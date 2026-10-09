# 1156 — Source-qualified work approach and backward retreat

Date: 2026-10-04 · Status: Component independently accepted; integration gates pending

## Decision

Keep ordinary all-yaw ground selection unchanged. Add explicitly selected,
source-bound forward and backward WALK policies using the existing profile
record's reserved byte. These policies hold the supplied shared ready pose,
walk at one fixed body heading, and return through the complete supplied fade
to ready. They never permit free-running idle, a heading change, or an
unobserved switch to a WORK programme.

The minimum positive includes both actual approach and retreat. A narrow
wall-facing forward profile alone cannot satisfy the ordinary Room provider's
directed WORK-to-retreat proof. Backward retreat must reverse the real walk
source phase while translating away from the wall with the same body heading;
forward walk rendered over a backward root is forbidden. No turn is granted
at the work face.

## Why

The actual 1152 FRONT station stands 768u from the face. Published WALK1's
complete all-yaw pick extent is 1,256u, so the existing route correctly refuses.
The unchanged source's complete local idle/walk union still reaches 865u;
there is an actual idle vertex beyond the face. Excluding arbitrary headings
alone is insufficient.

The supplied WALK keys plus exact ready pose and every permitted convex fade
reach at most 733u forward with the conservative accepted all-heading
numerical residual. The independently recomputed cardinal residual gives
732u. Retain the conservative 733u evidence and all seven whole role boxes:
three BODY, the same three TURN_RECOVERY, and one complete foot support row.
This is a selected source programme, not clipped body/tool geometry.

The existing 1142 half-turn is not an escape: its rebased tool hull reaches
865u toward the starting face and its proof names actual T0 stair supports.

## Required contract

The immutable programme binds Actor image `adc61764…`, clip1's exact loop and
short final interval, clip0@8*65536 shared ready, all native cardinal basis
coefficients/residuals, actual tool manufacture, full foot projection and
ready/WORK joins. Forward sampling is `q mod D`; backward sampling is
`(D - (q mod D)) mod D`, passed to the existing Content interval resolver.
Do not reverse frame indices while assuming all intervals have equal length.
Both directions retain every walk-phase-to-ready fade and ready-to-walk-start
fade. Whole body/tool and support proofs must survive phase reversal.

The actual 30Hz Routes owner is the source clock. In selected policies the
existing `R_PHASE` I32 is `0x11560000 | source_phase<<2 | geometric_phase`;
the existing `R_REQUEST_TICK` I64 stores two nonnegative31-bit Q16 lanes
`old_phase<<32 | phase`. Reserved bits, unknown tags and times outside the
exact clip/fade duration refuse. Policy0 retains its original request-tick
and phase meanings. Public Actor/phase observations expose only decoded
`PHASE_*`; private encoded words never become a caller-facing phase.
This is a changed schema/save interpretation even though packed widths and
bank counts are unchanged. It is not evidence of a complete new save loader.

`actor_phase_in(actual,worker)` is the concrete read-only arrival leaf;
`actor_phase(worker)` delegates to it. `source_work_observation_refusal`
observes current physical facts before the static `source_work_leaf_refusal`
checks the exact registered worker/Job/profile/revision tuple, stationary
state and completed ENTRY→WORK subphase. The caller still owns its complete
current physical/economic proof. `source_ready_leaf_refusal` requires the
exact canonical ready state and cannot manufacture one for policy0.
`request_source_ready` stops at the original work-loop seam then traverses
recovery, or retraces a partial entry. Driver programme5 reads this state
through `source_state_leaf_into`; render availability or render frequency
cannot advance gameplay, source phase or work.

The coherent new publication uses STAND0/WALK1 unchanged; forward2–5 and
backward6–9; then the sixteen exact WORK rows10–25 under SOURCE_WORK policy3.
No duplicate automatic WORK descriptor is added. The actual +X FRONT case
uses forward5, WORK24 and backward9. Normal stop/finish must retain the
actual Job/tool through recovery before releasing the claim. Recovery after
an already released cancellation remains an explicit lifecycle gate.

