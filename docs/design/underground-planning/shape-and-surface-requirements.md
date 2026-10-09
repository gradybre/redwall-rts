# Underground shapes and surfaces — planning slice 1

2026-10-02. D01 and D02 are approved as player-facing design direction. The specific
tool examples and technical approaches below are proposals, not completed
implementation, numerical balance decisions or replacement owner contracts.
See the [working agreement](README.md) for those approvals and later decisions,
including D17's contextual blueprint during construction, D22's optional
furniture outlines during room sizing, D23's worker renovation of finishes
and D25's whole-surface material choices. D26 adds amendments to unstarted room
areas during construction; D27 safely pauses the affected project during
revision. D28 resolves unapplied changes before leaving that revision.
The later [levels and connections slice](levels-and-connections.md) adds
cross-level openings, landings, clearance and protection against furniture or
walls on other floors; its requirements also apply to surface generation here.

## Approved intent

Use grid-based room painting with predictable edits and organic boundaries.
Offer multiple appropriate shape tools and a tool suited to tunnels. Do not
limit the player to oval/circular rooms. Room surfaces must suit their use,
maintain appropriate material scale and cover the actual room/shell geometry
without unintended overshoot or gaps.

Each room type suggests a coherent, appropriate wall/floor/ceiling treatment.
The player can choose compatible alternatives; changing materials must retain
the approved boundary fit and physical texture scale. D25 uses one floor
finish, one wall finish and one ceiling finish per room, without local material
painting. The exact material catalog and compatibility rules still need definition.

The user's staged construction workflow remains unchanged: confirm a room
blueprint, excavate it with workers, leave it empty, then order compatible
furnishings. D08 approves a single room project containing visible excavation
and selected surface-finishing stages. The player confirms the blueprint and
materials together; completion leaves the finished room empty and ready for
separately ordered furnishings.

D09 approves grid-based placement and rotation of those furnishings, with
footprint and access guides. [Furnishing and room use](furnishing-and-room-use.md)
requires that placement use the finished room boundary and actual floor heights.

D18 makes the selected type permanent once the room is built. Clearing its
furniture does not change that type. A different type requires removing the
actual room and selecting, laying out and constructing a new room before
furnishing it. This keeps the shape tools flexible within the selected type;
it does not approve fixed prefab layouts. D19 requires real backfilling to
solid ground as part of removal, then excavation and construction of the new
plan. The old completed shell/finishes cannot stand in for the replacement.

D06/D07 also approve painted raised/sunken sections with supported height
choices and matching fixed short stairs. Their floors, vertical boundaries
and stair joins inherit all the surface-fit and material-scale requirements
here; the section geometry is detailed in the levels and connections slice.

## Proposed tool palette

These are useful starting tools, not mandatory templates or a final room catalog.
All edits should show the resulting boundary before confirmation.

| Tool family | Example use | Proposed behavior |
| --- | --- | --- |
| Rectangle and rounded rectangle | Kitchens, cellars, stores, workshops | Drag extents on the grid; retain useful straight walls; offer rounded corners |
| Circle and oval | Burrow chambers and rounded alcoves | Convenient starting stamps with independent dimensions where applicable |
| Connected add/erase painting | L/T-shaped rooms, bent wings, recesses and irregular chambers | Combine or remove area; validate connected usable space and supported geometry |
| Long rectangle or capsule | Dining/common rooms and larger shared spaces | Form a long axis with straight or rounded ends |
| Tunnel route with width | Corridors between rooms and branches | Draw straight sections and bends along a route; preview the full width, joins and clearance |

The tunnel tool should make junctions and room connections understandable.
Its floor plan and its vertical cross-section are separate: a curved route
does not determine whether the passage has an earth arch, supported profile
or lined vault. Cross-section choice, supported widths, turns and connection
placement require the movement/geometry contract. Do not infer free access
for a body, carried load or stretcher from the existence of a visible opening.

D02 approves room-appropriate material defaults with compatible customization.
Shape suggestions should work with the shared tools; shape convenience must
not restrict every burrow to a circle or every kitchen to one fixed rectangle.
The specific tool examples above remain proposals within D01's requirements.

## Acceptance criteria derived from the approval

