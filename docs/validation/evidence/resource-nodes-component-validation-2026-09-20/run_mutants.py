"""Execute thirty ResourceNodes accessor/domain/order mutants in an owned clone."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/resource_nodes.gd')
BRIDGE=Path('godot/scripts/core/save_owner_resource_nodes.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_resource_nodes.gd').read_text(),re.M))
results=[]


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script',
                      'res://test/resource_nodes_validation_focus.gd'],cwd=clone,text=True,
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
    with tempfile.TemporaryDirectory(prefix='redwall-resource-nodes-mutants-') as scratch:
        clone=Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        source=ORIGINAL[BRIDGE].decode()
        helpers=''
        for kind,typ in [('u8','PackedByteArray'),('i32','PackedInt32Array'),('i64','PackedInt64Array')]:
            helpers+='\nstatic func _mutation_'+kind+'() -> '+typ+':\n\tvar values: '+typ+' = '+typ+'()\n\tvalues.resize(4096)\n\treturn values\n'
        fields=['PRESENT','RESOURCE_ID','QUANTITY_MILLI','CAPACITY_MILLI','REGROW_DAYS','PLANTED_DAY','EXHAUSTED','TILE','REF_SLOT','REF_GENERATION']
        for i,field in enumerate(fields):
            kind='u8' if i in [0,6] else ('i64' if i in [2,3] else 'i32')
            variant=replace_once(source,'record.'+kind+'_column(FIELD_'+field+')','_mutation_'+kind+'()')+helpers
            (clone/BRIDGE).write_text(variant)
            run(clone,'zero-substitute-'+field.lower(),True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        source=ORIGINAL[OWNER].decode()
        conditions={
            'present-flag':['present.count(0) + present.count(1) != RESOURCE_NODE_CAPACITY'],
            'exhausted-flag':['exhausted.count(0) + exhausted.count(1) != RESOURCE_NODE_CAPACITY'],
            'resource-id':['_i32_has_negative(resource_id)'],
            'quantity':['_i64_has_negative(quantity_milli)'],
            'capacity-code-identity':['_i64_has_negative(capacity_milli)'],
            'regrow-days':['_i32_has_negative(regrow_days)'],
            'planted-day':['_i32_has_negative(planted_day)'],
            'quantity-over-capacity':['quantity_milli[row] > capacity_milli[row]'],
            'present-capacity':['present[row] == 1 and capacity_milli[row] <= 0'],
            'present-day':['present[row] == 1 and planted_day[row] < MIN_CALENDAR_DAY'],
            'exhaustion':['(exhausted[row] == 1) != (quantity_milli[row] == 0)'],
            'present-tile':['tile[row] < 0 or tile[row] >= TILE_COUNT'],
            'inactive-tile':['tile[row] != NO_NODE'],
            'present-ref':['ref_slot[row] < 0 \\\n\t\t\t\t\tor ref_slot[row] >= EntityDirectory.DIRECTORY_CAPACITY','ref_generation[row] <= 0'],
            'inactive-ref':['ref_slot[row] != EntityDirectory.NULL_SLOT \\\n\t\t\t\tor ref_generation[row] != EntityDirectory.NULL_GENERATION'],
            'inactive-quantity':['quantity_milli[row] != 0'],
            'inactive-exhausted':['exhausted[row] != 0'],
        }
        for label,expressions in conditions.items():
            variant=source
            for expression in expressions: variant=replace_once(variant,expression,'false')
            (clone/OWNER).write_text(variant)
            run(clone,'omit-'+label,True)
        variant=replace_once(source,'\t\treturn REFUSE_COLUMN_SHAPE',
            '\t\treturn REFUSE_COLUMN_PRESENT_FLAG if present.size() > 0 and present[0] > 1 else REFUSE_COLUMN_SHAPE')
        (clone/OWNER).write_text(variant)
        run(clone,'present-before-shape',True)
        quantity='\tif _i64_has_negative(quantity_milli):\n\t\treturn REFUSE_COLUMN_QUANTITY\n'
        capacity='\tif _i64_has_negative(capacity_milli):\n\t\treturn REFUSE_COLUMN_CAPACITY\n'
        (clone/OWNER).write_text(replace_once(source,quantity+capacity,capacity+quantity))
        run(clone,'capacity-before-quantity',True)
        tile='\tvar tiles: StringName = _column_tile_refusal(present, tile)\n\tif tiles != REFUSE_NONE:\n\t\treturn tiles\n'
        ref='\tvar refs: StringName = _column_ref_refusal(present, ref_slot, ref_generation)\n\tif refs != REFUSE_NONE:\n\t\treturn refs\n'
        (clone/OWNER).write_text(replace_once(source,tile+ref,ref+tile))
        run(clone,'ref-before-tile',True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        run(clone,'mutation-restored',False)
finally:
    for path,data in ORIGINAL.items(): assert (ROOT/path).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==32
