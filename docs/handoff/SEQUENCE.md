# Sequence — the recommended order, what runs in parallel, and where files collide

This is a recommendation, not a ruling: Brendan may reorder. It follows the dependencies in BACKLOG.md and keeps
lanes that share a hot file apart. Keep to about 15 lanes at once (STATUS §3).

## 1. Land what is in flight (wave 0)

In this order, each merging `origin/master` again and rerunning the gates before its PR (STATUS §2):

1. **Batch 8**, PR #222. Then restage art wherever you run the demo (README §3.9).
2. **The review fixes**, PR #221. Expect a `kitchen.gd` conflict with batch 8.
3. **Route planning** (`perf/route-planning`): finish and record 1005, write the four perf rulings into 1001–1004,
   merge master (20+ commits behind), resolve `kitchen.gd` against batch 8 and #221, gates, push, PR.
4. **Hauling H0–H2** (`feat/hauling-h0-h2`): merge master (with #220), recompute the memory ledger and regenerate the
   capacity audit, gates, push, PR.
5. **`fix/follow-ups`**: whatever it finished (decisions 1041–1049).
6. **Measures phase 1** (`feat/demo-measures`): either its own docs PR now (DEC-049 placed after DEC-048), or carried
   into MEAS-2.

While these land, **ask Brendan the open questions** in groups: the settlement group (Q-S1–Q-S6), Q-F1–Q-F3, and the
first demo group (Q-D1–Q-D4). Nothing in wave 1 waits on the later Q-D questions.

## 2. Waves

Within a wave the lanes are file-disjoint (§3) unless marked. Demo lanes in a wave are integrated together as one
batch (README §5; the next is batch 9, decision 0904). Settlement lanes open their own PRs.

### The settlement track (runs beside every demo wave, one lane at a time)

`settlement_system.gd` allows one writer at a time (packet §7), so this track is sequential:

```
HAUL-H3 ──(with DEMO-D8's movement part, or straight after)──> DEMO-D8
   └──> HAUL-H4 ──> HAUL-H5 ──> [D7b: resident evacuation, if Q-S3 = (a)] ──> DEMO-D7 ──> HAUL-H7 ──> HAUL-H8 ──> DEMO-D9
```

- D7 goes after H5 so the evacuation flow has real hauls, and before H7 because both write `command_dispatch.gd`.
- D9 is last: it closes REQ-SET-127/128 and `CONSTRUCTION-EVACUATION-INTEGRATION` only with everything in.
- Q-S4's saving task (if added) follows H8.

### Wave 1 — the ruled follow-ups and the measurements (demo, batch 9)

| Lane | Notes |
|---|---|
| GOALS-2 | `goals/*` only |
| HALL-FUEL | `winter/*`; needs #221 (0995's infirmary hearth row) |
| BLD-PANEL | building UI, infirmary, forage herb patch, a thumbnail tool; needs Q-D1 |
| FLAX | `farm/*`, `tunnel_stores.gd`; needs Q-D2 and Q-D3 |
| FOLLOW-UPS | what `fix/follow-ups` left; small and scattered, so check each file against the others |
| WILDLIFE | a new folder plus one `demo_village.gd` hook |
| MEASURE-BAL | tools and `docs/balance/` only; run after wave 0 has merged |

### Wave 2 — measures, alone among demo lanes

| Lane | Notes |
|---|---|
| MEAS-2 | about 75 demo files and the settlement HUD, in nine sequential slices. Run it with **no other demo lane that changes player-facing amounts**. Tools lanes may run beside it: MEASURE-SOAK. |

Running MEAS-2 after wave 1 means wave 1's new text is converted by MEAS-2 and its lint, rather than every later
lane converting its own.

### Wave 3 — features with few shared files (demo, batch 10)

| Lane | Notes |
|---|---|
| HIVES | adds a work-board source; the stores get wax; honey dishes unblock |
| PRESERVE | first lane of the **kitchen chain** (below); adds pantry items |
| SKILLS | crews and `work_pace.gd`; touches many crew files, so nothing else in a crew file this wave |
| TIME | `session/*`, the speed area |
| DIG | `tunnel/*`, `burrow/*`, `spoil/*` |
| FISHING | `fishery/*`, `water/fishing_driver.gd`, `boats/*` |
| RG-AB | farm planner suggestions, threats |
| RG-AK | `cast_routines.gd`, `bridges.gd`, the UI shell (after BLD-PANEL) |
| ZONES | `stores/*`, after BLD-PANEL |

### Wave 4 — the second ring (demo, batch 11)

| Lane | Notes |
|---|---|
| BREW | kitchen chain, after PRESERVE and HIVES |
| WEATHER | `weather/*`, `fx/*`, `work_pace.gd` (after SKILLS) |
| WATER | after FISHING and WEATHER; scope per Q-D16 |
| PATHS | the router's costs (`cast_nav.gd`, `tunnel_router.gd`) after DIG |
| RG-Y | forage and orchard remainders |
| RG-Z | forestry, gear, workshops (after SKILLS) |
| RG-AG | input and the command vocabulary; **run alone among lanes that add keys** |
| RG-AH | after BLD-PANEL |
| RG-AJ | art; may need a paid request |

### Wave 5 — what depends on the rest (demo, batch 12)

| Lane | Notes |
|---|---|
| FEAST | kitchen chain, after BREW (Harvest and Orchard themes need mead and honey) |
| DAYPLAN | meal hours and the night routine; after FEAST, or coordinated with it (Q-D11, Q-D14) |
| RG-W | kitchen chain, last (menus, cooking modes, substitutions, buffers, the flow view) |
| RG-AC | after SKILLS and DAYPLAN (or folded into them) |
| RG-AD | after DAYPLAN and FEAST |
| RG-AE | after RG-AD |
| TRADE, EXPLORE, NEIGHBOURS | only once Q-D17 and Q-D19 are answered |

### The finish line

MEASURE-BAL again (food, fuel and work have changed), MEASURE-SOAK (windowed and 25 residents), FINAL-PASS, then
WIN-PERF. The Windows build only when Brendan asks.

## 3. The file-conflict map

**Hot files** (paths on batch 8):

| File | Path | Lines | Owns |
|---|---|---|---|
| `kitchen.gd` | `godot/demo/kitchen/kitchen.gd` | 2,414 | the demo's meal loop: planning, dish choice, reservations, cooking, calling diners, eating, the meal record |
| `demo_village.gd` | `godot/demo/demo_village.gd` | 2,047 | the demo's root: composes every demo subsystem; nearly every lane adds a hook here |
| `work_ids.gd` | `godot/demo/work/work_ids.gd` | 111 | the work-board source numbers, activities, states, priorities |
| `farm_catalog.gd` | `godot/demo/farm/farm_catalog.gd` | 441 | the pantry's item and category numbers and tables |
| `settlement_system.gd` | `godot/scripts/systems/settlement_system.gd` | 4,419 | the settlement's tick and composition root |
| `jobs.gd` | `godot/scripts/core/jobs.gd` | 3,292 | the Job and JobAgent stores and selection |
| `movement.gd` | `godot/scripts/core/movement.gd` | 1,419 | ARCH-SYS-012 movement (not yet composed into the tick) |

**Who touches what.** ● certain, ○ likely, blank none expected. "src" means the packet adds a work-board source;
"item" means it adds pantry items or categories.

| Packet | `kitchen.gd` | `demo_village.gd` | `work_ids.gd` | `farm_catalog.gd` | `settlement_system.gd` | `jobs.gd` | `movement.gd` | Other hot spots |
|---|---|---|---|---|---|---|---|---|
| HAUL-H3 | | | | | ● | | ● | `navigation.gd`, `haul_planner.gd`, movement docs |
| HAUL-H4 | | | | | ● | ● | | `work.gd` |
| HAUL-H5 | | | | | ● | | | `demolition_work.gd`, `haul_planner.gd` |
| HAUL-H7 | | | | | | | | `gear.gd`, `command_dispatch.gd` |
| HAUL-H8 | | | | | ○ | | | save sections, `scripts/ui/` |
| DEMO-D7 | | | | | ○ | | | `command_dispatch.gd`, `ui_availability.gd` |
| DEMO-D8 | | | | | ● | | ● | `test_movement.gd` |
| DEMO-D9 | | | | | | | | tests and a lane note |
| MEAS-2 | ○ (text) | ○ | | | | | | ~75 demo files; `ui_manager.gd`, `hud.gd` |
| BLD-PANEL | | ● | | | | | | `infirmary/*`, `forage/forage_rules.gd`, `stores/*`, `hall/*`, the B key |
| FLAX | | ○ | | ● (design note) | | | | `farm/*`, `tunnel_stores.gd`, `gear_locker.gd` |
| GOALS-2 | | | | | | | | `goals/*` |
| HALL-FUEL | | | | | | | | `winter/hearth_fuel.gd` |
| HIVES | ○ | ● | ● src | ○ | | | | `orchard/*`, `dish_book.gd` |
| PRESERVE | ● | ● | ○ src | ● item | | | | `meal_rules.gd`, `dish_book.gd`, `farm_storage.gd` |
| BREW | ● | ● | ○ src | ● item | | | | `dish_book.gd` |
| FEAST | ● | ○ | | | | | | `regatta/*`, `goals/*`, `winter/cold_exposure.gd` |
| SKILLS | | ● | | | | | | `work/work_pace.gd`, every crew's rules |
| DAYPLAN | ○ (meal hours) | ○ | | | | | | `burrow/night_routine.gd`, `meal_rules.gd`, `session/run_until.gd` |
| WEATHER | | ○ | | | | | | `work/work_pace.gd`, `weather/*`, `fx/*`, `boats/*` |
| WILDLIFE | | ● | | | | | | `demo_prewarm.gd` |
| WATER | | ○ | | | | | | `water/*`, `waterplay/*` |
| FISHING | | | | ○ item | | | | `fishery/*`, `boats/*`, `routes/route_kinds.gd` |
| TRADE | ? | ? | ? | ? | | | | unscoped |
| PATHS | | ○ | ○ src | | | | | `cast/cast_nav.gd`, `tunnel/tunnel_router.gd`, `world/*` |
| DIG | | ○ | | | | | | `tunnel/*`, `burrow/*`, `spoil/*` |
| ZONES | | ○ | | | | | | `stores/*`, `farm_pantry.gd`, `gear_locker.gd`, `orders/*` |
| EXPLORE, NEIGHBOURS | ? | ? | ? | ? | | | | unscoped |
| TIME | | ○ | | | | | | `session/*`, `winter/season_skip.gd` |
| RG-W | ● | | | ○ | | | | `meal_rules.gd`, `dish_book.gd`, `farm_sim.gd` |
| RG-Y | | ○ | ○ src | | | | | `forage/*`, `orchard/*` |
| RG-Z | | ○ | ○ src | | | | | `forestry/*`, `fishery/gear_*` |
| RG-AB | | | | | | | | `farm/farm_planner.gd`, threats |
| RG-AC | | ○ | | | | | | crews, `people/*` |
| RG-AD | ● (serving) | ○ | | | | | | `people/*`, `infirmary/*` |
| RG-AE | ○ | ○ | | | | | | `songs/*`, `chronicle/*`, `regatta/*` |
| RG-AG | | ● | | | | | | every key binding; `camera/*`, `lenses/*` |
| RG-AH | | ○ | | | | | | the building UI |
| RG-AJ | | ○ | | | | | | art, `world/*` |
| RG-AK | | ○ | | | | | | `cast/cast_routines.gd`, `waterplay/bridges.gd`, the UI shell |
| MEASURE-BAL, MEASURE-SOAK | | | | | | | | `tools/`, `docs/balance/`, `docs/performance/` |
| FOLLOW-UPS | | ○ | | | | | | scattered |

**Rules that follow from the map.**

- **The kitchen chain** is sequential: PRESERVE → BREW → FEAST → RG-W, with RG-AD's serving windows and DAYPLAN's meal
  hours coordinated with FEAST. Never two of these in flight at once.
- **`settlement_system.gd`, `jobs.gd`, `movement.gd`** belong to the settlement track only, one lane at a time.
- **`command_dispatch.gd`**: DEMO-D7 and HAUL-H7 never together.
- **`work_pace.gd`**: SKILLS before WEATHER.
- **`demo_village.gd`** is touched by nearly everyone, always as a narrow hook. Those conflicts are mechanical
  (keep both sides); the integrator resolves them. Keep each lane's hook to a few lines.
- **Keys**: RG-AG changes the binding scheme; run it when no other lane adds keys. BLD-PANEL settles B (Q-D1).

### Numbering in `work_ids.gd` (work-board sources)

At batch 8: `SOURCE_FARM` 0, `WOODS` 1, `BRIDGES` 2, `TUNNELS` 3, `FIT_OUT` 4, `SPOIL` 5, `KITCHEN` 6 (listed, never
claimed), `FISHERY` 7, `FERRY` 8, `STORES` 9, `HALL` 10, `CARE` 11, `FORAGE` 12, `ORCHARD` 13; **`SOURCE_COUNT` 14
and `SOURCE_WALK` 14** (WALK always equals COUNT: a queued walk, never a board task). `SOURCE_NAMES` has 14 entries.

- A lane takes the next number on its own branch (14 today) and **expects the integrator to renumber**: every batch so
  far has renumbered colliding sources (0902, 0903). Only `work_ids.gd` writes the numbers; everything else uses the
  constant.
- To add one: the constant; `SOURCE_COUNT` and `SOURCE_WALK` + 1; a name in `SOURCE_NAMES`; an adapter extending
  `godot/demo/work/work_source.gd` (pattern: `orchard_work.gd`, `forage_work.gd`) registered with `board.add_source(...)`
  in `godot/demo/work/demo_work.gd`. Arrays sized by `SOURCE_COUNT` follow by themselves (`work_board.gd`,
  `work_screen.gd`, `people_taps.gd`, `demo_people.gd`, `demo_songs.gd`, `godot/tools/balance/balance_labour.gd`).
- Tests to change: `test_demo_orchard_ui.gd` asserts `SOURCE_COUNT == 14` literally; the WALK == COUNT relation checks
  in `test_demo_fishery.gd`, `test_demo_ferry.gd`, `test_demo_forage.gd`, `test_demo_cellar.gd`,
  `test_demo_infirmary_building.gd`, `test_demo_orchard_ui.gd`. Prefer relation checks in new tests.
- Unrelated constants with similar names: `demo_notices.gd SOURCE_NAMES`, `presentation_extract.gd SOURCE_COUNT`,
  `needs.gd PURPOSE_SOURCE_COUNT`, the fishing and forage `*_CLAIM_SOURCE_COUNT` codes.
- Likely new sources, in the recommended landing order: HIVES (hive service), PRESERVE (a dryer or preserver), BREW
  (the brewery), PATHS (path building), RG-Y, RG-Z. Each lands as 14, then 15, … in batch order.

### Numbering in `farm_catalog.gd` (pantry items)

At batch 8: crops 0–15 (`ITEM_COUNT` 16); catch 16–21 (`FIRST_CATCH` 16, `CATCH_COUNT` 6); `ITEM_DRIED_FISH` 22,
`ITEM_FLOUR` 23, `ITEM_POTATO` 24, `ITEM_HONEY` 25; forage 26–29 (`NUTS`, `MUSHROOMS`, `HERB`, `BERRIES`); fruit 30–31
(`APPLE`, `PEAR`); **`PANTRY_ITEM_COUNT` 32**. Categories: 0–4 the GDD's crop rows (beans, cabbage, flax, grain,
roots), then `CAT_FISH` 5 … `CAT_HERB` 11, `CAT_BERRIES` 12, **`CAT_FRUIT` 13**. (The tracker's "CAT_BERRIES 11" is
out of date.)

