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

    def test_motion_profiles_levels_share_the_existing_reservation(self) -> None:
        result = budget.build(self.index)
        joint = result["profile_motion_reservation"]["joint"]
        self.assertEqual((joint["total"], joint["reservation"], joint["headroom"]), (232436, 262144, 29708))
        self.assertEqual(joint["independent_maxima_total_refuses"], 444284)
        self.assertEqual(result["live_with_reserve_bytes"], 99998782)
        self.assertFalse(result["runtime_qualified"])

    def test_session_fits_current_source_counted_joint_without_global_increase(self) -> None:
        result = budget.build(self.index)
        session = result["session_reservation"]
        self.assertEqual(session["source_counted_motion_joint_before_session_bytes"],
                         result["profile_motion_reservation"]["joint"]["total"])
        self.assertEqual((session["retained_numeric_bytes"], session["strong_reference_or_alias_members"]), (27, 24))
        self.assertEqual((session["profile_level_motion_session_joint_bytes"], session["joint_remaining_bytes"]), (233972, 28172))
        self.assertEqual(result["live_with_reserve_bytes"], 99998782)
        self.assertFalse(session["native_memory_qualified"])

    def test_session_unaccounted_owner_is_rejected(self) -> None:
        self.refuses("underground_session", "var _ready: bool", "var _extra: Content = null\nvar _ready: bool")

    def test_session_unaccounted_bank_is_rejected(self) -> None:
        self.refuses("underground_session", "var _ready: bool", "var _bank: PackedByteArray = PackedByteArray()\nvar _ready: bool")

    def test_session_duplicate_profile_allocation_is_rejected(self) -> None:
        self.refuses("underground_session", "_profiles = Profiles.new()", "_profiles = Profiles.new()\n\t_profiles = Profiles.new()")

    def test_session_cannot_duplicate_actual_actor_image(self) -> None:
        self.refuses("underground_session", "_profiles = Profiles.new()", "_content = Content.new()\n\t_profiles = Profiles.new()")

    def test_session_domain_remains_an_alias(self) -> None:
        self.refuses("underground_session", "_domain = _space._domain #", "_domain = _space.domain_copy() #")

    def test_session_independent_profile_maxima_refused(self) -> None:
        self.refuses("underground_session", "Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, PROFILE_SOURCE_COUNT,", "256, 3072, 64,")

    def test_session_actual_reservation_formula_cannot_omit_wrapper(self) -> None:
        self.refuses("underground_session", "Levels.RESERVED_BYTES + RESERVED_BYTES", "Levels.RESERVED_BYTES")

    def test_session_native_reservation_cannot_silently_grow(self) -> None:
        self.refuses("underground_session", "const CONTROL_BYTES: int = 1024", "const CONTROL_BYTES: int = 2048")

    def test_session_rejects_joint_overbooking_even_with_valid_own_source(self) -> None:
        import underground_session_memory as session
        source = self.index["underground_session"].text
        with self.assertRaises(ValueError):
            session.census(source, 262144 - 1536 + 1, 262144)

    def test_motion_unaccounted_member_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "var _busy: bool = false",
                     "var _busy: bool = false\nvar _extra: PackedInt32Array = PackedInt32Array()")

    def test_motion_larger_bank_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "I32_COUNT: int = 17421", "I32_COUNT: int = 17422")

    def test_motion_extra_allocation_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "\t_live.allocate()", "\t_live.allocate()\n\t_live.allocate()")

    def test_motion_decode_loop_cannot_retain_previous_window(self) -> None:
        self.refuses("underground_motion_catalog", "\t\tvar code: StringName = _decode_payload(",
                     "\t\tvar previous: PackedByteArray = _read(file, hashing, 4096)\n\t\tvar code: StringName = _decode_payload(")

    def test_motion_decode_payload_cannot_escape(self) -> None:
        self.refuses("underground_motion_catalog", "var bytes: PackedByteArray = _read(file, hashing, span * width)",
                     "var bytes: PackedByteArray = _read(file, hashing, span * width)\n\t_digest = bytes")

    def test_motion_copied_decode_window_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "file.get_buffer(count)", "file.get_buffer(count).duplicate()")

    def test_motion_larger_native_reserve_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "NATIVE_RESERVE: int = 32768", "NATIVE_RESERVE: int = 65536")

    def test_motion_joint_runtime_formula_drift_is_rejected(self) -> None:
        self.refuses("underground_motion_catalog", "+ 2 * BANK_BYTES + DECODE_BYTES", "+ BANK_BYTES + DECODE_BYTES")

    def test_motion_profile_bank_growth_is_rejected(self) -> None:
        self.refuses("underground_profiles", "boxes.resize(volumes * 7)", "boxes.resize(volumes * 8)")

    def test_motion_level_envelope_growth_is_rejected(self) -> None:
        self.refuses("underground_level_catalog", "MAX_RETAINED_BYTES: int = 244", "MAX_RETAINED_BYTES: int = 248")

    def test_motion_shared_profile_reservation_cannot_expand(self) -> None:
        self.refuses("underground_budget", "PROFILE_BYTES: int = 262144", "PROFILE_BYTES: int = 524288")

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

    def test_negative_start_control_width(self) -> None:
        self.refuses("excavation_sites", "_starting: bool", "_starting: int")

    def test_negative_missing_start_control(self) -> None:
        self.refuses("excavation_sites", "var _start_poisoned: bool = false", "")

    def test_negative_terminal_guard_width(self) -> None:
        self.refuses("excavation_sites", "_settling: bool", "_settling: int")

    def test_negative_missing_terminal_poison(self) -> None:
        self.refuses("excavation_sites", "var _settlement_poisoned: bool = false", "")

    def test_negative_extra_start_control(self) -> None:
        source = self.index["excavation_sites"].text
        self.refuses("excavation_sites", source, source + "\nvar _start_extra:bool = false\n")

    def test_negative_untyped_start_control(self) -> None:
        source = self.index["excavation_sites"].text
        self.refuses("excavation_sites", source, source + "\nvar _start_extra = false\n")

    def test_negative_duplicate_start_control(self) -> None:
        source = self.index["excavation_sites"].text
        self.refuses("excavation_sites", source, source + "\nvar _starting: bool = false\n")

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

    def test_negative_anchor_surface_metadata_growth(self) -> None:
        self.refuses("underground_surface_anchor", "_surface_box.resize(6)", "_surface_box.resize(12)")

    def test_negative_anchor_surface_metadata_width(self) -> None:
        self.refuses("underground_surface_anchor", "_surface_box: PackedInt32Array", "_surface_box: PackedInt64Array")

    def test_negative_anchor_duplicate_member(self) -> None:
        source = self.index["underground_surface_anchor"].text
        self.refuses("underground_surface_anchor", source, source + "\nvar _new_section: bool = false\n")

    def test_negative_anchor_untyped_member(self) -> None:
        source = self.index["underground_surface_anchor"].text
        self.refuses("underground_surface_anchor", source, source + "\nvar _untyped_extra = 0\n")

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
        self.assertEqual(anchor["numeric_control_bytes"], 93)

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

    def test_negative_phase_context_extra_collection(self) -> None:
        self.refuses("underground_locations", "class PhaseContext extends RefCounted:",
                     "class PhaseContext extends RefCounted:\n\tvar extra: Array = []")

    def test_negative_phase_context_extra_scalar(self) -> None:
        self.refuses("underground_locations", "class PhaseContext extends RefCounted:",
                     "class PhaseContext extends RefCounted:\n\tvar extra: int = 0")

    def test_negative_phase_context_wrong_reference_lifetime(self) -> None:
        body = budget.class_body(self.index["underground_locations"].text, "PhaseContext")
        self.refuses("underground_locations", body, body.replace("authority: WeakRef", "authority: RefCounted"))

    def test_negative_phase_context_full_ref_width(self) -> None:
        body = budget.class_body(self.index["underground_locations"].text, "PhaseContext")
        self.refuses("underground_locations", body, body.replace("site: Vector2i", "site: Vector3i"))

    def test_negative_phase_context_duplicate_member(self) -> None:
        self.refuses("underground_locations", "class PhaseContext extends RefCounted:",
                     "class PhaseContext extends RefCounted:\n\tvar site: Vector2i = NULL_REF")

    def test_negative_phase_context_duplicate_retained_packet(self) -> None:
        self.refuses("underground_connector_placements", "var _configured: bool = false",
                     "var _configured: bool = false\nvar _extra_phase: Locations.PhaseContext = null")

    def test_negative_phase_mode_width(self) -> None:
        self.refuses("underground_connector_placements", "var _phase_mode: bool = false",
                     "var _phase_mode: int = 0")

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
        self.assertEqual(result["new_mutable_and_reserved_bytes"], 5006017)
        self.assertEqual(result["declaration_bytes"], 23573)
        self.assertEqual(result["live_with_reserve_bytes"], 99998782)
        self.assertEqual(result["headroom_bytes"], 1218)
        self.assertFalse(result["runtime_qualified"])
        workpieces = result["connector_workpieces_reservation"]
        self.assertEqual(workpieces["two_bank_bytes"], 10752)
        self.assertEqual(workpieces["immutable_header_bytes"], 232)
        self.assertEqual(workpieces["immutable_rows_bytes"], 8192)
        self.assertEqual(workpieces["fixed_numeric_and_packed_bytes"], 123)
        self.assertEqual(workpieces["reserved_bytes"], 29928)
        self.assertEqual(result["contributions"]["connector_workpieces"], 29928)
        haul = result["haul_transfer_reservation"]
        self.assertEqual(haul["packet_bytes"], 216)
        self.assertEqual(haul["fixed_numeric_bytes"], 433)
        self.assertEqual(haul["reserved_bytes"], 3072)
        self.assertEqual(result["contributions"]["guarded_haul_transfers"], 3072)
        delivery = result["connector_delivery_reservation"]
        self.assertEqual(delivery["fixed_numeric_and_packed_bytes"], 753)
        self.assertEqual(delivery["work_new_numeric_bytes"], 1)
        self.assertEqual(delivery["declared_bytes"], 3826)
        self.assertEqual(delivery["reserved_bytes"], 4096)
        self.assertEqual(result["contributions"]["connector_delivery"], 4096)
        recipes = result["connector_recipe_reservation"]
        self.assertEqual(budget.payload(recipes["columns"]), 16580)
        self.assertEqual(recipes["bank_bytes"], 16512)
        self.assertEqual(recipes["known_binding_used_bytes"], 524288)
        self.assertEqual(recipes["remaining_binding_reserve_bytes"], 0)
        contacts = recipes["connector_contacts_reservation"]
        self.assertEqual(contacts["reserved_bytes"], 4096)
        self.assertEqual(contacts["fixed_numeric_and_packed_bytes"], 3059)
        self.assertEqual(contacts["fragment_banks_and_controls"], 1633)
        self.assertEqual(contacts["logical_helper_allowance_bytes"], 1024)
        self.assertEqual(recipes["entry_frontier_reservation"]["reserved_bytes"], 28597)
        self.assertEqual(recipes["entry_bindings_reservation"]["reserved_bytes"], 4096)
        self.assertEqual(recipes["entry_bindings_reservation"]["fixed_numeric_and_packed_bytes"], 486)
        self.assertEqual(recipes["funding_settlement_reservation"]["reserved_bytes"], 16)
        self.assertEqual(recipes["placement_reservation"]["reserved_bytes"], 108800)
        self.assertEqual(recipes["placement_reservation"]["fixed_controls"]["total_bytes"], 1895)
        self.assertEqual(recipes["placement_reservation"]["fixed_controls"]["components"]["phase_context"], 128)
        self.assertEqual(recipes["connector_work_reservation"]["reserved_bytes"], 563)
        self.assertEqual(recipes["connector_work_reservation"]["aliased_record_bytes_already_charged"], 128)
        assemblies = recipes["assembly_reservation"]
        self.assertEqual(budget.payload(assemblies["columns"]), 4316)
        self.assertEqual(assemblies["reserved_bytes"], 4760)
        anchor = recipes["surface_anchor_reservation"]
        self.assertEqual(anchor["numeric_control_bytes"], 93)
        self.assertEqual(anchor["packet_bytes"], 204)
        self.assertEqual(anchor["surface_metadata_bytes"], 24)
        self.assertEqual(anchor["fixed_numeric_and_packed_bytes"], 321)
        self.assertEqual(anchor["reserved_bytes"], 2048)
        self.assertEqual(budget.payload(result["quote"]["columns"]), 112)
        self.assertEqual(result["quote"]["numeric_control_bytes"], 72)
        self.assertEqual(result["furniture_bridge_cold"]["private_bytes_per_pair"], 60)
        self.assertEqual(result["furniture_bridge_cold"]["numeric_control_bytes"], 16)
        entry = result["entry_structure_reservation"]
        self.assertEqual(entry["fixed_numeric_and_packed_bytes"], 153)
        self.assertEqual(entry["reserved_bytes"], 384)
        self.assertEqual(entry["check_peak_bytes"], 1048912)

    def test_negative_delivery_inherited_storage(self) -> None:
        self.refuses("underground_connector_delivery", 'extends "res://scripts/core/haul_transfer_contract.gd"',
                     'extends "res://scripts/core/underground_connector_placements.gd"')

    def test_negative_delivery_extra_bank(self) -> None:
        self.refuses("underground_connector_delivery", "var _clock: Clock = null",
                     "var _clock: Clock = null\nvar _extra: PackedInt32Array = PackedInt32Array()")

    def test_negative_delivery_duplicate_packet(self) -> None:
        self.refuses("underground_connector_delivery", "_order = Placements.OrderRecord.new()",
                     "_order = Placements.OrderRecord.new()\n\t_order = Placements.OrderRecord.new()")

    def test_negative_delivery_larger_array(self) -> None:
        self.refuses("underground_connector_delivery", "_frame.resize(9)", "_frame.resize(90)")

    def test_negative_delivery_larger_nested_location_array(self) -> None:
        self.refuses("underground_connector_delivery", "_location.envelope.resize(6)", "_location.envelope.resize(60)")

    def test_negative_delivery_control_width(self) -> None:
        self.refuses("underground_connector_delivery", "var _work_tick: bool", "var _work_tick: int")

    def test_negative_delivery_early_allocation(self) -> None:
        self.refuses("underground_connector_delivery", "\tif _configured or _placements != null",
                     "\t_allocate()\n\tif _configured or _placements != null")

    def test_negative_delivery_initializer_allocates_before_admission(self) -> None:
        self.refuses("underground_connector_delivery", "\n\nstatic func _binding_leaf(a: RefCounted)",
                     "\n\nfunc _init() -> void:\n\t_allocate()\n\n\nstatic func _binding_leaf(a: RefCounted)")

    def test_negative_delivery_local_packed_image(self) -> None:
        self.refuses("underground_connector_delivery", "\t_order = Placements.OrderRecord.new()",
                     "\tvar scratch: PackedInt32Array = PackedInt32Array(range(1000000))\n\t_order = Placements.OrderRecord.new()")

    def test_negative_delivery_extra_allocation_reference(self) -> None:
        self.refuses("underground_connector_delivery", "\t_configured = true",
                     "\tvar allocate_again: Callable = _allocate\n\t_configured = true")

    def test_negative_delivery_local_copy_after_admission(self) -> None:
        self.refuses("underground_connector_delivery", "\t_configured = true",
                     "\tvar duplicate: PackedInt32Array = _frame.duplicate()\n\t_configured = true")

    def test_negative_delivery_late_append(self) -> None:
        self.refuses("underground_connector_delivery", "\ta._busy = false",
                     "\ta._frame.append(0)\n\ta._busy = false")

    def test_negative_delivery_extra_result_packet(self) -> None:
        self.refuses("underground_connector_delivery", "\ta._busy = false",
                     "\tvar extra: Inventory.OpResult = Inventory.OpResult.new(false, &\"\", NULL_REF, 0)\n\ta._busy = false")

    def test_negative_delivery_late_local_packed_image(self) -> None:
        self.refuses("underground_connector_delivery", "\ta._busy = false",
                     "\tvar scratch: PackedInt32Array = PackedInt32Array(range(1000000))\n\ta._busy = false")

    def test_negative_delivery_local_collection_literal(self) -> None:
        self.refuses("underground_connector_delivery", "\ta._busy = false",
                     "\tvar scratch: Array = [0, 1]\n\ta._busy = false")

    def test_negative_delivery_reordered_admission(self) -> None:
        self.refuses("underground_connector_delivery", "\t_allocate()\n\t_configured = true",
                     "\t_configured = true\n\t_allocate()")

    def test_negative_delivery_new_work_binding(self) -> None:
        self.refuses("work", "var _handling_tick: bool = false", "var _handling_tick: bool = false\nvar _handling_extra: int = 0")

    def test_negative_delivery_work_base(self) -> None:
        self.refuses("work", "extends RefCounted", 'extends "res://scripts/core/spoil_tips.gd"')

    def test_negative_delivery_planner_base(self) -> None:
        self.refuses("haul_planner", "extends RefCounted", 'extends "res://scripts/core/spoil_tips.gd"')

    def test_negative_delivery_planner_new_packet(self) -> None:
        self.refuses("haul_planner", "var _seed_count: int = 0",
                     "var _seed_count: int = 0\nvar _extra: HaulTransferContract.Transfer = null")

    def test_negative_delivery_smaller_helper_allowance(self) -> None:
        self.refuses("underground_connector_delivery", "HELPER_BYTES: int = 1024", "HELPER_BYTES: int = 512")

    def test_negative_delivery_math_packet_inherited_storage(self) -> None:
        self.refuses("int_math", "class IntResult:", "class IntResult extends RemainderAccumulator:")

    def test_negative_delivery_math_packet_extra_collection(self) -> None:
        self.refuses("int_math", "\tvar error: String", "\tvar error: String\n\tvar extra: PackedInt32Array")

    def test_negative_haul_packet_width(self) -> None:
        self.refuses("haul_transfer_contract", "var job: Vector2i", "var job: Vector3i")

    def test_negative_haul_pool_inherited_storage(self) -> None:
        self.refuses("reservations", "extends RefCounted", 'extends "res://scripts/core/spoil_tips.gd"')

    def test_negative_haul_inventory_inherited_storage(self) -> None:
        self.refuses("inventory", "extends RefCounted", 'extends "res://scripts/core/spoil_tips.gd"')

    def test_negative_haul_packet_size_constant(self) -> None:
        self.refuses("haul_transfer_contract", "TRANSFER_BYTES: int = 216", "TRANSFER_BYTES: int = 208")

    def test_negative_haul_packet_collection(self) -> None:
        self.refuses("haul_transfer_contract", "class Transfer extends RefCounted:",
                     "class Transfer extends RefCounted:\n\tvar extra: PackedByteArray = PackedByteArray()")

    def test_negative_haul_protocol_retained_state(self) -> None:
        source = self.index["haul_transfer_contract"].text
        self.refuses("haul_transfer_contract", source, source + "\nvar _extra: int = 0\n")

    def test_negative_haul_extra_scope_control(self) -> None:
        self.refuses("reservations", "var _haul_active: bool = false",
                     "var _haul_active: bool = false\nvar _haul_extra: int = 0")

    def test_negative_haul_extra_packet_outside_scope_prefix(self) -> None:
        source = self.index["reservations"].text
        self.refuses("reservations", source, source + "\nvar _extra: HaulContract.Transfer = HaulContract.Transfer.new()\n")

    def test_negative_haul_unaccounted_local_packet(self) -> None:
        source = self.index["reservations"].text
        self.refuses("reservations", source, source + "\nfunc _extra() -> void:\n\tvar packet := HaulContract.Transfer.new()\n")

    def test_negative_haul_inventory_control(self) -> None:
        source = self.index["inventory"].text
        self.refuses("inventory", source, source + "\nvar _haul_extra: bool = false\n")

    def test_negative_workpiece_bank_width(self) -> None:
        self.refuses("underground_connector_workpieces", "var fields: PackedInt32Array", "var fields: PackedInt64Array")

    def test_negative_workpiece_extra_bank_member(self) -> None:
        self.refuses("underground_connector_workpieces", "class Bank extends RefCounted:",
                     "class Bank extends RefCounted:\n\tvar extra: PackedByteArray = PackedByteArray()")

    def test_negative_workpiece_extra_retained_bank(self) -> None:
        self.refuses("underground_connector_workpieces", "var _stage: Bank = Bank.new()",
                     "var _stage: Bank = Bank.new()\nvar _third: Bank = Bank.new()")

    def test_negative_workpiece_extra_numeric_control(self) -> None:
        self.refuses("underground_connector_workpieces", "var _configured: bool = false",
                     "var _configured: bool = false\nvar _additional: int = 0")

    def test_negative_workpiece_omitted_restore_bank(self) -> None:
        self.refuses("underground_connector_workpieces", "\t_stage.allocate(placements)", "")

    def test_negative_workpiece_restore_allocation_before_admission(self) -> None:
        source = self.index["underground_connector_workpieces"].text
        line = "\t_stage.allocate(placements)"
        changed = source.replace(line, "", 1).replace("\tvar required: int = required_bytes(placements, assemblies)",
                    line + "\n\tvar required: int = required_bytes(placements, assemblies)", 1)
        self.refuses("underground_connector_workpieces", source, changed)

    def test_negative_workpiece_immutable_row_growth(self) -> None:
        self.refuses("underground_connector_workpieces", "_parts.resize(6 * assemblies)", "_parts.resize(7 * assemblies)")

    def test_negative_workpiece_source_header_growth(self) -> None:
        self.refuses("underground_connector_workpieces", "_header.resize(9)", "_header.resize(10)")

    def test_negative_workpiece_ambiguous_scratch_allocation(self) -> None:
        self.refuses("underground_connector_workpieces", "\t_scratch.resize(6)", "\t_scratch.resize(6)\n\t_scratch.resize(6)")

    def test_negative_workpiece_omitted_bank_charge(self) -> None:
        self.refuses("underground_connector_workpieces", "2 * ROW_BYTES * placements", "ROW_BYTES * placements")

    def test_negative_workpiece_nonexact_admission(self) -> None:
        self.refuses("underground_connector_workpieces", "arena_bytes != required", "arena_bytes < required")

    def test_negative_workpiece_native_reserve_removed(self) -> None:
        self.refuses("underground_connector_workpieces", "NATIVE_RESERVE: int = 8192", "NATIVE_RESERVE: int = 0")

    def test_negative_workpiece_control_reserve_reduced(self) -> None:
        self.refuses("underground_connector_workpieces", "CONTROL_BYTES: int = 2048", "CONTROL_BYTES: int = 1024")

    def test_negative_workpiece_changed_base(self) -> None:
        self.refuses("underground_connector_workpieces", "extends RefCounted", 'extends "res://scripts/core/underground_connector_placements.gd"')

    def test_negative_entry_structure_extra_packet(self) -> None:
        line = "var _entry_frontier: WeakRef = null"
        self.refuses("underground_entry_structure", line, line + "\nvar _extra: Owner.Region = null")

    def test_negative_entry_structure_wider_frame(self) -> None:
        self.refuses("underground_entry_structure", "_entry_frame: PackedInt32Array", "_entry_frame: PackedInt64Array")

    def test_negative_entry_structure_larger_episode(self) -> None:
        self.refuses("underground_entry_structure", "_entry_episode.resize(19)", "_entry_episode.resize(20)")

    def test_negative_entry_structure_duplicate_resize(self) -> None:
        line = "\t_entry_frame.resize(9)"
        self.refuses("underground_entry_structure", line, line + "\n" + line)

    def test_negative_entry_structure_missing_resize(self) -> None:
        self.refuses("underground_entry_structure", "\t_entry_frame.resize(9)", "")

    def test_negative_entry_structure_reserve_change(self) -> None:
        self.refuses("underground_entry_structure", "ENTRY_CONTROL_BYTES: int = 384", "ENTRY_CONTROL_BYTES: int = 432")

    def test_negative_entry_structure_missing_cold_coexistence(self) -> None:
        self.refuses("underground_entry_structure", " + ENTRY_CONTROL_BYTES > Budget.COLD_BYTES", " > Budget.COLD_BYTES")

    def test_negative_entry_structure_changed_parent(self) -> None:
        self.refuses("underground_entry_structure", 'extends "res://scripts/core/underground_phase_structure.gd"', 'extends RefCounted')

    def test_negative_entry_structure_base_growth_exceeds_original_cold_ceiling(self) -> None:
        self.refuses("underground_phase_structure", "CONTROL_BYTES: int = 1536", "CONTROL_BYTES: int = 1600")

    def test_negative_entry_structure_base_formula_drift(self) -> None:
        self.refuses("underground_phase_structure", "2 * (48 * Budget.PHASE_VOLUME_CAPACITY + sources)",
                     "3 * (48 * Budget.PHASE_VOLUME_CAPACITY + sources)")

    def test_negative_entry_structure_base_trailing_return_charge(self) -> None:
        line = "return 2 * (48 * Budget.PHASE_VOLUME_CAPACITY + sources) + plans + 8 * region_rows + CONTROL_BYTES"
        self.refuses("underground_phase_structure", line, line + " + 1024")

    def test_negative_entry_structure_base_trailing_plan_growth(self) -> None:
        line = "var plans: int = 144 * PLAN_ROWS"
        self.refuses("underground_phase_structure", line, line + " * 2")

    def test_negative_entry_structure_base_trailing_source_growth(self) -> None:
        line = "var sources: int = 16 * Budget.SOURCE_CAPACITY"
        self.refuses("underground_phase_structure", line, line + " * 2")

    def test_negative_entry_structure_base_comment_witness(self) -> None:
        line = "\tvar plans: int = 144 * PLAN_ROWS"
        self.refuses("underground_phase_structure", line, "\t#" + line + "\n" + line + " * 2")

    def test_negative_entry_structure_base_duplicate_statement(self) -> None:
        line = "\tvar sources: int = 16 * Budget.SOURCE_CAPACITY"
        self.refuses("underground_phase_structure", line, line + "\n" + line)

    def test_negative_entry_structure_base_duplicate_function(self) -> None:
        signature = "static func cold_peak_bytes(mode: int, region_rows: int) -> int:"
        source = self.index["underground_phase_structure"].text
        self.refuses("underground_phase_structure", source, source + "\n" + signature + '\n\t"""Duplicate."""\n\treturn -1\n')

    def test_negative_frontier_extra_retained_column(self) -> None:
        line = "var _episode: PackedInt32Array = PackedInt32Array()"
        self.refuses("underground_entry_frontier", line, line + "\nvar _extra: PackedInt32Array = PackedInt32Array()")

    def test_negative_frontier_wider_work_revision_bank(self) -> None:
        self.refuses("underground_entry_frontier", "_profile_revision: PackedInt64Array", "_profile_revision: PackedInt32Array")

    def test_negative_frontier_hidden_extra_station(self) -> None:
        self.refuses("underground_entry_frontier", "_station.resize(9 * _capacities[STATION])", "_station.resize(10 * _capacities[STATION])")

    def test_negative_frontier_wire_width_charge_drift(self) -> None:
        self.refuses("underground_entry_frontier", "(44 if table == STATION", "(32 if table == STATION")

    def test_negative_frontier_envelope_overbooks_all_remaining_bindings(self) -> None:
        self.refuses("underground_entry_frontier", "MAX_BYTES: int = 28597", "MAX_BYTES: int = 40000")

    def test_negative_frontier_consumes_contacts_earmark(self) -> None:
        self.refuses("underground_entry_frontier", "MAX_BYTES: int = 28597", "MAX_BYTES: int = 28598")

    def test_negative_frontier_inherits_unaccounted_state(self) -> None:
        self.refuses("underground_entry_frontier", "extends RefCounted",
                     'extends "res://scripts/core/underground_connector_placements.gd"')

    def test_negative_frontier_omits_fixed_initial_charge(self) -> None:
        self.refuses("underground_entry_frontier", "var total: int = FIXED_BYTES", "var total: int = 0")

    def test_negative_frontier_configure_undercharges_station_count(self) -> None:
        self.refuses("underground_entry_frontier", "total += capacities[table] * wire_row_bytes(table)",
                     "total += wire_row_bytes(table)")

    def test_negative_entry_binding_extra_retained_record(self) -> None:
        line = "var _entry_contact: Locations.Record = Locations.Record.new()"
        self.refuses("underground_entry_bindings", line, line + "\nvar _second_contact: Locations.Record = null")

    def test_negative_entry_binding_larger_contact_envelope(self) -> None:
        self.refuses("underground_entry_bindings", "_entry_contact.envelope.resize(6)", "_entry_contact.envelope.resize(12)")

    def test_negative_entry_binding_duplicate_scratch_allocation(self) -> None:
        line = "\t_entry_row.resize(ENTRY_EPISODE_FIELDS)"
        self.refuses("underground_entry_bindings", line, line + "\n" + line)

    def test_negative_entry_binding_nonempty_transform_map(self) -> None:
        line = "\t_entry_transform.origin = plan.origin_u"
        self.refuses("underground_entry_bindings", line, line + "\n\t_entry_transform.endpoint_refs.resize(32)")

    def test_negative_entry_binding_inherited_authority_growth(self) -> None:
        self.refuses("underground_connector_placements", "class Authority extends RefCounted:",
                     "class Authority extends RefCounted:\n\tvar hidden: PackedByteArray = PackedByteArray()")

    def test_negative_entry_binding_helper_headroom_shortfall(self) -> None:
        self.refuses("underground_entry_bindings", "ENTRY_FIXED_BYTES: int = 4096", "ENTRY_FIXED_BYTES: int = 2048")

    def test_negative_entry_binding_changed_parent(self) -> None:
        self.refuses("underground_entry_bindings", 'extends "res://scripts/core/underground_room_bindings.gd"', 'extends RefCounted')

    def test_negative_contacts_changed_parent(self) -> None:
        self.refuses("underground_connector_contacts", 'extends "res://scripts/core/underground_connector_work.gd".Contacts',
                     'extends RefCounted')

    def test_negative_contacts_inherited_state(self) -> None:
        self.refuses("underground_connector_work", "class Contacts extends RefCounted:",
                     "class Contacts extends RefCounted:\n\tvar hidden: PackedByteArray = PackedByteArray()")

    def test_negative_contacts_unbudgeted_retained_packet(self) -> None:
        line = "var _other: Locations.Record = Locations.Record.new()"
        self.refuses("underground_connector_contacts", line, line + "\nvar _extra: Locations.Record = null")

    def test_negative_contacts_wider_scratch(self) -> None:
        self.refuses("underground_connector_contacts", "_frame: PackedInt32Array", "_frame: PackedInt64Array")

    def test_negative_contacts_missing_scratch_allocation(self) -> None:
        self.refuses("underground_connector_contacts", "\t_frame.resize(9)", "")

    def test_negative_contacts_wider_episode(self) -> None:
        self.refuses("underground_connector_contacts", "_episode: PackedInt32Array", "_episode: PackedInt64Array")

    def test_negative_contacts_episode_growth(self) -> None:
        self.refuses("underground_connector_contacts", "\t_episode.resize(19)", "\t_episode.resize(20)")

    def test_negative_contacts_duplicate_scratch_allocation(self) -> None:
        line = "\t_frame.resize(9)"
        self.refuses("underground_connector_contacts", line, line + "\n" + line)

    def test_negative_contacts_fragment_bank_growth(self) -> None:
        self.refuses("underground_connector_contacts", "FRAGMENT_CAPACITY: int = 32", "FRAGMENT_CAPACITY: int = 33")

    def test_negative_contacts_fragment_width_growth(self) -> None:
        self.refuses("underground_connector_contacts", "first: PackedInt32Array", "first: PackedInt64Array")

    def test_negative_contacts_unbudgeted_nested_bank(self) -> None:
        line = "class Fragments extends RefCounted:"
        self.refuses("underground_connector_contacts", line, line + "\n\tvar extra: PackedByteArray = PackedByteArray()")

    def test_negative_contacts_nested_location_growth(self) -> None:
        self.refuses("underground_connector_contacts", "_other.envelope.resize(6)", "_other.envelope.resize(12)")

    def test_negative_contacts_untyped_nested_location(self) -> None:
        line = "class Record extends RefCounted:"
        self.refuses("underground_locations", line, line + "\n\tvar hidden = []")

    def test_negative_contacts_inherited_numeric_result(self) -> None:
        self.refuses("int_math", "class IntResult:", "class IntResult extends RefCounted:")

    def test_negative_contacts_unbudgeted_descriptor_packet(self) -> None:
        line = "class Descriptor extends RefCounted:"
        self.refuses("underground_profiles", line, line + "\n\tvar extra: PackedByteArray = PackedByteArray()")

    def test_negative_contacts_numeric_result_width_drift(self) -> None:
        self.refuses("int_math", "\tvar value: int\n", "\tvar value: Vector2i\n")

    def test_negative_contacts_helper_allowance_shortfall(self) -> None:
        self.refuses("underground_connector_contacts", "CONTROL_BYTES: int = 4096", "CONTROL_BYTES: int = 3000")

    def test_negative_contacts_untyped_retained_field(self) -> None:
        line = "var _other: Locations.Record = Locations.Record.new()"
        self.refuses("underground_connector_contacts", line, line + "\nvar _untyped = []")

    def entry_world_refuses(self, before: str, after: str) -> None:
        with self.assertRaises(AssertionError):
            budget.entry_world_reservation(self.changed("underground_entry_world_bindings", before, after))

    def test_entry_world_counts_one_borrowed_contact_packet(self) -> None:
        result = budget.entry_world_reservation(self.index)
        self.assertEqual(result["numeric_control_bytes"], 130)
        self.assertEqual(result["fixed_numeric_and_packed_bytes"], 202)
        self.assertEqual(result["logical_helper_allowance_bytes"], 1024)
        self.assertEqual(result["reserved_bytes"], 2048)

    def test_negative_entry_world_wider_box(self) -> None:
        self.entry_world_refuses("_entry_box: PackedInt32Array", "_entry_box: PackedInt64Array")

    def test_negative_entry_world_larger_box(self) -> None:
        self.entry_world_refuses("_entry_box.resize(6)", "_entry_box.resize(7)")

    def test_negative_entry_world_missing_resize(self) -> None:
        self.entry_world_refuses("\t_entry_air.resize(6)", "")

    def test_negative_entry_world_duplicate_resize(self) -> None:
        line = "\t_entry_reach.resize(6)"
        self.entry_world_refuses(line, line + "\n" + line)

    def test_negative_entry_world_wider_origin(self) -> None:
        self.entry_world_refuses("_entry_origin: Vector3i", "_entry_origin: Vector4i")

    def test_negative_entry_world_extra_owned_packet(self) -> None:
        line = "var _entry_contacts: WeakRef = null"
        self.entry_world_refuses(line, line + "\nvar _extra: PhaseContacts = PhaseContacts.new()")

    def test_negative_entry_world_duplicate_control(self) -> None:
        line = "var _entry_reading: bool = false"
        self.entry_world_refuses(line, line + "\n" + line)

    def test_negative_entry_world_untyped_collection(self) -> None:
        line = "var _entry_reading: bool = false"
        self.entry_world_refuses(line, line + "\nvar _extra = []")

    def test_negative_entry_world_strong_contact_owner(self) -> None:
        self.entry_world_refuses("_entry_contacts: WeakRef", "_entry_contacts: PhaseContacts")

    def test_negative_entry_world_changed_base(self) -> None:
        self.entry_world_refuses('extends "res://scripts/core/underground_world_bindings.gd"', 'extends RefCounted')

    def test_negative_entry_world_reserve_growth(self) -> None:
        self.entry_world_refuses("ENTRY_CONTROL_BYTES: int = 2048", "ENTRY_CONTROL_BYTES: int = 4096")

    def test_negative_entry_world_preallocated_initializer(self) -> None:
        self.entry_world_refuses("_entry_box: PackedInt32Array = PackedInt32Array()",
                                 "_entry_box: PackedInt32Array = PackedInt32Array(range(4096))")

    def test_negative_entry_world_unaccounted_array_growth(self) -> None:
        line = "\t_entry_box.resize(6)"
        self.entry_world_refuses(line, line + "\n\t_entry_box.append_array(PackedInt32Array(range(4096)))")

    def test_negative_entry_world_array_alias_growth(self) -> None:
        line = "\t_entry_box.resize(6)"
        self.entry_world_refuses(line, line + "\n\tvar alias: PackedInt32Array = _entry_box\n\talias.resize(4096)")

    def test_negative_entry_world_reassigned_array(self) -> None:
        line = "\t_entry_box.resize(6)"
        self.entry_world_refuses(line, line + "\n\t_entry_box = PackedInt32Array(range(4096))")

    def test_negative_entry_world_unaccounted_local_packed_scratch(self) -> None:
        line = "\t_entry_contacts = weakref(actual)"
        self.entry_world_refuses(line,
            "\tvar scratch: PackedInt32Array = PackedInt32Array(range(4096))\n\tscratch.fill(0)\n" + line)

    def test_negative_entry_world_getter_constructs_contacts(self) -> None:
        self.entry_world_refuses("return _entry_contacts.get_ref() as PhaseContacts if _entry_contacts != null else null",
                                 "return PhaseContacts.new()")

    def test_negative_entry_world_getter_returns_foreign_packet(self) -> None:
        self.entry_world_refuses("return _entry_contacts.get_ref() as PhaseContacts if _entry_contacts != null else null",
                                 "return _entry_contacts.get_ref().foreign_contacts")

    def test_negative_entry_world_duplicate_getter(self) -> None:
        line = "func _entry_actual() -> PhaseContacts:"
        self.entry_world_refuses(line, "func _entry_actual() -> PhaseContacts:\n\treturn null\n\n" + line)

    def test_negative_contacts_duplicate_field(self) -> None:
        line = "var _other: Locations.Record = Locations.Record.new()"
        self.refuses("underground_connector_contacts", line, line + "\n" + line)


if __name__ == "__main__":
    unittest.main(verbosity=2)
