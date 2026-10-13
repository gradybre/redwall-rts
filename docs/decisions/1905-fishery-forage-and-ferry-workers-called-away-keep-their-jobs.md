# 1905 — Fishery, forage and ferry workers called away keep their jobs (MEAL-CALLAWAY); a trip doesn't wait

Date: 2026-10-12 · Status: Accepted (engineering record of BACKLOG packet MEAL-CALLAWAY, its two independent reviews,
and Brendan's rulings "Trip doesn't wait", "Player's order holds" and "Only in working hours")

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
3. **"Player's order holds"** (the recommended option), on the second review's HIGH. Asked "Should a deliberate
   queued order still hold the trip?", Brendan chose the option that reads: "Only places kept automatically from a meal
   or other call-away are released; a place the player queued for someone waits for her. The player can always
   reassign it."
4. **"Only in working hours"** (the recommended option). Asked "Release only when someone could actually take it?",
   Brendan chose the option that reads: "A held place is released only while others are working and could fill it;
   overnight it stays hers."

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

Each owner checks once a frame, in its `update`, whether a shared trip that is ready to leave is held by a place a
worker KEPT when she was called away. If so, it releases that place. The REAL work board then offers it to any idle,
eligible resident. When she comes back nothing is left on her list: she does not take the place back, and goes on with
her routine.

How it is released (rulings 3 and 4, the second review), in one shared helper, `demo/work/held_places.gd`:

- **The keeper column.** Each owner records, per job row, who `called_away` let keep the job (`tables.j_keeper` in the
  fishery, `j_keeper` in the forage and the ferry). It is cleared when anyone claims the job and when the row is opened
  afresh.
- **Only her kept entry.** The release calls `HeldPlaces.release`, which uses the brain's new public `forget_kept`
  (formerly `_forget_return`) on the keeper alone. That drops only entries kept from an interruption, so a place the
  player queued for anyone (Shift+right-click, `work_board.queue_task`) is never touched: it holds the trip
  (ruling 3).
- **O(1).** A place nobody kept is skipped on its keeper column, and no brain is looked at. The first version swept
  every brain with `forget_task` each frame while a place waited (about 56 µs per sweep of 256 brains). That sweep was
  also what deleted queued orders.
- **Working hours** (ruling 4): `HeldPlaces.working_hours` is the demo's existing day, the night routine's own rule:
  not `night_routine.gd` `is_night_hour`, whose night runs from `DUSK_HOUR` 20:00 to `DAWN_HOUR` 06:00. No new
  constant. Overnight a kept place stays hers; from 06:00 it may be released.

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

### The second review of f35ce497, and what was done

It confirmed every earlier finding fixed and found:

- **HIGH: the release deleted the player's queued orders.** `_release_promise` called `forget_task` on every brain, and
  `forget_task` also removes queued entries. The reviewer reproduced it twice: a ferry crossing queued for a busy helm
  vanished within 2 frames, and a queued second boat seat vanished once the helm reached the jetty. Fixed by the keeper
  column and `forget_kept`, per ruling 3. The reviewer also saw a helm sent to bed lose her ferry place at once, and a
  forage seat at night; fixed per ruling 4.
- **MEDIUM: the per-frame sweep of every brain.** Fixed by the same change: O(1).
- **LOW: three copies of the release.** The shared logic is now `held_places.gd`. Each owner keeps only a few lines
  naming its own columns, with two blank lines between functions.
- **LOW: two seats both away.** New tests show a boat whose fishers are both away, and a party whose foragers are
  both away (as the night takes both), keep both places: nobody is out or at the jetty, so the trip is not ready to
  leave.
- **LOW, noted: the board's Reassign removes other residents' QUEUED entries for that task too** (`work_board.gd`
  `reassign` calls `forget_task` on every brain, decision 1905's first review). This is deliberate: Reassign is the
  player's latest explicit choice for that task, and a queued order of someone else's would otherwise hold a task the
  player has just given away.
- **LOW, noted: a stale entry takes a RESUME_MAX slot.** A kept entry whose job was refilled by the owner's own
  `claim` (not Reassign), or one the player's queued order made redundant, stays on the list beside the live entries
  until `take_up_unfinished` reaches it and drops it. Until then it counts toward RESUME_MAX (3) kept entries, so it
  can push out the oldest live kept entry. In practice this needs three call-aways before the next take-up. It is
  unchanged by this lane and recorded, not fixed.

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
    interruptions (`_forget_return`, since made public as `forget_kept`), so a player's queued entries stay apart
    (decision 0411).
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
- **Held places** (rulings 3 and 4; the second review):
  - The player's order holds: `test_a_seat_the_player_queued_holds_the_boat`,
    `test_a_seat_the_player_queued_holds_for_her` and `test_a_crew_place_the_player_queued_holds_the_crossing`. The
    keeper's kept place is given up, another resident's queued order for it holds, and the board gives it to nobody.
    Also `test_her_own_queued_order_outlives_the_release_of_her_kept_{seat,seat,place}`: the keeper had also queued
    it herself, her kept entry goes, and her queued order stays.
  - Working hours: `test_a_kept_seat_is_given_up_only_in_working_hours`, the party seat's and the crew place's. The
    place is kept overnight (21:00) though the trip is ready, and given up at dawn (06:00).
  - O(1), only the keeper: `test_only_the_keepers_entry_is_given_up`, `_seat_entry_`, `_crew_entry_`. Another
    resident's kept entry naming the same place (put on her list by hand) is not looked at.
  - Both away: `test_two_seats_both_away_stay_kept` and `test_two_party_seats_both_away_stay_kept` (the review's LOW).
- The fishery only: `test_a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm`. The orchard:
  `test_without_her_promise_the_board_gives_the_tending_to_another` and
  `test_two_kept_tasks_that_read_alike_are_both_kept`.

Every new test fails without its change; the mutants below show which kills which. The solo tests guard against a
release that goes too wide: a forager alone released, a set-down haul released, a closed ferry released, or another
trip's seat counted as her party.

## Mutation testing (one mutant per run; the owner's focused suite)

**68 of 68 killed, no survivors.** Every mutant was run again after the last change to its file, so the file:line
references are current. Two mutants survived their first run against these tests and were then killed:
"working hours from the hearth rule", once the dawn test moved to 06:00 (the hearth rule still counts 06:00 as
night), and "the release forgets queued entries too", once the self-queued tests were added. One mutant from the
previous round, the boat release's TRIP_QUEUED check, was equivalent, and that check was removed. Three guards
were not mutated because they are equivalent by construction: `may_release`'s keeper test (every caller checks
the keeper first), clearing the keeper on `claim`, and clearing it after a release (a stale keeper's release finds
no entry). Killed by: the tests named, without their `test_` prefix.

The fishery:

- `fishery/fishery.gd:918` let go loses the work done: a_miller_called_away_keeps_the_job_promised_on_the_work_board.
- `fishery/fishery.gd:1043` the order words: a_miller_called_away_keeps_the_job_promised_on_the_work_board.
- `fishery/fishery.gd:854` claim keeps the other seat's promise: a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm.
- `fishery/fishery.gd:874` _forget_other_seat forgets nothing: a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm.
- `fishery/fishery.gd:879` _forget_other_seat forgets the claimed seat instead: a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm.
- `fishery/fishery.gd:339` the boat never releases a held seat: a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_seat_the_player_queued_holds_the_boat, a_kept_seat_is_given_up_only_in_working_hours, only_the_keepers_entry_is_given_up.
- `fishery/fishery.gd:355` a seat is released before the other fisher is at the jetty: a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, two_seats_both_away_stay_kept.
- `fishery/fishery.gd:1018` called_away records no keeper: a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_seat_the_player_queued_holds_the_boat, a_kept_seat_is_given_up_only_in_working_hours, only_the_keepers_entry_is_given_up.
- `fishery/fishery.gd:364` release sweeps every brain (forget_kept): only_the_keepers_entry_is_given_up.
- `fishery/fishery.gd:1018` called_away keeps nothing: a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_kept_fishery_job_cancelled_is_stale, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_mill_to_another, a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm, a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_station_job_still_waits_for_its_miller, a_kept_seat_is_given_up_only_in_working_hours, two_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `fishery/fishery.gd:1016` a lost walk is kept: a_fishery_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `fishery/fishery.gd:1027` unfinished_of without its job guard: a_kept_fishery_job_cancelled_is_stale.
- `fishery/fishery.gd:1037` take_back without its job guard: a_kept_fishery_job_cancelled_is_stale.
- `fishery/fishery.gd:1037` take_back never claims: a_miller_called_away_keeps_the_job_promised_on_the_work_board.
- `fishery/fishery.gd:1030` the wrong board source: a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm, a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_station_job_still_waits_for_its_miller, a_kept_seat_is_given_up_only_in_working_hours, only_the_keepers_entry_is_given_up, two_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `fishery/fishery.gd:1030` the entry names the row: a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm, a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_station_job_still_waits_for_its_miller, a_kept_seat_is_given_up_only_in_working_hours, only_the_keepers_entry_is_given_up, two_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `fishery/fishery.gd:1037` take_back ignores the waiting test (claim forced): a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back.
- `fishery/fishery_task.gd:54` cancel never marks the task called away: a_fishery_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `fishery/fishery_task.gd:63` unfinished ignores the keep flag: a_fishery_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `fishery/fishery_task.gd:63` unfinished always null (the fix absent): a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_kept_fishery_job_cancelled_is_stale, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_mill_to_another, a_helm_moved_to_the_crew_seat_no_longer_holds_the_helm, a_boat_ready_to_leave_does_not_wait_for_a_second_called_away, the_second_back_from_her_meal_steps_aside, a_station_job_still_waits_for_its_miller, a_kept_seat_is_given_up_only_in_working_hours, two_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `work/fishery_work.gd:34` key() returns the row: a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, a_seat_the_player_queued_holds_the_boat, her_own_queued_order_outlives_the_release_of_her_kept_seat.

The forage:

- `forage/forage_trips.gd:728` let go loses the work done: an_interruption_loses_nothing_and_another_finishes, a_forager_called_away_keeps_the_seat_promised_on_the_work_board.
- `forage/forage_trips.gd:794` the order words: a_forager_called_away_keeps_the_seat_promised_on_the_work_board.
- `forage/forage_trips.gd:276` the party never releases a held seat: a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_seat_the_player_queued_holds_for_her, a_kept_party_seat_is_given_up_only_in_working_hours, only_the_keepers_seat_entry_is_given_up.
- `forage/forage_trips.gd:285` a forager alone is released too: a_forager_alone_still_keeps_her_seat, two_party_seats_both_away_stay_kept.
- `forage/forage_trips.gd:292` _party_out without its same-trip test: a_forager_alone_still_keeps_her_seat.
- `forage/forage_trips.gd:285` a seat with its haul set down is released too: a_party_seat_with_its_haul_set_down_is_still_kept.
- `forage/forage_trips.gd:783` called_away records no keeper: a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_seat_the_player_queued_holds_for_her, a_kept_party_seat_is_given_up_only_in_working_hours, only_the_keepers_seat_entry_is_given_up.
- `forage/forage_trips.gd:302` release sweeps every brain (forget_kept): only_the_keepers_seat_entry_is_given_up.
- `forage/forage_trips.gd:783` called_away keeps nothing: a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_kept_seat_cancelled_is_stale, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_seat_to_another, a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_forager_alone_still_keeps_her_seat, a_party_seat_with_its_haul_set_down_is_still_kept, a_kept_party_seat_is_given_up_only_in_working_hours, two_party_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `forage/forage_trips.gd:781` a lost walk is kept: an_interruption_loses_nothing_and_another_finishes, a_seat_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `forage/forage_trips.gd:792` unfinished_of without its job guard: a_kept_seat_cancelled_is_stale.
- `forage/forage_trips.gd:802` take_back without its job guard: a_kept_seat_cancelled_is_stale.
- `forage/forage_trips.gd:802` take_back never claims: a_forager_called_away_keeps_the_seat_promised_on_the_work_board.
- `forage/forage_trips.gd:795` the wrong board source: a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back, a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_forager_alone_still_keeps_her_seat, a_party_seat_with_its_haul_set_down_is_still_kept, a_kept_party_seat_is_given_up_only_in_working_hours, only_the_keepers_seat_entry_is_given_up, two_party_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `forage/forage_trips.gd:795` the entry names the row: a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back, a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_forager_alone_still_keeps_her_seat, a_party_seat_with_its_haul_set_down_is_still_kept, a_kept_party_seat_is_given_up_only_in_working_hours, only_the_keepers_seat_entry_is_given_up, two_party_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `forage/forage_trips.gd:802` take_back ignores the waiting test (claim forced): a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back.
- `forage/forage_task.gd:54` cancel never marks the task called away: a_seat_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `forage/forage_task.gd:63` unfinished ignores the keep flag: a_seat_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `forage/forage_task.gd:63` unfinished always null (the fix absent): a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_kept_seat_cancelled_is_stale, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_seat_to_another, a_party_under_way_does_not_wait_for_a_forager_called_away, the_forager_back_from_her_meal_steps_aside, a_forager_alone_still_keeps_her_seat, a_party_seat_with_its_haul_set_down_is_still_kept, a_kept_party_seat_is_given_up_only_in_working_hours, two_party_seats_both_away_stay_kept, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `work/forage_work.gd:33` key() returns the row: the_work_board_reads_the_seats, a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back, a_seat_the_player_queued_holds_for_her, her_own_queued_order_outlives_the_release_of_her_kept_seat.

The ferry:

- `ferry/ferry.gd:778` let go loses the work done: a_gatherer_called_away_keeps_the_job_promised_on_the_work_board.
- `ferry/ferry.gd:842` the order words: a_gatherer_called_away_keeps_the_job_promised_on_the_work_board.
- `ferry/ferry.gd:427` the crossing never releases its crew place: a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_closed_ferry_keeps_its_helm_called_away, a_crew_place_the_player_queued_holds_the_crossing, a_kept_crew_place_is_given_up_only_in_working_hours, only_the_keepers_crew_entry_is_given_up.
- `ferry/ferry.gd:436` the crossing releases while the ferry is closed: a_closed_ferry_keeps_its_helm_called_away.
- `ferry/ferry.gd:831` called_away records no keeper: a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_closed_ferry_keeps_its_helm_called_away, a_crew_place_the_player_queued_holds_the_crossing, a_kept_crew_place_is_given_up_only_in_working_hours, only_the_keepers_crew_entry_is_given_up.
- `ferry/ferry.gd:440` release sweeps every brain (forget_kept): only_the_keepers_crew_entry_is_given_up.
- `ferry/ferry.gd:831` called_away keeps nothing: a_carrier_called_away_sets_the_wood_down_for_the_next, a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_kept_ferry_job_cancelled_is_stale, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_pile_to_another, a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_gatherer_still_keeps_her_pile, a_closed_ferry_keeps_its_helm_called_away, a_kept_crew_place_is_given_up_only_in_working_hours, her_own_queued_order_outlives_the_release_of_her_kept_place.
- `ferry/ferry.gd:829` a lost walk is kept: a_ferry_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `ferry/ferry.gd:840` unfinished_of without its job guard: a_kept_ferry_job_cancelled_is_stale.
- `ferry/ferry.gd:850` take_back without its job guard: a_kept_ferry_job_cancelled_is_stale.
- `ferry/ferry.gd:850` take_back never claims: a_gatherer_called_away_keeps_the_job_promised_on_the_work_board.
- `ferry/ferry.gd:843` the wrong board source: a_carrier_called_away_sets_the_wood_down_for_the_next, a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_gatherer_still_keeps_her_pile, a_closed_ferry_keeps_its_helm_called_away, a_kept_crew_place_is_given_up_only_in_working_hours, only_the_keepers_crew_entry_is_given_up, her_own_queued_order_outlives_the_release_of_her_kept_place.
- `ferry/ferry.gd:843` the entry names the row: a_carrier_called_away_sets_the_wood_down_for_the_next, a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_gatherer_still_keeps_her_pile, a_closed_ferry_keeps_its_helm_called_away, a_kept_crew_place_is_given_up_only_in_working_hours, only_the_keepers_crew_entry_is_given_up, her_own_queued_order_outlives_the_release_of_her_kept_place.
- `ferry/ferry.gd:850` take_back ignores the waiting test (claim forced): a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back.
- `ferry/ferry_task.gd:54` cancel never marks the task called away: a_ferry_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `ferry/ferry_task.gd:63` unfinished ignores the keep flag: a_ferry_job_lost_on_the_way_paused_or_reassigned_keeps_nothing.
- `ferry/ferry_task.gd:63` unfinished always null (the fix absent): a_carrier_called_away_sets_the_wood_down_for_the_next, a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_kept_ferry_job_cancelled_is_stale, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, without_her_promise_the_board_gives_the_pile_to_another, a_crossing_ready_to_leave_does_not_wait_for_a_helm_called_away, the_helm_back_from_her_meal_steps_aside, a_gatherer_still_keeps_her_pile, a_closed_ferry_keeps_its_helm_called_away, a_kept_crew_place_is_given_up_only_in_working_hours, her_own_queued_order_outlives_the_release_of_her_kept_place.
- `work/ferry_work.gd:32` key() returns the row: a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, a_crew_place_the_player_queued_holds_the_crossing, her_own_queued_order_outlives_the_release_of_her_kept_place.

Shared code:

- `work/work_board.gd:302` the board ignores promises (the review's mutant): a_gatherer_called_away_keeps_the_job_promised_on_the_work_board, a_crew_place_the_player_queued_holds_the_crossing, a_miller_called_away_keeps_the_job_promised_on_the_work_board, a_seat_the_player_queued_holds_the_boat, a_forager_called_away_keeps_the_seat_promised_on_the_work_board, a_seat_the_player_queued_holds_for_her, a_called_away_tender_is_promised_on_the_real_work_board.
- `work/work_board.gd:451` Reassign forgets only the new worker's promise: a_crew_place_refilled_while_its_helm_is_away_is_not_taken_back, a_boat_seat_refilled_while_its_fisher_is_away_is_not_taken_back, a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back.
- `cast/resident_brain.gd:2224` remember_unfinished de-duplicates by words again: two_kept_tasks_that_read_alike_are_both_kept.
- `cast/resident_brain.gd:2272` forget_kept drops queued entries too (order lists): a_task_taken_up_from_the_list_leaves_no_second_entry_for_it.
- `cast/resident_brain.gd:2284` _forget_label drops entries that name a task: two_kept_tasks_that_read_alike_are_both_kept.
- `work/held_places.gd:24` working hours always: a_kept_crew_place_is_given_up_only_in_working_hours, a_kept_seat_is_given_up_only_in_working_hours, a_kept_party_seat_is_given_up_only_in_working_hours.
- `work/held_places.gd:26` working hours from the wrong rule (hearth hours): a_kept_crew_place_is_given_up_only_in_working_hours, a_kept_seat_is_given_up_only_in_working_hours, a_kept_party_seat_is_given_up_only_in_working_hours.
- `work/held_places.gd:36` release forgets queued entries too (the review's HIGH): her_own_queued_order_outlives_the_release_of_her_kept_place, her_own_queued_order_outlives_the_release_of_her_kept_seat, her_own_queued_order_outlives_the_release_of_her_kept_seat.
- `cast/resident_brain.gd:2272` forget_kept drops queued entries too: a_task_taken_up_from_the_list_leaves_no_second_entry_for_it.

## Gates

- **Focused suites**, staged and art-free (`godot/demo/assets` moved aside, then restored). The suites:
  `test_demo_fishery`, `_forage`, `_ferry`, `_orchard`, `_work`, `_work_edges`, `_action_cards`, `_kitchen`,
  `_forage_outings`, and the rigs changed here (`_brew`, `_new_recipes`, `_preserve`, `_fishing_revamp`, `_hives`,
  `_orchard_remainders`). Each run printed `581 test(s), 11541 assertion(s), 0 failure(s)`; `diagnostics: 0 unexpected
  error(s), 0 unexpected warning(s), 0 expected, 2 tolerated; leaked at exit: 0 object(s), 0 resource(s)`; `log: 0
  unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- `./tools/run_tests.sh --fast`, at 11d7c30a, before the reviews: `12199 test(s), 1130436 assertion(s), 0
  failure(s)`, 0 unexpected, 0 leaks. The coordinator reruns the full sharded suite on each fix-up.
- **Analyzer** (port 6397): `0 GDScript warning(s) in 0 of 1510 file(s)`.
- `underground_memory_budget.py --check`: exit 0. `ready07_arithmetic.py`: `"status": "PASS"`. `decision_numbers.py`:
  `PASS -- 547 records, 0 problem(s)`.

## Notes

- No pinned file was touched.
- Ruling 2's cost runs the other way from the resume rule's. A worker back from a meal may find her boat seat, party
  seat or crew place gone to someone else; she simply goes on with her routine. Solo work still waits for her.
