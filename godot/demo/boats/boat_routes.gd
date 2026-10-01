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
##
## THE FERRY (decision 0437, water part B lane 3). A THIRD BOAT, the ferry boat, is moored at its own berth off the
## FERRY STAGE -- a second jetty on the run's west bank, 8 m below the fisher shelter -- and rows ONE FIXED ROUTE down the
## run into the pond's north-east lobe to the FAR STAGE, a third jetty on the stream's far bank at its mouth, and back the
## same way. Both stages are lane 1's jetty pattern: a land end on the bank top the planner reaches,
## a deck over the water walked only by a boat's own steps, outside every building footprint. The fishing boats are the
## boathouse's two (FISHING_BOATS); the ferry boat never fishes, and the fishing boats never ferry. Each berth's crew
## boards from its own jetty (BERTH_JETTY), so a rescue in the ferry boat walks to the ferry stage, not the boathouse.

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

## The ferry's two stages (decision 0437): each a land end on the bank top and a deck end over the water, 3.3 m apart as
## the boathouse jetty's are (the same staged jetty model, drawn by demo/ferry/ferry_view.gd).
const FERRY_STAGE_NAME: String = "the ferry stage"
const FAR_STAGE_NAME: String = "the far stage"
const FERRY_STAGE_LAND_U: Vector2i = Vector2i(23450, 15565)     # 22.9, 15.2 -- the run's west bank top
const FERRY_STAGE_END_U: Vector2i = Vector2i(26829, 15565)      # 26.2, 15.2 -- 1.9 m out over the run
const FAR_STAGE_LAND_U: Vector2i = Vector2i(34816, 22323)       # 34.0, 21.8 -- the far bank at the stream's mouth
const FAR_STAGE_END_U: Vector2i = Vector2i(32358, 24678)        # 31.6, 24.1 -- out south-west over the north-east lobe
## The jetties in one table: the boathouse jetty (0), the ferry stage (1), the far stage (2).
const JETTY_COUNT: int = 3
const JETTY_NAMES: Array[String] = [JETTY_NAME, FERRY_STAGE_NAME, FAR_STAGE_NAME]
const JETTY_LANDS_U: Array[Vector2i] = [JETTY_LAND_U, FERRY_STAGE_LAND_U, FAR_STAGE_LAND_U]
const JETTY_ENDS_U: Array[Vector2i] = [JETTY_END_U, FERRY_STAGE_END_U, FAR_STAGE_END_U]

## The berths: where each boat lies moored (its centre; its bow points along its route's first leg), and the deck
## point its crew steps aboard from. The boathouse keeps the first FISHING_BOATS; the last is the ferry boat.
const BERTH_COUNT: int = 3
const FISHING_BOATS: int = 2
const FERRY_BOAT: int = 2
const BERTH_U: Array[Vector2i] = [
	Vector2i(23142, 31386),      # 22.6, 30.65 -- along the jetty's south side, clear of its 1.7 m deck
	Vector2i(25395, 29594),      # 24.8, 28.9  -- off the jetty's end
	Vector2i(28262, 15974),      # 27.6, 15.6  -- the ferry boat, off the ferry stage's end, lying down the run
]
const BERTH_STEP_U: Array[Vector2i] = [
	Vector2i(23142, 30310),      # 22.6, 29.6  -- the deck's south edge beside it
	Vector2i(23552, 29594),      # 23.0, 28.9  -- the deck's end
	Vector2i(26829, 15565),      # 26.2, 15.2  -- the ferry stage's end
]
## The jetty each berth's crew boards from: the boathouse jetty for the fishing boats, the ferry stage for the ferry boat.
const BERTH_JETTY: Array[int] = [0, 0, 1]
## Where a ferry crew or passenger steps between the far stage's deck and the ferry boat lying at its route's end: the
## deck's end, the boat lying off it.
const FAR_STEP_U: Vector2i = Vector2i(32358, 24678)             # 31.6, 24.1

