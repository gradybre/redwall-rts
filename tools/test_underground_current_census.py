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
        return dict(self.index, **{name: audit.parse_module(name, module.relative_path, text)})

    def test_current_counts(self):
        result = census.build(self.index, self.projected, self.motion)
        self.assertEqual(result["new_retained_bytes"], {"geometry_journals": 4322,
                         "locations_carry_and_retirement_controls": 161, "first_entry_runtime_chain": 8347, "cold_load_images": 196694})
        self.assertEqual(result["room_publication_controls"]["controls"], 8970)
        self.assertEqual(result["location_air_pool"]["remaining_bytes"], 1472)
        self.assertEqual(result["world_routes_cold"]["world_routes_cold_bytes"], 379648)

    def test_cold_load_images_are_charged_from_their_codec_constants(self):
        """ADR 1221: the Contacts scope (74) and the Planner admission image (12 + 24 x 8192); a grown image refuses."""
        result = census.build(self.index, self.projected, self.motion)
        self.assertEqual(result["cold_load_images"]["rows"], {"contact_scope": 74, "haul_admissions": 196620})
        text = self.index["haul_planner"].text.replace("const ADMISSION_WIRE_BYTES: int = 12 + 24 * JOB_CAPACITY",
                                                       "const ADMISSION_WIRE_BYTES: int = 12 + 28 * JOB_CAPACITY")
        with self.assertRaises((AssertionError, ValueError)):
            census.build(self.changed("haul_planner", text), self.projected, self.motion)

    def test_entry_progress_record_is_charged_at_its_wire_bound(self):
        """ADR 1218: two whole records at MAX_WIRE_BYTES plus the Writer/Reader packets; a changed bound refuses."""
        result = census.build(self.index, self.projected, self.motion)
        self.assertEqual(result["first_entry_runtime"]["rows"]["progress_record"], 2 * 2559 + 10)
        text = self.index["underground_entry_progress"].text.replace("const MAX_TASKS: int = 32", "const MAX_TASKS: int = 33")
        self.assertEqual(census.entry_progress(memory, self.changed("underground_entry_progress", text))["max_wire_bytes"],
                         2559 + 52)
        text = self.index["underground_entry_progress"].text.replace("+ HAULER_FIXED_BYTES + MAX_QUEUE", "+ 2 * HAULER_FIXED_BYTES + MAX_QUEUE")
        with self.assertRaises((AssertionError, ValueError)):
            census.build(self.changed("underground_entry_progress", text), self.projected, self.motion)

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
            "const CAPACITY: int = 64", "const CAPACITY: int = 256", 1)
        with self.assertRaisesRegex(ValueError, "journal ring capacity"):
            census.build(self.changed("underground_geometry_journal", text), self.projected, self.motion)

    def test_joint_pack_fits_the_raised_gate(self):
        result = memory.build()
        self.assertEqual((result["live_with_reserve_bytes"], result["gate_bytes"], result["headroom_bytes"]),
                         (100227400, 150000000, 49772600)) # ADR1217 step 5: PROFILE_BYTES +16,384

    def test_publication_controls_refuse_above_their_ceiling(self):
        text = self.index["underground_room_frontier_publication"].text.replace(
            "const CONTROL_BYTES: int = 9216", "const CONTROL_BYTES: int = 8192", 1)
        with self.assertRaisesRegex(ValueError, "publication controls exceed CONTROL_BYTES"):
            census.publication_controls(memory, self.changed("underground_room_frontier_publication", text))


if __name__ == "__main__":
    unittest.main()
