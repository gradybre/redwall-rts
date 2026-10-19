extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): a room wide along the Corridor wall.


func test_a_kitchen_twelve_wide_and_four_deep_east_of_its_access_is_dug() -> void:
	"""12 cells along the Corridor wall, 4 deep: most of the room lies past the Corridor's north end and is reached by
	turning inside the room."""
	dig_matrix(EAST, 12, 4)
