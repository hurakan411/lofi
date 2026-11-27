"""Rank 4 v3: latest rooftop motion, static near city, eight road cars."""
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

# Compact rotations, rather than broad horizontal stretching of foliage.
# Each leaf turns around its petiole; its blade keeps its shape. Branch motion
# is smaller and slower, with a slight phase delay at the free tips.
rotations=[]
def add_rotation(pivot,center,radii,degrees,delay,flutter=0,group=0):
    cx,cy=center;rx,ry=radii
    # Keep the actual leaf outline inside the rigid rotation area. Fade outside
    # the blade, so its tips move too instead of being pinned by the old matte.
    support=math.sqrt(1.55)
    x0=max(0,int(cx-rx*support-2));x1=min(w,int(cx+rx*support+3))
    y0=max(0,int(cy-ry*support-2));y1=min(h,int(cy+ry*support+3))
    xx=x[y0:y1,x0:x1];yy=y[y0:y1,x0:x1]
    q=((xx-cx)/rx)**2+((yy-cy)/ry)**2
    fade=np.clip((1.55-q)/.55,0,1)
    fade=fade*fade*(3-2*fade)
    rotations.append((slice(y0,y1),slice(x0,x1),fade,
        xx-pivot[0],yy-pivot[1],math.radians(degrees*(1.35 if not flutter else (1.8 if degrees<3 else 2.2))),delay,flutter,group))
# Roots and pots are outside these branch fields.
add_rotation((113,632),(111,566),(58,48),1.1,0)
add_rotation((52,691),(46,651),(62,39),.9,.15,group=1)
add_rotation((347,705),(347,683),(43,23),1.1,.25,group=2)
add_rotation((357,719),(357,766),(24,43),1.35,.4,group=2)
# (petiole, blade center, blade radius, angular swing, wind delay).
leaves=[
 ((113,543),(108,535),(12,8),4.8,.30),
 ((138,536),(147,528),(13,8),5.0,.45),
 ((125,554),(121,546),(10,9),4.5,.50),
 ((100,565),(91,560),(13,9),4.8,.35),
 ((80,575),(71,568),(13,10),5.5,.55),
 ((108,582),(110,573),(11,9),4.5,.45),
 ((128,588),(126,579),(11,10),5.0,.65),
 ((149,589),(160,586),(12,10),5.5,.75),
 ((141,606),(148,600),(12,10),4.8,.60),
 ((56,628),(62,620),(17,8),4.2,.40),
 ((49,639),(39,632),(16,9),4.5,.55),
 ((31,648),(20,642),(15,10),4.8,.65),
 ((61,651),(72,646),(18,11),4.0,.70),
 ((43,659),(36,665),(15,14),4.0,.50),
 ((65,659),(70,672),(15,16),4.2,.80),
 ((26,668),(18,680),(13,15),4.8,.75),
 ((345,682),(335,677),(14,8),5.0,.55),
 ((353,680),(361,675),(14,8),4.5,.65),
 ((366,690),(376,689),(15,10),4.5,.80),
 ((329,690),(318,689),(16,9),5.0,.70),
 ((356,737),(365,737),(12,10),5.5,.70),
 ((356,754),(348,758),(12,13),5.0,.85),
 ((358,773),(366,777),(12,14),5.0,1.0),
 ((359,793),(364,800),(10,12),5.5,1.1),
 # Large foreground blades have small angles but clearly visible tip arcs.
 ((382,851),(340,823),(53,19),2.4,.70),
 ((379,875),(339,856),(41,23),2.8,.90),
 ((388,856),(407,831),(33,25),2.8,.85),
 ((399,822),(423,793),(31,33),2.5,.60),
 ((408,896),(431,878),(28,24),2.6,1.0),
]
for j,(pivot,center,radii,degrees,delay) in enumerate(leaves):
    group=0 if j<9 else 1 if j<16 else 2 if j<24 else 3
    add_rotation(pivot,center,radii,degrees,delay,j+1,group=group)
