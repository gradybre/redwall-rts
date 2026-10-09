#!/usr/bin/env python3
"""Tests for the source-4 STAND/WALK derivation (ADR 1217 step 4c).

The record and clip-pin tests need only committed files; the rebuild test needs the staged palettes and world
basis and skips without them.

    $PY .../test_derive_claw_stand_rows.py -v
"""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import derive_claw_stand_rows as D

RECORD = D.SRC.HERE / "evidence/claw-split-rows-v1/stand-walk.json"
BASIS = D.SRC.PALETTE.parent / "world-yaw-v1.ugyaw"


class ClawStandRows(unittest.TestCase):
    """The rows are derived from the claw image's own clips and match the accepted ground role layout."""

    def test_clips_are_the_claw_images_own(self) -> None:
        """Both clips match the claw image's compilation record."""
        source = D.image_clips()
        self.assertEqual(set(source["clips"]), {"stand", "walk"})
        self.assertEqual(source["clips"]["stand"]["frames"], 122)
        self.assertEqual(source["clips"]["walk"]["frames"], 45)

    def test_record_roles(self) -> None:
        """STAND (mode 0) and WALK (mode 1) share the derived roles: a 712 u sweep and the 406 u stance."""
        rows = json.loads(RECORD.read_text())["rows"]
        self.assertEqual([(r["mode"], r["states"], r["tool"]) for r in rows], [(0, 257, -1), (1, 451, -1)])
        for row in rows:
            self.assertEqual(row["roles"]["BODY_HELD_LOAD"], [[-712, 0, -712, 712, 930, 712], [-402, -1, -402, 402, 0, 402]])
            self.assertEqual(row["roles"]["STANCE_SUPPORT"], [[-406, -1, -406, 406, 0, 406]])

    def test_rebuild_is_identical(self) -> None:
        """The stored record rebuilds exactly from the staged inputs."""
        if not D.SRC.PALETTE.is_file() or not BASIS.is_file():
            self.skipTest("staged palette and world basis are not present")
        result = D.derive(D.SRC.PALETTE, D.SRC.PALETTE.parent / "mole-grip-v3.ugpal", BASIS)
        stored = json.loads(RECORD.read_text())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "rows.json"
            path.write_text(json.dumps(result, indent=1, default=str) + "\n")
            rebuilt = json.loads(path.read_text())
        for key in ("rows", "ground_enclosure", "clip_sha256", "claw_image_sha256", "world_basis_sha256"):
            self.assertEqual(rebuilt[key], stored[key], key)


if __name__ == "__main__":
    unittest.main()
