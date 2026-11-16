extends Node3D
## THE LEVEL'S EARTH, CUT AWAY (decision 1913; its walls rounded and hand-dug, decision 1914; decision 1912's proof of
## concept). The level shown is drawn as a block of earth whose top is the level's floor plane -- the plane the player
## paints on and picks cells from (demo_build_paint.gd), so nothing painted floats -- with the dug space a DEPTH_M
## pit in it. Rooms stay on the 1 m grid for every rule; only the drawing of dug space is rounded:
##   THE FLOORS  every dug cell's whole floor, flat at DEPTH_M (rule a: never hide a usable cell);
##   THE WALLS   the earth round the dug cells as patches of a smooth heightfield (demo_build_burrow_field.gd): the
##               outline smoothed and carried outward, convex corners rounding into the earth and passage mouths
##               flaring, the section coved, the contour wobbled by fixed noise;
##   THE TOP     plain quads everywhere else, and APRON_M past the planning area so its edge never reads as a hole.
## One surface (build_burrow.gdshader) draws all three in world metres, the bought floor and wall textures where staged
## (`set_textures`) and the procedural packed earth where not (CI); the dug view's sun lights what is cut and its fill
## the uncut top. The mesh is on the dug layer and the top's (LAYER | TOP_LAYER) so both lights reach it.
##
## THE ACTUAL WORLD. The top is the World's ground as the World view's section draws it at a level
## (modular_world_view.gd `_kind_at`: land, or the deep protected water columns in their own flat marks), read once per
## tile from the settlement's World (demo_build_world.gd `section_kinds`); with no World it is all earth. It replaces
## the section's own plane in the build view, which cannot be cut (decision 1913 E1).
##
## THE CELLS (demo_build_works.gd), told apart by shape and by words, never by colour alone:
##   EARTH     the top, plain (rounded into beside a dug cell);
##   ORDERED   the top, square, each cell pegged out in chalk (rule b: plan in squares; never rounded into);
##   DIGGING   the one cell being dug: it deepens as the dig goes on (`set_progress`: a uniform, no rebuild), and the
##             rounding round it grows with it;
##   OPEN      dug: floor, the rounded walls round it.
## Rebuilt only when the works, the level or the cell being dug change; never per frame. Presentation only.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Quads := preload("res://demo/build_panel/demo_build_quads.gd")
const WorldView := preload("res://demo/burrow/modular_world_view.gd")
const World := preload("res://scripts/core/world_init.gd")
const Field := preload("res://demo/build_panel/demo_build_burrow_field.gd")
const Burrow := preload("res://demo/build_panel/demo_build_burrow.gd")
const BurrowShader := preload("res://demo/build_panel/build_burrow.gdshader")

const LAYER: int = 256
## The earth's top: drawn with the marks layer (demo_build_world.gd SHOWN_MASK), lit by the fill.
const TOP_LAYER: int = 512
## How deep a dug cell is drawn (decision 1912 E10: rooms are 1 m, decision 1932's one quantum).
const DEPTH_M: float = 1.0
const DEPTH_U: int = 1024
## A cell's side (u): the planner's 1 m grid.
const CELL_U: int = 1024
const UNITS_PER_M: float = 1024.0
## An ordered cell's chalk: a square CHALK_M wide, CHALK_INSET_M inside the cell's edges.
const CHALK: Color = Color(0.93, 0.88, 0.74, 0.32)
const CHALK_M: float = 0.06
const CHALK_INSET_M: float = 0.14
const LIFT_M: float = 0.006
## How far the earth's top runs on past the planning area's edge (m), and the colour water is marked in: the legacy
## cap's water hue (underground_cap.gdshader `water_colour`), darkened to sit below the earth (unshaded, it glared).
const APRON_M: float = 96.0
const WATER: Color = Color(0.085, 0.12, 0.155)
## The staged textures' tiling (metres a texture spans: each holds two repeats) and the unexcavated top's darkening;
## with no floor texture, modular_surface.gdshader's own darkening of undug earth.
const FLOOR_TILE_M: float = 4.0
const WALL_TILE_M: float = 2.0
const TOP_TINT: Color = Color(0.72, 0.68, 0.64)
const PROCEDURAL_TOP_TINT: Color = Color(0.66, 0.66, 0.66)
## The floor grid's strength while the Rooms or Furnish tab is open: fainter than the ghosts' own grid lines
## (demo_build_ghost.gd LINE_ALPHA 0.23), as it is lit with the floor; enough that the dug floor still reads in cells.
const GRID_ALPHA: float = 0.15
## Where the dug view's fill shines from (demo_build_dug.gd): the surface tells it from the sun by this.
const FILL_TOWARD: Vector3 = Vector3(0.0, 1.0, 0.01)
## How far round the works the field holds cells: a wall patch is within one cell of a dug cell and reads its own
## neighbours' neighbours (demo_build_burrow_field.gd REACH).
const REACH_CELLS: int = Field.REACH + 1
const NO_CELL: Vector3i = Vector3i(-1, 0, 0)
## Where a patch's signature puts the cell being dug when there is none: past the reach it reads.
const NOT_NEAR: Vector2i = Vector2i(Field.REACH + 1, 0)
## No level's top: far above any (the patch cache is kept for one top at a time).
const NO_TOP_M: float = 1.0e9
## Points a check samples across a cell, each way (its edges and corners included).
const CHECK_POINTS: int = 5

