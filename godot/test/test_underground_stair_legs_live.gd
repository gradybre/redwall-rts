extends "res://test/underground_host_case.gd"
## Decision 2091 (phase 1): the stair leg helper against the real M5 graph. The committed underground_flight checkpoint
## at tick 75,000 (decision 1240; the last point before P-2045-14's late-save limit) has module 0's stair carry
## published and landings 1-3 built. On it:
## - the empty way up from the deepest landing's F' to X resolves leg by leg in one pass, every certificate admits its
##   row, the pass charges one check an edge row and one a leg, and every leg takes the very edge a first-match scan by
##   stops and mode takes (Contacts' per-leg rule, with the mode added);
## - the loaded way down resolves on module 0 (its 17 CARRY edges, decision 1972) and stops at the sill's descent onto
##   landing 1's F, which nothing publishes until phase 2 (P-2091-4 (a));
## - a loaded descent takes the CARRY edge although its WALK twin joins the same two stops.

const Legs := preload("res://scripts/core/underground_stair_legs.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const RoutesOwner := preload("res://scripts/core/underground_routes.gd")
const ProfilesOwner := preload("res://scripts/core/underground_profiles.gd")
const Space := preload("res://scripts/core/room_space.gd")
const START_TICK: int = 75000
## Module 0's loaded legs that tick 75,000 publishes: H -> A(L0) and the seven descents to the sill.
const MODULE_ZERO_CARRY_LEGS: int = 8

var _o: Session.Retirement.Owners = null
var _stops: StairPath.Stops = null


func _load() -> bool:
	"""Load the flight at tick 75,000 and read its live stair stops through the foreman's own collector."""
	_checkpoint_loaded = true
	var point: String = Recipes.flight_point(Recipes.FLIGHT_TICKS.find(START_TICK))
	var refusal: String = Store.load_into(_host, GameManager, Recipes.FLIGHT, point, _content)
	assert_equal(refusal, "", "the underground_flight %s checkpoint loads" % point)
	if refusal != "": return false
	_o = _host.underground_session()._retirement_owners
	_stops = _host.underground_entry()._foreman._stops()
	return true


func after_each() -> void:
	"""Drop the borrowed owners before the host is freed."""
	_o = null
	_stops = null
	super.after_each()


func _deepest_landing() -> int:
	"""The deepest landing whose F' is live."""
	var deepest: int = 0
	for landing: int in range(1, StairPath.MODULES + 1):
		if _stops.fp[landing] != Vector2i(-1, 0): deepest = landing
	return deepest


func _first_match(legs: PackedInt32Array, leg: int) -> Vector2i:
	"""The reference rule: scan the edge table in row order for the first live edge with the leg's stops and its row's
	mode whose metadata reads (Contacts' `_row_path_refusal` scan, with the mode)."""
	var routes: RoutesOwner = _o.routes
	var edge: RoutesOwner.Edge = RoutesOwner.Edge.new()
	var mode: int = _o.profiles._live.fields[ProfilesOwner.F_MODE * _o.profiles._profile_capacity + Legs.row_of(legs, leg)]
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[RoutesOwner.E_GENERATION * routes._edge_capacity + row])
		if routes.edge_metadata_into(ref, edge) != &"": continue
		if edge.from_location == Legs.from_of(legs, leg) and edge.to_location == Legs.to_of(legs, leg) and edge.mode == mode:
			return ref
	return Vector2i(-1, 0)


func test_the_empty_way_up_resolves_in_one_pass_and_every_certificate_admits_its_row() -> void:
	"""From the deepest built landing's F' to X: every leg resolved, each certificate admits its row, the spend is one
	check an edge row plus one a leg, and each leg's edge is the reference scan's."""
	if not _load(): return
	var landing: int = _deepest_landing()
	assert_equal(landing, 3, "landings 1-3 are built at tick %d" % START_TICK)
	var legs: PackedInt32Array = PackedInt32Array()
	assert_equal(Legs.empty_up_into(_stops, landing, legs), &"", "planned")
	var edges: PackedInt32Array = PackedInt32Array()
	var remaining: PackedInt32Array = PackedInt32Array([Space.MAX_CHECKS])
	assert_equal(Legs.legs_refusal(_o.world_routes, _o.routes, _o.profiles, legs, edges, remaining), &"", "checked")
	assert_equal(Space.MAX_CHECKS - remaining[0], _o.routes._edge_capacity + Legs.leg_count(legs), "spend")
	for leg: int in Legs.leg_count(legs):
		assert_equal(Vector2i(edges[2 * leg], edges[2 * leg + 1]), _first_match(legs, leg), "leg %d" % leg)


func test_the_loaded_way_down_stops_where_nothing_loaded_is_published_yet() -> void:
	"""Module 0's approach and seven descents resolve to CARRY edges and their certificates admit the wood rows; the
	sill's descent onto landing 1's F has no edge (phase 2 publishes it), so the whole way refuses ROUTE_NOT_CONNECTED."""
	if not _load(): return
	var legs: PackedInt32Array = PackedInt32Array()
	var wood: int = Grip.item_of(Grip.carry_of(0))
	assert_equal(Legs.loaded_down_into(_stops, wood, 1, legs), &"", "planned")
	var edges: PackedInt32Array = PackedInt32Array()
	var remaining: PackedInt32Array = PackedInt32Array([Space.MAX_CHECKS])
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, legs, edges, remaining), Legs.REFUSE_UNJOINED, "refused")
	for leg: int in Legs.leg_count(legs):
		assert_equal(edges[2 * leg] >= 0, leg < MODULE_ZERO_CARRY_LEGS, "leg %d resolved" % leg)
	var prefix: PackedInt32Array = legs.slice(0, Legs.LEG_WORDS * MODULE_ZERO_CARRY_LEGS)
	remaining[0] = Space.MAX_CHECKS
	assert_equal(Legs.legs_refusal(_o.world_routes, _o.routes, _o.profiles, prefix, edges, remaining), &"",
		"module 0's loaded legs admit wood")


