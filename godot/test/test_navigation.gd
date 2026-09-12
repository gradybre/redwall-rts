extends "res://test/framework/test_case.gd"
## Coverage for ARCH-PATH-002/003/004/005 ground routing.
##
## READY_07 1.2's acceptance list drives this file: deterministic paths, ties and corners;
## disconnected cache starts; stale start/goal references; route storage full; quota exhaustion;
## and the separation of a queued path from a proven-unreachable one.
##
## WHY SO MANY STARTS SIT ON A MACRO CORNER, AND WHY THAT NO LONGER MATTERS. ARCH-PATH-003 used to
## route every request through its start macro's anchor -- the lowest passable cell of the macro,
## which is its top-left corner -- so a start that was NOT the anchor got an entry segment
## prepended and its published route was deliberately not the shortest path. Tests that check
## SEARCH results were therefore written from macro corners, where the anchor IS the start and the
## composed route was the pure A* answer.
##
## PATH-R02 removed that construction: every route now begins at the exact start it was requested
## from. The corner starts are kept because they also exercise PATH-R02 3 -- the case where the
## exact start coincides with the canonical anchor and the ordinary `variant_start=-1` descriptor
## is itself an exact-start route -- and the off-corner cases below now assert the optimum instead
## of the detour.

const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

## A macro corner well inside the authored land: cell (192,288), macro column 12, macro row 18.
const ANCHOR_X: int = 192
const ANCHOR_Z: int = 288

## Macro columns 0..18 and rows 4..31 of the authored map are entirely land: west of the river's
## cell columns 304..315, south of the coast band's cell rows 0..63, and clear of the lake.
const LAND_MACRO_COLUMNS: int = 19
const FIRST_LAND_MACRO_ROW: int = 4

## A long search whose first tick provably cannot finish: measured at 7373 expansions.
const LONG_START_X: int = 128
const LONG_START_Z: int = 128
const LONG_GOAL_X: int = 200
const LONG_GOAL_Z: int = 300

## East of the river, so reaching it from the west bank must find the ford: measured at 18530
## expansions, nine ticks of quota, which is what keeps a search observable while it runs.
const FAR_BANK_X: int = 440
const FAR_BANK_Z: int = 400

## ARCH-PATH-007: "The 1/4-real-second p95 target at 1x allows at most 7 complete 30 Hz tick
## intervals under a conservative one-tick enqueue phase, hence 7*2048=14336 expansions before a
## request misses the deadline". Both numbers are read from that paragraph, not chosen here.
const READINESS_DEADLINE_TICKS: int = 7
const TICKS_PER_SECOND: int = 30

## ARCH-PATH-008's first benchmark fixture is "256 distinct short routes". 256 is also the living
## population cap, so one uncached job route per resident is the whole colony asking at once.
const READINESS_BATCH: int = 256

static var _shared_world: SpatialWorldScript = null

var _world: SpatialWorldScript = null
var _directory: EntityDirectoryScript = null
var _navigation: NavigationScript = null
var _result: IntMathScript.IntResult = null
var _start: SpatialWorldScript.Location = null
var _goal: SpatialWorldScript.Location = null


func before_each() -> void:
	"""Bind a fresh directory and navigator to the shared read-only ground map."""
	if _shared_world == null:
		_shared_world = SpatialWorldScript.new()
	_bind(_shared_world)


func after_each() -> void:
	"""Drop everything but the shared map."""
	_world = null
	_directory = null
	_navigation = null
	_result = null
	_start = null
	_goal = null


func _bind(world: SpatialWorldScript) -> void:
	"""Point this test at one ground map with its own directory, navigator and scratch records."""
	_world = world
	_directory = EntityDirectoryScript.new()
	_navigation = NavigationScript.new(_directory, world)
	_result = IntMathScript.IntResult.new()
	_start = SpatialWorldScript.Location.new()
	_goal = SpatialWorldScript.Location.new()


func _carved_world() -> SpatialWorldScript:
	"""Build a private map this test may carve, and rebind the navigator to it."""
	_bind(SpatialWorldScript.new())
	return _world


func _cell(x: int, z: int) -> int:
	"""The cell index of a grid coordinate."""
	return z * SpatialWorldScript.CELLS_X + x


func _owner() -> Vector2i:
	"""A live directory entity to own a contact, so no endpoint is an unowned X/Z pair."""
	return _directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)


func _submit(start_cell: int, goal_cell: int, clearance: int) -> int:
	"""Submit one request between two freshly owned ground contacts; returns its record row."""
	return _submit_for(_directory.create(EntityDirectoryScript.KIND_JOB),
		_owner(), start_cell, _owner(), goal_cell, clearance)


func _submit_for(
	requester: Vector2i, start_owner: Vector2i, start_cell: int,
	goal_owner: Vector2i, goal_cell: int, clearance: int
) -> int:
	"""Bind both endpoints and submit, asserting the submission itself was accepted."""
	assert_true(_world.bind_ground_location(_start, start_cell, start_owner), "start binds")
	assert_true(_world.bind_ground_location(_goal, goal_cell, goal_owner), "goal binds")
	assert_true(
		_navigation.submit_request_into(requester, _start, _goal, clearance, 0, _result),
		"submission accepted (refusal was %s)" % _navigation.last_refusal())
	return _result.value


func _run(request: int, max_ticks: int) -> int:
	"""Service until the request settles or `max_ticks` pass; returns the ticks actually spent."""
	var tick: int = 0
	while _navigation.is_pending(request) and tick < max_ticks:
		tick += 1
		_navigation.service(tick)
	return tick


func _route(request: int) -> PackedInt32Array:
	"""The whole stored route of a ready request, start first and goal last."""
	var cells: PackedInt32Array = PackedInt32Array()
	if not _navigation.route_length_into(request, _result):
		return cells
	var length: int = _result.value
	for index: int in length:
		if _navigation.route_cell_into(request, index, _result):
			cells.append(_result.value)
	return cells


func _cost(request: int) -> int:
	"""The 10/14 cost of a ready request's route."""
	assert_true(_navigation.route_cost_into(request, _result), "the route has a cost")
	return _result.value


# --- the graph contract -------------------------------------------------------------------------

func test_graph_constants_match_arch_path_002() -> void:
	"""Expansion order, edge costs and the heuristic discount are copied from the contract."""
	assert_equal(NavigationScript.NEIGHBOUR_COUNT, 8, "eight neighbours")
	assert_equal(
		NavigationScript.NEIGHBOUR_DX, [0, 1, 0, -1, 1, 1, -1, -1] as Array[int],
		"N,E,S,W,NE,SE,SW,NW in X, with north at -Z")
	assert_equal(
		NavigationScript.NEIGHBOUR_DZ, [-1, 0, 1, 0, -1, 1, 1, -1] as Array[int],
		"N,E,S,W,NE,SE,SW,NW in Z")
	assert_equal(
		NavigationScript.NEIGHBOUR_COST, [10, 10, 10, 10, 14, 14, 14, 14] as Array[int],
		"10 orthogonal, 14 diagonal")
	assert_equal(NavigationScript.HEURISTIC_DIAGONAL_DISCOUNT, 6, "14 - 2*10 = -6 per diagonal")


