# MOVE-ENVELOPE-ERROR — enforce the interpolation error the record already declares

Task: 05_movement_first_playable.md
Date: 2026-09-14

Lane: MOVE-ENVELOPE-ERROR. Branch `feat/move-envelope-error`, base `origin/master` at `388f4f4`.
Engineering record: [decision 0143](../../../decisions/0143-a-recorded-interpolation-error-must-be-covered-by-its-margins.md).

Corrects a defect already merged on master. PR121's anchored-fit arithmetic is
sound; it did not enforce what it recorded.

## Reproduced first, before any change

Astra's retained probe, `docs/validation/cycle03_movement_probe.py`, run against
a fresh worktree of `388f4f4` (checker sha256
`6b2fe4f340d1f5336891ba691f04bebf1a63031d6a1d723f3681401c9324463a`):

```
{"admitting_class_count": 512, "clearance_class": 1, "margin_u": 0, "outcome": "FIT_OK",
 "residual_error_u": 1, "translated_bounds": {"x_hi": 512, "x_lo": 0, "z_hi": 512, "z_lo": 0},
 "validation_errors": []}
{"admitting_class_count": 0, "clearance_class": null, "margin_u": 1,
 "outcome": "PLACEMENT_INCOMPATIBLE_AT_OFFSET", "residual_error_u": 1,
 "translated_bounds": {"x_hi": 513, "x_lo": -1, "z_hi": 513, "z_lo": -1}, "validation_errors": []}
OBSERVED DEFICIENCY REPRODUCED: uncovered error passes; covering it refuses placement.
```

A declared 1 u residual with zero margins passed every check and was handed
`FIT_OK` class 1. Accounting for that 1 u gives translated bounds −1..513, which
correctly refuses placement. `interpolation_error_bound_units` was **required**
by schema 1 and read by nothing.

## What changed

Schema 2 (`docs/planning/movement_envelope_schema.json`):

- `schema_version` const `1` → `2`.
- `interpolation_error_bound_units` re-meant as the **residual** error the
  submitted extrema do not enclose; it bounds every axis.
- new `zero_residual_evidence` (required by the validator when the residual is 0).
- new required `micrometre_export_rounding`, enum
  `minima_floor_maxima_ceil` | `certified_residual_allowance`.

Validator (`tools/validate_movement_envelopes.py`):

- `residual_error_problems()` — each axis margin must be at least the residual,
  checked independently and named per axis. A `zero_margin_justification` does
  not cover a positive residual. An absent or negative residual refuses; it is
  never read as zero.
- `export_rounding_problems()` — a non-outward export must carry a strictly
  positive residual. Nearest and truncation are refused.
- `export_minimum_micrometres()` / `export_maximum_micrometres()` — outward
  rounding at the earlier export boundary, from an exact rational, integers only;
  a nonpositive denominator refuses.
- `schema_version_problems()` — version 1 named as historical and explicitly not
  migrated; version 2 is the only implemented version.
- `compute_fit()` gains the fifth outcome `UNCOVERED_INTERPOLATION_ERROR`, so a
  caller that skips validation still cannot reach `FIT_OK`.
- four new malformed fixtures; the set grows from six files to ten.

`PLACEMENT_INCOMPATIBLE_AT_OFFSET` and its exhaustive 1..512 scan are unchanged.

## Probe after the fix

Checker sha256 `a69bdd136dd80df0a7421b4f179f18ec8f87457c723e91589f1975b1f0c19dd6`.
The probe now fails its own reproduction at `assert not errors`, which is what
its docstring asks for:

```
AssertionError: ['$.records[0].margin_units.x: allowance 0 does not cover the declared
residual interpolation error of 1 unit(s). ... A zero_margin_justification cannot cover a
positive uncovered residual: prose does not move a bound.', ... .y ..., ... .z ...]
```

The probe file itself is byte-untouched.

## Verification

- `godot --headless --path godot --editor --quit` — exit 0, run first in the
  fresh worktree.
- `python3 tools/test_movement_envelopes.py` —
  `test_movement_envelopes: PASS -- 191 check(s), 0 failure(s)` (was 124).
- `./tools/run_tests.sh` — `ok: 4355 tests, 155623 assertions, 0 failures.`
- Mutation testing, one mutation per invocation, `shasum -a 256` byte-compare
  after every restore: 16 mutants, 16 killed, 0 survived. The first pass had
  three survivors (M11, M15, M16), each a rule covered by both the schema and
  the semantic layer where the test only saw their union; `test_the_schema_and_
  the_semantic_layer_each_refuse_on_their_own` now exercises each layer alone.

## What this does NOT do

It qualifies **no real envelope**. No measured body dimension exists, and none
is invented here: no dimension, margin, speed or cost. Every fixture value stays
synthetic and labelled, and the `synthetic_fixture` / `measurement` provenance
separation is unchanged. MOVE-G01/G02 and Q2's per-species rows remain open.
