#!/usr/bin/env python3
"""Verify the actual CLI and raw-log guard on an isolated asset-free own checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    assert not (ROOT / 'godot/demo/assets').exists(), 'use the isolated asset-free own checkout'
    paths = [p for p in (ROOT / 'godot').rglob('*.gd') if '.godot' not in p.parts]
    paths += [ROOT / 'godot/project.godot', ROOT / 'tools/gdscript_warnings.py',
              ROOT / 'tools/test_gdscript_warnings.py', Path(__file__).resolve()]
    def pins():
        return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before = pins()
    (out / 'source-before.json').write_text(json.dumps(before, indent=2) + '\n')
    for path in paths[-3:]:
        (out / (path.name + '.txt')).write_bytes(path.read_bytes())
    results = []
    status = 0
    shutil.rmtree(ROOT / 'godot/.godot', ignore_errors=True)
    commands = [(['python3', '-B', 'tools/test_gdscript_warnings.py'], 'protocol-tests.log'),
                (['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'clean-import.log'),
                (['python3', '-B', 'tools/gdscript_warnings.py', '--max', '0', '--port', '6470',
                  '--json', str(out / 'analyzer.json')], 'analyzer.log')]
    for command, name in commands:
        started = time.monotonic()
        with (out / name).open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
        results.append({'command': command, 'exit_code': result.returncode,
                        'seconds': round(time.monotonic() - started, 3)})
        print(name, result.returncode, flush=True)
        if result.returncode:
            status = 1
            break
    raw_path = Path(os.environ.get('TMPDIR', '/tmp')) / 'gdscript_warnings_editor_6470.log'
    if raw_path.exists():
        shutil.copyfile(raw_path, out / 'analyzer-editor.log')
    for name in ('clean-import.log', 'analyzer-editor.log'):
        text = (out / name).read_text() if (out / name).exists() else 'ERROR: missing log'
        if re.search(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|[1-9][0-9]* resources? still in use at exit|[1-9][0-9]* ObjectDB instances? (?:were|was) leaked', text, re.M):
            status = 1
    after = pins()
    (out / 'source-after.json').write_text(json.dumps(after, indent=2) + '\n')
    if before != after:
        status = 1
    record = {'commands': results, 'sources_unchanged': before == after, 'exit_code': status,
              'scope': 'actual analyzer CLI, clean import and protocol regression; no full-suite claim'}
    (out / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
    print(record, flush=True)
    return status


if __name__ == '__main__':
    raise SystemExit(main())
