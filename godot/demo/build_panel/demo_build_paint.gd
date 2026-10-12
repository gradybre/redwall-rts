extends Node3D
## PAINTING ON THE LEVEL in the demo (UI-BUILD-010; decision 1871). Draws the pending batch's rooms and the stroke in
## progress on the floor of the underground level the U view shows, and turns a screen point into a cell of the 1 m
## grid there. Presentation only: cells go into the batch (build_batch.gd), never into the world.
##
## THE FLOOR. The demo's U view shows the legacy warren's levels (tunnel_view.gd; level 1's floor 1.25 m down, level 2
## the candidate 4 m lower). A cell is picked where the view ray meets the floor the view SHOWS (demo_layers.gd
## `floor_y`) -- what the player sees under the pointer -- through the planner's own `modular_world_tool.gd ray_pick`.
## Its x and z are the cell; the settlement's actual level floors (the level catalog's, used by the order route) differ
## only in height, and a cell is a column. Cell (0, 0) starts at the actual space domain's datum.
##
## THE GHOSTS (demo_build_ghost.gd). Per level: one ghost per pending operation, tinted and tagged with its validity,
## and one for the stroke (or, before a stroke, the cell under the cursor) which also draws the level's 1 m grid while
## a room type is armed. Each on the level's U-view marks layer, so the other level and the surface never show them.
## They are rebuilt only when the batch's revision or the cursor moves (an integer compare a frame otherwise).

const Ghost := preload("res://demo/build_panel/demo_build_ghost.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const WorldTool := preload("res://demo/burrow/modular_world_tool.gd")
const Layers := preload("res://demo/demo_layers.gd")

## The legacy warren's two levels: the only ones the demo can draw on.
const LEVELS: Array[int] = [1, 2]
const UNITS_PER_M: float = 1024.0

var _batch: Batch = null
var _camera: Camera3D = null
var _datum_xz: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
## Per level (index 1, 2): its operation ghosts, and its stroke-and-grid ghost.
var _ghosts: Array = [[], [], []]
var _stroke_ghosts: Array[Ghost] = [null, null, null]
var _seen_revision: int = -1
var _seen_stroke: int = -1
var _seen_cursor: Vector3i = Vector3i(0, 0, -1)
var _cursor: Vector2i = Vector2i.ZERO
var _cursor_level: int = -1
var _armed_type: int = -1
## Ghosts drawn in the last refresh (checks).
var drawn: int = 0


func configure(batch: Batch, camera: Camera3D, datum_xz: Vector2i, bounds: Rect2i) -> StringName:
	"""Paint into `batch`, picking through `camera`; cells from `datum_xz` (u) on `bounds` (cells)."""
	name = "BuildPaint"
	_batch = batch
	_camera = camera
	_datum_xz = datum_xz
	_bounds = bounds
	for level: int in LEVELS:
		var ghost: Ghost = _new_ghost(level, true)
		if ghost == null:
			return &"BUILD_PAINT_GHOST"
		_stroke_ghosts[level] = ghost
	return &""


func _new_ghost(level: int, owns_grid: bool) -> Ghost:
	"""One ghost on `level`'s floor and marks layer, hidden (null if the overlay refuses the floor)."""
	var ghost: Ghost = Ghost.new()
	var datum: Vector3i = Vector3i(_datum_xz.x, floor_u(level), _datum_xz.y)
	if ghost.configure_ghost(datum, _bounds, Layers.marks(level), owns_grid) != &"":
		ghost.free()
		return null
	add_child(ghost)
	ghost.visible = false
	return ghost


static func floor_u(level: int) -> int:
	"""The shown floor of a legacy level, in u (presentation: where the ghost is drawn and the cell is picked)."""
	return roundi(Layers.floor_y(level) * UNITS_PER_M)


static func paintable(level: int) -> bool:
	"""Whether the demo can draw a ghost on `level` (the legacy warren's levels 1 and 2)."""
	return LEVELS.has(level)


func pick(screen: Vector2, level: int) -> WorldTool.Pick:
	"""The cell under a screen point on `level`'s shown floor (modular_world_tool.gd `ray_pick`); not ok off it."""
	if not paintable(level) or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return WorldTool.Pick.new()
	var datum: Vector3i = Vector3i(_datum_xz.x, floor_u(level), _datum_xz.y)
	return WorldTool.ray_pick(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), datum, 1024)


