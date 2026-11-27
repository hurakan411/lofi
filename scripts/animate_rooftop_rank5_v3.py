"""Rank 5 v3: inherit Rank 4 v5, 30-second trains and blinking rooftop beacons."""
from pathlib import Path
import math
import numpy as np
from PIL import Image,ImageDraw

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
w,h=438,900
y,x=np.mgrid[:h,:w];nx,ny=x/w,y/h
read=lambda name: np.asarray(Image.open(folder/name).convert('RGB').resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)
near=read('rank-4-near.png');far=read('rank-4.png')
foreground_gif=Image.open(folder/'rank-4-fans-room-off-v5.gif')
foreground_gif.seek(0);first=np.asarray(foreground_gif.convert('RGB'),dtype=np.float32)
# Reveal only the previously dark distance; preserve every latest foreground FX.
reveal=np.clip((48-near[:,:,0]-near[:,:,1])/22,0,1)*np.clip((.43-ny)/.10,0,1)
reveal[330:550,255:325]=0 # all eight cars and their roadway
reveal[280:372,365:438]=0 # the second room stays unlit
reveal[135:166,398:438]=0 # rooftop fan cases and rotating apertures
static=first*(1-reveal[:,:,None])+far*reveal[:,:,None]
Image.fromarray(np.uint8(np.clip(static,0,255))).save(folder/'rank-5-base-v3.png')

# The existing red points on actual rooftop masts, not windows or neon signs.
beacon_points=[(149,7),(135,16),(167,15),(185,12),(179,29),(121,35),(195,37),
    (216,58),(239,59),(251,46),(258,69),(233,83),(282,74),(270,78),
    (318,6),(334,0),(334,12),(340,15),(414,30),(395,43),(372,55),
    (366,65),(376,65),(385,74)]
beacons=[]
for cx,cy in beacon_points:
    x0=max(0,cx-5);x1=min(w,cx+6);y0=max(0,cy-5);y1=min(h,cy+6)
    yy,xx=np.mgrid[y0:y1,x0:x1];radius=np.hypot(xx-cx,yy-cy)
    patch=static[y0:y1,x0:x1]
    background=np.median(patch[(radius>3)&(radius<5.5)],axis=0)
    red=np.clip((patch[:,:,0]-np.maximum(patch[:,:,1],patch[:,:,2])*.9-8)/35,0,1)
    radial=np.clip((4.4-radius)/1.4,0,1)
    emission=np.maximum(patch-background,0)*red[:,:,None]*radial[:,:,None]
    # Adjacent points on a tower share timing; separate towers are offset.
    group=0 if cx<200 else 1 if cx<265 else 2 if cx<300 else 3 if cx<350 else 4
    beacons.append((slice(y0,y1),slice(x0,x1),emission,group,cx,cy))
beacon_periods=[2.,2.5,3.,2.5,3.]
beacon_offsets=[.05,.43,.73,.24,.58]
def beacon_level(t,group):
    phase=(t/beacon_periods[group]+beacon_offsets[group])%1
    distance=min(abs(phase-.17),1-abs(phase-.17))
    return .025+1.15*math.exp(-.5*(distance/.105)**2)
def blink_beacons(pixels,t):
    for ys,xs,emission,group,_,_ in beacons:
        pixels[ys,xs]+=(beacon_level(t,group)-1)*emission
    return pixels

# Longer five-car cutout; keep car height, adjust only the track perspective.
train_source=Image.open(folder/'train-sprite-five-cars.png').convert('RGBA')
bbox=train_source.getchannel('A').point(lambda value:255 if value>96 else 0).getbbox()
train_source=train_source.crop(bbox)
train_width=180
train_source=train_source.resize((train_width,round(train_source.height*train_width/train_source.width)),Image.Resampling.NEAREST)
source=np.asarray(train_source)
bottom=np.array([np.where(source[:,column,3]>96)[0][-1] if (source[:,column,3]>96).any() else 0 for column in range(train_width)])
source_slope=(bottom[140:170].mean()-bottom[5:30].mean())/137.5
shear=-.18-source_slope
shifts=np.rint(shear*np.arange(train_width)).astype(int)
padding=-min(0,int(shifts.min()))
projected=np.zeros((source.shape[0]+padding,train_width,4),dtype=np.uint8)
for column,shift in enumerate(shifts):
    yy=padding+int(shift)
    projected[yy:yy+source.shape[0],column]=source[:,column]