func test_bounded_capacities_match_arch_path_005() -> void:
	"""2048 expansions a tick, 256 descriptors, 1048576 route cells, 8192 request records."""
	assert_equal(NavigationScript.EXPANSION_QUOTA_PER_TICK, 2048, "the shared quota is 2048")
	assert_equal(NavigationScript.ROUTE_DESCRIPTOR_CAPACITY, 256, "256 cache descriptors")
	assert_equal(NavigationScript.ROUTE_CELL_CAPACITY, 1048576, "1048576 route cells")
	assert_equal(NavigationScript.PATH_REQUEST_CAPACITY, 8192, "8192 path request records")
	assert_equal(
		NavigationScript.ROUTE_CELL_CAPACITY / SpatialWorldScript.CELL_COUNT, 4,
		"the arena holds exactly four worst-case 262144-cell paths, as ARCH-PATH-005 states")


# --- deterministic paths, ties and corners -------------------------------------------------------

func test_a_straight_run_costs_ten_per_cell() -> void:
	"""Ten orthogonal steps cost 100 and visit eleven cells, one per half metre."""
	var request: int = _submit(_cell(96, 96), _cell(106, 96), 1)
	assert_equal(_run(request, 8), 1, "a short search settles in one tick")
	assert_true(_navigation.is_ready(request), "the route is ready")
	assert_equal(_cost(request), 100, "ten orthogonal steps cost 10 each")
	assert_equal(_route(request).size(), 11, "eleven cells, endpoints included")


func test_a_diagonal_run_costs_fourteen_per_cell() -> void:
	"""Ten diagonal steps cost 140, not 100 and not a rounded Euclidean 141."""
	var request: int = _submit(_cell(112, 112), _cell(122, 122), 1)
	assert_equal(_run(request, 8), 1, "a short search settles in one tick")
	assert_equal(_cost(request), 140, "ten diagonal steps cost 14 each")
	assert_true(
		_navigation.reference_cost_into(_cell(112, 112), _cell(122, 122), 1, _result),
		"the Dijkstra reference agrees the pair is connected")
	assert_equal(_result.value, 140, "and agrees on the exact cost")


func test_astar_cost_equals_the_dijkstra_reference() -> void:
	"""SET-MOVE-001 4's correctness reference: the octile search must match `h=0` exactly."""
	for pair: Array in [[100, 98, 48], [106, 96, 100], [100, 96, 40], [104, 104, 112]]:
		var goal: int = _cell(pair[0] as int, pair[1] as int)
		var request: int = _submit(_cell(96, 96), goal, 1)
		assert_equal(_run(request, 16), 1, "the search settles")
		assert_equal(_cost(request), pair[2] as int, "A* cost is the known optimum")
		assert_true(
			_navigation.reference_cost_into(_cell(96, 96), goal, 1, _result), "reference runs")
		assert_equal(_result.value, pair[2] as int, "Dijkstra agrees")


func test_the_tie_break_path_is_stable() -> void:
	"""Many equal-cost routes exist here; the fixed expansion order must always pick the same one.

	Pinned cell for cell. This is the assertion that fails if the N,E,S,W,NE,SE,SW,NW expansion
	order, the `(f, cell_id)` heap order or the equal-g lower-predecessor rule is disturbed --
	all of which leave the COST unchanged and would otherwise be invisible.
	"""
	var request: int = _submit(_cell(96, 96), _cell(100, 98), 1)
	assert_equal(_run(request, 8), 1, "the search settles")
	assert_equal(
		_route(request),
		PackedInt32Array([_cell(96, 96), _cell(97, 96), _cell(98, 96), _cell(99, 97), _cell(100, 98)]),
		"the orthogonal steps are taken before the diagonals, every time")
	assert_equal(_cost(request), 48, "and the tie-broken route is still an optimal one")


func test_the_tie_break_path_is_stable_at_a_second_scale() -> void:
	"""The same rule at eight by four: four orthogonal steps, then four diagonals."""
	var request: int = _submit(_cell(160, 160), _cell(168, 164), 1)
	assert_equal(_run(request, 8), 1, "the search settles")
	var expected: PackedInt32Array = PackedInt32Array([
		_cell(160, 160), _cell(161, 160), _cell(162, 160), _cell(163, 160), _cell(164, 160),
		_cell(165, 161), _cell(166, 162), _cell(167, 163), _cell(168, 164)])
	assert_equal(_route(request), expected, "the tie-broken route is pinned cell for cell")
	assert_equal(_cost(request), 96, "four orthogonal at 10 plus four diagonal at 14")


func test_two_navigators_produce_identical_routes() -> void:
	"""Determinism across instances, not merely across repeats inside one warmed cache."""
	var first: int = _submit(_cell(96, 96), _cell(106, 100), 1)
	assert_equal(_run(first, 16), 1, "the first navigator settles")
	var cells: PackedInt32Array = _route(first)
	_bind(_shared_world)
	var second: int = _submit(_cell(96, 96), _cell(106, 100), 1)
	assert_equal(_run(second, 16), 1, "the second navigator settles")
	assert_equal(_route(second), cells, "a fresh navigator produces the identical cell chain")
	assert_true(cells.size() > 2, "and the route is a real one, not a degenerate pair")


func test_every_route_step_is_adjacent_and_passable() -> void:
	"""A stored route must be a legal unsmoothed cell chain, not a straight line through water."""
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z + 12), 1)
	assert_true(_run(request, 32) >= 1, "the search settles")
	var cells: PackedInt32Array = _route(request)
	var illegal: int = 0
	for index: int in cells.size():
		if not _world.cell_passes_clearance(cells[index], 1):
			illegal += 1
		if index == 0:
			continue
		var dx: int = absi(cells[index] % 512 - cells[index - 1] % 512)
		var dz: int = absi(cells[index] / 512 - cells[index - 1] / 512)
		if dx > 1 or dz > 1 or dx + dz == 0:
			illegal += 1
	assert_equal(illegal, 0, "every cell is passable and every step is one legal lattice move")
	assert_equal(cells[0], _cell(ANCHOR_X, ANCHOR_Z), "the route starts at the exact start")
	assert_equal(cells[cells.size() - 1], _cell(ANCHOR_X + 20, ANCHOR_Z + 12), "and ends at the goal")


func test_a_diagonal_is_refused_when_one_adjacent_orthogonal_is_blocked() -> void:
	"""ARCH-PATH-002's corner rule: no squeezing between two cells that touch only at a corner."""
	var world: SpatialWorldScript = _carved_world()
	assert_true(world.override_static_legality(_cell(ANCHOR_X + 1, ANCHOR_Z), false), "block east")
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z - 1), 1)
	assert_equal(_run(request, 8), 1, "the search settles")
	assert_equal(_cost(request), 20, "the body walks north then east, at 10 + 10")
	assert_equal(_route(request).size(), 3, "three cells, not the two of a corner cut")
	assert_true(
		_navigation.reference_cost_into(
			_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z - 1), 1, _result),
		"the reference runs on the carved map")
	assert_equal(_result.value, 20, "and the Dijkstra reference refuses the same corner")


func test_a_clearance_class_larger_than_the_gap_cannot_route_through_it() -> void:
	"""Clearance is enforced per step, with the class the caller supplies and no default."""
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 4, ANCHOR_Z), 4)
	assert_equal(_run(request, 8), 1, "a wide body still crosses open land")
	assert_true(_navigation.is_ready(request), "clearance class 4 is satisfied inland")
	var narrow: int = _submit(
		_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 4, ANCHOR_Z),
		SpatialWorldScript.MAX_CLEARANCE_CLASS)
	assert_equal(_run(narrow, 8), 1, "the oversized request settles too")
	assert_true(
		_navigation.is_proven_unreachable(narrow),
		"a body needing a 512-cell square fits nowhere on this map")


