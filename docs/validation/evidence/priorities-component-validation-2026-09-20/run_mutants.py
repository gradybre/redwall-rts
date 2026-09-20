"""Execute eight Priorities projection/domain mutants without editing product files."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/priorities.gd')
BRIDGE=Path('godot/scripts/core/save_owner_priorities.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in
             ['godot/test/test_save_owner_priorities.gd','godot/test/test_priorities.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/priorities_validation_focus.gd'],cwd=clone,text=True,
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
    with tempfile.TemporaryDirectory(prefix='redwall-priorities-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helper='\nstatic func _mutation_zero(count: int) -> PackedByteArray:\n\tvar bytes: PackedByteArray = PackedByteArray()\n\tbytes.resize(count)\n\treturn bytes\n'
        for field,count in [('PRESENT',512),('JOB_PRIORITY',6144),('AUTO_FALLBACK',512),('DANGEROUS_WORK',512)]:
            variant=replace_once(source,'record.u8_column(FIELD_'+field+')','_mutation_zero('+str(count)+')')+helper
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        a='record.u8_column(FIELD_AUTO_FALLBACK)'; b='record.u8_column(FIELD_DANGEROUS_WORK)'
        variant=replace_once(source,a,'SWAP_MARKER')
        variant=replace_once(variant,b,a)
        variant=replace_once(variant,'SWAP_MARKER',b)
        (clone/BRIDGE).write_text(variant)
        run(clone,'swap-policy-arguments',True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        reserved='\tfor slot: int in PRIORITY_CAPACITY:\n\t\tif job_priority[slot * JOB_KIND_COUNT + JOB_KIND_RESERVED_INDEX] != PRIORITY_FORBIDDEN:\n\t\t\treturn REFUSE_COLUMN_RESERVED_PRIORITY\n'
        free='\tfor slot: int in PRIORITY_CAPACITY:\n\t\tif present[slot] == 0 \\\n\t\t\t\tand not _free_row_is_clear(job_priority, auto_fallback, dangerous_work, slot):\n\t\t\treturn REFUSE_COLUMN_FREE_ROW\n'
        variants={'omit-reserved-rule':replace_once(source,reserved,''),
                  'omit-free-row-rule':replace_once(source,free,''),
                  'free-before-reserved':replace_once(source,reserved+free,free+reserved)}
        for label,variant in variants.items():
            (clone/OWNER).write_text(variant)
            run(clone,label,True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==10
