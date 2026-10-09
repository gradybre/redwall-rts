#!/usr/bin/env python3
"""Tests for the create-only content-8 publication (ADR 1217 step 4c).

    python3 godot/data/underground/mole-worker/test_publish_claw_split_runtime.py -v
"""
from __future__ import annotations

import json
import struct
import unittest

import publish_claw_split_runtime as PUB


def published() -> tuple:
    """(revision, digests, fields, rows) of the published content-8 wire."""
    return PUB.PUB7.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())


class ClawSplitRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces and motion bank rebuild byte for byte."""
        built = PUB.build()
        for name, raw in built.items():
            if name in ("catalog_source.gd", "manifest.json"):
                continue  # Both pin current consumer digests, which renew independently.
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_blocks_and_sources(self) -> None:
        """52 rows, 6 sources: rows 0-41 are content 7's, then source 4's nine rows and source 5's one."""
        revision, digests, fields, _ = published()
        self.assertEqual((revision, len(fields), len(digests)), (8, 52, 6))
        self.assertEqual([f[PUB.F_SOURCE] for f in fields[42:]], [4] * 9 + [5])
        self.assertEqual(digests[4].hex(), PUB.INPUTS["claw"][1])
        self.assertEqual(digests[5].hex(), PUB.INPUTS["paw"][1])
        self.assertTrue(all(f[6] == -1 for f in fields[42:]))

    def test_walk_row_is_canonical_ground_with_the_derived_boxes(self) -> None:
        """Row 42 is row 31's words on source 4 with the canonical-ground policy; boxes from the derivation."""
        _, _, fields, rows = published()
        record = json.loads(PUB.INPUTS["walk"][0].read_text())
        walk = {row["row"]: row for row in record["rows"]}["claw WALK"]
        self.assertEqual(rows[42], PUB.PUB7.role_boxes(walk["roles"]))
        expected = list(fields[31])
        expected[PUB.F_SOURCE], expected[PUB.F_POLICY] = 4, PUB.POLICY_CANONICAL_GROUND
        for index in (PUB.F_FIRST_BOX,):
            expected[index] = fields[42][index]
        self.assertEqual(list(fields[42]), expected)

    def test_work_and_handling_rows_are_content_sevens(self) -> None:
        """Dig/tap and handling keep content 7's words and boxes; only the source changes for handling."""
        _, _, old_fields, old_rows = PUB.PUB7.parse((PUB.OLD / "mole-worker.ugprof").read_bytes())
        _, _, fields, rows = published()
        pairs = list(zip(range(43, 51), PUB.CLAW_ROWS)) + [(51, PUB.HANDLING_ROW)]
        for new, old in pairs:
            self.assertEqual(rows[new], old_rows[old], (new, old))
            same = [v for k, v in enumerate(fields[new]) if k not in (PUB.F_FIRST_BOX, PUB.F_SOURCE)]
            self.assertEqual(same, [v for k, v in enumerate(old_fields[old]) if k not in (PUB.F_FIRST_BOX, PUB.F_SOURCE)])

    def test_ground_paces_add_row_42_and_bind_source_4(self) -> None:
        """Sixteen ground caps (row 42 added) at revision 8, bound to the claw source."""
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        head = struct.unpack_from("<8sIq7I3q", ground)
        self.assertEqual(head, (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 16, 8, 1, 4))
        self.assertEqual(ground[72:104].hex(), PUB.INPUTS["claw"][1])
        last = struct.unpack_from("<7iq", ground, 136 + 36 * 15)
        self.assertEqual(last, (42, -1, 0, 1, 1, 0, 0, 1))

    def test_tampered_input_refuses(self) -> None:
        """A changed input digest refuses the build."""
        saved = PUB.INPUTS["paw"]
        PUB.INPUTS["paw"] = (saved[0], "0" * 64)
        try:
            with self.assertRaisesRegex(ValueError, "CLAW_SPLIT_RUNTIME_INPUT_PAW"):
                PUB.build()
        finally:
            PUB.INPUTS["paw"] = saved


if __name__ == "__main__":
    unittest.main()
