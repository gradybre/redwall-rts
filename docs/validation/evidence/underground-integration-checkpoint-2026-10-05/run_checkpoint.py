#!/usr/bin/env python3
"""Freeze one owned checkout, run the CI clean import/full suite/analyzer, and restore local assets."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def findings(text):
    return re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|'
                      r'resources still in use at exit|ObjectDB instances? (?:were |was )?leaked', text, re.M)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--port', type=int, default=6493)
    args = parser.parse_args()
    if not git('branch', '--show-current').startswith('codex/'):
        raise ValueError('An explicitly owned codex checkout is required')
    if git('diff', '--name-only', '--', 'godot', 'tools') or git('diff', '--cached', '--name-only'):
        raise ValueError('Commit the candidate before qualification')
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    project = ROOT / 'godot/project.godot'
    original = project.read_bytes()
    if b'config/use_custom_user_dir' in original:
        raise ValueError('An existing userdata override must not be replaced')
    user_dir = 'Redwall-ug-checkpoint-' + hashlib.sha256(str(out).encode()).hexdigest()[:12]
    override = original.replace(b'[application]\n', ('[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="' + user_dir + '"\n').encode(), 1)
    assets = ROOT / 'godot/demo/assets'
    if assets.is_symlink():
        raise ValueError('Do not move shared assets')
    paths = [ROOT / p for p in git('ls-files', 'godot', 'tools').splitlines()
             if not p.endswith(('.import', '.uid')) and (ROOT / p).is_file()]
    before = {str(p.relative_to(ROOT)): sha(p) for p in paths}
    write(out / 'source-before.json', before)
    sidecars = {p: p.read_bytes() for ext in ('*.import', '*.uid') for p in (ROOT / 'godot').rglob(ext)
                if '.godot' not in p.parts}
    record = {'head': git('rev-parse', 'HEAD'), 'branch': git('branch', '--show-current'),
              'scope': 'Full no-argument suite and all-file zero-warning analyzer; no hardware qualification',
              'commands': [], 'assets_present_before': assets.exists(), 'user_dir': user_dir}

    def run(command, name, timeout):
        start = time.monotonic()
        with (out / name).open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        record['commands'].append({'command': command, 'log': name, 'exit_code': result.returncode,
                                   'seconds': round(time.monotonic() - start, 3)})
        write(out / 'progress.json', record)
        print(name, result.returncode, flush=True)
        if result.returncode:
            raise RuntimeError(name + ' failed')
        return (out / name).read_text()

    status = 1
    with tempfile.TemporaryDirectory(prefix='ug-checkpoint-assets-', dir=ROOT) as temporary:
        parked = Path(temporary) / 'assets'
        try:
            project.write_bytes(override)
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / 'godot/.godot', ignore_errors=True)
            imported = run(['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'clean-import.log', 1200)
            record['import_findings'] = findings(imported)
            if record['import_findings']:
                raise RuntimeError('Unexpected clean-import findings')
            full = run(['./tools/run_tests.sh'], 'full-suite.log', 10800)
            sys.path.insert(0, str(ROOT / 'tools'))
            import ci_test_shards as shards
            counts, executed, _ = shards.parse_log(full)
            expected = shards.discover(ROOT)
            if Counter(executed) != Counter(expected) or any(n != 1 for n in Counter(executed).values()):
                raise RuntimeError('Full suite did not execute every discovered file exactly once')
            record['counts'] = counts
            record['suite_count'] = len(executed)
            record['summary_lines'] = [line for line in full.splitlines()
                                       if re.match(r'^\d+ test\(s\),|^diagnostics:|^log:', line)]
            print('\n'.join(record['summary_lines']), flush=True)
            analyzer = run(['python3', 'tools/gdscript_warnings.py', '--max', '0', '--port', str(args.port),
                            '--json', str(out / 'analyzer.json')], 'analyzer.log', 3600)
            raw = Path(os.environ.get('TMPDIR', '/tmp')) / f'gdscript_warnings_editor_{args.port}.log'
            shutil.copyfile(raw, out / 'analyzer-editor.log')
            record['analyzer_raw_findings'] = findings(raw.read_text())
            record['analyzer_summary'] = analyzer.strip().splitlines()[-1]
            if record['analyzer_raw_findings']:
                raise RuntimeError('Unexpected analyzer editor findings')
            for command, name in [
                (['python3', 'docs/validation/decision_numbers.py'], 'decision-numbers.log'),
                (['python3', 'tools/underground_memory_budget.py', '--check'], 'memory-check.log'),
                (['python3', 'docs/validation/validate_save_registry_handoff.py', '--source-root', '.'], 'registry-check.log'),
                (['python3', 'docs/validation/state_registry_coverage.py'], 'registry-coverage.log'),
                (['python3', 'tools/underground_build_queue.py', 'validate'], 'queue-check.log'),
            ]:
                run(command, name, 1200)
            status = 0
        except (Exception, KeyboardInterrupt) as error:
            record['error'] = repr(error)
        finally:
            record['override_unchanged'] = project.read_bytes() == override
            project.write_bytes(original)
            if parked.exists():
                parked.rename(assets)
            for ext in ('*.import', '*.uid'):
                for path in set((ROOT / 'godot').rglob(ext)) - set(sidecars):
                    if '.godot' not in path.parts:
                        path.unlink()
            for path, data in sidecars.items():
                path.write_bytes(data)
            after = {str(p.relative_to(ROOT)): sha(p) for p in paths}
            write(out / 'source-after.json', after)
            record.update(project_restored=project.read_bytes() == original,
                          assets_restored=assets.exists() == record['assets_present_before'],
                          sources_unchanged=before == after, head_unchanged=git('rev-parse', 'HEAD') == record['head'],
                          old_sidecars_restored=all(p.read_bytes() == data for p, data in sidecars.items()))
            if not all(record[key] for key in ('override_unchanged', 'project_restored', 'assets_restored',
                                              'sources_unchanged', 'head_unchanged', 'old_sidecars_restored')):
                status = 1
            record['exit_code'] = status
            write(out / 'invocation.json', record)
    return status


if __name__ == '__main__':
    raise SystemExit(main())
