#!/usr/bin/env python3
"""ADR 1206: content-6 runtime publication rebuilds byte-exactly and refuses every non-superset input."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import re
import struct
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
SPEC = importlib.util.spec_from_file_location("stone_runtime", Path(__file__).with_name("publish_stone_runtime.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
H = M.H
DIGESTS = re.compile(r"const DIGESTS: PackedStringArray = \[\n.*?\n\]", re.S)


class StoneRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = M.build()
        cls.old = (M.OLD / "mole-worker.ugprof").read_bytes()
        cls.wire = cls.out["mole-worker.ugprof"]

    def test_published_binary_files_rebuild_byte_exactly(self):
        for name in ("mole-worker.ugprof", "ground-pace.ugconn", "motion.ugmotion"):
            self.assertEqual((M.OUTPUT / name).read_bytes(), self.out[name], name)

    def test_accessor_and_manifest_match_except_renewable_consumer_pins(self):
        published = (M.OUTPUT / "catalog_source.gd").read_text()
        self.assertEqual(DIGESTS.sub("", published), DIGESTS.sub("", self.out["catalog_source.gd"].decode()))
        self.assertIn(f'const STONE_SOURCE_SHA: String = "{M.STONE_SOURCE_SHA}"', published)
        manifest = json.loads((M.OUTPUT / "manifest.json").read_text())
        rebuilt = json.loads(self.out["manifest.json"])
        for document in (manifest, rebuilt):
            document.pop("consumers")
            document.pop("renewals", None)
        self.assertEqual(manifest, rebuilt)

    def test_header_counts_and_paired_bank(self):
        self.assertEqual(struct.unpack_from("<8sIqIII", self.wire), (b"UGPROF01", 2, 6, 42, 377, 4))
        self.assertEqual(len(self.wire), 14840)
        self.assertEqual(2 * (len(self.wire) - 8), 29664)

    def test_new_rows_are_source_three_tool_free_stone_and_exact(self):
        fields, boxes = H.rows_of(self.wire, (6, 42, 377, 4))
        expected = [(2, 53, 1, 0, -1, 0, 1000, 1000), (3, -1, 0, 0, 0, 4, 0, 0), (3, -1, 0, 16384, 0, 4, 0, 0),
                    (3, 53, 0, 0, 0, 4, 1000, 1000), (3, 53, 0, 16384, 0, 4, 1000, 1000)]
        for row, want in zip(range(37, 42), expected):
            f = fields[row]
            self.assertEqual((f[0], f[6], f[7]), (3, -1, -1))
            self.assertEqual((f[4], f[8], f[10], f[11], f[16], f[17], f[19], f[20]), want)
            self.assertEqual((f[21], f[22]), (15, 0))
        self.assertEqual([len(b) for b in boxes[37:]], [7, 9, 9, 9, 9])
        self.assertEqual(boxes[37][2], (-598, 447, -598, 598, 821, 598, 0))
        self.assertEqual([H.rotate_quarter(b) for b in boxes[38]], boxes[39])
        self.assertEqual([H.rotate_quarter(b) for b in boxes[40]], boxes[41])

    def test_superset_refuses_any_changed_prefix_byte(self):
        M.check_superset(self.old, self.wire)
        cases = {"SOURCES_0_2": 40, "ROWS_0_36": 160 + 98 * 7 + 3, "BOXES_0_333": 160 + 98 * 42 + 28 * 100}
        for code, at in cases.items():
            bad = bytearray(self.wire)
            bad[at] ^= 1
            with self.assertRaisesRegex(ValueError, code):
                M.check_superset(self.old, bytes(bad))

    def test_key_order_is_checked_within_source_three(self):
        M.check_key_order(self.wire)
        rows = M.new_rows(M.read_inputs())
        swapped = M.build_wire(self.old, [rows[1], rows[0], *rows[2:]])
        with self.assertRaisesRegex(ValueError, "KEY_ORDER"):
            M.check_key_order(swapped)

    def test_ground_pace_adds_only_a_cap_row_for_the_stone_carry(self):
        ground = self.out["ground-pace.ugconn"]
        old = (M.OLD / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<I", ground, 44)[0], 15)
        self.assertEqual(struct.unpack_from("<q", ground, 48)[0], 6)
        self.assertEqual(ground[136:136 + 14 * 36], old[136:-8])
        self.assertEqual(H.PACE.unpack_from(ground, 136 + 36 * 14), (37, -1, 0, 1, 1, 0, 0, 1))

    def test_motion_rebind_changes_only_bound_words(self):
        motion = self.out["motion.ugmotion"]
        self.assertEqual(struct.unpack_from("<q", motion, 16)[0], 6)
        self.assertEqual(motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex(), H.sha(self.wire))

    def test_stone_item_is_53_with_the_wood_mass(self):
        self.assertEqual(M.stone_id(M.read_inputs()["items"]), 53)

    def test_inputs_are_pinned_and_output_is_create_only(self):
        with patch.dict(M.INPUTS, {"rows": (M.INPUTS["image"][0], M.INPUTS["rows"][1])}):
            with self.assertRaisesRegex(ValueError, "INPUT_ROWS"):
                M.read_inputs()
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            M.main()


if __name__ == "__main__":
    unittest.main()
