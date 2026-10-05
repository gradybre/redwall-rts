#!/usr/bin/env python3
"""Read-only review probes; output stays beside this script in the reviewer's worktree."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from unittest import mock

ROOT = Path('/Users/brendan/Developer/redwall-rts-codex-ug-integration')
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
import audit_registry_capacities as audit
import underground_room_memory as room
import underground_memory_budget as budget


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    pins = json.loads((OUT / 'review-inputs.json').read_text())
    assert all(sha((ROOT / path).read_bytes()) == expected for path, expected in pins.items())
    manifest = json.loads((ROOT / room.MANIFEST).read_text())
    index = audit.load_source_index()
    source_results = []
    for name, row in manifest['sources'].items():
        raw = (ROOT / row['path']).read_bytes()
        assert sha(raw) == row['sha256']
        source_results.append({'module': name, 'path': row['path'], 'sha256': sha(raw)})
    witnesses = {}
    for path, expected in manifest['witnesses'].items():
        assert sha((ROOT / path).read_bytes()) == expected
        witnesses[path] = expected
    predecessors = []
    for group in ('baseline', 'publisher_predecessors'):
        for name, row in manifest[group].items():
            path = manifest['sources'][name]['path']
            revision = row.get('revision', '8373d146')
            data = subprocess.check_output(['git', 'show', revision + ':' + path], cwd=ROOT)
            assert sha(data) == row['sha256'] == sha((ROOT / row['locator']).read_bytes())
            predecessors.append({'group': group, 'module': name, 'revision': revision,
                                 'path': path, 'sha256': sha(data)})
    injected_refusals = []
    for name, row in manifest['sources'].items():
        old = index.get(name) or audit.parse_module(name, row['path'], (ROOT / row['path']).read_text())
        changed = old._replace(text=old.text + '\nvar review_hidden_scratch: PackedByteArray = PackedByteArray()\n')
        with mock.patch.object(room, 'producer') as execute:
            try:
                room.build(dict(index, **{name: changed}))
            except ValueError as error:
                assert 'current reviewed source changed' in str(error)
            else:
                raise AssertionError('accepted hidden state in ' + name)
            execute.assert_not_called()
        injected_refusals.append(name)
    real_read = Path.read_bytes
    witness_refusals = []
    all_witnesses = dict(witnesses)
    for group in ('baseline', 'publisher_predecessors'):
        all_witnesses.update({row['locator']: row['sha256'] for row in manifest[group].values()})
    for relative in all_witnesses:
        target = ROOT / relative
        def mutate(path):
            data = real_read(path)
            return data + b'\n# independent changed witness\n' if path == target else data
        with mock.patch.object(Path, 'read_bytes', mutate), mock.patch.object(room, 'producer') as execute:
            try:
                room.build(index)
            except ValueError:
                pass
            else:
                raise AssertionError('accepted changed witness ' + relative)
            execute.assert_not_called()
        witness_refusals.append(relative)
    with mock.patch.object(subprocess, 'check_output', side_effect=AssertionError('normal build must not need Git')):
        result = budget.build()
    expected = json.loads((ROOT / 'docs/planning/underground_memory_pack.json').read_text())
    assert json.loads(json.dumps(result)) == expected
    assert json.dumps(result, indent=2) + '\n' == (ROOT / 'docs/planning/underground_memory_pack.json').read_text()
    extension = result['room_extension_reservation']
    assert extension['additional_global_reserved_bytes'] == 0
    assert result['live_with_reserve_bytes'] == 99999806 and result['headroom_bytes'] == 194
    assert result['ui_reset_reservation']['accounting']['controls'] == 6019
    assert result['ui_reset_reservation']['accounting']['helpers'] == 1903
    assert extension['composition']['constructor_exclusive_reuse']['simultaneous_total'] == 7493
    assert extension['ground_catalog']['fixed_peak_accounted'] == 1468
    assert not result['runtime_qualified'] and not extension['native_measured']
    assert all(sha((ROOT / path).read_bytes()) == expected for path, expected in pins.items())
    report = {'current_sources': source_results, 'witnesses': witnesses, 'exact_git_predecessors': predecessors,
              'injected_current_source_refusals_before_producer': injected_refusals,
              'changed_witness_refusals_before_producer': witness_refusals,
              'normal_build_without_git': True, 'generated_pack_semantically_identical': True,
              'controls': 6019, 'helpers': 1903, 'constructor_simultaneous_total': 7493,
              'lifecycle_reservation': 8192, 'ground_catalog_fixed': 1468, 'ground_catalog_fixed_reserve': 2048,
              'live_with_reserve_bytes': 99999806, 'headroom_bytes': 194,
              'source_and_metadata_pins_unchanged': True, 'runtime_qualified': False, 'native_measured': False}
    (OUT / 'independent-probe.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS:', len(source_results), 'current sources;', len(witnesses), 'immutable witnesses;',
          len(predecessors), 'exact predecessors;', len(injected_refusals) + len(witness_refusals),
          'pre-execution refusal probes; exact complete pack replay')


if __name__ == '__main__':
    main()
