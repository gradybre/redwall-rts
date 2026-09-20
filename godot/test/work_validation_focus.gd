extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	"""Owner16 mutation oracles; full suite separately runs the76 existing Work tests."""
	return PackedStringArray(["res://test/test_save_owner_work.gd"])
