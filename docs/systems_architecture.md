---DOC:systems_architecture.md---

# Settlement Systems Architecture

**Adopted movement amendment:** [SET-MOVE-001](movement_direction_amendment.md) implements DEC-035 at the direction/specification level. Its requirements supersede ground-only and one-floor claims as the complete settlement design. `settlement_rules_v2` remains the incomplete implementation baseline; MOVE-G01–05 identify exact engineering closure still required.

Specification `SET-ARCH-001`, revision 1.1; authored 2026-09-05. This document targets the settlement in `/Users/brendan/Developer/redwall-rts/godot`, using the authoritative GDD registry. It is an execution contract, not a Windows qualification result. Existing engine version was read as `4.7.2.stable.official.ed1daf0bf`; no source implementation is changed by this document.

Ruleset v2 is reconciled with [setting_rules_amendment.md](setting_rules_amendment.md). FaunaStock allocation and the HUNTING RNG domain remain inactive reserved storage; skill index 3 and zone index 1 are reserved holes. Candidate origin is derived from immutable per-scenario admission data and existing saved columns, so the conservative allocation totals remain unchanged.

## 1. Authority, boundaries, and implementation decisions

**ARCH-AUTH-001.** The implementation SHALL preserve every field, type, enum value, cardinality, and requirement in `[GDD §4.1–4.3]`. `[GDD §x]`, `[UI §x]`, and `[crowd §x]` identify inherited constraints. `[NEW]` identifies architecture decisions; `[DERIVED]` identifies arithmetic from cited operands. An entire table's stated provenance applies to all its values unless a row overrides it. Additional bookkeeping tables are explicitly distinguished from the fixed registry; they do not delete or reinterpret its fields.

**ARCH-AUTH-002.** Authoritative storage SHALL use signed 32-bit/64-bit packed columns and byte flags, with 64-bit integer intermediate arithmetic. Booleans occupy one byte and contain only 0/1. `StringName` catalog references compile to int32 IDs; `EntityRef` is two int32 columns `(slot,generation)`, null `(-1,0)`. Positions are 1/1024 m, +Y up and −Z forward; yaw is 65536 units/turn. No live Node reference, Resource instance, physics query, GPU result, or UI selection is authoritative identity. `[GDD §4.1–4.3; crowd §4.1–4.2]`

**ARCH-AUTH-003.** Use `floor_div` for nonnegative division, `ceil_div(a,b)=(a+b-1)//b`, and signed `trunc_div(a,b)=sign(a)*floor_div(abs(a),b)`. All denominators must be positive. Persist remainders instead of repeatedly discarding sub-unit rates. Calculate bounds in int64 before narrowing to int32; on overflow refuse the command or stop the tick transaction with a diagnostic. `[GDD §4.1, §5.2; NEW helper names/error boundary]`

**ARCH-SCOPE-001.** Allocate 512 resident rows and admit at most 256 living residents `[GDD §4.1]`. Keep the battle store's 2048 model slots separate `[crowd §0.1, §4.1]`. A settlement entity slot is not a battle slot, render instance index, job row, or persistent creature ID. The two layers share integer conventions and replay principles, not component layouts, speed policy, map bounds, or a common allocator.

**ARCH-SCOPE-002.** Keep settlement simulation single-threaded in typed GDScript initially `[NEW]`. Systems are a fixed set of `RefCounted` services operating on borrowed store columns; they do not instantiate an object per resident or dispatch a virtual component method per row. Native escalation moves an entire measured kernel with identical integer input/output and replay fixtures. No worker publishes state according to wall-clock completion. `[crowd §4.1, §6.1, §10.3; GDD §5.11 REQ-SET-162–164]`

*Rationale: deterministic ownership and explicit data flow are more valuable here than a general-purpose entity framework.*

## 2. Packed schema and memory accounting

**ARCH-MEM-001.** In the tables, I32=`PackedInt32Array` at 4 bytes/element, I64=`PackedInt64Array` at 8, B8=`PackedByteArray` at 1 `[GDD §4.2; Godot packed-array types]`. A comma-separated field group expands into separate contiguous columns of the stated length. Fixed children use the stated flattened owner-major indexing; variable children use packed arenas plus explicit offset/count indices. Do not allocate a GDScript `Array` for each row. Payload totals exclude allocator/object headers, which receive a separate measured reserve.

**ARCH-MEM-002.** **BASELINE-ONLY under SET-MOVE-001:** these bounds and all downstream directory, transform, payload and save-memory totals do not cover required multi-level space. Recompute them under MOVE-G02; do not multiply by an invented floor count. Fixed registry cardinalities below remain mandatory for the existing baseline. The remaining finite bounds below are geometric/conservation bounds, not new arbitrary gameplay caps `[DERIVED from GDD §5.1, §5.9]`: the map has 16384 exterior tiles and only one managed floor, so all interior floor furniture occupies at most 16384 floor tiles. Each tile has at most 4 edges; an edge holds at most one partition/door `[NEW explicit edge exclusivity consistent with no overlap]`. A conservative furniture bound is `16384+4*16384=81920`. Projects ≤81920 furniture+1024 exterior objects=82944. Interior rooms ≤16*1024=16384. Main containers ≤1024 building+512 satchel+82944 project+512 expedition+16384 nonempty ground-pile containers=101376. Empty orphan containers are reclaimed at lifecycle commit; a ground pile with no live lot cannot retain an occupied row `[NEW lifecycle rule]`.

**ARCH-MEM-003.** Relations retain at most degree 8 among the 512 resident slots, so undirected live edges ≤512*8/2=2048. Preserve historical relationships in ChronicleRecord before retiring their live edge. Expedited parties cannot exceed 512 rows because each consumes at least one resident slot; the living limit usually makes the real bound smaller. Orchard blocks ≤16384/16=1024. Use the more conservative capacities even when geometric/resource constraints prevent all maxima occurring simultaneously. `[GDD §4.2, §5.3, §5.6; DERIVED]`

**ARCH-MEM-004.** ChronicleRecord has no finite total record cap `[GDD §4.2]`. Store it in an append-only disk stream included in every logical save; keep two 64-record pages in RAM, for `2*64*24=3072` payload bytes `[NEW two-page cache; GDD 64-row presentation page]`. One page is immutable while UI reads it. A page flush must complete before reusing that page; an I/O failure pauses at a committed tick and keeps the unflushed page. This bounds RAM without deleting history. Never assert a finite total save-file size merely because the live ECS is bounded.

### 2.1 Global referenceable entity directory

| Kind | Maximum rows | Provenance |
|---|---|---|
| world | 1 | [GDD §4.2; derived bounds §2] |
| resident | 512 | [GDD §4.2; derived bounds §2] |
| building | 1024 | [GDD §4.2; derived bounds §2] |
| room | 16384 | [GDD §4.2; derived bounds §2] |
| furniture | 81920 | [GDD §4.2; derived bounds §2] |
| construction | 82944 | [GDD §4.2; derived bounds §2] |
| inventory_container | 101376 | [GDD §4.2; derived bounds §2] |
| inventory_lot | 16384 | [GDD §4.2; derived bounds §2] |
| job | 8192 | [GDD §4.2; derived bounds §2] |
| fish_habitat | 32 | [GDD §4.2; derived bounds §2] |
| harvest_zone | 128 | [GDD §4.2; derived bounds §2] |
| resource_node | 4096 | [GDD §4.2; derived bounds §2] |
| expedition | 512 | [GDD §4.2; derived bounds §2] |
| farm_plot | 4096 | [GDD §4.2; derived bounds §2] |
| orchard_plot | 1024 | [GDD §4.2; derived bounds §2] |
| hive | 1024 | [GDD §4.2; derived bounds §2] |
| production_order | 32768 | [GDD §4.2; derived bounds §2] |
| feast | 1 | [GDD §4.2; derived bounds §2] |

Directory length G=352418, the sum of the rows above; positioned-entity capacity P=512+1024+81920+4096=87552. Room, plot, zone, and hive position is derived from tile/owner metadata and does not duplicate a Transform. Furniture, residents, exterior structures, and resource nodes receive Transform rows. Transform ownership uses the directory indexes budgeted below. `[DERIVED; NEW placement of optional positioned components]`

### 2.2 Every fixed component field

