extends "res://test/framework/test_case.gd"
## The hill drawn (decision 2002; demo_build_mound_hill.gd, demo_build_mound_mesh.gd): the snapshot read off the
## Mounds, both looks' grids -- the hill whole, and cut away at the wall's top with each dug cell's floor whole (decision
## 1914 rule (a)) and a cell not yet dug kept square (rule (b)) -- their colours by stage, the grid's own rules, and the
## parts gathered into one mesh a material.

const Hill := preload("res://demo/build_panel/demo_build_mound_hill.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const DATUM: Vector2 = Vector2(0.0, 0.0)

var _mounds: Mounds = null


func before_each() -> void:
	"""A 4 × 2 Mound at (8, 8)-(11, 9), its door north at (9, 8), every cell heaped."""
	_mounds = Mounds.new()
	_mounds.configure(Rect2i(0, 0, 32, 32))
	_mounds.order_cells(_rect(Vector2i(8, 8), Vector2i(11, 9)))
	_mounds.order_edge(Vector2i(9, 8), 0, Mound.KIND_DOOR, 0)
	var cells: PackedInt32Array = _rect(Vector2i(8, 8), Vector2i(11, 9))
	for at: int in range(0, cells.size(), 2):
		_mounds.advance(Vector2i(cells[at], cells[at + 1]), Mounds.HEAPED)


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _point(arrays: Array, world: Vector2) -> int:
	"""The index of the lattice vertex at `world` (m), or -1."""
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for at: int in vertices.size():
		if is_equal_approx(vertices[at].x, world.x) and is_equal_approx(vertices[at].z, world.y):
			return at
	return -1


func _height(arrays: Array, world: Vector2) -> float:
	"""The grid's height at the lattice vertex at `world`, to a tenth of a millimetre (the grid is single precision)."""
	return snappedf((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[_point(arrays, world)].y, 0.0001)


func _kind(arrays: Array, world: Vector2) -> float:
	"""The grid's surface kind (colour alpha) at `world`."""
	return snappedf((arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[_point(arrays, world)].a, 0.01)


func test_a_snapshot_reads_the_heaped_cells_their_stages_and_yards() -> void:
	"""Heaped cells and further; each cell's stage; the early door's yard; the lattice over the field's box."""
	_mounds.advance(Vector2i(9, 8), Mounds.DUG)
	var snap: Hill.Snapshot = Hill.snapshot(_mounds, DATUM)
	assert_equal(snap.stages.size(), 8, "eight cells")
	assert_equal([snap.stages[Vector2i(9, 8)], snap.stages[Vector2i(8, 8)]], [Mounds.DUG, Mounds.HEAPED], "stages")
	assert_true(snap.field.is_yard(Vector2i(9, 7)), "the yard cut")
	assert_equal(snap.origin, snap.field.box().position, "origin")
	assert_equal(Hill.lattice(snap), Rect2i(snap.field.box().position * 4, snap.field.box().size * 4), "4 a metre")
	var empty: Mounds = Mounds.new()
	empty.configure(Rect2i(0, 0, 8, 8))
	empty.order_cells(PackedInt32Array([2, 2]))
	assert_equal(Hill.build_arrays(Hill.snapshot(empty, DATUM)), [[], []], "nothing heaped: nothing drawn")
	assert_null(Hill.outside(Hill.snapshot(empty, DATUM), null), "no mesh")


func test_the_whole_hill_and_the_cut_away_hill() -> void:
	"""Whole: the field's heights, under the ground where none; cut: no higher than the wall's top."""
	var snap: Hill.Snapshot = Hill.snapshot(_mounds, DATUM)
	var both: Array = Hill.build_arrays(snap)
	var whole: Array = both[0]
	var cut: Array = both[1]
	var middle: Vector2 = Vector2(10.0, 9.0)
	assert_equal(_height(whole, middle), snappedf(snap.field.height_m(middle), 0.0001), "the field's height")
	assert_true(_height(whole, middle) > Field.ROOM_TOP_M + Field.COVER_M - 0.001, "over the cover")
	assert_equal(_height(whole, Vector2(1.0, 1.0)), snappedf(MeshKit.UNDER_M, 0.0001), "the ground: just under it")
	assert_equal(_height(cut, middle), Field.ROOM_TOP_M, "cut at the wall's top")
	assert_equal(_kind(cut, middle), MeshKit.EARTH, "the cut top in earth")
	var vertices: PackedVector3Array = cut[Mesh.ARRAY_VERTEX]
	var highest: float = -INF
	for vertex: Vector3 in vertices:
		highest = maxf(highest, vertex.y)
	assert_true(highest <= Field.ROOM_TOP_M, "nothing above the wall's top")
	assert_equal(_kind(whole, middle), MeshKit.HEAP, "heaped earth's look")


func test_a_dug_cells_floor_is_whole_and_an_undug_cell_stays_square() -> void:
	"""Decision 1914 rules (a) and (b) in the cutaway: every lattice point of a dug cell's square is floor; the cell
	beside it, heaped but not dug, keeps its cut top right to its edge."""
	_mounds.advance(Vector2i(9, 8), Mounds.DUG)
	var cut: Array = Hill.build_arrays(Hill.snapshot(_mounds, DATUM))[1]
	for j: int in 5:
		for i: int in 5:
			var at: Vector2 = Vector2(9.0 + i * 0.25, 8.0 + j * 0.25)
			assert_equal(_height(cut, at), Hill.FLOOR_LIFT_M, "floor at %s" % at)
			assert_equal(_kind(cut, at), MeshKit.FLOOR, "floor's look")
	assert_equal(_height(cut, Vector2(10.75, 8.5)), Field.ROOM_TOP_M, "the undug cell's square, just inside its edge")
	assert_equal(_height(cut, Vector2(11.5, 9.5)), Field.ROOM_TOP_M, "the far cell")
	var wall: float = _height(cut, Vector2(8.75, 8.5))
	assert_equal(wall, Field.ROOM_TOP_M, "an undug neighbour west is never rounded into")


func test_the_turf_shows_once_a_cell_is_topped() -> void:
	"""Colours follow the nearest room cell's stage: heaped raw earth, then dug earth, then turf."""
	var cells: PackedInt32Array = _rect(Vector2i(8, 8), Vector2i(11, 9))
	for stage: int in [Mounds.DUG, Mounds.FRAMED, Mounds.TOPPED]:
		for at: int in range(0, cells.size(), 2):
			_mounds.advance(Vector2i(cells[at], cells[at + 1]), stage)
	var whole: Array = Hill.build_arrays(Hill.snapshot(_mounds, DATUM))[0]
	assert_equal(_kind(whole, Vector2(10.0, 9.0)), MeshKit.TURF, "turfed")
	assert_equal(_kind(whole, Vector2(10.0, 11.5)), MeshKit.TURF, "the berm too")
	assert_true(Hill.hash01(Vector2(3.0, 4.0)) >= 0.0 and Hill.hash01(Vector2(3.0, 4.0)) < 1.0, "a share")
	assert_equal(Hill.hash01(Vector2(3.0, 4.0)), Hill.hash01(Vector2(3.0, 4.0)), "fixed")


func test_cut_point_says_what_a_point_is() -> void:
	"""Floor (3) on a dug cell, cut top (1) at or over the wall's top, slope or ground (0) under it."""
	_mounds.advance(Vector2i(9, 8), Mounds.DUG)
	var snap: Hill.Snapshot = Hill.snapshot(_mounds, DATUM)
	var dug: Vector2i = (Vector2i(9, 8) - snap.origin) * 4 + Vector2i(2, 2)
	assert_equal(Hill.cut_point(snap, 5.5, dug), Vector2(Hill.FLOOR_LIFT_M, 3.0), "floor")
	var heaped: Vector2i = (Vector2i(11, 9) - snap.origin) * 4 + Vector2i(2, 2)
	assert_equal(Hill.cut_point(snap, 5.5, heaped), Vector2(Field.ROOM_TOP_M, 1.0), "the cut top")
	assert_equal(Hill.cut_point(snap, 2.0, Vector2i(0, 0)), Vector2(2.0, 0.0), "a slope")
	assert_equal(Hill.cut_point(snap, 0.0, Vector2i(0, 0)), Vector2(MeshKit.UNDER_M, 0.0), "the ground")


func test_a_grid_leaves_out_quads_wholly_under_the_ground() -> void:
	"""Two quads, one under the ground: one drawn; normals from the heights; nothing above the ground: no mesh."""
	var heights: PackedFloat32Array = PackedFloat32Array([-0.03, -0.03, 1.0, -0.03, -0.03, 1.0])
	var colours: PackedColorArray = PackedColorArray()
	colours.resize(6)
	var arrays: Array = MeshKit.grid_arrays(Vector2(5.0, 7.0), 1.0, 2, heights, colours)
	assert_equal((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 6, "one quad drawn")
	assert_equal((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[2], Vector3(7.0, 1.0, 7.0), "placed in metres")
	var normal: Vector3 = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)[1]
	assert_true(normal.x < 0.0 and normal.y > 0.0, "facing down the slope: %s" % normal)
	var flat: PackedFloat32Array = PackedFloat32Array([-0.03, -0.03, -0.03, -0.03])
	colours.resize(4)
	assert_true(MeshKit.grid_arrays(Vector2.ZERO, 1.0, 1, flat, colours).is_empty(), "none above")
	assert_null(MeshKit.grid_mesh(Vector2.ZERO, 1.0, 1, flat, colours, null), "no mesh")
	var mesh: ArrayMesh = MeshKit.grid_mesh(Vector2.ZERO, 1.0, 2, heights, PackedColorArray([Color.RED, Color.RED,
		Color.RED, Color.RED, Color.RED, Color.RED]), StandardMaterial3D.new())
	assert_equal(mesh.get_surface_count(), 1, "one surface")


func test_parts_gather_into_one_surface_a_material() -> void:
	"""Every primitive placed by its transform; two materials: two surfaces; nothing gathered: no mesh."""
	var kit: MeshKit = MeshKit.new()
	assert_null(kit.commit(), "nothing yet")
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	kit.add_box(wood, Vector3(2.0, 1.0, 1.0), Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)))
	assert_equal(kit.count(), 12, "a box's twelve triangles")
	kit.add_cylinder(wood, 0.5, 0.5, 1.0, Transform3D.IDENTITY)
	kit.add_sphere(iron, 0.3, Transform3D.IDENTITY)
	kit.add_ring(iron, 0.2, 0.3, Transform3D.IDENTITY)
	kit.add_disc(iron, 0.4, Transform3D.IDENTITY)
	kit.add_arch(wood, 1.0, 0.2, Transform3D.IDENTITY)
	var mesh: ArrayMesh = kit.commit()
	assert_equal(mesh.get_surface_count(), 2, "one a material")
	assert_true(mesh.surface_get_material(0) == wood and mesh.surface_get_material(1) == iron, "in order")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var far: float = -INF
	for vertex: Vector3 in vertices:
		far = maxf(far, vertex.x)
	assert_true(is_equal_approx(far, 11.0), "the box scaled and moved: %f" % far)
	assert_true(kit.count() > 12 + 6 * 4, "every part gathered")
