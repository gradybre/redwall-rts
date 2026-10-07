extends RefCounted
## ARCH-SAVE-002 section 1 WORLD, THE WHOLE SECTION: all nine owners, their exact wire framing,
## their semantic validators, their restore path and their canonical value adapters.
##
## R-WORLD-S1-001 (docs/rulings/2026-09-14_world_section_owner_encoders.md) is the binding
## contract for the nine owners it names. ADR 1072 declared a TENTH, `underground_space_owner`, and
## took the section to schema 4; ADR 1222 step 0 brought this codec to that declaration. Blocks
## appear in strict ASCII key order and a missing block is not a permitted variant.
## `save_section_world_runtime.gd` still owns the two fixed-format payloads -- the 4-byte
## `entity_directory` cursor and the 80-byte `world_runtime` body -- and this module composes the
## section around them, so neither layout is written twice.
##
## THE SECTION (all offsets section-relative, little-endian, no padding):
##
##   |      0 | scenario_version:u32                                        |      4 |
##   |      4 | effective_seed:i32                                          |      4 |
##   |      8 | map_generator_schema:u32                                    |      4 |
##   |     12 | authored_map_digest: raw bytes                              |     32 |
##   |     44 | store_count:u32, exactly 10                                 |      4 |
##   |     48 | ten owner blocks, ASCII key order, tiling to the section end         |
##
## Each wrapper is `owner_key_byte_count:u32, owner_key, owner_schema_version:u32,
## primary_count:u64, payload_byte_length:u64, payload`, occupying `24 + len(owner_key)` bytes.
##
## EXACTLY TWO COMPILED LAYOUTS (ADR 1222 step 0). The Space owner exists only while an
## underground Session is mounted, so its block has an UNMOUNTED form (capacities 0, an all-zero
## 18-entry header, every column empty: 416 payload bytes) and a MOUNTED form at the production
## pack (6144 regions, 2048 sources: 504224 payload bytes). The decoder reads the two capacity
## scalars at their compiled offsets -- identical in both layouts, since no earlier block changes
## -- selects the layout they name, and then finds every later item at THAT layout's compiled
## offset. Any other capacity pair, or a length that is not the named layout's, refuses.
##
## | Owner                   | Schema | primary (U / M) | Payload bytes (U / M) |
## |-------------------------|-------:|----------------:|----------------------:|
## | buildings               |      1 |          16,384 |               196,632 |
## | entity_directory        |      1 |               1 |                     4 |
## | farming                 |      1 |          16,384 |               737,360 |
## | forage                  |      1 |          16,384 |                65,544 |
## | resource_nodes          |      2 |          16,384 |                65,544 |
## | spatial_world           |      1 |         262,144 |             2,621,484 |
## | underground_space_owner |      1 |       0 / 6,144 |         416 / 504,224 |
## | weather                 |      1 |               1 |                    64 |
## | world_init              |      1 |          16,384 |                65,697 |
## | world_runtime           |      1 |               1 |                    80 |
##
## Section length 3,753,231 UNMOUNTED / 4,257,039 MOUNTED. The descriptor's `row_count` is the
## checked SUM of the ten primary counts, 344,067 / 350,211 -- not a population, not a field
## count and not the canonical record count.
##
## THE EIGHT ORDINARY OWNERS USE ONE PAYLOAD FORM: for each field in declared ordinal order,
## `element_count:u64` then exactly `element_count * type_width` value bytes. EVERY SCALAR CARRIES
## AN EXPLICIT `element_count = 1`. There is no payload field-count word, no repeated field name or
## type, no length inferred from the bytes that remain, and no child-table header. Those count
## prefixes are STRUCTURAL BYTES and contribute no canonical field record. `entity_directory` and
## `world_runtime` keep their existing fixed formats and have no count prefixes at all.
##
## WHY THE DECODER READS AT ABSOLUTE OFFSETS. This project has been bitten three times by a check
## that derived its expectation from the thing it was checking. `_read_block()` at offset O is
## therefore given O from the COMPILED TABLE below, never from where the previous block happened
## to end, and every declared extent in a wrapper -- key length, schema, primary count, payload
## length -- is COMPARED against that table rather than used to advance a cursor. A swapped pair of
## owners is caught because the key at a fixed offset is the wrong key; a lying payload length is
## caught because it is not the constant. The same rule governs fields: `element_count` at its
## compiled offset must EQUAL the compiled count, and the values are sliced from the compiled value
## offset. A decoder that recomputed those offsets from the counts it had just read would accept a
## consistently wrong file.
##
## THREE RESOURCE ARRAYS ARE DELIBERATELY ABSENT. R-WORLD-S1-001 §7 reclassified
## `resource_nodes._deposit_tiles`, `._deposit_ref_slot` and `._deposit_ref_generation` as
## CATEGORY-3 PLACEMENT SCRATCH: they describe one placement in progress, not a deposit ledger, and
## a failed placement leaves stale references in them. They contribute NO payload bytes, NO count
## prefix and NO canonical field record, which is why `resource_nodes` takes owner schema **2** and
## section 1 takes schema **3** in the same activation. Older bytes are NOT reinterpreted under the
## new versions: this codec refuses a section that is not exactly the target length, and no
## migration from the pre-correction layout is implemented or implied.
##
## NO FLOAT. ARCH-AUTH-002; `test_save_section_01.gd` greps this source to enforce it.
##
## COLD PATH. ARCH-SAVE-003. Payloads are assembled with native `PackedByteArray.append_array()`
## and `Packed*Array.to_byte_array()` rather than a per-value writer loop, because a per-byte
## GDScript loop over 3.75 MB is not a codec, it is a stall. `little_endian_refusal()` proves the
## native conversion is little-endian before any of it is trusted -- the format is LE by contract,
## and a silent big-endian host would otherwise produce a plausible, unreadable file.
##
## WHAT THIS MODULE DOES NOT CLAIM. It does not certify a release save. Cross-owner obligations
## that need state outside section 1 stay with their owners, `farming.gd`'s orchard inverse remains
## the open source-maintenance gate R-WORLD-S1-001 §6 names, and the 44-byte provenance prefix's
## VALUES still belong to the map/scenario producer (SAVE-R09-003), which is why none is invented
## here.

## Self-preload, so the inner Adapter class can reach this script's own static table. GDScript
## does not resolve an outer static function from an inner class by bare name.
const SaveSection01 := preload("res://scripts/core/save_section_01.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const WorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")

# --- identity and framing ---------------------------------------------------------------------

const SECTION_ID: int = 1

## R-WORLD-S1-001: section 1 moves to **3** with the resource scratch correction. The OWNER
## schemas inside it are a different namespace; see OWNER_SCHEMA_VERSIONS.
##
## READ from `save_section_world_runtime.gd` rather than restated. Two modules declaring the
## section's version independently is two numbers that can disagree, and the one that cannot
## preload the other has to be the definition: this module preloads that one.
const SECTION_SCHEMA_VERSION: int = WorldRuntime.SECTION_SCHEMA_VERSION

const PREFIX_BYTES: int = 44
const OFFSET_SCENARIO_VERSION: int = 0
const OFFSET_EFFECTIVE_SEED: int = 4
const OFFSET_MAP_GENERATOR_SCHEMA: int = 8
const OFFSET_AUTHORED_MAP_DIGEST: int = 12
const AUTHORED_MAP_DIGEST_BYTES: int = 32
const OFFSET_STORE_COUNT: int = 44
const STORE_COUNT_BYTES: int = 4
const FIRST_BLOCK_OFFSET: int = PREFIX_BYTES + STORE_COUNT_BYTES

## SAVE-LAYOUT-R01's wrapper, less the owner key's own bytes.
const WRAPPER_FIXED_BYTES: int = 24
const OWNER_KEY_MAX_BYTES: int = 256

## Type codes, shared with `canonical_state_hash.gd` so one table means one thing everywhere.
const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_U64: int = 3
const TYPE_I64: int = 4
const TYPE_WIDTHS: Array[int] = [1, 4, 4, 8, 8]

const OWNER_COUNT: int = 10
const OWNER_BUILDINGS: int = 0
const OWNER_ENTITY_DIRECTORY: int = 1
const OWNER_FARMING: int = 2
const OWNER_FORAGE: int = 3
const OWNER_RESOURCE_NODES: int = 4
const OWNER_SPATIAL_WORLD: int = 5
const OWNER_UNDERGROUND_SPACE: int = 6
const OWNER_WEATHER: int = 7
const OWNER_WORLD_INIT: int = 8
const OWNER_WORLD_RUNTIME: int = 9

## The ten keys in the strict ASCII order blocks must appear in.
const OWNER_KEYS: Array[String] = ["buildings", "entity_directory", "farming", "forage",
	"resource_nodes", "spatial_world", "underground_space_owner", "weather", "world_init",
	"world_runtime"]

## Only `resource_nodes` is not 1, and only because the deposit scratch left its payload.
const OWNER_SCHEMA_VERSIONS: Array[int] = [1, 1, 1, 1, 2, 1, 1, 1, 1, 1]

## ADR 1222 step 0: EXACTLY TWO compiled layouts, told apart by the space block's capacity
## scalars. UNMOUNTED is a world with no underground Session (capacities 0, an all-zero header,
## every column empty); MOUNTED is one at the production pack's fixed capacities. Every offset
## after the space block is compiled per layout; no other capacity pair is a layout.
const LAYOUT_UNMOUNTED: int = 0
const LAYOUT_MOUNTED: int = 1
const LAYOUT_COUNT: int = 2
const SPACE_REGION_CAPACITIES: Array[int] = [0, Budget.REGION_CAPACITY]
const SPACE_SOURCE_CAPACITIES: Array[int] = [0, Budget.SOURCE_CAPACITY]

## Declared primary physical row extents, UNMOUNTED layout. Grid-oriented for the mixed owners:
## `world_init` counts exterior tiles despite two scalars and three basin columns,
## `spatial_world` counts cells despite its revision scalar, `weather` counts ONE aggregate row
## despite ten values, and the space owner counts its regions (0 here, 6144 when MOUNTED).
const OWNER_PRIMARY_COUNTS: Array[int] = [16384, 1, 16384, 16384, 16384, 262144, 0, 1, 16384, 1]

## Exact payload widths, UNMOUNTED layout. Derived in `payload_bytes_of()` for the eight
## ordinary owners and checked against these constants, so a field-table edit that changes a
## width fails rather than drifts. The MOUNTED space payload is SPACE_MOUNTED_PAYLOAD_BYTES.
const OWNER_PAYLOAD_BYTES: Array[int] = [196632, 4, 737360, 65544, 65544, 2621484, 416, 64,
	65697, 80]
