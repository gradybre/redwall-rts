# 1064 — Sparse underground spatial ownership and phase publication
Date: 2026-10-02 · Status: Accepted implementation contract; composed validation open

## Scope and authority

UG21 implements the actual sparse geometry owner required by decision 1058 B2.
`underground_space_owner.gd` owns physical regions, floor-section identity and
confirmed spatial reservations. This first increment implements that store;
the following `underground_space_authority.gd` increment must bind its
revisioned survey to the real identity and excavation owners. Neither may copy
Sites' permanent paid-cut ledger, derive underground space from a surface tile,
or permit a preview widget to declare supported space.

The user-approved experience remains in-world painting on the selected dirt
level, permanent room purposes, actual digging before fitting out, multiple
levels and complete connector/landing clearance. This engineering record adds
no room sizes, floor spacing, material prices, body dimensions or capabilities.

## Packed owner schema

The following implementation contract passed independent review before
substantial source changes. Field names and byte arithmetic must match the final
source before this record becomes implementation evidence.

An immutable `RoomSpace.Domain` supplies the full world EntityRef, economic datum,
finite quantum bounds and cold-operation limits. Storage capacities `R` (region
rows) and `O` (bound source owners) are explicit configuration; neither has a
production default. Both are bounded by the existing RoomSpace operation ceiling.
There is no dense grid multiplied by a guessed number of underground levels.

| Arena | Packed columns | Logical bytes |
|---|---|---:|
| Region lifecycle | present, retired, role, claim kind: four B8; generation: one I32 | `8*R` |
| Actual region extent | lo/hi X/Y/Z and nominal level: seven I32 | `28*R` |
| Floor section link | section slot/generation: two I32 | `8*R` |
| Full external source identity | owner slot/generation: two I32; geometry revision: one I64 | `16*R` |
| Typed confirmed claim | claim slot/generation: two I32 | `8*R` |
| Source binding lifecycle/identity | present and source kind: two B8; slot/generation: two I32; revision: one I64 | `18*O` |
| Exact source facts | parent slot/generation plus four typed source facts: six I32 | `24*O` |
| Owner header | schema, capacities, full world ref, datum, quantum minimum/size, operation ceilings and world revision: eighteen I64 | `144` |
| Derived lowest-free heaps | one I32 per region and per owner row | `4*R + 4*O` |

The persisted packed payload is therefore `68*R + 42*O + 144`. Including the two
derived heaps gives `72*R + 46*O + 144`. A second equally sized, preallocated
staging bank permits non-failing publication without allocating another game
world. The two banks occupy `144*R + 92*O + 288` logical packed bytes. A B8
changed-row mask and I32 index list add `5*R` reusable scratch, making the actual
owner arena `149*R + 92*O + 288`. This scratch does not alter the persisted schema.
Ten scalar integer counters/capacities/tokens (80 logical bytes), a boolean seal
flag, refusal StringName, one Facts record (48 integer/vector bytes) and the
cached Domain (92 integer/vector/packed bytes) are separate from that arena.
The referenced source stores already belong to the composed world; they are not
duplicated here. Object, Variant, array, StringName, reference and engine allocator
headers remain native overhead. These formulas are not process-memory measurements.

No per-entity RefCounted object is allocated. An internal region handle has its
own explicitly named `(row,generation)` namespace; it is never presented as a
global EntityRef. A floor section is a live FLOOR_DATUM region handle, linked to
its actual owning room and absolute floor extent. The section's low Y is the
floor height. Metadata alone grants no void or route. Region links preserve the
exact section generation; deleting/reusing a floor row cannot transfer its
furniture or landing claims to another floor.

External Room/Furniture/Construction/World/Resident references remain in their actual
owner namespaces. Their live generation and exact relevant source facts are
rechecked against the real stores, rather than accepting a slot-shaped number.
Inventory container identities retain Inventory's distinct namespace. A source
fact guard is an exact copied value, not a collision-prone hash used as proof.

