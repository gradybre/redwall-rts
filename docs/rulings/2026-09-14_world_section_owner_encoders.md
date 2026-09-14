# R-WORLD-S1-001 — Section 1 owner membership, bounded wire contract, and scratch correction

Author ID: **R-WORLD-S1-001**  
Planning cycle: **Cycle1**  
Work item: **SAVE-S1-OWNERS**  
Disposition: **ADOPTED TARGET CONTRACT; EXECUTION AND INTEGRATED RECONCILIATION REQUIRED**  
Companion target manifest: [Cycle 1 WORLD target](../planning/astra_cycles/cycle_01_world_schema.json)

<a id="w2-section-1-owners-without-encoders"></a>

## 1. Decision and activation boundary

All seven previously unencoded section-1 owners MUST be encoded and semantically validated: `buildings`, `farming`, `forage`, `resource_nodes`, `spatial_world`, `weather`, and `world_init`. They join the existing `entity_directory` and `world_runtime` blocks. The target section has exactly nine required owners, including owners whose values are all their declared empty values. Missing blocks are not a permitted target-schema variant.

The three `resource_nodes` members `_deposit_tiles`, `_deposit_ref_slot`, and `_deposit_ref_generation` are reclassified as category-3 operation scratch. They MUST NOT contribute save payload or canonical field records after the coordinated implementation. The resource owner remains present and persists `_resource_slot`.

Adopt section-1 `resource_nodes.owner_schema_version=2` and section-1 `schema_version=3`. Other section-1 owner versions remain 1. This owner-version change is scoped to `(section_id=1, owner_key=resource_nodes)`; it does not automatically change another section's block owned by the same module. The rules identity MUST change with activation. Do not reinterpret older bytes under the new versions. Incompatible development saves are refused unless an explicit migration has been implemented and tested.

**Planner-cycle publication MUST NOT mutate the active canonical registry, source-classification registry, compiled runtime declarations, encoders, checker constants, or active rules identity.** Publish this ruling and the separate machine target manifest as planning artifacts. The executor activates all affected declarations and implementation together on the integrated working snapshot. A target manifest is not a replacement full registry and MUST NOT be imported by the active runtime before that integration.

This settles the archived inbox question `#w2-section-1-owners-without-encoders` (preserved in `docs/rulings/requests/open_items.json`). It does not report the encoders as implemented or the task's execution acceptance as passed.

## 2. Authority and inspected evidence

Read-only inspection followed [AGENTS](../../AGENTS.md), [REG-R01](2026-09-12_save_registry_answers.md), [SAVE-LAYOUT-R01](2026-09-12_clock_restore_and_layout_followup.md), and the fixed-header/section-table contract in [SAVE-R09](2026-09-11_save_codec_contract.md). Canonical schema inspection was restricted to section 1, its referenced source contracts, and root provenance/count/version metadata. Other sections were consulted through source references only where needed for cross-check obligations; this is not a full registry audit.

Evidence is the working snapshot at `/Users/brendan/Developer/redwall-rts`, not a clean checkout of HEAD. HEAD was `3e094e927c822056b51953aac4168b77acdee814`; it predates substantial staged implementation. The snapshot contained 247 staged additions and 83 staged modifications (330 files), zero tracked unstaged modifications, and five untracked entries. Inspected fingerprinted files matched their index versions. Untracked entries and the staged snapshot were preserved.

Observed active canonical artifact SHA-256: `1201b8a88a296dfd5273c063066fefd03000a70018aa95f6fdd65ba8272eb768`. Its root metadata reports 582 canonical records, 536 persisted packed-source fields, 50 owner groups, section-1 version 2, and `release_save_ready=false`. These are observations of that artifact, not proof that it reconciles with live source.

REG-R01 already forbids omission of implemented state and retains the other section-1 owners. The current two-owner encoder is an explicitly incomplete development composition, not an alternative valid implementation of this target. Its source comments about other owners do not override the actual section-1 field membership; for example, `crop_weather` state is not added to section 1 by this ruling.

The [foreign-weather fixture](../../godot/test/test_save_section_world_runtime.gd) deliberately supplies weather owner schema 3, primary_count 512, and a four-byte payload. The current helper measures and preserves those extents without interpreting weather. That fixture proves wrapper walking and dispatch bookkeeping, not weather correctness. `missing_owner_keys()` becoming empty proves key presence only. A target decoder MUST run all nine owner validators and the required cross-owner checks; count/order/CRC/digest agreement alone cannot substitute for them.

