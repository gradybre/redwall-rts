# Review: read-only whole-inventory stock counts (INIT-COUNT-R01 v1)

Source reviewed: `godot/scripts/core/inventory.gd`, `godot/scripts/core/gear.gd`,
`godot/scripts/core/int_math.gd`, `godot/test/test_gear.gd`. 2026-09-19.

Verdict: the shape is sound — a caller-owned record, one bounded high-water scan, staged
aggregates, publish-only-after-all-checks. Six items below must be settled before
implementation; they are narrow amendments to this draft, not new architecture.

## Blockers

### B1. The equipped/loose biconditional is not available to a pure read

The draft says a null container slot means equipped, and separately demands
"valid existing equipped attestation". In the owner, the only thing that proves an equipped
record is `_attests()`, which does `_equipment_authority.call(EQUIPMENT_ATTESTATION_METHOD,
lot_ref)` on a duck-typed `Object`. `_audit_lot_placement()` is the only place the
biconditional is re-derived, and it is explicitly documented as costing "one attestation per
live lot, which is why audit() is documented as a diagnostic and never runs on a tick".

A whole-inventory count cannot inherit that. Remedy: the primitive classifies **by
`_l_container_slot` alone** and states in its docstring that it does not certify attestation;
`audit()` retains that obligation, unchanged. Drop "valid existing equipped attestation" from
the row-validation list and keep the cheap, pure structural checks the same function already
makes for a detached row: `_l_container_generation == NULL_GENERATION`,
`_l_reserved_milli == 0`, and `_l_next == _l_prev == NULL_SLOT`. For a loose row, validate
the complete reference with `is_container_valid(Vector2i(_l_container_slot[slot],
_l_container_generation[slot]))` — pure, and it closes the "complete container reference"
obligation the draft correctly notes `_audit_lot_placement()` does not make.

### B2. The attestation guard is not reentry-safe, so BUSY alone is insufficient

`_attests()` and `_seed_consumption_refusal()` both do `_attesting = true` … `_attesting =
false` unconditionally. A nested attestation therefore *lowers* the outer guard on return,
leaving the outer authority callback able to reach mutators that `_guard()` would otherwise
refuse. The draft's "BUSY must reject reentrant entry before another attestation" is
necessary but does not fix this, and fixing `_attesting` to a save/restore is a mutation of
existing equip/seed paths outside this packet's ownership.

Remedy: with B1 applied the primitive never calls an authority, so it introduces no new
nesting. Keep `_attesting` in the BUSY set purely as an entry refusal (it means some
collaborator is mid-callback and the columns are not a settled boundary). Record the
`_attesting` clear-on-return asymmetry as a pre-existing owner finding for INIT-0; do not
repair it here.

### B3. Cost: per-lot attestation is not bounded work

`gear.is_equipped_record()` calls `_resolve_row()`, a bounded ascending scan over gear rows.
One attestation per live lot is live_lots x gear_rows, which contradicts "bounded read-only
snapshot". B1 removes it. Keep the draft's refusal to make any latency claim before
measurement in the real consumer.

### B4. STATE-before-OVERFLOW precedence implies two passes

As written, "row validation in ascending slot order -> STATE; overflow encountered while
accumulating a valid row -> OVERFLOW" means a malformed row at slot 7 must outrank an
overflow at slot 3, which requires validating every row before accumulating any.

Remedy: restate as **single pass, per row**: for each live row in ascending slot order,
validate (STATE on failure), then accumulate (OVERFLOW on failure). Refusal order across rows
is therefore slot order, and an earlier overflow legitimately pre-empts a later malformed
row. Adjust evidence item 5 so the overflow fixture contains no malformed rows, otherwise the
test pins an order the implementation is not required to produce.

### B5. Publication must copy values, not rebind arrays

`PackedInt64Array` is a value type with copy-on-write. Publishing by assigning the staging
arrays onto `target` replaces the caller's four allocations — which the record's constructor
is specified to own — and shares buffers until the next write. It also makes "leaves all
target arrays byte-identical" a statement about different objects on refusal than on success.