| Component | Separate columns | Array | Bytes/element | Column count | Length/column | Payload bytes | Provenance |
|---|---|---|---|---|---|---|---|
| World | seed, day, season, year, map_revision, speed, mode, milestone_mask | I32 | 4 | 8 | 1 | 32 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| World | tick | I64 | 8 | 1 | 1 | 8 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| EntityIdentity | persistent_id, generation, kind | I32 | 4 | 3 | 352418 | 4229016 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| EntityIdentity | active | B8 | 1 | 1 | 352418 | 352418 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Transform | x, y, z, yaw, prev_x, prev_y, prev_z, prev_yaw | I32 | 4 | 8 | 87552 | 2801664 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Resident | species_id, name_key, home_slot, home_generation, bed_slot, bed_generation, role, status | I32 | 4 | 8 | 512 | 16384 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Resident | arrival_tick | I64 | 8 | 1 | 512 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Resident | named, selected_P | B8 | 1 | 2 | 512 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Needs | hunger, rest, comfort, social, purpose, health, cold_hours, starving_hours, departure_days | I32 | 4 | 9 | 512 | 18432 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| NeedRemainders | hunger, rest, comfort, social, purpose | I64 | 8 | 5 | 512 | 20480 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Skills.xp | xp[owner*12+skill] | I64 | 8 | 1 | 6144 | 49152 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Skills.level | level[owner*12+skill] | I32 | 4 | 1 | 6144 | 24576 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Priorities.job_priority | job_priority[owner*12+kind] | B8 | 1 | 1 | 6144 | 6144 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Priorities.flags | auto_fallback, dangerous_work | B8 | 1 | 2 | 512 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Schedule.hourly_activity | hourly_activity[owner*24+hour] | B8 | 1 | 1 | 12288 | 12288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Schedule.state | template, current_activity | I32 | 4 | 2 | 512 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Schedule.latch | sleep_satisfied, resolved, present | B8 | 1 | 3 | 512 | 1536 | [NEW decision 0021] Latched sleep-window state; saved and hashed |
| JobAgent | job_slot, job_generation, phase, target_slot, target_generation, path_id, path_cursor | I32 | 4 | 7 | 512 | 14336 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| JobAgent | lease_expiry, blocked_tick, manual_until | I64 | 8 | 3 | 512 | 12288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| MoodMemory | memory_kind, value, source_id | I32 | 4 | 3 | 4096 | 49152 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| MoodMemory | expiry | I64 | 8 | 1 | 4096 | 32768 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| MealHistory.recipe_id | recipe_id[owner*6+index] | I32 | 4 | 1 | 3072 | 12288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| MealHistory.state | effect_kind, effect_value | I32 | 4 | 2 | 512 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| MealHistory.state | last_meal_tick, effect_expiry | I64 | 8 | 2 | 512 | 8192 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Equipment | tool_item_id, tool_durability, clothing_tier, satchel_slot, satchel_generation | I32 | 4 | 5 | 512 | 10240 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Relationship | a_id, b_id, affinity, last_contact_day | I32 | 4 | 4 | 2048 | 32768 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Relationship | friend | B8 | 1 | 1 | 2048 | 2048 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Injury | kind, severity, untreated_hours, rescuer_slot, rescuer_generation | I32 | 4 | 5 | 512 | 10240 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Injury | care_progress_mwu | I64 | 8 | 1 | 512 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Building | type_id, tier, origin_tile, rotation, state, condition, construction_slot, construction_generation, interior_id | I32 | 4 | 9 | 1024 | 36864 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Room | type, building_slot, building_generation, tile_offset, tile_count, temperature_tenths, furniture_mask, occupants | I32 | 4 | 8 | 16384 | 524288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Room | valid | B8 | 1 | 1 | 16384 | 16384 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Furniture | type_id, room_slot, room_generation, origin_tile, rotation, user_slot, user_generation, condition | I32 | 4 | 8 | 81920 | 2621440 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Construction | material_container_slot, material_container_generation, assigned_count, max_workers, refund_policy | I32 | 4 | 5 | 82944 | 1658880 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Construction | remaining_mwu | I64 | 8 | 1 | 82944 | 663552 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Construction | paused | B8 | 1 | 1 | 82944 | 82944 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| InventoryContainer | owner_slot, owner_generation, policy | I32 | 4 | 3 | 101376 | 1216512 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| InventoryContainer | max_mass_g, filters, reserved_mass_g | I64 | 8 | 3 | 101376 | 2433024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| InventoryContainer | reachable | B8 | 1 | 1 | 101376 | 101376 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| InventoryLot | item_id, quality, provenance, recipe_id, container_slot, container_generation | I32 | 4 | 6 | 16384 | 393216 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| InventoryLot | quantity_milli, reserved_milli, age_milli_hours, age_remainder | I64 | 8 | 4 | 16384 | 524288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Reservation | job_slot, job_generation, lot_slot, lot_generation, purpose | I32 | 4 | 5 | 32768 | 655360 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Reservation | quantity_milli, expiry | I64 | 8 | 2 | 32768 | 524288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ProductionOrder | recipe_id, building_slot, building_generation, mode, priority, completed_batches | I32 | 4 | 6 | 32768 | 786432 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ProductionOrder | target_milli | I64 | 8 | 1 | 32768 | 262144 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ProductionOrder | enabled | B8 | 1 | 1 | 32768 | 32768 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Job | kind, requester_slot, requester_generation, destination_slot, destination_generation, source_slot, source_generation, priority, required_skill, state, worker_slot, worker_generation | I32 | 4 | 12 | 8192 | 393216 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Job | remaining_mwu, created_tick | I64 | 8 | 2 | 8192 | 131072 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FishHabitat | type, zone_slot, zone_generation, effort_slots, pollution, danger, protected_fraction | I32 | 4 | 7 | 32 | 896 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FishHabitat | capacity_milli | I64 | 8 | 1 | 32 | 256 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FishStock | habitat_slot, habitat_generation, species_id | I32 | 4 | 3 | 96 | 1152 | [GDD §4.2; 32*3] |
| FishStock | population_milli, capacity_milli, harvested_today_milli | I64 | 8 | 3 | 96 | 2304 | [GDD §4.2; 32*3] |
| FishStock | closed | B8 | 1 | 1 | 96 | 96 | [GDD §4.2; 32*3] |
| FishHabitat | effort_used | I32 | 4 | 1 | 32 | 128 | [decision 0027, ratified by ruling §5 2026-09-09] §4.2 gives `effort_slots` as a capacity with nowhere to record occupancy, which REQ-SET-044/050 require |
| FishStock | restocking | B8 | 1 | 1 | 96 | 96 | [decision 0027, ratified by ruling §5] REQ-SET-048's 30-down/40-up band needs one bit population alone cannot supply. Transitions are strict: enter `100*P<30*K`, clear `100*P>40*K` |
| FishHabitat | intensive_harvest | B8 | 1 | 1 | 32 | 32 | [decision 0027, ratified by ruling §5] §5.4's "explicitly visible intensive harvest" policy flag; the store's single setter, which is what makes "never by auto-fallback" structural. The three rows above total **256 bytes** |
| FishingEffortClaim | expedition_generation, habitat_slot, habitat_generation, job_slot, job_generation, slot_count | I32 | 4 | 6 | 512 | 12288 | [decision 0037, ruling §5] `claim_row = owning Expedition typed row`; no allocator and no child heap. The Expedition's directory slot is NOT stored — it comes back from `EntityDirectory.owner_slot_of_typed_row()`, which reads ARCH-ID-003's existing reverse map |
| FishingEffortClaim | active | B8 | 1 | 1 | 512 | 512 | [decision 0037, ruling §5] Claim publication and the `effort_used` change are one committed step; the aggregate is rebuilt from live claims on load, never trusted. Slice total **12800 bytes** |
| HarvestZone | type, danger | I32 | 4 | 2 | 128 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| HarvestZone | quota_milli | I64 | 8 | 1 | 128 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| HarvestZone | protected, enabled | B8 | 1 | 2 | 128 | 256 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| HarvestZone.tiles | tile_id | I32 | 4 | 1 | 16384 | 65536 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| HarvestZone | basin_slot, basin_generation | I32 | 4 | 2 | 128 | 1024 | [decision 0026, planner ruling §3.1] Basin ownership; designations bind, never create |
| HarvestZone | harvested_today_milli, quota_reserved_milli | I64 | 8 | 2 | 128 | 2048 | [decision 0030 §4.7] Daily collected is authoritative; outstanding-reserved is a derived cache rebuilt from active claims |
| HarvestZone | quota_mode | B8 | 1 | 1 | 128 | 128 | [decision 0030 §4.6] Automatic / Inherit / Manual |
| FaunaStockReserved | zone_slot, zone_generation, species_id, population, capacity, tracks, harvest_today, migration_link | I32 | 4 | 8 | 384 | 12288 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FaunaStockReserved | birth_remainder | I64 | 8 | 1 | 384 | 3072 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ForagePatch | zone_slot, zone_generation, item_id | I32 | 4 | 3 | 640 | 7680 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ForagePatch | stock_milli, capacity_milli, harvested_year_milli | I64 | 8 | 3 | 640 | 15360 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ForageClaim | job_slot, job_generation, designation_slot, designation_generation, basin_slot, basin_generation, patch_kind | I32 | 4 | 7 | 8192 | 229376 | [decision 0030 §4.7] `claim_row = owning_job_typed_row`; no separate allocator |
| ForageClaim | remaining_milli | I64 | 8 | 1 | 8192 | 65536 | [decision 0030 §4.7] |
| ForageClaim | active | B8 | 1 | 1 | 8192 | 8192 | [decision 0030 §4.7] |
| ForageClaim.ordering | job_created_tick, job_persistent_id | I64 | 8 | 2 | 8192 | 131072 | [decision 0030, **outside** the ruling's 305280 payload per R05-QUOTA-024] Cache of the owning Job's own fields, rebuilt on load; not a separate claim timestamp |
| ResourceNode | resource_id, regrow_days, planted_day | I32 | 4 | 3 | 4096 | 49152 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ResourceNode | quantity_milli, capacity_milli | I64 | 8 | 2 | 4096 | 65536 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ResourceNode | exhausted | B8 | 1 | 1 | 4096 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Expedition | kind, zone_slot, zone_generation, member_id_0, member_id_1, member_id_2, member_count, phase, cargo_slot, cargo_generation, hazard_roll | I32 | 4 | 11 | 512 | 22528 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Expedition | remaining_mwu | I64 | 8 | 1 | 512 | 4096 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Expedition | consent | B8 | 1 | 1 | 512 | 512 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FarmPlot | crop_id, state, soil, fertility, moisture, health, last_family, family_streak, sow_day | I32 | 4 | 9 | 4096 | 147456 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FarmPlot | growth_milli_hours, compost_milli | I64 | 8 | 2 | 4096 | 65536 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| PendingService | owner_slot, owner_generation, service_day, job_slot, job_generation, serviced_day | I32 | 4 | 6 | 4096 | 98304 | [decision 0039; ruling 2026-09-09 §1] ARCH-SYS-009's pending-service identity `(owner EntityRef, operation, absolute service day)`; `row = owner_typed_row*DAILY_SERVICE_OPERATION_COUNT + operation`. `serviced_day` is the completion history the ruling forbids discarding |
| PendingService | status, requires_water | B8 | 1 | 2 | 4096 | 8192 | [decision 0039] FREE/PENDING/UNMET, where UNMET is R06-JOB-008's retained demand, plus §5.6's declared water input |
| PendingService.dirty | dirty_owner | I32 | 4 | 1 | 4096 | 16384 | [decision 0039] R06-JOB-008's dirty stack, one entry per owner; derived and rebuildable |
| PendingService.dirty | is_dirty | B8 | 1 | 1 | 4096 | 4096 | [decision 0039] Membership bit; what makes repeated dirty marking idempotent and the set bounded |
| OrchardPlot | species_id, age_days, health, chill_days | I32 | 4 | 4 | 1024 | 16384 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| OrchardPlot | tended_today, harvested_year | B8 | 1 | 2 | 1024 | 2048 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Hive | building_slot, building_generation, strength, serviced_day | I32 | 4 | 4 | 1024 | 16384 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Hive | feed_milli, honey_milli, wax_milli | I64 | 8 | 3 | 1024 | 24576 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Weather | event, start_day, duration_days, temperature_tenths, rain, forecast_0, forecast_1, forecast_2 | I32 | 4 | 8 | 1 | 32 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Feast | recipe_theme, state, capacity, coverage | I32 | 4 | 4 | 1 | 16 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Feast | start_tick | I64 | 8 | 1 | 1 | 8 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Feast.attendees | resident_id | I32 | 4 | 1 | 256 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Feast.reserved_lots | lot_id | I32 | 4 | 1 | 16384 | 65536 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Progress | milestone, victory_streak_days, feasts_completed | I32 | 4 | 3 | 1 | 12 | [GDD §4.2] |
| Progress | unlocked_mask, mastered_recipe_mask | I64 | 8 | 2 | 1 | 16 | [GDD §4.2] |
| Progress | charter_awarded | B8 | 1 | 1 | 1 | 1 | [GDD §4.2] |
| Notice | severity, category, source_slot, source_generation, code | I32 | 4 | 5 | 500 | 10000 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Notice | created_tick | I64 | 8 | 1 | 500 | 4000 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| Notice | resolved, acknowledged | B8 | 1 | 2 | 500 | 1000 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| TransferManifest | manifest_id, status, rules_hash | I32 | 4 | 3 | 0 | 0 | [GDD §4.2 inactive future adapter; NEW zero allocated rows] |
| TransferManifest.resident_ids | resident_id | I32 | 4 | 1 | 0 | 0 | [GDD §4.2 inactive] |
| TransferManifest.item_lot_ids | lot_id | I32 | 4 | 1 | 0 | 0 | [GDD §4.2 inactive] |
| TransferManifest.quantity_milli | quantity_milli | I64 | 8 | 1 | 0 | 0 | [GDD §4.2 inactive] |
| ManualTask | owner_id, kind, target_slot, target_generation, goal_x, goal_z | I32 | 4 | 6 | 4096 | 98304 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ManualTask | issued_tick, expiry_tick | I64 | 8 | 2 | 4096 | 65536 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| IntegrationRemainders | health, cold, work, xp, food_effect, cold_milli_hours | I64 | 8 | 6 | 512 | 24576 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| BatchState | job_slot, job_generation, recipe_id, lead_level, quality_roll, quality_score | I32 | 4 | 6 | 8192 | 196608 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| BatchState | passive_until, input_mass_g, output_reserved_g | I64 | 8 | 3 | 8192 | 196608 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FieldPolicy | zone_slot, zone_generation, rotation_id_0, rotation_id_1, rotation_id_2, rotation_cursor | I32 | 4 | 6 | 128 | 3072 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| FieldPolicy | auto_rotation, seed_reserve | B8 | 1 | 2 | 128 | 256 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| NoticeCondition | code, source_id, count | I32 | 4 | 3 | 2048 | 24576 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| NoticeCondition | first_tick, last_tick | I64 | 8 | 2 | 2048 | 32768 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| NoticeCondition | active | B8 | 1 | 1 | 2048 | 2048 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| NoticeCondition.affected_ids | affected_id[condition*256+index] | I32 | 4 | 1 | 524288 | 2097152 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ChronicleRecord.pages | resident_id, event, other_id, detail_key | I32 | 4 | 4 | 128 | 2048 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| ChronicleRecord.pages | tick | I64 | 8 | 1 | 128 | 1024 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| WorldPolicy | relief_used_year | I32 | 4 | 1 | 1 | 4 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| WorldPolicy | ration_reserve_milli | I64 | 8 | 1 | 1 | 8 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| WorldPolicy | auto_immigration, raw_emergency_food, variety_first | B8 | 1 | 3 | 1 | 3 | [GDD §4.2; lengths ARCH-MEM-002–004] |
| GeneratorState | requested_seed, effective_seed, attempt, architecture, settlement_name | I32 | 4 | 5 | 1 | 20 | [GDD §4.2; lengths ARCH-MEM-002–004] |

Fixed-field payload sum = **24288210 bytes** (24161234 before decision 0039 added the 126976-byte JobPlanner pending-service ledger, 24148434 before decision 0037 added the 12800-byte `FishingEffortClaim` slice, and 24146898 before decision 0021 added the 1536-byte `Schedule.latch` group, which took the Schedule packed payload from 16384 to 12288+4096+1536=**17920** bytes). The table includes selected_P for allocation but excludes it from canonical hashing. All zero-capacity TransferManifest fields remain declared in the schema and codec; enabling the adapter requires a versioned capacity/budget revision. The chronicle total is unbounded on disk; the row is only its two resident pages. `[DERIVED]`

### 2.3 Complete allocation ledger

All allocations beyond GDD field payload/derived map dimensions are `[NEW]` capacity decisions, not engine measurements. Shared immutable maps/catalogs exist once across transactional loads.

| Allocation | Count | Bytes/element | Bytes | Lifetime | Derivation |
|---|---|---|---|---|---|
| Fixed registry payload | 24725842 | 1 | 24725842 | mutable | Sum §2.2 (+1536 decision 0021; +306304 decisions 0026/0030; +131072 claim-ordering cache, declared separately per R05-QUOTA-024; +256 decision 0027, ratified; +12800 decision 0037 `FishingEffortClaim`; +126976 decision 0039 JobPlanner pending-service ledger) |
| Auxiliary payload | 16663388 | 1 | 16663388 | mutable | Sum §3 (+786436 decision 0019, +158816 ARCH-STATE-005, +65536 READY_06 §7 `TileHistory.family_streak`, +212996 ARCH-STATE-007) |
| Static navigation map | 262144 | 14 | 3670016 | shared immutable | walkability/layer bytes + terrain/height/clearance i32 |
| Active A* builder | 262144 | 21 | 5505024 | mutable | g,parent,heap,heap_position,stamp i32 + state byte |
| Route cell arena | 1048576 | 4 | 4194304 | mutable | ARCH-PATH-005 cells |
| Route descriptors | 256 | 64 | 16384 | mutable | 16 i32: ID,generation,key fields,offset,count,refcount,use tick low/high,flags |
| Path request records | 8192 | 64 | 524288 | mutable | 16 i32 fields; job/source/goal/phase/queue linkage and tick halves |
| Spatial heads | 16384 | 4 | 65536 | mutable | 128*128 heads |
| Resident motion/separation scratch | 512 | 64 | 32768 | mutable | 16 i32; velocities/remainders/next positions/corrections/grid links |
| Command queue | 4096 | 64 | 262144 | mutable | ARCH-CMD-001 stride |
| Command payload arena | 1048576 | 1 | 1048576 | mutable | ARCH-SAVE-001 |
| Tick event ring | 8192 | 32 | 262144 | mutable | crowd §12.1 stride; NEW settlement ring allocation |
| Read-only catalog/lookup budget | 1048576 | 2 | 2097152 | shared immutable | NEW two 1 MiB arenas; reject overbudget catalogs |
| I/O streaming buffers | 65536 | 4 | 262144 | temporary | NEW input/output/CRC/UTF8 chunks |
| UI numeric snapshots | 512 | 256 | 131072 | presentation counted conservatively | NEW two 128-byte resident summaries |
| Timing samples | 6900 | 8 | 55200 | diagnostic counted conservatively | NEW 23 stages, i64 timing samples |

| Metric | Bytes | Arithmetic / meaning |
|---|---|---|
| Planned allocated payload | 59078350 | Sum above |
| Allocator/object reserve | 8388608 | [NEW] 8*1048576 |
| One live world plus reserve | 67466958 | Payload + reserve |
| Headroom below decimal 100 MB | 32533042 | 100000000 − live total |
| Additional candidate mutable state | 52862766 | Second mutable world during transactional load: payload − 3670016 navigation map − 2097152 catalog arenas − 262144 I/O − 131072 UI snapshots − 55200 timing |
| Transactional peak plus same reserve | 120329724 | Live total + candidate mutable state |
| Transactional headroom | -20329724 | 100000000 − transactional peak |

**ARCH-MEM-009 (reconciliation trail).** The ledger sum moved from 57713254 to 59078350 in seven recorded steps, each verifiable on its own `[NEW; decisions 0019, 0021, 0037, 0038, 0039; READY_06 §7]`:

| Step | Governing record | Delta bytes | Running payload | Running payload + 8388608 reserve |
|---|---|---:|---:|---:|
| Baseline as generated | — | — | 57713254 | 66101862 |
| Schedule latch columns | decision 0021 | +1536 | 57714790 | 66103398 |
| Reservation pool indexing | decision 0019 | +786436 | 58501226 | 66889834 |
| Job/JobAgent runtime columns | ARCH-STATE-005 | +158816 | 58660042 | 67048650 |
| GearInstance allocator and exclusive claim | ARCH-STATE-007 (decision 0038) | +212996 | 58951374 | 67339982 |
| JobPlanner pending-service ledger | decision 0039 | +126976 | 59078350 | 67466958 |

The 66103398 figure recorded in decision 0021 is confirmed: it is the baseline plus the latch and nothing else, and it is superseded here only because further decisions are folded in on top of it. Coordinator bookkeeping (decision 0017) and the expanded movement scope (decision 0020) are **not** in any line above; see §3.1.

**ARCH-MEM-006.** The calculated two-world peak is 120329724 bytes, exceeding the gate by 20329724 bytes. Therefore the selected release architecture SHALL use a transactional **disk-backed rollback checkpoint**, not two resident mutable worlds: validate the entire incoming file and construct it in a separate inactive on-disk checkpoint, retain the old world's validated checkpoint, then reuse the old world's mutable allocations to decode the already validated incoming snapshot. On decode/I/O failure restore the validated old checkpoint before exposing any world. This avoids the second 52862766-byte mutable world and adds loading I/O. The original world remains logically unchanged on failure; UI remains in LOAD pause until rollback completes. If rollback itself encounters an I/O fault, keep both files and expose the load error without exposing a partially decoded world. `[NEW selected design; DERIVED ledger; GDD REQ-SET-161]`

**ARCH-MEM-007.** The allocator reserve is a budget to measure, not a claim that Godot headers occupy exactly that amount. Count all live packed capacities and engine-owned copies separately. A measured reserve overrun fails qualification. The main planned payload contributors are directory bookkeeping, fixed field stores, A* scratch, and route cells; active resident fields are a small fraction. Avoid copying packed arrays into temporary local Variants during hot updates. `[NEW instrumentation; crowd §4.2, §7]`

**ARCH-MEM-008.** The fixed record payloads in the ledger expand in this order `[NEW]`:

```text
RouteDescriptor, 16 i32 = 64 bytes:
route_id, generation, start_macro, goal_cell, clearance_class, map_revision,
variant_start_cell, anchor_cell, arena_offset, cell_count, reference_count,
last_use_tick_low, last_use_tick_high, flags, next_variant, reserved_zero

PathRequest, 16 i32 = 64 bytes:
job_slot, job_generation, start_cell, goal_cell, clearance_class, start_macro,
map_revision, phase, route_id, route_generation, created_tick_low,
created_tick_high, next_queue_row, exact_start_cell, anchor_cell, expansions

ResidentMotion, 16 i32 = 64 bytes:
vx, vz, displacement_remainder_x, displacement_remainder_z, next_x, next_z,
correction_x, correction_z, grid_next, grid_cell, radius_u, speed_u_per_s,
desired_yaw, next_yaw, movement_phase, blocked_ticks

SettlementEvent, 32 bytes:
kind:i32, tick:i64, source_persistent_id:i32, target_persistent_id:i32,
arg0:i32, arg1:i32, sequence:i32
```

Tick halves reconstruct a signed nonnegative int64 with range checks. SettlementEvent's layout is layer-specific and does not reinterpret the crowd event record. Event kind IDs are sorted from ARRIVAL, BATCH_COMPLETE, DEATH, DEPARTURE, FEAST_COMPLETE, INJURY, MILESTONE, NOTICE_CHANGED, ORDER_BLOCKED, RENAME, RESOURCE_CHANGED, ROOM_CHANGED; other conditions use a NOTICE_CHANGED code `[NEW]`. Drain presentation events before the next tick's ring reuse; event consumption cannot change gameplay. No allocator heap index is needed to remove arbitrary free entries: only pop-min and insert are used. Partition the directory's free_heap/heap_index allocation into global free-directory and per-kind free-row heaps, each G entries, and treat the field named heap_index as the second heap arena `[NEW naming clarification]`.


**ARCH-MEM-005.** Arena offsets/counts, owner-to-child indexes, occupancy masks, free heaps, stable ID lookup, dirty bits, and the supplementary columns in §3 are allocation overhead outside original field payload. The budget table includes them explicitly. Packed arrays are allocated once to these capacity lengths; page caches and stream buffers are bounded. Never call `resize()` in an ordinary resident update. Oversized incoming content is rejected before allocating a replacement world. `[NEW allocation policy; GDD §5.11]`

## 3. Additional state required by the fixed behavioral rules

The GDD registry does not encode every deadline, ownership mapping, or remainder its requirements need. These **additional saved tables** are `[NEW]`; original components remain byte-for-byte typed as specified. A code generator SHALL generate both sets from distinct schema declarations and include both in ruleset hashing. The missing-schema conflict is explicit in Conflicts Found.

| Table | Separate columns | Array | Bytes/element | Column count | Length/column | Payload bytes | Purpose / provenance |
|---|---|---|---|---|---|---|---|
| DirectoryIndex | typed_row, transform_row, active_index, free_heap, heap_index, typed_owner_slot | I32 | 4 | 6 | 352418 | 8458032 | [NEW] Allocator/reverse ownership; §4 |
| DirectoryIndex | retired, dirty | B8 | 1 | 2 | 352418 | 704836 | [NEW] Allocator/reverse ownership; §4 |
| ChildSliceIndex | offset, count | I32 | 4 | 2 | 16384 | 131072 | [NEW] Shared slice descriptors for zone/room/feast child arrays; lengths validated |
| ResidentRuntime | job_scan_cursor, rank_revision, meal_phase, activity_phase, last_health_band, bed_ref_slot, bed_ref_generation | I32 | 4 | 7 | 512 | 14336 | [NEW] Need/job continuation; GDD §5.2–5.3 |
| ResidentRuntime | last_progress_tick, lease_progress_mwu, wear_remainder, meal_until, next_selector_tick, activity_until | I64 | 8 | 6 | 512 | 24576 | [NEW] Need/job continuation; GDD §5.2–5.3 |
| TileHistory | fertility, last_family, family_streak, last_legume_day, compost_season, active_plot_row, orchard_row | I32 | 4 | 7 | 16384 | 458752 | [NEW; +65536 READY_06 §7] Erasing designations cannot erase soil history, INCLUDING the consecutive same-family harvest count |
| TileHistory | ripe_tick, growth_remainder | I64 | 8 | 2 | 16384 | 262144 | [NEW] Erasing designations cannot erase soil history |
| TileHistory | tended_today | B8 | 1 | 1 | 16384 | 16384 | [NEW] Erasing designations cannot erase soil history |
| GearInstance | lot_slot, lot_generation, item_id, durability, durability_cap, owner_slot, owner_generation, manufacture_recipe | I32 | 4 | 8 | 16384 | 524288 | [NEW] One instance/live gear lot or equipped item; §3 |
| GearInstance | equipped | B8 | 1 | 1 | 16384 | 16384 | [NEW] One instance/live gear lot or equipped item; §3 |
| GearInstanceIndex | occupied | B8 | 1 | 1 | 16384 | 16384 | [NEW ARCH-STATE-007; ruling 2026-09-09 §4] Gear-pool occupancy |
| GearInstanceIndex | free_heap | I32 | 4 | 1 | 16384 | 65536 | [NEW ARCH-STATE-007] Free-row min-heap, lowest index first; rebuilt ascending on load |
| GearInstanceIndex | free_count | I32 | 4 | 1 | 1 | 4 | [NEW ARCH-STATE-007] Heap occupancy counter |
| GearInstanceClaim | claim_job_slot, claim_job_generation | I32 | 4 | 2 | 16384 | 131072 | [NEW ARCH-STATE-007] The one Job that exclusively claims the gear; REQ-SET-044 |
| BatchDetails | dominant_item, effect_kind, effect_value, input_provenance, completion_sequence | I32 | 4 | 5 | 8192 | 163840 | [NEW] Retain source-dependent quality/effect after input consumption |
| BatchDetails | weighted_quality_sum, input_mass_sum, oldest_age_fraction, work_denominator, work_remainder | I64 | 8 | 5 | 8192 | 327680 | [NEW] Retain source-dependent quality/effect after input consumption |
| JobRuntime | player_priority, phase, completion_sequence, path_request_id, input_slice, output_slice | I32 | 4 | 6 | 8192 | 196608 | [NEW] Rank/context/transaction progress |
| JobRuntime | last_progress_tick, lease_progress_mwu | I64 | 8 | 2 | 8192 | 131072 | [NEW] Rank/context/transaction progress |
| JobPresence | job_present | B8 | 1 | 1 | 8192 | 8192 | [NEW ARCH-STATE-005] Row liveness for the Job store; saved and hashed |
| JobDirectoryRef | job_ref_slot, job_ref_generation | I32 | 4 | 2 | 8192 | 65536 | [NEW ARCH-STATE-005] Directory reference cache; rebuilt on load, not hashed |
| JobSelection | urgency, dangerous | B8 | 1 | 2 | 8192 | 16384 | [NEW ARCH-STATE-005] GDD §5.3 declared bucket and consent subject; saved and hashed |
| JobSelection.gates | station_gate, tool_gate, unlock_gate, inputs_gate | B8 | 1 | 4 | 8192 | 32768 | [NEW ARCH-STATE-005] Eligibility step 4/6 inputs; saved and hashed |
| JobLiveIndex | live_slot | I32 | 4 | 1 | 8192 | 32768 | [NEW ARCH-STATE-005] Ascending live-job index the scan cursor addresses; rebuilt on load, not hashed |
| JobAgentRuntime | agent_present, hazard_locked | B8 | 1 | 2 | 512 | 1024 | [NEW ARCH-STATE-005] Agent liveness and REQ-SET-015 latch; saved and hashed |
| JobAgentRuntime | agent_persistent_id | I32 | 4 | 1 | 512 | 2048 | [NEW ARCH-STATE-005] Persistent-ID cache for the stagger test; rebuilt on load, not hashed |
| JobSelectionScratch | skill_scratch, priority_scratch | I32 | 4 | 2 | 12 | 96 | [NEW ARCH-STATE-005] Per-pass strides; never saved or hashed, memory still counted |
| ReservationIndex | occupied | B8 | 1 | 1 | 32768 | 32768 | [NEW decision 0019] Global pool occupancy |
| ReservationIndex | free_heap | I32 | 4 | 1 | 32768 | 131072 | [NEW decision 0019] Free-row min-heap, lowest index first |
| ReservationIndex | free_count | I32 | 4 | 1 | 1 | 4 | [NEW decision 0019] Heap occupancy counter |
| ReservationIndex | job_head | I32 | 4 | 1 | 8192 | 32768 | [NEW decision 0019] Per-Job list head |
| ReservationIndex | lot_head | I32 | 4 | 1 | 16384 | 65536 | [NEW decision 0019] Per-lot list head |
| ReservationIndex | job_prev, job_next, lot_prev, lot_next | I32 | 4 | 4 | 32768 | 524288 | [NEW decision 0019] Intrusive links by Job and by lot |
| Candidate | species_id, skill_0, skill_1, event_day | I32 | 4 | 4 | 8 | 128 | [NEW] Reviewable pending immigration; GDD candidate cap 8 |
| Candidate | event_tick | I64 | 8 | 1 | 8 | 64 | [NEW] Reviewable pending immigration; GDD candidate cap 8 |
| RngStream | domain, state | I32 | 4 | 2 | 9 | 72 | [NEW] §8 exact stream domains |
| RngStream | draw_count | I64 | 8 | 1 | 9 | 72 | [NEW] §8 exact stream domains |
| BuildingService | passive_occupied, staff_occupied, boat_count, upgrade_paid_mask | I32 | 4 | 4 | 1024 | 16384 | [NEW] Service use and exact forecast history |
| BuildingService | fuel_remainder, cooking_fuel_day0, cooking_fuel_day1, cooking_fuel_day2 | I64 | 8 | 4 | 1024 | 32768 | [NEW] Service use and exact forecast history |
| HivePollinationLinks | hive_slot, hive_generation | I32 | 4 | 2 | 24576 | 196608 | [NEW] Six max links per conservative field block capacity |
| WorldTileMaps | building_slot, room_slot, zone_link_head, resource_slot | I32 | 4 | 4 | 16384 | 262144 | [NEW] Tile ownership and references |
| RoomTileLinks | tile_id | I32 | 4 | 1 | 16384 | 65536 | [NEW] Nonoverlapping room tiles |
| EventSchedule | kind, source_id, arg0, arg1 | I32 | 4 | 4 | 64 | 1024 | [NEW] Bounded calendar events; per-job deadlines remain in jobs; NEW 64 |
| EventSchedule | due_tick, sequence | I64 | 8 | 2 | 64 | 1024 | [NEW] Bounded calendar events; per-job deadlines remain in jobs; NEW 64 |
| SocialDailyPair | last_social_gain_day, last_rescue_event, last_feast_event, last_conflict_day | I32 | 4 | 4 | 2048 | 32768 | [NEW] Affinity once/event restrictions |
| MortalityWindow | starvation, exposure, other, departures | I32 | 4 | 4 | 48 | 768 | [NEW] Current winter and trailing 12-day counters; NEW 48-day ring |
| MasteryCounter | good_batches, total_portions | I32 | 4 | 2 | 64 | 512 | [NEW] Unchanged recipe thresholds; NEW 64 counter slots, bitmask limit |
| LotEffect | effect_kind, effect_value, effect_duration_ticks, source_item_id | I32 | 4 | 4 | 16384 | 262144 | [NEW] Prepared/preserved source effect survives ingredient consumption |
| WorldRuntime | next_persistent_id, prepared_portions, next_job_sequence, last_progress_day, requested_speed, pause_reasons | I32 | 4 | 6 | 1 | 24 | [NEW] Allocator/progression/session counters |
| WorldRuntime | next_command_sequence, next_event_sequence, chronicle_count | I64 | 8 | 3 | 1 | 24 | [NEW] Allocator/progression/session counters |
| NamePoolUtf8 | utf8_byte | B8 | 1 | 1 | 131072 | 131072 | [NEW] NEW 128 KiB live sanitized names; historic strings stream with chronicle |
| NamePoolIndex | offset, byte_count, reference_count | I32 | 4 | 3 | 4096 | 49152 | [NEW] NEW 4096 active names; release unreferenced aliases |
| BuildingItemMinimum | minimum_milli | I64 | 8 | 1 | 262144 | 2097152 | [NEW] NEW policy arena; 256 item IDs maximum in this compiled release |
| BuildingItemAllow | allowed | B8 | 1 | 1 | 262144 | 262144 | [NEW] NEW per-item override; filters bitset remains category mask |
| ConstructionPaidLedger | base_type, upgrade_mask | I32 | 4 | 2 | 82944 | 663552 | [NEW] Exact immutable paid package keys; costs retrieved by rules hash |

Auxiliary payload sum = **16663388 bytes** `[DERIVED]`. That is 15439604 before this reconciliation, plus 786436 of reservation-pool indexing (decision 0019), 158816 of Job/JobAgent runtime columns (ARCH-STATE-005), 65536 for `TileHistory.family_streak` (READY_06 §7, taking that I32 group from six columns/393216 bytes to seven/458752) and 212996 of GearInstance allocator and exclusive-claim columns (ARCH-STATE-007): 15439604+786436+158816+65536+212996=16663388. Arena links and exact owner counts must validate before activation; unused child descriptors are zero. These are explicit schema extensions, not permission to omit the original fields. Snapshotting original plus auxiliary columns is mandatory for replay.


**ARCH-STATE-001.** Model item instances with `GearInstance` rather than assigning durability to the immutable ItemDefinition. A gear lot is indivisible: `quantity_milli=1000`; one gear instance points at that lot. Stacking partially used tools is forbidden. Equipped tools/outfits transfer to the resident's Equipment fields and retain their source instance record outside satchel mass. Unequipping reverses that transfer without resetting durability. `tool_item_id` still uses the original catalog ID; its metadata records basic versus iron manufacture. `[GDD §4.2, §5.7, §5.9; NEW instance representation]` The allocator, ownership bookkeeping and claim columns this component needs are ARCH-STATE-007 below; the row shape here is unchanged by it.

**ARCH-STATE-002.** BatchState snapshots the original schema fields. BatchDetails additionally stores the resolved dominant input effect, weighted input-quality sum/mass, oldest effective age fraction, concrete input recipe provenance, remaining active work denominator, and completion sequence. For quality, use mass-weighted quality across all consumed input lots, with `floor_div(sum(mass_g*quality_score),sum(mass_g))`; nonperishable inputs contribute age fraction 0. Dominant-effect choice excludes water/brine and ties by compiled item ID. These weighting and brine interpretations are `[NEW]`; formula coefficients, one roll, and output tiers remain `[GDD §5.7 REQ-SET-091]`.

**ARCH-STATE-003.** Time-dependent soil metadata persists on world tiles when fields are erased. This includes last crop family, **the consecutive same-family harvest count paired with it** `[NEW READY_06 §7, 2026-09-09]`, the last legume-harvest day, compost application season, ripe tick, and growing-day service state. The family and its count are one pair: they are written together on a completed harvest and restored together on redraw, and a populated family carrying a zero count is a legacy snapshot with missing data that SHALL be explicitly migrated or rejected, never read as complete history. Recreating a field can allocate a FarmPlot row, but it SHALL copy the existing tile state; it SHALL not restore fertility or reset compost eligibility. `[GDD §5.6 REQ-SET-074–078; NEW tile backing store]`

**ARCH-STATE-004.** BuildingItemMinimum/BuildingItemAllow apply only to the 1024 exterior main stores. Satchels, ground piles, WIP/project stores, and expedition cargo inherit their owning job's permitted contents; they do not allocate independently editable per-item policies `[NEW UI scope]`. The original 64-bit filters field is a category mask; an optional per-item allow byte further restricts it. This release's compiled ItemDefinition catalog must contain at most 256 keys `[NEW content envelope]`; reject a larger authored catalog at compile time and require a new memory/rules revision. Two 65536-byte name pages hold at most 4096 live alias/localization bindings; retired historical aliases are written to the save's streamed NAME_POOL section before their live pages can be reused. Historic ID bindings never point to a new alias with a recycled key `[NEW name-pool lifetime]`.

AdmissionProfile and AuthoredAdmission definitions follow SET-AMEND-001 §5 and count inside the existing immutable catalog/lookup arenas. The current scenario manifest binds the profile; its catalog hash participates in the existing save compatibility check. Candidate origin is derived from profile/event_day/species_id because normal and exception species are disjoint and exception dates unique. A cleared candidate uses species_id=-1 and all other columns 0. Pending expiration, explicit exception acceptance and atomic clearing follow the amendment. No extra packed runtime allocation or per-resident lore object is added. FaunaStockReserved reference fields remain (-1,0), numeric fields 0; no directory entry may reference a live reserved fauna row. All eleven active skills retain their prior indices; transferred/saved index 3 must be zero. V1 saves are rejected before decoding into live state; no implicit catalog remapping is permitted.

**ARCH-STATE-005.** The Job/JobAgent runtime columns above are the eligibility and continuation state GDD §5.3 requires and §4.2 has no field for. They are implemented in `godot/scripts/core/jobs.gd`, whose header enumerates the same delta; this table is now their owning budget `[NEW; GDD §5.3, REQ-SET-015, REQ-SET-028]`.

- **Scan cursor.** §5.3's saved cursor is `ResidentRuntime.job_scan_cursor`, already budgeted above inside that 7-column I32 group (4*7*512=14336). The implementation names the same value `_agent_scan_cursor` and allocates it once at length 512 in the jobs module. That is **one** physical buffer serving one logical column; **no second allocation is counted, and none may be created**. The implementation must either move the column into a ResidentRuntime store or record the jobs module as its owner; it may not allocate a cursor in both places. Its index space is `JobLiveIndex`, not the raw job slot.
- **Declared urgency.** `urgency` stores the bucket a job *declares* (0 rescue, 1 personal critical, 2 food/fuel, 3 ordinary, 4 cosmetic). The **effective** bucket additionally reads current reserve conditions: a job declaring bucket 2 occupies bucket 2 only while the projected food/fuel reserve is under two days, and ranks as ordinary otherwise. The reserve condition is world state owned by the food-days figure and the inventory; it SHALL be an explicit input to selection and SHALL NOT be baked into the stored byte, so the stored column stays correct across a changing reserve.
- **Dangerous-work flag.** `dangerous` is per **Job**, and is the subject of eligibility step 5's consent test and REQ-SET-015's hazard bar. Its owning sources are HarvestZone `danger` and FishHabitat `danger` in §2.2; until those stores exist the flag is set explicitly by whoever creates the job, and it SHALL be recomputed from the owning zone/habitat danger value when the job's source or destination is bound and whenever that danger value changes. It is not the same field as `Priorities.flags.dangerous_work`, which is the **resident's** standing consent.
- **Station/tool/unlock/input gates.** Four derived eligibility inputs with three states: not-required (the job declares no such requirement), satisfied, blocked. Only *blocked* makes a job ineligible; not-required never means ready. Their owning systems are Building/Room/Furniture (station), Equipment (tool), Progress `unlocked_mask` (unlock) and Reservation/InventoryLot (inputs). Each SHALL be invalidated and rewritten by its owning system when that system's state changes — station on building state/condition/occupancy change, tool on equip/unequip/durability loss, unlock on milestone award, inputs on any reservation or lot change touching the job — and never lazily recomputed inside a selection pass. The skill half of step 4 is not a gate column: it is decided from the resident's Skills row against the job's `required_skill`.
- **Hazard lock.** `hazard_locked` is authoritative latched history, not a recomputable view: it is set when rest falls to the collapse threshold and cleared only when rest reaches the hazard-clear threshold, so its value at a given rest level depends on which threshold was crossed last. It is **saved and hashed**. Exactly one hazard gate exists and it lives here; the schedule store does not duplicate it.
- **Presence and reference caches.** `job_present` and `agent_present` are the row-liveness authority for their stores and are saved and hashed. `job_ref_slot`/`job_ref_generation` and `agent_persistent_id` are caches of values the global directory already owns; they are allocated for the life of the world, are reconstructed from the directory during load's derived-index rebuild, and are **excluded from canonical hashing** so a rebuilt cache cannot change a state digest. A cache that disagrees with the directory after rebuild is a load failure, not a repair.
- **Live-job index and per-pass scratch.** `JobLiveIndex` is the ascending live-job list the scan cursor addresses; the scratch columns hold one resident's twelve skill levels and twelve job priorities for the duration of a selection pass. Neither is saved and neither is hashed — and **both are counted in the ledger anyway**, because excluding state from a save does not remove it from resident memory. `JobLiveIndex` is rebuilt from `job_present` at load. The scratch columns hold no meaning between passes and SHALL NOT be read outside the pass that filled them.

**ARCH-STATE-006.** `ReservationIndex` is decision 0019's global reservation pool made explicit in the budget. The 32768 rows in §2.2's Reservation component are allocated from the lowest free index; there is no `job*4+i` owner-major indexing, and the 4:1 row-to-job ratio is a storage budget, not a per-recipe limit. Variable-length lists per Job and per inventory lot are formed by the head and prev/next link columns; free rows come from the min-heap. A transaction SHALL preflight its complete row requirement, and insufficient rows produce an explicit capacity refusal with **no partial reservations**. The 786436-byte indexing payload is additional to the 1179648 bytes the Reservation component already occupies in §2.2 (655360 I32 + 524288 I64). One implementation deviation is recorded rather than budgeted: `free_count` is a scalar GDScript `int` (64-bit) in `godot/scripts/core/reservations.gd`, where the ledger and decision 0019 both carry it as one int32; the 4-byte figure stands and the deviation is immaterial to the total. `[NEW; decision 0019]`

**ARCH-STATE-007.** `GearInstanceIndex` and `GearInstanceClaim` are the GearInstance allocator and ownership bookkeeping, adopted from `docs/rulings/2026-09-09_ready06_open_item_answers.md` §4 and implemented in `godot/scripts/core/gear.gd`. They close blocker **U5**, which was missing allocator and ownership state — **not** missing gear capacity: the 16384 rows and the 540672-byte fixed-field payload above were already budgeted, and neither is enlarged. There is no gear row per resident and no change to the global entity directory. `[NEW; decision 0038]`

- **Lowest-free-row pool.** Rows are allocated from the lowest free index through a preallocated min-heap, the same shape `ReservationIndex` and the directory's ARCH-ID-002 heaps use. Occupancy and the authoritative fields are saved and hashed; `free_heap` and `free_count` are derived and are **rebuilt ascending on load**, so a loaded world reuses rows in the same order as the world that saved it.
- **Allocate before consume.** A creation that cannot get a row refuses **before** any material is consumed or any loose output lot is created. The store publishes a preflight for exactly that call order.
- **Initialise before publish.** Every field of a row is written before its occupancy byte is set, and a row is blanked before it returns to the heap. The implementation enforces the order rather than merely following it: publishing a row whose identity columns are still blank fails and returns the row unpublished.
- **No durable raw row index.** No gear-row index escapes as a handle: the row carries no generation of its own, so a handle to it would silently re-point when the row is reused. Public entry points resolve validated, generation-checked lot and owner references and verify the row's recorded identity. A persistent `GearRef` requires its own budgeted generation column and retirement rule first, and adding one is a schema change, not an implementation detail. The same applies to a lot-indexed reverse column: the 212996 bytes above contain **no** reverse index, and the implementation uses a bounded ascending scan instead.
- **Exclusive Job claim.** `claim_job_slot`/`claim_job_generation` name the one cycle or coordinator Job holding the gear (decision 0017, REQ-SET-044). A second owner, a repair or ownership change while claimed, and a cycle whose available durability is below its specified wear are all refused. Completion applies wear once and releases the claim; cancellation before completion releases it and applies nothing.
- **Instance eligibility is a named predicate.** The portable instance-required keys are exactly `tool`, `net`, `trap`, `ice_kit` and `outfit_tier2`. `candle` shares their GEAR category and is **not** one of them: it remains stackable consumable inventory, which is why the ItemDefinition category is the wrong test. Tier-2 outfits retain identity for equipment transfers with canonical durability/cap **0/0** and wear/repair rejected as inapplicable; this introduces no clothing degradation mechanic. Starter tier-1 clothing remains `Equipment.clothing_tier`, not an invented ItemDefinition.
- **Two wear models stay distinct.** General tools use §5.7's 1-point-per-10-WU rule with a preserved remainder and caps 1000/1500 by manufacture; fishing gear uses §5.4's fixed per-cycle wear against a 1000 cap. The two repair recipes — wood 1 + stone 0.5 versus wood 1 + rope 0.25 — are preserved separately, repair clamps to the model's own cap, and repair is not a durability reset. The general remainder is **not** allocated here: it is `ResidentRuntime.wear_remainder`, already budgeted at length 512, and is passed into the wear operation and handed back.
- **Deliberately out of scope, with dependencies named.** The ruling's equipped-lot amendment (`InventoryLot.container=NULL_REF` for a validated equipped record) requires `inventory.gd`'s validation, mass accounting and consumers to change together and is **not** taken here; the `equipped` byte is carried and saved but never set, and no null-container lot is created. Boats and weirs are installed gear, not ItemDefinition inventory output; the boat owner/instance discriminator is unresolved and belongs to the expedition/installed-gear contract, so `WEAR_PER_CYCLE` carries no boat or weir entry and a non-resident owner reference is refused rather than guessed. `manufacture_recipe` currently carries a two-member local domain (basic/iron) because no compiled `RecipeDefinition` domain exists; it must migrate to the compiled recipe ID when that domain is compiled, which moves the save digest.

### 3.1 Still unbudgeted

These are known allocations that no line of §2.2, §3 or §2.3 counts. They are listed so the 32660018-byte headroom is read as *headroom against an incomplete ledger*, not as a certified margin `[NEW reconciliation note]`.

| Item | Governing record | Status |
|---|---|---|
| Coordinator-Job bookkeeping | decision 0017 | **Not counted anywhere.** Coordinator and member Jobs share the existing 8192-row capacity, but the coordinator's own state — the member-to-coordinator link, per-member accepted-work and fractional XP retention, shared-phase ownership marks, and the coordinator flag that excludes it from resident selection — has no column here. Decision 0017 states this is budgeted separately; it has not yet been. Sizing it requires the WU/XP model, which is a later task. |
| Expanded movement scope | decisions 0013, 0020; SET-MOVE-001; MOVE-G02 | **Not counted anywhere.** Finite multi-level location/connection/profile/reservation state, crossing queues, work contacts, topology-edit transactions and save migration. ARCH-MEM-002 already flags every figure here as baseline-only. Decision 0020 is explicit that **this one-floor ledger cannot qualify the connected-movement pathfinder**; do not present the totals above as movement-inclusive, and do not multiply them by an invented floor count. |
| ManualTask child store | U6 | Owner-major indexing for the 8-per-resident store is unspecified. §2.2 budgets `ManualTask` at 4096 rows, but the per-resident index and its slice descriptors are not separately allocated. |
| U5's remaining child stores | U5; ruling 2026-09-09 §4 | **Partially closed.** Reservation was budgeted by decision 0019 and GearInstance by ARCH-STATE-007 above. `BatchState`, `LotEffect`, `NoticeCondition` and `ChildSliceIndex` still have **no allocator storage budgeted**, so U5 is not closed as a whole. |
| Path/lease bookkeeping fields | REQ-SET-032/033; ARCH-JOB-004 | Allocated but never written: `path_id`, `path_cursor`, `lease_expiry`, `blocked_tick`, `manual_until`. The **memory is counted** in §2.2's JobAgent rows; the point is that the behavior these back is unimplemented, so no further allocation should be assumed absent. |
| Other implemented core stores | — | `residents.gd`, `needs.gd`, `priorities.gd`, `inventory.gd` and `entity_directory.gd` each allocate presence, liveness, free-list, environment-input and journal columns beyond their §2.2 rows, in the same way `jobs.gd` did before this pass. Only the jobs module was reconciled here. Each of the others needs the same column-by-column pass against §2.2/§3 before any measured-memory qualification is attempted; their deltas are **not** in the 58951374 total. |
| Measured allocator and engine overhead | ARCH-MEM-007; ARCH-CONFLICT-009 | The 8388608-byte reserve is a budget to measure, not a measurement. No Godot process memory has been measured against this ledger. |

## 4. Entity allocation, lifetime, and safe references

**ARCH-ID-001.** Every referenceable runtime entity receives one slot in a global directory; its `kind` and `typed_row` locate the appropriate typed store `[NEW directory]`. Resident rows remain separately bounded at 512 `[GDD §4.1]`. Child records such as Reservation, MoodMemory, Skills, and NoticeCondition are owner-indexed rows, not extra entity objects. A Job or InventoryLot is referenceable and does receive a directory entry. Use fixed kind numeric IDs from sorted ASCII kind keys, preserving GDD's explicitly numbered enums in their own domains. Persistent IDs are globally unique positive int32 values, assigned monotonically and never reused `[GDD §4.1–4.2]`.

**ARCH-ID-002.** Both directory and typed-row allocators use preallocated indexed min-heaps of free indices. Pop the lowest free slot, initialize all columns and children explicitly, then publish `active=1` at lifecycle commit. Initial generation is 1 `[NEW]`; increment on reuse, not on destroy, matching `[crowd §4.1]`. Generation 2147483647 may be used once; after its destruction retire the slot permanently rather than wrapping. Persistent ID exhaustion at 2147483647 refuses further creation and offers saving/continuation of the existing world; it never wraps or resets on load. `[NEW overflow disposition]`

**ARCH-ID-003.** All command, job, reservation, target, ownership, UI lookup, event, and save-load access SHALL validate this predicate before reading target columns:

```text
valid(ref, expected_kind) :=
    0 <= ref.slot < directory_capacity
    AND identity.active[ref.slot] == 1
    AND identity.generation[ref.slot] == ref.generation
    AND (expected_kind == ANY OR identity.kind[ref.slot] == expected_kind)
    AND 0 <= directory.typed_row[ref.slot] < kind_capacity[identity.kind[ref.slot]]
    AND typed_owner_slot[kind][typed_row] == ref.slot
```

`ANY` is a validator mode, not a saved kind. Validation of a null optional reference returns absent; it is never dereferenced. A stale mandatory reference cancels the dependent job through the normal release pipeline, emitting one grouped notice. `[GDD §4.1–4.2, §5.8; NEW reverse-owner consistency check]`

**ARCH-ID-004.** Creation is a transaction: reserve every required typed row, directory row, child row, inventory slot, and command-output slot; if any pool is full, release the temporary allocator reservations and refuse the operation with `CAPACITY_<STORE>`. Do not spend materials or evict a living resident, job, reservation, or resource. Eligible lot merging may be attempted first under the fixed GDD merge rule. Refused nonessential production remains disabled with an explanation; essential capacity failure pauses with a diagnostic if continuation would lose state. `[GDD §4.2, §5.8 REQ-SET-120; crowd CR-009; NEW error codes]`

**ARCH-ID-005.** At death/departure, stop new work, release reservations, transfer or drop real inventory under the cause's rules, record chronicle/memories, copy render corpse data if used, invalidate bed assignment and relationship indexes, then clear active and return the row at end-of-tick commit. Deferred create/destroy operations sort by command execution order and then persistent ID. No swap-removal changes a live authoritative slot; only active index arrays and render batches compact. `[GDD §5.2–5.3; crowd §4.1, §6.2]`

## 5. Tick pipeline, systems, and scheduler

**ARCH-TICK-001.** A dedicated GameManager scheduler runs from `_process` with unscaled real elapsed time; simulation never runs a second time in `_physics_process`. `Engine.time_scale` remains 1 `[NEW implementation; GDD §5.1; crowd §6.3]`. At normal speed run 30 ticks/real second, 2× runs 60, 4× runs 120; each completed tick applies identical integer game rules. The initial world is paused for inspection `[UI §4.3 UI-SET-103]`.

```text
Unscaled host clock -> scheduler debt -> fixed tick k
                                         |
                      capture previous / clear scratch
                                         |
                      ordered commands / validation
                                         |
                      due stock aging / needs integration
                                         |
      midnight? -> ecology -> crops/weather -> migration/departure intent
                                         |
                  jobs -> fixed-quota routes -> integer motion
                                         |
             productive work -> passive completions -> atomic inventory
                                         |
               care / health / mood -> deaths / lifecycle commit
                                         |
                      progression / notices / hour forecasts
                                         |
           completed_tick=k -> hash when due -> immutable UI/render delta
```

**ARCH-TICK-002.** Define a tick interval as `(k-1,k]`; read interval climate and resident activity from the committed tick `k-1`. Accrue continuous needs/work/age for that interval once. At an hourly/midnight crossing apply accumulated boundary effects before starting the next interval. Initial calendar offset is 4500 ticks; first midnight is 13500, then every 18000 ticks. Hour boundaries satisfy `(k+4500) mod 750=0`. Midnight satisfies `(k+4500) mod 18000=0`. Never perform a second age pass just because the same tick is both hourly and daily. `[GDD §5.1 REQ-SET-006–007; NEW interval convention]`

**ARCH-TICK-003.** Daily ordering is stock aging → ecology → crops/weather → immigration/departures → progression. At midnight, aging uses the season in the elapsed interval; ecology uses the new calendar day's season; crop hourly growth uses the elapsed hour's climate, followed by new-day weather/moisture/service reset. Prepare deaths/departures as intents, but commit them before progression so current living population and cause-of-death counters are correct. All systems below operate once in their assigned phase. `[GDD §5.1 REQ-SET-007, §5.10–5.11; NEW crossing convention]`

| ID / system | Reads | Writes | Frequency and dependency | Provenance |
|---|---|---|---|---|
| ARCH-SYS-001 TransformSnapshot | Transform current | Transform previous | Every tick; first | [crowd §6.2] |
| ARCH-SYS-002 CommandCommit | Ordered command queue, catalogs, directory, current stocks | Orders, policies, reservations, lifecycle intents | Every tick; after snapshot, before selectors | [GDD §5.1 REQ-SET-005] |
| ARCH-SYS-003 IntervalIntegrator | Needs, activities, weather, lots, rooms, work context | NeedRemainders, IntegrationRemainders, age/work accrual | Every tick; prior interval state | [GDD §5.2, §5.8] |
| ARCH-SYS-004 StockAge | Accrued lot age, storage factors | InventoryLot, spoilage intents, invalid leases | Hour crossing and expiry crossing; midnight first | [GDD §5.8 REQ-SET-107–108] |
| ARCH-SYS-005 Ecology | Basins, fish/forage/tree state (fauna reserved empty), climate | Stock growth, quotas, migration, resource regrowth, ecology events | Midnight after StockAge | [GDD §5.4–5.6, §5.9–5.10] |
| ARCH-SYS-006 CropWeather | FarmPlot, OrchardPlot, Hive, previous climate, event schedule | Crop progress/health/ripe state, moisture, weather forecast, service counters | Hourly crop integration; midnight after Ecology | [GDD §5.6, §5.10] |
| ARCH-SYS-007 ImmigrationDeparture | Needs/mood histories, reputation, candidates, policy, bed/stock availability | Review candidates, acceptance/departure intents | Daily; candidate event every third midnight from day 4; after CropWeather | [GDD §5.11] |
| ARCH-SYS-008 NeedIntent | Committed/accrued needs, safe rooms, food | Personal feeding/sleep/rescue intent | Every tick; emergencies preempt immediately | [GDD §5.2] |
| ARCH-SYS-009 JobPlanner | Orders, thresholds, recipe inputs, field/care/build service needs | Job rows, reservation plans, output commitments | On dirty service conditions; idle selectors every 30 ticks staggered by ID | [GDD §5.3, §5.7–5.9] |
| ARCH-SYS-010 JobSelector | Indexed jobs, priorities, schedule, skill, tools, paths | JobAgent, reservation transactions, scan cursors | At most 32 candidates/eligible resident/pass; exact GDD rank | [GDD §5.3] |
| ARCH-SYS-011 Navigation | Baked masks, map revision, request queue | Heap/search state, route caches, JobAgent path status | Every tick; total 2048 expansions | [GDD §5.11] |
| ARCH-SYS-012 Movement | Tick-start transforms, paths, clearance, speed caps | Transform current, motion remainders, occupancy scratch | Every tick; after Navigation | [GDD §5.11; crowd §5.3] |
| ARCH-SYS-013 ProductiveWork | Assigned job, F, tool, delivered inputs | Remaining work, XP accrual, wear remainder, completion intents | Every tick; after Movement | [GDD §5.3, §5.9] |
| ARCH-SYS-014 BatchCompletion | BatchState, frozen input/quality snapshot, passive_until | Finished lots, station release, mastery/portion increments | Every tick at exact deadline; stable job order | [GDD §5.7 REQ-SET-091–098] |
| ARCH-SYS-015 LogisticsCommit | Completion/transfer plans, containers, leases | Inventory quantities/owners, reservations, ground piles | Every tick; atomic operation order | [GDD §5.8] |
| ARCH-SYS-016 RoomHeat | Layout dirty tiles, hearth fuel, occupants | Room validity/temp, warm-bed index, fuel debit | Layout change; heat integration each tick; convergence hourly | [GDD §5.9] |
| ARCH-SYS-017 CareHealth | Hunger/exposure/injury accrual, care work | Health, injury, incapacity/death intents | Every tick; before lifecycle and progression | [GDD §5.2, §5.10] |
| ARCH-SYS-018 SocialMood | Needs, paired activity, memories, relationships | Affinity, mood memories, daily conflict result, naming triggers | Needs-derived mood each dirty tick; hourly/contact triggers and 18:00 conflict | [GDD §5.2–5.3] |
| ARCH-SYS-019 Lifecycle | Create/destroy/arrival/departure/death intents | Directory, typed occupancy, child release, chronicle | End of every tick; before progress | [GDD §4.1, §5.11; crowd §6.2] |
| ARCH-SYS-020 Progression | Final alive state, completed recipes/feasts, inventory, winter history | Progress, milestone_mask, unlock gifts, victory pause intent | On changed predicates; daily streak after lifecycle | [GDD §5.11] |
| ARCH-SYS-021 ForecastNotice | Dirty totals, current obligations, active conditions | Cached food/fuel/potential summaries, Notice/NoticeCondition | Hourly and committed stock/policy change; no frame scan | [GDD §5.8 REQ-SET-119; UI §7] |
| ARCH-SYS-022 CheckpointHash | All authoritative state and queues | Canonical digest, save stream, replay diagnostic | Committed boundary only | [GDD §5.11; crowd §6.4] |
| ARCH-SYS-023 PresentationExtract | Completed immutable snapshot, dirty pages | Render buffers, UI snapshots only | Render cadence; never writes simulation | [GDD REQ-SET-162; UI §3; crowd §6.3] |

**ARCH-TICK-004.** Parallelizable work is an implementation analysis, not release-1 scheduling: per-lot aging and per-resident need accrual read disjoint rows; crop/hour accumulation can write disjoint plot scratch. Shared output capacity, RNG consumption, reservations, jobs, deaths, and progression require ordered commits. Any future worker batches use immutable input pages, disjoint outputs, and reduction by persistent ID. The main thread waits at a deterministic barrier; missing the wall-time budget triggers overload rather than accepting an incomplete batch. `[NEW; crowd §6.1, §10.3]`

### 5.1 Pause commands and exact overload semantics

**ARCH-CMD-001.** Settlement command records use the field layout in §8 and sort by `(execute_tick,player_id,sequence_high_unsigned,sequence_low_unsigned)`. This preserves the crowd's player/64-bit-sequence ordering within a tick. Player ID is 0 in release 1 `[NEW]`. Assign each submitted command `execute_tick=completed_tick+1`; paused edits receive the same next tick, increasing sequence. Their ghosts/pending rows are presentation only. Save pending commands when paused without consuming them. `[GDD REQ-SET-005, REQ-SET-159; crowd §6.2, §6.4; UI §3, §5]`

**ARCH-CMD-002.** Queue speed/pause scheduler events separately from economic commands. Pause takes effect before another tick starts. UI pause reasons are PLAYER, MENU, CRITICAL, VICTORY, LOAD and combine as a bitmask `[UI §3]`; requested speed persists separately from the effective paused state. Selection/name-editor previews, modal cancellation, camera, and roof state consume no authoritative RNG. A confirmed name change is an ordinary next-tick command; a name preview is not. `[GDD §5.1, §5.3; UI §5]`

**ARCH-CLOCK-001.** Use integer host-clock debt units `[NEW]`: accumulate `elapsed_microseconds*30*effective_speed`; one tick costs 1000000 debt units. Host timing is a scheduler input, never a gameplay-rate input. At most 8 ticks/frame are scheduled `[NEW work ceiling]`. Preserve remaining debt; never discard completed or owed ticks to hide sustained overload. After this loop, measure real-equivalent backlog as the exact fraction `debt/(30*effective_speed*1000000)` seconds. Compare without division: overload iff `4*debt > 30*effective_speed*1000000`, matching strictly greater than 1/4 real second `[GDD REQ-SET-008]`.

**ARCH-CLOCK-002.** On overload change 4→2 or 2→1 once per rendered frame and retain debt in the same tick units; do not scale or drop it. At 1× set the CRITICAL diagnostic pause before another frame's ticks. Retain debt while paused. When a normal player pause is requested, discard only sub-tick presentation debt after all queued whole ticks have either drained or been explicitly acknowledged in an overload recovery action `[NEW policy]`. Explicit “resume without wall-time catch-up” may clear scheduler debt, but never alter completed state or pending command ticks; record this scheduler event. No automatic speed increase occurs. `[GDD §5.1; crowd §6.3]`

**ARCH-CLOCK-003.** Instrument each system with host microsecond timestamps outside its authority boundary. Keep the latest 300 tick samples per stage `[NEW sample window]`, expansions, processed rows, allocation deltas, completed tick, requested/effective speed, and backlog numerator. The diagnostic reports the stage with greatest accumulated microseconds across that window, its p95/p99, and the latest failing tick's stage costs. For N samples use nearest-rank percentile index `ceil_div(p*N,100)-1`. A threshold failure never lowers offscreen need/ecology accuracy. `[GDD REQ-SET-164; crowd §11.2]`

## 6. Job lifecycle and transaction protocol

```text
QUEUED -> candidate validation -> all-or-nothing reservations -> RESERVED
                                                              |
                              path queued -> TRAVEL -> WORK
                                                      |
                              optional passive wait in WORK
                                                      |
                                     outputs committed -> HAUL_OUTPUT
                                                              |
                                                          COMPLETE

Any invalid mandatory input/path/tool -> BLOCKED -> reevaluate -> QUEUED
Cancellation/death/expiry -> release leases -> settle WIP/refunds -> CANCELLED
COMPLETE/CANCELLED -> emit one event -> deferred retirement
```

**ARCH-JOB-001.** Preserve JobState values QUEUED=0, RESERVED=1, TRAVEL=2, WORK=3, HAUL_OUTPUT=4, COMPLETE=5, BLOCKED=6, CANCELLED=7 `[GDD §4.3]`. Passive wait is a saved phase within WORK, not a new numeric JobState. Each resident has at most one active job. Multi-member expeditions own one party-work counter; sum members' productive rates once, keep one member-job assignment per worker, and do not multiply completed output by crew count. `[GDD §4.2, §5.4–5.5; NEW phase mapping]`

**ARCH-JOB-002.** Eligibility order is health/rescue safety → activity → nonzero job priority → station/tool/skill/unlock → danger consent → complete inputs → legal destination. Urgency buckets 0 rescue/feeding incapacitated, 1 personal critical needs, 2 food/fuel while reserve<2 days, 3 ordinary work, 4 cosmetics. Within the bucket sort `(player_priority,job_priority,-skill_level,estimated_path_cells,created_tick,job_id)`. Scan at most 32 indexed candidates per pass; idle residents evaluate every 30 ticks staggered by persistent ID mod 30. Save the scan cursor, last evaluated rank revision, and next-pass tick. `[GDD §5.3]`

**ARCH-JOB-003.** Reservation transaction sequence: validate all handles → bind concrete input lots in GDD expiry order → calculate exact input discount using frozen lead level → reserve output mass/slots → reserve every input quantity → bind worker/party → commit. If a step fails, roll back only this transaction's provisional rows. Recipe input consumption occurs once at work start; delivered construction materials are consumed when build work starts. Input consumption and creation of WIP are one atomic state change. `[GDD §5.7–5.9]`

**ARCH-JOB-004.** Renew owned travel leases every 30 ticks; release after 300 ticks without owner renewal. A destination confirmed unreachable for 300 ticks becomes BLOCKED, releases leases, and retries after 900 ticks or map revision, whichever occurs first. Waiting for a queued path is not a confirmed unreachable result; a living owner may renew while its request remains queued. Cancellation followed by requeue cannot preserve a reservation under a different job. `[GDD §5.3 REQ-SET-032–033; NEW churn identity guard]` When food spoils, atomically invalidate its reservations, create equal-mass waste under the GDD item conversion, and replan dependents by job ID. A cancelled consumed food batch returns floor(half food input mass) as spoiled_food, not intact recipe inputs; construction uses its different 100%/80% cancellation and 50% demolition rules. These refund paths must not share an undifferentiated “refund all” helper. `[GDD §5.7 REQ-SET-094, §5.8, §5.9]`

**ARCH-JOB-005.** Completion is a transition identified by `(job persistent_id,generation,completion_sequence)` `[NEW]`. Apply XP, mastery/portion counters, output lots, wear, and release exactly once. Resource ownership remains valid throughout cancellation, output hauling, worker death, and save/load. A refused output allocation keeps the completed WIP with its reserved output obligations; it never silently removes production.

## 7. Deterministic navigation and movement

**ARCH-PATH-001.** The settlement map is 256 m square, 128×128 exterior tiles `[GDD §5.1]`. Navigation cells are 1/2 m, producing 512×512=262144 cells; cell ID=`z*512+x`. Bounds and origin are settlement-specific; do not copy the battle's 256×256 map index. Use static integer walkability, terrain, height, and clearance. Resolve doors/furniture and blueprint cut-route checks against the same authoritative mask. This ground-only baseline keeps birds grounded; no AIR/WATER fallback is inferred from a species label. SET-MOVE-001 requires an expanded location/connection contract for swimming, diving, tunnels and climbing; this flat cell ID cannot identify the complete world. `[GDD §5.11; crowd §5.1]`

**ARCH-PATH-002.** **Flat baseline algorithm only.** SET-MOVE-001 §4 requires a Dijkstra reference and a proven admissible heuristic before using nonlocal/domain connections; the cache and readiness rules below also need profile/domain revisions. A* uses N,E,S,W,NE,SE,SW,NW expansion order, edge costs 10 orthogonal/14 diagonal, no diagonal crossing when either adjacent orthogonal cell is blocked for clearance. Heuristic=`10*(dx+dz)-6*min(dx,dz)` for nonnegative cell differences. Indexed min-heap compares `(f,cell_id)`; on equal g retain the predecessor with lower cell ID `[NEW equal-g rule]`. Each cell has at most one heap entry, with decrease-key. Every removed/finalized search cell counts toward the global 2048 expansions/tick; blocked/duplicate neighbors are not expansions. Queue requests by job persistent ID, then request generation. `[GDD §5.11; NEW heuristic and heap implementation]`

**ARCH-PATH-003.** Macro cells contain 16×16 navigation cells `[NEW]`. The primary cache key is `(start_macro,goal_cell,clearance_class,map_revision)` `[GDD §5.11]`. Because two starts in the same macro can lie on opposite sides of a wall, this key identifies a **bucket**, not proof that any local start can reach its route. A bucket stores a canonical macro anchor and its full route to the exact goal. Choose the lowest passable cell in the macro as anchor; run a local A* from the actual start to that anchor constrained to the macro, with the same clearance/corner rules. If disconnected, run a full exact-start A* and store it as a bucket variant keyed additionally by start_cell. Never reuse a route across disconnected local components. `[NEW entry-segment design]`

**ARCH-PATH-004.** Goal is an exact cell, so the final segment terminates at that cell; a quantized within-cell interaction point uses a checked integer supercover segment and does not trigger another global route. Paths are unsmoothed cell chains for authority; visual root interpolation is separate. Local-entry, exact-route, and invalidation searches all share the 2048-expansion quota. An incomplete search cannot expose a traversable prefix. A resident with no prior valid path waits; an existing path may continue only while all traversed cells still satisfy the current revision. `[GDD §5.11; crowd §5.1, §6.1; NEW local segment rules]`

**ARCH-PATH-005.** Cache 256 descriptors and a shared arena of 1048576 int32 route cells `[NEW]`. The arena can hold four worst-case 262144-cell simple paths; it is not a guarantee of 256 simultaneous worst-case routes. Evict unreferenced descriptors by `(last_use_tick,cache_id)`. Referenced routes cannot be evicted. When descriptors/arena are full, keep a completed path as the active request result if its reserved arena space exists; otherwise leave the request blocked on route storage with an explicit diagnostic. Do not pretend this condition meets the latency budget. Incrementing map_revision invalidates descriptors; cancel/restart partial searches in job-ID order and release obsolete arenas at a tick boundary. `[GDD §7, §5.11 REQ-SET-164; NEW bounded cache/refusal]`

**ARCH-PATH-006.** Store complete in-progress heap, parent, g-score, state stamps, neighbor cursor, request order, and consumed quota at save boundaries. Completion visibility is a deterministic tick, not a worker callback. Save completed cache descriptors, IDs/generations, keys, refcounts, last-use ticks, and exact route cells. Rebuilding paths on load without preserving readiness/eviction decisions can break next-tick parity; restore these instead. `[GDD REQ-SET-160; crowd §6.4, §12.1]`

### 7.1 Latency arithmetic and rejected guarantee

**ARCH-PATH-007.** The 1/4-real-second p95 target at 1× allows at most 7 complete 30 Hz tick intervals under a conservative one-tick enqueue phase, hence `7*2048=14336` expansions before a request misses the deadline `[DERIVED: GDD §5.1, §7, §5.11]`. For a serial burst of N uncached queries each requiring E expansions, the nearest-rank p95 query is `ceil_div(95*N,100)` and completes no earlier than `ceil_div(E*ceil_div(95*N,100),2048)` ticks after service starts, plus enqueue phase. Population alone cannot determine the answer.

| Requests | Expansions/request | p95 request index | Expansions through p95 | Minimum builder ticks | Status relative to 7-tick allowance |
|---:|---:|---:|---:|---:|---|
| 12 | 256 | 12 | 3072 | 2 | Fits builder allowance only |
| 24 | 256 | 23 | 5888 | 3 | Fits builder allowance only |
| 48 | 256 | 46 | 11776 | 6 | Fits builder allowance only |
| 58 | 256 | 56 | 14336 | 7 | Boundary |
| 59 | 256 | 57 | 14592 | 8 | Fails |
| 80 | 256 | 76 | 19456 | 10 | Fails |
| 120 | 256 | 114 | 29184 | 15 | Fails |
| 180 | 256 | 171 | 43776 | 22 | Fails |
| 256 | 256 | 244 | 62464 | 31 | Fails |

All table inputs other than required population cases are `[NEW workload]`; outputs are `[DERIVED]`. At 256 queries the builder alone needs at least 31/30 real seconds; cache hits and nearby paths can improve a measured normal workload, but cannot establish a universal guarantee. Even one legal maze route may require more than 14336 expansions. The architecture therefore **does not satisfy an unconditional p95 route guarantee at any positive population**; it defines a qualification workload and records failure instead of changing the fixed quota.

**ARCH-PATH-008.** Benchmark cached routes, 256 distinct short routes, a 256-request 256-expansion burst, and a labyrinth whose only route visits more than 14336 cells `[NEW fixtures]`. Record request tick, queue wait, local/full expansions, completion tick, cache result, and route-storage blocking. A release claim requires p95≤1/4 second on the agreed normal workload, with failure scenes disclosed; native code cannot fix quota-limited latency unless a versioned GDD decision changes the quota or algorithm. `[GDD REQ-SET-163–164; crowd §5.1, §10.3]`

**ARCH-MOVE-001.** Reuse the crowd's bounded integer grid/separation method: 2 m spatial cells, scan at most 64 candidates, retain nearest 12 by squared distance then persistent ID, two Jacobi iterations reading immutable iteration positions, integer square root, signed truncation, and displacement remainder across 30 ticks. For the settlement's map the grid is 128×128. Static movement legality uses settlement clearance masks. Report scan truncation and persistent overlaps; do not describe soft separation as exact collision. `[crowd §5.3; GDD §5.11]`

## 8. RNG, canonical state, replay, and binary saves

**ARCH-RNG-001.** Use the crowd's xorshift32 exactly. Read signed stored state with `& 0xffffffff`; replace a zero initialized state with 1. The fixed test stream from seed 1 begins 270369,67634689,2647435461,307599695,2398689233. `[crowd §6.1, §12.2 GT-004]`

```text
x = state & 0xffffffff
x = (x XOR ((x << 13) & 0xffffffff)) & 0xffffffff
x = (x XOR (x >> 17)) & 0xffffffff
x = (x XOR ((x << 5) & 0xffffffff)) & 0xffffffff
hash_pair(a,b):
    h = (a XOR 0x9e3779b9) & 0xffffffff
    h = (h*1664525 + 1013904223 + (b & 0xffffffff)) & 0xffffffff
    return (h XOR (h >> 16)) & 0xffffffff
```

**ARCH-RNG-002.** Compile the following stream keys in ASCII order; seed each with `hash_pair(world.seed,stream_id+1)`, replacing zero with 1 `[NEW stream domains; crowd hash algorithm]`. Store state plus int64 draw count. No other system may consume these streams. Bounded selections use modulo with the same disclosed small bias as the crowd document; no rejection sampling changes unspecified draw counts.

| Stream | Exactly when it advances | Ordering / discard rule | Provenance |
|---|---|---|---|
| ECOLOGY | One wildlife-pressure roll per eligible summer/autumn basin/apiary at midnight | Persistent basin/apiary ID; consume even when the affected stock is empty | [GDD §5.9; NEW draw discipline] |
| FISHING | One hazard and one rare-quality roll per completed eligible fishing cycle | Expedition ID; closed/invalid cycles cancelled before departure consume none; already departed cancelled cycle retains saved rolls | [GDD §5.4; NEW draw discipline] |
| FORAGE | One hazard roll after each completed 60 WU exposure segment in natural danger≥1 | Worker ID, segment sequence | [GDD §5.5; NEW segment ordering] |
| HUNTING | Retired stream; never draw in rules v2 | Keep original seed initialization and zero draw_count; noncanonical loaded values fail validation | [AMEND-001: retained slot/key, no active hunting] |
| IMMIGRATION | Two skill-selection rolls per generated candidate | Event day, candidate index; duplicate second skill maps to next skill modulo 12 | [GDD §5.11; NEW distinct-skill draw mapping] |
| MAP | Map generation choices only | Attempt, tile ID, feature ID; generation state retained | [GDD §5.1; NEW stream isolation] |
| QUALITY | One roll per batch whose inputs commit | Job ID; `R=(draw mod 21)-10`; never reroll on worker swap | [GDD §5.7] |
| SOCIAL | One roll per eligible conflict pair at 18:00 | Room ID then ordered pair IDs; consume for every eligible pair, resolve lowest-ID passing pair | [GDD §5.3; NEW draw discipline] |
| WEATHER | One weighted event-selection roll per new season after the forced first spring. **Roll-to-row mapping ruled 2026-09-09**: scan §5.10's printed event order filtered to eligible rows, raw integer weights, `roll = draw mod weight_sum`, strict `roll < cumulative`. Sums: spring 85, summer 120, autumn 135, winter 110. Modulo bias disclosed; rejection sampling remains forbidden | Season index ORDERS the event and shall not cause per-season reseeding; forced onboarding event consumes zero draws | [GDD §5.10; decision 0028] |

Names and candidate species use deterministic hashes/cycles, not these stochastic streams `[GDD §5.3, §5.11]`. Rendering phase uses a separate stateless hash `[crowd §3.2]`. RNG draw state is included in saves and hashes.

### 8.1 Command and save byte formats

**ARCH-SAVE-001.** All saved integers use explicit little-endian encoding and two's-complement bit representation; strings use length-prefixed UTF-8 without object serialization. No engine Resource serializer, Dictionary order, RID, NodePath, or machine-native memory dump is the canonical format. The layout below is `[NEW]`, keeping `[crowd §6.4]` byte-order/hash conventions.

| Command offset | Type | Field | Bytes |
|---:|---|---|---:|
| 0 | i64 | execute_tick | 8 |
| 8 | i32 | player_id | 4 |
| 12 | u32 bits | sequence_low | 4 |
| 16 | u32 bits | sequence_high | 4 |
| 20 | i32 | kind | 4 |
| 24 | i32 | target_slot | 4 |
| 28 | i32 | target_generation | 4 |
| 32 | i32 | goal_x | 4 |
| 36 | i32 | goal_z | 4 |
| 40 | i32 | arg0 | 4 |
| 44 | i32 | arg1 | 4 |
| 48 | i32 | payload_offset | 4 |
| 52 | i32 | payload_length | 4 |
| 56 | i32 | flags | 4 |
| 60 | i32 | reserved_zero | 4 |

Command stride is 64 bytes `[DERIVED sum]`. Variable payloads contain full selection ID lists, schedule bytes, zone tiles, recipe orders, or sanitized aliases; the payload schema is selected by the command kind. Use an append-only replay stream and a 4096-command in-memory queue plus a 1048576-byte payload arena `[NEW]`. Queue overflow refuses additional edits with an explicit UI error; accepted commands are never dropped. Settlement ticks use int64, unlike the crowd's 48-byte command record with int32 tick; direct binary reinterpretation is prohibited.

**ARCH-CMD-003.** Command kinds `[NEW sorted ASCII domain]` are ACCEPT_CANDIDATES, APPOINT_WARDEN, ASSIGN_BED, CANCEL_JOB, CANCEL_MANUAL, CONFIRM_FEAST, DEMOLISH, DESIGNATE_ROOM, DESIGNATE_ZONE, EDIT_ORDER, EQUIP, NAME_RESIDENT, PLACE_BLUEPRINT, PLACE_FURNITURE, REQUEST_RELIEF_SEEDS, SET_ACTIVITY_SCHEDULE, SET_DOOR_OPEN, SET_FIELD_ROTATION, SET_JOB_PRIORITIES, SET_MANUAL_TASK, SET_POLICY, SET_STORE_FILTER, SET_STORE_MINIMUM, UPGRADE. Compile IDs from this exact list; reject unknown kinds. Kind-specific payloads use the original component field types, count first followed by owner-ID-sorted rows; all IDs must validate before committing any member of a group. `[GDD §4.2; UI §5; NEW command domain]`

| Save header offset | Encoding | Meaning | Bytes |
|---:|---|---|---:|
| 0 | ASCII | Magic RWLSET01 | 8 |
| 8 | u32 | Format version 1 | 4 |
| 12 | u32 | Header bytes 256 | 4 |
| 16 | u32 | Endian sentinel 16909060 | 4 |
| 20 | u32 | Section count | 4 |
| 24 | u64 | Total file bytes | 8 |
| 32 | i64 | Completed tick | 8 |
| 40 | SHA-256 bytes | Rules hash | 32 |
| 72 | SHA-256 bytes | Catalog hash | 32 |
| 104 | SHA-256 bytes | Map hash | 32 |
| 136 | SHA-256 bytes | Integer lookup-table hash | 32 |
| 168 | SHA-256 bytes | Engine patch/build identity hash | 32 |
| 200 | u64 | Section table offset, always 256 | 8 |
| 208 | u64 | Chronicle record count | 8 |
| 216 | u64 | Replay command sequence at checkpoint | 8 |
| 224 | SHA-256 bytes | Body digest over table plus section bytes | 32 |

Each section descriptor is 64 bytes: `section_id:u32, schema_version:u32, offset:u64, byte_length:u64, row_count:u64, crc32:u32, flags:u32, reserved_zero:24 bytes` `[NEW]`. CRC is CRC-32/ISO-HDLC: polynomial reversed 3988292384, initial register 4294967295, reflected bytes, final XOR 4294967295; check vector ASCII `123456789` gives 3421780262 `[NEW codec choice]`. SHA-256 protects the complete canonical body; CRC localizes corruption. Header numeric/hash fields other than the stored body digest receive their own hash through the canonical state domain described next, so a changed completed tick is detected by state verification, not CRC alone.

**ARCH-SAVE-002.** Section IDs are assigned in this exact order `[NEW]`: 1 WORLD, 2 CATALOG_IDS, 3 ENTITY_DIRECTORY, 4 COMPONENT_COLUMNS, 5 CHILD_ARENAS, 6 AUXILIARY_STATE, 7 INVENTORIES_AND_LEASE_INDEXES, 8 JOB_INDEXES, 9 NAVIGATION, 10 RNG, 11 EVENT_SCHEDULE, 12 PENDING_COMMANDS, 13 CHRONICLE, 14 NAME_POOL, 15 STATE_DIGEST. In each typed store serialize occupied bitset, all generations including free/retired slots, then columns in §2 field order by ascending slot. Encode zero for unused field payload while preserving generations and allocator-retirement state. Child arrays use owner ascending then child index; explicit variable lengths precede data. Save allocator heaps or rebuild them deterministically from occupancy and retired masks; active lists are rebuilt ascending.

**ARCH-HASH-001.** Canonical state hash is SHA-256 over domain string `RWL-STATE-1`, rules/catalog/map/lookup hashes, exact engine build string, completed tick, all authoritative occupied/generation and typed fields in schema order, variable children, all auxiliary future-affecting state, pending commands in execution order, RNG states/draw counts, navigation progress/cache eviction state, and the Chronicle count plus rolling digest. The Chronicle rolling digest is `SHA256(previous_digest || encoded_record)` starting with 32 zero bytes `[NEW streaming history representation]`; a save validates the full stream against it. Include current/previous authoritative Transform fields, not first-frame presentation overrides. Exclude selected flags, camera, UI panels, skin/LOD/batch slots, host scheduler debt, allocator addresses, timing metrics, and derived spatial/active indexes. `[GDD §4.2, REQ-SET-159–160; crowd §6.4]`

**ARCH-HASH-002.** Hash every tick in verification mode and every 300 ticks in ordinary replay recording `[crowd §6.4]`. End-of-tick hashing may exceed normal timing budgets in verification mode; report that mode separately instead of hiding its cost. On mismatch dump section digest, first different field/slot/child index, RNG draw counters, pending path progress, and last 30 commands `[crowd §6.4]`. Comparing only a final digest is insufficient for the parity gate.

### 8.2 Transactional save/load

**ARCH-SAVE-003.** Save only a completed boundary. Freeze the authoritative snapshot while streaming to a sibling temporary file; stream Chronicle and large sections in 65536-byte chunks `[NEW]`, calculating CRC/digest incrementally. Flush and close, re-open and validate the written header/section checksums, then rename into its target slot. A failed write leaves the prior valid save and source world intact. Use five rotating daily autosaves plus separate prewinter and pre-major-demolition saves `[GDD REQ-SET-158]`; user quicksave is separate `[UI §5]`. Do not rotate the good slot until new validation succeeds.

**ARCH-SAVE-004.** Load sequence SHALL be: pause old world → write and verify its rollback checkpoint → parse incoming fixed header without another world allocation → check magic/endian/version/tick bounds → require all 15 unique section IDs → check nonoverlapping ranges, exact file length, overflow-safe offsets → verify hashes/CRC by streaming → check rules/catalog/map/lookup/engine compatibility → stream-decode incoming data into an inactive normalized checkpoint with every §2 capacity/type/range check → validate refs, unique persistent IDs, relationship a<b/degree, inventory sums, reservations, job ownership, and pending deadlines using sorted on-disk indexes → recompute incoming state digest → reuse one world's arrays to decode the validated checkpoint while LOAD hides gameplay → rebuild derived indexes/render handles → recompute state digest again → publish atomically → present previous=current → resume only after LOAD closes. The validator uses the existing 65536-byte stream buffers and temporary files for sorted joins, never another full WorldStore. Failure before array reuse leaves old state resident; failure after reuse restores the verified rollback checkpoint under ARCH-MEM-006. Preserve the incoming file in every failure case. `[GDD REQ-SET-159–161; UI §4.3, §9 UX-T12; NEW validation order]`

**ARCH-SAVE-005.** Validate `quantity≥0`, `0≤reserved≤quantity`, each reservation sum equals its lot's reserved_milli, each container's charged mass plus reserved mass does not exceed capacity, living≤256, resident rows≤512, every child count within its fixed bound, and catalog indices within their verified domains. Reject nonzero reserved padding, invalid enum values, future format versions, illegal negative lengths, multiplication overflow, and malformed UTF-8. Player aliases are 2–32 Unicode characters with control characters rejected `[UI §4.3, §5]`; never use localized display strings to order simulation.

**ARCH-SAVE-006.** Next-tick parity test: fork canonical state at tick 3000, run uninterrupted to tick 18000; separately save/load at 3000 and continue with the same pending commands. Compare every tick 3001–18000 `[crowd §6.4, GT-012; GDD REQ-SET-160]`. Repeat at an exact midnight, active passive batch, expired lease, dying resident, and partial A* heap `[NEW coverage cases]`. The load screen may take longer to rebuild render resources; that elapsed time advances no simulation.

## 9. Godot runtime, UI, and rendering boundary

**ARCH-GODOT-001.** Autoloads are EntityManager (world store/directory), GameManager (scheduler/session/save coordination), EconomySystem (fixed settlement system registry), UIManager (input/snapshots), AudioManager (optional presentation) `[NEW five-service allocation; CLAUDE.md Architecture; max 6]`. CombatSystem is not loaded in the settlement release. Render services belong under the active scene and consume snapshots. There is no per-resident autoload, signal bus subscription, `_process`, physics body, NavigationAgent3D, Timer, or AnimationTree. At most 24 close-up skeletal actors are pooled; overflow uses the crowd representation `[GDD REQ-SET-162–163; crowd §2, §4.1]`.

**ARCH-GODOT-002.** `Array[int]` stores Variant payloads despite type checking; in the selected standard build a Variant occupies 24 bytes, while one packed int32 is 4 bytes. Thus N integer entries occupy 24N versus 4N payload bytes, a 6/1 ratio and savings 20N bytes before container headers. At N=512, payload is 12288 versus 2048 bytes, saving 10240; packed int64 is 4096, saving 8192. Engine source documents the 24-byte standard/40-byte double-precision Variant distinction; these calculations assume the pinned standard build, not a universal Object size. [Godot 4.7.2 Variant declaration](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/variant/variant.h). No fixed byte cost is invented for a Node or Resource object.

**ARCH-GODOT-003.** Systems call each other through the fixed registry and explicit data contracts, not signals. Signals flow **outward** from committed simulation events/snapshots to UI/audio/rendering; player intentions flow inward through the ordered command queue. A signal handler cannot edit authoritative columns or synchronously reenter a running system. Snapshot buffers are double-buffered and immutable to consumers. `[CLAUDE.md Architecture; GDD REQ-SET-162; NEW enforced API direction]`

**ARCH-UI-001.** Keep simulation summaries as dirty-counter-driven cached values: food/potential/fuel recompute every game hour and on committed stock/policy changes; roster rows update only when changed. UIManager reads snapshot version once/render frame, applies at most 64 dirty row updates and 32 notice events/frame `[NEW bounded view work]`, and continues remaining view-only work next frame. Critical pause/error state bypasses ordinary row scheduling. Virtualize resident, lot, job, and history lists; no full registry scan or per-frame Node creation. UI work remains independent of hourly/daily simulation and must meet p95≤1.5 ms `[GDD REQ-SET-162–163; UI §9 UX-T14]`.

**ARCH-UI-002.** Keep the UI document's six-zone layout, breakpoints, element IDs, input precedence, pause reasons, and accessibility behavior. View commands use generation-validated persistent identity, never render instance slots. All UI-only decimals derive from integer numerators: food_days_centi=`floor_div(100*ready_NP,daily_NP)` and display integer part plus two-digit remainder; zero heat demand displays the specified text. A pending preview is not a stock transaction. `[UI §1–5, §7–9; GDD §5.8]`

**ARCH-RENDER-001.** Extract current/previous integer transforms to presentation-only numeric buffers, then apply the crowd's interpolation and stable visual-row mapping. Pause snaps to the completed tick and freezes animation time while camera/UI remain active. Disable engine interpolation on ECS nodes when using this custom interpolation. Retain prior-tick intent for event-aligned animation. Settlement selection controls skeletal priority but never changes simulation rates or needs. `[crowd §2.4, §6.3; GDD §5.1; UI §3]`

## 10. Explicit battle adapter

**ARCH-TRANSFER-001.** Transfer execution remains disabled and its UI hidden in settlement release 1 `[GDD §8; UI REQ-UX-014]`. The adapter contract is nevertheless explicit: `manifest_id`, source/destination rules/catalog hashes, resident persistent ID, species key, HP, all 12 skill XP values, tool/outfit/gear instances with durability, and item lots with quantity/quality/age/provenance are validated together. Use a manifest transaction journal with PREPARED/COMMITTED/RETURNED states `[NEW]` and idempotent application by manifest ID. No citizen is alive under two simultaneously advancing ownership domains.

**ARCH-TRANSFER-002.** Map each species/equipment key through an explicit catalog conversion table; reject an unmapped key, never clamp to the first species. Carry persistent citizen ID unchanged; allocate a new battle slot/generation and record both handles. Settlement HP is 0–100; battle entry sets hp to settlement health and max_hp=100 for the shared fixture only `[NEW adapter profile; crowd §5.4]`. Battle skill values are a different stat domain: conversion requires a versioned profile and is disabled until that profile exists; do not cast XP to attack_skill. Settlement positions in a 256 m map do not transfer directly into the 128 m battle map; entry placement uses battle spawn slots. Relative transforms can be converted by a manifest-specific integer origin translation with range validation. `[GDD §4.1, §8; crowd §4.1–4.3, §5.1]`

**ARCH-TRANSFER-003.** On return, validate battle outcome ownership, carry HP/durability/consumed goods once, retain original settlement XP and apply only explicitly attributed XP deltas. Death returns a chronicle event and inventory disposition, not a recycled resident. The original schema's TransferManifest remains present but inactive; this release does not invent army entities, campaign trade, combat stat progression, or giant recruitment. `[GDD §8; NEW boundary discipline]`

## 11. Prototype migration plan

Repository inspected at commit `35b98cc1a1a92d7b59ed44306527f7ad85886009`. The source inventory contains 52 test methods: EntityManager 17, EconomySystem 16, GameManager 10, CombatSystem 9 `[OBSERVED source count]`. Running the unchanged prototype in an isolated local copy with Godot 4.7.2 returned **52 tests, 106 assertions, 0 failures, exit 0**. The run printed a macOS certificate lookup diagnostic and the deliberate unknown-resource error exercised by its negative test. This is a prototype compatibility baseline, not evidence that settlement rules are tested. No prototype file is changed by this planning task.

| ID / existing code | Decision | Concrete replacement and retained test meaning | Provenance |
|---|---|---|---|
| ARCH-MIG-001 `scripts/systems/entity_manager.gd` | Rewrite | Replace Dictionary-per-component/Resource instances with §2 columns and directory handles. Preserve monotonic persistent IDs but reuse runtime slots. Keep tests for unknown/dead entity rejection, removal, intersection queries, and safe iteration; replace object-reference assertions with column/ref assertions. Split `test_destroyed_ids_are_never_reused` into persistent-ID nonreuse and slot-reuse-generation validation. | [Observed prototype; GDD §4.1–4.2] |
| ARCH-MIG-002 `scripts/systems/economy_system.gd` | Rewrite | Remove four generic stockpiles, per-second rates, tolerance-based spending, silent cap trimming, and discarded accumulator debt. Implement lot quantities, mass, WIP, reservations, sources/sinks, and fixed-tick production. Retain all-or-nothing spending/nonnegative/unknown-key tests with concrete item IDs and milli-U. Replace tiny-rate cases with retained-remainder tests. | [Observed prototype; GDD §5.7–5.8] |
| ARCH-MIG-003 `scripts/systems/game_manager.gd` | Rewrite | Replace speed multipliers 1,2,3 and Engine.time_scale with §5 scheduler, 1,2,4, calendar, pause reasons, and next-tick commands. Keep boot/start/pause idempotence tests; replace Engine.time_scale assertions with invariant 1 and completed-tick comparisons. | [Observed prototype; GDD §5.1; UI §3] |
| ARCH-MIG-004 `scripts/systems/combat_system.gd` | Delete from settlement runtime | Remove autoload and settlement call sites only after health/needs/lifecycle tests replace its accidental responsibilities. Keep its 9 tests temporarily as legacy prototype tests; later archive them under a nonrelease test directory or remove them with an explicit migration record. Do not import its direct damage/death rules into settlement hazards. The battle system is separately specified. | [Observed prototype; GDD §5.2, §8; crowd §5.4] |
| ARCH-MIG-005 Resource components / current HUD | Migrate then retire | Rewrite Position/Health Resource consumers against immutable snapshots and ID validation; remove runtime component classes after no references remain. Keep UI formatting ideas, replace generic four-resource and obsolete speed bindings with UI-SET IDs and InputMap contract. | [Observed prototype; UI §4–5] |

**ARCH-MIG-006.** Execute in this order `[NEW migration sequencing]`:

1. Preserve a clean source baseline and run the current test runner. Record its real result; do not call source method counts a passed suite.
2. Add integer helpers, catalog compiler, golden GDD fixtures, and isolated new store modules. Keep old tests running against old modules so failures have a known cause.
3. Add the new directory/slot lifecycle with overflow, stale-ref, child-capacity, and cancellation tests. Migrate EntityManager's meaningful semantics; do not keep Dictionary/object layout as a compatibility constraint.
4. Add clock/calendar/command replay and pause tests before any needs/economy system. Switch GameManager only when exact tick/calendar tests pass.
5. Implement inventory/leases/gear metadata and source/sink accounting; replace EconomySystem and old resource HUD bindings together after transaction tests pass.
6. Implement needs/health/schedules/work, then ecology/crops/weather, then buildings/rooms, recipe/passive batches, feasts/immigration/progression. Add each system's GDD acceptance fixtures and cross-system invariants before enabling it in the active scene.
7. Switch all settlement consumers off CombatSystem, remove its autoload, and run the retained health/death/unknown-ref tests through settlement health/lifecycle. Separate the legacy battle prototype tests from release settlement tests.
8. Add transactional saves, replay parity, maximum-capacity fixtures, UI snapshots, and BAL-RUN strategy automation. Execute the missing actual survival runs before claiming the economy works.
9. Export Windows release builds and run §12 qualification. A Mac pass is development evidence only.

Keep a test migration ledger `old_test_name,new_test_name,retained_semantic,retirement_reason` `[NEW]`. A lower test count is acceptable only when duplicate/obsolete assertions are explicitly accounted for; a still-green old suite is not a reason to retain contradictory production behavior.

## 12. Qualification and initial execution checklist

**ARCH-PERF-001.** Required settlement gates are frame p95≤16.67 ms, p99≤20 ms, normal-speed tick p99≤2 ms, aggregate simulation CPU/frame at 4× p95≤6 ms, UI p95≤1.5 ms, simulation-owned RAM≤100000000 bytes, process≤4000000000 bytes, route-ready p95≤1/4 real second at 1×, and at most 24 skeletal actors `[GDD §5.11 REQ-SET-163]`. Interpret MB/GB as decimal for this settlement budget `[NEW unit disambiguation]`; the crowd document separately uses some binary GiB budgets. Budget targets are not measured results.

**ARCH-PERF-002.** Qualify exported release builds on the Windows Ryzen 5 3600/GTX 1660 Super/16 GB reference floor and AMD RX 6600 driver companion, at 1920×1080, Vulkan and D3D12; Mac Metal is a development comparison `[crowd §0.2–0.3, §8; GDD §5.11]`. Warm 60 real seconds, record 180, repeat 3 times, and take the slowest qualifying repeat; run a 20-minute soak `[crowd §0.3]`. Include all 256 living, maximal specified child stores, dense interiors, food expiry bursts, seasonal crossings, queued navigation, and 4× speed `[NEW settlement fixtures]`.

**ARCH-PERF-003.** A p99 tick budget of 2 ms does not by itself imply the aggregate 4× frame budget: at 60 rendered frames/second and 120 ticks/second the average is 2 ticks/frame, but catch-up may execute up to the chosen 8-tick limit. Measure the aggregate separately; use the inherited overload policy if debt persists. Native optimization can reduce CPU work but does not change fixed expansion-limited route readiness. `[DERIVED: GDD §5.1, REQ-SET-163; NEW 8-tick implementation cap]`

**ARCH-PERF-004.** The executable checker at `docs/validation/qualify.py` SHALL receive the measured CSV/JSON contract in `docs/validation/README.md`. It requires every individual tick sample, reconciles frame/tick counts and CPU totals, calculates nearest-rank percentiles, uses memory maxima, checks the complete Windows matrix, and compares every supplied save/load state digest. Missing evidence returns `BLOCKED` with exit 2; an isolated capture pass cannot award full qualification. Submitted coverage and visual-review attestations remain subject to review. The generated `validation-results/windows-status.json` currently reports `BLOCKED`; no absent runtime or hardware measurement is filled with an estimate. `[NEW executable evidence contract; thresholds ARCH-PERF-001–002]`

**ARCH-PERF-005.** The analytical cold-query bound is now executable in `docs/validation/arithmetic.py`: 256 distinct FIFO requests at 256 expansions each require 31 ticks at nearest-rank p95 under the fixed 2048 expansion quota. The 1× gate permits only 7 complete ticks. Retain the fixed quota and report failure for this workload; do not hide admission delay or silently increase work. `validation_resolution.md` §6 records exact source-amendment alternatives. `[GDD §5.11; DERIVED; NEW reference workload]`

- [ ] **ARCH-EXEC-001:** Generate every packed field in §2; assert byte lengths and GDD enum numeric values; compile immutable catalog IDs.
- [ ] **ARCH-EXEC-002:** Implement all §3 auxiliary saved columns and their ownership constraints; do not use hidden script member state as unversioned authority.
- [ ] **ARCH-EXEC-003:** Test slot reuse, generation exhaustion, persistent-ID exhaustion, all child-capacity refusals, and identity across render migrations.
- [ ] **ARCH-EXEC-004:** Implement ordered commands, fixed scheduler, first midnight at 13500, exact 1/2/4 speeds, pause previews, and 4→2→1→pause overload behavior.
- [ ] **ARCH-EXEC-005:** Implement one deterministic system stage at a time in §5 order, with immutable read phases and atomic ownership commits.
- [ ] **ARCH-EXEC-006:** Implement A* and cache as §7; publish route-latency failures instead of concealing them as worker idleness.
- [ ] **ARCH-EXEC-007:** Implement and corrupt-test binary saves; verify next-tick parity and all RNG golden sequences on Mac/Windows.
- [ ] **ARCH-EXEC-008:** Complete the test migration ledger, then remove obsolete prototype runtime modules.
- [ ] **ARCH-EXEC-009:** Run actual three-year economy policies and starvation branches from gameplay_balance.md; record missing/failed gates explicitly.
- [ ] **ARCH-EXEC-010:** Measure live and transactional peak memory against the exact table and reserve; then run Windows frame/UI/path/soak qualification.

## Conflicts Found

| ID | Source and requirement | Finding | Decision / limit |
|---|---|---|---|
| ARCH-CONFLICT-001 | GDD §4.2; REQ-SET-091, REQ-SET-159–160 | Required behavior needs saved fields absent from the registry: tool instance durability, scan/lease progress, crop service/ripe dates, pending candidate choices, effect snapshots, RNG, and path-builder state. | Preserve every fixed field and add explicitly named §3 auxiliary tables. A strictly “no new state” reading cannot satisfy the behavior/save requirements. |
| ARCH-CONFLICT-002 | GDD §7 and REQ-SET-163 | At 2048 expansions/tick, a 256-query burst of 256-expansion routes needs at least 31 builder ticks at p95, exceeding 1/4 second. A long maze can fail with one requester. | Preserve quota; fail qualification for that workload. No positive population alone proves the response-time bound. |
| ARCH-CONFLICT-003 | GDD §4.2 ChronicleRecord; REQ-SET-163 | Append-only unbounded history cannot all reside in finite 100 MB RAM. Even at 24 bytes/record, 4166667 records exceed 100000000 bytes before every other component. | Stream history to disk with two 64-record pages and saved digest; total disk/save size remains unbounded. |
| ARCH-CONFLICT-004 | GDD §5.11 REQ-SET-155 | Winter-day-12 midnight evaluation precedes the end of the last winter day; three point samples do not prove continuous maintenance. | Do not certify M4 from starts-of-days 10,11,12 samples alone. `validation_resolution.md` §5 gives an exact proposed preceding-54000-tick interpretation, preserving the award instant. A source clarification and explicitly budgeted saved interval state are required before implementing that proposal. |
| ARCH-CONFLICT-005 | crowd §4.2 versus §5.1; GDD §5.1 | Crowd §4.2's coordinate guard is ±128 m but describes a 128 m square; §5.1's actual battle map is ±64 m. Settlement is 256 m square with its own origin. | Treat the wider crowd guard as a numeric safety range, not map bounds; use each layer's actual navigation map and explicit transfer placement. |
| ARCH-CONFLICT-006 | crowd §6.4 versus GDD §4.2 | Battle command tick is int32; settlement World.tick and deadlines are int64. Binary command strides are 48 versus this document's 64 bytes. | Share ordering/hash conventions but use versioned layer-specific codecs; never reinterpret records. |
| ARCH-CONFLICT-007 | UI §1.2 versus UI §4.1 UI-SET-008 | Resource overflow trigger is layout-dependent, while its registry row labels it ALWAYS. | Follow breakpoint visibility from UI §1.2; flag source wording for a UI revision. No new unregistered control is introduced. |
| ARCH-CONFLICT-008 | CLAUDE.md older design guidance versus Document Authority/GDD | Earlier logarithmic scaling, broader population language, and generic flow-field advice do not define this capped settlement. | Follow its Document Authority precedence and the settlement GDD; keep battle guidance in battle scope. |
| ARCH-CONFLICT-009 | READY_04 deliverables 1 and 6; REQ-SET-163 | Packed payload arithmetic can be bounded, but engine headers, allocator reserve, long route storage pressure, and real Windows stage timings are not certified by this document. | Budget these explicitly and report unqualified performance. Do not claim ≤100 MB or deadline support from payload arithmetic alone. |
| ARCH-CONFLICT-010 | Prototype implementation versus GDD REQ-SET-002–008, REQ-SET-162 | Current stockpiles/clock use noninteger authority, speed 3, Engine.time_scale, dropped debt, and Resource components. | Rewrite core modules under §11; the old 52-test suite tests a different model. |
| ARCH-CONFLICT-011 | READY_04 memory budget and transactional loading | Fully resident old plus candidate worlds require 120075772 bytes including reserve, exceeding 100000000 by 20075772. Reconciled 2026-09-07 for decisions 0019 and 0021 and ARCH-STATE-005 (119493108 / 19493108); 2026-09-09 for READY_06 §7, decision 0037 and ARCH-STATE-007; was 117599532 / 17599532 before those. | Select disk-backed validation/rollback with one reusable world allocation under ARCH-MEM-006 and ARCH-SAVE-004. Its planned resident payload plus reserve is 67339982 bytes; actual allocator/I/O peaks still require measurement. The one-world gate still holds with 32660018 bytes spare, but §3.1 lists budget items not yet counted at all. |

## 13. Verification record

Observed during document generation: all 140 memory-field group products satisfied `element_width*column_count*allocated_length=payload_bytes`; the complete allocation ledger summed to 57713254 bytes before the 8388608-byte reserve, the selected one-world design totalled 66101862 planned bytes with 33898138 below the decimal 100 MB gate, and the rejected two-world design totalled 117599532 bytes.

Reconciled 2026-09-07 against decisions 0019 and 0021 and the implemented `godot/scripts/core/jobs.gd` columns (ARCH-STATE-005), then 2026-09-09 against the READY_06 §7 ruling adding `TileHistory.family_streak`, decision 0037's `FishingEffortClaim` and ARCH-STATE-007's gear allocator (`godot/scripts/core/gear.gd`): all **159** memory-field group products satisfy that identity, the widened TileHistory I32 group included (7*4*16384=458752); the ledger now sums to **58951374** bytes before the same 8388608-byte reserve. The selected one-world design totals **67339982** planned bytes, **32660018** below the decimal 100 MB gate, so that gate still holds on payload arithmetic. The rejected two-world design totals **120075772** bytes and is rejected by a larger margin than before. §3.1 records what remains uncounted; the gate conclusion is therefore provisional on those items, not final. These are allocation arithmetic, not measured Godot process memory.

The required unfinished-text scan returned no matches; the balance document's forbidden-population and disallowed-formula scans returned no matches. Each document contains exactly one required conflict heading. Markdown tables/fences passed structural checks. The unchanged legacy prototype passed 52 tests and 106 assertions with exit 0; no new settlement implementation or Windows performance/parity run is claimed. Arithmetic probes and schema inspection do not resolve the documented survival, path-latency, or qualification gaps.

This planning task deliberately leaves both documents uncommitted for review.

Follow-up validation: 27 reference/arithmetic/evidence-checker tests pass, including both full-winter food/health controls and fail-closed handling of incomplete Windows evidence. All commands, assumptions, schemas and output locations are in `docs/validation/README.md`. `docs/validation_resolution.md` records observed outcomes and the remaining runtime/source/hardware dependencies. This adds executable validation tooling; it does not claim that the Godot settlement migration, actual memory measurement, three-year strategies or Windows replay qualification has been completed.

Mac continuation: `docs/validation/headless/` now contains tested typed GDScript controls for packed resident allocation, integer scheduling, winter needs/production and a separate reference checkpoint codec. The current suite passes 324 Godot checks and 33 Python tests, matches both Python winter traces exactly, and verifies 15000 consecutive post-load hashes plus 1×/2×/4× equality. A second Mac process loads the retained checkpoint and matches all 15001 recorded boundary/continuation hashes. These kernels do not constitute the full directory/schema migration or the ARCH-SAVE release format. Windows testing is deferred per the user; their reported 5090 GPU / 64 GB machine is recorded as USER-PC, without changing W-N/W-A qualification floors. See `validation_resolution.md` §9 and `docs/validation/WINDOWS_START.md`.

## ARCH-MOVE-001 — adopted movement integration obligations

Follow MOVE-REQ-001–020 and close MOVE-G02. Add finite packed location/connection/profile/reservation state, job/service work contacts, deterministic crossing queues, topology-edit transactions and versioned save migration. Keep resident and battle stores separate. Expand cache identity to include all legality-affecting profile/topology/domain state. Authoritative movement and arrival remain integer/tick decisions; rendering, animation events and physics callbacks cannot determine them.

Audit ARCH-JOB travel leases and unreachable timeouts against crossing queues: waiting for occupied access is not proof of unreachable geometry. Define reservation renewal/release and deadlock behavior explicitly; do not apply a blanket timeout that abandons an occupied dive or climb. Save pending readiness, queue order, progress and consumed budgets. Recompute all ARCH-MEM-derived arrays, directory totals, scratch/search storage and worst-case save payloads after finite geometry is settled. No expanded-memory or latency pass is claimed here.
