extends SceneTree
## Headless test runner.
##
## Usage, from the repository root:
##     godot --headless --path godot --script test/run_tests.gd
##
## Exits 0 when every suite passes and 1 otherwise, so CI can gate on it.
##
## ---------------------------------------------------------------------------------------
## WHY THIS RUNS AS TWO PROCESSES. GDScript has no try/catch, and a runtime error inside a test
## method does NOT unwind into its caller: the engine prints `SCRIPT ERROR:` to stderr, abandons
## the rest of THAT ONE METHOD, and every caller above it carries on as if the call had returned
## normally (probed on 4.7.2 through a direct call, a Callable and `Object.call()` -- all three
## resumed at the next statement). `suite.failures` is then empty and the method used to print
## PASS with most of its assertions never executed. That is not hypothetical: deleting one enum
## key made a method die halfway, still report PASS, and change nothing visible except the total
## assertion count, which fell by two.
##
## Nothing inside the process observes that error. `EngineDebugger` exposes capture hooks only
## for messages arriving FROM a remote debugger and reports `is_active() == false` under
## `--script`; installing an error handler is a C++/GDExtension-only API; and a process cannot
## read its own stderr. The engine's stderr is the only observable, so the default invocation is
## a SUPERVISOR: it re-executes this same script with the `--run-suites` user flag, captures the
## worker's stdout and stderr merged in emission order, and charges every `SCRIPT ERROR:` line to
## whichever test method was running when it appeared.
##
## Two independent guards, because they catch different things:
##   1. WORKER, per method: the suite's assertion counter must increase across the method. A
##      method that aborted before its first assertion fails, and so does a vacuous method that
##      asserts nothing at all.
##   2. SUPERVISOR, per method: any script error printed between a method's markers turns its
##      result into a FAIL even when every assertion it did reach passed. This is the guard that
##      catches an abort partway down a method, which the counter alone cannot see.
##
## `push_error()` output (`ERROR:` / `USER ERROR:`) is deliberately NOT treated as an abort. It
## does not stop execution, and the suite contains deliberate negative tests that provoke it.

const TestCaseScript := preload("res://test/framework/test_case.gd")

const TEST_DIR: String = "res://test"
const TEST_PREFIX: String = "test_"
## Passed to the worker after `--`, so it arrives in OS.get_cmdline_user_args().
const WORKER_FLAG: String = "--run-suites"

# --- worker -> supervisor protocol, one line each, all written to stderr ---------------------

const MARK_SUITE: String = "##SUITE## "
const MARK_TEST: String = "##TEST## "
const MARK_FAILURE: String = "##FAILURE## "
const MARK_RESULT: String = "##RESULT## "
const MARK_TOTALS: String = "##TOTALS## "
const VERDICT_PASS: String = "PASS"
const VERDICT_FAIL: String = "FAIL"

## Engine output that means a GDScript method was abandoned where it stood.
const ABORT_PREFIXES: Array[String] = ["SCRIPT ERROR:", "USER SCRIPT ERROR:"]

const NO_ASSERTIONS_MESSAGE: String = \
	"made no assertions (vacuous, or aborted before reaching its first one)"

# --- supervisor tally ------------------------------------------------------------------------

var _tests: int = 0
var _failures: int = 0
var _assertions: int = 0
var _worker_tests: int = 0
var _worker_failures: int = 0
var _saw_totals: bool = false
var _stray_aborts: int = 0
var _test_name: String = ""
var _test_aborts: int = 0
var _pending_failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	"""Run the suites when carrying the worker flag, otherwise supervise a worker that does."""
	if OS.get_cmdline_user_args().has(WORKER_FLAG):
		quit(_run_worker())
		return
	quit(_run_supervisor())


# --- worker ----------------------------------------------------------------------------------

