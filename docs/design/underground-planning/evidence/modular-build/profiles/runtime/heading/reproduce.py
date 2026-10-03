#!/usr/bin/env python3
"""Compare real rendered heading with preserved Brain events in ten sampled underground transitions."""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('heading_transition_capture', HERE.parent / 'transitions/reproduce.py')
TRANSITIONS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRANSITIONS)
REPO = TRANSITIONS.REPO
DRIVER = REPO / 'tools/capture_underground_heading.gd'
BASE_DRIVER = TRANSITIONS.DRIVER
BASE_VALIDATE = TRANSITIONS.validate_report
TIME_ERROR = 0.00001  # Diagnostic float comparison only; never a spatial-clearance residual.


def source_scalar(name: str, source: str) -> float:
    """Read an existing presentation constant, refusing a changed expression instead of assuming it."""
    text = (REPO / source).read_text()
    match = re.search(r'^const ' + re.escape(name) + r': float = ([0-9]+\.[0-9]+)\s', text, re.M)
    if not match:
        raise ValueError(f'HEADING_SOURCE_CONSTANT:{name}')
    return float(match.group(1))


def arc(first: float, second: float) -> float:
    """Signed shortest display-angle difference, including the pi representation boundary."""
    return (second - first + math.pi) % (2.0 * math.pi) - math.pi


def validate_heading(report: dict) -> None:
    """Require actual Brain reversal but bounded rendered motion, matching slope and retained exit."""
    rate = source_scalar('SPOT_TURN_RATE', 'godot/demo/cast/resident_brain.gd')
    lean = source_scalar('LEAN_BACK_SHARE', 'godot/demo/cast/demo_actor.gd')
    for case in report['cases']:
        rows = case['motion']
        bound = rate * round(1000000 / report['sample_hz']) / 1000000
        peak = 0.0
        distinct = False
        for index, row in enumerate(rows):
            for field in ('rendered_yaw_rad', 'rendered_pitch_rad', 'rendered_stoop_lean_rad'):
                if not TRANSITIONS.finite(row.get(field)):
                    raise ValueError('HEADING_OBSERVATION_MISSING')
            difference = abs(arc(row['rendered_yaw_rad'], row['yaw_rad']))
            distinct = distinct or difference > bound
            if index:
                previous = rows[index - 1]
                step = abs(arc(previous['rendered_yaw_rad'], row['rendered_yaw_rad']))
                peak = max(peak, step)
                if step > bound + TIME_ERROR:
                    raise ValueError('HEADING_RENDERED_SNAP')
                prior_gap = abs(arc(previous['rendered_yaw_rad'], row['yaw_rad']))
                share = min(1.0, bound / prior_gap) if prior_gap else 1.0
                expected_pitch = previous['rendered_pitch_rad'] + (row['pitch_rad'] - previous['rendered_pitch_rad']) * share
                if abs(row['rendered_pitch_rad'] - expected_pitch) > TIME_ERROR:
                    raise ValueError('HEADING_PITCH_PROGRESS')
            if abs(row['rendered_stoop_lean_rad'] + row['rendered_pitch_rad'] * lean) > TIME_ERROR:
                raise ValueError('HEADING_STOOP_PROGRESS')
        if not distinct or case['max_observed_yaw_step_rad'] < math.pi - TIME_ERROR:
            raise ValueError('HEADING_BRAIN_REVERSAL_CHANGED')
        if abs(case.get('max_rendered_yaw_step_rad', -1) - peak) > TIME_ERROR:
            raise ValueError('HEADING_PEAK_INCONSISTENT')
        if abs(arc(rows[-1]['rendered_yaw_rad'], rows[-1]['yaw_rad'])) > TIME_ERROR:
            raise ValueError('HEADING_RECOVERY_INCOMPLETE')


def validate_report(spec: dict, report: dict, raw_log: str) -> None:
    """Retain every existing timeline, exact identity, event, source and native skin check first."""
    BASE_VALIDATE(spec, report, raw_log)
    validate_heading(report)


def build() -> dict:
    """Select exactly both underground cases for each real cast, retaining all inherited source pins."""
    spec = TRANSITIONS.build()
    spec['cases'] = [r for r in spec['cases'] if r['transition'].startswith('tunnel_')]
    expected = {(cast, mode) for cast in TRANSITIONS.BASE.CAST for mode in ('tunnel_reversal', 'tunnel_retreat')}
    if {(r['cast'], r['transition']) for r in spec['cases']} != expected or len(spec['cases']) != len(expected):
        raise ValueError('HEADING_CASE_COVERAGE')
    sources = {r['path']: r for r in spec['sources']}
    for path in (DRIVER, BASE_DRIVER, Path(__file__).resolve()):
        sources[str(path)] = TRANSITIONS.BASE.pin(str(path))
    spec['sources'] = [sources[path] for path in sorted(sources)]
    return spec


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-dir', type=Path, default=HERE / 'native')
    args = parser.parse_args()
    TRANSITIONS.BASE.preflight_bundle(args.out_dir)
    spec = build()
    TRANSITIONS.DRIVER = DRIVER
    TRANSITIONS.validate_report = validate_report
    result = TRANSITIONS.run(spec, args.out_dir)
    print(f"heading verified: {result['cases']} cases; {result['sampled_poses']} poses; {result['matrix_checks']} native matrix checks; bounded display turns; unchanged Brain events; 0 unexpected diagnostics/leaks; 0 qualified")


if __name__ == '__main__':
    main()
