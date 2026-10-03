# 1107 — Exact paid-cut unions for non-flat entry plans

Date: 2026-10-03

Status: scoped claim component independently reviewed and verified; not an accepted entrance or worker sequence.

Decision1101 requires a distinct EntryPlan and one permanent Corridor. A flat
RoomPlan's painted cells and common floor height cannot describe stair pockets.
Root owns this increment on `codex/underground-paid-cut-contact`, including the
new entry cut cursor and tests. Construction explicitly stopped writes and
leased `excavation_sites.gd` and its claim-batch test for the narrow typed entry
adaptation. Geometry retains Placement, SpaceOwner, Locations and Routes.

The concrete entry cursor accepts a finite union of integer half-open world
boxes `[x0,y0,z0,x1,y1,z1]`. It maps their union to the same immutable Domain,
1024u physical quantum and Y/Z/X key rank used by Sites. Overlapping heights,
parts, clearance pockets and duplicate boxes produce each intersecting complete
cube once. Gaps remain absent. Box order is immaterial. This is derived cold
geometry, never another physical history, pricing owner or permission to dig.

The cursor borrows the caller's private immutable box image and allocates one
eight-byte interval per input box. Each next occupied Y/Z band is selected by
a bounded scan which jumps empty coordinate spans. An in-place heapsort and
interval merge yield increasing unique X keys. Every scan, sort step, merge
and emitted key consumes the same finite operation allowance. Capacity or work
exhaustion invalidates the operation; a partial stream is diagnostic only.
Domain/rank overflow and malformed/out-of-bounds input refuse before allocation.
The existing Space.MAX_REGIONS is the cold input ceiling, not a new player
room-size limit. Actual composed byte/work admission can refuse smaller inputs.

`scratch_bytes(B) = 8B + 512` counts the interval bank and conservative logical
scalar/frame controls, separately from all caller/provider/private24B images,
Godot object/packed-array headers and other native overhead. No full Q-key image
is retained. A complete stream may rewind only with an allowance taken from its
remaining original budget. Replay allocates no new bank and accepts no new
input or callbacks.

The Sites adaptation uses a distinct EntryClaimInput: actual World, base level,
space revision and absolute boxes, with permanent purpose fixed to Corridor.
It constructs this exact concrete cursor internally under the original actual
Budget/token; a caller cannot supply a replacement cursor. Existing physical
history checks, full future Room generation, prepaid replay and sorted-key
publication remain shared. Ordinary RoomPlan/CutMap admission stays unchanged.
This adds no per-Site authoritative column or work counter.

All observers must finish before actual Room allocation. Later EntryPlan
composition must prepare exact future Corridor, sealed Space and Placement
identity/claims together and publish only their already-proved receipt. Creating
a live Corridor first and then calling the observed Placement register API
would leave a partial order and is not accepted. The installation frontier must
still prove real paid support, material/output contacts, full actor motion and
retreat; this cursor supplies none of those facts.

Verification will compare the stream with independent cube/box intersection,
including varying-height overlap, negative offset datums, gaps, permutations,
exact capacity, finite-work exhaustion and prepaid replay. Actual Sites tests
must additionally prove original-token ownership, callback mutation, history
races, all-or-nothing claims and unchanged flat-room behavior. Review and strict
summary/diagnostic/analyzer evidence are required before acceptance.

## Review and final observation boundary

Review reproduced wrong physical keys on both the new entry and existing flat
paths: an overridable second Domain descriptor changed datum X by one after the
first actual namespace proof, causing an extra actual X0 claim. A companion
regression revoked/replaced the Budget during that second observation. Sites
now creates one private concrete Domain from the sole attested descriptor only
after actual namespace/original-lease checks, and gives that copy to either
concrete cursor. No flat CutMap API or RoomPlan geometry rule changes. The92
logical private Domain bytes, its temporary24-byte configure bounds and copied
descriptor/nested scalar facts coexist inside the existing2048 control reserve;
native headers remain separately unmeasured.

Final independent Construction review accepted cursor and Sites source/test
pins. The clean focused five-suite run passed119 tests/28,414 assertions with
zero strict/raw unexpected diagnostics and object/resource leaks; the analyzer
found0 warnings across5 files. Source hashes stayed unchanged and assets were
restored. Rejected iterations and all accepted raw evidence are in
`docs/validation/evidence/underground-entry-claims-2026-10-03/`. This does not
complete actual EntryPlan/Placement confirmation or a playable first entrance.
