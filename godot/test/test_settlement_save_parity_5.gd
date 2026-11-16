extends "res://test/settlement_save_parity_case.gd"
## ARCH-SAVE-006 next-tick parity, fingerprint part 5 of PARTS (decision 1895); the test and its fixture are
## settlement_save_parity_case.gd.


func test_a_save_at_3000_continues_tick_for_tick_to_18000_with_its_coverage_cases() -> void:
	"""ARCH-SAVE-006: the fork at 3000 with a pending command, every tick to 18000, and each coverage case found on
	the way, each compared tick for tick over its own window; this suite fingerprints member part 5."""
	_check_part(4)
