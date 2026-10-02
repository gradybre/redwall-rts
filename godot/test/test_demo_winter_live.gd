extends "res://test/framework/test_case.gd"
## The winter's fuel and warmth loop on the REAL scene with REAL Viewport input (decision 0571): runs
## test/live/demo_winter_live.gd in its own headless process at 1280x720 and 1920x1080 and asserts every check it prints
## (the input live test's own way: the runner's worker cannot dispatch input). On placeholders when the demo's assets
## are not staged.

const HARNESS: String = "res://test/live/demo_winter_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run (fewer means the harness stopped early).
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


func test_the_winter_on_the_real_scene_at_1280x720() -> void:
	"""Spring's no demand, the Lab's skip by click, autumn's projection by the cell's click, winter with low wood, the
	hall out and cooling, Chilled at 80%, wood in and the warm-up, Consolidate, at 1280x720."""
	_assert_run("1280x720")


func test_the_winter_on_the_real_scene_at_1920x1080() -> void:
	"""The same at 1920x1080."""
	_assert_run("1920x1080")
