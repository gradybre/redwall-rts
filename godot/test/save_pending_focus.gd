extends "res://test/run_tests.gd"
## Use the existing non-vacuous supervisor for the exact pending-queue restore scope.

func _discover_suites() -> PackedStringArray:
	"""Exercise ordinary admission, privileged owner replacement and the two-owner codec."""
	return PackedStringArray(["res://test/test_commands.gd",
		"res://test/test_commands_arena_restore.gd",
		"res://test/test_save_section_pending_commands.gd"])
