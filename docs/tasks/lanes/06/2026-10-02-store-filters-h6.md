# 2026-10-02 — H6: store filters, store minimums and the shared instance allocator

Task: 06_buildings_rooms_logistics.md (06.4; REQ-SET-117)
Date: 2026-10-02
Decision: [1031](../../../decisions/1031-store-filters-and-minimums-are-a-building-keyed-arena.md)

- **`store_policy.gd` holds §3's BuildingItemAllow and BuildingItemMinimum.** The arena is
  262144 cells, keyed by Building row times item id. A per-building persistent-ID stamp adds
  4096 B, so a reused row inherits nothing.
- **`store_admits(container, item) -> bool` is the read-only "filters admit" query for
  destination selection.** It answers the category mask AND, for a main store, the building's
  per-item byte, and it allocates nothing.
- **`ordinary_withdrawable_milli()` is the minimum's floor for ordinary production.** Emergency
  meals do not ask it.
- **SET_STORE_FILTER and SET_STORE_MINIMUM commit through `command_dispatch.gd`.** Each takes a
  building target and count-first ascending item rows, and the group is atomic.
  `bind_store_policy()` attaches the store.
- **The shared instance allocator is ARCH-STATE-007's GearInstance pool.** It is already
  implemented in `gear.gd` (decision 0038), so nothing new was needed.
- **Not composed yet.** `settlement_system.gd` was outside this lane, so live play refuses both
  kinds with COMMAND_STORE_NOT_BOUND until it builds and binds the store.

Decision 1031 records eight proposals (P1–P8). Every reset or load path must also call the store's `clear()`, because the stamp's persistent IDs restart with the directory.

No checklist box closes: 06.4's hauling, reservations, recovery, gear swaps and EQUIP remain.
