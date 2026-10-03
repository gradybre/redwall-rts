extends "res://test/framework/test_case.gd"
## Real Room/World, Inventory, Construction, Sites and Work; profiles, support and routes are
## deliberately synthetic fixture inputs. These tests do not qualify production movement/finish.

const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ORIGIN: Vector3i = Vector3i.ZERO


class ObservedSpace extends Owner:
	## Read-only fixture observation proves denied cold allocation never calls the snapshot builder.
	var snapshot_reads: int = 0
	var last_snapshot: WeakRef = null
	var handle_reads: int = 0
	var replace_at_read: int = -1
	var observed_budget: Budget = null
	var observed_token: int = 0
	var replacement_token: int = 0

	func snapshot_for_site_into(out: Space.Snapshot, sites: Sites, site: Vector2i) -> StringName:
		"""Observe the real public survey path without changing its exact output or refusal."""
		snapshot_reads += 1
		last_snapshot = weakref(out)
		return super.snapshot_for_site_into(out, sites, site)

	func overlapping_regions_into(box: PackedInt32Array, out: PackedInt32Array) -> StringName:
		"""Adversarially replace a real cold reservation after the exact live handle observation."""
		var code: StringName = super.overlapping_regions_into(box, out)
		handle_reads += 1
		if code == &"" and observed_budget != null and handle_reads == replace_at_read:
			var released: StringName = observed_budget.release(observed_token)
			assert(released == &"", "fixture replaces its actual current lease")
			replacement_token = observed_budget.acquire(Budget.COLD_BYTES)
		return code


class ObservedAuthority extends Authority:
	## Observe only the returned cold packet sizes, without changing the actual preparation path.
	var finish_front_size: int = -1
	var finish_back_size: int = -1

	func _finish_inputs(check: Authority.ColdCheck, site: Vector2i, room: Vector2i,
			part: Authority.FinishPartition) -> StringName:
		"""Zero bank sizes distinguish early lifetime refusal from eventual late transaction rollback."""
		var code: StringName = super._finish_inputs(check, site, room, part)
		finish_front_size = part.front.size()
		finish_back_size = part.back.size()
		return code


class SyntheticRoomCommands extends Buildings.SpatialAuthority:
	## Fixture registration only; no actual movement, service, geometry or paid work permission.
	var owner: WeakRef = null
	var registering: bool = false

	func buildings_owner() -> RefCounted:
		"""The real Buildings instance remains the sole Room identity owner."""
		return owner.get_ref() if owner != null else null

	func mutation_refusal(action: int, subject: Vector2i, related: Vector2i,
			value: int, rotation: int) -> StringName:
		"""Admit only the single Dormitory registration arranged in this test's setup."""
		return &"" if registering and action == Buildings.SPATIAL_ROOM_CREATE and subject == NULL_REF \
			and related == NULL_REF and value == Buildings.ROOM_TYPE_DORMITORY and rotation == 0 \
			else Buildings.REFUSE_SPATIAL_COMMAND


