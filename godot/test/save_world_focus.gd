extends "res://test/run_tests.gd"
## Reuse the full non-vacuous supervisor for this bounded persistence suite.

func _discover_suites() -> PackedStringArray:
	"""Select the runtime install suite; all inherited output/error auditing remains active."""
	return PackedStringArray(["res://test/test_save_world_runtime_install.gd"])
