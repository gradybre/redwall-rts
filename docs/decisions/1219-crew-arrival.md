# 1219 — Crew arrival: registration on arrival, the surface walk, and unregistered residents in occupancy proofs

Date: 2026-10-07 · Status: Accepted (Brendan chose registration on arrival); implemented. Closes the simulation half
of ADR 1197 G5. The live chain now stops at a G6 gap.

## Brendan's decision (2026-10-07)

**Register on arrival.** When a resident is picked for the entry crew it walks to the stair-top anchor H on the
surface, is placed exactly on H (work-area endpoint 0) and is registered with the underground movement system
(Routes) then. Only crew moles cost underground memory and CPU; other surface residents are never registered.

## 1. Occupancy: unregistered residents are bodies by proof, not by registration

**Before.** Every occupancy proof (WorldRoutes turn, WorldRoutes workpiece, Delivery handling, Contacts installation)
refused `ROUTE_TURN_ACTOR_UNBOUND` (Contacts: `CONNECTOR_CONTACT_ACTOR_UNBOUND`) if *any* living resident was not a
route actor. With registration on arrival that can never pass: the surface residents are never registered. Routes'
own motion query (`occupancy_refusal`) was inconsistent the other way: it indexed only registered actors and treated
everyone else as empty air.

**Is "surface residents are outside the work area" true by construction? No.** The first-entry work area is on the
surface: all eleven endpoints sit at the origin's ground height, with air up to 1,422 u above it and up to 3.8 m
around the origin (`underground_entry_work_area.gd`). A surface resident standing over the trench *is* inside that
air. Nothing in the simulation moves residents today (Movement is not composed), but their initial poses, a future
surface mover, or the crew itself walking in could all put a body there. So the rule had to be a proof.

**The rule (all five proofs, one implementation, `Routes.unregistered_occupant_refusal`):**

- An absent or dead row occupies nothing (unchanged).
- A living resident that is not a route actor and has **no placed Transform** is still refused
  (`ROUTE_TURN_ACTOR_UNBOUND`): its position is unknown, so it can never be proved clear.
- Otherwise it occupies the half-open cube of half-width `UNREGISTERED_REACH_U` around its Transform root. If that
  cube overlaps the checked body, the proof refuses **`ROUTE_UNREGISTERED_RESIDENT_NEAR`**; if not, it is clear.
- The checked body is the query box itself (Routes motion, workpiece) or, where the actor's proof compares boxes
  (turn, Delivery, Contacts), the actor's root plus the whole current catalog extent (`_catalog_extent`, refused as
  `ROUTE_OCCUPANCY_STALE` if it is not current). Both are supersets of the exact boxes, so the test is conservative.
- Routes' motion query now applies the same rule after its registered-actor broadphase, charging 16 checks per
  resident row, and skipping the moving actor itself (`except_worker`).

So the work area excludes unregistered residents *by refusing* while one is within reach; it never assumes them
away. Registered actors keep their exact authored bodies.

**`UNREGISTERED_REACH_U` = 2 × 2611 = 5,222 u (decision).** Surface residents have no authored body (MOVE-G01 body
envelopes are unsupplied). The bound is derived from approved data only: DEC-039's tallest body is the badger at
2,611 u and its longest tail is the squirrel's at 950‰ of height, so no approved body reaches past height plus tail,
which is under twice the tallest height, in any direction from its root. It can only over-refuse. Known cost: a
surface resident within 5.1 m (in any axis) of a working actor blocks it, including vertically above a future
underground room at DEC-040's candidate 4 m spacing. Replace it with real per-species envelopes when MOVE-G01
supplies them.

**Alert.** `ROUTE_UNREGISTERED_RESIDENT_NEAR` maps to G5 ("surface Movement does not route residents around the work
area yet"). `ROUTE_TURN_ACTOR_UNBOUND` is no longer a G5 stop and is unmapped (a resident with no pose is a data
fault, not a missing capability).

## 2. The crew's surface walk (simulation hand-off)

There is no simulation surface movement to reuse: `navigation.gd`/`movement.gd` exist but are not composed in the
settlement (no SpatialWorld graph, and Movement refuses a clearance class it has no data for). The demo's walk is
presentation only. So the runtime implements the minimal version the spec allows:

- **Duration = BAL-WORK-003's straight-leg lower bound**, `ceil_div(D*30, v)` (`HaulPlanner.travel_ticks_into`), D the
  exact integer Euclidean length from the mole's Transform to H rounded up (`ceil_length`, integer bisection), v the
  mole's GDD §5.2 size-class ground cap from `residents.gd`. Generated settlement: 373 ticks.
- **No path, obstacle or clearance is modelled**, and the Transform does **not** move during the walk (only
  `movement.gd` may `advance()`, once per tick). On the walk's last tick `Transforms.place` puts it exactly on H's
  published integer point. Recorded limitation: until surface Navigation/Movement is composed, the walk is a timed
  teleport whose duration is a lower bound, and the resident's pose reads "at home" until it arrives.
- **Heading.** H admits only its authored narrow approach row (see below), which is exact-yaw, so arrival places the
  mole at that row's authored heading (`Foreman.arrival_yaw`). A row admitting all headings keeps the resident's own.
  Nothing is derived from the direction of motion.
- The walk runs inside `STEP_RUNNING` (`walk_ticks_left()`); no step number changed.

## 3. Registration at H, and leaving it

