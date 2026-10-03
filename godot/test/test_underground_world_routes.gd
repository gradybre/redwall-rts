extends "res://test/framework/test_case.gd"
## Exact route geometry and publication regression cases. Synthetic extents are explicitly
## local fixtures; source-bound production profiles, demo activation and performance are separate gates.

const Binding := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const ContentFixture := preload("res://test/test_underground_connector_catalog.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Work := preload("res://scripts/core/work.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048
const TEMP: String = "user://world-routes-catalog.bin"
const PROFILE_TEMP: String = "user://world-routes-profiles.bin"


class RefusingLocations extends Locations:
	## A negative-only fault injector retains actual endpoint ownership and validation.
	var refuse_live_read: bool = false

	func read_location_into(location: Vector2i, out: Locations.Record) -> StringName:
		"""Exercise an actual graph refusal after its provider has agreed to the same-stack publication."""
		return &"TEST_FINAL_ENDPOINT_REFUSAL" if refuse_live_read else super.read_location_into(location, out)


class ReenteringTerrain extends Terrain:
	## A negative-only callback probe delegates every physical decision to the real terrain implementation.
	var target: WeakRef = null
	var reentry_code: StringName = &""
	var preparation_code: StringName = &""

	func exclusions_refusal(bounds: PackedInt32Array) -> StringName:
		"""Try a nested scratch read and transaction before returning the actual unchanged local exclusions."""
		if target != null:
			var binding: Binding = target.get_ref() as Binding
			target = null
			reentry_code = binding.actor_admission_refusal(Vector2i(-1, 0), Profiles.Selection.new())
			preparation_code = binding.begin_prepare(1).error
		return super.exclusions_refusal(bounds)


var _residents: Residents = null
var _transforms: Transforms = null
var _buildings: Buildings = null
var _construction: Construction = null
var _inventory: Inventory = null
var _items: Items = null
var _gear: Gear = null
var _carry: Carry = null
var _work: Work = null
var _jobs: Jobs = null
var _pool: Pool = null
var _piles: Piles = null
var _profiles: Profiles = null
var _owner: Owner = null
var _sources: Owner.CoreSources = null
var _locations: RefusingLocations = null
var _budget: Budget = null
var _routes: Routes = null
var _binding: Binding = null
var _world: World = null
var _nodes: Nodes = null
var _terrain: ReenteringTerrain = null
var _movement: Movement = null
var _levels: Levels = null
var _catalog: Catalog = null
var _world_ref: Vector2i = NULL_REF
var _worker: Vector2i = NULL_REF
var _floor: Vector2i = NULL_REF
var _void: Vector2i = NULL_REF
var _first: Vector2i = NULL_REF
var _last: Vector2i = NULL_REF
var _lease: int = 0


func _image(boxes: Array[PackedInt32Array], roles: PackedInt32Array) -> Space.Snapshot:
	"""Explicit source-labeled observation only; none of these fixtures creates a productive physical permission."""
	var image: Space.Snapshot = Space.Snapshot.new()
	image.world_ref = Vector2i(5, 2)
	image.revision = 7
	for index: int in boxes.size():
		assert_true(image.volumes.append(boxes[index], roles[index], 1, Vector2i(6, 3), 2), "bounded synthetic geometry")
	return image


func _proof(boxes: Array[PackedInt32Array], roles: PackedInt32Array, checks: int = 1048576) -> Binding.Clearance:
	"""Tests admit the declared cold pack before creating fixed fragment banks and the isolated observation."""
	assert_true(Binding.COLD_BYTES < Budget.COLD_BYTES, "proof fits the actual shared envelope")
	var proof: Binding.Clearance = Binding.Clearance.new()
	proof.allocate(_image(boxes, roles), checks)
	return proof


func test_union_coverage_requires_every_interior_point_not_corners() -> void:
	"""All outer corners can be covered while a central one-unit slit remains impassable."""
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 10, 10, 10])
	var proof: Binding.Clearance = _proof([
		PackedInt32Array([0, 0, 0, 5, 10, 10]), PackedInt32Array([6, 0, 0, 10, 10, 10])],
		PackedInt32Array([Space.SUPPORTED_VOID, Space.SUPPORTED_VOID]))
	assert_false(proof.covered(bounds, Space.SUPPORTED_VOID), "interior missing plane is not free air")
	assert_equal(proof.error, &"", "missing coverage is distinct from exhausted work allowance")
	assert_equal(proof.count, 1, "one exact uncovered slab remains")
	assert_equal(proof.fragments.slice(0, 6), PackedInt32Array([5, 0, 0, 6, 10, 10]), "exact missing interior")


