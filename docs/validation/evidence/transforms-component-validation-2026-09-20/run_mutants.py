"""Execute fourteen Transforms projection/domain mutants without editing product files."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/transforms.gd')
BRIDGE=Path('godot/scripts/core/save_owner_transforms.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in
             ['godot/test/test_save_owner_transforms.gd','godot/test/test_transforms.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/transforms_validation_focus.gd'],cwd=clone,text=True,
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
    with tempfile.TemporaryDirectory(prefix='redwall-transforms-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helper='\nstatic func _mutation_zero(count: int) -> PackedInt32Array:\n\tvar values: PackedInt32Array = PackedInt32Array()\n\tvalues.resize(count)\n\treturn values\n'
        for field in ['BOUND_PERSISTENT_ID','X','Y','Z','YAW','PREV_X','PREV_Y','PREV_Z','PREV_YAW']:
            variant=replace_once(source,'record.i32_column(FIELD_'+field+')','_mutation_zero(87552)')+helper
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        domain='\tfor row: int in TRANSFORM_CAPACITY:\n\t\tif bound_persistent_id[row] < 0:\n\t\t\treturn REFUSE_COLUMN_BINDING_ID\n'
        duplicate='\tif _has_duplicate_positive_binding(bound_persistent_id):\n\t\treturn REFUSE_COLUMN_BINDING_DUPLICATE\n'
        free='\tfor row: int in TRANSFORM_CAPACITY:\n\t\tif bound_persistent_id[row] != 0:\n\t\t\tcontinue\n\t\tif x[row] != 0 or y[row] != 0 or z[row] != 0 or yaw[row] != 0 \\\n\t\t\t\tor prev_x[row] != 0 or prev_y[row] != 0 or prev_z[row] != 0 \\\n\t\t\t\tor prev_yaw[row] != 0:\n\t\t\treturn REFUSE_COLUMN_FREE_ROW\n'
        variants={'omit-binding-domain':replace_once(source,domain,''),
                  'omit-binding-uniqueness':replace_once(source,duplicate,''),
                  'omit-free-row':replace_once(source,free,''),
                  'free-before-duplicate':replace_once(source,duplicate+free,free+duplicate),
                  'duplicate-before-domain':replace_once(source,domain+duplicate,duplicate+domain)}
        for label,variant in variants.items():
            (clone/OWNER).write_text(variant)
            run(clone,label,True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==16
