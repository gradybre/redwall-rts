# Reservations owner column contract — feasibility audit

2026-09-19 · Read-only audit. Not an implementation, not an acceptance, not a
ruling. Parent notes (`astra-source-notes.md`) are treated as candidates, not as
instructions to accept. Nothing here was run or applied.

Scope: `godot/scripts/core/reservations.gd` as the seventh ARCH-SAVE-002
section 7 owner to publish columns, after StockAge. The wire format, field
ordinals, type codes and refusal codes already frozen in
`save_section_inventories.gd` are treated as authority and are **not** proposed
for change.

---

## 1. The eight canonical arrays are exactly the persisted set

REG-R01 declares eight `reservations` ordinals and the source carries exactly
eight authoritative columns, one per ordinal:

| Ord | Column | Type | Live blank |
|---:|---|---|---|
| 0 | `_occupied` | u8 | 0 |
| 1 | `_r_job_slot` | i32 | -1 |
| 2 | `_r_job_generation` | i32 | 0 |
| 3 | `_r_lot_slot` | i32 | -1 |
| 4 | `_r_lot_generation` | i32 | 0 |
| 5 | `_r_purpose` | i32 | 0 |
| 6 | `_r_quantity_milli` | i64 | 0 |
| 7 | `_r_expiry` | i64 | 0 |

Both `clear()` and `_free_row()` produce those blanks, and the codec's
`BLANK_ORDINALS_RESERVATIONS` demands ordinals 1..7 at exactly those values on an
inactive row. Source and wire agree today; no normalization layer is needed for
this owner, unlike `inventory`. Row identity is the bare index: there is no row
generation and REG-R01 forbids compaction. Any published contract must therefore
preserve index-for-index placement, and a restore must not renumber.

Everything else in the module is derived: `_free_heap`, `_free_count`,
`_job_head`, `_lot_head`, `_job_prev`, `_job_next`, `_lot_prev`, `_lot_next`,
`_active_count`. None is on the wire and none may be invented onto it.

**Finding (favourable, and not obvious).** The free min-heap is *not*
order-bearing. `_allocate_row()` calls `_pop_min()`, which returns the minimum
regardless of the array permutation, so any valid heap over the same free set
yields the identical allocation sequence. Rebuilding it as ascending free indices
is behaviourally exact. This is the opposite of `inventory`'s free **stacks**,
whose LIFO pop order forced HAZARD 1 to persist the permutation. The reservations
owner needs no stack-prefix machinery and no count field, and the section's
existing hazard note must not be copied across by analogy.

---

## 2. Constructor extents versus the owner block

`_init()` clamps to `[1, 32768]` rows, `[1, 8192]` job heads, `[1, 16384]` lot
heads. The codec marks `reservations` as `PRIMARY_COUNT_IS_FIXED == false`, so
`primary_count` is a runtime row count in `1..32768`, and declares **zero child
extents**. Job capacity and lot capacity are consequently *absent from the wire*.

**Blocker B1 (Astra disposition required).** Restoring into a pool whose job/lot
extents differ from the capturing pool's cannot be detected from the block alone.
Three candidate dispositions, none of which this audit may choose: (a) the target
pool's constructor-time extents are authoritative and the owner refuses any row
whose slot falls outside them; (b) two child extents are added to the owner block,
which changes the healthy wire and the owner schema version and is therefore out
of scope here; (c) job/lot extents are declared a load-orchestrator input carried
by a different section. Option (a) is the only one that preserves the frozen wire
and the reduced-harness capacities, and is the one the API below assumes; it must
still be ruled, because it makes a codec-valid stream owner-refusable.

**Blocker B3.** The codec bounds `_r_job_slot` by the **compiled**
`ReservationsScript.JOB_CAPACITY` (8192) and `_r_lot_slot` by `LOT_CAPACITY`
(16384), while the live module bounds them by `_job_capacity` / `_lot_capacity`.
A record accepted by `save_section_inventories.gd` can therefore be invalid for a
reduced-capacity harness pool. The owner must carry its own range refusal rather
than re-use the codec's; the codec must not be tightened, because it cannot see
runtime extents.

