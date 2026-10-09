extends "preview_closed.gd"
## Side and rear native witnesses for the provisionally selected firm hand derivative.


func _run() -> void:
	"""Inspect the whole actual strike and recovery from both sides and behind before rebaking."""
	var bundle: String = _out
	_world = Node3D.new()
	root.add_child(_world)
	_stage()
	if not _build_actors():
		_world.free()
		quit(2)
		return
	await _capture_angles(bundle)
	_actors.clear()
	_world.free()
	_world = null
	var file: FileAccess = FileAccess.open(bundle + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "poses": _samples, "changed_vertices": Array(_changed),
		"original_mesh_sha256": Array(_source_hashes), "derived_mesh_sha256": Array(_derived_hashes),
		"source_mesh_unchanged_checks": _source_hashes.size(), "production_qualified": false,
		"views": ["right-side", "rear", "left-side"], "status": "VISUAL_REVIEW_ONLY",
		"hand_geometry": "authored distal palm contraction; original rig, weights and materials"}, "\t") + "\n")
	file.close()
	print("grip-angle-preview: ", _samples, " actual poses across three views; qualification=0")
	quit(0)


func _capture_angles(bundle: String) -> void:
	"""World positions keep caption order; rotating every source actor exposes its actual palm and wrist."""
	var names: PackedStringArray = ["right-side", "rear", "left-side"]
	var angles: PackedFloat32Array = PackedFloat32Array([PI * 0.5, 0.0, PI * 1.5])
	for view: int in names.size():
		_out = bundle + "/" + names[view]
		if DirAccess.make_dir_absolute(_out) != OK:
			printerr("GRIP_VIEW_DIRECTORY_REFUSED")
			quit(2)
			return
		for actor: Demo in _actors:
			actor.rotation.y = angles[view]
		for clip: StringName in [&"idle", &"walk", &"heavy_hammer_swing"]:
			await _capture_clip(clip)
