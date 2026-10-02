extends RefCounted
## THE BOAT CORE's fixed geography: the jetty, the moorings and the routes a boat may row. Decision 0432 (live demo,
## water part B). Authored integer data in u (1/1024 m), each row commented in metres; checked against the one water
## map (`validate`, and test_demo_boats.gd), never trusted. Pure data and static functions: the ferry and regatta
## lane adds its own jetties and routes here, in the same shapes.
##
## THE JETTY. The boathouse's own landing (water_layout.gd `boathouse`) lies inside its footprint, where nobody can
## stand (decision 0196, part A's notes), so the boats are worked from a JETTY OUTSIDE IT: on the pond's west bank,
## 1.3 m south of the boathouse's front, running east into the pond. Its LAND end stands on the bank top, a walkable
## point any resident reaches by the ordinary planner; its deck runs out over the water to its END. Boarding and
## landing walk the deck (straight, at its height: presentation); the planner never routes across water through it.
## The boats are KEPT at the boathouse (§5.9: "Boathouse | ... | 2 stored boats; shore line"): two rowboats, each
## moored at its own berth beside the jetty.
##
## ROUTES. A boat moves only along a fixed route (Brendan's ruling for fishing: no free sailing): a polyline of water
## points from its berth to a FISHING STATION and back the same way. Every point and every leg between them is water
## at least BOAT_DRAFT_U deep, sampled every SAMPLE_U (`validate`). A rescue rows a straight leg from the berth to a
## victim, but only one `leg_is_water` passes (rescue isn't fishing; decision 0432).

const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

## A rowboat draws this much water, and keeps this far off any shallower water (DEMO: a 3.2 m rowboat for 1.0 m
## mice, its waterline a third up the hull -- water_dressing.gd's measured float).
const BOAT_DRAFT_U: int = 307            # 0.3 m
const SAMPLE_U: int = 256                # 0.25 m

## The jetty: its land end (on the bank top), its deck end (over water) and the deck's height above the datum (m;
## water_dressing.gd measured the model's deck 0.22 m above the -0.18 m water).
const JETTY_NAME: String = "the boathouse jetty"
const JETTY_LAND_U: Vector2i = Vector2i(20173, 29594)     # 19.7, 28.9
const JETTY_END_U: Vector2i = Vector2i(23552, 29594)      # 23.0, 28.9
const JETTY_DECK_Y_M: float = 0.04

## The berths: where each boat lies moored (its centre; its bow points along its route's first leg), and the deck
## point its crew steps aboard from.
const BERTH_COUNT: int = 2
const BERTH_U: Array[Vector2i] = [
	Vector2i(23142, 31386),      # 22.6, 30.65 -- along the jetty's south side, clear of its 1.7 m deck
	Vector2i(25395, 29594),      # 24.8, 28.9  -- off the jetty's end
]
const BERTH_STEP_U: Array[Vector2i] = [
	Vector2i(23142, 30310),      # 22.6, 29.6  -- the deck's south edge beside it
	Vector2i(23552, 29594),      # 23.0, 28.9  -- the deck's end
]

## The fishing stations (on the pond: the lake habitat) and each berth's route to its station, (x, z) pairs from the
## berth out. The return is the same route reversed.
const STATION_NAMES: Array[String] = ["the pond's middle", "the pond's south reach"]
const ROUTES: Array[Array] = [
	[23142, 31386, 25190, 31949, 28262, 31130],    # 22.6,30.65 -> 24.6,31.2 -> 27.6,30.4
	[25395, 29594, 27034, 31539, 28058, 33997],    # 24.8,28.9  -> 26.4,30.8 -> 27.4,33.2
]


static func route(route_index: int) -> PackedInt32Array:
	"""Route `route_index`'s points (x, z pairs, u) as a packed array, berth first."""
	return PackedInt32Array(ROUTES[route_index])


static func route_point(route_index: int, k: int) -> Vector2i:
	"""Point `k` of route `route_index` (u)."""
	return Vector2i(ROUTES[route_index][k * 2], ROUTES[route_index][k * 2 + 1])


static func route_points(route_index: int) -> int:
	"""How many points route `route_index` has."""
	@warning_ignore("integer_division") return ROUTES[route_index].size() / 2


static func route_length_u(route_index: int) -> int:
	"""Route `route_index`'s length, berth to station, in whole u (each leg's length rounded down)."""
	var total: int = 0
	for k: int in range(1, route_points(route_index)):
		total += leg_length_u(route_point(route_index, k - 1), route_point(route_index, k))
	return total


static func leg_length_u(a: Vector2i, b: Vector2i) -> int:
	"""The integer length of a leg, u: the integer square root of its squared length."""
	return isqrt((b - a).length_squared())


static func isqrt(n: int) -> int:
	"""floor(sqrt(n)) for n >= 0, exact in integers: a float first guess corrected in integers both ways."""
	if n < 2:
		return maxi(n, 0)
	var x: int = int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x


static func leg_is_water(map: WaterMapScript, a: Vector2i, b: Vector2i) -> bool:
	"""Whether every sample along a leg (SAMPLE_U apart, both ends included) is water BOAT_DRAFT_U deep."""
	var length: int = leg_length_u(a, b)
	@warning_ignore("integer_division") var steps: int = maxi(1, length / SAMPLE_U)
	for s: int in steps + 1:
		@warning_ignore("integer_division") var at: Vector2i = a + (b - a) * s / steps
		if map.depth_at(at) < BOAT_DRAFT_U:
			return false
	return true


static func validate(map: WaterMapScript) -> String:
	""""" when every route and berth is boat water and the jetty's land end is dry ground; else what is wrong."""
	if map.is_water(JETTY_LAND_U):
		return "the jetty's land end is in the water"
	if not map.is_water(JETTY_END_U):
		return "the jetty's end is not over water"
	for route_index: int in ROUTES.size():
		if route_point(route_index, 0) != BERTH_U[route_index]:
			return "route %d does not start at its berth" % route_index
		for k: int in range(1, route_points(route_index)):
			if not leg_is_water(map, route_point(route_index, k - 1), route_point(route_index, k)):
				return "route %d leg %d runs aground" % [route_index, k]
	return ""


static func m_of(at_u: Vector2i) -> Vector2:
	"""An integer point as metres."""
	return Vector2(WaterRules.to_m(at_u.x), WaterRules.to_m(at_u.y))


static func u_of(at_m: Vector2) -> Vector2i:
	"""A point in metres as integer u (rounded)."""
	return Vector2i(WaterRules.to_u(at_m.x), WaterRules.to_u(at_m.y))