---

## 3. No Inventory binding, and what that costs

The module holds no `Inventory` field: every mutator takes one per call. A column
contract must not introduce a binding, must not call `reserve_lot` /
`release_reservation`, must not replay `claim_batch`, and must not mutate any
inventory column. Installing columns is therefore *silent* with respect to
`lot.reserved_milli`.

**Blocker B4.** The decision-0019 invariant
`lot.reserved_milli == sum(active rows) <= lot.quantity_milli` cannot be proved by
this owner at capture or apply time. `audit(inventory)` is the only check that
spans both stores and it is a diagnostic, not part of the contract. The audit
recommends the coordinator run `reservations.audit(inventory)` *after* both
owners are applied, as an explicit orchestrator step; whether that step is
mandatory, and what it refuses with, is Astra's to rule.

**Blocker B5.** `claim_batch`, `release_claim`, `_release_list` and
`release_expired_for_job` all refuse `INVENTORY_TRANSACTION_OPEN`, because pool
rows are outside inventory's undo journal. A capture taken while a transaction is
open would photograph a half-applied world. With no binding, the owner cannot
detect this. Candidate: the *adapter* (not the owner) takes an optional
`Inventory` used **only** to assert `is_transaction_open() == false`, refusing
otherwise, and explicitly documented as *not* a totals proof. The alternative is a
caller-asserted quiescence precondition with no mechanical check. Astra to choose;
this audit recommends the optional-Inventory flag because it converts a comment
into a refusal at negligible cost, and because it keeps the owner itself free of
any Inventory parameter.

---

## 4. Semantics that must be preserved verbatim

- **Positive quantities.** `_preflight_claim_fields` refuses `quantity <= 0`, and
  the codec refuses `<= 0` on an occupied row. Both agree.
  **Blocker B2 (contradiction).** The logical registry prose describing a
  zero-quantity row as a *live empty reservation* contradicts both. Two
  authorities already refuse it; the prose is the outlier. Astra disposition
  required: correct the prose, or rule that zero-quantity live rows exist, in
  which case the codec's `REFUSE_QUANTITY_RANGE` on ordinal 6 and the source
  preflight both change — a wire-behaviour change, not a doc fix.
- **Expired leases survive.** `expiry` is an opaque absolute tick with no
  never-expires sentinel. A restore must install expired rows unchanged and must
  not sweep them; `release_expired_for_job` remains the only sweep, driven by the
  caller's tick. Restoring must not consult any clock for row content.
- **Opaque signed purpose.** `_r_purpose` is compared for equality and order and
  nothing else. The contract must validate only the i32 range and must not mirror
  a domain into `catalog.gd`. Negative purposes are legal.
- **Overflow.** Per-lot totals must be summed with `IntMath.checked_add_into` and
  refused on overflow. The module's `_math` scratch is call-scoped and must not be
  repurposed; the validator needs its own `IntResult`, owned by the columns object
  (see §6) so the pool allocates nothing new.

---

## 5. Cross-row properties the codec does not check

The current codec field-validates only. Four properties are load-bearing for the
derived indexes and are unchecked:

1. **Duplicate `(job_ref, lot_ref, purpose)`.** Coalescing makes the triple
   unique; `_find_row` early-exits on sorted order, so a duplicate makes one row
   permanently unreachable and un-releasable.
2. **Mixed job generations within one job slot.** `_list_head` reads the head
   row's generation and returns `NULL_ROW` on mismatch, so a mixed slot silently
   hides rows from every job-side operation. `_check_job_ref` prevents this live;
   a forged record can produce it.
3. **Mixed lot generations within one lot slot.** Same failure via
   `_preflight_claim_fields` and `drop_retired_lot_claims`.
4. **Per-lot quantity sums** that overflow i64 or that no lot could satisfy.

