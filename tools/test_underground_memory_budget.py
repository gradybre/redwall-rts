#!/usr/bin/env python3
"""Adversarial source edits must invalidate the joint pack without editing production files."""
from __future__ import annotations

import unittest

import underground_memory_budget as budget


class JointPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.index = budget.audit.load_source_index()

    def changed(self, module: str, before: str, after: str) -> dict:
        index = dict(self.index)
        source = index[module]
        self.assertIn(before, source.text)
        index[module] = budget.audit.parse_module(module, source.relative_path,
                                                  source.text.replace(before, after, 1))
        return index

    def refuses(self, module: str, before: str, after: str) -> None:
        with self.assertRaises(AssertionError):
            budget.build(self.changed(module, before, after))

    def test_negative_larger_quote_dimension(self) -> None:
        self.refuses("modular_project_contract", "OUTPUT_CAPACITY: int = 2", "OUTPUT_CAPACITY: int = 3")

    def test_negative_quote_width_change(self) -> None:
        self.refuses("modular_project_contract", "output_item: PackedInt32Array", "output_item: PackedInt64Array")

    def test_negative_quote_missing_resize(self) -> None:
        self.refuses("modular_project_contract", "\t\toutput_item.resize(OUTPUT_CAPACITY)", "")

    def test_negative_quote_ambiguous_resize(self) -> None:
        line = "\t\toutput_item.resize(OUTPUT_CAPACITY)"
        self.refuses("modular_project_contract", line, line + "\n" + line)

    def test_negative_unaccounted_retained_quote(self) -> None:
        source = self.index["construction"].text
        self.refuses("construction", source, source + "\nvar _extra_quote: ModularContract.Quote = ModularContract.Quote.new()\n")

    def test_negative_unaccounted_owner_column(self) -> None:
        source = self.index["underground_space_owner"].text
        self.refuses("underground_space_owner", source, source + "\nvar _unbudgeted: PackedInt32Array = PackedInt32Array()\n")

    def test_negative_furniture_bridge_changed_width(self) -> None:
        self.refuses("underground_space_owner", "_furniture_pins: PackedInt32Array", "_furniture_pins: PackedInt64Array")

    def test_negative_furniture_bridge_extra_input_copy(self) -> None:
        self.refuses("underground_space_owner", "_furniture_input_entries = entries\n",
                     "_furniture_input_entries = entries.duplicate()\n")

    def test_negative_furniture_bridge_larger_tuple(self) -> None:
        self.refuses("underground_space_owner", "_furniture_pins.resize(candidates.count * 5)",
                     "_furniture_pins.resize(candidates.count * 6)")

    def test_negative_furniture_bridge_unreleased_storage(self) -> None:
        self.refuses("underground_space_owner", "\t_furniture_rows = PackedInt32Array()\n", "")

    def test_negative_furniture_bridge_changed_charge(self) -> None:
        self.refuses("underground_space_owner", "return 60 * pair_count + 16", "return 60 * pair_count + 8")

    def test_negative_unaccounted_endpoint_column(self) -> None:
        source = self.index["inventory"].text
        self.refuses("inventory", source, source + "\nvar _spatial_extra: PackedInt32Array = PackedInt32Array()\n")

    def test_negative_loss_domain_count(self) -> None:
        self.refuses("excavation_inventory", "LOSS_DOMAIN_COUNT: int = 4", "LOSS_DOMAIN_COUNT: int = 5")

    def test_negative_settlement_control_width(self) -> None:
        self.refuses("excavation_inventory", "_settling_project: Vector2i", "_settling_project: Vector3i")

    def test_negative_missing_settlement_control(self) -> None:
        self.refuses("excavation_inventory", "var _settling_job: Vector2i = NULL_REF", "")

    def test_negative_extra_settlement_control(self) -> None:
        source = self.index["excavation_inventory"].text
        self.refuses("excavation_inventory", source,
                     source + "\nvar _settling_extra: Vector2i = NULL_REF\n")

    def test_negative_compact_settlement_declaration(self) -> None:
        source = self.index["excavation_inventory"].text
        self.refuses("excavation_inventory", source,
                     source + "\nvar _settling_extra:Vector2i = Vector2i(-1, 0)\n")

    def test_negative_untyped_settlement_declaration(self) -> None:
        source = self.index["excavation_inventory"].text
        self.refuses("excavation_inventory", source,
                     source + "\nvar _settling_extra = Vector2i(-1, 0)\n")

    def test_negative_duplicate_settlement_declaration(self) -> None:
        source = self.index["excavation_inventory"].text
        self.refuses("excavation_inventory", source,
                     source + "\nvar _settling_job: Vector2i = NULL_REF\n")

    def test_negative_unaccounted_recipe_column(self) -> None:
        source = self.index["underground_connector_recipes"].text
        self.refuses("underground_connector_recipes", source,
                     source + "\nvar _extra: PackedInt32Array = PackedInt32Array()\n")

    def test_negative_recipe_quantity_width(self) -> None:
        self.refuses("underground_connector_recipes", "_quantity: PackedInt64Array", "_quantity: PackedInt32Array")

    def test_negative_recipe_hash_scratch_growth(self) -> None:
        self.refuses("underground_connector_recipes", "_hash.resize(32)", "_hash.resize(64)")

    def test_negative_recipe_fixed_frame_shortfall(self) -> None:
        self.refuses("underground_connector_recipes", "FIXED_BYTES: int = 512", "FIXED_BYTES: int = 256")

    def test_negative_unaccounted_assembly_column(self) -> None:
        source = self.index["underground_connector_assemblies"].text
        self.refuses("underground_connector_assemblies", source,
                     source + "\nvar _extra: PackedInt32Array = PackedInt32Array()\n")

    def test_negative_assembly_column_width(self) -> None:
        self.refuses("underground_connector_assemblies", "_first_part: PackedInt32Array", "_first_part: PackedInt64Array")

    def test_negative_assembly_fixed_frame_shortfall(self) -> None:
        self.refuses("underground_connector_assemblies", "FIXED_BYTES: int = 512", "FIXED_BYTES: int = 256")

    def test_negative_anchor_box_growth(self) -> None:
        self.refuses("underground_surface_anchor", "_record.envelope.resize(6)", "_record.envelope.resize(12)")

    def test_negative_unaccounted_anchor_column(self) -> None:
        source = self.index["underground_surface_anchor"].text
        self.refuses("underground_surface_anchor", source,
                     source + "\nvar _extra: PackedInt32Array = PackedInt32Array()\n")

    def test_negative_anchor_control_shortfall(self) -> None:
        self.refuses("underground_surface_anchor", "RESERVED_BYTES: int = 2048", "RESERVED_BYTES: int = 256")

    def test_negative_anchor_nested_width_growth(self) -> None:
        self.refuses("underground_locations", "envelope: PackedInt32Array", "envelope: PackedInt64Array")

    def test_negative_anchor_unaccounted_nested_column(self) -> None:
        self.refuses("underground_space_owner", "class Region extends RefCounted:",
                     "class Region extends RefCounted:\n\tvar extra: PackedInt32Array = PackedInt32Array()")

    def test_negative_anchor_unaccounted_retained_packet(self) -> None:
        line = "var _record: Locations.Record = Locations.Record.new()"
        self.refuses("underground_surface_anchor", line,
                     line + "\nvar _extra: Locations.Record = Locations.Record.new()")

    def test_negative_anchor_commented_retained_packet(self) -> None:
        line = "var _record: Locations.Record = Locations.Record.new()"
        self.refuses("underground_surface_anchor", line,
                     line + "\nvar _extra: Locations.Record = Locations.Record.new() # another packet")

    def test_negative_anchor_late_allocated_packet(self) -> None:
        source = self.index["underground_surface_anchor"].text
        extra = source.replace("var _world: World = null", "var _extra: Locations.Record = null\nvar _world: World = null")
        extra = extra.replace("\t_record.envelope.resize(6)",
                              "\t_extra = Locations.Record.new()\n\t_extra.envelope.resize(1000000)\n\t_record.envelope.resize(6)")
        self.refuses("underground_surface_anchor", source, extra)

    def test_negative_anchor_nested_nonpacked_collection(self) -> None:
        self.refuses("underground_locations", "class Record extends RefCounted:",
                     "class Record extends RefCounted:\n\tvar extra: Array = []")

    def test_anchor_packet_parser_excludes_later_function_locals(self) -> None:
        source = self.index["underground_surface_anchor"].text
        index = self.changed("underground_surface_anchor", source, source +
                             "\nfunc unrelated() -> int:\n\tvar example: int = 7\n\treturn example\n")
        anchor = budget.build(index)["connector_recipe_reservation"]["surface_anchor_reservation"]
        self.assertEqual(anchor["packet_bytes"], 204)
        self.assertEqual(anchor["numeric_control_bytes"], 92)

    def test_negative_binding_reserve_cannot_omit_existing_consumers(self) -> None:
        self.refuses("underground_budget", "BINDINGS_AND_GROWTH_BYTES: int = 524288",
                     "BINDINGS_AND_GROWTH_BYTES: int = 378119")

    def test_negative_placement_bank_width_growth(self) -> None:
        self.refuses("underground_connector_placements", "var i32: PackedInt32Array", "var i32: PackedInt64Array")

    def test_negative_placement_omitted_bank_column(self) -> None:
        self.refuses("underground_connector_placements", "class Bank extends RefCounted:",
                     "class Bank extends RefCounted:\n\tvar extra: PackedInt32Array = PackedInt32Array()")

    def test_negative_placement_nested_control_collection(self) -> None:
        self.refuses("underground_locations", "class RoomContext extends RefCounted:",
                     "class RoomContext extends RefCounted:\n\tvar extra: Array = []")

    def test_negative_placement_late_allocated_packet(self) -> None:
        self.refuses("underground_connector_placements", "var _configured: bool = false",
                     "var _configured: bool = false\nvar _extra: Request = null")

    def test_negative_connector_adapter_unaccounted_numeric_field(self) -> None:
        self.refuses("underground_connector_work", "var _ready: bool = false",
                     "var _ready: bool = false\nvar _more: int = 0")

    def test_negative_connector_adapter_unaccounted_collection(self) -> None:
        self.refuses("underground_connector_work", "var _ready: bool = false",
                     "var _ready: bool = false\nvar _more: Array = []")

    def test_negative_placement_changed_top_level_parent(self) -> None:
        self.refuses("underground_connector_placements", "extends RefCounted",
                     'extends "res://scripts/core/other_owner.gd"')

    def test_negative_connector_work_changed_top_level_parent(self) -> None:
        self.refuses("underground_connector_work", 'extends "res://scripts/core/modular_project_contract.gd".Owner',
                     'extends "res://scripts/core/other_owner.gd".Owner')

    def test_negative_connector_adapter_inherited_collection(self) -> None:
        self.refuses("modular_project_contract", "class Owner extends RefCounted:",
                     "class Owner extends RefCounted:\n\tvar extra: Array = []")

    def test_negative_publication_inherited_control(self) -> None:
        self.refuses("underground_connector_placements", "class Publisher extends RefCounted:",
                     "class Publisher extends RefCounted:\n\tvar extra: int = 0")

    def test_negative_placement_changed_parent_is_not_omitted(self) -> None:
        self.refuses("underground_connector_placements", "class Request extends RefCounted:",
                     "class Request extends OtherOwner:")

    def test_negative_placement_constructor_undercharges_banks(self) -> None:
        self.refuses("underground_connector_placements", "189 * placements + 89 * openings + 14848",
                     "189 * placements + 89 * openings + 4096")

    def test_negative_corrected_binding_consumers_cannot_be_omitted(self) -> None:
        self.refuses("underground_budget", "BINDINGS_AND_GROWTH_BYTES: int = 524288",
                     "BINDINGS_AND_GROWTH_BYTES: int = 487498")

    def test_negative_route_leading_multiplier_preserves_precedence(self) -> None:
        self.refuses("underground_world_routes", "2 * EDGE_CAPACITY * (MASK_BYTES + 4 + 16)",
                     "2 * 2 * EDGE_CAPACITY * (MASK_BYTES + 4 + 16)")

    def test_negative_route_trailing_multiplier_preserves_precedence(self) -> None:
        self.refuses("underground_world_routes", "2 * EDGE_CAPACITY * (MASK_BYTES + 4 + 16)",
                     "2 * EDGE_CAPACITY * (MASK_BYTES + 4 + 16) * 2")

    def test_negative_joint_limit_even_when_individual_formulas_agree(self) -> None:
        self.refuses("underground_budget", "BINDINGS_AND_GROWTH_BYTES: int = 524288",
                     "BINDINGS_AND_GROWTH_BYTES: int = 624288")

    def test_negative_inadequate_endpoint_reserve(self) -> None:
        self.refuses("underground_budget", "INVENTORY_EXTENSION_BYTES: int = 131072",
                     "INVENTORY_EXTENSION_BYTES: int = 1024")

    def test_negative_inadequate_location_reserve(self) -> None:
        self.refuses("underground_budget", "LOCATION_AND_TOPOLOGY_BYTES: int = 1048576",
                     "LOCATION_AND_TOPOLOGY_BYTES: int = 1024")

    def test_negative_runtime_input_is_not_a_source_constant(self) -> None:
        with self.assertRaises(AssertionError):
            budget.resolve(self.index, "underground_space_owner", "_region_capacity")

    def test_positive_current_joint_pack_is_not_runtime_qualification(self) -> None:
        result = budget.build(self.index)
        self.assertEqual(result["new_mutable_and_reserved_bytes"], 4966485)
        self.assertEqual(result["declaration_bytes"], 23573)
        self.assertEqual(result["live_with_reserve_bytes"], 99959250)
        self.assertEqual(result["headroom_bytes"], 40750)
        self.assertFalse(result["runtime_qualified"])
        recipes = result["connector_recipe_reservation"]
        self.assertEqual(budget.payload(recipes["columns"]), 16580)
        self.assertEqual(recipes["bank_bytes"], 16512)
        self.assertEqual(recipes["known_binding_used_bytes"], 487499)
        self.assertEqual(recipes["remaining_binding_reserve_bytes"], 36789)
        self.assertEqual(recipes["funding_settlement_reservation"]["reserved_bytes"], 16)
        self.assertEqual(recipes["placement_reservation"]["reserved_bytes"], 108800)
        self.assertEqual(recipes["placement_reservation"]["fixed_controls"]["total_bytes"], 1670)
        self.assertEqual(recipes["connector_work_reservation"]["reserved_bytes"], 563)
        self.assertEqual(recipes["connector_work_reservation"]["aliased_record_bytes_already_charged"], 128)
        assemblies = recipes["assembly_reservation"]
        self.assertEqual(budget.payload(assemblies["columns"]), 4316)
        self.assertEqual(assemblies["reserved_bytes"], 4760)
        anchor = recipes["surface_anchor_reservation"]
        self.assertEqual(anchor["numeric_control_bytes"], 92)
        self.assertEqual(anchor["packet_bytes"], 204)
        self.assertEqual(anchor["fixed_numeric_and_packed_bytes"], 296)
        self.assertEqual(anchor["reserved_bytes"], 2048)
        self.assertEqual(budget.payload(result["quote"]["columns"]), 112)
        self.assertEqual(result["quote"]["numeric_control_bytes"], 72)
        self.assertEqual(result["furniture_bridge_cold"]["private_bytes_per_pair"], 60)
        self.assertEqual(result["furniture_bridge_cold"]["numeric_control_bytes"], 16)


if __name__ == "__main__":
    unittest.main(verbosity=2)
