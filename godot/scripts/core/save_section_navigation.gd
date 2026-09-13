extends RefCounted
## ARCH-SAVE-002 section 9 NAVIGATION: the partial A* search, the bounded route cache and the
## request queue, plus `movement.gd`'s route cursors, encoded through `save_codec.gd`'s
## ARCH-SAVE-001 primitives.
##
## ## THIS IS THE ROUTE-DESCRIPTOR GENERATION NAMESPACE AND NO OTHER
##
## The 2026-09-11 addendum records four distinct generation spaces: `entity_directory.gd`'s slot
## generation, `inventory.gd`'s container generation `_c_generation`, `inventory.gd`'s lot
## generation `_l_generation`, and `navigation.gd`'s ROUTE-DESCRIPTOR generation `_d_generation`.
## `gear.gd` and `reservations.gd` rows carry no generation at all. Section 9 touches TWO of them
## and they must not be confused:
##
##   * `_d_generation` and `_r_route_generation` are ROUTE-DESCRIPTOR generations. A READY request
##     holds the generation of the descriptor it references, and `_route_generation_refusal()`
##     compares those two and nothing else. `movement.gd`'s `_cursor_route_generation` is a copy
##     of the same number (`_route_still_valid()` compares it to `route_generation_of()`).
##   * `_r_job_generation`, `_c_start_owner_generation` and `_c_goal_owner_generation` are
##     DIRECTORY slot generations, half of an `EntityRef`. They are carried verbatim and are never
##     compared against a descriptor.
##
## A validator that checked `_r_route_generation` against `_r_job_generation` would accept a
## request whose two integers happen to match and republish an evicted route under a live holder.
##
## ## What section 9's bytes are
##
## REG-R01 (2026-09-12) gives §9 TWO owners, `movement` and `navigation`, and SAVE-LAYOUT-R01 gives
## the framing: `store_count:u32`, then one block per owner in ASCII key order -- `movement`
## before `navigation` -- each with `owner_key`, `owner_schema_version:u32`, `primary_count:u64`,
## `payload_byte_length:u64`. The blocks tile the section with no gaps.
##
##   | Offset | Type    | Field                                             | Bytes   |
##   |-------:|---------|---------------------------------------------------|--------:|
##   |      0 | u32     | store_count = 2                                   |       4 |
##   |      4 | u32     | owner_key byte length = 8                         |       4 |
##   |      8 | utf8    | owner_key = "movement"                            |       8 |
##   |     16 | u32     | owner_schema_version = 1                          |       4 |
##   |     20 | u64     | primary_count = 512                               |       8 |
##   |     28 | u64     | payload_byte_length = 18504                       |       8 |
##   |     36 |         | 9 cursor columns, each u64 count + 512 x i32      |   18504 |
##   |  18540 | u32     | owner_key byte length = 10                        |       4 |
##   |  18544 | utf8    | owner_key = "navigation"                          |      10 |
##   |  18554 | u32     | owner_schema_version = 2                          |       4 |
##   |  18558 | u64     | primary_count = 8192                              |       8 |
##   |  18566 | u64     | payload_byte_length = 5161468 + 4*(heap + arena)  |       8 |
##   |  18574 |         | 57 navigation fields in declared ordinal order    |       + |
##
## COLUMN-MAJOR, BY RULING. SAVE-LAYOUT-R01: "Packed stores use column-major bytes. Field schema
## order is the outer loop; ascending physical slot is the inner loop."
##
## FIELD ORDER IS THE DECLARED ORDINAL, NEVER GDScript DECLARATION ORDER. REG-R01: "Do not
## regenerate order from GDScript declaration order, dictionaries, display labels, directory
## iteration or this document at runtime." The two differ in both blocks and the difference is not
## cosmetic: `movement.gd` declares `_cursor_request` first, but ordinal 0 is `_cursor_owner_id`;
## `navigation.gd` declares `_g` first, but ordinal 13 is `_stamp`. NAV_FIELD_KEYS and
## MOVEMENT_FIELD_KEYS below are transcribed from
## `docs/planning/canonical_state_registry.json`, which REG-R01 makes the adopted declaration.
##
## ## Owner schema version 2 IS the exact-start semantics gate
##
## REG-R01's baseline section vector is `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]` and its stated reason for
## §9 is "exact-start navigation semantics", which is decision 0091 / PATH-R02. `navigation.gd`
## publishes the same number as `ROUTE_SEMANTICS_VERSION` and says a §9 restore "must compare this
## number and REFUSE, not flush the cache and not reinterpret an in-flight request". So the owner
## schema version and the route semantics version are the same gate, and `_read_navigation_owner()`
## puts a decoded version through `Navigation.refuse_route_semantics()` as well as comparing it to
## the declared 2. Version 1 was ARCH-PATH-003's macro-anchor composition; there is no migration.
##
## Two PATH-R02 consequences are enforced as wire rules, not comments:
##
##   * `_r_start_cell` must equal `_r_exact_start` in every row. ARCH-MEM-008 names both columns and
##     PATH-R02 makes them equal for good ("no stage rewrites the origin to an anchor any more"), so
##     a §9 writer persists both AND proves they agree.
##   * `PHASE_SEARCHING_LOCAL` (2) may not appear. The constant keeps its slot so an older payload
##     decodes to what it meant instead of re-reading as SEARCHING_FULL, and this schema version
##     refuses such a payload outright.
##
## ## The used prefix is persisted; the tail is not
##
## The ruling names §9's obligations: "Navigation partial search, arena used-prefix and queue
## progress remain required." The registry shapes `_heap` with `count_field: _heap_size` and
## `_arena` with `count_field: _arena_used`, both `used_prefix_preserve_order`, and every other
## column with a declared capacity.
##
## Cells at or past `_arena_used` are unallocated, not zeroed: `_compact_arena()` slides live
## blocks down and leaves the old copies in place, and `_heap_pop()` leaves the popped entry in
## `_heap[_heap_size]`. Two worlds that are identical in every observable way can hold different
## garbage there, so a §9 that wrote the tails would make them produce different bytes and
## different CRCs. That is decision 0103's argument about the directory's free heaps, and it
## applies here unchanged. `set_navigation_prefix_column()` copies `[0, used)` and zeroes the rest,
## `record_refusal()` REFUSES a Record whose tail is nonzero, and the wire carries `used` elements.
##
## OPEN, NAMED NOT INVENTED -- the builder residue is a different case. `_g`, `_parent`,
## `_heap_position` and `_state` are meaningful only where `_stamp[cell] == _search_serial`, so
## they carry residue too, but the registry declares all four at `SpatialWorld.CELL_COUNT` with
## `ascending_physical_slot` order, and `docs/persistence_state_registry.md` says §9 "may encode
## only the stamped cells ... but must reproduce them exactly". This module follows the declared
## shape and writes them verbatim. Sparsifying them is a later schema version's change, not this
## one's, and it needs a ruling because it would alter what the §15 digest covers.
##
## ## Primary count: declared here because the registry does not declare one
##
## REG-R01: "Module owners containing several differently sized logical tables need an explicitly
## validated primary count and child extents before their wire body is frozen; the logical registry
## does not authorize guessing these from the first column." `navigation` is exactly that owner: 13
## scalars, 262144-cell builder columns, 256 descriptors, 8192 requests and two used prefixes. No
## document publishes its primary count, so this module DECLARES it as `PATH_REQUEST_CAPACITY` --
## the path request is what §9 is about -- and validates every child extent separately against
## NAV_FIELD_EXTENT rather than deriving any of them from it. If a ruling lands with a different
## primary count, PRIMARY_COUNT_NAVIGATION changes and OWNER_SCHEMA_VERSION_NAVIGATION increments
## with it. `movement`'s primary count is unambiguous: one table, `MOTION_CAPACITY` = 512.
##
## ## Allocate before consume
##
## Decision 0059. `decode_into()` proves the declared extent is readable, reads into a LOCAL
## Record, validates framing, every declared element count, the recomputed payload length, every
## column domain and every cross-column invariant, and only then copies into the caller's Record.
## A refusal -- truncated, or FULL-LENGTH AND INVALID -- leaves the caller's Record byte-identical,
## and `test_save_section_navigation.gd` asserts that by comparing every column, not by eye.
##
## ## The int32 sign trap
##
## GDScript ints are 64-bit, so `0x80000000` is a POSITIVE 2147483648 while `-2147483648` is the
## same four bytes read as int32. Cell ids, route generations and the tick halves all sit near that
## boundary: `_d_generation` retires at 2147483647 rather than wrapping, and `_tick_high`/
## `_tick_low` exist precisely so no stored half has its high bit set. Every four-byte field here
## is read SIGNED, through `Reader.read_i32_into()` or `PackedByteArray.to_int32_array()`, so bytes
## `00 00 00 80` decode as -2147483648 and are refused as a negative generation rather than
## accepted as a plausible 2147483648.
##
## ## COLD PATH, NO FLOAT
##
## ARCH-SAVE-003 saves at a completed boundary and loads at a load boundary. `Record` and `Derived`
## are BOUNDED CODEC SCRATCH, not new authoritative columns: they exist only between capture and
## apply, they allocate every array once in `_init`, and nothing here runs per tick. There is no
## float in this file and `test_save_section_navigation.gd` greps this source to keep it that way.
##
## ## BLOCKER N1 -- NEITHER OWNER PUBLISHES A BULK COLUMN READER OR WRITER
##
## `navigation.gd` and `movement.gd` expose no `copy_columns_into()` / `restore_columns()` pair.
## Their §9 columns are underscore-prefixed privates, and no module in this repository reads
## another's privates -- `save_section_directory.gd` hit exactly this wall (its BLOCKER D1) and
## refused to reach in; the directory owner then added the API under decision 0105, and
## `save_section_world_runtime.gd` hit it against `sim_clock.gd` and got RESTORE-R01's
## `restore_runtime()`. So this module is complete from `Record` outwards -- capture setters,
## validation, encode, decode -- and there is deliberately NO `capture_into(store)` and NO
## `apply(record, store)`. `agrees_with_navigation()` cross-checks a Record against a live
## navigator as far as the PUBLIC readers allow, which is every scalar the module publishes, every
## descriptor's generation/variant/refcount and every request's phase; it cannot see `_g`,
## `_parent`, `_stamp`, `_heap`, `_arena` or the request columns.
##
## What is needed, exactly, and it is not this lane's file to write:
##
##     navigation.gd:
##       func copy_section9_columns_into(out_scalars: PackedInt32Array,
##           out_cells: PackedInt32Array, out_state: PackedByteArray,
##           out_descriptors: PackedInt32Array, out_requests: PackedInt32Array,
##           out_heap: PackedInt32Array, out_arena: PackedInt32Array) -> bool
##       func restore_section9_columns(scalars, cells, state, descriptors, requests,
##           heap, arena) -> bool
##       func last_column_refusal() -> StringName
##     movement.gd:
##       func copy_cursor_columns_into(out: PackedInt32Array) -> bool
##       func restore_cursor_columns(values: PackedInt32Array) -> bool
##
## ## BLOCKER N2 -- §9 PERSISTING CLOSES NO MOVE GATE
##
## PATH-R02's remeasured readiness distribution and MOVE-G01-05 are engineering work this module
## does not touch. A section that round-trips a partial search says nothing about how long that
## search takes to become ready.

