extends RefCounted
## ROUTE ESTIMATES: what a few work trips cost before and after a proposed bridge or tunnel, from the real router,
## planned a little at a time through the routing desk. Decision 0461 (review P5, ECO-039). Presentation only: it
## plans on copies, it moves nobody and it changes no network, bridge or store.
##
## THE REAL ROUTER, NOT A FORMULA. A trip is planned exactly as a resident's own trip is planned (cast_space.gd
## `plan_path`): through the tunnels the walker fits with its load, when any is open; over whatever the water offers
## that walker and load (a loaded walker never swims); round every obstacle -- by the same tunnel_router.gd over the
## same graph_paths.gd and cast_nav.gd. Its cost is the router's own figure for the route it found
## (`last_cost_m`, metres at walk speed: the surface at the weather's pace, wading slower, a tunnel at its bore's
## pace, a crossing at its own cost). Only two inputs differ from a resident's live plan, both stated on screen:
## nobody is standing about (a resident in the way is a moment's detour, not the route), and the trip starts and ends
## at the work places named, not wherever a resident stands.
##
## BEFORE AND AFTER. "Before" is planned on the LIVE network with the LIVE crossings -- literally a resident's plan,
## nobody standing about: it shares the router's warm stop-to-stop cache (keyed by the same revisions, so it adds only
## what that resident's own plan would add, and drops nothing) and changes no state. "After" is planned on a COPY of
## the network with the proposal in it -- a dug piece's segments taken as open (`propose_open`), a piece laid on the
## copy and taken as open (`propose_piece`, the Dig tool's plan), or a bridge offered as an open one is offered
## (`propose_bridge`, preview_crossings.gd). The copy has its own router and paths, so a proposal's crossings and
## segments never reach -- or throw away -- the live router's cache or Dijkstra tables. The copy is every packed column
## and scalar of the network duplicated; its mouths' lines, ground, rooms, fit-out and hauls are the live ones, read
## only (planning and laying a piece only read them).
##
## THE BUDGET (decision 0361's desk). Nothing here plans synchronously in a burst: `step(desk)` does ONE piece of the
## work -- making the copy, or one trip's one plan -- and only when no resident is waiting for a route and the
## desk's window can take a plan; its time is charged to the window (`charge(-1, ...)`), so the residents' plans in
## the same frame see it spent. A plan is never cut in two (0361), and a swimmer's across the water can cost tens of
## milliseconds cold (a dozen surface plans to the swim links' ends); so after a step longer than the desk's budget
## the estimate RESTS that many windows (`_rest`), keeping its average within the budget however long one plan is. With the copies and up to `capacity` trips before and after, an estimate takes at most
## 2 x capacity + 1 steps -- a few frames -- and the panels say "calculating…" until it is done.
##
## STALE. The answer is for the network, the water's crossings and the weather as they were when the copies were
## made; when any of them changes (`start`, `step`), the estimate starts again from new copies.
##
## WHAT IT IS NOT. A route's cost is walking time at walk speed: no turning, no queue at a mouth, no one in the way, a
## carrier's slower pace applied as one factor (`pace_m_s`). MOVE-G01..05 are open: this is the demo's routing, not
## a certified production route (the panels say "estimate").

