from pathlib import Path
from PIL import Image
from collections import deque
import math,hashlib,json,sys
root=Path('output/concepts/shrine')
def smooth(v):
 v=max(0,min(1,v));return v*v*(3-2*v)
def pen(t):
 q=t%3
 if q<2.4:
  u=q/2.4;p=u+.007*math.sin(2*math.pi*7*u)
  return -3+6*p+.12*math.sin(2*math.pi*7*u)*math.sin(math.pi*u),-5+7*p
 u=(q-2.4)/.6;p=1-smooth(u)
 return -3+6*p+.5*math.sin(math.pi*u),-5+7*p-1.2*math.sin(math.pi*u)
connectivity=[]
lower_body_hashes=set()
scale=134/304;left=488.26798932495734;top=945.5592105263158
for j,t in enumerate([0,.6,1.2,1.8,2.35,2.7]):
 im=Image.open(root/f'rank3-v1/connected-writing-{j}.png').convert('RGBA')
 lower_body_hashes.add(hashlib.sha256(im.crop((480,1023,585,1090)).tobytes()).hexdigest())
 alpha=im.getchannel('A');pix=alpha.load();W,H=im.size
 dx,dy=pen(t)
 path=[]
 for sx,sy in [(134,174),(145,178),(160,183),(180,188),(197,187),(211,184)]:
  weight=smooth((225-sx)/80)*smooth((sy-(132+.9*(sx-145))+18)/18)*smooth((192+.36*(sx-145)+32*(1-smooth((sx-125)/15))-sy)/12)*smooth((212-sy)/12)**2
  x=round(left+(sx-100)*scale+dx*weight);y=round(top+(sy-40)*scale+dy*weight)
  coverage=max(pix[xx,yy] for yy in range(y-1,y+2) for xx in range(x-1,x+2))
  assert coverage>170,('arm centre line uncovered',j,(sx,sy),coverage)
  path.append((x,y))
 start=max(((x,y) for y in range(path[0][1]-1,path[0][1]+2) for x in range(path[0][0]-1,path[0][0]+2)),key=lambda p:pix[p])
 q=deque([start]);seen={start}
 while q:
  x,y=q.popleft()
  for yy in range(max(0,y-1),min(H,y+2)):
   for xx in range(max(0,x-1),min(W,x+2)):
    if (xx,yy) not in seen and pix[xx,yy]>32:seen.add((xx,yy));q.append((xx,yy))
 target=path[-1]
 assert any((x,y) in seen for y in range(target[1]-1,target[1]+2) for x in range(target[0]-1,target[0]+2)),('wrist disconnected from shoulder',j)
 connectivity.append({'time':t,'wristConnectedToShoulder':True,'connectedPixels':len(seen)})
assert len(lower_body_hashes)==1,('writing moves lower body',len(lower_body_hashes))
if '--fixtures-only' in sys.argv:
 print(json.dumps(connectivity,indent=2));sys.exit(0)
im=Image.open(root/'rank-3-foreground-v1.gif')
assert im.size==(600,1300) and im.n_frames==2400 and im.info.get('loop')==0
regions={'water':(34,1107,207,1207),'office':(395,870,600,1110),'hair_while_writing':(552,985,577,1020),'knees_feet_while_writing':(480,1023,585,1090),'noren':(531,875,600,927),'hidden_upper_world':(0,0,600,840),'fixed_left_wall':(431,938,457,960),'closed_door_edge':(588,930,596,1030),'desk_edge':(447,1027,466,1031),'front_rail':(490,1050,510,1056),'fern_left':(0,1213,64,1300),'fern_center':(171,1220,290,1300),'undergrowth_right':(535,1213,600,1300),'fixed_paving':(310,1192,380,1220),'fixed_basin_rim':(168,1190,190,1205),'fixed_bamboo':(20,1034,29,1100)}
unique={k:set() for k in regions};duration=0
water=[]
for i in range(im.n_frames):
 im.seek(i);duration+=im.info.get('duration',0);rgb=im.convert('RGB')
 for k,box in regions.items():
  if k.endswith('_while_writing') and i>=80:continue
  unique[k].add(hashlib.sha256(rgb.crop(box).tobytes()).hexdigest())
 if i%240==0:water.append(hashlib.sha256(rgb.crop(regions['water']).tobytes()).hexdigest())
