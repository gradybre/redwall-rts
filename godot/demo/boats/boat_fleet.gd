extends RefCounted
## THE BOAT CORE: the village's boats as integer rows -- where each is along its course, which way it is going, who
## crews it, what it carries and how worn it is. Decision 0432 (live demo, water part B). Presentation-moved: a boat is
## no physics body and no node of its own (boat_view.gd draws every boat from these rows); nothing here writes into
## the settlement simulation.
##
## A BOAT ROW (structure of arrays, BERTH_COUNT rows -- the boathouse keeps two):
##   phase       MOORED at its berth; OUT along its course; ON_STATION at the course's end; BACK to its berth
##   course      the polyline it is rowing (u), berth first: a fixed route (boat_routes.gd ROUTES) or a rescue's leg
##   progress_u  how far along the course it is, whole u; the remainder of a frame's row is carried in micro-u
##   crew        up to SEATS residents (-1: empty seat); seat 0 is the HELM
##   owner       whose the boat is while out (a trip's or a rescue's serial; 0: nobody)
##   durability  §5.4's installed boat gear, 0..1000, worn 15 a fishing cycle; no boat sets out below its wear
##   cargo       the catch aboard (item, milli-U), for the view and the panel: the trip's books own it
## Speed is ROW_SPEED_U_S whatever the crew (DEMO), on the demo clock: paused, the boats stop; at 4x they row four times
## as fast. The ferry and regatta lane reuses this: a course is any validated water polyline from a berth. A RACE
## (decision 0438, the regatta) alone sets a boat's `pace_permille` above 1000 for its crew -- presentation of a
## deterministic result; every other row rows at 1000 (exactly ROW_SPEED_U_S).

const Routes := preload("res://demo/boats/boat_routes.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")

const PHASE_MOORED: int = 0
const PHASE_OUT: int = 1
const PHASE_ON_STATION: int = 2
const PHASE_BACK: int = 3
const PHASE_WORDS: Array[String] = ["moored", "rowing out", "on station", "rowing back"]
const SEATS: int = 2
const HELM: int = 0
const NOBODY: int = -1
## Rowing speed (DEMO: 0.8 m/s, a little faster than a mouse walks), micro-u per demo microsecond scale.
const ROW_SPEED_U_S: int = 819
const USEC_PER_SECOND: int = 1000000
## §5.4: boat durability 0..1000, wear 15 a cycle (fishing_driver.gd WEAR_PER_CYCLE[boat]).
const DURABILITY_CAP: int = 1000
const WEAR_PER_CYCLE: int = 15
## Seats along the hull from its centre (m, + toward the bow): the helm aft, the second forward (presentation).
const SEAT_ALONG_M: Array[float] = [-0.75, 0.55]
const NO_ITEM: int = -1
## A boat's ordinary pace, per mille of ROW_SPEED_U_S (see `pace_permille`).
const PACE_NORMAL: int = 1000

var count: int = Routes.BERTH_COUNT
var phase: PackedInt32Array = PackedInt32Array()
var course: Array[PackedInt32Array] = []
var course_len_u: PackedInt32Array = PackedInt32Array()
var progress_u: PackedInt32Array = PackedInt32Array()
var crew: PackedInt32Array = PackedInt32Array()
var owner: PackedInt32Array = PackedInt32Array()
var durability: PackedInt32Array = PackedInt32Array()
var cargo_item: PackedInt32Array = PackedInt32Array()
var cargo_milli: PackedInt64Array = PackedInt64Array()
## Per mille of ROW_SPEED_U_S each boat rows at (1000 unless a race set it; decision 0438).
var pace_permille: PackedInt32Array = PackedInt32Array()
## Bumped whenever a boat's phase, crew, owner or wear changes (panels redraw then; positions move every frame).
var revision: int = 0
## Distance every boat has rowed, all told, in u (a tally for tests and the ferry lane's checks).
var rowed_u: int = 0

