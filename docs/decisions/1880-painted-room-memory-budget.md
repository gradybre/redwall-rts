# 1880 — Painted-room memory budget: slice B's widths, capacities and bytes

Date: 2026-10-12 · Status: Accepted (budget recorded and checked; held outside the live total until the fold-in is
authorized; three questions open for Brendan)

Number range: 1880–1884 was allocated to this lane by the coordinator; 1880 is the only record it uses. It replaces
no BACKLOG range.

## Decision

ARCH-BUILD-001 obligation 1 is closed **as a budget**, with no runtime code: widths and capacities are chosen for the
1 m cell grid over five levels, the painted Room rows, the item rows and the edge items, and their exact bytes
(**16957440**) are written into a budget table in `docs/systems_architecture.md` ARCH-BUILD-001, checked by
`ready07_arithmetic.py` and `merge_gate.py`. ARCH-MEM-002's room, furniture, project and container bounds are
recomputed for five levels. Obligations 2 and 4 move to slice G and obligation 3 to slice C, by Brendan's ruling.

Two things are **not** done, and why:

- **The bytes are held outside the live total.** Folding them into §2.3 changes the live figure that
  `ready07_arithmetic.py` asserts equal to `docs/planning/underground_memory_pack.json`, and that needs the pack
  regenerated and eight test pins changed (see “Held, not folded”). The brief says to stop and report rather than do
  that. With them folded in, the gate still holds: live 117208047, headroom 32791953.
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
| Every painted cell lies in a 2 × 2 block of its room (at painting; on removal only by this record's PROPOSED Q3) | BUILD-REQ-002 |
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
| Painted rooms | 81920 | a room holds ≥ 4 cells (BUILD-REQ-002) and rooms do not overlap: 65536 / 4 = 16384 per level, × 5. A checkerboard of 2 × 2 rooms of two alternating types reaches it. **PROPOSED, Q3:** holds only if removal keeps the 2 × 2 rule; otherwise rooms ≤ cells = 327680 |
| Items | 81920 | footprint ≥ 2 × 2 cells, no overlap: 5 × 65536 / 4. Equals today's Furniture capacity 16384 + 4 × 16384 |
| Edge pieces | 652800 | 2 × 256 × 255 = 130560 edges between two map cells per level, × 5 |
| Edge slots | 655360 | each cell's west and north edge, 2 × 65536 per level, × 5; the 512 map-border slots per level are never used and kept so an edge is found by arithmetic |

**Rooms and removal (PROPOSED, Q3).** BUILD-REQ-002 governs painting. Nothing yet stops a removal (BUILD-REQ-006,
UI-BUILD “Remove cells”) from leaving a remaining cell outside any 2 × 2 block: clear three cells of a 2 × 2 room and a
one-cell room remains; clear a checkerboard from a large room and every remaining cell is its own room. The 81920
bound therefore needs the smallest rule that keeps BUILD-REQ-002's stated purpose (“no room has a strip one cell
wide”) after removal: **a removal that would leave a remaining cell outside a 2 × 2 block of its room is refused with
its reason, or those cells are added to the removal review.** Without it the honest bound is rooms ≤ cells = 327680,
which adds 245760 rows × 91 bytes (35 row + 17 index + 39 directory) = **22364160** bytes, total 39321600; still under
the gate (live 139572207), but it leaves no room for Q1 (a). The budget uses 81920 pending Q3, and states the
fallback beside it; `ready07_arithmetic.py` checks both.

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
| PaintedRoom | `building_slot`, `building_generation` | I32 | GDD's `Room.building`, kept for GDD fidelity as an optional reference; always null for painted rooms (ARCH-BUILD-001), 655360 bytes that slice G may drop if no room ever has a building |
| PaintedRoom | `room_group` | I32 | Lowest Room row of the roofed room group, which replaces “within that building” for heat and the exterior door. Derived on layout change, so RoomHeat stays event-driven |
| PaintedRoomIndex | `present` | B8 | Live rows, as decision 0080's RoomIndex |
| PaintedRoomIndex | `ref_slot`, `ref_generation`, `item_head`, `item_count` | I32 | The room's directory reference and the head of its item list; FurnitureIndex already links items into a room's list. No building list links: painted rooms have no building |
| PaintedRoomDirectory | EntityIdentity's 3 and DirectoryIndex's 6 I32, their 3 B8 | as today | 39 bytes per directory slot, the same per-slot cost as §2.2/§3's EntityIdentity and DirectoryIndex rows, at 81920 more slots. Rooms are generation-checked entities (ARCH-BUILD-001); painted rooms take no Transform row |
| EdgeItems | `piece` | B8 | 0 none, 1 half partition, 2/3 first/second edge of a partition, 4/5 first/second edge of a door. Owning room and orientation follow from the two cells and the slot's axis, so they are not stored |
| EdgeItems | `built` | B8 | Installed, or still a blueprint holding its edge (decision 1071's `installed` idea per edge) |
| EdgeItems | `condition` | I32 | GDD §4.2 Furniture `condition` is int32; partitions and doors keep it now that they leave the Furniture rows |
| EdgeItems | `generation` | I32 | Makes a piece a generation-checked `(edge slot, generation)` reference in its own edge space, as inventory containers have their own generation space (decision 0085), so a project, job or removal review can name a piece and a reused edge cannot inherit an old reference |
| Item rows | — | — | **No new allocation.** The item row is the existing Furniture row (8 × I32 at 81920) with `origin_tile` re-keyed to a global cell index (0–327679, which carries the level, so no `level` column: a second copy could disagree). Decision 0531 chose its anchor column's I32 for the same reason |

**Edge items are per-edge columns, not item rows.** As rows they would number 652800, each with a directory slot and,
under §10, a project and a container; see the next sections. **This is a representation deviation, recorded here:**
GDD §5.9 lists `interior_partition` and `interior_door` as furniture, and GDD §4.2 gives Furniture a directory
EntityRef and a `room` reference. Under decision 1880 they keep every GDD Furniture field, in edge form: type is the
`piece` code, origin is the edge slot, rotation is the slot's axis, user is none (GDD gives them no user), `condition`
is stored, and identity is `(edge slot, generation)` in the edge space rather than a directory slot. Rules:

- `built`, `condition` and `generation` live on a piece's **first** edge only (codes 1, 2, 4); a second edge (3, 5)
  carries only its code and its other columns stay 0, so no copy can disagree.
- A piece's `room` is the **lower Room row of its two cells**; an outside door has one painted side, which owns it.
- Map-border edges have no cell beyond them, so a piece there is refused; the east and south border edges have no slot
  and the west and north ones are never used.

## Bytes

| Part | Bytes | Arithmetic |
|---|---:|---|
| Cell grid | 2949120 | 327680 × (4 + 4 + 1) |
| Painted Room rows | 2867200 | 81920 × (7 × 1 + 7 × 4) |
| Room index | 1392640 | 81920 × (1 + 4 × 4) |
| Room directory slots | 3194880 | 81920 × (9 × 4 + 3 × 1) |
| Edge items | 6553600 | 655360 × (2 × 1 + 2 × 4) |
| **Total** | **16957440** | |

Old → new (if folded in): planned payload 91861999 → 108819439; one live world plus reserve 100250607 → 117208047;
headroom below the 150 MB gate 49749393 → 32791953. All of it is mutable world state, so the rejected two-world
figures would move by the same amount (candidate 85610234 → 102567674, peak 185860841 → 219775721, transactional
headroom −35860841 → −69775721); that design stays rejected under ARCH-MEM-006.

## Added, not replacing

The rows **add** to the ledger. The tile-based stores they supersede are still allocated by `buildings.gd` and stay
counted until the slice that implements the painted stores deletes them in the same change, with its own negative
trail row, as decision 0138 did. Counting both meanwhile is the conservative choice: the ledger never shows less than
the code may allocate while the two coexist. Retirable then, at least: §2.2 Room 540672, RoomIndex 409600,
RoomTileLinks 65536, SpatialRoomExtension 16384, the tile `room_slot` and `furniture_slot` columns 65536 each, and
16384 `room` directory slots 638976 (1802240 in all).

Nothing is double counted: the item rows add nothing because they *are* the Furniture rows, and each new table holds
state no existing row holds. (`merge_gate.py` L2 passes, but it only compares rows whose owners share a leading word,
so it is not evidence here; the reasoning above is.)

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
- Folding in therefore needs: the tool's base gains a `+ 16957440` term; `docs/planning/underground_memory_pack.json`
  is regenerated (`live_with_reserve_bytes` 117208047, `headroom_bytes` 32791953); `tools/test_underground_memory_budget.py`
  (seven pins of 100250607 or 49749393) and `tools/test_underground_current_census.py` (one) are re-pinned; the
  PaintedRoomDirectory bytes lengthen §2.2's EntityIdentity and §3's DirectoryIndex rows to G = 434338 (one directory,
  not two), and the other eight rows move into §3; and a trail row `+16957440 | 108819439 | 117208047` is added.

That is regenerating the pack and re-pinning tests, which the brief forbids without authorization. Changing only
ready07's equality to `live == pack + 16957440` was rejected: it would leave the pack's own `headroom_bytes` and its
`total < GATE_BYTES` check 17 MB too generous for the next underground lane. So the bytes sit in ARCH-BUILD-001's own
table, outside §3 and §2.3, and three Metric rows state the held total and the folded figures. `ready07_arithmetic.py`
checks every row's shape against named `DECISION_1880_*` products, their sum, the folded totals and
`folded live < gate`; `merge_gate.py` checks each row's arithmetic and the cross-form names.

## Projects and containers

Recomputed for five levels under SET-BUILD-001 §10 as written (one project per item, per partition or door piece and
per room delta, each with a material container):

- projects ≤ 81920 items + 1024 outdoor items + 652800 edge pieces + 327680 room deltas = **1063424** (a delta needs
  only one new cell: a cell that completes a 2 × 2 block of an existing room);
- containers ≤ 1024 building + 512 satchel + 1063424 projects + 512 expedition + 16384 ground piles = **1081856**.
  The 16384 piles are the surface's one per tile (decision 0532); underground spoil piles (ECON-003) still need the
  owner and bound decision 1075 names, so this container figure is surface-only.

Today's rows cost 185 bytes per project (the §2.2/§3 rows at 82944 = 114, four material-ledger cells = 32, a
directory slot = 39) and 99 per container (the §2.2/§3 rows at 101376 = 51, the §2.3 demolition scan pair and
de-duplication byte = 9, a directory slot = 39); `ready07_arithmetic.py` derives each part from the printed rows. The 980480 extra projects and containers would add **278456320**
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
| Scratch for re-deriving rooms after removal (split and relabel), `room_group` and the breadth-first dig order, over up to 65536 cells per level. `room_footprint.gd`'s 13-byte-per-cell scratch would be 851968 bytes at one level; today it is capped at 16384 cells | C, F | Review M4; listed in §3.1 |
| Underground spoil ground piles' owner and bound | C | Decision 1075; ECON-003 |
| Directory `KIND_COUNT` growth and each new owner's canonical declaration and schema bytes (about 1–2 KB) | C, G | Counted by `ready07_arithmetic.py`'s registry census when the columns are registered |

