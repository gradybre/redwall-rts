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
const NULL_REF: Vector2i = Vector2i(-1, 0)
var _fixture: RouteFixture = null


func before_each() -> void:
	"""Reuse the actual route stores; fixture assertions propagate without duplicating its test suite."""
	_fixture = RouteFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "real fixture setup: %s" % _fixture.failures)


func after_each() -> void:
	"""Carry setup/helper/cleanup failures outward and drop every real fixture retainer."""
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "real fixture helpers: %s" % _fixture.failures)
	_fixture = null


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
