#!/usr/bin/env python3
"""Tests for the create-only M5 bundle (decisions 2043 and 2044; decision 2046: `qualified-stairs-m5-v3`, the widened
foot).

    python3 godot/data/underground/first-entry-prefix-v1/test_publish_m5_flight.py -v
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import sys
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("publish_m5_flight", HERE / "publish_m5_flight.py")
PUB = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUB)
DUMP = PUB.V10


def tables(raw: bytes) -> list:
    """Decode a Frontier into its six tables (endpoint rows carry their travel row)."""
    return DUMP.read_frontier(raw)


class M5Bundle(unittest.TestCase):
    """The published bundle is exactly what the publisher derives, and its numbers are 2043 §3's."""

    @classmethod
    def setUpClass(cls) -> None:
        """Build once."""
        PUB.select(5)
        cls.built = PUB.build()
        cls.frontier = tables(cls.built["frontier.ugfront"])
        cls.v10 = tables((HERE / "qualified-stairs-v10/frontier.ugfront").read_bytes())

    def test_rebuild_is_byte_identical(self) -> None:
        """Every published file rebuilds byte for byte."""
        for name, raw in self.built.items():
            self.assertEqual((PUB.OUTPUT / name).read_bytes(), raw, name)

    def test_v10s_rows_are_kept_first(self) -> None:
        """Every v10 row keeps its index; only v10's sill INSTALL row grows by landing 1's strips."""
        for table, (old, new) in enumerate(zip(self.v10, self.frontier)):
            for index, row in enumerate(old):
                expected = list(row)
                if table == 0 and index == 7: expected[6] = 2 + 3 + 20  # Landing 1's deck slab, bands, rows 7-26.
                self.assertEqual(new[index], expected, (table, index))

    def test_counts_are_2043s_with_the_widened_foot(self) -> None:
        """36 installs, 26 cut groups, 174 cube episodes: 2043's 154 (54 top metre, 100 deep) and decision 2046's 20
        side cubes, four a layer; 232 parts."""
        install, station, cut, bearing, endpoint, episode = self.frontier
        self.assertEqual([len(install), len(cut), len(episode)], [36, 26, 174])
        layers = [sum(1 for e in episode if e[4] == -1024 * layer) for layer in range(5)]
        self.assertEqual(layers, [58, 44, 34, 24, 14])
        sides = [e for e in episode if e[0] < -1024 or e[3] > 1024]
        self.assertEqual(len(sides), 20)
        self.assertEqual({(e[2], e[0]) for e in sides}, {(z, x) for z in (-27648, -26624) for x in (-2048, 1024)})
        catalog = self.built["structure.ugconn"]
        self.assertEqual(struct.unpack_from("<7I", catalog, 20)[3], 232)

    def test_the_cut_groups_are_exactly_the_episodes_cubes(self) -> None:
        """The entry plan's claims (the CUT rows) cover exactly the 154 cubes the episodes cut, once each."""
        cubes = set()
        for box in (row[:6] for row in self.frontier[2]):
            for y in range(box[1], box[4], 1024):
                for z in range(box[2], box[5], 1024):
                    for x in range(box[0], box[3], 1024):
                        self.assertNotIn((x, y, z), cubes)
                        cubes.add((x, y, z))
        episodes = {(row[0], row[1], row[2]) for row in self.frontier[5]}
        self.assertEqual(cubes, episodes)

    def test_every_deep_strip_is_retired_by_its_rows_first_cube(self) -> None:
        """A strip under a deep row names the episode of that row's first cut cube (column 0), whose cube lies directly
        under it; a landing's own rows are never retired."""
        bearing, episode = self.frontier[3], self.frontier[5]
        strips = [row for row in bearing if row[0] == PUB.STRIP_KIND]
        self.assertEqual(len(strips), sum(3 + max(0, 27 - (5 * j + 2)) for j in range(1, 6)))
        for row in strips:
            if row[1] < 0:
                continue
            cube = episode[row[1]]
            self.assertEqual(cube[0], -1024)
            self.assertEqual((cube[4], cube[2], cube[5]), (row[7], row[5], row[8]))

    def test_the_side_cubes_are_struck_on_their_top_faces(self) -> None:
        """Decision 2046: each foot row's side cubes: the top metre from a land station 406 u outside the widened cut,
        after the slot's top metre; layer j + 1 first in landing j's stage, end row first, west then east, from a
        lateral station 406 u in from the slot's side on that row's slot floor, facing out (58 west, 62 east), at the
        stage's prefix; no bearing is retained under a side cube."""
        episode, station, endpoint = self.frontier[5], self.frontier[1], self.frontier[4]
        top = [e for e in episode[:58] if e[0] < -1024 or e[3] > 1024]
        self.assertEqual(top, episode[54:58], "after every slot cube of the top metre")
        for e in top:
            s = station[e[8]]
            self.assertEqual([abs(s[1]), s[2], s[3]], [PUB.SIDE_LAND_X, 0, e[2] + 512])
        for landing in range(1, 5):
            first = 58 + sum(44 - 10 * (j - 1) for j in range(1, landing))
            stage = episode[first:first + 4]
            self.assertEqual([(e[2], e[0]) for e in stage], [(-27648, -2048), (-27648, 1024), (-26624, -2048),
                                                            (-26624, 1024)], "landing %d" % landing)
            for e in stage:
                s = station[e[8]]
                west = e[0] < 0
                self.assertEqual([e[7], e[13], e[14]], [8 + 7 * (landing - 1), 0, 0])
                self.assertEqual([s[1], s[2]], [-PUB.LATERAL_X if west else PUB.LATERAL_X, -1024 * landing])
                self.assertEqual([s[4], s[5]], [16384, 58] if west else [49152, 62])
                self.assertEqual(s[3], PUB.END_WALL + PUB.LATERAL_BEHIND[-e[2] // 1024 - 1])
                self.assertEqual(endpoint[e[17]][7], PUB.DEEP_TRAVEL)

    def test_deep_episodes_follow_2044s_order(self) -> None:
        """Row-major from the end wall, column 0 then 1, at prefix 8 + 7(j - 1); stations 406 u inside the uphill row.
        Decision 2046: each stage's four side cubes come first."""
        episode, station = self.frontier[5], self.frontier[1]
        deep = [e for e in episode[58:] if -1024 <= e[0] and e[3] <= 1024]
        self.assertEqual([e[7] for e in deep[:40]], [8] * 40)
        self.assertEqual([e[7] for e in deep[-10:]], [29] * 10)
        self.assertEqual([(e[2], e[0]) for e in deep[:4]], [(-27648, -1024), (-27648, 0), (-26624, -1024), (-26624, 0)])
        for e in deep:
            s = station[e[8]]
            self.assertEqual(s[3], e[5] + PUB.DEEP_INSIDE)
            self.assertEqual(s[2], e[4])
            self.assertEqual([s[4], s[5]], [0, PUB.DIG_FORWARD])
            self.assertTrue(e[0] <= s[1] + 224 < e[3], "row 56's contact lands in the cube's column")

    def test_bill_is_2043s(self) -> None:
        """Fixtures wood 39,000 and 261,200 mWU over 36 recipes (five T0s at T0's bill)."""
        recipe = self.built["recipes.ugrecp"]
        rows = [struct.unpack_from("<iiq8sq", recipe, 116 + 80 * r) for r in range(36)]
        self.assertEqual(sum(r[4] for r in rows), PUB.FIXTURE_WOOD)
        self.assertEqual(sum(r[2] for r in rows), 261200)


class M2Bundle(unittest.TestCase):
    """Decision 2044 (P-2044-15): the M2 interim is the same construction with the first two modules only."""

    @classmethod
    def setUpClass(cls) -> None:
        """Build the M2 bundle once, then restore M5."""
        PUB.select(2)
        try:
            cls.built = PUB.build()
            cls.output = PUB.OUTPUT
        finally:
            PUB.select(5)
        cls.frontier = tables(cls.built["frontier.ugfront"])
        cls.m5 = tables((HERE / "qualified-stairs-m5-v1/frontier.ugfront").read_bytes())

    def test_rebuild_is_byte_identical(self) -> None:
        """Every published M2 file rebuilds byte for byte."""
        self.assertEqual(self.output.name, "qualified-stairs-m2-v1")
        for name, raw in self.built.items():
            self.assertEqual((self.output / name).read_bytes(), raw, name)

    def test_counts(self) -> None:
        """15 installs, 11 cut groups, 34 one-cube episodes (24 top metre, 10 deep), 97 parts."""
        install, station, cut, bearing, endpoint, episode = self.frontier
        self.assertEqual([len(install), len(station), len(cut), len(bearing), len(endpoint), len(episode)],
                         [15, 49, 11, 82, 97, 34])
        self.assertEqual([sum(1 for e in episode if e[4] == -1024 * layer) for layer in range(3)], [24, 10, 0])
        self.assertEqual(struct.unpack_from("<7I", self.built["structure.ugconn"], 20)[3], 97)

    def test_v10s_rows_lead_as_in_m5(self) -> None:
        """M2 keeps v10's rows first, as M5 does; only the sill's strip count differs (landing 1's rows 5-11)."""
        v10 = tables((HERE / "qualified-stairs-v10/frontier.ugfront").read_bytes())
        for table, old in enumerate(v10):
            for index, row in enumerate(old):
                expected = list(row)
                if table == 0 and index == 7: expected[6] = 2 + 3 + 5  # Landing 1's deck slab, bands, rows 7-11.
                self.assertEqual(self.frontier[table][index], expected, (table, index))


if __name__ == "__main__":
    sys.exit(unittest.main())
