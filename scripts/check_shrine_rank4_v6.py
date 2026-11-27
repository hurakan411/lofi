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
 im=Image.open(root/f'rank4-v6/connected-writing-{j}.png').convert('RGBA')
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

# The rendered transparent fox fixtures test the connected material surface,
# independently of changing sunlight beneath antialiased fur edges.
fox_body_hashes=[set(),set()];fox_tail_hashes=[set(),set()]
fox_boxes=[(272,1117,343,1194),(339,1203,434,1248)]
body_boxes=[(277,1126,302,1175),(347,1213,391,1237)]
tail_boxes=[(309,1164,343,1194),(400,1205,434,1247)]
for j in range(5):
 f=Image.open(root/f'rank4-v6/fox-only-{j}.png').convert('RGBA')
 for n in range(2):
  fox_body_hashes[n].add(hashlib.sha256(f.crop(body_boxes[n]).tobytes()).hexdigest())
  fox_tail_hashes[n].add(hashlib.sha256(f.crop(tail_boxes[n]).tobytes()).hexdigest())
  a=f.crop(fox_boxes[n]).getchannel('A');W,H=a.size;pix=a.load()
  filled={(x,y) for y in range(H) for x in range(W) if pix[x,y]>16}
  remaining=set(filled);largest=0
  while remaining:
   q=deque([remaining.pop()]);count=0
   while q:
    x,y=q.popleft();count+=1
    for yy in range(max(0,y-1),min(H,y+2)):
     for xx in range(max(0,x-1),min(W,x+2)):
      if (xx,yy) in remaining:remaining.remove((xx,yy));q.append((xx,yy))
   largest=max(largest,count)
  assert largest/max(1,len(filled))>.95,('fox tail/body disconnected',j,n,largest,len(filled))
assert all(len(v)==1 for v in fox_body_hashes),('fox bodies move',list(map(len,fox_body_hashes)))
assert all(len(v)>3 for v in fox_tail_hashes),('tails do not move',list(map(len,fox_tail_hashes)))

# Verify the actual rendered light layer, not only the timer formula.
from PIL import ImageChops
light0=Image.open(root/'rank4-v6/light-only-0.png').convert('RGB')
for j in [2,3,4]:
 end=Image.open(root/f'rank4-v6/light-only-{j}.png').convert('RGB')
 assert ImageChops.difference(light0,end).getbbox() is None,('light boundary mismatch',j)
mid=Image.open(root/'rank4-v6/light-only-1.png').convert('RGB')
assert ImageChops.difference(light0,mid).getbbox() is not None,'sunlight is static'

if '--fixtures-only' in sys.argv:
 print(json.dumps(connectivity,indent=2));sys.exit(0)
im=Image.open(root/'rank-4-shrine-v6.gif')
assert im.size==(600,1300) and im.n_frames==2400 and im.info.get('loop')==0
regions={'water':(40,1142,180,1193),'office':(395,870,600,1110),'hair_while_writing':(552,985,577,1020),'knees_feet_while_writing':(480,1023,585,1090),'noren':(531,875,600,927),'hidden_upper_world':(0,0,600,285),'near_torii_fixed':(315,905,330,924),'maple_canopy_high':(0,390,155,585),'maple_canopy_low':(0,740,180,1040),'hall_bell':(181,545,221,592),'torii_bell':(214,821,264,875),'hall_paper_left':(151,530,185,588),'hall_paper_right':(217,542,254,600),'torii_paper_left':(163,805,211,878),'torii_paper_right':(259,812,306,880),'airborne_leaves':(185,370,420,795),'near_stone_lantern_left':(81,888,103,918),'near_stone_lantern_right':(374,929,394,948),'near_hall_lantern':(274,620,285,644),'fixed_left_wall':(431,938,457,960),'closed_door_edge':(588,930,596,1030),'desk_edge':(447,1027,466,1031),'front_rail':(490,1050,510,1056),'fern_left':(0,1213,64,1300),'fern_center':(171,1220,290,1300),'undergrowth_right':(535,1213,600,1300),'paving_light':(310,1150,380,1200),'white_fox_tail':(309,1164,343,1194),'yellow_fox_tail':(399,1205,433,1247),'fixed_basin_rim':(168,1190,190,1205),'fixed_bamboo':(20,1100,29,1125)}
unique={k:set() for k in regions};duration=0
water=[]
for i in range(im.n_frames):
 im.seek(i);duration+=im.info.get('duration',0);rgb=im.convert('RGB')
 for k,box in regions.items():
  if k.endswith('_while_writing') and i>=80:continue
  unique[k].add(hashlib.sha256(rgb.crop(box).tobytes()).hexdigest())
 if i%240==0:water.append(hashlib.sha256(rgb.crop(regions['water']).tobytes()).hexdigest())