func set_cursor(cell: Vector2i, level: int, armed_type: int) -> void:
	"""Where the cursor cell is (the pointer's, or the arrow keys'), on which level, and the type armed (-1: none)."""
	_cursor = cell
	_cursor_level = level
	_armed_type = armed_type


func cursor() -> Vector2i:
	"""The cursor cell."""
	return _cursor


func screen_of(cell: Vector2i, level: int) -> Vector2:
	"""Where a cell's middle is on screen (the size label stands beside it); INF behind the camera."""
	var at: Vector3 = Vector3((_datum_xz.x + (cell.x + 0.5) * 1024.0) / UNITS_PER_M, Layers.floor_y(level),
		(_datum_xz.y + (cell.y + 0.5) * 1024.0) / UNITS_PER_M)
	if not is_instance_valid(_camera) or not _camera.is_inside_tree() or _camera.is_position_behind(at):
		return Vector2.INF
	return _camera.unproject_position(at)


func refresh(shown_level: int, active: bool) -> void:
	"""Redraw when the batch, the stroke or the cursor moved: every level's operations; the stroke or cursor and
	the grid on the level shown while `active` (the panel open with a type armed)."""
	var cursor_key: Vector3i = Vector3i(_cursor.x, _cursor.y, (_cursor_level * 64 + _armed_type + 1) if active else -1)
	if _batch.revision == _seen_revision and _batch.stroke_revision == _seen_stroke and cursor_key == _seen_cursor:
		return
	_seen_revision = _batch.revision
	_seen_stroke = _batch.stroke_revision
	_seen_cursor = cursor_key
	drawn = 0
	for level: int in LEVELS:
		_draw_operations(level)
		_draw_stroke(level, active and level == shown_level)


func _draw_operations(level: int) -> void:
	"""One ghost per pending operation on `level`, its validity tint and its type and glyph on the tag."""
	var pool: Array = _ghosts[level]
	var used: int = 0
	for k: int in _batch.operation_count():
		if _batch.operation_level(k) != level or _batch.operation_cell_count(k) == 0:
			continue
		if used == pool.size():
			var made: Ghost = _new_ghost(level, false)
			if made == null:
				break
			pool.append(made)
		var ghost: Ghost = pool[used]
		var kind: int = _batch.operation_kind(k)
		ghost.show_cells(_batch.operation_cells(k), kind, "%s %s" % [Validity.glyph(kind), BuildCatalog.type_name(_batch.operation_type(k))])
		ghost.visible = true
		used += 1
	for at: int in range(used, pool.size()):
		(pool[at] as Ghost).visible = false
	drawn += used


func _draw_stroke(level: int, shown: bool) -> void:
	"""The stroke in progress, or the cursor cell, with the level's grid -- on the level shown only."""
	var ghost: Ghost = _stroke_ghosts[level]
	ghost.visible = shown
	if not shown:
		return
	var cells: PackedInt32Array = _batch.stroke_cells() if _batch.stroke_active() and _batch.stroke_level() == level \
		else PackedInt32Array([_cursor.x, _cursor.y])
	var kind: int = _batch.stroke_kind() if _batch.stroke_active() else Validity.KIND_CAN_BUILD
	if not _bounds.has_point(_cursor) and not _batch.stroke_active():
		cells = PackedInt32Array()
	ghost.show_cells(cells, kind, "")
	drawn += 1


func operation_ghosts(level: int) -> Array:
	"""`level`'s operation ghosts (checks)."""
	return _ghosts[level] if paintable(level) else []


func stroke_ghost(level: int) -> Ghost:
	"""`level`'s stroke-and-grid ghost (checks)."""
	return _stroke_ghosts[level] if paintable(level) else null