# --- queued, searching, unreachable: three different things --------------------------------------

func test_a_queued_request_has_proved_nothing() -> void:
	"""Before its first expansion a request is pending, and specifically not unreachable."""
	var request: int = _submit(_cell(96, 96), _cell(106, 96), 1)
	assert_true(_navigation.is_queued(request), "it is queued")
	assert_true(_navigation.is_pending(request), "queued counts as pending")
	assert_false(_navigation.is_proven_unreachable(request), "and proves nothing about the goal")
	assert_false(_navigation.is_ready(request), "it holds no route")
	assert_false(_navigation.is_blocked_on_route_storage(request), "and storage has refused nothing")
	assert_equal(_navigation.request_expansions(request), 0, "it has spent no quota")
	assert_equal(_navigation.request_phase_name(request), &"QUEUED", "its phase says so")


func test_the_tick_quota_is_2048_finalized_expansions() -> void:
	"""ARCH-PATH-002's global budget: one tick finalizes 2048 cells and then stops."""
	var request: int = _submit(
		_cell(LONG_START_X, LONG_START_Z), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	assert_equal(_navigation.service(1), 2048, "the first tick spends the whole quota")
	assert_equal(
		_navigation.request_expansions(request), 2048, "and all of it went to this one search")
	assert_equal(_navigation.expansions_remaining_this_tick(), 0, "nothing is left of the tick")
	assert_true(_navigation.has_active_search(), "the search is still holding the builder")


func test_a_quota_interrupted_search_is_pending_not_unreachable() -> void:
	"""The acceptance item: an interrupted search must never look like a proof of unreachability."""
	var request: int = _submit(
		_cell(LONG_START_X, LONG_START_Z), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	_navigation.service(1)
	assert_true(_navigation.is_pending(request), "it is still pending after one tick")
	assert_false(_navigation.is_proven_unreachable(request), "it has proved nothing")
	assert_false(_navigation.is_ready(request), "and exposes no traversable prefix")
	assert_false(_navigation.route_length_into(request, _result), "no route may be read from it")
	assert_equal(_navigation.last_refusal(), NavigationScript.REFUSE_NOT_READY, "refusal is named")
	assert_true(_run(request, 64) > 1, "and it completes on a later tick")
	assert_true(_navigation.is_ready(request), "reaching the goal it never proved unreachable")


func test_an_isolated_start_is_proven_unreachable() -> void:
	"""An emptied open set IS a proof, and it is reported as its own distinct phase."""
	var world: SpatialWorldScript = _carved_world()
	for offset: Array in [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]:
		var cell: int = _cell(ANCHOR_X + (offset[0] as int), ANCHOR_Z + (offset[1] as int))
		assert_true(world.override_static_legality(cell, false), "wall off one neighbour")
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(96, 96), 1)
	assert_equal(_run(request, 8), 1, "the search settles immediately")
	assert_true(_navigation.is_proven_unreachable(request), "the walled-in start proves it")
	assert_false(_navigation.is_pending(request), "and it is no longer pending")
	assert_equal(_navigation.request_phase_name(request), &"UNREACHABLE", "its phase says so")
	assert_equal(_navigation.request_expansions(request), 1, "one finalized cell was enough")


func test_an_impassable_endpoint_is_unreachable_without_searching() -> void:
	"""A goal in open water needs no expansions to settle, and is not a storage or stale refusal."""
	var lake: int = _cell(400, 264)
	assert_false(_world.is_walkable_cell(lake), "the chosen goal is open lake water")
	var request: int = _submit(_cell(96, 96), lake, 1)
	_navigation.service(1)
	assert_true(_navigation.is_proven_unreachable(request), "an impassable goal is unreachable")
	assert_equal(_navigation.request_expansions(request), 0, "without spending any quota")
	assert_equal(_navigation.storage_blocked_count(), 0, "and without blaming route storage")


func test_a_second_queued_request_waits_without_being_judged() -> void:
	"""When one search eats the whole tick the next request stays QUEUED, not failed."""
	var first: int = _submit(
		_cell(LONG_START_X, LONG_START_Z), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	var second: int = _submit(_cell(96, 96), _cell(106, 96), 1)
	_navigation.service(1)
	assert_true(_navigation.is_pending(first), "the first search is mid-flight")
	assert_true(_navigation.is_queued(second), "the second has not started")
	assert_equal(_navigation.request_expansions(second), 0, "it spent no quota")
	assert_false(_navigation.is_proven_unreachable(second), "and it proves nothing about its goal")
	assert_equal(_navigation.queued_count(), 1, "exactly one request is still waiting")


func test_queue_order_is_requester_persistent_id_then_generation() -> void:
	"""ARCH-PATH-002: "Queue requests by job persistent ID, then request generation"."""
	var first_job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var second_job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_true(
		_directory.get_persistent_id(first_job) < _directory.get_persistent_id(second_job),
		"the first job has the lower persistent id")
	var later: int = _submit_for(
		second_job, _owner(), _cell(LONG_START_X, LONG_START_Z),
		_owner(), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	var earlier: int = _submit_for(
		first_job, _owner(), _cell(LONG_START_X + 1, LONG_START_Z),
		_owner(), _cell(LONG_GOAL_X, LONG_GOAL_Z + 1), 1)
	_navigation.service(1)
	assert_true(
		_navigation.request_expansions(earlier) > 0,
		"the lower persistent id is serviced first even though it was submitted second")
	assert_equal(_navigation.request_expansions(later), 0, "the higher id waits its turn")


# --- generation-safe references ------------------------------------------------------------------

func test_submission_refuses_a_dead_requester_or_contact_owner() -> void:
	"""Nothing is queued against a reference the directory has already retired."""
	var dead: Vector2i = _owner()
	assert_true(_directory.destroy(dead), "retire the owner")
	assert_true(_world.bind_ground_location(_start, _cell(96, 96), dead), "the record still binds")
	assert_true(_world.bind_ground_location(_goal, _cell(106, 96), _owner()), "the goal binds")
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_false(
		_navigation.submit_request_into(job, _start, _goal, 1, 0, _result), "submission refuses")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_START_OWNER, "and names which end")
	assert_equal(_navigation.live_request_count(), 0, "no record was consumed by the refusal")


func test_a_goal_owner_retired_after_submission_settles_as_stale_goal() -> void:
	"""References are revalidated at SERVICE time, not only when the request was accepted."""
	var goal_owner: Vector2i = _owner()
	var request: int = _submit_for(
		_directory.create(EntityDirectoryScript.KIND_JOB), _owner(), _cell(96, 96),
		goal_owner, _cell(106, 96), 1)
	assert_true(_directory.destroy(goal_owner), "the destination is removed while queued")
	_navigation.service(1)
	assert_equal(_navigation.request_phase_name(request), &"STALE_GOAL", "it settles as stale goal")
	assert_false(_navigation.is_ready(request), "it holds no route")
	assert_false(_navigation.is_proven_unreachable(request), "and it proved nothing about the map")


func test_a_start_owner_and_a_requester_settle_as_their_own_stale_phases() -> void:
	"""Three references, three distinct stale phases, so a diagnostic names the real cause."""
	var start_owner: Vector2i = _owner()
	var first: int = _submit_for(
		_directory.create(EntityDirectoryScript.KIND_JOB), start_owner, _cell(96, 96),
		_owner(), _cell(106, 96), 1)
	assert_true(_directory.destroy(start_owner), "retire the start owner")
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var second: int = _submit_for(job, _owner(), _cell(96, 97), _owner(), _cell(106, 97), 1)
	assert_true(_directory.destroy(job), "retire the requester")
	_navigation.service(1)
	assert_equal(_navigation.request_phase_name(first), &"STALE_START", "start staleness is its own")
	assert_equal(
		_navigation.request_phase_name(second), &"STALE_REQUESTER", "so is requester staleness")


func test_a_reused_slot_with_a_new_generation_is_still_stale() -> void:
	"""BOTH halves of the EntityRef are compared. Comparing the slot alone passes this and is wrong.

	The retired owner's directory slot is handed straight back to a new entity, so a validator that
	looked only at `ref.x` would find a live row there and route to a destination that belongs to
	something else entirely.
	"""
	var goal_owner: Vector2i = _owner()
	var request: int = _submit_for(
		_directory.create(EntityDirectoryScript.KIND_JOB), _owner(), _cell(96, 96),
		goal_owner, _cell(106, 96), 1)
	assert_true(_directory.destroy(goal_owner), "retire the destination")
	var replacement: Vector2i = _owner()
	assert_equal(replacement.x, goal_owner.x, "the new entity reuses the very same slot")
	assert_true(replacement.y != goal_owner.y, "with a different generation")
	assert_true(_directory.is_valid(replacement), "and the new entity is live")
	_navigation.service(1)
	assert_equal(
		_navigation.request_phase_name(request), &"STALE_GOAL",
		"the request is still stale, because the generation half no longer matches")


func test_submission_refuses_a_location_minted_before_an_edit() -> void:
	"""A handle from an older map revision is not a current destination."""
	var world: SpatialWorldScript = _carved_world()
	var start_owner: Vector2i = _owner()
	assert_true(world.bind_ground_location(_start, _cell(96, 96), start_owner), "binds")
	assert_true(world.bind_ground_location(_goal, _cell(106, 96), _owner()), "binds")
	assert_true(world.override_static_legality(_cell(300, 300), false), "an unrelated edit lands")
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_false(
		_navigation.submit_request_into(job, _start, _goal, 1, 0, _result), "submission refuses")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_START_LOCATION, "and names the endpoint")


func test_submission_refuses_an_invalid_clearance_class() -> void:
	"""A clearance class is a caller input and is bounds-checked, never defaulted."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_true(_world.bind_ground_location(_start, _cell(96, 96), _owner()), "binds")
	assert_true(_world.bind_ground_location(_goal, _cell(106, 96), _owner()), "binds")
	assert_false(_navigation.submit_request_into(job, _start, _goal, 0, 0, _result), "class 0")
	assert_equal(_navigation.last_refusal(), NavigationScript.REFUSE_CLEARANCE, "refusal is named")
	assert_false(
		_navigation.submit_request_into(
			job, _start, _goal, SpatialWorldScript.MAX_CLEARANCE_CLASS + 1, 0, _result),
		"a class beyond the map width is refused too")
	assert_equal(_result.value, 0, "a refused submission carries no record row")


func test_submission_refuses_an_uncontracted_domain() -> void:
	"""Diving, canopy and underground each need their own contract before a route may be asked for."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_true(_world.bind_ground_location(_start, _cell(96, 96), _owner()), "binds")
	assert_true(_world.bind_ground_location(_goal, _cell(106, 96), _owner()), "binds")
	_goal.domain = SpatialWorldScript.DOMAIN_GROUND + 1
	assert_false(_navigation.submit_request_into(job, _start, _goal, 1, 0, _result), "refused")
	assert_equal(_navigation.last_refusal(), SpatialWorldScript.REFUSE_DOMAIN, "refusal is named")


# --- ARCH-PATH-003's macro bucket ----------------------------------------------------------------

func test_a_second_start_in_the_same_macro_gets_its_own_exact_start_route() -> void:
	"""PATH-R02 2: sharing a macro is not a reason to reuse another start's route.

	SUPERSEDES `test_a_macro_bucket_is_reused_by_a_second_start_in_the_same_macro`, which asserted
	the opposite -- that the second start paid only for a macro-local entry segment onto the first
	start's stored bucket. That reuse is the detour PATH-R02 removes, so the acceptance is
	inverted: the second start searches for itself, and what must be preserved is that its answer
	is optimal and that the first start's route is still in the cache, untouched.
	"""
	var first: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 30, ANCHOR_Z), 1)
	assert_true(_run(first, 16) >= 1, "the first request settles")
	var first_route: int = _navigation.request_route_id(first)
	var descriptors: int = _navigation.descriptor_in_use_count()
	var second: int = _submit(_cell(ANCHOR_X + 3, ANCHOR_Z + 3), _cell(ANCHOR_X + 30, ANCHOR_Z), 1)
	assert_true(_run(second, 16) >= 1, "the second request settles")
	assert_true(_navigation.is_ready(second), "and it is ready")
	assert_true(
		_navigation.request_route_id(second) != first_route,
		"on a route of its own, not the first start's")
	assert_equal(
		_route(second)[0], _cell(ANCHOR_X + 3, ANCHOR_Z + 3), "which begins at its actual start")
	assert_true(
		_navigation.reference_cost_into(
			_cell(ANCHOR_X + 3, ANCHOR_Z + 3), _cell(ANCHOR_X + 30, ANCHOR_Z), 1, _result),
		"the Dijkstra reference runs for that exact pair")
	assert_equal(_cost(second), _result.value, "and the published cost is the optimum, not a detour")
	assert_true(
		_navigation.descriptor_in_use_count() > descriptors, "both routes are cached separately")
	assert_true(_navigation.is_ready(first), "and the first request still holds its own route")


