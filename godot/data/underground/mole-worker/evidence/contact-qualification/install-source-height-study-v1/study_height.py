#!/usr/bin/env python3
"""Inspect an explicitly unadopted raised timber-workpiece source fit; no target is installed or priced."""
from pathlib import Path
import importlib.util,json,hashlib
import numpy as np
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('install_height_author',HERE.parent/'author_install_source.py')
I=importlib.util.module_from_spec(spec);spec.loader.exec_module(I)
M,P,S=I.M,I.P,I.M.S
out=HERE/'study.json'
P.require(not out.exists() and not out.is_symlink(),'INSTALL_HEIGHT_OUTPUT_EXISTS')
paths=[Path(__file__),Path(I.__file__),Path(I.G.__file__),Path(M.__file__),Path(M.D.__file__),Path(I.A.__file__),
       Path(M.C.__file__),Path(M.C.H.__file__),Path(M.W.__file__),Path(M.W.H.__file__),Path(S.__file__),
       Path(P.__file__),Path(P.content.__file__),Path(P.envelope.__file__)]
pins={str(path.relative_to(P.ROOT)):P.content.file_hash(path) for path in paths}
cases,parts,rig,topology,roots,sources,historical=M.read_actual_source()
base,_,_,_=I.source_motion(cases[0],parts[1],rig)
frames=[]
for at in range(17):
 share=at/16;height=128+80-(82*share*share*(3-2*share))
 pose,_=I.poll_pose(cases[0],parts[1],rig,[128,height,-448],35);frames.append(pose['matrices'][0])
work=dict(base,matrices=np.stack(frames+frames[-2::-1]),geometry=parts)
entry=I.A.planted_entry(cases[0],work,rig,31);entry['geometry']=parts
results={}
for name,case in [('work',work),('entry',entry)]:
 results[name]=S.prove(case,parts,topology,rig['rig_binding'],roots,'body')
P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_HEIGHT_SOURCE_DRIFT')
report={'schema':1,'candidate_top_y_u':128,'source_pins':pins,'verified_source_files':sources,'historical_source_snapshot':historical,
        'self':results,'diagnostics':{name:I.pose_diagnostics(case,parts) for name,case in [('work',work),('entry',entry)]},
        'source_equation':'same exact original fixed-link arm/fit; poll_pose target height offset128 only, original planted lower body',
        'scope':'unadopted source-only workpiece-height study; no source patch, target owner, material delivery or assembly permission',
        'production_qualified':False}
with out.open('x') as stream:json.dump(report,stream,indent=2);stream.write('\n')
print(json.dumps({name:{k:row.get(k) for k in ['clear','checks','pairs','intervals']} for name,row in results.items()}))
