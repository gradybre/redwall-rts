extends "res://test/framework/test_case.gd"
## The world's ground and water colours answer to world-domain targets, not the UI pigment lock
## (demo/world/world_look.gd WORLD MATERIAL TARGETS, decision 0301, review F51; DEC-038 and
## docs/art-reference/visual_direction_alignment.md). No staged assets.

const Look := preload("res://demo/world/world_look.gd")
const WaterSurfaceScript := preload("res://demo/water/water_surface.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterGridScript := preload("res://demo/water/water_grid.gd")

## Files whose 3D colours this contract covers.
const WORLD_SOURCES: Array[String] = [
	"res://demo/world/world_look.gd", "res://demo/water/water_surface.gd", "res://demo/water/demo_water.gd",
]
## Words that would bind a 3D material to the UI lock again.
const UI_LOCK_CLAIMS: Array[String] = ["ART-LOCK-001 pigments", "locked pigment", "locked ART-LOCK", "asset_generation_lock.json"]

var _nodes: Array[Object] = []


func after_each() -> void:
	"""Free every node a test made."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _assert_params(material: ShaderMaterial, targets: Dictionary, what: String) -> void:
	"""Every target is the material's parameter of that name, exactly."""
	for key: StringName in targets:
		var value: Variant = material.get_shader_parameter(key)
		assert_true(value is Color and (value as Color).is_equal_approx(targets[key]), "%s: %s is its target" % [what, key])


func test_the_ground_wears_its_world_targets() -> void:
	"""make_ground: each ground colour is world_look.gd's ground target of the same name."""
	var ground: MeshInstance3D = Look.make_ground()
	_nodes.append(ground)
	_assert_params((ground.mesh as PrimitiveMesh).material as ShaderMaterial, Look.ground_targets(), "ground")


func test_the_water_and_the_bank_wear_their_world_targets() -> void:
	"""The water surface's and the bank film's colours are world_look.gd's water and bank targets."""
	var map := WaterLayout.make_map()
	var grid := WaterGridScript.new()
	grid.build(map, 60.0)
	var surface := WaterSurfaceScript.new()
	surface.build(grid, map, WaterSurfaceScript.DEFAULT_SKY)
	for node: MeshInstance3D in surface.nodes:
		_nodes.append(node)
	for material: ShaderMaterial in surface.materials:
		_assert_params(material, Look.water_targets(), "water")
	var water := DemoWaterScript.new()
	_nodes.append(water)
	_assert_params(water._bank_material(), Look.bank_targets(), "bank")


func test_every_target_sits_in_its_value_group() -> void:
	"""DEC-038's deliberate value grouping: each target inside its declared group (VALUE_GROUPS), every
	target declared, and the worn path clearly lighter than the grass (PATH_OVER_GRASS)."""
	var all: Dictionary = {}
	for targets: Dictionary in [Look.ground_targets(), Look.bank_targets(), Look.water_targets()]:
		all.merge(targets)
	for key: StringName in all:
		assert_true(Look.VALUE_GROUPS.has(key), "%s has a value group" % key)
		var group: Vector2 = Look.value_group_of(key)
		var value: float = Look.value_of(all[key])
		assert_true(value >= group.x and value <= group.y, "%s value %.3f in %s" % [key, value, group])
	var path: float = Look.value_of(all[&"path_color"])
	for grass: StringName in [&"grass_color", &"grass_sun_color"]:
		assert_true(path >= Look.value_of(all[grass]) * Look.PATH_OVER_GRASS, "the path reads over %s" % grass)
	assert_true(Look.value_of(all[&"deep_color"]) < Look.value_of(all[&"shallow_color"]), "deep water darker than the shallows")


func test_value_is_linear_luminance() -> void:
	"""value_of: black 0, white 1, and a mid sRGB grey about 0.214 (linear light)."""
	assert_almost_equal(Look.value_of(Color.BLACK), 0.0, "black")
	assert_almost_equal(Look.value_of(Color.WHITE), 1.0, "white")
	assert_true(absf(Look.value_of(Color(0.5, 0.5, 0.5)) - 0.214) < 0.002, "sRGB 0.5 grey")


func test_no_world_material_claims_the_ui_lock() -> void:
	"""The UI lock does not govern the world (visual_direction_alignment.md): none of the ground and water
	sources binds its colours to it any more."""
	for path: String in WORLD_SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(text.length() > 0, "%s read" % path)
		for claim: String in UI_LOCK_CLAIMS:
			assert_false(text.contains(claim), "%s does not claim '%s'" % [path, claim])
	assert_true(FileAccess.get_file_as_string(WORLD_SOURCES[0]).contains("DEC-038"), "world_look.gd names its authority")