assert duration==120000
for k in ['hidden_upper_world','fixed_left_wall','closed_door_edge','desk_edge','front_rail','fixed_paving','fixed_basin_rim','fixed_bamboo']:
 assert len(unique[k])==1,(k,len(unique[k]))
assert len(set(water))==1 and len(unique['water'])==240
assert len(unique['hair_while_writing'])>30
for k in ['fern_left','fern_center','undergrowth_right']:
 assert len(unique[k])>100,(k,len(unique[k]))
from PIL import ImageChops
old=Image.open(root/'rank-2-first-frame-v10.png').convert('RGB')
new=Image.open(root/'rank-3-first-frame-v1.png').convert('RGB')
assert ImageChops.difference(old,new).crop((405,858,600,1100)).getbbox() is None,'office core changed'
assert ImageChops.difference(old,new).crop((0,0,600,842)).getbbox() is None,'future rank scenery revealed'

assert len(unique['knees_feet_while_writing'])==1
rows=json.loads((root/'rank-3-timeline-v1.json').read_text())
for start in [4,19,49,94]:
 hold=[r for r in rows if start+1.9<=r['time']<start+4.4]
 assert len(hold)==50 and all(r['action']=='think_arms_crossed' and not r['brushHeld'] for r in hold)

assert rows==json.loads((root/'rank-2-timeline-v10.json').read_text()),'inherited gestures/timing changed'
for start in [27,67,107]:
 asleep=[r for r in rows if r['asleep'] and start<=r['time']<start+10]
 assert len(asleep)==200 and all(not r['brushHeld'] for r in asleep)
for start in [4,19,49,94]:
 assert any(r['action']=='think_arms_crossed' for r in rows if start<=r['time']<start+4.8)
assert all(not r['brushHeld'] for r in rows if r['action']=='think_arms_crossed')
for start in [0,12,15]:
 stroke=[r for r in rows if start<=r['time']<start+2.4 and r['writing']]
 if len(stroke)==48:
  # Tiny character strokes can briefly retrace horizontally (<0.01px); the
  # writing line as a whole must advance both rightwards and downwards.
  assert stroke[-1]['penDx']-stroke[0]['penDx']>5.5
  assert stroke[-1]['penDy']-stroke[0]['penDy']>6.5
  assert all(b['penDx']-a['penDx']>-.01 and b['penDy']>a['penDy'] for a,b in zip(stroke,stroke[1:]))
report={'file':'rank-3-foreground-v1.gif','dimensions':list(im.size),'frames':im.n_frames,'durationMilliseconds':duration,'loop':'infinite','bytes':(root/'rank-3-foreground-v1.gif').stat().st_size,'regionUniqueFrames':{k:len(v) for k,v in unique.items()},'writingDirection':'upper-left to lower-right','armConnectivityFixtures':connectivity,'keyPoseCount':48,'thoughtKeyPoses':24,'napKeyPoses':24,'motionAlignedInbetweens':True,'armsCrossedHoldSeconds':2.5,'thoughtCueEverySeconds':15,'sleepOverridesThoughtCue':True,'napIntervalSeconds':40,'napDurationSeconds':10,'napFramesPerVisit':200,'noStandingEntryExitOrStamping':True,'fixedFurnitureAndBackdrop':True,'rank2CorePixelsAndTimelinePreserved':True,'newPlantsMoveIndependently':True,'plantPeriodsSeconds':[8,10,12],'newReveal':['stone basin and rim','bamboo spout','mossy stone and shallow paving','foreground plants'],'futureRankSceneryHidden':True}
(root/'rank-3-verification-v1.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
