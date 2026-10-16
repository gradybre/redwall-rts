#!/usr/bin/env python3
"""Tests for the create-only stair-carry tables (decision 1981).

    python3 godot/data/underground/mole-worker/test_publish_stair_carry_motion.py -v
"""
from __future__ import annotations

import json
import struct
import unittest

import publish_stair_carry_motion as PUB


class StairCarryMotionPublication(unittest.TestCase):
    """The published wire is exactly what the publisher derives from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """The wire, the accessor and the manifest rebuild byte for byte."""
        built = PUB.build()
        for name, raw in built.items():
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_programs_end_where_the_motions_end(self) -> None:
        """Per item: the approach 343 u forward, one tread down and up, the half-turn 174 u back, the retreat 169 u
        and the back-up 343 u; the empty pair 343 u each way."""
        table, _, _ = PUB.programs()
        ends = {p["name"]: p["end"] for p in table}
        self.assertEqual(ends, {"empty_walk_off": [0, 0, -343], "empty_back_up": [0, 0, 343], "approach": [0, 0, -343],
                                "descent": [0, -128, -512], "ascent": [0, 128, 512], "turn": [0, 0, 174],
                                "retreat": [0, 0, 169], "back_up": [0, 0, 343]})
        self.assertEqual([len(p["keys"]) for p in table], [91, 91] + [91, 91, 91, 271, 91, 91] * 2)

    def test_headings(self) -> None:
        """The ascent and retreat face up the stair; the turn ends facing up; everything else faces down."""
        table, _, _ = PUB.programs()
        yaws = {p["name"]: p["yaw"] for p in table}
        self.assertEqual(yaws["ascent"], [32768, 32768])
        self.assertEqual(yaws["retreat"], [32768, 32768])
        self.assertEqual(yaws["turn"], [0, 32768])
        self.assertEqual(yaws["descent"], [0, 0])

    def test_gaits_change_deck_once(self) -> None:
        """The gaits stand on the start deck for the first 30 intervals; handoffs stay on one deck."""
        table, _, _ = PUB.programs()
        for p in table:
            decks = [k[4] for k in p["keys"][:-1]]
            if p["name"] in ("descent", "ascent"):
                self.assertEqual(decks, [0] * 30 + [1] * 60, p["row"])
            else:
                self.assertEqual(set(decks), {0}, p["row"])

    def test_the_wire_header_names_content_twelve(self) -> None:
        """Revision 12, fourteen programs, and the SHA of the content-12 profile wire."""
        wire = (PUB.OUTPUT / "stair-motion.ugstair").read_bytes()
        self.assertEqual(wire[:8], b"UGSTRM01")
        self.assertEqual(struct.unpack_from("<IqI", wire, 8), (1, 12, 14))
        profile = (PUB.CONTENT / "mole-worker.ugprof").read_bytes()
        self.assertEqual(wire[32:64], PUB.hashlib.sha256(profile).digest())
        self.assertEqual(wire[-8:], b"UGSTEND1")

    def test_clip_ordinals_follow_each_image(self) -> None:
        """Source 6's clips are hold then the six loaded then the empty pair; source 7's the hold and six."""
        table, _, _ = PUB.programs()
        self.assertEqual([(p["source"], p["clip"]) for p in table],
                         [(6, 7), (6, 8)] + [(6, c) for c in range(1, 7)] + [(7, c) for c in range(1, 7)])

    def test_a_bad_deck_index_is_refused(self) -> None:
        """A key naming a deck its program lacks is refused."""
        record = json.loads(PUB.TABLES.read_text())
        record["programs"][0]["keys"][3][4] = 5
        with self.assertRaisesRegex(ValueError, "DECK_INDEX"):
            PUB.programs(record)

    def test_a_program_not_starting_at_its_root_is_refused(self) -> None:
        """Every program is in the frame of its start root."""
        record = json.loads(PUB.TABLES.read_text())
        record["programs"][2]["keys"][0][2] = 1
        with self.assertRaisesRegex(ValueError, "PROGRAM_73"):
            PUB.programs(record)


if __name__ == "__main__":
    unittest.main()
