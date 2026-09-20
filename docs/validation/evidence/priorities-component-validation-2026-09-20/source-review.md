# Independent source review — PRIORITIES-S4-VALIDATE-R01 v1 / ADR 0171

Date: 2026-09-20. Scope: `priorities.gd`, `save_owner_priorities.gd`, `test_save_owner_priorities.gd`,
`test_priorities.gd`, `tools/test_priorities_metadata_preflights.py`, the CI wiring and the two
recorded evidence artefacts. I read the supplied sources only. **I ran nothing, edited nothing and
applied nothing**; every statement about execution below is a reading of the recorded logs, not a
run claim. Settled decisions — no 256 living cap here, spawn defaults, deferred bulk capture/apply,
cross-owner publication — are out of scope and are not reopened.

## Verdict

**No source blocker found.** Two required evidence layers are outstanding and are contract merge
gates, not defects in the shipped code. Four minor non-blocking notes are recorded.

## Predicate and shared helper

`columns_refusal()` is `static` over four typed packed arguments. It builds no live owner, no
`Columns` object, no default buffer, no derived occupancy array and no per-row object, and calls no
`duplicate()`, `slice()` or `sort()`. Gate 1 tests all four extents in one guard of `size()` calls
before any indexed read, so an empty or short column cannot reach a subscript. The order is exactly
the contract's: shape, presence, `auto_fallback`, `dangerous_work`, priority range, reserved index,
free row, then `REFUSE_NONE`. The two flag gates carry distinct codes and are checked auto-then-
dangerous, so a transposition at the argument boundary is observable whenever only one column is out
of domain.

Domain coverage is exact rather than sampled. `_is_flag_column()` requires `count(0) + count(1) ==
size()`, which covers every byte of each 512-byte column. `_is_priority_column()` sums `count()` over
0..4 and requires the total to equal `size()`, covering all 6144 bytes including the reserved index.
Both the reserved sweep and the free-row sweep iterate `PRIORITY_CAPACITY`, so slots 0 and 511 are
included. Indices use the physical `slot * JOB_KIND_COUNT + kind` formula throughout.

`_free_row_is_clear()` is the single static definition the contract demands: complete typed
signature, no presence argument, no live presence read, symmetric flag checks. `inactive_row_is_clear()`
retains its prior public guard verbatim — negative slot, slot past capacity, and present row all
return false — and delegates only afterwards. The validator reaches it only after full shape and
domain admission. No other ordinary behaviour was refactored; every existing mutator, reader and
refusal code in `priorities.gd` is unchanged.

## Framed bridge

Preloads are limited to Priorities, Schema, Section and SaveHeader. There is no instance state, no
clock, no I/O, no reflection and no registry walk; the record is not retained. Gate order is null →
`SAVE_COMPONENT_SHAPE`, owner ≠ 11 → `SAVE_COMPONENT_OWNER`, `Schema.schema_refusal()` returned
unchanged, metadata, `Section.owner_shape_refusal()` returned unchanged, then the predicate. Gates 3
and 5 return the upstream `Refusal` object directly, so code *and* detail are forwarded verbatim.
Gate 4's details all begin with the pinned `Priorities owner11 metadata:` prefix, which is what
separates it from gate 3's shared `SAVE_COMPONENT_METADATA` code.

The four accessor ordinals map in canonical order: `u8_column(0,1,2,3)` →
`(present, job_priority, auto_fallback, dangerous_work)`, matching `FIELD_KEYS[232..235]` of owner 11
(`_present`, `_job_priority`, `_auto_fallback`, `_dangerous_work`). All four are u8, so
`storage_index()` equals the ordinal. Nothing is duplicated or substituted: the accessors return the
record's own COW buffers straight into the predicate, so the 7680-byte caller image is charged once
and no packed memory is added. The column code is returned raw and unwrapped, with a detail naming
owner 11 and that code.

The metadata guard compares the compiled schema against pinned literals and cross-checks
`Priorities.PRIORITY_CAPACITY`, `Priorities.JOB_KIND_COUNT` and the 512 × 12 = 6144 product. The
header is explicit that this is *not* an owner-publication-table parity check and that the generator
and source-capacity audit remain the independent proof against actual declarations; that claim is
correctly bounded.

## Counterfactual metadata faults

All eight faults are schema-valid disagreements that reach gate 4, not hidden parse or framing
errors. I checked the arithmetic of each rebalance:

- `primary` moves one row from owner 11 to owner 12 (513/511), leaving the 193184 descriptor-row sum
  and every payload untouched, since payloads derive from field counts.