func test_adjacent_half_open_volumes_cover_without_gaps_or_double_faces() -> void:
	"""Exact shared faces suffice; either order yields complete coverage without requiring overlap."""
	var a: PackedInt32Array = PackedInt32Array([-10, -4, -8, 0, 8, 8])
	var b: PackedInt32Array = PackedInt32Array([0, -4, -8, 10, 8, 8])
	for reverse: bool in [false, true]:
		var boxes: Array[PackedInt32Array] = [a, b]
		if reverse:
			boxes.reverse()
		var proof: Binding.Clearance = _proof(boxes, PackedInt32Array([Space.SUPPORTED_VOID, Space.SUPPORTED_VOID]))
		assert_true(proof.covered(PackedInt32Array([-10, -4, -8, 10, 8, 8]), Space.SUPPORTED_VOID), "union spans exact face")
		assert_equal(proof.count, 0, "nothing silently discarded")


func test_support_residual_needs_both_authored_stance_and_actual_support() -> void:
	"""A negative body bound is retained; stance alone cannot excuse arbitrary penetration below the floor."""
	var body: PackedInt32Array = PackedInt32Array([-8, -1, -8, 8, 10, 8])
	var stance: PackedInt32Array = PackedInt32Array([-8, -2, -8, 8, 0, 8])
	var proof: Binding.Clearance = _proof([
		PackedInt32Array([-20, 0, -20, 20, 20, 20]), PackedInt32Array([-20, -4, -20, 20, 0, 20])],
		PackedInt32Array([Space.SUPPORTED_VOID, Space.SUPPORT]))
	proof.start(body)
	assert_true(proof.subtract_role(Space.SUPPORTED_VOID), "subtract actual clear body volume")
	assert_equal(proof.count, 1, "below-floor body residual remains")
	assert_true(proof.subtract_role(Space.SUPPORT, stance), "actual support intersected with exact stance")
	assert_equal(proof.count, 0, "complete body now proved without clipping")
	stance[0] += 1
	proof.start(body)
	assert_true(proof.subtract_role(Space.SUPPORTED_VOID), "independent narrow-stance attempt")
	assert_true(proof.subtract_role(Space.SUPPORT, stance), "intersection remains exact")
	assert_equal(proof.count, 1, "one-unit body outside authored stance refuses")


func test_unfinished_walls_access_and_foreign_claim_observations_remain_blocking() -> void:
	"""Positive void coverage cannot cancel a coincident physical blocker in a traversal image."""
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 10, 10, 10])
	for role: int in [Space.OBSTACLE, Space.UNFINISHED, Space.PROTECTED_ACCESS, Space.OPENABLE_SHELL,
			Space.RESOURCE, Space.WATER, Space.OCCUPANT, Space.DRY_SOLID]:
		var proof: Binding.Clearance = _proof([bounds, PackedInt32Array([4, 4, 4, 5, 5, 5])],
			PackedInt32Array([Space.SUPPORTED_VOID, role]))
		assert_true(proof.covered(bounds, Space.SUPPORTED_VOID), "void observation alone covers fixture")
		assert_true(proof.blocked(bounds), "physical negative fact remains decisive")
		assert_false(proof.blocked(PackedInt32Array([5, 0, 0, 10, 10, 10])), "exact half-open face does not overlap")


func test_floor_metadata_and_dry_matter_do_not_create_support_or_air() -> void:
	"""A floor height only names a namespace; negative facts never satisfy the independent positive union."""
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 10, 10, 10])
	var proof: Binding.Clearance = _proof([bounds], PackedInt32Array([Space.FLOOR_DATUM]))
	assert_false(proof.blocked(bounds), "metadata is not a physical wall")
	assert_false(proof.covered(bounds, Space.SUPPORTED_VOID), "metadata cannot make air")
	assert_false(proof.covered(bounds, Space.SUPPORT), "metadata cannot make footing")
	proof = _proof([bounds], PackedInt32Array([Space.DRY_SOLID]))
	assert_false(proof.covered(bounds, Space.SUPPORT), "original dry matter still needs actual support qualification")


