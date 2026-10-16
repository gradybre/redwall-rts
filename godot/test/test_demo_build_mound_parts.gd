extends "res://test/framework/test_case.gd"
## The Mounds' parts drawn (decision 2002; demo_build_mound_parts.gd, demo_build_mound_front.gd): windows flush on the
## slope and lit inside, the ribs as the frame, a hatch, the dressing kept clear of every window and door path, the
## chimney over a fitted hearth, the tree on the crown, and the front door stage by stage -- our own design, with no
## centre knob.

const Parts := preload("res://demo/build_panel/demo_build_mound_parts.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const DATUM: Vector2 = Vector2(50.0, 60.0)
## A 6 × 4 Kitchen at (10, 10)-(15, 13): its door north at (12, 10), a window south at (14, 13).
const DOOR: Vector3i = Vector3i(12, 10, 0)
const WINDOW: Vector3i = Vector3i(14, 13, 2)

var _palette: Dictionary = {}
var _mounds: Mounds = null
var _field: Field = null


func before_each() -> void:
	"""The Kitchen heaped, its door and window ordered, the field over it."""
	_palette = Front.palette()
	_mounds = Mounds.new()
	_mounds.configure(Rect2i(0, 0, 32, 32))
	_mounds.order_cells(_rect(Vector2i(10, 10), Vector2i(15, 13)))
	_mounds.order_edge(Mound.cell_of(DOOR), DOOR.z, Mound.KIND_DOOR, 0)
	_mounds.order_edge(Mound.cell_of(WINDOW), WINDOW.z, Mound.KIND_WINDOW, 0)
	_advance_all(Mounds.HEAPED)
	_field = Field.new()
	_field.setup(_mounds.all_cells(), _mounds.yards(), DATUM)


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _advance_all(stage: int) -> void:
	"""Every Kitchen cell to `stage`."""
	var cells: PackedInt32Array = _rect(Vector2i(10, 10), Vector2i(15, 13))
	for at: int in range(0, cells.size(), 2):
		_mounds.advance(Vector2i(cells[at], cells[at + 1]), stage)


func _materials(kit: MeshKit) -> Array[Material]:
	"""The materials a kit's mesh has, in order."""
	var out: Array[Material] = []
	var mesh: ArrayMesh = kit.commit()
	for surface: int in (mesh.get_surface_count() if mesh != null else 0):
		out.append(mesh.surface_get_material(surface))
	return out


func _vertices_of(kit: MeshKit, material: Material) -> PackedVector3Array:
	"""The vertices drawn in `material`."""
	var mesh: ArrayMesh = kit.commit()
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_material(surface) == material:
			return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()


func test_a_window_lies_flush_on_the_slope_facing_out() -> void:
	"""BUILD-MOUND-014: a heaped window's spot is on the slope at the wall's top metre; its frame faces the slope."""
	var spots: Array[Dictionary] = Parts.window_spots(_field, _mounds)
	assert_equal(spots.size(), 1, "the window only")
	assert_equal([spots[0]["row"], spots[0]["edge"]], [1, WINDOW], "its row and edge")
	var frame: Transform3D = Parts.window_frame(spots[0])
	assert_equal(frame.origin, spots[0]["point"], "on the surface")
	assert_true(frame.basis.z.is_equal_approx(spots[0]["normal"]), "z out along the slope's normal")
	assert_true(absf(frame.basis.x.dot(Vector3.RIGHT)) > 0.99, "x along the south wall")
	assert_true(absf(frame.basis.x.dot(frame.basis.z)) < 0.001, "square to it")
	var unheaped: Mounds = Mounds.new()
	unheaped.configure(Rect2i(0, 0, 32, 32))
	unheaped.order_cells(_rect(Vector2i(10, 10), Vector2i(15, 13)))
	unheaped.order_edge(Mound.cell_of(WINDOW), WINDOW.z, Mound.KIND_WINDOW, 0)
	assert_true(Parts.window_spots(_field, unheaped).is_empty(), "not heaped: not drawn")


func test_a_window_is_drawn_as_far_as_it_is_built() -> void:
	"""Nothing before its cells are framed; then its brick ring, hood and a dark hole; fitted: plaster and glass."""
	var spot: Dictionary = Parts.window_spots(_field, _mounds)[0]
	var kit: MeshKit = MeshKit.new()
	Parts.add_window(kit, _palette, spot, Mounds.DUG, false)
	assert_equal(kit.count(), 0, "not framed: nothing")
	Parts.add_window(kit, _palette, spot, Mounds.FRAMED, false)
	var framed: Array[Material] = _materials(kit)
	assert_true(framed.has(_palette[&"brick"]) and framed.has(_palette[&"hole"]), "ring and hole")
	assert_false(framed.has(_palette[&"glass"]), "no glass yet")
	var fitted: MeshKit = MeshKit.new()
	Parts.add_window(fitted, _palette, spot, Mounds.TOPPED, true)
	var done: Array[Material] = _materials(fitted)
	assert_true(done.has(_palette[&"glass"]) and done.has(_palette[&"plaster"]), "glass in its plastered rim")
	assert_false(done.has(_palette[&"hole"]), "no hole once glazed")


func test_a_window_lights_its_room_inside() -> void:
	"""BUILD-MOUND-016: inside, a disc at the wall's top metre facing in and down; by day the sky in it, a beam to the
	floor 1.6 m in, and its pool."""
	var frame: Transform3D = Parts.inside_frame(WINDOW, DATUM)
	assert_true(is_equal_approx(frame.origin.y, Field.WINDOW_HEIGHT_M), "the wall's top metre")
	assert_true(frame.basis.z.z < 0.0 and frame.basis.z.y < 0.0, "facing north into the room, and down")
	var floor_at: Vector3 = Parts.beam_floor(WINDOW, DATUM)
	assert_true(floor_at.is_equal_approx(Vector3(DATUM.x + 14.5, 0.04, DATUM.y + 14.0 - Parts.BEAM_IN_M)), "%s" % floor_at)
	var night: MeshKit = MeshKit.new()
	Parts.add_window_inside(night, _palette, WINDOW, DATUM)
	assert_equal(_materials(night), [_palette[&"hole"], _palette[&"rib"]] as Array[Material], "a dark disc and its ring")
	var day: MeshKit = MeshKit.new()
	Parts.add_daylight(day, _palette, WINDOW, DATUM)
	assert_equal(_materials(day), [_palette[&"sky"], _palette[&"beam"], _palette[&"pool"]] as Array[Material], "daylight")


func test_ribs_are_drawn_across_framed_crossings_only() -> void:
	"""BUILD-MOUND-007: a rib every 1.2 m along the room where every cell across is framed, never above the wall's top."""
	var room: PackedInt32Array = _rect(Vector2i(10, 10), Vector2i(15, 13))
	var none: MeshKit = MeshKit.new()
	assert_equal(Parts.add_ribs(none, _palette, _mounds, [room] as Array[PackedInt32Array], DATUM), 0, "nothing framed")
	_advance_all(Mounds.DUG)
	for z: int in range(10, 14):
		_mounds.advance(Vector2i(10, z), Mounds.FRAMED)
	var one: MeshKit = MeshKit.new()
	assert_equal(Parts.add_ribs(one, _palette, _mounds, [room] as Array[PackedInt32Array], DATUM), 1, "one framed crossing")
	_advance_all(Mounds.FRAMED)
	var all: MeshKit = MeshKit.new()
	assert_equal(Parts.add_ribs(all, _palette, _mounds, [room] as Array[PackedInt32Array], DATUM), 5, "6 m: five ribs")
	var highest: float = -INF
	for vertex: Vector3 in _vertices_of(all, _palette[&"rib"]):
		highest = maxf(highest, vertex.y)
	assert_true(highest <= Field.ROOM_TOP_M, "under the wall's top (the cutaway's cut): %f" % highest)


func test_dressing_keeps_clear_of_windows_and_door_paths() -> void:
	"""BUILD-MOUND-017: no shrub by a window or in the slope before it, nor on a door's path; all on the lower slope."""
	_advance_all(Mounds.DUG)
	var spots: Array[Dictionary] = Parts.window_spots(_field, _mounds)
	var spot_at: Vector3 = spots[0]["point"]
	assert_false(Parts.clear_of_windows(Vector2(spot_at.x + 1.0, spot_at.z), spots), "beside the window")
	assert_false(Parts.clear_of_windows(Vector2(spot_at.x, spot_at.z + 4.0), spots), "on the slope before it")
	assert_true(Parts.clear_of_windows(Vector2(spot_at.x - 5.0, spot_at.z), spots), "well along the wall")
	var station: Vector2 = Front.station_of(DOOR, DATUM)
	assert_false(Parts.clear_of_doors(station, _mounds.doors(), DATUM), "on the door's path")
	assert_true(Parts.clear_of_doors(station + Vector2(8.0, 0.0), _mounds.doors(), DATUM), "aside of it")
	var shrubs: PackedVector3Array = Parts.shrub_points(_field, spots, _mounds.doors())
	assert_false(shrubs.is_empty(), "shrubs grow")
	for shrub: Vector3 in shrubs:
		var at: Vector2 = Vector2(shrub.x, shrub.z)
		assert_true(shrub.y > Parts.SHRUB_LOW_M and shrub.y < Parts.SHRUB_HIGH_M, "lower slope")
		assert_true(Parts.clear_of_windows(at, spots) and Parts.clear_of_doors(at, _mounds.doors(), DATUM), "clear")


func test_the_chimney_stands_over_a_fitted_hearth_and_the_tree_on_the_crown() -> void:
	"""BUILD-MOUND-022: a fitted hearth on the Mound's floor gives a chimney's place; one ordered or below gives none;
	the tree stands on the cell deepest inside, clear of the window."""
	var fittings: Fittings = Fittings.new()
	var cells: Dictionary = Mound.set_of(_mounds.all_cells())
	fittings.order(Mound.SURFACE, Vector2i(11, 11), 0, Parts.HEARTH)
	fittings.order(1, Vector2i(11, 11), 0, Parts.HEARTH)
	assert_true(Parts.hearth_points(fittings, cells, DATUM).is_empty(), "ordered only")
	fittings.fit(0)
	fittings.fit(1)
	var hearths: Array[Vector2] = Parts.hearth_points(fittings, cells, DATUM)
	assert_equal(hearths.size(), 1, "the Surface's hearth only")
	var floor_cells: PackedInt32Array = fittings.cells_of(0)
	var over: Rect2 = Rect2(DATUM + Vector2(floor_cells[0], floor_cells[1]), Vector2.ZERO)
	for at: int in range(0, floor_cells.size(), 2):
		over = over.expand(DATUM + Vector2(floor_cells[at] + 1.0, floor_cells[at + 1] + 1.0))
	assert_true(hearths[0].is_equal_approx(over.get_center()), "over its middle: %s" % hearths[0])
	var spots: Array[Dictionary] = Parts.window_spots(_field, _mounds)
	var crown: Vector2 = Parts.crown_point(_field, _mounds.all_cells(), spots)
	assert_true(crown != Vector2.INF and Parts.clear_of_windows(crown, spots), "a crown clear of the window")
	assert_true(_field.inside_distance(crown) >= 1.5, "deep inside: %f" % _field.inside_distance(crown))
	var kit: MeshKit = MeshKit.new()
	Parts.add_chimney(kit, _palette, Vector3(1.0, 5.0, 1.0))
	Parts.add_tree(kit, _palette, Vector3(2.0, 6.0, 2.0))
	Parts.add_shrub(kit, _palette, Vector3(3.0, 0.5, 3.0))
	Parts.add_hatch(kit, _palette, Vector2i(11, 11), DATUM)
	var used: Array[Material] = _materials(kit)
	for key: StringName in [&"brick", &"pot", &"bark", &"leaf", &"bush", &"hole", &"oak", &"rib"]:
		assert_true(used.has(_palette[key]), "drawn in %s" % key)


func test_the_front_door_is_drawn_stage_by_stage() -> void:
	"""BUILD-MOUND-011: a hole once dug, posts, ring and eave once framed, the front, steps and garden once fitted, in
	the door's colour."""
	var frame: Transform3D = Front.frame_of(DOOR, DATUM)
	var none: MeshKit = MeshKit.new()
	Front.add_door(none, _palette, frame, Mounds.HEAPED, false, 0)
	assert_equal(none.count(), 0, "heaped: nothing")
	var dug: MeshKit = MeshKit.new()
	Front.add_door(dug, _palette, frame, Mounds.DUG, false, 0)
	assert_equal(_materials(dug), [_palette[&"hole"]] as Array[Material], "the hole")
	var framed: MeshKit = MeshKit.new()
	Front.add_door(framed, _palette, frame, Mounds.FRAMED, false, 0)
	assert_true(_materials(framed).has(_palette[&"brick"]) and _materials(framed).has(_palette[&"rib"]), "its frame")
	assert_false(_materials(framed).has(_palette[&"plaster"]), "no front yet")
	var fitted: MeshKit = MeshKit.new()
	Front.add_door(fitted, _palette, frame, Mounds.TOPPED, true, 3)
	var used: Array[Material] = _materials(fitted)
	for key: StringName in [&"plaster", &"turf", &"door_3", &"iron", &"lamp", &"stone", &"fence", &"bush", &"pink"]:
		assert_true(used.has(_palette[key]), "fitted with %s" % key)
	assert_false(used.has(_palette[&"door_0"]), "blue, not oak")


func test_the_door_has_no_centre_knob() -> void:
	"""DEC-010's boundary (P-2001-8 (a), our own design): no iron within 0.25 m of the round door's middle; its pull is
	a ring at its side."""
	var frame: Transform3D = Front.frame_of(DOOR, DATUM)
	var kit: MeshKit = MeshKit.new()
	Front.add_door(kit, _palette, frame, Mounds.TOPPED, true, Mound.COLOUR_OAK)
	var middle: Vector3 = frame * Vector3(0.0, Front.DOOR_UP_M, 0.25)
	var nearest: float = INF
	for vertex: Vector3 in _vertices_of(kit, _palette[&"iron"]):
		var local: Vector3 = frame.affine_inverse() * vertex
		if absf(local.y - Front.DOOR_UP_M) > 0.2:
			continue
		nearest = minf(nearest, Vector2(local.x, local.y - Front.DOOR_UP_M).length())
	assert_true(nearest > 0.25, "nearest iron at the door's height: %f m from its middle" % nearest)
	assert_true(middle.y > 0.0, "the door stands above the ground")


func test_the_doors_frame_lantern_and_station() -> void:
	"""The frame: on the front line at the door's middle, z out into the yard, right-handed; the lantern beside the
	door; the builder's station two metres out on the path."""
	var frame: Transform3D = Front.frame_of(DOOR, DATUM)
	assert_true(frame.origin.is_equal_approx(Vector3(DATUM.x + 13.0, 0.0, DATUM.y + 10.0)), "%s" % frame.origin)
	assert_true(frame.basis.z.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "out north")
	assert_true(frame.basis.determinant() > 0.0, "right-handed")
	assert_true(Front.station_of(DOOR, DATUM).is_equal_approx(Vector2(DATUM.x + 13.0, DATUM.y + 8.0)), "two metres out")
	var lantern: Vector3 = Front.lantern_at(frame)
	assert_true(lantern.y > 2.0 and lantern.z < DATUM.y + 10.0, "high, before the front: %s" % lantern)
	var east: Transform3D = Front.frame_of(Vector3i(15, 11, 1), DATUM)
	assert_true(east.origin.is_equal_approx(Vector3(DATUM.x + 16.0, 0.0, DATUM.y + 12.0)), "an east door")
	assert_true(Front.local(frame, Vector3(0.0, 0.0, 1.0)).origin.is_equal_approx(frame.origin + frame.basis.z), "local")
	var palette: Dictionary = Front.palette()
	assert_equal((palette[&"door_0"] as StandardMaterial3D).albedo_color, Front.DOOR_COLOURS[Mound.COLOUR_OAK], "oak")
	assert_true((palette[&"lamp"] as StandardMaterial3D).emission_enabled, "the lantern glows")
	assert_equal((palette[&"beam"] as StandardMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "a soft beam")
	assert_equal((Front.unshaded(Color.WHITE, 1.0)).transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque sky")
	assert_true(Front.glowing(Color.RED, 2.0).emission_energy_multiplier == 2.0, "glowing")
	assert_equal(Front.matte(Color.RED).cull_mode, BaseMaterial3D.CULL_DISABLED, "both faces")