class SyntheticBindings extends Authority.Bindings:
	## Exact actual identity, explicitly synthetic profiles/structure/contact/service qualification.
	var source_reader: Owner.CoreSources = null
	var owner: Owner = null
	var buildings: Buildings = null
	var jobs: Jobs = null
	var sites: Sites = null
	var inventory: Inventory = null
	var floor_ref: Vector2i = NULL_REF
	var qualified_revision: int = 1
	var cold_reads: int = 0
	var worker_reads: int = 0
	var published: int = 0
	var discarded: int = 0
	var pending: bool = false
	var refusal: StringName = &""
	var dynamic_refusal: StringName = &""
	var output_blocked: bool = false
	var drift_during_qualification: bool = false
	var fail_preparation: bool = false
	var physical_refusal: StringName = &""
	var stage_entry_geometry: bool = false
	var staged_floor: Vector2i = NULL_REF
	var staged_support: Vector2i = NULL_REF
	var saw_sealed_candidate: bool = false
	var cold_denied: bool = false
	var cold_next: int = 1
	var cold_active: int = 0
	var cold_opened: int = 0
	var cold_closed: int = 0
	var cold_attestation: StringName = &""
	var cold_objects_released: bool = true
	var actual_budget: Budget = null
	var last_plan: WeakRef = null
	var plan_limit: int = 32
	var malformed_plan: bool = false
	var expire_after_plan: bool = false
	var saw_checked_plan: bool = false
	var snapshot_refusal: StringName = &""
	var last_survey_stage: int = -1
	var mask_refusal: StringName = &""
	var mask_override_enabled: bool = false
	var mask_override: PackedInt32Array = PackedInt32Array()
	var mask_reads: int = 0
	var mask_row_limit: int = 0
	var mask_expire_after: bool = false
	var mask_drift_after: bool = false

	func sources() -> Owner.CoreSources:
		"""Use the actual reader that owns this fixture's directory and structural facts."""
		return source_reader

	func allocation_refusal(store: Owner, proof_rows: int, cache_bytes: int) -> StringName:
		"""A small explicit fixture allowance; this is not the production joint memory qualification."""
		return &"" if store == owner and proof_rows <= 8 and cache_bytes + owner.packed_memory_bytes() < 1048576 \
			else &"SYNTHETIC_BUDGET"

	func begin_cold_operation(store: Owner, _site: Vector2i, _operation: int, _stage: int) -> int:
		"""Observe one explicit synthetic reservation; production uses the real World-owned Budget."""
		if cold_denied or cold_active != 0 or store != owner:
			return 0
		cold_active = cold_next
		cold_next += 1
		if actual_budget != null:
			cold_active = actual_budget.acquire(Budget.COLD_BYTES)
			(owner as ObservedSpace).observed_token = cold_active
			if cold_active == 0:
				return 0
		cold_opened += 1
		last_plan = null
		(owner as ObservedSpace).last_snapshot = null
		return cold_active

	func cold_operation_refusal(token: int) -> StringName:
		"""An exact active token is necessary; fault injection can revoke its independent proof."""
		if actual_budget != null and not actual_budget.covers(token, Budget.COLD_BYTES):
			return Budget.REFUSE_TOKEN
		return cold_attestation if token > 0 and token == cold_active else &"SYNTHETIC_COLD_TOKEN"

	func end_cold_operation(token: int) -> void:
		"""Weak references prove the adapter releases after its original survey/plan and companions."""
		assert(token > 0 and token == cold_active, "exact cold release once")
		var snapshot: WeakRef = (owner as ObservedSpace).last_snapshot
		cold_objects_released = cold_objects_released and (last_plan == null or last_plan.get_ref() == null) \
			and (snapshot == null or snapshot.get_ref() == null) and not pending
		if actual_budget != null and actual_budget.covers(token, Budget.COLD_BYTES):
			var released: StringName = actual_budget.release(token)
			assert(released == &"", "fixture releases only its unchanged actual lease")
		cold_active = 0
		cold_closed += 1

	func qualification_revision() -> int:
		"""Fixture-controlled revision deliberately stands in for unavailable production measurements."""
		return qualified_revision

	func phase_plan_row_limit(store: Owner, token: int) -> int:
		"""Explicit synthetic allowance; real WorldBindings derives its own joint peak allowance."""
		return plan_limit if store == owner and cold_operation_refusal(token) == &"" else 0

	func phase_snapshot_into(store: Owner, physical: Sites, site: Vector2i, _operation: int,
			stage: int, _room: Vector2i, plan: Space.Plan, out: Space.Snapshot,
			token: int) -> StringName:
		"""Use only the actual sparse fixture image; production composes finite terrain here."""
		saw_checked_plan = last_plan != null and last_plan.get_ref() == plan
		last_survey_stage = stage
		if store != owner or physical != sites or cold_operation_refusal(token) != &"":
			return &"SYNTHETIC_SURVEY_BINDING"
		return owner.snapshot_for_site_into(out, sites, site) if snapshot_refusal == &"" else snapshot_refusal

	func room_refusal(room: Vector2i) -> StringName:
		"""Require an actual underground Room generation; layout coordinates remain synthetic."""
		var kind: Buildings.OpResult = buildings.spatial_kind_of_room(room)
		return &"" if kind.ok and kind.value == Buildings.ROOM_SPACE_UNDERGROUND else &"SYNTHETIC_ROOM_STALE"

	func retirement_refusal(room: Vector2i) -> StringName:
		"""No actual room/service is removed by this synthetic companion fixture."""
		return room_refusal(room)

	func floor_section(_site: Vector2i, _room: Vector2i) -> Vector2i:
		"""Return the actual owner-created synthetic floor region handle, including its generation."""
		return floor_ref

	func finish_mask_into(site: Vector2i, room: Vector2i, token: int,
			row_limit: int, out: PackedInt32Array) -> StringName:
		"""Observe actual fixture claims; override packets deliberately attack the independent paid adapter."""
		mask_reads += 1
		mask_row_limit = row_limit
		if cold_operation_refusal(token) != &"":
			return &"SYNTHETIC_COLD_TOKEN"
		if mask_refusal != &"":
			return mask_refusal
		out.clear()
		var code: StringName = &""
		if mask_override_enabled:
			out.append_array(mask_override)
		else:
			code = _actual_claim_mask(site, room, row_limit, out)
		if mask_expire_after:
			cold_attestation = &"SYNTHETIC_COLD_EXPIRED"
		if mask_drift_after:
			qualified_revision += 1
		return code

	func _actual_claim_mask(site: Vector2i, room: Vector2i, limit: int, out: PackedInt32Array) -> StringName:
		"""Fixture geometry is explicit; real full Room/Site/claim identities determine every emitted box."""
		var cube: PackedInt32Array = Space.quantum_box(owner.domain_copy(), sites.origin_of(site))
		var handles: PackedInt32Array = PackedInt32Array()
		var code: StringName = owner.overlapping_regions_into(cube, handles)
		var region: Owner.Region = Owner.Region.new()
		region.box.resize(6)
		var index: int = 0
		while code == &"" and index < handles.size():
			code = owner.region_into_reused(Vector2i(handles[index], handles[index + 1]), region)
			if code == &"" and region.owner == room and region.claim_kind == Owner.CLAIM_ROOM and region.claim_ref == room:
				if out.size() >= limit * 6:
					return &"SYNTHETIC_MASK_CAPACITY"
				for axis: int in 3:
					out.append(maxi(cube[axis], region.box[axis]))
				for axis: int in 3:
					out.append(mini(cube[axis + 3], region.box[axis + 3]))
			index += 2
		return code

	func phase_plan_into(site: Vector2i, _operation: int, stage: int, room: Vector2i,
			volume_rows_limit: int, out: Space.Plan) -> StringName:
		"""Synthetic one-metre reach envelopes test exact geometry, never authorize real body dimensions."""
		cold_reads += 1
		last_plan = weakref(out)
		out.owner_ref = room
		out.owner_revision = owner.source_revision(room)
		out.expected_revision = owner.revision()
		if stage == Contract.STAGE_CANCEL:
			return &""
		if volume_rows_limit < 2:
			return &"SYNTHETIC_PLAN_CAPACITY"
		var physical: Sites = source_reader.construction_owner().excavation_authority() as Sites
		var origin: Vector3i = physical.origin_of(site)
		out.contacts.approach.append(_translated([-1024, 0, 0, 0, 1024, 1024], origin), Space.ENVELOPE, 1,
			room, out.owner_revision)
		out.contacts.reach.append(_translated([-1024, 0, 0, 1, 1024, 1024], origin), Space.ENVELOPE, 1,
			room, out.owner_revision)
		out.contacts.work_xyz = PackedInt32Array([origin.x, origin.y + 512, origin.z + 512])
		out.contacts.profile_id = PackedInt32Array([7])
		out.contacts.profile_revision = PackedInt64Array([qualified_revision])
		if malformed_plan:
			out.contacts.reach.hi_x.clear()
		if expire_after_plan:
			cold_attestation = &"SYNTHETIC_COLD_EXPIRED"
		return &""

	func _translated(box: Array[int], origin: Vector3i) -> PackedInt32Array:
		"""Translate explicit synthetic metre contacts with the exact actual physical key."""
		var out: PackedInt32Array = PackedInt32Array(box)
		for axis: int in 3:
			out[axis] += origin[axis]
			out[axis + 3] += origin[axis]
		return out

	func phase_qualification_refusal(_domain: Space.Domain, _snapshot: Space.Snapshot,
			_plan: Space.Plan, _site: Vector2i, _operation: int, _stage: int) -> StringName:
		"""The component fixture is explicitly synthetic; revision drift tests refusal before mutation."""
		if drift_during_qualification:
			qualified_revision += 1
		return refusal

	func assigned_worker(_site: Vector2i, job: Vector2i) -> Vector2i:
		"""Read actual full Job generation and actual resident assignment, without inventing either."""
		if not jobs.directory().is_valid_of_kind(job, Directory.KIND_JOB):
			return NULL_REF
		return jobs.worker_of(jobs.directory().get_typed_row(job))

	func worker_refusal(_origin: Vector3i, _operation: int, _room: Vector2i, job: Vector2i,
			worker: Vector2i, _geometry_revision: int, _qualification: int) -> StringName:
		"""Real Job/worker linkage is checked; posture and movement remain synthetic fault injections."""
		worker_reads += 1
		return dynamic_refusal if assigned_worker(NULL_REF, job) == worker else &"SYNTHETIC_WORKER_STALE"

	func material_refusal(_origin: Vector3i, _room: Vector2i, container: Vector2i, _job: Vector2i) -> StringName:
		"""Retain actual Inventory generation/reachability; the location/contact geometry is synthetic."""
		return &"" if inventory.container_reachable(container) else &"SYNTHETIC_CONTAINER"

	func output_refusal(_origin: Vector3i, _operation: int, _room: Vector2i,
			container: Vector2i, _job: Vector2i, _promotion_tile: int) -> StringName:
		"""Inject a changed real-contact dependency while actual Inventory still proves capacity."""
		return &"" if inventory.container_reachable(container) and not output_blocked else &"SYNTHETIC_OUTPUT_BLOCKED"

	func stage_physical_geometry(store: Owner, token: int, site: Vector2i,
			operation: int, stage: int, room: Vector2i, _plan: Space.Plan) -> StringName:
		"""Synthetic dimensions only; actual owner/token/site/Room checks and publication are real."""
		if store != owner or sites == null or sites.room_of(site) != room \
				or sites.construction_owner() != source_reader.construction_owner():
			return &"SYNTHETIC_PHYSICAL_OWNER"
		var code: StringName = owner.stage_source(token, room)
		if code != &"":
			return code
		if stage_entry_geometry and operation == Contract.OP_CUT and stage == Contract.STAGE_COMMIT:
			var floor_region: Owner.Region = Owner.Region.new()
			floor_region.owner = room
			floor_region.level = 1
			floor_region.role = Space.FLOOR_DATUM
			floor_region.box = PackedInt32Array([0, 0, 0, 1024, 1, 1024])
			var added: Owner.Result = owner.stage_add(token, floor_region)
			if not added.ok():
				return added.error
			staged_floor = added.handle
			floor_region.role = Space.SUPPORT
			floor_region.box = PackedInt32Array([0, -128, 0, 1024, 0, 1024])
			added = owner.stage_add(token, floor_region)
			if not added.ok():
				return added.error
			staged_support = added.handle
		return physical_refusal

	func prepare_companions(owner_token: int, site: Vector2i, _operation: int,
			_stage: int, _room: Vector2i, _plan: Space.Plan) -> int:
		"""No service/navigation is published here; the synthetic companion only exercises atomic scope."""
		var candidate: Space.Snapshot = Space.Snapshot.new()
		saw_sealed_candidate = owner.prepared_snapshot_for_site_into(owner_token, candidate, sites, site) == &""
		pending = not fail_preparation and saw_sealed_candidate
		return 1 if pending else 0

	func prepared_refusal(token: int) -> StringName:
		"""A refused prepared companion is observable before the actual Inventory transaction."""
		return &"" if token == 1 and pending else &"SYNTHETIC_COMPANION_STALE"

	func revision_after(_token: int) -> int:
		"""The fixture installs no new qualified content during its no-op companion publication."""
		return qualified_revision

	func discard_companions(_token: int) -> void:
		"""Remove only synthetic pending state; real geometry remains the Owner's responsibility."""
		pending = false
		discarded += 1

	func publish_companions(_token: int) -> void:
		"""Count the actual boundary callback without claiming a real service or route."""
		pending = false
		published += 1


var _residents: Residents = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _jobs: Jobs = null
var _work: Work = null
var _gear: Gear = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _construction: Construction = null
var _buildings: Buildings = null
var _room_commands: SyntheticRoomCommands = null
var _owner: Owner = null
var _sources: Owner.CoreSources = null
var _authority: Authority = null
var _bindings: SyntheticBindings = null
var _sites: Sites = null
var _world: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF
var _site: Vector2i = NULL_REF
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _floor: Vector2i = NULL_REF
var _resident: int = -1
var _tools: Array[Vector2i] = []
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Compose actual owner identities; synthetic geometry dimensions are explicitly isolated."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	_inventory = Inventory.new(16, 512)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual authored catalog")
	_gear = Gear.new(8)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
	assert_true(_work.bind_gear(_gear).ok, "actual Work")
	_store = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_output = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_create_room_and_geometry()
	_bind_space()
	_resident = _worker()