var _datum_u: Vector2i = Vector2i.ZERO
## The planning area and a cell round it: the top is drawn over this, the rounding may reach into its rim.
var _drawn: Rect2i = Rect2i()
## Per row of `_drawn`: [x from, x to, kind] triples of the World's section kinds (one run of LAND with no World).
var _runs: Array[PackedInt32Array] = []
var _surface: ShaderMaterial = null
var _wet: Dictionary = {}
var _marks_material: StandardMaterial3D = null
var _ground: MeshInstance3D = null
var _marks: MeshInstance3D = null
var _digging: Vector3i = NO_CELL
var _top_y: float = 0.0
## The fields of the last draw: the cells as they are, and with the cell being dug dug (null when none).
var _fields: Array = []
## The surfaces of the last draw (checks): the top, the floors, the walls.
var _built: Array[Burrow] = []
## Which cells are wet (1) and which are drawn by a wall patch (1), over the last draw's field box.
var _wet_cells: PackedByteArray = PackedByteArray()
var _patched: PackedByteArray = PackedByteArray()
## Each wall patch made, by cell: [its neighbourhood's signature, the patch]. A patch depends only on the kinds of the
## 5 × 5 cells round it (and where the cell being dug is among them), so a dig remakes only the patches round it.
## Forgotten when the level's top moves (NO_TOP_M: none drawn yet).
var _patch_cache: Dictionary = {}
## The patches the build in hand uses: the cache becomes these when it is done (review M-d: patches no longer drawn
## are dropped, so a heavily dug level keeps only its walls).
var _patches_used: Dictionary = {}
var _cache_top: float = NO_TOP_M
## THE REBUILD (decision 1914 E6). `draw` reads the works on the main thread (`_prepare`: a copy of the level's
## states, its box, the ways), builds the fields, the surfaces' arrays and the chalk (`_build`) and shows them
## (`_commit`). With `threaded` (the live demo) `request` runs `_build` on a WorkerThreadPool task and `poll` shows it
## when done; `_build` touches only what `_prepare` set and the patch cache, which nothing else touches while it runs.
## What `_prepare` read, what `_build` made, and what is shown: the surfaces and the cell being dug.
var threaded: bool = false
var _task: int = -1
var _wanted: Array = []
var _held_share: bool = false
var _level: int = -1
var _states: PackedByteArray = PackedByteArray()
var _area: Rect2i = Rect2i()
var _box: Rect2i = Rect2i()
var _stairs: Array[Rect2i] = []
var _heads: Array[Vector2i] = []
var _built_arrays: Array = []
var _chalk_quads: Quads = Quads.new()
var _wet_quads: Dictionary = {}
var _shown: Array[Burrow] = []
var _shown_digging: Vector3i = NO_CELL
## The floor grid shown, and how far down the cell being dug is drawn (the shader's `dig_share`).
var _grid: bool = false
var _share: float = 0.0
## Rebuilds since configure, the last one's quads and patches, how long the build took, and how long the main thread
## spent on it (checks; decision 1914 times them).
var last_main_usec: int = 0
var rebuilds: int = 0
var top_quads: int = 0
var floor_quads: int = 0
var patch_count: int = 0
var mark_quads: int = 0
var last_build_usec: int = 0
## Wall patches made (not taken from the cache) by the last draw (checks).
var patches_made: int = 0


