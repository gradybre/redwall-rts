extends SceneTree
## Native rendered-pixel proof of one common translation with deliberately non-unit skin weights.
## Synthetic geometry tests the backend equation, never a production actor/contact certificate.

const Actor := preload("res://demo/cast/underground_actor.gd")
const Suite := preload("res://test/test_underground_actor.gd")


func _initialize() -> void:
	"""Wait until the real rendering backend and SceneTree are ready."""
	call_deferred("_run")


func _run() -> void:
	"""Both body and held part must move the same measured pixels despite different skin weight sums."""
	if DisplayServer.get_name() == "headless":
		printerr("NATIVE_GROUNDING_BACKEND_REQUIRED")
		quit(2)
		return
	var suite: Suite = Suite.new()
	var scene: Dictionary = _fixture(suite)
	var first: Array[Vector3] = await _observe(scene, 0, suite)
	var second: Array[Vector3] = await _observe(scene, 1, suite)
	for part: int in 2:
		suite.assert_true(first[part].y > 100 and second[part].y > 100, "both actual visible parts")
		suite.assert_true(absf((first[part].x - second[part].x) - 32.0) < 1.5, "same common half-metre translation")
		print("native-grounding: part=", part, "; first=", first[part], "; second=", second[part])
	scene.actor.free()
	scene.viewport.free()
	for failure: String in suite.failures:
		printerr("FAIL: ", failure)
	print("native-grounding: %d assertions, %d failures; synthetic non-unit body and static attachment" %
		[suite.assertions, suite.failures.size()])
	quit(0 if suite.failures.is_empty() else 2)


func _fixture(suite: Suite) -> Dictionary:
	"""Two original native mesh parts share the immutable two-frame grounding palette."""
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
	var actor: Actor = Actor.new()
	viewport.add_child(actor)
	var palette: Actor.Palette = _palette(suite)
	var bounds: AABB = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	suite.assert_equal(actor.configure(palette, [_mesh(suite, true), _mesh(suite, false)],
		Suite.HASH, [bounds, bounds]), &"", "actual native configured")
	return {"actor": actor, "viewport": viewport}


func _mesh(suite: Suite, skinned: bool) -> ArrayMesh:
	"""Half-sum skin weights deliberately distinguish post-skin translation from bone-wise translation."""
	var arrays: Array = suite._surface()
	if skinned:
		arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5, 0, 0, 0])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.GREEN if skinned else Color.BLUE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


func _palette(suite: Suite) -> Actor.Palette:
	"""Bone matrices remain fixed; only the shared after-skin root differs between these two frames."""
	var values: PackedFloat32Array = PackedFloat32Array()
	for frame: int in 2:
		values.append_array(suite._matrix(Transform3D(Basis.IDENTITY, Vector3(-2, 0, 0))))
		values.append_array(suite._matrix(Transform3D(Basis.IDENTITY, Vector3(0.5, 0, 0))))
	var palette: Actor.Palette = Actor.Palette.new()
	suite.assert_equal(palette.configure(Suite.HASH, 2, PackedInt32Array([1, 0]), values,
		PackedFloat32Array([0, 0.5])), &"", "exact finite content")
	return palette


func _observe(scene: Dictionary, frame: int, suite: Suite) -> Array[Vector3]:
	"""Read actual pixels only after both native upload and rendering have progressed."""
	suite.assert_equal(scene.actor.apply_pose(PackedInt32Array([frame, frame, 0, frame, frame, 0, 0])), &"", "pose")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = scene.viewport.get_texture().get_image()
	return [_pixels(image, true), _pixels(image, false)]


static func _pixels(image: Image, green: bool) -> Vector3:
	"""Return vertical centroid, visible count and horizontal centroid for one exact fixture colour."""
	var x_total: int = 0
	var y_total: int = 0
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.9 and color.r < 0.2 and ((green and color.g > 0.7 and color.b < 0.2) \
					or (not green and color.b > 0.7 and color.g < 0.2)):
				x_total += x
				y_total += y
				count += 1
	return Vector3(float(y_total) / count if count else 0.0, float(count), float(x_total) / count if count else 0.0)
