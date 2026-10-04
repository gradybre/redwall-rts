extends "../native_grounding_check.gd"
## Actual desktop GL pixels exercise the complete native source table and explicit world equation.
## Synthetic meshes test backend semantics; no production state or movement permission is implied.


func _run() -> void:
	"""Use the actual finite table, an exact finite Domain and original native body/static mesh paths."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() != 4 or FileAccess.file_exists(args[3]):
		printerr("NATIVE_WORLD_INPUT_OR_OUTPUT")
		quit(2)
		return
	var table: Actor.WorldBasis = _load_actual_table(args)
	if table == null:
		quit(2)
		return
	var suite: Suite = Suite.new()
	var scene: Dictionary = _world_fixture(suite, table)
	await _world_observations(scene, suite, args[3])
	scene.viewport.free()
	for failure: String in suite.failures:
		printerr("FAIL: ", failure)
	print("native-world: %d assertions, %d failures; actual complete source, synthetic meshes; qualified=0" %
		[suite.assertions, suite.failures.size()])
	quit(0 if suite.failures.is_empty() else 2)


func _load_actual_table(args: PackedStringArray) -> Actor.WorldBasis:
	"""Report actual allocator observations; global prior peaks are not isolated loading qualification."""
	var table: Actor.WorldBasis = Actor.WorldBasis.new()
	var before: int = OS.get_static_memory_usage()
	var peak_before: int = OS.get_static_memory_peak_usage()
	var code: StringName = table.load_file(args[0], args[1], args[2], Actor.WorldBasis.RESERVED_BYTES)
	print("native-world-memory: live_before=", before, "; live_after=", OS.get_static_memory_usage(),
		"; peak_before=", peak_before, "; peak_after=", OS.get_static_memory_peak_usage(),
		"; reserved=", Actor.WorldBasis.RESERVED_BYTES, "; isolated_peak_qualified=false")
	if code != &"":
		printerr(code)
		return null
	return table


func _world_fixture(suite: Suite, table: Actor.WorldBasis) -> Dictionary:
	"""The parent deliberately has extreme translation, nonuniform scale and non-Y rotation."""
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
	camera.position = Vector3(16, -4.5, 11)
	camera.look_at(Vector3(16, -4.5, 8), Vector3.UP)
	camera.current = true
	var parent: Node3D = Node3D.new()
	viewport.add_child(parent)
	parent.transform = Transform3D(Basis(Vector3.RIGHT, 0.7).scaled(Vector3(2, 3, 4)), Vector3(1900, -1000, 800))
	var actor: Actor = Actor.new()
	parent.add_child(actor)
	var bounds: AABB = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	suite.assert_equal(actor.configure(_palette(suite), [_mesh(suite, true), _mesh(suite, false)],
		Suite.HASH, [bounds, bounds]), &"", "original native part configuration")
	var domain: Actor.Space.Domain = suite._world_domain()
	suite.assert_equal(actor.bind_world_source(table, domain, domain.descriptor(), Suite.HASH, table.source_digest()),
		&"", "actual complete source, backend and Domain")
	actor.transform = Transform3D(Basis(Vector3.BACK, 1.1), Vector3(17, 19, 23))
	return {"actor": actor, "viewport": viewport}


func _world_observations(scene: Dictionary, suite: Suite, output: String) -> void:
	"""Mirror and translation must affect the actual visible skin and held mesh identically."""
	var sheet: Image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	var first: Array[Vector3] = await _world_observe(scene, suite, Vector3i(16384, -4608, 8192), 0, 0)
	sheet.blit_rect(scene.viewport.get_texture().get_image(), Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	var turned: Array[Vector3] = await _world_observe(scene, suite, Vector3i(16384, -4608, 8192), 32768, 0)
	sheet.blit_rect(scene.viewport.get_texture().get_image(), Rect2i(0, 0, 256, 256), Vector2i(256, 0))
	var grounded: Array[Vector3] = await _world_observe(scene, suite, Vector3i(16384, -4608, 8192), 0, 1)
	sheet.blit_rect(scene.viewport.get_texture().get_image(), Rect2i(0, 0, 256, 256), Vector2i(512, 0))
	var shifted: Array[Vector3] = await _world_observe(scene, suite, Vector3i(16896, -4608, 8192), 0, 0)
	sheet.blit_rect(scene.viewport.get_texture().get_image(), Rect2i(0, 0, 256, 256), Vector2i(768, 0))
	for part: int in 2:
		suite.assert_true(first[part].y > 100 and turned[part].y > 100 and grounded[part].y > 100 and shifted[part].y > 100,
			"actual skin and item remain visible, independent of extreme parents")
		suite.assert_true(absf(first[part].z + turned[part].z - 255.0) < 1.5, "full native heading mirror")
		suite.assert_true(absf(first[part].x - grounded[part].x - 32.0) < 1.5, "same half-metre grounding")
		suite.assert_true(absf(shifted[part].z - first[part].z - 32.0) < 1.5, "same exact integer world root")
		print("native-world: part=", part, "; initial=", first[part], "; turned=", turned[part],
			"; grounded=", grounded[part], "; shifted=", shifted[part])
	suite.assert_equal(sheet.save_png(output), OK, "create native comparison witness")


func _world_observe(scene: Dictionary, suite: Suite, root_u: Vector3i, yaw: int, frame: int) -> Array[Vector3]:
	"""Both source and root updates precede actual rendered frame observation."""
	suite.assert_equal(scene.actor.set_world_root(Vector2i(5, 9), root_u, yaw), &"", "exact world-root update")
	return await _observe(scene, frame, suite)
