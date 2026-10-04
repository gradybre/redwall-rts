extends "../../grip-authoring/native_grip_sequence.gd"
## Exact five-program source witness. Visible timber/bearings are unpaid fixtures, never live support.

var _shared_basis: Actor.WorldBasis = Actor.WorldBasis.new()
var _domain: Actor.Space.Domain = Actor.Space.Domain.new()
var _borrowed: Dictionary = {}
var _loaded_sha: String = ""
var _palette: Actor.Palette = null
var _sample: PackedFloat32Array = PackedFloat32Array()
var _coefficients: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _instances: Array[MeshInstance3D] = []
var _events: Array[Dictionary] = []
var _joins: Array[Dictionary] = []
var _previous_endpoint: Dictionary = {}
var _bone_checks: int = 0
var _world_checks: int = 0
var _fixture_count: int = 0


func _bind_actor(meshes: Dictionary) -> void:
	"""One shared finite table and immutable borrowed mesh set serve sequential source images."""
	_borrowed = meshes
	_suite.assert_equal(_shared_basis.load_file(_spec.basis, _spec.basis_sha256,
		_spec.basis_producer_sha256, Actor.WorldBasis.RESERVED_BYTES), &"", "exact shared native basis")
	_suite.assert_equal(_domain.configure(Vector2i(5, 9), Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Actor.Space.MAX_CHECKS), &"", "synthetic identity, exact finite domain")
	_loaded_sha = _spec.content_sha256
	_bind_current_content()


func _bind_current_content() -> void:
	"""Configure only an in-tree Actor; cache actual mesh instances for native world-transform observation."""
	_actor = Actor.new()
	_world.add_child(_actor)
	_suite.assert_equal(_content.mesh_binding_refusal(_borrowed.meshes), &"", "same complete original/derived geometry")
	_suite.assert_equal(_content.configure_actor(_actor, _borrowed.meshes, _borrowed.materials), &"", "actual mesh/material binding")
	_suite.assert_true(_content.domain_matches(_domain.descriptor().bounds_u), "complete numerical domain")
	_suite.assert_equal(_actor.bind_world_source(_shared_basis, _domain, _domain.descriptor(),
		_content.source_digest(), _shared_basis.source_digest()), &"", "same content and backend")
	_palette = _content.get("_palette") as Actor.Palette
	_suite.assert_true(_palette != null, "actual loaded palette observation")
	if _palette == null:
		return
	_sample.resize(_palette.scratch_count())
	_instances.clear()
	for child: Node in _actor.get_children():
		if child is MeshInstance3D:
			_instances.append(child as MeshInstance3D)
	_suite.assert_equal(_instances.size(), 2, "whole body plus held pick")
	_suite.assert_equal(_palette.bind_count(0), 24, "actual mole bind census")
	_suite.assert_equal(_palette.bind_count(1), 0, "actual static held-tool part")


func _activate_program(program: Dictionary) -> void:
	"""Retire the old Actor and palette before decoding another image; no hidden third palette copy."""
	if _loaded_sha != program.content_sha256:
		_instances.clear()
		_actor.free()
		_actor = null
		_palette = null
		_content = null
		_content = Content.new()
		_suite.assert_equal(_content.load_file(program.content, program.content_sha256, program.reserve_bytes),
			&"", "sequential exact image load")
		_loaded_sha = program.content_sha256
		_bind_current_content()
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	_suite.assert_true(_content.clip_timing_into(int(program.clip), timing), "actual finite source timing")
	_suite.assert_equal(timing, PackedInt32Array([int(program.intervals) * 65536, 0]), "nonlooping exact terminal")


func _build_stage() -> void:
	"""All twenty-two exact positive fixture prisms remain visible; none creates gameplay collision or support."""
	super._build_stage()
	root.size = Vector2i(1280, 720)
	for index: int in _spec.solids_u.size():
		_add_fixture_part(_spec.solids_u[index], index)
	_suite.assert_equal(_fixture_count, 22, "fourteen timber parts plus eight natural bearings")


func _add_fixture_part(row: Array, index: int) -> void:
	"""Use complete integer bounds, including deck thickness, bearers, posts and all base prisms."""
	var low: Vector3i = Vector3i(int(row[0]), int(row[1]), int(row[2]))
	var high: Vector3i = Vector3i(int(row[3]), int(row[4]), int(row[5]))
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(high - low) / 1024.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("795535") if index < 14 else Color("574c3a")
	material.roughness = 1.0
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.name = "FixturePart%d" % index
	instance.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(low + high) / 2048.0
	_world.add_child(instance)
	_fixture_count += 1


func _observe_clips() -> void:
	"""Both travel directions, stationary-root phases and every join are replayed in each of three views."""
	_suite.assert_equal(str(RenderingServer.get_current_rendering_method()), "gl_compatibility", "actual GL witness only")
	_suite.assert_true(OS.get_user_data_dir().ends_with("/" + str(_spec.user_directory_name)), "isolated user directory")
	for view: String in ["side", "opposite", "rts"]:
		_previous_endpoint.clear()
		for program: Dictionary in _spec.programs:
			_activate_program(program)
			if not _suite.failures.is_empty():
				return
			_set_view(view, program)
			await _observe_program(view, program)
			if not _suite.failures.is_empty():
				return


