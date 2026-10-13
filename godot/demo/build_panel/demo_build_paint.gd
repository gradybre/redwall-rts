extends Node3D
## PAINTING ON THE LEVEL in the demo (UI-BUILD-010; decisions 1871 and 1912). Draws the pending batch's rooms and the
## stroke in progress on the floor of the ACTUAL underground level shown (demo_build_world.gd), and turns a screen
## point into a cell of the 1 m grid there. Presentation only: cells go into the batch (build_batch.gd), never into
## the world.
##
## THE FLOOR (decision 1912, P-C6 (a)). Each underground level's floor is the settlement's level catalog's
## (`floor_y_u`, 5 m apart: DEC-061 Q6), handed in by the host. A cell is picked where the view ray meets that floor,
## through the planner's own `modular_world_tool.gd ray_pick`; cell (0, 0) starts at the actual space domain's datum
## (P-C5 (a): the shared frame).
##
## THE GHOSTS (demo_build_ghost.gd), on the World view's marks layer. Each pending room is drawn as GROUPS OF ITS
## CELLS BY THEIR CODE (build_cell_validity.gd): the cells that can be built in GOLD, the "No way in" cells dashed in
## WARNING, and each kind of "X" cell hatched in DANGER with its number against the room's reason list -- so a room's
## state is read cell by cell, in words on each group's tag. The stroke (or, before one, the cell under the cursor) is
## drawn the same way by its own pool, whose first ghost also draws the level's 1 m grid while a room type is armed.
## Ghosts are rebuilt only when the batch's revision, the stroke or the cursor moves (an integer compare a frame).
## WAYS DOWN (decision 1912): each pending one is drawn on the level it stands on (on the surface: the village's own
## marks layer) and where it lands, with its validity; while one is being placed the cursor ghost is its 2 × 2 cells,
## judged where they stand (build_batch.gd `judge_item`).

