extends "res://test/underground_flight_case.gd"
## Decision 2045: the whole M5 flight's segment 17, tick 80000 to tick 82500, restored along the way (underground_flight_case.gd).


func test_segment_17_restored_along_the_way_saves_as_the_uninterrupted_flight() -> void:
	"""From tick 80000 to tick 82500: the runtime and route owners restored on their periods, the save there equals the committed
	underground_flight checkpoint byte for byte."""
	_assert_flight_segment(17)