| ID | Requirement |
| --- | --- |
| UG-SHAPE-001 | Draw the draft directly on the dirt at its intended location in the selected underground world view. Show the planning grid and resulting boundary there before confirmation; a separate blueprint drawing canvas does not satisfy this requirement (D29). |
| UG-SHAPE-002 | The editor shall support both straight-sided and curved room shapes, including connected irregular shapes, rather than only oval/circular templates. |
| UG-SHAPE-003 | When painting, erasing or resizing, the editor shall keep the displayed usable floor, confirmed geometry and legal placement boundary consistent. |
| UG-SHAPE-004 | The editor shall provide a tunnel-appropriate route tool whose preview shows passage width, bends, junctions and connection openings. |
| UG-SHAPE-005 | If a requested shape is invalid or exceeds the adopted geometry limits, confirmation shall refuse with a specific visible reason rather than silently alter the shape or cut set. |
| UG-SURFACE-001 | When generating a supported shape, floors, walls, ceilings/roofs and the cutaway representation shall derive from the same confirmed geometry and meet at the intended boundaries and openings. |
| UG-SURFACE-002 | Material and surface geometry shall cover their intended region without unintended overshoot, gaps, crossing faces, duplicate interior walls or overlapping coplanar surfaces at joins. |
| UG-SURFACE-003 | When a room changes size, recognizable material features such as stone blocks, floor flags and timber grain shall retain their authored physical scale rather than enlarge or shrink with the whole room. |
| UG-SURFACE-004 | Along curved walls, bends and junctions, materials shall retain credible orientation and scale without stretched bands, abrupt accidental seams or visible projection through adjacent rooms. |
| UG-SURFACE-005 | When an approved expansion changes the boundary, new surfaces shall meet existing surfaces cleanly; resizing shall not unintentionally shift all existing texture detail. |
| UG-SURFACE-006 | When a ceiling/roof is shown, hidden or sectioned, its boundary and intended openings shall remain consistent with the room; a view change shall not modify authoritative walk space. |
| UG-SURFACE-007 | Appropriate material treatments shall preserve the adopted grounded, expressive art direction and make room purpose, entrances and work areas readable at normal RTS distance. |
| UG-SURFACE-008 | Each room type shall suggest a coherent default wall/floor/ceiling treatment and allow the player to choose compatible alternatives; every supported choice shall preserve surface coverage, boundary fit and physical material scale. |

Boundary fit applies to the defined shell, not just a rectangular bounding box.
Open doorways and tunnel mouths are intentional openings, not gaps to seal.
Wall thickness, lining, surface mounds and any deliberate exterior overhang need
explicit envelopes; a rendering shortcut must not occupy a neighboring room
or expose undug earth as usable floor. Underground ceilings and surface roofs
are different surfaces even when the interface groups them as room coverings.

## Material examples for discussion

These are proposed combinations, not a new runtime material catalog:

- Burrow: shaped earth with appropriate timber detailing and a packed-earth or
  compatible timber floor; naturally curved ceiling treatment.
- Kitchen/cellar: appropriate stone or plaster treatment, suitable floor flags
  and a coherent ceiling/vault profile; keep cooking and storage identities
  distinct through actual equipment and service rules.
- Shared/dining room: warm timber and/or masonry with a floor and overhead
  treatment appropriate to the span and setting.
- Tunnel: earth or supported/lined passage treatment, a continuous floor and
  ceiling profile, and clear material transitions at room entrances.

A visual material choice does not automatically grant heat, preservation,
durability or safety bonuses. Material delivery/cost and mandatory support
remain owned by existing rules or later explicit decisions. D08 settles that
the selected finishes share the initial room project; D23 permits later worker
renovation. Exact work dependencies, compatibility and recipes remain to define.
Detailed asset briefs still require book-qualified literary references and
reviewed supplied-image provenance before authoring new art.

### Material coverage controls — approved D25

D25 selects whole surfaces only: one finish for the room's floors, one for its
walls and one for its ceilings. The player may choose each category separately
from compatible options, starting with D02's coherent defaults. The local
material-painting alternative is rejected; do not introduce patch selection,
accent regions or mixed per-tile material choices as part of this plan.

