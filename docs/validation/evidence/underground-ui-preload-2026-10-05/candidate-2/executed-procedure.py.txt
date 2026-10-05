#!/usr/bin/env python3
"""Fresh clean-import and analyzer-only retry; preserve the original full run and its failed raw editor gate."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output/'executed-procedure.py.txt').write_bytes(Path(__file__).read_bytes())
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    assert head == args.expected_commit, 'source checkout must be the exact requested commit'
    names = subprocess.check_output(['git', 'ls-files', '-z', 'godot', 'tools',
        'docs/persistence_state_registry.md', 'docs/planning', '.github/workflows/tests.yml'], cwd=ROOT).decode().split('\0')
    names = [name for name in names if name and name != 'godot/project.godot']
    digest = lambda: {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in names}
    pins = digest()
    (output/'source-sha256.json').write_text(json.dumps(pins, indent=2)+'\n')
    record = {'head': head, 'worktree': str(ROOT), 'commands': [], 'source_unchanged': False,
              'procedure_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'custom_user_dir': 'Redwall-ug-route-integration-lsp-order-20261005', 'analyzer_port': 6465}
    sidecars = {p: p.read_bytes() for ext in ('*.uid', '*.import') for p in (ROOT/'godot').rglob(ext) if '.godot' not in p.parts}
    project = ROOT/'godot/project.godot'
    original = project.read_bytes()
    assert b'config/use_custom_user_dir' not in original
    isolated = original.replace(b'[application]\n', b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-route-integration-lsp-order-20261005"\n', 1)
    record['project_sha256_before'] = hashlib.sha256(original).hexdigest()
    record['isolated_project_sha256'] = hashlib.sha256(isolated).hexdigest()
    assets = ROOT/'godot/demo/assets'
    record['assets_present_before'] = assets.exists()
    status = 0
    def run(command, name):
        start = time.monotonic()
        print('starting', name, flush=True)
        with (output/name).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record['commands'].append({'command':command,'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3),'log':name})
        print(name, 'exit', result.returncode, flush=True)
        raw = (output/name).read_text()
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
            run(['python3','-B',str(Path(__file__).with_name('probe_lsp_order.py')),'--port','6465','--out',str(output/'probe')], 'analyzer.log')
            editor = Path(os.environ.get('TMPDIR', '/tmp'))/'gdscript_warnings_editor_6465.log'
            if editor.exists():
                shutil.copyfile(editor, output/'analyzer-editor.log')
                if re.search(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|resources still in use|ObjectDB instances? (?:were|was) leaked', editor.read_text(), re.M):
                    raise RuntimeError('raw analyzer editor diagnostics')
        except (Exception, KeyboardInterrupt) as error:
            status = 1
            record['error'] = str(error)
        finally:
            record['source_unchanged_before_cleanup'] = digest() == pins
            project.write_bytes(original)
            if parked.exists(): parked.rename(assets)
            for ext in ('*.uid', '*.import'):
                for path in {p for p in (ROOT/'godot').rglob(ext) if '.godot' not in p.parts} - set(sidecars):
                    path.unlink()
            for path, raw in sidecars.items():
                if not path.is_file() or path.read_bytes() != raw:
                    path.write_bytes(raw)
            record['sidecars_restored'] = all(p.is_file() and p.read_bytes() == raw for p, raw in sidecars.items())
            record['assets_restored'] = assets.exists() == record['assets_present_before']
            record['project_restored'] = project.read_bytes() == original
            record['source_unchanged'] = digest() == pins
            record['head_unchanged'] = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() == head
            if not all(record[key] for key in ('assets_restored','project_restored','source_unchanged_before_cleanup','source_unchanged','head_unchanged','sidecars_restored')): status = 1
            record['exit_code'] = status
            (output/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
    return status

if __name__ == '__main__':
    raise SystemExit(main())
