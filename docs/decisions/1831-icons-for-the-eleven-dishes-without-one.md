# 1831 — Icons for the eleven dishes without one
Date: 2026-10-09 · Status: Accepted (Brendan's approval of the two sheets; visual acceptance is still his, through
`tools/art_gate.py`)

A follow-up to the item-icon passes ([decision 0971](0971-art-pass-3-preserving-brewing-digging-and-free-effects.md) and
[decision 0972](0972-flax-linen-and-beeswax-icons.md)), made by 0972's method.

## Decision

On 2026-10-09 Brendan approved icons for the eleven dishes that had none, in his words **"Two sheets"**. The
coordinator delegated the calls under
[decision 0961](0961-paid-generation-is-by-request-and-may-be-delegated-within-an-approved-cap.md), with a **hard cap
of 20 credits** covering everything, any retry included.

The dishes are `dish_book.gd`'s rows whose `dish_<key>` icon (`meal_rules.gd` DISH_ICON_KEYS) was not staged. The
Pantry's kitchen stock rows drew no icon for them, and the Kitchen tab's row of meal icons left them out
(`DemoProps.staged_icon` is null without one):
- the feasts' four courses (decision 1701 P8 (b), ART-NEXT in `docs/handoff/BACKLOG.md`);
- the seven older breakfasts and suppers, which pass 1 (decision 0941) never drew.

## The plan

- **Two calls:** `nano-banana-2` image-to-image 3×3 sheets, each conditioned on pass 1's
  `assets/library/icon/sheet_foods_a/sheet.png` alone, as 0971's and 0972's were: **6 credits each, 12 in all.**
- **One retry of one sheet** (6 more, 18 in all) is allowed only if a cell is wrong: an animal in the vole stew, a dish
  that does not read, or a cell off the reference's style.
- **The prompts** keep 0972's structure: the style sentence, the grid sentence, the cells row by row, then the
  background sentence. The model's prompt limit is 600 characters, so each cell is a short phrase.
- **The seven spare cells hold plain empty vessels**, which are not dishes and get no key. They are neutral filler, so
  the model draws a full 3×3 grid with the same spacing, which the cutter needs.
- **Dishes that share a gdd row are told apart by vessel and colour.** The two porridges are a creamy oat porridge in a
  wooden bowl and a coarse golden barley porridge in a clay bowl. The two soups and the stew are a clear vegetable
  soup, a deep red beetroot soup and a thick stew in an iron pot. The two poached fish are a trout fillet in a deep
  bowl of broth and two whole dace in a shallow pan.
- **The vole stew is a vegetable stew** (`dish_book.gd`: carrot, onion and turnip only). DEC-006 sets a plant, fish
  and seafood boundary, so its row is prompted "vegetables only, no meat" and its cell names only the three roots. It
  must show no animal, and the prompt never says "vole".
- **The nut roast is plant-based** (SET-AMEND-001): beans, roots and nuts, drawn as a sliced loaf with hazelnuts on
  top.

| Sheet (library key) | Cell (col,row) | Icon key | Dish |
|---|---|---|---|
| `sheet_dishes_feasts_breakfasts` | 0,0 | `dish_feast_fish` | Feast fish: a whole fish on an oval platter with roast roots and herbs |
| | 1,0 | `dish_berry_tart` | Feast tarts: three small honey-glazed berry tarts |
| | 2,0 | `dish_nut_roast` | Nut roast: a sliced bean, root and nut loaf |
| | 0,1 | `dish_orchard_crumble` | Orchard crumble: apple and pear crumble in a clay dish |
| | 1,1 | `dish_porridge` | Wild oat porridge: a wooden bowl |
| | 2,1 | `dish_barleymeal` | Barleymeal porridge: a clay bowl, coarse and golden |
| | 0,2 · 1,2 · 2,2 | (none) | Empty wooden bowl, clay dish, wooden spoon |
| `sheet_dishes_suppers` | 0,0 | `dish_soup` | Togget's vegetable soup: carrot, turnip and herbs |
| | 1,0 | `dish_beetroot_soup` | Wild-beetroot soup: deep red, with onion |
| | 2,0 | `dish_vole_stew` | Vole vegetable stew: carrot, onion and turnip in an iron pot |
| | 0,1 | `dish_fish_stew` | Poached perch or trout: a trout fillet in broth with carrots |
| | 1,1 | `dish_poached_dace` | Poached dace: two whole dace in a shallow pan with sliced roots |
| | 2,1 · 0,2 · 1,2 · 2,2 | (none) | Empty wooden bowl, clay pot, wooden ladle, pewter plate |

The exact prompts are in `docs/art-reference/asset_library/concept_prompts.json`, under each sheet's key.

## The cut

`python3 tools/make_art_pass3.py --icons` cuts the two sheets with the same cutter as 0971's and 0972's nine (pass 1's
flood fill, 128 px transparent icons, a 4 px margin) into `godot/demo/assets/icons/<key>.png`. Their rows go in
`godot/demo/assets/art_pass3_icons.json`, marked decision 1831, and `tools/stage_art_passes.py` writes them into the
manifest's `icons` section. `DemoProps.has_icon(&"dish_...")` is then true for all eleven. When the art is not staged, as in CI, the panels draw
no icon, as before.

## What was made

