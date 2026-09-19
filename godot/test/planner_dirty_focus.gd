extends "res://test/run_tests.gd"
## Planner dirty-state format and canonical registry regression selection.

func _discover_suites() -> PackedStringArray:
	"""Use the normal suite supervisor for format, canonical declarations and live scheduling."""
	return PackedStringArray(["res://test/test_planner_dirty_format.gd",
		"res://test/test_save_section_job_indexes.gd", "res://test/test_canonical_state_hash.gd",
		"res://test/test_job_planner.gd"])
