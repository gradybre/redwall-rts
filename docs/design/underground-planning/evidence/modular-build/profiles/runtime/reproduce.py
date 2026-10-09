#!/usr/bin/env python3
"""Build an exact source-pinned input for the offline capture; never edit the library or the demo.

Run after the existing cast and selected-prop staging/import commands in README.md.
The fixed set is adult presentation evidence only, not a movement permission catalog.
"""
from __future__ import annotations

import hashlib
import argparse
import json
import math
from pathlib import Path
import re
import subprocess

REPO = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
LIBRARY = Path('/Users/brendan/Developer/redwall-rts/assets/library')
CAST = ('mouse_keeper', 'mole_digger', 'squirrel_gatherer', 'otter_boatwright', 'badger_quarryman')
CLIPS = ('idle', 'walk', 'cautious_crouch_walk_forward', 'carry_heavy_object_walk', 'heavy_hammer_swing')
PROPS = ('mole_pick', 'item_radish', 'item_turnip', 'item_carrot', 'item_beetroot', 'item_onion',
         'item_leek', 'item_lettuce', 'item_celery', 'item_peas', 'item_barley', 'item_oats')
TOOLS = ('capture_underground_profiles.gd', 'stage_demo_assets.py', 'make_demo_props.py',
         'demo_props_blender.py', 'ground_meshy_clips.py', 'repair_meshy_rig.py', 'demo_texture_imports.py')
DIAGNOSTIC = re.compile(r'^(?:(?:USER )?SCRIPT ERROR|(?:USER )?ERROR|(?:USER )?WARNING):|'
                        r'ObjectDB instances? (?:were|was) leaked|resources still in use|RID allocations.*leaked', re.M)
BUNDLE_NAMES = ('capture-spec.json', 'capture-native.json', 'capture-native.log', 'verification.json')


def actual_path(path: str) -> Path:
    """Resolve only the known project resource prefix; source paths remain explicit."""
    return REPO / 'godot' / path[6:] if path.startswith('res://') else Path(path)


def pin(path: str) -> dict:
    """No missing, oversized or empty source can become a successful staging record."""
    source = actual_path(path)
    if not source.is_file() or not 0 < source.stat().st_size <= 134217728:
        raise ValueError(f'missing/oversized source: {source}')
    return {'path': path, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}


def implementation_sources() -> set[str]:
    """Pin literal script-load dependencies and actual project autoloads transitively."""
    capture = (REPO / 'tools/capture_underground_profiles.gd').read_text()
    block = re.search(r'const REQUIRED_SOURCE_PATHS:.*?\[(.*?)\]', capture, re.S).group(1)
    sources = set(re.findall(r'"([^"]+)"', block))
    project = actual_path('res://project.godot').read_text()
    autoload = project.split('[autoload]', 1)[1].split('[', 1)[0]
    sources.update(re.findall(r'"\*(res://[^"]+\.gd)"', autoload))
    pending = [path for path in sources if path.endswith('.gd')]
    seen = set()
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        for dependency in re.findall(r'(?:preload|load)\(\s*"(res://[^"]+\.gd)"\s*\)', actual_path(path).read_text()):
            sources.add(dependency)
            if dependency not in seen:
                pending.append(dependency)
    return sources


def imported_sources(path: str) -> set[str]:
    """Bind the generated scene bytes the ResourceLoader actually consumes as well as its settings."""
    metadata = path + '.import'
    text = actual_path(metadata).read_text()
    matched = re.search(r'^dest_files=\[(.*?)\]', text, re.M)
    if not matched:
        raise ValueError(f'missing import destinations: {metadata}')
    destinations = set(re.findall(r'"(res://[^"]+)"', matched.group(1)))
    if not destinations:
        raise ValueError(f'empty import destinations: {metadata}')
    return {path, metadata, *destinations}


