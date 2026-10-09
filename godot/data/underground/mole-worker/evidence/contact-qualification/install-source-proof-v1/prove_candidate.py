#!/usr/bin/env python3
"""Source-local/yaw0 adze fixture proof; no workpiece, INSTALL, support or production permission."""
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'author_install_source.py'
SPEC=importlib.util.spec_from_file_location('install_author_proof',SOURCE)
I=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(I)
M,P,S,C=I.M,I.P,I.M.S,I.M.C


def crossing_patch(case,part,roots,vertex):
    """The native point's unknown exact crossing remains inside the rational planar patch, with full residual."""
    matrices=case['matrices'][:,24:25]
    raw=P._vertex_hulls(part,matrices,case['grounding'])
    padding,errors=P._residual_padding(part,matrices,case['grounding'],roots,raw)
    uncertainty=[Fraction(int(value),P.SCALE) for value in padding]
    source=[Fraction(float(value)) for value in part['geometry'][0]['points'][vertex]]
    points=[]
    for at,row in enumerate(matrices[:,0]):
        point=[sum(source[a]*Fraction(float(row[a*3+axis])) for a in range(3))+Fraction(float(row[9+axis]))
               for axis in range(3)]
        point[1]+=Fraction(float(case['grounding'][at]));points.append(point)
    result=[]
    for first,last in P.rendered_intervals(case):
        a,b=points[first],points[last]
        if not (a[1]-uncertainty[1]>0 and b[1]+uncertainty[1]<0): continue
        delta=a[1]-b[1]
        shares=[(a[1]-uncertainty[1])/delta,(a[1]+uncertainty[1])/delta]
        P.require(0<shares[0]<=shares[1]<1,'INSTALL_CONTACT_SHARE')
        low,high=[],[]
        for axis in (0,2):
            values=[((1-share)*a[axis]+share*b[axis])*1024 for share in shares]
            lo,hi=min(values)-uncertainty[axis]*1024,max(values)+uncertainty[axis]*1024
            low.append(lo.numerator//lo.denominator);high.append(-(-hi.numerator//hi.denominator))
        patch=[low[0],0,low[1],high[0],0,high[1]]
        nominal=a[1]/delta
        anchor=[round(((1-nominal)*a[0]+nominal*b[0])*1024),0,
                round(((1-nominal)*a[2]+nominal*b[2])*1024)]
        P.require(patch[0]<patch[3] and patch[2]<patch[5] and all(patch[k]<=anchor[k]<=patch[k+3] for k in range(3)),
                  'INSTALL_CONTACT_PATCH')
        result.append({'source_vertex':vertex,'rendered_edge':[first,last],'anchor_u':anchor,'patch_u':patch,
                       'share_range':[P.envelope.fraction_record(value) for value in shares],'residual_m':errors})
    P.require(bool(result),'INSTALL_NO_GENUINE_CROSSING')
    return result


def contained(box,container):
    return (box is not None and len(box)==len(container)==6 and
            all(type(v) is int for v in box+container) and
            all(container[a]<=box[a]<=box[a+3]<=container[a+3] for a in range(3)))


def main():
    out=HERE/'proof.json';P.require(not out.exists() and not out.is_symlink(),'INSTALL_PROOF_OUTPUT_EXISTS')
    preview=HERE.parent/'install-source-v2'
    candidate=json.loads((preview/'candidate.json').read_text());compiled=json.loads((preview/'compilation.json').read_text())
    pins=dict(candidate['producer_sources'])
    for path in [Path(__file__),preview/'candidate.json',preview/'plan.json',preview/'mole-worker.ugactor',preview/'compilation.json']:
        pins[str(path.relative_to(P.ROOT))]=P.content.file_hash(path)
    P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_PROOF_SOURCE_DRIFT')
    original,parts,rig,topology,roots,sources,historical=M.read_actual_source()
    cases=S.read_image(preview/'mole-worker.ugactor',compiled['content_sha256'],parts)
    wanted=I.source_motion(original[0],parts[1],rig,*candidate['source_recipe']['poll_xz_u'],candidate['source_recipe']['lean_degrees'])[:3]
    P.require(len(cases)==len(wanted)==3,'INSTALL_PROOF_CENSUS')
    for actual,expected in zip(cases,wanted):
        P.require(P.rendered_timing(actual)==P.rendered_timing(expected) and
                  actual['matrices'].tobytes()==expected['matrices'].tobytes() and
                  actual['grounding'].tobytes()==expected['grounding'].tobytes(),'INSTALL_PROOF_SOURCE_EQUATION')
        actual['geometry']=parts
    local={str(clip):P.continuous_floor(case,topology,roots) for clip,case in enumerate(cases)}
    support={}
    for clip,case in enumerate(cases):
        low,high,_,_=C.H.vertex_corners(case,parts[0],0,roots,Fraction(1))
        support[str(clip)]=C.foot_projection(parts[0],topology[0],low,high,local[str(clip)][0]['floor_intersection_u'])
    contacts=crossing_patch(cases[0],parts[1],roots,candidate['poll_source_vertex'])
    whole_contact=local['0'][1]['floor_intersection_u']
    target_checks=[{'assembly':row['assembly'],'kind':row['existing_target_kind'],
        'whole_below_plane_tool_inside_target':contained(whole_contact,row['local_target_box_u']),
        'whole_witness_patch_inside_target':all(contained(contact['patch_u'],row['local_patch_limits_u']) for contact in contacts)}
        for row in candidate['targets']]
    self_results={}
    for clip in (0,1):
        self_results[str(clip)]=S.prove(cases[clip],parts,topology,rig['rig_binding'],roots,'body')
        print('install-proof-clip '+json.dumps({'clip':clip,'clear':self_results[str(clip)]['clear']}),flush=True)
    P.require(S.reusable_timing(cases[2],cases[1],True) and
              cases[2]['matrices'].tobytes()==cases[1]['matrices'][::-1].tobytes() and
              cases[2]['grounding'].tobytes()==cases[1]['grounding'][::-1].tobytes(),'INSTALL_REVERSE_SOURCE')
    self_results['2']=dict(self_results['1'],reused_exact_reverse_clip=1)
    P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_PROOF_SOURCE_DRIFT')
    clear=all(row['clear'] for row in self_results.values()) and all(
        row['whole_below_plane_tool_inside_target'] and row['whole_witness_patch_inside_target'] for row in target_checks)
    report={'schema':1,'content_sha256':compiled['content_sha256'],'source_local_yaw0_clear':clear,
        'native_domain_roots_u':roots,'local':local,'support':support,'contacts':contacts,'target_geometry_checks':target_checks,
        'self':self_results,'source_pins':pins,'verified_source_files':sources,'historical_source_snapshot':historical,
        'remaining':['ACTUAL_TIMBER_WORKPIECE_AND_TARGET_MEANING','ACTUAL_TARGET_AND_SUPPORT_OWNER','ALL_YAW_NATIVE_CONTACT',
                     'PROFILE_STATE_DRIVER_AND_BUILD_JOB_BINDING','WHOLE_FIRST_PREFIX_AND_RETREAT'],
        'scope':'exact finite source-local/yaw0 body/tool/foot and candidate plane only; no actual assembly or INSTALL permission',
        'production_qualified':False}
    with out.open('x') as stream: json.dump(report,stream,indent=2);stream.write('\n')
    print(json.dumps({'source_local_yaw0_clear':clear,'contacts':contacts,'support':support,'production_qualified':False},indent=2))
    return 0 if clear else 2


if __name__=='__main__': sys.exit(main())
