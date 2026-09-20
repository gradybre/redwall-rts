extends "res://test/run_tests.gd"
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_save_component_columns_schema.gd",
		"res://test/test_save_section_component_columns.gd"])
