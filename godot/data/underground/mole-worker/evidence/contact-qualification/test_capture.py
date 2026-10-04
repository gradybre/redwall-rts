"""Synthetic evidence-runner failure regressions; no engine or content qualification."""
from copy import deepcopy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("capture", Path(__file__).with_name("run_capture.py"))
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


def tip():
    return {"content_sha256": "a" * 64, "production_qualified": False, "assertions": 61,
            "failures": [], "poses": 9, "screenshots": ["synthetic.png"],
            "native_points": [{"share_q16": step * 8192} for step in range(9)]}


class ReportRefusals(unittest.TestCase):
    def test_tip_requires_complete_census_and_empty_failures_despite_zero_exit(self):
        spec = {"content_sha256": "a" * 64}
        self.assertEqual(C.validate_report(tip(), "tip", spec, [])['poses'], 9)
        for delta in ({"poses": 0}, {"poses": 8}, {"assertions": 0}, {"assertions": True},
                      {"failures": ["rendering failed"]}, {"failures": None}, {"native_points": []},
                      {"screenshots": []}, {"production_qualified": True}, {"content_sha256": "b" * 64}):
            with self.assertRaises(ValueError):
                C.validate_report(dict(tip(), **delta), "tip", spec, [])

    def test_loop_report_must_match_actual_wire_first_frame_and_one_tick_interval(self):
        table = [(clip * 4, 4, 1 if clip < 7 else 0, 131073) for clip in range(9)]
        loops = [{"clip": clip, "duration_q16": duration, "frames": count,
                  "samples": [[131072, first + 2, first, 0]] * 5}
                 for clip, (first, count, _, duration) in enumerate(table[:7])]
        spec = {"content_sha256": "a" * 64, "source_frame_indices": [30, 31, 32, 30], "rig_entry": True}
        expected = 4 * (8 + 10 + 15) + 35
        report = {"content_sha256": "a" * 64, "production_qualified": False, "assertions": expected * 2,
                  "failures": [], "poses": expected, "screenshots": ["synthetic.png"], "loop_intervals": loops}
        self.assertEqual(C.validate_report(report, "work", spec, table)['poses'], expected)
        altered = deepcopy(report)
        altered["loop_intervals"][0]["samples"][0][2] = 3  # Stored-last rather than FIRST.
        with self.assertRaisesRegex(ValueError, "REPORT_LOOPS"):
            C.validate_report(altered, "work", spec, table)
        altered = deepcopy(report)
        altered["loop_intervals"].pop()
        with self.assertRaisesRegex(ValueError, "REPORT_LOOPS"):
            C.validate_report(altered, "work", spec, table)
        altered = dict(report, poses=expected - 1)
        with self.assertRaisesRegex(ValueError, "REPORT_POSES"):
            C.validate_report(altered, "work", spec, table)

    def test_topology_requires_real_nonempty_primitive_census(self):
        spec = {"content_sha256": "a" * 64}
        report = {"content_sha256": "a" * 64, "production_qualified": False, "assertions": 10,
                  "failures": [], "parts": [{"surfaces": [{"vertex_count": 3, "indices": [0, 1, 2]}]}] * 2}
        self.assertEqual(C.validate_report(report, "topology", spec, [])['indices'], 6)
        for parts in ([], [{"surfaces": []}] * 2, [{"surfaces": [{"vertex_count": 0, "indices": []}]}] * 2):
            with self.assertRaises(ValueError):
                C.validate_report(dict(report, parts=parts), "topology", spec, [])

    def test_motion_count_cannot_succeed_with_positive_but_partial_report(self):
        spec = {"content_sha256": "a" * 64, "last_source_frame": 17}
        report = dict(tip(), poses=210, assertions=500)
        self.assertEqual(C.validate_report(report, "motion", spec, [])['poses'], 210)
        with self.assertRaisesRegex(ValueError, "REPORT_POSES"):
            C.validate_report(dict(report, poses=209), "motion", spec, [])


if __name__ == "__main__":
    unittest.main()
