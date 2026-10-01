# 0435 — Fishing gear is real gear: the locker over gear.gd, wear without surprise breakage
Date: 2026-10-01 · Status: Accepted

Water part B (0431). Numbered in this lane's 0431–0439 range. Closes `fishing_driver.gd`'s named blocker "GEAR
DURABILITY AND WEAR".

## Decision

- **The gear is real.** The fishers' locker at the fisher shelter (§5.9: "Fisher shelter | ... | Gear locker")
  (`fishery/gear_locker.gd`) holds every hand net, trap, ice kit and tier-2 outfit as an `InventoryLot` of
  `data/item_definitions.json`'s item in a real `scripts/core/inventory.gd` container (200 000 g, §5.9's locker), with a
  real `scripts/core/gear.gd` GearInstance row. Its rope and iron are real lots too.
- **Wear is gear.gd's, unforked**: durability 0–1000; §5.4's wear a cycle (net 20, trap 10, ice kit 20); the claim is
  the cycle's Job's (decision 0017) -- completion wears it exactly once, cancellation not at all, a second completion
  refuses. **No surprise breakage** (review ECO-020): "A cycle cannot start with durability below wear" -- a worn net is
  refused BEFORE the trip ("every free hand net is worn below a cycle's 20 — Mend gear"), never breaks during one; the
  Water panel shows each piece's durability and cycles left.
- **Making** at the workbench (§5.9: "Gear crafting at a workbench"), §5.4's costs and balance §3.3's work: a net wood 2 +
  rope 1, 30 WU; a trap wood 4 + rope 2, 40 WU; an ice kit wood 2 + iron 1, 40 WU. Paid when the work starts there
  (wood from the stores, rope or iron from the locker), refunded if cancelled before the gear is made (no hidden loss --
  REQ-SET-094 is about food); the new gear carried to the locker.
- **Mending** (gear.gd's repair): 200 points per 30 WU for wood 1 + rope 0.25, clamped at the cap; Mend gear takes a free
  boat too worn to set out first, else the most worn free piece, else the most worn free boat (the boat is installed
  gear with the same recipe, 0432).
- **Tier-2 outfits** are gear with no durability (gear.gd: "no clothing degradation mechanic"); an ice trip sets one
  aside with its ice kit. They are not made here: §5.7's `outfit` is cloth 2 at a Workshop, and the demo has neither.

## The opening stock (DEMO)

The demo has no flax (rope is §5.7 flax), no iron producer and no cloth, so the locker opens with what the village came
with: **one hand net, one trap, two tier-2 outfits, 4 U of rope and 2 U of iron**. Making more gear spends them; when
they run out Make is refused saying so ("the locker holds 0.0 U (the village makes none)").

## Why

The real store exists, and it already states the GDD's two wear models, the claim-per-Job rule and the start-durability
bar exactly; a demo copy of durability would be a second copy of those rules. Its cost is small: the locker allocates a
4-container, 64-lot inventory and a 24-row gear store, about 1 ms at boot.

## Consequences

A later rope or iron producer only adds lots to the locker. A trap left soaking keeps its gear set aside until it is
collected. Gear has no owner resident (the locker owns it; GDD's "worker owns net" is not modelled), so nobody carries a
net between trips.

## Source

GDD §5.4 (gear table; durability; repair), §5.7 (masses; `outfit`), §5.9 (workbench, fisher shelter locker); balance §3.3
(`craft_net`, `craft_trap`, `craft_ice_kit`), BAL-CAT-009 (fishing-gear repair); `scripts/core/gear.gd`; decision 0017;
review ECO-019/020.
