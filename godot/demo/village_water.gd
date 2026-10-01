extends RefCounted
## THE VILLAGE'S WATER, as the farm and the tunnels ask about it: one small adapter over the real
## water module. Decision 0196 (live demo).
##
## The water foundation (demo/water/) owns the stream and the pond and publishes them as ONE integer
## query module, water_map.gd (u = 1/1024 m, Vector2i(x, z)). The farm and the tunnel works ask it
## four questions, and ask them only HERE -- demo_village.gd builds one of these over the map its
## water node built (`water/demo_water.gd` `map()`) and hands it to both through demo_services.gd:
##   * `at_edge(x_u, z_u)` -- the FARM's irrigation: does a tunnel mouth here open onto the water?
##     Dry ground within EDGE_REACH_U of the waterline (the map's own shore samples).
##   * `near_water(x_u, z_u)` -- the TUNNELS' ground: is the ground here wet from the water? Within
##     WET_REACH_U of the waterline (the map's inside margin), or in it.
##   * `spill_centre_u()` / `spill_radius_u()` -- the TUNNELS' flood: the stream spills over its west
##     bank at the ford, where the east road meets it (the map's `ford_west` landing), SPILL_REACH_U
##     into the village.
##   * `crosses_water(a, b, clearance_u)` -- the TUNNELS' routes: would a bore from a to b pass under
##     (or within `clearance_u` of) water? The map's own `segment_crosses_water`; no bore may.
## Every answer is exact integers. The three reaches are DEMO values (the water foundation publishes
## the shore; how near counts as "at", "wet" or "flooded" is the demo's reading of it), each the
## value the placeholder it replaced used, so the behaviour did not move with the swap.
##
## WHY AN ADAPTER AND NOT THE MAP ITSELF: the farm and the tunnels speak in their own terms (an edge,
## wet ground, a spill), and the map's evolution (phase 2: swimming, boats, bridges) should not
## reach into either. The placeholders these queries used to answer from -- the farm's reed pond and
## the tunnels' stream table -- are gone.

const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## A tunnel mouth this near the waterline opens onto the water: 2.5 m (demo; the farm pond's 2 m
## shore, plus half a metre since a mouth must stand off the carved bank's 1.2 m slope).
const EDGE_REACH_U: int = 2560
## Ground this near the waterline is wet: 4.5 m (demo; the tunnels' placeholder stream reach).
const WET_REACH_U: int = 4608
## The flood's reach from its spill point: 8.2 m (demo; the tunnels' placeholder spill).
const SPILL_REACH_U: int = 8397
## Where the stream spills in a flood: the ford's west bank, where the east road crosses it.
const SPILL_LANDING: StringName = &"ford_west"

## The village's map when none is handed in (a suite building one module alone); immutable once
## finalized, so every such adapter shares one.
static var _shared_map: WaterMapScript = null

var _map: WaterMapScript = null
var _bank: WaterMapScript.Bank = WaterMapScript.Bank.new()
var _spill: Vector2i = Vector2i.ZERO


func _init(water_map: WaterMapScript = null) -> void:
	"""Answer from `water_map` (the water node's), or from the village's authored water."""
	_map = water_map if water_map != null else _default_map()
	var found := IntMath.IntResult.new()
	var resolved: bool = _map.landing_index_into(SPILL_LANDING, found)
	assert(resolved, "the village water must have its %s landing" % SPILL_LANDING)
	_spill = _map.landing_water(found.value)


static func _default_map() -> WaterMapScript:
	"""The village's authored water (water_layout.gd), built once and shared."""
	if _shared_map == null:
		_shared_map = WaterLayout.make_map()
	return _shared_map


func map() -> WaterMapScript:
	"""The real water map this adapter answers from."""
	return _map


func at_edge(x_u: int, z_u: int) -> bool:
	"""THE FARM'S QUERY: whether (x, z) in u is dry ground within EDGE_REACH_U of the waterline."""
	var at := Vector2i(x_u, z_u)
	if _map.is_water(at) or not _map.nearest_bank(at, _bank):
		return false
	return _bank.distance_u <= EDGE_REACH_U


func near_water(x_u: int, z_u: int) -> bool:
	"""THE TUNNELS' QUERY: whether the ground at (x, z) in u is within WET_REACH_U of the waterline (or
	in the water)."""
	return _map.inside_margin_u(Vector2i(x_u, z_u)) > -WET_REACH_U


func spill_centre_u() -> Vector2i:
	"""THE FLOOD'S QUERY: where the stream spills -- the ford's west waterline point, in u."""
	return _spill


func spill_radius_u() -> int:
	"""THE FLOOD'S QUERY: how far the spill reaches from there, in u."""
	return SPILL_REACH_U


func crosses_water(a: Vector2i, b: Vector2i, clearance_u: int) -> bool:
	"""THE TUNNELS' ROUTE QUERY: whether the segment a-b (u) passes within `clearance_u` of water."""
	return _map.segment_crosses_water(a, b, clearance_u)


func edge_query() -> Callable:
	"""`at_edge` as the farm's `(x_u: int, z_u: int) -> bool` Callable (farm_tunnels.gd `water_edge`)."""
	return at_edge