func test_subtraction_preserves_six_disjoint_outside_slabs() -> void:
	"""A central obstacle-sized cut has six outside slabs whose exact volume is the cube minus the interior."""
	var proof: Binding.Clearance = _proof([PackedInt32Array([2, 3, 4, 8, 7, 6])], PackedInt32Array([Space.SUPPORTED_VOID]))
	assert_false(proof.covered(PackedInt32Array([0, 0, 0, 10, 10, 10]), Space.SUPPORTED_VOID), "outer volume remains")
	assert_equal(proof.count, 6, "one slab on every side")
	var volume: int = 0
	for row: int in proof.count:
		var a: PackedInt32Array = proof.fragments.slice(row * 6, row * 6 + 6)
		volume += (a[3] - a[0]) * (a[4] - a[1]) * (a[5] - a[2])
		for other: int in range(row + 1, proof.count):
			assert_false(Space.overlaps(a, proof.fragments.slice(other * 6, other * 6 + 6)), "slabs are disjoint")
	assert_equal(volume, 952, "1000 minus6×4×2, no vanished or doubled geometry")


func test_finite_comparison_and_fragment_exhaustion_fail_closed() -> void:
	"""Work/space limits report explicit failure before capacity growth or truncated coverage."""
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 10, 10, 10])
	var proof: Binding.Clearance = _proof([bounds], PackedInt32Array([Space.SUPPORTED_VOID]), 1)
	assert_false(proof.covered(bounds, Space.SUPPORTED_VOID), "one scan is not enough to subtract the actual fragment")
	assert_equal(proof.error, &"WORLD_ROUTE_CHECK_CAPACITY", "explicit work exhaustion")
	assert_equal(proof.fragments.size(), 6144, "fixed admitted arena retained")
	proof = _proof([], PackedInt32Array())
	proof.next_count = Binding.FRAGMENT_CAPACITY
	assert_false(proof._append(bounds), "full destination refuses before the next write")
	assert_equal(proof.error, &"WORLD_ROUTE_FRAGMENT_CAPACITY", "explicit fragment exhaustion")
	assert_equal(proof.next_fragments.size(), 6144, "no fallback unbounded allocation")


func test_certificate_mask_has_independent_profile_bits_and_private_copy() -> void:
	"""All256 finite IDs fit, including the last byte's high bit, without widening a smaller species' proof."""
	var live: Binding.Certificates = Binding.Certificates.new()
	var staged: Binding.Certificates = Binding.Certificates.new()
	live.allocate()
	staged.allocate()
	live.generations[1535] = 7
	live.geometry[1535] = 19
	live.content[1535] = 23
	for profile: int in [0, 7, 8, 255]:
		live.admit(1535, profile)
	staged.copy_from(live)
	staged.clear_row(1535)
	assert_equal(live.generations[1535], 7, "no mutable bank alias")
	assert_equal(staged.generations[1535], 0, "staged generation fully removed")
	for profile: int in 256:
		assert_equal(live.admits(1535, profile), profile in [0, 7, 8, 255], "exact per-profile permission")
		assert_false(staged.admits(1535, profile), "cleared generation has no surviving eligibility")
	assert_equal(Binding.CERTIFICATE_BYTES, 159744, "two complete fixed banks")


func test_unbound_adapter_cannot_admit_or_publish_actual_routes() -> void:
	"""The real provider's defaults refuse; a named component cannot create physical permission."""
	var binding: Binding = Binding.new()
	assert_equal(binding.configure(Binding.Configuration.new()), Binding.REFUSE_BINDING, "missing actual collaborators")
	assert_equal(binding.binding_refusal(), Binding.REFUSE_BINDING, "no remembered configured boolean")
	assert_equal(binding.begin_prepare(1).error, Binding.REFUSE_BINDING, "no unbound candidate")
	assert_equal(binding.travel_refusal(Vector2i(0, 1), Profiles.Selection.new()), Binding.REFUSE_BINDING, "no cached permission")
	assert_equal(binding.publish(1), Binding.REFUSE_CONTEXT, "no unbound graph publication")
	assert_false(binding.abort(1), "no foreign token cancellation")


