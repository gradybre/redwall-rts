#!/usr/bin/env python3
"""Exercise owner0 metadata gates and bypasses in an owned disposable Godot clone.

Counterfactual field type/count tables rebalance all affected lengths, including the
compiled expected total, to reach gate4 with a valid schema. They are not production
format changes. Source-capacity/generator checks separately pin the real schema.
"""
import ast
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SCHEMA=Path('godot/scripts/core/save_component_columns_schema.gd')
BRIDGE=Path('godot/scripts/core/save_owner_buildings.gd')
OWNER=Path('godot/scripts/core/buildings.gd')
DIRECTORY=Path('godot/scripts/core/entity_directory.gd')
CATALOG=Path('godot/scripts/core/catalog.gd')
DEFINITIONS=Path('godot/scripts/core/building_definitions.gd')


def replace_once(source,old,new):
    assert source.count(old)==1,(old,source.count(old))
    return source.replace(old,new)


def table(source,name):
    pattern=r'(const '+re.escape(name)+r': Array = )(\[.*?\])'
    found=list(re.finditer(pattern,source,re.S)); assert len(found)==1,name
    return found[0],ast.literal_eval(found[0][2])


def edit(source,name,changes):
    match,values=table(source,name)
    for index,value in changes.items():
        values[index]=value(values[index]) if callable(value) else value
    return source[:match.start(2)]+json.dumps(values)+source[match.end(2):]


def source_table_fault(source,name,fault):
    pattern=r'(const '+re.escape(name)+r': Array\[(?:int|String)\] = )(\[[^\]]*\])'
    found=list(re.finditer(pattern,source,re.S));assert len(found)==1,name
    match=found[0];values=ast.literal_eval(match[2]);assert len(values)>1
    if fault=='short':values.pop()
    elif fault=='long':values.append(values[-1])
    elif fault=='last-value':values[-1]=values[-1]+1 if isinstance(values[-1],int) else values[-1]+'_drift'
    else:raise AssertionError(fault)
    return source[:match.start(2)]+json.dumps(values)+source[match.end(2):]


def dictionary_fault(source,name,fault):
    pattern=r'(const '+re.escape(name)+r': Dictionary = )(\{.*?\})'
    found=list(re.finditer(pattern,source,re.S));assert len(found)==1,name
    match=found[0];values=ast.literal_eval(match[2]);key=list(values)[-1]
    if fault=='missing':del values[key]
    elif fault=='extra':values['_unexpected']=len(values)
    elif fault in ['last-id-value','last-ordinal']:values[key]+=1
    elif fault=='last-id-type':values[key]=str(values[key])
    elif fault=='last-row-type':values[key]=17
    elif fault=='last-row-short':values[key].pop()
    elif fault=='last-row-long':values[key].append(0)
    elif fault=='last-dimension-type':values[key][0]=str(values[key][0])
    elif fault=='last-dimension-value':values[key][0]+=1
    else:raise AssertionError(fault)
    return source[:match.start(2)]+json.dumps(values)+source[match.end(2):]



def schema_fault(source,fault):
    # Coherent arithmetic was independently frozen before implementation.
    plan=json.loads((ROOT/'docs/validation/evidence/buildings-validation-planning-2026-09-20/metadata-arithmetic-check.json').read_text())
    case=next(c for c in plan['cases'] if c['case']==fault)
    for name,values in case['changes'].items():
        source=edit(source,name,{int(i):value for i,value in values.items()})
    if case['section_bytes']!=12947565:
        for name in ['SECTION_BYTES','EXPECTED_SECTION_BYTES']:
            source=replace_once(source,'const '+name+': int = 12947565',
                                'const '+name+': int = '+str(case['section_bytes']))
    return source


