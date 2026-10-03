extends "res://test/framework/test_case.gd"
## Actual Buildings/Construction/Directory identities; spatial extents are synthetic test surveys.
## These fixtures do not qualify profiles, underground Room registration, excavation or navigation.

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const NULL_REF: Vector2i = Vector2i(-1, 0)
const R: int = 32
const O: int = 8

class SyntheticSpatial extends Contract.SpatialAuthority:
	## Actual Rooms, but only synthetic geometry admission for claim-lifetime/identity tests.
	var buildings: Buildings = null
	var domain: Space.Domain = null

	func domain_into(out: Contract.Domain) -> bool:
		"""Copy an explicit test domain; this is not a qualified production spatial adapter."""
		var binding: Dictionary = domain.descriptor()
		out.world_ref = binding.world_ref
		out.datum_u = binding.datum_u
		out.minimum_quantum = binding.min_quantum
		out.size_quanta = binding.size_quanta
		return true

	func room_refusal(room: Vector2i) -> StringName:
		"""This fixture still requires an actual live Room in the shared Buildings owner."""
		return &"" if buildings.is_live_room(room) else &"SYNTHETIC_ROOM_STALE"

	func operation_refusal(_origin: Vector3i, _operation: int, _stage: int, room: Vector2i) -> StringName:
		"""No profiles or geometry are qualified by this deliberately synthetic claim fixture."""
		return room_refusal(room)

	func publish_transition(_origin: Vector3i, _operation: int, _stage: int, _room: Vector2i) -> void:
		"""Synthetic no-op: this fixture never publishes geometry or a usable route."""
		pass

	func discard_transition(_origin: Vector3i, _operation: int, _stage: int, _room: Vector2i) -> void:
		"""No physical geometry preparation exists in this isolated identity/lifetime fixture."""
		pass

class SiteFixture extends RefCounted:
	var sites: Sites = null
	var spatial: SyntheticSpatial = null
	var jobs: Jobs = null

	func _init(construction: Construction, buildings: Buildings, domain: Space.Domain) -> void:
		"""Real physical/accounting identities with explicitly unqualified synthetic space admission."""
		var residents: Residents = Residents.new(buildings.directory())
		jobs = Jobs.new(residents)
		var work: Work = Work.new(jobs)
		var inventory: Inventory = Inventory.new(8, 32)
		var pool: Reservations = Reservations.new()
		var items: Items = Items.new()
		assert(items.load_default(inventory).ok, "fixture catalog")
		var gear: Gear = Gear.new(8)
		assert(gear.bind_equipment(inventory, buildings.directory(), residents).ok, "fixture Gear")
		assert(work.bind_gear(gear).ok, "fixture Work")
		spatial = SyntheticSpatial.new()
		spatial.buildings = buildings
		spatial.domain = domain
		sites = Sites.new(construction, inventory, pool, items, jobs, work, spatial, 32, 8)

	func bind_unstarted_job(site: Vector2i, project: Vector2i) -> bool:
		"""Cancellation still names a real exact-work BUILD Job, even before any material or labor."""
		var remaining: IntMath.IntResult = IntMath.IntResult.new()
		if not sites.construction_owner().remaining_mwu_into(project, remaining):
			return false
		var row: int = jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, remaining.value, 0).value
		return jobs.set_requester(row, project).ok and jobs.set_tool_gate(row, Jobs.GATE_SATISFIED).ok \
			and sites.bind_job(site, jobs.ref_of(row)).ok