func _actual_fixture(obstruction: int = 0) -> void:
	"""Actual World/Terrain/stores and adapter; only body certificates and paid surface extents are synthetic."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_residents.directory())
	var forage: Forage = Forage.new(_residents.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_residents.directory(), forage, _jobs)
	_world = World.new(_residents.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new(32, 64)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual item definitions")
	assert_true(_world.generate(World.bound_request(_items).request).ok, "actual terrain generated")
	_world_ref = _residents.directory().create(Directory.KIND_WORLD)
	_worker = _residents.ref_of(_residents.spawn(&"mouse").value)
	_transforms = Transforms.new(_residents.directory())
	assert_true(_transforms.place(_worker, X + 512, 512, Z + 512, 49152), "actual actor pose")
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_budget = Budget.new()
	_actual_profiles()
	_actual_space(obstruction)
	_actual_binding()
	_first = _location(Vector3i(X + 512, 512, Z + 512))
	_last = _location(Vector3i(X + 1536, 512, Z + 512))


func _actual_profiles() -> void:
	"""Real equipment/load/work readers consume clearly labelled synthetic immutable profile content."""
	_pool = Pool.new(64, Pool.JOB_CAPACITY, 64)
	_piles = Piles.new()
	assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
	assert_true(_piles.bind_world(_world_ref), "actual pile World")
	_carry = Carry.new()
	assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
	_work = Work.new(_jobs)
	assert_true(_work.bind_gear(_gear).ok, "actual Work")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(8, 64, 2, Profiles.ARENA_BYTES), &"", "finite synthetic profile arena")
	assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual source readers")
	var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_true(_residents.spatial_profile_identity_into(_worker, identity), "actual actor identity")
	var bytes: PackedByteArray = ContentFixture.synthetic_profile_image(identity)
	assert_equal(_profiles.load_file(PROFILE_TEMP, _write(PROFILE_TEMP, bytes), 1), &"", "synthetic certificate wire")


func _actual_space(obstruction: int) -> void:
	"""Publish explicit test geometry in production-size sparse columns, without asserting paid excavation."""
	_routes = Routes.new(_residents, _transforms)
	_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "finite production Domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual sparse owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	_floor = _region(token, PackedInt32Array([X, 512, Z, X + 2048, 513, Z + 2048]), Space.FLOOR_DATUM)
	_fixture_void(token, obstruction)
	_region(token, PackedInt32Array([X, 256, Z, X + 2048, 512, Z + 2048]), Space.SUPPORT)
	assert_equal(_owner.seal(token), &"", "synthetic extents sealed by actual owner")
	_owner.publish(token)
	_locations = RefusingLocations.new()
	assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
		_owner, _sources, _budget, 8, 228 * 8 + 256), &"", "actual endpoints")
	_terrain = ReenteringTerrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual local exclusions")
	_actual_catalog(domain)


func _fixture_void(token: int, obstruction: int) -> void:
	"""Independent central slit/blocker fixtures leave both complete endpoint envelopes unchanged."""
	if obstruction == 1:
		_void = _region(token, PackedInt32Array([X, 512, Z, X + 1024, 2560, Z + 2048]), Space.SUPPORTED_VOID)
		_region(token, PackedInt32Array([X + 1025, 512, Z, X + 2048, 2560, Z + 2048]), Space.SUPPORTED_VOID)
	else:
		_void = _region(token, PackedInt32Array([X, 512, Z, X + 2048, 2560, Z + 2048]), Space.SUPPORTED_VOID)
	if obstruction == 2:
		_region(token, PackedInt32Array([X + 1024, 512, Z, X + 1025, 1536, Z + 2048]),
			Space.UNFINISHED)
	if obstruction == 3:
		_region(token, PackedInt32Array([X, 256, Z, X + 2048, 512, Z + 2048]), Space.DRY_SOLID)
	if obstruction == 4:
		_region(token, PackedInt32Array([X + 1024, 768, Z, X + 1025, 1024, Z + 2048]), Space.SUPPORT)
	if obstruction == 5:
		_region(token, PackedInt32Array([X + 1024, 768, Z + 641, X + 1025, 1024, Z + 642]), Space.SUPPORT)


func _actual_catalog(domain: Space.Domain) -> void:
	"""An actual Movement profile supplies the pace; synthetic stair rows remain uninstalled data."""
	_movement = Movement.new(_residents.directory(), null, null, _transforms, _residents)
	_levels = Levels.new()
	assert_equal(_levels.load_file(ContentFixture.LEVEL_PATH, ContentFixture.LEVEL_HASH, 1), &"", "authored finite levels")
	assert_equal(_levels.bind_domain(domain, _residents.directory(), domain.descriptor(), Space.VERSION), &"", "exact World binding")
	_catalog = Catalog.new()
	assert_equal(_catalog.configure(Catalog.RESERVED_BYTES), &"", "admitted full catalog lifetime")
	assert_equal(_catalog.bind_actual(_profiles, _levels, _movement, _residents, _transforms, domain), &"", "actual pace owners")
	assert_equal(_load_catalog(1), &"", "test-only geometry and actual source-bound pace")


func _actual_binding() -> void:
	"""Configure the concrete provider before the actual graph, without a synthetic permission callback."""
	_binding = Binding.new()
	var config: Binding.Configuration = Binding.Configuration.new()
	config.routes = _routes
	config.owner = _owner
	config.sources = _sources
	config.locations = _locations
	config.profiles = _profiles
	config.catalog = _catalog
	config.levels = _levels
	config.movement = _movement
	config.residents = _residents
	config.transforms = _transforms
	config.world = _world
	config.terrain = _terrain
	config.budget = _budget
	assert_equal(_binding.configure(config), &"", "real typed route provider")
	assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
		8, 16, 64, 64, Routes.ARENA_BYTES), &"", "actual graph bound back to same provider")
	assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual actor selection")
	assert_equal(_binding.binding_refusal(), &"", "complete actual composition")


func _write(path: String, bytes: PackedByteArray) -> String:
	"""Hash precisely this test-owned file, never author or overwrite a production content pack."""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()


func _load_catalog(revision: int) -> StringName:
	"""A changed immutable content revision must force all retained derived certificates to requalify."""
	var bytes: PackedByteArray = ContentFixture.synthetic_image(revision)
	return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)


func _region(token: int, box: PackedInt32Array, role: int) -> Vector2i:
	"""Explicit finite test fact through actual stage/seal/publish, with full live World source identity."""
	var row: Owner.Region = Owner.Region.new()
	row.box = box
	row.role = role
	row.level = 0
	row.owner = _world_ref
	var result: Owner.Result = _owner.stage_add(token, row)
	assert_equal(result.error, &"", "actual geometry row: %s" % result.error)
	return result.handle


func _location(point: Vector3i) -> Vector2i:
	"""Both endpoints require actual whole envelope/support coverage before any route proof exists."""
	var row: Locations.Record = Locations.Record.new()
	row.point = point
	row.section = _floor
	row.level = 0
	row.role = Locations.ROLE_TRANSIT
	row.envelope = PackedInt32Array([point.x - 256, point.y, point.z - 256, point.x + 256, point.y + 1024, point.z + 256])
	row.support = PackedInt32Array([point.x - 256, point.y - 128, point.z - 256, point.x + 256, point.y, point.z + 256])
	var cold: int = _budget.acquire(Budget.COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	var added: Locations.Result = _locations.stage_add(token, row)
	assert_equal(added.error, &"", "whole endpoint geometry: %s" % added.error)
	assert_equal(_locations.seal(token), &"", "actual endpoint sealed")
	assert_true(_locations.publish(token), "actual endpoint published")
	assert_equal(_budget.release(cold), &"", "no output retained")
	return added.location


func _edge() -> Routes.Edge:
	"""An exact one-metre horizontal span across one actual dry World tile."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = _first
	edge.to_location = _last
	edge.section = _floor
	edge.level = 0
	edge.family = -1
	edge.variant = 0
	edge.mode = Profiles.MODE_WALK
	edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = _profiles.content_revision()
	edge.geometry_revision = _owner.revision()
	edge.point_count = 2
	edge.points = PackedInt32Array([X + 512, 512, Z + 512, X + 1536, 512, Z + 512])
	edge.length_u = 1024
	return edge