func configure(datum_u: Vector2i, bounds: Rect2i) -> void:
	"""Cells from `datum_u` (x, z in u) over `bounds`; all earth until `set_kinds`."""
	name = "BuildEarth"
	_datum_u = datum_u
	_drawn = bounds.grow(1)
	_marks_material = StandardMaterial3D.new()
	_marks_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marks_material.vertex_color_use_as_albedo = true
	_marks_material.vertex_color_is_srgb = true
	_marks_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marks_material.render_priority = 1
	_surface = ShaderMaterial.new()
	_surface.shader = BurrowShader
	_surface.set_shader_parameter(&"top_tint", PROCEDURAL_TOP_TINT)
	_surface.set_shader_parameter(&"floor_tile_m", FLOOR_TILE_M)
	_surface.set_shader_parameter(&"wall_tile_m", WALL_TILE_M)
	_surface.set_shader_parameter(&"datum_m", Vector2(datum_u) / UNITS_PER_M)
	_surface.set_shader_parameter(&"water", WATER)
	_surface.set_shader_parameter(&"fill_toward", FILL_TOWARD)
	_surface.set_shader_parameter(&"grid_alpha", 0.0)
	_surface.set_shader_parameter(&"floor_textured", false)
	_surface.set_shader_parameter(&"wall_textured", false)
	_set_share(0.0)
	_ground = _node(LAYER | TOP_LAYER, true)
	_marks = _node(LAYER, false)
	set_kinds(PackedByteArray())
	Field.warm()
	# The cell being dug moves down in the shader, past what the mesh's box holds when nothing is dug yet.
	_ground.extra_cull_margin = DEPTH_M


func _node(layer: int, shadows: bool) -> MeshInstance3D:
	"""One mesh node on `layer`, casting shadows or not."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.layers = layer
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func set_textures(floor_texture: Texture2D, wall_texture: Texture2D) -> void:
	"""Wear the staged textures (null: keep that surface procedural): a uniform each, no rebuild."""
	if floor_texture != null:
		_surface.set_shader_parameter(&"floor_texture", floor_texture)
		_surface.set_shader_parameter(&"floor_textured", true)
		_surface.set_shader_parameter(&"top_tint", TOP_TINT)
	if wall_texture != null:
		_surface.set_shader_parameter(&"wall_texture", wall_texture)
		_surface.set_shader_parameter(&"wall_textured", true)


func surface() -> ShaderMaterial:
	"""The one surface the earth is drawn in (checks)."""
	return _surface


func set_grid(shown: bool) -> void:
	"""Show the faint cell grid on the dug floors (the Rooms and Furnish tabs) or not: a uniform, no rebuild."""
	if shown != _grid:
		_grid = shown
		_surface.set_shader_parameter(&"grid_alpha", GRID_ALPHA if shown else 0.0)


func grid_shown() -> bool:
	"""Whether the floor grid is shown (checks)."""
	return _grid


func set_kinds(tile_kinds: PackedByteArray) -> void:
	"""The World's section kind per tile (World.TILE_COUNT bytes; empty: all earth): the rows' runs, worked out once
	(after any build in flight, which reads them)."""
	finish()
	_runs.clear()
	for z: int in range(_drawn.position.y, _drawn.end.y):
		_runs.append(_row_runs(tile_kinds, z))


func _row_runs(tile_kinds: PackedByteArray, z: int) -> PackedInt32Array:
	"""Row `z`'s runs of one kind ([from, to, kind] triples)."""
	var out: PackedInt32Array = PackedInt32Array()
	var tile_z: int = _tile_of(_datum_u.y, z)
	var known: bool = tile_kinds.size() == World.TILE_COUNT and tile_z >= 0 and tile_z < World.MAP_TILES_Z
	var last_tile: int = -1
	var kind: int = World.TERRAIN_LAND
	for x: int in range(_drawn.position.x, _drawn.end.x):
		var tile_x: int = _tile_of(_datum_u.x, x)
		if tile_x != last_tile:
			last_tile = tile_x
			var on_map: bool = known and tile_x >= 0 and tile_x < World.MAP_TILES_X
			kind = WorldView._kind_at(tile_kinds, tile_x, tile_z, true) if on_map else World.TERRAIN_LAND
		if out.is_empty() or out[out.size() - 1] != kind:
			out.append_array(PackedInt32Array([x, x + 1, kind]))
		else:
			out[out.size() - 2] = x + 1
	return out


static func _tile_of(datum_u: int, cell: int) -> int:
	"""The World tile a cell's west (or north) edge is in."""
	return floori(float(datum_u + cell * CELL_U) / float(World.TILE_SIZE_UNITS))


