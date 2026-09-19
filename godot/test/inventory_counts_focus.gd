extends "res://test/run_tests.gd"
## Whole-stock queries plus existing owner and real equipment regressions.

func _discover_suites() -> PackedStringArray:
	"""Exercise the new interface with the normal non-vacuous runner."""
	return PackedStringArray(["res://test/test_inventory_stock_counts.gd",
		"res://test/test_inventory.gd", "res://test/test_gear.gd"])
