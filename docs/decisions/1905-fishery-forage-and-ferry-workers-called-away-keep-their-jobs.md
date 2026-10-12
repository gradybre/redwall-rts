# 1905 — Fishery, forage and ferry workers called away keep their jobs (MEAL-CALLAWAY)

Date: 2026-10-12 · Status: Accepted (engineering record of BACKLOG packet MEAL-CALLAWAY)

Number range: 1905–1909 was allocated to this lane by the coordinator. This lane uses 1905 only.

## Context and approval

Decision 1900 found that the orchard lost a player's order when a meal's call, the night or another order took its
worker. Its task kept nothing to come back to (resident_brain.gd RESUMING, decision 0205), so the work board's promise
(decision 0411) never held the job. The fishery (`fishery_task.gd`, source 7), the ferry (`ferry_task.gd`, source 8) and
the forage (`forage_task.gd`, source 12) had the same gap. On 2026-10-12, in chat via AskUserQuestion, Brendan ruled
**"Fix all three next"** (decision 1900, "Brendan's rulings"; RULINGS.md 2026-10-12). The packet is this lane's brief.

## Decision

Each owner gets what 1900 gave the orchard:

- **`called_away(j, serial, brain) -> bool`** (`fishery.gd`, `forage_trips.gd`, `ferry.gd`). It returns whether the
  worker keeps the job: true when the owner let it go here (an order, a meal, the night, a release). It returns false
  for a walk it could not finish (`_unreached`: the job waits `RETRY_USEC` and is offered to anyone), and when the job
  is no longer this worker's. Each owner's existing rule for which failed walks count as unreached stands: the forage
  treats a failure while gathering as a let-go, and the ferry counts only its walking steps.
- **`unfinished_of(j, serial)`** makes the order-list entry (`unfinished_job.gd`). It names the owner's source and the
  job's serial, so the work board leaves the job to that resident. It returns null once the job is over. The words
  match the Work screen's action and target: "Mill grain, the mill", "Forage herbs, the herb bank", "Gather windfall,
  the far copse". They are built in the owners, not in their text files as the packet guessed, because that is where
  the Work screen's words come from.
- **`take_back(brain, j, serial)`** claims the job again, through the owner's own `claim`, only while it is the same job
  and is waiting. **The packet's pitfall:** a boat seat, a foraging party's seat or a ferry crew place refilled while
  its worker was away is not waiting, so it is refused, and nobody is displaced. The work board never gives a promised
  job away, but each owner's own hand-out can: Authorise with residents selected, a party order, Send the ferry. A
  paused job, or one waiting out a failed walk, is refused the same way.
- **Each task's `unfinished()`** (`fishery_task.gd`, `forage_task.gd`, `ferry_task.gd`) works as the orchard task's
  does. Asked before a call-away, it answers the job while it lasts, so the action card now says "goes back to it
  after". After a call-away, it answers only a job the owner let its worker keep: not a lost walk, and not one taken by
  the board's own Pause or Reassign, where the owner lets go first and `called_away` finds no worker.

Load rules are unchanged. A load in hand is still delivered before the night or a meal takes its carrier (each
`must_finish`). An order that takes a carrier still sets the load down for whoever comes next, now first of all the
carrier itself.

## Tests (one set per suite; deterministic, art-free, no scene tree)

`test_demo_fishery.gd`, `test_demo_forage.gd`, `test_demo_ferry.gd`:

