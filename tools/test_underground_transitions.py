#!/usr/bin/env python3
"""Adversarial evidence tests; synthetic reports prove guard behavior, never production clearance."""
from __future__ import annotations

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / 'tools/capture_underground_transitions.gd'
REPRO_PATH = ROOT / 'docs/design/underground-planning/evidence/modular-build/profiles/runtime/transitions/reproduce.py'
SPEC = importlib.util.spec_from_file_location('transition_reproduce', REPRO_PATH)
REPRO = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPRO)
BASETEST_SPEC = importlib.util.spec_from_file_location('profile_capture_tests', ROOT / 'tools/test_underground_profile_capture.py')
BASETEST = importlib.util.module_from_spec(BASETEST_SPEC)
BASETEST_SPEC.loader.exec_module(BASETEST)


class EngineGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = BASETEST.CaptureTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.spec = self.fixture.spec
        sources = {entry['path']: entry for entry in self.spec['sources']}
        sources.update((path, REPRO.BASE.pin(path)) for path in REPRO.extra_sources())
        self.spec['sources'] = list(sources.values())
        self.spec['cases'][0]['transition'] = 'walk_turn'

    def run_input(self, expected: str) -> dict:
        source, target = self.fixture.root / 'spec.json', self.fixture.root / 'result.json'
        source.write_text(json.dumps(self.spec))
        done = subprocess.run(['godot', '--headless', '--path', str(ROOT / 'godot'), '--script', str(DRIVER),
                               '--', str(source), str(target)], capture_output=True, text=True, timeout=40)
        self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
        self.assertIsNone(REPRO.BASE.DIAGNOSTIC.search(done.stdout + done.stderr), done.stdout + done.stderr)
        result = json.loads(target.read_text())
        self.assertRegex(result['error'], expected)
        self.assertFalse(result['production_qualified'])
        return result

    def test_actual_core_identity_readers_fail_stale_refs_and_unbound_physical_variants(self) -> None:
        target = self.fixture.root / 'self.json'
        done = subprocess.run(['godot', '--headless', '--path', str(ROOT / 'godot'), '--script', str(DRIVER),
                               '--', '--self-test', str(target)], capture_output=True, text=True, timeout=40)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIsNone(REPRO.BASE.DIAGNOSTIC.search(done.stdout + done.stderr), done.stdout + done.stderr)
        result = json.loads(target.read_text())
        self.assertGreaterEqual(len(result['checks']), 10)
        self.assertTrue(all(result['checks'].values()), result)
        self.assertEqual(result['qualified_profile_count'], 0)

    def test_missing_inherited_evaluator_refuses(self) -> None:
        self.spec['sources'] = [s for s in self.spec['sources'] if s['path'] != str(BASETEST.TOOL)]
        self.run_input('TRANSITION_INHERITED_IMPLEMENTATION_UNPINNED')

    def test_missing_reader_dependency_refuses(self) -> None:
        self.spec['sources'] = [s for s in self.spec['sources'] if not s['path'].endswith('/gear.gd')]
        self.run_input('IMPLEMENTATION_UNPINNED')

    def test_missing_actual_item_catalog_refuses(self) -> None:
        self.spec['sources'] = [s for s in self.spec['sources'] if not s['path'].endswith('/item_definitions.json')]
        self.run_input('TRANSITION_CATALOG_UNPINNED')

    def test_unknown_transition_refuses_before_fake_mesh_load(self) -> None:
        self.spec['cases'][0]['transition'] = 'inferred_ladder_grip'
        self.run_input('TRANSITION_CASE_FORMAT')

    def test_missing_fade_clip_cannot_inherit_walk(self) -> None:
        self.run_input('TRANSITION_REQUIRED_CLIP_MISSING')

    def test_changed_driver_source_refuses(self) -> None:
        next(s for s in self.spec['sources'] if s['path'] == str(DRIVER))['sha256'] = '0' * 64
        self.run_input('CAPTURE_SOURCE_HASH')


