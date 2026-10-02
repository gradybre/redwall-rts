extends "res://test/framework/test_case.gd"
## The hall on the REAL scene with real input (decision 0771): runs test/live/demo_hall_live.gd in its own headless
## process at 1280x720 and 1920x1080 and asserts every check it prints -- a click on the hall opening its panel, the
## tapestry opened from it and closed by Esc, the upgrade locked until the first harvest, Plan sending the selected
## builders and the work board listing them, stone carried to the hall on the running clock, the work rail, the great
## hall, four banners and the full tapestry. A separate process because only an in-tree scene lays its Controls out and
## takes Viewport input, and this runner's worker runs every suite before the root is in the tree. The harness boots
## demo/demo_village.tscn, on placeholders when the demo's assets are not staged.

const HARNESS: String = "res://test/live/demo_hall_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run per size (fewer means it stopped early).
const MIN_CHECKS: int = 30


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


func test_the_hall_on_the_real_scene_at_1280x720() -> void:
	"""The review's minimum window."""
	_assert_run("1280x720")


func test_the_hall_on_the_real_scene_at_1920x1080() -> void:
	"""The qualification floor's window."""
	_assert_run("1920x1080")
