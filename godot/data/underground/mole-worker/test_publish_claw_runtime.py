#!/usr/bin/env python3
"""Tests for the create-only content-7 publication (ADR 1217 step 4).

    python3 godot/data/underground/mole-worker/test_publish_claw_runtime.py -v
"""
from __future__ import annotations

import json
import unittest

import publish_claw_runtime as PUB


class ClawRuntimePublication(unittest.TestCase):
    """The published files are exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Wire, ground paces, motion bank, accessor and manifest rebuild byte for byte."""
        built = PUB.build()
        for name, raw in built.items():
            if name in ("catalog_source.gd", "manifest.json"):
                continue  # Both pin current consumer digests, which renew independently.
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_rows_and_sources(self) -> None:
        """51 rows, 5 sources; rows 0-41 keep their words; the claw block is the nine derived rows."""
        revision, digests, fields, rows = PUB.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())
        self.assertEqual((revision, len(fields), len(digests)), (7, 51, 5))
        claw = [f for f in fields if f[PUB.F_SOURCE] == PUB.CLAW_SOURCE]
        self.assertEqual(len(claw), 9)
        self.assertTrue(all(f[PUB.F_TOOL] == -1 for f in claw))
        self.assertEqual([f[PUB.F_YAW] for f in claw], [0, 0, 0, 16384, 16384, 32768, 32768, 49152, 49152])

    def test_derived_boxes_are_copied(self) -> None:
        """Every claw row's boxes are the derived record's boxes in role order."""
        record = json.loads(PUB.INPUTS["rows"][0].read_text())
        derived = {(row["program"], row["yaw"]): PUB.role_boxes(row["roles"]) for row in record["rows"]}
        _, _, fields, rows = PUB.parse((PUB.OUTPUT / "mole-worker.ugprof").read_bytes())
        order = [(0, "dig"), (0, "tap"), (0, "seat")] + [(y, n) for y in (16384, 32768, 49152) for n in ("dig", "tap")]
        for index, (yaw, name) in enumerate(order):
            self.assertEqual(rows[42 + index], derived[(name, yaw)], (name, yaw))

    def test_published_wire_refuses_tampering(self) -> None:
        """A changed input digest refuses the build."""
        saved = PUB.INPUTS["claw"]
        PUB.INPUTS["claw"] = (saved[0], "0" * 64)
        try:
            with self.assertRaisesRegex(ValueError, "CLAW_RUNTIME_INPUT_CLAW"):
                PUB.build()
        finally:
            PUB.INPUTS["claw"] = saved


if __name__ == "__main__":
    unittest.main()
