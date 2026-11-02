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
    next_node=next((n for n in nodes if ':id/boarding' in n.get('resource-id','') and n.get('text','').upper() in ['NEXT','DONE','SKIP'] and n.get('clickable')=='true' and n.get('enabled')=='true'),None)
    if next_node is None:
        next_node=next((n for n in nodes if n.get('resource-id','').endswith(':id/boarding4_play') and n.get('enabled')=='true'),None)
    if next_node is None:
        next_node=next((n for n in nodes if n.get('resource-id','').endswith(':id/boarding3_choice_learn') and n.get('enabled')=='true'),None)
    if next_node is None:
        # Close the observed subscription screen; never start purchases or trials.
        next_node=next((n for n in nodes if n.get('resource-id','').endswith(':id/paywall2_close') and n.get('enabled')=='true'),None)
    if next_node is None:
        drag_hint=next((n for n in nodes if n.get('resource-id','').endswith(':id/boarding2_drag_hint') and n.get('text')=='Drag the sword'),None)
        if drag_hint is not None:
            # Gesture measured in onboarding-next/onboarding-06.png at the fixed reference viewport.
            adb('shell','input','swipe','440','408','515','294','800')
            continue
        if any(n.get('resource-id','').endswith(':id/scene_view') for n in nodes):
            # Editor controls are populated asynchronously after onboarding closes.
            # Retain a settled capture before interpreting missing controls as absent features.
            time.sleep(15)
            adb('shell','uiautomator','dump','/sdcard/settled.xml')
            settled=adb('shell','cat','/sdcard/settled.xml')
            (root/'editor-settled.xml').write_text(settled)
            (root/'editor-settled.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
            (root/'editor-activities.txt').write_text(adb('shell','dumpsys','activity','activities'))
            adb('shell','input','keyevent','4')
            time.sleep(3)
            adb('shell','uiautomator','dump','/sdcard/back.xml')
            (root/'editor-back.xml').write_text(adb('shell','cat','/sdcard/back.xml'))
            (root/'editor-back.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
        break
    bounds=list(map(int,re.findall(r'\d+',next_node.get('bounds',''))))
    if len(bounds)!=4:break
    adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2))
    time.sleep(2)
(root/'observed-transitions.json').write_text(json.dumps(records,indent=2))
(root/'final-runtime.log').write_text(adb('logcat','-d'))