class SyntheticLocations extends Owner.ResidentLocations:
	## Real Resident and XYZ stores, explicitly synthetic mode/Room containment for this unit fixture.
	var residents: Residents = null
	var transforms: Transforms = null
	var containing_room: Vector2i = NULL_REF
	var mode: int = 5
	var pose: Transforms.Pose = Transforms.Pose.new()

	func directory() -> Directory:
		"""The real Resident store supplies the same global generations as Buildings."""
		return residents.directory()

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""No production qualification: mode and containment are deliberately fixture-controlled."""
		out.clear()
		if not residents.slot_of_ref(ref).ok or not transforms.read_into(ref, pose):
			return &"SYNTHETIC_LOCATION_STALE"
		out.kind = Directory.KIND_RESIDENT
		out.parent = containing_room
		out.a = pose.x
		out.b = pose.y
		out.c = pose.z
		out.d = mode
		return &""


var _buildings: Buildings = null
var _construction: Construction = null
var _sources: Owner.CoreSources = null
var _owner: Owner = null
var _domain: Space.Domain = null
var _world: Vector2i = NULL_REF
var _hall: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""Borrow real identity owners; synthetic geometry never invents an EntityRef."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_world = _buildings.directory().create(Directory.KIND_WORLD)
	_hall = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["hall"]), 59 * 128 + 58, 0, 1).ref
	_room = _buildings.designate_room(_hall, int(Catalog.ROOM_TYPE["DORMITORY"]), _room_tiles()).ref
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction)
	_domain = _new_domain()
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain, R, O), &"", "actual world binding")
	assert_true(_buildings.is_live_room(_room), "real room fixture")


func after_each() -> void:
	"""Release borrowed stores without reference cycles or retained engine objects."""
	_owner = null
	_sources = null
	_domain = null
	_construction = null
	_buildings = null


func _room_tiles() -> PackedInt32Array:
	"""GDD hall's first five columns; only actual source identity comes from this ground room."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for z: int in range(60, 68):
		for x: int in range(59, 64):
			tiles.append(z * 128 + x)
	return tiles


func _new_domain(checks: int = 100000) -> Space.Domain:
	"""Explicit negative-coordinate bounds and operation budget are synthetic, not production defaults."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(16, 16, 16),
		64, 64, checks), &"", "domain")
	return domain


func _begin() -> int:
	"""Use the exact live revision at the cold transaction boundary."""
	var result: Owner.Result = _owner.begin_stage(_owner.revision())
	assert_true(result.ok(), "prepare: %s" % result.error)
	return result.token


func _region(box: Array[int], role: int, ref: Vector2i, level: int = 1) -> Owner.Region:
	"""One input packet, never an authoritative per-entity object."""
	var region: Owner.Region = Owner.Region.new()
	region.box = PackedInt32Array(box)
	region.role = role
	region.owner = ref
	region.level = level
	return region


func _put(token: int, region: Owner.Region) -> Vector2i:
	"""Append a checked staged extent and retain its exact internal generation."""
	var result: Owner.Result = _owner.stage_add(token, region)
	assert_true(result.ok(), "region: %s" % result.error)
	return result.handle


func _publish(token: int) -> void:
	"""Model immediate prepare/preflight/publish with no physical mutation or yielding in between."""
	assert_equal(_owner.seal(token), &"", "sealed")
	assert_equal(_owner.prepared_refusal(token), &"", "immediate identity preflight")
	_owner.publish(token)


func _snapshot() -> Space.Snapshot:
	"""Return copied complete actual facts and blockers, with one explicit project exemption."""
	var result: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_into(result), &"", "snapshot")
	return result


func test_unbound_source_identity_and_capacity_refuse_before_allocation() -> void:
	"""The empty/unconfigured base cannot declare an underground world clear or supported."""
	var absent: Owner = Owner.new(Owner.Sources.new())
	assert_equal(absent.configure(_domain, R, O), &"SPACE_WORLD_UNBOUND", "no source adapter")
	assert_equal(absent.initialization_refusal(), &"SPACE_WORLD_UNBOUND", "explicit unbound state")
	assert_equal(absent.packed_memory_bytes(), 0, "no allocation")
	var bounded: Owner = Owner.new(_sources)
	assert_equal(bounded.configure(_domain, 65, O), &"SPACE_WORLD_CAPACITY", "capacity beyond domain")
	assert_equal(bounded.configure(_domain, R, 9223372036854775807), &"SPACE_WORLD_CAPACITY", "huge capacity")
	assert_equal(bounded.packed_memory_bytes(), 0, "refusal precedes allocation")
	assert_equal(_owner.configure(_domain, R, O), &"SPACE_WORLD_ALREADY_BOUND", "immutable world")


func test_geometry_is_invisible_until_non_failing_publication() -> void:
	"""Preparation exposes no free void, reservation or half-updated revision to readers."""
	var token: int = _begin()
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	assert_equal(handle, Vector2i(0, 1), "lowest slot, first generation")
	assert_false(_owner.is_live_region(handle), "unpublished handle")
	assert_equal(_snapshot().volumes.role.size(), 0, "live survey stays empty")
	assert_true(_owner.state_bytes().is_empty(), "mid-transaction save refused")
	_publish(token)
	assert_true(_owner.is_live_region(handle), "published handle")
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.DRY_SOLID]), "actual soil")
	assert_equal(_owner.revision(), 2, "one world revision")


func test_abort_wrong_tokens_and_stale_revisions_preserve_live_bytes() -> void:
	"""A failed material transaction can discard only its own preparation and retry afresh."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	_put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.SUPPORT, _world))
	assert_equal(_owner.begin_stage(1).error, &"SPACE_TRANSACTION_BUSY", "one transaction")
	assert_false(_owner.abort(token + 1), "another operation cannot abort")
	assert_true(_owner.abort(token), "abort")
	assert_equal(_owner.state_bytes(), before, "byte exact live state")
	assert_equal(_owner.begin_stage(0).error, &"SPACE_REVISION_STALE", "old proof refuses")
	assert_equal(_owner.stage_remove(token, Vector2i(0, 1)), &"SPACE_TRANSACTION_STALE", "discarded token")
	var next: int = _begin()
	assert_true(next != token, "no transient token reuse")
	assert_true(_owner.abort(next), "retry ends")


