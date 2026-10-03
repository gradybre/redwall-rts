# Underground furnishing and room use — planning slice 3

2026-10-02. D09 is approved as player-facing design direction: the player
places and rotates compatible furniture on a grid, with footprint and access
guides. D08 requires the empty room project, including its selected finishes,
to be complete first. D10 approves both confirmation modes with a selector for
the current room. D12 adds room entrance doors to post-completion furnishing.
D15 approves worker relocation of portable items and dismantle/rebuild for
fixed installations. D16 requires unloading affected goods before relocation,
with normal hauling for subsequent restocking. D18 fixes a completed room's
type; another type requires removal and a newly selected room layout/build.
D19 requires backfilling the removed room to solid ground before replacement.
D23 allows worker replacement of compatible room finishes while retaining the
room type and shape; D24 coordinates portable furniture move-out and return
through a reviewed renovation plan.
See the [working agreement](README.md) for the approvals.
This is planning, not implemented behavior.

## Approved placement experience

- Choose an item appropriate to the selected room, then position and rotate
  its preview on the placement grid. Display its occupied footprint and the
  space needed to install and use it as distinguishable guides.
- Validate against the actual finished boundary, including curved or concave
  walls, lining thickness, pillars, openings and other objects. A room's
  rectangular bounding box is not its legal furnishing area.
- Use the floor's real height and support. A raised alcove or sunken area must
  remain reachable through its actual connection, and an item cannot float,
  intersect a riser or gain access merely from sharing the room's identity.
- Keep doorways, stair landings and required circulation usable. Check already
  installed objects and confirmed projects as well as the proposed placement.
- Show a specific refusal reason, for example "bed blocks stair landing" or
  "shelf access is unreachable", with the affected area highlighted.
- Let the player choose layout preview or individual order placement for the
  current room, with the active mode visible while furnishing it.
- Offer compatible doors for completed open room entrances. Validate the
  opening, frame, moving parts and approaches as well as nearby furniture;
  a door order does not silently enlarge its opening or remove an obstruction.
- Offer a distinct Move action for eligible portable furnishings. Preview the
  destination and transport access; workers relocate the actual item. Fixed
  installations require deliberate dismantling and rebuilding orders.
- Before relocating storage furniture, haul affected goods to valid available
  storage and resolve its outstanding claims. Move the empty furnishing, then
  restock normally; a blocked unloading step must explain what is missing.
- For renovation, preview affected portable furniture and its temporary/return
  placements before confirmation, then coordinate real worker moves with the
  finish work. Fixed installations still need deliberate removal/rebuilding.
- Keep the built room's type when furniture is cleared. Replacing a kitchen
  with a bedroom requires removing the kitchen room, selecting Bedroom and
  constructing a new valid layout before bedroom furnishing becomes available.

The existing controls in `docs/ui_ux_controls.md:341`–`:346` commit quantized
placement and use 90-degree rotation, with mouse and keyboard paths. D09 does
not change those increments or adopt a finer numerical grid. The expanded
geometry-to-grid mapping remains an owner contract; all committed positions
and placement legality must remain integer-based and deterministic.

## Acceptance criteria derived from D09/D10/D12/D15/D16/D18/D24 and existing owner rules

