# Priorities saved-domain authority excerpts

## docs/game_gdd.md SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e

124: | Entity/component | Typed fields | Cardinality / relationships |
125: |---|---|---|
126: | World | seed: int32, tick: int64, day: int32, season: enum, year: int32, map_revision: int32, speed: enum, mode: enum, milestone_mask: int32 | Exactly 1; owns stores |
127: | EntityIdentity | persistent_id: int32, generation: int32, kind: enum, active: bool | One per runtime entity; IDs unique across kinds |
128: | Transform | x/y/z/yaw: int32, prev_x/prev_y/prev_z/prev_yaw: int32 | One per positioned entity; yaw 65536/turn |
129: | Resident | species_id: StringName(C)/int32, named: bool, name_key: StringName, arrival_tick: int64, home: EntityRef, bed: EntityRef, role: enum, status: enum, selected: bool(P) | One per creature; at most 1 bed and 1 home |
130: | Needs | hunger/rest/comfort/social/purpose: int32, health: int32, cold_hours: int32, starving_hours: int32, departure_days: int32 | One per resident; needs 0–10000, health 0–100 |
131: | NeedRemainders | hunger/rest/comfort/social/purpose: int64 | Five fixed fractional accumulators per resident |
132: | Skills | xp: int64[12], level: int32[12] | One fixed 12-column set per resident |
133: | Priorities | job_priority: byte[12], auto_fallback: bool, dangerous_work: bool | Priority 0–4; default dangerous=false |

## docs/game_gdd.md SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e

338: 
339: Default schedule:22:00–06:00 SLEEP,06:00–07:00 ANYTHING,07:00–12:00 WORK,12:00–13:00 ANYTHING,13:00–18:00 WORK,18:00–20:00 SOCIAL,20:00–22:00 ANYTHING. Night shift is the same pattern offset 12 hours. Flexible is all ANYTHING. Sleep only continues until rest≥9000; a resident then uses ANYTHING until the scheduled sleep window ends.
340: 
341: | ID | EARS requirement |
342: |---|---|
343: | REQ-SET-025 | The system shall retain twelve XP columns but track/award XP only for the eleven active skill/job kinds, with RESERVED_3 permanently zero, and award XP only for productive work that consumes or advances a valid job. |
344: | REQ-SET-026 | When a player changes a job priority, the system shall accept 0=forbidden,1=highest,2=high,3=normal,4=low and apply the change at the next job-selection boundary. |
345: | REQ-SET-027 | The system shall select jobs in the exact eligibility and ordering sequence defined below. |
346: | REQ-SET-028 | If no permitted job is available and automatic fallback is enabled, then the system shall allow HAUL, KEEP, and low-risk FORAGE at priority 4 only when their configured priority is nonzero. |
347: | REQ-SET-029 | While automatic fallback is disabled, the system shall leave a resident free to meet needs rather than invent a forbidden occupation. |
348: | REQ-SET-030 | When a job is accepted, the system shall atomically reserve its worker, complete input quantities, output capacity, and destination work slot before movement begins. |
349: | REQ-SET-031 | If a reservation cannot be obtained, then the system shall keep the job queued with the exact blocking cause and shall not partially lock unrelated ingredients. |
350: | REQ-SET-032 | While a resident is traveling to work, the system shall renew reservation leases every 30 ticks and release them if no owner renewal occurs for 300 ticks. |

## docs/setting_rules_amendment.md SHA256 ede2b0508f8428b7216c3b831d5ea54d1db3a868d903224b192d56b61cf1db10

33: 
34: | Domain | Retired keys | Replacement / disposition |
35: |---|---|---|
36: | Items | `bow`, `carcass_boar`, `carcass_deer`, `carcass_grouse`, `hide`, `hunting_tool`, `meal_game_roast`, `raw_game`, `smoked_game` | No item migration; add only `meal_nut_roast` in Section 4 |
37: | Main recipes | `bow`, `hunting_tool`, `smoke_game`, `game_roast` | `game_roast` is replaced by `nut_roast`; the other three have no replacement because no surviving release job needs them |
38: | Ancillary recipes | `process_deer`, `process_boar`, `process_grouse` | Removed |
39: | Building and station | `hunter_hut` | Removed; no renamed empty-purpose building |
40: | Huntable fauna | red deer, wild boar, wood grouse | No active food stocks, herd proxies, tracking quotas or harvesting jobs; no claim about their existence elsewhere in fiction |
41: | Skill/job index | `HUNT=3` | Rename to `RESERVED_3=3`, initialize XP/level/priority to 0, prohibit assignment and XP; keep 12-column physical stride |
42: | Zone index | `HUNT=1` | Rename to `RESERVED_1=1`; reject creation; keep other explicit enum values unchanged |
43: | FaunaStock component | Former game-animal stock rows | Retain allocated schema as `FaunaStockReserved`, all numeric fields 0, references `(-1,0)`, no active directory rows, no system updates |
44: | RNG domain | `HUNTING` | Retain existing stream slot/key as a tombstone initialized by the prior seed rule; draw_count remains 0 and no system may draw from it |

## docs/persistence_state_registry.md SHA256 95a770ff4c241f5faaae84f85a520ebb9101eb592bb86263ff20ee1fec5dfa2e

538: ### `godot/scripts/core/priorities.gd`
539: 
540: | Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
541: |---|---|---:|---|---|:-:|---|---|
542: | Player job priorities | `_job_priority` | 1 | `PRIORITY_CAPACITY * JOB_KIND_COUNT` = 6144 | 0 is a real priority (disabled), not an absence marker | 1 | §4 COMPONENT_COLUMNS | Owner-major at `slot * 12 + job kind`, values 0-4. Set only by SET_JOB_PRIORITIES commands, so nothing recomputes it. |
543: | Player work policy | `_auto_fallback`, `_dangerous_work`, `_present` | 1 | `PRIORITY_CAPACITY` = 512 | `_present == 0` is a free row | 1 | §4 COMPONENT_COLUMNS | Per-resident consent flags; `_dangerous_work` gates §5.3's dangerous-job step. |
544: | Priority scalars | -- | -- | -- | -- | 2 | §4 COMPONENT_COLUMNS | `_present_count`, recomputed from `_present`. |
545: 

## Canonical owner entry (registry6)
```json
{
  "section_id": 4,
  "owner_key": "priorities",
  "owner_schema_version": 1,
  "fields": [
    {
      "field_key": "_present",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "priorities",
      "source_member": "_present",
      "shape": {
        "declared_capacity": "`PRIORITY_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 0,
      "source_contract": "C084"
    },
    {
      "field_key": "_job_priority",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "priorities",
      "source_member": "_job_priority",
      "shape": {
        "declared_capacity": "`PRIORITY_CAPACITY * JOB_KIND_COUNT` = 6144",
        "order": "ascending_physical_slot"
      },
      "ordinal": 1,
      "source_contract": "C085"
    },
    {
      "field_key": "_auto_fallback",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "priorities",
      "source_member": "_auto_fallback",
      "shape": {
        "declared_capacity": "`PRIORITY_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 2,
      "source_contract": "C084"
    },
    {
      "field_key": "_dangerous_work",
      "type": "u8",
      "type_code": 0,
      "hash": true,
      "source_module": "priorities",
      "source_member": "_dangerous_work",
      "shape": {
        "declared_capacity": "`PRIORITY_CAPACITY` = 512",
        "order": "ascending_physical_slot"
      },
      "ordinal": 3,
      "source_contract": "C084"
    }
  ]
}
```
