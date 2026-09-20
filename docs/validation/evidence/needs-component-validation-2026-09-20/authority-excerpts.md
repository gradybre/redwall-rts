## docs/game_gdd.md:302-330 SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e

302: | Comfort |100/hour | +300/hour in valid heated room; +100/hour outdoors at 10–24°C | Low<3000; content≥6000 |
303: | Social |100/hour | +1200/hour of paired social activity; dining+200 per shared meal | Lonely<2500 |
304: | Purpose |75/hour | +320/hour of completed useful labor; mentoring+400/hour | Aimless<2500 |
305: 
306: Small size multiplier 1000, medium 1200, large 1600, denominator 1000. Carry capacities 12000/16000/24000 g; movement caps 3277/4096/3072 u/second. Work arithmetic never receives a hidden species productivity multiplier. Heat and injury can change requirements but do not change species identity.
307: 
308: Need integration uses exact integer remainders: for hourly rate R scaled in 1/1000 need-point units, each tick add R to accumulator, extract `trunc(accumulator/750000)`, retain remainder. Compound multipliers are applied in int64 before division. Clamp final needs 0–10000 and discard positive overflow/remainder when a need reaches 10000.
309: 
310: | ID | EARS requirement |
311: |---|---|
312: | REQ-SET-011 | The system shall update needs using the hourly rates, size factors, and remainder rule above, independent of visibility and game speed. |
313: | REQ-SET-012 | When hunger reaches 3500 or lower and the resident can interrupt safely, the system shall reserve a permitted meal and start a 12-WU eating task before ordinary work. |
314: | REQ-SET-013 | If no prepared meal is reachable, then the system shall allow raw-edible nonreserved food when hunger≤1500, selecting enough quantity to add at most 3000 NP and never consuming seed items. |
315: | REQ-SET-014 | While hunger is 0, the system shall remove 4 health/hour and add one starving-hour counter/hour; available food shall remain the highest nonrescue job priority. |
316: | REQ-SET-015 | While rest≤500, the system shall cancel ordinary work, place the resident in floor sleep, and prevent hazardous work until rest≥4000. |
317: | REQ-SET-016 | When health reaches 0, the system shall record death, release all job/bed/input reservations, preserve the identity in the chronicle, and create a burial job and recoverable carried inventory. |
318: | REQ-SET-017 | While health<100 and hunger/rest≥4000 and no untreated serious injury exists, the system shall restore 2 health/hour, increased to 4/hour in an infirmary. |
319: | REQ-SET-018 | If a resident is outdoors or in an unheated room below 0°C without tier 2 clothing, then the system shall add 1 cold exposure/hour; after 4 exposure hours it shall remove 3 health/hour until sheltered or properly clothed. |
320: | REQ-SET-019 | When a resident enters a heated room, the system shall reduce accumulated cold exposure by 2/hour and stop exposure damage immediately. |
321: | REQ-SET-020 | The system shall compute mood as the weighted need average plus active memories using the formula below and shall apply its productivity, conflict, and departure consequences. |
322: | REQ-SET-021 | When mood remains below 2000 across two consecutive midnights, the system shall issue an intention-to-leave warning; after a third midnight below 2000 it shall mark departure unless the resident is incapacitated. |
323: | REQ-SET-022 | When a warned resident's mood reaches 3500, the system shall clear the departure counter and warning. |
324: | REQ-SET-023 | While a resident is incapacitated, the system shall block departure and create a rescue/care job instead of letting the resident vanish. |
325: | REQ-SET-024 | When a departure completes at the map exit, the system shall remove that resident from population, release their home/tool, and retain relationships and chronicle history under their persistent ID. |
326: 
327: Mood=`clamp(floor((3*hunger+2*rest+2*comfort+social+2*purpose)/10)+sum(memory_values),0,10000)`. Productivity factor: mood<2000→600;2000–3999→800;4000–6999→1000;7000–8499→1100;≥8500→1150, denominator 1000. Health<40 adds factor 600;40–69 adds 850;≥70 adds 1000. Skill factor=`1000+50*level`; total work factor=clamp(floor(skill*mood*health/1000000),300,1800). Each work tick produces 80 milli-WU×factor/1000 with retained remainder; travel/eating/social/sleep do not produce job output.
328: 
329: Health/status precedence is DEAD at health=0, INCAPACITATED at health=1..15, INJURED at health=16..99 with an active Injury, otherwise ACTIVE or the current RESTING activity. A treated resident becomes conscious once health>=16. Floor sleep from exhaustion is not incapacitation and can recover without a rescuer. Health drains and recovery integrate per tick with signed remainders; a rescue does not clear an injury until treatment completes. `cold_milli_hours` stores 1000 per exposure-hour, allowing 25% reductions; `cold_hours` is its floor/1000 display value. In hard freeze, base cold gain is 2000 milli-hours/hour for tier 1 and 1000 for tier 2; apply combined food/feast reductions after that. Clearing shelter remains 2000/hour. Need caps discard overflow of either sign at the relevant bound.
330: 

