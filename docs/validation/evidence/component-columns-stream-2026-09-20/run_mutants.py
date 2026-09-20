"""Mutate an owned temporary clone; never edit a worker's frozen source inputs."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
REL = Path('godot/scripts/core/save_section_component_columns.gd')
original = (ROOT / REL).read_bytes()
results = []
EXPECTED_TESTS = sum(len(re.findall(r"^func test_", (ROOT / name).read_text(), re.M)) for name in ["godot/test/test_save_component_columns_schema.gd", "godot/test/test_save_section_component_columns.gd"])

def replace(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)


def variant(name):
    s = original.decode()
    anchor = '\t\tif expected.is_empty() or bytes != expected:\n'
    if name == 'omit-child-extents':
        patch = ('\t\tif stage == 1:\n'
                 '\t\t\texpected = expected.duplicate()\n'
                 '\t\t\tvar first_child: int = SaveSectionComponentColumnsScript.wrapper_bytes(_owner) - Schema.child_extent_count(_owner) * 8\n'
                 '\t\t\tfor index: int in range(first_child,expected.size()):\n'
                 '\t\t\t\texpected[index] = bytes[index]\n')
        return replace(s, anchor, patch + anchor)
    if name == 'omit-payload-length':
        patch = ('\t\tif stage == 1:\n'
                 '\t\t\texpected = expected.duplicate()\n'
                 '\t\t\tvar length_at: int = 16 + Schema.owner_key(_owner).to_utf8_buffer().size()\n'
                 '\t\t\tfor index: int in range(length_at,length_at+8):\n'
                 '\t\t\t\texpected[index] = bytes[index]\n')
        return replace(s, anchor, patch + anchor)
    if name == 'swap-equal-shape-columns':
        anchor = '\tvar code: int = Schema.field_type(record.owner, field)\n'
        start = s.index('static func column_fragment(')
        stop = s.index('static func release_column(')
        body = replace(s[start:stop], anchor, '\tif record.owner == 0 and field in [3,4]:\n\t\tfield = 7 - field\n' + anchor)
        return s[:start] + body + s[stop:]
    if name == 'allow-wrong-owner-order':
        return replace(s, '\t\tif record.owner != _owner:\n', '\t\tif false:\n')
    if name == 'publish-partial-owner':
        return replace(s, '\t\tif not _ready or _record == null:\n', '\t\tif _record == null:\n')
    if name == 'omit-section-length-preflight':
        return replace(s, '\tif section_byte_length != Schema.SECTION_BYTES:\n', '\tif section_byte_length == -2:\n')
    raise AssertionError(name)


def run(clone, name, expected_failure):
    result = subprocess.run(['godot','--headless','--path','godot','--script','res://test/component_columns_focus.gd'],
                            cwd=clone, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    (E / (name+'.log')).write_text(result.stdout)
    match = re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',result.stdout,re.M)
    valid = match is not None and int(match[1]) == EXPECTED_TESTS and 'SCRIPT ERROR:' not in result.stdout and 'Parse Error:' not in result.stdout
    killed = valid and int(match[3]) > 0 and result.returncode != 0
    passed = valid and int(match[3]) == 0 and result.returncode == 0
    row = {'name':name,'exit_code':result.returncode,'valid_execution':valid,'killed':killed,
           'summary':[line for line in result.stdout.splitlines() if '  FAIL ' in line or re.match(r'^\d+ test\(s\)',line)]}
    results.append(row)
    print(json.dumps(row),flush=True)
    assert killed if expected_failure else passed, row

try:
    with tempfile.TemporaryDirectory(prefix='redwall-component-mutants-') as scratch:
        clone = Path(scratch)
        shutil.copytree(ROOT/'godot',clone/'godot')
        (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
        (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
        run(clone,'mutation-baseline',False)
        for name in ['omit-child-extents','omit-payload-length','swap-equal-shape-columns',
                     'allow-wrong-owner-order','publish-partial-owner','omit-section-length-preflight']:
            (clone/REL).write_text(variant(name))
            run(clone,name,True)
        (clone/REL).write_bytes(original)
        run(clone,'mutation-restored',False)
finally:
    assert (ROOT/REL).read_bytes() == original
    (E/'mutation-results.json').write_text(json.dumps({'source_sha256':hashlib.sha256(original).hexdigest(),
                                                     'source_unchanged':True,'results':results},indent=2)+'\n')
assert len(results) == 8