func _wet_at(cell: Vector2i) -> bool:
	"""Whether `cell` (in the last draw's field) is under one of the World's wet kinds: never dug, never rounded into."""
	if _fields.is_empty():
		return false
	var field: Field = _fields[0]
	var local: Vector2i = cell - field.origin
	if local.x < 0 or local.y < 0 or local.x >= field.size.x or local.y >= field.size.y:
		return false
	return _wet_cells[local.y * field.size.x + local.x] == 1


func draw(works: Works, level: int, top_m: float, dig_cell: Vector3i) -> void:
	"""Rebuild `level`'s earth now with its top at `top_m`, `dig_cell` (level, x, z; NO_CELL: none) the cell being dug
	(any build in flight is finished first and any request waiting dropped: this one is newer)."""
	_wanted = []
	finish()
	var started: int = Time.get_ticks_usec()
	_prepare(works, level, top_m, dig_cell)
	_build()
	_commit()
	last_main_usec = Time.get_ticks_usec() - started


func request(works: Works, level: int, top_m: float, dig_cell: Vector3i) -> void:
	"""Rebuild as `draw` does; when `threaded`, the surfaces are built on a worker and `poll` shows them a frame or two
	later (one build in flight: a request made meanwhile waits, and only the newest is built after it)."""
	if not threaded:
		draw(works, level, top_m, dig_cell)
		return
	if _task >= 0:
		_wanted = [works, level, top_m, dig_cell]
		_held_share = _held_share or _on_level(dig_cell, level) != _shown_digging
		return
	var started: int = Time.get_ticks_usec()
	_prepare(works, level, top_m, dig_cell)
	_held_share = _digging != _shown_digging
	_task = WorkerThreadPool.add_task(_build, false, "BuildEarth")
	last_main_usec = Time.get_ticks_usec() - started


func poll() -> void:
	"""Each frame: show a build that has finished, and start the request waiting for it."""
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	var started: int = Time.get_ticks_usec()
	# A newer request for another cell being dug: the cell this build shows as being dug is dug by now, so it keeps
	# its depth until that request is shown (review M-a: it popped back up to the top for a frame or two).
	_settle(not _wanted.is_empty() and _on_level(_wanted[3], _wanted[1]) != _digging)
	last_main_usec += Time.get_ticks_usec() - started
	if not _wanted.is_empty():
		var wanted: Array = _wanted
		_wanted = []
		request(wanted[0], wanted[1], wanted[2], wanted[3])


func finish() -> void:
	"""Wait for the build in flight and show it, then build any request waiting at once (checks; a harness reads the
	earth as it now stands)."""
	if _task >= 0:
		_settle()
	if not _wanted.is_empty():
		draw(_wanted[0], _wanted[1], _wanted[2], _wanted[3])


func busy() -> bool:
	"""Whether a build is in flight or waiting (checks)."""
	return _task >= 0 or not _wanted.is_empty()


func _settle(keep_hold: bool = false) -> void:
	"""Wait for the task in flight (returns at once when it is done) and show what it built (`keep_hold`: the cell
	being dug keeps its depth)."""
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_commit(keep_hold)


static func _on_level(dig_cell: Vector3i, level: int) -> Vector3i:
	"""`dig_cell` if it is on `level`, else NO_CELL."""
	return dig_cell if dig_cell.x == level else NO_CELL


func _notification(what: int) -> void:
	"""Freed with a build in flight: wait for it, so the worker never reads what is gone."""
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _prepare(works: Works, level: int, top_m: float, dig_cell: Vector3i) -> void:
	"""On the main thread: all the build reads from the works -- a copy of the level's states, its box, the
	stairs down and the cells the stairs up rise into -- so the mole may go on digging while it builds."""
	rebuilds += 1
	_digging = _on_level(dig_cell, level)
	_top_y = top_m
	_level = level
	if _cache_top != top_m:
		_patch_cache.clear()
		_cache_top = top_m
	_states = works.level_states(level)
	_area = works.area()
	_box = works.box_of(level)
	_stairs.clear()
	_heads.clear()
	for row: int in works.way_count():
		if not works.way_live(row) or not way_open(works, row):
			continue
		if works.way_level(row) == level:
			_stairs.append(Rect2i(works.way_cell(row), Vector2i(Works.SIDE, Works.SIDE)))
		if works.landing_of(row).x == level:
			_heads.append_array(works.head_cells(row))


