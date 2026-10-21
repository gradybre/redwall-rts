extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): each room type at the GDD's minimum floor
## area (a tile is 2 x 2 cells).


func _init() -> void:
	"""The floor band only (`matrix_height_u`, room_heading_case.gd)."""
	matrix_height_u = Contract.QUANTUM_SIDE_U


func test_a_dining_room_at_its_minimum_east_of_its_access_is_dug() -> void:
	"""A Dining room's minimum: four seats' 8 tiles (32 cells), 8 along the wall and 4 deep, east."""
	dig_matrix(EAST, 8, 4, Buildings.ROOM_TYPE_DINING)


func test_a_common_room_at_its_minimum_north_of_its_access_is_dug() -> void:
	"""A Common room's minimum: 8 tiles (32 cells), 8 along the wall and 4 deep, north."""
	dig_matrix(NORTH, 8, 4, Buildings.ROOM_TYPE_COMMON)
