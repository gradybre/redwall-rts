#!/usr/bin/env python3
"""Tests for the create-only claw first-entry bundle (ADR 1217 step 4e).

    python3 godot/data/underground/first-entry-prefix-v1/test_publish_qualified_claw.py -v
"""
from __future__ import annotations

import struct
import unittest

import publish_qualified_claw as PUB


class QualifiedClawBundle(unittest.TestCase):
    """The published bundle is exactly what the publisher builds from its pinned inputs."""

    def test_rebuild_is_byte_identical(self) -> None:
        """Every wire rebuilds byte for byte."""
        for name, raw in PUB.build().items():
            if name not in ("catalog_source.gd", "manifest.json"):
                self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_frontier_binds_source_four_and_moves_the_cut_stations(self) -> None:
        """Revision 5, content 9, source 4; the six cut stations and endpoints 4-9 at x = +-1,430."""
        raw = (PUB.OUTPUT / "frontier.ugfront").read_bytes()
        self.assertEqual(struct.unpack_from("<qqqqqq", raw, 12)[0], 5)
        self.assertEqual(struct.unpack_from("<q", raw, 52)[0], 9)
        self.assertEqual(struct.unpack_from("<i", raw, 64)[0], 4)
        xs = [struct.unpack_from("<9i", raw, PUB.station_at(raw, i))[1] for i in range(2, 8)]
        self.assertEqual(xs, [-1430, 1430] * 3)
        travel = [struct.unpack_from("<7ii", raw, PUB.endpoint_at(raw, i))[7] for i in range(14)]
        self.assertEqual(travel, [43, 43, 47, 43] + [42] * 9 + [47])

    def test_workpieces_bind_paw_handling(self) -> None:
        """Program source 5 and set-down row 59 for both assemblies."""
        raw = (PUB.OUTPUT / "workpieces.ugwipc").read_bytes()
        self.assertEqual(struct.unpack_from("<q", raw, 76)[0], 5)
        self.assertEqual([struct.unpack_from("<6i", raw, 212 + 32 * r)[5] for r in range(2)], [59, 59])

    def test_structure_and_ground_headers_agree(self) -> None:
        """The structure binds content 9 and source 4 with the same header as the ground caps."""
        structure = (PUB.OUTPUT / "structure.ugconn").read_bytes()
        ground = (PUB.OUTPUT / "ground-pace.ugconn").read_bytes()
        self.assertEqual(structure[48:136], ground[48:136])
        self.assertEqual(struct.unpack_from("<3q", structure, 48), (9, 1, 4))

    def test_formatter_refuses_a_shared_set_down_source(self) -> None:
        """ADR 1190: the set-down program must differ from the Frontier source."""
        built = PUB.build()
        packet = {name: built[name] for name in PUB.K.FILES.values()} | {"mole-worker.ugprof": built["mole-worker.ugprof"]}
        pieces = bytearray(packet["workpieces.ugwipc"])
        pieces[180:212] = packet["frontier.ugfront"][188:220]
        pieces[76:84] = struct.pack("<q", 4)
        packet["workpieces.ugwipc"] = bytes(pieces)
        with self.assertRaisesRegex(ValueError, "ENTRY_CONSTANTS_WORKPIECES_NOT_DISTINCT"):
            PUB.K._linked(packet)


if __name__ == "__main__":
    unittest.main()
