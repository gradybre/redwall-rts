# 1905 — Fishery, forage and ferry workers called away keep their jobs (MEAL-CALLAWAY); a trip doesn't wait

Date: 2026-10-12 · Status: Accepted (engineering record of BACKLOG packet MEAL-CALLAWAY, its independent review, and
Brendan's ruling "Trip doesn't wait")

Number range: 1905–1909 was allocated to this lane by the coordinator. This lane uses 1905 only.

## Context and approval

Decision 1900 found that the orchard lost a player's order when a meal's call, the night or another order took its
worker. Its task kept nothing to come back to (resident_brain.gd RESUMING, decision 0205), so the work board's promise
(decision 0411) never held the job. The fishery (`fishery_task.gd`, source 7), the ferry (`ferry_task.gd`, source 8) and
the forage (`forage_task.gd`, source 12) had the same gap.

## Brendan's rulings (2026-10-12)

Both rulings were made in chat via AskUserQuestion and relayed by the coordinator.

1. **"Fix all three next"** (decision 1900's PROPOSAL): give the fishery, the forage and the ferry the orchard's three
   functions, each with a test. That is this packet.
2. **"Trip doesn't wait"**, on this record's PROPOSAL, and **not** the recommended option. Brendan was asked whether a
   fishing boat or a ferry crossing should wait for a worker called away to a meal, or whether a departing trip should
   give her place to someone else. The option he chose reads: "When a trip is ready to leave, a place held for an
   absent worker is released to anyone idle (a separate small change and ruling)." It is built below for the
   shared-trip places only: the fishery's boat seats, the forage party's seats and the ferry's crew place. Solo work
   keeps its promise, as ruling 1 decided.

## Decision

### Each owner keeps its worker's job (ruling 1)

- **`called_away(j, serial, brain) -> bool`** (`fishery.gd`, `forage_trips.gd`, `ferry.gd`) returns whether the worker
  keeps the job.
  - It returns true when the owner let the worker go here: an order, a meal, the night or a release.
  - It returns false for a walk she could not finish (`_unreached`: the job waits `RETRY_USEC` and is offered to
    anyone), and when the job is no longer hers.
  - Each owner keeps its own rule for which failed walks count as unreached: the forage treats a failure while
    gathering as a let-go, and the ferry counts only its walking steps.
- **`unfinished_of(j, serial)`** makes the order-list entry, naming the owner's source and the job's serial, so the
  work board leaves the job to that resident. It returns null once the job is over. The words match the Work screen's
  action and target: "Mill grain, the mill", "Forage herbs, the herb bank", "Gather windfall, the far copse". They are
  built in the owners, not in their text files as the packet guessed, because that is where the Work screen's words
  come from.
- **`take_back(brain: BrainScript, j, serial)`** claims the job again through the owner's own `claim`, and only while it
  is the same job and is waiting. A place someone else now holds is not waiting, so it is refused and nobody is
  displaced. A paused job, or one waiting out a failed walk, is refused the same way.
- **Each task's `unfinished()`** works as the orchard task's does. Before a call-away it answers the job while it
  lasts, so the action card says "goes back to it after". After a call-away it answers only a job the owner let her
  keep: not a lost walk, and not one taken by the board's own Pause or Reassign, where the owner lets go first and
  `called_away` finds no worker.
- Load rules are unchanged. A load in hand is still delivered before the night or a meal takes its carrier (each
  `must_finish`). An order that takes a carrier still sets the load down; the carrier now keeps that job to come back
  to (the ferry's `test_a_carrier_called_away_sets_the_wood_down_for_the_next` now releases her, R, before the next
  resident picks it up).

### A trip doesn't wait (ruling 2)

Each owner checks once a frame, in its `update`, whether a shared trip that is ready to leave is held only by a place
promised to a worker who is away. If so, it releases that promise: `forget_task(source, key)` on every brain, through a
small `_release_promise`. The REAL work board then offers the place to any idle, eligible resident. When she comes back,
nothing is left on her list: she does not take the place back, and goes on with her routine.

"Ready to leave", owner by owner:

- **The fishery** (`_release_held_seats`): a boat trip, one of whose seats has its fisher standing at the jetty (step
  `S_JETTY`), while the other seat waits. A seat at `S_JETTY` always has its fisher, because `_let_go` sends a seat not
  yet aboard back to its walk. Since nobody boards while a seat waits, such a trip is still QUEUED. A one-seat trip
  (net, trap, ice) and a station job never qualify.
- **The forage** (`_release_held_seats`, `_party_out`): a party under way, meaning another seat of the same trip has
  its forager, while this seat waits with nothing in hand. A forager out alone keeps hers. So does a party seat whose
  haul was set down: a load in hand is a delivery (decision 0222).
- **The ferry** (`_release_held_crew`): a crossing posted with the ferry open, its crew place waiting. A crew aboard is
  never called away (`must_finish`), so a waiting crew place means the boat waits only for its crew. A closed ferry
  waits anyway and keeps the place; it is released once the ferry opens. Gathers and hauls keep theirs.

### The independent review of 11d7c30a, and what was done

Nothing CRITICAL; the production code held.

- **HIGH: the "REAL work board" assertion could not fail.** The four suites' boards, the orchard's included, were bound
  with no crew keys. Every resident's crew priority was therefore FORBIDDEN, and `consider()` gave the job to nobody
  whether or not it was promised. The reviewer's proof: with `work_board.gd` `_candidate_ok` reduced to
  `if _idx_taken[k] == 1:`, every suite stayed green.
  - Each `_board_over(rig, j)` now binds one crew key per resident and sets every crew's priority for the job's
    activity to NORMAL.
  - Each suite has a control (`test_without_her_promise_the_board_gives_the_{mill,seat,pile,tending}_to_another`):
    with her entry removed (`remove_queued(0)`), the same board gives the job to another resident.
  - That mutant is now killed in all four suites. The first version of this record claimed the board test proved the
    promise; it did not until this fix. Decision 1900 has a correction note.
- **MEDIUM: a fishery boat soft-lock** (reproduced by the reviewer).
  - The bug: 0 (helm) is called away and keeps the helm. She is then Reassigned to the crew seat. The boat waited
    about 48 game hours for a helm, because the helm was promised to 0, and 0, waiting at the jetty as crew, was never
    idle.
  - The fix: `fishery.claim` now calls `_forget_other_seat`, so a fisher who takes one seat of a boat no longer
    promises its other seat.
  - Test: `test_a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm`. After the Reassign she no longer promises
    the helm, the REAL board gives the helm to the other able helm, and the boat sails.
  - Ruling 2 also covers this shape: the crew at the jetty makes the boat ready to leave, and the helm's promise is
    released. The seat fix stays as defence in depth, because it also clears the promise before she reaches the jetty.
  - The forage party and the ferry crew do not have the same shape. A party's seats never wait for each other, and a
    crossing has a single crew place. Ruling 2 releases both kinds of place regardless.
- **LOW 1: a promise survived a refill.** The first version of this record said "Authorise, a party order and Send"
  refill a kept place. They do not: they open new jobs. Only the board's Reassign hands a kept place to someone else.
  `work_board.gd` `reassign` forgot the promise only for the new worker, so the absent worker went on promising a job
  someone else held. It now forgets it for every brain. The three pitfall tests now refill the place through the REAL
  board's Reassign and require that the absent worker no longer promises it.
- **LOW 2: labels are not unique.** Examples: both seats of a boat, two pond trips, two far-copse jobs.
  `remember_unfinished` de-duplicated by words, so one kept job could silently drop another's promise.
  - It now de-duplicates an entry that names a work board task by (source, key), dropping only entries kept from
    interruptions (`_forget_return`), so a player's queued entries stay apart (decision 0411).
  - An entry that names no task still goes by its words, and only against other such entries (`_forget_label`).
  - Test: `test_two_kept_tasks_that_read_alike_are_both_kept` (`test_demo_orchard.gd`).
  - `resident_brain.gd` is not in the underground memory pack (`underground_memory_budget.py --check` passes). Its
    hash in `tools/measure_underground_variants.py`'s PRESENTATION_SOURCE_SHA256 was already stale on master
    (ce85…075a against 2391…f9b0 before this lane). That importer is a manual review tool that CI does not run, so its
    re-review is unchanged by this lane.
- **LOW 3: the rigs' `_board_pass` ignored promises.** Every rig that hands out these owners' jobs now skips a job
  promised to another resident (`_promised_to`): the fishery, forage, ferry and orchard suites, and `test_demo_brew`,
  `_new_recipes`, `_preserve`, `_fishing_revamp`, `_forage_outings`, `_hives` and `_orchard_remainders`. Only one
  older test relied on the old hand-out: the ferry carrier test, changed as above.
- **LOW 4:** `take_back` now takes a typed `BrainScript`, in the orchard too. `unfinished()` still makes one small
  entry each time an action card asks for it. The card's own line (`demo_command.gd` `interrupt_text`) builds strings
  on the same call, so this is not a per-frame cost. A `keeps_job()` would touch the shared `work_interrupt.gd` and
  every task, so it is left out.

## Tests (deterministic, art-free, no scene tree)

In each of `test_demo_fishery.gd`, `test_demo_forage.gd` and `test_demo_ferry.gd` (the fishery's names first):

- **Kept and promised through the REAL work board, crews bound:**
  `test_a_miller_called_away_keeps_the_job_promised_on_the_work_board`, plus the forager's and the gatherer's. The
  worker is a quarter into the work and is called away. The job is kept, named on her list, and the board gives it to
  nobody although every crew allows it. After her `work_done()` it is hers again, the same step with the work carried
  over.
- **The control:** `test_without_her_promise_the_board_gives_the_mill_to_another`, `_seat_`, `_pile_`.
- **Nothing kept:** `test_a_fishery_job_lost_on_the_way_paused_or_reassigned_keeps_nothing`, plus the seat's and the
  ferry's.
- **Stale:** `test_a_kept_fishery_job_cancelled_is_stale`, `test_a_kept_seat_cancelled_is_stale`,
  `test_a_kept_ferry_job_cancelled_is_stale`.
- **Refilled by Reassign:** `test_a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back`, the party seat's
  and the crew place's. Nobody promises the place any more, `take_back` refuses it, and nobody is displaced.
- **A trip doesn't wait:**
  - It leaves with someone else: `test_a_boat_ready_to_leave_does_not_wait_for_a_second_called_away` (it sails with
    the new second), `test_a_party_under_way_does_not_wait_for_a_forager_called_away` (both shares shelved) and
    `test_a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away` (it rows).
  - She steps aside: `test_the_second_back_from_her_meal_steps_aside`, plus the forager's and the helm's. Her list is
    empty, the place stays with whoever has it, and she has no job of that owner.
  - Solo work is still kept: `test_a_station_job_still_waits_for_its_miller`,
    `test_a_forager_alone_still_keeps_her_seat` (with another trip out at the same time),
    `test_a_party_seat_with_its_haul_set_down_is_still_kept`, `test_a_gatherer_still_keeps_her_pile` and
    `test_a_closed_ferry_keeps_its_helm_called_away`.
- The fishery only: `test_a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm`. The orchard:
  `test_without_her_promise_the_board_gives_the_tending_to_another` and
  `test_two_kept_tasks_that_read_alike_are_both_kept`.

Every new test fails without its change; the mutants below show which kills which. The solo tests guard against a
release that goes too wide: a forager alone released, a set-down haul released, a closed ferry released, or another
trip's seat counted as her party.

## Mutation testing (one mutant per run; the owner's focused suite)

**60 of 61 killed.** The one survivor, "the boat releases with no TRIP_QUEUED check", was equivalent: a seat that waits
keeps the boat QUEUED. The check was removed and the docstring says why.

Each line gives the file:line, the substitution, and what killed it. M is the main board test, C the control, N
nothing-kept, S stale, R the Reassign refill, L the trip-leaves test, A the steps-aside test, K the solo-kept test(s),
H the soft-lock test and D the de-duplication test.

The fishery (`test_demo_fishery.gd`):

- `fishery.gd:1014` `return true` → `return false` (called away keeps nothing): M, C, S, R, H, L, A, K.
- `fishery.gd:1012` a lost walk kept: N.
- `fishery.gd:1022` the job guard in `unfinished_of` removed: S.
- `fishery.gd:1032` the job guard in `take_back` removed: S.
- `fishery.gd:1032` `take_back` never claims: M.
- `fishery.gd:1032` `take_back` forces the worker in place of `claim`: M, R.
- `fishery.gd:1025` `SOURCE_FISHERY` → `SOURCE_FARM`: M, R, H, L, A, K.
- `fishery.gd:1025` the key `serial` → `j`: M, R, H, L, A, K.
- `fishery.gd:914` `_let_go` zeroes `j_mwu`: M.
- `fishery.gd:1038` the words' `", "` → `" "`: M.
- `fishery_task.gd:54` `_called_away = true` → `pass`: N.
- `fishery_task.gd:63` `unfinished()` ignores the keep flag: N.
- `fishery_task.gd:63` `unfinished()` always null (the fix absent): M, C, S, R, H, L, A, K.
- `work/fishery_work.gd:34` `key()` returns the row: M, R.
- `fishery.gd:851` `claim` without `_forget_other_seat`: H.
- `fishery.gd:870` `_forget_other_seat` forgets nothing: H.
- `fishery.gd:875` `_forget_other_seat` forgets the claimed seat instead: H.
- `fishery.gd:339` `update` without `_release_held_seats`: L, A.
- `fishery.gd:354` the `S_JETTY` condition dropped (released before the other fisher stands there): L, A.
- `fishery.gd:362` `_release_promise` forgets nothing: L, A.

The forage (`test_demo_forage.gd`):

- `forage_trips.gd:775` called away keeps nothing: M, C, S, R, L, A, K.
- `forage_trips.gd:773` a lost walk kept: N, and the older `test_an_interruption_loses_nothing_and_another_finishes`.
- `forage_trips.gd:783` the `unfinished_of` guard: S.
- `forage_trips.gd:793` the `take_back` guard: S.
- `forage_trips.gd:793` `take_back` never claims: M.
- `forage_trips.gd:793` `take_back` forces the worker: M, R.
- `forage_trips.gd:786` the wrong source: M, R, L, A, K.
- `forage_trips.gd:786` the key names the row: M, R, L, A, K.
- `forage_trips.gd:720` `_let_go` zeroes `j_mwu`: M, and the older interruption test.
- `forage_trips.gd:785` the words: M.
- `forage_task.gd:54` the call-away mark: N.
- `forage_task.gd:63` the keep flag ignored: N.
- `forage_task.gd:63` always null: M, C, S, R, L, A, K.
- `work/forage_work.gd:33` `key()` returns the row: M, R, and the older `test_the_work_board_reads_the_seats`.
- `forage_trips.gd:273` `update` without `_release_held_seats`: L, A.
- `forage_trips.gd:281` `_party_out` dropped (a forager alone released): K (`test_a_forager_alone_still_keeps_her_seat`).
- `forage_trips.gd:288` `_party_out` without its same-trip test: K (alone, with another trip out).
- `forage_trips.gd:281` the `j_load == 0` condition dropped: K (`test_a_party_seat_with_its_haul_set_down_is_still_kept`).

The ferry (`test_demo_ferry.gd`):

- `ferry.gd:830` called away keeps nothing: M, C, S, R, L, A, K, and the carrier test.
- `ferry.gd:828` a lost walk kept: N.
- `ferry.gd:838` the `unfinished_of` guard: S.
- `ferry.gd:848` the `take_back` guard: S.
- `ferry.gd:848` `take_back` never claims: M.
- `ferry.gd:848` `take_back` forces the worker: M, R.
- `ferry.gd:841` the wrong source: M, R, L, A, K, and the carrier test.
- `ferry.gd:841` the key names the row: the same.
- `ferry.gd:777` `_let_go` zeroes `j_mwu`: M.
- `ferry.gd:840` the words: M.
- `ferry_task.gd:54` the call-away mark: N.
- `ferry_task.gd:63` the keep flag ignored: N.
- `ferry_task.gd:63` always null: M, C, S, R, L, A, K, and the carrier test.
- `work/ferry_work.gd:32` `key()` returns the row: M, R.
- `ferry.gd:425` `update` without `_release_held_crew`: L, A, K (the closed-ferry test's release once open).
- `ferry.gd:433` the `is_open()` condition dropped: K (`test_a_closed_ferry_keeps_its_helm_called_away`).
- `ferry.gd:442` `_release_promise` forgets nothing: L, A, K.

Shared code:

- `work/work_board.gd:302` `_candidate_ok` ignores promises (the review's mutant): M in all four suites, the orchard's
  `test_a_called_away_tender_is_promised_on_the_real_work_board` included.
- `work/work_board.gd:451` `reassign` forgets only the new worker's promise: R in the fishery, forage and ferry.
- `cast/resident_brain.gd:2224` de-duplication by words again: D.
- `cast/resident_brain.gd:2270` `_forget_return` drops queued entries too: `test_demo_work_edges.gd`'s
  `test_a_task_taken_up_from_the_list_leaves_no_second_entry_for_it`.
- `cast/resident_brain.gd:2278` `_forget_label` drops entries that name a task: D.

## Gates

- **Focused suites**, staged and art-free (`godot/demo/assets` moved aside, then restored). The suites:
  `test_demo_fishery`, `_forage`, `_ferry`, `_orchard`, `_work`, `_work_edges`, `_action_cards`, `_kitchen`,
  `_forage_outings`, and the rigs changed here (`_brew`, `_new_recipes`, `_preserve`, `_fishing_revamp`, `_hives`,
  `_orchard_remainders`). Each run printed `567 test(s), 11475 assertion(s), 0 failure(s)`; `diagnostics: 0 unexpected
  error(s), 0 unexpected warning(s), 0 expected, 2 tolerated; leaked at exit: 0 object(s), 0 resource(s)`; `log: 0
  unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- `./tools/run_tests.sh --fast`, at 11d7c30a, before the review: `12199 test(s), 1130436 assertion(s), 0 failure(s)`,
  0 unexpected, 0 leaks. The coordinator reruns the full sharded suite on this fix-up.
- **Analyzer** (port 6397): `0 GDScript warning(s) in 0 of 1509 file(s)`.
- `underground_memory_budget.py --check`: exit 0. `ready07_arithmetic.py`: `"status": "PASS"`. `decision_numbers.py`:
  `PASS -- 547 records, 0 problem(s)`.

## Notes

- No pinned file was touched.
- Ruling 2's cost runs the other way from the resume rule's. A worker back from a meal may find her boat seat, party
  seat or crew place gone to someone else; she simply goes on with her routine. Solo work still waits for her.
