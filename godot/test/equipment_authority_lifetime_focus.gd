extends "res://test/run_tests.gd"
## Focused runner for EQUIPMENT-LIFETIME-R01v1 (ADR 0187).
##
## Inherits `test/run_tests.gd`'s exact worker/supervisor protocol and overrides only which
## suites are discovered, so nothing here is a standalone or hidden witness. Usage:
##     godot --headless --path godot --script test/equipment_authority_lifetime_focus.gd

const FOCUS_SUITE_NAMES: Array[String] = [
	"res://test/test_equipment_authority_lifetime.gd",
	"res://test/test_inventory.gd",
	"res://test/test_gear.gd",
	"res://test/test_stock_authority_lifetime.gd",
	"res://test/test_settlement_system.gd",
]


func _discover_suites() -> PackedStringArray:
	"""Override discovery: exactly the five suites this review requires, in the stated order."""
	return PackedStringArray(FOCUS_SUITE_NAMES)
