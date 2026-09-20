# Read-only whole-inventory stock counts

INIT-COUNT-R01 · version2 accepted for bounded implementation · 2026-09-19 · Astra

The actual UI/simulation inventory split remains an INIT-0 integration defect.
This packet adds a bounded read-only count primitive to Inventory. It does not
bind Economy, seed stock, change reset behavior or fix the running UI.

## Output and interface

Nested `Inventory.StockCounts`, caller-owned RefCounted, has four public arrays:
`live_milli`, `loose_milli`, `equipped_milli`, `unreserved_loose_milli`.
Each is a separate zeroed PackedInt64Array of ITEM_CAPACITY=256:8192B in total.
The constructor creates no Inventory, lot, container, catalog or resident.

`copy_stock_counts_into(target:StockCounts, out:IntMath.IntResult) -> bool`
returns out.ok; on success out.value is the number of live rows counted.
It stages in one local StockCounts and uses local IntMath scratch only. A refusal
writes out=false/0/error and leaves all target fields and owner state unchanged.
A successful publication REPLACES target's four array fields with the four
independent staging buffers. Callers retain the record, then reacquire its fields
after success; an older field reference remains an older snapshot. No stability
of a prior field allocation is promised. This also supports a caller that supplied
four correctly sized fields sharing a buffer: successful output separates them.
There are no callbacks/await/signals between assignments or anywhere in this read.
No duplicate() is necessary when adopting the private staging buffers.

One existing target8192B plus staging8192B is the packed working payload. Caller
retention of older fields extends those allocations' lifetime. Scalar/RefCounted
headers and allocator overhead are additional; this is not RSS qualification.
No full Inventory snapshot, owner scratch member or reverse index is allocated.
This is a cold presentation/capture API, not a per-resident/per-tick simulation
operation. A consumer must coalesce reads and measure its actual refresh budget.

## Validation and scope

The owner must be at a completed boundary with its item catalog registered.
Validate _l_slot_high_water in0.._l_capacity before indexing; scan once ascending.
Occupancy0 rows (including stale payload) are ignored. Any occupancy other than
0/1 within that scan is STATE. For each live row, require item0..255 registered,
positive lot generation, quantity>0, reserved in0..quantity. Unregistered records,
including a restored store before recataloging, explicitly refuse STATE. A
zero-quantity live row also refuses: capture/restore acceptance alone does not
certify a fully composed gameplay store. No count is published during world load.

A null container slot classifies as equipped in Inventory's structural sense.
Require null container generation, next and previous links, and zero reservation.
A loose row must have a complete valid container ref checked by the existing pure
is_container_valid predicate. Counts certify these local structural invariants,
NOT the Gear/Directory equipment-attestation biconditional, intrusive-list
membership, cached mass, conservation or full-world legality. Existing audit/load
coordination retains those obligations. Never call _attests, _audit_lot_placement,
audit, a collaborator or a helper that writes diagnostic fields from this API.

Every live row adds quantity to live; null-container rows add to equipped and
others add to loose and quantity-reserved to unreserved_loose. All sums use
IntMath.checked_add_into. No wrap, saturation or float conversion. Thus for each
item live=loose+equipped and0<=unreserved_loose<=loose. Unreserved loose stock does
not assert reachability, readiness, shelf-life or legal claimability. Nutrition,
item keys, catalog identity and world epochs belong to future consumers.

## Refusals

New Inventory StringName constants, converted to String for IntResult:
- REFUSE_STOCK_COUNTS_SHAPE = INV_STOCK_COUNTS_SHAPE
- REFUSE_STOCK_COUNTS_BUSY = INV_STOCK_COUNTS_BUSY
- REFUSE_STOCK_COUNTS_STATE = INV_STOCK_COUNTS_STATE
- REFUSE_STOCK_COUNTS_OVERFLOW = INV_STOCK_COUNTS_OVERFLOW

Precedence: null target or any field length not256 -> SHAPE; _tx_open,
_tx_poisoned, _j_count!=0 or _attesting -> BUSY; invalid high-water -> STATE.
Then ONE ascending pass: validate each row (STATE), then checked accumulation
(OVERFLOW). An earlier overflow precedes a later malformed row. Caller supplies
a valid IntResult distinct from Inventory's private scratch; no null-out contract.
No writes to owner fields, including existing scratch, diagnostics, transaction
flags or the attestation guard. No new canonical state or schema version.

## Required evidence

1. Empty small Inventory produces four zero256-item arrays and counted0.
2. Multiple containers/items/lots/reservations; all four literal totals independently
   asserted, live=loose+equipped. Checked INT64 boundary and true sum overflow.
3. Real Gear tool/MANUFACTURE_BASIC, real spawned Residents owner, real binding and
   equip/unequip preserve one lot and all totals. Destroying its empty former
   container does not omit the equipped lot. Release the binding cycle in cleanup.
4. Retired/reused rows count only the live generation; free stale payload ignored;
   equivalent stocks created in differing orders yield identical arrays.
5. Target shape, each BUSY condition, invalid highwater/occupancy/item/registration/
   generation/quantity/reservation/container/null-placement refuse atomically.
   Fault injection test-only. Pin earlier overflow versus later malformed row.
6. Reuse populated target with changed/empty stock: no stale totals. Prior held
   array references retain old values; deliberately aliased target fields are
   separated by success. Out stale success is cleared by refusal.
7. Source state_bytes equal before/after; separately compare scan hints, diagnostics,
   transaction flags/cleanup, journal count/arrays, _math/_plan/_out scratch and
   _attesting. An authority witness must record calls and assert zero after the read; this
   keeps failures inside the normal runner. A throwing/asserting witness is also
   acceptable if it produces a non-vacuous failing test when reached.
   Read from a hostile authority callback while _attesting=true refuses BUSY.

Implementation ownership: inventory.gd plus dedicated tests. Parent owns registry,
memory/evidence/queue. Focused/full suite, static gates and independent source
review precede merge. INIT-0 retains binding, producer and activation work.
