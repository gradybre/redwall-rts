#!/usr/bin/env python3
"""Tests for the one claw stroke at a wall (decision 1971): the derived wall rows and their world proof.

The record tests need only committed files; the rebuild tests need the staged palettes and world basis and skip
without them.

    $PY .../test_claw_wall.py -v
"""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

import derive_claw_wall_rows as D
import prove_claw_wall as W

ROWS = D.SRC.HERE / "evidence/claw-wall-rows-v1/rows.json"
PROOF = D.SRC.HERE / "evidence/claw-wall-proof-v1/proof.json"
BASIS = D.SRC.PALETTE.parent / "world-yaw-v1.ugyaw"
GRIP = D.SRC.PALETTE.parent / "mole-grip-v3.ugpal"
TOP_FACE = json.loads((D.SRC.HERE / "evidence/claw-rows-v1/rows.json").read_text())["rows"][0]["canonical_roles"]


def staged() -> bool:
    """Whether the pinned palettes and basis are staged."""
    return D.SRC.PALETTE.is_file() and GRIP.is_file() and BASIS.is_file()


class WallRows(unittest.TestCase):
    """The rows are M1's own boxes with the entry's paws as stroke and the contact on the wall plane."""

    def setUp(self) -> None:
        self.record = json.loads(ROWS.read_text())
        self.roles = self.record["rows"][0]["canonical_roles"]

    def test_wall_is_the_travel_rows_reach(self) -> None:
        """W = 521 u: the narrow approach/retreat body, ahead of the row's own 466 u recovery body."""
        self.assertEqual(self.record["wall_distance_u"], 521)
        self.assertEqual(D.travel_reach(), 521)
        own = max(-b[2] for r, boxes in self.roles.items() if r in ("BODY_HELD_LOAD", "TURN_RECOVERY",
                                                                   "WORK_APPROACH", "STANCE_SUPPORT") for b in boxes)
        self.assertEqual(own, 466)

    def test_only_paws_move_into_the_stroke(self) -> None:
        """Body, stance and approach equal M1's top-face row; the stroke gains the entry's paws, recovery loses them."""
        for role in ("BODY_HELD_LOAD", "STANCE_SUPPORT", "WORK_APPROACH"):
            self.assertEqual(self.roles[role], TOP_FACE[role], role)
        self.assertEqual(self.roles["WORK_STROKE"][:2], TOP_FACE["WORK_STROKE"])
        self.assertEqual(self.roles["WORK_STROKE"][2], [-478, 9, -597, 415, 507, 188])
        self.assertEqual(self.roles["TURN_RECOVERY"][0], [-370, 0, -466, 361, 840, 238])
        self.assertTrue(D.C.union([self.roles["TURN_RECOVERY"][0], self.roles["WORK_STROKE"][2]])[2] <=
                        TOP_FACE["TURN_RECOVERY"][0][2])

    def test_contact_on_the_wall_plane(self) -> None:
        """Every heading's anchor and patch lie on forward = W, inside the floor band, the stroke containing it."""
        for row in self.record["rows"]:
            canonical = row["canonical_roles"]
            point, patch = canonical["CONTACT_POINT"][0], canonical["CONTACT_PATCH"][0]
            self.assertEqual((point[2], patch[2], patch[5]), (-521, -521, -521))
            self.assertTrue(0 < point[1] < 1024 and patch[0] < patch[3] and patch[1] < patch[4])
            self.assertEqual(sum(map(len, row["roles"].values())), 12)

    def test_quarter_turns(self) -> None:
        """Each heading's boxes are the exact quarter turn of the canonical ones."""
        for heading, row in enumerate(self.record["rows"]):
            self.assertEqual(row["yaw"], 16384 * heading)
            for role, boxes in row["roles"].items():
                self.assertEqual(boxes, [D.N.orient_box(b, heading) for b in row["canonical_roles"][role]], role)

    def test_short_wall_refused(self) -> None:
        """A stroke that never reaches past the non-stroke boxes refuses instead of inventing a contact."""
        roles = {"BODY_HELD_LOAD": [[0, 0, -700, 1, 1, 0]], "WORK_STROKE": [[0, 0, -600, 1, 1, 0]]}
        with self.assertRaises(ValueError):
            D.wall_distance(roles)

    def test_rebuild_is_identical(self) -> None:
        """The stored record rebuilds exactly from the staged inputs."""
        if not staged():
            self.skipTest("staged palette and world basis are not present")
        result = D.derive(D.SRC.PALETTE, GRIP, BASIS)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "rows.json"
            path.write_text(json.dumps(result, indent=1, default=str) + "\n")
            rebuilt = json.loads(path.read_text())
        for key in ("rows", "wall_distance_u", "travel_reach_u", "image_record", "content_10_wire_sha256"):
            self.assertEqual(rebuilt[key], self.record[key], key)


