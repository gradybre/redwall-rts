extends "res://test/framework/test_case.gd"
## The Windows demo build's project settings and its full-screen key. Decision 0196. Needs no staged
## assets and no export: it reads the feature overrides the way the engine does, for a process that
## has the `demo_build` feature and for one that does not.

const WindowKeysScript := preload("res://demo/demo_window_keys.gd")

const DEMO_SCENE: String = "res://demo/demo_village.tscn"
const GAME_SCENE: String = "res://scenes/main.tscn"
const DEMO_FEATURES: Array[String] = ["windows", "pc", "x86_64", "template", "release", "demo_build"]
const PLAIN_FEATURES: Array[String] = ["windows", "pc", "x86_64", "template", "release"]


func _with(features: Array[String], setting: String) -> Variant:
	"""`setting` as a process with `features` reads it."""
	return ProjectSettings.get_setting_with_override_and_custom_features(setting, PackedStringArray(features))


func test_without_the_feature_the_game_still_opens_its_own_scene() -> void:
	"""The editor, the test suite and any other export are untouched by the demo build."""
	assert_equal(_with(PLAIN_FEATURES, "application/run/main_scene"), GAME_SCENE, "plain main scene")
	assert_equal(ProjectSettings.get_setting("application/run/main_scene"), GAME_SCENE, "the base value")
	assert_equal(_with(PLAIN_FEATURES, "display/window/size/mode"), DisplayServer.WINDOW_MODE_WINDOWED, "windowed")
	assert_equal(_with(PLAIN_FEATURES, "application/config/name"), "Redwall RTS", "the game's name")
	assert_false(OS.has_feature("demo_build"), "this process is not the demo build")


func test_the_demo_build_boots_the_demo_maximized() -> void:
	"""The feature the export preset sets sends the build straight into the village."""
	assert_equal(_with(DEMO_FEATURES, "application/run/main_scene"), DEMO_SCENE, "demo main scene")
	assert_true(ResourceLoader.exists(DEMO_SCENE), "the demo scene exists")
	assert_equal(_with(DEMO_FEATURES, "display/window/size/mode"), DisplayServer.WINDOW_MODE_MAXIMIZED, "maximized")
	assert_equal(_with(DEMO_FEATURES, "application/config/name"), "Redwall Demo", "titled Redwall Demo")


func test_the_desktop_vram_format_is_imported() -> void:
	"""The staged 3D textures are compressed to S3TC; an export without it would ship none of them."""
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_s3tc_bptc"), "S3TC/BPTC on")


func test_f11_toggles_full_screen_and_back() -> void:
	"""Windowed or maximized goes full screen; either full-screen mode comes back maximized."""
	assert_equal(WindowKeysScript.next_mode(DisplayServer.WINDOW_MODE_MAXIMIZED), DisplayServer.WINDOW_MODE_FULLSCREEN, "maximized")
	assert_equal(WindowKeysScript.next_mode(DisplayServer.WINDOW_MODE_WINDOWED), DisplayServer.WINDOW_MODE_FULLSCREEN, "windowed")
	assert_equal(WindowKeysScript.next_mode(DisplayServer.WINDOW_MODE_FULLSCREEN), DisplayServer.WINDOW_MODE_MAXIMIZED, "full")
	assert_equal(WindowKeysScript.next_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN), DisplayServer.WINDOW_MODE_MAXIMIZED,
		"exclusive")


func test_f11_is_bound_to_nothing_else() -> void:
	"""The key is free in the project's input map, so taking it hides no game action (Alt+Enter is not:
	it is brush_erase)."""
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				assert_false(key.keycode == WindowKeysScript.FULLSCREEN_KEY or key.physical_keycode == WindowKeysScript.FULLSCREEN_KEY,
					"%s does not use F11" % action)


func test_a_picture_the_demo_reads_itself_is_found_in_a_project_and_in_a_pack() -> void:
	"""Beside its .import (the project) the file is read from the project folder, which draws no
	"will not work on export" warning; with no .import (an exported pack) by its res:// path."""
	var DemoManifestScript: GDScript = load("res://demo/demo_manifest.gd")
	var imported: String = DemoManifestScript.readable_path("res://icon.svg")
	assert_equal(imported, ProjectSettings.globalize_path("res://icon.svg"), "project: the folder's file")
	assert_false(imported.begins_with("res://"), "not the res:// path")
	assert_equal(DemoManifestScript.readable_path("res://demo/assets/icons/none.png"), "res://demo/assets/icons/none.png",
		"pack: the res:// path")
