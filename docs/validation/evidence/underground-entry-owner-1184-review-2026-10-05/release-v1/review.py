#!/usr/bin/env python3
"""Independent read-only replay of the exact three-owner release checkpoint."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REL = 'docs/validation/evidence/underground-entry-owner-composition-2026-10-05/entry-release-v1'
PINS = {
    'godot/scripts/core/underground_entry_bindings.gd': 'f94bc772b7faace72464a000d1b0c71ea725f9ca573db788b094311391a3b183',
    'godot/scripts/core/underground_connector_placements.gd': '07d41b2dfdb6294a13e681e21fbb93b8e4b643f4befd60ae5136888512009c7a',
    'godot/scripts/core/underground_connector_delivery.gd': 'ecfecabe1b3ed05e5d4ae7870c75383302330526879c7a6321f7afb25090a583',
    'godot/test/test_underground_entry_composition.gd': 'd8c2ba09d7d1357a2d7518cb5dfff4d1ce8f036f7e1195e1f92dc06b83c9bb46',
    'godot/test/test_underground_entry_composition.gd.uid': 'ea882f0046951dc33ac5ea9e243b8fa978a56332b9c7e23ba7446947a7101158',
    REL + '/census.py': 'c04d5853afc8f658e79f2b4395c4566b09092308b449af89238c3e1bdd13b2d4',
    REL + '/test_census.py': 'c81b4a0efc40886892c35d15984716d0b38c8d91a95fa0a4df1a72becdf23933',
    REL + '/reproduce.py': 'c1b04dd36eed5d94bf5a71da99667a0a0174f779ae043cde67981a038607d16f',
}
ARCHIVED = {
    # The author continues additive kernel tests in this file. Review the exact executed release snapshot.
    'godot/test/test_underground_entry_composition.gd':
        REL + '/candidate-2/executed-source/test_underground_entry_composition.gd.txt',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value, reason):
    if not value:
        raise ValueError(reason)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    current = {path: digest(root / ARCHIVED.get(path, path)) for path in PINS}
    require(current == PINS, 'Frozen review source drift')
    evidence = root / REL
    require(json.loads((evidence / 'checkpoint-sha256.json').read_text()) == PINS,
            'Author checkpoint differs from independent pins')
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    with (HERE / 'census-tests.log').open('w') as stream:
        subprocess.run([sys.executable, '-B', str(evidence / 'test_census.py')],
                       cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
    spec = importlib.util.spec_from_file_location('entry_release_review_census', evidence / 'census.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    census = module.build()
    encoded = json.dumps(census, indent=2) + '\n'
    require(encoded == (evidence / 'census.json').read_text(), 'Census replay differs')
    (HERE / 'census.json').write_text(encoded)
    run = json.loads((evidence / 'candidate-2/invocation.json').read_text())
    for flag in ('executed_source_unchanged', 'project_restored', 'registry_restored',
                 'assets_restored', 'import_sidecars_restored', 'original_sources_restored', 'head_unchanged'):
        require(run[flag] is True, 'Author restoration failed: ' + flag)
    require(run['exit_code'] == 0 and not run['import_raw_findings'], 'Author execution failed')
    totals = {'tests': 0, 'assertions': 0}
    for name, counters in run['strict_suites'].items():
        for key in ('failures', 'unexpected_errors', 'unexpected_warnings', 'expected',
                    'tolerated', 'leaked_objects', 'leaked_resources'):
            require(counters[key] == 0, name + ': ' + key)
        for key in totals:
            totals[key] += counters[key]
        raw = (evidence / 'candidate-2' / (name + '.log')).read_text()
        require(f"{counters['tests']} test(s), {counters['assertions']} assertion(s), 0 failure(s)" in raw,
                'Missing raw strict summary: ' + name)
        require('log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).' in raw,
                'Missing raw diagnostic summary: ' + name)
    require(totals == {'tests': 86, 'assertions': 11684}, 'Unexpected test totals')
    require('0 GDScript warning(s) in 0 of 4 file(s)' in
            (evidence / 'candidate-2/analyzer.log').read_text(), 'Missing analyzer summary')
    require({path: digest(root / ARCHIVED.get(path, path)) for path in PINS} == PINS,
            'Source changed during review')
    result = {
        'scope': 'Owner-local EntryBindings, Placements and Delivery release only; complete Session kernel remains open.',
        'reviewer': '/root', 'source_sha256': PINS, 'source_locators': ARCHIVED, 'source_unchanged': True,
        'independent_census_tests': 11, 'census_byte_identical': True,
        'author_engine_evidence_verified': totals, 'engine_repeated_by_reviewer': False,
        'additional_retained_bytes': census['additional_retained_bytes'],
        'additional_constructor_allocation_bytes': census['additional_constructor_allocation_bytes'],
        'standalone_helper_bytes': {name: row['provisional_bytes'] for name, row in census['phases'].items()},
        'verdict': 'ACCEPTED for this narrow release component; no full-kernel, production publication or native qualification.',
        'required_composition_checks': [
            'Capture and match the original Host Planner and SimClock identities before any clear.',
            'All owner and canonical core preflights must finish before the first release write.',
            'Retain exact stopped constructor prefixes; foreign or active context links must refuse.',
            'Prove the complete release order and new constructor/helper lifetimes within existing ceilings.',
        ],
    }
    (HERE / 'review.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