func _build() -> void:
	"""The surfaces, their arrays and the chalk from what `_prepare` read (on a worker when threaded: nothing here is
	touched by the main thread while it runs)."""
	var started: int = Time.get_ticks_usec()
	patches_made = 0
	_fields = _fields_of()
	_built = [Burrow.new(DEPTH_M), Burrow.new(DEPTH_M), Burrow.new(DEPTH_M)]
	_wet_quads = {}
	_patches_used = {}
	_walls_and_floors()
	_patch_cache = _patches_used
	for row: int in _runs.size():
		_row(_drawn.position.y + row, _wet_quads)
	_apron(_built[0])
	_built_arrays = [_built[0].arrays(), _built[1].arrays(), _built[2].arrays()]
	_chalk_quads = _chalk()
	last_build_usec = Time.get_ticks_usec() - started


func _commit(keep_hold: bool = false) -> void:
	"""On the main thread: the built surfaces shown, the cell being dug starting again from the top (unless
	`keep_hold`: a newer request for another cell waits, and the hold stays until it is shown)."""
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface_arrays: Array in _built_arrays:
		Burrow.add_to(mesh, surface_arrays, _surface)
	for kind: int in _wet_quads:
		(_wet_quads[kind] as Quads).commit(mesh, _wet_material(kind))
	_ground.mesh = mesh
	var marks: ArrayMesh = ArrayMesh.new()
	_chalk_quads.commit(marks, _marks_material)
	_marks.mesh = marks
	mark_quads = _chalk_quads.count()
	top_quads = _built[0].count()
	floor_quads = _built[1].count()
	patch_count = _built[2].count()
	_shown = _built
	_shown_digging = _digging
	_surface.set_shader_parameter(&"top_y", _top_y)
	if not keep_hold:
		_held_share = false
		_set_share(0.0)


func _state_at(cell: Vector2i) -> int:
	"""A cell's state in the copy `_prepare` took (EARTH off the planning area)."""
	if not _area.has_point(cell) or _states.is_empty():
		return Works.EARTH
	return _states[(cell.y - _area.position.y) * _area.size.x + cell.x - _area.position.x]


func _fields_of() -> Array:
	"""The field round the works' box -- dug cells DUG; ordered, wet and stair-head cells HARD (the earth a dug way's
	stairs rise into stays square, so the top tread meets the top, neither floating over a rounded wall nor buried in
	one) -- and, with a cell being dug, a second with it dug (empty: nothing ordered or dug)."""
	_wet_cells = PackedByteArray()
	if _box.size == Vector2i.ZERO:
		return []
	var field: Field = Field.new()
	field.setup(_box.grow(REACH_CELLS).intersection(_drawn))
	_wet_cells.resize(field.size.x * field.size.y)
	for z: int in range(field.origin.y, field.origin.y + field.size.y):
		_fill_row(field, z)
	for head: Vector2i in _heads:
		if field.kind_of(head) == Field.EARTH:
			field.set_kind(head, Field.HARD)
	if _digging == NO_CELL:
		return [field]
	var dug: Field = Field.new()
	dug.copy_from(field)
	dug.set_kind(Vector2i(_digging.y, _digging.z), Field.DUG)
	return [field, dug]


func _fill_row(field: Field, z: int) -> void:
	"""Row `z`'s kinds in `field`: dug, planned (ordered, being dug) or wet kept square, or plain earth."""
	var runs: PackedInt32Array = _runs[z - _drawn.position.y]
	var at: int = 0
	var local: int = (z - field.origin.y) * field.size.x - field.origin.x
	for x: int in range(field.origin.x, field.origin.x + field.size.x):
		while x >= runs[at + 1]:
			at += 3
		var wet: bool = runs[at + 2] != World.TERRAIN_LAND
		_wet_cells[local + x] = 1 if wet else 0
		var state: int = _state_at(Vector2i(x, z))
		if state == Works.OPEN:
			field.set_kind(Vector2i(x, z), Field.DUG)
		elif state == Works.ORDERED or wet:
			field.set_kind(Vector2i(x, z), Field.HARD)


func _walls_and_floors() -> void:
	"""Each dug cell's floor and each cell the rounding reaches as a wall patch."""
	_patched = PackedByteArray()
	if _fields.is_empty():
		return
	var field: Field = _fields[0]
	_patched.resize(field.size.x * field.size.y)
	for z: int in range(field.origin.y, field.origin.y + field.size.y):
		_floor_row(field, z, _stairs)
		_wall_row(field, z, _level)


