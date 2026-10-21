extends "res://test/framework/test_case.gd"
## Decision 2091 (phase 1): the stair leg helper's pure plans on M5's full stop set. The loaded way down from H to a
## landing's F' (approach, eight descents, walk-off a module, the loaded join F' -> H' between modules), the optional
## ground legs from a source stand and to a destination stand, and the empty way back up through every landing's
## turning spot R'. The live graph checks are `test_underground_stair_legs_live.gd`.

const Legs := preload("res://scripts/core/underground_stair_legs.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const StairPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const M5StairPath := preload("res://test/test_underground_m5_stair_path.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SOURCE_STAND: Vector2i = Vector2i(900, 3)
const DESTINATION_STAND: Vector2i = Vector2i(901, 4)


func _wood() -> int:
	"""The compiled wood item the grip certificate carries."""
	return Grip.item_of(Grip.carry_of(0))


func _stone() -> int:
	"""The compiled stone item the grip certificate carries."""
	return Grip.item_of(Grip.carry_of(1))


func _stops() -> StairPath.Stops:
	"""Every stop live, each with its own handle (the M5 stair path suite's fixture)."""
	return M5StairPath.new()._full_stops()


func _rows(legs: PackedInt32Array) -> Dictionary:
	"""How many legs each row takes."""
	var out: Dictionary = {}
	for leg: int in Legs.leg_count(legs):
		var row: int = Legs.row_of(legs, leg)
		out[row] = int(out.get(row, 0)) + 1
	return out


func _chained(legs: PackedInt32Array) -> bool:
	"""Each leg starts where the one before it ended."""
	for leg: int in range(1, Legs.leg_count(legs)):
		if Legs.from_of(legs, leg) != Legs.to_of(legs, leg - 1): return false
	return true


func test_the_stair_rows_follow_the_items_grip_family() -> void:
	"""Wood takes the wood carry rows 73-78, stone 79-84; an item the grip certificate does not carry takes none."""
	assert_equal(Legs.stair_rows(_wood()), StairPins.STAIR_CARRY_WOOD_ROWS, "wood")
	assert_equal(Legs.stair_rows(_stone()), StairPins.STAIR_CARRY_STONE_ROWS, "stone")
	assert_equal(Legs.stair_rows(-1), PackedInt32Array(), "no item")
	assert_true(Grip.carry_row_for(_wood() + _stone() + 1) < 0, "the probe item is uncertified")
	assert_equal(Legs.stair_rows(_wood() + _stone() + 1), PackedInt32Array(), "an uncertified item")


func test_wood_goes_down_all_five_modules_in_fifty_four_legs() -> void:
	"""H to level 1's F': ten legs on module 0, eleven on each later one (the join first); 73 ten times (five approaches
	and five walk-offs), 74 forty times (eight descents a module), the ground carry 32 four times."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	assert_equal(Legs.loaded_down_into(stops, _wood(), StairPath.MODULES, legs), &"", "planned")
	assert_equal(Legs.leg_count(legs), 54, "legs")
	assert_true(_chained(legs), "chained")
	assert_equal(Legs.from_of(legs, 0), stops.h, "from H")
	assert_equal(Legs.to_of(legs, 53), stops.fp[StairPath.MODULES], "to level 1's F'")
	assert_equal(_rows(legs), {73: 10, 74: 40, Grip.carry_of(0): 4}, "rows")


func test_stone_takes_its_own_rows() -> void:
	"""The same way on 79, 80 and the stone ground carry 37."""
	var legs: PackedInt32Array = PackedInt32Array()
	assert_equal(Legs.loaded_down_into(_stops(), _stone(), StairPath.MODULES, legs), &"", "planned")
	assert_equal(_rows(legs), {79: 10, 80: 40, Grip.carry_of(1): 4}, "rows")


func test_module_one_is_module_zero_shifted_behind_its_join() -> void:
	"""Legs 10-20: F'(1) -> H'(1) on 32, H'(1) -> A0' on 73, seven descents to module 1's sill, onto F(2), the walk-off."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	Legs.loaded_down_into(stops, _wood(), 2, legs)
	assert_equal(Legs.leg_count(legs), 21, "two modules")
	var top: int = StairPath.global_level(1, -1) + 1
	var expected: Array = [[stops.fp[1], stops.hm[1], 32], [stops.hm[1], stops.a[top], 73]]
	for step: int in 7:
		expected.append([stops.a[top + step], stops.a[top + step + 1], 74])
	expected.append_array([[stops.a[top + 7], stops.f[2], 74], [stops.f[2], stops.fp[2], 73]])
	for at: int in expected.size():
		var leg: int = 10 + at
		assert_equal([Legs.from_of(legs, leg), Legs.to_of(legs, leg), Legs.row_of(legs, leg)], expected[at], "leg %d" % leg)


func test_module_zero_ends_its_descents_on_landing_one() -> void:
	"""Legs 0-9: H -> A(L0), A(L0) -> A(T0) ... A(T5) -> A(T6), the sill onto F(1), F(1) -> F'(1)."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	assert_equal(Legs.loaded_down_into(stops, _wood(), 1, legs), &"", "planned")
	assert_equal(Legs.leg_count(legs), 10, "one module")
	assert_equal([Legs.from_of(legs, 0), Legs.to_of(legs, 0)], [stops.h, stops.a[0]], "the approach")
	assert_equal([Legs.from_of(legs, 7), Legs.to_of(legs, 7)], [stops.a[6], stops.a[7]], "onto the sill")
	assert_equal([Legs.from_of(legs, 8), Legs.to_of(legs, 8), Legs.row_of(legs, 8)], [stops.a[7], stops.f[1], 74],
		"onto the floor")
	assert_equal([Legs.from_of(legs, 9), Legs.to_of(legs, 9), Legs.row_of(legs, 9)], [stops.f[1], stops.fp[1], 73],
		"the walk-off")


func test_each_landing_adds_eleven_legs() -> void:
	"""Down to landing j: 10 + 11 (j - 1) legs."""
	var legs: PackedInt32Array = PackedInt32Array()
	for landing: int in range(1, StairPath.MODULES + 1):
		assert_equal(Legs.loaded_down_into(_stops(), _wood(), landing, legs), &"", "landing %d" % landing)
		assert_equal(Legs.leg_count(legs), 10 + 11 * (landing - 1), "landing %d" % landing)


func test_stands_add_the_two_ground_legs() -> void:
	"""A source stand comes first (to H) and a destination stand last (from the landing's F'), on the ground carry."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	assert_equal(Legs.loaded_down_into(stops, _stone(), 5, legs, SOURCE_STAND, DESTINATION_STAND), &"", "planned")
	assert_equal(Legs.leg_count(legs), 56, "legs")
	assert_true(_chained(legs), "chained")
	assert_equal([Legs.from_of(legs, 0), Legs.to_of(legs, 0), Legs.row_of(legs, 0)], [SOURCE_STAND, stops.h, 37], "first")
	assert_equal([Legs.from_of(legs, 55), Legs.to_of(legs, 55), Legs.row_of(legs, 55)],
		[stops.fp[5], DESTINATION_STAND, 37], "last")
	assert_equal(Legs.loaded_down_into(stops, _stone(), 5, legs, SOURCE_STAND), &"", "source only")
	assert_equal(Legs.leg_count(legs), 55, "source only")


func test_a_missing_stop_refuses_and_leaves_no_legs() -> void:
	"""Any stop of the way not live refuses STAIR_LEGS_STOP with an empty list; a stop past the target is not read."""
	var legs: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5])
	var stops: StairPath.Stops = _stops()
	stops.hm[3] = NULL_REF
	assert_equal(Legs.loaded_down_into(stops, _wood(), 5, legs), Legs.REFUSE_STOP, "H'(3)")
	assert_equal(legs.size(), 0, "no legs")
	assert_equal(Legs.loaded_down_into(stops, _wood(), 3, legs), &"", "H'(3) is past landing 3")
	stops = _stops()
	stops.f[2] = NULL_REF
	assert_equal(Legs.loaded_down_into(stops, _wood(), 2, legs), Legs.REFUSE_STOP, "F(2)")
	stops = _stops()
	stops.a[3] = NULL_REF
	assert_equal(Legs.loaded_down_into(stops, _wood(), 1, legs), Legs.REFUSE_STOP, "a tread")
	stops = _stops()
	stops.h = NULL_REF
	stops.hm[0] = NULL_REF
	assert_equal(Legs.loaded_down_into(stops, _wood(), 1, legs), Legs.REFUSE_STOP, "H")
	assert_equal(Legs.loaded_down_into(stops, _wood(), 1, legs, SOURCE_STAND), Legs.REFUSE_STOP, "H from a stand")


