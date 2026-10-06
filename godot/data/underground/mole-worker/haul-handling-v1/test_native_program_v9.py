#!/usr/bin/env python3
"""The ten-clip native stone image (v9, ADR 1206) and its Metal replay evidence.

Run with --palette/--grip-palette (all-cast-v9, mole-grip-v3) and --capture evidence/native-program-v9.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

import compile_native_program as C
import compile_native_program_v9 as C9
import verify_native_program_v9 as V9

ARGS = None


class NativeProgramV9Tests(unittest.TestCase):
    def test_v8_outputs_are_unchanged(self):
        folder = C.HERE / "evidence/native-program-v8"
        for name, expected in C.read_json(folder / "output-sha256.json").items():
            self.assertEqual(C.digest(folder / name), expected, name)
        self.assertEqual(C.digest(folder / "compiled/haul-handling.ugactor"),
                         "cc8542712705248f944d7430cbba0b7a365860f0073473c2fc0cb9106cf97a85")

    def test_compiler_rebuilds_the_exact_v9_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = C9.compile_program(ARGS.palette, ARGS.grip_palette, Path(temporary) / "out")
            for name in ("stone-handling.ugactor", "program.json", "proof.json", "plan.json", "compilation.json"):
                self.assertEqual(C.digest(Path(temporary) / "out" / name), C.digest(ARGS.capture / "compiled" / name))
        self.assertEqual((report["clips"], report["frames"], report["wire_bytes"]), (10, 657, 791844))

    def test_stone_mesh_fingerprint_needs_exact_bits(self):
        part = C9.stone_part()
        rounded = json.loads(C9.STONE.read_text())["points"]
        lossy = dict(part, geometry=[dict(part["geometry"][0], points=np.asarray(rounded, dtype="<f4"))])
        self.assertTrue(np.array_equal(lossy["geometry"][0]["points"], part["geometry"][0]["points"]))
        self.assertNotEqual(C.I.CONTENT.geometry_fingerprint(lossy), C.I.CONTENT.geometry_fingerprint(part))
        native = C.read_json(ARGS.capture / "native-stock.json")
        self.assertEqual(native["mesh_sha256"], C.I.CONTENT.geometry_fingerprint(part).hex())

    def test_changed_clip_bytes_refuse(self):
        review = C.read_json(C9.REVIEW)
        forged = dict(review, sha256=dict(review["sha256"]))
        key = str(C9.clip_path("carry").relative_to(C.ROOT))
        forged["sha256"][key] = "0" * 64
        original = C.read_json
        with patch.object(C9.C, "read_json", side_effect=lambda path, *rest: forged if Path(path) == C9.REVIEW
                          else original(path, *rest)):
            with self.assertRaisesRegex(ValueError, "STONE_NATIVE_REVIEWED_CLIP"):
                C9.reviewed_inputs()

    def test_replay_report_and_independent_verification(self):
        stored = C.read_json(ARGS.capture / "verification.json")
        self.assertEqual(stored["coefficient_mismatches"], 0)
        self.assertEqual(stored["rows"], V9.ROWS)
        self.assertEqual(stored["joins"]["exact_joins_per_view"], 11)
        self.assertEqual(stored["stand_join"]["cross_image_stand_joins"], 3)
        self.assertGreaterEqual(min(stored["minimum_visible_floor_gap_u"].values()), 0)
        report = C.read_json(ARGS.capture / "report.json")
        self.assertEqual((report["failures"], report["rows"], report["rendering_driver"]), ([], V9.ROWS, "metal"))
        self.assertEqual(V9.verify(ARGS.capture, ARGS.palette, ARGS.grip_palette)["native_capture_sha256"],
                         stored["native_capture_sha256"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--capture", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
