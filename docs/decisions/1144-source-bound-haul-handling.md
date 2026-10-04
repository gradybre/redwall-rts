# 1144 — Source-bound haul handling and distinct workpiece set-down
Date: 2026-10-04 · Status: Accepted direction; physical qualification pending

## Decision

Author an additive, source-hashed mole handling packet under
`godot/data/underground/mole-worker/haul-handling-v1/`. Reuse the supplied current
mesh and rig, the real carry animation and the existing wood presentation
geometry. Author actual no-tool HAUL loading, loaded CARRY, HAUL_OUTPUT unloading
and a separate BUILD set-down program. Existing consumers and published profiles
remain unchanged until the complete physical and allocation packet is reviewed.

The independently reviewed static source uses R−S=(0,0,576)u with two actual
hand/stock triangle witnesses and complete body/wood geometry. This is a measured
source contract, not a gameplay distance. Its nine source pins remain unchanged.
The additive `evidence/program-review-v1/` checkpoint extends that exact pose
through approach/lift/place/recovery with continuous source-only separation,
support and two-hand contact proofs. Native, gait, quantity and runtime gates
remain open.

The supported worker station R and Inventory storage anchor S are distinct.
Measure R−S and the actual hand/wood contact C−S from the authored geometry.
A storage Location's metadata point is not an instruction to touch the worker's
feet or to bend an animation around the synthetic zero-point fixture.

## Why

ADR1140 proves actual finite deliveries, per-payload work, repost and partial
unload through real owners, but its physical profiles are explicitly synthetic.
The existing accepted mole programs use the BASIC tool with empty cargo. Their
INSTALL adze contact is not a pickup, carry or set-down source. The original
`carry_heavy_object_walk` and ADR1067's inter-hand log are reusable inputs, not
complete source qualifications.

Separate source images avoid exceeding the current sixteen-clip presentation
limit or silently extending the accepted six-role driver. Source geometry,
runtime identities, source-derived contact and memory admission remain separate
proofs. Geometry's ADR1143 additive motion catalog is a separate owner; its stair
programs confer no hauling permission.

## Required source closure

Retain every body, clothing and cargo primitive, complete foot support, entry,
recovery, interruption/reversal and program join. No-tool HAUL meets a real wood
mesh at S from a separately supported station R. Loaded CARRY preserves the
actual quantity variant, including idle, full ground travel, turn and retreat.
HAUL_OUTPUT joins both empty and still-loaded outcomes; repost enters the loaded
hub without a second pickup. A partial unload cannot hide or delete its retained
payload. The BUILD set-down program is distinct from INSTALL and must match the
actual worker/tool state and the complete billed workpiece's source transform.

Only the exact current rig/mesh coefficients may be reused. No anatomy scaling,
mesh omission, caller success flag, inferred route, free support or new balance
constant is authorized. Existing 2,000 mWU loading and unloading per payload,
capacity-limited shipments, Catalog wood mass, wood-only assembly prices and
Work/CARRY formulas remain authoritative. Source timing does not create a second
economic work clock.

## Runtime seam proposed for later review

Keep the actual Inventory container's full STORAGE Location as S. Resolve a
separate already-live full worker Location R with the authored station offset,
exact World/Room/section/level and support. Route the actual worker to R. The
immutable service row pins its source image/program/profile/revision, cargo
variant and measured curved-mesh grip certificate. This is distinct from the
existing planar `CONTACT_PATCH` used by CUT/INSTALL; neither the storage anchor
nor a convenient planar box substitutes for the two actual hand contacts.
The final transfer leaf must recheck both
full Locations, the exact Inventory association, source digest, R/S/C transform,
current worker/PID/Job/cargo/claim, current tick and the original chosen
destination before committing. It must not add a per-Job goods or destination
ledger. This is a proposal, not a new runtime entry point in this increment.

Source tables, decoded image, compiler scratch, render mesh and replacement
lifetimes need a complete census before admission. ADR1140's unused allowance is
not permission to allocate them. Share or replace source images only after joint
review with ADR1143 and the existing Profiles/presentation reservations; do not
charge PROFILE_BYTES twice or enlarge the decimal 100 MB limit.

## Provenance and boundaries

The author opened DEC-038's grounded expressive example and supplied IMG-08 and
IMG-25. They guide the existing mole's compact mass and readable working motion;
their troop counts and relative pixels are not measurements or game rules. The
already approved mesh remains unchanged. All generation is local deterministic
authoring of existing supplied inputs; no paid generation was requested.

Only this ADR, the new `haul-handling-v1/` subtree and dedicated evidence are
owned here. Furnishing's stair handoffs, Geometry's motion catalog, accepted
profile consumers, Delivery/Work/Planner/Inventory and the shared registry remain
outside this increment. Production hauling/handling activation and the complete
blueprint-to-empty-Kitchen milestone remain open until their actual composition
passes.

## Source

Root's explicit 1144 additive source lease; ADR1140 and ADR1134; accepted
`review-install-source-v1`, `review-install-program-v1` and
`review-install-program-native-v1` evidence; final `install-source-v4` and
`install-program-compile-v3` inputs; ADR1067; DEC-036/037/038/039 and
SET-MOVE-001. Exact input hashes and all authored/rejected candidates are retained
in the new subtree rather than replacing earlier evidence.

## Reviewed source checkpoints

Root independently accepted the static checkpoint after reading the complete
source and contact packet, inspecting three views, verifying nine input and
twenty-two output hashes, and replaying all fourteen tests. It then accepted the
four-phase checkpoint after reading the four new source files, verifying all
twenty-four input and thirty-five output pins, inspecting the lifted poses and
replaying thirteen tests in 53.877 seconds with zero failures. Root retained the
independent evidence under `docs/validation/evidence/underground-haul-static-review-2026-10-04/`
and `docs/validation/evidence/underground-haul-program-review-2026-10-04/` on the
integration branch. Both verdicts are source-only; none of the open activation
gates above is waived.
