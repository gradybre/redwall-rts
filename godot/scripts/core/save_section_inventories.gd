extends RefCounted
## ARCH-SAVE-002 section 7 INVENTORIES_AND_LEASE_INDEXES: the six stores that hold every item,
## every lease and every claim, encoded through `save_codec.gd`'s ARCH-SAVE-001 primitives and
## framed by SAVE-LAYOUT-R01's standard owner block.
##
## ## Six owners, in ASCII key order, tiling the section with no gaps
##
## REG-R01 (`docs/planning/canonical_state_registry.json`) declares exactly six section-7 owners:
## `fishing`, `forage`, `gear`, `inventory`, `reservations`, `stock_age`. That listing is also
## their ASCII order, which REG-R01 requires ("owner blocks in ASCII key order"), and this module
## refuses a stream whose blocks arrive in any other order rather than sorting them on the way in.
## Field order inside a block is the DECLARED ORDINAL from that artifact, never GDScript
## declaration order -- `inventory`'s wire order therefore interleaves container and lot columns
## (`_c_live`, `_l_live`, `_c_generation`, `_l_generation`, ...) exactly as the ordinals say.
##
##   | Offset | Type | Field                                             | Bytes |
##   |-------:|------|---------------------------------------------------|------:|
##   |      0 | u32  | store_count = 6                                   |     4 |
##   |      4 |      | block 0 `fishing`, owner schema 1                 |       |
##   |        |      | block 1 `forage`, owner schema 1                  |       |
##   |        |      | block 2 `gear`, owner schema 1                    |       |
##   |        |      | block 3 `inventory`, owner schema 2                |       |
##   |        |      | block 4 `reservations`, owner schema 1             |       |
##   |        |      | block 5 `stock_age`, owner schema 1                |       |
##
## One block is `owner_key` (u32 UTF-8 byte length then the bytes), `owner_schema_version:u32`,
## `primary_count:u64`, `payload_byte_length:u64`, then the payload. The payload is
## `child_extent_count:u32`, that many `u64` child extents, then each declared field as
## `element_count:u64` followed by its tightly packed little-endian values. COLUMN-MAJOR, by
## SAVE-LAYOUT-R01's explicit choice and not by inference from SoA storage.
##
## `inventory`'s owner schema version is 2 and every other owner's is 1, read off REG-R01's
## `owners` array. REG-R01's baseline SECTION version vector `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]`
## gives section 7 version 2 "for protected provenance"; that number lives in the 64-byte
## descriptor `save_header.gd` carries and is deliberately NOT written by this module.
##
## ## HAZARD 1 -- free-stack counts precede their used prefixes, and the tail is garbage
##
## REG-R01: "Inventory free-stack counts occur before their used prefixes; preserve stack order,
## validate counts against occupancy/retirement, rebuild other derived counts." `_c_free_count`
## and `_l_free_count` are ordinals 0 and 1; `_c_free` and `_l_free` are ordinals 28 and 29. That
## ordering is not decoration: the reader knows each stack's length before it reads a value.
##
## `inventory.gd`'s free lists are STACKS, not `entity_directory.gd`'s min-heaps -- `_alloc_lot_slot()`
## pops `_l_free[_l_free_count - 1]`, so pop order is last-freed-first and depends on the array
## PERMUTATION, not on the free set. The permutation is therefore category 1 and must be written.
## Only `[0, count)` is; the tail beyond the count is stale garbage left by earlier pops, and two
## worlds identical in every observable way can hold different garbage there. Persisting it would
## make those two worlds produce different bytes and different CRCs. `stock_age.gd`'s
## `_declared_slots` is the same shape for the same reason -- `_drop_declaration()` swaps the last
## entry into the freed position, so sweep order is observable and is not `_c_storage_class`
## ascending.
##
## `OwnerRecord` holds each of those three columns at its full backing capacity with a canonical
## `NULL_SLOT` tail, and `set_stack_column()` is the only way to fill one: it copies exactly
## `count` entries in order and fills the rest with `NULL_SLOT`. Encode writes the prefix; decode
## rebuilds the canonical tail. A round trip is byte-identical whatever the live store's tail held.
##
## ## HAZARD 2 -- four generation namespaces, two of them here, and two owners with none at all
##
## The 2026-09-11 addendum records four distinct generation spaces: `entity_directory.gd`'s slot
## generation, `inventory.gd`'s CONTAINER generation `_c_generation`, `inventory.gd`'s LOT
## generation `_l_generation`, and `navigation.gd`'s route-descriptor generation. Two of the four
## are owned here. `stock_age._c_declared_generation` is an INVENTORY CONTAINER generation;
## `reservations._r_lot_generation` and `gear._lot_generation` are INVENTORY LOT generations;
## `gear._owner_generation`, `gear._claim_job_generation`, `reservations._r_job_generation`,
## `forage._claim_*_generation` and `fishing._effort_claim_*_generation` are DIRECTORY generations.
## This module validates each against the range of the space it belongs to and never merges them.
##
## REG-R01 is explicit about the other half: "gear and reservations have no invented generation
## and cannot be compacted". A `gear` row and a `reservations` row are addressed by BARE ROW
## INDEX. This module writes them in row order at full capacity, invents no generation column for
## either, and a loader must not renumber them -- the index IS the identity.
##
## ## HAZARD 3 -- `_l_provenance` has a bounded domain and is refused, never clamped
##
## Decision 0113 / PROV-R01 freeze `InventoryProvenance` as a PROTECTED six-member domain,
## members 0..5 inclusive: ORDINARY, STARTER, COASTAL_BRINE, EXCAVATION, BACKFILL_RECLAIM,
## SPOIL_RECLAIM. REG-R01's record for `_l_provenance` carries `value_domain` and
## `value_extent: "0..5 inclusive"`, so the bound is checkable from the declaration rather than
## guessed. A stored 6, or a -1, is REFUSED. It is not clamped, not mapped to ORDINARY and not
## treated as an unknown wildcard: `UNSET_PROVENANCE` is the compatibility SPELLING of ORDINARY
## and not a seventh member. The bound is enforced on every row, live or free, because
## `_clear_lot_rows()` fills the column with `UNSET_PROVENANCE`, which is in domain.
##
## ## HAZARD 4 -- differently sized logical tables, and no extent inferred from a first column
##
## REG-R01: "Module owners containing several differently sized logical tables need an explicitly
## validated primary count and child extents before their wire body is frozen; the logical
## registry does not authorize guessing these from the first column."
##
## `inventory` is that owner. Its containers run to `_c_capacity <= 101376` and its lots to
## `_l_capacity <= 16384`, and its FIRST declared column is the scalar `_c_free_count` whose
## element count is 1 -- so inferring from the first column would produce an extent of one. The
## block therefore declares `primary_count = _c_capacity` in the wrapper and ONE child extent,
## `_l_capacity`, at the head of the payload; every column's own `element_count` must then equal
## whichever of the two its declared shape names. `stock_age` has a fixed `CONTAINER_CAPACITY`
## table and one count-governed list, `gear`/`reservations`/`forage`/`fishing` one table each, so
## they declare zero child extents and their `primary_count` is their row capacity.
##
## Extents are never derived from a column length here. `child_extents_of()` is a static table
## keyed by owner, `element_count_of()` reads the field's declared extent selector, and a
## disagreement between the two is REFUSE_ELEMENT_COUNT.
##
## ## Size: chunked, because ARCH-SAVE-003 says large sections are
##
## At the compiled maxima with every slot free this section is 10437959 bytes -- larger than
## section 3. ARCH-SAVE-003: "stream Chronicle and large sections in 65536-byte chunks,
## calculating CRC/digest incrementally." `ChunkCursor` is that stream, field-aligned so no chunk
## straddles two columns or two owners, following `save_section_directory.gd`'s precedent exactly.
## It does not fold the CRC itself: `save_header.gd::crc32_update()` takes a running register, and
## the caller folds each chunk because it must also fold the body SHA-256 over the same bytes.
##
## ## Allocate before consume
##
## Decision 0059. `decode_into()` proves the whole extent, reads into a LOCAL `Record`, validates
## every framing field, every column domain and every cross-column invariant, and only then copies
## into the caller's `Record`. A refusal -- truncated, or FULL-LENGTH AND INVALID -- leaves the
## caller's Record byte-identical, which `test_save_section_inventories.gd` asserts by comparing
## bytes rather than by eye. Every primary count and child extent is bounded against its compiled
## maximum BEFORE an `OwnerRecord` is allocated, so a hostile count cannot make this allocate.
##
## ## The int32 sign trap
##
## GDScript ints are 64-bit, so `0x80000000` is a POSITIVE 2147483648 while `-2147483648` is the
## same bit pattern read as int32. Every four-byte signed field here is read through
## `Reader.read_i32_into()`, which carries signedness explicitly. A generation whose bytes are
## `00 00 00 80` therefore decodes as -2147483648 and is refused as a negative generation instead
## of being accepted as a plausible 2147483648 no i32 column could hold.
##
## ## COLD PATH, NO FLOAT
##
## ARCH-SAVE-003 saves at a completed boundary. `Record`, `OwnerRecord` and the chunk buffers are
## BOUNDED CODEC SCRATCH that exists only between a capture and an apply; they are not new
## authoritative columns and not a second world. ARCH-AUTH-002: there is no float in this file,
## and `test_save_section_inventories.gd` greps this source to keep it that way.
##
## ## BLOCKER I1 -- NO OWNER PUBLISHES ITS COLUMNS, SO THERE IS NO `capture_into(store)`
##
## `save_section_directory.gd` can capture a live store because `entity_directory.gd` grew
## `copy_columns_into()` / `restore_columns()` for it (decision 0105). NONE of `inventory.gd`,
## `gear.gd`, `reservations.gd`, `stock_age.gd`, `forage.gd` or `fishing.gd` has an equivalent.
## Their columns are underscore-prefixed members, no module in this repository reads another's,
## and reaching into them here would put the free-stack, min-heap and intrusive-chain invariants
## in two files. So this module is the WIRE FORMAT and the VALIDATOR, reached through
## `OwnerRecord`'s typed column setters; `capture_into(store)` and `apply(record, store)` cannot
## be written until each of the six owners publishes the same shape the directory did. Those six
## files are not this lane's to edit. The gap is named here rather than half-published.
##
## ## OPEN, NOT INVENTED
##
##   * The 64-byte descriptor's `row_count` for a SIX-owner section. SAVE-LAYOUT-R01 settles it
##     for section 3 ("that capacity") and REG-R01 settles a `primary_count` per owner, but no
##     document says what a multi-owner section's single descriptor row_count is. Summing six
##     unrelated capacities would be a number with no meaning. This module therefore publishes no
##     `descriptor_row_count()`; the header owner must have that ruled.
##   * `inventory.gd` does NOT blank a retired container or lot row -- `_retire_lot()` clears
##     `_l_live` and frees the slot, leaving `_l_item_id`, `_l_quality` and `_l_provenance` at
##     their last live values. Two worlds that are observably identical can therefore differ in
##     those bytes. That is the store owner's design and this module does not refuse it; it is
##     recorded because section 15's canonical digest will have to decide whether a retired row's
##     residue is part of the state. `fishing`, `forage`, `gear` and `reservations` DO blank a
##     released row completely, so this module enforces their canonical blank form.
##   * Cross-owner coupling -- that a `gear._lot_slot` is below `inventory`'s runtime
##     `_l_capacity` rather than merely below the compiled `LOT_CAPACITY`, or that each lot's
##     `_l_reserved_milli` equals the sum of the `reservations` rows naming it (ARCH-SAVE-005) --
##     belongs to the load orchestrator, which sees all six blocks and the entity directory at
##     once. This module validates each owner against the compiled maxima and says so.

