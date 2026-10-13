extends Node3D
## THE LEVEL'S EARTH, CUT AWAY (decision 1913; decision 1912's proof of concept; the EG2 study's readable cutaway).
## The level shown is drawn as a block of earth whose top is the level's floor plane -- the plane the player paints
## on and picks cells from (demo_build_paint.gd), so nothing painted floats -- with every dug cell a PIT DEPTH_M deep
## cut into it: a floor of packed earth and earth walls where dug space meets earth, in the planner's own surface
## materials (modular_materials.gd: the unexcavated top darker, the dug faces as dug), with a soft shade along each
## wall's foot and a dark lip along each cut edge. The top is on its own layer (TOP_LAYER) so the dug view's sun
## (demo_build_dug.gd) lights only what was dug and the earth's top takes a dim fill: the rooms stand out of the mass.
##
## THE ACTUAL WORLD. The top is the World's ground as the World view's section draws it at a level
## (modular_world_view.gd `_kind_at`: land, or the deep protected water columns in their own flat marks), read once per
## tile from the settlement's World (demo_build_world.gd `section_kinds`); with no World it is all earth. It replaces
## the section's own plane in the build view, which cannot be cut (decision 1913 E1).
##
## THE CELLS (demo_build_works.gd), told apart by shape and by words, never by colour alone:
##   EARTH     the top, plain;
##   ORDERED   the top, each cell pegged out in chalk (and named "Waiting for the mole" by the dug view);
##   DIGGING   the one cell being dug: a pit that deepens as the dig goes on (`set_progress`), named "Digging";
##   OPEN      a pit.
## Rebuilt when the works, the level or the cell being dug change; per frame only the digging pit's scale moves.
## Presentation only.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Quads := preload("res://demo/build_panel/demo_build_quads.gd")
const Materials := preload("res://demo/burrow/modular_materials.gd")
const WorldView := preload("res://demo/burrow/modular_world_view.gd")
const World := preload("res://scripts/core/world_init.gd")

const LAYER: int = 256
## The earth's top: drawn with the marks layer (demo_build_world.gd SHOWN_MASK), lit apart from it.
const TOP_LAYER: int = 512
## How deep a dug cell is drawn (decision 1912 E10: rooms are 1 m, decision 1932's one quantum).
const DEPTH_M: float = 1.0
const DEPTH_U: int = 1024
## A cell's side (u): the planner's 1 m grid.
const CELL_U: int = 1024
const UNITS_PER_M: float = 1024.0
## modular_surface.gdshader reads the vertex colour: red is a dug (finished) face, anything else the unexcavated earth.
const DUG: Color = Color(1.0, 0.0, 0.0)
const UNDUG: Color = Color(1.0, 1.0, 1.0)
## The shade at a wall's foot (SHADE_M wide, fading out) and the lip along a cut edge (LIP_M wide).
const SHADE: Color = Color(0.03, 0.02, 0.01, 0.5)
const SHADE_M: float = 0.42
const LIP: Color = Color(0.05, 0.035, 0.02, 0.75)
const LIP_M: float = 0.07
## An ordered cell's chalk: a square CHALK_M wide, CHALK_INSET_M inside the cell's edges.
const CHALK: Color = Color(0.93, 0.88, 0.74, 0.32)
const CHALK_M: float = 0.06
const CHALK_INSET_M: float = 0.14
const LIFT_M: float = 0.006
## How far the earth's top runs on past the planning area's edge (m), and the colour water is marked in: the legacy
## cap's water hue (underground_cap.gdshader `water_colour`), darkened to sit below the earth (unshaded, it glared).
const APRON_M: float = 96.0
const WATER: Color = Color(0.085, 0.12, 0.155)
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NO_CELL: Vector3i = Vector3i(-1, 0, 0)

var _datum_u: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
## Per row of cells: [x from, x to, kind] triples of the World's section kinds (one run of LAND with no World).
var _runs: Array[PackedInt32Array] = []
var _surfaces: Materials = Materials.new()
var _wet: Dictionary = {}
var _marks_material: StandardMaterial3D = null
var _top: MeshInstance3D = null
var _dug: MeshInstance3D = null
var _marks: MeshInstance3D = null
## The cell being dug: its walls and floor on the earth's sides (scaled by the dig's progress), and its steps down to
## dug neighbours (scaled by what is left).
var _pit: MeshInstance3D = null
var _step: MeshInstance3D = null
var _digging: Vector3i = NO_CELL
## Rebuilds since configure, and the last one's quads: the top, the dug floors, the walls, the marks (checks).
var rebuilds: int = 0
var top_quads: int = 0
var floor_quads: int = 0
var wall_quads: int = 0
var mark_quads: int = 0


