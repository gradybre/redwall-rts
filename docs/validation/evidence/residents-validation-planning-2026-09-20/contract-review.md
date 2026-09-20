# Residents owner 12 contract review — RESIDENTS-S4-VALIDATE-R01 v1

2026-09-20. Source-only, read-only, not dispatch authority. Nothing here was built, run or
measured; every figure is arithmetic over the supplied sources.

## Confirmed against source

The nineteen columns, their ordinal order, type codes and extents match `residents.gd`
`COLUMN_KEYS`/`COLUMN_TYPE_CODES`/`COLUMN_EXTENTS`, the `Columns` field order, and the compiled
schema for owner 12 (`residents`, version 2, primary 512, child 0, field begin 236, count 19,
payload 103068, block 103101, offset 9447326; owner 13 at 9550427). `ROLE_WARDEN = 1` and
`ROLE_SPECIALIST = 2` are as the contract pins them. `_name_key` and `_selected` are correctly
absent.

A pure `columns_refusal(Columns)` plus a Needs-shaped seven-gate bridge is feasible: nothing in
shape, byte domains, skill XP/level/reserved, reference and equipment shape, the free-row rule or
the present-count bound reads instance state. ADR 0132 forbids nineteen positional arguments, and
the bridge can build `Columns` without constructing `Residents`, so no catalog, Directory or Needs
collaborator is created. Keeping `_catalog_error` ahead of the shared prefix and leaving the live
per-row species/size/arrival/Directory walk in place preserves today's diagnostics; calling the
saved predicate from live restore would indeed hoist a later row's arrival fault above an earlier
row's size or Directory fault, so the contract is right to forbid it.

The instance `skill_level_for_xp` wrapper over one static curve helper, the shared null guard
returning the existing `COLUMN_SHAPE`, the `INVALID_ARRIVAL_TICK` producer refusal after
`NOT_PRESENT`, and full signed i32 species / i64 arrival on inactive rows are all consistent with
the probe record and with `_column_free_row_refusal`, which bounds neither.

Budget: 102912 caller + 102912 default `Columns` buffers + 49152 largest int64 sort copy = 254976
logical packed bytes, under the 6417408 allowance. Cold Refusal/Columns/native overhead is
unmeasured and the contract says so.

The metadata counterfactual plan rebalances payloads, blocks, offsets and both totals coherently,
and the field-count case appends a new owner-10 field so all nineteen Residents fields survive.

## Observed evidence, restated without inference

The public probe reports 39 assertions / 0 failures. Both null probes returned `false` with
`COLUMN_SHAPE` **and** emitted a real SCRIPT ERROR at `_columns_are_capacity_sized`; exit 0 is
therefore not evidence of a clean refusal, and repaired acceptance needs new tests that fail on any
SCRIPT ERROR rather than a rerun of these logs.

## Mutants and oracles

The tally is arithmetic-correct: 19+5+3+4+3+6+1+2+2+1+1+1 = 48.

The nineteen projection omissions are the weak set. An omitted assignment leaves a canonical
`Columns` default that is itself legal, so a *legitimate-value* fixture cannot kill it. Each one
needs a witness malformed **in that field** — species 16, a zero generation, negative XP, a
level off the curve, item −2, durability without a tool, a named free row — where the oracle is
"the bridge accepted an image it must refuse". State that explicitly; an exact-code assertion that
kills an omission which would still refuse later must be labelled as such.

Likely equivalents: the redundant free-row halves the contract already names, and any
free-row clause whose violation is also caught by an earlier shape or equipment rule. The null-guard
mutant is a runtime-error oracle, not an assertion kill, and must require `false` +
`COLUMN_SHAPE` + the exact known Nil error; unrelated parser failures are not kills.

Declaration-array parity cannot conspire provided the metadata faults perturb the schema side only
while the Residents side stays pinned to literals (19, key strings, type codes, extents), which the
bridge pin list does.

## Blockers and bounded repairs

1. **Omission oracles unspecified.** Repair: name one malformed witness per field in acceptance
   item 2 before authoring.
2. **6144-address coverage cost unknown.** Repair: bound the per-address XP/level tests to one
   focused fixture and time that fixture before freezing mutation-harness limits. Do not assert a
   duration until measured.
3. **Null-guard oracle phrasing.** Repair: separate "runtime error detected" from "assertion
   killed" in the mutant table.

Optional, separate: a legacy-priority fixture note recording that the catalog-error path stays
source-reviewed, and a short statement of why no production corruption setter is added.

Unresolved and correctly deferred: saved catalog, Directory identity/uniqueness, Needs and death
barrier, §14 names, equipment ownership, lifecycle and cap reconciliation.