## Self-preload, so the inner classes can reach this script's static functions. An inner class
## resolves constants from its outer script but NOT functions.
const SaveSectionInventoriesScript := preload("res://scripts/core/save_section_inventories.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

# --- ARCH-SAVE-002 identity ------------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 6 AUXILIARY_STATE, 7 INVENTORIES_AND_LEASE_INDEXES, ...".
const SECTION_ID: int = 7

## REG-R01's six section-7 owners. This listing is also their ASCII order.
const OWNER_FISHING: int = 0
const OWNER_FORAGE: int = 1
const OWNER_GEAR: int = 2
const OWNER_INVENTORY: int = 3
const OWNER_RESERVATIONS: int = 4
const OWNER_STOCK_AGE: int = 5
const OWNER_COUNT: int = 6
const STORE_COUNT: int = OWNER_COUNT

const OWNER_KEYS: Array[String] = [
	"fishing", "forage", "gear", "inventory", "reservations", "stock_age",
]

## REG-R01's `owner_schema_version` per owner. `inventory` is 2; the other five are 1.
const OWNER_SCHEMA_VERSIONS: Array[int] = [1, 1, 1, 2, 1, 1]

## SAVE-LAYOUT-R01 / S2: owner keys are nonempty ASCII, at most 256 bytes.
const OWNER_KEY_MAX_BYTES: int = 256

# --- declared field tables, from REG-R01's ordinals --------------------------------------------

## SAVE-R09 canonical type codes. 0 = u8, 1 = u32, 2 = i32, 4 = i64. There is no code 3 here.
const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_I64: int = 4

## Which declared extent a field's element count comes from. Never inferred from a column length.
const EXT_PRIMARY: int = 0
const EXT_CHILD_0: int = 1
const EXT_SCALAR: int = 2

## No count field governs this ordinal: its element count is its full backing extent.
const NO_COUNT_FIELD: int = -1

const KEYS_FISHING: Array[StringName] = [
	&"_effort_claim_active", &"_effort_claim_expedition_generation",
	&"_effort_claim_habitat_slot", &"_effort_claim_habitat_generation",
	&"_effort_claim_job_slot", &"_effort_claim_job_generation", &"_effort_claim_slot_count",
]
const TYPES_FISHING: Array[int] = [TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32]
const EXTENTS_FISHING: Array[int] = [
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
]
const COUNT_FIELDS_FISHING: Array[int] = [-1, -1, -1, -1, -1, -1, -1]

const KEYS_FORAGE: Array[StringName] = [
	&"_claim_active", &"_claim_job_slot", &"_claim_job_generation", &"_claim_designation_slot",
	&"_claim_designation_generation", &"_claim_basin_slot", &"_claim_basin_generation",
	&"_claim_patch_kind", &"_claim_remaining_milli", &"_claim_created_tick",
	&"_claim_persistent_id",
]
const TYPES_FORAGE: Array[int] = [
	TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32,
	TYPE_I64, TYPE_I64, TYPE_I64,
]
const EXTENTS_FORAGE: Array[int] = [
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
]
const COUNT_FIELDS_FORAGE: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

const KEYS_GEAR: Array[StringName] = [
	&"_occupied", &"_lot_slot", &"_lot_generation", &"_item_id", &"_durability",
	&"_durability_cap", &"_owner_slot", &"_owner_generation", &"_manufacture_recipe",
	&"_equipped", &"_claim_job_slot", &"_claim_job_generation",
]
const TYPES_GEAR: Array[int] = [
	TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32,
	TYPE_U8, TYPE_I32, TYPE_I32,
]
const EXTENTS_GEAR: Array[int] = [
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
]
const COUNT_FIELDS_GEAR: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

const KEYS_INVENTORY: Array[StringName] = [
	&"_c_free_count", &"_l_free_count", &"_c_live", &"_l_live", &"_c_generation",
	&"_l_generation", &"_c_owner_slot", &"_c_owner_generation", &"_c_policy", &"_c_lot_count",
	&"_c_first_lot", &"_c_max_mass_g", &"_c_filters", &"_c_reserved_mass_g", &"_c_used_mass_g",
	&"_c_reachable", &"_l_item_id", &"_l_quality", &"_l_provenance", &"_l_recipe_id",
	&"_l_container_slot", &"_l_container_generation", &"_l_next", &"_l_prev",
	&"_l_quantity_milli", &"_l_reserved_milli", &"_l_age_milli_hours", &"_l_age_remainder",
	&"_c_free", &"_l_free",
]
const TYPES_INVENTORY: Array[int] = [
	TYPE_U32, TYPE_U32, TYPE_U8, TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32,
	TYPE_I32, TYPE_I32, TYPE_I64, TYPE_I64, TYPE_I64, TYPE_I64, TYPE_U8, TYPE_I32, TYPE_I32,
	TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I64, TYPE_I64, TYPE_I64,
	TYPE_I64, TYPE_I32, TYPE_I32,
]
const EXTENTS_INVENTORY: Array[int] = [
	EXT_SCALAR, EXT_SCALAR, EXT_PRIMARY, EXT_CHILD_0, EXT_PRIMARY, EXT_CHILD_0, EXT_PRIMARY,
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
	EXT_PRIMARY, EXT_PRIMARY, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0,
	EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0, EXT_CHILD_0,
	EXT_PRIMARY, EXT_CHILD_0,
]
## Ordinals 28 and 29 are the free STACKS: backed by the container and lot extents, persisted
## only as far as the counts at ordinals 0 and 1. HAZARD 1.
const COUNT_FIELDS_INVENTORY: Array[int] = [
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, 0, 1,
]

const KEYS_RESERVATIONS: Array[StringName] = [
	&"_occupied", &"_r_job_slot", &"_r_job_generation", &"_r_lot_slot", &"_r_lot_generation",
	&"_r_purpose", &"_r_quantity_milli", &"_r_expiry",
]
const TYPES_RESERVATIONS: Array[int] = [
	TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I64, TYPE_I64,
]
const EXTENTS_RESERVATIONS: Array[int] = [
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
	EXT_PRIMARY,
]
const COUNT_FIELDS_RESERVATIONS: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]

const KEYS_STOCK_AGE: Array[StringName] = [
	&"_declared_count", &"_last_hour_tick", &"_c_storage_class", &"_c_heated_interior",
	&"_c_declared_generation", &"_declared_slots",
]
const TYPES_STOCK_AGE: Array[int] = [
	TYPE_U32, TYPE_I64, TYPE_U8, TYPE_U8, TYPE_I32, TYPE_I32,
]
const EXTENTS_STOCK_AGE: Array[int] = [
	EXT_SCALAR, EXT_SCALAR, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
]
const COUNT_FIELDS_STOCK_AGE: Array[int] = [-1, -1, -1, -1, -1, 0]

# --- compiled bounds, taken from the owning modules rather than restated ------------------------

const FISHING_CLAIM_CAPACITY: int = FishingScript.FISHING_EFFORT_CLAIM_CAPACITY
const FISH_HABITAT_CAPACITY: int = FishingScript.FISH_HABITAT_CAPACITY
const FORAGE_CLAIM_CAPACITY: int = ForageScript.FORAGE_CLAIM_CAPACITY
const FORAGE_PATCH_KIND_COUNT: int = ForageScript.PATCHES_PER_ZONE
const GEAR_ROW_CAPACITY: int = GearScript.ROW_CAPACITY
const RESERVATION_ROW_CAPACITY: int = ReservationsScript.ROW_CAPACITY
const CONTAINER_CAPACITY: int = InventoryScript.CONTAINER_CAPACITY
const LOT_CAPACITY: int = InventoryScript.LOT_CAPACITY
const ITEM_CAPACITY: int = InventoryScript.ITEM_CAPACITY
const STORAGE_CLASS_COUNT: int = StockAgeScript.STORAGE_CLASS_COUNT
const STORAGE_UNDECLARED: int = StockAgeScript.STORAGE_UNDECLARED
const NO_HOUR_RUN: int = StockAgeScript.NO_HOUR_RUN
const DIRECTORY_CAPACITY: int = EntityDirectoryScript.DIRECTORY_CAPACITY
const NULL_SLOT: int = InventoryScript.NULL_SLOT
const NULL_GENERATION: int = InventoryScript.NULL_GENERATION
const MAX_INT32: int = InventoryScript.MAX_INT32
const MANUFACTURE_BASIC: int = GearScript.MANUFACTURE_BASIC
const MANUFACTURE_IRON: int = GearScript.MANUFACTURE_IRON

## Decision 0113 / PROV-R01: the protected InventoryProvenance domain is 0..5 INCLUSIVE.
const PROVENANCE_MIN: int = CatalogScript.PROVENANCE_ORDINARY
const PROVENANCE_MAX: int = CatalogScript.PROVENANCE_SPOIL_RECLAIM

## The maximum `primary_count` each owner's block may declare, by owner ordinal. `gear`,
## `inventory` and `reservations` size their tables from a construction argument, so their
## primary count is a stored runtime value bounded here; the other three are compile-time fixed.
const PRIMARY_COUNT_MAXIMA: Array[int] = [
	FISHING_CLAIM_CAPACITY, FORAGE_CLAIM_CAPACITY, GEAR_ROW_CAPACITY, CONTAINER_CAPACITY,
	RESERVATION_ROW_CAPACITY, CONTAINER_CAPACITY,
]
## True where the primary count is a compile-time constant and any other value is a refusal.
const PRIMARY_COUNT_IS_FIXED: Array[bool] = [true, true, false, false, false, true]

# --- framing arithmetic ------------------------------------------------------------------------

const SECTION_FRAMING_BYTES: int = SaveCodec.U32_BYTES
const ELEMENT_COUNT_BYTES: int = SaveCodec.U64_BYTES
const CHILD_EXTENT_COUNT_BYTES: int = SaveCodec.U32_BYTES
const CHILD_EXTENT_BYTES: int = SaveCodec.U64_BYTES

## ARCH-SAVE-003: "stream Chronicle and large sections in 65536-byte chunks".
const CHUNK_BYTES: int = 65536

## `save_header.gd`'s endian sentinel, reused as the little-endian probe constant. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

# --- refusal codes -----------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BYTE_ORDER: StringName = &"SAVE_INV_BYTE_ORDER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_INV_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_INV_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_INV_LENGTH"
const REFUSE_STORE_COUNT: StringName = &"SAVE_INV_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_INV_OWNER_KEY"
const REFUSE_OWNER_ORDER: StringName = &"SAVE_INV_OWNER_ORDER"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_INV_OWNER_SCHEMA_VERSION"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_INV_PRIMARY_COUNT"
const REFUSE_CHILD_EXTENT_COUNT: StringName = &"SAVE_INV_CHILD_EXTENT_COUNT"
const REFUSE_CHILD_EXTENT: StringName = &"SAVE_INV_CHILD_EXTENT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_INV_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_INV_ELEMENT_COUNT"
const REFUSE_FIELD_ORDINAL: StringName = &"SAVE_INV_FIELD_ORDINAL"
const REFUSE_COLUMN_LENGTH: StringName = &"SAVE_INV_COLUMN_LENGTH"
const REFUSE_COLUMN_TYPE: StringName = &"SAVE_INV_COLUMN_TYPE"
const REFUSE_CURSOR_EXHAUSTED: StringName = &"SAVE_INV_CURSOR_EXHAUSTED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_INV_ENCODE_FAILED"
const REFUSE_OCCUPANCY_BYTE: StringName = &"SAVE_INV_OCCUPANCY_BYTE"
const REFUSE_GENERATION_RANGE: StringName = &"SAVE_INV_GENERATION_RANGE"
const REFUSE_SLOT_RANGE: StringName = &"SAVE_INV_SLOT_RANGE"
const REFUSE_BLANK_ROW: StringName = &"SAVE_INV_BLANK_ROW"
const REFUSE_ACTIVE_ROW: StringName = &"SAVE_INV_ACTIVE_ROW"
const REFUSE_PROVENANCE_DOMAIN: StringName = &"SAVE_INV_PROVENANCE_DOMAIN"
const REFUSE_STORAGE_CLASS: StringName = &"SAVE_INV_STORAGE_CLASS"
const REFUSE_HEATED_BYTE: StringName = &"SAVE_INV_HEATED_BYTE"
const REFUSE_DECLARED_LIST: StringName = &"SAVE_INV_DECLARED_LIST"
const REFUSE_FREE_STACK: StringName = &"SAVE_INV_FREE_STACK"
const REFUSE_SLOT_UNACCOUNTED: StringName = &"SAVE_INV_SLOT_UNACCOUNTED"
const REFUSE_QUANTITY_RANGE: StringName = &"SAVE_INV_QUANTITY_RANGE"
const REFUSE_AGE_RANGE: StringName = &"SAVE_INV_AGE_RANGE"
const REFUSE_CONTAINER_CAPACITY: StringName = &"SAVE_INV_CONTAINER_CAPACITY"
const REFUSE_HOUR_TICK: StringName = &"SAVE_INV_HOUR_TICK"
const REFUSE_PATCH_KIND: StringName = &"SAVE_INV_PATCH_KIND"
const REFUSE_DURABILITY: StringName = &"SAVE_INV_DURABILITY"
const REFUSE_MANUFACTURE: StringName = &"SAVE_INV_MANUFACTURE"
const REFUSE_SLOT_COUNT: StringName = &"SAVE_INV_SLOT_COUNT"
const REFUSE_ITEM_ID: StringName = &"SAVE_INV_ITEM_ID"


