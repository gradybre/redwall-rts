#!/usr/bin/env python3
"""Tests for the create-only content-10 publication (ADR 1229).

    python3 godot/data/underground/mole-worker/test_publish_claw_stairs_runtime.py -v
"""
from __future__ import annotations

import struct
import unittest

import publish_claw_stairs_runtime as PUB


def published() -> tuple:
    """(revision, digests, fields, rows) of the published content-10 wire."""
    return PUB.PUB7.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())


class ClawStairsRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces and motion bank rebuild byte for byte."""
        for name, raw in PUB.build().items():
            if name not in ("catalog_source.gd", "manifest.json"):
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_new_rows_copy_the_derived_boxes(self) -> None:
        """Rows 51-55, 64 and 66 carry the derivation record's boxes and their policies."""
        derived = PUB.read_rows()
        _, _, fields, rows = published()
        expected = {51: ("step_back", 5), 52: ("step_forward", 4), 53: ("descent", 8), 54: ("ascent", 8),
                    55: ("turn", 9), 64: ("tread_tap", 3), 66: ("tread_seat", 7)}
        for row, (name, policy) in expected.items():
            self.assertEqual(rows[row], PUB.PUB7.role_boxes(derived[name]["roles"]), name)
            self.assertEqual(fields[row][PUB.F_POLICY], policy, name)
        self.assertEqual(fields[64][PUB.F_CONTACT], PUB.CONTACT_TREAD_FIT)

    def test_sources_four_and_five_are_the_v2_images(self) -> None:
        """Sources 4 and 5 are the native v2 images; sources 0-3 are content 9's."""
        _, old_digests, _, _ = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        _, digests, _, _ = published()
        self.assertEqual(digests[:4], old_digests[:4])
        self.assertEqual({4: digests[4], 5: digests[5]}, PUB.image_digests())

    def test_ground_caps_for_the_steps(self) -> None:
        """Twenty-six ground caps at revision 10; the last two are rows 51 and 52."""
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<I", ground, 44)[0], 26)
        self.assertEqual([struct.unpack_from("<i", ground, 136 + 36 * r)[0] for r in (24, 25)], [51, 52])

    def test_moved_rows_are_content_nines(self) -> None:
        """Content 9's rows 51-58 are rows 56-63, and its row 59 is row 65."""
        _, _, _, old_rows = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        _, _, _, rows = published()
        self.assertEqual(rows[56:64], old_rows[51:59])
        self.assertEqual(rows[65], old_rows[59])


if __name__ == "__main__":
    unittest.main()
