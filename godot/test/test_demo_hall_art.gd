extends "res://test/framework/test_case.gd"
## Art pass 2 on the hall and the homes (decision 0951; 0771 the hall's stages, 0541 the night): the stone Great Hall
## shown in the timber hall's place at tier 2 with the timber hall's own transform (demo_world.gd STAGES, hall_view.gd),
## the composed chimney and roundels kept only as the stand-in; the linen `hall_banner` hanging upright with only its
## cloth dyed; and the homes' `_windows` models, dark by day and glowing with each home's own lamp flag
## (night_lights.gd THE WINDOWS). CI stages nothing, so the staged branches run on packed stand-in scenes seeded into
## the world's scene cache (as test_demo_world.gd's `_stage_fake` does) and on a props table that says one key is
## staged; the unstaged branches run on the empty manifest, as CI's demo does.

const DemoWorld := preload("res://demo/world/demo_world.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Curves := preload("res://demo/world/daylight_curves.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const NightLightsScript := preload("res://demo/world/night_lights.gd")
const ViewScript := preload("res://demo/hall/hall_view.gd")
const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## Set-level calls the allocation check makes (a dawn and a dusk's worth of easing, and more).
const RAMPS: int = 2000


## A props table on which the linen banner is staged: a two-surface stand-in, the cloth and the wood each in its own
## material, drawn at the banner's size by the same fit a staged row gets (its base on y = 0).
class LinenProps extends "res://demo/props/demo_props.gd":
	func is_staged(key: StringName) -> bool:
		"""Only the linen banner is staged."""
		return key == &"hall_banner"

	func instance(key: StringName) -> MeshInstance3D:
		"""The banner's two-surface stand-in; every other key its placeholder."""
		if key != &"hall_banner":
			return super.instance(key)
		var mesh := ArrayMesh.new()
		for surface: int in 2:
			var arrays: Array = BoxMesh.new().get_mesh_arrays()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := StandardMaterial3D.new()
			material.resource_name = "banner_cloth" if surface == 0 else "banner_wood"
			mesh.surface_set_material(surface, material)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.transform = Transform3D.IDENTITY
		return node


var _world: DemoWorld = null
var _nodes: Array[Node] = []


func before_each() -> void:
	"""A fresh, unbuilt world outside any tree."""
	_world = DemoWorld.new()


func after_each() -> void:
	"""Free the world and every node a test made."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _world != null:
		_world.free()
		_world = null


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


func _stage(key: StringName, bound_key: StringName, glowing: bool) -> StandardMaterial3D:
	"""Seed a staged model of `key` into the world's scene cache: one box whose material glows (a windows model's mask,
	energy 1 as imported) or not, with `bound_key`'s recorded bound as its row. Returns the model's shared material."""
	var root := Node3D.new()
	root.name = "Staged_%s" % key
	var shape := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var material := StandardMaterial3D.new()
	material.emission_enabled = glowing
	material.emission = Color(0.851, 0.592, 0.263)
	mesh.surface_set_material(0, material)
	shape.mesh = mesh
	root.add_child(shape)
	shape.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var bound: Array = Sizes.NATIVE_AABB[bound_key]
	var lo: Vector3 = bound[0]
	var hi: Vector3 = bound[1]
	_world._scenes[key] = packed
	_world._world_rows[String(key)] = {"path": "", "aabb_min": [lo.x, lo.y, lo.z], "aabb_max": [hi.x, hi.y, hi.z]}
	return material


func _build_staged() -> void:
	"""Build the world from the rows seeded so far."""
	_world.build({"world": _world._world_rows.duplicate(), "cast": {}})


static func _great(projects: ProjectsScript) -> void:
	"""The upgrade carried in and built: tier 2."""
	projects.plan_upgrade()
	for mat: int in Rules.MAT_COUNT:
		var need: int = Rules.need_milli(Rules.PROJECT_UPGRADE, mat)
		if need > 0:
			projects.deliver(Rules.PROJECT_UPGRADE, mat, projects.lift(Rules.PROJECT_UPGRADE, mat,
				projects.reserve(Rules.PROJECT_UPGRADE, mat, need)))
	projects.add_work(Rules.PROJECT_UPGRADE, Rules.UPGRADE_WU * Rules.USEC_PER_WU, 0)


static func _projects() -> ProjectsScript:
	"""Projects over stores that can pay for the upgrade, unlocked."""
	var stores := StoresScript.new()
	stores.wood_milli_u = 21000
	stores.stone_milli_u = 40000
	var projects := ProjectsScript.new(stores)
	projects.unlocked = true
	return projects


# --- the world: the homes' windows models and the hall's later stage ------------------------------------------------

func test_nothing_staged_draws_the_plain_homes_and_no_stage() -> void:
	"""The empty manifest (CI): every home its placeholder, no stone hall, no window materials."""
	_world.build({"world": {}, "cast": {}})
	assert_not_null(_world.placed_node(&"hall"), "the timber hall is drawn")
	assert_true(String(_world.placed_node(&"hall").name).begins_with("Placeholder"), "as its placeholder")
	assert_null(_world.stage_node(&"hall"), "no stone hall")
	assert_null(_world.placed_node(&"nothing"), "no such placement")
	for id: StringName in Curves.LIT_HOMES:
		assert_true(_world.window_glow(id).is_empty(), "%s: no window materials" % id)


func test_a_lit_home_is_drawn_with_its_windows_model_dark() -> void:
	"""A staged `<key>_windows` model replaces the plain one at the plain one's scale; its glow is a dark duplicate per
	home, the shared model untouched; a windows model without its plain model, or a home not lit, keeps the plain."""
	_stage(&"hall", &"hall", false)
	var shared: StandardMaterial3D = _stage(&"hall_windows", &"hall", true)
	_stage(&"kitchen_windows", &"kitchen", true)
	_build_staged()
	var hall: Node3D = _world.placed_node(&"hall")
	assert_equal(String(hall.name), "Staged_hall_windows", "the hall drawn with its windows")
	var plain := DemoWorld.piece_transform(Layout.find_placement(Layout.placements(), &"hall"),
		_world._staged_scale(_world._world_rows, &"hall"), Sizes.sink_m(&"hall", 1.0))
	assert_true(hall.transform.is_equal_approx(plain), "at the plain hall's own transform")
	var glow: Array = _world.window_glow(&"hall")
	assert_equal(glow.size(), 1, "one window material")
	assert_almost_equal((glow[0] as BaseMaterial3D).emission_energy_multiplier, 0.0, "dark until the night drives it")
	assert_false(glow[0] == shared, "a duplicate")
	assert_almost_equal(shared.emission_energy_multiplier, 1.0, "the shared model untouched")
	var drawn := hall.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_true(is_same(drawn.get_surface_override_material(0), glow[0]), "the listed material is the one drawn")
	assert_true(String(_world.placed_node(&"kitchen").name).begins_with("Placeholder"), "no plain kitchen: plain")
	assert_true(_world.window_glow(&"kitchen").is_empty(), "and no glow")


func test_only_a_lit_home_takes_its_windows_model() -> void:
	"""A `<key>_windows` row for a placement that is not a lit home (the well) is never drawn."""
	_stage(&"well", &"well", false)
	_stage(&"well_windows", &"well", true)
	_build_staged()
	assert_equal(String(_world.placed_node(&"well").name), "Staged_well", "the plain well")
	assert_true(_world.window_glow(&"well").is_empty(), "no glow")


func test_each_home_glows_on_its_own_material() -> void:
	"""The three residences share one model, but each has its own window material (each home's flag is its own)."""
	_stage(&"residence", &"residence", false)
	_stage(&"residence_windows", &"residence", true)
	_build_staged()
	var a: Array = _world.window_glow(&"residence_a")
	var b: Array = _world.window_glow(&"residence_b")
	assert_equal(a.size() + b.size() + _world.window_glow(&"residence_c").size(), 3, "one each")
	assert_false(a[0] == b[0], "not shared")


func test_the_stone_stage_is_built_hidden_at_the_timber_halls_transform() -> void:
	"""hall_stage2 (its windows model when staged) stands hidden in the village with the timber hall's own transform --
	not scaled by its own height -- and its windows join the hall's glow."""
	_stage(&"hall", &"hall", false)
	_stage(&"hall_stage2", &"hall", false)
	_stage(&"hall_stage2_windows", &"hall", true)
	_build_staged()
	var stage: Node3D = _world.stage_node(&"hall")
	assert_not_null(stage, "built")
	assert_equal(String(stage.name), "Stage_hall_stage2", "named for its key")
	assert_false(stage.visible, "hidden until tier 2")
	assert_equal(stage.get_parent(), _world.get_node(^"Village"), "in the village, as every piece")
	assert_true(stage.transform.is_equal_approx(_world.placed_node(&"hall").transform), "the timber hall's transform")
	assert_equal(_world.window_glow(&"hall").size(), 1, "its windows glow with the hall")


func test_no_stage_without_the_timber_hall_staged() -> void:
	"""The stone hall needs the timber hall's staged transform: a placeholder hall has none to give."""
	_stage(&"hall_stage2", &"hall", false)
	_build_staged()
	assert_null(_world.stage_node(&"hall"), "no stone hall over a placeholder")


func test_a_rebuild_refills_the_same_glow_list() -> void:
	"""The list a holder keeps is the one a rebuild refills (not appended to, not replaced)."""
	_stage(&"hall", &"hall", false)
	_stage(&"hall_windows", &"hall", true)
	_build_staged()
	var held: Array = _world.window_glow(&"hall")
	_build_staged()
	assert_true(is_same(held, _world.window_glow(&"hall")), "the same list")
	assert_equal(held.size(), 1, "refilled, not appended")


# --- the night lights: the windows glow with each home's lamp ---------------------------------------------------------

func _lit_windows() -> Array:
	"""[lights, materials per home]: the pool over the homes, each home given one window material."""
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO)
	var lists: Dictionary = {}
	for id: StringName in Curves.LIT_HOMES:
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		lists[id] = [material]
	lights.bind_windows(func(id: StringName) -> Array: return lists[id])
	return [lights, lists]