class OwnerRecord:
	"""One decoded owner block: its declared extents and one packed column per declared field.

	Columns are held in three typed arrays by STORAGE KIND -- `PackedByteArray` for u8,
	`PackedInt32Array` for i32, `PackedInt64Array` for u32 and i64 -- and located by
	`storage_index_of()`. u32 shares i64 storage so an unsigned value up to 4294967295 round-trips
	without ever being read as a negative int32; the wire width stays four bytes.

	Every column is allocated at its full BACKING extent in `_init` and never resized again. A
	count-governed column (`_c_free`, `_l_free`, `_declared_slots`) keeps a canonical `NULL_SLOT`
	tail beyond its count, so two records holding the same logical state compare equal and
	re-encode identically. See HAZARD 1.
	"""
	var owner: int = OWNER_FISHING
	var primary_count: int = 0
	var child_extents: PackedInt64Array = PackedInt64Array()
	var u8_columns: Array[PackedByteArray] = []
	var i32_columns: Array[PackedInt32Array] = []
	var i64_columns: Array[PackedInt64Array] = []

	func _init(p_owner: int, p_primary_count: int, p_child_extents: PackedInt64Array) -> void:
		"""Allocate every column of one owner at its declared extents. The only resize here."""
		owner = p_owner
		primary_count = p_primary_count
		child_extents = p_child_extents.duplicate()
		for ordinal: int in SaveSectionInventoriesScript.field_count_of(p_owner):
			_allocate_column(ordinal)

	func _allocate_column(ordinal: int) -> void:
		"""Append one column, sized to its declared backing extent and canonically filled."""
		var length: int = SaveSectionInventoriesScript.backing_extent_of(self, ordinal)
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		var fill: int = SaveSectionInventoriesScript.canonical_fill_of(owner, ordinal)
		if type_code == TYPE_U8:
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(length)
			bytes.fill(fill)
			u8_columns.append(bytes)
		elif type_code == TYPE_I32:
			var words: PackedInt32Array = PackedInt32Array()
			words.resize(length)
			words.fill(fill)
			i32_columns.append(words)
		else:
			var longs: PackedInt64Array = PackedInt64Array()
			longs.resize(length)
			longs.fill(fill)
			i64_columns.append(longs)

	func u8_column(ordinal: int) -> PackedByteArray:
		"""The u8 column at `ordinal`. Empty when that ordinal is not a u8 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_U8:
			return PackedByteArray()
		return u8_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i32_column(ordinal: int) -> PackedInt32Array:
		"""The i32 column at `ordinal`. Empty when that ordinal is not an i32 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I32:
			return PackedInt32Array()
		return i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i64_column(ordinal: int) -> PackedInt64Array:
		"""The u32/i64 column at `ordinal`. Empty when that ordinal is neither."""
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		if type_code != TYPE_I64 and type_code != TYPE_U32:
			return PackedInt64Array()
		return i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func scalar(ordinal: int) -> int:
		"""The single value of a scalar field, or 0 when `ordinal` is not one."""
		if SaveSectionInventoriesScript.field_extent_of(owner, ordinal) != EXT_SCALAR:
			return 0
		var column: PackedInt64Array = i64_column(ordinal)
		if column.is_empty():
			return 0
		return column[0]

	func set_u8_column(ordinal: int, values: PackedByteArray) -> bool:
		"""Replace one u8 column. Refuses a wrong type or a length that is not its extent."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_U8:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		u8_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_i32_column(ordinal: int, values: PackedInt32Array) -> bool:
		"""Replace one i32 column. Refuses a count-governed ordinal: use `set_stack_column()`."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I32:
			return false
		if SaveSectionInventoriesScript.count_field_of(owner, ordinal) != NO_COUNT_FIELD:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_i64_column(ordinal: int, values: PackedInt64Array) -> bool:
		"""Replace one i64 column. Refuses a wrong type or a length that is not its extent."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I64:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_scalar(ordinal: int, value: int) -> bool:
		"""Set a scalar field's single value. Refuses a non-scalar ordinal or a negative u32.

		The column is rebuilt and assigned back rather than written through a local: a packed
		array taken out of a typed `Array` is a copy-on-write VALUE, so `column[0] = v` would
		update a temporary and leave the record unchanged.
		"""
		if SaveSectionInventoriesScript.field_extent_of(owner, ordinal) != EXT_SCALAR:
			return false
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		if type_code == TYPE_U32 and not SaveCodec.fits_u32(value):
			return false
		var replacement: PackedInt64Array = PackedInt64Array()
		replacement.resize(1)
		replacement[0] = value
		i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = replacement
		return true

	func set_stack_column(ordinal: int, values: PackedInt32Array, count: int) -> bool:
		"""Install the live prefix of a count-governed column and canonicalise its tail.

		HAZARD 1. `count` entries are copied IN ORDER, because pop order is the array
		permutation; every later cell becomes `NULL_SLOT`, because the live store's tail is
		stale garbage two identical worlds can disagree about. Nothing beyond `count` is ever
		persisted or compared.
		"""
		if SaveSectionInventoriesScript.count_field_of(owner, ordinal) == NO_COUNT_FIELD:
			return false
		var backing: int = SaveSectionInventoriesScript.backing_extent_of(self, ordinal)
		if count < 0 or count > backing or values.size() < count:
			return false
		var column: PackedInt32Array = PackedInt32Array()
		column.resize(backing)
		column.fill(NULL_SLOT)
		for index: int in count:
			column[index] = values[index]
		i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = column
		return true

	func equals(other: OwnerRecord) -> bool:
		"""True when both records declare the same extents and hold identical column bytes."""
		if owner != other.owner or primary_count != other.primary_count:
			return false
		if child_extents != other.child_extents:
			return false
		return _columns_equal(other)

	func _columns_equal(other: OwnerRecord) -> bool:
		"""Compare all three storage arrays element by element rather than by container."""
		if u8_columns.size() != other.u8_columns.size():
			return false
		if i32_columns.size() != other.i32_columns.size():
			return false
		if i64_columns.size() != other.i64_columns.size():
			return false
		for index: int in u8_columns.size():
			if u8_columns[index] != other.u8_columns[index]:
				return false
		for index: int in i32_columns.size():
			if i32_columns[index] != other.i32_columns[index]:
				return false
		for index: int in i64_columns.size():
			if i64_columns[index] != other.i64_columns[index]:
				return false
		return true


class Record:
	"""One decoded section 7: six `OwnerRecord`s in REG-R01's declared ASCII order.

	Bounded codec scratch on ARCH-SAVE-003's cold path, never a per-tick allocation and never a
	second mutable world. `copy_from()` and `equals()` exist so a refusal can be proved to have
	changed nothing by byte comparison rather than by eye (decision 0059).
	"""
	var owners: Array[OwnerRecord] = []

	func _init() -> void:
		"""Allocate all six owner blocks at their default compiled extents."""
		for owner: int in OWNER_COUNT:
			owners.append(OwnerRecord.new(owner,
				SaveSectionInventoriesScript.default_primary_count_of(owner),
				SaveSectionInventoriesScript.default_child_extents_of(owner)))

	func of(owner: int) -> OwnerRecord:
		"""The block for one owner ordinal."""
		return owners[owner]

	func copy_from(other: Record) -> void:
		"""Adopt every one of `other`'s six blocks. Six references to freshly decoded records."""
		owners = other.owners.duplicate()

	func equals(other: Record) -> bool:
		"""True when all six blocks compare equal."""
		for owner: int in OWNER_COUNT:
			if not owners[owner].equals(other.owners[owner]):
				return false
		return true


class Chunk:
	"""One streamed chunk: at most CHUNK_BYTES of section, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record one chunk's bytes; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with no bytes; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


class EncodeResult:
	"""Outcome of materialising a whole section: the bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded section; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- declared field tables, resolved by owner ordinal -------------------------------------------

static func field_keys_of(owner: int) -> Array[StringName]:
	"""REG-R01's canonical `field_key` strings for one owner, in declared ordinal order."""
	if owner == OWNER_FISHING:
		return KEYS_FISHING
	if owner == OWNER_FORAGE:
		return KEYS_FORAGE
	if owner == OWNER_GEAR:
		return KEYS_GEAR
	if owner == OWNER_INVENTORY:
		return KEYS_INVENTORY
	if owner == OWNER_RESERVATIONS:
		return KEYS_RESERVATIONS
	return KEYS_STOCK_AGE


static func field_types_of(owner: int) -> Array[int]:
	"""REG-R01's canonical type code per declared ordinal for one owner."""
	if owner == OWNER_FISHING:
		return TYPES_FISHING
	if owner == OWNER_FORAGE:
		return TYPES_FORAGE
	if owner == OWNER_GEAR:
		return TYPES_GEAR
	if owner == OWNER_INVENTORY:
		return TYPES_INVENTORY
	if owner == OWNER_RESERVATIONS:
		return TYPES_RESERVATIONS
	return TYPES_STOCK_AGE


static func field_extents_of(owner: int) -> Array[int]:
	"""Which declared extent governs each ordinal. HAZARD 4: never read off a column length."""
	if owner == OWNER_FISHING:
		return EXTENTS_FISHING
	if owner == OWNER_FORAGE:
		return EXTENTS_FORAGE
	if owner == OWNER_GEAR:
		return EXTENTS_GEAR
	if owner == OWNER_INVENTORY:
		return EXTENTS_INVENTORY
	if owner == OWNER_RESERVATIONS:
		return EXTENTS_RESERVATIONS
	return EXTENTS_STOCK_AGE


static func count_fields_of(owner: int) -> Array[int]:
	"""The scalar ordinal that bounds each field's persisted prefix, or NO_COUNT_FIELD."""
	if owner == OWNER_FISHING:
		return COUNT_FIELDS_FISHING
	if owner == OWNER_FORAGE:
		return COUNT_FIELDS_FORAGE
	if owner == OWNER_GEAR:
		return COUNT_FIELDS_GEAR
	if owner == OWNER_INVENTORY:
		return COUNT_FIELDS_INVENTORY
	if owner == OWNER_RESERVATIONS:
		return COUNT_FIELDS_RESERVATIONS
	return COUNT_FIELDS_STOCK_AGE


static func field_count_of(owner: int) -> int:
	"""How many fields one owner declares."""
	return field_types_of(owner).size()


static func field_type_of(owner: int, ordinal: int) -> int:
	"""The SAVE-R09 type code at one ordinal."""
	return field_types_of(owner)[ordinal]


static func field_extent_of(owner: int, ordinal: int) -> int:
	"""The extent selector at one ordinal."""
	return field_extents_of(owner)[ordinal]


static func count_field_of(owner: int, ordinal: int) -> int:
	"""The bounding scalar ordinal at one ordinal, or NO_COUNT_FIELD."""
	return count_fields_of(owner)[ordinal]


static func width_of_type(type_code: int) -> int:
	"""Element width in bytes of one SAVE-R09 type code."""
	if type_code == TYPE_U8:
		return SaveCodec.U8_BYTES
	if type_code == TYPE_I64:
		return SaveCodec.I64_BYTES
	return SaveCodec.I32_BYTES


static func storage_kind_of_type(type_code: int) -> int:
	"""0 for PackedByteArray, 1 for PackedInt32Array, 2 for PackedInt64Array storage.

	u32 shares the int64 store so an unsigned value above 2147483647 survives a round trip
	instead of being reinterpreted as a negative int32 -- the sign trap, closed by construction.
	"""
	if type_code == TYPE_U8:
		return 0
	if type_code == TYPE_I32:
		return 1
	return 2


