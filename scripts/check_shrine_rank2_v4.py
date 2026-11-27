from pathlib import Path
from PIL import Image
import hashlib,json
root=Path('output/concepts/shrine')
im=Image.open(root/'rank-2-office-v4.gif')
assert im.size==(600,1300)
assert im.n_frames==1200
assert im.info.get('loop')==0
regions={'water':(34,1107,207,1207),'office':(395,870,600,1110),'noren':(531,875,600,927),'hidden_upper_world':(0,0,600,840),'fixed_wall':(431,938,457,960),'front_rail':(490,1050,510,1056)}
unique={k:set() for k in regions}
water_repeat=[]
frames={}
duration=0
for i in range(im.n_frames):
 im.seek(i)
 duration+=im.info.get('duration',0)
 rgb=im.convert('RGB')
 for name,box in regions.items(): unique[name].add(hashlib.sha256(rgb.crop(box).tobytes()).hexdigest())
 if i in [0,240,480,720,960]:water_repeat.append(hashlib.sha256(rgb.crop(regions['water']).tobytes()).hexdigest())
 if i in [280,300,320,880,900,920]:frames[i]=hashlib.sha256(rgb.crop((497,943,591,1036)).tobytes()).hexdigest()
assert duration==60000
assert len(set(water_repeat))==1,'Inherited water must repeat exactly every 12s'
for k in ['hidden_upper_world','fixed_wall','front_rail']:assert len(unique[k])==1,(k,len(unique[k]))
assert len(set(frames.values()))==1,'Girl must be completely absent; furniture/door must remain stationary inside room'
assert len(unique['water'])==240
assert len(unique['noren'])>100
rows=json.loads((root/'rank-2-timeline-v4.json').read_text())
for offset in [0,30]:
 inside=[r for r in rows if r['action']=='inside_room' and offset+12<=r['time']<offset+18]
 assert len(inside)==100
 assert inside[0]['time']==offset+12.3
 assert inside[-1]['time']==offset+17.25
 assert all(r['figureCount']==0 for r in inside)
 assert rows[round((offset+17.3)*20)]['action']=='come_out_after_five_seconds'
for offset in [0,15,30,45]:
 assert rows[round((offset+6)*20)]['action']=='think_arms_behind_head_look_up'
for offset in [0,30]:
 names=[]
 for r in rows:
  if offset+23.3<=r['time']<offset+27.9 and (not names or r['action']!=names[-1]):names.append(r['action'])
 assert names==['put_brush_down','grasp_seal_from_holder','lift_and_position_seal','press_seal_on_ledger','lift_seal_from_paper','return_seal_to_holder','release_seal','pick_up_brush'],names
report={'file':'rank-2-office-v4.gif','dimensions':list(im.size),'frames':im.n_frames,'durationMilliseconds':duration,'loop':'infinite','bytes':(root/'rank-2-office-v4.gif').stat().st_size,'regionUniqueFrames':{k:len(v) for k,v in unique.items()},'waterRepeatsEvery12Seconds':True,'thinkingIntervalSeconds':15,'departureIntervalSeconds':30,'insideRoomSeconds':5,'insideRoomFramesPerVisit':100,'fullyEmptyOfficeVerified':True,'fixedRailWallAndUnrevealedWorld':True,'toolOrderVerified':True}
(root/'rank-2-verification-v4.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
