"""Retain original pack metadata, ordering and manifest set paths for the native chooser."""
from pathlib import Path
import json, zipfile, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent.parent
content=root/'App/Content'
catalog=json.loads((content/'catalog.json').read_text(encoding='utf-8'))
by_name={x['name']:x for x in catalog}
packs=[]
def add_pack(pack_id, read, names):
    translations={}
    for name in names:
        if name.startswith('translate_') and name.endswith('.xml'):
            try: translations[name[10:-4]]={n.get('name'):n.text or '' for n in ET.fromstring(read(name)).findall('string')}
            except ET.ParseError: pass
    title=pack_id
    if 'meta.txt' in names:
        try: title=json.loads(read('meta.txt')).get('mHumanName',title)
        except (ValueError,UnicodeError): pass
    pack={'id':pack_id,'title':title,'titles':{lang:t['pack_name'] for lang,t in translations.items() if t.get('pack_name')},'thumbnail':None}
    logo=next((n for n in ['logo.png','thumb_hdpi.png','thumb.png'] if n in names),None)
    if logo:
        target=content/'PackCovers'/f'{pack_id}.png';target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(read(logo));pack['thumbnail']='PackCovers/'+target.name
    manifest=ET.fromstring(read('manifest.xml'))
    for order,item in enumerate(manifest.findall('./items/item')):
        fullname=item.get('fullname') or pack_id+':'+item.get('sname','')
        if fullname in by_name:
            definition=by_name[fullname]
            definition['packID']=pack_id
            definition['folderPath']=[x for x in item.get('set','').replace('\\','/').split('/') if x]
            definition['catalogOrder']=order
            short=item.get('sname') or fullname.split(':')[-1]
            definition['titles']={lang:values[short] for lang,values in translations.items() if short in values}
    packs.append(pack)
for pack_id in ['jungle','newstickman','puppet','stickman','christmas','common']:
    folder=root/'original-assets/scenes'/pack_id
    if folder.exists():add_pack(pack_id,lambda name,folder=folder:(folder/name).read_bytes(),[p.name for p in folder.iterdir() if p.is_file()])
for path in sorted((root/'original-assets/packs').glob('*.atp')):
    with zipfile.ZipFile(path) as archive:add_pack(path.stem,archive.read,archive.namelist())
for definition in catalog:
    definition.setdefault('packID',definition['name'].split(':')[0]);definition.setdefault('folderPath',[])
(content/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False),encoding='utf-8')
(content/'packs.json').write_text(json.dumps(packs,ensure_ascii=False,indent=2),encoding='utf-8')
print('Packs:',len(packs),'items with folders:',sum(bool(x['folderPath']) for x in catalog))