**Two calls, 12 credits, no retry.** The balance was checked before and after each call: 98, then 92 after the first
sheet, then 86 after the second. 8 credits of the cap are unspent.

| Sheet | Task | Credits | Library file (sha256) |
|---|---|---|---|
| `sheet_dishes_feasts_breakfasts` | `01a121b3-a6d1-736d-a23c-8d5b0b8008c4` | 6 | `assets/library/icon/sheet_dishes_feasts_breakfasts/sheet.png` (`d13e1626…`) |
| `sheet_dishes_suppers` | `01a121b4-1c00-7232-9bb7-94c58cdd265e` | 6 | `assets/library/icon/sheet_dishes_suppers/sheet.png` (`8137ef4a…`) |

Both are `nano-banana-2` image-to-image, 1024 px, with one reference image, `assets/library/icon/sheet_foods_a/sheet.png`.
They were on the reference's style first time, so no retry was spent. Each cell was checked by eye, the stew zoomed:
- **The vole stew shows no animal.** Its iron pot holds carrot rounds, turnip cubes, onion slices and a few small pale
  beans or grains in a brown gravy. There is no meat or bone in it.
- **Two deviations were accepted rather than spending the retry**, because neither breaks a rule or reads wrong at
  icon size:
  - The poached perch or trout is a pink, salmon-like steak. Trout flesh is pink, and the dish is still fish.
  - The vegetable soup has a metal spoon in it, which stays inside its cell and is cut with it.
- **The two porridges are told apart at 32 px**: pale oat in a dark wooden bowl, gold barley in a clay bowl.
- **The nut roast is close to pass 1's nutbread** (`dish_nut_loaf`): both are sliced brown loaves. The roast is darker,
  studded with whole hazelnuts and drawn without a board.
- **The spare cells drew as asked**: an empty bowl, dish, spoon, pot, ladle and plate. They are not cut.

## The staging change

`tools/stage_art_passes.py` ran `make_art_pass3.py --icons` only when the icon record was missing. A checkout staged
before this decision therefore kept a record without the eleven, and a restage would not have cut them. Now:
- **The icon record is remade when it lacks a key the library can supply,** or cannot be read. Cutting needs Pillow
  and the library, not Blender.
- **A key whose sheet the library lacks is skipped, not fatal.** `make_icons` names it, cuts the rest and writes the
  record; it fails only when it can cut nothing. Staleness asks only for keys whose sheet is in the library. A library
  mirror without these two sheets therefore stages as before, with the eleven left to the panels' stand-ins, and is
  not recut on every restage. The code reviewer found this case (MEDIUM 1): before the fix, such a mirror failed
  every restage.
- **`tools/test_stage_art_passes.py` tests it:**
  - N04 tests the staleness rule, including a partial library and no library.
  - N05 tests that `run_tools` recuts a stale record and runs nothing for a complete one, with the tool calls recorded
    rather than run.
  - It checks that every `dish_book.gd` row has a `dish_<key>` icon a cutter cuts, the eleven on their cells.
  - It checks that each sheet keeps its decision.
  - Mutating the staleness wiring, the decision map or the partial-library filter fails it.

## Seen in the game

A scratch harness, kept outside the repository as 0971 allows, booted the real village at 1280x720 and 1920x1080. It
put two portions of each of the eleven dishes in the pot, and checked `has_icon` and `staged_icon` for all eleven,
which passed.
- **The Pantry's Stocks tab** draws each dish's icon on its kitchen row; all eleven were seen across two scroll
  positions.
- **The Kitchen tab** draws the first eight (its `MEAL_ICONS` pool) in its row of meal icons.
- **The field guide draws no icons at all.** Its dish entries are text: `field_guide_page.gd` adds no image. ART-NEXT's
  "the guide" was wrong about this, and no art can change it. Giving the guide's entries icons would be a separate,
  UI-text change, which this lane was told not to touch.

The frames are in the session scratchpad's `art6_frames/`, and the review sheets at native size and 32 px on dark and
light grounds are in `art6_check/`.

## What this does not do

- **It accepts no art.** The icons are candidates. Visual acceptance stays with Brendan, through `tools/art_gate.py`,
  as in decisions 0188, 0941, 0971 and 0972. `docs/planning/art_approvals.json` is his to edit and was not touched.
  As before, the paid approval was given in the session, through the coordinator, and is recorded here.
- **It wires nothing new.** The keys are the ones `meal_rules.gd` already builds, so no game code changed.
- **It commits no binaries.** The sheets live in the gitignored library, and the icons in the gitignored
  `godot/demo/assets/` (decision 0188).

## Restaging

On a checkout whose library holds the two sheets, run `python3 tools/stage_demo_assets.py --only art` or
`python3 tools/stage_art_passes.py`. Either recuts the icon record, because it lacks the eleven keys.

## Source

Brendan's approval ("Two sheets"), relayed by the coordinator on 2026-10-09. The ledger rows carry "decision 1831":
- `docs/art-reference/asset_library/meshy_tasks.jsonl`, the two tasks with their credits;
- `concept_prompts.json`, the exact prompts and the reference image;
- `files.json`, the two sheets' sizes and hashes;
- `docs/art-reference/asset_library/README.md` and `docs/art-reference/art_pass3_mapping.md`, the keys and cells.
