#!/usr/bin/env python3
"""Adversarial offline harness tests. Synthetic input is refused before any fake mesh can load."""
from __future__ import annotations

import hashlib
import importlib.util
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools/capture_underground_profiles.gd'
DIAGNOSTIC = re.compile(r'^(?:SCRIPT ERROR|ERROR|WARNING):|(?:ObjectDB instances? (?:were|was) leaked)|resources still in use', re.M)
REPRO_PATH = ROOT / 'docs/design/underground-planning/evidence/modular-build/profiles/runtime/reproduce.py'
REPRO_SPEC = importlib.util.spec_from_file_location('capture_reproduce', REPRO_PATH)
REPRO = importlib.util.module_from_spec(REPRO_SPEC)
REPRO_SPEC.loader.exec_module(REPRO)


def pin(path: Path, alias: str | None = None) -> dict:
    """Hash exact fixture or implementation bytes."""
    return {'path': alias or str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


class CaptureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory(prefix='redwall-capture-test-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.fake = self.root / 'not-a-model.glb'
        self.fake.write_bytes(b'synthetic fixture must never reach ResourceLoader')
        self.cache = self.root / 'not-a-scene.scn'
        self.cache.write_bytes(b'synthetic imported scene must never load')
        self.metadata = Path(str(self.fake) + '.import')
        self.metadata.write_text(f'[remap]\npath="{self.cache}"\n[deps]\ndest_files=["{self.cache}"]\n')
        self.manifest = self.root / 'manifest.json'
        self.manifest.write_text(json.dumps({'cast': {'mouse': {'species': 'mouse', 'body': str(self.fake),
            'clips': {'walk': str(self.fake)}, 'height_m': 1}}, 'world': {}}))
        paths = sorted(REPRO.implementation_sources())
        self.spec = {'schema': 1, 'manifest': pin(self.manifest),
            'sources': [pin(ROOT / 'godot' / p[6:], p) for p in paths] +
                       [pin(TOOL), pin(self.metadata), pin(self.cache), pin(self.fake)],
            'cases': [{'id': 'fixture', 'cast': 'mouse', 'species': 'mouse',
                       'life_stage': 'adult_presentation_candidate', 'clip': 'walk',
                       'scenario': 'plain', 'attachments': []}]}

    def run_input(self, value: dict, expected: str, output: Path | None = None) -> dict:
        path = self.root / 'spec.json'
        path.write_text(json.dumps(value))
        target = output or self.root / 'out.json'
        command = ['godot', '--headless', '--path', str(ROOT / 'godot'), '--script', str(TOOL), '--', str(path), str(target)]
        done = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
        self.assertIsNone(DIAGNOSTIC.search(done.stdout + done.stderr), done.stdout + done.stderr)
        result = json.loads(target.read_text())
        self.assertEqual(result['error'], expected)
        self.assertFalse(result['production_qualified'])
        self.assertEqual(result['qualified_profile_count'], 0)
        return result

    def test_eight_influences_and_missing_bind_state_geometry_are_guarded(self) -> None:
        target = self.root / 'self.json'
        done = subprocess.run(['godot', '--headless', '--path', str(ROOT / 'godot'), '--script', str(TOOL),
            '--', '--self-test', str(target)], capture_output=True, text=True, timeout=30)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIsNone(DIAGNOSTIC.search(done.stdout + done.stderr), done.stdout + done.stderr)
        report = json.loads(target.read_text())
        self.assertGreaterEqual(len(report['checks']), 9)
        self.assertTrue(all(report['checks'].values()), report)
        self.assertFalse(report['production_qualified'])

    def test_changed_source_bytes_refuse(self) -> None:
        self.fake.write_bytes(b'changed')
        self.run_input(self.spec, 'CAPTURE_SOURCE_HASH')

    def test_duplicate_source_pin_refuses(self) -> None:
        self.spec['sources'].append(self.spec['sources'][-1])
        self.run_input(self.spec, 'CAPTURE_SOURCE_HASH')

    def test_missing_actual_implementation_pin_refuses(self) -> None:
        self.spec['sources'].pop(0)
        self.run_input(self.spec, 'CAPTURE_IMPLEMENTATION_UNPINNED')

    def test_missing_indirect_hand_or_clip_helper_pin_refuses(self) -> None:
        self.spec['sources'] = [p for p in self.spec['sources'] if not p['path'].endswith('/clip_root_motion.gd')]
        self.run_input(self.spec, 'CAPTURE_IMPLEMENTATION_UNPINNED')

    def test_absent_clip_cannot_inherit_another_state(self) -> None:
        self.spec['cases'][0]['clip'] = 'cautious_crouch_walk_forward'
        self.run_input(self.spec, 'CAPTURE_STATE_MISSING')

    def test_species_cannot_inherit_another_rig(self) -> None:
        self.spec['cases'][0]['species'] = 'mole'
        self.run_input(self.spec, 'CAPTURE_CAST_IDENTITY')

    def test_child_cannot_inherit_adult_presentation(self) -> None:
        self.spec['cases'][0]['life_stage'] = 'child'
        self.run_input(self.spec, 'CAPTURE_CAST_IDENTITY')

    def test_unloaded_clip_cannot_borrow_carried_mesh(self) -> None:
        self.spec['cases'][0]['attachments'] = ['log']
        self.run_input(self.spec, 'CAPTURE_ATTACHMENT_STATE')

    def test_missing_state_source_pin_refuses(self) -> None:
        self.spec['sources'].pop()
        self.run_input(self.spec, 'CAPTURE_STATE_SOURCE_UNPINNED')

    def test_missing_actual_imported_scene_pin_refuses(self) -> None:
        self.spec['sources'] = [p for p in self.spec['sources'] if p['path'] != str(self.cache)]
        self.run_input(self.spec, 'CAPTURE_IMPORTED_SOURCE_UNPINNED')

    def test_duplicate_case_refuses(self) -> None:
        self.spec['cases'].append(self.spec['cases'][0])
        self.run_input(self.spec, 'CAPTURE_CASE_FORMAT')

    def test_case_capacity_refuses_before_any_resource_load(self) -> None:
        self.spec['cases'] *= 129
        self.run_input(self.spec, 'CAPTURE_CAPACITY')

    def test_manifest_format_refuses(self) -> None:
        self.manifest.write_text('{}')
        self.spec['manifest'] = pin(self.manifest)
        self.run_input(self.spec, 'CAPTURE_MANIFEST_FORMAT')

    def assert_existing_output_preserved(self, target: Path) -> None:
        before = target.read_bytes()
        source = self.root / 'spec.json'
        source.write_text(json.dumps(self.spec))
        done = subprocess.run(['godot', '--headless', '--path', str(ROOT / 'godot'), '--script', str(TOOL),
            '--', str(source), str(target)], capture_output=True, text=True, timeout=30)
        self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
        self.assertIsNone(DIAGNOSTIC.search(done.stdout + done.stderr), done.stdout + done.stderr)
        self.assertIn('CAPTURE_OUTPUT_EXISTS', done.stderr)
        self.assertEqual(target.read_bytes(), before)

    def test_source_output_remains_intact_even_before_first_pin_failure(self) -> None:
        self.spec['manifest']['sha256'] = '0' * 64
        self.assert_existing_output_preserved(self.fake)

    def test_manifest_output_is_never_truncated_by_a_refusal(self) -> None:
        self.assert_existing_output_preserved(self.manifest)

    def test_symlinked_source_output_is_preserved(self) -> None:
        alias = self.root / 'symlink.json'
        alias.symlink_to(self.manifest)
        self.assert_existing_output_preserved(alias)
        self.assertTrue(alias.is_symlink())

    def test_hardlinked_source_output_is_preserved(self) -> None:
        alias = self.root / 'hardlink.json'
        os.link(self.manifest, alias)
        self.assert_existing_output_preserved(alias)

    def test_omitted_loaded_neighbor_clip_pin_refuses(self) -> None:
        other = self.root / 'other.glb'
        other.write_bytes(b'neighbor clip must also be pinned because Actor.setup loads it')
        manifest = json.loads(self.manifest.read_text())
        manifest['cast']['mouse']['clips']['idle'] = str(other)
        self.manifest.write_text(json.dumps(manifest))
        self.spec['manifest'] = pin(self.manifest)
        self.run_input(self.spec, 'CAPTURE_STATE_SOURCE_UNPINNED')


class ReportTests(unittest.TestCase):
    """Synthetic reports exercise the outer guard; they never become measurement artifacts."""
    def setUp(self) -> None:
        row = {'id': 'synthetic', 'cast': 'synthetic_mouse', 'species': 'mouse',
               'life_stage': 'adult_presentation_candidate', 'clip': 'carry_heavy_object_walk',
               'scenario': 'plain', 'attachments': ['log']}
        self.spec = {'manifest': {'synthetic': True}, 'sources': [], 'cases': [row]}
        actual = copy.deepcopy(row)
        actual.update({'production_qualified': False, 'status': 'SAMPLED_RUNTIME_ONLY', 'samples': 16,
                       'bounds_m': [-1, 0, -1, 1, 1, 1], 'skin_engine_parity': 'MEASURED',
                       'skin_engine_matrix_checks': 16, 'skin_engine_matrix_max_error_m': 0,
                       'clip_duration_s': 0.5, 'clip_loop_mode': 0, 'expected_sample_count': 16,
                       'expected_palette_checks_per_sample': 1, 'clip_positions_s': [n / 30 for n in range(16)],
                       'bone_pose_max_change_from_first': 0.8,
                       'attachments': [{'key': 'log', 'bounds_m': [-1, 0, -1, 1, 1, 1],
                                        'body_and_attachment_bounds_m': [-1, 0, -1, 1, 1, 1]}]})
        self.report = {'error': '', 'status': 'SAMPLED_RUNTIME_ONLY', 'production_qualified': False,
                       'qualified_profile_count': 0, 'continuous_residual_um': None,
                       'missing_bindings': ['SYNTHETIC_UNQUALIFIED'], 'manifest': self.spec['manifest'],
                       'sources': [], 'cases': [actual]}

    def test_complete_synthetic_report_has_valid_shape_only(self) -> None:
        REPRO.validate_report(self.spec, self.report, 'synthetic clean log')

    def test_script_error_rejects_even_a_complete_zero_error_report(self) -> None:
        with self.assertRaisesRegex(ValueError, 'CAPTURE_UNEXPECTED_DIAGNOSTICS'):
            REPRO.validate_report(self.spec, self.report, 'SCRIPT ERROR: simulated API failure\n')

    def test_silently_skipped_attachment_rejects(self) -> None:
        self.report['cases'][0]['attachments'] = []
        with self.assertRaisesRegex(ValueError, 'CAPTURE_ATTACHMENT_COVERAGE'):
            REPRO.validate_report(self.spec, self.report, '')

    def test_unverified_renderer_palette_rejects_native_evidence(self) -> None:
        self.report['cases'][0]['skin_engine_parity'] = 'RENDERER_PALETTE_UNAVAILABLE'
        with self.assertRaisesRegex(ValueError, 'CAPTURE_NATIVE_PALETTE_UNVERIFIED'):
            REPRO.validate_report(self.spec, self.report, '')

    def test_synthetic_residual_cannot_promote_sampled_bounds(self) -> None:
        self.report['continuous_residual_um'] = 0
        with self.assertRaisesRegex(ValueError, 'CAPTURE_UNSUPPORTED_QUALIFICATION'):
            REPRO.validate_report(self.spec, self.report, '')

    def test_positive_counts_cannot_hide_a_frozen_nonlooping_clip(self) -> None:
        self.report['cases'][0]['clip_positions_s'] = [0.5] * 16
        with self.assertRaisesRegex(ValueError, 'CAPTURE_TIMELINE_POSITION'):
            REPRO.validate_report(self.spec, self.report, '')

    def test_partial_skin_palette_count_refuses(self) -> None:
        self.report['cases'][0]['skin_engine_matrix_checks'] = 15
        with self.assertRaisesRegex(ValueError, 'CAPTURE_PALETTE_COVERAGE'):
            REPRO.validate_report(self.spec, self.report, '')

    def test_nonlooping_hammer_needs_observed_pose_change(self) -> None:
        self.spec['cases'][0]['clip'] = 'heavy_hammer_swing'
        self.report['cases'][0]['clip'] = 'heavy_hammer_swing'
        self.report['cases'][0]['bone_pose_max_change_from_first'] = 0
        with self.assertRaisesRegex(ValueError, 'CAPTURE_HAMMER_MOTION_MISSING'):
            REPRO.validate_report(self.spec, self.report, '')


class BundleTests(unittest.TestCase):
    def test_preserved_output_bundle_refuses_before_changing_any_prior_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix='redwall-capture-bundle-') as directory:
            root = Path(directory)
            for name in REPRO.BUNDLE_NAMES:
                (root / name).write_bytes(('preserved ' + name).encode())
            before = {p.name: p.read_bytes() for p in root.iterdir()}
            with self.assertRaisesRegex(ValueError, 'CAPTURE_OUTPUT_BUNDLE_EXISTS'):
                REPRO.create_spec(root, {'changed': 'input'})
            self.assertEqual(before, {p.name: p.read_bytes() for p in root.iterdir()})

    def test_prior_report_alone_prevents_creating_a_new_input(self) -> None:
        with tempfile.TemporaryDirectory(prefix='redwall-capture-bundle-') as directory:
            root = Path(directory)
            (root / 'capture-native.json').write_bytes(b'preserved report')
            with self.assertRaisesRegex(ValueError, 'CAPTURE_OUTPUT_BUNDLE_EXISTS'):
                REPRO.create_spec(root, {'changed': 'input'})
            self.assertEqual(list(root.iterdir()), [root / 'capture-native.json'])

    def test_fresh_evidence_directory_supports_one_create_only_input(self) -> None:
        with tempfile.TemporaryDirectory(prefix='redwall-capture-bundle-') as directory:
            root = Path(directory) / 'fresh'
            path = REPRO.create_spec(root, {'synthetic': True})
            self.assertEqual(json.loads(path.read_text()), {'synthetic': True})
            with self.assertRaisesRegex(ValueError, 'CAPTURE_OUTPUT_BUNDLE_EXISTS'):
                REPRO.create_spec(root, {'replacement': True})


if __name__ == '__main__':
    unittest.main(verbosity=2)
