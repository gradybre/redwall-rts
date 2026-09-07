# Food, ingredients, objects and customs — source-to-game catalog

`DESIGN-CATALOG-002` · Revision 1.0 · Source observations plus authored adaptation classification. Entries are content candidates, not additions to `settlement_rules_v2`. Evidence IDs resolve in the named study and `source_audit.json`.

## 1. Admission into the game catalog

The current edible-animal whitelist is **carp, dace, herring, mackerel, mussel, perch, salmon, trout and whitefish**. Pike and eel remain nonharvestable hazards. Shrimp, whelk and grayling cannot be admitted by relabeling them `fish`. Source goat milk and eggs do not authorize livestock or dairy chains. A specific fictional plant-derived preparation can inform an authored plant recipe without changing this rule.

| Class | Exact meaning | Action before gameplay use |
|---|---|---|
| `PLANT_CANDIDATE` | Explicitly plant ingredients in the observed preparation | Define every input/output, process, work, fuel, quality and unlock field in the owning catalog |
| `WHITELIST_FISH_CANDIDATE` | Named edible animal is in current whitelist | Still author the dish; whitelist eligibility does not create its recipe |
| `FOOD_POLICY_CONFLICT` | Contains an animal ingredient outside current policy | Keep as source evidence; adopt a named deliberate adaptation or obtain a policy change |
| `COMPOSITION_UNRESOLVED` | Some source ingredients are unspecified or material words ambiguous | Resolve before declaring a faithful recipe; do not infer all cream/cheese bases |
| `PROP_OR_CULTURE` | Appearance, equipment, custom or narrative identity | May inform art/story briefs; authoritative resources and mechanics require their own catalog |

An ingredient-compatible dish is not necessarily implementable with the present five crops and 60 item definitions. Ingredient identity, season, supply chain and storage form need deliberate mapping. The same raw commodity may support multiple preparations without requiring each flavor word to become a separate farm resource.

## 2. Food candidate register

