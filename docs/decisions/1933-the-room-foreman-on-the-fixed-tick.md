# 1933 — The room foreman on the fixed tick (slice C2.1)

Date: 2026-10-15 · Status: Accepted (built; Brendan's rulings in decisions 1931 and 1932). The PROPOSALS below wait
on Brendan.

Number range: this lane's 1931–1949 (decision 1931). C2.2 and C2.3 records take 1934 onwards.

## Decision

A production room foreman now digs a confirmed underground room on the fixed tick, through the real owners. It is
proven on the ADR 1161/1213 Kitchen fixture.

**What the game does today.** The foreman follows whatever rows are bound. In the game those are the claws, and no
claw row qualifies against a room wall until decision 1971's universal stroke lands. So in the game it is claw-only
and digs nothing until then. Nothing in the game constructs it yet: C2.3 composes it from the mounted Session. The
proof runs on the retired content-6 pick rows, by Brendan's leave ("Yes, tests only"). It takes no height and no
price from them: the Kitchen's 8 Sites are the fixture's own DEC-054 clamp, and the foreman prices nothing.

### What was built (`godot/scripts/core/`)

| Module | What it does |
|---|---|
| `underground_room_dig_order.gd` | BUILD-REQ-012's order, computed once per dig (cold, from Sites keys and the Space owner's open regions). The room's cells are taken breadth-first across the floor from the cells beside open space; ties go by cell index (z-major, then x, as SET-BUILD-001 §3's `z × 256 + x`); each column is dug bottom up (decision 1971 confirms bottom up). A room with no open space beside it refuses `ROOM_DIG_ORDER_NO_WAY_IN`. A cell no step reaches sorts last and is still tried, so its refusal is the owners' own |
| `underground_room_builder.gd` | One builder's stage machine over the real owners, after the entry foreman's pattern. Per cube: prove or publish a contact (`Planner.next_contact_into`, aimed at that Site); open BRACE with a real BUILD Job (`create_job`, requester, tool gate, `bind_job`, containers) and assign the builder; walk the itinerary's legs (`Itinerary.reachability_refusal`, each edge's first certified family row, a stationary turn for an exact-heading row); enter WORK; START with the BRACE inputs claimed from the room's storage; earn one `Work.tick_solo_into` per tick; hand over to CUT and FINISH at the same station (DEC-059 P2); settle; walk home along the claimed way back |
| `underground_room_footprint.gd` | ECON-001's spacing between builders: a standing body, or a cube's whole footprint (way there, station work, way back) swept in 256 u pieces |
| `underground_room_foreman.gd` | One room. It plans the order, registers the crew, advances Routes once per tick, and hands each idle builder the first open cube. It sends a builder that just finished a cube up the same column first (painted height). It lets a builder set off only when its footprint meets no other builder's body or footprint. A refused cube waits until a cube is finished or a builder parks. The room is done only when Sites shows every cube finished and every builder is parked |
| `underground_room_runtime.gd` | P-C2-4 (a): one packed record per room (generation, state, storage and spoil containers: 21 B per room row) plus the foremen being dug |
| `settlement_system.gd` | `_advance_underground_rooms(tick)` runs right after `_advance_underground_entry`. It takes one adopted runtime (`adopt_underground_rooms`), dropped on a new mount or release. Every room that stops raises its own refusal and alert |

### Rules used