func test_snapshot_and_region_results_do_not_alias_authority() -> void:
	"""Caller edits cannot rewrite actual occupancy, the immutable datum or source inventory."""
	var token: int = _begin()
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORTED_VOID, _world))
	_publish(token)
	var copy: Space.Snapshot = _snapshot()
	copy.volumes.hi_x[0] = 8192
	copy.live_refs[0] = 123
	var row: Owner.Region = Owner.Region.new()
	assert_equal(_owner.region_into(handle, row), &"", "region reads")
	row.box[0] = -8192
	assert_equal(_snapshot().volumes.box_at(0), PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), "exact authority remains")
	var domain: Space.Domain = _owner.domain_copy()
	domain._bounds[0] = 0
	assert_equal(_owner.domain_copy().descriptor().bounds_u[0], -8192, "domain copy isolated")


func test_confirmed_claims_block_but_never_supply_void_or_dry_matter() -> void:
	"""A plan marker over dirt is neither a cut nor a finished navigation region."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	_publish(token)
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.DRY_SOLID, Space.OBSTACLE]), "reservation is only blocker")


func test_project_generation_loss_invalidates_confirmed_claims() -> void:
	"""A retired project's numbers cannot remain a valid claim or acquire an exemption."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	_publish(token)
	assert_true(_buildings.directory().destroy(project), "force owner-loss fixture")
	assert_equal(_owner.snapshot_into(Space.Snapshot.new()), &"SPACE_SOURCE_STALE", "stale actual claim refuses")


func test_source_facts_revalidate_even_when_entity_generation_is_unchanged() -> void:
	"""A geometry revision is not proof that a Building's actual placement facts remained unchanged."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "real Building source")
	var region: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _hall))
	_publish(token)
	assert_equal(_owner.source_refusal(_hall), &"", "source valid")
	assert_true(_buildings.set_building_interior_id(_hall, 12).ok, "same entity changes structural fact")
	assert_equal(_owner.source_refusal(_hall), &"SPACE_SOURCE_DRIFT", "exact fact drift")
	token = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"SPACE_SOURCE_REBUILD_REQUIRED", "must remove old geometry")
	assert_equal(_owner.stage_remove(token, region), &"", "remove old extent")
	assert_equal(_owner.stage_source(token, _hall), &"", "now rebind actual facts")
	_publish(token)
	assert_equal(_owner.source_refusal(_hall), &"", "updated exact source")


func test_final_preflight_detects_source_change_after_seal() -> void:
	"""No callback or awaited interval may separate final preflight from physical commit/publication."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "Building source")
	assert_equal(_owner.seal(token), &"", "sealed")
	assert_equal(_owner.stage_source(token, _room), &"SPACE_TRANSACTION_SEALED", "cannot edit sealed candidate")
	assert_true(_buildings.set_building_interior_id(_hall, 17).ok, "actual external mutation")
	assert_equal(_owner.prepared_refusal(token), &"SPACE_SOURCE_DRIFT", "last-moment preflight refuses")
	assert_true(_owner.abort(token), "discard stale preparation")


