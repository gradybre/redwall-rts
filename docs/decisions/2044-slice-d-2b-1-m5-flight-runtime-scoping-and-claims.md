# 2044 — Slice D phase 2b-1: the M5 flight runtime, scoping and file claims (stopped for the coordinator)

Date: 2026-10-17 · Status: Proposed. This is a scoping record only. No held file is edited until the coordinator
confirms the claims below with Slice C. PROPOSALS P-2044-1 to P-2044-6 are waiting.

Number range: 2044–2049, the D-flight lane's phase 2b. This is the 2b-1 record.
- **Branch:** `feat/slice-d-m5-flight`, cut from `docs/slice-d-flight` with origin/master `4c4fec92` (#272) merged in.
- **Worktree:** `scratchpad/wt-m5`. The analyzer runs on port 6505.

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
