# 1952 — Dig-tick cost, part 2: the approved P-1951 work, what it bought, and what the stalls are made of

Date: 2026-10-16 · Status: Accepted. It implements Brendan's 2026-10-15 rulings on decision 1951, with P-1951-2's
method replaced by the coordinator's call of 2026-10-16 (§4). Brendan ruled on this record's proposals on 2026-10-16
(see "Brendan's rulings (2026-10-16)"): P-1952-2 "Spread it out" and P-1952-1 "Later, if needed".

Lane DIG-TICK-COST, branch `perf/dig-tick-cost-2`, cut from `perf/dig-tick-cost` at its merged head `3cb7b60c` (master
`95d41cbf`), and merged with master `fd1c6d70` (PR #265) and `c11da82e` (PRs #267 and #268) on 2026-10-16. Brendan approved these items of decision 1951
on 2026-10-15 (`docs/handoff/RULINGS.md`): P-1951-1 (a), P-1951-2 (c) then (a), and P-1951-3 (a).

The coordinator cleared this lane for:

- `underground_room_world_bindings.gd` `worker_refusal`/`output_refusal`;
- the routes and proof files;
- a Profiles load revision.

Decision numbers 1952–1969 are this lane's. The rule is unchanged from 1951: **no rule changes**. Every change gives the
same answer, the same budget spends (including the exact fault and remaining budget when a budget runs out part way) and
the same saved bytes as the code it replaces. The per-tick owner trace of `tools/benchmark_dig_tick.gd` stays
byte-identical at every commit.

## Decision

1. **P-1951-3 (a) is done.** Profiles has a runtime-only load revision. The step-program closure (`ShortStep.uses()`,
   and through it `Assembly.uses()`) is remembered against it (§1).
2. **Every runtime cache is checked live in the test suite.** `CacheChecks.enabled` (`runtime_cache_checks.gd`, reached
   as `Profiles.CacheChecks`) is a static flag that the test framework turns on for every suite. The game and the dig benchmark leave it off. While it is on, each cache:
   - still computes its answer live, and answers with the live value;
   - reports a remembered answer that differs, as a `RUNTIME_CACHE_STALE` error.

   A suite that edits a bank in place without moving its token therefore fails, instead of reading a stale answer (§1a).
3. **P-1951-1 (a) is done in part.** Four steps make the re-checks that productive Work repeats every tick cheaper. None
   of them caches a verdict whose inputs are not all tracked:
   - the itinerary remembers each edge's profile choice (§2);
   - the final-facts snapshot and the Connector Contacts region scans walk only present rows (§3);
   - the four 512-row occupancy scans pass over rows that cannot answer (§3);
   - the itinerary's anchor check is remembered, and Locations finds source rows by slot (§3a).

   The cache of the whole verdict that P-1951-1 (a) describes is not built. §5 gives the reason and the measured
   options.
4. **P-1951-2's method is replaced; its intent is not.** The coordinator made this call on 2026-10-16, on this record's
   measurements (§4):
   - (c), the spatial index, is not built, because the proof images hold 7 to 76 rows;
   - (a)'s surface-exclusion revision is not built, because the costly refusals are not exclusion refusals;
   - an exact endpoint-proof memo, with spend replay, is built in their place (§4a).

   Its 140,872 B are charged through the ADR 1212 projection update.

## 1. P-1951-3: the step-program closure (`933dffd4`)

- `Profiles._load_revision` is runtime-only. It moves on `configure`, on every successful `load_file` swap, and on
  `invalidate_runtime_caches()`.
- `Routes._step_closure(profiles)` keeps `ShortStep.uses()` on the Profiles store, with the token and the `_live` instance
  it was read at. A loading store, a missing bank or a saturated (zero) token reads it afresh.
- WorldRoutes' profile proof and the itinerary's two `StepProgram.uses()` sites read it through `_step_closure`.

## 1a. Live cross-checking of every cache (independent review, HIGH)

The independent review of `3cb7b60c..495c63c9` found no equivalence break. Its one HIGH finding was that the step closure
and the edge memo trust the Profiles load token. A bank edited in place without `invalidate_runtime_caches()` would
therefore be answered stale. The lane's own test asserted that this happens.

Production never edits a Profiles bank in place; only `load_file` swaps it. Tests do edit banks in place: about 40 pokes
in 7 suites. Comparing the bank's values on every read would cost as much as the closure itself (about 150 values).
Instead:

- `CacheChecks.enabled` is a static bool in `runtime_cache_checks.gd`, a script with no dependencies. `test_case.gd`'s
  `_static_init` loads that script (it does not preload it) and sets the flag for the whole test process. The first
  version preloaded Profiles from the framework, and two CI contracts failed. One builds a throwaway project with only
  the framework (`test_run_tests_diagnostics.py`). The other clones the project with its game scripts broken on
  purpose (`test_buildings_metadata_preflights.py`). Both now pass, and a suite test asserts that the flag is on.
- The dig benchmark (`DigBenchMeter.time_answered_caches()`) and the memo suite clear it for themselves, because they
  time or test the answered path.
- While it is on, each of the four caches computes its answer live and answers live. A remembered answer that differs is
  reported as `RUNTIME_CACHE_STALE <cache>`, which the runner counts as an unexpected error. The four caches are:
  - the step closure;
  - the itinerary edge memo (split into `edge_memo_hit` and `replay_edge_profile` for this);
  - the anchor memo;
  - the endpoint memo.
- The edge and endpoint memos, when a slot would answer, also run the replay the game would run. They keep what it
  leaves (answer, budget, fault, search descriptor), put the state back, run live, and compare the two. Every suite
  therefore exercises the game's own replay code, not a second copy of it.
- Every suite that pokes a Profiles bank ran clean with the checks on, once two itinerary tests announced their edits: the itinerary, short itinerary, station planner,
  composition, footprint, claw wall profiles and profiles suites. No existing poke is answered stale.

The contract stays the same: **a bank edited in place must announce itself**. What changes is that it is now enforced by
whichever suite breaks it.

## 2. P-1951-1, step 1: the itinerary's per-edge profile choice (`bc95718b`, `e56f25bb`)

A room Work tick runs about five itinerary searches (`_ordinary_path`, for the worker and the output). Before this step,
most of each search's time went on `_edge_profile`. That function chooses, edge by edge, the first certified profile row
compatible with the anchor. WorldRoutes now remembers that choice per (edge, anchor) in a 16-slot packed memo
(`_edge_memo`, 19 words a slot, 2,432 B in `CONTROL_RESERVE`).

**What a slot is keyed on.**

- An epoch covers the inputs that move together:
  - the Routes graph instance and its publication token;
  - `_certificate_revision`, which moves on every certificate bank swap (publish, preflighted commit, restore; one
    helper, `_swap_certificates`);
  - the geometry revision;
  - the Profiles bank and its load revision.
- Each slot also keeps its own edge's inputs as read, and compares them on every answer:
  - the graph generation;
  - the certificate generation, geometry and content;
  - the four mask words.

  A certificate edited in place is therefore read again.

**When a hit answers.** Only inside the original search, with no recorded fault, and with budget for the whole
remembered spend. It then replays the exact spend and, when the choice wrote the search descriptor, the same five
descriptor fields.

## 3. P-1951-1, steps 2 and 3: walks that skip only rows that cannot answer (`e56f25bb`, `224bcf46`, `495c63c9`)

- **FinalFacts' snapshot** (about twice per room Work tick) counts and checks only the present source and region rows,
  through `Owner._next_present`. That is `find(1)` when the column is binary 0/1, and every row otherwise; 1951 proved it
  exact.
- **Connector Contacts.** `_unique_datum`, `_retained_earth_refusal` and `_installed_bearing_obstacles` skipped every row
  whose present byte is not 1, and charged nothing for it beyond their upfront `spend(_region_capacity)`. They now walk
  `_next_region` (`find(1)`, bounded by the region capacity). That is exact for any byte values.
- **The occupancy scans.** Contacts `_occupancy_leaf`, Delivery `_occupants_leaf`, WorldRoutes `_turn_occupants` and
  `workpiece_occupancy_refusal` now visit `Routes.next_occupancy_row(graph, from, extent)`. A row is passed over only
  when all three hold:
  - it is unregistered (slot −1 **and** generation 0);
  - its Resident's present byte is not 1;
  - the scan's unregistered test reaches `_unregistered_standing`. For the three scans that call
    `unregistered_body_refusal`, the helper itself tests `occupancy_extent_fresh`; the workpiece scan passes `false`.

  For such a row the old answer was `""` (standing's first test), and no spend was made for it. A stale extent passes
  over nothing, so the first free row still answers `ROUTE_OCCUPANCY_STALE`; a caller-level test checks each of the three
  scans. `_assembly_occupants_leaf` walks `_present.find(1)`.

## 3a. P-1951-1, step 4: the anchor check and the source-row lookup (`de5a154d`)

A profile of the room search (about 264 µs instrumented) showed two avoidable costs:

- about 51 µs in `Itinerary._anchor_refusal`, which mostly goes on the step program's 32-byte actor-digest compare;
- about 61 µs in Locations' `_resolve_source_row`. Its one-entry hint misses because World and Room sections alternate,
  so it scanned every source row.

The fixes:

- **The anchor memo.** `_anchor_refusal` is a pure function of the Profiles bank. Profiles keeps the last answer per anchor
  slot (`_anchor_memo`, 8 × 6 int64, 384 B in its `CONTROL_RESERVE`), keyed on the load revision and the bank, as the step
  closure is. A loading or poisoned store is never answered.
- **The source-row lookup.** `_resolve_source_row` walks `_o_slot.find(slot)` below the source capacity. The scan only
  ever read rows naming the slot, in row order, so every answer, and the hint it leaves, is unchanged.

## 4. P-1951-2: what the phase stalls are made of, and the coordinator's call

Two scratch instrumentations of the benchmark (not committed) measured the stalls.

**The proof images are small.** Each `_begin_proof` image held 7–76 volume rows. At the largest, 38 rows were
SUPPORTED_VOID and 34 were SUPPORT. Decision 1951 §6.2 counted "1.3 million box reads", but that figure comes from the
number of proofs, not from the size of an image. An exact index (P-1951-2 (c)) would still pay for its sorting, its
gap bookkeeping and its bulk spend replay, with at most 76 rows to skip.

**What the profile proofs cost.** One entry run (12 residents) had 14.4 s of stalls of 20 ms or more. The profile proofs
(`_profile_edge_refusal`) took about 6.0 s of that:

| Outcome | Calls | Time |
|---|---:|---:|
| Refused on heading, edge carried, live refused | 10,372 | 2.43 s |
| Admitted, edge not carried (full proof) | 336 | 0.88 s |
| Admitted, edge carried | 3,796 | 0.75 s |
| Refused `WORLD_ROUTE_ENDPOINT_BODY`, edge carried | 8,640 | 0.64 s |
| Refused on heading, edge not carried | 1,910 | 0.53 s |
| Refused on kind (all) | 59,750 | 0.28 s |
| Everything else | — | 0.5 s |

**The refusals do not depend on surface exclusions.**

- A heading refusal depends only on the content and the edge's path. The heading is tested only after both endpoint
  proofs (`_profile_endpoint_refusal`) have run, and those proofs are where the time goes. In the entry run they took
  1.82 s in all: 0.67 s observing the endpoint and 1.16 s on the per-box checks.
- An endpoint-body refusal depends only on the observed endpoint's immutable boxes, the content's boxes and the point.
- There were 41,986 endpoint proofs in the run, but only 424 distinct (location, point, profile, payload) keys.

**The coordinator's call (2026-10-16), relayed in this lane's messages:**

> Agreed. Don't build (c). The measurement settles it. What Brendan approved was the goal: speed-ups with no rule
> change. Swapping (c) for an exact endpoint-proof memo with spend replay is an engineering call within that, and I'm
> making it.

It also accepted the 80–340 KB reservation through the normal ADR 1212 projection update. `RULINGS.md` notes that this
replaces P-1951-2's method without changing its intent.

## 4a. The endpoint-proof memo (`f815bff5`)

`_profile_endpoint_refusal` still observes the endpoint live: the endpoint must be live, refreshed to this proof's
revision and at the path's end. The per-box checks (`_endpoint_boxes_refusal`) are then answered from WorldRoutes'
memo.

**How it is stored.**

- An **entry** for each of 64 Location-slot entries keeps the observed boxes those checks read, as 34 int32 words:
  - the point;
  - the envelope;
  - the support;
  - the air count and the live air boxes.

  The entry is compared box for box on every lookup, and refilled (with a new generation) when anything differs.
- Each entry has one **result word** per profile row: `generation << 16 | boxes checked << 4 | answer index`. A word from
  an older generation is never read.
- A **stamp** starts a new epoch, which retires every entry, when any of these moves:
  - the Profiles bank and its load revision;
  - the compiled content revision;
  - the six Domain bounds.
- The descriptor must be the bank's own current row for the compiled content: profile id, profile revision equal to
  `quantities[row]`, and content.

**What an answer replays.** The live checks spend `1 + box_count` per box and stop at the first refusal. An answer spends
the same total. When the budget runs out part way, it spends whole chunks while they fit and then makes the failing
`spend(chunk)`. That leaves the same fault and the same remaining budget as the live checks. Only completed answers are
kept, never a fault or a Profiles refusal.

**Why the skipped work is not missed.** The live checks also write scratch: `_body`, `_bounds`, `_scratch`, `_stance`
and `_support`. On the answered path this lane checked that every later reader writes that scratch before it reads it:
the next endpoint proof, `_profile_segments_refusal` and the next profile. Every other reader of `_endpoint` observes it
again first.

**Memory (ADR 1212 projection update).** The memo is 140,872 B:

| Column | Bytes |
|---|---:|
| Results, I64[64 × 256] | 131,072 |
| Entries, I32[64 × 34] | 8,704 |
| Entry tags, I64[64 × 2] | 1,024 |
| Stamp, I64[9] | 72 |

It is allocated once with WorldRoutes' fixed scratch and never saved. The census charges it as new retained memory
(`world_routes_endpoint_memo`), and **headroom moves from 49,749,393 B to 49,608,521 B**. After the merge with C2.3's
room-dig runtime (#268), it moves from 44,399,116 B to 44,258,244 B. Every artefact that carries the
figure is updated:

- the reviewed delta (with a stale duplicate edge-memo charge row removed), `REVIEWED_SHA` and the pack;
- the census and budget tests' pinned values;
- `systems_architecture.md`'s §2.3 table, ARCH-MEM-009 trail and allocation table;
- the rebased decision-1880 fold-in figures (after the #268 merge: 27,300,804 B, and 4,035,524 B left for slice G);
- `ready07_arithmetic.py`;
- four registry rows.

## 5. P-1951-1 (a): why the whole-verdict cache is not built

A cache of the room worker verdict would have to be keyed on every owner it reads:

- the Routes graph and its certificates;
- Locations' live bank;
- SpaceOwner's sources and claims;
- Profiles;
- Residents, Needs, Directory and Transforms;
- the worker's route row;
- the stores.

`Transforms.mutation_revision()` moves whenever any resident anywhere moves. A key that includes it would miss on every
tick on which a surface resident walks, and that is the common case at 256 residents. An exact verdict cache needs
per-row tokens on those owners, which are outside this lane.

The coordinator asked first for a memo of the itinerary search. The step-4 profile split the search's cost into the
anchor check, the source lookup, `_find` (about 47 µs) and two store checks (about 28 µs each). It is not the search
scratch. So the two exact sub-memos of §3a take the larger share without replaying the shared search scratch
(distances, predecessors, heap, proposed chain, path serial), and the search itself still runs. A memo of the whole
search remains possible, keyed as `_edge_memo`'s epoch plus Locations' publication token. Its scratch would have to be
replayed (four per-Location columns, the heap and the proposed chain, per slot), and the edges it relaxed would have to be checked value for value against tests that edit
the graph in place.

## 6. Results

The benchmark (`tools/benchmark_dig_tick.gd`, no trace) was run three times on each side, interleaved, at
`54558d6b`. The baseline is this lane's merged base `3cb7b60c`, which already has decision 1951's four speed-ups.
Figures are in microseconds unless marked, and each is the median of the three rounds.

The load average was 6.7–9.1 on both sides because other lanes' suites were running, so read the medians rather than
any single row.

| Room, 16 cubes | Before (`3cb7b60c`) | After (`54558d6b`) | Change |
|---|---:|---:|---:|
| `Work.tick_solo` p50 / p95 / p99 | 3,902 / 9,667 / 10,018 | 1,935 / 3,288 / 3,450 | −50% / −66% / −66% |
| Earning tick p50 / p95 / p99 | 4,660 / 10,499 / 10,924 | 2,635 / 3,961 / 4,130 | −43% / −62% / −62% |
| Routes advance (earning) p50 | 770 | 631 | −18% |
| Travel tick p50 / p95 | 699 / 952 | 617 / 879 | −12% / −8% |
| Phase open p50 | 17.3 ms | 14.1 ms | −19% |
| START p50 / p99 | 73.0 / 85.6 ms | 64.3 / 68.2 ms | −12% / −20% |
| Settlement p50 | 71.9 ms | 65.9 ms | −8% |
| Whole run (wall) | 18.8–18.9 s | 14.0–15.6 s | −21% |

| Entry prefix, 12 residents | Before | After | Change |
|---|---:|---:|---:|
| Foreman tick p50 / p95 / p99 | 643 / 15,002 / 18,151 | 589 / 10,820 / 13,190 | −8% / −28% / −27% |
| Ticks of 20 ms or more (per round) | 31, 29, 56 | 28, 28, 29 | — |
| Their total | 15.5 s | 14.0 s | −10% |
| Worst tick | 0.80 s | 0.74 s | −8% |
| Whole run (wall) | 30.1–33.4 s | 24.7–26.8 s | −18% |

At the 1x tick budget of REQ-SET-163 (about 2 ms for the whole simulation tick, p99):

- **Room.** A room earning tick with one builder is now about 2.6 ms at p50 and 4.1 ms at p99, so it is still over
  budget, and a foreman with several builders multiplies the Work share. The remaining cost is Routes `advance_tick`
  (about 0.6 ms), the itinerary searches, and the worker's observers and leaves.
- **Entry.** At the entry the per-tick p50 is well inside the budget. The p95 and p99 are set by the Connector Contacts
  re-proof on installer ticks.
- **Stalls.** The phase stalls remain. A START or settlement takes about 65 ms; an entry phase can take up to about
  0.7 s.

## 7. Proposals for Brendan

**P-1952-1: the per-tick worker and contact verdict.**

- **(a)** Add per-row write tokens to Transforms (and Locations' live rows), so that a cached verdict can be keyed on
  the rows it read rather than on a global counter. This is exact but large, and it changes owners outside this lane.
- **(b)** Memoize the whole itinerary search (§5).
- **(c)** Stop here.

**Recommendation: (a)** if the per-tick budget must be met at 256 residents; otherwise **(c)**. The entry's per-tick
cost is now dominated by the Connector Contacts re-proof, which reads the same moving inputs. (b) would take about
another 0.1–0.2 ms off a room tick.

**P-1952-2: the phase stalls.** The stalls are now made of per-edge requalification that is mostly carried or admitted,
plus Locations and Space preparation.

- **(a)** Spread one phase preparation over several ticks (1951's P-1951-2 (b)). This is a timing change for ARCH-SYS
  order.
- **(b)** Accept the stalls for this proof of concept.

**Recommendation: (b)** until the phase cadence is designed. Only (a) removes the stall itself.

## Independent review

Two independent `code-reviewer` subagents reviewed this lane: first `3cb7b60c..495c63c9`, then `495c63c9..5e7528a7`.
**Neither found an equivalence break.**

The second reviewer checked several things by hand:

- every input the endpoint checks read is in the entry, the stamp or the descriptor check;
- the chunked replay at every budget;
- all 26 readers of the skipped scratch;
- the word packing;
- the memory arithmetic, by running the seven validators.

| Review | Severity | Finding | Handling |
|---|---|---|---|
| 1 | HIGH | The step closure and the edge memo trust the Profiles load token, so a bank edited in place without announcing itself would be read stale. A test asserted the stale read. | Fixed by the live checks of §1a. The test now asserts the contract: a stale read with checks off, and a report with checks on. The full suite then caught `test_underground_room_itinerary`'s unannounced digest edit, through the anchor memo. That test and its twin in the short-itinerary suite now announce their edits. |
| 1 | MEDIUM | No test proved that a search was answered from the memo. | Fixed: a poisoned memo is followed. |
| 1 | MEDIUM | The stale-extent path of the three scans was untested. | Fixed: a caller-level test for each scan. |
| 1 | MEDIUM | The record was uncommitted. | This record. |
| 1 | LOW | The registry row omitted the 8 input words; `_next_revision` used a literal; FinalFacts' non-binary walks were untested; one test assertion was weak; `restore_state_bytes` ran to 32 lines. | All fixed. The swap is `_swap_certificates`. |
| 2 | MEDIUM | Checks-on ran a second copy of the replay logic, not the replay the game runs. | Fixed: checks-on runs `_replay_endpoint_boxes` / `replay_edge_profile`, keeps what they leave, puts the state back, runs live and compares. |
| 2 | MEDIUM | Only axis 0 of the entry key was tested. | Fixed: each of the 34 words is shown to retire the entry. |
| 2 | MEDIUM | The budget sweep missed chunk boundaries. | Fixed: every boundary, ±1, is tested. |
| 2 | LOW | The short-budget check branch was untested. | Fixed. |
| 2 | LOW | The serial wrapped instead of saturating. | Fixed: it saturates. |
| 2 | LOW | The box count was not in the descriptor check. | Fixed. |
| 2 | LOW | `edge_profile_memo` survived only as a test wrapper. | Removed; the tests use the production pair. |
| 2 | LOW | One test left its proof set. | Fixed. |
| 2 | LOW | The results are sized for 256 profile rows, not the about 70 loaded. | Kept: `Profiles.MAX_PROFILES` is the fixed capacity that content may load up to. Sizing by the configured capacity would make the census figure depend on content. |

## Behaviour proof

- The per-tick owner traces (`REDWALL_DIG_TRACE`; room 7,869 ticks, entry 3,462 ticks) are byte-identical to the merged
  baseline's trace at every commit of this lane.
- The test checkpoints keep their save bytes; only their manifests move.
- `test_underground_route_memos.gd` compares the itinerary memo and the endpoint memo with the memo off, filling and
  answering:
  - for the itinerary memo, every observable search output and its scratch;
  - for the endpoint memo, the answer, the remaining budget and the fault, for every station endpoint and profile, and at
    budgets that run out part way.

  It also proves that answers come from the memo (a poisoned word is followed), that each stamped input retires the
  memo, and that a stale word is reported with checks on.
- `test_dig_tick_equivalences.gd` checks each walk against the loop it replaced:
  - random presence bytes 0/1/2;
  - route references with slot and generation drawn independently;
  - fresh, stale and no-test extents;
  - random source slots with duplicates;
  - the FinalFacts precharge and claim walk on non-binary columns.
- `test_underground_routes.gd` checks that Contacts, Delivery and the turn scan each answer a stale extent at their
  first free row.

## Gates (results)

The final code is at `5918d11a`, the merge with master `c11da82e`. The worktree has no staged demo assets.

**Full suite, CI-style.** Each run deleted `godot/.godot`, re-imported with `godot --headless --path godot --editor
--quit` (no engine crash), and then ran `./tools/run_tests.sh`.

- At `f42e6d24`, before the merge (1 h 11 min), it printed:

  ```text
  12663 test(s), 1300454 assertion(s), 0 failure(s)
  diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 287 expected, 448 tolerated; leaked at exit: 0 object(s), 0 resource(s)
  log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
  ```

- At `5918d11a`, after the merge (1 h 14 min), it printed:

  ```text
  12839 test(s), 1438375 assertion(s), 0 failure(s)
  diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 287 expected, 456 tolerated; leaked at exit: 0 object(s), 0 resource(s)
  log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
  ```
- Two earlier runs reported problems that are now fixed:
  - At `5e7528a7`, two unexpected errors. They were the anchor memo's live check catching
    `test_underground_room_itinerary`'s unannounced bank edit (§1a). That test now announces its edits.
  - At `54558d6b`, two CI contracts failed, because the framework preloaded Profiles (§1a). The switch moved to
    `runtime_cache_checks.gd`.

**Other gates:**

- **Analyzer.** `python3 tools/gdscript_warnings.py --max 0 --port 6451` printed `0 GDScript warning(s) in 0 of 1564
  file(s)`. The lane had left 11 warnings, cleared in `54558d6b`.
- **Decision numbers.** `python3 docs/validation/decision_numbers.py` printed `PASS -- 565 records, 0 problem(s)`.
- **CI contracts.** Every `python3` contract command in `.github/workflows/tests.yml` that needs no Godot was run.
  - Before the merge, at `f42e6d24`: 59 run, 0 failed.
  - At `5918d11a`: 59 run, 0 failed.

  They include `underground_memory_budget.py --check`, `ready07_arithmetic.py`, `state_registry_coverage.py`,
  `audit_registry_capacities.py --check`, `merge_gate.py`, `renew_source_pins.py --check`,
  `test_run_tests_diagnostics.py` and `test_buildings_metadata_preflights.py`.
- **Mutation testing.** 83 mutants were run in their final form, and **all 83 were killed**:

  | Area | Mutants |
  |---|---:|
  | The step closure | 6 |
  | The edge memo | 10 + 14 |
  | FinalFacts | 6 |
  | The occupancy walk | 9 |
  | The live checks, the anchor memo, the source lookup and the endpoint memo | 26 |
  | The review fixes | 12 |

  - Twelve mutants survived at first; tests were added and the twelve were re-run and killed.
  - Three call-site mutants of the first occupancy design ("pass a stale extent as fresh") disappeared with the design.
    The call sites no longer take the flag; the helper tests the extent itself.
- **Behaviour.**
  - **Before the merge.** The per-tick traces were byte-identical to the baseline at every commit, last at
    `f42e6d24`.
  - **After the merge.** The trace of new master `c11da82e` is byte-identical to the old baseline, because C2.3 changes
    nothing on the benchmark's path. The trace at `5918d11a` is byte-identical to `c11da82e`'s.
  - **The room dig.** The room benchmark digs a whole 16-cube room through `Work.tick_solo`,
    `Sites.work_tick_refusal` and the room world bindings' `worker_refusal`/`output_refusal`. Those are the paths
    this lane memoizes. C2.3's new composite dispatcher and room runtime composition are not on the benchmark's path;
    their own suites run with the live cache checks on.
  - **Checkpoints.** Both checkpoints' save bytes are unchanged at every commit, and after the merge they equal
    master's.
- **Independent review.** Two `code-reviewer` passes found no equivalence break and no open CRITICAL or HIGH item (see
  above).

## Brendan's rulings (2026-10-16)

Brendan ruled in chat on 2026-10-16, and the coordinator relayed the rulings:

- **P-1952-2: "Spread it out".**
  - Phase preparation will run across several ticks, so a phase opens a few ticks later than it does now. That is a
    small timing change, and it will be recorded.
  - It is **not byte-identical**, so it is **not** part of this lane. It will be its own lane, which starts after the
    activation lane has mounted content 12, because both lanes touch the phase-start and route paths.
  - This branch does not begin it.
- **P-1952-1: "Later, if needed".**
  - The per-row write tokens wait.
  - After activation and phase spreading, the cost is re-measured with `tools/benchmark_dig_tick.gd`.
  - The tokens are built only if the 2 ms target of REQ-SET-163 is still not met.

## Source

- Decision 1951 and its rulings; `docs/handoff/RULINGS.md` (2026-10-15 and 2026-10-16).
- ADR 1205 (incremental requalification), ADR 1212 (memory census), ADR 1219 (unregistered occupants), ADR 1227 (contact
  proof spends).
- REQ-SET-163 (`docs/game_gdd.md`).
