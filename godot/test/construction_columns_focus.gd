extends "res://test/run_tests.gd"
## Focused runner for the CONSTRUCTION-S4-VALIDATE-R01v2 tranche.
##
## Reuses run_tests.gd's whole supervisor/worker/marker-audit machinery unchanged, overriding
## only suite discovery so exactly the new suites plus the existing test_construction.gd run,
## not the whole test directory. The fourth entry is the twelve real public retirement histories,
## which is component-lifecycle evidence only and certifies no saved identity or gameplay claim.
## Usage, from the repository root:
##     godot --headless --path godot --script test/construction_columns_focus.gd

const FOCUS_SUITES: Array[String] = [
	"res://test/test_construction.gd",
	"res://test/test_construction_columns.gd",
	"res://test/test_save_owner_construction.gd",
	"res://test/test_construction_retired_histories.gd",
]


func _discover_suites() -> PackedStringArray:
	"""Exactly the four suites this focused tranche must run, in this fixed order."""
	return PackedStringArray(FOCUS_SUITES)