func _create_room_and_geometry() -> void:
	"""An actual underground Room supplies identity; all spatial extents are explicit synthetic inputs."""
	_room_commands = SyntheticRoomCommands.new()
	_room_commands.owner = weakref(_buildings)
	assert_true(_buildings.bind_spatial_authority(_room_commands).ok, "actual Room command owner")
	_room_commands.registering = true
	_room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_DORMITORY).ref
	_room_commands.registering = false
	assert_true(_buildings.is_live_room(_room), "real Room")
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction)
	_owner = ObservedSpace.new(_sources)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-4, -4, -4), Vector3i(8, 8, 8),
		32, 128, 100000), &"", "explicit synthetic domain")
	assert_equal(_owner.configure(domain, 64, 8), &"", "actual owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_source(token, _room), &"", "actual Room source")
	_floor = _add(token, [-1024, 0, 0, 2048, 1, 2048], Space.FLOOR_DATUM, _room)
	_add(token, [-1024, 0, 0, 0, 1024, 2048], Space.SUPPORTED_VOID, _room)
	_add(token, [0, 0, 0, 2048, 1024, 2048], Space.DRY_SOLID, _world)
	_add(token, [0, 0, 0, 2048, 1024, 2048], Space.OBSTACLE, _room, Owner.CLAIM_ROOM)
	assert_equal(_owner.seal(token), &"", "synthetic complete survey")
	_owner.publish(token)


func _add(token: int, box: Array[int], role: int, owner: Vector2i, claim: int = Owner.CLAIM_NONE) -> Vector2i:
	"""One input packet feeds packed actual state; claim identity remains explicitly typed."""
	var region: Owner.Region = Owner.Region.new()
	region.box = PackedInt32Array(box)
	region.role = role
	region.owner = owner
	region.level = 1
	region.claim_kind = claim
	region.claim_ref = owner if claim == Owner.CLAIM_ROOM else NULL_REF
	if owner == _room and role != Space.FLOOR_DATUM:
		region.section = _floor
	var added: Owner.Result = _owner.stage_add(token, region)
	assert_true(added.ok(), "actual spatial row: %s" % added.error)
	return added.handle


func _bind_space() -> void:
	"""Actual Sites accepts only this adapter; synthetic downstream qualification stays labelled."""
	_bindings = SyntheticBindings.new()
	_bindings.source_reader = _sources
	_bindings.owner = _owner
	_bindings.buildings = _buildings
	_bindings.jobs = _jobs
	_bindings.inventory = _inventory
	_bindings.floor_ref = _floor
	_authority = ObservedAuthority.new()
	assert_equal(_authority.configure(_owner, _bindings, 1), &"", "explicit single-proof capacity fixture")
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _authority, 512, 8)
	_bindings.sites = _sites
	assert_equal(_sites.initialization_refusal(), &"", "actual paid physical owners")
	assert_equal(_authority.bind_sites(_sites), &"", "exact actual Sites instance")
	_site = _sites.claim_quantum(ORIGIN, _room).ref
	assert_true(_sites.is_live_site(_site), "exact physical key")


func after_each() -> void:
	"""Release shared actual stores and synthetic qualification without ownership cycles."""
	_assert_cold_released()
	_bindings.sites = null
	_sites = null
	_authority = null
	_bindings = null
	_owner = null
	_sources = null
	_construction = null
	_room_commands = null
	_buildings = null
	_gear = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null
	_pool = null
	_items = null
	_inventory = null
	_tools.clear()


func _assert_cold_released() -> void:
	"""Every completed or refused call must release once, after its charged objects have died."""
	assert_equal(_bindings.cold_active, 0, "no cold reservation escapes the operation")
	assert_equal(_bindings.cold_opened, _bindings.cold_closed, "all acquired leases release exactly once")
	assert_true(_bindings.cold_objects_released, "surveys, plans and companions die before release")


func test_unbound_or_foreign_owner_and_unadmitted_capacity_cannot_allocate_proofs() -> void:
	"""No finite local count or coincident numeric ref grants a real composition budget."""
	var refused: Authority = Authority.new()
	assert_equal(refused.configure(_owner, Authority.Bindings.new(), 8), &"SPACE_AUTHORITY_OWNER_MISMATCH", "base refuses")
	assert_equal(refused.packed_memory_bytes(), 0, "unbound allocates no cache")
	assert_equal(refused.configure(_owner, _bindings, 9), &"SYNTHETIC_BUDGET", "real typed allowance needed")
	assert_equal(refused.packed_memory_bytes(), 0, "budget refusal precedes allocation")
	assert_equal(refused.configure(_owner, _bindings, 9223372036854775807), &"SPACE_PROOF_CAPACITY", "overflow refuses")
	assert_equal(_authority.packed_memory_bytes(), 69 + 60, "all cache/scratch packed columns counted")
	assert_true(_owner.is_bound_sources(_sources), "exact actual source reader")
	assert_false(_owner.is_bound_sources(Owner.Sources.new()), "foreign reader cannot alias numeric world identity")
	assert_equal(Authority.cold_packed_peak_bytes(64, 8, 128), 16000, "all accepted cold paths bounded")
	assert_equal(Authority.cold_packed_peak_bytes(65, 8, 64), -1, "capacity relation checked")
	assert_equal(Authority.cold_packed_peak_bytes(1, 1, 9223372036854775807), -1, "no overflow in estimator")


func test_cold_reservation_refuses_before_snapshot_or_plan_allocation() -> void:
	"""Missing or revoked admission cannot construct even the first complete cold survey."""
	var observed: ObservedSpace = _owner as ObservedSpace
	var snapshots: int = observed.snapshot_reads
	var plans: int = _bindings.cold_reads
	var before: PackedByteArray = _owner.state_bytes()
	var base: Authority.Bindings = Authority.Bindings.new()
	assert_equal(base.begin_cold_operation(_owner, _site, Contract.OP_BRACE, Contract.STAGE_ADMIT), 0,
		"an unbound provider grants no cold storage")
	_bindings.cold_denied = true
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"SPACE_COLD_RESERVATION_REFUSED", "reserve before allocating")
	_bindings.cold_denied = false
	_bindings.cold_attestation = &"SYNTHETIC_COLD_REVOKED"
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		_bindings.cold_attestation, "an issued token still requires exact live attestation")
	assert_equal(observed.snapshot_reads, snapshots, "no full snapshot builder call")
	assert_equal(_bindings.cold_reads, plans, "no plan builder call")
	assert_equal(_owner.state_bytes(), before, "live state is unchanged")
	_assert_cold_released()


func test_cold_proof_only_and_qualification_refusals_release_after_last_copy() -> void:
	"""ADMIT and a rejected qualification hold the reservation until original survey/plan release."""
	var opened: int = _bindings.cold_opened
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"", "actual exact survey accepts the synthetic qualified approach")
	_assert_cold_released()
	_bindings.refusal = &"SYNTHETIC_COLD_PROFILE_REFUSED"
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		_bindings.refusal, "late qualification refusal releases the same lease")
	assert_equal(_bindings.cold_opened, opened + 2, "each cold attempt owns one reservation")
	_assert_cold_released()


func test_cold_refresh_reserves_before_copy_and_work_never_acquires() -> void:
	"""Funded proof replacement is a cold operation; productive Work stays allocation-free."""
	var job: int = _start(Contract.OP_BRACE)
	var snapshots: int = (_owner as ObservedSpace).snapshot_reads
	var opened: int = _bindings.cold_opened
	_bindings.cold_denied = true
	assert_equal(_authority.refresh_static_proof(_site), &"SPACE_COLD_RESERVATION_REFUSED", "refresh needs admission")
	assert_equal((_owner as ObservedSpace).snapshot_reads, snapshots, "denied refresh never copies geometry")
	assert_true(_work.tick_solo(job).ok, "existing exact proof continues to permit actual work")
	assert_equal(_bindings.cold_opened, opened, "productive tick does not acquire cold memory")
	_bindings.cold_denied = false
	assert_equal(_authority.refresh_static_proof(_site), &"", "fresh admitted refresh succeeds")
	assert_equal(_bindings.cold_opened, opened + 1, "only explicit refresh acquired memory")
	_assert_cold_released()


func test_actual_work_cycle_changes_only_the_paid_cube_and_keeps_room_claim() -> void:
	"""Real paid work creates unfinished then finished space; adjoining solid and Room claims survive."""
	var before: PackedByteArray = _owner.state_bytes()
	_complete(Contract.OP_BRACE)
	assert_equal(_owner.state_bytes(), before, "synthetic no-op support binding changes no geometry")
	_complete(Contract.OP_CUT)
	assert_equal(_target_role(), Space.UNFINISHED, "actual cut output and unfinished cube publish together")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 2000, "one actual cube of output")
	_complete(Contract.OP_FINISH)
	assert_equal(_target_role(), Space.SUPPORTED_VOID, "only actual completed finish opens supported space")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_into(image), &"", "ordinary full survey")
	assert_true(image.volumes.role.has(Space.OBSTACLE), "long-lived actual Room claim remains")
	assert_true(image.volumes.role.has(Space.DRY_SOLID), "outside slab remains solid")
	assert_false(image.volumes.role.has(Space.UNFINISHED), "target finishes exactly once")


func test_direct_publication_and_failed_companion_preserve_geometry_and_payment() -> void:
	"""A public callback or refused candidate cannot bypass the physical owner's committed window."""
	var job: int = _open(Contract.OP_BRACE)
	_deliver(Contract.OP_BRACE, job)
	assert_true(_sites.bind_worker(_site).ok, "actual worker binds")
	var before: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room), &"", "prepared only")
	_authority.publish_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room)
	assert_true(_owner.has_prepared(), "unattested direct publication does nothing")
	_authority.discard_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room)
	assert_equal(_owner.state_bytes(), before, "discard retains byte-exact live geometry")
	assert_equal(_inventory.state_bytes(), goods, "preparation spent no real goods")
	_bindings.fail_preparation = true
	assert_false(_sites.begin_phase_work(_site, 0).ok, "missing companion cannot begin paid work")
	assert_equal(_owner.state_bytes(), before, "failed prepare atomic")
	assert_equal(_inventory.state_bytes(), goods, "failed preparation consumed no inputs")
	_bindings.fail_preparation = false
	assert_true(_sites.begin_phase_work(_site, 0).ok, "fresh exact retry succeeds")


