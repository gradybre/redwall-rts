# 1651 — "First crossing" and "Regatta day" are village goals, read off the ferry's and the regatta's own counts

Date: 2026-10-07 · Status: Accepted

Handoff packet GOALS-2 (`docs/handoff/BACKLOG.md`). Branch `feat/demo-small-leftovers`.

## Brendan's ruling (2026-10-01)

Decision 0901 ("Goals for the ferry and regatta. Not registered.") asked:

> (a) leave both as they are; (b) add village goals "First crossing" (ferry crossings >= 1) and "Regatta day"
> (regattas held >= 1); (c) also bind M4's `feasts`.

Brendan answered **"YES" to option (b)** on 2026-10-01. That answer was recorded only in the coordinator's tracker;
`docs/handoff/RULINGS.md` (2026-10-01, "Ferry and regatta goals, every-dish text": "Yes, option (b): 'First crossing'
and 'Regatta day'") is its first repository record, and this record is its first decision record. 0901 itself is
append-only and is not edited. Option (c) was not chosen and is not built: `regatta.gd feasts_held` counts a regatta
day held to its end, not the GDD's COMPLETE feasts (FeastState), so M4's `feasts` part stays unmodelled.

## Decision

- **`demo/goals/village_goals.gd`**: two rows in `GOALS`, placed after "Over the water" (the other water goal):
  - `first_crossing`, "First crossing": one part, `crossings`, "Ferry crossings rowed home", target 1, measure kind
    `M_CROSSINGS` (14) = `ferry.gd crossings_done`, the latched count of crossings rowed home (a crossing stood down or
    held at the far stage is not counted, as the ferry itself does not count it).
  - `regatta_day`, "Regatta day": one part, `regattas`, "Regattas held", target 1, measure kind `M_REGATTAS` (15) =
    `regatta.gd feasts_held`, the latched count of regatta days held to their end (bumped once the day's feast supper
    is settled, whether or not every course was served: Brendan's 0682 ruling "hold the feast with a missing course").
    A season skipped at no cost (`ST_SKIPPED`) is not counted.
  - Two typed fields on the evaluator, `ferry` and `regatta`, unbound by default; an unbound one reads 0. The parts
    therefore always have a measure: they never show "not in this demo yet", and a suite without the water shows
    "0 of 1".
- **`demo/demo_village.gd`** (shared file; the hook): two lines in `_bind_goal_measures()`, which already runs after
  `_build_ferry()` and `_build_regatta()`: `_guide.goals.village.ferry = _ferry.ferry` and
  `_guide.goals.village.regatta = _regatta.regatta`.
- **Words**: the "Ferry and regatta" help topic (`demo/guide/help_topics.gd`) names the two goals and gains the search
  word "goal"; `godot/demo/README.md`'s village-goals list names them.

Reached, each goal is said once in Village news and woven into the hall's tapestry as every goal is (0781, 0902); it
grants nothing. Evaluated on the game hour, as every goal (0781); the two measures are field reads, allocation-free.

Rejected: registering the two goals from `demo_village.gd` through `book.register` (more lines in the shared file, and
the goals would be absent from `GOALS`, which the goals suite and the README read as the built-in set); binding them
through `bind_measure` on `M_NONE` parts (they would read "not in this demo yet" wherever the water is not built).

## Tests and gates

- `test_demo_goals.gd`: `test_first_crossing_is_reached_on_the_ferrys_own_count` (0 of 1, reached at the first
  crossing, said once), `test_regatta_day_is_reached_on_the_regattas_own_count` (reached at the first regatta, the
  ferry's goal untouched), `test_the_occasion_counts_read_nothing_unbound` (0 unbound, measured, the real fields when
  bound). The suite: `31 test(s), 504 assertion(s), 0 failure(s)`.
- Live harness `test/live/demo_guide_live.gd` (both sizes): the goals' evaluator holds the scene's own ferry and regatta
  models and the page lists both goals; a new step scrolls them into view and captures `guide_goals_occasions`.
  `LIVE-SUMMARY 62 0` at 1920x1080 and 1280x720 (63 after the review fix below).
- Frames (looked at): `scratchpad/goals2_check/guide_goals_occasions_{1920x1080,1280x720}.png` -- both goals, their why
  and "0 of 1"; `guide_goals_*` -- "Village goals: 0 of 11 reached".
- Mutation: 9 mutants, **9 killed** (the two measures swapped or zeroed, both targets raised, a kind colliding with
  `M_OWN_FOOD_DAYS`, a part left unmeasured, an off-by-one, and either `demo_village.gd` binding removed -- the last
  two killed by the live harness).
- The full suite (CI-style), the analyzer, the contracts and the independent review are run once the branch's three
  packets are in; their lines are added below under "Branch gates" and "Review".

## Review (independent `code-reviewer`, on 724a5a99)

Nothing CRITICAL or HIGH.

- **MEDIUM, answered here as a PROPOSAL (P1 below).** `regatta.gd feasts_held` is also bumped when the regatta's supper
  *lapsed* (`_settle_feast` → `_tally(null)`): a regatta held and then skipped past (the season skip) ends `ST_DONE`
  with "the race never started", nobody at the feast, and "Regatta day" reached. The reviewer reproduced it
  (`[feasts_held, race_off, winner] = [1, "the race never started", -1]`).
- **LOW, fixed.** The live harness's scroll step set an absolute offset from a relative distance; it now adds the
  distance (`+=`) and checks the page really scrolled with the title at the top.
- **LOW, kept.** The goals suite sets the two counters directly; the ferry and regatta suites already cover what
  raises them (`test_demo_ferry.gd`, `test_demo_regatta.gd`).

## PROPOSAL for Brendan

- **P1. Does a regatta skipped past count as "Regatta day"?** Built: it counts (`feasts_held` is the counter decision
  0901's option (b) named, "regattas held"). A regatta is only skipped past by the player's own season skip, whose
  news line says that meals were not lived.
  (a) As built: any regatta day that ran to its end counts.
  (b) Count only a regatta whose feast supper was served (a second counter in `regatta.gd`, raised in `_tally` when the
  kitchen published the meal; about five lines and one test).
  Recommendation: (b), since the goal's own words promise the race and the feast; it is a small follow-up if chosen.

## Branch gates (`feat/demo-small-leftovers`, all three packets and their review fixes; 2026-10-07)

- **Full suite, CI-style** (assets moved aside, `godot/.godot` deleted, fresh import, `./tools/run_tests.sh`):
  `9149 test(s), 612086 assertion(s), 0 failure(s)`;
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)`;
  `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- **Analyzer**: `0 GDScript warning(s) in 0 of 1028 file(s)` (one run during the contracts reported a spurious
  "Cannot find member" while the cache was busy; the rerun and the run after the CI-style suite both read 0).
- **Contracts**: every check in `.github/workflows/tests.yml`'s contract and preflight groups (43 commands, among them
  `decision_numbers.py`, `ready07_arithmetic.py`, `merge_gate.py`, `setting_contract.py`, `dispatch_plan.py --validate`,
  `astra_inbox.py --check`, `generate_canonical_state_table.py --check`, `lane_notes.py --check`, the movement checks
  and `state_registry_coverage.py`) exit 0. No settlement bytes were added, so the memory ledger and capacity audit are
  unchanged.

## Brendan's rulings (2026-10-07)

**P1: (b).** Relayed by the coordinator; the question he approved read: "Regatta day counts only a regatta whose feast
was served."

Built:
- `regatta.gd` keeps a second latched count, `feasts_served`. It is raised in `_tally` only when the kitchen published
  the supper's meal-finalized event (`final != null`), not when the supper lapsed past (`_tally(null)`, a season
  skip).
