extends RefCounted
## What each stretch of a planned route is: on the surface, wading, underground (and on which level), over a bridge,
## swimming, or over the bridge a preview proposes. Decision 0461 (review P5's route overlay). Read from the route's
## own leg codes (tunnel_router.gd LEG CODES) and the network and water it was planned over -- never guessed from where
## the line runs. Presentation only.
##
## A waypoint's KIND is how it is reached from the one before: a SURFACE leg (WADE where the water's hook costs wading
## on it: the ford), a segment of the network walked (UNDERGROUND, with that segment's level; 0 for a ramp or stairs
## between the levels), or a crossing -- a bridge row (BRIDGE), a swim link row (SWIM), the preview's proposed bridge
## (PROPOSED, preview_crossings.gd PROPOSAL_ROW), or any other water crossing (BOAT). `runs_text` merges consecutive
## waypoints of one kind into a run, e.g. "surface 18 m · wading 6 m · surface 12 m".
##
## BOAT LEGS (water part B, decisions 0432 and 0461). A boat's legs are TASK-DRIVEN, not router pairs: a crew member
## aboard (a fishing trip's seat or a boat rescue's helm) is placed by the boat (boat_fleet.gd), not walking a route.
## `boat_leg_into` reads the boat it sits in -- where it is now and the rest of its course, out to its station or back
## to its berth -- so the Routes layer draws it as BOAT ("by boat"), never as an unknown crossing or nothing.

