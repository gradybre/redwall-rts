extends RefCounted
## Why a resident is not moving along its route, and WHERE: the route overlay's marker and words (MOVE-REQ-018:
## planning, waiting for access, incompatibility and the lack of an exit told apart, in words as well as colour).
## Decision 0461 (review P5, P1's tunnel row). Every reason is read from the real cause in the brain, the network or
## the desk -- never from a timer or a guess. Presentation only.
##
##   FINDING_ROUTE   the brain waits at the routing desk (State.ROUTE: route_desk.gd), where it stands
##   WAITING_MOUTH   in a mouth's line (State.QUEUE: tunnel_queue.gd), at that mouth
##   NO_SAFE_EXIT    stranded below, every way out closed (resident_brain.gd `is_stranded`), where it stands
##   CLOSED_FLOOD    a segment ahead on its route is flooded (underground_graph.gd CLOSED_FLOODED), at its entry
##   CLOSED_FALL     ... its roof has fallen (CLOSED_COLLAPSED), at its entry
##   LOAD_TOO_WIDE   a segment ahead fits the walker but not with what it now carries (fit_refusal loaded), at its
##                   entry -- a load taken up after the route was planned (MOVE-REQ-019)
##   TOO_BIG         a segment ahead its body does not fit at all, at its entry
##   NO_ROUTE        its last trip found no route at all (resident_brain.gd REFUSED_NO_ROUTE), at the goal
##   GAVE_UP         its last trip stayed blocked and was given up (REFUSED_BLOCKED), at the goal
## The checks run in that order: the first that holds is the reason. A trip under way is looked along from the
## waypoint it is heading to; a trip that ended is not.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const NONE: int = 0
const FINDING_ROUTE: int = 1
const WAITING_MOUTH: int = 2
const NO_SAFE_EXIT: int = 3
const CLOSED_FLOOD: int = 4
const CLOSED_FALL: int = 5
const LOAD_TOO_WIDE: int = 6
const TOO_BIG: int = 7
const NO_ROUTE: int = 8
const GAVE_UP: int = 9
const WORDS: Array[String] = ["", "finding a route", "waiting for mouth", "no safe exit", "closed by flood",
	"closed by a roof fall", "load too wide", "too big for the bore", "can't find a way there",
	"gave up: the way stayed blocked"]
## Whether a reason is a wait that ends by itself (the overlay draws those brass, the rest clay).
const WAITS: Array[bool] = [false, true, true, false, false, false, false, false, false, false]


## Where a reason applies (metres, x and z) -- the caller's, reused.
class Where:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO


static func diagnose(brain: BrainScript, graph: GraphScript, where: Where) -> int:
	"""The reason resident `brain` is held up, and where (see the header); NONE when it is not."""
	if brain.state == BrainScript.State.ROUTE:
		where.at = brain.position
		return FINDING_ROUTE
	if brain.is_stranded():
		where.at = brain.position
		return NO_SAFE_EXIT
	if brain.state == BrainScript.State.QUEUE:
		where.at = brain.path[brain.path_index] if brain.path_index < brain.path.size() else brain.position
		return WAITING_MOUTH
	if brain.trip_outcome == BrainScript.TRIP_UNDERWAY:
		return _ahead(brain, graph, where)
	if brain.trip_failed():
		where.at = brain.goal()
		return GAVE_UP if brain.route_refusal() == BrainScript.REFUSED_BLOCKED else NO_ROUTE
	return NONE


static func _ahead(brain: BrainScript, graph: GraphScript, where: Where) -> int:
	"""The first segment ahead on the route that is closed, or that the walker does not fit with what it carries."""
	for k: int in range(brain.path_index, brain.path.size()):
		var code: int = brain.path_tunnel[k] if k < brain.path_tunnel.size() else RouterScript.SURFACE_LEG
		if code == RouterScript.SURFACE_LEG or RouterScript.is_crossing_code(code):
			continue
		var slot: int = RouterScript.leg_slot(code)
		var why: int = segment_reason(graph, slot, brain.index, brain.carrying)
		if why != NONE:
			where.at = graph.node_m(graph.leg_start_node(code))
			return why
	return NONE


static func segment_reason(graph: GraphScript, slot: int, who: int, carrying: bool) -> int:
	"""Why resident `who` (carrying, when `carrying`) may not walk segment `slot` now: closed, its load too wide, or
	its body too big; NONE when it may."""
	match graph.closed[slot]:
		GraphScript.CLOSED_FLOODED:
			return CLOSED_FLOOD
		GraphScript.CLOSED_COLLAPSED:
			return CLOSED_FALL
	if graph.fit_refusal(who, slot, carrying) == Rules.FIT_OK:
		return NONE
	return LOAD_TOO_WIDE if carrying and graph.fit_refusal(who, slot, false) == Rules.FIT_OK else TOO_BIG


static func fit_reason(graph: GraphScript, who: int, bore_class: int, carrying: bool) -> int:
	"""Whether resident `who` fits a bore of `bore_class` (with a load when `carrying`): NONE, LOAD_TOO_WIDE (it fits,
	its load does not) or TOO_BIG -- per member, never one member's fit standing for a group's (MOVE-REQ-012)."""
	if graph.fit_class_refusal(who, bore_class, carrying) == Rules.FIT_OK:
		return NONE
	if carrying and graph.fit_class_refusal(who, bore_class, false) == Rules.FIT_OK:
		return LOAD_TOO_WIDE
	return TOO_BIG
