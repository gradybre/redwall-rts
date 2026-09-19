# Read-only whole-inventory stock counts

INIT-COUNT-R01 · version1 draft · 2026-09-19 · Astra

The actual UI/simulation inventory split remains an INIT-0 integration defect.
A safe projection needs whole-store totals without one lot scan per displayed
item or a fabricated two-container shadow. This packet adds only a bounded
read-only snapshot primitive to the existing Inventory owner. It does not bind
Economy, seed stock, change reset behavior, or claim that the running UI is fixed.

## Output record and public API

Nested `Inventory.StockCounts`, caller-owned RefCounted:
- live_milli: PackedInt64Array[ITEM_CAPACITY=256]
- loose_milli: PackedInt64Array[256]
- equipped_milli: PackedInt64Array[256]
- unreserved_loose_milli: PackedInt64Array[256]

Constructor allocates and zeros exactly these four arrays. No inventory, container,
lot, catalog, directory or resident is created by this record. Packed payload8192B.
No authoritative state, serialized field or canonical registry version is added.

`copy_stock_counts_into(target:StockCounts, out:IntMath.IntResult) -> bool`
reads all live lot rows once, bounded by the owner's existing lot high-water,
stages checked aggregates in one local StockCounts, and only publishes to target
after all checks pass. Return out.ok; success out.value is the number of live lots
counted. Refusal writes out false/0/error and leaves all target arrays byte-identical.
The Inventory itself is unchanged, including lots, reservations, generations,
conservation ledgers, transaction state and state_bytes() image.

This is a bounded cold presentation/capture read, not a new per-resident or
per-tick simulation operation. One target8192B plus one local staging8192B and
publication copy overhead must be recorded. No full canonical inventory snapshot
is allocated; no permanent scratch or reverse index is added. The future projection
owns refresh timing and should coalesce reads at committed boundaries, not scan
for each individual HUD label. This packet makes no latency/budget acceptance
claim before measurement in its actual consumer.

## Domain and classification

The four arrays are indexed by Inventory's already registered compiled item ID.
Every live lot contributes quantity to live. A lot whose container slot is null
is equipped; otherwise it is loose. The existing equipment-attestation rule and
complete container reference remain validation obligations; never infer actual
gear from a null slot on a corrupted record. Equipped quantity never contributes
to loose availability. For loose lots, unreserved = quantity - reserved. This
field does not assert reachability, readiness, expiry or legal claimability.
For every item, live=loose+equipped and0<=unreserved_loose<=loose.

No nutrition, shelf-life, item-key mapping, container mass or route calculation
belongs here. ItemDefinitions/StockAge and the future projection own ready NP and
freshness. Do not put catalog identity tokens or world epochs into Inventory as
an incidental part of this read-only task.

Validate before accepting each live row: registered item in0..255; quantity>0;
reserved in0..quantity; legal placement (valid complete container ref, or valid
existing equipped attestation with its required null generation/zero reservation).
Use existing owner predicates where they are pure; do not call audit() or a helper
that changes diagnostics, repairs rows or mutates collaborators. Checked i64 sums
must refuse overflow; no wrap, saturation or lossy float conversion. Free rows,
including retained stale payload, contribute nothing. Iteration is ascending lot
slot order; totals remain independent of allocation order.

## Refusal order and errors

Use new StringName constants in Inventory, converted to String for IntResult:
- REFUSE_STOCK_COUNTS_SHAPE = INV_STOCK_COUNTS_SHAPE
- REFUSE_STOCK_COUNTS_BUSY = INV_STOCK_COUNTS_BUSY
- REFUSE_STOCK_COUNTS_STATE = INV_STOCK_COUNTS_STATE
- REFUSE_STOCK_COUNTS_OVERFLOW = INV_STOCK_COUNTS_OVERFLOW

Precedence: target null or any array length not256 -> SHAPE; an open or poisoned
transaction, or existing _attesting guard -> BUSY; then row validation in ascending slot order -> STATE;
overflow encountered while accumulating a valid row -> OVERFLOW. No target
publication before all rows succeed. Caller-owned out must be a valid IntResult,
as with other existing _into APIs. These are diagnostic errors, not catalog enums.

The read is synchronous, contains no await, and callers may not invoke it during
cross-owner publication. It validates this owner's data; it cannot certify a full
world's reference graph, clock barrier or complete save consistency.

## Required evidence

1. Empty small-capacity Inventory yields four zero256-item arrays and counted0.
2. Multiple physical containers, separated slots and multiple lots of one item
   count once; reserved quantities affect only unreserved_loose.
3. Real Gear equip/unequip integration proves live=loose+equipped with one real
   inventory lot, no duplicated tool. Include a real equipped lot after its
   original container is emptied; it remains in live/equipped totals.
4. A destroyed/reused lot row contributes only the current generation once;
   retained free-row payload is ignored. Compare equivalent differently ordered
   allocations with identical item totals.
5. Target wrong shape, open/poisoned transaction, malformed live row/placement
   and checked-sum overflow all refuse without changing target or source bytes.
   Fault injection belongs only in tests; no public mutation hook is added.
6. Reuse a previously populated target, then empty/different stock, proving no
   stale totals survive a successful new snapshot. Out failure never leaks success.
7. Prove no observer signal, transaction, catalog load, entity allocation or stock
   mutation is caused by a read. Source and actual state_bytes comparisons support
   this scope; full-world rollback remains separate.

Before implementation, independently review exact existing placement predicates
and Gear fixture APIs. Ownership: inventory.gd and dedicated tests; parent handles
registry/memory notes and evidence. No Economy/UI/startup edits in this packet.
After focused/full suite, static gates and independent source review, it may merge
as an owner primitive. INIT-0 retains all remaining producer/binding/activation work.

## Source findings for independent review

The real Gear.is_equipped_record predicate is documented and implemented as a
pure read of gear and directory. Inventory._attests invokes it while temporarily
raising _attesting; _audit_lot_placement uses that guard and checks the placement
biconditional for BOTH loose and detached lots. It does not check the complete
container reference/null generation itself. This draft permits the existing
temporary guard if restored before return; it does not permit lasting owner or
collaborator mutation. BUSY must reject reentrant entry before another attestation.
No Inventory _math scratch value may be held across an authority callback; use
caller/local IntResult and consume checked values before the next callback.
Review whether this guarded callback surface is sufficient for the narrow
read-only promise, including which diagnostics state_bytes actually covers.
state_bytes excludes journal/high-water and does not prove all diagnostic fields
unchanged. Tests must separately compare relevant diagnostics and transaction
flags; do not describe that byte image as a complete diagnostic snapshot.