## 3. Adopted section framing and primary counts

The uncompressed section uses little-endian integers, no implicit alignment, and no padding except the existing three explicit runtime reserved bytes.

| Section-relative offset | Prefix item | Width |
|---:|---|---:|
| 0 | scenario_version:u32 | 4 |
| 4 | effective_seed:i32 | 4 |
| 8 | map_generator_schema:u32 | 4 |
| 12 | authored_map_digest:raw bytes | 32 |
| 44 | store_count:u32, exactly 9 | 4 |
| 48 | first owner wrapper | variable by exact key length |

Retain existing provenance semantics. This ruling does not invent a scenario version, map-generator schema value, or authored-map digest, or declare all-zero provenance valid. The respective producer must supply values compatible with the integrated build.

Each wrapper is:

```text
owner_key_byte_count:u32
owner_key: exactly that many nonempty ASCII bytes
owner_schema_version:u32
primary_count:u64
payload_byte_length:u64
payload: exactly payload_byte_length bytes
```

Keys are the exact required keys below, in strict ASCII order. A wrapper occupies `24 + len(owner_key)` bytes. No duplicate, unknown, out-of-order, or missing owner is accepted. Blocks tile the entire section after its prefix/count, without gaps, overlap, or trailing bytes.

The seven new owners use this ordinary payload form:

```text
for each field in declared ordinal order:
    element_count:u64
    values: exactly element_count * declared_type_width bytes
```

Every scalar in an ordinary payload has an explicit `element_count=1`. There is no payload field-count word, no repeated field name/type, no array-length inferred from remaining bytes, and no extra child-table header. Count prefixes are structural bytes, not additional canonical field records. Each column uses ascending physical index; tile index is `z*128+x`, cell index is `z*512+x`. Weather column indices and basin indices retain their explicit owner-defined order.

Adopt grid-oriented primary counts for mixed owners: `world_init` counts 16,384 exterior tiles despite its scalar/seven-basin fields; `spatial_world` counts 262,144 cells despite its revision scalar. Weather counts one aggregate row despite eight i32 and two i64 values. The element-count table independently fixes every field extent. Do not infer primary_count from the first field, a live count, the sum of child extents, or the descriptor's row_count. Singleton primary counts for the mixed grids and unframed raw-array payloads are rejected alternatives.

| Owner, ASCII order | Owner schema | primary_count | Wrapper bytes | Payload bytes |
|---|---:|---:|---:|---:|
| `buildings` | 1 | 16,384 | 33 | 196,632 |
| `entity_directory` | 1 | 1 | 40 | 4 |
| `farming` | 1 | 16,384 | 31 | 737,360 |
| `forage` | 1 | 16,384 | 30 | 65,544 |
| `resource_nodes` | 2 | 16,384 | 38 | 65,544 |
| `spatial_world` | 1 | 262,144 | 37 | 2,621,484 |
| `weather` | 1 | 1 | 31 | 64 |
| `world_init` | 1 | 16,384 | 34 | 65,697 |
| `world_runtime` | 1 | 1 | 37 | 80 |

The descriptor row_count is the checked sum of block primary_count values: **344,067**. It is not population, unique entities, field count, or canonical record count.

## 4. Exact target field schemas

The following tables are exhaustive. Offsets are relative to the start of each owner's payload; every ordinary field's value bytes immediately follow its eight-byte count prefix. Type codes are u8=0, u32=1, i32=2, u64=3, i64=4. The manifest retains source binding, type code, hash membership, and offsets for independent verification.

### buildings — schema 1, payload 196,632 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_building_slot` | i32 | 16,384 | 0 | 8 |
| 1 | `_room_slot` | i32 | 16,384 | 65,544 | 65,552 |
| 2 | `_furniture_slot` | i32 | 16,384 | 131,088 | 131,096 |

