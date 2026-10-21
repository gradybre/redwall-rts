# 2092 — Stair-leg Delivery phase 1: the leg helper, and gate G0 stopped at the surface

Date: 2026-10-21 · Status: Accepted, but **stopped at gate G0** (P-2092-1 waits for Brendan). Built under decision
2091's rulings, P-2091-1 to -8 (a) ("Approve, start phase 1"). No new ruling is made here; the choices made while
building are recorded below.

Branch `feat/stair-leg-delivery`, cut from `docs/stair-leg-delivery` (which is cut from M5's `ea9c7ed6`). Number range
2092–2099; analyzer port 6519. Not pushed.

## Decision

Phase 1 of decision 2091 §9 is built. It adds new files only, plus one registry section:

| File | What |
|---|---|
| `godot/scripts/core/underground_stair_legs.gd` | The stateless leg helper (1941 §2 item 1, P-2091-3 (a)) |
| `godot/test/test_underground_stair_legs.gd` | Its plans on M5's full stop set (13 tests) |
| `godot/test/test_underground_stair_legs_live.gd` | The helper on the real M5 graph at tick 75,000 (6 tests) |
| `godot/data/underground/first-entry-prefix-v1/test_loaded_landing_clearance.py` | **Gate G0** (10 tests) |
| `docs/persistence_state_registry.md` | One section: the helper is stateless, category 3 |

**G0 passes at every landing and fails at the surface.**
- **At every landing, on M2 and M5,** every loaded body clears the sill and the decks. Every loaded join arrives without
  a turn.
- **At the surface it fails.** R's haul stand is the quarter-turn grip, so a loaded mover leaves it facing −X. It keeps
  that heading, because no loaded turn exists. H's approach (73/79) needs it facing down the flight.
- **The lane stops here,** as the coordinator's brief requires, and reports P-2092-1 (§2.1).

Nothing here touches M5's held files, D2 phase 2's way-in files, Delivery, the hauler, the room builder, or any Slice C
hold. The helper only *reads* the stair path's `Stops`, `global_level` and `hops_up_from_walk_off`.

## 1. The helper

`underground_stair_legs.gd` is stateless. A leg list is a `PackedInt32Array` with five words per leg: from (slot,
generation), to (slot, generation), and the row.

- **`loaded_down_into(stops, item, landing, out, source_stand, destination_stand)`** builds the loaded way from H down
  to landing j's F′.
  - Each module contributes:
    - the approach (73/79) from its H, or H′ below module 0, to A at its L0 position;
    - eight descents (74/80): L0 to T0, T0 to T5, onto the sill, then onto landing j+1's F;
    - the walk-off on the approach row again (decision 1981 W1/S1), from F to F′.
  - Between modules, the loaded join F′(j) → H′(j) runs on the item's ground CARRY row (32/37).
  - Optional ground legs come first and last: source stand → H, and F′ → destination stand.
  - Lengths: 10 legs to landing 1, 11 more per landing after that, so 54 to level 1, or 56 with both stands.
  - The rows come from the grip certificate's family: `Grip.family_of(Grip.carry_row_for(item))`. No quantity is
    read. 2b-2 adds earth's family there.
- **`empty_up_into(stops, landing, out)`** builds the empty way from F′ up to X. It uses the stair path's own
  `hops_up_from_walk_off`: the back-up 72, the half-turn 55, eight ascents 54 per module, and R′ on 45 then F′ on 47
  at each landing. That is 59 legs from level 1.
- **`resolve_into(routes, profiles, legs, edges_out, remaining)`** matches every leg to its live edge in **one pass**
  over the Routes edge table.
  - A leg is matched by its two stops (slot and generation) and by its row's mode.
  - It takes the first live edge, in row order, whose metadata reads. That is Contacts' `_row_path_refusal` rule.
  - It charges one check per edge row and one per leg.
- **`certify_refusal`** reads each matched edge's published certificate for its row, at the row's loaded revision
  (`WorldRoutes.static_profile_edge_refusal`), as Contacts does. **`legs_refusal`** runs `resolve_into` and then
  `certify_refusal`.
- **Refusals:** `STAIR_LEGS_UNCERTIFIED_ITEM`, `STAIR_LEGS_LANDING`, `STAIR_LEGS_STOP` (the list is left empty),
  `STAIR_LEGS_SHAPE`, `STAIR_LEGS_CHECKS` (the allowance is then marked exhausted, -1), `STAIR_LEGS_OWNER`, and
  Contacts' `ROUTE_NOT_CONNECTED` for an unmatched leg.

### Choices made while building

1. **Legs are matched by mode as well as by stops.**
   - Contacts' scan compares only the two stops (`underground_connector_contacts.gd:1566-1573`).
   - On module 0 a descent's WALK edge and its CARRY twin join the same two stops (`StairPath._joined`). A stop-only
     scan would give a loaded leg whichever edge comes first in row order.
   - The live suite proves the loaded descent takes the CARRY edge and the claw descent takes the WALK edge.
   - On WALK legs the match is exactly Contacts', because only one edge of that mode joins those stops.
2. **One pass, legs sorted by start slot.**
   - Each live edge's start slot is binary-searched in the legs, sorted by insertion (a few dozen legs).
   - The work is one edge pass plus a logarithmic lookup per edge, against one pass *per leg*.
   - The pass charges as Contacts charges its scan: one check per row.
   - The certificate reads are not charged, as Contacts' are not.
3. **A failed metadata read skips that edge for every leg**, as Contacts' scan skips the row.
4. **The empty way is the stair path's own hops**, leg for leg. So it is the walk the entry crew already takes
   (decision 1940; P-2045-11 (a)). Turning at R′ is still the walker's job. The hauler cannot turn (decision 2091 F2),
   so phase 3 walks the up list with turning legs.

## 2. Gate G0 (`test_loaded_landing_clearance.py`, run as `test_landing_clearance.py` is)

It reuses `test_landing_clearance.py`'s readers (the profile wire, the stair motion decks, the M2/M5 publisher). It
checks M2 and M5, wood and stone:

| Check | Result |
|---|---|
| Fixture decks of the loaded rooted motions at every landing lie in the Room's support. These are: the descent from the sill onto F (74/80), the walk-off F → F′ (73/79), and, except on the last landing, the next module's approach H′ → A0′ (73/79) and its seven descents | **All covered** |
| Loaded rooted bodies that dip below a landing floor are held by support or a cut cube. The next module's descents are clipped to the deck rows, as `test_landing_clearance.py` clips 53 | **All held** |
| The loaded join F′(j) → H′(j) on 32 and 37, swept along the join and standing at either end, meets no installed part | **Clear on every landing** |
| The stance of 32 and 37 at F′ and H′ lies on the deck rows, which are never cut | **Yes** |
| No turn: the sill's descent ends on F; F → F′ → H′ → A0′ runs straight down the centre line at one height; the last landing ends at F′ | **Yes** |
| The surface join from R's stand (−256, 0, 1,536) across to the centre line, then straight down the flight onto H (0, 0, −1,536), on 32 and 37, meets no part except the L0 deck its feet stand on | **Clear, but arrives turned: G0 fails (§2.1)** |
| The level-1 store's stand (D2's, P-2091-7) | Recorded: it must be a yaw-0 grip (§2.2) |

