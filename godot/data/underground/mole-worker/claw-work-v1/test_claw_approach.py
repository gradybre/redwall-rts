#!/usr/bin/env python3
"""Tests for the narrow claw approach/retreat derivation (ADR 1217 step 4d).

The record tests need only committed files; the role rebuild needs the staged palettes and skips without them.

    $PY .../test_claw_approach.py -v
"""
from __future__ import annotations

import json
import unittest

import author_claw_approach as A

RECORD = A.SRC.HERE / "evidence/claw-approach-v1/approach.json"
BASIS = A.SRC.PALETTE.parent / "world-yaw-v1.ugyaw"


def record() -> dict:
    """The stored derivation and proof record."""
    return json.loads(RECORD.read_text())


class ClawApproach(unittest.TestCase):
    """Rows, bearer clearance and the recorded self-clearance finding."""

    def test_rows_are_four_headings_forward_and_backward(self) -> None:
        """Eight YAW_EXACT WALK rows: READY_FORWARD then READY_BACKWARD, each turned exactly to the headings."""
        rows = record()["rows"]
        self.assertEqual([(r["selection_policy"], r["yaw"]) for r in rows],
                         [(p, y) for p in (1, 2) for y in (0, 16384, 32768, 49152)])
        self.assertEqual(rows[0]["roles"], record()["canonical_roles"])
        self.assertEqual(rows[1]["roles"]["BODY_HELD_LOAD"][0], A.N.orient_box(rows[0]["roles"]["BODY_HELD_LOAD"][0], 1))

    def test_narrow_body_is_the_fixed_heading_walk_hull(self) -> None:
        """The BODY box is the walk's own hull, far inside row 42's 712 u all-yaw sweep."""
        body = record()["canonical_roles"]["BODY_HELD_LOAD"][0]
        self.assertEqual(body, [-485, 0, -521, 479, 930, 412])
        self.assertTrue(all(abs(v) < 712 for v in (body[0], body[2], body[3], body[5])))

    def test_both_pending_bearers_are_clear(self) -> None:
        """No body triangle on any approach handoff meets either bearer over the 4,096 u span."""
        for name, proof in record()["proofs"]["bearers"].items():
            self.assertTrue(proof["clear"], name)
            self.assertEqual(proof["prism_u"], A.BEARERS[name])

    def test_self_clearance_finding_is_the_right_paw_in_the_late_stride_fade(self) -> None:
        """Every unresolved pair is right arm against the rest, fading to ready from walk keys 28-37."""
        proof = record()["proofs"]["self_clearance"]
        self.assertFalse(proof["clear"])
        self.assertEqual(proof["handoffs"], 45)
        self.assertEqual({row["pairing"] for row in proof["unresolved"]}, {"right_arm_vs_rest"})
        self.assertEqual(sorted({row["interval"][0] for row in proof["unresolved"]}), list(range(28, 38)))
        self.assertFalse(record()["clear"])

    def test_roles_rebuild(self) -> None:
        """The stored roles rebuild from the staged inputs."""
        if not A.SRC.PALETTE.is_file() or not BASIS.is_file():
            self.skipTest("staged palette and world basis are not present")
        data = A.sources(A.SRC.PALETTE, A.SRC.PALETTE.parent / "mole-grip-v3.ugpal", BASIS)
        canonical, _ = A.roles(data)
        self.assertEqual(json.loads(json.dumps(canonical)), record()["canonical_roles"])


if __name__ == "__main__":
    unittest.main()
