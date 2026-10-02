extends "res://test/framework/test_case.gd"
## A regrowing tree's young stage (demo/forestry/forest_view.gd GROWING, decision 0301, review F52):
## one height ramp from the shoot to the mature tree, the model swapped at equal height, the young tree
## drawn as its own mature model scaled about its foot with its sink scaled the same, the unscaled
## standing transform kept for the fall. A fake staged column -- no staged assets.

const IntMath := preload("res://scripts/core/int_math.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")

const WOOD: int = 60
const FAKE_HEIGHT: float = 1.9
const OAK: int = 0
const SAPLING: int = 2
const HOURS: int = Rules.REGROW_DAYS * 24

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test made."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _column() -> PackedScene:
	"""A stand-in staged tree: one column standing on the model's base."""
	var box := BoxMesh.new()
	box.size = Vector3(1.0, FAKE_HEIGHT, 1.0)
	box.subdivide_height = 19
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i].y += FAKE_HEIGHT * 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var root := Node3D.new()
	var column := MeshInstance3D.new()
	column.mesh = mesh
	root.add_child(column)
	column.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _view() -> Array:
	"""[stand, view]: an oak, a beech and a sapling, the mature trees 'staged' (the fake column) and let
	down by their sinks, drawn on day 1."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	for key: StringName in StandScript.LOOK_KEYS:
		world._scenes[key] = _column()
		world._world_rows[String(key)] = {"path": "", "aabb_min": [0.0, 0.0, 0.0], "aabb_max": [1.0, FAKE_HEIGHT, 1.0]}
	var stand := StandScript.new()
	var trees: Array[Dictionary] = [
		{"key": &"oak_mature", "at": Vector2(-10.0, -24.0), "yaw": 0.4, "size": 0.95},
		{"key": &"beech_mature", "at": Vector2(0.0, -24.0), "yaw": 0.5, "size": 1.1},
		{"key": &"oak_sapling", "at": Vector2(6.0, -20.0), "yaw": 1.0, "size": 1.0},
	]
	assert_true(stand.bind_into(trees, WOOD, 1, _read), "bound")
	var view := _keep(ViewScript.new()) as ViewScript
	view.configure(stand, func(_p: int) -> Node3D: return null, world.make_piece, _services.props)
	view.staged = true
	view.sync(1, 7)
	return [stand, view]


func _at_hour(view: ViewScript, hour: int) -> void:
	"""Draw the woods `hour` hours after day 1's midnight (a regrowth dated day 1)."""
	@warning_ignore("integer_division") view.sync(1 + hour / 24, hour % 24)


func _first_young_hour(view: ViewScript, t: int) -> int:
	"""The first hour of the regrowth at which tree `t` is drawn as a young tree (-1: never)."""
	for hour: int in HOURS:
		_at_hour(view, hour)
		if view.young_share(t) > 0.0:
			return hour
	return -1


func _felled(stand: StandScript, view: ViewScript, t: int) -> void:
	"""Fell tree `t` on day 1 and finish its fall."""
	assert_true(stand.fell_into(t, 1, Vector2(1.0, 0.0), false, _read), "felled")
	view.sync(1, 8)
	view.advance(ViewScript.FALL_S + ViewScript.LIE_S + 0.1)


func test_young_transform_scales_the_tree_and_its_sink_about_its_foot() -> void:
	"""young_transform: the basis scaled by the share, the let-down scaled the same, the spot kept."""
	var rest := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 6.0), Vector3(3.0, -1.2, -4.0))
	var young: Transform3D = ViewScript.young_transform(rest, 0.25)
	assert_almost_equal(young.basis.get_scale().x, 1.5, "a quarter the size")
	assert_almost_equal(young.origin.y, -0.3, "a quarter the sink")
	assert_true(Vector2(young.origin.x, young.origin.z).is_equal_approx(Vector2(3.0, -4.0)), "on its spot")
	assert_true(young.basis.get_rotation_quaternion().is_equal_approx(rest.basis.get_rotation_quaternion()), "turned the same")
	assert_true(ViewScript.young_transform(rest, 1.0).is_equal_approx(rest), "full size: the rest pose")


