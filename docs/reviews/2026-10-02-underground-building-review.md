# Underground building review — 2026-10-02

Status: source and retained-image review, followed by collaborative planning.
Reviewed `origin/master` at `d9941bd9fc4ebdca12ab5b34d86c943439d93ad1` in
the isolated `codex/underground-plan-2026-10-02` worktree. No gameplay files
were changed. No Godot tests, fresh game captures, or performance probes were
run for this review. Another developer's unmerged work is outside this baseline.

## Conclusion

The demo has substantial reusable underground work: connected passages,
two levels, staged digging, worker activity, round home shells, cellar vaults,
separate furniture installation, and inhabited rooms. It already refuses to
furnish an undug room. It does **not** yet provide an editable, confirmed room
blueprint or player-positioned furniture. It is also explicitly a demo rather
than the production excavation, logistics and save implementation.

The best direction is to preserve the connected-world behavior and useful
presentation work while separating **physical excavated space**, **room use**,
**architectural treatment**, and **furniture projects**. That separation is a
recommendation for discussion, not an approved architecture decision. Simply
enlarging the existing room templates would be unsafe and insufficient.

The user's requested sequence is already settled by the request:

1. Select the intended room/tunnel type and lay out its blueprint.
2. Explicitly confirm the layout.
3. Workers excavate the planned space.
4. Completion leaves an empty room.
5. The player orders compatible furnishings; residents construct and use them.

Rounded tunnels, burrows and rooms, strong visual quality, and decisions taken
in small steps are also requested. Exact shaping controls, room catalog,
shell finish, dimensions, costs and implementation milestones remain open.

## Evidence and authority

Read AGENTS.md, CLAUDE.md and ENVIRONMENT.md; compared the demo with the GDD,
UI/UX controls, movement amendment, underground economy/hazard amendment,
systems architecture, existing underground design and its implementation
decisions. The principal decision records are 0206–0212, 0371, 0612, 0801
and 0884. The earlier design's descriptions of what was missing before its
implementation are historical, not automatically current defects.

The current demo's explicit deviations are distinguished below from bugs.
Severity expresses the consequence for the requested expanded system:
**high** means a core workflow or authoritative-state dependency; **medium**
means a significant usability, visual or integration concern. Static extension
hazards are not claimed to have failed with today's supported templates.

The visual review used the approved grounded/expressive target, supplied
references IMG-03, IMG-04 and IMG-08, and retained underground screenshots.
Five screenshots are copied unchanged into
[the evidence directory](evidence/underground-2026-10-02/), with hashes and
original paths in [provenance.json](evidence/underground-2026-10-02/provenance.json).
Their capture revisions are unverified. They show historical appearance,
not a fresh run of the reviewed commit.

Rebellion's own [Evil Genius 2 lair-building developer blog](https://store.steampowered.com/news/posts/?appids=700600&enddate=1610031706&feed=steam_community_announcements)
describes confirmed blueprints, visible worker excavation, furniture carried
from a depot, and room-specific furniture eligibility. It also permits planning
room and furniture together. The user's requirement to finish an empty room
before furnishing is therefore an intentional adaptation. Its useful reference
is the legible planning/construction loop, rather than its industrial aesthetic
or a requirement to copy rectangular geometry.

## Existing capabilities worth retaining

| Area | Present capability | Limit |
| --- | --- | --- |
| Network | Packed graph, generation checks, stable integer routing, completed-only travel, junction splitting | Routes and fixed room pieces, not a canonical physical cut ledger |
| Depth | Two levels with ramps/stairs and level-aware picking | Two levels and 4 m spacing are demo choices |
| Digging | Pausable work, sequential pieces, crews, staged voids, fresh/drying earth, tool strikes, baskets, spoil and lights | Physical inputs/output capacity do not govern digging as production requires |
| Rooms | Round home and vaulted root cellar, doors, sockets and traversal | Two fixed templates; eight-room cap |
| Furnishing | Undug-room refusal, per-kind palette, planned/installed states, workers, retained progress, suggested layout | Automatic preset positions and immediate material debit |
| Inhabitation | Beds, nighttime routing, comfort, cellar storage and hauling providers | No generic underground kitchen/infirmary/service binding |
| Rendering | Cutaway, active levels, swept passages, curved home walls, practical props, warm lighting | Historical dark rims and coarse excavation shapes need a fresh visual pass |