Authoritative root travel keeps the existing actual Catalog
`RATE_GROUND_CAP` → Movement profile speed/revision and 30Hz integer remainder.
Root direction is the directed edge; body heading agrees for forward policy
and differs by exactly 32768 for backward policy. No speed, penalty, preview
rate, interpolation width or save column is invented. A different backward
speed would be a separate tuning decision.

Unknown policies refuse. Ordinary automatic selection ignores explicitly
selected policies, and ambiguity within each policy remains a refusal.
Existing full actor/Job/Gear/cargo/profile/source/geometry and final callback
guards apply at admission, search, every tick, stopping and handoff. A caller
boolean or a presentation `Frame.ready` is not permission to refresh a
physical profile or grant Work. The actual source clock and Route tuple must
close that handoff before composed acceptance.

## Storage and ownership

Eight new cardinal rows use the existing 98-byte profile and seven 28-byte
boxes each: paired growth 4,704 bytes. The source report's historical
Profile/Level/Motion/Session subtotal is 238,676 bytes. Including the separately
reviewed 8,192-byte retirement owner makes the prospective joint peak
246,868 / 262,144 bytes. The new publication has 26 profiles, 250 boxes, 1 source
and 9 cached consumer scripts. Both banks, all existing control/decode/caller
slices, Session and retirement remain charged; independent maxima cannot be
composed. Root owns the coherent current Profile/Motion identity rebind.

Source census finds no new retained member or resized bank in any existing
owner. The complete public admission/query frame chain is 632 bytes including
a 48-byte expression/return allowance (the preexisting corresponding WORK
chain was 624); the pure source-work leaf is 320 bytes. These whole public
query frames belong to the existing Profiles control reservation, not the
older 512-byte path-only slice. The census also includes all cold Profile
frames, both generations of loop decode buffers, hash/String temporaries,
complete Profile constants and new shared programme constants. Its 3,183-byte
logical/control count fits an explicit 4,096-byte slice inside the unchanged
32,768-byte control reserve, leaving 28,672 provisional native bytes. It is
not a native allocation measurement. The Driver retains its existing 18 pin
triples, 14 durations, caller scratch and one shared ActorContent allocation.

The Geometry lane owns the explicitly granted Profiles, Routes, WorldRoutes
and MoleProfileDriver sources/tests, additive `work-approach-v1/`, and its
evidence. Construction retains WorkFace and ordinary phase integration. Root
retains the shared publisher/Catalog outputs, consumer renewal and ledgers.
Historical published profiles remain immutable and fail closed on consumer
drift until the new coherent publication is reviewed.

## Evidence and closure

[The bounded source diagnosis and implementation packet](../validation/evidence/underground-work-approach-2026-10-04/README.md)
retain the real refusal, exact supplied keys, interval math, ownership and
final source census. Exact runtime-9 checks passed 155 tests /16,185 assertions,
all strict/raw diagnostics and leaks zero, analyzer 0/10, with source/project/
registry/assets restored. Seven source-contract, eleven native-audit and
sixteen census/runner Python tests passed. The all-cardinal native-2 replay
contains 1,504 canonical poses and 469,248 bit-exact native matrix scalar
comparisons, 9,336 assertions and 64 captures. It witnesses the actual changed
Driver/Actor on OpenGL with explicitly diagnostic spatial certificates; the
blank capture scene is not ordinary Room visual or paid-world acceptance.

Current-source publication, actual paid ordinary phase composition, native
allocation and target-hardware timing remain separate gates. Canonical headless
interruption/retry is covered; a complete save/restore loader is not. The
focused source guard timings remain evidence rather than a 256-worker budget
claim. Connected stairs, loaded handling and the general movement gates remain
separate.

Root independently accepted all 20 frozen executable pins after reading the
complete runtime/source/census delta and replaying the 11 native-audit and
16 census/runner checks. The exact review is retained at
[the independent review](../validation/evidence/underground-work-approach-2026-10-04/independent-review.json).