| ID | Requirement |
| --- | --- |
| UG-FURN-001 | While placing furniture, the tool shall show the placement grid, the selected item's occupied footprint and its required installation/use access space, updating them when the player moves or rotates it. |
| UG-FURN-002 | Furniture orders shall require the completed empty room from D08 and an item permitted by that room's catalog rules. |
| UG-FURN-003 | Placement shall validate the item's full footprint, occupied volume, support and required access against the finished room geometry and actual floor heights. |
| UG-FURN-004 | Placement shall preserve required access to existing usable furniture, doors, stairs and exits, and shall consider confirmed unfinished projects. |
| UG-FURN-005 | When an order is confirmed, the system shall revalidate current geometry and claims before committing its placement; a stale valid preview shall not authorize an overlap or blocked required route. |
| UG-FURN-006 | Installation and later use shall require reachable work/use contacts through the actual connected space; a direct line from the room center shall not substitute for a legal route around furniture and height changes. |
| UG-FURN-007 | When placement is invalid, the UI shall identify the failed condition in words and highlight the relevant object or region. |
| UG-FURN-008 | The furniture tool shall offer both layout-preview and individual-order modes with a visible selector scoped to the current room; changing one room's mode shall not change another room's mode. |
| UG-FURN-009 | In layout-preview mode, the player shall be able to arrange one or more items before explicit confirmation; draft edits shall not create construction orders, authoritative space claims or inventory mutations. |
| UG-FURN-010 | In individual-order mode, each committed valid placement shall submit its furniture construction order through the existing command and project rules, including paused-command handling. |
| UG-FURN-011 | Changing the furnishing mode shall not implicitly confirm or discard draft items, cancel confirmed orders, reset work or change material accounts; committing or discarding a retained draft shall require its corresponding explicit action. |
| UG-FURN-012 | Both modes shall apply the same room eligibility, footprint, support and access checks; confirmed orders shall retain their state when the room's mode changes. |
| UG-FURN-013 | A room entrance door shall be ordered after room completion through either furnishing mode and shall require a compatible completed opening, its actual recipe and valid installation/use clearance. |
| UG-FURN-014 | When the player orders Move for an eligible portable furnishing, workers shall handle, transport and set the existing item at the validated destination; fixed installations shall retain the dismantle/rebuild path. |
| UG-FURN-015 | Relocation shall require a route that accommodates the actual transported item and worker/load profile through openings, turns, stairs, landings and local height changes; an empty worker's route shall not prove that the furniture fits. |
| UG-FURN-016 | Before handling and at destination commit, relocation shall revalidate the live item, project conflicts, destination room compatibility, support, occupancy and required access; an occupied or in-use item shall not be picked up. |
| UG-FURN-017 | While an item is being handled or transported, it shall grant no installed services; destination services shall require completed placement and the owning room's validity rules, without simultaneous effects at the source. |
| UG-FURN-018 | Relocation shall conserve the item's identity and goods accounting without teleporting, creating a duplicate item or granting demolition salvage; it shall never silently replace a blocked Move with demolition. |
| UG-FURN-019 | When relocation is interrupted, cancelled or restored from a save, it shall preserve the actual item location, progress and valid claims without duplicating, discarding or instantly returning the item; unavailable work shall show its blocker. |
| UG-FURN-020 | Before pickup of a portable furnishing that owns storage, workers shall unload its goods by real hauling to eligible reachable storage with available capacity, and its outstanding reservations shall be resolved through their owners; relocation shall not carry it loaded or erase claims. |
| UG-FURN-021 | When a capacity-contributing fixture is relocated, the owning container's contents plus reservations shall fit its remaining available capacity throughout the move; only goods needed to satisfy that constraint shall require relocation, and the fixture shall not contribute capacity at both endpoints. |
| UG-FURN-022 | If required unloading lacks reachable eligible storage or cannot resolve a conflicting claim, relocation shall wait with a specific blocker rather than discard goods, exceed storage capacity or perform an unauthorized transfer. |
| UG-FURN-023 | After destination placement makes storage available, restocking shall use real hauling and applicable storage ownership/eligibility rules; relocation, interruption and restocking shall conserve goods and claims without recreating the source quantities. |
| UG-FURN-024 | A completed room shall retain its built type when furniture is removed, services become invalid or the game is saved and reloaded; emptying or refurnishing it shall not change its type or authorize equipment otherwise forbidden by that type. |
| UG-FURN-025 | Replacing a built room with a different type shall require actual removal of the old room followed by selection, layout, confirmation and construction of the new type; relabeling or preserving the old room as the new completed shell shall not satisfy that sequence. |
| UG-FURN-026 | Before room removal changes occupied space or services, it shall safely resolve affected occupants, goods, furniture, jobs and claims and protect neighboring rooms, other levels and required access; clearing furniture alone shall not count as removing the room. |
| UG-FURN-027 | A replacement room shall require its own compatible completed shell and access before furnishing under D08–D10; old room references, service grants and installed status shall not silently transfer to the new room. |
| UG-FURN-028 | Before coordinated renovation is confirmed, the player shall be shown affected portable items, legal temporary positions, intended return placements and interrupted uses, with the ability to review and revise those destinations. |
| UG-FURN-029 | A confirmed coordinated renovation plan shall order required unloading, worker relocation, finish work and return placement according to their dependencies, using the actual item identities and D15/D16 movement, goods and service rules. |
| UG-FURN-030 | Temporary and return placements and their routes shall be revalidated against actual room compatibility, load fit, changed finish envelopes, occupancy and protected access; unavailable placement shall wait with a visible blocker rather than silently substitute demolition or an unapproved destination. |
| UG-FURN-031 | Coordinated renovation shall preserve each item's actual location, claims, completed transfers and work progress through interruption, cancellation and save/load without instant return, duplication or rollback of committed finish work. |

