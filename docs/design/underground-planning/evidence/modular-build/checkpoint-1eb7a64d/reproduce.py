#!/usr/bin/env python3
"""Clean no-argument qualification of one immutable integration commit in an own worktree."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent

def main():
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    assert head.startswith('1eb7a64d')
    names = subprocess.check_output(['git', 'ls-files', '-z', 'godot', 'tools',
        'docs/persistence_state_registry.md', 'docs/planning'], cwd=ROOT).decode().split('\0')
    names = [name for name in names if name and name != 'godot/project.godot']
    digest = lambda: {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in names}
    pins = digest()
    (OUT/'source-sha256.json').write_text(json.dumps(pins, indent=2)+'\n')
    record = {'head': head, 'worktree': str(ROOT), 'commands': [], 'source_unchanged': False}
    project = ROOT/'godot/project.godot'
    original = project.read_bytes()
    assert b'config/use_custom_user_dir' not in original
    isolated = original.replace(b'[application]\n', b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-checkpoint-1eb7a64d"\n', 1)
    record['project_sha256_before'] = hashlib.sha256(original).hexdigest()
    record['isolated_project_sha256'] = hashlib.sha256(isolated).hexdigest()
    assets = ROOT/'godot/demo/assets'
    record['assets_present_before'] = assets.exists()
    status = 0
    def run(command, name):
        start = time.monotonic()
        print('starting', name, flush=True)
        with (OUT/name).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record['commands'].append({'command':command,'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3),'log':name})
        print(name, 'exit', result.returncode, flush=True)
        raw = (OUT/name).read_text()
        for line in raw.splitlines():
            if line.startswith(('diagnostics:', 'log:', 'ok:', 'error:')) or ' test(s),' in line or 'GDScript warning(s)' in line:
                print(line, flush=True)
        if result.returncode:
            raise RuntimeError(name)
        return raw
    with tempfile.TemporaryDirectory(prefix='ug-checkpoint-assets-', dir=ROOT.parent) as temporary:
        parked = Path(temporary)/'assets'
        try:
            project.write_bytes(isolated)
            if assets.exists(): assets.rename(parked)
            shutil.rmtree(ROOT/'godot/.godot', ignore_errors=True)
            raw = run(['godot','--headless','--path','godot','--editor','--quit'], 'clean-import.log')
            if re.search(r'(?:ERROR:|WARNING:|Parse Error:|Parser Error:|leaked at exit|resources still in use)', raw):
                raise RuntimeError('raw import diagnostics')
            run(['./tools/run_tests.sh'], 'full-suite.log')
            run(['python3','tools/gdscript_warnings.py','--max','0','--port','6199','--json',str(OUT/'analyzer.json')], 'analyzer.log')
        except Exception as error:
            status = 1
            record['error'] = str(error)
        finally:
            project.write_bytes(original)
            if parked.exists(): parked.rename(assets)
            record['assets_restored'] = assets.exists() == record['assets_present_before']
            record['project_restored'] = project.read_bytes() == original
            record['source_unchanged'] = digest() == pins
            record['head_unchanged'] = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() == head
            if not all(record[key] for key in ('assets_restored','project_restored','source_unchanged','head_unchanged')): status = 1
            record['exit_code'] = status
            (OUT/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
    return status

if __name__ == '__main__':
    raise SystemExit(main())
