#!/usr/bin/env python3
"""Exercise owner8 metadata gates and bypasses in an owned disposable Godot clone.

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
BRIDGE=Path('godot/scripts/core/save_owner_movement.gd')
OWNER=Path('godot/scripts/core/movement.gd')
SPEED_SOURCE=Path('godot/scripts/core/residents.gd')
DIRECTORY=Path('godot/scripts/core/entity_directory.gd')


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
    pattern=r'(const '+re.escape(name)+r': Array\[int\] = )(\[[^\]]*\])'
    found=list(re.finditer(pattern,source,re.S));assert len(found)==1,name
    match=found[0];tokens=[x.strip() for x in match[2][1:-1].split(',') if x.strip()]
    assert len(tokens)==3
    if fault=='short':tokens.pop()
    elif fault=='long':tokens.append(tokens[-1])
    else:tokens[0]='3278'
    return source[:match.start(2)]+'['+', '.join(tokens)+']'+source[match.end(2):]


def schema_fault(source,fault):
    # Coherent arithmetic was independently frozen before implementation.
    plan=json.loads((ROOT/'docs/validation/evidence/movement-validation-planning-2026-09-20/metadata-arithmetic-check.json').read_text())
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
const Bridge := preload("res://scripts/core/save_owner_movement.gd")
func test_actual_metadata_gate() -> void:
	var frame: Section.FramedOwner = Section.FramedOwner.new(8)
	for field: int in [11,12]:
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
	assert_equal(result.detail.begins_with("Movement owner8 metadata:"),%s,"gate4 prefix distinguishes schema gate")
	assert_equal(Bridge.METADATA_DETAIL_PREFIX,"Movement owner8 metadata:","exact prefix")
	assert_true(frame.u8_columns == bytes_before,"byte inputs preserved")
	assert_true(frame.i32_columns == i32_before,"i32 inputs preserved")
	assert_true(frame.i64_columns == i64_before,"i64 inputs preserved")
	if not schema.is_ok(): assert_equal(result.detail,schema.detail,"schema detail forwarded unchanged")
	else: assert_true(true,"no schema refusal to forward")
''' % (schema_code,code,'true' if gate4 else 'false')


def execute(clone,label,expect_failure=False):
    run=subprocess.run(['godot','--headless','--path','godot','--script',
                        'res://test/movement_metadata_probe_focus.gd'],cwd=clone,text=True,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    match=re.search(r'^1 test\(s\), 9 assertion\(s\), (\d+) failure\(s\)$',run.stdout,re.M)
    valid=match is not None and 'SCRIPT ERROR:' not in run.stdout and 'Parse Error:' not in run.stdout
    killed=bool(valid and int(match[1])>0 and run.returncode!=0)
    passed=bool(valid and int(match[1])==0 and run.returncode==0)
    assert killed if expect_failure else passed,label+'\n'+run.stdout
    return dict(case=label,assertions=9,valid_execution=valid,killed_bypass=killed,passed=passed)


def main():
    originals={p:(ROOT/p).read_bytes() for p in [SCHEMA,BRIDGE,OWNER,SPEED_SOURCE,DIRECTORY,Path('godot/project.godot')]}
    expressions={
        'key':'Schema.owner_key(OWNER_INDEX) != OWNER_KEY',
        'version':'Schema.owner_version(OWNER_INDEX) != OWNER_VERSION',
        'primary':'Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT',
        'children':'Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT',
        'field_count':'Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT',
        'field_key':'Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field])',
        'field_type':'Schema.field_type(OWNER_INDEX, field) != int(FIELD_TYPES[field])',
        'field_extent':'Schema.element_count(OWNER_INDEX, field) != int(FIELD_COUNTS[field])',
    }
    results=[]
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-movement-metadata-') as scratch:
            clone=Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            # A deliberately shortened Residents speed table must reach the cold bridge without
            # constructing unrelated live settlement autoloads whose startup assertions
            # correctly reject it first. Only this owned metadata clone disables autoloads.
            project=clone/'godot/project.godot'
            config=project.read_text()
            config,count=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',config)
            assert count==1,'one autoload section must be isolated'
            project.write_text(config)
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/movement_metadata_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_movement_metadata_probe.gd"])\n')
            probe=clone/'godot/test/test_movement_metadata_probe.gd'
            probe.write_text(suite('','',False))
            results.append(execute(clone,'positive-control'))
            for name in ['SIZE_MOVEMENT_U_PER_S']:
                for fault in ['short','long','value']:
                    (clone/SPEED_SOURCE).write_text(source_table_fault(originals[SPEED_SOURCE].decode(),name,fault))
                    probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                    results.append(execute(clone,name+'-'+fault))
            (clone/SPEED_SOURCE).write_bytes(originals[SPEED_SOURCE])
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
    assert len(results)==21
    print(json.dumps(dict(status='PASS',scope='Cold bridge metadata in disposable clone with live autoloads disabled; normal focus/full suite keep autoloads',cases=results,source_sha256={
        str(p):hashlib.sha256(d).hexdigest() for p,d in originals.items()}),indent=2))


if __name__=='__main__':
    main()