- `children` moves the child extent from owner 10 to owner 11, shifts `OWNER_CHILD_BEGIN[11]` to 4,
  moves ±8 bytes between the two payload/block lengths and pulls owner 11's offset back by 8, so the
  walk's field, child and offset cursors all still reconcile and the extent stays positive.
- `field_count` moves Residents' leading u8[512] field into owner 11 (±520 bytes, `FIELD_BEGIN[12]`
  → 237), keeping the 298-field total and the walk cursors consistent.
- `field_type` (u8 → i32, +1536) and `field_extent` (512 → 513, +1) both recompute the owner payload,
  owner block, the downstream offsets and *both* `SECTION_BYTES` and `EXPECTED_SECTION_BYTES`.
- `key` preserves the 10-byte key length and strict ASCII order between `orchard_hive` and
  `residents`; `version` and `field_key` need no length change.

The probe asserts `Schema.schema_refusal()` is clean and `Section.owner_shape_refusal()` is ok before
calling the bridge, so gate 3 and gate 5 are excluded by construction and gate 4 is the observed
gate. Each bypass run replaces one gate expression with `false`; in every case the bridge then either
accepts or returns a column code, so the pinned `SAVE_COMPONENT_METADATA` assertion fails and the
bypass is killed — the recorded JSON shows eight `killed_bypass: true` cases with valid execution and
no script or parse errors. The `schema-first-forwarding` case perturbs `OWNER_OFFSETS[0]` so gate 3
fires, and asserts the detail equals the schema module's own detail, which is the right way to show
that the shared code alone does not identify the gate. Totals reconcile: 1 + 8×2 + 1 = 18 cases ×
9 assertions = 162.

Harness integrity is real: the tree is copied to a temp clone, edits land only there, and the
`finally` block re-reads and asserts the three production files byte-for-byte against their
pre-recorded contents, with SHA-256 digests printed. The production generator and capacity audit
remain pinned by the separate `contracts` job, which the counterfactual tables never touch.

## Tests

The parent tests are genuinely adversarial rather than restatements of the implementation. Fixture
extents, field keys and the owner index are local literals that the schema is then asserted *against*.
Every `_expect()` compares the static and framed answers, pins the success/failure channel, and
re-checks all four caller columns byte-for-byte afterwards. The substitution witnesses are asymmetric
as required — present 2 vs a zero substitute yielding `COLUMN_FREE_ROW`, priority 5 vs an accepted
zero, and one flag set while the other is clean — and the all-zero frame is used only as the positive
empty control. The flag-swap witness (`auto = 0`, `dangerous = 255`) does kill a transposed argument
pair; the paired case where both flags are invalid pins ordering only, which is correct but is not
itself a swap witness. Refusal order is exercised across distinct rows, and the shape check is shown
to precede every indexed read. `test_public_lifecycle_and_shared_free_row_reader` admits real
lifecycle output, including non-default player priorities and consent, and confirms validation does
not disturb `present_count()`.

## Blockers and material gaps

1. **Full suite not run.** Recorded evidence is the focused run only: 33 tests, 7585 assertions, 0
   failures on pinned 4.7.2. The contract requires focused *and* full suites plus exact-head CI
   before merge. Outstanding.
2. **The eight projection/domain/precedence mutants are not in this packet.** Four zero-substitution
   mutants, the flag-swap mutant, reserved omission, free-row omission and the reserved/free
   precedence mutant are stated to be running separately. I can confirm the fixtures *would* kill
   them by reading the exact-code assertions, but I cannot confirm the runs. Outstanding.

## Minor, non-blocking

- `_is_priority_column()` calls `range(PRIORITY_MIN, PRIORITY_MAX + 1)`, allocating a five-element
  Array per call. Tiny and not a packed buffer, but it is an allocation the accounting does not
  mention; `for value: int in PRIORITY_MAX + 1` would remove it while `PRIORITY_MIN` is 0.
- `FLAG_ELEMENT_COUNT` is never cross-checked against `OWNER_PRIMARY_COUNT`. The failure mode is a
  false refusal, not a false accept, and gate 6 re-checks extents against the owner's own constants,
  so this is defence-in-depth only.
- The framed failure assertion uses `detail.contains("11")`, which 511 and other numbers would also
  satisfy. The code-substring assertion beside it carries the real weight.
- `test_every_physical_priority_byte_is_checked` sweeps all 6144 bytes through the static predicate
  and only the final case through the bridge; that is a reasonable cost trade, but the per-byte
  guarantee is a predicate-level one.
- The disposable clone symlinks the live `docs/` and `assets/` trees. No current suite writes there,
  but a future test that did would escape the sandbox.
