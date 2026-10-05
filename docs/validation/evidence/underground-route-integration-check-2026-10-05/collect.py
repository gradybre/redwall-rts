#!/usr/bin/env python3
"""Collect an already finished exact-head run without rerunning any test gate."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[3]
RUN = EVIDENCE / 'full-ca1edc3f'
CHECKPOINT = 'ca1edc3f62b09300f0e36ff0dfbcb1172a5f90ac'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    invocation = json.loads((RUN / 'invocation.json').read_text())
    assert invocation['head'] == CHECKPOINT
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == CHECKPOINT
    pins = json.loads((RUN / 'source-sha256.json').read_text())
    mismatches = [name for name, digest in pins.items()
                  if not (ROOT / name).is_file() or sha(ROOT / name) != digest]
    log = (RUN / 'full-suite.log').read_text()
    summaries = re.findall(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$', log, re.M)
    diagnostics = re.findall(
        r'^diagnostics: (\d+) unexpected error\(s\), (\d+) unexpected warning\(s\), '
        r'(\d+) expected, (\d+) tolerated; leaked at exit: (\d+) object\(s\), (\d+) resource\(s\)$',
        log, re.M)
    assert len(summaries) == 1 and len(diagnostics) == 1
    tests, assertions, failures = map(int, summaries[0])
    diagnostic_names = ('unexpected_errors', 'unexpected_warnings', 'expected',
                        'tolerated', 'leaked_objects', 'leaked_resources')
    raw = {
        'unexpected_errors': len(re.findall(r'^(?:USER )?ERROR:', log, re.M)),
        'unexpected_warnings': len(re.findall(r'^(?:USER )?WARNING:', log, re.M)),
        'leaked_objects': sum(map(int, re.findall(r'(\d+) ObjectDB instances? (?:were|was) leaked', log))),
        'leaked_resources': sum(map(int, re.findall(r'(\d+) resources still in use at exit', log))),
    }
    restoration_names = ('source_unchanged_before_cleanup', 'source_unchanged',
                         'assets_restored', 'project_restored', 'sidecars_restored', 'head_unchanged')
    analyzer_command = next((c for c in invocation['commands'] if c['log'] == 'analyzer.log'), None)
    analyzer = {'executed': analyzer_command is not None}
    if analyzer_command is not None:
        analyzer['exit_code'] = analyzer_command['exit_code']
        text = (RUN / 'analyzer.log').read_text()
        result = re.findall(r'(\d+) GDScript warning\(s\) in (\d+) of (\d+) file\(s\)', text)
        assert len(result) == 1
        analyzer.update(zip(('warnings', 'files_with_warnings', 'files_checked'), map(int, result[0])))
        analyzer['json'] = json.loads((RUN / 'analyzer.json').read_text())
    record = {
        'schema': 1,
        'checkpoint': CHECKPOINT,
        'run_exit_code': invocation['exit_code'],
        'tests': tests, 'assertions': assertions, 'failures': failures,
        'suites': len(re.findall(r'^test_[^\n]+\.gd$', log, re.M)),
        'strict_diagnostics': dict(zip(diagnostic_names, map(int, diagnostics[0]))),
        'raw_diagnostics': raw,
        'analyzer': analyzer,
        'restoration': {name: invocation[name] for name in restoration_names},
        'tracked_source_pins': len(pins),
        'independent_post_run_source_mismatches': mismatches,
        'artifact_pins': {name: sha(RUN / name) for name in (
            'invocation.json', 'source-sha256.json', 'executed-procedure.py.txt',
            'clean-import.log', 'full-suite.log', 'analyzer.log', 'analyzer.json',
            'analyzer-editor.log') if (RUN / name).is_file()},
        'native_memory_qualified': False,
        'gameplay_or_visual_qualified': False,
    }
    record['exact_ci_run_passed'] = (
        invocation['exit_code'] == 0 and tests > 0 and failures == 0
        and all(c['exit_code'] == 0 for c in invocation['commands'])
        and all(invocation[name] for name in restoration_names)
        and not mismatches and not any(raw.values())
        and analyzer.get('exit_code') == 0 and analyzer.get('warnings') == 0
        and analyzer.get('json') == {})
    (RUN / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
