extends Node3D
## THE DUG ROOMS, DRAWN (decision 1912's proof of concept; its look, decision 1913). On the level the build panel
## shows (the World view's marks layer, demo_build_world.gd), from demo_build_works.gd:
##   THE EARTH     the level as a cutaway block of earth with the dug cells a pit in it, its walls rounded and hand-dug
##                 (decision 1914), ordered cells pegged out in chalk and the cell being dug deepening as it goes
##                 (demo_build_earth.gd, rebuilt on a worker and shown by `refresh` when done), what was dug lit by
##                 this view's own sun and the earth's top by a dim fill, so the rooms stand out of the mass;
##   WAYS DOWN     where one stands on the level, stairs cut down into the floor; where one lands, stairs rising out of
##                 it (demo_build_ways.gd), once the landing is dug;
##   TAGS          "Way down", "Way up", "Way up to the surface", "Waiting for the mole: N cells", "Digging", in words;
## and on the surface (the village's own layers, seen without the panel) each confirmed Entrance as a burrow mouth named
## "Entrance". Rebuilt only when the works, the level shown or the cell being dug change. The tags are drawn over
## everything with their outline under their text (a tag drawn the other way round read as doubled), and are kept
## off each other by demo_build_tags.gd. Presentation only.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Earth := preload("res://demo/build_panel/demo_build_earth.gd")
const Ways := preload("res://demo/build_panel/demo_build_ways.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Look := preload("res://demo/world/world_look.gd")
const Props := preload("res://demo/props/demo_props.gd")

const LAYER: int = 256
const UNITS_PER_M: float = 1024.0
const TAG_PX: int = 36
const TAG_PRIORITY: int = 5
const TAG_PIXEL: float = 0.01
## A surface tag's size at a constant screen size (tunnel_overlay.gd LABEL_PIXEL).
const SURFACE_TAG_PIXEL: float = 0.0006
const WAITING: String = "Waiting for the mole: %d cells"
const DIGGING: String = "Digging"
## Over the earth's top: a way's name, the waiting cells' and the digging cell's (m).
const WAY_TAG_M: float = 1.1
const WAITING_TAG_M: float = 0.6
const DIGGING_TAG_M: float = 0.5
const ENTRANCE_TAG_M: float = 1.5
## This view's sun, on what was dug: high, from the south-west behind the camera, so the far walls and the floors are
## lit and each cut's west and south edges cast their shade into the room. The earth's top takes only a dim fill from
## straight above (demo_build_earth.gd TOP_LAYER), so the rooms stand out of the mass.
## The build art (decision 1913; demo_props.gd SIZES): the Entrance's burrow mouth and the landings' stair flight.
const MOUTH_KEY: StringName = &"burrow_mouth"
const STAIRS_KEY: StringName = &"dig_stairs"
## A staged flight rises north; turned about its middle and sunk a room's depth it goes down north instead.
const DOWN_TURN: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(Ways.SIDE_M, -Earth.DEPTH_M, Ways.SIDE_M))
## A half turn about a landing's middle: a flight that rises south, turned to rise north.
const HALF_TURN: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(Ways.SIDE_M, 0.0, Ways.SIDE_M))
## How far inside a landing's sides the staged flight is laid (review M3 on b1bb4779: no coplanar faces).
const ART_INSET_M: float = 0.01
const SUN_TOWARD: Vector3 = Vector3(-0.38, 0.8, 0.46)
const SUN_ENERGY: float = 1.7
const FILL_ENERGY: float = 0.22

var earth: Earth = null
var _works: Works = null
var _floors: PackedInt32Array = PackedInt32Array()
var _datum: Vector2i = Vector2i.ZERO
var _sun: DirectionalLight3D = null
var _fill: DirectionalLight3D = null
var _paint: StandardMaterial3D = null
var _mouth: ArrayMesh = null
var _up: ArrayMesh = null
var _down: ArrayMesh = null
var _mouths: Array[MeshInstance3D] = []
var _stairs: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _seen: Vector4i = Vector4i(-1, -1, -1, -1)
var _has_kinds: bool = false
## The level's ordered cells, refilled on a rebuild (demo_build_works.gd `cells_into`: its box only).
var _ordered: PackedInt32Array = PackedInt32Array()
## Rebuilds since configure (checks: nothing is rebuilt on a still frame).
var rebuilds: int = 0
## Which pieces are the staged art (checks): "mouth", "stairs".
var art: PackedStringArray = PackedStringArray()