## Self-preload, so the inner cursor classes can reach this script's static functions. An inner
## class resolves constants from its outer script but NOT functions.
const SaveSectionNavigationScript := preload("res://scripts/core/save_section_navigation.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Navigation := preload("res://scripts/core/navigation.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const SpatialWorld := preload("res://scripts/core/spatial_world.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

# --- ARCH-SAVE-002 identity ----------------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 8 JOB_INDEXES, 9 NAVIGATION, 10 RNG_STREAMS ...".
const SECTION_ID: int = 9

## REG-R01's baseline section vector `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]`, entry 9. The 64-byte
## DESCRIPTOR carries this; `save_header.gd` writes it and this module never does.
const SECTION_SCHEMA_VERSION: int = 2

## REG-R01: §9 has two owners. ASCII order puts "movement" (0x6D) before "navigation" (0x6E).
const STORE_COUNT: int = 2
const BLOCK_MOVEMENT: int = 0
const BLOCK_NAVIGATION: int = 1
const BLOCK_COUNT: int = 2

const OWNER_KEY_MOVEMENT: String = "movement"
const OWNER_KEY_NAVIGATION: String = "navigation"
const OWNER_KEY_MOVEMENT_BYTES: int = 8
const OWNER_KEY_NAVIGATION_BYTES: int = 10
## SAVE-LAYOUT-R01 / S2: owner keys are nonempty ASCII, at most 256 bytes.
const OWNER_KEY_MAX_BYTES: int = 256

const OWNER_SCHEMA_VERSION_MOVEMENT: int = 1
const OWNER_SCHEMA_VERSION_NAVIGATION: int = 2

# --- compiled extents, taken from the owners so the two cannot drift -----------------------------

const MOTION_CAPACITY: int = MovementScript.MOTION_CAPACITY
const CELL_COUNT: int = SpatialWorld.CELL_COUNT
const ROUTE_DESCRIPTOR_CAPACITY: int = Navigation.ROUTE_DESCRIPTOR_CAPACITY
const ROUTE_CELL_CAPACITY: int = Navigation.ROUTE_CELL_CAPACITY
const PATH_REQUEST_CAPACITY: int = Navigation.PATH_REQUEST_CAPACITY

const PRIMARY_COUNT_MOVEMENT: int = MOTION_CAPACITY
## DECLARED HERE; see "Primary count" in the module header.
const PRIMARY_COUNT_NAVIGATION: int = PATH_REQUEST_CAPACITY

const MAX_INT32: int = IntMath.INT32_MAX
const NO_ROW: int = -1
const NO_ROUTE: int = -1
const NO_VARIANT: int = -1
const NO_REQUEST: int = -1
const NO_PROFILE: int = -1
const NO_MODE: int = -1
const NO_OWNER_ID: int = 0

# --- movement block: nine cursor columns in declared ordinal order --------------------------------

const MOV_OWNER_ID: int = 0
const MOV_REQUEST: int = 1
const MOV_ROUTE_GENERATION: int = 2
const MOV_INDEX: int = 3
const MOV_PROFILE_ID: int = 4
const MOV_PROFILE_REVISION: int = 5
const MOV_MODE: int = 6
const MOV_LOAD_G: int = 7
const MOV_DESTINATION_REVISION: int = 8
const MOVEMENT_FIELD_COUNT: int = 9

const MOVEMENT_FIELD_KEYS: Array[StringName] = [
	&"_cursor_owner_id", &"_cursor_request", &"_cursor_route_generation", &"_cursor_index",
	&"_cursor_profile_id", &"_cursor_profile_revision", &"_cursor_mode", &"_cursor_load_g",
	&"_cursor_destination_revision",
]

# --- navigation block: 57 fields in declared ordinal order ----------------------------------------

const NAV_FIELD_COUNT: int = 57

const NAV_FIELD_KEYS: Array[StringName] = [
	&"_search_serial", &"_heap_size", &"_search_goal", &"_search_origin", &"_search_macro",
	&"_search_clearance", &"_expansions_remaining", &"_expansions_total", &"_arena_used",
	&"_free_request_head", &"_queue_head", &"_active_request", &"_served_revision",
	&"_stamp", &"_d_flags", &"_d_generation", &"_r_phase", &"_g", &"_parent", &"_heap",
	&"_heap_position", &"_state", &"_arena", &"_d_route_id", &"_d_start_macro", &"_d_goal_cell",
	&"_d_clearance", &"_d_map_revision", &"_d_variant_start", &"_d_anchor", &"_d_offset",
	&"_d_count", &"_d_refcount", &"_d_use_low", &"_d_use_high", &"_d_next_variant",
	&"_d_reserved", &"_r_job_slot", &"_r_job_generation", &"_r_start_cell", &"_r_goal_cell",
	&"_r_clearance", &"_r_start_macro", &"_r_map_revision", &"_r_route_id",
	&"_r_route_generation", &"_r_created_low", &"_r_created_high", &"_r_next_queue",
	&"_r_exact_start", &"_r_anchor", &"_r_expansions", &"_c_start_owner_slot",
	&"_c_start_owner_generation", &"_c_goal_owner_slot", &"_c_goal_owner_generation",
	&"_c_requester_persistent_id",
]

## The seven storage groups a navigation field belongs to. Fields of one group share an extent and
## are held in one packed column block inside `Record`, in ascending slot order.
const GROUP_SCALAR: int = 0
const GROUP_CELL: int = 1
const GROUP_STATE: int = 2
const GROUP_DESCRIPTOR: int = 3
const GROUP_REQUEST: int = 4
const GROUP_HEAP: int = 5
const GROUP_ARENA: int = 6

const NAV_FIELD_GROUP: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 3, 3, 4, 1, 1, 5, 1, 2, 6,
	3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
]

## Each field's index WITHIN its group, which is also its position in that group's packed block.
const NAV_FIELD_SLOT: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
	0, 0, 1, 0, 1, 2, 0, 3, 0, 0,
	2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
	16, 17, 18, 19, 20,
]

## Scalar slots, in declared ordinal order.
const SCALAR_SEARCH_SERIAL: int = 0
const SCALAR_HEAP_SIZE: int = 1
const SCALAR_SEARCH_GOAL: int = 2
const SCALAR_SEARCH_ORIGIN: int = 3
const SCALAR_SEARCH_MACRO: int = 4
const SCALAR_SEARCH_CLEARANCE: int = 5
const SCALAR_EXPANSIONS_REMAINING: int = 6
const SCALAR_EXPANSIONS_TOTAL: int = 7
const SCALAR_ARENA_USED: int = 8
const SCALAR_FREE_REQUEST_HEAD: int = 9
const SCALAR_QUEUE_HEAD: int = 10
const SCALAR_ACTIVE_REQUEST: int = 11
const SCALAR_SERVED_REVISION: int = 12
const SCALAR_COUNT: int = 13

## A* builder columns, in wire order.
const CELL_STAMP: int = 0
const CELL_G: int = 1
const CELL_PARENT: int = 2
const CELL_HEAP_POSITION: int = 3
const CELL_COLUMN_COUNT: int = 4

## Route descriptor columns, in wire order.
const DESC_FLAGS: int = 0
const DESC_GENERATION: int = 1
const DESC_ROUTE_ID: int = 2
const DESC_START_MACRO: int = 3
const DESC_GOAL_CELL: int = 4
const DESC_CLEARANCE: int = 5
const DESC_MAP_REVISION: int = 6
const DESC_VARIANT_START: int = 7
const DESC_ANCHOR: int = 8
const DESC_OFFSET: int = 9
const DESC_COUNT: int = 10
const DESC_REFCOUNT: int = 11
const DESC_USE_LOW: int = 12
const DESC_USE_HIGH: int = 13
const DESC_NEXT_VARIANT: int = 14
const DESC_RESERVED: int = 15
const DESC_COLUMN_COUNT: int = 16

## Path request and contact columns, in wire order.
const REQ_PHASE: int = 0
const REQ_JOB_SLOT: int = 1
const REQ_JOB_GENERATION: int = 2
const REQ_START_CELL: int = 3
const REQ_GOAL_CELL: int = 4
const REQ_CLEARANCE: int = 5
const REQ_START_MACRO: int = 6
const REQ_MAP_REVISION: int = 7
const REQ_ROUTE_ID: int = 8
const REQ_ROUTE_GENERATION: int = 9
const REQ_CREATED_LOW: int = 10
const REQ_CREATED_HIGH: int = 11
const REQ_NEXT_QUEUE: int = 12
const REQ_EXACT_START: int = 13
const REQ_ANCHOR: int = 14
const REQ_EXPANSIONS: int = 15
const REQ_START_OWNER_SLOT: int = 16
const REQ_START_OWNER_GENERATION: int = 17
const REQ_GOAL_OWNER_SLOT: int = 18
const REQ_GOAL_OWNER_GENERATION: int = 19
const REQ_REQUESTER_PERSISTENT_ID: int = 20
const REQ_COLUMN_COUNT: int = 21

# --- byte arithmetic ------------------------------------------------------------------------------

const ELEMENT_COUNT_BYTES: int = 8

## `owner_key_length:u32 + key + owner_schema_version:u32 + primary_count:u64 + payload:u64`.
const WRAPPER_FIXED_BYTES: int = 4 + 4 + 8 + 8
const MOVEMENT_WRAPPER_BYTES: int = WRAPPER_FIXED_BYTES + OWNER_KEY_MOVEMENT_BYTES
const NAVIGATION_WRAPPER_BYTES: int = WRAPPER_FIXED_BYTES + OWNER_KEY_NAVIGATION_BYTES

const MOVEMENT_PAYLOAD_BYTES: int = MOVEMENT_FIELD_COUNT \
	* (ELEMENT_COUNT_BYTES + SaveCodec.I32_BYTES * MOTION_CAPACITY)

## Everything in the navigation payload except the two used prefixes: 13 scalars, 4 cell columns,
## one state column, 16 descriptor columns, 21 request columns, and the two prefix count words.
const NAVIGATION_PAYLOAD_FIXED_BYTES: int = \
	SCALAR_COUNT * (ELEMENT_COUNT_BYTES + SaveCodec.I32_BYTES) \
	+ CELL_COLUMN_COUNT * (ELEMENT_COUNT_BYTES + SaveCodec.I32_BYTES * CELL_COUNT) \
	+ (ELEMENT_COUNT_BYTES + SaveCodec.U8_BYTES * CELL_COUNT) \
	+ DESC_COLUMN_COUNT * (ELEMENT_COUNT_BYTES + SaveCodec.I32_BYTES * ROUTE_DESCRIPTOR_CAPACITY) \
	+ REQ_COLUMN_COUNT * (ELEMENT_COUNT_BYTES + SaveCodec.I32_BYTES * PATH_REQUEST_CAPACITY) \
	+ 2 * ELEMENT_COUNT_BYTES

const NAVIGATION_PAYLOAD_MAX_BYTES: int = NAVIGATION_PAYLOAD_FIXED_BYTES \
	+ SaveCodec.I32_BYTES * (CELL_COUNT + ROUTE_CELL_CAPACITY)

const OFFSET_STORE_COUNT: int = 0
const OFFSET_MOVEMENT_WRAPPER: int = 4
const OFFSET_MOVEMENT_PAYLOAD: int = OFFSET_MOVEMENT_WRAPPER + MOVEMENT_WRAPPER_BYTES
const OFFSET_NAVIGATION_WRAPPER: int = OFFSET_MOVEMENT_PAYLOAD + MOVEMENT_PAYLOAD_BYTES
const OFFSET_NAVIGATION_PAYLOAD: int = OFFSET_NAVIGATION_WRAPPER + NAVIGATION_WRAPPER_BYTES

const SECTION_FIXED_BYTES: int = OFFSET_NAVIGATION_PAYLOAD + NAVIGATION_PAYLOAD_FIXED_BYTES
const SECTION_MAX_BYTES: int = OFFSET_NAVIGATION_PAYLOAD + NAVIGATION_PAYLOAD_MAX_BYTES

## ARCH-SAVE-003: "stream Chronicle and large sections in 65536-byte chunks".
const CHUNK_BYTES: int = 65536

## `save_header.gd`'s endian sentinel, reused as the little-endian probe constant. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

