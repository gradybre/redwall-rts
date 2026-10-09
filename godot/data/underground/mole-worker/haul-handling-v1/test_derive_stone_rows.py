#!/usr/bin/env python3
"""Stone row geometry (ADR 1206). Run with --palette/--grip-palette/--world-basis (world-yaw-v1.ugyaw)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import unittest

import derive_stone_rows as R

ARGS = None


class StoneRowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stored = json.loads(R.OUT.read_text())

    def test_rederivation_is_byte_identical(self):
        raw = R.D.encode(R.derive(ARGS.palette, ARGS.grip_palette, ARGS.world_basis))
        self.assertEqual(raw, R.OUT.read_bytes())

    def test_rows_are_the_three_stone_rows(self):
        rows = {row["name"]: row for row in self.stored["rows"]}
        self.assertEqual(set(rows), {"haul_carry_stone_1000", "haul_load_stone_1000", "haul_unload_stone_1000"})
        self.assertEqual((rows["haul_carry_stone_1000"]["cargo"], rows["haul_carry_stone_1000"]["yaw_kind_name"]),
                         ("stone", "YAW_ALL"))
        self.assertEqual(rows["haul_load_stone_1000"]["cargo"], None)
        self.assertEqual(rows["haul_unload_stone_1000"]["quantity_milli"], [1000, 1000])
        for row in rows.values():
            self.assertEqual((row["tool"], row["tool_variant"]), (-1, -1))

    def test_station_is_wood_station_and_both_contacts_are_exact(self):
        station = self.stored["station"]
        self.assertEqual((station["R_minus_S_u"], station["S_u"]), ([0, 0, 576], [0, 0, -576]))
        self.assertEqual([c["hand_bone"] for c in station["grip_contacts"]], [15, 19])

    def test_carry_boxes_are_radially_swept(self):
        carry = next(r for r in self.stored["rows"] if r["mode_name"] == "CARRY")
        for box in carry["boxes"]:
            x0, _, z0, x1, _, z1 = box["bounds_u"]
            self.assertEqual((x0, x1), (z0, z1))
            self.assertEqual(x0, -x1)

    def test_floor_portions_lie_on_the_floor_plane(self):
        for row in self.stored["rows"]:
            for box in row["boxes"]:
                low, high = box["bounds_u"][1], box["bounds_u"][4]
                self.assertTrue(low >= -1 and (high > 0 or (low, high) == (-1, 0)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--world-basis", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
