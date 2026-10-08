extends RefCounted
## Section 6 AUXILIARY_STATE immutable framing table (ADR 1222 step 4a).
##
## tools/generate_auxiliary_state_schema.py compiles the marked region below from the canonical
## registry's section-6 owners plus docs/planning/registry_capacity_audit.json. Nothing here reads
## JSON at runtime, instantiates a live store or calls an owner module. Every index is
## section-local; `ordinal` is the field's position WITHIN its owner.
##
## COUNT RULES (one per field):
##   RULE_SCALAR   -- exactly 1 element.
##   RULE_FIXED    -- exactly `rule_value` elements (a proved declared capacity, or `count: n`).
##   RULE_BOUNDED  -- 0..`rule_value` elements, checked BEFORE any slice or allocation.
##   RULE_UNPROVED -- no bound is provable from the registry or the audit, so NONE IS GUESSED: the
##                    field admits zero elements only, which is its canonical empty form. Lifting
##                    this needs a proved bound in the audit and a regenerated table.
##
## Pinned expectations sit OUTSIDE the generated region so a regenerated table that moved the owner
## set or the section schema is refused by `table_refusal()` rather than believed.

const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

const EXPECTED_OWNER_COUNT: int = 25
const EXPECTED_SECTION_SCHEMA_VERSION: int = 10

const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_U64: int = 3
const TYPE_I64: int = 4
const TYPE_WIDTHS: Array[int] = [1, 4, 4, 8, 8]

const RULE_SCALAR: int = 0
const RULE_FIXED: int = 1
const RULE_BOUNDED: int = 2
const RULE_UNPROVED: int = 3

const STORE_COUNT_BYTES: int = 4
const WRAPPER_FIXED_BYTES: int = 24
const FIELD_COUNT_BYTES: int = 8

const REFUSE_TABLE: StringName = &"SAVE_S6_TABLE"

# --- BEGIN GENERATED AUXILIARY STATE SCHEMA ---
# Generated from docs/planning/canonical_state_registry.json and
# docs/planning/registry_capacity_audit.json by tools/generate_auxiliary_state_schema.py.
# Registry RWL-CANONICAL-REGISTRY-2026-10-08-UG2 v16.
# Do not hand-edit. 25 owners, 182 fields, 14 UNPROVED (zero-only) fields.

const SECTION_SCHEMA_VERSION: int = 10
const REGISTRY_VERSION: int = 16
const OWNER_COUNT: int = 25
const FIELD_COUNT: int = 182
const EMPTY_SECTION_BYTES: int = 12446410
const MAX_SECTION_BYTES: int = 24994176

const OWNER_KEYS: Array[String] = [
	"buildings", "command_dispatch", "construction_extension", "construction_paid_ledger",
	"crop_weather", "demolition_admissions", "demolition_work", "ecology", "excavation_inventory",
	"excavation_sites", "haul_planner", "inventory", "modular_projects", "room_layout",
	"room_projects", "spoil_tips", "store_policy", "underground_connector_contacts",
	"underground_connector_placements", "underground_connector_workpieces",
	"underground_entry_progress", "underground_locations", "underground_mount",
	"underground_routes", "underground_world_routes",
]

const OWNER_SCHEMAS: Array[int] = [
	1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
]

const OWNER_FIELD_BEGIN: Array[int] = [
	0, 2, 6, 22, 24, 26, 33, 37, 38, 56, 96, 101, 109, 113, 129, 140, 160, 163, 165, 167, 169, 173,
	175, 178, 180,
]

const OWNER_FIELD_COUNTS: Array[int] = [
	2, 4, 16, 2, 2, 7, 4, 1, 18, 40, 5, 8, 4, 16, 11, 20, 3, 2, 2, 2, 4, 2, 3, 2, 2,
]

