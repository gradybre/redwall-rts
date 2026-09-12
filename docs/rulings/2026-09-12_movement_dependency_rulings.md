# Astra follow-up — macro detours and five movement dependencies

2026-09-12 · PATH-R02 and MOVE-DEP-R01–05. Engineering definitions, not a
MOVE-G01–05 completion claim. Complements decisions0053/0066/0083 and
[the prior movement boundary](2026-09-11_movement_gate_followthrough.md).

## PATH-R02 — replace compulsory macro-anchor composition

Adopt exact-start A* on every exact-start cache miss for the flat ground graph.
Keep the16×16 macro bucket key `(start_macro,goal_cell,clearance_class,map_revision)`;
use its existing `variant_start` field to qualify the exact start. This supersedes
ARCH-PATH-003's mandatory local start→anchor→goal construction for new requests.

1. Validate start/goal/clearance/revision under existing admission rules. Exact
   start==goal has its existing zero-travel result; no simulated journey is added.
2. Search the bounded cache for the exact variant. Reuse only a matching actual
   start, goal, clearance and revision; never reuse another start's route merely
   because it belongs to the same macro. Existing reference/generation checks apply.
3. If actual start equals the canonical anchor, an ordinary anchor descriptor
   (`variant_start=-1`) is also an exact-start route and may be reused or built.
4. On every other miss run unconstrained exact-start→exact-goal A* and publish
   the full route with `variant_start=start_cell`. Stop admitting new requests
   through SEARCHING_LOCAL or constructing prefix-plus-bucket routes.

Preserve N,E,S,W,NE,SE,SW,NW order,10/14 costs, octile heuristic, corner rules,
(f,cell_id) heap and equal-g predecessor rules for this flat graph. All finalized
expansions share the existing2048/tick quota; do not add a "small query" budget.
Retain256 descriptors and the1048576-cell arena, ref-safe eviction, waiting/refusal
and complete-route-only publication. Existing descriptor fields already support
exact variants, so this decision adds no route-store capacity or new arena.

There is no new distance threshold. A geometrically nearest point on a cached
route is not necessarily the cheapest join; even a minimum entry+suffix splice
is optimal only among paths joining that cached route. Neither is chosen.

The measured clear-macro fixture `(100,100)→(104,102)` must cost48 (two diagonal
steps at14 plus two orthogonal steps at10), replacing the old160 anchor detour. Preserve
its old160 result as historical evidence; replace the obsolete acceptance with
exact optimum and Dijkstra comparison. Test multiple starts in one macro,
disconnected components, exact and anchor cache hits, start==goal, quota pause/
resume, stale revisions, arena/descriptor exhaustion and deterministic save replay.

Cross-start cache reuse decreases. Remeasure readiness distributions and report
latency regressions openly; do not change2048 or claim ARCH-PATH-007/008 passed.
New algorithm semantics enter the rules identity. Retire old anchor-composition
state via an explicit navigation owner/section9 version change when implementing;
no silent load-time cache flush or reinterpretation of active/pending routes.
Pure memory-array shape compatibility does not establish continuation parity.

## MOVE-DEP-R01 — asset envelopes are a real predecessor

Asset owner supplies reviewed body/posture/gear/cargo envelopes; movement owner
validates/quantizes them and binds legal profiles. The asset deliverable includes
local origin, orientation, body-plus-gear horizontal width/depth, vertical extent,
swept bounds over required poses, stowed/carried attachment variants and source
mesh/rig/clip revisions. Comparison-authoring may begin now; enabled production
clearance awaits measured, approved-proportion geometry.

Keep head/ear-inclusive height candidates separate from passage/collision and
animated bounds. No formula from height, size class or battle radius supplies
horizontal clearance. No guessed margin is hidden in import. Derive and publish
the ground clearance class against the existing ANCHORED passable-square predicate,
with a body placement fixture that proves the envelope occupies that square;
a centered radius is a different contract. Ground `_clearance[cell] >= class`
remains exact. Connection width/height and turns additionally validate swept
posture/equipment bounds; a simple pair of width/height comparisons alone does
not prove a bend or diagonal passage is legal. These are G01 profile inputs and
G04 asset evidence, not one interchangeable gate.

## MOVE-DEP-R02 — fixed authoritative life stage

