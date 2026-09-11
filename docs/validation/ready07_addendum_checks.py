#!/usr/bin/env python3
"""Pinned naming/viewport arithmetic; --godot also checks copied production hash kernel.
No save codec, naming lifecycle or real-window acceptance is claimed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
VECTORS = [
    (1, 1, 1119302415, 15, 24, 'Ivy Pinehollow'),
    (1, 20260905, 1139595788, 12, 16, 'Hazel Hazelbridge'),
    (2, 20260905, 1144555583, 31, 1, 'Willow Ashbrook'),
    (12, 20260905, 1134568473, 25, 0, 'Pine Applebank'),
    (2147483647, 2147483647, 905157919, 31, 8, 'Willow Cedarvale'),
    (16777217, 20260905, 1357695244, 12, 8, 'Hazel Cedarvale'),
    (65536, 20260905, 3724026389, 21, 16, 'Moss Hazelbridge'),
]
LAYOUTS = [(1280, 720, 1.0, 1280, 'STANDARD'),
           (1280, 720, 1.25, 1024, 'NARROW'),
           (1280, 720, 1.5, 1280 / 1.5, 'NARROW'),
           (1920, 1080, 1.0, 1920, 'WIDE'),
           (1920, 1080, 1.5, 1280, 'STANDARD'),
           (3840, 2160, 1.0, 1920, 'WIDE')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', action='store_true')
    args = parser.parse_args()
    gdd = (ROOT / 'docs/game_gdd.md').read_text()
    given = re.search(r'Given names: (.*?)\. Surnames:', gdd).group(1).split(', ')
    surnames = re.search(r'Surnames: (.*?)\. Given index=', gdd).group(1).split(', ')
    assert len(given) == len(surnames) == 32
    for pid, seed, expected, gi, si, name in VECTORS:
        h = (pid ^ 0x9e3779b9) & 0xffffffff
        h = (h * 1664525 + 1013904223 + (seed & 0xffffffff)) & 0xffffffff
        h = (h ^ (h >> 16)) & 0xffffffff
        assert (h, h % 32, (h // 32) % 32) == (expected, gi, si)
        assert given[gi] + ' ' + surnames[si] == name
    for width, height, user, expected, profile in LAYOUTS:
        scale = max(1.0, min(2.0, min(width / 1920, height / 1080))) * user
        logical = width / scale
        actual = 'WIDE' if logical >= 1600 else 'STANDARD' if logical >= 1120 else 'NARROW'
        assert abs(logical - expected) < 1e-9 and actual == profile
    result = {'status': 'PASS', 'name_vectors': len(VECTORS), 'layout_fixtures': len(LAYOUTS),
              'save_parity': 'NOT_RUN', 'real_window_visual_check': 'NOT_RUN',
              'production_hash_kernel': 'NOT_RUN'}
    if args.godot:
        binary = shutil.which('godot')
        assert binary, 'Godot is required with --godot'
        with tempfile.TemporaryDirectory(prefix='redwall-name-hash-') as temp:
            project = Path(temp)
            core = project / 'scripts/core'
            core.mkdir(parents=True)
            hashes = {}
            for filename in ('rng.gd', 'int_math.gd'):
                source = ROOT / 'godot/scripts/core' / filename
                shutil.copyfile(source, core / filename)
                hashes[filename] = hashlib.sha256(source.read_bytes()).hexdigest()
            (project / 'project.godot').write_text('config_version=5\n')
            lines = ['extends SceneTree',
                     'const Rng = preload("res://scripts/core/rng.gd")',
                     'func _initialize() -> void:']
            for pid, seed, expected, _, _, _ in VECTORS:
                lines.extend([f'\tif Rng.hash_pair({pid}, {seed}) != {expected}:',
                              '\t\tpush_error("NAME_HASH_VECTOR_MISMATCH")',
                              '\t\tquit(1)', '\t\treturn'])
            lines.extend(['\tprint("NAME_HASH_KERNEL_PASS: 7 vectors")', '\tquit(0)'])
            (project / 'probe.gd').write_text('\n'.join(lines) + '\n')
            version = subprocess.check_output([binary, '--version'], text=True).strip()
            run = subprocess.run([binary, '--headless', '--path', temp, '--log-file',
                                  str(project / 'probe.log'), '--script', 'probe.gd'],
                                 text=True, capture_output=True, timeout=60)
            output = run.stdout + run.stderr
            assert run.returncode == 0 and 'NAME_HASH_KERNEL_PASS: 7 vectors' in output, output
            result.update(production_hash_kernel='PASS: isolated copies of production sources',
                          engine_version=version, kernel_source_sha256=hashes, kernel_output=output.strip())
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