func configure(datum_u: Vector2i, bounds: Rect2i) -> void:
	"""Cells from `datum_u` (x, z in u) over `bounds`; all earth until `set_kinds`."""
	name = "BuildEarth"
	_datum_u = datum_u
	_bounds = bounds
	_marks_material = StandardMaterial3D.new()
	_marks_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marks_material.vertex_color_use_as_albedo = true
	_marks_material.vertex_color_is_srgb = true
	_marks_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marks_material.render_priority = 1
	_top = _node(TOP_LAYER, true)
	_dug = _node(LAYER, true)
	_marks = _node(LAYER, false)
	_pit = _node(LAYER, true)
	_step = _node(LAYER, true)
	set_kinds(PackedByteArray())


func _node(layer: int, shadows: bool) -> MeshInstance3D:
	"""One mesh node on `layer`, casting shadows or not."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.layers = layer
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func set_kinds(tile_kinds: PackedByteArray) -> void:
	"""The World's section kind per tile (World.TILE_COUNT bytes; empty: all earth): the rows' runs, worked out once."""
	_runs.clear()
	for z: int in range(_bounds.position.y, _bounds.end.y):
		_runs.append(_row_runs(tile_kinds, z))


func _row_runs(tile_kinds: PackedByteArray, z: int) -> PackedInt32Array:
	"""Row `z`'s runs of one kind ([from, to, kind] triples)."""
	var out: PackedInt32Array = PackedInt32Array()
	var tile_z: int = _tile_of(_datum_u.y, z)
	var known: bool = tile_kinds.size() == World.TILE_COUNT and tile_z >= 0 and tile_z < World.MAP_TILES_Z
	var last_tile: int = -1
	var kind: int = World.TERRAIN_LAND
	for x: int in range(_bounds.position.x, _bounds.end.x):
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


func draw(works: Works, level: int, top_m: float, dig_cell: Vector3i) -> void:
	"""Rebuild `level`'s earth with its top at `top_m`, `dig_cell` (level, x, z; NO_CELL: none) the cell being dug."""
	rebuilds += 1
	_digging = dig_cell if dig_cell.x == level else NO_CELL
	var box: Rect2i = works.box_of(level)
	var top: Quads = Quads.new()
	var wet: Dictionary = {}
	for row: int in _runs.size():
		_row(works, level, _bounds.position.y + row, box, top, wet, top_m)
	_apron(top, top_m)
	var cut: Array[Quads] = [Quads.new(), Quads.new(), Quads.new()]
	_cuts(works, level, box, top_m, cut)
	var top_drawn: ArrayMesh = ArrayMesh.new()
	top.commit(top_drawn, _surfaces.material(Materials.EARTH, Materials.FLOOR))
	for kind: int in wet:
		(wet[kind] as Quads).commit(top_drawn, _wet_material(kind))
	_top.mesh = top_drawn
	var dug_mesh: ArrayMesh = ArrayMesh.new()
	cut[0].commit(dug_mesh, _surfaces.material(Materials.EARTH, Materials.FLOOR))
	cut[1].commit(dug_mesh, _surfaces.material(Materials.EARTH, Materials.WALL))
	_dug.mesh = dug_mesh
	var marks_mesh: ArrayMesh = ArrayMesh.new()
	cut[2].commit(marks_mesh, _marks_material)
	_marks.mesh = marks_mesh
	top_quads = top.count()
	floor_quads = cut[0].count()
	wall_quads = cut[1].count()
	mark_quads = cut[2].count()
	_draw_digging(works, level, top_m)


func _row(works: Works, level: int, z: int, box: Rect2i, top: Quads, wet: Dictionary, y: float) -> void:
	"""Row `z`'s top: each run whole outside the works' box, cell by cell inside it (a dug cell is a hole)."""
	var runs: PackedInt32Array = _runs[z - _bounds.position.y]
	var inside: bool = z >= box.position.y and z < box.end.y
	for at: int in range(0, runs.size(), 3):
		var target: Quads = top if runs[at + 2] == World.TERRAIN_LAND else _wet_quads(wet, runs[at + 2])
		if not inside:
			_strip(target, runs[at], runs[at + 1], z, y)
			continue
		_strip(target, runs[at], mini(runs[at + 1], box.position.x), z, y)
		_strip(target, maxi(runs[at], box.end.x), runs[at + 1], z, y)
		var from: int = -1
		for x: int in range(maxi(runs[at], box.position.x), mini(runs[at + 1], box.end.x) + 1):
			var hole: bool = x >= mini(runs[at + 1], box.end.x) or _is_hole(works, level, Vector2i(x, z))
			if hole and from >= 0:
				_strip(target, from, x, z, y)
				from = -1
			elif not hole and from < 0:
				from = x


