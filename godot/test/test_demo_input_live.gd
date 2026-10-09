extends "res://test/framework/test_case.gd"
## The live demo's input, menu and keyboard on the REAL scene with REAL Viewport input (decision 0261;
## review F26, F29, F30, F50): runs test/live/demo_input_live.gd in its own headless process and asserts
## every check it prints. A separate process because this runner's worker runs every suite inside
## `_initialize`, before the root is in the tree -- there no Viewport can dispatch a click or a key. The
## harness boots demo/demo_village.tscn, on placeholders when the demo's assets are not staged.

const HARNESS: String = "res://test/live/demo_input_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run (the harness has more; fewer means it stopped early).
const MIN_CHECKS: int = 80


func _run_harness(size: String, harness: String = HARNESS) -> PackedStringArray:
	"""The harness's output lines at a window size ("1280x720"); its exit code last."""
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
		harness, "--", "--size", size]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var lines: PackedStringArray = ("".join(PackedStringArray(output))).split("\n")
	lines.append("EXIT %d" % code)
	return lines


func _assert_run(size: String, harness: String = HARNESS, minimum_checks: int = MIN_CHECKS) -> void:
	"""Every LIVE check passed, the summary came, no script error, exit 0."""
	var lines: PackedStringArray = _run_harness(size, harness)
	var checks: int = 0
	var summary: String = ""
	for line: String in lines:
		if line.begins_with(SUMMARY_PREFIX):
			summary = line
		elif line.begins_with(CHECK_PREFIX):
			checks += 1
			assert_true(line.contains(": PASS"), "%s %s" % [size, line.substr(CHECK_PREFIX.length())])
		elif line.contains("SCRIPT ERROR"):
			fail("%s: %s" % [size, line])
		elif line.begins_with("ERROR:") or line.begins_with("USER ERROR:") or line.contains("leaked at exit") \
				or line.contains("ObjectDB instance") or line.contains("resources still in use at exit"):
			fail("%s: child diagnostics: %s" % [size, line])
		elif line.begins_with("WARNING:"):
			var unstaged := line == "WARNING: demo assets are not staged (tools/stage_demo_assets.py); running on placeholders" \
					or (line.begins_with("WARNING: sound cue ") and line.ends_with("; it plays silent until they are staged"))
			assert_true(unstaged, "%s: only the known unstaged-asset notices are allowed: %s" % [size, line])
	assert_false(summary.is_empty(), "%s: the harness finished (summary line printed)" % size)
	assert_true(checks >= minimum_checks, "%s: %d checks ran" % [size, checks])
	assert_equal(lines[lines.size() - 1], "EXIT 0", "%s: the harness exited cleanly" % size)


func test_the_real_scene_routes_input_menu_and_focus_at_1280x720() -> void:
	"""The Pantry, the menu, focus and the Lab, clicked and keyed on the real village at 1280x720."""
	_assert_run("1280x720")


func test_the_real_scene_routes_input_menu_focus_and_scale_at_1920x1080() -> void:
	"""The same at 1920x1080, where the harness also picks 150 %, restarts at it and shrinks the window."""
	_assert_run("1920x1080")


func test_room_blueprints_use_real_clicks_and_fit_at_1280x720() -> void:
	"""The live room review: held clicks, panel actions, explicit confirmation, refusal and Escape routing."""
	_assert_run("1280x720", "res://test/live/demo_room_blueprint_live.gd", 24)
