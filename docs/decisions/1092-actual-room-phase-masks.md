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
