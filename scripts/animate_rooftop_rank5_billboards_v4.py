"""Animate only three distant screen interiors over the approved Rank 5 v3 GIF."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

folder = Path(__file__).resolve().parents[1] / 'output/concepts/rooftop/stages'
source = Image.open(folder / 'rank-5-complete-v3.gif')
w, h = source.size
palette = Image.new('P', (1, 1))
palette.putpalette(source.getpalette())
palette_colors = np.array(palette.getpalette(), dtype=np.uint32).reshape(-1, 3)
keys = (palette_colors[:, 0] << 16) | (palette_colors[:, 1] << 8) | palette_colors[:, 2]
lookup = np.zeros(1 << 24, dtype=np.uint8)
lookup[keys] = np.arange(len(keys), dtype=np.uint8)
source.seek(0)
base = np.asarray(source.convert('RGB'))


def projection(quad):
    """Inverse project native screen pixels into normalized display coordinates."""
    matrix, target = [], []
    for (u, v), (x, y) in zip([(0, 0), (1, 0), (1, 1), (0, 1)], quad):
        matrix.extend([[x, y, 1, 0, 0, 0, -u*x, -u*y],
                       [0, 0, 0, x, y, 1, -v*x, -v*y]])
        target.extend([u, v])
    coeff = np.append(np.linalg.solve(matrix, target), 1).reshape(3, 3)
    x0 = math.floor(min(p[0] for p in quad)); x1 = math.ceil(max(p[0] for p in quad))
    y0 = math.floor(min(p[1] for p in quad)); y1 = math.ceil(max(p[1] for p in quad))
    yy, xx = np.mgrid[y0:y1+1, x0:x1+1]
    coords = coeff @ np.stack([xx.ravel(), yy.ravel(), np.ones(xx.size)])
    u, v = (coords[:2] / coords[2]).reshape(2, *xx.shape)
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    return yy[inside], xx[inside], u[inside], v[inside]


def read(name, size):
    return np.asarray(Image.open(folder/name).convert('RGB').resize(size, Image.Resampling.NEAREST), dtype=np.float32)


purple_size = (80, 160)
purple = [read('rank-5-purple-screen-original.png', purple_size),
          read('rank-5-purple-screen-pose-a.png', purple_size),
          read('rank-5-purple-screen-pose-b.png', purple_size)]
cyan_size = (96, 112)
cyan = [read('rank-5-cyan-screen-original.png', cyan_size),
        read('rank-5-cyan-screen-pose-a.png', cyan_size)]


def interpolate_frames(frames, sequence, phase, transition=.12):
    position = phase * len(sequence)
    slot = int(position) % len(sequence)
    local = position - math.floor(position)
    mix = np.clip((local - (1-transition))/transition, 0, 1)
    mix = mix * mix * (3-2*mix)
    return frames[sequence[slot]] * (1-mix) + frames[sequence[(slot+1) % len(sequence)]] * mix


purple_map = projection([(183,65.5),(200,71.8),(199.7,111.7),(182.8,107.6)])
cyan_map = projection([(123.5,117),(135,118.5),(134.5,131.6),(123,129.7)])
wide_map = projection([(275,107.8),(303,115),(303,127),(275,119)])

# The dark vertical frame member is in front of the horizontal screen.
wy, wx, wu, wv = wide_map
keep = ~((wu > .20) & (wu < .30))
wide_map = wy[keep], wx[keep], wu[keep], wv[keep]

union = np.zeros((h, w), dtype=bool)
for yy, xx, _, _ in [purple_map, cyan_map, wide_map]:
    union[yy, xx] = True


def sample(texture, u, v):
    th, tw = texture.shape[:2]
    return texture[np.clip(np.rint(v*(th-1)).astype(int), 0, th-1),
                   np.clip(np.rint(u*(tw-1)).astype(int), 0, tw-1)]


# Preserve the horizontal panel's original palette and coarse motif, then move
# that motif inside its stationary perspective frame.
wide_texture = np.zeros((32, 96, 3), dtype=np.float32)
quad = np.array([(275,107.8),(303,115),(303,127),(275,119)])
for j in range(32):
    v = j/31
    for i in range(96):
        u = i/95
        point = (1-v)*((1-u)*quad[0]+u*quad[1]) + v*((1-u)*quad[3]+u*quad[2])
        wide_texture[j,i] = base[round(point[1]),round(point[0])]


def screen_pixels(kind, t):
    mapping = [purple_map, cyan_map, wide_map][kind]
    yy, xx, u, v = mapping
    if kind == 0:
        phase = (t % 6)/6
        texture = interpolate_frames(purple, [0,1,2,1], phase)
        colors = sample(texture, u, v)
        # Gentle bright ribbon travels across the advertising image, not facade.
        distance = np.abs(((v - .32*u - phase + .5) % 1)-.5)
        ribbon = np.exp(-.5*(distance/.037)**2)
        colors = colors + ribbon[:,None]*np.array([13,9,20])
    elif kind == 1:
        phase = (t % 5)/5
        texture = interpolate_frames(cyan, [0,1,1,0], phase, .18)
        colors = sample(texture, u, v)
        distance = np.abs(((v + phase + .5) % 1)-.5)
        scan = np.exp(-.5*(distance/.065)**2)
        colors = colors + scan[:,None]*np.array([3,23,28])
    else:
        phase = (t % 10)/10
        colors = sample(wide_texture, (u+phase) % 1, v)
        # Moving coarse neon blocks give the horizontal display readable motion.
        wave = np.sin(2*math.pi*(u*2+phase))*.19+.57
        band = np.maximum(0, 1-np.abs(v-wave)/.16)
        colors = colors*.83 + band[:,None]*np.array([34,19,13])
    return np.uint8(np.clip(colors, 0, 255))


# Prequantize short periodic tracks. The original GIF palette already contains
# neon cyan/magenta; every pixel outside these screen masks keeps its exact index.
tracks = []
for kind, period in enumerate([6,5,10]):
    track = []
    for i in range(period*20):
        colors = screen_pixels(kind, i/20)
        strip = Image.fromarray(colors[None,:,:])
        track.append(np.asarray(strip.quantize(palette=palette, dither=Image.Dither.NONE))[0].copy())
    tracks.append(track)
    assert np.array_equal(screen_pixels(kind, 0), screen_pixels(kind, 60))

frames = []; duration = 0
for index in range(source.n_frames):
    source.seek(index)
    original = np.asarray(source.convert('RGB'), dtype=np.uint32)
    color_keys = (original[:,:,0]<<16) | (original[:,:,1]<<8) | original[:,:,2]
    codes = lookup[color_keys]
    for mapping, track in zip([purple_map,cyan_map,wide_map], tracks):
        yy, xx, _, _ = mapping
        codes[yy,xx] = track[index % len(track)]
    frame = Image.frombytes('P', (w,h), codes.tobytes())
    frame.putpalette(palette.getpalette())
    frames.append(frame)
    duration += source.info['duration']
    if index % 200 == 0:
        print(f'Composited {index}/{source.n_frames}', flush=True)
assert duration == 60000
output = folder/'rank-5-billboards-v4.gif'
frames[0].save(output, save_all=True, append_images=frames[1:], duration=50,
               loop=0, disposal=1, optimize=True)
print('Saved', output, output.stat().st_size, 'bytes', flush=True)

# Check the actual encoded GIF against the approved source, including all train,
# beacon, foreground and room pixels outside the three screen interiors.
check = Image.open(output); duration = 0
minimum = np.full((h,w,3), 255, dtype=np.int16)
maximum = np.zeros((h,w,3), dtype=np.int16)
for index in range(check.n_frames):
    check.seek(index); source.seek(index)
    actual = np.asarray(check.convert('RGB'))
    original = np.asarray(source.convert('RGB'))
    assert np.array_equal(actual[~union], original[~union]), index
    minimum = np.minimum(minimum, actual)
    maximum = np.maximum(maximum, actual)
    duration += check.info['duration']
assert check.n_frames == 1200 and duration == 60000 and check.info['loop'] == 0
for name, mapping in zip(['Purple','Cyan','Wide'], [purple_map,cyan_map,wide_map]):
    yy,xx,_,_ = mapping
    variation = (maximum-minimum)[yy,xx].max(axis=1)
    assert np.count_nonzero(variation > 12) > len(yy)*.5
    print(name, len(yy), 'pixels;', np.count_nonzero(variation > 12), 'visibly animated', flush=True)

detail = []
for index in range(600):
    check.seek(index)
    detail.append(check.convert('RGB').crop((110,55,310,141)).resize((800,344),Image.Resampling.NEAREST))
detail[0].save(folder/'rank-5-billboards-detail-v4.gif', save_all=True,
               append_images=detail[1:], duration=50, loop=0, disposal=1, optimize=True)

sheet = Image.new('RGB',(800,344*4),(12,10,25))
for row,index in enumerate([0,30,60,90]):
    check.seek(index)
    image = check.convert('RGB').crop((110,55,310,141)).resize((800,344),Image.Resampling.NEAREST)
    ImageDraw.Draw(image).text((8,8),f'{index/20:.1f}s',fill='white')
    sheet.paste(image,(0,row*344))
sheet.save(folder/'rank-5-billboards-contact-v4.jpg')
print('Verified 60s loop; exact preservation of all pixels outside screen interiors.', flush=True)
