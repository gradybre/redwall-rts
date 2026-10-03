# Underground levels and connections — planning slice 2

2026-10-02. The user requires multiple underground levels and setting-appropriate
ways to move between them, without a connection overlapping a wall, furnishing
or other obstruction on an affected level. These requirements extend D01;
they do not approve connector recipes, exact dimensions or final level spacing.

See [the working agreement](README.md): D03 records the accepted clearance
requirement, and D04 approves all five connection families below. Material
customization (D02) is also approved: room-appropriate defaults with compatible
alternatives. D05 approves fixed-size connection pieces, and D06 approves
standard levels with raised/sunken areas inside rooms. D07 approves painting
those sections with the room tools, choosing a supported height and placing
matching fixed short stairs.

D11 also approves a suggested room entrance and passage connection that the
player can reposition before confirmation. D12 approves fitting room entrance
doors afterward during furnishing. D13 approves planning additional entrances
from either the passage or the room. D14 approves continued use of unaffected
areas during structural work only while access, room validity and services
remain valid.

## What is settled

- A level connection must fit at its upper end, lower end and throughout the
  intervening space. Checking only the active floor or the two endpoints is
  insufficient.
- A stair/ramp/shaft cannot automatically cut through an existing wall, bed,
  stove or another object's occupied or required access space. Conflicts must
  be shown before confirmation, with no automatic demolition or relocation.
- The intended floor/ceiling opening is part of the connection blueprint.
  Creating that opening is a deliberate change, not permission to damage the
  surrounding floor, ceiling, room, supporting structure or furnishings.
- Different levels may overlap in horizontal plan when their actual heights,
  headroom and required separation permit it. A blanket X/Z overlap ban would
  wrongly forbid rooms stacked on different floors.
- The precise number/depth/spacing of levels remains an engineering decision.
  The existing two-level demo at candidate 4 m spacing is not the final limit.
- Include earth/timber steps, stone stairs, ramps, spiral stairs and timber
  ladders with hatches. The user chose the complete catalog in D04; individual
  connection designs must still meet the movement and construction contracts.
- Place connections by selecting a predefined size/layout, rotating it and
  positioning the whole piece. D05 does not change room painting or the
  separate tunnel route tool.
- Organize the underground around standard levels while allowing raised and
  sunken room sections, with matching fixed short stair pieces. Exact level
  heights and local offsets remain unresolved.
- Paint raised/sunken sections with the room's shape tools and choose from
  supported height offsets; position their matching fixed short stairs.

## Approved connection families — detailed designs remain proposals

| Type | Proposed appearance and use | Spatial/access consequence |
| --- | --- | --- |
| Earth steps with timber risers | Hand-dug burrow stairs with reinforced step fronts and practical rails | Straight or turning runs with real landings; retain headroom through the bend |
| Stone stairs | Stone treads and appropriate lining for cellars, kitchens or substantial communal buildings | Straight, L-shaped or returning flights; both landings and the full stairwell must fit |
| Sloping passage/ramp | A continuous packed-earth or appropriate paved descent | More horizontal run for a gentler descent; useful for hauling only when slope, width and load rules permit |
| Spiral stairs | Timber or masonry steps around a central support, appropriate to a compact stairwell | Potentially compact, but the central obstruction, turn clearance, headroom and cargo path must be real |
| Timber ladder and hatch | A small access shaft with a framed hatch and reachable step-off area | Specialized climbing route; eligibility must consider grip, capability and load; not a substitute for a usable route for every task |

D04 includes all five families. A staged implementation may develop them in
sequence, but shall not report the approved catalog complete while spiral
stairs or ladders/hatches remain absent. No suggested footprint implies a
fixed production cost, speed, progression unlock, species permission or capacity.

## Fixed-size connections — approved D05

The player chooses an authored size/layout, rotates it and places the whole
piece. Width, run, rise, turns and relative landing positions belong to that
variant. There are no player drag handles for stretching a connection and no
connection route-painting mode. The earlier adjustable-blueprint recommendation
was not selected. This restriction is specific to level connections; D01's room
painting and tunnel route tools remain unchanged.

