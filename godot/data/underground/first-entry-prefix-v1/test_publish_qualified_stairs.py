#!/usr/bin/env python3
"""Tests for the create-only T1-T6 bundle (ADR 1229 increment 5; v10, decision 1972).

    python3 godot/data/underground/first-entry-prefix-v1/test_publish_qualified_stairs.py -v
"""
from __future__ import annotations

import struct
import unittest

import publish_qualified_stairs as PUB


class QualifiedStairsBundle(unittest.TestCase):
    """The published bundle is exactly what the publisher derives from its pinned inputs."""

    @classmethod
    def setUpClass(cls) -> None:
        """Build once; every test reads the same in-memory packet."""
        cls.built = PUB.build()

    def test_rebuild_is_byte_identical(self) -> None:
        """Every published file rebuilds byte for byte."""
        for name, raw in self.built.items():
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_structure_appends_the_dec050_stair_paces_to_the_ground_caps(self) -> None:
        """Decision 1972: content 12 on source 4; 26 ground caps, then every stair timing in milli-u/s: v9's rows 53-55
        at the same ticks (528,000 and 116,000), then rows 71-84."""
        structure = self.built["structure.ugconn"]
        ground = self.built["ground-pace.ugconn"]
        self.assertEqual(structure[48:136], ground[48:136])
        self.assertEqual(struct.unpack_from("<3q", structure, 48), (12, 1, 4))
        count = len(PUB.STAIR_PACES)
        rows = [struct.unpack_from("<7iq", structure, len(structure) - 8 - 36 * (count - r)) for r in range(count)]
        self.assertEqual([(row[0], row[5], row[6]) for row in rows[:3]],
                         [(53, 528000, 2), (54, 528000, 2), (55, 116000, 2)])
        self.assertEqual([row[0] for row in rows], [53, 54, 55] + list(range(71, 85)))
        self.assertTrue(all(row[6] == PUB.RATE_AUTHORED_MILLI for row in rows))

    def test_every_stair_timing_lands_on_dec050_ticks(self) -> None:
        """ceil(length x 30,000 / rate) is 30 a tread, 45 a half-turn and 90 a handoff, the 169 u retreat included,
        and each rate is the slowest that does (one milli-u/s less takes a tick more)."""
        lengths = {53: 528, 54: 528, 55: 174, 71: 343, 72: 343}
        for first in (73, 79):
            lengths.update(dict(zip(range(first, first + 6), (343, 528, 528, 174, 169, 343))))
        ticks = {528: 30, 174: 45, 343: 90, 169: 90}
        for row, rate in PUB.STAIR_PACES:
            length = lengths[row]
            self.assertEqual(-(-length * 30000 // rate), ticks[length], row)
            self.assertEqual(-(-length * 30000 // (rate - 1)), ticks[length] + 1, row)
        self.assertEqual(dict(PUB.STAIR_PACES)[77], 56334)

    def test_sill_stops_are_appended_after_v9s(self) -> None:
        """Decision 1972: the sill's A and U follow v9's 44 stops, on the sill's new LANDING; H is the prefix's L0
        station at (0, 0, -1536), 343 u before A, already a stop; the floor's stops wait for slice D's F40."""
        stops = PUB.stair_endpoints()
        self.assertEqual(len(stops), 4 + 18 + 2)
        self.assertEqual([s[1:3] + s[4:8] for s in stops[-2:]],
                         [[7, 8, 0, -896, -5463, 53], [7, 8, 0, -896, -5289, 54]])
        old = PUB.read_frontier((PUB.OLD / "frontier.ugfront").read_bytes())[4]
        self.assertEqual(old[3][4:7], [0, 0, PUB.L0_FAR + PUB.ARRIVAL + PUB.HANDOFF_EDGE_U], "H is claw-v6's L0 station")
        landings = PUB.landings()
        self.assertEqual(len(landings), 8)
        self.assertEqual(landings[7], [-1024, -896, -5632, 1024, -895, -5120])

    def test_ground_caps_carry_the_v2_claw_digest(self) -> None:
        """Only the header digest changes from the published content-10 caps; every row is theirs."""
        original = PUB.pinned(PUB.RUNTIME / "ground-pace.ugconn", PUB.GROUND_SHA)
        rebound = self.built["ground-pace.ugconn"]
        profile = self.built["mole-worker.ugprof"]
        self.assertEqual(rebound[:72] + rebound[104:], original[:72] + original[104:])
        self.assertEqual(rebound[72:104], profile[32 + 32 * PUB.CLAW_SOURCE:64 + 32 * PUB.CLAW_SOURCE])

    def test_workpieces_stage_each_tread_bearer_by_tread_geometry(self) -> None:
        """Row 65 for L0/T0; row 66 for T_k's left bearer, part 7a+1, turn 3, T0's translation moved one pitch."""
        raw = self.built["workpieces.ugwipc"]
        for assembly in range(8):
            row = struct.unpack_from("<6i", raw, 212 + 32 * assembly)
            self.assertEqual(row[5], 65 if assembly < 2 else 66)
            if assembly >= 2:
                k = assembly - 1
                rise = 64 if assembly == 7 else 0
                self.assertEqual(row[:5], (7 * assembly + 1, 3, 2304 + 512 * k, 320 - rise, -2816 - 512 * k))

    def test_formatter_refuses_paces_that_do_not_extend_the_ground_caps(self) -> None:
        """An authored row must follow the caps exactly; a changed cap is GROUND_SOURCE."""
        packet = {name: self.built[name] for name in PUB.K.FILES.values()} | \
            {"mole-worker.ugprof": self.built["mole-worker.ugprof"]}
        ground = bytearray(packet["ground-pace.ugconn"])
        struct.pack_into("<i", ground, 136 + 20, struct.unpack_from("<i", ground, 136 + 20)[0] + 1)
        packet["ground-pace.ugconn"] = bytes(ground)
        with self.assertRaisesRegex(ValueError, "GROUND_SOURCE"):
            PUB.K._linked(packet)


if __name__ == "__main__":
    unittest.main()
