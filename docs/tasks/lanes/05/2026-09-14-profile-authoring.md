# MOVE-PROFILE-AUTHORING — Q2 proposal and evidence package

Task: 05_movement_first_playable.md
Date: 2026-09-14

Code base `origin/master` at `26f1f8f`. Proposal and evidence only, per Astra's Cycle 2
handoff: "missing policy/cost values stay explicitly unresolved until the Q2 ruling."

## Delivered

- `docs/planning/movement_profile_authoring.md` — the proposal package.
- `docs/planning/movement_profile_readiness.json` — 288 rows (16 species x 3 life stages x
  6 modes), 35 Q2 slots, all `null`.

## Result

**8 adopted, 0 explicitly_disabled, 280 unresolved_q2, 0 admission_qualified.** The 64 adult
connected rows and the 8 ground/ford `S/N` cells reconcile exactly with MOVE-C2-R01's own counts.
The matrix and totals were rebuilt and re-asserted at write time rather than transcribed, and the
file's own `validator_rules` are asserted before it is written: every leaf resolves to a row
class, no row's `blocking_contract` has `kind: presentation`, no `presentation_gaps` id appears in
any `evidence_absent`, and no slot carries a value.

## Two new questions for Astra

- **Q2-24.** `FORD_WALK` has a distinct mode id and a distinct bit but **no distinct predicate or
  cost**. `_cursor_mode` is written at `_attach_route()` and read only by `admitted_mode_of()`;
  no cell predicate, cost or eligibility rule consults it. Ford and ground walk are today the
  same traversal with different labels. `world_init.gd` does define a ford geometrically
  (`is_ford()`, river tiles z = 48..51, `FORD_Y_UNITS = -128`), but that is inherited GDD §5.1
  map geometry, not a movement policy, and no per-profile water-depth limit exists.
- **Q2-32.** HAZ-001 classifies `DIVE`, `SWIM_SURFACE` and unprotected `CLIMB` as dangerous, and
  forbids CHILD hazardous **work** and excavation. Whether that reaches CHILD **non-work travel**
  in those modes is stated nowhere. 48 CHILD rows stay `unresolved_q2` rather than being upgraded
  to `explicitly_disabled` by inference.

## Evidence found that qualifies nothing

`godot/assets/lookdev/proportion_comparison_manifest.json` does carry per-pose horizontal and
vertical extents for five species. Recorded as `EV-BLOCKOUT-POSE-BOUNDS` and disqualified on five
stated grounds — hand-authored blockout rather than reviewed production geometry,
`landmark_status: PROPOSED_FOR_REVIEW`, MOVE-C2-R01's proxy exclusion, discrete rest poses rather
than a swept envelope with an error bound, and no margin or declared anchor-to-root offset. None
of its numbers is used.

## Stale value reported, not edited

`docs/planning/asset_dimensions_and_budgets.md` lists squirrel at 1024 u; DEC-039 approved
**1178**, which the lookdev manifest already carries. Another lane's file.

## Two planning-doc claims that are false today

`movement_starter_ground_profile.md` asserts `residents.gd` has no life-stage column and that
`SpeciesDefinition.rig_id` has no values. Both exist. Those lines are historical and were not
repeated.

## Not claimed

No dimension, cost, speed, air budget, depth or clearance value is authored. No route recentring
is proposed; production placement stays `(+256,+256)`. MOVE-G01–G05, 05.1b and the
`MOVE-ENVELOPES` inbox item are unchanged. No paid generation is authorized.