func _begin() -> int:
	"""The caller owns the whole exact shared lease until candidate proof and publication are gone."""
	_lease = _budget.acquire(Budget.COLD_BYTES)
	var result: Routes.Result = _binding.begin_prepare(_lease)
	assert_equal(result.error, &"", "actual route preparation: %s" % result.error)
	return result.token


func _end(token: int) -> void:
	"""Abort an uncommitted candidate if present and release only this fixture's exact memory token."""
	_binding.abort(token)
	assert_equal(_budget.release(_lease), &"", "cold result lifetime ended")
	_lease = 0


func _publish_route() -> Vector2i:
	"""All real provider checks must pass before either actual graph or its eligibility bank publishes."""
	var token: int = _begin()
	var added: Routes.Result = _routes.stage_add(token, _edge())
	assert_equal(added.error, &"", "complete continuous route proof: %s" % added.error)
	assert_equal(_binding.seal(token), &"", "actual graph plus certificate sealed")
	assert_equal(_binding.publish(token), &"", "same-stack actual graph/certificate publication")
	_end(token)
	return added.ref


func _admit_actor() -> void:
	"""Actual pose/equipment/load and endpoint checks remain separate from static route certification."""
	assert_equal(_routes.admit_actor(_worker, NULL_REF, _first, Profiles.MODE_WALK, 0, -1), &"", "actual actor admitted")


