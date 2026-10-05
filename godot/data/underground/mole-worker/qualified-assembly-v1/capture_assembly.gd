extends "../evidence/grip-authoring/native_grip_sequence.gd"
## Native source witness only. Exact original meshes and finite paid-part shapes confer no live World permission.

const Handling := preload("res://data/underground/mole-worker/qualified-assembly-v1/handling_clock.gd")
const FRAME_COUNTS: PackedInt32Array = [55, 2, 55]
const FIRST_FRAMES: PackedInt32Array = [0, 55, 57]
const LOCAL_BOXES: PackedInt32Array = [-192, 0, -512, 1856, 128, -384, -256, 0, -512, 256, 128, -384]
var _native: FileAccess = null
var _beam: MeshInstance3D = null
var _events: Array[Dictionary] = []


func _run() -> void:
	"""Read one finite image and record all quarter-interval source poses, in both directions, through actual Actor."""
	_suite.assert_equal(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes), &"", "actual assembly image")
	_clock_tests()
	_world = Node3D.new()
	root.add_child(_world)
	_build_stage()
	var meshes: Dictionary = _borrow_actual_meshes()
	if _suite.failures.is_empty():
		_bind_actor(meshes)
	_native = FileAccess.open(_out + "/native.bin", FileAccess.WRITE)
	_native.store_buffer("UGASMN01".to_ascii_buffer())
	if _suite.failures.is_empty():
		for assembly: int in 2:
			for view: String in ["side", "opposite", "rts"]:
				_setup_view(assembly, view)
				await _sequence(assembly, view, false)
				await _sequence(assembly, view, true)
				await _canonical_sequence(assembly, view)
	_native.close()
	_native = null
	_world.free()
	_world = null
	_actor = null
	_camera = null
	_beam = null
	_finish()


func _build_stage() -> void:
	"""Lighting and the support-plane illustration are presentation, not the continuous physical proof."""
	super._build_stage()
	root.size = Vector2i(1280, 720)
	_camera.size = 2.8
	_beam = MeshInstance3D.new()
	_beam.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("916036")
	material.roughness = 0.85
	_beam.material_override = material
	_world.add_child(_beam)
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(4.0, 0.0625, 4.0)
	floor_node.mesh = floor_mesh
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color("555749")
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	floor_node.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(0.0, -0.03125, 0.0)
	_world.add_child(floor_node)


func _setup_view(assembly: int, view: String) -> void:
	"""The complete included bearer dimensions remain exact for each immutable assembly."""
	var at: int = assembly * 6
	var low: Vector3i = Vector3i(LOCAL_BOXES[at], LOCAL_BOXES[at + 1], LOCAL_BOXES[at + 2])
	var high: Vector3i = Vector3i(LOCAL_BOXES[at + 3], LOCAL_BOXES[at + 4], LOCAL_BOXES[at + 5])
	(_beam.mesh as BoxMesh).size = Vector3(high - low) / 1024.0
	var focus: Vector3 = Vector3(ORIGIN_U) / 1024.0 + Vector3(0.15, 0.4, -0.2)
	var offset: Vector3 = Vector3(3.0, 0.5, -0.3)
	if view == "opposite": offset = Vector3(-3.0, 0.5, -0.3)
	if view == "rts": offset = Vector3(2.2, 2.5, 2.5)
	_camera.position = focus + offset
	_camera.look_at(focus, Vector3.UP)


func _sequence(assembly: int, view: String, reversed_source: bool) -> void:
	"""Reversal uses the same exact affine intervals; this does not adopt a cancellation or productive-work rate."""
	var order: PackedInt32Array = PackedInt32Array([2, 1, 0] if reversed_source else [0, 1, 2])
	for clip: int in order:
		var steps: int = (FRAME_COUNTS[clip] - 1) * 4
		for step: int in steps + 1:
			var q16: int = (steps - step if reversed_source else step) * 16384
			await _sample(assembly, view, reversed_source, clip, q16)
			if not _suite.failures.is_empty(): return


func _sample(assembly: int, view: String, reversed_source: bool, clip: int, q16: int,
		kind: String = "quarter", tick: int = -1) -> void:
	"""Observe original skin matrices, actual pick/root transforms and the exact complete-bearer transform."""
	var frames: PackedInt32Array = PackedInt32Array([0, 0, 0])
	_suite.assert_equal(_content.clip_into(clip, q16, frames), &"", "finite source Q16")
	var pose: PackedInt32Array = PackedInt32Array([frames[0], frames[1], frames[2], frames[0], frames[1], frames[2], 65536])
	_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native assembly pose")
	var offset_z: float = 0.0
	var at: int = assembly * 6
	_beam.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(
		float(LOCAL_BOXES[at] + LOCAL_BOXES[at + 3]) / 2048.0,
		float(LOCAL_BOXES[at + 1] + LOCAL_BOXES[at + 4]) / 2048.0,
		float(LOCAL_BOXES[at + 2] + LOCAL_BOXES[at + 5]) / 2048.0 + offset_z / 1024.0)
	_suite.assert_equal(frames[0], FIRST_FRAMES[clip] + mini(q16 >> 16, FRAME_COUNTS[clip] - 1), "original key identity")
	_suite.assert_equal(_actor._palette.bind_count(0), 24, "all original body bones")
	_events.append({"assembly": assembly, "view": view, "reverse": reversed_source, "clip": clip,
		"q16": q16, "frames": Array(frames), "bearer_offset_z_u": offset_z, "kind": kind, "tick": tick})
	for bind: int in 24: _write_matrix(_actor.native_matrix(0, bind))
	_write_matrix(_actor.native_matrix(1, 0))
	_write_matrix(_actor._nodes[0].global_transform)
	_write_matrix(_beam.global_transform)
	_observed += 1
	await process_frame
	var duration: int = (FRAME_COUNTS[clip] - 1) * 65536
	if kind == "quarter" and (q16 == 0 or q16 == duration or q16 == (duration >> 1)):
		_save_frame("a%d-%s-%s-c%d-q%d" % [assembly, view, "reverse" if reversed_source else "forward", clip, q16], clip, q16)


