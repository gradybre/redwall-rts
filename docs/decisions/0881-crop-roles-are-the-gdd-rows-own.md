# 0881 — Crop roles are the GDD rows' own: two differences each, uses read from data
Date: 2026-10-01 · Status: Accepted

**Numbering.** The external review's crop-plans lane (group X: ECO-001, ECO-003, ECO-004 with feature #48, ECO-006,
ECO-007) takes 0881–0889: 0881 crop roles, 0882 harvest plans, 0883 the kitchen garden, 0884 tunnel outlets, 0885
tending policies. None of 0880–0889 existed on this branch.

Brendan approved the review's **ECO-001** ("Crop roles with clear uses", `redwall-review/REVIEW.md` 2180, read-only):
"Start with six role profiles across the existing ingredient set ... Give each at most two consequential differences
... Keep sibling ingredients explicitly equivalent until approved culinary use distinguishes them. Test 15–25%
differences, not tiny hidden bonuses."

## Decision

**A crop's role is its GDD §5.6 row's.** The demo grows sixteen pantry ingredients, each by exactly one §5.6 row
(`farm_catalog.gd` ITEM_CROP, decision 0196), and §5.7 gives each row its storage category. Five of the review's six
roles already *are* those rows, so the role is named for what the row's adopted numbers make it
(`godot/demo/farm/farm_crop_roles.gd`):

| §5.6 row | Role | Its two differences (the row's own numbers) |
|---|---|---|
| Roots (radish, turnip, carrot, beetroot, parsnip, onion) | Keeping root — the reliable staple | keeps 10 days (§5.7 240 h) · ripens in 5 days (§5.6 120 h) |
| Cabbage (cabbage, lettuce, spinach, leek, celery) | Fresh greens — the quick fresh crop | sown in summer and autumn (§5.6 windows) · keeps 6 days (§5.7 144 h) |
| Beans (pea, broad bean) | Soil restorer — the rotation restorative | gives the soil 800 fertility (§5.6 cost −800) · keeps 20 days (480 h) |
| Grain (wheat, barley, oats) | Flour crop | 10 U a bed (§5.6) · ripens in 8 days (192 h) |
| Flax (not grown in the demo) | Fibre crop | sown in spring · 5 U a bed |

Every difference is a row's constant worded at run time (`trait_text`), so a changed table changes the words; each is
20% or more between rows, never a hidden bonus.

**Uses are read from data**, so a dish added to the kitchen shows without an edit (the Dishes lane): every
`meal_rules.gd` dish whose input or second input is the ingredient's category (`is_input`), the mill for the grain row
(`fishery.gd` grinds CROP_GRAIN: §5.7 `flour`), and "eaten raw in a pinch" where the kitchen's raw-emergency table lists
the category (`raw_np_per_u`). A row no dish uses says so ("no dish in the village yet": peas and beans today).

**Shown** under each crop's button in the crop picker (`farm_bed_panel.gd` `picker_role`), as
"Keeping root — keeps 10 days · ripens in 5 days. Uses: Togget's vegetable soup, Poached perch or trout, eaten raw in
a pinch", and as "Radish (keeping root)" in the harvest plan (0882).

## Why

The review's own warning is "every named vegetable becoming a slightly different spreadsheet row with one best
answer". The adopted rows already differ by 20–60% in exactly the dimensions the review names (harvest timing,
storage, recipe use), and AGENTS.md forbids inventing constants no document states. So no number changed; the
difference is made *legible*.

## Proposals for Brendan

1. **A long-storing root apart from a quick fresh root** (the review's sixth role: radish quick, parsnip slow). It would
   give siblings of one §5.6 row different numbers. Options: (a) keep siblings equal (built); (b) per-ingredient
   modifiers inside the review's 15–25% (radish ripens 20% sooner and keeps 20% less; parsnip ripens 20% later and
   keeps 25% longer); (c) a new §5.6 row (a GDD amendment). **Recommendation: (a)** until a culinary use distinguishes
   them; if wanted, (c) with Brendan's numbers rather than demo modifiers.
2. **Flax, the fibre crop**, is not grown: nothing in the demo turns flax into cloth or rope yet. **Recommendation:**
   add it with a workbench rope recipe (§5.7 `rope`: flax 2 → rope 2), not before.
