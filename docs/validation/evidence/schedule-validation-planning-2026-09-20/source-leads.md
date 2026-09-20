# Schedule saved-domain source leads

Research only, not an accepted contract.

## docs/game_gdd.md SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e
126: | World | seed: int32, tick: int64, day: int32, season: enum, year: int32, map_revision: int32, speed: enum, mode: enum, milestone_mask: int32 | Exactly 1; owns stores |
127: | EntityIdentity | persistent_id: int32, generation: int32, kind: enum, active: bool | One per runtime entity; IDs unique across kinds |
128: | Transform | x/y/z/yaw: int32, prev_x/prev_y/prev_z/prev_yaw: int32 | One per positioned entity; yaw 65536/turn |
129: | Resident | species_id: StringName(C)/int32, named: bool, name_key: StringName, arrival_tick: int64, home: EntityRef, bed: EntityRef, role: enum, status: enum, selected: bool(P) | One per creature; at most 1 bed and 1 home |
130: | Needs | hunger/rest/comfort/social/purpose: int32, health: int32, cold_hours: int32, starving_hours: int32, departure_days: int32 | One per resident; needs 0–10000, health 0–100 |
131: | NeedRemainders | hunger/rest/comfort/social/purpose: int64 | Five fixed fractional accumulators per resident |
132: | Skills | xp: int64[12], level: int32[12] | One fixed 12-column set per resident |
133: | Priorities | job_priority: byte[12], auto_fallback: bool, dangerous_work: bool | Priority 0–4; default dangerous=false |
134: | Schedule | hourly_activity: byte[24], template: enum, current_activity: enum | Exactly 24 hour slots/resident |
135: | JobAgent | job: EntityRef, phase: enum, target: EntityRef, path_id: int32, path_cursor: int32, lease_expiry: int64, blocked_tick: int64, manual_until: int64 | At most 1 active job/resident |
136: | MoodMemory | memory_kind: enum, value: int32, expiry: int64, source_id: int32 | Up to 8 entries/resident; repeat kind refreshes |
137: | MealHistory | recipe_id: int32[6], last_meal_tick: int64, effect_kind: enum, effect_value: int32, effect_expiry: int64 | Last 6 completed meals; one food effect active |

## docs/game_gdd.md SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e
329: Health/status precedence is DEAD at health=0, INCAPACITATED at health=1..15, INJURED at health=16..99 with an active Injury, otherwise ACTIVE or the current RESTING activity. A treated resident becomes conscious once health>=16. Floor sleep from exhaustion is not incapacitation and can recover without a rescuer. Health drains and recovery integrate per tick with signed remainders; a rescue does not clear an injury until treatment completes. `cold_milli_hours` stores 1000 per exposure-hour, allowing 25% reductions; `cold_hours` is its floor/1000 display value. In hard freeze, base cold gain is 2000 milli-hours/hour for tier 1 and 1000 for tier 2; apply combined food/feast reductions after that. Clearing shelter remains 2000/hour. Need caps discard overflow of either sign at the relevant bound.
330: 
331: Personal eating/restoring uses unmodified 60 WU/game hour; eating consumes one prepared portion at task completion, clamping fullness without refunding excess NP. Raw emergency consumption chooses enough milli-U to restore at most 3000 NP; its 12-WU duration is the same. Arrival at a safe SOCIAL room pairs the lowest-ID unpaired residents for 60 game minutes; unmatched residents use ANYTHING. Mentoring is a SOCIAL alternative selected when an available friend has a skill at least 3 levels higher: 60 minutes together grants the learner 100 XP in that skill and the declared purpose restoration, once per pair/day. It does not generate production XP or override a work/need emergency. Ingredient effect comparison uses `abs(effect_value)*remaining_hours` for the single effect slot; displayed descriptions make replacement explicit.
332: 
333: Memory catalog `(value,duration hours)`: good_meal(+300,6), excellent_meal(+600,8), monotonous_meal(−400,6), feast(+1000,24), friend_died(−1800,72), stranger_died(−300,24), untreated_injury(−800, until treated), rescued(+600,48), cold_home(−600,12), conflict(−600,12), milestone(+500,24). Same kind/source refreshes rather than stacks; at eight entries replace the smallest absolute value, ties earliest expiry then enum value. Death grief only applies to living residents present in the settlement.
334: 
335: ### 5.3 Skills, jobs, schedules, relationships, and names
336: 
337: XP is 10 per completed productive WU in the corresponding job skill. Level=`min(10,floor_sqrt(floor(xp/5000)))`; cumulative XP at levels 0–10 is 0,5000,20000,45000,80000,125000,180000,245000,320000,405000,500000. Initial level 2 therefore means 20000 XP, not a free display value. Skills never decay. A completed batch's quality uses its lead worker's level at batch start.
338: 
339: Default schedule:22:00–06:00 SLEEP,06:00–07:00 ANYTHING,07:00–12:00 WORK,12:00–13:00 ANYTHING,13:00–18:00 WORK,18:00–20:00 SOCIAL,20:00–22:00 ANYTHING. Night shift is the same pattern offset 12 hours. Flexible is all ANYTHING. Sleep only continues until rest≥9000; a resident then uses ANYTHING until the scheduled sleep window ends.