Room shaping and local height painting remain available under D01/D06/D07;
their scope is geometry, not separately painted finishes. The selected finish
must cover its actual surface across the room, including curved/concave edges,
alcoves and relevant split-height surfaces. Keep openings clear and clip to
the owning room's boundaries. Adjacent rooms retain their own selections;
shared structure and each exposed surface need explicit ownership so a wall
choice cannot repaint its other side by accident. Stair/support assets retain
their own compatible catalog treatment and are not silently reskinned.

One selected finish can still contain authored joints, grain and material
variation; it does not require a flat color or a single texture stretched to
room size. Preserve physical material scale, complete coverage and correct
joins under the existing surface requirements. Such authored detail does not
introduce player-painted subregions or new gameplay effects.

D08 installs these selections during the original room project. D23/D24
replace the chosen whole surface category through actual worker renovation
and the reviewed relocation plan. Changing the floor choice alone does not
order replacement walls or ceilings. Safe staged work can temporarily expose
old/new finishes or unfinished surfaces according to actual progress; that
state is not permission to publish a completed mixed-material floor. Keep the
selected target separate from the installed progress in presentation and saves.

| ID | Acceptance criterion derived from D25 |
| --- | --- |
| UG-SURFACE-013 | Room material controls shall provide one compatible finish selection for each of floors, walls and ceilings, applying to its whole applicable room surface; they shall not provide local material painting or independently selected finish patches. |
| UG-SURFACE-014 | A confirmed finish replacement shall target the selected whole surface category without implicitly replacing unchanged categories or adjoining spaces; visible and saved partial replacement shall reflect actual work, and completion shall satisfy the selected whole-surface finish. |

No material catalog, construction recipe, numerical grid or new surface extent
is adopted here. Structural/lining compatibility and exact surface ownership
remain engineering work, with D03's cross-level protection still required.

### Replacing finishes after completion — approved D23

D02 settles initial material defaults/customization. D23 adds a worker
renovation order to replace compatible wall, floor or ceiling finishes while
retaining the room's type and footprint. Changing finishes alone does not
require full room removal/backfill; changing the room type still does under
D18/D19. A renovated kitchen remains the same kitchen.

Renovation needs actual delivery, work and partial-state
accounting. Surface coverage and physical texture scale must hold during and
after replacement, with visible unfinished areas matching committed work.
A material click cannot instantly repaint the completed world. Distinguish
removable decorative finishes from required structural
lining/support; a cosmetic operation cannot bypass ECON-005's restrictions
on removing support from an open void. Changes affecting the structural
envelope need the owning construction contract rather than an assumed skin
swap. Material compatibility, work recipes, recoveries and interruption/save
semantics need definition without inventing quantities or benefits. Check the
full finish/work envelope, including thickness, against furniture, access,
headroom and neighboring levels; retaining the footprint is not proof of fit.

D14's safe continued use and whole-room validity rules still apply. Affected
furniture, stored goods and access must be resolved through the approved
relocation/removal owners, with the actual blocker shown if work cannot
proceed. D24 in [furnishing and room use](furnishing-and-room-use.md) approves a
reviewed, confirmed move-out/return plan for affected portable furniture.
This does not authorize moves outside that plan. Fixed installations still
require deliberate removal
and rebuilding when they obstruct the work. Whole-room invalidity suspends
its services under REQ-SET-129; an unaffected corner cannot bypass that rule.

| ID | Acceptance criterion derived from D23 and existing owner rules |
| --- | --- |
| UG-SURFACE-009 | After a completed room's compatible replacement finishes are explicitly confirmed, workers shall deliver the required materials and perform renovation while preserving the room's identity, type and footprint. |
| UG-SURFACE-010 | Renovation shall validate the actual finish and work envelopes against required support, headroom, neighboring spaces, furniture and protected access; it shall not remove mandatory support from an open void or treat a structural change as an unvalidated cosmetic swap. |
| UG-SURFACE-011 | Affected furniture, goods, occupants, claims and services shall be resolved through their owning rules before conflicting renovation work proceeds; unresolved access, clearing or material requirements shall produce a visible blocker rather than unapproved displacement or deletion. |
| UG-SURFACE-012 | Renovation presentation and saved state shall preserve actual installed finishes, committed partial work and material accounts through interruption, cancellation and reload; they shall not imply instantaneous completion, duplicate recovery or rollback of already performed work. |