func test_floor_section_generation_cannot_transfer_furniture_to_reused_floor() -> void:
	"""Removing and reusing the same floor row never silently reparents a bed to another floor."""
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	assert_true(_buildings.is_live_furniture(bed), "actual bed")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	assert_equal(_owner.stage_source(token, bed), &"", "bed source")
	var floor_ref: Vector2i = _put(token, _region([0, -1024, 0, 2048, -1023, 2048], Space.FLOOR_DATUM, _room))
	var bed_box: Owner.Region = _region([0, -1024, 0, 1024, 0, 1024], Space.OBSTACLE, bed)
	bed_box.section = floor_ref
	var bed_ref: Vector2i = _put(token, bed_box)
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, floor_ref), &"", "prepare floor removal")
	assert_equal(_owner.seal(token), &"SPACE_SECTION_STALE", "dependent bed prevents removal")
	var replacement: Vector2i = _put(token, _region([0, -1024, 0, 2048, -1023, 2048], Space.FLOOR_DATUM, _room))
	assert_equal(replacement, Vector2i(floor_ref.x, floor_ref.y + 1), "slot reused with new generation")
	assert_equal(_owner.seal(token), &"SPACE_SECTION_STALE", "old bed link cannot attach to reused row")
	assert_equal(_owner.stage_remove(token, bed_ref), &"", "remove dependent bed geometry")
	_publish(token)
	assert_false(_owner.is_live_region(floor_ref), "old handle stays stale")
	assert_true(_owner.is_live_region(replacement), "new actual floor")


func test_two_levels_use_actual_xyz_and_level_label_cannot_hide_overlap() -> void:
	"""Same X/Z on different heights is separate; two different level labels do not excuse collision."""
	var token: int = _begin()
	_put(token, _region([0, -2048, 0, 1024, -1024, 1024], Space.DRY_SOLID, _world, 1))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORTED_VOID, _world, 2))
	_publish(token)
	assert_equal(_snapshot().volumes.role.size(), 2, "distinct actual heights")
	token = _begin()
	_put(token, _region([0, -2048, 0, 1024, -1024, 1024], Space.UNFINISHED, _world, 99))
	assert_equal(_owner.seal(token), &"SPACE_SURVEY_CONTRADICTION", "actual XYZ governs contradiction")
	assert_true(_owner.abort(token), "refusal leaves actual levels unchanged")


