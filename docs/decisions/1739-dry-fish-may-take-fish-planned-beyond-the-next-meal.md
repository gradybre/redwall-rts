# 1739 — Dry fish may take the fish the kitchen planned for meals beyond the next one
Date: 2026-10-08 · Status: Accepted

## The ruling

Brendan, 2026-10-08, on the balance rerun's follow-up question F3 (decision 1738;
`docs/balance/2026-10-07-year-matrix-rerun.md`, "Follow-up: after the tuning"): **(a)**, Dry fish may take fish the
kitchen has planned beyond the next meal, **never the next meal's fish**. Relayed by the coordinator.

The evidence: even fishing to 12 U, Dry fish was refused NO_FISH on 47 of 48 mornings and rations were never made. The
kitchen plans two days of meals ahead and reserves every fish for them, so the rack never saw a free one.

## Decision

- **The kitchen** (`kitchen.gd` FISH FOR THE RACK; three functions, nothing else in it changed):
  - `fish_beyond_next_meal_milli()`: the fish still in store that the takes of meals beyond the next one hold.
  - `release_fish_beyond_next_meal(milli)`: gives up to `milli` of that fish back to the pantry, free, from the latest
    meal holding fish first.
  - **Which meals are protected** (`_rack_may_take`): the next meal is the later of the earliest planned meal and the
    meal being served now. The rack never takes from it, from an occasion's meal (the feast), from a meal with a batch
    cooked or at the cauldron, or from fish already fetched or in hand.
  - **The meal that gave fish up** tops itself up again from what is free (THE CHOICE, unchanged).
- **The fishery** (`fishery.gd`):
  - `bind_spare_fish(spare, give)`.
  - `input_available_milli(input)`: what a batch may take, which for fish is the free fish plus the kitchen's beyond
    the next meal. Dry fish's refusal and its card use it.
  - `order_batch` first asks the kitchen for exactly what the free fish lacks (`_take_spare_fish`), then sets its food
    aside as before.
  - Only fish inputs ever ask, and unbound the fishery counts the free fish only.
- **The village** (`demo_village.gd`, one call in `_build_fishery`) binds the kitchen's two functions to the fishery.

`kitchen.gd` is also the FEAST lane's (#239). The change there is three new functions in a section of their own,
touching no existing line.

## Tests

- `test_demo_kitchen.gd`, with every planned meal holding fish:
  - the rack may take only what the meals beyond the next one hold;
  - giving it up takes the latest fish meal's first, never more than is beyond, and never the next meal's;
  - the kitchen's revision moves;
  - an occasion's meal keeps its fish.
- `test_demo_preserve.gd`, with the kitchen's side as Callables over a real take:
  - 1 U free and 3 U beyond the next meal make a batch, the kitchen is asked for exactly 3 U, and the batch holds 4 U;
  - free fish enough asks nothing;
  - one milli-U short in all is refused NO_FISH and asks nothing;
  - unbound counts the free fish only;
  - a fruit batch never asks for fish.
- Mutation: 8 mutants, 8 killed:
  - the release order;
  - `>` as `>=` for the next meal;
  - the occasion guard;
  - the revision;
  - the spare in the count;
  - the exact amount asked;
  - the order not asking;
  - the fish-only filter.
  The revision and the fish-only filter first survived; an assertion was added for each.

## The measurement

One staged provisioning rerun, 3 seeds, is in the report's follow-up section ("Fish for the rack").