The catalog needs suitable variants for the approved families. Straight,
L-shaped and returning stairs, straight/turning ramps, spiral handedness and
ladder/hatch orientations are candidate variants, not a finalized list of sizes.
Each variant must provide actual tread/rung spacing, opening geometry, landing
approaches and clearance appropriate to its type. Choosing a material treatment
does not authorize stretching geometry or altering its access envelope.

Placement validates the authored height difference against both endpoints.
If no variant fits the selected floors, explain the mismatch; do not silently
scale the piece, leave a floor gap, change room elevation or move an obstruction.
Room surfaces must meet its openings cleanly while preserving texture scale.
Numerical dimensions, allowed rotations, catalog bounds and the 1280×720
selection/preview layout still require design and verification.

## Standard levels with split-level areas — approved D06

Each main underground level has a defined floor height. Within a room, raised
or sunken sections may occupy different heights, with fixed short stairs
providing the required connection. These are real floors, not visual offsets:
residents, furnishings, work contacts, picking and saves must agree on their
actual height and access. A shared room or main-level ID cannot by itself make
two differently elevated areas reachable from one another.

Raised areas must preserve usable headroom; sunken areas must preserve separation
from spaces beneath them. All sides, openings and approaches must fit, including
against confirmed unfinished work. Changing a section's floor must not silently
raise its ceiling into the room above, lower a neighboring ceiling, or shift
existing furniture. Supported ceiling profiles may vary only within validated
space. Exact profiles, offsets and structural envelopes remain engineering work.

No numerical depth, spacing, local offset or number of levels is adopted here.
Those values still need the movement geometry, representation, memory and
performance work described by MOVE-G01/G02/G05. The design retains free
multi-level excavation and all three interoperable construction methods. Local
height changes cannot create unpriced usable space or duplicate excavation/spoil;
any retained earth, additional cut or constructed floor needs the actual physical
ledger and construction recipe. Their representation is not settled by this choice.

## Painting a split-level section — approved D07

Use the existing room shape tools to paint the section, choose a supported
raised/sunken height, and place matching fixed short stairs. Rounded,
straight-sided and irregular section shapes preserve D01's variety while
connections retain D05's fixed dimensions. A shaped alcove or a sunken common
area is an example, not a required template or a new room type. Selectable
height offsets must match the eventual fixed-piece catalog; their values and
count remain open.

The workflow remains blueprint → confirm → construction of an empty shell →
separately ordered furnishings. Painting the draft has no excavation or
inventory effects before confirmation. Its preview must show the actual
section boundary, height difference and stair landings so that the player can
resolve fit and access conflicts before committing it. Detailed controls,
stage boundaries, edge protection, cutaway treatment and 1280×720 presentation
still need design. D08 approves selected surface finishes as part of the same
room project, completed before the empty room is handed over for furnishing.

## Placement experience — proposed realization of the requirement

1. Pick a connection type and authored size/layout, then its origin and
   destination level. The origin may be above or below; the command represents
   the same physical connection. Identify any height mismatch before confirmation.
2. Position/rotate the whole piece. Show both fixed landing positions, the
   intervening route and required clearance on all affected levels.
3. Offer a linked floor preview and section view so an obstruction hidden on
   another level is visible without losing the draft.
4. Highlight the specific conflict: for example, **upper landing blocked by
   bed**, **stairwell intersects cellar wall**, or **insufficient headroom**.
   Identify its floor and object; do not present only a red, unexplained ghost.
5. Confirm only after revalidating every affected region. The connection and
   its openings/landings are one coherent project, not independent stairs
   placed on separate floors.

The exact interaction and layout still need design at 1280×720. The preview
must not repeat the current crowded overlay arrangement. An intentional opening
and its walk space should be distinguishable from additional support/clearance
space, so the player understands what the project reserves.

## Room entrances — approved D11

Propose a valid entrance and passage connection as part of the room blueprint.
The player can reposition it before confirmation. Show the opening, its actual
floor height, lining and required access space, and revalidate the whole
connection whenever its placement or the room shape changes. Validate against
rooms, passages, furniture, support and other confirmed projects. No suggestion
mutates the world or queues excavation before the blueprint is confirmed.

