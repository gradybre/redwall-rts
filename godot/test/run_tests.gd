extends SceneTree
## Headless test runner.
##
## Usage, from the `godot/` project directory:
##     godot --headless --script test/run_tests.gd
##
## Exits 0 when every suite passes and 1 otherwise, so CI can gate on it.

const TestCaseScript := preload("res://test/framework/test_case.gd")

const TEST_DIR: String = "res://test"
const TEST_PREFIX: String = "test_"


func _initialize() -> void:
	"""Run every discovered suite, print a summary, and exit with a status code."""
	var total_tests: int = 0
	var total_failures: int = 0
	var total_assertions: int = 0
	for suite_path: String in _discover_suites():
		var result: Dictionary = _run_suite(suite_path)
		total_tests += int(result["tests"])
		total_failures += int(result["failed"])
		total_assertions += int(result["assertions"])
	print("")
	print("%d test(s), %d assertion(s), %d failure(s)" % [total_tests, total_assertions, total_failures])
	quit(1 if total_failures > 0 else 0)


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
	# Loaded at runtime, not preloaded: --script mode does not register autoload
	# globals, so a preload of a suite that references one would fail to parse.
	var script: GDScript = load(suite_path)
	if script == null:
		push_error("Test runner failed to load %s" % suite_path)
		return {"tests": 0, "failed": 1, "assertions": 0}
	print("%s" % suite_path.get_file())
	if not script.can_instantiate():
		push_error("Test runner cannot instantiate %s (parse error?)" % suite_path)
		print("  FAIL  <suite failed to load>")
		return {"tests": 1, "failed": 1, "assertions": 0}
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


func _run_test(suite: TestCaseScript, method_name: String) -> bool:
	"""Run one test method with its hooks. True when it recorded no failures."""
	suite.failures = PackedStringArray()
	suite.before_each()
	suite.call(method_name)
	suite.after_each()
	if suite.failures.is_empty():
		print("  PASS  %s" % method_name)
		return true
	print("  FAIL  %s" % method_name)
	for failure: String in suite.failures:
		print("        %s" % failure)
	return false
