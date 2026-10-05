#!/usr/bin/env python3
"""Independent native transcript adversaries; source fields cannot self-label missing or changed execution."""
import copy
import hashlib
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

import run_native as R

OUT = Path(__file__).resolve().parent/"native-4"


class NativeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.read = staticmethod(R.P.json_read)
        cls.bounded = staticmethod(R.P.bounded)
        cls.spec = cls.read(OUT/"spec.json", 65536)
        cls.report = cls.read(OUT/"report.json", 8*1024*1024)

    def report_reader(self, report):
        return lambda path, *args: report if path == OUT/"report.json" else self.read(path, *args)

    def test_actual_all_quarter_samples_and_both_bearers(self):
        result = R.validate(OUT)
        self.assertEqual(result["sampled_poses"], 5634)
        self.assertEqual(result["exact_native_scalars"], 1825416)
        self.assertEqual(result["screenshots"], 108)

    def test_interruption_direction_and_exact_terminal_are_not_optional(self):
        for name in ("reverse", "terminal", "omitted"):
            report = copy.deepcopy(self.report)
            if name == "reverse": report["events"][499]["reverse"] = False
            elif name == "terminal": report["events"][216]["frames"][1] += 1
            else: report["events"].pop()
            with self.subTest(name=name), patch.object(R.P, "json_read", side_effect=self.report_reader(report)):
                with self.assertRaisesRegex(ValueError, "NATIVE_EVENTS"): R.validate(OUT)

    def test_changed_native_body_pick_and_bearer_refuse_after_caller_rehash(self):
        for matrix in (0, 24, 26):
            raw = bytearray(self.bounded(OUT/"native.bin", 8*1024*1024))
            struct.pack_into("<f", raw, 8+matrix*12*4, 2.0)
            report = copy.deepcopy(self.report)
            report["native_sha256"] = hashlib.sha256(raw).hexdigest()
            def read(path, *args):
                return bytes(raw) if path == OUT/"native.bin" else self.bounded(path, *args)
            with self.subTest(matrix=matrix), patch.object(R.P, "bounded", side_effect=read), \
                    patch.object(R.P, "json_read", side_effect=self.report_reader(report)):
                with self.assertRaisesRegex(ValueError, "NATIVE_MATRIX"): R.validate(OUT)

    def test_self_labelled_world_permission_refuses(self):
        report = copy.deepcopy(self.report)
        report["production_qualified"] = True
        with patch.object(R.P, "json_read", side_effect=self.report_reader(report)):
            with self.assertRaisesRegex(ValueError, "NATIVE_REPORT"): R.validate(OUT)

    def test_wrong_clip_timing_refuses_after_rehash(self):
        spec = dict(self.spec)
        raw = bytearray(self.bounded(R.P.B.actual(spec["content"]), 262144))
        struct.pack_into("<I", raw, 328+8, 1) # Authored finite entry may not become a loop.
        spec["content_sha256"] = hashlib.sha256(raw).hexdigest()
        with patch.object(R.P, "bounded", return_value=bytes(raw)):
            with self.assertRaisesRegex(ValueError, "NATIVE_TIMING"): R.source_arrays(spec)

    def test_foreign_shared_ready_refuses_after_rehash(self):
        spec = dict(self.spec)
        raw = bytearray(self.bounded(R.P.B.actual(spec["content"]), 262144))
        struct.pack_into("<f", raw, 472, 2.0)
        spec["content_sha256"] = hashlib.sha256(raw).hexdigest()
        with patch.object(R.P, "bounded", return_value=bytes(raw)):
            with self.assertRaisesRegex(ValueError, "NATIVE_JOINS"): R.source_arrays(spec)

    def test_unbounded_declared_source_count_refuses_before_array_view(self):
        spec = dict(self.spec)
        raw = bytearray(self.bounded(R.P.B.actual(spec["content"]), 262144))
        struct.pack_into("<I", raw, 24, 2147483647)
        spec["content_sha256"] = hashlib.sha256(raw).hexdigest()
        with patch.object(R.P, "bounded", return_value=bytes(raw)), \
                patch.object(R.np, "frombuffer", side_effect=AssertionError("materialized")):
            with self.assertRaisesRegex(ValueError, "NATIVE_IMAGE"): R.source_arrays(spec)


if __name__ == "__main__":
    unittest.main()
