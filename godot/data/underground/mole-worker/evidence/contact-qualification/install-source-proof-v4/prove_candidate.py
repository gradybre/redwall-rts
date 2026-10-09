#!/usr/bin/env python3
"""Source-local/yaw0 adze fixture proof; exact target-prism candidate, never INSTALL or production permission."""
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
T_SPEC=importlib.util.spec_from_file_location('install_whole_prisms',HERE.parent/'prove_stair_terrain.py')
T=importlib.util.module_from_spec(T_SPEC);T_SPEC.loader.exec_module(T)


def crossing_patch(case,part,roots,vertex,plane_u=128):
    """The native point's unknown exact crossing remains inside the rational planar patch, with full residual."""
    P.require(type(plane_u) is int and plane_u == 128,'INSTALL_CONTACT_PLANE')
    plane=Fraction(plane_u,1024)
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
        if not (a[1]-uncertainty[1]>plane and b[1]+uncertainty[1]<plane): continue
        delta=a[1]-b[1]
        shares=[(a[1]-plane-uncertainty[1])/delta,(a[1]-plane+uncertainty[1])/delta]
        P.require(0<shares[0]<=shares[1]<1,'INSTALL_CONTACT_SHARE')
        low,high=[],[]
        for axis in (0,2):
            values=[((1-share)*a[axis]+share*b[axis])*1024 for share in shares]
            lo,hi=min(values)-uncertainty[axis]*1024,max(values)+uncertainty[axis]*1024
            low.append(lo.numerator//lo.denominator);high.append(-(-hi.numerator//hi.denominator))
        patch=[low[0],plane_u,low[1],high[0],plane_u,high[1]]
        nominal=(a[1]-plane)/delta
        anchor=[round(((1-nominal)*a[0]+nominal*b[0])*1024),plane_u,
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


def target_prisms(prefix,targets):
    """The full workpiece is a non-supporting target; all existing support prisms remain positive."""
    P.require(targets == I.workpiece_targets(prefix),'INSTALL_EXACT_WORKPIECE')
    result=[]
    for at,target in enumerate(targets):
        origin=target['station_root_u']
        if at == 0:
            solids=[[-2048,-1024,-512,2048,0,1024]]
            sources=['retained exterior earth, ending at exact future pocket edge']
        else:
            sources=[row['name'] for row in prefix['parts'] if row['assembly']==0]
            solids=[[v-origin[axis%3] for axis,v in enumerate(row['bounds_u'])]
                    for row in prefix['parts'] if row['assembly']==0]
            P.require(len(solids)==7,'INSTALL_PRIOR_PART_CENSUS')
        solids.append(target['local_target_box_u'])
        sources.append('paid WIP candidate '+target['source_part_name'])
        result.append({'assembly':at,'solids_u':solids,'source_labels':sources,
                       'support_solid':0,'workpiece_solid':len(solids)-1,'workpiece_support':False})
    return result


def plane_intersection(case,part,triangles,roots,plane_u):
    """Retain the complete active-tool portion below the target plane, including all interiors/residual."""
    matrices=case['matrices'][:,24:25]
    raw=P._vertex_hulls(part,matrices,case['grounding'])
    padding,errors=P._residual_padding(part,matrices,case['grounding'],roots,raw)
    frames=[P._vertex_hulls(part,matrices[f:f+1],case['grounding'][f:f+1])[0] for f in range(case['frames'])]
    boxes=[];indices=set()
    for first,last in P.rendered_intervals(case):
        low=np.stack([frames[first][0],frames[last][0]])-padding
        high=np.stack([frames[first][1],frames[last][1]])+padding
        box=P.clipped_triangle_floor(low,high,triangles,plane_u*(P.SCALE//1024))
        if box is not None: boxes.append(box)
        chosen=np.flatnonzero(low[:,triangles,1].min(axis=(0,2))<=plane_u*(P.SCALE//1024))
        indices.update(int(v) for v in chosen)
    if not boxes:return {'bounds_u':None,'triangles':[],'residual_m':errors}
    low=np.asarray([min(b[a] for b in boxes) for a in range(3)],dtype=np.int64)
    high=np.asarray([max(b[a] for b in boxes) for a in range(3,6)],dtype=np.int64)
    return {'bounds_u':P.outward_units(low,high),'triangles':sorted(indices),'residual_m':errors}


def world_proof(case,parts,topology,roots,fixture,productive,below):
    """Every primitive faces every complete solid; only exact sole residue and active adze target contact differ."""
    boxes_u=fixture['solids_u'];boxes=[np.asarray(b,dtype=np.int64)*(P.SCALE//1024) for b in boxes_u]
    P.require(len(parts)==2 and 2<=len(boxes)<=8 and fixture['support_solid']==0 and
              fixture['workpiece_solid']==len(boxes)-1 and fixture['workpiece_support'] is False,'INSTALL_SOLID_CENSUS')
    for box in boxes_u:
        P.require(len(box)==6 and all(type(v) is int and abs(v)<=8192 for v in box) and
                  all(box[a]<box[a+3] for a in range(3)),'INSTALL_POSITIVE_PRISM')
    target=fixture['workpiece_solid'];allow_tool=productive and contained(below['bounds_u'],boxes_u[target])
    P.require(not productive or allow_tool,'INSTALL_ACTIVE_TOOL_ESCAPES_WORKPIECE')
    counter=[0];pairs=0;contacts=0;target_pairs=0;unresolved=[];support_rows=[];offset=0;exact_cache={}
    def exact(frame,vertex):
        key=(frame,vertex)
        if key not in exact_cache:
            P.require(len(exact_cache)<T.MAX_EXACT_VERTICES,'INSTALL_EXACT_VERTEX_CAPACITY')
            exact_cache[key]=T.exact_source_y(parts[0],case,frame,vertex)
        return exact_cache[key]
    for which,part in enumerate(parts):
        triangles=topology[which][0];P.require(len(part['geometry'])==1 and 0<len(triangles)<=T.MAX_TRIANGLES,'INSTALL_TRIANGLES')
        count=max(1,part['binds']);matrices=case['matrices'][:,offset:offset+count]
        whole=P._vertex_hulls(part,matrices,case['grounding']);padding,_=P._residual_padding(part,matrices,case['grounding'],roots,whole)
        frames=[P._vertex_hulls(part,matrices[f:f+1],case['grounding'][f:f+1])[0] for f in range(case['frames'])]
        memberships=T.foot_membership(part,triangles) if which==0 else []
        for first,last in P.rendered_intervals(case):
            raw_low=np.stack([frames[first][0],frames[last][0]]);raw_high=np.stack([frames[first][1],frames[last][1]])
            low,high=raw_low-padding,raw_high+padding
            if which==0:
                touching=False
                for side,mask in enumerate(memberships):
                    vertices=np.unique(triangles[mask]);foot_low=low[:,vertices];foot_high=high[:,vertices]
                    supported=T.inside_projection(foot_low,foot_high,boxes[0])
                    above=T.source_above_plane(raw_low,raw_high,vertices,(first,last),0,exact)
                    near=vertices[np.flatnonzero(raw_low[:,vertices,1].min(axis=0)<P.SCALE//1024)]
                    witness,gaps=T.contact_witness(near,(first,last),0,exact)
                    touching=touching or witness>=0
                    support_rows.append({'interval':first,'foot':side,'full_projection_inside':supported,'source_above':above,
                        'source_contact_vertex':witness,'contact_gap_u':[P.envelope.fraction_record(v) for v in gaps],
                        'full_foot_bounds_u':P.outward_units(foot_low.min((0,1)),foot_high.max((0,1)))})
                    if not supported or not above:unresolved.append({'kind':'SUPPORT','interval':first,'foot':side})
                if not touching:unresolved.append({'kind':'NO_SOURCE_STANCE_CONTACT','interval':first})
            tl,th=low[:,triangles],high[:,triangles];mn,mx=tl.min((0,2)),th.max((0,2))
            for solid,box in enumerate(boxes):
                possible=np.flatnonzero(np.all(mn<=box[3:],axis=1)&np.all(mx>=box[:3],axis=1))
                for triangle in possible:
                    pairs+=1;contact=False
                    if which==0 and solid==0:
                        contact=any(mask[triangle] and T.inside_projection(tl[:,triangle],th[:,triangle],box) and
                            T.source_above_plane(raw_low,raw_high,triangles[triangle],(first,last),0,exact) for mask in memberships)
                    if contact:contacts+=1
                    elif which==1 and solid==target and allow_tool:target_pairs+=1
                    elif not T.separated_box(tl[:,triangle],th[:,triangle],box,counter):
                        unresolved.append({'kind':'SOLID','part':which,'interval':first,'triangle':int(triangle),'solid':solid})
                    if len(unresolved)>=T.MAX_UNRESOLVED:
                        return {'clear':False,'unresolved':unresolved,'checks':counter[0],'pairs':pairs,'stopped_at_limit':True}
            if first%10==0: print('install-prism-progress '+json.dumps({'assembly':fixture['assembly'],'part':which,
                                  'interval':first,'checks':counter[0],'pairs':pairs}),flush=True)
        offset+=count
    return {'clear':not unresolved,'unresolved':unresolved,'checks':counter[0],'pairs':pairs,
        'numerical_sole_pairs':contacts,'intentional_active_adze_target_pairs':target_pairs,'supports':support_rows,
        'whole_tool_below_target_u':below['bounds_u'],'target_is_worker_support':False,
        'primitive_census':[len(rows[0]) for rows in topology],'intervals':len(P.rendered_intervals(case))}


def main():
    out=HERE/'proof.json';P.require(not out.exists() and not out.is_symlink(),'INSTALL_PROOF_OUTPUT_EXISTS')
    preview=HERE.parent/'install-source-v4'
    compiled=P.content.read_json(preview/'compilation.json',P.content.file_hash(preview/'compilation.json'),65536)
    with (preview/'mole-worker.ugactor').open('rb') as stream:header=stream.read(184)
    P.require(len(header)==184,'INSTALL_IMAGE_HEADER')
    candidate=P.content.read_json(preview/'candidate.json',header[120:152].hex(),1048576)
    pins=dict(candidate['producer_sources'])
    paths=[Path(__file__),Path(T.__file__),preview/'candidate.json',preview/'plan.json',preview/'mole-worker.ugactor',preview/'compilation.json']
    for path in paths:pins[str(path.relative_to(P.ROOT))]=P.content.file_hash(path)
    P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_PROOF_SOURCE_DRIFT')
    original,parts,rig,topology,roots,sources,historical=M.read_actual_source()
    cases=S.read_image(preview/'mole-worker.ugactor',compiled['content_sha256'],parts)
    recipe=candidate['source_recipe'];wanted=I.source_motion(original[0],parts[1],rig,*recipe['poll_xz_u'],recipe['lean_degrees'],recipe['azimuth_degrees'])[:3]
    P.require(len(cases)==len(wanted)==3,'INSTALL_PROOF_CENSUS')
    for actual,expected in zip(cases,wanted):
        P.require(P.rendered_timing(actual)==P.rendered_timing(expected) and actual['matrices'].tobytes()==expected['matrices'].tobytes() and
                  actual['grounding'].tobytes()==expected['grounding'].tobytes(),'INSTALL_PROOF_SOURCE_EQUATION')
        actual['geometry']=parts
    prefix=P.content.read_json(HERE.parent/'stair-sequence-prefix-v1/first-entry-prefix-v1.source.json',I.PREFIX_SHA,65536)
    fixtures=target_prisms(prefix,candidate['targets'])
    contacts=crossing_patch(cases[0],parts[1],roots,candidate['poll_source_vertex'])
    below={str(c):plane_intersection(case,parts[1],topology[1][0],roots,128) for c,case in enumerate(cases)}
    P.require(all(contained(row['patch_u'],target['local_patch_limits_u']) for row in contacts for target in candidate['targets']),
              'INSTALL_CONTACT_PATCH_ESCAPES_TARGET')
    local={str(c):P.continuous_floor(case,topology,roots) for c,case in enumerate(cases)}
    self_results={str(c):S.prove(cases[c],parts,topology,rig['rig_binding'],roots,'body') for c in (0,1)}
    P.require(S.reusable_timing(cases[2],cases[1],True) and cases[2]['matrices'].tobytes()==cases[1]['matrices'][::-1].tobytes() and
              cases[2]['grounding'].tobytes()==cases[1]['grounding'][::-1].tobytes(),'INSTALL_REVERSE_SOURCE')
    self_results['2']=dict(self_results['1'],reused_exact_reverse_clip=1)
    world={str(c):[world_proof(case,parts,topology,roots,fixture,c==0,below[str(c)]) for fixture in fixtures]
           for c,case in enumerate(cases[:2])}
    world['2']=[dict(row,reused_exact_reverse_clip=1) for row in world['1']]
    clear=all(row['clear'] for row in self_results.values()) and all(row['clear'] for group in world.values() for row in group)
    P.require(all(P.content.file_hash(P.ROOT/path)==digest for path,digest in pins.items()),'INSTALL_PROOF_SOURCE_DRIFT')
    report={'schema':1,'content_sha256':compiled['content_sha256'],'source_local_yaw0_candidate_clear':clear,
        'native_domain_roots_u':roots,'local':local,'below_target_plane':below,'contacts':contacts,'fixture_prisms':fixtures,
        'self':self_results,'world':world,'source_pins':pins,'verified_source_files':sources,'historical_source_snapshot':historical,
        'intentional_positive_penetration':'Only active adze shaping contact inside the exact timber workpiece; sole contacts permit numeric residue only, never source penetration.',
        'remaining':['ACTUAL_PAID_WIP_PART_AND_HANDLING','ACTUAL_TARGET_AND_SUPPORT_OWNER','ALL_YAW_NATIVE_CONTACT',
                     'PROFILE_STATE_DRIVER_AND_BUILD_JOB_BINDING','WHOLE_FIRST_PREFIX_AND_RETREAT'],
        'scope':'complete source-local/yaw0 body/tool/foot and fixed engineering prisms only; no actual assembly or INSTALL permission',
        'production_qualified':False}
    with out.open('x') as stream:json.dump(report,stream,indent=2);stream.write('\n')
    print(json.dumps({'source_local_yaw0_candidate_clear':clear,'contacts':contacts,'production_qualified':False},indent=2))
    return 0 if clear else 2

if __name__=='__main__':sys.exit(main())