const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")
const PreviewScript := preload("res://demo/routes/preview_crossings.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const BoatRoutes := preload("res://demo/boats/boat_routes.gd")

const KIND_SURFACE: int = 0
const KIND_WADE: int = 1
const KIND_UNDERGROUND: int = 2
const KIND_BRIDGE: int = 3
const KIND_SWIM: int = 4
## A boat leg (see BOAT LEGS), and any other water crossing.
const KIND_BOAT: int = 5
const KIND_PROPOSED: int = 6
const KIND_COUNT: int = 7
## How each kind reads in a run ("wading 6 m") and in the overlay's legend.
const KIND_WORDS: Array[String] = ["surface", "wading", "underground", "bridge", "swimming", "by boat", "new bridge"]
## A level that is between the two (a ramp or stairs down).
const BETWEEN_LEVELS: int = 0

## The swim links' crossing rows: from `swim_first`, `swim_count` of them (water_crossings.gd LINK_ROW0; the links'
## count). Rows below are bridges.
var swim_first: int = BridgesScript.MAX_BRIDGES
var swim_count: int = 0
## The water's hook, for wading (the base: no water).
var hook: CrossingHookScript = CrossingHookScript.new()
## The village's boats (water part B; none: no boat legs).
var fleet: FleetScript = null


func configure(water_hook: CrossingHookScript, first_swim_row: int, swim_rows: int) -> void:
	"""Read wading from `water_hook`; swim links are crossing rows [first_swim_row, + swim_rows)."""
	hook = water_hook if water_hook != null else CrossingHookScript.new()
	swim_first = first_swim_row
	swim_count = swim_rows


func kind_of(code: int, a: Vector2, b: Vector2) -> int:
	"""The kind of the leg from `a` to `b` with leg code `code` (see the header)."""
	if code == RouterScript.SURFACE_LEG:
		return KIND_WADE if hook.wade_extra_m(a, b) > 0.0 else KIND_SURFACE
	if not RouterScript.is_crossing_code(code):
		return KIND_UNDERGROUND
	var row: int = RouterScript.crossing_row(code)
	if row == PreviewScript.PROPOSAL_ROW:
		return KIND_PROPOSED
	if row < BridgesScript.MAX_BRIDGES:
		return KIND_BRIDGE
	if row >= swim_first and row < swim_first + swim_count:
		return KIND_SWIM
	return KIND_BOAT


func boat_leg_into(who: int, out: PackedVector2Array) -> bool:
	"""Resident `who`'s boat leg (see BOAT LEGS) into `out` (cleared first): the boat where it is now, then the rest of
	its course -- on out to its station, or, on station or rowing back, back to its berth. False when `who` is in no boat
	under way (moored: the walk to and from the jetty is its route)."""
	out.clear()
	var boat: int = fleet.boat_of_crew(who) if fleet != null else -1
	if boat < 0 or fleet.phase[boat] == FleetScript.PHASE_MOORED:
		return false
	out.append(fleet.position_m(boat))
	var points: PackedInt32Array = fleet.course[boat]
	var start: int = 0
	var outward: bool = fleet.phase[boat] == FleetScript.PHASE_OUT
	var ahead := PackedVector2Array()
	@warning_ignore("integer_division") for k: int in range(1, points.size() / 2):
		var a := Vector2i(points[k * 2 - 2], points[k * 2 - 1])
		var b := Vector2i(points[k * 2], points[k * 2 + 1])
		var length: int = BoatRoutes.leg_length_u(a, b)
		if outward and start + length > fleet.progress_u[boat]:
			out.append(BoatRoutes.m_of(b))
		elif not outward and start < fleet.progress_u[boat]:
			ahead.append(BoatRoutes.m_of(a))
		start += length
	if not outward:
		for k: int in range(ahead.size() - 1, -1, -1):
			out.append(ahead[k])
	return out.size() > 1


static func level_of(graph: GraphScript, code: int) -> int:
	"""An underground leg's level (BETWEEN_LEVELS on a ramp or stairs down between them); -1 for any other leg."""
	if code == RouterScript.SURFACE_LEG or RouterScript.is_crossing_code(code):
		return -1
	var slot: int = RouterScript.leg_slot(code)
	return BETWEEN_LEVELS if graph.seg_link[slot] != Rules.LINK_NONE else graph.seg_level[slot]


func kinds_into(graph: GraphScript, from: Vector2, path: PackedVector2Array, legs: PackedInt32Array,
		kinds: PackedInt32Array, levels: PackedInt32Array, first: int = 0) -> void:
	"""Each waypoint's kind and level (see the header) from waypoint `first` on, reached from `from`: entry k is
	waypoint first + k (no slice of the route is made)."""
	var count: int = maxi(path.size() - first, 0)
	kinds.resize(count)
	levels.resize(count)
	var at := from
	for k: int in count:
		var code: int = legs[first + k] if first + k < legs.size() else RouterScript.SURFACE_LEG
		kinds[k] = kind_of(code, at, path[first + k])
		levels[k] = level_of(graph, code)
		at = path[first + k]


static func run_word(kind: int, level: int) -> String:
	"""A run's name: "underground, level 1", "underground, between levels", or the kind's word."""
	if kind != KIND_UNDERGROUND:
		return KIND_WORDS[kind]
	return "underground, between levels" if level == BETWEEN_LEVELS else "underground, level %d" % level


func runs_text(graph: GraphScript, from: Vector2, path: PackedVector2Array, legs: PackedInt32Array,
		first: int = 0) -> String:
	"""The route from waypoint `first` on as its runs: "surface 18 m · wading 6 m · surface 12 m" ("" for no route)."""
	var kinds := PackedInt32Array()
	var levels := PackedInt32Array()
	kinds_into(graph, from, path, legs, kinds, levels, first)
	var parts := PackedStringArray()
	var at := from
	var run_m: float = 0.0
	for k: int in kinds.size():
		run_m += at.distance_to(path[first + k])
		at = path[first + k]
		var last: bool = k == kinds.size() - 1
		if last or kinds[k + 1] != kinds[k] or levels[k + 1] != levels[k]:
			parts.append("%s %d m" % [run_word(kinds[k], levels[k]), maxi(roundi(run_m), 1)])
			run_m = 0.0
	return " · ".join(parts)


func has_kind(from: Vector2, path: PackedVector2Array, legs: PackedInt32Array, kind: int) -> bool:
	"""Whether any stretch of the route is of `kind`."""
	var at := from
	for k: int in path.size():
		if kind_of(legs[k] if k < legs.size() else RouterScript.SURFACE_LEG, at, path[k]) == kind:
			return true
		at = path[k]
	return false