func _floor_row(field: Field, z: int, stairs: Array[Rect2i]) -> void:
	"""Row `z`'s dug floors, as runs (none under a way's stairs down, nor for the cell being dug: it is a patch)."""
	var floor_y: float = _top_y - DEPTH_M
	var from: int = -1
	for x: int in range(field.origin.x, field.origin.x + field.size.x + 1):
		var floor_here: bool = field.kind_of(Vector2i(x, z)) == Field.DUG
		for rect: Rect2i in stairs:
			floor_here = floor_here and not rect.has_point(Vector2i(x, z))
		if floor_here and from < 0:
			from = x
		elif not floor_here and from >= 0:
			_built[1].flat(_corner_xz(Vector2i(from, z)), _corner_xz(Vector2i(x, z + 1)), floor_y, 1.0)
			from = -1


func _wall_row(field: Field, z: int, level: int) -> void:
	"""Row `z`'s wall patches: each cell not dug with a dug neighbour once the cell being dug is dug, and that cell."""
	var last: Field = _fields[_fields.size() - 1]
	for x: int in range(field.origin.x, field.origin.x + field.size.x):
		var cell: Vector2i = Vector2i(x, z)
		if field.kind_of(cell) != Field.DUG and (Vector3i(level, x, z) == _digging or last.near_dug(cell)):
			_patched[(z - field.origin.y) * field.size.x + x - field.origin.x] = 1
			_built[2].add(_patch_of(cell))


func _patch_of(cell: Vector2i) -> Burrow:
	"""Cell `cell`'s wall patch: the one made before if its neighbourhood is the same, else made now."""
	var signature: int = _signature(cell)
	var kept: Array = _patch_cache.get(cell, [])
	if not kept.is_empty() and kept[0] == signature:
		_patches_used[cell] = kept
		return kept[1]
	var piece: Burrow = Burrow.new(DEPTH_M)
	piece.patch(_fields, cell, _corner(cell, _top_y), _wet_at(cell))
	_patches_used[cell] = [signature, piece]
	patches_made += 1
	return piece


func _signature(cell: Vector2i) -> int:
	"""What `cell`'s patch depends on: the field's kinds round it, where the cell being dug is among them, and whether
	it is wet."""
	var dug_at: Vector2i = Vector2i(_digging.y, _digging.z) if _fields.size() > 1 else cell + NOT_NEAR
	return ((_fields[0] as Field).signature(cell, dug_at) << 1) | (1 if _wet_at(cell) else 0)


func _hole(cell: Vector2i) -> bool:
	"""Whether the top is not drawn at `cell`: it is dug, or a wall patch draws it."""
	if _fields.is_empty():
		return false
	var field: Field = _fields[0]
	var local: Vector2i = cell - field.origin
	if local.x < 0 or local.y < 0 or local.x >= field.size.x or local.y >= field.size.y:
		return false
	return field.kind_of(cell) == Field.DUG or _patched[local.y * field.size.x + local.x] == 1


func _row(z: int, wet: Dictionary) -> void:
	"""Row `z`'s top: each run whole outside the field's box, split round the cells drawn dug or as walls inside it."""
	var runs: PackedInt32Array = _runs[z - _drawn.position.y]
	var box: Rect2i = _field_box()
	var inside: bool = z >= box.position.y and z < box.end.y
	for at: int in range(0, runs.size(), 3):
		if not inside:
			_strip(runs[at + 2], runs[at], runs[at + 1], z, wet)
			continue
		_strip(runs[at + 2], runs[at], mini(runs[at + 1], box.position.x), z, wet)
		_strip(runs[at + 2], maxi(runs[at], box.end.x), runs[at + 1], z, wet)
		var end: int = mini(runs[at + 1], box.end.x)
		var from: int = -1
		for x: int in range(maxi(runs[at], box.position.x), end + 1):
			var hole: bool = x >= end or _hole(Vector2i(x, z))
			if hole and from >= 0:
				_strip(runs[at + 2], from, x, z, wet)
				from = -1
			elif not hole and from < 0:
				from = x


func _field_box() -> Rect2i:
	"""The cells the last draw's field holds (empty: none)."""
	if _fields.is_empty():
		return Rect2i()
	var field: Field = _fields[0]
	return Rect2i(field.origin, field.size)


