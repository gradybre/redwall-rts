extends "res://test/framework/test_case.gd"
## The bursts spread (decision 1003): the kitchen's call to a meal (kitchen.gd THE CALL IS SPREAD) and dusk's sending
## to bed (night_routine.gd DUSK IS SPREAD) put at most their per-frame count of residents on the routing desk a frame,
## in their order, until everyone is called or sent; and the bedless's places at the hall's door are counted once, as the
## count of those before each. No scene tree, no assets.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const COUNT: int = 21
const HALL: Vector2 = Vector2(-2.0, -7.0)

var _brains: Array[BrainScript] = []


func after_each() -> void:
	"""Let go of the residents' jobs: an unfinished kitchen job holds the kitchen, which holds the residents."""
	for brain: BrainScript in _brains:
		brain.drop_jobs()
	_brains.clear()


func _residents(space: CastSpaceScript) -> Array[BrainScript]:
	"""COUNT residents in rows on open ground, on the space's network as mice."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brains: Array[BrainScript] = []
	for i in COUNT:
		var brain := BrainScript.new()
		brain.configure(space, 1.0, 0.25, 31 + i, lengths)
		brain.start_at(Vector2(-6.0 + 1.2 * float(i % 10), 2.0 + 1.2 * floorf(float(i) / 10.0)), 0.0, -1, -1)
		space.tunnels.set_body(brain.index, 1024, 256)
		brains.append(brain)
	_brains.append_array(brains)
	return brains


func _space() -> CastSpaceScript:
	"""Open ground with the hall's steps."""
	var space := CastSpaceScript.new()
	space.setup([{"name": NightScript.HALL_POI, "position": Vector3(HALL.x, 0.0, HALL.y), "capacity": 4}],
		[] as Array[Vector3])
	return space


func _names(count: int) -> PackedStringArray:
	"""Residents' names."""
	var out := PackedStringArray()
	for i in count:
		out.append("resident %d" % i)
	return out


# --- the kitchen's call ------------------------------------------------------------------------------

func _kitchen_at_breakfast(brains: Array[BrainScript], calendar: CalendarScript) -> KitchenScript:
	"""A kitchen over these residents with breakfast's portions out on the table, the calendar just before its call."""
	var kitchen := KitchenScript.new()
	var places := PlacesScript.new()
	places.set_points(Vector2(6.0, 0.0), Vector2(3.0, -3.0), Vector2(0.0, 4.0), Vector2(1.5, 4.5))
	places.add_table_seats(Vector2(3.0, -3.0), PlacesScript.SEATS_PER_TABLE)
	var keys: Array[StringName] = []
	var kinds := PackedStringArray()
	for i in brains.size():
		keys.append(&"mouse_keeper" if i == 0 else StringName("mouse_%d" % i))
		kinds.append("mouse")
	calendar.tick = (SimClock.HOURS_PER_DAY + Rules.CALL_HOUR[Rules.MEAL_BREAKFAST]) * SimClock.TICKS_PER_HOUR \
			- SimClock.CALENDAR_OFFSET_TICKS - 1
	kitchen.configure(brains, _names(brains.size()), kinds, keys, PantryScript.new(StorageScript.new(Vector2(8.5, 0.5))),
		StoresScript.new(), calendar, places)
	kitchen.store.add(Rules.DISH_PORRIDGE, 2 * COUNT, Rules.meal_key(1, Rules.MEAL_BREAKFAST))
	return kitchen


func _diners(kitchen: KitchenScript) -> PackedInt32Array:
	"""Who the kitchen has called to eat."""
	var out := PackedInt32Array()
	for i in COUNT:
		if kitchen.role_of(i) == KitchenScript.ROLE_EAT:
			out.append(i)
	return out


func test_the_call_to_a_meal_calls_at_most_its_count_a_frame_in_order() -> void:
	"""THE CALL IS SPREAD: 21 residents at breakfast's call, the cook (resident 0) busy with the pot: of the 20 free, 8
	on the call's frame (the first eight), 8 on the next, the last 4 on the one after -- every one called, none twice,
	in their order."""
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var kitchen := _kitchen_at_breakfast(brains, calendar)
	var called: Array[int] = []
	for frame in 6:
		calendar.tick += 1
		kitchen.update()
		called.append(_diners(kitchen).size())
	var first := called.find(KitchenScript.CALLS_PER_FRAME)
	assert_true(first >= 0, "a first pass calls CALLS_PER_FRAME (%s)" % [called])
	assert_equal(called.slice(first, first + 3), [8, 16, COUNT - 1] as Array[int], "then the next eight, then the rest")
	assert_equal(_diners(kitchen), PackedInt32Array(range(1, COUNT)), "everyone free, each once")
	assert_false(kitchen._calling_on, "nobody left to call")


