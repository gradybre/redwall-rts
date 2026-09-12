---DOC:game_gdd.md---

# Redwall RTS — Settlement Layer Game Design Document

**Adopted movement amendment:** [SET-MOVE-001](movement_direction_amendment.md) implements DEC-035 at the direction/specification level. Its requirements supersede ground-only and one-floor claims as the complete settlement design. `settlement_rules_v2` remains the incomplete implementation baseline; MOVE-G01–05 identify exact engineering closure still required.

| Field | Value |
|---|---|
| Document | SET-GDD-001, revision 1.1, 2026-09-05 |
| Product scope | Standalone single-player settlement game; no battles, armies, campaign map, or multiplayer |
| Engine baseline | Godot 4.7.2, GDScript; development on Apple Silicon, Windows primary shipping target |
| Companion | `ui_ux_controls.md`; shared technical foundation in `crowd_rendering_architecture.md` |
| Population | 12 starting adults; 80–200 normal mature population; 256 living resident cap |
| World | One 256 m square settlement map; woodland, river/lake/coast, seasonal land management |
| Design status | Fixed implementation baseline, not playtested balance or measured performance |

The engine version is pinned to the prior crowd architecture and the [official Godot release archive](https://godotengine.org/download/archive/); changing the engine minor version requires repeating the platform qualification gates.

All functional requirements are the uniquely numbered EARS statements in Sections 5–8. Tables, formulas, schemas, and layouts are normative data bound by REQ-SET-001. Descriptive feature/fantasy paragraphs explain intent without introducing additional hidden rules. Numbers are game design choices, not claims about real ecology, diet, or medicine.

*Rationale: an implementable initial release needs a finite content catalog and measurable rules; “deep” means interacting, understandable systems rather than an unlimited feature list.*

Ruleset `settlement_rules_v2` adopts DEC-005/006. [setting_rules_amendment.md](setting_rules_amendment.md) supplies the exact admission profile, exception, retired content, replacement roast and compatibility rules. New content values are identified there as authored choices. The single refuge initialization below is one scenario baseline; DEC-028 requires additional fully specified first-release scenarios, not a single-scenario final release.

## 1. Feature Overview

**Creature autonomy.** Every resident has persistent identity, five needs, health, skills, preferences, relationships, and an explicit schedule. Anonymous presentation does not mean disposable simulation. The player sets priorities and policies; residents find eligible work, eat, sleep, socialize, seek treatment, and react to sustained hardship. Growth comes through immigration; childbirth, child care, reproduction, and age-related death are outside release 1.

**Fishing.** River, lake, and coastal habitats have separate species stocks, seasonal catches, spawning closures, fishing capacity, and hazards. Nets, traps, weirs, and boats trade labor, access, efficiency, and risk. A temporarily abundant salmon run can fund preservation and a feast, while excessive extraction damages later seasons.

**Foraging and woodland stewardship.** Berries, nuts, mushrooms, roots and herbs mature on different calendars. Deeper woods offer higher yields with explicit exposure risk. Protected habitat remains useful without harvesting. Mammals and birds are not food stocks; wilderness danger remains in the existing foraging and fishing hazard rules.

**Farming and husbandry.** Fields track soil texture, fertility, moisture, crop family, progress, disease, and harvest readiness. Rotation and compost affect future harvests. Orchards require years of care; hives produce honey and wax and improve nearby pollinated crops. There is no livestock breeding subsystem in release 1.

**Cooking and preservation.** Food moves through inventory lots, work orders, recipes, quality, storage, and consumption. Dishes carry nutritional value and a bounded ingredient effect. Variety matters, and preservation converts short harvest windows into winter reserves. Feasts consume real multi-course supplies and grant a timed settlement benefit.

**Construction and interiors.** Exterior buildings occupy the terrain grid. The current starter fixture gives residential halls, community halls, and infirmaries managed interiors; the complete design must additionally support the interoperable underground construction and connected movement required by SET-MOVE-001. In the baseline fixture, production buildings and stores are accessible black boxes with explicit worker slots. Room validity, beds, seating, warmth, and walkable access are visible constraints. Defensive construction controls access and protects stores from wildlife; there is no settlement combat mode.

**Seasons and weather.** Four twelve-day seasons create a forty-eight-day year. Winter lowers available food, raises appetite and heating demand, and exposes weak storage and staffing. Forecasts provide time to respond; disasters follow a bounded event schedule. Day/night lighting, sleep schedules, opening hours, and outdoor darkness exist independently of season.

**Progression and completion.** The player grows from an inhabited refuge into a self-sufficient abbey, holt, or fortress community. Milestones unlock economic tools and cultural goals. The Hearth Charter objective provides a clear victory after at least three years; the same settlement can continue indefinitely. All core survival tools are available before the first winter.

## 2. Player Fantasy

| System | Intended experience |
|---|---|
| Residents | “The mouse I noticed in the kitchen has become the cook everyone relies on.” |
| Fishing | “I know this river well enough to feed the abbey without emptying it.” |
| Foraging/woodland | “The woodland is generous when respected, and dangerous when treated carelessly.” |
| Farming/orchards | “I planted something whose best years I have not reached yet.” |
| Cooking | “A warm meal is the visible result of many residents caring for one another.” |
| Feasts | “We are celebrating a surplus we earned, without gambling away winter.” |
| Building | “This collection of rooms and workshops has become a home.” |
| Winter | “We were prepared, but I still feel responsible for every empty bed and bowl.” |
| Progression | “The community can endure because I built habits, knowledge, and reserves.” |

*Rationale: danger comes from exposure, shortages, ecological decline, and strained relationships; the settlement does not need combat content to create tension.*

## 3. Core Loops

### 3.1 Daily management loop

1. Read food-days, fuel-days, health, housing, idle-worker, and blocked-job summaries.
2. Review that day's weather and critical alerts.
3. Set production targets, eligible work zones, and work priorities.
4. Residents reserve inputs, travel, work, haul outputs, and meet personal needs.
5. Inspect bottlenecks by cause: labor, input, storage, access, season, or habitat protection.
6. Reassign a small number of workers or change one policy rather than issuing continuous individual orders.
7. At evening, review meals, missed needs, relationships, production, and tomorrow's work.

### 3.2 Seasonal loop

1. At season start inspect the twelve-day calendar, ecological stocks, planting windows, and forecast.
2. Reserve seeds and winter food before spending harvests on growth or celebration.
3. Plant, fish, and forage within sustainable quotas.
4. Process surplus through mills, kitchens, drying racks, smokehouses, and cellars.
5. Expand heat, beds, tools, and storage only when the reserve forecast remains sufficient.
6. Respond to one bounded weather/ecology event and recover production.
7. Hold an affordable feast or retain the supplies.
8. Review population, stocks, soil, and lost work before the next season.

### 3.3 Long-term loop

1. Stabilize the original twelve residents and enable safe immigration.
2. Support twenty-four, forty-eight, eighty, then one hundred twenty residents.
3. Diversify staple sources and train specialists while preserving emergency fallback labor.
4. Invest in orchards, hives, preservation, room quality, and local material production.
5. Earn the Hearth Charter by sustaining the completion conditions through a winter.
6. Continue toward two hundred residents, full recipe mastery, and resilient surplus.

## 4. Entities & Components

### 4.1 Units, storage, and identity

| Symbol/type | Exact meaning |
|---|---|
| `int` | GDScript signed 64-bit arithmetic; serialized fields explicitly int32 or int64 as listed |
| `float` | Presentation/import values only; never authoritative decisions |
| `bool` | Packed byte 0/1 in runtime stores |
| `enum` | Explicit integer values from this document; never inferred from display order |
| `StringName` | Immutable catalog key; compiled to int32 index before simulation |
| `EntityRef` | Pair `(slot:int32,generation:int32)`; null=(-1,0) |
| Position unit `u` | 1/1024 m; +Y up, −Z forward |
| Need/mood/fertility scale | Integer 0–10000; percentages divide by 100 |
| Item quantity | `quantity_milli:int64`; 1000=one catalog unit, abbreviated U |
| Nutrition `NP` | Integer gameplay nutrition points; small resident requires 6000/day at baseline |
| Work `WU` | One game minute of base-speed productive labor; runtime stores milli-WU |
| Time | 30 ticks/real second at 1×; 18000 ticks/day; 750 ticks/game hour |
| Birth/growth scope | Adult immigration only; no demographic reproduction simulation |

Persistent creature IDs are monotonically allocated positive int32 values and never reused. Runtime slots are reused with generation validation. Resident storage capacity is 512 to leave room for transfers and deferred removal, but living population never exceeds 256. Species identity is independent of job, faction and rendering rig; sapience classification is consistent per species and disjoint from edible stock keys.

*Rationale: the settlement keeps the integer, fixed-tick, structure-of-arrays boundary established by the crowd document; it does not inherit battle formations, combat stats, or a requirement for one node per resident.*

### 4.2 Entity and component registry

All fields below are authoritative unless marked `P` for presentation or `C` for immutable catalog. Integer columns are `PackedInt32Array` unless marked 64; quantity/work/tick counters marked 64 use `PackedInt64Array`. Relations are explicit references or indexed child tables, not live Node references. Per-entity capacity includes only listed child arrays.

| Entity/component | Typed fields | Cardinality / relationships |
|---|---|---|
| World | seed: int32, tick: int64, day: int32, season: enum, year: int32, map_revision: int32, speed: enum, mode: enum, milestone_mask: int32 | Exactly 1; owns stores |
| EntityIdentity | persistent_id: int32, generation: int32, kind: enum, active: bool | One per runtime entity; IDs unique across kinds |
| Transform | x/y/z/yaw: int32, prev_x/prev_y/prev_z/prev_yaw: int32 | One per positioned entity; yaw 65536/turn |
| Resident | species_id: StringName(C)/int32, named: bool, name_key: StringName, arrival_tick: int64, home: EntityRef, bed: EntityRef, role: enum, status: enum, selected: bool(P) | One per creature; at most 1 bed and 1 home |
| Needs | hunger/rest/comfort/social/purpose: int32, health: int32, cold_hours: int32, starving_hours: int32, departure_days: int32 | One per resident; needs 0–10000, health 0–100 |
| NeedRemainders | hunger/rest/comfort/social/purpose: int64 | Five fixed fractional accumulators per resident |
| Skills | xp: int64[12], level: int32[12] | One fixed 12-column set per resident |
| Priorities | job_priority: byte[12], auto_fallback: bool, dangerous_work: bool | Priority 0–4; default dangerous=false |
| Schedule | hourly_activity: byte[24], template: enum, current_activity: enum | Exactly 24 hour slots/resident |
| JobAgent | job: EntityRef, phase: enum, target: EntityRef, path_id: int32, path_cursor: int32, lease_expiry: int64, blocked_tick: int64, manual_until: int64 | At most 1 active job/resident |
| MoodMemory | memory_kind: enum, value: int32, expiry: int64, source_id: int32 | Up to 8 entries/resident; repeat kind refreshes |
| MealHistory | recipe_id: int32[6], last_meal_tick: int64, effect_kind: enum, effect_value: int32, effect_expiry: int64 | Last 6 completed meals; one food effect active |
| Equipment | tool_item_id: int32, tool_durability: int32, clothing_tier: int32, satchel: EntityRef | One tool, one outfit, one carried container |
| Relationship | a_id: int32, b_id: int32, affinity: int32, last_contact_day: int32, friend: bool | Undirected unique pair a<b; degree≤8 per resident |
| Injury | kind: enum, severity: int32, untreated_hours: int32, care_progress_mwu: int64, rescuer: EntityRef | At most 1 aggregate injury/resident; worse severity replaces, damage still accumulates |
| Building | type_id: int32, tier: int32, origin_tile: int32, rotation: int32, state: enum, condition: int32, construction: EntityRef, interior_id: int32 | At most 1024 exterior structures; rotation 0–3 |
| Room | type: enum, building: EntityRef, tile_offset: int32, tile_count: int32, valid: bool, temperature_tenths: int32, furniture_mask: int32, occupants: int32 | Up to 16 rooms/managed building; nonoverlapping tiles |
| Furniture | type_id: int32, room: EntityRef, origin_tile: int32, rotation: int32, user: EntityRef, condition: int32 | Bed/seat/workstation single-user; hearth shared room service |
| Construction | material_container: EntityRef, remaining_mwu: int64, assigned_count: int32, max_workers: int32, paused: bool, refund_policy: enum | At most 1 project/building/furniture/road segment |
| InventoryContainer | owner: EntityRef, max_mass_g: int64, filters: bitset 64, reserved_mass_g: int64, policy: enum, reachable: bool | One main store/building, one satchel/resident; lots 0..many |
| InventoryLot | item_id: int32, quantity_milli: int64, reserved_milli: int64, quality: int32, age_milli_hours: int64, age_remainder: int64, provenance: enum, recipe_id: int32, container: EntityRef | At most 16384 live lots; split/merge only by identical attributes |
| Reservation | job: EntityRef, lot: EntityRef, quantity_milli: int64, expiry: int64, purpose: enum | At most 32768 rows; total per lot≤quantity |
| ProductionOrder | recipe_id: int32, building: EntityRef, mode: enum, target_milli: int64, priority: int32, completed_batches: int32, enabled: bool | At most 32 orders/building |
| Job | kind: enum, requester: EntityRef, destination: EntityRef, source: EntityRef, priority: int32, required_skill: int32, remaining_mwu: int64, state: enum, created_tick: int64, worker: EntityRef | At most 8192 active/queued jobs |
| FishHabitat | type: enum, zone: EntityRef, capacity_milli: int64, effort_slots: int32, pollution: int32, danger: int32, protected_fraction: int32, **effort_used: int32**, **intensive_harvest: bool** | One per marked water basin; up to 32 — an **allocation ceiling**, not a generation count (READY_06 §8B). `zone` refers exclusively to the owning basin, never to a player designation, and exactly one habitat may name a given basin reference. Bold fields ratified 2026-09-09 (decision 0027): `effort_slots` is a capacity and `effort_used` its occupancy; `intensive_harvest` is §5.4's explicitly visible policy |
| FishStock | habitat: EntityRef, species_id: int32, population_milli: int64, capacity_milli: int64, harvested_today_milli: int64, closed: bool, **restocking: bool** | 3 stocks/habitat; no shared global fish counter. `stock_row = habitat_typed_slot * 3 + species_index`. Bold field ratified 2026-09-09 (decision 0027): REQ-SET-048's 30-down/40-up latch |
| FishingEffortClaim | active: bool, expedition_generation: int32, habitat: EntityRef, job: EntityRef, slot_count: int32 | One per owning Expedition, `claim_row = owning_expedition_typed_row` within the 512 Expedition rows (READY_06 §5, decision 0037). A cycle reserves its whole gear requirement atomically; only its coordinator Job owns the claim |
| HarvestZone | type: enum, tiles: packed int32[], danger: int32, quota_milli: int64, protected: bool, enabled: bool, **basin: EntityRef**, **harvested_today_milli: int64**, **quota_reserved_milli: int64**, **quota_mode: enum** | Up to 128; tile membership max 16384 total zone links. Bold fields ruled 2026-09-09 (decisions 0026, 0030): `quota_milli` is a **daily** limit on total forage across all five kinds, shared by the basin; a designation may be stricter but never larger in effect |
| FaunaStockReserved | zone: EntityRef, species_id: int32, population: int32, capacity: int32, tracks: int32, harvest_today: int32, migration_link: int32, birth_remainder: int64 | Reserved allocation only: all numeric fields 0, refs (-1,0), no active rows or updates |
| ForagePatch | zone: EntityRef, item_id: int32, stock_milli: int64, capacity_milli: int64, harvested_year_milli: int64 | 5 patches per **basin** (decision 0026); `zone` refers exclusively to the owning basin, never to a player designation, so overlapping designations share one stock. `patch_row = basin_typed_slot * 5 + patch_kind`, kinds Berries 0, Nuts 1, Mushrooms 2, Herb 3, Roots 4. `harvested_year_milli` is annual ecological history, **not** the quota accumulator (decision 0030) |
| ForageClaim | active: bool, job: EntityRef, designation: EntityRef, basin: EntityRef, patch_kind: int32, remaining_milli: int64 | One per owning Job, `claim_row = owning_job_typed_row` within the 8192 Job rows (decision 0030). Uncollected forage is ecological stock, not an InventoryLot |
| ResourceNode | resource_id: int32, quantity_milli: int64, capacity_milli: int64, regrow_days: int32, planted_day: int32, exhausted: bool | Tree/stone/iron source; at most 4096 |
| Expedition | kind: enum, zone: EntityRef, member_ids: int32[3], member_count: int32, phase: enum, remaining_mwu: int64, cargo: EntityRef, hazard_roll: int32, consent: bool | Fishing 1–2 members; third member slot reserved empty; one job/member |
| FarmPlot | crop_id: int32, state: enum, soil: enum, fertility: int32, moisture: int32, growth_milli_hours: int64, health: int32, last_family: int32, family_streak: int32, compost_milli: int64, sow_day: int32 | One per 2 m tile; up to 4096 active farm tiles |
| OrchardPlot | species_id: int32, age_days: int32, health: int32, tended_today: bool, harvested_year: bool, chill_days: int32 | One per 4×4 farm-tile orchard block |
| Hive | building: EntityRef, strength: int32, feed_milli: int64, serviced_day: int32, honey_milli: int64, wax_milli: int64 | One per apiary; six pollination links max per field block |
| Weather | event: enum, start_day: int32, duration_days: int32, temperature_tenths: int32, rain: int32, forecast: int32[3] | One active major event/world; daily baseline independently |
| Feast | recipe_theme: enum, state: enum, attendees: int32[], reserved_lots: int32[], start_tick: int64, capacity: int32, coverage: int32 | At most 1 scheduled/active feast |
| Progress | milestone: enum, unlocked_mask: int64, victory_streak_days: int32, mastered_recipe_mask: int64, feasts_completed: int32, charter_awarded: bool | Exactly 1 |
| Notice | severity: enum, category: enum, source: EntityRef, code: StringName, created_tick: int64, resolved: bool, acknowledged: bool | 500 history entries; deduplicated active key(code, source) |
| TransferManifest | manifest_id: int32, resident_ids: int32[], item_lot_ids: int32[], quantity_milli: int64[], status: enum, rules_hash: StringName | Inactive future adapter; no army entity in this release |

**Ruled 2026-09-11 (READY_07 §2) — resource identity.** `ResourceNode.resource_id` identifies the extracted output's compiled `ItemDefinition` ID: `wood`, `stone` and `iron`. `ForagePatch.item_id` and `FishStock.species_id` use the same domain — `berries, nuts, mushrooms, herb, roots` and `trout, dace, salmon, perch, carp, whitefish, herring, mackerel, mussel`. These seventeen bindings are resolved by key against the compiled catalog and its verified `catalog_ids.json` hash; no generic `tree`, `forage` or `fish` ItemDefinition exists, and `fish` in a recipe is a selector over the approved nine species keys rather than a runtime stock item. Patch kind, fish species row and habitat type remain **different indexes from the item ID**: a compiled item ID never subscripts the five-row patch or nine-row species tables. See decision 0052.

`StringName name_key` references a localized authored name or sanitized player alias; it is not part of simulation ordering. Selection flags, navigation debug visuals, skin palettes, and scene nodes are outside saved gameplay truth. Child-array capacities are hard validation limits, with explicit refusal when full.

Additional fixed child stores close persistence requirements used by the job and UI contracts:

| Child store | Typed fields | Capacity / initial state |
|---|---|---|
| ManualTask | owner_id:int32, kind:enum, target:EntityRef, goal_x/z:int32, issued_tick/expiry_tick:int64 | 8 per resident; FIFO; kinds WALK=0, PREFER_WORK=1, REST=2, RESCUE=3; empty initially |
| IntegrationRemainders | health/cold/work/xp/food_effect:int64, cold_milli_hours:int64 | One row/resident; all 0; health uses 750-tick hourly denominator, cold uses milli-hours |
| BatchState | job:EntityRef, recipe_id:int32, lead_level:int32, quality_roll:int32, quality_score:int32, passive_until:int64, input_mass_g:int64, output_reserved_g:int64 | One per in-progress recipe batch; max 8192; removed at COMPLETE/CANCELLED |
| FieldPolicy | zone:EntityRef, rotation_ids:int32[3], rotation_cursor:int32, auto_rotation:bool, seed_reserve:bool | One per FARM zone; grain/beans/roots, cursor 0, auto false, reserve true |
| NoticeCondition | code:StringName, source_id:int32, affected_ids:int32[], first_tick/last_tick:int64, count:int32, active:bool | Max 2048 active keys; 256 affected IDs/key; history eviction never clears active truth |
| ChronicleRecord | resident_id:int32, event:enum, tick:int64, other_id:int32, detail_key:StringName | Death/departure/notability/assistance/Charter events; saved append-only; presentation pages 64 rows |
| WorldPolicy | auto_immigration:bool, raw_emergency_food:bool, variety_first:bool, ration_reserve_milli:int64, relief_used_year:int32 | Defaults false,true,false,0,0 |
| GeneratorState | requested_seed/effective_seed/attempt:int32, architecture:enum, settlement_name:StringName | One/world; ABBEY=0,HOLT=1,FORTRESS=2; semantic geometry identical |

All gameplay enum numeric values not individually listed are generated once from the lexicographically sorted ASCII catalog keys within their own domain and committed to `catalog_ids.json`; loading verifies its hash. Runtime enumeration by dictionary insertion order is prohibited. Empty references are `(-1,0)`; empty catalog IDs are −1; empty counters/remainders are 0. Newly allocated components are initialized explicitly before an entity becomes active. A registry validation failure aborts loading before mutating the current world.

**2026-09-11 building/room domain clarification:** BuildingDefinition.unlock and
RecipeDefinition.unlock reference the protected Milestone domain. RecipeDefinition.station
references the separate compiled Station service domain from BAL-CAT-011. Room.furniture_mask
is the OR of `1 << FurnitureDefinition ID` over live committed furniture rows with a
valid reference to that room generation; presence never substitutes for counts or
service validation. Known mask=511. [R-BUILD-DOM-001–004](rulings/2026-09-11_building_room_domains.md)
defines exact IDs, mutation/load rules, station binding and the starter shelf.

### 4.3 Enumerations and immutable catalogs

| Enum | Values |
|---|---|
| Season | SPRING=0, SUMMER=1, AUTUMN=2, WINTER=3 |
| WorldMode | STANDARD=0, SANDBOX=1 |
| Speed | PAUSED=0, NORMAL=1, DOUBLE=2, QUADRUPLE=4 |
| Activity | SLEEP=0, ANYTHING=1, WORK=2, SOCIAL=3 |
| ResidentStatus | ACTIVE=0, RESTING=1, INJURED=2, INCAPACITATED=3, LEAVING=4, DEAD=5, TRANSFERRED=6 |
| Role | RESIDENT=0, WARDEN=1, SPECIALIST=2 |
| JobKind/skill index | HAUL=0, BUILD=1, FISH=2, RESERVED_3=3, FORAGE=4, FARM=5, COOK=6, PRESERVE=7, CRAFT=8, TEND=9, KEEP=10, HEAL=11 |
| JobState | QUEUED=0, RESERVED=1, TRAVEL=2, WORK=3, HAUL_OUTPUT=4, COMPLETE=5, BLOCKED=6, CANCELLED=7 |
| ZoneType | FISH=0, RESERVED_1=1, FORAGE=2, FARM=3, ORCHARD=4, FORESTRY=5, QUARRY=6, STOCKPILE=7, CONSERVATION=8 |
| RoomType | DORMITORY=0, PRIVATE_ROOM=1, KITCHEN=2, DINING=3, COMMON=4, INFIRMARY=5, PANTRY=6, CORRIDOR=7 |
| BuildingState | BLUEPRINT=0, BUILDING=1, ACTIVE=2, PAUSED=3, DAMAGED=4, DEMOLISHING=5 |
| Milestone | M0=0, M1=1, M2=2, M3=3, M4=4; protected domain, Start maps to M0 |
| Soil | LOAM=0, CLAY=1, SAND=2 |
| CropState | EMPTY=0, SOWN=1, GROWING=2, RIPE=3, WITHERED=4 |
| OrderMode | ONCE=0, REPEAT=1, MAINTAIN_STOCK=2 |
| Quality | POOR=0, PLAIN=1, GOOD=2, EXCELLENT=3 |
| InjuryKind | NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5 |
| FeastState | PLANNED=0, PREPARING=1, READY=2, ACTIVE=3, COMPLETE=4, CANCELLED=5 |
| Severity | INFO=0, ADVISORY=1, WARNING=2, CRITICAL=3 |

Species catalog release 1: mouse, shrew, mole, rat, squirrel, sparrow, otter, hare, ferret, weasel, hedgehog, kestrel, badger, fox, wildcat, wolverine. Their rendering families remain separate unless validated compatible. Small species are the first six, medium the next six, large the last four. Giant residents are not recruitable in settlement release 1; their later reserved IDs remain unallocated.

| Catalog | Required typed properties |
|---|---|
| SpeciesDefinition | id: StringName, size: enum, hunger_multiplier: int32, carry_g: int32, speed_u_per_s: int32, rig_id: StringName, sapient: bool |
| ItemDefinition | id: StringName, category: enum, mass_g: int32, nutrition_per_u: int32, shelf_hours: int32, raw_edible: bool, seed: bool, effect: enum, effect_value: int32 |
| RecipeDefinition | id: StringName, inputs: item/quantity pairs, outputs: item/quantity pairs, work_mwu: int64, station: int32, skill: int32, unlock: int32, family: enum |
| BuildingDefinition | id: StringName, footprint_x/z: int32, materials: item/quantity pairs, work_mwu: int64, slots: int32, managed_interior: bool, room_tiles: int32, unlock: int32 |
| CropDefinition | id: StringName, family: enum, allowed_soils: mask, plant_windows: day intervals, growth_hours: int32, base_yield_milli: int64, moisture_min/max: int32, frost_tolerance: int32 |
| EventDefinition | id: StringName, season_mask: int32, duration_days: int32, forecast_days: int32, modifiers: fixed int32 vector |

## 5. Requirements

### 5.1 Common rules, time, and initialization

| ID | EARS requirement |
|---|---|
| REQ-SET-001 | The system shall implement all catalogs, formulas, typed schemas, capacities, and precedence rules in this document as the release 1 ruleset; changed values shall increment the ruleset version. |
| REQ-SET-002 | The system shall run authoritative logic at 30 ticks/second of 1× simulation time, using integer arithmetic and the deterministic command/RNG boundaries of the crowd architecture. |
| REQ-SET-003 | When game speed is 2× or 4×, the system shall execute two or four times as many fixed ticks per real second without changing per-tick rules. |
| REQ-SET-004 | While paused, the system shall freeze needs, jobs, weather, spoilage, animation phase, and event deadlines while allowing camera, selection, planning, and UI interaction. |
| REQ-SET-005 | When an editable command is issued while paused, the system shall append it to the next-tick ordered command queue and render a pending preview without applying gameplay consequences early. |
| REQ-SET-006 | The system shall define one day as 18000 ticks, one hour as 750 ticks, one season as 12 days, and one year as 48 days, starting at year 1/spring/day 1/06:00. |
| REQ-SET-007 | When a daily boundary occurs at 00:00, the system shall age stocks, update ecology, advance crops/weather, process immigration/departures, then evaluate progression in that order. |
| REQ-SET-008 | If the scheduler accumulates more than 0.25 real seconds of backlog at its current speed, then the system shall reduce 4× to 2× or 2× to 1× and display an overload warning; at 1× it shall pause with a diagnostic rather than skip ticks. |
| REQ-SET-009 | The system shall generate the initial settlement and resource distribution from the fixed initialization contract below. |
| REQ-SET-010 | Where sandbox mode is selected, the system shall use the same survival rules and permit continued play after Charter victory, with no forced objective deadline. |

At 1×: day 10 minutes, season 120 minutes, year 8 hours. At 2×: day 5 minutes, season 60 minutes, year 4 hours. At 4×: day 2.5 minutes, season 30 minutes, year 2 hours. Pause adds arbitrary wall time. Tick 0 corresponds to 06:00 on the first day; calendar time uses `(tick+4500) mod18000`, with the first midnight at tick 13500. Daily events use crossings of this offset calendar, not `tick mod18000==0`.

**Initialization identity clarification (2026-09-11, R-INIT-ID-001):** IDs 1–12
are global persistent IDs, with Rowan=1. The composed new-world transaction resets
once before allocation, allocates the cohort identities first, then allocates world
entities using the same continuing sequence. Terrain publication must not reset
those identities. Preserve prior-valid-world failure behavior and publish atomically;
see [the lifecycle and acceptance ruling](rulings/2026-09-11_initial_ids_and_narrow_alerts.md).

Initial conditions:12 adults (6 mice,2 moles,2 otters,2 squirrels); IDs 1–12; ID 1 named Warden Rowan; all five needs 7500, health 100, active job skills level 2 except Rowan KEEP 3; reserved skill index 3 has XP/level 0; no injuries; relationship edges(1,2),(3,4),(5,6),(7,8),(9,10),(11,12) affinity 20. Start with one completed refuge hall containing 12 beds, one kitchen bench, twelve seat places, one hearth, and one pantry; one well, four open stockpiles, and one outdoor workbench.

Initial inventory U: wood 180, stone 100, iron 20, rope 20, tool 24, cloth 24, water 60, grain 80, roots 80, berries 40, nuts 40, dried_fish 60, ration 60, seed_grain 32, seed_roots 32, seed_beans 16, seed_cabbage 16, seed_flax 16, herb 12, compost 32. Initial tool durability 1000, clothing tier 1. The starter hall and resource placement fit a 32 m radius of map center.

Initial loose lots are PLAIN quality, effective age 0, provenance STARTER, with no reservations. The 24 initial tool units include 12 equipped tools (one per resident) and 12 stored tools; they are not duplicated. All residents wear tier 1 clothing supplied as spawn equipment. Initial priorities are HAUL=2, RESERVED_3=0 and all other active jobs=3, auto_fallback=true, dangerous_work=false; orders are initially empty. Warden KEEP XP=45000; other active initial skills XP=20000; reserved index 3 XP=0. Initial room assignments follow resident ID ascending and bed ID ascending. Initial farm moisture is 6000, health 10000; empty plots have no previous crop family. All other initial fields follow the registry zero/null defaults unless a catalog specifies a different value.

The standard map preset has river, lake, and coastal inlets so all three fishing systems are accessible without a campaign. The player may choose Abbey, Holt, or Fortress architecture; these are visual kits with identical costs/capacities. A fixed-seed tutorial uses seed 20260905. Terrain generator validation guarantees: one river edge within 24 m, one forest zone within 32 m,64 loam tiles within 24 m, a 1200 U wood stock and 1200 U stone deposit within 48 m, renewable saplings, and an iron deposit within 80 m. Invalid seeds are rejected and regenerated with seed+1.

The shipping map is a deterministic authored estuary preset; the seed changes ecology events, resource variants, and names, not the following navigability guarantees. Exterior tile index is `z*128+x`; tile center in simulation units is `(2048*x+1024,0,2048*z+1024)`. Apply terrain masks in this priority: coast, river, lake, land. Coast is z=0..15; river is x=76..78 and z=16..127; lake is `(x-100)^2+(z-66)^2<=14^2`. Water surface is y=0; navigable land y=512 units. The natural ford at river tiles z=48..51 is walkable, y=−128 units, and is not a fishing work tile. In the existing baseline fixture all other water blocks residents, including bird residents. SET-MOVE-001 supersedes this as a release-wide swimming exclusion: surface swimming, diving and shore transitions are required under completed traversal profiles. Flight remains separately unspecified; anatomy alone grants no bypass. Water-bank interpolation affects visuals only. There is one stock basin of each habitat type; dividing a player zone never creates extra ecology stock. **Ruled 2026-09-09 (READY_06 §8B):** the specified initial estuary generates exactly one river, one lake and one coast basin — nine FishStock rows, capacities 2100/2200/3100 U, stocks at 80%. A player FISH designation binds to existing ecological ownership through its HarvestZone basin; overlapping, splitting, deleting, protecting or redrawing it creates and resets no fish, quota history, restocking state or effort capacity.

Land soil is LOAM for x=40..74,z=40..88, SAND within 4 tiles of coast or x>=112, CLAY otherwise. Clear initial building footprints, a one-tile apron, and the loam rectangle x=58..65,z=46..53 before placing resource nodes. Forest ecology basins are west x=8..49,z=20..105 and east x=82..119,z=20..105 excluding water; each is split at z=62 into north/south migration partners. FaunaStockReserved has no active instances; forage stocks are floor(0.8×capacity), including dormant stocks. Player harvest zones reference basin IDs; all intersecting zones share its quotas and do not multiply capacity.

Tree centers occupy every second x/every second z in forest masks. If more than 3000 centers qualify, retain the lowest tile indices. Each mature node contains 12 wood U. Add a guaranteed grove of 100 trees at x=40..49,z=54..63, one per tile, skipping duplicate centers and all cleared aprons; replace any skipped center at the lowest unused land tile inside x=36..49,z=50..67 until exactly 100 guaranteed nodes exist. Guaranteed stone deposit origin (44,70), footprint 4×4, quantity 1200 U; renewable bedrock access (48,70); iron origin (32,60), footprint 4×4, quantity 300 U. Ore footprints replace tree nodes. **A deposit's listed quantity is the sum across its footprint (ruled 2026-09-09, decision 0029):** each 4×4 deposit is sixteen independently exhaustible ResourceNode rows, one per tile, created in ascending tile-index order -- stone `x=44..47, z=70..73` at 75000 milli-U each, iron `x=32..35, z=60..63` at 18750 milli-U each, 32 rows of the 4096 total. Per-tile depletion is intended visible behaviour, and no ResourceNode footprint column is added. A footprint tile holding a tree node has that node replaced before the ore node is published, preserving one resource node per tile. The renewable bedrock access at (48,70) is separate and is in neither deposit total. Arrival/departure exit is (64,126), joined to the hall by ordinary land navigation. A failed topology assertion rejects generation after at most 16 seed attempts and returns the explicit failed assertion to the new-settlement form; the authored geometry makes repeated topology failure an implementation error, not an endless retry.

```text
MACRO MAP: each cell represents 16x16 exterior tiles; N is decreasing Z
         X=0  16  32  48  64  80  96 112
Z=  0     C   C   C   C   C   C   C   C
   16     F   F   F   .   R   F   F   F
   32     F   F   F   .   R   F   F   F
   48     F   F   I   A   R   F   L   F
   64     F   F   S   H   R   F   L   F
   80     F   F   F   .   R   F   F   F
   96     F   F   F   .   R   F   F   F
  112     .   .   .   .   E   .   .   .
C coast | R river | L lake | F forest | A arable | H hall | I iron | S stone | E exit
Exact tile masks and coordinates above override this coarse overview.
```

*Rationale: a single rich estuary map makes the full food chain playable in one standalone settlement; architecture themes do not hide balance advantages.*

### 5.2 Needs, health, and mood

| Need | Baseline decay/game hour | Restoration | Thresholds |
|---|---:|---|---|
| Hunger/fullness |250×size multiplier; winter×1.20 | Food adds its NP×quality factor | Eat≤3500; urgent≤1500; starving=0 |
| Rest |375 while awake; no awake decay while asleep | Sleep+1200/hour in bed; +750/hour on floor | Seek sleep≤2500; collapse≤500 |
| Comfort |100/hour | +300/hour in valid heated room; +100/hour outdoors at 10–24°C | Low<3000; content≥6000 |
| Social |100/hour | +1200/hour of paired social activity; dining+200 per shared meal | Lonely<2500 |
| Purpose |75/hour | +320/hour of completed useful labor; mentoring+400/hour | Aimless<2500 |

Small size multiplier 1000, medium 1200, large 1600, denominator 1000. Carry capacities 12000/16000/24000 g; movement caps 3277/4096/3072 u/second. Work arithmetic never receives a hidden species productivity multiplier. Heat and injury can change requirements but do not change species identity.

Need integration uses exact integer remainders: for hourly rate R scaled in 1/1000 need-point units, each tick add R to accumulator, extract `trunc(accumulator/750000)`, retain remainder. Compound multipliers are applied in int64 before division. Clamp final needs 0–10000 and discard positive overflow/remainder when a need reaches 10000.

| ID | EARS requirement |
|---|---|
| REQ-SET-011 | The system shall update needs using the hourly rates, size factors, and remainder rule above, independent of visibility and game speed. |
| REQ-SET-012 | When hunger reaches 3500 or lower and the resident can interrupt safely, the system shall reserve a permitted meal and start a 12-WU eating task before ordinary work. |
| REQ-SET-013 | If no prepared meal is reachable, then the system shall allow raw-edible nonreserved food when hunger≤1500, selecting enough quantity to add at most 3000 NP and never consuming seed items. |
| REQ-SET-014 | While hunger is 0, the system shall remove 4 health/hour and add one starving-hour counter/hour; available food shall remain the highest nonrescue job priority. |
| REQ-SET-015 | While rest≤500, the system shall cancel ordinary work, place the resident in floor sleep, and prevent hazardous work until rest≥4000. |
| REQ-SET-016 | When health reaches 0, the system shall record death, release all job/bed/input reservations, preserve the identity in the chronicle, and create a burial job and recoverable carried inventory. |
| REQ-SET-017 | While health<100 and hunger/rest≥4000 and no untreated serious injury exists, the system shall restore 2 health/hour, increased to 4/hour in an infirmary. |
| REQ-SET-018 | If a resident is outdoors or in an unheated room below 0°C without tier 2 clothing, then the system shall add 1 cold exposure/hour; after 4 exposure hours it shall remove 3 health/hour until sheltered or properly clothed. |
| REQ-SET-019 | When a resident enters a heated room, the system shall reduce accumulated cold exposure by 2/hour and stop exposure damage immediately. |
| REQ-SET-020 | The system shall compute mood as the weighted need average plus active memories using the formula below and shall apply its productivity, conflict, and departure consequences. |
| REQ-SET-021 | When mood remains below 2000 across two consecutive midnights, the system shall issue an intention-to-leave warning; after a third midnight below 2000 it shall mark departure unless the resident is incapacitated. |
| REQ-SET-022 | When a warned resident's mood reaches 3500, the system shall clear the departure counter and warning. |
| REQ-SET-023 | While a resident is incapacitated, the system shall block departure and create a rescue/care job instead of letting the resident vanish. |
| REQ-SET-024 | When a departure completes at the map exit, the system shall remove that resident from population, release their home/tool, and retain relationships and chronicle history under their persistent ID. |

Mood=`clamp(floor((3*hunger+2*rest+2*comfort+social+2*purpose)/10)+sum(memory_values),0,10000)`. Productivity factor: mood<2000→600;2000–3999→800;4000–6999→1000;7000–8499→1100;≥8500→1150, denominator 1000. Health<40 adds factor 600;40–69 adds 850;≥70 adds 1000. Skill factor=`1000+50*level`; total work factor=clamp(floor(skill*mood*health/1000000),300,1800). Each work tick produces 80 milli-WU×factor/1000 with retained remainder; travel/eating/social/sleep do not produce job output.

Health/status precedence is DEAD at health=0, INCAPACITATED at health=1..15, INJURED at health=16..99 with an active Injury, otherwise ACTIVE or the current RESTING activity. A treated resident becomes conscious once health>=16. Floor sleep from exhaustion is not incapacitation and can recover without a rescuer. Health drains and recovery integrate per tick with signed remainders; a rescue does not clear an injury until treatment completes. `cold_milli_hours` stores 1000 per exposure-hour, allowing 25% reductions; `cold_hours` is its floor/1000 display value. In hard freeze, base cold gain is 2000 milli-hours/hour for tier 1 and 1000 for tier 2; apply combined food/feast reductions after that. Clearing shelter remains 2000/hour. Need caps discard overflow of either sign at the relevant bound.

Personal eating/restoring uses unmodified 60 WU/game hour; eating consumes one prepared portion at task completion, clamping fullness without refunding excess NP. Raw emergency consumption chooses enough milli-U to restore at most 3000 NP; its 12-WU duration is the same. Arrival at a safe SOCIAL room pairs the lowest-ID unpaired residents for 60 game minutes; unmatched residents use ANYTHING. Mentoring is a SOCIAL alternative selected when an available friend has a skill at least 3 levels higher: 60 minutes together grants the learner 100 XP in that skill and the declared purpose restoration, once per pair/day. It does not generate production XP or override a work/need emergency. Ingredient effect comparison uses `abs(effect_value)*remaining_hours` for the single effect slot; displayed descriptions make replacement explicit.

Memory catalog `(value,duration hours)`: good_meal(+300,6), excellent_meal(+600,8), monotonous_meal(−400,6), feast(+1000,24), friend_died(−1800,72), stranger_died(−300,24), untreated_injury(−800, until treated), rescued(+600,48), cold_home(−600,12), conflict(−600,12), milestone(+500,24). Same kind/source refreshes rather than stacks; at eight entries replace the smallest absolute value, ties earliest expiry then enum value. Death grief only applies to living residents present in the settlement.

### 5.3 Skills, jobs, schedules, relationships, and names

XP is 10 per completed productive WU in the corresponding job skill. Level=`min(10,floor_sqrt(floor(xp/5000)))`; cumulative XP at levels 0–10 is 0,5000,20000,45000,80000,125000,180000,245000,320000,405000,500000. Initial level 2 therefore means 20000 XP, not a free display value. Skills never decay. A completed batch's quality uses its lead worker's level at batch start.

Default schedule:22:00–06:00 SLEEP,06:00–07:00 ANYTHING,07:00–12:00 WORK,12:00–13:00 ANYTHING,13:00–18:00 WORK,18:00–20:00 SOCIAL,20:00–22:00 ANYTHING. Night shift is the same pattern offset 12 hours. Flexible is all ANYTHING. Sleep only continues until rest≥9000; a resident then uses ANYTHING until the scheduled sleep window ends.

| ID | EARS requirement |
|---|---|
| REQ-SET-025 | The system shall retain twelve XP columns but track/award XP only for the eleven active skill/job kinds, with RESERVED_3 permanently zero, and award XP only for productive work that consumes or advances a valid job. |
| REQ-SET-026 | When a player changes a job priority, the system shall accept 0=forbidden,1=highest,2=high,3=normal,4=low and apply the change at the next job-selection boundary. |
| REQ-SET-027 | The system shall select jobs in the exact eligibility and ordering sequence defined below. |
| REQ-SET-028 | If no permitted job is available and automatic fallback is enabled, then the system shall allow HAUL, KEEP, and low-risk FORAGE at priority 4 only when their configured priority is nonzero. |
| REQ-SET-029 | While automatic fallback is disabled, the system shall leave a resident free to meet needs rather than invent a forbidden occupation. |
| REQ-SET-030 | When a job is accepted, the system shall atomically reserve its worker, complete input quantities, output capacity, and destination work slot before movement begins. |
| REQ-SET-031 | If a reservation cannot be obtained, then the system shall keep the job queued with the exact blocking cause and shall not partially lock unrelated ingredients. |
| REQ-SET-032 | While a resident is traveling to work, the system shall renew reservation leases every 30 ticks and release them if no owner renewal occurs for 300 ticks. |
| REQ-SET-033 | If a destination remains unreachable for 300 ticks, then the system shall mark the job blocked, release reservations, and retry after 900 ticks or a navigation revision, whichever comes first. |
| REQ-SET-034 | When a schedule changes, the system shall finish at most the current 30-WU safe work segment before changing activity; emergencies shall interrupt immediately. |
| REQ-SET-035 | When a resident completes 60 WU of social activity with another resident, the system shall add 2 affinity to their relationship, capped at one such gain/pair/day. |
| REQ-SET-036 | When two residents share a feast or one completes rescue/care for the other, the system shall add 5 or 8 affinity respectively, at most once per event. |
| REQ-SET-037 | When affinity reaches 40, the system shall mark the pair friends; when it falls below 25, it shall clear friendship. |
| REQ-SET-038 | If two residents sharing a social room both have mood<2500 and affinity<0 at 18:00, then the system shall perform one daily pair conflict roll and resolve the lowest-ID passing pair per room. |
| REQ-SET-039 | When a conflict occurs, the system shall subtract 12 affinity, apply conflict memories, and remove 30 WU of social time without combat, weapon use, or physical damage. |
| REQ-SET-040 | When a resident satisfies a naming trigger below, the system shall mark them notable and assign a stable name without changing skills, needs, labor, or resource consumption. |
| REQ-SET-041 | Where a resident is anonymous, the system shall retain full persistent state and display species plus role and ID rather than a personal name. |
| REQ-SET-042 | When the player pins a resident, the system shall promote that resident to named/notable status immediately on the committed tick and allow a 2–32-character alias. |

Eligibility order: health/rescue safety; activity permits work; job kind priority nonzero; required station/tool/skill/unlock; dangerous consent; complete inputs; legal destination. Urgency buckets ascending:0 rescue/feeding an incapacitated resident;1 personal critical needs;2 food/fuel jobs while projected reserve<2 days;3 ordinary production/construction;4 cosmetic upkeep. Within a bucket sort `(player_priority,job_priority,−skill_level,estimated_path_cells,created_tick,job_id)`. Reevaluate idle residents every 30 ticks, staggered by resident ID mod 30. A worker evaluates at most 32 indexed candidate jobs per pass, continuing next pass from the saved cursor when needed; this budget never changes eligibility.

Construction, expedition, and processing WU are total work shared by the declared party, not a requirement repeated per member. A job accumulates the sum of each working member's tick contribution; productive XP is awarded to each contributing resident from their own WU. Passive waits advance calendar time once and do not accelerate with crew count. Fishing parties reserve their specified gear and aid supplies. No hunting/tracking task or hunting gear is active in rules v2.

Manual “work here” is a temporary preferred destination for 6 game hours; it does not override sleep at≤500, starvation, incapacity, explicit job prohibition, or hazardous-zone consent. Job progress belongs to the job/station, so changing workers retains progress. Input consumption occurs at WORK start; cancellation before that returns all reservations, cancellation afterward retains consumed inputs as work-in-progress salvage as defined for the recipe/building.

Relationship affinity is−100..100. At midnight, pairs without contact for 3 days move 1 point toward 0. Degree cap 8 is enforced symmetrically; to create a ninth link, remove the lowest-absolute-affinity nonfriend link, ties oldest contact then pair ID; if every link is a friendship, the event grants its need benefit without a new edge. Conflict chance=`min(3000,1000+abs(affinity)*20)` per 10000, using the relationship event stream. Shared event rolls are sorted by pair IDs.

Naming triggers: player pin; skill reaches 8; first successful rescue of an incapacitated resident; lead cook of third completed feast; appointment as Warden. Generated names use fixed 32-entry given/surname catalogs indexed by `hash(persistent_id,world_seed)` (**RWL-NAME-1**: the exact integer `hash_pair(persistent_id,world_seed)` in systems_architecture.md ARCH-RNG-001/ARCH-NAME-001, bound 2026-09-11); duplicates append decimal identity suffix `-<ID>`. All residents can be inspected before naming. Named residents receive no invulnerability or simulation-detail privilege.

Name catalog, ordered 32 entries each. Given names: Alder, Ash, Basil, Bramble, Briar, Cedar, Clover, Dell, Elm, Fennel, Fern, Flint, Hazel, Heather, Holly, Ivy, Juniper, Lark, Laurel, Linden, Maple, Moss, Nettle, Oak, Pebble, Pine, Reed, Robin, Rowan, Rue, Sorrel, Willow. Surnames: Applebank, Ashbrook, Barkridge, Beechcroft, Birchwell, Brackenford, Bramblegate, Brookside, Cedarvale, Cloverfield, Dapplewood, Dewhollow, Elmstead, Fernbank, Foxglove, Greenbough, Hazelbridge, Hearthward, Hillroot, Honeywell, Ivyglen, Leafrunner, Mossbank, Oakbarrow, Pinehollow, Reedwater, Riverbend, Rootkeeper, Softstep, Stonehearth, Thistledown, Willowmere. Given index=hash mod 32; surname index=floor(hash/32) mod 32. An assigned name remains unchanged after promotion, saving, or transfer.

*Rationale: anonymous population reduces UI noise without deleting the individual history needed for emergent stories and later transfers.*

### 5.4 Fishing

One habitat represents a connected marked basin, not one tile. Initial stocks are 80% of capacity. Availability is an integer multiplier; “closed” means no harvest job, not zero population. Species columns retain their own stock even if the UI aggregates “fish.”

| Habitat | Species | Capacity U | Spring/Summer/Autumn/Winter availability | Daily recovery r/1000 | Special window |
|---|---|---:|---|---:|---|
| River | trout |600 |1000/800/1000/500 |80 | Spring days 5–7 spawning closure |
| River | dace |900 |1000/1200/800/300 |120 | No closure |
| River | salmon |600 |0/0/2000/0 |100 | Autumn days 1–4 harvest run; days 5–8 spawning closure |
| Lake | perch |900 |800/1200/1000/600 |100 | Ice access in winter |
| Lake | carp |700 |1000/1300/1000/200 |80 | Spring days 8–10 closure |
| Lake | whitefish |600 |800/700/1000/1000 |90 | Ice fishing favored |
| Coast | herring |1200 |1200/1000/800/500 |120 | Spring days 1–4 multiplier 1500 instead of 1200 |
| Coast | mackerel |900 |500/1500/1000/0 |100 | No winter harvest |
| Coast | mussel |1000 |800/1000/1200/500 |60 | Summer blight event closes harvest |

At midnight `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`, with P/K in milli-U. The final term is external recruitment, not reproduction from nothing. Closed species still recover. Salmon additionally receive 300 U at autumn day 1, capped at K. A habitat's sustainable daily quota is `floor(K_total_milli/40)` milli-U across species (2.5% of capacity). Conservation defaults:25% habitat refuge and minimum stock 30%K. Hard harvest floor is 10%K; the 30% limit can be lowered by an explicitly visible “intensive harvest” policy, never by auto-fallback. **Ruled 2026-09-09 (READY_06 §5, decisions 0027/0036):** REQ-SET-048's restocking default BLOCKS new harvest cycles for the affected stock while its latch is set — it is not merely a warning — and that intensive policy is the only override, down to the 10% hard floor and never past a closure, an unavailable species, the quota, danger consent or required gear. The latch enters at `100*P < 30*K` and clears at `100*P > 40*K`, both STRICT, so equality at 30% or 40% flips nothing; it is updated independently of the override, and the player's explicit intensive choice is never reset automatically. Effort is measured in SLOTS, not workers: a cycle atomically reserves its whole gear requirement — one slot for net/trap/ice kit, two for weir/boat — or takes none.

| Gear | Unlock | Construction/craft cost U | Workers/effort slots | Work and passive wait | Base catch U/cycle | Wear/cycle | Access |
|---|---|---|---|---|---:|---:|---|
| Hand net | Start | wood 2, rope 1 |1/1 |60 WU |8 |20 | Bank; all species except offshore mackerel |
| Trap | M1 | wood 4, rope 2 |1/1 |20 WU set+20 WU collect;6 h soak |12 |10 | Bank; dace/perch/carp/mussel |
| Weir | M2 | wood 30, stone 12, rope 6 |1/2 |30 WU inspect;12 h accumulate |30 |5 | River only; flow 4–12 m wide |
| Boat | M3 | wood 40, cloth 8, rope 10, iron 4 |2/2 |120 party-WU |36 |15 | River/lake/coast; offshore mackerel allowed |
| Ice kit modifier | Start workbench | wood 2, iron 1 |Same as net |Net cycle 90 WU |Net base 6 |20 | Frozen lake; tier 2 clothing required |

Fishing gear durability is 0–1000; worker owns net while trap/weir/boat owns installed gear. A cycle cannot start with durability below wear. Repairs cost wood 1+rope 0.25 and 30 WU per 200 restored durability. Net/trap/boat costs produce one gear object, not food. Weirs remain structures with their listed construction costs.

Catch for species i is `floor(base_catch_milli*(1000+50*skill)*A*S/1000000000)`, where `A=clamp(floor(1000*P/K),200,1000)` and S is seasonal multiplier. Limit the result to remaining quota and allowed stock above policy floor. A gear cycle targets one selected eligible species; auto mode chooses highest `predicted_NP/work`, then earliest closure, then species ID. Group boat skill is floor(mean crew FISH levels). Rare bonus roll per cycle is `min(1000,100+30*skill)` per 10000; success makes 25% of catch EXCELLENT quality, replacing that share rather than creating extra biomass.

| ID | EARS requirement |
|---|---|
| REQ-SET-043 | The system shall maintain fishing stocks and seasonal eligibility independently for every habitat/species pair using the table above. |
| REQ-SET-044 | When a fishing cycle starts, the system shall reserve its effort slots, gear durability, expected haul capacity, and legal stock allowance. |
| REQ-SET-045 | When a cycle completes, the system shall debit actual captured biomass atomically, create corresponding fish lots, apply wear, and release unused quota reservations. |
| REQ-SET-046 | If a species closes before a queued job starts, then the system shall block that job with the reopening day and select a legal fallback species only when auto mode is enabled. |
| REQ-SET-047 | While a spawning closure is active, the system shall prohibit intensive-harvest override for the closed species. |
| REQ-SET-048 | When fishing stock falls below 30% capacity, the system shall warn of depletion and default to restocking until stock recovers above 40%. |
| REQ-SET-049 | When the player enables intensive harvest, the system shall show the 10% hard stock floor and predicted recovery time before accepting that policy. |
| REQ-SET-050 | While a habitat's effort slots are occupied, the system shall queue further fishers rather than multiply yield with unbounded workers. |
| REQ-SET-051 | Where winter ice covers a lake, the system shall permit only equipped ice-kit crews or a maintained ice-access station, while river/coast access remains weather-dependent. |
| REQ-SET-052 | If a boat faces a storm or an unstaffed required crew slot, then the system shall prevent departure and preserve its queued order. |
| REQ-SET-053 | When a fishing expedition resolves, the system shall perform its one declared hazard roll and apply the injury/rescue rules below without tactical combat. |
| REQ-SET-054 | If a fisher is incapacitated, then the system shall create a rescue job at the expedition's bank landing point and retain cargo there rather than silently deleting the resident. |
| REQ-SET-055 | The system shall display stock, quota, expected catch, gear condition, closure dates, and numerical injury risk before hazardous fishing is authorized. |
| REQ-SET-056 | The system shall classify territorial eel encounters as nonharvestable sapient encounters and pike attacks as wildlife hazards; neither shall become an edible resident species. |

Habitat effort capacity: river 4, lake 6, coast 6. Base injury chances per 10000 completed cycle: net 12, trap 8, weir 5, boat 20, ice 24. Final=`max(1,base*(1+danger)−2*crew_skill−4*additional_crew)`; danger 0–3. River pike and territorial eels are the encounter descriptions selected by habitat/day hash. Injury removes 20 health and applies severity 1 bite/cut; boat/ice hazard uses severity 2 exposure and removes 35. Each severity 2 untreated hour removes 4 health until rescue/treatment; thus death can result from an ignored rescue, not an unannounced instant-kill roll. Hazard rolls use expedition ID and cycle sequence, unaffected by rendering or camera.

*Rationale: this preserves dangerous pike/eel fishing while avoiding a species-catalog conflict with later sapient eel characters.*

### 5.5 Food-source boundary and foraging

Residents and food-source creatures are disjoint classifications. Edible aquatic species are exactly carp, dace, herring, mackerel, mussel, perch, salmon, trout and whitefish, each explicitly sapient=false in the food-stock catalog. Pike/eel encounters cannot be harvested. Mammal and bird hunting, carcasses, hides, the hunter hut and hunting gear are retired under SET-AMEND-001. FaunaStockReserved keeps only canonical empty allocation; it creates no herd proxies or stock updates. The retained forest basin partition supports forage and resource zones without a game-animal population.

| Forage item | Spring | Summer | Autumn | Winter | Patch capacity U | Base work WU/U | Daily regrowth fraction/1000 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Berries |0 |1000 |400 |0 |300 |4 |120 |
| Nuts |0 |200 |1200 |300 |240 |5 |60 |
| Mushrooms |500 |300 |1200 |0 |180 |5 |100 |
| Herb |1000 |1200 |600 |200 |160 |8 |80 |
| Roots |800 |1000 |1200 |400 |300 |6 |70 |

Season multipliers alter regenerated quantity, not the nutrition of an item. Daily regrowth=`floor((K−P)*r*season/1000000)` plus a minimum 1 U when season>0 and P<K. **Ruled 2026-09-09 (READY_06 §8A, decision 0036), settling BAL-CONFLICT-012:** the minimum is a TERM, not a floor, and the result is capped at the room left, so `growth = 0` when `season=0` or `P=K`, otherwise `growth = min(K−P, floor((K−P)*r*season/1000000) + 1000)`. A stored `P>K` is refused rather than reported as zero growth. Winter stock can be harvested where availability>0; unavailable patches become dormant, not destroyed. Sustainable floor 20%K; intensive floor 5%K. Work per U=`ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))`. Natural danger is the basin center's distance category before lookout reductions, fixed at generation. Thus danger 3 woods yield 30% more U per base labor than equal-stock danger 0 woods; safety improvements do not erase their richness. Actual hazard danger still uses staffed lookouts and resident consent. Danger zones:0 inside 32 m of any staffed lookout;1 remaining land within 64 m of the central hall;2 at 64–96 m;3 beyond 96 m. Protected tiles are never automatically harvested.

| ID | EARS requirement |
|---|---|
| REQ-SET-057 | The system shall reject sapient food stocks, species classified as both residents and food, and mammal/bird harvest sources. |
| REQ-SET-058 | When catalog definitions are compiled, the system shall restrict edible aquatic stocks to the exact nine-key whitelist and reject contradictory sapience classifications. |
| REQ-SET-059 | While rules v2 is active, the system shall keep FaunaStockReserved canonical empty and create no huntable herd proxy, carcass or hide output. |
| REQ-SET-060 | If a command requests RESERVED_3 work or a RESERVED_1 zone, then the system shall reject it before allocating a job or changing the world. |
| REQ-SET-061 | When skills are initialized, displayed, assigned or tested for milestones, the system shall keep reserved index 3 zero and exclude it from active skills. |
| REQ-SET-062 | If a recipe, scenario or save references a retired content key, then the validator shall reject it rather than substituting a resource. |
| REQ-SET-063 | When recipe catalogs are compiled, the system shall use nut_roast in place of game_roast with the exact SET-AMEND-001 Section 4 inputs and inherited output rules. |
| REQ-SET-064 | When an Orchard feast is prepared, the system shall reserve ceil(E/4) nut_roast batches for its main course and retain all other feast rules. |
| REQ-SET-065 | When old hunting RNG or stock slots are retained for schema stability, the system shall keep them inactive and reject noncanonical saved data. |
| REQ-SET-066 | The system shall maintain separate forage stocks, regrowth, availability, and protection floors for all five patch types. |
| REQ-SET-067 | While a forage zone has danger 2 or 3, the system shall require the resident's dangerous-work permission and show an exposure warning. |
| REQ-SET-068 | When a forager completes 60 WU in danger≥1, the system shall roll injury chance `max(1,8*danger−FORAGE_level)` per 10000, causing 10 health loss and severity 1 injury on success. |
| REQ-SET-069 | If a forage quota or storage limit is reached, then the system shall stop new reservations and retain already collected cargo for hauling. |

### 5.6 Farming, soil, orchards, and hives

Fields use 2 m×2 m tiles; field designation is 4–256 tiles, rectangular or painted connected area. A plot records its own growth and soil; field grouping is a UI/work aggregation. Seasons have local days 1–12.

| Crop | Family | Soils | Plant windows | Growth game hours | Yield U/tile | Seed U/tile | Moisture min–max | Frost damage/hour | Fertility cost/harvest |
|---|---|---|---|---:|---:|---:|---|---:|---:|
| Grain | CEREAL |Loam, clay |Spring 1–4 |192 |10 |0.25 |3500–7500 |1000 |1200 |
| Roots | ROOT |Loam, sand |Spring 1–8; Summer 1–4 |120 |6 |0.25 |2500–7000 |300 |700 |
| Beans | LEGUME |Loam, clay |Spring 5–10; Summer 1–3 |144 |7 |0.25 |4000–8000 |1500 |−800 |
| Cabbage | LEAF |Loam, clay |Summer 5–10; Autumn 1–3 |120 |6 |0.25 |4000–8500 |150 |900 |
| Flax | FIBER |Loam, sand |Spring 1–6 |168 |5 |0.25 |3000–7500 |800 |800 |

Seed items are separate inventory IDs. Seed separation at the workbench turns grain/roots/beans/cabbage/flax 1 U into corresponding seed 4 U for 10 WU; seed items have 0 NP and cannot be eaten. Harvesting never silently spawns seed. Any crop-compatible soil starts fertility 7000; incompatible soil rejects planting. Empty/fallow plot gains 50 fertility/day; last LEGUME crop adds another 50/day for the next 12 days.

Each plot needs 4 WU sowing,1 WU tending/day while growing, and 6 WU harvest. Sowing consumes seeds at start. Tending restores 1000 moisture using water 0.25 U when below minimum and reduces blight health loss by 50% for that day. Growth advances each hour by 1000 milli-hours×temperature_factor×moisture_factor/1000000. Temperature factor is 0 below 0°C,500 at 0–7°C,1000 at 8–26°C,700 above 26°C; moisture factor 1000 within range,500 within 2000 outside range,0 farther outside. Ripe crops remain for 48 hours before losing 10% remaining yield/day; after 5 days unharvested they become compost-equivalent waste and the plot WITHERED.

Harvest yield=`floor(base_yield_milli*fertility_factor*health_factor*rotation_factor*pollination_factor/10^12)`. Fertility factor=`500+floor(fertility/20)` (500–1000); health factor=health 0–10000 divided by 10; rotation factor=1000 for first crop/family change,850 for a second consecutive same-family harvest,700 for third+, with LEGUME after a different family 1100. Pollination factor is 1100 for beans and orchard fruit with one healthy hive within 12 m,1150 with two; other crops 1000. Cap final yield at 125% base. This formula uses int64 at the product sizes in the table.

Compost applies 2 U/tile for 8 WU and restores 1500 fertility, capped 10000, at most once/tile/season. Crop rotation is chosen manually per field or through an explicit three-entry cycle; default cycle grain→beans→roots. A missed planting window leaves the plot fallow and warns; it does not choose a different seed without the player's rotation rule.

| Orchard | Plant cost/block | Block | Maturity | Yield/mature tree/year | Harvest | Care |
|---|---|---|---|---|---|---|
| Apple |sapling_apple 1, compost 4 |4×4 tiles |96 days |80 fruit U |Autumn 1–6 |20 WU/day in spring/summer; water 2 U/day during drought |
| Pear |sapling_pear 1, compost 4 |4×4 tiles |144 days |110 fruit U |Autumn 3–8 |Same |

Each orchard block contains one modeled large fruit tree. Immature trees yield 0; age is retained across winter. Untended spring/summer days remove 100 health; tended days restore 50, max 10000. Yield multiplies health/10000 and pollination factor. Winter chill counter increments per day with temperature≤5°C; fewer than 6 chill days in the previous winter gives 75% yield. Orchard removal yields wood 8 and no refunded sapling. Saplings are propagated at a nursery for fruit 4+compost 2+water 2,120 WU plus 12-day wait; the first two saplings of each type arrive with milestone M3, preventing a fruit/sapling bootstrap loop.

Hive strength starts 8000, healthy≥5000. During spring/summer/autumn, a tended hive produces honey 2 U+wax 0.25 U/day×strength/10000; service is 20 WU/day. Winter produces 0 and consumes honey 0.5 U/day. Missing winter feed removes 500 strength/day; a missed service day in spring/summer/autumn removes 200 strength and produces no honey/wax that day; tended spring days with strength>0 restore 300 after production. Winter needs feed but no tending labor. A hive at 0 strength is abandoned and can be recolonized in spring with honey 4, wood 2,60 WU and a 3-day wait. Pollution does not exist as a player-authored industrial system in release 1; the habitat pollution field remains 0 except specified event data.

| ID | EARS requirement |
|---|---|
| REQ-SET-070 | The system shall validate field connectivity, crop soil, seed supply, planting window, and output capacity before creating sowing jobs. |
| REQ-SET-071 | When a sowing task begins, the system shall consume the exact seed quantity and retain completed work if the worker changes. |
| REQ-SET-072 | While a crop is growing, the system shall integrate hourly growth using the temperature/moisture factors and retain fractional progress. |
| REQ-SET-073 | When growth reaches the crop's duration, the system shall mark it ripe and create a priority 2 harvest job. |
| REQ-SET-074 | When harvest completes, the system shall calculate yield from fertility, health, rotation, and pollination and apply the listed fertility change once. |
| REQ-SET-075 | If a ripe crop remains unharvested beyond its grace period, then the system shall apply the specified loss and ultimately mark it withered. |
| REQ-SET-076 | When compost is applied, the system shall consume 2 U, add 1500 fertility, and prevent repeat application until the next season. |
| REQ-SET-077 | When an automated field rotation advances, the system shall choose the next explicitly configured crop and show blocked reasons if its requirements fail. |
| REQ-SET-078 | While a field is fallow, the system shall restore fertility at the declared daily rate without requiring a worker. |
| REQ-SET-079 | When an orchard reaches maturity, the system shall enable its next legal annual harvest without retroactively generating previous years' fruit. |
| REQ-SET-080 | When an orchard harvest completes, the system shall set its harvested-year flag and prohibit a second harvest that year. |
| REQ-SET-081 | When the player plants an orchard, the system shall show the exact first eligible harvest year/day and occupied block before confirmation. |
| REQ-SET-082 | While a healthy hive is within 12 m of a pollinated crop, the system shall grant the bounded one/two-hive multiplier and ignore further hives for that crop. |
| REQ-SET-083 | When a hive is unserved or unfed, the system shall apply strength losses and show feed/service deficits before abandonment. |
| REQ-SET-084 | When frost affects a growing crop, the system shall remove the listed health/hour while temperature<0°C, halved for cabbage in a tended plot. |
| REQ-SET-085 | If crop health reaches 0, then the system shall mark it withered, cancel tending/harvest, and create a 10-WU clearing job yielding compost 0.5 U/tile. |
| REQ-SET-086 | When weather changes plot moisture, the system shall clamp moisture 0–10000 and show its growth consequence in the crop panel. |
| REQ-SET-087 | While a crop is within a blight event, the system shall remove 400 health/day, reduced to 200 if tended, and stop damage when the event ends. |
| REQ-SET-088 | When a seed reserve is enabled, the system shall reserve enough seed for the next configured planting across designated fields before allowing seed export or nonplanting use. |
| REQ-SET-089 | If a required seed becomes unobtainable, then the system shall expose the workbench seed-separation recipe and an emergency seed grant option defined in Section 7 instead of leaving an unexplained deadlock. |

### 5.7 Item, cooking, preservation, and feast catalogs

All raw food units weigh 250 g; prepared meal/ration units weigh 500 g; honey/nuts still use 250 g/U. Water is 1000 g/U. Material masses: wood 5000g, stone 5000g, iron 2000g, rope 500g, cloth 250g, tool 1000g, wax 250g, compost 1000g, seed 100g, sapling 1000g, salt 250g. Portable gear masses are net 1000 g, trap 3000 g, ice_kit 2000 g, outfit_tier2 500 g, candle 125 g. Equipped tools/outfits are outside satchel capacity. Boats/weirs are assembled in place and never hauled as single inventory items; only their materials are hauled. Construction and crafting transform recipe units; resource masses are storage costs, not a physical conservation model.

| Food category/item | NP/U raw | Raw edible | Base shelf hours | Ingredient effect |
|---|---:|---|---:|---|
| Grain/flour |1200 |No |720/240 |Satiety: hunger decay−5% for 6 h |
| Roots |800 |Yes |240 |Warmth: exposure accumulation−25% for 6 h |
| Beans |1100 |No |480 |Stamina: awake rest decay−5% for 6 h |
| Cabbage |600 |Yes |144 |Recovery: passive health restoration+1/hour for 6 h |
| Berries |700 |Yes |48 |Cheer: mood+200 for 6 h |
| Nuts |1600 |Yes |720 |Satiety: hunger decay−5% for 6 h |
| Mushrooms |600 |No |72 |Purpose: purpose restoration+10% for 6 h |
| Fruit |900 |Yes |144 |Cheer: mood+200 for 6 h |
| Honey |1200 |Yes |1440 |Social: social restoration+10% for 6 h |
| All fish species except mussel |1400 |No |48 |Recovery: passive health restoration+1/hour for 6 h |
| Mussel |1000 |No |36 |Stamina: awake rest decay−5% for 6 h |
| Herb |0 |No |480 |Care ingredient; no nutritional replacement |
| Mead |0 |No |1440 |Feast ingredient only; no intoxication subsystem |

Only the dominant **nonwater** ingredient by input mass grants the dish effect, ties item catalog ID; named recipe overrides are listed where used. Raw edible food grants its listed effect at half magnitude, integer rounded toward zero. Multiple food effects do not stack: a new effect replaces the previous one only if its remaining magnitude×hours value is greater, ties newest. Mood memory from meal quality is separate.

Recipe quantities are U, work is WU per batch, output meal nutrition is per portion. Mixed ingredient categories bind concrete lots at reservation time and preserve that selection through completion.

| Recipe ID | Inputs | Outputs | WU | Station/skill | Shelf h | Unlock |
|---|---|---|---:|---|---:|---|
| porridge |grain 2, water 2 |meal_porridge 2×1800 NP |12 |Kitchen/COOK |24 |Start |
| root_stew |roots 3, water 1 |meal_root_stew 2×1800 |16 |Kitchen/COOK |24 |Start |
| fish_stew |fish 2, roots 2, water 2 |meal_fish_stew 3×2200 |20 |Kitchen/COOK |24 |Start |
| bean_hotpot |beans 2, cabbage 2, water 2 |meal_bean_hotpot 3×2100 |20 |Kitchen/COOK |36 |M1 |
| woodland_pie |flour 2, mushrooms 2, roots 1, water 1 |meal_pie 3×2300 |30 |Kitchen/COOK |48 |M2 |
| nut_roast |beans 3, roots 2, nuts 1, herb 0.25 |meal_nut_roast 4×2400 |30 |Kitchen/COOK |36 |M2 |
| berry_tart |flour 2, berries 2, honey 0.5, water 1 |meal_tart 3×2200 |28 |Kitchen/COOK |48 |M2 |
| orchard_crumble |fruit 3, flour 2, honey 0.5 |meal_crumble 3×2300 |28 |Kitchen/COOK |48 |M3 |
| nut_loaf |flour 2, nuts 2, water 1 |meal_nut_loaf 3×2600 |24 |Kitchen/COOK |72 |M1 |
| feast_fish |fish 4, roots 2, herb 0.5, water 2 |meal_feast_fish 6×2500 |48 |Kitchen/COOK |36 |M2 |
| flour |grain 3 |flour 3 |12 |Mill/CRAFT |240 |M1 |
| dry_fish |fish 4 |dried_fish 3×1800 |24+12 h passive |Dryer/PRESERVE |720 |Start |
| dry_fruit |fruit 4 |dried_fruit3×1400 |20+12 h passive |Dryer/PRESERVE |720 |M3 |
| salt_fish |fish 4, salt 1 |salted_fish4×1600 |20+6 h passive |Preserver/PRESERVE |960 |M1 |
| ration |flour 2, dried_fish 1, nuts 1, water 1 |ration 3×2400 |24 |Kitchen/PRESERVE |1440 |M2 |
| mead |honey 3, water 3 |mead 4 |20+72 h passive |Brewery/COOK |1440 |M2 |
| compost |spoiled_food 4 or roots 4 |compost 2 |20+24 h passive |Composter/KEEP |Unlimited |Start |
| cloth |flax 4 |cloth 2 |30 |Workshop/CRAFT |Unlimited |M1 |
| rope |flax 2 |rope 2 |20 |Workbench/CRAFT |Unlimited |Start |
| tool |wood 2, stone 1 |tool 1 |30 |Workbench/CRAFT |Unlimited |Start |
| iron_tool |wood 1, iron 1 |tool 1 at 1500 durability |40 |Workshop/CRAFT |Unlimited |M2 |
| outfit |cloth 2 |outfit_tier2 1 |40 |Workshop/CRAFT |Unlimited |M1 |
| salt |water 4 |salt 1 |20+24 h passive |Saltpan/PRESERVE |Unlimited |M1/coastal water source |
| wax_candle |wax 1, flax 0.25 |candle 4 |16 |Workbench/CRAFT |Unlimited |M2 |

The salt recipe accepts only lots with coastal-brine provenance; well/river water is rejected. Brine has 0 NP and its own inventory item ID despite sharing 1000g mass. Generic fish excludes sapient eels and pike hazard encounters. Dried/salted fish and smoked game are directly edible; dried fruit is directly edible; rations are directly edible. Their effect is the source ingredient's effect. Raw ingredients marked “No” cannot be consumed even in emergency.

Cooking efficiency applies only to grain/flour/roots/beans/cabbage inputs: required milli-U=`base_milli*(1000−10*COOK_level)/1000`, floor, for max 10% saving. It does not reduce herbs, water, salt, seeds, feast attendee requirements, or preservation inputs. Output count is fixed. Quality score=`clamp(40+4*lead_skill+10*station_tier+floor(mean_input_quality/1000)−floor(max_input_age_fraction*20/10000)+R,0,100)`, R is deterministic integer−10..10 once/batch; input quality is 2500/5000/7500/10000. Score<40 POOR,40–64 PLAIN,65–84 GOOD,≥85 EXCELLENT. Output quality nutrition factor 900/1000/1050/1100 respectively.

Meal variety uses last 6 recipe IDs: repeat count 0–1 no penalty;2–3 applies monotonous memory−200;4–6 applies−400. Ingredient differences inside the same recipe do not fake variety. Consumption prefers policy-permitted portions by `(expiry_age_remaining,−quality,recipe_id,lot_id)` unless variety-first policy is chosen, in which case lowest repeat count precedes expiry. Foods expiring within 6 effective hours always override variety-first to reduce waste.

| ID | EARS requirement |
|---|---|
| REQ-SET-090 | The system shall implement the exact recipe graph, input categories, station restrictions, work/passive durations, nutrition, and shelf lives above. |
| REQ-SET-091 | When cooking starts, the system shall snapshot skill, input-lot quality/age, recipe, output capacity, and quality RNG roll so worker replacement does not reroll quality. |
| REQ-SET-092 | When a cooking batch completes, the system shall consume its work-in-progress record and create only the declared outputs at the computed quality. |
| REQ-SET-093 | While a passive drying/salting/fermentation stage is active, the system shall occupy a station batch slot but release the worker for other work. |
| REQ-SET-094 | If production is cancelled after input consumption, then the system shall yield 50% of food input mass as spoiled_food, rounded down to milli-U, and no finished portions. |
| REQ-SET-095 | When a resident eats, the system shall apply portion nutrition, bounded ingredient effect, quality memory, and meal-history update once. |
| REQ-SET-096 | When a recipe has been produced at GOOD or EXCELLENT quality 20 times, the system shall mark it mastered for progression without adding a hidden yield multiplier. |
| REQ-SET-097 | The system shall provide ONCE, REPEAT, and MAINTAIN_STOCK production orders with an explicit target and lot-reservation accounting. |
| REQ-SET-098 | While MAINTAIN_STOCK is enabled, the system shall count unreserved inventory plus committed in-progress outputs against the target before issuing another batch. |
| REQ-SET-099 | If a recipe lacks an input, station, worker, tool, unlock, or output space, then the system shall display that specific blocking reason and the missing quantity. |
| REQ-SET-100 | When a feast is planned, the system shall calculate attendee count, complete ingredient/portion requirements, seating waves, staffing, and post-feast reserves before accepting the plan. |
| REQ-SET-101 | If a feast would leave fewer than 3 food-days or 3 fuel-days, then the system shall block confirmation until the player explicitly overrides the reserve warning for that feast. |
| REQ-SET-102 | While a feast is preparing, the system shall reserve only its declared portions and shall release them if cancelled before the serving event. |
| REQ-SET-103 | When a ready feast begins at 18:00, the system shall serve eligible attendees over up to three one-hour waves and consume each resident's portions only on attendance. |
| REQ-SET-104 | When at least 80% of eligible residents attend all required courses, the system shall grant the theme's settlement buff; otherwise it shall grant attendee meals/social benefits without a settlement buff. |
| REQ-SET-105 | While a feast buff is active, the system shall apply its declared magnitude/duration once and shall prevent a same-theme stack or duration extension. |
| REQ-SET-106 | If a feast is interrupted by a critical emergency, then the system shall pause serving, retain unserved reserved portions, and cancel the remainder after 24 game hours if not resumed. |

Feast costs use actual portions; raw inputs follow the recipe table without a separate hidden fee. Eligible count E is all living residents present at confirmation, including incapacitated residents and excluding residents already in LEAVING or TRANSFERRED status. Incapacitated residents receive bedside service and remain part of the coverage denominator. Batch counts are rounded up; surplus portions remain ordinary inventory.

| Theme | Unlock | Main batches | Second-course batches | Beverage/condiment | Settlement buff |
|---|---|---|---|---|---|
| Hearth |M1 |ceil(E/3) bean_hotpot |ceil(E/3) nut_loaf |Warm infusion: water ceil(E/4) U + herb 0.25×ceil(E/12) U |Shared Warmth: cold-exposure accumulation−25% and mood+400 for 48 h |
| Harvest |M2 |ceil(E/6) feast_fish |ceil(E/3) berry_tart |mead ceil(E/4) U |Abundant Tables: purpose restoration+20% and work speed+5% for 48 h |
| Orchard |M3 |ceil(E/4) nut_roast |ceil(E/3) orchard_crumble |mead ceil(E/4) U |Rooted Community: social decay−20% for 48 h; immigration candidates+2 at the next event within 72 h |

Hearth infusion is prepared during service from its reserved water/herb; it has no stored output item or extra work beyond the staffing/service duration. It grants no separate nutrition or ingredient buff. Thus the M1 feast requires only M1-or-earlier inputs and stations. Mead is brewed before M2/M3 service. All feast beverage reservations use concrete item IDs; coastal brine never substitutes for water.

Each attendee receives one main and one second-course portion. Beverage quantity is consumed proportionally to attended/E with milli-unit rounding at the last attendee. Staffing is 2 cooks+1 keeper, skill≥2; seats≥ceil(E/3), except bedside attendees need no seat. Service consumes wood ceil(E/12) U, reserved at confirmation. At most one feast may start in any 72-game-hour interval. Every attendee gains social+2500 and feast memory+1000 for 24 h. Global work buffs cap+10%, hunger-decay reductions cap 10%, and cold-exposure reductions cap 40% across food/feast effects. A feast never requires a recipe unlocked later than its theme.

*Rationale: fixed portions and explicit reserve checks make a feast a real economic decision; the meal's benefits cannot be duplicated by repeatedly reopening the feast panel.*

### 5.8 Inventory, spoilage, logistics, and reserve forecasts

Age is effective storage age, not calendar expiry overwritten at every move. Base age per game hour is 1000 milli-hours; store factor open pile 1500, covered store 1000, pantry 750, cellar 350. Seasonal temperature factor spring 1000/summer 1500/autumn 1000/winter 500; heated interiors use 1000 in winter. Effective age per hour=`floor(store_factor*temperature_factor/1000)`, retaining tick fractions. Changing stores never resets age. Prepared food left on tables uses open-pile factor. Unlimited shelf items have shelf_hours=0 and do not spoil.

When age reaches shelf_hours×1000, food becomes spoiled_food at identical mass. NP becomes 0. Seed shelf life is 1440h and spoilage becomes compost material. Spoiled_food lasts 240h then is removed as waste with a notice, preventing permanent lot growth. Stack merge requires identical item, quality, recipe, provenance, and age rounded **up** to the next full effective hour; merged age is the older rounded age. Reservations remain attached or are remapped atomically.

Food-days=`floor(100*sum(edible_unreserved_NP)/daily_demand_NP)/100`, displayed two decimals; NP includes currently edible prepared and safe raw food, excludes seeds, raw inedible ingredients, expired food, and locked feast/export reservations. Daily demand uses each living resident's size and today's season multiplier; wounded residents still count. A separate “potential food” counter may show raw ingredients convertible by enabled recipes, but cannot be added to ready food-days.

Fuel-days=`available_wood_equivalent/daily_heating_demand`. One wood U heats one hearth for 6 game hours. A heated room can cover at most 120 interior tiles, so one normal residence/hall hearth consumes 4 wood/day in winter; spring/autumn consume 2/day when daily mean<10°C, summer 0. Kitchen production consumes wood 0.1 U/batch in addition to recipe-listed wood. Forecast includes this last-three-days mean cooking use. If heating demand 0, display “No current heat demand,” not infinite days.

| ID | EARS requirement |
|---|---|
| REQ-SET-107 | The system shall store food as quality/age/provenance lots and apply effective aging without resetting freshness on transport, merge, save, or load. |
| REQ-SET-108 | When a food lot expires, the system shall invalidate its food reservations, create spoiled_food of equal mass, and trigger recipe/meal replanning. |
| REQ-SET-109 | When selecting inventory for a recipe or meal, the system shall use first-expiring-first-out among legal lots unless the explicit meal-variety policy applies. |
| REQ-SET-110 | If storage capacity is insufficient, then the system shall stop new production reservations and allow existing cargo to be placed in a visible temporary ground pile at the destination. |
| REQ-SET-111 | When a haul job begins, the system shall limit carried mass by the resident's species capacity and split quantity exactly without cloning lots. |
| REQ-SET-112 | The system shall reserve output mass before production starts, counting committed outputs, queued deliveries, and current contents against capacity. |
| REQ-SET-113 | While food-days are below 2, the system shall raise food acquisition, cooking, and required hauling into emergency urgency bucket 2 without overriding forbidden or hazardous occupations. |
| REQ-SET-114 | When the next season is winter, the system shall display a twelve-day winter food/fuel projection using winter demand and current edible/preservable stocks separately. |
| REQ-SET-115 | When food is allocated to a future transfer manifest, the system shall remove that quantity from available settlement reserves while retaining it in total-owned inventory. |
| REQ-SET-116 | If a reserved lot is destroyed or becomes unreachable, then the system shall invalidate dependent jobs in stable job-ID order, release unaffected reservations, and show the broken dependency. |
| REQ-SET-117 | The system shall allow pantry/store filters and minimum reserves per item, with emergency meal access overriding ordinary production minimums but never seed classification. |
| REQ-SET-118 | When a recipe's consumed inputs become work-in-progress, the system shall remove them from edible inventories and exclude them from meal availability until valid output exists. |
| REQ-SET-119 | The system shall recompute ready food-days, potential food, fuel-days, and projected shortage dates every game hour and on committed stock/policy changes. |
| REQ-SET-120 | If the lot or reservation cap is reached, then the system shall merge eligible lots and refuse new nonessential orders with a diagnostic; it shall not delete existing resources. |

### 5.9 Building catalog, placement, interiors, and upgrades

Footprints are 2 m tiles, rotation in 90° steps. Materials are U; WU is total shared construction work, not per worker. Maximum 4 builders/project unless listed. Indoor kit themes change geometry only.

| Building | Footprint | Materials | WU | Operational slots | Managed interior / capacity | Unlock |
|---|---|---|---:|---:|---|---|
| Refuge/community hall |12×10 |wood 100, stone 60, cloth 12 |2400 |Keeper 2 |Interior 10×8; configured rooms |Start |
| Residence |10×8 |wood 60, stone 24, cloth 8 |1200 |0 |Interior 8×6;12-bed layout capacity; furniture purchased separately |Start |
| Infirmary |8×8 |wood 40, stone 30, cloth 12 |1000 |Healer 2 |Interior 6×6;8 patient beds |M1 |
| Kitchen |6×6 |wood 30, stone 20, iron 2 |600 |Cook 2 |Black box;2 cooking slots |Start |
| Open stockpile |4×4 |wood 4 |60 |0 |400000g; open storage |Start |
| Covered store |6×6 |wood 35, stone 10 |480 |Hauler 2 |1500000g; covered storage |Start |
| Cellar |6×6 |wood 20, stone 60 |900 |Hauler 2 |1000000g; cellar storage |M1 |
| Well |2×2 |wood 10, stone 20 |240 |Hauler 2 |Draw water 10 U/10 WU |Start |
| Workbench shelter |3×3 |wood 12, stone 4 |180 |Crafter 2 |2 craft slots |Start |
| Workshop |6×6 |wood 35, stone 20, iron 4 |720 |Crafter 3 |3 craft slots |M1 |
| Mill |5×5 |wood 25, stone 30 |720 |Crafter 2 |2 mill slots |M1 |
| Dryer |4×3 |wood 16, rope 4 |240 |Preserver 1 |4 passive batch slots |Start |
| Preserver/smokehouse |5×4 |wood 20, stone 24, iron 2 |480 |Preserver 2 |4 passive batch slots |M1 |
| Fisher shelter |4×3 |wood 18, rope 2 |240 |Fisher 2 |Gear locker; bank access |Start |
| Weir |4×2 |wood 30, stone 12, rope 6 |480 |Fisher 1 |2 habitat effort slots |M2 |
| Boathouse |6×4 |wood 40, stone 16, rope 4 |720 |Fisher 4 |2 stored boats; shore line |M3 |
| Composter |3×3 |wood 10 |120 |Keeper 1 |4 passive batch slots |Start |
| Apiary |3×3 |wood 12, rope 2 |180 |Keeper 1 |1 hive |M2 |
| Nursery |4×4 |wood 16, stone 8 |300 |Tender 2 |4 propagation slots |M3 |
| Brewery |5×4 |wood 24, stone 12, iron 2 |480 |Cook 1 |4 passive batch slots |M2 |
| Saltpan |4×4 |wood 8, stone 16 |240 |Preserver 1 |4 passive slots; coast≤4 m |M1 |
| Forester lodge |4×4 |wood 20, stone 8 |240 |Keeper 3 |Managed tree-zone access |Start |
| Quarry shed |4×4 |wood 16, stone 8 |240 |Crafter 3 |Stone/iron source access |Start |
| Lookout |2×2 |wood 12, stone 4 |180 |Keeper 1 |32 m low-risk radius when staffed |M1 |
| Fence segment |1×1 |wood 1 |12 |0 |Wildlife exclusion boundary |Start |
| Stone wall segment |1×1 |stone 3 |30 |0 |Weather/wildlife boundary |M2 |
| Gate |2×1 |wood 6, iron 1 |90 |0 |Passable toggle |Start |
| Dirt path |1×1 |None |2 |0 |Ground speed+10% |Start |
| Paved path |1×1 |stone 1 |6 |0 |Ground speed+20%; replaces dirt |M2 |
| Memorial garden |4×4 |wood 8, stone 12 |240 |Keeper 1 |16 permanent grave entries; visual reuse after 48 days |Start |

Construction materials are delivered to the project container before BUILD phase; workers can deliver in parts, but ordinary production reservations cannot consume delivered construction goods. Build rate sums up to 4 workers' actual work rates. A two-worker residence takes 600 base productive WU/worker, excluding hauling and travel.

Managed-building heat is a connected service: a fueled hearth supplies every valid room connected by open boundaries or interior doors within that building, up to 120 total interior tiles per hearth. Thus the starter dormitory receives its kitchen hearth's heat. Closed impermeable partitions without doors split the heated component. Allocate capacity by hearth ID, then room ID; a room is heated only if its entire tile count fits. Unheated indoors restores no room comfort and follows the hourly temperature convergence rule. Outdoor comfort restoration stops at 6000.

Operational stores for black-box production structures hold 100000 g input/output mass total, except fisher/boathouse gear lockers 200000 g. Passive batch slots and active worker slots are separate constraints. Ground piles hold at most 400000 g each and have 1500 aging factor; create adjacent passable tiles in N,E,S,W breadth-first order when a pile is full. Flax weighs 250 g/U, has no nutrition, and never spoils; dried_fish/salted_fish/dried_fruit weigh 250 g/U. Spoiled_food weighs 250 g/U, raw edible false; loss conversion uses milli-U to conserve its declared mass. General nonfood materials have shelf 0 and default quality PLAIN.

Generic BUILD/CRAFT/FARM/KEEP extraction work consumes 1 equipped tool durability per completed 10 WU; preserve remainder across tasks. No generic wear applies to eating, sleeping, socializing, healing, hauling, cooking, or gear-specific fishing cycles. Basic tools cap 1000, iron tools cap 1500; the fishing table's 1000 cap applies to fishing gear only. Repair uses wood 1+stone 0.5 and 30 WU to restore 200 general-tool durability up to its cap. Broken tools block tool-required work; bare-hand branch/stone recovery and basic-tool crafting remain available. Basic gear crafting at a workbench costs 30 WU/net, 40/trap, 40/ice_kit; boat assembly at boathouse costs 480 WU using its fishing-table materials. Changing equipment is a HAUL task of 4 WU plus travel and never creates a new item.

Wildlife pressure is one existing midnight ecology check per forage basin/apiary during summer/autumn: chance 200/10000, halved to 100 by a complete enclosing fence/wall boundary. On success remove min(2 U, current honey) from an apiary, or min(5 U,current stock) from that basin's highest-stock currently available forage item, ties item ID. Emit an advisory; do not injure residents. Lookout staffing reduces zone danger only, not this roll. No additional random disaster, structure fire, siege, or raider simulation exists in release 1.

Resource extraction recipes: tree 12 wood/120 WU, stone 4 U/120 WU, iron 2 U/180 WU. Surface stone deposits can exhaust; a quarry placed at the guaranteed bedrock source yields stone 4/180 WU indefinitely. Iron is optional efficiency equipment after the initial deposit. Trees regrow after 48 days when their stumps remain and no building occupies the tile; planting a cleared forestry tile costs compost 0.25 U and 4 WU, also maturing after 48 days. A forestry zone retains at least 20% mature trees by default; intensive override retains 10%. Fences reduce forage/hive wildlife-loss events by 50% when a closed boundary encloses the relevant tiles, not just when one fence is nearby.

| Furniture | Footprint tiles | Materials U | WU | Function |
|---|---|---|---:|---|
| Bed |1×1 |wood 2, cloth 1 |20 |1 resident; adjacent walk tile |
| Patient bed |1×1 |wood 2, cloth 2 |24 |1 patient; adjacent walk tile |
| Seat/table place |1×1 |wood 1 |10 |1 diner; group table visuals merge |
| Kitchen bench |2×1 |wood 4, stone 4, iron 1 |60 |1 cooking slot |
| Hearth |2×1 |stone 6 |60 |Heat up to 120 interior tiles |
| Shelf |1×1 |wood 2 |16 |50000g pantry capacity |
| Decoration |1×1 |wood 1, wax 0.25 |12 |Room comfort target+250, cap 1000 |
| Interior partition |Tile edge |wood 1 |8 |Room boundary; no floor occupation |
| Interior door |Tile edge |wood 2 |12 |Passable boundary; maintains heat |

Room validity: dormitory≥3 tiles/bed, at least 1 bed, all bed-adjacent access connected to exterior door; private room≥6 tiles, exactly 1 bed, partitioned enclosure; dining≥2 tiles/seat and≥4 seats; kitchen≥6 tiles,≥1 bench,≥1 hearth; common≥8 tiles,≥4 seats; infirmary≥3 tiles/patient bed,≥1 bed,≥1 shelf, heated; pantry≥4 tiles,≥1 shelf; corridor≥1 tile wide, linked to exterior. One tile belongs to exactly one room, furniture cannot overlap, and at least one connected walk path must reach every usable furniture access tile. Room occupancy is authoritative; roof visibility is presentation.

Default starter interior is 10×8 tiles. B=bed, K=kitchen bench cell, H=hearth cell, S=shelf, T=seat, .=walk tile. The left 5 columns form a 40-tile dormitory with 12 beds; the right 5 columns form kitchen on rows 0–1 (10 tiles), common room on rows 2–6 (25 tiles), and pantry on row 7 (5 tiles). A partition separates x4/x5, with a door at row 4. Other room designations share open walkable boundaries. The exterior south door is at x5. Coordinates are zero-based.

```text
BBBB..KKHH
.........S
BBBB..TTTT
..........
BBBB..TTTT
......TTTT
..........
......SSSS
```

Every seat has an adjacent walk tile above or below; shelves can be reached from the open common-room edge. Four pantry shelves supply 200000g storage. The fifth S at kitchen row 1 is a separate kitchen-owned shelf; it adds no pantry capacity or new industrial buffer. R-BUILD-DOM-004 preserves all five instances. On the 128×128 exterior tile grid, place the hall at(58,59), stockpiles at(50,60),(50,65),(70,60),(70,65), well at(64,54), and workbench at(58,54), all rotation 0. Clear these footprints before resource placement. Hall interior origin is exterior origin+(1,1). Four stockpiles provide 1600000g material storage; starting food fits the pantry. All initial items are assigned to legal containers by food first, then item ID, filling container IDs ascending.

*Baseline fixture boundary: the layout above specifies the existing starter interior, not the limit of the required construction system. DEC-029/031 and SET-MOVE-001 require placed burrows, planned tunnels/rooms and free multi-level excavation to work together. The former one-floor release restriction is superseded. Finish MOVE-G01/G02 before treating room/service rules and capacity bounds as complete for expanded space.*

| ID | EARS requirement |
|---|---|
| REQ-SET-121 | The system shall implement the building/furniture catalog with listed costs, work, capacities, unlocks, and exterior/interior representations. |
| REQ-SET-122 | When placing a building, the system shall require in-bounds nonoverlapping tiles, slope≤8°, height spread≤0.5 m, an accessible door, and its terrain-specific conditions. |
| REQ-SET-123 | If a placement would sever the last path from any occupied home/workplace to the central hall, then the system shall reject it and highlight the cut route. |
| REQ-SET-124 | When a blueprint is placed, the system shall create material-delivery and construction work without deducting undelivered materials from physical stores. |
| REQ-SET-125 | When delivered materials are complete, the system shall enable build work and consume those materials into the project as progress begins. |
| REQ-SET-126 | If a blueprint is cancelled before work begins, then the system shall return 100% of delivered materials as reachable ground lots; after work begins it shall return 80% of delivered materials, rounded down to milli-U. |
| REQ-SET-127 | When an active building is demolished, the system shall first evacuate residents and move stored goods, then return 50% original material costs after the declared construction WU×0.25 demolition work. |
| REQ-SET-128 | If goods or residents cannot be evacuated, then the system shall block demolition and show the exact stranded occupants/lots. |
| REQ-SET-129 | When a room/furniture layout changes, the system shall flood-fill room/access tiles and suspend services from invalid rooms without deleting beds, goods, or residents. |
| REQ-SET-130 | While a room is heated, the system shall consume fuel proportionally over game hours and maintain 18°C indoors at tier 1 or 20°C at tier 2. |
| REQ-SET-131 | If a hearth runs out of fuel, then the system shall converge room temperature halfway toward outside temperature each game hour and create an urgent refuel job. |
| REQ-SET-132 | When allocating beds, the system shall prefer the resident's current valid bed, then the nearest free permitted bed, ties building ID/furniture ID. |
| REQ-SET-133 | If no bed is available, then the system shall assign safe floor sleep in a reachable heated hall and issue a housing deficit alert. |
| REQ-SET-134 | When a kitchen door is within 8 m walking distance of a pantry/store access point, the system shall reduce hauling work for that connection by 10%, without changing ingredient quantities. |
| REQ-SET-135 | Where a valid dining/common room is within 12 m walking distance of a kitchen, the system shall add comfort 200 per served meal and show the adjacency bonus. |
| REQ-SET-136 | When a tier 1 residence/hall/store/workshop is upgraded, the system shall apply the exact upgrade package below without multiplying previous upgrades recursively. |
| REQ-SET-137 | While construction or demolition is paused by the player, the system shall retain delivered materials/progress and release workers and unfinished ingredient leases. |
| REQ-SET-138 | When a tree is felled, the system shall debit its wood once and leave a dated stump for permitted regrowth. |
| REQ-SET-139 | When a renewable bedrock quarry is used, the system shall generate only its declared work output and shall never require a tool material available exclusively from that same unavailable tool. |
| REQ-SET-140 | The system shall implement fences, walls, and lookouts solely as access, wildlife, and risk-management structures in settlement release 1, with no attack commands. |

Tier 2 upgrade packages: residence/hall stone 40+wood 20+cloth 8,1200 WU, heat fuel×0.75 and room comfort target+1000, no new floor/beds; store wood 25+stone 20,600 WU, capacity+100% of tier 1; workshop wood 20+iron 8,720 WU, craft speed+10%, slots remain 3. Only one upgrade per building; tier 3 is absent. Baseline comfort targets: floor/camp 2000, dormitory 6000, private 8000, heated common 7500; these targets cap the room's comfort restoration, and decorations add up to 1000 without exceeding 10000.

### 5.10 Seasons, weather, ecology events, and winter

| Season | Daylight | Baseline temperature | Rain/moisture per day | Pressure |
|---|---|---:|---:|---|
| Spring |06:00–19:00 |12°C |+1200 |Seed labor, spawning protection |
| Summer |05:00–21:00 |22°C |+300 |Dryness, fresh-food spoilage |
| Autumn |07:00–18:00 |10°C |+700 |Harvest, salmon run, preservation |
| Winter |08:00–16:00 |−5°C |+0 |Frozen soil, higher appetite, fuel |

Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer; rain adds after evaporation. Weather uses the following bounded seasonal event draw at season start, announced three days before its start. Exactly one major event occurs per season, selected by an isolated RNG stream; start day is 6, except early frost day 10. No other random disasters stack with it.

| Event | Eligible season | Weight | Duration | Exact effects |
|---|---|---:|---:|---|
| Ideal spell |Any |30 |3 days |Temperature 18°C except winter 2°C; crop growth×1.20; rain+600/day |
| Heavy rain/storm |Spring/autumn |35 |2 days |Temperature−3°C from baseline; rain+2000/day; boats disabled; outdoor work×0.80 |
| Drought |Summer |50 |4 days |Temperature 30°C; rain 0; extra moisture−1500/day; orchard water needed |
| Blight |Summer/autumn |20 |3 days |Crop damage 400/day; summer mussel harvest closes; no contagious spread outside event |
| Early frost |Autumn |30 |2 days |Temperature−3°C; frost effects; start day 10 |
| Hard freeze |Winter |60 |3 days |Temperature−12°C; outdoor exposure accumulation×2; lake ice access only |
| Calm days |Any |20 |2 days |No modifier; explicitly announced safe interval |

Weights are normalized within the season's eligible rows. First spring is forced Ideal spell on day 6 as onboarding, with the same visible rules; subsequent draws use RNG. **Roll-to-row mapping (ruled 2026-09-09, decision 0028).** "Normalized" means relative probability within the eligible set; no numeric percentage conversion is performed. Scan the event order printed above, filtered to the season's eligible rows, retaining raw integer weights: `roll = uint32_draw mod weight_sum`, then select the first row whose running cumulative weight strictly exceeds the roll. Modulo bias is accepted and disclosed; rejection sampling remains forbidden under ARCH-RNG-002. The season index orders the event and shall not cause per-season reseeding.

| Season | Weight sum | Reduced-roll mapping (inclusive) |
|---|---:|---|
| Spring | 85 | Ideal spell 0-29; Heavy rain/storm 30-64; Calm days 65-84 |
| Summer | 120 | Ideal spell 0-29; Drought 30-79; Blight 80-99; Calm days 100-119 |
| Autumn | 135 | Ideal spell 0-29; Heavy rain/storm 30-64; Blight 65-84; Early frost 85-114; Calm days 115-134 |
| Winter | 110 | Ideal spell 0-29; Hard freeze 30-89; Calm days 90-109 |
 Daylight affects visibility and work: unlit outdoor productive work×0.75 in darkness; no change to paths or invisible probability. Tier 2 clothing removes baseline cold exposure at−5°C, but hard freeze adds 1/hour even with that clothing; heated shelter still clears it. Torches/candles prevent the darkness productivity loss within 12 m; one candle lasts 12 game hours, one torch consumes wood 0.25 U/6h.

| ID | EARS requirement |
|---|---|
| REQ-SET-141 | The system shall advance seasons by local day and apply all stock, crop, daylight, hunger, storage, and heating changes at the exact boundary. |
| REQ-SET-142 | When a major event is scheduled, the system shall disclose its start, duration, and affected systems three days in advance and retain that forecast in the calendar. |
| REQ-SET-143 | While winter is active, the system shall multiply hunger demand by 1.20 and use winter ecological availability even if the camera is indoors. |
| REQ-SET-144 | While hard freeze is active, the system shall apply the explicit clothing/exposure rules and prevent unsafe boat departures. |
| REQ-SET-145 | When an event ends, the system shall remove its temporary modifiers without restoring crop health, consumed stocks, or injuries already incurred. |
| REQ-SET-146 | If food-days fall below 1 during winter, then the system shall raise a critical alert and offer the listed emergency actions without applying them automatically. |
| REQ-SET-147 | If fuel-days fall below 2 while forecast temperature<0°C, then the system shall warn with the estimated last heated hour and affected homes. |
| REQ-SET-148 | While an outdoor station is dark and unlit, the system shall apply the 0.75 work factor and expose it in the job breakdown. |
| REQ-SET-149 | When the first winter begins, the system shall display a dismissible preparation summary with ready food-days, fuel-days, warm beds, and outdoor staffing. |
| REQ-SET-150 | The system shall derive winter failure from hunger, exposure, illness/injury, labor loss, and departure rules rather than an undisclosed winter death percentage. |

Winter failure order is causal, not a scripted massacre: insufficient preserved food→more emergency labor→less hauling/fuel/care→hunger/rest decline→lower productivity→unheated rooms/exposure→injury/death→grief/departure→fewer workers. UI warnings reveal each link before the next. Emergency response options are stop immigration, suspend feasts, assign safe fish/forage/cooking labor, enable raw edible food, consolidate residents into heated halls, reduce nonessential production, and release ordinary production food reserves. Protected seeds remain protected; seed recovery has its own explicit assistance rule.

### 5.11 Immigration, milestones, victory, saves, and performance

Immigration events occur every third midnight from day 4. Candidate count=`min(8,2+floor(reputation/2000)+orchard_feast_bonus)`, reputation 0–10000. Candidates arrive only after player acceptance; capacity is limited by spare valid beds and the 256 resident cap. Default automatic acceptance is off. Acceptance predicts resulting food demand and rejects if ready food-days<4 after acceptance; an explicit event-specific override permits it. Candidate species use the scenario AdmissionProfile under SET-AMEND-001 §5. The refuge normal pool is mouse,mole,otter,squirrel,shrew,hedgehog,hare,badger in that order. At event day D=4+3*e, ordinary slot i uses pool[(world_seed mod N+e+i) mod N]. A declared exception replaces slot C-1 and requires explicit acceptance; it is never auto-admitted. The refuge has the authored rat petition at absolute day 10. Pending rows expire next midnight; acceptance/refusal clears the row atomically. The global 16-species catalog remains available to other validated profiles; giant residents are not candidates. New residents arrive with health 100, needs 6500, tier 1 clothing, one basic tool, skill XP 5000 in two seeded active skills and 0 otherwise; reserved skill index 3 remains zero. Immigration adds no food or currency.

Reputation is recomputed daily: `clamp(floor(mean_mood/2)+min(3000,100*completed_feasts)+1000*charter_awarded−500*deaths_last_12_days,0,10000)`. Empty population mean is 0. Acceptance cannot hide current deaths by resetting history.

**R-BUILD-DOM-001 mask binding:** bit m in World.milestone_mask and
Progress.unlocked_mask records actual award of Milestone m. Active new worlds
start with M0=0 and both masks=1; unknown/unbound progression is unavailable.
Progress.milestone is the highest earned ordinal for display, not an unlock
threshold. A definition requires its exact earned bit; do not infer earlier
awards from a higher ordinal. Awards/rewards commit once when their own conditions
pass, with eligible awards evaluated in ascending ID order. Masks agree and
reserve bits above 4 as zero; see [domain ruling](rulings/2026-09-11_building_room_domains.md).

| Milestone | Condition | Unlock/reward |
|---|---|---|
| M0 Refuge |Start |All basic survival buildings, farming, nets, safe foraging, drying, composting |
| M1 Settled Hearth |Day≥4 AND at least 12 residents AND prepared 200 portions cumulatively |Mill, workshop, cellar, preserver, saltpan, infirmary, lookout, traps; bean_hotpot, nut_loaf, tier 2 outfits; Hearth feast |
| M2 Abundance |Population≥48 AND survive first winter AND master 3 recipes |Weirs, apiary, brewery, stone walls, paved paths; pie, roast, tart, feast_fish, rations, mead, iron_tool |
| M3 Deep Roots |Population≥80 AND year≥2 AND food-days≥8 |Boats, boathouse, nursery, orchards;2 apple+2 pear saplings once; fruit recipes; Orchard feast |
| M4 Hearth Charter |Year≥3; population≥120;8 named specialists with skill≥8 across≥6 skills;10 mastered recipes;12 completed feasts; mean mood≥6500; ready food≥18 winter-demand days; fuel≥18 winter days; all residents warm-bedded; zero starvation/exposure deaths in current winter; conditions maintained last 3 winter days |Victory presentation, Charter monument cosmetic, continue settlement |

Feast success count, recipe mastery, and unlocks are monotonic; population/stock/mood conditions are current values. M4 can be earned at winter day 12 only, after evaluating that midnight's needs/deaths. There is no time-limit loss; year 10 is still eligible. An all-resident death/departure ends the settlement after the final lifecycle commit, offering load or new settlement. Warden death alone does not end play; player can appoint another adult, with no stat change.

| ID | EARS requirement |
|---|---|
| REQ-SET-151 | When an immigration event occurs, the system shall create a reviewable candidate list and show housing, food, and labor consequences before acceptance. |
| REQ-SET-152 | If accepting candidates exceeds living capacity or valid spare beds, then the system shall cap the selection and explain the limit; the population cap cannot be overridden. |
| REQ-SET-153 | When an accepted resident arrives, the system shall allocate a new persistent ID and valid bed and initialize the declared skills, needs, and equipment. |
| REQ-SET-154 | When a milestone's complete conditions are met, the system shall unlock its catalog entries once and record the triggering tick. |
| REQ-SET-155 | When M4 completes, the system shall award the Hearth Charter, pause for the completion screen, and allow continuation of the same save. |
| REQ-SET-156 | If living resident count reaches 0, then the system shall pause on settlement collapse and offer load save or return to menu without overwriting the previous autosave. |
| REQ-SET-157 | When Warden Rowan or a later Warden dies/leaves, the system shall allow appointment of any living resident and preserve the settlement. |
| REQ-SET-158 | The system shall support manual saves, five rotating daily autosaves, a separate prewinter save, and a separate pre-major-demolition quicksave. |
| REQ-SET-159 | When saving, the system shall serialize authoritative state, RNG streams, inventories/reservations, relationship edges, event schedule, job progress, unlocks, and pending commands at a tick boundary. |
| REQ-SET-160 | When loading, the system shall validate ruleset/map/catalog versions and rebuild navigation/render state before resuming, preserving simulation hashes after the next tick. |
| REQ-SET-161 | If a save is incompatible or corrupted, then the system shall retain the file, report the reason, and offer other saves without attempting a partial world load. |
| REQ-SET-162 | The system shall store per resident data in packed columns, batch job/path queries, and keep per-frame UI updates independent from hourly/day-level simulation. |
| REQ-SET-163 | While 256 residents are active at 1× or 4×, the system shall satisfy the qualification budgets below on the Windows reference floor before claiming support for that configuration. |
| REQ-SET-164 | When a performance budget fails, the system shall expose the failing subsystem and reduce speed as defined, without reducing offscreen need/ecology accuracy. |

Qualification floor matches the crowd document's proposed Ryzen 5 3600/GTX 1660 Super 6 GB/16 GB RAM at 1920×1080, with an AMD RX 6600 comparison. Release-build target: frame p95≤16.67 ms, p99≤20 ms; simulation tick p99≤2 ms at 1×; aggregate simulation CPU p95≤6 ms/render frame at 4×; UI work p95≤1.5 ms; simulation-owned memory≤100 MB; full process≤4 GB. These are acceptance budgets, not measurements. 256 residents use at most 24 conventional close-up skeletal actors; remaining residents use the chosen crowd presentation path. No physics body/navigation agent/AnimationTree is instantiated for every resident by default.

Settlement navigation uses 0.5 m static cells and deterministic squad-free A* routes per job destination; jobs share cached routes by(start macro cell, goal, clearance, map_revision), with local entry/exit segments. Stable neighbor order N, E, S, W, NE, SE, SW, NW, diagonal corner blocking,10/14 costs, tie cell index. Main-thread path work cap 2048 expansions/tick; idle/repath queries queue in job-ID order. Temporary resident separation uses the bounded integer grid from the crowd document. Placement validation updates connectivity before committing a new blocker. A release gate requires p95 job route ready≤0.25 real seconds at 1× and no unreachable workers trapped by valid construction.

## 6. Progressive Disclosure

Disclosure uses saved objective/milestone state, not elapsed wall time. The following player-time headings describe intended learning pace; pausing and speed controls do not secretly unlock systems.

| Stage | Visible systems | Required tutorial actions / success | Advanced detail |
|---|---|---|---|
| Minute 1 |Camera, resources, time, one alert, selected resident/building, build/harvest buttons |Pan to hall; select Rowan; pause/resume; designate safe roots zone |Detailed job matrix and ecology graphs initially collapsed |
| First 10 minutes |Food-days, kitchen order, hauling, beds, priority causes |Set porridge target 24; craft 2 nets; place dryer; produce 12 dried_fish U; mark 8×8 farm |Prerequisite banners link to exact missing item/worker |
| Hour 1 |M1 buildings, job/schedule tables, storage filters, season forecast, first feast planning |Reach 200 prepared portions; use pantry/cellar; create warmth/fuel reserve |Species stock, soil rotation, quality breakdown reveal on first inspection |
| Hour 10 |M2/M3 systems, orchards/hives, mead, rations, relationships, production forecasts |Master 3 recipes; hold 3 feasts; support 80+ residents; survive winter |All graphs, cohort staffing, lot-age tables, policy controls available |
| Hour 50+ |Charter/endless optimization,200–256 residents, all economic catalogs |Sustain 18-day reserves; high crop rotation diversity; stable stocks and specialist succession |No hidden infinite unlock track; optimize existing systems |

| ID | EARS requirement |
|---|---|
| REQ-SET-165 | When a new tutorial step becomes active, the system shall highlight one actionable element and explain its economic purpose without blocking unrelated play. |
| REQ-SET-166 | When the player opens an advanced panel early, the system shall allow inspection and show unlock requirements rather than concealing the underlying rule. |
| REQ-SET-167 | If a tutorial target is destroyed or unavailable, then the system shall substitute another valid target of the same action or mark the step recoverable, never lock progression permanently. |
| REQ-SET-168 | When the player skips the tutorial, the system shall reveal all basic management panels and retain normal gameplay unlock conditions. |

## 7. Edge Cases & Failure States

| Case | Required resolution/data consequence |
|---|---|
| Starvation while asleep |Hunger≤1500 interrupts sleep for reachable food; no wait until morning |
| Single remaining resident |Self-feeding/sleep remain available; basic recipes do not require two workers; no party hunting is available in rules v2 |
| All priorities 0 |No hidden labor override; critical alert links to “Enable safe survival jobs” command for selected residents |
| Tool chain exhausted |Workbench can craft basic tool from wood+stone by bare-hand work at 50% speed; fallen branches provide wood 1/20 WU without tool |
| No reachable stone |Guaranteed bedrock source allows bare-hand gathering stone 1/90 WU; quarry accelerates it |
| No seeds/edible crop inputs |Once per game year, request a relief seed pouch containing 8 U each grain/root/bean/cabbage/flax seed; arrival next dawn; records assistance in chronicle but does not disable victory |
| No fuel in winter |Safe branch collection remains possible; unheated crafting possible at cold-work penalty; residents can consolidate beds/floor sleep |
| Missing body after death |Death record is authoritative; burial job can place a memorial without resurrecting or duplicating inventory |
| Unreachable corpse/cargo |Markers persist; rescue/haul block with route reason; no global resource counter counts inaccessible items as ready supply |
| Worker dies during craft |Job retains WIP and bound RNG; another worker resumes without new inputs or quality reroll |
| Reserved food spoils |Reservations invalidate in stable order; feast preparation may fall back to preparing but never consume nonexistent food |
| Max population |Immigration acceptance disabled; existing residents fully simulated; no automatic expulsions |
| Full relationships |Need/social benefit still applies; new edge obeys degree cap; friends are not silently erased |
| Wall/gate closes on resident |Placement/closure rejected if footprint occupied or last access severed; no crushing death |
| Building loses valid interior |Bed/service assignments suspend; objects and goods remain; explicit repair/highlight path |
| Lake habitat exhausted |Minimum stock/recruitment creates recovery; alternative food remains unlocked; no unannounced instant respawn |
| Repeated recipe batching rounding |Quantities/work use integer milli-units; seed/food conversions cannot produce output without positive input |
| Zero heating demand |Fuel UI uses descriptive state; forecast denominator never divides by zero |
| Season roll over during work |Eligibility checked at start; legal started harvest/fishing finishes unless safety closure requires return; next job uses new season |
| Pause/menu overlap |One authoritative pause reason set; closing a menu restores previous speed only if no player/critical pause remains |
| Hardware overload |Lower requested speed then pause; do not skip daily ecology, starvation, or consumption |

| ID | EARS requirement |
|---|---|
| REQ-SET-169 | If any edge case in the table occurs, then the system shall apply its declared resolution and expose the cause in the relevant panel/notice. |
| REQ-SET-170 | When relief seeds are requested, the system shall enforce one pouch/world-year, show its next-dawn arrival, and record a non punitive assistance event. |
| REQ-SET-171 | When a resident becomes incapacitated, the system shall prioritize rescue to a reachable bed and then treatment, allowing another resident to carry one casualty at 50% movement speed. |
| REQ-SET-172 | While a severity 1 injury is untreated, the system shall prevent hazardous work and remove 1 health/hour; severity 2 shall remove 4/hour until treatment. |
| REQ-SET-173 | When treatment consumes herb 1+cloth 0.5 and completes 60 WU, the system shall clear the aggregate injury and restore 10 health, capped 100; treatment can occur at a field landing point or a bed. |
| REQ-SET-174 | If the last resident is injured but conscious, then the system shall allow self-treatment at 120 WU when supplies are reachable; unconscious self-rescue is impossible. |
| REQ-SET-175 | When a critical condition resolves, the system shall clear its active alert and retain its acknowledged/resolved history record. |

### 7.1 Worked economy fixtures and acceptance examples

**Population demand:**200 small residents require 1,200,000 NP/day, or 600 PLAIN 2000-NP equivalent meals. Winter requires 1,440,000 NP/day, or 720 such meals. A mixed cohort of 120 small+60 medium+20 large requires `(120+60*1.2+20*1.6)*6000=1,344,000 NP/day`; winter 1,612,800 NP/day. Forecasts use this exact weighted demand rather than population×a hard coded meal count.

**Field fixture:**64 grain tiles at fertility 7000, full health, no family penalty, no pollination yield`64*10*0.85=544 U` after 192 ideal growth hours(8 days). Seed requirement 16 U. Sowing 256 WU, tending 512 WU, harvest 384 WU, total 1152 WU, excluding hauling. At COOK 0,544 grain makes 272 porridge batches→544 portions×1800 NP=979200 NP, with 544 water U and 3264 cooking WU plus 27.2 wood U. Spread over 8 days, this supports 20.4 small baseline residents before seed-reserve/quality/spoilage/travel losses. Seed replacement 16U requires 4 grain U via separation, so edible grain 540 U→972000 NP, or 20.25 residents before remaining losses. This is an isolated crop fixture, not a guarantee that fields grow through wrong weather or windows.

**Winter stock fixture:**200 small residents need 17,280,000 NP for 12 winter days. At PLAIN ration 2400 NP/U, that is 7200 ration U;15% reserve margin gives 8280U. Ration recipe 3U/batch means 2760 batches, requiring flour 5520U, dried_fish 2760U, nuts 2760U, water 2760U and 66240 WU before ingredient-efficiency savings(which do not apply to PRESERVE recipes). At 500g/U, store mass 4,140,000g, requiring 5 cellars of 1,000,000g each or equivalent free capacity. Feasts and immigration reduce available reserves rather than being free bonuses.

**Starter food fixture:**60 ration U×2400+60 dried_fish U×1800+80 roots U×800+40 berries U×700+40 nuts U×1600=408000 ready NP before quality adjustments;10 small and 2 medium residents consume 74400 NP/day, thus 5.48 ready food-days at start. Grain 80U is potential food until cooked and is not included. The 80 root U is present in both raw-food readiness and potential recipes, so a combined forecast must not add it twice.

**Recipe quality fixture:**COOK level 4, tier 1 kitchen, PLAIN inputs quality 5000, maximum input age fraction 2500/10000, R=0 gives 40+16+10+5−5=66→GOOD. Three fish-stew portions total 3×2200×1.05=6930 NP. Quality roll is bound once even if the worker changes.

**Mood fixture:**hunger 6000, rest 7000, comfort 5000, social 4000, purpose 8000 gives(18000+14000+10000+4000+16000)/10=6200. Good meal memory+300 gives 6500 and work mood factor 1000. Losing a friend adds−1800, result 4700, still factor 1000; another comfort/hunger decline can cross the 4000 threshold.

These fixtures are arithmetic acceptance tests. A balance simulation must additionally test seasonally bounded harvests, tool/fuel logistics, travel, down time, and work force allocation over at least three full years. Stockpiles alone do not prove sustained economic viability.

## 8. Forward Compatibility Notes

The settlement is executable without a battle or campaign module. Future integration consumes stable identity and inventory contracts; it does not require replacing needs, job skills, farms, or stores with battle components.

| Hook | Typed contract / ownership |
|---|---|
| Export residents | `prepare_transfer(ids:PackedInt32Array,destination_id:int)->TransferManifest`; marks requested residents pending, not removed |
| Export supplies | Lot IDs+quantity_milli+recipe/quality/age/effect metadata; reserved from settlement availability |
| Commit transfer | `commit_transfer(manifest_id:int)->bool`; atomic resident status/inventory movement after destination accepts |
| Cancel transfer | `cancel_transfer(manifest_id:int)->void`; releases reservations without duplicating state |
| Return residents | Persistent ID, species, health, equipment durability, skills, injury, morale/mood-compatible memories; settlement assigns new runtime slots |
| Return supplies | Existing lot identity/provenance/elapsed age; no reset freshness |
| Time ownership | One authoritative world clock; settlement pause/distant advancement policy decided when future layer is implemented, not by rendering |
| Read-only summary | Population, food/fuel days, work force, production capacity, relationships/named roster, catalog version |

| ID | EARS requirement |
|---|---|
| REQ-SET-176 | Where a future transfer consumer is absent, the system shall hide transfer execution UI and retain all settlement simulation behavior. |
| REQ-SET-177 | When a transfer is prepared, the system shall reserve residents/items atomically and expose a reviewable manifest without removing them before commit. |
| REQ-SET-178 | If a transfer is cancelled or rejected, then the system shall restore availability exactly once and leave all persistent IDs and lot ages unchanged. |
| REQ-SET-179 | When a resident returns, the system shall map persistent identity into a free local slot and restore carried state without resetting learned skills or relationships. |
| REQ-SET-180 | The system shall separate shared species/item/identity schemas from settlement-only need/job/room schemas and future battle-only components. |
| REQ-SET-181 | The system shall keep economic outcomes independent of visual actor count, camera visibility, animation LOD, and future rendering implementation. |

### 8.1 Completion checklist and verification status

| Gate | Evidence required before release |
|---|---|
| Data contract | All catalog references resolve; every recipe/building input has an acquisition path; required fields cannot be missing |
| Economy | Deterministic three-year 80/120/200/256 resident runs; no quantity duplication, negative inventory, or unexplained survival deadlocks |
| Ecology | Over harvest recovery, closures, migration conservation, rotation, pollination, and orchard maturity tests |
| Autonomy | Every resident can reach food, bed, and permitted work; forbidden jobs never assigned; reservation time out and death cleanup verified |
| Time | 1×/2×/4× and pause produce identical state at the same tick; year rollovers and first offset midnight tested |
| Save | Save/load hash parity across Mac/Windows at busy construction, feast preparation, and winter starvation states |
| UX | Companion UI catalog fully implemented and tested at 1280×720,1920×1080,3840×2160; keyboard/screen-reader flows verified |
| Performance | Representative woodland/indoor release build passes 256 resident budgets on the Windows floor |

Document checks passed for requirement ID continuity, Markdown table/fence structure, starter food arithmetic, crop output, winter ration/storage demand, recipe quality, mood, and starter interior walk/furniture access. The authored numeric rules and dependency calculations are specification data. No Godot gameplay implementation or multi-year economic simulation was executed while writing this document. The release gates above remain implementation acceptance work, not claimed results.

## Connected movement scope — SET-MOVE-001

MOVE-REQ-001–020 are normative adopted behavior. Extend §5.1 terrain, §5.3 jobs, §5.6 fishing access, §5.9 rooms/construction and §5.11 routing/saves together. A usable home, storage or workstation must have real same-domain/transition access; X/Z proximity is insufficient. Finished tunnels persist, loads and profiles constrain passage, dive plans require valid air endpoints, and canopy work requires supported return routes. Exact production parameters and hazards remain MOVE-G01, not implementer discretion.

The [new design-reading package](redwall-design/README.md) is creative evidence. It adds no active recipe, caste, faction bonus or scenario initialization.

## 2026-09-11 asset and persistence engineering bindings

Sections5.9/5.11 use [ART-GAP-R01–05](planning/asset_dimensions_and_budgets.md)
for complete exterior-height ceilings, non-creature asset budgets and settlement
close-actor admission (64px nominal, cap24). Existing footprints, capacities and
rules do not change. Species heights beyond the1m mouse remain comparison
candidates pending decision0002's user review; horizontal movement radii never
supply stature. These authoring dimensions do not close MOVE-G01–05.

Section4.2 ChronicleRecord.detail_key retains its semantic string key; packed
and saved representation is a compiled stable i32 ChronicleDetail catalog ID,
not a Godot StringName intern value. [SAVE-R09-005](rulings/2026-09-11_save_codec_contract.md)
preserves the24-byte record, assigns its task08.5 producer and requires the
actual event/detail domain before release. SET-AMEND-001's rules-v2 compatibility
is independent of the save container's format1/schema-version vector.