func _run_worker() -> int:
	"""Run every discovered suite, emitting the marker protocol. Returns the exit code."""
	var tests: int = 0
	var failures: int = 0
	var assertions: int = 0
	for suite_path: String in _discover_suites():
		var result: Dictionary = _run_suite(suite_path)
		tests += int(result["tests"])
		failures += int(result["failed"])
		assertions += int(result["assertions"])
	_emit("%s%d %d %d" % [MARK_TOTALS, tests, assertions, failures])
	return 1 if failures > 0 else 0


func _emit(line: String) -> void:
	"""Write one protocol line to stderr, where it interleaves with the engine's own errors."""
	printerr(line)


func _discover_suites() -> PackedStringArray:
	"""Sorted paths of every `test_*.gd` file directly under TEST_DIR."""
	var paths: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Test runner cannot open %s" % TEST_DIR)
		return paths
	for file_name: String in dir.get_files():
		if file_name.begins_with(TEST_PREFIX) and file_name.ends_with(".gd"):
			paths.append("%s/%s" % [TEST_DIR, file_name])
	paths.sort()
	return paths


func _run_suite(suite_path: String) -> Dictionary:
	"""Instantiate one suite and run each of its test methods."""
	# The suite marker is emitted before the load so that a parse error, which the engine prints
	# during load(), is already inside this suite's span when the supervisor reads it.
	_emit(MARK_SUITE + suite_path.get_file())
	# Loaded at runtime, not preloaded: --script mode does not register autoload globals, so a
	# preload of a suite that references one would fail to parse.
	var script: GDScript = load(suite_path)
	if script == null:
		return _suite_load_failure("suite failed to load: %s" % suite_path)
	if not script.can_instantiate():
		return _suite_load_failure("suite cannot be instantiated (parse error?): %s" % suite_path)
	var suite: TestCaseScript = script.new()
	var tests: int = 0
	var failed: int = 0
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with(TEST_PREFIX):
			continue
		tests += 1
		if not _run_test(suite, method_name):
			failed += 1
	return {"tests": tests, "failed": failed, "assertions": suite.assertions}


func _suite_load_failure(reason: String) -> Dictionary:
	"""Report a suite that never ran at all as one failing pseudo-test."""
	_emit(MARK_TEST + "<suite did not load>")
	_emit(MARK_FAILURE + reason)
	_emit("%s%s 0" % [MARK_RESULT, VERDICT_FAIL])
	return {"tests": 1, "failed": 1, "assertions": 0}


func _run_test(suite: TestCaseScript, method_name: String) -> bool:
	"""Run one test method with its hooks, emitting its markers. True when it recorded no failures.

	The markers bracket before_each() and after_each() as well, so a runtime error raised in a
	hook is charged to the method it was setting up rather than to open air.
	"""
	suite.failures = PackedStringArray()
	var before: int = suite.assertions
	_emit(MARK_TEST + method_name)
	suite.before_each()
	suite.call(method_name)
	suite.after_each()
	var made: int = suite.assertions - before
	if made <= 0:
		suite.failures.append(NO_ASSERTIONS_MESSAGE)
	for failure: String in suite.failures:
		_emit(MARK_FAILURE + failure)
	var passed: bool = suite.failures.is_empty()
	_emit("%s%s %d" % [MARK_RESULT, VERDICT_PASS if passed else VERDICT_FAIL, made])
	return passed


# --- supervisor --------------------------------------------------------------------------------

func _run_supervisor() -> int:
	"""Run a worker process, audit its output, print the report. Returns the exit code."""
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), _worker_argv(), output, true, false)
	if exit_code < 0:
		_fail_run("could not start the worker process; no test was run")
	else:
		_audit(_capture_text(output), exit_code)
	print("")
	print("%d test(s), %d assertion(s), %d failure(s)" % [_tests, _assertions, _failures])
	return 1 if _failures > 0 else 0


func _worker_argv() -> PackedStringArray:
	"""Command line for the worker: this same script, this same project, plus the worker flag."""
	return PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", (get_script() as Script).resource_path,
		"--", WORKER_FLAG,
	])


func _capture_text(output: Array) -> String:
	"""Join the chunks OS.execute captured into one blob of merged stdout and stderr."""
	var text: String = ""
	for chunk: Variant in output:
		text += String(chunk)
	return text


