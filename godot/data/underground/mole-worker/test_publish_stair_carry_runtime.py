#!/usr/bin/env python3
"""Tests for the create-only content-12 publication (decision 1981).

    python3 godot/data/underground/mole-worker/test_publish_stair_carry_runtime.py -v
"""
from __future__ import annotations

import json
import struct
import unittest

import publish_stair_carry_runtime as PUB


def published() -> tuple:
    """(revision, digests, fields, rows) of the published content-12 wire."""
    return PUB.PUB7.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())


def encode(digests: list, fields: list, rows: list) -> bytes:
    """Content 9's encoder at revision 12."""
    saved, PUB.PUB9.NEW_REVISION = PUB.PUB9.NEW_REVISION, 12
    try:
        return PUB.PUB9.encode(list(digests), fields, rows)
    finally:
        PUB.PUB9.NEW_REVISION = saved


class StairCarryRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces and motion bank rebuild byte for byte; the manifest matches apart from the consumer
        pins `tools/renew_source_pins.py` may add after publication."""
        built = PUB.build()
        for name, raw in built.items():
            if name not in ("catalog_source.gd", "manifest.json"):
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)
        stored = json.loads((PUB.OUTPUT / "manifest.json").read_text())
        for key in ("consumers", "renewals"):
            stored.pop(key, None)
        self.assertEqual(stored, json.loads(built["manifest.json"]))

    def test_content_eleven_is_unchanged(self) -> None:
        """Sources 0-5 and rows 0-70 equal content 11's; sources 6 and 7 are the two verified images."""
        old = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        revision, digests, fields, rows = published()
        self.assertEqual((revision, len(fields), digests[:6]), (12, 85, old[1]))
        self.assertEqual(rows[:71], old[3])
        images = PUB.image_digests()
        self.assertEqual(digests[6:], [images[6], images[7]])

    def test_new_rows_take_their_templates_words(self) -> None:
        """Rows 71-84 keep row 31's, 32's or 37's words except source, heading, family and policy."""
        _, _, fields, rows = published()
        changed = {PUB.F_SOURCE, PUB.F_YAW_KIND, PUB.F_YAW, PUB.F_FAMILIES, PUB.F_FIRST_BOX, 15, PUB.F_POLICY}
        derived = PUB.read_rows()
        templates = [31] * 2 + [32] * 6 + [37] * 6
        for at, (template, row) in enumerate(zip(templates, derived)):
            index = 71 + at
            self.assertEqual([v for k, v in enumerate(fields[index]) if k not in changed],
                             [v for k, v in enumerate(fields[template]) if k not in changed], index)
            self.assertEqual(rows[index], PUB.PUB7.role_boxes(row["roles"]), index)
            self.assertEqual((fields[index][PUB.F_YAW_KIND], fields[index][PUB.F_YAW], fields[index][PUB.F_FAMILIES]),
                             (0, row["yaw"], 1), index)
            self.assertEqual(fields[index][PUB.F_POLICY], PUB.POLICY[row["name"]], index)
            self.assertEqual(fields[index][PUB.F_SOURCE], 6 if index < 79 else 7, index)

    def test_ground_and_motion_rebound_to_revision_twelve(self) -> None:
        """Ground paces keep their twenty-six caps; the motion bank names the new wire."""
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<Iq", ground, 44), (26, 12))
        motion = (PUB.OUTPUT / "motion.ugmotion").read_bytes()
        wire = PUB.sha((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())
        self.assertEqual(motion[PUB.H.BYTE_AT + 160:PUB.H.BYTE_AT + 192].hex(), wire)
        self.assertEqual(struct.unpack_from("<q", motion, 16), (12,))

    def test_accessor_names_the_rows_and_sources(self) -> None:
        """The accessor pins the new wire, both images and the row IDs; the manifest marks it inactive."""
        text = (PUB.OUTPUT / "catalog_source.gd").read_text()
        self.assertIn("const STAIR_CARRY_WOOD_ROWS: PackedInt32Array = [73, 74, 75, 76, 77, 78]", text)
        self.assertIn("const STAIR_CARRY_STONE_ROWS: PackedInt32Array = [79, 80, 81, 82, 83, 84]", text)
        self.assertIn("const STAIR_EMPTY_FLOOR_ROWS: PackedInt32Array = [71, 72]", text)
        self.assertIn(PUB.sha((PUB.OUTPUT / "mole-worker.ugprof").read_bytes()), text)
        for digest in PUB.image_digests().values():
            self.assertIn(digest.hex(), text)
        self.assertFalse(json.loads((PUB.OUTPUT / "manifest.json").read_text())["runtime_admitted"])

    def test_key_order_refusal(self) -> None:
        """A new row with a lower key than its source's previous row is refused."""
        old = (PUB.OLD / "mole-worker.ugprof").read_bytes()
        wire, _ = PUB.build_wire(PUB.read_rows())
        _, digests, fields, rows = PUB.PUB7.parse(wire)
        fields[73][1] = -1
        with self.assertRaises(ValueError):
            PUB.check(old, encode(digests, fields, rows))

    def test_ambiguous_key_refusal(self) -> None:
        """Two new rows with one policy, key and heading are refused (the back-up under the approach's word)."""
        old = (PUB.OLD / "mole-worker.ugprof").read_bytes()
        wire, _ = PUB.build_wire(PUB.read_rows())
        _, digests, fields, rows = PUB.PUB7.parse(wire)
        fields[78][PUB.F_POLICY] = PUB.ROOTED_TRAVEL
        with self.assertRaisesRegex(ValueError, "AMBIGUOUS_KEY"):
            PUB.check(old, encode(digests, fields, rows))

    def test_row_census_refusal(self) -> None:
        """A rows record out of publication order is refused."""
        saved = PUB.read_rows
        rows = saved()
        PUB.read_rows = lambda: rows[::-1]
        try:
            with self.assertRaisesRegex(ValueError, "ROW_GROUP|TEMPLATE"):
                PUB.build_wire(PUB.read_rows())
        finally:
            PUB.read_rows = saved


if __name__ == "__main__":
    unittest.main()
