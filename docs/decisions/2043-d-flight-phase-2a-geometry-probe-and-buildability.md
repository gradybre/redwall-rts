# 2043 — D-flight phase 2a: the flight geometry, the 160 u probe, and why F40 cannot be built in place

Date: 2026-10-16 · Status: Proposed. Phase 2a is built: the geometry module, its tests and the probe. P-2043-1 and
P-2043-2 wait for Brendan; P-2043-2 is the coordinator's call.

Number range: 2041–2049, the D-flight lane's. This record follows Brendan's rulings on
[decision 2041](2041-slice-d-flight-scoping-a-full-level-earth-timber-flight.md#brendans-rulings-2026-10-16). The
earth carry is scoped separately in [decision 2042](2042-one-basic-earth-carry-scoping.md).

## Decision

1. **The flight geometry is a cold module.** Its tests reproduce every number of decision 2041 §2 and today's
   flight.
2. **The 160 u probe fails with the accepted recipe.**
   - **What works.** The accepted authors produce both gaits at 160 u with no leg-reach refusal, unlike 256 u.
   - **What fails.** Both two-deck terrain proofs refuse: the mole's right leg meets the deck in each gait. The
     ascent's right arm also meets the body with M7's approved 3° swing.
   - **What it means.** Qualifying 160 u is new authoring: a recipe search, an arm-swing search, and every proof
     after. Nothing was authored, as ruled.
3. **F40 cannot be built in place with qualified motion.** Phase 2a found that P-DF-8 (a)'s order does not work for
   F40. In F40 the floor steps down 1 m in the middle of the run, under continuous treads.
   - **No station.** No qualified station can strike the first cube of the next step down. The row above it is
     filled wall to wall by the treads already standing there (F1).
   - **No way down.** No qualified motion can reach that lower floor before its treads exist.
   - **Recommendation (P-2043-1).** Build the straight flight as **five copies of today's qualified 1 m module (M5),
     joined by natural landings**. Each copy is the qualified flight translated by (0, −1,024 u, −5,120 u). It is
     buildable with qualified motion only, with no new post lengths and no temporary works. The costs are four more
     rows (2 × 27 cells) and slower hauls.

## 1. The geometry module (built)

**`godot/data/underground/full-level-flight-v1/flight_geometry.gd`**, new.

- **What it is.** A stateless module of static integer functions, in the style of `tread_geometry.gd`. Phase 2b's
  runtime preloads it; nothing held by the activation lane or cost-2 was edited.
- **The argument.** Every function takes `steps`: 40 for F40, or 8 for today's flight (the cross-check, and one
  module of M5). Nothing else is ruled, so every other value refuses.
- **How it refuses.**
  - A count refuses with −1, and a coordinate with 1; both lie outside every valid range.
  - Anything a runtime would publish comes only through a bool `_into` call that leaves its packet untouched on
    refusal: a floor stop (`floor_stop_into`), the cubes (`cubes_into`) and the bills (`fixture_bill_into`,
    `excavation_bill_into`, `total_bill_into`).
- **What it derives.**
  - Treads, the sill (D1), tops and far edges (identical to `tread_geometry.gd` for T0–T6).
  - Each tread's row; the rows, each row's floor depth by 2041 §2.1's rule, and the end wall.
  - Post lengths: 64–960 u, with 832 and 960 on T6, T7, T14, T15, T22, T23, T30 and T31.
  - The floor stops F, F′ and U, which are today's moved by (0, −4,096, −16,384). A point at or past the end wall
    refuses.
  - Every cut cube as a source-local box, in storage order (row, column, then layer from the top). This is not a dig
    order; §3 sets that.
  - The deep-cube count, the per-piece cube split (4 + 123 + 15) and the part count (276).
  - The fixture, excavation and total bills: wood 78,500, stone 35,500, 858,980 milli-WU and earth 284,000 for F40.
    The cube price is read from `excavation_contract.gd`, not retyped.
  - `ALLOWED_ROTATION_MASK` = 1: quarter-turn 0 only (P-DF-6).
- **One simplification found by mutation.** A tread row's floor depends only on its deeper tread, capped at the
  level floor. The cap is what places the sill's row and the run-out on the floor. An earlier draft special-cased
  the sill row; that case was equivalent and has been removed.

**`godot/test/test_full_level_flight_geometry.gd`**, new: 13 tests, 708 assertions. Every row of 2041 §2.4 and every
figure of §2.5 is asserted, together with:

- the impossibility of a 64–704 u floor for row 5, re-derived inside the test;
- each tread lying wholly in its row and bearing on its floor;
- the frame against `tread_geometry.gd`;
- uniqueness and containment of all 142 cube boxes;
- the per-piece split;
- the refusals;
- today's flight reproducing its measured ledger (59,220 + 77,840 milli-WU, 14 cubes);
- `translation(k)` for every tread, row 5's four cube boxes in order, and the level pack's own `level_spacing_u`
  read from `initial_level_pack.json`;
- every refusal leaving its packet untouched.

**Mutation testing.** A scratch script made 60 single-site mutants, one per run, then ran the focused suite and
restored the file. This was run after the review's fixes. **56 were killed and 4 survived. All four are equivalent
mutants, proved below:**

- **`MIN_POST` 64 → 0.**
  - The deeper tread's top in row 2 + m is 256(m + 1), so the floor is `ceil((256m + 512) / 1024)` against
    `ceil((256m + 448) / 1024)`.
  - For those to differ, a multiple of 1,024 would have to lie in [256m + 448, 256m + 512). Every multiple of 1,024
    is a multiple of 256, and none lies in that range.
  - The boundary itself is tested: 64 → 65 is killed.
- **The shallower tread instead of the deeper** (`+ 2` → `+ 1`). This gives `ceil((256m + 384) / 1024)`, and by the
  same argument it cannot differ at a 128 u rise. The deeper tread binds, so the code keeps it.
- **Dropping `MIN_POST` from the sum.** This is the first mutant again, in another form.
- **Dropping `valid(steps)` from `floor_stop_into`'s guard.** For an invalid flight `end_wall_z` is 1, so the
  end-wall test `far − beyond ≤ 1` refuses every point anyway. The explicit check stays for clarity.

## 2. The 160 u feasibility probe (P-DF-1 (b), ruled "probe 1:3.2")

**`godot/data/underground/mole-worker/claw-work-v1/probe_rise_160.py`**, new, evidence only.

- **How it runs.** It runs ADR 1217 M7's accepted path unchanged:
  - the authors `author_stair_descent.source_case` and `author_stair_motion.source_case`;
  - M7's recipe values (descent: advance 256, drop 128, leading foot 360, toe 20°; ascent: lead advance 68,
    lift 50);
  - the claw ready and the approved 3° right-arm swing;
  - the accepted provers: two-deck terrain, the repeated flight, and self-clearance.
- **The only change.** Four functions whitelist the rise. They are re-executed in memory, in each module object that
  holds them, with ±160 added to their literal tuples.
  - The originals are restored after the run (`widened`).
  - The sequence prover's segment and solid capacities take `prove_descent_flight`'s values, as in M7's own `prove`.
- **Nothing accepted was touched.** All 31 repository source files the probe reaches through its loaded modules are
  hashed before and after. The hashes are equal and are recorded in the result.
