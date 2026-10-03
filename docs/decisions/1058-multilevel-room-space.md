# 1058 — Bounded multilevel space and fixed connector transforms
Date: 2026-10-02 · Status: Accepted engineering foundation; production qualification open

## Decision

UG08 increment A introduces two cold, stateless integer helpers:
`room_space.gd` validates actual three-dimensional space and exact physical cut
quanta; `room_connectors.gd` transforms complete, fixed authored pieces. Neither
owns terrain, reservations, paid history, inventory, work, services or routes.
Success returns a copied revision-bound candidate, never construction permission.

Players draw directly on the dirt at the selected underground level. The
blueprint is an in-world outline, not a separate drawing canvas. These helpers
retain absolute position, actual floor height, nominal level and conflicting
object identity for that preview. Terrain picking and ghost rendering belong
to the UG09 world bridge; this increment does not implement or qualify them.

## Contract and reasons

- `Domain.configure()` registers one immutable world EntityRef, `datum_u`,
  minimum quantum coordinate and finite size, with caller-selected cold-operation
  capacities. All cuts are absolute origins of exact 1024u cubes relative to that
  datum. Signed coordinates and far corners are checked with int64 intermediates
  before int32 storage. No project may reset the datum or silently round a finer
  cut into free/extra excavation. This follows ECON-001, not a restriction on
  room drawing tools or surface meshes.
- `Snapshot` is the spatial owner's complete versioned survey for the domain.
  Packed half-open boxes retain actual X/Y/Z extent, level, whole owner
  EntityRef and revision. The live-owner table rejects stale generations and
  revisions. Dry solid, finished supported void, support, furniture/other
  obstacles, protected approaches, openable shells, water, resources, occupants,
  unfinished work and actual floor datums are distinct roles. Unknown coverage
  refuses. Floor metadata grants no excavated space.
- `Plan` contains required clearance/landing/support/solid/opening boxes,
  canonical cut origins and their work-contact indices. Exact box-union
  subtraction detects interior gaps that corner sampling or bounding boxes
  miss. Proposed occupied space must be completely covered by existing
  supported void or the actual requested whole cuts. Each cut must currently
  be dry solid and wholly removed by the proposal. Previously finished void
  may be reused without another cut or spoil entitlement.
- Overlap uses actual height across every surveyed level, not equal level IDs
  or endpoint-only checks. Intended openings target exact shell owners;
  they never authorize overlapping furniture, neighboring walls or supports.
  Supports and central posts cannot overlap their own required clearances.
  Refusals expose the conflicting full reference, revision, level and row.
- Work contacts include a real body approach, reach extent, point on the cut
  face and measured profile identity/revision. Approach space must already be
  finished. A typed `Authority.qualification_error()` must additionally bind
  actual dry/support rules, profile sweeps, legal connected work access and
  relevant task policy. The base authority refuses. Synthetic test subclasses
  are explicitly named and are not runtime qualification. These boxes cannot
  prove turning, grip, carrying capacity or support by themselves.
- `room_connectors.gd` recognizes all five approved families: earth/timber
  steps, stone stairs, ramps, spiral stairs and timber ladder/hatch. A
  `Definition` supplies a stable catalog key/revision, fixed local extents,
  endpoint heights, level offsets, allowed quarter turns, supports, openings,
  landings, work contacts and exact cuts. Placement rotates full boxes, work
  points and cube minima; canonical sorting retains the cut/contact pairing.
  It never stretches a rise or moves a floor to repair a mismatch. Two heights
  on one nominal level remain distinct, supporting later split-level sections.
  The tests exercise family dispatch with synthetic geometry, not five
  production-ready connector assets or traversal implementations.

All records are packed integer columns. Limits are caller configured and
validated: at most 16384 cut cubes, 16384 total input regions/cuts and 1048576
coverage/intersection checks per operation. Region count includes world rows,
proposed rows and both contact-volume tables; live owner rows are separately
bounded by the same region ceiling. Box fragmentation is also bounded. These
are refusal ceilings, not a frame-time or 256-resident performance claim.
A volume row has 48 logical bytes; each cut has 16; a contact adds 24 beyond
its two volume rows; each live owner adds 16 (two int32 reference fields and
one int64 revision). Input copies, coverage fragments
and dictionaries are transient and bounded, but native overhead is unmeasured.
This API is for cold placement/phase validation, not per-resident tick loops.