func _is_hole(works: Works, level: int, cell: Vector2i) -> bool:
	"""Whether the top is cut away at `cell`: dug, or being dug."""
	return works.state(level, cell) == Works.OPEN or Vector3i(level, cell.x, cell.y) == _digging


static func _wet_quads(wet: Dictionary, kind: int) -> Quads:
	"""The quads of one wet kind (made on first use)."""
	if not wet.has(kind):
		wet[kind] = Quads.new()
	return wet[kind]


func _wet_material(kind: int) -> Material:
	"""The World view's own matte mark for a wet kind (made once), drawn flat in WATER: lit by nothing, its own
	near-black ink read as a hole in the earth."""
	if not _wet.has(kind):
		var mark: StandardMaterial3D = WorldView._wet_projection_material(kind)
		mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mark.albedo_color = WATER
		_wet[kind] = mark
	return _wet[kind]


func _apron(top: Quads, y: float) -> void:
	"""The earth's top carried APRON_M past each edge of the planning area, so the map's edge never reads as a hole in
	the cutaway (nothing is painted or picked there: the cells stop at the edge)."""
	var low: Vector3 = _corner(_bounds.position, y)
	var high: Vector3 = _corner(_bounds.end, y)
	var out_low: Vector3 = low - Vector3(APRON_M, 0.0, APRON_M)
	var out_high: Vector3 = high + Vector3(APRON_M, 0.0, APRON_M)
	var bands: Array = [[out_low, Vector3(out_high.x, y, low.z)], [Vector3(out_low.x, y, high.z), out_high],
		[Vector3(out_low.x, y, low.z), Vector3(low.x, y, high.z)],
		[Vector3(high.x, y, low.z), Vector3(out_high.x, y, high.z)]]
	for band: Array in bands:
		var a: Vector3 = band[0]
		var c: Vector3 = band[1]
		top.quad(a, Vector3(c.x, y, a.z), c, Vector3(a.x, y, c.z), Vector3.UP, UNDUG)


func _strip(quads: Quads, from: int, to: int, z: int, y: float) -> void:
	"""Cells `from` to `to` (not included) of row `z` as one quad of the top at `y` (nothing when empty)."""
	if to <= from:
		return
	var west: Vector3 = _corner(Vector2i(from, z), y)
	var east: Vector3 = _corner(Vector2i(to, z + 1), y)
	quads.quad(west, Vector3(east.x, y, west.z), east, Vector3(west.x, y, east.z), Vector3.UP, UNDUG)


func _cuts(works: Works, level: int, box: Rect2i, y: float, into: Array[Quads]) -> void:
	"""Each dug cell's floor, walls, shade and lips, and each ordered cell's chalk (`into`: floors, walls, marks)."""
	for z: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var cell: Vector2i = Vector2i(x, z)
			var state: int = works.state(level, cell)
			if state == Works.ORDERED and Vector3i(level, x, z) != _digging:
				_chalk(into[2], cell, y + LIFT_M)
			elif state == Works.OPEN:
				_dug_cell(works, level, cell, y, into)


func _dug_cell(works: Works, level: int, cell: Vector2i, y: float, into: Array[Quads]) -> void:
	"""One dug cell: its floor (unless a way goes down through it), and a wall, shade and lip on each earth side."""
	var floor_y: float = y - DEPTH_M
	if not stairs_down_at(works, level, cell):
		var low: Vector3 = _corner(cell, floor_y)
		var high: Vector3 = _corner(cell + Vector2i.ONE, floor_y)
		into[0].quad(low, Vector3(high.x, floor_y, low.z), high, Vector3(low.x, floor_y, high.z), Vector3.UP, DUG)
	for side: int in SIDES.size():
		var beside: Vector2i = cell + SIDES[side]
		if _is_hole(works, level, beside):
			continue
		var ends: Array[Vector3] = _edge(cell, side, y)
		var inward: Vector3 = -Vector3(SIDES[side].x, 0.0, SIDES[side].y)
		var down: Vector3 = Vector3(0.0, -DEPTH_M, 0.0)
		into[1].quad(ends[0] + down, ends[1] + down, ends[1], ends[0], inward, DUG)
		_shade(into[2], ends, inward, floor_y - y + LIFT_M)
		var lip: Vector3 = -inward * LIP_M + Vector3(0.0, LIFT_M, 0.0)
		into[2].quad(ends[0] + Vector3(0.0, LIFT_M, 0.0), ends[1] + Vector3(0.0, LIFT_M, 0.0), ends[1] + lip,
			ends[0] + lip, Vector3.UP, LIP)


