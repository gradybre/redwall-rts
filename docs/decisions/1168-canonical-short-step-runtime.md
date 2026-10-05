# 1168 — Canonical short-step runtime

Date: 2026-10-05 · Status: Independently accepted component; production integration pending

## Decision

Consume the accepted ADR1164 finite232u source programme through the existing
Routes phase, clock, progress and rational-remainder columns. One terminal,
straight, level232u span at the existing3277u/s rate is the entire request.
The source admits exactly three accepted root ticks, preceded and followed by
the complete READY fades. A refused tick preserves its original source phase,
root, route and remainder. Replacement, cancellation, profile refresh, changed
pace, a bend, another span or an extra root tick cannot restart or extend it.

Keep wire-v2 and every row width. Proposed explicit policies4/5 are the short
forward/backward programme; policy6 is canonical all-yaw ground travel. Legacy
policy0 keeps its request-tick and public route-phase meanings. Every source
policy uses a versioned tag in the existing phase/clock union. Public phase
readers return only PHASE_*; source readiness remains a separate exact-tuple
leaf. Save interpretation changes despite unchanged widths and must validate
the admitted programme/tag, phase, original full refs and every clock bound.

## Source and row identity

The additive `work-step-v1/source_program.gd` defines protocol6. The existing
`work-approach-v1/source_program.gd` and v3 source artifacts remain immutable.
The proposed new publication keeps rows0–9, inserts +X short-forward10,
short-backward11 and all-yaw canonical-ground12, then shifts the unchanged
sixteen WORK rows to13–28. Existing loader key ordering requires WALK before
WORK. The resulting29 profiles/271 boxes reuse the same one Actor digest and
all fourteen source clips. No descriptor, body/tool mesh, complete box,
support requirement, numerical residual, or paid state is shortened.

Canonical ground uses the complete existing all-yaw ground seven-box union.
Its source begins at the exact shared READY pose, includes every emitted walk
interval and complete fade, and never uses renderer availability or elapsed
render frames to advance authority. Protocol6 WORK and approach/recovery use
the unchanged supplied equations and shared READY identity.

## Initial enrollment and handoffs

Only original fresh Routes admission may initialize canonical ground at READY,
after the actual full Resident, Transform, source, tool/cargo, Job, endpoint,
support, body and exclusive movement observations. Host enrollment precedes
presentation of this new source actor. An existing legacy Routes actor has no
canonical animation phase: it may not be silently converted, unregistered and
readmitted, or reconstructed from presentation state. Legacy-to-canonical
takeover therefore refuses. This is an explicit host initialization boundary,
not a renderer callback or a claim about existing legacy save compatibility.

An already canonical actor may change profiles only at its exact original
stationary READY endpoint. Canonical all-yaw ground12 provides the wide
gateway phase for ordinary graph travel. Selected approach, short-step and
WORK sources retain the body heading and their actual path direction. At a
wide gateway a turn requires READY plus the existing whole ground all-yaw
support/body/recovery and actual occupancy proof. The existing fixed-tick yaw
command retains its Transform interpolation history; there is no turn grant
at the narrow work station. All Job/tool/source state remains retained through
work recovery before release.

## Allocation and ownership

No additional actor columns, route links, graph bank, palette bank or
ActorContent image is proposed. The three additional seven-box profiles add
1764 paired numeric bytes inside the existing PROFILE_BYTES allocation.
The complete census counts both source-program payloads once: 996 bytes,
including UTF32 terminators. Profile fixed packets/constants plus the larger
complete cold/hot lifetime total 3,571 of the existing 4,096 logical controls
inside its unchanged 32,768 reservation. The full moving occupant/cargo path
is 877 bytes; the turn observation/cargo path is 504 of 512, including its
outer turn caller. Pure WORK/READY leaves are 344 each; foreign consumers
must add their own frames. Current joint Profiles/Levels/Motion/Session and
the single Retirement/composition slice total 248,632 of 262,144 bytes.
No global reservation or capacity increases. Native/reference allocations
remain provisional; component timing does not qualify game-scale throughput.

Geometry owns Profiles, Routes, WorldRoutes, Driver and their existing tests,
the additive work-step runtime protocol/harness, this ADR and its evidence.
Root owns publication, Itinerary, Provider, Frontier, WorkFace, FinalFacts,
Locations, shared memory tooling and current consumer closure. Actor/Content
remain read-only unless a concrete separate seam is granted. An immutable
diagnostic wire may exercise actual rows but does not renew production source
approval or confer whole-game qualification.

## Required evidence

Headless actual-owner enrollment→ground travel→READY/turn→selected approach→
short forward→WORK entry/recovery→short backward→gateway/retreat must retain
the exact source clock. Invalid length, pace, direction, successor, state,
generation, source revision, occupancy and late observations must refuse
atomically. Interrupted ticks and serialized original columns must resume
equivalently. Native replay must consume that same canonical state and the
actual source palette; the accepted source-only proof is not this evidence.

## Frozen evidence

The exact candidate and rejected attempts are retained under
`docs/validation/evidence/underground-short-work-step-runtime-2026-10-05/`.
The four strict suites pass 167 tests and 18,407 assertions with zero failures,
diagnostics or leaks; the targeted analyzer reports 0/11. Final native replay
passes 462 poses, 144,144 exact binary32 scalar comparisons, 46 side/RTS
captures at 1280×720 and 2,558 assertions. It uses the actual source Actor and
WorldRoutes clock but explicitly unearned diagnostic geometry/certificates.
Fifteen independent native-audit tests, six serializer tests and thirty
source/census tests pass. No actual paid-world or default-renderer activation
follows from that component evidence.

The final source manifest is `source-review-2/source-sha256.json` in that
evidence directory. `runtime-7` and `native-4` use those exact frozen sources.
Independent review R1 found that the original census admitted new collection
literals and enlarged packed-array initializers without charging them. Its
rejected source, exact call contract and executable counterexamples remain
under `source-review-1`. The corrected census closes full literal payloads,
local types and code-token/allocation expressions before accepting the same
logical count. The sole runtime correction removes one redundant eight-byte
clock local; the original column is read directly in three pure calls. This
reduces the complete foreign Provider chain from 517 to 509 of its existing
512-byte helper allowance without changing a guard, state, rate or reserve.

Construction independently accepted the corrected twenty-one source pins,
reproduced all four original allocation counterexamples as refusals, and ran
thirty census tests plus fifteen native-audit tests against the final replay.
The byte-exact review is retained in `independent-review/acceptance.json`,
SHA256 `6613e4cfa8c1b3a17b779d19bff46f8fb16b6115da5f50f47fc5f8a78818a37e`.
It reports no remaining high/medium findings and leaves current-consumer
publication, actual paid next-cell composition, World activation, native
memory and target-hardware performance open.

The WorldRoutes ground-only Catalog fix is included: a real positive ground
pace and all six empty variant/table counts may use the existing full owner,
digest and source checks without fabricating variant zero. Malformed mixed
tables, zero pace and stale source still refuse. This makes the actual finite
ground source usable by the component; it does not qualify terrain or routes.
