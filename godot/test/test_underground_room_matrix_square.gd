extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): a square room larger than the Corridor is
## wide, so its far cubes are reached over the room's own dug floor.


func test_a_seven_by_seven_kitchen_east_of_its_access_is_dug() -> void:
	"""7 x 7 cells east of the access: the rows past the Corridor's north end are reached by turning inside the room
	(an L-shaped approach, or a turned heading), every cube dug."""
	var run: Dig = dig_matrix(EAST, 7, 7)
	if run != null:
		assert_true(run.peak_published > 3, "an L-shaped chain of more than three stations: %d" % run.peak_published)
