# 1733 — The cordial is poured at every supper as a table drink, and keeps 240 h
Date: 2026-10-07 · Status: Accepted

## The ruling

Brendan, 2026-10-07, on the balance rerun's P2 (decision 1731): **both (a) and (c)**, "Approve both and have cordial
keep longer as well". Relayed by the coordinator.
- (a): the cordial is poured at ordinary suppers as a table drink;
- (c): its shelf goes from 72 h to 240 h.

The evidence: all of it spoiled (48–56 U a year), because it kept 72 h and was poured only at the regatta's feast.

## Decision

- **(c) The shelf.** `farm_catalog.gd GOODS_SHELF_HOURS` (the cordial's entry) and `dish_book.gd`'s `cordial` row both
  go to 240 h. A test pins the two together (`test_demo_brew.gd`).
- **(a) The table drink** (`godot/demo/kitchen/table_drink.gd`, ticked by `demo_kitchen.gd` after the kitchen):
  - **When.** It reads the kitchen's published meal events (`finals`, by serial, as `people_taps.gd` does), so the
    kitchen gains no hook.
  - **How much.** At each ordinary supper somebody ate, it pours ceil(diners/4) U of cordial nobody has set aside,
    soonest-spoiling first. That is the feast's measure (`regatta_menu.gd drink_need_milli`).
  - **What it skips.** Breakfast pours nothing. An occasion's supper (the feast) pours its own drinks: the occasion's
    meal is noted while `occasion_key` is set, so the feast is still known if the occasion is cleared before its event
    is published.
  - **What it does.** A drink has no NP and no effect (DEC-007; 1621 P4). The books: `poured_milli`, `pours`,
    `dry_suppers`.
- **The words.** `preserve_text.gd`: the guide's CORDIAL_USE ("A table drink: poured at every supper …") and the card's
  "poured at supper and at feasts".

## Tests

`test_demo_balance_tuning.gd`:
- the shelf in both tables, and the words;
- the measure at its boundaries (0, 1, 4, 5 and 9 diners);
- a supper pours once and a breakfast never does;
- a feast's supper (its occasion already cleared), an empty supper and earlier events pour nothing;
- only free cordial is poured, and a supper with none free is counted dry.
