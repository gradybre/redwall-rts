#!/usr/bin/env python3
"""Tests for the create-only content-11 publication (decision 1971).

    python3 godot/data/underground/mole-worker/test_publish_claw_wall_runtime.py -v
"""
from __future__ import annotations

import json
import struct
import unittest

import publish_claw_wall_runtime as PUB


def published() -> tuple:
    """(revision, digests, fields, rows) of the published content-11 wire."""
    return PUB.PUB7.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())


class ClawWallRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces, motion bank and manifest rebuild byte for byte."""
        for name, raw in PUB.build().items():
            if name != "catalog_source.gd":
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_wall_rows_copy_the_derived_boxes_and_the_dig_words(self) -> None:
        """Rows 67-70 carry the derivation's boxes and M1's words at the same heading (box index and count aside)."""
        derived = PUB.read_rows()
        _, _, fields, rows = published()
        for wall, dig, row in zip(PUB.WALL_ROWS, PUB.DIG_ROWS, derived):
            self.assertEqual(rows[wall], PUB.PUB7.role_boxes(row["roles"]))
            self.assertEqual([v for k, v in enumerate(fields[wall]) if k not in (PUB.F_FIRST_BOX, 15)],
                             [v for k, v in enumerate(fields[dig]) if k not in (PUB.F_FIRST_BOX, 15)], wall)
            self.assertEqual(fields[wall][15], 12, wall)

    def test_content_ten_is_unchanged(self) -> None:
        """Sources and rows 0-66 equal content 10's; only the revision and the four rows are new."""
        old = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        revision, digests, fields, rows = published()
        self.assertEqual((revision, len(fields), digests), (11, 71, old[1]))
        self.assertEqual(rows[:67], old[3])

    def test_ground_and_motion_rebound_to_revision_eleven(self) -> None:
        """Ground paces keep their twenty-six caps; the motion bank names the new wire."""
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<Iq", ground, 44), (26, 11))
        motion = (PUB.OUTPUT / "motion.ugmotion").read_bytes()
        wire = PUB.sha((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())
        self.assertEqual(motion[PUB.H.BYTE_AT + 160:PUB.H.BYTE_AT + 192].hex(), wire)

    def test_accessor_names_the_wall_rows(self) -> None:
        """The accessor pins the new wire and publishes the wall row IDs; the manifest marks it inactive."""
        text = (PUB.OUTPUT / "catalog_source.gd").read_text()
        self.assertIn("const CLAW_WALL_ROWS: PackedInt32Array = [67, 68, 69, 70]", text)
        self.assertIn(PUB.sha((PUB.OUTPUT / "mole-worker.ugprof").read_bytes()), text)
        self.assertFalse(json.loads((PUB.OUTPUT / "manifest.json").read_text())["runtime_admitted"])

    def test_key_order_refusal(self) -> None:
        """A wall row placed with a lower key than its source's previous row is refused."""
        old = (PUB.OLD / "mole-worker.ugprof").read_bytes()
        wire, _ = PUB.build_wire(PUB.read_rows())
        revision, digests, fields, rows = PUB.PUB7.parse(wire)
        fields[67][1] = -1
        saved, PUB.PUB9.NEW_REVISION = PUB.PUB9.NEW_REVISION, 11
        try:
            broken = PUB.PUB9.encode(list(digests), fields, rows)
        finally:
            PUB.PUB9.NEW_REVISION = saved
        with self.assertRaises(ValueError):
            PUB.check(old, broken)


if __name__ == "__main__":
    unittest.main()