func _set_view(view: String, program: Dictionary) -> void:
	"""Fixed cameras per program expose root travel; RTS is a diagnostic view without gameplay HUD."""
	var start: Array = program.entry_root_u
	var end: Array = program.exit_root_u
	var focus: Vector3 = Vector3(ORIGIN_U) / 1024.0
	focus += Vector3(float(start[0] + end[0]), float(start[1] + end[1]), float(start[2] + end[2])) / 2048.0
	focus.y += 0.30
	var offset: Vector3 = Vector3(2.2, 0.55, 0.35) if view == "side" else Vector3(-2.2, 0.6, -0.25)
	if view == "rts":
		offset = Vector3(3.9, 5.0, 4.0)
	_camera.size = 10.0 if view == "rts" else 3.0
	_camera.position = focus + offset
	_camera.look_at(focus, Vector3.UP)


func _save_frame(label: String, clip: int, tick: int) -> void:
	"""Force this exact selected main-thread pose to draw; automatic occlusion/redraw scheduling supplies no source phase."""
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_texture().get_image()
	var path: String = _out + "/" + label + ".png"
	_suite.assert_false(FileAccess.file_exists(path), "create-only native frame")
	_suite.assert_equal(image.save_png(path), OK, "actual rendered witness")
	var digest: String = FileAccess.get_sha256(path)
	_shots.append({"path": label + ".png", "clip": clip, "half_tick": tick, "sha256": digest})


