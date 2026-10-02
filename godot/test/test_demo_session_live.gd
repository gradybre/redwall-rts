extends "res://test/framework/test_case.gd"
## The live demo's time controls and accessibility on the REAL scene with REAL Viewport input (decision 0471;
## review UX-022, UX-023): runs test/live/demo_session_live.gd in its own headless process and asserts
## every check it prints. A separate process because this runner's worker runs every suite inside
## `_initialize`, before the root is in the tree -- there no Viewport can dispatch a click or a key. The
## harness boots demo/demo_village.tscn, on placeholders when the demo's assets are not staged.

const HARNESS: String = "res://test/live/demo_session_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run (the harness has more; fewer means it stopped early).
const MIN_CHECKS: int = 64


func _run_harness(size: String) -> PackedStringArray:
	"""The harness's output lines at a window size ("1280x720"); its exit code last."""
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
		HARNESS, "--", "--size", size]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var lines: PackedStringArray = ("".join(PackedStringArray(output))).split("\n")
	lines.append("EXIT %d" % code)
	return lines


func _assert_run(size: String) -> void:
	"""Every LIVE check passed, the summary came, no script error, exit 0."""
	var lines: PackedStringArray = _run_harness(size)
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
	assert_false(summary.is_empty(), "%s: the harness finished (summary line printed)" % size)
	assert_true(checks >= MIN_CHECKS, "%s: %d checks ran" % [size, checks])
	assert_equal(lines[lines.size() - 1], "EXIT 0", "%s: the harness exited cleanly" % size)


func test_pauses_run_until_presets_and_the_object_list_at_1280x720() -> void:
	"""Space, the planning pause, run until the meal and dawn, F6, the presets and Restore at 1280x720 (125 %)."""
	_assert_run("1280x720")


func test_pauses_run_until_presets_and_the_object_list_at_1920x1080() -> void:
	"""The same at 1920x1080, where Large readable takes 150 %."""
	_assert_run("1920x1080")