Task08 resident/community owner adds `Resident.life_stage:B8[512]`, new512 bytes.
Stable `LifeStage` encoding: ADULT0, CHILD1, ELDER2; COUNT3 is a bound, never a
stored stage. It preserves movement.gd's current adult0. Compile the immutable
domain through the catalog owner; do not hand-renumber SpeciesDefinition.
Unused rows use0 and remain distinguished by occupancy/generation. Live and dead
occupied resident rows retain their assigned stage until retirement. Generation-
checked readers reject stale refs; free-slot reuse explicitly initializes stage.

Stage is assigned at creation and fixed for release1 under DEC-032: no birth,
aging timer, adulthood transition or age-based death is introduced. Generic spawn
requires an explicit validated stage; the twelve starters pass ADULT. Restore and
transfer preserve it. Movement admission reads the resident's actual stage and
matches the profile; an `Admission.life_stage` caller value cannot override it.
Add `_profile_life_stage:B8[4]` (new4 bytes) to the starter catalog, allADULT.
Profile revisions continue to qualify matching entries. Catalog/profile metadata
is immutable binding, not another mutable life-stage authority.

Persist/hash the resident column in section4 and increment its owner/section
schema from the published pre-field baseline; update rules/catalog identities,
registry and ledger with the exact +512 resident and +4 starter-catalog bytes.
Do not add those bytes twice if another owner lands them first. Refuse old schemas
unless an explicit migration has reliable stage provenance; do not infer an
arbitrary loaded resident is adult just because old code lacked the column.

This enables identity and validation plumbing, not dependent-resident simulation.
Production child/elder creation/admission remains gated on PC-04's explicit needs,
care, schedule, work/hazard and profile rules. Isolated stage/storage fixtures may
exercise all three values, but ordinary runtime must not silently run non-adults
through adult coefficients. Child hazardous work remains forbidden; active elder
roles remain required. Task08 owns those full rules. Test stage mismatch, stale
references, slot reuse, invalid bytes, explicit starter stage, save/transfer and
refusal of unprofiled stages. No stage change during an active route is introduced.

## MOVE-DEP-R03 — logical rig identity, owned by G04 asset/catalog

Adopt the following exact SpeciesDefinition.rig_id keys for the existing16 species.
They are logical base/adult rig identities, NOT generated skeletons or an assertion
that any asset/clip/palette exists. Compile a RigDefinition key domain in ASCII
order when wiring it; bind each SpeciesDefinition through its actual species key.
No per-resident mutable rig column is needed. Count immutable lookup/artifact bytes
inside existing catalog budgets and update catalog identity explicitly.

| SpeciesDefinition key | rig_id |
| --- | --- |
| badger | rig_badger_v1 |
| ferret | rig_ferret_v1 |
| fox | rig_fox_v1 |
| hare | rig_hare_v1 |
| hedgehog | rig_hedgehog_v1 |
| kestrel | rig_kestrel_v1 |
| mole | rig_mole_v1 |
| mouse | rig_mouse_v1 |
| otter | rig_otter_v1 |
| rat | rig_rat_v1 |
| shrew | rig_shrew_v1 |
| sparrow | rig_sparrow_v1 |
| squirrel | rig_squirrel_v1 |
| weasel | rig_weasel_v1 |
| wildcat | rig_wildcat_v1 |
| wolverine | rig_wolverine_v1 |

Each key resolves through the asset manifest to a hierarchy, bone order, bind
transforms, socket and clip metadata and actual source/export digests. An unresolved
binding refuses asset export or activation of that crowd-render representation
rather than aliasing another
species' rig. Missing art MUST NOT refuse otherwise legal resident spawn or
authoritative movement: simulation legality comes from approved movement profiles,
not render availability. Report a presentation asset gap separately.
Separate palettes remain the default unless compatibility is
verified; equal bone names alone do not establish compatible bindings.
Sparrow/kestrel stay grounded under current settlement rules and still have their
own anatomical rigs. No flight mechanic or Giant resident is introduced.

Child/elder render variants require explicit `(species,life_stage)` bindings;
a stage override may share a verified compatible base rig but cannot silently
inherit adult proportions or movement eligibility. New incompatible hierarchies/
bind layouts get new versioned rig keys. Clip/bone/texture budgets and scale review
remain binding. This resolves missing identifiers; it does not close G04.

