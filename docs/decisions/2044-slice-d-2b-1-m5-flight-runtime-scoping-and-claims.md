# 2044 — Slice D phase 2b-1: the M5 flight runtime, scoping and file claims (stopped for the coordinator)

Date: 2026-10-17 · Status: Accepted. Stopped on 2026-10-19 at the check bound (P-2044-15, "Third stop" at the end): steps 2.2–2.8 are built and the live chain reaches module 0's T3. On 2026-10-18 the lane stopped twice at the claim boundary (P-2044-12, then P-2044-13 and P-2044-14); Brendan ruled all three (a) the same day, with a budget-only pre-clearance (see the rulings at the end). Before that: building (P-2044-7 to -11 ruled 2026-10-17; see the rulings at the end). Earlier: Brendan ruled P-2044-1 to P-2044-6, all (a), on 2026-10-17, and
Slice C accepted the claim list. Before any held file was edited, the build's first research pass found that 2b-1
needs files outside the agreed claims (the off-limits entry runtime among them). It also found that P-2044-4 (a) rests
on a miscount. Per the coordinator's rule, the lane stopped: see "Stopped before building" and P-2044-7 to P-2044-11.

Number range: 2044–2049, the D-flight lane's phase 2b. This is the 2b-1 record.
- **Branch:** `feat/slice-d-m5-flight`, cut from `docs/slice-d-flight` with origin/master `4c4fec92` (#272) merged in.
- **Worktree:** `scratchpad/wt-m5`. The analyzer runs on port 6505.

## Brendan's rulings and the claims agreed (2026-10-17)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2044-1 | **(a)**, "Measure, trim, prefilter" | Measure M5 on a scratch mount first; add the `_carry_eligible` edge prefilter only if it overflows |
| P-2044-3 | **(a)**, "Measure, trim, prefilter" | Retain only stop footprints and walk strips under the landings; clip decision 1981's carry floor decks in a data successor, its proofs re-run |
| P-2044-2 | **(a)**, "Raise MAX_BYTES" | One Frontier; `MAX_BYTES` raised to the measured size with a memory-ledger row |
| P-2044-4 | **(a)**, "Approve all" | Plan per stage; `MAX_TASKS` 64 and the save unchanged |
| P-2044-5 | **(a)**, "Approve all" | One 232-part variant and one Placement |
| P-2044-6 | **(a)**, "Approve all" | Reinstate P-1972-8's Locations witness with a never-cut check and a test per guard |

Indexed in `docs/handoff/RULINGS.md`.

**Boundaries agreed with Slice C** (their `perf/phase-spreading`, from `537a9a2e`):

- **Mine:** `underground_world_routes.gd` `_carry_eligible` and any new prefilter helper, plus the files claimed below.
- **Theirs:** the rest of WorldRoutes, all of `underground_routes.gd`, `work.gd`, `excavation_sites.gd`, and the
  phase-start and settlement paths.
- **Hooks:** if spreading needs a hook in the entry foreman, they ask through the coordinator.
- **Off-limits:**
  - the C2 follow-up's four files: `underground_room_world_bindings.gd`, `underground_entry_runtime.gd`,
    `underground_connector_delivery.gd` and `underground_entry_hauler.gd`;
  - the room builder, room foreman and room runtime.
- **Anything else,** the Session included, is reported before it is edited.

**A gate to re-run after their merge.** Once phase-spreading lands, phase preparation spans several ticks, so this
lane's check-peak measurement is re-run against it.

## What 2b-1 is

**The task.** Build the ruled flight, M5, into the runtime: today's qualified 1 m module five times in a straight line,
joined by natural landings (decision 2043 P-2043-1 (a)).

- **Module j** is today's module translated by (0, −1,024j, −5,120j).
- **Module j ≥ 1 has no L0.** Its landing is module j − 1's run-out, natural earth at depth j.
- **Module 4's floor is level 1's floor** (world −4,608).
- **Construction** follows 2043 §3's order. Layer 1 is cut along all 27 rows from land stations. Then, for each
  module, the next layer is cut from the floor above it, starting at the downhill end; the last cube is struck from
  the landing. The module's seven treads are then fitted.

2b-1 takes 1972 "Phase 3b"'s floor-end inventory (built and measured on `a8c4a831`, then removed for content 12's
mount) and applies it at each of five landings:

- the floor stops F, U and F′, and their seven WALK and 21 CARRY edges;
- the natural-landing support (P-1972-7, kept on master);
- the Locations witness for a stop on natural earth (P-1972-8, removed on master as unsafe without a never-cut
  check);
- the floor retention (P-1972-9). Retaining the whole trench needed 161 % of `MAX_CHECKS` at the sill's commit.
- the re-measurement against master's 95.4 % peak (1,000,378 of 1,048,576).

**Out of 2b-1.**

- The earth carry's activation (2b-2, which waits for Slice C's C2 follow-up).
- The C2 follow-up's four files: `underground_room_world_bindings.gd`, `underground_entry_runtime.gd`,
  `underground_connector_delivery.gd` and `underground_entry_hauler.gd`.
- The room builder, foreman and runtime.

## Findings (master `4c4fec92`)

- **G1. Today's bundle, `qualified-stairs-v10`:** 8 assemblies, 52 parts, a 6,716 B Frontier, a 9,152 B structure, 46
  endpoints (`underground_entry_contact_retirement_scope.gd` `ENDPOINTS`). The work area has 19 endpoints and 7 cut
  rows (`underground_entry_work_area.gd:20–22`).
- **G2. The entry runtime needs no edit.** It references no bundle. It composes the foreman through
  `underground_entry_site.gd` and `underground_entry_work_area.gd`. Its finishing alert, `ENTRY_KITCHEN_UNBUILT`
  ("descent to the sill"), only describes what the run built; the wording can stay.
