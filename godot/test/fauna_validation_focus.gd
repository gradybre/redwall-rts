extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""New owner17 mutation oracles; full suite separately covers existing world generation."""
	return PackedStringArray(["res://test/test_save_owner_world_init.gd"])
