extends "res://data/underground/evidence/matrix-presentation/world-basis/native_actor.gd"
## Decision1132. Actual Metal pixels and lifecycle; synthetic geometry grants no production profile permission.

const GL_SHA: String = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
const GL_PRODUCER: String = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"


func _run() -> void:
	"""Require the real default backend and exact streams before evaluating actual native skin/static pixels."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not _inputs_admitted(args):
		printerr("NATIVE_FORWARD_INPUT_OR_BACKEND")
		quit(2)
		return
	var suite: Suite = Suite.new()
	_legacy_refusal(suite, args[5])
	var table: Actor.WorldBasis = _load_actual_table(args)
	if table == null:
		quit(2)
		return
	suite.assert_true(table.matches_runtime(), "source matches actual Metal backend")
	var scene: Dictionary = _world_fixture(suite, table)
	await _world_observations(scene, suite, args[3])
	_refused_updates(scene, suite)
	await _reentry(scene, suite, table)
	scene.viewport.free()
	_write_native_report(suite, table, args)
	for failure: String in suite.failures:
		printerr("FAIL: ", failure)
	print("native-forward: %d assertions, %d failures; actual Metal pixels and two attachment cycles; qualified=0" %
		[suite.assertions, suite.failures.size()])
	quit(0 if suite.failures.is_empty() else 2)


static func _inputs_admitted(args: PackedStringArray) -> bool:
	"""Create-only outputs and actual native identity; command-line relabelling cannot impersonate Metal."""
	if args.size() != 6:
		return false
	if output_refusal(args[3], args[4]) != &"":
		return false
	var metadata: Dictionary = {"engine": Engine.get_version_info(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(),
		"api_version": RenderingServer.get_video_adapter_api_version()}
	return Actor.WorldBasis.backend_refusal(metadata) == &"" and metadata.rendering_driver == "metal"


static func output_refusal(binary: String, report: String) -> StringName:
	"""Use the accepted canonical-path/create-only guard before any native frame or report can overwrite a peer."""
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/bake_underground_world_basis.gd").simplify_path()
	var guard: GDScript = load(path) as GDScript
	if guard == null or FileAccess.get_sha256(path) != GL_PRODUCER:
		return &"NATIVE_FORWARD_OUTPUT_GUARD_SOURCE"
	return guard.output_refusal(binary, report, "res://data/underground/mole-worker/evidence/forward-plus-v1/native_forward_actor.gd")


func _legacy_refusal(suite: Suite, path: String) -> void:
	"""Release the old table before loading the new one; a valid GL stream cannot bind to actual Metal."""
	var old: Actor.WorldBasis = Actor.WorldBasis.new()
	suite.assert_equal(old.load_file(path, GL_SHA, GL_PRODUCER, Actor.WorldBasis.RESERVED_BYTES), &"", "old exact GL wire preserved")
	suite.assert_false(old.matches_runtime(), "matching coefficient bytes never authorize a foreign backend")
	var actor: Actor = Actor.new()
	root.add_child(actor)
	suite.assert_equal(actor.configure(_palette(suite), [_mesh(suite, true), _mesh(suite, false)], Suite.HASH,
		[AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6)), AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))]), &"", "native fixture")
	var domain: Actor.Space.Domain = suite._world_domain()
	suite.assert_equal(actor.bind_world_source(old, domain, domain.descriptor(), Suite.HASH, GL_SHA),
		&"UNDERGROUND_ACTOR_WORLD_SOURCE", "old source cannot relabel renderer")
	actor.free()


func _refused_updates(scene: Dictionary, suite: Suite) -> void:
	"""A refused world generation/heading or palette pose leaves both native parts at the last rendered state."""
	var actor: Actor = scene.actor
	var body: Transform3D = actor.native_matrix(0, 0)
	var held: Transform3D = actor.native_matrix(1, 0)
	suite.assert_equal(actor.set_world_root(Vector2i(5, 10), Vector3i(16384, -4608, 8192), 0),
		&"UNDERGROUND_ACTOR_WORLD_BINDING", "stale World refuses")
	suite.assert_equal(actor.set_world_root(Vector2i(5, 9), Vector3i(16384, -4608, 8192), 65536),
		&"UNDERGROUND_WORLD_BASIS_SELECTION", "unsupported heading refuses")
	suite.assert_true(actor.apply_pose(PackedInt32Array([0])) != &"", "incomplete pose refuses")
	suite.assert_equal(actor.native_matrix(0, 0), body, "native skin upload unchanged")
	suite.assert_equal(actor.native_matrix(1, 0), held, "native static transform unchanged")


func _reentry(scene: Dictionary, suite: Suite, table: Actor.WorldBasis) -> void:
	"""Exit frees old attachments; actual re-entry plus reconfiguration must visibly deform again."""
	var actor: Actor = scene.actor
	var parent: Node3D = actor.get_parent() as Node3D
	parent.remove_child(actor)
	suite.assert_equal(actor.get_child_count(), 0, "exit retired every native mesh part")
	suite.assert_equal(actor.apply_pose(PackedInt32Array()), &"UNDERGROUND_ACTOR_UNBOUND", "no orphan palette after exit")
	parent.add_child(actor)
	var bounds: AABB = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	suite.assert_equal(actor.configure(_palette(suite), [_mesh(suite, true), _mesh(suite, false)],
		Suite.HASH, [bounds, bounds]), &"", "new attachment after actual ENTER_TREE")
	var domain: Actor.Space.Domain = suite._world_domain()
	suite.assert_equal(actor.bind_world_source(table, domain, domain.descriptor(), Suite.HASH, table.source_digest()), &"", "same immutable table")
	var observed: Array[Vector3] = await _world_observe(scene, suite, Vector3i(16384, -4608, 8192), 0, 0)
	suite.assert_true(observed[0].y > 100 and observed[0].z < 120, "re-entered body visibly uses translated native skin")
	suite.assert_true(observed[1].y > 100 and observed[1].z > 150, "held mesh still uses its own source transform")
	print("native-forward-reentry: body=", observed[0], "; held=", observed[1])


func _write_native_report(suite: Suite, table: Actor.WorldBasis, args: PackedStringArray) -> void:
	"""Record the actual renderer and exact observed source, without assigning physical or arithmetic permission."""
	var report: Dictionary = {"scope": "synthetic native Metal WorldBasis binding and attachment lifecycle",
		"assertions": suite.assertions, "failures": suite.failures, "basis_sha256": table.source_digest(),
		"producer_sha256": table.producer_digest(), "image_sha256": FileAccess.get_sha256(args[3]),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(),
		"api_version": RenderingServer.get_video_adapter_api_version(), "engine": Engine.get_version_info(),
		"reserved_bytes": Actor.WorldBasis.RESERVED_BYTES, "attachment_cycles": 2,
		"qualified_profiles": 0, "complete_numerical_enclosure": false, "world_qualified": false}
	var file: FileAccess = FileAccess.open(args[4], FileAccess.WRITE)
	suite.assert_true(file != null, "new native report opened")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		suite.assert_equal(file.get_error(), OK, "native report complete")
		file.close()