class ReportGuardTests(unittest.TestCase):
    """Small synthetic observation rows keep every missing proof independently testable."""
    def setUp(self) -> None:
        self.request = {'id': 'synthetic_mouse.walk_turn', 'cast': 'synthetic_mouse', 'species': 'mouse',
                        'life_stage': 'adult_presentation_candidate', 'clip': 'walk', 'scenario': 'plain',
                        'transition': 'walk_turn', 'attachments': []}
        identity = {'error': '', 'resident_ref': [1, 1], 'species_id': 7, 'species': 'mouse', 'life_stage': 'ADULT',
                    'logical_rig': 'rig_mouse_v1', 'physical_variant_binding': 'UNBOUND', 'production_qualified': False,
                    'gear': {'lot_ref': [2, 1], 'item_id': 54, 'quantity_milli': 1000, 'durability': 1000,
                             'physical_variant_binding': 'UNBOUND'}, 'cargo': {}}
        self.row = {**self.request, 'samples': 4, 'expected_sample_count': 4, 'expected_palette_checks_per_sample': 1,
                    'skin_engine_matrix_checks': 4, 'skin_engine_matrix_max_error_m': 0, 'skin_engine_parity': 'MEASURED',
                    'status': 'SAMPLED_RUNTIME_ONLY', 'production_qualified': False, 'physical_variant_binding': 'UNBOUND',
                    'bounds_m': [-1, 0, -1, 1, 1, 1], 'clip_positions_s': [0, 1/30, 1/30, 2/30], 'bone_pose_max_change_from_first': 0.1,
                    'identity_initial': identity, 'identity_final': copy.deepcopy(identity), 'attachments': [], 'attachment_visibility': [],
                    'events': [{'name': name, 'step': i} for i, name in enumerate(REPRO.EXPECTED_EVENTS['walk_turn'])],
                    'motion': [{'step': i, 'root_m': [0, 0, i/30], 'yaw_rad': i/30, 'pitch_rad': 0, 'state': 1,
                                'clip': 'walk' if i < 2 else 'idle', 'played_clip': 'walk' if i < 2 else 'idle',
                                'animation_name': 'cast/walk' if i < 2 else 'cast/idle',
                                'animation_length_s': 2, 'animation_loop_mode': 1,
                                'clip_position_s': i/30 if i < 2 else (i-1)/30, 'clip_rate': 1,
                                'brain_clip_time_s': i/30, 'bore_progress_m': 0, 'stoop_m': 0,
                                'identity': copy.deepcopy(identity)} for i in range(4)]}
        self.spec = {'manifest': {'synthetic': True}, 'sources': [], 'cases': [self.request]}
        self.report = {'error': '', 'status': 'SAMPLED_RUNTIME_ONLY', 'production_qualified': False,
                       'qualified_profile_count': 0, 'continuous_residual_um': None, 'missing_bindings': ['UNQUALIFIED'],
                       'manifest': self.spec['manifest'], 'sources': [], 'cases': [self.row]}

    def rejects(self, error: str) -> None:
        with self.assertRaisesRegex(ValueError, error):
            REPRO.validate_report(self.spec, self.report, '')

    def test_complete_synthetic_shape_is_not_qualification(self) -> None:
        REPRO.validate_report(self.spec, self.report, '')
        self.assertFalse(self.report['production_qualified'])

    def test_missing_exit_or_reverse_event_refuses(self) -> None:
        self.row['events'].pop(1)
        self.rejects('TRANSITION_EVENT_COVERAGE')

    def test_partial_motion_rejects_positive_counts(self) -> None:
        self.row['motion'].pop()
        self.rejects('TRANSITION_MOTION_COVERAGE')

    def test_frozen_animation_timeline_refuses(self) -> None:
        self.row['motion'][1]['clip_position_s'] = 0
        self.row['clip_positions_s'][1] = 0
        self.rejects('TRANSITION_SOURCE_TIMELINE')

    def test_absent_actual_played_clip_refuses(self) -> None:
        for frame in self.row['motion']:
            frame['played_clip'] = 'idle'
        self.rejects('TRANSITION_SOURCE_STATE_COVERAGE')

    def test_partial_palette_rejects_native_success(self) -> None:
        self.row['skin_engine_matrix_checks'] = 3
        self.rejects('TRANSITION_PALETTE_COVERAGE')

    def test_changed_actual_gear_generation_refuses(self) -> None:
        self.row['motion'][1]['identity']['gear']['lot_ref'][1] += 1
        self.rejects('TRANSITION_IDENTITY_CHANGED')

    def test_changed_cargo_quantity_refuses(self) -> None:
        self.row['motion'][1]['identity']['cargo'] = {'quantity_milli': 999}
        self.rejects('TRANSITION_IDENTITY_CHANGED')

    def test_slot_only_gear_ref_refuses(self) -> None:
        self.row['identity_initial']['gear']['lot_ref'] = [2]
        self.row['identity_final'] = copy.deepcopy(self.row['identity_initial'])
        for frame in self.row['motion']:
            frame['identity'] = copy.deepcopy(self.row['identity_initial'])
        self.rejects('TRANSITION_GEAR_EVIDENCE')

    def test_physical_binding_cannot_be_fabricated(self) -> None:
        self.row['physical_variant_binding'] = 'ACCEPTED'
        self.rejects('TRANSITION_CASE_RESULT')

    def test_sampled_residual_cannot_be_promoted(self) -> None:
        self.report['continuous_residual_um'] = 0
        self.rejects('TRANSITION_REPORT_STATUS')

    def test_no_observed_turn_refuses(self) -> None:
        for frame in self.row['motion']:
            frame['yaw_rad'] = 0
        self.rejects('TRANSITION_TURN_NOT_OBSERVED')

    def test_nan_root_refuses(self) -> None:
        self.row['motion'][1]['root_m'][0] = float('nan')
        self.rejects('TRANSITION_FRAME_INVALID')

    def test_engine_error_cannot_hide_behind_complete_rows(self) -> None:
        with self.assertRaisesRegex(ValueError, 'TRANSITION_UNEXPECTED_DIAGNOSTICS'):
            REPRO.validate_report(self.spec, self.report, 'SCRIPT ERROR: synthetic failure')

    def test_reversal_cannot_reset_committed_progress(self) -> None:
        self.request['transition'] = self.row['transition'] = 'tunnel_reversal'
        self.row['events'] = [{'name': name, 'step': i} for i, name in enumerate(REPRO.EXPECTED_EVENTS['tunnel_reversal'])]
        self.row['events'][1].update({'progress_before_m': 1, 'progress_after_m': 0})
        self.rejects('TRANSITION_PROGRESS_RESET')