func test_the_retired_anchor_detour_fixture_now_costs_the_exact_optimum() -> void:
	"""PATH-R02's named fixture: cell (100,100) to (104,102) must cost 48, not 160.

	HISTORICAL EVIDENCE, PRESERVED DELIBERATELY. This method replaces
	`test_the_macro_anchor_detour_is_measured_not_hidden`, which asserted `_cost(request) == 160`
	and `_route(request)[4] == _cell(96, 96)`. Those were not wrong when written: implemented
	literally, ARCH-PATH-003 walked this start to its macro anchor at (96,96) first, and decision
	0053 measured the composed result at 160 against a true optimum of 48 -- a 3.33x overcharge on
	a four-step trip, bounded by the 16-cell macro and therefore worst on exactly the short job
	hops a settlement makes most.

	That acceptance is now OBSOLETE rather than merely relaxed, because PATH-R02 replaced the
	construction that produced it. It is not deleted quietly: the old numbers are recorded here so
	that a future reader who finds 160 in decision 0053 can see which test pinned it, what it
	proved and what superseded it. The replacement acceptance is the exact optimum plus Dijkstra
	agreement, which is strictly stronger -- 160 would fail it, and so would any other value.
	"""
	var request: int = _submit(_cell(100, 100), _cell(104, 102), 1)
	assert_equal(_run(request, 16), 1, "the request settles")
	assert_equal(_cost(request), 48, "two diagonals at 14 plus two orthogonals at 10")
	assert_true(
		_navigation.reference_cost_into(_cell(100, 100), _cell(104, 102), 1, _result), "reference")
	assert_equal(_result.value, 48, "and the independent Dijkstra agrees exactly")
	var route: PackedInt32Array = _route(request)
	assert_equal(route[0], _cell(100, 100), "the route begins at the actual start")
	assert_equal(route[route.size() - 1], _cell(104, 102), "and ends at the goal")
	assert_equal(route.size(), 5, "five cells: one start and four steps")
	assert_false(
		route.has(_cell(96, 96)), "and it never visits the macro anchor the old route detoured to")


