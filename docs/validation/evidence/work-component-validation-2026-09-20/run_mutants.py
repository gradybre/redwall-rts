"""Execute twenty-one Work projection/domain mutants without editing product files."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/work.gd')
BRIDGE=Path('godot/scripts/core/save_owner_work.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in
             ['godot/test/test_save_owner_work.gd'])
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/work_validation_focus.gd'],cwd=clone,text=True,
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
    with tempfile.TemporaryDirectory(prefix='redwall-work-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helpers='\nstatic func _mutation_i32(count: int) -> PackedInt32Array:\n\tvar values: PackedInt32Array = PackedInt32Array()\n\tvalues.resize(count)\n\treturn values\n\nstatic func _mutation_u8(count: int) -> PackedByteArray:\n\tvar values: PackedByteArray = PackedByteArray()\n\tvalues.resize(count)\n\treturn values\n'
        fields=['POTENTIAL_REMAINDER','XP_REMAINDER','WEAR_REMAINDER','TOOL_LOT_SLOT','TOOL_LOT_GENERATION','TOOL_JOB_SLOT','TOOL_JOB_GENERATION','TOOL_BROKEN']
        for field in fields:
            kind='u8' if field=='TOOL_BROKEN' else 'i32'
            count=6144 if field=='XP_REMAINDER' else 512
            variant=replace_once(source,'record.'+kind+'_column(FIELD_'+field+')','_mutation_'+kind+'('+str(count)+')')+helpers
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        conditions={
            'potential':'carry < 0 or carry >= WORK_FACTOR_DENOMINATOR',
            'xp':'progress < 0 or progress >= MILLI_WU_PER_WU',
            'reserved-xp':'xp_remainder[row * SKILL_COUNT + SKILL_RESERVED_INDEX] != 0',
            'wear':'wear < 0 or wear >= WEAR_MWU_PER_DURABILITY_POINT',
            'broken':'tool_broken[row] > 1',
            'lot-ref':'not _handle_is_valid(tool_lot_slot[row], tool_lot_generation[row],\n\t\t\t\tGearScript.LOT_CAPACITY)',
            'job-ref':'not _handle_is_valid(tool_job_slot[row], tool_job_generation[row],\n\t\t\t\tGearScript.JOB_CAPACITY)',
            'paired-binding':'bound != (tool_job_slot[row] != NULL_SLOT)',
            'unbound-broken':'not bound and tool_broken[row] != 0',
        }
        for label,expression in conditions.items():
            (clone/OWNER).write_text(replace_once(source,expression,'false'))
            run(clone,'omit-'+label,True)
        (clone/OWNER).write_text(replace_once(source,'memory_total.size() != RESIDENT_CAPACITY','false'))
        run(clone,'omit-memory-shape',True)
        # Safely allow a value refusal to preempt bad shape. Empty arrays still execute,
        # so a script error cannot masquerade as this precedence mutant's witness.
        variant=replace_once(source,'\t\treturn REFUSE_COLUMN_SHAPE',
            '\t\treturn REFUSE_COLUMN_POTENTIAL_REMAINDER if potential_remainder.size() > 0 and potential_remainder[0] < 0 else REFUSE_COLUMN_SHAPE')
        (clone/OWNER).write_text(variant)
        run(clone,'potential-before-shape',True)
        reserved='\tfor row: int in RESIDENT_CAPACITY:\n\t\tif xp_remainder[row * SKILL_COUNT + SKILL_RESERVED_INDEX] != 0:\n\t\t\treturn REFUSE_COLUMN_RESERVED_XP\n'
        wear='\tfor row: int in RESIDENT_CAPACITY:\n\t\tvar wear: int = wear_remainder[row]\n\t\tif wear < 0 or wear >= WEAR_MWU_PER_DURABILITY_POINT:\n\t\t\treturn REFUSE_COLUMN_WEAR_REMAINDER\n'
        (clone/OWNER).write_text(replace_once(source,reserved+wear,wear+reserved))
        run(clone,'wear-before-reserved-xp',True)
        lot='\tfor row: int in RESIDENT_CAPACITY:\n\t\tif not _handle_is_valid(tool_lot_slot[row], tool_lot_generation[row],\n\t\t\t\tGearScript.LOT_CAPACITY):\n\t\t\treturn REFUSE_COLUMN_TOOL_LOT_REF\n'
        job='\tfor row: int in RESIDENT_CAPACITY:\n\t\tif not _handle_is_valid(tool_job_slot[row], tool_job_generation[row],\n\t\t\t\tGearScript.JOB_CAPACITY):\n\t\t\treturn REFUSE_COLUMN_TOOL_JOB_REF\n'
        (clone/OWNER).write_text(replace_once(source,lot+job,job+lot))
        run(clone,'job-ref-before-lot-ref',True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==23
