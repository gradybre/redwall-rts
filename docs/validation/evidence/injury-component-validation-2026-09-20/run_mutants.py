"""Execute thirty-three Injury accessor/domain/order mutants in an owned clone."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/injury.gd')
BRIDGE=Path('godot/scripts/core/save_owner_injury.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_injury.gd').read_text(),re.M))
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/injury_validation_focus.gd'],cwd=clone,text=True,
                     stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
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
    with tempfile.TemporaryDirectory(prefix='redwall-injury-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helpers=''
        for kind,typ in [('u8','PackedByteArray'),('i32','PackedInt32Array'),('i64','PackedInt64Array')]:
            helpers+='\nstatic func _mutation_'+kind+'() -> '+typ+':\n\tvar values: '+typ+' = '+typ+'()\n\tvalues.resize(512)\n\treturn values\n'
        fields=['PRESENT','KIND','AIRLESS_EPISODE','EXHAUSTION_LATCH','CARE_CONTEXT_BLOCKED','SEVERITY','RESCUER_SLOT','RESCUER_GENERATION','UNTREATED_TICKS','CARE_PROGRESS_MWU','LAST_INCIDENT_ORDINAL']
        for i,field in enumerate(fields):
            kind='u8' if i<5 else ('i32' if i<8 else 'i64')
            variant=replace_once(source,'record.'+kind+'_column(FIELD_'+field+')','_mutation_'+kind+'()')+helpers
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        conditions={
            'present-flag':'not _byte_column_below(present, 2)',
            'airless-flag':'not _byte_column_below(airless_episode, 2)',
            'exhaustion-flag':'not _byte_column_below(exhaustion_latch, 2)',
            'context-flag':'not _byte_column_below(care_context_blocked, 2)',
            'kind':'not _byte_column_below(kind, KIND_COUNT)',
            'severity':'not _i32_column_within(severity, SEVERITY_NONE, SEVERITY_SERIOUS)',
            'ref-pair':'not _rescuer_pairs_valid(rescuer_slot, rescuer_generation)',
            'untreated':'not _i64_column_nonnegative(untreated_ticks)',
            'care':'not _i64_column_nonnegative(care_progress_mwu)',
            'ordinal':'not _i64_column_nonnegative(last_incident_ordinal)',
            'kind-severity':'(kind[row] == KIND_NONE) != (severity[row] == SEVERITY_NONE)',
        }
        for label,expression in conditions.items():
            (clone/OWNER).write_text(replace_once(source,expression,'false'))
            run(clone,'omit-'+label,True)
        # Split the two no-injury clauses without affecting the separate free-row gate.
        relation='if untreated_ticks[row] != 0 or care_progress_mwu[row] != 0:\n\t\t\treturn REFUSE_COLUMN_NO_INJURY'
        for label,remaining in [('no-injury-ticks','care_progress_mwu[row] != 0'),('no-injury-care','untreated_ticks[row] != 0')]:
            (clone/OWNER).write_text(replace_once(source,relation,'if '+remaining+':\n\t\t\treturn REFUSE_COLUMN_NO_INJURY'))
            run(clone,'omit-'+label,True)
        history='kind[row] == KIND_NONE and airless_episode[row] == 0 and exhaustion_latch[row] == 0'
        for label,remaining in [('active-ordinal','airless_episode[row] == 0 and exhaustion_latch[row] == 0'),('latched-ordinal','kind[row] == KIND_NONE')]:
            (clone/OWNER).write_text(replace_once(source,history,remaining))
            run(clone,'omit-'+label,True)
        (clone/OWNER).write_text(replace_once(source,'if inactive != REFUSE_NONE:','if false:'))
        run(clone,'omit-inactive',True)
        duplicate='return _column_rescuer_duplicate_refusal(present, rescuer_slot, rescuer_generation)'
        (clone/OWNER).write_text(replace_once(source,duplicate,'return REFUSE_NONE'))
        run(clone,'omit-duplicate',True)
        (clone/OWNER).write_text(replace_once(source,'\t\treturn REFUSE_COLUMN_SHAPE',
            '\t\treturn REFUSE_COLUMN_FLAGS if present.size() > 0 and present[0] > 1 else REFUSE_COLUMN_SHAPE'))
        run(clone,'flags-before-shape',True)
        untreated='\tif not _i64_column_nonnegative(untreated_ticks):\n\t\treturn REFUSE_COLUMN_UNTREATED_TICKS\n'
        care='\tif not _i64_column_nonnegative(care_progress_mwu):\n\t\treturn REFUSE_COLUMN_CARE_PROGRESS\n'
        (clone/OWNER).write_text(replace_once(source,untreated+care,care+untreated))
        run(clone,'care-before-untreated',True)
        variant=replace_once(source,duplicate,'return REFUSE_NONE')
        marker='\tvar inactive: StringName = _column_inactive_refusal(present, kind, airless_episode,'
        check='\tvar duplicates: StringName = _column_rescuer_duplicate_refusal(present, rescuer_slot, rescuer_generation)\n\tif duplicates != REFUSE_NONE:\n\t\treturn duplicates\n'
        (clone/OWNER).write_text(replace_once(variant,marker,check+marker))
        run(clone,'duplicate-before-inactive',True)
        (clone/OWNER).write_text(replace_once(source,'_untreated_ticks[slot] == IntMath.INT64_MAX','false'))
        run(clone,'omit-runtime-overflow',True)
        marker='\tif blocked >= 0:\n\t\t_last_refused_slot = blocked'
        partial='\tif blocked >= 0:\n\t\tif blocked > 0: _untreated_ticks[0] += 1\n\t\t_last_refused_slot = blocked'
        (clone/OWNER).write_text(replace_once(source,marker,partial))
        run(clone,'partial-advance-before-overflow-refusal',True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==35