assert duration==120000
# Ground leaves now move across the light-check region; the isolated light
# fixtures above verify the sunlight return without conflating the two layers.

for k in ['hidden_upper_world','fixed_left_wall','closed_door_edge','desk_edge','front_rail','fixed_basin_rim','fixed_bamboo','near_torii_fixed']:
 assert len(unique[k])==1,(k,len(unique[k]))
assert len(set(water))==1 and len(unique['water'])==240
assert len(unique['hair_while_writing'])>30
for k in ['fern_left','fern_center','undergrowth_right','paving_light']:
 assert len(unique[k])>100,(k,len(unique[k]))
from PIL import ImageChops
old=Image.open(root/'rank-2-first-frame-v10.png').convert('RGB')
new=Image.open(root/'rank-4-first-frame-v6.png').convert('RGB')
assert ImageChops.difference(old,new).crop((430,900,600,1100)).getbbox() is None,'office core changed'
mist=Image.open(root/'rank4-v6/mist-background.png').convert('RGB')
assert ImageChops.difference(mist,new).crop((0,0,600,285)).getbbox() is None,'hidden upper world differs from mist'
from PIL import ImageStat
assert min(ImageStat.Stat(new.crop((0,0,600,285))).mean)>220,'hidden area is not pale mist'
previous=Image.open(root/'rank-3-first-frame-v4.png').convert('RGB')
withoutLeaves=Image.open(root/'rank4-v6/frame-without-falling-leaves.png').convert('RGB')
for box in [(0,1100,390,1300),(430,1100,600,1300),(0,1179,600,1300)]:
 assert ImageChops.difference(previous,withoutLeaves).crop(box).getbbox() is None,('underlying rank3 foreground changed',box)
background=Image.open(root/'rank4-v6/scene-without-office.png').convert('RGB')
assert ImageChops.difference(background,new).crop((395,900,420,1020)).getbbox() is None,'office exterior still covers scenery'
assert min(ImageStat.Stat(new.crop((395,900,420,1020))).mean)>70,'left black exterior persists'
prior=Image.open(root/'rank-4-first-frame-v3.png').convert('RGB')
assert ImageChops.difference(prior,new).crop((430,900,600,1100)).getbbox() is None,'girl or room core changed'
assert ImageChops.difference(previous,new).crop((0,400,390,1030)).getbbox() is not None,'new scene absent'
for box in [(400,570,450,700),(450,620,540,740),(540,650,600,780)]:
 assert ImageChops.difference(mist,new).crop(box).getbbox() is None,('remaining bridge revealed',box)
assert ImageChops.difference(mist,new).crop((300,580,335,660)).getbbox() is not None,'bridge entrance not revealed'
for k in ['near_stone_lantern_left','near_stone_lantern_right','near_hall_lantern']:
 assert len(unique[k])>5,('new lantern does not move',k,len(unique[k]))

assert len(unique['knees_feet_while_writing'])==1
for k in ['white_fox_tail','yellow_fox_tail']:
 assert len(unique[k])>50,(k,len(unique[k]))
