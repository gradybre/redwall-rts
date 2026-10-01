# 0781 — Village goals and the milestones' road: a data-driven goal book on the game hour
Date: 2026-10-01 · Status: Accepted (feature approved by Brendan 2026-10-01, #57). The village goals, their targets and
the presentation choices below are PROPOSALS awaiting his ruling (see "For Brendan").

Numbered 0781: no record numbered 078x exists on any branch; 0781-0789 was the band the brief gave. Code:
`godot/demo/goals/`.

## Decision

The demo gets a **goal book**: optional goals that guide play once the first-village guide (decision 0481) is done,
shown in the village guide's new **Goals** tab (O, the HUD's Objectives command -- no new key). Each goal is a **data
entry** -- id, title, a short why, a group, one or more parts -- and each part a target, a unit and a **measure**: a
small evaluator over state the village already keeps (the stores, the calendar, the kitchen's counts and logs, the
pantry, the bridges, the tunnels, the seasonal planner's record). The book is **evaluated on the game hour**, never per
frame. A reached goal is said **once** as a Village news note (the notice and the history entry) and stays reached.
**Nothing is granted.** Later features add their own goals through a registration API (`register`, `bind_measure`,
`keep`; documented in `godot/demo/README.md`).

## The rules used

- **The adopted milestones come first** (GDD §5.11, the milestone table): M1 Settled Hearth (day ≥ 4, ≥ 12 residents,
  200 portions prepared cumulatively), M2 Abundance (population ≥ 48, survive the first winter, master 3 recipes), M3
  Deep Roots (population ≥ 80, year ≥ 2, food-days ≥ 8), M4 Hearth Charter (year ≥ 3, population ≥ 120, 8 named
  specialists, 10 mastered recipes, 12 feasts, mean mood ≥ 6500, ready food ≥ 18 winter-demand days, **fuel ≥ 18 winter
  days**, everyone warm-bedded, no starvation/exposure deaths this winter, all held through the last three winter days).
  Every condition is a part worded as the GDD states it. What the demo models is measured; what it does not is declared
  **without a measure**, shown "not in this demo yet", and blocks its milestone until a later feature binds one (M4's
  `fuel` part is there for the winter-fuel work to bind, in thousandths of a day).
- **Reaching a milestone's conditions here grants nothing.** REQ-SET-154 ("unlock its catalog entries once and record
  the triggering tick") and R-BUILD-DOM-001's masks belong to a progression system the demo does not run (`demo/water/fishing_driver.gd`
  already notes "the demo runs no milestones"); the memory catalog's `milestone(+500, 24 h)` is likewise not applied.
  Said as "Milestone conditions met: ... (the demo grants no unlocks)", it never claims an award. The demo has nine
  residents and no arrivals, so no milestone is reachable in it today.