### farming — schema 1, payload 737,360 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_tile_fertility` | i32 | 16,384 | 0 | 8 |
| 1 | `_tile_last_family` | i32 | 16,384 | 65,544 | 65,552 |
| 2 | `_tile_family_streak` | i32 | 16,384 | 131,088 | 131,096 |
| 3 | `_tile_last_legume_day` | i32 | 16,384 | 196,632 | 196,640 |
| 4 | `_tile_compost_season` | i32 | 16,384 | 262,176 | 262,184 |
| 5 | `_tile_active_plot_row` | i32 | 16,384 | 327,720 | 327,728 |
| 6 | `_tile_orchard_row` | i32 | 16,384 | 393,264 | 393,272 |
| 7 | `_tile_ripe_tick` | i64 | 16,384 | 458,808 | 458,816 |
| 8 | `_tile_growth_remainder` | i64 | 16,384 | 589,888 | 589,896 |
| 9 | `_tile_tended_today` | u8 | 16,384 | 720,968 | 720,976 |

### forage — schema 1, payload 65,544 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_tile_link_head` | i32 | 16,384 | 0 | 8 |

### resource_nodes — schema 2, payload 65,544 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_resource_slot` | i32 | 16,384 | 0 | 8 |

### spatial_world — schema 1, payload 2,621,484 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_map_revision` | i32 | 1 | 0 | 8 |
| 1 | `_walkable` | u8 | 262,144 | 12 | 20 |
| 2 | `_layer` | u8 | 262,144 | 262,164 | 262,172 |
| 3 | `_terrain` | i32 | 262,144 | 524,316 | 524,324 |
| 4 | `_height_units` | i32 | 262,144 | 1,572,900 | 1,572,908 |

### weather — schema 1, payload 64 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_row` | i32 | 8 | 0 | 8 |
| 1 | `_row64` | i64 | 2 | 40 | 48 |

### world_init — schema 1, payload 65,697 bytes

| Ordinal | Exact field key | Type | element_count | Count offset | Values offset |
|---:|---|---|---:|---:|---:|
| 0 | `_published` | u8 | 1 | 0 | 8 |
| 1 | `_published_seed` | i32 | 1 | 9 | 17 |
| 2 | `_terrain` | u8 | 16,384 | 21 | 29 |
| 3 | `_soil` | u8 | 16,384 | 16,413 | 16,421 |
| 4 | `_basin` | u8 | 16,384 | 32,805 | 32,813 |
| 5 | `_cleared` | u8 | 16,384 | 49,197 | 49,205 |
| 6 | `_basin_ref_slot` | i32 | 7 | 65,589 | 65,597 |
| 7 | `_basin_ref_generation` | i32 | 7 | 65,625 | 65,633 |
| 8 | `_basin_danger` | i32 | 7 | 65,661 | 65,669 |

### Existing fixed-format exceptions

`entity_directory` remains schema 1, primary_count 1, payload four bytes: `_next_persistent_id:u32` at offset 0. There is no element-count prefix inside this fixed payload.

`world_runtime` remains schema 1, primary_count 1, payload 80 bytes, without element-count prefixes:

| Offset | Item | Type/width |
|---:|---|---|
| 0 | _completed_tick | i64 |
| 8 | _world_seed | i32 |
| 12 | _seeded | u8 |
| 13 | reserved_zero | 3 bytes, all zero |
| 16 | _requested_speed | i32 |
| 20 | _pause_mask | i32 |
| 24 | _debt | i64 |
| 32 | _fallback_count | i64 |
| 40 | _diagnostic_pause_count | i64 |
| 48 | _acknowledged_catchup_resets | i64 |
| 56 | _acknowledged_ticks_discarded | i64 |
| 64 | _subtick_debt_discards | i64 |
| 72 | _day_boundaries_crossed | i64 |

These are twelve stored fields plus reserved bytes. Only `_world_seed`, `_seeded`, `_requested_speed`, and `_pause_mask` produce this owner's canonical field records. Completed tick is in the canonical stream prefix exactly once. Debt and six counters are persisted and protected by body digest/CRC but excluded from the canonical state hash. Do not append the legacy 21-byte helper contribution.

## 5. Common encoder, decoder, and restore obligations

Each new owner MUST provide bounded capture/encode, decode-to-staging, semantic validation, a canonical value adapter, and a restore/publication path owned by the integrated loader. The same exact field extents and normalization MUST govern save and canonical values. The concrete API naming is executor-owned; it must not obscure these separate responsibilities.

