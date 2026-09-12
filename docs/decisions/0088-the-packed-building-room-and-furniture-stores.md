# 0088 — The packed Building, Room and Furniture stores, and the two new catalog domains
Date: 2026-09-11 · Status: Accepted

## Decision

Task 06.1's first increment lands as four changes, implementing
[R-BUILD-DOM-001–004](../rulings/2026-09-11_building_room_domains.md) (adopted as decision 0074):

| What | Where | Kind |
|---|---|---|
| Protected `Milestone` domain, M0=0…M4=4 | `godot/scripts/core/catalog.gd` | catalog identity |
| Compiled `Station` domain, eleven BAL-CAT-011 keys | `godot/scripts/core/catalog.gd` | catalog identity |
| The earned-bit unlock gate and mask arithmetic | `godot/scripts/core/milestones.gd` | new, stateless |
| §4.1/§4.2/§4.3 numeric facts + Station provider binding | `godot/scripts/core/building_definitions.gd` | new, immutable |
| Packed Building / Room / Furniture columns and the presence mask | `godot/scripts/core/buildings.gd` | new, authoritative |

**`catalog_ids.json`'s digest moved, deliberately and for the third time.**
3869 bytes / 26 domains / 259 rows / `ead6a8ac…eecf4` →
**4062 bytes / 28 domains / 275 rows /
`3407b52e4db6fb19874d8ea3a3d636e46575def0048b513558f7a5d3894c3e90`**.
259 + 5 Milestone + 11 Station = 275, and no existing domain's ids moved. Every save written
against the old digest refuses until an explicit migration exists — decision 0043's precedent,
and the artifact working.

## Why these choices, and not the obvious ones

**Milestone is PROTECTED, and Station is COMPILED, and getting that backwards renumbers a
domain.** GDD §4.2's closing paragraph generates values "not individually listed" from sorted
ASCII keys. BAL-CAT-002 (`gameplay_balance.md:43`) lists M0…M4 individually — "Unlock values are
M0=0, M1=1, M2=2, M3=3, M4=4" — so §4.2's rule does not reach them and decision 0018's protection
rule does. "M0".."M4" happen to sort into the same order, which is exactly why protection matters:
the coincidence would hide a later `M10` re-sorting a persisted ordinal. BAL-CAT-011 numbers none
of its eleven service keys, so Station compiles, and `verify_compiled_enum()` proves its table is
the compiler's own output rather than eleven hand-chosen ordinals.

**`Start` is not a sixth key.** §5.9's building table prints `Start` where §5.11 calls the
milestone M0. `Milestones.id_of_source_label()` is the single place that translates it; the
catalog never carries the label, so nothing downstream can be keyed on a display spelling.

**The unlock gate tests the definition's own bit, never the highest earned ordinal.**
`(unlocked_mask & (1 << unlock)) != 0`. The ruling's counterexample is the whole point: M0+M3 is
mask 9 with highest 3, and an M1 definition is still locked. A `>=` comparison would silently
grant M1's mill, workshop, cellar, preserver, saltpan, infirmary and lookout the moment M3
landed, with no §5.11 condition ever having passed and no reward ever having committed. That
mutation was applied and killed four tests (see Evidence).

**Mask 0 refuses rather than answering M0.** An absent or unbound Progress store is *unavailable*.
`highest_earned(0)` refuses; `place_building()` with mask 0 places nothing. Answering M0 would
fabricate the world the ruling says does not exist.

**`milestones.gd` holds no state at all.** Progression owns both masks and the reward latches, and
the ruling says "Do not add a second mutable milestone store". Every function here is static and
pure and takes the mask as an argument, so it *cannot* become that second store.

**One module owns all three packed stores.** R-BUILD-DOM-003 requires membership and mask to move
"atomically on create/remove/reassign". A furniture row's bit lives on its room and a room's tiles
live on its building, so the invariants cross all three; splitting them would put a two-phase
update across a module boundary with no transaction. `inventory.gd` (containers + lots) and
`fishing.gd` (habitats + stocks + claims) are the same pattern.

**The mask is always RECOMPUTED, never incrementally cleared.** `_recompute_mask_row()` ORs
`1 << type_id` over the room's own bounded furniture chain. Incremental clearing is precisely the
bug where removing one of two beds drops the bed bit; recomputation makes "two beds still yield
bit 1" and "the last removal clears it" the same code path with no special case. The chain is
also what avoids the per-room nine-counter arena the ruling warns about.

