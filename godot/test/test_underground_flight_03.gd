extends "res://test/underground_flight_case.gd"
## Decision 2045: the whole M5 flight's segment 3, tick 18000 to tick 24000, restored along the way (underground_flight_case.gd).


func test_segment_03_restored_along_the_way_saves_as_the_uninterrupted_flight() -> void:
	"""From tick 18000 to tick 24000: the runtime and route owners restored on their periods, the save there equals the committed
	underground_flight checkpoint byte for byte."""
	_assert_flight_segment(3)
