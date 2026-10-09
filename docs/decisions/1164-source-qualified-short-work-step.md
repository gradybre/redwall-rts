# 1164 — Source-qualified short work step

Date: 2026-10-05 · Status: Source implementation; runtime admission pending

## Decision

Author a separate finite READY → 232u step → READY programme from the unchanged
supplied Mole walk keys, and its actual reverse. The first instance keeps body
yaw49152 and moves along +X or −X. It uses the existing small-Mole3277u/s ground
rate at30Hz; it does not select a new pace or truncate a full-cycle permission.
All full body/tool geometry, the native numerical residual, floor intersection,
foot support, complete ready fades and exact HIGH/FRONT ready joins remain.

This additive source packet does not change any current Profile, Routes, Driver,
Catalog or World owner. It issues no qualification bits, paid state or runtime
permission. Current v3 remains the accepted baseline. A later separately reviewed
consumer must enforce the finite protocol before these smaller bounds can be
published or used.

## Physical purpose

After the two first-layer Kitchen cubes at relative origins `(2048,0,0)` and
`(2048,0,1024)` have each completed real BRACE/CUT/FINISH, the supplied HIGH23
programme fits at roots `(1512,0,512)` and `(1512,0,1035)`. Its536u contact reach
requires a232u advance from the corresponding FRONT root atX1280. The full v3
WALK cycle reaches1036u high inside the paid1024u pocket. The complete first
three emitted movement ticks reach at most972u forward and966u backward.
Those finite source subsets, not clipped envelopes, provide the smaller step.

Coordinates are relative to `(122880,-4608,102400)` in the accepted real Room
fixture. Both stations still use the old Corridor's support and Room identity;
the target Site belongs to Kitchen. The second upper root isZ1035 because its
unchanged high tip extends11u toward −Z. Every added cube retains actual bills,
work, spoil, structural proof, worker/source facts and final-publication guards.

## Exact source and integer lifetime

The Actor image remains `adc61764…`, with its fourteen existing clips. READY is
clip0 at8*65536. The finite step samples clip1: forward atq and backward at
`(2097153−q)%2097153`. Its one-Q16-unit loop seam is retained. The conservative
forward endpoint set is0,1,2,3 plus READY; backward is0,32,31,30,29 plus READY.
All convex fades from READY to frozen walk0 and the terminal pose back to READY
must complete. Every allowed interruption freezes the original root, phase,
source, heading and rational remainder, then resumes that exact state. No
offscreen renderer decides progress, and neither a reset nor another route may
extend the prefix or return it to key0 mid-step.

Existing Routes distance is an exact reduced rational fraction, encoded in its
I64 remainder. For every admissible0≤r<1, adding3277/30 per accepted movement
tick traverses232u in exactly three ticks. The last tick clips to the endpoint;
with no queued successor, existing Routes discards remaining time and stores
zero. A finite step forbids successors, bends, changed pace and a fourth root
tick. Denominator overflow, stale tuple and malformed time refuse atomically.
Earlier30-residue arithmetic is only a subset of this rational-state contract.

The new source model is a reference for a future canonical owner, not a second
per-resident clock. Future runtime storage must reuse admitted route columns or
receive an explicit separately counted schema before implementation. Unknown
policy/version, body/path heading, full source or endpoint identity must refuse.

## Storage and remaining boundary

Two proposed seven-box +X profiles would add1176 paired bytes to the existing
Profile arena, reusing the exact Actor source digest. No second ActorContent
image, geometry, palette or per-resident bank is proposed. Controls, source
identity, decode and presentation coexistence require an exact census before
joint admission; the existing262144-byte reservation and all global limits
remain unchanged. The additive offline compiler must bound its own inputs and
allocation before materialization.

The lateral gateway requires a separate real multi-leg route and supported
READY/turn handoff. The current provider's single fixed backward profile does
not express it. This source programme does not grant that handoff, stairs,
loaded hauling, a whole4m-high Kitchen, native rendering or gameplay release.

## Source

- SET-MOVE-001 and existing Routes rational ground distance/clock semantics.
- ADR1156 and immutable v3 Profile/Actor/source proofs.
- The exact frontier review in commit937aeb5b, including the rejectedZ1024
  contact and corrected complete translated bounds.
- Root's bounded source-only lane: `work-step-v1/`, this ADR and the dedicated
  short-step evidence; shared consumer sources remain read-only.
