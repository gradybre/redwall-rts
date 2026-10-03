# 1095 — Derived room cut map
Date: 2026-10-03 · Status: Accepted (derived cursor and static admission capacity only)

## Decision

Keep the exact painted RoomPlan separate from its whole ECON-001 physical
excavation bill. A synchronous derived cursor emits every touched 1024u cube
exactly once in the immutable Sites Y/Z/X key order. It owns no history,
Room, project, worker or physical publication.

One N-row I64 active-prefix interval bank is gathered from canonical fine
X runs, sorted in place and unioned for each physical Z band/Y layer.
The cursor skips absent Z spans without scanning empty coordinate space.
Its caller supplies a finite work and cube envelope no larger than the actual
Domain work limit. Actual Sites binary searches debit17 probe steps against
the same cursor allowance; one emission is separately charged. Exhaustion is an
explicit refusal, never an accepted partial or silently truncated plan.
All transformed endpoints and the full Domain rank fit their signed
integer domains before the variable bank is allocated.

## Actual admission boundary

RoomBindings keeps the existing World-owned cold lease, protected original
input, exact Level/Terrain checks and unfiltered retained Space image.
It streams this derived union against actual Sites and the remaining
permanent history capacity, with no claim/payment/Directory writes.
Existing history still requires the separate retained-cut companion; it
cannot become virgin yield. The monotonic physical row remainder is checked
again after final source callbacks so late history insertions refuse.

Sites.remaining_history_capacity() is an allocation-free read of
capacity minus permanent count in the actual successfully bound, still-live
World composition. Refused initialization, expired spatial owner or a
recycled World returns-1. Releasing a Room claim never restores history
capacity. This reader is an observation, not a reservation or permission.

## Cold lifetime and scope

N remains the existing approved Footprint ceiling16384. The copied plans
are charged24N, the unfiltered sparse image48R+16O is327680 at the actual
6144/2048 pack, and this cursor adds8N. Packed validation's13N+8 is a
sequential peak. Total logical admission peak is
max(327680+8N,13N+8)+24N+2048 =854016 at maximum N, within the
unchanged1048960 cold arena. The cursor has sixteen I64 controls128, five Vector3i values60 and
two booleans2 =190 logical numeric bytes. They and bounded synchronous
helper frames remain inside the existing2048 controls; native headers,
Dictionary and allocation growth remain separately obligated in the shared
bindings reservation. This arithmetic is not a native RAM measurement.

The input array borrows the already protected RoomBindings plan and is
never written by the cursor; callers must keep that private input unchanged
for the synchronous loop. `clear` replaces the borrowed handle rather than
clearing its shared data. Original player input is checked by RoomBindings
after collaborating callbacks. The complete stream and all copied scratch
are synchronous and disappear
before the actual token is released. No persistent/canonical/save column
is added; physical state remains exclusively in Sites. Exact fine claims
and FINISH mask/residual publication are unchanged.

## Remaining integration

Actual prospective entry/profile/contact feasibility and an atomic
reserved-key publication companion remain required before Room acceptance.
No temporary Room/Job, free corridor/connector, support, tariff or production
permission is introduced. Current successful static observations still
return PROSPECTIVE_ENTRY_CONTACT_UNBOUND.

## Source

ECON-001–006; approved underground room plan and D29 actual-world painting;
decisions1056,1083,1091,1092,1094; root's bounded1095 ownership approval.

## Verification

Independent root source review accepted all six final pins without blocking
findings. Final affected component/regression results:128 tests,66972
assertions,0 failures; every strict/raw unexpected diagnostic and object/
resource leak count is0. Analyzer reports0 warnings in0 of6 files.

The actual16384-cell Room fixture reaches the deliberately unbound entry
gate with4096 unique Site lookups and unchanged authoritative state. The
separate test oracle covers all 511 nonempty 3×3 unions at three pitches. Raw import,
validated shard manifests, JSON summaries, logs, final source hashes and
independent review are in
[`underground-room-cut-map-2026-10-03`](../validation/evidence/underground-room-cut-map-2026-10-03/README.md).
Earlier fixture/LSP refusals are retained and explicitly excluded from
passing evidence. No full-suite, native-memory or playable-entry claim.
