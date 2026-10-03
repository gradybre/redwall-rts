extends SceneTree
## Native-only lifecycle smoke check; synthetic dimensions do not qualify any game profile.

const Suite := preload("res://test/test_underground_actor.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")


func _initialize() -> void:
	"""The actual backend must exist before the out-of-tree native RID lifecycle tests run."""
	call_deferred("_run")


func _run() -> void:
	"""Run the exact in-repository test source in a real renderer, then release every fixture."""
	if DisplayServer.get_name() == "headless":
		printerr("NATIVE_BACKEND_REQUIRED")
		quit(2)
		return
	var suite: Suite = Suite.new()
	var count: int = 0
	for method: Dictionary in suite.get_method_list():
		if str(method.name).begins_with("test_"):
			suite.before_each()
			suite.call(method.name)
			suite.after_each()
			count += 1
	for failure: String in suite.failures:
		printerr("FAIL: ", failure)
	print("native-adapter: %d tests, %d assertions, %d failures; backend=%s/%s; synthetic" %
		[count, suite.assertions, suite.failures.size(), DisplayServer.get_name(), RenderingServer.get_current_rendering_driver_name()])
	await _render_lifecycle(suite)
	print("native-attachment: rendered entry/re-entry checks; %d total assertions, %d failures" %
		[suite.assertions, suite.failures.size()])
	quit(0 if suite.failures.is_empty() else 2)


func _render_lifecycle(suite: Suite) -> void:
	"""Observe displaced pixels, not merely the contents of a skeleton RID that might be detached."""
	var viewport: SubViewport = _viewport()
	var actor: Actor = Actor.new()
	var mesh: ArrayMesh = suite._mesh(true)
	var material: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 1, 0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var palette: Actor.Palette = suite._palette([Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0))])
	for cycle: int in 2:
		viewport.add_child(actor)
		suite.assert_equal(actor.configure(palette, [mesh], Suite.HASH,
			[AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))]), &"", "configured after actual entry")
		suite.assert_equal(actor.apply_pose(PackedInt32Array([0, 0, 0, 0, 0, 0, 0])), &"", "upload")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var centroid: Vector2 = _green_pixels(viewport.get_texture().get_image())
		suite.assert_true(centroid.y > 100, "native triangle is visible")
		suite.assert_true(centroid.x < 100.0, "actual rendered triangle uses translated skin, not rest mesh")
		print("native-attachment: cycle=", cycle, "; green_pixels=", centroid.y, "; centroid_x=", centroid.x)
		viewport.remove_child(actor)
		suite.assert_equal(actor.apply_pose(PackedInt32Array()), &"UNDERGROUND_ACTOR_UNBOUND", "exit retired palette")
	actor.free()
	viewport.free()


func _viewport() -> SubViewport:
	"""A private native viewport has no dependence on the application's other scenes or camera."""
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0, 0, 3)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	return viewport


static func _green_pixels(image: Image) -> Vector2:
	"""Only opaque green fixture pixels count; a blank buffer or undeformed origin triangle fails."""
	var sum_x: int = 0
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var value: Color = image.get_pixel(x, y)
			if value.g > 0.7 and value.r < 0.2 and value.b < 0.2 and value.a > 0.9:
				sum_x += x
				count += 1
	return Vector2(float(sum_x) / count if count else 0.0, float(count))