- `village_goals.gd M_REGATTAS` reads it, and the goal's news line now says "…held its first regatta and sat down to
  its feast."

Tests:
- `test_demo_regatta.gd`: the lapsed path leaves `feasts_served` at 0 while `feasts_held` is 1; the served feast
  raises both.
- `test_demo_goals.gd`: a regatta held but not served does not reach the goal; a served one does.

Mutation of the new check: 3 mutants (count a lapsed supper, never count, the goal reading `feasts_held`), **3
killed**.

Gates for this change:
- Full suite, CI-style: `9149 test(s), 612089 assertion(s), 0 failure(s)`, 0 unexpected errors and warnings, 0 objects
  and 0 resources leaked, on both the `diagnostics:` and `log:` lines.

Review (independent `code-reviewer`, on 86ca4222). Nothing CRITICAL or HIGH. The reviewer confirmed:
- a served feast cannot reach the lapsed path;
- an unserved feast (skipped past) cannot get a meal event;
- `_tally` is the only way to ST_DONE.

Its MEDIUM is a question about what the ruling means, so it is **open for Brendan**:
- **How the code reads "served" now:** the kitchen closed the regatta supper's serving.
- **The edge case:** a supper can close with no feast hotpot eaten (no cook, or the reserved food spoiled). That still
  counts, while the news line says the village "sat down to its feast".
- **If he means "eaten by at least one resident":** count only when `attendees` is non-empty. That is a one-line change
  plus a test.

**The open point is closed (Brendan, 2026-10-07, relayed by the coordinator).** "Regatta day" counts only when at least
one resident ate the feast's main course.

Built:
- `regatta.gd` now raises `feasts_served` in `_tally` only when `attendees` is non-empty: the supper's committed diners
  who ate the bean hotpot.
- So neither of these counts:
  - a supper the season skip passed over;
  - a supper whose serving closed with no hotpot eaten.

Tests:
- New in `test_demo_regatta.gd`: `test_a_supper_closed_with_no_hotpot_eaten_is_not_a_regatta_day`. Its only diner ate
  soup, and the day is held but not counted.
- The attendance test now also asserts that a day where someone ate the hotpot counts.

Mutation: 3 mutants (count any closed supper, count every day, the check inverted), **3 killed**.

Gates after merging `origin/master` (#231, wildlife and weather):
- **Merge:** `demo_village.gd`, the field guide and the README merged additively; both sides' hooks are kept.
  `RULINGS.md`'s 2026-10-07 rows are combined.
- **Full suite, CI-style:** `9205 test(s), 647495 assertion(s), 0 failure(s)`; 0 unexpected errors and warnings, 0
  objects and 0 resources leaked, on both the `diagnostics:` and `log:` lines.
- **Analyzer:** `0 GDScript warning(s) in 0 of 1041 file(s)`.