def build() -> dict:
    """Record every imported clip the actor loads, including nonselected libraries and import settings."""
    manifest_path = 'res://demo/assets/manifest.json'
    manifest = json.loads(actual_path(manifest_path).read_text())
    sources = implementation_sources()
    sources.update(str(REPO / 'tools' / name) for name in TOOLS)
    sources.add(str(Path(__file__).resolve()))
    cases, gaps, staged = [], [], []
    for key in CAST:
        row = manifest['cast'][key]
        paths = [row['body'], *row['clips'].values()]
        for path in paths:
            sources.update(imported_sources(path))
        for path in paths:
            name = Path(path).stem
            raw = LIBRARY / 'creature' / key / 'grounded' / ('rigged.glb' if name == 'body' else f'anim_{name}.glb')
            sources.add(str(raw))
            staged.append({'cast': key, 'staged': pin(path), 'original': pin(str(raw))})
        for clip in CLIPS:
            if clip not in row['clips']:
                gaps.append({'cast': key, 'clip': clip, 'status': 'SOURCE_MISSING'})
                continue
            scenarios = ['plain']
            if clip == 'walk':
                scenarios += ['ramp_up', 'ramp_down', 'turn']
            if clip == 'cautious_crouch_walk_forward':
                scenarios += ['standard_bore']
            attachments = ['mole_pick'] if clip == 'heavy_hammer_swing' else []
            if clip == 'carry_heavy_object_walk':
                attachments = ['log', *PROPS[1:]]
                scenarios += ['standard_bore']
            for scenario in scenarios:
                cases.append({'id': f'{key}.{clip}.{scenario}', 'cast': key, 'species': row['species'],
                              'life_stage': 'adult_presentation_candidate', 'clip': clip,
                              'scenario': scenario, 'attachments': attachments})
    for key in PROPS:
        row = manifest['world'][key]
        sources.update(imported_sources(row['path']))
        sources.update([str(REPO / 'godot/demo/assets/props' / f'{key}.made.json'),
                        str(LIBRARY / row['source'])])
        if pin(str(LIBRARY / row['source']))['sha256'] != row['source_sha256']:
            raise ValueError(f'{key}: staging source hash no longer matches the actual library')
    return {'schema': 1, 'manifest': pin(manifest_path), 'sources': [pin(p) for p in sorted(sources)],
            'cases': cases, 'explicit_source_gaps': gaps, 'staged_from': staged,
            'qualified_profile_count': 0, 'production_qualified': False}


def valid_bounds(value: object) -> bool:
    """Require finite ordered sampled bounds, without turning their precision into a safety margin."""
    return isinstance(value, list) and len(value) == 6 and all(
        isinstance(v, (float, int)) and not isinstance(v, bool) and math.isfinite(v) for v in value
    ) and all(value[i] <= value[i + 3] for i in range(3))


def validate_report(spec: dict, report: dict, raw_log: str) -> None:
    """Exit 0 is insufficient: every requested identity/attachment and actual engine observation must exist."""
    if DIAGNOSTIC.search(raw_log):
        raise ValueError('CAPTURE_UNEXPECTED_DIAGNOSTICS')
    if report.get('error') != '' or report.get('status') != 'SAMPLED_RUNTIME_ONLY' or \
            report.get('production_qualified') is not False or report.get('qualified_profile_count') != 0:
        raise ValueError('CAPTURE_REPORT_STATUS')
    if report.get('continuous_residual_um', 'absent') is not None or not report.get('missing_bindings'):
        raise ValueError('CAPTURE_UNSUPPORTED_QUALIFICATION')
    if report.get('sources') != spec['sources'] or report.get('manifest') != spec['manifest']:
        raise ValueError('CAPTURE_REPORT_PROVENANCE')
    rows = report.get('cases', [])
    if not isinstance(rows, list) or len(rows) != len(spec['cases']):
        raise ValueError('CAPTURE_CASE_COVERAGE')
    for expected, actual in zip(spec['cases'], rows):
        if any(actual.get(field) != expected[field] for field in ('id', 'cast', 'species', 'life_stage', 'clip', 'scenario')):
            raise ValueError('CAPTURE_CASE_IDENTITY')
        if actual.get('production_qualified') is not False or actual.get('status') != 'SAMPLED_RUNTIME_ONLY' or \
                not 0 < actual.get('samples', 0) <= 1200 or not valid_bounds(actual.get('bounds_m')):
            raise ValueError('CAPTURE_CASE_RESULT')
        if actual.get('skin_engine_parity') != 'MEASURED' or actual.get('skin_engine_matrix_checks', 0) <= 0 or \
                actual.get('skin_engine_matrix_max_error_m') != 0:
            raise ValueError('CAPTURE_NATIVE_PALETTE_UNVERIFIED')
        validate_timeline(actual)
        if expected['clip'] == 'heavy_hammer_swing' and actual.get('bone_pose_max_change_from_first', 0) <= 0:
            raise ValueError('CAPTURE_HAMMER_MOTION_MISSING')
        attachments = actual.get('attachments', [])
        if [entry.get('key') for entry in attachments] != expected['attachments']:
            raise ValueError('CAPTURE_ATTACHMENT_COVERAGE')
        if any(not valid_bounds(entry.get('bounds_m')) or not valid_bounds(entry.get('body_and_attachment_bounds_m'))
               for entry in attachments):
            raise ValueError('CAPTURE_ATTACHMENT_RESULT')