## SAVE-R09 canonical type codes: 0 = u8, 2 = i32.
const CANONICAL_TYPE_U8: int = 0
const CANONICAL_TYPE_I32: int = 2

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BYTE_ORDER: StringName = &"SAVE_NAV_BYTE_ORDER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_NAV_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_NAV_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_NAV_LENGTH"
const REFUSE_RECORD_SHAPE: StringName = &"SAVE_NAV_RECORD_SHAPE"
const REFUSE_STORE_COUNT: StringName = &"SAVE_NAV_STORE_COUNT"
const REFUSE_BLOCK_ORDER: StringName = &"SAVE_NAV_BLOCK_ORDER"
const REFUSE_OWNER_KEY: StringName = &"SAVE_NAV_OWNER_KEY"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_NAV_OWNER_SCHEMA_VERSION"
const REFUSE_ROUTE_SEMANTICS: StringName = &"SAVE_NAV_ROUTE_SEMANTICS"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_NAV_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_NAV_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_NAV_ELEMENT_COUNT"
const REFUSE_FIELD_ORDINAL: StringName = &"SAVE_NAV_FIELD_ORDINAL"
const REFUSE_COLUMN_LENGTH: StringName = &"SAVE_NAV_COLUMN_LENGTH"
const REFUSE_PREFIX_TAIL: StringName = &"SAVE_NAV_PREFIX_TAIL"
const REFUSE_PREFIX_COUNT: StringName = &"SAVE_NAV_PREFIX_COUNT"
const REFUSE_SCALAR_RANGE: StringName = &"SAVE_NAV_SCALAR_RANGE"
const REFUSE_CELL_RANGE: StringName = &"SAVE_NAV_CELL_RANGE"
const REFUSE_STATE_BYTE: StringName = &"SAVE_NAV_STATE_BYTE"
const REFUSE_STAMP_RANGE: StringName = &"SAVE_NAV_STAMP_RANGE"
const REFUSE_HEAP_ENTRY: StringName = &"SAVE_NAV_HEAP_ENTRY"
const REFUSE_HEAP_POSITION: StringName = &"SAVE_NAV_HEAP_POSITION"
const REFUSE_ARENA_ENTRY: StringName = &"SAVE_NAV_ARENA_ENTRY"
const REFUSE_DESCRIPTOR_IDENTITY: StringName = &"SAVE_NAV_DESCRIPTOR_IDENTITY"
const REFUSE_DESCRIPTOR_FLAGS: StringName = &"SAVE_NAV_DESCRIPTOR_FLAGS"
const REFUSE_DESCRIPTOR_GENERATION: StringName = &"SAVE_NAV_DESCRIPTOR_GENERATION"
const REFUSE_DESCRIPTOR_WINDOW: StringName = &"SAVE_NAV_DESCRIPTOR_WINDOW"
const REFUSE_DESCRIPTOR_OVERLAP: StringName = &"SAVE_NAV_DESCRIPTOR_OVERLAP"
const REFUSE_DESCRIPTOR_FREE_STATE: StringName = &"SAVE_NAV_DESCRIPTOR_FREE_STATE"
const REFUSE_DESCRIPTOR_REFCOUNT: StringName = &"SAVE_NAV_DESCRIPTOR_REFCOUNT"
const REFUSE_VARIANT_CHAIN: StringName = &"SAVE_NAV_VARIANT_CHAIN"
const REFUSE_REQUEST_PHASE: StringName = &"SAVE_NAV_REQUEST_PHASE"
const REFUSE_RETIRED_PHASE: StringName = &"SAVE_NAV_RETIRED_PHASE"
const REFUSE_EXACT_START: StringName = &"SAVE_NAV_EXACT_START"
const REFUSE_REQUEST_FIELD: StringName = &"SAVE_NAV_REQUEST_FIELD"
const REFUSE_ROUTE_HOLD: StringName = &"SAVE_NAV_ROUTE_HOLD"
const REFUSE_ROUTE_GENERATION: StringName = &"SAVE_NAV_ROUTE_GENERATION"
const REFUSE_FREE_LIST: StringName = &"SAVE_NAV_FREE_LIST"
const REFUSE_QUEUE_LIST: StringName = &"SAVE_NAV_QUEUE_LIST"
const REFUSE_QUEUE_ORDER: StringName = &"SAVE_NAV_QUEUE_ORDER"
const REFUSE_ACTIVE_REQUEST: StringName = &"SAVE_NAV_ACTIVE_REQUEST"
const REFUSE_CURSOR_FIELD: StringName = &"SAVE_NAV_CURSOR_FIELD"
const REFUSE_CURSOR_IDLE: StringName = &"SAVE_NAV_CURSOR_IDLE"
const REFUSE_CURSOR_EXHAUSTED: StringName = &"SAVE_NAV_CURSOR_EXHAUSTED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_NAV_ENCODE_FAILED"
const REFUSE_STORE_MISMATCH: StringName = &"SAVE_NAV_STORE_MISMATCH"


class Record:
	"""One decoded section 9: both owner blocks, every column allocated once to its declared extent.

	Columns of equal extent share one packed block in declared ordinal order, so a block's memory
	layout IS the wire layout of its fields and every slice is a C++ copy. `heap` and `arena` are
	held at full capacity with only `[0, used)` meaningful; the tail is zero by construction and
	`record_refusal()` refuses it otherwise -- see "The used prefix is persisted" in the header.
	"""
	var movement: PackedInt32Array = PackedInt32Array()
	var scalars: PackedInt32Array = PackedInt32Array()
	var cells: PackedInt32Array = PackedInt32Array()
	var state: PackedByteArray = PackedByteArray()
	var descriptors: PackedInt32Array = PackedInt32Array()
	var requests: PackedInt32Array = PackedInt32Array()
	var heap: PackedInt32Array = PackedInt32Array()
	var arena: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate every block to its declared extent. The only place this class resizes."""
		movement.resize(MOVEMENT_FIELD_COUNT * MOTION_CAPACITY)
		scalars.resize(SCALAR_COUNT)
		cells.resize(CELL_COLUMN_COUNT * CELL_COUNT)
		state.resize(CELL_COUNT)
		descriptors.resize(DESC_COLUMN_COUNT * ROUTE_DESCRIPTOR_CAPACITY)
		requests.resize(REQ_COLUMN_COUNT * PATH_REQUEST_CAPACITY)
		heap.resize(CELL_COUNT)
		arena.resize(ROUTE_CELL_CAPACITY)
		clear()

	func clear() -> void:
		"""Refill with the state `navigation.gd::_init()` and `movement.gd::_allocate_cursors()` leave.

		This is a VALID empty navigator, not merely zeros: descriptor route ids are their own row,
		descriptor generations start at 1, the free request list threads ascending from row 0, and
		`_served_revision` is the first map revision. `record_refusal()` accepts it.
		"""
		movement.fill(0)
		scalars.fill(0)
		cells.fill(0)
		state.fill(0)
		descriptors.fill(0)
		requests.fill(0)
		heap.fill(0)
		arena.fill(0)
		_clear_movement()
		_clear_scalars()
		_clear_descriptors()
		_clear_requests()

	func _clear_movement() -> void:
		"""Every cursor row detached, exactly as `_allocate_cursors()` leaves it."""
		for row: int in MOTION_CAPACITY:
			set_cursor(MOV_REQUEST, row, NO_REQUEST)
			set_cursor(MOV_PROFILE_ID, row, NO_PROFILE)
			set_cursor(MOV_MODE, row, NO_MODE)

	func _clear_scalars() -> void:
		"""No search, no active request, an empty queue and the first map revision."""
		scalars[SCALAR_SEARCH_GOAL] = NO_ROW
		scalars[SCALAR_SEARCH_ORIGIN] = NO_ROW
		scalars[SCALAR_SEARCH_MACRO] = NO_ROW
		scalars[SCALAR_QUEUE_HEAD] = NO_ROW
		scalars[SCALAR_ACTIVE_REQUEST] = NO_ROW
		scalars[SCALAR_FREE_REQUEST_HEAD] = 0
		scalars[SCALAR_SERVED_REVISION] = SpatialWorld.FIRST_MAP_REVISION

	func _clear_descriptors() -> void:
		"""`_allocate_routes()`: route id is the row, generation starts at 1, no variant chain."""
		for row: int in ROUTE_DESCRIPTOR_CAPACITY:
			set_descriptor(DESC_ROUTE_ID, row, row)
			set_descriptor(DESC_GENERATION, row, 1)
			set_descriptor(DESC_NEXT_VARIANT, row, NO_VARIANT)

	func _clear_requests() -> void:
		"""`_allocate_requests()`: every row FREE, holding no route, threaded 0 -> 1 -> ... -> -1."""
		for row: int in PATH_REQUEST_CAPACITY:
			set_request(REQ_PHASE, row, Navigation.PHASE_FREE)
			set_request(REQ_ROUTE_ID, row, NO_ROUTE)
			set_request(REQ_NEXT_QUEUE, row,
				NO_ROW if row == PATH_REQUEST_CAPACITY - 1 else row + 1)

	func scalar(slot: int) -> int:
		"""One navigation scalar by its SCALAR_* slot."""
		return scalars[slot]

	func set_scalar(slot: int, value: int) -> void:
		"""Write one navigation scalar by its SCALAR_* slot."""
		scalars[slot] = value

	func cell(column: int, cell_id: int) -> int:
		"""One A* builder value: `column` is a CELL_* index, `cell_id` a cell in [0, 262144)."""
		return cells[column * CELL_COUNT + cell_id]

	func set_cell(column: int, cell_id: int, value: int) -> void:
		"""Write one A* builder value."""
		cells[column * CELL_COUNT + cell_id] = value

	func descriptor(column: int, row: int) -> int:
		"""One route descriptor value: `column` is a DESC_* index, `row` a descriptor in [0, 256)."""
		return descriptors[column * ROUTE_DESCRIPTOR_CAPACITY + row]

	func set_descriptor(column: int, row: int, value: int) -> void:
		"""Write one route descriptor value."""
		descriptors[column * ROUTE_DESCRIPTOR_CAPACITY + row] = value

	func request(column: int, row: int) -> int:
		"""One path request value: `column` is a REQ_* index, `row` a request in [0, 8192)."""
		return requests[column * PATH_REQUEST_CAPACITY + row]

	func set_request(column: int, row: int, value: int) -> void:
		"""Write one path request value."""
		requests[column * PATH_REQUEST_CAPACITY + row] = value

	func cursor(column: int, row: int) -> int:
		"""One movement cursor value: `column` is a MOV_* index, `row` a motion row in [0, 512)."""
		return movement[column * MOTION_CAPACITY + row]

	func set_cursor(column: int, row: int, value: int) -> void:
		"""Write one movement cursor value."""
		movement[column * MOTION_CAPACITY + row] = value

	func copy_from(other: Record) -> void:
		"""Overwrite all eight blocks from `other`. Eight C++ copies on the cold path, no loop."""
		movement = other.movement.duplicate()
		scalars = other.scalars.duplicate()
		cells = other.cells.duplicate()
		state = other.state.duplicate()
		descriptors = other.descriptors.duplicate()
		requests = other.requests.duplicate()
		heap = other.heap.duplicate()
		arena = other.arena.duplicate()

	func equals(other: Record) -> bool:
		"""True when all eight blocks are byte-identical. Proves a refusal changed nothing."""
		return movement == other.movement and scalars == other.scalars \
			and cells == other.cells and state == other.state \
			and descriptors == other.descriptors and requests == other.requests \
			and heap == other.heap and arena == other.arena


class Derived:
	"""The category-2 members §9 rebuilds instead of writing, and the scratch validation needs.

	`navigation.gd`'s `_live_requests` is the count of non-FREE rows and `_storage_blocked_count`
	is a diagnostic; `movement.gd`'s `_travelling_count` is likewise derived. None is persisted.
	`visited` and `holders` exist so the free-list and queue walks can detect a cycle and so the
	descriptor refcounts can be rebuilt from the requests that actually hold them.
	"""
	var visited: PackedByteArray = PackedByteArray()
	var holders: PackedInt32Array = PackedInt32Array()
	var in_use_rows: PackedInt32Array = PackedInt32Array()
	var live_requests: int = 0
	var free_requests: int = 0
	var queued_requests: int = 0
	var searching_requests: int = 0
	var ready_requests: int = 0
	var descriptors_in_use: int = 0
	var attached_cursors: int = 0

	func _init() -> void:
		"""Allocate the walk mark, the per-descriptor holder count and the in-use list once."""
		visited.resize(PATH_REQUEST_CAPACITY)
		holders.resize(ROUTE_DESCRIPTOR_CAPACITY)
		in_use_rows.resize(ROUTE_DESCRIPTOR_CAPACITY)
		clear()

	func clear() -> void:
		"""Reset to the empty-navigator state: nothing visited, no descriptor held."""
		visited.fill(0)
		holders.fill(0)
		in_use_rows.fill(NO_ROW)
		live_requests = 0
		free_requests = 0
		queued_requests = 0
		searching_requests = 0
		ready_requests = 0
		descriptors_in_use = 0
		attached_cursors = 0


class GroupBuffers:
	"""Decode-time accumulation, one raw byte buffer per storage group.

	Named members rather than an `Array` indexed by group: the seven buffers are statically typed,
	`append()` names the one rule that governs them, and no caller can index past the end. Fields
	of one group arrive in ascending slot order, which is why plain appends rebuild each group
	block in exactly the layout `Record` holds.
	"""
	var scalars: PackedByteArray = PackedByteArray()
	var cells: PackedByteArray = PackedByteArray()
	var state: PackedByteArray = PackedByteArray()
	var descriptors: PackedByteArray = PackedByteArray()
	var requests: PackedByteArray = PackedByteArray()
	var heap: PackedByteArray = PackedByteArray()
	var arena: PackedByteArray = PackedByteArray()

	func append(group: int, bytes: PackedByteArray) -> void:
		"""Append one column's raw bytes to its group's buffer."""
		if group == GROUP_SCALAR:
			scalars.append_array(bytes)
		elif group == GROUP_CELL:
			cells.append_array(bytes)
		elif group == GROUP_STATE:
			state.append_array(bytes)
		elif group == GROUP_DESCRIPTOR:
			descriptors.append_array(bytes)
		elif group == GROUP_REQUEST:
			requests.append_array(bytes)
		elif group == GROUP_HEAP:
			heap.append_array(bytes)
		else:
			arena.append_array(bytes)


class Chunk:
	"""One streamed chunk: at most CHUNK_BYTES of section bytes, or a refusal and no bytes."""
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


class ChunkCursor:
	"""Streams a whole section 9 in chunks of at most CHUNK_BYTES, never materialising it.

	Chunk boundaries are field-aligned: each block's wrapper is one chunk, each field's 8-byte
	`element_count` is one chunk, and a column's values split into whole-element runs. No chunk
	straddles two columns, so a caller folding CRC-32 and SHA-256 over the stream sees exactly the
	bytes `encode_record()` produces, in the same order. The first chunk carries `store_count` and
	the movement wrapper together, because both are fixed and tiny.
	"""
	var _record: Record
	var _wire: int = 0
	var _opened: bool = false
	var _count_done: bool = false
	var _element: int = 0
	var _emitted: int = 0

	func _init(p_record: Record) -> void:
		"""Open a cursor positioned before the first wrapper chunk."""
		_record = p_record

	func has_more() -> bool:
		"""True while any chunk of the section is still unemitted."""
		return _wire < MOVEMENT_FIELD_COUNT + NAV_FIELD_COUNT

	func emitted_bytes() -> int:
		"""Total bytes emitted so far. Equals `section_bytes_of()` once the cursor is drained."""
		return _emitted

	func next_chunk_into(out: Chunk) -> bool:
		"""Emit the next chunk of the section, or refuse past its end."""
		if not has_more():
			return out.refuse(REFUSE_CURSOR_EXHAUSTED,
				"section 9 already emitted all %d bytes" % _emitted)
		if not _opened:
			return _wrapper_into(out)
		if not _count_done:
			return _count_into(out)
		return _values_into(out)

	func _wrapper_into(out: Chunk) -> bool:
		"""Emit the block wrapper that opens the current field's block, if this field opens one."""
		_opened = true
		if _wire != 0 and _wire != MOVEMENT_FIELD_COUNT:
			return next_chunk_into(out)
		var order: SaveHeader.Refusal = SaveSectionNavigationScript.byte_order_refusal()
		if not order.is_ok():
			return out.refuse(order.code, order.detail)
		var bytes: PackedByteArray = \
			SaveSectionNavigationScript.wrapper_bytes_of(_record, _wire)
		if bytes.is_empty():
			return out.refuse(REFUSE_ENCODE_FAILED,
				"the owner wrapper before wire field %d could not be written" % _wire)
		_emitted += bytes.size()
		return out.succeed(bytes)

	func _count_into(out: Chunk) -> bool:
		"""Emit the current field's `element_count:u64`."""
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(ELEMENT_COUNT_BYTES)
		writer.write_u64(SaveSectionNavigationScript.wire_field_count(_record, _wire))
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		_count_done = true
		_element = 0
		_emitted += ELEMENT_COUNT_BYTES
		return out.succeed(writer.to_bytes())

	func _values_into(out: Chunk) -> bool:
		"""Emit the next run of the current column's values, advancing the field when it ends."""
		var total: int = SaveSectionNavigationScript.wire_field_count(_record, _wire)
		var per_chunk: int = CHUNK_BYTES / SaveSectionNavigationScript.wire_field_width(_wire)
		var end: int = mini(_element + per_chunk, total)
		var bytes: PackedByteArray = \
			SaveSectionNavigationScript.wire_field_slice(_record, _wire, _element, end)
		_element = end
		if _element >= total:
			_wire += 1
			_count_done = false
			_opened = false
		_emitted += bytes.size()
		return out.succeed(bytes)


