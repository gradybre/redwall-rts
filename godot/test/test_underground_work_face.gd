extends "res://test/framework/test_case.gd"
## Actual owners with explicitly synthetic profile envelopes and existing paid-space fixtures.
## No production profile qualification, free entrance or productive Site permission is claimed.

const Face := preload("res://scripts/core/underground_work_face.gd")
const Fixture := preload("res://test/test_underground_world_routes.gd")
const OwnerFixture := preload("res://test/test_underground_space_owner.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const BuildingCatalog := preload("res://scripts/core/catalog.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const FLOOR: int = -4608
const X: int = Fixture.X
const Z: int = Fixture.Z


class ObservedLocations extends Fixture.RefusingLocations:
	## Hooks run after actual endpoint reads and can only invalidate an otherwise genuine proof.
	var countdown: int = 0
	var probe: Callable = Callable()
	var fired: int = 0

	func read_location_into(location: Vector2i, out: Locations.Record) -> StringName:
		"""The second successful read is the final source callback in the work-face observation."""
		var code: StringName = super.read_location_into(location, out)
		if countdown > 0:
			countdown -= 1
			if countdown == 0:
				var action: Callable = probe
				probe = Callable()
				fired += 1
				action.call()
		return code


class ObservedSources extends Owner.CoreSources:
	## A real source observation may invalidate the original lease before its caller copies geometry.
	var probe: Callable = Callable()
	var fired: int = 0

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""Return real facts, then consume one observer hook without fabricating geometry permission."""
		var code: StringName = super.read_into(ref, out)
		if probe.is_valid():
			var action: Callable = probe
			probe = Callable()
			fired += 1
			action.call()
		return code


class ObservedSpace extends Owner:
	## Allocation boundary counters observe the real source owner without changing its facts.
	var domain_reads: int = 0
	var snapshot_reads: int = 0
	var region_reads: int = 0
	var region_probe: Callable = Callable()
	var snapshot_probe: Callable = Callable()

	func region_into_reused(handle: Vector2i, out: Owner.Region) -> StringName:
		"""A revoked lease after the first endpoint read must stop before another observation."""
		region_reads += 1
		var code: StringName = super.region_into_reused(handle, out)
		if region_probe.is_valid():
			var action: Callable = region_probe
			region_probe = Callable()
			action.call()
		return code

	func domain_copy() -> Space.Domain:
		"""Denied cold admission must not allocate even the private Domain packet."""
		domain_reads += 1
		return super.domain_copy()

	func snapshot_for_traversal_leased_into(out: Space.Snapshot, budget: Budget, token: int) -> StringName:
		"""Arm the actual source callback only inside the shared leased snapshot operation."""
		var observed: ObservedSources = _sources as ObservedSources
		observed.probe = snapshot_probe
		snapshot_probe = Callable()
		return super.snapshot_for_traversal_leased_into(out, budget, token)

	func _snapshot_image(room: Vector2i, project: Vector2i, traversal: bool) -> Space.Snapshot:
		"""Count entry to the real allocating helper rather than a preceding public observation."""
		snapshot_reads += 1
		return super._snapshot_image(room, project, traversal)


class UndergroundFixture extends Fixture:
	## Synthetic complete corridor at an authored underground floor; all owning stores are real.
	var commands: OwnerFixture.SyntheticRoomCommands = null
	var physical: OwnerFixture.SiteFixture = null
	var room: Vector2i = Vector2i(-1, 0)
	var checks: int = Space.MAX_CHECKS
	var register_building: bool = false
	var watched_building: Vector2i = Vector2i(-1, 0)
	func _actual_space(obstruction: int) -> void:
		"""A complete support/void fixture permits endpoint publication without inventing a production entrance."""
		_routes = Routes.new(_residents, _transforms)
		_sources = ObservedSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 8192, 6144, checks), &"", "actual finite fixture Domain")
		_room_identity(domain)
		_owner = ObservedSpace.new(_sources)
		assert_equal(_owner.configure(domain, 64 if checks <= 4096 else Budget.REGION_CAPACITY,
			16 if checks <= 4096 else Budget.SOURCE_CAPACITY), &"", "actual owner")
		var token: int = _owner.begin_stage(_owner.revision()).token
		if register_building:
			_register_building(token)
		assert_equal(_owner.stage_source(token, room), &"", "actual Room source")
		_floor = _region(token, PackedInt32Array([X, FLOOR, Z, X + 2048, FLOOR + 1, Z + 2048]), Space.FLOOR_DATUM)
		if obstruction == 1:
			_void = _region(token, PackedInt32Array([X, FLOOR, Z, X + 1850, FLOOR + 2048, Z + 2048]), Space.SUPPORTED_VOID)
			_region(token, PackedInt32Array([X + 1851, FLOOR, Z, X + 2048, FLOOR + 2048, Z + 2048]), Space.SUPPORTED_VOID)
		else:
			_void = _region(token, PackedInt32Array([X, FLOOR, Z, X + 2048, FLOOR + 2048, Z + 2048]), Space.SUPPORTED_VOID)
		_region(token, PackedInt32Array([X, FLOOR - 128, Z, X + 2048, FLOOR, Z + 2048]), Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "real owner seals explicit fixture space")
		_owner.publish(token)
		_finish_space(domain)

	func _register_building(token: int) -> void:
		"""The test Building is an actual retained source away from the corridor, before endpoint publication."""
		var result: Buildings.OpResult = _buildings.place_building(int(BuildingCatalog.BUILDING_DEFINITION["well"]),
			40 * 128 + 40, 0, 31)
		assert_true(result.ok, "actual watched Building")
		watched_building = result.ref
		assert_equal(_owner.stage_source(token, watched_building), &"", "retained actual structural source")

	func _finish_space(domain: Space.Domain) -> void:
		"""Bind actual Room/Sites endpoint ownership after the explicit synthetic geometry publication."""
		_locations = ObservedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, 8, 228 * 8 + 256), &"", "actual endpoints")
		assert_equal(_locations.bind_sites(physical.sites), &"", "actual physical ownership")
		_terrain = ReenteringTerrain.new()
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual terrain")
		_actual_catalog(domain)

	func _room_identity(domain: Space.Domain) -> void:
		"""Only the initial complete-shell state is synthetic; Room and physical cut-key identities are real."""
		commands = OwnerFixture.SyntheticRoomCommands.new()
		commands.owner = weakref(_buildings)
		assert_true(_buildings.bind_spatial_authority(commands).ok, "actual Room command owner")
		commands.permit(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_CORRIDOR)
		room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR).ref
		assert_true(_buildings.is_live_room(room), "real permanent Corridor")
		physical = OwnerFixture.SiteFixture.new(_construction, _buildings, domain)
		for x: int in 2:
			assert_true(physical.sites.claim_quantum(Vector3i(X + x * 1024, FLOOR, Z), room).ok, "real endpoint Site key")

	func after_each() -> void:
		"""Synthetic source permissions never survive this test fixture or enter production."""
		physical = null
		commands = null
		super.after_each()

	func _region(token: int, box: PackedInt32Array, role: int) -> Vector2i:
		"""Every fixture region uses the real level1 floor namespace and full Room source."""
		var row: Owner.Region = Owner.Region.new()
		row.box = box
		row.role = role
		row.level = 1
		row.owner = room
		row.section = NULL_REF if role == Space.FLOOR_DATUM else _floor
		var result: Owner.Result = _owner.stage_add(token, row)
		assert_equal(result.error, &"", "actual geometry row")
		return result.handle

	func _location(point: Vector3i) -> Vector2i:
		"""Initial endpoints are already proved by the real Locations support/envelope validator."""
		var row: Locations.Record = Locations.Record.new()
		row.point = Vector3i(point.x, FLOOR, point.z)
		row.section = _floor
		row.room = room
		row.level = 1
		row.role = Locations.ROLE_WORK
		row.envelope = PackedInt32Array([point.x - 256, FLOOR, point.z - 256, point.x + 256, FLOOR + 1024, point.z + 256])
		row.support = PackedInt32Array([point.x - 256, FLOOR - 128, point.z - 256, point.x + 256, FLOOR, point.z + 256])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = _locations.begin_prepare(cold).token
		var added: Locations.Result = _locations.stage_add(token, row)
		assert_equal(added.error, &"", "actual endpoint added")
		assert_equal(_locations.seal(token), &"", "actual endpoint proof")
		assert_true(_locations.publish(token), "actual endpoint published")
		assert_equal(_budget.release(cold), &"", "endpoint lease returned")
		return added.location


var _actual: UndergroundFixture = null
var _face: Face = null
var _config: Fixture.Binding.Configuration = null
var _request: Face.Request = null
var _lease: int = 0
var _replacement: int = 0


func _setup(obstruction: int = 0, checks: int = Space.MAX_CHECKS, registered_building: bool = false) -> void:
	"""Compose real source owners and freeze a test-only BUILD profile independently from production content."""
	_actual = UndergroundFixture.new()
	_actual.checks = checks
	_actual.register_building = registered_building
	_actual._actual_fixture(obstruction)
	assert_true(_actual.failures.is_empty(), "actual corridor fixture checks: %s" % _actual.failures)
	_load_profiles(_boxes())
	_config = Fixture.Binding.Configuration.new()
	_config.routes = _actual._routes
	_config.owner = _actual._owner
	_config.sources = _actual._sources
	_config.locations = _actual._locations
	_config.profiles = _actual._profiles
	_config.residents = _actual._residents
	_config.transforms = _actual._transforms
	_config.terrain = _actual._terrain
	_config.world = _actual._world
	_config.budget = _actual._budget
	_request = Face.Request.new()
	_request.location = _actual._last
	_request.target_origin = Vector3i(X + 2048, FLOOR, Z)
	_request.face = 0
	_request.profile_id = 0
	_request.profile_revision = 1
	_request.content_revision = 2
	_request.geometry_revision = _actual._owner.revision()
	_request.yaw = 49152
	_face = Face.new()
	_lease = _actual._budget.acquire(Budget.COLD_BYTES)


func _boxes() -> Array[PackedInt32Array]:
	"""Synthetic already-oriented box roles independently separate body, foot support, stroke and exact face point."""
	return [PackedInt32Array([-128, -1, -128, 128, 900, 128, Profiles.BODY_HELD_LOAD]),
		PackedInt32Array([-192, -1, -192, 192, 0, 192, Profiles.STANCE_SUPPORT]),
		PackedInt32Array([-160, -1, -160, 160, 900, 160, Profiles.TURN_RECOVERY]),
		PackedInt32Array([-160, 0, -160, 400, 900, 160, Profiles.WORK_APPROACH]),
		PackedInt32Array([400, 256, -32, 700, 768, 32, Profiles.WORK_STROKE]),
		PackedInt32Array([512, 512, 0, 512, 512, 0, Profiles.CONTACT_POINT]),
		PackedInt32Array([512, 500, -12, 512, 524, 12, Profiles.CONTACT_PATCH])]


func _load_profiles(boxes: Array[PackedInt32Array], revision: int = 2, kind: int = Profiles.CONTACT_ANCHOR_AND_PATCH) -> void:
	"""Load a real validated Profiles wire; numeric fixture extents are explicitly not production certificates."""
	var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_true(_actual._residents.spatial_profile_identity_into(_actual._worker, identity), "actual identity")
	var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
	bytes.resize(32)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, revision)
	bytes.encode_u32(20, 1)
	bytes.encode_u32(24, boxes.size())
	bytes.encode_u32(28, 1)
	for index: int in 32:
		bytes.append(7)
	Fixture.ContentFixture._append_row(bytes, PackedInt32Array([0, identity[0], identity[1], identity[2],
		Profiles.MODE_WORK, Profiles.POSTURE_UPRIGHT, -1, -1, -1, -1, Profiles.YAW_EXACT, 49152,
		31, 511, 0, boxes.size(), Jobs.JOB_KIND_BUILD, kind]), 1)
	bytes.resize(bytes.size() + 18)
	bytes[bytes.size() - 2] = Profiles.CERT_REQUIRED
	for box: PackedInt32Array in boxes:
		Fixture.ContentFixture._append_row(bytes, box)
	bytes.append_array("UGPEND01".to_ascii_buffer())
	assert_equal(_actual._profiles.load_file(Fixture.PROFILE_TEMP, _actual._write(Fixture.PROFILE_TEMP, bytes), revision), &"", "actual source load")


func _read() -> StringName:
	"""Read through the public geometry observer without creating an actor, project or physical claim."""
	return _face.solid_face_refusal(_config, _request, _lease)


func after_each() -> void:
	"""Return only leases acquired by this suite, then drop strong query/config references before the fixture."""
	if _actual == null:
		return
	if _actual._budget.covers(_lease, 1):
		assert_equal(_actual._budget.release(_lease), &"", "original lease returned")
	if _replacement > 0:
		assert_equal(_actual._budget.release(_replacement), &"", "test replacement returned")
	_lease = 0
	_replacement = 0
	_face = null
	_config = null
	_request = null
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "nested actual cleanup checks: %s" % _actual.failures)
	_actual = null


func test_exact_complete_corridor_and_authored_stroke_reach_one_solid_face() -> void:
	"""The profile can reach the target from actual supported space, without creating any gameplay state."""
	_setup()
	var before: PackedByteArray = _actual._owner.state_bytes()
	var ids: PackedByteArray = _actual._jobs.directory().state_bytes()
	assert_equal(_read(), &"", "source-bound synthetic profile fits the actual geometry")
	assert_equal(_actual._owner.state_bytes(), before, "no geometry or target opening")
	assert_equal(_actual._jobs.directory().state_bytes(), ids, "no actor, Room or Job created")
	assert_true(_actual._routes.read_actor_into(_actual._worker, Fixture.Routes.Actor.new()) != &"", "no resident admitted")
	assert_equal(Face.COLD_BYTES + 24 * 16384, 772096, "full-size Room coexistence is bounded")


func test_max_face_is_a_legal_exact_plane_without_reversing_already_oriented_boxes() -> void:
	"""A reflected source fixture approaches the other side; contact may equal the cube's high endpoint."""
	_setup()
	var boxes: Array[PackedInt32Array] = _boxes()
	for box: PackedInt32Array in boxes:
		var low: int = box[0]
		box[0] = -box[3]
		box[3] = -low
	_load_profiles(boxes, 3)
	_request.content_revision = 3
	_request.location = _actual._first
	_request.target_origin.x = X - 1024
	_request.face = 1
	assert_equal(_read(), &"", "inclusive max-face contact and immutable source orientation")
	_request.face = 0
	assert_equal(_read(), Face.REFUSE_CONTACT, "opposite plane is not selected contact")


func test_interior_one_unit_void_hole_blocks_approach_even_when_endpoints_fit() -> void:
	"""Exact union coverage catches an interior gap that endpoint and corner sampling misses."""
	_setup(1)
	assert_equal(_read(), Face.REFUSE_BODY, "one-unit approach gap is still solid")


func test_actual_support_and_negative_body_residual_are_never_clipped() -> void:
	"""A source can neither invent support beyond the corridor nor hide body below its authored stance."""
	_setup()
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[1][3] = 700
	_load_profiles(boxes, 3)
	_request.content_revision = 3
	assert_equal(_read(), Face.REFUSE_STANCE, "no floor support outside completed corridor")
	boxes = _boxes()
	boxes[0][1] = -2
	_load_profiles(boxes, 4)
	_request.content_revision = 4
	assert_equal(_read(), Face.REFUSE_BODY, "the second below-root unit is outside authored stance")


func test_stroke_cannot_enter_a_second_solid_cube_or_floor() -> void:
	"""The sole exception is the exact paid-volume candidate, not every point in a large tool AABB."""
	_setup()
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[4][3] = 1600
	_load_profiles(boxes, 3)
	_request.content_revision = 3
	assert_equal(_read(), Face.REFUSE_STROKE, "second cube remains blocked")
	boxes = _boxes()
	boxes[4][1] = -1
	_load_profiles(boxes, 4)
	_request.content_revision = 4
	assert_equal(_read(), Face.REFUSE_STROKE, "tool penetration into actual supporting floor refuses")


func test_full_profile_endpoint_and_face_identity_are_mandatory() -> void:
	"""Same slots, wrong yaw/revisions or an unattested contact cannot produce an observation."""
	_setup()
	_request.profile_revision = 2
	assert_equal(_read(), Face.REFUSE_PROFILE, "profile generation cannot alias")
	_request.profile_revision = 1
	_request.yaw = 0
	assert_equal(_read(), Face.REFUSE_PROFILE, "already-oriented source requires its exact yaw")
	_request.yaw = 49152
	_request.location.y += 1
	assert_true(_read() != &"", "full endpoint generation")
	_request.location.y -= 1
	_request.target_origin.x += 1
	assert_equal(_read(), Face.REFUSE_TARGET, "physical quantum origin cannot be rounded")
	_request.target_origin.x -= 1
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[5][1] = 999
	boxes[5][4] = 999
	boxes[6][1] = 987
	boxes[6][4] = 1011
	_load_profiles(boxes, 3)
	_request.content_revision = 3
	assert_equal(_read(), Face.REFUSE_CONTACT, "face point must also be reached by the actual stroke")


func _expire_lease() -> void:
	"""A real replacement with equal bytes does not preserve the original query's ownership."""
	assert_equal(_actual._budget.release(_lease), &"", "original exact lease released")
	_replacement = _actual._budget.acquire(Budget.COLD_BYTES)
	assert_true(_replacement > 0 and _replacement != _lease, "replacement identity")


func _replace_profiles() -> void:
	"""Change real immutable content after the final endpoint read returns its old complete facts."""
	_load_profiles(_boxes(), 3)


func _change_request() -> void:
	"""A caller may not reuse a successful old packet after selecting a different physical target."""
	_request.target_origin.x += 1024


func test_final_callback_drift_refuses_actual_replacement_and_mutated_input() -> void:
	"""Real mutations at the last callback must be caught by the subsequent callback-free final checks."""
	for action: Callable in [_expire_lease, _replace_profiles, _change_request]:
		_setup()
		var observer: ObservedLocations = _actual._locations as ObservedLocations
		observer.countdown = 2
		observer.probe = action
		assert_true(_read() != &"", "last callback mutation refuses")
		assert_equal(observer.fired, 1, "the final read hook executed")
		after_each()


func test_foreign_arena_or_unbound_sources_never_allocate_geometry_permission() -> void:
	"""An equal token from another live Budget is not the actual owner composition."""
	_setup()
	var foreign: Budget = Budget.new()
	var other_token: int = foreign.acquire(Budget.COLD_BYTES)
	_config.budget = foreign
	assert_equal(_face.solid_face_refusal(_config, _request, other_token), Face.REFUSE_BINDING, "foreign valid arena refused")
	assert_equal(foreign.release(other_token), &"", "test foreign lease returned")
	assert_equal(Face.new().solid_face_refusal(null, _request, _lease), Face.REFUSE_LEASE, "unbound observer")


func test_finite_scan_exhaustion_never_becomes_clearance() -> void:
	"""The actual finite Domain budget includes source passes before any exact fragment operations."""
	_setup(0, 4096)
	var before: PackedByteArray = _actual._owner.state_bytes()
	var observer: ObservedLocations = _actual._locations as ObservedLocations
	var watched: ObservedSpace = _actual._owner as ObservedSpace
	observer.countdown = 1
	observer.probe = _change_request
	watched.snapshot_reads = 0
	assert_equal(_read(), &"WORLD_ROUTE_CHECK_CAPACITY", "terrain and source work are charged before observation")
	assert_equal(observer.fired, 0, "no endpoint callback before unaffordable local/source work")
	assert_equal(watched.snapshot_reads, 0, "no retained geometry copy after early budget refusal")
	assert_equal(_actual._owner.state_bytes(), before, "refused query cannot change authoritative geometry")


func test_original_lease_must_cover_the_whole_packet_before_private_copies() -> void:
	"""One byte short fails before a Domain or physical snapshot is acquired from the actual owner."""
	_setup()
	assert_equal(_actual._budget.release(_lease), &"", "return full fixture lease")
	_lease = _actual._budget.acquire(Face.COLD_BYTES - 1)
	var watched: ObservedSpace = _actual._owner as ObservedSpace
	watched.domain_reads = 0
	watched.snapshot_reads = 0
	assert_equal(_read(), Face.REFUSE_LEASE, "all simultaneous buffers must be admitted")
	assert_equal(watched.domain_reads, 0, "no private Domain copy")
	assert_equal(watched.snapshot_reads, 0, "no actual physical image")


func _reenter() -> void:
	"""A final real source read cannot nest a second observer operation into its caller's lease."""
	assert_equal(_read(), Face.REFUSE_BUSY, "nested read refused")


func test_reentry_poison_survives_final_otherwise_valid_source_read() -> void:
	"""The outer operation must fail too; after it returns, an independent clean query may retry."""
	_setup()
	var observer: ObservedLocations = _actual._locations as ObservedLocations
	observer.countdown = 2
	observer.probe = _reenter
	assert_equal(_read(), Face.REFUSE_BUSY, "outer observation remains poisoned")
	assert_equal(observer.fired, 1, "final source callback ran")
	assert_equal(_read(), &"", "new clean operation can safely retry")


func test_complete_contact_patch_must_fit_one_face_with_the_matching_normal() -> void:
	"""An in-bounds focus anchor cannot conceal a contact patch across an adjacent wall or corner."""
	_setup()
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[6][2] = -513
	_load_profiles(boxes, 3)
	_request.content_revision = 3
	assert_equal(_read(), Face.REFUSE_CONTACT, "one unit of actual contact crosses the target edge")
	boxes = _boxes()
	boxes[6] = PackedInt32Array([500, 500, 0, 524, 524, 0, Profiles.CONTACT_PATCH])
	_load_profiles(boxes, 4)
	_request.content_revision = 4
	assert_equal(_read(), Face.REFUSE_CONTACT, "patch normal must match the selected target face")
	boxes = _boxes()
	boxes.pop_back()
	_load_profiles(boxes, 5, Profiles.CONTACT_ANCHOR_ONLY)
	_request.content_revision = 5
	assert_equal(_read(), Face.REFUSE_PROFILE, "legacy focus point alone cannot qualify a solid contact")


func test_first_endpoint_callback_replaced_lease_stops_before_later_reads() -> void:
	"""A first-read mutation is caught before region or target/snapshot work continues."""
	_setup()
	var observer: ObservedLocations = _actual._locations as ObservedLocations
	var watched: ObservedSpace = _actual._owner as ObservedSpace
	observer.countdown = 1
	observer.probe = _expire_lease
	watched.region_reads = 0
	watched.snapshot_reads = 0
	assert_equal(_read(), Face.REFUSE_LEASE, "original ownership expired during first read")
	assert_equal(observer.fired, 1, "first read hook fired")
	assert_equal(watched.region_reads, 0, "no observation after the invalid lease")
	assert_equal(watched.snapshot_reads, 0, "no later physical image allocation")


func _late_well() -> void:
	"""A real late unregistered footprint protects the target with an eight-metre foundation."""
	var result: Fixture.Buildings.OpResult = _actual._buildings.place_building(
		int(BuildingCatalog.BUILDING_DEFINITION["well"]), 50 * 128 + 61, 0, 31)
	assert_true(result.ok, "late actual well created over the target")


func _late_building_identity() -> void:
	"""Changing an actual retained Building fact does not itself bump the sparse geometry revision."""
	var result: Fixture.Buildings.OpResult = _actual._buildings.set_building_interior_id(_actual.watched_building, 5)
	assert_true(result.ok, "actual Building identity changed")


func test_final_endpoint_callback_cannot_hide_new_actual_terrain_exclusions() -> void:
	"""Checking only old snapshot facts would miss an actual newly placed surface obstruction."""
	_setup()
	var revision: int = _actual._owner.revision()
	var observer: ObservedLocations = _actual._locations as ObservedLocations
	observer.countdown = 2
	observer.probe = _late_well
	assert_equal(_read(), Fixture.Terrain.REFUSE_FOUNDATION, "fresh actual target exclusion refuses")
	assert_equal(observer.fired, 1, "mutation follows the final ordinary endpoint read")
	assert_equal(_actual._owner.revision(), revision, "sparse revision did not identify the new obstruction")


func test_final_endpoint_callback_cannot_hide_retained_actual_building_drift() -> void:
	"""A fresh leaf pass is required after source callbacks, even if a preceding full survey was valid."""
	_setup(0, Space.MAX_CHECKS, true)
	var revision: int = _actual._owner.revision()
	var observer: ObservedLocations = _actual._locations as ObservedLocations
	observer.countdown = 2
	observer.probe = _late_building_identity
	assert_equal(_read(), &"SPACE_SOURCE_DRIFT", "fresh retained actual source mismatch refuses")
	assert_equal(observer.fired, 1, "actual final callback fired")
	assert_equal(_actual._owner.revision(), revision, "identity drift is not a geometry publication")


func test_region_callback_expired_lease_stops_before_target_terrain_observation() -> void:
	"""The later section callback has the same lifetime rule as the first endpoint callback."""
	_setup()
	var watched: ObservedSpace = _actual._owner as ObservedSpace
	watched.region_probe = _expire_lease
	var terrain: Fixture.ReenteringTerrain = _actual._terrain
	terrain.binding_countdown = 1
	terrain.binding_probe = _change_request
	assert_equal(_read(), Face.REFUSE_LEASE, "section callback cannot hand off the original cold ownership")
	assert_equal(terrain.binding_probe_count, 0, "no target terrain query after section ownership expired")


func test_snapshot_source_callback_expired_lease_refuses_before_actual_image_allocation() -> void:
	"""The composed WorkFace cannot allocate after a Sources callback replaces its original cold lease."""
	_setup()
	var watched: ObservedSpace = _actual._owner as ObservedSpace
	var sources: ObservedSources = _actual._sources as ObservedSources
	var before: PackedByteArray = watched.state_bytes()
	watched.snapshot_reads = 0
	watched.snapshot_probe = _expire_lease
	assert_equal(_read(), Budget.REFUSE_TOKEN, "original lease expired inside actual source preflight")
	assert_equal(sources.fired, 1, "real source callback fired within leased snapshot")
	assert_equal(watched.snapshot_reads, 0, "no actual snapshot image under an expired token")
	assert_equal(watched.state_bytes(), before, "read refusal did not publish geometry")
	assert_true(_actual._budget.covers(_replacement, Budget.COLD_BYTES), "new operation's lease preserved")
	_lease = _replacement
	_replacement = 0
	assert_equal(_read(), &"", "independent retry explicitly owns the current lease")
	assert_equal(watched.snapshot_reads, 1, "one valid actual image on retry")
