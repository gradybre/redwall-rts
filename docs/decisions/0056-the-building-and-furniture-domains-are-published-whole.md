# 0056 — The building, furniture and room domains are published whole
Date: 2026-09-11 · Status: Accepted

## Decision

READY_07 §7.2 step 1's four missing domains are compiled and committed, in one change:

| Domain | Kind | Rows | Source of the keys |
|---|---|---:|---|
| `BuildingDefinition` | compiled, ascending ASCII | **30** | `gameplay_balance.md` §4.1 |
| `FurnitureDefinition` | compiled, ascending ASCII | **9** | `gameplay_balance.md` §4.3 |
| `RoomType` | protected, §4.3's own numbers | 8 | `game_gdd.md` §4.3 |
| `BuildingState` | protected, §4.3's own numbers | 6 | `game_gdd.md` §4.3 |

`BuildingDefinition` is **the whole catalog, not the starter colony's seven**:

```
apiary 0, boathouse 1, brewery 2, cellar 3, composter 4, covered_store 5, dirt_path 6,
dryer 7, fence 8, fisher_shelter 9, forester_lodge 10, gate 11, hall 12, infirmary 13,
kitchen 14, lookout 15, memorial_garden 16, mill 17, nursery 18, open_stockpile 19,
paved_path 20, preserver 21, quarry_shed 22, residence 23, saltpan 24, stone_wall 25,
weir 26, well 27, workbench 28, workshop 29
```

```
bed 0, decoration 1, hearth 2, interior_door 3, interior_partition 4, kitchen_bench 5,
patient_bed 6, seat 7, shelf 8
```

`catalog_ids.json` was regenerated. **The digest moved, deliberately**: 3064 bytes /
22 domains / 206 rows / `00e3ffd5…cbf1` → **3869 bytes / 26 domains / 259 rows /
`ead6a8ac6c67bb4b0d9b320a2414cc477f252b5f9cdf8bb3e1e0b8cc593eecf4`**. Every save written
against the old digest refuses, which is decision 0043's precedent and the artifact working.

## Why

**Complete, because a partial domain renumbers.** §7.2 step 1 names the failure mode outright:
"publish the complete domain or an explicitly versioned schema, **not seven runtime-only ordinals
that later renumber all buildings**". `Building.type_id` is persisted. Publishing only `hall`,
`open_stockpile`, `well` and `workbench` would give `well` id 2 today and id 27 the day the
catalog is finished, silently repointing every saved building. Thirty keys cost nothing now and
are immovable afterwards.

**Keyed on stable identifiers, never display names.** §5.9 prints "Refuge/community hall",
"Workbench shelter" and "Preserver/smokehouse"; §4.1's owning rows key them `hall`, `workbench`
and `preserver`. Keying on the printed name would place `refuge_hall` between `quarry_shed` and
`residence` and renumber six buildings. The suite asserts the display spellings are *refused*.

**Compiled versus protected is §4.2's own split, not a preference.** §4.2's closing paragraph
numbers everything §4.3 does not list individually (decision 0033), so Building/FurnitureDefinition
compile from sorted ASCII keys. §4.3 *does* list RoomType and BuildingState, and neither is in its
own keys' ASCII order — regeneration would give `COMMON=0` and `ACTIVE=0` — so both are protected
per decision 0018, where a recompile attempt is refused rather than silently accepted.

**Where the keys live.** In `catalog.gd`, alongside CommandKind/CropFamily/EventDefinition/
HabitatType, verified by `verify_compiled_enum()` against the compiler's own output. `catalog_ids.gd`
still holds no copy of any domain: it reads `Catalog.COMPILED_ENUM_DOMAINS` and
`Catalog.PROTECTED_ENUM_DOMAINS` and needed no registry edit at all. Rejected: a new
`building_definitions.gd`/`building_definitions.json` pair — the file-ownership boundary for this
increment is `catalog.gd`/`catalog_ids.gd`, and a second data file would be a second place for the
key list to drift from.

**`fixed_enum()` became a table lookup.** Thirteen `match` arms would have put it over the 30-line
limit. `FIXED_ENUM_TABLES` now indexes the §4.3 tables and the suite asserts both directions
against `PROTECTED_ENUM_DOMAINS`, which is a stronger guard than the `match` it replaces.

