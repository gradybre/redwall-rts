extends "res://test/framework/test_case.gd"
## Protocol6 static paths over actual source profiles and deliberately authored test geometry.
## Neither these empty corridors nor a successful path claim paid construction or dynamic READY.

const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const WorldFixture := preload("res://test/test_underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")

class Fixture extends WorldFixture:
	var endpoints: Locations = null
	var gateway: Vector2i = NULL_REF
	var face: Vector2i = NULL_REF

	func _actual_binding() -> void:
		"""Use the exact concrete endpoint owner required by the final static reader, before any endpoint exists."""
		endpoints = Locations.new()
		assert_equal(endpoints.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, 1024, 228 * 1024 + 256), &"", "original concrete endpoints")
		var config: Binding.Configuration = Binding.Configuration.new()
		config.routes = _routes; config.owner = _owner; config.sources = _sources; config.locations = endpoints
		config.profiles = _profiles; config.catalog = _catalog; config.levels = _levels; config.movement = _movement
		config.residents = _residents; config.transforms = _transforms; config.world = _world
		config.terrain = _terrain; config.budget = _budget
		_binding = Binding.new()
		assert_equal(_binding.configure(config), &"", "actual original configuration")
		assert_equal(_routes.configure(endpoints, _owner, _sources, _buildings, _budget, _binding,
			1024, 16, 64, 64, Routes.ARENA_BYTES), &"", "actual graph and masks")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles),
			&"", "actual dynamic readers")

	func _location(point: Vector3i) -> Vector2i:
		"""Publish complete original envelope and support through the concrete endpoint owner."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point; row.section = _floor; row.level = 0; row.role = Locations.ROLE_TRANSIT
		row.envelope = PackedInt32Array([point.x - 1256, point.y, point.z - 1256,
			point.x + 1256, point.y + 1036, point.z + 1256])
		row.support = PackedInt32Array([point.x - 406, point.y - 1, point.z - 406,
			point.x + 406, point.y, point.z + 406])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = endpoints.begin_prepare(cold).token
		var added: Locations.Result = endpoints.stage_add(token, row)
		assert_equal(added.error, &"", "whole actual endpoint")
		assert_equal(endpoints.seal(token), &"", "endpoint sealed")
		assert_true(endpoints.publish(token), "endpoint published")
		assert_equal(_budget.release(cold), &"", "endpoint scratch released")
		return added.location

	func connect_legs() -> void:
		"""A gateway turns into a finite232u terminal approach; all four directed masks are independently compiled."""
		var start: Vector3i = Vector3i(X + 512, 512, Z + 512)
		var bend: Vector3i = start + Vector3i(0, 0, 1024)
		var end: Vector3i = bend + Vector3i(232, 0, 0)
		gateway = _location(bend); face = _location(end)
		_publish_leg(_first, gateway, start, bend)
		_publish_leg(gateway, face, bend, end)

	func _publish_leg(first: Vector2i, last: Vector2i, begin: Vector3i, end: Vector3i) -> void:
		"""No direction or certificate is inferred from the opposite route."""
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = last if reverse else first; edge.to_location = first if reverse else last
			var a: Vector3i = end if reverse else begin
			var b: Vector3i = begin if reverse else end
			edge.points = PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z])
			edge.length_u = absi(b.x - a.x) + absi(b.z - a.z)
			assert_equal(_routes.stage_add(token, edge).error, &"", "actual whole-source leg")
		assert_equal(_binding.seal(token), &"", "complete mask and graph sealed")
		assert_equal(_binding.publish(token), &"", "original graph and masks published")
		_end(token)

	func after_each() -> void:
		"""Release the concrete extra endpoint reference as well as all inherited actual owners."""
		endpoints = null
		super.after_each()

var _fixture: Fixture = null
var _remaining: PackedInt32Array = PackedInt32Array([123])


func before_each() -> void:
	"""Keep source geometry exact while labelling the unpaid corridor as test geometry."""
	_fixture = Fixture.new()
	_fixture._turn_source_case = 3
	_fixture._actual_fixture()
	_fixture.connect_legs()
	_remaining[0] = 123
	assert_true(_fixture.failures.is_empty(), "setup: %s" % _fixture.failures)


func after_each() -> void:
	"""No test can silently leave source setup failures or a held cold arena behind."""
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "cleanup: %s" % _fixture.failures)
	_fixture = null


func _query(reverse: bool = false, anchor: int = Step.SHORT_FORWARD, checks: int = Space.MAX_CHECKS) -> StringName:
	"""Static eligibility borrows the actual graph; it never enrolls or changes a Resident."""
	return Itinerary.reachability_refusal(_fixture._binding,
		_fixture.face if reverse else _fixture._first, _fixture._first if reverse else _fixture.face,
		anchor, 1, 3, checks, _remaining)


func test_canonical_gateway_and_finite_step_are_compatible_in_both_directions() -> void:
	"""The source family covers an ordinary turning gateway and actual232u approach/retreat masks."""
	assert_true(_fixture._binding._live.admits(0, Step.GROUND), "real canonical ground mask")
	assert_true(_fixture._binding._live.admits(2, Step.SHORT_FORWARD), "real forward step mask")
	assert_true(_fixture._binding._live.admits(3, Step.SHORT_BACKWARD), "real backward step mask")
	var before: PackedByteArray = _fixture._transforms.state_bytes()
	assert_equal(_query(), &"", "canonical ground then finite approach")
	assert_equal(_fixture._routes._proposed_count, 2, "two real forward edges")
	assert_equal(_fixture._routes._proposed_edges[0], 2, "terminal forward edge")
	assert_equal(_query(true, Step.SHORT_BACKWARD), &"", "finite retreat then canonical ground")
	assert_equal(_fixture._routes._proposed_count, 2, "two real reverse edges")
	assert_equal(_fixture._routes._proposed_edges[0], 1, "terminal ground return edge")
	assert_equal(_fixture._transforms.state_bytes(), before, "static planning never moves a Resident")


func test_short_profiles_require_matching_source_family_heading_and_policy() -> void:
	"""The new anchor can use its exact finite steps and all-yaw ground, while other headings and WORK refuse."""
	var profiles: Profiles = _fixture._profiles
	for row: int in [5, 9, Step.SHORT_FORWARD, Step.SHORT_BACKWARD, Step.GROUND]:
		assert_true(Itinerary._compatible(profiles, Step.SHORT_FORWARD, row), "matching selected source %d" % row)
	for row: int in [0, 1, 2, 3, 4, 6, 7, 8, Step.WORK_FIRST, 26, 28]:
		assert_false(Itinerary._compatible(profiles, Step.SHORT_FORWARD, row), "incompatible source %d" % row)


func test_automatic_ground_and_work_cannot_be_ready_anchors() -> void:
	"""Neither old automatic identity nor a work/turn envelope supplies the selected travel heading."""
	for anchor: int in [0, 1, Step.GROUND, Step.WORK_FIRST, 26, 28]:
		var expected: StringName = Itinerary.REFUSE_FAMILY if anchor == 1 or anchor == Step.GROUND else &"ROUTE_PROFILE_MODE"
		assert_equal(_query(false, anchor), expected, "invalid READY anchor %d" % anchor)
		assert_equal(_remaining[0], 123, "refused output unchanged")


func test_missing_current_gateway_bit_cannot_borrow_legacy_ground() -> void:
	"""A negative-only removed certificate cannot be repaired by legacy row1 or another heading."""
	@warning_ignore("integer_division") var byte: int = Step.GROUND / 8
	var before: int = _fixture._binding._live.masks[byte]
	_fixture._binding._live.masks[byte] &= ~(1 << (Step.GROUND % 8))
	assert_equal(_query(), &"ROUTE_NOT_CONNECTED", "canonical gateway bit is mandatory")
	assert_equal(_remaining[0], 123, "no partial output")
	_fixture._binding._live.masks[byte] = before
	assert_equal(_query(), &"", "same exact original graph retries")


func test_payload_revision_digest_and_policy_drift_refuse_without_partial_output() -> void:
	"""A source name and matching headings never exempt any current row or actor identity."""
	var profiles: Profiles = _fixture._profiles
	for field: int in [Profiles.F_SOURCE, Profiles.F_SPECIES, Profiles.F_STAGE, Profiles.F_RIG,
			Profiles.F_POSTURE, Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
		var offset: int = field * profiles._profile_capacity + Step.GROUND
		profiles._live.fields[offset] += 1
		assert_false(Itinerary._compatible(profiles, Step.SHORT_FORWARD, Step.GROUND), "changed field %d" % field)
		profiles._live.fields[offset] -= 1
	var quantity: int = Profiles.L_QUANTITY_MAX * profiles._profile_capacity + Step.GROUND
	profiles._live.quantities[quantity] += 1
	assert_false(Itinerary._compatible(profiles, Step.SHORT_FORWARD, Step.GROUND), "quantity mismatch")
	profiles._live.quantities[quantity] -= 1
	profiles._live.sources[0] ^= 1
	assert_true(_query() != &"", "actor digest drift")
	profiles._live.sources[0] ^= 1
	profiles._live.quantities[Step.SHORT_FORWARD] += 1
	assert_equal(_query(), &"WORLD_ROUTE_PROFILE_STALE", "exact profile revision")
	profiles._live.quantities[Step.SHORT_FORWARD] -= 1
	assert_equal(_remaining[0], 123, "refusal preserves output")
	assert_equal(_query(), &"", "unmodified source retries")


func test_repeated_paths_are_deterministic_and_charge_bounded_work() -> void:
	"""Changing source-family support does not change stable graph search or its comparison budget."""
	assert_equal(_query(), &"", "first query")
	var budget: int = _remaining[0]
	var edges: PackedInt32Array = _fixture._routes._proposed_edges.duplicate()
	for attempt: int in 3:
		assert_equal(_query(), &"", "repeat %d" % attempt)
		assert_equal(_remaining[0], budget, "equal work charged")
		assert_equal(_fixture._routes._proposed_edges, edges, "same original path")
	assert_true(budget > 0 and budget < Space.MAX_CHECKS, "bounded work performed")
	_remaining[0] = 123
	assert_equal(_query(false, Step.SHORT_FORWARD, 2 * WorldRoutes.REACH_SCOPE_CHECKS),
		&"ROUTE_OPERATION_BUDGET", "bounded refusal")
	assert_equal(_remaining[0], 123, "bounded refusal preserves output")


func test_policy_and_missing_bits_refuse_short_rows() -> void:
	"""The terminal row must retain its exact finite policy and live certificate, not just equal geometry."""
	var profiles: Profiles = _fixture._profiles
	var offset: int = profiles._profile_capacity + Step.SHORT_FORWARD
	var original: int = profiles._live.flags[offset]
	profiles._live.flags[offset] = Profiles.POLICY_READY_FORWARD
	assert_false(Itinerary._compatible(profiles, Step.SHORT_BACKWARD, Step.SHORT_FORWARD),
		"ordinary forward policy cannot impersonate finite source")
	profiles._live.flags[offset] = original
	assert_true(Itinerary._compatible(profiles, Step.SHORT_BACKWARD, Step.SHORT_FORWARD), "exact source retry")
	var start: int = 2 * WorldRoutes.MASK_BYTES
	var mask: PackedByteArray = _fixture._binding._live.masks.slice(start, start + WorldRoutes.MASK_BYTES)
	for index: int in WorldRoutes.MASK_BYTES: _fixture._binding._live.masks[start + index] = 0
	assert_equal(_query(), &"ROUTE_NOT_CONNECTED", "no remembered terminal permission")
	assert_equal(_remaining[0], 123, "no partial output")
	for index: int in WorldRoutes.MASK_BYTES: _fixture._binding._live.masks[start + index] = mask[index]
	assert_equal(_query(), &"", "only original bits restored")


func test_stale_endpoint_certificate_and_content_are_rechecked() -> void:
	"""A slot or remembered certificate never substitutes for full live identity."""
	var original: Vector2i = _fixture.face
	_fixture.face.y += 1
	assert_equal(_query(), &"ROUTE_LOCATION_STALE", "endpoint generation")
	_fixture.face = original
	_fixture._binding._live.generations[2] += 1
	assert_true(_query() != &"", "certificate generation")
	_fixture._binding._live.generations[2] -= 1
	_fixture._binding._live.content[2] += 1
	assert_true(_query() != &"", "certificate content revision")
	_fixture._binding._live.content[2] -= 1
	assert_equal(_remaining[0], 123, "all refusals preserve output")
	assert_equal(_query(), &"", "all original identities retry")