- **Progressive disclosure** (GDD §6): disclosure uses saved objective/milestone state, not elapsed time; REQ-SET-166
  allows inspecting an advanced panel early with its requirements shown. So the Goals tab is open from the start and the
  goals are measured from the first hour (one done before the player looks is already done, as the guide's P7 rule).
- **UI**: UI-SET-033 (Objectives command, O) "opens progress"; UI-SET-071 asks for a keyboard-readable table, not an
  image -- the page is text rows. UI §7 files a milestone as INFO with its history retained: the demo's Village NOTE.
- **The guide is not changed**: its four objectives, their completion and its card are as decision 0481 left them. The
  goals' owner watches `steps.is_complete()` and, once, at the next game hour (so the guide's own completion line has
  the news strip first, and the guide's "chronicled once" check still holds), posts "What next: the village guide's
  Goals tab (O) holds goals to aim for now the first village stands."

## Why this shape

- **Hourly, not per frame**: the brief's rule, and the cost: `demo_goals.gd update()` is an integer compare of the
  calendar's hour index until it changes; then the ledger reads the logs and every measure is read once. The suite
  checks no object is retained across 200 frames and 24 hours of updates.
- **A ledger of its own** (`goals_ledger.gd`) for the three counts no model keeps for a whole session: portions prepared
  (the kitchen's batch log is trimmed to 256, so each new batch is read from its tail by `batches_cooked`), the dishes
  ever cooked, the suppers at which every resident ate cooked (the meal log read by its keys, which only grow, and a
  supper judged only once its day has ended -- the kitchen takes a diner off the tally if a held portion is given back,
  and the planner's record reads the same tally at the day's close), and the
  clean seasons (the record keeps 48 days; a season is judged once its open day is past it). It writes nothing.
- **Parts without measures rather than leaving conditions out**: the milestone reads as the GDD states it, and a later
  feature completes it by binding one measure instead of re-registering the goal.
- **The book keeps its evaluators alive** (`keep`): a `Callable` to a RefCounted's method does not hold the object, so a
  measure whose owner went away would silently become "not in this demo yet" (a test caught exactly that).
- **Every part is read at-least**: a "none of X" goal (no one chilled) measures a latch its feature keeps.

## Consequences

- The guide window's tab constants are renumbered (`TAB_GOALS` = 1; Projects, Field guide, Help, Practice move up one).
  Every caller uses the constants.
- `guide_world.gd` gains `record` (the planner's after-action record), bound in `demo_village.gd _guide_world`.
- Session only, like the projects: the demo cannot save.
- **Where the Great Hall's tapestry (#53) hooks**: `demo_goals.gd _on_reached(goal)` -- one line beside the news post
  once `feat/demo-great-hall` lands: `village.tapestry().add_entry(KIND_MILESTONE, goal.title, goal.said, goal.id)` (its
  `once_key` the goal's id, so a goal is woven once). Nothing here depends on it.

## Review

The independent review (code-reviewer) found: the pointer note posted in the same frame as the guide's completion line,
breaking `test_demo_guide.gd`'s "chronicled once" (HIGH; moved to the next hour); a full table judged before a held
portion could be given back (MEDIUM; judged at the day's end); a local shadowing the book's `goal()` (MEDIUM; renamed);
three tests that could not fail (MEDIUM; the milestone wording, the bridges/tunnels/Ready-food measures and the season
path under the allocation check are now driven); the harvest line's wording and a public `evaluate()` (LOW; fixed).
Mutation testing of the goal logic: every mutant killed (see the branch's report).

## For Brendan (PROPOSALS)

1. **The village goals and their targets** (demo values; the documents are silent). Harvest home 40.0 U into store;
   Every dish on the table (each of the kitchen's dishes, today 3 -- the target follows `DISH_COUNT` as dishes are
   added); A table for everyone (one supper where every resident ate a cooked portion); A full larder 4.0 days of Ready
   food (the GDD's own immigration margin, §5.11); Wood for the cold 60.0 U (the stores start at 40.0); Over the water
   (1 bridge open); A way below (3 tunnel stretches); A clean season (a whole season recorded with food harvested and no
   crop lost); The first winter weathered (year 2 reached with anyone living). *Options:* keep; retune; fewer.
   *Recommendation:* keep, retune after a playtest.
2. **Showing the milestones at all**, when none is reachable here. *Options:* (a) show M1-M4 with what the demo measures
   and "not in this demo yet" for the rest (built); (b) show M1 only; (c) hide them. *Recommendation:* (a) -- it is the
   road the full game takes, and the parts are where later features plug in.
3. **Order on the page**: the reachable village goals first, the milestones' road after (built). *Alternative:*
   milestones first. *Recommendation:* as built.
4. **Notes during the guide**: goals are measured and said from the first hour, guide or no guide. *Alternative:* hold
   their notes until the guide completes. *Recommendation:* as built -- the notes are quiet NOTEs in the news.
5. **"Survive the first winter"** is measured as the calendar reaching year 2 with anyone living (the demo cannot lose
   residents). *Recommendation:* keep until deaths exist.
6. **M3's food-days ≥ 8 reads the HUD's Ready food** (kitchen `days_of_meals_milli`); M4's "ready food ≥ 18
   winter-demand days" is left unmeasured because winter demand is not modelled. *Recommendation:* keep.
7. **The Goals tab second**, between Objectives and Projects. *Alternative:* last. *Recommendation:* second.

## Source

`docs/game_gdd.md` §5.11 (milestone table, R-BUILD-DOM-001, REQ-SET-154/155), §6 (progressive disclosure,
REQ-SET-165-168), the memory catalog (§5.7); `docs/ui_ux_controls.md` UI-SET-033, UI-SET-071, §7's severity table;
decision 0481 (the guide, its projects and the Village chronicle); decision 0451 (the planner's record); decision 0381
(the kitchen). Brief: feature #57, approved 2026-10-01.