Remedy: after the SHAPE check confirms all four target arrays are length 256, publish by
writing element-by-element into the target's **existing** arrays. Never assign an array field
on `target`. The local staging stays a per-call `StockCounts` (constructor-zeroed), so no
residue can survive between calls; do not hoist it to a reused member, which would reintroduce
the `_math`/`_plan` aliasing class the owner header warns about.

### B6. "Registered item" is not an invariant of a restored store

The draft requires a registered item in 0..255. `_item_registered` is catalog-time state
written only by `register_item()`; `_rebuild_derived_state()` restores live counts, high-water
and the conservation ledger but never repopulates it. The owner's own load-side validator,
`_canonical_live_refusal()`, checks `l_item_id` against `0 .. ITEM_CAPACITY` and nothing more.

Remedy: make the hard STATE check the **range** `0 <= item_id < ITEM_CAPACITY` (which is also
the array bound the four outputs need). If the registration check is kept, the draft must say
explicitly that a restored-but-not-recatalogued store refuses STATE — otherwise the primitive
is unusable immediately after `restore_canonical_columns()`.

## Secondary, accept as stated with the noted tightening

- **BUSY set.** Add `_j_count != 0`. `_canonical_quiescent_refusal()` already treats journal
  residue as non-quiescent; a count taken over columns with an unrolled journal is the same
  hazard. `_tx_poisoned` without `_tx_open` is unreachable (`_close_transaction()` clears it),
  so keeping it is belt-and-braces, not dead weight.
- **Overflow.** Use `IntMath.checked_add_into` with a **local** `IntResult`, never `_math`.
  All four accumulators need it, including `unreserved_loose` — `quantity - reserved` cannot
  overflow once `0 <= reserved <= quantity` is validated, but the running sum can.
- **High-water.** `_l_slot_high_water` is a conservative upper bound, not a count: it is
  raised by `_alloc_lot_slot()`, deliberately left raised by rollback, excluded from
  `state_bytes()`, and reset to 0 by `_clear_lot_rows()`. Bounding the scan by it is correct;
  evidence item 1 must not assert any relationship between `counted` and its value.
- **Diagnostics.** The draft is right that `state_bytes()` is not a diagnostic snapshot. The
  fields tests must compare separately: `_l_slot_high_water`, `_c_slot_high_water`,
  `_canonical_detail`, `_tx_open`/`_tx_poisoned`/`_tx_error`, `_tx_cleanup_lot`,
  `_op_cleanup_lot`, `_j_count`, and the `_math`/`_plan`/`_out_ref`/`_out_value` scratch. The
  primitive must touch none of them.

## Evidence item 3: the real Gear fixture

`test_gear.gd` gives the exact shape. `Gear.bind_equipment(inventory, residents.directory(),
residents)` wires all three and registers gear as the inventory's equipment authority, so the
authority **is** bound during this test — which is fine under B1 and is the honest
configuration. `_check_equip()` refuses anything but the compiled `tool`
(`REFUSE_EQUIP_KIND_UNSUPPORTED`), so the fixture must use `tool` /`MANUFACTURE_BASIC` with a
real `Residents` spawn, not a net or trap. `_detach_checked()` sets the container to
`(NULL_SLOT, NULL_GENERATION)` and leaves quantity, quality, provenance, recipe, age and
generation untouched, which is what makes `live = loose + equipped` observable with one lot
and no duplicated tool. Emptying the original container afterwards is reachable: the equipped
lot is unlinked, so `_c_lot_count` is 0 and `destroy_container()` will accept it.

## Unchanged

No signal, no `await`, no Economy/UI/startup edit, no new authoritative field, no serialized
field, no registry version, no reverse index, no public mutation hook. The record remains
caller-owned at 8192 B with one local staging of the same size. INIT-0 retains all
producer/binding/activation work.
