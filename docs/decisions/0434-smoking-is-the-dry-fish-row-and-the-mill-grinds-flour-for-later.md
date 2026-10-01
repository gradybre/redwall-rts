# 0434 — Smoking is the GDD's dry_fish row; dried fish is the reserve; the mill grinds flour for later
Date: 2026-10-01 · Status: Accepted

Water part B (0431). Numbered in this lane's 0431–0439 range.

## Decision

### 1. The smoking rack is the GDD's Dryer, running §5.7's `dry_fish`

**The GDD has no smoking method** (review ECO-028 says so; SET-AMEND-001 retired `smoke_game` with the game it smoked).
So the smoking rack by the fisher shelter IS §5.9's Dryer ("Preserver 1 | 4 passive batch slots | Start") running
§5.7's `dry_fish` row exactly: **fish 4 -> dried_fish 3 (3 × 1800 NP), 24 WU + 12 h passive, shelf 720 h**. It is drawn
as a smoking rack -- the staged `smoking_rack` model, two fish hanging a slot while it cures, smoke rising -- and called
"Dry fish on the smoking rack". Nothing about smoke changes a number.

- **Dry fish** (the Water panel): the 4 U of fresh fish that spoil first are set aside in their lots (the kitchen's own
  reservations, `ingredient_takes.gd`, so neither the kitchen nor the raw-food rule counts them) and room is held for
  the 3 U it makes (REQ-SET-112). A resident fetches them (the books do not move), and at the rack the batch STARTS:
  the 4 U are withdrawn then, all or nothing (REQ-SET-118); 24 WU hung; then the slot CURES 12 game hours with its worker
  free (REQ-SET-093); then a take-down job carries the 3 U to the held store.
- **Cancelled** before its fish reached the rack, nothing moves; after, REQ-SET-094: half the 4 U becomes spoiled food.
  A cured batch is always taken down -- one cured while every job row is taken stays READY and goes on the board as soon
  as a row is free.
- **Fresh food keeps its role** (review ECO-028): fresh fish is the kitchen's fish stew (0436) and dries 4 : 3 -- a
  quarter of its mass and NP given for 15 times the shelf life, and a slot and labour.

### 2. Dried fish is the reserve, eaten as it is

§5.7: "Dried/salted fish ... are directly edible". No GDD recipe the demo can cook takes dried fish (§5.7's `fish` selector
names the species, and `ration` needs flour, nuts and dried fish -- the demo has no nuts), so dried fish is the village's
RESERVE: `meal_rules.gd RAW_NP_PER_U` gives it 1800 NP/U, and a hungry resident with no portion eats it under the raw
emergency rule (REQ-SET-013, at most 3000 NP) -- after anything spoiling sooner, as that rule chooses (720 h keeps it last).

### 3. The mill grinds §5.7's `flour`, and the flour is stock for later

The watermill on the far bank grinds **grain 3 -> flour 3, 12 WU** (§5.7 `flour`, Mill/CRAFT; §5.9: "2 mill slots").
**Mill grain**: the 3 U of grain that spoil first, NOT set aside by the kitchen's porridge, are reserved, and room is held
for the 3 U of flour (REQ-SET-112, as the rack's; a cancel gives both back); a resident fetches
them, crosses the stream (the ford or a bridge) to the mill, where the batch starts (withdrawn then); 12 WU at the stones
while the wheel churns (presentation); the 3 U of flour carried back to the held store. Flour keeps 240 h.

**The flour outcome: no dish uses it in the demo.** Every §5.7 recipe that takes flour needs an input the demo does not
have -- `woodland_pie` mushrooms, `berry_tart` berries and honey, `orchard_crumble` fruit and honey, `nut_loaf` nuts,
`ration` nuts -- and porridge takes grain, not flour (BAL-RATIO-003). So no third flour dish is added; flour is pantry
stock, shown in the Stocks and the Water panel, for a later lane that brings one of those inputs. It is not eaten raw
(§5.7: "No").

## Why

Inventing a smoking recipe would be a number the GDD does not have; the dryer row is what the GDD offers for keeping
fish. Inventing a flour dish from ingredients the demo lacks would be the same.

## Consequences

When the GDD adds smoking, it replaces only the rack's row. When the demo gains nuts, mushrooms, berries, fruit or honey,
the matching flour recipe can join the kitchen like the fish stew (0436).

## Source

GDD §5.7 (`dry_fish`, `flour`, `ration`, the flour recipes; "Dried/salted fish ... directly edible"; REQ-SET-093/094/112/
118), §5.9 (Dryer, Mill), §5.2 (REQ-SET-013); balance BAL-RATIO-003; review ECO-028; SET-AMEND-001.
