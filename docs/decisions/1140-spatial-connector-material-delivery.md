# 1140 — Spatial connector material delivery

Date: 2026-10-04 · Status: Implementation approved; verification and source activation pending

## Decision

Add one concrete connector delivery coordinator, using the actual Inventory,
Reservations, HaulPlanner, Jobs, Work, Residents and underground movement owners.
The existing Planner row remains the only destination and reserved-mass record;
the existing reservation chain remains the only payload claim. The Job's source
may name its actual Construction Project. Inventory and Location handles never
enter Directory Job-reference columns. No additional per-job quantity, claim,
destination, progress or receipt bank is introduced.

Admission derives the destination from the actual Project material container and
the exact immutable Frontier material endpoint. It sizes each shipment using the
existing carry-capacity policy. Several ordinary shipments may supply one bill.
Geometry's separately owned 1141 guarded transaction reserves destination mass
and source goods together; the old two-transaction Planner admission is not an
atomic spatial admission.

The actual worker must reach the source before earning the existing 2,000 milli-WU
load work in WORK, move the goods into its real satchel, travel in the actual CARRY
profile, then arrive at the exact destination before earning the existing 2,000
milli-WU unload work in HAUL_OUTPUT. There is no second WORK phase for unloading,
no work while travelling and no route-as-delivery shortcut. Existing pantry
handling discounts require their actual source-defined connection; this entry
does not invent one. The 1134 test's explicit second-WORK bridge is historical
diagnostic evidence, not the production sequence implemented here.

LOAD, REPOST, UNLOAD and CANCEL use the same 1141 guarded Inventory boundary.
After the last observation and before Inventory commit, the concrete coordinator
rechecks the original transaction, full references, current source/endpoint and
worker facts, and the expected staged cargo. The postcommit tail only publishes
the prevalidated Resident satchel pair and existing Planner/Job columns. CANCEL
releases original claims and grams atomically, retains actual carried goods, and
does not require the cancelled connector Project or productive assignment to
remain live.

## Ownership and limits

This slice owns the new `underground_connector_delivery.gd` and test, narrow
HaulPlanner/Work changes and their tests, this decision and dedicated evidence.
Inventory, Reservations and `haul_transfer_contract.gd` are the separate 1141
lease. ConnectorWork, ConnectorContacts, Workpieces, physical source programs and
the movement/Space publication owners remain unchanged.

The new coordinator contribution has a **4,096-byte maximum**, to be replaced by
an exact source-derived retained/helper/native-reserve census before allocation
and acceptance. The preliminary 979-byte caller-packet ceiling plus 1,024-byte
helper allowance is a ceiling, not a requirement to add unused members. The
216-byte Transfer is borrowed from the Pool and counted only in 1141. There is no
claim of measured native allocation, runtime performance or a larger 100 MB
memory limit. Shared tooling and registry admission remain root-owned.

Tests may use the explicitly synthetic immutable handling/CARRY programs from
the real-owner 1134 fixture. Successful accounting and spatial tests do not
qualify those programs or prove the playable entrance/Kitchen milestone. Real
handling/carry source activation remains an explicit following gate.

## Source

Brendan's hauling rulings R-H5/R-H6/R-H7, recorded in decision 1021 and
`planning/construction_execution_package.md`; GDD REQ-SET-030–033 and 110–112;
BAL-CAT-010/BAL-WORK-003; the accepted 1134 physical-workpiece contract; root's
explicit 1140 file lease and 4,096-byte declaration ceiling. Work's concrete
cycle-free observer/final-leaf seam and the exact 1141 call signatures will be
recorded with the implementation and final census.

## Actual protocol and final observations

The coordinator binds one actual `SimClock` along with the original Placement,
Frontier, Planner, WorldRoutes and Work owners. `admit` selects the actual
Project's Frontier STORAGE endpoint and uses `HaulPlanner.admit_spatial`; the
Planner calls the accepted 1141 `admit_haul_guarded` before publishing its existing
row. `begin_load` requires source arrival and the exact no-tool HAUL WORK program.
`load_payload` and `unload_payload` require zero remaining work in WORK and
HAUL_OUTPUT respectively. `repost_payload` handles actual owned-satchel goods
after cancellation: a newly admitted Job exchanges its SOURCE claim for a
DESTINATION claim and enters HAUL_OUTPUT without moving goods or earning load
work again. Partial unload preserves the original live Resident satchel; only a
satchel actually retired by the guarded Inventory journal becomes null.