def suite(code,schema_code,gate4):
    return '''extends "res://test/framework/test_case.gd"
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_buildings.gd")
func test_actual_metadata_gate() -> void:
	var frame: Section.FramedOwner = Section.FramedOwner.new(0)
	for field: int in [5,9,11,13,22,24,26]:
		var slots: PackedInt32Array = frame.i32_column(field)
		slots.fill(-1)
		assert(frame.set_i32(field,slots))
	var bytes_before: Array[PackedByteArray] = []
	var i32_before: Array[PackedInt32Array] = []
	var i64_before: Array[PackedInt64Array] = []
	for values: PackedByteArray in frame.u8_columns: bytes_before.append(values.duplicate())
	for values: PackedInt32Array in frame.i32_columns: i32_before.append(values.duplicate())
	for values: PackedInt64Array in frame.i64_columns: i64_before.append(values.duplicate())
	var schema: Variant = Schema.schema_refusal()
	assert_equal(schema.code,&"%s","schema gate isolated")
	assert_true(Section.owner_shape_refusal(frame).is_ok(),"physically coherent frame")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,&"%s","real bridge refusal")
	assert_equal(result.detail.begins_with("Buildings owner0 metadata:"),%s,"gate4 prefix distinguishes schema gate")
	assert_equal(Bridge.METADATA_DETAIL_PREFIX,"Buildings owner0 metadata:","exact prefix")
	assert_true(frame.u8_columns == bytes_before,"byte inputs preserved")
	assert_true(frame.i32_columns == i32_before,"i32 inputs preserved")
	assert_true(frame.i64_columns == i64_before,"i64 inputs preserved")
	if not schema.is_ok(): assert_equal(result.detail,schema.detail,"schema detail forwarded unchanged")
	else: assert_true(true,"no schema refusal to forward")
''' % (schema_code,code,'true' if gate4 else 'false')


