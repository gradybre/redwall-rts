extends "res://test/framework/test_case.gd"
## Frost and snow lying on surfaces (demo/weather/weather_view.gd FROST AND SNOW, decision 0301, review
## F42): no camera-following sheet; the ground's and the bank film's own shaders take the cover, the
## village's buildings and props wear the cover overlay, the trees and the water do not. The placeholder
## village -- no staged assets.

const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const BANK_SHADER := preload("res://demo/water/water_bank.gdshader")
const WATER_SHADER := preload("res://demo/water/water.gdshader")
const COVER_SHADER := preload("res://demo/weather/snow_cover.gdshader")

var _nodes: Array[Object] = []


func after_each() -> void:
	"""Free every node a test made."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _village() -> Array:
	"""[root, world, view, weather]: the placeholder village under a root that also holds a bank film and
	a water surface, with the weather view configured over the world."""
	var root := Node3D.new()
	_nodes.append(root)
	var world := DemoWorldScript.new()
	root.add_child(world)
	world.build({})
	for node_name: String in ["WaterBank", "WaterSurface_stream"]:
		var film := MeshInstance3D.new()
		film.name = node_name
		var material := ShaderMaterial.new()
		material.shader = BANK_SHADER if node_name == "WaterBank" else WATER_SHADER
		film.material_override = material
		film.mesh = PlaneMesh.new()
		root.add_child(film)
	var weather := WeatherScript.new()
	var view := WeatherViewScript.new()
	root.add_child(view)
	view.configure(weather, DemoClockScript.new(), world)
	return [root, world, view, weather]


func _weather_is(weather: WeatherScript, view: WeatherViewScript, condition: int) -> void:
	"""Make the weather this condition and let the look arrive at once."""
	match condition:
		WeatherScript.COND_SNOW:
			weather.observe(3, 2, 15, -50, 1200, -1)
		WeatherScript.COND_FROST:
			weather.observe(3, 1, 0, -50, 100, -1)
		_:
			weather.observe(0, 3, 12, 150, 0, -1)
	assert_equal(weather.condition(), condition, "the weather reads %d" % condition)
	view._apply_targets(1.0)


func test_there_is_no_camera_following_sheet() -> void:
	"""The view draws no ground plane of its own: its only children are the falls (particles)."""
	var made: Array = _village()
	var view: WeatherViewScript = made[2]
	for child: Node in view.get_children():
		assert_true(child is CPUParticles3D, "%s is a fall, not a sheet" % child.name)


func test_the_ground_and_the_bank_take_the_cover_and_the_water_does_not() -> void:
	"""Snow: the ground's and the bank film's shaders get the cover; the water surface's material is not
	among the cover's and is never written."""
	var made: Array = _village()
	var root: Node3D = made[0]
	var world: DemoWorldScript = made[1]
	var view: WeatherViewScript = made[2]
	_weather_is(made[3], view, WeatherScript.COND_SNOW)
	var ground := (world.find_child("Ground", true, false) as MeshInstance3D).get_active_material(0) as ShaderMaterial
	var bank := (root.get_node("WaterBank") as MeshInstance3D).get_active_material(0) as ShaderMaterial
	var water := (root.get_node("WaterSurface_stream") as MeshInstance3D).get_active_material(0) as ShaderMaterial
	assert_true(view.cover_materials().has(ground) and view.cover_materials().has(bank), "ground and bank")
	assert_false(view.cover_materials().has(water), "not the water")
	for material: ShaderMaterial in [ground, bank]:
		assert_almost_equal(float(material.get_shader_parameter(&"snow_cover")), 1.0, "snow lies")
		assert_almost_equal(float(material.get_shader_parameter(&"frost_cover")), 0.0, "snow, not frost")
		assert_almost_equal(float(material.get_shader_parameter(&"water_level_y")), -WaterRules.to_m(WaterLayout.LEVEL_DROP_U), "stops at the water line")
	assert_null(water.get_shader_parameter(&"snow_cover"), "the water is never given a cover")


