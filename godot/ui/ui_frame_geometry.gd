extends RefCounted
## Where every piece of a container frame goes. The placement contract for `godot/ui/frames/`.
##
## `ui_art.gd` declares WHAT each frame is made of -- eight sources, an edge inset per side and
## a corner extent per corner. It deliberately declares no placement, because ART-UI-11 gives
## layout to the layout owner. This file is the missing half: given a panel rectangle it says
## exactly which pixels each of the eight pieces occupies. `ui_frame_builder.gd` turns those
## rectangles into Controls; `test/test_ui_frame_geometry.gd` proves them.
##
## ---------------------------------------------------------------------------------------
## WHAT THE DECLARED NUMBERS MEAN. Both were misread once, so they are spelled out.
##
## `UiArt.frame_edge_inset(frame, side)` is a THICKNESS MEASURED ACROSS THE STRIP, not a square
## extent and not a distance from the panel edge. For the top and bottom strips it is the
## strip's HEIGHT and its width is whatever run is left between the corners; for the left and
## right strips it is the strip's WIDTH and its height is the run between the corners. It is
## the same number in both roles only because the sources happen to be square-ish, and the
## journal proves it is not: its left inset is 12 and its right inset is 5.
## `test_ui_art.gd::test_frame_edge_thickness_matches_the_declared_stretch_margin` already
## measures exactly this against the rasterised art, one axis per side.
##
## `UiArt.frame_corner_size(frame, corner)` is the EXACT DRAW SIZE of that corner, equal to its
## source document, not an outer bound with bleed and not a nine-patch margin. A corner is
## blitted at that size and never scaled, because scaling relief art changes its apparent depth.
##
## ---------------------------------------------------------------------------------------
## THE ASSEMBLY RULE, in one sentence: CORNERS OWN THE CORNERS AND EDGES RUN BETWEEN THEM.
##
## Every piece sits flush against the panel's own boundary -- there is no outward bleed, so
## ART-UI-07's "ornament stays inside the measured panel rectangle" holds by construction.
## Each corner is placed at its own corner of the panel at its declared extent. Each edge is
## then inset along its run by the two corner extents that bracket it, so no strip is ever
## drawn underneath a corner motif: the top strip runs from the top-left corner's WIDTH to the
## panel width minus the top-right corner's WIDTH, and the left strip runs from the top-left
## corner's HEIGHT to the panel height minus the bottom-left corner's HEIGHT. Using the full
## panel width for the top strip -- which is what `PRESET_TOP_WIDE` gives you -- double-draws
## the band under both corners, and on the journal, whose two ends have different extents,
## the double-draw is visibly different at each end.
##
## Edges never overlap each other either, and that is a property of the delivered art rather
## than of this arithmetic: every corner is at least as wide as the side inset next to it
## (journal 12 vs 12 is the tight case) and at least as tall as the inset above it. The test
## asserts non-overlap for all five frames so that new art cannot quietly break it.
##
## ---------------------------------------------------------------------------------------
## REFUSAL. A panel too small to hold its own corners has no correct frame, so this refuses by
## name instead of clamping. A clamped frame would put the left and right corners on top of one
## another and report success. There is no sentinel rectangle.

const UiArt := preload("res://ui/ui_art.gd")

# --- piece order ------------------------------------------------------------------------
#
# Identical to the registry's run order (four edges, then four corners), so that
# `UiArt.frame_first_asset(frame) + piece` is the registry index of that piece.

const PIECE_EDGE_TOP: int = 0
const PIECE_EDGE_BOTTOM: int = 1
const PIECE_EDGE_LEFT: int = 2
const PIECE_EDGE_RIGHT: int = 3
const PIECE_CORNER_TL: int = 4
const PIECE_CORNER_TR: int = 5
const PIECE_CORNER_BL: int = 6
const PIECE_CORNER_BR: int = 7
const PIECE_COUNT: int = 8

## Node names for the built pieces, in piece order. A caller reads a piece back by name.
const PIECE_NAMES: Array[String] = [
	"EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight",
	"CornerTL", "CornerTR", "CornerBL", "CornerBR",
]

## `UiArt.frame_edge_inset` side order.
const SIDE_TOP: int = 0
const SIDE_RIGHT: int = 1
const SIDE_BOTTOM: int = 2
const SIDE_LEFT: int = 3

## `UiArt.frame_corner_size` corner order.
const CORNER_TL: int = 0
const CORNER_TR: int = 1
const CORNER_BL: int = 2
const CORNER_BR: int = 3

## The shortest run an edge strip may have. One pixel, because a strip with a zero-length run
## is not drawn at all and a frame with two invisible sides is not a frame. This is arithmetic,
## not a design value: no specification fixes a minimum container size, and this file does not
## invent one -- it only refuses the sizes at which its own output would be degenerate.
const MINIMUM_EDGE_RUN: float = 1.0

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_FRAME: StringName = &"UI_FRAME_UNKNOWN_FRAME"
const REFUSE_UNKNOWN_PIECE: StringName = &"UI_FRAME_UNKNOWN_PIECE"
const REFUSE_PANEL_TOO_SMALL: StringName = &"UI_FRAME_PANEL_TOO_SMALL"


