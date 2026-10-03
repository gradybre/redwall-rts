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

    def test_negative_binding_reserve_cannot_omit_existing_consumers(self) -> None:
        self.refuses("underground_budget", "BINDINGS_AND_GROWTH_BYTES: int = 524288",
                     "BINDINGS_AND_GROWTH_BYTES: int = 371311")

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
        self.assertEqual(recipes["known_binding_used_bytes"], 371312)
        self.assertEqual(recipes["remaining_binding_reserve_bytes"], 152976)
        self.assertEqual(budget.payload(result["quote"]["columns"]), 112)
        self.assertEqual(result["quote"]["numeric_control_bytes"], 72)
        self.assertEqual(result["furniture_bridge_cold"]["private_bytes_per_pair"], 60)
        self.assertEqual(result["furniture_bridge_cold"]["numeric_control_bytes"], 16)


if __name__ == "__main__":
    unittest.main(verbosity=2)
