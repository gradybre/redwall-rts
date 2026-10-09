#!/usr/bin/env python3
"""Actual demo input and native720p capture with isolated userdata and exact source restoration."""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
IMAGES = ['planning-open.png', 'planning-drawing.png', 'planning-other-floor.png', 'planning-refused.png', 'planning-stalled.png']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    project = ROOT / 'godot/project.godot'
    original = project.read_bytes()
    assert b'config/use_custom_user_dir' not in original
    user_dir = 'Redwall-ug1179-native-' + hashlib.sha256(str(out).encode()).hexdigest()[:12]
    candidate = original.replace(b'[application]\n', ('[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="' + user_dir + '"\n').encode(), 1)
    paths = [p for p in (ROOT / 'godot').rglob('*.gd') if '.godot' not in p.parts]
    paths += list((ROOT / 'godot/demo').rglob('*.gdshader'))
    paths += [Path(__file__).resolve(), ROOT / 'godot/demo/burrow/modular_demo_live.tscn']
    before = {str(p.relative_to(ROOT)): sha(p) for p in paths}
    write(out / 'source-before.json', before)
    record = {'commands': [], 'user_dir': user_dir, 'playable_room_complete': False}
    status = 1
    try:
        project.write_bytes(candidate)
        commands = [(['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'staged-import.log'),
                    (['godot', '--path', 'godot', '--windowed', '--resolution', '1280x720', '--position', '80,80',
                      '--quit-after', '900', 'res://demo/burrow/modular_demo_live.tscn', '--', str(out)], 'native.log')]
        for command, log_name in commands:
            start = time.monotonic()
            with (out / log_name).open('w') as stream:
                run = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
            text = (out / log_name).read_text()
            findings = re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|'
                r'resources still in use at exit|ObjectDB instances? (?:were |was )?leaked', text, re.M)
            record['commands'].append({'command': command, 'exit_code': run.returncode, 'raw_findings': findings,
                                       'seconds': round(time.monotonic() - start, 3)})
            print(log_name, run.returncode, 'findings', len(findings), flush=True)
            assert run.returncode == 0 and not findings, log_name
        report = json.loads((out / 'report.json').read_text())
        assert report['checks'] == 74 and report['failures'] == []
        assert report['driver'] == 'metal' and report['backend'] == 'forward_plus'
        assert report['playable_room_complete'] is False
        assert sorted(p.name for p in out.glob('*.png')) == sorted(IMAGES)
        pins = {}
        for name in IMAGES:
            data = (out / name).read_bytes()
            assert data[:8] == b'\x89PNG\r\n\x1a\n'
            assert (int.from_bytes(data[16:20], 'big'), int.from_bytes(data[20:24], 'big')) == (1280, 720)
            pins[name] = hashlib.sha256(data).hexdigest()
        write(out / 'image-sha256.json', pins)
        status = 0
    except (Exception, KeyboardInterrupt) as error:
        record['error'] = repr(error)
    finally:
        record['override_unchanged'] = project.read_bytes() == candidate
        project.write_bytes(original)
        after = {str(p.relative_to(ROOT)): sha(p) for p in paths}
        write(out / 'source-after.json', after)
        record.update(project_restored=project.read_bytes() == original, source_unchanged=before == after)
        if not all(record[k] for k in ('override_unchanged', 'project_restored', 'source_unchanged')):
            status = 1
        record['exit_code'] = status
        write(out / 'invocation.json', record)
    return status


if __name__ == '__main__':
    raise SystemExit(main())
