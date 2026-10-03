# 1075 — Actual world, terrain and contact bindings

Date: 2026-10-03 · Status: Accepted engineering packet; implementation in progress

## Decision

Bind the paid underground spatial adapter to the actual WorldInit, Buildings,
Construction, Inventory, Residents, Transforms and work/logistics owners. The
rendered village must use these actual locations and full references. A separate
demo actor position, preview region or successful sampled animation cannot grant
excavation, travel, inventory transfer or services.

This lane owns new `underground_world_bindings.gd` and `underground_locations.gd`
and their tests. It also owns narrowly additive, read-only identity readers in
Transforms and HaulCarry and corresponding tests. Existing transaction owners
remain UG07's lease. The integration owner separately extends real spatial
Inventory endpoints; this lane must not encode depth in a surface tile integer.

## Actual sources and the integration boundary

`settlement_system.gd` constructs the real stores and publishes WorldInit and
StarterColony. `demo_village.gd` currently hides that representation and draws a
separate presentation layout/cast. WorldInit spans positive 0–256m coordinates;
its ordinary land elevation is 512 world units. DemoWorld uses a much smaller
layout around the origin at Y=0. A view transform can center real simulation
coordinates, but cannot make the present arbitrary building layout coincide with
actual StarterColony footprints. UG09 must bind meshes, picking, actors and stock
displays to actual owners. Presentation transforms never change the paid lattice.

The following are usable owner data, not inferred geometry:

- WorldInit: published World/seed, surface terrain, soil, elevation and basin refs.
- Buildings: actual building type/origin/rotation; Room spatial kind and immutable
  purpose; actual furniture type/rotation and pending/installed distinction.
- Residents/Transforms: full Resident generation, species, life stage, rig binding
  and integer XYZ. Transform XYZ has one owner; the new location state adds real
  section, containing Room, mode/posture and committed route/contact identity.
- Work/Gear: the actual bound tool lot and its equipped owner/Job claim, item and
  manufacture. Per-worker validation never scans the whole Gear arena.
- HaulCarry/Inventory: actual satchel/carried lot, item/quantity, container owner,
  finite mass/reservations and full inventory generation namespace.

Exact borrowed-object checks prevent a foreign world with matching numeric refs
from qualifying. Transforms exposes `is_bound_directory`; HaulCarry exposes
`binding_matches`. These readers add no columns and change no behavior or state.

Existing SpatialWorld, Navigation and Movement supply a ground baseline; they do
not supply multilevel location, approach, posture or underground arrival. The
new sparse location/topology owner must provide those actual facts. Existing
ground-pile addresses name surface tiles only. Real underground piles require
the integration owner's explicit section/XYZ endpoint and atomic staging/pile
publication. Unbounded ordinary containers are not a substitute.

## Terrain, support and publication

Author finite, revisioned terrain/support content on WorldInit's actual datum.
Surface boundaries come from WorldInit; underground dry intervals, water and
resource protection, foundation/root extents and structural support must have
explicit content. A surface land label does not prove every depth is dry.
Demo TunnelGround's independent soil prices and spoil amounts are not imported.

Keep every physical cut an exact 1024u cube under ECON-001. Confirmed footprint
claims belong to the real Room; transient paid phases belong to their real
Construction. Prospective fresh-cut validation and retained UNFINISHED finishing
stay distinct. A paid cube alone creates no travel edge. Connected routes need
the complete body/gear/cargo envelope, supported approach and authored connector
endpoints. All approved connector families remain in scope.

Cold confirmation/phase validation derives a complete bounded survey and next
face contact. Productive WORK reads cached static revisions plus fresh actual
worker, posture, equipment, cargo and local dynamic occupancy. It must not rebuild
a survey or scan every region. Geometry, support, room services, topology and
inventory endpoints prepare before payment and publish in the exact same-stack
Sites/Router window. A failed or stale preparation preserves prior claims and
all actual world state.

## Initial technical reservation proposal

The reviewed initial composition selects R=6144 spatial rows, O=2048 source rows,
K=8192 cold-volume rows, P=256 concurrent proof rows, 256 Tips rows, and RoomLayout
capacities of 256 rooms/1024 fittings. These are explicit finite arenas, not new
player room limits or changes to global Buildings/Jobs capacities. Exhaustion
refuses before mutation. Native measurements and actual provider schemas still
have to qualify this proposal before production activation.

