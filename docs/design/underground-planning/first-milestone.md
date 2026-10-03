# First underground milestone — planning slice 4

2026-10-02. D20 approves one complete small underground build before expansion
of the whole palette. This document translates that scope into a reviewable
test sequence. D21 approves its shared stair passage. D22 approves optional
furniture outlines for sizing help in the blueprint view. Implementation has
now begun; [implementation status](implementation-status.md) separates the
confirmation foundation from the still-unqualified complete milestone.
See the [working agreement](README.md) for D01–D28.

## What the first build must demonstrate

One kitchen and one bedroom, connected through a tunnel and fixed stairs on
two test levels, must exercise the complete player workflow. The suggested
kitchen has useful straight walls and rounded corners; the suggested bedroom
has an irregular alcove. These are examples, not restrictions on either type's
shape. Numerical geometry and bedroom/private-room/dormitory mapping still
need the spatial and room owners; a schematic cannot supply them.

D21 places the stairs in a shared passage so removal of either room can
preserve circulation. Keep both room branches and removal scopes separate from
the stair and its landing approaches. Option 1 in the historical
[layout comparison](first-milestone-layout.png) is approved; the second option
is retained for context, not as an unresolved selection. Room-contained stairs
remain permissible elsewhere when valid. Shared passage placement still needs
real support, headroom and cargo checks.

Keeping the passage open does not guarantee unchanged room services. In
particular, removing a kitchen hearth may change connected heat under GDD
§5.9. Preview and revalidate those service effects; a clear route alone must
not make a cold or otherwise invalid room appear fully operational.

## First review checkpoint: blueprint to empty shell

This is a proposed implementation packet within D20, not a second approval of
the already chosen workflow. After the required owner contracts are complete:

1. Establish the shared passage, stair and both landing envelopes in the
   fixture's canonical geometry. Test the legal construction approach before
   asking workers to reach a new level; a drawn landing is not a finished route.
2. Select Kitchen and paint its draft. Show the grid, actual boundary,
   room-appropriate material preview, entrance suggestion and clearance. The
   draft can be revised before explicit confirmation with no world mutation.
   Under D25, expose one floor, wall and ceiling finish choice for the whole
   room; do not add local material-paint controls to the shape/height tools.
3. Show the applicable area/equipment/access requirements and real construction
   inputs. D22 adds an optional illustrative furniture-fit guide to supplement
   that information. Amount labels must follow the current owning UI rules,
   including DEC-049 natural measures; display rounding never changes accounts.
4. Confirm, then show real workers reaching legal contacts, installing required
   support, cutting and hauling spoil, and applying the selected finishes.
   Exercise one blocked delivery or access condition and its recovery.
   Under D26, revise an unstarted area during construction, inspect changed
   work/materials/access and confirm without resetting existing work. Also
   exercise work committed before D27's safe editing pause is acknowledged
   and an external world change afterward. Confirmation still revalidates;
   release only the editing pause after acceptance or explicit discard.
   D28 requires Apply / Discard / Keep editing when leaving with unapplied
   changes; test all three choices and a departure with no changes.
5. Inspect the completed empty shell at gameplay and close distances. Furniture
   becomes available only now. Check curved edges, straight walls, floor/ceiling
   joins, constant material scale and the protected passage/stair envelope.

Review that small result before broadening the walkthrough to the bedroom,
furnishing modes and removal/rebuild. This is incremental inspection of one
complete milestone; it does not reduce D20 to an editor-only deliverable.
Do not call the checkpoint complete without geometry/accounting checks and
appropriate interruption/save evidence alongside the visible playthrough.

### Small control review: revising the kitchen during work

This collects D26–D28 into one inspectable interaction without reopening their
approved behavior. Control names are working labels, not new registered UI IDs.