const FIELD_KEYS: Array[String] = [
	"_r_spatial_kind", "_f_installed", "_intent_player_id", "_intent_sequence_high",
	"_intent_sequence_low", "_intent_zone_generation", "_present", "_material_container_slot",
	"_material_container_generation", "_assigned_count", "_max_workers", "_refund_policy",
	"_remaining_mwu", "_paused", "_work_begun", "_ref_slot", "_ref_generation", "_subject_slot",
	"_subject_generation", "_purpose", "_type_id", "_phase", "_paid_base_type",
	"_paid_upgrade_mask", "_last_day", "_last_hour_tick", "_project_slot", "_project_generation",
	"_output_slot", "_output_generation", "_output_reserved_g", "_admitted_charge_g",
	"_destination_revision", "_intent_slot", "_intent_generation", "_job_slot", "_job_generation",
	"_last_day", "_capacity", "_free_count", "_free", "_project_slot", "_project_generation",
	"_head", "_output_slot", "_output_generation", "_output_mass_g", "_r_next", "_r_item",
	"_r_quality", "_r_provenance", "_r_recipe", "_r_quantity", "_r_age", "_r_remainder",
	"_lost_milli", "_capacity", "_count", "_domain_capacity", "_initial_earth_milli",
	"_virgin_sourced_milli", "_funded_braces", "_completed_braces", "_salvaged_braces",
	"_returned_brace_milli", "_world_slot", "_world_generation", "_datum_u_x", "_datum_u_y",
	"_datum_u_z", "_minimum_quantum_x", "_minimum_quantum_y", "_minimum_quantum_z",
	"_size_quanta_x", "_size_quanta_y", "_size_quanta_z", "_site_key", "_present", "_phase",
	"_installed", "_ever_cut", "_closure_before", "_embedded_milli", "_earned_mwu", "_room_slot",
	"_room_generation", "_project_slot", "_project_generation", "_operation", "_job_slot",
	"_job_generation", "_output_slot", "_output_generation", "_promotion_tile", "_worker_site",
	"_worker_generation", "_job_generation", "_dest_slot", "_dest_generation", "_dest_tile",
	"_reserved_g", "_spatial_capacity", "_spatial_world_slot", "_spatial_world_generation",
	"_spatial_container_slot", "_spatial_container_generation", "_spatial_location_slot",
	"_spatial_location_generation", "_spatial_location_revision", "_job_slot", "_job_generation",
	"_project_slot", "_project_generation", "_room_capacity", "_placement_capacity",
	"_geometry_capacity", "_room_slots", "_room_generations", "_room_types", "_room_modes",
	"_state", "_generation", "_room_row", "_type", "_x", "_z", "_rotation", "_project_slot",
	"_project_generation", "_present", "_project_slot", "_project_generation", "_room_type",
	"_pause_reasons", "_revision_state", "_revision_epoch", "_job_slot", "_job_generation",
	"_job_project_slot", "_job_project_generation", "_world_slot", "_world_generation", "_capacity",
	"_count", "_compacted_milli", "_reclaimed_milli", "_present", "_retired", "_prepared",
	"_generation", "_tile", "_project_slot", "_project_generation", "_operation", "_embedded_milli",
	"_quantity_milli", "_locked_milli", "_incoming_milli", "_earned_mwu", "_retained_quantity",
	"_allowed", "_minimum_milli", "_bound_persistent_id", "wire_length", "wire", "wire_length",
	"wire", "wire_length", "wire", "progress_length", "progress_record", "queue_length", "_queue",
	"wire_length", "wire", "_mounted", "_operations_prefix", "_content_digest", "wire_length",
	"wire", "wire_length", "wire",
]

const FIELD_TYPES: Array[int] = [
	0, 0, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 4, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 4, 4,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 4, 4, 4, 4, 2, 2, 4, 4, 4, 4, 4, 4,
	4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 0, 0, 0, 0, 0, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 2, 2, 2, 2, 2, 2,
	2, 0, 2, 2, 2, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 0, 0, 0, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4,
	0, 4, 2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 1, 0, 0, 2, 0, 1, 0, 1, 0,
]

const RULE_KINDS: Array[int] = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1,
	1, 1, 1, 1, 1, 0, 0, 0, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
	1, 1, 1, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 0, 1, 0, 2, 0, 2,
]

