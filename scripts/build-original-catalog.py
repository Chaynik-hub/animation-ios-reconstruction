"""Package original scene and ATP/ATI bitmap assets without changing their geometry."""
from pathlib import Path,PurePosixPath
import zipfile,io,xml.etree.ElementTree as ET,json,hashlib

root=Path(__file__).resolve().parent.parent
source=root/'original-assets'
content=root/'App/Content'
definitions={}
limitations=[]
def build(model_data,asset_data,read_file,relative):
    model=ET.fromstring(model_data);assets=ET.fromstring(asset_data)
    name=model.get('name')
    if not name:return None
    parts=[]
    for element in assets.findall('edgeAsset'):
        bitmap=element.get('bm')
        if not bitmap:
            limitations.append({'name':name,'reason':'edge without bitmap','edge':element.attrib});continue
        path=PurePosixPath(bitmap)
        if path.is_absolute() or '..' in path.parts:raise ValueError('Unsafe artwork path')
        try:data=read_file(bitmap)
        except (FileNotFoundError,KeyError):
            limitations.append({'name':name,'reason':'missing bitmap','bitmap':bitmap});continue
        target=relative/path
        destination=content/target;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data)
        part=dict(element.attrib,image=target.as_posix());parts.append(part)
        if element.get('svg'):
            svg=PurePosixPath(element.get('svg'))
            if svg.is_absolute() or '..' in svg.parts:raise ValueError('Unsafe SVG path')
            try:
                destination=content/relative/svg;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(read_file(str(svg)))
            except (FileNotFoundError,KeyError):limitations.append({'name':name,'reason':'missing SVG source'})
    if not parts:return None
    thumbnail=None
    try:
        data=read_file('thumb.png');target=relative/'thumb.png';destination=content/target;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data);thumbnail=target.as_posix()
    except (FileNotFoundError,KeyError):pass
    definitions[name]={'name':name,'points':[p.attrib for p in model.findall('point')],'parts':parts,'thumbnail':thumbnail}
    return name

for model in (source/'scenes').rglob('model.xml'):
    assets=model.with_name('assets.xml')
    if assets.exists():build(model.read_bytes(),assets.read_bytes(),lambda name,folder=model.parent:(folder/name).read_bytes(),PurePosixPath('Artwork')/model.parent.relative_to(source).as_posix())
for pack in (source/'packs').glob('*.atp'):
    with zipfile.ZipFile(pack) as archive:
        manifest=ET.fromstring(archive.read('manifest.xml'))
        default_scale=float(manifest.get('def_scale','1'))
        translations={}
        for translated in archive.namelist():
            if translated.startswith('translate_') and translated.endswith('.xml'):
                language=translated[len('translate_'):-4]
                try:
                    translations[language]={node.get('name'):node.text or '' for node in ET.fromstring(archive.read(translated)).findall('string')}
                except ET.ParseError:
                    limitations.append({'pack':pack.name,'reason':'invalid or empty translation','file':translated})
        for entry in archive.namelist():
            if not entry.endswith('.ati') or entry.startswith('__MACOSX/') or PurePosixPath(entry).name.startswith('._'):continue
            with zipfile.ZipFile(io.BytesIO(archive.read(entry))) as item:
                if 'model.xml' not in item.namelist() or 'assets.xml' not in item.namelist():
                    limitations.append({'pack':pack.name,'item':entry,'reason':'missing model/assets'});continue
                item_key=hashlib.sha256(entry.encode('utf-8')).hexdigest()[:20]
                name=build(item.read('model.xml'),item.read('assets.xml'),item.read,PurePosixPath('Artwork/Packs')/pack.stem/item_key)
                if name:
                    definitions[name]['defaultScale']=default_scale
                    short_name=name.split(':')[-1]
                    definitions[name]['titles']={language:values[short_name] for language,values in translations.items() if short_name in values}
(content/'catalog.json').write_text(json.dumps(list(definitions.values()),ensure_ascii=False),encoding='utf-8')
(root/'analysis/catalog-limitations.json').write_text(json.dumps(limitations,ensure_ascii=False,indent=2),encoding='utf-8')
print('Original objects:',len(definitions),'explicit asset limitations:',len(limitations))
