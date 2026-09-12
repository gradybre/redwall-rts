#!/usr/bin/env python3
"""Check the September12 specification package; not production runtime verification."""
from pathlib import Path
import datetime, hashlib, heapq, json, re, struct, subprocess
R=Path(__file__).resolve().parents[2]
checks=[]
def check(name,ok,detail=None):
    checks.append({'name':name,'passed':bool(ok),'detail':detail})
    if not ok: raise AssertionError(name)
rig=json.loads((R/'docs/planning/species_rig_identity.json').read_text())
species=json.loads((R/'godot/data/catalog_ids.json').read_text())['domains']['SpeciesDefinition']
check('Complete logical rig species coverage',set(rig['species_rig_id'])==set(species),len(species))
for key,value in rig['species_rig_id'].items():
    check('Rig naming '+key,value=='rig_'+key+'_v1')
check('LifeStage domain',rig['life_stage']=={'ADULT':0,'CHILD':1,'ELDER':2})
check('Existing adult ordinal preserved','const LIFE_STAGE_ADULT: int = 0' in (R/'godot/scripts/core/movement.gd').read_text())
check('Packed additions arithmetic',512+4+3*4*512==6660)
# Independent non-symmetric column byte fixture.
columns=struct.pack('<iiqq',1,258,3,4)
expected='010000000201000003000000000000000400000000000000'
check('Column-major literal byte vector',columns.hex()==expected)
check('Distinct from row-major',columns!=struct.pack('<iqiq',1,3,258,4))
check('RNG section byte count',4+9*4+9*8==112)
# Independent Dijkstra in an open16x16 macro. No runtime route implementation used.
def distance(start,goal):
    q=[(0,start)]; best={start:0}
    while q:
        cost,node=heapq.heappop(q)
        if cost!=best[node]:continue
        if node==goal:return cost
        x,z=node
        for dx,dz in [(0,-1),(1,0),(0,1),(-1,0),(1,-1),(1,1),(-1,1),(-1,-1)]:
            n=(x+dx,z+dz)
            if not (0<=n[0]<16 and 0<=n[1]<16):continue
            v=cost+(14 if dx and dz else 10)
            if v<best.get(n,10**9):best[n]=v;heapq.heappush(q,(v,n))
    return None
optimal=distance((4,4),(8,6)); old=distance((4,4),(0,0))+distance((0,0),(8,6))
check('Reported detour and exact optimum',optimal==48 and old==160,{'old_anchor_composition':old,'exact':optimal})
seed_vectors={1:0,9:0,10:1,19:1,1000:100,10000:1000}
for q,out in seed_vectors.items():check('Seed expiry vector '+str(q),q*100//1000==out)
check('Seed nominal no-gain',all((q//10)*1000<=q*100 for q in range(10001)))
check('Split lots cannot increase output',all(a//10+b//10<=(a+b)//10 for a in range(200) for b in range(200)))
check('Alert inherited usable height',96-2*2==92 and 44+4+44==92)
def pack(heights):
    out=[]; used=0
    for h in heights[:2]:
        remaining=92-used-(4 if out else 0)
        chosen=h if 44<=h<=remaining else 44 if remaining>=44 else None
        if chosen is None:break
        if out:used+=4
        used+=chosen;out.append(chosen)
    return out
for heights,want in [([44,44],[44,44]),([44,60],[44,44]),([60,44],[60]),([93,44],[44,44]),([92,44],[92])]:
    check('Alert packing '+str(heights),pack(heights)==want)
newdocs=[
 'docs/rulings/2026-09-12_clock_restore_and_layout_followup.md',
 'docs/rulings/2026-09-12_movement_dependency_rulings.md',
 'docs/rulings/2026-09-12_alerts_and_seed_expiry.md',
 'docs/rulings/2026-09-12_executor_followup.md']
for name in newdocs:
    p=R/name
    for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if target.startswith(('https://','http://','#')):continue
        local=target.split('#')[0]
        if local=='2026-09-12_followup_validation.json':continue
        check('Local link '+name+' -> '+local,(p.parent/local).exists())
registry=subprocess.run(['python3','docs/validation/state_registry_coverage.py'],cwd=R,capture_output=True,text=True)
# Record unexpected concurrent implementation coverage failures honestly; do not edit code here.
checks.append({'name':'Live state registry coverage','passed':registry.returncode==0,'detail':registry.stdout.strip()+registry.stderr.strip()})
diff=subprocess.run(['git','-c','filter.lfs.required=false','-c','filter.lfs.smudge=','-c','filter.lfs.process=','diff','--check','--','docs'],cwd=R,capture_output=True,text=True)
checks.append({'name':'Documentation whitespace','passed':diff.returncode==0,'detail':diff.stdout.strip()+diff.stderr.strip()})
result={'result':'PASS' if all(c['passed'] for c in checks) else 'FAIL','checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Specification source checks, independent arithmetic/byte fixtures and registry coverage. No production code executed.','checks':checks,'source_document_sha256':{p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in newdocs},'not_verified':['Clock restore implementation','Production codec continuation/rollback','Godot navigation change or path readiness latency','Rendered alert behavior/screenshots','Live seed expiry integration','Rig generation/proportion acceptance','Full MOVE gates and PC-04','Windows/minimum-hardware qualification']}
result['authoring_history']=[{'date':'2026-09-12','check':'Column-major literal byte vector','initial_result':'FAIL','correction':'Removed one extraneous trailing zero byte from the documented24-byte fixture; final check passes against independent little-endian encoding.'}]
(R/'docs/rulings/2026-09-12_followup_validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'result':result['result'],'checks':len(checks),'registry':registry.stdout.strip(),'failed':[c for c in checks if not c['passed']]},indent=2))
raise SystemExit(0 if result['result']=='PASS' else 1)
