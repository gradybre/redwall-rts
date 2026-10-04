extends "res://test/framework/test_case.gd"
## Decision1130: actual sealed owner/graph banks with the existing explicitly synthetic
## route/profile fixture. Fixed metadata observations never certify air, support or movement.

const RouteTests := preload("res://test/test_underground_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")


class ObservedLocations extends Locations:
	var full_reads: int = 0
	var public_reads: int = 0
	var full_refusal: StringName = &""

	func prepared_refusal(token: int) -> StringName:
		"""Count complete proofs without replacing their actual source/retention decisions."""
		full_reads += 1
		var code: StringName = super.prepared_refusal(token)
		return code if code != &"" else full_refusal

	func prepared_location_into(token: int, location: Vector2i, out: Locations.Record) -> StringName:
		"""The public interface retains its full proof; Routes must use the separate concrete observation."""
		public_reads += 1
		return super.prepared_location_into(token, location, out)


class ObservedRoutes extends Routes:
	var after_validation: Callable = Callable()

	func _validate_graph() -> StringName:
		"""A test-only last-read observer exposes whether seal brackets all fixed metadata reads."""
		var code: StringName = super._validate_graph()
		if after_validation.is_valid():
			var callback: Callable = after_validation
			after_validation = Callable()
			callback.call()
		return code


class Fixture extends RouteTests:
	func _make_space(nodes: int = NODES, regions: int = 64, sources: int = 16, surveys: int = 64) -> void:
		"""Use the same real stores; replace only observers before any graph/endpoint binding exists."""
		super._make_space(nodes, regions, sources, surveys)
		_routes = ObservedRoutes.new(_residents, _transforms)
		_sources._locations = _routes
		_locations = ObservedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, nodes, 228 * nodes + 256), &"", "actual observed endpoints")


var _fixture: Fixture = null
var _cold: int = 0
var _endpoint: Vector2i = Vector2i(-1, 0)
var _last_endpoint: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""The actual candidate is sealed before the graph can borrow its previously unpublished full handle."""
	_fixture = Fixture.new()
	_fixture.before_each()
	_cold = _fixture._budget.acquire(RouteTests.COLD_BYTES)
	var token: int = _fixture._locations.begin_prepare(_cold).token
	_endpoint = _fixture._locations.stage_add(token, _fixture._location_record(Vector3i(-512, 0, 512))).location
	_last_endpoint = _fixture._locations.stage_add(token, _fixture._location_record(Vector3i(512, 0, 512))).location
	assert_equal(_fixture._locations.seal(token), &"", "actual complete Location candidate")
	assert_equal(_fixture._routes.begin_prepare(_cold, 0, token).error, &"", "full preflight before graph copy")
	assert_equal(_fixture.failures, PackedStringArray(), "actual shared fixture setup")


func after_each() -> void:
	"""Each test owns its replacement lease too; candidate cleanup never publishes or rewinds generations."""
	_cleanup(_fixture)
	assert_equal(_fixture.failures, PackedStringArray(), "actual fixture cleanup")
	_fixture = null


func _cleanup(fixture: Fixture) -> void:
	"""Discard only the fixture's own original candidates before its exact current lease is released."""
	if fixture._routes._token != 0:
		fixture._routes.abort(fixture._routes._token)
	if fixture._locations._token != 0:
		fixture._locations.abort(fixture._locations._token)
	if fixture._owner._stage_token != 0:
		fixture._owner.abort(fixture._owner._stage_token)
	if fixture._budget._token != 0:
		assert_equal(fixture._budget.release(fixture._budget._token), &"", "caller releases its own arena")
	fixture.after_each()


func _sentinel() -> Locations.Record:
	"""Every scalar and both fixed arrays must survive any refused read unchanged."""
	var out: Locations.Record = Locations.Record.new()
	out.point = Vector3i(901, 902, 903)
	out.room = Vector2i(904, 905)
	out.section = Vector2i(906, 907)
	out.level = 908
	out.role = 909
	out.world = Vector2i(910, 911)
	out.payload_revision = 912
	out.geometry_revision = 913
	out.envelope = PackedInt32Array([1, 2, 3, 4, 5, 6])
	out.support = PackedInt32Array([7, 8, 9, 10, 11, 12])
	return out


