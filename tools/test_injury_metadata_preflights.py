#!/usr/bin/env python3
"""Exercise owner6 metadata gates and bypasses in an owned disposable Godot clone.

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
BRIDGE=Path('godot/scripts/core/save_owner_injury.gd')
OWNER=Path('godot/scripts/core/injury.gd')
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
    if fault=='key': return edit(source,'OWNER_KEYS',{6:'injurz'})
    if fault=='version': return edit(source,'OWNER_VERSIONS',{6:2})
    if fault=='primary': return edit(source,'OWNER_PRIMARY_COUNTS',{6:513,7:8191})
    if fault=='children':
        changes={'OWNER_CHILD_COUNTS':{6:1,7:0},'OWNER_CHILD_BEGIN':{7:4},
                 'OWNER_OFFSETS':{7:lambda n:n+8},
                 'OWNER_PAYLOAD_BYTES':{6:lambda n:n+8,7:lambda n:n-8},
                 'OWNER_BLOCK_BYTES':{6:lambda n:n+8,7:lambda n:n-8}}
        for name,values in changes.items(): source=edit(source,name,values)
        return source
    if fault=='field_count':
        # Append Jobs first u8[8192] after all eleven Injury descriptors.
        changes={'OWNER_FIELD_COUNTS':{6:12,7:37},'OWNER_FIELD_BEGIN':{7:134},
                 'OWNER_OFFSETS':{7:lambda n:n+8200},
                 'OWNER_PAYLOAD_BYTES':{6:lambda n:n+8200,7:lambda n:n-8200},
                 'OWNER_BLOCK_BYTES':{6:lambda n:n+8200,7:lambda n:n-8200}}
        for name,values in changes.items(): source=edit(source,name,values)
        return source
    if fault=='field_key': return edit(source,'FIELD_KEYS',{122:'_changed'})
    assert fault in ['field_type','field_extent']
    delta=1536 if fault=='field_type' else 1
    source=edit(source,'FIELD_TYPES' if fault=='field_type' else 'FIELD_COUNTS',
                {122:2 if fault=='field_type' else 513})
    for name in ['OWNER_PAYLOAD_BYTES','OWNER_BLOCK_BYTES']:
        source=edit(source,name,{6:lambda n:n+delta})
    source=edit(source,'OWNER_OFFSETS',{i:lambda n:n+delta for i in range(7,18)})
    for name in ['SECTION_BYTES','EXPECTED_SECTION_BYTES']:
        source=replace_once(source,'const '+name+': int = 12947565',
                            'const '+name+': int = '+str(12947565+delta))
    return source


def suite(code,schema_code,gate4):
    return '''extends "res://test/framework/test_case.gd"
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_injury.gd")
func test_actual_metadata_gate() -> void:
	var frame: Section.FramedOwner = Section.FramedOwner.new(6)
	for field: int in [6]:
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
	assert_equal(result.detail.begins_with("Injury owner6 metadata:"),%s,"gate4 prefix distinguishes schema gate")
	assert_equal(Bridge.METADATA_DETAIL_PREFIX,"Injury owner6 metadata:","exact prefix")
	assert_true(frame.u8_columns == bytes_before,"byte inputs preserved")
	assert_true(frame.i32_columns == i32_before,"i32 inputs preserved")
	assert_true(frame.i64_columns == i64_before,"i64 inputs preserved")
	if not schema.is_ok(): assert_equal(result.detail,schema.detail,"schema detail forwarded unchanged")
	else: assert_true(true,"no schema refusal to forward")
''' % (schema_code,code,'true' if gate4 else 'false')


def execute(clone,label,expect_failure=False):
    run=subprocess.run(['godot','--headless','--path','godot','--script',
                        'res://test/injury_metadata_probe_focus.gd'],cwd=clone,text=True,
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
        with tempfile.TemporaryDirectory(prefix='redwall-injury-metadata-') as scratch:
            clone=Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/injury_metadata_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_injury_metadata_probe.gd"])\n')
            probe=clone/'godot/test/test_injury_metadata_probe.gd'
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
            (clone/SCHEMA).write_text(replace_once(originals[SCHEMA].decode(),
                'const OWNER_OFFSETS: Array = [\n\t4,','const OWNER_OFFSETS: Array = [\n\t5,'))
            probe.write_text(suite('SAVE_COMPONENT_METADATA','SAVE_COMPONENT_METADATA',False))
            results.append(execute(clone,'schema-first-forwarding'))
    finally:
        for path,original in originals.items(): assert (ROOT/path).read_bytes()==original
    assert len(results)==18
    print(json.dumps(dict(status='PASS',cases=results,source_sha256={
        str(p):hashlib.sha256(d).hexdigest() for p,d in originals.items()}),indent=2))


if __name__=='__main__':
    main()