| Player action/state | Visible result | Work/state check |
| --- | --- | --- |
| Select the partly built kitchen | Show the contextual blueprint and actual work | Selection does not pause construction |
| Choose Revise | Show that this project is reaching a safe stop | Other projects and global time controls are unchanged |
| Stop acknowledged | Clearly separate worked areas from editable unstarted areas | Preserve work/materials and apply the owner's pause rules |
| Edit the remaining footprint | Show updated boundaries, quantities, access and furniture sizing guides | Draft edits create no construction orders or physical changes |
| Apply valid changes | Show the accepted amended plan | Revalidate first, then release only the editing hold |
| Discard changes | Return to the accepted original plan | Preserve performed work and release only the editing hold |
| Apply invalid changes | Show the actual blocker and retain the revision | No partial amendment, implicit discard or editing-hold release |
| Leave with unapplied changes | Offer Apply changes, Discard changes or Keep editing | No implicit commit/discard or abandoned editing hold |
| Dismiss the exit prompt | Stay in the revision with its draft intact | Consume the dismissal; do not also trigger a background action |
| Leave without changes | Close the revision without a lost-changes prompt | Safely release only its editing hold, including a pending stop |

A prior or newly issued manual pause remains effective after Apply/Discard.
This is part of the 1280×720 review and save/interruption checks, not a claim of
implemented UI. D28's exit choices are approved; exact control registration,
layout and hold/draft persistence still require the owning contracts.

### Optional sizing guide — approved D22

Provide optional example equipment outlines to help judge whether the painted
space can accommodate its purpose: actual kitchen bench/hearth footprints for a
kitchen, and the applicable bed/access footprint for the chosen bedroom type.
The full room requirements remain visible; a single example is not proof of
all counts, area ratios, connectivity or service validity. Hiding the examples
keeps the normal geometry and written requirements visible.

The guide must be visibly illustrative and use catalog dimensions
and actual access requirements. It cannot shrink equipment to fit, silently
clip it at a curved edge or show an unreachable arrangement as valid. A room
edit revalidates the example, including changed floor heights and protected
entrance/stair space. Missing catalog or access data cannot establish fit.
It must not impose fixed furnishing locations,
let players issue furnishing orders early, or carry examples forward into
D10's actual furniture draft. Exact presentation and arrangement generation
remain design/engineering work within the approved direction.

At this checkpoint, exercise a curved wall clipping a candidate footprint,
a blocked equipment approach and a layout edit that invalidates an earlier
example. Toggle the guide and confirm that it changes no world state, costs,
reservations or construction orders. After shell completion, the furnishing
tool must begin without items or orders inherited from these examples.

## Playthrough to review in small checkpoints

| Checkpoint | Visible result | Required evidence |
| --- | --- | --- |
| Plan | Choose the room type, paint a nontrivial footprint, inspect materials and entrance, place a matching stair connection, then confirm | Draft edits cause no world changes; overlaps and invalid access identify the actual blocker; selected and unselected plans follow D17 |
| Build | Workers reach the work face, install support, excavate, haul actual spoil and finish the selected surfaces | Committed geometry and the physical ledger agree; no unfinished through route; fitted floors/walls/ceilings retain material scale; completion leaves an empty shell |
| Furnish and use | Place compatible kitchen equipment and bedroom furnishings using both per-room confirmation modes | Grid fit, real access, whole-room validity and services agree; a wrong-room item refuses; mode changes preserve drafts and accepted work |
| Rearrange | Order an eligible portable item moved through the connection; exercise a storage move if the approved portability catalog supplies one | Real handling and load clearance; unload before pickup, preserve goods/claims and restock by hauling; fixed installations retain removal/rebuild |
| Remove and rebuild | Emptying the kitchen leaves its type unchanged; actual removal safely backfills it, then a newly selected bedroom plan is excavated and built | Solid-ground closure, real earth consumption/reclamation, no duplicate salvage, no inherited kitchen state and no new furnishing before completion |

Door installation remains a post-shell furnishing action. Test it through both
confirmation modes, preserving the actual opening and passage. A room project
must show paused/blocked states and work progress without pretending that a
missing finish or inaccessible contact is complete.

