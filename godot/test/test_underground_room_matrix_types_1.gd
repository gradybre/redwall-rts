extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): each room type at the GDD's minimum floor
## area (`room_catalog.gd`, `buildings.gd`; a tile is 2 x 2 cells), each on a different side of the access.


func test_a_dormitory_at_its_minimum_north_of_its_access_is_dug() -> void:
	"""A Dormitory's minimum: one bed's 3 tiles (12 cells), 2 along the wall and 6 deep, north."""
	dig_matrix(NORTH, 2, 6, Buildings.ROOM_TYPE_DORMITORY)


func test_an_infirmary_at_its_minimum_south_of_its_access_is_dug() -> void:
	"""An Infirmary's minimum: one patient bed's 3 tiles (12 cells), 6 along the wall and 2 deep, south."""
	dig_matrix(SOUTH, 6, 2, Buildings.ROOM_TYPE_INFIRMARY)


func test_a_corridor_at_its_minimum_width_west_of_its_access_is_dug() -> void:
	"""A Corridor at its minimum width of one tile (2 cells), 4 cells long, west."""
	dig_matrix(WEST, 2, 4, Buildings.ROOM_TYPE_CORRIDOR)