An invalid edit must identify its conflict; it must not be silently committed
or replaced by a different entrance. If no valid connection can be proposed,
show the missing access and let the player revise the plan. Workers still need
a reachable construction approach, including for the first room on a new level.
The rule does not require a destination room to be pre-dug, nor permit workers
to appear inside disconnected underground space.

The demo already proposes a passage to fixed room sockets in
`godot/demo/burrow/room_plan.gd:9`–`:22`, under decisions 0209/0212. This is
precedent for a preview, not a general entrance-placement implementation.
Painted room shapes need valid openings derived from their actual boundaries;
the old template sockets and numerical search limits are not adopted here.
Entrance profiles, door catalog entries, connection capacity limits and exact
validation dimensions remain future design/engineering work.

## Entrance doors — fitted afterward under approved D12

Complete the new room entrance as an open, structurally finished opening.
The player may order a compatible door during furnishing after the room
project is complete, using either of D10's confirmation modes. Doors follow
the same deliberate post-completion ordering as other furnishings; the proposed
exception that would build one with the shell was not selected.

Every installed door needs its actual construction recipe, valid frame/opening
and usable approach. Its moving parts and reserved access must fit around
nearby furniture and level connections. An open arch and a door must use their
actual room/access/heat rules; this approval supplies no new sealing,
sound, privacy, lock or material bonuses. The selected treatment must preserve
D01/D02 boundary fit and physical material scale.

The open entrance still needs the required support and selected boundary
finish. A future door is not permission to leave an unsupported or visually
unfinished shell. D12 applies to room entrance doors; the safety completion
and usage rules of stairs, rails and ladder/hatch connections remain under
their own geometry/traversal contracts. Existing installed doors are not
automatically removed when adjoining space is changed.

## Additional entrances — both approaches approved under D13

Support both entry points into the same editing workflow: draw a passage to a
valid room boundary and preview its opening, or mark an opening on the room
and then lay out the passage. The player can work from either direction.
The availability of multiple connections is not being reopened; the demo
already joins passages at free room sockets under decision 0209.

Every approach needs an explicit confirmation and the same opening, support,
work-access and occupancy validation. A wall marker remains a draft until the
required construction plan is defined and accepted. Existing beds, shelves,
stairs and escape routes must be protected. Any newly excavated space is
priced through the shared physical ledger and cannot publish a usable route
before the required supported geometry is complete. A new door can then be
ordered separately under D12.

For equivalent confirmed geometry, both workflows must validate and price the
same physical work and publish the same connectivity. Tool order is not a way
to bypass occupied-space checks, create a free opening, double-charge an existing
cut or manufacture spoil from already open space. Numerical connection bounds,
construction dependencies and precise opening geometry remain to specify.

## Structural work in occupied rooms — approved D14

Keep unaffected areas usable only when the actual work boundary, room validity
and required routes permit it. Preview the affected area and interrupted uses
before confirmation. If safe separation cannot be maintained, work waits until
the affected room can be safely cleared. The existing completed room and new
work need distinct geometry/status; starting an alteration must not simply
reset the whole room to an undug state.

Mandatory owner rules remain in force: SET-MOVE-ECON-001 refuses cutting into
occupied/reserved space and keeps unfinished voids out of public routes;
MOVE-REQ-008 protects occupied access and the only safe exit; REQ-SET-129 suspends
services of invalid rooms without deleting residents, beds or goods. D14
therefore requires room/service revalidation, not merely marking a small region
as closed while every existing service continues. If safe separation and valid
access cannot be maintained, affected use must stop or the work must wait.

This choice does not authorize unrequested furniture relocation, instant
evacuation, new hazard penalties or temporary bypasses through undug space.
D24 separately approves coordinated portable-item moves within a reviewed,
confirmed finish-renovation plan; it does not broaden D14 to arbitrary moves.
Exact work-area geometry, handling of occupants and construction/service
transactions remain engineering contracts; no live-room alteration behavior
is claimed to be verified by this planning document.

