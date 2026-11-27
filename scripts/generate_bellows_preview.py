"""Original procedural bellows Foley preview; no recorded samples required."""
from array import array
import math
from pathlib import Path
import random
import wave

RATE = 48000
DURATION = 4.2
OUT = Path(__file__).resolve().parents[1] / 'output/audio/bellows-one-shot-v1.wav'
rng = random.Random(214)
samples = []
low = mid = rumble = friction = 0.0


def swell(t, start, duration, attack=0.22, release=0.4):
    x = t - start
    if x < 0 or x >= duration:
        return 0.0
    a = min(1.0, x / attack)
    r = min(1.0, (duration - x) / release)
    return math.sin(a * math.pi / 2) ** 2 * math.sin(r * math.pi / 2) ** 2


for i in range(round(RATE * DURATION)):
    t = i / RATE
    noise = rng.uniform(-1, 1)
    low += 0.035 * (noise - low)
    mid += 0.19 * (noise - mid)
    rumble += 0.004 * (noise - rumble)
    friction += 0.065 * (rng.uniform(-1, 1) - friction)
    # A long outward breath, followed by a softer intake on recovery.
    press = swell(t, 0.35, 1.85, 0.36, 0.6)
    intake = swell(t, 2.4, 1.15, 0.28, 0.45)
    pressure = press + 0.43 * intake
    turbulence = 0.94 + 0.04 * math.sin(2 * math.pi * 3.1 * t) + 0.02 * math.sin(2 * math.pi * 7.3 * t)
    air = (1.8 * low + 0.40 * (mid - low) + 0.45 * rumble) * pressure * turbulence
    # Restrained leather friction: short, slightly irregular low creaks.
    leather = 0.0
    for start, duration, pitch, gain in [(0.31, .30, 122, .028), (1.75, .25, 101, .018), (2.39, .37, 139, .025)]:
        x = t - start
        env = swell(t, start, duration, .065, .12)
        phase = 2 * math.pi * (pitch * x - 18 * x * x + .12 * math.sin(2 * math.pi * 13 * x))
        leather += gain * env * (math.sin(phase) + .3 * math.sin(2.07 * phase) + 2 * friction)
    # Damped wooden joints, with rounded attacks to avoid sharp clicks.
    wood = 0.0
    for start, gain in [(.32, .036), (2.26, .045), (3.62, .026)]:
        x = t - start
        if 0 <= x < .3:
            env = (1 - math.exp(-x * 700)) * math.exp(-x * 38)
            wood += gain * env * (math.sin(2 * math.pi * 185 * x) + .38 * math.sin(2 * math.pi * 417 * x))
    samples.append(air * .65 + leather + wood)

peak = max(abs(x) for x in samples)
gain = .50 / peak
pcm = array('h', (round(max(-1, min(1, x * gain)) * 32767) for x in samples))
OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), 'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(RATE)
    wav.writeframes(pcm.tobytes())
print(OUT)
print(f'{DURATION:.1f}s, mono, {RATE}Hz, 16-bit; peak -6.02 dBFS')