## UG06 and UG09 composition

UG08 increment A depends only on the established geometry/authority contracts;
it need not wait for UG06's physical site ledger. The eventual UG09 adapter
binds `excavation_contract.gd`'s world/datum/bounds and absolute cube origins to
this `Domain`, and constructs fresh snapshots for admission, phase start and
immediate commit preflight. The site ledger retains paid/support/earth history
across project replacement. It is not reconstructed from these candidates.

Validation of current work contacts is deliberately operation-specific: a
large future room cannot claim every still-inaccessible face as presently
reachable. The sequencer must validate the next reachable operation against
then-current completed geometry. Planned destination-floor metadata can
describe a new landing, but it grants neither completed void nor a route.

The authority adapter is a trusted read-only owner boundary, not an arbitrary
UI callback. Its input copies cannot rewrite the checked candidate. It must
not perform material/world mutations while qualifying; success still requires
the integrating coordinator to revalidate current revisions and reserve all
affected space atomically. Actual Job/worker identity, delivered material and
adjacent output-container proofs remain UG06 owner checks. Publication must
compose the site ledger, real Inventory transaction, geometry, room validity,
services and topology; a finished cube alone never grants a public route.

The two modules own no persistent simulation columns. Registry category 3
records their caller-owned inputs/scratch. Once bound, the domain and accepted
geometry, content revisions, reservations and floor/endpoint identities must
be serialized by their real owners. No new save schema or identity namespace
is invented here. UG08 remains incomplete until production authoring, owner
integration, measured traversal, save/load and performance evidence land.

## Next production authoring packet — proposals, not adopted constants

The following packet makes the missing work concrete. Existing candidate 4m
level spacing is not adopted by these helpers. No demo tread/ramp or speed
constant is promoted into production.

| Owner input to author | Required values and evidence | Candidate variants and reason — PROPOSALS |
| --- | --- | --- |
| Map/level geometry | Immutable datum; finite min/size; main floor heights; supported raised/sunken offsets; actual floor/ceiling and structural thickness; terrain-to-selected-level pick mapping | Main floors plus separately authored short-rise pieces. Match offsets to the piece catalog so height selection never creates an unconnectable floor. |
| Earth/timber steps | Fixed width/run/rise, tread/riser count and dimensions, rails/posts, clearances, both landings, support and opening extents, rotations | Straight and quarter-turn pieces, plus short straight steps for split levels. They provide compact burrow access with explicit bend landings. |
| Stone stairs | The same measured geometry, with masonry structural and finish extents, applicable material recipes | Straight, L-shaped and returning flights. Returning flights can trade length for width without stretching or narrowing the selected variant. |
| Ramp/passage | Fixed slope/run/rise, clear width/headroom, bend sweep and turning landings, traction/load eligibility from the movement owner | Straight and landing-separated turning variants. Hauling suitability must be demonstrated with actual carried loads rather than inferred from the word ramp. |
| Spiral stairs | Inner/outer radii represented by conservative integer solids/clearance, central post, handedness, full tread and headroom sweep, entry/exit angles, landing approaches | Clockwise and counterclockwise versions with fixed rise. A compact footprint is useful only when the measured body and load can negotiate every turn. |
| Timber ladder/hatch | Rung spacing, shaft dimensions, grip/step-off envelopes, frame thickness, hatch sweep, landing approaches, reach/capability/load restrictions | Wall-adjacent ladder with side or forward step-off, each with its own fixed hatch orientation. Hatch motion and hands/load policy must be tested explicitly. |
| Profile catalog | Stable IDs/revisions; measured species/age/body/gear/posture/load envelopes; start/end transitions; swept turn/hatch/grip geometry; rounding/error/animation margins; qualified speeds | Qualify unloaded travel and task-specific load cases separately. Do not introduce species/age exclusions or free climbing permissions from missing measurements. |
| Structural/work owner | Dry terrain/water classifications; support spans and load limits; adjacent resource/occupancy protections; legal reachable worker face and body envelope; last-exit protection | Validate a conservative authored support region and actual approach per operation. A generic boolean support or proximity check is insufficient. |
| Economy/content owner | Exact fixture/door/stair/hatch recipes and labor; catalog identity/version; actual cut set including openings and retained solids; phase dependencies | Use existing adopted quantum economics for real cuts; separately author missing connector fixtures. Missing recipes must refuse, never install for free. |

