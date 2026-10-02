extends Control
## A drawn oak-leaf spray with an acorn, pinned to one corner of a HUD panel. Vector, not raster.
##
## The woodland concept frames its panels with oak leaves and acorns. It may not be cut up for
## runtime use (ART-UI-11), and no paid generation was requested for it, so the spray is DRAWN: two lobed
## leaves built from a parametric outline and one acorn, filled and inked in ART-LOCK-001
## pigments (I06 Leaf and I05 Sage for the leaves, I01 Ink contour, I08 Timber nut, I09 Umber
## cap). The polygons are computed once on construction; `_draw()` runs only when the canvas
## item is redrawn, never per frame.
##
## ART-UI-07/08: it takes no click, no focus and no accessibility node, and `attach()` sits it
## on the panel's outer corner, over the carved frame, so it never covers a control.

const Palette := preload("res://demo/ui/woodland_palette.gd")

## Each spray is named for its corner, so two on one panel never collide into an "@Control@".
const NAME_PREFIX: String = "WoodlandOrnament"

const CORNER_TOP_LEFT: int = 0
const CORNER_TOP_RIGHT: int = 1
const CORNER_BOTTOM_LEFT: int = 2
const CORNER_BOTTOM_RIGHT: int = 3

## The ornament's own square, in logical pixels, and where its stem sits within it.
const SIDE: float = 84.0
const STEM: Vector2 = Vector2(16.0, 16.0)
## How far outside the panel's corner the stem is pinned. Far enough that no leaf or acorn
## reaches past the panel's 8 px padding into a control, its hit area or its focus ring.
const CORNER_OFFSET: float = 12.0
## Leaf outline: samples along the midrib, and the lobes an oak leaf shows down each side.
const LEAF_SAMPLES: int = 28
const LEAF_LOBES: float = 3.5
const LEAF_LENGTH: float = 54.0
const LEAF_WIDTH: float = 0.24
## The two leaves: direction (radians, 0 = along +x) and length scale.
const LEAF_ANGLES: Array[float] = [-0.10, 1.67]
const LEAF_SCALES: Array[float] = [1.0, 0.82]
const OUTLINE_WIDTH: float = 1.4
const ACORN_CENTER: Vector2 = Vector2(23.0, 23.0)
const ACORN_RADIUS: Vector2 = Vector2(6.5, 8.5)
const ACORN_SEGMENTS: int = 18

## Filled outlines and their closed contours, computed once in `_init()`.
var _leaves: Array[PackedVector2Array] = []
var _leaf_loops: Array[PackedVector2Array] = []
var _midribs: Array[PackedVector2Array] = []
var _leaf_fills: Array[Color] = []
var _nut: PackedVector2Array = PackedVector2Array()
var _nut_loop: PackedVector2Array = PackedVector2Array()
var _cap: PackedVector2Array = PackedVector2Array()
var _cap_loop: PackedVector2Array = PackedVector2Array()
var _mirror: Transform2D = Transform2D.IDENTITY
## The bounds of each shape the spray draws, in its own unmirrored coordinates, contour included.
var _shape_bounds: Array[Rect2] = []
var _corner: int = CORNER_TOP_LEFT


func _init() -> void:
	"""Build the spray's polygons once and make the node purely decorative."""
	name = NAME_PREFIX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	accessibility_name = ""
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = Vector2(SIDE, SIDE)
	_leaf_fills = [Palette.LEAF, Palette.LEAF.lerp(Palette.SAGE, 0.45)]
	for index: int in LEAF_ANGLES.size():
		_leaves.append(leaf_outline(LEAF_ANGLES[index], LEAF_LENGTH * LEAF_SCALES[index]))
		_leaf_loops.append(closed(_leaves[index]))
		_midribs.append(_midrib(LEAF_ANGLES[index], LEAF_LENGTH * LEAF_SCALES[index]))
	_nut = _ellipse(ACORN_CENTER + Vector2(0.0, 2.5), ACORN_RADIUS, 0.0, TAU)
	_nut_loop = closed(_nut)
	_cap = _ellipse(ACORN_CENTER - Vector2(0.0, 3.2), ACORN_RADIUS + Vector2(1.6, -3.4), PI, TAU)
	_cap_loop = closed(_cap)
	for shape: PackedVector2Array in [_leaves[0], _leaves[1], _nut, _cap]:
		_shape_bounds.append(_bounds_of(shape).grow(OUTLINE_WIDTH))


func set_corner(corner: int) -> void:
	"""Choose which panel corner the spray grows out of; it is mirrored to face outward."""
	_corner = corner
	name = "%s%d" % [NAME_PREFIX, corner]
	var right: bool = corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT
	var bottom: bool = corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT
	_mirror = Transform2D(Vector2(-1.0 if right else 1.0, 0.0),
		Vector2(0.0, -1.0 if bottom else 1.0),
		Vector2(SIDE if right else 0.0, SIDE if bottom else 0.0))
	queue_redraw()


