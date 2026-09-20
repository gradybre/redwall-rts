extends "res://test/run_tests.gd"
## Exact planner owner, section codec and existing natural reconciliation.
func _discover_suites() -> PackedStringArray:
	"""Retain normal non-vacuous suite supervision."""
	return PackedStringArray(["res://test/test_job_planner_columns.gd",
		"res://test/test_save_section_job_indexes.gd", "res://test/test_planner_dirty_format.gd",
		"res://test/test_job_planner.gd"])