func test_actual_cut_stages_floor_support_then_sealed_companions_and_rolls_back_both_failures() -> void:
	"""Explicit synthetic entry geometry publishes with real paid output, never on a refused retry."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	_finish_work(job)
	_bindings.stage_entry_geometry = true
	var geometry: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	var physical: PackedByteArray = _sites.state_bytes()
	_bindings.physical_refusal = &"SYNTHETIC_SUPPORT_REFUSED"
	assert_false(_sites.settle_phase(_site).ok, "pre-seal support refusal")
	assert_false(_owner.has_prepared(), "partial support geometry discarded")
	assert_equal(_owner.state_bytes(), geometry, "first refusal preserves geometry bytes")
	assert_equal(_inventory.state_bytes(), goods, "first refusal creates no earth")
	assert_equal(_sites.state_bytes(), physical, "paid work/history retained for retry")
	assert_false(_owner.is_live_region(_bindings.staged_floor), "floor remains unpublished")
	_bindings.physical_refusal = &""
	_bindings.fail_preparation = true
	assert_false(_sites.settle_phase(_site).ok, "post-seal companion refusal")
	assert_true(_bindings.saw_sealed_candidate, "companion reads actual sealed future geometry")
	assert_equal(_owner.state_bytes(), geometry, "second refusal preserves geometry bytes")
	assert_equal(_inventory.state_bytes(), goods, "second refusal creates no earth")
	assert_equal(_sites.state_bytes(), physical, "no repeat charge or lost completed work")
	_bindings.fail_preparation = false
	assert_true(_sites.settle_phase(_site).ok, "same actual funded work can publish once")
	assert_true(_owner.is_live_region(_bindings.staged_floor), "floor published atomically")
	assert_true(_owner.is_live_region(_bindings.staged_support), "support published atomically")
	assert_equal(_target_role(), Space.UNFINISHED, "cut is still unavailable for travel")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 2000, "one paid cube output")


func test_physical_geometry_hook_refuses_unbound_foreign_token_and_wrong_room() -> void:
	"""Additional floor/support editing cannot borrow a coincident token or another physical room."""
	var plan: Space.Plan = Space.Plan.new()
	var base: Authority.Bindings = Authority.Bindings.new()
	assert_equal(base.stage_physical_geometry(_owner, 1, _site, Contract.OP_BRACE,
		Contract.STAGE_START, _room, plan), &"SPACE_PHYSICAL_GEOMETRY_UNBOUND", "base never assumes no edits")
	var token: int = _owner.begin_stage(_owner.revision()).token
	var foreign: Owner = Owner.new(_sources)
	assert_equal(_bindings.stage_physical_geometry(foreign, token, _site, Contract.OP_BRACE,
		Contract.STAGE_START, _room, plan), &"SYNTHETIC_PHYSICAL_OWNER", "actual geometry owner")
	assert_equal(_bindings.stage_physical_geometry(_owner, token + 1, _site, Contract.OP_BRACE,
		Contract.STAGE_START, _room, plan), &"SPACE_TRANSACTION_STALE", "actual editable token")
	assert_equal(_bindings.stage_physical_geometry(_owner, token, _site, Contract.OP_BRACE,
		Contract.STAGE_START, _world, plan), &"SYNTHETIC_PHYSICAL_OWNER", "actual Room identity")
	assert_true(_owner.abort(token), "no live geometry changed")


func test_productive_work_uses_static_proof_and_fresh_dynamic_checks() -> void:
	"""Actual worker ticks do not re-copy or scan the full geometry, while new posture/load blocks work."""
	var job: int = _start(Contract.OP_BRACE)
	var cold: int = _bindings.cold_reads
	var dynamic: int = _bindings.worker_reads
	for tick: int in 5:
		assert_true(_work.tick_solo(job).ok, "actual productive tick %d" % tick)
	assert_equal(_bindings.cold_reads, cold, "no cold proof rebuild inside productive tick")
	assert_equal(_bindings.worker_reads, dynamic + 5, "fresh actual dynamic proof every tick")
	var before: int = _jobs.remaining_mwu_of(job).value
	_bindings.dynamic_refusal = &"SYNTHETIC_CHANGED_POSTURE_OR_LOAD"
	assert_false(_work.tick_solo(job).ok, "changed worker state refuses")
	assert_equal(_jobs.remaining_mwu_of(job).value, before, "refusal advances no work")
	_bindings.dynamic_refusal = &""
	_bindings.qualified_revision += 1
	assert_false(_work.tick_solo(job).ok, "changed static qualification refuses cached proof")
	assert_equal(_bindings.cold_reads, cold, "stale proof never rebuilds from WORK")
	assert_equal(_authority.refresh_static_proof(_site), &"", "separate cold refresh requalifies funded phase")
	assert_equal(_bindings.last_survey_stage, Contract.STAGE_WORK, "funded refresh surveys the exact WORK stage")
	assert_true(_work.tick_solo(job).ok, "funded work resumes without repayment")


func test_backfill_and_recut_change_actual_space_without_duplicate_earth() -> void:
	"""Real closure restores solid and keeps permanent geology; a later cut reclaims its actual input."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	_complete(Contract.OP_FINISH)
	_complete(Contract.OP_BACKFILL_CLOSE)
	assert_equal(_target_role(), Space.DRY_SOLID, "paid closure publishes actual solid")
	assert_equal(_phase(), Sites.BACKFILLED, "physical phase agrees with spatial truth")
	assert_equal(_sites.embedded_earth_milli(_site), 2000, "actual input embedded once")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "no loose duplicate")
	assert_equal(_claim_count(Owner.CLAIM_CONSTRUCTION), 0, "only completed closure's phase marker retires")
	assert_equal(_claim_count(Owner.CLAIM_ROOM), 1, "accepted Room footprint survives")
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	assert_equal(_target_role(), Space.UNFINISHED, "recut opens only the paid target")
	assert_equal(_sites.embedded_earth_milli(_site), 0, "reclaimed input withdrawn")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one historical source event")
	assert_equal(_inventory.lot_provenance(_find_lot(_output, &"excavated_earth")),
		Catalog.PROVENANCE_BACKFILL_RECLAIM, "output retains actual provenance")


func test_unopened_support_closure_never_publishes_a_void_or_earth() -> void:
	"""The paid never-opened exception retires support and its phase claim while dirt stays solid."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_UNOPENED_SUPPORT_CLOSE)
	assert_equal(_target_role(), Space.DRY_SOLID, "no cosmetic or elapsed-work opening")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "no dirt was cut")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 125, "actual one-time support salvage")
	assert_equal(_claim_count(Owner.CLAIM_CONSTRUCTION), 0, "phase claim removed")
	assert_equal(_claim_count(Owner.CLAIM_ROOM), 1, "Room footprint remains")


func test_material_free_cut_cancellation_preserves_geometry_and_rebinds_progress() -> void:
	"""No refund container or contact is needed when actual cutting has produced no returned goods."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	for tick: int in 10:
		assert_true(_work.tick_solo(job).ok, "partial paid cut")
	var before: PackedByteArray = _owner.state_bytes()
	assert_true(_sites.cancel_phase(_site, NULL_REF).ok, "no material refund storage needed")
	assert_equal(_owner.state_bytes(), before, "unfinished labor never changed spatial geometry")
	assert_equal(_authority.refresh_static_proof(_site), &"SPACE_PHASE_STALE", "retired phase cannot reuse evidence")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no early earth")
	job = _start(Contract.OP_CUT)
	assert_equal(_jobs.remaining_mwu_of(job).value, 3200, "actual retained labor continues")
	_finish_work(job)
	assert_true(_sites.settle_phase(_site).ok, "resumed cut commits once")
	assert_equal(_target_role(), Space.UNFINISHED, "space and output publish together")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one source event")


func test_cancelled_closure_releases_only_its_marker_and_retains_actual_void() -> void:
	"""A refunded uncommitted closure cannot pretend earth is embedded or reclaim its support."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	_complete(Contract.OP_FINISH)
	var job: int = _start(Contract.OP_BACKFILL_CLOSE)
	assert_equal(_claim_count(Owner.CLAIM_CONSTRUCTION), 1, "closing entry reserved by actual phase")
	assert_true(_work.tick_solo(job).ok, "one actual closure tick")
	assert_true(_sites.cancel_phase(_site, _store).ok, "real WIP refund")
	assert_equal(_target_role(), Space.SUPPORTED_VOID, "uncommitted backfill did not replace usable matter")
	assert_equal(_claim_count(Owner.CLAIM_CONSTRUCTION), 0, "cancelled exact phase marker removed")
	assert_equal(_claim_count(Owner.CLAIM_ROOM), 1, "permanent Room marker remains")
	assert_equal(_sites.embedded_earth_milli(_site), 0, "no phantom embedded inventory")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 1600, "actual partial refund")
	assert_equal(_sites.earth_conservation_refusal(), &"", "refund and loss conservation")


func test_blocked_output_does_not_publish_geometry_or_consume_work_twice() -> void:
	"""A completed cut with a refused actual output contact retains both spatial and physical state."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	_finish_work(job)
	var geometry: PackedByteArray = _owner.state_bytes()
	var physical: PackedByteArray = _sites.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	var labor: PackedByteArray = _work.state_bytes()
	_bindings.output_blocked = true
	assert_false(_sites.settle_phase(_site).ok, "actual contact refused")
	assert_equal(_owner.state_bytes(), geometry, "geometry unchanged")
	assert_equal(_sites.state_bytes(), physical, "physical history unchanged")
	assert_equal(_inventory.state_bytes(), goods, "input/output transaction unchanged")
	assert_equal(_work.state_bytes(), labor, "no extra labor or wear")
	assert_false(_owner.has_prepared(), "refusal discarded transient candidate")
	_bindings.output_blocked = false
	assert_true(_sites.settle_phase(_site).ok, "fresh actual retry succeeds")
	assert_equal(_target_role(), Space.UNFINISHED, "one actual spatial cut")
	assert_false(_sites.settle_phase(_site).ok, "publication cannot repeat")


