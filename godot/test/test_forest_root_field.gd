extends "res://test/framework/test_case.gd"
## The trees' root support heightfield (demo/forestry/forest_root_field.gd, decision 0301, review F40)
## and the walkers' lift that reads it (forest_lift.gd). Synthetic meshes only -- no staged assets:
## the staged oak's numbers are a probe's (scratchpad), not the suite's.

const FieldScript := preload("res://demo/forestry/forest_root_field.gd")
const LiftScript := preload("res://demo/forestry/forest_lift.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const WOOD: int = 60
const EPS: float = 0.0001

var _read: IntMath.IntResult = IntMath.IntResult.new()
var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free the nodes a test made."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


static func _quad(out: PackedVector3Array, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	"""Two triangles of a flat, level square from (x0, z0) to (x1, z1) at height `y`."""
	for v: Vector3 in [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
			Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]:
		out.append(v)


func _lobe_field() -> FieldScript:
	"""One flat root lobe 0.3 m proud on the model's +X side, from 1.0 to 1.5 m out, 0.5 m wide."""
	var faces := PackedVector3Array()
	_quad(faces, 1.0, -0.25, 1.5, 0.25, 0.3)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.5)
	return field


func test_the_field_is_the_surface_under_each_cell() -> void:
	"""A cell under the lobe reads its height; the other side of the trunk and the far ground read 0;
	off the grid reads 0."""
	var field := _lobe_field()
	assert_almost_equal(field.height_local(Vector2(1.25, 0.0)), 0.3, "on the lobe")
	assert_almost_equal(field.height_local(Vector2(-1.25, 0.0)), 0.0, "the bare side")
	assert_almost_equal(field.height_local(Vector2(1.25, 1.0)), 0.0, "beside the lobe")
	assert_almost_equal(field.height_local(Vector2(9.0, 0.0)), 0.0, "off the grid")
	assert_equal(field.side, int(ceil(6.0 / FieldScript.CELL_M)), "the grid spans the reach both ways")


func test_the_highest_surface_at_or_below_the_cap_is_kept() -> void:
	"""Stacked surfaces: the higher one under the cap wins; one above the cap (a crown) and one below the
	ground are not footing."""
	var faces := PackedVector3Array()
	_quad(faces, 1.0, -0.5, 2.0, 0.5, 0.2)
	_quad(faces, 1.0, -0.5, 2.0, 0.5, 0.8)
	_quad(faces, -2.0, -0.5, -1.0, 0.5, 0.2)
	_quad(faces, -2.0, -0.5, -1.0, 0.5, FieldScript.CAP_M + 0.4)
	_quad(faces, 0.0, 1.0, 1.0, 2.0, -0.1)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.3)
	assert_almost_equal(field.height_local(Vector2(1.5, 0.0)), 0.8, "the higher root")
	assert_almost_equal(field.height_local(Vector2(-1.5, 0.0)), 0.2, "under a crown: the root below it")
	assert_almost_equal(field.height_local(Vector2(0.5, 1.5)), 0.0, "buried: the ground")


func test_a_root_rising_past_the_cap_is_footing_only_below_it() -> void:
	"""A ramp from 1.0 m to 2.2 m over a 0.2 m root: where the ramp is under CAP_M it is the footing; where
	it rises past the cap (trunk or crown) the root below is."""
	var faces := PackedVector3Array()
	_quad(faces, 1.0, -0.5, 2.0, 0.5, 0.2)
	for v: Vector3 in [Vector3(1.0, 1.0, -0.5), Vector3(2.0, 2.2, -0.5), Vector3(2.0, 2.2, 0.5),
			Vector3(1.0, 1.0, -0.5), Vector3(2.0, 2.2, 0.5), Vector3(1.0, 1.0, 0.5)]:
		faces.append(v)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.3)
	@warning_ignore("integer_division") var low: float = field.centre_of(field.side / 2 + 9)
	@warning_ignore("integer_division") var high: float = field.centre_of(field.side / 2 + 14)
	@warning_ignore("integer_division") assert_true(absf(field.height_local(Vector2(low, field.centre_of(field.side / 2))) - (1.0 + (low - 1.0) * 1.2)) < 0.002, "the ramp under the cap at %.3f" % low)
	@warning_ignore("integer_division") assert_almost_equal(field.height_local(Vector2(high, field.centre_of(field.side / 2))), 0.2, "past the cap: the root below")


