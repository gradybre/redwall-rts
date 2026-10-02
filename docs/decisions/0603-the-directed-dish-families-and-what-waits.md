# 0603 — The dish families Brendan directed, the tuning dishes, and what waits for an ingredient
Date: 2026-10-01 · Status: Accepted (the drafted rows await Brendan's confirmation: DEC-045)

Feature 16, phase 2. Brendan, on decision 0601's P5 (2026-10-01): **"Approve, but add in everything for 5 now."** The
families 0601 rejected for want of a GDD §5.7 row -- pies, pasties and turnovers, scones, oatcakes, farls and hardtack,
salads, cordials -- are added, each with a recipe written in §5.7's format. He also approved three balance-tuning
experiments for this lane (the balance baseline, `tools/balance-sim`, `docs/balance/2026-10-01-first-year-baseline.md`):
**E2** a fish dish needing no roots, **E3** dried fish and flour as kitchen inputs, **E4** a cabbage-and-bean pottage if
the gap remains. Setting record: DEC-045 in `docs/setting_decisions.md`. Numbered 0603 because 0602 (the Recipes tab's
index) was already taken in this lane's 0601–0609 range.

## Decision

### 1. The rows (DRAFTS for Brendan to confirm or retune)

Each row is GDD §5.7's format, station Kitchen/COOK, every batch burning §5.8's 0.1 U of wood ("Kitchen production
consumes wood 0.1 U/batch" -- a salad too: the rule names no exception). Numbers are drafted inside the adopted rows'
range (inputs 2–6 U, 2–4 portions, 1800–2600 NP a portion, 12–32 WU, 24–72 h shelf; preserved food longer), with NP
about 1.5 times the inputs' raw NP as porridge's is (2 U of grain, 2400 raw → 3600):

| Row (new) | Dish (library recipe) | Inputs (U) | Water | Out | WU | Shelf h | Meal | Now |
|---|---|---|---:|---|---:|---:|---|---|
| `oatcake` | Breakfast oatcake (`rakkety_tam::RAK_recipe_breakfast_oatcake`, SERVED) | oats 2 | 1 | 2 × 1800 | 14 | 72 | breakfast | cookable |
| `farl` | Barley farl (`taggerung::TAG_recipe_barley_farl`) | barley 2 | 1 | 2 × 1800 | 14 | 48 | breakfast | cookable |
| `hardtack` | Haversack hardtack (`rakkety_tam::RAK_recipe_haversack_hardtack`, RECOLLECTION) | flour 2 | 0.5 | 2 × 1800 | 16 | 480 | breakfast | cookable (E3) |
| `salad` | Spring salad (`outcast::OUT_recipe_spring_salad`, SERVED) | greens 2, roots 1 | 0.5 | 2 × 1400 | 6 | 12 | supper | cookable |
| `baked_fish` | Baked fish (`mossflower::MF_recipe_baked_fish`, CONSUMED) | fresh fish 2 | 0.5 | 2 × 1900 | 14 | 24 | supper | cookable (E2) |
| `fish_biscuit_soup` | Durral's dried-fish biscuit soup (`pearls_lutra::PL_RECIPE_durral_s_dried_fish_biscuit_soup`, SERVED) | dried fish 1, flour 1, roots 1 | 2 | 3 × 2000 | 20 | 24 | supper | cookable (E3) |
| `pasty` | Vegetable pasty (`salamandastron::SAL_recipe_vegetable_pasty`, SERVED) | flour 2, roots 1, greens 1, hazelnut 0.5 | 0.5 | 3 × 2200 | 24 | 48 | supper | waits: hazelnut |
| `root_pie` | Turnip, potato and beetroot pie (`martin_warrior::MW_RECIPE_turnip_potato_and_beetroot_pie`; the moles' deeper'n'ever pie) | flour 2, turnip or beetroot 2, potato 1, hazelnut 0.5 | 0.5 | 4 × 2300 | 32 | 48 | supper | waits: potato, hazelnut |
| `scones` | Hazelnut scones (`martin_warrior::MW_RECIPE_hazelnut_scones`) | flour 2, hazelnut 0.5 | 1 | 3 × 1800 | 20 | 48 | breakfast | waits: hazelnut |
| `cordial` | Raspberry cordial (`lord_brocktree::LB-RECIPE-raspberry-cordial`, SERVED) | raspberry 2, honey 0.5 | 2 | 4 × 500 | 10 | 72 | a drink | waits: raspberry, honey |

And §5.7's own **`woodland_pie`** (flour 2, mushrooms 2, roots 1, water 1 → 3 × 2300, 30 WU, 48 h; M2 not evaluated),
the GDD's dish with no library name -- waits for mushrooms. Nineteen dishes in all.

**Library ingredients the rows leave out** (each a seasoning or leaven a §5.7 row does not list, as porridge lists no
salt): the pasty's and hardtack's salt, the scones' yeast, the oatcake's and farl's salt. **The pastry fat** is the
library's own hazelnut oil, taken as hazelnut (§5.7's nuts) -- the pasty, the root pie and the scones wait for it.

**The cordial is a drink** (`dish_book.gd` DRINK): never chosen for breakfast or supper; listed with its recipe for the
feasts lane, whose beverages these are.

### 2. E2, E3, E4

- **E2**: Baked fish (above) -- fresh fish, no roots. With fish and no roots the cook bakes it rather than letting it rot
  (the choice's freshness rule puts fish first); with roots, the stew (3 portions a batch) still feeds more.
- **E3**: flour is the hardtack's, the pasty's, the pies' and the scones' base; dried fish and flour together are
  Durral's biscuit soup, which feeds a meal from 1 U of roots where the soup needs 3. Flour (240 h) keeps less long
  than grain (720 h), so the cook bakes hardtack before porridge when the flour feeds breakfast.
- **E4: not added.** Decision 0601's **bean hotpot** is §5.7's `bean_hotpot` -- beans 2 + cabbage 2 -- and cabbage is
  the greens category, so the gap the baseline measured (it ran before 0601) is the hotpot's; the salad also cooks
  greens. A second pottage would be a variant of the same recipe.

### 3. What waits, and where it will come from

A dish whose ingredient the demo cannot produce is **listed, never hidden**: the Recipes tab marks it "Waiting (needs
hazelnut: gathered by foragers)", the Kitchen tab lists "Waiting for ingredients", the field guide's entry says
"Waiting: ...". The pantry items:

| Ingredient | Pantry item | Source lane | Dishes waiting |
|---|---|---|---|
| hazelnut | **not defined here** -- the foraging lane owns nuts; named by key `hazelnut` (LEAF_hazelnut) | foraging (#22) | pasty, root pie, scones |
| mushroom | **not defined here** -- foraging's; key `mushroom` (LEAF_mushroom) | foraging (#22) | woodland pie |
| raspberry | **not defined here** -- berries are forage (§5.5); key `raspberry` (LEAF_raspberry) | foraging (#22) | cordial |
| potato | defined: `potato` (LEAF_potato), §5.6 roots row, 240 h | crops (lane X) | root pie |
| honey | defined: `honey` (LEAF_honey), CAT_HONEY, §5.7 1200 NP raw, 1440 h | hives (no lane yet; §5.6 hives) | cordial |

An input of category NEEDS names items another lane defines; it resolves to their category when the item exists (no
code change). `dish_book.gd PENDING_SOURCES` says where each comes from; **the lane that lands a source deletes its key
there**. Salt, oil and fruit are not needed by these rows.

### 4. Built to survive the source lanes landing

- **The cook never picks a drink or a waiting dish** (`meal_rules.gd serves`): the "Waiting" label is the cook's rule,
  so a source that arrives while its key is still in PENDING_SOURCES is not cooked under a "Waiting" label.
- **A NEEDS key must be an item or a pending one**; a misspelt key is an error, and a test checks the book.
- **The ready-food pool counts the catalog's categories** (`Rules.CATEGORY_COUNT`), so a lane adding a nuts category
  is pooled, never written past.
- **Selectors are 64-bit** (`ingredient_takes.gd` SELECT_ITEMS = 1 << 62): room for 62 pantry items, not 30.
- **Tests compare the book's declared categories**, so they hold before and after foraging defines its items.

## The independent review (2026-10-01)

HIGH, fixed: the drink guard had no test that could fail (now `serves`, tested for the cordial at both meals), and the
estimate's pool would have been overrun by a new category (now counted from the catalog). MEDIUM, fixed: waiting dishes
excluded from the choice; misspelt NEEDS keys an error; the guide's potato no longer says every dish taking it waits;
an unknown goods item is an error, not "not yet in the demo"; a drink is not "served at the hall's tables" and has no
other-meal link; "A drink" not "A Drink"; fresh fish's guide entry names every fish dish (baked fish included); tests
independent of foraging's items; 62-bit selectors. LOW, fixed: stale comments, flour's guide links, proper nouns kept,
the waiting list below the tab note. Not changed: PENDING_SOURCES stays an untyped Dictionary, as the codebase's are.

## Verification

- Mutation of the new logic: 26 mutants, 23 killed. The three survivors guard what has no case yet and are equivalent
  under today's data: `serves` without its drink check and the kitchen without `serves` (every waiting dish or drink
  has an input with no item yet, so it never has a batch); `CATEGORY_COUNT` without its catalog count (no category
  beyond the named nine yet). Each is caught by its test the day foraging defines raspberry or a new category.
- Frames, looked at (`scratchpad/dishes_check/p2_*` at 1920x1080 and 1280x720): the Recipes tab for flour (hardtack
  and the biscuit soup cookable; the pasty, pies and scones waiting, each with why), potato, dried fish; the Kitchen
  tab's plan (hardtack at breakfast, the salad at supper) and its "Waiting for ingredients"; the guide's pasty.
- Full suite: `ok: 7547 tests, 569210 assertions, 0 failures.`
- GDScript analyzer: no warning on any line this change adds.

## PROPOSALS needing Brendan's ruling

1. **The drafted numbers** in the table (DEC-045). Recommendation: confirm, then the balance sim measures them.
2. **Moles' favourite**: the library ties the deeper'n'ever pie to moles (`long_patrol::LP-FOOD-deeper-n-ever-...`,
   "Named mole-associated pie"); the favourites table (approved as P1) does not list the root pie. Recommendation: add
   "moles like the root pie" (LIBRARY basis) -- not changed without his word.
3. **Oatcakes and farls** lose every tie to porridge (the book's order; nobody likes them more), so the cook rarely
   makes them. Recommendation: leave it to feature 17's variety, or give a species a liking for them.
4. **Potato's rawness**: in the roots row it is raw-edible like the GDD's roots; the crops lane may revisit.

## Source

GDD §5.5 (forage), §5.6 (roots, hives), §5.7 (recipe format, food table, `woodland_pie`, `ration` left to preserving),
§5.8 (kitchen wood); CONTENT-LIB-001; the library recipes cited; decisions 0434, 0601, 0602; DEC-045.
