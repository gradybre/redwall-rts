"""75 functional source mutations; allocation unit is separate with assertion oracles; no parser/runtime-error kills."""
import hashlib,json,re,shutil,subprocess,tempfile,time
from pathlib import Path
from owner_mutations import once,owner_mutants
ROOT=Path('/var/folders/sr/s947m4s53j199jxj4qrxbtm40000gn/T/redwall-buildings-final-bridge-mmmmh9uf')
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/buildings.gd')
BRIDGE=Path('godot/scripts/core/save_owner_buildings.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_buildings.gd').read_text(),re.M))
results=[]
def run(clone,label,expect_failure):
    start=time.monotonic()
    p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/buildings_validation_focus.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
    (E/(label+'.log')).write_text(p.stdout)
    m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
    valid=m is not None and int(m[1])==EXPECTED and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
    killed=bool(valid and int(m[3])>0 and p.returncode!=0)
    passed=bool(valid and int(m[3])==0 and p.returncode==0)
    row=dict(case=label,oracle='assertions',exit_code=p.returncode,seconds=round(time.monotonic()-start,3),valid_execution=valid,killed=killed,passed=passed,summary=[s for s in p.stdout.splitlines() if '  FAIL ' in s or re.match(r'^\d+ test\(s\)',s)])
    results.append(row);print(json.dumps(row),flush=True)
    assert killed if expect_failure else passed,row
try:
    with tempfile.TemporaryDirectory(prefix='redwall-buildings-mutants-') as scratch:
        clone=Path(scratch);shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        bridge=ORIGINAL[BRIDGE].decode();owner=ORIGINAL[OWNER].decode()
        fields=['b_present', 'r_present', 'f_present', 'b_type_id', 'b_tier', 'b_origin_tile', 'b_rotation', 'b_state', 'b_condition', 'b_construction_slot', 'b_construction_generation', 'b_interior_id', 'r_type', 'r_building_slot', 'r_building_generation', 'r_tile_offset', 'r_tile_count', 'r_temperature_tenths', 'r_furniture_mask', 'r_occupants', 'r_valid', 'f_type_id', 'f_room_slot', 'f_room_generation', 'f_origin_tile', 'f_rotation', 'f_user_slot', 'f_user_generation', 'f_condition']
        for field in fields:
            pattern=r'^\t(?:columns|out)\.'+field+r' = record\.(?:u8|i32|i64)_column\([^\n]+\)$'
            matches=list(re.finditer(pattern,bridge,re.M));assert len(matches)==1,(field,len(matches))
            (clone/BRIDGE).write_text(once(bridge,matches[0][0],'\t# Deliberately omitted '+field+' projection.'))
            run(clone,'omit-projection-'+field,True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==31 and sum(x['killed'] for x in results)==29