func _unchanged(out: Locations.Record) -> void:
	"""Check complete output preservation, not just a sentinel result code."""
	assert_equal(out.point, Vector3i(901, 902, 903), "point preserved")
	assert_equal(out.room, Vector2i(904, 905), "full Room preserved")
	assert_equal(out.section, Vector2i(906, 907), "full section preserved")
	assert_equal(out.level, 908, "level preserved")
	assert_equal(out.role, 909, "role preserved")
	assert_equal(out.world, Vector2i(910, 911), "full World preserved")
	assert_equal(out.payload_revision, 912, "payload revision preserved")
	assert_equal(out.geometry_revision, 913, "geometry revision preserved")
	assert_equal(out.envelope, PackedInt32Array([1, 2, 3, 4, 5, 6]), "envelope preserved")
	assert_equal(out.support, PackedInt32Array([7, 8, 9, 10, 11, 12]), "support preserved")


func _observe(out: Locations.Record, ref: Vector2i = Vector2i(-1, 0)) -> StringName:
	"""Only the retained actual graph supplies original tokens and owner identities."""
	return Locations.prepared_route_location_into(_fixture._locations, _fixture._routes,
		_endpoint if ref == Vector2i(-1, 0) else ref, out)


func test_fixed_observations_copy_unpublished_row_without_repeating_full_proofs() -> void:
	"""No hidden source/installed census runs between the explicit full bracket boundaries."""
	var actual: ObservedLocations = _fixture._locations as ObservedLocations
	var sources: RouteTests.CountedSources = _fixture._sources as RouteTests.CountedSources
	var full_reads: int = actual.full_reads
	var reads: int = sources.reads
	var remaining: int = actual._remaining
	var out: Locations.Record = _sentinel()
	assert_false(actual.is_live_location(_endpoint), "future endpoint is not live authority")
	for index: int in 128:
		assert_equal(_observe(out), &"", "bounded row observation")
	assert_equal(actual.full_reads, full_reads, "no repeated all-record proof")
	assert_equal(actual.public_reads, 0, "strict public API was not bypassed by an override")
	assert_equal(sources.reads, reads, "no Source observer")
	assert_equal(actual._remaining, remaining, "no budget reset or hidden spend")
	assert_equal(out.point, Vector3i(-512, 0, 512), "exact authored point")
	assert_equal(out.world, _fixture._world, "actual full World")
	assert_equal(out.envelope, PackedInt32Array([-640, 0, 384, -384, 1024, 640]), "complete actual envelope")
	out.envelope[0] = 555
	assert_equal(_observe(out), &"", "caller writes never alias bank storage")
	assert_equal(out.envelope[0], -640, "original packed field remains unchanged")
	assert_equal(_fixture._routes.seal(_fixture._routes._token), &"", "full pre/post graph validation")
	assert_true(actual.full_reads >= full_reads + 2, "both full seal boundaries remain")
	assert_equal(_fixture._routes.prepared_refusal(_fixture._routes._token), &"", "final complete publication guard")


func test_foreign_actual_graph_with_coincident_tokens_never_supplies_the_namespace() -> void:
	"""Another fully configured graph and lease may have equal numbers but remain a different composition."""
	var other: Fixture = Fixture.new()
	other.before_each()
	var cold: int = other._budget.acquire(RouteTests.COLD_BYTES)
	var token: int = other._locations.begin_prepare(cold).token
	assert_equal(other._locations.seal(token), &"", "foreign actual sealed candidate")
	assert_equal(other._routes.begin_prepare(cold, 0, token).error, &"", "foreign actual graph")
	assert_equal(other._routes._token, _fixture._routes._token, "coincident graph token")
	assert_equal(other._locations._token, _fixture._locations._token, "coincident Location token")
	assert_equal(other._budget._token, _cold, "coincident real lease token")
	var out: Locations.Record = _sentinel()
	assert_equal(Locations.prepared_route_location_into(_fixture._locations, other._routes, _endpoint, out),
		&"LOCATION_OWNER_MISMATCH", "full object namespace remains required")
	_unchanged(out)
	_cleanup(other)
	assert_equal(other.failures, PackedStringArray(), "foreign setup and cleanup")


func test_full_handle_and_candidate_seals_preserve_refused_output() -> void:
	"""A live numeric slot, stale generation or unsealed Location image is not the original prepared row."""
	var out: Locations.Record = _sentinel()
	assert_equal(_observe(out, Vector2i(_endpoint.x, _endpoint.y + 1)), &"LOCATION_STALE", "full generation")
	_unchanged(out)
	_fixture._locations._sealed = false
	assert_equal(_observe(out), &"LOCATION_TOKEN_STALE", "original Location seal lost")
	_unchanged(out)
	_fixture._locations._sealed = true
	_fixture._routes._location_token += 1
	assert_equal(_observe(out), &"LOCATION_TOKEN_STALE", "different sealed candidate token")
	_unchanged(out)
	_fixture._routes._location_token -= 1
	_fixture._routes._space_token = 1
	assert_equal(_observe(out), &"LOCATION_GEOMETRY_STALE", "foreign coincident Space token")
	_unchanged(out)
	_fixture._routes._space_token = 0


