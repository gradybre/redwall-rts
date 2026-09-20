# Independent contract review — RES-TOTAL-R01 v1

Scope: read-only feasibility and acceptance review of `docs/planning/reservation_totals_contract.md`
(version 1, draft for review, 2026-09-19). No implementation, no execution, no source edits.
Inputs reviewed at pinned SHA256: contract `0fd54732…`, query/mutation excerpts `95ad45f4…`
(declared source SHA `408358c2…`), `godot/scripts/core/int_math.gd` `fba44816…`,
`godot/test/test_reservations.gd` `ad2da364…`, archived probe `2d261208…` and log `274e54ca…`,
and the serialized predecessor contract SAVE-RES-R01 `cc79293a…`.

**Verdict: ACCEPT WITH CONDITIONS.** No contradiction, no missing decision input, no blocker
requiring escalation. Six conditions (C1–C6) must be folded into version 2 before dispatch.

## 1. Defect and witness are real

The probe log is a genuine public-API witness, not a synthetic one: two mass-1 items, one lot each
of 6e18 milli, both claimed by job `(1,1)`. `claim_batch` accepts, `pool_audit_ok` is `true`, and
`job_total_accessor` reads `-6446744073709551616`. That is exactly `12e18 - 2^64`, so the accessor
wraps silently while every other reported invariant holds. The contract's refusal to reject the
claims, truncate, saturate, or tighten admission is correct: the per-lot totals (6e18 each) and the
per-item source totals are individually representable, and `_preflight_quantities` already refuses a
true per-lot overflow via `IntMath.checked_add_into`. Only the cross-lot job query is unsound.

## 2. Convention, codes and types are available

- `IntMath.IntResult` supplies precisely the semantics the contract asserts: `succeed()` sets
  `ok=true`/`error=""`, `refuse()` sets `ok=false`, **zeroes `value`**, and returns `false`. So
  "no partial total is exposed as a success" is satisfied by the existing primitive with no new
  refusal machinery.
- `REFUSE_OVERFLOW` already exists in `reservations.gd`; `_preflight_quantities` returns it. The
  audit mapping is therefore a reuse, not a new code, and needs no registry or wire change.
- The plain/`_into` pairing, the cold-wrapper-allocates-one-result rule, and the caller-owned-output
  rule all mirror `int_math.gd` verbatim, including its module docstring. The four proposed
  signatures are consistent with that convention and introduce no owner field.
- `_audit_lot_totals` returns `StringName` and `audit()` wraps it in an `Inventory.OpResult`, so
  returning `REFUSE_OVERFLOW` needs no signature change.

## 3. Census is consistent with the supplied sources

Live call sites of the two public names in `test_reservations.gd`: `job_reserved_total_milli` in
`test_recipe_reserves_across_five_or_more_lots` (4200) and
`test_replacing_a_party_member_leaves_the_coordinator_claims_intact` (2100);
`lot_reserved_total_milli` in `test_a_different_purpose_or_job_gets_its_own_row` (900) and twice in
`test_reserved_milli_equals_the_sum_of_active_rows` (1000, 500). Five sites total, all tests. Plus
the archived probe. No gameplay consumer appears anywhere in the supplied material, matching the
parent census. All five must become `assert_true(..._into(...))` or an `ok`-then-`value` inspection;
a left-behind `assert_equal(result, 4200)` would compare an object to an int and fail loudly rather
than pass silently, so migration errors are self-announcing.

The archived probe stays syntactically valid after the change: it only embeds the return value in a
`Dictionary` for `JSON.stringify`, so no static/import check breaks even if `docs/` is in parse
scope. Its *printed* value becomes meaningless, which is acceptable given the contract's explicit
"archived pre-change witness, not runnable current acceptance" clause.

## 4. Conditions

