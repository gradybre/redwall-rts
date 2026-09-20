"""Execute nineteen reserved-fauna projection/domain mutants without editing product files."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/world_init.gd')
BRIDGE=Path('godot/scripts/core/save_owner_world_init.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in
             ['godot/test/test_save_owner_world_init.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/fauna_validation_focus.gd'],cwd=clone,text=True,
                     stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    (E/(label+'.log')).write_text(p.stdout)
    m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
    valid=m is not None and int(m[1])==EXPECTED and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
    killed=bool(valid and int(m[3])>0 and p.returncode!=0)
    passed=bool(valid and int(m[3])==0 and p.returncode==0)
    row=dict(case=label,exit_code=p.returncode,valid_execution=valid,killed=killed,
             summary=[x for x in p.stdout.splitlines() if '  FAIL ' in x or re.match(r'^\d+ test\(s\)',x)])
    results.append(row); print(json.dumps(row),flush=True)
    assert killed if expect_failure else passed,row


try:
    with tempfile.TemporaryDirectory(prefix='redwall-fauna-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helpers='\nstatic func _mutation_i32(count: int) -> PackedInt32Array:\n\tvar values: PackedInt32Array = PackedInt32Array()\n\tvalues.resize(count)\n\treturn values\n\nstatic func _mutation_i64(count: int) -> PackedInt64Array:\n\tvar values: PackedInt64Array = PackedInt64Array()\n\tvalues.resize(count)\n\treturn values\n'
        fields=['ZONE_SLOT','ZONE_GENERATION','SPECIES_ID','POPULATION','CAPACITY','TRACKS','HARVEST_TODAY','MIGRATION_LINK','BIRTH_REMAINDER']
        for field in fields:
            kind='i64' if field=='BIRTH_REMAINDER' else 'i32'
            variant=replace_once(source,'record.'+kind+'_column(FIELD_'+field+')','_mutation_'+kind+'(384)')+helpers
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        for field in fields:
            parameter=field.lower()
            expected='EntityDirectory.NULL_SLOT' if field=='ZONE_SLOT' else ('EntityDirectory.NULL_GENERATION' if field=='ZONE_GENERATION' else '0')
            expression=parameter+'.count('+expected+') != FAUNA_STOCK_ROWS'
            (clone/OWNER).write_text(replace_once(source,expression,'false'))
            run(clone,'omit-default-'+parameter,True)
        variant=replace_once(source,'birth_remainder.size() != FAUNA_STOCK_ROWS','false')
        (clone/OWNER).write_text(variant)
        run(clone,'omit-i64-shape',True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==21