var _carry: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""BERTH_COUNT boats, each moored at its berth, unworn and unmanned."""
	for column: PackedInt32Array in [phase, course_len_u, progress_u, owner, durability, cargo_item, pace_permille]:
		column.resize(count)
	pace_permille.fill(PACE_NORMAL)
	cargo_milli.resize(count)
	_carry.resize(count)
	crew.resize(count * SEATS)
	crew.fill(NOBODY)
	durability.fill(DURABILITY_CAP)
	cargo_item.fill(NO_ITEM)
	for boat: int in count:
		course.append(Routes.route(boat))
		course_len_u[boat] = Routes.route_length_u(boat)


func is_boat(boat: int) -> bool:
	"""Whether `boat` names a row."""
	return boat >= 0 and boat < count


func is_free(boat: int) -> bool:
	"""Moored and nobody's."""
	return phase[boat] == PHASE_MOORED and owner[boat] == 0


func take(boat: int, serial: int) -> bool:
	"""Make a free boat `serial`'s (a trip or a rescue, > 0). False when it is not free."""
	if not is_boat(boat) or not is_free(boat) or serial <= 0:
		return false
	owner[boat] = serial
	revision += 1
	return true


func give_back(boat: int, serial: int) -> void:
	"""`serial` lets its moored boat go (anyone else's is left alone); its crew seats are emptied."""
	if is_boat(boat) and owner[boat] == serial and phase[boat] == PHASE_MOORED:
		owner[boat] = 0
		for place: int in SEATS:
			crew[boat * SEATS + place] = NOBODY
		cargo_item[boat] = NO_ITEM
		cargo_milli[boat] = 0
		pace_permille[boat] = PACE_NORMAL
		revision += 1


func seat(boat: int, which: int, who: int) -> void:
	"""Put `who` (NOBODY: nobody) in a seat."""
	crew[boat * SEATS + which] = who
	revision += 1


func crew_of(boat: int, which: int) -> int:
	"""Who sits in a seat (NOBODY: empty)."""
	return crew[boat * SEATS + which]


func boat_of_crew(who: int) -> int:
	"""The boat `who` sits in (-1: none)."""
	var k: int = crew.find(who)
	@warning_ignore("integer_division") return k / SEATS if k >= 0 and who != NOBODY else -1


func set_course(boat: int, points: PackedInt32Array, map: WaterMapScript) -> bool:
	"""Give a moored boat a course from its berth (the first point must be the berth; every leg boat water). False,
	nothing changed, otherwise."""
	if not is_boat(boat) or phase[boat] != PHASE_MOORED or points.size() < 4:
		return false
	if Vector2i(points[0], points[1]) != Routes.BERTH_U[boat]:
		return false
	var total: int = 0
	@warning_ignore("integer_division") for k: int in range(1, points.size() / 2):
		var a := Vector2i(points[k * 2 - 2], points[k * 2 - 1])
		var b := Vector2i(points[k * 2], points[k * 2 + 1])
		if map != null and not Routes.leg_is_water(map, a, b):
			return false
		total += Routes.leg_length_u(a, b)
	course[boat] = points.duplicate()
	course_len_u[boat] = total
	return true


func set_off(boat: int) -> bool:
	"""A moored boat with its crew aboard rows out along its course. False when it is not moored."""
	if not is_boat(boat) or phase[boat] != PHASE_MOORED:
		return false
	phase[boat] = PHASE_OUT
	progress_u[boat] = 0
	_carry[boat] = 0
	revision += 1
	return true


func row_back(boat: int) -> void:
	"""A boat out or on station turns for its berth (a moored one stays)."""
	if is_boat(boat) and (phase[boat] == PHASE_OUT or phase[boat] == PHASE_ON_STATION):
		phase[boat] = PHASE_BACK
		_carry[boat] = 0
		revision += 1


func step(usec: int) -> int:
	"""Row every boat out or back by `usec` demo microseconds. Returns a bit per boat that ARRIVED this step (on
	station, or back at its berth -- then MOORED)."""
	var arrived: int = 0
	for boat: int in count:
		if phase[boat] == PHASE_OUT or phase[boat] == PHASE_BACK:
			if _row(boat, usec):
				arrived |= 1 << boat
	return arrived


