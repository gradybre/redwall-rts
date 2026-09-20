extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_resource_claim_lifecycle.gd"])