func test_the_windows_are_dark_by_day_and_glow_with_each_homes_lamp() -> void:
	"""Level 0: dark. Night: WINDOW_GLOW x the level, each home by its own lamp flag (the hall's hearth cold: dark)."""
	var made: Array = _lit_windows()
	var lights: NightLightsScript = made[0]
	var lists: Dictionary = made[1]
	var hall: BaseMaterial3D = (lists[&"hall"] as Array)[0]
	var kitchen: BaseMaterial3D = (lists[&"kitchen"] as Array)[0]
	assert_almost_equal(hall.emission_energy_multiplier, 0.0, "by day: dark")
	lights.set_level(1.0)
	assert_almost_equal(hall.emission_energy_multiplier, NightLightsScript.WINDOW_GLOW, "night: the hall glows")
	assert_almost_equal(kitchen.emission_energy_multiplier, NightLightsScript.WINDOW_GLOW, "and the kitchen")
	var cold := {0: true}
	lights.set_home_lit(func(k: int) -> bool: return not cold.has(k))
	assert_almost_equal(hall.emission_energy_multiplier, 0.0, "the hall's hearth cold: its windows dark")
	assert_almost_equal(kitchen.emission_energy_multiplier, NightLightsScript.WINDOW_GLOW, "the kitchen still lit")
	lights.set_level(0.5)
	assert_almost_equal(kitchen.emission_energy_multiplier, NightLightsScript.WINDOW_GLOW * 0.5, "dusk: half")
	assert_almost_equal(hall.emission_energy_multiplier, 0.0, "the cold hall stays dark")
	cold.clear()
	assert_true(lights.read_homes(), "the hall relit: a change")
	assert_almost_equal(hall.emission_energy_multiplier, NightLightsScript.WINDOW_GLOW * 0.5, "its windows with it")
	lights.set_level(0.0)
	assert_almost_equal(hall.emission_energy_multiplier, 0.0, "day again: dark")
	assert_almost_equal(lights.window_energy(4), 0.0, "the kitchen written dark")