This added renovation to the feature plan during design approval. The later
build instruction recorded in the [working agreement](README.md) authorizes
implementation. Reuse the completed first fixture for a focused follow-up check
before extending renovation across the whole material/room catalog.

## Construction and selected finishes — approved D08

Use one player-confirmed room project with visible excavation and surface-
finishing stages, ending in the empty room the user requested. Confirm its
blueprint and selected materials together. Required deliveries and work may
proceed as their dependencies permit; the player does not need another finish
order. Retain material defaults and compatible customization from D02. Furniture
is ordered only after the room project is complete; it is not included by default.

D12 confirms that new room entrances are completed open and doors are ordered
afterward during furnishing. UG-BUILD-003 keeps its existing scope. Entrance
support and the selected surrounding surface finish still belong to the shell;
their coverage and material scale must hold both before and after a door is fitted.

Mandatory structural work is already specified by SET-MOVE-ECON-001, ECON-002
and ECON-003: bracing precedes cutting, and the required structural finish
precedes publication of usable supported space. Its FINISHING phase is not
an optional decorative treatment. D08 does not reorder or remove that work,
double-charge its installed bracing, or redefine unfinished space as usable.
The selected surface treatment may need additional work/materials where its
actual recipe requires them. The material catalog must identify that boundary;
no extra cost, free finish, service bonus or recipe is adopted by this approval.

The project must make progress and blocking reasons understandable:
for example, a safe excavated shell awaiting selected floor materials is
different from a completed room ready for furniture. The exact UI labels,
work dependencies and recipes remain open; D23 settles that later compatible
finish changes use worker renovation.

| ID | Acceptance criterion derived from D08 |
| --- | --- |
| UG-BUILD-001 | When the player confirms a room blueprint and its selected surface treatment, the system shall create one room project that schedules the required excavation, support and finish work according to their dependencies, without a second finish order. |
| UG-BUILD-002 | While the room project is in progress, its world presentation shall show the committed construction progress and its UI shall distinguish working, paused and blocked work from completion. |
| UG-BUILD-003 | The room shall become ready for furnishing only after its required shell, access and selected finish work are complete; completion shall leave furniture and room equipment uninstalled for the player to order separately. |

One player-facing project does not mean one irreversible all-at-once world
transaction. The existing physical phases, inventory conservation, legal work
contacts and cancellation rules still apply. Finishing an empty shell also
does not by itself grant a furnished room's services or capacities.

### Changes during room construction — approved D26

D01/D11 settle editable drafts before confirmation, and D14 settles safe use
during later structural work. D26 permits an amendment to an accepted room
project, limited to unstarted areas and preserving all work already performed.
The alternative of locking its layout until completion/cancellation was not
selected. This changes the remaining room footprint, not its selected type.

An amendment needs a preview of its actual geometry, changed
work/material quantities, access and affected dependencies before confirmation.
It must keep the selected room type and D25's finish choices; it cannot stretch
fixed stairs or silently shift an entrance/landing. Candidate additions and
removals must leave valid access, supports and a constructible whole plan.
An apparently untouched area is not automatically free: inspect reservations,
deliveries, physical-site history and other projects through their owners.

Define exact phase/work eligibility and atomic amendment transactions with
the construction owner. Started bracing, partial cutting, installed support,
finished geometry and committed work cannot be erased by editing the drawing.
Normal removal/backfill work remains necessary where already worked space
must physically change. Revalidate at confirmation if workers have progressed
since the preview; refuse a now-ineligible amendment rather than reset progress.
Uncommitted draft edits alone have no authoritative effects.

Amendments retain ECON-003/005's stable physical ledger, real refunds,
reachable returned lots and cancellation semantics. Cancelling a project is
not undoing excavation; a later project must rebind retained physical state
without creating a second virgin-earth source. Dependency, save/version and
UI details remain engineering work. No new refund rates, handling constants
or implicit pause of all construction are approved.