- **The fixture.** `prove_descent_flight`'s flight, pitched at 160 u: T0's parts moved by (0, −32 − 160k, −512k),
  with posts kept on the one-metre floor. That gives T0–T4 (T5's post would be negative), so five steps each way.
- **No rows and no publication.** The bottom (the sill and the floor) is not probed, because a 160 u flight's floor
  is a full level down.
- **Interpreter.** `$PY` = the prover interpreter recorded in the evidence invocations (Python 3.12.14,
  numpy 2.3.5).
- **Inputs.** The pinned palette `godot/demo/assets/underground-matrices/all-cast-v9.ugpal` was cloned (gitignored)
  from the frozen `redwall-rts-codex-ug-space` checkout, as ADR 1209 did.

**The control at 128 u is clear, reproducing M7 exactly.**

| Proof | Descent | Ascent |
|---|---|---|
| Two-deck terrain | 674 pairs, clear | 781 pairs, clear |
| The flight | 3,370 pairs, clear (= 5 × 674) | 3,905 pairs, clear (= 5 × 781) |
| Self-clearance (3 classes) | clear | clear |

**At 160 u it is not clear: FAIL.** Results are in `claw-work-v1/evidence/rise-probe-v1/`.

| Step | Descent | Ascent |
|---|---|---|
| Authoring | **Succeeds**: no `DESCENT_LEG_REACH` refusal, unlike 256 u (ADR 1209 line 25) | Succeeds |
| Two-deck terrain | **Refuses** at interval 45: the **right leg** (shin triangles 4395, 4567, 4568, 4670) meets a fixture solid; the prover stops at its 32-witness limit (350 pairs checked) | **Refuses** at interval 25: the **right leg** meets a fixture solid (399 pairs) |
| The flight | Not run (it needs a clear terrain base) | Not run |
| Self-clearance | Clear | **Right arm against the rest: not clear** with the 3° swing |

**Why it fails.** M7's foot and root tracks were tuned for a 128 u step: the descent's drop and lead foot, and the
ascent's lift. At 160 u the trailing shin in the descent and the leading shin in the ascent pass through the tread
the step leaves or reaches. In the ascent, the higher leg lift also brushes the hanging right paw again; that is
why M7 needed the swing at all. The leg reaches the step; the recipe does not clear the deck.

**What full 160 u authoring would take** (not started, as ruled):

1. **A recipe search** on the accepted authors' own parameters: descent drop, advance and leading foot; ascent lift
   and advance. This is new source candidates.
2. **A new arm-swing search** (M7's bisection).
3. **Proofs:** terrain, the flight, a new 160 u bottom fixture (a sill and floor a level down), and self-clearance.
4. **Re-derived motions:** the half-turn on a 160 u tread (`author_claw_turn`), the step back and forward, and the
   tread fitting with the bearer 32 u lower (DEC-060 candidate b).
5. **The 14 carry rows** (decision 1981) and the floor end, re-proved.
6. **Delivery to the runtime:** native capture, Brendan's motion review, about 21 new Profiles rows (content 13 or
   later, `PROFILE_BYTES`), and DEC-050's pace word (P-DF-9 (a)).
7. **New geometry:** about 30 distinct post lengths.
8. **The folding limit:** a 160 u flight still cannot fold (decision 2041 §2.2).

That is a full motion pipeline, ADR 1209's and 1981's scale. For comparison, the gain is 4 cells of length and 17 % of
a haul trip.

**Tests.** `claw-work-v1/test_probe_rise_160.py`, 7 tests, all passing (`$PY`, no art needed). They cover:

- the fixture at 128 u equals `prove_descent_flight`'s own treads, trench and descent segments;
- at 160 u the decks are one pitch lower and T5 refuses;
- `widen` refuses a missing literal;
- `widened` restores the original function objects, and the 160 u refusal, after its block;
- both stored records pin this probe file's hash and today's hashes of all 31 accepted source files it reaches;
- the stored control reproduces M7's counts;
- the stored 160 u result is the failure described above.

## 3. Finding: F40 cannot be built in place (P-DF-8 (a) does not work for it)

**F1. Treads fill the slot from wall to wall.**

- **The parts.** The first-entry prefix artifact (`docs/design/underground-planning/first-entry-prefix-v1.json`)
  gives T0's deck as x [−1,024, 1,024] and y [−192, −128]. Its bearers and posts stand at |x| 768–896.
- **The consequence.** Every tread row's floor is under a deck and between posts: about 250 u of space, with no
  stance for a mole.
- **What decision 2041 assumed.** P-DF-8 (a), "each cube struck on its top face from its uphill neighbour's floor",
  assumed that floor is free.

**F2. In F40, the first row of each new plateau has no station and no way to reach it.**

- **Where the plateaus start.** In rows 5, 9, 13 and 17 (2041 §2.4). Take row 5, whose floor must drop from depth 1
  to depth 2 before T6 (post 960) can stand.
- **No station.** The top-face rows (56–62, decision 1971 §3) need a stance on a floor level with the cube's top
  face, in an adjacent cell.
  - Row 4 is the only adjacent cell that keeps depth 1, and it holds T4 and T5.
  - A stance on T5 itself (top −768) is 256 u above the face, out of reach.
  - Rows 6 onward also need their deep layer.
  - The last cube of each new layer has no station.
- **No way down.** Even with a station, the floor at depth 1 beyond T5 can only be reached by a 256 u drop. That
  drop is refused motion (ADR 1209 line 25).
- **Temporary works would be needed.** In today's flight a sill (T6) bridges that drop, but in F40 a sill would stand
  on a floor that must later be dug out from under it. Removing an installed tread is an unbuilt flow.

**F3. The modular straight flight M5 is buildable with qualified motion only.**

M5 is decision 2041 §2.3's M5: today's 1 m module five times, each a natural-landing continuation of the last.

- **The top metre first.** The top metre of all 27 rows is cut from land stations, as the entry cuts its 14 cubes
  today. Then module 0 is today's flight.
- **The order.** Module j's landing is module j−1's run-out, which stays at depth j. From it:
  1. Layer j + 1 of every row past the landing is cut, from the downhill end upward. Each cube is struck from its
     uphill neighbour, which is still at depth j.
  2. The last cube, the next module's first row, is struck from the landing itself.
  3. The mole reaches all those floors by walking from F′ along the level floor at depth j. It never crosses a row it
     has deepened, because it retreats uphill.
  4. Then module j's treads are fitted, exactly as today's (DEC-060, chained under DEC-059 P1). The next module's T0
     is fitted from the natural landing, as T0 is from L0.
- **The spoil.** The deep cuts' earth is carried up by decision 2042's earth carry, which must be active before layer
  2 is cut.
- **What it uses.** Every motion is qualified: rows 56–62 on a floor, the stair gaits, the fitting, the half-turn,
  and the floor end (decision 1981, P-1972-7/9's natural footing).
- **The cost of a landing.**
  - Each landing adds 180 ticks down (walk-off and approach) and 225 ticks up (retreat, back-up and half-turn) to a
    laden haul.
  - The round trip goes from 2,805 to 4,425 ticks (5.9 game hours), +58 %.

| | F40 (ruled, not buildable in place) | **M5 (proposed)** |
|---|---:|---:|
| Footprint | 2 × 23 cells | 2 × 27 cells |
| Treads, posts | 39; adds 832 and 960 u | 35 (five × today's seven); today's posts only |
| Cut cubes (deep) | 142 (96) | 154 (100) |
| Parts (catalog `MAX_PARTS` 256) | 276, over | 52 + 4 × 45 = 232 in one variant, or five placements |
| Bill | wood 78,500 · stone 35,500 · 858,980 milli-WU · earth 284,000 | wood 77,500 · stone 38,500 · 912,620 · earth 308,000 |
| Haul round trip (lower bound) | 2,805 ticks | 4,425 ticks |
| New geometry | two post lengths, stepped floor under treads | none: today's module translated (0, −1,024, −5,120) per module; a "mid" variant without L0 |

**M5's bill under P-DF-4 (a).**

- **Fixtures:** L0, five T0s (each installed from a landing, at T0's bill) and 30 other treads. That is wood
  4,000 + 5,000 + 30,000 = 39,000, and 32,000 + 60,000 + 169,200 = 261,200 milli-WU.
- **Excavation:** 154 cubes. Per column: rows 0–1 at depth 1, then module j's five rows at depth j + 1, so
  2 + 5 × (1 + 2 + 3 + 4 + 5) = 77; two columns make 154.
- **Totals:** wood 77,500 (38,500 + 39,000); stone 38,500; work 651,420 + 261,200 = 912,620 milli-WU; earth
  308,000.

## 4. Proposals

**P-2043-1 — The layout that phase 2b builds (for Brendan; it revisits P-DF-2's straight F40).**

- **(a) M5: today's qualified module five times in a straight line, joined by natural landings. 2 × 27 cells,
  qualified motion only, no new post lengths, parts inside the catalog's bound. Hauls are 58 % slower than F40's
  would be.**
- (b) F40 with temporary works. At each of the four plateau ends, fit a temporary sill and run-out, cut the next
  layer, then remove the sill and re-cut under it. This needs an unbuilt tread-removal flow and re-proofs, and
  wastes a sill's timber four times.
- (c) F40 with a third, work column beside the slot, as a bench at each plateau's depth: 3 × 23 cells, 69 cells
  against M5's 54. The bench geometry and its stations are new work.

**Recommendation: (a).** It is the only option that needs no unqualified step.

**P-2043-2 — Where M5's geometry lives (for the coordinator).**

- **(a) Extend `flight_geometry.gd` in phase 2b with M5's modules (a layout argument). The F40 functions stay, as the
  record of the ruled layout, and their tests keep 2041's arithmetic.**
- (b) Extend it now, before Brendan rules.
- (c) A separate module.

**Recommendation: (a).**

## 5. What phase 2b needs from the activation and cost-2 merges

**The activation lane** (`feat/activate-content-11-12`).

- Content 12 mounted: the carry rows, the stair-carry tables, and the floor end F, U and F′ with P-1972-7/9's
  natural footing. M5's every landing and its bottom reuse that footing rule.
- The stair path's six-word edge plan with modes (`underground_entry_stair_path.gd`), to generalise from one module
  to five.
- `underground_entry_bindings.gd`'s retention of the cut floor under a natural landing, applied at each landing.
- The publisher `publish_qualified_stairs.py` and `entry_source_constants.py`, released. Phase 2b writes its own
  create-only publisher beside them.
- `underground_entry_contact_retirement_scope.gd` `ENDPOINTS` and `underground_route_composition.gd`, released, for the
  extra stops.
- The connector catalog (`MAX_PARTS`) and contacts, released.

**Cost-2** (`perf/dig-tick-cost-2`).

- M-2: whether a WorldRoutes preparation fits `MAX_CHECKS` once five modules' stair edges are live. It is measured on
  master after both merges; if it overflows, the lane stops with options.
- Routes, WorldRoutes, Locations, Profiles and Delivery released: for the stops and edges of five modules, and for
  decision 2042's earth carry (Profiles admission of content 13, Delivery's upward legs).

**Both**, in one pass: pins, the census (`PROFILE_BYTES` for content 13), checkpoints, and the Frontier byte bound
(per-module Frontiers if needed, P-DF-8 (c)).

## Gates (phase 2a)

- **Focused suite:** `./tools/run_tests.sh --suite test_full_level_flight_geometry.gd`, `ok: 13 tests, 708
  assertions, 0 failures`. Diagnostics: 0 unexpected errors and warnings, 0 leaks.
- **Full suite, CI-style:** `ok: 12819 tests, 1435535 assertions, 0 failures`, 0 unexpected diagnostics, 0 leaks ("Full suite" below).
- **Analyzer:** `python3 tools/gdscript_warnings.py --max 0 --port 6503`, `0 GDScript warning(s) in 0 of 1604
  file(s)`, rerun after the fixes.
- **Probe tests:** `$PY test_probe_rise_160.py`, 7 tests OK.
- **Mutation:** 60 mutants, 56 killed, 4 equivalent (§1).
- **`decision_numbers.py`:** PASS, 567 records.
- **Independent review:** 1 HIGH, 6 MEDIUM, 11 LOW; every HIGH and MEDIUM fixed ("Review" below).

## Review

An independent `code-reviewer` read the phase 2a code. It confirmed all of decision 2041's arithmetic and found the
probe's widening confined to the rise whitelists. It raised 1 HIGH, 6 MEDIUM and 11 LOW. All of them are fixed or
answered below.

**HIGH, fixed: `floor_stop` never refused.** For an invalid flight it returned a believable point on L0. It is now
`floor_stop_into`, which refuses an invalid flight, a bad packet, or a point at or past the end wall, and leaves the
packet untouched.

**MEDIUM, all fixed.**

- **The cube order.** `cubes_into`'s order is now described as storage order, not a dig order, and row 5's four
  boxes are asserted in order.
- **In-band sentinels.** Bills now come only through `fixture_bill_into`, `excavation_bill_into` and
  `total_bill_into`. The remaining counts keep −1 and coordinates keep 1, as documented in the module header.
- **Unruled flights.** `valid` now admits only the two ruled flights, 8 and 40.
- **Surviving mutants.** `is_sill(bad, −1)` is asserted false, and `translation(k)` is asserted for every k. The
  cube-order mutants are killed. The mutation figures in §1 come from the rerun.
- **The arithmetic test.** The literal-only loop in the row-5 test is labelled as documentation; module assertions
  are added beside it.
- **The probe's records.** They are now tied to the probe's own hash and to the current hashes of every source it
  reaches.

**LOW.**

- **Fixed:**
  - `ALLOWED_ROTATION_MASK` is renamed, and its test reads the mask.
  - The level spacing is read from the pack.
  - `cubes_into` writes in place, with no per-cube allocation.
  - Arrays in the tests are typed.
  - The probe hashes all 31 reachable sources.
  - `widened` restores the original functions.
  - The deck test asserts the exact list.
  - The docstring names the capacity values.
  - Decision 2041 §4 and §7 now say the derivation's tests are GDScript.
- **Answered, not changed:**
  - The sill's post of 0 is documented: read `is_sill` first.
  - Constants that repeat `tread_geometry.gd` stay local, so the F40 module does not depend on content 10's runtime
    file. The frame test pins them equal for T0–T6.
  - `_ceil_div` stays, because `IntMath` allocates.
  - The probe holding the descent drop at 128 is the stated scope: "fails with the accepted recipe".

### Full suite

These results are on the final code, after the review fixes.

- **The steps.** `godot/demo/assets` was moved aside and `godot/.godot` deleted. The editor import ran (`godot
  --headless --path godot --editor --quit`, exit 0). Then `./tools/run_tests.sh` ran in one process. The assets were
  then restored.
- **The suite:** `ok: 12819 tests, 1435535 assertions, 0 failures`.
  - `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 456 tolerated; leaked at exit: 0
    object(s), 0 resource(s)`.
  - `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s)`.
- **The analyzer,** rerun after the restore: `0 GDScript warning(s) in 0 of 1604 file(s)`.
- **The contracts:** `decision_numbers: PASS -- 567 records, 0 problem(s)` and `lane_notes: PASS`.