func test_original_real_lease_is_required_before_any_output_write() -> void:
	"""An equally large replacement reservation never revives the old candidate's original lease."""
	var out: Locations.Record = _sentinel()
	assert_equal(_fixture._budget.release(_cold), &"", "actual original lease ends")
	assert_equal(_observe(out), &"LOCATION_TOKEN_STALE", "missing lease")
	_unchanged(out)
	assert_true(_fixture._budget.acquire(RouteTests.COLD_BYTES) > _cold, "replacement real reservation")
	assert_equal(_observe(out), &"LOCATION_TOKEN_STALE", "same bytes, different original token")
	_unchanged(out)


func test_world_retirement_and_reuse_cannot_alias_a_prepared_endpoint() -> void:
	"""The concrete read includes full Directory generation, kind, typed row and reverse ownership."""
	var out: Locations.Record = _sentinel()
	assert_true(_fixture._residents.directory().destroy(_fixture._world), "retire actual World")
	var replacement: Vector2i = _fixture._residents.directory().create(Directory.KIND_WORLD)
	assert_equal(replacement.x, _fixture._world.x, "actual slot reused")
	assert_true(replacement.y > _fixture._world.y, "actual generation advanced")
	assert_equal(_observe(out), &"LOCATION_WORLD_STALE", "old full World refuses")
	_unchanged(out)


func test_strict_public_reader_keeps_complete_observer_refusal() -> void:
	"""A negative-only complete-proof observer still refuses public reads and final graph validation."""
	var actual: ObservedLocations = _fixture._locations as ObservedLocations
	actual.full_refusal = &"TEST_FULL_PROOF_REFUSAL"
	var out: Locations.Record = _sentinel()
	assert_equal(actual.prepared_location_into(actual._token, _endpoint, out), &"TEST_FULL_PROOF_REFUSAL", "strict public proof retained")
	_unchanged(out)
	assert_equal(_observe(out), &"", "observation carries no physical permission")
	assert_equal(_fixture._routes.seal(_fixture._routes._token), &"TEST_FULL_PROOF_REFUSAL", "complete graph proof still refuses")
	assert_false(_fixture._routes._sealed, "no graph publication candidate")


func test_graph_post_validation_rechecks_drift_after_last_metadata_observation() -> void:
	"""Even a successful final observer cannot destroy the World and leave a sealed graph behind."""
	var graph: ObservedRoutes = _fixture._routes as ObservedRoutes
	var out: Locations.Record = _sentinel()
	assert_equal(_observe(out), &"", "valid prior observation")
	graph.after_validation = func() -> void:
		assert_equal(_observe(out), &"", "last row observation sees original World")
		assert_true(_fixture._residents.directory().destroy(_fixture._world), "successful observer retires World")
	assert_equal(graph.seal(graph._token), &"ROUTE_OWNER_UNBOUND", "full post-validation boundary catches drift")
	assert_false(graph._sealed, "no sealed graph escaped")
	assert_equal(graph.last_published_token(), 0, "no published graph receipt")
	assert_equal(_fixture._locations.last_published_token(), 0, "no Location bank published")


func test_final_guard_rechecks_drift_after_successful_seal() -> void:
	"""A valid metadata copy and sealed candidate cannot substitute for the later full publication proof."""
	var graph: Routes = _fixture._routes
	var out: Locations.Record = _sentinel()
	assert_equal(_observe(out), &"", "original source was current")
	assert_equal(graph.seal(graph._token), &"", "actual graph sealed")
	assert_true(_fixture._residents.directory().destroy(_fixture._world), "late actual source retirement")
	assert_equal(graph.prepared_refusal(graph._token), &"ROUTE_OWNER_UNBOUND", "final full guard remains")
	assert_equal(graph.publish(graph._token), &"ROUTE_GEOMETRY_STALE", "no generic publication bypass")
	assert_equal(graph.last_published_token(), 0, "no receipt after source drift")


