"""69 source mutations with assertion oracles; no parser/runtime-error kills."""
import hashlib,json,re,shutil,subprocess,tempfile,time
from pathlib import Path
from owner_mutations import once,owner_mutants
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/field_policy.gd')
BRIDGE=Path('godot/scripts/core/save_owner_field_policy.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_field_policy.gd').read_text(),re.M))
results=[]
def run(clone,label,expect_failure):
    start=time.monotonic()
    p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/field_policy_validation_focus.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (E/(label+'.log')).write_text(p.stdout)
    m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
    valid=m is not None and int(m[1])==EXPECTED and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
    killed=bool(valid and int(m[3])>0 and p.returncode!=0)
    passed=bool(valid and int(m[3])==0 and p.returncode==0)
    row=dict(case=label,oracle='assertions',exit_code=p.returncode,seconds=round(time.monotonic()-start,3),valid_execution=valid,killed=killed,passed=passed,summary=[s for s in p.stdout.splitlines() if '  FAIL ' in s or re.match(r'^\d+ test\(s\)',s)])
    results.append(row);print(json.dumps(row),flush=True)
    assert killed if expect_failure else passed,row
try:
    with tempfile.TemporaryDirectory(prefix='redwall-field-policy-mutants-') as scratch:
        clone=Path(scratch);shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        bridge=ORIGINAL[BRIDGE].decode();owner=ORIGINAL[OWNER].decode()
        fields=['field_present','zone_slot','zone_generation','rotation_ids','rotation_cursor','auto_rotation','seed_reserve','cycle_ordinal','participants','resolved','withdrawn','completed_cycles','cancelled_cycles','requested_crop','cycle_state','close_reason','request_state','plot_field_slot','plot_cycle','plot_outcome']
        for field in fields:
            pattern=r'^\t(?:columns|out)\.'+field+r' = record\.(?:u8|i32)_column\([^\n]+\)$'
            matches=list(re.finditer(pattern,bridge,re.M));assert len(matches)==1,(field,len(matches))
            (clone/BRIDGE).write_text(once(bridge,matches[0][0],'\t# Deliberately omitted '+field+' projection.'))
            run(clone,'omit-projection-'+field,True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        mutations=owner_mutants(owner)
        assert len(mutations)==49
        for label,source in mutations.items():
            (clone/OWNER).write_text(source)
            run(clone,label,True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==71 and sum(x['killed'] for x in results)==69