func test_capacity_budget_and_scalar_overflow_refuse_without_live_changes() -> void:
	"""Finite engineering ceilings do not truncate a room or narrow enormous scalar values."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	var invalid: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	invalid.role = 9223372036854775807
	assert_equal(_owner.stage_add(token, invalid).error, &"SPACE_REGION_FORMAT", "role before B8 narrowing")
	invalid.role = Space.OBSTACLE
	invalid.level = 9223372036854775807
	assert_equal(_owner.stage_add(token, invalid).error, &"SPACE_REGION_FORMAT", "level before I32 narrowing")
	assert_true(_owner.abort(token), "invalid stage ends")
	assert_equal(_owner.state_bytes(), before, "live unchanged")
	var limited: Owner = Owner.new(_sources)
	assert_equal(limited.configure(_new_domain(1), R, O), &"", "explicit tiny work budget")
	assert_equal(limited.begin_stage(1).error, &"SPACE_OPERATION_BUDGET", "refuse before bank copy")


func test_saved_columns_roundtrip_and_allocator_continue_identically() -> void:
	"""Every authoritative column and retired generation survives the local schema boundary."""
	var token: int = _begin()
	var first: Vector2i = _put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.SUPPORT, _world))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, first), &"", "leave generation history in free row")
	_publish(token)
	var bytes: PackedByteArray = _owner.state_bytes()
	assert_equal(bytes.size(), 68 * R + 42 * O + 144, "exact persisted payload")
	assert_equal(_owner.packed_memory_bytes(), 149 * R + 92 * O + 288, "two banks, heaps and changed-row scratch")
	var restored: Owner = Owner.new(_sources)
	assert_equal(restored.configure(_domain, R, O), &"", "load target same domain")
	assert_equal(restored.restore_state_bytes(bytes), &"", "validated restore")
	assert_equal(restored.state_bytes(), bytes, "all columns byte exact")
	var resumed: Owner.Result = restored.begin_stage(restored.revision())
	var added: Owner.Result = restored.stage_add(resumed.token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world))
	assert_equal(added.handle, Vector2i(0, 2), "lowest free row generation preserved")
	assert_true(restored.abort(resumed.token), "roundtrip probe ends")


func test_corrupt_load_never_changes_live_or_partial_geometry() -> void:
	"""Wrong domain, sizes, hidden unused data and malformed lifecycle all fail in the alternate bank."""
	var before: PackedByteArray = _owner.state_bytes()
	var broken: PackedByteArray = before.duplicate()
	broken.resize(broken.size() - 1)
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_SIZE", "truncated")
	broken = before.duplicate()
	broken.encode_s64(5 * 8, 1024)
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_DOMAIN", "datum mismatch")
	broken = before.duplicate()
	broken[144] = 2
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_LIFECYCLE", "presence mask")
	broken = before.duplicate()
	broken[144 + 2 * R] = 1
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_UNUSED", "hidden free geometry")
	assert_equal(_owner.state_bytes(), before, "all corrupt loads atomic")
	assert_false(_owner.has_prepared(), "no failed load keeps transaction lock")


func test_exhausted_generations_retire_instead_of_wrapping() -> void:
	"""An exhausted internal slot remains unavailable after save and load."""
	var bytes: PackedByteArray = _owner.state_bytes()
	bytes[144 + R] = 1
	bytes.encode_s32(144 + 4 * R, 2147483647)
	assert_equal(_owner.restore_state_bytes(bytes), &"", "canonical retired row")
	var token: int = _begin()
	var next: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	assert_equal(next, Vector2i(1, 1), "skip retired row zero")
	_publish(token)
	bytes = _owner.state_bytes()
	bytes.encode_s64(17 * 8, 9223372036854775807)
	assert_equal(_owner.restore_state_bytes(bytes), &"", "maximum world revision can be read")
	assert_equal(_owner.begin_stage(_owner.revision()).error, &"SPACE_REVISION_EXHAUSTED", "no revision wrap")


func test_finite_source_and_region_capacity_refuse_without_truncation() -> void:
	"""A full arena explicitly refuses; no room extent or owner is silently omitted."""
	var tiny: Owner = Owner.new(_sources)
	assert_equal(tiny.configure(_domain, 1, 1), &"", "one physical region, one actual world source")
	var token: int = tiny.begin_stage(1).token
	assert_equal(tiny.stage_source(token, _room), &"SPACE_SOURCE_CAPACITY", "world occupies only source row")
	assert_true(tiny.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world)).ok(), "first extent")
	assert_equal(tiny.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world)).error,
		&"SPACE_REGION_CAPACITY", "no truncation")
	assert_true(tiny.abort(token), "capacity failure leaves live empty")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(tiny.snapshot_into(image), &"", "complete image")
	assert_equal(image.volumes.role.size(), 0, "nothing partially published")


func test_two_real_projects_cannot_claim_the_same_actual_volume() -> void:
	"""Other-project conflicts use full Construction references across any nominal level labels."""
	var first_project: Vector2i = _construction.open_build(_hall).ref
	var path: Vector2i = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["dirt_path"]), 0, 0, 1).ref
	var second_project: Vector2i = _construction.open_build(path).ref
	var token: int = _begin()
	for project: Vector2i in [first_project, second_project]:
		var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
		claim.claim_kind = Owner.CLAIM_CONSTRUCTION
		claim.claim_ref = project
		_put(token, claim)
	assert_equal(_owner.seal(token), &"SPACE_RESERVATION_CONFLICT", "no row-order winner")
	assert_true(_owner.abort(token), "neither conflicting claim installed")


func test_final_preflight_revalidates_project_claim_generation() -> void:
	"""Claims are checked even when their project is not a registered geometry source."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	assert_equal(_owner.seal(token), &"", "prepare actual claim")
	assert_true(_buildings.directory().destroy(project), "identity disappears before physical commit")
	assert_equal(_owner.prepared_refusal(token), &"SPACE_SOURCE_STALE", "last-moment claim refusal")
	assert_true(_owner.abort(token), "discard")


