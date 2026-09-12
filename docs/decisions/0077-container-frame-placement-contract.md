# 0077 — The container frame placement contract

Date: 2026-09-11
Status: Accepted
Owners: `godot/ui/ui_frame_geometry.gd`, `godot/ui/ui_frame_builder.gd`,
`godot/ui/ui_art_manifest.json`, `godot/test/test_ui_frame_geometry.gd`
Implements ART-UI-02, 07, 08 and 11 under
[SET-UX-VIS-002](../ui_visual_refinement_amendment.md); extends
[0072](0072-woodland-ui-art-construction.md), which delivered the art these rules place.

## Context

Decision 0072 delivered five container silhouettes as eight SVG pieces each — four edges and
four corners — with `godot/ui/ui_art.gd` declaring `FRAME_EDGE_INSET` per side and
`FRAME_CORNER_SIZE` per corner, and `ui_art_manifest.json` recording both. It deliberately
declared **no placement**, on the reading that ART-UI-11's "no frame size or click target
derives from an asset's pixels" gives layout to the layout owner.

Two attempts were then made to apply the frames in `godot/scripts/ui/ui_shell.gd`. Both put
the corners **outside** their panels and left the edge strips invisible. `_apply_frame_art()`
and `_add_frame_piece()` are still in that file, uncalled, with the author's note. The pieces
loaded and drew, so the fault was never the paths: the declared numbers had no stated meaning
and the Godot mechanism chosen to honour them does not behave as its documentation reads.

Leaving the contract unstated a third time was not an option, and neither was inventing it in
the shell, where a concurrent owner works.

## Decisions

### 1. `FRAME_EDGE_INSET` is a thickness measured across the strip

It is the **height** of the top and bottom strips and the **width** of the left and right
strips. It is not a square extent, and it is not a distance between the panel edge and the
strip — every strip is flush with the panel boundary.

The first application used it for both axes of every strip. That is wrong on the long axis at
every real panel size, and the journal proves the asymmetry is real rather than incidental:
its left inset is 12 and its right is 5, because one side is a bound spine and the other a
paper fore-edge. `test_ui_art.gd::test_frame_edge_thickness_matches_the_declared_stretch_margin`
already measured exactly this against the rasterised art, one axis per side; nothing had
written down what it meant.

### 2. `FRAME_CORNER_SIZE` is a draw size, not an outer bound

It is the exact size the corner is blitted at, equal to its source document. It carries no
bleed and it is not a nine-patch margin. Corners never scale, because scaling relief art
changes its apparent depth.

### 3. Corners own the corners; strips run **between** them

Each corner sits flush in its own corner of the panel. Each strip is then inset along its run
by the two corner extents that bracket it: the top strip runs from the top-left corner's width
to the panel width minus the top-right corner's width, and the left strip from the top-left
corner's height to the panel height minus the bottom-left corner's height.

A full-width strip — which is what `PRESET_TOP_WIDE` produces — double-draws the relief band
underneath both corner motifs, and on the journal, whose two ends have different extents, the
double-draw is visibly different at each end. Non-overlap between the strips themselves is a
property of the delivered art rather than of this arithmetic (every corner is at least as wide
as the side inset beside it; journal 12 vs 12 is the tight case), so the suite asserts it for
all five silhouettes to stop new art breaking it silently.

### 4. A panel too small for its own corners is refused by name, never clamped

`minimum_size_of()` is both corner pairs plus one pixel of edge run. Below it,
`rects_into()` returns `false`, leaves the output array untouched, and `refusal_for()` names
`UI_FRAME_PANEL_TOO_SMALL`. There is no sentinel rectangle. A panel that shrinks below the
minimum after the frame is applied has the whole frame **hidden**, because a clamped frame
stacks the two corners of a side on top of one another and still reports itself as applied.

The one-pixel run is arithmetic, not a design value: no specification fixes a minimum
container size and this work does not invent one. It only refuses the sizes at which its own
output would be degenerate.

