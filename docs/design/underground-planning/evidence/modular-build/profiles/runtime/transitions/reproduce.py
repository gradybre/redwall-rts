#!/usr/bin/env python3
"""Source-bound native demo transition measurements; all fixtures and samples remain unqualified."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
BASE_PATH = HERE.parent / 'reproduce.py'
SPEC = importlib.util.spec_from_file_location('base_capture_reproduce', BASE_PATH)
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
REPO = BASE.REPO
DRIVER = REPO / 'tools/capture_underground_transitions.gd'
MODES = ('walk_turn', 'carry_turn', 'swing_return', 'tunnel_reversal', 'tunnel_retreat')
EXPECTED_EVENTS = {
    'walk_turn': ['turn_and_walk', 'reverse_order', 'hold_and_fade_idle'],
    'carry_turn': ['turn_and_walk', 'reverse_order', 'hold_and_fade_idle'],
    'swing_return': ['swing', 'return_to_walk', 'hold_and_fade_idle'],
    'tunnel_reversal': ['begin_at_committed_bore_progress', 'turn_back', 'reached_surface_exit'],
    'tunnel_retreat': ['begin_at_committed_bore_progress', 'walk_out', 'reached_surface_exit'],
}


def extra_sources() -> set[str]:
    """Include inherited and transitive source readers, plus all actual data catalog inputs."""
    pending = [str(DRIVER)]
    seen = {str(REPO / 'tools/capture_underground_profiles.gd'), str(Path(__file__).resolve())}
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        pending.extend(re.findall(r'(?:preload|load)\(\s*"(res://[^"]+\.gd)"\s*\)', BASE.actual_path(path).read_text()))
    seen.update('res://' + str(p.relative_to(REPO / 'godot')) for p in (REPO / 'godot/data').rglob('*.json'))
    return seen


def build() -> dict:
    """Reuse actual source imports but select independently named transition and attachment fixtures."""
    spec = BASE.build()
    sources = {entry['path']: entry for entry in spec['sources']}
    sources.update((path, BASE.pin(path)) for path in sorted(extra_sources()))
    spec['sources'] = [sources[path] for path in sorted(sources)]
    manifest = json.loads(BASE.actual_path(spec['manifest']['path']).read_text())
    cases, gaps = [], []
    for cast in BASE.CAST:
        row = manifest['cast'][cast]
        for mode in MODES:
            clip = ('carry_heavy_object_walk' if mode == 'carry_turn' else
                    'heavy_hammer_swing' if mode == 'swing_return' else 'walk')
            if any(c not in row['clips'] for c in ('idle', 'walk', clip)):
                gaps.append({'cast': cast, 'transition': mode, 'status': 'REQUIRED_CLIP_MISSING'})
                continue
            variants = [['log'], ['item_radish']] if mode == 'carry_turn' else [['mole_pick']] if mode == 'swing_return' else [[]]
            for attachments in variants:
                cases.append({'id': f'{cast}.{mode}.{"_".join(attachments) or "body"}', 'cast': cast,
                    'species': row['species'], 'life_stage': 'adult_presentation_candidate', 'clip': clip,
                    'scenario': 'plain', 'transition': mode, 'attachments': attachments})
    spec.update({'cases': cases, 'explicit_transition_gaps': gaps, 'synthetic_routes_and_identity_fixtures': True})
    return spec


def finite(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def ref(value: object) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(type(v) is int for v in value) and value[0] >= 0 and value[1] > 0


def validate_identity(actual: dict, expected: dict, carrying: bool) -> None:
    """Identity evidence is exact, while its mapping to an imported physical variant must stay unbound."""
    if actual.get('error') != '' or not ref(actual.get('resident_ref')) or actual.get('species') != expected['species'] or \
            actual.get('life_stage') != 'ADULT' or not actual.get('logical_rig') or \
            actual.get('physical_variant_binding') != 'UNBOUND' or actual.get('production_qualified') is not False:
        raise ValueError('TRANSITION_RESIDENT_EVIDENCE')
    gear = actual.get('gear', {})
    if not ref(gear.get('lot_ref')) or type(gear.get('item_id')) is not int or type(gear.get('durability')) is not int or \
            gear.get('quantity_milli') != 1000 or gear.get('physical_variant_binding') != 'UNBOUND':
        raise ValueError('TRANSITION_GEAR_EVIDENCE')
    cargo = actual.get('cargo', {})
    if carrying:
        if not ref(cargo.get('lot_ref')) or not ref(cargo.get('satchel_ref')) or type(cargo.get('item_id')) is not int or \
                type(cargo.get('quantity_milli')) is not int or cargo['quantity_milli'] <= 0 or \
                cargo.get('physical_variant_binding') != 'UNBOUND':
            raise ValueError('TRANSITION_CARGO_EVIDENCE')
    elif cargo != {}:
        raise ValueError('TRANSITION_UNREQUESTED_CARGO')


def validate_motion(actual: dict, expected: dict) -> None:
    """Prove exact event/sample coverage; retain observed discontinuities rather than declaring smoothness."""
    count = actual.get('samples')
    if type(count) is not int or not 0 < count <= 1200 or actual.get('expected_sample_count') != count:
        raise ValueError('TRANSITION_SAMPLE_COVERAGE')
    frames = actual.get('motion', [])
    if not isinstance(frames, list) or len(frames) != count or len(actual.get('clip_positions_s', [])) != count:
        raise ValueError('TRANSITION_MOTION_COVERAGE')
    events = actual.get('events', [])
    if [event.get('name') for event in events] != EXPECTED_EVENTS[expected['transition']] or \
            any(type(event.get('step')) is not int or not 0 <= event['step'] < count for event in events) or \
            [event['step'] for event in events] != sorted(set(event['step'] for event in events)):
        raise ValueError('TRANSITION_EVENT_COVERAGE')
    if expected['transition'].startswith('tunnel_'):
        event = events[1]
        if not finite(event.get('progress_before_m')) or event.get('progress_after_m') != event['progress_before_m']:
            raise ValueError('TRANSITION_PROGRESS_RESET')
        if not frames[0].get('underground') or frames[-1].get('underground'):
            raise ValueError('TRANSITION_EXIT_MISSING')
    for n, frame in enumerate(frames):
        if frame.get('step') != n or not isinstance(frame.get('root_m'), list) or len(frame['root_m']) != 3 or \
                not all(finite(v) for v in frame['root_m']) or not all(finite(frame.get(k)) for k in
                    ('yaw_rad', 'pitch_rad', 'clip_position_s', 'clip_rate', 'brain_clip_time_s', 'bore_progress_m', 'stoop_m')):
            raise ValueError('TRANSITION_FRAME_INVALID')
        if frame['identity'] != actual.get('identity_initial'):
            raise ValueError('TRANSITION_IDENTITY_CHANGED')
    validate_animation_timeline(frames, actual['clip_positions_s'], expected)
    validate_identity(actual.get('identity_initial', {}), expected, expected['transition'] == 'carry_turn')
    if actual.get('identity_final') != actual['identity_initial']:
        raise ValueError('TRANSITION_IDENTITY_CHANGED')
    if not any(abs(f['yaw_rad'] - frames[0]['yaw_rad']) > 0 for f in frames[1:]) and expected['transition'] != 'swing_return':
        raise ValueError('TRANSITION_TURN_NOT_OBSERVED')
    if actual.get('bone_pose_max_change_from_first', 0) <= 0:
        raise ValueError('TRANSITION_POSE_NOT_OBSERVED')


def validate_animation_timeline(frames: list[dict], positions: list, expected: dict) -> None:
    """Observe every actual source clip and temporal step, including rate and non-looping endpoints."""
    if not any(frame.get('played_clip') == expected['clip'] for frame in frames) or frames[-1].get('played_clip') != 'idle':
        raise ValueError('TRANSITION_SOURCE_STATE_COVERAGE')
    for n, frame in enumerate(frames):
        name, duration, looping = frame.get('animation_name'), frame.get('animation_length_s'), frame.get('animation_loop_mode')
        if name != 'cast/' + str(frame.get('played_clip')) or not finite(duration) or duration <= 0 or looping not in (0, 1):
            raise ValueError('TRANSITION_SOURCE_TIMELINE')
        same = n > 0 and frames[n-1].get('animation_name') == name
        wanted = (frames[n-1]['clip_position_s'] if same else 0) + (frame['clip_rate'] / 30 if n else 0)
        wanted = wanted % duration if looping == 1 else min(wanted, duration)
        if frame['clip_rate'] < 0 or positions[n] != frame['clip_position_s'] or not math.isclose(
                frame['clip_position_s'], wanted, rel_tol=1e-5, abs_tol=1e-6):
            raise ValueError('TRANSITION_SOURCE_TIMELINE')


def validate_report(spec: dict, report: dict, raw_log: str) -> None:
    """Reject skipped transitions and false qualification even when the engine exits zero."""
    if BASE.DIAGNOSTIC.search(raw_log):
        raise ValueError('TRANSITION_UNEXPECTED_DIAGNOSTICS')
    if report.get('error') != '' or report.get('status') != 'SAMPLED_RUNTIME_ONLY' or report.get('production_qualified') is not False or \
            report.get('qualified_profile_count') != 0 or report.get('continuous_residual_um', 1) is not None or not report.get('missing_bindings'):
        raise ValueError('TRANSITION_REPORT_STATUS')
    if report.get('sources') != spec['sources'] or report.get('manifest') != spec['manifest']:
        raise ValueError('TRANSITION_PROVENANCE')
    rows = report.get('cases', [])
    if not isinstance(rows, list) or len(rows) != len(spec['cases']):
        raise ValueError('TRANSITION_CASE_COVERAGE')
    for expected, actual in zip(spec['cases'], rows):
        if any(actual.get(field) != expected[field] for field in ('id', 'cast', 'species', 'life_stage', 'clip', 'scenario', 'transition')):
            raise ValueError('TRANSITION_CASE_IDENTITY')
        if actual.get('production_qualified') is not False or actual.get('physical_variant_binding') != 'UNBOUND' or \
                actual.get('status') != 'SAMPLED_RUNTIME_ONLY' or not BASE.valid_bounds(actual.get('bounds_m')):
            raise ValueError('TRANSITION_CASE_RESULT')
        validate_motion(actual, expected)
        per_sample = actual.get('expected_palette_checks_per_sample', 0)
        if per_sample <= 0 or actual.get('skin_engine_parity') != 'MEASURED' or \
                actual.get('skin_engine_matrix_checks') != actual['samples'] * per_sample or actual.get('skin_engine_matrix_max_error_m') != 0:
            raise ValueError('TRANSITION_PALETTE_COVERAGE')
        for key in ('attachments', 'attachment_visibility'):
            if [entry.get('key') for entry in actual.get(key, [])] != expected['attachments']:
                raise ValueError('TRANSITION_ATTACHMENT_COVERAGE')
        for item, visible in zip(actual['attachments'], actual['attachment_visibility']):
            if not BASE.valid_bounds(item.get('bounds_m')) or not BASE.valid_bounds(item.get('body_and_attachment_bounds_m')) or \
                    type(visible.get('visible_samples')) is not int or visible['visible_samples'] <= 0 or \
                    type(visible.get('hidden_samples')) is not int or visible['hidden_samples'] < 0 or \
                    visible['visible_samples'] + visible['hidden_samples'] != actual['samples']:
                raise ValueError('TRANSITION_ATTACHMENT_RESULT')


def run(spec: dict, directory: Path) -> dict:
    """Create a fresh bundle, execute only our process, and pin the complete successful observation."""
    directory = directory.resolve()
    BASE.preflight_bundle(directory)
    directory.mkdir(parents=True, exist_ok=True)
    source = directory / 'capture-spec.json'
    with source.open('x') as stream:
        json.dump(spec, stream, indent=2)
        stream.write('\n')
    output, log = directory / 'capture-native.json', directory / 'capture-native.log'
    command = ['godot', '--path', str(REPO / 'godot'), '--rendering-method', 'gl_compatibility',
               '--audio-driver', 'Dummy', '--script', str(DRIVER), '--', str(source), str(output)]
    with log.open('x') as stream:
        done = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    if done.returncode != 0:
        raise ValueError(f'TRANSITION_ENGINE_EXIT:{done.returncode}; see {log}')
    report = json.loads(output.read_text())
    validate_report(spec, report, log.read_text())
    if report.get('spec_sha256') != BASE.pin(str(source))['sha256'] or report.get('rendering_driver') == 'dummy':
        raise ValueError('TRANSITION_NATIVE_PROVENANCE')
    for entry in [spec['manifest'], *spec['sources']]:
        if BASE.pin(entry['path']) != entry:
            raise ValueError('TRANSITION_SOURCE_CHANGED')
    result = {'schema': 1, 'scope': 'sampled actual demo transitions in explicit synthetic fixtures',
              'command': command, 'engine': report['engine'], 'cases': len(report['cases']), 'source_count': len(spec['sources']),
              'sampled_poses': sum(row['samples'] for row in report['cases']),
              'matrix_checks': sum(row['skin_engine_matrix_checks'] for row in report['cases']),
              'unexpected_diagnostics': 0, 'leaked_objects': 0, 'leaked_resources': 0, 'qualified_profile_count': 0,
              'report': BASE.pin(str(output)), 'log': BASE.pin(str(log)), 'spec': BASE.pin(str(source))}
    with (directory / 'verification.json').open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--out-dir', type=Path, default=HERE / 'native')
    parser.add_argument('--case', action='append', help='Exact case id; bounded pilot scope remains explicit')
    args = parser.parse_args()
    BASE.preflight_bundle(args.out_dir)
    spec = build()
    if args.case:
        cases = {row['id']: row for row in spec['cases']}
        if len(set(args.case)) != len(args.case) or any(key not in cases for key in args.case):
            raise ValueError('TRANSITION_CASE_SELECTION')
        spec['cases'] = [cases[key] for key in args.case]
    print(f"transition input: {len(spec['cases'])} cases; {len(spec['sources'])} pins; no production permission", flush=True)
    if args.run:
        result = run(spec, args.out_dir)
        print(f"transition verified: {result['cases']} cases; {result['sampled_poses']} poses; {result['matrix_checks']} native matrix checks; 0 unexpected diagnostics/leaks; 0 qualified", flush=True)
    else:
        BASE.create_spec(spec, args.out_dir)


if __name__ == '__main__':
    main()
