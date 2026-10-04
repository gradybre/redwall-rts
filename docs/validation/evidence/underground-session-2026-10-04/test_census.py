#!/usr/bin/env python3
"""Negative source mutations retain exact configured composition and the existing reservation."""
from pathlib import Path
import tempfile
import unittest
import census


class SessionCensus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (census.ROOT / census.SOURCE).read_text()

    def refuses(self, old, new):
        self.assertIn(old, self.source)
        with self.assertRaises(ValueError):
            census.census(self.source.replace(old, new, 1))

    def test_exact_source_and_joint_arithmetic(self):
        result = census.census(self.source)
        self.assertEqual(result["retained_numeric_bytes"], 27)
        self.assertEqual(result["strong_reference_or_alias_members"], 24)
        self.assertEqual(result["profile_level_motion_session_joint_bytes"], 233972)
        self.assertEqual(result["joint_remaining_bytes"], 28172)
        self.assertFalse(result["native_memory_qualified"])

    def test_inherited_storage(self):
        self.refuses("extends RefCounted", 'extends "res://scripts/core/underground_budget.gd"')

    def test_extra_ref(self):
        self.refuses("var _ready: bool", "var _extra: Content = null\nvar _ready: bool")

    def test_extra_packed_bank(self):
        self.refuses("var _ready: bool", "var _bank: PackedInt32Array = PackedInt32Array()\nvar _ready: bool")

    def test_untyped_field(self):
        self.refuses("var _ready: bool = false", "var _ready = false")

    def test_widened_numeric_field(self):
        self.refuses("var _ready: bool = false", "var _ready: int = 0")

    def test_duplicate_same_constructor(self):
        self.refuses("_profiles = Profiles.new()", "_profiles = Profiles.new()\n\t_profiles = Profiles.new()")

    def test_second_content_image(self):
        self.refuses("_profiles = Profiles.new()", "_content = Content.new()\n\t_profiles = Profiles.new()")

    def test_hidden_temporary_array(self):
        self.refuses("_profiles = Profiles.new()", "var extra: PackedByteArray = PackedByteArray()\n\t_profiles = Profiles.new()")

    def test_second_domain_copy(self):
        self.refuses("_domain = _space._domain #", "_domain = _space.domain_copy() #")

    def test_independent_profile_maximum(self):
        self.refuses("Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, PROFILE_SOURCE_COUNT,", "256, 3072, 64,")

    def test_larger_reservation(self):
        self.refuses("const CONTROL_BYTES: int = 1024", "const CONTROL_BYTES: int = 2048")

    def test_external_authority_link(self):
        self.refuses("_profiles = Profiles.new()", "_buildings.bind_spatial_authority(null)\n\t_profiles = Profiles.new()")

    def foundation_refuses(self, name, old, new):
        original = (census.ROOT / name).read_text()
        self.assertIn(old, original)
        with tempfile.TemporaryDirectory(prefix="ug-session-census-") as temporary:
            root = Path(temporary)
            for path in census.foundation_census(census.ROOT):
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((census.ROOT / path).read_bytes())
            (root / name).write_text(original.replace(old, new, 1))
            with self.assertRaises(ValueError):
                census.foundation_census(root)

    def test_current_profile_capacity_growth_requires_joint_recount(self):
        self.foundation_refuses("godot/data/underground/mole-worker/mole_profile_catalog.gd",
                                "BOX_COUNT: int = 194", "BOX_COUNT: int = 3072")

    def test_current_profile_bank_growth_requires_joint_recount(self):
        self.foundation_refuses("godot/data/underground/mole-worker/mole_profile_catalog.gd",
                                "PAIRED_BANK_BYTES: int = 14520", "PAIRED_BANK_BYTES: int = 14521")

    def test_level_helper_growth_requires_joint_recount(self):
        self.foundation_refuses("godot/scripts/core/underground_level_catalog.gd",
                                "CONTROL_RESERVE: int = 2048", "CONTROL_RESERVE: int = 4096")

    def test_global_gate_cannot_be_raised(self):
        self.foundation_refuses("godot/scripts/core/underground_budget.gd",
                                "PROFILE_BYTES: int = 262144", "PROFILE_BYTES: int = 524288")


if __name__ == "__main__":
    unittest.main()