- **G3. The entry foreman is tied to one module.**
  - `Tread.is_tread` (`underground_entry_foreman.gd:759, 857, 892`) assumes today's six-tread geometry.
  - `_publish_sill_edges` publishes the carry edges once the sill is in.
  - Both become per-module.
- **G4. The progress save holds 64 tasks** (`underground_entry_progress.gd:31` `MAX_TASKS`). M5 is 154 cuts and 36
  installs, 190 tasks. The foreman plans by stage today (`configure_installation(paid, k)`), so a plan per module
  stage fits only if no stage exceeds 64:
  - the top metre: 54 cubes plus module 0's 8 installs = 62;
  - layer 2: 40 cubes plus 7 installs = 47.
- **G5. Frontier `MAX_BYTES` is 28,597** (`underground_entry_frontier.gd:28`). The rows are 9, 7, 7 or 19 int32
  words. 154 CUT rows, 3 EPISODE rows a cube, 36 INSTALL rows and the stations and endpoints come to roughly
  40–45 KB (an estimate from v10's 6,716 B for 14 cubes and 8 installs). **That is over.**
- **G6. Catalog parts:** 7 + 5 × 45 = 232, inside `MAX_PARTS` 256 (`underground_connector_catalog.gd:17`) for one
  variant. Two variants (52 and 45 parts) would also fit.
- **G7. `PROFILE_BYTES` does not change.** M5 uses content 12's rows only: the claw stair rows 51–55 and the carry
  rows 71–84. Content 13 is 2b-2.
- **G8. The check bound.** WorldRoutes re-sweeps every live edge's carried certificate against every Space change at
  each preparation (`underground_world_routes.gd` `_carry_eligible` :873 and `_profile_sweeps_clean` :893). The cost
  is about (live edges) × (rows of the edge's kind) × (segments) × (boxes) × (1 + changes).
  - One module's chain already peaks at 95.4 %.
  - M5 brings about five times the stair edges (roughly 250 against 50).
  - The floor walks to the deep stations need retained natural floor under them (G9).
  - Without a cheaper sweep, the later modules' commits will overflow. This must be measured, not assumed.
- **G9. Ground walks on a natural floor need SUPPORT.**
  - WorldRoutes accepts an edge's decks and body cover only on void, the Room's SUPPORT or exterior air (1972 Phase
    2d).
  - A walk on a module's natural floor, to a deep-cut station or from F′ to the next H′, needs that floor retained as
    the Room's SUPPORT. That is the P-1972-9 cost.
  - The carry rows' floor decks (rows 71, 72, 78, 84) reach 5,975 u back under the stair. Decision 1981's tables
    give them the whole bottom fixture slab.

## The file claims (one line a file; "edit" unless marked)

**Data and tools (new files, no claim needed):**

- `godot/data/underground/first-entry-prefix-v1/publish_m5_flight.py` (new): the create-only M5 bundle successor,
  built from `publish_qualified_stairs.py`'s helpers by import.
- `godot/data/underground/first-entry-prefix-v1/qualified-stairs-m5-v1/` (new): the structure, Frontier, recipes,
  workpieces, assemblies, ground paces and accessor.
- `godot/data/underground/full-level-flight-v1/flight_geometry.gd` (mine): M5 dig order and stop helpers.
- If P-2044-3 (a): `stair-carry-v1/` successor tables with floor decks clipped (new files), and the proofs re-run.

**Held runtime files, claimed:**

1. **`scripts/core/underground_entry_stair_path.gd`:** five modules of stops and edges, landing and floor kinds, the
   F/U/F′ plan per landing, and gating per module.
2. **`scripts/core/underground_entry_bindings.gd`:** natural support at each landing; bounded floor retention
   (P-2044-3).
3. **`scripts/core/underground_locations.gd` (`_installed_row_site` only):** the natural-earth stop witness with a
   never-cut check below the floor, and a test for every guard.
4. **`scripts/core/underground_entry_foreman.gd`:** plan per module stage, the bench-down cut order, publishing each
   landing's edges after its sill, and module-aware `is_tread`.
5. **`scripts/core/underground_entry_work_area.gd`:** 27 rows of land stations for the top metre; the deep stations'
   endpoints at depth.
6. **`scripts/core/underground_entry_site.gd`:** the bundle preload; the survey over 27 rows.
7. **`scripts/core/underground_entry_composition.gd`:** the bundle preload.
8. **`scripts/core/underground_route_composition.gd`:** the bundle preload (no new ground paces).
9. **`scripts/core/underground_entry_frontier.gd`:** `MAX_BYTES`, with its ledger row (P-2044-2).
10. **`scripts/core/underground_entry_contact_retirement_scope.gd`:** `ENDPOINTS` and its registry rows.
11. **`scripts/core/underground_entry_progress.gd`:** only if P-2044-4 (b) (a save version bump).
12. **`scripts/core/underground_entry_installer.gd`:** conditional. Fitting T0 from a natural landing instead of L0,
    if its station rules assume L0's deck.
13. **`scripts/core/underground_connector_contacts.gd`:** conditional. Deep cut stations on a floor at depth, if the
    Frontier's station rows need more than data.
14. **`scripts/core/underground_world_routes.gd`:** see the next section.
15. **`data/underground/runtime_files.gd`:** the bundle paths.
16. **Census, memory pack, `docs/systems_architecture.md` ledger rows, the two ADR 1240 checkpoints, pins and the
    registry rows:** one pass at the end.
17. **`docs/building_model_amendment.md` §9:** the pending M5 amendment (decision 2041).

**Not claimed:**

- `underground_routes.gd`;
- `underground_profiles.gd`;
- `underground_stair_motion.gd` (content 12's tables serve M5 unchanged);
- `underground_connector_catalog.gd` (232 parts fit);
- `underground_connector_placements.gd`;
- `underground_session.gd` (to be confirmed when the mount is tried; any need comes back as a claim);
- the C2 follow-up's four files.

## Routes and WorldRoutes: the answer for Slice C

- **`underground_routes.gd`: no.**
- **`underground_world_routes.gd`: probably yes, in `_carry_eligible` only, plus one new private helper.** The need is
  confirmed first by measurement (P-2044-1).
  - **The change:** an edge-bound prefilter. Before the per-profile loop, test the edge's whole swept bound (its path
    hull widened by the largest certified profile extent) against the changes since its certificate. When none
    meets it, the edge is carried with O(changes) work.
  - **The cost model** becomes O(edges × changes) instead of O(edges × profiles × segments × boxes × changes).
  - **What it touches:** nothing else in WorldRoutes. No change to `_profile_sweeps_clean`, the seal or the published
    certificates.
- **Order.** The phase-spreading lane may proceed in Routes. In WorldRoutes it should avoid `_carry_eligible`, or the
  two lanes agree on an order.

## Entry foreman and entry runtime

- **Entry foreman: yes, claimed** (item 4).
- **Entry runtime: no** (G2). A need found later would come as a proposal, because the runtime is the C2 follow-up's.

## Capacity plan

| Bound | Today | M5 | Plan |
|---|---|---|---|
| `Space.MAX_CHECKS` (1,048,576) | 95.4 % peak | unmeasured; scales with live edges and retained rows (G8, G9) | P-2044-1 and P-2044-3; no raise without a ruling |
| Frontier `MAX_BYTES` (28,597) | 6,716 B | about 40–45 KB, estimated | P-2044-2 |
| Catalog `MAX_PARTS` (256) | 52 | 232 | fits; one variant (P-2044-5) |
| `PROFILE_BYTES` (282,624) | content 12 | unchanged | none in 2b-1 |
| Progress `MAX_TASKS` (64) | 8 installs + 14 cuts | 190 tasks | per-stage planning, at most 62 a stage (P-2044-4) |
| Retirement `ENDPOINTS` | 46 | about 5 × 46, measured | a census row |
| Routes `MAX_EDGES` 1,536, Locations 4,096 | about 70 edges | about 350 | fits |

## Proposals

**P-2044-1 — Making the check bound hold for five modules (WorldRoutes).**

- **(a) Measure M5 on a scratch mount first. If it overflows, add the edge-bound prefilter in `_carry_eligible` (the
  one cleared function), with tests, and re-measure.**
- (b) Raise `Space.MAX_CHECKS`. This is a budget ruling.
- (c) Retire each finished module's work-area edges and station endpoints as the next module starts, to cut the live
  edges (the ADR 1202 option 3 pattern). It helps but does not bound the stair's own edges.

**Recommendation: (a).**

**P-2044-2 — Frontier bytes.**

- **(a) One Frontier for the whole M5, with `MAX_BYTES` raised to the measured size and a ledger row (ADR 1212).
  About 15 KB more against 44 MB of headroom.**
- (b) Per-module Frontiers chained by the foreman (P-DF-8 (c)). This needs no raise, but it adds five bundles' worth of
  digests and a Frontier switch in the foreman.
- (c) Drop EPISODE rows for the deep cubes and derive their phases. This changes the Frontier format.

**Recommendation: (a).**

**P-2044-3 — Natural support under the landings and floors.**

- **(a) Retain only what each stop and walk stands on: each landing's stop footprints, and the floor strip of the
  walk to the next H′ and to the deep stations. Clip decision 1981's carry floor decks to the floor its proofs stood
  on, as a data successor with the proofs re-run (1972 Phase 3a option (a)).**
- (b) Retain each module's whole floor (P-1972-9 as built), relying on P-2044-1's prefilter to absorb the sweep
  cost.
- (c) Retain whole floors and raise `MAX_CHECKS`.

**Recommendation: (a), measured; fall back to (b) if the clipped decks fail their proofs.**

**P-2044-4 — Progress tasks.**

- **(a) Keep `MAX_TASKS` 64 and plan per module stage. No stage exceeds 62 tasks, and there is no save change.**
- (b) Raise `MAX_TASKS` and the save version.

**Recommendation: (a).**

**P-2044-5 — One variant or two.**

- **(a) One 232-part variant and one Placement for the whole flight. The stair path, foreman and bindings see one
  Placement, and the Frontier is one (P-2044-2 (a)).**
- (b) Two variants (the first module, 52 parts; a middle module, 45 parts), placed five times. Each runtime piece
  then learns several Placements.

**Recommendation: (a).**

**P-2044-6 — The Locations witness (P-1972-8 reinstated).**

- **(a) Reinstate it with a never-cut check on the earth under the stop's floor (Sites' history of that cube) and a
  test for each guard: wrong phase, foreign Room, a point off the cube's floor, earth below cut.**
- (b) Witness natural-floor stops through retained SUPPORT rows instead of Sites. This costs rows (G9).

**Recommendation: (a).**

## Order after the claims are confirmed

1. The bundle and its tests (new files).
2. The stair path, bindings and Locations witness, with fixtures.
3. The foreman per module.
4. A scratch mount and the M-2 measurement.
5. P-2044-1's prefilter only if the measurement needs it.
6. The census, checkpoints and pins.
7. The live chain to level 1's floor, with exact ledgers (2043 §3: 154 Sites, 36 installs, wood 77,500, stone
   38,500, 912,620 milli-WU).
