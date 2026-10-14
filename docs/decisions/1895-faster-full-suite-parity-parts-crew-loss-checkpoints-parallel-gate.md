# 1895 — Faster full-suite runs: parity in six parts, crew-loss checkpoint starts, a local parallel gate

Date: 2026-10-12 · Status: Accepted (engineering record of the TEST-SPEED packet; PROPOSALS below await Brendan)

Number range: 1895–1899 was allocated to this lane by the coordinator. This lane uses 1895 only.

## Brendan's rulings

- 2026-10-12, relayed by the coordinator: **"Run parallel shards"**, for the local full-suite gate; and "Start party
  compact, and test speed and orchard test" (this lane). BACKLOG.md's TEST-SPEED packet is the brief.
- Checkpoint starts are his decision 1240 of 2026-10-08, and its rule holds: a test that asserts a property of the
  whole run from tick 0 keeps its replay.
- 2026-10-12, in chat via AskUserQuestion, on the PROPOSALS below (each the recommended option):
  - Proposals 1 and 4, **"Approve both"**: the local runner keeps CI's 10 shards and 4 jobs as its default (pass
    `--jobs 5` on an idle machine); the CI weights are refreshed from this branch's first CI run once it merges.
  - Proposals 2 and 3, **"Approve both"**: `test_underground_host_whole_chain.gd` and
    `test_underground_paid_assembly_handling.gd` stay unsplit until a CI shard nears its 30-minute guard; checkpoint
    files stay committed, revisited at about 50 MB of growth.

## Baseline (bf49943a, art-free, freshly imported, this Mac)

The complete suite as CI's ten shards, four at a time (the coordinator's scratch runner, which this lane turned into
`tools/run_tests_parallel.sh`), then `ci_test_shards.py verify`:

- `ok: 490 suite files executed exactly once across 10 shards`; **12,333 tests, 1,245,495 assertions**, 0 failures,
  0 unexpected errors or warnings, 0 leaks (278 expected, 373 tolerated).
- Shard walls **[625, 470, 469, 469, 469, 457, 464, 462, 469, 455] s**; the **shard floor was 625 s**, shard 0 running
  `test_settlement_save_parity.gd` alone. Wall time 1,397 s. Suites together: 4,757 s.
- (The coordinator's slice B reference run had 1,245,499 assertions and the same 12,333 tests and shard 0 alone.)

## 1. ARCH-SAVE-006 parity in six parts

**Where the 620 s went** (probe at bf49943a): a tick of the generated settlement costs 0.16 ms (3,000 ticks in
0.48 s); one parity fingerprint costs **17.8 ms** (623 members hashed whole, the largest 1.3 ms: Navigation's
4 MB arena); a save 0.61 s (56,989,480 bytes), a load 1.0 s. The test fingerprints 33,000 ticks (15,000 recorded,
15,000 replayed, two 1,500-tick windows), so 99% of it is hashing.

**What was not done.** Splitting the horizon into tick ranges would need either several forks (ARCH-SAVE-006 in
`systems_architecture.md` says one save at 3000 and one continuous run compared at every tick 3001-18000) or the
uninterrupted run's fingerprints committed as a fixture (the loaded run alone is still 15,000 fingerprints, about
270 s). Neither meets the brief without changing what the test proves.

**Decision.** `save_parity_fingerprint.gd` gains `partition(parts)` (members largest first, each to the part with the
fewest bytes so far; deterministic for one binding) and `restrict(assignment, part)` (keep one part; the two queue
views go with part 0). The test body moved unchanged into `settlement_save_parity_case.gd` (not a suite), and six
suites `test_settlement_save_parity_1.gd`...`_6.gd` each run all of it (the same generated settlement, fork, pending
command, starving resident, uninterrupted run, saves, loads, windows and byte comparisons), fingerprinting their own
part at every tick. Together they compare every member at every tick, as one fingerprint did, with six independent
64-bit folds instead of one. Ticks are cheap, so each suite replays them. Each suite also asserts: all six suite
files exist and no seventh; the assignment covers every member exactly once and every part has members; the loaded
world binds the same member list; its part is the one kept.

Parts hold 100, 100, 105, 108, 105 and 105 members.

**Counts.** Before: 1 suite, 1 test, 58 assertions, 620 s (in the full run). After: 6 suites, 6 tests, 76 assertions
each (456), 126-128 s each measured three suites at a time (763 s together; each replays the 33,000 ticks, the
saves and the loads). The 18 extra assertions per part are the seven suite-file checks, four partition checks, and
two member and part checks on each of the three loads plus the first restriction.