func test_the_field_slopes_across_z_too_and_ends_at_its_edge() -> void:
	"""Bilinear in both directions: a ramp along z reads half way between two cell rows; a root reaching
	the grid's edge reads nothing beyond it."""
	var faces := PackedVector3Array()
	for v: Vector3 in [Vector3(-0.5, 0.0, 1.0), Vector3(0.5, 0.0, 1.0), Vector3(0.5, 0.4, 2.0),
			Vector3(-0.5, 0.0, 1.0), Vector3(0.5, 0.4, 2.0), Vector3(-0.5, 0.4, 2.0)]:
		faces.append(v)
	_quad(faces, 2.0, -0.5, 3.0, 0.5, 0.3)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.3)
	@warning_ignore("integer_division") var z0: float = field.centre_of(field.side / 2 + 10)
	@warning_ignore("integer_division") var z1: float = field.centre_of(field.side / 2 + 11)
	@warning_ignore("integer_division") var x: float = field.centre_of(field.side / 2)
	var mid: float = field.height_local(Vector2(x, (z0 + z1) * 0.5))
	assert_true(absf(mid - ((z0 + z1) * 0.5 - 1.0) * 0.4) < 0.002, "half way between rows (%.4f)" % mid)
	assert_almost_equal(field.height_local(Vector2(2.9, 0.0)), 0.3, "at the edge")
	assert_almost_equal(field.height_local(Vector2(3.2, 0.0)), 0.0, "beyond it")


func test_a_sloping_root_is_read_where_it_is() -> void:
	"""A ramp rising 0 -> 0.4 m along +X: the field follows it (bilinear between cell centres)."""
	var faces := PackedVector3Array()
	for v: Vector3 in [Vector3(1.0, 0.0, -0.5), Vector3(2.0, 0.4, -0.5), Vector3(2.0, 0.4, 0.5),
			Vector3(1.0, 0.0, -0.5), Vector3(2.0, 0.4, 0.5), Vector3(1.0, 0.0, 0.5)]:
		faces.append(v)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.3)
	@warning_ignore("integer_division") var x: float = field.centre_of(field.side / 2 + 12)
	assert_true(absf(field.height_local(Vector2(x, 0.0)) - (x - 1.0) * 0.4) < 0.002, "on the ramp at %.3f" % x)


func test_the_lookup_turns_with_the_tree() -> void:
	"""World -> tree-local: a tree at (10, 5) turned 90 degrees (the world's Basis(UP, yaw)) carries its
	+X lobe to world -Z; its size scales the distance and the height."""
	var field := _lobe_field()
	var at := Vector2(10.0, 5.0)
	assert_almost_equal(field.height_at(Vector2(11.25, 5.0), at, 0.0, 1.0), 0.3, "unturned: +X")
	assert_almost_equal(field.height_at(Vector2(10.0, 3.75), at, PI / 2.0, 1.0), 0.3, "turned: -Z")
	assert_almost_equal(field.height_at(Vector2(11.25, 5.0), at, PI / 2.0, 1.0), 0.0, "turned: +X is bare")
	assert_almost_equal(field.height_at(Vector2(10.0, 6.25), at, -PI / 2.0, 1.0), 0.3, "turned back: +Z")
	assert_almost_equal(field.height_at(Vector2(12.5, 5.0), at, 0.0, 2.0), 0.6, "twice the size: twice as far and high")
	var model := Basis(Vector3.UP, 1.1) * Vector3(1.25, 0.0, 0.1)
	assert_almost_equal(field.height_at(at + Vector2(model.x, model.z), at, 1.1, 1.0), 0.3, "the world's own turn agrees")


func test_to_local_and_to_world_are_inverse() -> void:
	"""to_world undoes to_local for any position, yaw and size."""
	for k: int in 7:
		var tree_at := Vector2(float(k) - 3.0, 2.0 * float(k))
		var yaw: float = 0.9 * float(k) - 2.0
		var size: float = 0.6 + 0.2 * float(k)
		var p := Vector2(1.7 - float(k), 0.3 * float(k))
		var back: Vector2 = FieldScript.to_world(FieldScript.to_local(p, tree_at, yaw, size), tree_at, yaw, size)
		assert_true(back.distance_to(p) < EPS, "round trip %d" % k)


func test_proud_roots_become_obstacles_and_low_ones_do_not() -> void:
	"""A ring of buttress round the trunk is one flare circle; a proud lobe beyond it gets its own circle;
	a low lobe is walked over (no circle)."""
	var faces := PackedVector3Array()
	_quad(faces, 0.5, -0.2, 0.9, 0.2, 0.9)
	_quad(faces, -0.9, -0.2, -0.5, 0.2, 0.9)
	_quad(faces, 2.0, 1.0, 2.4, 1.4, 0.7)
	_quad(faces, -2.4, -1.4, -2.0, -1.0, FieldScript.OBSTACLE_M - 0.1)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.4)
	assert_equal(field.obstacles.size(), 2, "the flare and one lobe")
	var flare: Vector3 = field.obstacles[0]
	assert_true(Vector2(flare.x, flare.y).length() < EPS and flare.z >= 0.85 and flare.z <= 1.0, "the flare circle reaches the buttress (%.3f)" % flare.z)
	var lobe: Vector3 = field.obstacles[1]
	assert_true(Vector2(lobe.x, lobe.y).distance_to(Vector2(2.2, 1.2)) < 0.2, "the proud lobe's circle on it")
	assert_almost_equal(lobe.z, FieldScript.OBSTACLE_RADIUS_M, "its radius")