## Gates

Run from the worktree root after the edits. Summary lines:

- `decision_numbers.py`: `decision_numbers: PASS -- 543 records, 0 problem(s)`
- `ready07_arithmetic.py`: `"status": "PASS", "field_rows": 145, "allocation_rows": 60, "checked_local_links": 149, ... "payload_bytes": 91861999`
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

One mutant per run (a width, column count, capacity, member name, extra row, byte total, printed total or prose
figure in the document, or one `DECISION_1880_*` product in `ready07_arithmetic.py`), then `ready07_arithmetic.py` and
`merge_gate.py`, then restore. First commit: **32 of 32 killed**. After the review fixes, the set grew to 46,
including the reviewer's two survivors (an extra row inside the budget table; `type` swapped with `occupants` between
the B8 and I32 rows) and every prose figure the reviewer found unchecked: **46 of 46 killed**, 0 survived.
`ready07_arithmetic.py` killed all 46; `merge_gate.py` killed the one mutant that made a row's own arithmetic wrong
(the others were internally consistent rows, which only the named products catch).

## Review

An independent `code-reviewer` read the first commit (fe63b582). It recomputed every figure and found the arithmetic
exact, confirmed the “held, not folded” reasoning against `underground_memory_budget.py`, ready07 and the test pins,
and confirmed the obligations match the ruling and the ARCH-MEM-002 anchor still resolves. Findings, all handled in
the second commit:

- **HIGH-1, the room bound relied on a rule removal could break.** BUILD-REQ-002 governs painting only. Fixed by
  making the 81920 bound explicitly PROPOSED on Q3 (a removal keeps the 2 × 2 rule), with the honest fallback (rooms ≤
  cells = 327680, +22364160 bytes) stated beside it and checked.
- **HIGH-2, ready07's table check was weaker than claimed** (an extra row and a column swap survived). Fixed: every
  numeric row between the budget heading and the total is now pinned as a full tuple, member names included.
- **MEDIUM-1, constant-only project/container checks and unchecked prose.** Fixed: the 114, 8, 51, 9 and 39 are now
  derived from the printed rows; the prose figures (bounds, G, retirable bytes, fallback) are asserted; the edge-piece
  figure is checked against the whole gate.
- **MEDIUM-2, the container bound kept a surface-only ground-pile count.** Answered: stated as surface-only, with
  underground spoil piles deferred to decision 1075's owner (Deferred table, §3.1).
- **MEDIUM-3, edge pieces lost entity identity without a recorded deviation.** Fixed: the deviation is recorded; a
  per-edge `generation` gives each piece an `(edge slot, generation)` reference (+2621440 bytes); `built`,
  `condition` and `generation` live on the first edge only; a piece's room is the lower Room row of its two cells;
  border pieces are refused. Q1 (b)'s memory note is corrected.
