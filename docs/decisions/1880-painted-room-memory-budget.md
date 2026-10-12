# 1880 — Painted-room memory budget: slice B's widths, capacities and bytes

Date: 2026-10-12 · Status: Accepted (budget recorded and checked; held outside the live total until the fold-in is
authorized; two questions open for Brendan)

Number range: 1880–1884 was allocated to this lane by the coordinator; 1880 is the only record it uses. It replaces
no BACKLOG range.

## Decision

ARCH-BUILD-001 obligation 1 is closed **as a budget**, with no runtime code: widths and capacities are chosen for the
1 m cell grid over five levels, the painted Room rows, the item rows and the edge items, and their exact bytes
(**14336000**) are written into a budget table in `docs/systems_architecture.md` ARCH-BUILD-001, checked by
`ready07_arithmetic.py` and `merge_gate.py`. ARCH-MEM-002's room, furniture, project and container bounds are
recomputed for five levels. Obligations 2 and 4 move to slice G and obligation 3 to slice C, by Brendan's ruling.

Two things are **not** done, and why:

- **The bytes are held outside the live total.** Folding them into §2.3 changes the live figure that
  `ready07_arithmetic.py` asserts equal to `docs/planning/underground_memory_pack.json`, and that needs the pack
  regenerated and five test pins changed (see “Held, not folded”). The brief says to stop and report rather than do
  that. With them folded in, the gate still holds: live 114586607, headroom 35413393.
- **Project and container bytes are not budgeted.** Under SET-BUILD-001 §10 as written they do not fit the gate
  (see “Projects and containers”). Their binding is slice C's and slice G's, and needs Brendan's answer to Q1 first.

## Brendan's rulings (2026-10-12)

Relayed by the coordinator: on 2026-10-12, in chat, using the AskUserQuestion tool, Brendan chose the recommended
option.

Question: “ARCH-BUILD-001 lists five slice-B obligations, but three are really later slices' work. How much should
slice B take on?” Answer: **“Budget now, rest later”** — “Slice B picks the column widths and capacities for the 1 m
cell grid, room rows, item rows and edge items, and writes the exact bytes into the memory ledger (checked by
ready07_arithmetic.py and merge_gate.py). Adding the nine new room types and items moves to slice G, binding painted
rooms to room projects to slice C, and store ownership to slice G. ARCH-BUILD-001 is amended to say so. No
save-format change and no pinned-file edits in B.”

## Rules used

| Rule | Source |
|---|---|
| Five levels, 256 × 256 one-metre cells each, index `level × 65536 + z × 256 + x` | SET-BUILD-001 §3, BUILD-REQ-018, ARCH-BUILD-001 |
| Every room cell lies in a 2 × 2 block of that room | BUILD-REQ-002 |
| Rooms on one level never overlap; each 4-connected same-type set is one room | BUILD-REQ-003, SET-BUILD-001 §3 |
| Items never overlap; access tiles must be free of other items | BUILD-REQ-010, SET-BUILD-001 §6 |
| Every GDD furniture footprint is at least one 2 m tile (2 × 2 cells); new key items and connector families start from a 4 × 4-cell placeholder | GDD §5.9, SET-BUILD-001 §3 and §5.3, OPEN-02 (a) |
| Partitions and doors sit on cell edges; a half partition covers one edge; one piece per edge | SET-BUILD-001 §6, §7.4; ARCH-MEM-002 edge exclusivity |
| Heat and the exterior door belong to the roofed room group, not a building | SET-BUILD-001 §4, BUILD-REQ-009 |
| Unfinished space is not a route; “No way in” before Confirm | SET-BUILD-001 §8, BUILD-REQ-013 |
| One project per item and per room delta | SET-BUILD-001 §10; GDD §4.2 Construction |
| Packed columns only, integer state, generation-checked references | ARCH-MEM-001, ARCH-BUILD-001, AGENTS.md |
| Gate 150000000 bytes | REQ-SET-163 as amended by DEC-053 |

## Capacities, each derived from geometry

| Store | Capacity | Derivation |
|---|---:|---|
| Cells | 327680 | 5 × 256 × 256 |
| Painted rooms | 81920 | a room holds ≥ 4 cells (BUILD-REQ-002) and rooms do not overlap: 65536 / 4 = 16384 per level, × 5. A checkerboard of 2 × 2 rooms of two alternating types reaches it |
| Items | 81920 | footprint ≥ 2 × 2 cells, no overlap: 5 × 65536 / 4. Equals today's Furniture capacity 16384 + 4 × 16384 |
| Edge pieces | 652800 | 2 × 256 × 255 = 130560 edges between two map cells per level, × 5 |
| Edge slots | 655360 | each cell's west and north edge, 2 × 65536 per level, × 5; the 512 map-border slots per level are never used and kept so an edge is found by arithmetic |

