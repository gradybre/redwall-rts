# 1125 — Source-qualified stationary ground turn

Date: 2026-10-04. Status: independently reviewed and strict component checks passed; production content/runtime gates remain open.

An actual ground route can arrive at a completed work station facing along its
last segment. The exact WORK profile can require another heading. A fixture
`Transforms.set_yaw` is not a production turn proof.

The concrete WorldRoutes owner gains `turn_actor(actual, worker, job,
target_yaw, max_checks) -> StringName`. This fixed-tick action requires an
already registered, idle actor at its exact current full Location, without a
queued or occupied edge or a prepared geometry transaction. Its committed
ground STAND/WALK profile must have all required source certificates, YAW_ALL,
and complete BODY_HELD_LOAD, TURN_RECOVERY and STANCE_SUPPORT geometry. Exact
WORK and stair sources cannot supply this sweep. The caller separately selects
the desired exact WORK profile after a successful turn.

All observations precede the final direct actual source, endpoint, dynamic
identity, terrain and occupant checks. Failure preserves authoritative route,
Transform and economic state. One static Transform commit checks the original
full identity, pose and mutation token, rolls previous XYZ to unchanged current
XYZ and previous yaw to old yaw, writes current yaw and invalidates once. It
neither teleports nor repeats the prior travel interpolation. Existing integer
yaw and shortest-arc presentation rules apply; no angular pace is invented.
The simulation caller issues this action on a fixed tick after arrival.
Ground actor admission alone does not establish that the presentation source
has finished WORK → RECOVERY → shared ready. The actual caller must complete
that source transition before ground refresh and turn. This component does not
advance a visual source phase or supply a gait/time policy.

Existing route/provider packets and finite scratch are reused; no per-actor
turn column, pending command, copied world image or retained permission cache
is added. Every bounded source, body and occupant pass is charged before it
runs. The final numeric helper census and strict adversarial evidence are
required before acceptance; native memory and complete-client timing remain
separate gates.

Ownership is limited to Routes/WorldRoutes and their tests, the narrow static
Transform operation and its tests, this decision and scoped evidence/registry.
The existing1124 performance experiment is saved separately and is not part of
this implementation. Parent granted the Transform sublease on2026-10-04.

Decision1080 defines all-yaw continuous-turn envelopes and exact WORK headings.
Furnishing's1123 source proof has all-heading ground body/turn/stance unions,
but its production wire remains unpublished at this decision. Synthetic
profile flags in component tests must remain labelled; this API cannot qualify
that content or claim a playable stair, work contact or whole first prefix.

## Final source and refusal boundary

`WorldRoutes.turn_actor(actual, worker, job, target_yaw, max_checks)` holds
the actual geometry, Location, source and graph owners throughout the query.
Ordinary Profile, Location and Terrain observations finish first. Direct final
checks then cover current source/claim facts, complete endpoint payload,
actual terrain exclusions, worker identity/pose/Job/equipment/cargo, and every
other living resident. A live resident without a current Routes registration
refuses; absence of a registered body is not proof of empty air. Registered
occupants retain full generation, source and containment checks. Current body
and recovery boxes are checked in all pairs.

The final static Transform kernel validates the original full Directory kind,
generation, reverse typed-row owner, positive persistent ID, exact pose and
mutation revision. It performs one yaw update only after every fallible check.
The existing occupancy revision is advanced only when it matched the original
Transform revision; an already-stale occupancy index remains stale.

Finite work is charged against the caller's original limit. The observing pass
reserves `8192 + 8O + 2R`; final scope/count passes reserve `2048 + O + R` plus
the exact FinalFacts source/claim charge. Each profile box reserves4096 checks
for its bounded Terrain and containment work. The full actual Resident scan
reserves `16 × 512`; each registered occupant reserves512 for current leaf
facts, then64 checks per source-box pair. Low limits refuse before the next
pass and leave all authoritative bytes unchanged. The exact-budget test
succeeds with zero remaining checks and refuses one check below that amount.

## Logical lifetime and evidence

No retained field, packed column, bank, saved ordinal or new cold image is
introduced. Existing Selection, Descriptor, Location, Box, bounds and source
scratch are reused sequentially under the provider/graph guards. The source
counter in the evidence records the longest declared numeric helper chain:
the observing cargo path is464 bytes; a48-byte allowance for expression and
result values gives512 within the existing helper ceiling. The Terrain
foundation path is420 and the direct current occupant tool path312 before
that allowance. Borrowed references, interned StringNames, Variant headers,
interpreter frames and existing OpResult native allocations remain unmeasured.
This is neither a zero-allocation nor native memory qualification claim.

The final isolated clean candidate7 passed133 tests /13051 assertions with no
failures, unexpected diagnostics or exit leaks; analyzer reported zero warnings
in five files. Source pins and the original project/assets were unchanged or
restored. The independent occupancy finding is preserved with its real failing
spawn/place witness, followed by unchanged-image refusal and despawn/retry in
the corrected run. Earlier failed test/loader attempts are retained separately.
The inherited route timing sample remains a failed performance qualification;
turn correctness does not close the256-caller timing gate.

Exact pins, reproduction, source-derived census and review record live in
`docs/validation/evidence/underground-ground-turn-2026-10-04/`.

Construction independently accepted all five candidate7 source/test pins and
reproduced the numeric census without rerunning engines. The unregistered
occupant finding is closed; no high/medium finding remains in this component.