func configure(works: Works, floors: PackedInt32Array, datum: Vector2i, bounds: Rect2i) -> void:
	"""Draw `works` on `floors` (u per level) from `datum` (u) over `bounds` (cells)."""
	name = "BuildDug"
	_works = works
	_floors = floors
	_datum = datum
	earth = Earth.new()
	earth.configure(datum, bounds)
	add_child(earth)
	_paint = Ways.material()
	_mouth = Ways.mouth_mesh(_paint)
	_up = Ways.stairs_up_mesh(_paint, Earth.DEPTH_M)
	_down = Ways.stairs_down_mesh(_paint)
	_sun = _make_light("BuildDugSun", SUN_TOWARD, SUN_ENERGY, LAYER)
	_sun.shadow_enabled = true
	_sun.shadow_caster_mask = LAYER | Earth.TOP_LAYER
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 80.0
	add_child(_sun)
	_fill = _make_light("BuildDugFill", Earth.FILL_TOWARD, FILL_ENERGY, Earth.TOP_LAYER)
	add_child(_fill)


static func _make_light(title: String, toward: Vector3, energy: float, layers: int) -> DirectionalLight3D:
	"""A light the village sun's colour shining from `toward` on `layers` only (the village above never shades the
	level: only these layers cast its shadows), hidden until a level is shown. The light is itself on `layers`: a
	camera draws only the lights on the layers it draws (the U view draws the marks layers alone)."""
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = title
	light.layers = layers
	light.transform = Transform3D(Basis.looking_at(-toward.normalized(), Vector3.FORWARD), Vector3.ZERO)
	light.light_color = Look.SUN_COLOR
	light.light_energy = energy
	light.light_cull_mask = layers
	light.shadow_caster_mask = layers
	light.visible = false
	return light


func use_props(props: Props) -> void:
	"""Draw the build art where `props` has it staged (decision 1913: the burrow mouth, the stair flight, the earth's
	textures); every piece not staged (CI, a fresh clone) keeps its procedural drawing."""
	if props == null:
		return
	var mouth: Mesh = props.mesh_of(MOUTH_KEY) if props.is_staged(MOUTH_KEY) else null
	var stairs: Mesh = props.mesh_of(STAIRS_KEY) if props.is_staged(STAIRS_KEY) else null
	set_art(mouth, props.fit_of(MOUTH_KEY) if mouth != null else Transform3D.IDENTITY, stairs,
		props.fit_of(STAIRS_KEY) if stairs != null else Transform3D.IDENTITY)
	earth.set_textures(props.build_texture("earth_floor"), props.build_texture("earth_wall"))
	_seen = Vector4i(-1, -1, -1, -1)


func set_art(mouth: Mesh, mouth_fit: Transform3D, stairs: Mesh, stairs_fit: Transform3D) -> void:
	"""The art in place of the procedural mouth (drawn by `mouth_fit`: on the ground, centred) and stairs (laid over a
	landing's 2 × 2 m and the room's rise, rising north; turned and sunk, in its cut, for a way down). A null or flat
	piece is drawn procedurally. Setup only: the meshes are baked once; a second call starts again."""
	art.clear()
	_mouth = Props.transformed(mouth, mouth_fit) if mouth != null else Ways.mouth_mesh(_paint)
	if mouth != null:
		art.append("mouth")
	_up = Ways.stairs_up_mesh(_paint, Earth.DEPTH_M)
	_down = Ways.stairs_down_mesh(_paint)
	if stairs == null or not (stairs_fit * stairs.get_aabb()).has_volume():
		return
	var up_fit: Transform3D = stretched(stairs.get_aabb(), stairs_fit)
	if not rises_north(stairs, up_fit):
		up_fit = HALF_TURN * up_fit
	_up = Props.transformed(stairs, up_fit)
	_down = Props.transformed(stairs, DOWN_TURN * up_fit)
	var cut: ArrayMesh = Ways.cut_mesh(_paint, Earth.DEPTH_M)
	_down.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cut.surface_get_arrays(0))
	_down.surface_set_material(_down.get_surface_count() - 1, _paint)
	art.append("stairs")


static func stretched(bound: AABB, fit: Transform3D) -> Transform3D:
	"""`fit` then a stretch that lays the drawn bound over a landing, ART_INSET_M inside its sides (so no face of the
	art lies on a wall or a cut's side) and from 0 to a room's depth."""
	var drawn: AABB = fit * bound
	var side: float = Ways.SIDE_M - 2.0 * ART_INSET_M
	var stretch: Vector3 = Vector3(side / drawn.size.x, Earth.DEPTH_M / drawn.size.y, side / drawn.size.z)
	var offset: Vector3 = Vector3(ART_INSET_M, 0.0, ART_INSET_M)
	return Transform3D(Basis.from_scale(stretch), offset - drawn.position * stretch) * fit


