# 0901 — Review batch 6: six lanes merged over the hygiene sweep, and what the merges needed
Date: 2026-10-01 · Status: Accepted

Numbered 0901: the batch-6 integration brief assigned the 0901–0909 block, and no branch or worktree used any number
in it. This record uses 0901 only.

## Decision

`integrate/review-batch-6` is `chore/test-hygiene` (PR #210: master plus decision 0501's zero-warning, zero-leak,
zero-unexpected-log gates and its warning sweep) with six finished, reviewed lanes merged `--no-ff`, in this order:

| # | Lane | Head | Decisions | Conflicts |
|---|---|---|---|---|
| 1 | `feat/demo-notices` | 346e0550 | 0591 | `demo_notices.gd` |
| 2 | `feat/demo-milestones` | 2404da50 | 0781 | none |
| 3 | `feat/demo-playtest-log` | 701e5744 | 0562 | `ui/demo_menu.gd` |
| 4 | `feat/demo-map-layers` | 731094b5 | 0581 | none |
| 5 | `tools/scale-test` | f8cfd7ee | 0561 | `cast/demo_cast.gd` |
| 6 | `feat/water-ferry-regatta` | 72947bfc | 0437–0439 | `boats/boat_fleet.gd`, `boats/boat_routes.gd`, `kitchen/kitchen.gd`, `songs/demo_songs.gd` |

Every lane but milestones was cut before the sweep. The sweep renamed shadowing locals and parameters, so a lane's
line that still uses an old name would resolve to the method that name shadowed, with no warning from git. Each
merge was therefore checked three ways: every lane-added line was matched against the names the sweep removed from
the same file; `tools/gdscript_warnings.py` ran on every `.gd` file the merge touched; and the affected suites ran.

## The conflicts, each resolved keeping both sides

- **`demo_notices.gd` `post` / `_append`.** The sweep and the lane each renamed the parameters that shadowed the
  feed's accessors (`message`, against the lane's `words`). The lane's file holds the same renames plus the tier API,
  so it was taken whole.
- **`demo_menu.gd` `_build_settings`.** The sweep renamed the local `page` (it shadowed `page()`) to `sheet`; the lane
  added its playtest section after the sound section. Both kept.
- **`demo_cast.gd` `build` and `advance`.** The sweep renamed the local `actor` to `cast_actor`; the lane rewrote the
  same loop for the stress cast's clones. The lane's loop is kept with the sweep's name. **This was the batch's one
  silent hazard:** `demo_cast.gd` has an `actor(i)` method, so a stray `actor` would have resolved to it. `advance`
  takes the lane's `_step_actors`, whose locals were already named apart.
- **`boat_fleet.gd` `_row`.** The lane's stroke scaled by `pace_permille`, with the sweep's integer-division
  annotation kept on `moved` (the lane had annotated only its own line). `line_of`: the lane's ferry-boat line.
- **`boat_routes.gd` `validate`.** The lane's per-jetty checks, with the loop variable `route_index` as the sweep
  named it (`route` is a static function in that file). The refusal strings keep the word "route".
- **`kitchen.gd` `_wanted`.** The lane's occasion batches first, then the sweep's `call_at` (a local `call` shadows
  `Object.call`).
- **`demo_songs.gd` `_working`.** Three ways of knowing a resident is at work, in order: the ferry lane's added work
  readers (ferry and race crews), the scale lane's one-pass board mark (decision 0561's O(N²) fix), then the
  per-resident board scan.

The ferry's work-board source stays `SOURCE_FERRY = 8`, with `SOURCE_WALK = 9` (`work/work_ids.gd`). The cellar's
`SOURCE_STORES` and the hall's `SOURCE_HALL`, which also used 8 on their own lanes, are renumbered when they merge.

## The fixes

1. **The ferry and regatta suites leaked at exit.** Written before the leak gate, each rig's ferry held a `flooded`
   lambda, and each rig's regatta its `post`, `record_deed` and `share_feast` lambdas, that capture the rig, which
   holds the ferry or regatta: a RefCounted cycle. Alone, `test_demo_ferry.gd` leaked 996 objects and 31 resources and
   `test_demo_regatta.gd` 1,232 and 47. `after_each` now clears those hooks, and both leak 0. The production wiring
   (`demo_ferry.gd`, `demo_regatta.gd`) captures nodes and the village's services, so it closes no cycle.
2. **The playtest log crumbs the compared map layer.** Decision 0562 crumbs the map layer shown; decision 0581 added a
   compared one. A `compare layer` view probe now reads `lenses.compare` (-1 when none). The input harness checks it is
   bound, and deleting the probe fails that check at both sizes.

3. **"Every dish on the table" now includes the regatta's bean hotpot.** The full suite found this one, and nothing
   textual pointed at it: the ferry lane added the kitchen's fourth dish (decision 0438), so `DISH_COUNT` is 4, and
   decision 0781's ruling has the goal's target follow `DISH_COUNT` as dishes are added. The goal now needs the
   hotpot, which the kitchen cooks only for the regatta (the first is in the first summer). The ruling is followed and
   the goals suite's ledger test updated: the everyday three read 3, and the hotpot completes the count. The
   goal's WHY sentence still names only porridge, soup and the fish stew. **For Brendan:** (a) keep the ruling, so
   the goal waits for a regatta, and add the hotpot to the WHY; (b) count the everyday dishes only (the three), as
   `kitchen.gd cookable_text` already treats the hotpot apart. Recommendation: (a), since a regatta is a goal worth
   having.