func test_bad_items_and_landings_refuse() -> void:
	"""An uncertified item, a landing outside 1..5 or no stops refuses before any leg is planned."""
	var legs: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5])
	assert_equal(Legs.loaded_down_into(_stops(), -1, 5, legs), Legs.REFUSE_ITEM, "item")
	assert_equal(legs.size(), 0, "cleared")
	assert_equal(Legs.loaded_down_into(_stops(), _wood(), 0, legs), Legs.REFUSE_LANDING, "landing 0")
	assert_equal(Legs.loaded_down_into(_stops(), _wood(), StairPath.MODULES + 1, legs), Legs.REFUSE_LANDING, "landing 6")
	assert_equal(Legs.loaded_down_into(null, _wood(), 1, legs), Legs.REFUSE_LANDING, "no stops")
	assert_equal(Legs.empty_up_into(_stops(), 0, legs), Legs.REFUSE_LANDING, "up from landing 0")
	assert_equal(Legs.empty_up_into(_stops(), StairPath.MODULES + 1, legs), Legs.REFUSE_LANDING, "up from landing 6")
	assert_equal(Legs.empty_up_into(null, 1, legs), Legs.REFUSE_LANDING, "up with no stops")


func test_the_empty_way_up_from_level_one_takes_fifty_nine_legs() -> void:
	"""F'(5) to X: on each landing the back-up 72 and the floor half-turn 55, eight ascents 54 a module, R' on 45 then
	F' on 47 at landings 4..1, and 45 onto X at the top."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	assert_equal(Legs.empty_up_into(stops, StairPath.MODULES, legs), &"", "planned")
	assert_equal(Legs.leg_count(legs), 59, "legs")
	assert_true(_chained(legs), "chained")
	assert_equal(Legs.from_of(legs, 0), stops.fp[5], "from F'(5)")
	assert_equal(Legs.to_of(legs, 58), stops.x, "to X")
	assert_equal(_rows(legs), {72: 5, 55: 5, 54: 40, 45: 5, 47: 4}, "rows")
	assert_equal([Legs.to_of(legs, 10), Legs.row_of(legs, 10)], [stops.d[4], 45], "R' on landing 4")
	assert_equal([Legs.to_of(legs, 11), Legs.row_of(legs, 11)], [stops.fp[4], 47], "back to F'(4)")


func test_the_empty_way_up_is_the_stair_paths_own() -> void:
	"""Every landing's way up is `StairPath.hops_up_from_walk_off` from its F', leg for leg."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	for landing: int in range(1, StairPath.MODULES + 1):
		Legs.empty_up_into(stops, landing, legs)
		var hops: Array = StairPath.hops_up_from_walk_off(stops, landing)
		assert_equal(Legs.leg_count(legs), hops.size(), "landing %d" % landing)
		for leg: int in hops.size():
			assert_equal([Legs.to_of(legs, leg), Legs.row_of(legs, leg)], [hops[leg][0], hops[leg][1]],
				"landing %d leg %d" % [landing, leg])


func test_a_missing_stop_on_the_way_up_refuses() -> void:
	"""R' (D) gone on landing 2, or the start F' gone, refuses STAIR_LEGS_STOP with an empty list."""
	var legs: PackedInt32Array = PackedInt32Array()
	var stops: StairPath.Stops = _stops()
	stops.d[2] = NULL_REF
	assert_equal(Legs.empty_up_into(stops, 5, legs), Legs.REFUSE_STOP, "R'(2)")
	assert_equal(legs.size(), 0, "no legs")
	assert_equal(Legs.empty_up_into(stops, 1, legs), &"", "landing 1 does not pass landing 2")
	stops = _stops()
	stops.fp[3] = NULL_REF
	assert_equal(Legs.empty_up_into(stops, 3, legs), Legs.REFUSE_STOP, "F'(3)")


func test_leg_words_read_back() -> void:
	"""A leg's stops and row read back from its five words."""
	var legs: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 74, 3, 4, 5, 6, 73])
	assert_equal(Legs.leg_count(legs), 2, "count")
	assert_equal([Legs.from_of(legs, 1), Legs.to_of(legs, 1), Legs.row_of(legs, 1)],
		[Vector2i(3, 4), Vector2i(5, 6), 73], "second leg")
