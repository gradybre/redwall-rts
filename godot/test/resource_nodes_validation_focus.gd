extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Owner13 scalar validation oracles; full run also covers ordinary resource history."""
	return PackedStringArray(["res://test/test_save_owner_resource_nodes.gd"])
