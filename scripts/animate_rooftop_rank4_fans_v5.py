"""Rank 4 v5: spinning AC rotors behind static grilles, second room lights off."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
source=Image.open(folder/'rank-4-near-traffic-residents-v4.gif')
w,h=source.size
palette=Image.new('P',(1,1));palette.putpalette(source.getpalette())
palette_rgb=np.array(palette.getpalette(),dtype=np.uint32).reshape(-1,3)
keys=(palette_rgb[:,0]<<16)|(palette_rgb[:,1]<<8)|palette_rgb[:,2]
order=np.argsort(keys);sorted_keys=keys[order]
source.seek(0);original0=np.asarray(source.convert('RGB'),dtype=np.float32)

full=Image.open(folder/'rank-4-near.png').convert('RGB')
room=Image.open(folder/'rank-4-second-room-off-generated-v5.png').convert('RGB').resize((177,194),Image.Resampling.NEAREST)
edited=full.copy();edited.paste(room,(698,554))
edited.save(folder/'rank-4-second-room-off-v5.png')
room_pixels=np.asarray(edited.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)
room_mask=Image.new('L',full.size,0)
ImageDraw.Draw(room_mask).polygon([(743,565),(875,568),(875,719),(742,710)],fill=255)
room_mask=room_mask.filter(ImageFilter.GaussianBlur(.65))
room_alpha=np.asarray(room_mask.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)/255

# Native coordinates of the four clear circular fan apertures. Cases and rims
# remain untouched. Different integral revolution counts make the 20s loop exact.
fan_specs=[
    (159.6,435.7,8.1,10.4,12,.2),
    (195.0,432.6,8.0,10.7,15,1.2),
    (357.3,526.8,5.7,6.5,16,2.0),
    (414.0,149.8,5.6,5.5,14,.8),
]
fans=[]
union=room_alpha>0
for cx,cy,rx,ry,cycles,phase in fan_specs:
    x0=max(0,math.floor(cx-rx-1));x1=min(w,math.ceil(cx+rx+2))
    y0=max(0,math.floor(cy-ry-1));y1=min(h,math.ceil(cy+ry+2))
    yy,xx=np.mgrid[y0:y1,x0:x1]
    u=(xx-cx)/rx;v=(yy-cy)/ry
    radius=np.hypot(u,v);angle=np.arctan2(v,u)
    alpha=np.clip((.94-radius)/.12,0,1)*np.clip((radius-.15)/.09,0,1)
    original=original0[y0:y1,x0:x1]
    median=np.median(original[(radius>.25)&(radius<.8)],axis=0)
    flat=np.asarray(Image.fromarray(original.astype(np.uint8)).filter(ImageFilter.GaussianBlur(.65)),dtype=np.float32)
    # Static high-frequency grille detail is overlaid on moving shaded blades.
    grille=(original-flat)*.65
    wire=((np.mod(xx-round(cx),3)==0)|(np.mod(yy-round(cy),3)==0))&(radius<.83)
    union[y0:y1,x0:x1]|=alpha>0
    fans.append((slice(y0,y1),slice(x0,x1),radius,angle,alpha,median,grille,wire,cycles,phase))

def spin_rotors(pixels,t):
    for ys,xs,radius,angle,alpha,median,grille,wire,cycles,phase in fans:
        rotation=2*math.pi*cycles*(t%20)/20+phase
        # Three broad swept blades, perspective-projected into each aperture.
        blades=np.clip((np.cos(3*(angle-rotation)+1.8*radius)-.04)*2.6,0,1)
        dark=median*.58+np.array([0,1,3])
        blade_color=median*.64+np.array([14,16,20])
        rotor=dark[None,None,:]+blades[:,:,None]*blade_color[None,None,:]+grille
        # Fixed grille wires and center hub stay in front of the rotor.
        rotor[wire]=rotor[wire]*.38+(median*.80+2)*.62
        a=alpha[:,:,None]
        pixels[ys,xs]=pixels[ys,xs]*(1-a)+rotor*a
    return pixels

frames=[];elapsed=0
for index in range(source.n_frames):
    source.seek(index);t=elapsed/1000
    original=np.asarray(source.convert('RGB'),dtype=np.float32)
    a=room_alpha[:,:,None]
    pixels=original*(1-a)+room_pixels*a
    pixels=spin_rotors(pixels,t)
    image=Image.fromarray(np.uint8(np.clip(pixels,0,255)))
    quantized=image.quantize(palette=palette,dither=Image.Dither.NONE)
    rgb=original.astype(np.uint32)
    color_keys=(rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
    matches=np.searchsorted(sorted_keys,color_keys)
    assert np.array_equal(sorted_keys[matches],color_keys)
    original_codes=order[matches].astype(np.uint8)
    codes=np.asarray(quantized).copy();codes[~union]=original_codes[~union]
    frame=Image.frombytes('P',(w,h),codes.tobytes());frame.putpalette(palette.getpalette())
    actual=np.asarray(frame.convert('RGB'))
    assert np.array_equal(actual[~union],original.astype(np.uint8)[~union])
    frames.append(frame)
    elapsed+=source.info['duration']
assert elapsed==20000 and len(frames)==400
assert np.array_equal(spin_rotors(original0.copy(),0),spin_rotors(original0.copy(),20))
output=folder/'rank-4-fans-room-off-v5.gif'
frames[0].save(output,save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);duration=0;minimum=None;maximum=None
for index in range(check.n_frames):
    check.seek(index);duration+=check.info['duration']
    rgb=np.asarray(check.convert('RGB'),dtype=np.int16)
    minimum=rgb.copy() if minimum is None else np.minimum(minimum,rgb)
    maximum=rgb.copy() if maximum is None else np.maximum(maximum,rgb)
assert duration==20000 and check.info['loop']==0
for ys,xs,*_ in fans:
    assert np.count_nonzero((maximum-minimum)[ys,xs].max(axis=2)>8)>12,'Rotor remains visible after GIF quantization'
check.seek(0);first=np.asarray(check.convert('RGB'))
lamp=(slice(309,331),slice(404,425))
assert first[lamp].mean()<original0[lamp].mean()*.45,'Second room lamp is off'
assert np.max((maximum-minimum)[room_alpha>.99])==0,'Room stays dark for the entire loop'
check.convert('RGB').save(folder/'rank-4-v5-preview.png')
print('Four rotors animated; cases and grilles fixed; 20-second phase continuity verified')
print('Second room lamp-region mean:',round(float(original0[lamp].mean()),1),'to',round(float(first[lamp].mean()),1))
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
