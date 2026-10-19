# 1942 — Room station-chain retirement, built against the re-measured route budget

Date: 2026-10-19 · Status: Accepted (built). Plan of record: decision 1934 §2, sequenced by the coordinator's
P-C22-2 (a), "after the cost lane" (that lane landed as #265, #269 and phase-spreading stage 1, #274). No ruling by
Brendan was needed. P-1942-1 below is the coordinator's sequencing call.

Lane `feat/room-station-retirement`, from master `8a7d045d`. Number range 1942–1949.

## Decision

1. **A room's finished columns give their station chains back.** Once the live route graph holds **35 edges**
   (`RETIRE_FROM_EDGES`: the edge count whose phase-commit route proof spends half of `Space.MAX_CHECKS` at the
   re-measured cost), each column whose cubes are all dug has its chain retired as soon as its builder stands idle.
   A chain is the column's WORK station plus the TRANSIT stations that lead to it alone. They leave Routes, then
   Locations, one chain a tick.
   - Below 35 edges nothing is retired, so the Kitchen (20 edges) and every room that never nears the bound digs
     exactly as on master.
   - The removal goes through the owners' own plain staging calls, as `underground_entry_stair_path.gd` retracts a
     stair stop. **`underground_locations.gd` is not edited.** Decision 1934 §2 expected a second issuer there; it is
     not needed (§3, choice 1).
2. **The station planner now agrees with Locations on other rooms' claims.** This is slice C3's two-room failure,
   root-caused here (§4.1).
   - A WORK station published as one air box is proved against its own Site's survey. That survey treats every
     claimed row as an obstacle, except the claims of the station's own room and its own phase.
   - The planner treated every room marker as nonphysical, so it could plan a box that publication then refused.
   - The planner now refuses such a box itself and goes on to the next lateral root.
3. **The gap that remains: rooms not dug straight out from their access** (§4.2). P-1942-1 (the coordinator's
   sequencing call): multi-heading digging is the next lane, straight after this one.

## 1. Re-measured on current master (`8a7d045d`)

**Method.** Scratch probes (not committed) dig claw rooms (content 12, decision 1939's fixture) through the room
runtime with one builder. The committed suites do the same.
- After every tick the probes read the last sealed route proof's spend (`WorldRoutes._proof_checks`) and the live
  edge and Location counts.
- Larger rooms paint the Kitchen's request wider or deeper. They have larger fixture arenas, M is topped up with
  BRACE stock, and the spoil goes to its own pile.
- Master runs used a clean worktree at `8a7d045d`.

**The paced rows decide the cost.** WorldRoutes certifies every edge for every paced row it admits. Two catalogs
were measured:
- the game's own ground-pace catalog (`qualified-stairs-v10/ground-pace.ugconn`), with **26 paced rows** (1–12, 31,
  32, 37 and 42–52);
- the claw Kitchen test fixture, which paces only 6 (31, 32, 37, 42, 46, 50).

The first is the one that counts. It is what the constants and the committed suites use.

**Under the game's catalog (26 paced rows):**

| Room (cells, cubes) | Done | Peak edges | Peak proof checks (of 1,048,576) | Ticks | Longest tick, stalls ≥ 20 ms (sum) |
|---|---:|---:|---:|---:|---|
| 2×2 Kitchen, 16 | 16 | 20 | 399,120 (38.1 %) | 2,845 | 262 ms, 111 (16.8 s) |
| 4×4, 64 | 64 | 84 | 912,640 (87.0 %) | 12,277 | 808 ms, 447 (141.6 s) |
| **6×4, 96** | **72, refused** | 100 | 1,044,960 (99.7 %), then `SPACE_COMPANION_PREPARATION_REFUSED` | 14,267 | 820 ms, 510 (177.0 s) |
| 6×4 on this branch | 96 | 40 | 582,956 (55.6 %) | 18,967 | |

- **Cost per route edge: about 8,059 checks**, with a base of about 237,561 (least squares over 20, 84 and 100
  edges).
- **The real limit: about 100 live edges.** (1,048,576 − 237,561) / 8,059 = 100.6, and the 6×4 room refuses at
  exactly 100.
- ADR 1213's "about 94 edges" was close. Decision 1934's "12.7 k a live edge" was an average (peak ÷ edges) on
  content 6.
- A room of 24 cells (6×4) cannot be dug on master. With retirement the same room is dug whole at the same ticks,
  never above 40 edges.

**Under the fixture's 6-row catalog** (for comparison; same rooms):

| Room | Done | Peak edges | Peak proof checks | Ticks | Longest tick, stalls ≥ 20 ms (sum) |
|---|---:|---:|---:|---:|---|
| 2×2 | 16 | 20 | 259,336 | 2,845 | |
| 4×4 | 64 | 84 | 352,684 | 12,277 | 450 ms, 441 (80.9 s) |
| 6×4 | 96 | 128 | 462,896 | 18,967 | 706 ms, 665 (172.6 s) |
| 12×4 | 192 | 260 | 798,332 | 40,837 | 1,472 ms, 1,341 (700.0 s) |
| 6×4, every chain retired | 96 | 10 | 171,062 | 18,967 | 143 ms, 630 (54.8 s) |

- About 2,480 checks a live edge (paired runs of the same room at the same ticks). The spend depends on the edges,
  not on the dug space: with every chain retired the peak stays at 171,062 from 16 cubes to 112.
- Locations preparations peak at 59,814 checks (5.7 %). They do not bind.

**Wall clock.** Each live edge adds about 5 ms (fixture catalog) to 8 ms (game catalog) to a phase START or
settlement. Retirement cuts the longest ticks as well as the check spend.

## 2. What was built

| File | Change |
|---|---|
| new `scripts/core/underground_room_station_retirement.gd` | Stateless. `due` (the live edge count reaches `RETIRE_FROM_EDGES`). `retire_finished` offers one chain a tick: the first idle builder whose last column is done has `chain_into` walk back from its WORK station, `retire` publishes the removal, and every idle builder that named a retired station forgets it. `retained` and `_locations_ready` are the pre-checks. The constants `MEASURED_BASE_CHECKS` (237,561), `MEASURED_CHECKS_PER_EDGE` (8,059) and `RETIRE_FROM_EDGES` = (`Space.MAX_CHECKS` / 2 − base) / per-edge = 35 |
| `scripts/core/underground_room_runtime.gd` | `advance`: one call, `Retirement.retire_finished(_foremen, _owners)`, after every foreman has advanced and before `_release_done` (the order agreed with slice C3: advance, retire, release, C3's `start_waiting`) |
| `scripts/core/underground_room_foreman.gd` | New: `retirable_station` (an idle builder's last station once its column is done; any station once the dig is DONE), `_column_done` (every order entry in the Site's column is DONE), `holds` |
| `scripts/core/underground_room_builder.gd` | New only: `station`, `last_site`, `holds` (parking, where it stands, and while not idle its station, plan legs, stands and haul endpoints), `_pair_in`, `forget_retired` (an idle builder whose station or plan named a retired station clears them, so its saved cursor names only live endpoints), `_names_any`. No member, no existing function, no save byte layout changed |
| `scripts/core/underground_room_station_planner.gd` | `_station_fits`: after the footing check, the WORK station's single published box must pass `_foreign_claim`. `_regions` keeps the claimed rows meeting the hull in a fifth table (`_keep_claim`; past 192 it falls back to scanning the owner). `_foreign_claim` mirrors which survey Locations uses: a world section keeps every claimed row; a room's section uses the Site holding the point, which must be that room's, and exempts only that room's claims and the Site's phase claim (`_section_room`, `_cube_origin`, `_exempt`, `_owner_claim`). `CONTROL_BYTES` 45,752 → 52,664 (the table and its refs, a cold slice inside the existing lease) |
| `test/test_underground_room_world_phases.gd` | `Phase.Fixture` gets `lot_capacity` and `site_capacity` (defaults unchanged) for the larger rooms |

### How a chain is found and retired

- **The walk.** Start at the WORK station, which must have one neighbour. Step to the next station while it is a
  TRANSIT station with at most two distinct neighbours (the one before and the one after). Stop at:
  - the gateway (the provider's bound retreat endpoint);
  - a junction: a station another chain also leaves from (ADR 1213's start at an existing TRANSIT station);
  - any endpoint some builder of any dig still holds;
  - anything that is not a station.
  - The walk is bounded by `MAX_CHAIN` = 2 × `Publication.MAX_STATIONS`. A longer run is left whole: none of it is
    taken, so no dangling spur is ever made.
  - A WORK station that is the gateway, or that another span leaves from, ends no chain.
  - A junction left behind becomes a plain station once the other chain goes, so the later walk takes it.
- **Pre-checks, so nothing is ever left half done.** The second publication can only fail where these could not
  foresee it:
  - no route actor stands on a chain station, and no container is placed on one (`retained`);
  - the entry's own contact-retirement bracket is closed;
  - the cold lease is free (`Budget.REFUSE_BUSY` means try again next tick);
  - under that lease a Locations preparation can begin (`_locations_ready`: a trial `begin_prepare`, aborted at
    once). That covers another preparation, a Frontier window, an open Space stage, an exhausted token or a short
    lease.
- **The removal.**
  - **Publication 1:** WorldRoutes stage-removes every live edge incident to the chain, then seals and publishes.
    Routes refuses an edge an actor holds.
  - **Publication 2:** Locations stage-removes the stations, then seals and publishes. Locations refuses an endpoint
    retained by an actor, a container or an edge.
  - Both run under one cold lease.
- **One chain a tick, and a refusal never stops a dig.**
  - At most one chain is offered a tick: the first idle builder, in dig and crew order, whose column is done.
  - The chain stays offered until it goes. A refusal changes nothing, so each later tick offers it again.
  - A refusal that lasts costs one walk over the edge rows and the resident rows each tick, never a publication. The
    pre-checks are refused first, and retirement is the only thing that publishes here.

### What "no other builder still needs" means

- A builder that is not idle, including one stopped mid-phase, holds its station, every planned leg's endpoint, its
  stands and its haul endpoints.
- Every builder holds its parking and where it stands.
- An idle builder's last station and plan are history. If they name a retired station they are cleared
  (`forget_retired`), and its next cube plans afresh.
- A column's cubes are all worked from its floor station (painted height, decision 1971). So "no unfinished cube
  still needs the chain" is the column being done.
- Another column whose cube could also have used the WORK station republishes a chain. In every probe run the tick
  counts with and without retirement were identical, so this never cost a tick.

### Chains that are never offered (known, bounded)

- A chain whose builder took another cube before the bound was reached. Each such chain is one column's, and only
  those finished below 35 edges.
- The chains of a stopped dig. A failed foreman offers none, and its paid phase keeps its station for the resume.
- The chain of a finished dig's last column, once its record is released. A DONE dig still offers it on the tick it
  finishes.
- Endpoints held only by an owner outside the room runtime's foremen (the entry's chain, or slice C3's waiting
  rooms) are invisible to `holds`. They are never on a room chain's walk: those walks stop at the gateway. This
  needs rechecking when C3 lands.

## 3. Engineering choices

1. **No edit to `underground_locations.gd`.** Decision 1934 §2 planned to admit a second issuer script at
   `_contact_retirement_context_refusal`. The plain path is enough: `begin_prepare` with no owner token,
   `stage_remove`, `seal`, `publish`. The stair path already uses it for a retracted stop. ADR 1191's bracket exists
   for the entry's own paid-scope proof, which a room chain does not need. So slice D's held functions are untouched.
2. **A threshold, not "always".** Retiring every finished chain is safe: in the probes the same rooms dug at the
   same ticks with less wall time. But the coordinator's gate is that rooms which don't need retirement stay
   byte-identical. So retirement waits until the graph's own edge count says the budget is being used up.
   - Half the budget leaves a 2× margin for content and geometry the fixture does not show.
   - The edge count is saved state (Routes' bank), so the decision survives a load. The last proof's spend is not
     saved, so it could not be used.
3. **It runs in the runtime, not the foreman.** "No other builder" includes other rooms' builders, and only the
   runtime sees every dig.
4. **Retiring the fixture's authored first contact.** In the claw Kitchen, the ADR 1161 bootstrap WORK station on
   the access line is the first column's station. It is retired like any other once the bound is reached.
5. **No new state.** Whether a chain is due is recomputed each tick from saved state: Routes' edges, Locations,
   Sites, the foreman's marks and each builder's saved cursor. A saved and restored runtime therefore retires the
   same chains on the same ticks (§4, the parity test).
6. **Planner, choice 2 of the Decision.** The planner's region tables keep treating every room marker as
   nonphysical. That is right for route sweeps, for TRANSIT stations and for extra air boxes, which Locations proves
   on the traversal survey. Only a WORK station with a single box is held to the Site survey's rule. A room that
   digs on master never has a WORK box meeting a foreign claim: publication would have refused it. So master's
   choices are unchanged wherever they published.

## 4. Root causes found: rooms that do not dig to the end on master

The coordinator asked why some rooms fail on master (`ROOM_STATION_GEOMETRY_CLOSED`). There are two causes.

**4.1 Slice C3's two-room case: fixed here.** The case is two Kitchens side by side on the Corridor's east wall,
room A at cells z 0–1 and room B at z 2–3. Room A is stopped after 5 cubes or more.
- Room B's cubes (1,2) and (1,3) then refuse. Stopped after 4 cubes or fewer, room B digs whole.
- The cause is that A's column (0,1) holds a dug void at layer 0. The planner counts it as open air, so for B's
  (1,2) it planned a WORK box at lateral z 2526. That box reaches z 2041, 7 u into A's cell, where A's reservation
  marker stands.
- Publication refused it (`LOCATION_ENVELOPE_BLOCKED`, traced to `_record_obstacles_refusal`, A's marker row). The
  foreman reported its last refusal, GEOMETRY_CLOSED.
- With the fix the planner picks z 2533 and the box starts at z 2048.
- Verified twice: on a scratch copy of C3's work-in-progress tree, where B is dug whole and A's re-order finishes
  for stops after 5, 6, 8, 10, 12 and 15 cubes; and on master's runtime by
  `test_underground_room_foreign_claims.gd`.

**4.2 Rooms not straight out from their access: the remaining gap (P-1942-1).** The room foreman digs every cube
from **one heading**: the access's bound retreat row, +X in the fixture, striking face 0. A chain leaves the gateway,
turns once along the access line, then runs straight along the heading. So a cube can be reached only through its
face toward the access, along a straight line of open space.

Measured under the fixture's 6-row catalog. Under the game's catalog every room over about 100 edges also runs out
of route budget without retirement (§1).

| Room | On master | Why |
|---|---|---|
| 12×4 (12 cells out from the access, 4 along it) | all 192 cubes | every cell is straight out from the Corridor |
| 4×12 | 64 of 192 | cells at z ≥ 4 lie past the Corridor's lateral end (z 4096): no straight line reaches them |
| 7×7 | 112 of 196 | the same, from z ≥ 4 |
| 6×8, 6×12 | 96 | the same |

12×4 against 4×12 is only orientation relative to the access: same claw rows, same fixture.

**Why trying the other three headings is not enough** (measured on cube (0,4) of the 4×12 room, yaw 32768, wall
row 69):
- Content 12 has every row needed at all four yaws: READY forward and backward 43–50, short 51–52 and wall 67–70.
  The game's ground-pace catalog (`qualified-stairs-v10/ground-pace.ugconn`) paces 43–52.
- The work row fits at lateral roots 2463–2594.
- But the turn at the gateway runs on the all-yaw ground row 42, whose body box is about ±712 u square (any
  facing). Swept along x at the access line (z 512), it pokes 200 u past the room's edge into natural earth.
- So a chain on another heading cannot leave the gateway whenever the access lies within about 0.7 m of the room's
  edge, which is the normal case.
- A real fix needs:
  - L-shaped chains: run in on the bound heading's narrow READY rows, turn in place at a station inside dug space
    (its turn air, about 1.4 m square, open), then run on the new heading;
  - mixed-family itineraries (`underground_room_itinerary.gd` links one heading family plus ground);
  - per-leg families in the builder.

**P-1942-1 (coordinator's sequencing call, 2026-10-19): (b).** Close this lane with retirement, the claims fix and
these measurements. Multi-heading digging follows at once in its own lane, `feat/room-multi-heading`. Its
acceptance test is the coverage matrix: 7×7, 4×12, 12×4, a room on each side of its access, an L-shaped room, and
every room type at its minimum size. Until then, a cell no straight chain reaches stops its room with
`ROOM_STATION_GEOMETRY_CLOSED`, as on master. Option (c), a painting rule (rooms only straight out from their
access), was not taken: it conflicts with "paint any room on the grid".

## 5. Proof

The fixture is decision 1939's claw Kitchen (content 12, the claw READY and wall rows, no tool) under the game's
26-row ground-pace catalog, with its room painted larger where needed.

**`test_underground_room_station_retirement.gd`** (slow tier):

| Test | Shows |
|---|---|
| the Kitchen below the bound | peak 20 edges < 35: nothing retired, the graph ends at 20 edges and 11 Locations, as on master |
| due from the bound | `due` at exactly `RETIRE_FROM_EDGES` live edges, not one fewer |
| retiring every chain returns the graph to its start | each chain walked back from a WORK station ends next to the gateway. Retiring all of them leaves the start's edges and Locations, less the fixture's authored first contact |
| a refusal before either publication changes nothing | busy lease; an open Space stage (Locations foreseen: `LOCATION_GEOMETRY_BUSY`); the entry's retirement bracket open; a route actor on the station; empty chain; missing owner. Each leaves edges, Locations and the lease exactly as they were |
| the walk stops at a junction | a TRANSIT station another span leaves from stops the walk, which takes it once the span is gone. A builder parked on a chain station stops it before that station. A WORK station another span leaves from ends no chain |
| **a room past the bound** | 6×4 (96 cubes): dug whole, 17 chains retired, at most 40 live edges, peak 582,956 checks; 18,967 ticks, no refusal, no live Project, no cold lease |
| **the same room without retirement** | dug by its foreman alone: refused at cube 72 with `SPACE_COMPANION_PREPARATION_REFUSED`, 100 live edges, the last proof at 1,044,960 checks (99.7 %). This is master's behaviour |
| two builders | on a level already holding 35 other edges (parallel Corridor spans far from the room): both dig, chains are retired, and after every tick every endpoint any builder names is live |
| stopped after retirements and ordered again | the builder dies earning a paid phase after two retirements, as in decision 1938. The stopped dig keeps the phase and its station, and offers no chain. Re-ordered with another mole, the phase is taken over and the room is finished, retiring chains again |
| restored before every tick | two worlds on a crowded level. A's runtime is saved and restored into a fresh one before every tick while retirement is due. The records match after every tick, and the final graphs and Locations banks are byte-identical |

**`test_underground_room_foreign_claims.gd`** (fast tier):

| Test | Shows |
|---|---|
| C3's two-room case on master's runtime | Kitchen A stopped (its builder dies) while earning its sixth cube. Kitchen B is then dug whole by another mole, and A, re-ordered with that mole, is finished. Every BRACE's wood is paid exactly once (32 × 250) |
| the planner's claim mirror on its own scratch | own room's marker exempt; another room's marker a wall; from the Corridor's section the Kitchen's marker a wall; a room's section over another room's Site refused; a world section exempts nothing; one claimed box is the envelope; two or more are not checked; `_exempt` for room and phase claims |

**Exactness.** The dig benchmark's per-tick SHA-256 trace (`tools/benchmark_dig_tick.gd`, `REDWALL_DIG_TRACE`;
the room loop and the entry run) is **byte-identical** to master `8a7d045d`: 11,453 lines, run on a clean master
worktree and on this branch. The two underground checkpoints were regenerated (not hand-merged). Every save point's
bytes equal master's, and only the source fingerprints moved.

**Mutation testing.** 30 mutants of the new logic were run against the suites that cover them: 20 were killed and
10 survived. The survivors are listed below with the reason each one is acceptable.

| Survivor | Why it is acceptable |
|---|---|
| `chain_into` without the `work == gateway` guard | equivalent here: the gateway is never a live WORK station in any fixture. Kept as a guard |
| the `MAX_CHAIN` overflow clears nothing | unreachable: the planner publishes at most 3 stations, one regateway deep |
| `_names_any` checks the station only | equivalent: an idle builder's legs go through its own chain only, so the station match already decides |
| a working builder's `holds` without its legs | equivalent while chains are trees from the gateway: a path through another chain makes a junction there, which stops the walk |
| `holds` without the parking | equivalent: a parked builder's `_at` is its parking |
| `_column_done` always true | only earlier retirement: the next cube republishes its chain. No wrong state |
| a FAILED dig offers chains | unreachable: a stopped dig's builders are at a paid phase (not idle) or leave in the same tick |
| no DONE shortcut | equivalent in a run: a DONE dig still holds its marks until it is saved; after a load the shortcut is what offers the last chain |
| the claims table ignored (always the owner scan) | same answer, more checks spent |
| floor division truncates | equivalent while every point lies above the domain datum, as the world's do |

## 6. Gates

- **Full CI-style run.** A fresh import exited 0. `./tools/run_tests_parallel.sh` ran 10 shards, 4 at a time, at
  `f0a1814c`: **13,008 tests and 1,500,821 assertions, 0 failures, 0 unexpected errors or warnings, 0 leaked
  objects or resources.** All 548 suite files ran exactly once (CI's verify). Wall time was 1,627 s under a load of
  about 8 from other lanes. The watchdog stopped nothing.
- **Analyzer.** `tools/gdscript_warnings.py --max 0 --port 6437`: 0 warnings in 1,628 files.
- **Contracts.** All 59 CI contract commands pass, including `decision_numbers.py`, `ready07_arithmetic.py`,
  `underground_memory_budget.py --check` with its tests, `test_underground_current_census.py`, `merge_gate.py`,
  the save-registry handoff, the canonical state table and the registry capacity audit.
- **Source pins.** `renew_source_pins.py --check` passes. No pinned source changed.
- **Checkpoints.** Both regenerated with `./tools/regenerate_test_checkpoints.sh`, never hand-merged. Every save
  point's bytes equal master's; only the manifests' source fingerprints moved.
- **Exactness.** The SHA trace is byte-identical to master (§5).
- **Memory (ADR 1212 census).** Retained state is unchanged:
  - the retirement module is stateless, added to the census's `ROOM_STATELESS` list;
  - the foreman and builder gain no members;
  - the runtime gains none.
  - The planner's cold slice grows from 45,752 to 52,664 B (the claimed-row table and its refs), inside the
    existing `Budget.COLD_BYTES` lease, with the census formula and its registry row updated.
  - The memory pack (`docs/planning/underground_memory_pack.json`) is regenerated: **headroom 44,201,316 B**,
    unchanged.
  - Retirement's own transient scratch (a chain of at most 12 ints, the 6-int neighbour list) lives only inside one
    call.
- **Slow tier.** `test_underground_room_station_retirement.gd` (559 s in the full run) is added to
  `godot/test/slow_suites.json`. Both new suites' measured times are added to `tools/ci_test_shard_weights.json`
  for shard balancing. `test_underground_room_foreign_claims.gd` (54 s) stays in the fast tier.
- **Independent review** (code-reviewer subagent). Every HIGH and MEDIUM finding is fixed:
  - **H1.** A refused second publication could orphan TRANSIT stations. Fixed with a trial Locations preparation
    and the entry-bracket check before the graph publication, plus tests.
  - **H2 and M3.** Persistent refusals reran work every tick. Fixed: one chain a tick, and no array literals.
  - **M1.** The claim check scanned the whole owner. Fixed: a claimed-row table filled during `_regions`, checked
    after the footing check.
  - **M2.** The mirror took the Site's room, not the section owner's. Fixed: the section owner decides, a world
    section exempts nothing, and a mismatched Site refuses.
  - **M4.** Test gaps. Fixed with the new holder, junction, bound and mirror tests.
  - **LOW.** Fixed: the gateway guard, the over-long walk taking nothing, and `Query.sites` typed. Recorded rather
    than fixed: the chains never offered (§2) and holders outside the runtime.
- **Locations spend.** Retirement runs its own preparations: a trial `begin_prepare`, then up to 6 `stage_remove`
  calls and a seal. It adds nothing to any phase commit's Locations spend; removing stations lowers it. So slice D's
  M2 measurement (a 91.3 % Locations peak) is not raised by this lane. It runs only from the room runtime, and only
  once 35 edges are live.

## Source

Decisions 1191, 1205, 1207, 1213, 1215, 1229, 1931 (row F), 1933, 1934 §2, 1935, 1937, 1938, 1939, 1951–1953;
`underground_entry_stair_path.gd` `retract`; Space's `snapshot_for_site_into` / `_exempt_claim`; the scratch probe
logs of this lane (not committed).
