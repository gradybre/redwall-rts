#!/usr/bin/env python3
"""Bounded authoring-only orientation search; sampled tests are never clearance certificates."""
from pathlib import Path
import importlib.util,json,hashlib
import numpy as np
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('install_pose_author',HERE.parent/'author_install_source.py')
I=importlib.util.module_from_spec(spec);spec.loader.exec_module(I)
M,P,S,A,G=I.M,I.P,I.M.S,I.A,I.G

def pose(ready,part,rig,point,lean,azimuth):
 parents,inverse,inv_inverse=A.hierarchy(rig)
 actual,_,fit=A.joints(ready,8,parents,inv_inverse)
 tool=P._affine64(ready['matrices'][8,24]);q,_=P._polar(tool[:3,:3])
 a=np.deg2rad(lean);x=np.array([0.,np.sin(a),np.cos(a)]);y=np.array([-1.,0.,0.])
 b=np.deg2rad(azimuth);spin=np.array([[np.cos(b),0,np.sin(b)],[0,1,0],[-np.sin(b),0,np.cos(b)]])
 tool[:3,:3]=spin@np.stack((x,y,np.cross(x,y)),axis=1)@P._rotation(q).T@tool[:3,:3]
 target=np.asarray(point,dtype=np.float64)/1024;target[1]-=float(ready['grounding'][8])
 tool[:3,3]=target-tool[:3,:3]@part['geometry'][0]['points'][I.POLL_VERTEX]
 hand=tool@np.linalg.inv(fit)
 shoulder,elbow,wrist=[actual[at][:3,3] for at in (17,18,19)]
 middle=G.knee_target(shoulder,elbow,wrist,hand[:3,3])
 moved=[row.copy() for row in actual]
 hand_turn=hand[:3,:3]@np.linalg.inv(actual[19][:3,:3])
 moved[18][:3,:3]=G.rotation_between(hand_turn@(wrist-elbow),hand[:3,3]-middle)@hand_turn@actual[18][:3,:3]
 moved[18][:3,3]=middle
 forearm_turn=moved[18][:3,:3]@np.linalg.inv(actual[18][:3,:3])
 moved[17][:3,:3]=G.rotation_between(forearm_turn@(elbow-shoulder),middle-shoulder)@forearm_turn@actual[17][:3,:3]
 moved[19]=hand
 result=dict(ready,frames=1,matrices=ready['matrices'][8:9].copy(),grounding=ready['grounding'][8:9].copy())
 A.put_pose(result,0,moved,inverse,fit,ready)
 return result

def collisions(case,parts,topology,ids):
 # Rounded float positions diagnose candidates only. They are NOT the interval/native proof.
 bp=G.source_positions(parts[0],case['matrices'][0],case['grounding'][0]);tp=I.prop_points(case,0,parts[1])
 bt=np.rint(bp[topology[0][0][ids]]*1024).astype(np.int64);tt=np.rint(tp[topology[1][0]]*1024).astype(np.int64)
 low,high=bt.min(1),bt.max(1);counter=[0]
 for tool,row in enumerate(tt):
  possible=np.flatnonzero(np.all(low<=row.max(0),axis=1)&np.all(high>=row.min(0),axis=1))
  for body in possible:
   a=np.stack([bt[body],bt[body]]);b=np.stack([row,row])
   if not any(S.projected_separation(a,a,b,b,axis) for axis in S.candidate_axes(a,a,b,b)):
    return {'clear':False,'body_triangle':int(ids[body]),'tool_triangle':tool}
 return {'clear':True}

def main():
 out=HERE/'study.json';P.require(not out.exists() and not out.is_symlink(),'INSTALL_POSE_STUDY_EXISTS')
 cases,parts,rig,topology,roots,sources,historical=M.read_actual_source()
 pins={str(path.relative_to(P.ROOT)):P.content.file_hash(path) for path in [Path(__file__),Path(I.__file__),Path(G.__file__),Path(S.__file__)]}
 ids,_=S.body_triangle_ids(parts[0],topology[0][0],rig['rig_binding'])
 rows=[]
 for x in (128,192):
  for lean in (25,35,45):
   for azimuth in (15,30,45):
    row={'x':x,'lean':lean,'azimuth':azimuth,'samples':[]}
    for height in (208,167,126):
     try:
      case=pose(cases[0],parts[1],rig,[x,height,-448],lean,azimuth)
      result=collisions(case,parts,topology,ids)
     except ValueError as exc:result={'clear':False,'refusal':str(exc)}
     row['samples'].append(dict(height=height,**result))
    rows.append(row);print(json.dumps(row),flush=True)
 P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_POSE_SOURCE_DRIFT')
 out.write_text(json.dumps({'schema':1,'rows':rows,'source_pins':pins,'verified_source_files':sources,
  'scope':'sampled floating authoring diagnostics only; all candidate interval/primitive/native/target proof remains required',
  'production_qualified':False},indent=2)+'\n')
if __name__=='__main__':main()