const SPACE_MOUNTED_PAYLOAD_BYTES: int = 504224

## Sum of the ten primary counts, per layout. The section descriptor's `row_count`, and nothing else.
const DESCRIPTOR_ROW_COUNTS: Array[int] = [344067, 350211]

## 44 + 4 + 358 wrapper bytes + the payloads: 3753231 UNMOUNTED, 4257039 MOUNTED.
const SECTION_BYTES_BY_LAYOUT: Array[int] = [3753231, 4257039]

## SAVE-REPLAY-R01 outer format2: header264 plus fifteen64-byte descriptors gives1224.
const FIRST_SECTION_OFFSET: int = 1224

# --- the seven ordinary owners' field tables ----------------------------------------------------
#
# Ordinal order IS wire order. Each entry's element count is the field's own declared extent and is
# independent of its owner's primary_count.

const BUILDINGS_FIELD_KEYS: Array[String] = ["_building_slot", "_room_slot", "_furniture_slot"]
const BUILDINGS_FIELD_TYPES: Array[int] = [TYPE_I32, TYPE_I32, TYPE_I32]
const BUILDINGS_FIELD_COUNTS: Array[int] = [16384, 16384, 16384]

const FARMING_FIELD_KEYS: Array[String] = ["_tile_fertility", "_tile_last_family",
	"_tile_family_streak", "_tile_last_legume_day", "_tile_compost_season",
	"_tile_active_plot_row", "_tile_orchard_row", "_tile_ripe_tick", "_tile_growth_remainder",
	"_tile_tended_today"]
const FARMING_FIELD_TYPES: Array[int] = [TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32,
	TYPE_I32, TYPE_I32, TYPE_I64, TYPE_I64, TYPE_U8]
const FARMING_FIELD_COUNTS: Array[int] = [16384, 16384, 16384, 16384, 16384, 16384, 16384,
	16384, 16384, 16384]

const FORAGE_FIELD_KEYS: Array[String] = ["_tile_link_head"]
const FORAGE_FIELD_TYPES: Array[int] = [TYPE_I32]
const FORAGE_FIELD_COUNTS: Array[int] = [16384]

const RESOURCE_FIELD_KEYS: Array[String] = ["_resource_slot"]
const RESOURCE_FIELD_TYPES: Array[int] = [TYPE_I32]
const RESOURCE_FIELD_COUNTS: Array[int] = [16384]

const SPATIAL_FIELD_KEYS: Array[String] = ["_map_revision", "_walkable", "_layer", "_terrain",
	"_height_units"]
const SPATIAL_FIELD_TYPES: Array[int] = [TYPE_I32, TYPE_U8, TYPE_U8, TYPE_I32, TYPE_I32]
const SPATIAL_FIELD_COUNTS: Array[int] = [1, 262144, 262144, 262144, 262144]

const WEATHER_FIELD_KEYS: Array[String] = ["_row", "_row64"]
const WEATHER_FIELD_TYPES: Array[int] = [TYPE_I32, TYPE_I64]
const WEATHER_FIELD_COUNTS: Array[int] = [8, 2]

const WORLD_INIT_FIELD_KEYS: Array[String] = ["_published", "_published_seed", "_terrain", "_soil",
	"_basin", "_cleared", "_basin_ref_slot", "_basin_ref_generation", "_basin_danger"]
const WORLD_INIT_FIELD_TYPES: Array[int] = [TYPE_U8, TYPE_I32, TYPE_U8, TYPE_U8, TYPE_U8, TYPE_U8,
	TYPE_I32, TYPE_I32, TYPE_I32]
const WORLD_INIT_FIELD_COUNTS: Array[int] = [1, 1, 16384, 16384, 16384, 16384, 7, 7, 7]

## `underground_space_owner` (ADR 1072, owner schema 1): REG-R01's 33 fields in ordinal order.
## Counts depend on the layout through each field's count kind: a scalar is 1, the header is
## HEADER_FIELDS (18), a region column is the layout's region capacity and a source column its
## source capacity. The owner's own wire (`state_bytes()`) holds the same 31 non-scalar columns in
## a DIFFERENT order; SPACE_WIRE_ORDER maps it.
const SPACE_FIELD_KEYS: Array[String] = ["_region_capacity", "_source_capacity", "_header",
	"_r_present", "_r_retired", "_r_role", "_r_claim_kind", "_r_generation", "_r_lo_x", "_r_lo_y",
	"_r_lo_z", "_r_hi_x", "_r_hi_y", "_r_hi_z", "_r_level", "_r_section_slot",
	"_r_section_generation", "_r_owner_slot", "_r_owner_generation", "_r_claim_slot",
	"_r_claim_generation", "_r_owner_revision", "_o_present", "_o_kind", "_o_slot",
	"_o_generation", "_o_parent_slot", "_o_parent_generation", "_o_a", "_o_b", "_o_c", "_o_d",
	"_o_revision"]
const SPACE_FIELD_TYPES: Array[int] = [TYPE_I32, TYPE_I32, TYPE_I64, TYPE_U8, TYPE_U8, TYPE_U8,
	TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32,
	TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I64, TYPE_U8, TYPE_U8,
	TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I64]
const SPACE_COUNT_SCALAR: int = 0
const SPACE_COUNT_HEADER: int = 1
const SPACE_COUNT_REGION: int = 2
const SPACE_COUNT_SOURCE: int = 3
const SPACE_FIELD_COUNT_KINDS: Array[int] = [0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
## Registry ordinals in the order `underground_space_owner.gd::_wire_columns()` writes them.
const SPACE_WIRE_ORDER: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
	21, 19, 20, 22, 23, 24, 25, 32, 26, 27, 28, 29, 30, 31]
## Header slots `_write_header()` fills from the schema and the two capacities; the last slot is
## the revision, at least 1 on a configured owner.
const SPACE_HEADER_SCHEMA: int = 0
const SPACE_HEADER_REGION_CAPACITY: int = 1
const SPACE_HEADER_SOURCE_CAPACITY: int = 2
const SPACE_HEADER_REVISION: int = 17

## `entity_directory` and `world_runtime` are the two fixed-format exceptions and declare no
## ordinary field table; their payloads carry no element-count prefixes at all.
## The two fixed-format owners declare no ordinary field table at all; these empty typed arrays
## are what `field_*_of()` returns for them, and their emptiness is what routes both owners to
## their own payload codecs.
const FIXED_FORMAT_FIELD_KEYS: Array[String] = []
const FIXED_FORMAT_FIELD_NUMBERS: Array[int] = []

const DIRECTORY_PAYLOAD_BYTES: int = WorldRuntime.DIRECTORY_PAYLOAD_BYTES
const RUNTIME_PAYLOAD_BYTES: int = WorldRuntime.BLOCK_BYTES

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_ENDIANNESS: StringName = &"SAVE_S1_HOST_NOT_LITTLE_ENDIAN"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_S1_NEGATIVE_OFFSET"
const REFUSE_SECTION_LENGTH: StringName = &"SAVE_S1_SECTION_LENGTH"
const REFUSE_TRUNCATED: StringName = &"SAVE_S1_TRUNCATED"
const REFUSE_PREFIX_FIELD: StringName = &"SAVE_S1_PREFIX_FIELD"
const REFUSE_STORE_COUNT: StringName = &"SAVE_S1_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_S1_OWNER_KEY"
const REFUSE_OWNER_SCHEMA: StringName = &"SAVE_S1_OWNER_SCHEMA"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_S1_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_S1_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_S1_ELEMENT_COUNT"
const REFUSE_NOT_TILED: StringName = &"SAVE_S1_SECTION_NOT_TILED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_S1_ENCODE_FAILED"
const REFUSE_COLUMN_SHAPE: StringName = &"SAVE_S1_COLUMN_SHAPE"
const REFUSE_STORE_MISSING: StringName = &"SAVE_S1_STORE_MISSING"
const REFUSE_CAPTURE_FAILED: StringName = &"SAVE_S1_CAPTURE_FAILED"
const REFUSE_RESTORE_FAILED: StringName = &"SAVE_S1_RESTORE_FAILED"
const REFUSE_SEED_DISAGREES: StringName = &"SAVE_S1_PUBLISHED_SEED_DISAGREES"
const REFUSE_UNSEEDED_PUBLISHED: StringName = &"SAVE_S1_PUBLISHED_WORLD_UNSEEDED"
const REFUSE_ADAPTER_FIELD: StringName = &"SAVE_S1_ADAPTER_UNKNOWN_FIELD"
const REFUSE_SPACE_LAYOUT: StringName = &"SAVE_S1_SPACE_LAYOUT"
const REFUSE_SPACE_HEADER: StringName = &"SAVE_S1_SPACE_HEADER"
const REFUSE_SPACE_MOUNT: StringName = &"SAVE_S1_SPACE_MOUNT"


# --- compiled offset table ----------------------------------------------------------------------

static func owner_key_of(owner: int) -> String:
	"""The exact ASCII owner key of block `owner`, 0..9 in wire order."""
	return OWNER_KEYS[owner]


static func wrapper_bytes_of(owner: int) -> int:
	"""`24 + len(owner_key)`, the wrapper's own width before its payload."""
	return WRAPPER_FIXED_BYTES + OWNER_KEYS[owner].to_utf8_buffer().size()


static func primary_count_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Block `owner`'s declared primary count in `layout`; only the space owner's varies."""
	if owner == OWNER_UNDERGROUND_SPACE:
		return SPACE_REGION_CAPACITIES[layout]
	return OWNER_PRIMARY_COUNTS[owner]


static func compiled_payload_bytes_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Block `owner`'s compiled payload width in `layout`, from the constant tables."""
	if owner == OWNER_UNDERGROUND_SPACE and layout == LAYOUT_MOUNTED:
		return SPACE_MOUNTED_PAYLOAD_BYTES
	return OWNER_PAYLOAD_BYTES[owner]


static func block_offset_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Section-relative offset of block `owner` in `layout`, summed from the compiled widths."""
	var offset: int = FIRST_BLOCK_OFFSET
	for index: int in owner:
		offset += wrapper_bytes_of(index) + compiled_payload_bytes_of(index, layout)
	return offset


static func payload_offset_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Section-relative offset of block `owner`'s first payload byte in `layout`."""
	return block_offset_of(owner, layout) + wrapper_bytes_of(owner)


