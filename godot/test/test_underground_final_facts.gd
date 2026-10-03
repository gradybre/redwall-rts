extends "res://test/framework/test_case.gd"
## Real owners and generational facts; inherited fixture geometry/profile certificates are
## explicitly synthetic component content. No movement or work permission is introduced.

const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const RouteFixture := preload("res://test/test_underground_routes.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const EntryTests := preload("res://test/test_underground_entry_orders.gd")
const PhysicalTests := preload("res://test/test_excavation_physical.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
var _fixture: RouteFixture = null
var _orders: Orders = null
var _entry_bindings: EntryTests.EntryBindings = null
var _router: Router = null
var _sites: Sites = null
var _physical: PhysicalTests.SpatialFixture = null


func before_each() -> void:
	"""Reuse the actual route stores; fixture assertions propagate without duplicating its test suite."""
	_fixture = RouteFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "real fixture setup: %s" % _fixture.failures)


func after_each() -> void:
	"""Carry setup/helper/cleanup failures outward and drop every real fixture retainer."""
	if _orders != null:
		_orders._discard_room(_entry_bindings)
	_orders = null
	_entry_bindings = null
	_router = null
	_sites = null
	_physical = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "real fixture helpers: %s" % _fixture.failures)
	_fixture = null


func _prepare_actual_entry() -> void:
	"""Use the actual coordinator's plan-before-seal/prepared-after-seal flow; only frontier permission is synthetic."""
	_physical = PhysicalTests.SpatialFixture.new()
	_physical.world = _fixture._world
	_sites = Sites.new(_fixture._construction, _fixture._inventory, _fixture._pool,
		_fixture._items, _fixture._jobs, _fixture._work, _physical, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual Sites/Funding")
	_router = Router.new(_fixture._construction, _fixture._inventory, _fixture._pool,
		_fixture._items, _fixture._jobs, _fixture._work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual Router")
	_orders = Orders.new()
	_entry_bindings = EntryTests.EntryBindings.new()
	_entry_bindings.arena = _fixture._budget
	_entry_bindings.construction = _fixture._construction
	_entry_bindings.space = _fixture._owner
	_entry_bindings.world = _fixture._world
	_entry_bindings.inventory = _fixture._inventory
	_entry_bindings.orders = weakref(_orders)
	assert_equal(_orders.configure(_router, _fixture._owner, _fixture._sources,
		RoomCatalog.new(), _entry_bindings), &"", "actual sole Room coordinator")
	_start_entry_preparation()


func _start_entry_preparation() -> void:
	"""Keep this exact synchronous packet open for adversarial final-check and direct kernel probes."""
	var plan: EntryPlan.Request = _entry_plan()
	_orders._stage_action = Orders.ROOM_ADMISSION_STAGE
	_orders._entry_mode = true
	_orders._entry_request = plan
	assert_equal(_orders._begin_entry_cold(_entry_bindings, plan), &"", "original complete lease")
	_orders._entry_plan = EntryPlan.Request.new()
	EntryPlan.copy_into(plan, _orders._entry_plan)
	assert_equal(_orders._prepare_room(_entry_bindings), &"", "actual Room source and markers seal")
	assert_true(_fixture._owner._sealed, "proof follows actual seal")
	assert_false(_fixture._buildings.is_live_room(_orders._stage_room), "identity still unallocated")


func _entry_plan() -> EntryPlan.Request:
	"""A fixed metadata-only claim fixture does not supply construction, support or profile permission."""
	var plan: EntryPlan.Request = EntryPlan.Request.new()
	plan.world = _fixture._world
	plan.space_revision = _fixture._owner.revision()
	plan.base_level = 1
	plan.origin_u = Vector3i(0, -2048, 0)
	plan.rotation = 0
	plan.anchor = Vector2i(0, 1)
	plan.catalog_row = 0
	plan.catalog_revision = 1
	plan.variant_revision = 1
	plan.grouping_revision = 1
	plan.recipe_revision = 1
	plan.frontier_revision = 1
	plan.source_digests.resize(128)
	plan.source_digests.fill(17)
	plan.claims = PackedInt32Array([0, -2048, 0, 1024, -1024, 1024])
	plan.opening_targets = PackedInt32Array([-1, 0, -1, 0])
	return plan


func _room_final(checks: int = Space.MAX_CHECKS) -> StringName:
	"""Call only the public typed static final proof with the actual prepared stores and original tokens."""
	return FinalFacts.prepared_room_refusal(_fixture._owner, _fixture._routes, _fixture._locations,
		_orders, _orders._room_candidate, _orders._stage_token, _fixture._budget,
		_orders._room_cold_token, checks)


func test_room_final_is_pure_and_ordinary_snapshot_remains_live_only() -> void:
	"""The typed future exception never leaks into the ordinary live-source API or callback adapters."""
	_prepare_actual_entry()
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	var observed: int = _entry_bindings.binding_reads
	assert_equal(_room_final(), &"", "exact prepared source/claim census")
	assert_equal(source.reads, 0, "no source observation callback")
	assert_equal(_entry_bindings.binding_reads, observed, "no binding callback")
	assert_equal(_final(), FinalFacts.REFUSE_BUSY, "ordinary reader refuses future Room")
	assert_false(_fixture._buildings.is_live_room(_orders._stage_room), "no identity or source publication")


func test_room_final_precharges_whole_census_and_mutable_input_comparison() -> void:
	"""Insufficient work stops before any fact read or input scan and leaves the reusable fact scratch untouched."""
	_prepare_actual_entry()
	_fixture._owner._facts.a = 987654
	assert_equal(_room_final(FinalFacts.BINDING_CHECKS), FinalFacts.REFUSE_BUDGET, "entire scan must be affordable")
	assert_equal(_fixture._owner._facts.a, 987654, "no early source work")
	_orders._entry_request.claims[0] += 1
	assert_equal(_room_final(), EntryPlan.REFUSE, "exact original claim tuple")
	_orders._entry_request.claims[0] -= 1
	assert_equal(_room_final(), &"", "unchanged request can retry")


func test_room_final_rejects_replaced_original_lease_and_foreign_same_number_budget() -> void:
	"""An equal-size replacement token cannot authorize prepared Room identity or geometry."""
	_prepare_actual_entry()
	var original: int = _orders._room_cold_token
	var other: Budget = Budget.new()
	assert_equal(other.acquire(Budget.COLD_BYTES), original, "foreign arena has same first numeric token")
	assert_true(FinalFacts.prepared_room_refusal(_fixture._owner, _fixture._routes, _fixture._locations,
		_orders, _orders._room_candidate, _orders._stage_token, other, original, Space.MAX_CHECKS) != &"", "exact arena identity")
	assert_equal(other.release(original), &"", "foreign lease remains ours")
	assert_equal(_fixture._budget.release(original), &"", "release original")
	var replacement: int = _fixture._budget.acquire(Budget.COLD_BYTES)
	assert_true(_room_final() != &"", "original token expired")
	assert_true(_fixture._budget.covers(replacement, Budget.COLD_BYTES), "replacement preserved")
	assert_equal(_fixture._budget.release(replacement), &"", "release test-owned replacement")


func test_room_final_rederives_actual_free_identity_and_whole_candidate() -> void:
	"""A candidate is an observation, never a reusable permit when a different allocation consumed its PID/slot."""
	_prepare_actual_entry()
	_orders._room_candidate.persistent_id += 1
	assert_true(_room_final() != &"", "mutable packet change")
	_orders._room_candidate.persistent_id -= 1
	var taken: Vector2i = _fixture._residents.directory().create(Directory.KIND_BUILDING)
	assert_true(taken != NULL_REF, "actual intervening allocation")
	assert_equal(_room_final(), Directory.REFUSAL_CANDIDATE, "actual heap/PID tuple moved")


func test_room_final_catches_late_actual_source_drift_without_observation() -> void:
	"""The source change that defeated an earlier Room observer is checked by actual kind-specific leaves."""
	var hall: Vector2i = _hall()
	_source(hall)
	_prepare_actual_entry()
	var row: int = _fixture._residents.directory().get_typed_row(hall)
	_fixture._buildings._b_rotation[row] = 1
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	assert_equal(_room_final(), &"SPACE_SOURCE_DRIFT", "late Building facts fail before identity")
	assert_equal(source.reads, 0, "no final external source observer")
	_fixture._buildings._b_rotation[row] = 0
	assert_equal(_room_final(), &"", "restored current facts retry")


func test_room_final_future_exception_is_only_own_metadata_and_claims() -> void:
	"""A changed sealed row cannot smuggle physical void or a foreign full section under a future Room."""
	_prepare_actual_entry()
	var row: int = _orders._entry_section.x
	_fixture._owner._s_r_role[row] = Space.SUPPORTED_VOID
	assert_equal(_room_final(), &"SPACE_ROOM_ADMISSION_REGION", "no future physical permission")
	_fixture._owner._s_r_role[row] = Space.FLOOR_DATUM
	for claim_row: int in _fixture._owner._region_capacity:
		if _fixture._owner._s_r_claim_kind[claim_row] == Owner.CLAIM_ROOM:
			_fixture._owner._s_r_section_generation[claim_row] += 1
			assert_equal(_room_final(), &"SPACE_ROOM_ADMISSION_REGION", "full section generation")
			_fixture._owner._s_r_section_generation[claim_row] -= 1
			break
	assert_equal(_room_final(), &"", "exact markers retry")


func test_room_final_rejects_foreign_companion_and_active_observer_states() -> void:
	"""A sealed unrelated graph or endpoint transaction cannot piggyback on the Room's final proof."""
	_prepare_actual_entry()
	_fixture._routes._in_callback = true
	assert_equal(_room_final(), FinalFacts.REFUSE_BUSY, "route callback active")
	_fixture._routes._in_callback = false
	_fixture._locations._in_retention = true
	assert_equal(_room_final(), FinalFacts.REFUSE_BUSY, "retention callback active")
	_fixture._locations._in_retention = false
	_fixture._locations._token = 991
	assert_equal(_room_final(), FinalFacts.REFUSE_BUSY, "unrelated endpoint candidate")
	_fixture._locations._token = 0
	assert_equal(_room_final(), &"", "matching idle companions")


func _allocate_entry_room() -> void:
	"""Publish through real Buildings under the actual Orders bracket; the source bank remains sealed."""
	assert_equal(_room_final(), &"", "all original facts qualify before identity")
	_orders._publishing = true
	assert_true(_fixture._buildings.designate_spatial_room_candidate(Buildings.ROOM_TYPE_CORRIDOR,
		_orders._room_candidate).ok, "exact actual future identity consumed")


func _room_swap(budget: Budget, token: int) -> bool:
	"""Only the static production kernel sees the actual retained candidate and caller-supplied arena."""
	return Owner.room_commit_preflighted(_fixture._owner, _orders._stage_token, _orders._room_candidate,
		Buildings.ROOM_TYPE_CORRIDOR, _orders, budget, token)


func test_room_commit_requires_actual_publishing_bracket_and_original_budget() -> void:
	"""Matching after-facts cannot borrow a foreign arena or skip the actual coordinator publication interval."""
	_prepare_actual_entry()
	assert_false(_room_swap(_fixture._budget, _orders._room_cold_token), "identity still future")
	_allocate_entry_room()
	var other: Budget = Budget.new()
	var other_token: int = other.acquire(Budget.COLD_BYTES)
	assert_equal(other_token, _orders._room_cold_token, "coincident token")
	assert_false(_room_swap(other, other_token), "foreign actual Budget refused")
	assert_equal(other.release(other_token), &"", "foreign lease untouched")
	_orders._publishing = false
	assert_false(_room_swap(_fixture._budget, _orders._room_cold_token), "outside actual publication bracket")
	_orders._publishing = true
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	var observations: int = _entry_bindings.binding_reads
	assert_true(_room_swap(_fixture._budget, _orders._room_cold_token), "exact actual pure tail")
	assert_equal(source.reads, 0, "no source observer after identity")
	assert_equal(_entry_bindings.binding_reads, observations, "no binding observer after identity")
	assert_equal(_fixture._owner.last_published_token(), _orders._stage_token, "exact success receipt")
	assert_false(_room_swap(_fixture._budget, _orders._room_cold_token), "consumed token cannot replay")
	_orders._publishing = false


func test_room_commit_does_not_borrow_replacement_lease_or_changed_after_facts() -> void:
	"""The exact original token and mirrored Room purpose remain required even after real allocation."""
	_prepare_actual_entry()
	_allocate_entry_room()
	var original: int = _orders._room_cold_token
	var row: int = _orders._room_candidate.typed_row
	_fixture._buildings._r_type[row] += 1
	assert_false(_room_swap(_fixture._budget, original), "wrong actual purpose")
	_fixture._buildings._r_type[row] -= 1
	assert_equal(_fixture._budget.release(original), &"", "test revokes original")
	var replacement: int = _fixture._budget.acquire(Budget.COLD_BYTES)
	assert_false(_room_swap(_fixture._budget, original), "expired original")
	assert_false(_room_swap(_fixture._budget, replacement), "replacement is not retained original")
	assert_true(_fixture._budget.covers(replacement, Budget.COLD_BYTES), "replacement not released")
	assert_equal(_fixture._budget.release(replacement), &"", "test releases its replacement")
	_orders._publishing = false


func _final(checks: int = Space.MAX_CHECKS) -> StringName:
	"""Supply the real complete binding and current expected geometry, with an explicit work budget."""
	return FinalFacts.snapshot_refusal(_fixture._owner, _fixture._routes, _fixture._locations,
		_fixture._owner.revision(), checks)


func _source(ref: Vector2i) -> void:
	"""Register actual facts through the ordinary source observation and transaction path."""
	var token: int = _fixture._owner.begin_stage(_fixture._owner.revision()).token
	assert_equal(_fixture._owner.stage_source(token, ref), &"", "actual source registration")
	assert_equal(_fixture._owner.seal(token), &"", "source sealed")
	_fixture._owner.publish(token)


func _record() -> Locations.Record:
	"""The production reader requires exact caller-owned fixed-size scratch before any writes."""
	var result: Locations.Record = Locations.Record.new()
	result.envelope.resize(6)
	result.support.resize(6)
	return result


func _hall() -> Vector2i:
	"""A real surface Building supplies source identity only, not underground support geometry."""
	var result: Buildings.OpResult = _fixture._buildings.place_building(
		int(Catalog.BUILDING_DEFINITION["hall"]), 59 * 128 + 58, 0, 1)
	assert_true(result.ok, "actual hall")
	return result.ref


func _room(hall: Vector2i) -> Vector2i:
	"""Author a legitimate surface Room for testing exact facts across every supported source kind."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for z: int in range(60, 68):
		for x: int in range(59, 64):
			tiles.append(z * 128 + x)
	var result: Buildings.OpResult = _fixture._buildings.designate_room(hall,
		int(Catalog.ROOM_TYPE["DORMITORY"]), tiles)
	assert_true(result.ok, "actual surface room")
	return result.ref


func test_final_sources_skip_observer_and_preserve_authority() -> void:
	"""Final reads touch only reusable facts; ordinary Sources overrides are never called."""
	_source(_hall())
	var before: PackedByteArray = _fixture._owner.state_bytes()
	var pose: PackedByteArray = _fixture._transforms.state_bytes()
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	assert_equal(_final(), &"", "current actual facts")
	assert_equal(source.reads, 0, "no public source observation")
	assert_equal(_fixture._owner.state_bytes(), before, "no geometry or saved source write")
	assert_equal(_fixture._transforms.state_bytes(), pose, "no pose write")


func test_late_building_change_refuses_without_geometry_revision_change() -> void:
	"""The concrete stale-snapshot bug is caught after an ordinary endpoint observation finishes."""
	var hall: Vector2i = _hall()
	_source(hall)
	var endpoint: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	var record: Locations.Record = _record()
	var revision: int = _fixture._owner.revision()
	assert_equal(_fixture._owner.snapshot_into(Space.Snapshot.new()), &"", "earlier complete snapshot")
	assert_equal(_fixture._locations.read_location_into(endpoint, record), &"", "last public observation")
	assert_true(_fixture._buildings.set_building_interior_id(hall, 12).ok, "late real owner mutation")
	assert_equal(_fixture._owner.revision(), revision, "no Space publication hides this drift")
	assert_true(FinalFacts.record_matches(_fixture._locations, endpoint, record, _fixture._owner), "endpoint itself unchanged")
	assert_equal(_final(), &"SPACE_SOURCE_DRIFT", "final actual source comparison catches it")


func test_all_nonresident_leaf_facts_equal_normal_observation() -> void:
	"""The static dispatch retains World/Building/Room/Furniture/Construction schemas exactly."""
	var hall: Vector2i = _hall()
	var room: Vector2i = _room(hall)
	var bed: Vector2i = _fixture._buildings.place_furniture(room,
		int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	var project: Vector2i = _fixture._construction.open_build(hall).ref
	var normal: Owner.Facts = Owner.Facts.new()
	var leaf: Owner.Facts = Owner.Facts.new()
	for ref: Vector2i in [_fixture._world, hall, room, bed, project]:
		assert_equal(_fixture._sources.read_into(ref, normal), &"", "ordinary actual observation")
		assert_equal(Owner.CoreSources.read_leaf_into(_fixture._sources, ref, leaf), &"", "static actual leaf")
		assert_equal([leaf.kind, leaf.parent, leaf.a, leaf.b, leaf.c, leaf.d],
			[normal.kind, normal.parent, normal.a, normal.b, normal.c, normal.d], "identical source schema")
		_source(ref)
	assert_equal(_final(), &"", "all actual source kinds pass together")


func test_project_claim_generation_remains_mandatory() -> void:
	"""Claims are checked even when their Construction is not a retained geometry source row."""
	var project: Vector2i = _fixture._construction.open_build(_hall()).ref
	var token: int = _fixture._owner.begin_stage(_fixture._owner.revision()).token
	var claim: Owner.Region = Owner.Region.new()
	claim.box = PackedInt32Array([5000, 0, 5000, 5100, 100, 5100])
	claim.owner = _fixture._world
	claim.role = Space.OBSTACLE
	claim.level = 0
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	assert_equal(_fixture._owner.stage_add(token, claim).error, &"", "actual project claim")
	assert_equal(_fixture._owner.seal(token), &"", "claim sealed")
	_fixture._owner.publish(token)
	assert_equal(_final(), &"", "live project claim")
	assert_true(_fixture._residents.directory().destroy(project), "actual retirement fixture")
	assert_equal(_final(), &"SPACE_SOURCE_STALE", "full claim generation required")


func test_budget_refuses_before_any_leaf_read() -> void:
	"""The first census and source-specific cost are admitted before reusable facts are touched."""
	_source(_hall())
	var required: int = FinalFacts._required_checks(_fixture._owner)
	_fixture._owner._facts.a = 7123
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	for limit: int in [-1, 127, required - 1, 9223372036854775807]:
		assert_equal(_final(limit), FinalFacts.REFUSE_BUDGET, "finite affordable work required")
		assert_equal(_fixture._owner._facts.a, 7123, "no leaf called under refused work budget")
	assert_equal(source.reads, 0, "no hidden observation call")
	assert_equal(_final(required), &"", "exact complete cost is sufficient")


func test_admitted_real_capacity_uses_actual_source_census() -> void:
	"""The unchanged6144/2048 pack can attest sparse real facts without quadratic precharging."""
	_fixture._binding = null
	_fixture._make_space(RouteFixture.NODES, 6144, 2048, 8192)
	_fixture._bind_routes(RouteFixture.NODES, RouteFixture.EDGES, RouteFixture.VERTICES, RouteFixture.LINKS)
	assert_equal(FinalFacts._required_checks(_fixture._owner), 128 + 2 * 8192 + 64, "both finite scans plus World leaf")
	assert_equal(_final(), &"", "actual production-sized empty pack")
	_source(_hall())
	assert_equal(_final(128 + 2 * 8192 + 128), &"", "actual present source count")


func test_foreign_binding_stale_revision_and_busy_owners_refuse() -> void:
	"""A prepared or reentrant owner cannot lend scratch to this final cold attestation."""
	assert_equal(FinalFacts.snapshot_refusal(_fixture._owner, Routes.new(null, null), _fixture._locations,
		_fixture._owner.revision(), Space.MAX_CHECKS), FinalFacts.REFUSE_BINDING, "foreign graph")
	assert_equal(FinalFacts.snapshot_refusal(_fixture._owner, _fixture._routes, _fixture._locations,
		_fixture._owner.revision() - 1, Space.MAX_CHECKS), &"SPACE_REVISION_STALE", "exact revision")
	var token: int = _fixture._owner.begin_stage(_fixture._owner.revision()).token
	assert_equal(_final(), FinalFacts.REFUSE_BUSY, "prepared geometry")
	assert_true(_fixture._owner.abort(token), "drop own candidate")
	_fixture._routes._in_callback = true
	assert_equal(_final(), FinalFacts.REFUSE_BUSY, "graph callback")
	_fixture._routes._in_callback = false
	_fixture._locations._in_retention = true
	assert_equal(_final(), FinalFacts.REFUSE_BUSY, "endpoint callback")
	_fixture._locations._in_retention = false
	assert_equal(_final(), &"", "all original lifetimes restored")


func test_endpoint_match_compares_every_packed_payload_and_proof_field() -> void:
	"""No envelope/role/section/revision change can hide behind an unchanged local pair."""
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	var record: Locations.Record = _record()
	assert_equal(_fixture._locations.read_location_into(location, record), &"", "actual endpoint")
	assert_true(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "entire exact record")
	for field: int in range(Locations.X, Locations.I32_FIELDS):
		var old: int = _fixture._locations._get32(_fixture._locations._live, field, location.x)
		_fixture._locations._set32(_fixture._locations._live, field, location.x, old + 1)
		assert_false(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "changed scalar%d" % field)
		_fixture._locations._set32(_fixture._locations._live, field, location.x, old)
	for field: int in Locations.I64_FIELDS:
		var old: int = _fixture._locations._get64(_fixture._locations._live, field, location.x)
		_fixture._locations._set64(_fixture._locations._live, field, location.x, old + 1)
		assert_false(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "changed revision")
		_fixture._locations._set64(_fixture._locations._live, field, location.x, old)
	assert_true(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "test corruption fully restored")


func test_retired_reused_endpoint_does_not_match_old_generation() -> void:
	"""Local slot reuse cannot recreate the completed approach from an earlier final observation."""
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	var record: Locations.Record = _record()
	assert_equal(_fixture._locations.read_location_into(location, record), &"", "old observed endpoint")
	var cold: int = _fixture._budget.acquire(RouteFixture.COLD_BYTES)
	var token: int = _fixture._locations.begin_prepare(cold).token
	assert_equal(_fixture._locations.stage_remove(token, location), &"", "unretained endpoint retires")
	assert_equal(_fixture._locations.seal(token), &"", "retirement sealed")
	assert_true(_fixture._locations.publish(token), "actual retirement")
	_fixture._budget.release(cold)
	var next: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	assert_equal(next.x, location.x, "same finite slot reused")
	assert_true(next.y != location.y, "new actual local generation")
	assert_false(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "old full ref is stale")
	assert_false(FinalFacts.record_matches(_fixture._locations, next, record, _fixture._owner), "old immutable payload revision is stale")


func test_idle_resident_matches_actual_transform_and_location() -> void:
	"""Resident facts require the actual committed actor, never a flat-tile pose fallback."""
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	assert_equal(_fixture._routes.admit_actor(_fixture._worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual actor")
	_source(_fixture._worker)
	var source: RouteFixture.CountedSources = _fixture._sources as RouteFixture.CountedSources
	source.reads = 0
	assert_equal(_final(), &"", "current actual resident")
	assert_equal(source.reads, 0, "no recursive resident observer")
	assert_true(_fixture._transforms.advance(_fixture._worker, -511, 0, 512), "real Transform mutation")
	assert_equal(_final(), &"ROUTE_ACTOR_POSITION_DRIFT", "endpoint root no longer matches")


func test_transit_resident_uses_exact_current_segment_and_generation() -> void:
	"""Moving actors retain the actual occupied span and exact integer interpolation, not endpoint-only proof."""
	var refs: Array[Vector2i] = _fixture._moving_actor()
	assert_equal(_fixture._routes.advance_tick(1), 1, "actual actor enters span")
	_source(_fixture._worker)
	assert_equal(_final(), &"", "actual in-span facts")
	var row: int = _fixture._residents.directory().get_typed_row(_fixture._worker)
	_fixture._routes._motion.resident[Routes.R_EDGE_GENERATION * Routes.RESIDENT_CAPACITY + row] += 1
	assert_equal(_final(), &"ROUTE_EDGE_STALE", "full occupied edge generation")
	_fixture._routes._motion.resident[Routes.R_EDGE_GENERATION * Routes.RESIDENT_CAPACITY + row] = refs[2].y
	_fixture._routes._motion.resident_long[Routes.R_PROGRESS * Routes.RESIDENT_CAPACITY + row] += 1
	assert_equal(_final(), &"ROUTE_ACTOR_POSITION_DRIFT", "exact current segment fraction")
	_fixture._routes._motion.resident_long[Routes.R_PROGRESS * Routes.RESIDENT_CAPACITY + row] -= 1
	assert_equal(_final(), &"", "restored exact actual state")


func test_retired_world_invalidates_facts_and_endpoint_observation() -> void:
	"""Every final path keeps the actual full World generation rather than numerical namespace coincidence."""
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	var record: Locations.Record = _record()
	assert_equal(_fixture._locations.read_location_into(location, record), &"", "actual endpoint")
	assert_true(_fixture._residents.directory().destroy(_fixture._world), "actual World retires")
	assert_equal(_final(), FinalFacts.REFUSE_BINDING, "world lifetime required")
	assert_false(FinalFacts.record_matches(_fixture._locations, location, record, _fixture._owner), "record cannot retain retired World permission")


func test_full_256_resident_leaf_census_fits_unchanged_domain_budget() -> void:
	"""The actual living cap has bounded linear final work, including real bound actor identities."""
	_fixture._binding = null
	_fixture._make_space(RouteFixture.NODES, 6144, 2048, 8192)
	_fixture._bind_routes(RouteFixture.NODES, RouteFixture.EDGES, RouteFixture.VERTICES, RouteFixture.LINKS)
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	for index: int in 256:
		var worker: Vector2i = _fixture._worker if index == 0 else _fixture._residents.spawn(&"mouse").ref
		assert_true(_fixture._transforms.place(worker, -512, 0, 512, 0), "actual pose")
		assert_equal(_fixture._routes.admit_actor(worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual fixture actor")
	var token: int = _fixture._owner.begin_stage(_fixture._owner.revision()).token
	for row: int in 256:
		assert_equal(_fixture._owner.stage_source(token, _fixture._residents.ref_of(row)), &"", "actual Resident source")
	assert_equal(_fixture._owner.seal(token), &"", "all sources sealed within existing budget")
	_fixture._owner.publish(token)
	assert_equal(FinalFacts._required_checks(_fixture._owner), 128 + 2 * 8192 + 64 + 256 * 256, "complete source-counted work")
	assert_equal(_final(), &"", "all256 actual identities attested")


func test_actor_and_world_generation_reuse_cannot_match_stored_sources() -> void:
	"""Actual resident retirement/reuse preserves the slot but never its authoritative identity."""
	var location: Vector2i = _fixture._location(Vector3i(-512, 0, 512))
	assert_equal(_fixture._routes.admit_actor(_fixture._worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual actor")
	_source(_fixture._worker)
	assert_true(_fixture._residents.despawn(_fixture._worker).ok, "actual resident retires")
	var next: Vector2i = _fixture._residents.spawn(&"mouse").ref
	assert_equal(next.x, _fixture._worker.x, "same Directory slot reused")
	assert_true(next.y != _fixture._worker.y, "new full generation")
	assert_equal(_final(), &"SPACE_SOURCE_STALE", "stored actor identity cannot alias replacement")


func test_domain_and_source_kind_changes_refuse_without_public_observers() -> void:
	"""The immutable Domain and exact Directory kind remain mandatory at the final leaf boundary."""
	_fixture._routes._domain._checks -= 1
	assert_equal(_final(), FinalFacts.REFUSE_BINDING, "complete Domain includes the finite work policy")
	_fixture._routes._domain._checks += 1
	var row: int = _fixture._owner._find_source(_fixture._world, false)
	_fixture._owner._o_kind[row] = Directory.KIND_BUILDING
	assert_equal(_final(), &"SPACE_SOURCE_STALE", "current actual kind must match stored kind before dispatch")
	_fixture._owner._o_kind[row] = Directory.KIND_WORLD
	assert_equal(_final(), &"", "actual source restored")


func test_static_leaf_never_substitutes_unbound_resident_or_half_null_reference() -> void:
	"""Only the typed actual Routes bridge may produce Resident facts; static nonresident dispatch refuses."""
	var facts: Owner.Facts = Owner.Facts.new()
	facts.a = 7
	assert_equal(Owner.CoreSources.read_leaf_into(_fixture._sources, _fixture._worker, facts),
		&"SPACE_SOURCE_KIND_UNBOUND", "no guessed Resident floor or mode")
	assert_equal(facts.a, 0, "ordinary cleared output semantics retained")
	assert_equal(Owner.CoreSources.read_leaf_into(_fixture._sources, Vector2i(-1, 1), facts),
		&"SPACE_SOURCE_STALE", "malformed reference cannot be null")
