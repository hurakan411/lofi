"""Original placeholder soundscape. No downloaded music or third-party samples."""
from pathlib import Path
import array
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Lofi/Resources/Audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 24000
random.seed(2811)

def save(name, samples):
    # Short edge fades prevent clicks at the loop boundary.
    edge = int(RATE * 0.025)
    for i in range(edge):
        gain = i / edge
        samples[i] *= gain
        samples[-i-1] *= gain
    peak = max(abs(v) for v in samples) or 1
    scale = min(1, .84 / peak)
    pcm = array.array('h', (int(max(-1, min(1, v * scale)) * 32767) for v in samples))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    print(name, len(samples) / RATE, 'seconds', flush=True)

def note(buffer, start, duration, midi, level):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    count = int(duration * RATE)
    offset = int(start * RATE)
    for i in range(count):
        t = i / RATE
        env = (1 - math.exp(-t * 35)) * math.exp(-t * 1.0) * min(1, (duration-t) / .18)
        tone = math.sin(2*math.pi*frequency*t) + .22*math.sin(2*math.pi*frequency*2*t)*math.exp(-t*2) + .07*math.sin(2*math.pi*frequency*3*t)
        buffer[(offset+i) % len(buffer)] += level * env * tone

music = [0.] * (RATE * 32)
chords = [(48, 55, 59, 62, 64), (45, 52, 55, 59, 60), (41, 48, 52, 55, 57), (43, 50, 53, 57, 59)]
for bar in range(8):
    chord = chords[bar % 4]
    start = bar * 4
    for index, midi in enumerate(chord):
        note(music, start + index*.035, 4, midi+12, .034)
    note(music, start, 3.8, chord[0]-12, .060)
    for beat in (0, 2):
        pos = int((start+beat)*RATE)
        for i in range(int(RATE*.20)):
            t = i / RATE
            music[pos+i] += .095*math.sin(2*math.pi*(45*t+1.5*(1-math.exp(-t*25))))*math.exp(-t*25)
    for beat in (1, 3):
        pos = int((start+beat)*RATE)
        for i in range(int(RATE*.12)):
            music[pos+i] += random.uniform(-1,1)*.035*math.exp(-i/RATE*45)
save('music', music)

for name in ('wind', 'rain', 'fire', 'pages'):
    n = RATE * 16
    values = [0.] * n
    low = 0.
    for i in range(n):
        t = i / RATE
        noise = random.uniform(-1, 1)
        low = low*.985 + noise*.015
        if name == 'wind':
            envelope = .5+.18*math.sin(2*math.pi*t/16)+.10*math.sin(2*math.pi*t/4)
            values[i] = low*1.7*envelope + noise*.013
        elif name == 'rain':
            values[i] = (noise*.11+low*.42)*(.85+.10*math.sin(2*math.pi*t/16))
        elif name == 'fire':
            values[i] = low*.8+noise*.022
        else:
            values[i] = 0
    if name in ('fire', 'rain', 'pages'):
        events = 44 if name == 'fire' else 72 if name == 'rain' else 3
        for event in range(events):
            start = random.randint(0, n-RATE//2) if name != 'pages' else int((2.5+event*5)*RATE)
            length = random.randint(70, 600) if name != 'pages' else int(.38*RATE)
            for j in range(length):
                if name == 'pages':
                    envelope = math.sin(math.pi*j/length)**2
                    values[start+j] += random.uniform(-1,1)*envelope*.075
                else:
                    values[start+j] += random.uniform(-1,1)*math.exp(-j/(length/7))*(.18 if name=='fire' else .07)
    save(name, values)
