extends "res://test/framework/test_case.gd"
## Actual ordinary Room/Space/Location/Route identities and publication leaves.
## Terrain, body and prospective approach permissions are explicit component fixtures.

const Actual := preload("res://test/test_underground_final_facts.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _actual: Actual = null
var _context: Locations.RoomContext = null
var _first: Vector2i = NULL_REF
var _last: Vector2i = NULL_REF
var _edge: Vector2i = NULL_REF


func before_each() -> void:
	"""Reuse the actual owner factory without running any inherited tests or preparing an entry."""
	_actual = Actual.new()
	_actual.before_each()
	_actual._bind_room_orders()
	assert_equal(_actual._fixture._locations.bind_room_orders(_actual._orders), &"", "actual sole Room binding")
	assert_true(_actual.failures.is_empty(), "actual setup: %s" % _actual.failures)


func after_each() -> void:
	"""Drop only test-owned companions before the actual Orders releases its original scope and arena."""
	if _context != null:
		_actual._fixture._routes.abort(_context.route_token)
		_actual._fixture._locations.abort(_context.location_token)
	_context = null
	_actual._orders._publishing = false
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "actual helper assertions: %s" % _actual.failures)
	_actual = null
	_first = NULL_REF
	_last = NULL_REF
	_edge = NULL_REF


func _plan() -> Orders.RoomPlan:
	"""A non-Corridor fine-cell plan reserves only metadata and claims beneath the old complete surface."""
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.world = _actual._fixture._world
	plan.space_revision = _actual._fixture._owner.revision()
	plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	plan.level = 1
	plan.origin_u = Vector3i(0, -2048, 0)
	plan.cell_size_u = 512
	plan.height_u = 1024
	plan.cells = PackedInt32Array([0, 0, 1, 0])
	return plan


func _prepare() -> void:
	"""Use the actual ordinary plan copy, future candidate, Space staging and sealing methods."""
	var orders: Orders = _actual._orders
	var plan: Orders.RoomPlan = _plan()
	orders._stage_action = Orders.ROOM_ADMISSION_STAGE
	orders._room_request = plan
	assert_equal(orders._begin_room_cold(_actual._entry_bindings, plan), &"", "original actual cold lease")
	orders._room_plan.copy_from(plan)
	assert_equal(orders._prepare_room(_actual._entry_bindings), &"", "ordinary Room sealed")
	assert_false(orders._entry_mode, "no entry protocol")
	assert_true(orders._entry_plan == null, "no fabricated EntryPlan")
	assert_equal(_final(), &"", "pure original ordinary source/claim proof")


func _final(checks: int = Space.MAX_CHECKS) -> StringName:
	"""Only the public typed concrete final proof may attest this actual future Room."""
	return _actual._room_final(checks)


func _prepare_companions() -> void:
	"""Refresh every old complete endpoint and authored edge; no future Room access is created."""
	var orders: Orders = _actual._orders
	var locations: Locations = _actual._fixture._locations
	var routes: Routes = _actual._fixture._routes
	_context = Locations.RoomContext.new()
	_context.orders = weakref(orders)
	_context.space = weakref(_actual._fixture._owner)
	_context.locations = weakref(locations)
	_context.budget = _actual._fixture._budget
	_context.world = orders._world
	_context.room = orders._stage_room
	_context.cold_token = orders._room_cold_token
	_context.space_token = orders._stage_token
	_context.base_revision = orders._room_plan.space_revision
	_context.target_revision = _context.base_revision + 1
	_context.profile_revision = _actual._fixture._profiles.content_revision()
	var begun: Locations.Result = locations.begin_room_prepare(_context.cold_token, _context.space_token,
		_context.room, orders._room_plan.room_type)
	assert_equal(begun.error, &"", "actual ordinary Location preparation")
	_context.location_token = begun.token
	assert_equal(locations.stage_refresh(begun.token, _first), &"", "first unchanged endpoint")
	assert_equal(locations.stage_refresh(begun.token, _last), &"", "last unchanged endpoint")
	assert_equal(locations.seal(begun.token), &"", "complete endpoint refresh sealed")
	_context.route_token = routes.begin_prepare(_context.cold_token, _context.space_token, begun.token).token
	assert_true(_context.route_token > 0, "actual graph preparation")
	assert_equal(routes.stage_refresh(_context.route_token, _edge), &"", "unchanged existing path")
	assert_equal(routes.seal(_context.route_token), &"", "complete graph sealed")