**The footing rule** treats a box that sits exactly 1 u deep in a part's top face as standing on that part, not as a
collision. A test pins how narrow it is: 2 u in is a collision.

**Recorded for phase 2 (not part of the gate).** The ground rows' bodies are wider than the air F′ and H′ are sized by
today.
- Sizes: 32 is ±714 u and 37 is ±598 u. F′'s air (sized by 47) and H′'s (sized by 43) are x −485..479, z −521..412.
- WorldRoutes holds each body box in the stop's air: its envelope, or one extra air box (ADR 1215;
  `underground_world_routes.gd:2988-3000`).
- A single box bounding all of wood's boxes at F′ would reach **28 u** into module j−1's sill deck.
- Two boxes both clear every part, at F′ and H′, on every landing:
  - an envelope over the grounded boxes, widened from 47's air;
  - one extra box over the raised load (y 447–704).
- **So phase 2 sizes F′ and H′ air that way.** The stops belong to M5's bundle, so this happens after M5 merges.

### 2.1 G0's failure: R's stand faces the wrong way

The independent review found this (HIGH 1). The first G0 test swept the surface join's boxes at yaw 0 and passed only
because rows 32 and 37 are square.

- **R's haul stand is the quarter-turn grip.** It stands at stock + (576, 0, 0) (`underground_entry_work_area.gd:57-59`).
  The grip certificate puts the stock at stand + (−576, 0, 0) at yaw 16384 (`grip_certificate.gd` `stock_offset`). So
  the mover lifts facing −X.
