#!/usr/bin/env python3
"""Exercise real refusal branches and kill preflight bypasses in a disposable Godot clone.

A reversed probe buffer simulates a byte-order mismatch; it is not a big-endian
machine measurement. Bad compiled metadata changes the first owner offset. Both
faults must stop both cursors before input/output. Production source is read only.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STREAM = Path('godot/scripts/core/save_section_component_columns.gd')
SCHEMA = Path('godot/scripts/core/save_component_columns_schema.gd')


def replace_once(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)


def bypass(source, cursor, fault):
    start = source.index('static func ' + cursor + '_preflight_refusal(')
    stop = source.index('\n\nstatic func ', start)
    body = source[start:stop]
    if fault == 'byte_order':
        body = replace_once(body, '\treturn byte_order_refusal()', '\treturn accepted()')
    else:
        body = replace_once(body, '\tvar metadata: SaveHeader.Refusal = Schema.schema_refusal()',
                            '\tvar metadata: SaveHeader.Refusal = accepted()')
    return source[:start] + body + source[stop:]


def probe_suite(code):
    refused = bool(code)
    return '''extends "res://test/framework/test_case.gd"
const Section := preload("res://scripts/core/save_section_component_columns.gd")
func test_both_cursors_stop_on_injected_preflight_fault() -> void:
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(2,193184)
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	assert_equal(encoder.refusal().code,&"%s","encoder preflight result")
	assert_equal(decoder.refusal().code,&"%s","decoder preflight result")
	assert_equal(encoder.emitted_bytes(),0,"encoder cannot emit during preflight")
	assert_equal(decoder.consumed_bytes(),0,"decoder cannot consume during preflight")
	assert_equal(encoder.has_more(),%s,"encoder stops on refusal")
	assert_equal(decoder.next_read_size(),%d,"decoder stops before owner allocation")
	assert_false(encoder.needs_owner(),"constructor never asks for owner yet")
	assert_false(decoder.owner_ready(),"constructor cannot publish an owner")
''' % (code,code,'false' if refused else 'true',0 if refused else 4)


def execute(clone, label, expect_failure):
    result = subprocess.run(['godot','--headless','--path','godot','--script',
                             'res://test/component_preflight_probe_focus.gd'], cwd=clone,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,text=True,timeout=90)
    match = re.search(r'^1 test\(s\), 8 assertion\(s\), (\d+) failure\(s\)$',result.stdout,re.M)
    valid = match is not None and 'SCRIPT ERROR:' not in result.stdout and 'Parse Error:' not in result.stdout
    failed = valid and int(match[1]) > 0 and result.returncode != 0
    passed = valid and int(match[1]) == 0 and result.returncode == 0
    assert failed if expect_failure else passed, label + '\n' + result.stdout
    return {'case':label,'assertions':8,'assertion_failure_killed_bypass':failed,'valid_execution':valid}


def main():
    original_stream = (ROOT/STREAM).read_bytes()
    original_schema = (ROOT/SCHEMA).read_bytes()
    results = []
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-preflight-') as scratch:
            clone = Path(scratch)
            shutil.copytree(ROOT/'godot',clone/'godot')
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            (clone/'godot/test/component_preflight_probe_focus.gd').write_text(
                'extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n'
                '\treturn PackedStringArray(["res://test/test_component_preflight_probe.gd"])\n')
            suite = clone/'godot/test/test_component_preflight_probe.gd'
            suite.write_text(probe_suite(''))
            results.append(execute(clone,'unmodified-positive-control',False))
            for fault, code in [('byte_order','SAVE_COMPONENT_BYTE_ORDER'),('metadata','SAVE_COMPONENT_METADATA')]:
                stream = original_stream.decode()
                schema = original_schema.decode()
                if fault == 'byte_order':
                    anchor = '\tvar probe: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()\n'
                    stream = replace_once(stream,anchor,anchor+'\tprobe.reverse() # injected mismatch, not a native big-endian host\n')
                else:
                    schema = replace_once(schema,'const OWNER_OFFSETS: Array = [\n\t4,',
                                          'const OWNER_OFFSETS: Array = [\n\t5,')
                (clone/SCHEMA).write_text(schema)
                suite.write_text(probe_suite(code))
                (clone/STREAM).write_text(stream)
                results.append(execute(clone,fault+'-fault-refused',False))
                for cursor in ['encode','decode']:
                    (clone/STREAM).write_text(bypass(stream,cursor,fault))
                    results.append(execute(clone,fault+'-'+cursor+'-bypass',True))
    finally:
        assert (ROOT/STREAM).read_bytes() == original_stream
        assert (ROOT/SCHEMA).read_bytes() == original_schema
    print(json.dumps({'status':'PASS','cases':results,
                      'stream_sha256':hashlib.sha256(original_stream).hexdigest(),
                      'schema_sha256':hashlib.sha256(original_schema).hexdigest(),
                      'native_big_endian_tested':False},indent=2))


if __name__ == '__main__':
    main()