func _old_path() -> void:
	"""Publish a real preexisting directed surface path; its certificate is explicitly synthetic content."""
	var first: Vector3i = Vector3i(-512, 0, 512)
	var last: Vector3i = Vector3i(512, 0, 512)
	_first = _actual._fixture._location(first)
	_last = _actual._fixture._location(last)
	_edge = _actual._fixture._publish_edges([_actual._fixture._edge(_first, _last, [first, last])])[0]


func _identity() -> void:
	"""Model only root's approved exact pure identity tail using the real allocator and mirrored row writer."""
	var orders: Orders = _actual._orders
	assert_equal(_final(), &"", "source proof immediately before actual identity")
	orders._publishing = true
	var ref: Vector2i = _actual._fixture._residents.directory().create_candidate(orders._room_candidate)
	assert_equal(ref, orders._stage_room, "exact allocator receipt")
	assert_true(_actual._fixture._buildings._publish_spatial_room(ref, orders._room_plan.room_type).ok, "actual Room mirror")


func _swap(budget: Budget, token: int) -> bool:
	"""The concrete kernel must inspect the actual issuer rather than a successful authority method."""
	var orders: Orders = _actual._orders
	return Owner.room_commit_preflighted(_actual._fixture._owner, orders._stage_token,
		orders._room_candidate, orders._room_plan.room_type, orders, budget, token)


func test_ordinary_room_publishes_exact_type_without_entry_or_source_observers() -> void:
	"""A Kitchen can consume its sealed real candidate with no Corridor, Placement or observer after identity."""
	_prepare()
	var revision: int = _actual._fixture._owner.revision()
	assert_false(_swap(_actual._fixture._budget, _actual._orders._room_cold_token), "future identity cannot publish")
	_identity()
	var reads: int = _actual._fixture._sources.reads
	var observations: int = _actual._entry_bindings.binding_reads
	assert_true(_swap(_actual._fixture._budget, _actual._orders._room_cold_token), "pure ordinary Room swap")
	assert_equal(_actual._fixture._owner.revision(), revision + 1, "one real revision")
	assert_equal(_actual._fixture._sources.reads, reads, "no source observer")
	assert_equal(_actual._entry_bindings.binding_reads, observations, "no authority observer")
	assert_equal(_actual._fixture._buildings.type_of_room(_actual._orders._stage_room).value,
		Buildings.ROOM_TYPE_KITCHEN, "original ordinary purpose")
	assert_false(_swap(_actual._fixture._budget, _actual._orders._room_cold_token), "cannot replay")


func test_ordinary_room_refreshes_only_exact_old_endpoint_and_path_payloads() -> void:
	"""All companion banks advance only after the actual full Room/Space receipts and retain their old identities."""
	_old_path()
	_prepare()
	_prepare_companions()
	assert_equal(Locations.room_prepared_leaf_refusal(_actual._fixture._locations, _context), &"", "sealed endpoints")
	assert_equal(Routes.room_prepared_leaf_refusal(_actual._fixture._routes, _context), &"", "sealed old graph")
	assert_false(Locations.publish_room_preflighted(_actual._fixture._locations, _context), "no premature endpoint swap")
	assert_false(Routes.publish_room_preflighted(_actual._fixture._routes, _context), "no premature graph swap")
	_identity()
	assert_true(_swap(_context.budget, _context.cold_token), "Space first")
	assert_false(Routes.publish_room_preflighted(_actual._fixture._routes, _context), "Location receipt precedes graph")
	assert_true(Locations.publish_room_preflighted(_actual._fixture._locations, _context), "endpoint refresh")
	assert_true(Routes.publish_room_preflighted(_actual._fixture._routes, _context), "old graph refresh")
	assert_equal(_actual._fixture._locations._live.count, 2, "no future endpoint")
	assert_equal(_actual._fixture._routes._live.edge_count, 1, "no future path")
	assert_equal(_actual._fixture._locations._last_published_token, _context.location_token, "original endpoint receipt")
	assert_equal(_actual._fixture._routes._last_published_token, _context.route_token, "original path receipt")


