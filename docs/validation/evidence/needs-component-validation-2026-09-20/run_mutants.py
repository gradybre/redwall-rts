"""Kill the twenty omitted-field mappings and death/order regressions in a disposable clone."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
NEEDS=Path('godot/scripts/core/needs.gd')
BRIDGE=Path('godot/scripts/core/save_owner_needs.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [NEEDS,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(), re.M)) for p in
             ['godot/test/test_save_owner_needs.gd','godot/test/test_needs_columns.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/needs_validation_focus.gd'],cwd=clone,text=True,
                     stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    (E/(label+'.log')).write_text(p.stdout)
    m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
    valid=m is not None and int(m[1])==EXPECTED and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
    killed=bool(valid and int(m[3])>0 and p.returncode!=0)
    passed=bool(valid and int(m[3])==0 and p.returncode==0)
    row=dict(case=label,exit_code=p.returncode,valid_execution=valid,killed=killed,
             summary=[x for x in p.stdout.splitlines() if '  FAIL ' in x or re.match(r'^\d+ test\(s\)',x)])
    results.append(row); print(json.dumps(row),flush=True)
    assert killed if expect_failure else passed, row


try:
    with tempfile.TemporaryDirectory(prefix='redwall-needs-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutant-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        mappings=re.findall(r'^\tcolumns\.([a-z_]+) = record\.(?:u8|i32|i64)_column\(FIELD_[A-Z_]+\)\n',source,re.M)
        assert len(mappings)==20 and len(set(mappings))==20
        for field in mappings:
            pattern=r'^\tcolumns\.'+re.escape(field)+r' = record\.(?:u8|i32|i64)_column\(FIELD_[A-Z_]+\)\n'
            modified,n=re.subn(pattern,'',source,flags=re.M); assert n==1
            (clone/BRIDGE).write_text(modified)
            run(clone,'omit-field-'+field,True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[NEEDS].decode()
        death='\tvar deaths: StringName = _column_health_status_refusal(columns)\n\tif deaths != REFUSE_NONE:\n\t\treturn deaths\n'
        free='\tvar free_rows: StringName = _column_free_row_refusal(columns)\n\tif free_rows != REFUSE_NONE:\n\t\treturn free_rows\n'
        predicate='\t\tif (columns.health[slot] == 0) != (columns.status[slot] == STATUS_DEAD):\n'
        variants={
          'omit-death-rule':replace_once(source,death,''),
          'allow-zero-health-nondead':replace_once(source,predicate,'\t\tif columns.health[slot] > 0 and columns.status[slot] == STATUS_DEAD:\n'),
          'allow-positive-health-dead':replace_once(source,predicate,'\t\tif columns.health[slot] == 0 and columns.status[slot] != STATUS_DEAD:\n'),
          'death-before-free-row':replace_once(source,free+death,death+free),
        }
        for label,modified in variants.items():
            (clone/NEEDS).write_text(modified)
            run(clone,label,True)
        (clone/NEEDS).write_bytes(ORIGINAL[NEEDS])
        run(clone,'mutant-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==26
