extends RefCounted
## Dependency-free assertion base for the headless test runner.
##
## GUT is not vendored into this repo, so suites extend this instead. Suites
## live in `res://test/` as `test_<module>.gd`; every method named `test_*` is
## run once, wrapped in before_each()/after_each().
##
## EVERY TEST METHOD MUST MAKE AT LEAST ONE ASSERTION. `assertions` is a running
## total for the whole suite, and the runner reads it as a before/after delta
## around each method: a method that leaves it unchanged is reported as a
## failure, because it is either vacuous or it died before reaching its first
## assertion. A suite must therefore never reset or assign this counter itself.
## `run_tests.gd`'s header explains why a GDScript runtime error inside a test
## is otherwise invisible, and what the runner does to catch one that lands
## partway down a method.

## ENGINE DIAGNOSTICS (decision 0501). An `ERROR:` or `WARNING:` line in the suite's log is a finding unless the test
## that printed it declared it. A negative test that provokes one on purpose calls `expect_diagnostic()` first; the
## runner then prints each matching line as `EXPECTED ERROR: ...` and FAILS the test if no such line appears, so a
## refusal that stops reporting itself is caught. A suite whose node fixtures can never be inside the scene tree (the
## worker runs before the root is, docs/ENVIRONMENT.md) overrides `tolerates_outside_tree()`, and a test whose output
## depends on what is staged on the machine calls `tolerate_diagnostic()`; such lines are printed as `TOLERATED ...`
## and none is required. Anything else stays a plain `ERROR:`/`WARNING:` line,
## which tools/run_tests.sh counts and fails on.
const MARK_EXPECT: String = "##EXPECT## "
const MARK_TOLERATE: String = "##TOLERATE## "
## A tolerance may name the engine function its next line (`   at: <function> (<file>)`) must come from, after this
## separator: `!is_inside_tree()` alone is the message of every unguarded tree check, and only these are the harness.
const TOLERATE_SOURCE_SEPARATOR: String = "\t"
## What the engine prints for a node used outside the tree: a 3D global transform read (a particle emitter restarting
## does one too) and a camera ray. Each is an artefact of the harness, not of the code.
const OUTSIDE_TREE_DIAGNOSTICS: Array[String] = [
	"Condition \"!is_inside_tree()\" is true.\tat: get_global_transform (scene/3d/node_3d.cpp",
	"Camera is not inside scene.\t(scene/3d/camera_3d.cpp",
]

var failures: PackedStringArray = PackedStringArray()
var assertions: int = 0


func before_each() -> void:
	"""Hook run before every test method. Override in a suite as needed."""
	return


func after_each() -> void:
	"""Hook run after every test method. Override in a suite as needed."""
	return


func tolerates_outside_tree() -> bool:
	"""Whether this suite drives node fixtures outside the scene tree (see ENGINE DIAGNOSTICS). Override to say so."""
	return false


func expect_diagnostic(fragment: String) -> void:
	"""Declare that the running test provokes, on purpose, an engine `ERROR:` or `WARNING:` line containing `fragment`.
	The runner fails the test when no such line follows (see ENGINE DIAGNOSTICS). Call it before provoking the line."""
	printerr(MARK_EXPECT + fragment)


func tolerate_diagnostic(fragment: String) -> void:
	"""Declare that the running test may print an engine line containing `fragment` depending on the machine, not the
	code: a sound cue whose files are not staged warns in CI and not where the demo's assets are staged. The runner
	prints a matching line as `TOLERATED ...`; none is required (see ENGINE DIAGNOSTICS)."""
	printerr(MARK_TOLERATE + fragment)


func fail(message: String) -> void:
	"""Record an unconditional failure."""
	assertions += 1
	failures.append(message)


func assert_true(condition: bool, message: String) -> void:
	"""Pass when the condition holds."""
	assertions += 1
	if not condition:
		failures.append("%s (expected true, got false)" % message)


func assert_false(condition: bool, message: String) -> void:
	"""Pass when the condition does not hold."""
	assertions += 1
	if condition:
		failures.append("%s (expected false, got true)" % message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	"""Pass when actual equals expected."""
	assertions += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func assert_almost_equal(actual: float, expected: float, message: String) -> void:
	"""Pass when two floats agree to within is_equal_approx tolerance."""
	assertions += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (expected %f, got %f)" % [message, expected, actual])


func assert_null(value: Variant, message: String) -> void:
	"""Pass when the value is null."""
	assertions += 1
	if value != null:
		failures.append("%s (expected null, got %s)" % [message, value])


func assert_not_null(value: Variant, message: String) -> void:
	"""Pass when the value is not null."""
	assertions += 1
	if value == null:
		failures.append("%s (expected a value, got null)" % message)


func assert_less_than(actual: float, limit: float, message: String) -> void:
	"""Pass when actual is strictly below the limit. Used for performance budgets."""
	assertions += 1
	if actual >= limit:
		failures.append("%s (expected < %f, got %f)" % [message, limit, actual])
