extends "res://test/run_tests.gd"
## Focus runner for GROUND-CLEARANCE-R01v1: the two existing movement suites plus the new one.
func _discover_suites() -> PackedStringArray:
	return PackedStringArray([
		"res://test/test_movement.gd",
		"res://test/test_movement_readmission.gd",
		"res://test/test_movement_clearance.gd",
	])
