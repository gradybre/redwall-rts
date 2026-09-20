extends "res://test/run_tests.gd"
## Owner continuation and its existing section codec.
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_stock_age_columns.gd",
		"res://test/test_stock_age.gd", "res://test/test_save_section_inventories.gd"])