const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const DeskScript := preload("res://demo/cast/route_desk.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")
const PreviewScript := preload("res://demo/routes/preview_crossings.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const PROPOSE_NONE: int = 0
const PROPOSE_BRIDGE: int = 1
const PROPOSE_PIECE: int = 2
const PROPOSE_OPEN: int = 3
## Trips one estimate plans by default (see THE BUDGET); `_init` may size it for more (the public ways: one a district).
const MAX_TRIPS: int = 4
## `_next` when there is nothing to do.
const IDLE: int = -1
## The network's helpers a copy shares with the live one, read only (see BEFORE AND AFTER).
const SHARED: Array[StringName] = [&"queue", &"ground", &"rooms", &"fit", &"haul"]

## How many trips it holds, and the trips: where each starts and ends, and what the panels call it.
var capacity: int = MAX_TRIPS
var trip_count: int = 0
var trip_from: PackedVector2Array = PackedVector2Array()
var trip_to: PackedVector2Array = PackedVector2Array()
var trip_names: PackedStringArray = PackedStringArray()
## Per trip: the cost before and after (metres at walk speed; INF: no route), and whether each is known yet.
var before_m: PackedFloat32Array = PackedFloat32Array()
var after_m: PackedFloat32Array = PackedFloat32Array()
var before_known: PackedByteArray = PackedByteArray()
var after_known: PackedByteArray = PackedByteArray()
## Per trip: the route found before and after, and each waypoint's leg code (tunnel_router.gd LEG CODES).
var before_paths: Array[PackedVector2Array] = []
var before_legs: Array[PackedInt32Array] = []
var after_paths: Array[PackedVector2Array] = []
var after_legs: Array[PackedInt32Array] = []
## Whose trip: the resident whose body, fit and water the plans use, its body radius, and whether it carries.
var walker: int = -1
var body_m: float = 0.25
var loaded: bool = true
## What is proposed (PROPOSE_*), and whether the copy could take it (a piece the copy's network has no room for).
var proposal: int = PROPOSE_NONE
var proposal_ok: bool = true
## Measurement: plans run, steps refused for the budget, estimates started, and the longest step (usec).
var plans_run: int = 0
var steps_refused: int = 0
var restarts: int = 0
var max_step_usec: int = 0

var _nav: CastNavScript = null
var _live: GraphScript = null
var _after: GraphScript = null
var _live_hook: CrossingHookScript = CrossingHookScript.new()
var _after_hook: PreviewScript = PreviewScript.new()
## Windows still to rest after a long step (see THE BUDGET).
var _rest: int = 0
var _spec: SpecScript = null
var _piece: int = -1
var _upto: int = -1
var _bridge: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _bridge_walk_m: float = 0.0
var _next: int = IDLE
var _key: int = 0
var _has_job: bool = false
var _copied: bool = false
var _seen: Vector3i = Vector3i(-1, -1, -1)
var _path: PackedVector2Array = PackedVector2Array()
var _legs: PackedInt32Array = PackedInt32Array()
var _no_standing: PackedVector3Array = PackedVector3Array()
var _ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
var _chain: PackedInt32Array = PackedInt32Array()


func _init(trips: int = MAX_TRIPS) -> void:
	"""Size the per-trip columns once, for `trips` trips."""
	capacity = maxi(trips, 1)
	for column: PackedVector2Array in [trip_from, trip_to]:
		column.resize(capacity)
	trip_names.resize(capacity)
	for column: PackedFloat32Array in [before_m, after_m]:
		column.resize(capacity)
	for column: PackedByteArray in [before_known, after_known]:
		column.resize(capacity)
	for k: int in capacity:
		before_paths.append(PackedVector2Array())
		before_legs.append(PackedInt32Array())
		after_paths.append(PackedVector2Array())
		after_legs.append(PackedInt32Array())


func configure(nav: CastNavScript, live: GraphScript, crossings: CrossingHookScript, water_crossing: Callable) -> void:
	"""Plan with this surface planner, copying this network, offering what these crossings offer;
	`water_crossing(a, b) -> bool` says whether a straight line meets water (preview_crossings.gd)."""
	_nav = nav
	_live = live
	_live_hook = crossings if crossings != null else CrossingHookScript.new()
	_after_hook.configure(crossings, water_crossing)


# --- what to estimate --------------------------------------------------------------------------------

func clear_trips() -> void:
	"""No trips (call `add_trip`, then `start`)."""
	trip_count = 0


func add_trip(from: Vector2, to: Vector2, name: String) -> bool:
	"""One more trip, from -> to; false once `capacity` are set."""
	if trip_count >= capacity:
		return false
	trip_from[trip_count] = from
	trip_to[trip_count] = to
	trip_names[trip_count] = name
	trip_count += 1
	return true


func set_walker(who: int, body_radius_m: float, carrying: bool) -> void:
	"""Plan as resident `who` would, with body radius `body_radius_m`, carrying when `carrying`."""
	walker = who
	body_m = body_radius_m
	loaded = carrying


func propose_nothing() -> void:
	"""Only "before": the routes as they are (the public routes, ECO-039)."""
	proposal = PROPOSE_NONE


func propose_bridge(approach_a: Vector2, approach_b: Vector2, walk_m: float) -> void:
	"""After: a bridge between these approaches, `walk_m` long (bridges.gd `approach`, `walk_length_m`)."""
	proposal = PROPOSE_BRIDGE
	_bridge[0] = approach_a
	_bridge[1] = approach_b
	_bridge_walk_m = walk_m


func propose_piece(spec: SpecScript) -> void:
	"""After: the piece `spec` laid (the Dig tool's plan, tunnel_plan.gd `spec_of`) and dug open."""
	proposal = PROPOSE_PIECE
	_spec = spec


func propose_open(p: int, upto: int = -1) -> void:
	"""After: the network's piece row `p` (planned, being dug or paused) dug open -- its first `upto` segments in dig
	order (a stage: dig_stages.gd), or all of it (-1)."""
	proposal = PROPOSE_OPEN
	_piece = p
	_upto = upto


func start(key: int) -> void:
	"""Estimate what was set, for `key` (the caller's hash of the trips, walker and proposal): kept as it is while the
	key is the same and nothing it was made for has changed (see STALE), else begun again."""
	if key == _key and _has_job and not _stale():
		return
	_key = key
	_has_job = true
	_restart()


func _restart() -> void:
	"""Forget every result; the next step makes fresh copies."""
	for k: int in capacity:
		before_known[k] = 0
		after_known[k] = 0
		before_m[k] = INF
		after_m[k] = INF
	_copied = false
	_next = 0 if trip_count > 0 else IDLE
	restarts += 1


func _stale() -> bool:
	"""Whether the network, the water's crossings or the weather moved since the copies were made."""
	return _copied and _seen != _now()


func _now() -> Vector3i:
	"""What an estimate is made for: the network's revision, the crossings' and the weather's surface pace."""
	return Vector3i(_live.revision, _live_hook.revision(), _live.surface_permille)


# --- the work, a piece at a time ---------------------------------------------------------------------

func is_calculating() -> bool:
	"""Whether the estimate still has work to do (the panels' "calculating…")."""
	return _next != IDLE


func is_done() -> bool:
	"""Whether every trip is planned, before and after."""
	return _next == IDLE and trip_count > 0 and before_known.count(1) >= trip_count


func steps_total() -> int:
	"""How many steps a whole estimate takes: the copy, then each trip before (and after, with a proposal)."""
	return 1 + trip_count * (2 if proposal != PROPOSE_NONE else 1)


func step(desk: DeskScript) -> bool:
	"""Do one piece of the work when the desk allows it (see THE BUDGET): nobody waiting for a route, a plan fitting this
	window, and no rest owed for a long step. Its time is charged to the window. True when it did something."""
	if _next == IDLE:
		return false
	if desk != null and (desk.waiting() > 0 or not desk.has_budget() or _rest > 0):
		steps_refused += 1
		_rest = maxi(_rest - 1, 0)
		return false
	var began := Time.get_ticks_usec()
	if _stale():
		_restart()
	if _next == 0:
		_make_copies()
	else:
		_plan_step(_next - 1)
	_next = _next + 1 if _next + 1 < steps_total() else IDLE
	var spent := Time.get_ticks_usec() - began
	max_step_usec = maxi(max_step_usec, spent)
	if desk != null:
		desk.charge(-1, spent)
		@warning_ignore("integer_division") _rest = spent / desk.budget_usec if desk.budget_usec > 0 else 0
	return true


func run_all() -> void:
	"""Every step at once, with no desk -- for the suites, never the live scene."""
	while _next != IDLE:
		step(null)


func _make_copies() -> void:
	"""The after network (see BEFORE AND AFTER) with the proposal in it; none without a proposal."""
	_seen = _now()
	_copied = true
	_drop_copy()
	_after = copy_network(_live) if proposal != PROPOSE_NONE else null
	_after_hook.withdraw()
	proposal_ok = true
	match proposal:
		PROPOSE_BRIDGE:
			_after_hook.propose(_bridge[0], _bridge[1], _bridge_walk_m, _live.surface_permille)
		PROPOSE_PIECE:
			proposal_ok = _spec != null and _after.add_piece(_spec, _ref)
			if proposal_ok:
				_open_piece(_after, _ref[2], -1)
		PROPOSE_OPEN:
			proposal_ok = _piece >= 0 and _piece < _after.piece_live.size() and _after.piece_live[_piece] == 1
			if proposal_ok:
				_open_piece(_after, _piece, _upto)


func _drop_copy() -> void:
	"""Let the old copy go: its router holds it back (`use_paths` keeps the graph it planned on), and two RefCounted
	holding each other are never freed -- so the router lets go first."""
	if _after != null:
		_after.router.clear_pairs()
	_after = null


func stop() -> void:
	"""Nothing to estimate any more (what it was for is gone): no more steps, and the copy let go."""
	_next = IDLE
	_has_job = false
	_drop_copy()


func _open_piece(graph: GraphScript, p: int, upto: int) -> void:
	"""The first `upto` segments of piece `p` in dig order (every one: -1) taken as dug open on a copy."""
	graph.piece_segments_into(p, _chain)
	for k: int in _chain.size():
		if upto < 0 or k < upto:
			graph.phase[_chain[k]] = GraphScript.PHASE_OPEN
	graph.revision += 1


func _plan_step(j: int) -> void:
	"""Plan step `j`: trip j (no proposal), else trip j / 2 before (even) or after (odd)."""
	var after: bool = proposal != PROPOSE_NONE and j % 2 == 1
	@warning_ignore("integer_division") var k: int = j / 2 if proposal != PROPOSE_NONE else j
	var cost: float = INF
	if not after or proposal_ok:
		cost = plan_cost(_after if after else _live, _after_hook if after else _live_hook, trip_from[k], trip_to[k])
	else:
		_path.clear()
		_legs.clear()
	plans_run += 1
	if after:
		after_m[k] = cost
		after_known[k] = 1
		after_paths[k] = _path.duplicate()
		after_legs[k] = _legs.duplicate()
	else:
		before_m[k] = cost
		before_known[k] = 1
		before_paths[k] = _path.duplicate()
		before_legs[k] = _legs.duplicate()


func plan_cost(graph: GraphScript, hook: CrossingHookScript, from: Vector2, to: Vector2) -> float:
	"""One trip planned on `graph` exactly as cast_space.gd `plan_path` plans a resident's (see THE REAL ROUTER):
	tunnels when any is open and the walker fits one with its load, the crossings only when the water offers some.
	The route into `_path` / `_legs`; its cost (m at walk speed), INF with no route. The surface planner's
	`last_found` is left as it was."""
	var found_before: bool = _nav.last_found
	var use_tunnels: bool = graph.open_count() > 0 and graph.fits_any(walker, loaded)
	var use_crossings: bool = hook.offers_for(walker, from, to, loaded)
	var found: bool = graph.plan(_nav, from, to, body_m, _no_standing, 0, _path, _legs, walker, loaded,
		hook if use_crossings else null, use_tunnels)
	_nav.last_found = found_before
	var cost: float = INF
	if found:
		cost = graph.router.last_cost_m() + (0.0 if use_crossings else unpriced_wading_m(graph, hook, from, _path, _legs))
	if graph != _live:
		graph.router.clear_pairs()
	return cost


static func unpriced_wading_m(graph: GraphScript, hook: CrossingHookScript, from: Vector2, path: PackedVector2Array,
		legs: PackedInt32Array) -> float:
	"""What the router would have added for wading on a route planned without the water's hook (see ONE FOOTING): each
	surface leg's wading extra, at the weather's surface pace."""
	var scale: float = float(Rules.PERMILLE) / float(maxi(graph.surface_permille, 1))
	var total: float = 0.0
	var at := from
	for k: int in path.size():
		if k >= legs.size() or legs[k] == RouterScript.SURFACE_LEG:
			total += hook.wade_extra_m(at, path[k]) * scale
		at = path[k]
	return total


# --- reading it ----------------------------------------------------------------------------------------

func trip_known(k: int) -> bool:
	"""Whether trip `k` is planned, before and (with a proposal) after."""
	return before_known[k] == 1 and (proposal == PROPOSE_NONE or after_known[k] == 1)


func saving_m(k: int) -> float:
	"""How much shorter trip `k` is after (m at walk speed; 0 when it is not, INF when it had no route before)."""
	if not trip_known(k) or after_m[k] == INF:
		return 0.0
	if before_m[k] == INF:
		return INF
	return maxf(before_m[k] - after_m[k], 0.0)


static func pace_m_s(walk_speed: float, carrying: bool) -> float:
	"""The pace a trip is timed at: the walk, or a carrier's (about CARRY_WALK_FRACTION of its walk; the brain's carry
	clip sets the exact figure -- see WHAT IT IS NOT)."""
	return walk_speed * (BrainScript.CARRY_WALK_FRACTION if carrying else 1.0)


static func seconds_of(cost_m: float, pace: float) -> float:
	"""A cost in metres at walk speed as demo seconds at `pace` (INF stays INF)."""
	return INF if cost_m == INF or pace <= 0.0 else cost_m / pace


static func copy_network(from: GraphScript) -> GraphScript:
	"""A copy of network `from` to plan on (see BEFORE AND AFTER): every packed column, array and scalar duplicated, its
	own router and paths, the SHARED helpers the live ones."""
	var into := GraphScript.new()
	for prop: Dictionary in from.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: StringName = prop["name"]
		var value: Variant = from.get(name)
		var kind: int = typeof(value)
		if kind == TYPE_OBJECT or kind == TYPE_NIL or kind == TYPE_CALLABLE:
			continue
		into.set(name, value.duplicate(true) if kind == TYPE_ARRAY or kind == TYPE_DICTIONARY else _duplicate_of(value))
	for name: StringName in SHARED:
		into.set(name, from.get(name))
	return into


static func _duplicate_of(value: Variant) -> Variant:
	"""A packed array duplicated; a scalar as it is."""
	return value.duplicate() if typeof(value) >= TYPE_PACKED_BYTE_ARRAY else value
