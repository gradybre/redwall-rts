extends "res://test/underground_flight_case.gd"
## Decision 2045: the whole M5 flight's segment 9, tick 50000 to tick 55000, restored along the way (underground_flight_case.gd).


func test_segment_09_restored_along_the_way_saves_as_the_uninterrupted_flight() -> void:
	"""From tick 50000 to tick 55000: the runtime and route owners restored on their periods, the save there equals the committed
	underground_flight checkpoint byte for byte."""
	_assert_flight_segment(9)