func test_the_stump_swaps_to_a_young_tree_at_equal_height() -> void:
	"""The shoot grows on the ramp to the sapling's full size; the next hour the oak's own model stands,
	about a third its size, as tall as the shoot was (within one hour's growth)."""
	var made: Array = _view()
	var stand: StandScript = made[0]
	var view: ViewScript = made[1]
	_felled(stand, view, OAK)
	var swap: int = _first_young_hour(view, OAK)
	assert_true(swap > 0 and swap < HOURS - 24, "the swap comes during the regrowth (hour %d)" % swap)
	_at_hour(view, swap - 1)
	var sapling_h: float = Sizes.target_height_m(StandScript.SAPLING_KEY) * view.young_node(OAK).transform.basis.get_scale().x / view._young_base[OAK]
	_at_hour(view, swap)
	var share: float = view.young_share(OAK)
	var tree_h: float = Sizes.target_height_m(&"oak_mature") * stand.size[OAK] * share
	## The row's growth is whole permille: one step of the ramp is a thousandth of its rise.
	var mature_h: float = Sizes.target_height_m(&"oak_mature") * stand.size[OAK]
	var step: float = (mature_h - ViewScript.GROW_FROM * Sizes.target_height_m(StandScript.SAPLING_KEY)) / 1000.0
	assert_true(absf(tree_h - sapling_h) <= step * 1.01, "equal heights at the swap, within a permille (%.4f, %.4f)" % [sapling_h, tree_h])
	assert_true(share > 0.28 and share < 0.4, "about a third (%.3f)" % share)


func test_at_the_swap_the_stump_goes_and_the_young_tree_stands_at_the_centre() -> void:
	"""Past the swap: the stump model, the stub and the shoot are hidden; the tree's own node stands on
	its spot, scaled by the share, let down by the share of its sink."""
	var made: Array = _view()
	var stand: StandScript = made[0]
	var view: ViewScript = made[1]
	_felled(stand, view, OAK)
	_at_hour(view, 5)
	assert_true(view.young_visible(OAK) and view.stump_key(OAK) != &"", "first a shoot by a stump")
	_at_hour(view, _first_young_hour(view, OAK) + 30)
	var share: float = view.young_share(OAK)
	var node: Node3D = view._tree_nodes[OAK]
	assert_false(view.young_visible(OAK), "the shoot is gone")
	assert_equal(view.stump_key(OAK), &"", "the stump is gone")
	assert_false(view._lower_nodes[OAK] != null and view._lower_nodes[OAK].visible, "the stub is gone")
	assert_true(view.tree_visible(OAK), "the young tree stands")
	assert_almost_equal(node.position.x, stand.at[OAK].x, "at the centre (x)")
	assert_almost_equal(node.position.z, stand.at[OAK].y, "at the centre (z)")
	assert_almost_equal(node.position.y, -Sizes.sink_m(&"oak_mature", stand.size[OAK]) * share, "the sink scaled")
	assert_almost_equal(node.transform.basis.get_scale().x, view._tree_rest[OAK].basis.get_scale().x * share, "the model scaled")
	assert_almost_equal(view.mound_scale(OAK), share, "the walkers stand on the young tree's roots, at its share")


func test_the_young_tree_grows_to_full_size_and_matures_seamlessly() -> void:
	"""At the last hour before maturity it is nearly full size; matured, it stands at its rest pose, and a
	fall then reads the unscaled pose."""
	var made: Array = _view()
	var stand: StandScript = made[0]
	var view: ViewScript = made[1]
	_felled(stand, view, OAK)
	_at_hour(view, HOURS - 1)
	assert_true(view.young_share(OAK) > 0.99, "nearly full at the last hour (%.4f)" % view.young_share(OAK))
	var matured := PackedInt32Array()
	stand.regrow_due(1 + Rules.REGROW_DAYS, func(_at: Vector2) -> bool: return false, matured)
	assert_equal(stand.state_of(OAK), StandScript.STATE_MATURE, "regrown")
	view.sync(1 + Rules.REGROW_DAYS, 0)
	assert_true(view._tree_nodes[OAK].transform.is_equal_approx(view._tree_rest[OAK]), "full size: the rest pose")
	assert_almost_equal(view.mound_scale(OAK), 1.0, "its roots at full size")
	assert_true(stand.fell_into(OAK, 2 + Rules.REGROW_DAYS, Vector2(0.0, 1.0), false, _read), "felled again")
	view.sync(2 + Rules.REGROW_DAYS, 1)
	assert_almost_equal(view._rest[OAK].basis.get_scale().x, view._tree_rest[OAK].basis.get_scale().x, "the fall turns the full-size crown")


