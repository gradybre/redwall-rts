#!/usr/bin/env python3
"""ADR 1206: the content-6 first-entry bundle rebuilds byte-exactly and changes only bound words."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location("qualified_stone", Path(__file__).with_name("publish_qualified_stone.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class QualifiedStoneTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = M.build()
        cls.old, _, _ = M.read_old()

    def test_every_published_file_rebuilds_byte_exactly(self):
        for name, raw in self.out.items():
            self.assertEqual((M.OUTPUT / name).read_bytes(), raw, name)

    def test_structure_is_v4_geometry_with_content_6_and_fifteen_paces(self):
        new, old = self.out["structure.ugconn"], self.old["structure.ugconn"]
        self.assertEqual(struct.unpack_from("<8sIq7I3q", new),
                         (b"UGCONN01", 1, 1, 1, 2, 26, 14, 56, 1, 15, 6, 1, 0))
        self.assertEqual(new[72:-8 - 15 * 36], old[72:-8 - 14 * 36])
        self.assertEqual(new[-8 - 15 * 36:-8], self.out["ground-pace.ugconn"][136:-8])

    def test_linked_files_change_only_content_and_digests(self):
        for name in ("assemblies.ugasmb", "recipes.ugrecp", "frontier.ugfront", "workpieces.ugwipc"):
            old, new = self.old[name], self.out[name]
            self.assertEqual(len(old), len(new))
            spans = [(a, a + 32) for a in M.LINKS[name]]
            if name in M.CONTENT_WORDS:
                spans.append((M.CONTENT_WORDS[name], M.CONTENT_WORDS[name] + 8))
            moved = [i for i, (a, b) in enumerate(zip(old, new)) if a != b]
            self.assertTrue(all(any(lo <= i < hi for lo, hi in spans) for i in moved), name)

    def test_accessor_names_content_6_frontier_4_and_the_successor_paths(self):
        text = self.out["catalog_source.gd"].decode()
        self.assertIn("const CONTENT_REVISION: int = 6", text)
        self.assertIn("const FRONTIER_REVISION: int = 4", text)
        self.assertIn(f'const PROFILE_SHA: String = "{M.NEW_PROFILE_SHA}"', text)
        self.assertNotIn("qualified-landing-v4", text)

    def test_relink_refuses_a_stale_content_word(self):
        stale = bytearray(self.old["workpieces.ugwipc"])
        struct.pack_into("<q", stale, 52, 4)
        with self.assertRaisesRegex(ValueError, "CONTENT_WORD_workpieces.ugwipc"):
            M.relink("workpieces.ugwipc", bytes(stale), self.old, self.out)

    def test_create_only(self):
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            M.main()


if __name__ == "__main__":
    unittest.main()
