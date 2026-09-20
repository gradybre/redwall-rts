# Movement section 4 — feasibility review (read-only)
Status: audit only. No contract is accepted, no source is edited, nothing is executed here.
SET-MOVE-001 remains authoritative: this block is the ground-motion baseline and completes no
MOVE gate. Tunnels, swimming, diving, canopy access and the close MOVE gates are untouched by
anything below. Stale claims inside existing source headers (missing ledger rows, owed byte
totals) are historical and are deliberately not repeated here as current blockers.
## 1. Re-derived block arithmetic
Owner 8 `movement`, version 1, primary 512, child extents 0, field begin 171, 16 fields, all
type 2 (i32) with count 512.
- values: `16 * 512 * 4 = 32768`
- payload: `child_count 4 + child extents 0 + 16 * field_count 8 + 32768 = 32900`
- block: `header 24 + key bytes 8 + 32900 = 32932`
- offset 9246459; field order vx, vz, remainder_x, remainder_z, next_x, next_z, correction_x,
  correction_z, radius_u, desired_yaw, next_yaw, grid_next, grid_cell, speed_u_per_s,
  movement_phase, blocked_ticks.
All three totals match the compiled tables. The nine route/admission cursor columns are section 2
and are not in scope.
## 2. Writer audit against the preliminary domains
Only `_allocate_motion`, `_allocate_cursors`, `_reset_motion`, `_attach_route`, `_advance_row`,
`_spend_budget`/`_arrive_at_target`/`_advance_cursor_target`, `_integrate_axis` and `_settle`
write these columns. Confirmed by that set:
- correction_x/z, radius_u, desired_yaw, next_yaw, blocked_ticks are written only as zero.
- remainder_x/z are `accumulated % 420` of non-negative inputs, so 0..419; `_settle` retains them.
- speed is written only from the size table, so 0 (never admitted) or 3277/4096/3072.
- grid cells are -1 or a real index; target pairs are written together, either both zero by
  `_reset_motion` or both as cell centres (256 + 512k, so never zero).
- TRAVELLING implies grid_cell >= 0, grid_next >= 0, speed > 0 and target == centre(grid_next).
- every `_settle` sets grid_next = -1 and leaves grid_cell and the target pair standing.
### Finding 1 — ARRIVED velocity is legitimately nonzero (unjustified strong relation)
`_spend_budget` can reach the route end and `_settle(ARRIVED)`, which zeroes vx/vz, but
`_advance_row` then writes `vx = here_x - pose.x` **after** `_spend_budget` returns. An arrived row
therefore retains its final tick displacement. Phases 3..5 do satisfy zero velocity: the height and
transform refusals settle either before that write or after it, and `revalidate_destination` and
the stale-profile path settle outside `_advance_row`'s write. IDLE is zeroed by `_reset_motion`.
A blanket "terminal phase implies zero velocity" rule would reject valid state; restrict it to 3..5.

### Finding 2 — a one-cell route arrives with a zero target

`_attach_route` calls `_advance_cursor_target`, which settles ARRIVED when no second route cell
exists, leaving the target pair at the `_reset_motion` zeros with a valid grid_cell and speed. The
tight local form is: ARRIVED implies grid_next == -1 and (target pair is zero **or** equals
centre(grid_cell)). Phases 3..5 keep whatever centre they held and must not be tied to grid_cell.

### Finding 3 — producer defect: despawn leaves motion running

`residents.despawn()` does not call `stop()`. Until the next `advance_tick` the row stays
TRAVELLING, `travelling_count()` over-reports by one, and the row may name an absent slot or a
reused row belonging to a different persistent id. The public probe observes exactly this. Two
consequences for the predicate: do not join a TRAVELLING row to resident presence, and do not
normalize the motion columns of a free resident row. `stop()` also retains speed and grid_cell, so
a stopped row is not a zero row. Report both to the movement and residents owners; neither blocks
the local predicate.

## 3. Recommended local domain (argument-only, cold, no live constructors)

phase 0..5; remainders 0..419; the six reserved columns exactly zero; speed in {0, 3277, 4096,
3072}; grid_cell and grid_next in {-1} or 0..262143; target pair both zero or both valid centres;
TRAVELLING as in section 2; phases 3..5 imply vx = vz = 0 and grid_next = -1; IDLE implies zero
velocity, zero remainders, zero target and grid_next = -1; ARRIVED as in finding 2; and
`abs(v) <= ceil(speed/30)` per axis, which is exact at 110/137/103 for the three caps because the
released budget is `(speed*14 + r)/420` with r <= 419 and a tick consumes at most that budget
across its bounded segments.

Deferred to MOVEMENT-SAVED-BINDINGS, not asserted locally: resident identity and the section 2
cursor owner, route request readiness and generation, profile id/revision, contact destination
revision, transform pose and previous pose agreement with grid_cell and the target, and loaded
tick phase. A live-world join is not evidence for any of these.

## 4. Pins, bounds and budget

Pin before use: MOTION_CAPACITY 512, MOTION_PHASE_COUNT 6, NO_REQUEST -1, TICKS_PER_SECOND 30,
COST_DIAGONAL 14 and the derived denominator 420, CELL_COUNT 262144, CELL_SIZE_UNITS 512,
CELL_CENTRE_OFFSET_UNITS 256, and the length-3 size speed table with its three entries. All are
compile-time constants reachable by preload alone. Overflow: every stored value stays far inside
i32 — targets peak at 261888, velocities at 137 — and the modulus inputs peak at 57763.

Budget: 32768 caller bytes plus 32768 default bytes = 65536 logical packed bytes, no scratch. That
is a logical packed figure, not a measured native or RSS figure.

Verdict: feasible as written, subject to the three findings above being reflected in the contract.