Room compatibility is separate from grid fit. The user's kitchen-only oven
example does not itself ban a domestic heating hearth from a home; cooking
equipment and heating fixtures need their actual catalog identities and rules.
The full room/item compatibility matrix remains to author against the GDD.
Completing a shell or placing a preview grants no beds, storage, cooking slots,
comfort or other services. Installed contents, access and the owning room
validity rules determine those effects.

D14 permits continued use during structural alterations only where the work
area, access and room/service validity allow it. A localized closure does not
override whole-room validity checks. Existing furniture and goods remain in
place until the player orders a valid action affecting them.

## Furniture delivery and installation — existing contract

`docs/game_gdd.md:665` requires construction materials to reach the project
container before build work. REQ-SET-124/125 specify delivery and consumption
into the project as work begins. Its furniture table supplies the existing
materials and work; this discussion does not invent a workshop-made furniture
inventory, a portable finished-object catalog or new recipes.

The plan shall retain those rules: confirmation creates construction work,
workers deliver real materials through valid routes, and the fixture becomes
usable only after installation commits. Presentation of bundles, tools and
partial assemblies should express actual delivery/work progress. Exact visual
stages and assets remain proposals requiring their own briefs and verification.

## Furniture confirmation — both modes approved under D10

Provide a room-specific selector with two choices. Proposed concise labels are
**Plan layout** and **Place individually**; exact wording and layout still
require UI design at 1280×720.

- **Plan layout:** arrange and revise furniture previews, inspect the combined
  footprint/access, then explicitly confirm the layout. It can contain one
  item or several. Nothing starts merely because a preview is positioned.
- **Place individually:** each valid placement submits its construction order.
  Once accepted by the simulation, it can enter the existing delivery/build
  workflow while the player continues arranging other items.

A selector change only changes how subsequent placements are handled. Existing
orders keep their progress, workers and accounting under their normal rules.
Unconfirmed previews remain drafts and require an explicit confirm or discard
action; they cannot turn into paid work because the player selected the other
mode. Retained drafts must be visibly distinguishable from confirmed work and
must be revalidated after changes elsewhere in the room.

Recommended UX details, not additional user decisions: start a new room in
Plan layout, remember each room's last selection when revisiting it, and show
a clear indicator when the room retains unconfirmed previews. Exact draft
retention across leaving the tool/save/load, confirmation semantics, atomic
validation for a grouped layout, construction dependencies and group pause/
cancel behavior remain to specify. Persisted UI state must be keyed to a live
room identity so slot reuse cannot transfer another room's draft or preference.

Both modes use D09's grid and check the actual combined occupancy and access.
Drafts do not debit inventory, reserve authoritative space or start workers.
Grouping orders in the UI does not replace the GDD's per-furniture construction
projects or its material/refund accounting. A mode change is not a construction
pause command and cannot undo already accepted orders.

## Implementation gap and engineering follow-through

### Rearranging installed furniture — approved D15

Provide a separate worker relocation action for catalog-approved portable
furnishings, while fixed installations use the existing dismantle/rebuild path.
Small tables or chairs are candidate portable examples; a masonry cooking
installation is a candidate fixed example. These classifications remain
proposals, not an adopted portability catalog. The player approved relocation
as an additional action, not dismantle/rebuild for every rearrangement.