**`pantry_capacity_g_of_room()` REFUSES a non-pantry room instead of answering 0.** R-BUILD-DOM-004
keeps all five starter shelf rows and gives only the four in the valid PANTRY room their
4 × 50000 = 200000 g. A caller summing rooms must not be able to fold the kitchen-owned fifth
shelf in by accident, and a refusal says why. Both rooms still carry presence bit 256.

**No hall double counting falls out of the domains rather than a special case.** `hall` is not a
Station key, so `station_of_building(hall)` is −1 and its two Keeper slots are never added to the
kitchen service; its one bench contributes exactly one slot. An exterior kitchen contributes its
own two and has no interior providers. The two paths sum without either knowing about the other.

**Room tile runs are bump-allocated and compacted, not free-listed.** `RoomTileLinks` is the
architecture's own 16384-entry arena and `Room.tile_offset`/`tile_count` are its GDD columns.
Removing a room shifts every later run down and corrects every live room's offset in the same
call — O(16384) on a cold path — which keeps the arena unfragmented with no free-run table and
therefore no extra ledger row. The cost is that offsets are only meaningful together with the
arena, so a save must write the two as a pair.

**Edge furniture may be reassigned within one building; floor furniture may not.** A floor piece is
where its tiles are, so its footprint is re-validated against the destination. An edge piece
occupies a tile *edge* (§4.3's "0/0 means edge placement") that can border a room whose tiles it
does not stand on, and R-BUILD-DOM-003 makes its owner an explicit declaration — "Edge furniture
contributes to its explicit `Furniture.room` owner only" — so it may change owner between rooms of
the same building, and no further.

## What is deliberately NOT implemented, and why

- **`Building.condition`'s scale is unstated.** GDD §4.2 types it `int32`; §4.3 numbers no scale;
  §5.9, `gameplay_balance.md` and `ui_ux_controls.md` give a building no maximum, damage rate or
  repair threshold (§5.9's 1000/1500 caps are *tool* durability). The store validates
  non-negativity and the int32 bound and stores what it is given. No ceiling was invented.
- **`Building.interior_id`'s domain is unstated** beyond §5.9's "Indoor kit themes change geometry
  only". Stored with GDD §4.2's −1 for empty and never dereferenced.
- **REQ-SET-122's slope, height-spread, door and terrain conditions are not evaluated** — they read
  terrain masks this store does not own. Its tile half, "in-bounds nonoverlapping", is enforced.
- **BAL-BUILD-001's edge-overlap rule is not enforced.** Nothing states how `origin_tile` +
  `rotation` names an *undirected* tile edge, so the edge index that rule needs cannot be built
  without inventing the representation. It belongs with 06.2's atomic-edit contract.
- **Room validity is set, not derived.** `room_meets_countable_rules()` implements exactly the
  counting half of §5.9's list; connectivity, enclosure, exterior links, corridor width and
  "heated" need room/heat topology that does not exist. `set_room_valid()` is a separate call so
  no room can become valid on counting evidence alone.
- **No Construction store, no materials, no upgrade packages, no container creation.** §4.1's
  `materials_milli` is a typed pair list consumed by REQ-SET-124/125/126's delivery and refund
  contract (06.2); `work_mwu` *is* carried because it is one integer. `inventory.gd` owns
  containers and R-BUILD-DOM-004 forbids a parallel container store, so this store publishes the
  Building row a container can be owned *by* and states the capacity it should have.
- **Save parity for `Room.furniture_mask` is open.** `master` merged `save_codec.gd` and
  `save_header.gd` on 2026-09-11, but those are ARCH-SAVE-001's encoding primitives and the
  header, not a section encoder: nothing writes or reads a component column yet.
  `verify_room_masks()` is the comparison R-BUILD-DOM-003 asks a loader to run, and its
  mismatch branch is deliberately unreachable through this store's own API — the mask is
  written only by the same recomputation the check runs — so only a decoder that writes
  masks straight from a file can produce a disagreement. That decoder is 09.2's.
- **`RecipeDefinition.unlock` and `.station` are not validated against real recipes**, because no
  recipe module exists. The ruling's "all 36 currently tabulated recipes name a real station" is
  therefore still a source-table claim, not a runtime one.

## Consequences for the memory ledger

`systems_architecture.md` §2.2 already ledgers the Building (9 I32 × 1024), Room (8 I32 + 1 B8 ×
16384) and Furniture (8 I32 × 81920) payloads, and §3 already ledgers `WorldTileMaps.building_slot`
/ `.room_slot` and `RoomTileLinks.tile_id`. Those rows are reproduced exactly and are **not**
re-added. The allocator, index and tile columns this implementation needs are new and are
**reported for hand reconciliation, not edited in** — `systems_architecture.md` and
`docs/validation/ready07_arithmetic.py` are untouched, and the latter still passes at 141 field
rows / 24 allocation rows.

New §3 rows required, totalling **1 885 220 bytes**:

| Table | Columns | Type | Width | Cols | Length | Bytes |
|---|---|---|---:|---:|---:|---:|
| BuildingIndex | `present` | B8 | 1 | 1 | 1024 | 1024 |
| BuildingIndex | `ref_slot, ref_generation, room_head, room_count` | I32 | 4 | 4 | 1024 | 16384 |
| RoomIndex | `present` | B8 | 1 | 1 | 16384 | 16384 |
| RoomIndex | `ref_slot, ref_generation, building_next, building_prev, furniture_head, furniture_count` | I32 | 4 | 6 | 16384 | 393216 |
| FurnitureIndex | `present` | B8 | 1 | 1 | 81920 | 81920 |
| FurnitureIndex | `ref_slot, ref_generation, room_next, room_prev` | I32 | 4 | 4 | 81920 | 1310720 |
| WorldTileMaps | `furniture_slot` (a FIFTH column on the existing four-column row) | I32 | 4 | 1 | 16384 | 65536 |
| FurnitureKindCount | `kind_count` | I32 | 4 | 1 | 9 | 36 |

The §4.1–4.3 fact columns in `building_definitions.gd` are immutable catalog data, 1752 bytes in
total (30 × 8 I32 + 30 × 2 I64 + 30 × 2 B8 + 9 × 5 I32 + 9 × 1 I64), and fall inside §2.3's
existing 2097152-byte read-only catalog/lookup budget on decision 0056's precedent, so they move
no ledger row.

## Evidence

`./tools/run_tests.sh`: **2831 tests, 100399 assertions, 0 failures** (baseline before this change:
2731 / 98832 / 0). `docs/validation/state_registry_coverage.py`: PASS, 39 modules, 302 rows, 614
packed columns. `docs/validation/ready07_arithmetic.py`: PASS, 141 field rows, 24 allocation rows.

Nine single-line mutations, one per invocation, each restored and `shasum -a 256`-compared against
a pristine copy; eight killed, one equivalent:

| Mutation | Result |
|---|---|
| `is_earned` → `highest >= milestone_id` | **killed, 4 failures** |
| mask not recomputed on furniture removal | killed, 2 |
| pantry room-type gate removed | killed, 1 |
| `_b_station` bound to the BuildingDefinition id | killed, 6 |
| unlock gate removed from `place_building()` | killed, 3 |
| invalid room still provides station slots | killed, 1 |
| `furniture_bit_of` returns `type_id`, unshifted | killed, 15 |
| tile-arena compaction `-= count` → `-= 1` | killed, 1 |
| compaction guard `> offset` → `>= offset` | **survived — equivalent** |

The survivor is an equivalent mutant, not a gap: every run has `count >= 1` (an empty tile list is
refused) and runs are disjoint, so no *live* room can share the removed run's offset and the two
comparisons cannot differ. The adjacent M9 mutation proves the compaction itself is pinned.

## Source

`docs/rulings/2026-09-11_building_room_domains.md` (+ its JSON fixtures); decision 0074;
decision 0056 (whose open items 1–4 this implements); GDD §4.2, §4.3, §5.9, §5.11;
`gameplay_balance.md` BAL-CAT-001/002/006/007/011, §4.1–4.3, BAL-BUILD-001;
`systems_architecture.md` §2.2/§3 and its 2026-09-11 building/room clarification;
`ui_ux_controls.md:173` (gate `Mm` binds to the actual earned bit); decisions 0018, 0033, 0043,
0059, 0062, 0063.