**`[NEW constraint]`** The item bound holds only while every item covers at least 2 × 2 cells. Slices D and G author
OPEN-02's real footprints; a definition smaller than that needs a ledger revision first.

## Widths, column by column

`PackedByteArray` (B8) wherever the value fits 0–255; `PackedInt32Array` (I32) otherwise. Godot has no 16-bit packed
array, so “fits in 16 bits” still means I32.

| Table | Columns | Width | Why |
|---|---|---|---|
| PaintedCellGrid | `room_slot` | I32 | Room rows go to 81920, past 255. Authoritative membership: a room *is* its painted cells, so this column is saved |
| PaintedCellGrid | `occupant_slot` | I32 | Directory slot of the item or outdoor item on the cell. One column serves both because an outdoor item is a Building row and an item a Furniture row; the directory's `kind` says which. Derived from item and outdoor-item rows, unsaved. Needed by BUILD-REQ-010 (no overlap, access tiles free) and BUILD-REQ-009 (surface rooms overlap no item) in one read, as decision 0080's per-tile `furniture_slot` |
| PaintedCellGrid | `finished` | B8 | Dug (underground) or built (surface). Derived from excavation sites and the room-shell project, unsaved. Makes “unfinished space is not a route” and “No way in” one read instead of a scan of a room's sites |
| PaintedRoom | `type`, `level`, `min_x`, `min_z`, `max_x`, `max_z`, `valid` | B8 | RoomType 0–16, level 0–4, inclusive bounding box 0–255, a flag |
| PaintedRoom | `cell_count` | I32 | 4–65536 cells; 65536 needs 17 bits |
| PaintedRoom | `temperature_tenths` | I32 | Signed; GDD int32 |
| PaintedRoom | `furniture_mask` | I32 | 18 bits once items 9–17 land (SET-BUILD-001 §5.3) |
| PaintedRoom | `occupants` | I32 | 0–256 is 257 values, one more than a byte holds |
| PaintedRoom | `building_slot`, `building_generation` | I32 | GDD's `Room.building`, kept as an optional reference, null for painted rooms (ARCH-BUILD-001) |
| PaintedRoom | `room_group` | I32 | Lowest Room row of the roofed room group, which replaces “within that building” for heat and the exterior door. Derived on layout change, so RoomHeat stays event-driven |
| PaintedRoomIndex | `present` | B8 | Live rows, as decision 0080's RoomIndex |
| PaintedRoomIndex | `ref_slot`, `ref_generation`, `item_head`, `item_count` | I32 | The room's directory reference and the head of its item list; FurnitureIndex already links items into a room's list. No building list links: painted rooms have no building |
| PaintedRoomDirectory | EntityIdentity's 3 and DirectoryIndex's 6 I32, their 3 B8 | as today | 39 bytes per directory slot, the same per-slot cost as §2.2/§3's EntityIdentity and DirectoryIndex rows, at 81920 more slots. Rooms are generation-checked entities (ARCH-BUILD-001); painted rooms take no Transform row |
| EdgeItems | `piece` | B8 | 0 none, 1 half partition, 2/3 first/second edge of a partition, 4/5 first/second edge of a door. Owning room and orientation follow from the two cells and the slot's axis, so they are not stored |
| EdgeItems | `built` | B8 | Installed, or still a blueprint holding its edge (decision 1071's `installed` idea per edge) |
| EdgeItems | `condition` | I32 | GDD §4.2 Furniture `condition` is int32; partitions and doors keep it now that they leave the Furniture rows |
| Item rows | — | — | **No new allocation.** The item row is the existing Furniture row (8 × I32 at 81920) with `origin_tile` re-keyed to a global cell index (0–327679, which carries the level, so no `level` column: a second copy could disagree). Decision 0531 chose its anchor column's I32 for the same reason |

**Edge items are per-edge columns, not item rows.** As rows they would number 652800, each with a directory slot and,
under §10, a project and a container; see the next sections.

## Bytes

| Part | Bytes | Arithmetic |
|---|---:|---|
| Cell grid | 2949120 | 327680 × (4 + 4 + 1) |
| Painted Room rows | 2867200 | 81920 × (7 × 1 + 7 × 4) |
| Room index | 1392640 | 81920 × (1 + 4 × 4) |
| Room directory slots | 3194880 | 81920 × (9 × 4 + 3 × 1) |
| Edge items | 3932160 | 655360 × (2 × 1 + 4) |
| **Total** | **14336000** | |

Old → new (if folded in): planned payload 91861999 → 106197999; one live world plus reserve 100250607 → 114586607;
headroom below the 150 MB gate 49749393 → 35413393. All of it is mutable world state, so the rejected two-world
figures would move by the same amount (candidate 85610234 → 99946234, peak 185860841 → 214532841, transactional
headroom −35860841 → −64532841); that design stays rejected under ARCH-MEM-006.

## Added, not replacing

The rows **add** to the ledger. The tile-based stores they supersede are still allocated by `buildings.gd` and stay
counted until the slice that implements the painted stores deletes them in the same change, with its own negative
trail row, as decision 0138 did. Counting both meanwhile is the conservative choice: the ledger never shows less than
the code may allocate while the two coexist. Retirable then, at least: §2.2 Room 540672, RoomIndex 409600,
RoomTileLinks 65536, SpatialRoomExtension 16384, the tile `room_slot` and `furniture_slot` columns 65536 each, and
16384 `room` directory slots 638976 (1802240 in all).

Nothing is double counted: the item rows add nothing because they *are* the Furniture rows, and the new tables use
their own owner names with no member spelled both `x` and `_x` (`merge_gate.py` L2 passes).

The §2.1 directory: G = 352418 + 81920 = 434338 while the tile `room` kind is allocated, 417954 after it retires; P
(positioned entities) is unchanged.

## Held, not folded

The ledger's convention is that planned rows count in “Planned allocated payload” (§2.2's GDD rows and §3's `[NEW]`
rows were counted before any code allocated them). So the conservative place for these bytes is §3, §2.3 and the
ARCH-MEM-009 trail. That interacts with a pinned figure:

- `ready07_arithmetic.py` asserts `live == underground_pack['live_with_reserve_bytes']`.
- `tools/underground_memory_budget.py` computes that figure as `86601769 + added + declaration − 21185 + 8388608`:
  decision 1071's running payload plus the underground contributions. It never reads the architecture document, so
  no non-underground row after decision 1071 can enter it without editing the tool.
- Folding in therefore needs: the tool's base gains a `+ 14336000` term; `docs/planning/underground_memory_pack.json`
  is regenerated (`live_with_reserve_bytes` 114586607, `headroom_bytes` 35413393); `tools/test_underground_memory_budget.py`
  (seven pins of 100250607 or 49749393) and `tools/test_underground_current_census.py` (one) are re-pinned; and the
  ten rows move into §3 (Auxiliary payload 39758689 → 54094689) with a trail row `+14336000 | 106197999 | 114586607`.

That is regenerating the pack and re-pinning tests, which the brief forbids without authorization. Changing only
ready07's equality to `live == pack + 14336000` was rejected: it would leave the pack's own `headroom_bytes` and its
`total < GATE_BYTES` check 14 MB too generous for the next underground lane. So the bytes sit in ARCH-BUILD-001's own
table, outside §3 and §2.3, and three Metric rows state the held total and the folded figures. `ready07_arithmetic.py`
checks every row's shape against named `DECISION_1880_*` products, their sum, the folded totals and
`folded live < gate`; `merge_gate.py` checks each row's arithmetic and the cross-form names.

## Projects and containers

Recomputed for five levels under SET-BUILD-001 §10 as written (one project per item, per partition or door piece and
per room delta, each with a material container):

- projects ≤ 81920 items + 1024 outdoor items + 652800 edge pieces + 327680 room deltas = **1063424** (a delta needs
  only one new cell: a cell that completes a 2 × 2 block of an existing room);
- containers ≤ 1024 building + 512 satchel + 1063424 projects + 512 expedition + 16384 ground piles = **1081856**.

Today's rows cost 185 bytes per project (the §2.2/§3 rows at 82944 = 114, four material-ledger cells = 32, a
directory slot = 39) and 99 per container (the §2.2/§3 rows at 101376 = 51, the §2.3 demolition scan pair and
de-duplication byte = 9, a directory slot = 39). The 980480 extra projects and containers would add **278456320**
bytes; the edge pieces alone (652800 × 284 = 185395200) exceed the whole gate. So these bytes cannot be budgeted
under §10 as written. They are listed in §3.1 “Still unbudgeted”; slices C and G ledger them once Q1 is ruled.

## Deferred, and to which slice

| Item | Slice | Source |
|---|---|---|
| RoomType 8–16, item definitions 9–17, catalog fingerprint, older-save refusal, 18-bit mask, `FurnitureKindCount` 9 → 18 | G | Brendan's ruling (obligation 2) |
| Binding painted underground room deltas to RoomProjects/ExcavationSites, and their project bytes. ExcavationSites' source maximum (73909 sites, about 18477 cells of 4 quanta) also limits one batch | C | Brendan's ruling (obligation 3) |
| Container owner for painted PANTRY/STORE/CELLAR rooms and `base_store_g` key items, and their container bytes (one per room: at most 81920 more, 8110080 bytes) | G | Brendan's ruling (obligation 4) |
| Registry, capacity audit and canonical-table reruns for each implemented column | C, G | Obligation 5 travels with the columns |
| Retiring the superseded tile-based rows (1802240 bytes) | C, G | “Added, not replacing” |
| The pending batch's draft, Undo/Redo and running ledger (presentation-side, unsaved) | B's panel lane | ARCH-BUILD-001 storage table; not in obligation 1 |