| Source kind | Exact parent and four I32 facts |
|---|---|
| World | Null parent; all four facts zero |
| Building | Null parent; BuildingDefinition ID, actual origin tile, rotation, interior ID |
| Room | Actual parent Building; immutable purpose, actual tile-link offset and count, zero |
| Furniture | Actual containing Room; FurnitureDefinition ID, origin tile, rotation, zero |
| Construction | Actual purpose-specific subject ref; purpose, type ID, zero, zero |
| Resident | Actual containing Room or actual surface/no-room null; world X, Y, Z and spatial mode |

`CoreSources` reads the existing real Buildings and Construction APIs. Their
flat tile facts guard identity; they do not authorize underground placement.
The current `Buildings.designate_room()` cannot register arbitrary stacked rooms;
UG07 must extend the actual room owner instead of inventing Room/Building refs.
The optional typed `ResidentLocations` reader must obtain real XYZ/mode and
containment from actual movement/transform/room owners. Its base refuses, and
CoreSources never fills a guessed Y, posture or containing Room from a ground
tile. Resident profile, gear and carried-load revisions remain separate mandatory
qualification. A synthetic mode/containment reader in the tests is labelled as
such, even though its Resident and Transform identities are real.

Floor links validate both generation and actual containing Room for furniture
and residents. An OCCUPANT extent must contain that Resident's actual XYZ anchor.
These checks do not substitute for a measured complete body/gear envelope or
prove that a live worker has a route to its work contact.

Every arena initializes unused fields canonically. Allocation selects the
lowest free index using derived, bounded heaps. A first generation is one;
reuse increments it, and an exhausted int32 generation retires the row. World
and source revisions never wrap. Capacity/revision failure happens before any
Inventory, work, geometry or reservation mutation. Heaps rebuild from persisted
presence/generation/retirement in ascending order after load.

## Prepare, publish and abort

Only one synchronous owner transaction may be prepared at a time. Preparation
copies into the already allocated staging bank, validates all edits and source
identities, reserves every required row, checks section/reference relationships,
and records the exact expected world/source revisions. Only changed rows need
pair checks against the full retained set: an unchanged pair was already proven
in the live image. The finite mask deduplicates edits; a decoded load compares
presence, retirement, generation, owner, section, roles, exact bounds and claims
against the current image, including removals. Identity/section validation still
checks every present row. Pair overlap uses scalar integer comparisons, with no
per-pair box allocation. Reads continue to see
the unchanged live bank. Other geometry mutators refuse while the transaction
is prepared.

Publication swaps the fully prepared packed banks and their derived indexes.
It performs no allocation, owner callback, geometry search or fallible catalog
lookup after the physical Inventory/WIP transaction commits. The caller must
perform immediate revision preflight and publish synchronously without a yield.
Confirmed reservations appear in public RoomSpace surveys only as OBSTACLE
markers, never as dry matter or supported void. The claim-kind byte is NONE=0, CONSTRUCTION=1 or ROOM=2; unknown values refuse,
including on load. Permanent accepted footprints belong to actual Rooms, while
phase work claims belong to actual Construction generations. A Room claim must
name the same actual Room as its source owner. No synthetic master project is
created merely to keep the footprint reserved.

The ordinary `snapshot_into()` returns every claim. The only selective reader,
`snapshot_for_site_into()`, proves the exact actual Sites/Construction binding,
live physical key, immutable world/domain and full Sites-to-Room/current-phase
relationship before omitting those exact claim-kind/reference pairs. Actual
furniture, occupants, exits, matter and foreign claims are never filtered.
Overlapping Room/Construction claims are allowed only when that real physical
ledger proves that the phase belongs to the same Room; distinct phase claims
still conflict. Room claims survive retirement of individual paid phases.
Final preflight rechecks every retained claim independently of source geometry.
Aborting discards only the transient prepared image. It preserves prior physical
geometry, confirmed Room/phase reservations, output/contact leases and paid history.
A failed physical attempt prepares and revalidates afresh before retrying.

