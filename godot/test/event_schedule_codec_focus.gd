extends "res://test/run_tests.gd"
## Existing schedule behavior and new wire adapter.
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_save_section_event_schedule.gd",
		"res://test/test_event_schedule.gd"])
