# 0903 — Review batch 8: the orchards and four art passes merged, the art wired into the demo
Date: 2026-10-02 · Status: Accepted

Numbered 0903: the batch-8 integration brief assigned it, and no branch, worktree or commit in the repository uses it.

## Decision

`integrate/review-batch-8` is `origin/master` (with batch 7, decision 0902) with six branches merged `--no-ff`, then the
art they carry wired into the live demo.

| # | Branch | Head | Decisions | Conflicts |
|---|---|---|---|---|
| 1 | `feat/demo-orchards` | dd41de74 | 0671–0677 | README, `demo_village.gd`, `farm_catalog.gd`, `farm_storage.gd`, `field_guide.gd`, `ingredient_takes.gd`, `kitchen.gd`, `meal_rules.gd`, `demo_work.gd`, `work_ids.gd`; and a duplicate `farm_pantry.gd reserve_at_into` git merged silently |
| 2 | `art/new-foods` | 9e80145a | 0941 | none |
| 3 | `art/second-pass` | 5f788aed | 0951, DEC-047 | the asset-library ledgers, `setting_decisions.md` |
| 4 | `art/third-pass` | daf7e111 | 0971, DEC-048 | the ledgers, `setting_decisions.md` |
| 5 | `art/style-probe` | cea27f53 | 0981 | the ledgers |
| 6 | `art/flax-icons` | 282ea923 | 0972 | the ledgers |

`art/flax-icons` was added by the coordinator during the batch ("after `art/third-pass`"); it was merged after the
style probe, which is ledger-only, so nothing between them depends on the order.

### Silent renames

The orchards branch was cut before decision 0501's sweep (its base is 6e72d5cb). Decision 0901's checks ran on it: every
identifier the master side removed from a file both sides changed was matched against the orchard's added lines (none
used one), `tools/gdscript_warnings.py` ran on the 31 files the merge touched (0 warnings), and the affected suites ran.
The one hazard git did not flag was a **duplicate function**: both branches added `farm_pantry.gd reserve_at_into` in
different places, so the merged file failed to parse. They are one function now (below). The art branches changed no
existing GDScript.

## The reconciliations

1. **Pantry items.** One `berries` row, per Brendan's ruling: the hedge yields the foraging lane's `berries` (item 29,
   `CAT_BERRIES` 12). Apple 30 and pear 31 follow it, with `CAT_FRUIT` 13; `PANTRY_ITEM_COUNT` 32; `FIRST_FRUIT` 30.
   `GOODS_CATEGORY`, `GOODS_SHELF_HOURS`, the labels, props and swatches run to match; `meal_rules.gd CATEGORY_WORDS`
   gains "fruit". The orchard reads its items through `ORCHARD_ITEMS`, a list, so it followed. The pantry index
   (`tools/make_demo_pantry_index.py`, regenerated) lists apple and pear by their LEAF.
2. **`RAW_NP_PER_U`** is the union: roots, cabbage, dried fish, honey, nuts, berries (700) and the orchard's fruit (900).
3. **Work-board sources.** `SOURCE_ORCHARD` 13 (11 on its lane), after foraging's 12; `SOURCE_COUNT` and `SOURCE_WALK`
   14; `SOURCE_NAMES` ends "Foraging", "Orchard". Only `work_ids.gd` writes the numbers.
4. **The kitchen and the basket stands.** The orchard's "never a stand lot" test sits beside master's carried-lot test in
   `ingredient_takes.gd`'s candidate and free counts, so `withdraw_free` (the care shelf's herb) never takes a lot
   waiting at a stand; `kitchen.gd _raw_candidate` (the orchard's) is kept for raw meals.
5. **`reserve_at_into`.** Master's (a cellar move's destination) and the orchard's (a basket stand) were the same
   function; master's order of refusals is kept and the orchard's lot-row check added (a reservation must have a lot
   row to land in).
6. **The field guide.** Apple and pear go to the orchard's own entry (`orchard_text.gd guide_fields`); berries keep the
   foraging entry, which now names the east orchard's hedge too.