| Rule | Source | Where |
|---|---|---|
| Breadth-first from the cells touching finished space, ties by cell index | BUILD-REQ-012; P-C9 (a) | dig order |
| Columns bottom up; the bottom cube clawed, the cubes above dug as part of the same work | "Painted height" (2026-10-15); decision 1971 | dig order keeps a column's cubes consecutive; the foreman offers a builder the next cube up its column before sending it home |
| At most 4 builders, one worker per quantum face, parallel faces only where the geometry permits | ECON-001; P-C9 (a) | `MAX_BUILDERS`; exclusive cube dispatch; the footprint rule |
| Inputs consumed once at WORK start; spoil capacity reserved before CUT; refusal when no capacity | ECON-003 | the owners' own START and CUT guards; the foreman stops the room on their refusal |
| Earth has no certified carry, so spoil stays in the bound pile | grip certificate (wood and stone only), decision 1911 §2.2 | nothing is hauled; a full pile stops the room with the pile's own refusal (`CAPACITY_EXCEEDED`) |
| Hand-over between BRACE, CUT and FINISH at the same station | DEC-059 P2 | `_hand_over` |
| A rest hour forbids work (REQ-SET-034) | ADR 1226 | every phase is shorter than Work's 30-WU safe segment, so a rest is waited out between phases (STAGE_BETWEEN), at a column's end, or parked; nothing is dispatched during it |
| The work row decides the tool gate | DEC-052 | `tool_gate_of`: a row naming no tool binds `GATE_NOT_REQUIRED` and claims nothing (the game's claws); a row naming one claims the crew's tool (the retired-pick fixture only) |
| A crew member that died or left stops the work | ADR 1223 crew-loss rule | checked for every builder in every stage |
| Arrival is placement on the endpoint, then registration | ADR 1219 | `register()`: placed on its parking, then admitted, one builder after another |
| One small record per room plus the per-phase projects | P-C2-4 (a); SET-BUILD-001 §10 note | runtime |
| Nothing is shown done that Sites does not show done | UG24 | done is re-read from Sites (SUPPORTED_VOID, no live phase) |

### What a stopped room leaves

The first refusal stops the room. Every builder then releases its open phase:

- an **unstarted** phase is cancelled through `Sites.cancel_phase`. Nothing was paid; its claims are released and
  its Project and Job are retired;
- a **started** phase keeps its paid Project for C2.3's resume. Only its worker is released (`Sites.release_worker`),
  so no resident is held by a dead Job.

The route actor stays where it stopped. `release_room` clears the record; re-ordering digs what is left, and the
owners refuse to reopen a phase a stopped dig had paid until C2.3 resumes it.

## Proof (fixture: ADR 1161 Kitchen, 2 × 2 cells × 2 layers, retired content-6 pick rows)

| Test | Result |
|---|---|
| One builder, `advance(tick)` only | All 8 cubes paid; the ledgers are ADR 1213's exactly (wood 2,000, stone 2,000, earth 16,000 milli-U, 33,840 milli-WU). No live Project, no cold lease, the builder parked by real travel. 2,870 ticks (ADR 1213's test loop took 3,905: the DEC-059 hand-over saves a recovery and an entry per phase). Column offers: 4, none taken (below) |
| Two builders (corridor widened 4 m south for a second parking, test geometry only) | Each cube finished once (5 and 3); both dig; 1,008 builder-ticks of waiting for the other's footprint; never both at a station at once. On this 2 m wide room the footprints always meet, so they take turns (ECON-001: parallel faces only where geometry permits) |
| Rest hours | Waited out between phases (twice), at a column's end and parked; nothing paid twice |
| Spoil pile full | Stops with `CAPACITY_EXCEEDED`: one BRACE paid, nothing cut, no cube done, the unstarted CUT cancelled, no live Project, the mole holds no Job |
| Builder lost (left mid-approach; dead before it is sent) | `ROOM_BUILDER_CREW_LOST`; the unstarted BRACE cancelled |
| Crew that can never move again (negative-only injection) | `ROOM_FOREMAN_CREW_BLOCKED`, BRACE cancelled, nothing paid |
| A builder at its station sent to a cube that needs a new chain | `ROUTE_OCCUPIED` (ADR 1213 "Parking": its own body blocks the publication); it stays at its station, then walks home, and the cube is dug from parking |
| Dig order | Exact order and distances on the Kitchen; reversed when the only open space is on the far side; no way in; unreached cells last; refusals named |
| Settlement wiring | An adopted runtime is dug to DONE by `SettlementSystem.run_tick` alone; the record is DONE, then released and re-orderable |
| Death mid-phase | The room stops; the started BRACE keeps its paid Project (one live), the resident holds no Job |
| Raw removal that skips decision 0017's departure | The room stops with the loss; Sites' release refusal (`EXCAVATION_WORKER_BINDING`) is kept apart rather than a clean stop claimed |
| Contracts | A key that leads to another Site; a busy cold lease (waited out); a counter that disagrees with Sites (`ROOM_FOREMAN_SITES_NOT_DONE`); a re-configure; a tool-less member on the pick rows (Routes' `PROFILE_TOOL_REQUIRED`); a crew member already digging; a row reused by a new room; a finished room with its crew still away (finishes without bringing it in); the grid edge in the dig order; the footprint's pieces, cache and half-open overlap |

**Column continuation is not taken on this fixture.** Every upper cube there needs its neighbours' lower cubes first
(ADR 1213), so the offer up the column is always refused, and the builder walks home. Under painted height an upper
cube is paid from its column's floor station (decision 1971's `_face` change). The offer then succeeds with no new
chain and no walk home. That positive path is proved when decision 1971's branch is merged (coordinator's note).

