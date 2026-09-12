# 0072 — How the woodland UI art family is constructed

Date: 2026-09-11
Status: Accepted
Owners: task 04.5b art pass, `godot/ui/**` and `godot/scripts/ui/ui_theme.gd`
Supersedes nothing. Implements ART-UI-01 to 08 and 11 under
[SET-UX-VIS-002](../ui_visual_refinement_amendment.md) revision 3 and
[ART-LOCK-001](../design/ui_refinement/asset_generation_lock.md).

## Context

Task 04.5b asked for a painted woodland art family to replace the task-04.4 monochrome line
icons. The brief arrived against amendment revision 2. Revision 3 and ART-LOCK-001 landed
while the work was in progress and changed several settled things — the twelve illustration
pigments, the exact object identity of each of the sixteen rows, the numeric light rig, the
contour ruling, and DEC-036's permission to use Brendan's supplied images directly. The
first pass of art was authored against revision 2 and then re-authored against the lock.

Several construction questions were not answered by either document, and a later reader
could reasonably undo any of them by accident. They are recorded here.

## Decisions

### 1. Ownership of the separation keyline: one pass behind everything, not per part

ART-LOCK-001 §4 requires an I01 ink contour on the primary silhouette plus, on FOREST, an
outer I04 cream keyline. The obvious implementation — give every drawn part its own keyline
and ink — was tried first and **fails at 24 px**: a 1 px keyline plus a 1 px contour on each
of three or four parts consumes most of an 18 px subject, and the icons became sticker-like
outlines with no readable interior. Contact sheets from that pass are the reason this is
written down.

The construction now used draws **all keylines first, then every part body front to back**.
A later part's fill paints over an earlier part's keyline, so cream survives only outside
the union of the parts. That is exactly the "primary silhouette", it needs no hand-authored
union path, and it puts no cream line through the middle of a drawing.

Do not change `keylines()` to run per part. It has already been tried.

### 2. Two medallion files per species, not one scaled file

The lock fixes the medallion frame **per size**: 44 px roundel with a 1 px ring and a 6x8
sprig at 48, 60 px with a 1.5 px ring and an 8x11 sprig at 64. A single source scaled to
both misses both. So each species has a `_48` and a `_64` file and its own registry ID.

The risk that creates — two files drifting into two different animals — is closed by
drawing the **subject** once in a 64-unit space and placing it into both canvases from one
string. Only the frame weights are per size. `test_ui_art.gd` checks all eight rasterise
differently from one another, so a copy-paste of one species over another fails.

### 3. Food and People have no files of their own

ART-LOCK-001 §5 says CMD-FOOD is the RES-FOOD artwork exactly and CMD-PEOPLE is the RES-POP
artwork exactly: sixteen logical rows, fourteen designs. Rather than commit duplicate SVGs
and rely on discipline to keep them identical, `ART.CMD.FOOD` and `ART.CMD.PEOPLE` point at
`res_food_ready.svg` and `res_population.svg`. They cannot drift because there is nothing to
drift from.

### 4. Panel corners carry their own opaque field; the renderer fills a cross

A notch, a chamfer or an angled shoulder only cuts the outline if nothing fills the corner
behind it. The first assembly filled the whole panel rectangle and laid decorated corners on
top, and every silhouette read as the same rounded rectangle with marks in the corners.

Each corner piece therefore includes the panel's own surface colour clipped to the
silhouette, and a renderer fills only the cross between the four corners. `build_specimen.gd`
demonstrates the construction, and it is the assembly a runtime implementation should copy.

Corner extents are stored **per corner**, not per panel, because the journal's bound side is
a 12x16 spine cap and its fore-edge side is a 14x14 page corner. Averaging them misplaces
both.

### 5. Edge strips are constant along the axis they stretch on

"Stretchable edge art" is only true if stretching cannot distort or seam it. Every edge
strip is therefore a constant profile — a relief band with no motif — and all motif lives in
the corners, which are never scaled. This also satisfies ART-UI-07's rule that ornament
belongs at anchors rather than around every row. The invariant is machine-checked: every
column of a horizontal strip must equal its first column.

### 6. How the contrast contract is measured on painted art

UXV-008 requires 3:1 for functional icon and border contrast. A painted body cannot be
assumed to meet it, and ART-LOCK-001 makes the keyline the declared mechanism rather than an
opaque backing. The test therefore grades the **outermost visible pixel** of each icon
composited over its surface, not the average of its body and not the outermost fully opaque
pixel. Grading only opaque pixels measures the ink contour underneath the keyline and gives
a misleading failure; grading the body average would let a dark icon pass on the strength of
a bright highlight somewhere in the middle.

### 7. Thresholds in `test_ui_art.gd` are evidence-based, and one of them was wrong first

`PAINTED_COLOUR_MINIMUM` originally counted distinct tones across all opaque pixels. A
mutation that flat-filled one icon and deleted its interior shading **survived** that check,
because the ink contour, the cast shadow and antialiasing supply tones of their own. The
check now counts tones strictly inside the body, away from the contour and every antialiased
pixel. Measured: the delivered family carries 26 to 77 interior tones and the same family
flat-filled carries 15, so the bar sits at 22. Re-running the same mutation against the new
check fails it.

This is recorded because the number looks arbitrary and is not.

## Consequences

- A renderer consuming this art must fill the cross between corners, not the rectangle.
- Adding an asset means adding a row to `ui_art.gd` and regenerating `ui_art_manifest.json`;
  the suite fails on a stale digest, which is intended.
- Every asset is a new file needing a Godot import. Run
  `godot --headless --path godot --editor --quit` before trusting any suite result, or a
  missing import looks exactly like broken art.
- The review renders under `godot/ui/review/` are behind a `.gdignore` and are not runtime
  assets. Nothing crops the AI concept image into a panel or bakes its text into a texture.

## Open

- **Brendan's aesthetic verdict is PENDING.** ART-UI-12 requires it to be recorded
  separately and it is not invented here. A headless suite cannot approve art.
- ART-UI-09 and 10 are not claimed by this pass: both need the art placed in the running
  HUD and resident slice, which is the integration lead's file ownership, not this one's.
