# Independent source acceptance — SAVE-RES-R01 v2

Date: 2026-09-19 · Separate author session · No tools run, no source edited

This review is a read of the supplied contract, decision 0163, `reservations.gd`
(including the appended column fragment), `save_reservations_restore.gd`, the
relevant parts of `save_section_inventories.gd`, the 17 parent-authored tests,
and the two evidence directories. All arithmetic below was re-derived by hand
from the source; nothing was executed. The parent reports 117 tests / 2639
assertions / 0 failures focused and 15 static checks passing, with the full suite
still underway. Those numbers are taken as reported, not independently observed.

No whole-world claim is made or accepted here.

## 1. What I verified and found correct

**Refusal atomicity and shape-before-index.** `copy_reservation_columns_into`
gates in the contract order: caller record shape (SHAPE) → live extents and all
thirteen live column shapes (SOURCE_DERIVED) → live native counts
(SOURCE_DERIVED) → canonical payload with specific codes → derived comparison.
`restore_reservation_columns` gates record shape → live shape → payload → publish,
and deliberately omits the live count check, which is exactly the state restore
exists to replace. `_reservation_live_shape_ok` runs before any column is indexed
and before `ReservationDerived.new` allocates, so a forged extent cannot drive an
out-of-bounds read or an unbounded allocation. `_refuse_column` writes one field.
No mutator, `clear`, `audit`, or Inventory call appears anywhere in the fragment.

**O(R log R) packed merge, keys, ties, group validation.** Both sorts are
bottom-up mergesorts over two length-R `PackedInt32Array` buffers with copy-back
per pass; no recursion, no Dictionary, no quadratic insertion.
`_reservation_key_before` compares fields directly and never subtracts, so an
extreme signed purpose cannot invert the order; the final `a < b` makes the sort
stable on row index. Job order is `(job_slot, lot_slot, lot_generation, purpose)`
and lot order is `(lot_slot, job_slot, job_generation, purpose)`, matching the
contract. Because the group field is the primary sort key, every slot's rows are
contiguous; a contiguous block that is not constant must contain an adjacent
unequal pair, so the adjacent-pair generation scans are complete, not
approximate. Generation scans run to completion before the duplicate scan, giving
the fixed JOB_GENERATION-over-DUPLICATE precedence. Once a job group is
single-generation, adjacency on `(lot_slot, lot_generation, purpose)` is exactly
the full five-field key, so duplicate detection is sound. Per-lot sums reset on
lot-slot change and bound via `quantity > RESERVATION_MAX_I64 - total` before the
addition, with `total >= 0` guaranteed by the earlier positive-quantity check;
`_math` is untouched. Cross-lot job totals are correctly not summed.

**Row identity and eight ordinals.** No compaction, renumbering, or reordering
exists on either path. All eight arrays are read, validated, and installed;
inactive rows are checked across ordinals 1..7. `test_exact_rows_...` pins this:
rows 0/2/4 for job 3 produce chain `[4, 2, 0]` — semantic lot order, not row
order — while the hole stays at row 1 and the next claim reuses row 1.

**Source heap acceptance.** `_reservation_live_heap_ok` checks
`free_count == R - active_count`, then for each `i < free_count` bounds-checks,
rejects occupied, rejects duplicate membership, and requires
`heap[(i-1)/2] <= heap[i]` with integer division. `(i-1)/2 < i < free_count`, so
no read reaches or passes the tail. Any valid permutation is accepted; the
rebuilt ascending array is never compared against the live heap. Restore installs
an ascending prefix with a `-1` tail, which is a valid min-heap and preserves
lowest-free-index allocation.

**Counts, old payload replacement, scratch.** Restore recomputes `active_count`
and `free_count` from occupancy and does not require the old payload, counts, or
indexes to be coherent — only that the object's construction extents and array
shapes still hold. `_math` and `_pending_new_rows` are never written by the
fragment; `_preflight_rows` recomputes the fresh-row count before every read, and
the test asserts the next claim reports 1 despite a forged pending value of 77.

**Canonical buffer independence and private staging.** Capture installs eight
`.duplicate()` arrays, so prior caller aliasing is replaced rather than written
through and the exported record is detached from the live pool. Restore
duplicates all eight inputs, so borrowing in the adapter is safe.
`ReservationDerived` never escapes; direct transfer into the owner is therefore
sound. The owner preloads no save module, and the test greps for that edge.

**Parent's `job_order` release (reviewed specifically).** `_derive_reservation_indexes`
now assigns `job_order = PackedInt32Array()` after `_reservation_link_rows` and
before the second `_reservation_sorted_rows` call. This is both necessary and
sufficient for the stated budget: without it, the caller's retained order buffer
(4R) would coexist with the second call's `order` and `scratch` (8R) for 12R;
with it, the peak is the two buffers inside a single call, 8R = 262144 bytes. At
the return of each call the callee's `scratch` is released and the caller shares
the returned `order`, so the transition point is also 8R. The revised docstring
now describes this accurately. I found no path that reads `job_order` after the
release. Accepted.

**Published arithmetic.** All figures re-derive: wrapper 4 + 12 + 4 + 8 + 8 = 36;
payload 4 + 8·8 + 37R = 68 + 37R; block 104 + 37R; at R = 32768, 1212520, and at
R = 8, 400 — matching `wire-baseline.json`. Canonical 37R = 1212416; derived
20R + 4J + 4L = 655360 + 32768 + 65536 = 753664; merge 8R = 262144; bitmap
R = 32768. Adapter precedence in both entry points matches the contract
step-for-step, and `block_shape_refusal` checks group cardinality 1/5/2 before
indexing any column.

## 2. Findings

