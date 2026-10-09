extends SceneTree
## Native D11 presentation witness using actual source/Room owners and explicitly synthetic fixture geometry.
## No production asset, playable entrance, work execution or whole-client performance qualification.

const Tests := preload("res://test/test_modular_access.gd")
const Fixture := preload("res://test/test_underground_room_approach.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
var _test: Tests = null
var _scene: Node3D = null
var _canvas: CanvasLayer = null
var _out: String = ""
var _images: Array[String] = []
var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	"""Use the actual project renderer and a finite deferred native sequence."""
	call_deferred(&"_run")


func _run() -> void:
	"""Three exact states retain the same drawing/marker and show an explicit invalid requested replacement."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	_out = args[0]
	root.size = Vector2i(1280, 720)
	_test = Tests.new()
	_test._ui()
	_check(_test.failures.is_empty(), "real fixture: %s" % _test.failures)
	_build_scene()
	await _save("ready.png")
	var cells: PackedInt32Array = _test._editor.draft.visible_cells()
	var target: Vector3i = _test._runtime._access.preview().target
	_test._editor._pick_access()
	_check(_test._editor.selecting_access(), "explicit reposition mode")
	await _save("choose-boundary.png")
	_test._editor.place_access_at(Vector2i.ONE)
	_test._finish(_test._runtime._access)
	_test._editor._sync_access()
	_check(_test._editor._confirm.disabled, "invalid boundary visibly refuses")
	_check(_test._editor.draft.visible_cells() == cells, "drawing retained")
	_check(_test._runtime._access.preview().target == target, "original marker retained")
	await _save("invalid-boundary.png")
	await _finish()


func _build_scene() -> void:
	"""Simple labelled dirt/clearance fixture shows the actual view adapter, not a proposed world-art replacement."""
	_scene = Node3D.new()
	root.add_child(_scene)
	_scene.add_child(_test._camera)
	_scene.add_child(_test._tool)
	var focus: Vector3 = Vector3(Fixture.X + 2304, Fixture.FLOOR, Fixture.Z + 1024) / 1024.0
	_test._camera.position = focus + Vector3(6.0, 7.0, 8.0)
	_test._camera.look_at(focus)
	_test._camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_test._camera.size = 8.5
	_test._camera.current = true
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(14.0, 14.0)
	ground.mesh = plane
	ground.position = focus - Vector3(1.5, 0.005, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("705843")
	ground.material_override = material
	_scene.add_child(ground)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -20, 0)
	_scene.add_child(light)
	_build_inspector()


func _build_inspector() -> void:
	"""The actual editor controls retain established Woodland palette tokens at1280x720."""
	_canvas = CanvasLayer.new()
	root.add_child(_canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(938, 20)
	panel.size = Vector2(322, 675)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.OAT
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override(&"panel", style)
	_canvas.add_child(panel)
	panel.add_child(_test._editor)
	var caption: Label = Label.new()
	caption.text = "Room access · actual adapter\nSynthetic physical/source fixture · no work ordered"
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override(&"font_size", 20)
	caption.add_theme_color_override(&"font_color", Palette.CREAM)
	_canvas.add_child(caption)
	_test._editor.refresh_site()


func _save(name: String) -> void:
	"""Capture a rendered frame and verify the saved bytes instead of counting a scheduled screenshot."""
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var picture: Image = root.get_texture().get_image()
	_check(picture != null and picture.get_size() == Vector2i(1280, 720), "actual1280x720 frame")
	var path: String = _out.path_join(name)
	_check(not FileAccess.file_exists(path), "create-only image")
	_check(picture.save_png(path) == OK and FileAccess.file_exists(path), "actual PNG saved")
	_images.append(name)


func _check(value: bool, label: String) -> void:
	"""Explicit finite native assertions never imply production source or world qualification."""
	_assertions += 1
	if not value: _failures.append(label)


func _finish() -> void:
	"""Release the actual view callbacks/fixtures before recording native exit and raw leak evidence."""
	_test.after_each()
	_check(_test.failures.is_empty(), "actual owner/view teardown")
	_test = null
	_scene.queue_free()
	_canvas.queue_free()
	await process_frame
	var report: Dictionary = {"scope": "actual room-access view with synthetic source/physical fixture",
		"qualified": false, "assertions": _assertions, "failures": _failures, "images": _images,
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name()}
	var file: FileAccess = FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	quit(0 if _failures.is_empty() else 1)