DEC-043 in `docs/setting_decisions.md:1084` and decision
`0536-furniture-returns-half-by-type-and-pieces-are-removed-alone.md` govern
removal: salvage is 50% of materials rather than an intact furniture item, and
removal needs actual work plus containment/accounting checks. D15 adds a
distinct lifecycle and requires explicit reconciliation with that owner before
implementation. It does not change the removal command or assert that a
portable furniture inventory already exists. A failed Move must report the
blocker; dismantling remains a separate deliberate action.

Relocation needs defined source/destination claims, service suspension, handling
work, worker/load eligibility, route fit through turns, stairs and doors,
preservation of stored goods, cancellation and save/load. The item's occupied
volume and movement state must remain represented throughout pickup, transport
and setting down; neither endpoint may be falsely available for conflicting
work. Real routes and claims need revalidation as the world changes, including
after a load change. Destination placement must satisfy D09's room-type and
geometry rules, and service changes must retain whole-room validity checks.

An interruption or cancellation after pickup cannot instantly send an item
back to its origin or turn it into salvage. The engineering contract must
define reachable return/set-down behavior, destination invalidation, safe
waiting and recovery without trapping residents or losing goods. That contract
must also serialize progress, transported-item ownership and reservations with
generation validation and deterministic next-tick continuation. No labor,
material, mass, crew-size, speed or new concurrency limits are adopted here.

### Storage contents — approved D16

Workers haul affected goods to valid storage before moving the eligible
furnishing, then restock through normal hauling after placement. This gives a
visible unloading, moving and restocking sequence; loaded-container relocation
is not the selected policy. D16 does not itself define a container or
portability catalog.

Respect the actual ownership pattern:

- A furniture-owned container must have its goods hauled out and its incoming/
  outgoing reservations resolved through their owners before pickup. New
  deliveries cannot refill it between the emptiness check and pickup. The
  integration contract must define how admission, draining and reservations
  cooperate without deleting claims or rerouting goods without authority.
- Pantry shelves contribute capacity to a building-owned store under decision
  0536, section 4. They do not own separate inventories. Only goods necessary
  to keep contents plus reservations within remaining available capacity need
  hauling when that capacity is unavailable. Moving a shelf does not empty the
  whole pantry by default or attach an arbitrary share of its goods to it.

Unloading requires reachable, eligible destination capacity. A blocked job
waits with an explanation; it cannot destroy goods or exceed capacity to make
pickup possible. Restocking uses actual hauling and applicable storage rules,
not a saved quantity copied into the destination. Source and destination
capacity must never count the same moving shelf twice.

Cancellation or interruption preserves completed transfers and goods in real
transit; it does not instantly restore a pre-move inventory snapshot. Exact
capacity transitions, claim handling, draining states and recovery remain
engineering work. Existing demolition/removal checks remain unchanged; no
general nested-container system or handling constants are adopted here.

### Clearing furniture for renovation — approved D24

D23 permits later worker renovation of compatible finishes. D14–D16 already
require safe work areas, actual portable-item movement and correct unloading.
D24 adds a reviewed plan coordinating affected portable furniture movement
with renovation. This is scoped to the confirmed renovation plan; ordinary
structural work does not gain blanket permission to move furniture.

Provide a reviewed move-out/return plan: show the affected portable items,
legal temporary destinations, intended return placements and interrupted uses
before confirmation. The player can review or change those destinations, then
workers perform real unloading/moving, renovation and return placement in
dependency order. The player need not issue a separate Move for every stage
already included in this plan. Editing its preview creates no paid work or
authoritative placement claims before confirmation.

A coordinated plan must reuse D15/D16 rather than teleport items,
invent a storage inventory or assume every empty floor accepts any furniture.
Temporary destinations need lawful placement and full worker/load access; any
new staging-space concept would need an explicit owner contract. Both temporary
and return placements must respect the finished surface envelope and protected
connections. If no valid destination exists, show the blocker and wait.
Temporary placement does not automatically grant or duplicate services;
eligibility and actual installed state still determine use under the room
and furniture owners. Clear the item again before return pickup if it is in
use, and apply D16's unloading/capacity checks on each relocation leg.
Revalidate destinations and routes when the world changes. Cancellation or
interruption preserves real item locations, goods, claims and partial work;
it cannot instantly put everything back. A blocked return cannot overwrite a
newly placed item or silently choose an unapproved replacement location.

