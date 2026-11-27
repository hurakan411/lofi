"""Coherent rank-2 illumination; retain the rank-1 timing and approved finger poses."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
folder = root / 'output/concepts/rooftop/stages'
rank1 = Image.open(folder / 'rank-1-light.gif')
w, h = rank1.size
art = Image.open(folder / 'rank-2.png').convert('RGB').resize((w, h), Image.Resampling.NEAREST)
base = np.asarray(art, dtype=np.float32)
y, x = np.mgrid[:h, :w]
nx, ny = x / w, y / h
# One continuous lighting pass for lamp, tabletop and reflected warm light.
# Never stitch independently lit left/right portions of the desk.
warm = np.clip((base[:, :, 0] - base[:, :, 2] - 8) / 55, 0, 1)
warm *= np.clip((base[:, :, 0] - 15) / 55, 0, 1)

def strength(t):
    # Same irregular loop as rank 1, now applied to the complete light field.
    value = .83 + .17 * math.sin(2 * math.pi * t / 8 + .2)
    value += .105 * math.sin(2 * math.pi * 3 * t / 8 + 1.1)
    value += .055 * math.sin(2 * math.pi * 7 * t / 8 + .7)
    for center, depth, spread in [(1.5,.30,.13),(4.3,.23,.19),(6.6,.32,.12)]:
        delta = min(abs(t-center), 8-abs(t-center))
        value -= depth * math.exp(-.5 * (delta/spread)**2)
    return max(.32, min(1.18,value))

cyan = np.clip((base[:, :, 2] + base[:, :, 1] - 2 * base[:, :, 0] - 35) / 150, 0, 1)
cyan *= ((nx > .425) & (nx < .602) & (ny > .696) & (ny < .782))
# Drawn finger poses, composited only at the finger joints. No image warping.
full = Image.open(folder / 'rank-2.png').convert('RGB')
poses = [base]
for filename, center in [('typing-pose-a.png', (72, 30)), ('typing-pose-b.png', (123, 52))]:
    variant = Image.open(folder / filename).convert('RGB').resize((190, 95), Image.Resampling.NEAREST)
    cy, cx = np.mgrid[:95, :190]
    distance = ((cx - center[0]) / 18) ** 2 + ((cy - center[1]) / 13) ** 2
    mask = Image.fromarray(np.uint8(np.clip((1 - distance) * 4, 0, 1) * 255))
    pose = full.copy()
    pose.paste(variant, (315, 1387), mask)
    poses.append(np.asarray(pose.resize((w, h), Image.Resampling.NEAREST), dtype=np.float32))
frames = []
for i in range(160):
    t = i / 20
    typing = t % 4 < 2.9
    # Alternating brief presses, release between presses, then a natural pause.
    pattern = [0, 1, 1, 0, 2, 2, 0, 1, 0, 2, 2, 0, 0, 1, 0, 2]
    pose_index = pattern[int(t * 10) % len(pattern)] if typing else 0
    added = poses[pose_index].copy()
    pulse = .09 * math.sin(2 * math.pi * 3 * t / 8) + .045 * math.sin(2 * math.pi * 11 * t / 8)
    added *= 1 + cyan[:, :, None] * pulse
    pixels = added * (1 + warm[:, :, None] * (strength(t) - 1))
    frame = Image.fromarray(np.uint8(np.clip(pixels, 0, 255)))
    draw = ImageDraw.Draw(frame)
    # A small terminal caret and short line of content appear with typing.
    if i % 20 < 12:
        cx = round(w * (.476 + .006 * (int(t * 2) % 4)))
        cy = round(h * .748)
        draw.line((cx, cy, cx, cy + 3), fill=(80, 214, 221), width=1)
    # Restrained keyboard response outside the hand silhouettes.
    if typing and i % 7 < 2:
        kx = round(w * (.521 + .006 * ((i // 7) % 3)))
        ky = round(h * (.808 + .003 * ((i // 14) % 2)))
        draw.line((kx, ky, kx + 1, ky), fill=(63, 107, 117), width=1)
    frames.append(frame)
palette = frames[max(range(160), key=lambda i: strength(i/20))].quantize(colors=224)
encoded = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
destination = folder / 'rank-2-workstation-v4.gif'
encoded[0].save(destination, save_all=True, append_images=encoded[1:], duration=50, loop=0, disposal=1, optimize=True)
check = Image.open(destination)
assert check.n_frames > 100 and check.info['loop'] == 0
elapsed = 0
samples = []
for i in range(check.n_frames):
    check.seek(i)
    elapsed += check.info['duration']
    samples.append(np.asarray(check.convert('RGB')))
assert elapsed == 8000
# Verify independent motions, not a static image or full-frame brightness pulse.
a = np.stack(samples).astype(np.int16)
for label, rect in [('lamp', (.62,.70,.70,.79)), ('screen', (.43,.70,.60,.78))]:
    x0,y0,x1,y1=rect
    region=a[:,int(y0*h):int(y1*h),int(x0*w):int(x1*w)]
    assert np.max(region.max(axis=0)-region.min(axis=0)) > 10, label
    print(label, 'animated')
hands = a[:, int(.785*h):int(.81*h), int(.37*w):int(.51*w)]
assert np.max(hands.max(axis=0)-hands.min(axis=0)) > 10, 'Fingers should articulate'
# Sleeves, wrists and palms outside the small difference masks must be invariant.
variation = np.max(np.stack(poses), axis=0) - np.min(np.stack(poses), axis=0)
assert np.count_nonzero(variation.max(axis=2)) < 450, 'Finger edits must stay local'
print('finger poses animate;', np.count_nonzero(variation.max(axis=2)), 'local changed pixels, no warping')
frames[10].save(folder / 'rank-2-preview-v4.png')
print(destination, check.size, check.n_frames, 'frames, 8 second loop,', destination.stat().st_size, 'bytes')

# Both sides of the former join must follow the same lamp rhythm.
regions = [(236,737,252,750), (281,737,298,750), (278,654,300,677)]
curves = []
for x0,y0,x1,y1 in regions:
    curves.append(a[:,y0:y1,x0:x1].mean(axis=(1,2,3)))
assert np.corrcoef(curves)[0,1] > .97, 'Desk illumination must be continuous'
print('Left/right desk reflection synchronized:', round(float(np.corrcoef(curves)[0,1]),4))