static func storage_index_of(owner: int, ordinal: int) -> int:
	"""Position of one ordinal's column inside its storage-kind array."""
	var kind: int = storage_kind_of_type(field_type_of(owner, ordinal))
	var index: int = 0
	for earlier: int in ordinal:
		if storage_kind_of_type(field_type_of(owner, earlier)) == kind:
			index += 1
	return index


static func canonical_fill_of(owner: int, ordinal: int) -> int:
	"""The value a never-used cell of one column carries, from the owning module's own reset.

	`fishing._clear_effort_claim_row()`, `forage._clear_claim_columns()`, `gear._blank_row()` and
	`reservations.clear()` all spell absence as `NULL_SLOT` for a slot and `NULL_GENERATION` for
	a generation; `gear._item_id` uses -1 and `forage._claim_patch_kind` uses -1.
	`stock_age._last_hour_tick` starts at `NO_HOUR_RUN`. Everything else starts at zero.
	"""
	if owner == OWNER_STOCK_AGE and ordinal == 1:
		return NO_HOUR_RUN
	if count_field_of(owner, ordinal) != NO_COUNT_FIELD:
		return NULL_SLOT
	if NEGATIVE_ONE_FILL_KEYS.has(field_keys_of(owner)[ordinal]):
		return NULL_SLOT
	return 0


## Field keys whose empty value is -1 rather than 0, across all six owners. `_item_id` is
## `gear.gd`'s only -1 item column; `inventory._l_item_id` legitimately holds 0 on a free row.
const NEGATIVE_ONE_FILL_KEYS: Array[StringName] = [
	&"_effort_claim_habitat_slot", &"_effort_claim_job_slot", &"_claim_job_slot",
	&"_claim_designation_slot", &"_claim_basin_slot", &"_claim_patch_kind", &"_lot_slot",
	&"_item_id", &"_owner_slot", &"_r_job_slot", &"_r_lot_slot", &"_c_owner_slot",
	&"_c_first_lot", &"_l_container_slot", &"_l_next", &"_l_prev",
]


static func default_primary_count_of(owner: int) -> int:
	"""The primary count a freshly allocated block carries: the owner's compiled maximum."""
	return PRIMARY_COUNT_MAXIMA[owner]


static func default_child_extents_of(owner: int) -> PackedInt64Array:
	"""The child extents a freshly allocated block carries. Only `inventory` declares any."""
	if owner == OWNER_INVENTORY:
		return PackedInt64Array([LOT_CAPACITY])
	return PackedInt64Array()


static func child_extent_count_of(owner: int) -> int:
	"""How many child extents one owner's payload declares. HAZARD 4."""
	return default_child_extents_of(owner).size()


static func child_extent_maximum_of(owner: int, index: int) -> int:
	"""The compiled maximum one declared child extent may carry.

	`inventory`'s only child extent is its LOT table, capped by `inventory.gd`'s LOT_CAPACITY.
	No other section-7 owner declares one; a future owner that does must be added here rather
	than borrowing this bound.
	"""
	if owner == OWNER_INVENTORY and index == 0:
		return LOT_CAPACITY
	return 0


static func backing_extent_of(record: OwnerRecord, ordinal: int) -> int:
	"""The allocated length of one column: 1 for a scalar, else its declared table's extent."""
	var selector: int = field_extent_of(record.owner, ordinal)
	if selector == EXT_SCALAR:
		return 1
	if selector == EXT_PRIMARY:
		return record.primary_count
	return int(record.child_extents[selector - EXT_CHILD_0])


static func persisted_count_of(record: OwnerRecord, ordinal: int) -> int:
	"""How many values of one column reach the wire: its backing extent, or its count field.

	HAZARD 1: for `_c_free`, `_l_free` and `_declared_slots` this is the live prefix length, and
	the stale tail beyond it is never written.
	"""
	var count_field: int = count_field_of(record.owner, ordinal)
	if count_field == NO_COUNT_FIELD:
		return backing_extent_of(record, ordinal)
	return record.scalar(count_field)


# --- layout arithmetic --------------------------------------------------------------------------

static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove `PackedInt32Array.to_byte_array()` is little-endian on this build.

	The bulk conversions in `column_slice()` and `_assign_column()` are C++ memory copies rather
	than `save_codec.gd` writes, so they inherit the host's byte order instead of the codec's
	explicit little-endian. Every Godot target is little-endian, but an unchecked assumption is
	how a save written on one machine silently transposes ten megabytes on another.
	"""
	var probe: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()
	if probe.size() != SaveCodec.I32_BYTES:
		return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
			"an i32 converted to %d bytes, not %d" % [probe.size(), SaveCodec.I32_BYTES])
	for index: int in SaveCodec.I32_BYTES:
		var expected: int = (BYTE_ORDER_PROBE >> (index * 8)) & SaveCodec.UINT8_MAX
		if probe[index] != expected:
			return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
				"byte %d of the sentinel is %d, not the little-endian %d"
					% [index, probe[index], expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func owner_key_bytes_of(owner: int) -> int:
	"""UTF-8 byte length of one owner key. All six are ASCII, so this equals their length."""
	return SaveCodec.utf8_byte_length(OWNER_KEYS[owner])


static func wrapper_bytes_of(owner: int) -> int:
	"""SAVE-LAYOUT-R01's owner wrapper: key length, key, schema version, primary count, length."""
	return SaveCodec.U32_BYTES + owner_key_bytes_of(owner) + SaveCodec.U32_BYTES \
		+ SaveCodec.U64_BYTES + SaveCodec.U64_BYTES


static func extent_block_bytes_of(owner: int) -> int:
	"""The declared child-extent block at the head of one owner's payload."""
	return CHILD_EXTENT_COUNT_BYTES + CHILD_EXTENT_BYTES * child_extent_count_of(owner)


static func payload_bytes_of(record: OwnerRecord) -> int:
	"""Total payload bytes one owner block occupies, from its declared extents and counts."""
	var total: int = extent_block_bytes_of(record.owner)
	for ordinal: int in field_count_of(record.owner):
		total += ELEMENT_COUNT_BYTES
		total += width_of_type(field_type_of(record.owner, ordinal)) \
			* persisted_count_of(record, ordinal)
	return total


static func block_bytes_of(record: OwnerRecord) -> int:
	"""Total bytes one owner block occupies, wrapper included."""
	return wrapper_bytes_of(record.owner) + payload_bytes_of(record)


static func section_bytes_of(record: Record) -> int:
	"""Total bytes this section occupies: `store_count` plus six tiled blocks, no gaps."""
	var total: int = SECTION_FRAMING_BYTES
	for owner: int in OWNER_COUNT:
		total += block_bytes_of(record.of(owner))
	return total


static func elements_per_chunk(type_code: int) -> int:
	"""How many values of one type fit in CHUNK_BYTES. 65536 for u8, 16384 i32, 8192 i64."""
	return CHUNK_BYTES / width_of_type(type_code)


static func column_slice(record: OwnerRecord, ordinal: int, start: int,
		end: int) -> PackedByteArray:
	"""The little-endian bytes of one column's `[start, end)` values. C++ copies, no loop.

	A u32 column is written element by element instead, because its storage is int64 and a bulk
	`to_byte_array()` would emit eight bytes where the wire declares four.
	"""
	var type_code: int = field_type_of(record.owner, ordinal)
	if type_code == TYPE_U8:
		return record.u8_column(ordinal).slice(start, end)
	if type_code == TYPE_I32:
		return record.i32_column(ordinal).slice(start, end).to_byte_array()
	if type_code == TYPE_I64:
		return record.i64_column(ordinal).slice(start, end).to_byte_array()
	return _u32_slice(record, ordinal, start, end)


static func _u32_slice(record: OwnerRecord, ordinal: int, start: int,
		end: int) -> PackedByteArray:
	"""Four little-endian bytes per u32 value in `[start, end)`, range-checked by the Writer."""
	var column: PackedInt64Array = record.i64_column(ordinal)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new((end - start) * SaveCodec.U32_BYTES)
	for index: int in range(start, end):
		writer.write_u32(column[index])
	return writer.to_bytes()


# --- streaming encode ---------------------------------------------------------------------------

## `ChunkCursor` stages, in the order one section is emitted.
const STAGE_SECTION: int = 0
const STAGE_WRAPPER: int = 1
const STAGE_EXTENTS: int = 2
const STAGE_COUNT: int = 3
const STAGE_VALUES: int = 4
const STAGE_DONE: int = 5


class ChunkCursor:
	"""Streams a whole section 7 in chunks of at most CHUNK_BYTES, never materialising it.

	Chunk boundaries are field-aligned: the four `store_count` bytes are one chunk, each owner
	wrapper is one, each child-extent block is one, each field's 8-byte `element_count` is one,
	and a column's values split into whole-element runs. No chunk straddles two columns or two
	owners, so a caller folding CRC-32 and SHA-256 over the stream sees exactly the bytes
	`encode_record()` would produce, in the same order. The cursor does not fold either digest.
	"""
	var _record: Record
	var _owner: int = OWNER_FISHING
	var _stage: int = STAGE_SECTION
	var _field: int = 0
	var _element: int = 0
	var _length: int = 0
	var _emitted: int = 0

	func _init(p_record: Record) -> void:
		"""Open a cursor positioned before the section's `store_count`."""
		_record = p_record

	func has_more() -> bool:
		"""True while any chunk of the section is still unemitted."""
		return _stage != STAGE_DONE

	func emitted_bytes() -> int:
		"""Total bytes emitted so far. Equals `section_bytes_of()` once drained."""
		return _emitted

	func next_chunk_into(out: Chunk) -> bool:
		"""Emit the next chunk of the section, or refuse past its end."""
		if _stage == STAGE_DONE:
			return out.refuse(REFUSE_CURSOR_EXHAUSTED,
				"section 7 already emitted all %d bytes" % _emitted)
		if _stage == STAGE_SECTION:
			return _section_into(out)
		if _stage == STAGE_WRAPPER:
			return _wrapper_into(out)
		if _stage == STAGE_EXTENTS:
			return _extents_into(out)
		if _stage == STAGE_COUNT:
			return _count_into(out)
		return _values_into(out)

	func _section_into(out: Chunk) -> bool:
		"""Emit `store_count:u32`, refusing first if this build is not little-endian."""
		var order: SaveHeader.Refusal = SaveSectionInventoriesScript.byte_order_refusal()
		if not order.is_ok():
			return out.refuse(order.code, order.detail)
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(SECTION_FRAMING_BYTES)
		writer.write_u32(STORE_COUNT)
		_stage = STAGE_WRAPPER
		return _accept(writer, out)

	func _wrapper_into(out: Chunk) -> bool:
		"""Emit one owner's key, schema version, primary count and payload byte length."""
		var block: OwnerRecord = _record.of(_owner)
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(
			SaveSectionInventoriesScript.wrapper_bytes_of(_owner))
		writer.write_utf8_u32(OWNER_KEYS[_owner], OWNER_KEY_MAX_BYTES)
		writer.write_u32(OWNER_SCHEMA_VERSIONS[_owner])
		writer.write_u64(block.primary_count)
		writer.write_u64(SaveSectionInventoriesScript.payload_bytes_of(block))
		_stage = STAGE_EXTENTS
		return _accept(writer, out)

	func _extents_into(out: Chunk) -> bool:
		"""Emit the declared child extents at the head of one owner's payload. HAZARD 4."""
		var block: OwnerRecord = _record.of(_owner)
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(
			SaveSectionInventoriesScript.extent_block_bytes_of(_owner))
		writer.write_u32(block.child_extents.size())
		for index: int in block.child_extents.size():
			writer.write_u64(block.child_extents[index])
		_stage = STAGE_COUNT
		_field = 0
		return _accept(writer, out)

	func _count_into(out: Chunk) -> bool:
		"""Emit one field's `element_count:u64`, then position the cursor over its values."""
		var block: OwnerRecord = _record.of(_owner)
		_length = SaveSectionInventoriesScript.persisted_count_of(block, _field)
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(ELEMENT_COUNT_BYTES)
		writer.write_u64(_length)
		_element = 0
		_stage = STAGE_VALUES
		if _length == 0:
			_advance_field()
		return _accept(writer, out)

	func _values_into(out: Chunk) -> bool:
		"""Emit the next whole-element run of the current column, at most CHUNK_BYTES."""
		var block: OwnerRecord = _record.of(_owner)
		var type_code: int = SaveSectionInventoriesScript.field_type_of(_owner, _field)
		var per_chunk: int = SaveSectionInventoriesScript.elements_per_chunk(type_code)
		var end: int = mini(_element + per_chunk, _length)
		var bytes: PackedByteArray = SaveSectionInventoriesScript.column_slice(
			block, _field, _element, end)
		_element = end
		if _element >= _length:
			_advance_field()
		_emitted += bytes.size()
		return out.succeed(bytes)

	func _advance_field() -> void:
		"""Step to the next declared field, the next owner block, or the end of the section."""
		_field += 1
		if _field < SaveSectionInventoriesScript.field_count_of(_owner):
			_stage = STAGE_COUNT
			return
		_owner += 1
		_stage = STAGE_WRAPPER if _owner < OWNER_COUNT else STAGE_DONE

	func _accept(writer: SaveCodec.Writer, out: Chunk) -> bool:
		"""Hand one framing chunk to the caller, refusing if the writer range-checked a value."""
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		var bytes: PackedByteArray = writer.to_bytes()
		_emitted += bytes.size()
		return out.succeed(bytes)


