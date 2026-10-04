#!/usr/bin/env python3
"""Executable counterexamples for the isolated native haul representation and replay proof."""
from __future__ import annotations

import argparse
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

import compile_native_program as C
import verify_native_program as V

ARGS = None


class NativeProgramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _, cls.body, cls.wood, _, _, _, _, _ = C.I.current_inputs(ARGS.palette, ARGS.grip_palette)
        cls.cases = C.cases_from_review(cls.body, cls.wood)
        cls.rows = V.capture(ARGS.capture / "native.bin")
        cls.pairs = C.read_json(C.HERE / "evidence/static-contact-review-v1/static-contact.json")["static_source"]["hand_contact_witnesses"]

    def test_complete_native_stock_representation_preserves_all_source_geometry(self):
        wrapped = C.wrapped_stock(self.wood)
        self.assertEqual(C.I.CONTENT.geometry_fingerprint(wrapped).hex(),
                         "cb0bf551f5439b0bea4609952c0ba43ff16d8c1bc5641743e1081e2412919cc5")
        self.assertIs(wrapped["geometry"], self.wood["geometry"])
        self.assertEqual(len(wrapped["geometry"][0]["points"]), 522)

    def test_changed_stock_point_cannot_inherit_original_geometry(self):
        measured = C.read_json(C.WRAPPER)
        measured["points"][0][0] += 0.01
        ordinary = C.read_json
        with patch.object(C, "read_json", side_effect=lambda p: measured if p == C.WRAPPER else ordinary(p)):
            with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_WRAPPER_GEOMETRY"):
                C.wrapped_stock(self.wood)

    def test_missing_or_reordered_complete_stock_triangle_refuses(self):
        measured = C.read_json(C.WRAPPER)
        measured["indices"][0], measured["indices"][1] = measured["indices"][1], measured["indices"][0]
        ordinary = C.read_json
        with patch.object(C, "read_json", side_effect=lambda p: measured if p == C.WRAPPER else ordinary(p)):
            with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_WRAPPER_GEOMETRY"):
                C.wrapped_stock(self.wood)

    def test_capture_oversize_closes_before_array_decoder(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "large.bin"
            with path.open("wb") as stream:
                stream.truncate(16 + V.ROWS * V.ROW_BYTES + 1)
            with patch.object(V.np, "frombuffer", side_effect=AssertionError("decoder entered")):
                with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_CAPTURE_CAPACITY"):
                    V.capture(path)

    def test_capture_truncation_refuses_before_array_decoder(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "short.bin"
            path.write_bytes(b"UGHNAT01")
            with patch.object(V.np, "frombuffer", side_effect=AssertionError("decoder entered")):
                with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_CAPTURE_CAPACITY"):
                    V.capture(path)

    def test_true_loop_last_interval_returns_to_first_not_unused_last_key(self):
        first = sum(C.COUNTS[:6])
        self.assertEqual(V.chosen(6, 217 * 65536 + 32768), (first + 217, first, 32768))
        self.assertEqual(V.chosen(6, 218 * 65536), (first, first + 1, 0))

    def test_invalid_clock_does_not_index_or_wrap_another_clip(self):
        for clip, elapsed in ((-1, 0), (8, 0), (0, -1), (0, 60 * 65536 + 1)):
            with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_CLOCK"):
                V.chosen(clip, elapsed)

    def test_every_native_event_has_the_exact_original_source_selection(self):
        at = 0
        for view in range(3):
            for clip, case in enumerate(self.cases):
                for elapsed in range(0, (case["frames"] - 1) * 65536 + 1, 16384):
                    row = self.rows[at]
                    V.row_refusal(row, view, clip, elapsed, case, row["values"][312:])
                    at += 1
        self.assertEqual(at, 7068)

    def test_wrong_selected_clip_is_not_a_valid_palette_sample(self):
        row = self.rows[0].copy()
        row["meta"][1] = 1
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_EVENT"):
            V.row_refusal(row, 0, 0, 0, self.cases[0], row["values"][312:])

    def test_world_root_applied_twice_is_detected(self):
        row = self.rows[0].copy()
        row["values"][309:312] += np.asarray(V.N.VIEWS[0]["root_u"]) / 1024
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_COEFFICIENT"):
            V.row_refusal(row, 0, 0, 0, self.cases[0], row["values"][312:])

    def test_native_body_palette_change_refuses(self):
        row = self.rows[0].copy()
        row["values"][19 * 12 + 9] += 0.01
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_COEFFICIENT"):
            V.row_refusal(row, 0, 0, 0, self.cases[0], row["values"][312:])

    def test_complete_native_lift_has_both_actual_triangle_contacts(self):
        row = next(r for r in self.rows if r["meta"][0] == 0 and r["meta"][1] == 1 and r["meta"][2] == 30 * 65536)
        self.assertTrue(V.hand_contacts(row["values"], self.body, self.wood, self.pairs))

    def test_shifted_stock_cannot_borrow_grip_permission(self):
        row = next(r for r in self.rows if r["meta"][1] == 4)
        values = row["values"].copy()
        values[297] += 0.5
        self.assertFalse(V.hand_contacts(values, self.body, self.wood, self.pairs))

    def test_one_departed_hand_is_not_two_hand_contact(self):
        row = next(r for r in self.rows if r["meta"][1] == 4)
        values = row["values"].copy()
        values[19 * 12 + 9] += 0.5
        self.assertFalse(V.hand_contacts(values, self.body, self.wood, self.pairs))

    def test_every_join_and_authored_reversal_has_identical_native_inputs(self):
        result = V.join_refusal(self.rows)
        self.assertEqual(result, {"exact_joins_per_view": 9, "exact_reversal_pairs_per_view": 3, "views": 3})

    def test_changed_hub_is_not_silently_blended_or_snapped(self):
        rows = self.rows.copy()
        row = next(r for r in rows if r["meta"][1] == 4 and r["meta"][2] == 0)
        row["values"][0] += 0.01
        with self.assertRaisesRegex(ValueError, "HAUL_NATIVE_JOIN"):
            V.join_refusal(rows)


def main():
    global ARGS
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "capture"):
        parser.add_argument("--" + name, type=Path, required=True)
    ARGS, remaining = parser.parse_known_args()
    unittest.main(argv=[__file__, *remaining])


if __name__ == "__main__":
    main()
