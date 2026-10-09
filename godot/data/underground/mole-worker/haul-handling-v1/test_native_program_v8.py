#!/usr/bin/env python3
"""Executable counterexamples for the 12-clip native haul image (v8) and its replay proof."""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

import compile_native_program_v8 as C8
import verify_native_program_v8 as V8

C, V = C8.C, V8.V
ARGS = None


class NativeProgramV8Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _, cls.body, cls.wood, _, _, _, _, _ = C.I.current_inputs(ARGS.palette, ARGS.grip_palette)
        cls.cases = C8.cases_from_sources(cls.body, C.wrapped_stock(cls.wood))
        cls.rows = V8.capture(ARGS.capture / "native.bin")
        cls.pairs = C.read_json(C.HERE / "evidence/static-contact-review-v1/static-contact.json")["static_source"]["hand_contact_witnesses"]

    def row(self, view: int, clip: int, elapsed: int):
        return next(r for r in self.rows if r["meta"][0] == view and r["meta"][1] == clip and r["meta"][2] == elapsed)

    def test_v7_executables_and_reviewed_image_are_unchanged(self):
        pins = C.read_json(C.HERE / "evidence/native-program-v7/final-source-sha256.json")
        for name, expected in pins.items():
            self.assertEqual(C.digest(C.ROOT / name), expected)
        self.assertEqual(C.digest(C.HERE / "evidence/native-program-v7/compiled/haul-handling.ugactor"),
                         "4bfa1a208dbb32d44efa2d1bc780b7bac7922d30134b26e69d8428cbf3be3056")

    def test_compiler_rebuilds_the_exact_v8_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = C8.compile_program(ARGS.palette, ARGS.grip_palette, Path(temporary) / "out")
            for name in ("haul-handling.ugactor", "program.json", "proof.json", "plan.json", "compilation.json"):
                self.assertEqual(C.digest(Path(temporary) / "out" / name), C.digest(ARGS.capture / "compiled" / name))
        self.assertEqual(report["clips"], 12)
        self.assertLessEqual(report["clips"], C.I.CONTENT.MAX_CLIPS)

    def test_the_eight_reviewed_clips_are_byte_identical_to_v7(self):
        reviewed = C.cases_from_review(self.body, C.wrapped_stock(self.wood))
        for old, new in zip(reviewed, self.cases[:8]):
            self.assertTrue(np.array_equal(old["matrices"], new["matrices"]))
            self.assertTrue(np.array_equal(old["grounding"], new["grounding"]))

    def test_tool_free_body_columns_are_the_pinned_source_and_hidden_stock_is_the_fixture(self):
        fixture = self.cases[0]["matrices"][0, 24]
        for name in C8.TOOL_FREE:
            raw = C8.clip_path(name).read_bytes()
            with np.load(io.BytesIO(raw), allow_pickle=False) as image:
                source = image["matrices"]
            case = self.cases[C8.CLIPS.index(name)]
            self.assertTrue(np.array_equal(case["matrices"][:, :24], source[:, :24]))
            self.assertTrue(np.array_equal(case["matrices"][:, 24], np.broadcast_to(fixture, (case["frames"], 12))))
        self.assertEqual([C8.MASKS[C8.CLIPS.index(n)] for n in C8.TOOL_FREE], [1, 1, 3, 3])

    def test_changed_tool_free_source_bytes_refuse(self):
        with patch.dict(C8.EMPTY_SHA, {"walk": "0" * 64}):
            with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_V8_EMPTY_CLIP"):
                C8.load_empty_case("walk", 45, 1)

    def test_capture_oversize_closes_before_array_decoder(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "large.bin"
            with path.open("wb") as stream:
                stream.truncate(16 + V8.ROWS * V8.ROW_BYTES + 1)
            with patch.object(V8.np, "frombuffer", side_effect=AssertionError("decoder entered")):
                with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_CAPTURE_CAPACITY"):
                    V8.capture(path)

    def test_true_loop_wraps_return_to_first_key(self):
        for clip in (6, V8.STAND, V8.WALK):
            first, count = sum(V8.COUNTS[:clip]), V8.COUNTS[clip]
            self.assertEqual(V8.chosen(clip, (count - 2) * 65536 + 32768), (first + count - 2, first, 32768))
            self.assertEqual(V8.chosen(clip, (count - 1) * 65536), (first, first + 1, 0))

    def test_one_shot_join_reaches_its_final_key(self):
        first, count = sum(V8.COUNTS[:V8.ENTER_HAUL]), V8.COUNTS[V8.ENTER_HAUL]
        self.assertEqual(V8.chosen(V8.ENTER_HAUL, (count - 1) * 65536), (first + count - 1, first + count - 1, 0))

    def test_invalid_clock_does_not_index_another_clip(self):
        for clip, elapsed in ((-1, 0), (12, 0), (V8.WALK, -1), (V8.WALK, 44 * 65536 + 1)):
            with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_CLOCK"):
                V8.chosen(clip, elapsed)

    def test_every_native_event_has_exact_source_selection_and_visibility(self):
        at = 0
        for view in range(3):
            for clip, case in enumerate(self.cases):
                for elapsed in range(0, (case["frames"] - 1) * 65536 + 1, 16384):
                    row = self.rows[at]
                    V8.row_refusal(row, view, clip, elapsed, case, row["values"][312:])
                    at += 1
        self.assertEqual(at, 9780)

    def test_visible_stock_during_tool_free_walk_refuses(self):
        row = self.row(0, V8.WALK, 0).copy()
        row["meta"][7] = 3
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_EVENT"):
            V8.row_refusal(row, 0, V8.WALK, 0, self.cases[V8.WALK], row["values"][312:])

    def test_hidden_stock_coefficient_is_still_exact(self):
        row = self.row(1, V8.STAND, 65536).copy()
        row["values"][297] += 0.01
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_COEFFICIENT"):
            V8.row_refusal(row, 1, V8.STAND, 65536, self.cases[V8.STAND], row["values"][312:])

    def test_world_root_applied_twice_on_walk_is_detected(self):
        row = self.row(2, V8.WALK, 16384).copy()
        row["values"][309:312] += np.asarray(V8.N.VIEWS[2]["root_u"]) / 1024
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_COEFFICIENT"):
            V8.row_refusal(row, 2, V8.WALK, 16384, self.cases[V8.WALK], row["values"][312:])

    def test_complete_native_lift_still_has_both_actual_triangle_contacts(self):
        self.assertTrue(V.hand_contacts(self.row(0, 1, 30 * 65536)["values"], self.body, self.wood, self.pairs))

    def test_every_join_and_reversal_has_identical_native_inputs(self):
        self.assertEqual(V8.join_refusal(self.rows),
                         {"exact_joins_per_view": 13, "exact_reversal_pairs_per_view": 4, "views": 3})

    def test_changed_stand_ready_key_breaks_the_tool_free_join(self):
        rows = self.rows.copy()
        row = next(r for r in rows if r["meta"][1] == V8.STAND and r["meta"][2] == V8.READY * 65536)
        row["values"][0] += 0.01
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_JOIN"):
            V8.join_refusal(rows)

    def test_wire_census_matches_loader_declarations(self):
        wire = (ARGS.capture / "compiled/haul-handling.ugactor").read_bytes()
        self.assertEqual(len(wire), 184 + 2 * 72 + 12 * 48 + 824 * 301 * 4 + 8)
        self.assertEqual(hashlib.sha256(wire).hexdigest(), C.read_json(ARGS.capture / "report.json")["content_sha256"])


def main():
    global ARGS
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "capture"):
        parser.add_argument("--" + name, type=Path, required=True)
    ARGS, remaining = parser.parse_known_args()
    unittest.main(argv=[__file__, *remaining])


if __name__ == "__main__":
    main()