static func frame_count() -> int:
	"""How many container silhouettes can be assembled."""
	return UiArt.frame_count()


static func is_frame(frame: int) -> bool:
	"""True for a declared silhouette index."""
	return frame >= 0 and frame < UiArt.frame_count()


static func is_piece(piece: int) -> bool:
	"""True for one of the eight piece slots."""
	return piece >= 0 and piece < PIECE_COUNT


static func registry_index_of(frame: int, piece: int) -> int:
	"""The `ui_art.gd` asset index of one piece. Callers validate both arguments first."""
	return UiArt.frame_first_asset(frame) + piece


static func source_path_of(frame: int, piece: int) -> String:
	"""The SVG source of one piece. Callers validate both arguments first."""
	return UiArt.source_path_of(registry_index_of(frame, piece))


static func minimum_size_of(frame: int) -> Vector2:
	"""The smallest panel this silhouette can dress: both corner pairs plus one run pixel.

	Callers validate the frame index first, exactly as `ui_art.gd`'s accessors require.
	"""
	var tl: Vector2i = UiArt.frame_corner_size(frame, CORNER_TL)
	var tr: Vector2i = UiArt.frame_corner_size(frame, CORNER_TR)
	var bl: Vector2i = UiArt.frame_corner_size(frame, CORNER_BL)
	var br: Vector2i = UiArt.frame_corner_size(frame, CORNER_BR)
	var width: float = maxf(float(tl.x + tr.x), float(bl.x + br.x)) + MINIMUM_EDGE_RUN
	var height: float = maxf(float(tl.y + bl.y), float(tr.y + br.y)) + MINIMUM_EDGE_RUN
	return Vector2(width, height)


static func refusal_for(frame: int, panel_size: Vector2) -> StringName:
	"""Why this frame cannot dress this panel, or REFUSE_NONE when it can.

	Named rather than boolean so a caller can report the reason instead of guessing at it.
	"""
	if not is_frame(frame):
		return REFUSE_UNKNOWN_FRAME
	var minimum: Vector2 = minimum_size_of(frame)
	if panel_size.x < minimum.x or panel_size.y < minimum.y:
		return REFUSE_PANEL_TOO_SMALL
	return REFUSE_NONE


static func rects_into(frame: int, panel_size: Vector2, out: Array[Rect2]) -> bool:
	"""Fill `out` with the eight piece rectangles, in piece order, in panel-local pixels.

	Returns false and leaves `out` untouched when the frame is unknown or the panel is too
	small to hold its own corners; `refusal_for()` names which. Construction-time only -- it
	sizes `out` once and is never called from a per-frame path.
	"""
	if refusal_for(frame, panel_size) != REFUSE_NONE:
		return false
	if out.size() != PIECE_COUNT:
		out.resize(PIECE_COUNT)
	_corner_rects_into(frame, panel_size, out)
	_edge_rects_into(frame, panel_size, out)
	return true


static func _corner_rects_into(frame: int, panel_size: Vector2, out: Array[Rect2]) -> void:
	"""Place the four corners flush into the four corners of the panel, unscaled."""
	var tl: Vector2 = Vector2(UiArt.frame_corner_size(frame, CORNER_TL))
	var tr: Vector2 = Vector2(UiArt.frame_corner_size(frame, CORNER_TR))
	var bl: Vector2 = Vector2(UiArt.frame_corner_size(frame, CORNER_BL))
	var br: Vector2 = Vector2(UiArt.frame_corner_size(frame, CORNER_BR))
	out[PIECE_CORNER_TL] = Rect2(Vector2.ZERO, tl)
	out[PIECE_CORNER_TR] = Rect2(Vector2(panel_size.x - tr.x, 0.0), tr)
	out[PIECE_CORNER_BL] = Rect2(Vector2(0.0, panel_size.y - bl.y), bl)
	out[PIECE_CORNER_BR] = Rect2(panel_size - br, br)


static func _edge_rects_into(frame: int, panel_size: Vector2, out: Array[Rect2]) -> void:
	"""Run each strip between the two corners that bracket it, at its declared thickness."""
	var tl: Vector2 = out[PIECE_CORNER_TL].size
	var tr: Vector2 = out[PIECE_CORNER_TR].size
	var bl: Vector2 = out[PIECE_CORNER_BL].size
	var br: Vector2 = out[PIECE_CORNER_BR].size
	var top: float = float(UiArt.frame_edge_inset(frame, SIDE_TOP))
	var right: float = float(UiArt.frame_edge_inset(frame, SIDE_RIGHT))
	var bottom: float = float(UiArt.frame_edge_inset(frame, SIDE_BOTTOM))
	var left: float = float(UiArt.frame_edge_inset(frame, SIDE_LEFT))
	out[PIECE_EDGE_TOP] = Rect2(tl.x, 0.0, panel_size.x - tl.x - tr.x, top)
	out[PIECE_EDGE_BOTTOM] = Rect2(
		bl.x, panel_size.y - bottom, panel_size.x - bl.x - br.x, bottom)
	out[PIECE_EDGE_LEFT] = Rect2(0.0, tl.y, left, panel_size.y - tl.y - bl.y)
	out[PIECE_EDGE_RIGHT] = Rect2(
		panel_size.x - right, tr.y, right, panel_size.y - tr.y - br.y)
