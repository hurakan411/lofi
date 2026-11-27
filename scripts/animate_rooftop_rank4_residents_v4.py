"""Add staggered, drawn resident gestures to the approved Rank 4 v3 GIF."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

folder=Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
source=Image.open(folder/'rank-4-near-traffic-v3.gif')
w,h=source.size
palette=Image.new('P',(1,1));palette.putpalette(source.getpalette())
palette_rgb=np.array(palette.getpalette(),dtype=np.uint32).reshape(-1,3)
palette_keys=(palette_rgb[:,0]<<16)|(palette_rgb[:,1]<<8)|palette_rgb[:,2]
key_order=np.argsort(palette_keys);sorted_keys=palette_keys[key_order]
full=Image.open(folder/'rank-4-near.png').convert('RGB')
# Only silhouette neighborhoods change. The rest of each generated edit is unused.
people=[
    ('blue-room',[(754,814),(782,810),(789,817),(789,836),(782,843),(782,854),(754,854)],
     [1.8,8.5,15.4],(.25,.95,.30)),
    ('warm-room-left',[(795,998),(816,998),(823,1014),(834,1019),(835,1037),(814,1042),(796,1037)],
     [4.5,12.3],(.25,.90,.35)),
    ('warm-room-right',[(848,1018),(869,1018),(875,1026),(875,1054),(850,1052),(842,1042),(842,1029)],
     [5.4,13.4],(.25,.65,.30)),
]
variants=[]
for name in ['a','b']:
    crop=Image.open(folder/f'rank-4-residents-pose-{name}.png').convert('RGB').resize((139,292),Image.Resampling.NEAREST)
    image=full.copy();image.paste(crop,(736,788))
    variants.append(np.asarray(image.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32))

masks=[]
for label,polygon,events,timing in people:
    mask=Image.new('L',full.size,0);d=ImageDraw.Draw(mask);d.polygon(polygon,fill=255)
    # Window mullions, the blue room's horizontal sill and the lampshade are fixed.
    d.polygon([(787,788),(796,788),(797,862),(788,862)],fill=0)
    d.polygon([(739,832),(791,834),(791,842),(739,840)],fill=0)
    d.rectangle((835,985,844,1080),fill=0)
    d.polygon([(813,987),(827,987),(834,1004),(807,1004)],fill=0)
    mask=mask.filter(ImageFilter.GaussianBlur(.4))
    masks.append(np.asarray(mask.resize((w,h),Image.Resampling.NEAREST),dtype=np.float32)/255)
union=np.maximum.reduce(masks)>0
assert np.count_nonzero(union)<1300,'Keep animation local to small residents'

def pose_at(t,events,timing):
    lead,hold,returning=timing
    for start in events:
        local=t-start
        if 0<=local<lead:return 0
        if lead<=local<lead+hold:return 1
        if lead+hold<=local<lead+hold+returning:return 0
    return None

frames=[];active=[0]*len(people);duration=0
for index in range(source.n_frames):
    source.seek(index);t=duration/1000
    original=np.asarray(source.convert('RGB'),dtype=np.float32)
    pixels=original.copy()
    active_mask=np.zeros((h,w),dtype=bool)
    for person,mask in enumerate(masks):
        _,_,events,timing=people[person]
        pose=pose_at(t,events,timing)
        if pose is None:continue
        active[person]+=1
        active_mask|=mask>0
        a=mask[:,:,None]
        pixels=pixels*(1-a)+variants[pose]*a
    frame=Image.fromarray(np.uint8(np.clip(pixels,0,255))).quantize(palette=palette,dither=Image.Dither.NONE)
    # Pillow palette quantization can approximate even existing palette colors.
    # Restore exact source indices everywhere without an active resident gesture.
    rgb=original.astype(np.uint32)
    keys=(rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
    matches=np.searchsorted(sorted_keys,keys)
    assert np.array_equal(sorted_keys[matches],keys)
    original_codes=key_order[matches].astype(np.uint8)
    codes=np.asarray(frame).copy();codes[~active_mask]=original_codes[~active_mask]
    frame=Image.frombytes('P',(w,h),codes.tobytes());frame.putpalette(palette.getpalette())
    # Ensure re-encoding never alters the approved traffic or rooftop animation.
    actual=np.asarray(frame.convert('RGB'))
    assert np.array_equal(actual[~union],original.astype(np.uint8)[~union])
    frames.append(frame)
    duration+=source.info['duration']
assert duration==20000 and len(frames)==400
assert all(count>30 for count in active)
for _,_,events,timing in people:
    assert pose_at(0,events,timing) is None and pose_at(19.95,events,timing) is None
output=folder/'rank-4-near-traffic-residents-v4.gif'
frames[0].save(output,save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=1,optimize=True)
check=Image.open(output);elapsed=0
for index in range(check.n_frames):
    check.seek(index);elapsed+=check.info['duration']
assert elapsed==20000 and check.info['loop']==0
for label,count in zip([p[0] for p in people],active):print(label,':',count,'gesture frames')
print('Changed silhouette neighborhood:',np.count_nonzero(union),'native pixels; all other pixels preserved')
print(output,check.size,check.n_frames,'frames, 20-second infinite loop,',output.stat().st_size,'bytes')
