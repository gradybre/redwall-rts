#!/usr/bin/env python3
"""Create-only native actual source2/6 replay; independent integer clock and binary32 matrix oracle."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
PREDECESSOR = HERE.parent / 'work-step-v1/run_canonical.py'
PREDECESSOR_SHA = '9144d16446d4da81ffde9e457da96b3625d6123f39391c7304e5ccc1113d17fa'
if (not PREDECESSOR.is_file() or PREDECESSOR.is_symlink() or PREDECESSOR.stat().st_size > 65536
        or hashlib.sha256(PREDECESSOR.read_bytes()).hexdigest() != PREDECESSOR_SHA):
    raise ValueError('BEARER_NATIVE_PREDECESSOR')
spec = importlib.util.spec_from_file_location('bearer_native_predecessor', PREDECESSOR)
S = importlib.util.module_from_spec(spec)
spec.loader.exec_module(S)
P, ONE = S.P, 65536
PROFILE = HERE / 'diagnostic-profile-1/mole-worker.ugprof'
PROFILE_SHA = '17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9'
GROUND = HERE / 'bearer-routes-input-v1/ground-pace.ugconn'
GROUND_SHA = '877be0982eb6945c4c4f014e9de428b3ab278d1fddc630080e9c6bfe341a1ea8'
H = [60 * 2048 + 512, 512, 50 * 2048 + 512]
M = [H[0], H[1], H[2] + 1536]
R = [H[0], H[1], H[2] + 1024]
SHOTS = (0, 4, 8, 16, 23, 27, 31, 35, 39, 44, 49, 53, 57)


def expected(tick):
    """Use the adopted3277/30 exact movement law and original8-tick fades, never returned state."""
    P.need(type(tick) is int and 0 <= tick <= 57, 'BEARER_NATIVE_TICK')
    if tick == 0:
        return 12, [0, 0, 0, 0], M
    if tick <= 31:
        state, distance = S.travel(tick, 1536)
        return 2, state, [M[0], M[1], M[2] - distance]
    state, distance = S.travel(tick - 31, 1024)
    return 6, state, [H[0], H[1], H[2] + distance]


def frames(profile, state, table):
    """Exact backward phase reversal preserves the original modulus and all stationary READY fade endpoints."""
    phase, q, old, _ = state
    backward = profile == 6
    P.need(phase in (0, 2, 3, 4), 'BEARER_NATIVE_PHASE')
    if phase in (0, 3):
        clip, sample = 0, 8 * ONE
    elif phase == 4:
        clip, sample = 1, 0
    else:
        clip, sample = 1, (2097153 - q) % 2097153 if backward else q
    current = P.clip_frames(table[clip], sample)
    previous, share = current, ONE
    if phase in (3, 4):
        previous = (P.clip_frames(table[1], (2097153 - old) % 2097153 if backward else old)
                    if phase == 3 else P.clip_frames(table[0], 8 * ONE))
        share = q * ONE // 491520
    return current + previous + [share]


def expected_events(table):
    result = []
    for view in ('side', 'rts'):
        for tick in range(58):
            profile, state, point = expected(tick)
            result.append({'view': view, 'tick': tick, 'action': 'initial' if tick == 0 else 'tick',
                           'profile': profile, 'state': state, 'point': point, 'yaw': 0,
                           'frames': frames(profile, state, table), 'ready': state[0] == 0})
    return result


def validate(out):
    config = P.json_read(out / 'spec.json', 65536)
    report = P.json_read(out / 'report.json', 2097152)
    P.need(report['production_qualified'] is False and report['program_version'] == 6
           and report['content_revision'] == 4 and report['content_sha256'] == P.IMAGE_SHA
           and report['failures'] == [] and report['poses'] == 116 and report['matrix_count'] == 26
           and report['resolution'] == [1280, 720] and report['assertions'] >= 116 * 4
           and report['user_directory'].endswith('/' + config['user_directory_name']), 'BEARER_NATIVE_REPORT')
    P.need(config['content_sha256'] == P.IMAGE_SHA and config['content'] == 'res://' + S.IMAGE_RELATIVE
           and config['profiles_sha256'] == PROFILE_SHA and config['ground_sha256'] == GROUND_SHA,
           'BEARER_NATIVE_SOURCE')
    table, matrix, grounding = P.source_arrays(dict(config, content=str(ROOT / 'godot' / S.IMAGE_RELATIVE)))
    events = expected_events(table)
    P.need(report['events'] == events, 'BEARER_NATIVE_CANONICAL_EVENTS')
    raw = P.bounded(out / 'native.bin', 1048576)
    P.need(len(raw) == 8 + 116 * 26 * 12 * 4 and raw[:8] == b'UGSTPN01'
           and hashlib.sha256(raw).hexdigest() == report['native_sha256'], 'BEARER_NATIVE_BYTES')
    native = np.frombuffer(raw, dtype='<f4', offset=8).reshape(116, 26, 12)
    P.need(np.isfinite(native).all(), 'BEARER_NATIVE_FINITE')
    basis = P.bounded(S.BASIS_WITNESS, 1048576)
    P.need(hashlib.sha256(basis).hexdigest() == config['basis_sha256'] == S.BASIS_SHA
           and config['basis'] == 'res://demo/assets/underground-matrices/world-yaw-v1.ugyaw', 'BEARER_NATIVE_BASIS')
    start = len(basis) - 65536 * 8 - 8
    P.need(start > 0, 'BEARER_NATIVE_BASIS_LAYOUT')
    for index, event in enumerate(events):
        pose, floor = P.blend(matrix, event['frames']), P.blend(grounding, event['frames'])
        cs = struct.unpack_from('<ff', basis, start + event['yaw'] * 8)
        wanted = np.empty((26, 12), dtype=np.float32)
        wanted[:24] = pose[:24]
        wanted[24] = P.world_matrix(pose[24], floor, event['point'], cs)
        wanted[25] = P.world_matrix(np.array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype=np.float32), floor, event['point'], cs)
        P.need(np.array_equal(native[index].view(np.uint32), wanted.view(np.uint32)), 'BEARER_NATIVE_MATRIX:' + str(index))
    names = {f'{view}-{"initial" if tick == 0 else "tick"}-{tick:03d}.png' for view in ('side', 'rts') for tick in SHOTS}
    P.need(len(report['screenshots']) == len(names) == 26
           and {row['path'] for row in report['screenshots']} == names, 'BEARER_NATIVE_SCREEN_CENSUS')
    for shot in report['screenshots']:
        raw = P.bounded(out / shot['path'], 4194304)
        P.need(hashlib.sha256(raw).hexdigest() == shot['sha256'] and raw[:8] == b'\x89PNG\r\n\x1a\n'
               and struct.unpack_from('>II', raw, 16) == (1280, 720), 'BEARER_NATIVE_SCREEN')
    return {'poses': 116, 'exact_native_scalars': 116 * 26 * 12, 'screenshots': 26,
            'assertions': report['assertions'], 'production_qualified': False,
            'scope': 'Actual source2/6 canonical native sampling in free fixture geometry; no paid construction or source exception acceptance.'}


def run(out):
    P.need(not out.exists() and not out.is_symlink(), 'BEARER_NATIVE_OUTPUT_EXISTS')
    out = out.resolve()
    script = HERE / 'capture_bearer_routes.gd'
    bake = S.CONTACT / 'high-wall-runtime-sources-v1/bake-spec.json'
    P.need(P.B.digest(bake) == 'f912989add1284bd8653ca7e071d1e5c577738e44f2e559e372fafbdaf420b86', 'BEARER_NATIVE_BAKE')
    pins, historical = P.source_pins(script, bake)
    for path, digest in ((PROFILE, PROFILE_SHA), (GROUND, GROUND_SHA), (PREDECESSOR, PREDECESSOR_SHA)):
        P.need(P.B.digest(path) == digest, 'BEARER_NATIVE_INPUT')
        pins[str(path)] = digest
    for path in [Path(__file__), S.BASIS_WITNESS, HERE / 'endpoint_certificate.gd', *S.DEPENDENCIES]:
        pins[str(path)] = P.B.digest(path)
    override = ROOT / 'godot/override.cfg'
    P.need(not override.exists() and not override.is_symlink(), 'BEARER_NATIVE_OVERRIDE_EXISTS')
    name = 'Redwall-Codex-Bearer-Route-' + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    override_bytes = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n').encode()
    config = P.json_read(HERE.parent / 'evidence/grip-native-v2/spec.json', 65536)
    config.update(content='res://' + S.IMAGE_RELATIVE, content_sha256=P.IMAGE_SHA, reserve_bytes=7141920,
                  profiles='res://' + str(PROFILE.relative_to(ROOT/'godot')), profiles_sha256=PROFILE_SHA,
                  ground='res://' + str(GROUND.relative_to(ROOT/'godot')), ground_sha256=GROUND_SHA,
                  user_directory_name=name, production_qualified=False, diagnostic_profile_flags=True)
    for key in ('content', 'basis', 'manifest'):
        source = P.B.actual(config[key])
        P.need(P.B.digest(source) == config[key + '_sha256'], 'BEARER_NATIVE_SOURCE:' + key)
        pins[str(source)] = config[key + '_sha256']
    out.mkdir(parents=True)
    (out / '.gdignore').touch()
    (out / 'spec.json').write_text(json.dumps(config, indent=2) + '\n')
    (out / 'historical-current-distinction.json').write_text(json.dumps(historical, indent=2) + '\n')
    (out / 'sources-before.json').write_text(json.dumps(pins, indent=2) + '\n')
    commands = [['godot', '--headless', '--path', 'godot', '--editor', '--quit', '--log-file', str(out/'engine-import.log')],
                ['godot', '--path', 'godot', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                 '--fixed-fps', '60', '--log-file', str(out/'engine-native.log'), '--script', str(script), '--', str(out/'spec.json'), str(out)]]
    sidecars = {path: path.read_bytes() for path in (ROOT/'godot').rglob('*.import')}
    results = []
    override.write_bytes(override_bytes)
    try:
        for index, command in enumerate(commands):
            if index == 1:
                restored = P.H.restore_pinned_imports(bake, ROOT/'godot/demo/assets/underground-matrices/mole-grip-v3.inputs', ROOT)
                (out/'import-cache-restoration.json').write_text(json.dumps(restored, indent=2)+'\n')
            log = out / ('import.log' if index == 0 else 'native.log')
            with log.open('x') as stream:
                code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600).returncode
            bad = bool(P.B.DIAGNOSTIC.search(log.read_text()))
            results.append({'command': command, 'exit': code, 'raw_diagnostic': bad})
            P.need(code == 0 and not bad, 'BEARER_NATIVE_ENGINE:' + str(index))
        (out/'verification.json').write_text(json.dumps(validate(out), indent=2)+'\n')
    finally:
        removed = P.restore_sidecars(ROOT/'godot', sidecars)
        (out/'generated-import-sidecars.json').write_text(json.dumps(removed, indent=2)+'\n')
        after = {path: P.B.digest(Path(path)) if Path(path).is_file() else None for path in pins}
        (out/'sources-after.json').write_text(json.dumps(after, indent=2)+'\n')
        same_override = override.is_file() and override.read_bytes() == override_bytes
        if same_override: override.unlink()
        (out/'invocation.json').write_text(json.dumps({'commands': results, 'source_unchanged': pins == after,
            'override_restored': same_override, 'sidecars_restored': True, 'production_qualified': False}, indent=2)+'\n')
        P.need(pins == after and same_override, 'BEARER_NATIVE_SOURCE_DRIFT')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('out', type=Path)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    if args.verify:
        print(json.dumps(validate(args.out), indent=2))
    else:
        run(args.out)
