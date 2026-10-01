# 0601 — The kitchen's recipe book, each species' favourites, and the cook's choice
Date: 2026-10-01 · Status: Accepted (its PROPOSALS await Brendan's ruling)

Feature 16, approved by Brendan on 2026-10-01: more Redwall dishes, with each species' favourites. Extends decisions
0381 (the meal loop, ruling 1's alternation) and 0436 (the fish stew). Numbered in this lane's 0601–0609 range; 0602 is
the Recipes tab's index.

## Decision

### 1. The recipe book is data, and adding a recipe is adding a row

`godot/demo/kitchen/dish_book.gd` holds one row per dish: key, names, library id, the GDD §5.7 row it is cooked as, its
meal, §5.7's portions, NP, WU, shelf and water, and its inputs as `[category, milli-U, items]`. `meal_rules.gd` builds
every column from it once, at load (`_static_init`); the kitchen, the planner, the pantry, the guide and the HUD read
those columns. Inputs are a list -- any number, not the old "input and a second input" -- so the feast and preserving
lanes can add `feast_fish` (three inputs) or `ration` (four) as rows. `items` narrows a §5.7 category to the library
dish's own ingredients; ingredient_takes.gd's reservations take a SELECTOR (a category, or a mask of items), so a dish
reserves, fetches and withdraws only what it is made of. Rows 0–2 keep their indices.

### 2. The dishes: library candidates cooked as §5.7 rows, from what the demo grows and catches

LIB-008 keeps a library recipe inactive until an owning specification gives its numbers; §5.7 is that specification,
so -- as 0381 and 0436 did -- each new dish is a production-candidate library recipe COOKED AS a §5.7 row, carrying the
row's numbers exactly, and only from food the demo has (the sixteen crops, the six fish, flour, dried fish; there is no
foraging, honey, fruit, nuts, mushrooms, herbs, salt or dairy in the demo):

| Dish | Library recipe (occurrence) | §5.7 row | Takes |
|---|---|---|---|
| Barleymeal porridge | `pearls_lutra::PL_RECIPE_barleymeal_porridge` (SERVED) | `porridge` | barley or oats |
| Wild-beetroot soup | `triss::TRI_recipe_wild_beetroot_soup` (Roobee's soup) | `root_stew` | beetroot or onion |
| Vole vegetable stew | `taggerung::TAG_recipe_vole_vegetable_stew` | `root_stew` | carrot, onion or turnip |
| Poached dace | `taggerung::TAG_recipe_poached_dace` (source names dace) | `fish_stew` | dace + any roots |
| Bean hotpot | none: the GDD's own `meal_bean_hotpot` | `bean_hotpot` | beans (pea, broad bean) + greens |

Numbers: porridge grain 2 + water 2 → 2 × 1800 NP, 12 WU, 24 h; root_stew roots 3 + water 1 → 2 × 1800, 16 WU, 24 h;
fish_stew fish 2 + roots 2 + water 2 → 3 × 2200, 20 WU, 24 h; bean_hotpot beans 2 + cabbage 2 + water 2 → 3 × 2100,
20 WU, **36 h**; every batch 0.1 U of wood (BAL-SUPPLY-004; the fuel code is not touched). §5.7's `cabbage` input is
the demo's cabbage row (cabbage, lettuce, spinach, leek, celery), shown as "greens". The fish-stew rows' roots are §5.7's
second input, which the library's poached fish do not name (as 0436). Eight dishes in all.

**Rejected, and why** (searched: every production candidate whose ingredients resolve to the demo's food, and those one
or two ingredients short):

- **Pies, pasties, turnovers** (deeper'n'ever pie, leek pasty, vegetable pasty, feast pasties, celery and leek
  turnovers, Dotti's pie, hare-song pasties): §5.7's only pie, `woodland_pie`, needs mushrooms; the library's pastry
  needs hazelnut or sunflower oil and salt; the deeper'n'ever pie needs potato. No row cooks them from the demo's food.
- **Scones, oatcakes, farls, hardtack, skilly and duff**: no §5.7 baked-goods row; inventing one would invent numbers
  (0434 rejected the same for flour).
- **Salads** (spring, summer, cave household, frame picnic): no §5.7 salad row; raw greens are emergency food only.
- **Cordials and drinks** (oatmeal water, oat and barley water, greensap milk): no §5.7 drink row; `mead` needs honey,
  and the Hearth infusion is a feast beverage with no stored output.
- **Greens-only and mixed soups** (leek-celery, young onion and leek, celery-carrot, spring vegetable with leek,
  Migooch, Lupinia's stew, leaf-wrapped vegetables, Drufo's grain and root soup, autumn harvest soup, Grandma's
  hard-baked stew, Guosim camp stew): their ingredients span the cabbage row and roots, or grain and roots -- no
  single §5.7 row has those inputs.
- **Fish alone** (baked, grilled, roasted, camp dace, willow-roasted whitefish): §5.7 cooks fish only as `fish_stew`
  (with roots, as chosen) or `feast_fish` (needs herb).
- **Joke, captive and cruelty contexts**: bad-cook porridge and stew (jokes), turnip stew (Bladd's joking
  proposal), captives' grain porridge, Poskra's soup (a cruel water rat), stewed dace (source eels).
- **Pea and celery soup, carrot-turnip-pea-and-leek stew, leek and bean soup**: need salt or thyme, and mix roots
  with beans and greens -- not `bean_hotpot`'s inputs. Hence the hotpot is the GDD's own dish, with no library name.
- **Shrimp and hotroot soup** (the otters'): shrimp is not a game fish and hotroot is fictional.

### 3. Each species' favourites: data and display only

`dish_favourites.gd`: per species, liked and disliked dishes, each LIBRARY or PROPOSAL. The GDD defines no
favourite-food effect and feature 17 (variety and favourites mood) is not approved, so a favourite changes **no NP,
mood, need or memory**. It is noted on the resident's card ("Last meal: supper, beetroot soup — a favourite") and
counted (`nourishment.gd favourites_eaten`), shown as "(liked by N)" in the Kitchen tab's plan and as "A favourite of
moles and badgers." in the field guide -- and weighed in the cook's choice (4).

### 4. The cook's choice, deterministic

Of the meal's dishes whose free food makes at least a batch: (1) one whose food feeds the whole meal (every portion it
wants) -- so a favourite made from a little beetroot never leaves the village short while the carrots would feed it;
(2) the food that keeps least long (§5.7 shelf hours of its inputs' categories: fresh fish 48, greens 144, roots 240,
grain 720) -- 0436's "fresh fish while it is fresh", for every dish; (3) the village's taste, likes less dislikes of
every resident (everyone is called to every meal); (4) the book's order, so the meal's plain dish wins a tie.

**This narrows 0436**: a fresh-fish stew that would feed only part of the meal (2 U of fish is 3 portions) now yields
to a dish that feeds everyone; the fish is cooked when there is enough of it, or when nothing feeds the whole meal.
Measured in the first capture: 8 U of dace planned a full breakfast of poached dace, then a supper of one batch for
nine -- a short meal while 8 U of carrots and beetroot sat in store. With none of its meal's, the other meal's best (ruling 1's "other
dish"); with none, the meal's plain dish, waiting. A meal is re-chosen only while it holds no food.

### 5. Variety counts §5.7 recipes

`repeats_of` counts the last six meals by §5.7 row: "Ingredient differences inside the same recipe do not fake
variety". The monotony line names the recipe ("root stew 3 of last 6"). Still a readout: no mood.

### 6. The ready-food estimate

The HUD's Ready food counts the plain dishes (every input a whole category) by category -- dishes of several inputs
first (the stew's roots before the soup's), then the rest in the book's order; the wood bounds it. A variant cooks the
same numbers, so it is never counted twice. Under a wood limit the multi-input dishes now come first (was porridge
first): a difference of a portion or two only when wood is short.

## PROPOSALS needing Brendan's ruling

1. **The favourites table** (`dish_favourites.gd`). Only "moles like Togget's vegetable soup" rests on the library
   (Togget is a mole, `outcast::OUT_character_togget`). The rest are proposals: moles and badgers the beetroot soup
   (the mole deeper'n'ever pie's beetroot; a badger enjoying hotroot soup's red roots), squirrels the barleymeal and
   the vole stew (Drufo's grain-and-root soup), otters the poached dace (the books' fishers), mice the hotpot (no
   basis), the beaver the hotpot and disliking both fish stews (a plant-eater; DEC-041). Options: keep; replace with
   per-resident tastes in `demo_people.json`; mice with none. Recommendation: keep, and give mice an authored
   favourite when the people pass next touches food.
2. **The choice's order**: feeding everyone, then freshness, then taste. Options: freshness first (0436's literal
   rule: a short fish stew whenever there is a batch of fish -- people go without while roots sit in store); taste
   before freshness (a disliked fish stew would wait while the fish spoils). Recommendation: as built -- a full meal
   first, then waste avoidance (§5.7's own override for expiring food), then taste.
3. **Variety in the choice**: the cook does not rotate dishes; the same favourite repeats while its food lasts.
   Rotation belongs with feature 17. Recommendation: leave it to 17.
4. **The hotpot's M1 unlock is not evaluated**: the demo runs no milestones (as the fishing driver's M1–M3 gear).
   Options: cook it from the start (built); hold it until a demo milestone exists. Recommendation: from the start.
5. **Dishes rejected for want of a §5.7 row** (pies, pasties, scones, salads, cordials): adding them needs authored
   rows in the GDD/balance documents first. Recommendation: author `oatcake` and `salad` rows if Brendan wants them;
   the demo can then add them as dish-book rows.

## Why

Every number is §5.7's; nothing is invented that a document does not state. Data-driven rows let the next lanes add
recipes without touching the kitchen's logic. Selectors make "a beetroot soup" mean beetroot.

## Consequences

`meal_rules.gd`'s INPUT_CROP/INPUT_MILLI/SIDE_CROP/SIDE_MILLI stay as views of the first two inputs for older readers;
new code reads `INPUT_N` and `input_selector/category/milli`. A dish's inputs may not share an item
(`test_demo_dishes.gd` checks the book). The field guide's dish ids are built from the book (`dish_<key>`).

## Verification

- Suite: `ok: 7538 tests, 568402 assertions, 0 failures.` New suite `godot/test/test_demo_dishes.gd` (23 tests) and
  `tools/test_make_demo_pantry_index.py` (4).
- Live harnesses at 1280x720 and 1920x1080: layout, guide, people, planner, input and session all pass (session at
  1080p passed on its rerun; its first run hit the demo's CPU-stall pause under machine load).
- Mutation testing of the new logic: 50 mutants, 49 killed. The survivor removes the "plain dishes only" filter from the
  ready-food estimate; the estimate is then wrong only when a variant comes before its plain dish in the book's order,
  which no current row does (each plain dish's index is lower and takes a superset of the variant's food).
- GDScript analyzer (language server): no warning on any line this change adds.

## Source

GDD §5.7 (the recipe table, the food table, variety, REQ-SET-090/094/109), §5.8; balance §3.2 (`bean_hotpot`
`beans:2000;cabbage:2000;water:2000`, unlock 1); BAL-SUPPLY-004; CONTENT-LIB-001 (LIB-002/003/008, §4); the library's
recipes, catalog and pantry; decisions 0381, 0434, 0436; DEC-041; LORE-P12 (a taste is no job lock or multiplier).