## Findings

### UG-01 — High: the editable blueprint and explicit confirmation stage is missing

**Evidence:** `godot/demo/burrow/room_tool.gd:239` calls placement on left
press; `:384` creates the room/passage and starts its worker.
`godot/demo/tunnel/tunnel_control.gd:603` confirms a tunnel when dragging ends.

**Why it matters:** moving a ghost and clicking commits immediately. The
player cannot compose the requested room outline, inspect its access and cost,
then deliberately release the whole plan to workers.

**Suggested direction:** one draft editor for room and passage work, with
undo, cancel and explicit Confirm excavation. Draft edits must have no
inventory/job effects. Confirmation must revalidate current geometry, access,
capacity and dependencies. Display the concrete reason when part of a plan
cannot be confirmed. Keyboard and pointer paths must perform the same command.

### UG-02 — High: shape, purpose and layout are coupled to fixed templates

**Evidence:** `godot/demo/burrow/underground_rooms.gd:53`, `:74`, `:108`
and `:202` define home/cellar geometry and fixed tables;
`godot/demo/burrow/room_plan.gd:34` has no editable contour or dimensions.
`godot/demo/burrow/room_view.gd:626` draws only the two template outlines.

**Why it matters:** the current system cannot express a hand-shaped room,
expansion, merged spaces, or a kitchen within a dug shell. Scaling a visual
mesh would leave cost, walk space and furniture positions inconsistent.

**Suggested direction:** choose the player's shaping method first, then
specify a canonical footprint/cut mapping. Consider separating room use from
earth/timber/stone treatment. Keep visible boundaries, legal furniture space,
paid excavation and navigation consistent. Rounded presentation must not
advertise usable space that the authoritative footprint denies.

### UG-03 — High: the current storage stride cannot safely accept arbitrary room sizes

**Evidence:** `godot/demo/tunnel/underground_graph.gd:127` reserves 66
timeline entries per segment; `:279` allocates that fixed stride; `:1311`
writes entries using `timeline_count()` without a per-room bound. The current
room templates use 24 quanta (`underground_rooms.gd:244`). Other demo limits
include eight rooms, 96 nodes/segments, 24 mouths and degree-four junctions
(`underground_rooms.gd:67`; `tunnel_rules.gd:568`).

**Why it matters:** larger/custom rooms cannot be enabled merely by changing
dimensions. An excessive timeline count would overwrite the next segment's
slice or exceed the array. This is a future-extension hazard, not an observed
failure of the existing 24-quantum templates.

**Suggested direction:** define finite geometry/project capacities and checked
allocation before accepting freeform input. Test exact capacity, one beyond
capacity, fragmented storage and repeated edits. Do not adopt demo caps or
level spacing as production limits without the owning specification.

### UG-04 — High: furnishing order is separate, but furniture placement is not free

**Evidence:** `room_fixtures.gd:331` refuses an undug room; `:298` chooses
the first eligible fixed place; `:379` supplies a suggested layout.
`tunnel_panel.gd:237` presents kind-based plus/minus controls.
Decision `0210-fit-out-and-living.md:23` explicitly replaces the earlier
proposed placement grid with safe preset sockets. `install_task.gd:55`
routes through the room middle and then approaches a fixed stand-off point.

**Why it matters:** the user chooses what to install but cannot arrange it.
The preset solution deliberately avoids obstructed paths; removing that
constraint requires real interior clearance and access validation.

**Suggested direction:** retain the completion gate and suggested layout as
a convenience, then add direct placement/rotation, legal footprints, usable
approach positions and a visibly protected walking route. Shared decor and
specialized room equipment need explicit catalog rules. Moving, removing or
redesignating occupied furnishings must retain residents, goods and claims.

### UG-05 — High: excavation accounting is segment-local, not persistent physical space

