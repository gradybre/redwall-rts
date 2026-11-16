extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): each room type at the GDD's minimum floor
## area (a tile is 2 x 2 cells), each on a different side of the access.


func _init() -> void:
	"""The floor band only (`matrix_height_u`, room_heading_case.gd)."""
	matrix_height_u = Contract.QUANTUM_SIDE_U


func test_a_pantry_at_its_minimum_south_of_its_access_is_dug() -> void:
	"""A Pantry's minimum: 4 tiles (16 cells), 4 by 4, south."""
	dig_matrix(SOUTH, 4, 4, Buildings.ROOM_TYPE_PANTRY)


func test_a_kitchen_at_its_minimum_west_of_its_access_is_dug() -> void:
	"""A Kitchen's minimum: 6 tiles (24 cells), 4 along the wall and 6 deep, west."""
	dig_matrix(WEST, 4, 6, Buildings.ROOM_TYPE_KITCHEN)


func test_a_bedroom_at_its_minimum_north_of_its_access_is_dug() -> void:
	"""A Bedroom's minimum: 6 tiles (24 cells), 6 along the wall and 4 deep, north."""
	dig_matrix(NORTH, 6, 4, Buildings.ROOM_TYPE_PRIVATE_ROOM)
