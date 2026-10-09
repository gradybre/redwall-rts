extends "res://test/framework/test_case.gd"
## Real current certificates over original Corridor geometry; no paid or dynamic READY permission is supplied.

const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Space := preload("res://scripts/core/room_space.gd")
const GroupFixture := preload("res://test/test_underground_connector_assemblies.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const X: int = Phase.X
const Z: int = Phase.Z
const FLOOR: int = Phase.FLOOR
const TEMP: String = "user://room-itinerary-catalog.bin"

class ObservedDirectory extends Directory:
	var calls: int = 0

	func is_valid_of_kind(ref: Vector2i, expected_kind: int) -> bool:
		"""A negative-only observer must never run inside the pure source boundary."""
		calls += 1
		return super.is_valid_of_kind(ref, expected_kind)

class MixedFixture extends Phase.SourceFixture:

	func _load_catalog(revision: int) -> StringName:
		"""All three source selectors retain actual Movement's unchanged small-Mole ground cap."""
		var bytes: PackedByteArray = GroupFixture._catalog_wire(4, revision)
		bytes.encode_u32(44, 3); bytes.encode_s64(48, 2)
		bytes.resize(bytes.size() - 80)
		for profile: int in [1, 5, 9]:
			GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, 2, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func add_wide_gateway() -> Vector2i:
		"""Publish supported endpoint and both complete all-yaw legs through the original owners."""
		var other: Vector2i = _endpoint(Vector3i(X - 1024, FLOOR, Z + 1536), Locations.ROLE_TRANSIT)
		var token: int = _begin()
		for backwards: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = other if backwards else _first
			edge.to_location = _first if backwards else other
			edge.length_u = 1024
			edge.points = PackedInt32Array([X - 1024, FLOOR, Z + (1536 if backwards else 512),
				X - 1024, FLOOR, Z + (512 if backwards else 1536)])
			assert_equal(_routes.stage_add(token, edge).error, &"", "actual full all-yaw corridor leg")
		assert_equal(_binding.seal(token), &"", "real current certificates")
		assert_equal(_binding.publish(token), &"", "original graph plus masks")
		_end(token)
		return other

var _fixture: MixedFixture = null
var _destination: Vector2i = Vector2i(-1, 0)
var _remaining: PackedInt32Array = PackedInt32Array([123])


func before_each() -> void:
	"""Every case creates actual source owners and three supported points without accepting a Room order."""
	_fixture = MixedFixture.new()
	_fixture._actual_fixture()
	_fixture.connect_source_paths()
	_destination = _fixture.add_wide_gateway()
	_remaining[0] = 123
	assert_true(_fixture.failures.is_empty(), "actual fixture setup: %s" % _fixture.failures)


func after_each() -> void:
	"""Keep original paid state and shared-lease invariants; release every borrowed owner."""
	assert_equal(_fixture.sites._ever_cut.count(1), 0, "no paid cube or free excavation")
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual fixture cleanup: %s" % _fixture.failures)
	_fixture = null


func _query(anchor: int = 9, checks: int = Space.MAX_CHECKS) -> StringName:
	"""A fresh bounded static query never creates or moves an actor."""
	return Itinerary.reachability_refusal(_fixture._binding, _fixture._last, _destination,
		anchor, 1, 2, checks, _remaining)


func test_mixed_backward_and_all_yaw_path_uses_actual_distinct_masks() -> void:
	"""The original one-profile reader cannot express this turn; exact source-compatible legs can."""
	assert_false(_fixture._binding._live.admits(1, 1), "all-yaw source cannot fit the solid work wall")
	assert_true(_fixture._binding._live.admits(1, 9), "complete original backward clearance")
	assert_true(_fixture._binding._live.admits(2, 1), "wide gateway has the full all-yaw envelope")
	assert_false(_fixture._binding._live.admits(2, 9), "backward +X body cannot walk along Z")
	assert_equal(WorldRoutes.profile_reachability_refusal(_fixture._binding, _fixture._last,
		_destination, 9, 1, 2, Space.MAX_CHECKS, _remaining), &"ROUTE_NOT_CONNECTED", "single-profile boundary")
	assert_equal(_query(), &"", "fresh mixed directed path")
	assert_equal(_fixture._routes._proposed_count, 2, "exact two-edge chain")
	assert_equal(_fixture._routes._proposed_edges[0], 2, "last edge in original reverse scratch")
	assert_equal(_fixture._routes._proposed_edges[2], 1, "first edge in original reverse scratch")
	assert_true(_remaining[0] > 0 and _remaining[0] < Space.MAX_CHECKS, "work was charged")


func test_repeated_queries_have_identical_chain_and_budget() -> void:
	"""Stable masks, distance and edge ties produce the same exact fresh result each time."""
	assert_equal(_query(), &"", "first query")
	var debt: int = _remaining[0]
	var path: PackedInt32Array = _fixture._routes._proposed_edges.duplicate()
	for attempt: int in 3:
		assert_equal(_query(), &"", "repeated query %d" % attempt)
		assert_equal(_remaining[0], debt, "equal bounded work")
		assert_equal(_fixture._routes._proposed_edges, path, "same directed chain")
	assert_equal(_fixture._binding._witness_serial, 0, "no one-profile witness borrows a mixed result")


func test_wrong_heading_and_automatic_anchor_do_not_borrow_source_ready() -> void:
	"""Different selected heading has no fitting first leg; automatic identity is not a READY anchor."""
	assert_equal(_query(6), &"ROUTE_NOT_CONNECTED", "opposite family cannot use backward9")
	assert_equal(_remaining[0], 123, "refused output unchanged")
	assert_equal(_query(1), Itinerary.REFUSE_FAMILY, "legacy automatic actor has no source READY")
	assert_equal(_remaining[0], 123, "automatic refusal preserves output")


func test_missing_certificate_never_becomes_an_inferred_leg() -> void:
	"""Removing the only fitting bit cannot be repaired by endpoint adjacency or another Profile."""
	var byte: int = 2 * WorldRoutes.MASK_BYTES
	var before: int = _fixture._binding._live.masks[byte]
	_fixture._binding._live.masks[byte] &= ~(1 << 1)
	assert_equal(_query(), &"ROUTE_NOT_CONNECTED", "actual missing all-yaw certificate")
	assert_equal(_remaining[0], 123, "no partial successful output")
	_fixture._binding._live.masks[byte] = before
	assert_equal(_query(), &"", "restored original exact certificate")


func test_stale_endpoint_and_certificate_full_generations_refuse() -> void:
	"""A matching slot alone cannot identify the current endpoint or certificate."""
	assert_equal(Itinerary.reachability_refusal(_fixture._binding, _fixture._last,
		Vector2i(_destination.x, _destination.y + 1), 9, 1, 2, Space.MAX_CHECKS, _remaining),
		&"ROUTE_LOCATION_STALE", "full endpoint identity")
	_fixture._binding._live.generations[1] += 1
	assert_true(_query() != &"", "wrong certificate generation")
	assert_equal(_remaining[0], 123, "stale refusal preserves output")
	_fixture._binding._live.generations[1] -= 1
	assert_equal(_query(), &"", "current original identities retry")


func test_budget_and_busy_refusals_preserve_output_and_allow_retry() -> void:
	"""No partial result or surviving exclusive latch follows a refused bounded search."""
	assert_equal(_query(9, 2 * WorldRoutes.REACH_SCOPE_CHECKS), &"ROUTE_OPERATION_BUDGET", "initialization debt")
	assert_equal(_remaining[0], 123, "budget output unchanged")
	_fixture._binding._reading = true
	assert_equal(_query(), WorldRoutes.REFUSE_BUSY, "nested read is refused")
	_fixture._binding._reading = false
	assert_equal(_query(), &"", "same original owners retry after refusal")


func test_source_payload_and_quantity_mismatch_are_not_compatible() -> void:
	"""Equal path headings never waive current body, equipment or carried quantity identity."""
	var profiles: Profiles = _fixture._profiles
	assert_true(Itinerary._compatible(profiles, 9, 1), "actual full all-yaw source family")
	for field: int in [Profiles.F_SOURCE, Profiles.F_SPECIES, Profiles.F_STAGE, Profiles.F_RIG,
			Profiles.F_POSTURE, Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
		var offset: int = field * profiles._profile_capacity + 1
		profiles._live.fields[offset] += 1
		assert_false(Itinerary._compatible(profiles, 9, 1), "changed source family field %d" % field)
		profiles._live.fields[offset] -= 1
	var quantity: int = Profiles.L_QUANTITY_MAX * profiles._profile_capacity + 1
	profiles._live.quantities[quantity] += 1
	assert_false(Itinerary._compatible(profiles, 9, 1), "changed carried quantity interval")
	profiles._live.quantities[quantity] -= 1
	assert_equal(_query(), &"", "restored exact source payload")


func test_reverse_mixed_path_needs_its_own_forward_certificate() -> void:
	"""Returning along the same physical gateway requires the independently published opposite legs."""
	assert_equal(Itinerary.reachability_refusal(_fixture._binding, _destination, _fixture._last,
		5, 1, 2, Space.MAX_CHECKS, _remaining), &"", "full all-yaw then selected forward5")
	assert_equal(_fixture._routes._proposed_count, 2, "two original opposite legs")
	assert_equal(_fixture._routes._proposed_edges[0], 0, "last forward5 edge")
	assert_equal(_fixture._routes._proposed_edges[2], 3, "first opposite all-yaw edge")


func test_zero_span_checks_identity_without_inventing_an_edge() -> void:
	"""A supported current point is a zero-leg static route, never proof that an actor is READY there."""
	assert_equal(Itinerary.reachability_refusal(_fixture._binding, _fixture._last, _fixture._last,
		9, 1, 2, Space.MAX_CHECKS, _remaining), &"", "current exact zero span")
	assert_equal(_fixture._routes._proposed_count, 0, "no edge fabricated")
	_remaining[0] = 123
	assert_equal(Itinerary.reachability_refusal(_fixture._binding, _fixture._last, _fixture._last,
		9, 2, 2, Space.MAX_CHECKS, _remaining), &"WORLD_ROUTE_PROFILE_STALE", "zero span still has a full row identity")
	assert_equal(_remaining[0], 123, "stale zero-span output unchanged")


func test_source_digest_and_profile_revision_are_current_on_every_query() -> void:
	"""A cached geometry publication cannot hide an altered source digest or stale selected row."""
	assert_equal(_query(), &"", "original source query")
	_remaining[0] = 123
	_fixture._profiles._live.sources[0] ^= 1
	assert_true(_query() != &"", "changed original Actor digest refuses")
	assert_equal(_remaining[0], 123, "source refusal leaves output unchanged")
	_fixture._profiles._live.sources[0] ^= 1
	_fixture._profiles._live.quantities[9] += 1
	assert_equal(_query(), &"WORLD_ROUTE_PROFILE_STALE", "row revision is exact")
	_fixture._profiles._live.quantities[9] -= 1
	assert_equal(_query(), &"", "original source and revision retry")


func test_directory_observer_is_refused_before_any_final_reader_callback() -> void:
	"""Exact Directory identity closes the reviewed copied-result-then-destroy observer hole."""
	var original: Directory = _fixture.endpoints._ids
	var observed: ObservedDirectory = ObservedDirectory.new()
	_fixture.endpoints._ids = observed
	assert_equal(_query(), WorldRoutes.REFUSE_BINDING, "subclass cannot supply a final source leaf")
	assert_equal(observed.calls, 0, "no overridable read ran")
	assert_equal(_remaining[0], 123, "directory refusal output unchanged")
	_fixture.endpoints._ids = original
	assert_equal(_query(), &"", "original exact Directory remains usable")


func test_equal_distance_parallel_edges_keep_original_slot_tie() -> void:
	"""Publishing another real equal-cost gateway edge does not change the existing stable smaller edge tie."""
	var edge: Routes.Edge = _fixture._edge()
	edge.from_location = _fixture._first; edge.to_location = _destination
	edge.length_u = 1024
	edge.points = PackedInt32Array([X - 1024, FLOOR, Z + 512, X - 1024, FLOOR, Z + 1536])
	var token: int = _fixture._begin()
	var added: Routes.Result = _fixture._routes.stage_add(token, edge)
	assert_equal(added.error, &"", "complete second real path")
	assert_equal(_fixture._binding.seal(token), &"", "real duplicate path certificates")
	assert_equal(_fixture._binding.publish(token), &"", "exact publication")
	_fixture._end(token)
	assert_true(added.ref.x > 2, "higher slot for equal-cost candidate")
	assert_equal(_query(), &"", "two equally short actual paths")
	assert_equal(_fixture._routes._proposed_edges[0], 2, "smaller actual edge wins")


func test_ordinary_provider_uses_mixed_path_without_granting_paid_work() -> void:
	"""The real provider's static path seam consumes the fresh itinerary; no phase is started or paid."""
	assert_equal(_fixture.provider._ordinary_capture_contact(_fixture._last, 24, 0), &"", "derived current contact metadata")
	_fixture.provider._entry_remaining = Space.MAX_CHECKS
	assert_equal(_fixture.provider._ordinary_path(_destination), &"", "provider accepts the actual mixed path")
	assert_true(_fixture.provider._entry_remaining > 0 and _fixture.provider._entry_remaining < Space.MAX_CHECKS,
		"provider propagates the charged remaining work")
	assert_equal(_fixture.sites._ever_cut.count(1), 0, "static access creates no paid progress")
