"""Independent wire and source-identity checks for the additive offline ground pace compiler."""
from pathlib import Path
import struct
import unittest

import compile_ground_pace as compiler


class GroundPaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wire, cls.manifest = compiler.build()
        cls.profile = (compiler.ROOT / compiler.PROFILE_PATH).read_bytes()
        cls.identity = cls.manifest["movement"]

    def test_exact_actual_rows_and_zero_tables(self):
        self.assertEqual(self.wire[:8], b"UGCONN01")
        self.assertEqual(struct.unpack_from("<Iq7I3q", self.wire, 8),
                         (2, 1, 0, 0, 0, 0, 0, 0, 9, 2, 1, 0))
        self.assertEqual(len(self.wire), 468)
        for i in range(9):
            self.assertEqual(struct.unpack_from("<7iq", self.wire, 136 + 36 * i),
                             (i + 1, -1, 0, 1, 1, 0, 0, 1))
        self.assertEqual(self.wire[-8:], b"UGCEND01")
        self.assertEqual(self.manifest["excluded_non_walk"][0], {"profile_id": 0, "mode": 0})
        self.assertEqual([r["profile_id"] for r in self.manifest["rows"]], list(range(1, 10)))

    def test_rebuild_matches_all_committed_artifact_bytes(self):
        base = Path(__file__).resolve().parent
        self.assertEqual(self.wire, (base / compiler.OUTPUT_NAME).read_bytes())
        import json
        self.assertEqual(self.manifest, json.loads((base / "manifest.json").read_text()))

    def test_profile_shape_is_bounded_before_unpack(self):
        for image in (self.profile[:20], self.profile[:-1], self.profile + b"x"):
            with self.assertRaises(ValueError):
                compiler.walking_rows(image, self.identity, 1, 15)
        image = bytearray(self.profile)
        struct.pack_into("<I", image, 20, 0xffffffff)
        with self.assertRaisesRegex(ValueError, "HEADER"):
            compiler.walking_rows(image, self.identity, 1, 15)

    def test_current_walk_identity_and_certificate_are_mandatory(self):
        for offset, value in ((4, 7), (8, 1), (72, 0), (96, 7)):
            image = bytearray(self.profile)
            if offset == 96:
                image[64 + 98 + offset] = value
            else:
                struct.pack_into("<q" if offset == 72 else "<i", image, 64 + 98 + offset, value)
            with self.assertRaisesRegex(ValueError, "IDENTITY"):
                compiler.walking_rows(image, self.identity, 1, 15)

    def test_no_walk_rows_cannot_form_an_empty_pace_catalog(self):
        image = bytearray(self.profile)
        for row in range(26):
            struct.pack_into("<i", image, 64 + 98 * row + 16, 0)
        with self.assertRaisesRegex(ValueError, "PACE_COUNT"):
            compiler.walking_rows(image, self.identity, 1, 15)

    def test_duplicate_and_reordered_rows_refuse(self):
        for rows in ([self.manifest["rows"][0]] * 2, list(reversed(self.manifest["rows"]))):
            with self.assertRaisesRegex(ValueError, "PACE_ORDER"):
                compiler.encode(2, self.profile[32:64], 1, bytes(32), self.identity, rows)

    def test_movement_identity_is_derived_from_actual_named_tables(self):
        self.assertEqual(self.identity, {"profile_id": 1, "profile_key": "starter.ground.adult.mole",
                         "profile_revision": 1, "species_id": 6, "life_stage": 0})
        movement = (compiler.ROOT / compiler.MOVEMENT_PATH).read_text()
        residents = (compiler.ROOT / compiler.RESIDENTS_PATH).read_text()
        with self.assertRaisesRegex(ValueError, "MOVEMENT_KEY"):
            compiler.movement_identity(movement.replace("starter.ground.adult.mole", "unknown.ground.adult.mole"), residents)
        with self.assertRaisesRegex(ValueError, "MOVEMENT_SPECIES"):
            compiler.movement_identity(movement.replace('[&"mouse", &"mole", &"otter", &"squirrel"]',
                                                        '[&"mouse", &"shrew", &"otter", &"squirrel"]'), residents)


if __name__ == "__main__":
    unittest.main()
