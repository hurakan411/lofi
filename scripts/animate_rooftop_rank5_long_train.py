"""Rank 5 v2: five-car train, faster full pass, one appearance per 30-second loop."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
w,h=438,900
read=lambda name: Image.open(folder/name).convert('RGB').resize((w,h),Image.Resampling.NEAREST)
r2=np.asarray(read('rank-2.png'),dtype=np.float32)
r3=np.asarray(read('rank-3.png'),dtype=np.float32)
near_city=np.asarray(read('rank-4-near.png'),dtype=np.float32)
far_city=np.asarray(read('rank-4.png'),dtype=np.float32)
y,x=np.mgrid[:h,:w]
nx,ny=x/w,y/h
# Keep the accepted near-side buildings and road; reveal only the hidden distance.
reveal=np.clip((48-near_city[:,:,0]-near_city[:,:,1])/22,0,1)*np.clip((.43-ny)/.10,0,1)
r4=near_city*(1-reveal[:,:,None])+far_city*reveal[:,:,None]
Image.fromarray(np.uint8(r4)).save(folder/'rank-5-base-v2.png')
# Join STATIC artwork first, then illuminate the whole scene together.
# This avoids seams between independently flickering layers.
core=np.clip((r2.max(axis=2)-18)/18,0,1)
core*=((nx>.20)&(nx<.78)&(ny>.686)&(ny<.86))
core=np.asarray(Image.fromarray(np.uint8(core*255)).filter(ImageFilter.GaussianBlur(.45)),dtype=np.float32)/255
prior=r3*(1-core[:,:,None])+r2*core[:,:,None]
foreground=np.clip((r3.max(axis=2)-18)/18,0,1)
foreground=np.asarray(Image.fromarray(np.uint8(foreground*255)).filter(ImageFilter.GaussianBlur(.35)),dtype=np.float32)/255
foreground*=np.clip((ny-.55)/.025,0,1)
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
# A perspective road path, entirely in front of the still-hidden railway.
road=np.array([(267,340),(268,355),(272,375),(270,395),(274,414),
               (285,438),(295,465),(302,490),(310,518),(313,545)],dtype=float)
distances=np.r_[0,np.cumsum(np.linalg.norm(np.diff(road,axis=0),axis=1))]
distances/=distances[-1]

def road_point(u):
    index=min(len(road)-2,max(0,int(np.searchsorted(distances,u)-1)))
    fraction=(u-distances[index])/(distances[index+1]-distances[index])
    center=road[index]*(1-fraction)+road[index+1]*fraction
    tangent=road[index+1]-road[index];tangent/=np.linalg.norm(tangent)
    normal=np.array([tangent[1],-tangent[0]])
    return center,tangent,normal

def draw_cars(frame,t):
    overlay=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(overlay)
    for phase,reverse,color in [(0.05,False,(96,119,135)),(.42,False,(130,119,98)),(.72,True,(89,112,127))]:
        progress=(t/8+phase)%1
        u=1-progress if reverse else progress
        center,tangent,normal=road_point(u)
        direction=-tangent if reverse else tangent
        center+=normal*((-1 if reverse else 1)*(2+1.5*u))
        length=3+3*u;breadth=1.8+1.1*u
        fade=min(1,u/.065,(1-u)/.065)
        alpha=round(255*max(0,fade))
        corners=[center+direction*length*.5+normal*breadth*.5,
                 center+direction*length*.5-normal*breadth*.5,
                 center-direction*length*.5-normal*breadth*.5,
                 center-direction*length*.5+normal*breadth*.5]
        d.polygon([tuple(np.rint(p).astype(int)) for p in corners],fill=(*color,alpha))
        windshield=center+direction*length*.12
        d.line([tuple(windshield-normal*breadth*.35),tuple(windshield+normal*breadth*.35)],fill=(42,71,86,alpha),width=1)
        for side in [-1,1]:
            head=center+direction*length*.48+normal*breadth*.35*side
            tail=center-direction*length*.48+normal*breadth*.35*side
            d.point(tuple(np.rint(head).astype(int)),fill=(225,205,154,alpha))
            d.point(tuple(np.rint(tail).astype(int)),fill=(164,62,57,alpha))
    return Image.alpha_composite(frame.convert('RGBA'),overlay).convert('RGB')

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

# Indexed frames keep memory bounded for the full 30-second GIF.
reference=np.uint8(np.clip(base*(1+warm[:,:,None]*.18),0,255))
palette=Image.fromarray(reference).quantize(colors=256)
encoded=[]
for i in range(600):
    absolute_t=i/20
    # Four complete background cycles fit exactly in the 30-second delivery.
    t=(absolute_t*32/30)%8
    typing=t%4<2.9
    pattern=[0,1,1,0,2,2,0,1,0,2,2,0,0,1,0,2]
    pose=poses[pattern[int(t*10)%len(pattern)] if typing else 0]
    breeze=math.sin(2*math.pi*t/8)
    second=math.sin(2*math.pi*2*t/8+.8)-math.sin(.8)
    dx=(canopy*1.8+left*1.3+right*1.5)*breeze+(vine*1.6+foreground*1.4)*(.7*breeze+.3*second)
    sx=np.clip(np.rint(x-dx).astype(int),0,w-1)
    pulse=.09*math.sin(2*math.pi*3*t/8)+.045*math.sin(2*math.pi*11*t/8)
    pixels=pose[y,sx]*(1+cyan[y,sx,None]*pulse)*(1+warm[y,sx,None]*(strength(t)-1))
    frame=Image.fromarray(np.uint8(np.clip(pixels,0,255)))
    frame=draw_cars(frame,t)
    frame=draw_train(frame,absolute_t)
    draw=ImageDraw.Draw(frame)
    if i%20<12:
        cx=round(w*(.476+.006*(int(t*2)%4)));cy=round(h*.748)
        draw.line((cx,cy,cx,cy+3),fill=(80,214,221),width=1)
    if typing and i%7<2:
        kx=round(w*(.521+.006*((i//7)%3)));ky=round(h*(.808+.003*((i//14)%2)))
        draw.line((kx,ky,kx+1,ky),fill=(63,107,117),width=1)
    if i==70:
        frame.save(folder/'rank-5-preview-v2.png')
    encoded.append(frame.quantize(palette=palette,dither=Image.Dither.NONE))
output=folder/'rank-5-complete-v2.gif'
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
assert elapsed==30000 and check.n_frames>500
active=np.flatnonzero(np.array(train_counts)>0)
assert len(active)>50 and np.all(np.diff(active)==1), 'One continuous pass, no mid-pass disappearance'
assert active[-1]<160 and not any(train_counts[160:]), 'Only one train in the 30-second loop'
print('Train visible:',round(active[0]/20,2),'to',round(active[-1]/20,2),'seconds; no gaps')
assert np.corrcoef(curves)[0,1]>.97,'Desk lighting must remain continuous'
for label,region in [('typing',(.37,.785,.51,.81)),('lamp',(.62,.70,.70,.79)),('monitor',(.43,.70,.60,.78)),('leaves',(.10,.59,.39,.69)),('cars',(.57,.375,.75,.61)),('train',(.39,.21,.80,.275))]:
    x0,y0,x1,y1=region
    assert (maximum-minimum)[int(y0*h):int(y1*h),int(x0*w):int(x1*w)].max()>10,label
    print(label,'animated')
# Distant architecture and neon stay still; the new motion is the passing train.
assert np.array_equal(minimum[:20,200:220],maximum[:20,200:220])

print('Light correlation:',round(float(np.corrcoef(curves)[0,1]),4))
print(output,check.size,check.n_frames,'frames, 30-second infinite loop,',output.stat().st_size,'bytes')