For each authored variant, provide full local packed geometry, render mesh
alignment and texture scale, then measure clearance in all permitted rotations
and actual endpoint heights. Include pending furniture/room work and an
obstacle between otherwise clear endpoints. The qualification packet must
cover construction access, interruptions, carried loads, safe retreat,
save/load and full HUD captures at 1280×720. Curved visual surfaces must stay
inside these physical boundaries; neither smoothing nor picking can create
extra usable volume. This record does not claim that visual qualification.

## Validation

With no demo assets present, removed this worktree's `godot/.godot`, then ran
`godot --headless --path godot --editor --quit`. The actual strict runner's
singleton shards (`171/303` and `186/303` at this source state) reported:

```text
27 test(s), 249 assertion(s), 0 failure(s)
16 test(s), 179 assertion(s), 0 failure(s)
```

Both suites independently reported:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`tools/gdscript_warnings.py --port 6149 --max 0` over all four new GDScript
files reported `0 GDScript warning(s) in 0 of 4 file(s)`.
Registry coverage passed with 97 modules, 450 rows and 771 packed columns.
This is focused evidence, not a full-suite claim or measured production
clearance/performance qualification. The test dimensions and accepting
authorities are synthetic.

## Follow-on implementation packet — surveyed after increment A

This is the bounded next packet, not a declaration that the following stores
or profiles already exist. File leases, schema adoption and independent review
must precede implementing each part. The parent is separately building UG19's
selected-level world input; that presentation work does not own world rules.

### Existing real inputs and their limits

| Input available now | Exact authority/source | Safe use and limit |
| --- | --- | --- |
| Adult anatomical heights: mouse 1024u, mole 922u, squirrel 1178u, otter 1526u, badger 2611u | `setting_decisions.md` DEC-039; `planning/asset_dimensions_and_budgets.md` GAP-01/02 | Normalize and compare the actual bare adult anatomy. These are not width, posture, work reach, step height or equipment clearance. Beaver 1434u remains explicitly proposed under DEC-041. Child and elder dimensions cannot be obtained by silently scaling the adult. |
| Real local walk clips for those five species | `art-reference/asset_library/grounded.json`; `assets/library/creature/<cast key>/grounded/anim_walk.glb` in the main checkout | Read-only existence and SHA256 checks on 2026-10-02 matched all five rows for `mouse_keeper`, `mole_digger`, `squirrel_gatherer`, `otter_boatwright`, `badger_quarryman`. These are provisional assets with traceable source, not accepted complete body/gear sweeps. The binaries are absent from this isolated worktree; reference/read them without modifying the other checkout. |
| Idle/walk/carry and some crouch/dig clips; raw bed, pick, arch and door sources | `tools/stage_demo_assets.py` CAST/CLIPS/OPTIONAL_CLIPS; library README and repair/ground/bake manifests | Measurable inputs, with known grounding/tail/loop limitations. The staged mouse crouch has an additional repin, so measure the actual bound version and preserve its derivation/hash. Do not label raw generated source as the runtime asset. No paid generation is necessary to start. |
| Integer 2m furniture floor footprints | `building_definitions.gd:137`, `floor_x_of()`/`floor_z_of()`; GDD §5.9, balance §4.3 | Bed, patient bed, seat, shelf and decoration: 1×1 tiles = 2048×2048u. Hearth and kitchen bench: 2×1 = 4096×2048u. Partition/door: edge placement, not a zero-volume object. Heights, usable approach, door swing and work reach remain separately authored/measured. UG18 owns the catalog mapping. |
| Existing room identity and countable validity | `buildings.gd` `is_live_room`, `type_of_room`, `room_tile_at`, `room_building_ref_of`, `furniture_rows_in_room`, and full furniture readers; GDD §5.9 | Preserve full Room/Furniture EntityRefs, immutable purpose and countable requirements. Tile rows contain no generalized underground height or body-fit proof. Do not reinterpret their flat tile index as a new underground location. |
| Surface model briefs | `planning/asset_dimensions_and_budgets.md` GAP-03 | 3072u minimum clear internal height and 1536×3072u ordinary doorway are authored surface-model briefs. They are useful comparison fixtures, not an underground rule or proof all residents and cargo fit. The cellar's 2048u maximum aboveground height does not specify its depth. |
| Inherited movement/load ceilings | `residents.gd:193`–`:194`; MOVE-C3-R01 §4 | Small/medium/large: 3277/4096/3072u per second and 12000/16000/24000g. Connected profiles must bind their own applicable speeds and any tighter loads; changing mode cannot enlarge the satchel or add a guessed ladder capability. |
| Measurement schema and exact conversion | `planning/movement_envelope_schema.json` schema 2; `tools/validate_movement_envelopes.py`; MOVE-C2/C3 | Reuse source hashes, actual gear/cargo variant, outward integer micrometre conversion, seven legal states, full continuous sweep and explicit residual error/margins. Ground class derivation is anchored; it is not a general 3D connector-fit algorithm. |

