# Movement component validation and readmission contract

MOVEMENT-S4-VALIDATE-R01 · version1 · accepted for bounded implementation, 2026-09-20; ADR0182.

This milestone validates the existing ground-motion section4 columns and repairs one demonstrated traveller-count defect. It does not complete connected tunnels, swimming, diving, canopy access, profile/hazard policy, travel/work integration or any MOVE-G01–05 gate under SET-MOVE-001. No baseline map limit is promoted to a complete settlement limit.

## Layout and cold image

Owner8 `movement`, version1, primary512, no child extents, global fieldbegin171/count16. Ordinals are canonical Schema.FIELD_KEYS[171..186], never the source declaration order. All fields are i32[512]: values32768, payload32900, block32932, offset9246459. Nine route/admission cursor fields are saved separately in section2 and are not appended here. No schema or canonical registry version change.

Add a cold `class Columns` with these16 packed arrays, argument-free constructor, and is_sized(). Defaults are zero except grid_next/grid_cell=-1. No live Movement, SpatialWorld, Navigation, Residents, Transforms or Directory construction is allowed in validation.

| Ordinal | Property (canonical key adds `_`) |
|---|---|
| 0 | vx |
| 1 | vz |
| 2 | remainder_x |
| 3 | remainder_z |
| 4 | next_x |
| 5 | next_z |
| 6 | correction_x |
| 7 | correction_z |
| 8 | radius_u |
| 9 | desired_yaw |
| 10 | next_yaw |
| 11 | grid_next |
| 12 | grid_cell |
| 13 | speed_u_per_s |
| 14 | movement_phase |
| 15 | blocked_ticks |

## Pure predicate and exact priority

Add static columns_refusal(image: Columns)->StringName, success existing REFUSE_NONE. It reads only its argument and compiled constants, changes no buffer, calls no callback or diagnostic, reads no clock and uses no float. New constants REFUSE_COLUMN_SHAPE/PHASE/RESERVED/REMAINDER/SPEED/VELOCITY/CELL/TARGET/STATE return the corresponding exact COLUMN_* codes.

Null or any incorrect16 extent gives COLUMN_SHAPE before indexing. Then ascending physical rows, with these gates within each row:

1. Phase is IDLE0/TRAVELLING1/ARRIVED2/ROUTE_LOST3/PROFILE_STALE4/CONTACT_STALE5, else COLUMN_PHASE.
2. correction_x, correction_z, radius_u, desired_yaw, next_yaw and blocked_ticks are all exactly0, else COLUMN_RESERVED. They are reserved by the current producer, not a basis for inventing geometry or facing policy.
3. Both remainders are0..419, else COLUMN_REMAINDER.
4. Speed is0 or one of the existing Residents.SIZE_MOVEMENT_U_PER_S entries3277,4096,3072, else COLUMN_SPEED. Do not join it to the current resident's species, which may have changed or disappeared.
5. For each velocity component, `-limit <= v <= limit`, where integer limit=(speed+29)/30 after speed validation. Limits are0,110,137,103. Else COLUMN_VELOCITY. Do not force ARRIVED velocity to zero: the source writes its final displacement after settling ARRIVED.
6. grid_cell and grid_next each allow NO_REQUEST=-1 or0..262143, else COLUMN_CELL.
7. Target pair next_x/next_z is either both0, or both valid cell centres: each256..261888 and `(coordinate-256)%512==0`. Mixed zero/nonzero is invalid. Else COLUMN_TARGET. These are stored waypoint targets, not arbitrary Transform positions.
8. Phase relations, else COLUMN_STATE:
   - IDLE: vx/vz, both remainders and both target coordinates0; grid_next=-1. Retain valid speed and grid_cell history. No free-resident normalization.
   - TRAVELLING: speed>0, both grid cells nonnegative, target exactly the source centre of grid_next. Zero instantaneous velocity is legal before the first tick; remainders retain their fractional domains.
   - ARRIVED: speed>0, grid_cell nonnegative, grid_next=-1, and target either both0 or exactly centre(grid_cell). Velocity and remainders retain their bounded values. The all-zero target permits a public one-cell route that arrives during admission.
   - ROUTE_LOST/PROFILE_STALE/CONTACT_STALE: speed>0, grid_cell nonnegative, grid_next=-1, vx/vz0. Valid target coordinates and remainders are retained. No target equality to grid_cell: the abandoned target may be ahead. The generic target domain deliberately permits a zero pair without making a historical reachability claim; the phase does not advance it.

Source helpers for cell centres are static and may be reused after the cell domain gate. All calculations fit i64: source speed maximum4096, step numerator at most57763, cell-centre maximum261888, signed velocity limits at most137. No packed scratch or per-row allocation is needed. Caller32768 + cold defaults32768 =65536 conservative logical packed bytes, below6417408 streaming allowance. Native overhead/RSS remains unmeasured.

## Confirmed producer repair

readmission-original.log reproduces a persistent count defect using only public APIs:3 tests/52assertions, all3 tests fail with no engine error. Re-admitting a TRAVELLING row increments the count twice; stop or immediate one-cell arrival leaves a phantom traveller. Reused resident rows show the same issue before the next cleanup tick.