func test_a_loaded_descent_takes_the_carry_twin() -> void:
	"""The first descent's two stops are joined by a WALK edge and by its CARRY twin; the loaded leg takes the CARRY
	edge, and the same stops on the claw descent row take the WALK edge."""
	if not _load(): return
	var walk_leg: PackedInt32Array = PackedInt32Array([_stops.a[0].x, _stops.a[0].y, _stops.a[1].x, _stops.a[1].y,
		StairPath.StairPins.CLAW_DESCENT_ROW])
	var carry_leg: PackedInt32Array = walk_leg.duplicate()
	carry_leg[4] = Legs.stair_rows(Grip.item_of(Grip.carry_of(0)))[Legs.DESCENT]
	var walk_edge: PackedInt32Array = PackedInt32Array()
	var carry_edge: PackedInt32Array = PackedInt32Array()
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, walk_leg, walk_edge, PackedInt32Array([Space.MAX_CHECKS])), &"",
		"walk")
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, carry_leg, carry_edge, PackedInt32Array([Space.MAX_CHECKS])),
		&"", "carry")
	assert_true(walk_edge[0] != carry_edge[0], "two edges")
	var edge: RoutesOwner.Edge = RoutesOwner.Edge.new()
	_o.routes.edge_metadata_into(Vector2i(carry_edge[0], carry_edge[1]), edge)
	assert_equal(edge.mode, ProfilesOwner.MODE_CARRY, "the loaded leg's edge")
	_o.routes.edge_metadata_into(Vector2i(walk_edge[0], walk_edge[1]), edge)
	assert_equal(edge.mode, ProfilesOwner.MODE_WALK, "the claw leg's edge")


func test_the_allowance_one_check_short_refuses_and_stays_spent() -> void:
	"""One check under the pass's cost refuses STAIR_LEGS_CHECKS and marks the allowance exhausted."""
	if not _load(): return
	var legs: PackedInt32Array = PackedInt32Array()
	Legs.empty_up_into(_stops, 1, legs)
	var edges: PackedInt32Array = PackedInt32Array()
	var remaining: PackedInt32Array = PackedInt32Array([_o.routes._edge_capacity + Legs.leg_count(legs) - 1])
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, legs, edges, remaining), Legs.REFUSE_BUDGET, "short")
	assert_equal(remaining[0], -1, "exhausted")
	remaining[0] = _o.routes._edge_capacity + Legs.leg_count(legs)
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, legs, edges, remaining), &"", "exact")
	assert_equal(remaining[0], 0, "all spent")
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, legs, edges, PackedInt32Array()), Legs.REFUSE_BUDGET,
		"no allowance")


func test_a_stale_stop_generation_or_a_wrong_row_is_refused() -> void:
	"""A leg whose end stop's generation is stale matches no edge; a resolved WALK leg certified for a row its edge does
	not admit is refused by the certificate."""
	if not _load(): return
	var legs: PackedInt32Array = PackedInt32Array()
	Legs.empty_up_into(_stops, 1, legs)
	var stale: PackedInt32Array = legs.duplicate()
	stale[3] += 1
	var edges: PackedInt32Array = PackedInt32Array()
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, stale, edges, PackedInt32Array([Space.MAX_CHECKS])),
		Legs.REFUSE_UNJOINED, "stale end")
	assert_true(edges[0] < 0 and edges[2] >= 0, "only the stale leg is unmatched")
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, legs, edges, PackedInt32Array([Space.MAX_CHECKS])), &"", "fresh")
	var wrong: PackedInt32Array = legs.duplicate()
	wrong[4] = StairPath.StairPins.CLAW_DESCENT_ROW # The back-up's edge carries 72, not the descent.
	assert_true(Legs.certify_refusal(_o.world_routes, _o.profiles, wrong, edges, _o.profiles.content_revision()) != &"",
		"a row the edge does not admit")


func test_malformed_lists_and_missing_owners_refuse() -> void:
	"""A list not a whole number of legs, a row outside the profile bank, an edge list of the wrong size, or a missing
	owner refuses before anything is read."""
	if not _load(): return
	var edges: PackedInt32Array = PackedInt32Array()
	var budget: PackedInt32Array = PackedInt32Array([Space.MAX_CHECKS])
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, PackedInt32Array([1, 2, 3]), edges, budget), Legs.REFUSE_SHAPE,
		"words")
	assert_equal(Legs.resolve_into(_o.routes, _o.profiles, PackedInt32Array([1, 1, 2, 1, 100000]), edges, budget),
		Legs.REFUSE_SHAPE, "row")
	assert_equal(Legs.resolve_into(null, _o.profiles, PackedInt32Array(), edges, budget), Legs.REFUSE_OWNER, "routes")
	assert_equal(Legs.certify_refusal(_o.world_routes, _o.profiles, PackedInt32Array([1, 1, 2, 1, 72]), PackedInt32Array(),
		1), Legs.REFUSE_SHAPE, "edges")
	assert_equal(Legs.certify_refusal(null, _o.profiles, PackedInt32Array(), PackedInt32Array(), 1), Legs.REFUSE_OWNER,
		"binding")
