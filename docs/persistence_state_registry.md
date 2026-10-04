# Persistence: the future-affecting-state registry

Task 09.1. One row per store per column group, for every module under
`godot/scripts/core/`. This registry now includes the implemented section codecs
and restore helpers; complete save orchestration remains unfinished. The rows
classify state ownership. Owning contracts and versioned codecs define its wire format.

Enforced by [`docs/validation/state_registry_coverage.py`](validation/state_registry_coverage.py),
which reads the packed columns straight out of the GDScript and fails when a
store has no row, a row names a column that no longer exists, a width disagrees
with the declared type, or a count stops quoting the module's own `resize()`
expression. `tools/run_tests.sh` runs it, so a new store that lands without a row
fails the build rather than being forgotten. What that script cannot check is
recorded in [decision 0062](decisions/0062-the-future-affecting-state-registry.md).

## G1–G3 resolution — 2026-09-11

[Decision 0063](decisions/0063-save-classification-naming-and-responsive-ui.md)
resolves the command-result and reachability rows and makes required persisted
host metadata explicit. Read [the addendum](rulings/2026-09-11_ready07_save_ui_addendum.md)
for digest membership, distinct reference namespaces and remaining integration tests.
The original gap report in decision 0062 remains historical, not current instruction.

## What the columns mean

**Store file** is the `###` heading. **Members** are the exact `var` names, so
the check is mechanical. **Width B** is the element width of the declared packed
type: `PackedByteArray` 1, `PackedInt32Array` 4, `PackedInt64Array` 8,
`PackedStringArray` variable. **Count** quotes the module's own `resize()`
argument with `=` for a value that resolves from `const` declarations, `<=` for
one clamped to a constant by a constructor argument, and `runtime` for one that
is neither. **Null / unused** is how absence is spelled in that column — this is
where a loader gets it wrong. **Cat** is the classification below.
**ARCH-SAVE-002** is the section the row belongs to, `--` when it is not saved.

## The three categories

1. **Required persisted state.** Includes future-affecting simulation state and
   explicitly required host-continuation/evidence metadata (ARCH-SAVE-007).
   Canonical hash membership is separately governed by ARCH-HASH-001 and row notes.
   Omitting future-affecting state makes a reloaded world
   diverge from an uninterrupted one. Packed authoritative columns, allocator
   generations and retirement, RNG state and draw counts, pending commands and
   scheduler events, clocks, leases and claims, child arena indexes, cargo and
   work in progress.
2. **Derived; must be rebuilt on load, never written.** Reconstructible from
   category 1. Writing it creates two sources of truth that can disagree.
   ARCH-SAVE-002 already mandates the rebuild for active lists, and permits it
   for allocator heaps; ARCH-HASH-001 excludes "derived spatial/active indexes".
3. **Transient presentation, diagnostic, or compile-time state; not saved.**
   Explicitly required historical clock metadata belongs to category 1 with a
   hash exclusion, not a prose exception to this category (decision 0063).

**UNRESOLVED** is used where the answer is a contract question, never a guess.
Each UNRESOLVED row states its question in Notes; the checker requires that.
ARCH-SAVE-006's next-tick parity test (fork at tick 3000, compare every tick to
18000) is the eventual arbiter for any row where category 1 versus 2 is a
judgement about reconstructibility rather than about a document.

## Two rules this registry applies, and where they come from

**Owning persistence/field contracts decide classification, not allocation alone.**
Decision 0063 corrects the original rule recorded in decision 0062: memory
accounting includes transient output and derived indexes too. Explicitly persisted
fields remain stored/cross-checked as required; this correction does not silently
reclassify other existing rows. GDD InventoryContainer.reachable is explicitly
modeled state and has no reconstruction owner today.

**Section assignment is this registry's reading, not a quotation.**
ARCH-SAVE-002 fixes fifteen section IDs and their order but does not enumerate
their contents. The reading used here: §1 WORLD for world-singleton scalars and
tile-indexed maps (§2's `World`, `WorldPolicy`, `WorldRuntime`, `WorldTileMaps`
rows); §2 CATALOG_IDS for catalog-derived tables; §3 for `entity_directory.gd`;
§4 COMPONENT_COLUMNS for per-entity typed-store columns; §5 CHILD_ARENAS for
owner-to-children arenas with explicit lengths; §6 AUXILIARY_STATE for
orchestration latches and the intent ledger; §7 for inventory, reservations and
gear claims; §8 JOB_INDEXES for the planner's ledgers and the job ordering index;
§9 for navigation and route cursors; §10 for RNG; §12 for both command queues.
§14 NAME_POOL has exactly one member, `residents.gd`'s `_name_key`.
**§11 EVENT_SCHEDULE, §13 CHRONICLE and §15 STATE_DIGEST have no owning module at
all yet**: no timed-event store, no Chronicle and no digest writer exists. The
scheduler queue is in §12 and not in §11 because
`docs/planning/ready07_scheduler_contract.md:116-124` puts it there as the
`SCHQ0001` extension to PENDING_COMMANDS. 09.2 confirms or corrects all of this.

## The generation asymmetry, stated once

`entity_directory.gd` holds the authoritative `_generation` **on the directory
slot**. Every typed store's `_ref_slot`/`_ref_generation` pair is a *copy*. A
load that restored only live slots' generations, or that reset them, would hand
the next `create()` a `(slot, generation)` pair that an `EntityRef` taken before
the save still holds — the aliasing the generation counter exists to prevent.
ARCH-SAVE-002 already requires "all generations including free/retired slots";
this registry says where they live so that requirement can be obeyed.

It is not the only generation space. **`inventory.gd` allocates its own slots**
and carries `_c_generation`/`_l_generation` independently of the directory, even
though ARCH-ID-001 gives `inventory_container` and `inventory_lot` directory
kinds — its own header records this at lines 69-72. **`navigation.gd`** has a
third, `_d_generation`, with its own `FLAG_RETIRED` rule, which `movement.gd`'s
route cursor validates against. `gear.gd` and `reservations.gd` rows have **no
generation of their own at all** and are addressed by row index, so those rows
must be written in row order and must not be compacted on load. Three generation
spaces and two index-addressed stores; 09.2 must not merge them.

## Blocked, and what each needs

Two things in this repository are explicitly blocked on the absent save module.
Neither needs new state.

* **`scheduler_events.gd`'s `SCHQ0001` subsection.** `encode_extension_into()`
  and `restore_extension()` implement it in full, with validation, and nothing
  calls them. It needs 09.2's §12 writer to emit tag `SCHQ0001`,
  `schema_version` 1, payload length `32 + 32*count`, the canonical `head = 0`
  control header, then `count` records in queue order — and a second process to
  read them back.
* **`resource_catalog_binding.gd`'s save/reload round trip.** Its header records
  that "generate a world, save it, reload it, prove the bound ids survive" cannot
  be exercised. It needs 09.2's §2 decode to call `verify_ids()` on the restored
  request against the artifact the header hash pins.

## Registry

### `godot/scripts/core/building_definitions.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| BuildingDefinition facts (i32) | `_b_footprint_x`, `_b_footprint_z`, `_b_slots`, `_b_room_tiles`, `_b_unlock`, `_b_passive_slots`, `_b_max_builders` | 4 | `BUILDING_DEFINITION_COUNT` = 30 | None on a compiled row: every one of the thirty keys has a `gameplay_balance.md` §4.1/§4.2 row, and `_assert_key_sets()` refuses construction otherwise | 2 | §2 CATALOG_IDS | IMMUTABLE CATALOG, NOT SIMULATION STATE. Transcribed from §4.1/§4.2 and placed at the id `Catalog.BUILDING_DEFINITION` assigns, so a reload recompiles them from the artifact whose digest the save header pins at offset 72. `_b_unlock` is a protected Milestone id (BAL-CAT-002, R-BUILD-DOM-001), never a threshold. |
| BuildingDefinition facts (i64) | `_b_work_mwu`, `_b_base_store_g` | 8 | `BUILDING_DEFINITION_COUNT` = 30 | 0 is a real value here: BAL-CAT-007 gives hall, residence and infirmary `base_store_g=0` on purpose | 2 | §2 CATALOG_IDS | Milli-WU and grams; int64 because `work_mwu` reaches 2400000 and `base_store_g` 1500000 and both are summed by callers. See the first row of this group. |
| BuildingDefinition facts (u8) | `_b_managed_interior`, `_b_tier_two_allowed` | 1 | `BUILDING_DEFINITION_COUNT` = 30 | 0 is "no managed interior" / "tier 2 refused" | 2 | §2 CATALOG_IDS | §4.1's managed_interior as a bit, and BAL-CAT-006's "Only residence, hall, covered_store, and workshop accept the GDD tier-2 packages" as a bit. See the first row of this group. |
| Building Station providers | `_b_station` | 4 | `BUILDING_DEFINITION_COUNT` = 30 | `-1` (GDD §4.2's empty catalog id) means this definition provides no service; 0 is `brewery` | 2 | §2 CATALOG_IDS | R-BUILD-DOM-002's explicit provider mapping. A STATION id, never a BuildingDefinition id: eight keys are spelled identically in the two domains and none of the eleven carries the same number in both, so a wrong-domain integer here cannot be caught by a range check. Rebuilt by key lookup through both compiled catalogs. |
| FurnitureDefinition facts (i32) | `_f_floor_x`, `_f_floor_z`, `_f_user_slots` | 4 | `FURNITURE_DEFINITION_COUNT` = 9 | `0/0` floor is §4.3's own "0/0 means edge placement", not an absent row | 2 | §2 CATALOG_IDS | `gameplay_balance.md` §4.3, placed at the id `Catalog.FURNITURE_DEFINITION` assigns. Same reload argument as the building rows. |
| FurnitureDefinition facts (i64) | `_f_work_mwu` | 8 | `FURNITURE_DEFINITION_COUNT` = 9 | None on a compiled row | 2 | §2 CATALOG_IDS | Milli-WU for one furniture instance. See the first row of this group. |
| Furniture Station providers | `_f_station`, `_f_station_slots` | 4 | `FURNITURE_DEFINITION_COUNT` = 9 | `-1` means this kind provides no service, and its slot count is then 0 | 2 | §2 CATALOG_IDS | BAL-CAT-011's second kitchen provider: `kitchen_bench` supplies service 3 at one slot per instance, and R-BUILD-DOM-002's "Each 2x1 bench is one furniture instance, not two slots" is why the count is 1 rather than its footprint. |
| Catalog counts | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_building_count`, `_furniture_count`, `_station_count`: the compiled domain sizes, re-read from `catalog.gd` on construction and cross-checked against `BUILDING_DEFINITION_COUNT`/`FURNITURE_DEFINITION_COUNT`. |

### `godot/scripts/core/buildings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Building columns | `_b_type_id`, `_b_tier`, `_b_origin_tile`, `_b_rotation`, `_b_state`, `_b_condition`, `_b_construction_slot`, `_b_construction_generation`, `_b_interior_id` | 4 | `BUILDING_CAPACITY` = 1024 | `_b_construction_slot == -1` with generation 0 is the null ref; `_b_interior_id == -1` is GDD §4.2's empty catalog id | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's Building row verbatim, and `systems_architecture.md` §2.2's nine-column I32 group at 1024 rows. `_b_condition`'s SCALE IS UNSTATED -- no document gives a building maximum, damage rate or repair threshold -- so the store validates non-negativity only and a loader must not clamp it to an invented ceiling. |
| Building occupancy | `_b_present` | 1 | `BUILDING_CAPACITY` = 1024 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset; what says a row is free, exactly as `resource_nodes.gd`'s `_present` does. |
| Building identity and room chain head | `_b_ref_slot`, `_b_ref_generation`, `_b_room_head`, `_b_room_count` | 4 | `BUILDING_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref; `_b_room_head == -1` means no rooms | 1 | §5 CHILD_ARENAS | The directory reference copy plus the head of this building's intrusive room chain and its length. The count enforces GDD §4.2's "Up to 16 rooms/managed building"; the head is re-derivable in ascending row order, but `rooms_of_building()` returns chain order and a caller choosing "the first room" would observe it, so the conservative reading writes it. |
| Room columns | `_r_type`, `_r_building_slot`, `_r_building_generation`, `_r_tile_offset`, `_r_tile_count`, `_r_temperature_tenths`, `_r_furniture_mask`, `_r_occupants` | 4 | `ROOM_CAPACITY` = 16384 | `_r_building_slot == -1` with generation 0 is the null ref; `_r_tile_count == 0` is refused by surface `designate_room()`; actual underground rooms have no flat links and use the explicit spatial-kind discriminator | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's Room row, and §2.2's eight-column I32 group at 16384. `_r_furniture_mask` is R-BUILD-DOM-003's presence summary, bit i for FurnitureDefinition i, known mask 511; on load it is RECOMPUTED from the staged furniture rows and compared by `verify_room_masks()`, which refuses a mismatch rather than repairing it. |
| Room validity and occupancy | `_r_valid`, `_r_present` | 1 | `ROOM_CAPACITY` = 16384 | `_r_present == 0` is a free row; `_r_valid == 0` is "not validated", which is also every new room's value | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's `valid: bool` and §2.2's separate B8 Room row, plus the occupancy bitset. `_r_valid` has no deterministic rebuild owner today: §5.9's validity list mixes countable rules with topology that no module evaluates, so it is written rather than derived. |
| Room spatial domain | `_r_spatial_kind` | 1 | `ROOM_CAPACITY` = 16384 | SURFACE=0; UNDERGROUND=1; free rows 0 | 1 | §6 AUXILIARY_STATE | Decisions 1069/1071. Mandatory Buildings extension loaded atomically with its existing Room/Furniture state. Actual underground Room identities have a null exterior parent and no ground TileLinks. The discriminator is authoritative and requires a versioned composed codec; legacy capture refuses it. |
| Room identity and chains | `_r_ref_slot`, `_r_ref_generation`, `_r_building_next`, `_r_building_prev`, `_r_furniture_head`, `_r_furniture_count` | 4 | `ROOM_CAPACITY` = 16384 | `-1` slot with generation 0 is the null ref; `-1` in any link is a chain end | 1 | §5 CHILD_ARENAS | The directory reference copy, this room's links in its building's chain, and the head/length of its own furniture chain. `_r_furniture_count` is the bound `_recompute_mask_row()` walks, which is how R-BUILD-DOM-003's "recompute from the owning bounded rows" avoids a per-room nine-counter arena. |
| Furniture columns | `_f_type_id`, `_f_room_slot`, `_f_room_generation`, `_f_origin_tile`, `_f_rotation`, `_f_user_slot`, `_f_user_generation`, `_f_condition` | 4 | `FURNITURE_CAPACITY` = 81920 | `_f_user_slot == -1` with generation 0 means unoccupied; `_f_room_slot` is never null on a live row | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's Furniture row and §2.2's eight-column I32 group at 81920. `_f_room_generation` is the ROOM's directory generation, and it is what makes a reused room slot unable to inherit the previous room's mask bits. An installed damaged row still contributes its presence bit; pending installation does not, and usability is a separate check. |
| Furniture occupancy | `_f_present` | 1 | `FURNITURE_CAPACITY` = 81920 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| Furniture installation | `_f_installed` | 1 | `FURNITURE_CAPACITY` = 81920 | Pending/free 0; installed 1 | 1 | §6 AUXILIARY_STATE | Decisions 1069/1071. Mandatory Buildings extension loaded atomically with its existing Room/Furniture state. Pending actual identities reserve membership and Directory capacity but supply no presence mask, user, kind count or service. Legacy live surface rows initialize to installed; an unknown flag refuses legacy load. |
| Furniture identity and room chain | `_f_ref_slot`, `_f_ref_generation`, `_f_room_next`, `_f_room_prev` | 4 | `FURNITURE_CAPACITY` = 81920 | `-1` slot with generation 0 is the null ref; `-1` in either link is a chain end | 1 | §5 CHILD_ARENAS | The directory reference copy and this row's links in its room's intrusive chain. Same conservative reading as the room chain: the mask is order-independent because OR is commutative, but `furniture_rows_in_room()` exposes the order. |
| Tile ownership maps | `_building_slot`, `_room_slot`, `_furniture_slot` | 4 | `TILE_COUNT` = 16384 | `-1` for a tile with no building / no room / no floor furniture | 1 | §1 WORLD | `WorldTileMaps.building_slot` and `.room_slot` in §3's ledger, which `resource_nodes.gd` deliberately left to "the stores that will" own them. `_furniture_slot` is a THIRD tile map with no existing ledger row: GDD §5.9's "furniture cannot overlap" needs a per-tile occupant and `WorldTileMaps` has only four columns. All three are inverses of a stored column (`_b_origin_tile`, the room tile run, `_f_origin_tile`), so a loader cross-checks rather than choosing one. |
| RoomTileLinks arena | `_room_tile_id` | 4 | `ROOM_TILE_LINK_CAPACITY` = 16384 | `-1` outside `[0, _room_tile_used)`; a live room's run is `[tile_offset, tile_offset + tile_count)` | 1 | §5 CHILD_ARENAS | `RoomTileLinks.tile_id` in §3's ledger: GDD §5.9's "One tile belongs to exactly one room". Runs are bump-allocated and the arena is COMPACTED on room removal, which rewrites every later room's `_r_tile_offset` in the same call -- so offsets are only meaningful together with this arena and the two must be written as a pair. |
| Per-kind furniture counters | `_f_kind_count` | 4 | `FURNITURE_KIND_COUNT` = 9 | 0 means no installed row of that kind anywhere | 2 | §4 COMPONENT_COLUMNS | Nine totals so a HUD bed counter costs a lookup instead of an 81920-row scan. Exactly recomputable from `_f_present`, `_f_installed` and `_f_type_id`, so writing it would create a second source of truth for a number the rows already state. |
| Store counts and collaborators | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_b_live_count`, `_r_live_count`, `_f_live_count` are recomputed from the three occupancy bitsets and `_room_tile_used` from the live rooms' runs. `_directory`, `_owns_directory` and `_definitions` are wiring: the shared allocator, the construction flag, and the immutable catalog facts, all re-bound on load. |
| Spatial owner wiring and diagnostic image | -- | -- | -- | No bound authority | 3 | -- | Decision 1069. `_spatial_authority` is a once-bound weak exact-object bridge, never serialized. `spatial_state_bytes()` allocates a cold caller-owned 98304-byte image of the two authoritative flags. The legacy codec refuses spatial/pending/unknown flags and retained non-surface furniture; it never omits them. UG16 owns versioned composed capture/restore and rebind validation. |

### `godot/scripts/core/canonical_state_hash.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| §15 canonical field walker | -- | -- | -- | -- | 3 | -- | Holds no module-level `var` beyond `_production`, the once-built `Declaration` cached from the generated table. That table is REG-R01's checked-in declaration compiled from `planning/canonical_state_registry.json`: build-time constant data, not simulation state, so losing it on reload changes no outcome. Its packed columns live inside `Declaration` and total **12436 fixed bytes** (61 owners x 4 x i32 =976;764 fields x3 x u8 =2292;764 x i64 declared counts =6112;764 x i32 UTF-8 caps =3056) plus **11137 bytes** of key text in two `PackedStringArray`s -- **23573 logical bytes resident**, built once and never resized. Decision1072 reconciles this current census; native container/String/object costs remain separately reserved and unmeasured. Decision 0167 reconciles the actual listed-field census, including eight non-hash records, and accounts for a prior 179-byte ledger omission plus that repair's 44-byte declaration append; decision 0531 appends `_c_anchor_tile` for 29 more (15 fixed + 14 key bytes); the table is compiled by `tools/generate_canonical_state_table.py` and is never hand-edited. The 65536-byte `Emitter` chunk is per-walk scratch allocated in its `_init`, not a resident column. The module WRITES §15 -- exactly 32 raw SHA-256 bytes over SAVE-R09's RWL-STATE-1 stream -- but owns none of the state it hashes: every value arrives from the owning store's adapter, and a declared owner with no adapter refuses (`CANONICAL_NO_ADAPTER`) instead of hashing a subset. ARCH-SAVE-007's "a memory allocation row alone does not make a field persisted or canonical" applies in both directions here. See [decision 0127](decisions/0127-the-canonical-field-walker-refuses-what-it-cannot-hash.md). |

### `godot/scripts/core/catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Compiled enum domains | -- | -- | -- | -- | 3 | -- | Holds no `var` at all: fifteen protected enum tables and `ITEM_DEFINITION_MAX_KEYS` compiled from lexicographically sorted ASCII keys (GDD §4.2 closing paragraph). Nothing here changes at runtime, so nothing here is saved. The catalog's identity reaches the file as the header's catalog hash at offset 72, produced by `catalog_ids.gd`. |

### `godot/scripts/core/catalog_ids.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Canonical catalog artifact and digest | -- | -- | -- | -- | 1 | §2 CATALOG_IDS | Also stateless: `encode_section_payload()` and the SHA-256 it digests are recomputed from the compiled domains and `godot/data/catalog_ids.json` every call (decision 0034 compares the artifact as bytes). Future-affecting because ARCH-SAVE-004 rejects a file whose catalog hash does not match, so the id a save wrote still means the same key. |

### `godot/scripts/core/command_dispatch.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Command result ledger, envelope | `_result_execute_tick` | 8 | `RESULT_CAPACITY` = 4096 | Rows outside `[0, _result_count)` from `_result_write` are stale prior rows, not zeroed | 3 | -- | Decision 0063 / ARCH-SAVE-007: completed outcomes are transient; omit from save and canonical hash. Empty result ring/cursors on load; do not erase restored source-intent identity. `_result_store_code` shares this classification. |
| Command result ledger, fields | `_result_sequence_low`, `_result_sequence_high`, `_result_kind`, `_result_code`, `_result_value`, `_result_target_slot`, `_result_target_generation` | 4 | `RESULT_CAPACITY` = 4096 | Same ring rule as the row above | 3 | -- | Decision 0063 / ARCH-SAVE-007: completed outcomes are transient; omit from save and canonical hash. Empty result ring/cursors on load; do not erase restored source-intent identity. `_result_store_code` shares this classification. |
| Source-intent ledger | `_intent_player_id`, `_intent_sequence_high`, `_intent_sequence_low`, `_intent_zone_generation` | 4 | `INTENT_CAPACITY` = 128 | `_intent_player_id == -1` (`NO_INTENT_PLAYER`) means no command produced this zone row | 1 | §6 AUXILIARY_STATE | Task 04.4's duplicate suppression: one row per `HarvestZone` row carrying `(player_id, sequence_high, sequence_low)` plus the designation's generation. Dropping it lets a replayed or re-evaluated command create a second designation, so it is future-affecting in the strictest sense. |
| Payload decode scratch | `_payload` | 1 | `PAYLOAD_SCRATCH_BYTES` = 65540 | Contents past the decoded length are stale bytes | 3 | -- | One reused buffer sized to the largest per-kind payload; written and consumed inside one dispatch. |
| Dispatch counters and scratch | -- | -- | -- | -- | 3 | -- | `_result_write`, `_result_count`, `_results_recorded`, `_committed_count`, `_refused_count`, `_duplicate_intent_count`, `_drained`, `_calendar`, `_math`, `_target_row`, `_store_code`, `_last_refusal`. `_result_write`/`_result_count` remain transient under decision 0063; reset only result state on load, not the persisted source-intent ledger. |

### `godot/scripts/core/commands.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Pending command envelope (i64) | `_execute_tick` | 8 | `QUEUE_CAPACITY` = 4096 | Only the `_count` rows from `_head` are live; the rest hold whatever a drained command left. ARCH-SAVE-002: encode zero for unused payload | 1 | §12 PENDING_COMMANDS | ARCH-SAVE-001's 64-byte command record, field for field. SAVE-SEQ-R01 section12schema3 supersedes the historical ready07 schema2 prefix:28 prefix bytes, then E unchanged64-byte records in canonical command order, E<=4096. `_sequence_low`/`_sequence_high` hold u32 BITS in i32 columns, so a sequence past 0x80000000 stores negative -- the codec must write the bits, not a signed widening. |
| Pending command envelope (i32) | `_player_id`, `_sequence_low`, `_sequence_high`, `_kind`, `_target_slot`, `_target_generation`, `_goal_x`, `_goal_z`, `_arg0`, `_arg1`, `_payload_offset`, `_payload_length`, `_flags`, `_reserved_zero` | 4 | `QUEUE_CAPACITY` = 4096 | Only the `_count` rows from `_head` are live; the rest hold whatever a drained command left. ARCH-SAVE-002: encode zero for unused payload | 1 | §12 PENDING_COMMANDS | See the first row of this group. |
| Queue order index | `_order` | 4 | `QUEUE_CAPACITY` = 4096 | Entries outside `[0, _count)` are stale | 2 | §12 PENDING_COMMANDS | ready07 §Save: "Rebuild ring/order indexes deterministically". Records are written in canonical order and restored from row 0, so head becomes 0 and this index is regenerated rather than carried. |
| Payload arena | `_payload` | 1 | `PAYLOAD_ARENA_BYTES` = 1048576 | Bytes at or past `_payload_used` are unallocated, not zeroed | 1 | §12 PENDING_COMMANDS | ready07 §Save: write "exactly P bytes of the economic payload arena's used prefix (preserve offsets and consumed space that still affects admission)", P<=1048576. Compacting it on load would change which future command is admitted, so the used prefix is future-affecting even where a live command no longer points into part of it. |
| Empty-reference constant | `_no_refs` | 4 | never allocated | Always length 0 | 3 | -- | A permanently empty array passed as the "no referenced ids" argument. Never sized, never written. |
| Queue control and sequence allocator | -- | -- | -- | -- | 1 | §12 PENDING_COMMANDS | SAVE-SEQ-R01 keeps `_count`, `_payload_used` and `_next_sequence_low` as prefix/canonical u32 values; `_next_sequence_high` is u64 at prefix20 and commands canonical ordinal2/type3. Every ordinary u32 pair, including zero, remains meaningful; terminal high4294967296/low0 is saved exactly. The existing native int64 scalar needs no new resident allocation. The sequence pair is an allocator, not a counter: reusing a number would make two distinct commands compare equal in a replay stream. |
| Ring head | -- | -- | -- | -- | 2 | §12 PENDING_COMMANDS | `_head`. Records are written in canonical order and restored from row 0, so its canonical restored value is 0. |
| Command diagnostics and scratch | -- | -- | -- | -- | 3 | -- | `_kind_count`, `_accepted_count`, `_refused_count`, `_drained_count`, `_refused_member`, `_last_refusal`, `_math`, `_scratch`. SAVE-P2-R02 adds cold restore scratch only: one decoded Command, up to4096 packed span keys (32768B), and caller-owned encoded record/used-prefix buffers. No retained column or second Commands instance; restore preserves diagnostic counters. |

### `godot/scripts/core/construction.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Construction columns | `_material_container_slot`, `_material_container_generation`, `_assigned_count`, `_max_workers`, `_refund_policy` | 4 | `CONSTRUCTION_CAPACITY` = 82944 | `_material_container_slot == -1` with generation 0 is the null ref; `_assigned_count == 0` is a project with no builder bound, which is also every paused project | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's Construction row and `systems_architecture.md` §2.2's five-column I32 group at 82944. `_material_container` is an INVENTORY CONTAINER reference, NOT a directory one: it validates against `inventory.gd`'s `_c_generation`, and the 2026-09-11 addendum's four distinct namespaces are why a decoder that checked it against the directory would accept a stale handle whose numbers matched. `_refund_policy` is REQ-SET-126/127's three fractions (100/80/50) and is RECOMPUTED from `_purpose` and `_work_begun` on load and compared by `verify_refund_policies()`, which refuses a mismatch rather than repairing it. |
| Construction work | `_remaining_mwu` | 8 | `CONSTRUCTION_CAPACITY` = 82944 | 0 on a live row means the work is finished, not that the row is free | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's `remaining_mwu: int64` and §2.2's single I64 column at 82944. Milli-WU, int64 because §4.1's hall declares 2400000 before any demolition or upgrade arithmetic. |
| Project pause and consumption latch | `_paused`, `_work_begun` | 1 | `CONSTRUCTION_CAPACITY` = 82944 | 0 means running / not yet consumed | 1 | §4 COMPONENT_COLUMNS | `_paused` is GDD §4.2's `paused: bool` and §2.2's B8 Construction row; REQ-SET-137 keeps the ledger and the remainder across it and only releases workers. `_work_begun` is NEW and is the single record that REQ-SET-125's consumption has happened, which is the ONLY thing that moves REQ-SET-126's refund from 100% to 80%. It is not derivable from `_remaining_mwu`: a project whose work has begun but earned no milli-WU yet still refunds 80%. |
| Project occupancy | `_present` | 1 | `CONSTRUCTION_CAPACITY` = 82944 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset; what says a row is free, exactly as `buildings.gd`'s `_b_present` does. ARCH-SAVE-002 serializes the occupied bitset FIRST, so `planning/canonical_state_registry.json` gives this **ordinal 0** in section 4 even though `construction.gd` declares it after `_material_container_slot`; the remaining fifteen follow the module's own declaration order. A codec that walked GDScript declaration order instead would produce a stream that is stable, plausible and wrong, the same trap `canonical_state_hash.gd`'s header names for alphabetical order. |
| Project identity and subject | `_ref_slot`, `_ref_generation`, `_subject_slot`, `_subject_generation` | 4 | `CONSTRUCTION_CAPACITY` = 82944 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | The directory reference copy, and the Building or Furniture this project acts on. DIRECTORY namespace, both pairs. The subject is the reverse of `buildings.gd`'s `_b_construction_slot` only for building subjects: §4.2 gives Furniture no construction column at all, so a furniture project's subject is stored here and nowhere else and cannot be rebuilt from the Building store. |
| Project classification | `_purpose`, `_type_id`, `_phase` | 4 | `CONSTRUCTION_CAPACITY` = 82944 | `_type_id == -1` on a free row only; a live project always names a definition | 1 | §4 COMPONENT_COLUMNS | NEW, and none of the three is in §4.2. `_purpose` is build/upgrade/furniture/demolish and decides which bill and which refund rule applies; `_type_id` is the BuildingDefinition or FurnitureDefinition id the bill is read at; `_phase` is where the project stands in REQ-SET-124-127's sequence. All three are module ordinals, NOT compiled catalog domains -- no document numbers them and `catalog.gd` was not this change's to extend -- so a codec must pin them itself rather than assume a domain will appear. `_phase` is NOT SET-MOVE-ECON-001 ECON-003's excavation-site phase domain, which is a property of ground and belongs to the excavation owner. |
| Delivered material ledger | `_delivered_milli` | 8 | `DELIVERED_CELLS` = 331776 | 0 means nothing has been delivered on that line; cells at or beyond a project's own bill size are always 0 | 1 | §5 CHILD_ARENAS | REQ-SET-124's delivered quantities, owner-major at stride `MATERIAL_SLOTS_PER_PROJECT` = 4, so line `k` of project row `r` is cell `r * 4 + k`. This is the ONLY basis REQ-SET-126's 100%/80% refund reads, and it is retained after consumption precisely so the 80% case has something to compute from; it is NOT reconstructible from the project's `material_container`, which `begin_work()` empties. The stride is fixed rather than arena-allocated: the largest authored bill is three typed pairs and the fourth slot is spare for ECON-003's brace input. |
| ConstructionPaidLedger | `_paid_base_type`, `_paid_upgrade_mask` | 4 | `CONSTRUCTION_CAPACITY` = 82944 | `_paid_base_type == -1` (`NO_PAID_PACKAGE`) with mask 0 on a free row and on an UPGRADE row, which pays no base package | UNRESOLVED | §4 COMPONENT_COLUMNS | [Decision 0534](decisions/0534-demolition-admit-and-the-adopted-inventory.md): BUILD-C4-R01's "recorded paid packages", `systems_architecture.md` §3's already-budgeted ConstructionPaidLedger row (663552 B). Package KEYS only; quantities are read back from the compiled bills under the save header's rules hash. `_paid_base_type` is a BuildingDefinition id or a FurnitureDefinition id according to `_purpose`, exactly as `_type_id` is. A DEMOLITION row's pair is the admission snapshot its 50% return and its 0.25 WU are computed from, so it is future-affecting state. QUESTION: which §4 owner and ordinals carry it -- appended to the construction owner, whose 16-column body ADR 0186 froze, or a separate ConstructionPaidLedger owner -- and is that CONSTRUCTION-SAVED-BINDINGS' decision? Until answered it is in no save, like the rest of an open project (CONSTRUCTION-SAVED-BINDINGS). |
| Return manifest key scratch | `_manifest_key` | 4 | `MATERIAL_SLOTS_PER_PROJECT` = 4 | Only the first `count` lines of the last call mean anything | 3 | -- | One demolition's per-item material key indexes, refilled by every manifest read. Not state: recomputed from `_type_id` and the paid-ledger pair. |
| Return manifest quantity scratch | `_manifest_milli` | 8 | `MATERIAL_SLOTS_PER_PROJECT` = 4 | As above | 3 | -- | The matching per-item milli-U totals, before the 50% floor. |
| Halved return key scratch | `_return_key` | 4 | `RETURN_LINE_CAPACITY` = 6 | Only the first `count` lines of the last call mean anything | 3 | -- | [Decision 0536](decisions/0536-furniture-returns-half-by-type-and-pieces-are-removed-alone.md): one removal's HALVED return, the building's lines then each piece of furniture's, so up to every material key once. Not state: recomputed from the paid-ledger pair and the pieces in the building. |
| Halved return quantity scratch | `_return_milli` | 8 | `RETURN_LINE_CAPACITY` = 6 | As above | 3 | -- | The matching milli-U, each building line floored once and each piece's floored on its own. |
| Building and upgrade bill keys | `_build_key`, `_upgrade_key` | 4 | `BUILDING_BILL_CELLS` = 120 | `-1` in any cell past a definition's own pair count; `_upgrade_key` is all `-1` for the twenty-six definitions with no tier-2 package | 2 | §2 CATALOG_IDS | IMMUTABLE CATALOG, NOT SIMULATION STATE. `gameplay_balance.md` §4.1's and §4.2's `materials_milli` pair lists, which decision 0088 deliberately left to "the store that needs it". A cell holds an index into `MATERIAL_KEYS`, NOT a compiled ItemDefinition id: ids are compiled at runtime from `item_definitions.gd` and ARCH-CAT-004 forbids compiling one in, so a caller resolves the key. Recompiled from the source tables on construction. |
| Building and upgrade bill quantities | `_build_milli`, `_upgrade_milli` | 8 | `BUILDING_BILL_CELLS` = 120 | 0 in any cell past a definition's own pair count | 2 | §2 CATALOG_IDS | The milli-U half of the rows above. int64 because a quantity is a `quantity_milli` and callers sum bills. See the first row of this group. |
| Furniture bill keys | `_furniture_key` | 4 | `FURNITURE_BILL_CELLS` = 36 | `-1` past a definition's own pair count | 2 | §2 CATALOG_IDS | §4.3's `materials_milli`, at the id `Catalog.FURNITURE_DEFINITION` assigns. Same key-index rule and the same reload argument as the building rows. |
| Furniture bill quantities | `_furniture_milli` | 8 | `FURNITURE_BILL_CELLS` = 36 | 0 past a definition's own pair count | 2 | §2 CATALOG_IDS | The milli-U half of the row above. |
| Bill pair counts | `_build_count`, `_upgrade_count` | 4 | `BUILDING_KINDS` = 30 | 0 is a REAL empty bill for `dirt_path`, which §4.1 gives `[]`, and for the twenty-six definitions with no tier-2 package | 2 | §2 CATALOG_IDS | How many typed pairs each definition's bill has, so a reader never scans the spare stride cells. The `dirt_path` zero is why an empty bill opens straight into PHASE_READY rather than awaiting a delivery that can never arrive. |
| Furniture bill pair counts | `_furniture_count` | 4 | `FURNITURE_KINDS` = 9 | 0 would be an empty §4.3 bill; none of the nine has one | 2 | §2 CATALOG_IDS | As above, for §4.3's nine rows. |
| Tier-2 package work | `_upgrade_work` | 8 | `BUILDING_KINDS` = 30 | 0 means this definition has no tier-2 package, and `declared_work_mwu_into()` refuses rather than pricing 0 work | 2 | §2 CATALOG_IDS | §4.2's upgrade table `work_mwu`: hall and residence 1200000, covered_store 600000, workshop 720000. BAL-CAT-006 restricts the packages to those four keys and `_assert_bills()` refuses construction if a fifth appears. |
| Store counts and collaborators | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_live_count` is recomputed from `_present`. `_buildings`, `_owns_buildings`, `_directory`, `_definitions` and `_math` are wiring: the borrowed Building store, the construction flag, the allocator read out of that store, the immutable catalog facts, and one reusable `IntResult` scratch. All are re-bound on load and none is state. |

### `godot/scripts/core/crop_weather.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Daily and hourly orchestration latches | -- | -- | -- | `_last_day == 0` (`NO_DAY_RUN`) and `_last_hour_tick == -1` (`NO_HOUR_RUN`) mean "never run" | 1 | §6 AUXILIARY_STATE | These latches are the only thing stopping a day's crop/weather pass running twice or being skipped. A reload that reset them would re-run the current day's ecology against already-advanced stocks. `_calendar`, `_read`, `_tile_x`, `_tile_z`, `_last_refusal` and the eight collaborator handles are category 3. |

### `godot/scripts/core/demolition_admissions.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Admitted demolition and its output reservation | `_project_slot`, `_project_generation`, `_output_slot`, `_output_generation` | 4 | `BUILDING_CAPACITY` = 1024 | `(-1, 0)` for no admission and, on the output pair, for the ground-pile fallback; once the project is no longer a live CONSTRUCTION row the project and binding readers answer null, but an unreleased claim stays readable through `unreleased_*_of()` until `release()` | UNRESOLVED | §4 COMPONENT_COLUMNS | [Decision 0534](decisions/0534-demolition-admit-and-the-adopted-inventory.md): indexed by Building typed row. Binds the anonymous Inventory `reserved_mass_g` taken at *admit* to its demolition project, so D5's commit (`complete_demolition()`, [decision 0535](decisions/0535-demolition-completion-is-one-commit-and-furniture-refuses.md)) places the return into it, releases exactly that claim and then the record, before the building row goes. The grams stay recorded until `release()` even after the project retires, so a claim cannot outlive its project unseen. The project pair is a DIRECTORY ref; the output pair is an INVENTORY CONTAINER ref. QUESTION: which §4 owner and ordinals carry it once CONSTRUCTION-SAVED-BINDINGS saves open projects? Without it a load would keep section 7's reserved mass and lose who owns it. |
| Output reservation grams | `_output_reserved_g` | 8 | `BUILDING_CAPACITY` = 1024 | 0 with no admission or a ground-pile fallback | UNRESOLVED | §4 COMPONENT_COLUMNS | The grams reserved at admission: the sum of each returned line's own `ceil(q * m / 1000)` lot debit. QUESTION: which §4 owner and ordinals carry it, beside the output pair? |
| Admitted return charge | `_admitted_charge_g` | 8 | `BUILDING_CAPACITY` = 1024 | 0 with no admission | UNRESOLVED | §4 COMPONENT_COLUMNS | [Decision 0536](decisions/0536-furniture-returns-half-by-type-and-pieces-are-removed-alone.md): the admitted return's capacity charge for EVERY admission, a ground-pile fallback included; equal to `_output_reserved_g` when a store holds the claim. The commit refuses a return whose charge differs (furniture placed or removed around the coordinator). Future-affecting: a loaded open demolition must compare against it. QUESTION: which §4 owner and ordinals carry it, beside the output grams? |
| Destination revision | `_destination_revision` | 4 | `BUILDING_CAPACITY` = 1024 | `FIRST_DESTINATION_REVISION` = 1 after `clear()`; 0 is never stored | UNRESOLVED | §4 COMPONENT_COLUMNS | MOVE-DEP-R05's contact-owner revision for each Building row, +1 per admitted demolition (INV-GOODS-R01: "advances on demolition/access edits affecting admission"). Monotonic per row across reuse. Movement's `_cursor_destination_revision` (section 4, owner 8) captures it at travel admission, so the two must agree after a load. QUESTION: which §4 owner and ordinals carry it, and does the building owner (BUILDINGS-SAVED-BINDINGS) take it over when it publishes contacts? |
| Bindings | -- | -- | -- | -- | 3 | -- | `_directory` is the settlement's one allocator, re-bound on construction. |

### `godot/scripts/core/demolition_work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Evacuate-then-demolish order | `_intent_slot`, `_intent_generation` | 4 | `BUILDING_CAPACITY` = 1024 | `(-1, 0)` for no order; a recorded ref whose building has gone (or whose row was reused) reads as no order and is dropped by the next hourly reconcile | UNRESOLVED | §4 COMPONENT_COLUMNS | [Decision 0537](decisions/0537-demolition-work-is-a-build-job-and-evacuation-waits-for-hauling.md): DEMO-CONTAIN-R01 blocker 4's "persisted evacuate then demolish intent", one per Building typed row, holding the building's full DIRECTORY ref so a reused row never inherits an order. Future-affecting: an order that a load dropped would never retry *admit*, and the building the player ordered down would stand. QUESTION: which §4 owner and ordinals carry it -- the building owner (BUILDINGS-SAVED-BINDINGS, beside the building row it is keyed by) or the construction owner beside the admission record (CONSTRUCTION-SAVED-BINDINGS)? Until answered it is in no save, like the admission record it leads to. |
| Removal work Job link | `_job_slot`, `_job_generation` | 4 | `BUILDING_CAPACITY` = 1024 | `(-1, 0)` for no Job; a link to a Job the Job store has released reads as none | UNRESOLVED | §4 COMPONENT_COLUMNS | Decision 0537: the one BUILD Job working each admitted removal (a demolition, or one piece's removal on its building's row), a DIRECTORY ref of KIND_JOB. The Job's own `requester` names the project, so this link is reconstructible by a scan of the Job store's requester columns -- category 2 once Jobs and open projects are both saved. QUESTION: category 1 or 2? It cannot be settled before CONSTRUCTION-SAVED-BINDINGS saves open projects: today a load keeps no open project, so no Job may name one either. Whoever saves Jobs must not restore a removal's BUILD Job without its project: the coordinator never works a BUILD Job it cannot resolve, and its hourly sweep retires one (decision 0537). |
| Bindings and scratch | -- | -- | -- | -- | 3 | -- | `_directory`, `_jobs`, `_construction` and `_buildings` are the settlement's own stores, re-bound on construction; `_read` is one reused IntResult. |

### `godot/scripts/core/ecology.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Daily ecology latch | -- | -- | -- | `_last_day == 0` (`NO_DAY_RUN`) means the daily pass has never run | 1 | §6 AUXILIARY_STATE | Same argument as `crop_weather.gd`: midnight is one of ARCH-SAVE-006's named coverage cases, and a save taken at an exact midnight with the latch dropped re-runs regrowth. `_calendar`, `_read`, `_hive_day` and the collaborator handles are category 3. |

### `godot/scripts/core/entity_directory.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Identity columns | `_persistent_id`, `_kind` | 4 | `DIRECTORY_CAPACITY` = 352418 | `_persistent_id == 0` and `_kind == -1` (`KIND_ANY`) on a free slot | 1 | §3 ENTITY_DIRECTORY | `destroy()` zeroes both, so a free slot's identity is genuinely absent rather than stale. |
| Generation column | `_generation` | 4 | `DIRECTORY_CAPACITY` = 352418 | Never null: a never-used slot holds 0 and the value only ever increases | 1 | §3 ENTITY_DIRECTORY | THE GENERATION LIVES HERE, ON THE DIRECTORY SLOT, NOT ON THE TYPED ROW. Typed stores carry `_ref_slot`/`_ref_generation` back-pointers, which are copies. ARCH-SAVE-002 requires "all generations including free/retired slots": a load that wrote generations only for live slots, or that reset them, would hand the next `create()` a `(slot, generation)` pair that an `EntityRef` taken before the save still holds -- the aliasing `clear()`'s docstring says generations exist to make impossible. Stale refs stay stale across a reload only if this whole column survives verbatim. |
| Occupied bitset | `_active` | 1 | `DIRECTORY_CAPACITY` = 352418 | 0 = free, 1 = live; one byte per slot, not a packed bitset | 1 | §3 ENTITY_DIRECTORY | ARCH-SAVE-002's "occupied bitset", serialized first in each typed store. |
| Retirement mask | `_retired` | 1 | `DIRECTORY_CAPACITY` = 352418 | 0 = reusable, 1 = spent its last generation and never returns to the free heap | 1 | §3 ENTITY_DIRECTORY | ARCH-SAVE-002 names "allocator-retirement state" explicitly. It is also implied by `_generation[slot] >= 2147483647`, so a loader can and should cross-check the two rather than trust either alone. |
| Typed-row map | `_typed_row` | 4 | `DIRECTORY_CAPACITY` = 352418 | `-1` (`NULL_SLOT`) on a free slot | 1 | §3 ENTITY_DIRECTORY | The slot-to-typed-row half of ARCH-ID-003. Not derivable: nothing else records which row of the kind's store a slot owns. |
| Reverse owner map | `_typed_owner_slot` | 4 | `DIRECTORY_CAPACITY` = 352418 | `-1` (`NULL_SLOT`) for a free typed row | 2 | §3 ENTITY_DIRECTORY | The exact inverse of `_typed_row`, arena-partitioned by `_kind_base`. Rebuild by walking live slots ascending; writing it as well would give ARCH-ID-003's validator two sources that can disagree. |
| Free-slot and free-row heaps | `_free_heap`, `_heap_index` | 4 | `DIRECTORY_CAPACITY` = 352418 | Only the first `_free_count` / `_kind_free_count[kind]` entries of each window are live | 2 | §3 ENTITY_DIRECTORY | ARCH-SAVE-002 permits either: "Save allocator heaps or rebuild them deterministically from occupancy and retired masks". Rebuild is correct here because `_pop_min()` returns the window minimum, so allocation order depends on the SET of free entries and not on the array permutation; `_rebuild_free_heaps()` already fills ascending, which is a valid min-heap. Task 09's "restored lowest-free allocation" check is exactly this property.  Ascending refill is `restore_columns()`'s obligation as well as `_rebuild_free_heaps()`': decision 0105 restores from the six written columns and rebuilds these, and ascending fill is what makes the next `create()` return the lowest free slot. |
| Per-kind allocator counters | `_kind_base`, `_kind_free_count`, `_kind_live_count` | 4 | `KIND_COUNT` = 18 | No null: every kind always has an entry | 2 | §3 ENTITY_DIRECTORY | `_kind_base` is the prefix sum of the `KIND_CAPACITY` constant and can never differ between two builds of the same rules. The two counts are recomputed from `_active` and `_retired` with the heaps. |
| Persistent-id allocator | -- | -- | -- | -- | 1 | §1 WORLD | `_next_persistent_id` IS future-affecting and IS NOT derivable: `destroy()` zeroes `_persistent_id`, so "max live id + 1" is wrong the moment anything has died, and reusing an id breaks ARCH-SAVE-004's unique-persistent-id validation. It is `WorldRuntime.next_persistent_id` in §2's ledger (systems_architecture.md:405).  §1 BLOCK FRAMING (decision 0115): owner key `entity_directory`, `owner_schema_version:u32` = 1, `primary_count:u64` = 1, `payload_byte_length:u64` = 4, payload `_next_persistent_id:u32 LE`. Domain **1..2147483648 inclusive**, where 2147483648 is the EXHAUSTED cursor after the final signed-int32 identity was issued -- live persistent-id columns stay i32 and never contain it. Block width 4 + 16 + 4 + 8 + 8 + 4 = **44 bytes**. The cursor is captured and restored EXPLICITLY and validated to exceed every positive stored id; it is never derived as max(live ids) + 1, which is wrong the moment anything has died, and a stale cursor is a REFUSAL rather than an automatic repair. |
| Directory live counters | -- | -- | -- | -- | 2 | §3 ENTITY_DIRECTORY | `_free_count` and `_live_count`, recomputed with the heaps from `_active` and `_retired`. |
| Directory refusal code | -- | -- | -- | `REFUSAL_NONE` is the empty StringName | 3 | -- | `_last_refusal`, the code from the most recent refused `create()`. |
| Directory column refusal code | -- | -- | -- | `REFUSAL_NONE` is the empty StringName | 3 | -- | `_last_column_refusal`, the code from the most recent refused `copy_columns_into()` or `restore_columns()` (decision 0105). Deliberately a SEPARATE namespace from `_last_refusal` above, every code prefixed `COLUMN_`: sharing one field would let a save or a load clobber a `create()` refusal the caller had not read yet. A `StringName` scalar, not a packed column, so it owes no §2.3 allocation row and no ledger byte. |
| Cold future-allocation observation | -- | -- | -- | Null ref, kind/row -1 and PID0 when reset | 3 | -- | Decision1083. Caller-owned CreateCandidate carries32 logical numeric bytes (future full ref8, kind/typed row/PID8 each) plus exact weak Directory/native object overhead. This adds no Directory member, heap copy, reservation, allocator epoch or save column. Every consume rechecks actual owner, capacities, both heap roots, generation and PID. Each caller counts its own packet instance; RoomOrders includes one in its separate92-byte extension below. Candidates and sealed observations are discarded across reset/restore; no pointer or future identity is serialized. |
| Cold mixed-kind future-allocation packet | -- | -- | -- | Count0 and null weak owner invalidate every tuple; unused tails are scratch | 3 | -- | Decision1086. Caller-owned CreateBatch allocates five I32 tuple columns at explicit K, an I32[K+1] heap frontier and I32[18] requested-kind counts:24K+76 packed bytes plus16 logical numeric capacity/count bytes. K is refused outside1..352418 before allocation; this is an engineering ceiling, never a production default. Actual caller cold admission must precede construction and separately count input/pinned copies, WeakRef/object/packed headers, helper frames and native growth. No extra result-reference copy, Directory member, full heap copy, reservation, epoch, history rollback or save bytes. Peek/revalidation touches only packet scratch; all ordered actual-owner slot/generation/kind/typed-row/PID choices are rechecked before callback-free publication. Consuming owners separately pin the mutable observation and actual World; packets are discarded across reset/restore and never serialized. |

### `godot/scripts/core/event_schedule.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Event record i32 fields | `_kind`, `_source_id`, `_arg0`, `_arg1` | 4 | `CAPACITY` = 64 | Rows `[_count, CAPACITY)` are held byte ZERO, not stale residue; `_remove_row()` zeroes the vacated row | 1 | §11 EVENT_SCHEDULE | SAVE-R09-005's §11 record, field order `kind, source_id, arg0, arg1, due_tick, sequence`, 32 bytes, dense and sorted `(due_tick, sequence)`, maximum 64. 4 x 4 B x 64 = **1024 B**, the count already budgeted in `docs/systems_architecture.md:434`. GDScript ints are 64-bit, so every one of the four is `IntMath.fits_int32()`-checked BEFORE insertion: `0x80000000` is positive and would store as `-2147483648`. BLOCKED: no kind/argument DOMAIN is ruled anywhere, so these are validated as int32 storage and carry no meaning; SAVE-R09-005 requires that domain and the production/consumption rules before real events are activated. BLOCKED: §11 has no codec -- the payload is `next_sequence:i64` then N records, length `8 + 32*N`, and nothing writes or reads it. |
| Event record i64 fields | `_due_tick`, `_sequence` | 8 | `CAPACITY` = 64 | Rows `[_count, CAPACITY)` are byte zero; sequence 0 is the EXHAUSTED marker and never a live row | 1 | §11 EVENT_SCHEDULE | 2 x 8 B x 64 = **1024 B**, `docs/systems_architecture.md:435`. Live sequences are unique, nonzero and below `_next_sequence` unless it is exhausted; `restore_rows()` checks all of that plus strict `(due_tick, sequence)` ascent before writing a byte. Due ticks are offset-calendar ticks: a midnight is `(tick + 4500) mod 18000 == 0` and tick 13500 is the first one, never `tick % 18000`. Rows do not expire on their own -- SAVE-R09-005 forbids silently expired rows, so a due row stays until a consumer pops it. |
| Event schedule scalars | -- | -- | -- | `_next_sequence == 0` means the allocator is EXHAUSTED; it is not an empty schedule and not a null | 1 | §11 EVENT_SCHEDULE | `_next_sequence` is SAVE-R09-005's "ALREADY BUDGETED `WorldRuntime.next_event_sequence` i64 reassigned to EventSchedule ownership/section 11" -- 8 B moving owner, NOT 8 B added, so `docs/systems_architecture.md:441` must drop it from the WorldRuntime I64 row as this store gains it. Initial 1, issued 1..I64_MAX, never reused, never inferred from live rows. `_count` is the declared u32 scalar, 4 B on the wire, a plain GDScript int in memory and so no packed-column row. Both are ordinals 0 and 1 of REG-R01's eight declared fields. |
| Event schedule diagnostics and scratch | -- | -- | -- | -- | 3 | -- | `_last_refusal`, the code from the most recent refused call, and `_math`, the reused `IntResult` scratch. Neither is simulation state; both are a `StringName`/object handle rather than a packed column, so they owe no ledger byte. |

### `godot/scripts/core/family_rules.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Fixed-stage compiled rate tables | `_hunger_rates_milli`, `_daily_demand_np` | 8 | `TABLE_COUNT` = 18 | Every valid stage/size/season row is populated | 2 | §2 CATALOG_IDS | FAMILY-RULES-R01 / decision0158. Two private tables reconstruct from the same compiled rules,288 packed bytes. Scalar readers only. Since [decision 0521](decisions/0521-pc04-adopted-with-children-inactive.md) the helper is BOUND: `needs.gd` owns one instance and reads its hunger rows, and `residents.gd` reads its demand rows through it. Children remain inactive, so no live world reads a CHILD row; the complete family rules fingerprint is still an activation prerequisite. No additional canonical/save field is declared. |
| Table readiness | -- | -- | -- | false until every checked value is built | 2 | §2 CATALOG_IDS | `_ready` is a derived construction result, not resident state. Queries cannot publish a partial table. |

### `godot/scripts/core/farming.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| FarmPlot state | `_present` | 1 | `FARM_PLOT_CAPACITY` = 4096 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | The store's occupied bitset. |
| FarmPlot crop identity and soil | `_crop_id`, `_state`, `_soil`, `_fertility`, `_moisture` | 4 | `FARM_PLOT_CAPACITY` = 4096 | `_crop_id == -1` (`CROP_NONE`) when nothing is sown | 1 | §4 COMPONENT_COLUMNS | Catalog-indexed values; ARCH-SAVE-005 bounds them against the verified `CropFamily`/`Soil` domains. |
| FarmPlot growth accumulator | `_growth_milli_hours` | 8 | `FARM_PLOT_CAPACITY` = 4096 | 0 before sowing | 1 | §4 COMPONENT_COLUMNS | Integer milli-hours. Task 09's acceptance list names "item/XP/clock remainders" for exactly this reason: dropping a sub-hour remainder shifts a ripening tick. |
| FarmPlot condition and rotation | `_health`, `_last_family`, `_family_streak` | 4 | `FARM_PLOT_CAPACITY` = 4096 | `_last_family == -1` (`FAMILY_NONE`) before the first harvest | 1 | §4 COMPONENT_COLUMNS | `_family_streak` drives the rotation factor and is pure history; nothing reconstructs it. |
| FarmPlot compost store | `_compost_milli` | 8 | `FARM_PLOT_CAPACITY` = 4096 | 0 = none applied | 1 | §4 COMPONENT_COLUMNS | Work-in-progress quantity in milli units. |
| FarmPlot placement and identity | `_sow_day`, `_tile`, `_ref_slot`, `_ref_generation` | 4 | `FARM_PLOT_CAPACITY` = 4096 | `_ref_slot == -1` with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | `_ref_slot`/`_ref_generation` are a COPY of the directory pair; the authoritative generation is `entity_directory.gd`'s. ARCH-SAVE-004 validates the two agree rather than trusting this copy. |
| FarmPlot active list | `_live_slots` | 4 | `FARM_PLOT_CAPACITY` = 4096 | Only `[0, _live_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | ARCH-SAVE-002: "active lists are rebuilt ascending". |
| Tile agronomy grid | `_tile_fertility`, `_tile_last_family`, `_tile_family_streak`, `_tile_last_legume_day`, `_tile_compost_season`, `_tile_active_plot_row`, `_tile_orchard_row` | 4 | `TILE_COUNT` = 16384 | `_tile_active_plot_row`/`_tile_orchard_row` hold `-1` when no plot or orchard owns the tile; `_tile_last_legume_day == 0` (`NO_LEGUME_DAY`) means never | 1 | §1 WORLD | Per-tile soil history outlives any plot that sat on the tile, so it cannot be reconstructed from the plot rows. `_tile_active_plot_row` is an inverse of `_tile` and is saved with the grid it indexes; the loader cross-checks rather than choosing. |
| Tile growth remainders | `_tile_ripe_tick`, `_tile_growth_remainder` | 8 | `TILE_COUNT` = 16384 | `_tile_ripe_tick == -1` (`NO_RIPE_TICK`) when nothing on the tile is ripe | 1 | §1 WORLD | An absolute tick and a sub-hour remainder; both shift a harvest boundary if dropped. |
| Tile daily tend latch | `_tile_tended_today` | 1 | `TILE_COUNT` = 16384 | 0 = not tended since the last daily rollover | 1 | §1 WORLD | Cleared at the day boundary, so a save at an exact midnight (an ARCH-SAVE-006 case) must carry its pre-rollover value. |
| Farming scratch | -- | -- | -- | -- | 3 | -- | `_math` and the `_owns_directory` construction flag. |

### `godot/scripts/core/field_policy.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Field identity | `_zone_slot`, `_zone_generation` | 4 | `FIELD_CAPACITY` = 128 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | The owning HarvestZone reference; the authoritative generation is the directory's. |
| Rotation plan | `_rotation_ids` | 4 | `FIELD_CAPACITY * ROTATION_LENGTH` = 384 | `-1` (`NO_CROP`) in an unfilled rotation position | 1 | §4 COMPONENT_COLUMNS | Three crop ids per field, owner-major at `field * 3 + position`. |
| Rotation cursor | `_rotation_cursor` | 4 | `FIELD_CAPACITY` = 128 | 0 (`DEFAULT_ROTATION_CURSOR`) | 1 | §4 COMPONENT_COLUMNS | Which rotation position the next cycle sows. Pure position state, not derivable from the plan. |
| Field policy flags | `_auto_rotation`, `_seed_reserve`, `_field_present` | 1 | `FIELD_CAPACITY` = 128 | `_field_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | Player policy, set by SET_POLICY commands. |
| Cycle accounting | `_cycle_ordinal`, `_participants`, `_resolved`, `_withdrawn`, `_completed_cycles`, `_cancelled_cycles`, `_requested_crop` | 4 | `FIELD_CAPACITY` = 128 | `_cycle_ordinal == 0` (`NO_CYCLE`) when no cycle is open; `_requested_crop == -1` (`NO_CROP`) | 1 | §4 COMPONENT_COLUMNS | An open cycle's participant/resolution counts are mid-flight work; a reload that lost them would close a cycle early or never. |
| Cycle enums | `_cycle_state`, `_close_reason`, `_request_state` | 1 | `FIELD_CAPACITY` = 128 | Byte enums; value 0 is the initial state of each, not an absence marker | 1 | §4 COMPONENT_COLUMNS | ARCH-SAVE-005 rejects a value at or above `CYCLE_STATE_COUNT`, `CLOSE_REASON_COUNT`, `REQUEST_STATE_COUNT`. |
| Plot participation (i32) | `_plot_field_slot`, `_plot_cycle` | 4 | `PLOT_CAPACITY` = 4096 | `_plot_field_slot == -1` (`NO_FIELD`) when the plot is in no field | 1 | §4 COMPONENT_COLUMNS | One row per farm plot, indexed by plot row. |
| Plot participation (u8) | `_plot_outcome` | 1 | `PLOT_CAPACITY` = 4096 | `_plot_field_slot == -1` (`NO_FIELD`) when the plot is in no field | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Policy counters and scratch | -- | -- | -- | -- | 3 | -- | Ten `_*_count` diagnostics plus `_math` and `_calendar`. |

### `godot/scripts/core/fishing.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| FishHabitat occupancy | `_habitat_present` | 1 | `FISH_HABITAT_CAPACITY` = 32 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| FishHabitat configuration | `_habitat_type`, `_habitat_zone_slot`, `_habitat_zone_generation`, `_habitat_effort_slots`, `_habitat_pollution`, `_habitat_danger`, `_habitat_protected_fraction` | 4 | `FISH_HABITAT_CAPACITY` = 32 | `_habitat_zone_slot == -1` with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | `_habitat_zone_generation` is a copy of the directory generation for the owning zone. |
| FishHabitat capacity | `_habitat_capacity_milli` | 8 | `FISH_HABITAT_CAPACITY` = 32 | 0 = no capacity | 1 | §4 COMPONENT_COLUMNS | `quantity_milli` int64 per AGENTS.md. |
| FishHabitat identity and daily effort | `_habitat_ref_slot`, `_habitat_ref_generation`, `_habitat_effort_used` | 4 | `FISH_HABITAT_CAPACITY` = 32 | `-1`/0 null ref; `_habitat_effort_used == 0` after the daily reset | 1 | §4 COMPONENT_COLUMNS | Effort used today is cleared at the day boundary and is future-affecting at an exact midnight. |
| FishHabitat intensive flag | `_habitat_intensive` | 1 | `FISH_HABITAT_CAPACITY` = 32 | 0 = not intensive | 1 | §4 COMPONENT_COLUMNS | Per-day policy latch. |
| FishHabitat active list | `_live_habitat_slots` | 4 | `FISH_HABITAT_CAPACITY` = 32 | Only `[0, _live_habitat_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | ARCH-SAVE-002 rebuilds active lists ascending. |
| FishStock occupancy | `_stock_present` | 1 | `FISH_STOCK_CAPACITY` = 96 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Owner-major at `habitat * 3 + species slot`. |
| FishStock identity | `_stock_habitat_slot`, `_stock_habitat_generation`, `_stock_species_id` | 4 | `FISH_STOCK_CAPACITY` = 96 | `-1`/0 null ref | 1 | §4 COMPONENT_COLUMNS | `_stock_species_id` indexes `fishing.gd`'s own nine-row `SPECIES_KEYS`, NOT a compiled item id; `resource_catalog_binding.gd` owns the translation and warns that sorting the two together associates the wrong habitats. |
| FishStock quantities | `_stock_population_milli`, `_stock_capacity_milli`, `_stock_harvested_today_milli` | 8 | `FISH_STOCK_CAPACITY` = 96 | 0 | 1 | §4 COMPONENT_COLUMNS | `_stock_harvested_today_milli` resets daily, so it is future-affecting across a midnight save. |
| FishStock closure flags | `_stock_closed`, `_stock_restocking` | 1 | `FISH_STOCK_CAPACITY` = 96 | 0 = open / not restocking | 1 | §4 COMPONENT_COLUMNS | Closure survives a reload or a closed fishery reopens itself. |
| FishingEffortClaim (u8) | `_effort_claim_active` | 1 | `FISHING_EFFORT_CLAIM_CAPACITY` = 512 | `_effort_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A live claim on habitat effort slots: exactly task 09.1's "clocks/leases/claims". Indexed by the OWNING EXPEDITION'S typed row, so the row index itself is identity and the loader must not compact these rows. FISH-ID-R01 / decision0167 stores the full Expedition slot/generation pair; typed row plus generation aliases a new owner after cross-kind slot reuse. |
| FishingEffortClaim (i32) | `_effort_claim_expedition_generation`, `_effort_claim_habitat_slot`, `_effort_claim_habitat_generation`, `_effort_claim_job_slot`, `_effort_claim_job_generation`, `_effort_claim_slot_count`, `_effort_claim_expedition_slot` | 4 | `FISHING_EFFORT_CLAIM_CAPACITY` = 512 | `_effort_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| Fishing claim count | -- | -- | -- | -- | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_effort_claim_count` is recomputed from `_effort_claim_active`; capture validates it, restore derives it privately. |
| Effort tally scratch | `_effort_total_scratch` | 4 | `FISH_HABITAT_CAPACITY` = 32 | Refilled per pass | 3 | -- | Per-habitat running total inside one effort pass. |
| Fishing scratch | -- | -- | -- | -- | 3 | -- | `_math`, `_math_b`, `_math_c`, `_pending_claim_row`, `_pending_habitat_slot`, `_owns_directory`. |
| Claim-column diagnostic | -- | -- | -- | -- | 3 | -- | `_last_claim_column_refusal` belongs only to the exact section7 claim boundary. Code echo; failure-only owner write, cleared on success. Local Columns/tally objects are cold staging and do not add canonical fields. |

### `godot/scripts/core/forage.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| HarvestZone occupancy | `_zone_present` | 1 | `HARVEST_ZONE_CAPACITY` = 128 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| HarvestZone configuration | `_zone_type`, `_zone_danger` | 4 | `HARVEST_ZONE_CAPACITY` = 128 | None; every live zone has both | 1 | §4 COMPONENT_COLUMNS | `_zone_type` indexes the compiled `ZoneType` domain. |
| HarvestZone quota | `_zone_quota_milli` | 8 | `HARVEST_ZONE_CAPACITY` = 128 | 0 = no manual quota | 1 | §4 COMPONENT_COLUMNS | Player policy in milli units. |
| HarvestZone policy flags | `_zone_protected`, `_zone_enabled` | 1 | `HARVEST_ZONE_CAPACITY` = 128 | 0/1 flags with no absence value | 1 | §4 COMPONENT_COLUMNS | Set by SET_POLICY; decision 0030 §4.6. |
| HarvestZone identity and basin | `_zone_ref_slot`, `_zone_ref_generation`, `_zone_basin_slot`, `_zone_basin_generation` | 4 | `HARVEST_ZONE_CAPACITY` = 128 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | Copies of directory pairs; the directory's `_generation` remains authoritative. |
| HarvestZone daily quota accounting | `_zone_harvested_today_milli`, `_zone_quota_reserved_milli` | 8 | `HARVEST_ZONE_CAPACITY` = 128 | 0 | 1 | §4 COMPONENT_COLUMNS | `_zone_quota_reserved_milli` is quantity promised to live claims; dropping it double-issues a quota after a reload. |
| HarvestZone quota mode | `_zone_quota_mode` | 1 | `HARVEST_ZONE_CAPACITY` = 128 | Byte enum; 0 is a real mode, not absence | 1 | §4 COMPONENT_COLUMNS | Bounded by `QUOTA_MODE_COUNT` at load. |
| HarvestZone child heads and counts | `_zone_link_head`, `_zone_tile_count`, `_zone_patch_count` | 4 | `HARVEST_ZONE_CAPACITY` = 128 | `_zone_link_head == -1` (`NO_LINK`) for a zone with no tiles | 1 | §5 CHILD_ARENAS | The head of the zone's tile-link chain. ARCH-SAVE-002 writes child arrays owner-ascending with "explicit variable lengths" before the data, which is what `_zone_tile_count` is. |
| HarvestZone active list | `_live_zone_slots` | 4 | `HARVEST_ZONE_CAPACITY` = 128 | Only `[0, _live_zone_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | ARCH-SAVE-002 rebuilds active lists ascending. |
| Zone/tile link arena | `_link_tile`, `_link_zone`, `_link_tile_next`, `_link_zone_next` | 4 | `ZONE_LINK_CAPACITY` = 16384 | `-1` (`NO_LINK`) terminates either chain; a free link is on the `_link_free_head` list | 1 | §5 CHILD_ARENAS | 16384 links threaded into two intrusive lists. Chain ORDER is insertion order and is observable, so the arena is written as chains rather than re-derived by scanning ascending. |
| Tile-to-zone index | `_tile_link_head` | 4 | `TILE_COUNT` = 16384 | `-1` (`NO_LINK`) for a tile in no zone | 1 | §1 WORLD | `WorldTileMaps.zone_link_head` in §2's ledger (systems_architecture.md:397), so it is a stored field even though it is reachable from the arena. |
| ForagePatch columns (u8) | `_patch_present` | 1 | `FORAGE_PATCH_CAPACITY` = 640 | `_patch_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | Owner-major at `zone_slot * 5 + kind`. `_patch_item_id` is a compiled `ItemDefinition` id bound by `resource_catalog_binding.gd`. `_patch_harvested_year_milli` is a per-year total, so it must survive a mid-year save. |
| ForagePatch columns (i32) | `_patch_item_id`, `_patch_zone_slot`, `_patch_zone_generation` | 4 | `FORAGE_PATCH_CAPACITY` = 640 | `_patch_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| ForagePatch columns (i64) | `_patch_stock_milli`, `_patch_capacity_milli`, `_patch_harvested_year_milli` | 8 | `FORAGE_PATCH_CAPACITY` = 640 | `_patch_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| ForageClaim columns (u8) | `_claim_active` | 1 | `FORAGE_CLAIM_CAPACITY` = 8192 | `_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Live claims against a zone's quota, indexed by the OWNING JOB'S typed row (decision 0030 §4.7). `_claim_remaining_milli` is work-in-progress and `_claim_created_tick` orders expiry: both are exactly what task 09.1 means by cargo/WIP and claims. |
| ForageClaim columns (i32) | `_claim_job_slot`, `_claim_job_generation`, `_claim_designation_slot`, `_claim_designation_generation`, `_claim_basin_slot`, `_claim_basin_generation`, `_claim_patch_kind` | 4 | `FORAGE_CLAIM_CAPACITY` = 8192 | `_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| ForageClaim columns (i64) | `_claim_remaining_milli`, `_claim_created_tick`, `_claim_persistent_id` | 8 | `FORAGE_CLAIM_CAPACITY` = 8192 | `_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| Forage link allocator | -- | -- | -- | `_link_free_head == -1` (`NO_LINK`) when the free list is empty | 1 | §5 CHILD_ARENAS | `_link_bump`, `_link_free_head` and `_link_used`. A bump pointer plus a free LIST, not a min-heap: like `inventory.gd`'s stacks and unlike `entity_directory.gd`'s heaps, the order it hands links out depends on the list contents, so it must be written. |
| Forage live counts | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_live_zone_count` and `_claim_count`, recomputed from `_zone_present` and `_claim_active`. |
| Forage scratch | -- | -- | -- | `_pending_*` use `-1` / `NULL_SLOT` between calls | 3 | -- | `_math`, `_math_b`, `_math_c`, `_pending_designation_slot`, `_pending_basin_slot`, `_pending_patch_row` and `_owns_directory`. |
| Claim-column diagnostic | -- | -- | -- | -- | 3 | -- | `_last_claim_column_refusal` belongs only to the exact section7 claim boundary. Code echo; failure-only owner write, cleared on success. Local Columns/tally objects are cold staging and do not add canonical fields. |

### `godot/scripts/core/gear.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| GearInstance columns | `_lot_slot`, `_lot_generation`, `_item_id`, `_durability`, `_durability_cap`, `_owner_slot`, `_owner_generation`, `_manufacture_recipe` | 4 | `_row_capacity` <= 16384 | `_lot_slot`/`_owner_slot` hold `-1` with generation 0 for the null ref | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A GEAR ROW HAS NO GENERATION OF ITS OWN. `_lot_generation` is the inventory LOT's local generation and `_owner_generation` is the resident's DIRECTORY generation -- two different generation spaces in one row. The module's header records that a persistent `GearRef` "needs budgeted generations and a retirement rule" and that none is budgeted, so gear rows are addressed by row index only: §7 must write them in row order and a load must not compact them. |
| Gear occupancy and equip flag | `_equipped`, `_occupied` | 1 | `_row_capacity` <= 16384 | `_occupied == 0` is a free row; `_equipped == 0` is stowed | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset plus the equip state a reload must preserve. |
| Gear job claims | `_claim_job_slot`, `_claim_job_generation` | 4 | `_row_capacity` <= 16384 | `_claim_job_slot == -1` with generation 0 means unclaimed | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A live tool claim by a job: task 09.1's "claims". The existing live Gear API bounds the claim slot by 8192; the codec bounds 352418. The prior DIRECTORY-generation interpretation requires explicit Jobs/Work integration reconciliation. SAVE-GEAR-R01v2 preserves the existing numeric pair and refuses incompatible slots without remapping. |
| Gear free heap | `_free_heap` | 4 | `_row_capacity` <= 16384 | Only `[0, _free_count)` is live | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | A min-heap like `entity_directory.gd`'s, so ARCH-SAVE-002's rebuild permission applies: allocation order depends on the free set, not the permutation. |
| Gear lot index | `_lot_row` | 4 | `LOT_CAPACITY` = 16384 | -1 means no Gear row for the lot slot | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Decision 1068. Exact private lot-slot to Gear-row relation; reads recheck occupancy and full recorded lot identity. Rebuilt from validated occupied rows on both restoration paths; never saved or hashed. Whole-column restore privately stages one additional 65536-byte index before publication. Capture/audit verify both directions. |
| Starter-seed rollback buffer | `_seed_lot_slot`, `_seed_lot_generation` | 4 | `STARTER_TOOL_TOTAL` = 24 | Only `[0, _seed_count)` is meaningful during seeding; successful completion leaves 24 as residue, while clear/rollback reset it | 3 | -- | CONSTRUCTION-TIME RECORD, NOT AUTHORITATIVE STATE. That is an explicit call, made by the author of the column (decision 0061), not a default. It holds the lot references that one in-flight `seed_starter_tools()` has created so far, so `_rollback_seed()` can undo exactly those and nothing else; nothing reads it once the call returns, and it records no fact that is not already in the gear rows above and `inventory.gd`'s lot rows. `seed_starter_tools()` is a single synchronous call and ARCH-SAVE-003 saves only at a completed tick boundary, so no save can observe a half-seeded state. Domain, per the 2026-09-11 addendum: the pair is an INVENTORY LOT reference (`_l_generation`), not a container ref and not a directory ref, so anything that ever does validate it must validate it there. RESOLVED by STATE-COHORT-R01 (2026-09-11): residents.gd's analogous `_cohort_slots` rollback buffer is category 3 too; the earlier category-1 founder-history interpretation is superseded. |
| Gear derived scalars | -- | -- | -- | `_id_* == -1` means the item key was not resolved | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_row_capacity` is a construction argument; `_free_count` and `_active_count` derive from occupancy, `_equipped_count` from equipped rows. Five `_id_*` fields are re-resolved from the verified loaded catalog by exact bulk restoration. Missing catalog keys may remain -1. Capture compares these caches without changing them. |
| Gear transient state and bindings | -- | -- | -- | `_restoring` must be false at a legal boundary | 3 | -- | `_restoring`, `_last_column_refusal`, `_wear_math`, `_inventory`, `_directory_binding`, `_residents` are transient guard/diagnostic/scratch and borrowed wiring. SAVE-GEAR-R01v2 preserves scratch and bindings, refreshes derived catalog IDs only on successful restore, and requires existing bindings before installing equipped rows. It does not attest mirrors, liveness or a whole world. |

### `godot/scripts/core/ground_piles.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Breadth-first visit mask | `_visited` | 1 | `TILE_COUNT` = 16384 | Refilled to 0 per placement | 3 | -- | [Decision 0532](decisions/0532-ground-piles-are-placed-breadth-first-and-reclaimed-at-commit.md): DEMO-CONTAIN-R01 #9's N, E, S, W spill scratch. Holds nothing between calls; every placement is one inventory transaction that commits or rolls back before it returns, except `place_lots_from_seeds_in_transaction()` ([decision 0535](decisions/0535-demolition-completion-is-one-commit-and-furniture-refuses.md)), which writes into its caller's transaction and leaves the commit or abort to it. |
| Breadth-first queue | `_queue` | 4 | `TILE_COUNT` = 16384 | Only `[0, _queue_tail)` is meaningful, for the last call | 3 | -- | The examined-and-eligible tile order. After a commit it is walked once more to declare storage class 1500 on new piles -- by the helper itself, or by `declare_placed_piles()` after the caller's commit for the in-transaction variant (decision 0535) -- then it is dead. Still nothing to save: the declarations it leads to are StockAge's. |
| Borrowed destroyed-footprint mask | `_excluded` | 1 | never allocated | Empty outside a placement call | 3 | -- | The caller's 16384-byte mask, held by reference for one call so the site authority Inventory calls back into can refuse a destroyed footprint whose Building row is already gone. Released before the call returns. |
| Refund ring sort keys | `_seed_keys` | 8 | `REFUND_SEED_CAPACITY` = 512 | `INT64_MAX` past the ring | 3 | -- | DEC-043's 2026-10-01 follow-up ruling: a doorless building's refund starts from its footprint's edge ring, nearest its front first. One `distance * 16384 + tile` key per ring tile, sorted in place; scratch for one `refund_seeds_into()` call. |
| Single start tile | `_single_seed` | 4 | `1` = 1 | Overwritten per call | 3 | -- | Lets `place_lots_into_piles(start_tile, ...)` share the seeded walk without allocating a one-cell array per call. |
| Composer bindings and cursor | -- | -- | -- | -- | 3 | -- | `_inventory`, `_buildings`, `_stock_age`, `_spatial` and `_world_ref` are borrowed wiring rebound by the composer's owner; `_queue_tail`, `_spec_row` and `_spec_remaining` are call scratch, and so is `_move_source`, the container [decision 1022](decisions/1022-a-satchel-is-made-per-haul-and-the-claim-travels-with-the-goods.md)'s mover empties during one call. The module owns no simulation state: piles are Inventory rows and their storage class is StockAge's declaration. |

### `godot/scripts/core/haul_carry.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Re-claim record | `_reclaim` | 8 | `ReservationsScript.CLAIM_STRIDE` = 5 | Overwritten per use | 3 | -- | [Decision 1022](decisions/1022-a-satchel-is-made-per-haul-and-the-claim-travels-with-the-goods.md): task 06.4 H1's one-row claim buffer, used only by the unreachable rollback after a refused ground-pile unload. The haul's carry owns NO state: the satchel and its lots are Inventory rows (section 7), the claims are the pool's rows (section 7), and the resident's `Equipment.satchel` pair is `residents.gd`'s (section 4). |
| Composer bindings and scratch | -- | -- | -- | -- | 3 | -- | `_inventory`, `_reservations`, `_residents` and `_piles` are borrowed wiring; `_math`, `_expiry` and `_place` are call scratch. |

### `godot/scripts/core/haul_planner.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Admitted haul and its destination | `_job_generation`, `_dest_slot`, `_dest_generation`, `_dest_tile` | 4 | `JOB_CAPACITY` = 8192 | `_job_generation == 0` for no admission; the destination pair is `(-1, 0)` for a ground-pile destination; `_dest_tile == -1` (`NO_TILE`) for no admission | UNRESOLVED | §4 COMPONENT_COLUMNS | [Decision 1023](decisions/1023-haul-payloads-are-sized-at-assignment-and-go-to-the-lowest-eligible-store.md): task 06.4 H2, indexed by the reservation pool's Job key (slot 0..8191). Binds Inventory's anonymous `reserved_mass_g`, taken when a haul is admitted (REQ-SET-030), to the Job that will release it with the unload, and names the tile the hauler unloads at (a store's anchor, or R2's first eligible pile seed). The destination pair is an INVENTORY CONTAINER ref; the generation is the pool's Job key generation. QUESTION: which §4 owner and ordinals carry it once the Job store's HAUL jobs are saved (slice H8)? Without it a load keeps section 7's reserved mass and the pool's HAUL claims but loses which store the grams belong to. |
| Admitted destination grams | `_reserved_g` | 8 | `JOB_CAPACITY` = 8192 | 0 with no admission or a ground-pile destination | UNRESOLVED | §4 COMPONENT_COLUMNS | The payload's `ceil(q * m / 1000)` charge, reserved in the destination store at admission and released, exactly, by the unload's own transaction (`complete_unload()` through `reservations.deliver_claim()`, which also retires the record) or by `cancel()`; `audit()` checks per store that the records never hold more than the store reserves. QUESTION: which §4 owner and ordinals carry it, beside the destination pair? |
| Source footprint and its complement | `_footprint`, `_outside` | 1 | `InventoryScript.ANCHOR_TILE_COUNT` = 16384 | All 0 and all 1 between calls; only the source footprint's rectangle is written during one and restored after | 3 | -- | Decision 0534's R1 "off the footprint", reused for hauling: the source building's tiles, marked by `ground_piles.refund_seeds_into()`, and the mask `inventory.next_container_anchored_in()` walks. Cold path. |
| Refund seeds | `_seeds` | 4 | `GroundPilesScript.REFUND_SEED_CAPACITY` = 512 | Only the first `_seed_count` cells are meaningful, for the last call | 3 | -- | R2's pile fallback origin for the source building: its door, else its front-first ring (DEC-043). |
| Placement spec | `_spec` | 8 | `GroundPilesScript.SPEC_STRIDE` = 7 | Overwritten per call | 3 | -- | One `preflight_lots_from_seeds()` row carrying the source lot's attributes and the payload. |
| Claim record | `_claim` | 8 | `ReservationsScript.CLAIM_STRIDE` = 5 | Overwritten per call | 3 | -- | The one HAUL_SOURCE row `admit()` hands the pool's `claim_batch()`. |
| Unload seed | `_one_seed` | 4 | `1` = 1 | Overwritten per call | 3 | -- | The recorded unload tile as a one-cell seed buffer for `complete_unload()` onto ground piles. |
| Bindings and scratch | -- | -- | -- | -- | 3 | -- | `_inventory`, `_reservations`, `_residents`, `_buildings`, `_piles` and `_store_policy` (decision 1031) are borrowed wiring; `_seed_count`, `_math`, `_place` and `_chosen` are call scratch. |

### `godot/scripts/core/haul_transfer_contract.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Guarded hauling protocol | -- | -- | -- | -- | 3 | -- | [Decision1141](decisions/1141-guarded-spatial-haul-transfers.md). Stateless permission-refusing base and fixed216-byte caller packets. The two retained packets belong to Reservations below; no canonical column, independent bank or duplicate economic ledger. |

### `godot/scripts/core/households.gd`

[Decision 0521](decisions/0521-pc04-adopted-with-children-inactive.md) / FAMILY-STATE-R01. PC-04's household and dependent-care owner, adopted with children inactive. **No settlement composes it yet**, so no live world holds a row; when one does, every column below is future-affecting state. The rows are UNRESOLVED rather than category 1 because category 1 here must equal `canonical_state_registry.json` exactly (`validate_save_registry_handoff.py`), and the owner ID, ordinals and declaration hashes are the activation packet's to allocate (FAMILY-STATE-R01 §Save; gate 3). The sections cited are the ones FAMILY-STATE-R01 names.

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Household presence | `_h_present` | 1 | `HOUSEHOLD_CAPACITY` = 256 | 0 = free row | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 owner ID and ordinals does the activation packet assign? Present rows hold 1..8 living members. |
| Household identity and count | `_h_generation`, `_h_persistent_id`, `_h_member_count` | 4 | `HOUSEHOLD_CAPACITY` = 256 | free row: generation retained 0..I32_MAX, ID 0, count 0 | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 ordinals does the activation packet assign? Generation is this owner's OWN namespace -- a fifth generation space, never the directory's; retirement keeps it, so a reused row is a new identity, and a row at I32_MAX is permanently retired. IDs are monotonic from 1 and never recycled. |
| Household member arena | `_h_member_slot`, `_h_member_generation` | 4 | `MEMBER_CAPACITY` = 2048 | `(-1, 0)` | UNRESOLVED | §5 CHILD_ARENAS | Which §5 arena declaration does the activation packet assign? Index `row*8 + ordinal`; resident DIRECTORY EntityRefs in strictly ascending persistent ID, null tail. Validated jointly with the parent rows and the dependent back-references in one call. |
| Dependent bytes | `_d_present`, `_d_care_eligible`, `_d_warning_bits`, `_d_willing` | 1 | `RESIDENT_CAPACITY` = 512 | all 0 | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 ordinals does the activation packet assign? Indexed by the RESIDENT typed row; presence follows Residents. Warning bits are 0, 1 or 3 (critical implies low). Willing defaults 1 for ADULT/ELDER and is 0 for CHILD. |
| Dependent references and care | `_d_resident_slot`, `_d_resident_generation`, `_d_household_row`, `_d_household_generation`, `_d_preferred_0`, `_d_preferred_1`, `_d_care`, `_d_provider_slot`, `_d_provider_generation`, `_d_service_paired_ticks`, `_d_provider_served_ticks_today` | 4 | `RESIDENT_CAPACITY` = 512 | bound resident `(-1, 0)`, household `(-1, 0)`, preferences 0, care 0, provider `(-1, 0)`, counters 0 | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 ordinals does the activation packet assign? `resident_slot` + `resident_generation` bind the row to the resident's WHOLE directory EntityRef ([decision 0996](decisions/0996-household-bindings-keep-the-whole-directory-ref.md), review R04: a generation alone belongs to a directory slot, so a typed row reused under another slot at the same generation would otherwise inherit the row); the provider ref is a directory EntityRef; preferences are persistent IDs, never live slots. A stable saved turn holds 0..749. |
| Care remainder | `_d_care_remainder` | 8 | `RESIDENT_CAPACITY` = 512 | 0 | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 ordinal does the activation packet assign? Magnitude < 750000; 0 outward at a reached bound. |
| Household and day scalars | -- | -- | -- | -- | UNRESOLVED | §4 COMPONENT_COLUMNS | Which §4 scalar records does the activation packet assign? `_next_household_id` (i64, 1..2147483648) and `_served_day` (i64, the current absolute world day). |
| Care step scratch | `_care_step` | 8 | `CARE_STEP_WIDTH` = 2 | refilled per child row | 3 | -- | `care_after_tick()`'s two outputs, consumed before the next row. |
| Collaborators and scratch | -- | -- | -- | -- | 3 | -- | `_residents` and `_directory` are composition references; `_calendar` is restore scratch. |

### `godot/scripts/core/int_math.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Checked integer arithmetic | -- | -- | -- | -- | 3 | -- | Pure functions and one `IntResult` value class; no module-level `var` and no state. Listed so the registry covers every file under `godot/scripts/core/` and a future state field here cannot slip in unclassified. |

### `godot/scripts/core/injury.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Injury row bytes and latches | `_present`, `_kind`, `_airless_episode`, `_exhaustion_latch`, `_care_context_blocked` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row; `_kind == 0` (`KIND_NONE`) means no aggregate injury | 1 | §4 COMPONENT_COLUMNS | Decision 0109. `_kind` is GDD §4.3's `InjuryKind`, derived from `catalog.gd`'s protected domain rather than transcribed. HAZ-002/003's latches are future-affecting: losing `_airless_episode` creates a SECOND EXPOSURE incident on reload for one the world already resolved. |
| Injury severity and rescuer reference | `_severity`, `_rescuer_slot`, `_rescuer_generation` | 4 | `RESIDENT_CAPACITY` = 512 | `_severity == 0` when uninjured; `_rescuer_slot == -1` with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | GDD §4.2's `Injury.severity` and `Injury.rescuer`. The rescuer is an EntityRef in the **directory's** slot/generation space, not a row index in this store -- one of the four distinct generation namespaces. |
| Injury clocks, care work and incident ordinal | `_untreated_ticks`, `_care_progress_mwu`, `_last_incident_ordinal` | 8 | `RESIDENT_CAPACITY` = 512 | 0 | 1 | §4 COMPONENT_COLUMNS | `untreated_hours` is the floor of `_untreated_ticks` over 750, following `_starving_ticks`. `_last_incident_ordinal` is HAZ-004's one-shot dedup latch: dropping it lets a replayed hazard charge twice. |
| Injury counters and scratch | -- | -- | -- | -- | 3 | -- | `_present_count`, `_injured_count`, `_last_refused_slot`, `_out_value`, `_math`. |

### `godot/scripts/core/inventory.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Container identity and policy | `_c_owner_slot`, `_c_owner_generation`, `_c_policy`, `_c_generation`, `_c_lot_count`, `_c_first_lot` | 4 | `_c_capacity` <= 101376 | `_c_owner_slot == -1` with generation 0 is the null ref; `_c_first_lot == -1` means no lots | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_c_generation` IS THIS MODULE'S OWN GENERATION SPACE, not the directory's. The header (lines 69-72) records that ARCH-ID-001 gives both containers and lots a directory kind but that "this module allocates its own slots". A container `EntityRef` therefore validates against `_c_generation`, and §7 must carry it in full for the same reason §3 carries the directory's -- two independent generation spaces that 09.2 must not merge. |
| Container mass and filters | `_c_max_mass_g`, `_c_filters`, `_c_reserved_mass_g`, `_c_used_mass_g` | 8 | `_c_capacity` <= 101376 | 0 | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | ARCH-SAVE-005 validates that charged mass plus reserved mass does not exceed capacity. `_c_used_mass_g` and `_c_reserved_mass_g` are also recomputable from the lot chain; they are written and cross-checked, not chosen between. |
| Container occupancy | `_c_live` | 1 | `_c_capacity` <= 101376 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset, and INV-CANON-R01's SOLE test of liveness. A row at 1 is copied into the save/hash projection exactly; a row at 0 is emitted at the ruling's unused-value table -- `_c_owner_slot` -1, `_c_owner_generation` 0, `_c_policy` 0, `_c_lot_count` 0, `_c_first_lot` -1, `_c_max_mass_g` 0, `_c_filters` 0, `_c_reserved_mass_g` 0, `_c_used_mass_g` 0, `_c_reachable` 0, and (decision 0531) `_c_anchor_tile` -1 -- while `_c_generation` is copied UNCHANGED. The mask is never applied on container nullness, quantity, reachability or list membership. |
| Container reachability | `_c_reachable` | 1 | `_c_capacity` <= 101376 | 0 = unreachable, and also the value every row starts at | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | GDD §4.2 / decision 0063: explicit container state, no current deterministic rebuild owner. Save/hash live 0/1 exactly; canonical zero for unused payload. Future topology derivation requires an explicit owning-contract/schema amendment, not a default. |
| Container anchor | `_c_anchor_tile` | 4 | `_c_capacity` <= 101376 | `-1` (`UNPLACED_TILE`) = a container on no tile -- a satchel, an expedition pack -- and the value every row starts at | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | DEMO-CONTAIN-R01 #1/#2/#8, [decision 0531](decisions/0531-demolition-containment-is-adopted-and-containers-carry-an-anchor-tile.md): one placement cell per container, `0..16383` = GDD §5.1's `z*128+x`, interiors on the same grid. NOT derivable from any other store -- Buildings holds no Inventory ref, and owner equality proves ownership, not placement (decision 0145) -- so it is written, hashed and refused rather than rebuilt. Inventory owner schema 4 / section schema 5 append it as ordinal 30; schema 3/4 bodies are refused, never migrated. Live rows save their exact cell; an inactive row's residue is emitted as -1. Written only by `create_container()` and `set_container_anchor()`, both domain-checked and journaled; read by the bounded cold-path `containers_anchored_in_into()`. A placement CELL, so MOVE-G02's level encoding may later widen its meaning without widening the column. |
| Spatial endpoint identities | `_spatial_container_slot`, `_spatial_container_generation`, `_spatial_location_slot`, `_spatial_location_generation` | 4 | `capacity` runtime | slot -1/generation 0 | 1 | §6 AUXILIARY_STATE | Decisions1076/1072 amend the preceding surface-anchor row: four sparse full-ref columns. Actual Locations owns XYZ/Room/section. The dedicated spatial admission door writes container anchor -2-row, which is private and reverse-validated; ordinary setters cannot write it. No surface alias. Requires a new mandatory versioned extension in UG16; legacy capture/restore refuse live endpoints and the flat complete-footprint query refuses partial results. |
| Spatial endpoint payload revision | `_spatial_location_revision` | 8 | `capacity` runtime | 0 for unused | 1 | §6 AUXILIARY_STATE | Positive immutable location-payload revision; actual geometry qualification is fresh. The existing shared 14-cell journal snapshots all five fields atomically. Together 24C live bytes. `_spatial_authority` and `_spatial_checked_revision` are category3 wiring/transient scratch. Decision1072 additionally persists the configured capacity and full `_spatial_world` binding in this mandatory extension; it must agree with the actual World, never act as a second world/position owner. |
| Ground-pile tile map | `_pile_at_tile` | 4 | `ANCHOR_TILE_COUNT` = 16384 | `-1` (`NO_PILE`) = no pile on that tile | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | DEMO-CONTAIN-R01 #9's OPTIONAL derived tile -> pile map, approved with #9, [decision 0532](decisions/0532-ground-piles-are-placed-breadth-first-and-reclaimed-at-commit.md). The container SLOT of the live `POLICY_GROUND_PILE` row anchored on each tile. Fully derivable from category-1 `_c_live`, `_c_policy` and `_c_anchor_tile`, so it is NEVER written: `restore_canonical_columns()` refuses an unplaced pile or two piles on one tile BEFORE adopting, then `_rebuild_derived_state()` rebuilds it. Journaled per cell so a rollback restores it with the rows; `audit()` re-derives it; `state_bytes()` includes it because rollback must restore it exactly. 65536 B, ledgered in ARCH §2.3. |
| Ground-pile reclaim candidates | `_pile_candidates` | 4 | `JOURNAL_CAPACITY` = 4096 | Only `[0, _pile_candidate_count)` is live | 3 | -- | Decision 0532 / ARCH-MEM-002: the slots of the piles the open transaction created or took a lot out of, so a successful commit retires the ones left with no lot and no reserved mass. Transaction scratch like the undo journal: cleared at begin, rollback, clear and restore, empty at every legal save point. `_pile_candidate_count`, `_pile_candidates_overflowed`, `_site_owner` and the borrowed `_ground_pile_authority` belong to the same transient group. 16384 B, ledgered in ARCH §2.3. |
| Lot identity and chain | `_l_item_id`, `_l_quality`, `_l_provenance`, `_l_recipe_id`, `_l_container_slot`, `_l_container_generation`, `_l_generation`, `_l_next`, `_l_prev` | 4 | `_l_capacity` <= 16384 | `_l_next`/`_l_prev` hold `-1` at the ends of a container's chain; `_l_container_slot == -1` with generation 0 on a LIVE lot means EQUIPPED, not free | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_l_generation` is the second local generation space described above. The doubly linked chain order is observable to merge and withdrawal order, so it is written as a chain rather than re-derived from `_l_container_slot` ascending. DECISION 0061 GAVE `_l_container_slot == -1` A MEANING: a live lot with a null container is an equipped gear record held by a resident, threaded into no chain and charging no container's mass. A loader must not read it as a free row -- `_l_live` is what says free -- and must not attach it to a container. The pairing is exact in both directions: the container is null if and only if `gear.gd` attests an equipped record with a live owner, which `inventory.audit()` re-derives per lot and refuses as `AUDIT_ORPHAN_LOT` otherwise.  Value domain `InventoryProvenance` (decision 0113), members 0..5 inclusive: ORDINARY, STARTER, COASTAL_BRINE, EXCAVATION, BACKFILL_RECLAIM, SPOIL_RECLAIM. A stored value outside that set is REFUSED at load, never clamped -- `UNSET_PROVENANCE` is the compatibility spelling of ORDINARY, not a seventh member and not an unknown wildcard. |
| Lot quantities and age | `_l_quantity_milli`, `_l_reserved_milli`, `_l_age_milli_hours`, `_l_age_remainder` | 8 | `_l_capacity` <= 16384 | 0 | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `quantity_milli` int64 per AGENTS.md. `_l_age_remainder` is the sub-hour spoilage remainder task 09's acceptance list calls out by name; a negative or truncated age inverts every downstream spoilage result, so ARCH-SAVE-005's `quantity>=0` and `0<=reserved<=quantity` checks apply here and refusal is the only legal response. |
| Lot occupancy | `_l_live` | 1 | `_l_capacity` <= 16384 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset, and INV-CANON-R01's SOLE test of liveness for a lot. A row at 0 is emitted at the unused-value table -- `_l_item_id` 0, `_l_quality` 0, `_l_provenance` 0 (ORDINARY, a real member and not an unknown wildcard), `_l_recipe_id` 0, `_l_container_slot` -1, `_l_container_generation` 0, `_l_next` -1, `_l_prev` -1, `_l_quantity_milli` 0, `_l_reserved_milli` 0, `_l_age_milli_hours` 0, `_l_age_remainder` 0 -- and `_l_generation` is copied UNCHANGED. THE STORE IS NOT BLANKED AT RETIREMENT and must not be: `_apply_transfer()` retires the source before `_credit_new_lot()` reads its attributes, and with one free lot slot that same slot returns under a new generation. `_l_reserved_milli` 0 on a dead row is the reserved-merge residue case -- `_apply_merge()` moves the claim to the destination and leaves the number behind -- and normalizing it creates no second claim, because occupancy is decisive. |
| Free-slot stacks (i32) | `_c_free` | 4 | `_c_capacity` <= 101376 | Only `[0, _c_free_count)` / `[0, _l_free_count)` is live | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A STACK, NOT THE DIRECTORY'S MIN-HEAP -- and INV-CANON-R01 preserves the USED PREFIX IN POP ORDER while rebuilding the excluded tail to -1, because prefix membership is half of what separates a free-INT32_MAX slot (still allocatable once more) from a retired-INT32_MAX one. Occupancy is the other half. Rebuilding the stack, sorting it, or filtering INT32_MAX rows out of it collapses three distinct states into fewer (comment at line 259). Pop order is therefore last-freed-first and depends on the array contents, so unlike `entity_directory.gd`'s heaps this allocator is NOT reconstructible from occupancy and must be written. ARCH-SAVE-002's "save allocator heaps or rebuild them" resolves to "save" for this store. |
| Free-slot stacks (i32) | `_l_free` | 4 | `_l_capacity` <= 16384 | Only `[0, _c_free_count)` / `[0, _l_free_count)` is live | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| Item catalog facts (i32) | `_item_mass_g`, `_item_category` | 4 | `ITEM_CAPACITY` = 256 | `_item_registered == 0` means the id has no registered mass | 2 | §2 CATALOG_IDS | The module's own comment: "Catalog-time item facts. Not simulation state". Re-registered from the verified catalog on load. |
| Item catalog facts (u8) | `_item_registered` | 1 | `ITEM_CAPACITY` = 256 | `_item_registered == 0` means the id has no registered mass | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Conservation ledger | `_sourced_milli`, `_sunk_milli` | 8 | `ITEM_CAPACITY` = 256 | 0 | 3 | -- | Lifetime totals read only by `audit()`. Dropping them changes no future state; it changes only what a post-load audit reports, and the audit compares live quantities either way. |
| Undo journal (i32) | `_j_kind`, `_j_index` | 4 | `JOURNAL_CAPACITY` = 4096 | Only `[0, _j_count)` is live | 3 | -- | The module labels this "scratch, not authoritative state". ARCH-SAVE-003 saves only a completed boundary, so `_tx_open` is false and the journal is empty at every legal save point; 09.2 should assert that rather than serialize it. |
| Undo journal (i64) | `_j_row` | 8 | `JOURNAL_CAPACITY * ROW_STRIDE` = 57344 | Only `[0, _j_count)` is live | 3 | -- | See the first row of this group. |
| Audit tally | `_audit_live_milli` | 8 | `ITEM_CAPACITY` = 256 | Refilled per audit | 3 | -- | Allocated once so `audit()` costs no allocation; holds nothing between audits. |
| Inventory counts and capacities | -- | -- | -- | -- | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_c_capacity`/`_l_capacity` are construction arguments; `_c_free_count`, `_l_free_count`, `_c_live_count` and `_l_live_count` are recomputed from `_c_live`/`_l_live` and the free stacks. `_equipped_lot_count` is recomputed the same way, from the live lots whose `_l_container_slot` is `-1`, and `audit()` already re-derives it rather than trusting it. |
| Transaction state and scan hints | -- | -- | -- | -- | 3 | -- | `_tx_open`, `_tx_poisoned`, `_tx_error`, `_tx_saved_*`, `_plan`, `_math`, `_out_ref`, `_out_value`. ARCH-SAVE-003 saves only a completed boundary, so `_tx_open` must be false at any legal save point. `_c_slot_high_water`/`_l_slot_high_water` are excluded by the module's own `state_bytes()` precisely so two byte images of identical state cannot differ over a scan hint. `_tx_saved_equipped_count` belongs to the same transaction group. `_equipment_authority` is a wiring reference to `gear.gd` and `_attesting` is a frame-local re-entry guard that is false outside an attestation: both rebind at load, and a loader must re-bind the authority before auditing, because with none bound every equipped lot reads as an orphan. |

INIT-COUNT-R01v2 / decision0159 adds nested caller-owned `StockCounts`, not owner
state: four256-entry i64 buffers (8192B), plus one8192B temporary staging record
per cold count. On success the target adopts independent staging buffers; no
persistent Inventory member, canonical field or schema version is added. The
single scan performs local structural validation without equipment callbacks;
full cross-owner attestation remains the audit/load coordinator's obligation.

### `godot/scripts/core/item_definitions.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Compiled item facts (i32) | `_nutrition_per_u`, `_shelf_hours`, `_effect_id`, `_effect_value` | 4 | `count` runtime | `_effect_id` holds the compiled `none` effect for items with no effect | 2 | §2 CATALOG_IDS | Loaded from `res://data/item_definitions.json` and sized to that file's key count, which is why the count is not a compile-time constant. Rebuilt by reloading the catalog whose hash the save header pins at offset 72; writing them would duplicate the artifact §2 already carries. |
| Compiled item facts (u8) | `_raw_edible`, `_seed` | 1 | `count` runtime | `_effect_id` holds the compiled `none` effect for items with no effect | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Catalog dictionaries and load flag | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_item_ids`, `_category_ids`, `_effect_ids`, `_item_count`, `_loaded`. Same argument: rebuilt by `load()` against the verified artifact. |
| Successful registration owner wiring | -- | -- | -- | Unbound before successful registration | 3 | -- | Decision 1056. `_registered_inventory` is a weak reference to the actual target of the last successful catalog registration. Failure leaves it unchanged. It is reconstructed and checked after load, never hashed or serialized as a pointer; a catalog rebound to another Inventory invalidates existing excavation composition. |

### `godot/scripts/core/job_index_schema.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Shared planner record schema | -- | -- | -- | -- | 3 | -- | Decision0160: pure shared layout, cold typed Record and structural validation. No live owner state. Planner and section8 codec consume the same definitions without a cycle. |

### `godot/scripts/core/job_planner.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Daily service request rows | `_owner_slot`, `_owner_generation`, `_service_day`, `_job_slot`, `_job_generation`, `_serviced_day` | 4 | `SERVICE_ROW_COUNT` = 8192 | `-1` slot with generation 0 is the null ref | 1 | §8 JOB_INDEXES | One row per (owner, operation). `_service_day`/`_serviced_day` are the pending/settled day pair; losing them re-requests or silently skips a day's tending. |
| Service request status | `_status`, `_requires_water` | 1 | `SERVICE_ROW_COUNT` = 8192 | Byte enums bounded by `STATUS_COUNT` | 1 | §8 JOB_INDEXES | Pending/created/completed/cancelled status of a live request. |
| Service request crop context | `_field_cycle`, `_requested_crop` | 4 | `SERVICE_ROW_COUNT` = 8192 | `_requested_crop == -1` (`NO_CROP`) | 1 | §8 JOB_INDEXES | The field cycle a sowing request belongs to, so a cycle cannot be served twice. |
| Service gate reason | `_gate_reason` | 1 | `SERVICE_ROW_COUNT` = 8192 | Byte enum bounded by `REASON_COUNT` | 1 | §8 JOB_INDEXES | Why a request is blocked; it selects the next evaluation's behaviour, not only the UI text. |
| Field cycle cursors | `_cycle_cursor`, `_completed_cycle` | 4 | `OWNER_CAPACITY` = 4096 | 0 = no cycle completed | 1 | §8 JOB_INDEXES | Per-owner sowing progress. |
| Forage demand enablement (u8) | `_demand_enabled` | 1 | `ZONE_OWNER_CAPACITY` = 128 | `_demand_owner_slot == -1` with generation 0 | 1 | §8 JOB_INDEXES | Standing demand per harvest zone. |
| Forage demand enablement (i32) | `_demand_owner_slot`, `_demand_owner_generation` | 4 | `ZONE_OWNER_CAPACITY` = 128 | `_demand_owner_slot == -1` with generation 0 | 1 | §8 JOB_INDEXES | See the first row of this group. |
| Forage demand rows (u8) | `_demand_status`, `_demand_blocker` | 1 | `DEMAND_ROW_COUNT` = 640 | `_demand_job_slot == -1` with generation 0 when no job is outstanding | 1 | §8 JOB_INDEXES | `_demand_quantified_milli` is a committed quantity: dropping it re-issues a forage job for goods already claimed. |
| Forage demand rows (i32) | `_demand_job_slot`, `_demand_job_generation` | 4 | `DEMAND_ROW_COUNT` = 640 | `_demand_job_slot == -1` with generation 0 when no job is outstanding | 1 | §8 JOB_INDEXES | See the first row of this group. |
| Forage demand rows (i64) | `_demand_quantified_milli` | 8 | `DEMAND_ROW_COUNT` = 640 | `_demand_job_slot == -1` with generation 0 when no job is outstanding | 1 | §8 JOB_INDEXES | See the first row of this group. |
| Hive service rows (i32) | `_hive_owner_slot`, `_hive_owner_generation`, `_hive_service_day`, `_hive_job_slot`, `_hive_job_generation` | 4 | `HIVE_OWNER_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §8 JOB_INDEXES | Decision 0051's hive-service slice, same argument as the field rows above. |
| Hive service rows (i64) | `_hive_feed_demand_milli` | 8 | `HIVE_OWNER_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §8 JOB_INDEXES | See the first row of this group. |
| Hive service rows (u8) | `_hive_status`, `_hive_blocker` | 1 | `HIVE_OWNER_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §8 JOB_INDEXES | See the first row of this group. |
| Dirty-row work lists (i32) | `_dirty_rows` | 4 | `OWNER_CAPACITY` = 4096 | Zero outside saved prefix | 1 | §8 JOB_INDEXES | SAVE-J2-R01 / decision 0157: preserve exact prefix order and membership with its saved count; unused tail is zero. |
| Dirty-row work lists (u8) | `_is_dirty` | 1 | `OWNER_CAPACITY` = 4096 | 0 outside saved membership | 2 | §8 JOB_INDEXES | Rebuild exactly from the corresponding saved dirty-list prefix; never mark all owners dirty. |
| Dirty-row work lists (i32) | `_dirty_zone_rows` | 4 | `ZONE_OWNER_CAPACITY` = 128 | Zero outside saved prefix | 1 | §8 JOB_INDEXES | SAVE-J2-R01 / decision 0157: preserve exact prefix order and membership with its saved count; unused tail is zero. |
| Dirty-row work lists (u8) | `_is_zone_dirty` | 1 | `ZONE_OWNER_CAPACITY` = 128 | 0 outside saved membership | 2 | §8 JOB_INDEXES | Rebuild exactly from the corresponding saved dirty-list prefix; never mark all owners dirty. |
| Dirty-row work lists (i32) | `_dirty_hive_rows` | 4 | `HIVE_OWNER_CAPACITY` = 1024 | Zero outside saved prefix | 1 | §8 JOB_INDEXES | SAVE-J2-R01 / decision 0157: preserve exact prefix order and membership with its saved count; unused tail is zero. |
| Dirty-row work lists (u8) | `_is_hive_dirty` | 1 | `HIVE_OWNER_CAPACITY` = 1024 | 0 outside saved membership | 2 | §8 JOB_INDEXES | Rebuild exactly from the corresponding saved dirty-list prefix; never mark all owners dirty. |
| Dirty-list count scalar | -- | 4 | 1 scalar | 0 = empty | 1 | §8 JOB_INDEXES | `_dirty_count` in 0..4096; SAVE-J2-R01 persists the exact prefix length, encoded as one i32 element. |
| Dirty-list count scalar | -- | 4 | 1 scalar | 0 = empty | 1 | §8 JOB_INDEXES | `_dirty_zone_count` in 0..128; SAVE-J2-R01 persists the exact prefix length, encoded as one i32 element. |
| Dirty-list count scalar | -- | 4 | 1 scalar | 0 = empty | 1 | §8 JOB_INDEXES | `_dirty_hive_count` in 0..1024; SAVE-J2-R01 persists the exact prefix length, encoded as one i32 element. |
| Status-derived counts | -- | 8 | 8 scalars | 0 | 2 | §8 JOB_INDEXES | Decision0160: rebuild `_pending_count`, `_unmet_count`, `_requested_count`, `_demand_enabled_count`, `_demand_pending_count`, `_demand_unmet_count`, `_hive_pending_count`, `_hive_unmet_count` from the saved status/enablement columns. |
| Planner counters and scratch | -- | -- | -- | -- | 3 | -- | The21session outcome diagnostics, `_last_blocker`, `_last_column_refusal`, `_math` and `_calendar`. The three dirty-list counts are canonical scalars above; `_dropped_on_load_count` remains diagnostic. |

### `godot/scripts/core/jobs.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Job columns | `_kind`, `_requester_slot`, `_requester_generation`, `_destination_slot`, `_destination_generation`, `_source_slot`, `_source_generation`, `_priority`, `_required_skill`, `_state`, `_worker_slot`, `_worker_generation` | 4 | `JOB_CAPACITY` = 8192 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | `_worker_slot`/`_worker_generation` are the live assignment; ARCH-SAVE-004 validates job ownership against the resident store. |
| Job progress and order key | `_remaining_mwu`, `_created_tick` | 8 | `JOB_CAPACITY` = 8192 | 0 remaining means complete | 1 | §4 COMPONENT_COLUMNS | `_remaining_mwu` is milli work units in flight -- task 09.1's work-in-progress -- and `_created_tick` is a tiebreak in §5.3's ordering, so both change which job is picked next. |
| Job occupancy | `_job_present` | 1 | `JOB_CAPACITY` = 8192 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| Job identity copy | `_job_ref_slot`, `_job_ref_generation` | 4 | `JOB_CAPACITY` = 8192 | `-1`/0 null ref | 1 | §4 COMPONENT_COLUMNS | Copy of the directory pair; the directory's generation stays authoritative. |
| Job eligibility flags | `_urgency`, `_dangerous`, `_station_gate`, `_tool_gate`, `_unlock_gate`, `_inputs_gate`, `_is_coordinator` | 1 | `JOB_CAPACITY` = 8192 | Byte enums; the four gates use decision 0023's UNAVAILABLE value rather than a false | 1 | §4 COMPONENT_COLUMNS | `_urgency` also orders `_live_slots`, so it must be restored before that index is rebuilt. |
| Coordinator and member chain | `_coordinator_slot`, `_coordinator_generation`, `_member_head`, `_member_next` | 4 | `JOB_CAPACITY` = 8192 | `_member_head`/`_member_next == -1` terminates the chain | 1 | §5 CHILD_ARENAS | Decision 0017's coordinator groups. Membership order is observable, so the chain is written rather than re-derived. |
| Job active list and id cache | `_live_slots`, `_job_persistent_id` | 4 | `JOB_CAPACITY` = 8192 | Only `[0, _live_count)` of `_live_slots` is meaningful | 2 | §8 JOB_INDEXES | ARCH-SAVE-002 rebuilds active lists ascending; `_job_persistent_id` is explicitly "a cache of the directory's never-reused persistent ID" and is refilled from §3. |
| Urgency bucket bounds | `_bucket_begin` | 4 | `URGENCY_COUNT + 1` = 6 | `_bucket_begin[URGENCY_COUNT] == _live_count` | 2 | §8 JOB_INDEXES | Half-open bounds over `_live_slots`; regenerated with it. |
| JobAgent assignment | `_agent_job_slot`, `_agent_job_generation`, `_agent_phase`, `_agent_target_slot`, `_agent_target_generation` | 4 | `AGENT_CAPACITY` = 512 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | One row per resident slot; `_agent_phase` is where in the job the resident is. |
| JobAgent route cursor (reserved) | `_agent_path_id`, `_agent_path_cursor` | 4 | `AGENT_CAPACITY` = 512 | Currently always 0 | 1 | §4 COMPONENT_COLUMNS | RESERVED ALLOCATION ONLY -- the module's own comment says "no pathfinder exists, so these are 0 and never written". They are §2 ledger fields, so 09.2 must write them as zeros and MUST NOT repurpose these v1 bytes (task 09.1's closing sentence) when `movement.gd`'s cursor is wired through instead. |
| JobAgent leases (reserved) | `_agent_lease_expiry`, `_agent_blocked_tick`, `_agent_manual_until` | 8 | `AGENT_CAPACITY` = 512 | Currently always 0 | 1 | §4 COMPONENT_COLUMNS | RESERVED ALLOCATION ONLY: REQ-SET-032/033 lease bookkeeping and ManualTask are unimplemented (blocker U6). These are the "leases" of task 09.1 and become live state the moment those land; the same do-not-repurpose rule applies. |
| JobAgent occupancy and hazard latch | `_agent_present`, `_agent_hazard_locked` | 1 | `AGENT_CAPACITY` = 512 | `_agent_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | `_agent_hazard_locked` is REQ-SET-015's latch: it survives the condition that set it, so nothing recomputes it. |
| JobAgent persistent-id cache | `_agent_persistent_id` | 4 | `AGENT_CAPACITY` = 512 | 0 for a free row | 2 | §8 JOB_INDEXES | A cache of the directory's never-reused id, refilled from §3 like `_job_persistent_id`. |
| Scan continuation key (i32) | `_job_scan_cursor` | 4 | `AGENT_CAPACITY` = 512 | `_job_scan_cursor == 0` means no scan in progress | 1 | §4 COMPONENT_COLUMNS | Decision 0023's `(bucket, job persistent_id)` continuation key, and the comment says it IS `ResidentRuntime.job_scan_cursor` from §3. A reload that reset it restarts a partial scan and picks a different job -- ARCH-SAVE-006's "active passive batch" coverage case. |
| Scan continuation key (u8) | `_continuation_bucket` | 1 | `AGENT_CAPACITY` = 512 | `_job_scan_cursor == 0` means no scan in progress | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Job pass scratch | `_skill_scratch`, `_priority_scratch` | 4 | `JOB_KIND_COUNT` = 12 | Refilled per candidate evaluation | 3 | -- | Twelve entries each, one per job kind. |
| Jobs derived counters | -- | -- | -- | `_deepest_continuation_bucket == -1` when no resident holds a continuation | 2 | §8 JOB_INDEXES | `_live_count`, `_agent_count` and `_deepest_continuation_bucket`. The last is an UPPER BOUND whose only cost when too high is one wasted walk, so a load may restore it at its maximum and converge. |
| Jobs pass inputs and scratch | -- | -- | -- | -- | 3 | -- | `_food_reserve_below_two_days` is a per-pass world input the caller restates each pass. `_best_*`, `_walk_*`, `_math`, `_dangerous_consent_scratch` and `_hazard_locked_scratch` live inside one candidate evaluation. `_last_column_refusal` [decision 0132] is the StringName code from the most recent `restore_columns()` refusal: a diagnostic scalar, excluded from `state_bytes()`, owing no ledger byte. |

### `godot/scripts/core/milestones.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Milestone unlock gate | -- | -- | -- | -- | 3 | -- | No module-level `var` at all: every function is static and pure, taking `unlocked_mask` as an argument. R-BUILD-DOM-001 gives both masks to Progression and says "Do not add a second mutable milestone store", so this file deliberately holds none. `World.milestone_mask` and `Progress.unlocked_mask` are saved by their own owners; nothing here is. Listed so the registry covers every file under `godot/scripts/core/` and a future state field here cannot slip in unclassified. |

### `godot/scripts/core/movement.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| ResidentMotion velocity and remainders | `_vx`, `_vz`, `_remainder_x`, `_remainder_z`, `_next_x`, `_next_z` | 4 | `MOTION_CAPACITY` = 512 | 0 for an idle body | 1 | §4 COMPONENT_COLUMNS | ARCH-MEM-008's ResidentMotion fields. The two remainders are sub-unit position carried at denominator `30 * COST_DIAGONAL`; dropping them moves a body by up to one unit per axis and diverges immediately. |
| ResidentMotion reserved fields | `_correction_x`, `_correction_z`, `_radius_u`, `_desired_yaw`, `_next_yaw` | 4 | `MOTION_CAPACITY` = 512 | Currently always 0 | 1 | §4 COMPONENT_COLUMNS | RESERVED: the module's header says separation, body radii and yaw are all held at zero because MOVE-G01's parameter pack has not supplied them and facing's zero reference is unstated. They are ledgered §2 fields, so they are written as zeros and MUST NOT be repurposed -- MOVE-G02 owns the expanded movement version and migration matrix that changes them. |
| ResidentMotion route cells | `_grid_next`, `_grid_cell` | 4 | `MOTION_CAPACITY` = 512 | `-1` (`NO_REQUEST`) when the body is following no route | 1 | §4 COMPONENT_COLUMNS | NOT a spatial-hash chain: `_grid_cell` is the cell the body occupies and `_grid_next` the route cell it is walking to, and `_segment_is_diagonal()` compares them to charge 10 or 14. They hold invariantly to `route_cell(_cursor_request, _cursor_index)` and its successor, so they are derivable -- but they are two of ARCH-MEM-008's sixteen ledgered ResidentMotion fields, so the ledger rule applies: written, and cross-checked against the cursor on load rather than chosen between. |
| ResidentMotion speed and phase | `_speed_u_per_s`, `_movement_phase`, `_blocked_ticks` | 4 | `MOTION_CAPACITY` = 512 | `_movement_phase == 0` is `MOTION_IDLE`, a real phase and not absence | 1 | §4 COMPONENT_COLUMNS | `_blocked_ticks` is an accumulating counter that drives the route-lost decision. |
| ResidentRouteCursor | `_cursor_request`, `_cursor_route_generation`, `_cursor_index` | 4 | `MOTION_CAPACITY` = 512 | `_cursor_request == -1` (`NO_REQUEST`) when the body follows no route | 1 | §9 NAVIGATION | Decision 0053's addition, because ARCH-MEM-008's ResidentMotion has no field naming which route a body follows or how far along it is. `_cursor_route_generation` validates against `navigation.gd`'s descriptor generation -- a THIRD generation space, distinct from the directory's and from inventory's. |
| ResidentRouteCursor ownership | `_cursor_owner_id` | 4 | `MOTION_CAPACITY` = 512 | `0` (`NO_OWNER_ID`) when the row's cursor belongs to nobody | 1 | §9 NAVIGATION | Decision 0066. The persistent id of the resident the cursor was attached for, compared on every `_advance_row()` so a successor spawned into a despawned traveller's typed row cannot inherit its route. Persistent ids are never reused, which is why this is not a generation -- the same reasoning as `transforms.gd`'s `_bound_persistent_id`, and a load that dropped it would let one reused row walk the wrong body. |
| ResidentTravelAdmission | `_cursor_profile_id`, `_cursor_profile_revision`, `_cursor_mode`, `_cursor_load_g`, `_cursor_destination_revision` | 4 | `MOTION_CAPACITY` = 512 | `_cursor_profile_id == -1` (`NO_PROFILE`) and `_cursor_mode == -1` (`NO_MODE`) when the body was admitted to nothing | 1 | §9 NAVIGATION | Decision 0083. The terms one journey was admitted under: which starter ground profile, at which revision, in which traversal mode, carrying how much, and the contact owner's destination revision. `_advance_row()` settles the body MOTION_PROFILE_STALE when `_cursor_profile_revision` no longer matches the live profile, and `revalidate_destination()` settles it MOTION_CONTACT_STALE on a changed destination revision -- so a load that dropped either number would resume a journey under withdrawn terms instead of refusing it. `_cursor_load_g` is the committed load GDD §5.2's carry capacity was checked against at admission. |
| StarterGroundProfile catalog | `_profile_species_id`, `_profile_size_class`, `_profile_speed_u_per_s`, `_profile_carry_g`, `_profile_mode_mask` | 4 | `PROFILE_COUNT` = 4 | A profile whose `_profile_revision` is 0 is unpublished and its other columns are meaningless | 2 | §2 CATALOG_IDS | Decision 0083. Derived wholly from `residents.gd` at `_init()` -- the compiled species id, GDD §5.2's size class, speed cap and carry capacity, and `PROFILED_MODE_MASK`. Rebuilt rather than written, for the same reason the reverse owner map is: writing it too would give the audit two sources that can disagree, which is precisely the drift the derivation exists to prevent. |
| StarterGroundProfile revisions | `_profile_revision` | 4 | `PROFILE_COUNT` = 4 | `0` when nothing is published at that id | 1 | §2 CATALOG_IDS | Decision 0083. NOT derivable, unlike the five columns above: `revise_profile()` advances it, and every travelling resident's `_cursor_profile_revision` is compared against it every tick. A load that reset it to `PROFILE_FIRST_REVISION` would silently re-validate journeys whose profile had been withdrawn. |
| Movement scratch | -- | -- | -- | -- | 3 | -- | `_scratch`, `_pose`, `_travelling_count`, `_last_refusal`, the `_step_position`/`_step_budget`/`_here_x`/`_here_z` per-tick scalars and the five collaborator handles. |

### `godot/scripts/core/navigation.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| A* frontier arrays | `_g`, `_parent`, `_heap`, `_heap_position`, `_stamp` | 4 | `SpatialWorld.CELL_COUNT` = 262144 | An entry is meaningful only where `_stamp[cell] == _search_serial`; every other entry is a previous search's residue | 1 | §9 NAVIGATION | ARCH-SAVE-006 names "a partial A* heap" as a required coverage case, and ARCH-HASH-001 includes "navigation progress". Restarting the search on load is NOT equivalent: it would spend expansions out of the resuming tick's budget and make the route ready on a different tick. §9 may encode only the stamped cells -- 262144 cells x 4 bytes x 5 columns is 5 MB of mostly stale data -- but must reproduce them exactly. |
| A* cell state | `_state` | 1 | `SpatialWorld.CELL_COUNT` = 262144 | 0 is `STATE_UNTOUCHED`; like the arrays above it is only meaningful under the current stamp | 1 | §9 NAVIGATION | Same argument and the same sparsification opportunity. |
| Route cell arena | `_arena` | 4 | `ROUTE_CELL_CAPACITY` = 1048576 | Cells at or past `_arena_used` are unallocated, not zeroed | 1 | §9 NAVIGATION | Task 09's acceptance list requires "fully referenced route arenas": every descriptor's `[offset, offset+count)` window must lie inside the restored used prefix, and compacting the arena on load would change later eviction behaviour. |
| Route descriptors | `_d_route_id`, `_d_generation`, `_d_start_macro`, `_d_goal_cell`, `_d_clearance`, `_d_map_revision`, `_d_variant_start`, `_d_anchor`, `_d_offset`, `_d_count`, `_d_refcount`, `_d_use_low`, `_d_use_high`, `_d_flags`, `_d_next_variant`, `_d_reserved` | 4 | `ROUTE_DESCRIPTOR_CAPACITY` = 256 | `_d_flags` without `FLAG_IN_USE` is a free descriptor; `_d_next_variant == -1` (`NO_VARIANT`) ends a variant chain | 1 | §9 NAVIGATION | ARCH-HASH-001 includes "cache eviction state": `_d_use_low`/`_d_use_high` are the u64 use counter the eviction order reads, and `_d_generation` is the route generation `movement.gd`'s cursor validates against. `FLAG_RETIRED` is this store's own generation-retirement rule and must survive exactly as §3's does. |
| Path request records and contacts | `_r_job_slot`, `_r_job_generation`, `_r_start_cell`, `_r_goal_cell`, `_r_clearance`, `_r_start_macro`, `_r_map_revision`, `_r_phase`, `_r_route_id`, `_r_route_generation`, `_r_created_low`, `_r_created_high`, `_r_next_queue`, `_r_exact_start`, `_r_anchor`, `_r_expansions`, `_c_start_owner_slot`, `_c_start_owner_generation`, `_c_goal_owner_slot`, `_c_goal_owner_generation`, `_c_requester_persistent_id` | 4 | `PATH_REQUEST_CAPACITY` = 8192 | `-1` (`NO_ROW`) in the queue links and owner slots | 1 | §9 NAVIGATION | The pending-request queue, its ages (`_r_created_low`/`_r_created_high` are a tick split across two nonnegative halves) and its per-request expansion spend. Task 09.4 requires canonical future state to include "navigation admission/readiness ... queue ages" by name. |
| Navigation search and queue scalars | -- | -- | -- | `_search_goal`, `_search_origin`, `_search_macro`, `_free_request_head`, `_queue_head` and `_active_request` all use `-1` (`NO_ROW`) | 1 | §9 NAVIGATION | `_search_serial`, `_heap_size`, `_search_*`, `_expansions_remaining`, `_expansions_total`, `_arena_used`, `_free_request_head`, `_queue_head`, `_active_request` and `_served_revision` are the other half of the partial search and of the request allocator. `_use_heuristic` is a test-only switch, `_live_requests`, `_storage_blocked_count` and `_last_refusal` are diagnostics. |

### `godot/scripts/core/needs.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Need values and remainders (i32) | `_need_value` | 4 | `RESIDENT_CAPACITY * NEED_COUNT` = 2560 | None: every living resident has all five needs | 1 | §4 COMPONENT_COLUMNS | Owner-major at `slot * 5 + need`, integers 0-10000 per AGENTS.md. The int64 remainder is the sub-point accumulator; task 09.4 warns that canonical future state is more than "needs and XP", and this is the half of needs that is easy to forget. |
| Need values and remainders (i64) | `_need_remainder` | 8 | `RESIDENT_CAPACITY * NEED_COUNT` = 2560 | None: every living resident has all five needs | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Health and remainder (i32) | `_health` | 4 | `RESIDENT_CAPACITY` = 512 | 0-100 with a separate remainder | 1 | §4 COMPONENT_COLUMNS | Same remainder argument. |
| Health and remainder (i64) | `_health_remainder` | 8 | `RESIDENT_CAPACITY` = 512 | 0-100 with a separate remainder | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Cold exposure | `_cold_milli_hours`, `_cold_remainder` | 8 | `RESIDENT_CAPACITY` = 512 | 0 | 1 | §4 COMPONENT_COLUMNS | Accumulated exposure in milli-hours; the winter tests depend on it exactly. |
| Starvation clock | `_starving_ticks` | 8 | `RESIDENT_CAPACITY` = 512 | 0 = not starving | 1 | §4 COMPONENT_COLUMNS | An absolute tick count driving REQ-SET's starvation death; ARCH-SAVE-006 names "a dying resident" as a coverage case. |
| Departure countdown | `_departure_days` | 4 | `RESIDENT_CAPACITY` = 512 | 0 = not counting down | 1 | §4 COMPONENT_COLUMNS | Days remaining before a resident leaves. |
| Resident state bytes | `_status`, `_present`, `_size_class`, `_activity`, `_comfort_environment`, `_social_paired`, `_purpose_source`, `_cold_environment`, `_clothing_tier`, `_infirmary`, `_injury_state`, `_airless` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row; the rest are byte enums whose 0 is a real value | 1 | §4 COMPONENT_COLUMNS | `_injury_state` is the GDD's Injury model (kind/severity/care), which is settlement healing and NOT a combat damage model. ARCH-SAVE-005 bounds each byte against its `*_COUNT`. |
| Hunger rate table | `_hunger_rate_milli` | 8 | `HUNGER_RATE_COUNT` = 9 | One entry per (life stage, size class), index `stage * SIZE_COUNT + size` | 2 | §4 COMPONENT_COLUMNS | Nine values copied from `family_rules.gd`'s FAMILY-RULES-R01 table at construction and at each season change, not runtime state ([decision 0521](decisions/0521-pc04-adopted-with-children-inactive.md)). The ADULT row equals the pre-PC-04 size-and-season product exactly. `_family_rules` is the derived catalog instance it is read from; `_life_stages_required` is Residents-composition configuration (category 3) that makes the stage-blind sweep refuse. The life stage itself is Residents' column and is NOT copied here: `tick_all_staged()` reads it as an argument. |
| Needs tick scratch | `_rate_scratch` | 8 | `NEED_COUNT` = 5 | Refilled per resident | 3 | -- | Five entries, one per need, reused by the tick. |
| Needs live counters | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_present_count` and `_living_count`, recomputed from `_present` and `_status`. ARCH-SAVE-005 caps living residents at 256, which is checked against the recomputed value, not a stored one. |
| Needs pass inputs and scratch | -- | -- | -- | -- | 3 | -- | `_winter` and `_hard_freeze` are per-tick world inputs the caller restates every tick. `_death_count`, `_last_refused_slot`, `_math`, `_step_value`, `_step_remainder` and `_out_value` are diagnostics or scratch. `_last_column_refusal` [decision 0132] is the StringName code from the most recent `restore_columns()` refusal: a diagnostic scalar, excluded from `state_bytes()`, owing no ledger byte. |

### `godot/scripts/core/orchard_hive.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| OrchardPlot occupancy | `_o_present` | 1 | `ORCHARD_CAPACITY` = 1024 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| OrchardPlot growth | `_o_species_id`, `_o_age_days`, `_o_health`, `_o_chill_days` | 4 | `ORCHARD_CAPACITY` = 1024 | None on a live row | 1 | §4 COMPONENT_COLUMNS | `_o_chill_days` is the accumulated winter chill requirement -- multi-season history nothing else reconstructs. |
| OrchardPlot daily and yearly latches | `_o_tended_today`, `_o_harvested_year` | 1 | `ORCHARD_CAPACITY` = 1024 | 0 = not tended / not harvested this period | 1 | §4 COMPONENT_COLUMNS | Cleared at day and year rollovers respectively, so both matter at a boundary save. |
| OrchardPlot placement and identity | `_o_origin_x`, `_o_origin_z`, `_o_ref_slot`, `_o_ref_generation` | 4 | `ORCHARD_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | Tile origin plus the directory reference copy. |
| OrchardPlot active list | `_o_live_slots` | 4 | `ORCHARD_CAPACITY` = 1024 | Only `[0, _o_live_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | Rebuilt ascending. |
| Hive occupancy | `_h_present` | 1 | `HIVE_CAPACITY` = 1024 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| Hive state | `_h_building_slot`, `_h_building_generation`, `_h_strength`, `_h_serviced_day` | 4 | `HIVE_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | `_h_serviced_day` pairs with `job_planner.gd`'s hive service rows; the two must be restored consistently or a hive is serviced twice in one day. |
| Hive stores | `_h_feed_milli`, `_h_honey_milli`, `_h_wax_milli` | 8 | `HIVE_CAPACITY` = 1024 | 0 | 1 | §4 COMPONENT_COLUMNS | Work-in-progress quantities in milli units. |
| Hive foraging box and identity | `_h_min_tile_x`, `_h_min_tile_z`, `_h_max_tile_x`, `_h_max_tile_z`, `_h_ref_slot`, `_h_ref_generation` | 4 | `HIVE_CAPACITY` = 1024 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | The hive's tile bounding box plus the directory reference copy. |
| Hive active list | `_h_live_slots` | 4 | `HIVE_CAPACITY` = 1024 | Only `[0, _h_live_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | Rebuilt ascending. |
| Hive service links | `_link_hive_slot`, `_link_hive_generation` | 4 | `LINK_CAPACITY` = 30720 | `-1` with generation 0 in an unused link | 1 | §5 CHILD_ARENAS | Decision 0051's owner-major recipient links, `LINKS_PER_RECIPIENT` per owner. Fixed-stride, so ARCH-SAVE-002's owner-ascending child rule writes them directly. |
| Hive candidate scratch (i64) | `_cand_distance` | 8 | `LINKS_PER_RECIPIENT` = 6 | Refilled per selection | 3 | -- | Six-entry selection buffer used inside one hive-day pass. |
| Hive candidate scratch (i32) | `_cand_persistent_id`, `_cand_slot`, `_cand_generation` | 4 | `LINKS_PER_RECIPIENT` = 6 | Refilled per selection | 3 | -- | See the first row of this group. |
| Orchard/hive live counts | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_o_live_count` and `_h_live_count`, recomputed with their active lists. |
| Orchard/hive scratch | -- | -- | -- | -- | 3 | -- | `_cand_count`, `_math` and the `_owns_directory` construction flag. |

### `godot/scripts/core/presentation_extract.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Snapshot frames | `_current`, `_previous` | 8 | `FIELD_COUNT` = 14 | A field's value is meaningless unless `_available` marks it | 3 | -- | ARCH-SYS-023's read-only extract and the one place a `float` is legal. ARCH-HASH-001 excludes presentation explicitly and requires "current/previous authoritative Transform fields, not first-frame presentation overrides". A reload rebuilds these on the next capture. |
| Field availability | `_available` | 1 | `FIELD_COUNT` = 14 | 0 = the field's source store was never bound | 3 | -- | Fixed at construction from which stores were composed; it is a property of the wiring, not of the world. |
| Layer visibility | `_layer_visible` | 1 | `LAYER_COUNT` = 6 | 0 = hidden | 3 | -- | A UI toggle. ARCH-HASH-001 excludes UI panels; hiding a layer changes what is reported and never what is true. |
| Extract scalars | -- | -- | -- | -- | 3 | -- | `_current_tick`, `_previous_tick`, `_capture_count`, `_last_refusal`, `_calendar` and the six source handles. |

### `godot/scripts/core/priorities.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Player job priorities | `_job_priority` | 1 | `PRIORITY_CAPACITY * JOB_KIND_COUNT` = 6144 | 0 is a real priority (disabled), not an absence marker | 1 | §4 COMPONENT_COLUMNS | Owner-major at `slot * 12 + job kind`, values 0-4. Set only by SET_JOB_PRIORITIES commands, so nothing recomputes it. |
| Player work policy | `_auto_fallback`, `_dangerous_work`, `_present` | 1 | `PRIORITY_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | Per-resident consent flags; `_dangerous_work` gates §5.3's dangerous-job step. |
| Priority scalars | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_present_count`, recomputed from `_present`. |

### `godot/scripts/core/progression_interval.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Continuous interval arithmetic | -- | -- | -- | -- | 3 | -- | PROGRESS-C4-R01: static functions only, no mutable module fields or packed allocations. Caller-owned result is scratch. The future Progress owner must separately budget and serialize observation state before production integration. This helper does not add an owner or save record. |

### `godot/scripts/core/reservations.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reservation rows | `_r_job_slot`, `_r_job_generation`, `_r_lot_slot`, `_r_lot_generation`, `_r_purpose` | 4 | `_row_capacity` <= 32768 | `-1` slot with generation 0 is the null ref | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A RESERVATION ROW HAS NO GENERATION OF ITS OWN: `_r_job_generation` is the directory's and `_r_lot_generation` is `inventory.gd`'s LOCAL lot generation, so one row spans two generation spaces and neither belongs to it. Rows are addressed by index, so §7 must not compact them. |
| Reservation quantity and expiry | `_r_quantity_milli`, `_r_expiry` | 8 | `_row_capacity` <= 32768 | 0 quantity is an inactive blank; occupied reservations require positive quantity | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_r_expiry` is an absolute tick: ARCH-SAVE-006 names "an expired lease" as a coverage case, and ARCH-SAVE-005 requires each reservation sum to equal its lot's `reserved_milli`. |
| Reservation occupancy | `_occupied` | 1 | `_row_capacity` <= 32768 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset. |
| Reservation free heap | `_free_heap` | 4 | `_row_capacity` <= 32768 | Only `[0, _free_count)` is live | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | A min-heap like `entity_directory.gd`'s, so ARCH-SAVE-002's rebuild permission applies: the free SET determines allocation order. |
| Per-job reservation index | `_job_head` | 4 | `_job_capacity` <= 8192 | `-1` for a job with no reservations | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Head of the per-job chain; reconstruct by sorting occupied row indices by job slot and semantic (lot slot, lot generation, purpose) key, preserving row identities (decision0163). |
| Per-lot reservation index | `_lot_head` | 4 | `_lot_capacity` <= 16384 | `-1` for a lot with no reservations | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Head of the per-lot chain; reconstruct by lot slot and semantic (job slot, job generation, purpose) key, preserving row identities (decision0163). |
| Reservation chain links | `_job_prev`, `_job_next`, `_lot_prev`, `_lot_next` | 4 | `_row_capacity` <= 32768 | `-1` at either end of a chain | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Both chains are pure indexes over canonical reservation rows; sorted semantic keys, not appending ascending row indices, define their order. SAVE-RES-R01v2 rebuilds them with bounded packed merge sorting. Capture refuses malformed source indexes. |
| Reservation counts and capacities | -- | -- | -- | -- | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_row_capacity`, `_job_capacity` and `_lot_capacity` are construction arguments; `_active_count` and `_free_count` are recomputed from `_occupied`. |
| Reservation scratch | -- | -- | -- | -- | 3 | -- | `_math` and `_pending_new_rows`, both consumed inside one call; `_last_column_refusal` is a separate category3 diagnostic. Column restore preserves existing scratch; the next claim recomputes pending fresh-row count. |
| Exact Inventory owner wiring | -- | -- | -- | Unbound only before composition/first successful operation | 3 | -- | Decision 1056. `_bound_inventory` is weak world wiring; first successful claim/Inventory operation, explicit empty-pool composition or Inventory-aware restore binds it. Failed operations cannot bind, clear/pure-column recovery retain it, and expired/foreign owners refuse. Production save apply supplies the actual Inventory; whole-world load must reconstruct and validate this relation without serializing or hashing pointers. |
| Guarded haul scope and packets | -- | -- | -- | Inactive between synchronous calls | 3 | -- | [Decision1141](decisions/1141-guarded-spatial-haul-transfers.md). `_haul_original` and `_haul_view` are two fixed216-byte packets; `_haul_active` adds one byte. `_haul_inventory`, `_haul_guard` and `_haul_error` are borrowed wiring/diagnostic identity. The view is borrowed by Delivery, not copied into another bank. All admission, transfer and cancellation facts are reobserved from canonical owners per call; no completed-tick future fact exists only here. The3072-byte separate allowance covers512 controls,512 helpers and2048 provisional native bytes; native memory and composed save qualification remain open. |

### `godot/scripts/core/residents.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Species catalog table (utf-8) | `_species_key` | var | `SPECIES_COUNT` = 16 | Sized to `SPECIES_COUNT` regardless of how many keys the catalog defines | 2 | §2 CATALOG_IDS | Loaded from the catalog; `_species_key` is the only `PackedStringArray` in a core store and has no fixed element width. Rebuilt on load from the artifact the header hash pins. |
| Species catalog table (u8) | `_species_size` | 1 | `SPECIES_COUNT` = 16 | Sized to `SPECIES_COUNT` regardless of how many keys the catalog defines | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Resident occupancy and species (u8) | `_present` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | 512 rows; ARCH-SAVE-005 caps living residents at 256 and rows at 512. |
| Resident occupancy and species (i32) | `_species` | 4 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Resident classification | `_size_class`, `_named` | 1 | `RESIDENT_CAPACITY` = 512 | `_named == 0` means the resident still carries a generated name | 1 | §4 COMPONENT_COLUMNS | `_size_class` mirrors `needs.gd`'s and must agree after a load. |
| Resident life stage | `_life_stage` | 1 | `RESIDENT_CAPACITY` = 512 | Unused rows hold 0, which is also ADULT; `_present` and the directory generation are what distinguish them | 1 | §4 COMPONENT_COLUMNS | MOVE-DEP-R02 / GDD §4.2 as amended 2026-09-12, landed by decision 0095. Fixed bounded domain ADULT 0, CHILD 1, ELDER 2; COUNT 3 is a bound and is never stored. Assigned once at creation and never mutated: release 1 has no birth, aging timer or adulthood transition, so there is no setter. NOT derivable from any other store. A loader must refuse a pre-column schema rather than infer ADULT. |
| Resident name | `_name_key` | var | `RESIDENT_CAPACITY` = 512 | Empty string for an unnamed row | 1 | §14 NAME_POOL | ARCH-SAVE-001 stores strings length-prefixed UTF-8; ARCH-SAVE-005 requires 2-32 Unicode characters with control characters rejected, and forbids ordering simulation by a display string. |
| Resident arrival and role (i64) | `_arrival_tick` | 8 | `RESIDENT_CAPACITY` = 512 | 0 arrival tick is tick 0, a real value | 1 | §4 COMPONENT_COLUMNS | `_arrival_tick` is an absolute tick, so it stays correct across a reload without adjustment. |
| Resident arrival and role (u8) | `_role` | 1 | `RESIDENT_CAPACITY` = 512 | 0 arrival tick is tick 0, a real value | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Resident selection flag | `_selected` | 1 | `RESIDENT_CAPACITY` = 512 | 0 = not selected | 3 | -- | ARCH-HASH-001 excludes "selected flags" from the canonical hash by name. It is UI state; 09.2 may write it for continuity, but it must not enter the digest and cannot change a tick. |
| Resident home and bed | `_home_slot`, `_home_generation`, `_bed_slot`, `_bed_generation`, `_ref_slot`, `_ref_generation` | 4 | `RESIDENT_CAPACITY` = 512 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | `_ref_slot`/`_ref_generation` are the directory copy; the directory's generation is authoritative. |
| Equipment tool mirror | `_equip_tool_item_id`, `_equip_tool_durability` | 4 | `RESIDENT_CAPACITY` = 512 | `_equip_tool_item_id == -1` (`NO_TOOL_ITEM`) means no tool is equipped, and the durability beside it is then 0 | 1 | §4 COMPONENT_COLUMNS | GDD §4.2 `Equipment.tool_item_id` / `tool_durability`, landed by [decision 0061](decisions/0061-an-equipped-lot-is-a-null-container-lot-a-store-can-prove.md). MIRROR, NOT AUTHORITY: the authoritative durability is the `GearInstance` row in `gear.gd`, which funnels every durability write through one private setter, and `gear.audit_equipment_mirror()` re-derives both columns and refuses on divergence. They are therefore reconstructible from category 1 -- and are still classified 1, written and cross-checked, for exactly the reason `_skill_level` and `inventory.gd`'s `_c_used_mass_g` are: an explicitly modeled field with a cross-check is not a choice between two sources. Future-affecting and hashed: GDD §5.7's tool gate reads them, and a broken tool blocks tool-required work. `_equip_tool_item_id` is a compiled ItemDefinition id, not a reference in any generation domain. GDD §4.2's fifth Equipment field, `clothing_tier`, is `needs.gd`'s column and is classified in that store's section. |
| Equipment satchel ref | `_equip_satchel_slot`, `_equip_satchel_generation` | 4 | `RESIDENT_CAPACITY` = 512 | `-1` slot with generation 0 is the null ref: no satchel | 1 | §4 COMPONENT_COLUMNS | GDD §4.2 `Equipment.satchel: EntityRef` (decision 0061). NOT derivable from any other store -- nothing else records which container is a resident's satchel -- so unlike the tool pair above this one has no cross-check and omitting it loses the binding outright. INVENTORY CONTAINER DOMAIN, not the directory's: it names a container `inventory.gd` allocated for itself, so it validates against `_c_generation`. The 2026-09-11 addendum records container refs, lot refs, route refs and directory refs as four distinct generation namespaces; a codec that validated this pair as a directory ref would accept a stale handle whose numbers happen to match. `set_satchel()` range-checks the pair but cannot enforce the domain, because this store holds no inventory reference. Equipped gear is outside satchel mass by construction, not by subtraction: an equipped lot sits in no container at all. |
| Resident skills (i64) | `_skill_xp` | 8 | `RESIDENT_CAPACITY * SKILL_COUNT` = 6144 | 0 XP at level 0 | 1 | §4 COMPONENT_COLUMNS | Owner-major at `slot * 12 + skill`. `_skill_level` is derived from `_skill_xp` by the level table, but task 09's acceptance list names "item/XP" explicitly and both are ledgered §2 fields, so both are written and cross-checked. |
| Resident skills (i32) | `_skill_level` | 4 | `RESIDENT_CAPACITY * SKILL_COUNT` = 6144 | 0 XP at level 0 | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Resident active list | `_live_slots` | 4 | `RESIDENT_CAPACITY` = 512 | Only `[0, _live_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | Rebuilt ascending. |
| Cohort rollback scratch | `_cohort_slots` | 4 | `INITIAL_POPULATION` = 12 | Only the current synchronous spawn/rollback call owns meaningful entries | 3 | -- | STATE-COHORT-R01: written by spawn_initial_settlement and read only by _rollback_cohort. Successful-call residue has no future meaning; bare reusable slots cannot record founder identity after death. No save/digest membership; save cannot observe an in-flight call. See rulings/2026-09-11_focus_and_rollback_state.md. |
| Resident catalog and counters | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_species_ids` and `_catalog_error` are rebuilt by reloading the catalog; `_live_count` is recomputed with the active list. |
| Resident scratch | -- | -- | -- | -- | 3 | -- | The `_owns_collaborators` construction flag (the unused `_math` scratch was deleted, decision 0501). `_last_column_refusal` [decision 0132] is the StringName code from the most recent `restore_columns()` refusal: a diagnostic scalar, excluded from `state_bytes()`, owing no ledger byte. |

### `godot/scripts/core/resource_catalog_binding.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Bound resource ids | -- | -- | -- | `_opened == false` means no artifact has been verified | 2 | §2 CATALOG_IDS | `_items`, `_artifact_ids`, `_artifact_path`, `_opened`. Every id is re-resolved by key through the owning registry and re-checked against the committed artifact, so nothing here is written: the artifact §2 already carries IS the source. BLOCKED: the module's header records that "generate a world, save it, reload it, prove the bound ids survive" cannot be exercised because no save module exists. What it needs is 09.2's §2 decode calling `verify_ids()` on the restored request; it does not need new state here. |

### `godot/scripts/core/resource_nodes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| ResourceNode occupancy | `_present` | 1 | `RESOURCE_NODE_CAPACITY` = 4096 | 0 = free row | 1 | §4 COMPONENT_COLUMNS | Occupied bitset. |
| ResourceNode output id | `_resource_id` | 4 | `RESOURCE_NODE_CAPACITY` = 4096 | None on a live row | 1 | §4 COMPONENT_COLUMNS | A compiled `ItemDefinition` id for the EXTRACTED OUTPUT, bound by `resource_catalog_binding.gd`; ARCH-SAVE-004's catalog compatibility check is what keeps it meaning the same item. |
| ResourceNode quantities | `_quantity_milli`, `_capacity_milli` | 8 | `RESOURCE_NODE_CAPACITY` = 4096 | 0 | 1 | §4 COMPONENT_COLUMNS | int64 milli quantities. |
| ResourceNode regrowth (i32) | `_regrow_days`, `_planted_day` | 4 | `RESOURCE_NODE_CAPACITY` = 4096 | `_exhausted == 1` marks a depleted node | 1 | §4 COMPONENT_COLUMNS | `_planted_day` is an absolute day; regrowth resumes from it rather than from the load. |
| ResourceNode regrowth (u8) | `_exhausted` | 1 | `RESOURCE_NODE_CAPACITY` = 4096 | `_exhausted == 1` marks a depleted node | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| ResourceNode placement and identity | `_tile`, `_ref_slot`, `_ref_generation` | 4 | `RESOURCE_NODE_CAPACITY` = 4096 | `-1` slot with generation 0 is the null ref | 1 | §4 COMPONENT_COLUMNS | The node's tile plus the directory reference copy. |
| ResourceNode active list | `_live_slots` | 4 | `RESOURCE_NODE_CAPACITY` = 4096 | Only `[0, _live_count)` is meaningful | 2 | §4 COMPONENT_COLUMNS | Rebuilt ascending. |
| Tile-to-node index | `_resource_slot` | 4 | `TILE_COUNT` = 16384 | `-1` for a tile with no node | 1 | §1 WORLD | `WorldTileMaps.resource_slot` in §2's ledger (systems_architecture.md:397). It is the inverse of `_tile`, so the loader cross-checks the two rather than choosing one. |
| Deposit placement scratch | `_deposit_tiles`, `_deposit_ref_slot`, `_deposit_ref_generation` | 4 | `DEPOSIT_NODE_COUNT` = 16 | `-1` slot with generation 0 is the null ref | 3 | -- | R-WORLD-S1-001 §7 RECLASSIFIED THESE FROM CATEGORY 1. They are the working set of ONE placement in progress, not a registry of every deposit: `_refuse_deposit()` writes the footprint before the later field/occupancy checks, `_reserve_deposit_rows()` stores temporary references, and a partial rollback destroys those references WITHOUT clearing the arrays. A freshly allocated arena also holds default zeros, and a later node destruction leaves a stale reference behind. Persisting them would put scratch from a FAILED operation into save and hash state, and a strict live-reference check could then reject legitimate later state. The committed deposit is already recoverable from `_tile`/`_resource_slot` and the ResourceNode rows, which remain category 1. They carry no §1 wire bytes, no count prefix, no null normalization and no canonical field record; the owner's saved field is `_resource_slot` alone, at owner schema 2. |
| Resource node live count | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_live_count`, recomputed with the active list. |
| Resource node scratch | -- | -- | -- | -- | 3 | -- | `_math` and the `_owns_directory` construction flag. |

### `godot/scripts/core/rng.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Per-stream xorshift32 state | `_state` | 4 | `STREAM_COUNT` = 9 | 0 is the UNSEEDED value and is exactly what xorshift32 forbids, so it can never be a live state | 1 | §10 RNG | THE CURRENT STATE, NOT THE SEED. Nine streams in crowd §6.1's SIGNED int32 storage form: a state at or above 2147483648 is stored negative. `stored_state_of()` returns that signed form and `restore_stream()` accepts the UNSIGNED u32 and refuses a negative, so §10 must write `stored_state_of()` and the loader must convert back before restoring. Re-deriving a stream from `_world_seed` on load would restart it at draw 0 and diverge on the very next roll -- silently, because the values are still plausible. |
| Per-stream draw counts | `_draw_count` | 8 | `STREAM_COUNT` = 9 | 0 draws is the seeded state | 1 | §10 RNG | ARCH-RNG-002: "Store state plus int64 draw count", and ARCH-HASH-001 hashes "RNG states/draw counts". They are also the localiser ARCH-HASH-002 dumps on a mismatch, so a divergence names a stream and a draw index rather than "the RNG". |
| RNG seed and seeded flag | -- | -- | -- | `_seeded == false` with `_world_seed == 0` is the unseeded store | 1 | §1 WORLD | `_world_seed` is `World.seed` in §2's ledger. §10 cannot be decoded without it: `restore_stream()` requires a seeded store because the retired HUNTING stream's canonical value is defined against the seed, and SET-AMEND-001 §3 requires a noncanonical tombstone to FAIL validation. ARCH-SAVE-002's section order already puts WORLD (1) before RNG (10), so the load order works; 09.2 must not reorder them. |

### `godot/scripts/core/save_world_runtime_install.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Stateless runtime install adapter | -- | -- | -- | -- | 3 | -- | SAVE-W1-R02 / decision 0153. Static cold-path join of decoded WorldRuntime and RNG records. Temporary 108-byte RNG column snapshot and seed scalars support local recovery; no retained simulation state, duplicate clock/world or new wire fields. The full coordinator owns world association and publication/recovery policy. |

### `godot/scripts/core/save_identity_restore.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Stateless identity restore adapter | -- | -- | -- | -- | 3 | -- | SAVE-D2-R02 / decision 0152. Static cold-path functions join the decoded section 3 record and section 1 allocator cursor through the directory's existing atomic owner API. Constants, borrowed arguments and temporary refusal values add no retained simulation state, packed allocation or wire fields. The coordinator owns the supplied clock/directory world association. |

### `godot/scripts/core/save_codec.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Encoding primitives | -- | -- | -- | -- | 3 | -- | Holds no module-level `var` at all: ARCH-SAVE-001's little-endian integer, two's-complement and length-prefixed-UTF-8 primitives, all static, plus a `Reader` and a `Writer` whose buffers are per-call scratch owned by the caller that constructed them. It is the codec the sections are written THROUGH; it owns no world state, so there is nothing here to save. ARCH-SAVE-007's line that "a memory allocation row alone does not make a field persisted or canonical" is the same point from the other direction. |

### `godot/scripts/core/save_header.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Fixed header and section table | -- | -- | -- | -- | 3 | -- | Holds no module-level `var` beyond the lazily built 256-entry CRC-32/ISO-HDLC lookup table, which is a compile-time constant derived from the reversed polynomial `systems_architecture.md:745` states. Everything else is static: the SAVE-REPLAY-R01 format2/264-byte header codec, the 64-byte descriptor codec, the body SHA-256 and the section-table validator. The pure checkpoint binding validator compares header high/low and tick with decoded section12/section1 values without importing section modules or restoring stores. The header pair is redundant, not a second allocator. The header's own bytes are file structure, not additional simulation state; the catalog hash it carries at offset 72 is `catalog_ids.gd`'s digest, not a second one. |

### `godot/scripts/core/save_section_01.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 1 WORLD composer | -- | -- | -- | -- | 3 | -- | R-WORLD-S1-001. Holds no module-level `var`; every function is static and the only mutable objects are a caller-owned `State`, a caller-owned `Stores` and per-call slices. Writes §1 under SAVE-LAYOUT-R01: the 44-byte map-provenance prefix, `store_count:u32` = **9**, then `buildings`, `entity_directory`, `farming`, `forage`, `resource_nodes`, `spatial_world`, `weather`, `world_init`, `world_runtime` in ASCII key order. Owner schema versions are 1 except **resource_nodes = 2**, and the SECTION schema version is **3**; both moved with the deposit-scratch reclassification below. Seven owners use the ordinary `element_count:u64` + values form; `entity_directory` (4 bytes) and `world_runtime` (80 bytes) keep their existing fixed formats and carry no count prefixes. Payloads total 3752409 bytes, wrappers 311, section length **3752768**, descriptor `row_count` **344067** as the checked sum of the nine primary counts. The decoder reads every wrapper item and every field at a COMPILED absolute offset and compares the declared extents against it, rather than advancing a cursor by what it just read. Restores the seven ordinary owners through their own `restore_section_1_columns()`; the D2 cursor is installed with §3 and `world_runtime` has no side-effect-free publication path (BLOCKER W1). Carries §1's nine canonical value adapters. `State` is 3.75 MB of BOUNDED COLD-PATH CODEC SCRATCH, not a second world. |

### `godot/scripts/core/save_section_event_schedule.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section11 byte adapter | -- | -- | -- | -- | 3 | -- | Decision0161 / SAVE-S11-R01v2. Stateless8+32N codec over existing EventSchedule; exact allocator and row order. Descriptor count0..64, schema1; no inline count/owner wrapper. Does not activate event semantics. |

### `godot/scripts/core/save_section_inventories.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 7 INVENTORIES_AND_LEASE_INDEXES codec | -- | -- | -- | -- | 3 | -- | Decision 0122. Holds no module-level `var`; every function is static and the only mutable objects are a caller-owned `Record`, its six `OwnerRecord` blocks and per-call chunk buffers. Writes §7 under SAVE-LAYOUT-R01: `store_count:u32` = 6, then `fishing`, `forage`, `gear`, `inventory`, `reservations`, `stock_age` in ASCII key order -- each with `owner_key`, `owner_schema_version:u32` (**4 for inventory** under DEMO-CONTAIN-R01 after INV-CANON-R01's 3, **2 for fishing** under FISH-ID-R01, 1 for the other four), `primary_count:u64`, `payload_byte_length:u64`, then `child_extent_count:u32`, its `u64` child extents, and each declared field as `element_count:u64` plus column-major values. `4 + 14947 + 434298 + 688256 + 7887149 + 1212520 + 608353` = **10845527 bytes** at the compiled maxima with every slot free; larger than §3, so ARCH-SAVE-003 chunking applies and the largest chunk is exactly 65536. It writes NO category-2 member -- `_free_heap`, `_job_head`, `_lot_head` and the four chain-link columns are rebuilt by their owners and every count is recomputed from occupancy. It DOES write `inventory.gd`'s `_c_free`/`_l_free` and `stock_age.gd`'s `_declared_slots`, because those are stacks and a swap-ordered dense list whose PERMUTATION is observable -- but only `[0, count)`, since the tail beyond the count is stale garbage two identical worlds can disagree about. `Record` is 11250208 bytes of BOUNDED CODEC SCRATCH on the cold path, larger than the wire image because count-governed columns are held at full backing capacity and u32 scalars occupy int64 cells -- not new authoritative columns and not a second world. BLOCKER I1 IS NARROWED, NOT CLOSED: `inventory.gd` now publishes the quiescent normalized projection INV-CANON-R01 specifies, so `capture_inventory_into()` / `apply_inventory()` handle THAT ONE OWNER and `InventoryAdapter` gives section 15 the same staged block the encoder drains. `stock_age` now publishes its exact owner columns through the separate SAVE-AGE-R01v2 adapter. `reservations` now has its own exact owner boundary and separate block adapter. `gear` now has its exact owner boundary and separate single-block adapter under SAVE-GEAR-R01v2. `fishing` and `forage` now publish exact claim columns through the separate SAVE-CLAIMS-R01 adapter; FISH-ID-R01 adds Fishing's eighth column containing the full Expedition slot. Whole-section/world capture and cross-section reconciliation remain open. The descriptor schema is 5, `fishing` owner schema is 2 and `inventory` owner schema is 4, activated with registry version 7 and the compiled declaration table (decision 0531 appended `_c_anchor_tile` as inventory ordinal 30; schema 4 came with FISH-ID-R01). `decode_into_versioned` refuses a stale section descriptor before reading owner blocks, and the ordinary decoder refuses Fishing owner schema 1 and Inventory owner schema 3 before their bodies; no missing identity or placement is guessed. |

### `godot/scripts/core/save_section_job_indexes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 8 JOB_INDEXES codec | -- | -- | -- | -- | 3 | -- | Decisions 0120, 0146 and 0157 / SAVE-J2-R01. Static codec for one job_planner owner, owner/section schema2, primary count8192. The original29 ordinals are unchanged; append three dirty arrays and three scalar counts at ordinals29..34. Payload384164 = 35×8 + 383884 canonical-value bytes; total section384203 = 39 + 384164. Descriptor-aware decode validates the readable23-byte owner preamble and owner/section versions before requiring the current full extent. Old development schemas refuse explicitly. |
| Section 8 decode/capture scratch | -- | var | five tables plus scalar counts | each field's declared unused value | 3 | -- | Record holds383884 bytes before object overhead, an increase of21004. Two records grow42008 bytes; queue validation additionally reuses one local4096-byte seen-bit array. These are bounded cold-path codec allocations. Existing live dirty arrays/counts become canonical, with zero tails and exact order; membership bits derive from prefixes. BLOCKER J2 remains: live capture/apply need a separately contracted owner bulk API and cross-owner validation. |

### `godot/scripts/core/save_section_navigation.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 9 NAVIGATION codec | -- | -- | -- | -- | 3 | -- | Decision 0121. Holds no module-level `var`; all static, with a caller-owned `Record`, a caller-owned `Derived` and per-call buffers. Writes §9 under SAVE-LAYOUT-R01: `store_count:u32` = 2, then `movement` (schema 1, primary 512, payload 18504) and `navigation` (schema 2, primary 8192, payload 5161468 + 4*(heap_size + arena_used)) in ASCII key order, column-major, in declared ordinal order -- **5180042 bytes empty, 10422922 maximum**. It owns none of that state: the classified rows are `navigation.gd`'s six and `movement.gd`'s three §9 groups. Only `_heap` and `_arena` are `count_field`-shaped and only those are prefix-truncated; `_g`, `_parent`, `_heap_position` and `_state` are declared at full `CELL_COUNT` with `ascending_physical_slot` and are written verbatim, because sparsifying them changes what the §15 digest covers and needs a ruling. `Record` is 18432+52+4194304+262144+16384+688128+1048576+4194304 = **10422324 bytes** and `Derived` is 8192+1024+1024 = **10240 bytes** of BOUNDED CODEC SCRATCH on ARCH-SAVE-003's cold path -- not new authoritative columns, and neither exists between a save and a load. |

### `godot/scripts/core/save_section_name_pool.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 14 NAME_POOL codec | -- | -- | -- | -- | 3 | -- | Holds no module-level `var`: every function is static and the only mutable objects are a caller-owned `Record` and a per-call `Writer`. It WRITES §14 -- `store_count:u32` = 1, then the 33-byte owner wrapper (4 key length + 9 `residents` + 4 `owner_schema_version` + 8 `primary_count` + 8 `payload_byte_length`), then the RETAINED inner `row_count:u32` = 512 and 512 rows of `utf8_byte_count:u32 LE` plus exactly that many UTF-8 bytes. Framing is 4 + 33 = 37 bytes and SECTION schema version is 2 (decision 0112); both counts are validated, and `payload_byte_length` against `length - 37` from the descriptor rather than only against bounds -- but owns none of that state itself, exactly as ARCH-SAVE-007 says a memory allocation row alone does not make a field persisted. The classified row for what it carries is `residents.gd`'s "Resident name" (`_name_key`) above. THE FORMAT'S FIRST VARIABLE-LENGTH SECTION: length is no longer the validation, so the row count is written explicitly and `decode_into()` takes the descriptor length and bounds every row against the section end rather than the buffer end, the layout being gapless. `canonical_bytes_of()` emits the 512 values WITHOUT the row-count prefix, because SAVE-R09's canonical field record supplies `value_count` itself. See [decision 0099](decisions/0099-the-first-variable-length-save-section-frames-its-own-row-count.md). |
| Section 14 decode/capture scratch | -- | var | `ROW_COUNT` = 512 | The empty string, `_name_key`'s declared canonical unused value | 3 | -- | `Record.names`, a 512-row `PackedStringArray` inside the codec's inner `Record` class -- not a module-level `var` -- mirroring `residents.gd::_name_key` for the duration of one save or one load; the authoritative column stays in `residents.gd`. Transient under decision 0063's accounting, which counts it without persisting it. Fixed framing arithmetic: PAYLOAD `4 + 512*4` = 2052 minimum, starter settlement 2064, maximum `2052 + 512*128` = 67588. The SECTION adds 37 bytes of framing: 2089 minimum, starter settlement 2101, maximum 67625 (decision 0112). The 131072-byte arena limit is unchanged and still enforced independently. `apply()` also allocates a 512-byte PackedByteArray snapshot of the incoming `_named` column so a refused restore rolls back to the exact prior pair -- cold path, one per load, freed on return. |

### `godot/scripts/core/save_section_directory.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 3 ENTITY_DIRECTORY codec | -- | -- | -- | -- | 3 | -- | Holds no module-level `var`; every function is static and the only mutable objects are a caller-owned `Record`, a caller-owned `Derived` and per-call chunk buffers. It WRITES §3 under SAVE-LAYOUT-R01's block framing -- `store_count:u32`=1, `owner_key` "entity_directory", `owner_schema_version:u32`=1, `primary_count:u64`=352418, `payload_byte_length:u64`=6343572, then column-major `_active:u8`, `_generation:i32`, `_retired:u8`, `_persistent_id:i32`, `_kind:i32`, `_typed_row:i32` at full capacity; 44 + 6*8 + 18*352418 = 6343616 bytes -- but owns none of that state: the classified rows are `entity_directory.gd`'s eight above. It deliberately writes NO category-2 member. `_typed_owner_slot` and both counter groups are rebuilt by `rebuild_into()`; the two min-heaps are rebuilt by the directory's own `_rebuild_free_heaps()`, because only their live prefix is meaningful and persisting the tail would make two identical worlds produce different bytes. `Record` is 18*352418 = 6343524 bytes and `Derived` is 4*352418 + 2*4*18 = 1409816 bytes of BOUNDED CODEC SCRATCH on ARCH-SAVE-003's cold path -- not new authoritative columns and not a second world; neither exists between a save and a load, and the streaming `ChunkCursor` holds at most 65536 bytes at a time. `_next_persistent_id` stays §1 WORLD's and is not written here.

### `godot/scripts/core/save_section_pending_commands.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 12 PENDING_COMMANDS codec | -- | -- | -- | -- | 3 | -- | Decision 0123. Holds no module-level `var`; all static with a caller-owned `Record`. Writes §12 in the record-major exception form retained from SAVE-LAYOUT-R01, with SAVE-SEQ-R01's schema3 extension. Prefix28 bytes: section_schema:u32=3, economic_count E:u32, payload_used P:u32, scheduler_extension_bytes X:u32=48+32*S, next_low:u32 at16, next_high:u64 at20. Then E unchanged64-byte command records, P exact arena bytes and unchanged SCHQ0001 schema1 extension (tag8, version4, length4, control32, S32-byte records). `76 + 64*E + P + 32*S`: **76 empty,1318988 maximum**. It owns none of that state -- the classified rows are `commands.gd`'s and `scheduler_events.gd`'s. It writes NO category-2 member: both ring `_head` values and `commands.gd`'s `_order` are rebuilt, and arena bytes no pending span covers are ZEROED per ARCH-SAVE-002. `Record` is 32768 + 229376 + 1048576 + 2048 + 6144 = **1318912 bytes** of bounded codec scratch on the cold path, exactly `MAX_SECTION_BYTES - 76`; it exists only between a capture and an apply and never during a tick, so like every other `save_section_*` codec it takes no §2.3 allocation row. SAVE-P2-R02 supersedes the former admission-based restore: `apply()` requires one shared clock, matching saved boundary, a held load barrier and two empty target queues. It installs the exact economic window through `restore_pending_window()` before `restore_extension()`, checks restoration of the prior empty economic window/allocator if the scheduler refuses, and reports `SAVE_PC_ROLLBACK_FAILED` with the barrier held if that recovery fails. Bounded additional apply scratch is at most262144 encoded economic bytes,1048576 used-prefix bytes and32768 span-sort bytes; no second live queue or retained column is added. |

### `godot/scripts/core/save_section_rng.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 10 RNG codec | -- | -- | -- | -- | 3 | -- | Holds no module-level `var`: every function is static and the only mutable objects are a caller-owned `Record` and a per-call `Writer`. It WRITES §10 -- nine `rng.gd` states at offset 0 as i32 and nine draw counts at offset 36 as i64, a fixed 108-byte payload -- but owns none of that state itself, exactly as ARCH-SAVE-007 says a memory allocation row alone does not make a field persisted. The classified rows for what it carries are `rng.gd`'s three above. |

### `godot/scripts/core/save_section_world_runtime.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section 1 WorldRuntime codec | -- | -- | -- | -- | 3 | -- | Holds no module-level `var`; all static. It writes the leading 80-byte WorldRuntime block of §1 -- completed tick, world seed, seeded flag, requested speed, pause mask, then host debt and the six clock counters -- whose classified rows are `sim_clock.gd`'s four and `rng.gd`'s "RNG seed and seeded flag" below and above. Its two encoders realise the READY_07 G3 split: `encode_block()` writes all thirteen fields and `canonical_bytes_of()` writes only the five ARCH-HASH-001 ones, so debt and the counters are saved and CRC/SHA-protected without entering the canonical digest. It does NOT publish into `sim_clock.gd`, which has no writer for the tick, the debt or the counters. |
| Section 1 composition | -- | -- | -- | -- | 3 | -- | Decision 0115. This module also composes the whole section: the 44-byte map-provenance prefix, `store_count:u32` bounded by REG-R01's nine §1 owners, then owner blocks in ASCII key order tiling the remainder with no gaps. Two blocks exist today -- `entity_directory` at 44 bytes and `world_runtime` at 117 -- giving a 209-byte development section. `DEBT_MAX` is now `INT64_MAX`, not `INT64_MAX/4`: the old cap made this codec REFUSE debts `sim_clock.restore_runtime()` accepts, which is the asymmetry RESTORE-R01 resolves in favour of the whole domain. Seven registered §1 owners still have no encoder; `missing_owner_keys()` reports them and `decode_section()` measures a foreign block's extent so its owner can decode its own payload without this module guessing a schema. |

### `godot/scripts/core/schedule.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Activity templates | `_template_hours` | 1 | `TEMPLATE_COUNT * HOURS_PER_DAY` = 72 | Three templates x 24 hours | 2 | §2 CATALOG_IDS | Compiled from the catalog at construction; rebuilt on load. |
| Per-resident hourly schedule | `_hourly_activity` | 1 | `SCHEDULE_CAPACITY * HOURS_PER_DAY` = 12288 | One byte per (resident, hour); the value is a real activity, never absence | 1 | §4 COMPONENT_COLUMNS | Player-authored by SET_ACTIVITY_SCHEDULE commands, so nothing recomputes it. ARCH-SAVE-005 bounds each byte by `ACTIVITY_COUNT`. |
| Schedule assignment | `_template`, `_current_activity` | 4 | `SCHEDULE_CAPACITY` = 512 | None on a live row | 1 | §4 COMPONENT_COLUMNS | `_current_activity` is resolved each hour but is read within the hour it is set, so a mid-hour save must carry it. |
| Schedule flags | `_present`, `_sleep_satisfied`, `_resolved` | 1 | `SCHEDULE_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | `_sleep_satisfied` is the sleep-exception latch. `_resolved` records that at least one successful resolve produced `_current_activity`; it is retained across timetable edits and template reassignment, not derived from the current hour. Decision0172 pins saved local consistency without re-resolving history. |
| Schedule catalog and count | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_template_ids` and `_catalog_error` are rebuilt from the catalog; `_present_count` is recomputed from `_present`. |
| Schedule scratch | -- | -- | -- | -- | 3 | -- | `_hunger_scratch` and `_rest_scratch`, consumed inside one hourly resolve. |

### `godot/scripts/core/scheduler_events.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Scheduler event boundary tick | `_boundary_tick` | 8 | `QUEUE_CAPACITY` = 256 | Rows outside `[0, _count)` from `_head` are stale; the contract serializes no unused row | 1 | §12 PENDING_COMMANDS | R07-SCHED-001's queue. ready07's save contract puts it in section 12 as the `SCHQ0001` extension AFTER the economic records, not in §11 EVENT_SCHEDULE -- §11 is for timed game events, of which none is implemented. BLOCKED: `encode_extension_into()`/`restore_extension()` implement the subsection in full with validation and are UNWIRED. What they need is a caller -- 09.2's §12 writer must emit tag `SCHQ0001`, schema_version 1, payload length 32+32*count, the canonical head=0 control header, then count records in queue order -- not more state here. |
| Scheduler event record fields | `_sequence_low`, `_sequence_high`, `_kind`, `_reason`, `_value`, `_reserved` | 4 | `QUEUE_CAPACITY` = 256 | `_reserved` is zero padding and ARCH-SAVE-005 rejects it nonzero | 1 | §12 PENDING_COMMANDS | The sequence halves hold u32 BITS in i32 columns, so a sequence past 0x80000000 stores NEGATIVE and `compare_sequence()` masks before comparing; a codec that sign-extends reverses two events. `(0, 0)` is the EXHAUSTED sentinel, never a valid event. |
| Queue control header | -- | -- | -- | `_last_drained_boundary == -1` (`NO_PRIOR_DRAIN`) before the first drain | 1 | §12 PENDING_COMMANDS | `_head`, `_count`, `_next_sequence_low`, `_next_sequence_high`, `_last_applied_sequence_low`, `_last_applied_sequence_high` and `_last_drained_boundary` are the contract's 32-byte control block. `_head` restores canonically to 0. Validation on load: last_applied precedes every pending sequence, next sequence exceeds every admitted one, and the pending boundary equals the saved completed tick.  |
| Scheduler diagnostics and wiring | -- | -- | -- | -- | 3 | -- | `_executing`, `_overload_issued_this_frame`, `_admitted_count`, `_coalesced_count`, `_refused_count`, `_applied_count`, `_pump_count`, `_last_refusal`, the three scratch records and the four `Callable` hooks. The callables are host wiring. ARCH-HASH-001 excludes debt/timing/diagnostics, not all scheduler state; requested speed, pause and pending scheduler records remain canonical (decision 0063). |

### `godot/scripts/core/sim_clock.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Completed tick | -- | -- | -- | -- | 1 | §1 WORLD | `_completed_tick` is `World.tick` in §2's ledger and the save header's completed tick at offset 32. ARCH-SAVE-003 saves only a completed boundary, so this is the tick the whole file is stamped with, and the calendar is ALWAYS derived from it as `(tick + 4500) mod 18000` -- never stored separately, never `tick % 18000 == 0`. RESTORE-R01 (decision 0089): `sim_clock.gd::restore_runtime()` is the ONE validated writer for this field and the nine below, and it assigns nothing until all ten validate. No new column is declared by it. |
| Requested speed and pause mask | -- | -- | -- | `_pause_mask == 0` means not paused; `PLAYER` is its initial value | 1 | §1 WORLD | `WorldRuntime.requested_speed` and `WorldRuntime.pause_reasons` in §2's ledger (systems_architecture.md:405), and `docs/planning/ready07_scheduler_contract.md:116-117` says to keep them with WorldRuntime. ARCH-HASH-001's exclusion list does not name them. They change no tick's CONTENT -- speed runs identical ticks faster -- but a CRITICAL or VICTORY pause is a simulation-caused state that a reload must not clear. |
| Host scheduler debt | -- | -- | -- | Nonnegative I64 | 1 | §1 WORLD | `_debt` is required persisted host-continuation metadata (ARCH-SAVE-007), **excluded from ARCH-HASH-001** but protected by body digest/CRC. Restore exactly, reset host sample origin, never charge load time or discard owed ticks. |
| Historical clock counters | -- | -- | -- | Nonnegative I64 | 1 | §1 WORLD | `_fallback_count`, `_diagnostic_pause_count`, `_acknowledged_catchup_resets`, `_acknowledged_ticks_discarded`, `_subtick_debt_discards`, `_day_boundaries_crossed`: persist all six under ARCH-SAVE-007, exclude from ARCH-HASH-001. No new discard authorization. |
| Clock transient diagnostics and scratch | -- | -- | -- | -- | 3 | -- | `_last_diagnostic`, `_last_error`, `_math` and signal/wiring handles reset or rebind. Raw host timestamps and time spent loading are not saved debt. |

### `godot/scripts/core/spatial_world.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Cell passability and layer | `_walkable`, `_layer` | 1 | `CELL_COUNT` = 262144 | `_walkable == 0` blocks; `_layer` is always 0 in the single-floor baseline | 1 | §1 WORLD | 512x512 cells at 512 units. `_layer` is allocated for MOVE-G03's multi-floor scope and is currently constant: 09.2 writes it as it stands and must not repurpose the byte when floors land. |
| Cell terrain and height | `_terrain`, `_height_units` | 4 | `CELL_COUNT` = 262144 | None; every cell has both | 1 | §1 WORLD | Height in 1/1024 m units, int32, per AGENTS.md. |
| Cell clearance | `_clearance` | 4 | `CELL_COUNT` = 262144 | 0 = no clearance computed yet | 2 | §1 WORLD | A derived distance field over `_walkable`; `_clearance_dirty` exists precisely because it is recomputed. Writing it would let a save disagree with its own passability map. |
| Map revision and scalars | -- | -- | -- | -- | 1 | §1 WORLD | `_map_revision` is `World.map_revision` in §2's ledger and is compared against `navigation.gd`'s cached `_d_map_revision`/`_r_map_revision`, so a restored world that restarted the revision counter would silently accept stale routes. `_walkable_count` is recomputed, `_clearance_dirty` must be resolved before a save, `_last_refusal` is diagnostic. |

### `godot/scripts/core/save_component_columns_schema.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable component metadata | -- | -- | -- | -- | 3 | -- | Decision0169 / SAVE-S4-STREAM-R01v2. No mutable module state. Fifteen compiled const Arrays:781 integer cells x8 +4288 UTF8 key bytes =10536 logical payload bytes, shared once and ledgered separately. Array/Variant/String headers, scalar constants and native overhead are not measured by this arithmetic. Generator independently checks298 source capacities and canonical field identities. Runtime reads no JSON or live owners. |

### `godot/scripts/core/save_section_component_columns.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Component framing cursors and one-owner record | -- | -- | -- | -- | 3 | -- | Decision0169. No resident module state. FramedOwner contains one owner's exact typed buckets; transient capture/decode transport is not a new canonical owner. Conditional maximum6417408 value/transient bytes assumes callers release every owner reference before feeding the next wrapper. Immutable10536-byte metadata is charged separately. Partial records cannot escape; full physical values remain unchanged. Structural acceptance alone cannot authorize installation: semantic validators, owner adapters, cross-section consistency and coordinator are separate tasks. |

### `godot/scripts/core/save_owner_needs.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Pure owner9 semantic bridge | -- | -- | -- | -- | 3 | -- | Decision0170 / NEEDS-S4-VALIDATE-R01v2. No mutable module state or live owner construction. A temporary Columns projection shares all20 framed packed buffers and calls the same pure predicate as live restore. Conditional135168 logical bytes conservatively covers framed image57344 + constructor defaults57344 + largest returning range sort-copy20480. Native/wrapper overhead is unmeasured. Exact health/death equivalence prevents the demonstrated living-count drift. No complete Needs/world validity or owner publication follows. |

### `godot/scripts/core/save_owner_priorities.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Pure owner11 policy validator | -- | -- | -- | -- | 3 | -- | Decision0171 / PRIORITIES-S4-VALIDATE-R01v1. No mutable module state or live owner construction. Four caller-owned byte columns feed the same static predicate reusable by future bulk restore. Exact domains and reserved/free rules preserve player choices. The7680framed bytes are already inside the streaming allowance; no default projection, duplicate or sort buffer is added. Native/wrapper overhead is unmeasured. This does not supply bulk APIs, present_count rebuild or cross-owner/publication validity. |

### `godot/scripts/core/save_owner_schedule.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Pure owner14 saved-history validator | -- | -- | -- | -- | 3 | -- | Decision0172 / SCHEDULE-S4-VALIDATE-R01v1. No mutable module state, live owner construction or catalog dependency. Six typed caller-owned packed columns feed the static predicate, which shares the existing inactive-row rule. Full physical domain and local history checks preserve customized timetables and resolved activity history. The17920framed bytes are already inside the streaming allowance; no projection, duplicate or sort buffer is added. Native/wrapper overhead is unmeasured. No bulk APIs, present_count rebuild, section2 catalog identity, cross-owner validity or publication is supplied. |

### `godot/scripts/core/save_owner_transforms.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Pure owner15 pose and binding validator | -- | -- | -- | -- | 3 | -- | Decision0173 / TRANSFORMS-S4-VALIDATE-R01v1. No mutable module state or live owner/Directory construction. Nine typed caller-owned i32 columns feed the static predicate; positive binding uniqueness uses one private350208-byte duplicate-and-sort. Framed3151872 + scratch350208 + three65536stream windows =3698688logical packed bytes, below existing6417408one-owner stream allowance. Native/wrapper overhead is unmeasured. Preserve all signed pose/yaw values, independent current/previous and legitimate stale bindings. Bulk APIs/nonzero-stamp count rebuild and saved cursor/Directory identity remain separate. |

### `godot/scripts/core/save_owner_buildings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Buildings validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner0 bridge, BUILDINGS-S4-VALIDATE-R01v1/ADR0183. No mutable authoritative state or live owner construction. Columns(false) borrows29 pre-shaped buffers; no full second3298304-byte image. Logical4150272 envelope within6417408 stream allowance; native/RSS costs unqualified. Retired building/room/furniture history preserved. Directory/section1/section5 identity, geometry, chain, arena, construction/user/clock joins and bulk restoration remain BUILDINGS-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_construction.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Construction validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner1 bridge, CONSTRUCTION-S4-VALIDATE-R01v2/ADR0186. No mutable authoritative state or live owner construction. Columns(false) borrows16 pre-shaped buffers; no second4893696-byte default image or packed scratch. Caller4893696 + two663552 field copies + three65536 stream windows =6417408 logical packed allowance; native overhead remains unmeasured. Retained purpose, type, phase and refund history are preserved. Same-file Directory/Buildings identity, section5 delivered-material ledger, material conservation, clock and bulk restoration remain CONSTRUCTION-SAVED-BINDINGS. Classification is not candidate acceptance. |

### `godot/scripts/core/save_owner_movement.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Movement validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner8 bridge, MOVEMENT-S4-VALIDATE-R01v1/ADR0182. No mutable authoritative state or live owner construction. Caller32768 + cold Columns defaults32768 =65536 conservative logical packed bytes, within6417408 stream allowance; native/transitive preload costs unmeasured. ARRIVED final velocity and zero one-cell targets are retained. Same-file cursor/Residents/navigation/Transforms/clock joins and bulk restoration remain MOVEMENT-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_fishing.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Fishing habitat and stock validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner4 bridge, FISHING-S4-VALIDATE-R01v1/ADR0181. No mutable authoritative state or live owner construction. Caller5344 + cold Columns defaults5344 =10688 conservative logical packed bytes; fixed32-row duplicate scans add no packed scratch, within6417408 stream allowance; native/RSS unmeasured. Inactive habitat history is retained while stock rows are blank. Same-file Directory/Forage/claims/catalog/clock bindings and bulk restoration remain FISHING-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_farming.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| FarmPlot saved validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner2 bridge, FARMING-S4-VALIDATE-R01v1/ADR0180. No mutable authoritative state or live owner construction. Caller266240 + cold Columns defaults266240 + two4096 i32 sort copies32768 =565248 conservative logical packed bytes, within6417408 stream allowance; native/RSS unmeasured. Present crop-state relations differ from broad inactive retained history. Same-file TileHistory/Directory/clock bindings and bulk restoration remain FARMING-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_field_policy.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| FieldPolicy saved validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner3 bridge, FIELD-POLICY-S4-VALIDATE-R01v1/ADR0179. No mutable authoritative state or live owner construction. Caller44288 + coldColumnsdefaults44288 + three128i32OPENcount scratch1536 =90112logicalpackedbytes within6417408stream allowance, not measuredRSS. Closed/inactive/stale history preserved; same-file Directory/Forage/Farming bindings and bulk restoration remain FIELD-POLICY-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_residents.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Residents saved validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner12 bridge, RESIDENTS-S4-VALIDATE-R01v1/ADR0178. No mutable authoritative state or live Residents construction. Existing caller Columns projection shares framed buffers; conservatively caller102912 + transient defaults102912 + existingXPsort49152 =254976logical packedbytes within6417408stream allowance, not measuredRSS. Native/wrapper overhead unmeasured. Catalog/Directory/Needs/names/equipment and complete restore remain RESIDENTS-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_injury.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Injury saved validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner6 bridge, INJURY-S4-VALIDATE-R01v1/ADR0177. No mutable authoritative or packed state, live owner construction or extra packed scratch. Caller20992bytes remain in stream allowance; ordinary cold refusal wrappers and native overhead are unmeasured. Saved Needs/Directory/resident/movement agreement and bulk restoration remain INJURY-SAVED-BINDINGS. |

### `godot/scripts/core/save_owner_resource_nodes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| ResourceNodes saved validation bridge | -- | -- | -- | -- | 3 | -- | Pure owner13 scalar-domain bridge. No packed storage or live owner; caller172032bytes stay in stream allowance. Saved inverse/Directory/catalog identity and combined restore remain separate prerequisites. |

### `godot/scripts/core/save_owner_work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Pure owner16 carry and tool-binding validator | -- | -- | -- | -- | 3 | -- | Decision0175 / WORK-S4-VALIDATE-R01v1. Existing owner version2. Eight typed caller-owned i32 columns plus one byte column feed a static local-domain predicate; no live owner construction, mutation, projection or packed scratch. Memory keeps the full signed range, carries survive unbound rows and stale current-job bindings remain history. The39424framed packed bytes are already inside the stream allowance; native/wrapper overhead is unmeasured. Saved Gear/Inventory/Jobs/resident ownership and claim consistency, bulk restore and derived bound count remain separate prerequisites. |

### `godot/scripts/core/save_owner_world_init.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---|---|---|:-:|---|---|
| Pure owner17 reserved-fauna validator | -- | -- | -- | -- | 3 | -- | Decision0174 / FAUNA-S4-VALIDATE-R01v1. No mutable module state or WorldInit/collaborator construction. Eight i32 and one i64 caller-owned columns feed the shared static predicate. Every row is fixed empty: null zone reference (-1,0), all other values zero. The15360framed packed bytes are already inside the streaming allowance; no projection, duplicate or scratch is added. Native/wrapper overhead is unmeasured. Source null sentinels are pinned before column reads. No hunting, repair, combined section1/4 restoration or publication is supplied. |

### `godot/scripts/core/save_resource_claims_reconcile.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Read-only claim checker | -- | -- | -- | -- | 3 | -- | Decision0168 / SAVE-CLAIM-CHECK-R01v2. No module-level mutable state or live owner access. New caller-owned component projections total148768 packed bytes; private Directory Derived, two internal Directory-validator sort copies and 32+128 int64 sums have a conservative4230440-byte packed allocation bound, not RSS. Compares exact live/stale ownership, provenance, ecological references and all saved aggregates without mutation. Result and temporary sums are cold scratch, not canonical/resident columns. Actual section4/file projection, versions and coordinator invocation remain SAVE-CLAIM-WORLD-BINDING; no complete-save acceptance. |

### `godot/scripts/core/save_resource_claims_restore.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Exact resource claim block adapter | -- | -- | -- | -- | 3 | -- | SAVE-CLAIMS-R01v2 / decision0166. Stateless single-block section7 owner0/1 adapter. Total shape and codec admission precede exact owner publication; apply requires supplied held clock. No Inventory dependency. No other-section aggregates or canonical ordering fields rebuilt. Separate checked cross-section claim reconciliation must pass before full-world activation. |

### `godot/scripts/core/save_gear_restore.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Exact Gear owner block adapter | -- | -- | -- | -- | 3 | -- | Stateless single-block section7 owner2 adapter. Total shape before codec access; capture stages before publication. Apply requires supplied held clock barrier. Both paths require supplied idle Inventory, matching any existing Gear binding. Owner refreshes five catalog IDs on restore and preserves equipped rows, bare identities and claims. No schema change, full-section/world acceptance or collaborator mutation; owner refuses codec-admitted incompatible reference pairs without repair. |

### `godot/scripts/core/save_reservations_restore.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reservations block adapter | -- | -- | -- | -- | 3 | -- | Decision0163 / SAVE-RES-R01v2. Stateless single-OwnerRecord bridge. Caller supplies a nonbusy Inventory; apply also requires a held clock barrier. Exact eight canonical fields and row IDs; private cold staging only. Target constructor job/lot extents interpret the unchanged wire. No Inventory binding, total reconciliation, full-section assembly or valid-world publication. |

### `godot/scripts/core/save_stock_age_restore.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| StockAge block adapter | -- | -- | -- | -- | 3 | -- | Decision 0162 / SAVE-AGE-R01v2. Stateless static bridge from one caller-owned section 7 `OwnerRecord` to StockAge columns. Cold-path local records and membership validation only; capture publishes after shape, binding, busy and semantic checks; apply requires a supplied held load barrier. No whole-section assembly or Inventory restore. No new canonical field or wire change. |

### `godot/scripts/core/store_policy.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| BuildingItemAllow | `_allowed` | 1 | `POLICY_CELLS` = 262144 | 1 (`ALLOWED`) in every cell of an unbound row and for every item a bound building has not restricted; a row whose stamp below does not name the live building is read as all-1 whatever its bytes say | UNRESOLVED | §5 CHILD_ARENAS | [Decision 1031](decisions/1031-store-filters-and-minimums-are-a-building-keyed-arena.md): REQ-SET-117's per-item store filter, `systems_architecture.md` §3's BuildingItemAllow row (262144 B). Owner-major at fixed stride `ITEM_CAPACITY` = 256: cell `building_row * 256 + item_id`, `building_row` being the Building's DIRECTORY typed row. It decides which main store a hauler may deliver an item to, so it is future-affecting and this registry's reading is category 1. QUESTION: which owner and ordinals carry it in `canonical_state_registry.json` -- a separate `store_policy` owner in §5 CHILD_ARENAS, or the buildings owner (decision 1031's P4)? No codec writes it until that is answered, like the rest of task 06's unbound stores. A codec must write a STALE row (stamp not naming the live building) as all-1, or hash it so, because its leftover bytes are unreachable and must not split two equivalent worlds. |
| BuildingItemMinimum | `_minimum_milli` | 8 | `POLICY_CELLS` = 262144 | 0 (`NO_MINIMUM`) in every cell of an unbound row; a stale row reads as all-0 | UNRESOLVED | §5 CHILD_ARENAS | Decision 1031: REQ-SET-117's per-item minimum reserve held back from ORDINARY production (emergency meal access is the one override and does not read it), §3's BuildingItemMinimum row (2097152 B). Same cell formula and same stale-row rule as the row above. QUESTION: which owner and ordinals carry it -- the same question as the row above (decision 1031's P4)? Category 1 by this registry's reading. int64 `quantity_milli`, nonnegative, no upper bound stated by any document. |
| Policy binding stamp | `_bound_persistent_id` | 4 | `BUILDING_CAPACITY` = 1024 | 0 (`UNBOUND`): the directory issues persistent IDs from 1, so 0 names no building | UNRESOLVED | §5 CHILD_ARENAS | Decision 1031, NEW (+4096 B, not in §3's two rows): the never-reused persistent ID of the building whose policy each row holds. A reused Building row whose stamp names a demolished building reads as the defaults, and its first write resets all 256 cells before stamping. NOT derivable from the two arenas: a reused row that was never written carries the dead building's bytes, so rebuilding the stamp from "who lives at this row now" would hand them to the newcomer. QUESTION: which owner and ordinals carry it beside the two arenas it qualifies (decision 1031's P4)? Category 1 by this registry's reading. |
| Bindings and scratch | -- | -- | -- | -- | 3 | -- | `_buildings`, `_inventory` and `_directory` are wiring rebound by the composer. There is no scratch. |

### `godot/scripts/core/stock_age.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Storage declarations (u8) | `_c_storage_class`, `_c_heated_interior` | 1 | `CONTAINER_CAPACITY` = 101376 | `_c_storage_class == 0` (`STORAGE_UNDECLARED`) means no declaration, and such a container is never aged | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | GDD §5.8's store factor and the heated-interior exception, per `inventory.gd` CONTAINER SLOT. Future-affecting in the plainest sense: drop them and every stored lot stops aging, so a reloaded world's food never spoils. Their eventual owner is the §5.9 building/furniture layer (ARCH-SYS-016), which has no store yet; when it lands these become a mirror it writes and this row becomes a category 2 rebuild, which is a contract change and not a default. |
| Declaration generation | `_c_declared_generation` | 4 | `CONTAINER_CAPACITY` = 101376 | 0 on an undeclared slot, which is also `inventory.gd`'s null generation | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | THE GENERATION IS `inventory.gd`'s CONTAINER generation space, not the entity directory's -- the same two-namespace point the inventory rows above make. A loader that restored the class bytes without this column would let a recycled container slot inherit the storage class of the container that used to occupy it, which silently changes a cellar into an open pile. |
| Declared slot list | `_declared_slots` | 4 | `CONTAINER_CAPACITY` = 101376 | Only `[0, _declared_count)` is live; the rest hold `-1` (`NULL_SLOT`) | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A DENSE LIST WHOSE ORDER IS OBSERVABLE, which is why it is category 1 rather than a rebuilt index. Withdrawal swaps the last entry into the freed position, so the order is not recoverable from `_c_storage_class` ascending, and it is the order containers are swept in. A lot that expires to nothing RETIRES its row, pushing that slot onto `inventory.gd`'s last-freed-first free stack; two different sweep orders therefore hand the next `create_lot()` different slots. Rebuilding it ascending would be a different world, not the same one. |
| Declared count and hourly latch | -- | -- | -- | -- | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_declared_count` is the live length of the list above. `_last_hour_tick == -1` (`NO_HOUR_RUN`) means the pass has never run; it is the only thing stopping an hour being aged twice or skipped across a save taken at an exact crossing, and midnight is one of ARCH-SAVE-006's named coverage cases. Same argument as `crop_weather.gd`'s latch, which is category 1 for the same reason. |
| Bound stores and scratch | -- | -- | -- | -- | 3 | -- | `_inventory` and `_definitions` are wiring references rebound at load; `_calendar`, `_math`, `_store_factor`, `_temperature_factor`, `_last_refusal` and the separate `_last_column_refusal` are scratch. SAVE-AGE-R01v2 copies/restores the four canonical arrays and two scalars exactly; restore invalidates only the two compiled-id caches, preserving order and stale generations until normal sweep. `_spoiled_food_id` and `_compost_id` are cached lookups of the compiled `spoiled_food` and `compost` ids and are re-resolved from the catalog the save header pins, never written. |

### `godot/scripts/core/transforms.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Current pose | `_x`, `_y`, `_z`, `_yaw` | 4 | `TRANSFORM_CAPACITY` = 87552 | An unbound row holds 0; `_bound_persistent_id == 0` is what marks it unbound | 1 | §4 COMPONENT_COLUMNS | int32 positions in 1/1024 m units, -Z forward, per AGENTS.md. ARCH-HASH-001 requires "current/previous authoritative Transform fields, not first-frame presentation overrides". |
| Previous pose | `_prev_x`, `_prev_y`, `_prev_z`, `_prev_yaw` | 4 | `TRANSFORM_CAPACITY` = 87552 | Same as the current pose | 1 | §4 COMPONENT_COLUMNS | Canonical current and previous pose fields remain exact across load, digest verification and publication. ARCH-HASH-001 includes both and excludes first-frame presentation overrides; ARCH-SAVE-004 verifies the installed digest again. Load previous=current is a presentation-only override, never a canonical history rewrite (decision0173). |
| Transform binding | `_bound_persistent_id` | 4 | `TRANSFORM_CAPACITY` = 87552 | 0 = the row is bound to nothing | 1 | §4 COMPONENT_COLUMNS | Decision 0053's TransformBinding: which entity's persistent id owns the row. Persistent ids are never reused, so this survives slot reuse across a reload. |
| Transform bound count | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_bound_count`, recomputed from the nonzero entries of `_bound_persistent_id`. |
| Transform refusal code | -- | -- | -- | -- | 3 | -- | `_last_refusal` and the directory handle. |

### `godot/scripts/core/weather.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Weather row, int32 columns | `_row` | 4 | `ROW_COLUMN_COUNT` = 8 | Eight named columns indexed by `COL_*`; none is an absence marker | 1 | §1 WORLD | GDD §4.2's single Weather row. The active event, its remaining duration and the season's selected event all sit here; ARCH-RNG-002 forbids per-season reseeding, so a reload that recomputed the event from the season would consume a WEATHER draw that the uninterrupted run did not. |
| Weather row, int64 columns | `_row64` | 8 | `ROW64_COLUMN_COUNT` = 2 | `ABSOLUTE_SEASON_NONE` marks "no season scheduled" | 1 | §1 WORLD | Decision 0055's absolute-season identity and the scheduled-once latch. The latch is what stops one season's event being selected twice, so it is future-affecting in the strongest sense. |
| Weather scratch | -- | -- | -- | -- | 3 | -- | `_math` and `_calendar`. |

### `godot/scripts/core/work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Work remainders (i32) | `_potential_remainder` | 4 | `RESIDENT_CAPACITY` = 512 | 0-999 each; 0 is a real value | 1 | §4 COMPONENT_COLUMNS | §5.2's retained work remainder and §5.3's fractional XP, both in milli-WU. Task 09's acceptance list names "item/XP/clock remainders" -- these are the XP ones, and dropping them loses up to 999 milli-WU per resident per skill and shifts a level-up tick. |
| Work remainders (i32) | `_xp_remainder` | 4 | `RESIDENT_CAPACITY * SKILL_COUNT` = 6144 | 0-999 each; 0 is a real value | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Mood memory total | `_memory_total` | 4 | `RESIDENT_CAPACITY` = 512 | 0 is an honest default, not absence | 1 | §4 COMPONENT_COLUMNS | REQ-SET-020's `sum(memory_values)`. The module's comment is explicit that it is NOT a second source of truth for memories because blocker U6 leaves MoodMemory's owner-major index formula unspecified and no such store exists. Task 09.1 lists "memories" as registry scope: the memory STORE is absent, and this integer is the only memory-derived state a save can carry today. |
| Party tick scratch (i32) | `_party_job`, `_party_resident`, `_party_skill`, `_party_persistent_id`, `_party_potential` | 4 | `PARTY_CAPACITY` = 512 | Refilled by `_collect_contributors()` and consumed before its caller returns | 3 | -- | The module's own header calls these "per-tick scratch (not simulation state)". |
| Party tick scratch (i64) | `_party_share`, `_party_fraction` | 8 | `PARTY_CAPACITY` = 512 | Refilled by `_collect_contributors()` and consumed before its caller returns | 3 | -- | See the first row of this group. |
| Work scalars | -- | -- | -- | -- | 3 | -- | `_party_count`, `_party_identity_count`, `_pending_leftover`, `_factor_out` and `_math`, all consumed inside one party tick. |
| Tool wear carry (i32) | `_wear_remainder` | 4 | `RESIDENT_CAPACITY` = 512 | 0-9999 each; 0 is a real value | 1 | §4 COMPONENT_COLUMNS | GDD §5.7's sub-point tool-wear carry in milli-WU. This IS architecture §3's `ResidentRuntime.wear_remainder`, which no store implements and which `gear.gd` explicitly refuses to allocate a second copy of. Decision 0110 moved it OUT of that I64 budget rather than counting it twice. Dropping it loses up to 9999 milli-WU per resident and shifts the tick a durability point falls on. |
| Tool settlement binding (i32) | `_tool_lot_slot`, `_tool_lot_generation`, `_tool_job_slot`, `_tool_job_generation` | 4 | `RESIDENT_CAPACITY` = 512 | `-1` slot with generation 0 is the null ref, meaning no binding | 1 | §4 COMPONENT_COLUMNS | SET-MOVE-ECON-001 ECON-002, decision 0110. The InventoryLot reference of the tool a resident bound for wear settlement and the Job reference holding the matching `gear.gd` claim. Both are full generation-carrying refs, NOT row indices -- `gear.gd`'s own rows stay bare indices and never escape it. Must be saved with `gear.gd`'s claim columns or a load leaves a claim in one store with no binding in the other. |
| Tool broken flag (u8) | `_tool_broken` | 1 | `RESIDENT_CAPACITY` = 512 | 0 is "not broken", a real value | 1 | §4 COMPONENT_COLUMNS | 1 once a bound tool has been worn to 0. §5.7's "Broken tools block tool-required work" as an O(1) per-tick gate; sound because `gear.gd` refuses every repair, re-owning, unequip and destroy while the claim stands. Derivable from the bound tool's durability at load if a future owner prefers. |
| Modular paid-owner callback wiring | -- | -- | -- | Null Job refs outside each synchronous tick | 3 | -- | Decision 1073: weak `_modular_authority`, exact `_pending_modular_job` and `_publishing_modular_job` (two 8-byte full Job refs). The pending bracket ensures every post-gate refusal and zero accepted work drops only its own prepared PRODUCTIVE candidate. These controls are not saved or hashed and must be clear at save/load boundaries. |

### `godot/scripts/core/world_init.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Published world map | `_terrain`, `_soil`, `_basin`, `_cleared` | 1 | `TILE_COUNT` = 16384 | Every tile has all four; `_cleared == 0` means uncleared, a real state | 1 | §1 WORLD | REQ-SET-009's authored estuary, 128x128 exterior tiles. Decision 0048 records the allocation. `_cleared` changes during play as the settlement clears ground, so this is not merely generation output. |
| Published basin references | `_basin_ref_slot`, `_basin_ref_generation`, `_basin_danger` | 4 | `BASIN_COUNT` = 7 | `-1` slot with generation 0 is the null ref | 1 | §1 WORLD | Seven ecology basins and their §5.5 danger bands; the refs point at `forage.gd` HarvestZone rows through the directory. |
| Staged world map (u8) | `_staged_terrain`, `_staged_soil`, `_staged_basin`, `_staged_cleared`, `_staged_used` | 1 | `TILE_COUNT` = 16384 | `_staged_used` marks which staging tiles a generation pass has written | 3 | -- | The second allocation that publishing SWAPS with the live map. A save is taken at a completed tick, when no generation is in flight, so the staging buffers hold a previous pass's residue. Writing them would double the map's bytes for state no future tick reads; a load leaves them as allocated. |
| Staged world map (i32) | `_staged_danger` | 4 | `BASIN_COUNT` = 7 | `_staged_used` marks which staging tiles a generation pass has written | 3 | -- | See the first row of this group. |
| Staged world map (i32) | `_staged_centres` | 4 | `TREE_CENTER_CAP` = 3000 | `_staged_used` marks which staging tiles a generation pass has written | 3 | -- | See the first row of this group. |
| Staged world map (i32) | `_staged_grove` | 4 | `GROVE_NODE_COUNT` = 100 | `_staged_used` marks which staging tiles a generation pass has written | 3 | -- | See the first row of this group. |
| Staged world map (i32) | `_staged_fish_item_ids` | 4 | `FISH_SPECIES_COUNT` = 9 | `_staged_used` marks which staging tiles a generation pass has written | 3 | -- | See the first row of this group. |
| FaunaStockReserved (i32) | `_fauna_zone_slot`, `_fauna_zone_generation`, `_fauna_species_id`, `_fauna_population`, `_fauna_capacity`, `_fauna_tracks`, `_fauna_harvest_today`, `_fauna_migration_link` | 4 | `FAUNA_STOCK_ROWS` = 384 | Every row is zero and `_fauna_zone_slot` is the null slot; there is no mutator | 1 | §4 COMPONENT_COLUMNS | REQ-SET-059's canonical EMPTY allocation: hunting is retired in rules v2 (SET-AMEND-001 §3) and nothing writes these rows. Task 09.2 must "Reject incompatible v1 hunting state under SET-AMEND-001", so a file carrying nonzero fauna rows is refused rather than loaded -- and these 384 rows' bytes must not be repurposed. |
| FaunaStockReserved (i64) | `_fauna_birth_remainder` | 8 | `FAUNA_STOCK_ROWS` = 384 | Every row is zero and `_fauna_zone_slot` is the null slot; there is no mutator | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| World publication state | -- | -- | -- | `_published == false` means no map has been generated | 1 | §1 WORLD | `_published` and `_published_seed`. The seed must agree with `rng.gd`'s `_world_seed` and with `World.seed` in §2's ledger; ARCH-SAVE-004's map-compatibility check is what makes that agreement enforceable. |
| World-generation scratch | -- | -- | -- | -- | 3 | -- | `_staged_centre_count`, `_staged_grove_count`, `_math`, `_measured`, `_foreign_kind` and `_externally_cleared_mask`, all live only inside a generation pass. The last is the caller's statement of which directory kinds its own reset clears (decision 0094): one bit per kind in a scalar, set before `preflight()` and replaced on every call, so it is configuration for a pass rather than state a pass produces. |


## 2026-09-11 follow-on ownership rulings

[SAVE-R09-001–005](rulings/2026-09-11_save_codec_contract.md) assigns proposed
owners for sections11/13/15, the section1 provenance prefix and version policy.
Those modules/fields are not asserted implemented by this registry. Their owners
must add rows and exact byte counts alongside implementation, including the
existing8-byte WorldRuntime event allocator moved to EventSchedule ownership,
without duplicate allocation/serialization. Existing generation spaces remain distinct.
STATE-COHORT-R01 corrects `_cohort_slots` above; the previous founder-history
interpretation is retained as superseded evidence in the dated ruling.


### `godot/scripts/core/starter_structures.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---|---|---|---|---|---|
| Authored refuge preparation | -- | -- | -- | Plan defaults -1; header zero | 3 | -- | INIT-C-PREP-R01v1 / decision0184. Cold derived plan, no saved authority or live owner construction. Ten caller-owned PackedInt32Array payloads total2480 logical bytes; caller plus one staged Plan bound4960, with bounded metadata/graph scratch. Success publishes validated arrays by copy-on-write assignment; refusal preserves prior output. Producer last_refusal is transient diagnostic state. Actual native overhead is not measured. Exact tile layout and candidate adjacency establish no body fit, topology publication, room validity, heat, real contacts or container admission; those remain INIT-C and related integration contracts. |

### `godot/scripts/core/starter_colony.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---|---|---|---|---|---|
| INIT-C live apply records | -- | -- | -- | Applied refs and StoreBinding owners `(-1,0)`, anchors -1 | 3 | -- | DEMO-CONTAIN-R01 D3 / decision 0533. No module-level column: the translator writes only through `buildings.gd`'s public doors, whose rows are the saved state. `Applied` (six PackedInt32Array, 7+4+31 slot/generation pairs, 336 logical bytes) and `StoreBinding` (one pantry ref and tile plus three 4-cell PackedInt32Array, 60 logical bytes) are caller-owned cold records allocated per generation or binding read, never resident between them, and never saved: the binding is re-read from the live Building rows each time. |

### `godot/scripts/core/room_projects.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Registered Construction identities and purpose | `_project_slot`, `_project_generation`, `_room_type`, `_revision_epoch` | 4 | `PROJECT_CAPACITY` = 82944 | Slot/type -1 and generation/epoch 0 on a free record | 1 | §6 AUXILIARY_STATE | Decision 1053. Construction EntityRef plus immutable protected RoomType and monotonic editing-session token; this is project control, not a completed room or physical cut ledger. Save/hash integration remains required before activation. |
| Registration and independent pause holds | `_present`, `_pause_reasons`, `_revision_state` | 1 | `PROJECT_CAPACITY` = 82944 | 0 means absent/no pause/no revision | 1 | §6 AUXILIARY_STATE | Player and revision bits are independent. Request and acknowledged release are distinct, with acknowledgement revalidated against Jobs/Reservations. An absent UI panel cannot reconstruct or discard these holds. |
| Actual Job/project identity bindings | `_job_slot`, `_job_generation`, `_job_project_slot`, `_job_project_generation` | 4 | `JOB_CAPACITY` = 8192 | Slot -1 plus generation 0 is null | 1 | §6 AUXILIARY_STATE | Each real Jobs requester must name its Construction identity. Old Job generations may remain until actual claims are resolved; no automatic alias on slot reuse. |
| Owner wiring and scratch result | -- | -- | -- | -- | 3 | -- | Construction, Jobs, Reservations and directory references; `_owners_match` is derived from wiring and `_math` is transient output. Packed payload is 1707008 bytes. No save codec or live demo integration is claimed by the local evidence image. |


### `godot/scripts/core/room_footprint.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---|---|---|---|---|---|
| Cold room-footprint geometry | -- | -- | -- | Empty result on refusal | 3 | -- | Decision 1052. Stateless integer helpers only; caller-owned packed cell/edge/loop values and temporary bounded membership scratch. No module-level mutable columns, room identity, spatial publication, material account or paid-cut state. Confirmed footprint and grid identity remain the integrating owner's persistence obligation. |
| One-call packed validation packet | -- | -- | -- | Invalid requested count allocates no packed rows; neighbor sentinel -1 | 3 | -- | Decision1094. The nested, temporary ValidationScratch object owns three exact I32 arrays (_validation_up, _validation_down, _validation_queue) and one exact byte array (_validation_flags), all sized to its source-clamped _validation_capacity, at most 16384 cells. Original invalid requests refuse before allocation. Logical payload is13N packed bytes plus one I64 capacity8; the packet dies with the synchronous validation call. These are not module-level columns or persistent geometry. Native headers and helper frames remain separately admitted controls. Existing contour/editing helpers retain their original cold contracts. |


### `godot/scripts/core/room_layout.gd`

[Decisions1054/1072](decisions/1072-joint-underground-state-and-memory.md):
bounded packed furniture drafts and project receipts, declared as mandatory
section6 state. The declaration does not implement its codec or live-world
composition. These records perform no Inventory, paid work, installation or
service mutation; accepted receipts must resolve actual live projects on load.

| Column group | Members | Width (bytes) | Count | Sentinel / default | Category | Save section | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Room binding and immutable type | `_room_slots`, `_room_generations`, `_room_types` | 4 | `_room_capacity` <= 16384 | null slot/generation `(-1, 0)`; free type 0 | 1 | §6 AUXILIARY_STATE | Full actual Room identity and immutable purpose, validated with Buildings and geometry. Decision1072 schema1 fixes explicit field order after the three capacity scalars. |
| Per-room furnishing mode | `_room_modes` | 1 | `_room_capacity` <= 16384 | 0 = Plan layout; 1 = Place individually | 1 | §6 AUXILIARY_STATE | Switching affects subsequent clicks and preserves existing drafts/orders. The preference retains its exact Room binding. |
| Placement lifecycle | `_state` | 1 | `_placement_capacity` <= 81920 | 0 = free; 1 = draft; 2 = accepted receipt | 1 | §6 AUXILIARY_STATE | Receipts grant no services and own no world occupancy. Accepted state must reconcile with the actual full Construction identity. |
| Local placement identities, room binding and geometry | `_generation`, `_room_row`, `_type`, `_x`, `_z`, `_rotation` | 4 | `_placement_capacity` <= 81920 | inactive payload 0; generation retained and never wraps; rotation 0..3 | 1 | §6 AUXILIARY_STATE | Local draft/receipt namespace, distinct from EntityDirectory. INT32_MAX free slots remain retired. Coordinates are exact room-relative integers. |
| Accepted project references | `_project_slot`, `_project_generation` | 4 | `_placement_capacity` <= 81920 | `(-1, 0)` outside accepted rows | 1 | §6 AUXILIARY_STATE | Full actual Construction identity; restore cannot turn a receipt into installed Furniture. |
| Exact configured capacities | -- | -- | -- | -- | 1 | §6 AUXILIARY_STATE | `_room_capacity`, `_placement_capacity`, `_geometry_capacity` are saved bounded constructor inputs; allocation must also fit the joint1072 pack. |
| Runtime adapters and synchronous scratch | -- | -- | -- | -- | 3 | -- | Decisions1054/1087. `_submitting` is false, no Result lease is held and provider quarantine is reconciled at every legal save boundary. One exact typed Sources provider replaces the three Callables; weak wiring and immutable definitions rebind only after all actual owners validate. Snapshot/profile/validation/result/batch objects are admitted cold inputs/scratch, never alternate authoritative world state. |
| Cold layout/result lifetime and diagnostic controls | -- | -- | -- | No token or escaped arrays outside the same input call | 3 | -- | Decision1087. One I64 operation token, one Vector2i Room and one submission-quarantine bool add17 logical numeric planner bytes; one escaped Result adds an I64 token hint and committed-outcome bool, totaling26 new logical numeric bytes across retained lifetimes. Source/snapshot/result references, weak pointers and diagnostic StringNames require separately admitted native overhead. Logical simultaneous planner packed peak is336G+64P+512; native map entries are bounded bymax(6G,2P), not a native byte qualification. Provider snapshots, companions, container headers and allocation growth are additionally charged before first read/copy. All five Result arrays including placement_rows clear before exact-token release. `release_result` and mandatory `finish_input` consume views synchronously before frame/simulation/input returns; abandoned/corrupt views are cleared and diagnosed. Late cleanup faults preserve committed outcomes and quarantine further provider commands until explicit same-world reconciliation. No new persistent columns or save codec. |

### `godot/scripts/core/excavation_contract.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable excavation operation facts and owner contract | -- | -- | -- | -- | 3 | -- | Decision 1056. ECON-001/002/005 constants and a typed abstract authority; no instance state or packed columns. The base authority refuses admission. Concrete physical state belongs to excavation_sites, not this interface. |


### `godot/scripts/core/room_catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---|---|---|---|---|---|
| Read-only room-purpose and furniture queries | -- | -- | -- | Refused query has no usable ID or palette | 3 | -- | Decision 1059. No module-level packed columns or live room/furniture/project state. One immutable BuildingDefinitions reference; caller-owned cold query records copy existing catalog footprints, bills, purpose compatibility and necessary service prerequisites. Actual room type, construction, installed services, material selections and placement profiles remain their existing owners' state and persistence obligations. |
### `godot/scripts/core/room_space.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---:|---|---|:-:|---|---|
| Cold multilevel validation | -- | -- | -- | Refusal has no candidate; owner null is `(-1,0)` | 3 | -- | Decision 1058. Stateless helper with caller-owned immutable domain, versioned packed snapshot/plan/contact records and bounded union-coverage scratch. Volume rows are 48 logical bytes, cuts 16, contact metadata 24 beyond its volume rows, live owners 16 (two int32 reference fields plus one int64 revision). No module-level persistent columns, terrain, reservations, material account, physical history or route publication. Integrating owners must serialize the domain and accepted geometry/content/owner revisions; no codec assignment is invented by this foundation. |

### `godot/scripts/core/room_connectors.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---:|---|---|:-:|---|---|
| Cold fixed-piece transforms | -- | -- | -- | Refusal has no plan; unnamed catalog defaults refuse | 3 | -- | Decision 1058. Stateless exact quarter-turn/translation over caller-owned catalog definitions and placement inputs. Output is only a RoomSpace candidate with catalog revision, actual endpoint floors and full target refs. No production catalog defaults, dynamic resizing, occupancy, installation, work, traversal or saved identity is created. Accepted connector identity/geometry and catalog version remain the eventual owning store's persistence obligation. |

### `godot/scripts/core/excavation_inventory.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Funded project identity, receipt head and reserved output | `_project_slot`, `_project_generation`, `_head`, `_output_slot`, `_output_generation` | 4 | `Construction.CONSTRUCTION_CAPACITY` = 82944 | Slot/head -1; generations 0 | 1 | §6 AUXILIARY_STATE | Decision 1056. Full Construction generation owns consumed material WIP and actual Inventory output reservation; codec/hash composition required before activation. |
| Reserved output mass | `_output_mass_g` | 8 | `Construction.CONSTRUCTION_CAPACITY` = 82944 | 0 | 1 | §6 AUXILIARY_STATE | Already reserved finite Inventory headroom, never a virtual output buffer. |
| Receipt free arena and metadata | `_free`, `_r_next`, `_r_item`, `_r_quality`, `_r_provenance`, `_r_recipe` | 4 | `_capacity` <= 32768 | Next -1; unused metadata 0 | 1 | §6 AUXILIARY_STATE | Deterministic fixed SoA receipt pool, requested capacity in 1..32768 and no larger than actual Reservations.row_capacity(); invalid requests refuse before allocation, without clamping into a usable owner. No per-input-lot truncation. Free count and capacity are saved control scalars; capacity exhaustion refuses before consumption. |
| Receipt input quantities and exact ages | `_r_quantity`, `_r_age`, `_r_remainder` | 8 | `_capacity` <= 32768 | 0 | 1 | §6 AUXILIARY_STATE | Actual consumed input metadata for cancellation; not another loose-goods ledger. |
| Declared cancellation losses by purpose | `_lost_milli` | 8 | `LOSS_CELL_CAPACITY` = 1024 | 0 | 1 | §6 AUXILIARY_STATE | Decisions 1069/1073/1102. Four historical per-item domains: excavation, spatial furniture, spoil tips, connector installation. Additional6144 persistent bytes and6144 per staged image versus the original excavation-only column. Global earth sums domains once; support reads excavation only. Loss survives project retirement and is not derivable. |
| Staged metadata | `_s_item`, `_s_quality`, `_s_provenance`, `_s_recipe` | 4 | `_capacity` <= 32768 | 0 outside populated prefix | 3 | -- | Cold transaction scratch, overwritten before read. |
| Staged quantities and ages | `_s_quantity`, `_s_age`, `_s_remainder` | 8 | `_capacity` <= 32768 | 0 outside populated prefix | 3 | -- | Captured before Inventory may retire input lots; becomes authoritative only after commit. |
| Staged item totals, returns and rounding carries | `_s_totals`, `_s_returned`, `_s_carry` | 8 | `Inventory.ITEM_CAPACITY` = 256 | 0 | 3 | -- | Cleared for each transaction; scratch count and IntResult are transient. Decision1106 reuses `_s_totals` for prepared per-item cancellation loss, so postcommit loss/WIP publication needs no new bill callback. No new vector or duplicate accounting. |
| Shared output quote | -- | -- | -- | Reset before each cold read | 3 | -- | Decision 1073. Funding holds one reusable ModularContract.Quote with 112 nested packed scratch bytes, four catalog keys and scalar/ref controls. It shares the existing single receipt arena and reads actual typed owner facts, never per-project quote objects or a second material ledger. |
| Synchronous input preparation and settlement | -- | -- | -- | Both full refs null outside the original Funding call | 3 | -- | Decision1106. `_settling_project` and `_settling_job` are two full integer references, 16 logical bytes within the existing bindings/control reserve. Project excludes recursive entry before Recipe observers; Job qualifies only the exact Inventory/Reservations transaction. The allocation-free reader exposes no permission outside that exact scope. Every return clears both refs; no save, canonical hash, packed column or paid receipt is added. |
| Bound owner references | -- | -- | -- | null | 3 | -- | Construction, Inventory, Reservations and compiled item definitions are world wiring; no production codec or live activation is claimed. |

### `godot/scripts/core/excavation_sites.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Permanent physical presence, phase and source/support flags | `_present`, `_phase`, `_installed`, `_ever_cut`, `_closure_before` | 1 | `_capacity` <= 73909 | Absent/flags 0; phase SOLID | 1 | §6 AUXILIARY_STATE | Decision 1056. Capacity is the explicit sparse physical-history budget in 1..73909, within an 8388608-byte packed arena including fixed indexes/scratch, not a room-count policy. Untouched world cells allocate no records; exhausted capacity refuses before paid work. Physical keys/history never recycle when a room/project retires. |
| Immutable physical keys | `_site_key` | 8 | `_capacity` <= 73909 | -1 | 1 | §6 AUXILIARY_STATE | Absolute quantum rank in the immutable world domain. Permanent append-only records never evict or recycle paid history. |
| Sorted physical-key index | `_ordered_key` | 8 | `_capacity` <= 73909 | -1 | 2 | §6 AUXILIARY_STATE | Derived ascending keys for binary cold admission lookup; rebuild from the authoritative populated `_site_key` prefix. |
| Sorted key record index | `_ordered_row` | 4 | `_capacity` <= 73909 | -1 | 2 | §6 AUXILIARY_STATE | Derived row index parallel to ordered keys; O(n) cold insertion, no per-tick spatial search. |
| Embedded backfill quantity | `_embedded_milli` | 8 | `_capacity` <= 73909 | 0 | 1 | §6 AUXILIARY_STATE | Actual committed earth retained under the original quantum key. |
| Retained physical work by operation | `_earned_mwu` | 8 | `_earned_capacity` <= 369545 | 0 | 1 | §6 AUXILIARY_STATE | Derived capacity is exactly the admitted history capacity times five operations, bounded before allocation. Cancellation keeps earned labor; new project funding never resets history. |
| Room, Construction, Job and output identities plus operation | `_room_slot`, `_room_generation`, `_project_slot`, `_project_generation`, `_operation`, `_job_slot`, `_job_generation`, `_output_slot`, `_output_generation`, `_promotion_tile` | 4 | `_capacity` <= 73909 | Slots/operation/tile -1; generations 0 | 1 | §6 AUXILIARY_STATE | Full generation-qualified owner links. Promotion tile denotes an actual space-owner-held output contact, never geometry clearance by itself. |
| Bound Job lookup | `_job_site` | 4 | `Jobs.JOB_CAPACITY` = 8192 | -1 | 2 | §6 AUXILIARY_STATE | Derived lookup of the authoritative full Job bindings; no raw-global-slot reinterpretation. |
| Registered worker identity and work face | `_worker_site`, `_worker_generation` | 4 | `Work.RESIDENT_CAPACITY` = 512 | Site -1; generation 0 | 1 | §6 AUXILIARY_STATE | Allocated resident rows (living population still caps at 256). One actual worker per face and four per room project, coupled to actual Jobs/Work/Gear ownership. |
| Delivery transaction totals | `_delivery_totals` | 8 | `2` = 2 | 0 | 3 | -- | Cold scratch for the maximum adopted two-line phase bill; reads all actual reservation rows and refuses extras. |
| Immutable domain and physical conservation scalars | -- | -- | -- | World null only before valid binding | 1 | §6 AUXILIARY_STATE | World identity, copied datum/minimum/size, sparse capacity/count and world volume, initial earth, virgin source, funded/completed/salvaged brace counts and committed per-material brace returns. Required UG16 codec/hash state even after all paid phase rows retire; legacy saves explicitly unsupported. |
| Owner wiring and synchronous permit | -- | -- | -- | Null permit and action -1 | 3 | -- | Construction/Inventory/Reservations/Items/Jobs/Work/Funding and weak SpatialAuthority wiring. Permits and prepared-candidate row/stage exist only during the current physical-owner call stack; decision 1069 adds `_publishing_spatial`, one logical bool byte of category-3 synchronous callback control, false outside the exact committed spatial publication and excluded from save/hash; `_earned_capacity` is a derived 8-byte scalar cache recomputed from admitted site capacity times five operations. Decision1117 adds `_starting` and `_start_poisoned`, two explicitly charged logical bool bytes for exclusive START and nested-entry refusal, both cleared at return and excluded from save/hash. Decision1120 adds `_settling` and `_settlement_poisoned`, two more explicitly charged logical bool bytes for exclusive COMMIT/CANCEL and nested terminal refusal, cleared at return and excluded from save/hash. Initialization refusal and transient math/result scratch are excluded from local state image. All collaborator bindings are revalidated on live phase/work entry. |
| Cold Room claim request and private input | -- | 4 | `2N <= 32768` | Empty outside the exact synchronous confirmation | 3 | -- | Decision1095 atomic claim increment. Nested RoomClaimInput.cells borrows the coordinator image; RoomClaimBatch._cells duplicates exactly2N I32 entries only after the actual full World lease, input bounds and scope match. N<=16384; this is8N private bytes, never another physical history ledger. |
| Cold actual Room after-facts | -- | 4 | `Buildings.ROOM_IDENTITY_FIELDS` = 6 | Dropped with the batch before cold release | 3 | -- | RoomClaimBatch._room_facts owns24 packed bytes to prove full real Room purpose/spatial kind/parent after Directory allocation. No post-identity allocation or saved column. |
| Cold claim batch wiring and controls | -- | -- | -- | No packet or publication crosses a frame or save boundary | 3 | -- | One weak current batch on Sites; coordinator holds the strong synchronous batch/Sites links. Exact request, candidate, authority, Budget/token, cached immutable Domain, monotonic physical count and prepaid replay state are transient only. The batch's existing CutMap owns one8N interval bank. Complete copy/control and sequential companion census is in1095; no new packed persistent state or epoch. |
| Cold non-flat entry claim image and concrete cursor | -- | 4 | `6B <= 98304` | Empty outside synchronous EntryPlan admission | 3 | -- | Decision1107. Distinct EntryClaimInput fixes Corridor purpose and borrows world boxes; RoomClaimBatch._boxes duplicates exactly24B private bytes after the original actual World lease and complete104B+2048 image/control admission. Its internally created EntryCutMap uses8B intervals; ordinary flat input remains unchanged. Both claim paths copy the sole attested Domain after the actual namespace/original-lease proof:92 logical private Domain bytes, temporary24 configure bounds and descriptor/scalar coexistence fit the existing2048 control allowance; no second caller observation chooses keys or precedes an unleased allocation. No new per-Site columns, history or work counters. Input/cursor references, base level and copied full source/Room identity remain transient; all packed lifetimes drop before cold release. |



### `godot/scripts/core/connector_geometry.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Reason / contract |
|---|---|---:|---|---|:-:|---|---|
| Cold fixed-content mesh and footprint compilation | -- | -- | -- | Refusal has no candidate; unnamed or incomplete content refuses | 3 | -- | Decision 1070. Stateless integer compiler over explicit caller-owned polygon parts, fixed RoomConnectors metadata and full RoomSpace contracts. Packed input is 12 bytes per top vertex, 32 per part plus 4 for the offset sentinel, and 4 per material. Triangle output is 44 bytes per triangle, plus 4 per part, 4 per material, optional 24-byte hinge and 24-byte sweep. Compiled geometry additionally holds copied 48-byte volume rows and full contact/cut metadata; each part adds one SOLID row, a hatch one ENVELOPE row. Bounds are caller-selected under 128 parts, 2048 top vertices, 8192 triangles, 16 materials and RoomSpace region ceilings; no resident arrays or module-level persistent state. The eventual accepted content/geometry owner must retain the catalog revision, never rebuild authority from a mutable display mesh. Native object/material/renderer memory is separate, unmeasured presentation overhead. |


### `godot/scripts/core/modular_project_contract.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Quote input quantities | -- | 8 | `INPUT_CAPACITY` = 4 | 0 | 3 | -- | Nested scratch `Quote.input_milli`. Decision 1069. One bounded component-owned cold quote, reset before the actual typed owner fills it. Not per-project state or a price source. |
| Quote output identifiers | -- | 4 | `OUTPUT_CAPACITY` = 2 | Item/recipe -1, other metadata 0 | 3 | -- | Nested scratch `Quote.output_item`, `output_quality`, `output_provenance`, `output_recipe`. Finite actual-owner output candidate; Inventory validates catalog/metadata before any transaction. |
| Quote output quantities and ages | -- | 8 | `OUTPUT_CAPACITY` = 2 | 0 | 3 | -- | Nested scratch `Quote.output_milli`, `output_age`, `output_remainder`. Exact caller-owned scratch with 112 packed bytes per quote, never an output buffer or an authoritative receipt arena. |
| Quote named inputs, facts and abstract owner/router methods | -- | -- | -- | null/empty outside initialized quote | 3 | -- | Four named catalog input keys, actual full subject, operation/q/work/Job-kind/count scalars and fail-closed typed methods. Construction holds one reusable quote and a weak router; neither is saved or hashed. Concrete operation owners remain responsible for immutable source quantities/type and persistence. |

### `godot/scripts/core/modular_projects.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Accepted actual Job and project identities | `_job_slot`, `_job_generation`, `_project_slot`, `_project_generation` | 4 | `JOB_CAPACITY` = 8192 | Slots -1; generations 0 | 1 | §6 AUXILIARY_STATE | Decision 1073. Full generation-qualified primary and accepted member Job/Construction bindings, keyed by actual typed Job row. Explicit accepted bindings are not derivable from nonunique/mutable requester refs. 131072 live bytes and another 131072 per actual cold image; cold uniqueness scan, O(1) primary productive lookup, bounded crew walk. UG16 must atomically validate owner/party identities; legacy capture explicitly refuses. |
| Delivery line totals | `_delivery_totals` | 8 | `DELIVERY_CAPACITY` = 4 | 0 before each cold read | 3 | -- | Actual owned claims staged against the full immutable bill; 32 scratch bytes, never authoritative delivered stock. |
| Quote and owner/callback controls | -- | -- | -- | No active permit/publication outside synchronous call | 3 | -- | One reusable nested Quote adds 112 packed scratch bytes plus names/scalars/native overhead. Actual owner references, derived World identity, weak purpose owners, initialization refusal, IntResults, crew count, admission/busy and exact mutation/publication controls are nonpersistent composition/transaction state. No extra receipt arena and no per-worker objects. Work additionally holds weak modular authority and full pending/publication Job refs as transient callback wiring. |
| Paired Furniture admission controls | -- | -- | -- | Null candidate/Room and false publication flag outside the same call | 3 | -- | Decision1089 core increment. The Router borrows one caller-admitted Directory.CreateBatch; its retained Vector2i Room and bool add9 logical numeric bytes, with no new packed columns or authoritative state. Accepted count and first full Project ref are pinned in16 helper-frame bytes before publication callbacks can discard the borrowed packet. Native handles, one command OpResult and helper frames are additionally admitted; this is not a measured native allocation claim. Quiescent save/load has no candidate/window, and the later RoomOrders/SpaceOwner packet peak is separately declared before activation. The real Directory allocates all alternating Furniture/Construction observations exactly once; only preflighted catalog rows and sealed companions may publish afterward. |


### `godot/scripts/core/underground_space_owner.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual live spatial state (8 B) | `_header` | 8 | `HEADER_FIELDS` = 18 | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Prepared image (8 B) | `_s_header` | 8 | `HEADER_FIELDS` = 18 | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Derived allocation heap (4 B) | `_region_free_heap` | 4 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 2 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Lowest-free allocator derives from canonical live lifecycle columns; counts and heaps rebuild on load. |
| Derived allocation heap (4 B) | `_source_free_heap` | 4 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 2 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Lowest-free allocator derives from canonical live lifecycle columns; counts and heaps rebuild on load. |
| Prepared image (4 B) | `_s_region_free_heap`, `_s_r_generation`, `_s_r_lo_x`, `_s_r_lo_y`, `_s_r_lo_z`, `_s_r_hi_x`, `_s_r_hi_y`, `_s_r_hi_z`, `_s_r_level`, `_s_r_section_slot`, `_s_r_section_generation`, `_s_r_owner_slot`, `_s_r_owner_generation`, `_s_r_claim_slot`, `_s_r_claim_generation` | 4 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Prepared image (4 B) | `_s_source_free_heap`, `_s_o_slot`, `_s_o_generation`, `_s_o_parent_slot`, `_s_o_parent_generation`, `_s_o_a`, `_s_o_b`, `_s_o_c`, `_s_o_d` | 4 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Actual live spatial state (1 B) | `_r_present`, `_r_retired`, `_r_role`, `_r_claim_kind` | 1 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Actual live spatial state (4 B) | `_r_generation`, `_r_lo_x`, `_r_lo_y`, `_r_lo_z`, `_r_hi_x`, `_r_hi_y`, `_r_hi_z`, `_r_level`, `_r_section_slot`, `_r_section_generation`, `_r_owner_slot`, `_r_owner_generation`, `_r_claim_slot`, `_r_claim_generation` | 4 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Actual live spatial state (8 B) | `_r_owner_revision` | 8 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Actual live spatial state (1 B) | `_o_present`, `_o_kind` | 1 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Actual live spatial state (4 B) | `_o_slot`, `_o_generation`, `_o_parent_slot`, `_o_parent_generation`, `_o_a`, `_o_b`, `_o_c`, `_o_d` | 4 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Actual live spatial state (8 B) | `_o_revision` | 8 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 1 | §1 WORLD | Decision 1064. Explicit finite constructor capacity, no adopted production default. Canonical live payload includes internal region generations, exact external owner facts, physical extents and typed Room/Construction claims. Schema 1 local round-trip; decision1072 declares its mandatory canonical owner; full save composition remains required before activation. |
| Prepared image (1 B) | `_s_r_present`, `_s_r_retired`, `_s_r_role`, `_s_r_claim_kind` | 1 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Prepared image (8 B) | `_s_r_owner_revision` | 8 | `_region_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Prepared image (1 B) | `_s_o_present`, `_s_o_kind` | 1 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Prepared image (8 B) | `_s_o_revision` | 8 | `_source_capacity` runtime | Slots -1, null generations 0; see typed schema | 3 | -- | Decision 1064. Explicit finite constructor capacity, no adopted production default. Preallocated alternate bank; only a completed transaction is saveable. Aborted preparation never replaces actual geometry or claims. |
| Owner derived configuration | -- | -- | -- | No active token at save | 2 | §1 WORLD | Decision 1064. Immutable cached Domain and capacities derive from the eighteen-I64 header. Live free counts/heaps rebuild after load. |
| Bound source and transaction control | -- | -- | -- | No active token at save | 3 | -- | Decision 1064. Bound Sources and scratch Facts rebind to actual stores. Stage/next tokens, seal flag, operation budget, changed-row count and stage free counts are transient; tokens carry no gameplay ordering or entitlement. Completed-load composition invalidates all pre-load proofs before resuming. |
| Changed-row indices | `_changed_rows` | 4 | `_region_capacity` runtime | Only the checked prefix is read | 3 | -- | Decision 1064. One preallocated row index per changed region; count resets before each transaction. Validated unchanged pairs need not be rechecked. |
| Changed-row mask | `_changed_mask` | 1 | `_region_capacity` runtime | 0 before each transaction | 3 | -- | Decision 1064. Deduplicates the finite changed index list. Decoded loads compare exact spatial columns with the already validated live image; owner/source/section validation still checks every live row. |
| Pending Furniture installation control | -- | -- | -- | Source row -1 and null bindings outside a sealed operation | 3 | -- | Decision1075. One transient source-row int8, full project ref8 and IntResult numeric9 add25 logical bytes; two weak actual Router/purpose-owner bindings and native handles remain in the explicit binding/control reservation. Only staged installed0→1 is anticipated; generic publication refuses it, exact actual COMMIT plus installed1 publishes, and abort clears controls. No new packed or wire state. |
| Future Room admission control | -- | -- | -- | Candidate reset, row/type -1, null weak bindings and callback flags false outside the operation | 3 | -- | Decision1075 and1083. One reusable Directory.CreateCandidate carries32 numeric bytes (fullref8, kind/typedrow/PID24); source-row/type controls16 plus two callback guard bools2 total50 logical bytes inside the admitted binding reservation. Three weak handles/native headers are separately within that reservation. Exact observed future Room facts and blocking floor-plan markers publish only after actual identity allocation in the same bound authority window. Callbacks cannot abort/rebegin/edit/publish the owner; a refused attestation leaves caller cleanup/retry usable. No new packed/wire state, and active candidates cannot save. |
| Private exact paired allocator tuples | `_furniture_pins` | 4 | `candidates.count * 5` runtime | Empty outside one admitted cold candidate | 3 | -- | Decision1075. Five exact I32 fields for each future Furniture and paired Construction:40N bytes. Rechecked against actual Directory before publication and actual typed after-facts afterward; never authoritative future entities. |
| Private exact fitting entries | `_furniture_entries` | 4 | never allocated | Empty outside candidate | 3 | -- | Type, exact plan X/Z and rotation duplicated only after actual RoomOrders cold admission;16N bytes. No resize(); never allocated with resize: the bounded input is duplicated. |
| Sorted future source-row index | `_furniture_rows` | 4 | `_furniture_count` runtime | Empty outside candidate | 3 | -- |4N bytes; existing row index high bit carries bounded per-seal geometry presence scratch. Every future piece requires an occupied obstacle and actual containing Room section. |
| Borrowed original fitting entries | `_furniture_input_entries` | 4 | never allocated | Empty outside candidate | 3 | -- | Never allocated: an alias to the already charged caller request, not a fourth owned copy; exact comparison with private entries detects mutation. |
| Batch binding and controls | -- | -- | -- | Count0, RoomNULL outside candidate | 3 | -- | CountI64 + full Room8 =16 logical numeric bytes; actual authority and original Directory batch are weak bindings. Three private arrays total60N and are dropped before the caller releases the exact shared cold lease. Existing reentry guards/Facts scratch reused; native references/array headers stay in the binding reserve. No packed persistent field or wire-schema change. |

### `godot/scripts/core/underground_space_authority.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Derived static proof presence | `_present` | 1 | `_capacity` runtime | 0 | 2 | §1 WORLD | Decision 1064. Explicit jointly admitted proof capacity, bounded by actual Jobs and Construction. No proof persists or hashes; load invalidates all old evidence. |
| Derived full identities and phase | `_proof_i32` | 4 | `_capacity * I32_FIELDS` runtime | 0 while absent | 2 | §1 WORLD | Eleven I32 fields per proof: full Site/Room/Construction refs, absolute XYZ, operation and physical phase. |
| Derived proof revisions | `_proof_i64` | 8 | `_capacity * I64_FIELDS` runtime | 0 while absent | 2 | §1 WORLD | Actual geometry and qualification revisions; a mismatch refuses productive work without rebuilding. |
| Derived proof allocation and search | `_ordered`, `_free` | 4 | `_capacity` runtime | -1 outside prefixes | 2 | §1 WORLD | Sorted actual site-slot lookup and lowest-free row heap. 69*P total fixed packed cache bytes including presence. |
| Prepared exact proof row | `_next_i32` | 4 | `I32_FIELDS` = 11 | 0 outside operation | 3 | -- | One finite replacement row, retained outside live proofs until attested publication. |
| Prepared exact proof revisions | `_next_i64` | 8 | `I64_FIELDS` = 2 | 0 outside operation | 3 | -- | Together with prepared I32 fields: 60 packed bytes. |
| Cold phase check target | -- | -- | -- | Empty until bounded quantum resolves | 3 | -- | One exact six-I32 target. Snapshot/Plan inputs, qualification copies and union fragments are bounded caller-owned scratch; not authoritative state. |
| Binding, candidate and cold controls | -- | -- | -- | No active candidate at save | 3 | -- | Actual source/space/physical/qualification references, weak Sites binding, cache counts, candidate tokens, booleans, refusal and math scratch. Declared separately in decision 1064; no production qualification is claimed. |

| Shared cold-operation token | -- | -- | -- | 0 outside the exact synchronous operation | 3 | -- | Decision1075. `_cold_token` adds 8 logical numeric bytes inside the existing binding/control reservation. Acquire and attest before the first ColdCheck/survey/plan allocation; retain through exact paid preparation; release only after charged original copies and companions are discarded. No packed, authoritative or wire state; actual WorldBindings must use the single decision1072 Budget instance. |

### `godot/scripts/core/inventory_spatial_contract.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Typed actual location attestation | -- | -- | -- | -- | 3 | -- | Decision 1076: fail-closed interface; actual Locations owns coordinates and support, actual Inventory owns sparse endpoint refs/transactions. No packed state or per-entity objects. |



### `godot/scripts/core/spoil_tips.gd`

Decisions1065/1072/1078. Explicit finite physical tip ledger; the actual shared
paid operation coordinator is `spoil_work.gd`. Actual ground siting and versioned
save integration remain pending.
Local row/generation handles are qualified by the bound actual World.

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Presence, retired identity and paid preparation | `_present`, `_retired`, `_prepared` | 1 | `_capacity` runtime | 0 | 1 | §6 AUXILIARY_STATE | No generation wrap; paid closure alone releases the actual tile. |
| Local identity, tile and active full Construction operation | `_generation`, `_tile`, `_project_slot`, `_project_generation`, `_operation` | 4 | `_capacity` runtime | Slots/tile/operation -1; generations 0 | 1 | §6 AUXILIARY_STATE | Actual project purpose/subject/q must agree with the exact typed operation owner. |
| Embedded source and current quantity claims | `_embedded_milli`, `_quantity_milli`, `_locked_milli`, `_incoming_milli` | 8 | `_capacity` runtime | 0 | 1 | §6 AUXILIARY_STATE | Pending source withdrawal never creates free capacity; claims cover the whole exact q. |
| Retained operation work | `_earned_mwu` | 8 | `_capacity * OP_COUNT` runtime | 0 | 1 | §6 AUXILIARY_STATE | Four separate fixed/exact-q work records per tip. Cancellation cannot erase earned labor. |
| Retained variable quantities | `_retained_quantity` | 8 | `_capacity * 2` runtime | 0 | 1 | §6 AUXILIARY_STATE | Separate COMPACT/RECLAIM q contracts; mismatches refuse. |
| Lowest-free row heap | `_free_heap` | 4 | `_capacity` runtime | Only populated prefix matters | 2 | §6 AUXILIARY_STATE | Rebuildable from present/retired; lowest-free deterministic admission and cold bijection audit. |
| Exterior tile lookup | `_tile_row` | 4 | `MAX_CAPACITY` = 16384 | -1 | 2 | §6 AUXILIARY_STATE | Reverse lookup audited against actual live tile owner; no slot-only identity permission. |
| Persistent owner header | -- | -- | -- | -- | 1 | §6 AUXILIARY_STATE | World slot/generation, configured capacity, live count and lifetime compacted/reclaimed counters. Closed generations and lifetime conservation require a versioned codec even when no tip is live. |
| Wiring, allocator control and cold scratch | -- | -- | -- | -- | 3 | -- | Exact Construction/Directory and once-bound weak Publisher, free count, initialization refusal and IntResult. Audit uses a temporary C-byte visited buffer; diagnostic image has 48+103C output bytes and peaks at 48+119C logical packed scratch while output coexists with a column conversion. Audit and image are cold and sequential. Native headers/references and composed validation/restore are separate budget obligations; independent C=16384 is not a production allocation pack. |
### `godot/scripts/core/spoil_work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Typed operation wiring and synchronous request/publication scratch | -- | -- | -- | Tip/project null; operation/action/tile -1 outside a request | 3 | -- | Decision1065. No per-tip or per-project arrays. Actual Construction/Tips/Items references, weak router/physical contacts, one nested weak-backref Publisher, one reusable integer result, cold pending subject/tile/op/q and one prepared transition identity. The actual tip ledger owns persistent physical q/work/source state; the shared router owns actual Job bindings and one Funding arena. Quotes are caller-owned reusable scratch from that router/Construction. Numeric/object/ref/native lifetimes need joint1072 admission; a missing or expired physical binding grants no work or geometry permission. |


### `godot/scripts/core/underground_budget.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Shared synchronous cold allocation admission | -- | -- | -- | Token0, used0 at quiescence | 3 | -- | Decision1072. Four numeric I64 controls (32 logical bytes) within the bindings/growth envelope. One actual World instance serializes physical phases, wire capture and generic survey scratch; every nested allocation charges its simultaneous peak before allocation. Token equality across two arenas grants no authority; bindings attest the exact arena instance. No persistent gameplay state or measured native allocation claim. |

### `godot/scripts/core/underground_locations.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Live local endpoint Bank | -- | -- | -- | Explicit full local generations; absent payload canonical | 1 | §1 WORLD | Decision1075. Nested Bank retains header I64[16], field-major i32 I32[22N], i64 I64[2N], present B8[N], retired B8[N]: 106N+128 bytes. Fields are generation, XYZ, full Room/section refs, level/role, six envelope and six support bounds; payload/proof revisions. Exact local wire schema1 is not composed UG16 activation. Nested packed columns are explicitly counted here although the current coverage regex enumerates top-level columns only. |
| Prepared local endpoint Bank | -- | -- | -- | Invisible until sealed actual publication | 3 | -- | Same 106N+128 payload, preallocated separately, no alias with live. Failed preparations and loads preserve the current bank. |
| Both banked derived allocation/order indexes | -- | -- | -- | Unused index tails -1 | 2 | §1 WORLD | Each Bank has free_rows and ordered I32[N], two banks total16N. Derived from presence/generation/retired; rebuild on load. Total packed owner228N+256. |
| Caller packets, exclusive cold lease and copied survey | -- | -- | -- | No outstanding operation at save | 3 | -- | One typed Record/Region scratch and side-effect-free weak Inventory adapter. The actual decision1072 shared Budget enforces a finite admitted simultaneous operation before copies; exact instance binding is exposed for composition and capture retains its lease until caller consumption. The provisional nested ColdLease is removed; no second token allocator is retained. One raw wire106N+128 beside banks; cold snapshot and bounded union scratch are separately charged. No per-resident objects. Route/actor/contact columns remain implementation work inside the reserved provider envelope. |
### `godot/scripts/core/underground_room_orders.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual owner wiring and one synchronous room/furniture operation | -- | -- | -- | Project/furniture/room null; action -1, token 0 and publication/cold-held false outside operation | 3 | -- | Decision1081. No packed authoritative state, Quote, receipt arena or per-entity object. Actual Construction/Buildings/SpaceOwner/CoreSources/RoomCatalog are borrowed; router, typed physical bindings and furniture purpose use exact weak links. World ref plus operation refs/action/token/publication/cold-held and one reusable IntResult total 59 logical numeric control bytes. Cold cancellation queries finite exact region handles and boxes inside the existing serialized sparse transaction only after explicit typed shared cold admission; release follows companion/sparse scratch cleanup. Native object/Variant/frame and joint cold lifetimes require admitted composition. UG16 reconstructs wiring and requires no in-flight stage. Persistent installed flags, sources, recipes, WIP and work remain exclusively in their actual owners. |
| Exact painted Room request and future identity scratch | -- | -- | -- | Empty copied cells, null future ref and reset scalar fields outside admission | 3 | -- | Decision1083. One reusable RoomPlan60 logical numeric bytes plus Directory CreateCandidate32 adds92, making151 total RoomOrders numeric controls. RoomPlan.cells is an8N-byte copied cold packet, N<=actual Domain max_cells<=16384, acquired only after typed shared cold admission. Caller request storage is counted separately by its composer. Footprint's conservative logical packed peak<=136N+60 precedes the sparse bank; up to4N native Dictionary entries, loop headers and append/reallocation growth also require actual admission and measurement. Exact row-run marker staging retains8N plus96 fixed packed bytes before owner/helper frames; the independently owned Space banks/pinned source candidate and companion lifetimes are separate. All copied packets drop before release. No authoritative column or codec is added; accepted full Room identity and exact future marker/source geometry persist only in Directory/Buildings/SpaceOwner. The base provider remains closed until actual terrain/profile/paid-cut mapping and joint budget qualify. |

### `godot/scripts/core/underground_furniture_work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
| Exact actual furniture purpose and cold pending selection | -- | -- | -- | Pending subject null and type -1 outside selection | 3 | -- | Decision1081. No packed columns or additional receipt/Quote allocation. Actual Construction plus weak shared Router and sole RoomOrders wiring, World ref, one pending full Furniture ref/type and reusable IntResult total 33 logical numeric bytes. Quotes are populated only in caller-owned existing scratch from the protected actual catalog. Pending selection is discardable request state; accepted project identity, paid progress/materials and installed presence remain their existing persistent owners. Live exact composition checks refuse foreign/expired wiring; no pointer or synchronous callback permit is saved. |

### `godot/scripts/core/underground_profiles.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual Resident physical identity scratch | `_identity` | 4 | `3` = 3 | overwritten only by successful actual reader | 3 | -- | Decision1080. One reusable exact species/stage/logical-rig read, not per-resident state. |
| Actual tool/cargo selection scratch | `_query_values` | 8 | `5` = 5 | -1 before each read | 3 | -- | Actual current item/manufacture, cargo item/recipe and Job kind. Full dynamic refs and quantities remain owned by Residents, Gear, Work and Inventory. |
| Immutable source-derived content banks | -- | -- | -- | content revision0 means absent; no default qualified content | 2 | §1 WORLD | Two nested Bank instances, each with18 I32 fields,3 I64 fields and2 byte fields per descriptor;7 I32 fields per box;32 bytes per source-bundle digest;4 I64 header fields. Field-major packed columns, never one object per descriptor. Maxima256 descriptors,3072 boxes,64 bundles yield226368 packed bytes for both banks/headers. Actual World/save must pin the full authored content digest/revision before recreating these derived banks; no save may silently load a different catalog. This slice does not yet add that owning save field or claim composed activation. |
| Borrowed owners, streamed input and bounded query controls | -- | -- | -- | no active load at save; caller outputs unchanged on refusal | 3 | -- | Exact Residents/Transforms/Inventory/Gear/HaulCarry/Work/Reservations/GroundPiles collaborators; three capacity scalars, worker-row and loading control; one Pose, Selection, IntResult; streamed header/row at most98 bytes plus SHA context, expected digest string and exact source digests. A32768-byte explicit control/native reservation includes the52 packed scratch bytes above and simultaneous bounded row/header buffers. Maximum logical banks plus reservation259136 <=262144; native reservation is not a measured allocation claim. No third full input or JSON image. Per-query binary search plus at most16 exact key variants; at most12 boxes per selection. Geometry lookup is not movement/contact authorization. |


### `godot/scripts/core/underground_terrain.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Finite immutable domain and reused clipped query boxes | `_domain_bounds`, `_tile_box`, `_clip` | 4 | `6` = 6 | Derived bounds; no persistent modification | 3 | -- | Decision1082. Three six-I32 boxes,72 bytes. Actual World/content owns immutable datum and domain; live source/paid-space composition remains WorldBindings. No tile/depth copy. |
| Authored catalog protection extents | `_depth`, `_height` | 4 | `Definitions.BUILDING_DEFINITION_COUNT` = 30 | Key-complete before binding | 3 | -- | Two immutable derived content arrays,240 bytes. Foundation exclusion depths and upper protected-site envelopes do not represent an opaque mesh or interior traversal. World save pins content revision. |
| Compiled resource keys | `_resource_ids` | 4 | `3` = 3 | Bound wood/stone/iron IDs only | 3 | -- |12 bytes resolved through verified catalog binding, never copied numeric IDs. |
| Reused Building identity packet | `_building_facts` | 4 | `4` = 4 | Cleared on refusal | 3 | -- |16 bytes for actual type/origin/rotation/state; full reference belongs to actual Directory/Buildings. |
| Reused resource observation | `_resource_facts` | 8 | `4` = 4 | Cleared on refusal | 3 | -- |32 bytes for actual tile/item/quantity/regrowth. Reads live owner every query, no persistence cache. |
| Exact owner wiring and numeric query controls | -- | -- | -- | No gameplay mutation | 3 | -- | Total packed372 bytes plus66 numeric control bytes, within existing131072-byte terrain reservation. Decision1090 adds one8-byte unsaved immutable World-source proof revision; actual live World identity is always checked, current resource/Building exclusions are never cached. Weak SpaceOwner/CoreSources avoid composition cycles. Fixed content/native handles and initialization peak remain subject to measurement.48 bytes per cold output row plus256 control bytes require exact shared Budget coverage before append; caller retains lease through consumption. No paid cuts, routes, support claims or world state are created. |

### `godot/scripts/core/underground_space_owner.gd` — bounded validation controls

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Borrowed staged-index counts | -- | -- | -- | `_validation_regions` and `_validation_sources` are -1 outside validation | 3 | -- | Decision 1075. Two numeric integers add 16 logical control bytes inside the existing bindings reserve. Existing staged free-heap arrays temporarily hold compact present-region and sorted source-row indexes while mutations are locked. Both heaps are rebuilt on every success/refusal before later editing or publication. No added packed columns, changed wire schema or extra retained image; load never normalizes invalid saved revisions. `allocation_within` and the exact borrowed ResidentLocations reader are stateless comparisons/readers. |


### `godot/scripts/core/underground_world_bindings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact intersection boxes | `_clip`, `_intersection` | 4 | `6` = 6 | Overwritten during each bounded observation | 3 | -- | Decision1085. Two six-I32 boxes total48 bytes. A nested immutable Domain copy adds24 packed bounds bytes and68 logical numeric bytes; it derives from the actual SpaceOwner, never another persistent world. |
| Reused Room identity fields | `_room_identity` | 4 | `Buildings.ROOM_IDENTITY_FIELDS` = 6 | Caller scratch never grants service or geometry | 3 | -- | Decision1088.24 logical bytes for the fixed Buildings identity reader. Separate `_identity_reading` and `_worker_reading` booleans add2, total26 retained logical bytes within the existing1072 bindings reserve. WorldBindings total becomes297 bytes. Reads validate the real World, actual registered underground Room source and reciprocal full Job/Resident identities; they allocate no new authoritative rows or saved ordinals. Reentry guards clear before return and are never persisted. Native array/reference/control overhead remains in the existing shared reservation. |
| Observation controls and actual owner wiring | -- | -- | -- | No candidate permission or gameplay mutation | 3 | -- | Two I64 counters and one boolean add17 logical control bytes. Together with nested Domain and the above arrays, the provider has157 logical persistent/reused bytes inside the existing524288-byte bindings/native-growth reservation. SpaceOwner/CoreSources are weak; World/Terrain/Budget are the actual shared objects. No new authoritative columns or wire schema. |
| Simultaneous cold observation and fragment peak | -- | -- | -- | Cleared after observation; caller retains exact lease through output use | 3 | -- | Before the first copy, the actual shared Budget must cover975488 logical bytes: sparse snapshot327680; natural rows24576; output425984; two4096-element six-I32 fragment lists196608; transient controls640. Fragment lists contain packed integer boxes, never per-entity state. Caller plans/copies and native/container growth are additional charged coexistence in the pre-existing reserved envelopes, not measured RAM. A reentrant refusal preserves the active outer output; every admitted failure clears all output columns. |
| Site-scoped phase plan coexistence | -- | -- | -- | No escaped phase output after exact lease release | 3 | -- | Decision1088. No new retained field: one synchronous actual-site Room/project pin pair and phase bounds/controls fit the existing640 compositor controls plus512 additional phase controls. Before a plan is built, the exact shared Budget covers the original1048960-byte cold ceiling; at most1013 combined plan/approach/reach rows are conservatively charged72 bytes each, making the simultaneous maximum1048936. Input shapes are checked before deriving bounds, source/claim scope comes from the real Sites-scoped Owner reader, and later Authority validation retains the existing combined-row/copy bound. Native growth is still separately obligated, not measured here. |
| Actual phase lease and scope pins | -- | -- | -- | Token0 and null refs at quiescence | 3 | -- | Decision1088 follow-through. `_phase_token` and `_phase_geometry_revision` are two I64 controls, `_phase_site`/`_phase_room`/`_phase_project` are three full two-I32 refs, and `_cold_opening` is one boolean:41 logical bytes within the existing bindings/native-growth reservation (198 total logical persistent/reused WorldBindings bytes). Exclusive opening precedes provider callbacks; exact current World-owned Budget is acquired before any phase image, scope is rechecked before copies, and cleanup releases only that token after all originals/companions are dropped. No authoritative/wire columns or gameplay permission are added. Decision1088 structural follow-through adds `_phase_operation` and `_phase_stage`, two transient I64 controls (16 logical bytes). They pin the exact borrowed phase, reset to-1 on all cleanup, and take the current retained/reused total from297 to313 bytes without new canonical/save state. |
| Actual structural dispatch guards | -- | -- | -- | No active callback at a public boundary | 3 | -- | Decision1088. Two booleans add2 logical bytes, taking current WorldBindings controls to315 bytes within the existing bindings reservation. Weak provider/Level links hold no physical authority after expiration. Natural structure, staging and sealed-future observations retain exact original phase scope; no full work qualification or save ordinal is introduced. |

### `godot/scripts/core/underground_locations.gd` — actual route-retention observer

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Weak typed retention and callback controls | -- | -- | -- | Callback booleans false outside synchronous observation; no observer by default | 3 | -- | Decision 1075. One weak actual graph observer plus `_in_retention` and `_retention_reentered` (2 logical numeric bytes) inside the existing bindings/control reserve. Once attached, an expired or foreign observer refuses retirement. Final actual Inventory, geometry and exact shared-lease checks follow all observer callbacks. No packed/canonical/wire change; restore must rebind the real graph owner. `allocation_within` is a stateless exact-capacity reader. |


### `godot/scripts/core/transforms.gd` — runtime cache freshness

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Runtime mutation revision | -- | -- | -- | Positive until permanent exhaustion poison; public0 refuses cached observations | 3 | -- | Decision1075. One8-byte integer inside the bindings/control reserve, not a packed/canonical/saved field. All successful actual pose writes and reset invalidate, including same-value mutations; refusals preserve. Explicit future in-place restore invalidation is provided; current owner15 only validates inactive columns. Saturation never prevents a whole owner reset or recycles an old token. Routes' separate expected8-byte token is charged inside its own fixed controls. |


### `godot/scripts/core/underground_level_catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable engineering level configuration | `_config` | 4 | `CONFIG_FIELDS` = 13 | Empty before exact source validation | 2 | §1 WORLD | Decision1080. Source datum/minimum/extent, spacing, clear height, protected roof band and required local footing. Recreated only from the World-pinned content digest/revision; creates no terrain, void, support or route. |
| Authored local section menu | `_offsets` | 4 | `offsets.size()` runtime | Empty before exact source validation | 2 | §1 WORLD | Full candidate length is validated in1..MAX_OFFSETS=9 before allocation/copy; exact whole-quantum signed offsets, strict order including zero. No implicit rounding or clipping. |
| Authored fixed short-rise menu | `_short_rises` | 4 | `rises.size()` runtime | Empty before exact source validation | 2 | §1 WORLD | Full candidate length is validated in1..MAX_SHORT_RISES=8 before allocation/copy; matching height is not connector eligibility or movement permission. |
| Full immutable World/domain binding | `_identity` | 4 | `IDENTITY_FIELDS` = 21 | Empty before exact actual binding | 2 | §1 WORLD | Full World generation, datum/minimum/size, six bounds, three actual finite capacities and RoomSpace format version. Exact borrowed Directory identity and live World generation additionally gate every lookup. |
| Exact source digest | `_digest` | 1 | `32` = 32 | Empty before exact source validation | 2 | §1 WORLD | SHA256 of the very same small wire bytes decoded; content revision is one additional logical8-byte scalar. Actual World/save must pin digest/revision; composed codec remains pending. |
| Bound source, cold decoding and caller records | -- | -- | -- | Unbound before load/domain checks | 3 | -- | Max retained236 packed bytes+8 revision bytes. An explicit2048-byte loading/control/native allowance includes simultaneous wire<=156, typed decode<=120, local hash32, immutable copy<=152, descriptor/identity scratch and object/control overhead; this is admission, not measured native memory. Total2292 joins Profiles259136 inside the unchanged262144 ceiling (261428 combined). Caller Record has10 int64 fields, one Vector2i and one bool (89 logical bytes), charged by its consuming owner. No per-level objects or retained second image. |

### `godot/scripts/core/underground_room_orders.gd` — synchronous furniture layout admission

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual shared input scope and paired request scratch | -- | -- | -- | Token0, no retained snapshot/receipt/candidate at quiescence | 3 | -- | Decision1089. No authoritative columns. Four I64 scope controls32 plus callback bool1; nested cold packet count8, two Batch scalar headers80, Directory packet controls16 and receipt bool1 total138 numeric bytes. The caller admits120N+76 packed Directory/entry/pin bytes before construction, plus SpaceOwner's declared60N+16 bridge, giving180N+230 known packed/control bytes alongside existing RoomLayout336G+64P+512. Receipt8N is already within planner64P. Five private tuple arrays pin complete2N identity observations; two extra entry arrays pin copied16N input each. One actual Budget/Bindings/snapshot and one receipt are strongly retained only for synchronous cleanup; native references/headers/frame/growth need additional joint admission. Provider callbacks never substitute a remembered held flag for direct exact Budget.covers. Only one snapshot and one accepted receipt may coexist per scope; no frame/input/simulation/save crosses the lease. |

### `godot/scripts/core/underground_layout_sources.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Typed actual coordinator wiring | -- | -- | -- | No active strong coordinator outside one synchronous input operation | 3 | -- | Decision1089. No packed/numeric gameplay state or allocation arena. One weak permanent RoomOrders reference and one temporary strong reference delegate only to the actual configured Room authority, exact shared Budget and real Directory-backed identity readers. RefCounted/native header costs remain in the admitted provider allowance. All accepted state stays in Buildings, Construction, SpaceOwner and RoomLayout; UG16 reconstructs these nonpersistent links at quiescence. |

### `godot/scripts/core/underground_routes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual directed spans | -- | -- | -- | Full local generations; absent span payload canonical | 1 | §1 WORLD | Decision1075 implementation in progress. Nested live EdgeBank fields I32[14E], longs I64[3E], present/retired B8[E] each and XYZ vertices I32[3V]. Section identity, endpoints, authored connector mode/content and exact polyline are actual retained graph state; derived free/order I32[E] each. One separately preallocated stage bank. No composed save activation is asserted until actual graph/motion load validation lands. |
| Actual actor and pooled route state | -- | -- | -- | Full Resident/Location/edge/Job refs; absent rows have explicit sentinels | 1 | §1 WORLD | Nested MotionBank has resident I32[27S], resident_long I64[6S], links I32[4L], plus derived I32[L] free heap. One live bank and one inactive load bank. S512 is the actual typed capacity with at most256 living residents. Room/section/level is committed containment, not endpoint height inference. The existing I64 remainder uses a canonical reduced positive31-bit numerator/denominator encoding; exact elapsed time crosses qualified spans without banking blocked time. No per-resident objects. |
| Dijkstra distance | `_distance` | 8 | `_location_capacity` runtime | INT64_MAX until reached | 3 | -- | One bounded cold query; no flat heuristic. |
| Dijkstra indexes | `_predecessor`, `_heap_node`, `_heap_position` | 4 | `_location_capacity` runtime | -1 before lookup | 3 | -- | One finite exact edge predecessor and paired heap indexes per Location. |
| Dijkstra status | `_search_state` | 1 | `_location_capacity` runtime | 0 unvisited | 3 | -- | Exact query-local undiscovered/queued/settled state. |
| Proposed full edge refs | `_proposed_edges` | 4 | `2 * _location_capacity` runtime | Valid prefix only | 3 | -- | One shared reverse route result; a candidate grants no resident movement permission. |
| Occupancy bucket heads | `_occupancy_heads` | 4 | `_location_capacity` runtime | -1 empty | 2 | §1 WORLD | Derived exact actor broadphase; rebuilt from actual identity/pose/content truth. |
| Occupancy actor indexes | `_occupancy_next`, `_occupancy_visit` | 4 | `RESIDENT_CAPACITY` = 512 | -1 empty or zero epoch | 2 | §1 WORLD | At most256 living actors; typed capacity remains512. |
| Occupancy cell coordinates | `_occupancy_cell` | 4 | `3 * RESIDENT_CAPACITY` = 1536 | Canonical unused zero | 2 | §1 WORLD | Exact hash-cell XYZ derived from current actor roots; no physical permission. |
| Occupancy complete envelopes | `_occupancy_bounds` | 4 | `6 * RESIDENT_CAPACITY` = 3072 | Canonical unused zero | 2 | §1 WORLD | Whole body/held-load bounds; stale occupant is never omitted as empty. |
| Occupancy profile revision | `_occupancy_profile` | 8 | `RESIDENT_CAPACITY` = 512 | 0 absent | 2 | §1 WORLD | Must match actual admitted content; productive contacts cannot rebuild static geometry. |
| Catalog-wide broadphase extent | `_catalog_extent` | 4 | `6` = 6 | Refuses absent/stale content | 2 | §1 WORLD | Derived union of all admitted body/held-load and turn/recovery boxes; no movement permission. Fixed packet bytes are included in the 2112-byte control/query ceiling. |
| Candidate complete body scratch | `_candidate_bounds` | 4 | `6` = 6 | Overwritten only after complete profile checks | 3 | -- | Fixed translated envelope scratch, included in the 2112-byte control/query ceiling. |
| Occupant box scratch | `_occupant_bounds` | 4 | `6` = 6 | Private translated body/recovery box | 3 | -- | Reused exact per-box overlap scratch keeps nested provider occupancy reads separate from the moving actor's pending bounds; included in the2112-byte fixed query/control ceiling. |
| Companion controls and fixed query packets | -- | -- | -- | No outstanding graph candidate/query at save | 3 | -- | Exact weak collaborator/retention bindings prevent a CoreSources cycle. One reused I32[3V] full edge packet also serves compaction; no third graph image. Fixed numeric/query reservation2112 and all live/stage/load/index buffers plus reviewed Locations total1041728 at N1024/E1536/V4096/L4096/S512, leaving6848 within the existing1MiB reservation. Exact fixed logical census2068, including the8-byte Locations publication receipt, fits the2112-byte ceiling. Actual save and production movement composition remain in progress. |

### `godot/scripts/core/underground_room_orders.gd` — authored section metadata

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Section envelope and shared exact claim handle | -- | -- | -- | No extra owner field or retained packet | 3 | -- | Decision1091. One existing FLOOR_DATUM row plus R unchanged fine CLAIM_ROOM rows replaces2R newly confirmed rows; no persistent schema/capacity change or migration of older section handles. Enclosing metadata grants no area/support/void. Sequential floor/claim boxes peak24 packed bytes within the existing48-byte allowance. The changed cold helper chain has128 logical numeric bytes including the retained16-byte section Result and complete transform arguments/endpoints; unchanged frames/native headers remain in the existing joint helper/growth allowance. No per-Site map or hot-path allocation. |

Decision1075 prepared observation readers add no fields to
`underground_space_owner.gd` or `underground_routes.gd`. Exact sealed metadata is
copied into existing caller-owned fixed scratch without a new image or index.
The consumer still holds the previously charged shared cold lease and must run
full source/claim preflight before and after the whole observation batch; the
readers introduce no new authoritative, derived or transient retained state.

### `godot/scripts/core/underground_connector_catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact content digest scratch | `_hash` | 1 | `32` = 32 | Empty before full arena admission | 3 | -- | Decision1080. One reused caller-shaped digest reader, included in the fixed2048-byte control/decode reservation. No per-actor allocation. |
| Immutable source-derived connector content banks | -- | -- | -- | Revision0 means absent; no geometry or pace defaults | 2 | §1 WORLD | Two nested Bank instances. Each has26 I32+1 I64 per16 variants;4 I32 per512 path points;8 I32 per1024 regions;9 I32 per256 parts;3 I32 per2048 vertices;1 I32 per16 materials;7 I32+1 I64 per256 paces;11 I64 header fields and96 digest bytes. Exactly86008 bytes per bank,172016 together. The actual World/save must pin catalog, profile and level content digests/revisions; no mutable source image or catalog alone is installed geometry. |
| Actual owner bindings, bounded stream and reader controls | -- | -- | -- | No load in progress at save; every refused read preserves caller output | 3 | -- | Exact Profiles/Levels/Movement/Residents/Transforms composition; configure/load flags, one Descriptor, one IntResult,32-byte digest scratch, one112-byte maximum wire row plus the64-byte enclosing source header and SHA context, bounded caller Record/row output and scalar loop controls. Fixed2048 plus native16384 reservation joins172016 bank bytes for190448 total inside the existing bindings524288 arena, separately from Profiles/Levels262144. Native reservation is unmeasured. At most16 variants,16 exact opening targets per variant and256 pace rows; no third bank/full wire/JSON image. Actual installed connector refs, placement transform, opening target refs, paid publication and eligibility remain with their owning World components. |

### `godot/scripts/core/underground_room_bindings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Fixed paid cube and exact claim intersection | `_cube`, `_clip` | 4 | `6` = 6 | Empty until exact owner composition binds; overwritten per synchronous query | 3 | -- | Decision1092.48 packed bytes, no authoritative coordinates or duplicate Site/Room map. Actual Sites owns the immutable quantum and SpaceOwner owns every exact claim. |
| Reused actual Region, callbacks and cold outputs | -- | -- | -- | No active query at save/input/frame boundary | 3 | -- | Decision1092. One reusable Region adds24 packed box bytes and48 numeric metadata bytes; `_remaining`8 and `_reading`1 give129 total logical persistent/reused bytes. Two weak actual owner links, one borrowed actual Budget reference and native headers remain inside the shared bindings/native reservation. The exact World phase lease precedes descriptor/domain scratch and the8R handle image plus one exactly sized24F caller mask;512 cold control bytes cover sequential helper/numeric/descriptor scratch, with native/growth overhead additionally admitted. No authoritative schema, save ordinal, new arena or worker cache is added. Caller clears the synchronous output before the actual phase owner releases its lease. |

### `godot/scripts/core/underground_world_routes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused whole-profile and contact bounds | `_bounds`, `_support`, `_scratch` | 4 | `6` = 6 | Overwritten during one guarded query | 3 | -- | Decision1090 implementation in progress. Three fixed six-I32 boxes,72 bytes, within the4096-byte fixed packet/control reservation. No authoritative geometry or resident state. |
| Reused immutable path endpoint triples | `_first_point`, `_last_point` | 4 | `3` = 3 | Overwritten by exact full-edge observation | 3 | -- |24 packed bytes, also within the4096-byte fixed reservation. |
| Derived live and private route certificates | -- | -- | -- | Generation0 has no eligibility; masks never saved | 2 | §1 WORLD | Two nested Certificates banks, each with49152 mask B8,1536 generation I32 and two1536 revision I64 arrays:79872 per bank,159744 combined. Actual graph generation, geometry/content revisions, exact catalog revision and actual profile identity remain mandatory. Changed catalog content invalidates every old mask. Same-stack actual graph success alone promotes its private companion. |
| Borrowed actual World composition and fixed query packets | -- | -- | -- | No active preparation or retained cold proof at quiescence | 3 | -- | Weak graph/Owner/CoreSources/Locations prevent cycles; actual Profiles/Catalog/Levels/Movement/Residents/Transforms/World/Terrain/Budget remain shared. One Domain copy, Descriptor, two Boxes, Location, Region, metadata-only Edge, IntResult and numeric/boolean guards plus the96 direct packed bytes are within4096 reservation. Total163840 joins Catalog190448 within the existing524288 bindings/native-growth reserve. Full native and aggregate runtime qualification remain open. |
| Leased exact continuous-coverage proof | -- | -- | -- | Dropped before physical/route publication and exact cold-lease release | 3 | -- | One actual traversal Snapshot327680 plus two flat1024-fragment six-I32 banks49152 and1024 fixed scratch/control bytes:377856. No per-entity objects or third image. With actual Authority original snapshot425984 and two72x1013 phase plans145872, known logical coexistence949712 fits the unchanged1048960 cold ceiling. It cannot coexist with the975488-byte terrain compositor. Underlying actual owners retain their own bounded preflights; the adapter charges source-row passes and every local union/fragment scan. Exact masks supply ground passage only; installed fixed connector proof remains a separate required dependency. |

### `godot/scripts/core/underground_space_owner.gd` — exact publication receipt

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Successful local publication token | -- | -- | -- | Zero before the first publication and after successful restore | 3 | -- | Decision1075. `_last_published_token` adds 8 logical numeric bytes inside the existing shared bindings/control reserve. Only the actual completed bank swap changes it across all four publication paths. Abort/refusal preserve the previous token. It is unsaved and noncanonical; no packed/wire field or image grows. Exact owner identity and all physical/source/lease checks remain mandatory. |

### `godot/scripts/core/underground_locations.gd` — exact publication receipt

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Successful local publication token | -- | -- | -- | Zero before the first publication and after successful restore | 3 | -- | Decision1075. `_last_published_token` adds 8 logical numeric bytes inside the existing 2,112-byte whole-topology fixed-control ceiling, changing its actual census 2,060→2,068. Combined Locations/Routes reservation remains 1,041,728 with 6,848 unallocated bytes inside1MiB; the receipt is included once. Only actual bank swap publishes it, failed operations preserve, successful restore clears. Existing packed banks and wire format remain unchanged. Routes compares exact Space/Location receipts before and after provider callbacks; future Locations requires exact Space receipt plus its real Sites publication window. No extra Route state or multi-owner atomicity permission is introduced. |


### `godot/scripts/core/underground_world_bindings.gd` — exact room-provider composition

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact floor metadata and reciprocal query guard | -- | -- | -- | No active query at input/frame/save boundary | 3 | -- | Decision1088. One reused Region has24 packed box bytes and48 numeric metadata bytes; `_room_reading` adds1, for73 additional logical retained bytes and271 total WorldBindings retained/reused bytes. One once-bound weak RoomOrders link prevents a cycle. The exact configured composer, actual owners and arena must match; full phase scope is checked before and after callbacks. The output mask is caller-owned within the existing shared cold lease, with no second copy or concurrent compositor. Native weak-ref/Region headers and callback frames remain in1072's existing bindings/growth reservation. No authoritative state or wire ordinal is introduced. |


### `godot/scripts/core/underground_space_authority.gd` — exact FINISH partition scratch

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Cold exact mask, full handles and residual banks | -- | -- | -- | Synchronous FinishPartition exists only inside the already-held phase lease | 3 | -- | Decision1075 FINISH appendix. Four variable packed buffers: mask at most24R bytes, actual region handles8R, and two fixed flat residual banks48R. Actual `Owner.region_capacity()` supplies R before allocation; no per-fragment object or array. Provider handles and copied qualification arguments have already dropped; this packet drops before physical/companion plan copies. No persistent/wire/canonical columns. |
| Fixed partition packet and helper controls | -- | -- | -- | No retained packet or unsaved gameplay state after the call | 3 | -- | Three six-I32 scratch boxes plus two Region boxes120 packed bytes, Region metadata96 logical bytes, three integer counters24 and one boolean =241 known logical bytes inside512 controls. Simultaneous original snapshot48K+16O, original plan72P, variable buffers80R and512 controls peak at990952 for R6144/O2048/K8192/P1013, sequential within unchanged1048960 shared cold arena. Native object/packed headers and growth remain separately obligated in existing bindings reserve; no measured-RAM claim. Productive WORK allocates none of these buffers. |


### `godot/scripts/core/underground_space_owner.gd` — actual Room identity scratch

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact actual Room facts | -- | -- | -- | Scratch is initialized once and never grants source permission | 3 | -- | Decision1093. Nested CoreSources `_room_identity` is one six-I32 packet, 24 bytes, inside the unchanged shared bindings reservation. The actual Buildings helper reads full generation, purpose, spatial kind, parent and surface TileLinks without allocating OpResult. Public source output is still cleared before refusal; underground b/c stay zero. No authoritative column, canonical ordinal or wire field changes; source lookup remains bounded linear. |


### `godot/scripts/core/underground_room_bindings.gd` — actual Room admission preflight

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Authored Level record and exact admission token | -- | -- | -- | No active synchronous Room preflight at save/frame/input boundary | 3 | -- | Decision1092. One reused LevelCatalog.Record contains full World8 plus ten I64 values80 and bool1 =89 logical bytes; `_room_token` adds8, for97 added retained/reused bytes and226 total RoomBindings logical bytes with existing129 mask scratch. Two weak coordinator/catalog links, native headers and borrowed actual owner references remain in1072's shared bindings/growth reservation. No authoritative state or saved pointer. |
| Private exact admission plan and sequential packed/retained-image lifetime | -- | -- | -- | `_room_pin` and `_room_request` null after every return | 3 | -- | Decisions1092/1094. Cold-only RoomPlan metadata60 plus8N cells per image; charge24N for incoming and both possible protected copies before allocation. Decision1095 adds one8N derived interval bank; sequential logical peak is max(327680+8N,13N+8)+24N+2048, at most854016 bytes for the unchanged16384-cell ceiling. One unfiltered actual Owner snapshot replaces the redundant natural/composed image only for virgin admission; actual Terrain still checks every exact paid run and authored band in bounded windows. Existing six-I32 Region scratch is reused, with no member/state delta. Exact source, owner, input and World token checks bracket callbacks; all private copies drop before release. Native headers/growth remain in the joint reservation. The prior477-cell engineering limit is removed; actual entry/contact/support and retained-history companions remain required for production. |

### `godot/scripts/core/underground_room_orders.gd` — exact Room cold handshake

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
| Original request, exact Budget identity and retained cold token | -- | -- | -- | `_room_request` and `_room_budget` null; `_room_cold_token`0 outside the synchronous admission | 3 | -- | Decision1092. One added I64 token8 logical bytes; original request and actual Budget are strong references only inside the exclusive call/cleanup scope. Existing candidate/plan scratch is reused and clears before provider release. Successful provider return alone grants no permission: actual Budget.covers and the original token are required before copies, callbacks and Directory publication. Combined with concrete provider additions, total retained/reused logical delta105 bytes, no packed/canonical/wire schema change. |

### `godot/scripts/core/underground_phase_structure.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact geometry packets | `_cube`, `_column`, `_band`, `_piece`, `_cut`, `_overlap` | 4 | `6` = 6 | Empty until exact actual binding; overwritten during guarded cold operations | 3 | -- | Decision1093. Six boxes144 bytes plus three nested Region boxes72, included once in the fixed packet below. Actual claims, paid Site origins and immutable Levels derive every bound; these packets grant no caller-authored geometry permission. |
| Cold live handles | `_handles` | 4 | never allocated | Empty outside one held exact World phase lease | 3 | -- | No local resize; actual Owner fills the isolated handle image by append, at most8R charged bytes. |
| Exact remainder banks | `_front`, `_back` | 4 | `_capacity * 6` runtime | Empty outside one held exact World phase lease | 3 | -- | Two flat banks48R exist only during staged BRACE completion. No per-fragment object or worker allocation. CHECK omits banks, PREPARED uses one isolated48R+16O future snapshot after the original survey drops. |
| Actual provider wiring and fixed cold controls | -- | -- | -- | No active query or retained candidate image at save/input boundary | 3 | -- | Weak actual Scope/Space/Terrain/Sites wiring with strong synchronous borrows. Exact fixed retained/reused census772: Domain92, six boxes144, three Regions216, two Level records178, IntResult9, thirteen I64 controls104, five booleans5 and three full refs24. This packet, future Snapshot scalar controls24, actual Scope's temporary Level descriptor/identity packet and bounded simultaneous helper frames fit1536 logical controls; Scope's retained102 is separately counted in the existing binding reserve. No authoritative columns or new arena. At R6144/O2048/K8192/P1013 complete simultaneous logical peaks are CHECK1048528, STAGE917456 and PREPARED524240 within1048960. Exact shared-token admission precedes allocating callbacks; caller aliases or overlapping lifetimes need their own admission. Native headers/growth remain separately obligated and unmeasured. Natural protections live as actual Room-owned Space SUPPORT rows, not a duplicate provider state store or salvage entitlement. |


### `godot/scripts/core/underground_world_structure_scope.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable actual Domain and scope controls | -- | -- | -- | Weak World reference; no active read at public boundary | 3 | -- | Decision1088. Nested Domain92 logical bytes (24 packed bounds and68 numeric controls), Level revision8 and two booleans2 total102 within the existing shared bindings reservation. No own authoritative or packed columns. Level/Budget references are shared actual owners; transient descriptor/identity callback scratch is included in1093's1536 control envelope. No canonical/save state, physical geometry or worker qualification. |


### `godot/scripts/core/underground_room_cut_map.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Borrowed protected plan image | `_cells` | 4 | never allocated | Empty before configure and after clear | 3 | -- | Decision1095. Borrowed canonical fine cells from the caller's already charged private plan image; never written by the cursor. No extra cell copy or saved state. The entire cursor lifetime stays inside the same synchronous admitted operation. |
| Active-prefix interval heap | `_intervals` | 8 | `_capacity` runtime | Empty before complete preflight and after clear | 3 | -- | One exactly N-row I64 bank, N<=RoomFootprint.MAX_OPERATION_CELLS16384. Signed-safe normalized X endpoints are sorted and unioned in place. No per-quantum output, history, coordinate list, other packed bank, or saved state. |
| Derived cursor controls and borrowed input identity | -- | -- | -- | No escaped cursor at frame/input/save boundary | 3 | -- | Sixteen I64 controls128, five Vector3i observations60 and two booleans2 total190 logical numeric bytes, cold only inside RoomBindings' existing2048 logical helper reservation. Existing real Sites retains every physical history key; the new read-only remaining_history_capacity exposes no permission. Full source-counted scalar/native ledger is recorded in1095. Native packed/object headers, descriptor Dictionary and synchronous frames remain in1072's separate shared bindings/growth obligation. |


### `godot/scripts/core/underground_locations.gd` — exact Room-confirmation endpoint companion

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Future actual Room scope and refresh-only mode | -- | -- | -- | No Room candidate or companion remains at save/frame/input boundary | 3 | -- | Decision1096. Full Room8, type8 and boolean1 add17 logical numeric bytes; actual whole-topology census2068→2085 remains within2112, so total Locations/Routes reservation stays1041728. The once-bound Orders link is weak; synchronous methods borrow the actual coordinator strongly. No packed bank, allocator, wire or canonical column changes. Original actual Budget, sealed Space token, unchanged RoomPlan, exact Orders publication window and successful Space receipt remain mandatory. Only existing immutable endpoints refresh; no first entrance is created. |
| Sequential endpoint proof during Room admission | -- | -- | -- | Snapshot dropped by seal; fragment lists drop when each proof returns | 3 | -- | Room path enforces actual R≤6144/O≤2048/K≤8192 before callbacks/copies. One snapshot48R+16O, fragments24K, packet384, existing Room copies24N and controls2048 peak at919936 for N16384 within1048960 shared cold bytes. Prior admission surveys, later route surveys and future Sites cursor scratch must not overlap this peak. Later prepared/publication checks use current scalar/packed facts without another survey. Native headers and bounded callback frames remain in the unchanged bindings/growth reserve; native qualification is still open. |


### `godot/scripts/core/underground_routes.gd` — cold profile-filtered path query

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Private immutable profile/path observation | -- | -- | -- | Call-local ProfilePath drops before the synchronous query returns | 3 | -- | Decision1098. Descriptor23I64=184 plus two full endpoint pairs16 and four integer pins32 gives232 logical bytes; Result adds24 numeric bytes. Enforced512-byte cold allowance covers the packet and bounded helper controls before allocation and after callbacks, within an invoking Room's existing2048 controls. Exact actual Catalog/Bindings/Owner/Profiles/Locations/CoreSources are borrowed strongly for the call; native headers remain in existing bindings/growth allowance. No new retained field, SoA, canonical/wire state, graph bank or path scratch. Existing Dijkstra arrays are reused exclusively. Caller output storage is separately admitted and never resized. |
### Underground Profiles planar contact amendment (decision1080)

`underground_profiles.gd` additionally admits CONTACT_PATCH role6 in the existing
seven-int immutable box record. Contact kind2 requires exactly one planar patch
and one contained coplanar anchor; kind1 remains the legacy anchor-only contract.
The schema adds no packed columns, retained control fields, banks, wire bytes or
capacity. The cold role/shape/anchor validator's additional nested scalar locals
are bounded by128 logical bytes within the existing32768-byte control/native
reservation (reserved, not measured). Source digest/content revision obligations
and the Profiles+Level arena ceiling are unchanged. Contact metadata is excluded
from body/turn broadphase; actual face consumers must separately validate its
complete translated patch. This registry entry records storage semantics only,
not source geometry or gameplay qualification.


### `godot/scripts/core/underground_final_facts.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Stateless final actual-source and endpoint attestation | -- | -- | -- | No instance, retained field, array, epoch or saved state | 3 | -- | Decision1100. Static helpers borrow actual Space/CoreSources/Routes/Locations and reuse existing Facts/Pose scratch. Final nonresident facts use the exact CoreSources leaf schemas; Resident containment reads committed packed actor/endpoint/span data without observation hooks. Two capacity scans and each actual leaf have explicit precharged work. A256-byte logical helper-frame ceiling is inside the invoking1099 existing2048 controls; native getter result/reference headers remain in the existing bindings/growth obligation. No new snapshot, buffer or canonical/save field. |

### `godot/scripts/core/underground_work_face.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Guarded synchronous observation | -- | -- | -- | No read active at save/frame/input boundary | 3 | -- | Decision1099. Two boolean guards add2 logical retained bytes within the existing bindings reserve. No authoritative columns, per-worker object, saved state, Room/Site claim or productive permission. Actual owners and original request are borrowed strongly only for this synchronous read. |
| Leased exact work-face packet | -- | -- | -- | All private geometry drops before the original actual Budget lease is returned | 3 | -- | One traversal Snapshot327680 plus two1024-fragment banks49152 and2048 logical numeric/control bytes total378880. With existing Room copies24N atN16384 the sequential peak is772096 within1048960. Private input68, query scalars31, Domain92, Descriptor184, two Boxes64, two Locations232, Region72, four six-I32 boxes96, Clearance scratch/control120 and Snapshot controls24 total983 fixed logical bytes. The original caller Request adds68, leaving997 of the2048 allowance for bounded simultaneous helper numeric frames. Actual owner references, native headers, packed capacity and stack/native growth remain separately obligated in the unchanged shared bindings reserve; no measured-runtime qualification is asserted. |


### Underground Terrain final local observation (decision1099)

The callback-free `local_facts_refusal` borrows the same exact World/Nodes/Items/
Buildings/Space/Source/Budget owners and reuses all existing boxes/facts columns.
It adds no packed storage or persistent control fields. Its bounded scalar helper
frames remain within the shared WorkFace control envelope when called there.
`LOCAL_QUERY_CHECKS=1025` charges up to64 tile reads at16 tile/leaf checks each
plus one finite-query guard; the caller pays that budget before local work. The
query checks actual current local protections after observation callbacks; it
does not mint physical-space or work permission, or initialize a missing binding.

### `godot/scripts/core/underground_connector_recipes.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable source revisions and row count | `_header` | 8 | `4` = 4 | Zero until a complete successful source load | 2 | §1 WORLD | Decision1102. Recipe, connector-catalog and frontier revisions plus loaded part count. One immutable source bank, not per-placement accounting. Actual save composition must pin exact immutable content sources before any connector installation can activate. |
| Immutable exact source hashes | `_digests` | 1 | `96` = 96 | Zero before successful publication | 2 | §1 WORLD | Recipe, actual connector-catalog and authored frontier SHA256 values. Hashes do not themselves qualify frontier geometry or contacts. |
| Exact part IDs and bill counts | `_part_id`, `_input_count` | 4 | `_capacity` <= 256 | Part -1, count0 | 2 | §1 WORLD | Unique sorted ordinals owned by one exact actual connector variant. No missing row fallback or active price data. |
| Fixed construction material key indices | `_input_key` | 4 | `_input_capacity` runtime | -1 | 2 | §1 WORLD | Four lines per part resolve the existing six Construction material names through the actual Items/Inventory composition on every read. |
| Exact authored installation work | `_work_mwu` | 8 | `_capacity` <= 256 | 0 | 2 | §1 WORLD | Positive integer milli-WU, never excavation BRACE work or timed demo progress. |
| Exact authored quantities | `_quantity` | 8 | `_input_capacity` runtime | 0 | 2 | §1 WORLD | Positive integer milli-U; checked mass/refund overflow and duplicate-key refusal. One64P+128-byte immutable bank; no loader bank or full file image. |
| Reused exact source digest | `_hash` | 1 | `32` = 32 | Empty before explicit configuration admission | 3 | -- |32 packed scratch bytes within the512-byte logical control/decode envelope. Exact fixed header/row streaming and native SHA/RefCounted/StringName overhead are additional unmeasured native obligations; no measured-runtime claim. |
| Reused actual part facts | `_part` | 4 | `9` = 9 | Empty before explicit configuration admission | 3 | -- |36 packed scratch bytes within the same512-byte envelope; neither query allocates another part bank. |
| Actual source bindings and bounded read controls | -- | -- | -- | No active load/read at frame or save boundary | 3 | -- | Actual Catalog/Items/Inventory references; capacity/key-count, exact variant ordinal/revision, configured/loaded/busy flags and one reused IntResult. Source bank derives only from pinned authored content. No placement, service, work, contact or installed-prefix state. |

### `godot/scripts/core/excavation_inventory.gd` — connector installation loss domain

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
| Existing purpose-separated loss column extension | -- | 8 | `LOSS_CELL_CAPACITY` = 1024 | 0 | 1 | §6 AUXILIARY_STATE | Decision1102 extends the existing `_lost_milli` from768 to1024 I64 entries: purpose8 connector installation is fourth after excavation/furniture/tips. Additional2048 persistent bytes and2048 per simultaneous cold image. Every refund uses the same exact receipt owner/transaction; loss survives Project retirement. Canonical reconciliation and composed codec remain required. |

### `godot/scripts/core/modular_projects.gd` — connector purpose binding

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
| Exact weak connector-purpose owner | -- | -- | -- | Unbound until the actual typed placement adapter exists | 3 | -- | Decision1102 adds one WeakRef alongside Furniture/Tip owners, no new packed column/Quote/receipt arena. Purpose8 cannot bind to another actual World or replace a live different owner; the complete real placement/recipe/source contract remains a queued adapter dependency. |

### `godot/scripts/core/underground_connector_source_facts.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Pure final actual source attestation | -- | -- | -- | No retained fields, copies or query result object | 3 | -- | Decision1102. Static typed helper borrows actual Catalog/Profile/Level banks and exact Movement/Residents/Transforms/Directory wiring. Bounded32/64-byte hash comparisons and full World generation validation follow all overridable observation callbacks. Its numeric helper frames fit the existing224-byte nested-frame allowance inside Recipes512 controls; no new arena or packed column. No source/geometry permission is invented. |


### `godot/scripts/core/underground_locations.gd` — create-only World anchor companion

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Once-bound World scope and create-only preparation mode | -- | -- | -- | No prepared anchor or active lease at save/frame boundary | 3 | -- | Decision1103. One unsaved boolean adds 1 logical byte, changing the whole-topology fixed census 2085→2086 within the existing 2112-byte ceiling; total Locations/Routes reservation remains1041728. The WorldScope reference is weak and cannot be replaced after binding, including expiration. No packed bank, allocator, wire or canonical field changes. Exact original Budget, sealed Space and successful publication receipt remain mandatory. New records are only actual World/null-Room level0; all old immutable endpoint payloads survive and must refresh. |
| World observation coexistence | -- | -- | -- | Private input copy dies on return; survey drops at seal or abort | 3 | -- | One local Record is116 logical bytes: integer vectors36, scalar integers32 and copied envelopes48. A256-byte additional guard/record allowance is reserved before World callbacks. Existing88K+384 cold admission therefore becomes88K+640 (721536 atK8192); actual admitted-pack snapshot327680 + fragments196608 +384 +256 =524928 before separately charged caller/provider coexistence. Scope uses full claims even for TRANSIT; existing underground endpoint refresh can conservatively refuse on Room markers. Native objects/handles/growth remain in the existing unmeasured bindings reservation. |
| Pure World publication tail | -- | -- | -- | Exact synchronous actual provider window only | 3 | -- | All ordinary source/Terrain/retention observations precede Space publication. The endpoint swap requires the actual callback-free WorldScope publishing predicate, exact Space receipt/revision, unchanged packed old endpoint identities and the original shared lease, then callback-free Inventory retention. No synthetic first-entry, constructed floor, profile, Site or movement permission is introduced. |

### `godot/scripts/core/underground_space_owner.gd` — leased complete prepared observation

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Exact sealed full-claim copy gate | -- | -- | -- | Caller owns and budgets every output lifetime | 3 | -- | Decision1103. Stateless prepared_snapshot_leased_into requires exact sealed Space token and original actual Budget token before source/claim observers and immediately before the allocating helper. It charges48R+16O+256 plus any retained prior output, recounting after observers. Work admission requires2(R+O) within the existing immutable operation ceiling. All claims remain present; no ordinary snapshot behavior, retained field, wire or schema changes. Same-owner reentry poisons the copy; replacement leases and refused output are preserved. |

### `godot/scripts/core/underground_connector_assemblies.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable group/source/variant census | `_header` | 8 | `7` = 7 | Zero before successful load | 2 | §1 WORLD | Decision1104. Group/Catalog/Recipe revisions, actual Catalog row/variant revision, group and exact actual part counts. Single immutable source bank, no placement/cut/work state. Composed content/source binding is required before activation/save release. |
| Exact immutable source digests | `_digests` | 1 | `96` = 96 | Zero before successful load | 2 | §1 WORLD | Grouping/Catalog/Recipe SHA256. Acyclic file pins; actual Recipe frontier hash names this billable grouping, not physical construction permission. |
| Complete billable part partition | `_kind`, `_first_part`, `_part_count`, `_recipe_anchor` | 4 | `_capacity` <= 256 | Kind/first/anchor -1, count0 | 2 | §1 WORLD | Exactly one group per nonempty contiguous Catalog part range and exactly one actual Recipe anchor per group. Complete unique coverage, no second included-part bill. Four I32 columns16G plus152 fixed immutable bytes. |
| Reused source hash | `_hash` | 1 | `32` = 32 | Empty before admitted configure | 3 | -- | Within512 logical reader controls; not another immutable source image. |
| Reused actual Catalog part facts | `_part` | 4 | `9` = 9 | Empty before admitted configure | 3 | -- | Same fixed allowance. Caller-owned AssemblyRecord adds32 bytes outside this reader. |
| Bound owners, capacity and synchronous controls | -- | -- | -- | Busy false at frame/save boundary | 3 | -- | Actual Catalog/Recipes/Items/Inventory object references; one capacity I64 and three bools11 logical bytes. No serialized pointer, escrow, installed prefix or physical frontier. Maximum required4760 bytes plus unmeasured native overhead; joint Placement/content/control admission remains open. |

### `godot/scripts/core/underground_surface_anchor.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual natural-surface creation scope | -- | -- | -- | No operation, candidate or cold token at save/frame boundary | 3 | -- | Decision1103. One once-bound provider holds actual World/Terrain/Space/CoreSources/Locations/Routes/Budget references; Locations borrows it weakly. Fixed World/seed and transient full handles/tokens/flags are reconstructed composition controls, not independent saved authority. Actual published natural floor/air/support and endpoint records belong to the existing Space/Locations canonical banks. |
| Fixed input and observation scratch | -- | -- | -- | Arrays stay empty until the2048-byte logical binding admission | 3 | -- | Decisions1103/1115. One Locations.Record116 logical bytes (48 packed), one Region72 (24 packed), provider numeric controls93 and returned result16 plus the separately listed24-byte metadata box total321 before nested helper frames. The1024 helper allowance remains within2048; native references/headers remain unmeasured. No per-anchor object, profile certificate, cut ledger or material receipt. Cold preparation borrows the actual full Budget lease, with Locations peak plus2048 admitted before creation. |
| Shared surface metadata input | `_surface_box` | 4 | `6` = 6 | Empty before configure | 3 | -- | Fixed private copy of new or borrowed FLOOR_DATUM bounds. It grants no physical air/support over the intervening dirt and introduces no canonical field. |

### Underground Profiles exact work selection amendment (decision1080)

`query_work_profile_into` adds current profile/content-pinned selection for an
authored WORK contact while reusing the same actual-owner query scratch. The
immutable catalog may retain multiple WORK rows with the same physical key,
within the unchanged16-variant limit; an ordinary ambiguous read refuses.
There are no new retained fields, packed columns, banks, source-image copies,
wire bytes or capacities. Additional selection/dispatch scalar locals and call
frames are conservatively bounded by256 logical bytes within the existing32768
control/native reservation, which remains unmeasured. The query performs no
per-worker heap allocation or saved selection cache. Source/content identity,
complete-state certificate and actual Job/Work/Gear obligations remain unchanged.


### `godot/scripts/core/underground_entry_plan.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Distinct synchronous non-flat request | -- | -- | -- | No request/copy retained at a frame/save boundary | 3 | -- | Decision1108. Caller/private/provider images each carry100 logical scalar bytes,128 source-digest bytes,24B per claim box and16B per opening target. The request grants no source, work, support or route permission. Exact RoomOrders/Bindings use the original shared cold lease; Sites separately owns the canonical paid union. No per-Room state object or save column. |
| RoomOrders entry operation controls | -- | -- | -- | Entry mode false and references cleared after success/refusal | 3 | -- | The existing RoomOrders exclusive Room admission stage also owns an entry-mode boolean, one section EntityRef and transient typed request/claim references. The packet peak includes three digest/target copies plus2048 additional logical controls beyond Sites four-box-image/cursor allowance. Actual binding must add sequential Space/Placement/Location/Route peaks and native headers before production activation. |

### `godot/scripts/core/underground_entry_cut_map.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Borrowed protected non-flat box image | `_boxes` | 4 | never allocated | Empty before configure and after clear | 3 | -- | Decision1107. Caller-owned private world boxes6B I32 entries, B<=Space.MAX_REGIONS16384. No cursor copy or authoritative history. All caller images must be admitted separately under the same cold lease. |
| Active-prefix union intervals | `_intervals` | 8 | `_capacity` runtime | Empty before complete preflight and after clear | 3 | -- | One B-row bank sorts and merges normalized X endpoints in place; no full physical-key output list or second bank. |
| Derived scalar controls and frames | -- | -- | -- | Cursor never crosses a frame/save boundary | 3 | -- | Twelve I64 controls96, four Vector3i48 and three bools3 total147 logical retained numeric bytes. The512-byte fixed logical allowance also covers copied Domain numerical facts/bounds and nested synchronous scalar frames. Actual packed/object headers, Dictionary/String/ref overhead and native growth remain separately unmeasured; no canonical/save state or production memory claim. |

### `godot/scripts/core/underground_connector_placements.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Canonical Placement and opening banks | -- | -- | -- | Only a validated current source tuple can publish | 1 | §1 WORLD | Decision1105. Two banks each hold18 I32 +2 I64 +2 B8 per actual configured Placement, and8 I32 +1 I64 per actual configured opening. One256-byte header/digest image per bank pins World and immutable variant/group/recipe. Existing header15 stores the audited active Project count; all mutations reserve enough global revision increments for its terminal transitions. No WU, bill, cut ledger or duplicate geometry. Streaming canonical capture excludes derived heaps; coordinated physical restore remains mandatory. |
| Bounded audit marks | `_marks` | 1 | `placements + openings` runtime | Audit rebuilt | 3 | -- | Actual configure caps the sum at768. Existing inactive bank receives load scalars directly, without a full raw file image. Both deterministic free heaps are preallocated in each bank. |
| Scalar streaming window | `_stream` | 1 | `width` runtime | Reused for each scalar | 3 | -- | Width is bounded by4096; no retained complete raw-file image. |
| Synchronous companion and source controls | -- | -- | -- | No prepared tokens at save/frame boundary | 3 | -- | One once-bound actual InstallationContext plus private original tokens, weak physical/publisher links and actual immutable owners. Source-counted logical coexistence1557 fits2048 controls: owner117, two Bank free-count pairs32, shared Context112, private Request308, caller Request308, caller Order/Assembly128, result8, digest32, nested frame ceiling512. Conditional envelope189P+89M+14848 includes provisional8192 native bytes; not measured/admitted production maximum. |

### Underground paid installation companion bindings (decision1105)

Space borrows the single actual `Locations.InstallationContext` weakly;
Locations and WorldRoutes retain that same object, whose112 logical numeric
bytes are counted once in Placement2048 above. There is no per-Placement
context, new companion bank, wire or canonical field. Exact original tokens
and actual Router/Construction source leaves guard static publication after
all observers finish before Funding. Native references, WeakRefs and headers
remain part of the explicit unmeasured bindings/native reservation. The cold
retained Placement/target source refresh costs64(P+M) checks and uses only the
already-admitted inactive bank.

### `godot/scripts/core/underground_connector_work.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Actual owner wiring and synchronous installation controls | -- | -- | -- | Unbound or no active transition | 3 | -- | Decision1106. No packed columns, per-placement WU, escrow, claim ledger or canonical fields. Reuses one Placement OrderRecord96B and AssemblyRecord32B; retains original actual Budget and exact action/project only through a synchronous operation. Shared Construction/Funding/Placement remain the durable owners. Actual numeric census179B includes the same128B caller pair already charged by Placement1105, so51B is additional retained control; adapter helper allowance512B makes additional joint563B within the existing bindings reserve. Actual native references/headers remain unmeasured. `is_quiescent()` requires no escaped transition. Save/restore must rebind the actual composition with no open transition. |

The connector-only static Construction START kernel and final Router phase/crew
checks add no members or copied Quote. Their longest new numeric helper chain
is129B (169B including the existing Router entry frame), inside the512B allowance
above; it is not an additional retained allocation or a second paid ledger.

### Future Corridor Placement admission companions (decision1108)

| Retained or transient scope | Change | Accounting and lifecycle |
|---|---|---|
| Pending Placement frontier source | Existing header14 and digest bytes96..127 become once-bound on the first accepted empty-store entry | Pinned in the inactive bank before observers; refusal preserves live zero; retirement to empty preserves the accepted positive revision/hash. No new column, image or counter. Source bytes identify immutable content and grant no physical permission. |
| Synchronous Room admission context | One RoomContext80B, private candidate32B and flag1B | Adds113 logical bytes to Placement1557, giving1670 within the existing2048 fixed allowance. Existing native header/reference reservation remains provisional; no authoritative per-row expansion. All exact original tokens and weak issuer links clear on completion/discard. |
| Existing endpoint/path/certificate refresh | Existing inactive banks only | Same full old handles/payloads; all rows refresh to exact sealed geometry/content. The pure final leaf runs before Room/Sites identity. Actual success receipts then permit static observer-free swaps. No new endpoint, edge, installed part, work counter or physical permission. |
| Sequential cold request and proof lifetime | Two EntryPlan images plus one Location or WorldRoutes proof | Exact runtime admission is2*payload + max(88K+384,377856)+2048 under the original Budget; sizes and lease rechecked after observers. Both proof images drop before Sites batch creation. At R/K6144 and maximum conservative6143 claims/16 targets:838936 Location,675736 graph,644120 final Sites logical bytes. Concrete provider scratch/native overlap still requires joint admission. |

### Existing Placement frame and endpoint readers (decision1105)

The additive readers introduce no owner field, canonical column, packed bank,
mapping or snapshot. Caller frame9I32=36 bytes and endpoint2I32=8 bytes can
coexist with the existing96+32-byte order/assembly pair. Their172 numeric bytes
plus a256-byte bounded helper-frame ceiling fit the explicitly borrowed512-byte
cold control allowance; this is part of the invoking original Budget lease,
not another arena. Extra Frontier/contact state and unmeasured native headers
remain the composing caller's separate obligation. Lookup reads current full
Room/World/section/source identity and grants no installed-prefix or physical
permission.

### `godot/scripts/core/underground_entry_frontier.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Admitted table census | `_capacities` | 4 | `TABLE_COUNT` = 6 | Empty before configure | 3 | -- | Decision1109. Explicit six-int resize/copy at configuration,24 packed bytes, no runtime growth. Count bounds and whole subreserve precede allocation. |
| Immutable source identity and counts | `_header` | 8 | `HEADER_FIELDS` = 14 | Zero before a successful load | 2 | §1 WORLD | Six revisions, Catalog/source selection and six row counts. Content-derived; no runtime Project, worker or phase state. |
| Exact immutable hashes | `_digests` | 1 | `DIGEST_BYTES` = 160 | Zero before a successful load | 2 | §1 WORLD | Self, Catalog, Assembly, Recipe and actual profile-program SHA256. Profiles monotonic content revision is separately exact; program hash is not labelled binary-image hash. |
| Installation selectors | `_install` | 4 | `9 * _capacities[INSTALL]` runtime | Zero before load | 2 | §1 WORLD | One immutable row per billable Grouping ordinal, with prior-only support/retreat. |
| Authored working stations | `_station` | 4 | `9 * _capacities[STATION]` runtime | Zero before load | 2 | §1 WORLD | Endpoint/root/yaw/profile/posture/face/work kind, never an allocated runtime Location. |
| Exact working profile revisions | `_profile_revision` | 8 | `4 * _capacities[STATION]` runtime | Zero before load | 2 | §1 WORLD | Qualified source revision; actual worker/contact observation remains required. |
| Additional quarter-turn work selections | `_rotation_profile` | 4 | `3 * _capacities[STATION]` runtime | -1 before load | 2 | §1 WORLD | Three explicit work-profile IDs beside the primary station row. Every allowed Catalog rotation has its exact source-qualified yaw/profile/revision; no inferred work pose. |
| Canonical physical prerequisites | `_cut` | 4 | `7 * _capacities[CUT]` runtime | Zero before load | 2 | §1 WORLD | Whole-cube union bounds and exact stable phase tags. Actual Sites remains the sole physical progress ledger. |
| Retained bearing selectors | `_bearing` | 4 | `9 * _capacities[BEARING]` runtime | Zero before load | 2 | §1 WORLD | Natural or prior installed-part bounds; a pending part cannot bear itself. |
| Endpoint selectors | `_endpoint` | 4 | `7 * _capacities[ENDPOINT]` runtime | Zero before load | 2 | §1 WORLD | Kind, assembly/datum/role and point only; no live owner handle. |
| Explicit transit selection | `_travel_profile` | 4 | `_capacities[ENDPOINT]` runtime | Zero before load | 2 | §1 WORLD | No implicit WALK selection from a WORK station. |
| Exact transit revision | `_travel_revision` | 8 | `_capacities[ENDPOINT]` runtime | Zero before load | 2 | §1 WORLD | Full paired revision; aliased caller outputs refuse unchanged. |
| Authored excavation episodes | `_episode` | 4 | `19 * _capacities[EPISODE]` runtime | Zero before load | 2 | §1 WORLD | Whole-cube ranges, BRACE/CUT/FINISH masks and explicit station/dependency/material/output/retreat selectors. No second paid-progress bank. |
| Borrowed actual owners and synchronous reader controls | -- | -- | -- | No load at frame/save boundary | 3 | -- | Four actual source-owner refs and configured/loaded/busy flags. Streamed header/row/hash/helper lifetimes fit the explicit2048 logical control reservation; entire configured reader <=28597. Native growth remains unmeasured and must fit actual remaining bindings headroom. Save pins immutable sources; no runtime geometry/contact permission is serialized here. |

### Live static reachability and exact endpoint selection (decisions1098/1105)

The new pure live methods add no owner control, canonical column, packed bank,
retained map or save requirement. Locations reuses its existing pure selector;
WorldRoutes reuses the existing184-byte Descriptor and Routes' admitted search
arrays. The public caller supplies only already-sized endpoint2I32 and
remaining-work1I32 buffers. A bounded512-byte logical helper-frame ceiling
(the source-counted longest path is336 bytes) is charged to the invoking
Contacts/control lifetime. This does not increase Placement's1670/2048 fixed
census or imply a second cold arena; nested caller records/native frames still
need actual joint admission. Full-generation/source checks and finite work
apply on every call. Correctness is component-tested; the measured256-caller
three-span workload failed runtime timing qualification and cannot authorize
unbudgeted searches for every productive worker.

### Bounded source lookup and immutable attestation (decisions1098/1105)

Locations adds an unsaved full source-ref8 plus row-hint8. Its actual fixed
topology control census is2102/2112; the reserved combined1041728 is unchanged.
The hint rechecks packed presence/full generation and all current source facts;
SourceOwner seal/load uniqueness remains mandatory. WorldRoutes adds four
unsaved I64 controls32 inside its existing4096 fixed allowance: original
Catalog/Profile/Levels native instance IDs and last fully checked immutable
Catalog revision. Monotonic/load-once source contracts allow reuse of digest
comparison only; all live wiring, source revisions and generation checks stay.
No authoritative array, retained path map, save/hash field or extra cold arena
is added. The48 logical retained bytes do not change Placement1670/2048 or the
invoking helper-frame ceiling512. Native capacity and timing remain unqualified.
WorldRoutes' existing Catalog reference is inherited from Routes.Bindings,
replacing its former direct declaration without duplicating the per-provider
reference. The cold caller reads that typed field directly after callbacks;
unbound base providers retain null and refuse. Native object headers/reference
storage remain inside the existing provider controls/native obligation.

### Measured direct route reads (decision1098)

The packed-read overhead correction adds no retained fields, arrays, map or
save/hash change. It uses the same actual bank offsets and proof predicates,
with all conservative work charges unchanged. One endpoint stride scalar adds
8 logical frame bytes: the deepest declared path is now344/512 in the existing
invoking Contacts allowance. Borrowed typed local references do not copy their
banks; native reference/interpreter frames remain unmeasured. The prior retained
topology2102/2112 and WorldRoutes4096 reservations are unchanged. A measured
21.465ms p95 for256 small-path queries still fails runtime qualification; this
does not admit an unbudgeted per-worker search or a whole simulation tick.


### `godot/scripts/core/underground_entry_bindings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Immutable episode scratch | `_entry_row` | 4 | `ENTRY_EPISODE_FIELDS` = 19 | Empty before binding | 3 | -- | Decision1111. One fixed synchronous output row, never per-placement progress. |
| Immutable bearing scratch | `_entry_bearing` | 4 | `ENTRY_BEARING_FIELDS` = 9 | Empty before binding | 3 | -- | One fixed synchronous output row. |
| Actual owners and transient entry context | -- | -- | -- | No operation at a save/frame boundary | 3 | -- | Borrowed concrete Frontier/Placement/Room/Terrain owners; one weak-backed Placement authority, two116-byte endpoint records,68-byte transform with four empty target arrays,42 provider numeric bytes and112 packed row bytes total454. The2048 logical helper allowance stays within4096; native headers/frames remain unmeasured. Variable request/cursor images are sequential under the original cold lease. No new canonical state, work, part, endpoint or payment ledger. Source import alone does not qualify memory or gameplay. |

### `godot/scripts/core/underground_connector_contacts.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact frame/source rows | `_frame`, `_install`, `_station`, `_bearing`, `_part` | 4 | `9` = 9 | Empty before configure | 3 | -- | Decision1106 actual Contacts. Fixed caller scratch only, not saved authority or a per-Placement record bank. Exact source facts are rechecked after observations. |
| Reused immutable phase episode | `_episode` | 4 | `19` = 19 | Empty before configure | 3 | -- | Same once-bound Contacts packet reads exact EPISODE selectors. No second packet or per-Site bank; distinct phase mode never aliases an INSTALL Project. |
| Reused cut/endpoint rows | `_endpoint`, `_cut` | 4 | `7` = 7 | Empty before configure | 3 | -- | Immutable selectors do not create endpoints, work, cuts or support. |
| Reused Catalog region facts | `_region` | 4 | `8` = 8 | Empty before configure | 3 | -- | Actual variant-relative LANDING metadata needs independently published full FLOOR_DATUM and support. |
| Reused full endpoint result | `_pair` | 4 | `2` = 2 | Empty before configure | 3 | -- | Actual finite unique selector; no retained map. |
| Shared route work result | `_remaining` | 4 | `1` = 1 | Empty before configure | 3 | -- | The static current-route query spends the same operation budget and preserves this output on failure. |
| Reused exact world boxes | `_bounds`, `_support`, `_target`, `_scratch` | 4 | `6` = 6 | Empty before configure | 3 | -- | Integer exact positive-volume bounds. Negative source foot residual is retained. |
| Whole contact packet and source controls | -- | -- | -- | No open observation or permission across a frame/save boundary | 3 | -- | Source census and runtime reflection confirm3059 logical bytes:452 top-level packed,221 numeric scalar controls, Order96, two Location records232 including their96 packed bytes, Descriptor184, Selection168, two Box records64, IntResult9, and one Fragments packet1633 (two32-row six-I32 banks1536, three six-I32 buffers72, threeI64 plusbool25). Additional1024 numeric helper-frame allowance gives4083 within the admitted4096 binding subreserve, including the nested512 route-query ceiling. The73 additional numeric bytes retain explicit phase mode, full Site, operation/episode, original cold/Space/companion tokens, and separate output full container/Location/payload. Prepared permission requires the original observed tuple and exact actual1121 typed context with independent issuer pins; tokens alone grant nothing. Actual strong/weak references, packed/object headers and native frames remain unmeasured; no native or worker-timing qualification. No new gameplay, receipt, claim, installed-prefix or canonical columns. |

### Installed timber and supported contacts (decision1114)

EntryBindings adds only `_timber_placement` and `_timber_project` (two full
8-byte refs), plus `_timber_assembly` and `_timber_token` (two8-byte controls).
These32 logical bytes are synchronous category3 state, cleared when the exact
operation is discarded or published. They update the prior Entry numeric
census from42 to74 and its complete fixed numeric/packed packet from454 to486,
inside the unchanged4096 reservation. No Location, Placement, SourceOwner or
SurfaceAnchor member, packed column, installed flag, endpoint map or canonical
ordinal is added. The existing Placement installed prefix remains the sole
lasting paid assembly progress.

The reused cold geometry has two6R-I32 fragment banks and four6-I32 boxes.
Actual no-snapshot geometry is48R+4096 =299008 logical bytes atR6144; the
conservative allowed image coexistence remains96R+16O+4096 =626688 atO2048.
Geometry scratch drops before Locations coverage and then WorldRoutes
certificate compilation. Placement's108800 reservation is already charged
once and the EntryPlan/cursor are absent during installation. Own Entry numeric
frames256 plus the existing conservative nested-owner ceiling512 give the
same928/2048 helper charge; the exact installed-Location chain is248 bytes
within that512. Original tokens and work bounds precede each allocation/scan.
Native reference, packed/object header and interpreter-frame costs remain
unmeasured. See the committed1114 census/evidence; this is not runtime or
whole-prefix gameplay qualification.

Installed Location refresh/load rederives current Catalog LANDING, paid prefix,
complete prism and lower-Site witnesses, including fractional floors whose
roots lie inside completed cubes. Every such source pass is before irreversible
publication. No additional image or proof flag survives a save/frame boundary.
Generic Sites refresh with installed contacts remains closed pending the actual
refresh-only phase context in1121; immutable source bytes alone grant no
temporary floor, free air, stair motion or payment.

### `godot/scripts/core/underground_entry_structure.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused exact Placement frame | `_entry_frame` | 4 | `9` = 9 | Empty until bound; overwritten for each actual phase | 3 | -- | Decision1122. Original actual Placement position, cardinal rotation, Level, full Section and Anchor. No independent authority or saved bank. |
| Reused immutable phase episode | `_entry_episode` | 4 | `19` = 19 | Empty until bound; selected only by the exact current Placement prefix and whole Site key | 3 | -- | Same actual Frontier source row, rechecked after observing collaborators. No installed prefix, support receipt or physical ledger is stored here. |
| Entry structural adapter controls | -- | -- | -- | No selected entry at a public boundary; actual owners borrowed through weak references | 3 | -- | The inherited1093 packet remains counted once. Additional fixed logical packet153 bytes comprises112 packed, fourI64 controls32, one full ref8 and onebool1. A separately admitted384-byte increment includes this packet and231 logical helper-frame allowance. Existing cold ceilings stay unchanged; complete CHECK maximum1048912 fits1048960. Source-derived global reconciliation passed119 checker tests and independent review; actual prepared-phase composition and native measurement remain open. Natural support protections publish as real Room-owned Space SUPPORT rows only after paid BRACE; no new canonical authority, native-memory qualification, roof or free walkability. |

### Actual excavation phase companion context (decision1121)

Placements adds one synchronous `Locations.PhaseContext` and one mode byte;
the packet contains five full refs40B plus eleven I64 controls88B. Owner holds
one weak link and Locations borrows that same packet, so128B is counted once.
Five weak owner references and one strong original Budget reference remain
once-bound; operation-specific Site/Project/Room/tokens clear after their exact
candidates are published or discarded. These are category3 controls, absent
from canonical hashes/wire images and never valid at a save/frame boundary.
No packed column, per-Site proof, worker state or second payment ledger is added.

The complete Placement fixed logical census advances1670→1799 inside its
existing2048 allowance. It retains the shared Order96+Assembly32 caller pair
once. The existing512 helper allowance includes the longest new cross-owner
numeric chain484: Authority108, provider callback40, Placement64, installed
Location272. The final installed-source leaf chain is360. Source-derived
member/chain details are reproduced by the1121 `census.py/json`; native object,
reference and packed headers and interpreter frames remain unmeasured.

The actual original Authority Budget owns all sequential cold copies. At the
1093 two-Plan maximum145872, conservative Location691024 and graph526800
peaks include4096 controls and remain below1048960. The old survey drops before
companion preparation and Location coverage drops before graph compilation.
Existing preallocated banks are not charged twice. Only a real successful
Sites payment/settlement publishes the sealed base+1 Space receipt and all
companion/source revisions. Rejected payment changes no live bank. Generic
publication remains guarded by Authority's original token after companion
cleanup. Ordinary unbound behavior and saved schemas remain unchanged.

### Source-qualified stationary ground turn (decision1125)

The concrete WorldRoutes turn command adds no retained member, packed column,
bank, pending command or canonical ordinal to WorldRoutes, Routes or Transforms.
It reuses existing guarded Profile/Location/Box/source packets. No separate
save/hash payload is introduced. A successful fixed-tick action writes only
the existing current yaw, previous yaw/XYZ history and one Transform mutation
revision; current XYZ and route/economic authority remain unchanged. Refusals
preserve their complete images. Existing occupancy freshness stays invalid if
it was already stale before the turn.

The source-counted numeric helper paths fit the existing512 ceiling: the
longest observing cargo chain declares464 bytes, plus48 expression/result
bytes. There is no new reservation or double charge for reused packets. Native
references, interned StringNames, Variant headers, interpreter frames and
existing OpResult allocations are not measured by this logical census.
`underground-ground-turn-2026-10-04/census.py` and its pinned output preserve
the calculation. Production profile/source-phase and whole-client timing
qualification remain open; no stair or productive WORK turn permission is
created by the component.

### Charge-stable route scratch witness (decision1124)

Routes adds one unsaved I64 `_path_serial`; WorldRoutes adds twelve unsaved I64
witness keys/debt controls. These104 logical bytes are category3 optimization
state, absent from canonical hashes/wire images. Actual object IDs, successful
Space/Locations/graph receipts, geometry and immutable profile pins plus the
unchanged full chain/source proof bound reuse of the existing proposed-edge
scratch. Every solver invocation changes the serial before scratch writes;
exhaustion permanently disables reuse. No new packed bank, per-worker proof,
caller permission or saved epoch is introduced.

Both warm and fresh queries reserve64 checks per configured Location before
probing scratch, then consume identical successful Dijkstra debt. Discarding
keys or restoring the actual same Space/Locations images preserves readiness
and remaining logical work. This raises both paths' probe charge, never the
operation ceiling; cold/actor searches retain their existing algorithm.

Source census advances topology fixed controls2102→2110 inside2112 and
WorldRoutes fixed packets/controls862→958 inside4096. The104-byte actual delta
uses those existing reservations; it is not an extra reserve allocation.
The largest declared helper chain336 plus48 expression/result bytes fits the
existing512 caller allowance. Reproduction and source pins are in
`underground-route-witness-2026-10-04/census.py` and `census.json`.
Native/reference/Variant/array/VM overhead and target timing remain unqualified.
Paired repeat17.516ms and fresh22.892ms p95 per256 queries, and38.524ms for256
distinct endpoint pairs, remain failed timing qualification.

### `godot/scripts/core/underground_entry_world_bindings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reused complete motion and contact boxes | `_entry_box`, `_entry_air`, `_entry_reach` | 4 | `6` = 6 | Empty before exact binding | 3 | -- | Decision1119. Three fixed caller buffers,72 logical packed bytes. No per-Site row or retained survey. |
| Synchronous exact entry phase context | -- | -- | -- | No operation at a save/frame boundary | 3 | -- | Weak borrow of the existing Contacts; five full refs40, eight I64 controls64, two Vector3i24 and two booleans2, plus the72 packed bytes above, total202. Source census and runtime reflection agree. The longest own numeric call chain is224 within the explicit1024 helper allowance, giving1226 within a NEW2048 global reservation; the existing4083-byte Contacts packet remains separately charged and singly instantiated. No second Contacts, paid progress, recipe, receipt, endpoint or canonical state. Original source/prefix/lease and reentry controls are synchronous. Native frames and whole-tick qualification remain open. |

### `godot/scripts/core/underground_connector_workpieces.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Canonical static paid workpiece rows | -- | -- | -- | Absent row has zero fields | 1 | §1 WORLD | Decision1134. Two banks each retain five I32 columns and one B8 presence column per actual Placement: Placement generation, full Project and full Region. No new entity namespace, work counter, quantity or paid receipt. Whole-store capture/restore is streamed; composed save and actual-owner restore remain a separate acceptance gate. |
| Immutable source header | `_header` | 8 | `9` = 9 | Zero before source load | 2 | §1 WORLD | Exact source/Catalog/variant/group/recipe/profile revisions and source row/program identity. Immutable source remains separate from actual World permission. |
| Source digests | `_digests` | 1 | `160` = 160 | Zero before source load | 2 | §1 WORLD | Workpiece template, Catalog, Grouping, Recipe and distinct set-down program hashes. An INSTALL source cannot substitute for the set-down program. |
| Included-part and set-down profile selectors | `_parts` | 4 | `6 * assemblies` runtime | Zero before source load | 2 | §1 WORLD | Six field-major columns: complete included part, quarter-turn, XYZ translation and profile. A is admitted at configure and cannot exceed256. |
| Exact set-down profile revisions | `_profile_revisions` | 8 | `assemblies` runtime | Zero before source load | 2 | §1 WORLD | One revision per immutable group; no inferred role or geometry permission. |
| Reused exact bounds and coordinate scratch | `_bounds`, `_scratch` | 4 | `6` = 6 | No prepared operation at save boundary | 3 | -- | Two24-byte packed boxes inside2048 logical control/helper bytes. Numeric controls75B give123B retained numeric/packed controls; borrowed owner references and native overhead remain unmeasured. |
| Whole-owner admission | -- | -- | -- | Complete arena admitted before either bank or source allocation | 3 | -- | Separate contribution42P+32A+232+2048+512+8192 =29928B atP=A=256. The512 stream and8192 provisional native reservations coexist with both banks and the immutable source. This is outside the fully assigned binding reserve; it does not increase the100MB joint ceiling. Native measurement and composed persistence remain open. |

### Paid workpiece spatial and owner controls (decisions1134–1135)

The shared InstallationContext adds an8-byte action and8-byte full obstacle;
Placement independently retains the same16-byte tuple. Its once-bound Workpieces
reference is weak. The source-derived Placement controls total1895/2048B,
including a576B nested helper allowance; this reallocates64B of existing
headroom and adds32B of retained numeric state without expanding a reserve.
The complete recorded phase/endpoint chain is572B. ConnectorWork adds one
borrowed Workpieces reference and no numeric or packed field. Its existing563B
logical allowance and Contacts'4096B allowance remain unchanged. Native
reference/header costs and whole-client peak qualification remain open.