func test_obstacles_are_capped() -> void:
	"""Scattered proud knuckles never make more than MAX_OBSTACLES circles."""
	var faces := PackedVector3Array()
	for i: int in 8:
		for j: int in 8:
			_quad(faces, -3.8 + i, -3.8 + j, -3.6 + i, -3.6 + j, 0.8)
	var field := FieldScript.new()
	field.bake(faces, 4.0, 0.2)
	assert_equal(field.obstacles.size(), FieldScript.MAX_OBSTACLES, "capped")


func test_obstacles_are_placed_with_the_tree() -> void:
	"""obstacles_at: the cast's public (x, radius, z), turned and scaled with the tree."""
	var faces := PackedVector3Array()
	_quad(faces, 2.0, -0.2, 2.4, 0.2, 0.8)
	var field := FieldScript.new()
	field.bake(faces, 3.0, 0.3)
	var placed: Array[Vector3] = field.obstacles_at(Vector2(4.0, -1.0), PI / 2.0, 2.0)
	assert_equal(placed.size(), 1, "one lobe")
	var local: Vector3 = field.obstacles[0]
	assert_true(local.x > 2.0 and local.x < 2.4, "the lobe's circle on the lobe (%s)" % local)
	## Turned 90 degrees, model +X is world -Z and model +Z is world +X; doubled.
	var expected := Vector2(4.0 + 2.0 * local.y, -1.0 - 2.0 * local.x)
	assert_true(Vector2(placed[0].x, placed[0].z).distance_to(expected) < EPS, "turned and doubled (%s)" % placed[0])
	assert_almost_equal(placed[0].y, FieldScript.OBSTACLE_RADIUS_M * 2.0, "radius doubled")


func test_faces_of_takes_off_the_placement_but_keeps_the_sink() -> void:
	"""A piece placed like the world places a tree (scaled, turned, let down by its sink, at its spot):
	its triangles come back in tree-local metres at size 1, the sink still under them."""
	var piece := Node3D.new()
	_nodes.append(piece)
	var child := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 0, 1)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	child.mesh = mesh
	child.position = Vector3(0.5, 0.0, 0.0)
	piece.add_child(child)
	var size: float = 1.5
	var model_scale: float = 2.0
	var sink: float = 0.6 * size
	piece.transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * model_scale * size), Vector3(9.0, -sink, -4.0))
	var faces: PackedVector3Array = FieldScript.faces_of(piece, piece.transform, 0.7, size)
	assert_equal(faces.size(), 3, "one triangle")
	assert_true(faces[0].distance_to(Vector3(3.0, -0.6, 0.0)) < 0.0001, "(1.5, 0, 0) * 2, let down 0.6 (%s)" % faces[0])
	assert_true(faces[1].distance_to(Vector3(3.0, 1.4, 0.0)) < 0.0001, "and up the model (%s)" % faces[1])


func _lift_over(field: FieldScript, scale: float) -> LiftScript:
	"""A lift over one oak at (5, 5) turned 90 degrees, reading `field` at `scale` of its size."""
	var stand := StandScript.new()
	var trees: Array[Dictionary] = [{"key": &"oak_mature", "at": Vector2(5.0, 5.0), "yaw": PI / 2.0, "size": 1.0}]
	assert_true(stand.bind_into(trees, WOOD, 1, _read), "bound")
	var lift := LiftScript.new()
	lift.configure(stand, null)
	var fields: Array[FieldScript] = [field, null]
	lift.use_fields(fields, func(_t: int) -> float: return scale)
	return lift


func test_the_lift_stands_walkers_on_the_turned_field() -> void:
	"""forest_lift.gd reads the tree's field in its own frame: the lobe a 90-degree tree carries to -Z
	lifts a walker there, not at +X; a young tree's half-size roots lift half as high, half as far."""
	var lift := _lift_over(_lobe_field(), 1.0)
	assert_almost_equal(lift.height_at(Vector2(5.0, 3.75)), 0.3, "on the turned lobe")
	assert_almost_equal(lift.height_at(Vector2(6.25, 5.0)), 0.0, "where the radial profile would lift")
	var young := _lift_over(_lobe_field(), 0.5)
	assert_almost_equal(young.height_at(Vector2(5.0, 4.375)), 0.15, "half size: half as far, half as high")
	var none := _lift_over(_lobe_field(), 0.0)
	assert_almost_equal(none.height_at(Vector2(5.0, 3.75)), 0.0, "no roots drawn: nothing lifts")