func test_region_query_and_source_retirement_keep_internal_namespace_exact() -> void:
	"""The edit query returns generations, and forgetting a source cannot orphan its extents."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "register room")
	var region: Vector2i = _put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.OBSTACLE, _room))
	assert_equal(_owner.stage_forget_source(token, _room), &"SPACE_SOURCE_IN_USE", "cannot orphan")
	_publish(token)
	var hits: PackedInt32Array = PackedInt32Array()
	assert_equal(_owner.overlapping_regions_into(PackedInt32Array([-512, -512, -512, 512, 512, 512]), hits), &"", "query")
	assert_equal(hits, PackedInt32Array([region.x, region.y]), "full internal region handle")
	token = _begin()
	assert_equal(_owner.stage_remove(token, region), &"", "release extent")
	assert_equal(_owner.stage_forget_source(token, _room), &"", "retire source")
	_publish(token)
	assert_equal(_owner.source_revision(_room), 0, "retired source has no revision")
	assert_equal(_owner.source_refusal(_room), &"SPACE_SOURCE_NOT_REGISTERED", "no inherited binding")


func _resident_locations() -> SyntheticLocations:
	"""Bind real transform/resident owners but explicitly label the unqualified containment/mode."""
	var fixture: SyntheticLocations = SyntheticLocations.new()
	fixture.residents = Residents.new(_buildings.directory())
	fixture.transforms = Transforms.new(_buildings.directory())
	fixture.containing_room = _room
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction, fixture)
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain, R, O), &"", "bind explicit resident reader")
	return fixture


func _occupant(token: int, resident: Vector2i, floor_ref: Vector2i) -> Owner.Region:
	"""A synthetic full envelope uses the actual resident feet coordinate supplied through Transform."""
	assert_equal(_owner.stage_source(token, resident), &"", "actual resident source")
	var body: Owner.Region = _region([0, -1024, 0, 1024, 0, 1024], Space.OCCUPANT, resident)
	body.section = floor_ref
	return body


func test_missing_actual_resident_location_reader_never_uses_flat_ground() -> void:
	"""Directory liveness cannot invent Y, a Room or a movement mode."""
	var residents: Residents = Residents.new(_buildings.directory())
	var resident: Vector2i = residents.spawn(&"mouse").ref
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, resident), &"SPACE_RESIDENT_LOCATION_UNBOUND", "no fallback")
	assert_true(_owner.abort(token), "refusal leaves owner unchanged")


func test_resident_xyz_mode_and_generation_changes_invalidate_old_geometry() -> void:
	"""Same X/Z below another floor, posture/mode changes and recycled IDs require new actual evidence."""
	var fixture: SyntheticLocations = _resident_locations()
	var resident: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_true(fixture.transforms.place(resident, 64, -1024, 64, 0), "real XYZ placement")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	var floor_ref: Vector2i = _put(token, _region([0, -1024, 0, 1024, -1023, 1024], Space.FLOOR_DATUM, _room))
	_put(token, _occupant(token, resident, floor_ref))
	_publish(token)
	assert_equal(_owner.source_refusal(resident), &"", "exact actual position")
	fixture.mode = 4
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_DRIFT", "changed movement mode")
	fixture.mode = 5
	assert_true(fixture.transforms.place(resident, 64, -2048, 64, 0), "real lower level")
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_DRIFT", "height drift despite same X/Z")
	assert_true(fixture.residents.despawn(resident).ok, "real resident retires")
	var replacement: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_equal(replacement.x, resident.x, "actual slot reuse")
	assert_true(replacement.y != resident.y, "new generation")
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_STALE", "old occupant cannot follow reused slot")


func test_resident_floor_owner_and_actual_height_are_both_required() -> void:
	"""A Room-shaped reference and a level label cannot move an occupant away from real XYZ."""
	var fixture: SyntheticLocations = _resident_locations()
	var resident: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_true(fixture.transforms.place(resident, 64, -1024, 64, 0), "real position")
	var token: int = _begin()
	var wrong_floor: Vector2i = _put(token, _region([0, -1024, 0, 1024, -1023, 1024], Space.FLOOR_DATUM, _world))
	_put(token, _occupant(token, resident, wrong_floor))
	assert_equal(_owner.seal(token), &"SPACE_SECTION_OWNER", "world floor is not containing Room")
	assert_true(_owner.abort(token), "discard wrong owner")
	token = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room")
	var floor_ref: Vector2i = _put(token, _region([0, -2048, 0, 1024, -2047, 1024], Space.FLOOR_DATUM, _room))
	var body: Owner.Region = _occupant(token, resident, floor_ref)
	body.box = PackedInt32Array([0, -2048, 0, 1024, -1024, 1024])
	_put(token, body)
	assert_equal(_owner.seal(token), &"SPACE_RESIDENT_POSITION", "lower envelope cannot contain actual upper feet")
	assert_true(_owner.abort(token), "discard wrong height")


func test_changed_row_validation_catches_later_row_edit_against_unchanged_earlier_row() -> void:
	"""Incremental pair checking cannot skip the lower-index unchanged half of a new collision."""
	var token: int = _begin()
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var later: Vector2i = _put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.SUPPORTED_VOID, _world))
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	token = _begin()
	assert_equal(_owner.stage_remove(token, later), &"", "replace later row")
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, _world))
	assert_equal(_owner.seal(token), &"SPACE_SURVEY_CONTRADICTION", "edit checked against lower unchanged row")
	assert_true(_owner.abort(token), "refusal atomic")
	var loaded: PackedByteArray = before.duplicate()
	loaded.encode_s32(144 + 8 * R + 4, 0)
	loaded.encode_s32(144 + 20 * R + 4, 1024)
	assert_equal(_owner.restore_state_bytes(loaded), &"SPACE_SURVEY_CONTRADICTION", "incoming changed row also checked")
	assert_equal(_owner.state_bytes(), before, "load failure leaves exact prior image")


func test_load_removal_rechecks_retained_floor_dependents() -> void:
	"""An incoming image with fewer regions must not retain references to a deleted floor generation."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	var floor_ref: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _room))
	var attached: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.PROTECTED_ACCESS, _room)
	attached.section = floor_ref
	_put(token, attached)
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	var corrupt: PackedByteArray = before.duplicate()
	corrupt.encode_s32(144 + 4 * R, 2)
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_SECTION_STALE", "floor generation changed without dependent update")
	assert_equal(_owner.state_bytes(), before, "source and floor data retained")
	corrupt = before.duplicate()
	_erase_saved_region(corrupt, floor_ref.x)
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_SECTION_STALE", "canonical removed floor with retained dependent")
	assert_equal(_owner.state_bytes(), before, "removed-floor refusal preserves live bytes")