func _strip(kind: int, from: int, to: int, z: int, wet: Dictionary) -> void:
	"""Cells `from` to `to` (not included) of row `z` as one quad of the top: earth, or a wet kind's mark (nothing when
	empty)."""
	if to <= from:
		return
	if kind == World.TERRAIN_LAND:
		_built[0].flat(_corner_xz(Vector2i(from, z)), _corner_xz(Vector2i(to, z + 1)), _top_y, 0.0)
		return
	if not wet.has(kind):
		wet[kind] = Quads.new()
	var west: Vector3 = _corner(Vector2i(from, z), _top_y)
	var east: Vector3 = _corner(Vector2i(to, z + 1), _top_y)
	(wet[kind] as Quads).quad(west, Vector3(east.x, _top_y, west.z), east, Vector3(west.x, _top_y, east.z), Vector3.UP,
		Color.WHITE)


func _wet_material(kind: int) -> Material:
	"""The World view's own matte mark for a wet kind (made once), drawn flat in WATER: lit by nothing, its own
	near-black ink read as a hole in the earth."""
	if not _wet.has(kind):
		var mark: StandardMaterial3D = WorldView._wet_projection_material(kind)
		mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mark.albedo_color = WATER
		_wet[kind] = mark
	return _wet[kind]


func _apron(top: Burrow) -> void:
	"""The earth's top carried APRON_M past each edge of what is drawn, so the map's edge never reads as a hole in the
	cutaway (nothing is painted or picked there: the cells stop at the edge)."""
	var low: Vector2 = _corner_xz(_drawn.position)
	var high: Vector2 = _corner_xz(_drawn.end)
	var out_low: Vector2 = low - Vector2(APRON_M, APRON_M)
	var out_high: Vector2 = high + Vector2(APRON_M, APRON_M)
	top.flat(out_low, Vector2(out_high.x, low.y), _top_y, 0.0)
	top.flat(Vector2(out_low.x, high.y), out_high, _top_y, 0.0)
	top.flat(Vector2(out_low.x, low.y), Vector2(low.x, high.y), _top_y, 0.0)
	top.flat(Vector2(high.x, low.y), Vector2(out_high.x, high.y), _top_y, 0.0)


func _chalk() -> Quads:
	"""Each ordered cell but the one being dug, pegged out in chalk on the top (square: rule b)."""
	var marks: Quads = Quads.new()
	for z: int in range(_box.position.y, _box.end.y):
		for x: int in range(_box.position.x, _box.end.x):
			if _state_at(Vector2i(x, z)) == Works.ORDERED and Vector3i(_level, x, z) != _digging:
				_peg(marks, Vector2i(x, z), _top_y + LIFT_M)
	return marks


func _peg(marks: Quads, cell: Vector2i, y: float) -> void:
	"""An ordered cell pegged out: a chalk square inside its edges."""
	var low: Vector3 = _corner(cell, y) + Vector3(CHALK_INSET_M, 0.0, CHALK_INSET_M)
	var high: Vector3 = _corner(cell + Vector2i.ONE, y) - Vector3(CHALK_INSET_M, 0.0, CHALK_INSET_M)
	for band: Array in [[low, Vector3(high.x, y, low.z + CHALK_M)], [Vector3(low.x, y, high.z - CHALK_M), high],
			[low, Vector3(low.x + CHALK_M, y, high.z)], [Vector3(high.x - CHALK_M, y, low.z), high]]:
		var a: Vector3 = band[0]
		var c: Vector3 = band[1]
		marks.quad(a, Vector3(c.x, y, a.z), c, Vector3(a.x, y, c.z), Vector3.UP, CHALK)


static func stairs_down_at(works: Works, level: int, cell: Vector2i) -> bool:
	"""Whether `cell` is under a way down standing on `level` that is dug through (its stairs are drawn there)."""
	for row: int in works.way_count():
		var at: Vector2i = works.way_cell(row)
		if works.way_live(row) and works.way_level(row) == level and Rect2i(at, Vector2i(2, 2)).has_point(cell) \
				and way_open(works, row):
			return true
	return false


static func way_open(works: Works, row: int) -> bool:
	"""Whether way down `row` is dug through: its landing, and below the surface its own 2 × 2 cells too (a way may
	stand on a passage still waiting for the mole; review M1: its stairs were drawn buried under the earth's top)."""
	if not way_dug(works, row):
		return false
	var top: int = works.way_level(row)
	for offset: Vector2i in Works.QUAD:
		if top >= 1 and works.state(top, works.way_cell(row) + offset) != Works.OPEN:
			return false
	return true


