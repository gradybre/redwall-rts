#!/usr/bin/env python3
"""ADR 1200: content-5 runtime publication rebuilds byte-exactly and refuses every non-superset input."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import re
import struct
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("haul_runtime", Path(__file__).with_name("publish_haul_runtime.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
DIGESTS = re.compile(r"const DIGESTS: PackedStringArray = \[\n.*?\n\]", re.S)


class HaulRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = M.build()
        cls.old = (M.OLD / "mole-worker.ugprof").read_bytes()
        cls.wire = cls.out["mole-worker.ugprof"]

    def test_published_binary_files_rebuild_byte_exactly(self):
        for name in ("mole-worker.ugprof", "ground-pace.ugconn", "motion.ugmotion"):
            self.assertEqual((M.OUTPUT / name).read_bytes(), self.out[name], name)

    def test_accessor_and_manifest_match_except_renewable_consumer_pins(self):
        # ADR 1192 renewals may change only DIGESTS and the manifest's consumers/renewals.
        published = (M.OUTPUT / "catalog_source.gd").read_text()
        self.assertEqual(DIGESTS.sub("", published), DIGESTS.sub("", self.out["catalog_source.gd"].decode()))
        self.assertIn(f'const HAUL_SOURCE_SHA: String = "{M.HAUL_SOURCE_SHA}"', published)
        manifest = json.loads((M.OUTPUT / "manifest.json").read_text())
        rebuilt = json.loads(self.out["manifest.json"])
        for document in (manifest, rebuilt):
            document.pop("consumers")
            document.pop("renewals", None)
        self.assertEqual(manifest, rebuilt)

    def test_header_counts_and_paired_bank(self):
        self.assertEqual(struct.unpack_from("<8sIqIII", self.wire), (b"UGPROF01", 2, 5, 37, 334, 3))
        self.assertEqual(len(self.wire), 13114)
        self.assertEqual(2 * (len(self.wire) - 8), 26212)

    def test_new_rows_are_source_two_tool_free_and_exact(self):
        fields, boxes = M.rows_of(self.wire, (5, 37, 334, 3))
        wood, haul = M.compiled_ids(M.INPUTS["items"][0].read_bytes())
        self.assertEqual((wood, haul), (60, 0))
        expected = [(0, -1, 1, 0, -1, 0, 0, 0), (1, -1, 1, 0, -1, 0, 0, 0), (2, wood, 1, 0, -1, 0, 1000, 1000),
                    (3, -1, 0, 0, haul, 4, 0, 0), (3, -1, 0, 16384, haul, 4, 0, 0),
                    (3, wood, 0, 0, haul, 4, 1000, 1000), (3, wood, 0, 16384, haul, 4, 1000, 1000)]
        for row, want in zip(range(30, 37), expected):
            f = fields[row]
            self.assertEqual((f[0], f[6], f[7]), (2, -1, -1))
            self.assertEqual((f[4], f[8], f[10], f[11], f[16], f[17], f[19], f[20]), want)
            self.assertEqual((f[21], f[22]), (15, 0))
        self.assertEqual([len(b) for b in boxes[30:]], [5, 5, 7, 9, 9, 9, 9])
        self.assertEqual(boxes[32][2], (-714, 447, -714, 714, 704, 714, 0))

    def test_rotation_convention_matches_published_rows_13_and_17(self):
        M.check_rotation(self.old)
        _, boxes = M.rows_of(self.wire, (5, 37, 334, 3))
        self.assertEqual([M.rotate_quarter(b) for b in boxes[33]], boxes[34])
        self.assertEqual([M.rotate_quarter(b) for b in boxes[35]], boxes[36])
        with patch.object(M, "rotate_quarter", lambda b: (-b[5], b[1], b[0], -b[2], b[4], b[3], b[6])):
            with self.assertRaisesRegex(ValueError, "ROTATION_CONVENTION"):
                M.check_rotation(self.old)

    def test_superset_refuses_any_changed_prefix_byte(self):
        M.check_superset(self.old, self.wire)
        cases = {"SOURCES_0_1": 40, "ROWS_0_29": 128 + 98 * 7 + 3, "BOXES_0_280": 128 + 98 * 37 + 28 * 100}
        for code, at in cases.items():
            bad = bytearray(self.wire)
            bad[at] ^= 1
            with self.assertRaisesRegex(ValueError, code):
                M.check_superset(self.old, bytes(bad))

    def test_key_order_is_checked_within_source_two(self):
        M.check_key_order(self.wire)
        rows = M.new_rows(M.read_inputs())
        swapped = M.build_wire(self.old, [rows[1], rows[0], *rows[2:]])
        with self.assertRaisesRegex(ValueError, "KEY_ORDER"):
            M.check_key_order(swapped)

    def test_ground_pace_adds_only_cap_rows_for_walk_and_carry(self):
        ground = self.out["ground-pace.ugconn"]
        old = (M.OLD / "ground-pace.ugconn").read_bytes()
        self.assertEqual(struct.unpack_from("<I", ground, 44)[0], 14)
        self.assertEqual(struct.unpack_from("<q", ground, 48)[0], 5)
        self.assertEqual(ground[136:136 + 12 * 36], old[136:-8])
        tail = [M.PACE.unpack_from(ground, 136 + 36 * r) for r in (12, 13)]
        self.assertEqual(tail, [(31, -1, 0, 1, 1, 0, 0, 1), (32, -1, 0, 1, 1, 0, 0, 1)])

    def test_motion_rebind_changes_only_bound_words(self):
        motion = self.out["motion.ugmotion"]
        self.assertEqual(struct.unpack_from("<q", motion, 16)[0], 5)
        self.assertEqual(motion[M.BYTE_AT + 160:M.BYTE_AT + 192].hex(), M.sha(self.wire))

    def test_inputs_are_pinned_and_output_is_create_only(self):
        with patch.dict(M.INPUTS, {"rows": (M.INPUTS["walk"][0], M.INPUTS["rows"][1])}):
            with self.assertRaisesRegex(ValueError, "INPUT_ROWS"):
                M.read_inputs()
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            M.main()


if __name__ == "__main__":
    unittest.main()