static func section_bytes_of(layout: int) -> int:
	"""The exact section length of `layout`."""
	return SECTION_BYTES_BY_LAYOUT[layout]


static func field_keys_of(owner: int) -> Array[String]:
	"""The ordinary field keys of one of the eight ordinary owners, in ordinal order.

	An if-chain rather than an indexed literal: GDScript builds an untyped `Array` from a literal
	and then refuses to return it as `Array[String]`, so the literal form fails at run time in
	exactly the places a parse check does not reach.
	"""
	if owner == OWNER_BUILDINGS:
		return BUILDINGS_FIELD_KEYS
	if owner == OWNER_FARMING:
		return FARMING_FIELD_KEYS
	if owner == OWNER_FORAGE:
		return FORAGE_FIELD_KEYS
	if owner == OWNER_RESOURCE_NODES:
		return RESOURCE_FIELD_KEYS
	if owner == OWNER_SPATIAL_WORLD:
		return SPATIAL_FIELD_KEYS
	if owner == OWNER_UNDERGROUND_SPACE:
		return SPACE_FIELD_KEYS
	if owner == OWNER_WEATHER:
		return WEATHER_FIELD_KEYS
	if owner == OWNER_WORLD_INIT:
		return WORLD_INIT_FIELD_KEYS
	return FIXED_FORMAT_FIELD_KEYS


static func field_types_of(owner: int) -> Array[int]:
	"""The ordinary field type codes of one owner, in ordinal order."""
	if owner == OWNER_BUILDINGS:
		return BUILDINGS_FIELD_TYPES
	if owner == OWNER_FARMING:
		return FARMING_FIELD_TYPES
	if owner == OWNER_FORAGE:
		return FORAGE_FIELD_TYPES
	if owner == OWNER_RESOURCE_NODES:
		return RESOURCE_FIELD_TYPES
	if owner == OWNER_SPATIAL_WORLD:
		return SPATIAL_FIELD_TYPES
	if owner == OWNER_UNDERGROUND_SPACE:
		return SPACE_FIELD_TYPES
	if owner == OWNER_WEATHER:
		return WEATHER_FIELD_TYPES
	if owner == OWNER_WORLD_INIT:
		return WORLD_INIT_FIELD_TYPES
	return FIXED_FORMAT_FIELD_NUMBERS


static func field_counts_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> Array[int]:
	"""The ordinary field element counts of one owner in `layout`, in ordinal order."""
	if owner == OWNER_BUILDINGS:
		return BUILDINGS_FIELD_COUNTS
	if owner == OWNER_FARMING:
		return FARMING_FIELD_COUNTS
	if owner == OWNER_FORAGE:
		return FORAGE_FIELD_COUNTS
	if owner == OWNER_RESOURCE_NODES:
		return RESOURCE_FIELD_COUNTS
	if owner == OWNER_SPATIAL_WORLD:
		return SPATIAL_FIELD_COUNTS
	if owner == OWNER_UNDERGROUND_SPACE:
		return space_field_counts(layout)
	if owner == OWNER_WEATHER:
		return WEATHER_FIELD_COUNTS
	if owner == OWNER_WORLD_INIT:
		return WORLD_INIT_FIELD_COUNTS
	return FIXED_FORMAT_FIELD_NUMBERS


static func space_field_counts(layout: int) -> Array[int]:
	"""The space owner's 33 element counts in `layout`, from each field's count kind."""
	var counts: Array[int] = []
	for kind: int in SPACE_FIELD_COUNT_KINDS:
		if kind == SPACE_COUNT_SCALAR:
			counts.append(1)
		elif kind == SPACE_COUNT_HEADER:
			counts.append(SpaceOwner.HEADER_FIELDS)
		elif kind == SPACE_COUNT_REGION:
			counts.append(SPACE_REGION_CAPACITIES[layout])
		else:
			counts.append(SPACE_SOURCE_CAPACITIES[layout])
	return counts


