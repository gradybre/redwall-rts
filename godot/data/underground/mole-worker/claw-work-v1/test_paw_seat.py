#!/usr/bin/env python3
"""Tests for the paw handling/seating packet (ADR 1217 step 2).

Derivation and stored-evidence tests need only committed files; the rebuild test needs the staged palette and
skips without it.

    $PY .../test_paw_seat.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import author_paw_seat as SEAT

SRC = SEAT.SRC
CANDIDATE = SRC.HERE / "evidence/paw-seat-v1/candidate-a"


def proof() -> dict:
    """The stored proof record."""
    return json.loads((CANDIDATE / "proof.json").read_text())


class PawSeatDerivation(unittest.TestCase):
    """Published numbers the motion is built on."""

    def test_tap_heights_follow_the_accepted_tap(self) -> None:
        """33 keys, from 80 u above the top to 2 u below it at key 16, mirrored."""
        heights = SEAT.tap_heights()
        self.assertEqual(len(heights), 33)
        self.assertAlmostEqual(heights[0], 208.0)
        self.assertAlmostEqual(heights[16], 126.0)
        self.assertEqual(heights, heights[::-1])

    def test_contacts_mirror_row_16_on_both_bearers(self) -> None:
        """The right contact is row 16's point; both lie on both bearers' common section."""
        self.assertEqual(SEAT.CONTACT["right"].tolist(), [128.0, 128.0, -448.0])
        self.assertEqual(SEAT.CONTACT["left"].tolist(), [-128.0, 128.0, -448.0])
        for point in SEAT.CONTACT.values():
            self.assertTrue(SEAT.SECTION[0] < point[0] < SEAT.SECTION[3] and SEAT.SECTION[2] < point[2] < SEAT.SECTION[5])

    def test_entry_path_ends_on_the_work_point(self) -> None:
        """`approach` starts at the hanging point, peaks above the work point, and ends on it."""
        start, finish = np.array([10., 20., 30.]), np.array([100., 50., -400.])
        np.testing.assert_allclose(SEAT.approach(start, finish, 0.0, 128.), start)
        np.testing.assert_allclose(SEAT.approach(start, finish, SEAT.RAISE_SHARE, 128.), finish + [0., 128., 0.])
        np.testing.assert_allclose(SEAT.approach(start, finish, 1.0, 128.), finish)


class PawSeatEvidence(unittest.TestCase):
    """The stored proof."""

    def test_everything_clears_on_both_installations(self) -> None:
        """Seat and tap, work and entry, both installations, with no exception."""
        result = proof()
        self.assertTrue(result["clear"])
        for name in ("seat", "tap"):
            for part in ("work", "entry"):
                row = result[name][part]
                self.assertTrue(row["self"]["clear"], (name, part))
                for key, world in row["world"].items():
                    self.assertEqual(world["unresolved"], [], (name, part, key))

    def test_tap_contacts_are_the_anchors(self) -> None:
        """Each palm vertex crosses the top at its anchor, with a patch on both bearers."""
        tap = proof()["tap"]
        self.assertEqual(tap["contact"]["right"]["anchor_u"], [128, 128, -448])
        self.assertEqual(tap["contact"]["left"]["anchor_u"], [-128, 128, -448])
        self.assertTrue(tap["patches_on_both_bearers"])


@unittest.skipUnless(SRC.PALETTE.is_file(), "needs the staged all-cast-v9.ugpal")
class PawSeatRebuild(unittest.TestCase):
    """Byte-identical rebuild."""

    def test_rebuild_matches_every_stored_clip(self) -> None:
        """All six clips rebuild byte for byte from the recipe."""
        record = json.loads((CANDIDATE / "candidate.json").read_text())
        programs = SEAT.author(SEAT.corrected_source(), record["recipe"])
        for name, cases in programs.items():
            for part, case in zip(("work", "entry", "recovery"), cases):
                with np.load(CANDIDATE / f"{name}_{part}.npz", allow_pickle=False) as image:
                    self.assertEqual(image["matrices"].tobytes(), case["matrices"].tobytes(), (name, part))


if __name__ == "__main__":
    unittest.main()