const RULE_VALUES: Array[int] = [
	16384, 81920, 128, 128, 128, 128, 82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944,
	82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944, 1, 1, 1024, 1024, 1024, 1024,
	1024, 1024, 1024, 1024, 1024, 1024, 1024, 1, 1, 1, 32768, 82944, 82944, 82944, 82944, 82944,
	82944, 32768, 32768, 32768, 32768, 32768, 32768, 32768, 32768, 1024, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 73909, 73909, 73909, 73909, 73909, 73909, 73909, 369545, 73909,
	73909, 73909, 73909, 73909, 73909, 73909, 73909, 73909, 73909, 512, 512, 8192, 8192, 8192, 8192,
	8192, 1, 1, 1, 1024, 1024, 1024, 1024, 1024, 8192, 8192, 8192, 8192, 1, 1, 1, 16384, 16384,
	16384, 16384, 81920, 81920, 81920, 81920, 81920, 81920, 81920, 81920, 81920, 82944, 82944,
	82944, 82944, 82944, 82944, 82944, 8192, 8192, 8192, 8192, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 262144, 262144, 1024, 1, 74, 1, 43776, 1, 5436, 1, 4591, 1, 8, 1,
	110464, 1, 1, 32, 1, 320608, 1, 84184,
]

const UNPROVED_FIELDS: Array[String] = [
	"spoil_tips._present", "spoil_tips._retired", "spoil_tips._prepared", "spoil_tips._generation",
	"spoil_tips._tile", "spoil_tips._project_slot", "spoil_tips._project_generation",
	"spoil_tips._operation", "spoil_tips._embedded_milli", "spoil_tips._quantity_milli",
	"spoil_tips._locked_milli", "spoil_tips._incoming_milli", "spoil_tips._earned_mwu",
	"spoil_tips._retained_quantity",
]
# --- END GENERATED AUXILIARY STATE SCHEMA ---


static func owner_valid(owner: int) -> bool:
	"""True for a section-6 owner index."""
	return owner >= 0 and owner < OWNER_COUNT


static func field_valid(owner: int, ordinal: int) -> bool:
	"""True for a declared (owner, ordinal) pair."""
	return owner_valid(owner) and ordinal >= 0 and ordinal < OWNER_FIELD_COUNTS[owner]


static func field_count_of(owner: int) -> int:
	"""How many fields `owner` declares. Call `owner_valid()` first."""
	return OWNER_FIELD_COUNTS[owner]


static func field_key_of(owner: int, ordinal: int) -> String:
	"""The registry key of one field. Call `field_valid()` first."""
	return FIELD_KEYS[OWNER_FIELD_BEGIN[owner] + ordinal]


static func field_type_of(owner: int, ordinal: int) -> int:
	"""The type code (TYPE_*) of one field. Call `field_valid()` first."""
	return FIELD_TYPES[OWNER_FIELD_BEGIN[owner] + ordinal]


static func rule_kind_of(owner: int, ordinal: int) -> int:
	"""The count rule (RULE_*) of one field. Call `field_valid()` first."""
	return RULE_KINDS[OWNER_FIELD_BEGIN[owner] + ordinal]


static func rule_value_of(owner: int, ordinal: int) -> int:
	"""The count rule's value: 1, the fixed count, the bound, or 0 for an unproved field."""
	return RULE_VALUES[OWNER_FIELD_BEGIN[owner] + ordinal]


static func width_of(owner: int, ordinal: int) -> int:
	"""Bytes per element of one field."""
	return TYPE_WIDTHS[field_type_of(owner, ordinal)]


static func ordinal_of(owner: int, field_key: String) -> int:
	"""The ordinal of `field_key` within `owner`, or -1."""
	for ordinal: int in OWNER_FIELD_COUNTS[owner]:
		if field_key_of(owner, ordinal) == field_key:
			return ordinal
	return -1


static func empty_count_of(owner: int, ordinal: int) -> int:
	"""The canonical empty element count: 1 for a scalar, n for FIXED(n), else 0."""
	var kind: int = rule_kind_of(owner, ordinal)
	if kind == RULE_SCALAR or kind == RULE_FIXED:
		return rule_value_of(owner, ordinal)
	return 0


static func max_count_of(owner: int, ordinal: int) -> int:
	"""The largest admissible element count of one field."""
	if rule_kind_of(owner, ordinal) == RULE_UNPROVED:
		return 0
	return rule_value_of(owner, ordinal)


