extends "res://test/run_tests.gd"
## Exact Gear boundary plus existing real Gear behavior and section7 codec.
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_gear_columns.gd", "res://test/test_gear.gd",
		"res://test/test_save_section_inventories.gd"])
