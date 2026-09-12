# Persistence: the future-affecting-state registry

Task 09.1. One row per store per column group, for every module under
`godot/scripts/core/`. **There is no save module in this repository.** This
document is the inventory that makes writing one (09.2/09.3) possible; it writes
no bytes and settles no schema.

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

### `godot/scripts/core/catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Compiled enum domains | -- | -- | -- | -- | 3 | -- | Holds no `var` at all: eight protected enum tables and `ITEM_DEFINITION_MAX_KEYS` compiled from lexicographically sorted ASCII keys (GDD §4.2 closing paragraph). Nothing here changes at runtime, so nothing here is saved. The catalog's identity reaches the file as the header's catalog hash at offset 72, produced by `catalog_ids.gd`. |

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
| Pending command envelope (i64) | `_execute_tick` | 8 | `QUEUE_CAPACITY` = 4096 | Only the `_count` rows from `_head` are live; the rest hold whatever a drained command left. ARCH-SAVE-002: encode zero for unused payload | 1 | §12 PENDING_COMMANDS | ARCH-SAVE-001's 64-byte command record, field for field. `docs/planning/ready07_scheduler_contract.md:125-132` fixes the container-v2 form: a 24-byte prefix, then E 64-byte records in canonical command order, E<=4096. `_sequence_low`/`_sequence_high` hold u32 BITS in i32 columns, so a sequence past 0x80000000 stores negative -- the codec must write the bits, not a signed widening. |
| Pending command envelope (i32) | `_player_id`, `_sequence_low`, `_sequence_high`, `_kind`, `_target_slot`, `_target_generation`, `_goal_x`, `_goal_z`, `_arg0`, `_arg1`, `_payload_offset`, `_payload_length`, `_flags`, `_reserved_zero` | 4 | `QUEUE_CAPACITY` = 4096 | Only the `_count` rows from `_head` are live; the rest hold whatever a drained command left. ARCH-SAVE-002: encode zero for unused payload | 1 | §12 PENDING_COMMANDS | See the first row of this group. |
| Queue order index | `_order` | 4 | `QUEUE_CAPACITY` = 4096 | Entries outside `[0, _count)` are stale | 2 | §12 PENDING_COMMANDS | ready07 §Save: "Rebuild ring/order indexes deterministically". Records are written in canonical order and restored from row 0, so head becomes 0 and this index is regenerated rather than carried. |
| Payload arena | `_payload` | 1 | `PAYLOAD_ARENA_BYTES` = 1048576 | Bytes at or past `_payload_used` are unallocated, not zeroed | 1 | §12 PENDING_COMMANDS | ready07 §Save: write "exactly P bytes of the economic payload arena's used prefix (preserve offsets and consumed space that still affects admission)", P<=1048576. Compacting it on load would change which future command is admitted, so the used prefix is future-affecting even where a live command no longer points into part of it. |
| Empty-reference constant | `_no_refs` | 4 | never allocated | Always length 0 | 3 | -- | A permanently empty array passed as the "no referenced ids" argument. Never sized, never written. |
| Queue control and sequence allocator | -- | -- | -- | -- | 1 | §12 PENDING_COMMANDS | `_count`, `_payload_used`, `_next_sequence_high` and `_next_sequence_low` are four of ready07's six prefix U32 fields (`docs/planning/ready07_scheduler_contract.md:125-127`). The sequence pair is an allocator, not a counter: reusing a number would make two distinct commands compare equal in a replay stream. |
| Ring head | -- | -- | -- | -- | 2 | §12 PENDING_COMMANDS | `_head`. Records are written in canonical order and restored from row 0, so its canonical restored value is 0. |
| Command diagnostics and scratch | -- | -- | -- | -- | 3 | -- | `_kind_count`, `_accepted_count`, `_refused_count`, `_drained_count`, `_refused_member`, `_last_refusal`, `_math`, `_scratch`. |