func test_an_occupied_spot_keeps_its_shoot() -> void:
	"""With something standing on the spot the stump cannot regrow (§5.9), so no young tree is drawn over
	it: the shoot stays, at the sapling's full size at most."""
	var made: Array = _view()
	var stand: StandScript = made[0]
	var view: ViewScript = made[1]
	view.set_occupied(func(_at: Vector2) -> bool: return true)
	_felled(stand, view, OAK)
	_at_hour(view, HOURS - 1)
	assert_almost_equal(view.young_share(OAK), 0.0, "no young tree")
	assert_true(view.young_visible(OAK) and view.stump_key(OAK) != &"", "the shoot by its stump")
	var share: float = view.young_node(OAK).transform.basis.get_scale().x / view._young_base[OAK]
	assert_almost_equal(share, ViewScript.GROW_TO, "the shoot held at the sapling's full size")


func test_the_drawn_growth_is_the_calendar_hours_whatever_the_speed() -> void:
	"""At 1x the woods redraw every hour; at 4x the frames step several hours at once. The drawing is a
	function of the calendar's hour alone, so both reach the same pose."""
	var a: Array = _view()
	var b: Array = _view()
	for made: Array in [a, b]:
		_felled(made[0], made[1], OAK)
	for hour: int in range(0, 700):
		_at_hour(a[1], hour)
	for hour: int in range(0, 700, 4):
		_at_hour(b[1], hour)
	_at_hour(b[1], 699)
	var view_a: ViewScript = a[1]
	var view_b: ViewScript = b[1]
	assert_almost_equal(view_a.young_share(OAK), view_b.young_share(OAK), "the same share")
	assert_true(view_a._tree_nodes[OAK].transform.is_equal_approx(view_b._tree_nodes[OAK].transform), "the same pose")


func test_a_sapling_becomes_the_mature_model_on_its_ramp() -> void:
	"""The demo's own sapling (the world's sapling node) grows on the same ramp and is replaced by an oak
	model made the world's way past its full size; its roots scale with it."""
	var made: Array = _view()
	var view: ViewScript = made[1]
	assert_almost_equal(view.mound_scale(SAPLING), 0.0, "a sapling has no roots to stand on")
	_at_hour(view, 2)
	assert_true(view.young_visible(SAPLING), "a sapling first")
	var swap: int = _first_young_hour(view, SAPLING)
	assert_true(swap > 0, "it swaps (hour %d)" % swap)
	assert_not_null(view._tree_nodes[SAPLING], "an oak model made for it")
	assert_true(view.tree_visible(SAPLING) and not view.young_visible(SAPLING), "the young oak, not the sapling")
	assert_almost_equal(view.mound_scale(SAPLING), view.young_share(SAPLING), "its roots at its share")


func test_the_mound_scale_follows_what_is_drawn() -> void:
	"""mound_scale: a standing tree 1, a stump's mound 1 while its shoot grows, 0 once cleared."""
	var made: Array = _view()
	var stand: StandScript = made[0]
	var view: ViewScript = made[1]
	assert_almost_equal(view.mound_scale(OAK), 1.0, "standing")
	_felled(stand, view, OAK)
	_at_hour(view, 3)
	assert_almost_equal(view.mound_scale(OAK), 1.0, "the stump's mound")
	assert_true(stand.grub_into(OAK, _read), "grubbed out")
	view.sync(1, 4)
	assert_almost_equal(view.mound_scale(OAK), 0.0, "cleared")
