# 1900 — The orchard tending flake: an orchard worker called away keeps its job

Date: 2026-10-12 · Status: Accepted (engineering record of the ORCHARD-FLAKE lane; Brendan asked for the lane on
2026-10-12: "Start party compact, and test speed and orchard test")

Number range: 1900–1904 was allocated to this lane by the coordinator. This lane uses 1900 only.

## Context

`test_demo_orchard_live.gd` failed now and then with "the apple is tended in game time: FAIL after 2400 frames". In the
failing runs the tend job had lost its worker (`worker -1`). Decision 1871 measured it failing 2 of 5 runs on slice B's
branch, 2 of 8 at bbbb3207 and 1 of 8 at master 1cfe1e3c, so it was older than slice B. BACKLOG.md's FOLLOW-UPS asked
its owner to find the cause.

## Brendan's rulings (2026-10-12)

Relayed by the coordinator. On 2026-10-12, in chat via AskUserQuestion, Brendan was asked: "Fishing, foraging and the
ferry have the same bug the orchard had … Fix them the same way?" He answered **"Fix all three next"**: a small
follow-up lane right after this fix merges, giving `fishery_task.gd`, `forage_task.gd` and `ferry_task.gd` the
orchard's three functions, each job type with a test. It is BACKLOG.md's packet **MEAL-CALLAWAY**; this lane does not
implement it.

## The cause

**Breakfast's call takes the tender off the apple, and the orchard keeps nothing for her to come back to.**

1. The harness selects resident 0, clicks Tend, and runs the village at 4x from 06:00. She walks to the apple and starts
   the 20 WU at tick 922 (07:14) in every run. Left alone she finishes at tick 1172–1176 (07:34).
2. In some runs a stand-in cook takes the kitchen's round at 07:00 (tick 750). The first batch is then cooking by about
   tick 960, so breakfast is "on its way" (`kitchen.gd meal_coming`), and at tick 960–975 (07:17) the kitchen calls
   every resident to the table (`_call_diners`). In the other runs nobody takes the round until 08:00 (tick 1500), and
   no call comes while she works.
3. The call reaches the orchard through the brain:
   `kitchen._call_diners → _start_role → resident_brain.order_task → _drop_task → orchard_task.cancel →
   orchard_jobs.called_away → _let_go`. The job goes back on the board with `worker -1` (4,170 of 20,000 mWU done,
   kept). Then `_drop_task` asks the task for the job to come back to (`remember_unfinished(task.unfinished())`). The
   orchard's task did not override `unfinished()`, so the base answered null and **nothing was kept**.
4. The kitchen's own header says a called diner's job is "PARKED on its resume queue (decision 0205)". The farm, the
   woods, the hall, the kitchen, the tunnel jobs, installs and the spoil crew all keep one (RESUMING, decision 0205;
   the work board's promise, decision 0411). The orchard (0671) never joined; nor did the fishery, the forage or the
   ferry (see "Follow-ups"). After breakfast resident 0 went back to
   her routine, and the job waited for whoever the board offered it to. In the failing runs that was resident 7, at
   about tick 1995 (08:40), when the 2,400-frame wait ran out.

**Why only some runs.** The demo's presentation clock is real frame time × speed (decision 0196), and route planning is
budgeted in real microseconds per frame (decisions 0361, 1001). So the village's exact state at 07:00 (who is free, how
much water has been drawn) varies with machine load, and with it whether a stand-in cook starts breakfast before 08:00.
That variation is by design. The bug is that the orchard lost the player's order to an interruption that the farm,
the woods, the hall and the tunnel jobs survive. **The harness's 2,400-frame bound was also wall-clock dependent:** how much game time a frame passes
depends on the load.