func test_static_refresh_is_read_only_and_cannot_fund_or_publish_a_phase() -> void:
	"""A cold proof refresh replaces derived evidence only after exact paid-phase prerequisites hold."""
	assert_equal(_authority.refresh_static_proof(_site), &"SPACE_PHASE_STALE", "no active phase")
	var job: int = _open(Contract.OP_BRACE)
	_deliver(Contract.OP_BRACE, job)
	assert_equal(_authority.refresh_static_proof(_site), &"SPACE_PHASE_NOT_FUNDED", "delivery is not payment")
	assert_true(_sites.bind_worker(_site).ok, "actual worker")
	assert_true(_sites.begin_phase_work(_site, 0).ok, "actual payment and start")
	var geometry: PackedByteArray = _owner.state_bytes()
	var physical: PackedByteArray = _sites.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	assert_equal(_authority.invalidate_proofs(), &"", "completed load boundary clears derived evidence")
	assert_false(_work.tick_solo(job).ok, "missing proof refuses, no automatic cold scan")
	_bindings.drift_during_qualification = true
	assert_equal(_authority.refresh_static_proof(_site), &"SPACE_GEOMETRY_STALE", "changing evidence cannot replace proof")
	_bindings.drift_during_qualification = false
	assert_equal(_authority.refresh_static_proof(_site), &"", "fresh bounded proof rebuild")
	assert_equal(_owner.state_bytes(), geometry, "no spatial publication")
	assert_equal(_sites.state_bytes(), physical, "no physical state or work reset")
	assert_equal(_inventory.state_bytes(), goods, "no repayment or output")
	assert_true(_work.tick_solo(job).ok, "current proof permits actual worker validation")


func test_failed_refresh_retains_the_prior_proof_and_earned_labor() -> void:
	"""A refused cold replacement cannot erase the usable old row or silently perform a worker tick."""
	var job: int = _start(Contract.OP_BRACE)
	assert_true(_work.tick_solo(job).ok, "one actual tick before replacement")
	var i32: PackedInt32Array = _authority._proof_i32.duplicate()
	var i64: PackedInt64Array = _authority._proof_i64.duplicate()
	var remaining: int = _jobs.remaining_mwu_of(job).value
	_bindings.refusal = &"SYNTHETIC_PROFILE_TEMPORARILY_UNAVAILABLE"
	assert_equal(_authority.refresh_static_proof(_site), _bindings.refusal, "new candidate refused")
	assert_equal(_authority._proof_i32, i32, "exact old identity row survives")
	assert_equal(_authority._proof_i64, i64, "exact old revisions survive")
	assert_equal(_jobs.remaining_mwu_of(job).value, remaining, "cold refresh spent no work")
	_bindings.refusal = &""
	assert_true(_work.tick_solo(job).ok, "unchanged actual static proof remains usable")


func test_interior_unknown_gap_cannot_be_authorized_by_corner_coverage() -> void:
	"""All cube corners may look solid while an interior unsurveyed cavity still refuses a paid cut."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_remove(token, _first_matter(Space.DRY_SOLID)), &"", "remove broad solid survey")
	for box: Array in [[0, 0, 0, 400, 1024, 1024], [600, 0, 0, 2048, 1024, 1024],
			[400, 0, 0, 600, 400, 1024], [400, 600, 0, 600, 1024, 1024],
			[400, 400, 0, 600, 600, 400], [400, 400, 600, 600, 600, 1024]]:
		var typed_box: Array[int] = []
		typed_box.assign(box)
		_add(token, typed_box, Space.DRY_SOLID, _world)
	assert_equal(_owner.seal(token), &"", "known disjoint surrounding solid")
	_owner.publish(token)
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(_sites.open_phase(_site, Contract.OP_BRACE).error, &"SPACE_PHASE_TARGET_UNKNOWN", "interior hole refuses")
	assert_equal(_sites.state_bytes(), before, "no phase or material entitlement allocated")


func test_same_room_actual_obstacle_is_not_a_claim_exemption() -> void:
	"""Scoping the accepted Room footprint cannot hide its actual furnishings or another solid obstruction."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	_add(token, [-800, 0, 300, -600, 700, 500], Space.OBSTACLE, _room)
	assert_equal(_owner.seal(token), &"", "actual room-owned obstacle records")
	_owner.publish(token)
	assert_equal(_sites.open_phase(_site, Contract.OP_BRACE).error,
		&"SPACE_WORK_CONTACT_OBSTRUCTED", "actual obstacle remains in scoped approach")
	assert_equal(_claim_count(Owner.CLAIM_ROOM), 1, "only typed accepted marker can be scoped")


func test_retained_unfinished_approach_never_becomes_supported_for_finishing() -> void:
	"""The target may be retained unfinished, but the worker still needs complete existing supported space."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_remove(token, _first_matter(Space.SUPPORTED_VOID)), &"", "remove supported approach")
	_add(token, [-1024, 0, 0, 0, 1024, 1024], Space.UNFINISHED, _room)
	assert_equal(_owner.seal(token), &"", "actual unfinished approach state")
	_owner.publish(token)
	assert_equal(_sites.open_phase(_site, Contract.OP_FINISH).error, &"SPACE_WORK_APPROACH_UNFINISHED", "no fake finish route")
	assert_equal(_target_role(), Space.UNFINISHED, "target is unchanged by refusal")


func test_missing_floor_generation_blocks_cut_output_until_exact_retry() -> void:
	"""A paid completed cut cannot attach its result to a stale or guessed floor, nor lose earned work."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	_finish_work(job)
	var before: PackedByteArray = _owner.state_bytes()
	_bindings.floor_ref = Vector2i(_floor.x, _floor.y + 1)
	assert_equal(_sites.settle_phase(_site).error, &"SPACE_SECTION_MISSING", "reused floor generation refuses")
	assert_equal(_owner.state_bytes(), before, "no partial matter replacement")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no output before coherent geometry")
	_bindings.floor_ref = _floor
	assert_true(_sites.settle_phase(_site).ok, "actual floor revalidated on fresh candidate")
	assert_equal(_target_role(), Space.UNFINISHED, "earned cut publishes once")


func test_full_proof_capacity_refuses_before_payment_then_retries_freed_row() -> void:
	"""Two real active phases cannot overrun one admitted cache row or share a proof by Room identity."""
	_start(Contract.OP_BRACE)
	var second: Vector2i = _sites.claim_quantum(Vector3i(0, 0, 1024), _room).ref
	var worker: int = _worker()
	var job: int = _open(Contract.OP_BRACE, second, worker)
	_deliver(Contract.OP_BRACE, job, second)
	assert_true(_sites.bind_worker(second).ok, "second actual assigned worker")
	var goods: PackedByteArray = _inventory.state_bytes()
	var geometry: PackedByteArray = _owner.state_bytes()
	assert_equal(_sites.begin_phase_work(second, 0).error, &"SPACE_PROOF_CAPACITY", "second proof refuses before payment")
	assert_equal(_inventory.state_bytes(), goods, "second inputs remain actual delivered claims")
	assert_equal(_owner.state_bytes(), geometry, "no geometry or claim publication on capacity failure")
	assert_false(_owner.has_prepared(), "failed reserve leaves no pending stage")
	assert_true(_sites.cancel_phase(_site, _store).ok, "first actual cancellation retires its exact cache row")
	assert_true(_sites.begin_phase_work(second, 0).ok, "second phase retries freshly admitted free row")
	assert_true(_work.tick_solo(job).ok, "new full Site/Job proof authorizes only the second actual worker")


func test_wrong_identity_or_stage_cannot_discard_another_candidate() -> void:
	"""A different physical key, reused Room or operation cannot release another transaction's preparation."""
	var job: int = _open(Contract.OP_BRACE)
	_deliver(Contract.OP_BRACE, job)
	assert_true(_sites.bind_worker(_site).ok, "actual assigned worker")
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room), &"", "prepare exact")
	var cold_token: int = _bindings.cold_active
	assert_true(cold_token > 0, "preparation retains its actual cold reservation")
	_authority.discard_transition(Vector3i(0, 0, 1024), Contract.OP_BRACE, Contract.STAGE_START, _room)
	_authority.discard_transition(ORIGIN, Contract.OP_CUT, Contract.STAGE_START, _room)
	_authority.discard_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, Vector2i(_room.x, _room.y + 1))
	assert_true(_owner.has_prepared(), "wrong identities preserve pending candidate")
	assert_equal(_bindings.cold_active, cold_token, "wrong discard cannot release another lease")
	assert_equal(_authority.invalidate_proofs(), &"SPACE_TRANSITION_BUSY", "load cannot overlap a physical transition")
	_authority.discard_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room)
	assert_false(_owner.has_prepared(), "exact discard releases preparation")
	_assert_cold_released()
	assert_equal(_authority.worker_refusal(ORIGIN, Contract.OP_BRACE, _room, _jobs.ref_of(job),
		Vector2i(_residents.ref_of(_resident).x, _residents.ref_of(_resident).y + 1)),
		&"SPACE_WORKER_IDENTITY", "stale resident generation cannot qualify")
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, 999, _room), &"SPACE_STAGE_INVALID", "unknown stage")


