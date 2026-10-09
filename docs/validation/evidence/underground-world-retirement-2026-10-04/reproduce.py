#!/usr/bin/env python3
"""Isolated official component suites; diagnostic prerequisite copies always restore their original bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
FILES = ['godot/scripts/core/underground_world_retirement.gd', 'godot/scripts/core/buildings.gd',
         'godot/scripts/core/construction.gd', 'godot/scripts/core/work.gd', 'godot/scripts/core/inventory.gd',
         'godot/test/test_underground_world_retirement.gd']
INPUTS = ['godot/data/underground/initial_level_pack.uglvl', 'tools/run_tests.sh',
          'tools/ci_test_shards.py', 'tools/gdscript_warnings.py', 'docs/persistence_state_registry.md']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def snapshot():
    paths = {p for folder in ('scripts', 'demo', 'test', 'data')
             for p in (ROOT / 'godot' / folder).rglob('*.gd') if p.is_file()}
    paths.update(ROOT / name for name in INPUTS)
    paths.update([Path(__file__).resolve(), EVIDENCE / 'registry-test-only-append.md'])
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def raw_findings(text):
    return re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|'
                      r'resources still in use at exit|ObjectDB instances? (?:were |was )?leaked', text, re.M)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--port', type=int, default=6359)
    parser.add_argument('--suites', nargs='+', default=['test_underground_world_retirement.gd'])
    args = parser.parse_args()
    if args.out.is_symlink() or args.out.exists():
        raise ValueError('Evidence output must be new and not a symlink')
    out = args.out.resolve()
    project = ROOT / 'godot/project.godot'
    original_project = project.read_bytes()
    registry = ROOT / 'docs/persistence_state_registry.md'
    original_registry = registry.read_bytes()
    appendix = (EVIDENCE / 'registry-test-only-append.md').read_bytes()
    if b'### `godot/scripts/core/underground_world_retirement.gd`' in original_registry:
        appendix = b''
    if b'config/use_custom_user_dir' in original_project or original_project.count(b'[application]\n') != 1:
        raise ValueError('Refuse incompatible project user-directory configuration')
    prerequisites, replacement, originals = {}, {}, {}
    assets = ROOT / 'godot/demo/assets'
    if assets.is_symlink():
        raise ValueError('Refuse shared/symlink assets before isolation')
    out.mkdir(parents=True, exist_ok=False)
    isolated = 'Redwall-ug1155-' + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    test_project = original_project.replace(b'[application]\n', (
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + isolated + '"\n').encode(), 1)
    original_pins = snapshot()
    write(out / 'original-inputs.json', original_pins)
    write(out / 'diagnostic-prerequisites.json', prerequisites)
    write(out / 'source-sha256.json', {name: sha(ROOT / name) for name in FILES})
    saved = out / 'executed-source'
    saved.mkdir()
    for name in FILES:
        (saved / (Path(name).name + '.txt')).write_bytes((ROOT / name).read_bytes())
    (saved / 'reproduce.py.txt').write_bytes(Path(__file__).read_bytes())
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    record = {'head_before': head, 'commands': [], 'custom_user_dir_name': isolated,
              'project_sha256_before': sha(project), 'assets_present_before': assets.exists(),
              'runtime_qualified': False, 'diagnostic_composition': False}
    sidecars = {p: p.read_bytes() for p in (ROOT / 'godot').rglob('*.import')}
    status, pins = 1, None

    def run(command, log_name):
        started = time.monotonic()
        with (out / log_name).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        record['commands'].append({'command': command, 'exit_code': result.returncode,
                                   'seconds': round(time.monotonic() - started, 3), 'log': log_name})
        print(log_name, result.returncode, flush=True)
        if result.returncode:
            raise RuntimeError(log_name + ' failed')

    with tempfile.TemporaryDirectory(prefix='ug1155-assets-', dir=ROOT) as temporary:
        parked = Path(temporary) / 'assets'
        try:
            project.write_bytes(test_project)
            registry.write_bytes(original_registry + appendix)
            (out / 'registry-test-only-append.md').write_bytes(appendix)
            # Accepted prerequisites are already present; validation above makes no source replacement.
            pins = snapshot()
            write(out / 'inputs-before.json', pins)
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / 'godot/.godot', ignore_errors=True)
            run(['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'clean-import.log')
            record['import_raw_findings'] = raw_findings((out / 'clean-import.log').read_text())
            if record['import_raw_findings']:
                raise RuntimeError('Raw import diagnostics or leaks')
            sys.path.insert(0, str(ROOT / 'tools'))
            import ci_test_shards as shards
            plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT,
                                    weights_path=ROOT / 'tools/ci_test_shard_weights.json')
            record['strict_suites'] = {}
            for suite in args.suites:
                index = next(i for i, group in enumerate(plan['shards']) if group == [suite])
                log_name = suite + '.log'
                run(['./tools/run_tests.sh', '--shard', f"{index}/{plan['shard_count']}",
                     '--output-dir', str(out)], log_name)
                counts, actual, _ = shards.parse_log((out / log_name).read_text())
                if actual != [suite]:
                    raise RuntimeError('Official singleton suite census mismatch')
                record['strict_suites'][suite] = counts
            run(['python3', 'tools/gdscript_warnings.py', '--max', '0', '--port', str(args.port),
                 '--json', str(out / 'analyzer.json'), *FILES], 'analyzer.log')
            status = 0
        except (Exception, KeyboardInterrupt) as error:
            record['error'] = repr(error)
        finally:
            after = snapshot()
            write(out / 'inputs-after.json', after)
            record['executed_source_unchanged'] = pins is not None and pins == after
            # Read-only accepted prerequisite inputs remain checked against their original bytes.
            project.write_bytes(original_project)
            registry.write_bytes(original_registry)
            if parked.exists():
                parked.rename(assets)
            for path in set((ROOT / 'godot').rglob('*.import')) - set(sidecars):
                path.unlink()
            for path, original in sidecars.items():
                path.write_bytes(original)
            restored = snapshot()
            write(out / 'restored-inputs.json', restored)
            record.update(project_restored=project.read_bytes() == original_project,
                          registry_restored=registry.read_bytes() == original_registry,
                          prerequisites_restored=all(p.read_bytes() == value for p, value in originals.items()),
                          assets_restored=assets.exists() == record['assets_present_before'],
                          import_sidecars_restored=all(p.read_bytes() == value for p, value in sidecars.items()),
                          original_sources_restored=restored == original_pins,
                          head_unchanged=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == head)
            if not all(record[key] for key in ('project_restored', 'registry_restored', 'prerequisites_restored', 'assets_restored',
                       'import_sidecars_restored', 'executed_source_unchanged', 'original_sources_restored', 'head_unchanged')):
                status = 1
            record['exit_code'] = status
            write(out / 'invocation.json', record)
    return status


if __name__ == '__main__':
    raise SystemExit(main())
