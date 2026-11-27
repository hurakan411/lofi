from pathlib import Path
from PIL import Image,ImageChops
import json,hashlib
root=Path('output/concepts/shrine');folder=root/'rank5-v6'
for name,count in [('connected-writing',6),('fox-only',5),('light-only',5),('hanging-only',6),('maples-only',6),('canopy-only',6),('airborne-only',6)]:
 for j in range(count):
  f=f'{name}-{j}.png';assert (folder/f).read_bytes()==(root/'rank5-v5'/f).read_bytes(),f
assert json.loads((folder/'leaf-lifecycle.json').read_text())==json.loads((root/'rank5-v5/leaf-lifecycle.json').read_text())
walkers=json.loads((folder/'walker-lifecycle.json').read_text());assert len({r['actor'] for r in walkers})==4 and all(not r['fox'] for r in walkers)
new=Image.open(root/'rank-5-first-frame-v6.png').convert('RGB')
old=Image.open(root/'rank-5-first-frame-v4.png').convert('RGB')
assert ImageChops.difference(new,old).crop((470,460,520,530)).getbbox() is None,'torii not restored'
a=Image.open(folder/'frame-without-falling-leaves.png').convert('RGB');b=Image.open(root/'rank5-v5/frame-without-falling-leaves.png').convert('RGB')
box=ImageChops.difference(a,b).getbbox();assert box and box[0]>=470 and box[1]>=460 and box[2]<=520 and box[3]<=530,('unrelated scene changed',box)
assert json.loads((root/'rank-5-timeline-v6.json').read_text())==json.loads((root/'rank-5-timeline-v5.json').read_text())
im=Image.open(root/'rank-5-shrine-v6.gif');assert im.size==(600,1300) and im.n_frames==2400 and im.info.get('loop')==0
hashes=set()
for i in [0,239,240,799,1599,2399]:
 im.seek(i);hashes.add(hashlib.sha256(im.convert('RGB').crop((470,460,520,530)).tobytes()).hexdigest())
assert len(hashes)==1,'torii retains animated overlay'
r={'file':'rank-5-shrine-v6.gif','dimensions':[600,1300],'frames':2400,'durationSeconds':120,'loop':'infinite','bytes':(root/'rank-5-shrine-v6.gif').stat().st_size,'tenguAndSeatShadowRemoved':True,'originalToriiPixelsRestored':True,'walkingStairFoxesRemainRemoved':True,'restingForegroundFoxesPreserved':True,'onlyTenguRegionChanged':list(box),'all80LeafPathsAndEnvironmentalLayersPreserved':True,'clerkTimelinePreserved':True,'remainingWalkingVisitors':4}
(root/'rank-5-verification-v6.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
