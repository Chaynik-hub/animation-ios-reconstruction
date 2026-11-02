from pathlib import Path
import zipfile,io,json,resvg_py
root=Path(__file__).resolve().parent.parent; content=root/'App/Content'; entries=[];errors=[]
def add(pack,name,files,read):
    source=next((f for f in ['bg.png','bg.jpg','bg.jpeg','bg.svg'] if f in files),None)
    if not source:errors.append({'pack':pack,'name':name,'error':'missing background'});return
    relative=Path('Backgrounds')/pack/name;target=content/relative;target.mkdir(parents=True,exist_ok=True)
    data=read(source)
    if source.endswith('.svg'):
        (target/'bg.svg').write_bytes(data)
        data=resvg_py.svg_to_bytes(svg_string=data.decode('utf-8-sig'),width=2048,skip_system_fonts=True)
    (target/'bg.png').write_bytes(data)
    if 'thumb.png' in files:(target/'thumb.png').write_bytes(read('thumb.png'))
    else:
        from PIL import Image
        image=Image.open(io.BytesIO(data));image.thumbnail((180,180));image.save(target/'thumb.png')
    entries.append({'id':pack+':'+name,'pack':pack,'title':name,'image':(relative/'bg.png').as_posix(),'thumbnail':(relative/'thumb.png').as_posix()})
for pack in sorted((root/'original-assets/bgs').iterdir()):
    for folder in sorted(pack.iterdir()):
        if folder.is_dir():add(pack.name,folder.name,[p.name for p in folder.iterdir()],lambda n,folder=folder:(folder/n).read_bytes())
for pack in sorted((root/'original-assets/packs').glob('*.atp')):
    with zipfile.ZipFile(pack) as archive:
        for entry in archive.namelist():
            if entry.startswith('bgs/') and entry.endswith('.zip'):
                with zipfile.ZipFile(io.BytesIO(archive.read(entry))) as bg:add(pack.stem,Path(entry).stem,bg.namelist(),bg.read)
(content/'backgrounds.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf8')
(root/'analysis/background-inventory.json').write_text(json.dumps({'count':len(entries),'errors':errors,'svg_raster_width':2048},indent=2),encoding='utf8')
print(len(entries),'backgrounds;',len(errors),'missing')
