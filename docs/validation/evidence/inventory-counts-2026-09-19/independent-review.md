# Independent source review — INIT-COUNT-R01 v2 read-only stock counts

Scope: `godot/scripts/core/inventory.gd` (`StockCounts`, `copy_stock_counts_into` and its
three private helpers) and `godot/test/test_inventory_stock_counts.gd`, read against
`inventory_stock_counts_contract.md` v2 and the Astra counts-review disposition. No source
was edited. Activation, consumer wiring, seed stock, Economy and the INIT-0 UI/simulation
split are out of scope and were not assessed.

**Verdict: accept for merge.** Four non-blocking notes follow. No defect was found that
would need a repro or a remedy.

## Contract consumption

**Output and interface.** `StockCounts` is a nested caller-owned RefCounted with exactly the
four public arrays named by the contract, each resized to `ITEM_CAPACITY` and zero-filled
once in its own `_init()`. It constructs no Inventory, lot, container, catalog or resident.
`copy_stock_counts_into(target, out) -> bool` returns `out.ok`; on success `out.value` is the
count of live rows folded, not a quantity.

**Publication is field replacement, not element copying.** On success the four target fields
are reassigned from four independent staging buffers built by the call. This is the point
the disposition reserved for source review (B5 rejected as proposed), and it is implemented
as specified: because the staging buffers are freshly allocated and mutually independent,
the four assignments are correct irrespective of whether the caller supplied four correctly
sized fields sharing one buffer, and success separates them. `StockCounts` declares plain
`var` fields with no setters, and the class emits no signal, so there is no callback, `await`
or observer between the four assignments. An older reference a caller retained is an older
snapshot; no stability of a prior allocation is promised, and the method docstring states
this in the same terms as the contract. No `duplicate()` is taken or needed.

**Callback-free read.** The only collaborators reached are `is_container_valid()` — the
existing pure predicate the contract names — and `IntMath.checked_add_into`, which writes
only the caller-supplied scratch. `_attests`, `_audit_lot_placement`, `audit()`, the seed
expiry authority and every diagnostic-writing helper are absent from the call graph. The
UncalledAuthority witness in evidence item 2 corroborates this at runtime.

**No owner writes.** The read does not call `_enter`/`_leave`, so it cannot open, poison or
journal a transaction. It uses a call-local `StockCounts` and a call-local
`IntMath.IntResult` rather than `_math`, `_plan`, `_out_ref` or `_out_value`; it does not
touch `_canonical_detail`, `_attesting`, the scan hints or the conservation ledger. The
explicit `_tx_poisoned` term in the BUSY predicate is redundant in practice (poisoning is
cleared as the transaction closes, so it implies `_tx_open`) but is the contract's own
wording and is correctly defensive.

**Refusal precedence.** Checked in the contract's order: `target == null` short-circuits
before any field is read, then any field length other than `ITEM_CAPACITY`, both SHAPE; then
`_tx_open or _tx_poisoned or _j_count != 0 or _attesting`, BUSY; then `_l_slot_high_water`
outside `0.._l_capacity`, STATE. `>` rather than `>=` against capacity correctly admits a
high-water mark equal to capacity. Then exactly one ascending pass. Occupancy 0 rows are
skipped without inspection, so free stale payload is ignored; any other occupancy is STATE.
Per row the order is item id in range and registered, positive lot generation, positive
quantity, reservation within `0..quantity`, then placement. Validation of a row precedes its
accumulation and accumulation precedes the next row's validation, so an earlier OVERFLOW
refuses before a later malformed row is reached, exactly as the disposition accepted under
B4 and as the test pins. Every refusal returns before the first target assignment, so a
refusal is atomic by construction and leaves the caller's record and all owner state
unchanged.

**Placement and totals.** A null container slot classifies as equipped and additionally
requires null container generation, null next and previous links and zero reservation; any
other container slot must form a complete ref accepted by `is_container_valid`. Every live
row adds quantity to `live`; equipped rows add to `equipped` and return, loose rows add to
`loose` and `quantity - reserved` to `unreserved_loose`. All four sums use
`checked_add_into`; there is no wrap, saturation or float anywhere in the path. `live ==
loose + equipped` and `0 <= unreserved_loose <= loose` therefore hold per item by
construction.

**Restored and uncatalogued stores.** `restore_canonical_columns` leaves `_item_registered`
alone, so a restored store before recataloguing has unregistered live rows and refuses
STATE, which is the contract's explicit requirement and the reason no count can be published
during world load. Its own precondition (`_tx_open or _j_count != 0 or _attesting`) is
unchanged by this packet and remains sufficient: poisoning cannot outlive the transaction
that caused it, so the omitted `_tx_poisoned` term is subsumed by `_tx_open`.

## Evidence review

The eleven focused tests map onto the contract's seven evidence obligations. The real Gear
path is genuinely real: an `item_definitions` catalog, a `Gear` store bound through
`bind_equipment` to the inventory and a spawned resident directory, `MANUFACTURE_BASIC`,
then equip, destroy of the now-empty former container, a count, and unequip into a different
container. Totals move loose to equipped and back over one preserved lot, `live_lot_count()`
stays 1, and `gear.state_bytes()` is unchanged across the read. Cleanup releases the
inventory to gear authority edge with `set_equipment_authority(null)`, which is the only real
ownership cycle the suite creates — the UncalledAuthority holds no back-reference and the
ReentrantAuthority holds a `WeakRef` — so the cycle release is both correct and sufficient.

Fault injection is confined to tests and writes private columns directly; the disposition's
Godot 4.7.2 probe finding (shared fields observe element writes) is consistent with these
tests taking effect, and is the same engine behaviour that makes field replacement, rather
than element copying, the correct publication strategy. INT64 boundary, true sum overflow,
overflow-before-malformed-row, retired and reused generations, order independence, aliased
and repopulated targets, stale success clearing, and the hostile reentrant read during a live
`_attesting` window are all covered.

## Notes (non-blocking)

1. Docstring typo in `copy_stock_counts_into`: "biconditual" for "biconditional". Source not
   edited here; fold into any later touch of the file.
2. Evidence item 7 asks for an authority whose predicate throws or asserts if called. The
   test uses a call counter asserted to be zero. This is a deliberate and arguably better
   substitute in GDScript, where an assert would abort the run rather than fail one case,
   but it is a documented deviation from the contract's wording.
3. `_private_bytes()` compares scan hints, diagnostics, transaction flags and cleanup,
   journal count and arrays, `_math`/`_plan`/`_out` scratch and `_attesting` as one aggregate
   image rather than as separate assertions. Coverage is complete; only failure diagnosis
   granularity is reduced.
4. The focused log ends with 275 leaked ObjectDB instances and 5 resources still in use.
   Nothing in this packet's own fixtures accounts for them and the packet releases its one
   cycle, but the parent should compare against a baseline focused run before treating the
   number as unchanged.

## Explicit non-promises confirmed

The counts certify Inventory-local structural invariants only. They do not attest the
Gear/Directory equipment biconditional, intrusive-list membership, cached container mass,
conservation or full-world legality; those remain the obligations of `audit()` and the load
coordination. Unreserved loose stock asserts no reachability, readiness, shelf life or legal
claimability. Both the module docstring and the method docstring say so without overclaiming.
This is a cold presentation and capture API; a consumer must coalesce reads and measure its
own refresh budget, and no such consumer is authorised by this packet.
