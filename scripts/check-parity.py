"""Do not package a claimed final IPA before the requested parity has evidence."""
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parent.parent
data=json.loads((root/'analysis/parity_requirements.json').read_text(encoding='utf-8'))
problems=[]
for key in ['function_inventory_coverage','android_screen_inventory_coverage']:
    if data.get(key)!='complete':problems.append(key+' is not complete')
for item in data['requirements']:
    if item.get('status')!='verified':problems.append(item['id']+': '+item.get('status','missing'))
    elif not item.get('verification_report') or not (root/item['verification_report']).is_file():problems.append(item['id']+': missing verification report')
if problems:
    print('Final IPA delivery is blocked: original parity is incomplete.')
    print('\n'.join(problems))
    sys.exit(1)
print('All recorded requirements have verification reports; final packaging allowed.')