func test_a_start_that_is_its_own_macro_anchor_reuses_the_anchor_descriptor() -> void:
	"""PATH-R02 3: a `variant_start=-1` route IS an exact-start route when the start is the anchor.

	It is the one case where the old bucket key survives, and it survives on merit rather than by
	exception: the stored route literally begins at the requested cell, so reusing it publishes the
	same cells an exact-start search would have found.
	"""
	var corner: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 12, ANCHOR_Z + 6)
	var first: int = _submit(corner, goal, 1)
	assert_true(_run(first, 16) >= 1, "the first request settles")
	var route: int = _navigation.request_route_id(first)
	assert_equal(
		_navigation.route_variant_start(route), -1,
		"an anchor start publishes the ordinary descriptor, not a start-keyed variant")
	var spent: int = _navigation.total_expansions()
	var second: int = _submit(corner, goal, 1)
	assert_equal(_run(second, 16), 1, "the second request settles at once")
	assert_equal(
		_navigation.request_route_id(second), route, "reusing the very same stored route")
	assert_equal(
		_navigation.total_expansions(), spent, "without spending a single further expansion")
	assert_equal(_route(second)[0], corner, "and it begins where it was asked to begin")


func test_an_exact_start_variant_is_reused_only_by_that_same_start() -> void:
	"""PATH-R02 2: the cache probe matches on the ACTUAL start, not on the macro it belongs to.

	Two starts three cells apart inside one macro, heading to one goal. The first builds a variant;
	the second must not be handed it. Reusing it is precisely the (100,100) detour, generalised.
	"""
	var goal: int = _cell(ANCHOR_X + 24, ANCHOR_Z + 4)
	var here: int = _cell(ANCHOR_X + 5, ANCHOR_Z + 5)
	var there: int = _cell(ANCHOR_X + 8, ANCHOR_Z + 2)
	var first: int = _submit(here, goal, 1)
	assert_true(_run(first, 16) >= 1, "the first request settles")
	var variant: int = _navigation.request_route_id(first)
	assert_equal(_navigation.route_variant_start(variant), here, "keyed by its exact start")
	var spent: int = _navigation.total_expansions()
	var repeat: int = _submit(here, goal, 1)
	assert_equal(_run(repeat, 16), 1, "the same start settles at once")
	assert_equal(_navigation.request_route_id(repeat), variant, "on the cached variant")
	assert_equal(_navigation.total_expansions(), spent, "for no expansions at all")
	var other: int = _submit(there, goal, 1)
	assert_true(_run(other, 16) >= 1, "the neighbouring start settles too")
	assert_true(
		_navigation.request_route_id(other) != variant,
		"but NOT by borrowing the first start's route")
	assert_true(
		_navigation.total_expansions() > spent, "it paid for its own search, as PATH-R02 requires")
	assert_equal(_route(other)[0], there, "and its route begins at its own start")


func test_a_goal_back_past_the_anchor_is_never_retraced() -> void:
	"""Decision 0053's second symptom: a goal behind the start used to be reached by going forward.

	Start (110,110) and goal (98,98) share macro (6,6), whose anchor is its corner (96,96). Under
	anchor composition the published route ran (110,110) -> (96,96) -> (98,98): it walked PAST the
	goal to the anchor and then back over cells it had already visited, for 224 against an optimum
	of 168. An exact-start search cannot produce that shape at all.
	"""
	var start: int = _cell(110, 110)
	var goal: int = _cell(98, 98)
	var request: int = _submit(start, goal, 1)
	assert_true(_run(request, 16) >= 1, "the request settles")
	assert_true(_navigation.reference_cost_into(start, goal, 1, _result), "the reference runs")
	assert_equal(_result.value, 168, "twelve diagonal steps")
	assert_equal(_cost(request), 168, "and the published route costs exactly that")
	var route: PackedInt32Array = _route(request)
	assert_false(route.has(_cell(96, 96)), "it does not visit the anchor beyond the goal")
	var seen: Dictionary = {}
	for cell: int in route:
		assert_false(seen.has(cell), "and it never visits any cell twice")
		seen[cell] = true


func test_no_request_enters_the_retired_searching_local_phase() -> void:
	"""PATH-R02: "Stop admitting new requests through SEARCHING_LOCAL". Watch a search that used to.

	The start is three cells off its macro corner with a goal across the river, so under anchor
	composition its first serviced tick was spent on the macro-local entry segment. Every tick of
	this request is now inspected, and SEARCHING_LOCAL must appear in none of them.
	"""
	var request: int = _submit(
		_cell(ANCHOR_X + 3, ANCHOR_Z + 3), _cell(FAR_BANK_X, FAR_BANK_Z), 1)
	var observed: Dictionary = {}
	var tick: int = 0
	while _navigation.is_pending(request) and tick < 64:
		tick += 1
		_navigation.service(tick)
		observed[_navigation.request_phase_name(request)] = true
	assert_true(_navigation.is_ready(request), "the request finishes")
	assert_true(tick > 1, "after more than one tick, so mid-search phases were actually sampled")
	assert_false(
		observed.has(&"SEARCHING_LOCAL"), "and it never passed through the retired local phase")
	assert_true(observed.has(&"SEARCHING_VARIANT"), "it ran the exact-start search instead")
	assert_equal(
		_route(request)[0], _cell(ANCHOR_X + 3, ANCHOR_Z + 3), "beginning at the exact start")


func test_every_start_in_one_macro_agrees_with_dijkstra() -> void:
	"""PATH-R02's "test multiple starts in one macro": all sixteen must be exactly optimal.

	Sixteen starts on the leading diagonal of macro (12,18) to one shared goal outside it. Under
	anchor composition fifteen of the sixteen would have been overcharged by their walk to the
	corner; each is now compared against the independent `h=0` reference for its own pair.
	"""
	var goal: int = _cell(ANCHOR_X + 40, ANCHOR_Z + 9)
	for step: int in SpatialWorldScript.MACRO_CELLS:
		var start: int = _cell(ANCHOR_X + step, ANCHOR_Z + step)
		var request: int = _submit(start, goal, 1)
		assert_true(_run(request, 16) >= 1, "the request settles")
		var published: int = _cost(request)
		assert_true(_navigation.reference_cost_into(start, goal, 1, _result), "the reference runs")
		assert_equal(published, _result.value, "A* matches Dijkstra for this exact start")
		assert_equal(_route(request)[0], start, "and the route begins at it")


func test_route_semantics_version_two_refuses_anchor_composition_state() -> void:
	"""PATH-R02: retire the old state through an explicit version, never a silent reinterpretation.

	A version 1 descriptor table has the same sixteen columns of the same widths as a version 2
	one, so shape proves nothing. The gate is a number, and it refuses by name.
	"""
	assert_equal(NavigationScript.ROUTE_SEMANTICS_VERSION, 2, "PATH-R02 is version 2")
	assert_equal(
		NavigationScript.ROUTE_SEMANTICS_VERSION_ANCHOR_COMPOSITION, 1,
		"anchor composition was version 1")
	assert_equal(NavigationScript.route_semantics_version(), 2, "and the module publishes it")
	assert_equal(
		NavigationScript.refuse_route_semantics(2), NavigationScript.REFUSE_NONE,
		"its own version continues")
	assert_equal(
		NavigationScript.refuse_route_semantics(1), NavigationScript.REFUSE_ROUTE_SEMANTICS,
		"a version 1 payload is refused, not migrated")
	assert_equal(
		NavigationScript.refuse_route_semantics(3), NavigationScript.REFUSE_ROUTE_SEMANTICS,
		"and so is a version this module has never published")


