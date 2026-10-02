# 0994 — Opening-stock provenance lives on the pantry's lots
Date: 2026-10-02 · Status: Accepted

From the range 0993–0999 assigned to the fixes of the independent review of 2026-10-02
(`docs/reviews/2026-10-02-codex-review.md`, branch `codex/review-2026-10-02`). This record answers its **R02** and
amends how decision 0902's ruling 2 ("A full larder" counts only food the village cooked or brought in) is measured.

## The finding

`opening_pantry.gd left_milli` inferred the opening stock still held as its 40 U / 50 U less **every** withdrawal and
spoiling of the item since, assuming the opening lots go first. They need not: the kitchen takes the lot that spoils
first (`ingredient_takes.gd`, decision 0381) and a lot's expiry depends on its store's rate (`farm_pantry.gd
lot_spoil_hours`). Opening carrots moved into a cool cellar (350‰) outlast a younger harvest in the warm covered store
(1000‰); cooking or spoiling that younger lot reduced the inferred opening balance while the opening carrots were
untouched, so the goal credited starter food as the village's own.

## The ruling

**Brendan, 2026-10-02:** "R02: track opening-stock provenance on the actual lots, preserved through split, transfer,
merge, consumption and spoilage, so 'A full larder' (decision 0902, ruling 2) counts correctly. Test an older opening
lot in a cellar against a younger harvested lot in a warm store, for both consumption and spoilage."

## Decision

- `farm_pantry.gd` keeps a packed column `_lot_opening` (milli-U of each lot that is opening stock; never more than the
  lot holds). `add_opening_into` is `add_into` that marks the quantity opening; `opening_milli_of(item)` sums it;
  `lot_opening_milli(lot)` and `opening_share(lot, milli)` read it.
- The share follows the actual food: a new lot (a delivery, `_open_lot`) has none; a full table's merge keeps the lot's
  share and adds the delivery's (none); a split -- a carry's or a set-down's -- moves the moved part's **proportional
  share, floored**, the rest staying; a withdrawal takes its proportional share the same way, all of it once the lot is
  emptied; a spoiled lot's share goes with it. Proportional-floored keeps the remaining share within the remaining lot
  (the ceiling of a value no larger than an integer is no larger than it). In practice a lot is wholly opening or wholly
  not -- only a full table merges a delivery into an opening lot -- so the share moves whole.
- `opening_pantry.gd stock` stores through `add_opening_into`; `left_milli` is the item's opening share still held,
  clamped to what the pantry holds. The ledger columns (decision 0451) are unchanged and no longer used for this.

## Tests

`test_demo_opening_pantry.gd`: the review's case built with the pantry's own move (decision 0611) -- opening carrots aged
a day then moved to a 350‰ cellar, 20 U of younger carrots in the 1000‰ covered store -- for **consumption** (the
kitchen's own `ingredient_takes.gd reserve_into`/`consume_into` takes the warm lot; all 50 U still count, where the
ledger would have said 48) and **spoilage** (the warm lot spoils; all 50 U still count; once the cellar lot spoils too,
none); a split carry moving its share exactly and a withdrawal taking its own; a delivery merged into the opening lot
sharing withdrawals proportionally, floored, with the share's boundaries.

## Consequences

Any new path that moves or removes lot quantity in `farm_pantry.gd` must move `_lot_opening` with it. No PROPOSAL.

## Source

Brendan's ruling of 2026-10-02 on R02; decision 0902 ruling 2; GDD §5.8 (lots, merge keeps the older age, stores never
reset age); REQ-SET-111 (exact splits without cloning lots).