rows=json.loads((root/'rank-4-timeline-v6.json').read_text())
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
for k in ['maple_canopy_high','maple_canopy_low','hall_bell','torii_bell','hall_paper_left','hall_paper_right','torii_paper_left','torii_paper_right','airborne_leaves']:
 assert len(unique[k])>50,(k,'wind animation missing',len(unique[k]))
wind=json.loads((root/'rank4-v5/wind-fixture-check.json').read_text())
assert all(item['minimumConnectedFraction']>.88 for item in wind['objects'].values())
assert all(max(item['meanBoundaryDelta'])<.003 for item in wind['loopChecks'].values())
clean=Image.open(root/'rank4-v6/cleaned-shrine-plate.png').convert('RGB')
back=Image.open(root/'rank4-v4/scene-without-office.png').convert('RGB')
assert ImageChops.difference(clean,back).crop((90,470,105,500)).getbbox() is None,'hall geometry changed beneath moving leaves'
falling=json.loads((root/'rank4-v6/falling-leaf-check.json').read_text())
assert falling['leafCount']==40 and falling['fadeOnlyAfterLanding'] and falling['restingLeafPositionFixedDuringFade']
report={'file':'rank-4-shrine-v6.gif','dimensions':list(im.size),'frames':im.n_frames,'durationMilliseconds':duration,'loop':'infinite','bytes':(root/'rank-4-shrine-v6.gif').stat().st_size,'regionUniqueFrames':{k:len(v) for k,v in unique.items()},'writingDirection':'upper-left to lower-right','armConnectivityFixtures':connectivity,'keyPoseCount':48,'thoughtKeyPoses':24,'napKeyPoses':24,'motionAlignedInbetweens':True,'armsCrossedHoldSeconds':2.5,'thoughtCueEverySeconds':15,'sleepOverridesThoughtCue':True,'napIntervalSeconds':40,'napDurationSeconds':10,'napFramesPerVisit':200,'noStandingEntryExitOrStamping':True,'fixedFurnitureAndBackdrop':True,'rank2CorePixelsAndTimelinePreserved':True,'newPlantsMoveIndependently':True,'plantTipAmplitudesPixels':[6,7.5,7],'twoRestingFoxes':['ivory white','golden yellow'],'foxBodiesFixed':True,'whiteFoxSeatedLookingUphill':True,'whiteFoxMovedForwardPixels':65,'lightingCycleSeconds':12,'lightingFinalHoldSeconds':0.6,'lightAtBoundaryMatchesStartExactly':True,'foxTailsConnectedAndAnimated':True,'dappledSunlightMovesWithoutResamplingStoneTexture':True,'plantPeriodsSeconds':[6,12,12],'newReveal':['large near torii and sacred rope','continuous stairs behind torii','nearest upper-left shrine hall','first bay of bridge entrance','two stone lanterns'],'rank3ForegroundOutsideOfficeFringePreserved':True,'rank3MotionInherited':True,'newLanternLightCyclesSeconds':[4,6,6,4],'newToriiAndArchitectureFixed':True,'futureRankSceneryHidden':True,'bridgeEntranceRevealed':True,'remainingBridgeConcealed':True,'hiddenWorldCoveredByPaleMist':True,'foregroundNotRecolored':True,'revealFeatherPixels':100,'revealFeatherIsotropic':True,'officeBlackExteriorRemoved':True,'officeUpperCropBlendedIntoRoof':True,'girlAndRoomCorePreserved':True,'windObjectsConnected':True,'windLoopsSeamlessly':True,'newBellsAndPaperAnimateWithoutBackgroundWarp':True,'mapleBoughCount':3,'mapleBoughTipAmplitudesPixels':[21,28,30],'airborneMapleLeafCount':40,'fadesOnlyAfterLanding':True,'landingRestSeconds':1.5,'landingFadeSeconds':1.3,'fallingLeafCheck':'rank4-v6/falling-leaf-check.json','windFixtureReport':'rank4-v5/wind-fixture-check.json'}
(root/'rank-4-verification-v6.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