func test_direct_start_and_commit_require_the_actual_paid_construction_phase() -> void:
	"""Plausible operation refs cannot prepare paid publication while materials or accepted labor are missing."""
	var job: int = _open(Contract.OP_BRACE)
	var before: PackedByteArray = _owner.state_bytes()
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room),
		&"SPACE_PHASE_NOT_READY", "awaiting materials is not ready")
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_COMMIT, _room),
		&"SPACE_WORK_INCOMPLETE", "unfunded phase cannot commit")
	assert_false(_owner.has_prepared(), "refused stage allocated no spatial candidate")
	assert_equal(_owner.state_bytes(), before, "unready calls change no geometry")
	_deliver(Contract.OP_BRACE, job)
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_COMMIT, _room),
		&"SPACE_WORK_INCOMPLETE", "delivered inputs do not replace accepted labor")
	assert_true(_sites.bind_worker(_site).ok, "actual worker and tool bind")
	assert_true(_sites.begin_phase_work(_site, 0).ok, "actual ready phase pays and starts")
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, _room),
		&"SPACE_PHASE_NOT_READY", "funded working phase cannot start twice")
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_COMMIT, _room),
		&"SPACE_WORK_INCOMPLETE", "positive remaining labor blocks completion")
	_finish_work(job)
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_COMMIT, _room), &"", "actual done phase prepares")
	_authority.discard_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_COMMIT, _room)
	assert_true(_sites.settle_phase(_site).ok, "fresh attested physical commit remains required")


func test_repeated_productive_proofs_do_not_scan_or_mutate_the_spatial_owner() -> void:
	"""Measure 256 proof pairs for one real worker/site; this is not a 256-distinct-worker qualification."""
	var job: int = _start(Contract.OP_BRACE)
	var cold: int = _bindings.cold_reads
	var before: PackedByteArray = _owner.state_bytes()
	var started: int = Time.get_ticks_usec()
	for index: int in 256:
		assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_WORK, _room), &"", "static actual proof")
		assert_equal(_authority.worker_refusal(ORIGIN, Contract.OP_BRACE, _room, _jobs.ref_of(job),
			_residents.ref_of(_resident)), &"", "fresh dynamic actual assignment")
	print("UG21_SINGLE_SITE_PROOF_BATCH: 256 pairs, %d usec; synthetic dynamic profile; no Work ticks" % (Time.get_ticks_usec() - started))
	assert_equal(_bindings.cold_reads, cold, "no survey/plan copies inside repeated productive checks")
	assert_equal(_owner.state_bytes(), before, "read-only proof path leaves authoritative geometry byte exact")


func _first_matter(role: int) -> Vector2i:
	"""Obtain an internal generation-checked edit handle without guessing its allocator row."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_owner.overlapping_regions_into(PackedInt32Array([-4096, -4096, -4096, 4096, 4096, 4096]),
		handles), &"", "all finite actual regions")
	var packet: Owner.Region = Owner.Region.new()
	for at: int in range(0, handles.size(), 2):
		var handle: Vector2i = Vector2i(handles[at], handles[at + 1])
		assert_equal(_owner.region_into(handle, packet), &"", "real edit handle")
		if packet.role == role and packet.claim_kind == Owner.CLAIM_NONE:
			return handle
	return NULL_REF


func _claim_count(kind: int) -> int:
	"""Read actual typed claim markers, including the ordinary full-view closing obstacle."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_owner.overlapping_regions_into(PackedInt32Array([-4096, -4096, -4096, 4096, 4096, 4096]),
		handles), &"", "bounded actual region handles")
	var packet: Owner.Region = Owner.Region.new()
	var count: int = 0
	for at: int in range(0, handles.size(), 2):
		assert_equal(_owner.region_into(Vector2i(handles[at], handles[at + 1]), packet), &"", "live internal region")
		count += int(packet.claim_kind == kind)
	return count


func _worker(stage: int = Residents.LIFE_STAGE_ADULT) -> int:
	"""Create an eligible base-rate resident and equip an actual durable general tool."""
	var resident: int = _residents.spawn_with_stage(&"mouse", stage).value
	assert_true(_priorities.spawn(resident).ok, "worker priorities spawn")
	assert_true(_schedule.spawn(resident, _schedule.default_template_id().value).ok, "schedule spawns")
	assert_true(_schedule.resolve(resident, 8, false).ok, "real work-hour eligibility resolves")
	assert_true(_jobs.spawn_agent(resident).ok, "actual JobAgent spawns")
	for need: int in Needs.NEED_COUNT:
		var present: int = _residents.needs().need_of(resident, need).value
		assert_true(_residents.needs().apply_need_event(resident, need, 5000 - present).ok, "base-rate mood")
	var tool: Vector2i = _lot(&"tool", Gear.GEAR_LOT_QUANTITY_MILLI)
	assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool creates")
	assert_true(_gear.equip(tool, _residents.ref_of(resident)).ok, "actual tool equips")
	_tools.append(tool)
	return resident


func _lot(key: StringName, quantity: int) -> Vector2i:
	"""Create fixture starting materials; cut earth is only ever produced by actual Sites."""
	var made: Inventory.OpResult = _inventory.create_lot(_store, _items.compiled_id(key),
		quantity, 1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(made.ok, "actual material lot creates: %s" % made.error)
	return made.ref


func _open(operation: int, site: Vector2i = Vector2i(-1, 0), worker: int = -1) -> int:
	"""Open a real paid phase and Job, bind actual worker/tool, but do not begin productive work."""
	if site == NULL_REF:
		site = _site
	if worker == -1:
		worker = _resident
	var opened: Construction.OpResult = _sites.open_phase(site, operation)
	assert_true(opened.ok, "physical phase opens: %s" % opened.error)
	_construction.remaining_mwu_into(opened.ref, _math)
	var job: int = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, 0).value
	assert_true(_jobs.set_requester(job, opened.ref).ok, "Job names actual Construction generation")
	assert_true(_jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "equipment requirement is explicit")
	assert_true(_sites.bind_job(site, _jobs.ref_of(job)).ok, "phase binds actual Job")
	assert_true(_sites.bind_material_container(site, _store).ok, "delivered location binds")
	if operation == Contract.OP_CUT or operation == Contract.OP_BACKFILL_CLOSE \
			or operation == Contract.OP_UNOPENED_SUPPORT_CLOSE:
		assert_true(_sites.bind_output(site, _output).ok, "actual finite output binds")
	assert_true(_jobs.assign_worker(worker, job).ok, "actual worker assigns")
	assert_true(_work.claim_tool_for_work(worker, _tools[worker]).ok, "actual equipped tool claims")
	return job


func _deliver(operation: int, job: int, site: Vector2i = Vector2i(-1, 0)) -> void:
	"""Use real material claims; earth input is physically moved from prior actual cut output."""
	if site == NULL_REF:
		site = _site
	for line: int in Contract.input_count(operation):
		var key: StringName = Contract.input_key(operation, line)
		var quantity: int = Contract.input_milli(operation, line)
		var lot: Vector2i = _find_lot(_output, key) if key == &"excavated_earth" else _lot(key, quantity)
		if key == &"excavated_earth":
			assert_true(_inventory.move_lot(lot, _store).ok, "actual previously cut earth hauled to input")
		var batch: PackedInt64Array = PackedInt64Array([lot.x, lot.y,
			Reservations.PURPOSE_EXCAVATION_INPUT, quantity, 100000])
		assert_true(_pool.claim_batch(_jobs.ref_of(job), batch, 1, _inventory).ok, "real Job claims input")
	if Contract.input_count(operation) > 0:
		var recorded: Construction.OpResult = _sites.record_deliveries(site)
		assert_true(recorded.ok, "Construction delivery derives from actual claims: %s" % recorded.error)


func _find_lot(container: Vector2i, key: StringName) -> Vector2i:
	"""Read actual loose stock without creating a substitute earth source."""
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != NULL_REF and _inventory.lot_item_id(lot) != _items.compiled_id(key):
		lot = _inventory.container_next_lot(lot)
	return lot


func _start(operation: int, site: Vector2i = Vector2i(-1, 0), worker: int = -1) -> int:
	"""Fund a phase using real claims and bind its worker before the first actual Work tick."""
	if site == NULL_REF:
		site = _site
	var job: int = _open(operation, site, worker)
	_deliver(operation, job, site)
	assert_true(_sites.bind_worker(site).ok, "physical face binds actual worker")
	var started: Construction.OpResult = _sites.begin_phase_work(site, 0)
	assert_true(started.ok, "real paid work begins: %s" % started.error)
	return job


func _finish_work(job: int) -> int:
	"""Drive actual integer Work ticks; there is no fabricated progress or timer completion."""
	var ticks: int = 0
	while _jobs.remaining_mwu_into(job, _math) and _math.value > 0 and ticks < 1000:
		var worked: Work.TickResult = _work.tick_solo(job)
		assert_true(worked.ok, "actual Work contribution: %s" % worked.error)
		if not worked.ok:
			break
		ticks += 1
	return ticks


