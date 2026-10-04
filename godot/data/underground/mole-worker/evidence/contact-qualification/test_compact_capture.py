"""Retained native witness validation; these tests launch no renderer and admit no gameplay state."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_capture", HERE / "run_compact_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class CompactCapture(unittest.TestCase):
    def setUp(self):
        source = HERE / "native-compact-program-v1"
        self.report = json.loads((source / "report.json").read_text())
        self.spec = json.loads((source / "spec.json").read_text())
        self.table = R.BASE.wire_timing(self.spec)

    def test_actual_eleven_clip_three_work_program_has_exact_positive_native_census(self):
        result = R.validate_report(self.report, self.spec, self.table)
        self.assertEqual(result, {"poses": 2214, "assertions": 9148, "phases": 9, "work_choices": 3,
                                  "production_qualified": False})

    def test_partial_motion_or_failed_assertions_cannot_pass_with_exit_zero(self):
        for change in ({"poses": 2213}, {"assertions": 0}, {"assertions": True}, {"failures": ["native failure"]},
                       {"production_qualified": True}, {"content_sha256": "0" * 64}):
            with self.assertRaises(ValueError):
                R.validate_report(dict(self.report, **change), self.spec, self.table)

    def test_wrong_loop_rule_missing_front_or_unmatched_recovery_refuses(self):
        with self.assertRaisesRegex(ValueError, "TIMING"):
            R.expected_poses(self.table[:8])
        for clip, field in ((8, 2), (10, 3)):
            table = [list(row) for row in self.table]
            table[clip][field] += 1
            with self.assertRaisesRegex(ValueError, "TIMING"):
                R.expected_poses(table)

    def test_wrong_work_source_frame_cannot_borrow_another_valid_contact_role(self):
        event = next(row for row in self.report["events"] if row["profile"] == 4 and row["phase"] == 6)
        changed = copy.deepcopy(event)
        changed["frames"][0:2] = [self.table[2][0], self.table[2][0] + 1]
        with self.assertRaisesRegex(ValueError, "ROLE_FRAMES"):
            R.event_refusal(changed, self.table)
        changed = dict(event, profile=1)
        with self.assertRaisesRegex(ValueError, "NATIVE_ROLE"):
            R.event_refusal(changed, self.table)

    def test_ready_and_carry_fade_cannot_hide_a_productive_source_or_instant_pose_jump(self):
        event = next(row for row in self.report["events"] if row["phase"] == 0)
        changed = copy.deepcopy(event)
        changed["frames"][0] = 7
        with self.assertRaisesRegex(ValueError, "HUB"):
            R.event_refusal(changed, self.table)
        event = next(row for row in self.report["events"] if row["phase"] == 3)
        changed = copy.deepcopy(event)
        changed["frames"][3] = self.table[2][0]
        with self.assertRaisesRegex(ValueError, "FADE_SOURCE"):
            R.event_refusal(changed, self.table)
        changed = copy.deepcopy(self.report["events"][0])
        changed["frames"][6] = 0
        with self.assertRaisesRegex(ValueError, "UNAUTHORED_BLEND"):
            R.event_refusal(changed, self.table)

    def test_missing_event_phase_or_image_list_refuses(self):
        for change in ({"events": self.report["events"][:-1]}, {"phase_counts": [0] * 10}, {"screenshots": []}):
            with self.assertRaisesRegex(ValueError, "PHASES"):
                R.validate_report(dict(self.report, **change), self.spec, self.table)

    def test_bound_role_and_protocol_bytes_cannot_be_replaced_behind_the_actual_image(self):
        source = HERE / "compact-program-compile-v2/result"
        roles = R.bound_roles(source / "mole-worker.ugactor", self.spec["content_sha256"], source)
        self.assertEqual(roles["front"]["CONTACT_PATCH"], [[4, 705, -768, 7, 710, -768]])
        with tempfile.TemporaryDirectory() as name:
            target = Path(name)
            for file in ("program.json", "roles.json", "plan.json"):
                (target / file).write_bytes((source / file).read_bytes())
            for file in ("program.json", "roles.json", "plan.json"):
                original = (target / file).read_bytes()
                (target / file).write_bytes(original + b" ")
                with self.assertRaisesRegex(ValueError, "METADATA"):
                    R.bound_roles(source / "mole-worker.ugactor", self.spec["content_sha256"], target)
                (target / file).write_bytes(original)


if __name__ == "__main__":
    unittest.main()
