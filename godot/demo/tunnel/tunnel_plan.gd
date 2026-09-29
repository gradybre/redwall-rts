extends RefCounted
## The tunnel route a player is laying out, click by click. Decision 0196 (live demo). Pure data:
## tunnel_control.gd feeds it clicks and draws it; the tests drive it directly.
##
## The first point is the entrance, each further one a bend, and the last the exit. A point is
## checked as it is laid (tunnel_rules.validate_point: the limit, the bounds, the entrance's
## clearance; and here, its gap from the last point and whether the new leg runs under a building)
## and refused outright if it fails; the whole route is checked again on confirming (validate_route:
## the exit's clearance and the length too). Points are integer u.
##
## WATER. No bore may pass under water: every point and every leg is asked `water_crossing(a, b,
## clearance_u)` -- the village's water adapter (demo/village_water.gd `crosses_water`, the real
## map's `segment_crosses_water`) -- with half a bore of clearance, and refused REFUSE_UNDER_WATER.
## A point in the water is refused so before its bounds, so a click on the stream says why.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

## (x, z) pairs in u; sized once for MAX_POINTS.
var points_u: PackedInt32Array = PackedInt32Array()
var count: int = 0
## `(a: Vector2i, b: Vector2i, clearance_u: int) -> bool`: whether a bore a-b meets water (see WATER;
## unset: no water anywhere).
var water_crossing: Callable = Callable()


func _init() -> void:
	"""Size the points once."""
	points_u.resize(Rules.MAX_POINTS * 2)


func clear() -> void:
	"""Start a new route."""
	count = 0


func try_add(x_u: int, z_u: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array(), under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""Lay the next point, or refuse it: returns REFUSE_NONE when it was added, else the reason. The
	point is written in place first and only counted once every check passes."""
	if _meets_water(Vector2i(x_u, z_u), Vector2i(x_u, z_u)):
		return Rules.REFUSE_UNDER_WATER
	var reason := Rules.validate_point(x_u, z_u, count, bounds_u, circles_u, spots_u)
	if reason != Rules.REFUSE_NONE:
		return reason
	points_u[2 * count] = x_u
	points_u[2 * count + 1] = z_u
	if count > 0 and Rules.points_too_close(points_u, count):
		return Rules.REFUSE_REPEATED_POINT
	if count > 0 and Rules.leg_under(points_u, count, under_u):
		return Rules.REFUSE_UNDER_BUILDING
	if count > 0 and _leg_meets_water(count):
		return Rules.REFUSE_UNDER_WATER
	count += 1
	return Rules.REFUSE_NONE


func _meets_water(a: Vector2i, b: Vector2i) -> bool:
	"""Whether a bore from a to b (u) would pass under water (see WATER)."""
	return water_crossing.is_valid() and bool(water_crossing.call(a, b, Rules.BORE_WIDTH_U / 2))


func _leg_meets_water(k: int) -> bool:
	"""Whether the leg into point `k` would pass under water."""
	return _meets_water(Vector2i(points_u[2 * k - 2], points_u[2 * k - 1]), Vector2i(points_u[2 * k], points_u[2 * k + 1]))


func undo() -> bool:
	"""Take back the last point. False when there was none to take."""
	if count == 0:
		return false
	count -= 1
	return true


func route_reason(bounds_u: Rect2i, circles_u: PackedInt32Array, spots_u: PackedInt32Array = PackedInt32Array(),
		under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""REFUSE_NONE when the route as laid may be dug, else why not (the rules', then water)."""
	var reason := Rules.validate_route(points_u, count, bounds_u, circles_u, spots_u, under_u)
	if reason != Rules.REFUSE_NONE:
		return reason
	for k in range(1, count):
		if _leg_meets_water(k):
			return Rules.REFUSE_UNDER_WATER
	return Rules.REFUSE_NONE


func length_u() -> int:
	"""The route's length so far, in u."""
	return Rules.route_length_u(points_u, count)


func length_to_u(x_u: int, z_u: int) -> int:
	"""The route's length if a point at (x_u, z_u) were laid next (the preview under the pointer)."""
	if count == 0:
		return 0
	var dx := x_u - points_u[2 * count - 2]
	var dz := z_u - points_u[2 * count - 1]
	return length_u() + Rules.isqrt(dx * dx + dz * dz)


func point_m(k: int) -> Vector2:
	"""Point `k` in metres (x, z), for drawing."""
	return Vector2(Rules.to_m(points_u[2 * k]), Rules.to_m(points_u[2 * k + 1]))


static func length_text(length_u_value: int) -> String:
	"""A length in u as the panel shows it: metres to one decimal, e.g. "12.4 m". Rounded to the
	nearest tenth -- except that a length the limits refuse is rounded AWAY from the limit, so a
	refused 1.99 m never reads "2.0 m" and a refused 64.04 m never reads "64.0 m"."""
	var tenths := (length_u_value * 10 + Rules.UNITS_PER_M / 2) / Rules.UNITS_PER_M
	if length_u_value < Rules.MIN_LENGTH_U:
		tenths = length_u_value * 10 / Rules.UNITS_PER_M
	elif length_u_value > Rules.MAX_LENGTH_U:
		tenths = Rules.ceil_div(length_u_value * 10, Rules.UNITS_PER_M)
	return "%d.%d m" % [tenths / 10, tenths % 10]