static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole validated section 7 in one buffer, by draining a `ChunkCursor`.

	ARCH-SAVE-003 streams large sections and `ChunkCursor` is that stream; this is the
	concatenation, for a caller that genuinely wants every byte at once -- a pinned fixture, the
	canonical walker, a test. A file writer should drive the cursor instead.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var expected: int = section_bytes_of(record)
	var buffer: PackedByteArray = PackedByteArray()
	var cursor: ChunkCursor = ChunkCursor.new(record)
	var chunk: Chunk = Chunk.new()
	while cursor.has_more():
		if not cursor.next_chunk_into(chunk):
			return out.refuse(chunk.refusal, chunk.detail)
		if chunk.bytes.size() > CHUNK_BYTES:
			return out.refuse(REFUSE_LENGTH,
				"a chunk of %d bytes exceeds the %d-byte stream bound"
					% [chunk.bytes.size(), CHUNK_BYTES])
		buffer.append_array(chunk.bytes)
	if buffer.size() != expected:
		return out.refuse(REFUSE_LENGTH,
			"encoded %d bytes, not the declared %d" % [buffer.size(), expected])
	return out.succeed(buffer)


# --- decode ---------------------------------------------------------------------------------------

static func extent_refusal(bytes: PackedByteArray, offset: int,
		byte_length: int) -> SaveHeader.Refusal:
	"""Prove `byte_length` bytes are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_directory.gd::extent_refusal()` is. Section 7's length is not fixed -- six
	owners with runtime capacities -- so the descriptor's declared length is an argument rather
	than a compiled constant, and a load orchestrator can ask before committing to anything.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if byte_length < SECTION_FRAMING_BYTES:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 7 declares %d bytes, fewer than its %d framing bytes"
				% [byte_length, SECTION_FRAMING_BYTES])
	if bytes.size() < byte_length or offset > bytes.size() - byte_length:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 7 needs %d bytes at offset %d, buffer holds %d"
				% [byte_length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func decode_into(bytes: PackedByteArray, offset: int, byte_length: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode section 7 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the extent is proved, every owner wrapper is
	checked, each primary count and child extent is bounded against the compiled maximum BEFORE
	its `OwnerRecord` is allocated, the six blocks land in a LOCAL Record, and every column
	domain and cross-column invariant runs against that local. Only then is `out` overwritten.
	A full-length section carrying a provenance of 6, a free stack naming a live slot or blocks
	in the wrong ASCII order therefore leaves `out` byte-identical.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset, byte_length)
	if not extent.is_ok():
		return extent
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return order
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var parsed: Record = Record.new()
	var framing: SaveHeader.Refusal = _read_section(bytes, reader, parsed)
	if not framing.is_ok():
		return framing
	if reader.position() - offset != byte_length:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 7 consumed %d bytes, not the declared %d"
				% [reader.position() - offset, byte_length])
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_section(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read `store_count` then six owner blocks, tiling with no gaps in declared ASCII order."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 7 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	for owner: int in OWNER_COUNT:
		var block: SaveHeader.Refusal = _read_block(bytes, reader, owner, parsed)
		if not block.is_ok():
			return block
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_block(bytes: PackedByteArray, reader: SaveCodec.Reader, owner: int,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read one owner's wrapper, extents and columns, and check it consumed exactly its length.

	The payload begins after the three fixed-width wrapper fields the key is followed by, so
	`start` is computed from the key's end rather than sampled after `_read_wrapper()` -- which
	also consumes the child-extent block and would put those bytes outside the measured payload.
	"""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEYS[owner]:
		return SaveHeader.Refusal.new(REFUSE_OWNER_ORDER,
			("block %d is owned by '%s', not the ASCII-ordered '%s'. REG-R01 fixes the order; "
				+ "this reader does not sort blocks on the way in.")
				% [owner, text.value, OWNER_KEYS[owner]])
	var start: int = reader.position() + SaveCodec.U32_BYTES + SaveCodec.U64_BYTES \
		+ SaveCodec.U64_BYTES
	var declared: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var wrapper: SaveHeader.Refusal = _read_wrapper(reader, owner, parsed, declared)
	if not wrapper.is_ok():
		return wrapper
	var columns: SaveHeader.Refusal = _read_columns(bytes, reader, parsed.of(owner))
	if not columns.is_ok():
		return columns
	var consumed: int = reader.position() - start
	if consumed != declared.value:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' consumed %d payload bytes, not the %d its wrapper declares"
				% [OWNER_KEYS[owner], consumed, declared.value])
	if consumed != payload_bytes_of(parsed.of(owner)):
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' consumed %d payload bytes, not the %d its extents give"
				% [OWNER_KEYS[owner], consumed, payload_bytes_of(parsed.of(owner))])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_wrapper(reader: SaveCodec.Reader, owner: int, parsed: Record,
		out_declared: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read schema version, primary count, payload length and child extents, then allocate.

	HAZARD 4 and H4's "bounds are checked before allocation": the primary count and every child
	extent are bounded against the owning module's compiled maximum first, so a hostile count
	cannot make this allocate, and no extent is read off whichever column happens to come first.

	`out_declared` carries the wrapper's own `payload_byte_length` back to the caller, which
	compares it to the bytes the block ACTUALLY consumes. Recomputing the length from the
	decoded extents instead would compare the reader against itself and accept any declared
	length inside the arithmetically possible window -- which mutation testing confirmed.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSIONS[owner]:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner '%s' schema %d is not the supported %d"
				% [OWNER_KEYS[owner], scalar.value, OWNER_SCHEMA_VERSIONS[owner]])
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var primary_count: int = scalar.value
	var bound: SaveHeader.Refusal = primary_count_refusal(owner, primary_count)
	if not bound.is_ok():
		return bound
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	out_declared.succeed(scalar.value)
	return _read_extents(reader, owner, primary_count, scalar.value, parsed)