func after_each() -> void:
	"""The actual composition is acyclic; source fixtures never survive in production or another test."""
	if _budget != null:
		assert_true(_budget.is_quiescent(), "exact shared lease returned")
	_binding = null
	_routes = null
	_locations = null
	_owner = null
	_sources = null
	_terrain = null
	_catalog = null
	_levels = null
	_movement = null
	_world = null
	_nodes = null
	_drop_actual_stores()
	_remove_fixture_files()


func _drop_actual_stores() -> void:
	"""Drop actual source owners after their borrowing adapters, never while a query is active."""
	_profiles = null
	_work = null
	_jobs = null
	_carry = null
	_gear = null
	_piles = null
	_pool = null
	_inventory = null
	_items = null
	_transforms = null
	_construction = null
	_buildings = null
	_residents = null
	_budget = null


func _remove_fixture_files() -> void:
	"""Delete only this suite's two explicitly test-owned content wires."""
	for path: String in [TEMP, PROFILE_TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_actual_world_ground_route_moves_actual_actor_at_inherited_pace() -> void:
	"""No synthetic provider grants movement: concrete clearance plus real actor owners admit every tick."""
	_actual_fixture()
	var edge: Vector2i = _publish_route()
	assert_true(edge != NULL_REF, "actual published full edge")
	_admit_actor()
	assert_equal(_routes.request_route(_worker, _last, 1), &"", "source-qualified one-metre route")
	for tick: int in range(1, 11):
		_routes.advance_tick(tick)
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual moving actor remains readable")
	assert_equal(actor.point, Vector3i(X + 1536, 512, Z + 512), "3277u/s reaches1024u within10 fixed ticks")
	assert_equal(actor.location, _last, "actual destination identity retained")
	assert_equal(actor.section, _floor, "actual full floor section")


func test_actual_clear_endpoints_do_not_allow_middle_holes_or_unfinished_volume() -> void:
	"""Whole continuous coverage rejects central missing air and unfinished work between safe endpoints."""
	for obstruction: int in [1, 2]:
		_actual_fixture(obstruction)
		var token: int = _begin()
		var added: Routes.Result = _routes.stage_add(token, _edge())
		assert_equal(added.error, &"WORLD_ROUTE_NO_FITTING_PROFILE", "endpoints alone cannot admit crossing")
		assert_true(_binding.seal(token) != &"", "refused candidate cannot seal")
		_end(token)
		after_each()


func test_actual_support_excuses_only_authored_below_floor_contact() -> void:
	"""The real adapter keeps the full -1u body bound while proving its exact stance/support intersection."""
	_actual_fixture(3)
	_publish_route()
	_admit_actor()
	assert_equal(_routes.request_route(_worker, _last, 1), &"", "real support covers body residual")


func test_actual_structural_support_inside_void_blocks_body_and_recovery_sweeps() -> void:
	"""Real support between safe endpoints remains solid even where a completed void also overlaps it."""
	for obstruction: int in [4, 5]:
		_actual_fixture(obstruction)
		var token: int = _begin()
		var added: Routes.Result = _routes.stage_add(token, _edge())
		assert_equal(added.error, &"WORLD_ROUTE_NO_FITTING_PROFILE", "support beyond authored stance is physical obstruction")
		assert_true(_binding.seal(token) != &"", "body or recovery collision cannot qualify passage")
		_end(token)
		after_each()


func test_fixed_connector_data_cannot_authorize_an_unbuilt_stair() -> void:
	"""A valid catalog row and empty space are insufficient without the actual paid installed connector owner."""
	_actual_fixture()
	var token: int = _begin()
	var edge: Routes.Edge = _edge()
	edge.family = 0
	var added: Routes.Result = _routes.stage_add(token, edge)
	assert_equal(added.error, &"WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED", "no geometry-only free stair")
	_end(token)


func test_aborted_route_row_cannot_inherit_a_previous_candidates_mask() -> void:
	"""Private masks stay tied to the exact non-reused operation even when local edge identity is reused."""
	_actual_fixture()
	var token: int = _begin()
	var first: Routes.Result = _routes.stage_add(token, _edge())
	assert_equal(first.error, &"", "first private certificate")
	assert_equal(_binding.seal(token), &"", "first sealed")
	_end(token)
	token = _begin()
	var second: Routes.Result = _routes.stage_add(token, _edge())
	assert_equal(second.error, &"", "second separately proved candidate")
	assert_equal(second.ref, first.ref, "aborted allocation reuses same numeric generation")
	assert_true(token != first.token, "operation itself never reused")
	assert_equal(_binding.publish(first.token), Binding.REFUSE_CONTEXT, "old operation cannot publish new bank")
	assert_equal(_binding.seal(token), &"", "current actual proof sealed")
	assert_equal(_binding.publish(token), &"", "only current exact operation publishes")
	_end(token)


func test_catalog_replacement_requires_every_retained_route_to_requalify() -> void:
	"""Refreshing the catalog cannot bless all old masks merely by updating one global revision pin."""
	_actual_fixture()
	var edge: Vector2i = _publish_route()
	assert_equal(_load_catalog(2), &"", "actual immutable catalog replaced")
	var token: int = _begin()
	assert_equal(_binding.seal(token), &"WORLD_ROUTE_CERTIFICATE_STALE", "retained route lacks new proof")
	_end(token)
	token = _begin()
	assert_equal(_routes.stage_refresh(token, edge), &"", "explicit complete new proof")
	assert_equal(_binding.seal(token), &"", "all surviving masks current")
	assert_equal(_binding.publish(token), &"", "replacement certificates published")
	_end(token)
	_admit_actor()
	assert_equal(_routes.request_route(_worker, _last, 1), &"", "current pace and clearance remain usable")


func test_live_resource_change_blocks_motion_without_a_geometry_revision_change() -> void:
	"""A new actual surface resource is not hidden by an earlier cold geometry certificate."""
	_actual_fixture()
	_publish_route()
	_admit_actor()
	assert_equal(_routes.request_route(_worker, _last, 1), &"", "path initially clear")
	var revision: int = _owner.revision()
	var tree: Nodes.OpResult = _nodes.create_at_tile(50 * 128 + 60, _items.compiled_id(&"wood"), 1000, 4, 1)
	assert_true(tree.ok, "actual resource source created")
	assert_equal(_owner.revision(), revision, "no sparse geometry transaction")
	_routes.advance_tick(1)
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "blocked actor remains at safe contact")
	assert_equal(actor.point, Vector3i(X + 512, 512, Z + 512), "fresh exclusions prevent movement")
	assert_true(_nodes.destroy(tree.ref).ok, "actual obstruction removed")
	_routes.advance_tick(2)
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual actor still present")
	assert_true(actor.point.x > X + 512, "fresh local truth permits next legal motion")


