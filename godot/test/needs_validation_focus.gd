extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Run the new bridge and the existing owner bulk API contract together."""
	return PackedStringArray(["res://test/test_save_owner_needs.gd","res://test/test_needs_columns.gd"])