- **Kept and promised through the REAL work board:** `test_a_miller_called_away_keeps_the_job_promised_on_the_work_board`,
  `test_a_forager_called_away_keeps_the_seat_promised_on_the_work_board`,
  `test_a_gatherer_called_away_keeps_the_job_promised_on_the_work_board`.
  - The worker is a quarter into the mill's grinding, the herbs' gathering or a windfall pile's gathering. The card
    says RESUMES. The worker is then called away by an order, the path a meal's call takes.
  - The job is kept: `promises(source, key)`, with the order list's words.
  - It waits, and another resident is eligible for it. Yet with `work_board.gd` bound to every resident and the owner's
    adapter, `rebuild_index` followed by `consider` for every resident gives it to nobody.
  - After `work_done()` it is hers again. Back at work, the work step is the same (`need` unchanged) and the work done
    carried over (at least what it was, and less than one frame's work more).
- **Nothing kept:** `test_a_fishery_job_lost_on_the_way_paused_or_reassigned_keeps_nothing`,
  `test_a_seat_lost_on_the_way_paused_or_reassigned_keeps_nothing`,
  `test_a_ferry_job_lost_on_the_way_paused_or_reassigned_keeps_nothing`. Pause and Reassign leave the order list empty.
  A walk given up (trip failed) leaves it empty too, and the job waits `RETRY_USEC` with one try counted.
- **Stale:** `test_a_kept_fishery_job_cancelled_is_stale`, `test_a_kept_seat_cancelled_is_stale`,
  `test_a_kept_ferry_job_cancelled_is_stale`. A kept job the player cancels, its row reused by the next order, is
  neither taken back nor kept again, and the new job is not hers.
- **The pitfall:** `test_a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back`,
  `test_a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back`,
  `test_a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back`. The seat or crew place is kept, then refilled
  through the owner's `claim`. `take_back` refuses it, and after her `work_done()` the other resident still has it.
- `test_demo_forage.gd`'s `_run` takes `board: bool`, as the fishery's and the ferry's already did. With it false, the
  rig's simple hand-out does not give a promised seat away.

**Each test fails without its fix.** The mutant "`unfinished()` always null" is the packet's "before" state; the
orchard's fix was absent from these tasks. It fails 3 tests in each suite: the main test, the stale test and the
pitfall test. The nothing-kept test passes without the fix, as it must: before the fix nothing was ever kept. It is
killed by its own mutants, "a lost walk is kept", "cancel never marks the task called away" and "unfinished ignores
the keep flag".

## Mutation testing (one mutant per run; the owner's focused suite)

**42 of 42 killed, no survivors.** For each owner, the mutant at file:line, then what killed it (the suite's new tests:
M main, N nothing-kept, S stale, P pitfall).

The fishery (`test_demo_fishery.gd`):

- `fishery.gd:977` `return true` → `return false` (called away keeps nothing): M, S, P.
- `fishery.gd:975` after `_unreached`, `return false` → `return true` (a lost walk kept): N.
- `fishery.gd:985` the `is_job` guard in `unfinished_of` removed: S.
- `fishery.gd:995` the `is_job` guard in `take_back` removed: S.
- `fishery.gd:995` `take_back` never claims (`and false`): M.
- `fishery.gd:995` `take_back` forces the worker in place of `claim` (no waiting test): M, P.
- `fishery.gd:988` `SOURCE_FISHERY` → `SOURCE_FARM`: M, P.
- `fishery.gd:988` the entry's key `serial` → `j` (the row): M, P.
- `fishery.gd:877` `_let_go` also zeroes `j_mwu` (the work done lost): M.
- `fishery.gd:1001` the words' `", "` → `" "`: M.
- `fishery_task.gd:54` `_called_away = true` → `pass`: N.
- `fishery_task.gd:63` `unfinished()` ignores the keep flag: N.
- `fishery_task.gd:63` `unfinished()` always null (the fix absent): M, S, P.
- `work/fishery_work.gd:34` `key()` returns the row: M.

The forage (`test_demo_forage.gd`):

- `forage_trips.gd:750` called away keeps nothing: M, S, P.
- `forage_trips.gd:748` a lost walk kept: N.
- `forage_trips.gd:758` `unfinished_of` without its guard: S.
- `forage_trips.gd:768` `take_back` without its guard: S.
- `forage_trips.gd:768` `take_back` never claims: M.
- `forage_trips.gd:768` `take_back` forces the worker: M, P.
- `forage_trips.gd:761` the wrong source: M, P.
- `forage_trips.gd:761` the entry names the row: M, P.
- `forage_trips.gd:695` `_let_go` zeroes `j_mwu`: M, and the existing `test_an_interruption_loses_nothing_and_another_finishes`.
- `forage_trips.gd:760` the words: M.
- `forage_task.gd:54` the call-away mark: N.
- `forage_task.gd:63` the keep flag ignored: N.
- `forage_task.gd:63` always null: M, S, P.
- `work/forage_work.gd:33` `key()` returns the row: M, and the existing `test_the_work_board_reads_the_seats`.

The ferry (`test_demo_ferry.gd`):

- `ferry.gd:812` called away keeps nothing: M, S, P.
- `ferry.gd:810` a lost walk kept: N.
- `ferry.gd:820` `unfinished_of` without its guard: S.
- `ferry.gd:830` `take_back` without its guard: S.
- `ferry.gd:830` `take_back` never claims: M.
- `ferry.gd:830` `take_back` forces the worker: M, P.
- `ferry.gd:823` the wrong source: M, P.
- `ferry.gd:823` the entry names the row: M, P.
- `ferry.gd:759` `_let_go` zeroes `j_mwu`: M.
- `ferry.gd:822` the words: M.
- `ferry_task.gd:54` the call-away mark: N.
- `ferry_task.gd:63` the keep flag ignored: N.
- `ferry_task.gd:63` always null: M, S, P.
- `work/ferry_work.gd:32` `key()` returns the row: M.

## Gates

- Focused suites (`test_demo_fishery.gd`, `test_demo_forage.gd`, `test_demo_ferry.gd`, `test_demo_forage_outings.gd`,
  `test_demo_work.gd`, `test_demo_work_edges.gd`, `test_demo_action_cards.gd`, `test_demo_kitchen.gd`), staged and
  art-free (`godot/demo/assets` moved aside, then restored): each `319 test(s), 3041 assertion(s), 0 failure(s)`,
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s),
  0 resource(s)`.
- `./tools/run_tests.sh --fast` (staged, once, at the end): `12199 test(s), 1130436 assertion(s), 0 failure(s)`;
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 310 tolerated; leaked at exit: 0
  object(s), 0 resource(s)`; `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0
  resource(s).`
- Analyzer (port 6397): `0 GDScript warning(s) in 0 of 1509 file(s)`.
- `underground_memory_budget.py --check`: exit 0. `ready07_arithmetic.py`: `"status": "PASS"`. `decision_numbers.py`:
  `PASS -- 547 records, 0 problem(s)`. `dispatch_plan.py --validate`, `lane_notes.py --check`
  and `merge_gate.py`: PASS.

## Notes

- **No pinned file was touched.** The owners, tasks and tests are demo code.
- **A promised seat holds a trip.** While a fisher, forager or helm is away at a meal, the work board leaves their seat
  or crew place to them (0411), so a boat waits at the jetty, or a crossing at its stage, for its crew to come back.
  This is the resume rule's intended cost, the same as the farm's, the woods' and now the orchard's. The owner's own
  orders can still fill the place at once, and the returning worker then steps aside.
