"""Add the rank-2 workstation to the actual existing rank-1 GIF frames."""
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
# New workstation fades into existing darkness; the lamp region stays rank 1 verbatim.
alpha = np.clip((nx - .195) / .03, 0, 1) * np.clip((.612 - nx) / .018, 0, 1)
alpha *= np.clip((ny - .680) / .012, 0, 1) * np.clip((.867 - ny) / .025, 0, 1)
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
# Decode the variable-duration optimized rank-1 GIF onto its original 20fps timeline.
old_frames = []
for i in range(rank1.n_frames):
    rank1.seek(i)
    frame = np.asarray(rank1.convert('RGB'), dtype=np.float32)
    old_frames.extend([frame] * round(rank1.info['duration'] / 50))
assert len(old_frames) == 160
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
    pixels = old_frames[i] * (1 - alpha[:, :, None]) + added * alpha[:, :, None]
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
palette = frames[0].quantize(colors=192)
encoded = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
destination = folder / 'rank-2-workstation-v3.gif'
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
frames[10].save(folder / 'rank-2-preview-v3.png')
print(destination, check.size, check.n_frames, 'frames, 8 second loop,', destination.stat().st_size, 'bytes')
