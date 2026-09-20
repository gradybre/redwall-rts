# RES-TOTAL-R01 v2 — independent source review

Date: 2026-09-19 · Reviewer: independent specialist (source only, no execution)
Scope reviewed: `docs/planning/reservation_totals_contract.md`,
`docs/decisions/0164-return-checked-reservation-totals.md`,
`godot/scripts/core/reservations.gd`, `godot/scripts/core/int_math.gd`,
`godot/test/test_reservations.gd`, `godot/test/test_reservation_totals.gd`,
`docs/validation/evidence/reservation-totals-2026-09-19/integration.diff`.

**Verdict: NEEDS REPAIR.** One blocking defect (B1) makes the owner file
unparseable. Every other contract obligation I can judge from source is met and is
recorded below as accepted, so the repair is bounded to two lines. No runtime claim
is made here: I ran nothing.

---

## Blockers

### B1 — Two mangled fragment-marker lines make `reservations.gd` fail to parse

**Exact locations (symbol-anchored; both are single lines).**

1. `godot/scripts/core/reservations.gd`, the first line after the blank lines that
   follow the end of `func _count_list(head: int, by_job: bool) -> int:` and before
   the comment line ``# `func _sum_list(...)`. The unchecked `_sum_list` is DELETED``.
   That line currently reads, verbatim and with no leading `#`:

   ``func job_reserved_total_milli(...)` through the end of``

   In `integration.diff` this is the first added line of hunk `@@ -946,28 +946,90 @@`.

2. `godot/scripts/core/reservations.gd`, the first line after the end of
   `func _audit_order(previous: int, row: int, by_job: bool) -> int:` and before the
   comment line ``# in `godot/scripts/core/reservations.gd`. It is the last internal caller``.
   That line currently reads, verbatim and with no leading `#`:

   ``func _audit_lot_totals(inventory: Inventory)` ``

   In `integration.diff` this is the first added line of hunk `@@ -1120,8 +1182,35 @@`.

**Why this blocks.** Both lines are the *first* line of a packet fragment header
("REPLACEMENT BLOCK. These lines replace everything from …") whose leading `# ` was
lost during integration; the continuation lines of the same headers kept their `# `.
As source, each is a `func` statement with an unbalanced parenthesis, a stray
backtick and trailing prose, followed by no `->` and no body. GDScript cannot parse
either. The contract's "a missing internal migration must fail parsing" clause is
about `_sum_list` references; this is an unrelated integration accident that fails
parsing for the wrong reason and hides whether the intended migration is clean.

**Suggested bounded fix.** Restore the two lost comment prefixes; change nothing
else. At location 1:

```
# REPLACEMENT BLOCK. These lines replace everything from `func job_reserved_total_milli(...)` through the end of
```

At location 2:

```
# REPLACEMENT BLOCK. These lines replace the whole of `func _audit_lot_totals(inventory: Inventory)`
```

The same two added lines in `integration.diff` must be corrected identically, or
re-applying the diff reintroduces the defect. Nothing below or above those lines
needs to move: the real declarations
`func job_reserved_total_milli(job_ref: Vector2i) -> IntMath.IntResult:` and
`func _audit_lot_totals(inventory: Inventory) -> StringName:` already exist further
down in each block and are well formed.

No second blocker found.

---

## Accepted — exact arithmetic, clearing and null-first semantics

- `_sum_list_into(head, by_job, out)` starts `total = 0`, walks the existing chain in
  its existing semantic order (`_job_next` / `_lot_next`, unchanged), routes every
  quantity through `IntMath.checked_add_into(total, _r_quantity_milli[row], out)`,
  and copies `out.value` into the local `total` **before** the next call. That is the
  required discipline for an output that is also scratch; it matches every other
  checked caller in this repository (`_preflight_quantities`, `RemainderAccumulator`).
- Overflow returns `false` immediately from inside the loop. `IntResult.refuse()` in
  `int_math.gd` sets `ok=false`, `value=0`, non-empty `error`, so no partial total is
  ever visible as a success. Contract satisfied exactly.
- Success path ends in `out.succeed(total)`, which sets `ok=true`, the exact total and
  an empty error — so a prior failure on a reused `out` is cleared.
- Missing list: `_list_head()` answers `NULL_ROW` for an out-of-range slot and for a
  generation mismatch (it compares `_r_job_generation[head]` / `_r_lot_generation[head]`
  against `owner_ref.y`). The loop body never executes and control reaches
  `out.succeed(0)`. This is the contract's explicit "calls out.succeed(0), clearing any
  earlier failure", not an early `return true`.
- Null-first: both `job_reserved_total_milli_into` and `lot_reserved_total_milli_into`
  test `if out == null: return false` **before** evaluating `_list_head(...)`, so no
  head column and no row is read, and no owner field is written. The defensive repeat
  of the null test inside `_sum_list_into` is redundant but harmless and I accept it.
- Exactness: nothing truncates, saturates or clamps; `IntMath.checked_add_into` is the
  standard `INT64_MAX - b` / `INT64_MIN - b` guard, so `I64_MAX` sums exactly and
  `I64_MAX + 1` refuses. No false refusal at the boundary.

## Accepted — cold/hot agreement and result independence

- `job_reserved_total_milli` / `lot_reserved_total_milli` each allocate exactly one
  `IntMath.IntResult.new()` and delegate to the corresponding `_into` form, so the two
  surfaces cannot diverge. The returned object is fresh per call and holds no reference
  to `_math` or to any owner field. Return type is now `IntMath.IntResult`, i.e. the
  old plain names return an explicit result rather than an integer, as required.