7. **`farm_storage.gd`.** An entry may carry master's `storage_class` and `why` and the orchard's `staging` together.
8. **The bramble edge moves.** The foraging lane's "bramble edge" spot (8.0, 25.5) lay inside the orchard's east planting
   block (x 6–14, z 22–30): a tree planted there would stand on the forager. It is now (-25.0, 27.0), the south-west
   woods' edge west of the old orchard, inside the woods' 30 m reach the foraging suite holds every spot to. A
   PROPOSAL (question 4).
9. **`setting_decisions.md`** runs DEC-044, 045, 046, 047, 048. The ledgers (`meshy_tasks.jsonl`, `concept_prompts.json`,
   `files.json`, the README) keep every pass's rows: a three-way union by row (files by path), so a row either side
   added is kept and none is lost; `files.json` is 1,750 files after the last merge, its count and total recomputed.
   `prep_unit.py`'s `--allow-flat` was identical on both art branches and merged once.

## Staging, and how to reproduce it

The art passes' files are gitignored (decision 0188), so merging brings only their tools and ledgers.

- **The tools.** `tools/stage_demo_assets.py` now stages all of it. Its new `--only art` restages the art alone:
  `make_demo_food_art.py` (pass 1; cached by `<key>.made.json`) and a new `tools/stage_art_passes.py`, which runs
  `make_art_pass2.py all` and `make_art_pass3.py` (and `--icons`) only when a pass's record is missing, then writes their
  manifest rows: the world rows the demo draws, pass 3's and 0972's icons in the `icons` section, and a new `ui` section
  (portraits by cast key, the tapestry's ground and emblems, the chronicle page). Flax gets a plant row (mapped). Its
  self-test, `tools/test_stage_art_passes.py`, runs in CI with the validator self-tests.
- **What was run here**, against the shared library `/Users/brendan/Developer/redwall-rts/assets/library/`:
  `make_demo_food_art.py --library <lib>`, `make_art_pass2.py all`, `make_art_pass3.py`, `make_art_pass3.py --icons`,
  `stage_demo_assets.py --only art --library <lib>`, then `demo_texture_imports.py --godot godot`. Every step exited 0;
  nothing had to be copied from the pass worktrees (they had been copied first, and the tools' output replaced them).
- **The main checkout and the Windows build**: `python3 tools/stage_demo_assets.py` (from the main checkout, whose
  library is local), then `python3 tools/demo_texture_imports.py --godot godot`; `build_demo_windows.py` runs the second
  itself.
- **Every key resolves.** A check of the three mapping files (`food_art_mapping.json`'s 35 assets, and every staged file
  and icon key named in `art_pass2_mapping.md` and `art_pass3_mapping.md`): 147 checked, 0 missing; the manifest holds
  141 world rows, 42 icons and the `ui` section.

## The wiring

Every piece degrades to the stand-in it replaced when its art is not staged (CI has none): the same code runs either
way, and the suites check both paths without the assets.

| Art | Wired | Stand-in |
|---|---|---|
| `apple_tree`, `pear_tree` | `orchard_view.gd`: every age, KIND_FRUIT (sapling 0.2–0.45, young 0.5, full 1.0, old 1.11; the pear sunk 0.15) | the oak, small |
| `raspberry_canes`, `bramble_blackberry`, `strawberry_patch` | the hedge at size 1, no sink; the patch a third season slot | oak crowns; five plants |
| the bushes' modelled berries | hidden by the tree shader (`berry_hide`) out of season and as the stock runs down | the speckle |
| `apple_basket` | the old orchard stand, a full basket per started third while it holds apples most | baskets and heap |
| `hazel_bush`, `mushroom_forage`, `herb_patch`, `bramble_blackberry` | beside the four foraging spots; hazels and brambles season slots | nothing |
| `infirmary_ward` | `BODY_KEY`, prescaled, sunk its row's 0.33 m | the residence |
| `herb_patch` | the infirmary's patch, scaled with its stock | procedural clumps |
| item and dish icons | by key: `item_<pantry key>`, `dish_<recipe key>`; Pantry, Recipes, Kitchen tab, Stocks rows | model icon, roundel |
| `pine_scots`, `yew_ancient` | fifteen in the woods (`world/evergreens.gd`), KIND_EVERGREEN, DEC-047 sizes | none |
| portraits | the group tiles (two across while shown) and the inspector's person header | none |
| `hall_stage2` | tier 2, the timber hall's transform; its own chimney, the composed roundels kept (ruling 1) | the composed chimney and roundels |
| `hall_banner` | four tints, cloth only | the relic banner |
| tapestry ground, 8 emblems | the panel's cloth; an emblem by entry kind in place of its knot | the drawn cloth |
| chronicle page | the page's background, text inside `text_area_ltrb` | the plain page |
| window glow | each lit home's `_windows` model, emission from its lamp flag (dark by day) | dark windows |
| `oak_mature_bare` | every bare oak (`season_view.gd use_authored_bare`) | the cut |
| `tunnel_set` | `BRACE_KEY` (and the rooms' ribs) | the old brace |
| `rock_face` | the bore's walls on ROCK ground (`bore_dressing.gd`) | nothing |

**Mapped, not wired** (their features are not built): the wildlife; the bee skep and the bees; flax; the preserving and
brewing props; fire, lightning and the ice; pass 3's food and drink icons and 0972's flax, linen and wax (they are keyed:
an item added with that key picks its icon up); the find icons for coins, a map and a spring (no such finds yet); the
herb infusion's icon (the regatta's preview is plain text).

**The evergreens.** The woods had none. Fifteen (ten pines, five yews) stand among the woods' trees past the clearing's
edge, out to 50 m, mostly north, by their own seed. They are not the forestry's (never felled) and their trunks are the
cast's obstacles in every run, staged or not, so planning is the same either way. A PROPOSAL (question 3).

**The modelled berries.** The bushes carry their berries in their texture. The tree shader hides them
(`season_leaves.gdshaderinc` `berry_hide`): a ripe red texel (red over green past 5, measured: the canes' red bark stays
under 4.5) or a dark purple-black one is painted its bush's measured leaf colour by UV cell, as many cells as the stock
above its floor is short, and every one while dormant; a hidden berry is leaf from then on, so it tints and falls with
the leaves. Every other tree's `berry_hide` stays 0 and its colour is unchanged.

## Review

The independent review (code-reviewer) found one HIGH, fixed: the old orchard stand's full apple baskets were hidden by
the east stand's pass. Its MEDIUMs were fixed (the bare oak shares the canopy's material, so a faded one keeps its snow;
the evergreens read the spots from their owners) or answered (the parallel `stock_rows`/`stock_row_dishes` loops are held
together by a test). Its thirteen mutants that survived the first tests are all killed now. The UI lane's own review
(portraits, tapestry, chronicle) found one HIGH (no production caller: the `demo_village.gd` hooks, added) and five
MEDIUMs, all fixed by that lane; the hall lane's review found no CRITICAL or HIGH beyond question 1.

## What the gates found

- **The select harness** failed two checks at both sizes: the orchard's opening work puts residents on tasks at once, and
  a resident on a task reads as working, not "can't get there". The harness now holds its forced resident under no order
  while it reads the statuses.
- **The orchard and forage suites** asserted the lanes' own numbers (item 26/27, CAT 11, source 11, `PANTRY_ITEM_COUNT`
  30); they now check the merged ones by relation.
