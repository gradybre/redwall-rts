# 1737 — A preserving or brewing batch holds its water from the order until its work starts
Date: 2026-10-07 · Status: Accepted (the fix); its limit is recorded

## The fix

- **The bug.** Found in the balance rerun's review (decision 1731) and assigned by the coordinator with the 2026-10-07
  rulings. `fishery.gd batch_refusal` checked the butt's water but `order_batch` did not reserve it, so two batches in
  one morning could be ordered against the same water. The second was then given up when its work began.
- **The fix.** `water_held_milli()` is the recipe water of every live rack or station batch (KIND_DRY, KIND_BATCH) not
  yet started. A batch's water refusal checks the butt **less that hold**, and says so: "… and 2.0 U of it is set aside
  for batches already ordered". The hold is computed from the jobs, so it cannot drift, and a batch that starts (taking
  its water) or is cancelled releases it.
- **The card.** The batch card's water cost shows what is free after the hold.
- **Unchanged.** The check when a batch starts, which compares the butt with the batch's own water.

## The limit (recorded, not fixed)

- **Only the fishery's own orders see the hold.** The kitchen's cooking and the feast's infusion draw on the butt by
  their own rules (the regatta keeps a `water_held_milli` of its own).
- **Why.** A store-wide reservation belongs in `demo/tunnel/tunnel_stores.gd`, which is the digging lane's file and is
  not edited here.
- **What can still happen.** If the kitchen draws the butt down between a batch's order and its start, the batch is
  still given up when it starts, as before.

## Tests

`test_demo_balance_tuning.gd`:
- the hold counts ordered batches and not started ones, a recipe without water, another job kind, or a cancelled job;
- with one mead held, a second is refused NO_WATER one milli-U short, with the words, and is allowed at the full
  amount.