### `godot/scripts/core/crop_weather.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Daily and hourly orchestration latches | -- | -- | -- | `_last_day == 0` (`NO_DAY_RUN`) and `_last_hour_tick == -1` (`NO_HOUR_RUN`) mean "never run" | 1 | §6 AUXILIARY_STATE | These latches are the only thing stopping a day's crop/weather pass running twice or being skipped. A reload that reset them would re-run the current day's ecology against already-advanced stocks. `_calendar`, `_read`, `_tile_x`, `_tile_z`, `_last_refusal` and the eight collaborator handles are category 3. |

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
| Free-slot and free-row heaps | `_free_heap`, `_heap_index` | 4 | `DIRECTORY_CAPACITY` = 352418 | Only the first `_free_count` / `_kind_free_count[kind]` entries of each window are live | 2 | §3 ENTITY_DIRECTORY | ARCH-SAVE-002 permits either: "Save allocator heaps or rebuild them deterministically from occupancy and retired masks". Rebuild is correct here because `_pop_min()` returns the window minimum, so allocation order depends on the SET of free entries and not on the array permutation; `_rebuild_free_heaps()` already fills ascending, which is a valid min-heap. Task 09's "restored lowest-free allocation" check is exactly this property. |
| Per-kind allocator counters | `_kind_base`, `_kind_free_count`, `_kind_live_count` | 4 | `KIND_COUNT` = 18 | No null: every kind always has an entry | 2 | §3 ENTITY_DIRECTORY | `_kind_base` is the prefix sum of the `KIND_CAPACITY` constant and can never differ between two builds of the same rules. The two counts are recomputed from `_active` and `_retired` with the heaps. |
| Persistent-id allocator | -- | -- | -- | -- | 1 | §1 WORLD | `_next_persistent_id` IS future-affecting and IS NOT derivable: `destroy()` zeroes `_persistent_id`, so "max live id + 1" is wrong the moment anything has died, and reusing an id breaks ARCH-SAVE-004's unique-persistent-id validation. It is `WorldRuntime.next_persistent_id` in §2's ledger (systems_architecture.md:405). |
| Directory live counters | -- | -- | -- | -- | 2 | §3 ENTITY_DIRECTORY | `_free_count` and `_live_count`, recomputed with the heaps from `_active` and `_retired`. |
| Directory refusal code | -- | -- | -- | `REFUSAL_NONE` is the empty StringName | 3 | -- | `_last_refusal`, the code from the most recent refused `create()`. |

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
| FishingEffortClaim (u8) | `_effort_claim_active` | 1 | `FISHING_EFFORT_CLAIM_CAPACITY` = 512 | `_effort_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A live claim on habitat effort slots: exactly task 09.1's "clocks/leases/claims". Indexed by the OWNING EXPEDITION'S typed row, so the row index itself is identity and the loader must not compact these rows. The owner reference is rebuilt through `entity_directory.owner_slot_of_typed_row()`, which is why only the generation is stored. |
| FishingEffortClaim (i32) | `_effort_claim_expedition_generation`, `_effort_claim_habitat_slot`, `_effort_claim_habitat_generation`, `_effort_claim_job_slot`, `_effort_claim_job_generation`, `_effort_claim_slot_count` | 4 | `FISHING_EFFORT_CLAIM_CAPACITY` = 512 | `_effort_claim_active == 0` is a free claim row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| Effort tally scratch | `_effort_total_scratch` | 4 | `FISH_HABITAT_CAPACITY` = 32 | Refilled per pass | 3 | -- | Per-habitat running total inside one effort pass. |
| Fishing scratch | -- | -- | -- | -- | 3 | -- | `_math`, `_math_b`, `_math_c`, `_effort_claim_count`, `_pending_claim_row`, `_pending_habitat_slot`, `_owns_directory`. `_effort_claim_count` is recomputed from `_effort_claim_active`. |

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

### `godot/scripts/core/gear.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| GearInstance columns | `_lot_slot`, `_lot_generation`, `_item_id`, `_durability`, `_durability_cap`, `_owner_slot`, `_owner_generation`, `_manufacture_recipe` | 4 | `_row_capacity` <= 16384 | `_lot_slot`/`_owner_slot` hold `-1` with generation 0 for the null ref | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A GEAR ROW HAS NO GENERATION OF ITS OWN. `_lot_generation` is the inventory LOT's local generation and `_owner_generation` is the resident's DIRECTORY generation -- two different generation spaces in one row. The module's header records that a persistent `GearRef` "needs budgeted generations and a retirement rule" and that none is budgeted, so gear rows are addressed by row index only: §7 must write them in row order and a load must not compact them. |
| Gear occupancy and equip flag | `_equipped`, `_occupied` | 1 | `_row_capacity` <= 16384 | `_occupied == 0` is a free row; `_equipped == 0` is stowed | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset plus the equip state a reload must preserve. |
| Gear job claims | `_claim_job_slot`, `_claim_job_generation` | 4 | `_row_capacity` <= 16384 | `_claim_job_slot == -1` with generation 0 means unclaimed | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A live tool claim by a job: task 09.1's "claims". The generation is the DIRECTORY's, for the claiming job. |
| Gear free heap | `_free_heap` | 4 | `_row_capacity` <= 16384 | Only `[0, _free_count)` is live | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | A min-heap like `entity_directory.gd`'s, so ARCH-SAVE-002's rebuild permission applies: allocation order depends on the free set, not the permutation. |
| Starter-seed rollback buffer | `_seed_lot_slot`, `_seed_lot_generation` | 4 | `STARTER_TOOL_TOTAL` = 24 | Only `[0, _seed_count)` is meaningful, and `_seed_count` is 0 outside a seeding call | 3 | -- | CONSTRUCTION-TIME RECORD, NOT AUTHORITATIVE STATE. That is an explicit call, made by the author of the column (decision 0061), not a default. It holds the lot references that one in-flight `seed_starter_tools()` has created so far, so `_rollback_seed()` can undo exactly those and nothing else; nothing reads it once the call returns, and it records no fact that is not already in the gear rows above and `inventory.gd`'s lot rows. `seed_starter_tools()` is a single synchronous call and ARCH-SAVE-003 saves only at a completed tick boundary, so no save can observe a half-seeded state. Domain, per the 2026-09-11 addendum: the pair is an INVENTORY LOT reference (`_l_generation`), not a container ref and not a directory ref, so anything that ever does validate it must validate it there. RESOLVED by STATE-COHORT-R01 (2026-09-11): residents.gd's analogous `_cohort_slots` rollback buffer is category 3 too; the earlier category-1 founder-history interpretation is superseded. |
| Gear scalars | -- | -- | -- | `_id_* == -1` means the item key was not resolved | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_row_capacity` is a construction argument, `_free_count` and `_active_count` are recomputed from `_occupied`, the five `_id_*` fields are re-resolved from the verified catalog, and `_restoring` is a transient guard that must be false at any save boundary. |

### `godot/scripts/core/int_math.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Checked integer arithmetic | -- | -- | -- | -- | 3 | -- | Pure functions and one `IntResult` value class; no module-level `var` and no state. Listed so the registry covers every file under `godot/scripts/core/` and a future state field here cannot slip in unclassified. |

