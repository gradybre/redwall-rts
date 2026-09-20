# INIT-0 inventory authority — gap audit (advisory)

Date 2026-09-19 · baseline `47a4da2` · read-only. No source was edited, nothing was run,
no activation or PC acceptance is claimed. Evidence is the supplied excerpt set
(`source-excerpts.json`, sha 0be1d1d6…) plus the four full files in the packet inputs.
**Excerpt absence is not proof of absence:** `ui_manager.new_settlement`,
`ui_world_session.generate/create/reset`, all of `stock_age.gd`, `gear.gd`,
`residents.gd` and the non-excerpted parts of `inventory.gd` were not shown; every
claim below about them is stated as *not shown* and must be re-checked by the owner.

## 1. Observed divergence

- `main.gd::_ready` → `EconomySystem.reset()`, `SettlementSystem.reset()`,
  `_seed_stores()`, `_generate_initial_world()`.
- `_seed_stores()` deposits `STARTING_INVENTORY_U` (wood 180 U = 180000 milli, berries
  40000, tool 24000, …) into **EconomySystem's private `_inventory`**
  (`var _inventory := InventoryScript.new()`, opened into `_pantry` /
  `_material_store` by `_open_stores()`).
- `SettlementSystem._compose_stock_layer()` builds a **second** `Inventory` and a second
  `ItemDefinitions`, and binds `StockAge` to that pair. Nothing seeds it.
- `UIManager._refresh_counters()` reads Wood/Stone/Ready NP/Food-days from EconomySystem.

So the screen shows 180 U wood against a simulation-authoritative store holding zero
lots, and aging/expiry (`StockAge`) operates on the empty store. This is the defect
INIT-0 exists to remove; it is a genuine divergence, not a naming difference.

## 2. Mutator / reader inventory (visible surface only)

Production **mutators** of stock state reachable from boot or UI:

| Caller | Call | Effect on a borrowed store |
|---|---|---|
| `main._ready` | `EconomySystem.reset()` | clears store **and** reloads catalog into it |
| `main._seed_stores` | `EconomySystem.deposit(key, milli)` ×20 | creates containers' lots |
| `main._exit_tree`, `_generate_initial_world` | `bind_residents(null/…)` | borrowed-ref only, benign |
| `main._ready` | `SettlementSystem.reset()` | `_clear_stock_layer()` clears + reloads catalog, steps generations |
| `main._generate_initial_world` | `SettlementSystem.create_generated_settlement()` | internal `reset()` inside `_run_initialization_transaction` |
| `ui_world_session.create_with_cohort_into` | `reset.call()`, `cohort.call()`, `publish_prepared()` | clears stores mid-attempt |
| (not shown) | `EconomySystem.withdraw`, `recompute_summary` | callers outside excerpt |

**Readers** that must survive cutover: `stock_milli`, `stock_units`, `available_milli`,
`ready_nutrition_points`, `food_days_centi/_text`, `daily_demand_np`, `fuel_days_text`,
`store_used_mass_g`, `pantry()`, `material_store()`, `inventory()`, `definitions()`,
`is_known_item`, `item_count`, `catalog_error`, `last_refusal`, and
`UIManager._refresh_counters` / `_on_stocks_changed`.

## 3. Actual contradictions blocking a naive borrow

1. **Constructor allocation.** `EconomySystem._init()` calls `reset()`, which does
   `InventoryScript.new()` + catalog load + two `create_container` calls. As an autoload
   this is exactly the transient production-sized allocation the ruling forbids. A
   borrowed projection cannot simply overwrite `_inventory` afterwards.
2. **`reset()` writes through the borrow.** Its body is `clear()` + catalog reload +
   `_open_stores()`. Performed on a borrowed store it destroys the owner's lots and
   re-registers the owner's catalog — three prohibited writes in one method.
3. **Two-container totals.** `available_milli`, `_recompute_summary`, `_store_for` and
   `withdraw` are hard-wired to `_pantry`/`_material_store`. Under settlement ownership
   the real stores are INIT-C/D's four stockpiles, five shelves and equipment lots, so
   these readers would under-report. They must become whole-store queries.
