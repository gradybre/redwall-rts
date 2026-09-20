"""Forty-seven assertion mutants and one characterized null-runtime-error mutant."""
import hashlib,json,re,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
E=Path(__file__).resolve().parent
OWNER=Path('godot/scripts/core/residents.gd')
BRIDGE=Path('godot/scripts/core/save_owner_residents.gd')
ORIGINAL={p:(ROOT/p).read_bytes() for p in [OWNER,BRIDGE]}
EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_residents.gd').read_text(),re.M))
results=[]

def once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)

def run(clone,label,expect_failure):
    p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/residents_validation_focus.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (E/(label+'.log')).write_text(p.stdout)
    m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
    valid=m is not None and int(m[1])==EXPECTED and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
    killed=bool(valid and int(m[3])>0 and p.returncode!=0)
    passed=bool(valid and int(m[3])==0 and p.returncode==0)
    row=dict(case=label,oracle='assertions',exit_code=p.returncode,valid_execution=valid,killed=killed,passed=passed,summary=[s for s in p.stdout.splitlines() if '  FAIL ' in s or re.match(r'^\d+ test\(s\)',s)])
    results.append(row);print(json.dumps(row),flush=True)
    assert killed if expect_failure else passed,row

def null_probe(clone,label,expect_error):
    script='''extends SceneTree
const Residents := preload("res://scripts/core/residents.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var store: Residents = Residents.new()
	var copied: bool = store.copy_columns_into(null)
	print("NULL_CAPTURE returned=%s diagnostic=%s" % [copied,store.last_column_refusal()])
	var restored: bool = store.restore_columns(null)
	print("NULL_RESTORE returned=%s diagnostic=%s" % [restored,store.last_column_refusal()])
	quit()
'''
    (clone/'godot/test/residents_null_mutation_probe.gd').write_text(script)
    p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/residents_null_mutation_probe.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    (E/(label+'.log')).write_text(p.stdout)
    valid=p.returncode==0 and 'Parse Error' not in p.stdout and all(s+' returned=false diagnostic=COLUMN_SHAPE' in p.stdout for s in ['NULL_CAPTURE','NULL_RESTORE'])
    known="SCRIPT ERROR: Invalid access to property or key 'skill_xp' on a base object of type 'Nil'."
    detected=valid and p.stdout.count('SCRIPT ERROR:')==2 and p.stdout.count(known)==2 and '_columns_are_capacity_sized' in p.stdout
    clean=valid and 'SCRIPT ERROR:' not in p.stdout
    row=dict(case=label,oracle='known null runtime error',exit_code=p.returncode,valid_execution=valid,killed=bool(detected if expect_error else False),passed=bool(clean),assertion_kill=False)
    results.append(row);print(json.dumps(row),flush=True)
    assert detected if expect_error else clean,p.stdout