# --- layout arithmetic ----------------------------------------------------------------------------

static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove `PackedInt32Array.to_byte_array()` is little-endian on this build.

	The bulk conversions in `wire_field_slice()` and `decode_into()` are C++ memory copies, not
	`save_codec.gd` writes, so they inherit the host's byte order instead of the codec's explicit
	little-endian. Every Godot target is little-endian, but an unchecked assumption is how a save
	written on one machine silently transposes every cell id on another.
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


static func wire_field_total() -> int:
	"""Number of wire fields across both blocks, in emission order."""
	return MOVEMENT_FIELD_COUNT + NAV_FIELD_COUNT


static func wire_block_of(wire: int) -> int:
	"""Which owner block a wire field belongs to."""
	return BLOCK_MOVEMENT if wire < MOVEMENT_FIELD_COUNT else BLOCK_NAVIGATION


static func wire_field_of(wire: int) -> int:
	"""The declared field ordinal of a wire field within its own block."""
	return wire if wire < MOVEMENT_FIELD_COUNT else wire - MOVEMENT_FIELD_COUNT


static func wire_field_key(wire: int) -> StringName:
	"""The declared canonical field key of a wire field."""
	if wire < MOVEMENT_FIELD_COUNT:
		return MOVEMENT_FIELD_KEYS[wire]
	return NAV_FIELD_KEYS[wire - MOVEMENT_FIELD_COUNT]


static func wire_field_width(wire: int) -> int:
	"""Element width in bytes: 1 for `_state`, 4 for every other §9 column."""
	if wire < MOVEMENT_FIELD_COUNT:
		return SaveCodec.I32_BYTES
	if NAV_FIELD_GROUP[wire - MOVEMENT_FIELD_COUNT] == GROUP_STATE:
		return SaveCodec.U8_BYTES
	return SaveCodec.I32_BYTES


static func canonical_type_of(wire: int) -> int:
	"""SAVE-R09's type code for a wire field: 0 for the u8 column, 2 for the i32 columns."""
	if wire_field_width(wire) == SaveCodec.U8_BYTES:
		return CANONICAL_TYPE_U8
	return CANONICAL_TYPE_I32


static func wire_field_count(record: Record, wire: int) -> int:
	"""Declared element count of a wire field. The two prefix columns read their own count scalar."""
	if wire < MOVEMENT_FIELD_COUNT:
		return MOTION_CAPACITY
	var group: int = NAV_FIELD_GROUP[wire - MOVEMENT_FIELD_COUNT]
	if group == GROUP_SCALAR:
		return 1
	if group == GROUP_CELL or group == GROUP_STATE:
		return CELL_COUNT
	if group == GROUP_DESCRIPTOR:
		return ROUTE_DESCRIPTOR_CAPACITY
	if group == GROUP_REQUEST:
		return PATH_REQUEST_CAPACITY
	if group == GROUP_HEAP:
		return record.scalar(SCALAR_HEAP_SIZE)
	return record.scalar(SCALAR_ARENA_USED)


static func group_stride_of(group: int) -> int:
	"""Elements per COLUMN in one storage group, which is its base multiplier inside the block.

	One for a scalar: the 13 scalar fields are one element each and sit side by side in a
	13-element block, so their stride is 1 while the block is 13 long. Every other group holds one
	full-extent column per field. The two prefix groups keep their full capacity here; only the
	wire count shrinks to the used prefix.
	"""
	if group == GROUP_SCALAR:
		return 1
	if group == GROUP_CELL or group == GROUP_STATE or group == GROUP_HEAP:
		return CELL_COUNT
	if group == GROUP_DESCRIPTOR:
		return ROUTE_DESCRIPTOR_CAPACITY
	if group == GROUP_REQUEST:
		return PATH_REQUEST_CAPACITY
	return ROUTE_CELL_CAPACITY


static func wire_count_offset(record: Record, wire: int) -> int:
	"""Byte offset, from the start of the section, of one wire field's `element_count:u64`.

	Walks every preceding field of the same block, because two navigation fields are variable
	length. Each block's own payload offset is fixed: only the navigation block's length varies and
	it is the last one.
	"""
	var first: int = 0
	var offset: int = OFFSET_MOVEMENT_PAYLOAD
	if wire >= MOVEMENT_FIELD_COUNT:
		first = MOVEMENT_FIELD_COUNT
		offset = OFFSET_NAVIGATION_PAYLOAD
	for earlier: int in range(first, wire):
		offset += ELEMENT_COUNT_BYTES \
			+ wire_field_width(earlier) * wire_field_count(record, earlier)
	return offset


static func wire_value_offset(record: Record, wire: int) -> int:
	"""Byte offset, from the start of the section, of one wire field's first value."""
	return wire_count_offset(record, wire) + ELEMENT_COUNT_BYTES


static func navigation_payload_bytes(heap_size: int, arena_used: int) -> int:
	"""Declared `payload_byte_length` of the navigation block for one pair of prefix counts."""
	return NAVIGATION_PAYLOAD_FIXED_BYTES + SaveCodec.I32_BYTES * (heap_size + arena_used)


static func section_bytes_of(record: Record) -> int:
	"""Total encoded size of one Record: fixed framing plus its two used prefixes."""
	return OFFSET_NAVIGATION_PAYLOAD + navigation_payload_bytes(
		record.scalar(SCALAR_HEAP_SIZE), record.scalar(SCALAR_ARENA_USED))


static func wrapper_bytes_of(record: Record, wire: int) -> PackedByteArray:
	"""The framing that precedes a wire field, or empty when the field is mid-block.

	Wire field 0 carries `store_count` and the movement wrapper; the first navigation field carries
	the navigation wrapper. ASCII key order is structural here: the movement block is emitted first
	because this function emits its wrapper first, and `decode_into()` refuses any other order.
	"""
	if wire == 0:
		return _wrapper_writer(SaveCodec.Writer.new(OFFSET_MOVEMENT_PAYLOAD), OWNER_KEY_MOVEMENT,
			OWNER_SCHEMA_VERSION_MOVEMENT, PRIMARY_COUNT_MOVEMENT, MOVEMENT_PAYLOAD_BYTES, true)
	if wire == MOVEMENT_FIELD_COUNT:
		return _wrapper_writer(SaveCodec.Writer.new(NAVIGATION_WRAPPER_BYTES),
			OWNER_KEY_NAVIGATION, OWNER_SCHEMA_VERSION_NAVIGATION, PRIMARY_COUNT_NAVIGATION,
			navigation_payload_bytes(record.scalar(SCALAR_HEAP_SIZE),
				record.scalar(SCALAR_ARENA_USED)), false)
	return PackedByteArray()


static func _wrapper_writer(writer: SaveCodec.Writer, key: String, version: int,
		primary: int, payload: int, lead_store_count: bool) -> PackedByteArray:
	"""Write one SAVE-LAYOUT-R01 owner wrapper, optionally preceded by the section store count."""
	if lead_store_count:
		writer.write_u32(STORE_COUNT)
	writer.write_utf8_u32(key, OWNER_KEY_MAX_BYTES)
	writer.write_u32(version)
	writer.write_u64(primary)
	writer.write_u64(payload)
	if writer.failed():
		return PackedByteArray()
	return writer.to_bytes()


static func wire_field_slice(record: Record, wire: int, start: int, end: int) -> PackedByteArray:
	"""The little-endian bytes of one column's `[start, end)` values. C++ copies, no loop."""
	if wire < MOVEMENT_FIELD_COUNT:
		var base: int = wire * MOTION_CAPACITY
		return record.movement.slice(base + start, base + end).to_byte_array()
	return _navigation_slice(record, wire - MOVEMENT_FIELD_COUNT, start, end)


static func _navigation_slice(record: Record, field: int, start: int,
		end: int) -> PackedByteArray:
	"""One navigation column's `[start, end)` bytes, from whichever group block holds it."""
	var group: int = NAV_FIELD_GROUP[field]
	var base: int = NAV_FIELD_SLOT[field] * group_stride_of(group)
	if group == GROUP_SCALAR:
		return record.scalars.slice(base + start, base + end).to_byte_array()
	if group == GROUP_CELL:
		return record.cells.slice(base + start, base + end).to_byte_array()
	if group == GROUP_STATE:
		return record.state.slice(start, end)
	if group == GROUP_DESCRIPTOR:
		return record.descriptors.slice(base + start, base + end).to_byte_array()
	if group == GROUP_REQUEST:
		return record.requests.slice(base + start, base + end).to_byte_array()
	if group == GROUP_HEAP:
		return record.heap.slice(start, end).to_byte_array()
	return record.arena.slice(start, end).to_byte_array()


# --- capture -------------------------------------------------------------------------------------

static func set_movement_columns(record: Record, values: PackedInt32Array) -> SaveHeader.Refusal:
	"""Install all nine cursor columns at once, in DECLARED ORDINAL order, field-major.

	`values` is `MOVEMENT_FIELD_COUNT * MOTION_CAPACITY` long: ordinal 0 (`_cursor_owner_id`)
	first, NOT `movement.gd`'s declaration order, which starts at `_cursor_request`.
	"""
	if values.size() != MOVEMENT_FIELD_COUNT * MOTION_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_COLUMN_LENGTH,
			"the movement block needs %d values, got %d"
				% [MOVEMENT_FIELD_COUNT * MOTION_CAPACITY, values.size()])
	record.movement = values.duplicate()
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func set_navigation_column(record: Record, field: int,
		values: PackedInt32Array) -> SaveHeader.Refusal:
	"""Install one full-extent navigation i32 column by its declared ordinal.

	Refuses the two prefix columns and `_state`: those have their own setters, because a prefix
	column's wire length comes from its count scalar and `_state` is a byte column.
	"""
	var ordinal: SaveHeader.Refusal = _navigation_ordinal_refusal(field)
	if not ordinal.is_ok():
		return ordinal
	var group: int = NAV_FIELD_GROUP[field]
	if group == GROUP_STATE or group == GROUP_HEAP or group == GROUP_ARENA:
		return SaveHeader.Refusal.new(REFUSE_FIELD_ORDINAL,
			"field %d (%s) has its own setter" % [field, NAV_FIELD_KEYS[field]])
	var capacity: int = group_stride_of(group)
	if values.size() != capacity:
		return SaveHeader.Refusal.new(REFUSE_COLUMN_LENGTH,
			"field %d (%s) needs %d values, got %d"
				% [field, NAV_FIELD_KEYS[field], capacity, values.size()])
	_install_navigation_values(record, group, NAV_FIELD_SLOT[field] * capacity, values)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _install_navigation_values(record: Record, group: int, base: int,
		values: PackedInt32Array) -> void:
	"""Splice one validated column into its group block: head, new column, tail. Three C++ copies.

	A packed array has no range assignment, and an element-wise loop over a 262144-cell column is
	a quarter of a million GDScript iterations on a path that runs once per column.
	"""
	if group == GROUP_SCALAR:
		record.scalars = _spliced(record.scalars, base, values)
	elif group == GROUP_CELL:
		record.cells = _spliced(record.cells, base, values)
	elif group == GROUP_DESCRIPTOR:
		record.descriptors = _spliced(record.descriptors, base, values)
	else:
		record.requests = _spliced(record.requests, base, values)


