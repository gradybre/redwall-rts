extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): a room wide along the Corridor wall.


func _init() -> void:
	"""The floor band only (`matrix_height_u`, room_heading_case.gd)."""
	matrix_height_u = Contract.QUANTUM_SIDE_U


func test_a_kitchen_twelve_wide_and_four_deep_east_of_its_access_is_dug() -> void:
	"""12 cells along the Corridor wall, 4 deep: most of the room lies past the Corridor's north end and is reached by
	turning inside the room."""
	var run: Dig = dig_matrix(EAST, 12, 4)
	if run != null:
		assert_true(run.peak_published > 3, "an L-shaped chain of more than three stations: %d" % run.peak_published)