func test_route_edge_reads_use_fixed_observations_with_the_existing_full_boundaries() -> void:
	"""A real prepared span sees both unborn endpoints without repeating the whole installed census."""
	var actual: ObservedLocations = _fixture._locations as ObservedLocations
	var full_reads: int = actual.full_reads
	var graph: Routes = _fixture._routes
	var remaining: int = graph._remaining
	var edge: Routes.Edge = _fixture._edge(_endpoint, _last_endpoint, [Vector3i(-512, 0, 512), Vector3i(512, 0, 512)])
	assert_equal(graph.stage_add(graph._token, edge).error, &"", "actual span candidate")
	assert_equal(actual.full_reads, full_reads, "no full Location proof for either row observation")
	assert_equal(actual.public_reads, 0, "public full reader remains distinct")
	assert_true(remaining - graph._remaining >= 2 * Locations.PREPARED_OBSERVATION_CHECKS, "both fixed reads prepaid")
	assert_equal(graph.seal(graph._token), &"", "full before/after proof around finite graph scan")
	assert_equal(actual.full_reads, full_reads + 2, "exact two full seal checks, independent of endpoint reads")
	assert_equal(graph.prepared_refusal(graph._token), &"", "final complete proof remains")


func test_prepared_route_read_refuses_before_copy_when_fixed_work_is_unpaid() -> void:
	"""The reduced all-record work is not free metadata work or a reset of either operation budget."""
	var out: Locations.Record = _sentinel()
	_fixture._routes._remaining = Locations.PREPARED_OBSERVATION_CHECKS - 1
	var location_checks: int = _fixture._locations._remaining
	assert_equal(_fixture._routes._location_into(_endpoint, out), &"ROUTE_OPERATION_BUDGET", "insufficient fixed work")
	_unchanged(out)
	assert_equal(_fixture._locations._remaining, location_checks, "no Location work reset or hidden proof")


func test_actual_failed_location_operation_cannot_supply_later_metadata() -> void:
	"""Use the actual sticky failed-spend state, without adding a cache or resetting the old operation."""
	var actual: Locations = _fixture._locations
	assert_false(actual._spend(actual._remaining + 1), "real finite operation exhausts")
	assert_equal(actual._remaining, -1, "actual original failure sentinel")
	var out: Locations.Record = _sentinel()
	assert_equal(_observe(out), &"LOCATION_OPERATION_BUDGET", "failed candidate cannot supply a row")
	_unchanged(out)
	assert_equal(actual._remaining, -1, "observation did not reset the failed operation")


func test_malformed_output_and_replaced_bank_arrays_refuse_before_indexing() -> void:
	"""A malformed caller or inconsistent reserved bank produces a refusal, not partial output or a runtime error."""
	var out: Locations.Record = _sentinel()
	out.support.resize(5)
	assert_equal(_observe(out), &"LOCATION_OUTPUT_SHAPE", "caller must retain both six-I32 arrays")
	assert_equal(out.point, Vector3i(901, 902, 903), "no scalar copied before shape refusal")
	assert_equal(out.support, PackedInt32Array([7, 8, 9, 10, 11]), "malformed caller array unchanged")
	out = _sentinel()
	var present: PackedByteArray = _fixture._locations._stage.present
	_fixture._locations._stage.present = PackedByteArray()
	assert_equal(_observe(out), &"LOCATION_OBSERVATION_SHAPE", "bad reserved bank cannot be indexed")
	_unchanged(out)
	_fixture._locations._stage.present = present
	assert_equal(_observe(out), &"", "original exact bank remains readable")


func test_fixed_namespace_and_geometry_tuple_drift_refuses_unchanged_output() -> void:
	"""Current graph and Location banks must share the original exact Domain and base/target pair."""
	var out: Locations.Record = _sentinel()
	var bounds: PackedInt32Array = _fixture._locations._domain._bounds
	_fixture._locations._domain._bounds = PackedInt32Array()
	assert_equal(_observe(out), &"LOCATION_OWNER_MISMATCH", "malformed fixed Domain refuses")
	_unchanged(out)
	_fixture._locations._domain._bounds = bounds
	_fixture._routes._target_geometry_revision += 1
	assert_equal(_observe(out), &"LOCATION_GEOMETRY_STALE", "target revision is exact")
	_unchanged(out)
	_fixture._routes._target_geometry_revision -= 1
	var token: int = _fixture._owner.begin_stage(_fixture._owner.revision()).token
	assert_equal(_fixture._owner.seal(token), &"", "different real sealed Space candidate")
	assert_equal(_observe(out), &"LOCATION_GEOMETRY_STALE", "unexpected Space candidate cannot alias original zero token")
	_unchanged(out)
	assert_true(_fixture._owner.abort(token), "discard unrelated fixture candidate")