- **The forage suite's 30 m reach** rejected the first new bramble-edge spot (8, 41); hence (-25, 27).
- **The routes harness** at 1280x720 once refused a dig's confirm (its documented transient: a resident on the new
  entrance); the rerun passed.

## Gates

Run on the tip (0579887f and this record's docs) as `.github/workflows/tests.yml` runs them, in both conditions:

```text
./tools/run_tests.sh                                   # assets staged
8768 test(s), 592727 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 290 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

./tools/run_tests.sh                                   # as CI: assets moved aside, godot/.godot deleted, re-imported
8768 test(s), 592658 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

python3 tools/gdscript_warnings.py --max 0
0 GDScript warning(s) in 0 of 1001 file(s)

python3 tools/test_run_tests_diagnostics.py
test_run_tests_diagnostics: PASS -- expected, missing, unexpected, tolerated and leaked all classified
```

One analyzer run, started the moment the import cache was put back after the CI-mode run, reported 169 warnings in 27
files; the two runs after it, on the same tree, reported 0. The live harnesses run inside the suite at 1280x720 and
1920x1080 in both conditions, with no failing check; the orchard, care, routes, select, people, hall, chronicle, layout
and daylight harnesses were also run on their own at both sizes while wiring. Every other CI step exits 0: the
preflight self-tests, the audio staging and new art staging self-tests (`test_stage_art_passes.py` 17/17), the UI
refinement contract, `make_art_pass3.py --check-ice`, and every specification contract (decision numbers, the ledger
arithmetic, the merge gate, the dispatch graph, the Astra inbox, the registry and its table, the three cycle handoffs,
the capacity audit unregenerated, the component column schema, lane notes, the movement checks, state-registry
coverage and the validator self-tests).

Frames, each looked at, at 1920x1080 and 1280x720: `scratchpad/batch8_check/art/` (the orchard by season, the hedge
and its berries, the apple stand, the four foraging spots, the infirmary and its herb patch, the evergreens and the bare
oak in winter, the Pantry and Kitchen tab icons, the rock-faced tunnel), `batch8_check/hall/` (the timber and stone
halls by day and night, the banners, a residence and the kitchen at night) and `batch8_check/ui/` (the group tiles, the
person header, the tapestry, the chronicle).

### Master, merged after the batch, and the gates again

`origin/master` (#218 sharded CI, decision 0991; #219 demolition D6, decision 0537; #216, a review doc) merged cleanly
(eff597e3): no demo file changed on master, and the workflow keeps this branch's `test_stage_art_passes.py` step. The
gates ran again as the sharded CI runs them -- the demo's assets moved aside, `godot/.godot` deleted and re-imported:

```text
./tools/run_tests.sh --shard N/8 --output-dir <dir>      # N = 0..7, each exit 0, each 0 failures, 0 unexpected, 0 leaks
python3 tools/ci_test_shards.py verify --reports <dir> --count 8
ok: 286 suite files executed exactly once across 8 shards
tests 8925, assertions 603020, failures 0, expected 272, tolerated 353, unexpected errors 0, unexpected warnings 0,
leaked objects 0, leaked resources 0

python3 tools/test_ci_test_shards.py --godot              # Ran 17 tests ... OK
python3 tools/gdscript_warnings.py --max 0
0 GDScript warning(s) in 0 of 1008 file(s)
```

The sharding picked up this batch's new suites (`test_demo_art_wiring.gd`, `test_demo_hall_art.gd` and the orchard's
three) without any change. Every other CI step listed in `.github/workflows/tests.yml` exits 0.

## For Brendan

1. **The stone hall's roundels.** The brief said to remove the composed second chimney and roundels at tier 2; built so.
   `art_pass2_mapping.md` step 3 says "Keep the roundels and banners" (only the chimney is the model's own).
   - (a) As built: no roundels on the stone hall.
   - (b) Keep the composed roundels on it; drop only the chimney.

   Recommendation: (b), which follows the mapping, unless the model's own stonework is meant to replace them.
2. **The window glow's colour.** At 1.5 the masked windows read pale cream rather than ember at night (0.9 looks the
   same: the tint is the mask's and the tonemap's). (a) Keep. (b) Warm the emission colour in code. (c) Re-bake the
   mask's colour (`make_art_pass2.py`). Recommendation: (a) for now.
3. **The evergreens** (a PROPOSAL; the woods had none): fifteen in the woods, their trunks obstacles at art pass 2's
   proposed radii (pine 0.45 m, yew 0.9 m) and sunk its proposed 0.6 m -- values DEC-047 left open. (a) As built.
   (b) Other counts or places. (c) Not drawn until the radii and sinks are ruled. Recommendation: (a), and rule the
   radii and sinks as proposed.
4. **The bramble edge moved** (a PROPOSAL; reconciliation 8) from inside the orchard's east block to (-25, 27).
   (a) As built. (b) Elsewhere. Recommendation: (a).
5. **The group tiles go two across while portraits show** (three portraits of 40 px leave about 30 px for a name).
   (a) As built. (b) Three across, no tag line. (c) No portraits on the tiles. Recommendation: (a).
6. **Where the resident portrait lives.** The shell journal's identity row is fixed by UI-IDENTITY-R01 and its residents
   carry no cast key, so the portrait went into the demo inspector's person header. (a) As built. (b) Amend
   UI-IDENTITY-R01 for a journal slot. Recommendation: (a) for the demo.
7. **The tapestry ground's nine-patch margins.** The manifest's bottom margins (116 half, 232 full) leave the inner
   rule's rows in the centre band; the panel draws the field stretched to hide it. Recommendation: restage with 120 and
   240 (`art_pass2_ui.py`), free.
8. **The hazel's nuts** are brown as its bark, so the tree shader cannot hide them out of season (the berries it can).
   (a) Accept. (b) A bare-hazel variant (a free Blender step, as the bare oak). Recommendation: (a) for now.
9. **Wired icons waiting for items.** Pass 3's jam, pickles, dried fruit, cheese, ale and cider and 0972's flax, linen
   and wax are keyed (`item_<key>`), so an item added with that key picks its icon up. Recommendation: the preserving,
   brewing, flax and hives lanes use those keys.

## Brendan's rulings (2026-10-02)

He approved all nine recommendations:

1. **The stone hall keeps its roundels; only the composed chimney is dropped.** Built (`hall_view.gd _build_composed`:
   the roundels always, the chimney only with no stone hall staged); `test_demo_hall_art.gd` checks both, and the frames
   are in `scratchpad/batch8_check/rulings/` (`03_hall_tier2_day`, `05_hall_tier2_night`, both sizes).
2. **The cream window glow** stays for now (emission 1.5), as built.
3. **Fifteen evergreens; pine trunk 0.45 m, yew 0.9 m; sink 0.6 m**, as built. Recorded as ruled in DEC-047
   (`setting_decisions.md`), `world_sizes.gd`, `evergreens.gd` and `test_demo_world.gd`.
4. **The bramble edge stays at (-25, 27).**
5. **The group tiles go two across while portraits show**, as built.
6. **Portraits stay in the demo inspector's person header**; UI-IDENTITY-R01 is unchanged.
7. **The tapestry ground is restaged with bottom margins of 120 (half) and 240 (full).** `tools/art_pass2_ui.py`
   `TAPESTRY_PATCH` is (180, 226, 178, 240); `art_pass2_ui.py` then `stage_demo_assets.py --only art` restaged it, and the
   manifest carries the new margins. The panel's stretched field stays (it draws the same with the new margins); the
   fixture and `field_rects` test follow the new numbers. Frames: `rulings/tapestry*`, both sizes -- no seam, the
   rule inside the border.
8. **The hazel's nuts show all year** for now.
9. **Future lanes use the waiting icon keys** (`item_jam`, `item_cider`, `item_flax`, `item_linen`, `item_wax` and the
   rest): an item added with that key picks its icon up with no wiring.

## Source

The batch-8 integration brief and the coordinator's additions (2026-10-02: merge `art/flax-icons`; restage from the
shared library and verify every mapping key); Brendan's orchard rulings (0671); decisions 0501, 0901, 0902, 0941, 0951,
0971, 0972, 0981 and DEC-047, DEC-048.

## Gates on the final tip (9e31d2e5, the rulings built)

As the sharded CI runs them -- the demo's assets moved aside, `godot/.godot` deleted and re-imported:

```text
./tools/run_tests.sh --shard N/8 --output-dir <dir>      # N = 0..7, each exit 0
python3 tools/ci_test_shards.py verify --reports <dir> --count 8
ok: 286 suite files executed exactly once across 8 shards
tests 8925, assertions 603021, failures 0, expected 272, tolerated 353, unexpected errors 0, unexpected warnings 0,
leaked objects 0, leaked resources 0
python3 tools/test_ci_test_shards.py --godot              # Ran 17 tests ... OK
python3 tools/gdscript_warnings.py --max 0
0 GDScript warning(s) in 0 of 1008 file(s)
```

Every other Python step of `.github/workflows/tests.yml` exits 0.
