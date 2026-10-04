#!/usr/bin/env python3
"""Independent read-only ADR1142 review; write evidence only beside this file."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SOURCE = Path('/Users/brendan/Developer/redwall-rts-codex-ug-space')
BASE = SOURCE / 'godot/data/underground/mole-worker/evidence/contact-qualification'
PACKET = BASE / 'stair-handoffs-v1'
OUT = Path(__file__).resolve().parent
MANIFEST_PINS = {
    'source-sha256.json': 'c9d5a97579bb0b5867082ff2b96db707532cd8d62cb6c4472347c24680f1b925',
    'output-sha256.json': '8269f80a2a4fc7020ad8a72ead6f0b8f89250f2c2fc020bd89b9031893bf57c3',
    'history-sha256.json': '5cf4d070e3dc6d87bee27ba3191e220b6bc027995068b05d51961e5797f5d54d',
    'inherited-sha256.json': '5588390a4d02e1fec3705d86b4cbcf0721dfc1192a570d91942d5219a33bcf77',
}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write(name, value):
    with (OUT / name).open('x') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')


def manifest_state():
    result = {}
    for name, expected in MANIFEST_PINS.items():
        path = PACKET / 'review-v1' / name
        assert sha(path) == expected, name
        rows = json.loads(path.read_text())
        matches = {}
        for relative, digest in rows.items():
            source = SOURCE / relative
            assert source.resolve().is_relative_to(SOURCE), relative
            actual = sha(source)
            assert actual == digest, (relative, digest, actual)
            matches[relative] = actual
        result[name] = {'sha256': expected, 'count': len(rows), 'files': matches}
    result['git'] = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=SOURCE, text=True).strip(),
        'tracked_status': subprocess.check_output(['git', 'status', '--short', '--untracked-files=no'], cwd=SOURCE, text=True),
    }
    return result


def run(name, args):
    argv = [sys.executable, '-B', *map(str, args)]
    start = time.monotonic()
    with (OUT / (name + '.log')).open('x') as stream:
        result = subprocess.run(argv, cwd=SOURCE, stdout=stream, stderr=subprocess.STDOUT,
                                env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
    row = {'argv': argv, 'cwd': str(SOURCE), 'elapsed_seconds': time.monotonic() - start,
           'exit_code': result.returncode, 'log_sha256': sha(OUT / (name + '.log'))}
    write(name + '-invocation.json', row)
    print(json.dumps({'step': name, **row}), flush=True)
    assert result.returncode == 0, name
    return row


def main():
    before = manifest_state()
    write('manifests-before.json', before)
    steps = []
    for name in ('test_stair_handoffs', 'test_stair_handoff_proof'):
        steps.append(run(name, [BASE / (name + '.py')]))
    comparisons = {}
    for kind in ('terrain', 'tool-body'):
        output = OUT / ('turn-' + kind)
        steps.append(run('turn-' + kind, [BASE / 'prove_stair_handoffs.py', PACKET / 'candidate-6/result',
                                         output, '--name', 'turn', '--kind', kind]))
        original = PACKET / 'proof-v1/turn' / kind / 'result/proof.json'
        copied = output / 'proof.json'
        assert json.loads(original.read_text()) == json.loads(copied.read_text()), kind
        comparisons[kind] = {'original_sha256': sha(original), 'replayed_sha256': sha(copied),
                             'byte_equal': original.read_bytes() == copied.read_bytes()}
    steps.append(run('column-proposal', [PACKET / 'summarize_program.py', PACKET / 'candidate-6/result',
                                         PACKET / 'proof-v1', OUT / 'column-proposal']))
    original = PACKET / 'column-proposal-v2/result/program.json'
    copied = OUT / 'column-proposal/program.json'
    assert json.loads(original.read_text()) == json.loads(copied.read_text()), 'column proposal'
    comparisons['columns'] = {'original_sha256': sha(original), 'replayed_sha256': sha(copied),
                              'byte_equal': original.read_bytes() == copied.read_bytes()}
    after = manifest_state()
    write('manifests-after.json', after)
    assert before == after
    write('result.json', {'steps': steps, 'comparisons': comparisons, 'manifests_unchanged': True,
                          'engine_or_native_run': False, 'runtime_qualification': False})
    print(json.dumps({'complete': True, 'comparisons': comparisons}), flush=True)


if __name__ == '__main__':
    main()