### 5. Pieces are placed explicitly. Godot's layout presets are not used, and here is why

Two properties of Godot 4.7.2 were probed, not assumed, and both make the obvious
anchor-and-preset version silently wrong in this project's configuration:

* **`Control.get_parent_anchorable_rect()` returns an empty rect while the control is outside
  a SceneTree**, so anchors resolve against a zero-sized parent. The shell is built off-tree
  on purpose, and the headless runner executes every suite inside `SceneTree._initialize()`,
  where even `root.add_child()` leaves `is_inside_tree()` false. An anchored frame measures
  zero in both.
* **`set_anchors_and_offsets_preset(preset, PRESET_MODE_MINSIZE)` sizes from
  `get_minimum_size()`, not `get_combined_minimum_size()`**, so `custom_minimum_size` is
  invisible to it. Every offset it writes is `0`; each piece becomes a zero-sized rect pinned
  exactly on its anchor line; and Control's later minimum-size enforcement inflates it outward
  along `grow_horizontal`/`grow_vertical`, both `GROW_DIRECTION_END` by default. A `TOP_RIGHT`
  corner therefore grows from `x = panel_width` rightwards, entirely outside the panel. **That
  is the whole of the first failure**, and the same mechanism explains the second: the pieces
  that grew inward were visible, the ones that grew outward were not.

So every piece keeps default anchors and takes an explicit `position` and `size` from
`ui_frame_geometry.gd`. Nothing depends on a layout pass, a tree, or a frame boundary, which
is also what lets the suite assert built rectangles synchronously.

Pieces are `TextureRect` with `EXPAND_IGNORE_SIZE`, so a texture can never impose a minimum
size and re-introduce the growth trap. `STRETCH_SCALE` is lossless here because
`test_ui_art.gd` already proves every edge strip is constant along the axis it stretches on.

### 6. The holder follows the panel, with one measured caveat

`apply()` leaves a `FrameArt` holder connected to the panel's `resized` signal, so a
responsive relayout keeps a correct frame without a second call. But `Control.set_size()` runs
`_size_changed()` only while inside a tree, so `resized` never fires off-tree and therefore
never fires under `--script` at all. The suite drives the same chain by issuing
`NOTIFICATION_RESIZED` itself, which is what the engine does in a live tree, and `refresh()`
is the explicit door for a caller that resizes a panel off-tree.

### 7. No art was changed

Every piece already matched its declared bounds; the mismatch was entirely in placement. The
corner sources are mirrored copies of the top-left one and their band stacks join the strips
pixel-for-pixel at every seam, which the contact sheet shows at magnification. The manifest
diff for this work is additive only — no asset digest moved.

## Consequences

The shell owner applies a frame in one line and owns no geometry:

```gdscript
const UiFrameBuilder := preload("res://ui/ui_frame_builder.gd")
UiFrameBuilder.apply(panel, UiFrameBuilder.FRAME_RESOURCE_TRAY)
```

`ui_shell.gd`, `ui_layout.gd` and `ui_manager.gd` were **not** modified; the uncalled
`_apply_frame_art()` / `_add_frame_piece()` pair is left for their owner to delete.

`ui_art_manifest.json` now carries a `frame_placement` block stating all of the above in
words, plus a `minimum_panel_size` per silhouette, and the suite asserts that those numbers
still agree with the code. A bare pair of integers cannot say which axis it belongs to; that
was the root of the misreading and it is now written into the artifact itself.

## Still open

The journal declares two extra pieces, `ART.FRAME.JOURNAL.RING` and
`ART.FRAME.JOURNAL.STRAP`, which are **not** part of the eight-piece contract and have no
declared anchor of any kind. No constant was invented for them: the builder does not place
them, and it will not until the amendment or a decision says where they go.

The corner and strip art has never been seen by a human eye at final size in the running
shell. `godot/ui/review/sheets/art_frame_geometry.png` is the substitute and shows all five
frames at 132x76, 300x120 and 760x96.
