extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Run the framed validation contract beside existing public Priorities behavior."""
	return PackedStringArray(["res://test/test_save_owner_priorities.gd","res://test/test_priorities.gd"])
