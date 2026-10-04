# 1061 — Paint room plans directly on the selected world's dirt
Date: 2026-10-02 · Status: Accepted interaction component; playable construction pending

## Decision

D29 clarifies the existing approved interaction: the player's pointer draws
on the actual dirt where the room will be built. Blueprint means the in-world
planned outline. A separate drawing canvas is not the gameplay interaction.
The earlier UG04 board remains an explicitly labeled component test fixture.

`modular_world_tool.gd` binds the live Camera3D, one draft, its exact integer
pitch/domain, immutable world datum and the host's selected-level/modal owners.
It projects actual pointer rays onto that selected floor. Float arithmetic ends
at the input boundary; authoritative draft cells stay integer. Negative positions
use floor, never truncation. Missing, nonfinite, behind-camera, out-of-viewport,
overflowing and numerically unpickable domains refuse. Display precision must
preserve quarter-cell interiors as well as boundary corners.

The controls remain a narrow inspector beside the world. Rectangle, rounded
rectangle, oval, free painting and tunnel routing all operate on the same
world footprint and retained history; they do not restrict rooms to circles.
The world overlay uses the same integer datum/pitch and fills exactly selected
cells. Only exposed edges form its bright boundary; interior grid lines are
lighter. World-sized shader coordinates remain fixed when the camera moves.
Geometry rebuilds only when cells change; invalid-state tint reuses the meshes.

Presses begin only after GUI input declines them. A captured release is consumed
before GUI, so releasing over Confirm cannot also click the button. Escape or
right-click cancels the current stroke. Modal opening, view/floor change, tool
deactivation or focus loss does the same without erasing earlier strokes. The
selected level is read synchronously on each event to close same-frame switch
races. Replaced drafts, changed grid domains and invalidated view providers hide
stale marks; cancellation targets the captured original draft, never another
room's replacement draft. Camera pan/zoom never samples a stationary pointer
into paint. The host retains unrelated camera and keyboard controls.

## Scope and composition

This component publishes no excavated terrain, project, material transaction,
room identity, service or route. Confirmation in the real-village fixture remains
unbound and refuses orders. UG09 must compose the actual UG06/UG07/UG08/UG21
owners and bind the same datum for picking, geometry, exact paid cubes and shells.
The fixture's legacy level heights are explicit test inputs, not an adoption
of production floor spacing or subsurface survey truth.

The native walkthrough uses the actual demo scene, its camera, underground view
and modal router. It checks world drawing, real UI interception, release-over-GUI,
camera pan, same-frame level switching, modal dismissal and focus loss. Existing
legacy panels overlap the new inspector's surroundings; ordinary-play tool
selection and HUD coexistence remain UG09 work. Placeholder dirt/room art and
these captures are interaction evidence, not final world-art qualification.

## Independent review and verification

Independent review found incorrect boundary-triple decoding (stray diagonal
lines), stale-binding cancellation, insufficient subcell precision at extreme
coordinates and dark text on a dark panel. Each was fixed before approval.
The exact rendered line segments now have independent coverage tests for one
cell, an L shape and a negative-offset rounded shape; they exclude interior
edges and duplicate/stray segments. Native captures use the existing parchment
WoodlandSkin and were inspected after the fix. The child harness fails if its
PNG saves fail, or any script error/unexpected engine diagnostic/leak appears.

A clean editor import was followed by the actual strict runner's singleton
shards for the changed world tool and its draft/editor dependencies:

```text
9 test(s), 149 assertion(s), 0 failure(s)
11 test(s), 201 assertion(s), 0 failure(s)
10 test(s), 104 assertion(s), 0 failure(s)
```

Each independently reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The corrected source's analyzer reports
`0 GDScript warning(s) in 0 of 6 file(s)` (dedicated port6153).
Native1280x720 walkthrough: `LIVE-SUMMARY 42 0`, including four successful PNG
saves. The native standalone log contains the existing unstaged-asset notices;
the strict child test explicitly checks that no other warning/error is accepted.
No claim of a zero-warning native raw log is made.

Five local headless rebuilds measured4096cells median10.798ms/max10.845ms;
16384cells median43.624ms/max45.001ms. These are whole-preview cold costs,
not per-frame/256-resident or qualification-floor results. Repeated camera
frames and style changes reuse geometry. Large-plan responsiveness and the
whole UI budget still require UG17 qualification/optimization.

Source hashes, logs, performance probe and all four inspected screenshots live
in [world evidence](../design/underground-planning/evidence/modular-build/world/).
This focused result does not replace the full integrated CI-style checkpoint.

## Sources

Brendan's2026-10-02 direct-on-dirt clarification; D01–D29 under
`docs/design/underground-planning/`; decisions1052/1055/1057;
AGENTS.md, CLAUDE.md and the adopted movement/economy amendments.
