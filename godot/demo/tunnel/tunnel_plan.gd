extends RefCounted
## The tunnel route a player is laying out, click by click. Decision 0196 (live demo). Pure data:
## tunnel_control.gd feeds it clicks and draws it; the tests drive it directly.
##
## The first point is the entrance, each further one a bend, and the last the exit. A point is
## checked as it is laid (tunnel_rules.validate_point: the limit, the bounds, the entrance's
## clearance) and refused outright if it fails; the whole route is checked again on confirming
## (validate_route: the exit's clearance and the length too). Points are integer u.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

## (x, z) pairs in u; sized once for MAX_POINTS.
var points_u: PackedInt32Array = PackedInt32Array()
var count: int = 0


func _init() -> void:
	"""Size the points once."""
	points_u.resize(Rules.MAX_POINTS * 2)


func clear() -> void:
	"""Start a new route."""
	count = 0


func try_add(x_u: int, z_u: int, bounds_u: Rect2i, circles_u: PackedInt32Array) -> int:
	"""Lay the next point, or refuse it: returns REFUSE_NONE when it was added, else the reason."""
	var reason := Rules.validate_point(x_u, z_u, count, bounds_u, circles_u)
	if reason != Rules.REFUSE_NONE:
		return reason
	points_u[2 * count] = x_u
	points_u[2 * count + 1] = z_u
	count += 1
	return Rules.REFUSE_NONE


func undo() -> bool:
	"""Take back the last point. False when there was none to take."""
	if count == 0:
		return false
	count -= 1
	return true


func route_reason(bounds_u: Rect2i, circles_u: PackedInt32Array) -> int:
	"""REFUSE_NONE when the route as laid may be dug, else why not."""
	return Rules.validate_route(points_u, count, bounds_u, circles_u)


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
	"""A length in u as the panel shows it: metres to one decimal, e.g. "12.4 m"."""
	var tenths := (length_u_value * 10 + Rules.UNITS_PER_M / 2) / Rules.UNITS_PER_M
	return "%d.%d m" % [tenths / 10, tenths % 10]