8. Gates: the full suite CI-style, the analyzer on port 6505, mutation testing, an independent review, frames.

## Stopped before building (2026-10-17)

A read-only research pass over the entry pipeline on master `537a9a2e`, checked line by line where load-bearing,
found the following. **No held file was edited.**

### Corrections to this record

- **G4 / P-2044-4 is wrong: a cube is three tasks, not one.** The foreman plans one Task per phase (BRACE, CUT,
  FINISH), and the census counts them so: `tools/underground_current_census.py:308`,
  `tasks = 3 * EPISODE + INSTALL`.
  - The top-metre stage is therefore about 48 × 3 = 144 tasks, and layer 2 is 40 × 3 + 7 = 127. Both are well over
    `Progress.MAX_TASKS` 64 (`underground_entry_progress.gd:31`).
  - Restoring a save also requires every future task's station Location to be live (`underground_entry_foreman.gd`
    `_task_refusal`). That rules out planning deep stations ahead.
  - **P-2044-4 (a), as ruled, cannot hold.** It is re-asked as P-2044-8.
- **G5: one EPISODE row per cube,** and stations and endpoints are larger than estimated. The Frontier is about
  49 KB, not 40–45 KB. P-2044-2 (a) still applies.
- **Capacity table: Locations capacity is 1,024** (`underground_budget.gd:12`), not 4,096. M5 needs about 280 for the
  entry, shared with rooms. It fits.