static func rises_north(mesh: Mesh, at: Transform3D) -> bool:
	"""Whether `mesh` drawn by `at` stands higher on its north half (smaller z) than its south (review M2 on b1bb4779:
	a flight's direction is measured, not assumed)."""
	var middle: float = (at * mesh.get_aabb()).get_center().z
	var sums: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	for surface: int in mesh.get_surface_count():
		var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in points:
			var placed: Vector3 = at * point
			var north: int = 0 if placed.z < middle else 2
			sums[north] += placed.y
			sums[north + 1] += 1.0
	return sums[0] / maxf(sums[1], 1.0) >= sums[2] / maxf(sums[3], 1.0)


func stairs_mesh(up: bool) -> ArrayMesh:
	"""The stairs drawn up out of a landing, or down a way (checks)."""
	return _up if up else _down


func set_kinds(tile_kinds: PackedByteArray) -> void:
	"""The World's ground per tile (demo_build_world.gd `section_kinds`); the level is drawn again."""
	earth.set_kinds(tile_kinds)
	_has_kinds = not tile_kinds.is_empty()
	_seen = Vector4i(-1, -1, -1, -1)


func has_kinds() -> bool:
	"""Whether the World's ground has been handed in."""
	return _has_kinds


func refresh(level: int, digging: Vector3i = Earth.NO_CELL) -> void:
	"""Redraw when the works, the level shown (-1: none) or the cell being dug (level, x, z) changed; each frame, show
	the earth's rebuild once it is done (demo_build_earth.gd `poll`)."""
	earth.poll()
	var below: bool = underground(level)
	var on_level: bool = digging.x == level and below
	var key: Vector4i = Vector4i(_works.revision, level, digging.y if on_level else -1, digging.z if on_level else -1)
	if key == _seen:
		return
	_seen = key
	rebuilds += 1
	earth.visible = below
	_sun.visible = below
	_fill.visible = below
	if below:
		earth.request(_works, level, top_m(level), digging)
	_place_mouths()
	_place_stairs(level)
	_place_tags(level, digging if on_level else Earth.NO_CELL)


func underground(level: int) -> bool:
	"""Whether `level` is an underground level drawn here (1-4; not the surface, nor the bar's Overview)."""
	return level >= 1 and level < _floors.size()


func set_progress(share: float) -> void:
	"""How far the cell being dug has gone (0-1)."""
	earth.set_progress(share)


func top_m(level: int) -> float:
	"""Level `level`'s earth top: its floor plane, where cells are painted and picked (m)."""
	return _floors[level] / UNITS_PER_M


func _place_mouths() -> void:
	"""A burrow mouth on the surface for each confirmed Entrance (not a hatch on a Mound room's floor: the Mound's
	drawing has it, decision 2002)."""
	var used: int = 0
	for row: int in _works.way_count():
		if _works.way_level(row) == 0 and not on_mound(row):
			var mouth: MeshInstance3D = _pooled(_mouths, used, _mouth, Layers.SURFACE)
			mouth.position = _corner(_works.way_cell(row) + Vector2i.ONE, 0.0)
			used += 1
	for k: int in range(used, _mouths.size()):
		_mouths[k].visible = false


func on_mound(row: int) -> bool:
	"""Whether way down `row` stands on a Mound room's floor (decision 2002: the works' Surface cells)."""
	return _works.way_level(row) == 0 and _works.state(0, _works.way_cell(row)) != Works.EARTH


func _place_stairs(level: int) -> void:
	"""Stairs down where a dug way stands on `level`, stairs up where one lands on it."""
	var used: int = 0
	for row: int in _works.way_count():
		var top: int = _works.way_level(row)
		if not underground(level) or (top != level and top + 1 != level) or not Earth.way_open(_works, row):
			continue
		var stairs: MeshInstance3D = _pooled(_stairs, used, _down if top == level else _up, LAYER)
		stairs.position = _corner(_works.way_cell(row), top_m(level) - Earth.DEPTH_M)
		used += 1
	for k: int in range(used, _stairs.size()):
		_stairs[k].visible = false


func _pooled(pool: Array[MeshInstance3D], at: int, mesh: ArrayMesh, layer: int) -> MeshInstance3D:
	"""The pool's node `at` (made when the pool is that short), showing `mesh` on `layer`."""
	if at == pool.size():
		var node: MeshInstance3D = MeshInstance3D.new()
		add_child(node)
		pool.append(node)
	var out: MeshInstance3D = pool[at]
	out.mesh = mesh
	out.layers = layer
	out.visible = true
	return out