### `godot/scripts/core/inventory.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Container identity and policy | `_c_owner_slot`, `_c_owner_generation`, `_c_policy`, `_c_generation`, `_c_lot_count`, `_c_first_lot` | 4 | `_c_capacity` <= 101376 | `_c_owner_slot == -1` with generation 0 is the null ref; `_c_first_lot == -1` means no lots | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_c_generation` IS THIS MODULE'S OWN GENERATION SPACE, not the directory's. The header (lines 69-72) records that ARCH-ID-001 gives both containers and lots a directory kind but that "this module allocates its own slots". A container `EntityRef` therefore validates against `_c_generation`, and §7 must carry it in full for the same reason §3 carries the directory's -- two independent generation spaces that 09.2 must not merge. |
| Container mass and filters | `_c_max_mass_g`, `_c_filters`, `_c_reserved_mass_g`, `_c_used_mass_g` | 8 | `_c_capacity` <= 101376 | 0 | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | ARCH-SAVE-005 validates that charged mass plus reserved mass does not exceed capacity. `_c_used_mass_g` and `_c_reserved_mass_g` are also recomputable from the lot chain; they are written and cross-checked, not chosen between. |
| Container occupancy | `_c_live` | 1 | `_c_capacity` <= 101376 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset. |
| Container reachability | `_c_reachable` | 1 | `_c_capacity` <= 101376 | 0 = unreachable, and also the value every row starts at | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | GDD §4.2 / decision 0063: explicit container state, no current deterministic rebuild owner. Save/hash live 0/1 exactly; canonical zero for unused payload. Future topology derivation requires an explicit owning-contract/schema amendment, not a default. |
| Lot identity and chain | `_l_item_id`, `_l_quality`, `_l_provenance`, `_l_recipe_id`, `_l_container_slot`, `_l_container_generation`, `_l_generation`, `_l_next`, `_l_prev` | 4 | `_l_capacity` <= 16384 | `_l_next`/`_l_prev` hold `-1` at the ends of a container's chain; `_l_container_slot == -1` with generation 0 on a LIVE lot means EQUIPPED, not free | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_l_generation` is the second local generation space described above. The doubly linked chain order is observable to merge and withdrawal order, so it is written as a chain rather than re-derived from `_l_container_slot` ascending. DECISION 0061 GAVE `_l_container_slot == -1` A MEANING: a live lot with a null container is an equipped gear record held by a resident, threaded into no chain and charging no container's mass. A loader must not read it as a free row -- `_l_live` is what says free -- and must not attach it to a container. The pairing is exact in both directions: the container is null if and only if `gear.gd` attests an equipped record with a live owner, which `inventory.audit()` re-derives per lot and refuses as `AUDIT_ORPHAN_LOT` otherwise. |
| Lot quantities and age | `_l_quantity_milli`, `_l_reserved_milli`, `_l_age_milli_hours`, `_l_age_remainder` | 8 | `_l_capacity` <= 16384 | 0 | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `quantity_milli` int64 per AGENTS.md. `_l_age_remainder` is the sub-hour spoilage remainder task 09's acceptance list calls out by name; a negative or truncated age inverts every downstream spoilage result, so ARCH-SAVE-005's `quantity>=0` and `0<=reserved<=quantity` checks apply here and refusal is the only legal response. |
| Lot occupancy | `_l_live` | 1 | `_l_capacity` <= 16384 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset. |
| Free-slot stacks (i32) | `_c_free` | 4 | `_c_capacity` <= 101376 | Only `[0, _c_free_count)` / `[0, _l_free_count)` is live | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A STACK, NOT THE DIRECTORY'S MIN-HEAP (comment at line 259). Pop order is therefore last-freed-first and depends on the array contents, so unlike `entity_directory.gd`'s heaps this allocator is NOT reconstructible from occupancy and must be written. ARCH-SAVE-002's "save allocator heaps or rebuild them" resolves to "save" for this store. |
| Free-slot stacks (i32) | `_l_free` | 4 | `_l_capacity` <= 16384 | Only `[0, _c_free_count)` / `[0, _l_free_count)` is live | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | See the first row of this group. |
| Item catalog facts (i32) | `_item_mass_g`, `_item_category` | 4 | `ITEM_CAPACITY` = 256 | `_item_registered == 0` means the id has no registered mass | 2 | §2 CATALOG_IDS | The module's own comment: "Catalog-time item facts. Not simulation state". Re-registered from the verified catalog on load. |
| Item catalog facts (u8) | `_item_registered` | 1 | `ITEM_CAPACITY` = 256 | `_item_registered == 0` means the id has no registered mass | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Conservation ledger | `_sourced_milli`, `_sunk_milli` | 8 | `ITEM_CAPACITY` = 256 | 0 | 3 | -- | Lifetime totals read only by `audit()`. Dropping them changes no future state; it changes only what a post-load audit reports, and the audit compares live quantities either way. |
| Undo journal (i32) | `_j_kind`, `_j_index` | 4 | `JOURNAL_CAPACITY` = 4096 | Only `[0, _j_count)` is live | 3 | -- | The module labels this "scratch, not authoritative state". ARCH-SAVE-003 saves only a completed boundary, so `_tx_open` is false and the journal is empty at every legal save point; 09.2 should assert that rather than serialize it. |
| Undo journal (i64) | `_j_row` | 8 | `JOURNAL_CAPACITY * ROW_STRIDE` = 57344 | Only `[0, _j_count)` is live | 3 | -- | See the first row of this group. |
| Audit tally | `_audit_live_milli` | 8 | `ITEM_CAPACITY` = 256 | Refilled per audit | 3 | -- | Allocated once so `audit()` costs no allocation; holds nothing between audits. |
| Inventory counts and capacities | -- | -- | -- | -- | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_c_capacity`/`_l_capacity` are construction arguments; `_c_free_count`, `_l_free_count`, `_c_live_count` and `_l_live_count` are recomputed from `_c_live`/`_l_live` and the free stacks. `_equipped_lot_count` is recomputed the same way, from the live lots whose `_l_container_slot` is `-1`, and `audit()` already re-derives it rather than trusting it. |
| Transaction state and scan hints | -- | -- | -- | -- | 3 | -- | `_tx_open`, `_tx_poisoned`, `_tx_error`, `_tx_saved_*`, `_plan`, `_math`, `_out_ref`, `_out_value`. ARCH-SAVE-003 saves only a completed boundary, so `_tx_open` must be false at any legal save point. `_c_slot_high_water`/`_l_slot_high_water` are excluded by the module's own `state_bytes()` precisely so two byte images of identical state cannot differ over a scan hint. `_tx_saved_equipped_count` belongs to the same transaction group. `_equipment_authority` is a wiring reference to `gear.gd` and `_attesting` is a frame-local re-entry guard that is false outside an attestation: both rebind at load, and a loader must re-bind the authority before auditing, because with none bound every equipped lot reads as an orphan. |

### `godot/scripts/core/item_definitions.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Compiled item facts (i32) | `_nutrition_per_u`, `_shelf_hours`, `_effect_id`, `_effect_value` | 4 | `count` runtime | `_effect_id` holds the compiled `none` effect for items with no effect | 2 | §2 CATALOG_IDS | Loaded from `res://data/item_definitions.json` and sized to that file's key count, which is why the count is not a compile-time constant. Rebuilt by reloading the catalog whose hash the save header pins at offset 72; writing them would duplicate the artifact §2 already carries. |
| Compiled item facts (u8) | `_raw_edible`, `_seed` | 1 | `count` runtime | `_effect_id` holds the compiled `none` effect for items with no effect | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Catalog dictionaries and load flag | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_item_ids`, `_category_ids`, `_effect_ids`, `_item_count`, `_loaded`. Same argument: rebuilt by `load()` against the verified artifact. |

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
| Dirty-row work lists (i32) | `_dirty_rows` | 4 | `OWNER_CAPACITY` = 4096 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | A sweep accelerator, not state: a load that marks every owner dirty produces the same evaluations in the same order, at the cost of one full sweep. ARCH-HASH-001 excludes "derived spatial/active indexes" and this is one. |
| Dirty-row work lists (u8) | `_is_dirty` | 1 | `OWNER_CAPACITY` = 4096 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | See the first row of this group. |
| Dirty-row work lists (i32) | `_dirty_zone_rows` | 4 | `ZONE_OWNER_CAPACITY` = 128 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | See the first row of this group. |
| Dirty-row work lists (u8) | `_is_zone_dirty` | 1 | `ZONE_OWNER_CAPACITY` = 128 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | See the first row of this group. |
| Dirty-row work lists (i32) | `_dirty_hive_rows` | 4 | `HIVE_OWNER_CAPACITY` = 1024 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | See the first row of this group. |
| Dirty-row work lists (u8) | `_is_hive_dirty` | 1 | `HIVE_OWNER_CAPACITY` = 1024 | Only `[0, _dirty*_count)` of each list is live | 2 | §8 JOB_INDEXES | See the first row of this group. |
| Planner counters and scratch | -- | -- | -- | -- | 3 | -- | Twenty-eight `_*_count` diagnostics, `_last_blocker`, `_math` and `_calendar`. `_dropped_on_load_count` is named for a load path that does not exist yet. |

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
| Jobs pass inputs and scratch | -- | -- | -- | -- | 3 | -- | `_food_reserve_below_two_days` is a per-pass world input the caller restates each pass. `_best_*`, `_walk_*`, `_math`, `_dangerous_consent_scratch` and `_hazard_locked_scratch` live inside one candidate evaluation. |

### `godot/scripts/core/movement.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| ResidentMotion velocity and remainders | `_vx`, `_vz`, `_remainder_x`, `_remainder_z`, `_next_x`, `_next_z` | 4 | `MOTION_CAPACITY` = 512 | 0 for an idle body | 1 | §4 COMPONENT_COLUMNS | ARCH-MEM-008's ResidentMotion fields. The two remainders are sub-unit position carried at denominator `30 * COST_DIAGONAL`; dropping them moves a body by up to one unit per axis and diverges immediately. |
| ResidentMotion reserved fields | `_correction_x`, `_correction_z`, `_radius_u`, `_desired_yaw`, `_next_yaw` | 4 | `MOTION_CAPACITY` = 512 | Currently always 0 | 1 | §4 COMPONENT_COLUMNS | RESERVED: the module's header says separation, body radii and yaw are all held at zero because MOVE-G01's parameter pack has not supplied them and facing's zero reference is unstated. They are ledgered §2 fields, so they are written as zeros and MUST NOT be repurposed -- MOVE-G02 owns the expanded movement version and migration matrix that changes them. |
| ResidentMotion route cells | `_grid_next`, `_grid_cell` | 4 | `MOTION_CAPACITY` = 512 | `-1` (`NO_REQUEST`) when the body is following no route | 1 | §4 COMPONENT_COLUMNS | NOT a spatial-hash chain: `_grid_cell` is the cell the body occupies and `_grid_next` the route cell it is walking to, and `_segment_is_diagonal()` compares them to charge 10 or 14. They hold invariantly to `route_cell(_cursor_request, _cursor_index)` and its successor, so they are derivable -- but they are two of ARCH-MEM-008's sixteen ledgered ResidentMotion fields, so the ledger rule applies: written, and cross-checked against the cursor on load rather than chosen between. |
| ResidentMotion speed and phase | `_speed_u_per_s`, `_movement_phase`, `_blocked_ticks` | 4 | `MOTION_CAPACITY` = 512 | `_movement_phase == 0` is `MOTION_IDLE`, a real phase and not absence | 1 | §4 COMPONENT_COLUMNS | `_blocked_ticks` is an accumulating counter that drives the route-lost decision. |
| ResidentRouteCursor | `_cursor_request`, `_cursor_route_generation`, `_cursor_index` | 4 | `MOTION_CAPACITY` = 512 | `_cursor_request == -1` (`NO_REQUEST`) when the body follows no route | 1 | §9 NAVIGATION | Decision 0053's addition, because ARCH-MEM-008's ResidentMotion has no field naming which route a body follows or how far along it is. `_cursor_route_generation` validates against `navigation.gd`'s descriptor generation -- a THIRD generation space, distinct from the directory's and from inventory's. |
| ResidentRouteCursor ownership | `_cursor_owner_id` | 4 | `MOTION_CAPACITY` = 512 | `0` (`NO_OWNER_ID`) when the row's cursor belongs to nobody | 1 | §9 NAVIGATION | Decision 0066. The persistent id of the resident the cursor was attached for, compared on every `_advance_row()` so a successor spawned into a despawned traveller's typed row cannot inherit its route. Persistent ids are never reused, which is why this is not a generation -- the same reasoning as `transforms.gd`'s `_bound_persistent_id`, and a load that dropped it would let one reused row walk the wrong body. |
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
| Resident state bytes | `_status`, `_present`, `_size_class`, `_activity`, `_comfort_environment`, `_social_paired`, `_purpose_source`, `_cold_environment`, `_clothing_tier`, `_infirmary`, `_injury_state` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row; the rest are byte enums whose 0 is a real value | 1 | §4 COMPONENT_COLUMNS | `_injury_state` is the GDD's Injury model (kind/severity/care), which is settlement healing and NOT a combat damage model. ARCH-SAVE-005 bounds each byte against its `*_COUNT`. |
| Hunger rate table | `_hunger_rate_milli` | 8 | `SIZE_COUNT` = 3 | One entry per size class | 2 | §4 COMPONENT_COLUMNS | Three constants derived from the balance table at construction, not runtime state. |
| Needs tick scratch | `_rate_scratch` | 8 | `NEED_COUNT` = 5 | Refilled per resident | 3 | -- | Five entries, one per need, reused by the tick. |
| Needs live counters | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_present_count` and `_living_count`, recomputed from `_present` and `_status`. ARCH-SAVE-005 caps living residents at 256, which is checked against the recomputed value, not a stored one. |
| Needs pass inputs and scratch | -- | -- | -- | -- | 3 | -- | `_winter` and `_hard_freeze` are per-tick world inputs the caller restates every tick. `_death_count`, `_last_refused_slot`, `_math`, `_step_value`, `_step_remainder` and `_out_value` are diagnostics or scratch. |

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

### `godot/scripts/core/reservations.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Reservation rows | `_r_job_slot`, `_r_job_generation`, `_r_lot_slot`, `_r_lot_generation`, `_r_purpose` | 4 | `_row_capacity` <= 32768 | `-1` slot with generation 0 is the null ref | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | A RESERVATION ROW HAS NO GENERATION OF ITS OWN: `_r_job_generation` is the directory's and `_r_lot_generation` is `inventory.gd`'s LOCAL lot generation, so one row spans two generation spaces and neither belongs to it. Rows are addressed by index, so §7 must not compact them. |
| Reservation quantity and expiry | `_r_quantity_milli`, `_r_expiry` | 8 | `_row_capacity` <= 32768 | 0 quantity is a real (empty) reservation, not absence | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | `_r_expiry` is an absolute tick: ARCH-SAVE-006 names "an expired lease" as a coverage case, and ARCH-SAVE-005 requires each reservation sum to equal its lot's `reserved_milli`. |
| Reservation occupancy | `_occupied` | 1 | `_row_capacity` <= 32768 | 0 = free row | 1 | §7 INVENTORIES_AND_LEASE_INDEXES | Occupied bitset. |
| Reservation free heap | `_free_heap` | 4 | `_row_capacity` <= 32768 | Only `[0, _free_count)` is live | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | A min-heap like `entity_directory.gd`'s, so ARCH-SAVE-002's rebuild permission applies: the free SET determines allocation order. |
| Per-job reservation index | `_job_head` | 4 | `_job_capacity` <= 8192 | `-1` for a job with no reservations | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Head of the per-job chain; rebuilt by walking occupied rows ascending. |
| Per-lot reservation index | `_lot_head` | 4 | `_lot_capacity` <= 16384 | `-1` for a lot with no reservations | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Head of the per-lot chain; same rebuild. |
| Reservation chain links | `_job_prev`, `_job_next`, `_lot_prev`, `_lot_next` | 4 | `_row_capacity` <= 32768 | `-1` at either end of a chain | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | Both chains are pure indexes over `_r_job_slot`/`_r_lot_slot`; rebuilding them ascending gives one canonical order, which is what ARCH-SAVE-004's "rebuild derived indexes" step is for. |
| Reservation counts and capacities | -- | -- | -- | -- | 2 | §7 INVENTORIES_AND_LEASE_INDEXES | `_row_capacity`, `_job_capacity` and `_lot_capacity` are construction arguments; `_active_count` and `_free_count` are recomputed from `_occupied`. |
| Reservation scratch | -- | -- | -- | -- | 3 | -- | `_math` and `_pending_new_rows`, both consumed inside one call. |

