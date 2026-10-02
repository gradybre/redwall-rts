# 0675 — A protected grove: never felled, a stone to rest and watch from, a season's line in its record
Date: 2026-10-01 · Status: Accepted (review ECO-015, group Y); its specifics are 0671's proposal 7

## Decision

- **One grove, the North hollow**: a 6.5 m circle in the west of the North stand (the forestry zone), round two of its
  mature trees, protected from the start; the Orchard panel's grove section toggles it. A sage ring marks it while
  protected; a mossy stone at its heart is its rest and observation spot.
- **The woods never fell a tree in it while it is protected** -- by the player's order, a zone's auto-fell, or the
  winter lane's Firewood order. The hook is narrow: `forest_crew.gd set_protected(callable)`, asked by `_fell_refusal`,
  which every fell already goes through, refusing **IN_PROTECTED_GROVE** ("it stands in a protected grove — never
  felled"). The zone's floor still counts the grove's trees (they stand).
- **Its use** (ECO-015's "place utility before a biodiversity score"): once a season a resident walks to the stone and
  observes (10 WU); the line -- the date, the season's sighting (insects and the trees' own year only: mammals and birds
  are never targets or pest icons), the trees standing, protected or not -- goes into its record (sixteen kept) and
  the village news.
- **No yield buff**, as ECO-015 says ("begin with no new yield buff").

## Why the conservation zone is not enough

The GDD's CONSERVATION zone is never cut at all; ECO-015 asks for a grove that is a *place* inside a worked woodland,
which is a choice the player keeps making. A circle inside the forestry zone is that choice, and its toggle lets it go.

## Not built

The grove's seasonal forage reserve (its forage is the foraging lane's -- that lane's nut spot at (-7.5, -29.4) lies in
it, unwired); rest as a need (the observation is work, not rest, until a leisure model exists: SOC leisure is group
AE's); marking more groves.

## Source

REVIEW.md ECO-015 (2561); GDD §5.5 ("Protected tiles are never automatically harvested"), §5.9 (forestry zones);
the winter fuel lane's Firewood order (decision 0571 on its branch), which asks `_fell_refusal`.