func test_the_expansion_quota_is_unchanged_by_path_r02() -> void:
	"""PATH-R02 holds the quota fixed, and ARCH-PATH-007's deadline arithmetic depends on it.

	"All finalized expansions share the existing 2048/tick quota; do not add a 'small query'
	budget." ARCH-PATH-007 derives the readiness deadline from that number: at most seven complete
	30 Hz intervals inside 0.25 real seconds, hence 7*2048 = 14336 expansions. Raising the quota to
	absorb exact-start search would silently rewrite that derivation.
	"""
	assert_equal(
		NavigationScript.EXPANSION_QUOTA_PER_TICK, 2048, "still 2048 finalized expansions a tick")
	assert_equal(
		NavigationScript.EXPANSION_QUOTA_PER_TICK * READINESS_DEADLINE_TICKS, 14336,
		"which is ARCH-PATH-007's 14336-expansion deadline budget")
	var request: int = _submit(
		_cell(LONG_START_X, LONG_START_Z), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	assert_equal(
		_navigation.service(1), NavigationScript.EXPANSION_QUOTA_PER_TICK,
		"and one busy tick spends exactly the quota, never more")
	assert_true(_navigation.is_pending(request), "leaving the long search still running")


func test_a_disconnected_macro_start_gets_its_own_exact_start_variant() -> void:
	"""ARCH-PATH-003: "Never reuse a route across disconnected local components"."""
	var world: SpatialWorldScript = _carved_world()
	var corner_x: int = ANCHOR_X + 15
	var corner_z: int = ANCHOR_Z + 15
	for offset: Array in [[-1, 0], [-1, -1], [0, -1]]:
		var cell: int = _cell(corner_x + (offset[0] as int), corner_z + (offset[1] as int))
		assert_true(world.override_static_legality(cell, false), "cut the in-macro neighbours")
	var request: int = _submit(_cell(corner_x, corner_z), _cell(ANCHOR_X + 40, ANCHOR_Z + 20), 1)
	assert_true(_run(request, 32) >= 1, "the request settles")
	assert_true(_navigation.is_ready(request), "it still finds a route, around the outside")
	var route: int = _navigation.request_route_id(request)
	assert_equal(
		_navigation.route_variant_start(route), _cell(corner_x, corner_z),
		"and the stored route is keyed by the exact start, not by the macro bucket")
	assert_equal(_route(request)[0], _cell(corner_x, corner_z), "it begins at the real start")


func test_a_quota_interrupted_exact_start_variant_is_pending_too() -> void:
	"""The third search stage must be pending mid-flight, exactly like the other two.

	Added after a mutation survived: narrowing `is_pending()` to exclude PHASE_SEARCHING_VARIANT
	left the suite green, because every existing variant search finished inside a single tick and
	was therefore never observed while it was running. A disconnected macro start with a distant
	goal keeps one alive across ticks, and a variant search that is not "pending" is a body whose
	route request has silently stopped counting as in progress.
	"""
	var world: SpatialWorldScript = _carved_world()
	var corner_x: int = ANCHOR_X + 15
	var corner_z: int = ANCHOR_Z + 15
	for offset: Array in [[-1, 0], [-1, -1], [0, -1]]:
		var cell: int = _cell(corner_x + (offset[0] as int), corner_z + (offset[1] as int))
		assert_true(world.override_static_legality(cell, false), "cut the in-macro neighbours")
	var request: int = _submit(
		_cell(corner_x, corner_z), _cell(FAR_BANK_X, FAR_BANK_Z), 1)
	_navigation.service(1)
	assert_equal(
		_navigation.request_phase_name(request), &"SEARCHING_VARIANT",
		"the macro-local entry failed, so the exact-start search is what is running")
	assert_true(_navigation.is_pending(request), "and a running search is pending")
	assert_false(_navigation.is_proven_unreachable(request), "it has proved nothing")
	assert_equal(
		_navigation.request_expansions(request), 2048,
		"the local and variant stages shared one tick quota between them")
	assert_true(_run(request, 64) > 1, "and it finishes on a later tick")
	assert_true(_navigation.is_ready(request), "with a real route")


func test_a_start_that_is_its_own_goal_gets_a_one_cell_route() -> void:
	"""ARCH-PATH-004's goal is an exact cell; a body already on it has a route of length one."""
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X, ANCHOR_Z), 1)
	assert_equal(_run(request, 4), 1, "it settles at once")
	assert_true(_navigation.is_ready(request), "and it is ready")
	assert_equal(_route(request), PackedInt32Array([_cell(ANCHOR_X, ANCHOR_Z)]), "one cell")
	assert_equal(_cost(request), 0, "costing nothing")


# --- bounded route storage ------------------------------------------------------------------------

func test_route_storage_full_is_its_own_state_not_an_unreachable_goal() -> void:
	"""ARCH-PATH-005: when every descriptor is referenced a found route is BLOCKED, never lost."""
	var held: Array[int] = _fill_every_descriptor()
	assert_equal(
		_navigation.descriptor_in_use_count(), NavigationScript.ROUTE_DESCRIPTOR_CAPACITY,
		"all 256 descriptors are in use")
	var overflow: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z), 1)
	_run(overflow, 8)
	assert_true(
		_navigation.is_blocked_on_route_storage(overflow), "the 257th route has nowhere to live")
	assert_false(_navigation.is_proven_unreachable(overflow), "which is NOT a claim about the map")
	assert_equal(_navigation.storage_blocked_count(), 1, "and it is counted as a storage refusal")
	assert_equal(held.size(), NavigationScript.ROUTE_DESCRIPTOR_CAPACITY, "256 routes are held")


func test_a_referenced_route_is_never_evicted_to_make_room() -> void:
	"""Referenced routes cannot be evicted, so the blocked request cannot steal a live one."""
	var held: Array[int] = _fill_every_descriptor()
	var overflow: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z), 1)
	_run(overflow, 8)
	var still_ready: int = 0
	for request: int in held:
		if _navigation.is_ready(request):
			still_ready += 1
	assert_equal(still_ready, held.size(), "every held route survived the storage pressure")
	assert_equal(
		_navigation.route_reference_count(_navigation.request_route_id(held[0])), 1,
		"and each is held by exactly one request")


func test_releasing_a_request_frees_its_route_for_the_next_one() -> void:
	"""Dropping the last reference makes a descriptor evictable, and the blocked case then clears."""
	var held: Array[int] = _fill_every_descriptor()
	var blocked: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z), 1)
	_run(blocked, 8)
	assert_true(_navigation.is_blocked_on_route_storage(blocked), "blocked while everything is held")
	assert_true(_navigation.release_request(held[0]), "release one holder")
	var retry: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 1, ANCHOR_Z), 1)
	_run(retry, 8)
	assert_true(_navigation.is_ready(retry), "the next request finds room by eviction")
	assert_equal(
		_navigation.descriptor_in_use_count(), NavigationScript.ROUTE_DESCRIPTOR_CAPACITY,
		"and the pool is full again, never grown")