func test_exact_cold_lease_loss_refuses_before_certificate_publication() -> void:
	"""A replacement lease of the same byte count cannot authorize a prior candidate or release its owner."""
	_actual_fixture()
	var token: int = _begin()
	assert_equal(_routes.stage_add(token, _edge()).error, &"", "private candidate")
	assert_equal(_binding.seal(token), &"", "sealed masks remain private")
	assert_equal(_budget.release(_lease), &"", "original lease expires")
	_lease = _budget.acquire(Budget.COLD_BYTES)
	assert_equal(_binding.publish(token), Binding.REFUSE_BUDGET, "old exact lease is required")
	assert_equal(_routes.last_published_token(), 0, "neither graph nor masks published")
	_end(token)


func test_late_actual_endpoint_refusal_never_promotes_private_certificates() -> void:
	"""Provider agreement precedes later actual-owner checks and is not graph publication."""
	_actual_fixture()
	var token: int = _begin()
	var added: Routes.Result = _routes.stage_add(token, _edge())
	assert_equal(added.error, &"", "real complete geometry proof")
	assert_equal(_binding.seal(token), &"", "private graph and masks sealed")
	var revision: int = _routes.revision()
	_locations.refuse_live_read = true
	assert_equal(_binding.publish(token), &"TEST_FINAL_ENDPOINT_REFUSAL", "actual endpoint check vetoes final graph swap")
	assert_equal(_routes.last_published_token(), 0, "no actual successful swap")
	assert_equal(_routes.revision(), revision, "live graph unchanged")
	assert_equal(_binding._live.generations[added.ref.x], 0, "private eligibility did not promote early")
	_locations.refuse_live_read = false
	assert_equal(_binding.publish(token), &"", "unchanged exact candidate can finish after valid final checks")
	assert_equal(_routes.last_published_token(), token, "exact actual success receipt")
	assert_equal(_binding._live.generations[added.ref.x], added.ref.y, "only success promotes eligibility")
	_end(token)


