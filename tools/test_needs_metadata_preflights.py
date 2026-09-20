#!/usr/bin/env python3
"""Inject metadata drift into a disposable clone and exercise the real Needs bridge.

Owner publication faults leave compiled Schema valid, distinguishing bridge gate4
from schema gate3. No mutation touches the product working tree.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NEEDS = Path('godot/scripts/core/needs.gd')
SCHEMA = Path('godot/scripts/core/save_component_columns_schema.gd')
BRIDGE = Path('godot/scripts/core/save_owner_needs.gd')


def replace_once(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)


def publication_fault(source, name, fault):
    pattern = r'(const ' + re.escape(name) + r': Array\[[^\]]+\] = \[\n)(.*?)(\n\])'
    matches = list(re.finditer(pattern, source, re.S))
    assert len(matches) == 1, name
    match = matches[0]
    tokens = [token.strip() for token in match[2].split(',') if token.strip()]
    assert len(tokens) == 20
    if fault == 'short':
        tokens.pop()
    elif fault == 'long':
        tokens.append(tokens[-1])
    else:
        tokens[0] = {'COLUMN_KEYS': '&"_wrong"', 'COLUMN_TYPE_CODES': 'COLUMN_TYPE_I32',
                     'COLUMN_EXTENTS': 'RESIDENT_CAPACITY + 1'}[name]
    return source[:match.start(2)] + '\t' + ', '.join(tokens) + ',' + source[match.end(2):]


def schema_fault(source, fault):
    """Change owner9 identity while keeping all schema arithmetic consistent."""
    edits = {
        'key': {'OWNER_KEYS': {9: '"needy"'}},
        'version': {'OWNER_VERSIONS': {9: '3'}},
        'primary': {'OWNER_PRIMARY_COUNTS': {8: '511', 9: '513'}},
        'children': {
            'OWNER_CHILD_COUNTS': {9: '1', 10: '0'},
            'OWNER_CHILD_BEGIN': {10: '5'},
            'OWNER_OFFSETS': {10: '9336936'},
            'OWNER_PAYLOAD_BYTES': {9: '57516', 10: '102604'},
            'OWNER_BLOCK_BYTES': {9: '57545', 10: '102640'},
        },
    }[fault]
    for name, changes in edits.items():
        pattern = r'(const ' + name + r': Array = \[\n)(.*?)(\n\])'
        matches = list(re.finditer(pattern, source, re.S))
        assert len(matches) == 1, name
        match = matches[0]
        tokens = [t.strip() for t in match[2].split(',') if t.strip()]
        assert len(tokens) == 18
        for index, value in changes.items():
            tokens[index] = value
        source = source[:match.start(2)] + '\t' + ', '.join(tokens) + source[match.end(2):]
    return source


def suite(code, schema_code, gate4):
    return '''extends "res://test/framework/test_case.gd"
const Needs := preload("res://scripts/core/needs.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_needs.gd")
func test_real_metadata_preflight() -> void:
	var frame: Section.FramedOwner = Section.FramedOwner.new(9)
	var clothing: PackedByteArray = PackedByteArray()
	clothing.resize(512)
	clothing.fill(1)
	assert_true(frame.set_u8(16,clothing),"valid physical clothing fixture")
	var status: PackedByteArray = PackedByteArray()
	status.resize(512)
	status.fill(Needs.STATUS_DEAD)
	assert_true(frame.set_u8(9,status),"valid physical free status fixture")
	assert_equal(Schema.schema_refusal().code,&"%s","schema gate isolated")
	var refusal: Variant = Bridge.framed_refusal(frame)
	assert_equal(refusal.code,&"%s","actual bridge metadata result")
	assert_equal(refusal.detail.begins_with("Needs owner9 metadata:"),%s,"gate4 distinguished by prefix")
	assert_equal(Bridge.METADATA_DETAIL_PREFIX,"Needs owner9 metadata:","exact accepted prefix")
	if not Schema.schema_refusal().is_ok():
		assert_equal(refusal.detail,Schema.schema_refusal().detail,"schema detail forwarded unchanged")
	else:
		assert_true(true,"no schema refusal to forward")
	assert_true(frame.u8_column(16)==clothing,"refusal preserves clothing")
	assert_true(frame.u8_column(9)==status,"refusal preserves status")
''' % (schema_code, code, 'true' if gate4 else 'false')


def execute(clone, label, expect_failure=False):
    result = subprocess.run(['godot','--headless','--path','godot','--script',
                             'res://test/needs_metadata_probe_focus.gd'],cwd=clone,text=True,
                            stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    match = re.search(r'^1 test\(s\), 9 assertion\(s\), (\d+) failure\(s\)$',result.stdout,re.M)
    valid = match is not None and 'SCRIPT ERROR:' not in result.stdout and 'Parse Error:' not in result.stdout
    killed = bool(valid and int(match[1]) > 0 and result.returncode != 0)
    passed = bool(valid and int(match[1]) == 0 and result.returncode == 0)
    assert killed if expect_failure else passed, label+'\n'+result.stdout
    return {'case':label,'assertions':9,'valid_execution':valid,'killed_bypass':killed,'passed':passed}


def main():
    originals = {path:(ROOT/path).read_bytes() for path in [NEEDS,SCHEMA,BRIDGE]}
    results=[]
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-needs-metadata-') as scratch:
            clone=Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/needs_metadata_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_needs_metadata_probe.gd"])\n')
            probe=clone/'godot/test/test_needs_metadata_probe.gd'
            probe.write_text(suite('','',False))
            results.append(execute(clone,'unmodified-positive-control'))
            for name in ['COLUMN_KEYS','COLUMN_TYPE_CODES','COLUMN_EXTENTS']:
                for fault in ['short','long','value']:
                    (clone/NEEDS).write_text(publication_fault(originals[NEEDS].decode(),name,fault))
                    probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                    results.append(execute(clone,name+'-'+fault))
            (clone/NEEDS).write_bytes(originals[NEEDS])
            expressions = {
                'key': 'Schema.owner_key(OWNER_INDEX) != OWNER_KEY',
                'version': 'Schema.owner_version(OWNER_INDEX) != OWNER_VERSION',
                'primary': 'Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT',
                'children': 'Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT',
            }
            for fault, expression in expressions.items():
                (clone/SCHEMA).write_text(schema_fault(originals[SCHEMA].decode(),fault))
                probe.write_text(suite('SAVE_COMPONENT_METADATA','',True))
                results.append(execute(clone,'owner-'+fault+'-fault-refused'))
                (clone/BRIDGE).write_text(replace_once(originals[BRIDGE].decode(),expression,'false'))
                results.append(execute(clone,'owner-'+fault+'-gate-bypassed',True))
                (clone/BRIDGE).write_bytes(originals[BRIDGE])
            (clone/SCHEMA).write_text(replace_once(originals[SCHEMA].decode(),
                'const OWNER_OFFSETS: Array = [\n\t4,','const OWNER_OFFSETS: Array = [\n\t5,'))
            probe.write_text(suite('SAVE_COMPONENT_METADATA','SAVE_COMPONENT_METADATA',False))
            results.append(execute(clone,'schema-gate-before-owner-parity'))
    finally:
        for path, original in originals.items():
            assert (ROOT/path).read_bytes() == original
    assert len(results)==19
    print(json.dumps({'status':'PASS','cases':results,'source_sha256':{
        str(path):hashlib.sha256(data).hexdigest() for path,data in originals.items()}},indent=2))


if __name__=='__main__':
    main()
