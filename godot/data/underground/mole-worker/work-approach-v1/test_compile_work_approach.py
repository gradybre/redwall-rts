#!/usr/bin/env python3
"""Bounded source-clock and complete join regressions; no fabricated geometry qualification."""
import copy
from fractions import Fraction
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("work_approach", Path(__file__).with_name("compile_work_approach.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


def case(count, duration, loop=1):
    """Supply exact finite timing and byte-comparable palettes for algorithm counterexamples only."""
    return {"frames": count, "source_loop_mode": loop,
            "source_duration_s": Fraction(duration, 30 * M.ONE), "duration_q16": duration,
            "matrices": np.zeros((count, 1, 12), dtype=np.float32),
            "grounding": np.zeros(count, dtype=np.float32)}


class SourceContractTests(unittest.TestCase):
    def test_short_loop_seam_is_not_uniform_frame_reversal(self):
        d = 2097153
        self.assertEqual(M.sample_interval(34, d, 0, True), [0, 1, 0])
        self.assertEqual(M.sample_interval(34, d, 1, True), [32, 0, 0])
        self.assertEqual(M.sample_interval(34, d, 2, True), [31, 32, 65535])
        self.assertEqual(M.sample_interval(34, d, d - 1), [32, 0, 0])
        self.assertEqual(M.sample_interval(34, d, d), [0, 1, 0])

    def test_reverse_uses_identical_source_phase_at_every_boundary_and_fraction(self):
        d = 2097153
        samples = {0, 1, 2, d - 2, d - 1, d, d + 1}
        for frame in range(33):
            for share in (0, 1, 16384, 32768, 49152, 65535):
                samples.add(frame * M.ONE + share)
        for q in sorted(samples):
            with self.subTest(q=q):
                self.assertEqual(M.sample_interval(34, d, q, True),
                                 M.sample_interval(34, d, (d - q % d) % d))

    def test_all_33_intervals_survive_in_both_directions(self):
        row = M.interval_contract(case(34, 2097153))
        self.assertEqual(len(row["forward"]), 33)
        self.assertEqual(len(row["backward"]), 33)
        self.assertEqual(row["backward"][0], {"a": 0, "b": 32, "from_q16": 0, "to_q16": 1})
        for direction in ("forward", "backward"):
            cursor = 0
            for interval in row[direction]:
                self.assertEqual(interval["from_q16"], cursor)
                self.assertGreater(interval["to_q16"], cursor)
                cursor = interval["to_q16"]
            self.assertEqual(cursor, 2097153)

    def test_bad_or_overflowed_timing_refuses(self):
        invalid = [(True, 2097153, 0, False), (34, 0, 0, False), (34, 2097153, -1, False),
                   (34, 2097153, 1 << 31, False), (34, 2097153, 0, 1),
                   (2049, 2097153, 0, False), (34, 32 * M.ONE, 0, False)]
        for values in invalid:
            with self.subTest(values=values), self.assertRaises(ValueError):
                M.sample_interval(*values)
        for timing in (case(34, 33 * M.ONE), case(34, 2097153, 0), case(33, 32 * M.ONE)):
            with self.assertRaises(ValueError):
                M.interval_contract(timing)

    def test_every_emittable_walk_ready_simplex_is_required(self):
        cases = [case(122, 121 * M.ONE), case(34, 2097153)]
        expected = M.C.H.handoff_sets(cases)
        proof = {"carry_handoffs": {"checked": copy.deepcopy(expected)}}
        result = M.selected_handoffs(cases, proof)
        self.assertEqual(len(result), 34)
        self.assertNotIn("idle", {row["from"] for row in result})
        selected = [index for index, row in enumerate(expected) if row["from"] in ("ready", "walk")]
        for index in selected:
            bad = copy.deepcopy(proof)
            del bad["carry_handoffs"]["checked"][index]
            with self.subTest(missing=index), self.assertRaises(ValueError):
                M.selected_handoffs(cases, bad)
        bad = copy.deepcopy(proof)
        bad["carry_handoffs"]["checked"].append(copy.deepcopy(expected[-1]))
        with self.assertRaises(ValueError):
            M.selected_handoffs(cases, bad)

    def test_work_joins_require_grounding_and_palette_at_all_four_boundaries(self):
        cases = [case(10, 9 * M.ONE) for _ in range(14)]
        self.assertEqual(len(M.work_joins(cases)), 4)
        for work in (2, 5, 8, 11):
            for clip, frame in ((work + 1, 0), (work + 1, 9), (work + 2, 0), (work + 2, 9)):
                for key in ("matrices", "grounding"):
                    bad = copy.deepcopy(cases)
                    bad[clip][key][frame] = 1
                    with self.subTest(clip=clip, frame=frame, key=key), self.assertRaises(ValueError):
                        M.work_joins(bad)

    def test_joint_census_includes_both_banks_and_existing_owners(self):
        result = M.retained_census()
        self.assertEqual(result["profile_count"], 26)
        self.assertEqual(result["box_count"], 250)
        self.assertEqual(result["terms"]["paired_profiles"], 2 * (98 * 26 + 28 * 250 + 64))
        self.assertEqual(sum(result["terms"].values()), 238676)
        self.assertEqual(result["remaining"], 23468)
        self.assertFalse(result["native_measured"])
        self.assertEqual(result["actor_image_delta"], 0)


if __name__ == "__main__":
    unittest.main()