- Ignoring the delegated bool is safe: the refusal is fully carried on the returned
  object (`ok=false`, `value=0`, non-empty `error`).

## Accepted — no owner writes in the public queries

- The only writes on any path through the four public query methods are to the caller's
  `out` (or to the locally allocated result in the cold wrappers). `_math`,
  `_pending_new_rows`, `_last_column_refusal`, every canonical column, both head
  columns, the four link columns and the free heap are untouched, on success and on
  overflow alike. No Inventory method is called from any of them.

## Accepted — audit ordering and codes

- `_audit_lot_totals` keeps the fixed order the contract names, per lot: `head ==
  NULL_ROW` skip; `inventory.is_lot_valid(lot_ref)` gate returning the pre-existing
  `REFUSE_AUDIT_RESERVED_TOTAL`; then `_sum_list_into(head, false, _math)` returning
  the **already existing** `REFUSE_OVERFLOW`; then `var total: int = _math.value`
  copied immediately; then equality against `lot_reserved_milli`; then the
  `lot_quantity_milli` bound. An invalid lot therefore still outranks an arithmetic
  outcome, and no wrapped sum is ever compared.
- Reuse of the existing `_math` scratch here adds no per-lot allocation and is
  consistent with audit's diagnostic role, as the contract permits. The copy into
  `total` before the two further Inventory queries is present and is necessary.
- `REFUSE_OVERFLOW` already existed in the constant block; no new code was minted.

## Accepted — retained claims, unchanged semantics, out-of-scope defences

- Claim admission, coalescing, expiry/renewal, releases, row allocation, canonical
  columns, `state_bytes()` and the SAVE-RES-R01 column boundary are byte-identical to
  their prior form in the reviewed source; `integration.diff` touches only the query
  block, `_audit_lot_totals` and three assertions plus one helper in the reservation
  suite. No valid claim is rejected, truncated or saturated to conceal the defect.
- Release results remain row counts, so they correctly acquire no quantity-sum bound.
- Audit blind spots for Inventory lots the pool holds no rows for remain open and are
  correctly disclaimed in the docstring; that is the coordinator's separate
  reconciliation task and is **out of scope** here.
- `_list_head` hardening against a structurally corrupt head index (e.g. a forged
  in-range head pointing at an inactive row) is **accepted unchanged**: the contract
  forbids new defences, and public admission cannot produce that state.

## Accepted — caller migration

- No internal caller of the deleted `_sum_list` survives in the reviewed owner source;
  the sole former caller, `_audit_lot_totals`, now calls `_sum_list_into`. Grep of the
  owner file finds only `_sum_list_into`. The name `_sum_list` appears only inside
  comment prose.
- `test_reservations.gd` migrates all three call sites to the new result form via the
  new `_assert_checked_total(result, expected, label)`, which asserts `ok` before
  `value`: `test_recipe_reserves_across_five_or_more_lots` (4200),
  `test_a_different_purpose_or_job_gets_its_own_row` (900),
  `test_reserved_milli_equals_the_sum_of_active_rows` (1000 then 500), and
  `test_replacing_a_party_member_leaves_the_coordinator_claims_intact` (2100). No
  surviving `assert_equal(_pool.job_reserved_total_milli(...), <int>)` form remains in
  the reviewed suite.

## Accepted — test coverage is meaningful

`test_reservation_totals.gd` builds its fixture through the real public API
(`register_item` / `create_container` / `create_lot` / `claim_batch`) and asserts both
audits green before testing, so the two-item/two-lot 6e18 witness is genuinely admitted
rather than forged. Covered: public-API job overflow refusal with claims retained and
world still auditing; exact `I64_MAX` (4611686018427387903 + 4611686018427387904) with
no false refusal; ordinary sums; empty and missing/out-of-range/generation-mismatched
refs for both forms; reused-output recovery success→overflow→success with `error`
cleared; both query forms agreeing; whole-object field image plus `_math` image plus
`inventory.state_bytes()` unchanged across all four queries; independent cold results
and success-zero distinguished from refusal-zero; capture/restore agreement using the
admitted two-lot job-overflow witness (not the injected per-lot one); and a
structurally valid injected per-lot overflow proving `audit()` returns `OVERFLOW`
rather than a mismatch code. A checked-add-skipping mutant dies on both the witness
test and the `I64_MAX` test.

Two non-blocking observations, recorded only: (a)
`test_null_output_refuses_before_list_access` proves "before list access" indirectly,
by forging an out-of-range head and relying on the engine to complain if the null gate
were removed — adequate, but weaker than the other cases; (b) the audit-overflow test
depends on rows 0 and 1 being the lowest-free allocations after a full release, which
is guaranteed by the min-heap but is an implicit coupling.

---

## Remaining evidence (not obtainable from source; parent owns)

1. Repair B1, then a fresh exact-head census of `job_reserved_total_milli`,
   `lot_reserved_total_milli` and `_sum_list` across the whole repository — the review
   inputs contain only the owner file and the two suites, so callers elsewhere (save
   adapter, `jobs.gd`, tools) are unverified here.
2. A parse/static check of `reservations.gd` proving the two repaired lines are the
   only integration damage.
3. Runtime acceptance: existing reservation suite, `test_reservation_totals.gd`,
   relevant save tests, full/static checks and exact-head CI.
4. Confirmation that `integration.diff` hunk offsets still apply after the repair; I
   cannot verify hunk line counts from the supplied text.
