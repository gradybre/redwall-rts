#!/usr/bin/env python3
"""Read-only replay of the timing refresh against its exact historical suite tree."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

SUBJECT = Path('/Users/brendan/Developer/redwall-rts-codex-ug-integration')
OUT = Path(__file__).resolve().parent
REF = '256c19082a173f1dde8118c6ebf7ad36abd31598'
REPORTS = SUBJECT / 'docs/validation/evidence/underground-host-checkpoint-2026-10-04/ci-256c1908'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_blob(path):
    return subprocess.check_output(['git', 'show', f'{REF}:{path}'], cwd=SUBJECT)


def main():
    controls = ['tools/ci_test_shards.py', 'tools/test_ci_test_shards.py',
                'tools/run_tests.sh', 'godot/test/run_tests.gd']
    controls += [str(p.relative_to(SUBJECT)) for p in sorted((SUBJECT / '.github/workflows').glob('*')) if p.is_file()]
    table = 'tools/ci_test_shard_weights.json'
    pins = {p: digest(SUBJECT / p) for p in [table, *controls]}
    unchanged = {p: (SUBJECT / p).read_bytes() == git_blob(p) for p in controls}
    assert all(unchanged.values()), unchanged
    run = json.loads((REPORTS / 'run.json').read_text())
    assert run['headSha'] == REF and run['conclusion'] == 'success'
    assert all(job['conclusion'] == 'success' for job in run['jobs'])
    current = json.loads((SUBJECT / table).read_text())
    old = json.loads(git_blob(table))
    assert {k: v for k, v in current.items() if k != 'suite_usec'} == {k: v for k, v in old.items() if k != 'suite_usec'}
    archive = subprocess.check_output(['git', 'archive', '--format=tar', REF,
                                       'godot/test', 'tools/ci_test_shards.py'], cwd=SUBJECT)
    with tempfile.TemporaryDirectory(prefix='ci-weight-review-', dir=OUT.parent) as name:
        snapshot = Path(name)
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
            for entry in tar.getmembers():
                path = Path(entry.name)
                direct_suite = path.parent.as_posix() == 'godot/test' and path.name.startswith('test_') and path.suffix == '.gd'
                if entry.isfile() and (direct_suite or entry.name == 'tools/ci_test_shards.py'):
                    target = snapshot / path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(tar.extractfile(entry).read())
        helper = snapshot / 'tools/ci_test_shards.py'
        assert digest(helper) == pins['tools/ci_test_shards.py']
        command = [sys.executable, '-B', str(helper), 'weights', '--reports', str(REPORTS),
                   '--count', '8', '--output', str(OUT / 'reproduced-weights.json')]
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        (OUT / 'weights-replay.log').write_text(result.stdout + result.stderr)
        assert result.returncode == 0, result.stderr
        assert (OUT / 'reproduced-weights.json').read_bytes() == (SUBJECT / table).read_bytes()
        spec = importlib.util.spec_from_file_location('reviewed_shards', helper)
        shards = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(shards)
        aggregate = shards.aggregate(REPORTS, 8, repo=snapshot)
        plan = shards.make_plan(8, repo=snapshot, weights_path=OUT / 'reproduced-weights.json')
        assert aggregate['suite_count'] == len(current['suite_usec']) == 397
        assert set(plan['suites']) == set(current['suite_usec'])
        old_plan = json.loads((REPORTS / 'manifest-0.json').read_text())
        old_actual = [sum(aggregate['suite_usec'][suite] for suite in group) for group in old_plan['shards']]
        future = snapshot / 'godot/test/test_review_future_direct_suite.gd'
        future.write_text('extends RefCounted\n')
        future_plan = shards.make_plan(8, repo=snapshot, weights_path=OUT / 'reproduced-weights.json')
        assert future.name in future_plan['suites'] and len(future_plan['suites']) == 398
        future.unlink()
        current_corpus = set(shards.discover(SUBJECT))
        historical_corpus = set(shards.discover(snapshot))
    assert pins == {p: digest(SUBJECT / p) for p in pins}
    report = {
        'verdict': 'accepted; no high/medium correctness finding',
        'scope': 'Timing data only. No engine rerun or foreign source/cache/project edits.',
        'source_commit': REF, 'source_ci_run': 37226172376,
        'source_pins': pins, 'unchanged_from_measured_commit': unchanged,
        'generated_table_byte_identical': True,
        'table_non_timing_fields_unchanged': True,
        'prior_measured_suites': len(old['suite_usec']), 'measured_suites': aggregate['suite_count'],
        'old_assignment_actual_suite_usec': old_actual,
        'new_assignment_estimated_usec': plan['estimated_usec'],
        'aggregated_original_counts': aggregate['counts'],
        'new_unweighted_suite_discovered_exactly_once': True,
        'current_vs_measured_corpus': {'added': sorted(current_corpus-historical_corpus),
                                      'removed': sorted(historical_corpus-current_corpus)},
        'initial_current_tree_replay': 'Correctly refused: manifest corpus differs from discovered test files. Exact original256c1908 corpus then reproduced using unchanged helper in own temporary snapshot.',
        'limits': 'Balanced durations are estimates from the same recorded suite times, not a measured rerun or a change to exact-once discovery, diagnostic thresholds, count checks or CI gates.',
        'source_unchanged': True,
    }
    (OUT / 'review.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