- **A ground CARRY edge keeps the heading the mover lifted at.** No loaded turn is authored. The work area's carry edge
  steps out sideways and "enters the destination stand moving -X (yaw 16384)" (`_carry_approach`, :352-358).
- **H's approach starts facing down the flight (yaw 0).** That is the rooted 73/79, H → A(L0) along −Z. So a mover
  carrying from R's stand reaches H turned a quarter, and the 73/79 edge cannot take it.
- **R's yaw-0 grip is blocked by M.** It would stand at stock + (0, 0, 576) = (−832, 0, 2,112). That is 64 u past M's
  stock point (−832, 0, 2,048), on M's line.
- `test_g0_fails_at_the_surface_the_stand_at_r_faces_the_wrong_way` pins all of this.

**P-2092-1 — How a loaded mover leaves the surface facing down the flight.**
- **(a) A stair-head store.**
  - It is a new surface staging container for stair hauls, beside the stair head, off the centre line. Its stand is the
    yaw-0 grip, with the stock 576 u further down the flight from the stand.
  - It is published with the way in (phase 2), in the work area M5 holds. Its exact point is chosen by a clearance test
    first, as for every other stop.
  - P-2052-7's labelled stand-in, and later HAUL-H3+, stock this store for rooms instead of R. That changes P-2052-2's
    "staging is the surface R" to "staging is the stair-head store".
  - No new motion. One more container.
- (b) Two hops through a turning store. The mover lifts at R's quarter stand, carries to a set-down store placed so that
  a yaw-0 stand can lift from it, and lifts again there. This is (a)'s container plus a second trip per unit.
- (c) Author a loaded ground turn, a new qualified motion with a content successor. It is ruled out in spirit by every
  "no new motion" choice so far (P-2045-11).
- (d) Move R so its yaw-0 grip is free. This changes the entry's qualified work area, its chain and its checkpoints.

**Recommendation: (a).**

### 2.2 The level-1 store's stand (recorded for D2 phase 2, P-2091-7 (a))

- A mover arrives at F′(5) facing down the flight and keeps that heading. So the store's stand must be the **yaw-0 grip**,
  with the stock 576 u further down the flight from the stand.