func test_the_windows_are_written_only_when_their_value_changes() -> void:
	"""The same level, or the same lamp answers: nothing written."""
	var lights: NightLightsScript = _lit_windows()[0]
	lights.set_level(1.0)
	var writes: int = lights.glow_writes
	lights.set_level(1.0)
	assert_equal(lights.glow_writes, writes, "the same level: nothing")
	assert_false(lights.read_homes(), "the same answers")
	assert_equal(lights.glow_writes, writes, "nothing")
	lights.write_windows()
	assert_equal(lights.glow_writes, writes, "asked again unchanged: nothing")
	lights.set_level(0.9)
	assert_equal(lights.glow_writes, writes + Curves.LIT_HOMES.size(), "a new level: each home once")
	writes = lights.glow_writes
	lights.write_windows()
	assert_equal(lights.glow_writes, writes, "at 0.9 (not exact in float32), asked again: nothing")
	lights.set_home_lit(func(k: int) -> bool: return k != 0)
	assert_equal(lights.glow_writes, writes + 1, "one home's flag: that home alone")


func test_the_full_night_glow_is_the_art_maps_value() -> void:
	"""art_pass2_mapping.md, Window glow masks: emission 0 by day, "about 1.5" at night."""
	assert_almost_equal(NightLightsScript.WINDOW_GLOW, 1.5, "about 1.5")


func test_without_windows_bound_nothing_is_written() -> void:
	"""No binding (nothing staged, or the village not wired): the level and the lamps run as before."""
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO)
	lights.set_level(1.0)
	lights.update(Vector3.ZERO)
	assert_equal(lights.glow_writes, 0, "nothing written")
	assert_almost_equal(lights.window_energy(0), -1.0, "never")
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size(), "the door lamps lit as before")