func test_the_shaders_that_take_the_cover_declare_it() -> void:
	"""The ground, bank and overlay shaders all have the cover's uniforms (a renamed one would silently do
	nothing); the water shader has none."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	world.build({})
	var ground := (world.find_child("Ground", true, false) as MeshInstance3D).get_active_material(0) as ShaderMaterial
	for shader: Shader in [ground.shader, BANK_SHADER, COVER_SHADER]:
		var names: PackedStringArray = PackedStringArray()
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names.append(String(uniform["name"]))
		for wanted: String in ["snow_cover", "frost_cover", "snow_color", "water_level_y"]:
			assert_true(names.has(wanted), "%s declares %s" % [shader.resource_path, wanted])
	for uniform: Dictionary in WATER_SHADER.get_shader_uniform_list():
		assert_false(String(uniform["name"]).contains("snow"), "the water has no cover")


func test_frost_is_a_thinner_cover_than_snow() -> void:
	"""COVER and FROSTY: snow lies fully, frost at its own share and flagged as frost; rain lays none."""
	var made: Array = _village()
	var view: WeatherViewScript = made[2]
	_weather_is(made[3], view, WeatherScript.COND_FROST)
	assert_almost_equal(view.cover(), WeatherViewScript.COVER[WeatherScript.COND_FROST], "frost's cover")
	assert_almost_equal(view.frost(), 1.0, "all frost")
	assert_true(view.cover() < WeatherViewScript.COVER[WeatherScript.COND_SNOW], "thinner than snow")
	_weather_is(made[3], view, WeatherScript.COND_SNOW)
	assert_almost_equal(view.frost(), 0.0, "snow")
	assert_almost_equal(WeatherViewScript.COVER[WeatherScript.COND_RAIN], 0.0, "rain lays nothing")


func test_buildings_and_props_wear_the_overlay_and_trees_do_not() -> void:
	"""While a cover lies, every building and prop mesh of the village wears the cover overlay; the trees
	and the ground cover's MultiMeshes never do; a clear day takes it off."""
	var made: Array = _village()
	var world: DemoWorldScript = made[1]
	var view: WeatherViewScript = made[2]
	_weather_is(made[3], view, WeatherScript.COND_SNOW)
	assert_true(view.overlaid_count() > 10, "the village wears it (%d)" % view.overlaid_count())
	var trees: Dictionary = {}
	for i: int in world.trees().size():
		trees[world.tree_node(i)] = true
	var dressed: int = 0
	for piece: Node in world.get_node("Village").get_children():
		for node: Node in piece.find_children("*", "MeshInstance3D", true, false) + ([piece] if piece is MeshInstance3D else []):
			var overlay: Material = (node as MeshInstance3D).material_overlay
			if trees.has(piece):
				assert_null(overlay, "a tree wears none")
			else:
				dressed += 1 if overlay != null and (overlay as ShaderMaterial).shader == COVER_SHADER else 0
	assert_equal(dressed, view.overlaid_count(), "every one counted wears the cover shader")
	_weather_is(made[3], view, WeatherScript.COND_CLEAR)
	assert_equal(view.overlaid_count(), 0, "a clear day takes it off")


func test_the_cover_eases_in_on_the_demo_clock() -> void:
	"""Like the light, the cover comes over EASE_S of demo time: half way after half of it."""
	var made: Array = _village()
	var view: WeatherViewScript = made[2]
	var weather: WeatherScript = made[3]
	weather.observe(3, 2, 15, -50, 1200, -1)
	view._apply_targets(0.5)
	assert_almost_equal(view.cover(), 0.5, "half way")


func test_configuring_again_keeps_one_set_of_falls() -> void:
	"""tunnel_ext.gd configures the view twice (without, then with, the world): one rain and one snow."""
	var made: Array = _village()
	var view: WeatherViewScript = made[2]
	view.configure(made[3], DemoClockScript.new(), made[1])
	var falls: int = 0
	for child: Node in view.get_children():
		falls += 1 if child is CPUParticles3D else 0
	assert_equal(falls, 2, "rain and snow, once")
