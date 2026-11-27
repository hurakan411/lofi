"""Rank 3 adds rooftop surroundings; approved rank-2 motion is composited intact."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageFilter

root = Path(__file__).resolve().parents[1]
folder = root / 'output/concepts/rooftop/stages'
previous = Image.open(folder / 'rank-2-workstation-v3.gif')
w, h = previous.size
base_image = Image.open(folder / 'rank-3.png').convert('RGB').resize((w, h), Image.Resampling.NEAREST)
base = np.asarray(base_image, dtype=np.float32)
rank2 = np.asarray(Image.open(folder / 'rank-2.png').convert('RGB').resize((w,h), Image.Resampling.NEAREST), dtype=np.float32)
y, x = np.mgrid[:h, :w]
nx, ny = x / w, y / h
# Reuse all visible workstation pixels, including the accepted hand animation.
mask = np.clip((rank2.max(axis=2) - 18) / 18, 0, 1)
mask *= (nx > .20) & (nx < .78) & (ny > .686) & (ny < .86)
mask = np.asarray(Image.fromarray(np.uint8(mask*255)).filter(ImageFilter.GaussianBlur(.45)), dtype=np.float32)/255

def patch(cx, cy, rx, ry):
    # Smoothly anchored leaf-cluster motion, tapering to zero at patch boundaries.
    distance = ((nx-cx)/rx)**2 + ((ny-cy)/ry)**2
    return np.maximum(0, 1-distance)**2

# Plant regions avoid the woman, hands, lamp and structural railing.
canopy = patch(.265,.625,.145,.067)
left = patch(.105,.725,.125,.055)
right = patch(.805,.763,.115,.035)
vine = patch(.837,.855,.080,.068)
foreground = patch(.90,.925,.17,.075)
old_frames=[]
for i in range(previous.n_frames):
    previous.seek(i)
    old_frames.extend([np.asarray(previous.convert('RGB'),dtype=np.float32)] * round(previous.info['duration']/50))
assert len(old_frames)==160
frames=[]
for i in range(160):
    t=i/20
    breeze=math.sin(2*math.pi*t/8)
    second=math.sin(2*math.pi*2*t/8+.8)-math.sin(.8)
    dx=(canopy*1.8+left*1.3+right*1.5)*breeze
    dx+=(vine*1.6+foreground*1.4)*(.7*breeze+.3*second)
    sx=np.clip(np.rint(x-dx).astype(int),0,w-1)
    plants=base[y,sx]
    pixels=plants*(1-mask[:,:,None])+old_frames[i]*mask[:,:,None]
    frames.append(Image.fromarray(np.uint8(np.clip(pixels,0,255))))
# One shared palette prevents frame-to-frame palette flicker.
palette=frames[0].quantize(colors=224)
encoded=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
output=folder/'rank-3-rooftop.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output)
assert check.info.get('loop')==0 and check.n_frames>100
elapsed=0
minimum=None
maximum=None
for i in range(check.n_frames):
    check.seek(i)
    elapsed+=check.info['duration']
    a=np.asarray(check.convert('RGB'),dtype=np.int16)
    minimum=a.copy() if minimum is None else np.minimum(minimum,a)
    maximum=a.copy() if maximum is None else np.maximum(maximum,a)
assert elapsed==8000
for label,region in [('typing',(.37,.785,.51,.81)),('lamp',(.62,.70,.70,.79)),('monitor',(.43,.70,.60,.78)),('leaves',(.10,.59,.39,.69))]:
    x0,y0,x1,y1=region
    delta=(maximum-minimum)[int(y0*h):int(y1*h),int(x0*w):int(x1*w)]
    assert delta.max()>10,label
    print(label,'animated')
# Upper darkness remains completely stationary; it contains no city reveal yet.
assert np.array_equal(minimum[:int(.56*h)],maximum[:int(.56*h)])
frames[0].save(folder/'rank-3-preview.png')
print(output,check.size,check.n_frames,'frames, 8-second infinite loop,',output.stat().st_size,'bytes')