### `godot/scripts/core/residents.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Species catalog table (utf-8) | `_species_key` | var | `SPECIES_COUNT` = 16 | Sized to `SPECIES_COUNT` regardless of how many keys the catalog defines | 2 | §2 CATALOG_IDS | Loaded from the catalog; `_species_key` is the only `PackedStringArray` in a core store and has no fixed element width. Rebuilt on load from the artifact the header hash pins. |
| Species catalog table (u8) | `_species_size` | 1 | `SPECIES_COUNT` = 16 | Sized to `SPECIES_COUNT` regardless of how many keys the catalog defines | 2 | §2 CATALOG_IDS | See the first row of this group. |
| Resident occupancy and species (u8) | `_present` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | 512 rows; ARCH-SAVE-005 caps living residents at 256 and rows at 512. |
| Resident occupancy and species (i32) | `_species` | 4 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
| Resident classification | `_size_class`, `_named` | 1 | `RESIDENT_CAPACITY` = 512 | `_named == 0` means the resident still carries a generated name | 1 | §4 COMPONENT_COLUMNS | `_size_class` mirrors `needs.gd`'s and must agree after a load. |
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
| Resident scratch | -- | -- | -- | -- | 3 | -- | `_math` and the `_owns_collaborators` construction flag. |

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
| Deposit footprint plan | `_deposit_tiles`, `_deposit_ref_slot`, `_deposit_ref_generation` | 4 | `DEPOSIT_NODE_COUNT` = 16 | `-1` slot with generation 0 is the null ref | 1 | §1 WORLD | The sixteen nodes of a 4x4 mineral deposit; world-generation output that must survive a reload as generated. |
| Resource node live count | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_live_count`, recomputed with the active list. |
| Resource node scratch | -- | -- | -- | -- | 3 | -- | `_math` and the `_owns_directory` construction flag. |

### `godot/scripts/core/rng.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Per-stream xorshift32 state | `_state` | 4 | `STREAM_COUNT` = 9 | 0 is the UNSEEDED value and is exactly what xorshift32 forbids, so it can never be a live state | 1 | §10 RNG | THE CURRENT STATE, NOT THE SEED. Nine streams in crowd §6.1's SIGNED int32 storage form: a state at or above 2147483648 is stored negative. `stored_state_of()` returns that signed form and `restore_stream()` accepts the UNSIGNED u32 and refuses a negative, so §10 must write `stored_state_of()` and the loader must convert back before restoring. Re-deriving a stream from `_world_seed` on load would restart it at draw 0 and diverge on the very next roll -- silently, because the values are still plausible. |
| Per-stream draw counts | `_draw_count` | 8 | `STREAM_COUNT` = 9 | 0 draws is the seeded state | 1 | §10 RNG | ARCH-RNG-002: "Store state plus int64 draw count", and ARCH-HASH-001 hashes "RNG states/draw counts". They are also the localiser ARCH-HASH-002 dumps on a mismatch, so a divergence names a stream and a draw index rather than "the RNG". |
| RNG seed and seeded flag | -- | -- | -- | `_seeded == false` with `_world_seed == 0` is the unseeded store | 1 | §1 WORLD | `_world_seed` is `World.seed` in §2's ledger. §10 cannot be decoded without it: `restore_stream()` requires a seeded store because the retired HUNTING stream's canonical value is defined against the seed, and SET-AMEND-001 §3 requires a noncanonical tombstone to FAIL validation. ARCH-SAVE-002's section order already puts WORLD (1) before RNG (10), so the load order works; 09.2 must not reorder them. |