func _audit(text: String, exit_code: int) -> void:
	"""Replay the worker's output line by line, printing the report and tallying failures."""
	for line: String in text.split("\n"):
		_audit_line(line)
	if _test_name != "":
		_pending_failures.append("worker stopped before reporting a result for this method")
		_finish_test(VERDICT_FAIL)
	_cross_check(exit_code)


func _cross_check(exit_code: int) -> void:
	"""Refuse to call a run clean when the worker's own tallies disagree with what was seen."""
	if not _saw_totals:
		_fail_run("worker ended before reporting its totals (exit code %d)" % exit_code)
		return
	if _stray_aborts > 0:
		_fail_run("%d script error(s) outside any test method" % _stray_aborts)
	if _worker_tests != _tests:
		_fail_run("worker counted %d test(s); the supervisor saw %d" % [_worker_tests, _tests])
	if _worker_failures > _failures:
		_fail_run("worker reported %d failure(s); the supervisor accounted for %d"
			% [_worker_failures, _failures])


func _audit_line(line: String) -> void:
	"""Interpret one line of worker output: protocol marker, script error, or pass-through."""
	if line.begins_with(MARK_SUITE):
		print(line.substr(MARK_SUITE.length()))
	elif line.begins_with(MARK_TEST):
		_begin_test(line.substr(MARK_TEST.length()))
	elif line.begins_with(MARK_FAILURE):
		_pending_failures.append(line.substr(MARK_FAILURE.length()))
	elif line.begins_with(MARK_RESULT):
		_finish_test(line.substr(MARK_RESULT.length()))
	elif line.begins_with(MARK_TOTALS):
		_read_totals(line.substr(MARK_TOTALS.length()))
	elif _is_abort(line):
		_record_abort(line)
	else:
		print(line)


func _is_abort(line: String) -> bool:
	"""True for engine output that means a GDScript method was abandoned where it stood."""
	for prefix: String in ABORT_PREFIXES:
		if line.begins_with(prefix):
			return true
	return false


func _record_abort(line: String) -> void:
	"""Print a script-error line and charge it to the running method, or to the run itself."""
	print(line)
	if _test_name == "":
		_stray_aborts += 1
		return
	_test_aborts += 1


func _begin_test(method_name: String) -> void:
	"""Open a method's span, closing any previous one the worker left unreported."""
	if _test_name != "":
		_pending_failures.append("worker began the next method without reporting this one")
		_finish_test(VERDICT_FAIL)
	_test_name = method_name
	_test_aborts = 0
	_pending_failures = PackedStringArray()


func _finish_test(payload: String) -> void:
	"""Close a method's span and print its verdict. A script error inside it overrides a PASS."""
	var verdict: PackedStringArray = payload.split(" ")
	var passed: bool = verdict.size() > 0 and verdict[0] == VERDICT_PASS and _test_aborts == 0
	_tests += 1
	if passed:
		print("  PASS  %s" % _test_name)
	else:
		print("  FAIL  %s" % _test_name)
		for failure: String in _pending_failures:
			print("        %s" % failure)
		if _test_aborts > 0:
			print("        ABORTED: %d script error(s) above ended this method early, so the"
				% _test_aborts)
			print("        assertions after that point never ran")
		_failures += 1
	_test_name = ""
	_test_aborts = 0
	_pending_failures = PackedStringArray()


func _read_totals(payload: String) -> void:
	"""Take the worker's tallies. Assertions can only be counted inside the worker process."""
	var fields: PackedStringArray = payload.split(" ")
	if fields.size() != 3:
		_fail_run("worker totals line was malformed: '%s'" % payload)
		return
	_worker_tests = int(fields[0])
	_assertions = int(fields[1])
	_worker_failures = int(fields[2])
	_saw_totals = true


func _fail_run(reason: String) -> void:
	"""Record a failure belonging to the run itself rather than to any one test method."""
	print("  FAIL  <test run>")
	print("        %s" % reason)
	_failures += 1