UG06's typed contract distinguishes proof-only ADMIT/WORK from prospective
START/COMMIT/CANCEL publication. It supplies `discard_transition()` for failed
attempts. The candidate binds exact quantum origin, operation, stage, room
generation and geometry revision. A completed cube cannot itself publish public
navigation or countable room services: the actual supporting owners must be
included in the same proven publication boundary.

## Phase-specific validation preserves actual truth

`RoomSpace.validate()` is the prospective fresh-cut/placement validator. It
knows existing supported void and exact new dry-solid cuts. It deliberately
does not treat retained UNFINISHED void as supported.

FINISH therefore uses a separate operation-specific preflight against actual
Sites state and the unmodified spatial survey. It proves the worker's complete
supported approach, actual reachable work target, support and obstruction rules
without adding a second cut or relabelling unfinished space prematurely. CUT
creates retained unfinished geometry; only successful actual FINISH may publish
supported completion. Backfill/remove-support preflight protects occupants,
furniture, pending work and remaining exits across actual heights.

Missing dry/support/water coverage, missing measured profiles, unqualified
movement contacts and incomplete service/topology ownership refuse. Source
measurements from B1 are not automatically production-qualified movement or
reach profiles. No inherited ground-only Location/Contact is fabricated into
an underground route. Cold stored Resident regions are revision-bound evidence,
not a new per-tick Resident movement store. STAGE_WORK must reuse static geometry
proofs while the real dynamic occupancy/profile/contact owner checks changes;
it may not call snapshot construction, whole-owner seal or all-region validation
for every productive worker tick.

## Persistence and total memory remain composition obligations

All future-affecting live columns above are category 1. The staged bank and
in-flight token are scratch, never saveable mid-transaction; save accepts only
a completed boundary. Heaps and cached lookup/domain data are category 2.
No state is reclassified to evade the canonical registry. The shared canonical
owner/version/table and full save coordinator are separate leased work; this
lane supplies its exact field/schema and round-trip obligations for them.

A complete RoomSpace snapshot contributes `48*n + 16*o` packed bytes for its
actual region and live-owner rows. Its validator may hold the caller snapshot,
an isolated checked copy and a qualification copy simultaneously. The final
ledger must count those copies, plan/contact inputs and bounded union scratch,
alongside the two owner banks. There is no third authoritative undo bank: abort
retains live data, and publication ends the transaction. Load reuses the staged
bank only at a completed boundary, validates the entire incoming image and its
source relationships, then publishes atomically. Local wire order is the eighteen signed I64 header
values, the nineteen Region columns in their declaration order, then the eleven
Source columns. Integer encoding is explicitly signed little-endian. Wrong size,
schema/domain, unused bytes, duplicate source slots, lifecycle values, stale
sources/claims/sections and contradictory matter refuse without changing live
bytes. Local restore does not itself activate a shared game-save schema. The
composed load boundary must discard all previously derived geometry/profile
proofs before resuming; a loaded saved revision is not permission to reuse a
pre-load cache. It may not allocate a second
WorldStore or conceal a whole-world load peak behind this local ledger.

The current composed baseline already declares 81,057,920 bytes including its
unchanged reserve. UG06 and other underground allocations consume the same
remaining arithmetic headroom. An arena ceiling is not an adopted production
parameter pack or permission to exceed 100,000,000 bytes. RoomLayout, profiles,
all owner copies and transient lifetimes still need the root's shared accounting
and runtime qualification.