4. **Stale refs across reset.** `_clear_stock_layer` steps both generation spaces, so any
   cached container ref in the projection silently invalidates. The projection must hold
   **no** container refs, or hold an epoch and refuse on mismatch.
5. **Ordering makes boot stock unreachable.** `_seed_stores()` runs *before*
   `create_generated_settlement()`, whose transaction resets again. Moving the seed into
   the shared store without moving it after publication erases it (the manifest already
   records this). Therefore a read-only borrow at boot legitimately reports **zero loose
   stock** until INIT-D admits real containers. Zero-because-empty must render as a real
   zero; only *unbound* renders unavailable. Do not paper over this with a projection write.
6. **Catalog identity is triple.** Settlement loads one `ItemDefinitions` into its
   inventory, EconomySystem loads another into its own, `ui_world_session._open_catalog`
   loads a third against a private `Inventory`. Compiled ids are only guaranteed equal by
   construction, not verified. A projection must borrow the **owner's** `definitions()`
   instance and be able to prove it is the one registered into the borrowed store.
7. **Summary freshness vs aging.** `_recompute_summary` runs only on Economy-committed
   change. Once `StockAge.run_hour_into` advances ages in the borrowed store, `_is_expired`
   flips and ready NP changes with no notification, so the HUD holds a stale figure. REQ-SET-119's
   hourly half becomes mandatory, not optional, after cutover.
8. **Failed-attempt restoration is out of scope.** `create_with_cohort_into` calls
   `reset.call()` *after* preflight; a later cohort/publish refusal leaves the stores
   already cleared. "Failed preparation leaves prior quantities intact" is therefore not
   achievable in INIT-0 and depends on ARCH-MEM-006 disk rollback (INIT-C/D/E). Do not
   claim a borrowed projection fixes it.

## 4. Source gaps (not-shown, must be supplied before design closes)

- No **all-container enumerator** was supplied. Only `containers_by_owner_into`
  (directory-owner filtered) and the `container_first_lot`/`container_next_lot` chain are
  visible. Whole-store summaries (live / loose / equipped / unreserved / ready NP) need an
  owner-agnostic live-container or live-lot walk. `total_live_milli` /
  `total_equipped_milli` / `total_loose_milli` exist but are documented **diagnostic**
  linear scans, per item id.
- No **epoch / generation counter** accessor on `Inventory` is shown for detecting `clear()`.
- No accessor proving which `ItemDefinitions` instance registered a given `Inventory`.
- `stock_age.gd` (`declare_storage_class`, `run_hour_into`) and `residents.gd`
  (`daily_demand_np`) bodies were not shown; hour-boundary hooks are assumed, not proven.
- Container/lot capacities are only reachable via `canonical_capacities()`; the concrete
  numbers were not shown, so the memory figure below is a formula, not a measurement.

## 5. Smallest bounded packet that materially enables cutover

**INIT-0a — read-only borrowed projection + owner-side primitives.** It contains no
seeding, no container creation, no activation. Two owners:

### 5a. Inventory owner adds (read-only, no behaviour change)

```gdscript
func live_container_count() -> int
func live_containers_into(out_pairs: PackedInt32Array, out: IntMath.IntResult) -> bool
#   flat slot,generation pairs in ascending slot order; refuses
#   OWNER_OUTPUT_TOO_SMALL writing nothing, mirroring containers_by_owner_into
func store_epoch() -> int            # monotonic; incremented by clear()
func registered_catalog_token() -> int  # set by register_item(); 0 when unregistered
```

### 5b. EconomySystem gains (and only these mutate EconomySystem's own fields)

```gdscript
func bind_stock(store: InventoryScript, catalog: ItemDefinitionsScript) -> StringName
func unbind_stock() -> void
func is_stock_bound() -> bool
func bound_epoch() -> int
func refresh_summary(reason: StringName) -> StringName
func stock_totals_into(item_key: StringName, out: StockTotals) -> bool
func settlement_summary_into(out: StockSummary) -> bool
```

Output records (plain `RefCounted`, caller-owned, reusable, no per-call allocation):