rigid=np.zeros((h,w),dtype=np.float32)
rigid[692:728,25:79]=1 # left pot
rigid[677:710,78:106]=1 # lantern
rigid[704:727,330:364]=1 # right pot
rigid[760:895,277:285]=1 # desk leg
# Keep railing straight where broad plant support meets it.
rail=((np.abs(y-(532.6+.166*x))<3.3)|(np.abs(y-(546.6+.172*x))<2.5))&(x>153)
rigid[rail]=1

# Separate wind phase, period and gust envelope for each distinct plant.
# The hanging vine belongs to the right pot and inherits its wind with a lag.
wind_profiles=[
    (3,.35,7,2.1,1,.8),   # rear tree: about 6.7 seconds
    (4,2.2,2,4.4,2,3.3),  # left pot: about 5 seconds
    (5,4.3,6,.7,1,4.9),   # right pot and trailing vine: about 4 seconds
    (2,1.0,7,1.8,3,1.6),  # large foreground plant: about 10 seconds
]
def plant_wind(t,group):
    frequency,phase,secondary,offset,gust_frequency,gust_phase=wind_profiles[group]
    tau=2*math.pi*t/20
    gust=.91+.09*math.sin(gust_frequency*tau+gust_phase)
    return gust*(.82*math.sin(frequency*tau+phase)+.18*math.sin(secondary*tau+offset))

def plant_motion(t):
    dx=np.zeros((h,w),dtype=np.float32)
    dy=np.zeros((h,w),dtype=np.float32)
    leaf_x=np.zeros_like(dx);leaf_y=np.zeros_like(dy);leaf_weight=np.zeros_like(dx)
    for ys,xs,weight,xx,yy,amplitude,delay,flutter,group in rotations:
        tau=2*math.pi*(t-delay)/20
        wind=plant_wind(t-delay,group)
        if flutter:
            wind+=.08*math.sin((6+flutter%3)*tau+flutter*.7+wind_profiles[group][1])
        angle=amplitude*wind
        c=math.cos(angle)-1;s=math.sin(angle)
        xx_shift=weight*(c*xx+s*yy)
        yy_shift=weight*(-s*xx+c*yy)
        if flutter:
            leaf_x[ys,xs]+=xx_shift;leaf_y[ys,xs]+=yy_shift
            leaf_weight[ys,xs]+=weight
        else:
            dx[ys,xs]+=xx_shift;dy[ys,xs]+=yy_shift
    # Overlapping leaf regions share a rotation rather than multiplying it.
    dx+=leaf_x/np.maximum(1,leaf_weight);dy+=leaf_y/np.maximum(1,leaf_weight)
    dx*=1-rigid;dy*=1-rigid
    return dx,dy

def sample_plants(scene,dx,dy):
    # Fractional sampling removes 1-pixel snapping on slow leaf-tip arcs.
    xx=np.clip(x+dx,0,w-1);yy=np.clip(y+dy,0,h-1)
    x0=xx.astype(int);y0=yy.astype(int)
    x1=np.minimum(x0+1,w-1);y1=np.minimum(y0+1,h-1)
    fx=(xx-x0)[:,:,None];fy=(yy-y0)[:,:,None]
    return ((scene[y0,x0]*(1-fx)+scene[y0,x1]*fx)*(1-fy)
        +(scene[y1,x0]*(1-fx)+scene[y1,x1]*fx)*fy).astype(np.float32)
# Keep the approved near city and road, using a clean plate only behind moving
# foreground silhouettes. This prevents both ghost leaves and wobbly buildings.
city_original=read(Image.open(folder/'rank-4-near.png').convert('RGB'))
clean=read(Image.open(folder/'rank-4-clean-plate-generated-v3.png').convert('RGB'))
plate_mask=Image.new('L',(w,h),0);pm=ImageDraw.Draw(plate_mask)
for box in [(48,505,184,646),(0,600,119,708),(290,650,408,733),
            (327,710,402,824),(267,748,438,900),(89,612,235,766),
            (243,696,286,746)]:
    pm.rectangle(box,fill=255)
