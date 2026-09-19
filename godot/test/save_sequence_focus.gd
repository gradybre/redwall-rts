extends "res://test/run_tests.gd"
## Run SAVE-SEQ-R01 and the exact pending restore regression surface through the audited supervisor.

func _discover_suites() -> PackedStringArray:
	"""Cover wire framing, allocator semantics, canonical values and prior queue restoration."""
	return PackedStringArray(["res://test/test_economic_sequence_format.gd",
		"res://test/test_commands.gd", "res://test/test_commands_arena_restore.gd",
		"res://test/test_save_section_pending_commands.gd", "res://test/test_scheduler_events.gd",
		"res://test/test_canonical_state_hash.gd"])
