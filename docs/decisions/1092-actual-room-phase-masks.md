# 1092 — Actual Room section and fine physical phase masks

2026-10-03. Engineering component independently reviewed and focused verification
complete; productive contacts and playable construction remain separate work.

## Decision and actual owner boundary

`underground_room_bindings.gd` is the concrete, once-bound RoomOrders binding for
the two cold phase observations in this increment. It borrows the actual
WorldBindings, actual Sites and the exact World-owned Budget. Actual
WorldBindings/CoreSources/Construction/Buildings/SpaceOwner object identity is
required; numerically equal references in another owner are not sufficient.
The inherited room admission, layout, support/contact, installation and service
gates remain explicitly closed until their concrete engineering packets land.
This module does not expose a success fallback or a caller-supplied permission.

Both calls require the current full Site and Room, its unchanged actual project,
the actual spatial revision and the same live phase token. WorldBindings owns
that scope; a bare caller-acquired token, another Site in the same Room, a new
project or an equally funded replacement token cannot reuse it. The existing
SpaceOwner `site_scope_refusal` additionally proves the actual Sites/Construction
pair and exact immutable economic Domain, including World, datum, minimum and
extents. Scope, current sources and lease are rechecked after collaborators and
before any output becomes usable. An exclusive local guard is set before the
first callback. A reentrant call refuses without clearing the outer output.

`phase_section_into(site, room, cold_token, out)` uses the actual sparse owner's
reviewed exact-claim resolver. Every Room claim intersecting the canonical paid
cube must reference one full, live, Room-owned FLOOR_DATUM section at its actual
level. The floor may be far below an upper cut. Neither cube Y nor the metadata
envelope supplies a guessed floor. Missing, ambiguous, stale or foreign section
links refuse. The caller provides fixed six-I32 Region scratch; refusal leaves
all its existing fields unchanged.

`finish_mask_into(site, room, cold_token, row_limit, out)` returns a flat six-I32
box per exact Room-claim intersection with the actual Sites'1024u cube. Only
stored OBSTACLE/CLAIM_ROOM rows with the exact owner, claim ref, full section and
level contribute. Metadata envelopes, physical cavities, foreign Rooms and
other claim kinds contribute nothing. A complete count precedes exact output
allocation. Pair comparisons require a disjoint result: positive-volume overlap
refuses instead of double-counting, truncating or silently normalizing the
canonical claims. Half-open touching remains legal. Capacity/work/source/lease
refusal clears all mask entries; no partial candidate escapes.

The method returns observation only. Geometry's separate Authority packet must
independently compare both mask and exact unfiltered claim union, validate actual
support/contact/source evidence, and stage the residual before payment. A
site-scoped snapshot intentionally omits reservation markers and cannot replace
that independent mask proof.

## Economic and shape semantics

The player's exact in-world painted footprint retains its authored integer
pitch, concavity, holes and room type. It is not snapped to the paid lattice.
ECON-001 still cuts and yields one immutable1m³ quantum once. ECON-003 finishing
can expose only the exact claimed intersection as usable supported void. The
remaining already-paid cavity must remain explicit nontraversable UNFINISHED.
It cannot become fake untouched soil, free outside floor, or a traversable hole.
This reader never publishes either role and introduces no price, new role,
multiple-Room-per-Site rule or per-quantum duplicate section/history columns.

## Bounded lifetime, work and memory

The same actual World cold lease admits the entire synchronous phase. There is
no parallel arena, cross-frame result or lingering hover allocation. The caller
must consume and clear the mask before its actual owner releases that lease.
The provider owns no release permission; stale cleanup cannot release a newer
caller's reservation.

The provider retains two six-I32 boxes48 bytes plus a reused Region's six-I32
box24 and metadata48, an eight-byte remaining-work counter and one boolean:
**129 logical reused bytes**. Two WeakRefs, the actual Budget reference, the
Region/packed headers and ordinary native object overhead stay within the
existing shared524288-byte bindings/native-growth reservation. This is not a
new129-byte canonical store and is not a measured allocator claim.

Its maximum simultaneous variable payload is **8R+24F+512** cold bytes: full
overlapping handles, one exactly sized flat mask and sequential helper/control
scratch. R≤6144 and F≤R. Bounded Domain/descriptor copies occur before the handle
image; the existing exact site-domain proof may use its own fixed quantum/
Domain/descriptor scratch later under the same control allowance. No per-box
object or array image is retained. Native packed growth, Dictionary and object
headers also need the existing joint native allowance;512 is a logical numeric/
small-packet control charge, not a proof of native allocation size.

