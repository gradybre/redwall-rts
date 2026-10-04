# 1050 — Room blueprints are reviewed before excavation
Date: 2026-10-02 · Status: Accepted

## Decision

The demo's room tool holds an unconfirmed blueprint on a world click. Only
Confirm / Enter orders excavation. The held location does not follow pointer
motion; Move resumes positioning and Discard / Escape removes only the draft.
The review card lives at the top of the existing scrolling detail panel.

Revalidate the complete current site and entrance at confirmation. If the
suggested passage or its referenced generation changed, show the new proposal
and require confirmation again. If the reviewed passage cannot be allocated,
refuse the complete order rather than silently build a standalone room.

## Why

Brendan approved blueprint → confirm → worker excavation → empty shell →
furnishing, then explicitly asked to begin implementation. Previously one
room click ordered work immediately, and network exhaustion could silently
omit the passage shown in the preview. Neither behavior supports reviewing a
modular room plan.

The first integration uses the existing two room templates and excavation
owner. Arbitrary painted footprints cannot safely inherit their fixed
12-cell geometry, fixed socket walks or 66-entry segment timeline. This
increment does not rename a burrow home “Bedroom” or a root cellar “Kitchen”,
nor claim to implement those functional room types.

## Consequences

- Drafts allocate no room/network rows, dispatch no workers and spend no stock.
- Held drafts keep their room type and level until explicitly resolved.
- Reuse the existing quarter-metre positioning lattice for the clipped preview
  grid. This is not a decision about future paint cells or the physical paid-cut
  lattice. The world-anchored grid is presentation only.
- Existing construction remains responsible for progress and the empty shell.
  No materials, work rates, furniture rules or service bonuses are invented.
- The direct `place` harness hook remains synchronous; player input reaches it
  through `confirm`. Both paths revalidate and reject a missing reviewed passage.
- This closes only the initial confirmation increment. The approved D20
  blueprint-to-empty-shell checkpoint, variable geometry, material installation,
  project revision holds, persistence and production movement gates remain open.

## Source

[Approved direction D01–D28 and the subsequent build instruction](../design/underground-planning/README.md),
[first milestone](../design/underground-planning/first-milestone.md),
[implementation status](../design/underground-planning/implementation-status.md),
and existing demo room/level owners (0209, 0212).