const Ghost := preload("res://demo/build_panel/demo_build_ghost.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const WorldTool := preload("res://demo/burrow/modular_world_tool.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const Layers := preload("res://demo/demo_layers.gd")

## The underground levels painted on (DEC-061 Q6: levels 1-4).
const LEVELS: Array[int] = [1, 2, 3, 4]
## Every level drawn on: the surface too, where the Entrance is placed.
const DRAWN: Array[int] = [0, 1, 2, 3, 4]
const UNITS_PER_M: float = 1024.0
## The World view's marks layer (demo_build_world.gd MARKS_LAYER).
const MARKS_LAYER: int = 256

var _batch: Batch = null
var _camera: Camera3D = null
var _datum_xz: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
## Each level's floor (u), index = level.
var _floors: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
## Per level (index 1-4): the room ghosts' pool, and the stroke's pool (its first ghost owns the grid).
var _ghosts: Array = [[], [], [], [], []]
var _stroke_ghosts: Array = [[], [], [], [], []]
var _seen_revision: int = -1
var _seen_stroke: int = -1
var _seen_cursor: Vector3i = Vector3i(0, 0, -1)
var _seen_level: int = -1
var _cursor: Vector2i = Vector2i.ZERO
var _cursor_level: int = -1
var _armed_type: int = -1
var _placing: bool = false
## Room ghosts and stroke ghosts drawn since configure (checks: a cursor move redraws no room).
var operation_draws: int = 0
var stroke_draws: int = 0


func configure(batch: Batch, camera: Camera3D, datum_xz: Vector2i, bounds: Rect2i, floors: PackedInt32Array) -> StringName:
	"""Paint into `batch`, picking through `camera`; cells from `datum_xz` (u) on `bounds` (cells); `floors[level]` is
	each underground level's floor (u)."""
	name = "BuildPaint"
	_batch = batch
	_camera = camera
	_datum_xz = datum_xz
	_bounds = bounds
	for level: int in DRAWN:
		_floors[level] = floors[level] if level < floors.size() else 0
		var ghost: Ghost = _new_ghost(level, true)
		if ghost == null:
			return &"BUILD_PAINT_GHOST"
		(_stroke_ghosts[level] as Array).append(ghost)
	return &""


func _new_ghost(level: int, owns_grid: bool) -> Ghost:
	"""One ghost on `level`'s floor and the marks layer, hidden (null if the overlay refuses the floor)."""
	var ghost: Ghost = Ghost.new()
	var datum: Vector3i = Vector3i(_datum_xz.x, _floors[level], _datum_xz.y)
	if ghost.configure_ghost(datum, _bounds, MARKS_LAYER if level > 0 else Layers.SURFACE_MARKS, owns_grid) != &"":
		ghost.free()
		return null
	add_child(ghost)
	ghost.visible = false
	return ghost


func floor_u(level: int) -> int:
	"""Level `level`'s floor (u), where the ghost is drawn and the cell is picked (the surface: 0)."""
	return _floors[level] if DRAWN.has(level) else 0


static func paintable(level: int) -> bool:
	"""Whether `level` is painted on (underground levels 1-4)."""
	return LEVELS.has(level)


func pick(screen: Vector2, level: int) -> WorldTool.Pick:
	"""The cell under a screen point on `level`'s floor (modular_world_tool.gd `ray_pick`; the surface's ground plane
	for level 0); not ok off it."""
	if not DRAWN.has(level) or not is_instance_valid(_camera) or not _camera.is_inside_tree():
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
	var at: Vector3 = Vector3((_datum_xz.x + (cell.x + 0.5) * 1024.0) / UNITS_PER_M, floor_u(level) / UNITS_PER_M,
		(_datum_xz.y + (cell.y + 0.5) * 1024.0) / UNITS_PER_M)
	if not is_instance_valid(_camera) or not _camera.is_inside_tree() or _camera.is_position_behind(at):
		return Vector2.INF
	return _camera.unproject_position(at)


func refresh(shown_level: int, active: bool, placing: bool = false) -> void:
	"""Redraw what moved: the room ghosts of the level shown when the batch changed or the level did; its stroke pool
	when the stroke or cursor moved (`placing`: the cursor is a way down's 2 × 2). Other levels' ghosts are hidden
	(only one level is ever drawn)."""
	_placing = placing
	var cursor_key: Vector3i = Vector3i(_cursor.x, _cursor.y,
		(_cursor_level * 64 + _armed_type + 1 + (32 if placing else 0)) if active else -1)
	var level_moved: bool = shown_level != _seen_level
	var batch_moved: bool = _batch.revision != _seen_revision or level_moved
	if not batch_moved and _batch.stroke_revision == _seen_stroke and cursor_key == _seen_cursor:
		return
	_seen_revision = _batch.revision
	_seen_stroke = _batch.stroke_revision
	_seen_cursor = cursor_key
	_seen_level = shown_level
	for level: int in DRAWN:
		var shown: bool = level == shown_level
		if batch_moved:
			_draw_operations(level, shown)
		_draw_stroke(level, shown and active)


func _draw_operations(level: int, shown: bool) -> void:
	"""Each pending room on `level` as its cells' groups (see THE GHOSTS); none when the level is not shown."""
	var pool: Array = _ghosts[level]
	var used: int = 0
	if shown:
		for k: int in _batch.operation_count():
			if _batch.operation_level(k) == level and _batch.operation_cell_count(k) > 0:
				used = _draw_groups(level, pool, used, _batch.operation_cells(k), _batch.operation_cell_codes(k),
					BuildCatalog.type_name(_batch.operation_type(k)))
		used = _draw_items(level, pool, used)
	for at: int in range(used, pool.size()):
		(pool[at] as Ghost).visible = false
	operation_draws += used


func _draw_groups(level: int, pool: Array, used: int, cells: PackedInt32Array, codes: PackedByteArray,
		name_words: String) -> int:
	"""One ghost per code present in `codes` (✓ first, then ! , then each X numbered in order); returns the pool's
	next free slot."""
	var number: int = 0
	for code: int in Cells.CELL_CODES:
		var group: PackedInt32Array = _cells_with(cells, codes, code)
		if group.is_empty():
			continue
		var ghost: Ghost = _pooled(level, pool, used)
		if ghost == null:
			return used
		var kind: int = Cells.kind_of(code)
		number += 1 if kind == Validity.KIND_NOT_POSSIBLE else 0
		ghost.show_cells(group, kind, tag_words(kind, code, name_words, number))
		ghost.visible = true
		used += 1
	return used


func _draw_items(level: int, pool: Array, used: int) -> int:
	"""Each pending way down standing on `level` (its validity and name) or landing there ("lands here")."""
	var items: Items = _batch.items()
	for row: int in items.count():
		var top: int = items.level_of(row)
		if not items.is_live(row) or (top != level and top + 1 != level):
			continue
		var ghost: Ghost = _pooled(level, pool, used)
		if ghost == null:
			return used
		var kind: int = _batch.item_kind(row)
		var words: String = Items.name_of(top) if top == level else "%s lands here" % Items.name_of(top)
		ghost.show_cells(Items.footprint(items.cell_of(row)), kind, "%s %s" % [Validity.glyph(kind), words])
		ghost.visible = true
		used += 1
	return used


static func tag_words(kind: int, code: int, name_words: String, number: int) -> String:
	"""A group's tag: "✓ Kitchen", "! Kitchen: No way in", "X1 Kitchen: Cannot dig here: water"; without a name (the
	stroke's), "" for ✓ and the words alone otherwise."""
	if kind == Validity.KIND_CAN_BUILD:
		return "%s %s" % [Validity.glyph(kind), name_words] if not name_words.is_empty() else ""
	var head: String = Cells.words_of(code).get_slice(":", 0) if code == Cells.CELL_NO_WAY_IN else Cells.words_of(code)
	var who: String = "%s: " % name_words if not name_words.is_empty() else ""
	if kind == Validity.KIND_NOT_POSSIBLE:
		return "%s%d %s%s" % [Validity.glyph(kind), number, who, head]
	return "%s %s%s" % [Validity.glyph(kind), who, head]


static func _cells_with(cells: PackedInt32Array, codes: PackedByteArray, code: int) -> PackedInt32Array:
	"""The cells whose code is `code` (all of them for CELL_OK when no codes are known), canonical."""
	var out: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, cells.size(), 2):
		@warning_ignore("integer_division") var slot: int = at / 2
		var own: int = codes[slot] if slot < codes.size() else Cells.CELL_OK
		if own == code:
			out.append_array(PackedInt32Array([cells[at], cells[at + 1]]))
	return out