## 2. Checkpoint starts for the host-fixture suites

Per-test times (temporary per-test timer, uncommitted, as decision 1243 did) and the tick each chain point holds:

| Suite (full run s) | Long tests | Converted? |
|---|---|---|
| `test_underground_host_crew_loss.gd` (369) | crew lost in each of 7 installer stages; crew lost while handling, plain and restored | **Yes**: both tests start after the loss point |
| `test_underground_host.gd` (274) | six of about 42 s: fixed ticks to the first gap; busy crew rests; tired crew changes shift; crew lost mid-haul; mid-phase; rest at a haul stand | No (below) |
| `test_underground_host_whole_chain.gd` (434) | restored every tick; descent to the sill; whole entry restored | No: all three assert the whole run from tick 1 (finishing tick 3462 or 8348, "never goes back to M", images of the whole run) |
| `test_entry_worker_view.gd` (7.7) | none: its chain is begun but never ticked | No: nothing to skip |

In `test_underground_host.gd`, the fixed-ticks test asserts every tick from arrival and the finishing tick; the busy
crew must finish later than DONE_TICK; the tired crew's rest declines from tick 1 to the seek line. Those keep their
replay (1240's rule). The other three lose their crew or rest at ticks 483, 642 and 447 (first trip, first paid cut,
first lift), about 5-7 s of replay each against a 1-2 s load plus about 4 s of equivalence proof per point and
0.33 MB of history per regeneration: about 18 s saved in all, not worth three more points.

**The new recipe**, `underground_spare` (`checkpoint_recipes.gd`): `underground_host_case._live_with_spare()`'s chain
(the entry begun with 7 wood and 2 stone, every eligible mole but the crew and the next benched by a tool), built by
new static helpers in `fixtures/underground_entry_chain.gd` (`eligible_moles`, `bench_all_but`, `begin_with_spare`,
`spare_of`; the case's `_eligible_moles` now delegates to the fixture). It is driven through the GameManager autoload
**one tick a frame** (33,334 us at 1x; the 20 debt units left per frame make a second tick only after 50,000 frames,
and the recipe refuses any frame that ran other than one tick), so each point is saved on the first tick it holds,
exactly where the suite's own `run_tick` loop stopped. Points: `install_0_stage_10` 1491, `install_0_stage_2` 1763,
`install_0_stage_4` 1794, `install_0_stage_5` 1855, `install_0_stage_6` 1885, `install_0_stage_7` 2245,
`install_1_stage_9` 3106. Regeneration takes about 43 s; seven 0.33 MB files.

The host suites call `run_tick` directly while the recipe goes through the clock. Nothing the chain runs before tick
13,500 (the first midnight) reads the autoload's clock except the command queue's rebind, and the chain queues no
commands; the converted tests' own end assertions (the prefix finished, DONE_LEDGER, byte-identical images) pass
from every point, which they would not if the trajectories differed.

`underground_host_case.gd`'s `_spare_from_checkpoint(point)` loads a point into the suite's host with the suite's own
actor content and returns [owners, runtime, crew, spare, next tick]; `after_each()` hands the autoload back at tick
0 when a checkpoint was loaded (decision 1236). `test_checkpoint_equivalence.gd` proves the new recipe (replay
byte-identical, every point loads and resaves identically) and gains `test_every_recipe_has_its_replay_proof`, which
fails when a recipe in `NAMES` has no proof test.

**Counts.** `test_underground_host_crew_loss.gd`: 2 tests before and after; 35,495 -> 17,723 assertions, 369 s -> 198 s.
The 17,772 assertions that went are the replayed prefixes' per-tick "the settlement tick itself never fails" and
their setup. That check now runs once per replay inside the recipe instead (review M1, below): the recipe binds a
`Stepper` that records the first tick `run_tick` refuses, and regeneration and the equivalence replay both fail on
it. (As first committed it did not: the recipe bound `run_tick` straight to the autoload, whose clock adapter
discards the bool, so a refused tick between about 643 and 3106 would have gone unseen.) `test_checkpoint_equivalence.gd`: 1 test, 17
assertions, 34 s -> 3 tests, 72 assertions, 105 s. The `underground_entry` checkpoint's bytes are unchanged (its
manifest moved with the chain fixture).

## 3. `tools/run_tests_parallel.sh`, the local full-suite gate

`./tools/run_tests_parallel.sh [--shards COUNT] [--jobs JOBS] [--output-dir DIR]`:

- `--shards` defaults to the count CI's verify step names in `.github/workflows/tests.yml` (10), so the local plan is
  CI's plan; `--jobs` defaults to **4** (about 4 x 1.3 GB and four busy cores, safe beside other lanes); 5 when the
  machine is otherwise idle;
- each shard is `./tools/run_tests.sh --shard N/COUNT --output-dir DIR`, unchanged: its own private HOME and
  `user://` (ADR 1204) and the zero allowances; xargs runs the script itself once per shard index (macOS xargs refuses
  long `-I` commands, which is why the scratch version needed a helper; the scratch version also failed when started
  by a relative path, because it changed directory before finding its helper);
- afterwards it prints each shard's exit status and summary lines, then `ci_test_shards.py verify` (also written to
  `DIR/verified.json`), and exits 0 only when every shard exited 0 **and** verify passed;
- it refuses a non-empty report directory (stale reports would be verified) and an unimported project; it is bash 3.2
  compatible (macOS).

`tools/test_run_tests_parallel.py` (13 cases, about 5 s, no Godot) runs it against a fake `run_tests.sh` and a fake
verify, and is a new step of CI's contracts job. Documented in `docs/ENVIRONMENT.md` and `docs/handoff/README.md`
section 3.4 step 3 as the recommended local gate.

## 4. Rebalance

`tools/ci_test_shard_weights.json` is now the baseline run's 489 measured suites plus focused measurements of the
eight changed suites (three at a time); `godot/test/slow_suites.json` carries the same seconds. No suite crossed 60 s
either way; `test_settlement_save_parity.gd` left the slow tier and its six parts joined it (477 fast, 18 slow).
`ci_test_shards.py` plans all 495 suites exactly once at ten shards, estimated at 480 s each (4,800 s in all).

**A suite whose time varies around the 60 s threshold.** The ORCHARD-FLAKE lane (`fix/orchard-tend-flake`, not
merged when this was measured) makes `test_demo_orchard_live.gd` wait in game time: about 40 s usually, 62-88 s when
breakfast interrupts at one or both sizes (about one run in five). On master it measured 37.8 s (baseline) and
37.3 s (final run), and this lane did not edit it. The rule this lane applies: the slow tier lists a suite when its
**typical** full-run time is over 60 s (the median of the runs measured, not one slow run), because the tier exists
for per-commit turnaround and a suite that is usually 40 s belongs to it; the shard weight records the measured time
it was given. So the orchard suite stays fast, with its master time as its weight. After that branch merges,
re-measure it in a full run; list it only if its median crosses 60 s.

## 5. Result: the final run (fdf9d421, art-free, freshly imported, `./tools/run_tests_parallel.sh`, 4 jobs)

```text
ok: 495 suite files executed exactly once across 10 shards
{"counts": {"assertions": 1228181, "expected": 278, "failures": 0, "leaked_objects": 0, "leaked_resources": 0,
 "tests": 12340, "tolerated": 373, "unexpected_errors": 0, "unexpected_warnings": 0}, "shard_count": 10,
 "suite_count": 495, "wall_seconds": [518, 513, 518, 521, 470, 493, 481, 477, 478, 479]}
wall seconds: 1481; load after: 6.36 6.11 6.59
ok: every shard passed and verify passed.
```

Every shard printed `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`

- **The shard floor: 625 s -> 521 s** (the slowest shard; the spread is now 470-521 s instead of one 625 s shard and
  nine of 455-470 s).
- **Tests: 12,333 -> 12,340** (+5: the parity test is six; +2: the spare recipe's proof and the every-recipe guard).
- **Assertions: 1,245,495 -> 1,228,181** (-17,314): parity +398 (58 -> 6 x 76), crew loss -17,772, equivalence +55,
  `test_checkpoint_store.gd` +3 (its freshness check iterates the recipes), and `test_demo_layout_live.gd` +2, a live
  suite whose count varies between runs (the coordinator's reference run differed from this lane's baseline by 4).
- Per suite (full runs, before -> after): parity 620 -> 6 x 124-126; crew loss 369 -> 182; equivalence 34 -> 94.
  Unchanged suites ran about 3-6% slower in the final run (whole chain 434 -> 459, host 274 -> 293): the machine
  carried the other lanes' runs (load 6-9 against 4-7). Suites together 4,757 -> 4,889 s.
- **Wall time 1,397 s -> 1,481 s at 4 jobs.** At four jobs ten shards run in three waves, so the local wall time
  follows total work over the jobs, not the floor; the parity parts add about 140 s of replayed ticks, saves and
  loads, and the load was higher. The floor is what bounds CI (ten runners at once) and a 5-job local run (two waves).

## Mutation tests (one mutant per run)

- **The tool: 17 of 17 killed** by `tools/test_run_tests_parallel.py` (skip shard 0; a fixed `/10` shard count; `-P
  1`; ignoring a shard's exit status; ignoring verify; ignoring shard failures; a fixed verify count; accepting a
  non-empty directory; ignoring the workflow's count; a status file that always says 0; default jobs 1; accepting
  `--shards 0`; skipping the import check; exit 0 on failure; usage exiting 0; accepting a missing option value;
  dropping the summary lines). One survived the first round (a missing option value at the end of the line) and a
  case was added for it.
- **The parity split: 3 of 3 killed** (every member in part 0: "every part fingerprints members [623, 0, ...]";
  `restrict()` keeping every member: "part 1 hashes its own members (expected 100, got 623)"; the loaded run
  restricted to the next part: "first difference at 3001"); the review's M2 mutant (a suite passing another part's number) is killed too: 4 of 4.
