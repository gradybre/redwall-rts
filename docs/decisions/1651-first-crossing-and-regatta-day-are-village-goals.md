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
  `LIVE-SUMMARY 62 0` at 1920x1080 and 1280x720.
- Frames (looked at): `scratchpad/goals2_check/guide_goals_occasions_{1920x1080,1280x720}.png` -- both goals, their why
  and "0 of 1"; `guide_goals_*` -- "Village goals: 0 of 11 reached".
- Mutation: 9 mutants, **9 killed** (the two measures swapped or zeroed, both targets raised, a kind colliding with
  `M_OWN_FOOD_DAYS`, a part left unmeasured, an off-by-one, and either `demo_village.gd` binding removed -- the last
  two killed by the live harness).
- The full suite (CI-style), the analyzer, the contracts and the independent review are run once the branch's three
  packets are in; their lines are added below under "Branch gates" and "Review".
