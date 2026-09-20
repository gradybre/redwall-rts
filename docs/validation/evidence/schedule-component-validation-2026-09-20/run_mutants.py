"""Execute twelve Schedule projection/domain mutants without editing product files."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/schedule.gd')
BRIDGE=Path('godot/scripts/core/save_owner_schedule.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in
             ['godot/test/test_save_owner_schedule.gd','godot/test/test_schedule.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/schedule_validation_focus.gd'],cwd=clone,text=True,
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
    with tempfile.TemporaryDirectory(prefix='redwall-schedule-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helpers='\nstatic func _mutation_u8(count: int) -> PackedByteArray:\n\tvar bytes: PackedByteArray = PackedByteArray()\n\tbytes.resize(count)\n\treturn bytes\n\nstatic func _mutation_i32(count: int) -> PackedInt32Array:\n\tvar values: PackedInt32Array = PackedInt32Array()\n\tvalues.resize(count)\n\treturn values\n'
        for field,count,kind in [('PRESENT',512,'u8'),('HOURLY_ACTIVITY',12288,'u8'),('TEMPLATE',512,'i32'),('CURRENT_ACTIVITY',512,'i32'),('SLEEP_SATISFIED',512,'u8'),('RESOLVED',512,'u8')]:
            variant=replace_once(source,'record.'+kind+'_column(FIELD_'+field+')','_mutation_'+kind+'('+str(count)+')')+helpers
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        for label,a,b in [('flags','record.u8_column(FIELD_SLEEP_SATISFIED)','record.u8_column(FIELD_RESOLVED)'),('signed','record.i32_column(FIELD_TEMPLATE)','record.i32_column(FIELD_CURRENT_ACTIVITY)')]:
            variant=replace_once(source,a,'SWAP_MARKER')
            variant=replace_once(variant,b,a)
            variant=replace_once(variant,'SWAP_MARKER',b)
            (clone/BRIDGE).write_text(variant)
            run(clone,'swap-'+label+'-arguments',True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        start=source.index('static func _row_state_refusal(')
        end=source.index('\n\nfunc sleep_satisfied_of(',start)
        body=source[start:end]
        matches=list(re.finditer(r'\tfor slot: int in SCHEDULE_CAPACITY:.*?(?=\tfor slot: int in SCHEDULE_CAPACITY:|\treturn REFUSE_NONE)',body,re.S))
        assert len(matches)==3
        variants={label:replace_once(source,m.group(),'') for label,m in zip(['omit-free-row','omit-unresolved-state','omit-sleep-state'],matches)}
        inverted=body.replace('present[slot] == 1','present[slot] == 0')
        assert inverted!=body
        variants['invert-present-state-gates']=replace_once(source,body,inverted)
        for label,variant in variants.items():
            (clone/OWNER).write_text(variant)
            run(clone,label,True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==14