**Evidence:** `tunnel_rules.gd:230` prices segment length/cross-section;
`underground_graph.gd:1308` builds a segment-local timeline and `:1398`
computes its output. `tunnel_ground.gd:6` describes substrate/wetness rather
than mutable solid/void state. The adopted underground amendment
(`docs/underground_economy_hazard_amendment.md:31`) requires shared physical
1 m³ cut identities for all excavation tools, with no duplicate yield/charge.

**Why it matters:** overlap, enlargement, joining tools and cancellation
must refer to what has physically been cut, independently of room or project
IDs. Redrawing a plan must not create a new paid/yielding copy of old earth.

**Suggested direction:** establish the authoritative cut ledger and atomic
publication of progress/output/topology before custom rooms become production
gameplay. The adopted lattice does not require dense voxels or a particular
rendering algorithm. Keep smooth visual contours and discrete paid quantities
as an explicit mapping, not an implicit mesh approximation.

### UG-06 — High: work, support and spoil still use deliberate demo shortcuts

**Evidence:** `underground_graph.gd:1476` advances work without mandatory
tool/material/output preflight; `:1511` posts spoil directly to a mouth heap.
`spoil_haul.gd:6` says hauling leaves dig timing unchanged; `:103` takes the
pending pile, and `:139` dumps it when no hauler exists. `tunnel_ground.gd:17`
varies work/yield by soil and produces stone from rock; `tunnel_hazards.gd:13`
permits later bracing and unbraced closure. These are documented demo choices.

**Why it matters:** impressive worker animation is not yet a physical
construction economy. Under the adopted production rules, support precedes
cutting, tools must be valid, spoil requires local reachable finite capacity,
and blocked completion must not grant repeated work, experience or output.
Soil multipliers, rock yield and random collapse cannot silently migrate from
the demo into the production contract.

**Suggested direction:** reuse production construction's delivery, WIP and
commit-pending primitives (`godot/scripts/core/construction.gd:21`, `:54`),
with a separate physical excavation owner as that file requires at `:63`.
Close the tool-binding prerequisite explicitly: `core/work.gd:142` currently
allows a tool-required productive tick without a binding. Keep supported dry
excavation and transport safe under the adopted rules. Treat the existing
transport-only/outlet distinction in decision 0884 as binding; visible dampness
does not automatically authorize a new water simulation.

### UG-07 — High: generic room services and construction economics are not connected

**Evidence:** burrow fixtures debit their whole cost at order time
(`room_fixtures.gd:366`) and refund the full amount even after installation
(`:298`, `:444`). Installers do not fetch/carry their materials
(`install_task.gd:77`). An open room is traversable, while individual fixtures
supply functions; there is no generic operational room state. Kitchens use
authored exterior places (`demo/kitchen/kitchen_places.gd:5`,
`demo_kitchen.gd:80`). Production room validity is count-only
(`core/buildings.gd:1640`), not complete access/enclosure/heat validation.

**Why it matters:** placing an oven mesh cannot make a functioning kitchen.
Every service needs its own eligibility, materials, worker position, storage,
activity and failure-state bindings. Free placement also invalidates the
current assumption that walking straight from the room middle is safe.

**Suggested direction:** retain separate shell and fit-out projects. Connect
appropriate room purposes and furnishings to real services through production
contracts, with deliveries and visible waiting/installation states. Preserve
progress and ownership across interruption. Do not turn the demo's immediate
refunds or free persistent large-bed alcove expansion into new release rules.

### UG-08 — High: underground save/resume is absent

**Evidence:** `godot/demo/README.md:364` explicitly says the demo cannot save.
The reviewed graph/burrow APIs do not expose canonical save/load of their state.
`core/save_owner_buildings.gd:35` and `save_owner_movement.gd:27` explicitly
leave bulk state capture/apply and cross-owner/connected-tunnel work open.
`test_save_replay_checkpoint.gd:2` tests checkpoint binding, not a disk coordinator.