func _edge(cell: Vector2i, side: int, y: float) -> Array[Vector3]:
	"""The two top corners of `cell`'s edge on `side` (SIDES order: north, east, south, west)."""
	var corners: Array[Vector2i] = [cell, cell + Vector2i(1, 0), cell + Vector2i.ONE, cell + Vector2i(0, 1)]
	return [_corner(corners[side], y), _corner(corners[(side + 1) % 4], y)]


static func _shade(marks: Quads, ends: Array[Vector3], inward: Vector3, drop: float) -> void:
	"""The shade along a wall's foot, `drop` below its top ends, fading out SHADE_M into the room."""
	var a: Vector3 = ends[0] + Vector3(0.0, drop, 0.0)
	var b: Vector3 = ends[1] + Vector3(0.0, drop, 0.0)
	var clear: Color = Color(SHADE, 0.0)
	marks.shaded(a, b, b + inward * SHADE_M, a + inward * SHADE_M, Vector3.UP,
		PackedColorArray([SHADE, SHADE, clear, clear]))


func _chalk(marks: Quads, cell: Vector2i, y: float) -> void:
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
		if works.way_level(row) == level and Rect2i(at, Vector2i(2, 2)).has_point(cell) and way_open(works, row):
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


func _draw_digging(works: Works, level: int, y: float) -> void:
	"""The cell being dug: its earth-side walls and floor (`_pit`), and its steps down to dug neighbours (`_step`)."""
	_pit.visible = _digging != NO_CELL
	_step.visible = _pit.visible
	if not _pit.visible:
		return
	var cell: Vector2i = Vector2i(_digging.y, _digging.z)
	var pit: Quads = Quads.new()
	var step: Quads = Quads.new()
	pit.quad(Vector3(0, -1, 0), Vector3(1, -1, 0), Vector3(1, -1, 1), Vector3(0, -1, 1), Vector3.UP, DUG)
	for side: int in SIDES.size():
		var ends: Array[Vector3] = _unit_edge(side)
		var inward: Vector3 = -Vector3(SIDES[side].x, 0.0, SIDES[side].y)
		var dug: bool = works.state(level, cell + SIDES[side]) == Works.OPEN
		var up: Vector3 = Vector3(0.0, 1.0, 0.0)
		if dug:
			step.quad(ends[0], ends[1], ends[1] + up, ends[0] + up, -inward, DUG)
		else:
			pit.quad(ends[0] - up, ends[1] - up, ends[1], ends[0], inward, DUG)
	_pit.mesh = _commit(pit)
	_step.mesh = _commit(step)
	_pit.position = _corner(cell, y)
	_step.position = _pit.position - Vector3(0.0, DEPTH_M, 0.0)


static func _unit_edge(side: int) -> Array[Vector3]:
	"""The two corners of a 1 m cell's edge on `side` in the cell's own frame, at its top."""
	var corners: Array[Vector3] = [Vector3.ZERO, Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]
	return [corners[side], corners[(side + 1) % 4]]


func _commit(quads: Quads) -> ArrayMesh:
	"""`quads` as a mesh in the dug wall's surface."""
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, _surfaces.material(Materials.EARTH, Materials.WALL))
	return mesh


func set_progress(share: float) -> void:
	"""How far the cell being dug has gone (0-1): its pit deepens, its steps down shrink. A transform, no rebuild."""
	var dug: float = dug_depth_m(share)
	_pit.scale = Vector3(1.0, dug, 1.0)
	_step.scale = Vector3(1.0, DEPTH_M - dug, 1.0)


func top_mesh() -> ArrayMesh:
	"""The earth's top as last drawn (checks)."""
	return _top.mesh as ArrayMesh


func digging_nodes() -> Array[MeshInstance3D]:
	"""The cell being dug's pit and its steps down (checks)."""
	return [_pit, _step]


static func dug_depth_m(share: float) -> float:
	"""How deep the cell being dug is drawn at `share` (0-1) of its dig (never quite flat nor quite through)."""
	return clampf(share, 0.04, 0.96) * DEPTH_M


func digging() -> Vector3i:
	"""The cell drawn as being dug (checks; NO_CELL: none)."""
	return _digging


func _corner(cell: Vector2i, y: float) -> Vector3:
	"""A cell corner in metres at height `y`."""
	return Vector3(_datum_u.x / UNITS_PER_M + cell.x, y, _datum_u.y / UNITS_PER_M + cell.y)