plate_mask=np.asarray(plate_mask.filter(ImageFilter.GaussianBlur(3)),dtype=np.float32)/255
city_plate=city_original*(1-plate_mask[:,:,None])+clean*plate_mask[:,:,None]
city_image=Image.fromarray(np.uint8(np.clip(city_plate,0,255)))
city_image.save(folder/'rank-4-clean-plate-v3.png')

def foreground_alpha(pixels):
    # The original Rank 3 scene is drawn over dark indigo. Red/green separate
    # opaque foreground material from that indigo without carrying a dark veil.
    value=np.maximum(pixels[:,:,0],pixels[:,:,1])
    return np.clip((value-9)/12,0,1)

# Same accepted road entirely in front of the concealed railway.
road=np.array([(267,340),(268,355),(272,375),(270,395),(274,414),
    (285,438),(295,465),(302,490),(310,518),(313,545)],dtype=float)
distances=np.r_[0,np.cumsum(np.linalg.norm(np.diff(road,axis=0),axis=1))]
distances/=distances[-1]
def road_point(u):
    index=min(len(road)-2,max(0,int(np.searchsorted(distances,u)-1)))
    f=(u-distances[index])/(distances[index+1]-distances[index])
    center=road[index]*(1-f)+road[index+1]*f
    tangent=road[index+1]-road[index];tangent/=np.linalg.norm(tangent)
    return center,tangent,np.array([tangent[1],-tangent[0]])
# Four vehicles in each lane; staggered spacing, body styles and perspective speed.
cars=[
    (.03,False,(100,129,150),1.10,1.00),
    (.28,False,(159,125,65),1.22,1.10),
    (.54,False,(134,76,94),1.15,.94),
    (.79,False,(133,146,153),1.28,1.06),
    (.12,True,(95,128,135),1.18,1.02),
    (.37,True,(130,113,158),1.10,.95),
    (.64,True,(148,124,99),1.26,1.13),
    (.89,True,(87,113,148),1.16,1.00),
]
visible_counts=[]
def draw_cars(t):
    overlay=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(overlay)
    visible=0
    for phase,reverse,color,exponent,scale in cars:
        progress=(t/10+phase)%1
        u=(1-progress)**exponent if reverse else progress**exponent
        center,tangent,normal=road_point(u)
        direction=-tangent if reverse else tangent
        center+=normal*((-1 if reverse else 1)*(2+1.5*u))
        length=(3.5+3.1*u)*scale;breadth=(1.9+1.1*u)*scale
        fade=max(0,min(1,u/.045,(1-u)/.045));alpha=round(255*fade)
        visible+=fade>.4
        corners=[center+direction*length*.5+normal*breadth*.5,
                 center+direction*length*.5-normal*breadth*.5,
                 center-direction*length*.5-normal*breadth*.5,
                 center-direction*length*.5+normal*breadth*.5]
        d.polygon([tuple(np.rint(p).astype(int)) for p in corners],fill=(*color,alpha))
        windshield=center+direction*length*.10
        d.line([tuple(windshield-normal*breadth*.35),tuple(windshield+normal*breadth*.35)],fill=(38,67,83,alpha),width=1)
        for side in [-1,1]:
            head=center+direction*length*.48+normal*breadth*.34*side
            tail=center-direction*length*.48+normal*breadth*.34*side
            d.point(tuple(np.rint(head).astype(int)),fill=(245,220,166,alpha))
            d.point(tuple(np.rint(tail).astype(int)),fill=(192,67,63,alpha))
    visible_counts.append(visible)
    return Image.alpha_composite(city_image.convert('RGBA'),overlay).convert('RGB')