In _attach_route, after the existing speed check succeeds and before _reset_motion, decrement _travelling_count exactly once when that row's current phase is MOTION_TRAVELLING. Keep the existing reset/attach, one increment, and possible immediate settlement. A nontravelling row contributes nothing to remove. Every refusal must occur before this adjustment and leave the original row/count unchanged. No count clamp, whole-store recount, despawn callback, new state field, navigation reference change or new public API. All other gameplay behavior stays as implemented.

Regression cases include same-owner repeated admission, replacement with immediate arrival, successor admission before stale-row cleanup, multiple independent travellers, and a rejected replacement preserving count/phase/cursor/fractions. One explicit mutation removes the new adjustment and must restore the observed failures. Also test an unconditional decrement (nontravelling admission must still count1). This repair is separate from legitimate deferred despawn cleanup: the existing persistent-owner check must continue to settle stale rows on their next tick without moving a successor.

## Framed bridge and source pins

New save_owner_movement.gd directly preloads only Movement, Schema, Section and SaveHeader. Seven gates: null; wrongowner8; unchanged schema refusal; metadata/source pins; unchanged owner shape refusal; one cold Columns with16 explicit canonical i32 assignments; exact raw column code wrapped in an owner-qualified detail. Metadata prefix `Movement owner8 metadata:`; column detail contains `Movement owner 8 ` and the exact code, without row identity. Success empty code/detail. No live-world join or publication.

Use conventional OWNER_INDEX/KEY/VERSION/PRIMARY_COUNT/CHILD_EXTENT_COUNT/FIELD_COUNT and FIELD_KEYS/TYPES/COUNTS metadata pins. Pin ownerkey movement/version1/512/0/16 and every field key/type/count.

Source pins: MOTION_CAPACITY512, MOTION_IDLE0/TRAVELLING1/ARRIVED2/ROUTE_LOST3/PROFILE_STALE4/CONTACT_STALE5/PHASE_COUNT6, NO_REQUEST-1, TICKS_PER_SECOND30, REMAINDER_DENOMINATOR420, ORTHOGONAL_NUMERATOR_FACTOR14, DIAGONAL_NUMERATOR_FACTOR10; Movement.Navigation.COST_ORTHOGONAL10/COST_DIAGONAL14; Movement.SpatialWorld.CELLS_X512/CELLS_Z512/CELL_COUNT262144/CELL_SIZE_UNITS512/CELL_CENTRE_OFFSET_UNITS256; Movement.ResidentsScript.RESIDENT_CAPACITY512. Pin ResidentsScript.SIZE_MOVEMENT_U_PER_S length3 before each entry [3277,4096,3072]. Indirect constant access keeps the four direct preloads. If the implementation reuses additional sentinel aliases, record and pin those actual inputs before acceptance.

## Required verification and boundaries

Public history probe4tests/98assertions/0 verifies arrival's final displacement via Transforms, immediate one-cell arrival, retained stop speed, stale profile/contact fractions, and reused-row owner protection. It does not expose private vx/vz directly. The before-repair regression is intentionally failing evidence, not accepted product behavior.

Before author dispatch freeze explicit accepted/refused images, metadata counterfactual arithmetic and logical mutation units. Tests must cover all16 projections/extents, every512 row, shape before unsafe indexing, exact per-row priority, nonmutation, each reserved field, phase cases, all source speeds and velocity endpoints, all remainder and cell/target boundaries, terminal retained history and full physical capacity. Source-data drift must be refused before table indexing; parser/runtime errors cannot be counted as mutation catches. The metadata tool isolates autoloads only in its owned disposable clone, with actual configuration/source hashes preserved.

Final gates:17 static checks/capacity regeneration, actual import, focused and full suite, required faults/mutations, independent exact-source review and exact-head CI/merge. Integrate the producer regression into the normal suite. Canonical schema bytes stay unchanged.

MOVEMENT-SAVED-BINDINGS must still reconcile same-file Residents persistent identity, section2 cursor/profile/load/destination terms, navigation request/route generations and readiness, Transforms current/previous pose, loaded tick phase and common provenance. Pending stale resident/route state may be legitimate before its owning tick checks and must not be silently erased. Full bulk capture/apply and connected movement gameplay remain unfinished.

## Reviewed verification refinements

The frozen value set has156 cases including explicit speed0/vx1 and speed0/vz1 refusals. The49 shape cases and every16field/every512row draft are separate. metadata-cases.json enumerates21 planned cases/189assertions: one control, eight coherent schema faults each refused and specifically bypassed, one schema-first forwarding case and three Residents speed-table faults. No runtime count is inferred from those plans.

No live construction is permitted, but Movement has transitive script preloads; the four direct adapter preloads are not a claim of load isolation or native memory size. Expanded public readmission evidence is5tests/100assertions/4failingtests on the original, with the refused replacement case already passing. Reset-order rewrites are equivalent and excluded from mutation accounting. See contract-disposition.md for all independent review findings.
