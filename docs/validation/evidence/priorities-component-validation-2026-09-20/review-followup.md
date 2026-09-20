# Review follow-up — PRIORITIES-S4-VALIDATE-R01 v1 / ADR 0171

Date: 2026-09-20. Bounded follow-up to `source-review.md`, reading `source-review-disposition.md`,
`review-cleanup.md` and the supplied sources. **I ran nothing, edited nothing and applied nothing**;
every statement below is a reading. Settled production and gameplay decisions are not reopened.

## The one production change

`_is_priority_column()` now iterates `PRIORITY_MAX - PRIORITY_MIN + 1` integer offsets and sums
`column.count(PRIORITY_MIN + offset)`, requiring the total to equal `column.size()`.

- **Bounds equivalent.** With MIN 0 and MAX 4 the count is 5 and the sampled values are 0,1,2,3,4 —
  exactly the former `range(PRIORITY_MIN, PRIORITY_MAX + 1)` sequence. Both named constants are still
  read, so the inclusive domain is declared rather than assumed, and nothing depends on MIN being 0.
  If the constants were ever narrowed so MAX < MIN, the iteration count is non-positive and the loop
  body is skipped, which is the same empty sequence the old `range()` produced; behaviour under a
  hypothetical future edit is unchanged, not newly defined.
- **No allocation.** `for offset: int in <int>` is integer-count iteration and builds no Array. The
  five-element temporary is gone; no packed buffer, duplicate, slice or per-row object is introduced.
  Coverage is still exact over all 6144 bytes via the same five `count()` passes, so the 7680-byte
  caller-image accounting and the "adds no packed buffers" claim both stand unchanged.
- **Scope.** Gate order, codes, details, field mapping, helper sharing and every other reader,
  mutator and lifecycle path in `priorities.gd` are untouched. No schema, owner-version or
  canonical-state change; no gameplay behaviour is affected.

## Diagnostic assertion

The framed failure path now asserts `detail.contains("Priorities owner 11 ")` beside the exact-code
substring. That is the full owner-label fragment, so the loose `"11"` match — which 511 and other
numbers satisfied — is resolved. Both assertions must hold, so the owner identity and the returned
column code are each pinned.

## Dispositions accepted

- `FLAG_ELEMENT_COUNT`: fail-closed only. Metadata compares each extent and owner primary to 512 and
  the predicate checks its own capacities, so drift yields a false refusal, never a false accept.
- 6144-byte sweep: predicate-level by design. Framed accessors hand whole columns to that same
  predicate, all four mappings have substitution witnesses and the final byte also runs the bridge.
- Clone symlinks: not claimed as an OS-enforced sandbox. The probe writes only explicit clone paths
  and the `finally` guard verifies the three product sources byte-identical.
- **Correction to my earlier prose:** the primary fault moves one row from owner 12 to owner 11
  (513/511), the reverse of what I wrote. The descriptor-row total is unchanged and the fault still
  reaches gate 4, so the reading and the recorded assertion results are unaffected.

## Status

No source blocker. Pre-cleanup evidence — full suite 4895 tests / 216053 assertions / 0 failures with
553 objects and 33 resources, and all eight mutants killed against a 33/7585/0 baseline and restored
run — is archived under `before-review-cleanup/` for its original source SHA and no longer pins the
current files. Regenerating the source hash sidecar and rerunning focused, full, mutation and
exact-head CI against the final source remain required merge gates; I cannot and do not confirm those
runs. Do not mark SAVE-S4-SEMANTICS or owner bindings complete from this primitive.
