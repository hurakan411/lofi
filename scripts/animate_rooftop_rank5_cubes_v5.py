"""Rank 5: rotating cyan cube display, preserving every other v4 pixel."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

folder = Path(__file__).resolve().parents[1]/'output/concepts/rooftop/stages'
source = Image.open(folder/'rank-5-billboards-v4.gif')
w,h = source.size
source.seek(0)
base = source.convert('RGB')
palette = Image.new('P',(1,1)); palette.putpalette(source.getpalette())
rgb_palette = np.array(palette.getpalette(),dtype=np.uint32).reshape(-1,3)
keys = (rgb_palette[:,0]<<16)|(rgb_palette[:,1]<<8)|rgb_palette[:,2]
lookup = np.zeros(1<<24,dtype=np.uint8)
lookup[keys] = np.arange(len(keys),dtype=np.uint8)

# Use only the clean screen interior. Keep facade edges and the two smaller
# overlapping signs in the original animation, outside the edit mask.
crop = (88,143,139,216)
cw,ch = crop[2]-crop[0],crop[3]-crop[1]
plate = Image.open(folder/'rank-5-cubes-clean-plate-v5.png').convert('RGB').resize((cw,ch),Image.Resampling.NEAREST)
mask = Image.new('L',(cw,ch),0)
ImageDraw.Draw(mask).polygon([(6,3),(40,5),(40,62),(27,62),(27,67),(13,67),(13,58),(5,57)],fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(.7))
alpha = np.asarray(mask,dtype=np.float32)/255
old_patch = np.asarray(base.crop(crop),dtype=np.float32)
plate_pixels = old_patch*(1-alpha[:,:,None])+np.asarray(plate,dtype=np.float32)*alpha[:,:,None]
union = np.zeros((h,w),dtype=bool)
union[crop[1]:crop[3],crop[0]:crop[2]] = alpha>0

vertices = np.array([(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]],dtype=float)
edges = [(i,j) for i in range(8) for j in range(i+1,8) if np.sum(vertices[i]!=vertices[j])==1]
faces = [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
scale = 4


def cube(layer, t, lower=False):
    # Upright cubes rotating continuously about their vertical axes. Rates are
    # different but both phases close exactly at 60 seconds.
    period = 15 if lower else 12
    angle = math.pi/4 + (1 if lower else -1)*2*math.pi*(t%period)/period
    x,y,z = vertices.T
    xr = x*math.cos(angle)+z*math.sin(angle)
    depth = -x*math.sin(angle)+z*math.cos(angle)
    center = np.array([111-crop[0], (188 if lower else 166)-crop[1]])
    points = np.stack([xr*10.7, (y*.88-depth*.42)*11.2],axis=1)+center
    projected = [tuple(p*scale) for p in points]
    d = ImageDraw.Draw(layer)
    if lower:
        # Fill the nearer faces, painter-sorted. Darker far faces remain visible
        # only until occluded, with changing shading from the stable light source.
        for face in sorted(faces,key=lambda f: float(depth[f].mean())):
            p = points[face]
            normal = np.cross(np.array([xr[face[1]]-xr[face[0]],y[face[1]]-y[face[0]],depth[face[1]]-depth[face[0]]]),
                              np.array([xr[face[2]]-xr[face[1]],y[face[2]]-y[face[1]],depth[face[2]]-depth[face[1]]]))
            normal /= max(np.linalg.norm(normal),1e-6)
            shade = .57+.43*abs(float(normal@np.array([.6,-.6,.529])))
            color = tuple(int(c*shade) for c in [61,185,200])+(235,)
            d.polygon([projected[i] for i in face],fill=color)
    # Far edges first, closer edges brighter. Fine fixed-pixel widths preserve
    # the scene's pixel-art scale rather than making a smooth vector overlay.
    for i,j in sorted(edges,key=lambda e:float(depth[list(e)].mean())):
        far = float(depth[[i,j]].mean()) < -.2
        color = (53,127,151,190) if far else (118,218,224,255)
        if lower and far:
            continue
        d.line([projected[i],projected[j]],fill=color,width=3 if far else 4)
    # A small bright glint rides one edge; the cube itself does not flash.
    i,j = (3,7) if lower else (0,4)
    phase = ((t/3)+(.35 if lower else 0))%1
    a = np.array(projected[i]); b = np.array(projected[j])
    p = a+(b-a)*phase; q = a+(b-a)*min(phase+.15,1)
    d.line([tuple(p),tuple(q)],fill=(181,239,232,255),width=4)


def patch_at(t):
    layer = Image.new('RGBA',(cw*scale,ch*scale),(0,0,0,0))
    cube(layer,t,False); cube(layer,t,True)
    layer = layer.resize((cw,ch),Image.Resampling.BOX)
    fg = np.asarray(layer,dtype=np.float32)
    a = fg[:,:,3:4]/255
    # Soft local emission; no change to screen border, facade or nearby signs.
    glow = np.asarray(layer.filter(ImageFilter.GaussianBlur(1.1)),dtype=np.float32)
    pixels = plate_pixels+glow[:,:,:3]*(glow[:,:,3:4]/255)*.18
    pixels = pixels*(1-a)+fg[:,:,:3]*a
    pixels = old_patch*(1-alpha[:,:,None])+pixels*alpha[:,:,None]
    return Image.fromarray(np.uint8(np.clip(pixels,0,255)))


assert np.array_equal(np.asarray(patch_at(0)),np.asarray(patch_at(60)))
track = []
for index in range(1200):
    track.append(np.asarray(patch_at(index/20).quantize(palette=palette,dither=Image.Dither.NONE)).copy())

# Render geometry contact sheet first so it can be reviewed while encoding.
sheet = Image.new('RGB',(cw*8*4,ch*8))
for col,index in enumerate([0,30,60,90]):
    image = patch_at(index/20).resize((cw*8,ch*8),Image.Resampling.NEAREST)
    ImageDraw.Draw(image).text((8,8),f'{index/20:.1f}s',fill='white')
    sheet.paste(image,(col*cw*8,0))
sheet.save(folder/'rank-5-cubes-contact-v5.png')

frames = []; duration = 0
local_mask = alpha>0
for index in range(source.n_frames):
    source.seek(index)
    original = np.asarray(source.convert('RGB'),dtype=np.uint32)
    color_keys = (original[:,:,0]<<16)|(original[:,:,1]<<8)|original[:,:,2]
    codes = lookup[color_keys]
    patch = codes[crop[1]:crop[3],crop[0]:crop[2]]
    patch[local_mask] = track[index][local_mask]
    frame = Image.frombytes('P',(w,h),codes.tobytes()); frame.putpalette(palette.getpalette())
    frames.append(frame)
    duration += source.info['duration']
    if index%300==0: print('Composited',index,'/',source.n_frames,flush=True)
assert duration==60000
output = folder/'rank-5-billboards-cubes-v5.gif'
frames[0].save(output,save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=1,optimize=True)
print('Saved',output,output.stat().st_size,'bytes',flush=True)

check = Image.open(output); duration = 0
minimum = np.full((ch,cw,3),255,dtype=np.int16)
maximum = np.zeros((ch,cw,3),dtype=np.int16)
for index in range(check.n_frames):
    check.seek(index); source.seek(index)
    actual = np.asarray(check.convert('RGB'))
    original = np.asarray(source.convert('RGB'))
    assert np.array_equal(actual[~union],original[~union]),index
    patch = actual[crop[1]:crop[3],crop[0]:crop[2]]
    minimum = np.minimum(minimum,patch); maximum = np.maximum(maximum,patch)
    duration += check.info['duration']
assert check.n_frames==1200 and duration==60000 and check.info['loop']==0
for name,ys in [('Upper',slice(6,39)),('Lower',slice(34,61))]:
    variation = (maximum-minimum)[ys,7:40].max(axis=2)
    count = int(np.count_nonzero(variation>20))
    assert count>200
    print(name,'cube:',count,'pixels visibly animate',flush=True)
check.seek(0); check.convert('RGB').save(folder/'rank-5-cubes-preview-v5.png')
print('Verified 60-second infinite loop; all exterior pixels match v4 exactly.',flush=True)