```gdscript
class StockTotals:   # one item id
    var ok: bool; var error: StringName; var epoch: int
    var live_milli: int; var equipped_milli: int; var loose_milli: int
    var unreserved_milli: int

class StockSummary:  # whole store
    var ok: bool; var error: StringName; var epoch: int
    var containers_scanned: int; var lots_scanned: int
    var ready_np: int              # unreserved, unexpired, raw-edible, non-seed
    var live_np: int               # same filter, reserved included
    var used_mass_g: int
    var refreshed_at_hour: int     # source of freshness, -1 when never
```

Refusal codes (new, all `StringName`): `STOCK_UNBOUND`, `STOCK_EPOCH_STALE`,
`STOCK_CATALOG_FOREIGN`, `STOCK_CATALOG_UNAVAILABLE`, `STOCK_ENUMERATION_UNAVAILABLE`,
`STOCK_REFRESH_IN_TRANSACTION`, `STOCK_SUMMARY_STALE`.

**Unavailable ≠ zero.** While unbound, `stock_totals_into` / `settlement_summary_into`
refuse `STOCK_UNBOUND` and `food_days_text()` / new `stock_text(key)` render `"--"`.
The legacy `stock_milli()/stock_units()/available_milli()` int-returning readers cannot
express this and must be retired in the same packet (callers: `UIManager._refresh_counters`
Wood/Stone) rather than left returning a lying 0.

**Refresh atomicity.** `refresh_summary()` refuses `STOCK_REFRESH_IN_TRANSACTION` when
`store.is_transaction_open()` or `store.is_transaction_poisoned()`; it never opens a
transaction, never writes, and publishes the new `StockSummary` by whole-record swap so a
reader never observes a half-updated figure. It stamps `epoch` from `store_epoch()` and
`refreshed_at_hour` from the caller-supplied hour. Callers: once after a committed stock
mutation by the owner, and once per stock hour after `StockAge.run_hour_into` (contradiction 7).

**Binding lifetime.** `bind_stock` refuses `STOCK_CATALOG_FOREIGN` unless
`catalog.is_loaded()` and its token equals `store.registered_catalog_token()`. Exactly one
`bind_stock` per successful publication, invoked by the integration owner after the single
reset+seed, never from `_init()`. `_init()` must leave the system **unbound with no
`Inventory` allocated**; legacy fixtures call an explicit
`bind_stock(own_store, own_catalog)` on an inventory they construct themselves.

**Budget.** One `PackedInt32Array` scratch sized `canonical_capacities().x * 2` allocated
once at first `bind_stock` and reused; two record instances; no second `Inventory`, no
per-call allocation, no reverse index. Cost per refresh is one pass over occupied
containers plus one pass over their lot chains — same order as today's two-container walk,
scaled by real container count; keep `total_live_milli`'s per-item scan off the tick path.

## 6. Alternatives rejected

- **Settlement borrows EconomySystem's store.** Rejected: `StockAge`, the catalog load and
  the single-reset contract all live on the settlement side; inverting ownership moves the
  reset problem rather than solving it, and leaves an autoload owning simulation state.
- **Synthetic directory owner for stock containers, enumerated via
  `containers_by_owner_into`.** Rejected: fabricates a container owner that no INIT-C/D
  building will match, and silently drops equipment lots (`container_slot == NULL_SLOT`).
- **Keep the two Economy containers as a shadow of the settlement stores.** Rejected:
  duplicates lots, the exact defect INIT-0 removes.
- **Cache `pantry()/material_store()` refs post-bind.** Rejected by contradiction 4.
- **Have the projection seed the borrowed store when it finds it empty.** Rejected: a
  projection write, and it would double-seed after INIT-D lands.

## 7. Explicitly out of scope here

Physical container creation, gear/equipment admission, rebinding after a *replacement* of
an existing valid world, and any disk rollback. Those remain INIT-C/D/E and ARCH-MEM-006.
INIT-0a delivers only a truthful, non-allocating, read-only view plus the refusals that
make the remaining gaps visible instead of rendering them as zeros.
