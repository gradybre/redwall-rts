#!/usr/bin/env python3
"""Tests for the tool-free stair gaits (ADR 1217 M7).

    $PY .../test_claw_stairs.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import author_claw_stairs as CS

SRC = CS.SRC
FOLDER = SRC.HERE / "evidence/claw-stairs-v1"


def load(name: str) -> dict:
    """A stored record."""
    return json.loads((FOLDER / name).read_text())


class Records(unittest.TestCase):
    """The stored candidate and proof."""

    def test_recipes_are_the_accepted_ones(self) -> None:
        """The leg recipes equal stair-descent-v7 case 0 and stair-motion-v15 case 0."""
        record = load("candidate.json")
        d, a = record["accepted_recipes"]["descent"], record["accepted_recipes"]["ascent"]
        self.assertEqual((d["root_advance_u"], d["root_drop_u"], d["leading_foot_advance_u"], d["toe_first_degrees"]),
                         (256, 128, 360, 20))
        self.assertEqual((a["lead_root_advance_u"], a["lead_root_lift_u"]), (68, 50))

    def test_swing_is_minimal(self) -> None:
        """The right arm needs 3 degrees and 2 fails; the left arm is clear at 0."""
        record = load("candidate.json")
        self.assertEqual(record["arm_swing_degrees"], {"right": 3, "left": 0})
        trail = {(row["side"], row["degrees"]): row["clear"] for row in record["swing_search"]}
        self.assertTrue(trail[("right", 3)])
        self.assertFalse(trail[("right", 2)])
        self.assertTrue(trail[("left", 0)])

    def test_every_proof_clears(self) -> None:
        """Terrain, flight, bottom (descent) and self-clearance, both gaits."""
        proof = load("proof.json")
        self.assertEqual(set(proof["descent"]), {"terrain", "flight", "bottom", "self"})
        self.assertEqual(set(proof["ascent"]), {"terrain", "flight", "self"})
        for rows in proof.values():
            for row in rows.values():
                self.assertTrue(row["clear"])

    def test_envelope_is_zero_at_the_ends(self) -> None:
        """The swing leaves both ready endpoints untouched."""
        self.assertEqual(CS.envelope(0), 0.)
        self.assertEqual(CS.envelope(CS.ASC.FRAME_COUNT - 1), 0.)
        self.assertEqual(CS.envelope(45), 1.)


@unittest.skipUnless(SRC.PALETTE.exists(), "staged palette absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """The clips rebuild byte for byte, and start and end on the ready key."""

    def test_rebuild(self) -> None:
        """Both gaits."""
        src = CS.SEAT.corrected_source()
        cases = CS.author(src, load("candidate.json")["arm_swing_degrees"])
        for gait, case in cases.items():
            with np.load(FOLDER / f"{gait}.npz", allow_pickle=False) as image:
                self.assertEqual(image["matrices"].tobytes(), case["matrices"][:, :24].tobytes())
                for end in (0, -1):
                    np.testing.assert_array_equal(image["matrices"][end], src["stand"]["matrices"][SRC.READY_FRAME])


if __name__ == "__main__":
    unittest.main()
