extends RefCounted
## What each stretch of a planned route is: on the surface, wading, underground (and on which level), over a bridge,
## swimming, or over the bridge a preview proposes. Decision 0461 (review P5's route overlay). Read from the route's
## own leg codes (tunnel_router.gd LEG CODES) and the network and water it was planned over -- never guessed from where
## the line runs. Presentation only.
##
## A waypoint's KIND is how it is reached from the one before: a SURFACE leg (WADE where the water's hook costs wading
## on it: the ford), a segment of the network walked (UNDERGROUND, with that segment's level; 0 for a ramp or stairs
## between the levels), or a crossing -- a bridge row (BRIDGE), a swim link row (SWIM), the preview's proposed bridge
## (PROPOSED, preview_crossings.gd PROPOSAL_ROW), or any other water crossing (WATER: a boat leg, should the water
## offer one). `runs_text` merges consecutive waypoints of one kind into a run, e.g.
## "surface 18 m · wading 6 m · surface 12 m".

const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")
const PreviewScript := preload("res://demo/routes/preview_crossings.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")

const KIND_SURFACE: int = 0
const KIND_WADE: int = 1
const KIND_UNDERGROUND: int = 2
const KIND_BRIDGE: int = 3
const KIND_SWIM: int = 4
const KIND_WATER: int = 5
const KIND_PROPOSED: int = 6
const KIND_COUNT: int = 7
## How each kind reads in a run ("wading 6 m") and in the overlay's legend.
const KIND_WORDS: Array[String] = ["surface", "wading", "underground", "bridge", "swimming", "by water", "new bridge"]
## A level that is between the two (a ramp or stairs down).
const BETWEEN_LEVELS: int = 0

## The swim links' crossing rows: from `swim_first`, `swim_count` of them (water_crossings.gd LINK_ROW0; the links'
## count). Rows below are bridges.
var swim_first: int = BridgesScript.MAX_BRIDGES
var swim_count: int = 0
## The water's hook, for wading (the base: no water).
var hook: CrossingHookScript = CrossingHookScript.new()


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
	return KIND_WATER


static func level_of(graph: GraphScript, code: int) -> int:
	"""An underground leg's level (BETWEEN_LEVELS on a ramp or stairs down between them); -1 for any other leg."""
	if code == RouterScript.SURFACE_LEG or RouterScript.is_crossing_code(code):
		return -1
	var slot: int = RouterScript.leg_slot(code)
	return BETWEEN_LEVELS if graph.seg_link[slot] != Rules.LINK_NONE else graph.seg_level[slot]


func kinds_into(graph: GraphScript, from: Vector2, path: PackedVector2Array, legs: PackedInt32Array,
		kinds: PackedInt32Array, levels: PackedInt32Array) -> void:
	"""Each waypoint's kind and level (see the header), starting from `from`."""
	kinds.resize(path.size())
	levels.resize(path.size())
	var at := from
	for k: int in path.size():
		var code: int = legs[k] if k < legs.size() else RouterScript.SURFACE_LEG
		kinds[k] = kind_of(code, at, path[k])
		levels[k] = level_of(graph, code)
		at = path[k]


static func run_word(kind: int, level: int) -> String:
	"""A run's name: "underground, level 1", "underground, between levels", or the kind's word."""
	if kind != KIND_UNDERGROUND:
		return KIND_WORDS[kind]
	return "underground, between levels" if level == BETWEEN_LEVELS else "underground, level %d" % level


func runs_text(graph: GraphScript, from: Vector2, path: PackedVector2Array, legs: PackedInt32Array) -> String:
	"""The route as its runs: "surface 18 m · wading 6 m · surface 12 m" ("" for no route)."""
	var kinds := PackedInt32Array()
	var levels := PackedInt32Array()
	kinds_into(graph, from, path, legs, kinds, levels)
	var parts := PackedStringArray()
	var at := from
	var run_m: float = 0.0
	for k: int in path.size():
		run_m += at.distance_to(path[k])
		at = path[k]
		var last: bool = k == path.size() - 1
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
