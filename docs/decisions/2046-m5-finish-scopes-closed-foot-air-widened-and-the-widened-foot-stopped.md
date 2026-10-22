# 2046 — M5 finish: the finished entry's scopes closed, the foot's air widened, and why the widened foot stopped

Date: 2026-10-22 · Status: Accepted in part. B1 and B3 are built; B4 (the widened foot) **stopped for a ruling**, under
the brief's "if something won't fit, stop and report" (P-2046-1).

Branch `feat/slice-d-m5-finish`, cut from M5's final head `771e1f7a` (PR #283, `feat/slice-d-m5-full`). Number range
2046–2049; analyzer port 6505. This lane fixes the three problems decision
[2054](2054-slice-d2-phase-2-the-bound-way-in-and-why-m5s-foot-admits-no-room-yet.md) (slice D2 phase 2, on
`feat/slice-d2-phase2`) found in M5's held files: B1, B3 and B4. Decision
[2045](2045-slice-d-m5-round-measured-and-scoped.md) is the M5 round's record.

## Brendan's rulings (2026-10-22, relayed by the coordinator)

| Proposal | Ruling | What it means here |
|---|---|---|
| P-2054-1 | **(a)** | When the entry finishes, M5 closes the two scopes left open: the entry bindings' `_timber_token` and Contacts' `_valid`. The Session stops reporting `WORLD_RETIREMENT_BUSY`, so painted rooms can be ordered; the host must not crash there |
| P-2054-2 | **(a)** | Widen F′(5)'s air (an envelope plus ADR 1215's extra box) so a loaded row fits; the CARRY span from F′ to the level-1 store's stand is then admitted. Clearance proved first; content 12's rows only, no new motion |
| P-2054-3 | **(a)**, "Widen it" | Cut M5's bottom run-out one cell wider on each side, so a room's front work station can strike a single cube and be reached by a turn. B4's proof first; re-measure the bottom stage's peaks; "if something won't fit, stop and report" |
| Order | "Merge M5, then fix" | #283 merges as it is; this lane is the next PR |

## B1 — the finished entry's scopes are closed (built)

