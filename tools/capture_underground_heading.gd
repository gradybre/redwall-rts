extends "capture_underground_transitions.gd"
## Native evidence only: preserve the accepted brain observations and add the actual rendered root.

var _previous_rendered: Vector3 = Vector3.ZERO


func _implementation_error(pins: Dictionary) -> String:
	"""Keep the inherited transition reader's literal dependency closure source-bound in this sibling."""
	var refusal: String = super._implementation_error(pins)
	if refusal != "":
		return refusal
	var pending: Array[String] = [get_script().resource_path.get_base_dir().path_join("capture_underground_transitions.gd")]
	var seen: Dictionary = {}
	var references: RegEx = RegEx.create_from_string("(?:preload|load)\\(\\s*\"(res://[^\"]+\\.gd)\"\\s*\\)")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		if seen.size() >= MAX_SOURCES or not pins.has(path):
			return "HEADING_INHERITED_IMPLEMENTATION_UNPINNED"
		seen[path] = true
		for matched: RegExMatch in references.search_all(FileAccess.get_file_as_string(path)):
			var dependency: String = matched.get_string(1)
			if not seen.has(dependency) and not pending.has(dependency):
				pending.append(dependency)
	return ""


func _capture_pose() -> void:
	"""The unchanged evaluator measures final skin output; this adds display and source heading separately."""
	super._capture_pose()
	if _error != "":
		return
	var rendered: Vector3 = _actor.rotation
	_row.motion[-1]["rendered_yaw_rad"] = rendered.y
	_row.motion[-1]["rendered_pitch_rad"] = rendered.x
	_row.motion[-1]["rendered_stoop_lean_rad"] = _actor.stoop().lean_rad if _actor.stoop() != null else 0.0
	if _step == 0:
		_row["max_rendered_yaw_step_rad"] = 0.0
	else:
		_row.max_rendered_yaw_step_rad = maxf(_row.max_rendered_yaw_step_rad,
			absf(angle_difference(_previous_rendered.y, rendered.y)))
	_previous_rendered = rendered