For the independent Authority mask stage, the retained composed snapshot425984,
maximum phase plan72936, flat mask24F, reacquired8R handles, two flat residual
banks48R and512 controls peak at **990952 logical bytes** for R=F=6144. The
provider's handle image must drop before the Authority acquires its own; the
compositor's intermediate snapshots/fragments and copied qualification arguments
must already have dropped. This is below the unchanged1048960 cold ceiling.
The two residual banks must be reused sequentially for both directions of exact
union proof and cube-minus-mask publication. Fragment/source limits and all
nested pair work remain explicit refusal conditions, not hidden growth.

Before surveying handles the provider precharges **12(Rmax+Omax)=98304** checks
against the actual configured Domain work ceiling. This conservatively covers
the reviewed resolver's4R+3O allowance, five complete current-source/claim
checks, the handle scan, bounded World-source lookup and fixed scope callbacks.
Every fixed-row read and pair comparison additionally decrements the remaining
allowance. The metadata path uses the same conservative charge. Pathological
fragmentation therefore refuses deterministically without omitting validation;
the work cap is a cold engineering bound, not a measured frame-time guarantee.

All authoritative data stays in existing owners. The129-byte state and weak
wiring are category3 and must be reconstructed after quiescent composed load;
no pointer is serialized and no codec/version changes here. Actual composed
save/load, hardware memory/timing qualification and demo integration remain
separate queued work.

## Verification

Tests compose actual generated World, Directory, catalog, Inventory, Buildings,
Construction, Work/Gear, Sites, sparse SpaceOwner, Terrain, WorldBindings and
shared Budget. Only fixture Room registration and unstarted Site admission are
explicitly synthetic; no paid work or production profile/contact success is
claimed. They exercise fine holed claims, upper cuts, adjacent foreign claims,
physical residual exclusion, full section identity, exact limits, unchanged
authoritative bytes and adversarial lease/domain/identity callbacks.

After deleting the own import cache, the clean Godot4.7.2 editor import reported
no diagnostics with demo assets absent. Five unchanged strict CI selections
report **101 tests,7725 assertions,0 failures**: new RoomBindings16/573,
RoomOrders/confirmation25/1356, WorldBindings37/828, paid FurnitureWork15/4628
and typed LayoutSources8/340. Every strict and raw footer reports zero unexpected
errors/warnings, zero expected/tolerated diagnostics and zero object/resource
leaks. The analyzer reports `0 GDScript warning(s) in 0 of 3 file(s)`.

An initial analyzer warning was a test parameter shadowing an existing method;
the final test-only rename corrected it. A temporary selection helper then
requested a nonexistent separate confirmation suite after the first two final
suites had already passed. Confirmation is covered by RoomOrders; the remaining
three real selections completed after correcting that test path. The error,
initial analyzer evidence, final logs, full shard manifests and exact unchanged
three-file source pins are retained in
`docs/validation/evidence/underground-room-masks-2026-10-03/iteration-1/`.

Independent root review matched those three final pins and found no blocking
issue in the actual binding/Domain, scope-before-allocation, synchronous strong
references, final mask cleanup, exclusive callbacks, full section identity or
disjoint clipping. It accepted the129-byte reused census and conservative scan
charge; it did not rerun engine tests. The Markdown state registry check passes
120 modules,595 rows and963 packed columns. No shared gate was weakened and no
full-suite or production physical permission is claimed by this component.


## Exact phase composer identity prerequisite

The typed base now exposes `phase_world_owner() -> RefCounted`, returning null.
The actual RoomBindings implementation returns its configured weak composer
target, or null after expiry. This is identity metadata only and creates no
lease or permission. Two WorldBindings objects over the same actual World,
Space, source reader and Budget still have different phase scopes; root's
delegation must require the exact object before borrowing a phase observation.
There are no added fields, packed bytes or cold copies.

The focused actual-store regression covers unbound readers, exact identity, a
same-store replacement and expiration without a hidden strong reference. Root
independently reviewed the exact three source pins with no high/medium finding.
Clean strict RoomBindings17/604 plus RoomOrders25/1356 total42 tests,1960
assertions,0 failures; strict/raw unexpected diagnostics and leaks are all zero.
The analyzer reports0 GDScript warnings in0 of3 actual files. Corrected local
selection/analyzer path mistakes are disclosed in the retained evidence at
`docs/validation/evidence/underground-room-masks-2026-10-03/phase-world-identity/`.


