# 0162 — Restore storage-aging order and hour latch exactly

Date:2026-09-19 · Status:Implemented; independent review accepted; exact-head CI pending

[SAVE-AGE-R01v2](../planning/stock_age_columns_contract.md) publishes StockAge's
existing4packed columns and2scalars, plus a separate single-OwnerRecord adapter.
Actual waste-expiry probing demonstrates why order is canonical: declarations
[2,1] give next lot slots[0,1], while sorting them gives[1,0]. Preserve stale
declarations until normal sweep, exact count/list order and the existing latch.

Keep structural latch domain>=-1 and section7schema3/owner1 unchanged; stronger
clock/latch/fault validity remains coordinator work. Restore binds before install,
checks a supplied held clock barrier in the adapter, duplicates incoming arrays
and invalidates exactly2compiled item caches. Existing operational diagnostics
and scratch stay intact; a new column-refusal scalar is category3 only.

Use unique StockAge column method names, total local block-shape checks and
private staged publication without a codec-owner preload cycle. No full Inventory
or6owner snapshot is allocated by this adapter. Other I1owners and full-world
rollback/stock fault policy remain open.
