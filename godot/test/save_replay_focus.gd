extends "res://test/run_tests.gd"
## Header relocation and checkpoint binding run through the same non-vacuous suite supervisor.

func _discover_suites() -> PackedStringArray:
	"""Exercise header/descriptor, section1 relocation, tuple binding and section12 regressions."""
	return PackedStringArray(["res://test/test_save_header.gd",
		"res://test/test_save_replay_checkpoint.gd", "res://test/test_save_section_01.gd",
		"res://test/test_economic_sequence_format.gd", "res://test/test_save_section_pending_commands.gd"])