- **Claim 5: WorkArea cannot publish deep stations,** and claims 12 (installer) and 13 (Contacts) are required, not
  conditional:
  - a station at depth cannot be a surface kind;
  - Contacts' phase mode proves single-profile reach only, and refuses across a stair.

### Needs outside the agreed claims

1. **The entry runtime** (`underground_entry_runtime.gd`, the C2 follow-up's).
   - It plans the whole prefix up front for `INSTALLATIONS = 8` (`:34, :366-367`). Its `_station_paths` assumes one
     deep batch of land stations (`:379-391`).
   - The foreman cannot add stages later: `configure_installation` refuses unless the stage is OPEN at index 0
     (`underground_entry_foreman.gd:751`).
   - So M5's 36 installs and staged planning need the runtime changed.
2. **Data certificates that know only today's module:**
   - `qualified-claw-runtime-v2/tread_geometry.gd`: `is_tread` covers assemblies 2–7, and its station and bearer
     rules are linear.
   - `qualified-claw-runtime-v2/paw_physical_certificate.gd`: it dispatches on `Tread.is_tread`.
   - `qualified-assembly-v1/physical_certificate.gd` and `source_program.gd`: they accept only assemblies 0 and 1,
     with hard-coded L0 and T0 roots and exterior air for the body.
   - Module j's T0 and treads are refused by all four.
3. **The confirmation budget** (`underground_entry_bindings.gd`, claimed).
   - `_entry_cut_set_refusal` charges `17 + EPISODES × 32` checks per cube (`:378`), and the natural bearings
     `EPISODES × 32` each (`:479-480`).
   - For M5's 154 cubes and about 150 bearings that is about 1.5 M checks, over the 1,048,576 budget, so confirmation
     would refuse.
   - The fix is within a claimed file, but it changes a proof's cost model.
4. **An unverified physical question in unclaimed code** (Sites, the space owner). Can a paid cut take a cube that
   holds its own Room's retained SUPPORT? Floor stations and their strips stand over cubes that are cut later, so
   their Locations and SUPPORT must be retired first.
5. **Not needed:** `underground_connector_delivery.gd`, `underground_room_world_bindings.gd`, the Session,
   `underground_routes.gd` and the rest of WorldRoutes. Spoil keeps going to R's pile: ECON-003's "adjacent" rule is
   not enforced for entry cuts anywhere, and M5's 308 U fits R at 77 % of a pile.

**Motion:** nothing found makes M5 infeasible with qualified motion. Rows 56/58/60/62 exist at all four headings.
The blockers are runtime and certificate generality.

### Proposals

**P-2044-7 — The entry runtime (for the coordinator with the C2 follow-up lane).**

- **(a) A narrow, cleared edit in this lane.** `INSTALLATIONS` read from the mounted Frontier, and planning moved to
  the foreman stage by stage (the runtime asks for the next stage when one finishes). `_station_paths` takes the
  stage's batch. These are a few functions, in an order agreed with C2.
- (b) The C2 follow-up lane makes the same edit, and 2b-1 waits for it.
- (c) Keep the up-front plan and raise every bound it meets instead: tasks, endpoints, legs and the confirmation
  budget. This is the largest change, with the most memory.

**Recommendation: (a).**

**P-2044-8 — Progress tasks (re-asks P-2044-4).**

- **(a) Raise `MAX_TASKS` (to 160 at least, the largest stage's 144 plus margin), `MAX_ENDPOINTS` (59 land
  endpoints) and `MAX_LEGS`, bump the save version to 4, and add census rows.** The hauler reads `MAX_LEGS` through
  the shared constant, so the off-limits hauler file itself does not change.
- (b) Sub-stages of at most 21 cubes inside the foreman, with no save change. That is about eight sub-stages for the
  top metre, each with its stations live at its own plan time.
- (c) Both.

**Recommendation: (a).** The ruled (a) does not hold.

**P-2044-9 — The module-blind certificates.**

- **(a) New successor files that are module-aware** (a `tread_geometry` successor reading
  `full-level-flight-v1/flight_geometry.gd`, and paw/assembly certificate successors for module T0s), wired from the
  claimed foreman, Contacts and bindings. The published files stay as they are.
- (b) Claim the four files and edit them in place.

**Recommendation: (a).**

**P-2044-10 — The confirmation budget.**

- **(a) In `underground_entry_bindings.gd` (claimed), index the episodes by cube once, so each cube costs
  O(log EPISODES) instead of O(EPISODES).** Re-measure.
- (b) Confirm M5 module by module, as separate Placement stages. That needs P-2044-5 re-ruled.
- (c) Raise the entry check budget.

**Recommendation: (a).**

**P-2044-11 — Floor stations over cubes still to be cut.**

- **(a) Before building, prove on a fixture that retiring a station's Location, its strip SUPPORT and its edges
  frees the cube below for its own Room's cut. If Sites or the space owner refuses, report it.**
- (b) Stand every deep station only on floors that are never cut later. Each cube is then struck from the landing
  side through longer walks, which is not possible for every cube.

**Recommendation: (a).**

### What this means for 2b-1

2b-1 is larger than 2044 scoped:

- the runtime (P-2044-7);
- four certificates (P-2044-9);
- Contacts and the installer (required);
- the progress format (P-2044-8);
- the confirmation cost (P-2044-10);
- a physical question in Sites (P-2044-11).

The lane has stopped for the coordinator and Brendan. Nothing was built; the claims of record stand unused.

## Brendan's rulings on the stop proposals (2026-10-17)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion. Every ruling is the recommended option.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2044-7 | **(a)**, "Narrow edit here, ordered" | This lane edits `underground_entry_runtime.gd` for three things only: `INSTALLATIONS` read from the Frontier, planning stage by stage, and `_station_paths` per batch. **Not yet.** The coordinator is agreeing the order with Slice C (default: their C2 follow-up merges first), and the runtime edit is the build's small last step |
| P-2044-8 | **(a)**, "Raise to 160, save v4" | `MAX_TASKS` to at least 160, plus `MAX_ENDPOINTS` and `MAX_LEGS`, with the entry-progress save at version 4 and census rows. **This replaces P-2044-4 (a)**, whose premise (one task per cube) was wrong |
| P-2044-9 | **(a)** | New module-aware successor files for `tread_geometry`, `paw_physical_certificate`, `qualified-assembly-v1/physical_certificate` and `source_program`, wired from the claimed foreman, Contacts and bindings; the originals are not edited |
| P-2044-10 | **(a)** | Episodes indexed by cube once in `underground_entry_bindings.gd`, then re-measured |
| P-2044-11 | **(a)** | A fixture first proves that retiring a station's Location, support strip and edges frees the cube below for its own Room's cut. The floor stations are built on it only if it passes; otherwise the lane stops and reports |

**Claims now:** this record's list, plus the successor files. Contacts, the installer and
`underground_entry_progress.gd` are now required, not conditional. Boundaries otherwise unchanged: no Delivery, no
room world bindings, no Session, no Routes, and in WorldRoutes only `_carry_eligible`. Indexed in
`docs/handoff/RULINGS.md`.

### Order with Slice C, and the follow-ons (2026-10-17, from the coordinator)

**The entry runtime.**

- Slice C's C2 follow-up, PR #273 (`feat/room-dig-followups`), merges first.
- It adds hunks to `underground_entry_runtime.gd` around start, advance, `owns_job` and `_read_foreman`, and two
  refusal constants. It touches neither `INSTALLATIONS`, nor the planning loop, nor `_station_paths`.
- P-2044-7's three-part edit lands on top of it, when the coordinator says so.
- #273 adds no save field, so the progress move to version 4 has no ordering constraint.
- If the files #273 regenerates conflict, they are regenerated, never hand-merged: the memory pack and the two ADR
  1240 checkpoints.

**Follow-ons after 2b-1:**

- **2b-2:** the earth carry's activation.
- **Stair-leg Delivery** (decision 1941 §2; Brendan ruled P-1941-1 (b), "Wait for M5"). It is built once, against
  M5's real flight. Until then `ROOM_HAUL_NO_STAIR_CARRY` stays raised on every live level, so **D2 and C3 depend on
  it too.**
- **D2:** the connector bound to the room-dig runtime.


## Build restarted, then stopped at the claim boundary again (2026-10-18)

The previous build agent was stopped by a usage limit before committing code. A fresh agent restarted the build on
2026-10-18 from the coordinator's brief.

**Done:**

- `origin/master` (`9440b9d1`, #273) merged (`0acc7262`). Only `docs/handoff/RULINGS.md` conflicted; both sides were
  kept. The memory pack and the two ADR 1240 checkpoints merged cleanly.
- **P-2044-11, the fixture proof: passes at the owner level.** `godot/test/test_underground_m5_station_retirement.gd`,
  5 tests, 61 assertions, 0 failures, 0 diagnostics, 0 leaks. Two real-owner fixtures are reused as helpers:
  - the paid cycle (`test_underground_space_authority.gd`: the real Space owner, Space authority, Sites,
    Construction, Inventory and Work around one claimed Room cube);
  - the endpoint layer (`test_underground_work_face.gd`'s level-1 corridor: the real Locations, Routes, WorldRoutes
    and Sites over the Room's SUPPORT strip, the floor a station stands on).
- **What the proof shows:**
  - A live Room SUPPORT strip in the cube's work reach refuses its paid BRACE when it opens
    (`SPACE_WORK_CONTACT_OBSTRUCTED`), and nothing moves or is spent.
  - Once the strip is retired, BRACE, CUT and FINISH all complete for the cube's own Room. The cube ends as its
    supported void, with no SUPPORT left in it and one cube of earth out.
  - A strip clear of the reach is not refused, but the cut leaves it standing inside the dug void (SUPPORT over
    nothing). So retirement must come first and is never left to the cut.
  - A station retires in a fixed order:
    - its route edge first (Locations refuses `LOCATION_ROUTE_RETAINED` while an edge names it);
    - then its Location;
    - then the strip under it.

    The neighbouring station, on the strip outside the cube, still proves its footing. A station left on a retired
    strip refuses `LOCATION_COVERAGE_MISSING`.

So Sites and the Space owner do not refuse the cut once the station is retired. **But no claimed file can retire the
strip in the running game.** Per the coordinator's rule, the lane stopped here. No held file has been edited.

### Why the strip's retirement needs an unclaimed file

1. **Every entry phase refuses a cube that a claim-free SUPPORT row overlaps.**
   - Every phase's preparation (`underground_space_authority.gd:838`) calls the World bindings'
     `stage_physical_geometry`.
   - For the entry that reaches `underground_entry_structure.gd` `_walk_claims`, which returns `REFUSE_PROTECTED`
     (`STRUCTURE_NEIGHBOR_PROTECTION`, `:158`) for any claim-free SUPPORT meeting the paid cube. It does so in the
     STAGE and PREPARED passes alike, whatever the reach.
   - A station's strip lies in the cube under it. So the strip must be gone before that cube's first phase opens.
2. **A strip can only be removed by a Space transaction that also refreshes Locations and WorldRoutes.**
   - Routes accepts an edge or an endpoint only at the current Space revision: `_path_edge_current`
     (`underground_routes.gd:1871`), `_profile_endpoint_refusal` and `at_contact_refusal`
     (`ROUTE_CONTACT_GEOMETRY_STALE`).
   - A bare Space publish would therefore stale every edge and Location, and stop all movement until the next
     requalification.
   - The issuers that publish with that refresh are:
     - the Space authority's paid phases. Their companion is Placements' phase refresh, which refreshes only
       (`underground_connector_placements.gd:1911, 1928`; Locations refuses removals in a phase,
       `LOCATION_ROOM_REFRESH_ONLY`, `underground_locations.gd:1733`);
     - Placements' installations, through `underground_entry_bindings.gd` (claimed);
     - room orders;
     - the World publisher.
3. **Layer j + 1's stations stand on floors cut in the same stage, between installations.**
   - 2043 §3 strikes each cube from its uphill neighbour at depth j. The stations in rows 2 + 5j to 25 stand over
     cubes that the same stage cuts next. Only the landing row's station does not.
   - No installation runs mid-stage, so the only transaction that could carry the removal is a paid phase. That
     needs `underground_entry_structure.gd` or `underground_space_authority.gd`, or a new Placements transaction.
     None is claimed.
   - There is no qualified alternative to the order. A strike from the deeper floor needs a way down that does not
     exist before the module's treads (2043 F2).
4. **Not affected:**
   - F, U and F′ and every natural landing: each stands on module j − 1's run-out, which is never deepened;
   - the posts' natural bearings: they lie in layer j + 2 under module j's rows, which are never cut.

   Only the deep cut stations and the floor walks to them are affected.

### P-2044-12 — Retiring a deep station's strip mid-stage (for the coordinator and Brendan)

- **(a) Clear `underground_entry_structure.gd` for one STAGE hook, and `underground_entry_frontier.gd` for the data
  it reads.**
  - At an episode's BRACE START, the Space candidate also removes the Room's station strips that the Frontier marks
    as retired by that episode.
  - Each strip is retired by the BRACE START of the cube cut just before the cube under it, whose reach never meets
    it.
  - The station's edges and Location retire just before, through their own preparations (proved above).
  - The phase's own refresh then re-proves every Location and edge against the candidate.
  - About 40 lines in the structure, plus the Frontier's parser for the new field (a format change).
- (b) A new station-retirement transaction in `underground_connector_placements.gd`, issued by the foreman. It
  removes a station's edges, its Location and its strip under one Space, Locations and Routes publication, as an
  installation does. This is a new transaction kind of several hundred lines, with its own proofs.
- (c) Keep M5 to what needs no mid-stage retirement: the top metre, module 0 and the floor stops at landing 1. That
  does not reach level 1.

**Recommendation: (a).** It rides on the phase transaction that already refreshes everything, and adds no new
publication path.

### A gate to re-run later

Whatever is built, **the check-peak measurement (P-2044-1) must be re-run once Slice C's `perf/phase-spreading`
merges**, because phase preparation then spans several ticks (see "Brendan's rulings and the claims agreed").

## Brendan's ruling on P-2044-12 (2026-10-18)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2044-12 | **(a)**, "Small hook in entry structure" | `underground_entry_structure.gd` is cleared for this lane, for one hook of about 40 lines and nothing else: when a cube's BRACE starts, the hook removes the support strip the Frontier marks for retirement, on the cube cut just before the cube under it, whose reach never meets that strip. `underground_entry_frontier.gd`'s parser gains the one new data field; that is a format change, recorded in the census and the memory ledger |

Slice C was told of the claim. Indexed in `docs/handoff/RULINGS.md`. The build resumes at step 2.2 of the brief
(P-2044-9), with the hook added where it fits.

## Second stop after P-2044-12: two more files outside the claims (2026-10-18)

After the P-2044-12 ruling, the build resumed with a design pass over every piece of the runtime before writing
code. The aim was to find every file outside the claims at once, rather than one at a time. Two were found. No file
outside the claims was edited.

### The design the pass settled (within the claims)

- **Deep stations.** For layer j + 1, station S(r, c) stands on row r's floor at depth j and strikes cube
  (r + 1, c)'s top face with claw dig row 56 (yaw 0). Its contact point (224, 0, −544) lands 138 u inside the cube.
  - Placement: x = −512 for column 0 and +400 for column 1; z = −1024(r + 1) + 406. Travel is on the narrow approach
    row 43.
  - Row 56's and row 43's bodies then stay inside the 2 m slot, and their stances inside the station's own column.
- **The floor graph.** A spine runs down column 1 (S(r, 1) ↔ S(r + 1, 1)), with one crossing per row
  (S(r, 0) ↔ S(r, 1)). The cut order is row-major from the end wall: (26, 0), (26, 1), (25, 0), (25, 1), and so on.
- **When each strip retires (P-2044-12's hook fits this order exactly):**
  - cube (r, 0)'s strips (its station and its half of the crossing) are retired by (r + 1, 1)'s BRACE start;
  - cube (r, 1)'s strips (its station, its half of the crossing and the spine through row r) are retired by
    (r, 0)'s BRACE start.

  In each case the crew has already left the station, its edges and Location have retired, and the retiring cube's
  reach never meets the strip. That reach lies above its own floor, as `_entry_contact_bounds` builds it. The
  landing row's stations are never undermined and keep their strips.
- **The Frontier data field.** A third BEARING kind, a strip. Its field 1 names the episode whose BRACE start
  retires it, and the row size is unchanged. The bindings retain strips at the previous sill's commit; the entry
  structure's hook removes them.
- **Material and spoil for deep cubes.** A stage's brace inputs are hauled to M once, at the surface, when the stage
  starts. Each deep phase then only claims stock at M. Contacts proves the station's reach to M and R across the
  stair leg by leg, as it already does for tread stations (Contacts is claimed).

### P-2044-13 — The handling dispatch (`qualified-claw-runtime-v1/handling_programs.gd`, not claimed)

- Every assembly-specific handling proof reaches the paw certificate through this one data file's content-keyed
  dispatch: the Workpieces' load-time part check (`underground_connector_workpieces.gd:466`), Routes, WorldRoutes
  and Contacts.
- For content 12 it calls `qualified-claw-runtime-v2/paw_physical_certificate.gd`, whose `Tread.is_tread` covers
  assemblies 2–7. Anything else falls through to the pick certificate, which accepts assemblies 0 and 1 only.
- So the 232-part M5 bundle's workpieces for modules 1–4 (assemblies 8–35) are refused when the bundle loads, and the
  bundle cannot mount.
- P-2044-9's successor certificates are new files, but nothing in the claims can route to them: Routes, WorldRoutes
  and Workpieces all preload this dispatch.

Options:

- **(a) Clear `handling_programs.gd` for one change.** Its content-12 paw certificate (`PawPhysical10`) points at the
  new module-aware successor. The successor delegates assemblies 0–7 to the published v2 certificate unchanged, so
  today's entry behaves byte for byte as before, and adds module j's T0–T6 (module-translated stations, bearers and
  part transforms).
- (b) A successor dispatch file, with its preload switched in Routes, WorldRoutes, Workpieces, Contacts and the
  presentation. This needs off-limits files.
- (c) Re-rule P-2044-5 to two variants placed five times, so every Placement's assemblies stay 0–7. Every runtime
  owner then has to handle several Placements, which is a far larger change.

**Recommendation: (a).**

### P-2044-14 — Clipped floor decks need the stair motion owner (off-limits)

- P-2044-3 (a) asked for decision 1981's carry floor decks to be clipped in a data successor. Those decks are the
  stair-carry tables' decks, read by WorldRoutes through the stair motion owner.
- `underground_stair_motion.gd` `load_carry_file` refuses any wire but the one its own pins name
  (`expected_sha != CarryPins.WIRE_SHA`). A successor table can therefore never be loaded without editing the stair
  motion owner, which is off-limits.

Options:

- **(a) Leave the carry tables as they are.**
  - On M5's floors, publish no edges on rows 71/72 or the loaded walk-off/back-up rows.
  - Between modules, walk on qualified ground rows over retained walk strips. Each landing stop is joined like L0's:
    F → P′ on the narrow approach 43, and U0′ → U on the approach 45.
  - The floor walk-off, back-up and floor CARRY edges then wait for stair-leg Delivery (decision 1941 §2), which is
    built on M5 anyway.
  - P-2044-3's "retain only stop footprints and walk strips" holds, and no clipped successor is needed in 2b-1.
  - F′ (the walk-off's end) has no edge until then.
- (b) Clear `underground_stair_motion.gd` to load a clipped successor of the carry tables.
- (c) P-2044-3 (b): retain each module's whole floor (never undermined, since each module stops at its own depth),
  and rely on P-2044-1's prefilter for the check bound.

**Recommendation: (a).** It needs no new claim and defers only what stair-leg Delivery will rebuild.

### What was not found

The pass found no other file outside the claims. Session, Placements, ConnectorWork, the entry plan, the cut map and
Sites read no tread or module geometry. Locations, Contacts, the installer, the bindings, the structure hook, the
foreman, the runtime, the work area, the site, the compositions and the census are claimed. One file remains
unproved until the mount runs: `underground_entry_world_bindings.gd`'s per-phase episode lookup budget with 154
episodes.

## Brendan's rulings on P-2044-13 and P-2044-14 (2026-10-18)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion. Every ruling is the recommended option.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2044-13 | **(a)**, "One change to the dispatch" | `qualified-claw-runtime-v1/handling_programs.gd` is cleared for one change only: content 12's tread certificate points at a new module-aware successor, which hands assemblies 0–7 to today's certificate unchanged. A test proves today's entry behaves byte for byte as before |
| P-2044-14 | **(a)**, "Keep tables, defer floor carry" | Today's stair-carry tables stay. On M5's floors no edge uses rows 71/72 or the loaded walk-off and back-up rows. Each landing is joined on qualified ground rows over retained walk strips: F → P′ on row 43, U0′ → U on row 45. F′ stands with no edge |
| Pre-clearance | **"Yes, budget only"** | If measurement shows `underground_entry_world_bindings.gd`'s per-phase episode lookup budget is short for 154 episodes, that one budget constant may be raised, with a memory-ledger row and a test. Any other edit to that file, or to any other file outside the claims, still stops the lane |

**P-2044-14 supersedes P-2044-3's deck clipping.** P-2044-3 (a) asked for decision 1981's carry floor decks to be
clipped in a data successor. That successor cannot load without the off-limits stair motion owner, so no clipped
tables are published. P-2044-3's other half stands: only stop footprints and walk strips are retained as support.

**What stair-leg Delivery (decision 1941 §2) inherits.** It is built once, on M5. It also takes over what 2b-1 now
leaves out:

- the floor walk-off and back-up edges (rows 71 and 72, F ↔ F′) at each landing;
- the loaded walk-off and back-up on the floors (the approach and back-up rows 73/78 and 79/84 used at a floor);
- with them, the deck question: those rows' floor decks reach about 5,975 u back under the stair. They need either
  that floor retained as the Room's support (each module's floor is never dug deeper, so retaining it is safe, but
  it costs check budget) or clipped tables, which needs the stair motion owner cleared.

Indexed in `docs/handoff/RULINGS.md`.

## Third stop: M5 does not fit one cold-operation check bound (2026-10-19)

Steps 2.2–2.8 were built (commits `5a056fcd`, `1959cf98`): the stair path for five modules and their floor stops,
foreman stage-by-stage planning, the bindings cube index and strip staging, the Locations natural-floor witness with
its four guard tests (P-2044-6), Contacts reach for landings and deep stations, the entry-structure strip hook
(P-2044-12), the work area for 27 rows, and progress v4. The live chain was then driven on a scratch mount
(`test_zz_m5_scratch_chain.gd`, not committed; it tops up R's staged stock and holds the crew's needs full, so only
the build is measured). Every refusal it met was measured and either fixed inside the claims or is listed below.

### Fixed inside the claims (measured on the mount)

| Where | Measured | Fix | After |
|---|---|---|---|
| SurfaceAnchor, publishing the 59 work-area endpoints | each create refreshes every endpoint; all cut stations shared one full-length footing strip, so each create cost 56,902 more per earlier same-side station; endpoint 21 hit 1,048,576 | `WorkArea.foot`: a cut station after the first pair stands on its own row's slice of the strip | every cut station 579,449; the peak is a haul stand's 807,057 |
| Entry bindings cube index (P-2044-10) | the key's x field sat at bit 62, so `key << 3` overflowed and every lookup missed (`ENTRY_EXACT_CUT_SET_REQUIRED`) | 18-bit fields; a test checks the shift at the Domain's corners | found |
| Confirmation, 58 surface contacts | 832,342 checks: each paid a full source scan (8,448) and full terrain windows | the section's source scan is charged in full only while Locations' resolution hint is cold; a terrain window is charged 16 a tile read plus one (`LOCAL_QUERY_CHECKS` is that for a full 8×8 window) | preflight 288,520; the final recheck leaves 506,249 |
| WorldRoutes preparations at L0's and T0's completion | 982,994, then over 1,048,576: sixteen paths to cut stations whose cuts were done were requalified | the surface cut stations are batches 0 ({3,4,5,6}) and 1 ({7,8}) of `WorkArea`, retired by the runtime's existing per-batch rule when a later step starts with the crew off them; `WORK` publishes H and batch 0 only | 603,622 and 692,536; the initial publication 743,438 |
| Timber proofs' terrain windows | the same flat per-window charge | charged by tiles read, as the confirmation | — |

### Deviation recorded: strip retirement

P-2044-12's ruling text has a strip "retired by the BRACE START of the cube cut just before the cube under it". The
turning stance spills behind every station, so no earlier cube's reach is clear of the strip it would retire; the
strip is retired at the BRACE START of the episode its Frontier row names, which is the row's own first cube (column
0), directly under the strip. That BRACE's reach never goes below the floor, so it never meets the strip it retires
(the P-2044-11 proof, `test_underground_m5_station_retirement.gd`). The publisher test
`test_every_deep_strip_is_retired_by_its_rows_first_cube` pins this.

### Where it stops: three cold operations past `Space.MAX_CHECKS`

The chain reaches module 0's stage 2 (all 150 tasks of prefix 2 planned, every top-metre and deep cut of module 0
done, T1 and T2 installed) and stops at T3's installation, tick 34,174. Three separate bounds are reached, each one
`Space.MAX_CHECKS` (1,048,576) per operation:

1. **The timber installation (entry bindings).** T0's operation spends 210,000 on its preflight, 408,000 staging
   (40,000 a part: two scans of all 6,144 Space region slots per part) and then re-checks the operation scope
   (`TIMBER_SCOPE_CHECKS`, 2,048) after every refreshed Location (120 → 245,760) and every refreshed edge
   (48 → 98,304). Its final proof is then short by 2,000. Both counts grow with every module. Scratch only (not
   committed): with that charge at 256 the chain went on to T3.
2. **WorldRoutes requalification.** A carried edge still compiles every profile's segment sweep against every
   image volume; the volumes grew from 74–79 on master to 313 by module 0's stage 2. A carried edge now costs
   13,000–30,000 (eligibility about 5,700 of it). T1's completion used **985,830 (94.0 %)** with 35 edges and none
   recompiled. Module 0 ends with about 68 live edges and module 4 with about 216, so the projection is about
   1.4 M at module 0's end and several million by module 4. The cleared prefilter in `_carry_eligible` removes only
   the eligibility share; the compile sweep is outside it.
3. **Locations' witness pass.** At T3's completion, `_derive_witnesses` (from `prepared_installation_leaf_refusal`)
   ran out of the same operation's `_remaining` (`LOCATION_OPERATION_BUDGET`) with 71 live Locations.

P-2044-1 (a) was "measure, then prefilter only if it overflows". It overflows, and the prefilter cannot close it:
the growth is in the carried compile, the Locations witness pass and the bindings' per-row scope charge, none of
which is the cleared function.

### P-2044-15 — The check bound for M5 (for the coordinator and Brendan)

- **(a) Budget: raise `Space.MAX_CHECKS` (`room_space.gd`).** Simplest; not a frame budget by its own comment, but
  every installation and phase runs inside one tick, so a raised bound is a longer hitch. The figure needs a
  measurement with the raise (the projection is several million by module 4).
- **(b) Cost model: make the bounded work scale with what changed.** Slice C's WorldRoutes lets a carried edge
  skip the per-profile segment sweep when the swept hull misses every change (2044's stated cost model, which needs
  `_compile_profiles`/`_profile_edge_refusal`, outside `_carry_eligible`); this lane charges the bindings' scope
  re-check once per refresh loop rather than per row and scans only present region rows; Locations' witness pass
  is charged by records rather than by the whole operation's remainder. Each needs its own clearance.
- **(c) Scope: build fewer modules in 2b-1** (for example M2: the surface to landing 2) inside today's bound, and
  take the rest when (b) lands.

**Recommendation: (b), with (c) as the interim deliverable if (b) cannot be scheduled now.** (a) alone moves the
cost into frame hitches that grow with every module.
