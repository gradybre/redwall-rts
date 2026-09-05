extends RefCounted
## Dependency-free assertion base for the headless test runner.
##
## GUT is not vendored into this repo, so suites extend this instead. Suites
## live in `res://test/` as `test_<module>.gd`; every method named `test_*` is
## run once, wrapped in before_each()/after_each().

var failures: PackedStringArray = PackedStringArray()
var assertions: int = 0


func before_each() -> void:
	"""Hook run before every test method. Override in a suite as needed."""
	return


func after_each() -> void:
	"""Hook run after every test method. Override in a suite as needed."""
	return


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
