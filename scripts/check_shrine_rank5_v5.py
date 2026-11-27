from pathlib import Path
from collections import deque
from PIL import Image, ImageChops, ImageStat
import hashlib, json, sys
root=Path('output/concepts/shrine'); folder=root/'rank5-v5'
# The original clerk and all established environmental layers are unchanged.
for name,count in [('connected-writing',6),('fox-only',5),('light-only',5),('hanging-only',6),('maples-only',6),('canopy-only',6),('airborne-only',6)]:
 for j in range(count):
  f=f'{name}-{j}.png'
  assert (folder/f).read_bytes()==(root/'rank5-v4'/f).read_bytes(),f
assert json.loads((folder/'leaf-lifecycle.json').read_text())==json.loads((root/'rank5-v4/leaf-lifecycle.json').read_text())
walkers=json.loads((folder/'walker-lifecycle.json').read_text())
assert len({r['actor'] for r in walkers})==4
assert all(not r['fox'] for r in walkers)
for j in range(11):
 alpha=Image.open(folder/f'walkers-only-{j}.png').getchannel('A')
 assert alpha.crop((430,540,600,660)).getbbox() is None,'walking stair fox remains'
 assert alpha.crop((378,0,600,270)).getbbox() is None,'upper-right walker returned'
body_hashes=set();leg_hashes=set();fractions=[];centroids=[]
for j in range(14):
 im=Image.open(folder/f'tengu-only-{j}.png').convert('RGBA')
 body_hashes.add(hashlib.sha256(im.crop((475,470,510,505)).tobytes()).hexdigest())
 leg_hashes.add(hashlib.sha256(im.crop((475,507,510,525)).tobytes()).hexdigest())
 a=im.getchannel('A').crop((473,470,511,525)); W,H=a.size; pix=a.load()
 remaining={(x,y) for y in range(H) for x in range(W) if pix[x,y]>24}; total=len(remaining);largest=0
 while remaining:
  q=deque([remaining.pop()]);count=0
  while q:
   x,y=q.popleft();count+=1
   for yy in range(max(0,y-1),min(H,y+2)):
    for xx in range(max(0,x-1),min(W,x+2)):
     if (xx,yy) in remaining:remaining.remove((xx,yy));q.append((xx,yy))
  largest=max(largest,count)
 fractions.append(largest/max(1,total)); assert fractions[-1]>.95,('tengu limb disconnect',j,fractions[-1])
 p=im.getchannel('A').load();xs=[]
 for x0,x1 in [(475,491),(491,510)]:
  weight=sum(p[x,y] for y in range(513,524) for x in range(x0,x1))
  xs.append(sum(x*p[x,y] for y in range(513,524) for x in range(x0,x1))/max(1,weight))
 centroids.append(xs)
assert len(body_hashes)==1,'tengu upper body/seat moves'
assert len(leg_hashes)>6,'tengu lower legs static'
assert centroids[3][0]+2<centroids[9][0] and centroids[3][1]>centroids[9][1]+2,('feet do not alternate',centroids)
start=Image.open(folder/'tengu-only-0.png').convert('RGBA');end=Image.open(folder/'tengu-only-13.png').convert('RGBA')
seam=ImageStat.Stat(ImageChops.difference(start,end)).mean
assert max(seam)<.003
report={'walkingStairFoxesRemoved':True,'remainingWalkingVisitors':4,'restingForegroundFoxesPreserved':True,'tenguSeat':[491,502],'tenguHeightPixels':44,'tenguUpperBodyAndSeatFixed':True,'lowerLegsSwingAlternately':True,'legPeriodSeconds':3,'legAngleAmplitudeRadians':.18,'minimumConnectedFraction':min(fractions),'loopMeanDelta':seam,'environmentClerkAnd80LeafPathsPreserved':True,'footCentroids':centroids}
(folder/'motion-fixture-check.json').write_text(json.dumps(report,indent=2)+'\n')
if '--fixtures-only' in sys.argv:
 print(json.dumps(report,indent=2));sys.exit()
im=Image.open(root/'rank-5-shrine-v5.gif');assert im.size==(600,1300) and im.n_frames==2400 and im.info.get('loop')==0
regions={'tengu_body_fixed':(481,475,505,505),'tengu_lower_legs':(479,507,504,523),'door_fixed':(588,930,596,1030),'desk_fixed':(447,1027,466,1031),'basin_fixed':(168,1190,190,1205)}
unique={k:set() for k in regions};duration=0
for i in range(im.n_frames):
 im.seek(i);duration+=im.info.get('duration',0);rgb=im.convert('RGB')
 for k,b in regions.items():unique[k].add(hashlib.sha256(rgb.crop(b).tobytes()).hexdigest())
assert duration==120000
for k,values in unique.items():
 if k.endswith('_fixed'):assert len(values)==1,(k,len(values))
 else:assert len(values)>15,(k,len(values))
assert json.loads((root/'rank-5-timeline-v5.json').read_text())==json.loads((root/'rank-5-timeline-v4.json').read_text())
report.update(file='rank-5-shrine-v5.gif',dimensions=[600,1300],frames=2400,durationMilliseconds=duration,loop='infinite',bytes=(root/'rank-5-shrine-v5.gif').stat().st_size,regionUniqueFrames={k:len(v) for k,v in unique.items()},clerkTimelinePreserved=True)
(root/'rank-5-verification-v5.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