| ID | Dish/material | Explicit source detail | Class | Evidence |
|---|---|---|---|---|
| FOOD-001 | Whole baked grayling | Large fish served from a trolley with culinary ceremony | FOOD_POLICY_CONFLICT | RW-D01 |
| FOOD-002 | Shrimp with cream and rose leaves | Aquatic starter with named garnish | FOOD_POLICY_CONFLICT | RW-D01 |
| FOOD-003 | Barley pearls in acorn puree | Distinct grain/nut preparation; seasoning not fully given | COMPOSITION_UNRESOLVED | RW-D01 |
| FOOD-004 | Cabbage stalks and creamed turnip | Marination, nutmeg, texture and prepared form | COMPOSITION_UNRESOLVED | RW-D01 |
| FOOD-005 | Mole pie variation | Turnip, potato, beetroot and beans, with tomato chutney in Mossflower | COMPOSITION_UNRESOLVED | MF-D06 |
| FOOD-006 | Celery-fennel stew | Hazelnut dumplings and cheese accompaniment | COMPOSITION_UNRESOLVED | MF-D04 |
| FOOD-007 | Seed-barley cake | Mint icing; no full batter specification | COMPOSITION_UNRESOLVED | MF-D05 |
| FOOD-008 | Tussock hotpot | Corn, carrot, mushroom, turnip, winter cabbage, onion, secret herb gravy and crust | COMPOSITION_UNRESOLVED | LP-D01 |
| FOOD-009 | Camp crumble | Apple, blackberry and plum with greensap/maple sauce | COMPOSITION_UNRESOLVED | LP-D01 |
| FOOD-010 | Army cauldron stew | Leek, mushroom, carrot, turnip, shrimp, onion, potato, herbs | FOOD_POLICY_CONFLICT | LP-D09 |
| FOOD-011 | Great Hall cake | Arrowroot/pollen flour, greensap milk, fruit/nut preparations and layered toppings | COMPOSITION_UNRESOLVED | SA-D03 |
| FOOD-012 | Cave dinner pastie | Leek and mushroom under crust, watercress garnish | COMPOSITION_UNRESOLVED | SA-D06 |
| FOOD-013 | Cave salad | Fennel, hazelnuts, young dandelions, scallions | PLANT_CANDIDATE | SA-D06 |
| FOOD-014 | Greensap nut cheese | Pounded grass stems and special tubers; hazel, almond, chestnut; bark-covered maturation | PLANT_CANDIDATE | OC-D03 |
| FOOD-015 | Beechnut spread | Paste spread on brown bread | PLANT_CANDIDATE | OC-D02 |
| FOOD-016 | Treetop broth | Maple tips, acorns, beechnuts, green apple, horse chestnut | PLANT_CANDIDATE | OC-D08 |
| FOOD-017 | Phantom warrior soup | Treetop broth combined with hotroot-shrimp soup; parsley wine, ramson, winter rosehips | FOOD_POLICY_CONFLICT | OC-D08 |
| FOOD-018 | Family travel cake | Fruit and honey cake sliced at a shelter fire | COMPOSITION_UNRESOLVED | MX-D04 |
| FOOD-019 | Strawberry fizz | Cask, trestle, spigot and tasting/service described | COMPOSITION_UNRESOLVED | MX-D09 |
| FOOD-020 | Polleekin's stew | Carrot, turnip, peas and leeks cooked in a stone-oven household | PLANT_CANDIDATE | MW-D03 |
| FOOD-021 | Shipboard hotroot soup | Watershrimp and bulrush; barleybread and scupperjuice beside it | FOOD_POLICY_CONFLICT | MW-D06 |
| FOOD-022 | Broggle's nutfarls | Hazel, beech and chestnuts in a praised bread preparation | COMPOSITION_UNRESOLVED | TG-D05 |
| FOOD-023 | Cavemob eel preparations | Elvers collected, carted, cooked in several ways and made into pies | FOOD_POLICY_CONFLICT | TG-D06 |
| FOOD-024 | Skilly'n'duff aboard Stopdog | Wheat/barley flour, preserved damsons, honey, water, unnamed other ingredients; soft pudding | COMPOSITION_UNRESOLVED | TR-D03 |
| FOOD-025 | Leaf-wrapped island produce | Fruits/vegetables wrapped in leaves over fire-heated stones | PLANT_CANDIDATE | TR-D06 |
| FOOD-026 | Roobee's dinner | Cabbage-turnip pasties, carrot-mushroom cheese bake, beetroot soup, fruitloaf | COMPOSITION_UNRESOLVED | TR-D07 |
| FOOD-027 | Tansy's celebration cake | Greensap milk, flour, honey, nuts, fruit and wine; oiled bark liner | COMPOSITION_UNRESOLVED | PL-D04 |
| FOOD-028 | Tansywine | Rosehip, honey, strawberry; commemorative name | PLANT_CANDIDATE | PL-D10 |
| FOOD-029 | Didjety's sausages | Ground barley/oats/carrot/mushroom; onion-skin wrap; baked slowly overnight | PLANT_CANDIDATE | RT-D11 |
| FOOD-030 | Didjety's sausage rolls | Sausage preparation enclosed in pastry and warmed on stones | COMPOSITION_UNRESOLVED | RT-D12 |
| FOOD-031 | Individualized oatmeal | Honey for one diner; hotroot and nutmeg for another | PLANT_CANDIDATE | RT-D01 |
| FOOD-032 | Ruff's dace | Dace over greens/leeks with a cornflour/oat crust, flat-stone cooking | WHITELIST_FISH_CANDIDATE | LB-D03 |
| FOOD-033 | Frutch's chowder | Potato, whelk and leek | FOOD_POLICY_CONFLICT | LB-D06 |
| FOOD-034 | Traveling ration set | Dried apple, nuts, oatcake, water | COMPOSITION_UNRESOLVED | LP-D06 |
| FOOD-035 | Cooler drinks | Cordials cooled in a stream or cellar | PROP_OR_CULTURE | OC-D03; PL-D09 |
| FOOD-036 | Cellar range | Ale, cider, stout, wines, brandy, port and sherry named | COMPOSITION_UNRESOLVED | RW-D03 |

These fictional food descriptions are source analysis, not real-world preparation advice. The botanical names and fantastical processes have not been evaluated as food or medicine.

## 3. What a source recipe really establishes

| Preparation | Known operations | Known source counts/timing | Explicit missing production data |
|---|---|---|---|
| Ruff's dace | Prepare greens; use their water for crust mixture; cook fish on stone; arrange over drained vegetables | Two dace; two leeks; no exact cooking duration | All masses, other ingredient quantities, yield, portions, work, heat, fuel, spoilage, nutrition and quality |
| Greensap cheese | Pound stems/tubers; incorporate nuts; mature in dark space under damp bark; slice with twine | Seasonal history, not calibrated processing time | Botanical identities, extraction yield, additives, ratios, required station, exact maturation duration, loss and outputs |
| Didjety's sausages | Grind/mix named ingredients; wrap in onion skin; bake slowly | Overnight in the described household | Ingredient masses, batch output, thermal conditions, work/fuel, nutrition, storage and unlock |
| Great Hall cake | Mix, bake, cool until firm, cut and layer carefully, finish surface | Layering instructions; no complete quantitative formula | Exact input list/ratios, durations, oven capacity, output portions and spoilage |
| Skilly'n'duff | Mix flour/preserved fruit/water; bake soft pudding; serve sauce | No exact counts; additional ingredients unnamed | Full input set plus every game production value |