## MOVE-DEP-R04 — profile costs depend on the graph proof

The first nonlocal/domain connection invalidates the flat octile proof, not
necessarily every individual heuristic value. For the expanded graph initially
use deterministic Dijkstra (`h=0`) with the adopted finite edge costs, global2048
expansion quota and explicit graph node/edge tie order. Do not enable expanded
routing before G01 supplies geometry, positive traversal costs and finite maxima,
and G02 binds node/edge identity, capacities and a complete cost-order schema.

Any optimized heuristic must prove a lower bound in THAT graph and match an
independent Dijkstra reference on cheap shortcuts, transitions, disconnected
regions, stale revisions and equal-cost choices. No Euclidean/octile fallback
across domains just because endpoints have X/Z coordinates. Readiness and memory
still require expanded fixtures; flat512×512 capacity is not the expanded world.

## MOVE-DEP-R05 — actual contact producers belong to task06

Buildings/rooms/furniture/logistics/service owners publish generation-safe contact
identity, work location, approach location, positive destination_revision, service
availability and relevant footprint/access requirements. Movement consumes those
values; it does not synthesize a destination or validate a fictitious workbench.
Use bounded owner/service instances and their declared contacts, not an unbounded
global pool or a new one-contact-per-building gameplay restriction. Distinct hall
services and beds can have distinct contacts under their actual owners.

The complete contact identity is `(owner_slot,owner_generation,contact_key)`;
destination_revision qualifies that identity, not a different contact. Adopt a
stable compiled `ContactDefinition` key for each definition-local semantic contact
(e.g. definition-qualified work versus doorway contact); ASCII order assigns its
i32 ID. The asset/service owner authors the ACTUAL finite key/offset/access slice
for each enabled definition. All compiled contact slices, count/offset metadata
and keys must fit within the existing1MiB catalog arena alongside other catalogs;
fail import on missing/duplicate keys or aggregate overflow. No implicit contact0
for an undefined service. Require every key to belong to that owner's definition.

Add contact_key to the caller-owned Contact record and capture it with the
DESTINATION owner's ref in travel state. The current `_cursor_owner_id` is the
travelling RESIDENT's identity and cannot substitute for destination identity.
Concrete new columns: `_cursor_destination_slot`, `_cursor_destination_generation`,
`_cursor_contact_key`, each I32[512], +6144 bytes. Null/unbound values are(-1,0,-1).
The existing `_cursor_destination_revision` remains the revision authority captured
at admission. Persist/hash these additions, update section4/owner schema, registry
and memory once, and compare the complete tuple plus revision on revalidation.
Contact record memory is caller-owned/reused and must be counted separately from
these packed columns; do not allocate one object per resident. Save/load may not
accept a different contact merely because it shares the same revision or cell.


Immutable definitions supply exact local work/approach positions and access
requirements; transform with the owning integer placement/rotation conventions.
The contact owner must author these offsets/envelopes before that service enables
travel. The current two-Location Contact binder is usable but not a producer.
A positive caller-supplied revision does not prove a service exists or is usable.

Publish a new revision whenever demolition, footprint/door/access change,
service availability, endpoint replacement or required approach validity changes
admission. Capture and revalidate identity plus revision atomically. Notify travel
in the same committed owner change before the next dependent travel/work read;
no polling gap or remote-work fallback. For an existing positive I32 revision, an edit requiring advancement at
INT32_MAX refuses atomically rather than wrapping. Owner retirement invalidates
its generation-checked identity normally; a replacement owner has a new identity,
not permission to reuse a live contact revision under the same ref. Budget any
new producer/revision/offset storage before implementation; reuse an existing
revision only if it covers every invalidation cause. Test rotate/demolish/rebuild,
slot reuse, service closure, stale approach and interruption while travelling.

## Execution boundary

PATH-R02, the fixed-stage identity plumbing and logical rig manifest can proceed
as bounded independent increments. Horizontal clearance needs asset measurements;
actual service travel needs contact producers; expanded modes still need the
complete G01/G02 contracts. No missing care, excavation, diving-air or construction
quantity is filled by an arbitrary default here. Full05.1b remains open.