func _stage_distant_geometry(offset: int = 4096) -> int:
	"""A real distant obstacle changes the candidate identity without changing endpoint or path clearance."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	_region(token, PackedInt32Array([X + offset, 512, Z, X + offset + 64, 768, Z + 64]), Space.OBSTACLE)
	assert_equal(_owner.seal(token), &"", "actual distinct geometry candidate")
	return token


func test_concrete_provider_requires_the_exact_successful_geometry_companion() -> void:
	"""Identical target revisions after actual abort/replacement cannot promote a different candidate's proof."""
	for replace: bool in [false, true]:
		_actual_fixture()
		var edge: Vector2i = _publish_route()
		var previous: int = _routes.last_published_token()
		var space_token: int = _stage_distant_geometry()
		_lease = _budget.acquire(Budget.COLD_BYTES)
		var candidate: Routes.Result = _binding.begin_prepare(_lease, space_token)
		assert_equal(candidate.error, &"", "actual future traversal snapshot")
		assert_equal(_routes.stage_refresh(candidate.token, edge), &"", "actual full-profile recompilation")
		assert_equal(_binding.seal(candidate.token), &"", "private future masks sealed")
		var published: int = space_token
		if replace:
			assert_true(_owner.abort(space_token), "A discarded after proof")
			published = _stage_distant_geometry(4352)
		_owner.publish(published)
		assert_equal(_owner.last_published_token(), published, "actual successful companion identity")
		var code: StringName = _binding.publish(candidate.token)
		assert_equal(code, &"ROUTE_SPACE_PUBLICATION" if replace else &"", "exact companion, not equal revision")
		assert_equal(_routes.last_published_token(), previous if replace else candidate.token, "only exact graph publishes")
		_end(candidate.token)
		after_each()


func test_geometry_change_invalidates_whole_cached_route_before_new_movement() -> void:
	"""Even a physically distant real publication requires the old certificate to be explicitly refreshed."""
	_actual_fixture()
	_publish_route()
	_admit_actor()
	var token: int = _owner.begin_stage(_owner.revision()).token
	_region(token, PackedInt32Array([X, 3072, Z, X + 2048, 4096, Z + 2048]), Space.UNFINISHED)
	assert_equal(_owner.seal(token), &"", "actual changed geometry")
	_owner.publish(token)
	assert_true(_routes.request_route(_worker, _last, 1) != &"", "old complete proof cannot survive another geometry revision")
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(_transforms.read_into(_worker, pose), "actual pose still readable")
	assert_equal(Vector3i(pose.x, pose.y, pose.z), Vector3i(X + 512, 512, Z + 512), "no hidden relocation")


func test_reentrant_local_source_read_cannot_replace_current_actor_scratch() -> void:
	"""The actual outer admission survives nested read/refused transaction attempts without borrowed state."""
	_actual_fixture()
	_publish_route()
	_terrain.target = weakref(_binding)
	_admit_actor()
	assert_equal(_terrain.reentry_code, Binding.REFUSE_BUSY, "nested query refuses before shared scratch")
	assert_equal(_terrain.preparation_code, Binding.REFUSE_BUSY, "nested preparation cannot copy banks")
	assert_equal(_routes.request_route(_worker, _last, 1), &"", "outer real actor remains independently valid")
	_routes.advance_tick(1)
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual actor retained")
	assert_true(actor.point.x > X + 512, "normal next motion still works")
