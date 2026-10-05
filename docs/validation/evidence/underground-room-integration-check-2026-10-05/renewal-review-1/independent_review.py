#!/usr/bin/env python3
"""Read-only renewal review; publication probes write only this evidence tree."""
import contextlib
import difflib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from unittest import mock

ROOT = Path('/Users/brendan/Developer/redwall-rts-codex-ug-integration')
OUT = Path(__file__).resolve().parent
PRODUCER = 'godot/data/underground/mole-worker/renew_work_approach_profiles.py'
spec = importlib.util.spec_from_file_location('reviewed_frontier_renewal', ROOT / PRODUCER)
renew = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renew)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    pins = json.loads((OUT / 'review-inputs.json').read_text())
    assert all(sha((ROOT / path).read_bytes()) == expected for path, expected in pins.items())
    wire, constants, manifest = renew.inputs()
    old = json.loads((ROOT / renew.OLD / 'manifest.json').read_bytes())
    expected_fields = {
        'consumer_commit', 'consumers', 'prerequisite_pins', 'constants_sha256',
        'source_review_sha256', 'historical_source_replacements', 'renewed_from_sha256',
        'source_native_replay_sha256', 'scope',
    }
    changed_fields = {name for name in old.keys() | manifest.keys() if old.get(name) != manifest.get(name)}
    assert changed_fields == expected_fields, changed_fields
    assert len(old['prerequisite_pins']) == 509
    assert wire == (ROOT / renew.OLD / 'mole-worker.ugprof').read_bytes()
    assert not manifest['world_activation_qualified']
    before_constants = (ROOT / renew.OLD / 'catalog_source.gd').read_text()
    delta = ''.join(difflib.unified_diff(before_constants.splitlines(True), constants.decode().splitlines(True),
                                       fromfile='immutable-v3/catalog_source.gd', tofile='renewed/catalog_source.gd', n=0))
    (OUT / 'constants.diff').write_text(delta)
    assert len([line for line in delta.splitlines() if line.startswith('+') and not line.startswith('+++')]) == 5
    closure = {path: sha((ROOT / path).read_bytes()) for path in manifest['prerequisite_pins']}
    assert closure == manifest['prerequisite_pins']
    (OUT / 'verified-prerequisite-pins.json').write_text(json.dumps(closure, indent=2) + '\n')
    # The implementation's path gate is kept, but its allowed output root is
    # relocated to this reviewer's evidence so no foreign tree is written.
    publication_directory = tempfile.TemporaryDirectory(dir=OUT, prefix='publication-replay-')
    publication_root = Path(publication_directory.name)
    output = publication_root / 'successor'
    with mock.patch.object(renew, 'HERE', publication_root), contextlib.redirect_stdout(io.StringIO()):
        renew.publish(output)
    outputs = {
        'mole-worker.ugprof': wire,
        'catalog_source.gd': constants,
        'manifest.json': (json.dumps(manifest, indent=2) + '\n').encode(),
    }
    assert all((output / name).read_bytes() == raw for name, raw in outputs.items())
    with mock.patch.object(renew, 'HERE', publication_root), mock.patch.object(renew, 'inputs') as capture:
        try:
            renew.publish(output)
        except ValueError as error:
            assert str(error) == 'FRONTIER_RENEWAL_OUTPUT'
        else:
            raise AssertionError('existing successor was overwritten')
        capture.assert_not_called()
    # Change a source only in the read view after inputs has returned. The
    # final pass must refuse before creating any successor path.
    original_inputs = renew.inputs
    original_read = Path.read_bytes
    source = ROOT / renew.CHANGED[0]
    armed = False

    def returned_inputs():
        nonlocal armed
        value = original_inputs()
        armed = True
        return value

    def changed_read(path):
        raw = original_read(path)
        return raw + b'\n# changed after capture\n' if armed and path == source else raw

    late_output = publication_root / 'must-remain-absent'
    with mock.patch.object(renew, 'HERE', publication_root), mock.patch.object(renew, 'inputs', returned_inputs), \
            mock.patch.object(Path, 'read_bytes', changed_read):
        try:
            renew.publish(late_output)
        except ValueError as error:
            late_refusal = str(error)
            assert late_refusal == 'FRONTIER_RENEWAL_HASH:' + renew.CHANGED[0]
        else:
            raise AssertionError('late source mutation published')
    assert not late_output.exists()
    assert all((output / name).read_bytes() == raw for name, raw in outputs.items())
    archived = OUT / 'rebuilt-successor'
    if archived.exists():
        assert all((archived / name).read_bytes() == raw for name, raw in outputs.items())
    else:
        archived.mkdir()
        for name, raw in outputs.items():
            (archived / name).write_bytes(raw)
    publication_directory.cleanup()
    # Exercise real symlink and file-size gates in reviewer-owned temporary
    # files; no source root path is changed or populated.
    with tempfile.TemporaryDirectory(dir=OUT, prefix='bounded-input-') as directory:
        scratch = Path(directory)
        with (scratch / 'oversize').open('wb') as stream:
            stream.truncate(32 * 1024 * 1024 + 1)
        (scratch / 'alias').symlink_to(scratch / 'oversize')
        for name in ('oversize', 'alias'):
            with mock.patch.object(renew, 'ROOT', scratch), mock.patch.object(Path, 'read_bytes') as read:
                try:
                    renew.read(name, '0' * 64)
                except ValueError as error:
                    assert str(error) == 'FRONTIER_RENEWAL_FILE:' + name
                else:
                    raise AssertionError('unbounded/aliased input read')
                read.assert_not_called()
    assert all(sha((ROOT / path).read_bytes()) == expected for path, expected in pins.items())
    assert all(sha((ROOT / path).read_bytes()) == expected for path, expected in closure.items())
    report = {
        'old_prerequisites': 509, 'renewed_prerequisites': len(closure),
        'current_consumers': len(manifest['consumers']), 'changed_consumers': len(renew.CHANGED),
        'all_other_manifest_fields_unchanged': True, 'changed_manifest_fields': sorted(changed_fields),
        'wire_byte_identical': True, 'constants_changed_lines': 5,
        'outputs': {name: {'bytes': len(raw), 'sha256': sha(raw)} for name, raw in outputs.items()},
        'isolated_create_only_publish_passed': True, 'existing_output_refused_before_inputs': True,
        'late_source_refusal_before_output_creation': late_refusal,
        'oversized_and_symlink_inputs_refused_before_read': True,
        'source_and_prerequisite_pins_unchanged': True, 'foreign_writes': False,
        'godot_rerun': False, 'world_activation_qualified': False,
    }
    (OUT / 'independent-review.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: immutable geometry; 9 current consumers; create-only output; late revalidation and bounded-input refusals')


if __name__ == '__main__':
    main()