| Simultaneous ownership or reserved provider ceiling | Bytes |
|---|---:|
| Spatial live/staged banks, indexes and change mask: 149R + 92O + 288 | 1,104,160 |
| Static proof cache/prepared row: 69P + 60 | 17,724 |
| Paid-phase cold bound: 120K + 32O + 384 | 1,048,960 |
| Known spatial/adapter/core-reader/cold numeric objects | 686 |
| Tips live plus simultaneous capture: 107C + 65536 + 48 + 119C | 123,440 |
| RoomLayout live: 13L + 33F | 37,120 |
| Proposed topology, resident location and contact arena | 1,048,576 |
| Proposed real spatial Inventory endpoint arena | 131,072 |
| Proposed compiled profile/contact certificates, including replacement/load | 262,144 |
| Proposed terrain and support content | 131,072 |
| Proposed RoomLayout cold preparation | 262,144 |
| Proposed binding controls and additional native growth | 524,288 |
| Subtotal before new shared transaction deltas | **4,691,386** |

The integration checkpoint leaves 5,009,623 logical bytes before this proposal.
UG07 additionally requires 262,144 bytes for four Job-to-Project I32 columns and
their simultaneous image, and 8,192 bytes for live/image loss-domain expansion.
UG07's reviewed transaction packet confirms three Quote buffers at 112 packed
bytes each, plus the Router's 32-byte delivery scratch. Each Quote also owns 72
logical numeric bytes and four StringName keys; those controls and native object
headers belong in the explicit binding/native reservation. The complete reviewed
B1–B3 increment, including Router and Work controls, is 271,003 bytes. The proposed
sum is therefore 4,962,389, leaving 47,234 bytes before further declaration changes.
Provider reserves are not
implemented allocations or proof that native peaks fit. Every final source-derived field/copy belongs in admission;
no missing provider receives a zero-byte allowance.

Paid-phase preparation, confirmation and save/load share one exclusive cold
lifetime. The owner save image is 68R + 42O + 144 = 503,952 bytes, smaller than
the reserved paid-phase cold envelope. Confirmation must bound all simultaneous
surveys, plans, fragments and source/index containers; three survey payloads alone
reach 983,040 bytes at these counts. It cannot assume arbitrary plans fit in the
remaining space. Typed container/Variant/allocator costs need separate measured
evidence. No independent maximum or historical 8MiB reserve is free capacity.

Sealed candidate readers return actual staged regions and a complete staged
snapshot with all claims retained as blockers. They require the receiver's
current sealed token and fresh source/claim preflight. Tokens belong to that
actual owner instance, not a global integer namespace. Returned arrays do not
alias either owner bank. The consumer must count the newly built snapshot and
any prior snapshot retained in the output argument until assignment. Production
companion preparation uses a fresh empty output and releases it before the next
cold phase; retaining a third full survey requires separately admitted memory.

## Location endpoint schema and cold lifetime

The first concrete location slice uses an explicit N (initial pack N=1024).
Each of the two banks has 22 I32 columns: local generation; XYZ; full Room ref;
full floor-section ref; level; role; six envelope bounds; six support bounds.
Two I64 columns hold the immutable payload revision and the geometry revision
whose complete cold validation established its current proof. Two byte columns
hold presence and generation exhaustion. Each bank also owns its own free-row
heap and sorted-row index (two I32 arrays). Thus each bank is 114N bytes and the
pair is **228N + 256 bytes**, including two fixed 16-I64 headers. No per-location
object or Dictionary is stored. Caller packets are temporary typed values.

The canonical one-bank image is **106N + 128 bytes**; heaps and order are rebuilt
and checked. Capture/load may run only through the exclusive cold lease, without
a staged phase, and admission counts the raw image beside both banks. Snapshot
copies needed to validate locations use the already reserved phase/survey cold
arena, never an uncounted third survey. The maximum is checked before copying.
New location payloads are immutable. Refreshing a stale static proof changes
only its geometry revision, not the payload revision retained by Inventory.
Changing a live same-generation payload through the local loader refuses even
when Inventory currently holds no container there. Canonical exhausted slots
must retain their exhaustion marker.

