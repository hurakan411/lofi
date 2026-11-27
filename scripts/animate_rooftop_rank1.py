"""Animate the existing rank-1 lamp artwork; no camera or scene changes."""
from pathlib import Path
import math
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'output/concepts/rooftop/stages/rank-1.png'
destination = source.with_name('rank-1-light.gif')
base_image = Image.open(source).convert('RGB')
# Half-size preview keeps a tall GIF light enough to display and share.
width = 438
base_image = base_image.resize((width, round(base_image.height * width / base_image.width)), Image.Resampling.NEAREST)
base = np.asarray(base_image, dtype=np.float32)
# Warm light only: navy darkness remains fixed throughout the loop.
warm = np.clip((base[:, :, 0] - base[:, :, 2] - 8) / 55, 0, 1)
warm *= np.clip((base[:, :, 0] - 15) / 55, 0, 1)

def strength(t):
    # All frequencies close at eight seconds; mixed rhythms avoid a regular pulse.
    value = 0.83 + 0.17 * math.sin(2 * math.pi * t / 8 + .2)
    value += .105 * math.sin(2 * math.pi * 3 * t / 8 + 1.1)
    value += .055 * math.sin(2 * math.pi * 7 * t / 8 + .7)
    for center, depth, spread in [(1.5, .30, .13), (4.3, .23, .19), (6.6, .32, .12)]:
        delta = min(abs(t - center), 8 - abs(t - center))
        value -= depth * math.exp(-.5 * (delta / spread) ** 2)
    return max(.32, min(1.18, value))

palette = Image.fromarray(np.uint8(np.clip(base * (1 + warm[:, :, None] * .2), 0, 255))).quantize(colors=128)
frames = []
for i in range(160):
    value = strength(i / 20)
    pixels = np.uint8(np.clip(base * (1 + warm[:, :, None] * (value - 1)), 0, 255))
    frame = Image.fromarray(pixels).quantize(palette=palette, dither=Image.Dither.NONE)
    frames.append(frame)
frames[0].save(destination, save_all=True, append_images=frames[1:], duration=50, loop=0, disposal=1, optimize=True)
check = Image.open(destination)
assert check.n_frames > 80 and check.info.get('loop') == 0
assert sum((check.seek(i), check.info['duration'])[1] for i in range(check.n_frames)) == 8000
samples = []
for i in range(check.n_frames):
    check.seek(i)
    samples.append(np.asarray(check.convert('RGB'), dtype=np.float32)[warm > .8].mean())
assert max(samples) - min(samples) > 20, 'Lamp must visibly change brightness'
print(f'{destination}\n{check.size}, {check.n_frames} frames, 8 seconds, infinite loop, {destination.stat().st_size:,} bytes')
print(f'Lamp brightness range: {min(samples):.1f}–{max(samples):.1f}')
