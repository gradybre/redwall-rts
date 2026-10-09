# 1112 — Source-phase route motion

Date: 2026-10-03 · Status: implementation contract **proposal**, not runtime,
pace, save-format or production-profile activation.

## Decision proposed

An explicitly tagged source-motion span advances an integer source phase, then
derives both pose and actual root from that phase. Reuse Routes' existing actor
columns and Transform position/yaw; do not infer phase from XYZ distance. The
current ground-distance path remains unchanged. This is a bounded first
nonlooping-program contract, not an arbitrary animation state machine.

The actual 128u ascent source contains four stationary-root adjacent intervals
while feet move. Distance cannot distinguish their poses or support. The source
also proves only its provisional two-deck fixture, not actual paid treads,
descent, repeated steps, landing transitions or a completed entrance.

## Exact source boundary

Paths below are relative to
`godot/data/underground/mole-worker/evidence/contact-qualification/` in the
content lane. Bytes were read and hashed; no native or geometry tests were
rerun for this proposal.

| Source | SHA-256 |
| --- | --- |
| `stair-motion-v15/mole-worker.ugactor` (219560 bytes) | `3a9e2459edba1bf4eaa50f91b5accb53f53317e5fc67bfa75b4a4b4cb8ac6988` |
| `stair-motion-v15/candidate.json` | `3f66b788004e971f8291f81b714aedaaaef77185974aae47cf540521508e0334` |
| `stair-motion-v15/plan.json` | `8aa50f9d5bb508bdb2cd6e34d047f73f18a8ae45a784c1b790057aa136251ef4` |
| `stair-motion-v15/terrain-v3.json` | `caef0c5208a06a15d62f63b86a12673179dee929506a527dfac918e1077d9258` |

The image header's candidate/plan digests at bytes120:152 and152:184 match
those files. Plan revision100 is source identity, not a gameplay revision.
Only attempts[0]/case0 is this 128u-rise,512u-run candidate; case1 is the failed
256u comparison. There are91 integer root rows,91 planted masks and90 adjacent
support records. Source roots start(0,0,0) and end(0,128,-512). Floating ankle
authoring targets and the `production_qualified=false` record cannot grant
runtime support. The preview's nominal3 seconds is diagnostic; **no pace value
is adopted here**.

## Content and state contract

An actual immutable motion-program owner must bind the complete source digest,
program ID/revision, clip ID, exact Catalog row/variant/content revisions and
exact Profile ID/revision/content. A versioned `SOURCE_PHASE_V1` discriminator
belongs to that immutable edge/program contract; connector family alone cannot
select it. Missing or mismatched programs refuse. The edge's full generation,
Placement/prefix, actual containing section and installed support remain
separate live facts. No caller-supplied success flag creates this binding.

| Existing actor column | Distance span | Proposed source-phase span |
| --- | --- | --- |
| `R_SEGMENT` I32 | Polyline segment | Source interval0..89 |
| `R_PROGRESS` I64 | Whole distance within segment | Whole Q16 share0..65535 |
| `R_REMAINDER` I64 | Reduced sub-unit distance | Reduced sub-Q16 phase units |
| `R_PHASE` I32 | Idle/queued/travelling/held | Unchanged lifecycle meaning |

The two-lane reduced remainder keeps its existing positive31-bit bounds and
overflow refusal. Other full actor/profile/Job/tool/load refs stay unchanged.
The same transient MotionStep fields can stage interval/share/remainder before
one commit. No new per-resident column, Transform field, route-link map or
source-time counter is proposed. Saved bytes still need a versioned semantic
contract: old distance values must never be reinterpreted as phases. The
unimplemented Routes restore/parity gate is not closed by keeping field sizes.

For the first program, `q=interval*65536+share`, with
`0 <= q <= 90*65536`. Ordinary intervals use rows i and i+1; the terminal value
uses row90/row90/share0. `Content.clip_into` adds its absolute first-frame offset;
root rows stay relative0..90. This source has no short terminal interval.
Looping/short clips require their own existing finish-interval rules and are
outside this first implementation. A completed edge transfers to its real
endpoint and retains no occupied terminal interval.

One phase selects all body/tool matrices and this exact root equation:

`root[axis] = ceil((a[axis]*(65536-share) + b[axis]*share) / 65536)`.

Use signed integer ceil, then the certified exact orientation and checked
integer world translation. Do not interpolate or round the already-rotated
endpoints instead: ceil does not commute with a sign-changing rotation. Every
product/narrowing must be bounded; failure preserves the committed actor.
Yaw follows the admitted source/orientation, including stationary roots, not
an inferred tangent. The current candidate is yaw0, not an all-yaw certificate.