**Blocker B7.** If the owner refuses these and the codec does not, a stream is
codec-valid and owner-invalid — two acceptance surfaces for one artefact. The
audit's position: accept that asymmetry deliberately, refuse at the owner with a
distinct code family, and leave the wire and the codec untouched. Recording it
here so it is a ruled asymmetry rather than a discovered one.

---

## 6. Proposed API (exact), refusals, and validation order

**Columns object.** A nested `ReservationColumns` holding `row_capacity`,
`job_capacity`, `lot_capacity`, the eight packed arrays sized to `row_capacity`,
two `PackedInt32Array` row-index work buffers also sized to `row_capacity`, and
one `IntMath.IntResult`. Constructed with the three extents, caller-owned, reused
across saves, holding **no** Inventory reference and no link/head/heap arrays.
The work buffers live here, not in the pool, so ARCH-MEM-005's allocate-once rule
for the pool is untouched.

**Owner methods**, names deliberately distinct from `inventory`'s
`copy_canonical_columns_into` / `restore_canonical_columns`:

- `copy_reservation_columns_into(columns) -> bool` — capture.
- `restore_reservation_columns(columns) -> bool` — apply.
- `reservation_columns_detail() -> String` — last refusal detail.
- `structural_audit() -> Inventory.OpResult` — the occupancy/heap/list half of
  `audit()` with no Inventory argument, so capture can prove the live derived
  state sound before photographing it. `audit(inventory)` is unchanged and
  delegates to it.

**Adapter methods** on `save_section_inventories.gd`, mirroring the inventory
pair: `capture_reservations_into(record, store, columns)` and
`apply_reservations(record, store, columns)`, each returning a
`SaveHeader.Refusal`, each validating the block with the existing
`owner_refusal()` in addition to the owner's own checks. Per §3, both may take an
optional `Inventory` used solely for the transaction-open barrier.

**New refusal codes** (owner-side, distinct family, no existing code altered):
`COLUMNS_SHAPE`, `COLUMNS_OCCUPANCY_BYTE`, `COLUMNS_BLANK_ROW`,
`COLUMNS_SLOT_RANGE`, `COLUMNS_GENERATION_RANGE`, `COLUMNS_QUANTITY_RANGE`,
`COLUMNS_EXPIRY_RANGE`, `COLUMNS_JOB_GENERATION_MIXED`,
`COLUMNS_LOT_GENERATION_MIXED`, `COLUMNS_DUPLICATE_KEY`, `COLUMNS_OVERFLOW`,
`COLUMNS_SOURCE_DERIVED` (capture-side, live indexes corrupt),
`COLUMNS_TRANSACTION_OPEN` (adapter).

**Validation order, fixed and total:**

1. Shape: the three extents equal the target pool's; every array length equals
   `row_capacity`.
2. Occupancy: every `_occupied` byte is 0 or 1.
3. Inactive rows: ordinals 1..7 exactly at the blank values of §1.
4. Active row fields, per row, in ordinal order: job slot in
   `[0, job_capacity)`; job generation in `[1, INT32_MAX]`; lot slot in
   `[0, lot_capacity)`; lot generation in `[1, INT32_MAX]`; purpose in i32 range;
   quantity `> 0`; expiry `>= 0`.
5. Per-job-slot generation consistency.
6. Per-lot-slot generation consistency.
7. Duplicate `(job_slot, job_generation, lot_slot, lot_generation, purpose)`,
   detected from the sorted order of §7 rather than by a second scan.
8. Per-lot checked summation for overflow.

Only after step 8 may anything be written. Steps 5–7 consume the sort of §7, so
the sort runs inside validation and its output is reused for the rebuild.

---

## 7. Rebuild: packed bottom-up mergesort, O(R log R)

Two orders are needed, matching the module's comparators exactly:

- Job lists: group by `_r_job_slot`, ordered within a group by
  `(_r_lot_slot, _r_lot_generation, _r_purpose)` — i.e. sort occupied row indices
  by `(job_slot, lot_slot, lot_generation, purpose)`.
