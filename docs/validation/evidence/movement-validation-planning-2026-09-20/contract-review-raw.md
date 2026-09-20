# Movement section 4 contract review — MOVEMENT-S4-VALIDATE-R01 v1

Independent read-only review. Nothing was executed, imported, mutated or edited. The candidate is
not accepted here. SET-MOVE-001 scope is unchanged: this block is ground motion only and closes no
MOVE gate. Gameplay modes and MOVEMENT-SAVED-BINDINGS remain separate.

## 1. Layout

Re-derived without reusing the candidate's totals: values 16 x 512 x 4 = 32768; payload
4 + 0 + 16 x 8 + 32768 = 32900; block 24 + 8 + 32900 = 32932. Owner 8 `movement`, version 1,
primary 512, child extents 0, field begin 171, sixteen (type 2, count 512) fields. All agree with
source-layout.json.

**Finding A, act before dispatch.** The contract's ordinal table is *schema* order. movement.gd
declares `_grid_next`/`_grid_cell` before `_radius_u`/`_speed_u_per_s`, so an implementer copying
declaration order produces four mislabelled canonical keys that still pass every shape check. State
that ordinals come from FIELD_KEYS[171..186], never from the source file.

## 2. Ordered domains against the actual writers

shape -> phase -> reserved -> remainder -> speed -> velocity -> cell -> target -> state, ascending
physical rows, is consistent with `_allocate_motion`, `_allocate_cursors`, `_reset_motion`,
`_attach_route`, `_advance_row`, `_spend_budget`, `_arrive_at_target`, `_advance_cursor_target`,
`_integrate_axis`, `_settle` and `stop`. Confirmed specifically:

- Retained ARRIVED velocity is real: `_spend_budget` may settle ARRIVED mid-tick, then
  `_advance_row` writes `vx = here_x - _pose.x` afterwards. Restricting zero velocity to phases 3-5
  is correct; every 3-5 settle precedes that write or overwrites it.
- The zero one-cell target is real: `_attach_route` -> `_advance_cursor_target` settles ARRIVED on
  `_reset_motion`'s zero pair with a valid `grid_cell`.
- A non-zero ARRIVED target always equals centre(grid_cell), because `_arrive_at_target` assigns
  `grid_cell = grid_next` before the target is re-pointed.
- Stale fractions: `_settle` retains remainders, `stop` clears them, so "IDLE zero, 2-5 retained
  0..419" has no counterexample. `stop` also retains speed and `grid_cell`, as the contract allows.
- Velocity: per-axis released budget is `(speed*factor + r)/420`, factor <= 14, r <= 419, integrated
  once per tick, so `|v| <= (speed+29)/30` is exact at 110/137/103.

I found no public writer counterexample to any proposed restriction.

## 3. Indexing, overflow, preload

The null/extent gate before indexing is correct and the 49 shape witnesses (1 + 16 x 3) cover it.
Peak magnitudes are 57763 (modulus input), 261888 (centre) and 137 (velocity): i32-safe. Use the
two-sided `-limit <= v <= limit`, never `abs(v)`, so INT32_MIN needs no negation. `cell_centre_*` on
NO_REQUEST is arithmetically safe — GDScript truncating division yields (-256, 256), outside the
accepted target domain — which is exactly why the grouped TRAVELLING claim in section 4 holds.

**Finding B.** "No live construction" is satisfied, but preloading movement.gd still loads
int_math, entity_directory, spatial_world, navigation, transforms and residents. Say so; claim no
isolation from those script loads.

## 4. Witness and mutation accounting

Recounted 154 frozen images (8 accepts, 3 phase, 18 reserved, 10 remainder, 9 speed, 36 velocity,
8 cell, 16 target, map-last-cell, 38 state/terminal, 7 priority ladder) and 49 shape cases.
Spot-checked `earlier-reserved-before-later-phase` (row 0 beats row 511, pinning per-row ascending
order over per-column passes), `phase-before-reserved`, `cell-before-target`,
`arrived-wrong-retained-centre`, `map-last-cell` and `idle-valid-nonzero-target`: all classify as
stated. The 50 mutation groups sum correctly. The grouped TRAVELLING `grid_next >= 0` equivalence
is justified rather than asserted, and the unconditional-decrement mutant is killable.

**Finding C, missing discriminating witness.** No image pairs speed 0 with non-zero velocity. Add
`clear` + `vx = 1` and a `vz` twin, expecting COLUMN_VELOCITY. Without it a mutant treating speed 0
as unbounded survives and velocity-before-state precedence at speed 0 is untested.

**Finding D.** The plan cites 18 schema/control/bypass metadata cases; the frozen arithmetic file
holds 9. Enumerate the 18 — presumably each of the 9 against schema-refusal and bridge-refusal —
before dispatch, or 21 cases / 189 assertions is unauditable. Mutating the owned residents clone,
and pinning SIZE_MOVEMENT_U_PER_S length 3 before each entry, is the right malformed-table guard.

## 5. Producer repair

`_attach_route`'s speed check is the last refusal on the path, so decrementing once immediately
after it is atomic: every earlier refusal returns with row, phase, cursor, fractions and count
untouched. `_reset_motion` does not write `_movement_phase`, so placing the decrement before or
after it is observationally equivalent — do not claim that ordering as a tested property. The
repair is correctly scoped to the persistent count defect in readmission-original.log (3 tests, 52
assertions, 3 failing) and does not touch legitimate deferred despawn cleanup, whose stale-row
settling the public probe (4 tests, 98 assertions, 0 failures) already covers.

## 6. Verdict

Proceed after Findings A, C and D are folded in; B is documentation only. No policy decision from
Brendan is required.