func _fill_every_descriptor() -> Array[int]:
	"""Submit one short macro-anchor route per macro until all 256 descriptors are referenced."""
	var requests: Array[int] = []
	var made: int = 0
	while made < NavigationScript.ROUTE_DESCRIPTOR_CAPACITY:
		var column: int = made % LAND_MACRO_COLUMNS
		var row: int = FIRST_LAND_MACRO_ROW + made / LAND_MACRO_COLUMNS
		var corner: int = _cell(column * 16, row * 16)
		var request: int = _submit(corner, corner + 1, 1)
		_run(request, 4)
		requests.append(request)
		made += 1
	return requests


func test_a_new_map_revision_retires_every_route_built_before_it() -> void:
	"""ARCH-PATH-005 invalidation, including releasing the arena the retired routes occupied."""
	var world: SpatialWorldScript = _carved_world()
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z), 1)
	assert_true(_run(request, 16) >= 1, "the route is built")
	assert_true(_navigation.is_ready(request), "and ready")
	assert_true(_navigation.arena_used() > 0, "with cells committed in the arena")
	assert_true(world.override_static_legality(_cell(10, 100), false), "an edit lands somewhere")
	_navigation.service(2)
	assert_equal(
		_navigation.request_phase_name(request), &"STALE_REVISION", "the holder is retired")
	assert_equal(_navigation.descriptor_in_use_count(), 0, "every stale descriptor was freed")
	assert_equal(_navigation.arena_used(), 0, "and the arena was compacted back to empty")
	assert_equal(_navigation.served_revision(), world.current_map_revision(), "on the new revision")


func test_cancelling_a_ready_request_releases_its_route() -> void:
	"""Cancellation must drop the reference exactly once, so the descriptor becomes evictable."""
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 8, ANCHOR_Z), 1)
	assert_true(_run(request, 8) >= 1, "the route is built")
	var route: int = _navigation.request_route_id(request)
	assert_equal(_navigation.route_reference_count(route), 1, "one holder")
	assert_true(_navigation.cancel_request(request), "cancel it")
	assert_equal(_navigation.route_reference_count(route), 0, "the reference is gone")
	assert_equal(_navigation.request_phase_name(request), &"CANCELLED", "and the phase says so")
	assert_true(_navigation.release_request(request), "the record returns to the free list")
	assert_equal(_navigation.live_request_count(), 0, "leaving no live records")


func test_request_row_operations_refuse_a_row_that_is_not_live() -> void:
	"""No sentinel row: an operation on an unallocated record refuses by name."""
	assert_false(_navigation.cancel_request(0), "row 0 is not allocated")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_INVALID_REQUEST, "refusal is named")
	assert_false(_navigation.release_request(-1), "a negative row is refused")
	assert_false(_navigation.route_length_into(0, _result), "and no route may be read from it")
	assert_equal(_navigation.request_phase(999999), NavigationScript.PHASE_FREE, "out of range is free")
	assert_false(_navigation.is_request_row(0), "the predicate agrees")


func test_reading_a_route_index_out_of_range_refuses() -> void:
	"""A route index past the end refuses rather than returning the goal again."""
	var request: int = _submit(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 4, ANCHOR_Z), 1)
	assert_true(_run(request, 8) >= 1, "the route is built")
	assert_true(_navigation.route_length_into(request, _result), "the length reads")
	var length: int = _result.value
	assert_false(_navigation.route_cell_into(request, length, _result), "one past the end refuses")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_INVALID_INDEX, "refusal is named")
	assert_false(_navigation.route_cell_into(request, -1, _result), "a negative index refuses")


# --- PATH-R02 readiness remeasurement, REQ-SET-163 and ARCH-PATH-007/008 -------------------------

func _p95_nearest_rank(values: PackedInt32Array) -> int:
	"""ARCH-PATH-007's nearest-rank p95: the `ceil_div(95*N,100)`-th smallest value, 1-based."""
	var sorted_values: PackedInt32Array = values.duplicate()
	sorted_values.sort()
	var rank: int = (95 * sorted_values.size() + 99) / 100
	return sorted_values[rank - 1]


func _short_route_batch() -> Array[int]:
	"""Submit ARCH-PATH-008's 256 distinct short routes, none of them starting on a macro anchor.

	One request per macro of the all-land block, offset five cells in from the corner so every one
	of them takes PATH-R02's exact-start search rather than the anchor-descriptor path. Eight
	cells east and four south is a nine-cell route, the length of an ordinary job hop.
	"""
	var requests: Array[int] = []
	for index: int in READINESS_BATCH:
		var column: int = index % LAND_MACRO_COLUMNS
		var macro_row: int = FIRST_LAND_MACRO_ROW + index / LAND_MACRO_COLUMNS
		var start_x: int = column * SpatialWorldScript.MACRO_CELLS + 5
		var start_z: int = macro_row * SpatialWorldScript.MACRO_CELLS + 5
		requests.append(
			_submit(_cell(start_x, start_z), _cell(start_x + 8, start_z + 4), 1))
	return requests


func _ticks_to_ready(requests: Array[int], max_ticks: int) -> PackedInt32Array:
	"""Service until every request settles, returning the tick each one became ready on."""
	var settled: PackedInt32Array = PackedInt32Array()
	settled.resize(requests.size())
	settled.fill(-1)
	var outstanding: int = requests.size()
	var tick: int = 0
	while outstanding > 0 and tick < max_ticks:
		tick += 1
		_navigation.service(tick)
		for index: int in requests.size():
			if settled[index] < 0 and not _navigation.is_pending(requests[index]):
				settled[index] = tick
				outstanding -= 1
	return settled


func test_job_route_readiness_p95_after_exact_start_search() -> void:
	"""REQ-SET-163's "job route ready at 1x p95 < 0.25 real seconds", REMEASURED under PATH-R02.

	PATH-R02 requires this because cross-start cache reuse decreases: 256 residents in 256
	different macros used to pay one full anchor search each anyway, but a second body in an
	already-searched macro used to pay almost nothing and now pays for its own search. The whole
	colony asking at once is the fixture ARCH-PATH-008 names, and the number below is measured,
	not asserted from the budget. THIS IS NOT AN ARCH-PATH-008 PASS CLAIM: that gate also needs the
	256-expansion burst and the labyrinth, on the qualification hardware.
	"""
	var requests: Array[int] = _short_route_batch()
	var settled: PackedInt32Array = _ticks_to_ready(requests, 256)
	for index: int in requests.size():
		assert_true(_navigation.is_ready(requests[index]), "every route in the batch is ready")
	var p95_ticks: int = _p95_nearest_rank(settled)
	print("[PATH-R02 readiness] %d short routes, p95 %d ticks, worst %d ticks, %d expansions"
		% [requests.size(), p95_ticks, _p95_nearest_rank(settled), _navigation.total_expansions()])
	assert_equal(p95_ticks, 3, "measured: p95 3 ticks, 0.100 real seconds at 30 ticks a second")
	assert_equal(
		_navigation.total_expansions(), 6400, "measured: 6400 expansions, 25 for each route")
	assert_equal(
		_navigation.storage_blocked_count(), 0,
		"and no route was refused storage, because one request now needs one descriptor")
	assert_true(p95_ticks >= 1, "a tick is the floor: nothing is ready before it is serviced")
	assert_true(
		p95_ticks <= READINESS_DEADLINE_TICKS,
		"p95 %d ticks is inside ARCH-PATH-007's 7-tick (0.2333 s) allowance" % p95_ticks)
	assert_true(
		p95_ticks * 1000 < 250 * TICKS_PER_SECOND,
		"and inside REQ-SET-163's 0.25 real seconds at 30 ticks a second")


