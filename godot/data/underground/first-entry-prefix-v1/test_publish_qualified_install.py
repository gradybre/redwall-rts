#!/usr/bin/env python3
"""ADR 1202: the T0-selector successor bundle rebuilds byte-exactly and changes only two Frontier words."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location("qualified_install", Path(__file__).with_name("publish_qualified_install.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class QualifiedInstallTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = M.build()
        cls.old = M.read_old()

    def test_every_published_file_rebuilds_byte_exactly(self):
        for name, raw in self.out.items():
            self.assertEqual((M.OUTPUT / name).read_bytes(), raw, name)

    def test_only_the_frontier_changes(self):
        for name in M.OLD_SHA:
            if name != "frontier.ugfront":
                self.assertEqual(self.out[name], self.old[name], name)

    def test_frontier_changes_only_revision_and_t0_material(self):
        old, new = self.old["frontier.ugfront"], self.out["frontier.ugfront"]
        moved = [i for i, (a, b) in enumerate(zip(old, new)) if a != b]
        self.assertTrue(all(M.REVISION_AT <= i < M.REVISION_AT + 8 or M.T0_MATERIAL_AT <= i < M.T0_MATERIAL_AT + 4
                            for i in moved))
        self.assertEqual(struct.unpack_from("<q", new, 12)[0], 3)
        self.assertEqual(struct.unpack_from("<9i", new, 220), (0, 0, 0, 0, 1, 2, 4, 1, 2))
        self.assertEqual(struct.unpack_from("<9i", new, 256), (1, 1, 1, 1, 1, 6, 4, 10, 3))

    def test_refuses_a_foreign_t0_row_or_selector(self):
        bad = bytearray(self.old["frontier.ugfront"])
        struct.pack_into("<i", bad, M.T0_MATERIAL_AT, 2)
        with self.assertRaisesRegex(ValueError, "OLD_T0_INSTALL_ROW"):
            M.frontier(bytes(bad))
        bad = bytearray(self.old["frontier.ugfront"])
        struct.pack_into("<i", bad, M.endpoint_at(bytes(bad), 10) + 4 * 6, 2047)
        with self.assertRaisesRegex(ValueError, "SELECTOR_IDENTITY"):
            M.frontier(bytes(bad))

    def test_accessor_names_frontier_3_and_the_successor_paths(self):
        text = self.out["catalog_source.gd"].decode()
        self.assertIn("const FRONTIER_REVISION: int = 3", text)
        self.assertIn("const CONTENT_REVISION: int = 5", text)
        self.assertNotIn("qualified-haul-v2", text)

    def test_create_only(self):
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            M.main()


if __name__ == "__main__":
    unittest.main()
