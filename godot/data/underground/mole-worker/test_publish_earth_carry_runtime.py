#!/usr/bin/env python3
"""Tests for the create-only content-13 publication and its stair tables (decision 2042).

    python3 godot/data/underground/mole-worker/test_publish_earth_carry_runtime.py -v
"""
from __future__ import annotations

import json
import re
import struct
import unittest

import publish_earth_carry_motion as MOT
import publish_earth_carry_runtime as PUB


BUILT: dict = {}
MOTION: dict = {}


def built(name: str) -> bytes:
    """One content-13 output as the publisher builds it now (the rebuild test ties it to the published file)."""
    if not BUILT:
        BUILT.update(PUB.build())
    return BUILT[name]


def built_motion(name: str) -> bytes:
    """One stair-table output as its publisher builds it now."""
    if not MOTION:
        MOTION.update(MOT.build())
    return MOTION[name]


def published() -> tuple:
    """(revision, digests, fields, rows) of the content-13 wire."""
    return PUB.PUB7.parse(built("mole-worker.ugprof"))


def old() -> tuple:
    """Content 12's."""
    return PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())


def encode(digests: list, fields: list, rows: list) -> bytes:
    """Content 9's encoder at revision 13."""
    saved, PUB.PUB9.NEW_REVISION = PUB.PUB9.NEW_REVISION, 13
    try:
        return PUB.PUB9.encode(list(digests), fields, rows)
    finally:
        PUB.PUB9.NEW_REVISION = saved


class EarthCarryRuntimePublication(unittest.TestCase):
    """Content 13: content 12 plus eleven earth rows that are the stone rows with their cargo changed."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces and motion bank rebuild byte for byte; the accessor and manifest match apart from the
        consumer pins a renewal may move."""
        built = PUB.build()
        for name, raw in built.items():
            if name not in ("catalog_source.gd", "manifest.json"):
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)
        digests = re.compile(r"const DIGESTS: PackedStringArray = \[\n.*?\n\]", re.S)
        self.assertEqual(digests.sub("", (PUB.OUTPUT / "catalog_source.gd").read_text()),
                         digests.sub("", built["catalog_source.gd"].decode()))
        self.assertEqual(json.loads((PUB.OUTPUT / "manifest.json").read_text()), json.loads(built["manifest.json"]))

    def test_content_twelve_is_unchanged_and_the_stone_images_repeat(self) -> None:
        """Sources 0-7 and rows 0-84 are content 12's; sources 8 and 9 are its sources 3 and 7."""
        _, old_digests, _, old_rows = old()
        revision, digests, fields, rows = published()
        self.assertEqual((revision, len(fields), len(digests)), (13, 96, 10))
        self.assertEqual((digests[:8], digests[8], digests[9]), (old_digests, old_digests[3], old_digests[7]))
        self.assertEqual(rows[:85], old_rows)

    def test_earth_rows_are_the_stone_rows_with_cargo_eleven_and_five_kilos(self) -> None:
        """85-89 repeat 37-41 on source 8 and 90-95 repeat 79-84 on source 9; a carried unit is item 11 at 5,000."""
        _, _, old_fields, old_rows = old()
        _, _, fields, rows = published()
        moved = {PUB.F_SOURCE, PUB.F_CARGO, PUB.F_FIRST_BOX, PUB.Q_MIN, PUB.Q_MAX}
        for row, template in zip(range(85, 96), list(range(37, 42)) + list(range(79, 85))):
            self.assertEqual([v for k, v in enumerate(fields[row]) if k not in moved],
                             [v for k, v in enumerate(old_fields[template]) if k not in moved], row)
            self.assertEqual(rows[row], old_rows[template], row)
            self.assertEqual(fields[row][PUB.F_SOURCE], 8 if row < 90 else 9, row)
            carries = old_fields[template][PUB.F_CARGO] != -1
            self.assertEqual(fields[row][PUB.F_CARGO], 11 if carries else -1, row)
            self.assertEqual((fields[row][PUB.Q_MIN], fields[row][PUB.Q_MAX]), (5000, 5000) if carries else (0, 0), row)

    def test_the_earth_item_is_the_catalog_s_excavated_earth(self) -> None:
        """Ascending-ASCII ids give stone 53 (ADR 1206) and excavated_earth 11."""
        self.assertEqual((PUB.item_id("stone"), PUB.item_id("wood"), PUB.item_id("excavated_earth")), (53, 60, 11))
        with self.assertRaisesRegex(ValueError, "ITEM_"):
            PUB.item_id("no_such_item")

    def test_ground_adds_row_85_with_row_37_s_cap(self) -> None:
        """27 caps at revision 13; the last is the earth carry's, equal to the stone carry's but for its profile."""
        ground = built("ground-pace.ugconn")
        self.assertEqual(struct.unpack_from("<Iq", ground, 44), (27, 13))
        paces = [PUB.H.PACE.unpack_from(ground, 136 + 36 * r) for r in range(27)]
        stone = next(p for p in paces if p[0] == 37)
        self.assertEqual(paces[-1], (85,) + stone[1:])
        self.assertEqual(ground[-8:], b"UGCEND01")

    def test_motion_rebound_to_revision_thirteen(self) -> None:
        """The motion bank names the new wire at revision 13."""
        motion = built("motion.ugmotion")
        wire = PUB.sha(built("mole-worker.ugprof"))
        self.assertEqual(motion[PUB.H.BYTE_AT + 160:PUB.H.BYTE_AT + 192].hex(), wire)
        self.assertEqual(struct.unpack_from("<q", motion, 16), (13,))
        self.assertEqual(struct.unpack_from("<2q", motion, PUB.H.I64_AT + 8), (13, 13))
        old_motion = (PUB.OLD / "motion.ugmotion").read_bytes()
        with self.assertRaisesRegex(ValueError, "MOTION_LAYOUT"):
            PUB.rebind_motion(old_motion[:-1] + b"x", PUB.OLD_WIRE_SHA, wire, "0" * 64)

    def test_accessor_and_manifest(self) -> None:
        """The accessor names the earth rows, item and payload; the manifest marks it inactive."""
        text = built("catalog_source.gd").decode()
        for line in ("const EARTH_ITEM: int = 11", "const EARTH_QUANTITY_MILLI: int = 5000",
                     "const EARTH_LEVEL_ROWS: PackedInt32Array = [85, 86, 87, 88, 89]",
                     "const EARTH_STAIR_ROWS: PackedInt32Array = [90, 91, 92, 93, 94, 95]"):
            self.assertIn(line, text)
        manifest = json.loads(built("manifest.json"))
        self.assertFalse(manifest["runtime_admitted"])
        self.assertEqual((manifest["content_revision"], manifest["earth_quantity_milli"], manifest["earth_item"]),
                         (13, 5000, 11))

    def test_a_template_with_another_unit_is_refused(self) -> None:
        """A stone template must carry stone or nothing."""
        _, _, fields, rows = old()
        fields[37][PUB.F_CARGO] = 60
        with self.assertRaisesRegex(ValueError, "TEMPLATE_37"):
            PUB.earth_rows(fields, rows)

    def test_a_template_with_another_quantity_is_refused(self) -> None:
        """A stone template's trip is 1,000 milli-U."""
        _, _, fields, rows = old()
        fields[40][PUB.Q_MAX] = 2000
        with self.assertRaisesRegex(ValueError, "TEMPLATE_QUANTITY"):
            PUB.earth_rows(fields, rows)

    def test_key_order_and_identity_refusals(self) -> None:
        """An earth row out of its source's key order, or differing from its template, is refused."""
        wire, previous = PUB.build_wire()
        _, digests, fields, rows = PUB.PUB7.parse(wire)
        edited = [list(f) for f in fields]
        edited[86][1] = -1
        with self.assertRaisesRegex(ValueError, "KEY_ORDER"):
            PUB.check(previous, encode(digests, edited, rows))
        boxes = [list(r) for r in rows]
        boxes[91][0] = (boxes[91][0][0] - 1,) + tuple(boxes[91][0][1:])
        with self.assertRaisesRegex(ValueError, "TEMPLATE_IDENTITY_91"):
            PUB.check(previous, encode(digests, fields, boxes))
        edited = [list(f) for f in fields]
        edited[90][11] = 16384  # F_YAW
        with self.assertRaisesRegex(ValueError, "TEMPLATE_IDENTITY_90"):
            PUB.check(previous, encode(digests, edited, rows))