func _observe_program(view: String, program: Dictionary) -> void:
	"""Sampling is exactly half a source interval; elapsed render time supplies no gameplay rate."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	var shot_ticks: PackedInt32Array = PackedInt32Array(program.shot_ticks)
	var terminal: int = int(program.intervals) * 2
	for tick: int in terminal + 1:
		var state: PackedInt32Array = _phase_state(program, tick * 32768)
		var root_u: Vector3i = ORIGIN_U + Vector3i(state[0], state[1], state[2])
		_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), root_u, state[3]), &"", "exact fixed root and moving heading")
		_suite.assert_equal(_content.clip_into(int(program.clip), tick * 32768, now), &"", "same source phase")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native full-body and tool pose")
		_observe_native(pose, root_u, state[3])
		_record_event(view, program, tick, state, now, terminal)
		_observed += 1
		await process_frame
		if shot_ticks.has(tick):
			_save_frame("%s-%s-%03d" % [view, program.name, tick], int(program.clip), tick)
			await process_frame
	print("native-handoffs-program: ", view, "/", program.name, "; total_poses=", _observed)


func _phase_state(program: Dictionary, time_q16: int) -> PackedInt32Array:
	"""New roots are fixed-frame; old local roots are ceiled before their exact orientation and translation."""
	var count: int = int(program.intervals)
	@warning_ignore("integer_division") var first: int = mini(time_q16 / 65536, count)
	var last: int = mini(first + 1, count)
	var share: int = time_q16 % 65536 if first < count else 0
	var value: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for axis: int in 4:
		value[axis] = _ceil_ratio(int(program.keys[first][axis]) * (65536 - share)
			+ int(program.keys[last][axis]) * share, 65536)
	if program.root_frame == "local_then_fixed_quarter_turn":
		var point: Vector3i = _quarter_turn(Vector3i(value[0], value[1], value[2]), int(program.quarter_turn))
		for axis: int in 3:
			value[axis] = point[axis] + int(program.origin_u[axis])
	return value


func _quarter_turn(point: Vector3i, turns: int) -> Vector3i:
	"""The old source fixture transform is exact integer rotation; heading never rotates the fixed world root."""
	match turns:
		0: return point
		1: return Vector3i(point.z, point.y, -point.x)
		2: return Vector3i(-point.x, point.y, -point.z)
		3: return Vector3i(-point.z, point.y, point.x)
	return Vector3i.ZERO


func _ceil_ratio(numerator: int, denominator: int) -> int:
	"""Bounded signed integer source coordinates remain exact at every selected half interval."""
	@warning_ignore("integer_division") var value: int = (numerator + denominator - 1) / denominator if numerator >= 0 else -(-numerator / denominator)
	return value


func _observe_native(pose: PackedInt32Array, root_u: Vector3i, yaw: int) -> void:
	"""Check the actual skeleton buffers and actual instance world transforms against independent scalar assembly."""
	_suite.assert_equal(_palette.sample_into(pose, _sample), &"", "actual immutable local sample")
	_suite.assert_equal(_shared_basis.coefficients_into(yaw, _coefficients), &"", "same actual finite heading")
	for bind: int in _palette.bind_count(0):
		_suite.assert_equal(_matrix_bytes(_actor.native_matrix(0, bind)),
			_matrix_bytes(_local_matrix(bind * 12)), "native skeleton full float32 matrix")
		_bone_checks += 1
	for part: int in 2:
		var local: Transform3D = Transform3D.IDENTITY if part == 0 else _local_matrix(_palette.part_offset(part))
		var expected: Transform3D = _expected_world(local, _sample[-1], root_u)
		_suite.assert_equal(_matrix_bytes(_instances[part].global_transform), _matrix_bytes(expected), "native world body/tool equation")
		_suite.assert_true(_instances[part].visible and _instances[part].is_inside_tree(), "actual visible attached instance")
		_world_checks += 1


func _local_matrix(at: int) -> Transform3D:
	"""Rebuild the original column-major float32 values without calling Actor.matrix_at."""
	return Transform3D(Basis(Vector3(_sample[at], _sample[at + 1], _sample[at + 2]),
		Vector3(_sample[at + 3], _sample[at + 4], _sample[at + 5]),
		Vector3(_sample[at + 6], _sample[at + 7], _sample[at + 8])),
		Vector3(_sample[at + 9], _sample[at + 10], _sample[at + 11]))


func _expected_world(local: Transform3D, grounding: float, root_u: Vector3i) -> Transform3D:
	"""Independent scalar oracle: the fixed root is added once after the moving body basis."""
	var c: float = _coefficients[0]
	var s: float = _coefficients[1]
	var result: Transform3D = Transform3D.IDENTITY
	for axis: int in 3:
		var column: Vector3 = local.basis[axis]
		result.basis[axis] = Vector3(c * float(column.x) + s * float(column.z), column.y,
			-s * float(column.x) + c * float(column.z))
	result.origin = Vector3(c * float(local.origin.x) + s * float(local.origin.z) + float(root_u.x) / 1024.0,
		float(local.origin.y) + grounding + float(root_u.y) / 1024.0,
		-s * float(local.origin.x) + c * float(local.origin.z) + float(root_u.z) / 1024.0)
	return result


func _matrix_bytes(value: Transform3D) -> PackedByteArray:
	"""Byte comparison retains signed zero and every native float32 component instead of an approximate test."""
	var result: PackedFloat32Array = PackedFloat32Array()
	for axis: int in 3:
		for row: int in 3:
			result.append(value.basis[axis][row])
	for axis: int in 3:
		result.append(value.origin[axis])
	return result.to_byte_array()


func _record_event(view: String, program: Dictionary, tick: int, state: PackedInt32Array,
		now: PackedInt32Array, terminal: int) -> void:
	"""Retain exact emitted phase/root/frame tuples and byte-identical local endpoint joins across image replacement."""
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(_sample.to_byte_array())
	var pose_sha: String = hash_context.finish().hex_encode()
	var event: Dictionary = {"view": view, "program": program.name, "half_tick": tick,
		"root_u": [state[0], state[1], state[2]], "yaw": state[3], "frames": Array(now), "palette_sha256": pose_sha}
	_events.append(event)
	if tick == 0 or tick == terminal:
		_suite.assert_equal(pose_sha, str(program.endpoint_pose_sha256), "exact original ready pose at join")
	if tick == 0 and not _previous_endpoint.is_empty():
		for field: String in ["root_u", "yaw", "palette_sha256"]:
			_suite.assert_equal(event[field], _previous_endpoint[field], "complete native endpoint join")
		_joins.append({"view": view, "from": _previous_endpoint.program, "to": program.name,
			"root_u": event.root_u, "yaw": event.yaw, "palette_sha256": pose_sha})
	if tick == terminal:
		_previous_endpoint = event.duplicate(true)


func _observe_transitions() -> void:
	"""All visible transitions are exact source joins; no ground turn, paid support or gameplay rate is inferred."""
	_suite.assert_equal(_joins.size(), 12, "four exact joins in every view")
	_suite.assert_equal(_observed, 3795, "complete five-program half-interval census")
	_suite.assert_equal(_shots.size(), 93, "complete native image selection after explicit integer conversion")
	_suite.assert_false(bool(_spec.production_qualified), "no production permission")
	_suite.assert_equal(_ceil_ratio(-65537, 65536), -1, "negative ceil boundary")
	_suite.assert_equal(_ceil_ratio(-1, 65536), 0, "negative fractional root")


func _finish() -> void:
	"""Report actual native observations without converting sampled rendering into continuous World proof."""
	var report: Dictionary = {"schema": 1, "scope": "source_only_stair_handoffs_gl",
		"production_qualified": false, "poses": _observed, "assertions": _suite.assertions,
		"failures": _suite.failures, "events": _events, "joins": _joins, "screenshots": _shots,
		"bone_checks": _bone_checks, "world_checks": _world_checks, "fixture_parts": _fixture_count,
		"renderer": str(RenderingServer.get_current_rendering_method()), "user_directory": OS.get_user_data_dir(),
		"program_content_sha256": _spec.program_content_sha256, "basis_sha256": _spec.basis_sha256,
		"gameplay_rate_adopted": false, "actual_world_playback": false, "metal_qualified": false}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("native-handoffs: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