def execute(clone,label,expect_failure=False):
    run=subprocess.run(['godot','--headless','--path','godot','--script',
                        'res://test/buildings_metadata_probe_focus.gd'],cwd=clone,text=True,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    match=re.search(r'^1 test\(s\), 9 assertion\(s\), (\d+) failure\(s\)$',run.stdout,re.M)
    valid=match is not None and 'SCRIPT ERROR:' not in run.stdout and 'Parse Error:' not in run.stdout
    killed=bool(valid and int(match[1])>0 and run.returncode!=0)
    passed=bool(valid and int(match[1])==0 and run.returncode==0)
    assert killed if expect_failure else passed,label+'\n'+run.stdout
    return dict(case=label,assertions=9,valid_execution=valid,killed_bypass=killed,passed=passed)


def main():
    originals={p:(ROOT/p).read_bytes() for p in [SCHEMA,BRIDGE,OWNER,DIRECTORY,CATALOG,DEFINITIONS,Path('godot/project.godot')]}
    expressions={
        'key':'Schema.owner_key(OWNER_INDEX) != OWNER_KEY',
        'version':'Schema.owner_version(OWNER_INDEX) != OWNER_VERSION',
        'primary':'Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT',
        'children':'Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT',
        'child_room':'Schema.child_extent(OWNER_INDEX, 0) != 16384',
        'child_furniture':'Schema.child_extent(OWNER_INDEX, 1) != 81920',
        'field_count':'Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT',
        'field_key':'Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field])',
        'field_type':'Schema.field_type(OWNER_INDEX, field) != int(FIELD_TYPES[field])',
        'field_extent':'Schema.element_count(OWNER_INDEX, field) != int(FIELD_COUNTS[field])',
    }
    results=[]
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-buildings-metadata-') as scratch:
            clone=Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            # A deliberately malformed immutable source table must reach the cold bridge without
            # constructing unrelated live settlement autoloads whose startup assertions
            # correctly reject it first. Only this owned metadata clone disables autoloads.
            project=clone/'godot/project.godot'
            config=project.read_text()
            config,count=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',config)
            assert count==1,'one autoload section must be isolated'
            project.write_text(config)
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/buildings_metadata_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_buildings_metadata_probe.gd"])\n')
            probe=clone/'godot/test/test_buildings_metadata_probe.gd'
            probe.write_text(suite('','',False))
            results.append(execute(clone,'positive-control'))
            owner_arrays=['COLUMN_BUILDING_KEYS','COLUMN_BUILDING_FOOTPRINT_X','COLUMN_BUILDING_FOOTPRINT_Z','COLUMN_FURNITURE_KEYS','COLUMN_FURNITURE_FLOOR_X','COLUMN_FURNITURE_FLOOR_Z','COLUMN_TIER_TWO_TYPE_IDS']
            source_faults=[]
            for name in owner_arrays:
                for fault in ['short','long','last-value']:
                    source_faults.append((OWNER,name,fault,source_table_fault,name+'-'+fault))
            for name in ['BUILDING_DEFINITION','FURNITURE_DEFINITION']:
                for fault in ['missing','extra','last-id-value','last-id-type']:
                    source_faults.append((CATALOG,name,fault,dictionary_fault,'Catalog.'+name+'-'+fault))
            for name in ['BUILDING_STATE','ROOM_TYPE']:
                source_faults.append((CATALOG,name,'last-ordinal',dictionary_fault,'Catalog.'+name+'-last-ordinal'))
            for name in ['BUILDING_FACTS','FURNITURE_FACTS']:
                for fault in ['missing','last-row-type','last-row-short','last-row-long','last-dimension-type','last-dimension-value']:
                    source_faults.append((DEFINITIONS,name,fault,dictionary_fault,'BuildingDefinitions.'+name+'-'+fault))
            for fault in ['short','long','last-value']:
                source_faults.append((DEFINITIONS,'TIER_TWO_KEYS',fault,source_table_fault,'BuildingDefinitions.TIER_TWO_KEYS-'+fault))
            for path,name,fault,editor,label in source_faults:
                (clone/path).write_text(editor(originals[path].decode(),name,fault))
                # The missing shelf catalog key otherwise constant-folds an unrelated live
                # accessor into a parse error before the cold metadata gate. Only in this
                # one owned-clone counterfactual, use an equal-valued local lookup key.
                isolated_shelf=path==CATALOG and name=='FURNITURE_DEFINITION' and fault=='missing'
                if isolated_shelf:
                    original_line='\treturn SHELF_PANTRY_CAPACITY_G if type_id == int(Catalog.FURNITURE_DEFINITION[SHELF_KEY]) else 0'
                    replacement='\tvar saved_shelf_key: String = SHELF_KEY\n\treturn SHELF_PANTRY_CAPACITY_G if type_id == int(Catalog.FURNITURE_DEFINITION[saved_shelf_key]) else 0'
                    (clone/DEFINITIONS).write_text(replace_once(originals[DEFINITIONS].decode(),original_line,replacement))
                probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                results.append(execute(clone,label))
                (clone/path).write_bytes(originals[path])
                if isolated_shelf:(clone/DEFINITIONS).write_bytes(originals[DEFINITIONS])
            (clone/DIRECTORY).write_text(replace_once(originals[DIRECTORY].decode(),'const NULL_GENERATION: int = 0','const NULL_GENERATION: int = 1'))
            probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
            results.append(execute(clone,'Directory.NULL_GENERATION-value'))
            (clone/DIRECTORY).write_bytes(originals[DIRECTORY])
            for fault,expression in expressions.items():
                (clone/SCHEMA).write_text(schema_fault(originals[SCHEMA].decode(),fault))
                probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                results.append(execute(clone,fault+'-fault-refused'))
                (clone/BRIDGE).write_text(replace_once(originals[BRIDGE].decode(),expression,'false'))
                results.append(execute(clone,fault+'-gate-bypassed',True))
                (clone/BRIDGE).write_bytes(originals[BRIDGE])
            (clone/SCHEMA).write_bytes(originals[SCHEMA])
            (clone/SCHEMA).write_text(replace_once(originals[SCHEMA].decode(),
                'const OWNER_OFFSETS: Array = [\n\t4,','const OWNER_OFFSETS: Array = [\n\t5,'))
            probe.write_text(suite('SAVE_COMPONENT_METADATA','SAVE_COMPONENT_METADATA',False))
            results.append(execute(clone,'schema-first-forwarding'))
    finally:
        for path,original in originals.items(): assert (ROOT/path).read_bytes()==original
    assert len(results)==69
    planned=json.loads((ROOT/'docs/validation/evidence/buildings-validation-planning-2026-09-20/metadata-cases.json').read_text())
    assert {case['case'] for case in results}=={case['case'] for case in planned['cases']}
    assert sum(case['killed_bypass'] for case in results)==10
    print(json.dumps(dict(status='PASS',scope='Cold bridge metadata in disposable clone with live autoloads disabled; normal focus/full suite keep autoloads',cases=results,source_sha256={
        str(p):hashlib.sha256(d).hexdigest() for p,d in originals.items()}),indent=2))


if __name__=='__main__':
    main()