- **MEDIUM-4, scratch for re-deriving rooms was neither budgeted nor deferred.** Answered: deferred to slices C and F
  with its size (851968 bytes at one level), and listed in §3.1.
- **LOW:** “five test pins” corrected to eight; the edge index formula fixed; the fold-in recipe now lengthens the one
  directory instead of a second; the `merge_gate.py` L2 citation is withdrawn as evidence; the `building_*` columns
  are stated as kept for GDD fidelity; `KIND_COUNT` and declaration growth are deferred to the slices that register
  the columns.

## Open questions for Brendan

**Q1 — How are partitions, doors and repainted cells built?** (slices C and G) Today every partition, door and every
newly painted patch gets its own building job with its own material store. On five levels that is up to a million
jobs, which does not fit the memory limit.
(a) **A room's new cells, partitions and doors are built as one job for that room; painting more cells onto a room
that is still being built adds to its job instead of starting a second one.** Room jobs are then at most one per room
(81920); items such as beds and machines keep their own jobs. Cost: about 23.3 MB (81920 × 284 bytes), plus up to
8.1 MB for painted store rooms' containers; about 1.4 MB of the 150 MB limit would remain after decision 1880. That
is tight, and it assumes Q3 (a).
(b) Keep one job per piece but allow at most 82944 unfinished jobs at once (today's number), refusing more with
“Too many unfinished building jobs”. No memory beyond decision 1880's (pieces can be named by their edge slot and
generation), but a new limit the player can hit.
(c) Keep one job per piece with no limit; not possible within the memory limit.
**Recommendation: (a).** It reuses the room-project revision that decisions 1053/1062 already built and matches how
the player paints rooms. It changes SET-BUILD-001 §10, so it needs your ruling before slice C.

**Q2 — Count decision 1880's 17.0 MB in the live memory total now?** (lead's authorization)
(a) **Yes, now: let a lane extend the underground memory tool's base by 16957440, regenerate its pack file and update
its tests, so the 17.0 MB is reserved before any other lane spends it.** Live total 117208047, headroom 32791953.
(b) Later, when slice C or G first allocates any of it.
**Recommendation: (a).** Until it is folded in, the pack reports 49.7 MB of headroom that is really 32.8 MB.

**Q3 — Can removing cells leave a room part one cell wide?** (slices C and F) Painting already refuses a strip one cell
wide (BUILD-REQ-002), but removing cells could leave one, or even single-cell rooms. That changes the memory needed for
rooms.
(a) **Refuse a removal that would leave a one-cell-wide strip, saying why, or add those cells to the removal so the
review shows them.** Rooms stay at most 81920 and decision 1880's budget holds.
(b) Allow it. Rooms can then number up to 327680, which costs another 22.4 MB and leaves no room for Q1 (a).
**Recommendation: (a).** It keeps the rule painting already follows, so every room stays at least 2 × 2.

## Source

Brendan's ruling of 2026-10-12 (above); SET-BUILD-001 §3, §4, §6, §7.4, §8, §10 and BUILD-REQ-002/003/009/010/013/018;
ARCH-BUILD-001; ARCH-MEM-001/002/009; decisions 0080, 0138, 0531, 1053, 1062, 1071, 1072, 1212 and 1851 (E16);
`tools/underground_memory_budget.py`; DEC-053.