- **Append only.** A new item goes at the end (32 today). Inserting a crop into 0–15 shifts every later id.
- To add one: append to `ITEM_KEYS`, `ITEM_LABELS`, `ITEM_PROP`, `ITEM_SWATCH`, `GOODS_CATEGORY` and
  `GOODS_SHELF_HOURS` (the last two indexed `item - 16`); bump `PANTRY_ITEM_COUNT`; add `ITEM_*` and, if needed,
  `CAT_*`; in `godot/demo/kitchen/meal_rules.gd`, a word in `CATEGORY_WORDS` and, if raw-edible, a `RAW_NP_PER_U` entry;
  the field guide entry (`godot/demo/guide/field_guide.gd`); add the key to `tools/make_demo_pantry_index.py` and
  regenerate `godot/demo/farm/pantry_index.json`. `ingredient_takes.gd MASK_BITS` (62) caps the item count.
- The icon needs no wiring: `item_<key>` is picked up by key (0903 ruling 9). Use the waiting keys: `jam`, `pickles`,
  `dried_fruit`, `cheese`, `ale`, `cider`, `flax`, `linen`, `wax` (and their alternates in 0972).
- Materials (flax, rope, cloth, wax, iron) belong in the village stores (`tunnel_stores.gd`), not the pantry.
- Likely new items: PRESERVE (dried fruit, rations), BREW (mead), later jam, pickles and the rest if Q-D5 allows.

