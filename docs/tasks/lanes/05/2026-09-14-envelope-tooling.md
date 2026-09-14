# Movement envelope tooling — MOVE-C2-R01's measurement and fit method, executable

Task: 05_movement_first_playable.md
Date: 2026-09-14

Lane: MOVE-ENVELOPE-TOOLING. Base `origin/master` at `26f1f8f`.
Engineering record: [decision 0141](../../../decisions/0141-a-placement-refusal-is-not-a-clearance-class-refusal.md).

## What landed

Three new files, plus the ADR and this record:

- `docs/planning/movement_envelope_schema.json` — the shape a **measured** swept
  envelope record must take: identity, variant (gear, cargo, support
  attachments), the swept extrema, the explicit per-axis margin and its
  provenance, the declared anchor-to-root offset, and a `data_class`
  discriminator that separates a measurement from a synthetic fixture.
- `tools/validate_movement_envelopes.py` — validates records against that schema
  and computes MOVE-C2-R01 3–5's anchored fit in exact integer arithmetic.
- `tools/test_movement_envelopes.py` — 124 checks, negative cases first.

**This lane measured nothing.** There is no body width, height, gear extent or
load bound in any of these files. Every dimension present is a synthetic test
constant under an invented species key (`synthetic_specimen_alpha`), labelled as
such in the record itself and refused by the validator if it ever tries to carry
provenance. MOVE-C2-R01's Q1 convention is what this implements; **Q2 per-species
production profiles remain OPEN**, no movement gate is closed here, and a
`FIT_OK` record is not an authored profile, not an enabled mode and not
permission for any species to travel.

## The result the ruling asked to be reproduced

At the baseline `+256/+256` root offset, a swept body whose translated minimum
falls behind the north-west anchor is **incompatible with the clearance square
at any class**. The square grows south and east from its anchor, and the failing
conditions `ox+xlo >= 0` / `oz+zlo >= 0` never mention `k`.

The validator reports that as `PLACEMENT_INCOMPATIBLE_AT_OFFSET`, distinct from
`CLEARANCE_CLASS_EXCEEDS_DOMAIN`, and **proves it rather than asserting it**: it
scans the whole published 1..512 domain and reports how many classes admit the
body. On the synthetic wide fixture that count is 0 of 512, while the naive
`ceil(max(width,depth)/512)` lower bound answers class 2 — which is exactly why
MOVE-C2-R01 4 says that bound never replaces containment. The test suite repeats
the scan with a containment predicate written out longhand in the test file, so
the module's own helper is not the judge of its own claim.

Re-centring is not offered, proposed or implemented. Any offset other than the
baseline is accepted for measurement and report only, flagged
`NOT baseline: report only`, and needs a reviewed MOVE-G02 position/anchor/save
contract before production use.

## Evidence

```
python3 tools/test_movement_envelopes.py
test_movement_envelopes: PASS -- 124 check(s), 0 failure(s)

python3 tools/validate_movement_envelopes.py --emit-synthetic-fixtures DIR   (exit 0)
  DIR/synthetic_fits_class_1.json            -> PASS,          exit 0
  DIR/synthetic_placement_incompatible.json  -> DOES_NOT_FIT,  exit 2
  DIR/malformed_*.json  (four files)         -> REFUSE,        exit 1 each
  no file named                              -> REFUSE,        exit 1

./tools/run_tests.sh
ok: 4338 tests, 152837 assertions, 0 failures.
```

Seventeen mutants, one per invocation, each file restored and `shasum -a 256`
byte-compared against a pristine copy afterwards. **All seventeen killed**,
including the four the brief required: the anchor offset dropped; quantization
rounded inward (both signs, and the margin applied inward); the class bound off
by one (both the domain bound and the ceiling division); and the negative
translated minimum reported as a class problem. Also killed: the placement check
removed entirely, the exhaustive scan admitting everything, `require_class()`
returning a `-1` sentinel instead of refusing, the int32 range check dropped, and
schema validation, record semantics and the schema-keyword closure each replaced
by "always passes".

## Not done here, and why

- `tools/test_movement_envelopes.py` is **not wired into
  `.github/workflows/tests.yml`**, which this lane does not own. Whoever owns
  that file should add it beside the other `tools/` self-tests.
- `godot/scripts/core/spatial_world.gd` was read only and is byte-unchanged. The
  validator parses `CELL_SIZE_UNITS`, `CELL_CENTRE_OFFSET_UNITS`, the 1..512
  clearance domain and the grid size out of it, and the mode and life-stage ids
  out of `movement.gd` and `residents.gd`, rather than restating any of them.
- No task checklist box is ticked by this lane: the measurement, profile and
  qualification gates it would touch are all still open.
