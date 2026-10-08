extends RefCounted
## Section 5 CHILD_ARENAS immutable framing table (ADR 1222 step 3).
##
## `tools/generate_auxiliary_state_schema.py --section 5` compiles the marked region below from the
## canonical registry's section-5 owners plus docs/planning/registry_capacity_audit.json. Section 5
## shares section 6's owner-block wire form, so this module has section 6's table API exactly;
## every section-5 field is FIXED at a proved capacity (or a SCALAR), so no count is bounded. Nothing here reads
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

const EXPECTED_OWNER_COUNT: int = 5
const EXPECTED_SECTION_SCHEMA_VERSION: int = 1

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

const REFUSE_TABLE: StringName = &"SAVE_S5_TABLE"

# --- BEGIN GENERATED CHILD ARENAS SCHEMA ---
# Generated from docs/planning/canonical_state_registry.json and
# docs/planning/registry_capacity_audit.json by tools/generate_auxiliary_state_schema.py --section 5.
# Registry RWL-CANONICAL-REGISTRY-2026-10-07-SL1 v14.
# Do not hand-edit. 5 owners, 32 fields, 0 UNPROVED (zero-only) fields.

const SECTION_SCHEMA_VERSION: int = 1
const REGISTRY_VERSION: int = 14
const OWNER_COUNT: int = 5
const FIELD_COUNT: int = 32
const EMPTY_SECTION_BYTES: int = 5081011
const MAX_SECTION_BYTES: int = 5081011

const OWNER_KEYS: Array[String] = [
	"buildings", "construction", "forage", "jobs", "orchard_hive",
]

const OWNER_SCHEMAS: Array[int] = [
	1, 1, 1, 1, 1,
]

const OWNER_FIELD_BEGIN: Array[int] = [
	0, 15, 16, 26, 30,
]

const OWNER_FIELD_COUNTS: Array[int] = [
	15, 1, 10, 4, 2,
]

const FIELD_KEYS: Array[String] = [
	"_b_ref_slot", "_b_ref_generation", "_b_room_head", "_b_room_count", "_r_ref_slot",
	"_r_ref_generation", "_r_building_next", "_r_building_prev", "_r_furniture_head",
	"_r_furniture_count", "_f_ref_slot", "_f_ref_generation", "_f_room_next", "_f_room_prev",
	"_room_tile_id", "_delivered_milli", "_link_bump", "_link_free_head", "_link_used",
	"_zone_link_head", "_zone_tile_count", "_zone_patch_count", "_link_tile", "_link_zone",
	"_link_tile_next", "_link_zone_next", "_coordinator_slot", "_coordinator_generation",
	"_member_head", "_member_next", "_link_hive_slot", "_link_hive_generation",
]

const FIELD_TYPES: Array[int] = [
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
]

const RULE_KINDS: Array[int] = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
]

const RULE_VALUES: Array[int] = [
	1024, 1024, 1024, 1024, 16384, 16384, 16384, 16384, 16384, 16384, 81920, 81920, 81920, 81920,
	16384, 331776, 1, 1, 1, 128, 128, 128, 16384, 16384, 16384, 16384, 8192, 8192, 8192, 8192,
	30720, 30720,
]

const UNPROVED_FIELDS: Array[String] = []
# --- END GENERATED CHILD ARENAS SCHEMA ---


static func owner_valid(owner: int) -> bool:
	"""True for a section-5 owner index."""
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
