extends RefCounted
## The village's WORK PLACES and the WORK TRIPS between them: what a route estimate is asked about (review P5: "store to
## farm, woods to log stack, the hall to the far bank") and what the public routes are labelled for (ECO-039). Decision
## 0461. Presentation only; the places are where the village's own work stands, read from the cast's points of
## interest and the water's landings wherever those exist, so a moved building moves its place.
##
## A trip is RELEVANT to a proposal when it could use it: to a bridge when its straight line meets the water (only such
## a trip is offered a crossing at all: water_crossings.gd WHAT A TRIP IS OFFERED), nearest the bridge first; to a
## tunnel piece when walking to one end and from the other is shorter than the straight walk (it might save something),
## the most it might save first. The estimate then says whether it really does.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

const SQUARE: int = 0
const STORE: int = 1
const FARM: int = 2
const LOG_STACK: int = 3
const YARD: int = 4
const HALL: int = 5
const FISHING: int = 6
const FAR_FORD: int = 7
const FAR_MILL: int = 8
## The foraging trips' grounds in the north woods (decision 0681; forage_rules.gd SPOT_AT's hazel brake).
const FORAGE: int = 9
const PLACE_COUNT: int = 10
const NAMES: Array[String] = ["the square", "the store", "the farm", "the log stack", "the wood yard", "the hall",
	"the fisher's landing", "the far bank at the ford", "the far bank by the mill", "the forage grounds"]
## Where each place is: a point of interest's first slot (world_layout.gd POINTS), else a water landing's land point
## (water_layout.gd LANDING_NAMES), else the authored point (metres; the far bank by the mill has neither).
const POIS: Array[StringName] = [&"well_drink", &"store_front", &"crops_cabbage", &"log_stack", &"stockpile",
	&"hall_steps", &"", &"", &"", &""]
const LANDINGS: Array[StringName] = [&"", &"", &"", &"", &"", &"", &"fisher_shelter", &"ford_east", &"", &""]
const AUTHORED: Array[Vector2] = [Vector2(0.0, 1.2), Vector2(14.0, 8.4), Vector2(-9.4, 8.0), Vector2(4.6, 15.6),
	Vector2(12.6, -13.6), Vector2(0.0, -10.2), Vector2(19.6, 7.3), Vector2(30.4, -0.8), Vector2(28.0, -25.5),
	Vector2(-7.5, -29.4)]
## The work trips, (from, to).
const TRIPS: Array[Vector2i] = [Vector2i(STORE, FARM), Vector2i(LOG_STACK, STORE), Vector2i(HALL, FAR_MILL),
	Vector2i(STORE, FAR_FORD), Vector2i(LOG_STACK, FAR_MILL), Vector2i(HALL, FISHING), Vector2i(YARD, FAR_MILL),
	Vector2i(FARM, LOG_STACK)]
## The work districts whose public route from the square the Routes layer labels (ECO-039).
const DISTRICTS: Array[int] = [STORE, FARM, LOG_STACK, YARD, HALL, FISHING, FAR_FORD, FAR_MILL, FORAGE]

var points: PackedVector2Array = PackedVector2Array(AUTHORED)

var _order: PackedFloat32Array = PackedFloat32Array()


func resolve(space: CastSpaceScript, map: WaterMapScript) -> void:
	"""Each place's point: its point of interest's first slot in `space`, else its landing on `map`, else authored."""
	points = PackedVector2Array(AUTHORED)
	for k: int in PLACE_COUNT:
		var poi: int = space.poi_names.find(POIS[k]) if space != null and POIS[k] != &"" else -1
		if poi >= 0:
			points[k] = space.slot_position(poi, 0)
			continue
		if map == null or LANDINGS[k] == &"":
			continue
		for n: int in map.landing_count():
			if map.landing_name(n) == LANDINGS[k]:
				var land: Vector2i = map.landing_land(n)
				points[k] = Vector2(WaterRules.to_m(land.x), WaterRules.to_m(land.y))


func trip_name(t: int) -> String:
	"""'the store to the farm' (the arrow is the panels' before -> after)."""
	return "%s to %s" % [NAMES[TRIPS[t].x], NAMES[TRIPS[t].y]]


func trip_from(t: int) -> Vector2:
	"""Where work trip `t` starts."""
	return points[TRIPS[t].x]


func trip_to(t: int) -> Vector2:
	"""Where work trip `t` ends."""
	return points[TRIPS[t].y]


func water_trips_into(middle: Vector2, crosses_water: Callable, most: int, out: PackedInt32Array) -> int:
	"""The work trips relevant to a bridge whose middle is `middle` (see RELEVANT), nearest first, at most `most`, into
	`out`; how many."""
	out.clear()
	_order.clear()
	for t: int in TRIPS.size():
		if crosses_water.is_valid() and bool(crosses_water.call(trip_from(t), trip_to(t))):
			_insert(out, t, _segment_distance(middle, trip_from(t), trip_to(t)))
	return _keep(out, most)


func near_trips_into(end_a: Vector2, end_b: Vector2, most: int, out: PackedInt32Array) -> int:
	"""The work trips relevant to a tunnel between `end_a` and `end_b` (see RELEVANT), the most each might save first,
	at most `most`, into `out`; how many."""
	out.clear()
	_order.clear()
	for t: int in TRIPS.size():
		var straight: float = trip_from(t).distance_to(trip_to(t))
		var via: float = minf(trip_from(t).distance_to(end_a) + end_b.distance_to(trip_to(t)),
			trip_from(t).distance_to(end_b) + end_a.distance_to(trip_to(t)))
		if via < straight:
			_insert(out, t, via - straight)
	return _keep(out, most)


func _insert(out: PackedInt32Array, t: int, rank: float) -> void:
	"""Keep `out` sorted by rank, least first (equal ranks in trip order)."""
	var at: int = out.size()
	while at > 0 and _order[at - 1] > rank:
		at -= 1
	out.insert(at, t)
	_order.insert(at, rank)


static func _keep(out: PackedInt32Array, most: int) -> int:
	"""Cut `out` to `most`; its size."""
	if out.size() > most:
		out.resize(most)
	return out.size()


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from `p` to the segment a-b."""
	var ab: Vector2 = b - a
	if ab.length_squared() <= 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
