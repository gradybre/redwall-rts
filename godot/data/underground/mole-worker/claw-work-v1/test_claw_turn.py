#!/usr/bin/env python3
"""Tests for the tool-free half-turn and the step forward on a tread (ADR 1209 step 5).

    $PY .../test_claw_turn.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import author_claw_turn as TURN
import prove_tread_step_forward as FORWARD

SRC = TURN.SRC
TURN_DIR = SRC.HERE / "evidence/claw-turn-v1"
FORWARD_DIR = SRC.HERE / "evidence/tread-step-forward-v1"


class TurnRecord(unittest.TestCase):
    """The stored turn."""

    def test_candidate_6_controls(self) -> None:
        """The turn keeps candidate 6's controls: 169 to 343 u behind the far edge, yaw 0 to 32768, 271 keys."""
        record = json.loads((TURN_DIR / "candidate.json").read_text())
        self.assertEqual(record["keys"], 271)
        self.assertEqual(record["controls_u"][0], [0, -128, -2391])
        self.assertEqual(record["controls_u"][-1], [0, -128, -2217])
        self.assertEqual((record["heading_controls"][0], record["heading_controls"][-1]), (0, 32768))
        self.assertEqual(record["author_sha256"], TURN.AH_SHA)
        self.assertEqual(record["arm_swing_degrees"], {"right": 0})

    def test_every_tread_clears(self) -> None:
        """Self-clearance and the handoff prover on T0...T5."""
        proof = json.loads((TURN_DIR / "proof.json").read_text())
        self.assertTrue(proof["self"]["clear"])
        for m in TURN.TREADS:
            self.assertTrue(proof[f"T{m}"]["clear"], m)
            self.assertEqual(proof[f"T{m}"]["unresolved"], [])

    def test_fixture_puts_the_standing_deck_at_t0(self) -> None:
        """Translated by m pitches, the standing tread's deck is index 7 at T0's coordinates."""
        for m in TURN.TREADS:
            ground = TURN.fixture(m)
            self.assertEqual(ground["solids_u"][7], [-1024, -192, -2560, 1024, -128, -2048])
            self.assertEqual(ground["shift_u"], [0, 128 * m, 512 * m])


class ForwardRecord(unittest.TestCase):
    """The stored step forward."""

    def test_clear_with_the_next_tread(self) -> None:
        """Walk keys 0, 1, 2; clear; the fitted next tread is in the fixture."""
        record = json.loads((FORWARD_DIR / "step_forward.json").read_text())
        self.assertTrue(record["clear"])
        self.assertEqual(record["walk_keys"], [0, 1, 2])
        self.assertEqual(record["fixture"]["labels"][-1], FORWARD.NEXT_TREAD_LABEL)
        self.assertEqual(record["fixture"]["solids_u"][-1], [-1024, -896, -822, 1024, -128, -310])


@unittest.skipUnless(SRC.PALETTE.exists(), "staged palette absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """Byte-for-byte rebuilds."""

    def test_turn(self) -> None:
        """The turn clip, endpoints on the ready key."""
        src = TURN.SEAT.corrected_source()
        table, _ = TURN.AH.read_basis()
        case = TURN.author(src, table, {"right": 0})
        with np.load(TURN_DIR / "turn.npz", allow_pickle=False) as image:
            self.assertEqual(image["matrices"].tobytes(), case["matrices"][:, :24].tobytes())


if __name__ == "__main__":
    unittest.main()
