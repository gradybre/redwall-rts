# 0436 — The kitchen's third dish is §5.7's fish stew, cooked from fresh fish
Date: 2026-10-01 · Status: Accepted

Water part B (0431); extends decision 0381's kitchen (Brendan's ruling 1 there: two dishes, alternating). Numbered in this
lane's 0431–0439 range.

## Decision

- **The dish**: the content library's "Requested perch or trout" (`taggerung::TAG_recipe_requested_perch_or_trout`, a
  poached perch proposal), COOKED AS §5.7's `fish_stew` row exactly -- **fish 2, roots 2, water 2 -> meal_fish_stew
  3 × 2200 NP, 20 WU, Kitchen/COOK, 24 h, Start** -- as the porridge and the soup are library recipes cooked as their
  rows. Its `fish` is §5.7's selector over the six fresh species the village catches (BAL-CAT-004); DRIED fish is its own
  item and is not taken (0434: it is the reserve). Its second input is the roots row.
- **When**: at SUPPER, in place of the soup, whenever the stores hold a batch's fresh fish and roots nobody has set aside
  -- fresh fish keeps 48 h, so it is cooked while it is fresh; otherwise ruling 1's alternation runs as before
  (porridge at breakfast, soup at supper, each turning to the other when its food is short). The stew's own fallback is
  the soup.
- **Two inputs, both or neither**: a meal of fish stew reserves both inputs from real lots (soonest to spoil first),
  holds no more of either than whole batches of both make (`_even_inputs`), withdraws both together when a batch starts,
  and a batch cancelled while cooking yields half of both as spoiled food (REQ-SET-094). The kitchen's reservations
  gained a category filter (`ingredient_takes.gd live_milli` / `consume_into` / `release_milli`, `crop`; -1 any).
- **Ready food** counts each dish at its own portions (`cookable_portions`): porridge from the grain, the stew from the
  fish and the roots it takes (3 a batch), the soup from the roots left -- never the roots twice.
- **Words**: the Cook card shows both inputs' have/need; a stew short of roots says so; the Kitchen tab's pot counts its
  portions. The Recipes tab is NOT extended: its rows are the content library's pantry index (`farm_recipes.gd`,
  `pantry_index.json`), built for the 16 farm ingredients; listing fish, dried fish and flour there needs that index
  rebuilt with the fish leaves (`tools/make_demo_pantry_index.py`) -- left for a later lane. A batch withdraws its two
  inputs only after checking both are at the kitchen, so it never takes one without the other.

## Why

Water part B's catch should feed the village: without a dish, fresh fish has no use but drying, and review ECO-028 asks
that "fresh food keeps a role". The fish stew is a Start recipe of §5.7 whose every input exists in the demo, so it is
the GDD's own answer, not an invented one. Rejected: putting dried fish in the stew -- §5.7's `fish` names the species.

## Consequences

Ruling 1's "two dishes, alternating" stands for breakfast and the soup's turn; the stew only replaces a supper the
pantry's fresh fish can make. A flour dish can join the same way when its inputs exist (0434).

## Source

GDD §5.7 (`fish_stew`, the food table, REQ-SET-094/109); balance §3.2 (`fish_stew`: `@fish:2000;roots:2000;water:2000`);
decision 0381; review ECO-028; the content library's recipes (`docs/redwall-content-library/shared/recipes.json`).