Fixed installations retain separate deliberate dismantle/rebuild actions and
their actual work/material/salvage rules. The renovation preview should identify
those blockers, not silently include demolition in a portable-item Move plan.
Catalog eligibility and numerical handling recipes remain unresolved engineering
work. Define linked-project identities, destination claims, cancellation and
save bindings before implementation; D24 grants no new handling constants or
storage semantics.

### Replacing completed rooms — approved D18

A built room's type is permanent for that room's lifetime. An empty kitchen is
still a kitchen, and removing its cooking equipment does not make bedroom-only
furnishing legal. Invalidity suspends the kitchen's services under REQ-SET-129;
it does not erase the type. Brendan rejected both earlier conversion options.

To replace it, the player must remove the actual kitchen room, select the new
type (for example Bedroom), lay out and confirm that type's floor plan, and
have workers construct it before furnishing. The previous shell cannot be
declared a bedroom or inherited as an already completed bedroom just because
its furniture was cleared. The new room still has D01's shape flexibility and
D02's compatible material choices; the word "layout" does not select a single
fixed prefab or settle bedroom/private-room/dormitory catalog mappings.

Removal must resolve affected residents, goods, furniture, projects and claims
without trapping residents, undermining other levels or erasing inventory.
Portable furniture may be deliberately relocated under D15/D16; fixed pieces
use adopted removal work and salvage. A retained portable piece is not already
installed in the replacement room: any later placement must obey its type,
completed-shell and access rules. There is no automatic move or mass refund.

The demo binds fixture eligibility to templates
(`godot/demo/burrow/room_fixtures.gd:335`), but that alone does not implement
the complete removal/rebuild lifecycle. The production `remove_room()` refuses
furniture (`godot/scripts/core/buildings.gd:984`); the test helper that deletes
and recreates pantry shelves (`godot/test/test_starter_colony.gd:432`) is not
authority to bypass worker removal, inventory, service or identity transactions.
Reconcile those owners with D18 before implementation. Retire old room claims
and references correctly; a reused slot cannot inherit the old room's installed
status, drafts, selected furnishing mode or service grants.

### Excavation after room removal — approved D19

Room removal includes backfilling the room's excavation to solid ground. It is
not complete while an open cavity remains within the removal scope. After
removal, the player selects and lays out the new room, which workers excavate,
support and finish before furniture can be ordered. D18's permanent room type
and D19's physical closure form one consistent remove/rebuild workflow.

Use actual earth hauled through valid routes and the existing ECON-005 closure
rules. Before closure begins, resolve affected residents, goods, furniture,
projects and claims and prohibit new entry into the closing space. Maintain
an accessible work face and a safe route for the final worker to leave.
Support remains installed until the coupled backfill/salvage commit; a visual
demolition animation cannot remove it early. Wait with the specific blocker
when earth, legal access, support clearance or salvage capacity is unavailable.

Removal scope must identify the room's actual volumes and shared boundaries.
Do not backfill connected passages, stair landings, neighboring rooms or spaces
above/below merely because they touch the room. Their support and access
dependencies must be resolved safely before the room can close. A future
replacement cannot serve as the only current escape route or justification
for removing an occupied connection.

Re-digging uses the adopted brace/cut/finish prices and recovers the actual
embedded earth under BACKFILL_RECLAIM; only newly cut virgin ground can produce
virgin-source output. Keep the physical ledger through project retirement,
cancellation and save/load. Completed closure does not revert when an order is
cancelled, and a partially backfilled site must not return as an intact kitchen
or become a ready bedroom. These are existing accounting/safety rules applied
to D19, not new resource quantities or salvage percentages.

Exact room-finish removal recipes, scope representation, shared-support
ownership, capacity changes and atomic room-retirement sequencing remain
engineering work. [Shape and surface requirements](shape-and-surface-requirements.md)
contains the build/closure acceptance criteria.

### Existing implementation and integration work