func _complete(operation: int) -> int:
	"""Commit actual physical output only after real worker contributions finish the phase."""
	var job: int = _start(operation)
	var ticks: int = _finish_work(job)
	var settled: Construction.OpResult = _sites.settle_phase(_site)
	assert_true(settled.ok, "physical output/support commits: %s" % settled.error)
	assert_true(_inventory.audit().ok, "actual Inventory audit passes")
	assert_true(_pool.audit(_inventory).ok, "actual claim audit passes")
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual earth physical ledger balances")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual wood/stone WIP-support-salvage-loss accounts balance")
	return ticks


func _phase() -> int:
	"""Read physical phase through the public owner API."""
	assert_true(_sites.phase_into(_site, _math), "physical phase reads")
	return _math.value


func _target_role() -> int:
	"""Inspect actual authoritative target coverage after publication, not presentation or elapsed time."""
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(image, _sites, _site), &"", "exact survey")
	var target: PackedInt32Array = PackedInt32Array([0, 0, 0, 1024, 1024, 1024])
	for row: int in image.volumes.role.size():
		if image.volumes.role[row] in [Space.DRY_SOLID, Space.UNFINISHED, Space.SUPPORTED_VOID] \
				and Space.contains_box(image.volumes.box_at(row), target):
			return image.volumes.role[row]
	return -1


func test_phase_plan_allowance_and_shape_are_checked_before_survey() -> void:
	"""Plan memory and table integrity must be proven before the binding surveys its contact bounds."""
	var observed: ObservedSpace = _owner as ObservedSpace
	var snapshots: int = observed.snapshot_reads
	var plans: int = _bindings.cold_reads
	_bindings.plan_limit = 0
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"SPACE_PHASE_PLAN_CAPACITY", "zero allowance refuses before any phase plan")
	assert_equal(_bindings.cold_reads, plans, "no plan allocation without admission")
	_bindings.plan_limit = 1
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"SYNTHETIC_PLAN_CAPACITY", "provider refuses before exceeding exact allowance")
	_bindings.plan_limit = 32
	_bindings.malformed_plan = true
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"SPACE_PHASE_PLAN_FORMAT", "truncated table cannot determine a query")
	assert_equal(observed.snapshot_reads, snapshots, "no snapshot on any early refusal")
	_assert_cold_released()


func test_phase_plan_lease_expiry_and_survey_refusal_release_all_scratch() -> void:
	"""Provider success never overrides the exact shared lease or a refused world survey."""
	var observed: ObservedSpace = _owner as ObservedSpace
	var snapshots: int = observed.snapshot_reads
	_bindings.expire_after_plan = true
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		&"SYNTHETIC_COLD_EXPIRED", "recheck immediately after plan callback")
	assert_equal(observed.snapshot_reads, snapshots, "expired plan does not start a survey")
	_bindings.expire_after_plan = false
	_bindings.cold_attestation = &""
	_bindings.snapshot_refusal = &"SYNTHETIC_WORLD_SURVEY_REFUSED"
	assert_equal(_authority.operation_refusal(ORIGIN, Contract.OP_BRACE, Contract.STAGE_ADMIT, _room),
		_bindings.snapshot_refusal, "composed survey refusal is final")
	assert_true(_bindings.saw_checked_plan, "the actual prepared plan precedes its bounds-based survey")
	_assert_cold_released()


func _set_finish_claims(boxes: Array[PackedInt32Array]) -> void:
	"""Replace only exact Room reservation rows; paid physical matter and floor identity stay actual."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_owner.overlapping_regions_into(_owner.domain_copy()._bounds, handles), &"", "actual live claim survey")
	var token: int = _owner.begin_stage(_owner.revision()).token
	var region: Owner.Region = Owner.Region.new()
	region.box.resize(6)
	var index: int = 0
	while index < handles.size():
		var handle: Vector2i = Vector2i(handles[index], handles[index + 1])
		assert_equal(_owner.region_into_reused(handle, region), &"", "actual full row")
		if region.owner == _room and region.claim_kind == Owner.CLAIM_ROOM:
			assert_equal(_owner.stage_remove(token, handle), &"", "replace accepted synthetic test plan")
		index += 2
	for box: PackedInt32Array in boxes:
		region.box = box.duplicate()
		region.owner = _room
		region.role = Space.OBSTACLE
		region.level = 1
		region.section = _floor
		region.claim_kind = Owner.CLAIM_ROOM
		region.claim_ref = _room
		assert_true(_owner.stage_add(token, region).ok(), "new exact fine claim")
	assert_equal(_owner.seal(token), &"", "actual source and shape validation")
	_owner.publish(token)


func _fine_finish_claims() -> Array[PackedInt32Array]:
	"""The concave L uses256u paint while physical excavation remains the complete1024u cube."""
	return [PackedInt32Array([0, 0, 0, 256, 1024, 1024]), PackedInt32Array([256, 0, 0, 1024, 1024, 256])]


func _prepare_fine_finish() -> int:
	"""Real bracing/cutting and actual work earn the finishing output before injecting mask failures."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	_set_finish_claims(_fine_finish_claims())
	var job: int = _start(Contract.OP_FINISH)
	_finish_work(job)
	return job


func _assert_finished_partition(expected_finished: int) -> void:
	"""Count exact disjoint actual volume, never corner samples or a metadata bounding rectangle."""
	var survey: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(survey, _sites, _site), &"", "actual published physical survey")
	var cube: PackedInt32Array = PackedInt32Array([0, 0, 0, 1024, 1024, 1024])
	var boxes: Array[PackedInt32Array] = []
	var finished: int = 0
	var unfinished: int = 0
	for row: int in survey.volumes.role.size():
		var role: int = survey.volumes.role[row]
		if role not in [Space.SUPPORTED_VOID, Space.UNFINISHED]:
			continue
		var box: PackedInt32Array = Space.intersection(survey.volumes.box_at(row), cube)
		if not Space.valid_box(box):
			continue
		for previous: PackedInt32Array in boxes:
			assert_false(Space.overlaps(previous, box), "no overlapping finished/residual prefix")
		boxes.append(box)
		var volume: int = (box[3] - box[0]) * (box[4] - box[1]) * (box[5] - box[2])
		finished += volume if role == Space.SUPPORTED_VOID else 0
		unfinished += volume if role == Space.UNFINISHED else 0
	assert_equal(finished, expected_finished, "only exact painted union becomes usable")
	assert_equal(finished + unfinished, 1024 * 1024 * 1024, "entire paid cube remains accounted")
	assert_equal(_claim_count(Owner.CLAIM_ROOM), 2, "long-lived exact claims remain")


func test_fine_finish_publishes_exact_claim_union_and_retains_paid_outside_cavity() -> void:
	"""Completed real work cannot turn a concave painted room into its rectangular paid excavation envelope."""
	_prepare_fine_finish()
	var earth: int = _inventory.total_live_milli(_items.compiled_id(&"excavated_earth"))
	assert_true(_sites.settle_phase(_site).ok, "actual paid exact-shape finish")
	_assert_finished_partition((256 * 1024 + 768 * 256) * 1024)
	assert_equal(_bindings.mask_row_limit, 64, "scratch uses actual small owner capacity")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), earth, "finish gives no extra cut yield")
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual paid ledger unchanged by shape")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual material receipts balance")
	assert_false(_sites.settle_phase(_site).ok, "actual phase cannot publish twice")


func test_finish_rejects_missing_extra_overlapping_and_outside_masks_before_payment() -> void:
	"""The real provider's output is independently checked against both directions of the exact claim union."""
	_prepare_fine_finish()
	var before: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	var packets: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array([0, 0, 0, 256, 1024, 1024]),
		PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), PackedInt32Array([-1, 0, 0, 1024, 1024, 1024]),
		PackedInt32Array([0, 0, 0, 256, 1024, 1024, 0, 0, 0, 256, 1024, 1024])]
	var errors: Array[StringName] = [&"SPACE_FINISH_MASK_SHAPE", &"SPACE_FINISH_MASK_MISSING",
		&"SPACE_FINISH_MASK_OUTSIDE_CLAIMS", &"SPACE_FINISH_MASK_BOUNDS", &"SPACE_FINISH_MASK_OVERLAP"]
	_bindings.mask_override_enabled = true
	for index: int in packets.size():
		_bindings.mask_override = packets[index]
		assert_equal(_sites.settle_phase(_site).error, errors[index], "independent refusal%d" % index)
		assert_equal(_owner.state_bytes(), before, "no partial geometry")
		assert_equal(_inventory.state_bytes(), goods, "no consumed paid output on refusal")
		assert_false(_owner.has_prepared(), "failed candidate always discarded")
		assert_equal(_bindings.cold_active, 0, "failed operation releases cold scratch")
	_bindings.mask_override_enabled = false
	assert_true(_sites.settle_phase(_site).ok, "same earned work retries with exact real mask")
	_assert_finished_partition((256 * 1024 + 768 * 256) * 1024)


