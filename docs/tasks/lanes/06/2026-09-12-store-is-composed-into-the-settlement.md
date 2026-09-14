# 2026-09-12 — the store is composed into the settlement

Task: 06_buildings_rooms_logistics.md
Date: 2026-09-12


[Decision 0087](../decisions/0087-the-building-store-is-composed-and-the-two-inventory-split-is-not-on-master.md)
makes the call 0080 named and did not make: `settlement_system.gd` constructs
`Buildings.new(_directory)` over the settlement's one directory, clears it with the
other stores, and publishes `buildings()` / `building_definitions()`. A placed bed
now takes a real resident as its `user`, `live_furniture_of_kind(bed)` is a live
readable counter for UI §1.1's `Beds`, and `base_store_g_of()` states the 400000 g a
stockpile-owned container should carry — which is asserted to equal, four times over,
`economy_system.gd`'s §5.9 material-store mass.

**06.1 still stays unchecked, and the §7.2 starter settlement is NOT built.** A
generated settlement holds 0 buildings, 0 rooms and 0 furniture, which a test now
pins so composition is never mistaken for construction. 0087 itemises the five
blockers: no owner for the starter build, no store for §5.11's starting unlock mask
(the value 1 is authored; `World.milestone_mask`/`Progress.unlocked_mask` have no
owning module), no room-validity declaration, no defined edge-furniture
representation for §5.9's x4/x5 partition and its row-4 door, and no composed
`gear.gd` or building-owned container creation.