func test_ordinary_original_plan_scalars_and_cells_are_rechecked_without_observers() -> void:
	"""Each original scalar and fine cell remains mandatory after all preparation callbacks have returned."""
	_prepare()
	var plan: Orders.RoomPlan = _actual._orders._room_request
	for field: StringName in [&"world", &"space_revision", &"room_type", &"level", &"origin_u", &"cell_size_u", &"height_u"]:
		var old: Variant = plan.get(field)
		if old is Vector2i:
			plan.set(field, old + Vector2i(0, 1))
		elif old is Vector3i:
			plan.set(field, old + Vector3i(1, 0, 0))
		else:
			plan.set(field, old + 1)
		assert_true(_final() != &"", "changed original %s" % field)
		plan.set(field, old)
		assert_equal(_final(), &"", "same original tuple retries")
	plan.cells[0] += 1
	assert_equal(_final(), Orders.REFUSE_PLAN, "exact fine cell")
	plan.cells[0] -= 1
	assert_equal(_final(), &"", "restored cells retry")


func test_ordinary_final_precharges_input_and_source_work_before_fact_scratch() -> void:
	"""A short caller budget refuses without executing the complete source or variable input scan."""
	_prepare()
	_actual._fixture._owner._facts.a = 98765
	assert_equal(_final(FinalFacts.BINDING_CHECKS), FinalFacts.REFUSE_BUDGET, "cumulative final work")
	assert_equal(_actual._fixture._owner._facts.a, 98765, "no source read before charge")
	assert_false(_actual._fixture._buildings.is_live_room(_actual._orders._stage_room), "identity unchanged")


func test_ordinary_final_rejects_foreign_budget_candidate_and_retired_world() -> void:
	"""Coincident tokens, future numbers and an invalid World never replace actual original owners."""
	_prepare()
	var other: Budget = Budget.new()
	var foreign: int = other.acquire(Budget.COLD_BYTES)
	assert_equal(foreign, _actual._orders._room_cold_token, "same numeric first token")
	assert_false(_swap(other, foreign), "foreign arena")
	assert_equal(other.release(foreign), &"", "foreign untouched")
	_actual._orders._room_candidate.persistent_id += 1
	assert_true(_final() != &"", "whole allocator candidate")
	_actual._orders._room_candidate.persistent_id -= 1
	assert_true(_actual._fixture._residents.directory().destroy(_actual._fixture._world), "actual World retired")
	assert_true(_final() != &"", "full World remains live before identity")


func test_ordinary_publishing_bracket_and_actual_mirrored_room_are_exact() -> void:
	"""A valid live Room elsewhere or a closed issuer bracket cannot consume the original sealed Space bank."""
	_prepare()
	_identity()
	var orders: Orders = _actual._orders
	orders._publishing = false
	assert_false(_swap(_actual._fixture._budget, orders._room_cold_token), "closed bracket")
	orders._publishing = true
	var row: int = orders._room_candidate.typed_row
	_actual._fixture._buildings._r_type[row] = Buildings.ROOM_TYPE_CORRIDOR
	assert_false(_swap(_actual._fixture._budget, orders._room_cold_token), "wrong actual purpose")
	_actual._fixture._buildings._r_type[row] = orders._room_plan.room_type
	assert_true(_swap(_actual._fixture._budget, orders._room_cold_token), "exact original receipt retry")