func _erase_saved_region(bytes: PackedByteArray, row: int) -> void:
	"""Author an actually absent row under the fixed 1064 wire contract, retaining only its generation."""
	var widths: Array[int] = [1, 1, 1, 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 8, 4, 4]
	var offset: int = 144
	for column: int in widths.size():
		var at: int = offset + widths[column] * row
		if column == 4:
			offset += widths[column] * R
			continue
		if widths[column] == 1:
			bytes[at] = 0
		elif widths[column] == 4:
			bytes.encode_s32(at, -1 if column in [12, 14, 17] else 0)
		else:
			bytes.encode_s64(at, 0)
		offset += widths[column] * R


func test_empty_source_retirement_spends_its_real_scan_budget() -> void:
	"""Repeated empty-source retirement cannot bypass the declared cold transaction work ceiling."""
	var tiny: Owner = Owner.new(_sources)
	assert_equal(tiny.configure(_new_domain(19), 1, 4), &"", "one source edit fits exactly")
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	for source: Vector2i in [_hall, _room, bed]:
		var source_token: int = tiny.begin_stage(tiny.revision()).token
		assert_equal(tiny.stage_source(source_token, source), &"", "register one actual source")
		assert_equal(tiny.seal(source_token), &"", "bounded source transaction")
		tiny.publish(source_token)
	var before: PackedByteArray = tiny.state_bytes()
	var token: int = tiny.begin_stage(tiny.revision()).token
	assert_equal(tiny.stage_forget_source(token, _hall), &"", "first retirement")
	assert_equal(tiny.stage_forget_source(token, _room), &"", "second retirement")
	assert_equal(tiny.stage_forget_source(token, bed), &"SPACE_OPERATION_BUDGET", "third scan refuses before mutation")
	assert_true(tiny.abort(token), "abort over-budget batch")
	assert_equal(tiny.state_bytes(), before, "live source/allocator state remains byte exact")


func _room_claim(token: int, room: Vector2i = NULL_REF) -> Vector2i:
	"""A persistent accepted footprint is owned by its actual Room, not a synthetic paid project."""
	if room == NULL_REF:
		room = _room
	assert_equal(_owner.stage_source(token, room), &"", "actual Room source")
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, room)
	claim.claim_kind = Owner.CLAIM_ROOM
	claim.claim_ref = room
	return _put(token, claim)


