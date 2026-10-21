# 1935 — Same-level room Delivery and the builder's haul stage (slice C2.2)

Date: 2026-10-15 · Status: Accepted (built under decision 1934's rulings: P-C22-1 "Same-level now + basic stair
carry", P-C22-2 (a)). Nothing here is a new ruling; the choices made while building are recorded below.

Number range: this lane's 1931–1949 (decision 1931). Branch `feat/room-foreman-c2-2`.

## Decision

A room's BRACE inputs (wood and stone) are now hauled into the room's storage from a staging container on the
**same underground level**, through the World's one Delivery and the entry's hauler, unchanged. A staging container
on another level is refused with the named gap **`ROOM_HAUL_NO_STAIR_CARRY`** until stair-carry rows exist
(`feat/stair-carry`). Station-chain retirement is not built: it follows the cost lane (P-C22-2 (a)), and
`underground_locations.gd` is untouched.

**What the game does today.** Nothing yet: no stock reaches any underground level (decision 1934, finding 1), and
nothing in the game constructs the room runtime until C2.3. The proof runs on the Kitchen fixture.

### What was built (`godot/scripts/core/`)

| Module | Change |
|---|---|
| `underground_connector_delivery.gd` | **Room branch.** An excavation Project whose Site belongs to a live room that no present Placement names as its corridor is a room dig (`_room_dig`: the phase authority's own rule, `underground_room_world_bindings.gd` `_ordinary_entry_room`, so the two never disagree). Its destination is the Project's own material container, which Sites proved at `bind_material_container` and re-proves at `record_deliveries`; no Placement or Frontier row is read (`_pin_room`). The final leaves re-prove the graph receipts and that the Project is still open on a Site of a live non-entry room (`_room_source_leaf`). Endpoint containers belong to the Placements owner's World (`_world_of`). Every worker, grip, scene, role, occupant and transfer leaf is shared with the entry branch. One retained flag, `_room_haul` |
| `underground_room_builder.gd` | **Haul stage.** When a Delivery is bound and a staging container named, a BRACE whose inputs the storage lacks (whole units, ADR 1210's `units_into`) is preceded by `STAGE_TO_STORE` (walk to the storage, no Job) and `STAGE_HAUL` (the entry's hauler, unchanged, then the BRACE Job brings the builder back onto the storage). The builder then goes on along the claimed way to the station. The two endpoints must be live and on one level (`ROOM_HAUL_NO_STAIR_CARRY` otherwise), and are re-proved when the haul starts |
| `underground_room_foreman.gd`, `underground_room_runtime.gd` | The staging container in `configure` and in the room record (P-C22-1's +8 B: 29 B a row). A staging container that is the storage is refused |

### Choices made while building

1. **No Delivery-side level check.** Delivery's grip reachability (`_reach_stands`) proves the loaded leg on the
   item's CARRY row, and no stair row admits cargo (ADR 1229, constraint 4), so Delivery already refuses any stair
   leg. The gap is named where the haul is planned (the builder).
2. **Inputs are reserved when the builder sets off.** A BRACE's inputs are claimed for its Job at dispatch, or the
   moment its haul lands; Sites records the delivery at START, where it proves the delivery with the worker at its
   station (ECON-003's consumption at START is unchanged). Before this, hauled units lay free in the storage until
   START, and a second builder could plan against them (review C1).
3. **The tool is claimed at the station.** For both paths the work row's tool (none for the claws, DEC-052) is
   claimed where the work begins, not at dispatch. Travel needs no claim.
4. **The walk to the storage carries no Job.** The builder walks with its own legs, which turn for exact-heading
   rows; the hauler's legs do not turn. The hauler's last step assigns the BRACE Job (as the entry's does).
5. **The haul's footprint.** The trips are claimed along the routes the graph search takes for the haul WALK row
   and each item's CARRY row (every polyline segment), with the lift and set-down rows at both stands, so the
   foreman's turn-taking (ECON-001) sees them. The haul WALK row is the certified automatic tool-free, cargo-free
   WALK row (row 31 in contents 6-10). The hauler, unchanged, still fails on a held step
   (`ENTRY_HAUL_ROUTE_HELD`); the claim is what keeps other builders off the trips.
6. **Set off, not standing.** A builder with no leg to walk (parked on the storage) has not set off until it acts,
   so the footprint check runs first; after the haul it stays set off and its cube's claim stays occupied.
7. **Abandon.** A haul under way returns its admitted claim through Delivery's cancel and retires its HAUL Job
   (ADR 1225, as the entry's); goods already lifted stay in the satchel. The phase is released even when that
   release refuses.
8. **A rest hour during a haul is waited out** (found by the focused tests). Jobs refuses any assignment in a
   rest hour, and every trip takes a new HAUL Job, so a rest falling mid-haul stopped the room
   (`STEP2_ACTIVITY_FORBIDS_WORK`). The builder now neither starts a haul nor advances one while the hour rests,
   and the wait is not a stall (as `STAGE_BETWEEN`'s). The route actor finishes the step it is on.

## Proof (fixture: ADR 1161 Kitchen, 16 Sites, retired content-6 pick rows; `test_underground_room_haul.gd`)

The fixture adds a staging container R in the Corridor, the two grip stands (WORK endpoints at the certified
offset, footing from `underground_entry_work_area.gd` STAND_FOOT), the haul spans (WALK both ways, the loaded CARRY
span in the work area's shape), and paces for rows 31, 32 and 37 at the existing Movement rate (the content-6
manifest's ground pace rule: RATE_GROUND_CAP, no new constant). Delivery is composed with a minimal valid entry
Frontier source; a room haul reads none of its rows.

**Fixture steps (not game behaviour).** Content 6's haul rows hold no tool (ADR 1217) and its travel and work rows
need the pick, so the room's storage M is the crew's parking, the test puts the pick into M before the haul and
takes it back after, and adds the other cubes' inputs to M (the pick fixture can haul only once). A body parked on
the Corridor access closes every later station chain (`ROOM_STATION_GEOMETRY_CLOSED`, found here), so M is not the
access. C2.3 should place crew parking off the access.

| Test | Shows |
|---|---|
| hauls the first BRACE inputs and the room is dug | two trips (one whole unit of wood, one of stone) R → M through the room branch; the BRACE's 250 + 250 reserved out of them on landing; the room dug to Sites' record; lift and set-down paid exactly |
| a held tool stops the haul | Routes' `PROFILE_TOOL_REQUIRED` at the switch at rest; the BRACE cancelled, the HAUL Job retired, R untouched |
| a crew lost mid-haul | Delivery's cancel returns the claim; nothing held |
| a crew lost on the way home | the BRACE Job's release through Jobs; the delivered unit stays in M |
| no staging container | no haul; `ENTRY_FOREMAN_INPUT_LOT` as before |
| a staging container on another level | `ROOM_HAUL_NO_STAIR_CARRY` (a second Corridor floor, level 2) |
| the claimed footprint | both stands covered |
| scope | no Locations: `ROOM_BUILDER_SCOPE`; a container with no endpoint: `ENTRY_HAUL_NO_STAND`; staging = storage refused |
| branch choice | a present Placement naming the Kitchen sends the Project down the entry branch, which refuses it; without it, one whole unit is admitted |

## Not proven here (named)

- **`ROOM_HAUL_NO_STAIR_CARRY`** stands until `feat/stair-carry`'s rows exist.
- **A whole haul from a station up a column.** The focused test proves the plan and the walk back to M on real legs
  (`test_underground_room_haul_leaves.gd`); the trips themselves cannot run there, since the pick fixture cannot
  carry while holding the pick. C2.3's claw Kitchen runs the whole case.
- **Two builders hauling at once:** the claim keeps them apart (its boxes are pinned); a two-builder haul needs
  the claw fixture too (C2.3).
- **Save and load of a haul in progress:** C2.3 (registry rows UNRESOLVED, as the entry's ADR 1218).

## Review and mutation testing

**Independent review** (code-reviewer, on `224b01e1`): one CRITICAL, three HIGH, six MEDIUM, three LOW. Fixed in
`0af57424` and `95ce10e7`:

- **C1** hauled units lay free in M until START: inputs are now reserved at set-off or on landing (choice 2).
- **H1** a builder with no leg to walk counted as set off and skipped the footprint check; **H2** after the haul its
  occupied space shrank to its body: a `_departed` flag (choice 6).
- **H3** the trips were claimed as straight lines without the handling rows: now along the searched routes, with the
  lift and set-down rows (choice 5). The hauler's hard stop on a held step stays (the hauler is reused unchanged).
- **M1** room versus entry: Delivery now uses the phase authority's exact rule, so they cannot disagree; a
  Placement-less entry cut is a room for both (it was refused before), and its material contact is still Sites'.
- **M2** the endpoints are re-proved when the haul starts (`ROOM_HAUL_NO_STAIR_CARRY`, or `ROOM_BUILDER_TARGET_MOVED`
  for a different container); **M3** abandon releases the phase even when the haul's release refuses; **M5** the
  hauler's Locations must be the binding's; **M6** staging = storage is refused. LOWs fixed (docstring, pose row).
- **LOW notes (kept):** M5's two small duplications. `_haul_units` repeats the entry foreman's `_phase_units`
  (eight lines; the entry foreman is not this lane's file), and `_stand_of` repeats the hauler's stand rule (an
  instance method there, so not callable without a hauler).

**Mutation testing** (scratch runner, one mutant per run, focused suites; rounds on `224b01e1`, `0af57424`,
`95ce10e7`, `fff1b9ad` and, for every survivor, `44da48a1`): 57 mutants. 7 are moot (their code was replaced or
removed by the review fixes). Of the 50 that apply to the final code, **46 are killed**, **3 are equivalent** and
**1 is deferred to C2.3**.

The survivors of the first pass were killed by focused tests (`test_underground_room_haul_leaves.gd`, plus two
in `test_underground_room_builder.gd`):

- Delivery's room leaves are called on a real pinned operation while the world changes under them: a Location
  and a route published after the pin; a present Placement naming the room; the Site holding another Project; a
  stale room generation; a non-Site subject; the leaf's budget one check short.
- The trip claim is checked box by box: each item's lift and set-down box at the stands, and, on a hand-built
  variant with a direct span from M to R's stand, the empty walk between the stands.
- The builder's stage machine is driven directly: the next cube up a column hauls from its station (real legs back
  to M, the approach claimed from M); the stall bound restarts on the hauler's progress; a rest hour at a stand and
  on arrival at M (choice 8); the post-haul pose row and the BRACE Job on the legs; the trip ledgers counted once;
  only a BRACE is hauled for; two stands at one point are no stand; a builder sent home has not set off.

| Survivor | Verdict |
|---|---|
| `_clear`'s reset of `_room_haul` | **Equivalent.** Every reader (`_material_leaf`, `_source_leaf`, `_world_of`) runs inside `_operation_leaf`, which is reached only after `_pin_project` has assigned the flag in the same operation; `cancel` takes `_cancel_leaf` first, and a Work leaf whose observation failed is refused on its cleared Job |
| `_start_haul`'s `_at = _store()` | **Equivalent.** TO_STORE ends only past its last leg: its legs were planned from `_at` to the storage, so either the walk set `_at` to the storage at each arrival, or there was no leg because `_at` already was the storage |
| `continue_column` planning the walk to M on the retreat row instead of the forward row | **Equivalent.** The foreman's forward row is `Itinerary.family_row` of the retreat row: same identity fields and quantities, so `Itinerary._compatible` admits the same rows for either anchor and the search returns the same legs (the column test passes either way) |
| `_departed` set when the first step is a turn | **Deferred to C2.3.** It needs a builder whose first leg starts facing away from an exact-heading travel row. In the game that is the leg after every haul: the hauler's last walk ends on the haul WALK row facing the stand's heading. The pick fixture cannot turn with its pick at the parking (`ROUTE_TURN_UNCERTIFIED`), so its test turns the body itself. Covered by C2.3's claw Kitchen haul-and-dig case, in which the builder turns after the haul |

## Performance (judged after the cost lane, P-C2-2 (a))

Scratch suite (not committed), the full haul-and-dig run, Routes advanced first, then `foreman.advance` timed whole
(it includes Delivery's final proofs and the handling Work ticks). Brendan's Mac, load average 4–5:

| Ticks | n | p50 µs | p90 µs | p95 µs | p99 µs | max µs |
|---|---:|---:|---:|---:|---:|---:|
| Walking to M and hauling (2 trips) | 199 | 59 | 3,419 | 3,629 | 9,274 | 13,199 |
| Digging (16 cubes, Work included) | 2,975 | 299 | 9,146 | 13,374 | 122,124 | 196,498 |

The haul's walking ticks are cheap; its lift and set-down ticks run Delivery's complete final proof every Work
tick (about 3.5 ms) and its admissions and transfers about 9–13 ms. Over budget, as the dig's own Work and phase
transitions are (decision 1933); the cost lane owns those paths.

## Memory

- Delivery: one bool, `_room_haul`; fixed 834 → 835 B, declared 3,907 → 3,908 B of its 4,096 B reservation
  (ADR 1212's update in `tools/underground_memory_budget.py`; pack regenerated). Totals unchanged.
- The room record: 21 → 29 B a row, 344,064 → 475,136 B. Not allocated in the game until C2.3 (the reviewed
  settlement delta's text updated, `REVIEWED_SHA` renewed).
- Per hauling builder: the queue (one int per unit, at most 2 per BRACE) and the approach legs.

## Final gates (at `7309fb25`, after merging `origin/master` with PR #262, 2026-10-15)

- **Full suite, CI-style:** `godot/.godot` deleted, `godot --headless --path godot --editor --quit`, then
  `./tools/run_tests_parallel.sh`: `ok: 513 suite files executed exactly once across 10 shards`, 12,608 tests,
  1,245,478 assertions, 0 failures, 0 unexpected errors or warnings, 0 leaked objects or resources; every shard and
  CI's verify passed. The two underground checkpoints were regenerated for the new sources (manifests only).
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6433`: 0 warnings in 1,556 files.
- **Contracts:** every command of CI's contracts job exited 0 (`decision_numbers.py` 558 records,
  `underground_memory_budget.py --check` and its tests, `test_underground_current_census.py`, `merge_gate.py`,
  `state_registry_coverage`, the registry and schema generators' checks, among them).
- **Boundaries:** no edit to `work.gd`, the routes modules, `excavation_sites.gd`, `underground_locations.gd`,
  `underground_room_world_bindings.gd`, the hauler, the stroke lane's or the stair-carry lane's files.

## Source

Decisions 1210, 1217, 1225, 1229, 1933, 1934; `underground_connector_delivery.gd`, `underground_entry_hauler.gd`,
`underground_room_world_bindings.gd` `_ordinary_entry_room`, `excavation_sites.gd` `bind_material_container`,
`record_deliveries`, `release_worker`.