def validate_timeline(actual: dict) -> None:
    """Check every observed source position, not merely positive sample and palette totals."""
    duration = actual.get('clip_duration_s', 0)
    if not isinstance(duration, (float, int)) or not math.isfinite(duration) or duration <= 0:
        raise ValueError('CAPTURE_TIMELINE_DURATION')
    count = math.ceil(duration * 30) + 1
    positions = actual.get('clip_positions_s', [])
    if actual.get('expected_sample_count') != count or actual.get('samples') != count or len(positions) != count:
        raise ValueError('CAPTURE_TIMELINE_COVERAGE')
    per_sample = actual.get('expected_palette_checks_per_sample', 0)
    if per_sample <= 0 or actual.get('skin_engine_matrix_checks') != count * per_sample:
        raise ValueError('CAPTURE_PALETTE_COVERAGE')
    looping = actual.get('clip_loop_mode')
    if looping not in (0, 1):
        raise ValueError('CAPTURE_TIMELINE_LOOP_UNSUPPORTED')
    for frame, position in enumerate(positions):
        expected = (frame / 30) % duration if looping == 1 else min(frame / 30, duration)
        # Diagnostic engine-time comparison only; this tolerance is never a spatial residual or clearance.
        if not isinstance(position, (float, int)) or not math.isfinite(position) or \
                not math.isclose(position, expected, rel_tol=1e-5, abs_tol=1e-6):
            raise ValueError('CAPTURE_TIMELINE_POSITION')


def preflight_bundle(directory: Path) -> None:
    """Preserve the entire prior evidence bundle before writing even a replacement input manifest."""
    if any((directory / name).exists() or (directory / name).is_symlink() for name in BUNDLE_NAMES):
        raise ValueError('CAPTURE_OUTPUT_BUNDLE_EXISTS')


def create_spec(directory: Path, spec: dict) -> Path:
    """Create a fresh pinned input only after all output paths are known unused."""
    preflight_bundle(directory)
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'capture-spec.json'
    with target.open('x') as stream:
        stream.write(json.dumps(spec, indent=2, sort_keys=True) + '\n')
    return target


def run_native(spec: dict, target: Path) -> None:
    """Run only a newly created report/log, reject diagnostics, and bind final evidence to unchanged sources."""
    output, log = target.parent / 'capture-native.json', target.parent / 'capture-native.log'
    verification = target.parent / 'verification.json'
    if any(p.exists() or p.is_symlink() for p in (output, log, verification)):
        raise ValueError('CAPTURE_OUTPUT_BUNDLE_EXISTS')
    command = ['godot', '--path', str(REPO / 'godot'), '--rendering-method', 'gl_compatibility',
               '--audio-driver', 'Dummy', '--script', str(REPO / 'tools/capture_underground_profiles.gd'),
               '--', str(target), str(output)]
    with log.open('x') as stream:
        result = subprocess.run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, timeout=600)
    if result.returncode != 0:
        raise ValueError(f'CAPTURE_ENGINE_EXIT:{result.returncode}')
    report = json.loads(output.read_text())
    validate_report(spec, report, log.read_text())
    if report.get('spec_sha256') != pin(str(target))['sha256'] or report.get('rendering_driver') == 'dummy':
        raise ValueError('CAPTURE_NATIVE_PROVENANCE')
    for source in [spec['manifest'], *spec['sources']]:
        if pin(source['path']) != source:
            raise ValueError(f"CAPTURE_SOURCE_DRIFT:{source['path']}")
    checks = sum(row['skin_engine_matrix_checks'] for row in report['cases'])
    summary = {'schema': 1, 'scope': 'sampled staged runtime evidence only', 'command': command,
               'engine': report['engine'], 'cases': len(report['cases']), 'sources': len(spec['sources']),
               'sampled_poses': sum(row['samples'] for row in report['cases']), 'matrix_checks': checks,
               'matrix_max_observed_error_m': 0, 'unexpected_diagnostics': 0, 'leaked_objects': 0,
               'leaked_resources': 0, 'production_qualified': False, 'qualified_profile_count': 0,
               'report': pin(str(output)), 'log': pin(str(log)), 'spec': pin(str(target))}
    with verification.open('x') as stream:
        stream.write(json.dumps(summary, indent=2) + '\n')
    print(f"capture verified: {summary['cases']} cases; {summary['sampled_poses']} sampled poses; "
          f'{checks} exact observed native matrix checks; 0 unexpected diagnostics/leaks; 0 qualified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true', help='also run and strictly verify the native capture')
    parser.add_argument('--out-dir', type=Path, default=HERE, help='fresh evidence directory; existing bundles refuse')
    args = parser.parse_args()
    preflight_bundle(args.out_dir)
    result = build()
    target = create_spec(args.out_dir.resolve(), result)
    print(f"capture input: {len(result['cases'])} cases; {len(result['sources'])} exact source pins; "
          f"{len(result['explicit_source_gaps'])} explicit clip gaps; no production permission")
    if args.run:
        run_native(result, target)