static func primary_count_refusal(owner: int, primary_count: int) -> SaveHeader.Refusal:
	"""Bound one owner's declared primary count against its compiled capacity.

	Three owners size their table from a construction argument, so their count is a stored
	runtime value in `[1, maximum]`. The other three are compile-time fixed and any other value
	is a refusal rather than a smaller world.
	"""
	var maximum: int = PRIMARY_COUNT_MAXIMA[owner]
	if PRIMARY_COUNT_IS_FIXED[owner] and primary_count != maximum:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"owner '%s' declares primary_count %d, not the compiled %d"
				% [OWNER_KEYS[owner], primary_count, maximum])
	if primary_count < 1 or primary_count > maximum:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"owner '%s' declares primary_count %d, outside 1..%d"
				% [OWNER_KEYS[owner], primary_count, maximum])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_extents(reader: SaveCodec.Reader, owner: int, primary_count: int,
		payload_length: int, parsed: Record) -> SaveHeader.Refusal:
	"""Read the declared child extents, bound each one, and allocate this owner's block."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != child_extent_count_of(owner):
		return SaveHeader.Refusal.new(REFUSE_CHILD_EXTENT_COUNT,
			"owner '%s' declares %d child extents, not %d"
				% [OWNER_KEYS[owner], scalar.value, child_extent_count_of(owner)])
	var extents: PackedInt64Array = PackedInt64Array()
	for index: int in scalar.value:
		var child: SaveCodec.Scalar = SaveCodec.Scalar.new()
		if not reader.read_u64_into(child):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		var maximum: int = child_extent_maximum_of(owner, index)
		if child.value < 1 or child.value > maximum:
			return SaveHeader.Refusal.new(REFUSE_CHILD_EXTENT,
				"owner '%s' child extent %d is %d, outside 1..%d"
					% [OWNER_KEYS[owner], index, child.value, maximum])
		extents.append(child.value)
	parsed.owners[owner] = OwnerRecord.new(owner, primary_count, extents)
	return _payload_length_refusal(owner, parsed.of(owner), payload_length)


static func _payload_length_refusal(owner: int, block: OwnerRecord,
		declared: int) -> SaveHeader.Refusal:
	"""Reject a declared payload length that cannot match the extents just read.

	The count-governed columns are still unknown here, so this is the length with EMPTY stacks
	as a floor and FULL stacks as a ceiling; `_read_block()` proves the exact figure afterwards.
	"""
	var floor_bytes: int = extent_block_bytes_of(owner)
	var ceiling_bytes: int = floor_bytes
	for ordinal: int in field_count_of(owner):
		var width: int = width_of_type(field_type_of(owner, ordinal))
		floor_bytes += ELEMENT_COUNT_BYTES
		ceiling_bytes += ELEMENT_COUNT_BYTES + width * backing_extent_of(block, ordinal)
		if count_field_of(owner, ordinal) == NO_COUNT_FIELD:
			floor_bytes += width * backing_extent_of(block, ordinal)
	if declared < floor_bytes or declared > ceiling_bytes:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' declares a %d-byte payload, outside %d..%d for its extents"
				% [OWNER_KEYS[owner], declared, floor_bytes, ceiling_bytes])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_columns(bytes: PackedByteArray, reader: SaveCodec.Reader,
		block: OwnerRecord) -> SaveHeader.Refusal:
	"""Read every declared field of one owner in ordinal order, count prefix then values."""
	for ordinal: int in field_count_of(block.owner):
		var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
		if not reader.read_u64_into(scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		var expected: int = persisted_count_of(block, ordinal)
		if expected < 0 or expected > backing_extent_of(block, ordinal):
			return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
				("owner '%s' field '%s' would persist %d values into a column of %d. Its count "
					+ "field is out of range and nothing is read.")
					% [OWNER_KEYS[block.owner], field_keys_of(block.owner)[ordinal], expected,
						backing_extent_of(block, ordinal)])
		if scalar.value != expected:
			return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
				"owner '%s' field '%s' declares %d elements, not the %d its extent gives"
					% [OWNER_KEYS[block.owner], field_keys_of(block.owner)[ordinal],
						scalar.value, expected])
		var read: SaveHeader.Refusal = _read_one_column(bytes, reader, block, ordinal, expected)
		if not read.is_ok():
			return read
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_one_column(bytes: PackedByteArray, reader: SaveCodec.Reader,
		block: OwnerRecord, ordinal: int, count: int) -> SaveHeader.Refusal:
	"""Read one column's values, bulk-reinterpreting its bytes where the widths allow it."""
	var type_code: int = field_type_of(block.owner, ordinal)
	if type_code == TYPE_U32:
		return _read_u32_column(reader, block, ordinal, count)
	var start: int = reader.position()
	var end: int = start + width_of_type(type_code) * count
	if end > bytes.size() or not reader.seek(end):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"owner '%s' field '%s' runs past the buffer"
				% [OWNER_KEYS[block.owner], field_keys_of(block.owner)[ordinal]])
	_assign_column(bytes.slice(start, end), block, ordinal, count)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_u32_column(reader: SaveCodec.Reader, block: OwnerRecord, ordinal: int,
		count: int) -> SaveHeader.Refusal:
	"""Read a u32 column one value at a time, keeping unsigned values out of the sign trap."""
	var column: PackedInt64Array = block.i64_column(ordinal).duplicate()
	for index: int in count:
		var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
		if not reader.read_u32_into(scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		column[index] = scalar.value
	block.i64_columns[storage_index_of(block.owner, ordinal)] = column
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _assign_column(raw: PackedByteArray, block: OwnerRecord, ordinal: int,
		count: int) -> void:
	"""Reinterpret one column's little-endian bytes into its packed array. C++ copies, no loop.

	A count-governed column keeps its canonical `NULL_SLOT` tail: only the first `count` cells
	come off the wire, and the rest were filled at allocation. HAZARD 1.
	"""
	var type_code: int = field_type_of(block.owner, ordinal)
	var index: int = storage_index_of(block.owner, ordinal)
	if type_code == TYPE_U8 and count == block.u8_columns[index].size():
		block.u8_columns[index] = raw
		return
	if type_code == TYPE_I64 and count == block.i64_columns[index].size():
		block.i64_columns[index] = raw.to_int64_array()
		return
	if type_code != TYPE_I32:
		return
	var values: PackedInt32Array = raw.to_int32_array()
	if count == block.i32_columns[index].size():
		block.i32_columns[index] = values
		return
	var column: PackedInt32Array = block.i32_columns[index].duplicate()
	for cell: int in count:
		column[cell] = values[cell]
	block.i32_columns[index] = column


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 7 rule, owner by owner, in declared ASCII order."""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	for owner: int in OWNER_COUNT:
		var refusal: SaveHeader.Refusal = owner_refusal(record.of(owner))
		if not refusal.is_ok():
			return refusal
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func owner_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Dispatch one owner block to its validator. Public so a lane can check one store alone."""
	if block.owner == OWNER_FISHING:
		return _fishing_refusal(block)
	if block.owner == OWNER_FORAGE:
		return _forage_refusal(block)
	if block.owner == OWNER_GEAR:
		return _gear_refusal(block)
	if block.owner == OWNER_INVENTORY:
		return _inventory_refusal(block)
	if block.owner == OWNER_RESERVATIONS:
		return _reservations_refusal(block)
	return _stock_age_refusal(block)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Check all six blocks are present, correctly owned and sized to their declared extents."""
	if record.owners.size() != OWNER_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"record holds %d owner blocks, not %d" % [record.owners.size(), OWNER_COUNT])
	for owner: int in OWNER_COUNT:
		var block: OwnerRecord = record.of(owner)
		if block.owner != owner:
			return SaveHeader.Refusal.new(REFUSE_OWNER_ORDER,
				"block %d declares owner %d" % [owner, block.owner])
		var bound: SaveHeader.Refusal = primary_count_refusal(owner, block.primary_count)
		if not bound.is_ok():
			return bound
		var columns: SaveHeader.Refusal = _block_shape_refusal(block)
		if not columns.is_ok():
			return columns
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _block_shape_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Check one block's child extents and every column length against the declared extents."""
	if block.child_extents.size() != child_extent_count_of(block.owner):
		return SaveHeader.Refusal.new(REFUSE_CHILD_EXTENT_COUNT,
			"owner '%s' holds %d child extents, not %d"
				% [OWNER_KEYS[block.owner], block.child_extents.size(),
					child_extent_count_of(block.owner)])
	for index: int in block.child_extents.size():
		var maximum: int = child_extent_maximum_of(block.owner, index)
		if block.child_extents[index] < 1 or block.child_extents[index] > maximum:
			return SaveHeader.Refusal.new(REFUSE_CHILD_EXTENT,
				"owner '%s' child extent %d is %d, outside 1..%d"
					% [OWNER_KEYS[block.owner], index, block.child_extents[index], maximum])
	for ordinal: int in field_count_of(block.owner):
		var length: SaveHeader.Refusal = _column_length_refusal(block, ordinal)
		if not length.is_ok():
			return length
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _column_length_refusal(block: OwnerRecord, ordinal: int) -> SaveHeader.Refusal:
	"""Check one column is allocated at exactly its declared backing extent."""
	var expected: int = backing_extent_of(block, ordinal)
	var type_code: int = field_type_of(block.owner, ordinal)
	var actual: int = block.u8_column(ordinal).size()
	if type_code == TYPE_I32:
		actual = block.i32_column(ordinal).size()
	elif type_code == TYPE_I64 or type_code == TYPE_U32:
		actual = block.i64_column(ordinal).size()
	if actual != expected:
		return SaveHeader.Refusal.new(REFUSE_COLUMN_LENGTH,
			"owner '%s' field '%s' holds %d cells, not the %d its extent declares"
				% [OWNER_KEYS[block.owner], field_keys_of(block.owner)[ordinal], actual, expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build one refusal. Shorthand used by the six owner validators."""
	return SaveHeader.Refusal.new(code, detail)


static func _accepted() -> SaveHeader.Refusal:
	"""The accepting refusal. Shorthand used by the six owner validators."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _occupancy_refusal(column: PackedByteArray, owner: int,
		ordinal: int) -> SaveHeader.Refusal:
	"""Refuse any occupancy byte that is not 0 or 1. ARCH-SAVE-002's bitset is one byte per row."""
	for row: int in column.size():
		if column[row] > 1:
			return _refuse(REFUSE_OCCUPANCY_BYTE,
				"owner '%s' field '%s' row %d holds %d, not 0 or 1"
					% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row, column[row]])
	return _accepted()


static func _generation_refusal(value: int, live: bool, owner: int,
		ordinal: int, row: int) -> SaveHeader.Refusal:
	"""Bound one generation: never negative, and never the null generation on a live row.

	THE SIGN TRAP. `00 00 00 80` reads as -2147483648 through `read_i32_into()`, so it lands
	here as a negative and is refused, rather than being taken for a plausible 2147483648.
	"""
	if value < NULL_GENERATION or value > MAX_INT32:
		return _refuse(REFUSE_GENERATION_RANGE,
			"owner '%s' field '%s' row %d holds generation %d, outside 0..%d"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row, value, MAX_INT32])
	if live and value == NULL_GENERATION:
		return _refuse(REFUSE_GENERATION_RANGE,
			"owner '%s' field '%s' row %d is live with the null generation"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row])
	return _accepted()


static func _slot_refusal(value: int, live: bool, capacity: int, owner: int, ordinal: int,
		row: int) -> SaveHeader.Refusal:
	"""Bound one slot reference: NULL_SLOT when free, and inside `capacity` when live."""
	if value < NULL_SLOT or value >= capacity:
		return _refuse(REFUSE_SLOT_RANGE,
			"owner '%s' field '%s' row %d holds slot %d, outside %d..%d"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row, value, NULL_SLOT,
					capacity - 1])
	if live and value == NULL_SLOT:
		return _refuse(REFUSE_SLOT_RANGE,
			"owner '%s' field '%s' row %d is live with the null slot"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row])
	return _accepted()


static func _blank_row_refusal(block: OwnerRecord, row: int,
		ordinals: Array[int]) -> SaveHeader.Refusal:
	"""Refuse a released row that is not at its owning module's canonical empty value.

	`fishing._clear_effort_claim_row()`, `forage._clear_claim_row()`, `gear._blank_row()` and
	`reservations._free_row()` each blank EVERY column of a released row, so a nonzero residue
	there is corruption, not history -- and, left unchecked, two observably identical worlds
	would produce different bytes. `inventory.gd` deliberately does NOT blank a retired row, so
	this check is not applied to it; see OPEN, NOT INVENTED.
	"""
	for ordinal: int in ordinals:
		var expected: int = canonical_fill_of(block.owner, ordinal)
		var actual: int = _cell_of(block, ordinal, row)
		if actual != expected:
			return _refuse(REFUSE_BLANK_ROW,
				"owner '%s' row %d is free but '%s' holds %d, not the blank %d"
					% [OWNER_KEYS[block.owner], row, field_keys_of(block.owner)[ordinal],
						actual, expected])
	return _accepted()


static func _cell_of(block: OwnerRecord, ordinal: int, row: int) -> int:
	"""One column cell as an integer, whatever storage kind it lives in."""
	var type_code: int = field_type_of(block.owner, ordinal)
	if type_code == TYPE_U8:
		return block.u8_column(ordinal)[row]
	if type_code == TYPE_I32:
		return block.i32_column(ordinal)[row]
	return block.i64_column(ordinal)[row]


## Ordinals every released row of the four blanking owners must carry at its canonical value.
const BLANK_ORDINALS_FISHING: Array[int] = [1, 2, 3, 4, 5, 6]
const BLANK_ORDINALS_FORAGE: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const BLANK_ORDINALS_GEAR: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const BLANK_ORDINALS_RESERVATIONS: Array[int] = [1, 2, 3, 4, 5, 6, 7]


static func _fishing_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `fishing.gd`'s FishingEffortClaim rows: a lease on a habitat's effort slots.

	The row index is the OWNING EXPEDITION'S typed row, so a loader must never compact these.
	`_effort_claim_habitat_slot` and `_effort_claim_job_slot` are DIRECTORY slots, taken from
	`habitat_ref.x` and `job_ref.x` in `_write_effort_claim()`, not typed rows of their stores.
	"""
	var active: PackedByteArray = block.u8_column(0)
	var occupancy: SaveHeader.Refusal = _occupancy_refusal(active, block.owner, 0)
	if not occupancy.is_ok():
		return occupancy
	for row: int in block.primary_count:
		var live: bool = active[row] == 1
		if not live:
			var blank: SaveHeader.Refusal = _blank_row_refusal(block, row, BLANK_ORDINALS_FISHING)
			if not blank.is_ok():
				return blank
			continue
		var claim: SaveHeader.Refusal = _fishing_row_refusal(block, row)
		if not claim.is_ok():
			return claim
	return _accepted()


static func _fishing_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one live effort claim: three references and a positive slot count."""
	for ordinal: int in [1, 3, 5]:
		var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(ordinal)[row],
			true, block.owner, ordinal, row)
		if not generation.is_ok():
			return generation
	for ordinal: int in [2, 4]:
		var slot: SaveHeader.Refusal = _slot_refusal(block.i32_column(ordinal)[row], true,
			DIRECTORY_CAPACITY, block.owner, ordinal, row)
		if not slot.is_ok():
			return slot
	if block.i32_column(6)[row] < 1:
		return _refuse(REFUSE_SLOT_COUNT,
			"fishing row %d is an active claim on %d effort slots"
				% [row, block.i32_column(6)[row]])
	return _accepted()


static func _forage_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `forage.gd`'s ForageClaim rows: live claims against a zone's quota.

	Indexed by the owning Job's typed row (decision 0030 §4.7), so these rows are not compacted
	either. `_claim_remaining_milli` is work in progress and `_claim_created_tick` orders expiry.
	"""
	var active: PackedByteArray = block.u8_column(0)
	var occupancy: SaveHeader.Refusal = _occupancy_refusal(active, block.owner, 0)
	if not occupancy.is_ok():
		return occupancy
	for row: int in block.primary_count:
		if active[row] != 1:
			var blank: SaveHeader.Refusal = _blank_row_refusal(block, row, BLANK_ORDINALS_FORAGE)
			if not blank.is_ok():
				return blank
			continue
		var claim: SaveHeader.Refusal = _forage_row_refusal(block, row)
		if not claim.is_ok():
			return claim
	return _accepted()


static func _forage_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one live forage claim: three directory refs, a patch kind and three int64s."""
	var slots: Array[int] = [1, 3, 5]
	var generations: Array[int] = [2, 4, 6]
	for index: int in slots.size():
		var slot: SaveHeader.Refusal = _slot_refusal(block.i32_column(slots[index])[row], true,
			DIRECTORY_CAPACITY, block.owner, slots[index], row)
		if not slot.is_ok():
			return slot
		var generation: SaveHeader.Refusal = _generation_refusal(
			block.i32_column(generations[index])[row], true, block.owner, generations[index], row)
		if not generation.is_ok():
			return generation
	var kind: int = block.i32_column(7)[row]
	if kind < 0 or kind >= FORAGE_PATCH_KIND_COUNT:
		return _refuse(REFUSE_PATCH_KIND,
			"forage row %d claims patch kind %d, outside 0..%d"
				% [row, kind, FORAGE_PATCH_KIND_COUNT - 1])
	for ordinal: int in [8, 9, 10]:
		if block.i64_column(ordinal)[row] < 0:
			return _refuse(REFUSE_QUANTITY_RANGE,
				"forage row %d field '%s' is negative" % [row, KEYS_FORAGE[ordinal]])
	return _accepted()