**C1 (evidence gap → delete, don't supplement).** The excerpt set is *not* complete for this change:
`release_job_claims` / `release_lot_claims` are shown but `_release_list` is not, and
`test_a_release_refuses_when_the_inventory_no_longer_covers_the_rows` proves the release path
performs a whole-list coverage proof that could plausibly use `_sum_list`. Resolution: require the
implementation to **remove** `_sum_list` entirely, not add `_sum_list_into` beside it. Any
unenumerated caller then fails to parse instead of silently keeping unchecked arithmetic. If a
release-path caller is found, it takes a *local* `IntResult` (never `_math`, which the same batch
path already uses) and maps overflow to `REFUSE_OVERFLOW`; this does not add an admission limit and
leaves release results as row counts, consistent with the contract.

**C2 (zero case must be written, not implied).** "No matching list … succeeds with 0" must be
realized as an explicit `out.succeed(0)` on the `head == NULL_ROW` path. Without it a caller reusing
one output across success→overflow→success — a sequence the contract's own test list demands — would
read a stale `ok=false` for a legitimately empty job. State this explicitly in v2.

**C3 (aliasing discipline).** `int_math.gd` states that a caller reusing one scratch MUST copy
`out.value` into a local before the next call. Since the accumulator is the caller's output object,
the loop must be `if not checked_add_into(total, _r_quantity_milli[row], out): return false` followed
by `total = out.value`. v2 should name this requirement so it is not rediscovered during review.

**C4 (null output).** `out.refuse()` on a null reference would crash. The `_into` forms must test
`out == null` and `return false` before any member access, with no owner write. The contract asserts
the outcome; v2 should assert the ordering.

**C5 (audit ordering, precisely).** "Before any equality comparison" is satisfiable without
reordering the existing `is_lot_valid` gate, and reordering it would change
`REFUSE_AUDIT_RESERVED_TOTAL` behaviour that existing tests rely on. Fix the order as:
`is_lot_valid` → checked sum (`REFUSE_OVERFLOW` on failure) → equality (`REFUSE_AUDIT_RESERVED_TOTAL`)
→ bound (`REFUSE_AUDIT_RESERVED_EXCEEDS`). The audit may use `_math`, but must copy `_math.value`
into a local `total` immediately, since the subsequent Inventory calls are outside the module's
control. Verification item for the implementer: confirm no earlier stage of `audit()` sums
quantities; if one does, it is covered by C1.

**C6 (continuation test must pick the right fixture).** SAVE-RES-R01 deliberately refuses a per-lot
quantity sum that does not fit i64 (`COLUMN_RESERVATION_OVERFLOW`) while admitting a job's sum across
different lots. Therefore the capture/restore agreement test must use the two-lot/one-job witness —
which round-trips — and must **not** use the injected per-lot overflow fixture, which cannot survive
restore by design. v2 should say so, or the test author will write an unsatisfiable case.

## 5. Test feasibility notes (no change required)

- The witness needs mass-1 items and a container capacity above ~1.2e16 g; `FILTERS_ACCEPT_ALL` with
  `INT64_MAX` capacity is already proven to work by the probe. Existing fixture masses (250/5000)
  force a dedicated inventory fixture or a separate test file — the contract already permits one.
- Exact-`I64_MAX` coverage is reachable with `4611686018427387903 + 4611686018427387904`.
- The injected per-lot audit overflow follows the established pattern in
  `_assert_audit_bounds_reserved_by_quantity`: two structurally valid rows on one lot, direct
  `_r_quantity_milli` bump, assert `REFUSE_OVERFLOW`, restore, re-assert green. Occupancy, links and
  positive-quantity properties all remain intact, so no earlier audit branch is disturbed.
- "No owner/scratch mutation" is directly observable from GDScript tests, which already reach private
  members: assert `_pool._math.ok`/`value`/`error` and `_pool._pending_new_rows` unchanged across both
  query forms, and assert `_inv.audit().ok` plus `state_bytes()` equality.
- The skipped-mutant obligation is satisfied: replacing `checked_add_into` with `+=` makes the
  witness test report a wrapped success instead of a refusal.

## 6. Residual risk

The census predates the columns PR and the change alters the **type**, not just the behaviour, of two
existing public names. Require a fresh repository-wide grep for both names at the exact head the
implementation branches from, recorded in the evidence folder, before acceptance. Serialization after
the columns PR and single-writer ownership of `reservations.gd` are correctly specified and should be
enforced.