try:
    with tempfile.TemporaryDirectory(prefix='redwall-residents-mutants-') as scratch:
        clone=Path(scratch);shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        null_probe(clone,'null-baseline',False)
        bridge=ORIGINAL[BRIDGE].decode();owner=ORIGINAL[OWNER].decode()
        fields=['present','species','size_class','named','life_stage','arrival_tick','role','home_slot','home_generation','bed_slot','bed_generation','ref_slot','ref_generation','equip_tool_item_id','equip_tool_durability','equip_satchel_slot','equip_satchel_generation','skill_xp','skill_level']
        for field in fields:
            pattern=r'^\t(?:columns|out)\.'+field+r' = record\.(?:u8|i32|i64)_column\([^\n]+\)$'
            matches=list(re.finditer(pattern,bridge,re.M));assert len(matches)==1,(field,len(matches))
            (clone/BRIDGE).write_text(once(bridge,matches[0][0],'\t# Deliberately omitted '+field+' projection.'))
            run(clone,'omit-projection-'+field,True)
        (clone/BRIDGE).write_bytes(ORIGINAL[BRIDGE])
        clauses={
            'present-byte':'not _byte_column_below(columns.present, 2)',
            'named-byte':'not _byte_column_below(columns.named, 2)',
            'size-byte':'not _byte_column_below(columns.size_class, SIZE_COUNT)',
            'stage-byte':'not _byte_column_below(columns.life_stage, LIFE_STAGE_COUNT)',
            'role-byte':'not _byte_column_below(columns.role, ROLE_COUNT)',
            'xp':'not _int64_column_within(columns.skill_xp, 0, IntMath.INT64_MAX)',
            'skill-level':'columns.skill_level[index] != _skill_level_curve(columns.skill_xp[index])',
            'reserved-skill':'columns.skill_xp[reserved] != 0 or columns.skill_level[reserved] != 0',
            'home-pair':'not _is_well_formed_pair(columns.home_slot[slot], columns.home_generation[slot])',
            'bed-pair':'not _is_well_formed_pair(columns.bed_slot[slot], columns.bed_generation[slot])',
            'self-pair':'not _is_well_formed_pair(columns.ref_slot[slot], columns.ref_generation[slot])',
            'satchel-pair':'not _is_well_formed_pair(columns.equip_satchel_slot[slot],\n\t\t\t\tcolumns.equip_satchel_generation[slot])',
            'item-floor':'item < NO_TOOL_ITEM',
            'durability-floor':'item < NO_TOOL_ITEM or durability < 0',
            'empty-tool-durability':'item == NO_TOOL_ITEM and durability != 0',
            'free-name':'name_occupancy_refusal(false, columns.named[slot] == 1, NO_NAME_KEY) != REFUSE_NONE',
            'free-stage':'columns.life_stage[slot] != LIFE_STAGE_ADULT',
            'free-role':'columns.role[slot] != ROLE_RESIDENT',
            'free-self':'columns.ref_slot[slot] != EntityDirectory.NULL_SLOT',
            'free-tool':'columns.equip_tool_item_id[slot] != NO_TOOL_ITEM',
            'free-satchel':'columns.equip_satchel_slot[slot] != EntityDirectory.NULL_SLOT',
            'present-cap':'columns.present.count(1) > RESIDENT_LIVING_CAP',
        }
        for label,condition in clauses.items():
            (clone/OWNER).write_text(once(owner,condition,'item < NO_TOOL_ITEM' if label=='durability-floor' else 'false'))
            run(clone,'omit-'+label,True)
        for label,expression in [('species-scalar','return species_id_value >= 0 and species_id_value < SPECIES_COUNT'),('arrival-scalar','return tick >= 0')]:
            (clone/OWNER).write_text(once(owner,expression,'return true'))
            run(clone,'omit-'+label,True)
        shape='\tif not _columns_are_capacity_sized(columns):\n\t\treturn REFUSE_COLUMN_SHAPE'
        variant='\tif not _columns_are_capacity_sized(columns):\n\t\treturn REFUSE_COLUMN_PRESENT_BYTE if columns != null and columns.present.size() > 0 and columns.present[0] > 1 else REFUSE_COLUMN_SHAPE'
        (clone/OWNER).write_text(once(owner,shape,variant))
        run(clone,'present-before-shape',True)
        a=owner.index('static func columns_refusal(');b=owner.index('static func _columns_local_prefix_refusal(',a)
        segment=owner[a:b]
        marker='\tvar slot: int = columns.present.find(1, 0)'
        earlier='\tfor earlier: int in RESIDENT_CAPACITY:\n\t\tif columns.present[earlier] == 1 and not _species_id_in_range(columns.species[earlier]):\n\t\t\treturn REFUSE_COLUMN_SPECIES\n'
        changed=once(segment,marker,earlier+marker)
        (clone/OWNER).write_text(owner[:a]+changed+owner[b:])
        run(clone,'global-species-before-earlier-arrival',True)
        (clone/OWNER).write_text(once(owner,'if not _arrival_tick_is_valid(tick):','if false:'))
        run(clone,'omit-arrival-producer-guard',True)
        a=owner.index('func _restore_column_refusal(');b=owner.index('static func _column_byte_domain_refusal(',a)
        changed=once(owner[a:b],'_columns_local_prefix_refusal(columns)','columns_refusal(columns)')
        (clone/OWNER).write_text(owner[:a]+changed+owner[b:])
        run(clone,'saved-scalars-before-live-row-priority',True)
        (clone/OWNER).write_text(once(owner,'\tif columns == null:\n\t\treturn false\n',''))
        null_probe(clone,'omit-shape-null-guard',True)
        (clone/OWNER).write_bytes(ORIGINAL[OWNER])
        null_probe(clone,'null-restored',False)
        run(clone,'mutation-restored',False)
finally:
    for p,data in ORIGINAL.items():assert (ROOT/p).read_bytes()==data
    (E/'mutation-results.json').write_text(json.dumps(dict(source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in ORIGINAL.items()},source_unchanged=True,results=results),indent=2)+'\n')
assert len(results)==52,len(results)
assert sum(r['killed'] for r in results)==48