func test_a_look_without_a_field_lifts_nobody() -> void:
	"""No field for the look (a placeholder tree): the ground, everywhere."""
	var lift := _lift_over(null, 1.0)
	assert_almost_equal(lift.height_at(Vector2(5.0, 3.75)), 0.0, "no field")


func test_root_obstacles_come_from_staged_trees_in_reach() -> void:
	"""root_obstacles: one bake per model; a placeholder tree and a tree beyond the reach add nothing."""
	var trees: Array[Dictionary] = [
		{"key": &"oak_mature", "at": Vector2(3.0, 0.0), "yaw": 0.0, "size": 1.0},
		{"key": &"oak_mature", "at": Vector2(60.0, 0.0), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(-3.0, 0.0), "yaw": 0.0, "size": 1.0},
	]
	var nodes: Array[Node3D] = [_proud_piece("Oak", trees[0]), _proud_piece("Oak2", trees[1]), _proud_piece("Placeholder_beech", trees[2])]
	var out: Array[Vector3] = FieldScript.root_obstacles(trees, func(i: int) -> Node3D: return nodes[i], 30.0)
	assert_equal(out.size(), 1, "the near staged oak's lobe only")
	assert_true(absf(out[0].x - 5.2) < 0.2 and absf(out[0].z) < 0.2, "beside it (%s)" % out[0])


func _proud_piece(piece_name: String, p: Dictionary) -> Node3D:
	"""A placed piece whose only mesh is a proud lobe 2.0-2.4 m out on its +X side."""
	var faces := PackedVector3Array()
	_quad(faces, 2.0, -0.2, 2.4, 0.2, 0.8)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	var at: Vector2 = p["at"]
	piece.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y))
	_nodes.append(piece)
	return piece


func test_a_model_is_baked_once() -> void:
	"""baked(): two pieces drawing the same mesh (the woods' obstacles, then the view) share one field; a
	different mesh gets its own."""
	var p: Dictionary = {"key": &"oak_mature", "at": Vector2(3.0, 0.0), "yaw": 0.0, "size": 1.0}
	var a: MeshInstance3D = _proud_piece("A", p)
	var b := MeshInstance3D.new()
	b.mesh = a.mesh
	_nodes.append(b)
	var c: MeshInstance3D = _proud_piece("C", p)
	var first: FieldScript = FieldScript.baked(a, a.transform, 0.0, 1.0, 4.5, 1.1)
	assert_true(is_same(FieldScript.baked(b, b.transform, 0.0, 1.0, 4.5, 1.1), first), "the same mesh: the same field")
	assert_false(is_same(FieldScript.baked(c, c.transform, 0.0, 1.0, 4.5, 1.1), first), "another mesh: its own")


func test_a_model_reloaded_from_its_file_is_not_baked_again() -> void:
	"""Decision 1048: a Restart demo loads the tree models afresh -- new mesh objects with the same resource path -- and
	the cache keys the model by its path, so the restarted village finds its field and the cache does not grow (keyed by
	instance id it kept two more fields every restart)."""
	var p: Dictionary = {"key": &"oak_mature", "at": Vector2(3.0, 0.0), "yaw": 0.0, "size": 1.0}
	var a: MeshInstance3D = _proud_piece("A", p)
	var b: MeshInstance3D = _proud_piece("B", p)
	assert_false(is_same(a.mesh, b.mesh), "two mesh objects")
	a.mesh.set_path_cache("res://zz_test/oak_mature.glb::ArrayMesh_t1")
	b.mesh.set_path_cache("res://zz_test/oak_mature.glb::ArrayMesh_t1")
	var first: FieldScript = FieldScript.baked(a, a.transform, 0.0, 1.0, 4.5, 1.1)
	var held: int = FieldScript._baked.size()
	assert_true(is_same(FieldScript.baked(b, b.transform, 0.0, 1.0, 4.5, 1.1), first), "the same model: the same field")
	assert_equal(FieldScript._baked.size(), held, "nothing more held")
	b.mesh.set_path_cache("res://zz_test/beech_mature.glb::ArrayMesh_t2")
	assert_false(is_same(FieldScript.baked(b, b.transform, 0.0, 1.0, 4.5, 1.1), first), "another file's model: its own")