- Decision `0210-fit-out-and-living.md`, section 1, deliberately used fixture
  places to protect doors, sockets and walk space. `room_fixtures.gd:298` orders
  the first eligible place. D09 expands player control, so those protections
  need real geometry/access validation rather than removal.
- `godot/demo/burrow/install_task.gd:83`–`:91` takes the installer from the
  room center to the fixed work contact using `task_stroll_to`. Arbitrary grid
  layouts require routes around actual obstacles and split-level connections.
- The demo's immediate fixture debit is not the production delivery contract;
  the [initial review](../../reviews/2026-10-02-underground-building-review.md)
  records this and the separate save/load gap. Production integration must
  conserve delivered/WIP materials and retain references, claims and progress.
- Geometry, room validity, route revisions and installed service changes must
  agree at commit. Reuse the adopted packed storage and generation-validated
  identities; bound incremental validation for the 256-resident workload.

## Future verification

Cover rounded and concave room edges; rotated multi-cell items; raised/sunken
floors; a bed blocking the only stair landing; mutually conflicting orders;
an accessible item whose placement blocks an earlier item's use; and a stale
preview invalidated by another project. Verify both installer and resident
routes, room compatibility and loss/restoration of valid room services.

Exercise both modes in different rooms, switch with unconfirmed previews,
switch with accepted/in-progress orders, and submit while the game is paused.
Verify no implicit confirmation, lost draft, changed material balance, cancelled
worker task or cross-room preference change. Revalidate a retained draft after
an individually placed item changes its available space. Equivalent accepted
commands must produce the same simulation result regardless of the UI mode
that submitted them; mode selection itself must not change authoritative work.
Include door orders in both modes: no automatic door at shell completion,
valid and invalid opening fits, obstructed swing/approach space, and installation
beside other planned furniture. Door previews must grant no installed effects.

Exercise portable moves within and between compatible completed rooms; a turn
or stair that admits the worker but not the furniture; an in-use bed; competing
destination claims; and a destination changed after pickup. Verify services at
both ends, no salvage from Move, and unchanged fixed-installation removal rules.
Interrupt and save/load before pickup, during a level transition and before
placement, preserving item identity, physical progress and deterministic state.
Verify pantry capacity and reservations cannot be duplicated or exceeded during
a shelf move. Cover a pantry whose remaining capacity already holds its goods,
one needing only partial evacuation, and one with reserved incoming goods.
Exercise a furniture-owned store that is empty, occupied or claimed; no eligible
unloading destination; a blocked hauling route; attempted delivery during
draining; and interruption/save/load during unloading and restocking. Confirm
pickup waits for its checks, real transfers conserve quantities, restocking
respects ownership/eligibility, and cancellation creates no inventory rollback.

For D18, clear every fixture from a completed kitchen and verify that it remains
a kitchen and refuses bedroom-only items. Save/reload that empty room and
repeat the check. Attempt a direct type switch; it must not bypass removal and
new construction. Exercise the complete remove/select/layout/build/furnish
sequence, including a new shape, unresolved goods/claims, dependent stairs and
spaces above/below. Confirm old room services and references cannot survive as
the new room's state. Verify deliberately relocated compatible furniture can
return only after the replacement shell is complete; fixture clearing by itself
must never count as room removal.

For D19, observe real earth delivery and closure progress before complete
solid-ground restoration. Test insufficient earth, unreachable delivery,
occupied/claimed space, a shared support, a dependent stair and the last safe
exit. Verify support and salvage publication at the coupled commit, and keep
the final work contact reachable. Interrupt/cancel/save midway through closure
and confirm the committed partial backfill remains. Rebuild with a new shape
covering both backfilled and virgin ground; each cut must use its correct earth
account exactly once. The replacement must wait for completed removal and
cannot grant furnishings or services before its own construction finishes.

Check delivery, interruption, save/load, cancellation and completion without
duplicated inputs, lost goods or premature service activation. Inspect the
grid, footprint/access guides, refusals and keyboard placement with the real
HUD at 1280×720. Exact layout dimensions, capacity bounds, algorithms and
performance qualification remain engineering work.

No Godot tests or runtime captures were run for this planning slice.