static func field_count_offset_of(owner: int, ordinal: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Payload-relative offset of one field's `element_count:u64` prefix in `layout`."""
	var types: Array[int] = field_types_of(owner)
	var counts: Array[int] = field_counts_of(owner, layout)
	var offset: int = 0
	for index: int in ordinal:
		offset += SaveCodec.U64_BYTES + counts[index] * TYPE_WIDTHS[types[index]]
	return offset


static func field_value_offset_of(owner: int, ordinal: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Payload-relative offset of one field's first value byte, immediately after its count."""
	return field_count_offset_of(owner, ordinal, layout) + SaveCodec.U64_BYTES


static func payload_bytes_of(owner: int, layout: int = LAYOUT_UNMOUNTED) -> int:
	"""Payload width DERIVED from the field table, so a table edit cannot silently keep a width."""
	var keys: Array[String] = field_keys_of(owner)
	if keys.is_empty():
		return DIRECTORY_PAYLOAD_BYTES if owner == OWNER_ENTITY_DIRECTORY else RUNTIME_PAYLOAD_BYTES
	var last: int = keys.size() - 1
	return field_value_offset_of(owner, last, layout) \
		+ field_counts_of(owner, layout)[last] * TYPE_WIDTHS[field_types_of(owner)[last]]


static func table_refusal() -> SaveHeader.Refusal:
	"""Prove BOTH compiled layouts are self-consistent before any of either is written or trusted.

	Checks the key order, then per layout the ten derived payload widths against the compiled
	ones, the total against SECTION_BYTES_BY_LAYOUT and the primary-count sum against
	DESCRIPTOR_ROW_COUNTS. A drifting table refuses here instead of producing an unreadable file.
	"""
	var previous: String = ""
	for owner: int in OWNER_COUNT:
		if Digest.ascii_compare(previous, OWNER_KEYS[owner]) >= 0:
			return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
				"'%s' does not follow '%s' in ASCII order" % [OWNER_KEYS[owner], previous])
		previous = OWNER_KEYS[owner]
	for layout: int in LAYOUT_COUNT:
		var refusal: SaveHeader.Refusal = _layout_table_refusal(layout)
		if not refusal.is_ok():
			return refusal
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _layout_table_refusal(layout: int) -> SaveHeader.Refusal:
	"""One layout's derived widths, total and primary-count sum against its compiled constants."""
	var total: int = PREFIX_BYTES + STORE_COUNT_BYTES
	var rows: int = 0
	for owner: int in OWNER_COUNT:
		if payload_bytes_of(owner, layout) != compiled_payload_bytes_of(owner, layout):
			return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
				"layout %d: '%s' derives %d payload bytes against the declared %d" % [layout,
					OWNER_KEYS[owner], payload_bytes_of(owner, layout),
					compiled_payload_bytes_of(owner, layout)])
		total += wrapper_bytes_of(owner) + compiled_payload_bytes_of(owner, layout)
		rows += primary_count_of(owner, layout)
	if total != SECTION_BYTES_BY_LAYOUT[layout]:
		return SaveHeader.Refusal.new(REFUSE_SECTION_LENGTH, "layout %d sums to %d bytes, not %d"
			% [layout, total, SECTION_BYTES_BY_LAYOUT[layout]])
	if rows != DESCRIPTOR_ROW_COUNTS[layout]:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT, "layout %d primary counts sum to %d, not %d"
			% [layout, rows, DESCRIPTOR_ROW_COUNTS[layout]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func little_endian_refusal() -> SaveHeader.Refusal:
	"""Prove `Packed*Array.to_byte_array()` is little-endian on this host before trusting it.

	The format is little-endian by contract and the native conversions are what make a 3.75 MB
	section encodable at all. On a big-endian host they would produce a plausible file no other
	build could read, so this refuses rather than assuming the platform.
	"""
	var narrow: PackedByteArray = PackedInt32Array([1]).to_byte_array()
	var wide: PackedByteArray = PackedInt64Array([1]).to_byte_array()
	if narrow.size() != 4 or narrow[0] != 1 or narrow[3] != 0:
		return SaveHeader.Refusal.new(REFUSE_ENDIANNESS,
			"a native i32 conversion produced %s" % narrow.hex_encode())
	if wide.size() != 8 or wide[0] != 1 or wide[7] != 0:
		return SaveHeader.Refusal.new(REFUSE_ENDIANNESS,
			"a native i64 conversion produced %s" % wide.hex_encode())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- staged section state -----------------------------------------------------------------------

class State:
	"""One whole section 1 as data: the provenance prefix and all ten owners' values.

	Every packed column is sized ONCE here, at its declared element count, so neither capture nor
	decode resizes one on a load path. Decoding rebinds a column to a freshly sliced buffer of the
	same declared length, which the decoder checks; it never grows one to fit what it read.
	"""
	var scenario_version: int = 0
	var effective_seed: int = 0
	var map_generator_schema: int = 0
	var authored_map_digest: PackedByteArray = PackedByteArray()
	var next_persistent_id: int = EntityDirectoryScript.PERSISTENT_ID_MIN
	var runtime: WorldRuntime.Record = null
	var building_slot: PackedInt32Array = PackedInt32Array()
	var room_slot: PackedInt32Array = PackedInt32Array()
	var furniture_slot: PackedInt32Array = PackedInt32Array()
	var farming: FarmingScript.SavedTileHistory = null
	var tile_link_head: PackedInt32Array = PackedInt32Array()
	var resource_slot: PackedInt32Array = PackedInt32Array()
	var map_revision: int = SpatialWorldScript.FIRST_MAP_REVISION
	var walkable: PackedByteArray = PackedByteArray()
	var layer: PackedByteArray = PackedByteArray()
	var cell_terrain: PackedInt32Array = PackedInt32Array()
	var height_units: PackedInt32Array = PackedInt32Array()
	var weather_row: PackedInt32Array = PackedInt32Array()
	var weather_row64: PackedInt64Array = PackedInt64Array()
	var published: int = 0
	var published_seed: int = 0
	var world_map: WorldInitScript.SavedMap = null
	## ADR 1222 step 0: the space block's layout and its 33 fields as RAW little-endian value
	## bytes, indexed by registry ordinal (ordinals 0 and 1 are the two 4-byte capacity scalars).
	var space_layout: int = LAYOUT_UNMOUNTED
	var space_values: Array[PackedByteArray] = []

	func _init() -> void:
		"""Allocate every column at its declared extent, plus the two owned sub-records."""
		authored_map_digest.resize(AUTHORED_MAP_DIGEST_BYTES)
		runtime = WorldRuntime.Record.new()
		farming = FarmingScript.SavedTileHistory.new()
		world_map = WorldInitScript.SavedMap.new()
		building_slot.resize(BUILDINGS_FIELD_COUNTS[0])
		room_slot.resize(BUILDINGS_FIELD_COUNTS[1])
		furniture_slot.resize(BUILDINGS_FIELD_COUNTS[2])
		tile_link_head.resize(FORAGE_FIELD_COUNTS[0])
		resource_slot.resize(RESOURCE_FIELD_COUNTS[0])
		walkable.resize(SPATIAL_FIELD_COUNTS[1])
		layer.resize(SPATIAL_FIELD_COUNTS[2])
		cell_terrain.resize(SPATIAL_FIELD_COUNTS[3])
		height_units.resize(SPATIAL_FIELD_COUNTS[4])
		weather_row.resize(WEATHER_FIELD_COUNTS[0])
		weather_row64.resize(WEATHER_FIELD_COUNTS[1])
		set_space_unmounted()

	func set_space_unmounted() -> void:
		"""The canonical UNMOUNTED space block: zero capacities, a zero header, empty columns."""
		space_layout = LAYOUT_UNMOUNTED
		space_values.clear()
		var counts: Array[int] = SaveSection01.space_field_counts(LAYOUT_UNMOUNTED)
		for ordinal: int in SPACE_FIELD_KEYS.size():
			var raw: PackedByteArray = PackedByteArray()
			raw.resize(counts[ordinal] * TYPE_WIDTHS[SPACE_FIELD_TYPES[ordinal]])
			space_values.append(raw)

	func space_shape_detail() -> String:
		"""The first space field whose raw width is not its layout's, or an empty string."""
		if space_layout < 0 or space_layout >= LAYOUT_COUNT:
			return "space layout %d is not compiled" % space_layout
		if space_values.size() != SPACE_FIELD_KEYS.size():
			return "the space block holds %d fields, not %d" % [space_values.size(),
				SPACE_FIELD_KEYS.size()]
		var counts: Array[int] = SaveSection01.space_field_counts(space_layout)
		for ordinal: int in SPACE_FIELD_KEYS.size():
			var width: int = counts[ordinal] * TYPE_WIDTHS[SPACE_FIELD_TYPES[ordinal]]
			if space_values[ordinal].size() != width:
				return "%s is %d bytes, not %d" % [SPACE_FIELD_KEYS[ordinal],
					space_values[ordinal].size(), width]
		return ""

	func column_shape_detail() -> String:
		"""The first column whose length is not its declared extent, or an empty string."""
		var named: Array = [["_building_slot", building_slot.size(), BUILDINGS_FIELD_COUNTS[0]],
			["_room_slot", room_slot.size(), BUILDINGS_FIELD_COUNTS[1]],
			["_furniture_slot", furniture_slot.size(), BUILDINGS_FIELD_COUNTS[2]],
			["_tile_link_head", tile_link_head.size(), FORAGE_FIELD_COUNTS[0]],
			["_resource_slot", resource_slot.size(), RESOURCE_FIELD_COUNTS[0]],
			["_walkable", walkable.size(), SPATIAL_FIELD_COUNTS[1]],
			["_layer", layer.size(), SPATIAL_FIELD_COUNTS[2]],
			["_terrain", cell_terrain.size(), SPATIAL_FIELD_COUNTS[3]],
			["_height_units", height_units.size(), SPATIAL_FIELD_COUNTS[4]],
			["_row", weather_row.size(), WEATHER_FIELD_COUNTS[0]],
			["_row64", weather_row64.size(), WEATHER_FIELD_COUNTS[1]],
			["authored_map_digest", authored_map_digest.size(), AUTHORED_MAP_DIGEST_BYTES]]
		for entry: Array in named:
			if int(entry[1]) != int(entry[2]):
				return "%s is %d elements, not %d" % [entry[0], int(entry[1]), int(entry[2])]
		if not farming.is_sized():
			return "the farming tile history is not 16384-sized"
		if not world_map.is_sized():
			return "the world_init map columns are not at their declared extents"
		return space_shape_detail()


class Stores:
	"""The live stores section 1 is captured from and restored into. All eight are required.

	Handed over as one object rather than eight parameters because every entry point here needs
	all of them, and a codec that accepted a null store would quietly skip an owner.
	"""
	var directory: EntityDirectoryScript = null
	var buildings: BuildingsScript = null
	var farming: FarmingScript = null
	var forage: ForageScript = null
	var resource_nodes: ResourceNodesScript = null
	var spatial_world: SpatialWorldScript = null
	var weather: WeatherScript = null
	var world_init: WorldInitScript = null
	## OPTIONAL (ADR 1222 step 0): the mounted underground Session's Space owner, or null for a
	## world with no underground. Not part of `missing_detail()`; null means UNMOUNTED.
	var space_owner: SpaceOwner = null

	func missing_detail() -> String:
		"""Names the first unbound store, or an empty string when all eight are present."""
		var named: Array = [["entity_directory", directory], ["buildings", buildings],
			["farming", farming], ["forage", forage], ["resource_nodes", resource_nodes],
			["spatial_world", spatial_world], ["weather", weather], ["world_init", world_init]]
		for entry: Array in named:
			if entry[1] == null:
				return "no %s store is bound" % String(entry[0])
		return ""


# --- capture ------------------------------------------------------------------------------------

static func capture_into(stores: Stores, runtime: WorldRuntime.Record, scenario_version: int,
		map_generator_schema: int, authored_map_digest: PackedByteArray,
		out: State) -> SaveHeader.Refusal:
	"""Snapshot all ten owners at a quiescent save boundary into `out`.

	The provenance prefix's VALUES are the caller's: SAVE-R09-003 gives them to the map/scenario
	producer and nothing here manufactures one. `effective_seed` is taken from the runtime record's
	world seed, which is the only seed this section can vouch for.

	R-WORLD-S1-001 §5: this is a snapshot at an established quiescent boundary. The deposit
	reclassification is NOT permission to snapshot midway through a placement or reservation.
	"""
	var bound: String = stores.missing_detail()
	if bound != "":
		return SaveHeader.Refusal.new(REFUSE_STORE_MISSING, bound)
	if authored_map_digest.size() != AUTHORED_MAP_DIGEST_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_FIELD,
			"the authored map digest is %d bytes, not %d"
				% [authored_map_digest.size(), AUTHORED_MAP_DIGEST_BYTES])
	out.scenario_version = scenario_version
	out.map_generator_schema = map_generator_schema
	out.authored_map_digest = authored_map_digest.duplicate()
	out.runtime.copy_from(runtime)
	out.effective_seed = runtime.world_seed
	out.next_persistent_id = stores.directory.next_persistent_id()
	return _capture_owners(stores, out)


static func _capture_owners(stores: Stores, out: State) -> SaveHeader.Refusal:
	"""Pull the seven ordinary owners' columns through their own validated copy entry points."""
	if not stores.buildings.copy_section_1_columns_into(out.building_slot, out.room_slot,
			out.furniture_slot):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED, stores.buildings.section_1_detail())
	if not stores.farming.copy_section_1_columns_into(out.farming):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED, stores.farming.section_1_detail())
	if not stores.forage.copy_section_1_columns_into(out.tile_link_head):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED, stores.forage.section_1_detail())
	if not stores.resource_nodes.copy_section_1_columns_into(out.resource_slot):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED,
			stores.resource_nodes.section_1_detail())
	if not stores.spatial_world.copy_section_1_columns_into(out.walkable, out.layer,
			out.cell_terrain, out.height_units):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED,
			stores.spatial_world.section_1_detail())
	out.map_revision = stores.spatial_world.section_1_map_revision()
	if not stores.weather.copy_section_1_columns_into(out.weather_row, out.weather_row64):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED, stores.weather.section_1_detail())
	if not stores.world_init.copy_section_1_columns_into(out.world_map):
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED, stores.world_init.section_1_detail())
	out.published = 1 if stores.world_init.section_1_is_published() else 0
	out.published_seed = stores.world_init.section_1_published_seed()
	return capture_space(stores.space_owner, out)


static func capture_space(owner: SpaceOwner, out: State) -> SaveHeader.Refusal:
	"""The space block: UNMOUNTED for a null owner, else the owner's live bank as MOUNTED.

	Reads the owner only through `state_bytes()`, which returns nothing unless the owner is at a
	completed boundary; that empty answer refuses here. The wire's columns are re-indexed into
	registry ordinals through SPACE_WIRE_ORDER, so the section writes them in declared order.
	"""
	if owner == null:
		out.set_space_unmounted()
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	var wire: PackedByteArray = owner.state_bytes()
	if wire.size() != Budget.SPACE_WIRE_BYTES:
		return SaveHeader.Refusal.new(REFUSE_CAPTURE_FAILED,
			"the space owner gave %d wire bytes, not the pack's %d (not at a completed boundary?)"
				% [wire.size(), Budget.SPACE_WIRE_BYTES])
	var values: Array[PackedByteArray] = _space_values_from_wire(wire, LAYOUT_MOUNTED)
	out.space_layout = LAYOUT_MOUNTED
	out.space_values = values
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _space_values_from_wire(wire: PackedByteArray, layout: int) -> Array[PackedByteArray]:
	"""Slice the owner's column-major wire into raw values by registry ordinal, scalars from layout."""
	var values: Array[PackedByteArray] = []
	values.resize(SPACE_FIELD_KEYS.size())
	values[0] = PackedInt32Array([SPACE_REGION_CAPACITIES[layout]]).to_byte_array()
	values[1] = PackedInt32Array([SPACE_SOURCE_CAPACITIES[layout]]).to_byte_array()
	var counts: Array[int] = space_field_counts(layout)
	var at: int = 0
	for ordinal: int in SPACE_WIRE_ORDER:
		var width: int = counts[ordinal] * TYPE_WIDTHS[SPACE_FIELD_TYPES[ordinal]]
		values[ordinal] = wire.slice(at, at + width)
		at += width
	return values


static func space_wire_of(state: State) -> PackedByteArray:
	"""The owner's exact `state_bytes()` image rebuilt from a MOUNTED state's raw values."""
	var wire: PackedByteArray = PackedByteArray()
	for ordinal: int in SPACE_WIRE_ORDER:
		wire.append_array(state.space_values[ordinal])
	return wire


# --- encode -------------------------------------------------------------------------------------