D18 separately requires actual room removal and new construction when the room
type changes. D14's continued use during valid local alterations does not
authorize conversion of a kitchen into another room type. Replacement must
protect every neighboring space, supported level and required connection;
D19 requires backfilling the removed room to solid ground without relaxing
those protections. Identify dependent stairs, shared supports and required
routes before closure. Work waits until those dependencies are safely resolved;
it cannot include an adjacent room or connection in the removal without its
own valid, explicitly authorized scope. Maintain access for earth delivery and
the closing workers, including their final retreat. Future replacement stairs
or rooms do not count as a present escape route.

## Acceptance criteria derived from D03–D07 and D11–D14

| ID | Requirement |
| --- | --- |
| UG-LEVEL-001 | Every room, object, opening and connection endpoint shall retain its actual level and height; shared X/Z coordinates shall not imply shared occupancy or access. |
| UG-LEVEL-002 | Before confirmation, a connection shall validate its full three-dimensional occupied, clearance and support envelope, including headroom, rail/support thickness and both landing approaches. |
| UG-LEVEL-003 | The validator shall consider every level intersected by the connection, including any intervening level, rather than only its origin and destination. |
| UG-LEVEL-004 | If a connection conflicts with a wall, floor/ceiling outside its authorized opening, furnishing, usable object approach, another connection or required supporting region, placement shall refuse and identify the conflict on the relevant level. |
| UG-LEVEL-005 | Confirmed projects shall reserve their required space so that later walls, furniture, room edits or excavation cannot occupy the connection or block its landing/approach. |
| UG-LEVEL-006 | Placement checks shall include already confirmed but unfinished projects as well as installed objects; draft previews shall have no inventory or authoritative reservation effects. |
| UG-LEVEL-007 | When confirming a draft, the simulation shall revalidate changed occupancy and reservations atomically; a stale preview shall not authorize an overlapping project. |
| UG-LEVEL-008 | The system shall protect required ceiling/floor support and separation between stacked spaces; visual smoothing shall not erase the structural region or create an unapproved opening. |
| UG-LEVEL-009 | An unfinished connection shall not permit through travel. It shall become usable only when its required space, supports, openings and landings are complete and safely connected. |
| UG-LEVEL-010 | An accepted connection project shall have a legal reachable construction approach; workers shall reach new levels through completed space and legal work faces, not teleport into an isolated lower room. |
| UG-LEVEL-011 | Traversal shall validate resident, equipment, posture, grip and carried-load compatibility for the actual route and its turns under the movement owner. |
| UG-LEVEL-012 | A later closure, backfill or demolition shall resolve occupants, goods and claims and preserve required escape/access routes before making the connection unavailable. |
| UG-LEVEL-013 | The rendered stairs/ramp/shaft and openings on all affected floors shall match the confirmed geometry and use the surface-fit/material-scale requirements from slice 1. |
| UG-LEVEL-014 | The supported connection catalog shall include earth/timber steps, stone stairs, ramps, spiral stairs and timber ladders with hatches; each family shall use the same project, clearance, topology and traversal-eligibility contracts. |
| UG-LEVEL-015 | The connection tool shall offer predefined size/layout variants for selection, rotation and placement; it shall preserve the chosen variant's dimensions and relative landing positions. |
| UG-LEVEL-016 | If the selected variant does not match the actual endpoint heights or required space, confirmation shall refuse with a specific reason rather than stretch the piece, move room floors or relocate obstructions. |
| UG-LEVEL-017 | The underground shall support standard main levels with raised and sunken room sections connected by matching fixed short stair pieces; each section shall retain its actual floor height for placement, routing, work, picking and persistence. |
| UG-LEVEL-018 | When a section changes height, validation shall check headroom, floor/ceiling separation, surrounding structures and required access against every affected space, including unfinished confirmed projects. |
| UG-LEVEL-019 | When placing furniture on a split-level floor, the system shall validate its support, occupied volume and usable approach at their actual heights; a shared room ID shall not substitute for valid placement or reachability. |
| UG-LEVEL-020 | The generated room surfaces shall cover raised/sunken floors and their vertical boundaries consistently, including curved or concave edges and stair joins, without texture stretching, unintended gaps or overlap. |
| UG-LEVEL-021 | The section editor shall use the room's shape tools to paint raised/sunken regions, offer supported height choices compatible with fixed short stair variants, and preview the resulting boundaries, heights and landings before confirmation. |
| UG-LEVEL-022 | While laying out a room blueprint, the tool shall propose a valid entrance and passage connection where available and allow the player to reposition it before confirmation. |
| UG-LEVEL-023 | Entrance previews shall show the actual opening and required access space; changes to the entrance, room shape or surrounding state shall trigger validation of the full connection before it can be confirmed. |
| UG-LEVEL-024 | If no valid entrance/connection is available, the tool shall explain the missing access and shall not present the room as ready for construction or silently create a route. |
| UG-LEVEL-025 | When a room project completes, its newly created entrances shall be structurally finished open connections; room entrance doors shall require separate post-completion furnishing orders. |
| UG-LEVEL-026 | The editor shall support planning an additional entrance either by drawing a passage to a valid room boundary or by marking the room opening first and laying out its passage; both workflows shall produce an explicitly confirmed construction plan. |
| UG-LEVEL-027 | For equivalent confirmed geometry, both additional-entrance workflows shall apply the same validation, physical excavation accounting and completed-connectivity rules. |
| UG-LEVEL-028 | During structural work on an existing room, unaffected space shall remain usable only while work separation, required routes, room validity and service conditions permit it. |
| UG-LEVEL-029 | If safe work separation cannot be maintained, structural work shall wait until the affected area or room is safely cleared; the project shall not bypass occupied/reserved-space checks or create an unsafe escape route. |
| UG-LEVEL-030 | Before confirmation, the alteration preview shall identify the work area and expected interrupted uses; subsequent world changes shall trigger revalidation before affected work proceeds. |

