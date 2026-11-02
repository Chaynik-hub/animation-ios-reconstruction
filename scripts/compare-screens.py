"""Compare explicitly aligned captures. A score alone never proves behavioral parity."""
from pathlib import Path
import argparse,json,math
from PIL import Image,ImageChops,ImageStat

p=argparse.ArgumentParser()
p.add_argument('--android',required=True,type=Path)
p.add_argument('--ios',required=True,type=Path)
p.add_argument('--android-crop',type=int,nargs=4,metavar=('X','Y','W','H'))
p.add_argument('--ios-crop',type=int,nargs=4,metavar=('X','Y','W','H'))
p.add_argument('--output',required=True,type=Path)
p.add_argument('--state',required=True,help='Recorded matching scene and interaction state')
args=p.parse_args()
def crop(image,box):
    if box is None:return image
    x,y,w,h=box
    if x<0 or y<0 or w<=0 or h<=0 or x+w>image.width or y+h>image.height:raise ValueError('Invalid crop')
    return image.crop((x,y,x+w,y+h))
a=crop(Image.open(args.android).convert('RGB'),args.android_crop)
b=crop(Image.open(args.ios).convert('RGB'),args.ios_crop)
if a.size!=b.size:raise SystemExit('Capture sizes differ: provide calibrated crops with identical pixel dimensions. No automatic stretching is allowed.')
args.output.mkdir(parents=True,exist_ok=True)
difference=ImageChops.difference(a,b)
statistics=ImageStat.Stat(difference)
mae=sum(statistics.mean)/3
rmse=math.sqrt(sum(value*value for value in statistics.rms)/3)
ssim=None
try:
    import numpy as np
    from skimage.metrics import structural_similarity
    ssim=float(structural_similarity(np.asarray(a),np.asarray(b),channel_axis=2,data_range=255))
except ImportError:pass
report={'state':args.state,'android':str(args.android),'ios':str(args.ios),'android_crop':args.android_crop,'ios_crop':args.ios_crop,'dimensions':a.size,'MAE_0_255':mae,'RMSE_0_255':rmse,'SSIM':ssim,'limitations':['Requires independently verified matching state and crop calibration.','Static image metrics do not verify gestures, timing or business logic.']}
if ssim is None:report['limitations'].append('SSIM unavailable: numpy/scikit-image not installed in this interpreter.')
difference.save(args.output/'difference.png')
Image.blend(a,b,0.5).save(args.output/'overlay.png')
(args.output/'metrics.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