## Physical identity prerequisites for actual support and worker binding

`Sites.jobs_owner()` borrows the exact successfully initialized Job store, or
null after refused initialization. This is owner identity metadata; a consumer
still proves current World, full Job, requester, worker and contact separately.
`Sites.installed_support(site)` reads the actual paid installed byte through the
full live Site, immutable World generation and bound spatial Room proof. It
rechecks the exact authority, World, Room and installed byte after that callback.
It does not infer a brace from BRACING, CUTTING or CLOSING. A canceled closure
retains support; either successfully settled physical closure removes it.

These are stateless readers: no packed columns, persistent controls, scratch
buffers, save fields or byte ledger change. Root owns the actual worker binding;
geometry owns the separate retained natural-footing/roof provider. Neither may
turn this paid-brace fact into invented natural support or free installation.

Five new actual physical lifecycle/identity regressions and refused-initializer
assertions cover unsettled/settled brace, cutting/finishing/closing, canceled and
paid closure, stale Site/Room, expired authority, callback-time World retirement,
World slot reuse, actual Job object identity and unchanged authoritative bytes.
Final clean strict physical suite:48 tests,23880 assertions,0 failures; strict
and raw unexpected diagnostics and leaks all zero. Analyzer:0 warnings in0 of2
files. The initial test-constructor error and complete final evidence are retained
at `docs/validation/evidence/underground-room-masks-2026-10-03/physical-identity-readers/`.
Independent root review matched both frozen source pins and accepted the exact
paid-state/identity checks and tests with no high/medium finding.


## Actual Room admission: lease handshake and geometric preflight

This increment implements the existing `begin_room_cold` path for one exact
player RoomPlan. It is an actual geometric preflight, not completed admission.
The same concrete RoomBindings remains the one RoomOrders authority; no second
Room registry, purpose owner, geometry store, budget or economic ledger appears.
The once-bound actual LevelCatalog supplies section heights and local footing/
protected-above intervals. Its actual Directory and complete Domain must match;
a numerically equal World from another Directory cannot substitute.

The provider obtains the actual World cold lease before copying a plan, Domain,
Footprint map or snapshot. The original request object, exact coordinator,
World/Space revision, Building/Construction/Sites identities and actual Budget
remain conjunctive. Strong synchronous borrows keep the World composer, Room
coordinator, LevelCatalog and Sites alive through final cleanup. The Sites borrow
matches its configured weak target and the actual Construction owner. Actual
scope is rechecked after callbacks, including callbacks that release the outer
Router/Sites composition. Nested requests refuse before another allocation.

RoomOrders no longer treats a successful provider return as memory permission
by itself. It pins the actual Budget before acquisition and requires the exact
positive `room_cold_token`, actual `Budget.covers` and
`room_cold_refusal(original_plan, token)` before copying. It rechecks that exact
scope after every preparatory callback, before further geometry copies and
before Directory publication. Refused cleanup drops owned plan/identity and
companion scratch before ending the lease; it never releases a newly reacquired
foreign token. The successful confirmation fixtures use the real Budget while
remaining explicitly synthetic for physical admission permission.

The current actual provider checks these facts before naming the remaining
entry dependency:

- The requested level, floor Y and clear height match an exact authored
  LevelCatalog record, including an authored section offset. This is the current
  pack's qualified subset; shorter ceilings or additional packs require their
  own authored contracts, not inferred numeric permissions.
- Canonical cardinal connectivity, holes and pinch rules remain the existing
  Footprint contract. Fine pitch, concavity and holes are preserved unchanged.
- Each exact painted X run is surveyed against original real Terrain and an
  unfiltered composed snapshot. The separate whole touched1024u physical cut
  span must be dry and unoccupied; an obstacle just outside a fine outline but
  inside its economic cube still blocks the cut. The fine confirmed Room shape
  is never replaced with that expanded survey span.
- Every intersecting actual claim, wall, pending item or other non-dry physical
  role remains visible. Actual retained Sites history refuses with
  `ROOM_RETAINED_CUT_MAPPING_UNBOUND`; a new request cannot mint virgin yield
  over an old physical quantum. Reuse needs the later real cut-map companion.
