#!/usr/bin/env python3
"""Full bounded self proof for one raised, outward-facing adze candidate, still no world permission."""
from pathlib import Path
import importlib.util,json
from fractions import Fraction
import numpy as np
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('install_orientation_study',HERE.parent/'install-source-pose-study-v1/study_pose.py')
D=importlib.util.module_from_spec(spec);spec.loader.exec_module(D)
I,M,P,S=D.I,D.M,D.P,D.S
out=HERE/'study.json';P.require(not out.exists() and not out.is_symlink(),'INSTALL_ORIENTED_EXISTS')
paths=[Path(__file__),Path(D.__file__),Path(I.__file__),Path(I.G.__file__),Path(M.__file__),Path(M.D.__file__),Path(I.A.__file__),
 Path(M.C.__file__),Path(M.C.H.__file__),Path(M.W.__file__),Path(M.W.H.__file__),Path(S.__file__),Path(P.__file__),Path(P.content.__file__),Path(P.envelope.__file__)]
pins={str(path.relative_to(P.ROOT)):P.content.file_hash(path) for path in paths}
cases,parts,rig,topology,roots,sources,historical=M.read_actual_source();frames=[]
for at in range(17):
 t=at/16;case=D.pose(cases[0],parts[1],rig,[128,128+80-82*t*t*(3-2*t),-448],35,30);frames.append(case['matrices'][0])
work=dict(cases[0],frames=33,source_loop_mode=0,duration_q16=32*65536,source_duration_s=Fraction(32,30),matrices=np.stack(frames+frames[-2::-1]),grounding=np.full(33,cases[0]['grounding'][8],dtype=np.float32),geometry=parts)
entry=I.A.planted_entry(cases[0],work,rig,31);entry['geometry']=parts
results={}
for name,case in [('work',work),('entry',entry)]:results[name]=S.prove(case,parts,topology,rig['rig_binding'],roots,'body')
P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_ORIENTED_SOURCE_DRIFT')
report={'schema':1,'contact_u':[128,128,-448],'lean_degrees':35,'azimuth_degrees':30,'source_pins':pins,'verified_source_files':sources,
'historical_source_snapshot':historical,'self':results,'diagnostics':{n:I.pose_diagnostics(c,parts) for n,c in [('work',work),('entry',entry)]},
'scope':'complete source-local/yaw0 body/tool self only; no workpiece/floor/native/INSTALL permission','production_qualified':False}
with out.open('x') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({n:{k:r.get(k) for k in ['clear','checks','pairs','intervals']} for n,r in results.items()}))
