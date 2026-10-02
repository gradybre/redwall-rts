# 0997 — A meal is finalized once its last bowl is eaten or given back, and the feast and the people read that
Date: 2026-10-02 · Status: Accepted (one PROPOSAL below awaits Brendan)

Review R05 (`docs/reviews/2026-10-02-codex-review.md` on `codex/review-2026-10-02`, medium): the regatta's feast tally
(and with it the chronicle line, the shared-feast affinity and the batch-7 Shared Warmth coverage, decision 0682) and the
people's taps (the "Cooked supper … for everyone" deed and shared-supper contact, decision 0491) were taken at the
supper's 19:00 end. The kitchen deliberately lets a diner keep its bowl past that end (decision 0381: "a diner already
eating finishes its bowl") and commits the meal only when it is eaten (`_eat_portion`, REQ-SET-095) -- or moves the diner to
"went without" if the bowl comes back (`_served_but_missed`). So a guest served at 18:59 who finished at 19:01 was left
out of the feast, and a cook kept a permanent deed for a meal whose last bowl was then given back.

## The rule used

**Brendan's ruling (2026-10-02), as given:** "R05: publish one 'meal finalized' event once every holder for that meal
has finished or cancelled, carrying the committed diner set. The regatta feast tally, chronicle and buff, and
`people_taps`' deeds and shared-supper contact, consume that event instead of closing at 19:00. Add two boundary tests:
a last bowl eaten after closing, and a last bowl returned after closing."

Decisions 0381 (consumption at the end of eating), 0438 (the feast's tally is who ate the main course), 0491 (memories
are committed deeds only) and 0781 (a supper is judged only once a held portion can no longer be given back) all already
require committed consumption; this decision gives them one event to read.

## Decision

**The event** (`demo/kitchen/kitchen.gd`, THE MEAL FINALIZED; class `MealFinal`):