- Required footing and protected-above bands are checked only over the exact
  painted runs, including their actual XYZ depths. A bounding envelope or a
  depth label never fills a hole or grants support. Fresh source/revision and
  scope checks finish the observation.

A clear plan currently returns `PROSPECTIVE_ENTRY_CONTACT_UNBOUND`. It creates no
Room, Construction project, Site, support, route, material claim or usable void.
Actual prospective entry/first-work feasibility, qualified profiles, connector
installation, structural publication, paid cut-map companion and final staged
admission are required follow-ups. Later assigned-worker/tool/load checks remain
separate from prospective admission, which has no actual Job yet. There is no
caller success flag or fake entrance/corridor in this increment. The demo cannot
activate this unfinished path as completed construction.

### Cold peak and required packed-validator follow-up

The entire synchronous operation reserves the existing1048960-byte World arena.
With N painted cells, the conservative admission request is
`max(975488 + 16N + 2048, 2192N + 2048)`: the reviewed World compositor peak plus
both possible8N plan images, or128N conservative Footprint packed buffers,
16N plan images and2048N native Dictionary/growth allowance. The latter reserves
512 bytes for each of at most4N outgoing entries, including growth/header
allowance.2048 fixed bytes additionally cover the sequential Domain/descriptor,
helper frames, temporary RoomPlan metadata and borrowed native references. The
reservation is engineering accounting, not measured allocator/RAM evidence.
The existing region/source and per-run/cube comparisons spend explicit bounded
cold work; no per-worker or per-frame full survey is added.

This deliberately conservative intermediate accepts at most477 cells in one
preflight and refuses478 **before copying**.477 is not a gameplay room-size
policy, a new paint limit or permission to truncate the approved footprint.
**Production activation is blocked until the existing16384-cell footprint
operation contract and simultaneous Room/compositor lifetime are reconciled.**
The queued validation-only follow-up replaces Dictionary connectivity/loop
scratch with bounded packed adjacency/queue/flags while preserving all current
validation errors and contour behavior. Actual compositor capacity or sequential
plan lifetimes must also be proved; simply replacing477 with another hidden
limit is not sufficient.

The retained/reused logical delta is105 bytes: one LevelCatalog.Record89, one
provider I64 token8 and one RoomOrders I64 token8. The provider's private
RoomPlan is cold-only60-byte numeric metadata plus8N cells; its lifetime is
inside the above2048/16N reservation. Two extra weak links and strong synchronous
request/Budget/owner references have native headers/control costs inside the
existing shared bindings/growth reservation. Existing129-byte mask scratch is
reused. There are no authoritative columns, saved ordinals, per-Site maps or
separate arenas; UG16 reconstructs this category3 wiring only at quiescence.

### Admission verification

Tests use actual generated World, LevelCatalog, Terrain, SpaceOwner, Buildings,
Construction, Directory, Inventory, Work/Gear, Sites, Router and Budget. Only
initial obstacle Room/Furniture registration and unstarted historical-Site
qualification are explicitly synthetic fixture setup. The target confirmation
always uses actual RoomBindings and never receives productive permission.

The final clean seven-suite baseline passes127 tests,8416 assertions,0 failures.
The final two-source lifetime correction reruns actual admission at15 tests,
504 assertions,0 failures; combining that changed suite with the six unchanged
baseline suites gives128 tests,8444 assertions. These are component checks,
not a claim that the whole game suite was rerun. Every final strict and raw
footer has zero unexpected errors/warnings and zero object/resource leaks;
expected/tolerated diagnostics are zero. Analyzer evidence covers all five
files in the baseline and the two changed files in the final correction.

Retained evidence includes rejected test-only setup iterations: a wrong
Buildings state-image method, a foreign World fixture that did not yet alias
both ref fields, and one wrong test preload alias. The actual cold-handshake
regression also tightened the coordinator's immediate post-callback check so a
replaced lease reports its scope failure before another candidate callback.
No gate was weakened. Full raw logs, manifests, exact pins and review notes live
under `docs/validation/evidence/underground-room-masks-2026-10-03/admission/`.

Independent root review accepted the final five source pins, including the
strong Sites borrow and callback-time outer-owner release regression. It found
no critical/high/medium issue within this static preflight and exact lease
handshake scope. Final correction analyzer reports0 warnings in0 of2 files;
no runtime/source change followed that evidence. Playable admission, the
packed-validator replacement and large-plan coexistence remain explicitly open.

