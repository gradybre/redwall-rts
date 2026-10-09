#!/usr/bin/env python3
"""ADR 1202 blocker 3: the split-landing successor rebuilds byte-exactly and changes only the named Frontier words."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location("qualified_landing", Path(__file__).with_name("publish_qualified_landing.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class QualifiedLandingTests(unittest.TestCase):
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

    def test_frontier_changes_only_the_split_landing_words(self):
        old, new = self.old["frontier.ugfront"], self.out["frontier.ugfront"]
        insert = M.endpoint_at(old, M.OLD_ENDPOINTS)
        self.assertEqual(new[insert + 80:], old[insert:], "episode table and end marker move unchanged")
        allowed = [(M.REVISION_AT, M.REVISION_AT + 8), (M.COUNTS_AT + 16, M.COUNTS_AT + 20),
                   (M.endpoint_at(old, M.CONTACT) + 28, M.endpoint_at(old, M.CONTACT) + 40),
                   (M.install_at(1) + 32, M.install_at(1) + 36)]
        moved = [i for i, (a, b) in enumerate(zip(old[:insert], new[:insert])) if a != b]
        self.assertTrue(all(any(lo <= i < hi for lo, hi in allowed) for i in moved))
        self.assertEqual(struct.unpack_from("<q", new, 12)[0], 4)
        self.assertEqual(M.counts(new), (2, 8, 2, 10, 14, 6))
        self.assertEqual(struct.unpack_from("<9i", new, M.install_at(0)), (0, 0, 0, 0, 1, 2, 4, 1, 2))
        self.assertEqual(struct.unpack_from("<9i", new, M.install_at(1)), (1, 1, 1, 1, 1, 6, 4, 10, 13))

    def test_contact_takes_h_approach_and_arrival_selectors_are_derived(self):
        new = self.out["frontier.ugfront"]
        self.assertEqual(M.endpoint(new, 0)[7:], (2, 1), "H approaches on source 2")
        self.assertEqual(M.endpoint(new, 3), (1, 0, 1, 2, 0, 0, -1536, 2, 1), "narrow WORK contact on source 2")
        self.assertEqual(M.endpoint(new, 12), (1, 0, 1, 0, 0, 0, -664, 12, 1), "arrival sized by all-yaw 12")
        self.assertEqual(M.endpoint(new, 13), (1, 0, 1, 0, 0, 0, -664, 6, 1), "arrival as the backward retreat")

    def test_arrival_air_stops_at_the_t0_bearer_and_stance_stays_on_the_deck(self):
        boxes = M.profile_boxes(self.old["mole-worker.ugprof"], 12)
        z = M.arrival_point(self.old)[2]
        self.assertEqual(z + min(b[2] for b in boxes if b[6] in M.AIR_ROLES), -1920, "touches, never overlaps")
        stance = [b for b in boxes if b[6] == M.STANCE][0]
        self.assertLessEqual(z + stance[5], 0, "stance ends on the L0 LANDING datum")

    def test_refuses_a_foreign_predecessor(self):
        bad = dict(self.old)
        raw = bytearray(self.old["frontier.ugfront"])
        struct.pack_into("<i", raw, M.install_at(1) + 32, 2)
        bad["frontier.ugfront"] = bytes(raw)
        with self.assertRaisesRegex(ValueError, "OLD_T0_INSTALL_ROW"):
            M.frontier(bad)
        raw = bytearray(self.old["frontier.ugfront"])
        struct.pack_into("<i", raw, M.endpoint_at(bytes(raw), M.CONTACT) + 24, -1024)
        bad["frontier.ugfront"] = bytes(raw)
        with self.assertRaisesRegex(ValueError, "OLD_CONTACT"):
            M.frontier(bad)

    def test_accessor_names_frontier_4_and_the_successor_paths(self):
        text = self.out["catalog_source.gd"].decode()
        self.assertIn("const FRONTIER_REVISION: int = 4", text)
        self.assertIn("const ENDPOINT_COUNT: int = 14", text)
        self.assertIn("const CONTENT_REVISION: int = 5", text)
        self.assertNotIn("qualified-install-v3", text)

    def test_create_only(self):
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            M.main()


if __name__ == "__main__":
    unittest.main()