static func way_dug(works: Works, row: int) -> bool:
	"""Whether way down `row`'s landing (its 2 × 2 cells one level down) is all dug."""
	var landing: Vector3i = works.landing_of(row)
	for offset: Vector2i in Works.QUAD:
		if works.state(landing.x, Vector2i(landing.y, landing.z) + offset) != Works.OPEN:
			return false
	return true


func set_progress(share: float) -> void:
	"""How far the cell being dug has gone (0-1): it deepens, the rounding round it grows. A uniform, no rebuild. While
	a build for another cell is in flight the cell shown stays as it was (it was just dug, or the dig stopped)."""
	if not _held_share:
		_set_share(share)


func _set_share(share: float) -> void:
	"""The shader's `dig_share`: how far down the cell being dug is drawn, as a share of DEPTH_M."""
	_share = dug_depth_m(share) / DEPTH_M
	_surface.set_shader_parameter(&"dig_share", _share)


static func dug_depth_m(share: float) -> float:
	"""How deep the cell being dug is drawn at `share` (0-1) of its dig (never quite flat nor quite through)."""
	return clampf(share, 0.04, 0.96) * DEPTH_M


func digging() -> Vector3i:
	"""The cell drawn as being dug (checks; NO_CELL: none)."""
	return _shown_digging


func ground_mesh() -> ArrayMesh:
	"""The earth as last drawn: its top, floors, walls and water marks (checks)."""
	return _ground.mesh as ArrayMesh


func built() -> Array[Burrow]:
	"""The surfaces shown: the top, the floors, the walls (checks)."""
	return _shown


func height_at(point: Vector2) -> float:
	"""The drawn earth's height under `point` (x, z in m) as the dig stands, read from the built vertices: a wall
	patch's, else a floor's, else the top's (NAN: off what is drawn; checks)."""
	var share: float = _share
	if _shown.is_empty():
		return NAN
	for k: int in [2, 1, 0]:
		var y: float = _shown[k].height_at(point, share) if k == 2 else _shown[k].height_at(point)
		if not is_nan(y):
			return y
	return NAN


func cells_off_the_floor(cells: PackedInt32Array) -> int:
	"""How many of `cells` (canonical pairs) are drawn anywhere but at the floor's depth over their closed square,
	sampled CHECK_POINTS each way (checks: rule a, never hide a usable cell)."""
	var off: int = 0
	for at: int in range(0, cells.size(), 2):
		var whole: bool = true
		for k: int in CHECK_POINTS * CHECK_POINTS:
			@warning_ignore("integer_division") var step: Vector2 = Vector2(k % CHECK_POINTS, k / CHECK_POINTS)
			var y: float = height_at(_corner_xz(Vector2i(cells[at], cells[at + 1])) + step / (CHECK_POINTS - 1))
			whole = whole and absf(y - (_top_y - DEPTH_M)) < 0.0001
		off += 0 if whole else 1
	return off


func cells_rounded(cells: PackedInt32Array) -> int:
	"""How many of `cells` are drawn below the top anywhere under their chalk square (checks: rule b, what is planned
	stays square)."""
	var rounded: int = 0
	for at: int in range(0, cells.size(), 2):
		var low: Vector2 = _corner_xz(Vector2i(cells[at], cells[at + 1])) + Vector2.ONE * CHALK_INSET_M
		var flat: bool = true
		for k: int in CHECK_POINTS * CHECK_POINTS:
			@warning_ignore("integer_division") var step: Vector2 = Vector2(k % CHECK_POINTS, k / CHECK_POINTS)
			var y: float = height_at(low + step * (1.0 - 2.0 * CHALK_INSET_M) / (CHECK_POINTS - 1))
			flat = flat and absf(y - _top_y) < 0.0001
		rounded += 0 if flat else 1
	return rounded


func _corner(cell: Vector2i, y: float) -> Vector3:
	"""A cell corner in metres at height `y`."""
	return Vector3(_datum_u.x / UNITS_PER_M + cell.x, y, _datum_u.y / UNITS_PER_M + cell.y)


func _corner_xz(cell: Vector2i) -> Vector2:
	"""A cell corner's x and z in metres."""
	return Vector2(_datum_u.x / UNITS_PER_M + cell.x, _datum_u.y / UNITS_PER_M + cell.y)