- On the centre line, these all fit the run-out's cut only with the stand at **z ≥ −26,869**, which is at most 71 u past
  F′(5):
  - both families' yaw-0 set-down (35 and 40);
  - their stock (stone's reaches 779 u ahead; the end wall is at −27,648);
  - the ground carry.
- `test_a_level_one_store_stand_must_face_down_the_flight` pins this.
- An off-centre or up-flight stand is also possible, because a ground carry may move sideways at a fixed heading. D2
  places it with this test's readers.

## 3. Measured on the real graph (tick 75,000)

- The committed `underground_flight` checkpoint at tick 75,000 has landings 1–3 built and module 0's stair carry
  published. It is the last flight point before P-2045-14's late-save limit.
- **The empty way up from landing 3's F′ to X.**
  - It has 35 legs, and all of them resolve. Every certificate admits its row.
  - The spend is **1,571 checks**: 1,536 edge rows plus 35 legs. That is **0.15 % of `MAX_CHECKS`**.
  - Compare decision 2091 §3, which estimated ≤ 83k for Contacts' per-leg scan on 54 legs.
  - Wall time, best of 20, on Brendan's Mac under other lanes' load:
    - **1.83 ms** with the certificates;
    - **13.9 ms** for the per-leg reference scan alone (best of 5).
  - 176 of 1,536 edge rows are live.
- **The loaded way down to landing 1 (wood).**
  - Module 0's eight loaded legs resolve to CARRY edges, and their certificates admit 73/74. These are the approach
    and the seven descents to the sill.
  - The ninth leg, the sill's descent onto F(1), has no edge, so the way refuses `ROUTE_NOT_CONNECTED`. This is
    decision 2091 F1. Phase 2 publishes that edge (P-2091-4 (a)).

## 4. Gates (at `db9560f5`)

- **Focused suites:** `./tools/run_tests.sh --suite test_underground_stair_legs.gd --suite
  test_underground_stair_legs_live.gd` printed:
  - `ok: 19 tests, 351 assertions, 0 failures.`
  - `diagnostics: 0 unexpected error(s), 0 unexpected warning(s) ... leaked at exit: 0 object(s), 0 resource(s)`
  - The live suite takes 18 s locally.
- **G0:** `python3 godot/data/underground/first-entry-prefix-v1/test_loaded_landing_clearance.py` printed `Ran 10 tests
  ... OK`. The surface failure is pinned as a recorded fact. `test_landing_clearance.py` still prints OK.
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6519` printed `0 GDScript warning(s) in 0 of 1692
  file(s)`.
- **Contracts:** all 32 commands of CI's contracts and `underground-memory` jobs exited 0. Among them:
  - `decision_numbers: PASS -- 584 records`;
  - `state_registry_coverage: PASS -- 209 modules`;
  - `underground_memory_budget.py --check`, `test_underground_memory_budget.py` and
    `test_underground_current_census.py`.
- **The full suite at 12 shards was not run.** The lane stopped at G0 as briefed. The change is new files plus one
  registry section, so it touches no existing suite's code. The full suite runs before this branch is put up for merge.

## 5. Review and mutation testing

**Independent review** (code-reviewer, read from git objects at `3a16ae55`): one HIGH, three MEDIUM, seven LOW.
- **HIGH 1 (G0's surface heading):** confirmed. It is §2.1, and the lane stops on it.
- **MEDIUM 2 (untested matches):**
  - A stale start generation is now tested.
  - "First edge wins" and a failed metadata read can't be built on a live graph; they are declared below.
- **MEDIUM 3:** an empty list now refuses `STAIR_LEGS_SHAPE`.
- **MEDIUM 4:** `legs_refusal`'s docstring states the caller's scope leaf.
- **LOWs:**
  - Rows are checked before the charge, and nothing is charged on a malformed list.
  - No temporary arrays are built per leg.
  - The long lines are split.
  - The stance assertion has a message.
  - R's stand is derived from the stock point.
  - The stands' yaw-0 obligation is in `loaded_down_into`'s docstring.
- The reviewer confirmed the indices, the sort and search, the early return, the mode match and the allowance
  semantics, and found no vacuous G0 assertion.

**Mutation testing** (scratch runner `scratchpad/sld_mut/mutate.py`, one mutant per run, both focused suites).
- 42 mutants were run; 1 is moot, because the review fix removed its code. **37 of the 41 that apply are killed.**
- The 4 survivors (SURVIVED_MUTANTS):

| Survivor | Verdict |
|---|---|
| `_match_edge` early `return` → `continue` | **Equivalent.** Legs are sorted by start slot, so the first different slot ends the run; `continue` only scans further |
| Matching absent edge rows too | **Equivalent.** `edge_metadata_into` refuses a row that is not live, so such a row is never given to a leg; the presence test only saves the read |
| Dropping "not yet matched" (the last matching edge wins) | **Not constructible on a live graph.** It needs two live edges with the same stops and mode. The stair path's `_joined` never stages such a twin, and no fixture can publish one without a second publisher |
| Ignoring a failed metadata read | **Not constructible without corrupting an owner.** It needs a live edge whose section reads stale |

## 6. What phase 2 inherits

- **P-2092-1's ruling, first.** Without it, the surface join has no stand to start from.
- **Publishing the loaded edges at way-in bind** (P-2091-4 (a)). That is `StairPath.carry_plan`'s down-only extension,
  plus the surface join from the stand P-2092-1 settles. Both are in M5's files, so this happens after M5 merges.
- **Widening F′'s and H′'s air** as envelope plus extra box (§2).
- **The probe at `STEP_DONE`.** If H′ is retired, the join ends at A0′ and G0's checks are redone first.
- **The cost gates G1/G2** of decision 2091 §9, on a level-1 checkpoint once P-2045-14's fix lands.
- **`test_loaded_landing_clearance.py` runs by hand.** CI does not run it, and it does not run
  `test_landing_clearance.py` either. A CI step for the prefix's Python tests would be a small change to the shared
  workflow, worth proposing with phase 2.

## Source

- Decisions 1941, 1972, 1981, 2044, 2045 and 2091 (and its rulings).
- ADR 1215.
- `underground_entry_stair_path.gd`, `underground_connector_contacts.gd:1454-1574`, `underground_world_routes.gd:2712`
  and `:2988`, and `test_landing_clearance.py`.
