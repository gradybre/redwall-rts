extends "res://test/framework/test_case.gd"
## The live demo's DAY AND NIGHT on the REAL scene (decision 0541): runs test/live/demo_daylight_live.gd in its own
## headless process and asserts every check it prints -- the light at 06:00, 12:00, 19:30, 23:00 and 04:30, a rainy
## dusk, a snowy night, the U view at night left to its own environment, and Brighter nights turned on in the Settings.
## A separate process because this runner's worker runs every suite inside `_initialize`, before the root is in the
## tree (decision 0261). The harness boots demo/demo_village.tscn, on placeholders when the assets are not staged.

const HARNESS: String = "res://test/live/demo_daylight_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run (fewer means it stopped early).
const MIN_CHECKS: int = 38


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


func test_the_day_and_the_night_on_the_real_scene_at_1920x1080() -> void:
	"""Dawn, noon, dusk, a resident at night on the path, before dawn, a rainy dusk, a snowy night, U at night and
	Brighter nights -- on the real scene at 1920x1080."""
	_assert_run("1920x1080")