- **The review fixes' own mutants: 5 of 5 killed** (M1 refusal at tick 1000, M2, L1, L2, and L4's check removed).
- **The checkpoint starts: 5 of 7 killed** in the first round, **7 of 7 after the review fixes (L1, L2)** (`spare_of` not excluding the crew; the spare benched too; the stage
  condition at `> 2`; three-tick frames; the spare recipe's proof test renamed). First round, SURVIVED_MUTANTS: 2 (both killed now; **SURVIVED_MUTANTS: 0**).
  (a) `_spare_from_checkpoint` returning the loaded tick instead of the next one shifts the rest of the run by one
  tick; the crew-loss tests assert the finish, ledgers and plain-against-restored images, none of which depends on
  the exact loss tick, which was equally true of the replayed version. (b) Not handing the autoload back in
  `after_each()` passes inside the suite; the harm (a later suite's commands stamped past its clock, decision 1236) is
  outside it.

## Independent review (2026-10-12) and resolutions

The coordinator's reviewer found nothing CRITICAL or HIGH. Every MEDIUM and LOW is fixed on top of d0898ef4:

- **M1, the per-tick refusal check was not moved.** `checkpoint_recipes.gd` now binds `Stepper.step`, which runs
  `run_tick` and remembers the first refused tick; `_drive_underground` and `_drive_spare` stop there and set
  `built.error` ("the settlement refused tick N"). Regenerated: **every `.rwlsave.gz` is byte-identical**; only the two
  manifests changed (the recipe script is a fingerprint root). Mutant: a step that refuses tick 1000 fails both
  equivalence proofs ("underground_spare: the settlement refused tick 1000").
- **M2, a part suite could fingerprint another part.** `settlement_save_parity_case.gd`'s `_assert_suite_files(part)`
  requires the running script's path to be `PART_SUITE % (part + 1)` and stops the test when it is not. Mutant:
  `_parity_2` calling `_check_part(0)` fails at once ("this suite fingerprints its own part, 1").
- **L1, survivor (a).** `_lose_and_resume` asserts the loss tick is the manifest point's tick + 1. The off-by-one
  mutant now fails ("expected 1492, got 1491").
- **L2, survivor (b).** After each explicit `after_each()` the crew-loss tests assert the autoload clock is back at
  tick 0. The no-release mutant now fails ("expected 0, got 1491").
- **L3, independent partitions.** Chosen: each part prints a digest of the member names and their parts in its
  coverage line (`partition 852e831fede0e32a` in all six at this commit), so CI logs show they agree. Partitioning
  is still by bytes at bind time, which balances the parts; a member-name-only partition would not.
- **L4.** `ci_test_shards.make_plan()` refuses a weight naming no suite, as `slow_suites()` does; a new planner test
  covers it, and removing the check fails that test.
- **L5.** A refused rebind after a save sets `built.error` (the shared `_bind()`).
- **L6.** The jobs test sleeps 1.5 s per fake and accepts 2-3 overlapping shards at `--jobs 3` (exactly 1 at
  `--jobs 1`); the tool's mutants are still 17 of 17 killed.

Counts after the fixes: each parity part 77 assertions (one more: the suite-path check); crew loss 17,740 (+9 loss
tick checks, +8 clock checks); the full-suite total moves by +6 x 1 + 17 = +23 assertions over the final run above,
with the same 12,340 tests.

## Proposal 4 carried out: CI weights refreshed from CI (2026-10-12)

Per Brendan's ruling on proposal 4, `tools/ci_test_shard_weights.json` was regenerated from the first master CI run
after this lane merged (run 38307575838, PR #251's merge, all ten shard artifacts):
`python3 tools/ci_test_shards.py weights --reports <the ten shards' reports> --count 10 --output tools/ci_test_shard_weights.json`.
The reports verified first: `ok: 495 suite files executed exactly once across 10 shards`, 12340 tests, 0 failures.

- That run's shard walls on the local-seconds weights: [702, 1127, 1049, 1116, 797, 753, 848, 980, 855, 842] s.
- The plan with the CI weights estimates [907, 895, 895, 895, 895, 895, 895, 895, 895, 895] s: the slowest CI shard
  about 220 s shorter.
- The local parallel runner reads the same weights, so its shards are now balanced for the runner, not the Mac;
  the Mac runs a suite 1.1x to 3.2x faster than the runner (1243), so local shards may be somewhat less even.

## Gates

- The final parallel run above (art-free, `godot/.godot` deleted and re-imported at fdf9d421).
- Focused: all six parity parts `ok: 2 tests, 152 assertions, 0 failures.` (three runs);
  `test_underground_host_crew_loss.gd` `ok: 2 tests, 17723 assertions, 0 failures.`;
  `test_checkpoint_equivalence.gd` `ok: 3 tests, 72 assertions, 0 failures.`; `test_checkpoint_store.gd` passed in
  the full run (8 tests, 36 assertions).
- `./tools/regenerate_test_checkpoints.sh`: `ok: 2 checkpoint(s) written` (underground_entry bytes unchanged).
- `python3 tools/gdscript_warnings.py --max 0 --port 6393`: `0 GDScript warning(s) in 0 of 1509 file(s)`.
- `python3 tools/underground_memory_budget.py --check`: pass (no runtime bytes changed).
- `python3 docs/validation/ready07_arithmetic.py`: `"status": "PASS"`.
- `python3 docs/validation/decision_numbers.py`: `PASS -- 545 records, 0 problem(s)`.
- `python3 tools/lane_notes.py --check`: `PASS -- 64 lane record(s), 0 problem(s)`.
- `python3 tools/test_ci_test_shards.py`: `OK (skipped=5)`; with `--godot`: `Ran 20 tests ... OK`.
- `python3 tools/test_run_tests_parallel.py`: `Ran 13 tests ... OK`.
- `ci_test_shards.py`: the ten-shard plan assigns all 495 suites exactly once; tiers 477 fast + 18 slow.
- After the review fixes (focused, at most three processes): parity parts 1-3 and 4-6 each
  `ok: 3 tests, 231 assertions, 0 failures.`; crew loss, equivalence and store together
  `ok: 13 tests, 17848 assertions, 0 failures.`; `test_ci_test_shards.py` `OK (skipped=5)`;
  `test_run_tests_parallel.py` OK; analyzer `0 GDScript warning(s) in 0 of 1509 file(s)`; memory budget, ready07,
  decision numbers and lane notes pass. No full run: the fixes reach only these suites and tools.

## PROPOSALS (for Brendan)

1. **Local shard count.** With 4 jobs, CI's 10 shards run in three waves (about 3 x 480 s). Options: (A) keep CI's
   count as the default, the same plan CI verifies; (B) default to twice the jobs (8 shards at 4 jobs is two waves of
   about 600 s, roughly 4 minutes faster); (C) default to 5 jobs (two waves of about 480 s). Recommendation: A, and
   pass `--jobs 5` when nothing else is running.
2. **The next single-suite floor** is `test_underground_host_whole_chain.gd` (434 s) and
   `test_underground_paid_assembly_handling.gd` (389 s). None of their long tests can start from a checkpoint (whole
   run, or harness worlds). Options: (A) split each into one suite per long test, as decision 1243 did; (B) leave
   them. Recommendation: B until a CI shard nears the 30-minute guard; they are below the 480 s average now.
3. **Checkpoint history.** `underground_spare` adds seven 0.33 MB files whenever a source change moves the chain
   before tick 3106 (with `underground_entry`, about 3 MB per such regeneration). Options: (A) keep committing them;
   (B) decision 1240's alternative, an uncommitted cache keyed by the same fingerprint, rebuilt on first use (one
   43 s replay per CI shard that needs it). Recommendation: A for now; revisit if the repository grows by more than
   about 50 MB from checkpoints.
4. **CI weights.** These weights are local seconds. Options: (A) refresh them from the first CI run of this branch
   (`ci_test_shards.py weights --reports <downloaded artifacts> --count 10`); (B) keep local timings. Recommendation:
   A, since runner time per suite varies from 1.1x to 3.2x the Mac's (decision 1243).