| ID | Acceptance criterion derived from D26 and existing owner rules |
| --- | --- |
| UG-BUILD-009 | During room construction, the player shall be able to propose additions/removals limited to unstarted areas, retaining the selected room type, finish choices and all started or completed physical work. |
| UG-BUILD-010 | An amendment preview shall identify changeable versus worked areas and show the actual changed geometry, work/material requirements, access and dependencies; editing the draft alone shall not mutate authoritative geometry, accounts or jobs. |
| UG-BUILD-011 | Confirmation shall revalidate work progress, physical history, claims, deliveries, support and access before accepting an amendment; a stale or invalid amendment shall refuse without partially changing the accepted plan or erasing performed work. |
| UG-BUILD-012 | Accepted amendments and their interruption/save/cancellation handling shall preserve physical-site identity, actual goods, valid claims and committed progress, applying the existing owners to cancelled unstarted work without duplicate refunds, output or excavation yield. |

### Work during plan revision — approved D27

D27 selects a safe pause for the affected room project when the player invokes
Revise, leaving the rest of the settlement under its existing time controls.
After the pause is acknowledged, workers no longer consume the unstarted area
while the player revises it. Continuing this project's construction during revision
was not selected. This is a project command, not a new global pause reason.

A project pause is a real control command, separate from editing the visual
draft. Selection, hover and blueprint visibility must remain presentation only
under UG-VIEW-004. The UI must disclose the effect of Revise, show pending
safe-stop versus actual pause, and retain normal progress/WIP/worker/lease
behavior from the construction owner, including REQ-SET-137 and ECON-005.
It cannot teleport a worker, erase work committed before acknowledgement or claim a
stable preview before the project has reached its safe paused state.

Releasing an editing hold after accepted confirmation or explicit discard
must not override a pause already present or one the player adds separately.
Actual delivery/access blockers remain blockers; invalid confirmation retains
the draft and its editing pause. Leaving the tool, saving a draft, cancelling
the underlying project, interruption and reload need explicit
edit-session/hold ownership so a forgotten editor cannot permanently suspend
work or incorrectly resume it. These details are engineering/design work;
D27 chooses the player-facing behavior, not a new pause schema or save format.
Revalidate on confirmation because other world state can change while the
player edits. Shared passage/stair projects and unrelated work must not acquire
this room's editing pause merely because the room depends on them.

| ID | Acceptance criterion derived from D27 and existing pause rules |
| --- | --- |
| UG-BUILD-013 | Invoking Revise for a room under construction shall request a safe pause for that project without changing global time controls or pausing unrelated projects; ordinary selection and preview visibility shall not issue that command. |
| UG-BUILD-014 | The revision UI shall distinguish a requested stop from an acknowledged pause, preserve actual work/materials and apply the construction owner's worker/lease rules; work committed before acknowledgement shall remain authoritative. |
| UG-BUILD-015 | Accepted amendment or explicit revision discard shall release only the corresponding editing pause, preserving independent player pauses and real blockers; failed confirmation shall not release it or falsely resume work. |
| UG-BUILD-016 | Edit-session and project-pause ownership shall remain consistent through interruption, cancellation and save/load, with live generation-validated project references; recovery shall not orphan a pause, resume an independently paused project or reset physical progress. |

### Leaving an unfinished revision — approved D28

D28 requires resolving unapplied changes when leaving this revision editor:
offer Apply changes, Discard changes or Keep editing. Apply must succeed under
D26's current validation before the editor can treat the amendment as committed;
Discard drops only the new draft, retaining the previously accepted plan and
all physical work. Both release only the editing pause under D27. Keep editing
retains the draft and hold. Freely switching away while retaining a pending
draft and its editing hold was not selected. Rejected Apply must retain the
draft, explain the actual failure and preserve the editing pause; clicking the
button is not proof of authoritative acceptance.

Scope this to leaving a changed room revision, not panning, inspecting another
level within the same edit, cancelling the current brush stroke, changing a
normal selection outside revision or switching D10 furnishing modes. An
unchanged revision does not require a lost-changes prompt; departure releases
only its editing hold, including safe handling of a stop still awaiting
acknowledgement. Escape/focus handling must respect the
owning one-layer dismissal rules and not apply/discard a draft through an
unrelated click. Dismissing the exit prompt cancels departure and returns to
editing; it does not discard the revision or trigger the original background
action. Saving or reloading cannot silently confirm
the draft, erase it, override a manual pause or lose the reason work is held.
Exact control registration and draft/hold persistence remain owner work.