static func encode_section(state: State, out: WorldRuntime.EncodeResult) -> bool:
	"""Encode the whole section in its layout: prefix, `store_count = 10`, then ten blocks.

	Every structural invariant is proved BEFORE a byte is emitted: the compiled table is
	self-consistent, the host is little-endian, the staged columns are at their declared extents,
	and the prefix fields are in range. A refusal produces no bytes at all.
	"""
	var table: SaveHeader.Refusal = table_refusal()
	if not table.is_ok():
		return out.refuse(table.code, table.detail)
	var endian: SaveHeader.Refusal = little_endian_refusal()
	if not endian.is_ok():
		return out.refuse(endian.code, endian.detail)
	var shape: String = state.column_shape_detail()
	if shape != "":
		return out.refuse(REFUSE_COLUMN_SHAPE, shape)
	var prefix: SaveHeader.Refusal = prefix_refusal(state)
	if not prefix.is_ok():
		return out.refuse(prefix.code, prefix.detail)
	var space: SaveHeader.Refusal = space_refusal(state)
	if not space.is_ok():
		return out.refuse(space.code, space.detail)
	return _encode_blocks(state, out)


static func _encode_blocks(state: State, out: WorldRuntime.EncodeResult) -> bool:
	"""The prefix then all ten blocks in `state.space_layout`, length-checked against the table."""
	var layout: int = state.space_layout
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append_array(_prefix_bytes(state))
	for owner: int in OWNER_COUNT:
		var payload: PackedByteArray = _payload_bytes(state, owner, out)
		if payload.size() != compiled_payload_bytes_of(owner, layout):
			return out.refuse(REFUSE_PAYLOAD_LENGTH, "'%s' encoded %d payload bytes, not %d"
				% [OWNER_KEYS[owner], payload.size(), compiled_payload_bytes_of(owner, layout)])
		bytes.append_array(_wrapper_bytes(owner, layout))
		bytes.append_array(payload)
	if bytes.size() != section_bytes_of(layout):
		return out.refuse(REFUSE_SECTION_LENGTH,
			"section 1 encoded %d bytes, not %d" % [bytes.size(), section_bytes_of(layout)])
	return out.succeed(bytes)


static func prefix_refusal(state: State) -> SaveHeader.Refusal:
	"""The four provenance fields and the D2 cursor. No value here is invented or defaulted."""
	if state.authored_map_digest.size() != AUTHORED_MAP_DIGEST_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_FIELD, "the authored map digest is %d bytes"
			% state.authored_map_digest.size())
	if state.scenario_version < 0 or state.scenario_version > SaveCodec.UINT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_FIELD,
			"scenario version %d is not a u32" % state.scenario_version)
	if state.map_generator_schema < 0 or state.map_generator_schema > SaveCodec.UINT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_FIELD,
			"map generator schema %d is not a u32" % state.map_generator_schema)
	if state.effective_seed < SaveCodec.INT32_MIN or state.effective_seed > SaveCodec.INT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_FIELD,
			"effective seed %d is not an i32" % state.effective_seed)
	return WorldRuntime.cursor_refusal(state.next_persistent_id)


static func _prefix_bytes(state: State) -> PackedByteArray:
	"""The 44-byte map-provenance prefix followed by `store_count = 10`, as 48 bytes."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(FIRST_BLOCK_OFFSET)
	writer.write_u32(state.scenario_version)
	writer.write_i32(state.effective_seed)
	writer.write_u32(state.map_generator_schema)
	writer.write_bytes(state.authored_map_digest)
	writer.write_u32(OWNER_COUNT)
	return writer.to_bytes()


static func _wrapper_bytes(owner: int, layout: int) -> PackedByteArray:
	"""One block's `key_length, key, schema, primary_count, payload_length` wrapper in `layout`."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(wrapper_bytes_of(owner))
	writer.write_utf8_u32(OWNER_KEYS[owner], OWNER_KEY_MAX_BYTES)
	writer.write_u32(OWNER_SCHEMA_VERSIONS[owner])
	writer.write_u64(primary_count_of(owner, layout))
	writer.write_u64(compiled_payload_bytes_of(owner, layout))
	return writer.to_bytes()


static func _payload_bytes(state: State, owner: int,
		out: WorldRuntime.EncodeResult) -> PackedByteArray:
	"""One block's payload: the two fixed formats, or the ordinary count-prefixed form."""
	if owner == OWNER_ENTITY_DIRECTORY:
		var cursor: SaveCodec.Writer = SaveCodec.Writer.new(DIRECTORY_PAYLOAD_BYTES)
		cursor.write_u32(state.next_persistent_id)
		return cursor.to_bytes()
	if owner == OWNER_WORLD_RUNTIME:
		var body: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
		if not WorldRuntime.encode_block(state.runtime, body):
			out.refuse(body.refusal, body.detail)
			return PackedByteArray()
		return body.bytes
	return _ordinary_payload_bytes(state, owner)


static func _ordinary_payload_bytes(state: State, owner: int) -> PackedByteArray:
	"""`element_count:u64` then the column's native little-endian bytes, per field, in order."""
	var payload: PackedByteArray = PackedByteArray()
	var counts: Array[int] = field_counts_of(owner, state.space_layout)
	for ordinal: int in counts.size():
		payload.append_array(_count_prefix_bytes(counts[ordinal]))
		payload.append_array(_field_value_bytes(state, owner, ordinal))
	return payload


static func _count_prefix_bytes(count: int) -> PackedByteArray:
	"""One field's eight-byte element-count prefix. A structural byte group, never a record."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(SaveCodec.U64_BYTES)
	writer.write_u64(count)
	return writer.to_bytes()


static func _field_value_bytes(state: State, owner: int, ordinal: int) -> PackedByteArray:
	"""One field's values as native little-endian bytes, dispatched by (owner, ordinal).

	`little_endian_refusal()` has already proved these conversions are little-endian, and
	`encode_section()` has already proved every column is at its declared extent, so the widths
	this returns are exactly `element_count * type_width`.
	"""
	if owner == OWNER_BUILDINGS:
		return [state.building_slot, state.room_slot,
			state.furniture_slot][ordinal].to_byte_array()
	if owner == OWNER_FARMING:
		return _farming_field_bytes(state, ordinal)
	if owner == OWNER_FORAGE:
		return state.tile_link_head.to_byte_array()
	if owner == OWNER_RESOURCE_NODES:
		return state.resource_slot.to_byte_array()
	if owner == OWNER_SPATIAL_WORLD:
		return _spatial_field_bytes(state, ordinal)
	if owner == OWNER_UNDERGROUND_SPACE:
		return state.space_values[ordinal]
	if owner == OWNER_WEATHER:
		return state.weather_row.to_byte_array() if ordinal == 0 \
			else state.weather_row64.to_byte_array()
	return _world_init_field_bytes(state, ordinal)


static func _farming_field_bytes(state: State, ordinal: int) -> PackedByteArray:
	"""TileHistory's ten columns in ordinal order: seven i32, two i64, then the u8 flag."""
	var history: FarmingScript.SavedTileHistory = state.farming
	if ordinal < 7:
		return [history.fertility, history.last_family, history.family_streak,
			history.last_legume_day, history.compost_season, history.active_plot_row,
			history.orchard_row][ordinal].to_byte_array()
	if ordinal == 7:
		return history.ripe_tick.to_byte_array()
	if ordinal == 8:
		return history.growth_remainder.to_byte_array()
	return history.tended_today


static func _spatial_field_bytes(state: State, ordinal: int) -> PackedByteArray:
	"""The revision scalar as a one-element i32 field, then the four cell columns."""
	if ordinal == 0:
		return PackedInt32Array([state.map_revision]).to_byte_array()
	if ordinal == 1:
		return state.walkable
	if ordinal == 2:
		return state.layer
	if ordinal == 3:
		return state.cell_terrain.to_byte_array()
	return state.height_units.to_byte_array()


static func _world_init_field_bytes(state: State, ordinal: int) -> PackedByteArray:
	"""Two scalars, four u8 tile grids, then the three seven-entry basin columns."""
	if ordinal == 0:
		return PackedByteArray([state.published])
	if ordinal == 1:
		return PackedInt32Array([state.published_seed]).to_byte_array()
	var world_map: WorldInitScript.SavedMap = state.world_map
	if ordinal < 6:
		return [world_map.terrain, world_map.soil, world_map.basin,
			world_map.cleared][ordinal - 2]
	return [world_map.basin_ref_slot, world_map.basin_ref_generation,
		world_map.basin_danger][ordinal - 6].to_byte_array()


# --- decode -------------------------------------------------------------------------------------