Required construction access does **not** mean that both floors must already
be independently reachable: the first safe connection is how a new level is
opened. Its work sequence needs a reachable initial face and valid dependencies
for excavation and construction. The destination may be a planned landing/new
passage that becomes available as that work completes. No pre-dug room or free
shaft is inferred from placing a link.

An installed connection's reservation must also cover the space needed to use
it. It is insufficient to protect only the visible stair mesh while allowing
a bed, stove or closed wall directly across its top or bottom approach. Existing
task and last-exit constraints remain separate from ordinary static collision.

## Relation to the existing implementation and adopted rules

- SET-MOVE-001 already requires free multi-level excavation to interoperate
  with placed burrows and planned rooms/tunnels. Its MOVE-REQ-005 owns access
  eligibility; MOVE-REQ-013 distinguishes stacked occupancy. This discussion
  does not re-open that scope or adopt infinite depth.
- Decision `0212-the-second-level.md` records the demo's straight ramp/stair
  links, height-aware separation checks and level-specific rendering. It
  explicitly leaves production MOVE-G01–05 open and labels spacing a candidate.
  Reuse those concepts without treating their constants as a final world model.
- `godot/demo/tunnel/tunnel_plan.gd:52` describes the current straight,
  two-point link and its first-to-second-level restriction. Turning stairs,
  spiral stairs and generalized origin/destination levels require additional
  geometry and traversal contracts; they are not already supported by new art.
- Excavation and connector materials remain priced through the adopted
  physical cut ledger and actual recipes. A floor opening, landing or shaft
  cannot be a free space creation shortcut. Production save/load must retain
  cross-level project identity, reservations, partially completed cuts and
  in-progress traversals.
- Existing demo code is not evidence that all furniture/access envelopes are
  currently integrated into link placement. The stated requirements above are
  future acceptance checks, not a claim of current compliance.
- `godot/demo/burrow/room_view.gd:533` currently derives a whole room's floor
  from its main level, and `fixture_view.gd:356` places fixtures using that same
  level floor. Split-level sections need a shared actual-floor model across
  those consumers and the simulation; moving only the visible floor mesh cannot
  satisfy D06.

## Setting evidence and adaptation boundaries

The following records were retrieved from the supplied content library. They
support the architectural vocabulary, not dimensions or gameplay balance:

| Qualified source | Library locator | Relevant evidence |
| --- | --- | --- |
| `redwall::RW-PLACE-cavern-hole` | Blocks 651–3729; `index-1403_split_005.html` block 188 through `index-1403_split_018.html` block 219 | Domestic gathering/dining space below Great Hall stairs, connected to kitchens |
| `redwall::RW-PLACE-dormitory-and-top-passage` | Blocks 651–1881; `index-1403_split_005.html` block 188 through `index-1403_split_013.html` block 125 | Bedrooms, spiral stairs, upper passage and loft hatch |
| `redwall::RW-PLACE-bell-tower-and-belfry` | Blocks 3656–3728; `index-1403_split_018.html` blocks 146–218 | Spiral stair and practical timber structure |
| `long_patrol::LP-PLACE-redwall-bell-tower` | Blocks 1541–3012; `Jacques, Brian - Redwall 10 - The Long Patrol.htm` blocks 1541–3012 | Stair access, beams and a rope ladder used in rescue |

These are broad catalog locators, not measured canonical plans or claims that
the proposed underground layouts occur exactly as drawn. Earth/timber step
construction and ramps also have an existing demo precedent in decision 0212.
The proposed compact stairwell and fixed ladder/hatch combinations are authored
game applications; their shape and material details still require asset briefs.

## Future verification

Test valid stacking; a bed/stove/wall on the other floor; free endpoints with
an obstructed stairwell between them; blocked use space beside a free opening;
insufficient headroom/support separation; overlapping pending projects; a draft
that becomes stale; and placing furniture after a stair project is confirmed.
Also test upward planning, rotated/turning connections, room expansion beside
an existing stairwell, and every level crossed by a longer connection if that
connector type is adopted.

Exercise real residents and carried loads, construction/hauling dependencies,
interruption, save/load at incomplete phases and safe cancellation/removal.
Cover every approved connection family, including spiral turns and ladder
grip/step-off transitions; a successful straight-stair case does not verify them.
For fixed pieces, check supported rotations, landing alignment and height
mismatches; verify that changing material or previewing another floor cannot
change dimensions, clearance or tread/rung spacing.
Exercise raised and sunken sections inside one room, matched and mismatched
short stairs, obstructed landings, reduced headroom, and a room above/below.
Check furniture spanning a height boundary without valid support, an object on
a reachable raised section, an isolated section, construction interruption and
save/load. Verify that curved section edges and their vertical faces meet the
main floor cleanly and that hidden levels do not alter picking or reachability.
Exercise section painting, erasing and boundary changes with rounded,
straight-sided and concave shapes; revalidate stair fit and access after edits.
Check suggested entrances on curved and concave walls, repositioning beside
stairs/furniture, edits that invalidate the suggested passage, and rooms with
no reachable construction approach. Confirm that previews leave geometry,
inventory and work queues unchanged, and that commit revalidates stale plans.
Verify a completed open entrance with no automatic door, later door placement
in either furnishing mode, incompatible opening dimensions, and door clearance
blocked by a nearby shelf or stair landing. Installing a door must not duplicate
the already completed opening's excavation or disturb a neighboring room.
Plan the same additional connection from both directions and compare the
accepted opening, passage, physical cut set, resource accounting and completed
topology. Cover invalid joins, already paid cuts, partial work and cancellation;
changing tools must not bypass validation or reset the physical site ledger.
Exercise an alteration that preserves a valid occupied room, one that invalidates
the room's services, one that blocks its only exit and one whose work area cannot
be safely separated. Verify work waits where needed, unaffected valid use can
continue, residents/goods are retained, and no furniture moves automatically.
Cover a route becoming blocked after confirmation, pause/resume, cancellation
and save/load without losing the distinction between completed and unfinished
space or enabling an unfinished route.
Capture both endpoint views and a section view with the real HUD at 1280×720.
Check mesh openings and material continuity on each floor, including partial
excavation. Numerical dimensions, supported depth bounds and performance
qualification remain to be specified and measured.

No Godot tests or fresh runtime captures were run for this planning slice.