static func _spliced(block: PackedInt32Array, base: int,
		values: PackedInt32Array) -> PackedInt32Array:
	"""`block` with `values` replacing `[base, base + values.size())`, same total length."""
	var result: PackedInt32Array = block.slice(0, base)
	result.append_array(values)
	result.append_array(block.slice(base + values.size(), block.size()))
	return result


static func set_navigation_state_column(record: Record,
		values: PackedByteArray) -> SaveHeader.Refusal:
	"""Install `_state` (ordinal 21), the one byte-wide column in section 9."""
	if values.size() != CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_COLUMN_LENGTH,
			"_state needs %d values, got %d" % [CELL_COUNT, values.size()])
	record.state = values.duplicate()
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func set_navigation_prefix_column(record: Record, field: int, values: PackedInt32Array,
		used: int) -> SaveHeader.Refusal:
	"""Install `_heap` or `_arena` AND its count scalar, keeping the used prefix and dropping the tail.

	THIS IS WHERE THE GARBAGE IS DROPPED. A live `_arena` holds evicted route cells past
	`_arena_used` and a live `_heap` holds popped entries past `_heap_size`; both are stale residue
	that two observationally identical worlds can disagree on. `values` is the FULL capacity column
	as the owner holds it; only `[0, used)` survives and the tail is zeroed, so the encoded bytes
	and therefore the CRC depend on observable state alone.
	"""
	var invalid: SaveHeader.Refusal = _prefix_argument_refusal(field, values, used)
	if not invalid.is_ok():
		return invalid
	var group: int = NAV_FIELD_GROUP[field]
	var kept: PackedInt32Array = values.slice(0, used)
	kept.resize(group_stride_of(group))
	if group == GROUP_HEAP:
		record.heap = kept
		record.set_scalar(SCALAR_HEAP_SIZE, used)
	else:
		record.arena = kept
		record.set_scalar(SCALAR_ARENA_USED, used)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _prefix_argument_refusal(field: int, values: PackedInt32Array,
		used: int) -> SaveHeader.Refusal:
	"""Prove a prefix capture names a prefix column, a full-capacity buffer and a legal count."""
	var ordinal: SaveHeader.Refusal = _navigation_ordinal_refusal(field)
	if not ordinal.is_ok():
		return ordinal
	var group: int = NAV_FIELD_GROUP[field]
	if group != GROUP_HEAP and group != GROUP_ARENA:
		return SaveHeader.Refusal.new(REFUSE_FIELD_ORDINAL,
			"field %d (%s) is not a used-prefix column" % [field, NAV_FIELD_KEYS[field]])
	var capacity: int = group_stride_of(group)
	if values.size() != capacity:
		return SaveHeader.Refusal.new(REFUSE_COLUMN_LENGTH,
			"field %d needs %d values, got %d" % [field, capacity, values.size()])
	if used < 0 or used > capacity:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_COUNT,
			"used prefix %d is outside [0, %d]" % [used, capacity])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _navigation_ordinal_refusal(field: int) -> SaveHeader.Refusal:
	"""Prove a declared navigation field ordinal exists before anything indexes the field tables."""
	if field < 0 or field >= NAV_FIELD_COUNT:
		return SaveHeader.Refusal.new(REFUSE_FIELD_ORDINAL,
			"navigation ordinal %d is outside [0, %d)" % [field, NAV_FIELD_COUNT])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole validated section 9 in one buffer, by draining a `ChunkCursor`.

	ARCH-SAVE-003 streams large sections and `ChunkCursor` is that stream; this is the
	concatenation, for a caller that genuinely wants all five megabytes at once -- a pinned
	fixture, the canonical walker, a test. A file writer drives the cursor instead.
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


# --- decode ----------------------------------------------------------------------------------------

static func decode_into(bytes: PackedByteArray, offset: int, out: Record) -> SaveHeader.Refusal:
	"""Decode section 9 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the declared extent is proved readable, both wrappers
	are checked, every column lands in a LOCAL Record, the declared payload length is recomputed
	from the decoded prefix counts, and every cross-column invariant runs against that local. Only
	then is `out` overwritten. A FULL-LENGTH section carrying a retired SEARCHING_LOCAL phase, a
	descriptor window past the arena prefix or a route generation from the wrong namespace
	therefore leaves `out` byte-identical -- validate-then-commit, never commit-then-validate.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return order
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var parsed: Record = Record.new()
	var body: SaveHeader.Refusal = _read_section(bytes, reader, offset, parsed)
	if not body.is_ok():
		return body
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_section(bytes: PackedByteArray, reader: SaveCodec.Reader, offset: int,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read store count, both wrappers and all 66 columns, then prove the section consumed exactly."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 9 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	var movement: SaveHeader.Refusal = _read_movement_block(bytes, reader, parsed)
	if not movement.is_ok():
		return movement
	var navigation: SaveHeader.Refusal = _read_navigation_block(bytes, reader, parsed)
	if not navigation.is_ok():
		return navigation
	var consumed: int = reader.position() - offset
	if consumed != section_bytes_of(parsed):
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 9 consumed %d bytes, not the declared %d"
				% [consumed, section_bytes_of(parsed)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_movement_block(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read the first owner block, refusing any owner but `movement` -- ASCII order is the rule."""
	var owner: SaveHeader.Refusal = _read_owner(reader, OWNER_KEY_MOVEMENT,
		OWNER_SCHEMA_VERSION_MOVEMENT, PRIMARY_COUNT_MOVEMENT, MOVEMENT_PAYLOAD_BYTES,
		SaveCodec.Scalar.new())
	if not owner.is_ok():
		return owner
	var staged: PackedByteArray = PackedByteArray()
	var chunk: Chunk = Chunk.new()
	for wire: int in MOVEMENT_FIELD_COUNT:
		var column: SaveHeader.Refusal = _read_column(bytes, reader, parsed, wire, chunk)
		if not column.is_ok():
			return column
		staged.append_array(chunk.bytes)
	parsed.movement = staged.to_int32_array()
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_navigation_block(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read the second owner block: the version gate, then all 57 columns in ordinal order.

	The declared ordinals make the format self-describing: `_heap_size` is ordinal 1 and
	`_arena_used` is ordinal 8, so both prefix counts are already decoded when `_heap` (19) and
	`_arena` (22) arrive -- which is also what lets the declared `payload_byte_length` be
	recomputed from the body rather than trusted.
	"""
	var declared: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var owner: SaveHeader.Refusal = _read_navigation_owner(reader, declared)
	if not owner.is_ok():
		return owner
	var groups: GroupBuffers = GroupBuffers.new()
	var chunk: Chunk = Chunk.new()
	for field: int in NAV_FIELD_COUNT:
		var column: SaveHeader.Refusal = _read_column(bytes, reader, parsed,
			MOVEMENT_FIELD_COUNT + field, chunk)
		if not column.is_ok():
			return column
		groups.append(NAV_FIELD_GROUP[field], chunk.bytes)
		if field == SCALAR_ARENA_USED:
			parsed.scalars = groups.scalars.to_int32_array()
	var installed: SaveHeader.Refusal = _install_groups(parsed, groups)
	if not installed.is_ok():
		return installed
	return _declared_length_refusal(parsed, declared.value)


static func _declared_length_refusal(parsed: Record, declared: int) -> SaveHeader.Refusal:
	"""Compare the navigation block's declared payload length with the body it just described."""
	var body: int = navigation_payload_bytes(parsed.scalar(SCALAR_HEAP_SIZE),
		parsed.scalar(SCALAR_ARENA_USED))
	if declared != body:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			("the navigation block declares %d payload bytes; its own _heap_size %d and "
				+ "_arena_used %d make it %d") % [declared,
					parsed.scalar(SCALAR_HEAP_SIZE), parsed.scalar(SCALAR_ARENA_USED), body])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _install_groups(parsed: Record, groups: GroupBuffers) -> SaveHeader.Refusal:
	"""Reinterpret each accumulated group buffer, padding the two used prefixes back to capacity.

	`resize()` on a packed array zero-fills the entries it adds, which is exactly the tail
	`set_navigation_prefix_column()` wrote and `_prefix_refusal()` requires: the residue past
	`_heap_size` and `_arena_used` never existed on the wire and does not come back.
	"""
	parsed.scalars = groups.scalars.to_int32_array()
	parsed.cells = groups.cells.to_int32_array()
	parsed.state = groups.state
	parsed.descriptors = groups.descriptors.to_int32_array()
	parsed.requests = groups.requests.to_int32_array()
	var heap: PackedByteArray = groups.heap
	heap.resize(SaveCodec.I32_BYTES * CELL_COUNT)
	parsed.heap = heap.to_int32_array()
	var arena: PackedByteArray = groups.arena
	arena.resize(SaveCodec.I32_BYTES * ROUTE_CELL_CAPACITY)
	parsed.arena = arena.to_int32_array()
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_column(bytes: PackedByteArray, reader: SaveCodec.Reader, parsed: Record,
		wire: int, out: Chunk) -> SaveHeader.Refusal:
	"""Read one field's `element_count:u64` and its value run, leaving the raw bytes in `out`."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var expected: int = wire_field_count(parsed, wire)
	if scalar.value != expected:
		return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
			"field %s declares %d elements, not %d"
				% [wire_field_key(wire), scalar.value, expected])
	var start: int = reader.position()
	var end: int = start + wire_field_width(wire) * expected
	if end > bytes.size():
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"field %s needs bytes up to %d, buffer holds %d"
				% [wire_field_key(wire), end, bytes.size()])
	out.succeed(bytes.slice(start, end))
	if not reader.seek(end):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_owner(reader: SaveCodec.Reader, key: String, version: int, primary: int,
		payload: int, declared: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read and check one owner wrapper, leaving its declared payload length in `declared`.

	`payload` is the length this schema requires, or -1 for a block whose length depends on values
	inside its own payload. The navigation block is that case, and its caller compares `declared`
	with the recomputed length once the prefix counts are decoded.
	"""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != key:
		return SaveHeader.Refusal.new(REFUSE_BLOCK_ORDER,
			("section 9 block is owned by '%s', not '%s'. Blocks are in ASCII key order: "
				+ "'movement' then 'navigation'.") % [text.value, key])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != version:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner '%s' schema %d is not the supported %d" % [key, scalar.value, version])
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != primary:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"owner '%s' primary_count %d is not the declared %d" % [key, scalar.value, primary])
	return _read_payload_length(reader, key, payload, declared)