func _row(boat: int, usec: int) -> bool:
	"""One boat's stroke: whole u along (or back down) its course, the fraction carried. True when it got there."""
	@warning_ignore("integer_division") _carry[boat] += usec * ROW_SPEED_U_S * pace_permille[boat] / PACE_NORMAL
	@warning_ignore("integer_division") var moved: int = _carry[boat] / USEC_PER_SECOND
	_carry[boat] -= moved * USEC_PER_SECOND
	rowed_u += moved
	if phase[boat] == PHASE_OUT:
		progress_u[boat] = mini(course_len_u[boat], progress_u[boat] + moved)
		if progress_u[boat] == course_len_u[boat]:
			phase[boat] = PHASE_ON_STATION
			revision += 1
			return true
		return false
	progress_u[boat] = maxi(0, progress_u[boat] - moved)
	if progress_u[boat] == 0:
		phase[boat] = PHASE_MOORED
		revision += 1
		return true
	return false


func wear(boat: int) -> void:
	"""A completed fishing cycle's §5.4 wear."""
	durability[boat] = maxi(0, durability[boat] - WEAR_PER_CYCLE)
	revision += 1


func can_fish(boat: int) -> bool:
	"""Whether the boat holds a cycle's wear (§5.4: "A cycle cannot start with durability below wear")."""
	return durability[boat] >= WEAR_PER_CYCLE


func mend(boat: int, points: int) -> void:
	"""Restore `points` of durability, clamped at the cap (gear.gd's repair rule)."""
	durability[boat] = mini(DURABILITY_CAP, durability[boat] + points)
	revision += 1


# --- where it is (presentation from the integer state) ----------------------------------------

func position_m(boat: int) -> Vector2:
	"""The boat's centre in metres, along its course at `progress_u`."""
	var points: PackedInt32Array = course[boat]
	var left: int = progress_u[boat]
	@warning_ignore("integer_division") for k: int in range(1, points.size() / 2):
		var a := Vector2i(points[k * 2 - 2], points[k * 2 - 1])
		var b := Vector2i(points[k * 2], points[k * 2 + 1])
		var length: int = Routes.leg_length_u(a, b)
		@warning_ignore("integer_division") if left <= length or k == points.size() / 2 - 1:
			var t: float = clampf(float(left) / float(maxi(length, 1)), 0.0, 1.0)
			return Routes.m_of(a).lerp(Routes.m_of(b), t)
		left -= length
	return Routes.m_of(Vector2i(points[0], points[1]))


func yaw(boat: int) -> float:
	"""The way the bow points (the cast's yaw: atan2(x, z) of the heading): along the leg it is on, the way it is
	going; moored and on station, the way it came."""
	var leg: Vector2 = _leg_dir(boat)
	if phase[boat] == PHASE_BACK:
		leg = -leg
	return atan2(leg.x, leg.y)


func _leg_dir(boat: int) -> Vector2:
	"""The unit direction (outward) of the leg the boat is on."""
	var points: PackedInt32Array = course[boat]
	var left: int = progress_u[boat]
	@warning_ignore("integer_division") var last: int = points.size() / 2 - 1
	for k: int in range(1, last + 1):
		var a := Vector2i(points[k * 2 - 2], points[k * 2 - 1])
		var b := Vector2i(points[k * 2], points[k * 2 + 1])
		if left < Routes.leg_length_u(a, b) or k == last:
			return Vector2(b - a).normalized()
		left -= Routes.leg_length_u(a, b)
	return Vector2(0.0, 1.0)


func seat_m(boat: int, which: int) -> Vector2:
	"""Where a seat is, in metres (along the hull from the boat's centre)."""
	var y: float = yaw(boat)
	return position_m(boat) + Vector2(sin(y), cos(y)) * SEAT_ALONG_M[which]


func moving(boat: int) -> bool:
	"""Whether the boat is under oars."""
	return phase[boat] == PHASE_OUT or phase[boat] == PHASE_BACK


func line_of(boat: int) -> String:
	"""The Boats section's line: "Rowboat 1: rowing out · 940/1000 (62 trips left)" ("The ferry boat: ..." for the ferry's,
	which never fishes, so it shows no trips)."""
	if boat == Routes.FERRY_BOAT:
		return "%s: %s · %d/%d" % [Routes.boat_name(boat), PHASE_WORDS[phase[boat]], durability[boat], DURABILITY_CAP]
	@warning_ignore("integer_division") return "%s: %s · %d/%d (%d trips left)" % [Routes.boat_name(boat), PHASE_WORDS[phase[boat]], durability[boat],
		DURABILITY_CAP, durability[boat] / WEAR_PER_CYCLE]