| ID | Acceptance criterion derived from D28 and existing UI rules |
| --- | --- |
| UG-BUILD-017 | Leaving a room revision with unapplied changes shall offer Apply changes, Discard changes and Keep editing; no choice shall be inferred from an unrelated click, selection change or prompt dismissal. |
| UG-BUILD-018 | Apply shall leave the revision only after authoritative acceptance, Discard shall remove only the unconfirmed edits, and Keep editing or prompt dismissal shall retain the draft and editing pause; rejection shall show its blocker without releasing the hold or partially applying the amendment. |
| UG-BUILD-019 | Leaving an unchanged revision shall require no lost-changes prompt and shall safely release only its editing hold; every exit path shall preserve independent pauses, actual blockers, committed work and the owning one-layer input/focus rules. |

## Room removal and rebuilding — approved D18/D19

The old room retains its type until actual removal. Workers safely clear its
removal scope and backfill it with delivered earth, restoring solid ground.
The player then selects and lays out a new room, whose excavation, support and
selected finish work must complete before furnishing. Show real closure and
construction progress rather than an instantaneous replacement of one floor
texture with another.

The physical site keeps its history after the room identity is retired.
ECON-005 couples support removal, funded backfill and salvage publication;
re-digging BACKFILLED ground withdraws embedded earth. Render the actual
committed state, including partially backfilled boundaries, without covering
adjacent rooms, hiding required support early or publishing a usable new floor
before its construction commits. Removal scope and finished-surface seams must
respect the same cross-level geometry used for placement and access.

| ID | Acceptance criterion derived from D19 and existing excavation rules |
| --- | --- |
| UG-BUILD-004 | Completed removal of a built underground room shall require real backfilling of its removal scope to solid ground; an open cavity or room-type reset shall not count as completion. |
| UG-BUILD-005 | Closure shall resolve affected occupants, goods and claims, maintain legal work access and protect other rooms, levels and connections; installed support shall remain until the coupled backfill/salvage transaction commits. |
| UG-BUILD-006 | Backfilling shall consume actually delivered earth and require legal salvage capacity under the existing owner rules; missing resources or access shall block work with a specific reason. |
| UG-BUILD-007 | Removal and re-digging shall preserve the physical-site ledger, committed partial work and material accounts across cancellation and saves; cutting backfilled ground shall reclaim its embedded earth rather than generate a new virgin source. |
| UG-BUILD-008 | A replacement room shall begin excavation of the removed room's space only after removal/backfilling is complete, then follow its newly confirmed plan and the adopted brace/cut/finish sequence before becoming ready for furnishing. |

Room-finish teardown recipes, scope boundaries, support ownership and exact
retirement/publication transactions remain to specify. These requirements do
not change cancellation of an unfinished excavation into automatic backfill.

## Excavation blueprint visibility — approved D17

D08 already requires visible committed progress. The initial review's UG-10
identifies the demo's six-stage room reveal and completion-time additions;
arbitrary room shapes need readable working faces, required support, spoil
handling and finishing that follow the actual project state. This does not
reopen the adopted world art direction or allow presentation to invent work.

D17 selects a full translucent plan while the project is selected or edited,
with only a subtle planned boundary otherwise. This retains a reference for
the intended extent while keeping the actual work readable. Planned space
must remain distinguishable from completed geometry; workers, supports, spoil
and unfinished faces must not disappear under an opaque preview.

The full overlay must remain inspectable through the project's existing
selection path, including keyboard/list selection. Deselecting a project cannot
hide its existing warnings or make blocked work look complete. Layer/cutaway
visibility and picking still follow the owning controls; a plan on one level
must not be mistaken for an occupied floor or object on another. Overlays may
show the player's planned outline into unexcavated space, not hidden contents
or geology that have not been discovered.

Exact opacity, line weight and selection treatment require a later 1280×720
visual check. D17 does not change roof controls, physical completion or worker
simulation; the approved world art and reduced-motion rules remain in force.

| ID | Acceptance criterion derived from D17 and existing UI rules |
| --- | --- |
| UG-VIEW-001 | While an unfinished room or tunnel project is selected or being edited, its full translucent plan shall be visible over its actual dirt/world location within the active view; otherwise its presentation shall retain a subtle planned boundary around the visible work. Camera and selected-level changes must preserve the same world placement (D29). |
| UG-VIEW-002 | The plan overlay shall distinguish intended space from committed construction and shall keep the actual work and required warning/blocker information legible. |
| UG-VIEW-003 | Blueprint visibility shall respect the selected layer, cutaway and discovery rules; it shall not expose undiscovered contents or make geometry on another level an accidental selection target. |
| UG-VIEW-004 | Selecting, editing the draft presentation or hiding a plan overlay shall not itself change authoritative work, inventory, geometry or routes; world changes shall require their normal explicit commands. |