train_sprite=Image.fromarray(projected)
train_front_foot=int(np.quantile(bottom[5:30]+padding+shifts[5:30],.85))
train_sprite.save(folder/'train-five-cars-projected.png')
rail_y=275-.18*x
# No artificial left cutoff: the entire consist continues beyond the frame.
train_visibility=((x<=351)&(y<=rail_y+1)).astype(np.uint8)*255
occlusion=Image.new('L',(w,h),0);od=ImageDraw.Draw(occlusion)
# Actual foreground ladder, roof silhouette and utility poles from the scene.
for rect in [(12,168,18,290),(43,168,48,290),(72,168,77,290),
             (150,210,154,290),(156,223,160,290),(169,236,173,290),
             (146,241,174,245)]:
    od.rectangle(rect,fill=255)
od.polygon([(0,248),(80,248),(80,244),(100,244),(100,237),(114,237),
            (114,246),(140,246),(140,250),(180,250),(180,290),(0,290)],fill=255)
train_visibility[np.asarray(occlusion)>0]=0
train_counts=[]

def draw_train(frame,absolute_t):
    front_x=360-(absolute_t-.8)*85
    if absolute_t<.8 or front_x < -train_width-10:
        train_counts.append(0)
        return frame
    top_y=275-.18*front_x-train_front_foot+1
    layer=Image.new('RGBA',(w,h),(0,0,0,0))
    layer.alpha_composite(train_sprite,(round(front_x),round(top_y)))
    clipped=np.minimum(np.asarray(layer.getchannel('A')),train_visibility)
    train_counts.append(int(np.count_nonzero(clipped>96)))
    layer.putalpha(Image.fromarray(clipped))
    return Image.alpha_composite(frame.convert('RGBA'),layer).convert('RGB')

# The least common loop is 60 seconds: three 20s foreground loops and two
# 30s train passes. No time remapping of any accepted animation is needed.
reference=Image.fromarray(np.uint8(np.clip(static,0,255)))
palette=reference.quantize(colors=248);colors=palette.getpalette()
reserved=[(255,87,117),(234,45,75),(124,28,49),(51,24,44),
    (242,186,111),(30,56,91),(94,140,178),(76,222,230)]
for j,color in enumerate(reserved):colors[(248+j)*3:(249+j)*3]=list(color)
palette.putpalette(colors)
encoded=[]
for i in range(1200):
    absolute_t=i/20
    foreground_gif.seek(i%400)
    near_frame=np.asarray(foreground_gif.convert('RGB'),dtype=np.float32)
    pixels=near_frame*(1-reveal[:,:,None])+far*reveal[:,:,None]
    pixels=blink_beacons(pixels,absolute_t)
    frame=Image.fromarray(np.uint8(np.clip(pixels,0,255)))
    frame=draw_train(frame,absolute_t%30)
    if i in [0,70,140,240,670]:frame.save(folder/f'rank-5-v3-preview-{i:04}.png')
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
    if i and i%400==0:print('Rendered',i,'of 1200 frames',flush=True)
output=folder/'rank-5-complete-v3.gif'
encoded[0].save(output,save_all=True,append_images=encoded[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);elapsed=0
beacon_red=[[] for _ in beacons];train_spans=[];minimum=None;maximum=None
for i in range(check.n_frames):
    check.seek(i);elapsed+=check.info['duration']
    a=np.asarray(check.convert('RGB'),dtype=np.int16)
    for j,(_,_,_,_,cx,cy) in enumerate(beacons):beacon_red[j].append(int(a[cy,cx,0]))
    minimum=a.copy() if minimum is None else np.minimum(minimum,a)
    maximum=a.copy() if maximum is None else np.maximum(maximum,a)
assert elapsed==60000 and check.n_frames==1200 and check.info['loop']==0
active=np.flatnonzero(np.array(train_counts)>0)
parts=np.split(active,np.flatnonzero(np.diff(active)>1)+1)
assert len(parts)==2 and all(len(part)>50 for part in parts)
assert all(np.all(np.diff(part)==1) for part in parts),'No mid-pass disappearance'
assert abs((parts[1][0]-parts[0][0])/20-30)<.01
assert len(beacons)==24
ranges=[max(values)-min(values) for values in beacon_red]
assert sum(delta>20 for delta in ranges)>=20,'Beacon blinking survives GIF encoding'
for group in range(5):assert abs(beacon_level(0,group)-beacon_level(60,group))<1e-10
for ys,xs,emission,_,_,_ in beacons:
    assert np.max(emission)>15
# The extinguished second room remains static and dark for the entire minute.
assert np.max((maximum-minimum)[306:333,400:430])==0
for part in parts:print('Continuous train pass:',part[0]/20,'to',part[-1]/20,'seconds')
print('Beacons:',len(beacons),'with',sum(delta>20 for delta in ranges),'visible red intensity swings >20')
print(output,check.size,check.n_frames,'frames, 60-second infinite loop,',output.stat().st_size,'bytes')