## Trial against the universal stroke (PR #260, `1eecb657`, not merged)

A trial merge was tested and then aborted; nothing from it is committed. The room suites ran on the merged tree.

**What #260 changes for C2.1.**
- The Kitchen fixture now has 16 Sites: 4 cubes per column.
- WorkFace refuses `WORK_FACE_COLUMN_UNOPENED` unless every cube below the paid one is a finished void.
- An upper cube is paid from its column's floor station.

**Results with this foreman unchanged.**
- **One builder** dug all 16 cubes in 2,976 ticks. It took **12 cubes straight up their columns** (3 per column)
  without walking home: painted height's stacked cubes, dug bottom up inside the breadth-first order.
- **Two builders** dug 8 cubes each, all 16 cubes exactly once.
- **Seven assertions failed, all fixture expectations that #260 changes:**
  - the dig order's three exact lists still expect 8 Sites;
  - the station-refusal test now meets `WORK_FACE_COLUMN_UNOPENED` before `ROUTE_OCCUPIED`, and its builder had
    already taken a cube up its column;
  - the stuck-room injection marks cubes that are now different cubes.

  These are updated when the coordinator says to merge `origin/master`.

## PROPOSALS for Brendan

**P-1933-1 — How the crew reaches its parking.**

- **(a) As the entry crew does: ADR 1219's surface walk over BAL-WORK-003's straight-leg ticks, then placement on the
  parking endpoint and registration.** Builders arrive one at a time, because a resident still on its way blocks every
  occupancy proof within 5,222 u (ADR 1219's reach rule).
- **(b)** Placement only, as C2.1 does now in tests.

**Recommendation: (a), built in C2.3.** C2.1's `register()` places and registers, which is ADR 1219's arrival without
the walk.

**P-1933-2 — A stopped room's paid phases.**

- **(a) Keep a started phase's paid Project for a later resume, releasing only its worker (as built).** An unstarted
  phase is cancelled; nothing was paid.
- **(b)** Cancel started phases too: ECON-005 refunds 80 %, so a fifth of the bill is lost on every stop.

**Recommendation: (a).** C2.3 builds the resume.

**P-1933-3 — How close two builders may work.**

- **(a) Footprints as built: the whole way there, the station and the way back, as 256 u boxes, and a builder waits
  until its footprint is clear of every other builder.** It is deadlock-free and stops honestly when nothing can move.
  On the 2 m Kitchen the builders always take turns.
- **(b)** Exact per-tick occupancy (Routes' own sweeps) instead of claimed footprints. This allows more parallel work
  in large rooms, at a higher cost per tick and with the risk of two builders blocking each other mid-route.

**Recommendation: (a)** until a room large enough to dig in parallel is measured.

## For C2.2 and C2.3 (found here; not built)

- **C2.2:**
  - Delivery's room pin, so the room's storage is stocked (today the fixture stocks it by hand);
  - station-chain retirement, needed past about 94 route edges (ADR 1213).
- **C2.3 composition:**
  - one composite Jobs dispatcher for the entry and the room runtime. The entry runtime's `owns_job` claims every
    excavation Job, so with the entry bound, only the entry crew could take a room Job (`REFUSE_DISPATCHED_JOB`).
    Room builders must also be reserved from the JobSelector between cubes (decision 1223's rule, extended);
  - the runtime built from the Session;
  - P-1933-1's walk in.
- **C2.3 save and load:**
  - the record, the foremen and the builders' cursors (registry rows marked UNRESOLVED);
  - a resume for a stopped dig's paid phases (P-1933-2);
  - moving the route actors of a stopped crew;
  - the memory ledger.

## Memory

- **The packed record:** 16,384 room rows × 21 B = **344,064 B**. It is not allocated in the game in C2.1: nothing
  constructs the runtime outside tests. C2.3 ledgers it when it composes the runtime.
- **Per dig being dug:**
  - the order, 12 B per Site;
  - the dispatch marks, 1 B per Site;
  - per builder, a claimed footprint of 210–306 boxes × 24 B (about 5–7 KB on the Kitchen) and a row-extent cache
    of 67 rows × 24 B = 1,608 B.

  At most 256 digs run at once (one builder each at the population cap).
- **Not triggered here:** decision 1880's 16,957,440 B fold (P-C8 (a)). C2.1 allocates no painted cell, room, item
  or edge column.
- **Settlement:** the only census-input change is `settlement_system.gd`'s one runtime reference. It is a reviewed
  zero-byte delta in `reviewed-deltas.json` (ADR 1212's projection update): `REVIEWED_SHA` renewed, the pack
  regenerated. Pins only; totals unchanged: live 100,250,607 B, headroom 49,749,393 B.

## Performance (gate 6 judged after the cost lane, P-C2-2 (a))

**Method.** A scratch suite (not committed) wrapped each fixed tick of a whole Kitchen dig with the final code:
`Routes.advance_tick` first, then `foreman.advance`, with `Work.tick_solo_into` timed inside it. **Own** = the
foreman's tick minus the Work tick. It still includes every other owner call the foreman makes: the planner and
publication, `open_phase`, START, settlement and the Routes reads.

**Conditions.** Brendan's Mac, headless editor binary, load average 11–15 (other lanes running), so these are not
floor figures.

| Crew | Ticks | Own p50 µs | Own p90 µs | Own p95 µs | Own p99 µs | Ticks with own < 1 ms | Whole tick p50 µs |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 builder | 2,870 | 370 | 626 | 762 | 133,043 | 2,732 (95.2 %) | 2,976 |
| 2 builders | 2,945 | 395 | 674 | 3,545 | 157,223 | 2,784 (94.5 %) | 3,229 |

**The foreman's own share.**

- In steady stages it is a few hundred µs per tick, and most of that is Routes reads (`read_actor_into`, the
  readiness leaf).
- The p99 ticks are the owners' phase transitions: START and settlement take 110–170 ms each, measured in decision
  1931 F3.
- The 2-builder p95 adds the footprint checks and the second builder's reads.

**Who owns what is over budget.**

- The 2 ms budget is broken by the owners, not the foreman: `Work.tick_solo` about 4.6 ms, `Routes.advance_tick`
  about 1.8 ms, plus the START and settlement stalls.
- Those belong to the cost lane (`perf/dig-tick-cost`, P-C2-2 (a)).

## Review

An independent `code-reviewer` read `ac44f842`. It found:

- **HIGH H1, the set-off rule could hang silently.** **Fixed:**
  - a crew in which nothing can move stops with `ROOM_FOREMAN_CREW_BLOCKED`, and the check trusts only blocks still
    current at the end of the tick;
  - a waiting builder is never mistaken for a stall.
- **HIGH H2, a stopped room orphaned Jobs and Projects.** **Fixed:** abandon on halt, as described above. Both
  spoil-pile tests assert `live_project_count() == 0`.
- **HIGH H3, a lost builder in IDLE, COLUMN or BETWEEN hung the room.** **Fixed:** the crew-loss check (directory
  row or DEAD) runs every tick for every builder, before registration too. Tested both dead before dispatch and
  departed mid-approach.
- **HIGH H4, the entry dispatcher owns every excavation Job.** **Deferred to C2.3**, where the runtime is composed;
  nothing composes it in C2.1, so it cannot occur in the game. Listed above.
- **MEDIUM:**
  - **Fixed:**
    - M1 the epoch tracks every stage, motion and footprint change;
    - M2 cached extents, a hull pre-check and an in-place body;
    - M3 `may_work` before the open-cube scan;
    - M4 only running digs count, re-ordering needs a release, record rows are kept per foreman, and a deleted
      room's row is reusable;
    - M5 a busy crew member is refused;
    - M6 the retained order is in the registry note;
    - M7 the way home is the claimed one;
    - M8 every stopped room alerts.
- **LOW:**
  - **Fixed:**
    - done is re-verified from Sites;
    - the epoch cache is 64-bit;
    - `configure` refuses missing owners and a re-configure;
    - a busy cold lease is retried rather than marked refused;
    - a dug room finishes before any registration;
    - the sort key's bounds are guarded.
  - **Answered:** `register()` placing the worker is P-1933-1.
- **Tests the reviewer said could not fail:**
  - **Fixed:**
    - both builders must dig;
    - turns must happen;
    - the column offer must happen;
    - the frozen crew is driven to its refusal.
  - **Not provable on this fixture:** the two builders at a station at the same moment. Their footprints always
    meet in a 2 m room.

## Corrections to this lane's earlier records

See decisions 1931 and 1932: rows 57/59/61/63 are the paw seating tap, not dig rows; the claws' 1,024 u came from
them (decision 1971).

## Mutation testing

One mutant per run, applied by a scratch runner (not committed), with the focused suites run cheapest first and the
source restored after each.

- **First pass:** 63 mutants, 41 killed. For the 22 survivors, tests were added or code that could never decide
  anything was removed (commit `67298b03`). Four survivors went with their code: the seed's room-membership skip, the
  footprint's role filter, the duplicated loss check and the pre-open tool check.
- **Second pass:** the 18 survivors still in the code plus 5 new mutants on the new code. 16 killed and 7 survived;
  one of the 7 (the record's generation check on settlement) then went with its code too (commit `2c630115`).
- **In all:** 68 mutants, 57 killed, 5 moot because their code is gone, 6 survived.

| Survivor | Why it survives |
|---|---|
| Footprint: drop the hull pre-check before the pairwise test | Equivalent. The pre-check only skips work; the answer is the same |
| Tool gate `tool >= 0` → `> 0` | Equivalent on published content: item id 0 is `beans`, and no row names it as a tool |
| `ROUTE_OCCUPIED` on a route request is waited out → returned as a failure | Not reached here: footprints keep builders apart, and nobody outside the crew stands in the fixture. It guards against residents outside the crew (the entry crew, passers-by) |
| A held route step is waited out → returned as a failure | Same reason |
| The turn to the work row's heading at the station is skipped | Not reached here: every Kitchen work row has the approach row's heading. It is needed when they differ |
| Reopening refused cubes on a settled FINISH is removed | Outcome-equivalent: the same cubes reopen a few ticks later, when the builder parks. Only the timing differs |

SURVIVED_MUTANTS: the six above. Two are equivalent, one is outcome-equivalent, and three guard against conditions
the fixture cannot produce.

## Gates (at `2c630115`, run 2026-10-15)

- **Full suite, CI-style.**
  - Setup: `godot/.godot` deleted, `godot --headless --path godot --editor --quit`, no demo art in this worktree.
  - Run: `./tools/run_tests_parallel.sh --jobs 3` (CI's 10 shards and CI's verify).
  - Result: `ok: 509 suite files executed exactly once across 10 shards`, 12,534 tests, 1,237,361 assertions,
    0 failures, 0 unexpected errors, 0 unexpected warnings, 0 leaked objects or resources; every shard exited 0.
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6433`: `0 GDScript warning(s) in 0 of 1548 file(s)`.
- **Contracts:** every check in CI's contracts job exited 0. They include:
  - `decision_numbers.py` PASS;
  - `ready07_arithmetic.py` PASS;
  - `underground_memory_budget.py --check`, `test_underground_memory_budget.py` and
    `test_underground_current_census.py` OK;
  - `merge_gate.py` PASS;
  - `state_registry_coverage.py`: PASS, 199 modules, 818 rows, 1,097 packed columns.
- **Mutation testing:** above.
- **Review:** above.
- **Performance:** above. Gate 6 is judged after the cost lane lands (P-C2-2 (a)).

## Source

BUILD-REQ-012, SET-BUILD-001 §3 and §10; ECON-001, ECON-003, ECON-005; DEC-052, DEC-054 (as amended by "Painted
height"), DEC-059; REQ-SET-034; ADR 1161, 1191, 1212, 1213, 1219, 1223, 1225, 1226; decisions 0017, 1880, 1911,
1931, 1932, 1971.
