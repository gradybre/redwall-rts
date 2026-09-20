extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_fishing_claim_identity.gd", "res://test/test_resource_claim_columns.gd", "res://test/test_fishing.gd", "res://test/test_save_section_inventories.gd", "res://test/test_canonical_state_hash.gd"])