The existing diagnostic
`validation/evidence/ground-access-planning-2026-09-20/mouse-rigid-yaw-diagnostic.json`
already measures a **439u static rigid-yaw radius**, excluding animated body,
gear and cargo. It fails containment at the baseline (+256,+256) ground root
offset. Its alternative (+768,+768) is explicitly diagnostic. Re-centering all
actors would change position/anchor/save semantics and is not an incidental
way to pass underground clearance tests. `movement.gd:565` correctly continues
to refuse unspecified clearance; the packet must preserve that guard until
real owner-qualified profiles replace it.

### B1 — Source-bound measurements that can start immediately

Lease a new offline measurement tool, its Python tests and a repository-owned
evidence directory. Read existing manifests and local source assets without
staging or editing the main checkout. For each selected asset/clip, bind source
SHA256, anatomical normalization transform, axes/root, attachments, clip name,
legal pose states and exact output version. Begin with the five checked adult
walk sources plus matching idle/crouch/carry/dig inputs where present.

Produce independently inspectable source measurements and missing-state
reports. Include all skinning influences, tail/gear/load extents and the
continuous interpolation between poses; sampled frame minima/maxima alone
must not assert zero residual. Use conservative bounds with a documented
residual proof, then exact outward integer conversion. Do not fill absent
entry/hold/turn/reversal/retreat/exit mappings with assumed capabilities, use a
height-ratio width, or tag partial diagnostics as production-ready schema-2
profiles. Unit tests mutate source hash, omit an attachment/state, shrink an
extremum inward, and understate error/margin; each must refuse qualification.

This work needs measurement/engineering, not another approval of DEC-039 or
a paid asset request. A profile that cannot yet qualify still supplies useful
actual geometric evidence for the next authored connector iteration.

### B2 — Actual spatial owner and phase preflight

First record a complete typed schema and byte ledger for a **sparse**, bounded
underground geometry owner: immutable world domain/datum; actual floor-section
identity and height; packed physical-region rows with owner generation and
revision; finished versus unfinished extent; supporting solids; protected
approaches/openings; and confirmed-project reservations. Include allocators,
scratch, load peak, revision exhaustion and save/hash ownership. Do not copy a
proposed capacity or allocate a dense world by multiplying the surface grid
by an invented floor count. All required bounds are explicit configuration
until the production parameter pack is adopted.

