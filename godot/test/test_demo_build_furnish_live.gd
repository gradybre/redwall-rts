extends "res://test/live_harness_case.gd"
## Decision 1921, the Furnish tab's whole loop live: runs test/live/demo_build_furnish_live.gd in its own headless
## process and asserts every check it prints -- the Kitchen and Dormitory dug, a hearth and two benches placed (one
## turned with R), the refusals in words, Confirm all, a resident fitting them, "✓ Kitchen ready", and two beds raising
## the HUD's Beds. Its own suite (the slow tier): the loop takes over a minute.

const FURNISH_HARNESS: String = "res://test/live/demo_build_furnish_live.gd"
## The harness's checks (57 on this branch); fewer means it stopped early.
const FURNISH_CHECKS: int = 57


func test_the_furnish_tab_places_fits_and_readies_rooms_at_1280x720() -> void:
	"""The Furnish tab's loop through the real input gate on the real village."""
	_assert_run("1280x720", FURNISH_HARNESS, FURNISH_CHECKS)
