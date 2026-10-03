# Underground planning — working agreement

Started 2026-10-02. This records the approved player-facing design and its
implementation progress. It does not replace the owning game contracts.

**Implementation authorized, 2026-10-02:** Brendan asked, “Ok- please start
building this in now to the other work I’ve been doing.” Work has begun from
`origin/master` at `223eb586` on `codex/underground-build-2026-10-02`, in an
isolated worktree, then integrated `origin/master` at `82d60ba8` (PR #228).
See [implementation status](implementation-status.md) for
the exact delivered slice and the outstanding parts of the first milestone.

The [initial review](../../reviews/2026-10-02-underground-building-review.md)
is pinned to `d9941bd9fc4ebdca12ab5b34d86c943439d93ad1`.

## User direction already given

- Select a room or passage type and lay out a blueprint before confirming it.
- Workers excavate the room; completion leaves an empty shell.
- Furnishing is ordered afterward, with equipment appropriate to the room use.
- A completed room retains its selected type even when empty. A different type
  requires removing the actual room and building a newly selected room layout.
- Removing a built underground room includes real backfilling to solid ground;
  a replacement requires excavating and constructing its new floor plan.
- Use Evil Genius 2's clear construction workflow as a reference, with rounded
  tunnels, burrows and room boundaries suited to this world.
- Make the result immersive, dynamic and visually high quality.
- Work through recommendations and approvals in small pieces before producing
  a complete implementation plan.

## Approved direction

**D01 — Grid-based room painting with organic boundaries. Approved by Brendan
on 2026-10-02, with the additions below.**

The user accepted the recommendation to add/erase room area in predictable
increments, show the planning grid, and preview the rounded boundary before
confirmation. This refines option A from the earlier comparison. It does not
adopt unconstrained freehand sculpting or a curve-handle editor as the main tool.

The approval explicitly requires:

- Different shape tools appropriate to different room uses; circles and ovals
  must not be the only available shapes.
- An appropriate tool for laying out tunnels.
- Appropriate walls, floors, roofs/ceilings and other shell materials.
- Materials that maintain appropriate scale as room shapes and sizes change.
- Complete surface coverage inside the intended boundaries, with no unintended
  spill beyond them or uncovered gaps short of them.

The workflow remains blueprint → confirm → worker excavation → empty completed
shell → separately ordered compatible furniture. This originally recorded design approval. Implementation is now authorized
as noted above; numerical grid spacing, capacities, material prices and the
mapping to the adopted physical cut ledger still require their owning contracts.

[Shape and surface requirements](shape-and-surface-requirements.md) records this
approved intent, concrete acceptance criteria derived from it, and proposed
tool/material examples. Specific examples are labeled as proposals.

**D02 — Room-appropriate defaults with compatible customization. Approved by
Brendan on 2026-10-02.**

The user selected option 1 for room materials: “I choose item 1 for room
materials.” Each room type suggests a coherent, appropriate wall/floor/ceiling
treatment, and the player can choose compatible alternatives. Appropriate
shape suggestions remain conveniences within D01's varied tool palette, not
mandatory room templates.

Material changes must preserve the approved boundary fit and physical texture
scale. This choice does not approve a specific material catalog, costs, service
bonuses, finish timing or changes to furniture eligibility. Connection types
are recorded separately in D04.

**D03 — Multi-level access must protect other levels and their contents.
Required by Brendan on 2026-10-02.**

Account for multiple underground levels and appropriate ways up/down. An
entryway/stair/other connection must not overlap a wall, bed, stove or other
obstruction on an affected level. Validate the full intervening space as well
as both landings, preserve required headroom/support, and protect the connection
against later blocking construction or furniture placement. An intentional
floor opening is part of the plan; automatic damage or relocation is not.

[Levels and connections](levels-and-connections.md) records the requirements,
setting evidence, access types and verification cases. Exact level
count, spacing, depths and connector dimensions remain unresolved.

**D04 — Full connection catalog, including spiral stairs and ladders/hatches.
Approved by Brendan on 2026-10-02.**

The user selected option 3: “Item 3 for steps.” Include earth/timber steps,
stone stairs, sloping passages/ramps, spiral stairs, and timber ladders with
hatches. Straight and turning stair/ramp layouts are part of the intended
variety; supported variants and numerical geometry still need definition.
D05 below records the chosen placement interaction.

All types inherit D03's full-space, landing and cross-level protection rules.
Spiral stairs and ladders must also validate actual turn clearance, grip,
resident capability and carried loads under the movement owner. Selecting
the catalog does not make every connection usable by every resident or task,
or approve numerical dimensions, recipes, costs or traversal speeds.

**D05 — Fixed-size connection pieces. Approved by Brendan on 2026-10-02.**

The user selected option 2 ("2") in the connection shaping/sizing question:
choose from predefined sizes and layouts, rotate and place them. Connection
dimensions and the relative positions of their landings belong to the selected
piece; the player does not stretch its run, width or height or paint its route.
This applies to D04's complete connection catalog. Room painting and the
separate tunnel route tool retain D01's approved flexibility.

Each piece must fit the actual height difference, openings, headroom, landings
and access space on every affected level. If no supported piece fits, show the
reason; do not stretch the piece or move existing walls/furniture to make it fit.
The number of variants and dimensions remain unresolved. D06 below records
the selected floor-height model.

**D06 — Standard underground levels with split-level areas. Approved by Brendan
on 2026-10-02.**

The user selected option 2 ("2") in the floor-height question: standard levels
with raised or sunken sections inside rooms, connected by additional fixed
short stair pieces. A local floor-height change must be real geometry used by
movement, placement and construction, with the same clearance and protection
rules as connections between the main levels.

This selects the player-facing height model, not numerical depths, offsets,
level count or spacing. The existing four-level/4 m candidate is not adopted.
Supported short connection variants must match their actual endpoint heights;
room elevations and fixed pieces must not be stretched to conceal a mismatch.
The shape controls for raised/sunken sections are recorded in D07 below.

**D07 — Paint raised/sunken sections with supported height choices. Approved
by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the section-creation question. Use the
room's shape tools to paint a section, choose a supported raised or sunken
height, then position matching fixed short stairs. This allows rounded,
straight-sided and irregular sections while preserving D05's fixed connection
dimensions. The selected height must be supported by the eventual connection
catalog; numerical heights and the number of variants remain unresolved.

All sections retain the room's construction workflow and the approved
headroom, furniture-access, surface-fit and cross-level protection requirements.
See [the connection slice](levels-and-connections.md) for acceptance criteria.

**D08 — One room project with visible excavation and finishing stages.
Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the finish-timing question. Confirm the
room blueprint and selected materials together. Workers perform excavation
with the required support work, apply the chosen wall/floor/ceiling finishes,
and leave an empty completed room ready for separately ordered furnishings.
The player does not need a second order to start its selected finish work.

Construction progress must be visible in the world. Mandatory bracing and
structural finish remain governed by SET-MOVE-ECON-001; the combined player
project does not reorder those phases or charge installed bracing twice.
This approval supplies no new recipes, costs, service bonuses or automatic
furniture. See [shape and surface requirements](shape-and-surface-requirements.md)
for completion criteria and the structural/decorative distinction.

**D09 — Grid-based furniture placement with rotation and access guides.
Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the furniture-placement question. The
player positions and rotates each compatible item on a visible placement grid,
with its occupied footprint and required access space highlighted. Furnishing
begins after D08's room project completes. Placement must validate actual floor
support, room boundaries, objects, doorways, stairs and reachable use/install
positions, including raised and sunken sections.

This replaces mandatory fixed fixture spots as the intended player experience.
It does not supply new grid spacing, furniture sizes or rotation increments;
the existing controls specify 90-degree placement rotation until amended.
Expanded geometry still requires a consistent mapping to the owning spatial,
room and service contracts. [Furnishing and room use](furnishing-and-room-use.md)
records the requirements, current implementation gap and future checks.

**D10 — Both furniture confirmation modes, selectable for the current room.
Approved by Brendan on 2026-10-02.**

The user requested: "Give players both functionalities and an option to choose
which one they are using for the current room". Provide a visible room-specific
choice between arranging a layout before confirming it and creating an order
for each valid item placement. This is a choice for the selected room, not a
single forced mode for every room.

Both modes retain D09's grid, footprint/access guides and validation, and D08's
completed-room prerequisite. A mode switch must not implicitly confirm or
discard drafts, cancel orders or alter material accounts. Confirmed orders
retain their construction state when the player changes mode. The furnishing
slice distinguishes the approved modes from proposed default/retention details.

**D11 — Suggested room entrance and passage connection, editable before
confirmation. Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the entrance-placement question. The room
blueprint proposes a valid entrance and passage connection; the player can
reposition it before confirming. Preview the opening and required access space,
and revalidate the whole connection after edits against the actual room/passage
boundary, height, support and nearby obstructions.

A suggestion cannot cut a wall, order a passage or move furniture before
confirmation. If no valid entrance/connection is available, explain the missing
access instead of making an unbuildable room appear ready. Entrance profiles
and numerical dimensions remain to define; D13 covers additional connections. See
[levels and connections](levels-and-connections.md) for acceptance criteria.

**D12 — Fit room entrance doors during furnishing. Approved by Brendan on
2026-10-02.**

The user selected option 2 ("2") in the door-timing question. Workers complete
the room with its new entrance open; the player can order a compatible door
afterward during furnishing. Doors use D10's selected furnishing mode and the
actual delivery, installation and clearance rules. D08's empty-shell handoff
remains unchanged; no entrance door is installed automatically with it.

The finished opening must be structurally complete and visually meet the room
and passage. Later door installation must fit the actual opening and preserve
required access. This approval concerns room entrance doors, not the safety
completion of stairs or ladder/hatch connections. Exact door styles, dimensions
and their catalog mappings remain to define.

**D13 — Plan additional entrances from either the passage or the room.
Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the additional-entrance question. Support
both approaches: draw a passage to a valid room boundary to preview an opening,
or mark the opening first and then lay out its connecting passage. Both lead
to the same validated construction plan and require explicit confirmation.

Marking a wall does not immediately open it. Workers perform the required
excavation/support/finish work, protecting existing furniture, stairs and access.
Equivalent confirmed geometry must not receive different excavation prices or
completed connectivity because the player started from a different tool.
D11 remains the suggested initial entrance; D12 keeps doors as later furnishing
orders. Numerical connection limits and detailed construction sequencing remain
engineering work.

**D14 — Keep unaffected areas usable during structural work when valid.
Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the occupied-room construction question.
Separate the work area and retain use of unaffected space only while actual
access, room validity and services remain valid. If safe separation cannot be
maintained, work waits until the affected room can be safely cleared. Preview
the affected area and interrupted uses before confirmation.

This preserves safe exits, furniture, goods and the existing prohibition on
cutting occupied/reserved space or using unsupported unfinished voids.
REQ-SET-129 still suspends services from an invalid room; this approval does
not let selected beds or equipment continue operating inside one. It does not
authorize automatic furniture moves, instant evacuation or new hazard penalties.
Renovation-specific coordinated moves are approved separately under D24.
Exact work-area geometry and construction/service transactions remain to specify.

**D15 — Workers relocate portable furniture; fixed installations require
dismantling and rebuilding. Approved by Brendan on 2026-10-02.**

The user selected option 1 ("1") in the furniture-rearrangement question.
Provide a distinct Move action for catalog-approved portable furnishings.
Workers handle and transport the existing item through a route that fits the
actual load, then set it in a valid destination. Fixed installations use the
existing removal and construction rules. An obstructed move must explain its
blocker, never silently substitute demolition.

DEC-043 and decision 0536 retain their removal rule: 50% material salvage,
not an intact item. Relocation neither invokes that refund nor creates a second
piece. D15 approves the player experience; eligible items, work, cargo profiles,
claims, interrupted moves and persistence still need an owner contract before
implementation. Small chairs/tables as portable and masonry cooking fixtures
as fixed are candidate examples, not an approved portability catalog. Stored
goods remain protected; D16 defines their handling during relocation. See
[furnishing and room use](furnishing-and-room-use.md) for acceptance criteria.

**D16 — Unload storage furniture before relocating it. Approved by Brendan on
2026-10-02.**

The user selected option 1 ("1") in the storage-contents question. Workers haul
affected goods to reachable, eligible storage with available capacity, relocate
the empty eligible furnishing, then restock through normal hauling and the
applicable storage rules. If unloading is blocked, relocation waits with a
specific explanation. Moving a loaded container is not the selected policy.

A furniture-owned container must be emptied and its outstanding reservations
resolved through their owners before pickup. Existing pantry shelves instead
contribute capacity to a single building-owned pantry container under decision
0536; goods are not assigned to individual shelves. Moving one requires only
the hauling needed to keep contents plus reservations within remaining
available capacity, not emptying the whole pantry. It cannot carry a fictional
share of the building's inventory or supply capacity at two places at once.

Goods and claims remain conserved through unloading, relocation, restocking
and interruption. Restocking cannot recreate quantities or silently change
storage ownership/eligibility. This approval retains existing demolition's
emptiness checks and supplies no new container catalog, quantities, handling
rates or general nested-container system. Exact capacity transitions and
reservation handling still need the relocation/inventory integration contract.

**D17 — Contextual blueprint during excavation. Approved by Brendan on
2026-10-02.**

The user selected option 1 ("1") in the excavation-blueprint visibility question.
Show the full translucent plan when its project is selected or being edited;
otherwise retain a subtle planned boundary around the visible work. Preserve
D08's visible committed progress: actual working faces, required supports,
real spoil hauling and finishing remain legible as workers progress.

Plan overlays stay distinct from completed space and reveal no undiscovered
contents or geology. Existing warnings and blocked-state information remain
available regardless of selection. This approval concerns construction-plan
visibility, not a new world art style, roof mode or change to excavation
mechanics. Exact opacity, line weight and transitions remain visual-design
work with a 1280×720 acceptance check. See
[shape and surface requirements](shape-and-surface-requirements.md) for criteria.

**D18 — Built room types are permanent; a different type requires room removal
and new construction. Approved by Brendan on 2026-10-02.**

The user rejected both proposed conversion workflows and specified: "It always
stays a kitchen. So you need to remove the actual room, select the new room
(ie. Bedroom) then build that layout from there". Clearing a kitchen's furniture
does not turn it into a bedroom or unlock bedroom-only furnishing. An invalid
kitchen loses its services under the existing rules, but retains its type.

The replacement sequence is: safely clear affected occupants/goods and resolve
furniture through deliberate orders; remove the actual built room; select the
new room type; lay out and confirm its appropriate floor plan; workers build
that room; then furnish the completed new shell under D08–D10. There is no
in-place type switch or empty-room relabeling shortcut. The old completed room
and its finishes cannot simply be carried forward as an already completed room
of the new type. D19 requires restoring solid ground through backfilling before
the replacement is excavated and built.

The new floor plan still uses D01's varied shape tools and D02's compatible
material choices. This approval does not impose one fixed prefab shape per
type, supply a bedroom catalog mapping, or authorize automatic demolition,
furniture relocation, inventory loss or new prices. D15/D16 govern deliberate
relocation; adopted furniture salvage, room validity and safe-removal rules
remain in force. Changes that retain a room's type remain subject to D14.
See [furnishing and room use](furnishing-and-room-use.md) for acceptance criteria
and the integration work needed before implementation.

**D19 — Backfill the removed room before rebuilding. Approved by Brendan on
2026-10-02.**

The user selected option 2 ("2") in the post-removal space question. Workers
safely remove the built room and backfill its excavation with actual earth,
restoring solid ground. A replacement then uses the newly selected room type
and floor plan, with fresh excavation, required support and construction before
furnishing. Leaving an open cavity as the completed removal outcome was not
selected. This is physical work, not an instant terrain or room-type reset.

SET-MOVE-ECON-001 ECON-005 governs the operation: resolve occupants, items and
claims before closure, maintain legal work access, and keep installed support
until its coupled backfill/salvage transaction commits. Haul real earth and
wait with an explanation if resources, routes or required output capacity are
unavailable. Do not report removal complete until the room's removal scope is
backfilled and its obsolete services/access are retired.

Re-digging follows the existing brace/cut/finish rules and recovers earth from
the backfill account; it does not create a second virgin-soil yield. Preserve
physical history, partial closure, claims and accounting through cancellation
and saves. Protect neighboring rooms, upper/lower floors and stairs; closure
cannot remove the last safe exit or silently include another room/connection.
Exact removal-scope geometry, shared-support ownership, room-finish recipes and
safe work sequencing remain engineering work. D19 does not change ordinary
furniture salvage or unfinished-project cancellation rules.

**D20 — Start with one complete small underground build. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1") in the implementation-sequencing question.
The first milestone proves a kitchen and bedroom connected by a tunnel and
stairs across two test levels, covering planning, digging, finishing,
furnishing, relocation, backfill and rebuilding together before expanding the
full room/tool palette. The alternative of completing the entire editor first
was not selected.

This small build is a test fixture, not a two-room or two-level product limit,
fixed prefab rule or reduction of D04's full connection catalog. Kitchen/
bedroom labels must map to the actual room catalog; no new recipe or room enum
is implied by this example. [First milestone](first-milestone.md) describes
the proposed fixture, work sequence and evidence needed to accept it.

Before implementation, close the relevant geometry, paid-cut, movement,
inventory and save contracts against the current owning specifications. The
milestone needs a 1280×720 visual review, real worker/material behavior and
meaningful interruption/save checks; the final integrated design still needs
qualification at 256 residents. The existing restriction on gameplay-code
edits remains in force during this planning task. This decision chooses plan
order, not permission to bypass owner contracts or start restricted edits.

**D21 — Shared stair passage for the first test build. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1") in the fixture-layout question. The kitchen
and bedroom branch off shared circulation containing the stair connection
and its landings. Keep that passage outside each room's removal scope so
replacement can preserve the main route, subject to actual support, clearance
and occupancy checks. The [comparison](first-milestone-layout.png) records the
two schematic alternatives; its option 1 is the approved arrangement.

This selects the first fixture layout, not a rule against valid room-contained
stairs elsewhere. It does not authorize backfilling a protected connection,
overlapping furniture or treating a future exit as completed. Shape, span,
grid spacing, depth and clearance dimensions remain to define; the diagram
is not an engine capture or geometry qualification. Keeping the route open
also does not preserve cooking, heat or other services supplied by a room
being removed; those effects still require their real service checks.

**D22 — Optional furniture outlines while drawing a room blueprint. Approved
by Brendan on 2026-10-02.**

The user selected option 1 ("1"): optional example furniture outlines and
their required access space help judge the room's size while painting. These
guides supplement the boundary, dimensions and written room requirements.
Players can hide the examples without losing the normal validity information.
The alternative of providing only geometry and written requirements was not
selected.

Examples use actual compatible catalog footprints, supported rotations and
access requirements. Revalidate them against edited boundaries, floor heights,
entrances and protected stair/landing space. Never shrink equipment, clip its
footprint or show a blocked approach as usable. An illustrative arrangement
does not by itself establish every room count, area or service requirement;
missing catalog/access data must not be presented as proof of fit.

These are non-ordering guides: no furniture placement command, queued order,
cost, inventory change, authoritative reservation, fixed socket or service
grant. Actual furnishing and its two confirmation modes still begin only
after room completion. Examples are not transferred into a furnishing draft.
See [first milestone](first-milestone.md) and the
[shape and surface requirements](shape-and-surface-requirements.md) for the
corresponding checkpoint and acceptance criteria. Exact rendering and example
arrangement generation remain engineering/design work.

**D23 — Worker renovation of completed room finishes. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1"). Players can order compatible replacement
wall, floor and ceiling finishes after a room is completed. Workers deliver
the required materials and perform the replacement while preserving the room's
type and shape. The alternative of requiring full room removal/backfill for
every finish change was not selected. D18 remains unchanged: changing a
kitchen into a bedroom still requires removing and rebuilding the room.

Renovation must reflect actual work and installed finishes, protect access and
support, and resolve affected furniture, stored goods and services under
D14–D16 and the owning rules. It cannot remove structural support from an open
void or silently treat a load-bearing lining as decoration. A compatible
finish must fit the validated envelope; replacing a finish cannot create
overlaps with furniture, stairs or neighboring levels. Real blockers must
remain visible, and interrupted work/resources must be preserved.

This approves the renovation workflow, not a material catalog, numerical
recipe, salvage rate or service bonus. Those details still need their owners;
D24 separately approves reviewed coordination of affected portable furniture.
See [shape and surface requirements](shape-and-surface-requirements.md)
for the derived acceptance criteria.

**D24 — Coordinated furniture move-out and return for renovation. Approved by
Brendan on 2026-10-02.**

The user selected option 1 ("1"). Preview the affected portable furniture,
legal temporary positions and intended return placements before confirmation.
The player can review and adjust those positions, then workers perform the
necessary unloading, move-out, renovation and return in dependency order.
Separate player-issued moves are not required for every stage of the approved
plan. This is approval of coordinated relocation for renovation, not blanket
permission to rearrange furniture during other work.

D15/D16 still govern actual movement, catalog eligibility, route/load fit,
storage ownership, goods and claims. A fixed installation needs deliberate
dismantling/rebuilding under its own rules; a blocked Move never silently
becomes demolition. If there is no legal temporary position or route, affected
work waits and explains the blocker. Return placement must also remain valid
after the finish change and after later world changes.

Cancellation, interruption and saves retain actual item locations and completed
work. No instant reset, duplicate item or unapproved replacement destination
is allowed. Required support, stair/door approaches and neighboring spaces
remain protected throughout. See [furnishing and room use](furnishing-and-room-use.md)
for acceptance criteria and the remaining engineering contract.

**D25 — Whole-surface finishes only. Approved by Brendan on 2026-10-02.**

The user selected option 2 ("2"). Each room has one floor finish, one wall
finish and one ceiling finish, selected independently from compatible choices
with D02's appropriate defaults. Local material painting and mixed finish
sections within one surface category were not selected. This does not restrict
D01's room shapes or D06/D07's painted raised/sunken sections.

Each finish covers its entire applicable surface, including curved/concave
boundaries and split-height areas, while preserving intentional openings and
physical texture scale. One finish is not one enlarged texture stretched over
the room; authored grain, joints and variation can remain part of that finish.
Finish changes must not spill into neighboring rooms, stairs or other levels.

D08 applies the choices during initial construction. D23/D24 apply later
changes through worker renovation and reviewed furniture relocation. Changing
the floor finish does not by itself order new walls or ceilings. Work can
progress in safe stages, temporarily showing actual old/new or unfinished
areas; completed replacement has one selected finish for that surface category.
No local repaint tool, material recipe, bonus or room-type conversion is
approved. See [shape and surface requirements](shape-and-surface-requirements.md).

**D26 — Amend unstarted areas during room construction. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1"). Players may add or remove room blueprint
areas where physical work has not started, review the changed work, material
requirements and access, then explicitly confirm the amendment. The remaining
layout is not locked for the entire construction period. Already started
bracing, cutting, installed support, completed geometry and committed work
remain real and cannot be erased by changing the drawing.

Keep the room type and whole-surface finish selections. Fixed stairs retain
D05's geometry, and an amendment cannot silently relocate an entrance or
landing. The complete amended plan must remain constructible and protect
existing access, support, neighboring rooms and other levels. Reservations,
deliveries and physical-site history must be checked even where no visible
digging has begun. Revalidate actual work and claims at confirmation; a stale
preview must refuse an ineligible change instead of resetting progress.

Preserve the physical ledger, actual goods, claims and partial work through
amendment, cancellation and saves. Existing cancellation/refund owners govern
removed unstarted work; this approval creates no new refund rate or virgin
excavation yield. Draft edits alone have no authoritative effects. D27 separately
approves a safe project pause when the player invokes the revision workflow.
See [shape and surface requirements](shape-and-surface-requirements.md).

**D27 — Safely pause the room project during revision. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1"). The explicit Revise action requests a safe
pause for the affected room's construction while the rest of the settlement
continues under its existing speed/pause state. Workers reach the construction
owner's safe stopping point; the UI distinguishes a requested pause from an
acknowledged one. Selection, hover and blueprint visibility alone do not pause
work. The alternative of deliberately continuing this project's construction
throughout revision was not selected.

Retain actual work, delivered materials and work in progress, and handle workers
and uncommitted leases through the existing pause rules. Do not roll back work
committed before the stop was acknowledged. The acknowledged pause stabilizes
this project's remaining work; confirmation must still revalidate other world
changes and the current authoritative state.

After a revision is accepted or explicitly discarded, release only its editing
pause. A pre-existing or later player-issued pause remains effective, and real
delivery/access blockers remain. Do not resume the whole game or unrelated
projects. Invalid confirmation cannot release the editing pause as if an
amendment succeeded. Hold ownership, interruption and persistence need their
engineering contracts; D28 requires resolving changes before deliberately
leaving an unfinished revision. See [shape and surface requirements](shape-and-surface-requirements.md).

**D28 — Resolve unfinished revisions before leaving. Approved by Brendan
on 2026-10-02.**

The user selected option 1 ("1"). When leaving the room revision editor with
unapplied changes, offer Apply changes, Discard changes or Keep editing. The
alternative of freely leaving a retained draft and its project paused was not
selected. This closes the revision interaction choices in D26–D28.

Apply must pass current validation and receive authoritative acceptance before
the edit is treated as committed. A rejected amendment retains the draft,
shows the blocker and keeps the editing pause. Discard removes only the
unconfirmed edits, preserving the previously accepted plan and all physical
work. Successful Apply or explicit Discard releases only the editing pause;
Keep editing retains the draft and hold. Independent manual pauses, blockers
and global time controls remain unchanged under D27.

This concerns D26/D27 room revisions, not normal selection, layer inspection
within the same edit, initial blueprint strokes or D10 furnishing modes. An
unchanged revision needs no lost-changes prompt; leaving it must still release
its editing hold correctly. Escape/focus handling must not apply or discard
changes accidentally. Save/load and interruptions must preserve the draft and
its valid hold ownership without silently resolving the decision for the player.
Exact registered controls and persistence remain engineering work.

## Current review checkpoint

The interaction choices discussed in D01–D28 are recorded. The next review
piece is the already scoped [blueprint-to-empty-shell checkpoint](first-milestone.md#first-review-checkpoint-blueprint-to-empty-shell):
plan the kitchen with whole-surface materials and optional fit guides, build
with real work, revise an unstarted area through the complete pause/exit flow,
then inspect the finished empty shell before furnishing. This combines the
approved decisions; it is not another request to approve those same rules.

Continue reviewing the small D20 build in its existing checkpoints rather
than adding unrelated features. Exact geometry/catalog bounds, material/work
recipes, owner integration, save contracts and measured visual/performance
evidence remain to establish before implementation acceptance. The source
review remains pinned to its recorded baseline. The implementation status
records the refresh against current master and distinguishes old evidence
from new runtime checks.

## Earlier comparisons and display fallback

The accompanying `room-shape-options.html` is the earlier schematic comparison.
Its circle/oval examples illustrate a narrow case, not the approved shape limit.
Clicking its examples is not approval of additional features. Dimensions,
construction quantities and the underlying paid-cut mapping remain undecided.

At the user's request, `room-shape-examples.html` adds a simultaneous comparison
of the same brief under all three methods: main chamber, sleeping alcove and
entrance. Blueprint, empty-shell and furnished views illustrate the sequence;
they do not approve a specific layout, room catalog, shell finish or furniture
placement rule. D01's approval is recorded above from the user's later answer.

The user reported that the inline visualizations do not display. Ordinary PNG
exports are available as [blueprint examples](room-blueprint-examples.png) and
[furnished examples](room-furnished-examples.png). Use these visible images and
direct file links for the next discussion rather than relying on inline embeds.

The initial planning discussion authorized no implementation or paid art.
The subsequent explicit build instruction above authorizes this feature’s
implementation; paid generation remains unauthorized. The design ledger was
originally kept here under the earlier review-only write restrictions. Existing
owning specifications have not been rewritten by copying that ledger into the
implementation branch. Each implementation packet must reconcile its work
with those owners and the outstanding movement/excavation engineering gates.