**Evidence.** Temporary prints (removed before committing) gave the calendar tick at each let-go, each meal call, each
cook hand-out, each claim, the start of each work step and the tending. `Engine.capture_script_backtraces()` at
`_let_go` gave the stack above. Over 64 instrumented runs (staged, 4 at a time) 12 failed. All 12 had the 07:17
breakfast call and a let-go of job 0 at the same tick. None of the 52 passing runs had a call before the tending was
done.

## The fix

- **`orchard_task.gd` `unfinished()`** returns the job to come back to (the board's `unfinished_of`). Before the brain
  calls it away, it answers the job while it lasts, so the action card now says "goes back to it after". After, it
  answers only a job the board let the resident keep: not a walk it could not finish, nor a job the board itself took
  away (Pause, Reassign: `called_away` finds another worker, or none, and keeps nothing).
- **`orchard_jobs.gd`**: `called_away` returns whether the worker keeps the job. `unfinished_of(j, serial)` makes the
  entry (`unfinished_job.gd`, naming source 13 and the job's serial, so the work board leaves it to that resident,
  0411). `take_back(brain, j, serial)` claims it again only while it is the same job and waits. A new header section,
  CALLED AWAY, says so.
- **`orchard_text.gd` `order_words`**: the order list's words, "Tend, the old apple".
- **The harness** (`test/live/demo_orchard_live.gd`) waits on game state, not frames. It runs until the apple is tended,
  with the bound **TEND_BY_HOUR, 14:00 game time on day 1** (read from `meal_rules.gd`: the hour before supper's
  `COOK_FROM_HOUR`, 15:00) and a stopped-clock guard: it gives up if the calendar does
  not move for 600 frames, so it fails rather than hangs. The bound comes from the rules and the measured runs. The walk
  is about an hour and the work a third of an hour. Breakfast may keep her from 07:00 to its end at 09:00 (meal_rules.gd
  `CALL_HOUR`, `END_HOUR`). Her walk back from the hall is about two hours. Done by about 11:30; the latest of this
  lane's runs was 11:28 (tick 4098). 14:00 leaves two and a half hours in hand. A LIVE check, "the bound leaves her
  time after breakfast", requires `END_HOUR[0] + RETURN_HOURS (3) <= TEND_BY_HOUR`, so a change to the meal hours
  cannot leave the bound stale silently. It replaces a frame count, not a budget of the same kind. The harness also proves more than before: a new check, **"the
  selected resident tended it"**, records the last worker seen on the job, and it must be resident 0.

The village itself still decides, from run to run, whether breakfast interrupts the tending. Both paths are now
correct and both pass. The deterministic proof of the interrupted path is the unit test below, not the live run.

## Tests

`test_demo_orchard.gd` (art-free, no scene tree; the real cast on the real layout):

- `test_a_tender_called_away_comes_back_to_her_tree`: **the failure scenario, deterministic.** Resident 0 at work on
  the apple is handed another task, the path the kitchen's call takes. The job is let go but stays on the board, kept
  on her list as "Tend, the old apple" and naming source 13 with its serial. The card says RESUMES. With the board's
  hand-out off, as the work board leaves a promised job alone, she takes it back. Interrupted a quarter into the work,
  she is back at it with the same step (`need_mwu` unchanged) and the work done carried over (`done_mwu` at least what
  it was and less than one frame's work more), and she tends it. **It fails without the fix** (`FAIL test_a_tender_called_away_comes_back_to_her_tree`, 1 failure).
- `test_a_job_the_board_takes_away_or_a_lost_walk_is_not_kept`: Pause and Reassign keep nothing. A walk given up
  (trip failed) keeps nothing, and the job waits `RETRY_USEC` with one try counted.
- `test_a_kept_job_cancelled_is_stale`: a kept job the player cancels, its row reused by the pear's tending, is neither
  taken back nor kept again.
- `test_a_called_away_tender_is_promised_on_the_real_work_board` (added after review): the same through the REAL work
  board (`work_board.gd` with `orchard_work.gd`, as `test_demo_work_edges.gd` does for tunnel jobs). Called away by an
  order, she `promises(SOURCE_ORCHARD, key)`; with the index rebuilt, `consider` gives the job to none of the other
  idle residents; after her `work_done()` it is hers again.
- `_run` takes `board: bool`. With it false, the rig's simple hand-out does not give a promised job to someone else.

## Failure rate, before and after

The harness alone (`godot --headless --path godot --script res://test/live/demo_orchard_live.gd`, sizes alternating):

- **Before, staged, 4 at a time:** 12 of 64 with temporary prints (prints only), then 2 of 16 clean. In all, **14 of 80
  (17.5%)**.
- **Before, staged, one at a time (light load):** 0 of 10.
- **Before, art-free, 4 at a time:** 0 of 40. The placeholder cast's timeline did not meet the 07:00 race in these runs.
  The unit test covers the path art-free.
- **After, staged, 2 or 4 at a time:** **92 of 92 passed**: 64 plain runs (24 with an earlier draft's bound of noon,
  12 of them with temporary claim prints) and 28 with `--verbose`. 21 went through the breakfast path, each tended by
  resident 0 between 11:01 and 11:28 (ticks 3763–4098). She took the job back at ticks 2349–2631 (09:08–09:30).
- **Harness mutant (the fix reverted, `unfinished()` always null), 16 runs:** two took the breakfast path. One failed
  "the selected resident tended it: FAIL resident 7". In the other, resident 0 happened to be the one the board gave it
  back to. The live check catches the bug only when someone else picks the job up, so the unit test is the reliable
  guard.

The suites (`./tools/run_tests.sh --suite test_demo_orchard_live.gd --suite test_demo_orchard.gd`, two at a time):

- **Staged: 16 consecutive passes**, each `53 test(s), 2791 assertion(s), 0 failure(s)` and `diagnostics: 0 unexpected
  error(s), 0 unexpected warning(s)`. The live suite took 40 s in 10 runs, 62–64 s in 5 (a breakfast path at one size)
  and 88 s in 1 (both sizes).
- **Art-free (`godot/demo/assets` moved aside): 16 consecutive passes**, the same lines.

## Gates

- `./tools/run_tests.sh --suite test_demo_orchard.gd`: `52 test(s), 2747 assertion(s), 0 failure(s)`; `diagnostics: 0
  unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
- The related suites (`test_demo_orchard_remainders_live.gd`, `_ui`, `_remainders`, `test_demo_hives.gd`,
  `test_demo_action_cards.gd`, `test_demo_spoil.gd`, `test_demo_no_u_text.gd`, `test_demo_kitchen.gd`): `240 test(s),
  3585 assertion(s), 0 failure(s)`, 0 unexpected, 0 leaks.
- `./tools/run_tests.sh --fast` (staged, once, at the end): `12186 test(s), 1130306 assertion(s), 0 failure(s)`;
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 310 tolerated; leaked at exit: 0
  object(s), 0 resource(s)`; `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0
  resource(s).`
- Analyzer (port 6395): `0 GDScript warning(s) in 0 of 1503 file(s)`.
- `underground_memory_budget.py --check`: exit 0 (no pinned file touched). `ready07_arithmetic.py`: `"status": "PASS"`.
  `decision_numbers.py`: `PASS -- 545 records, 0 problem(s)`. `merge_gate.py` and `lane_notes.py --check`: PASS.
- **Mutation testing**, one mutant per run against `test_demo_orchard.gd`: **10 of 10 killed**. The mutants: called
  away keeps nothing; a lost walk kept; `unfinished_of` without its job guard; `take_back` without its job guard; the
  wrong board source; `take_back` never claims; cancel never marks the task called away; `unfinished()` ignoring the
  keep flag; `unfinished()` always null; the order words. Plus the harness mutant above. No survivors.

## The independent review of e336ef53, and what was done

The coordinator's independent review found nothing CRITICAL or HIGH. Its findings, each fixed on top of e336ef53:

- **MEDIUM 1: "nothing lost" could not fail.** The mutant `need_mwu[j] = 0` in `_let_go`'s non-carrying branch
  survived: the test read `done_mwu` while she was still walking back, and `_open_work` resets the progress only on
  arrival. Now the test interrupts her a quarter into the work, runs until she is at work again, and requires the same
  `need_mwu` and `done_mwu` carried over (at least what it was, less than one frame's work more). Killed, and so is
  `done_mwu[j] = 0` in the same place.
- **MEDIUM 2: no test used the promise through the REAL work board.** Added
  `test_a_called_away_tender_is_promised_on_the_real_work_board` (see Tests). It kills the mutant "`orchard_work.gd`
  `key()` returns the row, not the serial", and the mutant "the entry names the row".
- **LOW 3: TEND_BY_HOUR could go stale.** It is now read from `meal_rules.gd` (`COOK_FROM_HOUR[1] - 1`), and a LIVE
  check requires `END_HOUR[0] + RETURN_HOURS <= TEND_BY_HOUR`.
- **LOW 4: the orchard was not "alone".** The fishery (source 7), the ferry (8) and the forage (12) have the same gap.
  The wording here and in BACKLOG.md is corrected, and the PROPOSAL was widened to all three. Brendan ruled on it
  (above).
- **LOW 5: the slow-tier question** is recorded as handed over to TEST-SPEED (Follow-ups).

After the fixes: `./tools/run_tests.sh --suite test_demo_orchard.gd` printed `53 test(s), 2760 assertion(s), 0
failure(s)`, 0 unexpected, 0 leaks. Four consecutive suite runs (`test_demo_orchard_live.gd` with
`test_demo_orchard.gd`, one at a time) passed staged and four art-free, each `55 test(s), 2814 assertion(s), 0
failure(s)` and `diagnostics: 0 unexpected error(s), 0 unexpected warning(s)`. The live suite took 37–41 s, or 62–64 s
on a breakfast path. The analyzer, `underground_memory_budget.py --check`, `ready07_arithmetic.py` and
`decision_numbers.py` passed again (lines as in Gates). **Mutation:** the 4 new mutants were killed, and the 10 earlier
ones are still killed against the stronger tests: **14 of 14**.

## Follow-ups

- **Exit leaks in the harness's own process.** Two of the 64 plain runs after the fix printed "2 ObjectDB instances
  were leaked at exit", both on the breakfast path. One unfixed run (not on that path) printed 6, the same transient
  decision 1871 saw in `test_modular_demo_live.gd`'s child. None of 28 `--verbose` runs (8 on the breakfast path) leaked,
  nor 16 more plain runs (6 on it), so the leaked classes could not be named. The fix adds no reference cycle: an entry
  holds the board, and the board holds its tasks, which hold it only weakly. The brain's `drop_jobs` clears entries
  when its actor is freed. The live wrapper does not read the child's leak line.

- **The fishery's, the forage's and the ferry's tasks have the same gap** (ruled: "Fix all three next", see
  "Brendan's rulings"; BACKLOG MEAL-CALLAWAY) (`fishery_task.gd`, source 7;
  `ferry_task.gd`, source 8; `forage_task.gd`, source 12: none overrides `unfinished()`). A worker of theirs called to
  a meal or by another order loses the job to the board in the same way. Their owners get the orchard's three
  functions (`called_away` returning the keep, `unfinished_of`, `take_back`) in that lane, not this one.
- **The live suite's time**: about 40 s, but 62–88 s when breakfast interrupts the tending at one or both sizes (about
  one run in five). The slow tier's threshold is 60 s (`slow_suites.json`, decision 1240). **Handed over:** TEST-SPEED
  (its decision 1895 §4) keeps `test_demo_orchard_live.gd` in the fast tier by its median time (about 38–40 s).
  Re-measure after both lanes merge.