## docs/persistence_state_registry.md SHA256 719beb9a69bfbf2f697901a545ac6fe460f96b76de05d6f8cb3e9e645e8118e1
707: ### `godot/scripts/core/schedule.gd`
708: 
709: | Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
710: |---|---|---:|---|---|:-:|---|---|
711: | Activity templates | `_template_hours` | 1 | `TEMPLATE_COUNT * HOURS_PER_DAY` = 72 | Three templates x 24 hours | 2 | §2 CATALOG_IDS | Compiled from the catalog at construction; rebuilt on load. |
712: | Per-resident hourly schedule | `_hourly_activity` | 1 | `SCHEDULE_CAPACITY * HOURS_PER_DAY` = 12288 | One byte per (resident, hour); the value is a real activity, never absence | 1 | §4 COMPONENT_COLUMNS | Player-authored by SET_ACTIVITY_SCHEDULE commands, so nothing recomputes it. ARCH-SAVE-005 bounds each byte by `ACTIVITY_COUNT`. |
713: | Schedule assignment | `_template`, `_current_activity` | 4 | `SCHEDULE_CAPACITY` = 512 | None on a live row | 1 | §4 COMPONENT_COLUMNS | `_current_activity` is resolved each hour but is read within the hour it is set, so a mid-hour save must carry it. |
714: | Schedule flags | `_present`, `_sleep_satisfied`, `_resolved` | 1 | `SCHEDULE_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | `_sleep_satisfied` is a per-night latch and `_resolved` records that this hour's activity has been applied; both change what the next hour does. |
715: | Schedule catalog and count | -- | -- | -- | -- | 2 | §2 CATALOG_IDS | `_template_ids` and `_catalog_error` are rebuilt from the catalog; `_present_count` is recomputed from `_present`. |
716: | Schedule scratch | -- | -- | -- | -- | 3 | -- | `_hunger_scratch` and `_rest_scratch`, consumed inside one hourly resolve. |

## Canonical schedule entry
```json
{
  "section_id": 4,
  "owner_key": "schedule",
  "owner_schema_version": 1,
  "fields": [
    {
      "field_key": "_present",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_present",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 0,
      "source_contract": "C102"
    },
    {
      "field_key": "_hourly_activity",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_hourly_activity",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY * HOURS_PER_DAY` = 12288",
        "order": "ascending_physical_slot"
      },
      "ordinal": 1,
      "source_contract": "C103"
    },
    {
      "field_key": "_template",
      "type": "i32",
      "type_code": 2,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_template",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 2,
      "source_contract": "C104"
    },
    {
      "field_key": "_current_activity",
      "type": "i32",
      "type_code": 2,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_current_activity",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 3,
      "source_contract": "C104"
    },
    {
      "field_key": "_sleep_satisfied",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_sleep_satisfied",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 4,
      "source_contract": "C102"
    },
    {
      "field_key": "_resolved",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "schedule",
      "source_member": "_resolved",
      "shape": {
        "declared_capacity": "`SCHEDULE_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 5,
      "source_contract": "C102"
    }
  ]
}
```

## godot/scripts/core/catalog_ids.gd SHA256 63dfd84986c0761316301470c8dfb845a41670a91bb0f34f08cfc2ceeba84afb
20: ## RoomType and BuildingState since decision 0056: each addition moved these bytes and this
21: ## digest, which is an intentional catalog change and not a parity result), residents.gd's
22: ## species keys,
23: ## farming.gd's crop keys, schedule.gd's template keys, forage.gd's quota-mode keys, and the
24: ## ItemDefinition/ItemCategory/ItemEffect keys read out of `res://data/item_definitions.json`,
25: ## the same file item_definitions.gd loads. There is no second copy of any domain here, so the
26: ## artifact cannot drift from the code it describes.
27: ##
28: ## WHY THE REGISTRY LIVES HERE AND NOT IN catalog.gd. The build registry must reference
29: ## residents.gd, farming.gd, schedule.gd, forage.gd and item_definitions.gd, and every one of
30: ## those preloads catalog.gd. Putting the registry in catalog.gd would make those preloads
49: ## ARCH-SAVE-001/002 place this artifact in the save file as follows, and this module produces
50: ## every value that placement needs, so the save module can embed them unchanged:
51: ##   * `catalog_hash = SHA256(canonical catalog_ids.json bytes)`, the raw 32 digest bytes, goes
52: ##     at save-header offset 72 (SAVE_HEADER_CATALOG_HASH_OFFSET). digest_of() / Artifact.digest.
53: ##   * Section 2 CATALOG_IDS (SAVE_SECTION_ID) carries a little-endian u32 byte length followed
54: ##     by those same canonical bytes: save_section_payload(). Its section descriptor's
55: ##     schema_version is 1 (SAVE_SECTION_SCHEMA_VERSION) and its row_count is the number of
56: ##     domain entries across all domains: Artifact.row_count.
57: ##   * No duplicate embedded hash is needed; the header digest is the only copy.
58: ##   * On load, verify_embedded() validates the embedded mapping, the digest and the installed
59: ##     catalog BEFORE any world mutation, per §4.2's "a registry validation failure aborts
60: ##     loading before mutating the current world". It is static and pure: it cannot mutate a
61: ##     world even by mistake, and a mismatch refuses with a catalog/version code instead of
62: ##     reassigning live IDs. An explicit migration is a separate, unwritten contract.
63: ## No save writer is stubbed here. When the save module lands it calls the four functions named
64: ## above; until then this wiring is unexercised by any shipping path.
90: 
91: const Catalog := preload("res://scripts/core/catalog.gd")
92: const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
93: const ResidentsScript := preload("res://scripts/core/residents.gd")
94: const FarmingScript := preload("res://scripts/core/farming.gd")
95: const ScheduleScript := preload("res://scripts/core/schedule.gd")
96: const ForageScript := preload("res://scripts/core/forage.gd")
97: 
453: 		FarmingScript.CROP_DEFINITION_DOMAIN:
454: 			out.append_array(FarmingScript.CROP_KEYS)
455: 		ScheduleScript.TEMPLATE_DOMAIN:
456: 			out.append_array(ScheduleScript.TEMPLATE_KEYS)
457: 		ForageScript.QUOTA_MODE_DOMAIN:
