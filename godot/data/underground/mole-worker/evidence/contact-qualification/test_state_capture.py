"""Adversarial validation of the actual retained native state-driver report; no rendering is repeated."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("state_capture", HERE / "run_state_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class Capture(unittest.TestCase):
    def setUp(self):
        self.spec = json.loads((HERE / "native-state-program-v1/spec.json").read_text())
        self.spec["content"] = str(HERE / "state-program-compile-v4/result/mole-worker.ugactor")
        self.report = json.loads((HERE / "native-state-program-v1/report.json").read_text())
        self.table = R.BASE.wire_timing(self.spec)

    def test_actual_complete_source_report_has_exact_pose_and_phase_census(self):
        result = R.validate_report(self.report, self.spec, self.table)
        self.assertEqual(result, {"poses": 1536, "assertions": 6358, "phases": 9, "production_qualified": False})

    def test_partial_or_empty_native_execution_never_passes_a_zero_exit(self):
        for changed in ({"poses": 0}, {"poses": 1535}, {"assertions": 0}, {"assertions": True},
                        {"events": self.report["events"][:-1]}):
            with self.assertRaises(ValueError):
                R.validate_report(dict(self.report, **changed), self.spec, self.table)

    def test_source_scope_or_failed_assertion_refuses_even_with_matching_counts(self):
        for changed in ({"production_qualified": True}, {"content_sha256": "0" * 64}, {"failures": ["actual tool drift"]}):
            with self.assertRaisesRegex(ValueError, "SCOPE"):
                R.validate_report(dict(self.report, **changed), self.spec, self.table)

    def test_missing_phase_or_changed_phase_tally_is_not_complete_state_coverage(self):
        for phase in range(9):
            changed = list(self.report["phase_counts"])
            changed[phase] -= 1
            with self.assertRaisesRegex(ValueError, "PHASES"):
                R.validate_report(dict(self.report, phase_counts=changed), self.spec, self.table)
        changed = list(self.report["phase_counts"])
        changed[9] = 1
        with self.assertRaisesRegex(ValueError, "PHASES"):
            R.validate_report(dict(self.report, phase_counts=changed), self.spec, self.table)

    def test_false_ready_invalid_phase_and_incomplete_renderer_packet_refuse(self):
        for key, value in (("ready", True), ("phase", 9), ("phase", False), ("frames", [0, 0, 0])):
            changed = copy.deepcopy(self.report)
            moving = next(row for row in changed["events"] if row["phase"] != 0)
            moving[key] = value
            with self.assertRaisesRegex(ValueError, "EVENT"):
                R.validate_report(changed, self.spec, self.table)

    def test_missing_images_or_different_source_clock_refuses(self):
        with self.assertRaisesRegex(ValueError, "PHASES"):
            R.validate_report(dict(self.report, screenshots=[]), self.spec, self.table)
        changed = list(self.table)
        changed[2] = (*changed[2][:3], changed[2][3] + 1)
        with self.assertRaisesRegex(ValueError, "TIMING"):
            R.validate_report(self.report, self.spec, changed)


if __name__ == "__main__":
    unittest.main()