static func _read_payload_length(reader: SaveCodec.Reader, key: String, payload: int,
		declared: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read one block's `payload_byte_length` and compare it with the length this schema requires."""
	if not reader.read_u64_into(declared):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if payload >= 0 and declared.value != payload:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' declares a %d-byte payload, not %d" % [key, declared.value, payload])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_navigation_owner(reader: SaveCodec.Reader,
		declared: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read the navigation wrapper, gating the schema version through PATH-R02's semantics check.

	The declared payload length is read here and cross-checked in `_read_section()` against the
	length recomputed from the decoded `_heap_size` and `_arena_used`, because those two scalars
	are inside the payload this length describes.
	"""
	var owner: SaveHeader.Refusal = _read_owner(reader, OWNER_KEY_NAVIGATION,
		OWNER_SCHEMA_VERSION_NAVIGATION, PRIMARY_COUNT_NAVIGATION, -1, declared)
	if not owner.is_ok():
		return owner
	var semantics: StringName = Navigation.refuse_route_semantics(OWNER_SCHEMA_VERSION_NAVIGATION)
	if semantics != Navigation.REFUSE_NONE:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_SEMANTICS,
			("this schema encodes route semantics %d and navigation.gd now publishes %d: %s. "
				+ "There is no migration; PATH-R02 forbids reinterpreting a stored route.")
				% [OWNER_SCHEMA_VERSION_NAVIGATION, Navigation.route_semantics_version(),
					semantics])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove the whole declared section is readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_rng.gd::extent_refusal()` and `save_section_directory.gd::extent_refusal()` are.
	Section 9's length is not fixed -- it grows with the two used prefixes -- so this reads the
	navigation block's declared `payload_byte_length`, bounds it against the compiled capacities,
	and only then proves the total fits. H4: bounds are checked before allocation.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < SECTION_FIXED_BYTES or offset > bytes.size() - SECTION_FIXED_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 9 needs at least %d bytes at offset %d, buffer holds %d"
				% [SECTION_FIXED_BYTES, offset, bytes.size()])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.read_u64_at(bytes,
			offset + OFFSET_NAVIGATION_PAYLOAD - ELEMENT_COUNT_BYTES, scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, scalar.detail)
	if scalar.value < NAVIGATION_PAYLOAD_FIXED_BYTES \
			or scalar.value > NAVIGATION_PAYLOAD_MAX_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"the navigation block declares %d payload bytes, outside [%d, %d]"
				% [scalar.value, NAVIGATION_PAYLOAD_FIXED_BYTES, NAVIGATION_PAYLOAD_MAX_BYTES])
	var total: int = OFFSET_NAVIGATION_PAYLOAD + scalar.value
	if offset > bytes.size() - total:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 9 declares %d bytes at offset %d, buffer holds %d"
				% [total, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func section_length_refusal(byte_length: int,
		record: Record) -> SaveHeader.Refusal:
	"""Check a descriptor's declared section length against what this Record encodes to.

	SAVE-R09-004 requires exact block consumption and no trailing bytes. Section 9's length is a
	function of the two used prefixes, so the comparison needs the Record, not a constant.
	"""
	if byte_length != section_bytes_of(record):
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 9 declares %d bytes, not the %d this state encodes to"
				% [byte_length, section_bytes_of(record)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func descriptor_row_count() -> int:
	"""The 64-byte save DESCRIPTOR's `row_count` for section 9: the declared navigation primary."""
	return PRIMARY_COUNT_NAVIGATION


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 9 rule, checked by rebuilding the derived counters and discarding them."""
	return rebuild_into(record, Derived.new())


static func rebuild_into(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Validate a Record and rebuild every category-2 counter from it.

	`out` is scratch, cleared on entry, and its contents are meaningless unless the returned
	Refusal is ok -- unlike a decoded Record, which decision 0059 requires to stay byte-identical
	through a refusal.
	"""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	out.clear()
	var scalars: SaveHeader.Refusal = _scalar_refusal(record)
	if not scalars.is_ok():
		return scalars
	var builder: SaveHeader.Refusal = _builder_refusal(record)
	if not builder.is_ok():
		return builder
	var routes: SaveHeader.Refusal = _descriptor_refusal(record, out)
	if not routes.is_ok():
		return routes
	var requests: SaveHeader.Refusal = _request_refusal(record, out)
	if not requests.is_ok():
		return requests
	return _cursor_refusal(record, out)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every block must be exactly its declared length before anything indexes into it."""
	var sizes: Array[int] = [record.movement.size(), record.scalars.size(), record.cells.size(),
		record.state.size(), record.descriptors.size(), record.requests.size(),
		record.heap.size(), record.arena.size()]
	var wanted: Array[int] = [MOVEMENT_FIELD_COUNT * MOTION_CAPACITY, SCALAR_COUNT,
		CELL_COLUMN_COUNT * CELL_COUNT, CELL_COUNT,
		DESC_COLUMN_COUNT * ROUTE_DESCRIPTOR_CAPACITY, REQ_COLUMN_COUNT * PATH_REQUEST_CAPACITY,
		CELL_COUNT, ROUTE_CELL_CAPACITY]
	for index: int in sizes.size():
		if sizes[index] != wanted[index]:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"block %d holds %d values, not %d" % [index, sizes[index], wanted[index]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _scalar_refusal(record: Record) -> SaveHeader.Refusal:
	"""Bound every navigation scalar, and both used prefixes against their capacities."""
	var bounded: Array[int] = [SCALAR_SEARCH_SERIAL, SCALAR_EXPANSIONS_TOTAL,
		SCALAR_EXPANSIONS_REMAINING, SCALAR_SEARCH_CLEARANCE]
	for slot: int in bounded:
		if record.scalar(slot) < 0:
			return SaveHeader.Refusal.new(REFUSE_SCALAR_RANGE,
				"%s is %d; it can never be negative"
					% [NAV_FIELD_KEYS[slot], record.scalar(slot)])
	if record.scalar(SCALAR_EXPANSIONS_REMAINING) > Navigation.EXPANSION_QUOTA_PER_TICK:
		return SaveHeader.Refusal.new(REFUSE_SCALAR_RANGE,
			"_expansions_remaining %d exceeds the %d-expansion tick quota"
				% [record.scalar(SCALAR_EXPANSIONS_REMAINING),
					Navigation.EXPANSION_QUOTA_PER_TICK])
	if record.scalar(SCALAR_SERVED_REVISION) < SpatialWorld.FIRST_MAP_REVISION:
		return SaveHeader.Refusal.new(REFUSE_SCALAR_RANGE,
			"_served_revision %d is below the first map revision %d"
				% [record.scalar(SCALAR_SERVED_REVISION), SpatialWorld.FIRST_MAP_REVISION])
	var prefixes: SaveHeader.Refusal = _prefix_refusal(record)
	if not prefixes.is_ok():
		return prefixes
	return _search_scalar_refusal(record)


static func _prefix_refusal(record: Record) -> SaveHeader.Refusal:
	"""Both used prefixes lie inside their capacity AND their tails are zero, not stale garbage."""
	var heap_size: int = record.scalar(SCALAR_HEAP_SIZE)
	if heap_size < 0 or heap_size > CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_COUNT,
			"_heap_size %d is outside [0, %d]" % [heap_size, CELL_COUNT])
	var arena_used: int = record.scalar(SCALAR_ARENA_USED)
	if arena_used < 0 or arena_used > ROUTE_CELL_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_COUNT,
			"_arena_used %d is outside [0, %d]" % [arena_used, ROUTE_CELL_CAPACITY])
	if record.heap.slice(heap_size, CELL_COUNT).count(0) != CELL_COUNT - heap_size:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_TAIL,
			"_heap holds nonzero residue past its %d-entry used prefix" % heap_size)
	if record.arena.slice(arena_used, ROUTE_CELL_CAPACITY).count(0) \
			!= ROUTE_CELL_CAPACITY - arena_used:
		return SaveHeader.Refusal.new(REFUSE_PREFIX_TAIL,
			"_arena holds nonzero residue past its %d-cell used prefix" % arena_used)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _search_scalar_refusal(record: Record) -> SaveHeader.Refusal:
	"""The active search's identity: three optional cells, and an idle builder that is really idle."""
	for slot: int in [SCALAR_SEARCH_GOAL, SCALAR_SEARCH_ORIGIN]:
		var value: int = record.scalar(slot)
		if value != NO_ROW and not SpatialWorld.is_cell(value):
			return SaveHeader.Refusal.new(REFUSE_SCALAR_RANGE,
				"%s is %d, neither a cell nor -1" % [NAV_FIELD_KEYS[slot], value])
	var macro_id: int = record.scalar(SCALAR_SEARCH_MACRO)
	if macro_id != NO_ROW and (macro_id < 0 or macro_id >= SpatialWorld.MACRO_COUNT):
		return SaveHeader.Refusal.new(REFUSE_SCALAR_RANGE,
			"_search_macro %d is neither a macro cell nor -1" % macro_id)
	var active: int = record.scalar(SCALAR_ACTIVE_REQUEST)
	if active != NO_ROW and (active < 0 or active >= PATH_REQUEST_CAPACITY):
		return SaveHeader.Refusal.new(REFUSE_ACTIVE_REQUEST,
			"_active_request %d is neither a request row nor -1" % active)
	if active == NO_ROW and record.scalar(SCALAR_HEAP_SIZE) != 0:
		return SaveHeader.Refusal.new(REFUSE_ACTIVE_REQUEST,
			("no request holds the builder but the heap has %d entries; "
				+ "_abandon_active_search() empties it")
				% record.scalar(SCALAR_HEAP_SIZE))
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _builder_refusal(record: Record) -> SaveHeader.Refusal:
	"""The A* builder: cell-column domains, then the heap's indexed-min-heap invariant.

	The domain checks sort a copy of each column rather than walking 262144 values in GDScript:
	the sort is one C++ call and only the extremes matter. This is also the int32 sign-trap guard
	-- bytes `00 00 00 80` read signed are -2147483648, which no stamp or g-score can be.
	"""
	if record.state.count(Navigation.STATE_UNTOUCHED) + record.state.count(Navigation.STATE_OPEN) \
			+ record.state.count(Navigation.STATE_CLOSED) != CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STATE_BYTE,
			"_state holds a byte outside {0, 1, 2}")
	var serial: int = record.scalar(SCALAR_SEARCH_SERIAL)
	var stamps: SaveHeader.Refusal = _column_range_refusal(record, CELL_STAMP, 0, serial,
		REFUSE_STAMP_RANGE)
	if not stamps.is_ok():
		return stamps
	var costs: SaveHeader.Refusal = _column_range_refusal(record, CELL_G, 0, MAX_INT32,
		REFUSE_CELL_RANGE)
	if not costs.is_ok():
		return costs
	var parents: SaveHeader.Refusal = _column_range_refusal(record, CELL_PARENT, NO_ROW,
		CELL_COUNT - 1, REFUSE_CELL_RANGE)
	if not parents.is_ok():
		return parents
	var positions: SaveHeader.Refusal = _column_range_refusal(record, CELL_HEAP_POSITION, NO_ROW,
		CELL_COUNT - 1, REFUSE_CELL_RANGE)
	if not positions.is_ok():
		return positions
	return _heap_refusal(record)


static func _column_range_refusal(record: Record, column: int, low: int, high: int,
		code: StringName) -> SaveHeader.Refusal:
	"""Prove one A* builder column lies inside `[low, high]`, by sorting a copy of it."""
	var base: int = column * CELL_COUNT
	var sorted: PackedInt32Array = record.cells.slice(base, base + CELL_COUNT)
	sorted.sort()
	if sorted[0] < low or sorted[CELL_COUNT - 1] > high:
		return SaveHeader.Refusal.new(code,
			"cell column %d spans [%d, %d], outside [%d, %d]"
				% [column, sorted[0], sorted[CELL_COUNT - 1], low, high])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _heap_refusal(record: Record) -> SaveHeader.Refusal:
	"""`_heap_position[_heap[i]] == i` for every used entry, and every entry is open and stamped.

	The position map is what makes the heap indexed: `_heap_swap()` maintains it on every move and
	`_heap_pop()` sets the removed cell's position to -1. A restored heap whose positions disagree
	would sift the wrong cell and silently return a non-shortest path.
	"""
	var serial: int = record.scalar(SCALAR_SEARCH_SERIAL)
	for index: int in record.scalar(SCALAR_HEAP_SIZE):
		var cell_id: int = record.heap[index]
		if not SpatialWorld.is_cell(cell_id):
			return SaveHeader.Refusal.new(REFUSE_HEAP_ENTRY,
				"heap slot %d holds %d, which is not a cell" % [index, cell_id])
		if record.cell(CELL_HEAP_POSITION, cell_id) != index:
			return SaveHeader.Refusal.new(REFUSE_HEAP_POSITION,
				"cell %d sits at heap slot %d but records position %d"
					% [cell_id, index, record.cell(CELL_HEAP_POSITION, cell_id)])
		if record.cell(CELL_STAMP, cell_id) != serial:
			return SaveHeader.Refusal.new(REFUSE_HEAP_ENTRY,
				"heap cell %d carries stamp %d, not the current search serial %d"
					% [cell_id, record.cell(CELL_STAMP, cell_id), serial])
		if record.state[cell_id] != Navigation.STATE_OPEN:
			return SaveHeader.Refusal.new(REFUSE_HEAP_ENTRY,
				"heap cell %d is in state %d, not STATE_OPEN"
					% [cell_id, record.state[cell_id]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _descriptor_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Every route descriptor: identity, flags, ROUTE generation, and its arena window."""
	for row: int in ROUTE_DESCRIPTOR_CAPACITY:
		var invalid: SaveHeader.Refusal = _one_descriptor_refusal(record, out, row)
		if not invalid.is_ok():
			return invalid
	var overlap: SaveHeader.Refusal = _window_overlap_refusal(record, out)
	if not overlap.is_ok():
		return overlap
	return _arena_value_refusal(record)


static func _one_descriptor_refusal(record: Record, out: Derived,
		row: int) -> SaveHeader.Refusal:
	"""One descriptor's identity, flags and generation, and its window when it is in use."""
	if record.descriptor(DESC_ROUTE_ID, row) != row:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_IDENTITY,
			"descriptor %d carries route id %d; _allocate_routes() sets it to its own row"
				% [row, record.descriptor(DESC_ROUTE_ID, row)])
	var flags: int = record.descriptor(DESC_FLAGS, row)
	if flags != 0 and flags != Navigation.FLAG_IN_USE and flags != Navigation.FLAG_RETIRED:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_FLAGS,
			"descriptor %d holds flags %d, outside {0, %d, %d}"
				% [row, flags, Navigation.FLAG_IN_USE, Navigation.FLAG_RETIRED])
	var generation: int = record.descriptor(DESC_GENERATION, row)
	if generation < 1:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_GENERATION,
			("descriptor %d holds route generation %d; _allocate_routes() starts them at 1 and "
				+ "_free_descriptor() only ever raises them") % [row, generation])
	if flags == Navigation.FLAG_RETIRED and generation < MAX_INT32 - 1:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_GENERATION,
			"descriptor %d is retired at route generation %d, not the spent %d"
				% [row, generation, MAX_INT32 - 1])
	if flags != Navigation.FLAG_IN_USE:
		return _free_descriptor_refusal(record, row)
	out.in_use_rows[out.descriptors_in_use] = row
	out.descriptors_in_use += 1
	return _window_refusal(record, row)