The final leaf checks the concrete current worker and physical scene. The first
actual adversary showed that an overridable Terrain helper could move the worker
inside Inventory attestation after its pose had been checked. The new owner now
reads Terrain/Location facts directly at this boundary. The other reused final
reader implementations are pinned to their concrete scripts at bind and use;
ordinary Terrain/Location observation seams remain available before the final
proof. This is an explicit composition restriction, not an assertion that a
static wrapper makes virtual calls pure. No frozen movement/profile owner was
changed to implement that restriction.

The actual Inventory seed observer is exercised during ADMIT, LOAD and UNLOAD.
A successful observer that moves the worker causes the original transaction to
refuse with no quantity, claim, reserved mass, satchel, WU or XP publication.
Restoring the original station retries a completed transfer without repeating
its 2,000 milli-WU phase. Reentry poisons the original synchronous request. Work
also compares its original captured contributor with the current full Job,
Resident and agent links before publishing progress or skill credit.

## Claim time

The authoritative decision tick is the bound Clock's `completed_tick + 1`,
matching `SimClock._drain_ticks` and GameManager's pre-increment step convention.
A claim with `expiry <= decision_tick` refuses, even if the normal Pool expiry
sweep has not yet run. The captured decision tick must remain unchanged through
all observations. Cold admission conservatively requires validity for that same
next tick. Cancellation releases original claims/grams independently of expiry
or productive permission. No second clock or persistent per-haul time column is
introduced. The real Clock regression permits work during tick 1 for expiry 2,
then rejects it inside tick 2 before `_completed_tick` increments.

## Diagnostic dependency restoration

Early isolated checks explicitly pinned the 1141 diagnostic source overlays and
restored their original bytes before consuming the accepted commit
`064f0c0d1b5e71059215b23755a249ea3a066c65` (local `f1602e0f`). Subsequent checks use
that committed Inventory/Reservations/protocol source. A temporary, hashed
registry appendix is restored after each test invocation; the shared registry
and budget generator remain root-owned. Rejected bring-up and adversarial runs
remain in this decision's evidence directory.

## Reviewed return boundaries and prepared work

The actual post-super Pool/Planner adversaries showed why their outer return
paths also belong to this concrete coordinator's no-observer boundary. A real
guarded LOAD could succeed, then an overridable Pool wrapper could reassign the
worker before Delivery published its original Job and satchel columns. The
coordinator therefore requires the exact existing Pool and Planner scripts at
initialization and final use, including cancellation. Inventory's explicit
observation authorities remain supported; their callbacks run inside the
separately reviewed 1141 journal guard. No lower-owner observation support is
removed. Cold implementation refusal occurs before caller packet allocation and
clears provisional binding references.

A current productive claim is proved again after ordinary source observations.
The exact full Job, claim row, lot, purpose, quantity, expiry, Planner destination
and grams must still match; a previously copied expiry alone grants no work. A
real observer releasing the claim reproduced unwanted WU/XP progress in the
rejected source. The final leaf requires the real current reservation before
publishing any progress; staged transfer after-facts remain owned by 1141.

Work also freezes its computed factor in existing transient party cell 14 before
observations. A legal late `work_factor_of` read for another actual resident
previously overwrote shared scratch and changed the original worker's remainder.
Publication now uses the prepared factor together with the already retained
needs, skill, progress and original full contributor checks. No new authoritative
column, allocation, handling rate or rounding rule is introduced.

## Actual finite delivery into paid installation

The passing candidate-10 real-owner test completes the four L0 cubes, then moves
two actual wood payloads of 2,400 and 1,600 milli through route arrival, loading
Work, satchel transfer, CARRY travel, HAUL_OUTPUT unloading Work and guarded
unload. Each payload earns 2,000 + 2,000 milli-WU. The initial post-excavation
material store has 1,500 milli: the first delivery reaches 3,900 and the unchanged
4,000-milli assembly bill correctly refuses START. After the second delivery the
store holds 5,500; the original primary BUILD Job then pays exactly 4,000 and
publishes the real raised, non-supporting workpiece, leaving 1,500. This closes
the prior diagnostic second-WORK delivery bridge for that tested path. All
handling/CARRY motion certificates in this fixture remain explicitly synthetic.