## Blueprint sizing guides — approved D22

During room blueprint editing, offer optional illustrative outlines of
compatible equipment and its required access space. They help the player
judge a useful size before committing to excavation. They are not furnishing
orders or prescribed locations; the player still furnishes the completed
empty shell through D09/D10. Hiding the examples leaves the room's ordinary
boundary, dimensions and validity information available.

| ID | Acceptance criterion derived from D22 |
| --- | --- |
| UG-VIEW-005 | While drawing a room blueprint, the player shall be able to show or hide clearly labeled example furniture outlines and their access space without hiding ordinary room geometry or requirement information. |
| UG-VIEW-006 | Examples shall use compatible catalog footprints, supported orientations and actual access requirements, revalidated against the draft boundary, local floor heights and protected connections after relevant edits; no scaling, clipping or blocked approach shall be presented as valid fit. |
| UG-VIEW-007 | Sizing examples shall create no furnishing orders, authoritative reservations, costs, inventory changes, fixed sockets or service grants and shall not become items in the post-completion furnishing draft. |
| UG-VIEW-008 | The guide shall distinguish an illustrative arrangement from proof of full room validity, retain applicable count/area/access/service information and indicate when missing catalog or access data prevents establishing fit. |

Rendering and arrangement generation remain to design. Existing layer,
discovery, reduced-motion and 1280×720 readability requirements also apply.
The guide must not reveal an undiscovered obstruction or contents; it uses
the information the planning tool is permitted to expose. These overlays must
remain distinguishable from confirmed projects and actual furniture.

## Engineering implications — proposed, not yet an implementation design

- Generate/clip surfaces to the actual footprint, including concave corners.
  Scaling one rectangular floor or one circular shell cannot meet the requirement.
  A single center triangle fan is not generally valid for arbitrary concave
  footprints; use a representation/triangulation that preserves the valid region.
- Preserve a shared boundary/opening description for surface generation,
  clipping, picking and navigation. Visual smoothing must not introduce
  unpriced traversable space or conceal a blocked passage.
- Keep texture scale in physical units. The demo already samples earth grain
  in world coordinates in `godot/demo/tunnel/bore_surface.gdshaderinc:113`
  and `:183`. That is reusable behavior, not proof that every material meets
  the expanded-shape contract.
- Ordered patterns need particular care. The current stone wall mapping uses
  `p.x + p.z` at `bore_surface.gdshaderinc:174`; it does not measure distance
  along a curved wall. Its pattern spacing therefore varies with wall direction.
  A candidate solution is surface-distance coordinates for ordered courses and
  compatible world/surface projection for irregular earth. The final algorithm
  and seam policy remain an engineering decision.
- The current floor builder fans vertices around a round room's middle
  (`godot/demo/burrow/room_mesh.gd:82`). Extending it to L/T-shaped rooms needs
  actual geometry work, not different texture scaling alone.
- Cache/rebuild only affected geometry within measured budgets. Persistent
  authoritative geometry stays integer-based and deterministic; render meshes,
  material coordinates and view cutaways must not decide gameplay outcomes.

The adopted excavation price/conservation lattice is 1 m³, defined in
`docs/underground_economy_hazard_amendment.md:31`. The painting grid is not
automatically that lattice or the GDD's older building-tile grid. Their mapping
is unresolved engineering work. Finer geometry cannot silently create free
usable space, change paid excavation or duplicate spoil.

## Verification to include in the eventual implementation plan