- **When.** One per meal (a meal key is one day's breakfast or supper), published **once**: after the kitchen has ended
  that meal's serving (`_close_meal`) **and** no resident holds anything of it any more (`holders_of(key) == 0`). A
  holder is a resident whose meal is that key and who holds a reserved portion (a diner or the cook), reserved raw food
  (an emergency raw meal, also one waiting to set off again after a blocked walk), or a diner's part still under way
  (walking to its seat, waiting there for an occasion's second course, eating). Each holder either eats (committed) or
  gives its food back (called away, to bed, its course never coming). Checked at the end of the kitchen's `update()`, so
  a meal nobody holds at its end is published in the very update that ended it; earliest pending meal first.
- **What.** `key`, `serial` (publication order, 1 the first; `finals_published` counts every one), `diners` (who ate a
  cooked portion of it -- their first portion of the meal, each once, in the order they finished; the cook's early supper
  counts for the supper), `raw` (who ate raw at it) and `without` (how many went without: the meal's tally row as the
  kitchen has corrected it for every bowl given back). Integer, packed arrays; no floats.
- **Where.** Appended to the kitchen's bounded log `finals` (MAX_MEAL_LOG, 64 events, oldest dropped) -- the kitchen's
  existing way of telling others what happened (as `meal_keys`/`meal_without` and `cooked_by` are read by the people,
  the goals and the planner's record). Readers: `final_of(key)`, `final_pending(key)`, `holders_of(key)`,
  `meal_lapsed(key)` (the kitchen has run past the meal's end without ending it -- a season skip over it, or a meal
  before the kitchen was configured -- so no event will ever come).
- **Not a callback list.** Decision 0491 forbids the owner calling into the people ("a tap on its owner's committed
  state -- never a call from the owner's code into the people"), and a call from inside `kitchen.update()` into the
  regatta would re-enter the kitchen mid-hour (the tally clears the occasion and draws service water). Both consumers
  already run once a frame and read the log at the edge, which is still exactly one published event per meal. Waiting
  allocates nothing (checked by a test: 200 waits, 0 objects).
- **The 19:00 tally is unchanged.** `meal_keys`/`meal_ate`/`meal_raw`/`meal_without` and the news line "Supper, day 2: 8
  ate, 1 went without" still post at the serving's end; only consumers that need the committed result moved.

**The regatta** (`demo/regatta/regatta.gd`): the feast is settled by `_settle_feast()` instead of the hour. Once the
kitchen has published the feast supper's event, `_tally(final)` counts the attendees from `final.diners` (those whose
occasion courses include the main course; resident order) and every-course coverage from them, then settles the menu
(Shared Warmth, the infusion's herb and water), writes the chronicle, the winners' deed and the feast's company (+5
affinity). A feast whose supper the kitchen never ended (`meal_lapsed`: a season skip over its day) is tallied with
nobody, its food and wood given back as before. While a bowl is still out after 19:00 the regatta waits and does
nothing else.

**The people** (`demo/people/people_taps.gd`): `_poll_meals` reads each newly published event (by serial; `watch()`
baselines at `finals_published`). The cook's first "meal for everyone" deed needs `without == 0` and at least one
committed diner; a supper's shared contact is every pair of its committed `diners` (no longer `fed.last_meal` /
`last_outcome`, which a later meal can overwrite).

**Edge cases.** A meal with no diners at all is published at its end (`diners` empty, everyone `without`). A Restart
builds a new kitchen, regatta and taps: nothing carries over (the demo has no save). A season skip (`skip_to_hour`) ends
the meal being served quietly, with no tally and so no event; a holder of it who eats afterwards starts an event that can
never be published, and the next meal's end lets it go (`_forget_unfinalizable`). A meal already pending when a skip
happens is published when its holders resolve. Every holder is released by bedtime at the latest (the night routine
lets an eater finish its bowl, then calls the rest away), so a feast's tally comes before the night.

## The independent review's findings, fixed

- **H1 -- a two-course guest counted twice.** A guest who had eaten the occasion's main course and gave its second-course
  bowl back after the end was counted both as a diner and as gone without (a 6-resident probe: 2 diners + 2 raw + 3
  without = 7), so `people_taps` wrongly withheld the cook's deed. `_ate_a_course(i, key)` now says a guest has eaten
  the meal; `_clear_role` gives such a bowl back without `_served_but_missed`, `_holding` does not count that guest's
  second portion as a meal eaten at the end, and `_eat_portion`'s "first" reads the same helper. Test (regatta): the
  second-course give-back after 19:00 -- every resident counted exactly once, in the event and in the kitchen's tally.
- **M1 -- nothing guaranteed the event fires.** THE DEADLINE: when a later meal's serving ends, any earlier meal still
  waiting on a holder is overdue (no diner holds a bowl through the next serving); each holder's part ends
  (`_give_up_part`: its food back, it went without, its brain's kitchen task let go) and the meal is published at that
  update's end. The settling runs **before** the closing meal's own tally (a second review's HIGH: run after it, the
  freed resident was in neither meal's count, so the closing meal could read "nobody went without" over a hungry
  resident). Test: a held meal settled and published when the next one ends, once, and the closing meal and its event
  count every resident.
- **M2, M3** -- two assertions that could not fail now can (the cook's round under way holds nothing; two later events
  at one look do not re-read the supper before them).
- **LOW** -- `feast_settled()` renamed `_settle_feast()` (the regatta's own); `_building` typed
  `Dictionary[int, MealFinal]`; a test for the next end letting go an event that can never be published (mutant M22).
  Not done: `_publish` refusing a missing tally row -- the tests publish synthetic events on a bare kitchen, and every
  real publication follows `_record_meal`. Two mutants survive as equivalent: the regatta's occasion-key guard in
  `_count_attendees` (only the regatta clears the occasion, after counting) and the people's diner-index guard
  (`people_ledger.gd pair` already refuses an out-of-range resident).

## PROPOSAL (needs Brendan's ruling)

**A season skip during the feast's own supper.** The Demo Lab's skip (decision 0571) ends a meal being served quietly:
"the kitchen's meals … did not run". With this decision such a feast is `meal_lapsed` and tallied with **nobody**, even
guests who had already eaten the hotpot before the skip (the 19:00 reading would have counted them).
- *Option A (built, recommended):* keep -- the skip is a Lab trigger that declares the kitchen's meals unlived, and
  counting a partial feast would need a second, unpublished kind of result.
- *Option B:* on a lapse, tally the guests who had committed a bowl before the skip (the kitchen exposes its partial
  diner set for a lapsed meal).
- *Option C:* refuse the skip while a regatta's feast day is under way.

## Why

The ruling names the mechanism. The holder definition is what the kitchen itself already treats as "not yet decided"
(`_served_but_missed`'s conditions, `must_finish`, the second-course wait), so the event cannot fire while any of them
could still change the result, and cannot wait forever because each of them ends by bedtime. Reading the corrected
tally row for `without` keeps the event and the kitchen's own ledger in one count.

## Consequences

- A new consumer of "who ate meal X" reads `final_of(X)` (or the `finals` log), never `fed.last_meal` or the 19:00 row.
- The regatta's tally can now happen after 19:00; its chronicle line and Shared Warmth start then.
- 0781's goals and the planner's record still read the tally row at the day's end, which is already corrected; they
  could move onto the event later without changing what they count.

## Verification

Focused suites (`test_demo_kitchen.gd`, `test_demo_regatta.gd`, `test_demo_people.gd`), including the two boundary tests
for each consumer (a last bowl eaten after the end; a last bowl given back after the end), the event published only at
its last holder and exactly once, at the end when nothing is held, its log bound, the holder definition clause by
clause, a lapse, and no allocation while waiting. Mutation results are in the hand-back report of this change.

## Source

Review R05; Brendan's ruling of 2026-10-02; decisions 0381, 0438, 0491, 0571, 0682, 0781; GDD REQ-SET-095.
