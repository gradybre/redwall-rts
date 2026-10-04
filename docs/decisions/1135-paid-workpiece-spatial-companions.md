# 1135 — Paid workpiece spatial companions
Date: 2026-10-04 · Status: Accepted component; integrated and production qualification pending

## Decision

Extend the existing exact InstallationContext and inactive spatial banks to
support a static, Project-owned workpiece at connector START. Loose materials
arrive through existing Inventory and hauling, including partial shipments.
Only the successful consumption of the complete delivered bill publishes the
non-supporting OBSTACLE. Funding remains the sole quantity and work receipt.

COMMIT removes that exact full Region and Project source while installing the
complete paid assembly. Successful CANCEL removes them only after the existing
refund settles. A blocked refund retains WIP, workpiece and installed prefix.
This version introduces no movement of consumed WIP, new entity namespace,
support surface, endpoint, route, paid-cut ledger or second bill.

## Concrete boundary and publication order

Placements once binds the actual Workpieces owner reciprocally with the actual
purpose-8 Router owner. Workpieces does not preload Placements, ConnectorWork or
Contacts, allowing the spatial owner to call its concrete static source and
bounds leaves without a preload cycle or virtual permission callback.

`prepare_workpiece_start` and `prepare_workpiece_cancel` retain the exact full
Placement, Project, original Budget/token, immutable source and full obstacle
identity. Caller bounds alone authorize nothing. START adds only one exact
Project-owned OBSTACLE; terminal preparation removes only the live full Region
and forgets its Project source before eventual Project retirement. The existing
completion path incorporates the same removal before staging the paid group.

All immutable-content, physical, occupant, retention, endpoint and certificate
observations finish before Funding commits. Direct final leaves then verify the
original tuple, prepared banks and lease. The actual Router START/COMMIT/CANCEL
window publishes Space, Locations, graph/certificates and Placement in order.
The same static kernel writes or clears the Workpieces row before clearing the
shared context. ConnectorWork does not publish that row a second time. No
observer or newly satisfiable permission follows payment.

START and CANCEL preserve every old endpoint and edge payload, all retained
actors and exits, and previously eligible profile masks. They add no endpoint
or edge. Generic Space publication remains forbidden for an owned token,
including after attempted companion discard. All refusal paths abort the exact
owned candidate before releasing its original lease or ownership controls.

## Storage and bounded work

The existing shared InstallationContext gains action (8 B) and full obstacle
(8 B); Placement independently pins the same two values (16 B): 32 logical
control bytes, no packed row or saved-format delta. The complete cross-owner
numeric chain is568 B for Workpieces CANCEL through actual installed Location
refresh; the existing PhaseContext refresh chain is572 B after the accepted
support/air correction. Reassign64 B of unused control headroom to a576 B
helper allowance. The source-derived fixed envelope is1895/2048, including the
32 B retained change and this helper allowance once. The added weak Workpieces
binding and borrowed strong references have unmeasured native header/lifetime
costs within the existing provisional allowance; they are not declared free.
No reserve, bank or capacity increases.

Existing Space, Locations, graph, mask and Placement banks are reused. Physical
proof scratch drops before Location preparation, then Location scratch drops
before route qualification. At the current R=6144/O=2048 maxima, conservative
sequential cold ceilings are 626688 B (`96R+16O+4096`), 545152 B
(`88R+384+4096`) and 380928 B (`48R+16O+49152+4096`), inside the original
1048960 B lease. No RoomPlan images coexist on this path. Exact live-source,
claim, actor, endpoint and edge work is charged before its bounded scan.
Workpieces' own 21P rows and immutable 32A source rows are separately owned and
counted under 1134; neither is duplicated here.

## Ownership and acceptance

Geometry owns SpaceOwner, Placements, Locations, Routes, WorldRoutes,
EntryBindings, the narrow FinalFacts source-reader correction, their scoped
tests and this record. Construction owns Workpieces,
ConnectorWork and Contacts. Root owns the connector-only Router/Contract START
publication seam (1136), shared memory tooling and integration. SurfaceAnchor
is unchanged. Other agents' edits and accepted prerequisites are preserved.

Required actual-owner tests include START publication and refusal atomicity;
late source/lease/pose/observer mutation; generic and static premature publish
attempts; full-generation obstacle substitution; occupied endpoint/last-exit
blocking; exact COMMIT replacement; successful and blocked refund; discard and
retry; no second paid row or quantity; and unchanged ordinary installation.
Production handling remains refused until actual immutable source/body/load
and source-program obligations close. Geometry tests cannot qualify motion,
stair pace or native memory/performance.

## Source

Root's approved 1134/1135/1136 task packet, SET-MOVE-001 retention obligations,
the actual guarded purpose-8 Funding lifecycle (1118), existing pure installation
companions (1105/1114), and independent support/air contract (1133).

## Final store observation correction

The actual paid START probe in `late-room-probe-1` demonstrated that the existing
`CoreSources.read_leaf_into` still dispatched public Building/Room/Furniture/Project
methods after final occupancy. A successful Room copy followed by an actual worker
move could therefore pay and publish an overlapping workpiece. The rejected run
is retained. The installation final source/claim tail and four FinalFacts call sites use a separate concrete
`CoreSources.read_final_into` over exact Directory and actual packed store columns.
Normal source observations remain unchanged; no additional source image, field,
permission, or revision is introduced.

## Terminal physical occupancy

Cancellation releases the real BUILD assignment before the guarded refund.
The retained body is still physical. `Routes.physical_selection_into` therefore
reads the same immutable committed profile/content revision plus the current
full Resident/PID/Transform, exact equipped Gear lot and manufacture, and actual
satchel/cargo quantity. It does not require a productive Job or Gear claim.
Every complete BODY_HELD_LOAD and TURN_RECOVERY box remains part of occupancy.
Refused reads leave output untouched. This reader grants no movement, turn or
productive work; the existing work and turn readers retain their stricter Job
and tool-claim checks.

The final source/claim numeric chain is224 B and the physical occupancy chain
is272 B; both fit the same576 B allowance. The direct source reader performs
at most29 packed-column reads (Furniture, including its parent Room's full
Directory/reverse-row check), retaining the existing64-check nonresident leaf
charge plus the separately charged source/claim scans. See `census.py` and the
exact source-pinned output in this record's evidence directory.

## Independent component acceptance

Root independently accepted the exact ten `source-review-2` production/test
pins after reviewing the spatial kernels, direct final store readers, physical
occupancy and all six actual paid lifecycle regressions. The independent census
reproduction matched 1895/2048 controls and 572/576 maximum numeric chain. The
selected strict evidence is 404 tests/29732 assertions/0 failures, zero unexpected
diagnostics/leaks, and analyzer 0/10. The reproduced late-Room failure remains
in the evidence beside its correction.

This verdict is limited to the component's source and correctness with the
recorded diagnostic 1134 dependency snapshots. Later Workpieces source changes
require paired census and integration checks. Synthetic motion, production
handling/source closure, native memory/performance and integrated gates remain
open. No shared memory registry or queue update is included in this component.
