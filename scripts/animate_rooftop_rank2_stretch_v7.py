"""Rank 2 v7: separate hair-tip tufts with anchored roots, continuous lamp, 20s stretch."""
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

# Continuous smooth 4-second lamp cycle with slower variation; no deep dips.
def strength(t):
    return .99+.14*math.sin(2*math.pi*5*t/20+.2)+.03*math.sin(2*math.pi*3*t/20+1.1)

def stretch_name(t):
    local=t-3.4
    for lo,hi,name in [(0,.18,'e'),(.18,.38,'a'),(.38,.58,'b'),(.58,.80,'d'),
                       (.80,2.0,'c'),(2.,2.22,'d'),(2.22,2.42,'b'),
                       (2.42,2.62,'a'),(2.62,2.80,'e')]:
        if lo<=local<hi:return name
    return None

# Keep the mass of the bob fixed. Only short outer tufts bend at their ends.
# Centers are in native pixels; each compact field falls to zero before its root.
# Independent periods and phase delays avoid a single sideways head wobble.
tufts=[
    (110,665,5.5,10,654,1.8,5,.2),
    (119,673,5.5,9,662,2.0,4,1.4),
    (129,678,5.0,8,666,1.7,6,2.7),
    (139,679,4.5,7,668,1.5,5,4.0),
    (118,644,5.0,6,638,1.1,7,1.8),
]
strand_fields=[]
for cx,cy,rx,ry,root,amplitude,frequency,phase in tufts:
    radius=((x-cx)/rx)**2+((y-cy)/ry)**2
    falloff=np.clip(1-radius,0,1)**1.5
    falloff*=np.clip((y-root)/(cy-root),0,1)
    strand_fields.append((falloff,amplitude,frequency,phase))
def hair_dx(t):
    dx=np.zeros((h,w),dtype=np.float32)
    for field,amplitude,frequency,phase in strand_fields:
        # Slight gust modulation, still a seamless 20-second loop.
        breeze=.82+.18*math.sin(2*math.pi*2*t/20+phase*.5)
        dx+=field*amplitude*breeze*math.sin(2*math.pi*frequency*t/20+phase)
    return dx
reference=Image.fromarray(np.uint8(np.clip(stretch_poses['c']*1.16,0,255)))
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
    # Small free tips move independently; central hair, roots and face stay fixed.
    dx=hair_dx(t)
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
    if i==100:frame.save(folder/'rank-2-stretch-preview-v7.png')
    event_frames.append(stretching)
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-2-stretch-v7.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);assert check.info['loop']==0
elapsed=0
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
assert elapsed==20000
active=np.flatnonzero(event_frames)
assert len(active)>40 and np.all(np.diff(active)==1),'One stretch per loop'
assert .81<min(light_levels)<.86 and 1.13<max(light_levels)<1.16,'Visible smooth lamp variation without deep dimming'
motion=np.stack([hair_dx(t) for t in np.arange(0,20,.1)])
assert 1.5<float(np.abs(motion).max())<2.1,'Small visible tuft motion'
assert np.count_nonzero(motion[:,625:653,127:175])==0,'Central hair mass and crown anchored'
assert np.count_nonzero(motion[:,653:690,151:177])==0,'Face anchored'
assert np.max(np.abs(motion[0]-hair_dx(20)))<1e-5,'Seamless hair loop'
# Verify the keyboard is unoccupied during the full overhead stretch.
full_stretch=stretch_poses['c']
assert np.mean(np.abs(full_stretch[710:735,165:225]-base[710:735,165:225]))>3
print('Stretch once per loop:',round(active[0]/20,2),'to',round(active[-1]/20,2),'seconds')
print('Light range:',round(min(light_levels),3),'to',round(max(light_levels),3))
print('Maximum independent hair-tip movement:',round(float(np.abs(motion).max()),2),'pixels')
print('Pixels reached by hair motion:',np.count_nonzero(np.max(np.abs(motion),axis=0)>.5))
# Inspect the actual indexed GIF, so palette compression cannot hide the lamp pulse.
lamp_brightness=[]
for frame_index in range(check.n_frames):
    check.seek(frame_index)
    rgb=np.asarray(check.convert('RGB'),dtype=float)
    lamp_brightness.append(float(rgb[654:679,275:306].mean()))
assert max(lamp_brightness)-min(lamp_brightness)>15,'Encoded lamp brightness visibly varies'
print('Decoded lamp ROI brightness range:',round(min(lamp_brightness),1),round(max(lamp_brightness),1))
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