static func _gear_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `gear.gd`'s GearInstance rows.

	A GEAR ROW HAS NO GENERATION OF ITS OWN (REG-R01: gear "cannot be compacted"). `_lot_slot`
	pairs with `inventory.gd`'s LOT generation; `_owner_slot` and `_claim_job_slot` pair with
	DIRECTORY generations. Three namespaces in one row and none of them the row's.
	"""
	var occupied: PackedByteArray = block.u8_column(0)
	var equipped: PackedByteArray = block.u8_column(9)
	for ordinal: int in [0, 9]:
		var occupancy: SaveHeader.Refusal = _occupancy_refusal(
			block.u8_column(ordinal), block.owner, ordinal)
		if not occupancy.is_ok():
			return occupancy
	for row: int in block.primary_count:
		if occupied[row] != 1:
			var blank: SaveHeader.Refusal = _blank_row_refusal(block, row, BLANK_ORDINALS_GEAR)
			if not blank.is_ok():
				return blank
			continue
		var instance: SaveHeader.Refusal = _gear_row_refusal(block, row, equipped[row] == 1)
		if not instance.is_ok():
			return instance
	return _accepted()


static func _gear_row_refusal(block: OwnerRecord, row: int, equipped: bool) -> SaveHeader.Refusal:
	"""Validate one occupied gear row: its lot, its owner, its claim, wear and manufacture."""
	var lot: SaveHeader.Refusal = _slot_refusal(block.i32_column(1)[row], true, LOT_CAPACITY,
		block.owner, 1, row)
	if not lot.is_ok():
		return lot
	var lot_generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(2)[row], true,
		block.owner, 2, row)
	if not lot_generation.is_ok():
		return lot_generation
	var refs: SaveHeader.Refusal = _gear_refs_refusal(block, row, equipped)
	if not refs.is_ok():
		return refs
	if block.i32_column(3)[row] < 0:
		return _refuse(REFUSE_ITEM_ID, "gear row %d is occupied with item id %d"
			% [row, block.i32_column(3)[row]])
	return _gear_wear_refusal(block, row)


static func _gear_refs_refusal(block: OwnerRecord, row: int, equipped: bool) -> SaveHeader.Refusal:
	"""Validate the owner and job-claim references of one occupied gear row."""
	var owner_slot: int = block.i32_column(6)[row]
	var slot: SaveHeader.Refusal = _slot_refusal(owner_slot, equipped, DIRECTORY_CAPACITY,
		block.owner, 6, row)
	if not slot.is_ok():
		return slot
	var owner_live: bool = owner_slot != NULL_SLOT
	var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(7)[row], owner_live,
		block.owner, 7, row)
	if not generation.is_ok():
		return generation
	var claim_slot: int = block.i32_column(10)[row]
	var claim: SaveHeader.Refusal = _slot_refusal(claim_slot, false, DIRECTORY_CAPACITY,
		block.owner, 10, row)
	if not claim.is_ok():
		return claim
	return _generation_refusal(block.i32_column(11)[row], claim_slot != NULL_SLOT, block.owner,
		11, row)


static func _gear_wear_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one occupied gear row's durability window and manufacture recipe."""
	var durability: int = block.i32_column(4)[row]
	var cap: int = block.i32_column(5)[row]
	if cap < 0 or durability < 0 or durability > cap:
		return _refuse(REFUSE_DURABILITY,
			"gear row %d holds durability %d against a cap of %d" % [row, durability, cap])
	var recipe: int = block.i32_column(8)[row]
	if recipe != MANUFACTURE_BASIC and recipe != MANUFACTURE_IRON:
		return _refuse(REFUSE_MANUFACTURE,
			"gear row %d declares manufacture recipe %d, not %d or %d"
				% [row, recipe, MANUFACTURE_BASIC, MANUFACTURE_IRON])
	return _accepted()


static func _reservations_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `reservations.gd`'s rows: job-held claims on a lot's unreserved quantity.

	A RESERVATION ROW HAS NO GENERATION OF ITS OWN either. `_r_job_slot` is a JOB TYPED ROW
	bounded by `jobs.gd`'s JOB_CAPACITY (`_check_job_ref()` bounds it by `_job_capacity`), and
	`_r_lot_slot` is an `inventory.gd` LOT slot. Rows are addressed by index and not compacted.
	"""
	var occupied: PackedByteArray = block.u8_column(0)
	var occupancy: SaveHeader.Refusal = _occupancy_refusal(occupied, block.owner, 0)
	if not occupancy.is_ok():
		return occupancy
	for row: int in block.primary_count:
		if occupied[row] != 1:
			var blank: SaveHeader.Refusal = _blank_row_refusal(block, row,
				BLANK_ORDINALS_RESERVATIONS)
			if not blank.is_ok():
				return blank
			continue
		var claim: SaveHeader.Refusal = _reservation_row_refusal(block, row)
		if not claim.is_ok():
			return claim
	return _accepted()


static func _reservation_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one occupied reservation: its job row, its lot, its quantity and its expiry."""
	var job: SaveHeader.Refusal = _slot_refusal(block.i32_column(1)[row], true,
		ReservationsScript.JOB_CAPACITY, block.owner, 1, row)
	if not job.is_ok():
		return job
	var job_generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(2)[row], true,
		block.owner, 2, row)
	if not job_generation.is_ok():
		return job_generation
	var lot: SaveHeader.Refusal = _slot_refusal(block.i32_column(3)[row], true, LOT_CAPACITY,
		block.owner, 3, row)
	if not lot.is_ok():
		return lot
	var lot_generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(4)[row], true,
		block.owner, 4, row)
	if not lot_generation.is_ok():
		return lot_generation
	if block.i64_column(6)[row] <= 0:
		return _refuse(REFUSE_QUANTITY_RANGE,
			"reservation row %d is occupied and reserves %d milli"
				% [row, block.i64_column(6)[row]])
	if block.i64_column(7)[row] < 0:
		return _refuse(REFUSE_QUANTITY_RANGE,
			"reservation row %d expires at tick %d" % [row, block.i64_column(7)[row]])
	return _accepted()


static func _inventory_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `inventory.gd`: two differently sized tables and two order-bearing free stacks."""
	for ordinal: int in [2, 3, 15]:
		var occupancy: SaveHeader.Refusal = _occupancy_refusal(
			block.u8_column(ordinal), block.owner, ordinal)
		if not occupancy.is_ok():
			return occupancy
	var containers: SaveHeader.Refusal = _inventory_containers_refusal(block)
	if not containers.is_ok():
		return containers
	var lots: SaveHeader.Refusal = _inventory_lots_refusal(block)
	if not lots.is_ok():
		return lots
	var container_stack: SaveHeader.Refusal = _free_stack_refusal(block, 28, 0, 2, 4)
	if not container_stack.is_ok():
		return container_stack
	return _free_stack_refusal(block, 29, 1, 3, 5)


static func _inventory_containers_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate every container row: its generation, owner ref, chain head and mass ledger."""
	var live: PackedByteArray = block.u8_column(2)
	var lot_capacity: int = int(block.child_extents[0])
	for slot: int in block.primary_count:
		var is_live: bool = live[slot] == 1
		var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(4)[slot],
			is_live, block.owner, 4, slot)
		if not generation.is_ok():
			return generation
		var owner_slot: int = block.i32_column(6)[slot]
		var reference: SaveHeader.Refusal = _slot_refusal(owner_slot, false, DIRECTORY_CAPACITY,
			block.owner, 6, slot)
		if not reference.is_ok():
			return reference
		var owner_generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(7)[slot],
			owner_slot != NULL_SLOT, block.owner, 7, slot)
		if not owner_generation.is_ok():
			return owner_generation
		var chain: SaveHeader.Refusal = _container_chain_refusal(block, slot, is_live, lot_capacity)
		if not chain.is_ok():
			return chain
	return _accepted()


static func _container_chain_refusal(block: OwnerRecord, slot: int, is_live: bool,
		lot_capacity: int) -> SaveHeader.Refusal:
	"""Validate one container's lot count, chain head and BAL-SAFE-002 mass window.

	`_destroy_container_checked()` refuses unless the container is empty and holds no reserved
	mass, so a freed row carries a zero count, a null head and a zero ledger; anything else is
	a container that was freed while still charged.
	"""
	var lot_count: int = block.i32_column(9)[slot]
	var first_lot: int = block.i32_column(10)[slot]
	if lot_count < 0 or lot_count > lot_capacity:
		return _refuse(REFUSE_CONTAINER_CAPACITY,
			"container %d holds %d lots, outside 0..%d" % [slot, lot_count, lot_capacity])
	var head: SaveHeader.Refusal = _slot_refusal(first_lot, false, lot_capacity, block.owner,
		10, slot)
	if not head.is_ok():
		return head
	if (lot_count == 0) != (first_lot == NULL_SLOT):
		return _refuse(REFUSE_CONTAINER_CAPACITY,
			"container %d holds %d lots with first lot %d" % [slot, lot_count, first_lot])
	if not is_live and (lot_count != 0 or block.i64_column(13)[slot] != 0
			or block.i64_column(14)[slot] != 0):
		return _refuse(REFUSE_CONTAINER_CAPACITY,
			"container %d is free but still charged" % slot)
	return _container_mass_refusal(block, slot)


static func _container_mass_refusal(block: OwnerRecord, slot: int) -> SaveHeader.Refusal:
	"""Re-derive BAL-SAFE-002's `used + reserved <= max` without an addition that can overflow."""
	var maximum: int = block.i64_column(11)[slot]
	var reserved: int = block.i64_column(13)[slot]
	var used: int = block.i64_column(14)[slot]
	if maximum < 0 or reserved < 0 or used < 0:
		return _refuse(REFUSE_CONTAINER_CAPACITY,
			"container %d holds a negative mass: max %d, reserved %d, used %d"
				% [slot, maximum, reserved, used])
	if used > maximum or reserved > maximum - used:
		return _refuse(REFUSE_CONTAINER_CAPACITY,
			"container %d charges %d used plus %d reserved against a %d gram capacity"
				% [slot, used, reserved, maximum])
	return _accepted()


