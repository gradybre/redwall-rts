extends "res://test/framework/test_case.gd"
## The playtest log's engine-level capture (decision 0562): runs test/live/playtest_log_live.gd in its own
## headless process and asserts every check it prints. A separate process because the harness raises a real
## push_error, push_warning, printerr, script error and thread error for the logger to catch, and pushes F12 through
## the Viewport, which this runner's worker cannot (its root is not in the tree).

const HARNESS: String = "res://test/live/playtest_log_live.gd"
const CHECK_PREFIX: String = "LIVE "
const SUMMARY_PREFIX: String = "LIVE-SUMMARY "
const MIN_CHECKS: int = 13


func test_the_real_logger_captures_every_kind_of_line_and_f12_marks() -> void:
	"""Every LIVE check passed, the summary came, and the process exited 0 (no abort at exit: decision 0562)."""
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", HARNESS]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var checks: int = 0
	var summary: String = ""
	for line: String in "".join(PackedStringArray(output)).split("\n"):
		if line.begins_with(SUMMARY_PREFIX):
			summary = line
		elif line.begins_with(CHECK_PREFIX):
			checks += 1
			assert_true(line.contains(": PASS"), line.substr(CHECK_PREFIX.length()))
	assert_false(summary.is_empty(), "the harness finished (summary line printed)")
	assert_true(checks >= MIN_CHECKS, "%d checks ran" % checks)
	assert_equal(code, 0, "the harness exited cleanly")