- Validate source column sizes before encoding. Validate exact schema, primary_count, payload length, each field count, and checked count-times-width before allocating or consuming untrusted extents. For this fixed target, differing counts are refusals, not allocation requests.
- Prove reads remain within both the owner payload and enclosing section, using checked/subtraction-based bounds. Require exact payload consumption and section EOF. Reject integer overflow, truncation, trailing bytes, and unsupported versions.
- A count or type mismatch is never repaired by resizing, truncation, coercion, sign reinterpretation outside the codec's explicit type contract, or filling omitted columns.
- Flags accept only 0 or 1. A null EntityRef is exactly `(slot=-1,generation=0)`. Non-null references require the target directory's live generation, expected entity kind, correct typed row, and matching component identity. Reject half-null and stale references; do not coerce them to null. Bare typed rows and arena indices are not EntityRefs and must be checked in their own namespaces.
- Preserve declared sentinels and genuine historical state. `-1`, zero, and byte value 255 have different field-specific meanings. Never blanket-zero a full tile/cell grid because an entity row is absent. Encode no fictional scratch placeholders.
- Validate local domains first and cross-owner relationships against decoded staging stores before publishing any of the affected state. Persisted inverse maps are cross-checked in both directions, not arbitrated by choosing whichever copy looks plausible.
- Restore under the existing unpublished load barrier, preserving the prior live world on failure. Do not publish these owners through gameplay creation/destruction, allocation, clearing, weather selection, or other side-effectful mutators. Rebuild only declared derived data from the accepted stored state.
- Snapshot at an established quiescent save boundary. The deposit scratch reclassification does not authorize saving midway through a placement/reservation operation or serializing pending scratch as a substitute for a transaction boundary.

## 6. Owner semantic validators

Numeric bounds below are the baseline target's wire/domain rules. They do not certify current source mutators or cross-owner maintenance. When an integrated source change alters a domain, re-audit and version the affected contract rather than silently extending these validators.

### S1-BUILDINGS

All three grids contain `-1` for no occupant. Otherwise `_building_slot` is a typed row in 0..1023, `_room_slot` in 0..16383, and `_furniture_slot` in 0..81919. Require the corresponding occupied component row and its valid directory identity.

Cross-check every live building's entire rotated footprint against its grid, every live room's saved tile run against the room grid, and every floor-furniture footprint against the furniture grid. Reject missing mappings, stray mappings, wrong rows, overlaps inconsistent with the owning store, and invalid run/footprint extents. Merely checking an origin tile is insufficient. Edge furniture has a zero floor footprint and must not be required to claim a floor tile. Source: [buildings footprints](../../godot/scripts/core/buildings.gd), [furniture footprint rule](../../godot/scripts/core/buildings.gd).

### S1-FARMING

- Fertility is 0..10000. Last family is -1 or a compiled family ID 0..4. Streak is 0..2147483647; family=-1 requires streak=0, and any real family requires streak>=1. Use the owner's `is_history_pair_consistent` semantics.
- Last-legume day is 0..2147483647; zero means never. Compost season is -1..2147483647; -1 means no compost season. These are absolute history values, not cyclic season ordinals, and are not reset during load.
- Active-plot row is -1 or 0..4095. Orchard row is -1 or 0..1023. Cross-check each non-null row's presence, identity, and tile/footprint; cross-check the reverse mapping of all live affected plots/orchards. Do not convert these typed rows into directory-slot values.
- Ripe tick is -1 or a nonnegative representable i64 absolute tick. Growth remainder is 0..999999, matching the stored modulo-1000000 arithmetic. Tended-today is 0/1. Do not introduce a new chronological equality with the load-time clock or run rollover to force one; any scheduler-phase checks must use the already established completed-boundary/latch contract.
- Cross-check active plots' mirrored fertility and family/streak values against the tile history. Validate any other stored mirror only using its declared semantics; a season-dependent derived mirror is not a direct historical equality.

The [destroy operation](../../godot/scripts/core/farming.gd) explicitly preserves tile history, including ripe tick, growth remainder, and tending. A tile without an active plot can therefore retain those values; absence is not permission to normalize them away.

**Source maintenance gap:** `_tile_orchard_row` is allocated, initialized to -1, and read, but the inspected scripts contain no population writer. The target retains this registered field. Executor integration MUST establish and verify its intended live-orchard inverse maintenance before claiming the reverse check passes. Do not quietly accept an all--1 map beside live orchards or reconstruct over a contradictory incoming map. This is a maintenance prerequisite, not an extra registry-field addition or an excuse to remove the field.

