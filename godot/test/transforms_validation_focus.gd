extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Focused new image validation and existing public Transform behavior."""
	return PackedStringArray(["res://test/test_save_owner_transforms.gd","res://test/test_transforms.gd"])