## Consequences

- **Identity only.** Footprints, materials, work, slots, `managed_interior`, `room_tiles`,
  `unlock`, `base_store_g`, `passive_slots` and `max_builders` are NOT transcribed here. They stay
  in §4.1/§4.2's rows and belong to §7.2 step 2's packed Building/Furniture/Room stores, which are
  explicitly out of this increment's scope. A catalog id is not a capacity.
- Step 2 reads `Catalog.BUILDING_DEFINITION[...]` / `Catalog.FURNITURE_DEFINITION[...]` /
  `Catalog.ROOM_TYPE[...]` / `Catalog.BUILDING_STATE[...]` as constant expressions. It must not
  mirror any of them locally.
- The memory ledger is unchanged: 53 catalog entries fall inside §2.3's existing 2097152-byte
  "Read-only catalog/lookup budget" row, so no field or allocation row moves and
  `docs/validation/ready07_arithmetic.py` keeps its pinned 140 rows / 25028946 and 23 rows /
  60292646 untouched. It still passes; the 437632 reconciliation is reproduced, not reapplied.
- `ItemDefinition` ids did not move — adding top-level domains cannot renumber a sibling — so the
  seventeen resource/forage/fish bindings of decision 0052 are unaffected and still asserted.

## What §5.9 leaves unstated, and was therefore not invented

1. **`BuildingDefinition.unlock`'s domain.** §5.9 prints `Start`, `M1`, `M2`, `M3`; §4.2 gives
   `Progress.milestone: enum` but §4.3 numbers no Milestone enum and nothing states that
   `unlock` *is* that ordinal. §4.1's rows carry 0/1/2/3, which is a plausible encoding, not a
   stated one. No milestone domain is declared here.
2. **The Station service domain** (BAL-CAT-011: brewery, composter, dryer, kitchen, mill, nursery,
   preserver, saltpan, well, workbench, workshop) is a *separate* domain that the ruling says in
   terms "indexes a service domain, **not** the BuildingDefinition index". Eight of its keys are
   spelled identically to building keys; they are **not** the same ids. It is not compiled here
   because no recipe/station module exists to own it — aliasing it to `BuildingDefinition` would
   be wrong by the ruling's own words.
3. **`Room.furniture_mask`'s bit assignment.** §4.2 declares the int32 field and no document says
   which bit a furniture kind occupies. `1 << FurnitureDefinition id` is the obvious reading and
   is nowhere stated; it is left to whoever owns the Room store, with this note as the blocker.
4. **The fifth `S` in §5.9's kitchen row.** §7.1 offers only a "recommended interpretation" for
   whether it is a pantry shelf. It is a placement question, not a catalog one: `shelf` is one
   FurnitureDefinition key regardless, and the capacity question belongs to step 2.
5. **Five more §4.3-numbered enums remain unprotected and absent from the artifact**: WorldMode,
   ResidentStatus, Role, InjuryKind, FeastState. They are outside this increment (and `needs.gd`
   still carries decision 0018's known `ResidentStatus` mirror exception). Adding them later is
   another intentional digest move; doing it in one change rather than five is the cheaper path.

## Source

`docs/rulings/2026-09-11_ready07_open_item_answers.md` §7.1–7.2 step 1; `docs/game_gdd.md` §4.2
closing paragraph, §4.3 and §5.9; `docs/gameplay_balance.md` §4.1/§4.2/§4.3 and BAL-CAT-006/007;
decisions 0018, 0033, 0034, 0042, 0043.

## Resolution addendum — 2026-09-11

[R-BUILD-DOM-001–004](../rulings/2026-09-11_building_room_domains.md) resolves
open items 1–4 above. BAL-CAT-002 already authored unlock values M0=0 through
M4=4; the missing binding/publication is now protected Milestone. Station's
complete 11-key ASCII domain is now explicit. Room.furniture_mask uses the
existing FurnitureDefinition ID as bit position, for committed presence only.
The kitchen S is retained separately from the four pantry-capacity shelves.
The historical questions above are preserved, not current unanswered blockers.
Catalog artifact regeneration, stores and service integration remain executor
work; this addendum does not report them complete. Item 5's other enum coverage
remains separate.
