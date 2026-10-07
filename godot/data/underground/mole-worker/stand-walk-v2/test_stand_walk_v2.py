#!/usr/bin/env python3
"""Tests for the corrected tool-free stand and walk (ADR 1217 / 1199 successor).

Stored-evidence tests need only committed files; the rebuild test needs the staged palettes and skips without them.

    $PY .../test_stand_walk_v2.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import author_stand_walk_v2 as V2

SRC = V2.SRC
CANDIDATE = V2.HERE / "evidence/stand-walk-v2"
GRIP = SRC.PALETTE.parent / "mole-grip-v3.ugpal"


def record() -> dict:
    """The candidate record."""
    return json.loads((CANDIDATE / "candidate.json").read_text())


def proof() -> dict:
    """The candidate's proof record."""
    return json.loads((CANDIDATE / "proof.json").read_text())


class StandWalkV2Derivation(unittest.TestCase):
    """The correction's construction."""

    def test_turn_is_a_proper_rotation(self) -> None:
        """Rodrigues turns are orthonormal with determinant one."""
        axis = np.array([0.2, -0.3, 0.9])
        axis /= np.linalg.norm(axis)
        rotation = V2.turn(axis, 7.0)
        np.testing.assert_allclose(rotation.T @ rotation, np.eye(3), atol=1e-12)
        self.assertAlmostEqual(float(np.linalg.det(rotation)), 1.0, places=12)
        np.testing.assert_allclose(rotation @ axis, axis, atol=1e-12)

    def test_search_brackets_the_chosen_degree(self) -> None:
        """Each side's degree clears, one degree less fails, 0 fails and 30 clears, all recorded."""
        data = record()
        clear = lambda row: all(v == 0 for counts in row["unresolved"].values() for v in counts.values())
        for side, chosen in data["swing_degrees"].items():
            rows = {row["degrees"]: clear(row) for row in data["search"] if row["side"] == side}
            self.assertTrue(rows[chosen])
            self.assertFalse(rows[chosen - 1])
            self.assertFalse(rows[0])
            self.assertTrue(rows[V2.MAX_DEGREES])


class StandWalkV2Evidence(unittest.TestCase):
    """The stored proofs."""

    def test_everything_clears(self) -> None:
        """Support, per-arm separation, stock separation, and the dig from the corrected ready key."""
        result = proof()
        self.assertTrue(result["clear"])
        for name, rows in result["separation"].items():
            for key, row in rows.items():
                self.assertEqual(row["unresolved"], [], (name, key))
        self.assertTrue(result["dig_pa"]["clear"])
        self.assertFalse(result["dig_pa"]["release_allowed"])

    def test_dig_needs_no_release(self) -> None:
        """The dig entry's left arm separates with the exception switched off."""
        entry = proof()["dig_pa"]["entry"]["self"]["left_arm_vs_rest"]
        self.assertEqual(entry["unresolved"], [])
        self.assertEqual(entry["released_stand_contact"]["pairs"], 0)


@unittest.skipUnless(SRC.PALETTE.is_file() and GRIP.is_file(), "needs the staged palettes")
class StandWalkV2Rebuild(unittest.TestCase):
    """Byte-identical rebuild."""

    def test_stand_and_walk_rebuild(self) -> None:
        """The stored stand and walk are the published clips swung by the recorded degrees."""
        _, _, _, _, topology, _, _, _ = V2.A.I.current_inputs(SRC.PALETTE, GRIP)
        rig = V2.A.hierarchy(topology)
        data = record()
        clips = {n: V2.load(p, loop, d) for n, (p, loop, d) in V2.PUBLISHED.items()}
        offsets = V2.offsets_of(clips["stand"], rig, {s: float(v) for s, v in data["swing_degrees"].items()})
        for name, case in clips.items():
            rebuilt = V2.swung(case, rig, offsets)
            with np.load(CANDIDATE / (name + ".npz"), allow_pickle=False) as image:
                self.assertEqual(image["matrices"].tobytes(), rebuilt["matrices"].tobytes(), name)


if __name__ == "__main__":
    unittest.main()
