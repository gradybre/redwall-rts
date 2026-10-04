#!/usr/bin/env python3
"""Adversarial replay of the source-bound native heading evidence; no engine or permissions implied."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('heading_reproduce', HERE / 'reproduce.py')
CAPTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CAPTURE)


class HeadingEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = json.loads((HERE / 'native/capture-spec.json').read_text())
        cls.report = json.loads((HERE / 'native/capture-native.json').read_text())
        cls.log = (HERE / 'native/capture-native.log').read_text()
        cls.baseline = json.loads((HERE.parent / 'transitions/native-v2/capture-native.json').read_text())

    def changed(self) -> dict:
        return copy.deepcopy(self.report)

    def test_actual_native_capture_passes_all_inherited_and_heading_checks(self) -> None:
        CAPTURE.validate_report(self.spec, self.report, self.log)

    def test_every_preexisting_motion_field_matches_the_original_unsmoothed_brain(self) -> None:
        original = {row['id']: row for row in self.baseline['cases']}
        for case in self.report['cases']:
            before = original[case['id']]
            for field in ('samples', 'events', 'identity_initial', 'identity_final', 'clip_positions_s'):
                self.assertEqual(case[field], before[field], (case['id'], field))
            self.assertEqual(len(case['motion']), len(before['motion']))
            for index, (first, second) in enumerate(zip(before['motion'], case['motion'])):
                for field, value in first.items():
                    self.assertEqual(second[field], value, (case['id'], index, field))

    def test_old_pi_snap_is_rejected_even_if_all_native_matrix_checks_pass(self) -> None:
        report = self.changed()
        row = report['cases'][0]['motion'][2]
        row['rendered_yaw_rad'] = row['yaw_rad']
        with self.assertRaisesRegex(ValueError, 'HEADING_RENDERED_SNAP'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_slope_cannot_jump_ahead_of_the_rendered_turn(self) -> None:
        report = self.changed()
        report['cases'][0]['motion'][2]['rendered_pitch_rad'] += 0.2
        with self.assertRaisesRegex(ValueError, 'HEADING_PITCH_PROGRESS'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_spine_counterlean_cannot_jump_independently(self) -> None:
        report = self.changed()
        report['cases'][0]['motion'][2]['rendered_stoop_lean_rad'] += 0.2
        with self.assertRaisesRegex(ValueError, 'HEADING_STOOP_PROGRESS'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_missing_real_rendered_observation_refuses(self) -> None:
        report = self.changed()
        del report['cases'][0]['motion'][2]['rendered_yaw_rad']
        with self.assertRaisesRegex(ValueError, 'HEADING_OBSERVATION_MISSING'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_nonfinite_rendered_observation_refuses(self) -> None:
        report = self.changed()
        report['cases'][0]['motion'][2]['rendered_yaw_rad'] = float('nan')
        with self.assertRaisesRegex(ValueError, 'HEADING_OBSERVATION_MISSING'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_forged_peak_does_not_hide_a_different_motion_sequence(self) -> None:
        report = self.changed()
        report['cases'][0]['max_rendered_yaw_step_rad'] = 0
        with self.assertRaisesRegex(ValueError, 'HEADING_PEAK_INCONSISTENT'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_slowing_the_reported_authority_is_not_a_passing_visual_fix(self) -> None:
        report = self.changed()
        report['cases'][0]['max_observed_yaw_step_rad'] = 0
        with self.assertRaisesRegex(ValueError, 'HEADING_BRAIN_REVERSAL_CHANGED'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_inherited_timeline_still_refuses_a_missing_pose(self) -> None:
        report = self.changed()
        report['cases'][0]['motion'].pop()
        with self.assertRaisesRegex(ValueError, 'TRANSITION_MOTION_COVERAGE'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_inherited_progress_guard_still_refuses_a_reset(self) -> None:
        report = self.changed()
        report['cases'][0]['events'][1]['progress_after_m'] = -1
        with self.assertRaisesRegex(ValueError, 'TRANSITION_PROGRESS_RESET'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_source_provenance_cannot_be_removed_to_approve_new_motion(self) -> None:
        report = self.changed()
        report['sources'].pop()
        with self.assertRaisesRegex(ValueError, 'TRANSITION_PROVENANCE'):
            CAPTURE.validate_report(self.spec, report, self.log)

    def test_native_sample_does_not_grant_profile_qualification(self) -> None:
        report = self.changed()
        report['production_qualified'] = True
        with self.assertRaisesRegex(ValueError, 'TRANSITION_REPORT_STATUS'):
            CAPTURE.validate_report(self.spec, report, self.log)


if __name__ == '__main__':
    unittest.main()