The latest root accounting for Sites/Funding maxima and the decision 1068 Gear
index increment leaves only 5,206,314 logical bytes before this owner, profiles,
RoomLayout and load/validation peaks.
A proposed finite composition admission must price the owner's `149*R + 92*O
+ 288`, its scalar/domain scratch, up to three `48*n + 16*o` snapshot images,
plans/contacts, the explicit local wire buffer `68*R + 42*O + 144` when present,
and the real simultaneously retained profile/layout owners. It must refuse an
over-budget parameter pack before allocations/copies. Independent maximum
R/O values are not a production default or additive allocation permission.
The owner currently accepts explicit finite capacities; actual global composition
admission remains the shared coordinator's open requirement.

## Economic lattice and rounded finish boundary

The initial engineering mapping for real excavation is an explicit 1024u
horizontal drawing lattice and vertical bounds on the same immutable economic
datum. Rectangle, rounded brush, ellipse and tunnel/path tools can produce
arbitrary connected stepped unions of whole paid cubes. This is an initial
binding candidate, not completion of UG-SHAPE-002 or a claim of final visual
quality. The 256u component/world-overlay study is preview-only.

A final smooth inner contour can fit inside fully paid whole-cube excavation,
with every changed cube charged exactly once. It still needs actual authored
finish geometry, material recipe/work ownership, matching walls/floors/ceilings
and occupancy. Cosmetic smoothing must not widen walkable space, conceal a
remaining solid obstruction or silently price a partial cut. Finer-volume
physical geometry requires its separately priced/catalogued ECON-001 change.
The user's approved curved-room direction remains adopted while this concrete
finish implementation is outstanding.

## Component evidence (not composed release qualification)

After the Room/Construction claim split, a clean import with demo assets aside
reported zero error/warning lines. The strict singleton owner shard reported:

```text
28 test(s), 377 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer over the owner and its test file with `--max 0 --port 6152`
reported `0 GDScript warning(s) in 0 of 2 file(s)`.
Independent source review accepted the sparse owner after adding the missing
retirement scan-budget debit and an actual removed-floor load regression. A
second narrow review accepted the Room/Construction claim split, exact Sites
binding and all four claim regressions. That source review is separate from
the execution evidence above.
The first added lifetime fixture correctly refused cancellation without its
actual Job binding; the fixture now binds a real matching BUILD Job before
cancellation. No production gate was weakened. The test authority only supplies
synthetic space admission and never claims qualified geometry or routes.

Development-machine cold probes, Godot 4.7.2, synthetic finite regions and actual
World/Buildings identity, 16 allocated source rows:

| Region capacity/populated rows | Owner packed arena bytes | Bulk prepare + seal + publish | Snapshot | One-row remove/re-add + publish | Local save + restore |
|---:|---:|---:|---:|---:|---:|
| 64 | 11,296 | 1.013 ms | 0.067 ms | 0.161 ms | 0.299 ms |
| 256 | 39,904 | 10.716 ms | 0.208 ms | 0.593 ms | 1.056 ms |
| 512 | 78,048 | 39.517 ms | 0.428 ms | 1.146 ms | 2.032 ms |

Before changed-row/scalar overlap checks the 512-region full build took 123.912
ms. The revised bulk operation still exceeds a frame budget. These are small
component probes on the development Mac, not qualification-floor measurements,
not a 256-worker throughput result and not an adopted allocation pack. Whole
room confirmation/large-map edits must be scheduled accordingly; productive
WORK cannot perform these operations. Native peak allocation measurement and
actual composed contacts/occupancy/profile performance remain open.

## Required evidence before completion

Use actual core identities/stores for stale or reused room/furniture refs,
cross-floor worker/obstacle checks, a newly blocked landing, missing map/support
truth, confirmed reservation conflicts, prepare/abort/retry and revision changes.
Prove atomic publication with real Sites/Inventory/Work for a reachable next cut,
retained unfinished state and output refusal. Round-trip every live column,
including free/retired generations and claims, and test each physical phase.
Measure allocations/cold validation at explicit capacities without presenting
them as adopted gameplay limits. UG21 remains running until the composed
acceptance and independent review are complete.

## Source

AGENTS.md; systems_architecture.md ARCH-ID-002, ARCH-MEM-001/006/010 and
ARCH-SAVE-001/003/004; decision 1058 B2; SET-MOVE-001 and SET-MOVE-ECON-001;
the recorded UG21 file lease at integration `82084569`; the user's approved
underground plan and D29 world-drawing clarification.
