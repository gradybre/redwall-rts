extends "res://test/live_harness_case.gd"
## Decision 2002, the Mound homes' whole loop live: runs test/live/demo_build_mound_live.gd in its own headless process
## and asserts every check it prints -- a Kitchen, a Hall (Passage) and a Bedroom painted in the Mound style on the
## Surface, "! No way in" until a door, a door and two windows placed (one refused on a door's yard, in words), Confirm
## all, the hill heaped, dug, framed and topped by a resident, the hill fitting its rules, a Pantry grown on with a
## hatch on its floor that lands on level 1, and a hearth fitted under a chimney. Its own suite (the slow tier).

const MOUND_HARNESS: String = "res://test/live/demo_build_mound_live.gd"
## The harness's checks; fewer means it stopped early.
const MOUND_CHECKS: int = 45


func test_the_mound_is_planned_built_grown_and_entered_at_1280x720() -> void:
	"""The Mound homes' loop through the real input gate on the real village."""
	_assert_run("1280x720", MOUND_HARNESS, MOUND_CHECKS)