### S1-FORAGE

Each tile head is -1 or an arena index 0..16383. Cross-check the saved link arena and zone rows: allocated link membership; matching `_link_tile`; live valid owning zone; legal next indices; no cycles; and agreement between the zone chains and tile chains, including their membership counts. Bound traversal by the 16,384-entry arena and reject unreachable allocated links or links assigned to inconsistent tiles/zones under the owning arena schema. Free-list membership must not be treated as live linkage.

Preserve saved head and next-link order. Equal set membership is not permission to reorder a chain. The [source inserts at each tile head](../../godot/scripts/core/forage.gd), so sorting on load would change the stored traversal. Do not reinterpret a head as a zone row or directory reference.

### S1-RESOURCE_NODES

The sole target field is `_resource_slot`. Each value is -1 or a typed resource-node row 0..4095. Cross-check every occupied tile with the live component row, its valid ResourceNode directory identity, and its `_tile` value; every live node mapped by the component must have the matching inverse entry. Reject duplicates, missing inverses, stale identities, and out-of-grid component tiles. Do not reject a present exhausted node simply because quantity is zero.

The removed deposit arrays have no target wire representation, count prefixes, null normalization, or canonical adapters. They remain ordinary owner-managed scratch storage if still needed by placement. Their old contents are irrelevant to target save/hash values; this does not erase genuine directory/component changes caused by a reservation operation.

### S1-SPATIAL_WORLD

Revision is 1..2147483647 in the inspected baseline; do not silently widen it to i64. `_walkable` is 0/1, `_layer` is exactly zero, `_terrain` is a baseline terrain ID 0..3, and `_height_units` is a signed i32 in 1/1024 m units. Every one of the 262,144 cells is represented, including blocked cells.

Restore the stored columns, then rebuild `_walkable_count` and clearance using those columns. Do not invoke a whole-map authored-terrain rebuild that overwrites stored legality. [override_static_legality](../../godot/scripts/core/spatial_world.gd) legitimately changes walkability and increments revision; equality to initial authored walkability is not a valid universal load check. Validate revision dependencies in other owners according to their saved invalidation semantics; a deliberately stale route/cache is not automatically a corrupt map.

This baseline does not close MOVE-G02/G03, implement multi-floor movement, or override the higher-level movement direction. A later wider revision, terrain domain, or layer model requires explicit reconciliation and versioning.

### S1-WEATHER

The i32 row has exactly these indices: 0 event, 1 start_day, 2 duration_days, 3 temperature_tenths, 4 rain, 5 forecast_event, 6 forecast_start_day, 7 forecast_duration_days. The i64 row has index 0 scheduled_absolute_season and index 1 forecast_absolute_season. These are two packed arrays in one aggregate; eight i32 values are not eight weather entities.

Event IDs are -1 (none) or 0..6 in compiled order: blight, calm_days, drought, early_frost, hard_freeze, heavy_rain, ideal_spell. Present tuples must match start days `[6,6,6,10,6,6,6]` and durations `[3,2,4,2,3,2,3]`. Absent event/forecast tuples are exactly `(-1,0,0)`. Each absolute-season identity is -1 or a nonnegative i64. A present event or disclosed forecast requires its corresponding non-null identity and eligibility in identity modulo 4. Compile these checks from the authoritative catalog/owner constants, not independently maintained numerical copies.

Validate stored temperature/rain as signed i32 values with the baseline reachable outer bounds temperature -120..300 and rain 0..3200 (derived from the inspected season/effect tables). These bounds alone are not an event-state parity proof. If checking the exact day's derived pair, use the existing orchestration phase/latch contract; do not refresh or overwrite a saved row to match the clock.

Event expiry retains the scheduled-once season identity and can retain a disclosed forecast. Never force the scheduled identity to -1 merely because event=-1, erase a historical forecast, infer missing identities from event eligibility, or draw/reseed WEATHER during decode. Cleared fixture state has absent tuples, zero temperature/rain, and both identities -1. Do not promote that fixture into valid initialized gameplay weather merely because its bytes pass local bounds.

