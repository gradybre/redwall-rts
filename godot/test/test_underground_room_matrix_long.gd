extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): a room long along its heading.


func test_a_kitchen_four_wide_and_twelve_deep_east_of_its_access_is_dug() -> void:
	"""4 cells along the Corridor wall, 12 deep: long straight heading runs over the dug floor."""
	dig_matrix(EAST, 4, 12)
