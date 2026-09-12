# 0090 — Expired seed converts to compost by floored nominal mass, per lot

Date: 2026-09-12 · Status: **Accepted**

[STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md) closes gap 3 of
decision [0085](0085-stock-aging-runs-hourly-and-declares-its-store.md): the
seed → compost quantity GDD §5.8 left unstated is now specified, so
`godot/scripts/core/stock_age.gd` converts instead of refusing. This record fixes
the judgements that implementation required and names, precisely, what it did not
build.

## Decision

1. **The divisor is derived, never written.** The yield is
   `floor_div(checked_mul(seed_quantity_milli, seed_mass_g), compost_mass_g)`
   with **exactly one final floor**, over the two masses read from the registered
   item catalog. The literal `10` appears nowhere in `stock_age.gd`.
   `floor(q_milli/10)` is what that expression currently *evaluates to* — all
   five seed items are 100 g/U and compost is 1000 g/U — not what it computes.
   `test_the_catalog_masses_still_make_the_expiry_divisor_exactly_ten` pins the
   current value from the catalog side, so editing a seed mass or compost's mass
   **fails a test** rather than silently re-pricing every expiry.
2. **One floor, over the milli-gram product.** Dividing the masses first and
   multiplying after agrees on every multiple of ten and disagrees on 1, 9 and 19
   — which is exactly why the ruling tabulates those three rows. The product is
   milli-units × grams-per-unit = milli-grams; the quotient is milli-units of
   compost.
3. **Per lot, and never per aggregate stack.** `_convert_expired_seed()` is
   called once per expiring row and reads only that row's quantity. This is what
   makes `sum(floor(q_i·sm/cm)) <= floor(sum(q_i)·sm/cm)` hold: splitting a seed
   stack can only lose compost. Applying the floor to a container's total would
   hand a split stack a unit it did not earn, and merging unrelated lots to
   recover a remainder is forbidden by the ruling.
4. **The remainder is decay loss, and it is ledgered rather than dropped.** The
   **entire** seed quantity is sunk and only the floored compost quantity
   sourced, through `inventory.gd`'s existing `transform_lot_item()`. `audit()`'s
   per-item `live + sunk == sourced` therefore still closes on both items while
   the missing nominal mass is visible as the difference between the two
   ledgers. `HourResult.seed_decay_loss_milli_g` reports the remainder in
   milli-grams **for the hour just run**; it is a report, never a store, because
   STOCK-SEED-R01 forbids an authoritative mass-remainder field and forbids
   carrying a remainder across lots or hours.
5. **Zero output retires the seed.** A lot whose yield floors to zero is sunk for
   its whole quantity via `sink_lot_quantity()`, which retires the row. No
   zero-quantity compost lot is created and no row lingers at zero holding a slot
   against REQ-SET-120's 16384-lot cap.
6. **Both branches are one atomic inventory transaction.** Reservations are
   released and the lot transformed or sunk inside a single
   `begin()`/`commit()` pair, per decision 0059. A refusal at any step leaves
   every collaborating store byte identical and is counted in
   `refused_lots` / `last_lot_refusal`; it does **not** abort the rest of the
   hour, because one unconvertible lot is not a reason to leave every other lot
   unaged.
7. **Refusal, not a plausible number.** Non-positive catalog masses, a
   non-positive quantity, and an int64 overflow of the product all refuse with
   `SEED_COMPOST_YIELD_UNREPRESENTABLE` and a zeroed value channel. Saturating
   the overflow would create matter out of arithmetic.

## Why the reserved-lot ordering is what it is

`inventory.gd`'s `_check_transform()` refuses `LOT_HAS_RESERVATION`, so the
release is not cosmetic: without it inside the same transaction, an expired seed
lot under a sowing claim would stay seed forever. Releasing first and
transforming second, inside one transaction, is the only ordering that satisfies
both the ruling's "atomically invalidates/releases the lot's reservations" and
the store's own precondition.

## What this did NOT implement

Both are named in the module header as numbered gaps and are **not** closed:

- **The seed-consumer eligibility guard is supplied but unenforced.**
  STOCK-SEED-R01 requires every seed-consuming path to reject a lot whose age has
  reached its shelf threshold, and gives *enforcement* to Inventory ("Inventory
  owns enforcement for quantity admission"). `inventory.gd` is another owner's
  file. What landed here is the predicate itself,
  `StockAge.refuses_seed_consumption()` — derived from persisted age and the item
  definition, no new per-lot flag, **fail-closed** so a lot it cannot evaluate is
  never admitted. **Nothing calls it.** No seed consumer in this repository is
  guarded today.
- **The blocking critical-pause and exactly-once retry are not built.** The
  ruling routes arithmetic/ledger/schema failure through "the existing
  critical-pause path" with a revalidated retry of the same expiry transaction.
  That path belongs to ARCH-SYS-001 / `settlement_system.gd`, which calls this
  stage. This module counts and names the refusal with the store left byte
  identical and invents neither a pause nor a retry ledger.

Continuation through the real hourly caller and across save/reload, and the
starter-economy integration, remain exactly as open as decision 0085 left them.

## Consequences

- `HourResult.unconvertible_seed_lots` and
  `REFUSE_SEED_RATIO_UNSPECIFIED` are **removed**: the quantity they existed to
  refuse is now specified, and keeping a refusal nobody can trigger would be a
  lie about what the module does. They are replaced by `seed_lots_converted`,
  `seed_lots_retired`, `seed_sunk_milli`, `compost_sourced_milli` and
  `seed_decay_loss_milli_g`. No caller outside `stock_age.gd` read either.
- A converted seed is counted in `lots_expired` as well as
  `seed_lots_converted`, because its row expired into another item. A retired
  zero-yield seed is **not**, because no row survived the hour to have become
  anything.
- **No packed column was added or changed**, so no memory-ledger row moves:
  `docs/systems_architecture.md` §2.2/§2.3 and the ARCH-MEM-009 trail are
  untouched, and `docs/persistence_state_registry.md` gains no row. The two new
  cached ints (`_compost_id` alongside `_spoiled_food_id`) are derived catalog
  ids re-resolved on every bind, not state.
- A future seed item with a mass that does not divide compost's is **legal**: the
  single floor handles it and the remainder becomes decay loss. What is not legal
  is a zero or negative mass, which refuses.

## Source

- [STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md), and the
  "Expired seed quantity" row of
  [the executor follow-up](../rulings/2026-09-12_executor_followup.md).
- GDD §5.8 (shelf life, aging, expiry outcomes) and §5.7 / the item table for the
  catalog masses, via `godot/data/item_definitions.json`.
- Decision 0059 (allocate before consume), decision 0085 (gap 3), decision 0061
  (equipped lots), REQ-SET-108 and REQ-SET-120.