static func decode_section(bytes: PackedByteArray, offset: int, section_byte_length: int,
		out: State) -> SaveHeader.Refusal:
	"""Decode a whole section 1 at `offset` into `out`, reading every item at a COMPILED offset.

	Allocate before consume (decision 0059): everything lands in a local State and the caller's is
	overwritten only after all ten blocks, every element count and every prefix field validate.
	A malformed section leaves `out` byte-identical, so a refused load cannot half-publish.

	`section_byte_length` must be EXACTLY one compiled layout's length, and the space block's
	capacity scalars must name that same layout. Any other length is refused rather than measured:
	accepting it would be reinterpreting bytes written under another schema.
	"""
	var extent: SaveHeader.Refusal = section_extent_refusal(bytes, offset, section_byte_length)
	if not extent.is_ok():
		return extent
	var staged: State = State.new()
	staged.space_layout = layout_of(bytes, offset, section_byte_length)
	if staged.space_layout < 0:
		return SaveHeader.Refusal.new(REFUSE_SPACE_LAYOUT,
			"the space capacities name no compiled layout, or not this section's length")
	var blocks: SaveHeader.Refusal = _read_blocks(bytes, offset, staged)
	if not blocks.is_ok():
		return blocks
	var invalid: SaveHeader.Refusal = prefix_refusal(staged)
	if invalid.is_ok():
		invalid = space_refusal(staged)
	if not invalid.is_ok():
		return invalid
	_adopt(staged, out)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_blocks(bytes: PackedByteArray, offset: int, staged: State) -> SaveHeader.Refusal:
	"""The prefix then all ten blocks at the staged layout's compiled offsets, tiling exactly."""
	var layout: int = staged.space_layout
	var prefix: SaveHeader.Refusal = _read_prefix(bytes, offset, staged)
	if not prefix.is_ok():
		return prefix
	for owner: int in OWNER_COUNT:
		var block: SaveHeader.Refusal = _read_block(bytes, offset, owner, staged)
		if not block.is_ok():
			return block
	var last: int = block_offset_of(OWNER_COUNT - 1, layout) + wrapper_bytes_of(OWNER_COUNT - 1) \
		+ compiled_payload_bytes_of(OWNER_COUNT - 1, layout)
	if last != section_bytes_of(layout):
		return SaveHeader.Refusal.new(REFUSE_NOT_TILED,
			"ten blocks end at %d, not the section end %d" % [last, section_bytes_of(layout)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func layout_of(bytes: PackedByteArray, offset: int, section_byte_length: int) -> int:
	"""The compiled layout named by the space block's two capacity scalars, or -1.

	Both scalars sit at the SAME compiled offsets in either layout, because no block before the
	space block changes. The pair must equal one layout's capacities exactly AND the section's
	declared length must be that layout's; the caller has already proved the bytes are readable.
	"""
	var base: int = offset + payload_offset_of(OWNER_UNDERGROUND_SPACE)
	var region: int = bytes.decode_s32(base + field_value_offset_of(OWNER_UNDERGROUND_SPACE, 0))
	var source: int = bytes.decode_s32(base + field_value_offset_of(OWNER_UNDERGROUND_SPACE, 1))
	for layout: int in LAYOUT_COUNT:
		if region == SPACE_REGION_CAPACITIES[layout] and source == SPACE_SOURCE_CAPACITIES[layout]:
			return layout if section_byte_length == section_bytes_of(layout) else -1
	return -1


static func section_extent_refusal(bytes: PackedByteArray, offset: int,
		section_byte_length: int) -> SaveHeader.Refusal:
	"""Prove the compiled table, the host endianness and that one layout's exact length is readable.

	The buffer bound is written as a SUBTRACTION so `offset + section_byte_length` is never formed
	and cannot overflow into a bound that accidentally passes.
	"""
	var table: SaveHeader.Refusal = table_refusal()
	if not table.is_ok():
		return table
	var endian: SaveHeader.Refusal = little_endian_refusal()
	if not endian.is_ok():
		return endian
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if not SECTION_BYTES_BY_LAYOUT.has(section_byte_length):
		return SaveHeader.Refusal.new(REFUSE_SECTION_LENGTH,
			"section 1 declares %d bytes, not a compiled layout's %s"
				% [section_byte_length, str(SECTION_BYTES_BY_LAYOUT)])
	if bytes.size() < section_byte_length or offset > bytes.size() - section_byte_length:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 1 needs %d bytes at offset %d, buffer holds %d"
				% [section_byte_length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_prefix(bytes: PackedByteArray, offset: int, staged: State) -> SaveHeader.Refusal:
	"""The 44-byte provenance prefix and `store_count`, each at its own absolute offset."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.read_u32_at(bytes, offset + OFFSET_SCENARIO_VERSION, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	staged.scenario_version = scalar.value
	if not SaveCodec.read_i32_at(bytes, offset + OFFSET_EFFECTIVE_SEED, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	staged.effective_seed = scalar.value
	if not SaveCodec.read_u32_at(bytes, offset + OFFSET_MAP_GENERATOR_SCHEMA, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	staged.map_generator_schema = scalar.value
	staged.authored_map_digest = bytes.slice(offset + OFFSET_AUTHORED_MAP_DIGEST,
		offset + OFFSET_AUTHORED_MAP_DIGEST + AUTHORED_MAP_DIGEST_BYTES)
	if not SaveCodec.read_u32_at(bytes, offset + OFFSET_STORE_COUNT, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != OWNER_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"store_count is %d, not the required %d" % [scalar.value, OWNER_COUNT])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_block(bytes: PackedByteArray, offset: int, owner: int,
		staged: State) -> SaveHeader.Refusal:
	"""One block's wrapper at its COMPILED offset, then its payload. Nothing here advances a cursor.

	The key, schema, primary count and payload length are all COMPARED against the compiled table.
	A swapped owner pair is caught because the key sitting at this block's fixed offset is the
	wrong key -- which is exactly the failure a cursor-walking decoder shares with its encoder and
	therefore cannot see.
	"""
	var layout: int = staged.space_layout
	var base: int = offset + block_offset_of(owner, layout)
	var key: PackedByteArray = OWNER_KEYS[owner].to_utf8_buffer()
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.read_u32_at(bytes, base, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != key.size():
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"block %d declares a %d-byte key, not %d" % [owner, scalar.value, key.size()])
	if bytes.slice(base + SaveCodec.U32_BYTES, base + SaveCodec.U32_BYTES + key.size()) != key:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"block %d does not carry '%s' at offset %d" % [owner, OWNER_KEYS[owner], base])
	var head: SaveHeader.Refusal = _read_wrapper_numbers(bytes, base + SaveCodec.U32_BYTES
		+ key.size(), owner, layout)
	if not head.is_ok():
		return head
	return _read_payload(bytes, offset + payload_offset_of(owner, layout), owner, staged)


static func _read_wrapper_numbers(bytes: PackedByteArray, at: int,
		owner: int, layout: int) -> SaveHeader.Refusal:
	"""Schema version, primary count and payload length, each against its compiled constant."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.read_u32_at(bytes, at, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != OWNER_SCHEMA_VERSIONS[owner]:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA, "'%s' declares schema %d, not %d"
			% [OWNER_KEYS[owner], scalar.value, OWNER_SCHEMA_VERSIONS[owner]])
	if not SaveCodec.read_u64_at(bytes, at + SaveCodec.U32_BYTES, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != primary_count_of(owner, layout):
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"'%s' declares primary_count %d, not %d"
				% [OWNER_KEYS[owner], scalar.value, primary_count_of(owner, layout)])
	if not SaveCodec.read_u64_at(bytes, at + SaveCodec.U32_BYTES + SaveCodec.U64_BYTES, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != compiled_payload_bytes_of(owner, layout):
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"'%s' declares %d payload bytes, not %d"
				% [OWNER_KEYS[owner], scalar.value, compiled_payload_bytes_of(owner, layout)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_payload(bytes: PackedByteArray, at: int, owner: int,
		staged: State) -> SaveHeader.Refusal:
	"""The two fixed formats, or every ordinary field at its compiled count and value offsets."""
	if owner == OWNER_ENTITY_DIRECTORY:
		var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
		if not SaveCodec.read_u32_at(bytes, at, scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
		staged.next_persistent_id = scalar.value
		return WorldRuntime.cursor_refusal(scalar.value)
	if owner == OWNER_WORLD_RUNTIME:
		return WorldRuntime.decode_into(bytes, at, staged.runtime)
	var layout: int = staged.space_layout
	var counts: Array[int] = field_counts_of(owner, layout)
	for ordinal: int in counts.size():
		var checked: SaveHeader.Refusal = _read_element_count(bytes, at, owner, ordinal, layout)
		if not checked.is_ok():
			return checked
		_read_field_values(bytes, at + field_value_offset_of(owner, ordinal, layout), owner,
			ordinal, staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_element_count(bytes: PackedByteArray, at: int, owner: int,
		ordinal: int, layout: int) -> SaveHeader.Refusal:
	"""One field's `element_count:u64`, which must EQUAL the compiled count. Never an allocation."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var expected: int = field_counts_of(owner, layout)[ordinal]
	if not SaveCodec.read_u64_at(bytes, at + field_count_offset_of(owner, ordinal, layout), scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value != expected:
		return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
			"'%s.%s' declares %d elements, not %d" % [OWNER_KEYS[owner],
				field_keys_of(owner)[ordinal], scalar.value, expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_field_values(bytes: PackedByteArray, at: int, owner: int, ordinal: int,
		staged: State) -> void:
	"""Slice one field's values from its COMPILED value offset and bind them to the staged column.

	The slice width is `element_count * type_width` from the compiled table, and the count sitting
	in the file has already been proved equal to that count, so no length here comes from the file.
	"""
	var width: int = field_counts_of(owner, staged.space_layout)[ordinal] \
		* TYPE_WIDTHS[field_types_of(owner)[ordinal]]
	var raw: PackedByteArray = bytes.slice(at, at + width)
	if owner == OWNER_UNDERGROUND_SPACE:
		staged.space_values[ordinal] = raw
	elif owner == OWNER_BUILDINGS:
		_bind_buildings(staged, ordinal, raw.to_int32_array())
	elif owner == OWNER_FARMING:
		_bind_farming(staged, ordinal, raw)
	elif owner == OWNER_FORAGE:
		staged.tile_link_head = raw.to_int32_array()
	elif owner == OWNER_RESOURCE_NODES:
		staged.resource_slot = raw.to_int32_array()
	elif owner == OWNER_SPATIAL_WORLD:
		_bind_spatial(staged, ordinal, raw)
	elif owner == OWNER_WEATHER:
		_bind_weather(staged, ordinal, raw)
	else:
		_bind_world_init(staged, ordinal, raw)


static func _bind_buildings(staged: State, ordinal: int, values: PackedInt32Array) -> void:
	"""Bind one of the three decoded tile maps to its staged column."""
	if ordinal == 0:
		staged.building_slot = values
	elif ordinal == 1:
		staged.room_slot = values
	else:
		staged.furniture_slot = values


static func _bind_farming(staged: State, ordinal: int, raw: PackedByteArray) -> void:
	"""Bind one decoded TileHistory column: seven i32, two i64, then the u8 tending flag."""
	var history: FarmingScript.SavedTileHistory = staged.farming
	if ordinal < 7:
		var narrow: PackedInt32Array = raw.to_int32_array()
		if ordinal == 0:
			history.fertility = narrow
		elif ordinal == 1:
			history.last_family = narrow
		elif ordinal == 2:
			history.family_streak = narrow
		elif ordinal == 3:
			history.last_legume_day = narrow
		elif ordinal == 4:
			history.compost_season = narrow
		elif ordinal == 5:
			history.active_plot_row = narrow
		else:
			history.orchard_row = narrow
	elif ordinal == 7:
		history.ripe_tick = raw.to_int64_array()
	elif ordinal == 8:
		history.growth_remainder = raw.to_int64_array()
	else:
		history.tended_today = raw


static func _bind_spatial(staged: State, ordinal: int, raw: PackedByteArray) -> void:
	"""Bind the revision scalar and the four decoded cell columns."""
	if ordinal == 0:
		staged.map_revision = raw.to_int32_array()[0]
	elif ordinal == 1:
		staged.walkable = raw
	elif ordinal == 2:
		staged.layer = raw
	elif ordinal == 3:
		staged.cell_terrain = raw.to_int32_array()
	else:
		staged.height_units = raw.to_int32_array()


static func _bind_weather(staged: State, ordinal: int, raw: PackedByteArray) -> void:
	"""Bind the eight-value i32 row and the two-value i64 identity row."""
	if ordinal == 0:
		staged.weather_row = raw.to_int32_array()
	else:
		staged.weather_row64 = raw.to_int64_array()


static func _bind_world_init(staged: State, ordinal: int, raw: PackedByteArray) -> void:
	"""Bind the two scalars, the four u8 tile grids and the three seven-entry basin columns."""
	var world_map: WorldInitScript.SavedMap = staged.world_map
	if ordinal == 0:
		staged.published = raw[0]
	elif ordinal == 1:
		staged.published_seed = raw.to_int32_array()[0]
	elif ordinal == 2:
		world_map.terrain = raw
	elif ordinal == 3:
		world_map.soil = raw
	elif ordinal == 4:
		world_map.basin = raw
	elif ordinal == 5:
		world_map.cleared = raw
	elif ordinal == 6:
		world_map.basin_ref_slot = raw.to_int32_array()
	elif ordinal == 7:
		world_map.basin_ref_generation = raw.to_int32_array()
	else:
		world_map.basin_danger = raw.to_int32_array()


static func _adopt(staged: State, out: State) -> void:
	"""Move a fully validated staged section into the caller's State, column reference by reference.

	Packed arrays are copy-on-write, so this costs references rather than another 3.75 MB. The
	staged object is discarded immediately afterwards and never written again, so nothing can
	mutate a column `out` now holds.
	"""
	out.scenario_version = staged.scenario_version
	out.effective_seed = staged.effective_seed
	out.map_generator_schema = staged.map_generator_schema
	out.authored_map_digest = staged.authored_map_digest
	out.next_persistent_id = staged.next_persistent_id
	out.runtime.copy_from(staged.runtime)
	out.building_slot = staged.building_slot
	out.room_slot = staged.room_slot
	out.furniture_slot = staged.furniture_slot
	out.farming = staged.farming
	out.tile_link_head = staged.tile_link_head
	out.resource_slot = staged.resource_slot
	out.map_revision = staged.map_revision
	out.walkable = staged.walkable
	out.layer = staged.layer
	out.cell_terrain = staged.cell_terrain
	out.height_units = staged.height_units
	out.weather_row = staged.weather_row
	out.weather_row64 = staged.weather_row64
	out.published = staged.published
	out.published_seed = staged.published_seed
	out.world_map = staged.world_map
	_adopt_space(staged, out)


static func _adopt_space(staged: State, out: State) -> void:
	"""Move the validated space block's layout and raw values into `out`, by reference."""
	out.space_layout = staged.space_layout
	out.space_values = staged.space_values


# --- semantic validation -------------------------------------------------------------------------

static func validate_section(state: State, stores: Stores) -> SaveHeader.Refusal:
	"""Run every owner validator over a decoded section, before anything is published.

	Count, order, length and CRC agreement are NOT a substitute for these: a file can tile
	perfectly and still carry a family with no streak, a half-null basin reference or an event
	that its own season cannot hold. Every owner judges its own domain through the same predicate
	its live store enforces, so the codec holds no second copy of any rule.
	"""
	var bound: String = stores.missing_detail()
	if bound != "":
		return SaveHeader.Refusal.new(REFUSE_STORE_MISSING, bound)
	var shape: String = state.column_shape_detail()
	if shape != "":
		return SaveHeader.Refusal.new(REFUSE_COLUMN_SHAPE, shape)
	var prefix: SaveHeader.Refusal = prefix_refusal(state)
	if not prefix.is_ok():
		return prefix
	var runtime: SaveHeader.Refusal = WorldRuntime.record_refusal(state.runtime)
	if not runtime.is_ok():
		return runtime
	var owners: SaveHeader.Refusal = _owner_domain_refusal(state, stores)
	if not owners.is_ok():
		return owners
	var space: SaveHeader.Refusal = space_refusal(state)
	if not space.is_ok():
		return space
	return seed_agreement_refusal(state)


static func space_refusal(state: State) -> SaveHeader.Refusal:
	"""The space block's own rules, before any owner sees it (ADR 1222 step 0).

	UNMOUNTED must be the canonical empty form: zero capacities and an all-zero header (its
	columns are empty by shape). MOUNTED must carry the pack capacities in both scalars and in the
	header, the owner's schema and a configured revision of at least 1. Everything else about the
	bank is the owner's to judge, in `restore_state_bytes()`, when the Session is re-mounted.
	"""
	var shape: String = state.space_shape_detail()
	if shape != "":
		return SaveHeader.Refusal.new(REFUSE_COLUMN_SHAPE, shape)
	var layout: int = state.space_layout
	var scalars: Array[int] = [state.space_values[0].decode_s32(0), state.space_values[1].decode_s32(0)]
	if scalars != [SPACE_REGION_CAPACITIES[layout], SPACE_SOURCE_CAPACITIES[layout]]:
		return SaveHeader.Refusal.new(REFUSE_SPACE_LAYOUT,
			"capacities %s do not name layout %d" % [str(scalars), layout])
	var header: PackedInt64Array = state.space_values[2].to_int64_array()
	if layout == LAYOUT_UNMOUNTED:
		return _space_header_refusal(header == PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0]), "an unmounted space header must be all zero")
	var expected: Array[int] = [SpaceOwner.SCHEMA, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY]
	var agrees: bool = [header[SPACE_HEADER_SCHEMA], header[SPACE_HEADER_REGION_CAPACITY],
		header[SPACE_HEADER_SOURCE_CAPACITY]] == expected
	return _space_header_refusal(agrees and header[SPACE_HEADER_REVISION] >= 1,
		"a mounted space header must carry schema %d, the pack capacities and a revision >= 1"
			% SpaceOwner.SCHEMA)


static func _space_header_refusal(valid: bool, detail: String) -> SaveHeader.Refusal:
	"""REFUSE_SPACE_HEADER with `detail` unless `valid`."""
	if valid:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	return SaveHeader.Refusal.new(REFUSE_SPACE_HEADER, detail)


static func _owner_domain_refusal(state: State, stores: Stores) -> SaveHeader.Refusal:
	"""Each of the seven ordinary owners' local domains, in ASCII owner order."""
	var code: StringName = stores.buildings.section_1_local_refusal(state.building_slot,
		state.room_slot, state.furniture_slot)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.buildings.section_1_detail())
	code = stores.farming.section_1_local_refusal(state.farming)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.farming.section_1_detail())
	code = stores.forage.section_1_local_refusal(state.tile_link_head)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.forage.section_1_detail())
	code = stores.resource_nodes.section_1_local_refusal(state.resource_slot)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.resource_nodes.section_1_detail())
	code = stores.spatial_world.section_1_local_refusal(state.map_revision, state.walkable,
		state.layer, state.cell_terrain, state.height_units)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.spatial_world.section_1_detail())
	code = stores.weather.section_1_local_refusal(state.weather_row, state.weather_row64)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.weather.section_1_detail())
	code = stores.world_init.section_1_local_refusal(state.published, state.published_seed,
		state.world_map)
	if code != REFUSE_NONE:
		return SaveHeader.Refusal.new(code, stores.world_init.section_1_detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func seed_agreement_refusal(state: State) -> SaveHeader.Refusal:
	"""R-WORLD-S1-001 §6: a PUBLISHED map's seed must agree with provenance and with the runtime.

	This is the one cross-owner rule that belongs here rather than in an owner: `world_init.gd`
	cannot see the section's provenance prefix and `save_section_world_runtime.gd` cannot see the
	published map. The seed keeps its signed-i32 domain; no positivity rule is invented.
	An UNPUBLISHED map asserts nothing about the seed beyond its own zero, which its own validator
	already enforces.
	"""
	if state.published != 1:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	if state.published_seed != state.effective_seed:
		return SaveHeader.Refusal.new(REFUSE_SEED_DISAGREES,
			"the published seed %d is not the provenance effective seed %d"
				% [state.published_seed, state.effective_seed])
	if state.published_seed != state.runtime.world_seed:
		return SaveHeader.Refusal.new(REFUSE_SEED_DISAGREES,
			"the published seed %d is not the runtime world seed %d"
				% [state.published_seed, state.runtime.world_seed])
	if not state.runtime.rng_seeded:
		return SaveHeader.Refusal.new(REFUSE_UNSEEDED_PUBLISHED,
			"a published world declares an unseeded runtime")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- restore and publication ----------------------------------------------------------------------

static func restore_section(state: State, stores: Stores) -> SaveHeader.Refusal:
	"""Publish a validated section into the seven ordinary owners, under the caller's load barrier.

	EVERYTHING IS VALIDATED FIRST. `validate_section()` runs to completion before a single column
	is written, so a refusal leaves the prior live world intact -- which is the whole point of the
	unpublished load barrier the caller holds.

	NOTHING IS PUBLISHED THROUGH A GAMEPLAY MUTATOR. No building is placed, no zone created, no
	weather drawn, no map generated and no allocator touched. Each owner installs its stored
	columns and rebuilds only its declared derived data.

	TWO OWNERS ARE DELIBERATELY NOT PUBLISHED HERE. The `entity_directory` cursor is installed
	with section 3 by `save_identity_restore.gd` under the same barrier. `world_runtime` joins
	section 10's RNG streams through `save_world_runtime_install.gd` (SAVE-W1-R02), using the
	existing exact clock/manager restore APIs. Neither path uses ordinary pause setters.
	Both values remain on State for the full coordinator to compose; this operation restores
	only the seven ordinary owners and does not claim whole-world transactional publication.
	"""
	var invalid: SaveHeader.Refusal = validate_section(state, stores)
	if not invalid.is_ok():
		return invalid
	return _publish_owners(state, stores)


static func _publish_owners(state: State, stores: Stores) -> SaveHeader.Refusal:
	"""Install the seven ordinary owners' validated columns, in ASCII owner order."""
	if not stores.buildings.restore_section_1_columns(state.building_slot, state.room_slot,
			state.furniture_slot):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, stores.buildings.section_1_detail())
	if not stores.farming.restore_section_1_columns(state.farming):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, stores.farming.section_1_detail())
	if not stores.forage.restore_section_1_columns(state.tile_link_head):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, stores.forage.section_1_detail())
	if not stores.resource_nodes.restore_section_1_columns(state.resource_slot):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED,
			stores.resource_nodes.section_1_detail())
	if not stores.spatial_world.restore_section_1_columns(state.map_revision, state.walkable,
			state.layer, state.cell_terrain, state.height_units):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED,
			stores.spatial_world.section_1_detail())
	if not stores.weather.restore_section_1_columns(state.weather_row, state.weather_row64):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, stores.weather.section_1_detail())
	if not stores.world_init.restore_section_1_columns(state.published, state.published_seed,
			state.world_map):
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, stores.world_init.section_1_detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func restore_space_owner(state: State, owner: SpaceOwner) -> SaveHeader.Refusal:
	"""Publish the validated space block into the re-mounted Session's Space owner.

	NOT part of `restore_section()`: the Space owner exists only after the orchestrator has
	re-mounted the underground Session through its composers, and ADR 1221 restores it FIRST in
	the underground group. UNMOUNTED requires that no owner is mounted; MOUNTED requires one and
	hands it the exact `state_bytes()` image, which the owner validates in its staging bank and
	refuses without touching its live bank.
	"""
	var space: SaveHeader.Refusal = space_refusal(state)
	if not space.is_ok():
		return space
	if state.space_layout == LAYOUT_UNMOUNTED:
		if owner == null:
			return SaveHeader.Refusal.new(REFUSE_NONE, "")
		return SaveHeader.Refusal.new(REFUSE_SPACE_MOUNT, "an unmounted save cannot fill a mounted Space")
	if owner == null:
		return SaveHeader.Refusal.new(REFUSE_SPACE_MOUNT, "a mounted save needs a re-mounted Space owner")
	var code: StringName = owner.restore_state_bytes(space_wire_of(state))
	if code != &"":
		return SaveHeader.Refusal.new(REFUSE_RESTORE_FAILED, "underground_space_owner: %s" % code)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func cross_check_refusal(stores: Stores) -> SaveHeader.Refusal:
	"""Every cross-owner inverse, run against the LIVE stores after the component sections land.

	Separate from `restore_section()` on purpose. These rules compare section 1's tile maps with
	section 4's component rows and the directory's generations, none of which exist yet while
	section 1 is being staged. A loader runs this once, still under the barrier, after every
	section it depends on has been published.

	`farming.gd`'s orchard inverse is NOT asserted here and that is deliberate: R-WORLD-S1-001 §6
	names the missing live-orchard maintenance as an open integration prerequisite, and asserting a
	reverse map no writer maintains would either rubber-stamp an all-null column or reconstruct
	over a contradictory one.
	"""
	var bound: String = stores.missing_detail()
	if bound != "":
		return SaveHeader.Refusal.new(REFUSE_STORE_MISSING, bound)
	var named: Array = [["buildings", stores.buildings], ["farming", stores.farming],
		["forage", stores.forage], ["resource_nodes", stores.resource_nodes],
		["spatial_world", stores.spatial_world], ["world_init", stores.world_init]]
	for entry: Array in named:
		var store: Object = entry[1]
		var code: StringName = store.call(&"section_1_cross_check_refusal")
		if code != REFUSE_NONE:
			return SaveHeader.Refusal.new(code, "%s: %s"
				% [String(entry[0]), store.call(&"section_1_detail")])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- canonical value adapters (ARCH-HASH-001) -----------------------------------------------------