## Admission follow-up: packed validation and one retained image

Decision 1094 now provides exact packed validation while preserving the existing
16,384-cell operation ceiling and all shape/refusal semantics. This follow-up
removes the temporary 477-cell admission bound; it introduces no replacement
room size, drawing pitch, material or level policy.

Virgin-room admission already requires actual `Terrain.dig_refusal` for every
whole paid-cut run and every exact painted footing/protected-above band. Those
checks prove original dryness and current water/resource/Building exclusions.
Admission also rejects every overlapping retained physical role except original
`DRY_SOLID` and metadata `FLOOR_DATUM`, and separately rejects all retained Sites
history. It therefore needs one complete, unfiltered actual SpaceOwner snapshot,
not the additional original-natural/subtracted/composed output image used by
physical phase validation. Physical phases keep their existing compositor.
Every claim, wall, pending item, support, void, unfinished cavity and foreign
reservation remains visible; no site-specific or traversal exemption is used.

The actual source image and its full World/revision are checked around the
operation. Exact owner composition, original input, source liveness, exclusive
entry and the actual World Budget token remain mandatory. A source or token
change cannot publish a Room or retain an accepted result. Existing actual
retained-history refusal and `PROSPECTIVE_ENTRY_CONTACT_UNBOUND` remain explicit:
this is static admission evidence, not a free corridor, installed entrance,
excavation permission or playable construction claim.

### Simultaneous memory and work

Let N be the unchanged admitted footprint count, R the configured joint region
ceiling of 6144, and O the source ceiling of 2048. One actual snapshot requires
at most `48R + 16O = 327680` logical packed bytes. Charge 24N for the incoming
plan and both possible protected plan copies, even though the current static
preflight retains fewer simultaneously. With the existing 2048-byte helper,
Domain/descriptor and scalar allowance, the complete cold envelope is:

```text
max(327680, Footprint.validation_scratch_bytes(N)) + 24N + 2048
```

At N=16384 this is 722944 bytes, below the unchanged shared World arena of
1048960 bytes. No original-shape image is silently omitted, no second arena is
created and no input is truncated. The actual full arena is still acquired
before the first copy and held synchronously through cleanup. Native packed
headers, strong/weak references and allocation growth remain in the existing
joint bindings/native reservation; this formula is not measured native RAM.
There are no new persistent or reused member columns. Window bounds reuse the
existing six-I32 Region box; scalar helper frames fit the declared allowance.

Packed footprint validation and its surrounding linear cell/run passes are
conservatively precharged at 32N operations, in addition to the unchanged owner
scan allowance. Canonical checks, linear adjacent-row joins, once-enqueued BFS,
pinch/Euler checks and run discovery have bounded linear loop examinations.
Retained-row comparisons and immutable Sites lookups spend their actual nested
work. Terrain checks split each original requested box into clipped, tile-aligned
windows of at most 8×8 actual tiles, within Terrain's existing 64-tile read cap.
Each window charges `16 * actual_tile_count + 1` before the real terrain call.
Both window endpoints are pinned before callbacks and the exact arena token is
checked before and after every call. This changes query granularity only; full
cut volume and exact fine painted bands stay unchanged, including holes.

### Verification scope

The focused tests use the same actual owners as the earlier admission packet.
The fixture Domain now permits the already-approved full Footprint ceiling.
New cases cover a complete 16384-cell rectangle, a 130m run spanning 66 terrain
tiles, a 508-cell outline around an occupied hole, both horizontal window axes,
a real river reached only after the first dry window, and a replaced actual
Budget token immediately after one genuine terrain query. Existing depth,
pending Furniture, claim, wall, original request mutation, reentry, World
identity, authored height and retained paid-history refusals remain covered.

Final clean strict checks pass actual admission 21 tests / 689 assertions,
RoomOrders 28 / 1457 and RoomBindings masks 17 / 604: 66 tests, 2750 assertions
and zero failures. Each suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The final analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`. Independent
root review accepts the exact source/test pins with no high or medium finding
in the complete retained snapshot, actual Terrain windows, lifetime checks or
memory calculation. Logs, full shard manifests, exact hashes and commands are
retained under `docs/validation/evidence/underground-room-masks-2026-10-03/admission-scale/`.
No full game suite or native allocation qualification is claimed by these
component checks. Actual first-work contact, qualified profile, entry/connector
and prepared support companions remain required before confirmation can succeed.