Location handles belong to this actual owner instance. They are neither global
Directory refs nor spatial region handles. Underground endpoints require a live
Room, its exact floor-section generation and an actual permanent Sites key at
the point's paid cube. This key supplies the typed Room-claim exemption; actual
obstacles, foreign claims and unfinished volumes remain blockers. Surface
endpoints have a World-owned floor and no Room. Full containment and support
are validated using integer boxes; a point alone is not a storage permission.

Inventory gets one weak adapter implementing its typed location contract. The
adapter compares the exact Inventory/World binding. The 2m storage-cell key is
World plus full section plus floor-divided X/Z relative to the immutable world
datum. It does not move or enlarge the authored envelope. Retiring a location
requires the actual Inventory retained-reference guard, including stale proofs;
the guard runs again at sealing, final preflight and publication, so a real
container created after staging cannot lose its location. It runs before both
ordinary and future Sites publication branches. An absent guard refuses.
Later route/actor/contact fields remain reserved work
within the same 1MiB provider ceiling, not zero-byte completed functionality.

The endpoint-only cold operation uses at most one snapshot (48K region bytes
plus 16K source bytes, conservatively using the owner's enforced O<=K), two
fragment lists bounded to K/2 six-I32 boxes each (24K), and 384 box-scratch bytes:
**88K + 384 packed bytes**. This excludes native Array/packed-handle overhead,
which must fit the separately admitted native/control reservation. The actual shared
1072 Budget replaces the provisional component ColdLease; the composer must reserve
the actual simultaneous caller plan/survey and companion peak before the first
copy, and retain the token until charged output is consumed. An independent
maximum phase plus maximum endpoint copy cannot coexist merely because each
fits separately.

## Engineering and policy

Decision1058 already authorizes engineering authoring of finite bounds, spacing,
offsets, connector dimensions and tested support/contact envelopes. These do not
need another user interview. New player-visible recipes, mode speeds or load
rules need owning numerical authoring/review. Excluding an approved connector or
construction method, a new species/age ban or changing ordinary safe access would
change the approved experience and requires an explicit proposal.

The intended acceptance is an actual Kitchen and connected tunnel, workers at
real supported contacts, paid digging, finite real spoil, finishing, retained
connected travel and room-appropriate installed equipment. Synthetic component
fixtures and the unbound base interfaces do not complete that acceptance.

## Prerequisite validation

The exact identity readers and sealed geometry readers were independently
reviewed. A clean import after moving assets aside and deleting `.godot` produced
no diagnostic lines. The strict runner reported:

```text
26 test(s), 167 assertion(s), 0 failure(s)
29 test(s), 173 assertion(s), 0 failure(s)
34 test(s), 476 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Each suite emitted the same zero diagnostic/leak footers. The analyzer reported
`0 GDScript warning(s) in 0 of 6 file(s)` with `--max 0` on port6153. These results
cover additive readers, stale/foreign owner checks, sealed/unsealed/aborted/
published tokens, removed/reused regions, source drift and copied-output
isolation. They do not qualify the forthcoming actual terrain, route, profile
or storage composition.

## Source

- AGENTS.md, CLAUDE.md, ENVIRONMENT.md and decision0006.
- SET-MOVE-001, SET-MOVE-ECON-001; decisions1058, 1064, 1069, 1071.
- User's approved in-world room planning, immutable room purpose, multi-level
  access and all approved construction families.
- Read-only actual-owner investigation and parent-approved packet/leases,
  2026-10-03. Strict execution evidence will be added for the implemented scope.

## Paid physical geometry seam verification

The actual adapter stages derived floor/support/shell geometry after its paid
matter patch and before sealing the spatial candidate. Companion topology and
services then prepare against that sealed candidate. The concrete provider must
derive actual source content; the base refuses. Prepared site snapshots require
the same real Sites/Room/phase proof as live snapshots and omit only exact
reservation markers. Actual same-Room obstacles remain blockers.

Independent review accepted this additive four-file delta. Clean strict runs:

```text
35 test(s), 493 assertion(s), 0 failure(s)
21 test(s), 2805 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

Both suites emitted the same zero footers. The analyzer initially rejected one
fixture identifier shadow; it was renamed with no behavior change and the final
analyzer passed. [Raw logs and exact source evidence](../validation/evidence/underground-ug1075-bindings-2026-10-03/README.md)
retain that rejection and the accepted runs. This verifies transaction seams;
it does not qualify actual terrain, support content, profiles or navigation.

## Immutable endpoint validation

Independent source review accepted the endpoint slice after its current
Inventory-retention checks were added. The final clean, assets-aside import
produced zero diagnostics. The strict runner and analyzer reported:

```text
16 test(s), 358 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

[Raw endpoint evidence](../validation/evidence/underground-ug1075-bindings-2026-10-03/locations/README.md)
records exact source hashes, strict invocation and the rejected fixture run.
This proves actual endpoint identity, bounded local persistence and Inventory
retention/promotion against synthetic geometric fixtures. Actual terrain,
movement, profile qualification and shared cold-budget composition remain work
in this same lane.

## Exact pending Furniture installation source

UG07's room coordinator remains the sole Buildings SpatialAuthority. Its
Furniture purpose owner prepares `stage_furniture_install(token, project,
router, owner)` before Funding commits; ordinary `seal`/`prepared_refusal` then
check exact actual before-facts. The sparse owner derives the Furniture from the
actual completed Construction, validates full Room/type/rotation/generation and
pending status, and anticipates only installed d=0 to d=1 in its existing staged
source bank. Ordinary source registration still reads only current facts.

`publish_furniture_install` requires the same actual Router, purpose owner, full
project and exact synchronous COMMIT bracket, plus actual Buildings installed=1
facts. Generic publication cannot publish this special candidate. Aborting
retains all old geometry and claims. No fallible geometric rebuild occurs after
payment. Publication revalidates identity guards and swaps the prebuilt bank;
the correct immediately preflighted callback has no remaining physical decision.

There are no new packed columns or wire fields. One source-row integer (8), full
project ref (8), and existing-shape IntResult numeric controls (9) add 25 logical
control bytes. Two weak bindings and scratch/native handles are separately
covered by the admitted binding/control reservation. This state is transient,
cleared on abort/publication and excluded from canonical save/hash.

Independent review and the final clean strict run accepted 39 tests / 570
assertions / 0 failures, zero strict/raw diagnostics and leaks, and analyzer
`0 GDScript warning(s) in 0 of 4 file(s)`.
[Raw installation-source evidence](../validation/evidence/underground-ug1075-bindings-2026-10-03/furniture-source/README.md)
pins the actual source and rejected fixture iteration. Physical placement and
contact/profile truth remain the real coordinator/bindings owners' responsibility.

## Shared cold-operation boundary

The actual Sites spatial adapter now requests an exact bound cold reservation
before allocating `ColdCheck`, its snapshot or its plan. Base Bindings refuses.
Production WorldBindings must use the same actual World-owned decision1072 Budget
as Locations and all companion readers. It must reserve the simultaneous peak
before the first copy, extend that same lease before additional companion
allocations, and keep every charged object inside the admitted lifetime.

Proof-only admission and explicit static-proof refresh release after their
survey/plan are discarded. Successful START/COMMIT/CANCEL preparation retains the
token until exact Sites publication or exact discard; refused preparation first
aborts its owner/companions, then drops the caller's original `ColdCheck`, and
only then releases. Productive WORK neither acquires a lease nor constructs a
survey. Foreign discard calls cannot release another prepared transaction.

One transient int token adds **8 logical control bytes**, inside the existing
binding/control reservation. No packed cache, authoritative or wire fields change.
A reservation is a finite logical allocation contract, not measured native memory.
The source review and actual shared-provider composition remain separate gates.

Clean assets-aside import and the unchanged strict runner reported
`24 test(s), 3010 assertion(s), 0 failure(s)`; both strict/raw diagnostic footers
reported zero unexpected errors/warnings and object/resource leaks, with zero
expected/tolerated diagnostics. The analyzer reported
`0 GDScript warning(s) in 0 of 2 file(s)` under `--max 0`. The regression fixture
observes survey/plan destruction with weak references, verifies every acquired
lease releases exactly once, and covers refusal before the first copy. Its
budget/contact provider is explicitly synthetic; actual World binding is still
implementation work. Raw logs and source pins are retained under
`docs/validation/evidence/underground-ug1075-bindings-2026-10-03/cold-operation/`.

## Actual Locations / shared Budget binding

Locations now takes the reviewed decision1072 `Budget` type directly. The
provisional nested component lease is removed; there is one actual shared arena,
not a second token allocator hidden in Locations. The read-only
`is_bound_budget(candidate)` compares the exact configured object. Production
WorldBindings must require it before coordinating nested phase/endpoint work.
There are no new endpoint columns or persistent fields. Budget's four numeric
controls are counted once by decision1072; the obsolete component lease is not
also allocated or charged.

All existing `covers` checks apply to the actual shared lease. A captured image
retains that lease until consumed; restore requires its wire bytes plus the
bounded survey peak to fit the same reservation. Another acquisition refuses
while an image is retained. A nested operation must extend the same lease
before its additional allocation, and release only after all charged objects
are gone. This preserves the exact endpoint lifetime and Inventory retention
checks rather than treating equal capacity numbers as a common arena.

The independent narrow review accepted the replacement. Clean CI import and
strict tests reported Locations **17 tests /396 assertions** and unchanged
Budget **6 tests /58 assertions**, all failures, strict/raw diagnostics and leaks
zero. The analyzer reported `0 GDScript warning(s) in 0 of 2 file(s)`. Raw evidence,
source hashes and the rejected preliminary registry invocation are under
`docs/validation/evidence/underground-ug1075-bindings-2026-10-03/shared-budget/`.
This is logical lifetime evidence; actual terrain/profile/route composition and
native memory qualification remain in progress.

## Proposed actual route-owner arena (not allocated yet)

The next owned module is `underground_routes.gd`, with a separate focused test.
Locations remains the immutable endpoint/containment owner. Routes owns connected
edge identity, retained route state and integer Transform progression; it also
supplies the actual `SpaceOwner.ResidentLocations` reader. A paid cube, matching
X/Z or a successful profile query alone does not create a connection.

The initial technical pack proposes N=1024 actual Locations, E=1536 directed
edges, V=4096 authored polyline vertices, L=4096 pooled route links and the actual
Residents typed capacity S=512. At most 256 residents are living, as before.
These are finite reusable arena capacities, not a room count, floor count or
maximum player route-length policy. Admission refuses before allocating a partial
route. The counts leave room for the measured initial settlement workload and
must be exercised at 256 living residents before claiming workload qualification.

| Store | Exact proposed columns | Retained bytes at this pack |
|---|---|---:|
| Existing Locations banks | Reviewed 228N+256 | 233,728 |
| Two directed-edge banks | Each has14 I32: generation, from slot/generation, to slot/generation, owning Room slot/generation, family, variant, rotation, path start/count, mode, posture; 3 I64: content revision, geometry revision, path length; 2 B8: present, exhausted; plus I32 free heap and deterministic order index. 180E total | 276,480 |
| Two authored polyline banks | X/Y/Z I32 columns; compact occupied prefix with per-edge start/count. 24V total | 98,304 |
| Resident state plus simultaneous load image | 26 I32: full Resident ref, current Location ref, current edge ref, actual Job ref, route head/tail, mode/posture/phase, profile ID/connector family, full tool/cargo/satchel refs, segment index, committed next Location ref, requested goal Location ref. 6 I64: profile/content revisions, committed cargo quantity, edge progress, displacement remainder, request tick. 304S total | 155,648 |
| Pooled route state plus simultaneous load image and both derived heaps | Four I32: full edge ref, next link, owning Resident typed row. Actual Resident identity is validated through that row's full stored ref. Both heaps are preflighted before load publication. 40L total | 163,840 |
| One reused Dijkstra scratch | Per Location: I64 distance, I32 predecessor edge/heap node/heap position, B8 search state. 21N | 21,504 |
| One proposed route result | Full local edge ref per node, 8N | 8,192 |
| Derived local occupancy lookup | I32 hash heads[N], next[S], cell XYZ[3S], query visit[S], complete actual body/held-load envelope[6S], I64 profile revision[S] | 28,672 |
| Bounded numeric/header reservation | Source-defined fixed headers and operation controls, charged before final implementation; native objects/handles remain in the separately declared bindings reserve | 1,024 |
| Combined proposed provider peak | Including existing Locations and simultaneous route/resident load images | **987,392** |

The remaining **61,184 bytes** inside the existing1,048,576-byte provider reserve
are unallocated headroom, not a permission to omit later columns. The final source
will recalculate exact scalar/header counts. Cold survey/profile copies still
borrow the actual shared decision1072 Budget; no third graph bank or per-resident
path object is permitted. Current graph publication and cold loaded images must
not overlap uncharged.

Edges are generation-checked, directed, and split at real Room/domain boundaries;
all five approved connector families refer to their actual source-bound content.
Each segment retains its authored positions, never stretched between arbitrary
floors. The graph is admitted only against complete supported geometry and exact
profile requirements, including turns/recovery and protected landing reservations.
Dijkstra uses positive integer path lengths and deterministic stable ties; it does
not reuse the old flat octile heuristic. Pooled links share the finite global
arena instead of allocating a private maximum path for every resident.

An active resident's full identity, actual Transform and committed profile/load
must agree. The derived occupancy lookup is rebuilt or updated from those actual
owners once per movement boundary, not by a whole-geometry scan on each Work
call. A changed profile or geometry invalidates future entry; interruption must
retain the occupied edge, progress and safe exit. The next implementation packet
must settle deterministic landing queues/retreat, exact pace provenance and
legacy-Movement handoff before movement activation. Ground caps can be read from
Residents; connector pace is an explicit authored input rather than an invented
copy of a ground-only speed. This schema proposal grants no traversal permission.

## Prepared endpoint read for atomic topology companions

`Locations.prepared_location_into` now copies an exact endpoint only after the
existing sealed-token, current geometry and Inventory-retention preflight. Its
caller supplies fixed output scratch; refusal leaves that output unchanged.
The method exposes neither mutable bank storage nor a live endpoint before
publication. This lets the forthcoming topology companion validate a future
endpoint in the same atomic transaction. There are no new stored fields.

Independent source review accepted the narrow change. Clean CI import and strict
tests reported **18 tests /420 assertions /0 failures**, zero strict/raw errors,
warnings, expected/tolerated diagnostics and leaks. The analyzer reported
`0 GDScript warning(s) in 0 of 2 file(s)`. Raw logs and source pins are retained
under the1075 evidence directory's `prepared-endpoint/` child. Actual topology
and World composition remain implementation work.

## Exact future Room source bridge for atomic plan confirmation

Decision 1083 supplies a real Directory `CreateCandidate` observation and guarded
Buildings Room publication. SpaceOwner now exposes
`stage_room_admission(token, candidate, room_type, authority)` and
`publish_room_admission` with the same arguments. The actual `CoreSources`,
Directory, Construction/Buildings and its one bound `Buildings.SpatialAuthority`
must agree. A caller-provided future `Facts` record never qualifies.

Preparation independently observes and pins the next global full reference,
typed Room row and persistent ID. It retains the original packet and authority
weakly; seal and final preflight compare every scalar and recheck the actual
Directory roots/PID and the coordinator's exact retained packet. Changing or
losing the original packet, consuming either allocator, changing purpose, or
using another actual owner refuses. Preparation spends no Directory identity.

The only anticipated source is an actual future underground Room with permanent
type, NULL surface parent and no TileLinks. Its geometry may contain only
FLOOR_DATUM metadata and OBSTACLE markers carrying that exact full Room claim.
The claim must refer to its own Room-owned planned floor; both floor and claim
must exist before sealing. These are planned blockers, not physical UNFINISHED,
support, dry matter or supported void. Fine painted boundaries remain exact:
this bridge adds no 1m drawing or height restriction. The production confirmer's
actual provider separately owes dry terrain/support, access and fully priced
1024-cube coverage before admission. It may not interpret a fine claim as a free
partial excavation.

Ordinary publication refuses a pending Room admission. The special publication
requires the same token, candidate object, type and authority, its exact
synchronous Room-admission window, and actual Buildings/Directory after-facts:
full Room generation, typed row, persistent ID, permanent type and underground
domain. Every other source and claim is still revalidated normally. Furniture
installation and Room admission cannot share the special source slot. Abort
clears only transient controls and preserves all live geometry, claims and
unspent identity. The coordinator must finish all fallible proof before it calls
Buildings; publication follows synchronously without another fallible rebuild.

No packed or canonical wire field changes. One reusable `CreateCandidate`
contains 32 logical numeric bytes (full ref 8; kind/typed row/PID 24); row/type
controls add 16 and two callback guard bools add 2, for **50 logical bytes** inside the previously declared binding
reservation. Three weak handles (the candidate's Directory, original packet and
actual authority) and their native headers are charged to that same reservation.
The candidate cannot coexist with another future Room source, and does not
allocate per resident, per room or per productive Work tick.

All virtual Room authority attestations are guarded. Attempts to abort, rebegin,
edit, restore or publish SpaceOwner inside the callback refuse and invalidate that
attestation. The guard is cleared when the callback returns, so normal caller
cleanup and an exact retry remain possible. The original candidate is pinned
before callbacks; its actual allocator/current scalars are checked afterward,
including after the publication attestation. No sticky busy latch survives a
refusal. These controls do not replace the actual coordinator's required pure
callback contract or its pre-allocation proofs.

Independent source review accepted the final correction. Clean CI import and
strict tests reported **49 tests /812 assertions** for SpaceOwner and
**24 tests /3,010 assertions** for the unchanged paid adapter, with zero failures,
strict/raw errors, warnings, expected/tolerated diagnostics and leaks. The analyzer
reported `0 GDScript warning(s) in 0 of 2 file(s)`. Final raw logs, source pins and
historical rejected fixture/analyzer results are preserved under the1075 evidence
directory's `room-admission/` child. This is actual identity/atomic-marker component
evidence; production terrain, contacts and the actual Room confirmer are separate
composition work.


## Production-capacity validation and exact allocation readers

The actual joint pack exposed a correctness blocker hidden by small component
fixtures: SpaceOwner precharged R*(O+1)+O for sealing and R+O² for loading.
At R=6,144/O=2,048, even an empty arena with one added region exceeded the
unchanged 1,048,576-check RoomSpace work ceiling. The configured capacity was
being treated as populated work. Per-edit source revision propagation and
changed-versus-capacity overlap scans also multiplied empty rows.

Validation now temporarily borrows the two existing staged free-heap arrays.
One holds the compact present-region rows; the other is an in-place heapsorted
index of present source rows by global slot. Source joins use charged binary
search and retain exact generation checks. Overlap validation compares each
changed row with present rows, preserving every contradictory-matter and
foreign-claim check. Source registration/removal lookups charge actual visited
rows. Work units remain logical row/identity/comparison checks, not elapsed time
or a claim about individual VM instructions. The original MAX_CHECKS, configured
capacities, physical geometry rules and saved schema do not change.

Reconstruction of both deterministic free heaps is reserved before borrowing
and runs on every validation success or refusal. Public edits, abort/rebegin and
publication cannot mutate an owner while its heaps contain indexes. A failed
seal can be edited and retried; an exhausted operation can be aborted and begun
afresh. One affected source receives one new revision per transaction. Before
ordinary sealing, all its retained rows receive that revision through the
indexed join. Loading never performs this repair: corrupt or stale saved region
revisions still refuse. Forgetting and re-registering the same actual source
within one transaction cannot reset its live revision through row reuse.

There are no new packed fields or arrays. Two temporary signed integer counts
add **16 logical control bytes** inside the existing binding/control reserve.
They return to -1 before subsequent mutation or publication. Staged heap arrays
remain derived scratch; serialized bytes, source/region generation rules and
allocator choice remain unchanged.

`allocation_within(region_limit, source_limit)` is an allocation-free comparison
against positive, actually configured capacities, so WorldBindings can reserve
its complete cold-copy bound before creating a snapshot. The exact borrowed
multilevel source provider is available as
`CoreSources.resident_locations_owner()`; missing or foreign bindings return
null. Neither reader grants geometry, movement or profile permission.

The exact joint-pack regressions measured 26,632 logical checks for a minimal
seal, 40,966 for its restore, 655,905 for registering and placing all 256 actual
living Residents in one transaction, 112,545 for their full restore and 32,934
for one body edit in that populated image. The fixture uses real generational
Residents and Transforms with explicitly synthetic containment/envelopes; it is
not production profile or traversal qualification. A separate 1,024-static-region
edit exhausts the same original work ceiling and preserves every live byte.
This region workload does not create residents beyond the living cap.

Final clean CI import and strict component tests report SpaceOwner **57 tests /
2,976 assertions** and unchanged paid Authority **24 tests /3,010 assertions**,
with zero failures, strict/raw errors, warnings, expected/tolerated diagnostics
and leaks. Independent read-only source review accepted the exact source/test pins with no
high or medium findings; the analyzer reported zero warnings in both files.
Final evidence is retained under the 1075 evidence directory's `capacity-validation/`
child. Full-scene frame time, native memory and completed route binding remain
separate qualifications.
