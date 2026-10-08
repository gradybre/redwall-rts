# 1734 — Ordering a drink warns when the stores already hold two feasts' worth of it
Date: 2026-10-07 · Status: Accepted

## The ruling

Brendan, 2026-10-07, on the balance rerun's P3 (decision 1731): **(a) + (b).**
- (a): the Harvest and Orchard feasts pour mead and cider. That is the FEAST lane's work.
- (b): the Brew order warns above two feasts' worth, 6 U a drink. That is this record.

The evidence: mead (36–44 U a year) and cider (4–16 U) piled up with nothing to pour them, and mead took 27–33 U of honey
a year that the residents would otherwise have eaten.

## Decision

- **The figure.** `preserve_rules.gd DRINK_STOCK_WARN_MILLI` = 6000: two feasts of the nine at ceil(9/4) = 3 U each.
  The ruling's 6 U is kept as it is, and is not rescaled with the population.
- **Which rows.** `is_drink(recipe)`: mead, the cordial, ale and cider (the USE_DRINK rows).
- **The words.** `fishery.gd drink_stock_warning(recipe)`. When the pantry already holds at least 6 U of that drink:
  "the stores already hold 8.0 U of mead, two feasts' worth (6.0 U): more will wait for a feast to pour it".
- **A warning only.** The order is never refused.
- **Where it shows** (`demo_fishery.gd`):
  - after the order's answer: "Brew mead: on the work board — …" (`batch_answer`);
  - on the order's card, after the result: "… Note: …". The card has no warning line of its own, and it keeps
    UI-SET-073's size.

## Tests

`test_demo_balance_tuning.gd`:
- at 6 U it warns, and 1 milli-U under it does not;
- every drink row warns, and no eaten or ingredient row does, however deep the stock;
- with no pantry there is no warning.

The frames are in decision 1738.
