extends "res://test/run_tests.gd"
## Pure stage table with the existing need and resident suites.

func _discover_suites() -> PackedStringArray:
	"""Retain the normal non-vacuous runner and actual consumer regressions."""
	return PackedStringArray(["res://test/test_family_rules.gd",
		"res://test/test_needs.gd", "res://test/test_residents.gd"])
