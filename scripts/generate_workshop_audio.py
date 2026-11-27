"""Original, restrained loopable Foley for the ember workshop; no external samples."""
from pathlib import Path
from array import array
import math, random, wave, shutil
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Lofi/Resources/Audio'
RATE=24000
DURATION=24
N=RATE*DURATION
rng=random.Random(271127)

def save(name, values):
    for i in range(600):
        gain=math.sin(i/600*math.pi/2)**2
        values[i]*=gain
        values[-1-i]*=gain
    peak=max(map(abs,values)) or 1
    gain=min(1,.65/peak)
    data=array('h',(round(max(-1,min(1,x*gain))*32767) for x in values))
    with wave.open(str(OUT/f'{name}.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(data.tobytes())
    print(name, '24s, peak', round(peak*gain,3))

# The original quiet charcoal crackle already fits this new world's ember bed.
shutil.copyfile(OUT/'fire.wav',OUT/'embers.wav')
# Reuse the approved original bellows synthesis, with space between each breath.
with wave.open(str(ROOT/'output/audio/bellows-one-shot-v1.wav')) as w:
    rate=w.getframerate();raw=array('h',w.readframes(w.getnframes()))
values=[0.0]*N
for start in [0,5,10,15,20]:
    for j in range(min(int(len(raw)*RATE/rate),N-int(start*RATE))):
        values[int(start*RATE)+j]+=raw[int(j*rate/RATE)]/32768*.72
save('bellows',values)
# Muted anvil strikes: low inharmonic body, softened transient, generous silence.
values=[0.0]*N
for start in range(0,24,2):
    for j in range(min(int(.75*RATE),N-start*RATE)):
        t=j/RATE
        attack=1-math.exp(-t*1100)
        body=sum(amp*math.sin(math.tau*f*t)*math.exp(-t*decay) for f,amp,decay in [(413,.17,12),(731,.085,18),(1189,.035,25)])
        values[start*RATE+j]+=attack*(body+rng.uniform(-1,1)*.035*math.exp(-t*90))
save('hammer',values)
# Occasional short grinding phrases, low-pass friction rather than piercing hiss.
values=[0.0]*N
low=mid=0.0
for i in range(N):
    t=i/RATE;u=t%6
    noise=rng.uniform(-1,1);low+=.035*(noise-low);mid+=.14*(noise-mid)
    envelope=math.sin(math.pi*min(1,u/1.7))**2 if u<1.7 else 0
    values[i]=(low*.65+mid*.16)*envelope*(.9+.1*math.sin(math.tau*t*8))
save('grinder',values)
# Sparse tick/tock and distant soft bell: the final clock is distinct from a forge.
values=[0.0]*N
for k in range(16):
    start=int(k*1.5*RATE)
    for j in range(min(int(.18*RATE),N-start)):
        t=j/RATE
        pitch=680 if k%2==0 else 490
        env=(1-math.exp(-t*1800))*math.exp(-t*68)
        values[start+j]+=.13*env*(math.sin(math.tau*pitch*t)+.23*math.sin(math.tau*pitch*2.13*t))
for start in [1,9,17]:
    for j in range(min(2*RATE,N-start*RATE)):
        t=j/RATE
        values[start*RATE+j]+=.035*(1-math.exp(-t*80))*sum(a*math.sin(math.tau*f*t)*math.exp(-t*d) for f,a,d in [(349,1,2.5),(704,.35,3.8),(1043,.12,5)])
save('clockwork',values)
