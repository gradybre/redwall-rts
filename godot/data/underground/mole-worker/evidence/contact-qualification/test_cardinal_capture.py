#!/usr/bin/env python3
"""Adversarial native-report checks; reconstructed reports below are deliberately synthetic tests."""
import copy
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("cardinal_native", HERE / "run_cardinal_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class CardinalNativeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles, cls.contacts, _ = R.math_inputs()
        cls.spec = {"content": str(R.M.IMAGE_DIR / "mole-worker.ugactor"), "content_sha256": R.M.IMAGE_SHA,
                    "user_directory_name": "test-only-cardinal"}
        cls.table = R.BASE.wire_timing(cls.spec)
        original = json.loads((HERE / "install-program-native-v1/report.json").read_text())
        events, counts = [], [0] * 10
        for ordinal, yaw in enumerate(R.YAWS):
            for view in ("side", "rts"):
                for event in original["events"]:
                    if not event["label"].startswith(view + "-"):
                        continue
                    row = copy.deepcopy(event)
                    role = row["profile"]
                    row.update(source_role=role, yaw=yaw, profile=role if role < 2 else 4 * ordinal + role,
                               label=view + "-yaw" + str(yaw) + row["label"][len(view):])
                    events.append(row)
                    counts[row["phase"]] += 1
        samples = []
        for profile in range(2, 18):
            contact = cls.contacts[str(profile)]
            first, last = [[R._fraction(v) for v in row] for row in contact["exact_ideal_endpoints_m"]]
            for share in range(0, 65537, 8192):
                t = Fraction(share, 65536)
                canonical = [((1 - t) * a + t * b) * 1024 for a, b in zip(first, last)]
                point = R.M.N.exact_cardinal(canonical, (profile - 2) // 4)
                samples.append({"profile": profile, "yaw": contact["yaw"], "vertex": contact["vertex"],
                                "share_q16": share, "point_u": [float(v) for v in point],
                                "frames": R.clip_frames(cls.table[2 + 3 * ((profile - 2) % 4)], contact["frame_pair"][0] * 65536 + share)})
        cls.report = dict(production_qualified=False, content_sha256=R.M.IMAGE_SHA, program_version=4,
                          failures=[], poses=len(events) + len(samples), assertions=6 * len(events),
                          events=events, phase_counts=counts, native_contacts=samples, screenshots=[{"fixture": True}],
                          user_directory="/test/" + cls.spec["user_directory_name"])

    def test_complete_synthetic_census_exercises_checker(self):
        result = R.validate_report(self.report, self.spec, self.table, self.contacts)
        self.assertEqual(result["driver_poses"], 7648)
        self.assertEqual(result["contact_poses"], 144)
        self.assertFalse(result["production_qualified"])

    def test_wrong_heading_or_role_refuses(self):
        for field, value in (("yaw", 123), ("source_role", 5), ("profile", 6)):
            row = next(copy.deepcopy(e) for e in self.report["events"] if e["profile"] == 2)
            row[field] = value
            with self.assertRaises(ValueError):
                R.event_refusal(row, self.table)

    def test_tip_count_duplicate_identity_and_source_frame_refuse(self):
        for mutation in (lambda rows: rows.pop(), lambda rows: rows.__setitem__(1, copy.deepcopy(rows[0])),
                         lambda rows: rows[0].__setitem__("vertex", 652),
                         lambda rows: rows[0].__setitem__("frames", [0, 1, 0])):
            rows = copy.deepcopy(self.report["native_contacts"])
            mutation(rows)
            with self.assertRaises(ValueError):
                R.contact_refusal(rows, self.contacts, self.table)

    def test_tip_outside_numerical_enclosure_and_nan_refuse(self):
        for value in (10000, float("nan")):
            rows = copy.deepcopy(self.report["native_contacts"])
            rows[0]["point_u"][0] = value
            with self.assertRaises(ValueError):
                R.contact_refusal(rows, self.contacts, self.table)

    def test_missing_recovery_cannot_hide_in_equal_total(self):
        record = copy.deepcopy(self.report)
        at = next(i for i, event in enumerate(record["events"]) if event["profile"] == 17 and event["phase"] == 7)
        record["events"][at] = copy.deepcopy(record["events"][0])
        with self.assertRaises(ValueError):
            R.validate_report(record, self.spec, self.table, self.contacts)

    def test_false_scope_zero_assertions_or_failed_report_refuse(self):
        for field, value in (("production_qualified", True), ("assertions", 0), ("failures", ["bad"]),
                             ("poses", 1), ("program_version", 3)):
            record = dict(self.report)
            record[field] = value
            with self.assertRaises(ValueError):
                R.validate_report(record, self.spec, self.table, self.contacts)

    def test_exact_short_final_and_actual_loop_edge(self):
        self.assertEqual(R.clip_frames((8, 4, 1, 163840), 131072), [10, 8, 0])
        self.assertEqual(R.clip_frames((8, 4, 1, 163840), 147456), [10, 8, 32768])
        self.assertEqual(R.clip_frames((8, 4, 0, 163840), 163840), [11, 11, 0])

    def test_existing_and_dangling_output_refuse_without_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            file = root / "kept"
            file.write_bytes(b"original")
            for path in (root, file):
                with self.assertRaises(ValueError):
                    R.R.output_refusal(path)
            link = root / "dangling"
            link.symlink_to(root / "missing")
            with self.assertRaises(ValueError):
                R.R.output_refusal(link)
            self.assertEqual(file.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
