#!/usr/bin/env python3
"""ADR 1212: the current-source census refuses any storage change it has not counted."""
from __future__ import annotations

import unittest

import audit_registry_capacities as audit
import underground_current_census as census
import underground_memory_budget as memory
import underground_motion_memory as motion_memory
import underground_room_memory as room_memory

EXTRA = {"mole_profile_catalog": "godot/data/underground/mole-worker/mole_profile_catalog.gd",
         "short_program": "godot/data/underground/mole-worker/work-step-v1/source_program.gd",
         "source_program": "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
         "mole_profile_driver": "godot/data/underground/mole-worker/mole_profile_driver.gd",
         "settlement_system": "godot/scripts/systems/settlement_system.gd",
         "ui_manager": "godot/scripts/systems/ui_manager.gd",
         "ui_world_session": "godot/scripts/ui/ui_world_session.gd"}


class CurrentCensusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = dict(audit.load_source_index())
        for name, path in EXTRA.items():
            if name not in cls.index:
                cls.index[name] = audit.parse_module(name, path, (census.ROOT / path).read_text())
        extensions, _ = room_memory.build(cls.index)
        cls.projected = extensions["projected_reviewed_inputs"]
        cls.motion = motion_memory.build(cls.index)

    def changed(self, name, text):
        module = self.index[name]
        return dict(self.index, **{name: module._replace(text=text)})

    def test_current_counts(self):
        result = census.build(self.index, self.projected, self.motion)
        self.assertEqual(result["new_retained_bytes"], {"geometry_journals": 16994,
                         "locations_carry_and_retirement_controls": 129, "first_entry_runtime_chain": 2430})
        self.assertEqual(result["world_routes_cold"]["world_routes_cold_bytes"], 385024)

    def test_new_member_in_projected_source_refuses(self):
        text = self.index["underground_locations"].text + "\nvar _hidden: PackedInt64Array = PackedInt64Array()\n"
        with self.assertRaisesRegex(ValueError, "unreviewed storage delta"):
            census.build(self.changed("underground_locations", text), self.projected, self.motion)

    def test_new_resize_in_projected_source_refuses(self):
        source = self.index["underground_space_owner"].text
        text = source.replace("\t_journal.allocate()\n", "\t_journal.allocate()\n\t_spare.resize(4096)\n", 1)
        self.assertNotEqual(text, source)
        with self.assertRaisesRegex(ValueError, "unreviewed storage delta"):
            census.build(self.changed("underground_space_owner", text), self.projected, self.motion)

    def test_new_entry_owner_member_refuses(self):
        text = self.index["underground_entry_foreman"].text.replace(
            "var _index: int = 0\n", "var _index: int = 0\nvar _log: PackedInt64Array = PackedInt64Array()\n", 1)
        with self.assertRaisesRegex(ValueError, "unreconciled retained member"):
            census.build(self.changed("underground_entry_foreman", text), self.projected, self.motion)

    def test_stateless_entry_module_cannot_gain_state(self):
        text = self.index["underground_entry_site"].text + "\nvar _cache: PackedInt32Array = PackedInt32Array()\n"
        with self.assertRaisesRegex(ValueError, "stateless entry module"):
            census.build(self.changed("underground_entry_site", text), self.projected, self.motion)

    def test_projected_set_must_match_reviewed_rows(self):
        with self.assertRaisesRegex(ValueError, "projected inputs and reviewed rows differ"):
            census.build(self.index, self.projected[1:], self.motion)

    def test_wider_journal_refuses(self):
        text = self.index["underground_geometry_journal"].text.replace(
            "const CAPACITY: int = 256", "const CAPACITY: int = 512", 1)
        with self.assertRaisesRegex(ValueError, "journal ring capacity"):
            census.build(self.changed("underground_geometry_journal", text), self.projected, self.motion)

    def test_joint_pack_reports_the_overrun(self):
        with self.assertRaisesRegex(AssertionError, "100019359"):
            memory.build()


if __name__ == "__main__":
    unittest.main()