static_core=np.maximum(fixed_core,core_mask(base,.60))
static_scene=environment*(1-static_core[:,:,None])+base*static_core[:,:,None]
static_alpha=foreground_alpha(static_scene)[:,:,None]
reference=Image.fromarray(np.uint8(np.clip(static_scene*1.16*static_alpha+city_plate*(1-static_alpha),0,255)))
palette=reference.quantize(colors=240)
colors=palette.getpalette()
reserved=[v[2] for v in cars]+[(245,220,166),(192,67,63),(38,67,83),(80,214,221)]
for j,color in enumerate(reserved):colors[(240+j)*3:(241+j)*3]=list(color)
palette.putpalette(colors)
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
    wind_x,wind_y=plant_motion(t)
    wind_x*=1-protected;wind_y*=1-protected
    plant_maximum=max(plant_maximum,float(np.hypot(wind_x,wind_y).max()))
    # Pots/roots remain fixed; hair retains the small independent v7 tufts.
    assert np.max(np.abs(wind_x[694:725,25:78])+np.abs(wind_y[694:725,25:78]))<.5
    assert np.max(np.abs(wind_x[707:722,330:365])+np.abs(wind_y[707:722,330:365]))<.5
    source_x=np.clip(np.rint(x-hair_dx(t)).astype(int),0,w-1)
    pixels=sample_plants(scene[y,source_x],wind_x,wind_y)
    mix=screen_mix(t)
    visible_screen=screen_mask&(np.max(np.abs(pose-base),axis=2)<18)
    alpha=visible_screen.astype(np.float32)*mix
    pixels=pixels*(1-alpha[:,:,None])+alternate_pixels*alpha[:,:,None]
    # A single lighting pass keeps the lamp, wood and new plants coherent.
    warm=np.clip((pixels[:,:,0]-pixels[:,:,2]-8)/55,0,1)*np.clip((pixels[:,:,0]-15)/55,0,1)
    cyan=np.clip((pixels[:,:,2]+pixels[:,:,1]-2*pixels[:,:,0]-35)/150,0,1)
    cyan*=((nx>.425)&(nx<.602)&(ny>.696)&(ny<.782))
    alpha_foreground=foreground_alpha(pixels)[:,:,None]
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
    city_frame=np.asarray(draw_cars(t),dtype=np.float32)
    frame=Image.fromarray(np.uint8(np.clip(np.asarray(frame)*alpha_foreground+city_frame*(1-alpha_foreground),0,255)))
    if i in [0,40,100,240]:frame.save(folder/f'rank-4-v3-preview-{i:03}.png')
    event_frames.append(stretching)
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-4-near-traffic-v3.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);assert check.info['loop']==0
elapsed=0
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
assert elapsed==20000
active=np.flatnonzero(event_frames)
assert len(active)>40 and np.all(np.diff(active)==1)
assert 6<plant_maximum<12
# Distinct plant rhythms should not share the same swing direction throughout.
curves=np.array([[plant_wind(t,g) for t in np.arange(0,20,.05)] for g in range(4)])
corr=np.corrcoef(np.gradient(curves,axis=1))
np.fill_diagonal(corr,0)
assert np.abs(corr).max()<.35,'Plants must not swing in sync'
print('Maximum cross-plant velocity correlation:',round(float(np.abs(corr).max()),3))
for a,b in zip(plant_motion(0),plant_motion(20)):
    assert np.max(np.abs(a-b))<1e-5
assert screen_mix(0)==0 and screen_mix(10)==1 and screen_mix(20)==0
assert len(cars)==8 and min(visible_counts)>=6
assert np.max(np.abs(np.asarray(draw_cars(0),dtype=int)-np.asarray(draw_cars(20),dtype=int)))==0
print('Cars:',len(cars),'vehicles,',min(visible_counts),'to',max(visible_counts),'visible; city remains fixed')
print('Stretch:',active[0]/20,'to',active[-1]/20,'seconds; once per 20 seconds')
print('Display changes every 10 seconds; lamp and hair inherited from Rank 2 v8')
print('Maximum plant-tip movement:',round(plant_maximum,2),'native pixels; pots fixed')
print('Lamp exposure range:',round(min(light_levels),3),round(max(light_levels),3))
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
