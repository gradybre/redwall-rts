#!/usr/bin/env python3
"""Exact interval counterexamples and actual-mesh handling regressions; no native qualification."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

import author_handling as A
import author_program as AUTHOR
import prove_program as P
import prove_static_contact as S
import render_candidate as R

INPUTS = None
CANDIDATE = A.I.HERE / "evidence/handling-program-v1"
WOOD = A.I.HERE / "evidence/wood-topology-v1.json"


def copy_case(case: dict) -> dict:
    return {key: value.copy() if isinstance(value, np.ndarray) else value for key, value in case.items()}


class ExactIntervalTests(unittest.TestCase):
    def test_quadratic_endpoints_do_not_prove_interior(self):
        self.assertFalse(P.polynomial_nonnegative((F(3, 16), -F(1), F(1))))
        self.assertTrue(P.polynomial_nonnegative((F(1, 4), -F(1), F(1))))
        self.assertFalse(P.polynomial_nonnegative((F(0), F(-1), F(0))))

    def test_translating_true_contact_is_continuous(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        first = [(F(1, 2), F(1, 2), F(1)), (F(1, 2), F(1, 2), F(-1)), (F(0), F(0), F(2))]
        translate = lambda points: [tuple(v + d for v, d in zip(point, (F(5), F(-3), F(7)))) for point in points]
        self.assertTrue(P.interval_contact(first, translate(first), stock, translate(stock), (0, 1)))
        self.assertTrue(P.interval_contact(translate(first), first, translate(stock), stock, (0, 1)))

    def test_both_endpoint_contacts_can_leave_triangle_in_between(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        first = [(F(0), F(1, 4), F(1)), (F(6), F(1, 4), F(-4)), (F(-1), F(1, 4), F(2))]
        last = [(F(6), F(1, 4), F(4)), (F(0), F(1, 4), F(-1)), (F(-1), F(1, 4), F(2))]
        self.assertIsNotNone(S.edge_witness(first, stock))
        self.assertIsNotNone(S.edge_witness(last, stock))
        # The tracked edge meets x=6/5 at both endpoints but x=3 at t=1/2, outside x+y<=2.
        self.assertFalse(P.interval_contact(first, last, stock, stock, (0, 1)))

    def test_rotated_or_degenerate_stock_is_not_a_translation_certificate(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        hand = [(F(1, 2), F(1, 2), F(1)), (F(1, 2), F(1, 2), F(-1)), (F(0), F(0), F(2))]
        rotated = [stock[0], stock[2], stock[1]]
        self.assertFalse(P.interval_contact(hand, hand, stock, rotated, (0, 1)))
        self.assertFalse(P.interval_contact(hand, hand, [stock[0]] * 3, [stock[0]] * 3, (0, 1)))


class ActualProgramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.body, cls.wood, _, cls.topology, cls.compact, _, _ = A.I.current_inputs(*INPUTS)
        cls.body_tri = np.asarray(cls.topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
        cls.wood_tri = R.wood_topology(WOOD, cls.wood)
        accepted = A.I.HERE / "evidence/static-contact-review-v1"
        cls.pairs = json.loads((accepted / "static-contact.json").read_text())["static_source"]["hand_contact_witnesses"]
        cls.cases = {name: P.load_case(CANDIDATE / (name + ".npz")) for name in ("approach", "lift", "place", "recovery")}
        cls.reports = {name: cls.prove(case, name in ("lift", "place")) for name, case in cls.cases.items()}

    @classmethod
    def prove(cls, case: dict, grip: bool) -> dict:
        return P.prove(case, cls.body, cls.wood, cls.body_tri, cls.wood_tri,
                       cls.topology["rig_binding"], cls.pairs, grip)

    def test_all_four_complete_source_transitions_pass(self):
        for name, report in self.reports.items():
            self.assertTrue(report["all_intervals_complete"], name)
            self.assertTrue(report["non_grip_separation"], name)
            self.assertEqual(report["initial_contained_vertices"], [], name)
            self.assertEqual(report["floor_penetrations"], [], name)
            self.assertTrue(report["supported_feet"], name)
            self.assertEqual(report["body_triangles"], 10209)
            self.assertEqual(report["non_grip_triangles"], 9283)
            self.assertEqual(report["intentional_grip_triangles"], [478, 448])
            self.assertEqual(report["stock_triangles"], 768)
            self.assertEqual(len(report["intervals"]), 60)
        self.assertTrue(self.reports["lift"]["continuous_two_hand_contact"])
        self.assertTrue(self.reports["place"]["continuous_two_hand_contact"])

    def test_reviewed_static_pickup_and_setdown_are_exact_joins(self):
        with np.load(AUTHOR.STATIC / "poses.npz", allow_pickle=False) as static:
            for name, at in (("approach", -1), ("lift", 0), ("place", -1), ("recovery", 0)):
                np.testing.assert_array_equal(self.cases[name]["matrices"][at], static["matrices"][1])
                self.assertEqual(self.cases[name]["grounding"][at], static["grounding"][1])
        for first, last in (("approach", "lift"), ("place", "recovery")):
            np.testing.assert_array_equal(self.cases[first]["matrices"][-1], self.cases[last]["matrices"][0])

    def test_loaded_hub_repost_and_empty_recovery_body_joins_are_exact(self):
        lift, place, approach, recovery = [self.cases[name] for name in ("lift", "place", "approach", "recovery")]
        np.testing.assert_array_equal(lift["matrices"][-1], place["matrices"][0])
        np.testing.assert_array_equal(lift["matrices"][-1, :24], approach["matrices"][0, :24])
        np.testing.assert_array_equal(lift["matrices"][-1, :24], recovery["matrices"][-1, :24])
        np.testing.assert_array_equal(place["matrices"], lift["matrices"][::-1])
        np.testing.assert_array_equal(recovery["matrices"], approach["matrices"][::-1])
        # This is a source join only. No repost creates another pickup and no partial quantity is inferred here.
        self.assertFalse(json.loads((CANDIDATE / "candidate.json").read_text())["production_qualified"])

    def test_every_authored_joint_key_retains_original_lengths(self):
        parents, _, inverse_inverse = A.hierarchy(self.topology)
        reference = A.globals_at(self.compact[0], 8, inverse_inverse)
        lengths = [0. if parent < 0 else np.linalg.norm(reference[at][:3, 3] - reference[parent][:3, 3])
                   for at, parent in enumerate(parents)]
        for frame in range(self.cases["lift"]["frames"]):
            posed = A.globals_at(self.cases["lift"], frame, inverse_inverse)
            for at, parent in enumerate(parents):
                if parent >= 0:
                    length = np.linalg.norm(posed[at][:3, 3] - posed[parent][:3, 3])
                    self.assertLess(abs(length - lengths[at]), 1e-6, f"{frame}/{at}")

    def test_late_hand_departure_loses_continuous_contact(self):
        changed = copy_case(self.cases["lift"])
        changed["matrices"][30, 15, 9] += 1 / 4
        self.assertFalse(P.contact_proof(changed, self.body, self.wood, self.body_tri, self.wood_tri, self.pairs[0], 29))
        self.assertFalse(P.contact_proof(changed, self.body, self.wood, self.body_tri, self.wood_tri, self.pairs[0], 30))
        self.assertTrue(P.contact_proof(self.cases["lift"], self.body, self.wood, self.body_tri, self.wood_tri, self.pairs[0], 29))

    def test_stock_crossing_body_between_clear_endpoints_refuses(self):
        original = self.cases["lift"]
        changed = {**original, "frames": 2, "matrices": np.repeat(original["matrices"][-1:], 2, axis=0),
                   "grounding": np.repeat(original["grounding"][-1:], 2, axis=0)}
        changed["matrices"][:, 24, 11] = [-1., 1.]
        for frame in (0, 1):
            report = S.prove(P.at_frame(changed, frame), self.body, self.wood, self.body_tri, self.wood_tri,
                             self.topology["rig_binding"])
            self.assertTrue(report["non_grip_separation"])
        report = self.prove(changed, False)
        self.assertFalse(report["non_grip_separation"])
        self.assertGreater(len(report["unresolved"]), 0)
        self.assertFalse(report["all_intervals_complete"])

    def test_lowered_mid_key_cannot_hide_floor_penetration(self):
        original = self.cases["lift"]
        changed = {**original, "frames": 2, "matrices": original["matrices"][29:31].copy(),
                   "grounding": original["grounding"][29:31].copy()}
        changed["grounding"][1] -= 1 / 1024
        report = self.prove(changed, False)
        self.assertTrue(report["floor_penetrations"])
        self.assertFalse(report["supported_feet"])

    def test_rotating_stock_image_refuses_before_proof(self):
        changed = copy_case(self.cases["lift"])
        changed["matrices"][30, 24, 0] += 1 / 1024
        with tempfile.TemporaryDirectory(prefix="haul-program-negative-") as folder:
            path = Path(folder) / "changed.npz"
            AUTHOR.write_case(path, changed)
            with self.assertRaisesRegex(ValueError, "HANDLING_PROGRAM_STOCK_ROTATION"):
                P.load_case(path)

    def test_all_reviewed_static_source_files_remain_unchanged(self):
        manifest = json.loads((A.I.HERE / "evidence/static-contact-review-v1/source-sha256.json").read_text())
        # The checked-in manifest uses source paths as keys; every original source is independently rehashed.
        pins = manifest.get("source_sha256", manifest)
        for relative, expected in pins.items():
            self.assertEqual(hashlib.sha256((A.I.ROOT / relative).read_bytes()).hexdigest(), expected, relative)


def main() -> None:
    global INPUTS, CANDIDATE, WOOD
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE)
    parser.add_argument("--wood-topology", type=Path, default=WOOD)
    args = parser.parse_args()
    INPUTS, CANDIDATE, WOOD = (args.palette, args.grip_palette), args.candidate, args.wood_topology
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(kind)
                               for kind in (ExactIntervalTests, ActualProgramTests)])
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if outcome.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
