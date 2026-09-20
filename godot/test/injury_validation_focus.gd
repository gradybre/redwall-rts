extends "res://test/run_tests.gd"

func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_save_owner_injury.gd"])