Then implement a complete snapshot producer and revisioned staged changes
behind the existing RoomSpace API. Bind actual Buildings/Furniture and phase
project identities; use UG18's supported catalog dimensions and B1's measured
profiles when qualified. Existing underground demo room slots have no
generation namespace and cannot be substituted for those core references.
The original surface `SpatialWorld.Location`/`Contact` remains ground-only;
any expanded location/connection namespace and migration needs its own adopted
schema instead of fabricated ground cells.

Map truth must explicitly provide dry solid, water/resource extents and
support. A surface terrain tile or a visible cap is not a subsurface survey.
Missing geometry must refuse. Connect UG06 `SpatialAuthority` admission/start/
commit preflight using exact absolute cubes; bind actual Jobs, workers,
material contacts and reserved local output containers. Stage prospective
geometry/service/topology changes, revalidate revisions immediately before the
real Inventory commit, and publish through the non-failing owner seam. Preserve
the site's paid ledger across room removal/replacement. No duplicate terrain,
inventory or service authority may be maintained by the preview widget.

Required tests use the **actual stores** for a next reachable cut, stale/reused
room and furniture refs, worker on another floor, newly blocked landing,
missing support/water survey, output-capacity refusal, retained unfinished
void, only-exit closure and save/reload between every physical phase. Synthetic
subclasses alone cannot close this increment.

### B3 — Fixed production families and qualification

Use the five-family candidate list above to author versioned concrete pieces,
starting with reusable straight/turn/landing primitives but preserving each
family's full solid/clearance/support/sweep distinctions. Fit measured bodies
and supported loads to the **actual** start/end floors and openings; keep
selected-level terrain picking and ghost transforms on this same datum.
Publish a connector only when its real profile, geometry, support, recipe,
phase dependencies and movement cost rows all exist. A family enum or shared
synthetic box is not a completed catalog. Spirals and ladders stay in this lane
until their turns, grip, hatch sweep and safe step-off are qualified.

The packet's physical tests cover every piece/rotation, upward and downward
planning, two heights within one room, intermediate-floor conflicts, pending
work and carried loads. Add source/mesh boundary comparison and 1280×720
in-world preview captures. Finally qualify deterministic live movement,
interruption/retreat, save/load and 256-resident resource/time budgets before
closing the corresponding MOVE gates. UG06/UG09 integration tests must show
that paid completion, usable geometry and services become visible together.

### Which choices need player input, and which do not

No new user answer is necessary to begin B1, schema/ledger design or the fixed
piece authoring tools. Finite bounds, representation, authored level spacing,
offset catalogs, variant dimensions and tested contact/support envelopes are
engineering outputs explicitly left open by D03–07; record their evidence and
present concrete tradeoffs if needed rather than asking the player to guess
body widths or safe support spans. Missing measurements are engineering work,
not evidence a species cannot use a route.

Seek a targeted product decision only if the implementation proposes a change
to the approved experience: excluding an approved family/construction method,
adding species/age bans, reducing ordinary access to particular room types,
making formerly ordinary access deliberately hazardous, or choosing visual
anatomy/scale not already approved. New player-visible material/labor recipes,
connected-mode speeds and load rules need explicit owning numerical authoring
and review; neither existing economic constants nor a successful fit test
supplies them. Unresolved adult/elder **unprotected** climbing permissions must
not be silently replaced with a blanket ladder permission. Protected ordinary
infrastructure policy is already adopted; its real safety/grip qualification
still has to be built. These boundaries do not reopen the user's five-family,
free-shape, multilevel or in-world drawing approvals.

## Source

- `AGENTS.md`, `CLAUDE.md`, `docs/systems_architecture.md` and decision 0006.
- `docs/movement_direction_amendment.md`; `docs/underground_economy_hazard_amendment.md` ECON-001/003.
- `docs/design/underground-planning/README.md` D03–07 and D11–14;
  `levels-and-connections.md`, including the unresolved numerical authoring.
- `docs/rulings/2026-09-14_cycle02_movement_envelopes.md` and
  `2026-09-14_cycle03_movement_policy.md`.
- User clarification on 2026-10-02: draw directly on selected-level dirt with
  an in-world blueprint overlay, not a separate drawing canvas.