The registered section-1 owner schema remains 1. [weather.gd's SCHEMA_VERSION=2](../../godot/scripts/core/weather.gd) is its separate snapshot-identity version, reflecting the required two i64 values; it is not the owner wrapper version. The existing identity validator rejects ambiguous legacy snapshots. These version namespaces must not be conflated.

### S1-WORLD_INIT

`_published` and each `_cleared` value are 0/1. `_published_seed` is signed i32. Per-tile terrain is 0..3, soil is 0..2 or 255 (no soil), and basin is 0..6 or 255 (no basin). Basin danger is 0..3. Byte value 255 is a declared sentinel, not signed -1 encoded through an unchecked conversion.

For unpublished fixture state, enforce the source's explicit reset values: published=false, seed=0, terrain=LAND (3) throughout, soil=255, basin=255, cleared=0, all seven references=(-1,0), and all seven dangers=0. This is an explicit empty state, not a claim that a partially built map can be saved.

For published state, require all seven basin identities, distinct and generation-checked through the directory into live HarvestZone rows. Indices 0..3 designate the four forage basins; indices 4..6 designate fish coast/lake/river in compiled HabitatType order. Check the referenced rows are the intended basin owners (not player designations), appropriate forage/fish type, and agree with the stored basin danger. Every non-sentinel tile basin index must resolve through that table. Check the relevant fish-habitat bindings using the fishing owner's identity rules before publication.

Require published seed agreement with the provenance effective seed and runtime world seed, and a seeded runtime for a published world. Retain the signed-i32 seed domain; do not invent positivity at this boundary. Exact authored-map/danger-generation provenance belongs to its producer and compatible rules identity, not to a guessed reconstruction during load. Source: [reset state](../../godot/scripts/core/world_init.gd), [basin publication](../../godot/scripts/core/world_init.gd).

### Existing directory/runtime checks retained

Directory cursor is 1..2147483648 inclusive and exceeds every positive stored directory persistent ID. The upper value is the exhausted allocator, not a live signed-i32 ID. Preserve the cursor through destruction of all entities; do not derive max(live IDs)+1. Restore it with section 3 under the same barrier.

Runtime retains its existing speed domain {0,1,2,4}, known logical pause-bit mask, seeded flag 0/1, zero reserved bytes, tick range 0..INT64_MAX-4500, and debt/counter ranges 0..INT64_MAX. Header completed tick must agree. Preserve debt and counters exactly, and use the out-of-band load barrier without rewriting the saved logical pause mask. No new arbitrary debt ceiling is adopted here.

## 7. Why the resource scratch correction is required

The [source declares the three arrays as scratch](../../godot/scripts/core/resource_nodes.gd). They describe one placement in progress, not an enduring registry of all deposits. `_refuse_deposit()` writes the footprint before later field/occupancy validation; `_reserve_deposit_rows()` stores temporary references; partial rollback destroys those references without clearing the arrays. Newly allocated scratch may also contain default zeros, and later node destruction can make old reservation references stale.

The persistence prose and canonical C007 declarations instead describe committed world-generation output. That interpretation is contradicted by the actual lifecycle. Persisting the arrays would make scratch from a failed operation part of save/hash state, and a strict live-reference check could reject legitimate later state.

This ruling resolves that conflict by reclassification, not by inventing a deposit ledger, accepting stale live references, or fabricating three null-filled saved arrays. The executor updates the prose/classification row, removes exactly these three section-1 canonical fields, and changes the version/identity with the implementation. Other resource-node fields and other owner groups remain untouched by this narrow removal.

## 8. Exact sizes, offsets, and canonical counts

For the adopted target: the seven ordinary payloads contain 31 field-count prefixes (248 bytes). All nine payloads total 3,752,409 bytes; all nine wrappers total 311 bytes. Therefore:

```text
section_1_length = 44 + 4 + 311 + 3,752,409 = 3,752,768 bytes
first_section_offset = 256 + 15*64 = 1,216
section_2_offset = 1,216 + 3,752,768 = 3,753,984
section_1_descriptor_row_count = 344,067
```

| Owner | Block offset in section | Payload offset in section | End offset, exclusive |
|---|---:|---:|---:|
| `buildings` | 48 | 81 | 196,713 |
| `entity_directory` | 196,713 | 196,753 | 196,757 |
| `farming` | 196,757 | 196,788 | 934,148 |
| `forage` | 934,148 | 934,178 | 999,722 |
| `resource_nodes` | 999,722 | 999,760 | 1,065,304 |
| `spatial_world` | 1,065,304 | 1,065,341 | 3,686,825 |
| `weather` | 3,686,825 | 3,686,856 | 3,686,920 |
| `world_init` | 3,686,920 | 3,686,954 | 3,752,651 |
| `world_runtime` | 3,752,651 | 3,752,688 | 3,752,768 |

Removing three i32[16] fields removes `3*(8+16*4)=216` bytes. The hypothetical full encoding of the old declared fields would be 3,752,984 bytes and put section 2 at 3,754,200; those are comparison values, not the adopted target.

The target section has 44 declared stored fields and 36 canonical field records, down from the observed section's 47 and 39. There are nine owners before and after this correction. Primary counts are unchanged by scratch removal. These S1 totals are derived from the exact target in this ruling; if integration changes any S1 fields/extents, they require a revised target rather than silent arithmetic drift.

**Missing encoders never blocked first-body-offset 1,216.** The header/table already fixes it independently of payloads. Missing encoders block complete section lengths, subsequent section offsets, and correct complete body/canonical digest production. OPEN W2's impact text must make that distinction when the executor/integration owner updates the request record. CRC and body digest must be produced from actual complete bytes, not these arithmetic tables or the target manifest's JSON hash.

## 9. Active-registry drift and mandatory atomic reconciliation

Read-only checks were reproduced against this working snapshot:

| Check | Observed result | Evidence scope |
|---|---|---|
| `python3 -B docs/validation/validate_save_registry_handoff.py --source-root .` | FAIL, exit 1: 17 added construction category-1 fields absent from canonical; missing set empty | Registry structure/31 independent primitive fixtures are insufficient; source/canonical membership gate fails |
| Nested `state_registry_coverage` | PASS: 52 modules, 350 rows, 681 packed columns checked | Source classification coverage, not canonical reconciliation or semantic save validation |
| `python3 -B docs/validation/decision_numbers.py` | FAIL, exit 1: duplicate 0090, 0091, 0092; 128 records, 3 problems | Pre-existing decision-number integration problems, unchanged by this ruling |

The 17 construction fields reported as added are:

```text
_assigned_count
_delivered_milli
_material_container_generation
_material_container_slot
_max_workers
_paused
_phase
_present
_purpose
_ref_generation
_ref_slot
_refund_policy
_remaining_mwu
_subject_generation
_subject_slot
_type_id
_work_begun
```

**582→579 canonical records and 536→533 packed fields are ONLY the local subtract-three arithmetic on the observed active artifact, before mandatory construction reconciliation. They MUST NOT be asserted or pinned as final integrated global totals.** The construction fields and any newer implemented state MUST be reconciled under REG-R01. This ruling does not assign construction's full schema/ordinals or assume that those 17 packed fields exhaust all missing scalar or concurrent state. Recompute final totals from the reconciled declarations and source; do not substitute an unreviewed add-17 shortcut for that audit.

The executor must perform one coordinated activation on the integrated working base:

1. Re-read active AGENTS/authority changes, re-audit S1 membership/counts/source hashes and all newly implemented state, including the 17 construction fields. Resolve concurrent changes rather than resetting to old HEAD or copying old global totals.
2. Implement the seven codecs/adapters and loader validation/publication paths, including required source maintenance such as the orchard inverse. Preserve existing directory/runtime framing and behavior.
3. Reclassify the three deposit fields in the source-classification prose/metadata and remove their canonical records. Reconcile construction and any newer state in their appropriate sections under REG-R01.
4. Update the active canonical registry, source contracts/provenance as appropriate, section/owner versions, compiled canonical tables, rules identity inputs, and source/value adapters in the same integrated change. Remove C007 only if no reconciled declaration still references it.
5. Update dependent checkers/constants/fixtures from the reconciled data. Known sites include `docs/validation/validate_save_registry_handoff.py` (582/536 pins), `godot/scripts/core/canonical_state_hash.gd` (record count and compiled arrays), `godot/test/test_canonical_state_hash.gd` (packed count and declaration fixtures), and section-1 composition constants/tests. Audit all dependent consumers, not only these named sites. The comment referencing `tools/generate_canonical_state_table.py` names a file absent from the inspected tree; locate or provide a reproducible table-maintenance path rather than claiming that generator ran.
6. Run the source-aware registry checker on the integrated base, plus appropriate encoding, validation, restore, hash, and continuation checks. Source classification PASS alone does not waive canonical drift. The Cycle 1 queued source-checking gate owns integration follow-through; keep the pre-existing duplicate-number failures visible for their integration owner.

No planner artifact shall create a period where the active registry says scratch has been removed while old runtime tables/checkers still describe it, or where new source owners remain omitted solely to preserve a historical count. Atomic here means one coherent implementation/declaration/validation activation; it is not an instruction to commit or publish from this planning task.

## 10. Executor acceptance evidence

Required focused evidence, to be run after implementation:

- Pin complete section bytes, each owner payload/count offset, the two fixed exceptions, descriptor count, first offset 1,216, target section length, and subsequent-offset arithmetic. Verify exact-nine-owner ordering and versions.
- Reject missing/unknown/duplicate/reordered owners; arbitrary-weather fixture values; unsupported schemas; primary/element count mismatches; overflow; truncated headers/fields; payload length mismatches; nonzero reserved bytes; and trailing bytes. Every failure must leave live state unpublished and unchanged.
- Round-trip all seven owners with non-default data and boundary sentinels, including full tile/cell extents, null/non-null references, extreme valid typed rows, zero/one flags, and preserved histories on tiles with no live plot.
- Exercise building/furniture rotated footprints and edge furniture, room tile runs, plot and orchard inverse maintenance, resource inverse mismatches, forage chain cycles/free-list confusion, stale generations, wrong kinds, and half-null references.
- Preserve changed static legality and rebuild only derived clearance/counts. Cover weather before/after expiry and forecast disclosure without extra RNG draws; cover an exact day/season boundary using the existing orchestration-latch contract rather than assuming load-time refresh.
- Verify the three scratch fields produce no target payload or canonical field records. Changing only those scratch contents must not change target serialization/hash. A failed placement test must distinguish ignored scratch from genuine allocator/generation/cursor changes; do not assert that every failed placement leaves the entire world hash unchanged.
- Verify directory cursor persistence after destroying the highest ID and all entities, including exhausted cursor bytes `00000080`, and rejection of stale/invalid cursors. Verify exact runtime debt/counter restoration and canonical exclusion.
- Compare uninterrupted and restored continuation at the supported completed save boundaries, with matching canonical values and relevant RNG/allocator behavior. A round-trip byte match alone is insufficient evidence of future-state correctness.
- Require source/canonical membership and types to reconcile on the actual integration base, with final counts derived there. Recompute source fingerprints after implementation and report changed scope.

These are acceptance obligations, not claims of completed tests. Only the read-only Python results in section 9 and static target arithmetic were checked during this planning task. No Godot encoder, transactional restore, continuation parity, complete rules/lookup manifest, or release-save readiness was certified.

## 11. Machine target manifest and exclusions

The companion JSON is `R-WORLD-S1-001-TARGET-1`, explicitly marked `PLANNING_TARGET_NOT_ACTIVE_REGISTRY`. It contains the exact nine S1 owner targets, retained canonical ordinals/type codes/source bindings, numeric element counts, count/value offsets, primary counts, derived lengths, local registry removals/version changes, the known construction reconciliation requirement, read-only check outcomes, and per-file working-source SHA-256 fingerprints. It is suitable for independent comparison; it is not an instruction to load this file as the active canonical registry.

The manifest deliberately presents 579/533 only under snapshot-specific subtract-three expectations with a warning. It publishes no final integrated global count. Re-audit counts and source hashes at implementation even if HEAD has not changed: a staged/unstaged integration snapshot can change without a new commit.

This ruling excludes resident spawning and resident-state design (INIT-POSE-R01 owns that lane), construction gameplay/schema authorship, repairs to pre-existing duplicate ADR numbers, complete encoders for other sections, full save/load orchestration beyond the S1 integration obligations, map/scenario digest producers, release certification, additional movement domains/layers, and new gameplay state. Cross-checks against other owners are validation requirements, not authorization to redesign or duplicate their stores.

The ruling and companion target are stored in the repository by the Cycle 1 lead. The architectural auditor performed read-only source review and temporary drafting; no active registry/runtime changes are made by this planning publication. See the Cycle 1 report for the lead’s separate GitHub metadata audit and baseline run.

Selected-source aggregate SHA-256 (algorithm and constituent files are in the manifest): `87bf5357b1862fa6782c217904af8dc59048b5ac74e8e82f4cb1fc69ccfcdaec`.