**Why it matters:** a partially excavated room, funded support, blocked output,
pending furniture and residents already traversing a connection must resume
without duplicated goods, lost excavation or broken exits. Existing earth
provenance labels in inventory codecs do not save the physical cut ledger.

**Suggested direction:** make save/replay at every project phase part of the
design and acceptance criteria. Persist confirmed commands, paid cut state,
WIP, supports, goods/claims, spoil location, connectivity and traversal state.
Treat unsent draft persistence as a separate user-experience choice.

### UG-09 — Medium: the two cellar systems need coherent presentation and services

**Evidence:** decision `0612-the-cellar-building-stands-beside-the-dug-root-cellar.md:1`
records the explicit instruction to build both. Dug cellars derive capacity
from installed fixtures (`room_fixtures.gd:552`), while standalone Cellar
buildings have their own delivery/construction lifecycle
(`demo/stores/cellar_projects.gd:158`) and fixed catalog capacity
(`cellar_rules.gd:20`). `cellar_haul.gd:512` includes an entrance fallback
when a carrier cannot use the underground route.

**Why it matters:** the same player-facing function currently has different
capacity, construction and access behavior. A new room catalog could duplicate
storage again or accidentally remove a previously approved building option.

**Suggested direction:** keep both construction forms and expose their
differences clearly. Share valid storage/service interfaces, stable provider
identity and physical access rules; do not silently equalize capacities or
replace either option. Confirm whether an entrance delivery represents a real
transfer point before retaining it in the production model.

### UG-10 — Medium: the visual excavation front and shell finish need clearer meaning

**Evidence:** `room_view.gd:75` and `:460` reveal six geometric stages;
`:504` adds built-in supports/door lighting at completion. A cellar's bare
shell already includes its lined treatment. `warren_particles.gd:26` caps
active face effects at three. `fixture_view.gd:253` brings furniture in by
rise/scale/fade. Historical partial-room and dig-face images are retained.

**Why it matters:** a growing disc communicates progress but not necessarily
which wall workers are cutting. Finished lining that appears with no legible
construction stage blurs the distinction between raw excavation and a finished
room. Automatically spawning complete furniture weakens the sense of labor.

**Suggested direction:** agree what belongs to the empty completed shell.
Show the actual working frontier, fresh cuts, mandatory supports, temporary
spoil and clearing. Let delivered bundles and partial assemblies explain
furniture construction. Maintain bounded visual effects and prioritize visible
work fronts, without letting presentation decide progress or require particle
simulation for every resident.

### UG-11 — Medium: readability and construction workspace need a dedicated pass

**Evidence:** historical images show broad dark/jagged cut rims, dim working
faces and detailed props against relatively plain shell surfaces. Current
`underground_cap.gd:60` uses eight mask pixels/metre;
`underground_cap.gdshader:28` and `:98` contain sampling/cut-band treatment.
These are investigation points, not a proven single cause of the appearance.
The historical 720p frame has guide, legend, news, both side panels and bottom
commands covering much of the work area. Decision 0801 also records a news/map
picker overlap. `tunnel_view.gd:185` implements a mouse-ignoring floor label;
`demo_layers.gd:91` fixes section height.

**Why it matters:** the player must see an opening, cut face, entrance and
furniture approach area while editing. Atmosphere cannot depend on hiding
those elements in darkness. A passing rectangle-bound test does not establish
a comfortable construction workspace.

**Suggested direction:** one construction inspector and compact confirmation
bar, with optional overlays yielding during editing. Provide visible clickable
floor controls and explicit cutaway choices. Preserve decision 0801's rule
that U changes layer without automatically changing camera angle. Validate
smooth readable cut boundaries, material depth and task lighting at both normal
RTS distance and close inspection; compare against the approved grounded,
expressive target rather than adopting a new global art style.

### UG-12 — High: expanded topology and 256-resident behavior remain unmeasured

**Evidence:** `graph_paths.gd:131` rebuilds all live mouth source tables for
a fit class when its revision changes; both current fit classes can require
48 source searches at the present mouth cap. `tunnel_works.gd:281` scans
segments per frame and queries timelines. Decision 0208's measurements at
`:187` concern an earlier small demo, not this proposed larger system.

