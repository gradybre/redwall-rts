#!/usr/bin/env python3
"""Tests for the create-only content-9 publication (ADR 1217 step 4e).

    python3 godot/data/underground/mole-worker/test_publish_claw_approach_runtime.py -v
"""
from __future__ import annotations

import json
import struct
import unittest

import publish_claw_approach_runtime as PUB


def published() -> tuple:
    """(revision, digests, fields, rows) of the published content-9 wire."""
    return PUB.PUB7.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())


class ClawApproachRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces and motion bank rebuild byte for byte."""
        for name, raw in PUB.build().items():
            if name not in ("catalog_source.gd", "manifest.json"):
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_narrow_rows_copy_the_derived_boxes(self) -> None:
        """Rows 43-50 are the record's rows in order, with forward/backward policies and exact headings."""
        record = json.loads(PUB.APPROACH[0].read_text())
        _, _, fields, rows = published()
        for index, row in enumerate(record["rows"]):
            self.assertEqual(rows[43 + index], PUB.PUB7.role_boxes(row["roles"]))
            self.assertEqual((fields[43 + index][PUB.F_POLICY], fields[43 + index][PUB.F_YAW]),
                             (PUB.POLICIES[row["policy"]], row["yaw"]))

    def test_moved_rows_are_content_eights(self) -> None:
        """Content 8's rows 43-51 are rows 51-59 with the same boxes."""
        _, _, _, old_rows = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        _, _, _, rows = published()
        self.assertEqual(rows[51:60], old_rows[43:52])

    def test_ground_caps_for_the_narrow_rows(self) -> None:
        """Twenty-four ground caps at revision 9; the last eight are rows 43-50."""
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<I", ground, 44)[0], 24)
        profiles = [struct.unpack_from("<i", ground, 136 + 36 * r)[0] for r in range(16, 24)]
        self.assertEqual(profiles, list(range(43, 51)))

    def test_fade_window_must_hold_in_the_record(self) -> None:
        """A narrower blocked window than the record's unresolved fades refuses."""
        saved = PUB.FADE_BLOCKED
        PUB.FADE_BLOCKED = (29, 37)
        try:
            with self.assertRaisesRegex(ValueError, "CLAW_APPROACH_RUNTIME_FADE_WINDOW"):
                PUB.read_approach()
        finally:
            PUB.FADE_BLOCKED = saved


if __name__ == "__main__":
    unittest.main()
