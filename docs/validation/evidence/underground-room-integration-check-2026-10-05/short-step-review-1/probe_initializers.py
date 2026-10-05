#!/usr/bin/env python3
"""Run against the immutable rejected producer, not its in-progress correction."""
import hashlib
import json
from pathlib import Path
import types
from unittest import mock

AUTHOR = Path('/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime')
E = AUTHOR / 'docs/validation/evidence/underground-short-work-step-runtime-2026-10-05'
OUT = Path(__file__).resolve().parent
raw = (E / 'source-review-1/docs__validation__evidence__underground-short-work-step-runtime-2026-10-05__census.py.txt').read_bytes()
assert hashlib.sha256(raw).hexdigest() == '1a7911d0a2f531c77e4e0c16059a197d83e198966087953e08421fb581462bf5'
C = types.ModuleType('frozen_1168_census')
C.__file__ = str(E / 'census.py')
exec(compile(raw, C.__file__, 'exec', optimize=0), C.__dict__)
contract = (E / 'source-review-1/call-contract.json.txt').read_bytes()
assert hashlib.sha256(contract).hexdigest() == C.CALL_CONTRACT_SHA
read_bytes = Path.read_bytes
def exact_original(path):
    return contract if path == E / 'supporting/call-contract.json' else read_bytes(path)
def build(overrides=None):
    with mock.patch.object(Path, 'read_bytes', exact_original):
        return C.build(overrides)
baseline = build()
rows = []
for name, module, old, new in (
    ('driver_pose_growth', C.D, 'var _pose: PackedInt32Array = PackedInt32Array([0, 0, 0])',
     'var _pose: PackedInt32Array = PackedInt32Array([' + ','.join(['0'] * 65536) + '])'),
    ('profile_header_growth', C.P, 'var header: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])',
     'var header: PackedInt64Array = PackedInt64Array([' + ','.join(['0'] * 4096) + '])'),
):
    source = C.path(module).read_text()
    assert old in source
    changed = source.replace(old, new, 1)
    try:
        result = build({module: changed})
    except ValueError as error:
        rows.append({'name': name, 'refused': True, 'message': str(error)})
    else:
        rows.append({'name': name, 'refused': False,
                     'counted_before': baseline['profile_control']['counted_logical'],
                     'counted_after': result['profile_control']['counted_logical'],
                     'mutated_source_sha256': hashlib.sha256(changed.encode()).hexdigest(),
                     'old_initializer': old, 'new_initializer': new})
(OUT / 'initializer-probes.json').write_text(json.dumps(rows, indent=2) + '\n')
print(json.dumps([{k:v for k,v in row.items() if k not in ('old_initializer','new_initializer')} for row in rows], indent=2))