static func _free_descriptor_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""A descriptor that holds no route holds no window, no reference and no variant link."""
	if record.descriptor(DESC_COUNT, row) != 0 or record.descriptor(DESC_OFFSET, row) != 0:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_FREE_STATE,
			"free descriptor %d still claims arena [%d, +%d); _free_descriptor() zeroes both"
				% [row, record.descriptor(DESC_OFFSET, row), record.descriptor(DESC_COUNT, row)])
	if record.descriptor(DESC_REFCOUNT, row) != 0:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_FREE_STATE,
			"free descriptor %d holds %d references"
				% [row, record.descriptor(DESC_REFCOUNT, row)])
	if record.descriptor(DESC_NEXT_VARIANT, row) != NO_VARIANT:
		return SaveHeader.Refusal.new(REFUSE_VARIANT_CHAIN,
			"free descriptor %d still links variant %d"
				% [row, record.descriptor(DESC_NEXT_VARIANT, row)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _window_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""An in-use descriptor's `[offset, offset+count)` lies inside the restored arena used prefix.

	Task 09's acceptance requires "fully referenced route arenas". A window past `_arena_used`
	would read cells the load never restored, which is why the prefix and the windows are checked
	against each other rather than either alone.
	"""
	var offset: int = record.descriptor(DESC_OFFSET, row)
	var count: int = record.descriptor(DESC_COUNT, row)
	var used: int = record.scalar(SCALAR_ARENA_USED)
	if count < 1 or count > CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_WINDOW,
			"in-use descriptor %d holds %d cells; _store_route() never stores an empty route"
				% [row, count])
	if offset < 0 or offset > used - count:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_WINDOW,
			"descriptor %d claims arena [%d, %d) outside the %d-cell used prefix"
				% [row, offset, offset + count, used])
	if record.descriptor(DESC_REFCOUNT, row) < 0:
		return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_REFCOUNT,
			"descriptor %d holds %d references" % [row, record.descriptor(DESC_REFCOUNT, row)])
	var variant: int = record.descriptor(DESC_NEXT_VARIANT, row)
	if variant != NO_VARIANT and (variant < 0 or variant >= ROUTE_DESCRIPTOR_CAPACITY):
		return SaveHeader.Refusal.new(REFUSE_VARIANT_CHAIN,
			"descriptor %d links variant %d, which is not a descriptor" % [row, variant])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _window_overlap_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""No two live route blocks share an arena cell. `_acquire_arena()` hands out disjoint runs.

	Walks only the descriptors `_one_descriptor_refusal()` found in use, so the pairwise cost is
	the number of stored routes and not the 256-row capacity.
	"""
	for first: int in out.descriptors_in_use:
		var left: int = out.in_use_rows[first]
		var left_start: int = record.descriptor(DESC_OFFSET, left)
		var left_end: int = left_start + record.descriptor(DESC_COUNT, left)
		for second: int in range(first + 1, out.descriptors_in_use):
			var right: int = out.in_use_rows[second]
			var right_start: int = record.descriptor(DESC_OFFSET, right)
			var right_end: int = right_start + record.descriptor(DESC_COUNT, right)
			if left_start < right_end and right_start < left_end:
				return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_OVERLAP,
					"descriptors %d [%d, %d) and %d [%d, %d) share arena cells"
						% [left, left_start, left_end, right, right_start, right_end])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _arena_value_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every cell inside the arena used prefix is a real cell index."""
	var used: int = record.scalar(SCALAR_ARENA_USED)
	if used == 0:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	var sorted: PackedInt32Array = record.arena.slice(0, used)
	sorted.sort()
	if sorted[0] < 0 or sorted[used - 1] >= CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_ARENA_ENTRY,
			"the arena used prefix spans [%d, %d], outside [0, %d)"
				% [sorted[0], sorted[used - 1], CELL_COUNT])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _request_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Every path request row, then the free list, the pending queue and the descriptor refcounts."""
	var exact: SaveHeader.Refusal = _exact_start_refusal(record)
	if not exact.is_ok():
		return exact
	for row: int in PATH_REQUEST_CAPACITY:
		var invalid: SaveHeader.Refusal = _one_request_refusal(record, out, row)
		if not invalid.is_ok():
			return invalid
	var active: SaveHeader.Refusal = _active_request_refusal(record, out)
	if not active.is_ok():
		return active
	var refcounts: SaveHeader.Refusal = _refcount_refusal(record, out)
	if not refcounts.is_ok():
		return refcounts
	var free_list: SaveHeader.Refusal = _free_list_refusal(record, out)
	if not free_list.is_ok():
		return free_list
	return _queue_refusal(record, out)


static func _exact_start_refusal(record: Record) -> SaveHeader.Refusal:
	"""PATH-R02: `_r_start_cell` equals `_r_exact_start` in every row, so both columns agree.

	ARCH-MEM-008 names both, so a §9 writer persists both; PATH-R02 removed the only stage that
	could make them differ, so the payload proves it rather than asserting it in a comment. One
	C++ comparison of two 8192-element column slices.
	"""
	var start: PackedInt32Array = record.requests.slice(REQ_START_CELL * PATH_REQUEST_CAPACITY,
		(REQ_START_CELL + 1) * PATH_REQUEST_CAPACITY)
	var exact: PackedInt32Array = record.requests.slice(REQ_EXACT_START * PATH_REQUEST_CAPACITY,
		(REQ_EXACT_START + 1) * PATH_REQUEST_CAPACITY)
	if start != exact:
		return SaveHeader.Refusal.new(REFUSE_EXACT_START,
			("_r_start_cell and _r_exact_start disagree. PATH-R02 makes every route begin at its "
				+ "requester's exact start; an anchor-rewritten origin is version 1 state."))
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _one_request_refusal(record: Record, out: Derived, row: int) -> SaveHeader.Refusal:
	"""One request row: its phase, its route hold and the ROUTE generation that hold carries."""
	var phase: int = record.request(REQ_PHASE, row)
	if phase < 0 or phase >= Navigation.PHASE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_REQUEST_PHASE,
			"request %d holds phase %d, outside [0, %d)" % [row, phase, Navigation.PHASE_COUNT])
	if phase == Navigation.PHASE_SEARCHING_LOCAL:
		return SaveHeader.Refusal.new(REFUSE_RETIRED_PHASE,
			("request %d is in PHASE_SEARCHING_LOCAL, retired by PATH-R02. The constant keeps its "
				+ "slot so version 1 bytes decode to what they meant; this version refuses them.")
				% row)
	if phase == Navigation.PHASE_FREE:
		out.free_requests += 1
	else:
		out.live_requests += 1
	if phase == Navigation.PHASE_QUEUED:
		out.queued_requests += 1
	if phase == Navigation.PHASE_SEARCHING_FULL or phase == Navigation.PHASE_SEARCHING_VARIANT:
		out.searching_requests += 1
	var bounded: SaveHeader.Refusal = _request_field_refusal(record, row, phase)
	if not bounded.is_ok():
		return bounded
	return _route_hold_refusal(record, out, row, phase)


static func _request_field_refusal(record: Record, row: int, phase: int) -> SaveHeader.Refusal:
	"""Domain bounds for one request's cells, clearance, queue link and expansion spend."""
	var link: int = record.request(REQ_NEXT_QUEUE, row)
	if link != NO_ROW and (link < 0 or link >= PATH_REQUEST_CAPACITY):
		return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
			"request %d links to %d, which is not a request row" % [row, link])
	if record.request(REQ_EXPANSIONS, row) < 0:
		return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
			"request %d has spent %d expansions" % [row, record.request(REQ_EXPANSIONS, row)])
	for column: int in [REQ_CREATED_LOW, REQ_CREATED_HIGH]:
		if record.request(column, row) < 0:
			return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
				("request %d holds a negative created-tick half %d; both halves are stored "
					+ "nonnegative so no int32 truncates a set high bit")
					% [row, record.request(column, row)])
	if phase == Navigation.PHASE_FREE:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	return _live_request_field_refusal(record, row)


