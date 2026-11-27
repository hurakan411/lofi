"""Original synthesized shrine ambience; no external recordings or samples.
These are provisional sound assets, consistent with the existing prototype audio.
"""
from pathlib import Path
import array
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Lofi/Resources/Audio'
RATE = 24000
DURATION = 24
N = RATE * DURATION
rng = random.Random(251125)

def save(name, values):
    # Fade the boundary to silence for click-free loops.
    edge = int(.04 * RATE)
    for i in range(edge):
        values[i] *= i / edge
        values[-i-1] *= i / edge
    pcm = array.array('h', (int(max(-.9, min(.9, value)) * 32767) for value in values))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    print(name, DURATION, 'seconds')

water = [0.] * N
low = 0.
for i in range(N):
    noise = rng.uniform(-1, 1)
    low = low * .93 + noise * .07
    water[i] = (low * .13 + noise * .019) * (.82 + .12 * math.sin(2 * math.pi * i / N))
for start in [rng.uniform(.4, DURATION-.5) for _ in range(95)]:
    offset = int(start * RATE)
    freq = rng.uniform(900, 2100)
    for j in range(int(.12 * RATE)):
        t = j / RATE
        water[offset+j] += .04 * math.sin(2*math.pi*(freq*t + 180*t*t)) * math.exp(-t*45) * min(1, t*900)
save('water', water)

brush = [0.] * N
for start in [i * .75 + rng.uniform(.03, .15) for i in range(31)]:
    offset = int(start * RATE)
    length = int(rng.uniform(.18, .42) * RATE)
    low = 0.
    for j in range(length):
        low = .72 * low + .28 * rng.uniform(-1, 1)
        brush[offset+j] += low * .13 * math.sin(math.pi*j/length)**2
save('brush', brush)

bell = [0.] * N
for start, level in [(3.2, .11), (4.1, .06), (15.7, .085)]:
    offset = int(start * RATE)
    for j in range(int(2.6 * RATE)):
        t = j / RATE
        env = min(1, t*600) * math.exp(-t*2.3)
        bell[offset+j] += level * env * (math.sin(2*math.pi*1500*t) + .35*math.sin(2*math.pi*2418*t) + .18*math.sin(2*math.pi*3197*t))
save('bell', bell)

birds = [0.] * N
for start in [1.3, 1.7, 8.0, 8.4, 17.3, 17.8]:
    offset = int(start * RATE)
    length = int(.22*RATE)
    for j in range(length):
        t = j / RATE
        birds[offset+j] += .055 * math.sin(math.pi*j/length)**2 * math.sin(2*math.pi*(2200*t + 1800*t*t + .7*math.sin(2*math.pi*12*t)))
save('birds', birds)