Author game recipes as deliberate adaptations with complete integer catalog rows. Do not convert “overnight” into the existing game's tick count and attribute that number to Jacques. Do not use the current `woodland_pie` recipe as canonical mole pie: it currently uses flour, mushrooms, roots and water. Current `root_stew` does not prove the source's named vegetables exist as individual stock keys. Current `mead` does not implement cider, strawberry fizz or Tansywine.

Recommended candidate order is FOOD-029, FOOD-014, FOOD-032, then a named adapted mole pie. This is an authored planning priority: clear source identity, strong community use and manageable opportunity to extend existing materials. It is not a player-approved unlock order or a promise that the current catalogs can already produce them.

## 4. Ingredient families for art and economy authoring

| Family | Source examples in this pass | Decisions needed for game representation |
|---|---|---|
| Grains/starches | Oat, barley, wheat, cornflour, arrowroot, pollen flour | Distinguish actual stock from regional wording; do not map every flour to one item silently |
| Roots/vegetables | Carrot, turnip, potato, beetroot, leek, onion, cabbage, bean, pea | Decide stock granularity versus visual variety; preserve nutrition/cost truth |
| Nuts/seeds | Hazel, chestnut, almond, beech, acorn | Supply and seasonal form; not all named nuts need separate economic resources |
| Fruit | Apple, pear, plum, damson, greengage, berry varieties, quince, grapes | Fresh/preserved/dried forms; visual ripeness without unspecifed yield mechanics |
| Greens/aromatics | Fennel, celery, watercress, dandelion, mint, ramson, rosehip | Culinary culture versus real medical claims; authored horticultural availability |
| Sweeteners/creams | Honey, maple preparations, greensap milk, many named creams | Known versus unknown base; fictional plant preparation must be specifically identified |
| Fish/shellfish | Dace/trout plus conflicting grayling/shrimp/whelk/elver | Whitelist exactness; discovery does not authorize harvesting |
| Drinks | Water, tea, cordial, fizz, cider, ale, wine | Recipe identity, storage vessel and occasion; no inferred alcohol effects |

## 5. Objects and customs beyond the kitchen

| ID | Reference | Game-direction application | Evidence |
|---|---|---|---|
| OBJ-001 | Lantern line and rope ladder | Prepared descent; light and access have different functions | LP-D08 |
| OBJ-002 | Plumb line and quill knife | Visible inspection with a concrete finding | LP-D03 |
| OBJ-003 | Carved bottle mistaken for doorstop | Provenance and skilled recognition | TG-D04 |
| OBJ-004 | Monocle on retention cord | Reading aid and inherited personal story | TG-D05 |
| OBJ-005 | Buckthorn spoon and floorboard lever | Authored, finite interaction with readable physical constraints | PL-D05 |
| OBJ-006 | Tapestry and commemorative object placement | Shared memory, recovery and continuity | RW-D03; MX-D10 |
| OBJ-007 | Leaf talisman | Socially recognized history with bounded local meaning | OC-D04 |
| OBJ-008 | Boat name and transferred craft | Stable identity through gifting, renaming and learning | MX-D07, MX-D10; TR-D08 |
| OBJ-009 | Pail of manuscripts, ink gourd, scroll | Scholarship embedded in household life | LB-D01–02 |
| OBJ-010 | Wire/twine cheese cutter, bark wrap, spigot | Small craft details with useful animation/contact points | OC-D03; MX-D09 |
| CULT-001 | Cheese-and-drink tasting | Cooperative judgment, recording and recipe knowledge | PL-D09 |
| CULT-002 | Rotating sentries at a feast | Participation depends on actual duty coverage | LB-D08 |
| CULT-003 | Performers after chores | Work, audience and shared leisure | MX-D05 |
| CULT-004 | Produce judging | Community prestige through cultivation | TR-D06 |
| CULT-005 | Quiet preferred breakfast | Relationship expressed through small accommodations | TR-D04 |
| CULT-006 | Winter storytelling | Seasonal gathering and intergenerational memory | TG-D01; LB-D02 |
| CULT-007 | Public commemorative meal | Names and absences matter to ceremony | OC-D07 |
| CULT-008 | Family dance | Distinct instruments, formations and playful competence | RT-D04 |