func test_a_repeated_job_route_is_ready_on_its_first_serviced_tick() -> void:
	"""ARCH-PATH-008's "cached routes" fixture: the exact-start cache still removes the search.

	PATH-R02 narrows what may be reused; it does not weaken reuse by the same start. A body sent
	back to a destination it already has a route to is ready on tick one for zero expansions.
	"""
	var requests: Array[int] = _short_route_batch()
	_ticks_to_ready(requests, 256)
	var spent: int = _navigation.total_expansions()
	for request: int in requests:
		assert_true(_navigation.release_request(request), "release the first batch")
	var repeats: Array[int] = _short_route_batch()
	var settled: PackedInt32Array = _ticks_to_ready(repeats, 16)
	assert_equal(
		_navigation.total_expansions(), spent, "the repeat batch ran no search at all")
	assert_equal(_p95_nearest_rank(settled), 1, "and its p95 readiness is one tick")


func test_the_measured_price_of_losing_cross_start_reuse() -> void:
	"""PATH-R02: "Cross-start cache reuse decreases... report latency regressions openly."

	This is the regression, isolated and pinned rather than left to be rediscovered -- the same
	role `test_the_macro_anchor_detour_is_measured_not_hidden` played for the detour it replaced.
	Sixty-four bodies standing in one macro and sent to one distant goal used to cost one full
	anchor search plus sixty-three tiny entry segments. They now cost sixty-four full searches.

	MEASURED, both algorithms, same fixture, same map, deterministic tick counts:

	    anchor composition (v1):  p95  1 tick,     1232 expansions, 127 descriptors
	    exact-start       (v2):  p95 24 ticks,   50064 expansions,  64 descriptors

	24 ticks is 0.800 real seconds at 30 ticks a second, which BREACHES REQ-SET-163's 0.25 s and
	ARCH-PATH-007's seven-tick allowance. It is disclosed here as ARCH-PATH-008's "failure scenes
	disclosed" rather than hidden, and PATH-R02 forbids the obvious patch: the quota stays at 2048
	and no small-query budget is added. What the fixture buys is correctness -- every one of the
	sixty-four routes is now the exact optimum for its own start, which none but the anchor's was
	before, and descriptor pressure halves.

	If a later change makes this fixture faster, this test fails. That is intended: replace the
	number with the new measurement and say what changed, exactly as PATH-R02 did to the 160.
	"""
	var goal: int = _cell(ANCHOR_X + 60, ANCHOR_Z + 40)
	var requests: Array[int] = []
	for index: int in 64:
		requests.append(_submit(_cell(ANCHOR_X + index % 8, ANCHOR_Z + index / 8), goal, 1))
	var settled: PackedInt32Array = _ticks_to_ready(requests, 256)
	var p95_ticks: int = _p95_nearest_rank(settled)
	print("[PATH-R02 reuse loss] 64 starts in one macro, p95 %d ticks, %d expansions"
		% [p95_ticks, _navigation.total_expansions()])
	assert_equal(p95_ticks, 24, "measured at 24 ticks, against 1 under anchor composition")
	assert_true(
		p95_ticks > READINESS_DEADLINE_TICKS,
		"which is openly outside ARCH-PATH-007's deadline, not quietly inside it")
	assert_equal(_navigation.total_expansions(), 50064, "for 50064 expansions, against 1232")
	assert_equal(
		_navigation.descriptor_in_use_count(), 64, "one descriptor each, against 127 before")
	for index: int in [0, 17, 63]:
		var start: int = _cell(ANCHOR_X + (index as int) % 8, ANCHOR_Z + (index as int) / 8)
		assert_true(_navigation.reference_cost_into(start, goal, 1, _result), "the reference runs")
		assert_equal(
			_cost(requests[index as int]), _result.value,
			"and what the expansions bought is an exactly optimal route for that start")


func test_the_batch_replays_identically_on_a_second_navigator() -> void:
	"""Determinism across the whole exact-start batch, which a save replay has to reproduce.

	No section 9 writer exists yet, so this is the strongest replay claim available: two navigators
	given the same submissions in the same order must publish byte-identical routes and spend the
	same expansions on the same ticks. A route that varied run to run could not be serialized
	meaningfully in the first place.
	"""
	var first: Array[int] = _short_route_batch()
	var first_ticks: PackedInt32Array = _ticks_to_ready(first, 256)
	var first_routes: Array[PackedInt32Array] = []
	for request: int in first:
		first_routes.append(_route(request))
	var spent: int = _navigation.total_expansions()
	_bind(_shared_world)
	var second: Array[int] = _short_route_batch()
	var second_ticks: PackedInt32Array = _ticks_to_ready(second, 256)
	assert_equal(second_ticks, first_ticks, "the same requests are ready on the same ticks")
	assert_equal(_navigation.total_expansions(), spent, "for the same total expansions")
	for index: int in second.size():
		assert_equal(_route(second[index]), first_routes[index], "and on identical cells")


# --- the Dijkstra correctness reference -----------------------------------------------------------

func test_the_reference_refuses_while_a_search_holds_the_builder() -> void:
	"""The reference shares the A* builder, so it refuses rather than corrupting a live search."""
	var request: int = _submit(
		_cell(LONG_START_X, LONG_START_Z), _cell(LONG_GOAL_X, LONG_GOAL_Z), 1)
	_navigation.service(1)
	assert_true(_navigation.has_active_search(), "a search is mid-flight")
	assert_false(
		_navigation.reference_cost_into(_cell(96, 96), _cell(97, 96), 1, _result), "refused")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_REFERENCE_BUSY, "refusal is named")
	assert_true(_navigation.is_pending(request), "and the live search is undisturbed")


func test_the_reference_spends_none_of_the_tick_quota() -> void:
	"""The reference is a validation tool: it must not compete with gameplay searches for quota."""
	var before: int = _navigation.total_expansions()
	assert_true(
		_navigation.reference_cost_into(_cell(96, 96), _cell(104, 100), 1, _result), "it runs")
	assert_equal(
		_navigation.total_expansions(), before, "and charged nothing to the shared expansion budget")


func test_the_reference_refuses_an_unreachable_pair_explicitly() -> void:
	"""No in-band cost means "unreachable"; the reference refuses with its own code."""
	var world: SpatialWorldScript = _carved_world()
	for offset: Array in [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]:
		var cell: int = _cell(ANCHOR_X + (offset[0] as int), ANCHOR_Z + (offset[1] as int))
		assert_true(world.override_static_legality(cell, false), "wall off one neighbour")
	assert_false(
		_navigation.reference_cost_into(_cell(ANCHOR_X, ANCHOR_Z), _cell(96, 96), 1, _result),
		"the walled-in start reaches nothing")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_REFERENCE_UNREACHABLE, "named refusal")
	assert_equal(_result.value, 0, "and the refused result carries no cost")


func test_the_reference_refuses_bad_inputs() -> void:
	"""Out-of-map cells and impossible clearance classes refuse before the builder is touched."""
	assert_false(_navigation.reference_cost_into(-1, _cell(96, 96), 1, _result), "bad start")
	assert_equal(_navigation.last_refusal(), NavigationScript.REFUSE_INVALID_CELL, "named")
	assert_false(
		_navigation.reference_cost_into(_cell(96, 96), SpatialWorldScript.CELL_COUNT, 1, _result),
		"bad goal")
	assert_false(
		_navigation.reference_cost_into(_cell(96, 96), _cell(97, 96), 0, _result), "bad class")
	assert_equal(_navigation.last_refusal(), NavigationScript.REFUSE_CLEARANCE, "named")