func test_a_call_within_its_count_calls_everyone_at_once() -> void:
	"""Eight or fewer to call (the cook and eight others): all on the call's frame, as before the spread."""
	var space := _space()
	var brains := _residents(space).slice(0, KitchenScript.CALLS_PER_FRAME + 1)
	var calendar := CalendarScript.new()
	var kitchen := _kitchen_at_breakfast(brains, calendar)
	var most := 0
	for frame in 4:
		calendar.tick += 1
		kitchen.update()
		var now := 0
		for i in brains.size():
			now += 1 if kitchen.role_of(i) == KitchenScript.ROLE_EAT else 0
		if now > 0 and most == 0:
			most = now
	assert_equal(most, KitchenScript.CALLS_PER_FRAME, "all eight on the one frame")


# --- dusk -------------------------------------------------------------------------------------------

func _night(space: CastSpaceScript, brains: Array[BrainScript], calendar: CalendarScript) -> NightScript:
	"""The night over these residents with no beds (all to the hall), the calendar at dusk's tick."""
	var night := NightScript.new()
	var heights := PackedInt32Array()
	heights.resize(brains.size())
	heights.fill(1024)
	night.configure(space.tunnels, brains, _names(brains.size()), heights, calendar, null)
	night.set_alarm(func() -> bool: return false)
	night.set_hall(HALL)
	calendar.tick = (NightScript.DUSK_HOUR - 6) * SimClock.TICKS_PER_HOUR
	return night


func _sleepers(brains: Array[BrainScript]) -> int:
	"""How many have a sleep task."""
	var n := 0
	for brain in brains:
		n += 1 if brain.task is SleepTaskScript else 0
	return n


func test_dusk_sends_at_most_its_count_a_frame_in_order() -> void:
	"""DUSK IS SPREAD: 21 residents at dusk: 8 sent on dusk's frame (the first eight), 8 on the next, the last 5 on the
	one after; nobody is sent twice."""
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var night := _night(space, brains, calendar)
	var sent: Array[int] = []
	for frame in 4:
		night.step()
		sent.append(_sleepers(brains))
	assert_equal(sent, [8, 16, COUNT, COUNT] as Array[int], "eight a frame, then the rest")
	for i in NightScript.SENDS_PER_FRAME:
		assert_true(brains[i].task is SleepTaskScript, "the first eight first (%d)" % i)
	assert_equal(night._dusk_next, -1, "dusk's sending done")


func test_through_the_night_the_free_are_sent_at_most_their_count_a_frame() -> void:
	"""After dusk, everyone released at once is sent back to bed at most SENDS_PER_FRAME a frame."""
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var night := _night(space, brains, calendar)
	for frame in 3:
		night.step()
	for brain in brains:
		brain.release()
	calendar.tick += NightScript.RESEND_TICKS
	night.step()
	assert_equal(_sleepers(brains), NightScript.SENDS_PER_FRAME, "eight back to bed this frame")
	night.step()
	assert_equal(_sleepers(brains), 2 * NightScript.SENDS_PER_FRAME, "eight more the next")


func test_a_bedless_place_at_the_door_is_its_count_of_bedless_before_it() -> void:
	"""`hall_spot`: each resident's place is the count of bedless residents before it (the old count's), and follows the
	beds when they change -- however they are written."""
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var night := _night(space, brains, calendar)
	night.bed_of.fill(AllocationScript.NO_BED)
	night.bed_of[1] = 8
	night.bed_of[4] = 9
	for i in COUNT:
		var before := 0
		for j in i:
			before += 1 if night.bed_of[j] == AllocationScript.NO_BED else 0
		var spot := HALL + Vector2(NightScript.HALL_SPACING_M * float(before % 5 - 2), 0.0)
		assert_equal(night.hall_spot(i), spot, "resident %d: after %d bedless" % [i, before])
	night.bed_of[0] = 10
	assert_equal(night.hall_spot(2), HALL + Vector2(NightScript.HALL_SPACING_M * -2.0, 0.0), "a bed given: recounted")


