#!/usr/bin/env python3
"""Tests for the create-only T1-T6 bundle (ADR 1229 increment 5).

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
        """Content 10 on source 4; 26 ground caps, then descent/ascent at 528 u/s and the half-turn at 116 u/s."""
        structure = self.built["structure.ugconn"]
        ground = self.built["ground-pace.ugconn"]
        self.assertEqual(structure[48:136], ground[48:136])
        self.assertEqual(struct.unpack_from("<3q", structure, 48), (10, 1, 4))
        rows = [struct.unpack_from("<7iq", structure, len(structure) - 8 - 36 * (3 - r)) for r in range(3)]
        self.assertEqual([(row[0], row[5], row[6]) for row in rows], [(53, 528, 1), (54, 528, 1), (55, 116, 1)])

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