#
# `canonical_state_hash.gd` walks the compiled declaration and asks each owner for one field at a
# time through `canonical_field_values(field_key, out)`. The ten adapters below are section 1's
# side of that contract. They read the SAME staged columns the encoder writes, at the SAME declared
# extents, so a save and a hash cannot disagree about what section 1 contains.
#
# THE THREE DEPOSIT ARRAYS HAVE NO ADAPTER, because they have no declaration. Asking a
# `resource_nodes` adapter for `_deposit_tiles` refuses by name rather than returning a plausible
# column, which is what makes the reclassification observable from the hash side as well as the
# wire side.

class Adapter:
	"""One section-1 owner's canonical value adapter over a staged State.

	Holds a reference to the State rather than a copy of its columns: packed arrays are
	copy-on-write, so re-hashing the same section costs nothing and cannot observe a later edit
	to a column the State has since rebound.
	"""
	var _state: State = null
	var _owner: int = 0

	func _init(p_state: State, p_owner: int) -> void:
		"""Bind this adapter to one staged section and one of its ten owners."""
		_state = p_state
		_owner = p_owner

	func canonical_field_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""Supply one declared field's values, or refuse a key this owner does not declare."""
		if _owner == OWNER_ENTITY_DIRECTORY:
			return _directory_values(field_key, out)
		if _owner == OWNER_WORLD_RUNTIME:
			return _runtime_values(field_key, out)
		var ordinal: int = SaveSection01.field_keys_of(_owner).find(String(field_key))
		if ordinal < 0:
			return out.refuse(REFUSE_ADAPTER_FIELD, "'%s' declares no field '%s'"
				% [OWNER_KEYS[_owner], field_key])
		return _ordinary_values(ordinal, out)

	func _directory_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""§1's `entity_directory` block is the one u32 cursor and nothing else."""
		if field_key != &"_next_persistent_id":
			return out.refuse(REFUSE_ADAPTER_FIELD,
				"'entity_directory' declares no field '%s'" % field_key)
		return out.supply_int64(PackedInt64Array([_state.next_persistent_id]), 1)

	func _runtime_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""The four hashed WorldRuntime fields. Debt, the six counters and the tick are excluded."""
		if field_key == &"_world_seed":
			return out.supply_int32(PackedInt32Array([_state.runtime.world_seed]), 1)
		if field_key == &"_seeded":
			return out.supply_bytes(PackedByteArray([1 if _state.runtime.rng_seeded else 0]), 1)
		if field_key == &"_requested_speed":
			return out.supply_int32(PackedInt32Array([_state.runtime.requested_speed]), 1)
		if field_key == &"_pause_mask":
			return out.supply_int32(PackedInt32Array([_state.runtime.pause_mask]), 1)
		return out.refuse(REFUSE_ADAPTER_FIELD,
			"'world_runtime' emits no canonical record for '%s'" % field_key)

	func _ordinary_values(ordinal: int, out: Digest.FieldValues) -> bool:
		"""One ordinary owner's field, at the declared element count the wire uses."""
		var count: int = SaveSection01.field_counts_of(_owner, _state.space_layout)[ordinal]
		var type_code: int = SaveSection01.field_types_of(_owner)[ordinal]
		if _owner == OWNER_UNDERGROUND_SPACE:
			return _space_values(ordinal, type_code, count, out)
		if type_code == TYPE_U8:
			return out.supply_bytes(_byte_column(ordinal), count)
		if type_code == TYPE_I64:
			return out.supply_int64(_wide_column(ordinal), count)
		return out.supply_int32(_narrow_column(ordinal), count)

	func _space_values(ordinal: int, type_code: int, count: int,
			out: Digest.FieldValues) -> bool:
		"""One space field, converted from its raw little-endian bytes to its typed column."""
		var raw: PackedByteArray = _state.space_values[ordinal]
		if type_code == TYPE_U8:
			return out.supply_bytes(raw, count)
		if type_code == TYPE_I64:
			return out.supply_int64(raw.to_int64_array(), count)
		return out.supply_int32(raw.to_int32_array(), count)

	func _byte_column(ordinal: int) -> PackedByteArray:
		"""The u8 column of (`_owner`, `ordinal`): farming's tending flag, spatial's two cell
		columns, or one of world_init's five."""
		if _owner == OWNER_FARMING:
			return _state.farming.tended_today
		if _owner == OWNER_SPATIAL_WORLD:
			return _state.walkable if ordinal == 1 else _state.layer
		if ordinal == 0:
			return PackedByteArray([_state.published])
		return [_state.world_map.terrain, _state.world_map.soil, _state.world_map.basin,
			_state.world_map.cleared][ordinal - 2]

	func _wide_column(ordinal: int) -> PackedInt64Array:
		"""The i64 column of (`_owner`, `ordinal`): farming's two, or weather's identity row."""
		if _owner == OWNER_WEATHER:
			return _state.weather_row64
		return _state.farming.ripe_tick if ordinal == 7 else _state.farming.growth_remainder

	func _narrow_column(ordinal: int) -> PackedInt32Array:
		"""The i32 column of (`_owner`, `ordinal`), scalars included as one-element columns."""
		if _owner == OWNER_BUILDINGS:
			return [_state.building_slot, _state.room_slot, _state.furniture_slot][ordinal]
		if _owner == OWNER_FARMING:
			return [_state.farming.fertility, _state.farming.last_family,
				_state.farming.family_streak, _state.farming.last_legume_day,
				_state.farming.compost_season, _state.farming.active_plot_row,
				_state.farming.orchard_row][ordinal]
		if _owner == OWNER_FORAGE:
			return _state.tile_link_head
		if _owner == OWNER_RESOURCE_NODES:
			return _state.resource_slot
		if _owner == OWNER_SPATIAL_WORLD:
			return _spatial_narrow_column(ordinal)
		if _owner == OWNER_WEATHER:
			return _state.weather_row
		return _world_init_narrow_column(ordinal)

	func _spatial_narrow_column(ordinal: int) -> PackedInt32Array:
		"""`_map_revision` as a one-element column, then terrain and height."""
		if ordinal == 0:
			return PackedInt32Array([_state.map_revision])
		return _state.cell_terrain if ordinal == 3 else _state.height_units

	func _world_init_narrow_column(ordinal: int) -> PackedInt32Array:
		"""`_published_seed` as a one-element column, then the three basin columns."""
		if ordinal == 1:
			return PackedInt32Array([_state.published_seed])
		return [_state.world_map.basin_ref_slot, _state.world_map.basin_ref_generation,
			_state.world_map.basin_danger][ordinal - 6]


static func register_adapters(walker: Digest.Walker, state: State) -> Digest.Refusal:
	"""Register all ten section-1 owners' canonical value adapters on `walker`.

	Refuses on the first owner the declaration does not know or that already has an adapter, so a
	renamed or duplicated owner surfaces here instead of inside a digest.
	"""
	for owner: int in OWNER_COUNT:
		var refusal: Digest.Refusal = walker.register_owner(SECTION_ID, OWNER_KEYS[owner],
			Adapter.new(state, owner))
		if not refusal.is_ok():
			return refusal
	return Digest.Refusal.new(Digest.REFUSE_NONE, "")
