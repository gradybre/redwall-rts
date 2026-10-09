#!/usr/bin/env python3
"""Independent exact-input verification of the composed diagnostic retirement kernel."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REL = 'docs/validation/evidence/underground-entry-owner-composition-2026-10-05/entry-kernel-v1'
MANIFESTS = {
    'source-sha256.json': ('dfc6c17f24e2bf4561007b8ac7df0894ff369217da0ff9f0cb5760b6eaf530a0', 5),
    'inherited-sha256.json': ('9b73c1df4eccbab20aa93403dec1acd6d00bdd2728bda412646731857c4f1ced', 182),
    'output-sha256.json': ('de5ebcf852514fb2c93cb2a0a9993df599d7825ee67eacb30140e7feeb8ce9b2', 33),
    'history-sha256.json': ('dee8c06ec509b11bc07023663b162b9c196bf6e9ebc298612963d4c73f4df2ae', 30),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(value, reason):
    if not value:
        raise ValueError(reason)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    evidence = root / REL
    frozen = {}
    groups = {}
    for name, (expected, count) in MANIFESTS.items():
        path = evidence / 'source-review-1' / name
        raw = path.read_bytes()
        require(sha(raw) == expected, 'Review manifest drift: ' + name)
        values = json.loads(raw)
        require(len(values) == count, 'Review manifest census: ' + name)
        groups[name] = values
        for key, value in values.items():
            locator, digest = (value['locator'], value['sha256']) if isinstance(value, dict) else (key, value)
            data = (root / locator).read_bytes()
            require(sha(data) == digest, 'Exact input drift: ' + locator)
            require(locator not in frozen or frozen[locator] == digest, 'Conflicting input pins')
            frozen[locator] = digest
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    with (HERE / 'census-tests.log').open('w') as stream:
        subprocess.run([sys.executable, '-B', str(evidence / 'test_census.py')],
                       cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
    spec = importlib.util.spec_from_file_location('entry_kernel_independent_review', evidence / 'census.py')
    module = importlib.util.module_from_spec(spec)
    # Execute the exact reviewed producer; its own adapter freezes transitive parsers first.
    producer = (evidence / 'census.py').read_bytes()
    require(sha(producer) == groups['source-sha256.json'][REL + '/census.py'], 'Producer drift')
    exec(compile(producer, str(evidence / 'census.py'), 'exec'), module.__dict__)
    census = module.build()
    encoded = json.dumps(census, indent=2) + '\n'
    require(encoded == (evidence / 'census.json').read_text(), 'Independent census mismatch')
    (HERE / 'census.json').write_text(encoded)
    run = json.loads((evidence / 'candidate-2/invocation.json').read_text())
    totals = {'tests': 0, 'assertions': 0}
    for name, counts in run['strict_suites'].items():
        for key in ('failures', 'unexpected_errors', 'unexpected_warnings', 'expected',
                    'tolerated', 'leaked_objects', 'leaked_resources'):
            require(counts[key] == 0, 'Nonzero author gate: ' + name + ':' + key)
        for key in totals:
            totals[key] += counts[key]
        raw = (evidence / 'candidate-2' / (name + '.log')).read_text()
        require(f"{counts['tests']} test(s), {counts['assertions']} assertion(s), 0 failure(s)" in raw,
                'Missing author summary')
        require('log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).' in raw,
                'Missing author diagnostics')
    require(totals == {'tests': 27, 'assertions': 2134}, 'Unexpected author test totals')
    for key in ('executed_source_unchanged', 'project_restored', 'registry_restored',
                'assets_restored', 'import_sidecars_restored', 'original_sources_restored', 'head_unchanged'):
        require(run[key] is True, 'Author restoration failed: ' + key)
    require(run['exit_code'] == 0 and not run['import_raw_findings'], 'Author failed')
    require('0 GDScript warning(s) in 0 of 5 file(s)' in
            (evidence / 'candidate-2/analyzer.log').read_text(), 'Analyzer evidence missing')
    for locator, digest in frozen.items():
        require(sha((root / locator).read_bytes()) == digest, 'Input changed during review: ' + locator)
    result = {
        'scope': 'Complete diagnostic original-owner retirement only; production Session and new constructor prefixes remain open.',
        'reviewer': '/root', 'manifest_sha256': {name: value[0] for name, value in MANIFESTS.items()},
        'verified_census': {name: len(value) for name, value in groups.items()},
        'source_sha256': groups['source-sha256.json'], 'inputs_unchanged': True,
        'independent_census_tests': 17, 'census_byte_identical': True,
        'author_engine_evidence_verified': totals, 'engine_repeated_by_reviewer': False,
        'accounting': census['accounting'],
        'verdict': 'ACCEPTED diagnostic kernel; no high or medium finding in this scope.',
        'outstanding': ['Actual private Session constructor and all reachable failure prefixes 10–17.',
                        'Recount complete constructor and current peer source closure before integration.',
                        'Mount coherent reviewed source publication, then verify actual demo workflow and native memory.'],
    }
    (HERE / 'review.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