func test_ordinary_actual_receipt_cannot_borrow_foreign_or_replacement_cold_lease() -> void:
	"""Even after real identity, coincident foreign or renewed original-owner tokens cannot publish Space."""
	_prepare()
	_identity()
	var budget: Budget = _actual._fixture._budget
	var original: int = _actual._orders._room_cold_token
	var revision: int = _actual._fixture._owner.revision()
	var other: Budget = Budget.new()
	var foreign: int = other.acquire(Budget.COLD_BYTES)
	assert_equal(foreign, original, "same numeric token after actual identity")
	assert_false(_swap(other, foreign), "actual issuer rejects foreign arena")
	assert_equal(other.release(foreign), &"", "foreign lease unchanged")
	assert_equal(budget.release(original), &"", "original owner token revoked")
	var replacement: int = budget.acquire(Budget.COLD_BYTES)
	assert_true(replacement > original, "distinct replacement token")
	assert_false(_swap(budget, original), "expired original cannot publish")
	assert_false(_swap(budget, replacement), "current replacement is not original scope")
	assert_equal(_actual._fixture._owner.revision(), revision, "live Space remains unchanged")
	assert_true(budget.covers(replacement, Budget.COLD_BYTES), "replacement lease retained")
	assert_equal(budget.release(replacement), &"", "test releases only its replacement")


func test_ordinary_companion_scope_rejects_missing_private_plan_and_original_request() -> void:
	"""A typed coordinator alone is insufficient after its exact retained plan/request is removed or changed."""
	_old_path()
	_prepare()
	_prepare_companions()
	var orders: Orders = _actual._orders
	var plan: Orders.RoomPlan = orders._room_plan
	orders._room_plan = null
	assert_true(Locations.room_scope_leaf_refusal(_actual._fixture._locations, _context) != &"", "missing private plan")
	orders._room_plan = plan
	var request: Orders.RoomPlan = orders._room_request
	orders._room_request = null
	assert_true(Locations.room_scope_leaf_refusal(_actual._fixture._locations, _context) != &"", "missing original request")
	orders._room_request = request
	request.cells[0] += 1
	assert_true(Locations.room_scope_leaf_refusal(_actual._fixture._locations, _context) != &"", "changed original payload")
	request.cells[0] -= 1
	assert_equal(Locations.room_scope_leaf_refusal(_actual._fixture._locations, _context), &"", "same exact scope retry")


func test_ordinary_companions_reject_payload_drift_and_replaced_tokens() -> void:
	"""No new payload or same-number foreign preparation can be laundered through a refresh-only Room context."""
	_old_path()
	_prepare()
	_prepare_companions()
	var locations: Locations = _actual._fixture._locations
	locations._stage.i32[Locations.X * locations._capacity + _first.x] += 1
	assert_equal(Locations.room_prepared_leaf_refusal(locations, _context), &"LOCATION_ROOM_REFRESH_ONLY", "changed endpoint payload")
	locations._stage.i32[Locations.X * locations._capacity + _first.x] -= 1
	_context.space_token += 1
	assert_true(Locations.room_prepared_leaf_refusal(locations, _context) != &"", "exact Space token")
	_context.space_token -= 1
	assert_equal(Locations.room_prepared_leaf_refusal(locations, _context), &"", "original context retry")


func test_ordinary_final_rejects_late_actual_source_drift_and_retries() -> void:
	"""A successful previous observing read cannot hide current actual Building changes from the final leaf."""
	var hall: Vector2i = _actual._hall()
	_actual._source(hall)
	_prepare()
	var row: int = _actual._fixture._residents.directory().get_typed_row(hall)
	_actual._fixture._buildings._b_rotation[row] += 1
	assert_equal(_final(), &"SPACE_SOURCE_DRIFT", "late actual source mutation")
	_actual._fixture._buildings._b_rotation[row] -= 1
	assert_equal(_final(), &"", "current facts restored")