func test_an_empty_glow_list_is_bound_harmlessly() -> void:
	"""The world's lists with nothing staged are empty: bound, written, nothing to write to."""
	_world.build({"world": {}, "cast": {}})
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO)
	lights.bind_windows(_world.window_glow)
	lights.set_level(1.0)
	assert_almost_equal(lights.window_energy(0), NightLightsScript.WINDOW_GLOW, "the value kept")
	assert_true(_world.window_glow(&"hall").is_empty(), "no materials")


func test_the_window_glow_allocates_nothing() -> void:
	"""RAMPS level changes through dawn and dusk with every home's windows bound: no object kept."""
	var lights: NightLightsScript = _lit_windows()[0]
	lights.set_level(0.5)
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in RAMPS:
		lights.set_level(float(k % 100) / 100.0)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects, 0, "no object kept")


# --- the hall view: the stone hall, the stand-in, the banner --------------------------------------------------------

func test_the_stone_hall_replaces_the_timber_one_at_tier_2() -> void:
	"""Staged: the timber hall until tier 2, then the stone hall in its place, its own chimney (none composed) and the two
	roundels in its outer bays (Brendan's ruling on decision 0903)."""
	_stage(&"hall", &"hall", false)
	_stage(&"hall_stage2", &"hall", false)
	_build_staged()
	var view: ViewScript = _keep(ViewScript.new())
	view.build(_world, null)
	var projects := _projects()
	view.sync(projects)
	assert_equal(view.composed_pieces(), ViewScript.ROUNDEL_X.size(), "the roundels, no composed chimney")
	assert_false(view.stone_shown() or view.great_shown(), "tier 1: the timber hall")
	assert_true(_world.placed_node(&"hall").visible, "standing")
	_great(projects)
	view.sync(projects)
	assert_true(view.stone_shown() and view.great_shown(), "tier 2: the stone hall")
	assert_true(view.composed_shown() == ViewScript.ROUNDEL_X.size(), "with its roundels")
	assert_false(_world.placed_node(&"hall").visible, "the timber hall hidden")


func test_without_the_stone_hall_the_composed_stand_in_stays() -> void:
	"""Nothing staged: the composed chimney and two roundels on the timber hall at tier 2, as before."""
	_world.build({"world": {}, "cast": {}})
	var view: ViewScript = _keep(ViewScript.new())
	view.build(_world, null)
	assert_equal(view.composed_pieces(), 1 + ViewScript.ROUNDEL_X.size(), "the chimney and the roundels")
	var projects := _projects()
	_great(projects)
	view.sync(projects)
	assert_true(view.great_shown() and not view.stone_shown(), "the composed great hall")
	assert_true(_world.placed_node(&"hall").visible, "on the timber hall")


func test_the_linen_banner_hangs_upright_and_dyes_only_its_cloth() -> void:
	"""hall_banner staged: upright (no lie-flat turn), centred HANGING_Y up the facade; its cloth (surface 0) dyed with
	its bay's tint, its wood (surface 1) never."""
	var view: ViewScript = _keep(ViewScript.new())
	view.build(null, LinenProps.new())
	assert_equal(view.banner_model(), ViewScript.BANNER_KEY, "the linen banner")
	for k: int in ViewScript.BANNER_X.size():
		var node: MeshInstance3D = view.banner_node(k)
		var cloth := node.get_surface_override_material(0) as BaseMaterial3D
		assert_not_null(cloth, "banner %d: its cloth dyed" % k)
		assert_true(cloth.albedo_color.is_equal_approx(ViewScript.BANNER_DYES[k]), "banner %d: its tint" % k)
		assert_null(node.get_surface_override_material(1), "banner %d: its wood never" % k)
		assert_null(node.material_override, "banner %d: no whole-mesh override" % k)
		assert_true(node.transform.basis.y.normalized().is_equal_approx(Vector3.UP), "banner %d: upright" % k)
		var bottom: float = ViewScript.HANGING_Y - PropsScript.drawn_size_m(ViewScript.BANNER_KEY) * 0.5
		assert_almost_equal(node.transform.origin.y, bottom, "banner %d: hung centred on the bay" % k)


func test_without_the_linen_banner_the_stand_in_hangs() -> void:
	"""Not staged: the stand-in banner, stood upright from lying flat and scaled to the facade, dyed whole."""
	var view: ViewScript = _keep(ViewScript.new())
	view.build(null, PropsScript.new())
	assert_equal(view.banner_model(), ViewScript.STAND_IN_BANNER_KEY, "the stand-in")
	var node: MeshInstance3D = view.banner_node(0)
	assert_false(node.transform.basis.y.normalized().is_equal_approx(Vector3.UP), "turned up from lying flat")
	assert_not_null(node.material_override, "dyed whole, as before")
