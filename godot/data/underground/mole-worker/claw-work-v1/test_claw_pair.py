#!/usr/bin/env python3
"""Tests for the two-paw claw-stroke packet (ADR 1217 step 1b).

Derivation and stored-evidence tests need only committed files; the rebuild test needs the staged
`all-cast-v9.ugpal` and skips without it.

    $PY .../test_claw_pair.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import author_claw_pair as PAIR

W, SRC = PAIR.W, PAIR.SRC
EVIDENCE = SRC.HERE / "evidence"
CANDIDATES = EVIDENCE / "claw-pair-v1"
RECIPE = {"right_x_u": 224, "left_x_u": -224, "anchor_z_u": -544, "rake_u": 32, "lean_degrees": 70, "drop_u": 96,
          "tilt_degrees": 60, "right_roll_degrees": 90, "left_roll_degrees": 90, "head_lift_degrees": 60}


def proof(name: str) -> dict:
    """A stored candidate's proof record."""
    return json.loads((CANDIDATES / ("candidate-" + name) / "proof.json").read_text())


class ClawPairDerivation(unittest.TestCase):
    """Phasing and station facts."""

    def test_station_is_the_moved_in_one(self) -> None:
        """The cube's near face is 406 u ahead: 512 minus the derived 106 u inset."""
        self.assertEqual(PAIR.STATION_INSET_U, SRC.stance_inset_limit())
        self.assertEqual(PAIR.target_cube({"target": SRC.first_target()})[5], -406)

    def test_paws_run_half_a_cycle_apart_and_start_above_the_face(self) -> None:
        """Left = right shifted 16 keys; at the clip start both claws are 10 u above the face."""
        right, left = PAIR.paw_loop(RECIPE, "right"), PAIR.paw_loop(RECIPE, "left")
        self.assertEqual(len(right), W.WORK_KEYS - 1)
        for key in range(len(right)):
            other = left[(key + PAIR.HALF_CYCLE) % len(left)]
            self.assertAlmostEqual(right[key][1], other[1])
            self.assertAlmostEqual(right[key][2], other[2])
        self.assertAlmostEqual(right[0][1], 10.0)
        self.assertAlmostEqual(left[0][1], 10.0)
        self.assertLess(right[1][1], right[0][1])
        self.assertGreater(left[1][1], left[0][1])

    def test_recipe_outside_its_domain_refuses(self) -> None:
        """A head lift above 60 degrees, or crossed paws, refuse before any solve."""
        src = {"target": SRC.first_target()}
        with self.assertRaisesRegex(ValueError, "CLAW_PAIR_RECIPE_HEAD_LIFT_DEGREES"):
            PAIR.author(src, dict(RECIPE, head_lift_degrees=61))
        with self.assertRaisesRegex(ValueError, "CLAW_PAIR_RECIPE_LEFT_X_U"):
            PAIR.author(src, dict(RECIPE, left_x_u=32))


class ClawPairEvidence(unittest.TestCase):
    """The stored candidates and their exact proofs."""

    def test_candidates_clear_every_proof(self) -> None:
        """Both paws: contact on the face, below-face hull in the cube, world, both arms and arm-to-arm clear."""
        for name in ("pa", "pb"):
            result = proof(name)
            stroke, entry = result["stroke"], result["entry"]
            self.assertTrue(result["clear"], name)
            self.assertEqual(set(stroke["contact"]), {"right", "left"})
            self.assertTrue(stroke["patches_inside_cube_face"] and stroke["below_face"]["only_paw"], name)
            self.assertLess(stroke["below_face"]["bounds_u"][5], -406, name)
            self.assertTrue(entry["nothing_below_face"], name)
            for clip in (stroke, entry):
                self.assertEqual(clip["world"]["unresolved"], [], name)
                for pairing in ("right_arm_vs_rest", "left_arm_vs_rest", "right_arm_vs_left_arm"):
                    self.assertEqual(clip["self"][pairing]["unresolved"], [], (name, pairing))

    def test_stroke_admits_no_released_contact(self) -> None:
        """The stand-contact release applies to the entry only, as a prefix from the ready key."""
        for name in ("pa", "pb"):
            result = proof(name)
            self.assertEqual(result["stroke"]["self"]["left_arm_vs_rest"]["released_stand_contact"]["pairs"], 0)
            released = result["entry"]["self"]["left_arm_vs_rest"]["released_stand_contact"]
            self.assertTrue(released["is_prefix_from_ready"], name)
            self.assertEqual(result["stand_ready_contact"]["pairs"], 9)
            self.assertTrue(result["stand_ready_contact"]["clear_apart_from_contact"])

    def test_probe_record_counts(self) -> None:
        """The recorded probe's clear count matches its rows."""
        probe = json.loads((EVIDENCE / "claw-pair-probe-v1.json").read_text())
        clear = [r for r in probe["rows"] if r["solvable"] and r["lowest_non_paw_u"] >= 0 and
                 r["paw_vertices_below_face_outside_cube"] == 0]
        self.assertEqual(probe["sampled_clear"], len(clear))


@unittest.skipUnless(SRC.PALETTE.is_file(), "needs the staged all-cast-v9.ugpal")
class ClawPairRebuild(unittest.TestCase):
    """Byte-identical rebuild of the stored clips from their recipes."""

    def test_rebuild_matches_every_stored_clip(self) -> None:
        """Each candidate's three clips rebuild byte for byte."""
        src = SRC.read_claw_source()
        for name in ("pa", "pb"):
            folder = CANDIDATES / ("candidate-" + name)
            record = json.loads((folder / "candidate.json").read_text())
            cases, _ = PAIR.author(src, record["recipe"])
            for clip, case in zip(("stroke", "entry", "recovery"), cases):
                with np.load(folder / (clip + ".npz"), allow_pickle=False) as image:
                    self.assertEqual(image["matrices"].tobytes(), case["matrices"].tobytes(), (name, clip))


if __name__ == "__main__":
    unittest.main()
