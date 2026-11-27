"""Rank 2 v8: alternate holographic screen content every 10 seconds."""
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
# Alternate interface content inside the original holographic frame.
# The frame, glass edges and perspective are retained from the approved scene.
screen_w,screen_h=96,64
sy,sx=np.mgrid[:screen_h,:screen_w]
glass=np.empty((screen_h,screen_w,3),dtype=np.uint8)
glass[:,:,0]=6+sx*.06+sy*.04
glass[:,:,1]=48-sx*.14-sy*.08
glass[:,:,2]=77-sx*.18-sy*.10
alternate=Image.fromarray(glass)
draw=ImageDraw.Draw(alternate)
muted=(18,94,119);ink=(24,179,196);bright=(60,211,217)
# Header, two columns of code and a live chart, footer status blocks.
draw.line((6,8,29,8),fill=ink,width=2)
for xx in [80,85,90]:draw.rectangle((xx,7,xx+1,8),fill=muted)
draw.line((6,14,90,14),fill=muted,width=1)
for yy,indent,length in [(22,0,23),(28,5,20),(34,5,25),(40,5,15),(46,0,26)]:
    draw.line((7+indent,yy,7+indent+length,yy),fill=ink if yy in [22,40] else muted,width=2)
    draw.point((5,yy),fill=bright)
draw.line((51,22,51,48,89,48),fill=muted,width=1)
draw.line([(54,44),(60,39),(66,41),(72,30),(79,34),(87,23)],fill=bright,width=2)
for xx,yy in [(60,39),(72,30),(87,23)]:draw.rectangle((xx-1,yy-1,xx+1,yy+1),fill=bright)
for xx,ww in [(7,16),(27,9),(41,13),(77,12)]:draw.line((xx,56,xx+ww,56),fill=muted,width=2)
# Inverse affine map from screen-plane UV to native image coordinates.
uv=np.linalg.inv(np.array([[66.,-4.],[14.,38.]]))@np.stack((x-191,y-637)).reshape(2,-1)
u,v=uv.reshape(2,h,w)
screen_mask=(u>=0)&(u<=1)&(v>=0)&(v<=1)
cu=np.clip(np.rint(u*(screen_w-1)).astype(int),0,screen_w-1)
cv=np.clip(np.rint(v*(screen_h-1)).astype(int),0,screen_h-1)
alternate_pixels=np.asarray(alternate,dtype=np.float32)[cv,cu]
def screen_mix(t):
    # End each 10-second interval with a quiet 0.3-second page change.
    if t<9.7:return 0.
    if t<10:return .5-.5*math.cos(math.pi*(t-9.7)/.3)
    if t<19.7:return 1.
    return .5+.5*math.cos(math.pi*(t-19.7)/.3)

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
    mix=screen_mix(t)
    # A raised sleeve may occlude the glass in the intermediate stretch pose.
    visible_screen=screen_mask&(np.max(np.abs(pose-base),axis=2)<18)
    alpha=visible_screen.astype(np.float32)*mix
    pixels=pixels*(1-alpha[:,:,None])+alternate_pixels*alpha[:,:,None]
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
        if mix>.5:xx=204+(int(t*2)%3)*2;yy=669
        draw.line((xx,yy,xx,yy+3),fill=(80,214,221),width=1)
    if typing and i%7<2:
        xx=round(w*(.521+.006*((i//7)%3)));yy=round(h*(.808+.003*((i//14)%2)))
        draw.line((xx,yy,xx+1,yy),fill=(63,107,117),width=1)
    if i in [40,240]:frame.save(folder/f'rank-2-display-v8-{i//200}.png')
    event_frames.append(stretching)
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-2-stretch-v8.gif'
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
assert screen_mix(0)==0 and screen_mix(10)==1 and screen_mix(20)==0
assert len(set(round(screen_mix(t),5) for t in [2,6,12,16]))==2
print('Display changes: 10 and 20 seconds (20-second seamless loop)')
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
