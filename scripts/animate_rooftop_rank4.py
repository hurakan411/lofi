"""Rank 4: retain the rooftop motions, add independently glowing neon city."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
w,h=438,900
read=lambda name: Image.open(folder/name).convert('RGB').resize((w,h),Image.Resampling.NEAREST)
r2=np.asarray(read('rank-2.png'),dtype=np.float32)
r3=np.asarray(read('rank-3.png'),dtype=np.float32)
r4=np.asarray(read('rank-4.png'),dtype=np.float32)
y,x=np.mgrid[:h,:w]
nx,ny=x/w,y/h
# Join STATIC artwork first, then illuminate the whole scene together.
# This avoids seams between independently flickering layers.
core=np.clip((r2.max(axis=2)-18)/18,0,1)
core*=((nx>.20)&(nx<.78)&(ny>.686)&(ny<.86))
core=np.asarray(Image.fromarray(np.uint8(core*255)).filter(ImageFilter.GaussianBlur(.45)),dtype=np.float32)/255
prior=r3*(1-core[:,:,None])+r2*core[:,:,None]
foreground=np.clip((r3.max(axis=2)-18)/18,0,1)
foreground=np.asarray(Image.fromarray(np.uint8(foreground*255)).filter(ImageFilter.GaussianBlur(.35)),dtype=np.float32)/255
base=r4*(1-foreground[:,:,None])+prior*foreground[:,:,None]
# Preserve the accepted workstation details while the new city fills its background.
base=base*(1-core[:,:,None])+r2*core[:,:,None]
near_lamp=np.maximum(foreground,core)
poses=[base]
full=Image.open(folder/'rank-2.png').convert('RGB')
for filename,center in [('typing-pose-a.png',(72,30)),('typing-pose-b.png',(123,52))]:
    variant=Image.open(folder/filename).convert('RGB').resize((190,95),Image.Resampling.NEAREST)
    cy,cx=np.mgrid[:95,:190]
    distance=((cx-center[0])/18)**2+((cy-center[1])/13)**2
    mask=Image.fromarray(np.uint8(np.clip((1-distance)*4,0,1)*255))
    pose=full.copy();pose.paste(variant,(315,1387),mask)
    delta=np.asarray(pose.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)-r2
    poses.append(base+delta)

warm=np.clip((base[:,:,0]-base[:,:,2]-8)/55,0,1)*np.clip((base[:,:,0]-15)/55,0,1)
warm*=near_lamp
cyan=np.clip((base[:,:,2]+base[:,:,1]-2*base[:,:,0]-35)/150,0,1)
cyan*=((nx>.425)&(nx<.602)&(ny>.696)&(ny<.782))

def strength(t):
    value=.83+.17*math.sin(2*math.pi*t/8+.2)
    value+=.105*math.sin(2*math.pi*3*t/8+1.1)+.055*math.sin(2*math.pi*7*t/8+.7)
    for center,depth,spread in [(1.5,.30,.13),(4.3,.23,.19),(6.6,.32,.12)]:
        delta=min(abs(t-center),8-abs(t-center))
        value-=depth*math.exp(-.5*(delta/spread)**2)
    return max(.32,min(1.18,value))

def patch(cx,cy,rx,ry):
    return np.maximum(0,1-((nx-cx)/rx)**2-((ny-cy)/ry)**2)**2

canopy=patch(.265,.625,.145,.067)
left=patch(.105,.725,.125,.055)
right=patch(.805,.763,.115,.035)
vine=patch(.837,.855,.080,.068)
foreground=patch(.90,.925,.17,.075)
# Only emissive sign pixels pulse, never whole buildings or the rooftop lamp.
brightness=base.max(axis=2)
chroma=brightness-base.min(axis=2)
neon=np.clip((brightness-65)/70,0,1)*np.clip((chroma-32)/70,0,1)
neon*=((base[:,:,2]>base[:,:,1]*1.08)|(base[:,:,1]>base[:,:,0]*1.30))
neon*=ny<.60
signs=[]
for bounds,frequency,phase,amount in [
    ((.21,.16,.285,.245),1,.2,.18),
    ((.405,.07,.49,.14),2,1.2,.13),
    ((.68,.035,.81,.10),1,2.4,.10),
    ((.535,.255,.64,.335),3,.8,.13),
    ((.37,.35,.49,.47),2,2.1,.12),
    ((.80,.09,.91,.155),1,1.6,.16)]:
    x0,y0,x1,y1=bounds
    region=neon*((nx>x0)&(nx<x1)&(ny>y0)&(ny<y1))
    signs.append((region,frequency,phase,amount))
# Tiny separated window groups fade gently rather than strobing.
rng=np.random.default_rng(74)
window_groups=[]
for k in range(4):
    grid=rng.random((h//5+1,w//5+1))
    selected=np.repeat(np.repeat(grid<.055,5,axis=0),5,axis=1)[:h,:w]
    window=selected*(ny<.58)*(base[:,:,0]>80)*(base[:,:,1]>65)*(base[:,:,2]<base[:,:,0]*.9)
    window_groups.append(window)
frames=[]
for i in range(160):
    t=i/20;typing=t%4<2.9
    pattern=[0,1,1,0,2,2,0,1,0,2,2,0,0,1,0,2]
    pose=poses[pattern[int(t*10)%len(pattern)] if typing else 0]
    breeze=math.sin(2*math.pi*t/8)
    second=math.sin(2*math.pi*2*t/8+.8)-math.sin(.8)
    dx=(canopy*1.8+left*1.3+right*1.5)*breeze+(vine*1.6+foreground*1.4)*(.7*breeze+.3*second)
    sx=np.clip(np.rint(x-dx).astype(int),0,w-1)
    pulse=.09*math.sin(2*math.pi*3*t/8)+.045*math.sin(2*math.pi*11*t/8)
    pixels=pose[y,sx]*(1+cyan[y,sx,None]*pulse)*(1+warm[y,sx,None]*(strength(t)-1))
    city_response=np.ones((h,w),dtype=np.float32)
    for region,frequency,phase,amount in signs:
        city_response+=region*amount*math.sin(2*math.pi*frequency*t/8+phase)
    for k,window in enumerate(window_groups):
        city_response+=window*.12*math.sin(2*math.pi*t/8+k*1.6)
    pixels*=city_response[:,:,None]
    frame=Image.fromarray(np.uint8(np.clip(pixels,0,255)))
    draw=ImageDraw.Draw(frame)
    if i%20<12:
        cx=round(w*(.476+.006*(int(t*2)%4)));cy=round(h*.748)
        draw.line((cx,cy,cx,cy+3),fill=(80,214,221),width=1)
    if typing and i%7<2:
        kx=round(w*(.521+.006*((i//7)%3)));ky=round(h*(.808+.003*((i//14)%2)))
        draw.line((kx,ky,kx+1,ky),fill=(63,107,117),width=1)
    frames.append(frame)
palette=frames[max(range(160),key=lambda i:strength(i/20))].quantize(colors=256)
encoded=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
output=folder/'rank-4-neon-city.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);assert check.info['loop']==0
elapsed=0;minimum=None;maximum=None;curves=[[],[]]
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
    a=np.asarray(check.convert('RGB'),dtype=np.int16)
    minimum=a.copy() if minimum is None else np.minimum(minimum,a)
    maximum=a.copy() if maximum is None else np.maximum(maximum,a)
    curves[0].append(a[737:750,236:252].mean())
    curves[1].append(a[737:750,281:298].mean())
assert elapsed==8000 and check.n_frames>100
assert np.corrcoef(curves)[0,1]>.97,'Desk lighting must remain continuous'
for label,region in [('typing',(.37,.785,.51,.81)),('lamp',(.62,.70,.70,.79)),('monitor',(.43,.70,.60,.78)),('leaves',(.10,.59,.39,.69)),('neon',(.21,.16,.285,.245))]:
    x0,y0,x1,y1=region
    assert (maximum-minimum)[int(y0*h):int(y1*h),int(x0*w):int(x1*w)].max()>10,label
    print(label,'animated')
# Buildings remain fixed; city motion is confined to light, not camera movement.
assert np.array_equal(minimum[:20,200:220],maximum[:20,200:220])
frames[10].save(folder/'rank-4-preview.png')
print('Light correlation:',round(float(np.corrcoef(curves)[0,1]),4))
print(output,check.size,check.n_frames,'frames, 8-second infinite loop,',output.stat().st_size,'bytes')