**F1 — The supplied-Inventory guard is satisfiable by any quiescent Inventory
(medium, design-visible, not a code bug).** `_inventory_refusal` queries only
`is_transaction_open()` and `is_transaction_poisoned()`. A freshly constructed
`Inventory.new(1, 1)` answers false to both, so `apply(block, store, held_clock,
Inventory.new(1,1))` proceeds while the real world's Inventory is mid-transaction.
The contract states cross-world attestation is deliberately out of scope, and I
accept that scoping — but the parameter then provides no protection at all, and
nothing in the test suite records that fact. Bounded remedy: add one negative
control asserting that a foreign non-busy Inventory is accepted, so the hole is
executable rather than prose, and carry a named coordinator obligation to pass
the bound Inventory.

**F2 — Both adapter paths allocate and fill a 37R canonical body they discard
(low, bounded, cold path).** `ReservationColumns.new(store.row_capacity(), ...)`
resizes and `fill()`s all eight arrays. In `capture_into` every one is then
replaced by the owner's `.duplicate()`; in `apply` every one is overwritten by a
borrowed block array before any read. At R = 32768 that is 1212416 bytes
allocated and written per call, never read. The adapter docstring claims apply
"owns one borrowed column view", which understates the footprint by 37R. Bounded
remedy: either add a metadata-only construction path for the view, or amend the
docstring and the evidence accounting to include the constructor body. No
behavioural change either way.

**F3 — Restore makes the admitted cross-lot overflow reachable from a file
(medium, scope interaction).** `_sum_list` is unchecked, so
`job_reserved_total_milli` wraps on a job whose rows across different lots exceed
i64. That is correctly left to the separate arithmetic packet. What changes here
is reachability: previously the state required two very large lots and a live
claim sequence; after this work it is one restore of a crafted block, and the
parent test deliberately constructs exactly that state (two rows of 6e18 on
distinct lots for one job) and asserts it is admitted. Recommendation: no change
to this packet, but the arithmetic packet should land before any save file from
an untrusted source is accepted, and that ordering should be recorded.

**F4 — Per-phase peak footprint is not published (low, evidence).** The contract
lists component sizes but no phase peak. For capture at full capacity I derive
roughly: live owner 57R + 4J + 4L, derived staging 20R + 4J + 4L (alive through
publication), merge 8R, membership bitmap R, caller's prior record 37R, and the
eight new duplicates 37R overlapping the old ones — about 160R + 8J + 8L ≈ 5.4 MB.
The evidence set should state the number it intends to be held to.

Observation, non-blocking: the merge buffers are sized R rather than the active
count, so a pool with one active row still allocates 8R. That is what the
contract specifies; sizing to `count` would be a cheap sparse-case improvement.

## 3. Required acceptance gaps

Each is blocking for acceptance under the contract's own required-test list.

1. **Live column shape corruption is never exercised.**
   `test_source_derived_corruption_...` forges *values* in heads, links, heap, and
   counts, but never resizes a live column or drives `_row_capacity` outside
   1..ROW_CAPACITY. `_reservation_live_shape_ok`'s size branches are therefore
   unproven on both capture and restore. Add one case per array class.
2. **In-range-but-wrong native counts are untested.** The counts test uses
   4294967296, which fails the range branch. A case with, say,
   `_active_count = 5`, `_free_count = 3` on an 8-row pool holding 6 active rows
   satisfies `_reservation_live_counts_ok` and must be caught later by
   `_reservation_derived_matches`. That path is currently unproven.
3. **Recapture byte stability is asserted nowhere.** The contract requires it.
   `test_adapter_overwrites_...` recaptures and applies but never compares two
   encodings. Add: capture → hash → apply into a fresh pool → recapture → assert
   identical bytes.
4. **Restore over aliased caller i32 buffers is untested.** Aliasing is covered
   only on the capture side. Restore from a record whose `r_job_slot` and
   `r_lot_slot` are the same array should be asserted to yield independent owner
   columns.
5. **The registry prose correction is unevidenced.** The contract and decision
   0163 both require correcting the zero-quantity and chain-order prose in the
   canonical state registry. No registry artifact appears in this packet.
6. **Full suite, static checks, and exact-head CI are absent.** Only the focused
   log is present; the 15 static checks and the full run are reported but not
   shown, and no negative controls or exact-head CI evidence is included.

Two further evidence notes. The literal block hashes are produced by a test that
reconstructs the wrapper framing itself (`write_utf8_u32`, literal schema 1,
literal extent count 0) and concatenates `Codec.column_slice` output; it does not
drive the codec's own block encoder. Given that five section-7 owners still
publish nothing, that proxy is reasonable, but it should be labelled as a proxy
rather than as an encoder baseline. Separately, evidence is split across
`reservations-columns-2026-09-19/` and
`reservations-columns-contract-2026-09-19/`; the acceptance packet should
cross-link or consolidate them.

Minor test-quality note: the poisoned-Inventory branch is reached by
`_inv.set("_tx_poisoned", true)` rather than by a genuine failed operation inside
an open transaction. Forging a private flag proves the adapter reads it; it does
not prove the predicate means what the adapter assumes. Prefer a real poisoning
sequence where one is cheap to construct.

## 4. Disposition

The implementation matches the accepted contract on every behaviour I was asked
to verify, and I found no correctness defect in validation ordering, key
comparison, group scanning, overflow bounding, heap acceptance, row identity,
refusal atomicity, or buffer independence. The parent's `job_order` release is
correct and is what makes the stated two-buffer merge budget true. Acceptance
should be withheld only pending the six gaps in section 3 and a decision on F1's
negative control; F2 and F4 are documentation and accounting corrections, and F3
is a sequencing recommendation for the already-separated arithmetic packet.