Use the same material on minimum/maximum supported sizes and on a rectangle,
rounded rectangle, round room, concave L/T shape, irregular alcove, straight
tunnel, curved tunnel, branch junction, room connection and level transition.
Exercise add/erase, resize and supported expansion. Check partial excavation
as well as the completed shell, so its visible front also respects actual cuts.
Check that each room type offers its appropriate default treatment and that
supported material substitutions preserve the same geometry and coverage.
For D25, change each surface category independently on a curved/concave room
with a raised section and an adjacent room. Check complete coverage, preserved
physical scale, unchanged other categories and no neighbor/other-level spill.
Verify that local material painting is absent while shape/height painting still
works. Interrupt/save a whole-floor renovation partway through and confirm that
its old/new progress is preserved, then that completion covers the whole floor.
Verify D08's complete sequence, a pause during each relevant stage, blocked
finish deliveries, cancellation and save/resume. A supported but uncompleted
room project must not be reported ready for furnishing, finish work must not
require a second player order, and completion must not install furniture.

For D26, add and remove unstarted areas in a partly constructed room and
verify the retained geometry/progress and actual work/material changes. Refuse
edits intersecting started bracing, partial cuts, installed support, a protected
landing or dependent access. Include an unstarted area with existing deliveries
or claims and exercise the proper owner transactions rather than assuming it
is empty. Advance work between preview and confirmation and verify a stale
amendment refuses without partial effects. Save/load before and after acceptance
and check stable cut identity, no duplicated refunds/output and a valid resumed
plan. Repeat confirmation to verify its transaction cannot apply twice.

For D27, invoke Revise during active work and verify requested/acknowledged
pause states, retention of progress/materials and lawful worker/lease release.
Selection/hover alone must leave construction running. Exercise a worker commit
before pause acknowledgement and an external access/occupancy change afterward;
both must be reflected truthfully at confirmation. Confirm, discard and fail
validation with and without an independent manual pause, including a pause
added during editing. Only the editing hold may release. Other projects and
global speed/pause state remain unchanged. Save/load and interrupt around pause
request, acknowledgement and amendment acceptance without orphaned holds or
duplicate commands. Include underlying project cancellation and slot reuse.

For D28, leave a changed revision by each supported editor-exit path and
exercise all three choices. Include rejected Apply, Escape/prompt dismissal,
an unchanged edit, departure before the safe-stop acknowledgement and a manual
pause added while the dialog is open. Verify no background click-through,
double action, lost draft, partial amendment or orphaned editing hold. Saving
and reloading with a pending revision must preserve its accepted plan, draft,
real progress and valid pause ownership without silently applying/discarding
changes. Inspect keyboard focus, labels and all actions at 1280×720.

For D23, renovate a completed room using a compatible finish and verify its
identity, type and footprint remain unchanged. Inspect curved/concave joins,
finish thickness and constant texture scale. Exercise a blocked material
delivery, obstructing furniture, a protected stair approach, a neighboring
level and an attempted structural-support removal. Check valid continued use
versus whole-room service suspension, then interrupt/cancel/save at meaningful
replacement stages without duplicating materials or restoring old progress.
Furniture clearing follows D24's reviewed move-out/return plan. Test a missing
temporary destination, a changed return position, storage unloading on both
legs where required, and cancellation/save during each stage. Check that the
coordinated operation cannot silently include fixed-installation demolition.

For D22, exercise equipment beside curved/concave edges, a changed local floor
height, a blocked approach and a protected stair landing. Revalidate after
each edit without shrinking or clipping the examples. Toggle the guide and
check unchanged authoritative state, resources and orders; complete the shell
and verify no example becomes a furniture order or retained furnishing draft.
Show missing data honestly and keep full room requirements readable with the
guide visible or hidden. An example fitting does not grant a room service.

For D17, compare selected and unselected projects at close and normal RTS
distances, including multiple adjacent plans, curved tunnels, overlapping
screen projections from different levels, and a paused/blocked excavation.
Check keyboard/list selection, actual-work legibility, visible warnings and no
discovery leakage. Repeated selection, zoom and cutaway changes must leave
equal-tick authoritative state unchanged. Review the plan against the real HUD
at 1280×720, including reduced-motion and color-independent status cues.

Geometric checks should verify coverage, openings, shared edges, triangle
containment, clearance and agreement with the confirmed footprint. Runtime
visual checks should inspect constant material scale, edge contact, seams,
lighting leaks, cutaway changes and near/far camera views at 1280×720 and higher
resolutions. Check repeated edits and reload once persistence exists. Measure
the integrated workload at the 256-resident cap; do not declare performance
from visual correctness alone.

No new tests were run for this planning slice. These are future acceptance
criteria, not claims of current implementation or verification.