## The fishing stations (on the pond: the lake habitat) and each berth's route to its station, (x, z) pairs from the
## berth out. The return is the same route reversed. The ferry boat's "station" is the far stage: down the run and into
## the north-east lobe, off the far stage's end.
const STATION_NAMES: Array[String] = ["the pond's middle", "the pond's south reach", FAR_STAGE_NAME]
const ROUTES: Array[Array] = [
	[23142, 31386, 25190, 31949, 28262, 31130],    # 22.6,30.65 -> 24.6,31.2 -> 27.6,30.4
	[25395, 29594, 27034, 31539, 28058, 33997],    # 24.8,28.9  -> 26.4,30.8 -> 27.4,33.2
	[28262, 15974, 29286, 20070, 30310, 23757, 31027, 25958],    # 27.6,15.6 -> 28.6,19.6 -> 29.6,23.2 -> 30.3,25.35
]


static func route(route_index: int) -> PackedInt32Array:
	"""Route `route_index`'s points (x, z pairs, u) as a packed array, berth first."""
	return PackedInt32Array(ROUTES[route_index])


static func route_point(route: int, k: int) -> Vector2i:
	"""Point `k` of route `route` (u)."""
	return Vector2i(ROUTES[route][k * 2], ROUTES[route][k * 2 + 1])


static func route_points(route: int) -> int:
	"""How many points route `route` has."""
	return ROUTES[route].size() / 2


static func route_length_u(route: int) -> int:
	"""Route `route`'s length, berth to station, in whole u (each leg's length rounded down)."""
	var total: int = 0
	for k: int in range(1, route_points(route)):
		total += leg_length_u(route_point(route, k - 1), route_point(route, k))
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
	var steps: int = maxi(1, length / SAMPLE_U)
	for s: int in steps + 1:
		var at: Vector2i = a + (b - a) * s / steps
		if map.depth_at(at) < BOAT_DRAFT_U:
			return false
	return true


static func validate(map: WaterMapScript) -> String:
	""""" when every route and berth is boat water and every jetty's land end is dry ground; else what is wrong."""
	for jetty: int in JETTY_COUNT:
		if map.is_water(JETTY_LANDS_U[jetty]):
			return "%s's land end is in the water" % JETTY_NAMES[jetty]
		if not map.is_water(JETTY_ENDS_U[jetty]):
			return "%s's end is not over water" % JETTY_NAMES[jetty]
	for route: int in ROUTES.size():
		if route_point(route, 0) != BERTH_U[route]:
			return "route %d does not start at its berth" % route
		for k: int in range(1, route_points(route)):
			if not leg_is_water(map, route_point(route, k - 1), route_point(route, k)):
				return "route %d leg %d runs aground" % [route, k]
	return ""


static func m_of(at_u: Vector2i) -> Vector2:
	"""An integer point as metres."""
	return Vector2(WaterRules.to_m(at_u.x), WaterRules.to_m(at_u.y))


static func u_of(at_m: Vector2) -> Vector2i:
	"""A point in metres as integer u (rounded)."""
	return Vector2i(WaterRules.to_u(at_m.x), WaterRules.to_u(at_m.y))


static func jetty_land_m(jetty: int) -> Vector2:
	"""Jetty `jetty`'s land end (see the jetties' table), metres."""
	return m_of(JETTY_LANDS_U[jetty])


static func jetty_end_m(jetty: int) -> Vector2:
	"""Jetty `jetty`'s deck end over the water, metres."""
	return m_of(JETTY_ENDS_U[jetty])


static func boat_jetty_land_m(boat: int) -> Vector2:
	"""Where boat `boat`'s crew walks to board it: its own jetty's land end (BERTH_JETTY), metres."""
	return jetty_land_m(BERTH_JETTY[boat])


static func boat_name(boat: int) -> String:
	"""'Rowboat 1', 'Rowboat 2', 'The ferry boat'."""
	return "The ferry boat" if boat == FERRY_BOAT else "Rowboat %d" % (boat + 1)