func _pooled(level: int, pool: Array, used: int) -> Ghost:
	"""The pool's ghost at `used`, made when the pool is that short (null if the overlay refuses)."""
	if used == pool.size():
		var made: Ghost = _new_ghost(level, false)
		if made == null:
			return null
		pool.append(made)
	return pool[used]


func _draw_stroke(level: int, shown: bool) -> void:
	"""The stroke in progress as its cells' groups (Erase in its own words), or the cursor cell, with the level's grid
	-- on the level shown only."""
	var pool: Array = _stroke_ghosts[level]
	if pool.is_empty():
		return
	var used: int = 0
	if shown:
		used = _stroke_groups(level, pool)
	(pool[0] as Ghost).visible = shown
	for at: int in range(maxi(used, 1), pool.size()):
		(pool[at] as Ghost).visible = false
	stroke_draws += 1


func _stroke_groups(level: int, pool: Array) -> int:
	"""The stroke's groups into the stroke pool (the first ghost, which owns the grid, always used)."""
	if _placing:
		var judged: Array = _batch.judge_item(level, _cursor, -1)
		var words: String = Validity.line(int(judged[0]), String(judged[1]))
		(pool[0] as Ghost).show_cells(Items.footprint(_cursor) if _bounds.has_point(_cursor) else PackedInt32Array(),
			int(judged[0]), "%s: %s" % [Items.name_of(level), words])
		return 1
	if not _batch.stroke_active() or _batch.stroke_level() != level:
		var cursor_cells: PackedInt32Array = PackedInt32Array([_cursor.x, _cursor.y]) if _bounds.has_point(_cursor) \
			else PackedInt32Array()
		(pool[0] as Ghost).show_cells(cursor_cells, Validity.KIND_CAN_BUILD, "")
		return 1
	var cells: PackedInt32Array = _batch.stroke_cells()
	if _batch.stroke_erasing() or (_batch.stroke_kind() == Validity.KIND_NOT_POSSIBLE and _batch.stroke_cell_codes().is_empty()):
		(pool[0] as Ghost).show_cells(cells, _batch.stroke_kind(), "Erase" if _batch.stroke_erasing() else "")
		return 1
	(pool[0] as Ghost).show_cells(PackedInt32Array(), Validity.KIND_CAN_BUILD, "")
	return maxi(_draw_groups(level, pool, 1, cells, _batch.stroke_cell_codes(), ""), 1)


func operation_ghosts(level: int) -> Array:
	"""`level`'s room ghosts (checks)."""
	return _ghosts[level] if DRAWN.has(level) else []


func stroke_ghost(level: int) -> Ghost:
	"""`level`'s grid-owning stroke ghost (checks)."""
	return (_stroke_ghosts[level] as Array)[0] if DRAWN.has(level) else null


func stroke_ghosts(level: int) -> Array:
	"""`level`'s stroke pool (checks)."""
	return _stroke_ghosts[level] if DRAWN.has(level) else []
