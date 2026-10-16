extends Node3D
## THE MOUNDS, DRAWN (decision 2002), over the Surface's unchanged ground on the village's own layer, from
## demo_build_mounds.gd: two looks, the same hill --
##   OUTSIDE  (the village, and the panel on any other level): the hill whole (demo_build_mound_hill.gd), each door's
##            built front and yard garden (demo_build_mound_front.gd), its windows flush on the slope, and once a
##            Mound is topped its dressing: a chimney over each room with a fitted hearth, a tree on its crown, shrubs
##            on its lower slope -- none by a window or on a door's path (demo_build_mound_parts.gd);
##   CUTAWAY  (the build panel open on the Surface): the hill cut off at the wall's top, the mockup's "Turf off", so the
##            dug rooms show with their rounded walls, timber ribs once framed, furniture (demo_build_furnish.gd), a
##            hatch where a way down stands on a room's floor, and each fitted window's daylight: a disc of sky, a beam
##            and a pool of light on the floor, and while it is day a spotlight (BUILD-MOUND-016).
## Ordered cells waiting for their heap are pegged out in chalk, and each Mound's state is named over it in words
## ("Heaping the hill: 12 cells to go", "! No way in: place a door on an outer edge"). The hill is rebuilt only when the
## Mounds, the works or the furniture change: on a WorkerThreadPool task when `threaded` (the live demo), from a
## snapshot taken on the main thread; the parts on the main thread when it is shown. Presentation only.