func _bounds_of(shape: PackedVector2Array) -> Rect2:
	"""The smallest rectangle holding every point of one shape."""
	var bounds: Rect2 = Rect2(shape[0], Vector2.ZERO)
	for point: Vector2 in shape:
		bounds = bounds.expand(point)
	return bounds


func rects_in_panel(panel_size: Vector2) -> Array[Rect2]:
	"""Where each drawn shape lands in its panel's coordinates, for a panel of `panel_size`.

	Computed from the anchors and offsets rather than read from `position`, because anchors
	only resolve against a parent that is inside the tree."""
	var origin: Vector2 = Vector2(anchor_left * panel_size.x + offset_left,
		anchor_top * panel_size.y + offset_top)
	var out: Array[Rect2] = []
	for bounds: Rect2 in _shape_bounds:
		var drawn: Rect2 = _mirror * bounds
		out.append(Rect2(origin + drawn.position, drawn.size))
	return out


func pinned_corner() -> int:
	"""Which panel corner this spray is pinned to."""
	return _corner


static func attach(panel: Control, corner: int) -> Control:
	"""Pin a new ornament to one outer corner of `panel`, following it through any resize."""
	var script: GDScript = load("res://demo/ui/woodland_ornament.gd") as GDScript
	var ornament: Control = script.new() as Control
	ornament.call(&"set_corner", corner)
	var right: bool = corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT
	var bottom: bool = corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT
	var ax: float = 1.0 if right else 0.0
	var ay: float = 1.0 if bottom else 0.0
	ornament.anchor_left = ax
	ornament.anchor_right = ax
	ornament.anchor_top = ay
	ornament.anchor_bottom = ay
	var ox: float = (CORNER_OFFSET + STEM.x - SIDE) if right else -(CORNER_OFFSET + STEM.x)
	var oy: float = (CORNER_OFFSET + STEM.y - SIDE) if bottom else -(CORNER_OFFSET + STEM.y)
	ornament.offset_left = ox
	ornament.offset_top = oy
	ornament.offset_right = ox + SIDE
	ornament.offset_bottom = oy + SIDE
	panel.add_child(ornament)
	return ornament


static func leaf_outline(angle: float, length: float) -> PackedVector2Array:
	"""A lobed oak-leaf outline from the stem along `angle`, both edges in one closed loop."""
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	var along: Vector2 = Vector2.from_angle(angle)
	var across: Vector2 = along.orthogonal()
	for sample: int in LEAF_SAMPLES + 1:
		var t: float = float(sample) / float(LEAF_SAMPLES)
		var envelope: float = pow(sin(PI * pow(t, 0.75)), 0.85)
		var lobe: float = 0.6 + 0.4 * pow(absf(cos(PI * LEAF_LOBES * t)), 0.6)
		var half: float = length * LEAF_WIDTH * envelope * lobe
		var spine: Vector2 = STEM + along * (t * length)
		upper.append(spine + across * half)
		lower.append(spine - across * half)
	lower.reverse()
	upper.append_array(lower)
	return upper


func _midrib(angle: float, length: float) -> PackedVector2Array:
	"""The leaf's central vein, from the stem to just short of the tip."""
	var along: Vector2 = Vector2.from_angle(angle)
	return PackedVector2Array([STEM - along * 3.0, STEM + along * (length * 0.92)])


func _ellipse(center: Vector2, radius: Vector2, start: float, stop: float) -> PackedVector2Array:
	"""Points round an ellipse arc; a half arc closes across its chord when filled."""
	var points: PackedVector2Array = PackedVector2Array()
	for segment: int in ACORN_SEGMENTS + 1:
		var a: float = lerpf(start, stop, float(segment) / float(ACORN_SEGMENTS))
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


func _draw() -> void:
	"""Draw the leaves, then the acorn over their stems, mirrored to face out of the corner."""
	draw_set_transform_matrix(_mirror)
	for index: int in _leaves.size():
		draw_colored_polygon(_leaves[index], _leaf_fills[index])
		draw_polyline(_leaf_loops[index], Palette.INK, OUTLINE_WIDTH, true)
		draw_polyline(_midribs[index], Palette.INK.lerp(Palette.LEAF, 0.4), 1.0, true)
	draw_colored_polygon(_nut, Palette.TIMBER.lerp(Palette.CLAY, 0.35))
	draw_polyline(_nut_loop, Palette.INK, OUTLINE_WIDTH, true)
	draw_colored_polygon(_cap, Palette.UMBER)
	draw_polyline(_cap_loop, Palette.INK, OUTLINE_WIDTH, true)
	draw_circle(ACORN_CENTER + Vector2(-2.3, 4.0), 1.8, Palette.EMBER.lerp(Palette.CREAM, 0.3))
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	"""A copy of a loop with its first point repeated at the end, for an unbroken contour."""
	var loop: PackedVector2Array = points.duplicate()
	if not points.is_empty():
		loop.append(points[0])
	return loop