static func count_admissible(owner: int, ordinal: int, count: int) -> bool:
	"""Whether `count` satisfies the field's rule. Never allocates; safe for any int."""
	var kind: int = rule_kind_of(owner, ordinal)
	if kind == RULE_BOUNDED:
		return count >= 0 and count <= rule_value_of(owner, ordinal)
	return count == empty_count_of(owner, ordinal)


static func wrapper_bytes_of(owner: int) -> int:
	"""One block's wrapper: key length, key, schema, primary count and payload length."""
	return WRAPPER_FIXED_BYTES + OWNER_KEYS[owner].to_utf8_buffer().size()


static func payload_bytes_at(owner: int, maximum: bool) -> int:
	"""The owner's payload with every field at its canonical-empty or its maximum count."""
	var total: int = 0
	for ordinal: int in OWNER_FIELD_COUNTS[owner]:
		var count: int = max_count_of(owner, ordinal) if maximum else empty_count_of(owner, ordinal)
		total += FIELD_COUNT_BYTES + count * width_of(owner, ordinal)
	return total


static func section_bytes_at(maximum: bool) -> int:
	"""The whole section's length with every field at its canonical-empty or maximum count."""
	var total: int = STORE_COUNT_BYTES
	for owner: int in OWNER_COUNT:
		total += wrapper_bytes_of(owner) + payload_bytes_at(owner, maximum)
	return total


static func table_refusal() -> SaveHeader.Refusal:
	"""Prove the compiled table is self-consistent and matches the pinned expectations."""
	var shape: String = _shape_detail()
	if shape == "":
		shape = _order_detail()
	if shape == "" and section_bytes_at(false) != EMPTY_SECTION_BYTES:
		shape = "empty section derives %d bytes, not %d" % [section_bytes_at(false),
			EMPTY_SECTION_BYTES]
	if shape == "" and section_bytes_at(true) != MAX_SECTION_BYTES:
		shape = "maximum section derives %d bytes, not %d" % [section_bytes_at(true),
			MAX_SECTION_BYTES]
	if shape != "":
		return SaveHeader.Refusal.new(REFUSE_TABLE, shape)
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


static func _shape_detail() -> String:
	"""Pinned counts and column lengths, or "" when they agree."""
	if OWNER_COUNT != EXPECTED_OWNER_COUNT \
			or SECTION_SCHEMA_VERSION != EXPECTED_SECTION_SCHEMA_VERSION:
		return "table has %d owners at schema %d, pinned %d at %d" % [OWNER_COUNT,
			SECTION_SCHEMA_VERSION, EXPECTED_OWNER_COUNT, EXPECTED_SECTION_SCHEMA_VERSION]
	for column: Array in [OWNER_KEYS, OWNER_SCHEMAS, OWNER_FIELD_BEGIN, OWNER_FIELD_COUNTS]:
		if column.size() != OWNER_COUNT:
			return "an owner column has %d rows, not %d" % [column.size(), OWNER_COUNT]
	for column: Array in [FIELD_KEYS, FIELD_TYPES, RULE_KINDS, RULE_VALUES]:
		if column.size() != FIELD_COUNT:
			return "a field column has %d rows, not %d" % [column.size(), FIELD_COUNT]
	return ""


static func _order_detail() -> String:
	"""ASCII owner order and dense, contiguous per-owner field ranges, or ""."""
	var previous: String = ""
	var begin: int = 0
	for owner: int in OWNER_COUNT:
		if Digest.ascii_compare(previous, OWNER_KEYS[owner]) >= 0:
			return "'%s' does not follow '%s' in ASCII order" % [OWNER_KEYS[owner], previous]
		if OWNER_FIELD_BEGIN[owner] != begin:
			return "'%s' fields begin at %d, not %d" % [OWNER_KEYS[owner],
				OWNER_FIELD_BEGIN[owner], begin]
		previous = OWNER_KEYS[owner]
		begin += OWNER_FIELD_COUNTS[owner]
	return "" if begin == FIELD_COUNT else "owners span %d fields, not %d" % [begin, FIELD_COUNT]