func _place_tags(level: int, digging: Vector3i) -> void:
	"""The names, in the order they give way to each other: the cell being dug, the ways, the waiting cells."""
	var used: int = 0
	if digging.x >= 1:
		used = _tag(used, DIGGING, _corner(Vector2i(digging.y, digging.z), top_m(level) + DIGGING_TAG_M) \
			+ Vector3(0.5, 0.0, 0.5), LAYER)
	used = _way_tags(used, level)
	_ordered.clear()
	if underground(level):
		_works.cells_into(level, Works.ORDERED, _ordered)
	if not _ordered.is_empty():
		@warning_ignore("integer_division") var waiting: int = _ordered.size() / 2 - (1 if digging.x >= 1 else 0)
		if waiting > 0:
			used = _tag(used, WAITING % waiting, _middle_of(_ordered, top_m(level) + WAITING_TAG_M), LAYER)
	for at: int in range(used, _tags.size()):
		_tags[at].visible = false


func _way_tags(used: int, level: int) -> int:
	""""Entrance" over each mouth on the surface; "Way down" / "Way up" / "Way up to the surface" on the level shown."""
	for row: int in _works.way_count():
		var top: int = _works.way_level(row)
		var at: Vector3 = _corner(_works.way_cell(row) + Vector2i.ONE, 0.0)
		if top == 0 and not on_mound(row):
			used = _tag(used, "Entrance", at + Vector3(0.0, ENTRANCE_TAG_M, 0.0), Layers.SURFACE_MARKS)
		if underground(level) and (top == level or top + 1 == level):
			var words: String = "Way down" if top == level else "Way up to the surface" if top == 0 else "Way up"
			used = _tag(used, words, at + Vector3(0.0, top_m(level) + WAY_TAG_M, 0.0), LAYER)
	return used


func _middle_of(cells: PackedInt32Array, y: float) -> Vector3:
	"""The middle of the box round `cells` (canonical pairs) at height `y`."""
	var box: Rect2i = Rect2i(Vector2i(cells[0], cells[1]), Vector2i.ONE)
	for at: int in range(2, cells.size(), 2):
		box = box.expand(Vector2i(cells[at], cells[at + 1])).expand(Vector2i(cells[at], cells[at + 1]) + Vector2i.ONE)
	var low: Vector3 = _corner(box.position, y)
	var high: Vector3 = _corner(box.end, y)
	return (low + high) / 2.0


func _tag(used: int, words: String, at: Vector3, layer: int) -> int:
	"""Tag `used` (made when the pool is that short) shows `words` at `at` on `layer`; returns the next free one."""
	if used == _tags.size():
		var tag: Label3D = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = TAG_PX
		tag.outline_size = 8
		tag.render_priority = TAG_PRIORITY
		tag.outline_render_priority = TAG_PRIORITY - 1
		add_child(tag)
		_tags.append(tag)
	var label: Label3D = _tags[used]
	label.text = words
	label.layers = layer
	# A pooled tag may carry another's lift (review M4); the spacer lifts it again the same frame.
	label.offset = Vector2.ZERO
	# On the surface the camera comes close (a burrow mouth from 7 m): a constant size there, as the village's own
	# tags (tunnel_overlay.gd); on a level, the size the spacer measures (demo_build_tags.gd).
	label.fixed_size = layer != LAYER
	label.pixel_size = SURFACE_TAG_PIXEL if layer != LAYER else TAG_PIXEL
	label.position = at
	label.visible = true
	return used + 1


func _corner(cell: Vector2i, y: float) -> Vector3:
	"""A cell corner in metres at height `y`."""
	return Vector3(_datum.x / UNITS_PER_M + cell.x, y, _datum.y / UNITS_PER_M + cell.y)


func tags() -> PackedStringArray:
	"""The names shown (checks)."""
	var out: PackedStringArray = PackedStringArray()
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag.text)
	return out


func shown_tags(out: Array[Label3D]) -> void:
	"""Append the level's shown tags to `out`, in the order they give way (the surface's are not on the level)."""
	for tag: Label3D in _tags:
		if tag.visible and tag.layers == LAYER:
			out.append(tag)


func stairs_shown() -> int:
	"""Stairs drawn on the level (checks)."""
	var shown: int = 0
	for node: MeshInstance3D in _stairs:
		shown += 1 if node.visible else 0
	return shown


func mouths_shown() -> int:
	"""Burrow mouths drawn on the surface (checks)."""
	var shown: int = 0
	for node: MeshInstance3D in _mouths:
		shown += 1 if node.visible else 0
	return shown