- Lot lists: sort by `(lot_slot, job_slot, job_generation, purpose)`.

Bottom-up mergesort over **row indices** in the two work buffers: runs of 1, 2,
4, … merged alternately between buffers, no recursion, stable, deterministic,
O(R log R) comparisons and O(R) moves per pass. The two passes reuse the same two
buffers sequentially. Links and heads are then written in one linear walk per
order: consecutive entries with equal owner slot are chained, a slot change
starts a new head. Sorted-insertion (the live path) is worst-case quadratic at
32768 rows and is unacceptable on a restore; the mergesort is the reason this is
feasible at all.

The free heap is filled with the ascending free indices and `_free_count` /
`_active_count` recomputed from `_occupied` (see §1 for why ascending is exact).

**Memory, as phase allocations — not a process peak or RSS claim.** Work buffers
`8 * R` (262144 at R = 32768). Derived outputs `20 * R + 4 * J + 4 * L` (753664 at
the maxima), which are the pool's existing allocate-once columns and are
overwritten, not newly allocated. Canonical columns `37 * R` (1212416), owned by
the caller. Phases: **A** validate (no writes, reads source or record only);
**B** install the eight columns; **C** rebuild derived in one pass each. Phase A
proves phase C cannot fail, which is what makes B+C jointly atomic without a
journal. A refusal in A leaves the target byte-identical.

**Capture-side source validation.** `copy_reservation_columns_into` must run
`structural_audit()` first and refuse `COLUMNS_SOURCE_DERIVED` if the live heads,
links, occupancy or heap are inconsistent. Copying only the eight canonical
columns from a pool whose indexes are broken would encode a *different, healthy*
future from a malformed present. **The contract must refuse, never repair.** It
must additionally re-run steps 5–8 against the live rows, because the structural
audit does not check duplicates or mixed generations.

---

## 8. Test requirements

**Negative (each must leave the target byte-identical, proved by comparing
`state_bytes()`, `free_row_count()` and `active_row_count()` before and after):**
occupancy byte 2; inactive row with any of the seven residues; active row with
quantity 0 and with a negative quantity; expiry -1; job slot equal to
`job_capacity`; lot slot equal to `lot_capacity`; job generation 0 on an active
row; two active rows sharing the full key; two rows on one job slot with
different job generations; two rows on one lot slot with different lot
generations; a per-lot sum that overflows i64; array length mismatch; extents
mismatch; apply with an inventory transaction open; capture from a pool whose
`_job_head` has been corrupted.

**Continuation (the point of the contract — the restored pool must be a live
pool, not a museum piece):** after restore, `state_bytes()` equals the source
pool's; `audit(inventory)` passes against a matching inventory; the next
allocation takes the lowest free index; `_find_row` finds every restored claim;
a coalescing `claim_batch` adds onto a restored row and consumes zero fresh rows;
`release_job_claims` and `release_lot_claims` walk canonical order;
`release_expired_for_job` releases exactly the restored rows at or past the tick;
`renew_claim` refuses a non-later expiry against a restored lease; restoring a
second record over a populated pool replaces it wholly with no leaked rows.

---

## 9. Blockers requiring Astra disposition

B1 job/lot extents absent from the owner wire. B2 registry prose versus source and
codec on zero-quantity live rows. B3 compiled versus runtime slot bounds. B4 the
`reserved_milli` correspondence is an orchestrator duty with no owner-level proof.
B5 transaction-open barrier: optional `Inventory` for a flag, or caller assertion.
B6 whether the adapter takes a clock at all, given expiry is opaque and expired
leases must be preserved unswept. B7 the deliberate two-surface asymmetry between
codec field validation and owner cross-row validation. B8 refuse-versus-repair on
corrupt live derived indexes at capture.

No full section 7 assembly and no closure of BLOCKER I1 follows from this owner:
that needs `fishing`, `forage`, `gear` and `stock_age` as well.
