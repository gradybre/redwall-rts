extends "res://test/run_tests.gd"

func _discover_suites() -> PackedStringArray:
	"""Development-only strict supervisor focus; final qualification also runs the registry-gated wrapper."""
	return PackedStringArray(["res://test/test_underground_connector_delivery.gd"])
