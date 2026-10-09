#!/usr/bin/env python3
"""Independent read-only artifact/native replay. Never launches Godot."""
import hashlib
import importlib.util
import json
from pathlib import Path

AUTHOR = Path('/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime')
E = AUTHOR / 'docs/validation/evidence/underground-short-work-step-runtime-2026-10-05'
P = AUTHOR / 'godot/data/underground/mole-worker/work-step-v1'
OUT = Path(__file__).resolve().parent

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        while block := file.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def main():
    pins = json.loads((OUT / 'original-source-pins.json').read_text())
    excluded = {str((E / f).relative_to(AUTHOR)) for f in ('census.py', 'test_census.py')}
    unchanged = {path: digest for path, digest in pins.items() if path not in excluded}
    assert all(sha(AUTHOR / path) == digest for path, digest in unchanged.items())
    profile = load('independent_step_serializer', P / 'assemble_diagnostic.py')
    wire, mapping = profile.encode(profile.OLD.read_bytes(), profile.REPORT.read_bytes())
    assert wire == (E / 'profile-diagnostic-1/mole-worker.ugprof').read_bytes()
    assert mapping == json.loads((E / 'profile-diagnostic-1/manifest.json').read_text())['mapping']
    (OUT / 'rebuilt-profile.ugprof').write_bytes(wire)
    ground = load('independent_step_ground', P / 'assemble_ground_diagnostic.py')
    pace, manifest = ground.build()
    assert pace == (P / 'diagnostic-ground-v1/ground-pace.ugconn').read_bytes()
    ground_manifest = (json.dumps(manifest, indent=2) + '\n').encode()
    assert ground_manifest == (P / 'diagnostic-ground-v1/manifest.json').read_bytes()
    (OUT / 'rebuilt-ground.ugconn').write_bytes(pace)
    (OUT / 'rebuilt-ground-manifest.json').write_bytes(ground_manifest)
    native = load('independent_step_native', P / 'run_canonical.py')
    verification = native.validate(E / 'native-3')
    assert verification == json.loads((E / 'native-3/verification.json').read_text())
    before = json.loads((E / 'native-3/sources-before.json').read_text())
    after = json.loads((E / 'native-3/sources-after.json').read_text())
    assert before == after
    bad = [path for path, digest in before.items() if not Path(path).is_file() or sha(Path(path)) != digest]
    assert not bad, bad
    runtime = json.loads((E / 'runtime-6/source-sha256.json').read_text())
    assert all(sha(AUTHOR / path) == digest for path, digest in runtime.items())
    for invocation in ('runtime-6', 'native-3'):
        record = json.loads((E / invocation / 'invocation.json').read_text())
        assert record['source_unchanged']
        assert all(c.get('exit_code', c.get('exit')) == 0 for c in record['commands'])
    assert all(sha(AUTHOR / path) == digest for path, digest in unchanged.items())
    report = {'unchanged_candidate_source_pins': len(unchanged), 'runtime_source_pins': len(runtime),
              'native_input_pins': len(before), 'native_all_inputs_match_current': True,
              'profile_wire_byte_exact': True, 'profile_row_mapping_exact': True,
              'ground_wire_and_manifest_byte_exact': True, 'native_verification_exact': True,
              'verification': verification, 'engine_invoked': False, 'author_sources_written': False}
    (OUT / 'replay-results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