# --- SERVED AS IT IS COOKED and the wait spots (decision 1005) ------------------------------------------------------

func test_the_pot_goes_out_while_its_meal_is_served_and_the_table_is_empty() -> void:
	"""`_serve_early`: the meal being served with portions in the pot and none at the table: out now; with portions
	still at the table, or between meals: not yet."""
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var kitchen := _kitchen_at_breakfast(brains, calendar)
	assert_false(kitchen._serve_early(), "before the call: nothing is being served")
	calendar.tick += 1
	kitchen.update()
	assert_true(kitchen._serving != KitchenScript.FREE and kitchen._serve_early(), "called, pot full, table empty: out")
	kitchen.store.carry_out()
	kitchen.store.add(Rules.DISH_PORRIDGE, 2, Rules.meal_key(1, Rules.MEAL_BREAKFAST))
	assert_false(kitchen._serve_early(), "portions still at the table: the cook cooks on")


func test_a_diner_without_a_seat_waits_off_the_cooks_spot() -> void:
	"""The wait spots: every table has WAIT_SPOTS_PER_TABLE of them beyond its seats, none in its serving gap; a diner
	with no seat waits at one, never at the cook's spot by the table."""
	var places := PlacesScript.new()
	places.set_points(Vector2(6.0, 0.0), Vector2(3.0, -3.0), Vector2(0.0, 4.0), Vector2(1.5, 4.5))
	places.add_table_seats(Vector2(3.0, -3.0), PlacesScript.SEATS_PER_TABLE)
	assert_equal(places.wait_spots.size(), PlacesScript.WAIT_SPOTS_PER_TABLE, "a ring of them")
	var toward := (Vector2(6.0, 0.0) - Vector2(3.0, -3.0)).angle()
	for spot in places.wait_spots:
		assert_true(absf(angle_difference(toward, (spot - Vector2(3.0, -3.0)).angle())) >= PlacesScript.SERVING_GAP / 2.0 - 1e-3,
			"out of the serving gap")
		assert_almost_equal(spot.distance_to(Vector2(3.0, -3.0)), PlacesScript.SEAT_RING_M + PlacesScript.WAIT_RING_GAP_M,
			"beyond the seats")
	var space := _space()
	var brains := _residents(space)
	var calendar := CalendarScript.new()
	var kitchen := _kitchen_at_breakfast(brains, calendar)
	kitchen._seat.fill(0)
	kitchen._seat[20] = -1
	var w: int = kitchen.places.wait_spot(20)
	assert_equal(kitchen._diner_spot(20), kitchen.places.wait_spots[w], "the seatless diner's wait spot")
	assert_true(kitchen._diner_spot(20) != kitchen.places.stand_table, "not the cook's spot")
	assert_equal(kitchen._face_of_seat(20), kitchen.places.wait_face[w], "facing its table")
	var bare := PlacesScript.new()
	assert_equal(bare.wait_spot(3), -1, "no wait spots: none (the cook's spot, as before)")


func test_a_trip_with_no_route_waits_before_it_plans_again() -> void:
	"""NO WAY YET: a walk whose plan found no route is not planned again until NO_ROUTE_RETRY_S has passed."""
	var space := CastSpaceScript.new()
	var circles: Array[Vector3] = []
	for k in 12:
		var angle := TAU * float(k) / 12.0
		circles.append(Vector3(cos(angle) * 3.0, 0.9, sin(angle) * 3.0))
	space.setup([], circles)
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(space, 1.0, 0.25, 9, lengths)
	brain.start_at(Vector2(-8.0, 0.0), 0.0, -1, -1)
	_brains.append(brain)
	brain.order_move(Vector2.ZERO)
	assert_equal(brain._no_route_s, 0.0, "no way into the ring: waiting to plan again")
	var replans := brain._replans
	for f in roundi(BrainScript.NO_ROUTE_RETRY_S * 0.5 * 60.0):
		brain.step(1.0 / 60.0)
	assert_equal(brain._replans, replans, "no replan within the wait")