static func _inventory_lots_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate every lot row: its generation, item, provenance, chain and quantities."""
	var live: PackedByteArray = block.u8_column(3)
	var lot_capacity: int = int(block.child_extents[0])
	for slot: int in lot_capacity:
		var is_live: bool = live[slot] == 1
		var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(5)[slot],
			is_live, block.owner, 5, slot)
		if not generation.is_ok():
			return generation
		var provenance: SaveHeader.Refusal = _provenance_refusal(block.i32_column(18)[slot], slot)
		if not provenance.is_ok():
			return provenance
		var identity: SaveHeader.Refusal = _lot_identity_refusal(block, slot, is_live, lot_capacity)
		if not identity.is_ok():
			return identity
		var quantities: SaveHeader.Refusal = _lot_quantity_refusal(block, slot)
		if not quantities.is_ok():
			return quantities
	return _accepted()


static func _provenance_refusal(value: int, slot: int) -> SaveHeader.Refusal:
	"""HAZARD 3. Refuse any `_l_provenance` outside decision 0113's protected 0..5 domain.

	REFUSED, NEVER CLAMPED. A stored 6 or -1 is not an unknown origin to be mapped onto
	ORDINARY: PROV-R01 says "-1/6 and other arbitrary values fail", and a lot silently relabelled
	ORDINARY would gain or lose the coastal-brine and virgin-source entitlements the domain
	exists to gate. `UNSET_PROVENANCE` is the compatibility spelling of ORDINARY, in domain.
	"""
	if value < PROVENANCE_MIN or value > PROVENANCE_MAX:
		return _refuse(REFUSE_PROVENANCE_DOMAIN,
			("lot %d carries provenance %d, outside the protected InventoryProvenance domain "
				+ "%d..%d. Decision 0113 refuses it; it is not clamped to ORDINARY.")
				% [slot, value, PROVENANCE_MIN, PROVENANCE_MAX])
	return _accepted()


static func _lot_identity_refusal(block: OwnerRecord, slot: int, is_live: bool,
		lot_capacity: int) -> SaveHeader.Refusal:
	"""Validate one lot's item id, container reference and both intrusive chain links.

	Decision 0061: a LIVE lot with `_l_container_slot == -1` is an EQUIPPED gear record held by
	a resident -- threaded into no chain and charging no container. It is not a free row, so the
	container reference is deliberately not required to be live here.
	"""
	var item_id: int = block.i32_column(16)[slot]
	if item_id < 0 or item_id >= ITEM_CAPACITY:
		return _refuse(REFUSE_ITEM_ID,
			"lot %d names item %d, outside 0..%d" % [slot, item_id, ITEM_CAPACITY - 1])
	var container_slot: int = block.i32_column(20)[slot]
	var reference: SaveHeader.Refusal = _slot_refusal(container_slot, false,
		block.primary_count, block.owner, 20, slot)
	if not reference.is_ok():
		return reference
	var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(21)[slot],
		container_slot != NULL_SLOT, block.owner, 21, slot)
	if not generation.is_ok():
		return generation
	for ordinal: int in [22, 23]:
		var link: SaveHeader.Refusal = _slot_refusal(block.i32_column(ordinal)[slot], false,
			lot_capacity, block.owner, ordinal, slot)
		if not link.is_ok():
			return link
	if is_live and container_slot == NULL_SLOT and (block.i32_column(22)[slot] != NULL_SLOT
			or block.i32_column(23)[slot] != NULL_SLOT):
		return _refuse(REFUSE_SLOT_RANGE,
			"lot %d is an equipped record threaded into a container chain" % slot)
	return _accepted()


static func _lot_quantity_refusal(block: OwnerRecord, slot: int) -> SaveHeader.Refusal:
	"""ARCH-SAVE-005's `quantity >= 0` and `0 <= reserved <= quantity`, plus a non-negative age.

	The registry is explicit that "a negative or truncated age inverts every downstream spoilage
	result", and that refusal is the only legal response. A -1 written here as an overflow
	sentinel is exactly the bug that ruling was written against.
	"""
	var quantity: int = block.i64_column(24)[slot]
	var reserved: int = block.i64_column(25)[slot]
	if quantity < 0:
		return _refuse(REFUSE_QUANTITY_RANGE,
			"lot %d holds a quantity of %d milli" % [slot, quantity])
	if reserved < 0 or reserved > quantity:
		return _refuse(REFUSE_QUANTITY_RANGE,
			"lot %d reserves %d milli of %d" % [slot, reserved, quantity])
	for ordinal: int in [26, 27]:
		if block.i64_column(ordinal)[slot] < 0:
			return _refuse(REFUSE_AGE_RANGE,
				"lot %d field '%s' is %d, and a negative age inverts every spoilage result"
					% [slot, KEYS_INVENTORY[ordinal], block.i64_column(ordinal)[slot]])
	return _accepted()


static func _free_stack_refusal(block: OwnerRecord, stack_ordinal: int, count_ordinal: int,
		live_ordinal: int, generation_ordinal: int) -> SaveHeader.Refusal:
	"""HAZARD 1. Validate one free stack's live prefix against occupancy and retirement.

	REG-R01: "validate counts against occupancy/retirement". Every entry of `[0, count)` must be
	a distinct in-range slot whose `_live` byte is 0, and every slot that is neither live nor on
	the stack must be RETIRED -- `_free_lot_slot()` returns without pushing exactly when the
	generation has reached MAX_INT32, so that is the only way a slot leaves both sets. Stack
	ORDER is not checked, because order is the state: pops are last-freed-first.
	"""
	var capacity: int = backing_extent_of(block, stack_ordinal)
	var count: int = block.scalar(count_ordinal)
	if count < 0 or count > capacity:
		return _refuse(REFUSE_FREE_STACK,
			"owner 'inventory' field '%s' declares %d free slots, outside 0..%d"
				% [KEYS_INVENTORY[count_ordinal], count, capacity])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(capacity)
	seen.fill(0)
	var entries: SaveHeader.Refusal = _stack_entries_refusal(block, stack_ordinal, live_ordinal,
		count, seen)
	if not entries.is_ok():
		return entries
	return _stack_partition_refusal(block, stack_ordinal, live_ordinal, generation_ordinal, seen)


static func _stack_entries_refusal(block: OwnerRecord, stack_ordinal: int, live_ordinal: int,
		count: int, seen: PackedByteArray) -> SaveHeader.Refusal:
	"""Check the live prefix names distinct, in-range, non-live slots, and mark each as seen."""
	var stack: PackedInt32Array = block.i32_column(stack_ordinal)
	var live: PackedByteArray = block.u8_column(live_ordinal)
	for index: int in count:
		var slot: int = stack[index]
		if slot < 0 or slot >= seen.size():
			return _refuse(REFUSE_FREE_STACK,
				"free stack '%s' entry %d names slot %d, outside 0..%d"
					% [KEYS_INVENTORY[stack_ordinal], index, slot, seen.size() - 1])
		if seen[slot] == 1:
			return _refuse(REFUSE_FREE_STACK,
				"free stack '%s' names slot %d twice" % [KEYS_INVENTORY[stack_ordinal], slot])
		if live[slot] == 1:
			return _refuse(REFUSE_FREE_STACK,
				"free stack '%s' entry %d names slot %d, which is live"
					% [KEYS_INVENTORY[stack_ordinal], index, slot])
		seen[slot] = 1
	return _accepted()


static func _stack_partition_refusal(block: OwnerRecord, stack_ordinal: int, live_ordinal: int,
		generation_ordinal: int, seen: PackedByteArray) -> SaveHeader.Refusal:
	"""Every slot is live, on the stack, or retired at MAX_INT32. There is no fourth state."""
	var live: PackedByteArray = block.u8_column(live_ordinal)
	var generation: PackedInt32Array = block.i32_column(generation_ordinal)
	for slot: int in seen.size():
		if live[slot] == 1 or seen[slot] == 1:
			continue
		if generation[slot] != MAX_INT32:
			return _refuse(REFUSE_SLOT_UNACCOUNTED,
				("slot %d is neither live nor on free stack '%s', and its generation %d is not "
					+ "the exhausted %d that retirement leaves behind")
					% [slot, KEYS_INVENTORY[stack_ordinal], generation[slot], MAX_INT32])
	return _accepted()


static func _stock_age_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `stock_age.gd`: declaration columns plus one order-bearing dense slot list.

	`_c_declared_generation` is an `inventory.gd` CONTAINER generation and not the directory's:
	without it a recycled container slot would inherit the storage class of whatever used to
	occupy it, silently turning a cellar into an open pile.
	"""
	var heated: SaveHeader.Refusal = _occupancy_refusal(block.u8_column(3), block.owner, 3)
	if not heated.is_ok():
		return heated
	var tick: int = block.i64_column(1)[0]
	if tick < NO_HOUR_RUN:
		return _refuse(REFUSE_HOUR_TICK,
			"stock_age last hour tick %d is below %d" % [tick, NO_HOUR_RUN])
	var declarations: SaveHeader.Refusal = _stock_age_rows_refusal(block)
	if not declarations.is_ok():
		return declarations
	return _declared_list_refusal(block)


static func _stock_age_rows_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate every container's storage class, heated flag and declaration generation."""
	var classes: PackedByteArray = block.u8_column(2)
	var heated: PackedByteArray = block.u8_column(3)
	var generation: PackedInt32Array = block.i32_column(4)
	for slot: int in block.primary_count:
		if classes[slot] >= STORAGE_CLASS_COUNT:
			return _refuse(REFUSE_STORAGE_CLASS,
				"container %d declares storage class %d, outside 0..%d"
					% [slot, classes[slot], STORAGE_CLASS_COUNT - 1])
		var declared: bool = classes[slot] != STORAGE_UNDECLARED
		var bound: SaveHeader.Refusal = _generation_refusal(generation[slot], declared,
			block.owner, 4, slot)
		if not bound.is_ok():
			return bound
		if not declared and (heated[slot] != 0 or generation[slot] != 0):
			return _refuse(REFUSE_HEATED_BYTE,
				"container %d is undeclared but carries heated %d and generation %d"
					% [slot, heated[slot], generation[slot]])
	return _accepted()


static func _declared_list_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""HAZARD 1 again. Validate the dense declared list's prefix, order kept, tail unwritten.

	`_drop_declaration()` swaps the last entry into the freed position, so this ORDER is the
	hourly sweep order and is not recoverable from `_c_storage_class` ascending. The count must
	equal the number of declared containers exactly: a shorter one silently stops aging a store.
	"""
	var classes: PackedByteArray = block.u8_column(2)
	var slots: PackedInt32Array = block.i32_column(5)
	var count: int = block.scalar(0)
	if count < 0 or count > block.primary_count:
		return _refuse(REFUSE_DECLARED_LIST,
			"stock_age declares %d containers, outside 0..%d" % [count, block.primary_count])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(block.primary_count)
	seen.fill(0)
	for index: int in count:
		var slot: int = slots[index]
		if slot < 0 or slot >= block.primary_count or seen[slot] == 1:
			return _refuse(REFUSE_DECLARED_LIST,
				"declared entry %d names slot %d, out of range or repeated" % [index, slot])
		if classes[slot] == STORAGE_UNDECLARED:
			return _refuse(REFUSE_DECLARED_LIST,
				"declared entry %d names slot %d, which declares no storage class" % [index, slot])
		seen[slot] = 1
	return _declared_count_refusal(classes, seen)


static func _declared_count_refusal(classes: PackedByteArray,
		seen: PackedByteArray) -> SaveHeader.Refusal:
	"""Every container with a storage class must appear in the dense list exactly once.

	There is deliberately no separate `declared == count` comparison. `seen` carries exactly
	`count` marks, all of them on distinct declared slots, so once every declared slot is marked
	the two numbers are equal by construction -- a comparison here would be a line no input can
	reach, and mutation testing found it surviving for exactly that reason.
	"""
	for slot: int in classes.size():
		if classes[slot] != STORAGE_UNDECLARED and seen[slot] == 0:
			return _refuse(REFUSE_DECLARED_LIST,
				"container %d declares a storage class but is absent from the dense list" % slot)
	return _accepted()


# --- the empty world --------------------------------------------------------------------------

static func fill_empty(record: Record) -> void:
	"""Put a record into the state the six modules' own `clear()` calls produce.

	Five of the six are already there after allocation, because `canonical_fill_of()` reads each
	module's blank value. `inventory.gd` is not: `_clear_container_rows()` STEPS every generation
	forward to 1 rather than refilling with it, and `_refill_free_stack()` pushes slots
	HIGHEST-FIRST so the first pop returns slot 0. This reproduces both, which is what makes a
	freshly cleared store and a freshly allocated record encode to the same bytes.
	"""
	var block: OwnerRecord = record.of(OWNER_INVENTORY)
	var containers: int = block.primary_count
	var lots: int = int(block.child_extents[0])
	_fill_ones(block, 4, containers)
	_fill_ones(block, 5, lots)
	block.set_scalar(0, containers)
	block.set_scalar(1, lots)
	block.set_stack_column(28, _descending_slots(containers), containers)
	block.set_stack_column(29, _descending_slots(lots), lots)


static func _fill_ones(block: OwnerRecord, ordinal: int, length: int) -> void:
	"""Set one i32 column to generation 1 in every cell, as a cleared store's column is."""
	var column: PackedInt32Array = PackedInt32Array()
	column.resize(length)
	column.fill(1)
	block.set_i32_column(ordinal, column)


static func _descending_slots(length: int) -> PackedInt32Array:
	"""`[length - 1, ..., 0]`, the order `_refill_free_stack()` pushes a cleared store's slots."""
	var slots: PackedInt32Array = PackedInt32Array()
	slots.resize(length)
	for index: int in length:
		slots[index] = length - 1 - index
	return slots


static func empty_record() -> Record:
	"""A record holding the six stores' empty state at their compiled default capacities."""
	var record: Record = Record.new()
	fill_empty(record)
	return record