## Gates

Run from the worktree root after the edits. Summary lines:

- `decision_numbers.py`: `decision_numbers: PASS -- 543 records, 0 problem(s)`
- `ready07_arithmetic.py`: `"status": "PASS", "field_rows": 145, "allocation_rows": 60, ... "payload_bytes": 91861999`
  (payload unchanged: the budget is held; its new asserts pass)
- `merge_gate.py`: `merge_gate: PASS -- ledger only, 0 problem(s)`; `test_merge_gate.py`: `merge_gate self-test: PASS`
- `setting_contract.py`: `"status": "PASS_STATIC_SPEC_AND_REFERENCE_ONLY"`, 30 buildings, 9 furniture;
  `arithmetic.py`: `ARITHMETIC_ONLY_NOT_THREE_YEAR_SURVIVAL`
- `state_registry_coverage.py`: `PASS -- 194 modules, 806 rows, 1082 packed columns checked`
- `underground_memory_budget.py --check`: `"live_with_reserve_bytes": 100250607, "headroom_bytes": 49749393`
  (unchanged); `test_underground_memory_budget.py` and `test_underground_current_census.py`: `OK`
- `audit_registry_capacities.py --check`: `census differs from Astra Cycle 3 (388f4f4) only by recorded decisions:
  reconciled`; `test_registry_capacity_audit.py`: `PASS -- 190 check(s), 0 failure(s)`
- `generate_canonical_state_table.py --check`: `PASS generated declaration table matches canonical_state_registry.json`;
  component-column and section 5/6 schema generators: `PASS`
- `validate_save_registry_handoff.py --source-root .`: `PASS registry structure: 75 owners, 810 canonical records`
- `lane_notes.py --check`: `PASS -- 64 lane record(s)`; `dispatch_plan.py --validate`: `PASS -- 137 tasks`;
  `astra_inbox.py --check`: `PASS`; `ready07_addendum_checks.py` and `ui_refinement_contract.py`: `"status": "PASS"`;
  the three cycle handoff validators: `PASS`

No GDScript changed, so the Godot suite and the analyzer were not run.

## Mutation test

One mutant per run (a width, column count, capacity, byte total or printed total in the document, or one
`DECISION_1880_*` product in `ready07_arithmetic.py`), then `ready07_arithmetic.py` and `merge_gate.py`, then restore.
**32 of 32 killed**, 0 survived. `ready07_arithmetic.py` killed all 32; `merge_gate.py` killed the one mutant that made
a row's own arithmetic wrong (the other 31 were internally consistent rows, which only the named products catch).

## Review

REVIEW_PLACEHOLDER

## Open questions for Brendan

**Q1 — How are partitions, doors and repainted cells built?** (slices C and G) Today every partition, door and every
newly painted patch gets its own building job with its own material store. On five levels that is up to a million
jobs, which does not fit the memory limit.
(a) **A room's new cells, partitions and doors are built as one job for that room; painting more cells onto a room
that is still being built adds to its job instead of starting a second one.** Room jobs are then at most one per room
(81920); items such as beds and machines keep their own jobs. Cost: about 23.3 MB (81920 × 284 bytes), plus up to
8.1 MB for painted store rooms' containers; about 4.0 MB of the 150 MB limit would remain after decision 1880.
(b) Keep one job per piece but allow at most 82944 unfinished jobs at once (today's number), refusing more with
“Too many unfinished building jobs”. No extra memory, but a new limit the player can hit.
(c) Keep one job per piece with no limit; not possible within the memory limit.
**Recommendation: (a).** It reuses the room-project revision that decisions 1053/1062 already built and matches how
the player paints rooms. It changes SET-BUILD-001 §10, so it needs your ruling before slice C.

**Q2 — Count decision 1880's 14.3 MB in the live memory total now?** (lead's authorization)
(a) **Yes, now: let a lane extend the underground memory tool's base by 14336000, regenerate its pack file and update
its tests, so the 14.3 MB is reserved before any other lane spends it.** Live total 114586607, headroom 35413393.
(b) Later, when slice C or G first allocates any of it.
**Recommendation: (a).** Until it is folded in, the pack reports 49.7 MB of headroom that is really 35.4 MB.

## Source

Brendan's ruling of 2026-10-12 (above); SET-BUILD-001 §3, §4, §6, §7.4, §8, §10 and BUILD-REQ-002/003/009/010/013/018;
ARCH-BUILD-001; ARCH-MEM-001/002/009; decisions 0080, 0138, 0531, 1053, 1062, 1071, 1072, 1212 and 1851 (E16);
`tools/underground_memory_budget.py`; DEC-053.
