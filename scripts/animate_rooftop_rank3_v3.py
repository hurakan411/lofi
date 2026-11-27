"""Rank 3 v3: inherit Rank 2 v8 motion, stronger anchored foliage, no coffee."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

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

# Use only the mug-removal patch from image_gen; preserve the approved scene.
environment=read(Image.open(folder/'rank-3-no-coffee-v3.png').convert('RGB'))
def core_mask(pose,top):
    mask=np.clip((pose.max(axis=2)-18)/18,0,1)
    mask*=((nx>.20)&(nx<.78)&(ny>top)&(ny<.86))
    return np.asarray(Image.fromarray(np.uint8(mask*255)).filter(ImageFilter.GaussianBlur(.45)),dtype=np.float32)/255
fixed_core=core_mask(base,.686)

def patch(cx,cy,rx,ry):
    return np.maximum(0,1-((x-cx)/rx)**2-((y-cy)/ry)**2)**2
# Finite leaf/branch regions end before pots, table and railing. Higher branches
# bend farther than their roots. Separate phases keep foliage from rocking as one.
canopy=patch(113,552,59,46)*np.clip((634-y)/80,0,1)
left=patch(43,650,65,40)*np.clip((691-y)/38,0,1)
right=patch(346,683,47,24)*np.clip((705-y)/25,0,1)
right*=y<701
vine=patch(357,771,29,51)*np.clip((y-718)/54,0,1)
front_left=patch(350,822,69,34)*np.clip((892-y)/70,0,1)
front_right=patch(410,801,43,40)*np.clip((890-y)/80,0,1)
front_low=patch(398,855,47,37)*np.clip((900-y)/48,0,1)
leaf_tip=patch(88,568,21,17)+patch(130,535,20,13)
def plant_dx(t):
    tau=2*math.pi*t/20
    gust=.85+.15*math.sin(2*tau+.4)
    return gust*(canopy*6.2*math.sin(3*tau)
        +left*5.5*math.sin(4*tau+.6)
        +right*5.8*math.sin(3*tau+1.25)
        +vine*6.4*math.sin(4*tau+2.1)
        +front_left*5.8*math.sin(3*tau+2.5)
        +front_right*5.3*math.sin(4*tau+1.7)
        +front_low*5.2*math.sin(3*tau+3.1)
        +leaf_tip*1.6*math.sin(6*tau+.7))
static_core=np.maximum(fixed_core,core_mask(base,.60))
static_scene=environment*(1-static_core[:,:,None])+base*static_core[:,:,None]
reference=Image.fromarray(np.uint8(np.clip(static_scene*1.16,0,255)))
palette=reference.quantize(colors=256)
encoded=[];event_frames=[];light_levels=[]
plant_maximum=0.
for i in range(400):
    t=i/20;name=stretch_name(t)
    stretching=name is not None
    typing=t%4<2.9 and not stretching
    pattern=[0,1,1,0,2,2,0,1,0,2,2,0,0,1,0,2]
    pose=stretch_poses[name] if stretching else typing_poses[pattern[int(t*10)%len(pattern)] if typing else 0]
    # Union of resting and raised silhouettes removes old hands when stretching.
    core=np.maximum(fixed_core,core_mask(pose,.60))
    scene=environment*(1-core[:,:,None])+pose*core[:,:,None]
    protected=np.clip((core-.15)/.55,0,1)
    wind=plant_dx(t)*(1-protected)
    plant_maximum=max(plant_maximum,float(np.abs(wind).max()))
    # Pots/roots remain fixed; hair retains the small independent v7 tufts.
    assert np.max(np.abs(wind[694:725,25:78]))<.5
    assert np.max(np.abs(wind[707:722,330:365]))<.5
    dx=hair_dx(t)+wind
    source_x=np.clip(np.rint(x-dx).astype(int),0,w-1)
    pixels=scene[y,source_x].copy()
    mix=screen_mix(t)
    visible_screen=screen_mask&(np.max(np.abs(pose-base),axis=2)<18)
    alpha=visible_screen.astype(np.float32)*mix
    pixels=pixels*(1-alpha[:,:,None])+alternate_pixels*alpha[:,:,None]
    # A single lighting pass keeps the lamp, wood and new plants coherent.
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
    if i in [0,40,100,240]:frame.save(folder/f'rank-3-v3-preview-{i:03}.png')
    event_frames.append(stretching)
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-3-rooftop-v3.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);assert check.info['loop']==0
elapsed=0
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
assert elapsed==20000
active=np.flatnonzero(event_frames)
assert len(active)>40 and np.all(np.diff(active)==1)
assert 4<plant_maximum<8
assert np.max(np.abs(plant_dx(0)-plant_dx(20)))<1e-5
assert screen_mix(0)==0 and screen_mix(10)==1 and screen_mix(20)==0
print('Stretch:',active[0]/20,'to',active[-1]/20,'seconds; once per 20 seconds')
print('Display changes every 10 seconds; lamp and hair inherited from Rank 2 v8')
print('Maximum plant-tip movement:',round(plant_maximum,2),'native pixels; pots fixed')
print('Lamp exposure range:',round(min(light_levels),3),round(max(light_levels),3))
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
