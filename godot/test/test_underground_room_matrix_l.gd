extends "res://test/room_heading_case.gd"
## Decision 1943's coverage matrix (the fixture: `room_heading_case.gd`): an L-shaped painted room.


func test_an_l_shaped_kitchen_east_of_its_access_is_dug() -> void:
	"""Four cells deep and two wide along the Corridor wall, with its far end running four cells further north past
	the Corridor's end: that leg is reached only over the room's own dug floor, turning inside the room."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 6:
		for x: int in 4:
			if z < 2 or x >= 2:
				cells.append(x); cells.append(z)
	var run: Dig = dig_matrix(EAST, 6, 4, KITCHEN, false, cells)
	if run != null:
		assert_true(run.peak_published > 3, "an L-shaped chain of more than three stations: %d" % run.peak_published)