**Cause** (decision 2054 B1, confirmed): a paid operation's publication clears the Placement's controls
(`underground_connector_placements.gd` `publish_completion`, `publish_workpiece_preflighted`) but asks its authority to
discard its timber scope only on a refused operation (`discard_completion`). So the last operation's `_timber_token`
outlived the entry. Contacts keeps `_valid` true after every successful observation until the next pin or a
`discard_transition`. `underground_world_retirement.gd` (`_entry_refusal`) and `Contacts.retirement_refusal_in` read
both as an open operation, so `Session.current_refusal()` stayed `WORLD_RETIREMENT_BUSY` and `room_orders()` lent
nothing (the host's `order_painted_room` then called `world_ref()` on null; D2 fixed that call on its branch).

**Fix**, in M5's own files (no Placements edit):

| File | Change |
|---|---|
| `underground_entry_runtime.gd` | On the finishing tick (`STEP_DONE`), `_foreman.close_finished_scopes()`; a refusal is pushed as `ENTRY_FINISHED_SCOPE <code>`. While the crew leaves, the close is asked again each tick (review M1), so a close refused on the finishing tick does not stay open |
| `underground_entry_foreman.gd` | `close_finished_scopes()`: refused (`ENTRY_FOREMAN_STATE`) unless the last stage has settled, every installation is planned, and both Contacts and an authority that can close exist; then Contacts', then the Placement authority's |
| `underground_connector_contacts.gd` | `close_finished_scope()`: drops the retained observation as `discard_transition` and `discard_phase` do (`_valid`, the phase mode, primary Job, material, phase output); refused while a proof runs (`CONNECTOR_CONTACT_REENTRY`) or a phase holds its Space or companion lease (`CONNECTOR_CONTACT_SCOPE`) |
| `underground_entry_bindings.gd` | `AdmissionAuthority.close_finished_scope()` → `_close_finished_timber()`: discards the scope as `_discard_timber` does, only when the Placement is not prepared on that lease (`ENTRY_ORIGINAL_COLD_SCOPE`) and no proof reads (`ROOM_MASK_REENTRY`); idempotent |

Both closes are idempotent; nothing else changes before the finishing tick, so every flight point before the finish
is unchanged.

**Proved:**
- `test_underground_m5_finished_scopes.gd` (from the committed finish checkpoint): the entry is done, Contacts holds
  no scope, the provider no timber scope, `current_refusal()` is empty, `room_orders()` is lent, and the host's order of
  a painted level-1 Kitchen is refused only by the way-in seam (`ROOM_DIG_NO_WAY_IN`, D2's to fill), nothing admitted;
  each scope set open again makes the Session busy and the close clears it; every refusal of the closes, with the
  scope kept.
- `underground_flight_case.gd`: the live last segment (tick 90,000 → the finish, restored along the way) ends with the
  Session quiescent and no timber scope.
- A live probe (scratch, not committed) from tick 90,000: finish on tick 92,559 as before; `current_refusal` empty.

**For D2 (an obligation, review M3).** The root cause stays: a successful publish never discards the provider's
timber scope, and Contacts keeps its last observation. This lane closes them when the entry finishes. Any later paid
operation through the same entry provider or Contacts (stair-leg Delivery's, D2's) reopens them, and must close its own
scopes when it settles, or the Session goes busy again.

The host's own null call while the Session is busy (`order_painted_room` → `session.room_orders().world_ref()`) is in
`settlement_system.gd`'s D2 wiring, which this lane stays off; D2's `_room_orders_refusal` fixes it there. After the
finish the Session is no longer busy, so that path is not reached from M5's state.

## B3 — F′(5)'s air holds the loaded rows (built)

P-2054-2 (a) with decision 2092 §2's shape. `test_landing_clearance.py`'s new test was written and run first:

| At F′(5), relative to its point | Box |
|---|---|
| Envelope: 47's air and the carry rows' grounded body and turn boxes, from the floor up | x −679..679, y 0..937, z −679..679 |
| Extra air box (ADR 1215): the carry rows' raised load (32's y 447–704, 37's 447–821) | x −714..714, y 447..821, z −714..714 |
| Footing: 47's stance and both carry stances | x −375..375, z −375..375 |

Both boxes clear every installed part and the run-out's walls; every carry body box lies in one of them; the footing
lies on the deck rows, which are never cut; one box bounding both would reach 28 u into the last sill's deck (2092's
finding, pinned). The CARRY span to the stand 50 u on clears every part.

**Built** in `underground_entry_bindings.gd` only, for F′(5) alone (classified by the stair path: `KIND_FP` of the last
landing): `_timber_profile_envelope` resets `air_count` and, for F′(5), `_foot_carry_air` widens the record by the grip
certificate's two carry rows (`Grip.carry_of`, 32 and 37). The extra box is proved by `_timber_extra_air_box` against
every physical and foreign-claim blocker, and it must lie wholly in completed void (ADR 1215's rule, which Locations
repeats); the envelope's region pass became `_timber_void_residual`, shared and unchanged for every other endpoint.
`_timber_profile_foot` also proves each carry row's below-floor boxes on its own stance (`_profile_foot`). Locations'
session pool already holds extra air (64 slots, `underground_room_composition.gd`); Contacts' refusal of multi-air
endpoints concerns installation stations, and F′(5) is none (the last sill's order retreats to X). The other landings'
F′ keep one box, so stair-leg Delivery still widens F′ and H′ there (decision 2092 §6).

**Proved:** `test_underground_m5_foot_air.gd` (from the finish checkpoint): F′(5) holds exactly those boxes; both carry
rows' bodies fit (`Locations.air_contains`), while 47's air alone holds neither; landings 1–4 keep one box; a yaw-0
stand 50 u past F′(5) is published and the CARRY span F′(5) → stand is admitted by WorldRoutes' seal, and the WALK span
too (decision 2054's probe found the span refused `WORLD_ROUTE_NO_FITTING_PROFILE`). The live probe reached the same
record and spans.

## B4 — the widened foot: the proof passes, the build stopped

### The proof, first (`test_underground_m5_wide_foot.gd`)

Decision 2054's B4 test, re-run on content 12's own rows (no D2 file):
- On the 2-cell foot no front station both strikes one cube and stands where row 42 turns (2054's record, kept).
- With the last two rows four cells across (x ±2,048), row 42 turns on any line within 1,336 u of the centre line, so
  the end wall's two inner cells have stations (478–609 u in) on turnable lines. One is built out: the corner where 42
  turns (712–824 u from the end wall), the straight walk on 43/47, the wall row 67 at its station, all clear of the
  widened walls, the end wall and the sill; one unit outside either range they are not.
- The side walls still admit no front there: their stations stand 415–546 u or 1,439–1,633 u from the end wall, and
  row 42 turns only 712–824 u from it whatever the width (the end wall and the sill bound it).

`flight_geometry.gd` names the foot (`FOOT_ROWS` 2, `FOOT_HALF_WIDTH` 2,048, `layout_foot_rows`,
`layout_foot_half_width`, `layout_row_width_cubes`); the cube counts and bill are **not** changed on this branch.

### The build, and where it stopped

The widened foot is the last two rows (25, the last sill's far half, and 26, the end row) cut four cells across, open
to the sky as the slot is: 20 more cubes, four a layer, each struck on its top face by a qualified row. That build was
carried as far as the first real admission and is kept, not merged, on the local branch
**`wip/slice-d-m5-wide-foot`** (`1b1fd593`, not pushed): the create-only bundle `qualified-stairs-m5-v3` (36/210/26/235
/325/174 Frontier rows; Frontier 55,556 B), four land stations at x ±2,454, sixteen lateral stations (x ±618, 728 and
1,324 u from the end wall, rows 58/62, each stage's first cuts), their floor walks turning on the lateral line, the
foreman's lateral and footing retirements, the work area's four extra endpoints, and the matching tests
(`test_landing_clearance.py`'s lateral test passes; `test_publish_m5_flight.py` passes on v3).

**It stops at the entry's admission.** `test_underground_entry_work_area.gd`'s real first-prefix admission refuses
`ENTRY_NATURAL_BEARING_REMOVED`:

1. The admission (`underground_entry_bindings.gd` `_entry_surface_contacts_refusal` → `_entry_natural_bearing`)
   requires every surface work-area endpoint's footing to stand on natural ground that **no claimed cube** removes.
2. Two kinds of land footing lie over the new side cubes' top metre: the first cut pair's full-length outer strip (work
   area `LEFT_FOOT`/`RIGHT_FOOT`, x ±1,024..±2,966 the whole length of the slot, which is also the surveyed SUPPORT the
   gateway walks along x ±2,560 stand on), and the land stations of rows 25 and 26 at x ±1,430, whose stance
   (x ±1,024..±1,836) stands on those very cells.
3. Those row 25/26 stations cannot move: once row 25's side cells are claimed, every cell next to row 25's slot cubes
   (its side cells, the other slot cube, row 24's and row 26's slot cubes) is claimed, so no land station can strike
   row 25's slot top metre at all. A top-face strike needs a stance on an adjacent cell's top.
4. And the SurfaceAnchor stages each endpoint's footing and air as permanent World SUPPORT and void rows; removing a
   Location does not remove them, and nothing retires them.

So P-2054-3 (a) needs a capability that does not exist: a surface endpoint whose ground a later cut takes, retired with
its World rows before that cut, and admitted on that condition. That is outside M5's claims (`underground_surface_anchor
.gd` is not M5's) and changes the admission's rule, so the lane stops here, as briefed. The bottom stage's peaks were
not re-measured: no flight with the widened foot was ever admitted.

**What 2054 did not see.** Its B4 analysis was of the foot alone. Its remark "the same holds for any 2-cell slot" is
true of the run-out's length it measured (1,536 u), not of every length (P-2046-1 (b)).

### P-2046-1 — How a level-1 room opens at M5's foot (for the coordinator and Brendan)

- **(a) Build the widened foot with surface-endpoint retirement.** The admission accepts a land endpoint whose footing a
  later cut takes when the Frontier names the episode before which it retires (as a deep strip names its retiring
  episode, P-2044-12 (a)); the foreman retires it (its edges, its Location, and its SurfaceAnchor World rows) before that
  episode's BRACE; the first pair's strip stops short of the foot rows. Needs `underground_surface_anchor.gd` (a retire
  operation for World rows) and the admission rule; then `wip/slice-d-m5-wide-foot` continues, the flight is measured
  against `MAX_CHECKS` (the phase structure is already 96.7 % at landing 4) and every checkpoint regenerates. End-wall
  rooms (the end wall's inner cells) open; side walls do not. Largest change.
- **(b) Lengthen the bottom run-out one row instead of widening it.** A third run-out row (2,560 u from the last sill's
  far edge to the end wall): 10 more cubes, all inside the slot's two cells, cut by today's stations and rows exactly as
  every other row (no new endpoint kind, no footing over a cut, no new motion). Row 42 then turns 712–1,848 u from the
  end wall, which holds every side-wall station of the middle run-out row (1,439–1,570 u west, 1,502–1,633 u east), so
  a room painted beside the run-out opens from its side wall, on either side. Proved on content 12's rows by
  `test_a_run_out_one_row_longer_admits_a_side_wall_front_in_the_two_cell_slot`. End-wall rooms still do not open.
  Changes M5's geometry, bundle (a v3 with 28 rows), bill and every checkpoint; D2 re-lays its foot (hub, parking,
  store) in the longer run-out. F′(5) and B3 are unchanged (F′ is measured from the sill).
- (c) Level-1 rooms wait for a later connector or a dug foot chamber (2054's P-2054-3 (c)).

**Recommendation: (b).** It reaches the ruling's purpose (a front that strikes one cube and is turned into) with the
mechanisms M5 already qualifies, and it keeps every land footing off the claims.

## Gates (this round, B1 and B3)

- **Focused suites** (entry bindings, Contacts, the M5 geometry, the wide-foot proof, the entry Frontier): `ok: 115
  tests, 12211 assertions, 0 failures`, 0 unexpected diagnostics, 0 leaks. After the review: the foot-air and
  finished-scopes suites, segment 22, the crew-leaves and crew-lost-at-finish suites, the whole chain, the checkpoint
  store, the wide-foot proof, the entry bindings and Contacts: 0 failures.
- **Clearance:** `test_landing_clearance.py` `Ran 11 tests ... OK`; `test_publish_m5_flight.py` unchanged and OK.
- **Analyzer** (`--port 6505`): `0 GDScript warning(s) in 0 of 1702 file(s)`.
- **Source pins** renewed for Contacts (`renew_source_pins.py --write`).
- See "Review, mutation and the regenerated checkpoints" below.

## Review, mutation and the regenerated checkpoints

**Independent review** (`code-reviewer`, of B1 and B3): no CRITICAL; one HIGH, three MEDIUM, eight LOW.

| Finding | Outcome |
|---|---|
| H1: the memory pack still pinned the old digests of Contacts and the entry bindings (`underground_memory_budget.py --check` failed) | **Fixed**: the pack regenerated; only those two digests move, every byte figure unchanged (live with reserve 106,191,789 B) |
| M1: a close refused on the finishing tick was never retried | **Fixed**: retried each tick while the crew leaves (both closes idempotent) |
| M2: `_timber_extra_air_box`'s refusals were untested, and it keeps the envelope's exemptions | **Fixed**: `test_the_extra_air_box_must_lie_in_completed_void` (the box moved into uncut earth or onto the sill's deck refuses); the docstring says Locations' ADR 1215 proof, which exempts nothing, is the authority |
| M3: the root cause (a publish never discards the scopes) stays for later paid operations | **Recorded** as D2's and stair-leg Delivery's obligation (B1 above) |
| LOW: a finish-checkpoint assertion that could not fail (the timber scope is not saved) | **Fixed**: dropped; the live check is segment 22's |
| LOW: the foreman reported success with nothing to close | **Fixed**: refused without Contacts or a closing authority |
| LOW: Contacts' close left the phase mode and output | **Fixed**: cleared, as `discard_phase` does |
| LOW: an allocation for the extra box; hard-coded test constants; this record's dangling reference | Constants now `flight_geometry.gd`'s; reference fixed. The extra box stays a copy: using the proof's own `box` as scratch (tried) aliased `subtract_cover`'s scratch and moved the regenerated finish by one region, which the regeneration caught |
| LOW: a post-finish save made by the old code restores `_valid` true | **Answered**: no such save exists outside the committed checkpoints, which are regenerated |

**Mutation testing** (scratch runner, one mutant a run against its named suites: B1's against the finished-scopes
suite and segment 22, B3's against the foot-air suite and segment 22; the checkpoint manifests re-fingerprinted for
each mutant so the committed saves still load): **18 of 23 killed.** The five survivors (SURVIVED_MUTANTS):

| Survivor | Verdict |
|---|---|
| The foreman's "authority can close" guard dropped | Equivalent: the Placement's only authority is the entry provider's, which can |
| The retry while the crew leaves dropped | Not constructible in the chain: it matters only when the finishing tick's close refused, which no fixture reaches |
| Contacts' close keeps the phase mode | Equivalent in the flight: the mode is already off at the finish (the regenerated finish save is the same either way) |
| A raised load box taken as one starting above 447 u instead of above the floor | Equivalent on content 12: no carry box starts between the floor and 447 u |
| The carry rows' below-floor proof at F'(5) skipped | Equivalent on content 12: their below-floor boxes lie inside their own stance |

**Regenerated checkpoints:** every flight point through tick 90,000 is byte-identical; the finish (tick 92,559,
unchanged) saves Contacts with no retained scope and F'(5) with its widened air; the entry and spare recipes only
re-fingerprinted. Segment 22 (90,000 → the finish, restored along the way) passes in 149 s.

**Contracts** (CI's contracts and underground-memory jobs, run here): decision numbers (587 records), ready07, merge
gate, dispatch plan, Astra inbox, save registry, canonical state table, the capacity audit, both schemas, lane notes,
state registry coverage, `underground_memory_budget.py --check` and its two tests: all pass.

**Not run, because B4 stopped:** the full 12-shard suite, the frames of the widened foot (nothing widened was built on
this branch) and the bottom stage's peaks. They run once, on the branch that carries B4 after the ruling.

## Source

Decisions 1215, 1936, 1937, 1990, 1991, 2041–2045, 2052–2054, 2091, 2092; ADR 1209; the code at `771e1f7a`.
