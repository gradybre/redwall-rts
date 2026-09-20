extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Run saved Schedule validation alongside its established public behavior suite."""
	return PackedStringArray(["res://test/test_save_owner_schedule.gd","res://test/test_schedule.gd"])