static func _live_request_field_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""An allocated request names real cells, a contracted clearance class and a real macro."""
	for column: int in [REQ_START_CELL, REQ_GOAL_CELL, REQ_EXACT_START]:
		if not SpatialWorld.is_cell(record.request(column, row)):
			return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
				"request %d holds %d in column %d, which is not a cell"
					% [row, record.request(column, row), column])
	var clearance: int = record.request(REQ_CLEARANCE, row)
	if clearance < SpatialWorld.MIN_CLEARANCE_CLASS \
			or clearance > SpatialWorld.MAX_CLEARANCE_CLASS:
		return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
			"request %d holds clearance class %d, outside [%d, %d]"
				% [row, clearance, SpatialWorld.MIN_CLEARANCE_CLASS,
					SpatialWorld.MAX_CLEARANCE_CLASS])
	var macro_id: int = record.request(REQ_START_MACRO, row)
	if macro_id < 0 or macro_id >= SpatialWorld.MACRO_COUNT:
		return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
			"request %d starts in macro %d, outside [0, %d)"
				% [row, macro_id, SpatialWorld.MACRO_COUNT])
	if record.request(REQ_MAP_REVISION, row) < SpatialWorld.FIRST_MAP_REVISION:
		return SaveHeader.Refusal.new(REFUSE_REQUEST_FIELD,
			"request %d was minted against map revision %d"
				% [row, record.request(REQ_MAP_REVISION, row)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _route_hold_refusal(record: Record, out: Derived, row: int,
		phase: int) -> SaveHeader.Refusal:
	"""A request holds a route exactly while it is READY, at THAT DESCRIPTOR'S ROUTE GENERATION.

	`_r_route_generation` is a ROUTE-DESCRIPTOR generation and is compared with `_d_generation`
	and nothing else. `_r_job_generation` is a DIRECTORY slot generation from the requester's
	`EntityRef`; comparing the hold against it would accept a request whose two unrelated numbers
	happen to match and would republish an evicted route to a live holder.
	"""
	var route: int = record.request(REQ_ROUTE_ID, row)
	if route == NO_ROUTE:
		return _unheld_route_refusal(record, row, phase)
	if phase != Navigation.PHASE_READY:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_HOLD,
			("request %d is in phase %d and still references route %d; _settle_request() drops "
				+ "the reference exactly once") % [row, phase, route])
	if route < 0 or route >= ROUTE_DESCRIPTOR_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_HOLD,
			"request %d references route %d, which is not a descriptor" % [row, route])
	if record.descriptor(DESC_FLAGS, route) != Navigation.FLAG_IN_USE:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_HOLD,
			"request %d is READY on descriptor %d, which holds no route" % [row, route])
	if record.request(REQ_ROUTE_GENERATION, row) != record.descriptor(DESC_GENERATION, route):
		return SaveHeader.Refusal.new(REFUSE_ROUTE_GENERATION,
			"request %d holds route generation %d; descriptor %d is at %d"
				% [row, record.request(REQ_ROUTE_GENERATION, row), route,
					record.descriptor(DESC_GENERATION, route)])
	out.ready_requests += 1
	out.holders[route] += 1
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _unheld_route_refusal(record: Record, row: int, phase: int) -> SaveHeader.Refusal:
	"""A request that references no route: it cannot be READY, and it carries no route generation."""
	if phase == Navigation.PHASE_READY:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_HOLD,
			"request %d is READY and references no route" % row)
	if record.request(REQ_ROUTE_GENERATION, row) != 0:
		return SaveHeader.Refusal.new(REFUSE_ROUTE_GENERATION,
			"request %d holds no route but carries route generation %d"
				% [row, record.request(REQ_ROUTE_GENERATION, row)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _active_request_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""At most one request holds the shared builder, and it is the one the scalar names."""
	var active: int = record.scalar(SCALAR_ACTIVE_REQUEST)
	if active == NO_ROW:
		if out.searching_requests != 0:
			return SaveHeader.Refusal.new(REFUSE_ACTIVE_REQUEST,
				"%d requests are mid-search but none holds the builder" % out.searching_requests)
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	if out.searching_requests != 1:
		return SaveHeader.Refusal.new(REFUSE_ACTIVE_REQUEST,
			"request %d holds the builder but %d requests are mid-search"
				% [active, out.searching_requests])
	var phase: int = record.request(REQ_PHASE, active)
	if phase != Navigation.PHASE_SEARCHING_FULL and phase != Navigation.PHASE_SEARCHING_VARIANT:
		return SaveHeader.Refusal.new(REFUSE_ACTIVE_REQUEST,
			"request %d holds the builder in phase %d" % [active, phase])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _refcount_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Every descriptor's refcount equals the number of READY requests that actually hold it.

	ARCH-PATH-005 will not evict a referenced route, so a refcount restored too high pins a route
	forever and one restored too low lets a live holder's route be evicted underneath it.
	"""
	for row: int in ROUTE_DESCRIPTOR_CAPACITY:
		if record.descriptor(DESC_REFCOUNT, row) != out.holders[row]:
			return SaveHeader.Refusal.new(REFUSE_DESCRIPTOR_REFCOUNT,
				"descriptor %d records %d references; %d READY requests hold it"
					% [row, record.descriptor(DESC_REFCOUNT, row), out.holders[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _free_list_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""The free request list threads exactly the FREE rows, once each, with no cycle."""
	var walked: int = 0
	var cursor: int = record.scalar(SCALAR_FREE_REQUEST_HEAD)
	while cursor != NO_ROW:
		if cursor < 0 or cursor >= PATH_REQUEST_CAPACITY:
			return SaveHeader.Refusal.new(REFUSE_FREE_LIST,
				"the free list reaches %d, which is not a request row" % cursor)
		if out.visited[cursor] != 0:
			return SaveHeader.Refusal.new(REFUSE_FREE_LIST,
				"the free list revisits request %d; it is a cycle, not a list" % cursor)
		if record.request(REQ_PHASE, cursor) != Navigation.PHASE_FREE:
			return SaveHeader.Refusal.new(REFUSE_FREE_LIST,
				"the free list holds request %d, which is in phase %d"
					% [cursor, record.request(REQ_PHASE, cursor)])
		out.visited[cursor] = 1
		walked += 1
		cursor = record.request(REQ_NEXT_QUEUE, cursor)
	if walked != out.free_requests:
		return SaveHeader.Refusal.new(REFUSE_FREE_LIST,
			"the free list holds %d rows but %d requests are FREE" % [walked, out.free_requests])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _queue_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""The pending queue threads exactly the QUEUED rows, in `_enqueue()`'s service order.

	ORDER IS STATE. `_enqueue()` keeps the list sorted by requester persistent id, then request
	generation, then row, so the per-tick service loop never sorts -- which means a queue restored
	in a different order services a different request first and diverges the whole world.
	"""
	var walked: int = 0
	var previous: int = NO_ROW
	var cursor: int = record.scalar(SCALAR_QUEUE_HEAD)
	while cursor != NO_ROW:
		var step: SaveHeader.Refusal = _queue_step_refusal(record, out, cursor, previous)
		if not step.is_ok():
			return step
		out.visited[cursor] = 1
		walked += 1
		previous = cursor
		cursor = record.request(REQ_NEXT_QUEUE, cursor)
	if walked != out.queued_requests:
		return SaveHeader.Refusal.new(REFUSE_QUEUE_LIST,
			"the pending queue holds %d rows but %d requests are QUEUED"
				% [walked, out.queued_requests])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _queue_step_refusal(record: Record, out: Derived, cursor: int,
		previous: int) -> SaveHeader.Refusal:
	"""One queue link: a real QUEUED row, not already walked, and not out of service order."""
	if cursor < 0 or cursor >= PATH_REQUEST_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_QUEUE_LIST,
			"the pending queue reaches %d, which is not a request row" % cursor)
	if out.visited[cursor] != 0:
		return SaveHeader.Refusal.new(REFUSE_QUEUE_LIST,
			"request %d is on both the free list and the pending queue, or twice on one" % cursor)
	if record.request(REQ_PHASE, cursor) != Navigation.PHASE_QUEUED:
		return SaveHeader.Refusal.new(REFUSE_QUEUE_LIST,
			"the pending queue holds request %d, which is in phase %d"
				% [cursor, record.request(REQ_PHASE, cursor)])
	if previous != NO_ROW and not _queue_precedes(record, previous, cursor):
		return SaveHeader.Refusal.new(REFUSE_QUEUE_ORDER,
			"request %d precedes %d in the stored queue but not in _enqueue()'s order"
				% [previous, cursor])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _queue_precedes(record: Record, left: int, right: int) -> bool:
	"""`navigation.gd::_queue_precedes()`: requester persistent id, then generation, then row."""
	var left_id: int = record.request(REQ_REQUESTER_PERSISTENT_ID, left)
	var right_id: int = record.request(REQ_REQUESTER_PERSISTENT_ID, right)
	if left_id != right_id:
		return left_id < right_id
	var left_generation: int = record.request(REQ_JOB_GENERATION, left)
	var right_generation: int = record.request(REQ_JOB_GENERATION, right)
	if left_generation != right_generation:
		return left_generation < right_generation
	return left < right


static func _cursor_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Every movement route cursor: detached rows carry the full null tuple, attached rows are real."""
	for row: int in MOTION_CAPACITY:
		var request: int = record.cursor(MOV_REQUEST, row)
		if request == NO_REQUEST:
			var idle: SaveHeader.Refusal = _idle_cursor_refusal(record, row)
			if not idle.is_ok():
				return idle
			continue
		if request < 0 or request >= PATH_REQUEST_CAPACITY:
			return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
				"motion row %d follows request %d, which is not a request row" % [row, request])
		var attached: SaveHeader.Refusal = _attached_cursor_refusal(record, row)
		if not attached.is_ok():
			return attached
		out.attached_cursors += 1
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _idle_cursor_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""A row following no route carries `stop()`'s exact null tuple, not residue.

	`movement.gd` writes all nine columns together in `_allocate_cursors()` and `stop()`, so a
	detached row that still carries a route generation or a committed load is corruption -- and it
	is the shape a load could quietly produce by restoring only the columns it recognised.
	"""
	var nulls: Array[int] = [NO_OWNER_ID, NO_REQUEST, 0, 0, NO_PROFILE, 0, NO_MODE, 0, 0]
	for column: int in MOVEMENT_FIELD_COUNT:
		if record.cursor(column, row) != nulls[column]:
			return SaveHeader.Refusal.new(REFUSE_CURSOR_IDLE,
				"detached motion row %d holds %s = %d, not the null %d"
					% [row, MOVEMENT_FIELD_KEYS[column], record.cursor(column, row),
						nulls[column]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _attached_cursor_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""An attached cursor's admission terms, including the ROUTE generation it was admitted on.

	The cursor is NOT required to match a live descriptor: `_settle()` leaves a cursor in place
	when a body arrives or loses its route, and `_route_still_valid()` is what compares the stored
	route generation with the descriptor's. Restoring a stale cursor is correct; restoring one
	whose own fields contradict each other is not.
	"""
	if record.cursor(MOV_ROUTE_GENERATION, row) < 1:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d carries route generation %d; descriptors start at 1"
				% [row, record.cursor(MOV_ROUTE_GENERATION, row)])
	if record.cursor(MOV_INDEX, row) < 0 or record.cursor(MOV_INDEX, row) >= CELL_COUNT:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d sits at route index %d"
				% [row, record.cursor(MOV_INDEX, row)])
	if record.cursor(MOV_OWNER_ID, row) < 1:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			("attached motion row %d carries owner persistent id %d; a successor in the same "
				+ "typed row would inherit its route") % [row, record.cursor(MOV_OWNER_ID, row)])
	var profile: int = record.cursor(MOV_PROFILE_ID, row)
	if profile < 0 or profile >= MovementScript.PROFILE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d was admitted under profile %d" % [row, profile])
	if record.cursor(MOV_PROFILE_REVISION, row) < MovementScript.PROFILE_FIRST_REVISION:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d was admitted at profile revision %d"
				% [row, record.cursor(MOV_PROFILE_REVISION, row)])
	return _attached_cursor_terms_refusal(record, row)


static func _attached_cursor_terms_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""The remaining admission terms: traversal mode, committed load and destination revision."""
	var mode: int = record.cursor(MOV_MODE, row)
	if mode < 0 or mode >= MovementScript.MODE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d was admitted in mode %d, outside [0, %d)"
				% [row, mode, MovementScript.MODE_COUNT])
	if record.cursor(MOV_LOAD_G, row) < 0:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d committed a load of %d g"
				% [row, record.cursor(MOV_LOAD_G, row)])
	if record.cursor(MOV_DESTINATION_REVISION, row) < SpatialWorld.FIRST_DESTINATION_REVISION:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_FIELD,
			"attached motion row %d holds destination revision %d, below the first %d"
				% [row, record.cursor(MOV_DESTINATION_REVISION, row),
					SpatialWorld.FIRST_DESTINATION_REVISION])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- verification against a live store --------------------------------------------------------------

static func agrees_with_navigation(record: Record, store: Navigation) -> SaveHeader.Refusal:
	"""Verify a decoded Record against a live navigator, as far as the PUBLIC readers allow.

	BLOCKER N1 bounds this: `navigation.gd` publishes no bulk column reader, so the scalars it
	exposes, every descriptor's generation, variant key and reference count, and every request's
	phase are all that can be compared. `_g`, `_parent`, `_stamp`, `_heap`, `_arena` and the
	request columns are unreachable from outside the module and are covered instead by an
	encode/decode/re-encode round trip.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	var scalars: SaveHeader.Refusal = _store_scalar_refusal(record, store)
	if not scalars.is_ok():
		return scalars
	var routes: SaveHeader.Refusal = _store_descriptor_refusal(record, store)
	if not routes.is_ok():
		return routes
	return _store_phase_refusal(record, store)


static func _store_scalar_refusal(record: Record, store: Navigation) -> SaveHeader.Refusal:
	"""Compare the navigation scalars the module publishes with the Record's."""
	var names: Array[StringName] = [&"_arena_used", &"_served_revision", &"_expansions_total",
		&"_expansions_remaining", &"_active_request"]
	var live: Array[int] = [store.arena_used(), store.served_revision(), store.total_expansions(),
		store.expansions_remaining_this_tick(), store.active_request_row()]
	var slots: Array[int] = [SCALAR_ARENA_USED, SCALAR_SERVED_REVISION, SCALAR_EXPANSIONS_TOTAL,
		SCALAR_EXPANSIONS_REMAINING, SCALAR_ACTIVE_REQUEST]
	for index: int in slots.size():
		if live[index] != record.scalar(slots[index]):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"%s is %d in the navigator, %d in the record"
					% [names[index], live[index], record.scalar(slots[index])])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _store_descriptor_refusal(record: Record, store: Navigation) -> SaveHeader.Refusal:
	"""Compare every descriptor's ROUTE generation, variant key and reference count."""
	for row: int in ROUTE_DESCRIPTOR_CAPACITY:
		if store.route_generation_of(row) != record.descriptor(DESC_GENERATION, row):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"descriptor %d is at route generation %d in the navigator, %d in the record"
					% [row, store.route_generation_of(row),
						record.descriptor(DESC_GENERATION, row)])
		if store.route_variant_start(row) != record.descriptor(DESC_VARIANT_START, row):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"descriptor %d keys variant start %d in the navigator, %d in the record"
					% [row, store.route_variant_start(row),
						record.descriptor(DESC_VARIANT_START, row)])
		if store.route_reference_count(row) != record.descriptor(DESC_REFCOUNT, row):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"descriptor %d holds %d references in the navigator, %d in the record"
					% [row, store.route_reference_count(row),
						record.descriptor(DESC_REFCOUNT, row)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _store_phase_refusal(record: Record, store: Navigation) -> SaveHeader.Refusal:
	"""Compare every request's phase, plus the two counts the navigator derives from them."""
	for row: int in PATH_REQUEST_CAPACITY:
		if store.request_phase(row) != record.request(REQ_PHASE, row):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"request %d is in phase %d in the navigator, %d in the record"
					% [row, store.request_phase(row), record.request(REQ_PHASE, row)])
	var derived: Derived = Derived.new()
	var invalid: SaveHeader.Refusal = rebuild_into(record, derived)
	if not invalid.is_ok():
		return invalid
	if store.live_request_count() != derived.live_requests:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"the navigator holds %d live requests, the record %d"
				% [store.live_request_count(), derived.live_requests])
	if store.queued_count() != derived.queued_requests:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"the navigator queues %d requests, the record %d"
				% [store.queued_count(), derived.queued_requests])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
