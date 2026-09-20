extends "res://test/run_tests.gd"
## Checked queries, established claims, exact owner restoration and wire codec.
func _discover_suites() -> PackedStringArray:
	return PackedStringArray(["res://test/test_reservation_totals.gd",
		"res://test/test_reservations.gd", "res://test/test_reservations_columns.gd",
		"res://test/test_save_section_inventories.gd"])
