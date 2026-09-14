# 0141 — A placement refusal is not a clearance-class refusal
Date: 2026-09-14 · Status: Accepted

## Decision

MOVE-C2-R01's measurement and fit convention is implemented as
`tools/validate_movement_envelopes.py` against
`docs/planning/movement_envelope_schema.json`, and the anchored fit reports
**four distinguishable refusals**, not one failure. In particular a swept body
whose translated minimum falls behind the north-west anchor returns
`PLACEMENT_INCOMPATIBLE_AT_OFFSET`, never `CLEARANCE_CLASS_EXCEEDS_DOMAIN`.

Four supporting choices go with it:

1. **Measured extrema are committed as exact signed integer micrometres.**
   MOVE-C2-R01 3 permits floating point during offline measurement; the float
   crosses into the repository when the record is authored, and every step after
   that — quantization, translation, class derivation — is exact integer
   arithmetic. There is no float in the schema, the validator or the tests.
2. **The map geometry is parsed from the GDScript that owns it**, not copied.
   `CELL_SIZE_UNITS`, `CELL_CENTRE_OFFSET_UNITS`, the 1..512 clearance domain
   and the grid size come from `godot/scripts/core/spatial_world.gd`; mode and
   life-stage ids come from `movement.gd` and `residents.gd`. A record file must
   declare the same values and is refused when it disagrees.
3. **Every record carries a `data_class` discriminator.** A `synthetic_fixture`
   must carry a note and may not carry provenance; a `measurement` must carry
   provenance and may not carry the note. An invented number can therefore never
   be read, reported or copied as a measured body dimension.
4. **The JSON Schema subset is closed.** The validator refuses a schema that
   uses a keyword it does not enforce, so a constraint cannot be added to the
   schema and silently never checked.

## Why

The clearance square is anchored at its **north-west corner** and grows south
and east with `k`. The baseline root offset is `+256/+256`. The containment
conditions are `ox+xlo >= 0`, `oz+zlo >= 0`, `ox+xhi <= 512k`, `oz+zhi <= 512k`
— and the first two **do not mention `k` at all**. A body wide enough to sweep
behind its own root therefore fails at every class in the domain. Reporting that
as "needs a larger clearance class" is false, and sends a reader searching for a
`k` that does not exist; the tool proves the point instead of asserting it, by
scanning all 512 published classes and reporting that zero of them admit the
body.

The naive `ceil(max(width, depth) / 512)` answers a small class for exactly this
case, which is why MOVE-C2-R01 4 says it is only a lower bound. The validator
still computes it, and prints it beside the real outcome so the gap is visible
rather than assumed.

Rejected: re-centring the square, clamping the bounds, or relocating the root.
MOVE-C2-R01 5 requires a separately reviewed MOVE-G02 position/anchor/save
contract for any placement other than the baseline, so a non-baseline offset in
a record is accepted for **measurement and report only** and labelled as such.
Also rejected: a sentinel class (`-1`, `0`) for a refused fit. `require_class()`
raises; there is no number to leak into a downstream comparison.

## Consequences

This is tooling. **It closes no movement gate.** MOVE-C2-R01's Q2 per-species
policy/cost rows remain OPEN, no measurement exists, and a `FIT_OK` record is
not an authored profile, not an enabled mode and not permission for a species to
travel. A missing record refuses as a missing contract and is never evidence of
biological inability.

`godot/scripts/core/spatial_world.gd` is read-only to this work and unchanged.
The schema has no compiled enum number and no packed-storage claim: MOVE-G02
still owns those. `tools/test_movement_envelopes.py` is not yet wired into
`.github/workflows/tests.yml`, which this lane does not own; adding it is a
follow-up for whoever owns that file.

## Source

[MOVE-C2-R01](../rulings/2026-09-14_cycle02_movement_envelopes.md), Q1 items
1–7 and the residual-gate table;
[Cycle 2](../planning/astra_cycles/cycle_02.md), "Exact change boundaries";
[ADR 0140](0140-cycle-two-inventory-projection-and-movement-measurement.md).
Lane record:
[docs/tasks/lanes/05/2026-09-14-envelope-tooling.md](../tasks/lanes/05/2026-09-14-envelope-tooling.md).