func _canonical_sequence(assembly: int, view: String) -> void:
	"""Actual native palettes consume the exact 30-tick entry and recovery equations; no paid state is fabricated."""
	var state: Vector2i = Vector2i(Handling.ENTRY, 0)
	var out: PackedInt32Array = PackedInt32Array([0, 0])
	for tick: int in 61:
		_suite.assert_equal(Handling.source_into(state.x, state.y, out), &"", "canonical integer source")
		await _sample(assembly, view, false, out[0], out[1], "clock", tick)
		state = Handling.advance(state.x, state.y)
	_suite.assert_equal(state, Vector2i(Handling.HANDLED_READY, 0), "actual complete handling sequence")


func _clock_tests() -> void:
	"""Every interrupted entry retraces without a completion marker; saved integer state resumes identically."""
	var out: PackedInt32Array = PackedInt32Array([123, 456])
	for phase: int in [-1, 1, 2, 3, 4, 6, 9, 10, 12, 15]:
		_suite.assert_equal(Handling.source_into(phase, 0, out), &"ASSEMBLY_SOURCE_CLOCK", "reserved phase")
		_suite.assert_equal(out, PackedInt32Array([123, 456]), "refused output unchanged")
	for elapsed: int in 30:
		var original: Vector2i = Vector2i(Handling.ENTRY, elapsed * Handling.ONE)
		var interrupted: Vector2i = Handling.interrupt(original.x, original.y)
		for step: int in elapsed: interrupted = Handling.advance(interrupted.x, interrupted.y)
		_suite.assert_equal(interrupted, Vector2i(Handling.READY, 0), "partial entry never handled")
		var replay: Vector2i = original
		for step: int in 60 - elapsed: replay = Handling.advance(replay.x, replay.y)
		_suite.assert_equal(replay, Vector2i(Handling.HANDLED_READY, 0), "exact saved phase resumes")
	_suite.assert_equal(Handling.advance(Handling.ENTRY, 1), Vector2i(-1, -1), "fractional authoritative tick refuses")
	_suite.assert_equal(Handling.advance(Handling.ENTRY, Handling.DURATION), Vector2i(-1, -1), "noncanonical boundary refuses")


func _write_matrix(matrix: Transform3D) -> void:
	"""Original native binary32 columns are retained without source-side recomposition."""
	for vector: Vector3 in [matrix.basis.x, matrix.basis.y, matrix.basis.z, matrix.origin]:
		_native.store_float(vector.x)
		_native.store_float(vector.y)
		_native.store_float(vector.z)


func _save_frame(label: String, clip: int, tick: int) -> void:
	"""Every evidence image comes from an actual draw; source phase never depends on rendering."""
	RenderingServer.force_draw(false, 0.0)
	var image: Image = root.get_texture().get_image()
	var path: String = _out + "/" + label + ".png"
	_suite.assert_false(FileAccess.file_exists(path), "create-only frame")
	_suite.assert_equal(image.save_png(path), OK, "actual rendered source")
	_shots.append({"path": label + ".png", "clip": clip, "q16": tick, "sha256": FileAccess.get_sha256(path)})
	print("assembly-frame: ", _observed, " ", label)


func _finish() -> void:
	"""Sampled native source execution remains separate from source-continuous and actual paid-world permission."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"matrix_count": 27, "assertions": _suite.assertions, "failures": _suite.failures, "events": _events,
		"screenshots": _shots, "native_sha256": FileAccess.get_sha256(_out + "/native.bin"),
		"resolution": [root.size.x, root.size.y], "user_directory": OS.get_user_data_dir(),
		"production_qualified": false, "world_identity": "presentation fixture only; no paid state, path or support permission",
		"source_time": "Q16 quarter intervals in both directions plus the exact 30-tick entry/recovery source equations; no paid owner state",
		"source_mesh_sha256": Grip.SOURCE_DIGEST, "derived_mesh_sha256": Grip.DERIVED_DIGEST}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures: printerr("FAIL: ", failure)
	print("native-assembly: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