4. **The guide harness counted nine residents where CI has six.** CI failed on PR #212 (run 36960572929): `7854
   test(s), 574805 assertion(s), 2 failure(s)`, both `test_demo_guide_live.gd`, at 1280x720 and 1920x1080. The
   milestones lane's Goals-tab check required `Residents: 9 of 12`, the staged manifest's nine. With no assets staged,
   as in CI, `demo_cast.gd` spawns `PLACEHOLDER_COUNT` (six) placeholders, and M1 reads `Residents: 6 of 12`. The
   integration's local run had assets staged, so it passed. The check now takes the count from the scene's cast
   (`actor_count()`, which must be above 0) rather than a literal. It was rerun with no assets and a fresh import, as
   in the CI workflow. `gh run view --log` cuts this job's log at the 502,700-character tuple marker
   `test_construction_columns.gd` prints, so its copy ends there with no summary line. The job's full log
   (`gh api repos/{owner}/{repo}/actions/jobs/<id>/logs`) holds the summary and the failures.

No lane added an analyzer warning after these resolutions.

## Overlaps checked, and left as they are

- **Keys.** The only new key is the playtest log's **F12** (`playtest/playtest_log.gd MARK_KEY`). Nothing else binds
  F12 (`demo_window_keys.gd` binds F11; the help lists F12). Notices, goals and map layers each state that they add no
  key, and the ferry and regatta add none.
- **Notice tiers for the ferry and regatta.** Their posts already take the right tier by inference: the ferry's
  closure and storm WARNINGs are normal and its NOTEs info, the regatta's chronicle and its lines are info, and the
  stranded-cargo incident (SEVERITY_WARNING) is normal. Naming those tiers would change nothing. Naming a **kind**
  would change behaviour, because a named kind's repeats group within a game day and can be snoozed. Decision 0591
  itself left every existing call site unchanged, so these are left too.
- **Goals for the ferry and regatta. Not registered.** The registration API makes this a few lines
  (`ferry.crossings_done`, `ferry.ferried_milli` and `regatta.feasts_held` are latched counts), but the titles and
  targets would be new design, and Brendan approved decision 0781's goals as a set. One binding looks natural,
  M4's `feasts` ("12 completed feasts") to `regatta.feasts_held`, but that counter increments when the occasion's day
  ends. The GDD counts *completed* feasts (FeastState COMPLETE), and the demo cannot yet serve the Hearth feast's
  second course and infusion (decision 0438), so the two are not the same count. **For Brendan:** (a) leave both as
  they are; (b) add village goals "First crossing" (ferry crossings >= 1) and "Regatta day" (regattas held >= 1);
  (c) also bind M4's `feasts`. Recommendation: (b), after the feast's missing-courses ruling in decision 0438.
- **Breadcrumbs on new panels.** Panels are crumbed through the input gate's top modal layer, and the right column's
  panel through its own probe. So the ferry's and regatta's sections (in the Water panel), the feast command (which
  opens that section), the Goals tab (in the village guide) and the lens legend all show up without new probes. Only
  the compared layer needed one (fix 2).
- **The scale lane's tolerance** (`test_scale_stress.gd EXIT_LEAK`: exactly one engine "resources still in use at
  exit" line from the harness's child process) is kept unchanged.

## Gates

Run on the tip with these fixes, as `.github/workflows/tests.yml` runs them:

```text
./tools/run_tests.sh
7854 test(s), 574895 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 290 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
python3 tools/gdscript_warnings.py --max 0
0 GDScript warning(s) in 0 of 808 file(s)
```

That run had the demo's assets staged. After fix 4 the suite was rerun as CI runs it: `godot/demo/assets` moved
aside, `godot/.godot` removed and re-imported with `godot --headless --path godot --editor --quit`:

```text
./tools/run_tests.sh
7854 test(s), 574813 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The 353 tolerated diagnostics match CI's run 36960572929, which a staged run (290) does not. With the assets back,
the guide harness reads `Residents: 9 of 12` and passes.

The live harnesses run inside the suite. Each one that draws the village (guide, input, layout, map layers, notices,
people, planner, routes, session) runs at 1280x720 and 1920x1080. The playtest log's capture harness takes no size
and draws no layout, so it runs once. The scale harness runs at 25 residents (`test_scale_stress.gd`). Every other
step of both CI jobs exits 0: the runner diagnostics self-test, the preflight fault injections, the UI refinement
contract, `ready07_addendum_checks.py --godot`, decision numbers, the ledger arithmetic, the merge gate, the dispatch
graph, the Astra inbox, the registry and its generated table, the cycle handoffs, the capacity audit (`--check`: no
core source changed, so the sidecar needs no regeneration), the component column schema, lane notes, the movement
checks, state-registry coverage and the validator self-tests.

## Source

The batch-6 integration brief (2026-10-01); decisions 0501, 0437–0439, 0561, 0562, 0581, 0591 and 0781.
