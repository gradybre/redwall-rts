#!/usr/bin/env python3
"""Tests for the create-only claw stair motion tables (ADR 1229 increment 3).

    python3 godot/data/underground/mole-worker/test_publish_claw_stair_motion.py -v
"""
from __future__ import annotations

import struct
import unittest

import publish_claw_stair_motion as PUB


class ClawStairMotionPublication(unittest.TestCase):
    """The published wire is exactly what the publisher derives from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """The wire and the generated accessor rebuild byte for byte."""
        built = PUB.build()
        for name in ("stair-motion.ugstair", "catalog_source.gd"):
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), built[name], name)

    def test_programs_end_where_the_approved_motions_end(self) -> None:
        """Rows 51-55: the two 141 u steps, the stair gaits one tread each way, the half-turn 174 u back."""
        table, _, _ = PUB.programs()
        self.assertEqual([p["row"] for p in table], [51, 52, 53, 54, 55])
        self.assertEqual([p["end"] for p in table], [[0, 0, 141], [0, 0, -141], [0, -128, -512], [0, 128, 512], [0, 0, 174]])
        self.assertEqual([p["yaw"] for p in table], [(0, 0), (0, 0), (0, 0), (32768, 32768), (0, 32768)])
        self.assertEqual([len(p["keys"]) for p in table], [2, 2, 91, 91, 271])

    def test_each_interval_names_a_deck_of_its_program(self) -> None:
        """The gaits change deck once (the first 30 intervals on the start deck), the turn stays on one."""
        table, _, _ = PUB.programs()
        descent, ascent, turn = table[2], table[3], table[4]
        for gait in (descent, ascent):
            decks = [key[4] for key in gait["keys"][:90]]
            self.assertEqual(decks, [0] * 30 + [1] * 60)
        self.assertEqual({key[4] for key in turn["keys"]}, {0})

    def test_the_wire_header_names_content_ten(self) -> None:
        """Magic, version, content revision and the census in the header."""
        raw = (PUB.OUTPUT / "stair-motion.ugstair").read_bytes()
        self.assertEqual(struct.unpack_from("<8sIqIII", raw), (b"UGSTRM01", 1, 10, 5, 457, 7))
        self.assertEqual(raw[-8:], b"UGSTEND1")

    def test_a_pinned_input_change_refuses(self) -> None:
        """An input whose digest is not the pinned one is refused before any derivation."""
        saved = dict(PUB.INPUTS)
        try:
            first = next(iter(PUB.INPUTS))
            PUB.INPUTS[first] = "0" * 64
            with self.assertRaises(ValueError):
                PUB.programs()
        finally:
            PUB.INPUTS.clear()
            PUB.INPUTS.update(saved)


if __name__ == "__main__":
    unittest.main()
