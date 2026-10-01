extends "res://test/run_tests.gd"
## PC-04 adoption focus: hunger wiring, households/care store and their consumer regressions.

func _discover_suites() -> PackedStringArray:
	"""Run the PC-04 suites with the existing need, resident and rate-table regressions."""
	return PackedStringArray(["res://test/test_family_hunger_wiring.gd",
		"res://test/test_households.gd", "res://test/test_family_rules.gd", "res://test/test_needs.gd",
		"res://test/test_ui_resident_snapshot.gd", "res://test/test_ui_resident_card.gd",
		"res://test/test_injury.gd", "res://test/test_settlement_system.gd",
		"res://test/test_residents.gd"])