const Mound := preload("res://scripts/ui/build_mound.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Hill := preload("res://demo/build_panel/demo_build_mound_hill.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Parts := preload("res://demo/build_panel/demo_build_mound_parts.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Jobs := preload("res://demo/build_panel/demo_build_mound_jobs.gd")
const Burrow := preload("res://demo/build_panel/demo_build_burrow_field.gd")
const Layers := preload("res://demo/demo_layers.gd")
const MoundShader := preload("res://demo/build_panel/build_mound.gdshader")

const TAG_PX: int = 36
const TAG_PIXEL: float = 0.0006
const TAG_PRIORITY: int = 5
const TAG_UP_M: float = 7.0
const CHALK: Color = Color(0.93, 0.88, 0.74, 0.55)
const CHALK_M: float = 0.06
const LANTERN_COLOUR: Color = Color8(0xff, 0xb0, 0x66)
const DAYLIGHT_COLOUR: Color = Color8(0xea, 0xf4, 0xff)
const NO_WAY_IN: String = "! %s" % Mound.TEXT_NO_DOOR
## BUILD-MOUND-021's words over a way down on a Mound room's floor.
const HATCH_WORDS: String = Mound.TEXT_HATCH
## By the least-built stage among a Mound's cells (demo_build_mounds.gd ORDERED ... FRAMED; NONE unused).
const STATE_WORDS: Array[String] = ["", "Heaping the hill: %s to go", "Digging: %s to go", "Framing: %s to go",
	"Topping and turfing: %s to go"]

var threaded: bool = false
var _mounds: Mounds = null
var _works: Works = null
var _fittings: Fittings = null
var _datum_m: Vector2 = Vector2.ZERO
var _material: ShaderMaterial = null
var _palette: Dictionary = {}
var _hill: MeshInstance3D = null
var _cut: MeshInstance3D = null
var _parts_out: MeshInstance3D = null
var _parts_cut: MeshInstance3D = null
var _daylight: MeshInstance3D = null
var _tags: Array[Label3D] = []
var _lanterns: Array[OmniLight3D] = []
var _daylights: Array[SpotLight3D] = []
var _seen: Vector3i = Vector3i(-1, -1, -1)
## What the drawing reads besides the Mounds, as last drawn (`surface_key`).
var _surface_seen: Vector3i = Vector3i(-1, -1, -1)
var _task: int = -1
var _wanted: bool = false
var _snap: Hill.Snapshot = null
var _built: Array = []
var _cutaway: bool = false
var _day: bool = true
## Checks: rebuilds, the last build's time on its worker, and what the parts drew.
var rebuilds: int = 0
var last_build_usec: int = 0
var ribs_drawn: int = 0
var shrubs_drawn: int = 0
var windows_drawn: int = 0
var spots: Array[Dictionary] = []
## Tags in use: each Mound's state first, then the hatches' words (`_place_tags`).
var _mound_tags: int = 0
var _tags_used: int = 0


func configure(mounds: Mounds, works: Works, fittings: Fittings, datum_m: Vector2) -> void:
	"""Draw `mounds` (with the works' rooms and the confirmed furniture) from `datum_m` (cell (0, 0), m)."""
	name = "BuildMounds"
	_mounds = mounds
	_works = works
	_fittings = fittings
	_datum_m = datum_m
	_material = ShaderMaterial.new()
	_material.shader = MoundShader
	_palette = Front.palette()
	_palette[&"chalk"] = Front.unshaded(Color(CHALK, 1.0), CHALK.a)
	_hill = _node()
	_cut = _node()
	_parts_out = _node()
	_parts_cut = _node()
	_daylight = _node()
	_daylight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Burrow.warm()


func _node() -> MeshInstance3D:
	"""One mesh node on the village's layer, casting shadows."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.layers = Layers.SURFACE
	add_child(node)
	return node


func use_props(props: Object) -> void:
	"""The build panel's staged earth textures on the hill's floors and earth (decision 1913); none staged: colours."""
	if props == null:
		return
	var floor_texture: Texture2D = props.call(&"build_texture", "earth_floor")
	var wall_texture: Texture2D = props.call(&"build_texture", "earth_wall")
	if floor_texture != null:
		_material.set_shader_parameter(&"floor_texture", floor_texture)
		_material.set_shader_parameter(&"floor_textured", true)
	if wall_texture != null:
		_material.set_shader_parameter(&"wall_texture", wall_texture)
		_material.set_shader_parameter(&"wall_textured", true)


func material() -> ShaderMaterial:
	"""The hill's one material (checks)."""
	return _material


func refresh(cutaway: bool, day: bool) -> void:
	"""Each frame: show a finished build, rebuild when the Mounds or what it reads of the Surface moved (the works and
	the furniture move below too: those are compared only when their revisions move), and show the look asked for
	(`cutaway`: the build panel on the Surface) with the daylight `day` gives."""
	poll()
	var key: Vector3i = Vector3i(_mounds.revision, _works.revision, _fittings.revision)
	if key != _seen:
		_seen = key
		var surface: Vector3i = surface_key()
		if surface != _surface_seen:
			_surface_seen = surface
			request()
	if cutaway != _cutaway or day != _day:
		_cutaway = cutaway
		_day = day
		_show()


func surface_key() -> Vector3i:
	"""What the drawing reads: the Mounds' revision, the Surface's ways down (hashed) and its fitted furniture."""
	var fitted: int = 0
	for row: int in _fittings.count():
		fitted += 1 if _fittings.level_of(row) == Mound.SURFACE and _fittings.state_of(row) == Fittings.FITTED else 0
	return Vector3i(_mounds.revision, hash(_works.ways_on(Mound.SURFACE)), fitted)


func request() -> void:
	"""Rebuild the hill from a snapshot of the Mounds: on a worker when `threaded` (one build in flight; a request
	made meanwhile waits, and only the newest is built after it), else now."""
	if _task >= 0:
		_wanted = true
		return
	rebuilds += 1
	_snap = Hill.snapshot(_mounds, _datum_m)
	if threaded:
		_task = WorkerThreadPool.add_task(_build, false, "BuildMounds")
		return
	_build()
	_commit()


func _build() -> void:
	"""Both looks' surface arrays from the snapshot (on a worker when threaded: nothing else touches it meanwhile)."""
	var started: int = Time.get_ticks_usec()
	_built = Hill.build_arrays(_snap)
	last_build_usec = Time.get_ticks_usec() - started


func poll() -> void:
	"""Show a build that has finished, and start the request waiting for it."""
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_commit()
	if _wanted:
		_wanted = false
		request()


func finish() -> void:
	"""Wait for any build in flight and show it (checks read the hill as it now stands)."""
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_commit()
	if _wanted:
		_wanted = false
		var was: bool = threaded
		threaded = false
		request()
		threaded = was


func busy() -> bool:
	"""Whether a build is in flight or waiting (checks)."""
	return _task >= 0 or _wanted


func _notification(what: int) -> void:
	"""Freed with a build in flight: wait for it, so the worker never reads what is gone."""
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _commit() -> void:
	"""On the main thread: the meshes made, the parts, lights and tags drawn from the same snapshot."""
	_hill.mesh = MeshKit.mesh_of(_built[0], _material)
	_cut.mesh = MeshKit.mesh_of(_built[1], _material)
	spots = Parts.window_spots(_snap.field, _mounds)
	_parts_out.mesh = _parts(false)
	_parts_cut.mesh = _parts(true)
	_daylight.mesh = _daylight_mesh()
	_place_lights()
	_place_tags()
	_show()


func _show() -> void:
	"""The look asked for: the hill whole or cut away, and the lights and words that go with it (a hatch's words only
	cut away, where it shows)."""
	for k: int in range(_mound_tags, _tags_used):
		_tags[k].visible = _cutaway
	_hill.visible = not _cutaway
	_parts_out.visible = not _cutaway
	_cut.visible = _cutaway
	_parts_cut.visible = _cutaway
	_daylight.visible = _cutaway and _day
	for light: SpotLight3D in _daylights:
		light.visible = _cutaway and _day and light.has_meta(&"used")


func hill_mesh(cutaway: bool) -> ArrayMesh:
	"""The hill as last drawn, whole or cut away (checks)."""
	return (_cut.mesh if cutaway else _hill.mesh) as ArrayMesh


func shown_cutaway() -> bool:
	"""Whether the cut-away look shows (checks)."""
	return _cutaway


# --- the parts -------------------------------------------------------------------------------------------------------

func _parts(cut: bool) -> ArrayMesh:
	"""One look's parts as one mesh: doors and windows, the ribs and hatches inside (cut away) or the chimneys and
	trees on top (whole), shrubs on the slope, and chalk round the cells waiting for their heap."""
	var kit: MeshKit = MeshKit.new()
	_add_doors(kit)
	windows_drawn = _add_windows(kit, cut)
	if cut:
		ribs_drawn = Parts.add_ribs(kit, _palette, _mounds, rooms(), _datum_m)
		_add_hatches(kit)
	else:
		_add_crowns(kit)
	shrubs_drawn = _add_shrubs(kit)
	_add_chalk(kit)
	return kit.commit()


func _add_doors(kit: MeshKit) -> void:
	"""Each door as far as its cells are built, its front once fitted."""
	for row: int in _mounds.edge_count():
		if _mounds.edge_kind(row) != Mound.KIND_DOOR:
			continue
		var stage: int = Mounds.TOPPED
		for edge: Vector3i in _mounds.edges_of(row):
			stage = mini(stage, _mounds.stage_of(Mound.cell_of(edge)))
		var frame: Transform3D = Front.frame_of(_mounds.edges_of(row)[0], _datum_m)
		Front.add_door(kit, _palette, frame, stage, _mounds.edge_fitted(row), _mounds.edge_colour(row))


func _add_windows(kit: MeshKit, cut: bool) -> int:
	"""Each window on its slope (and, cut away, a fitted one's daylight inside); returns how many were drawn."""
	for spot: Dictionary in spots:
		var row: int = int(spot["row"])
		var fitted: bool = _mounds.edge_fitted(row)
		Parts.add_window(kit, _palette, spot, _mounds.stage_of(_mounds.edge_cell(row)), fitted)
		if cut and fitted:
			Parts.add_window_inside(kit, _palette, spot["edge"], _datum_m)
	return spots.size()


func _daylight_mesh() -> ArrayMesh:
	"""Each fitted window's daylight inside, as one mesh shown cut away by day."""
	var kit: MeshKit = MeshKit.new()
	for spot: Dictionary in spots:
		if _mounds.edge_fitted(int(spot["row"])):
			Parts.add_daylight(kit, _palette, spot["edge"], _datum_m)
	return kit.commit()


func daylight_shown() -> bool:
	"""Whether the windows' daylight inside is drawn now (checks)."""
	return _daylight.visible and _daylight.mesh != null


func _add_hatches(kit: MeshKit) -> void:
	"""A hatch where a way down stands on a dug Mound room's floor."""
	var tops: PackedInt32Array = _works.ways_on(Mound.SURFACE)
	for at: int in range(0, tops.size(), 2):
		var cell: Vector2i = Vector2i(tops[at], tops[at + 1])
		if _mounds.is_open(cell):
			Parts.add_hatch(kit, _palette, cell, _datum_m)


func _add_crowns(kit: MeshKit) -> void:
	"""On each topped Mound: a chimney over each fitted hearth, and a tree on the crown."""
	var all: Array[PackedInt32Array] = _mounds.groups()
	for group: int in all.size():
		if _mounds.least_stage(group) < Mounds.TOPPED:
			continue
		for point: Vector2 in Parts.hearth_points(_fittings, Mound.set_of(all[group]), _datum_m):
			Parts.add_chimney(kit, _palette, Vector3(point.x, _snap.field.height_m(point), point.y))
		var crown: Vector2 = Parts.crown_point(_snap.field, all[group], spots)
		if crown.is_finite():
			Parts.add_tree(kit, _palette, Vector3(crown.x, _snap.field.height_m(crown) - 0.2, crown.y))


func _add_shrubs(kit: MeshKit) -> int:
	"""Shrubs on the lower slope of topped ground; returns how many."""
	var drawn: int = 0
	for at: Vector3 in Parts.shrub_points(_snap.field, spots, _mounds.doors()):
		var cell: Vector2i = _snap.field.nearest_cell(Vector2(at.x, at.z))
		if int(_snap.stages.get(cell, Mounds.HEAPED)) >= Mounds.TOPPED:
			Parts.add_shrub(kit, _palette, at)
			drawn += 1
	return drawn


func _add_chalk(kit: MeshKit) -> void:
	"""Each cell waiting for its heap pegged out in chalk on the ground."""
	var waiting: PackedInt32Array = PackedInt32Array()
	_mounds.cells_into(Mounds.ORDERED, waiting)
	for at: int in range(0, waiting.size(), 2):
		var cell: Vector2i = Vector2i(waiting[at], waiting[at + 1])
		if _mounds.stage_of(cell) != Mounds.ORDERED:
			continue
		var middle: Vector3 = Vector3(_datum_m.x + cell.x + 0.5, 0.02, _datum_m.y + cell.y + 0.5)
		for side: Vector3 in [Vector3(0.0, 0.0, -0.36), Vector3(0.0, 0.0, 0.36)]:
			kit.add_box(_palette[&"chalk"], Vector3(0.78, 0.01, CHALK_M), Transform3D(Basis.IDENTITY, middle + side))
		for side: Vector3 in [Vector3(-0.36, 0.0, 0.0), Vector3(0.36, 0.0, 0.0)]:
			kit.add_box(_palette[&"chalk"], Vector3(CHALK_M, 0.01, 0.78), Transform3D(Basis.IDENTITY, middle + side))


func rooms() -> Array[PackedInt32Array]:
	"""The dug Mound rooms: open cells joined to their neighbours of the same type (pairs)."""
	var open: PackedInt32Array = PackedInt32Array()
	_mounds.cells_into(Mounds.DUG, open)
	var by_type: Dictionary = {}
	for at: int in range(0, open.size(), 2):
		var type: int = _works.type_of(Mound.SURFACE, Vector2i(open[at], open[at + 1]))
		var cells: PackedInt32Array = by_type.get(type, PackedInt32Array())
		cells.append_array(PackedInt32Array([open[at], open[at + 1]]))
		by_type[type] = cells
	var out: Array[PackedInt32Array] = []
	for type: int in by_type:
		out.append_array(Mound.components(by_type[type]))
	return out


# --- lights and words ------------------------------------------------------------------------------------------------

func _place_lights() -> void:
	"""A lantern's light by each fitted door, and a spotlight of daylight through each fitted window (cut away, by
	day)."""
	var used: int = 0
	for row: int in _mounds.edge_count():
		if _mounds.edge_kind(row) == Mound.KIND_DOOR and _mounds.edge_fitted(row):
			var light: OmniLight3D = _lantern(used)
			light.position = Front.lantern_at(Front.frame_of(_mounds.edges_of(row)[0], _datum_m))
			light.visible = true
			used += 1
	for k: int in range(used, _lanterns.size()):
		_lanterns[k].visible = false
	_place_daylights()


func _lantern(at: int) -> OmniLight3D:
	"""Lantern light `at` (made when the pool is that short)."""
	if at == _lanterns.size():
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = LANTERN_COLOUR
		light.light_energy = 0.9
		light.omni_range = 7.0
		add_child(light)
		_lanterns.append(light)
	return _lanterns[at]


func _place_daylights() -> void:
	"""A spotlight from each fitted window's sky disc to its pool of light."""
	var used: int = 0
	for spot: Dictionary in spots:
		if not _mounds.edge_fitted(int(spot["row"])):
			continue
		if used == _daylights.size():
			var made: SpotLight3D = SpotLight3D.new()
			made.light_color = DAYLIGHT_COLOUR
			made.light_energy = 2.4
			made.spot_range = 9.0
			made.spot_angle = 35.0
			add_child(made)
			_daylights.append(made)
		var light: SpotLight3D = _daylights[used]
		var edge: Vector3i = spot["edge"]
		light.transform = Transform3D(Basis.looking_at(Parts.beam_floor(edge, _datum_m) - Parts.inside_frame(edge,
			_datum_m).origin, Vector3.UP), Parts.inside_frame(edge, _datum_m).origin)
		light.set_meta(&"used", true)
		used += 1
	for k: int in range(used, _daylights.size()):
		_daylights[k].remove_meta(&"used")
		_daylights[k].visible = false


func daylights_shown() -> int:
	"""Window spotlights shining now (checks)."""
	var shown: int = 0
	for light: SpotLight3D in _daylights:
		shown += 1 if light.visible else 0
	return shown


func _place_tags() -> void:
	"""Over each Mound its state in words, and over each hatch where it leads."""
	var used: int = 0
	var all: Array[PackedInt32Array] = _mounds.groups()
	for group: int in all.size():
		var words: String = state_words(group)
		if not words.is_empty():
			used = _tag(used, words, _over(all[group]))
	_mound_tags = used
	var tops: PackedInt32Array = _works.ways_on(Mound.SURFACE)
	for at: int in range(0, tops.size(), 2):
		var cell: Vector2i = Vector2i(tops[at], tops[at + 1])
		if _mounds.stage_of(cell) != Mounds.NONE:
			var middle: Vector3 = Vector3(_datum_m.x + cell.x + 1.0, 2.2, _datum_m.y + cell.y + 1.0)
			used = _tag(used, HATCH_WORDS, middle)
	_tags_used = used
	for k: int in range(used, _tags.size()):
		_tags[k].visible = false


func state_words(group: int) -> String:
	"""Mound `group`'s state in words: no way in, the stage it is at and the cells left, the doors and windows still to
	fit; "" once it is finished."""
	if _mounds.door_of(group) < 0:
		return NO_WAY_IN
	var least: int = _mounds.least_stage(group)
	var cells: PackedInt32Array = _mounds.groups()[group]
	if least < Mounds.TOPPED:
		var left: int = 0
		for at: int in range(0, cells.size(), 2):
			left += 1 if _mounds.stage_of(Vector2i(cells[at], cells[at + 1])) == least else 0
		return STATE_WORDS[least] % ("1 cell" if left == 1 else "%d cells" % left)
	for row: int in _mounds.edge_count():
		if not _mounds.edge_fitted(row) and _mounds.group_of(_mounds.edge_cell(row)) == group:
			return Jobs.words({"kind": Mounds.JOB_FIT_EDGE, "row": row, "edge": _mounds.edges_of(row)[0]}, _mounds)
	return ""


func _over(cells: PackedInt32Array) -> Vector3:
	"""Over the middle of the box round `cells`, TAG_UP_M up."""
	var box: Rect2i = Parts._box_of(cells)
	var middle: Vector2 = _datum_m + Vector2(box.position) + Vector2(box.size) / 2.0
	return Vector3(middle.x, TAG_UP_M, middle.y)


func _tag(used: int, words: String, at: Vector3) -> int:
	"""Tag `used` (made when the pool is that short) shows `words` at `at`; returns the next free one."""
	if used == _tags.size():
		var tag: Label3D = Label3D.new()
		tag.layers = Layers.SURFACE_MARKS
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = true
		tag.pixel_size = TAG_PIXEL
		tag.font_size = TAG_PX
		tag.outline_size = 8
		tag.render_priority = TAG_PRIORITY
		tag.outline_render_priority = TAG_PRIORITY - 1
		add_child(tag)
		_tags.append(tag)
	_tags[used].text = words
	_tags[used].position = at
	_tags[used].visible = true
	return used + 1


func shown_tags(out: Array[Label3D]) -> void:
	"""Append the shown tags to `out` (demo_build_tags.gd keeps them off each other)."""
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag)


func tags() -> PackedStringArray:
	"""The words shown over the Mounds (checks)."""
	var out: PackedStringArray = PackedStringArray()
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag.text)
	return out
