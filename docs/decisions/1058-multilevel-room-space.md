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
its two volume rows; each live owner adds 12. Input copies, coverage fragments
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

## Source

- `AGENTS.md`, `CLAUDE.md`, `docs/systems_architecture.md` and decision 0006.
- `docs/movement_direction_amendment.md`; `docs/underground_economy_hazard_amendment.md` ECON-001/003.
- `docs/design/underground-planning/README.md` D03–07 and D11–14;
  `levels-and-connections.md`, including the unresolved numerical authoring.
- `docs/rulings/2026-09-14_cycle02_movement_envelopes.md` and
  `2026-09-14_cycle03_movement_policy.md`.
- User clarification on 2026-10-02: draw directly on selected-level dirt with
  an in-world blueprint overlay, not a separate drawing canvas.