class BundleTests(unittest.TestCase):
    def test_prior_bundle_preserved_before_subprocess_or_input_write(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in REPRO.BASE.BUNDLE_NAMES:
                (root / name).write_bytes(b'prior source-bound evidence')
            before = {p.name: p.read_bytes() for p in root.iterdir()}
            with mock.patch.object(REPRO.subprocess, 'run') as run:
                with self.assertRaisesRegex(ValueError, 'OUTPUT_BUNDLE_EXISTS'):
                    REPRO.run({}, root)
                run.assert_not_called()
            self.assertEqual(before, {p.name: p.read_bytes() for p in root.iterdir()})

    def test_relative_output_directory_is_resolved_before_engine_changes_working_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            relative = Path(os.path.relpath(directory, Path.cwd()))
            with mock.patch.object(REPRO.subprocess, 'run', side_effect=RuntimeError('intercept')) as run:
                with self.assertRaisesRegex(RuntimeError, 'intercept'):
                    REPRO.run({}, relative)
            command = run.call_args.args[0]
            start = command.index('--') + 1
            self.assertTrue(all(Path(p).is_absolute() for p in command[start:]))
            self.assertEqual(json.loads((Path(directory) / 'capture-spec.json').read_text()), {})

    def test_lone_report_also_preserves_all_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'capture-native.json').write_bytes(b'old report')
            with self.assertRaisesRegex(ValueError, 'OUTPUT_BUNDLE_EXISTS'):
                REPRO.run({}, root)
            self.assertEqual([(p.name, p.read_bytes()) for p in root.iterdir()], [('capture-native.json', b'old report')])


if __name__ == '__main__':
    unittest.main(verbosity=2)
