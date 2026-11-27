"""Rank 2 v5: drawn stretch once per 20 seconds, hair breeze, gentle light."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
w,h=438,900
full=Image.open(folder/'rank-2.png').convert('RGB')
read=lambda im: np.asarray(im.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)
base=read(full)
y,x=np.mgrid[:h,:w];nx,ny=x/w,y/h
# Preserve the approved locally drawn typing poses.
typing_poses=[base]
for filename,center in [('typing-pose-a.png',(72,30)),('typing-pose-b.png',(123,52))]:
    variant=Image.open(folder/filename).convert('RGB').resize((190,95),Image.Resampling.NEAREST)
    cy,cx=np.mgrid[:95,:190]
    distance=((cx-center[0])/18)**2+((cy-center[1])/13)**2
    mask=Image.fromarray(np.uint8(np.clip((1-distance)*4,0,1)*255))
    pose=full.copy();pose.paste(variant,(315,1387),mask)
    typing_poses.append(read(pose))

# Registered drawn keyframes; replace the old arms completely, no body warping.
cw,ch=370,460
cy,cx=np.mgrid[:ch,:cw]
edge=np.minimum.reduce([cx,cy,cw-1-cx,ch-1-cy])
alpha=np.clip(edge/9,0,1)
# Monitor remains registered. The halfway arm can naturally occlude its left edge.
monitor=Image.new('L',full.size,0)
ImageDraw.Draw(monitor).polygon([(382,1260),(522,1285),(516,1388),(376,1362)],fill=255)
monitor_mask=np.asarray(monitor.crop((165,1090,535,1550)))>0
crop_original=np.asarray(full.crop((165,1090,535,1550)))
stretch_poses={}
for name in ['e','a','b','d','c']:
    crop=np.asarray(Image.open(folder/f'stretch-{name}.png').convert('RGB').resize((cw,ch),Image.Resampling.NEAREST)).copy()
    keep_screen=monitor_mask.copy()
    if name=='b':
        keep_screen&=cx>235
    crop[keep_screen]=crop_original[keep_screen]
    pose=full.copy()
    pose.paste(Image.fromarray(crop),(165,1090),Image.fromarray(np.uint8(alpha*255)))
    stretch_poses[name]=read(pose)

# Periodic lighting stays close to nominal exposure; no deep irregular dips.
def strength(t):
    return .995+.027*math.sin(2*math.pi*2*t/20+.2)+.013*math.sin(2*math.pi*3*t/20+1.1)

def stretch_name(t):
    local=t-3.4
    for lo,hi,name in [(0,.18,'e'),(.18,.38,'a'),(.38,.58,'b'),(.58,.80,'d'),
                       (.80,2.0,'c'),(2.,2.22,'d'),(2.22,2.42,'b'),
                       (2.42,2.62,'a'),(2.62,2.80,'e')]:
        if lo<=local<hi:return name
    return None

# Only free strands at the back and crown move; face and skull remain anchored.
hairfield=np.exp(-2*(((nx-.277)/.020)**2+((ny-.742)/.022)**2))
hairfield+=np.exp(-2*(((nx-.347)/.019)**2+((ny-.697)/.009)**2))*.85
hairfield*=((nx<.367)&(ny>.685)&(ny<.77))
reference=Image.fromarray(np.uint8(np.clip(stretch_poses['c']*1.04,0,255)))
palette=reference.quantize(colors=256)
encoded=[];event_frames=[];light_levels=[]
for i in range(400):
    t=i/20;name=stretch_name(t)
    stretching=name is not None
    typing=t%4<2.9 and not stretching
    pattern=[0,1,1,0,2,2,0,1,0,2,2,0,0,1,0,2]
    if stretching:
        pose=stretch_poses[name]
    else:
        pose=typing_poses[pattern[int(t*10)%len(pattern)] if typing else 0]
    # A 1-pixel breeze affecting flexible hair tips only.
    dx=hairfield*1.15*math.sin(2*math.pi*2*t/20)
    sx=np.clip(np.rint(x-dx).astype(int),0,w-1)
    pixels=pose[y,sx].copy()
    warm=np.clip((pixels[:,:,0]-pixels[:,:,2]-8)/55,0,1)*np.clip((pixels[:,:,0]-15)/55,0,1)
    cyan=np.clip((pixels[:,:,2]+pixels[:,:,1]-2*pixels[:,:,0]-35)/150,0,1)
    cyan*=((nx>.425)&(nx<.602)&(ny>.696)&(ny<.782))
    light=strength(t);light_levels.append(light)
    pulse=.035*math.sin(2*math.pi*5*t/20)+.012*math.sin(2*math.pi*11*t/20)
    pixels*=(1+warm[:,:,None]*(light-1))*(1+cyan[:,:,None]*pulse)
    frame=Image.fromarray(np.uint8(np.clip(pixels,0,255)))
    draw=ImageDraw.Draw(frame)
    if typing and i%20<12:
        xx=round(w*(.476+.006*(int(t*2)%4)));yy=round(h*.748)
        draw.line((xx,yy,xx,yy+3),fill=(80,214,221),width=1)
    if typing and i%7<2:
        xx=round(w*(.521+.006*((i//7)%3)));yy=round(h*(.808+.003*((i//14)%2)))
        draw.line((xx,yy,xx+1,yy),fill=(63,107,117),width=1)
    if i==100:frame.save(folder/'rank-2-stretch-preview-v5.png')
    event_frames.append(stretching)
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-2-stretch-v5.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);assert check.info['loop']==0
elapsed=0
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
assert elapsed==20000
active=np.flatnonzero(event_frames)
assert len(active)>40 and np.all(np.diff(active)==1),'One stretch per loop'
assert min(light_levels)>.95 and max(light_levels)<1.04,'Keep lamp near nominal brightness'
assert np.count_nonzero(np.rint(hairfield*1.15))>0,'Hair-tip motion present'
# Verify the keyboard is unoccupied during the full overhead stretch.
full_stretch=stretch_poses['c']
assert np.mean(np.abs(full_stretch[710:735,165:225]-base[710:735,165:225]))>3
print('Stretch once per loop:',round(active[0]/20,2),'to',round(active[-1]/20,2),'seconds')
print('Light range:',round(min(light_levels),3),'to',round(max(light_levels),3))
print('Hair tip maximum movement:',round(float(hairfield.max()*1.15),2),'pixels')
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
