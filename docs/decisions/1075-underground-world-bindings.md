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
headers belong in the explicit binding/native reservation. With the packed Quote
and delivery allowances the proposed sum is 4,962,090, leaving 47,533 bytes.
Remaining Router controls must also be counted. Provider reserves are not
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