**Why it matters:** custom footprints, additional work faces, furniture
obstacles and simultaneous completions increase invalidation and path work.
Increasing fixed caps without measurement could cause expensive update bursts.

**Suggested direction:** bound and schedule dirty-region updates; measure
digging, hauling, installation and ordinary travel together at 256 residents.
Record route requests, topology rebuilds, render/mesh cost and simulation time.
Test multiple levels and simultaneous project completions. Do not claim a
frame-rate or wall-clock budget from old small-scene evidence.

## Test coverage read, and acceptance still needed

Existing tests cover graph routes against a reference (`test_demo_graph.gd:347`,
`:507`), cancellation (`:261`, `:280`), capacity refusals (`:1036`), fixed room
opening (`test_demo_rooms.gd:97`, `:227`), lower-level dependencies
(`test_demo_levels_edges.gd:177`), earth conservation (`test_demo_earth.gd:255`),
undug-room refusal (`test_demo_fitout.gd:137`), installed-only capacity (`:252`)
and retained installation progress (`:364`). They were inspected, not rerun.

The eventual plan needs these additions, tied to approved features:

- Draft edits/cancellation change no authoritative inventory or jobs;
  confirmation revalidates stale access and capacity.
- Every shaping tool reaches the same physical cut identity; overlaps,
  enlargement and reload never double-pay or double-yield.
- Workers only reach excavations through completed space and legal work faces;
  supported void becomes usable at the correct atomic commit.
- Full or unreachable spoil storage pauses safely; retry adds no duplicate work,
  experience, wear or output.
- Empty completed rooms remain empty until furniture is ordered; inappropriate
  equipment refuses with a clear reason.
- Furniture fits its room, can be reached and used, preserves entrance routes,
  and behaves correctly when expanded, moved, removed or interrupted.
- Cancellation, backfill and demolition preserve goods, occupants, reservations
  and the last safe exit; physical excavation progress cannot be refunded twice.
- Save/load/replay match at draft policy boundaries and every authoritative
  construction phase, including blocked completion and occupied connections.
- Both cellar forms, kitchen/meal supply, heat/fuel, beds and infirmary services
  use actual legal access rather than proximity or a visually open doorway.
- A complete 1280×720 workflow with the real HUD: outline, confirm, partial dig,
  empty completion, fit-out, daily use, adjacent connection, second floor,
  cancellation/resumption, keyboard navigation and reduced motion.
- Repeat the integrated workload at the 256-resident cap, including topology
  revision bursts. Keep missing platform qualification explicitly unmeasured.

Existing live harnesses include `godot/test/live/demo_camera_live.gd`,
`demo_routes_live.gd`, `demo_input_live.gd` and `demo_layout_live.gd`. They can
support fresh evidence after the approved interaction is implemented; retained
phase-specific scratch probes need compatibility review first.

## Planning handoff

The first player-facing decision was the **room-shaping method**. Following
this review, Brendan approved grid-based add/erase painting with organic
boundaries, multiple room-appropriate shapes beyond circles/ovals, a tunnel
tool, and correctly fitted/scaled surface materials. The approval and remaining
choices are recorded in the [working agreement](../design/underground-planning/README.md).
The comparisons are schematic, not playable prototypes or a final shape catalog.

After that decision, discuss one topic at a time: room use/style boundaries,
empty-shell finish, furnishings/access, worker/logistics experience, and editing
or expansion of occupied spaces. Then resolve technical ownership, persistence,
budgets and implementation gates against the chosen experience. This is an
order for discussion, not a preapproved full implementation plan.

The approved visual direction already calls for purposeful inhabited earth:
roots, timber, hearths, storage, practical tools and connected domestic rooms.
See `docs/art-reference/visual_direction_alignment.md` and
`docs/redwall-content-library/shared/locations_and_movement.md`. Literary
references inform materials and use; they do not authorize new numerical rules,
random hazards or hydrology. New content briefs must retain book-qualified
source IDs and distinguish source facts from proposed game treatment.
