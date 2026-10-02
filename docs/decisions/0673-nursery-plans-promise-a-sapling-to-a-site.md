# 0673 — Nursery plans: each propagated sapling is promised to a site, and shows its first fruiting season
Date: 2026-10-01 · Status: Accepted (review ECO-009, group Y); built as Brendan approved on 2026-10-01 (decision 0671:
all proposals as built)

## Decision

- **A plan** (`orchard_model.gd`, at most six) ties one sapling of a species to one empty site: WAITING (the nursery has
  not propagated it), GROWING (§5.6's 12-day wait), READY (a sapling held for that site), closed when planted. A site
  with a plan is **spoken for**: no other planting goes there. A waiting plan may be dropped; a growing or ready one
  goes on to its site.
- **The routine works plans**: a propagation is raised for a waiting plan whose inputs are in the village -- §5.6's
  fruit 4 U of its species **from the orchard's basket stands** (oldest lots first, counted as used: never food in a
  store, which the kitchen may have reserved), compost 2 U (the farm's compost store) and water 2 U (the kitchen's
  butt) -- 120 WU at the nursery; a planting is raised for a ready plan's site. A propagation notes its plan's serial
  when it is opened, so a plan dropped and its row reused is never finished against the new one.
- **The first producing season is shown** for every plan and every empty site: the early fruit (decision 0672) and the
  full crop, REQ-SET-081's day, counted from when the sapling will be ready.
- The **free saplings** (the M3 grant, decision 0672) may be planted straight away on any free site.
- ECO-010's "seedling" share is the group's **keep** (0674): fruit held at the baskets for the nursery.

## Not built

**Relocating a young sapling with a growth delay** (ECO-009's "Light: relocation is a new mechanic") needs its own
ruling and is not built; a planted tree stays where it is (§5.6: removal gives wood 8 and no sapling back -- not offered
in the demo either).

## Source

REVIEW.md ECO-009 (2404); GDD §5.6 (nursery propagation, the 12-day wait, REQ-SET-081).