## 4. Key bindings (for any lane that adds a key)

There is no single registry. Three places:

1. **`godot/project.godot [input]`** (UI §5 actions, pinned by `godot/test/test_input_map.gd`): WASD and arrows pan;
   Q/E rotate; PgUp/PgDn and the wheel zoom; Alt+PgUp/PgDn pitch; Enter, Shift+Enter, Ctrl+Enter select; Shift+arrows
   box; Esc clears selection and opens the menu; Tab/Shift+Tab cycle; Ctrl+0–9 assign groups, 0–9 recall; C context,
   X cancel; Space and Ctrl+Space pause; F1/F2/F3 speeds; B build, Z zones, H harvest, J jobs, K food, L residents,
   F feast, O objectives, N history, T calendar, M minimap; Home/End camera home and follow; F4 roofs; R and Shift+R
   rotate placement; [ and ] brush size, Alt+Enter brush erase; Delete demolish; P pin a resident; F6 world list;
   F5/F9 quick save and load; Ctrl+Tab/Ctrl+Shift+Tab tabs; Ctrl/Cmd+Z undo; Ctrl/Cmd+A select all.
2. **Raw demo keys**, each in its owner file: F11 full screen (`demo_window_keys.gd`); F7 focus switch
   (`ui/demo_input_gate.gd`); F8 Demo Lab (`ui/demo_lab.gd`); F12 playtest mark (`playtest/playtest_log.gd`); G
   Run until (`ui/demo_run_menu.gd`); V map layer and K pantry (`farm/demo_farm.gd`); T planner (`farm/farm_planner.gd`,
   shared with the calendar); R release a selection (`control/demo_command.gd`; also the room tool); Shift+O orbit,
   Shift+U cutaway, Shift+1–4 and Ctrl+Shift+1–4 bookmarks (`camera/camera_modes.gd`); B, U, H, C, L, Backspace,
   Enter, PgUp, PgDn in the Dig tool and Underground view (`tunnel/tunnel_control.gd`); C clears a spoil heap
   (`spoil/demo_spoil.gd`); Esc cancels placement tools.
3. **The player's table**: `godot/demo/README.md`, "Commanding the residents" and "The camera's modes".

**Free, as far as checked:** the plain letters I and Y; F10; punctuation (`- = ; ' , . / \` and the backquote); most
Shift+ and Alt+ letter combinations (only Shift+O, Shift+U and Shift+R are used). Whether the demo handles every UI §5
map action (F, N, M, P, Z, X) is unverified: treat them as reserved. Tests: `test_input_map.gd`,
`test_demo_input_gate.gd`, `test_demo_input_live.gd`, `test/live/demo_input_live.gd`.
