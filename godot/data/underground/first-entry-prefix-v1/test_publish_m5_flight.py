#!/usr/bin/env python3
"""Tests for the create-only M5 bundle (decisions 2043 and 2044).

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
                if table == 0 and index == 7: expected[6] = 2 + 22
                self.assertEqual(new[index], expected, (table, index))

    def test_counts_are_2043s(self) -> None:
        """36 installs, 26 cut groups, 154 cube episodes (54 top metre, 100 deep), 232 parts."""
        install, station, cut, bearing, endpoint, episode = self.frontier
        self.assertEqual([len(install), len(cut), len(episode)], [36, 26, 154])
        layers = [sum(1 for e in episode if e[4] == -1024 * layer) for layer in range(5)]
        self.assertEqual(layers, [54, 40, 30, 20, 10])
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
        self.assertEqual(len(strips), 22 + 17 + 12 + 7 + 2)
        for row in strips:
            if row[1] < 0:
                continue
            cube = episode[row[1]]
            self.assertEqual(cube[0], -1024)
            self.assertEqual((cube[4], cube[2], cube[5]), (row[7], row[5], row[8]))

    def test_deep_episodes_follow_2044s_order(self) -> None:
        """Row-major from the end wall, column 0 then 1, at prefix 8 + 7(j - 1); stations 406 u inside the uphill row."""
        episode, station = self.frontier[5], self.frontier[1]
        deep = episode[54:]
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


if __name__ == "__main__":
    sys.exit(unittest.main())