An adopted positive integer **phase-units per second** must be pinned by the
program revision before execution. The existing30Hz rational machinery can
advance those units and convert unspent time across different authored rates.
No value is inferred from ground pace, tread dimensions or preview frame rate.
Every crossed source interval is checked, even if both roots are equal.
Finite transition/work exhaustion refuses without banking blocked tick time.
Source spans may only split at explicitly certified phase/containment handoffs;
generic polyline subdivision cannot restart a clip or erase its stationary time.

## Proposed executable seams and ordering

Cold program admission must independently validate emitted integer root rows,
complete body/clothing/tool interval occupancy, anatomical full-foot support
obligations, continuous witnesses, numerical residuals and certified entry/exit
poses against the **actual installed** full-generation support/section refs.
Neither a planted bit nor a source fixture deck proves current world support.
The compiled program must retain exact source provenance and a bounded mapping
from source intervals to their real section/support obligations. Its schema,
capacity and memory admission are prerequisites, not hidden additions here.

The proposed provider seam is
`phase_motion_refusal(worker, edge, from_interval, from_share, to_interval,
to_share, selection) -> StringName`. Base providers refuse. The concrete
provider resolves the exact immutable program from the actual edge; callers
cannot substitute root/support coordinates. It validates each traversed phase
range, current terrain exclusions, supported feet, whole body/tool clearance,
dynamic occupancy, exact Job/Work/Gear/load, and actual committed source pins.
This complements, rather than replaces, static route eligibility.

Routes builds one candidate step, completes every provider observation, then
checks original full actor/edge/source/geometry/Transform identity and poisoned
callback state through concrete leaves. Only then may a callback-free commit
update integer Transform root/yaw, phase columns, containment, occupancy and
consumed route links. A held phase preserves its supported committed pose.
Cancellation releases future links and retains the occupied source program;
it cannot reset phase, reverse the unqualified clip or remove supporting parts.
Source replacement/geometry removal must preserve occupied obligations or
refuse before mutation. Gear/load changes cannot silently borrow old clearance.

For presentation, propose
`Routes.read_actor_motion_into(worker, out_actor: Actor, out_phase: MotionPhase)`.
Both caller packets are sized before the call and remain unchanged on refusal.
MotionPhase has11 integer fields: kind, program ID/revision, source ID/revision,
clip ID, Catalog row/revision, variant revision, interval and share (88 logical
bytes, one reusable caller packet). Actor supplies full worker/edge/profile
identity and actual root/yaw. This read makes one coherent observation; the
renderer uses its source phase and never advances authority from render time.
No packet or native allocation is authorized merely by this proposed signature.

## Memory, ownership and acceptance

The resident/Transform SoA delta is zero. That does **not** make the program
free:91 root XYZ I32 rows alone are1092 bytes; masks, interval body/foot proof,
source identities, load overlap and native headers are additional. The last
4096 binding bytes are earmarked for Contacts, not this program. Before source
implementation, provide a complete joint source-counted live/load/cold/caller
coexistence census and explicit admission within the unchanged overall budget.
No full triangle trajectory or per-resident program copy belongs in tick code.

Geometry would own Routes' phase branch/tests and its actual WorldRoutes
consumer under an explicit follow-on lease. Root would own actual installed
world/support composition. Content would own the immutable program/compiler,
source certificate and Actor driver phase consumer. Transforms needs no new
storage; any writer change requires its own narrow lease. These are proposals,
not permission to edit another lane. Pace adoption and production activation
remain separate from all three implementation slices.

Required acceptance includes: stationary roots with advancing foot phase;
negative/quarter-turn ceil parity with native rendering; exact final row90 and
entry/exit handoff; interruption/blocked-prefix with no banked time; pause and
1x/2x/4x equal-tick parity; full source/edge/support retirement and revision
refusal; actual Job/tool/cargo changes; late callback replacement/reentry;
multi-interval budget exhaustion; complete native/256-resident timing and
memory; versioned mid-interval save/resume parity. Tests may use synthetic
rates to verify arithmetic, clearly separated from any admitted production rate.

## Sources and limits

[SET-MOVE-001](../movement_direction_amendment.md), decisions1075/1080/1090/1101,
the exact source packet above and its `review-stair-ascent-v1` record supply
this proposal. The source author confirmed interval/terminal semantics. This
document neither changes the existing first-entry recipe/geometry candidate
nor certifies the128u fixture, reverse descent, landing turns, loaded traversal,
safe retreat or playable Kitchen construction. No runtime test or activation
is claimed by this documentation-only change.
