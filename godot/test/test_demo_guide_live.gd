extends "res://test/framework/test_case.gd"
## The first-village guide on the REAL scene with REAL Viewport input (decision 0481): runs test/live/demo_guide_live.gd in
## its own headless process (see test_demo_input_live.gd for why) and asserts every check it prints -- the first
## objective done by a real click on the marked resident, Show me, Hide and the menu's Reopen granting nothing, the
## village guide's help typed into, a field-guide entry opened, a practice story leaving the village alone, a project
## named and pinned. On placeholders when the demo's assets are not staged.

const HARNESS: String = "res://test/live/demo_guide_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
## At least this many checks must run (fewer means the harness stopped early).
const MIN_CHECKS: int = 30


func _assert_run(size: String) -> void:
	"""Every LIVE check passed, the summary came, no script error, exit 0."""
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
		HARNESS, "--", "--size", size]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var lines: PackedStringArray = ("".join(PackedStringArray(output))).split("\n")
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
	assert_equal(code, 0, "%s: the harness exited cleanly" % size)


func test_the_guide_by_real_input_at_1280x720() -> void:
	"""The first objective by a real click, skip and reopen, and the village guide's pages, at 1280x720."""
	_assert_run("1280x720")


func test_the_guide_by_real_input_at_1920x1080() -> void:
	"""The same at 1920x1080."""
	_assert_run("1920x1080")
