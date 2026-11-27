from pathlib import Path
from PIL import Image
import hashlib,json
root=Path('output/concepts/shrine')
im=Image.open(root/'rank-2-office-v6.gif')
assert im.size==(600,1300)
assert im.n_frames==240 and im.info.get('loop')==0
regions={'water':(34,1107,207,1207),'writing_hand_and_brush':(494,988,536,1023),'brush_tip':(494,1009,504,1024),'noren':(531,875,600,927),'hidden_upper_world':(0,0,600,840),'head':(518,949,555,981),'seated_body':(518,1026,568,1035),'closed_door':(570,929,593,1030),'resting_seal':(462,1006,470,1019),'paper_away_from_brush':(477,1010,488,1018),'desk_edge':(447,1027,480,1031),'front_rail':(490,1050,510,1056)}
unique={k:set() for k in regions}
duration=0
for i in range(im.n_frames):
 im.seek(i);duration+=im.info.get('duration',0)
 rgb=im.convert('RGB')
 for k,box in regions.items():unique[k].add(hashlib.sha256(rgb.crop(box).tobytes()).hexdigest())
assert duration==12000
for k in ['hidden_upper_world','head','seated_body','closed_door','resting_seal','paper_away_from_brush','desk_edge','front_rail']:
 assert len(unique[k])==1,(k,len(unique[k]))
assert len(unique['writing_hand_and_brush'])>=60
assert len(unique['brush_tip'])>=50
assert len(unique['water'])==240 and len(unique['noren'])>100
trajectory=json.loads((root/'rank-2-pen-trajectory-v6.json').read_text())
for offset in [0,3,6,9]:
 strokes=[r for r in trajectory if offset<=r['time']<offset+2.4 and r['writingDown']]
 assert len(strokes)==48
 assert all(b['nibY']>a['nibY'] for a,b in zip(strokes,strokes[1:]))
 assert strokes[-1]['nibY']-strokes[0]['nibY']>9
 assert max(r['nibX'] for r in strokes)-min(r['nibX'] for r in strokes)<0.5
 assert all(1007<r['nibY']<1025 for r in strokes)
report={'file':'rank-2-office-v6.gif','dimensions':list(im.size),'frames':im.n_frames,'durationMilliseconds':duration,'loop':'infinite','bytes':(root/'rank-2-office-v6.gif').stat().st_size,'regionUniqueFrames':{k:len(v) for k,v in unique.items()},'continuousWriting':True,'topToBottomVerified':True,'writingSecondsPerColumn':2.4,'liftAndReturnSeconds':0.6,'verticalTravelPixels':trajectory[47]['nibY']-trajectory[0]['nibY'],'noThinkingOrDepartureOrStamping':True,'fixedBackgroundPaperAndFurniture':True}
(root/'rank-2-verification-v6.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