class EarthCarryMotionPublication(unittest.TestCase):
    """Content 13's stair tables: content 12's fourteen programs, then the six stone ones as rows 90-95."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Every published file rebuilds byte for byte."""
        for name, raw in MOT.build().items():
            self.assertEqual((MOT.OUTPUT / name).read_bytes(), raw, name)

    def test_earth_programs_are_the_stone_programs(self) -> None:
        """Rows 90-95 keep every key, deck, end, heading and clip of 79-84; only row, source and group move."""
        table, _, _ = MOT.programs()
        self.assertEqual([p["row"] for p in table], list(range(71, 85)) + list(range(90, 96)))
        stone = {p["row"]: p for p in table if p["row"] in range(79, 85)}
        for program in table[14:]:
            template = stone[program["row"] - 11]
            self.assertEqual({k: v for k, v in program.items() if k not in ("row", "source", "group")},
                             {k: v for k, v in template.items() if k not in ("row", "source", "group")})
            self.assertEqual((program["source"], program["group"]), (9, "earth"))

    def test_the_wire_names_revision_thirteen_and_the_content_13_wire(self) -> None:
        """Header: 20 programs at content revision 13, then the content-13 profile digest."""
        wire = built_motion("stair-motion.ugstair")
        self.assertEqual(wire[:8], b"UGSTRM01")
        self.assertEqual(struct.unpack_from("<IqI", wire, 8), (1, 13, 20))
        self.assertEqual(wire[32:64].hex(), PUB.sha((PUB.OUTPUT / "mole-worker.ugprof").read_bytes()))
        self.assertIn("const CONTENT_REVISION: int = 13", built_motion("catalog_source.gd").decode())
        self.assertEqual(wire[-8:], b"UGSTEND1")


if __name__ == "__main__":
    unittest.main()
