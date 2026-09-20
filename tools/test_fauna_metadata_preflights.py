#!/usr/bin/env python3
"""Exercise owner17 metadata gates and bypasses in an owned disposable Godot clone.

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
BRIDGE=Path('godot/scripts/core/save_owner_world_init.gd')
OWNER=Path('godot/scripts/core/world_init.gd')
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


def schema_fault(source,fault):
    if fault=='key': return edit(source,'OWNER_KEYS',{17:'world_iniu'})
    if fault=='version': return edit(source,'OWNER_VERSIONS',{17:2})
    if fault=='primary': return edit(source,'OWNER_PRIMARY_COUNTS',{17:385,16:511})
    if fault=='children':
        changes={'OWNER_CHILD_COUNTS':{10:0,17:1},
                 'OWNER_CHILD_BEGIN':{i:4 for i in range(11,18)},
                 'OWNER_OFFSETS':{i:lambda n:n-8 for i in range(11,18)},
                 'OWNER_PAYLOAD_BYTES':{10:lambda n:n-8,17:lambda n:n+8},
                 'OWNER_BLOCK_BYTES':{10:lambda n:n-8,17:lambda n:n+8}}
        for name,values in changes.items(): source=edit(source,name,values)
        return source
    if fault=='field_count':
        # Move Work's last u8[512] descriptor after all nine fauna fields.
        for name in ['FIELD_KEYS','FIELD_TYPES','FIELD_COUNTS']:
            match,values=table(source,name)
            values.append(values.pop(288))
            source=source[:match.start(2)]+json.dumps(values)+source[match.end(2):]
        changes={'OWNER_FIELD_COUNTS':{16:8,17:10},'OWNER_FIELD_BEGIN':{17:288},
                 'OWNER_OFFSETS':{17:lambda n:n-520},
                 'OWNER_PAYLOAD_BYTES':{16:lambda n:n-520,17:lambda n:n+520},
                 'OWNER_BLOCK_BYTES':{16:lambda n:n-520,17:lambda n:n+520}}
        for name,values in changes.items(): source=edit(source,name,values)
        return source
    if fault=='field_key': return edit(source,'FIELD_KEYS',{289:'_changed'})
    assert fault in ['field_type','field_extent']
    delta=1536 if fault=='field_type' else 4
    source=edit(source,'FIELD_TYPES' if fault=='field_type' else 'FIELD_COUNTS',
                {289:4 if fault=='field_type' else 385})
    for name in ['OWNER_PAYLOAD_BYTES','OWNER_BLOCK_BYTES']:
        source=edit(source,name,{17:lambda n:n+delta})
    for name in ['SECTION_BYTES','EXPECTED_SECTION_BYTES']:
        source=replace_once(source,'const '+name+': int = 12947565',
                            'const '+name+': int = '+str(12947565+delta))
    return source


def suite(code,schema_code,gate4):
    return '''extends "res://test/framework/test_case.gd"
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_world_init.gd")
func test_actual_metadata_gate() -> void:
	var frame: Section.FramedOwner = Section.FramedOwner.new(17)
	if Schema.field_type(17,0) == Schema.TYPE_I32:
		var slots: PackedInt32Array = frame.i32_column(0)
		slots.fill(-1)
		assert(frame.set_i32(0,slots))
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
	assert_equal(result.detail.begins_with("WorldInit owner17 metadata:"),%s,"gate4 prefix distinguishes schema gate")
	assert_equal(Bridge.METADATA_DETAIL_PREFIX,"WorldInit owner17 metadata:","exact prefix")
	assert_true(frame.u8_columns == bytes_before,"byte inputs preserved")
	assert_true(frame.i32_columns == i32_before,"i32 inputs preserved")
	assert_true(frame.i64_columns == i64_before,"i64 inputs preserved")
	if not schema.is_ok(): assert_equal(result.detail,schema.detail,"schema detail forwarded unchanged")
	else: assert_true(true,"no schema refusal to forward")
''' % (schema_code,code,'true' if gate4 else 'false')


def execute(clone,label,expect_failure=False):
    run=subprocess.run(['godot','--headless','--path','godot','--script',
                        'res://test/fauna_metadata_probe_focus.gd'],cwd=clone,text=True,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    match=re.search(r'^1 test\(s\), 9 assertion\(s\), (\d+) failure\(s\)$',run.stdout,re.M)
    valid=match is not None and 'SCRIPT ERROR:' not in run.stdout and 'Parse Error:' not in run.stdout
    killed=bool(valid and int(match[1])>0 and run.returncode!=0)
    passed=bool(valid and int(match[1])==0 and run.returncode==0)
    assert killed if expect_failure else passed,label+'\n'+run.stdout
    return dict(case=label,assertions=9,valid_execution=valid,killed_bypass=killed,passed=passed)


def main():
    originals={p:(ROOT/p).read_bytes() for p in [SCHEMA,BRIDGE,OWNER,DIRECTORY]}
    expressions={
        'key':'Schema.owner_key(OWNER_INDEX) != OWNER_KEY',
        'version':'Schema.owner_version(OWNER_INDEX) != OWNER_VERSION',
        'primary':'Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT',
        'children':'Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT',
        'field_count':'Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT',
        'field_key':'Schema.field_key(OWNER_INDEX, field) != key',
        'field_type':'Schema.field_type(OWNER_INDEX, field) != type_code',
        'field_extent':'Schema.element_count(OWNER_INDEX, field) != count',
    }
    results=[]
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-fauna-metadata-') as scratch:
            clone=Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/fauna_metadata_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_fauna_metadata_probe.gd"])\n')
            probe=clone/'godot/test/test_fauna_metadata_probe.gd'
            probe.write_text(suite('','',False))
            results.append(execute(clone,'positive-control'))
            for fault,expression in expressions.items():
                (clone/SCHEMA).write_text(schema_fault(originals[SCHEMA].decode(),fault))
                probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                results.append(execute(clone,fault+'-fault-refused'))
                (clone/BRIDGE).write_text(replace_once(originals[BRIDGE].decode(),expression,'false'))
                results.append(execute(clone,fault+'-gate-bypassed',True))
                (clone/BRIDGE).write_bytes(originals[BRIDGE])
            (clone/SCHEMA).write_bytes(originals[SCHEMA])
            sentinel_faults=[
                ('null-slot','const NULL_SLOT: int = -1','const NULL_SLOT: int = -2',
                 'WorldInit.EntityDirectory.NULL_SLOT != OWNER_NULL_SLOT'),
                ('null-generation','const NULL_GENERATION: int = 0','const NULL_GENERATION: int = 1',
                 'WorldInit.EntityDirectory.NULL_GENERATION != OWNER_NULL_GENERATION'),
            ]
            for label,old,new,expression in sentinel_faults:
                (clone/DIRECTORY).write_text(replace_once(originals[DIRECTORY].decode(),old,new))
                probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                results.append(execute(clone,label+'-source-fault-refused'))
                (clone/BRIDGE).write_text(replace_once(originals[BRIDGE].decode(),expression,'false'))
                results.append(execute(clone,label+'-source-guard-bypassed',True))
                (clone/BRIDGE).write_bytes(originals[BRIDGE])
                (clone/DIRECTORY).write_bytes(originals[DIRECTORY])
            (clone/SCHEMA).write_text(replace_once(originals[SCHEMA].decode(),
                'const OWNER_OFFSETS: Array = [\n\t4,','const OWNER_OFFSETS: Array = [\n\t5,'))
            probe.write_text(suite('SAVE_COMPONENT_METADATA','SAVE_COMPONENT_METADATA',False))
            results.append(execute(clone,'schema-first-forwarding'))
    finally:
        for path,original in originals.items(): assert (ROOT/path).read_bytes()==original
    assert len(results)==22
    print(json.dumps(dict(status='PASS',cases=results,source_sha256={
        str(p):hashlib.sha256(d).hexdigest() for p,d in originals.items()}),indent=2))


if __name__=='__main__':
    main()