class WallProof(unittest.TestCase):
    """The world proof admits paws in the target and a bounded floor scrape, nothing else."""

    def test_record_clear(self) -> None:
        """Stroke and entry, bottom and column quanta: no unresolved pair; the scrape is used by the stroke only."""
        proof = json.loads(PROOF.read_text())
        self.assertTrue(proof["clear"])
        self.assertEqual(proof["rows_sha256"], D.SRC.sha(ROWS))
        for clip in W.CLIPS:
            for mode in ("bottom", "column"):
                self.assertEqual(proof[clip][mode]["unresolved"], [])
        self.assertGreater(proof["dig_stroke"]["bottom"]["paw_scrape"], 0)
        self.assertEqual(proof["dig_entry"]["bottom"]["paw_scrape"], 0)
        self.assertEqual(proof["dig_stroke"]["column"]["paw_target"], 0)

    def test_fixture_centres_the_stroke(self) -> None:
        """The target holds the whole stroke box laterally; the neighbours meet at its edges."""
        ground = W.fixture(json.loads(ROWS.read_text())["rows"][0], 521)
        target, left, right = ground["solids_u"][2], ground["solids_u"][3], ground["solids_u"][4]
        self.assertEqual(target[3] - target[0], 1024)
        self.assertTrue(target[0] <= -478 and 415 <= target[3])
        self.assertEqual((left[3], right[0]), (target[0], target[3]))
        self.assertEqual(ground["scrape_u"], [[-226, -61, -561, 287, 0, -415]])

    def test_scrape_is_bounded_by_the_stroke_box(self) -> None:
        """A triangle's below-plane part inside the box scrapes; one reaching past it does not."""
        low = np.zeros((2, 3, 3), dtype=np.int64)
        high = np.zeros((2, 3, 3), dtype=np.int64)
        low[:, :, 2] = high[:, :, 2] = -500 * W.Q
        low[:, 0, 1] = high[:, 0, 1] = -40 * W.Q
        low[:, 1, 1] = high[:, 1, 1] = 50 * W.Q
        low[:, 2, 0] = high[:, 2, 0] = 10 * W.Q
        triangle = np.array([0, 1, 2], dtype=np.int64)
        self.assertTrue(W.scraped(low, high, triangle, [-226, -61, -561, 287, 0, -415]))
        low[:, 0, 1] = high[:, 0, 1] = -80 * W.Q
        self.assertFalse(W.scraped(low, high, triangle, [-226, -61, -561, 287, 0, -415]))

    def test_rebuild_is_identical(self) -> None:
        """The stored proof rebuilds exactly."""
        if not staged():
            self.skipTest("staged palette and world basis are not present")
        result = W.prove(json.loads(ROWS.read_text()), D.SRC.PALETTE, GRIP)
        stored = json.loads(PROOF.read_text())
        rebuilt = json.loads(json.dumps(result, default=str))
        for key in ("clear", "fixture", "dig_stroke", "dig_entry", "self_clearance"):
            self.assertEqual(rebuilt[key], stored[key], key)


if __name__ == "__main__":
    unittest.main()
