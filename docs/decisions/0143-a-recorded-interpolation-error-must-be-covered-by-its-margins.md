# 0143 — A recorded interpolation error must be covered by its margins
Date: 2026-09-14 · Status: Accepted

## Decision

Movement envelope input records move to **schema version 2**.
`measurement.interpolation_error_bound_units` is now defined as the **residual**
conservative interpolation error the submitted extrema do **not** already
enclose, it bounds every axis, and
`tools/validate_movement_envelopes.py` **refuses** any record whose
`margin_units.x`, `.y` and `.z` are not each at least that residual.

Four supporting rules ship with it:

1. **A zero residual needs written evidence.** `zero_residual_evidence` is
   required whenever the residual is `0`, because MOVE-C3-R01 §6 permits zero
   only when the owner establishes that the extrema already enclose the full
   continuous sweep. A zero residual with a justified zero margin is then legal:
   the same error is not counted a second time.
2. **A `zero_margin_justification` cannot cover a positive residual.** The
   refusal is arithmetic, and prose does not move a bound. MOVE-C2-R01 §3's
   explicit-zero allowance still stands for the case where nothing is uncovered.
3. **The micrometre export direction is declared per record.** New required
   field `micrometre_export_rounding`, one of `minima_floor_maxima_ceil` (rounded
   outward at export) or `certified_residual_allowance` (not rounded outward,
   which then requires a strictly positive residual to carry the discarded
   precision). Nearest and truncation are not offered. `export_minimum_micrometres()`
   and `export_maximum_micrometres()` implement the outward conversion from an
   exact rational, refusing a nonpositive denominator.
4. **Schema 1 is refused by name, never migrated.** `schema_version_problems()`
   reports a version 1 document as a historical record that may be read as
   history but cannot qualify, and states that no automatic migration is
   performed; its owner must reassert error coverage and source evidence as
   version 2.

Enforcement runs in two independent places: `record_semantic_problems()` before
any fit is attempted, and `compute_fit()` itself, which returns the new outcome
`UNCOVERED_INTERPOLATION_ERROR` rather than a class. A caller that skips
validation still cannot obtain `FIT_OK` from an uncovered record.

## Why

ADR 0141's anchored-fit arithmetic is sound and its 124 checks passed — and it
did not enforce what it recorded. Schema 1 made
`interpolation_error_bound_units` **required** and then never read it: neither
`record_semantic_problems()` nor `_quantized_local_bounds()` used the field.

Cycle 3's probe, `docs/validation/cycle03_movement_probe.py`, reproduces the
consequence exactly. A synthetic box with X/Z extrema ±250000 µm, baseline
offset 256, an explicit zero margin with its justification, and a declared 1 u
residual passed schema, file and record validation with no problems and returned
`FIT_OK`, clearance class 1. Applying that same 1 u as a margin makes the
translated minimum −1 and the maximum 513, which is
`PLACEMENT_INCOMPATIBLE_AT_OFFSET`. So the record that passed and the record
that refuses describe the same declared body; `FIT_OK` was not a complete
measurement-bound check.

Rounding inward is the bug class, and it has an earlier instance than the fit.
The conversion from a measured coordinate into the signed integer micrometres
this file commits happens **before** the tool sees anything, and the tool cannot
reconstruct precision discarded there. A maximum of 250000.25 µm truncated to
250000 µm quantizes to 256 u instead of the 257 u it needs, and lands exactly on
a class boundary it does not actually fit. Later outward u-quantization does not
repair it. Hence the declared export direction and the outward export helpers.

## Consequences

This is still tooling, and it **closes no movement gate**. It qualifies no real
envelope: **no measured body dimension exists**, and none is invented here. No
dimension, margin, speed or cost appears in this change; every fixture value
stays synthetic and labelled, and the `data_class` separation is unchanged — a
`synthetic_fixture` carrying provenance is refused, a `measurement` lacking it is
refused.

`PLACEMENT_INCOMPATIBLE_AT_OFFSET` is untouched and remains the tool's most
valuable property: a negative translated minimum is a placement problem that no
clearance class repairs, still proven by the exhaustive 1..512 scan rather than
asserted. The new `UNCOVERED_INTERPOLATION_ERROR` sits beside it as a fifth
distinguishable refusal; it does not absorb it. `require_class()` still raises
and returns no sentinel.

Every existing record file must be reauthored at version 2, adding
`micrometre_export_rounding`, adding `zero_residual_evidence` where the residual
is zero, and widening any margin that does not cover a declared residual. Only
the labelled synthetic fixtures exist today, so nothing measured is invalidated.
The synthetic fixture set grows from six files to ten: four new malformed files
cover the uncovered residual, the unevidenced zero, an inward export and a
version 1 document.

Astra's probe now **fails its own reproduction**, which is what its docstring
asks for: "a corrected checker should fail this reproduction rather than be
changed to preserve it." The probe file is left byte-untouched.

`godot/scripts/core/spatial_world.gd` remains read-only to this work and
unchanged. `docs/planning/movement_profile_*.{md,json}` belongs to another lane
and was not touched.

## Source

[MOVE-C3-R01 §6](../rulings/2026-09-14_cycle03_movement_policy.md), acceptance
cases T1–T3; [MOVE-C2-R01 §§3–5](../rulings/2026-09-14_cycle02_movement_envelopes.md);
[Cycle 3](../planning/astra_cycles/cycle_03.md), "Movement progress and the new
defect"; [ADR 0141](0141-a-placement-refusal-is-not-a-clearance-class-refusal.md),
which this corrects rather than replaces. Lane record:
[docs/tasks/lanes/05/2026-09-14-cycle03-envelope-error.md](../tasks/lanes/05/2026-09-14-cycle03-envelope-error.md).