The first walkthrough also needs an invalid-placement case: attempt furniture
on a stair landing and attempt a stair whose clearance intersects another
level's room/item. Both must explain the conflict before commitment. A removal
that would eliminate protected access must refuse until that dependency is
resolved; the happy-path layout cannot stand in for this negative check.

## Engineering work before the walkthrough

The initial review is pinned to `d9941bd9fc4ebdca12ab5b34d86c943439d93ad1`.
Refresh it against the current implementation and owning contracts before
creating implementation packets; Claude's subsequent fixes must not be
overwritten or treated as absent because of that historical baseline.

Resolve the relevant MOVE-G01–05 obligations for this increment: the supported
shape representation and bounds; shared integer geometry for cuts, rooms,
surface generation, placement, contacts and movement; actual stair/room/item
catalog rows; paid-cut and support ownership; closure transactions; and save
bindings. The two-level fixture supplies none of those numerical constants.

Use the existing construction/inventory owners and generation-validated packed
storage. Define deterministic admission, interruption, cancellation and commit
boundaries before joining the new tools to worker jobs. A rendering-only
preview must not masquerade as completed excavation, logistics or persistence.
No new paid asset generation is part of this milestone selection.

## Evidence required for acceptance

- A 1280×720 playthrough of the complete sequence with readable work faces,
  room status, placement guides, refusals and ordinary keyboard alternatives.
  Additional close views inspect materials and joins; neither substitutes for
  the gameplay view. Review grounded expressive art against the existing
  approved references without treating this schematic as an art target.
- Geometry and conservation checks for curved/concave shapes, stacked spaces,
  shared boundaries, cargo clearance, old/new room identities and the full
  backfill/re-dig loop. Use additional fixture variants for split-level sections
  and local alterations under D06/D07/D14; they need not crowd the first image.
- Interrupt and save/load at meaningful work boundaries: excavation,
  finishing, furniture delivery, relocation and closure. Preserve actual
  progress, resource accounts, claims and equal-tick authoritative results.
- Measure the integrated workload at the 256-resident cap, using the owning
  performance targets. A quiet two-room scene alone cannot establish capacity
  or frame/tick performance. Expand fixture stress without inventing a higher
  resident limit.
- Run the applicable CI contract/analyzer gates and the full strict headless
  suite using the user's prescribed import procedure in an isolated checkout:
  move demo assets aside if present, remove the import cache, import with
  `godot --headless --path godot --editor --quit`, run `./tools/run_tests.sh`,
  and restore the assets afterward. Report the test summary and diagnostics/
  leaks lines, not just the process exit status.

## After the first accepted build

Extend the same verified lifecycle across the remaining shape tools, room
types, materials and D04 connection families. A successful example does not
close the whole movement scope or demonstrate every shape/connection profile.
Keep unsupported variants visibly unavailable until their contracts and
verification exist; do not publish working-looking but unusable stairs or
rooms as a completed feature.

D23 adds later worker renovation of compatible finishes to the overall plan;
D24 includes reviewed portable furniture move-out and return.
Use the completed fixture for a focused follow-up inspection of replacement
work, unchanged room type/shape, material fit, temporary/return placement,
interrupted use and persistence before expanding that operation across the
full catalog. D25 replaces each selected whole surface category, with actual
partial work visible until it is complete. This leaves the first
blueprint-to-empty-shell checkpoint intact.

The construction/revision interaction choices through D28 are settled for
this checkpoint. The next review is the concrete blueprint-to-empty-shell
walkthrough above, followed by the remaining small playthrough checkpoints.
Technical bounds, catalogs and runtime evidence remain owner work; this is
not a claim of implementation readiness or verified game behavior. Brendan's
subsequent build instruction authorizes the relevant gameplay changes on the
isolated Codex branch; see the [working agreement](README.md). The branch,
shared-checkout and paid-generation restrictions still apply.