ADR 1191 authored H as the L0 bearer's handling station: only the narrow same-heading approach (source 2), the
backward retreat to R (source 6), source 16 and handling 29 fit its envelope; the all-yaw tooled travel row
(source 12) deliberately does not. The first live run, admitting on the station's travel row 12, refused
`WORLD_ROUTE_ENDPOINT_BODY`. A probe that tried the content-6 rows at H in order (tooled first) admitted tooled
row 2 at yaw 0, the Frontier's own travel profile for H.

So the foreman's `plan_arrival(H)` takes everything from the Frontier, nothing invented:

- H must be the first installation's station (else `ENTRY_FOREMAN_PLAN`); the worker is admitted there with
  `admit_travel_actor` on **H's own authored travel profile**, with its tool (tooled rows until claw rows land; the
  tool-free rows 30/31 do not fit H with a tool held, and a tool-free crew would use `admit_actor` WALK once claw
  rows remove the tool);
- it leaves by **that installation's authored retreat** (R on its profile), then continues on the station's or the
  haul's legs exactly as before. `Crew.arrival` names the endpoint; NULL keeps the old "admit on the first station"
  behaviour used by fixtures.

## 4. Release when the crew goes home

Routes has **no unregister**, and ADR 1168 forbids unregister-and-readmit on purpose (ADR 1210 kept that under the
switch at rest). So nothing is released: when the prefix ends the crew mole stays registered, standing on its last
endpoint, and counts in every occupancy proof with its exact body. It is the standing entry crew for the Kitchen work
(G9). Sending it home to the surface needs an unregister rule in Routes (a certified rule change) plus surface
Movement; not built, and Brendan's to choose when that work starts.

## 5. Live chain (`test_underground_host.gd::test_fixed_ticks_drive_the_live_foreman_until_the_first_gap`)

The G5 placement stand-in is gone; only the G11 tool and the R-staged stock stand-ins remain. Ticks alone:

1. the mole walks 373 ticks (independently recomputed in the test) and on that tick is on H's exact point,
   registered on H, and already switched to the retreat row;
2. it retreats to R, walks tooled to M, puts the tool down, switches at rest and hauls both whole units of the first
   brace (one wood, one stone) through Delivery, the eleven other residents clearing every occupancy proof by
   their reach cubes;
3. going home it stops with **`JOB_HAS_WORKER`**: the JobSelector had already given the step's unassigned BUILD Job
   to an idle surface mouse while the crew hauled. Mapped to **G6** (reserving the crew's Jobs is not built). Only
   the crew is a route actor.

## 6. Presentation (ADR 1211)

`entry_worker_view.gd` no longer raises `ENTRY_SURFACE_HANDOFF_UNBUILT`: the cast walker is held at H until the
simulation registers the resident, which alone switches the view to drawing. Refusals on the way are the runtime's.

## Memory (DEC-053 census)

| Store | Bytes |
|---|---|
| Runtime `_transforms`, `_anchor`, `_walk_left`, `_arrival_yaw` | +28 |
| `Crew.arrival` | +8 |
| Foreman arrival profile/revision/retreat fields | +40 |
| Third Hauler leg bound (arrival leg), both retained Haulers | +48 |
| `UNREGISTERED_REACH_U` (compile-time, reviewed delta row) | 0 |
| **Total** | **+124** (first-entry chain 3,086 → 3,210 B; joint pack 100,007,755 B, headroom 49,992,245 B under DEC-053's 150 MB gate) |

Registration itself adds no bytes: Routes' resident columns are fixed at 256 rows. CPU: each occupancy proof adds
at most one direct column read and three comparisons per resident row (≤ 256), already inside each proof's census
charge; the motion query charges it explicitly.

## Rejected

- **Treat unregistered residents as empty air** (the motion query's old behaviour): unsound on a surface work area.
- **Register every resident:** contradicts Brendan's decision and costs underground memory/CPU for all 256.
- **Exclude by the anchor section's footprint with no body bound:** the air reaches within 0.28 m of the section's
  edge, so a body standing just outside could still overlap.
- **Advance the Transform along a straight line each tick:** a second mover besides `movement.gd`, walking through
  whatever lies between.

## Amendment (2026-10-07, after ADR 1224): the sixth proof

ADR 1224's live run reached the paid L0 installation and stopped with `ROUTE_ASSEMBLY_ACTOR_UNBOUND`.
`Routes._assembly_occupants_leaf`, the assembly-handling occupancy proof that the L0 delivery and handling run
through, still required every living resident to be a route actor.

It now applies the same rule as the other five proofs, through the same helper:
- an unregistered living resident is checked with `unregistered_body_refusal`, at the handling actor's own root and
  bounded by the whole current catalog extent;
- the result is `ROUTE_UNREGISTERED_RESIDENT_NEAR` when within `UNREGISTERED_REACH_U`, and clear otherwise;
- registered actors keep their exact body proof.

The bound is the same over-refusing one. No new constant or state is added, and the leaf's existing
16-checks-per-row charge covers the read.

## Note (2026-10-07, ADR 1227): the reach scan's measured cost

ADR 1224 suspected this rule's per-row charge of exhausting Contacts' operation budget at T0's paid FUND (ADR 1197
G14). Measured, Contacts' occupancy leaf (16 checks × 512 allocator rows, reach test included) spent 8,192 of the
1,046,706 checks in that operation, under 1%. The rule and its charges are unchanged. G14 was fixed in the Region-bank
scans instead (ADR 1227).