### `godot/scripts/core/save_codec.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Encoding primitives | -- | -- | -- | -- | 3 | -- | Holds no module-level `var` at all: ARCH-SAVE-001's little-endian integer, two's-complement and length-prefixed-UTF-8 primitives, all static, plus a `Reader` and a `Writer` whose buffers are per-call scratch owned by the caller that constructed them. It is the codec the sections are written THROUGH; it owns no world state, so there is nothing here to save. ARCH-SAVE-007's line that "a memory allocation row alone does not make a field persisted or canonical" is the same point from the other direction. |

### `godot/scripts/core/save_header.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Fixed header and section table | -- | -- | -- | -- | 3 | -- | Holds no module-level `var` beyond the lazily built 256-entry CRC-32/ISO-HDLC lookup table, which is a compile-time constant derived from the reversed polynomial `systems_architecture.md:745` states. Everything else is static: the 256-byte header codec, the 64-byte descriptor codec, the body SHA-256 and the section-table validator. The header's own bytes are file structure, not simulation state; the catalog hash it carries at offset 72 is `catalog_ids.gd`'s digest, not a second one. |

### `godot/scripts/core/schedule.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Activity templates | `_template_hours` | 1 | `TEMPLATE_COUNT * HOURS_PER_DAY` = 72 | Three templates x 24 hours | 2 | §2 CATALOG_IDS | Compiled from the catalog at construction; rebuilt on load. |
| Per-resident hourly schedule | `_hourly_activity` | 1 | `SCHEDULE_CAPACITY * HOURS_PER_DAY` = 12288 | One byte per (resident, hour); the value is a real activity, never absence | 1 | §4 COMPONENT_COLUMNS | Player-authored by SET_ACTIVITY_SCHEDULE commands, so nothing recomputes it. ARCH-SAVE-005 bounds each byte by `ACTIVITY_COUNT`. |
| Schedule assignment | `_template`, `_current_activity` | 4 | `SCHEDULE_CAPACITY` = 512 | None on a live row | 1 | §4 COMPONENT_COLUMNS | `_current_activity` is resolved each hour but is read within the hour it is set, so a mid-hour save must carry it. |
| Schedule flags | `_present`, `_sleep_satisfied`, `_resolved` | 1 | `SCHEDULE_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | `_sleep_satisfied` is a per-night latch and `_resolved` records that this hour's activity has been applied; both change what the next hour does. |
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
| Completed tick | -- | -- | -- | -- | 1 | §1 WORLD | `_completed_tick` is `World.tick` in §2's ledger and the save header's completed tick at offset 32. ARCH-SAVE-003 saves only a completed boundary, so this is the tick the whole file is stamped with, and the calendar is ALWAYS derived from it as `(tick + 4500) mod 18000` -- never stored separately, never `tick % 18000 == 0`. |
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

### `godot/scripts/core/transforms.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Current pose | `_x`, `_y`, `_z`, `_yaw` | 4 | `TRANSFORM_CAPACITY` = 87552 | An unbound row holds 0; `_bound_persistent_id == 0` is what marks it unbound | 1 | §4 COMPONENT_COLUMNS | int32 positions in 1/1024 m units, -Z forward, per AGENTS.md. ARCH-HASH-001 requires "current/previous authoritative Transform fields, not first-frame presentation overrides". |
| Previous pose | `_prev_x`, `_prev_y`, `_prev_z`, `_prev_yaw` | 4 | `TRANSFORM_CAPACITY` = 87552 | Same as the current pose | 1 | §4 COMPONENT_COLUMNS | The interpolation source for the render frame after a load. ARCH-SAVE-004 ends with "present previous=current", so the loader may collapse them -- but ARCH-HASH-001 hashes both, so the collapse must happen after the incoming digest is verified, not before. |
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
| World-generation scratch | -- | -- | -- | -- | 3 | -- | `_staged_centre_count`, `_staged_grove_count`, `_math`, `_measured` and `_foreign_kind`, all live only inside a generation pass. |


## 2026-09-11 follow-on ownership rulings

[SAVE-R09-001–005](rulings/2026-09-11_save_codec_contract.md) assigns proposed
owners for sections11/13/15, the section1 provenance prefix and version policy.
Those modules/fields are not asserted implemented by this registry. Their owners
must add rows and exact byte counts alongside implementation, including the
existing8-byte WorldRuntime event allocator moved to EventSchedule ownership,
without duplicate allocation/serialization. Existing generation spaces remain distinct.
STATE-COHORT-R01 corrects `_cohort_slots` above; the previous founder-history
interpretation is retained as superseded evidence in the dated ruling.
