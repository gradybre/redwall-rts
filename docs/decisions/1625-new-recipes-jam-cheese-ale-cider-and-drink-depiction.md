# 1625 — New recipes for the waiting icons: berry jam, nut cheese, ale and cider; drink depicted by the mead rule
Date: 2026-10-07 · Status: Accepted (engineering) under Brendan's approval; **every number PROVISIONAL; pickles BLOCKED**

**Numbering.** The lead assigned 1625–1629 on `feat/demo-new-recipes` (the food packets' remapped 1601–1629 range; the
packets' own 1251–1260 collides with a parallel digging branch). 1625 is free on every local and remote ref.

## Approval (Brendan, 2026-10-07)

Relayed by the coordinator: **"Approve and build Q-d5 and dec-007"** -- open question Q-D5 options (b) and (c):
- **(b)** draft and build the recipes the icons of art pass 3 already exist for (decision 0971: `item_jam`,
  `item_pickles`, `item_cheese`, `item_ale`, `item_cider`), from the content library, within DEC-006's plant, fish and
  seafood boundary;
- **(c)** rule how drink is depicted (DEC-007's open point "How should mead and other drinks be depicted?").

**Brendan's ruling on DEC-007's drink depiction (2026-10-07):** ale and cider follow the mead rule -- a feast or table
drink only, no intoxication, and no effect on Shared Warmth. (`docs/setting_decisions.md` is not edited here, as
instructed; the ruling is recorded in this record and in `docs/handoff/RULINGS.md`.)

## Decision

Four rows are appended to the stations' recipe table (`godot/demo/preserve/preserve_rules.gd`, decisions 1611/1621),
and four pantry items to `farm_catalog.gd` (append only): **jam 36, cheese 37, ale 38, cider 39** (categories 18–21).
The preserving table gains **two crocks** (passive slots 8–9, after the rack's 0–3 and the vats' 4–7) for the cheese's
culture stage. A recipe input may now be an **item selector** (`ingredient_takes.gd` SELECT_ITEMS), so ale takes
barley alone and cider apples alone; the input column is int64 for it. The regatta's feast pours ale and cider beside
mead and the cordial (`regatta_menu.gd` DRINK_ITEMS). The Water panel gains Make jam / Make cheese (Preserves) and
Brew ale / Make cider (Brewing).

### The recipes, each number PROVISIONAL, and its source

| Row | Inputs → output | Work, wait, station | Shelf | Eaten raw | Source (content library, `shared/recipes.json` / `pantry.json`) |
|---|---|---|---|---|---|
| `jam` | berries 2 + honey 1 + water 1 → **berry jam 3** | 16 WU, none, preserving table | 720 h | 850 NP | The library's honey fruit jams: `COMPONENT_shared_blackberry_jam` / `strawberry_jam` (fruit, honey, water, apple pectin), `marlfox::MF_RECIPE_damson_jam`, `taggerung::TAG_recipe_quince_jam` (fruit, honey, water). The demo's `berries` stands for the hedge's blackberries and strawberries; the apple pectin is folded into the cooking (no pectin item). |
| `cheese` | nuts 2 + water 1 → **nut cheese 2** | 16 WU + 24 h in a crock, preserving table | 1440 h | 1600 NP | `taggerung::TAG_recipe_nut_cheese` -- hazelnut, chestnut, water, a cultured food starter: **a salt-free plant cheese the demo's nuts can make.** The cultured oat, hazelnut, almond and seed *cheese* components take `LEAF_salt`; the library's other salt-free bases (`COMPONENT_shared_cultured_hazelnut_cream`, `cultured_oat_curd`, `oat_and_seed_curd`) need an oat drink the demo does not make. The demo's `nuts` are the woods' hazelnuts and chestnuts; the starter is the crock's culture stage, not an input. Dairy stays excluded (DEC-006, SET-AMEND-001). |
| `ale` | barley 3 + water 3 → **ale 4** | 20 WU + 72 h in a vat, brewery | 1440 h | no | `COMPONENT_shared_october_ale` / `shared_ale` (malted barley, water, fermentation culture); `salamandastron::SAL_recipe_october_ale`. Malting and the culture are folded into the brew; the October ale's "ten seasons" of cellaring is not imported as a wait (the library itself says so). Units, work and wait follow §5.7 `mead`. |
| `cider` | apples 4 + water 1 → **cider 4** | 16 WU + 72 h in a vat, brewery | 1440 h | no | `taggerung::TAG_recipe_pale_cider` (apple, water, cultured yeast), `mossflower::MF_recipe_cider`, `COMPONENT_shared_pale_cider`. Apples only (pears are not cider); the wait follows mead's. |

Why these numbers: the units sit between §5.7's preserving rows (fruit 4 → 3) and mead (honey 3 + water 3 → 4); the
work matches the nearest §5.7 rows (16 WU for a cooked preserve, mead's 20 WU for a brew); the raw NP spread a batch's
input NP over its output (jam: 2 berries × 700 + 1 honey × 1200 ≈ 3 × 850; cheese: 2 nuts × 1600 = 2 × 1600); the
shelves are dried fruit's 720 h for jam and mead's 1440 h for both drinks and the cheese (the cheese keeps its nuts
twice as long as the nuts' own 720 h -- its purpose, since its NP equals theirs). The feast pours ale and cider ceil(E/4)
U each, mead's quantity. None is a GDD number.

### Pickles: BLOCKED

Every pickle formula in the content library takes **salt**: `taggerung::TAG_recipe_pickled_onions` (onion, cider
vinegar, water, salt), `long_patrol::LP-RECIPE-tangy-pickles` and `lord_brocktree::LB-RECIPE-kitchen-song-pickles`
(cucumber, onion, apple vinegar, water, salt); the fish pickles are coastal. The library does give a vinegar route --
`COMPONENT_shared_apple_vinegar` (apple, fermentation culture, vinegar culture) -- but no pickle that uses vinegar
without salt. Salt is coastal brine only (GDD §5.7; SET-AMEND-001), and the demo village has no coast. So no salt
source is invented and pickles are not built.

### Rules kept

- DEC-006 / SET-AMEND-001: plant staples plus fish and seafood; no livestock, milk or eggs -- the cheese is the
  library's plant cheese, the jam's sweetener the apiary's honey.
- LIB-002 / LIB-008: library records stay NOT_RUNTIME_ACTIVE; every number here is the demo's, marked PROVISIONAL.
- DEC-007 as ruled above: no intoxication; drinks never affect Shared Warmth; ale and cider are never eaten raw.
- Append-only numbering (SEQUENCE.md); no work-board source and no key added.

### Shared files touched

`farm_catalog.gd` (items 36–39, categories 18–21, `ITEM_BARLEY`), `meal_rules.gd` (words; jam and cheese raw NP),
`preserve_rules.gd` (four rows, crocks, item selectors, the int64 input column), `preserve_text.gd`, `fishery.gd`
(item-selector pickup, CROCKS_FULL, `slots_in_use`), `demo_fishery.gd` (cards from the action map, the lines),
`water_panel.gd` (two button rows), `regatta_menu.gd` (ale and cider poured), `tools/make_demo_pantry_index.py` and
`pantry_index.json`. Nothing under `scripts/core/`, `demo/burrow/`, `demo/tunnel/`, `demo/cast/` or the settlement UI.

## PROPOSALS (for Brendan)

1. **The four rows' numbers** in the table above, and the feast's ceil(E/4) U pour of ale and of cider (with mead and
   cordial, a fully stocked feast now pours four drinks). *Recommendation: approve as provisional; tune after a balance
   run.*
2. **Cheese as nut cheese** (the salt-free taggerung row), set in two crocks at the preserving table for 24 h.
   *Options:* (a) as built; (b) a salted oat cheese once salt exists. *Recommendation: (a).*
3. **Ale from barley alone, cider from apples alone**, both in the brewery's vats, poured at the feast like mead.
   *Recommendation: confirm.*
4. **Pickles (BLOCKED)**. *Options:* (a) wait for salt -- a coastal scenario or trade brings it, and pickles follow the
   library's formulas; (b) an authored salt-free vinegar pickle -- onion or roots in apple vinegar made from the
   orchard's apples (the library's `COMPONENT_shared_apple_vinegar`), a new recipe beyond the library's formulas, which
   needs your approval; (c) drop pickles from the demo and retire the icon's use. *Recommendation: (b), since the
   orchard and the brewery now give the demo apples and a fermenting place; otherwise (a).*

## Gates

Filled in when the lane's gates have run (below).

## Source

Brendan, 2026-10-07 ("Approve and build Q-d5 and dec-007"); `docs/handoff/OPEN_QUESTIONS.md` Q-D5; DEC-006, DEC-007;
`docs/setting_rules_amendment.md`; GDD §5.7; the content library (`shared/recipes.json`, `shared/pantry.json`,
`authoring_handoff.md`); decisions 0971, 1601, 1611, 1621.
