# 0902 — Review batch 7: sixteen lanes merged, the reconciliations between them, and what the gates found
Date: 2026-10-02 · Status: Accepted

Numbered 0902: the batch-7 integration brief assigned it, and no branch, worktree or commit in the repository uses it.

## Decision

`integrate/review-batch-7` is `integrate/review-batch-6` (PR #212) with sixteen finished, reviewed lanes merged
`--no-ff`, in the brief's order, and batch 6's later fix (54237c05, the guide harness's cast count) merged between the
two phases.

| # | Lane | Head | Decisions | Conflicts |
|---|---|---|---|---|
| 1 | `feat/demo-winter-fuel` | e6533e72 | 0571 | README, `night_routine.gd`, `resident_brain.gd`, `demo_village.gd`, `farm_season.gd`, `field_guide.gd`, `help_topics.gd`, `kitchen.gd`, `demo_menu.gd` |
| 2 | `feat/demo-standing-orders` | 5c07e71f | 0711 | README, `demo_village.gd` |
| 3 | `feat/demo-day-night` | fb564520 | 0541 | `demo_village.gd` |
| 4 | `feat/demo-seasonal-trees` | 6e72d5cb | 0551 | README, `demo_village.gd`, `demo_input_live.gd` |
| 5 | `feat/demo-camera` | 3d7efb20 | 0801 | README, `demo_access.gd`, `demo_village.gd`, `demo_news_strip.gd` |
| 6 | `feat/demo-multiselect` | 76e7a7fa | 0791 | `demo_layout_live.gd` |
| 7 | `fix/demo-pause-card` | 9856824b | 0931 | `demo_village.gd` |
| 8 | `tools/balance-sim` | d60fbeec | 0911, 0912 | none |
| 9 | `feat/demo-chronicle` | e0a81d5f | 0631 | `demo_village.gd` |
| 10 | `tools/soak-test` | 0688f903 | 0921–0923 | `farm_alerts.gd` |
| 11 | `feat/demo-cellar` | a95b13ee | 0611, 0612 | `demo_village.gd`, `work_ids.gd` |
| 12 | `feat/demo-great-hall` | 17ac86dd | 0771 | README, `demo_village.gd`, `work_ids.gd` |
| 13 | `feat/demo-infirmary` | b5e74923 | 0621–0623 | README, `demo_village.gd`, `demo_menu.gd`, `demo_work.gd`, `work_ids.gd`, `demo_input_live.gd` |
| 14 | `feat/demo-dishes` | 83d9eceb | 0601–0603, DEC-045 | `setting_decisions.md`, README, `field_guide.gd`, `ingredient_takes.gd`, `kitchen.gd`, `kitchen_text.gd`, `meal_rules.gd`, `test_demo_kitchen.gd` |
| 15 | `feat/demo-foraging` | 6aaec0c8 | 0681, 0682 | README, `demo_village.gd`, `farm_catalog.gd`, `field_guide.gd`, `kitchen.gd`, `meal_rules.gd`, `work_ids.gd`, `test_demo_kitchen.gd` |
| 16 | `feat/demo-crop-plans` | ebae2636 | 0881–0886 | README, `farm_alerts.gd`, `farm_planner.gd`, `farm_sim.gd`, `farm_stock_view.gd`, `help_topics.gd`, `demo_work.gd` |

Every conflict was resolved keeping both sides; where the two sides could not both stand, the choice is a
reconciliation below. The gates ran once after Phase A, and their findings were fixed before Phase B. Phase B was
rehearsed on a scratch branch, then replayed onto this one with `git rerere` (the same resolutions, the same merge
messages), so its merges sit on top of the Phase A fixes.

### Silent renames

Decision 0901's three checks ran after every merge: each lane-added line matched against the names the hygiene sweep
removed from the same file, `tools/gdscript_warnings.py` on the files the merge touched, and the affected suites. Ten
lanes were cut before decision 0501's sweep. What came up, each kept on the sweep's name:

- `kitchen.gd`: the sweep renamed `_on_hour`'s, `_top_up`'s, `_reserve_input`'s and `_even_inputs`' parameter
  `hour_index` to `at_hour` (it shadowed `hour_index()`), and `_wanted`'s local `call` to `call_at`. The winter's
  `skip_to_hour`, the dishes' input loops and the foraging's two-course code all wrote `hour_index`; inside those
  functions it would have been the method.
- `farm_season.gd` `_add_runway(kitchen, _sim)`, `night_routine.gd` `set_alarm(alarm_test)`,
  `farm_stock_view.gd`'s local `store_shelf`, and `field_guide.gd`'s `made` (the foraging lane's `entry` shadowed
  `entry()`).
- The analyzer found 9 warnings in Phase A (camera, multiselect, soak) and 18 in Phase B (hall, infirmary): three
  redundant awaits, shadowing locals and parameters, two unused parameters, and intended integer divisions. Each was
  fixed by intent, as decision 0501 does; none was a bug.

## The reconciliations

1. **Work-board source ids.** `work/work_ids.gd`: FERRY 8, STORES 9, HALL 10, CARE 11, FORAGE 12; `SOURCE_COUNT` 13;
   a queued walk `SOURCE_WALK` 13; `SOURCE_NAMES` in that order. A search confirmed only `work_ids.gd` writes the
   numbers; every reader uses the constants, and the suites check `SOURCE_WALK == SOURCE_COUNT`. The foraging suite's
   "the next source" check now expects 12.
2. **Pantry item keys.** The dishes lane's `hazelnut`, `mushroom` and `raspberry` are the foraging lane's `nuts`,
   `mushrooms` and `berries` (`dish_book.gd`); they are struck from `PENDING_SOURCES`, which now holds potato (no potato
   crop: the dishes' definition is kept) and honey. Items in `farm_catalog.gd`, in merge order: potato 24, honey 25,
   nuts 26, mushrooms 27, herb 28, berries 29 (`PANTRY_ITEM_COUNT` 30, `FIRST_FORAGE` 26); categories honey 8, nuts 9,
   mushrooms 10, herb 11, berries 12, with `GOODS_CATEGORY`, `GOODS_SHELF_HOURS` and `meal_rules.gd CATEGORY_WORDS`
   extended to match. The ingredient selectors are 64-bit and every item is under 64. With the forage items in, the
   pasty, the scones and the woodland pie can be cooked; the root pie waits for potato and the cordial for honey.
   `tools/make_demo_pantry_index.py` now lists the four forage items by woodland leaves (the demo's selection: nuts
   hazelnut, beechnut, chestnut and sweet chestnut; mushrooms mushroom and button mushroom; herb mint, thyme, sage and
   rosemary; berries raspberry, blackberry, bilberry, elderberry, strawberry and whortleberry; never nutmeg, a spice).
3. **The nut loaf is the recipe book's row 19**, `nut_loaf`, cooked as §5.7's own `nut_loaf` row (flour 2 + nuts 2 +
   water 1, 3 × 2600 NP, 24 WU, 72 h; an adopted row). `meal_rules.gd DISH_NUT_LOAF` names it (4 on its lane; the id
   semantics are kept, the number is the book's). It carries a new meal kind, `dish_book.gd OCCASION`, which the cook's
   choice never picks; `is_occasion_dish` reads that kind. The regatta's two-course occasion now reserves and counts
   every input of each course from the book's columns, and the Ready food estimate leaves occasion dishes out.
4. **The bean hotpot: the dishes lane's ruling is kept.** Decision 0438 (the ferry lane) cooked the hotpot only for an
   occasion; decision 0601, ruled by Brendan ("the hotpot cooked from the start"), made it an everyday supper dish. It
   is both: the cook may choose it for supper, and the regatta still cooks it as the feast's main course. The kitchen
   suites, the regatta's skip test (the supper may go back to the hotpot, from its own reservation) and the standing
   orders (peas are now a food crop) follow that. See question 1 below.
5. **"Every dish on the table" counts everyday dishes.** Decision 0781's ruling has the goal follow the recipe book. It
   now counts `meal_rules.gd is_everyday_dish`: served at breakfast or supper and waiting for no ingredient. That
   leaves out occasion dishes (the nut loaf), drinks (the cordial) and dishes still waiting for a source (the root pie):
   17 of the book's 20 today, rising as sources land. The target is read when the goals are registered
   (`village_goals.gd EVERYDAY_DISHES`); the part reads "Everyday dishes cooked". A standing order's food crop uses the
   same test.
6. **Hearths lit.** `night_lights.gd set_home_lit` is bound (`demo_village.gd home_lamp_lit`): the hall's door lamp
   follows `hearth_fuel.gd hearth_lit(HALL)`, fuelled and demanded. The three surface residences and the kitchen have no
   hearth in the winter's model (its homes are the burrow rows below), so they keep the lamps' hours. The burrow
   hearths' glow and smoke were already the winter's (`fixture_view.gd set_lit` through `tunnel_ext.gd hearth_lit`).
   The hall's panel says its hearth in the winter's words on its Heat line. See question 3.
7. **Work pace.** The winter adds its Chilled factor to the infirmary's `services.work_pace`. Each frame it sets every
   resident's `resident_brain.gd work_permille` from the composed pace, so the outdoor crews apply health × Chilled
   once, through `work_credit`. The infirmary's heal and gather work read the pace directly, never through
   `work_credit`, so nothing applies a factor twice. A hurt, Chilled resident works at 680‰
   (`test_demo_winter.gd`).
8. **Group-select statuses.** Chilled (`cold_exposure.gd is_chilled`) and Injured (`care_state.gd is_hurt`) are one row
   each in `demo_village.gd _build_group_select`.
9. **Goals.** M4's `fuel` part is bound to `demo_winter.gd fuel_winter_days_milli`: the stores' wood over a winter
   day's demand (every burning hearth at 4 U, plus the cooking mean), in thousandths of a day, whatever today's
   season. This is the GDD's "fuel ≥ 18 winter days". Today's fuel-days, the figure `metrics_into` reports, is
   `NO_DEMAND` in summer.
10. **Chronicle and tapestry.** `chronicle().page_written` weaves a `KIND_CHRONICLE` entry, once a season; a new goals
    hook, `demo_goals.gd also_reached`, weaves each goal or milestone reached as `KIND_MILESTONE`, once a goal. Both are
    wired in `demo_village.gd _weave_history`.
11. **Cellar and infirmary structures.** Their `cast_space.gd` and `tunnel_control.gd` hunks were identical, and git
    merged them once. The slots are documented: the cellars 0–1, the infirmary 3. The two `stand_spot.gd` copies are
    one, `demo/cast/stand_spot.gd`.
12. **One care shelf, two sources.** A treatment's herb is the pantry's `herb` item. While the care shelf is under its
    12 U, the pantry's free herb (the foragers') is moved onto it at each look, day or night. Only what is still short
    sends the herbalist to the infirmary's patch. `ingredient_takes.gd withdraw_free` takes only unreserved food, so the
    feast's infusion keeps the herb it holds. This was the simplest consistent option: neither lane's gathering changes.
13. **Balance and soak, smoke runs only.** A 6-game-hour soak with a Restart at hour 3 passed with 0 flags. The balance
    matrix (seed 1 × hands-off and light-touch, 2 days) failed at first. With the sounds staged, the year runner quit
    while they played, leaving "5 resources still in use at exit", which the matrix counts as a failed run. The balance
    lane's own tree does the same. `balance_run.gd` now frees the village and quits 30 frames later, as the soak test
    does, and both runs pass.

## The pause card and its neighbours at 1280x720

Measured on the real scene (paused, the guide's card up, the camera following, three news lines; the surface and the
U view):

| Pair | Before | After | |
|---|---|---|---|
| News over the Map layer picker | 74 px (decision 0801) | 2 px (the frames' borders) | fixed: the news fits its band less the camera row (`demo_news_strip.gd`), drawing fewer lines |
| Party actions docked at 100 % | undocked (Follow + Select idle) | docked | fixed: Select idle flows in the actions (`demo_party_panel.gd add_top_row`) |
| Pause card over the Map layer picker, U view | 254 × 32 px | clear | fixed after Brendan's ruling on question 4: it falls back to the top of the alert column (`demo_pause_card.gd keep_clear`) |
| Pause card, guide card, camera strip, news (surface) | clear | clear | |

At 1920x1080 nothing overlaps.

## What the gates found

- **Phase A, staged.** Five failures, all from lanes meeting:
  - The layout harness: the party actions no longer docked at 100 % (above).
  - The people harness: it paused before the village had opened, because there are two more prewarm steps now.
  - The select harness: another resident stood in front of the mouse it double-clicked.
- **Phase A, CI mode** (no staged assets; the cast is six placeholders of one species). Five failures, from lanes
  whose harnesses had only been run with the assets staged:
  - The chronicle harness: its deeds named residents 5, 6 and 8.
  - The opening pantry: its Ready food was fixed for nine residents.
  - The select harness: its names took first words, and it expected two species.

  Each check now derives the value from the scene.
- **Phase B.**
  - A 63-object leak in `test_demo_cellar_building.gd`: the stores node's cellar bar is the village's to parent, so
    the test frees it.
  - The hall harness counted the tapestry's entries. Goals now weave in too, and "A full larder" is reached at the
    first hour (question 2).
  - The dishes, kitchen, crop roles, regatta and forage suites asserted the lanes' separate books.
- **The final runs.**
  - CI mode: the infirmary harness's "the board's residents fetch its materials" fails on its own lane too where the
    assets are not staged. The placeholder bodies have no carry clip (`resident_brain.gd can_carry`), so nobody may
    fetch. The harness now reads whether the cast can carry, and with no carrier checks that every place waits on
    "can't carry a load".
  - Both modes: the select harness's runtime names failed to compile in a main loop's script, because they preloaded
    a script whose dependencies name the autoloads. It now loads that script at run time.
  - Staged, run beside the CI-mode run: one layout check ("party 9: every member row reachable") failed under the
    doubled load. Rerun alone, the layout harness passed at both sizes.
- **Batch 6's 54237c05** (the guide harness counts the cast's residents) is merged.

## For Brendan

1. **The hotpot.**
   - (a) Everyday supper dish and feast main course (built, from 0601's ruling).
   - (b) Occasion only, as 0438 had it.

   Recommendation: (a).
2. **"A full larder" is reached at the first hour.** Decision 0912's opening pantry is four days of food for nine.
   - (a) Keep.
   - (b) Raise the goal above the opening stock.
   - (c) Count only food the village has cooked or brought in.

   Recommendation: (c).
3. **The hall's door lamp follows its hearth strictly**, so it is dark on a night with no heat demand (the first spring
   night).
   - (a) As built.
   - (b) Dark only while the hearth is out of fuel or let go out.

   Recommendation: (b), with the residences still unbound.
4. **The pause card covers the Map layer picker's top row in the U view at 1280x720 while the guide's card is up.** No
   placement is clear of everything there.
   - (a) Fall back to its UI-SET-086 place at the top of the alert column, over the HUD's alert cards.
   - (b) Move below the picker, over the news.
   - (c) Leave it.

   Recommendation: (a).
5. **The hall's tier-2 fuel factor** (×0.75, decision 0771) is not applied to the winter's hall hearth.
   `hearth_fuel.gd` has one rate for every source. Recommendation: a per-source tier factor, in a follow-up.
6. **Two herb patches.** The infirmary's patch by the south road and the forage basin's herb bank both feed the one
   shelf. Recommendation: let the herbalist gather through the forage store when the Buildings-panel follow-up (0623 P4)
   touches the infirmary.
7. **The herb moves from the pantry to the shelf at once**, not carried. Recommendation: keep until stores hauling is
   generalised.
8. **The soak report's self-test** (`tools/test_soak_report.py`) passes but is not in CI; the balance lane added its
   own. Recommendation: add it.

## Brendan's rulings (2026-10-02)

He took the recommended option on all eight questions:

1. **The hotpot** stays an everyday supper dish and the feast's main course, as built.
2. **"A full larder" counts only food the village cooked or brought in.** Built:
   - The part is now "Ready food of the village's own" (`village_goals.gd M_OWN_FOOD_DAYS`): the Ready food less what
     the opening stock still in the pantry would cook. The opening stock left is read from the pantry's withdrawn and
     spoiled ledger (`opening_pantry.gd portions_left`; its lots are the oldest, so they are spent first).
   - `guide_world.gd opening_stock` says whether the village opened with that stock.
   - The goal is no longer reached at the first hour; the hall harness checks it on the real scene.
3. **The hall's lamp is dark only while its hearth is out of fuel or let go out** (`hearth_fuel.gd hearth_cold`), not
   on a night that wants no heat. Built; the daylight harness lets the hearth go out and sees the lamp go dark. This
   supersedes the strict reading in reconciliation 6.
4. **The pause card falls back to the top of the alert column** (its UI-SET-086 place, over the HUD's alert cards)
   where stepping below the top card would cover the Map layer picker. Built (`demo_pause_card.gd keep_clear`); the
   session harness checks it in the U view at both sizes, and fails without it.
5. **The hall's tier-2 fuel factor** goes to a follow-up: a per-source tier factor in `hearth_fuel.gd`. **Pending.**
6. **The two herb patches** are merged during the Buildings-panel work (0623 P4). **Pending.**
7. **The herb moves from pantry to shelf at once**, for now, as built.
8. **`tools/test_soak_report.py` runs in CI**, with the validator self-tests. Done.

## Master, merged after the batch

`origin/master` (batch 6 #212, demolition D4 #214 and the art-lock request #213) is merged in after the rulings.

- **D4's settlement changes.** D4 changed `settlement_system.gd`, `construction.gd`, `economy_system.gd`,
  `ui_manager.gd` and `main.gd`; the boot now builds the starter colony, and its buildings own the opening stores.
  None of these files is a demo file, and no lane in this batch changed them.
- **How the demo touches them.** The demo reads the settlement only through `UIManager`'s opening pause and the HUD,
  which it repaints with its own figures. The only demo files master changed are `gear_locker.gd` (a well-formed
  owner, decision 0533) and a comment in `woodland_ornament.gd`, neither touched by a lane here.
- **The check.** The full suite and every live harness ran on the merged tip in both modes (below).
- **The capacity audit.** It is regenerated only if its `--check` fails.

## Gates

Run on the tip (f3aca5dc: the batch, Brendan's rulings 2, 3, 4 and 8, and origin/master) as
`.github/workflows/tests.yml` runs them, in both conditions:

```text
./tools/run_tests.sh                                   # assets staged
8644 test(s), 589215 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 290 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

./tools/run_tests.sh                                   # as CI: assets moved aside, godot/.godot deleted, re-imported
8644 test(s), 589145 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

python3 tools/gdscript_warnings.py --max 0
0 GDScript warning(s) in 0 of 980 file(s)

python3 tools/test_run_tests_diagnostics.py
test_run_tests_diagnostics: PASS -- expected, missing, unexpected, tolerated and leaked all classified
```

The live harnesses run inside the suite. All sixteen that take a size passed at both 1280x720 and 1920x1080 (32 size
runs in each condition): camera, care, chronicle, daylight, guide, hall, input, layout, lens, notices, people, planner,
routes, select, session and winter. The playtest log's harness takes no size and draws no layout, so it runs once.
Every other step of both CI jobs exits 0:

- the twenty preflight fault injections and allocation discriminators;
- the demo audio staging self-test;
- the UI refinement contract;
- `ready07_addendum_checks.py --godot` (PASS);
- every "Specification contracts" step: decision numbers, the ledger arithmetic, the merge gate, the dispatch graph, the
  Astra inbox, the registry against its source and its generated table, the three cycle handoffs, the component column
  schema, lane notes, the movement checks, state-registry coverage and the validator self-tests, including the balance
  and soak reports'.

The capacity audit (`--check`) passes unregenerated on the merged tip, with D4's `construction.gd` in it: master's own
CI had regenerated it with that change, and no lane here touches `scripts/core`.

## Source

The batch-7 integration brief and the coordinator's additions (2026-10-01/02: merge 5c07e71f and batch 6's 54237c05;
Brendan's rulings on 0623, 0631, 0881–0886 and 0921, and DEC-046; run the suite as CI does); decisions 0501, 0901 and
every lane's records listed above.
