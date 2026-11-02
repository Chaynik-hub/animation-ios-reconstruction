"""Capture observed onboarding transitions; select only nodes present in current UI XML."""
from pathlib import Path
import subprocess,time,xml.etree.ElementTree as ET,re,json

root=Path('reference-output')
def adb(*args, binary=False):
    return subprocess.check_output(['adb',*args],timeout=40).decode('utf-8',errors='replace') if not binary else subprocess.check_output(['adb',*args],timeout=40)
records=[]
for step in range(24):
    time.sleep(2)
    adb('shell','uiautomator','dump','/sdcard/step.xml')
    xml=adb('shell','cat','/sdcard/step.xml')
    (root/f'onboarding-{step:02d}.xml').write_text(xml)
    (root/f'onboarding-{step:02d}.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
    tree=ET.fromstring(xml)
    nodes=list(tree.iter('node'))
    records.append({'step':step,'text':[n.get('text') for n in nodes if n.get('text')]})
    next_node=next((n for n in nodes if n.get('resource-id','').endswith((':id/boarding_next',':id/boarding4_play')) and n.get('enabled')=='true'),None)
    if next_node is None:break
    bounds=list(map(int,re.findall(r'\d+',next_node.get('bounds',''))))
    if len(bounds)!=4:break
    adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2))
    time.sleep(2)
(root/'observed-transitions.json').write_text(json.dumps(records,indent=2))
(root/'final-runtime.log').write_text(adb('logcat','-d'))