## docs/persistence_state_registry.md:487-509 SHA256 2a7a769b1ff57d29d2922d64a1528083641905d067b7cd4fde6f098134784204

487: | Route cell arena | `_arena` | 4 | `ROUTE_CELL_CAPACITY` = 1048576 | Cells at or past `_arena_used` are unallocated, not zeroed | 1 | §9 NAVIGATION | Task 09's acceptance list requires "fully referenced route arenas": every descriptor's `[offset, offset+count)` window must lie inside the restored used prefix, and compacting the arena on load would change later eviction behaviour. |
488: | Route descriptors | `_d_route_id`, `_d_generation`, `_d_start_macro`, `_d_goal_cell`, `_d_clearance`, `_d_map_revision`, `_d_variant_start`, `_d_anchor`, `_d_offset`, `_d_count`, `_d_refcount`, `_d_use_low`, `_d_use_high`, `_d_flags`, `_d_next_variant`, `_d_reserved` | 4 | `ROUTE_DESCRIPTOR_CAPACITY` = 256 | `_d_flags` without `FLAG_IN_USE` is a free descriptor; `_d_next_variant == -1` (`NO_VARIANT`) ends a variant chain | 1 | §9 NAVIGATION | ARCH-HASH-001 includes "cache eviction state": `_d_use_low`/`_d_use_high` are the u64 use counter the eviction order reads, and `_d_generation` is the route generation `movement.gd`'s cursor validates against. `FLAG_RETIRED` is this store's own generation-retirement rule and must survive exactly as §3's does. |
489: | Path request records and contacts | `_r_job_slot`, `_r_job_generation`, `_r_start_cell`, `_r_goal_cell`, `_r_clearance`, `_r_start_macro`, `_r_map_revision`, `_r_phase`, `_r_route_id`, `_r_route_generation`, `_r_created_low`, `_r_created_high`, `_r_next_queue`, `_r_exact_start`, `_r_anchor`, `_r_expansions`, `_c_start_owner_slot`, `_c_start_owner_generation`, `_c_goal_owner_slot`, `_c_goal_owner_generation`, `_c_requester_persistent_id` | 4 | `PATH_REQUEST_CAPACITY` = 8192 | `-1` (`NO_ROW`) in the queue links and owner slots | 1 | §9 NAVIGATION | The pending-request queue, its ages (`_r_created_low`/`_r_created_high` are a tick split across two nonnegative halves) and its per-request expansion spend. Task 09.4 requires canonical future state to include "navigation admission/readiness ... queue ages" by name. |
490: | Navigation search and queue scalars | -- | -- | -- | `_search_goal`, `_search_origin`, `_search_macro`, `_free_request_head`, `_queue_head` and `_active_request` all use `-1` (`NO_ROW`) | 1 | §9 NAVIGATION | `_search_serial`, `_heap_size`, `_search_*`, `_expansions_remaining`, `_expansions_total`, `_arena_used`, `_free_request_head`, `_queue_head`, `_active_request` and `_served_revision` are the other half of the partial search and of the request allocator. `_use_heuristic` is a test-only switch, `_live_requests`, `_storage_blocked_count` and `_last_refusal` are diagnostics. |
491: 
492: ### `godot/scripts/core/needs.gd`
493: 
494: | Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
495: |---|---|---:|---|---|:-:|---|---|
496: | Need values and remainders (i32) | `_need_value` | 4 | `RESIDENT_CAPACITY * NEED_COUNT` = 2560 | None: every living resident has all five needs | 1 | §4 COMPONENT_COLUMNS | Owner-major at `slot * 5 + need`, integers 0-10000 per AGENTS.md. The int64 remainder is the sub-point accumulator; task 09.4 warns that canonical future state is more than "needs and XP", and this is the half of needs that is easy to forget. |
497: | Need values and remainders (i64) | `_need_remainder` | 8 | `RESIDENT_CAPACITY * NEED_COUNT` = 2560 | None: every living resident has all five needs | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
498: | Health and remainder (i32) | `_health` | 4 | `RESIDENT_CAPACITY` = 512 | 0-100 with a separate remainder | 1 | §4 COMPONENT_COLUMNS | Same remainder argument. |
499: | Health and remainder (i64) | `_health_remainder` | 8 | `RESIDENT_CAPACITY` = 512 | 0-100 with a separate remainder | 1 | §4 COMPONENT_COLUMNS | See the first row of this group. |
500: | Cold exposure | `_cold_milli_hours`, `_cold_remainder` | 8 | `RESIDENT_CAPACITY` = 512 | 0 | 1 | §4 COMPONENT_COLUMNS | Accumulated exposure in milli-hours; the winter tests depend on it exactly. |
501: | Starvation clock | `_starving_ticks` | 8 | `RESIDENT_CAPACITY` = 512 | 0 = not starving | 1 | §4 COMPONENT_COLUMNS | An absolute tick count driving REQ-SET's starvation death; ARCH-SAVE-006 names "a dying resident" as a coverage case. |
502: | Departure countdown | `_departure_days` | 4 | `RESIDENT_CAPACITY` = 512 | 0 = not counting down | 1 | §4 COMPONENT_COLUMNS | Days remaining before a resident leaves. |
503: | Resident state bytes | `_status`, `_present`, `_size_class`, `_activity`, `_comfort_environment`, `_social_paired`, `_purpose_source`, `_cold_environment`, `_clothing_tier`, `_infirmary`, `_injury_state`, `_airless` | 1 | `RESIDENT_CAPACITY` = 512 | `_present == 0` is a free row; the rest are byte enums whose 0 is a real value | 1 | §4 COMPONENT_COLUMNS | `_injury_state` is the GDD's Injury model (kind/severity/care), which is settlement healing and NOT a combat damage model. ARCH-SAVE-005 bounds each byte against its `*_COUNT`. |
504: | Hunger rate table | `_hunger_rate_milli` | 8 | `SIZE_COUNT` = 3 | One entry per size class | 2 | §4 COMPONENT_COLUMNS | Three constants derived from the balance table at construction, not runtime state. |
505: | Needs tick scratch | `_rate_scratch` | 8 | `NEED_COUNT` = 5 | Refilled per resident | 3 | -- | Five entries, one per need, reused by the tick. |
506: | Needs live counters | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_present_count` and `_living_count`, recomputed from `_present` and `_status`. ARCH-SAVE-005 caps living residents at 256, which is checked against the recomputed value, not a stored one. |
507: | Needs pass inputs and scratch | -- | -- | -- | -- | 3 | -- | `_winter` and `_hard_freeze` are per-tick world inputs the caller restates every tick. `_death_count`, `_last_refused_slot`, `_math`, `_step_value`, `_step_remainder` and `_out_value` are diagnostics or scratch. `_last_column_refusal` [decision 0132] is the StringName code from the most recent `restore_columns()` refusal: a diagnostic scalar, excluded from `state_bytes()`, owing no ledger byte. |
508: 
509: ### `godot/scripts/core/orchard_hive.gd`