func test_finish_accepts_a_different_disjoint_partition_of_the_same_claim_union() -> void:
	"""Independent proof compares physical unions, so output rows need not mirror claim segmentation."""
	_prepare_fine_finish()
	_bindings.mask_override_enabled = true
	_bindings.mask_override = PackedInt32Array([0, 0, 0, 1024, 1024, 256,
		0, 0, 256, 256, 512, 1024, 0, 512, 256, 256, 1024, 1024])
	assert_true(_sites.settle_phase(_site).ok, "same exact union with different XYZ partition")
	_assert_finished_partition((256 * 1024 + 768 * 256) * 1024)


func test_finish_mask_unbound_and_oversized_output_preserve_real_earned_phase() -> void:
	"""Absent authored mask truth and technical exhaustion never silently finish the whole paid cube."""
	_prepare_fine_finish()
	var before: PackedByteArray = _owner.state_bytes()
	_bindings.mask_refusal = &"SPACE_FINISH_MASK_UNBOUND"
	assert_equal(_sites.settle_phase(_site).error, &"SPACE_FINISH_MASK_UNBOUND", "no generic whole-cube fallback")
	_bindings.mask_refusal = &""
	_bindings.mask_override_enabled = true
	_bindings.mask_override.resize(65 * 6)
	assert_equal(_sites.settle_phase(_site).error, &"SPACE_FINISH_MASK_SHAPE", "real64-row bound checked before scratch banks")
	assert_equal(_owner.state_bytes(), before, "no geometry prefix")
	assert_equal(_bindings.cold_active, 0, "all denied scratch released")
	_bindings.mask_override_enabled = false
	assert_true(_sites.settle_phase(_site).ok, "full phase can retry after technical refusal")


func test_finish_partition_peak_includes_actual_banks_handles_and_original_inputs() -> void:
	"""The real admitted pack fits under the same shared cold arena without erasing smaller capacities."""
	assert_equal(Authority.finish_partition_peak_bytes(6144, 2048, 8192, 1013), 990952, "maximum simultaneous payload")
	assert_equal(Authority.finish_partition_peak_bytes(64, 8, 128, 2), 12048, "small actual arena, not default maximum")
	assert_equal(Authority.finish_partition_peak_bytes(0, 8, 128, 2), -1, "unconfigured")
	assert_equal(Authority.finish_partition_peak_bytes(129, 8, 128, 2), -1, "bad row relation")
	assert_equal(Authority.finish_partition_peak_bytes(64, 8, 128, 9223372036854775807), -1, "bound before multiply")


func _fill_finish_arena() -> Array[Vector2i]:
	"""Consume the actual remaining rows with distant World obstacles, never silently grow the arena."""
	var survey: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_into(survey), &"", "actual occupied row count")
	var token: int = _owner.begin_stage(_owner.revision()).token
	var removable: Array[Vector2i] = []
	for index: int in _owner.region_capacity() - survey.volumes.role.size():
		var x: int = -3000 + index * 4
		var handle: Vector2i = _add(token, [x, -3000, -3000, x + 2, -2998, -2998], Space.OBSTACLE, _world)
		if removable.size() < 2:
			removable.append(handle)
	assert_equal(_owner.seal(token), &"", "bounded full actual arena")
	_owner.publish(token)
	return removable


func test_finish_late_region_exhaustion_aborts_the_entire_paid_geometry_candidate() -> void:
	"""Failure after removing target matter and staging a finished prefix cannot lose the original cube or goods."""
	_prepare_fine_finish()
	var removable: Array[Vector2i] = _fill_finish_arena()
	var before: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	assert_equal(_sites.settle_phase(_site).error, &"SPACE_REGION_CAPACITY", "insufficient rows for exact residual")
	assert_equal(_owner.state_bytes(), before, "actual pre-finish geometry retained byte-for-byte")
	assert_equal(_inventory.state_bytes(), goods, "actual paid receipt ownership retained")
	assert_false(_owner.has_prepared(), "no leaked failed stage")
	var token: int = _owner.begin_stage(_owner.revision()).token
	for handle: Vector2i in removable:
		assert_equal(_owner.stage_remove(token, handle), &"", "release unrelated technical capacity")
	assert_equal(_owner.seal(token), &"", "actual capacity becomes available")
	_owner.publish(token)
	assert_true(_sites.settle_phase(_site).ok, "same earned phase retries without duplicate labor")
	_assert_finished_partition((256 * 1024 + 768 * 256) * 1024)


func test_finish_mask_callback_cannot_outlive_its_exact_lease_or_qualification() -> void:
	"""Mask source success is insufficient when its callback revokes a separate current-world proof."""
	_prepare_fine_finish()
	var before: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	_bindings.mask_expire_after = true
	assert_equal(_sites.settle_phase(_site).error, &"SYNTHETIC_COLD_EXPIRED", "returned mask has no lease")
	assert_equal(_owner.state_bytes(), before, "geometry unchanged after callback lease loss")
	assert_equal(_bindings.cold_active, 0, "expired proof still cleans its exact owned operation")
	_bindings.mask_expire_after = false
	_bindings.cold_attestation = &""
	_bindings.mask_drift_after = true
	assert_equal(_sites.settle_phase(_site).error, &"SPACE_GEOMETRY_STALE", "changed profile/support qualification")
	assert_equal(_owner.state_bytes(), before, "no prefix after qualification drift")
	assert_equal(_inventory.state_bytes(), goods, "neither refusal commits receipts")
	_bindings.mask_drift_after = false
	assert_true(_sites.settle_phase(_site).ok, "fresh exact proof retries")


func test_flat_finish_subtraction_preserves_negative_bounds_and_refuses_fragment_exhaustion() -> void:
	"""The bounded six-slab primitive neither snaps negative coordinates nor truncates an inner cut."""
	var part: Authority.FinishPartition = Authority.FinishPartition.new()
	part.limit = 6
	part.front.resize(36)
	part.back.resize(36)
	part.reset(PackedInt32Array([-1024, -1024, -1024, 0, 0, 0]))
	part.cut = PackedInt32Array([-768, -768, -768, -256, -256, -256])
	var check: Authority.ColdCheck = Authority.ColdCheck.new()
	check.remaining = 100
	assert_true(_authority._subtract_flat(check, part), "exact inner subtraction")
	assert_equal(part.count, 6, "six disjoint retained slabs")
	var volume: int = 0
	for row: int in part.count:
		Authority._copy_flat_box(part.front, row * 6, part.piece)
		volume += (part.piece[3] - part.piece[0]) * (part.piece[4] - part.piece[1]) * (part.piece[5] - part.piece[2])
		assert_false(Space.overlaps(part.piece, part.cut), "residual never includes cut volume")
	assert_equal(volume, 1024 * 1024 * 1024 - 512 * 512 * 512, "exact retained integer volume")
	part.limit = 5
	part.reset(PackedInt32Array([-1024, -1024, -1024, 0, 0, 0]))
	assert_false(_authority._subtract_flat(check, part), "sixth slab refuses before writing beyond five-row admission")
	assert_equal(check.error, &"SPACE_FINISH_FRAGMENT_CAPACITY", "explicit finite capacity refusal")
	part.limit = 6
	part.reset(PackedInt32Array([-1024, -1024, -1024, 0, 0, 0]))
	check.remaining = 0
	assert_false(_authority._subtract_flat(check, part), "zero operation budget cannot begin subtraction")
	assert_equal(check.error, &"SPACE_OPERATION_BUDGET", "no silent unbounded work")


func test_finish_handle_observer_cannot_allocate_banks_after_replacing_the_actual_lease() -> void:
	"""A real Budget replacement during handle observation refuses before either residual bank grows."""
	_prepare_fine_finish()
	var geometry: PackedByteArray = _owner.state_bytes()
	var goods: PackedByteArray = _inventory.state_bytes()
	var physical: PackedByteArray = _sites.state_bytes()
	var observed: ObservedSpace = _owner as ObservedSpace
	var actual: Budget = Budget.new()
	_bindings.actual_budget = actual
	_bindings.mask_override_enabled = true
	_bindings.mask_override = PackedInt32Array([0, 0, 0, 256, 1024, 1024, 256, 0, 0, 1024, 1024, 256])
	observed.observed_budget = actual
	observed.replace_at_read = observed.handle_reads + 2
	var result: Construction.OpResult = _sites.settle_phase(_site)
	assert_false(result.ok, "expired original reservation cannot prepare FINISH")
	assert_equal(result.error, Budget.REFUSE_TOKEN, "exact actual token refusal after handles")
	assert_equal((_authority as ObservedAuthority).finish_front_size, 0, "first bank never allocated")
	assert_equal((_authority as ObservedAuthority).finish_back_size, 0, "second bank never allocated")
	assert_equal(_owner.state_bytes(), geometry, "no geometry or staged prefix published")
	assert_equal(_inventory.state_bytes(), goods, "no output or input ownership changed")
	assert_equal(_sites.state_bytes(), physical, "real earned physical phase remains unchanged")
	assert_false(_owner.has_prepared(), "whole candidate aborted")
	assert_true(actual.covers(observed.replacement_token, Budget.COLD_BYTES), "cleanup preserved replacement lease")
	assert_equal(actual.release(observed.replacement_token), &"", "actual new owner releases its lease")
	observed.replace_at_read = -1
	assert_true(_sites.settle_phase(_site).ok, "fresh actual lease permits exactly one retry")
	assert_true(actual.is_quiescent(), "successful path releases its own actual lease")