func test_room_claim_survives_actual_paid_phase_retirement() -> void:
	"""The confirmed layout outlives each real quantum phase; cancellation cannot erase it."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	assert_equal(fixture.sites.initialization_refusal(), &"", "real Sites composition")
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var phase: Vector2i = fixture.sites.open_phase(site, Contract.OP_BRACE).ref
	assert_true(_construction.is_live_project(phase), "real phase project")
	assert_true(fixture.bind_unstarted_job(site, phase), "real phase Job binds before cancellation")
	var token: int = _begin()
	var claim: Vector2i = _room_claim(token)
	_publish(token)
	var cancelled: Construction.OpResult = fixture.sites.cancel_phase(site, NULL_REF)
	assert_true(cancelled.ok, "unstarted empty phase retires: %s" % cancelled.error)
	assert_false(_construction.is_live_project(phase), "phase generation no longer live")
	assert_true(_owner.is_live_region(claim), "confirmed room claim persists")
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.OBSTACLE]), "ordinary survey still blocks")
	var scoped: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, site), &"", "exact retained physical Room scope")
	assert_equal(scoped.volumes.role.size(), 0, "only that Room's marker omitted")


func test_site_scoped_snapshot_keeps_actual_geometry_and_other_phase_claims() -> void:
	"""An exemption cannot erase residents, fixtures, exits or another paid project's work area."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var project: Vector2i = fixture.sites.open_phase(site, Contract.OP_BRACE).ref
	var token: int = _begin()
	_room_claim(token)
	var phase_claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room)
	phase_claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	phase_claim.claim_ref = project
	_put(token, phase_claim)
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.PROTECTED_ACCESS, _room))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room))
	_publish(token)
	assert_equal(_snapshot().volumes.role.size(), 4, "both markers plus actual geometry")
	var scoped: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, site), &"", "same actual Room/phase scope")
	assert_equal(scoped.volumes.role, PackedInt32Array([Space.PROTECTED_ACCESS, Space.OBSTACLE]), "actual rows retained")
	var next_site: Vector2i = fixture.sites.claim_quantum(Vector3i(1024, 0, 0), _room).ref
	assert_true(fixture.sites.open_phase(next_site, Contract.OP_BRACE).ok, "separate real paid phase")
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, next_site), &"", "different exact phase")
	assert_equal(scoped.volumes.role.size(), 3, "other phase's marker remains blocking")


func test_room_claim_kind_is_typed_and_corrupt_load_refuses() -> void:
	"""A Room cannot impersonate a paid project or lend its claim to another geometric owner."""
	var token: int = _begin()
	var bad: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	bad.claim_kind = Owner.CLAIM_ROOM
	bad.claim_ref = _room
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_ROOM_CLAIM_IDENTITY", "wrong claim owner")
	bad.claim_kind = Owner.CLAIM_CONSTRUCTION
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_PROJECT_IDENTITY", "wrong reference namespace")
	bad.claim_kind = 9223372036854775807
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_RESERVATION_FORMAT", "kind narrowing refused")
	assert_true(_owner.abort(token), "invalid claims unchanged")
	token = _begin()
	_room_claim(token)
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	var corrupt: PackedByteArray = before.duplicate()
	corrupt[144 + 3 * R] = 3
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_REGION_FORMAT", "unknown on-disk claim kind")
	assert_equal(_owner.state_bytes(), before, "corrupt claim load atomic")


func test_foreign_sites_and_changed_domain_cannot_receive_an_exemption() -> void:
	"""Coincident ref numbers and a drifted descriptor never prove the actual world's claim scope."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var other: Construction = Construction.new()
	assert_equal(other.directory().create(Directory.KIND_WORLD), _world, "coincident World numbers in another real directory")
	var foreign: SiteFixture = SiteFixture.new(other, other.buildings(), _domain)
	assert_equal(foreign.sites.initialization_refusal(), &"", "foreign world is separately valid")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(image, foreign.sites, site), &"SPACE_SITE_OWNER_MISMATCH", "actual owner pointer required")
	var shifted: Space.Domain = Space.Domain.new()
	assert_equal(shifted.configure(_world, Vector3i(1024, 0, 0), Vector3i(-8, -8, -8), Vector3i(16, 16, 16), 64, 64, 100000), &"", "different datum")
	fixture.spatial.domain = shifted
	assert_equal(_owner.snapshot_for_site_into(image, fixture.sites, site), &"SPACE_SITE_DOMAIN", "domain identity drift")
