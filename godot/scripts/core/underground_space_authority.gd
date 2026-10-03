extends "res://scripts/core/excavation_contract.gd".SpatialAuthority
## Actual Sites/geometry adapter. Qualified movement, support and topology remain mandatory typed
## owner bindings; the base binding refuses. No UI callback or preview can publish physical space.
## Cold candidates use whole paid cubes; productive WORK reads only revision-bound static proofs.

const Contract := preload("res://scripts/core/excavation_contract.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const NO_ROW: int = -1
const I32_FIELDS: int = 11
const I64_FIELDS: int = 2
const SITE_SLOT: int = 0
const SITE_GENERATION: int = 1
const ROOM_SLOT: int = 2
const ROOM_GENERATION: int = 3
const PROJECT_SLOT: int = 4
const PROJECT_GENERATION: int = 5
const ORIGIN_X: int = 6
const ORIGIN_Y: int = 7
const ORIGIN_Z: int = 8
const OPERATION: int = 9
const PHASE: int = 10
const GEOMETRY_REVISION: int = 0
const QUALIFICATION_REVISION: int = 1
const COLD_BOX_SCRATCH_BYTES: int = 16 * 6 * 4


class Bindings extends Space.Authority:

	## A real composed implementation reads actual measured profiles, movement, material contacts,
	## structure, room validity/services and topology. It is never a caller-supplied yes/no flag.
	func sources() -> Owner.CoreSources:
		"""Return the exact geometry owner's actual source reader, or remain unbound."""
		return null

	func allocation_refusal(_owner: Owner, _proof_rows: int, _cache_bytes: int) -> StringName:
		"""Prove the joint owner/cache/cold-input/companion peak fits the composed allocation pack."""
		return &"SPACE_COMPOSITION_BUDGET_UNBOUND"

	func begin_cold_operation(_owner: Owner, _site: Vector2i, _operation: int, _stage: int) -> int:
		"""Reserve the actual simultaneous world-owned cold peak before the first survey allocation."""
		return 0

	func cold_operation_refusal(_token: int) -> StringName:
		"""Attest the same actual Budget token and all nested companion charges without mutation."""
		return &"SPACE_COMPOSITION_COLD_UNBOUND"

	func end_cold_operation(_token: int) -> void:
		"""Release only after every charged survey/plan and retained companion has been discarded."""
		assert(false, "Unbound geometry cannot hold a cold-operation lease")

	func qualification_revision() -> int:
		"""Actual static profile, structural and route qualification revision; zero is unavailable."""
		return 0

	func room_refusal(_room: Vector2i) -> StringName:
		"""Require actual underground Room registration, immutable purpose and current geometry binding."""
		return &"SPACE_ROOM_PUBLICATION_UNBOUND"

	func retirement_refusal(_room: Vector2i) -> StringName:
		"""Prove actual occupants, fittings, contacts, pending work, support and exits permit retirement."""
		return &"SPACE_ROOM_RETIREMENT_UNBOUND"

	func phase_plan_into(_site: Vector2i, _operation: int, _stage: int, _room: Vector2i,
			_volume_rows_limit: int, _out: Space.Plan) -> StringName:
		"""Bound combined volume/approach/reach rows before allocation; read actual measured next-face truth."""
		return &"SPACE_PHASE_CONTACT_UNBOUND"

	func phase_qualification_refusal(_domain: Space.Domain, _snapshot: Space.Snapshot,
			_plan: Space.Plan, _site: Vector2i, _operation: int, _stage: int) -> StringName:
		"""Qualify actual support/load/dryness and operation-specific reachable work without mutation."""
		return &"SPACE_PHASE_QUALIFICATION_UNBOUND"

	func worker_refusal(_origin: Vector3i, _operation: int, _room: Vector2i, _job: Vector2i,
			_worker: Vector2i, _geometry_revision: int, _qualification_revision: int) -> StringName:
		"""Read fresh actual posture/gear/load, full worker identity and dirty dynamic broadphase truth."""
		return &"SPACE_WORKER_CONTACT_UNBOUND"

	func assigned_worker(_site: Vector2i, _job: Vector2i) -> Vector2i:
		"""Read the actual Job's assigned worker; a contact cannot nominate an arbitrary resident."""
		return NULL_REF

	func floor_section(_site: Vector2i, _room: Vector2i) -> Vector2i:
		"""Read the actual room-owned floor-section handle; no floor spacing or level is guessed."""
		return NULL_REF

	func material_refusal(_origin: Vector3i, _room: Vector2i, _container: Vector2i,
			_job: Vector2i) -> StringName:
		"""Prove the real material container's complete bound location and legal current approach."""
		return &"SPACE_MATERIAL_CONTACT_UNBOUND"

	func output_refusal(_origin: Vector3i, _operation: int, _room: Vector2i,
			_container: Vector2i, _job: Vector2i, _promotion_tile: int) -> StringName:
		"""Prove actual finite output contact ownership, including held first-pile promotion leases."""
		return &"SPACE_OUTPUT_CONTACT_UNBOUND"

	func stage_physical_geometry(_owner: Owner, _owner_token: int, _site: Vector2i,
			_operation: int, _stage: int, _room: Vector2i, _plan: Space.Plan) -> StringName:
		"""Derive actual support/floor/shell edits before sealing; missing concrete content refuses."""
		return &"SPACE_PHYSICAL_GEOMETRY_UNBOUND"

	func prepare_companions(_owner_token: int, _site: Vector2i, _operation: int,
			_stage: int, _room: Vector2i, _plan: Space.Plan) -> int:
		"""Stage measured support and real service/topology owners; zero supplies no publishable token."""
		return 0

	func prepared_refusal(_token: int) -> StringName:
		"""Revalidate the complete companion candidate before the physical transaction commits."""
		return &"SPACE_COMPANION_PUBLICATION_UNBOUND"

	func revision_after(_token: int) -> int:
		"""Return the precomputed qualification revision that the exact prepared publication installs."""
		return 0

	func discard_companions(_token: int) -> void:
		"""An unbound provider cannot own a prepared companion publication."""
		assert(false, "No unbound companion token can be discarded")

	func publish_companions(_token: int) -> void:
		"""The actual owner publishes only previously sealed state without allocation or refusal."""
		assert(false, "No unbound companion token can be published")


class ColdCheck extends RefCounted:
	## One bounded synchronous check, never a resident/entity object or per-WORK allocation.
	var snapshot: Space.Snapshot = Space.Snapshot.new()
	var plan: Space.Plan = Space.Plan.new()
	var target: PackedInt32Array = PackedInt32Array()
	var remaining: int = 0
	var fragments: int = 0
	var error: StringName = &""
	var site: Vector2i = NULL_REF
	var operation: int = -1
	var stage: int = -1
	var qualification_revision: int = 0

	func spend(amount: int = 1) -> bool:
		"""Refuse before a bounded cold operation exceeds its explicit comparison allowance."""
		if amount < 0 or remaining < amount:
			error = &"SPACE_OPERATION_BUDGET"
			return false
		remaining -= amount
		return true


var _owner: Owner = null
var _bindings: Bindings = null
var _sources: Owner.CoreSources = null
var _construction: Construction = null
var _buildings: Buildings = null
var _domain: Space.Domain = null
var _sites: WeakRef = null
var _ready_error: StringName = &"SPACE_AUTHORITY_UNBOUND"
var _capacity: int = 0
var _count: int = 0
var _free_count: int = 0
var _present: PackedByteArray = PackedByteArray()
var _proof_i32: PackedInt32Array = PackedInt32Array()
var _proof_i64: PackedInt64Array = PackedInt64Array()
var _ordered: PackedInt32Array = PackedInt32Array()
var _free: PackedInt32Array = PackedInt32Array()
var _next_i32: PackedInt32Array = PackedInt32Array()
var _next_i64: PackedInt64Array = PackedInt64Array()
var _stage: int = -1
var _owner_token: int = 0
var _companion_token: int = 0
var _cache_row: int = NO_ROW
var _cache_position: int = NO_ROW
var _new_cache_row: bool = false
var _geometry_changed: bool = false
var _cold_token: int = 0
var _phase_number: IntMath.IntResult = IntMath.IntResult.new()
var _operation_number: IntMath.IntResult = IntMath.IntResult.new()


func configure(owner: Owner, bindings: Bindings, proof_rows: int) -> StringName:
	"""Bind actual owners and an explicitly jointly admitted finite cache before allocating arrays."""
	if _owner != null:
		return &"SPACE_AUTHORITY_ALREADY_CONFIGURED"
	if owner == null or bindings == null or bindings.sources() == null \
			or not owner.is_bound_sources(bindings.sources()):
		return &"SPACE_AUTHORITY_OWNER_MISMATCH"
	if proof_rows < 1 or proof_rows > mini(Jobs.JOB_CAPACITY, Construction.CONSTRUCTION_CAPACITY):
		return &"SPACE_PROOF_CAPACITY"
	var construction: Construction = bindings.sources().construction_owner()
	if construction == null or construction.directory() != bindings.sources().directory():
		return &"SPACE_AUTHORITY_OWNER_MISMATCH"
	var code: StringName = bindings.allocation_refusal(owner, proof_rows, 69 * proof_rows + 60)
	if code != &"":
		return code
	_owner = owner
	_bindings = bindings
	_sources = bindings.sources()
	_construction = construction
	_buildings = construction.buildings()
	_domain = owner.domain_copy()
	_capacity = proof_rows
	_allocate_cache()
	_ready_error = &""
	return &""


func _allocate_cache() -> void:
	"""All productive-path storage is finite and allocated once after joint composition admission."""
	_present.resize(_capacity)
	_proof_i32.resize(_capacity * I32_FIELDS)
	_proof_i64.resize(_capacity * I64_FIELDS)
	_ordered.resize(_capacity)
	_free.resize(_capacity)
	_next_i32.resize(I32_FIELDS)
	_next_i64.resize(I64_FIELDS)
	_clear_cache()


func initialization_refusal() -> StringName:
	"""Report missing composition without treating an empty cache as permission to work."""
	return _ready_error


func bind_sites(sites: Sites) -> StringName:
	"""Complete the weak back-reference only for actual initialized Sites bound to this adapter."""
	if _ready_error != &"" or sites == null or sites.initialization_refusal() != &"" \
			or sites.construction_owner() != _construction or not sites.is_bound_spatial(self) \
			or _construction.excavation_authority() != sites:
		return &"SPACE_SITE_OWNER_MISMATCH"
	if _sites != null and _sites.get_ref() != sites:
		return &"SPACE_SITES_ALREADY_BOUND"
	_sites = weakref(sites)
	return &""


func domain_into(out: Contract.Domain) -> bool:
	"""Expose the immutable actual world descriptor needed while constructing its physical ledger."""
	if _ready_error != &"" or out == null:
		return false
	out.world_ref = _domain._world
	out.datum_u = _domain._datum
	out.minimum_quantum = _domain._min_quantum
	out.size_quanta = _domain._size_quanta
	return true


func room_refusal(room: Vector2i) -> StringName:
	"""Validate actual full Room identity without recursive Sites.room_of calls or region scans."""
	if _ready_error != &"" or not _buildings.is_live_room(room):
		return &"SPACE_ROOM_STALE"
	return _bindings.room_refusal(room)


func retirement_refusal(room: Vector2i) -> StringName:
	"""Room removal needs actual occupancy, structure and last-exit truth beyond phase retirement."""
	var code: StringName = room_refusal(room)
	return _bindings.retirement_refusal(room) if code == &"" else code


func packed_memory_bytes() -> int:
	"""Cache, validity, indexes and one prepared row; caller/cold/native/companion memory is separate."""
	return 69 * _capacity + 60 if _capacity > 0 else 0


static func cold_packed_peak_bytes(region_capacity: int, source_capacity: int, volume_limit: int) -> int:
	"""Bound accepted input/copy/fragment/query payload; exclude separately admitted binding/native storage."""
	if volume_limit < 1 or volume_limit > Space.MAX_REGIONS or region_capacity < 1 \
			or region_capacity > volume_limit or source_capacity < 1 or source_capacity > volume_limit:
		return -1
	return 120 * volume_limit + 32 * source_capacity + COLD_BOX_SCRATCH_BYTES


func _physical() -> Sites:
	"""A weak borrowed physical owner avoids a cycle through its spatial authority."""
	return _sites.get_ref() as Sites if _sites != null else null


func _context_refusal(origin: Vector3i, operation: int, room: Vector2i) -> StringName:
	"""Read actual identities before any geometry, proof index or work-stage operation."""
	var code: StringName = room_refusal(room)
	if code != &"":
		return code
	var sites: Sites = _physical()
	if sites == null or sites.construction_owner() != _construction or not sites.is_bound_spatial(self) \
			or _construction.excavation_authority() != sites or not Contract.valid_operation(operation):
		return &"SPACE_SITE_OWNER_MISMATCH"
	if not _sources.directory().is_valid_of_kind(_domain._world, Directory.KIND_WORLD):
		return &"SPACE_WORLD_STALE"
	var site: Vector2i = sites.site_at(origin)
	if not sites.is_live_site(site) or sites.origin_of(site) != origin or sites.room_of(site) != room:
		return &"SPACE_SITE_STALE"
	return &""


func operation_refusal(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> StringName:
	"""Prepare only cold lifecycle transitions; productive WORK performs no owner or region scan."""
	if stage < Contract.STAGE_ADMIT or stage > Contract.STAGE_WORK:
		return &"SPACE_STAGE_INVALID"
	var code: StringName = _context_refusal(origin, operation, room)
	if code != &"":
		return code
	var site: Vector2i = _physical().site_at(origin)
	if stage == Contract.STAGE_WORK:
		return _work_refusal(site, operation, room)
	if _stage != -1 or _owner.has_prepared() or _cold_token != 0:
		return &"SPACE_TRANSITION_BUSY"
	code = _phase_refusal(site, operation, stage)
	if code != &"":
		return code
	return _run_cold_operation(site, operation, stage, room)


func _begin_cold(site: Vector2i, operation: int, stage: int) -> StringName:
	"""Acquire before any ColdCheck copies; a refused reservation leaves no charged objects behind."""
	if _cold_token != 0:
		return &"SPACE_TRANSITION_BUSY"
	_cold_token = _bindings.begin_cold_operation(_owner, site, operation, stage)
	if _cold_token <= 0:
		_cold_token = 0
		return &"SPACE_COLD_RESERVATION_REFUSED"
	var code: StringName = _bindings.cold_operation_refusal(_cold_token)
	if code != &"":
		_release_cold()
	return code


func _release_cold() -> void:
	"""The caller has already dropped every charged temporary and any retained companion."""
	if _cold_token > 0:
		_bindings.end_cold_operation(_cold_token)
		_cold_token = 0


func _run_cold_operation(site: Vector2i, operation: int, stage: int, room: Vector2i) -> StringName:
	"""Proof-only calls release their survey; successful prepared phases retain the same shared lease."""
	var code: StringName = _begin_cold(site, operation, stage)
	if code != &"":
		return code
	var check: ColdCheck = ColdCheck.new()
	code = _cold_refusal(check, site, operation, stage, room)
	if code == &"" and stage != Contract.STAGE_ADMIT:
		code = _prepare(check, site, operation, stage, room)
	check = null
	if code != &"" or stage == Contract.STAGE_ADMIT:
		_release_cold()
	return code


func _phase_refusal(site: Vector2i, operation: int, stage: int) -> StringName:
	"""A cold candidate binds the physical state and exact actual phase project, never caller WU."""
	var sites: Sites = _physical()
	if not sites.phase_into(site, _phase_number):
		return &"SPACE_SITE_STALE"
	if stage == Contract.STAGE_ADMIT:
		return &"" if sites.project_of(site) == NULL_REF else &"SPACE_PHASE_STALE"
	if not sites.operation_into(site, _operation_number) or _operation_number.value != operation \
			or not _construction.is_live_project(sites.project_of(site)):
		return &"SPACE_PHASE_STALE"
	if stage == Contract.STAGE_START and (not _construction.phase_into(sites.project_of(site), _operation_number) \
			or _operation_number.value != Construction.PHASE_READY):
		return &"SPACE_PHASE_NOT_READY"
	if stage == Contract.STAGE_COMMIT:
		if not _construction.phase_into(sites.project_of(site), _operation_number) \
				or _operation_number.value != Construction.PHASE_WORK_DONE \
				or not _construction.remaining_mwu_into(sites.project_of(site), _operation_number) \
				or _operation_number.value != 0 or sites.job_of(site) == NULL_REF:
			return &"SPACE_WORK_INCOMPLETE"
	return &""


func _work_refusal(site: Vector2i, operation: int, room: Vector2i) -> StringName:
	"""Exact cached static truth is necessary; no cache miss can trigger a whole cold rebuild here."""
	var position: int = _lower_bound(site.x)
	if position == _count:
		return &"SPACE_STATIC_PROOF_MISSING"
	var row: int = _ordered[position]
	if not _proof_identity_matches(row, site, operation, room):
		return &"SPACE_STATIC_PROOF_STALE"
	if _proof_i64[row * I64_FIELDS + GEOMETRY_REVISION] != _owner.revision() \
			or _proof_i64[row * I64_FIELDS + QUALIFICATION_REVISION] != _bindings.qualification_revision():
		return &"SPACE_STATIC_PROOF_STALE"
	return &"" if _stage == -1 and not _owner.has_prepared() else &"SPACE_TRANSITION_BUSY"


func _proof_identity_matches(row: int, site: Vector2i, operation: int, room: Vector2i) -> bool:
	"""All generations and current physical phase are read afresh without allocating a snapshot."""
	var at: int = row * I32_FIELDS
	var sites: Sites = _physical()
	if row < 0 or row >= _capacity or _present[row] != 1 or not sites.phase_into(site, _phase_number):
		return false
	var project: Vector2i = sites.project_of(site)
	return _proof_i32[at + SITE_SLOT] == site.x and _proof_i32[at + SITE_GENERATION] == site.y \
		and _proof_i32[at + ROOM_SLOT] == room.x and _proof_i32[at + ROOM_GENERATION] == room.y \
		and _proof_i32[at + PROJECT_SLOT] == project.x and _proof_i32[at + PROJECT_GENERATION] == project.y \
		and _proof_i32[at + OPERATION] == operation and _proof_i32[at + PHASE] == _phase_number.value \
		and sites.operation_into(site, _operation_number) and _operation_number.value == operation


func worker_refusal(origin: Vector3i, operation: int, room: Vector2i,
		job: Vector2i, worker: Vector2i) -> StringName:
	"""Keep fresh posture/load/occupancy proof mandatory before every actual productive worker tick."""
	var code: StringName = _context_refusal(origin, operation, room)
	if code != &"":
		return code
	var site: Vector2i = _physical().site_at(origin)
	if _physical().job_of(site) != job or job == NULL_REF \
			or not _sources.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return &"SPACE_WORKER_IDENTITY"
	return _bindings.worker_refusal(origin, operation, room, job, worker, _owner.revision(),
		_bindings.qualification_revision())


func material_refusal(origin: Vector3i, room: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Actual Inventory namespace/contact validation stays in its typed movement/material owner."""
	var code: StringName = _contact_context_refusal(origin, room, job)
	return _bindings.material_refusal(origin, room, container, job) if code == &"" else code


func output_refusal(origin: Vector3i, operation: int, room: Vector2i,
		container: Vector2i, job: Vector2i, promotion_tile: int) -> StringName:
	"""An arbitrary tile or numeric container ref never substitutes for an actual held output contact."""
	var code: StringName = _contact_context_refusal(origin, room, job)
	if code != &"" or not _physical().operation_into(_physical().site_at(origin), _operation_number) \
			or _operation_number.value != operation:
		return code if code != &"" else &"SPACE_PHASE_STALE"
	return _bindings.output_refusal(origin, operation, room, container, job, promotion_tile)


func _contact_context_refusal(origin: Vector3i, room: Vector2i, job: Vector2i) -> StringName:
	"""Material and output readers name the actual active Job for this exact immutable physical key."""
	var sites: Sites = _physical()
	if sites == null:
		return &"SPACE_SITE_OWNER_MISMATCH"
	var site: Vector2i = sites.site_at(origin)
	if not sites.operation_into(site, _operation_number):
		return &"SPACE_PHASE_STALE"
	var code: StringName = _context_refusal(origin, _operation_number.value, room)
	if code != &"":
		return code
	return &"" if job != NULL_REF and sites.job_of(site) == job else &"SPACE_JOB_STALE"


func _cold_refusal(check: ColdCheck, site: Vector2i, operation: int, stage: int,
		room: Vector2i) -> StringName:
	"""Copy a complete bounded cold survey and bind a real operation-specific contact plan."""
	check.remaining = _domain._checks
	check.fragments = _domain._regions
	check.site = site
	check.operation = operation
	check.stage = stage
	check.qualification_revision = _bindings.qualification_revision()
	check.target = Space.quantum_box(_domain, _physical().origin_of(site))
	if check.target.is_empty() or _bindings.qualification_revision() < 1:
		return &"SPACE_QUALIFICATION_UNBOUND"
	var code: StringName = _owner.snapshot_for_site_into(check.snapshot, _physical(), site)
	if code != &"":
		return code
	code = _bindings.phase_plan_into(site, operation, stage, room,
		_domain._regions - check.snapshot.volumes.role.size(), check.plan)
	if code == &"":
		code = _plan_format_refusal(check, room)
	if code == &"":
		code = _target_refusal(check, operation, room)
	if code == &"":
		code = _contacts_refusal(check, room)
	if code == &"":
		code = _bindings.phase_qualification_refusal(_domain, check.snapshot.copy(), check.plan.copy(),
			site, operation, stage)
	if code == &"" and (check.snapshot.revision != _owner.revision() or _owner.source_refusal(room) != &"" \
			or check.qualification_revision != _bindings.qualification_revision()):
		return &"SPACE_GEOMETRY_STALE"
	return code


func _plan_format_refusal(check: ColdCheck, room: Vector2i) -> StringName:
	"""Bound every table and integer namespace before indexing or copying qualification inputs."""
	var plan: Space.Plan = check.plan
	if plan == null or plan.owner_ref != room or plan.expected_revision != check.snapshot.revision \
			or plan.owner_revision != _owner.source_revision(room) or plan.contacts == null:
		return &"SPACE_PHASE_PLAN_STALE"
	var total: int = check.snapshot.volumes.role.size()
	for rows: Space.Volumes in [plan.volumes, plan.contacts.approach, plan.contacts.reach]:
		if rows == null:
			return &"SPACE_PHASE_PLAN_FORMAT"
		total += rows.role.size()
		if total > _domain._regions or not _rows_valid(check, rows):
			return check.error if check.error != &"" else &"SPACE_PHASE_PLAN_FORMAT"
	var count: int = plan.contacts.profile_id.size()
	if (count < 1 and check.stage != Contract.STAGE_CANCEL) or plan.contacts.profile_revision.size() != count \
			or plan.contacts.approach.role.size() != count or plan.contacts.reach.role.size() != count \
			or plan.contacts.work_xyz.size() != count * 3:
		return &"SPACE_PHASE_CONTACT_MISSING"
	if not plan.cuts_xyz.is_empty() or not plan.cut_contacts.is_empty() or not plan.endpoints_xyz.is_empty() \
			or not plan.endpoint_levels.is_empty() or not plan.endpoint_refs.is_empty() or not plan.endpoint_revisions.is_empty():
		return &"SPACE_PHASE_PLAN_SCOPE"
	return &""


func _rows_valid(check: ColdCheck, rows: Space.Volumes) -> bool:
	"""An actual phase plan contains bounded integer owner-qualified regions, never float boxes."""
	var count: int = rows.role.size()
	for column: Variant in [rows.lo_x, rows.lo_y, rows.lo_z, rows.hi_x, rows.hi_y, rows.hi_z,
			rows.level, rows.owner_slot, rows.owner_generation, rows.owner_revision]:
		if column.size() != count:
			return false
	for row: int in count:
		if not check.spend():
			return false
		var box: PackedInt32Array = rows.box_at(row)
		if not Space.valid_box(box) or not Space.contains_box(_domain._bounds, box) \
				or rows.level[row] < 0 or rows.role[row] < Space.ENVELOPE or rows.role[row] > Space.SOLID \
				or _snapshot_source_revision(check, rows.ref_at(row)) != rows.owner_revision[row] or rows.owner_revision[row] < 1:
			return false
	return true


func _snapshot_source_revision(check: ColdCheck, ref: Vector2i) -> int:
	"""Charge the actual bounded source scan; many contacts cannot hide quadratic unbudgeted work."""
	for row: int in check.snapshot.live_revisions.size():
		if not check.spend():
			return 0
		if check.snapshot.live_refs[row * 2] == ref.x and check.snapshot.live_refs[row * 2 + 1] == ref.y:
			return check.snapshot.live_revisions[row]
	return 0


func _target_refusal(check: ColdCheck, operation: int, room: Vector2i) -> StringName:
	"""The entire paid cube needs actual current matter/void truth; unknown gaps never become free space."""
	var roles: Array[int] = [Space.DRY_SOLID]
	var required_owner: Vector2i = NULL_REF
	if operation == Contract.OP_FINISH:
		roles = [Space.UNFINISHED]
		required_owner = room
	elif operation == Contract.OP_BACKFILL_CLOSE:
		roles = [Space.UNFINISHED, Space.SUPPORTED_VOID]
		required_owner = room
	if not _covers(check, check.target, roles, required_owner):
		return check.error if check.error != &"" else &"SPACE_PHASE_TARGET_UNKNOWN"
	for row: int in check.snapshot.volumes.role.size():
		if not check.spend():
			return check.error
		var role: int = check.snapshot.volumes.role[row]
		if not Space.overlaps(check.target, check.snapshot.volumes.box_at(row)):
			continue
		if role in [Space.DRY_SOLID, Space.UNFINISHED, Space.SUPPORTED_VOID] \
				and (role not in roles or (required_owner != NULL_REF and check.snapshot.volumes.ref_at(row) != required_owner)):
			return &"SPACE_PHASE_TARGET_CONFLICT"
		if role in [Space.OBSTACLE, Space.PROTECTED_ACCESS, Space.OPENABLE_SHELL,
				Space.WATER, Space.RESOURCE, Space.OCCUPANT] \
				and check.stage != Contract.STAGE_CANCEL:
			return &"SPACE_PHASE_TARGET_OBSTRUCTED"
	return &""


func _contacts_refusal(check: ColdCheck, room: Vector2i) -> StringName:
	"""Approaches already exist; only the exact retained work target may be unfinished within reach."""
	var contacts: Space.Contacts = check.plan.contacts
	for row: int in contacts.profile_id.size():
		if contacts.profile_id[row] < 0 or contacts.profile_revision[row] < 1:
			return &"SPACE_PROFILE_MISSING"
		var approach: PackedInt32Array = contacts.approach.box_at(row)
		var reach: PackedInt32Array = contacts.reach.box_at(row)
		var point: Vector3i = Space.point_at(contacts.work_xyz, row)
		if not _covers(check, approach, [Space.SUPPORTED_VOID]):
			return check.error if check.error != &"" else &"SPACE_WORK_APPROACH_UNFINISHED"
		if not Space.contains_box(reach, approach) or not _contains_point(reach, point) or not _on_face(check.target, point):
			return &"SPACE_WORK_REACH"
		if not _covers(check, reach, [Space.DRY_SOLID, Space.SUPPORTED_VOID, Space.UNFINISHED]):
			return check.error if check.error != &"" else &"SPACE_WORK_REACH"
		var code: StringName = _contact_obstructions(check, approach, reach, contacts.approach.ref_at(row), room)
		if code != &"":
			return code
	return _support_refusal(check)


func _contact_obstructions(check: ColdCheck, approach: PackedInt32Array, reach: PackedInt32Array,
		contact_owner: Vector2i, room: Vector2i) -> StringName:
	"""Keep all actual rows; only an attested assigned worker can intersect its own approach envelope."""
	var rows: Space.Volumes = check.snapshot.volumes
	for row: int in rows.role.size():
		if not check.spend():
			return check.error
		var role: int = rows.role[row]
		var box: PackedInt32Array = rows.box_at(row)
		if role < Space.OBSTACLE or role == Space.FLOOR_DATUM or not Space.overlaps(reach, box):
			continue
		if role == Space.UNFINISHED and rows.ref_at(row) == room \
				and Space.contains_box(check.target, Space.intersection(reach, box)) \
				and not Space.overlaps(approach, box):
			continue
		if role == Space.OCCUPANT and rows.ref_at(row) == contact_owner \
				and _is_exact_contact_worker(check, contact_owner, room):
			continue
		return &"SPACE_WORK_CONTACT_OBSTRUCTED"
	return &""


func _is_exact_contact_worker(check: ColdCheck, occupant: Vector2i, room: Vector2i) -> bool:
	"""Read actual Job assignment and fresh worker qualification; a same-Room occupant is not enough."""
	var job: Vector2i = _physical().job_of(check.site)
	if job == NULL_REF or not _sources.directory().is_valid_of_kind(occupant, Directory.KIND_RESIDENT) \
			or _bindings.assigned_worker(check.site, job) != occupant:
		return false
	return _bindings.worker_refusal(_physical().origin_of(check.site), check.operation, room, job,
		occupant, check.snapshot.revision, check.qualification_revision) == &""


func _support_refusal(check: ColdCheck) -> StringName:
	"""Any declared required support must be real; other next-face regions remain qualification inputs."""
	var rows: Space.Volumes = check.plan.volumes
	for row: int in rows.role.size():
		if rows.role[row] == Space.SUPPORT_REQUIRED and not _covers(check, rows.box_at(row), [Space.SUPPORT]):
			return check.error if check.error != &"" else &"SPACE_SUPPORT_MISSING"
	return &""


func _covers(check: ColdCheck, box: PackedInt32Array, roles: Array[int], owner: Vector2i = NULL_REF) -> bool:
	"""Exact bounded union subtraction detects interior holes; corner samples and bounding boxes do not."""
	var pending: Array[PackedInt32Array] = [box]
	var rows: Space.Volumes = check.snapshot.volumes
	for row: int in rows.role.size():
		if not check.spend():
			return false
		if rows.role[row] not in roles or (owner != NULL_REF and rows.ref_at(row) != owner):
			continue
		var next: Array[PackedInt32Array] = []
		for fragment: PackedInt32Array in pending:
			if not check.spend() or not _subtract(check, fragment, rows.box_at(row), next):
				return false
		pending = next
		if pending.is_empty():
			return true
	return false


func _subtract(check: ColdCheck, box: PackedInt32Array, cover: PackedInt32Array,
		out: Array[PackedInt32Array]) -> bool:
	"""At most six disjoint outside slabs remain after removing an intersecting half-open box."""
	if not Space.overlaps(box, cover):
		return _append_fragment(check, out, box)
	var cut: PackedInt32Array = Space.intersection(box, cover)
	var core: PackedInt32Array = box.duplicate()
	for axis: int in 3:
		if core[axis] < cut[axis]:
			var before: PackedInt32Array = core.duplicate()
			before[axis + 3] = cut[axis]
			if not _append_fragment(check, out, before):
				return false
			core[axis] = cut[axis]
		if core[axis + 3] > cut[axis + 3]:
			var after: PackedInt32Array = core.duplicate()
			after[axis] = cut[axis + 3]
			if not _append_fragment(check, out, after):
				return false
			core[axis + 3] = cut[axis + 3]
	return true


func _append_fragment(check: ColdCheck, out: Array[PackedInt32Array], box: PackedInt32Array) -> bool:
	"""Refuse before growing the exact-union scratch beyond its explicit region ceiling."""
	if out.size() >= check.fragments:
		check.error = &"SPACE_FRAGMENT_CAPACITY"
		return false
	out.append(box)
	return true


static func _contains_point(box: PackedInt32Array, point: Vector3i) -> bool:
	"""Use actual half-open coordinates for reach; no vector float conversion participates."""
	for axis: int in 3:
		if point[axis] < box[axis] or point[axis] >= box[axis + 3]:
			return false
	return true


static func _on_face(box: PackedInt32Array, point: Vector3i) -> bool:
	"""A target-face point lies in its closed boundary and on at least one exact face plane."""
	var face: bool = false
	for axis: int in 3:
		if point[axis] < box[axis] or point[axis] > box[axis + 3]:
			return false
		face = face or point[axis] == box[axis] or point[axis] == box[axis + 3]
	return face


func _prepare(check: ColdCheck, site: Vector2i, operation: int, stage: int, room: Vector2i) -> StringName:
	"""Reserve all finite cache/geometry/companion state before the physical owner can spend anything."""
	var code: StringName = _reserve_candidate(site, operation, stage, room)
	if code != &"":
		return code
	var started: Owner.Result = _owner.begin_stage(check.snapshot.revision)
	if not started.ok():
		return _failed_prepare(started.error)
	_owner_token = started.token
	code = _stage_geometry(check, site, operation, stage, room)
	if code == &"":
		code = _bindings.stage_physical_geometry(_owner, _owner_token, site, operation,
			stage, room, check.plan.copy())
	if code != &"":
		return _failed_prepare(code)
	code = _owner.seal(_owner_token)
	if code != &"":
		return _failed_prepare(code)
	_companion_token = _bindings.prepare_companions(_owner_token, site, operation, stage, room, check.plan.copy())
	if _companion_token <= 0:
		return _failed_prepare(&"SPACE_COMPANION_PREPARATION_REFUSED")
	_geometry_changed = _owner.prepared_has_changes(_owner_token)
	_next_i64[GEOMETRY_REVISION] = _owner.revision() + int(_geometry_changed)
	_next_i64[QUALIFICATION_REVISION] = _bindings.revision_after(_companion_token)
	code = _final_preflight(check, site, operation, stage, room)
	return &"" if code == &"" else _failed_prepare(code)


func _reserve_candidate(site: Vector2i, operation: int, stage: int, room: Vector2i) -> StringName:
	"""Only START installs a static proof; terminal phases remove their exact prior proof on publish."""
	var position: int = _lower_bound(site.x)
	var row: int = _ordered[position] if position < _count else NO_ROW
	if row != NO_ROW and _proof_i32[row * I32_FIELDS + SITE_SLOT] != site.x:
		row = NO_ROW
	if stage == Contract.STAGE_START and row == NO_ROW:
		if _free_count == 0:
			return &"SPACE_PROOF_CAPACITY"
		row = _heap_pop()
		_new_cache_row = true
	_stage = stage
	_cache_row = row
	_cache_position = position
	var project: Vector2i = _physical().project_of(site)
	var origin: Vector3i = _physical().origin_of(site)
	_next_i32[SITE_SLOT] = site.x
	_next_i32[SITE_GENERATION] = site.y
	_next_i32[ROOM_SLOT] = room.x
	_next_i32[ROOM_GENERATION] = room.y
	_next_i32[PROJECT_SLOT] = project.x
	_next_i32[PROJECT_GENERATION] = project.y
	_next_i32[ORIGIN_X] = origin.x
	_next_i32[ORIGIN_Y] = origin.y
	_next_i32[ORIGIN_Z] = origin.z
	_next_i32[OPERATION] = operation
	_next_i32[PHASE] = _started_phase(operation)
	return &""


func _stage_geometry(check: ColdCheck, site: Vector2i, operation: int, stage: int,
		room: Vector2i) -> StringName:
	"""Paid phase facts determine matter changes; support/finish/services need real companion owners."""
	var code: StringName = &""
	if stage == Contract.STAGE_COMMIT or stage == Contract.STAGE_CANCEL:
		code = _remove_phase_claims(_physical().project_of(site))
	if code != &"":
		return code
	if stage == Contract.STAGE_START and operation in [Contract.OP_BACKFILL_CLOSE, Contract.OP_UNOPENED_SUPPORT_CLOSE]:
		return _reserve_closure(check.target, _physical().project_of(site), room)
	if stage != Contract.STAGE_COMMIT or operation not in [Contract.OP_CUT, Contract.OP_FINISH, Contract.OP_BACKFILL_CLOSE]:
		return &""
	return _replace_matter(check, site, operation, room)


func _remove_phase_claims(project: Vector2i) -> StringName:
	"""Retirement removes exact phase markers everywhere, preserving every persistent Room claim."""
	var handles: PackedInt32Array = PackedInt32Array()
	var code: StringName = _owner.overlapping_regions_into(_domain._bounds, handles)
	if code != &"":
		return code
	var region: Owner.Region = Owner.Region.new()
	@warning_ignore("integer_division")
	for index: int in handles.size() / 2:
		var handle: Vector2i = Vector2i(handles[index * 2], handles[index * 2 + 1])
		if _owner.region_into(handle, region) != &"":
			return &"SPACE_REGION_STALE"
		if region.claim_kind == Owner.CLAIM_CONSTRUCTION and region.claim_ref == project:
			code = _owner.stage_remove(_owner_token, handle)
			if code != &"":
				return code
	return &""


func _reserve_closure(box: PackedInt32Array, project: Vector2i, room: Vector2i) -> StringName:
	"""Keep entry blocked during actual closing, without duplicating an existing whole-target claim."""
	var handles: PackedInt32Array = PackedInt32Array()
	var code: StringName = _owner.overlapping_regions_into(box, handles)
	if code != &"":
		return code
	var region: Owner.Region = Owner.Region.new()
	@warning_ignore("integer_division")
	for index: int in handles.size() / 2:
		code = _owner.region_into(Vector2i(handles[index * 2], handles[index * 2 + 1]), region)
		if code != &"":
			return code
		if region.claim_kind == Owner.CLAIM_CONSTRUCTION and region.claim_ref == project \
				and Space.contains_box(region.box, box):
			return &""
	region = Owner.Region.new()
	region.box = box
	region.role = Space.OBSTACLE
	region.owner = room
	region.claim_kind = Owner.CLAIM_CONSTRUCTION
	region.claim_ref = project
	var floor_region: Owner.Region = Owner.Region.new()
	code = _room_floor_into(_physical().site_at(Vector3i(box[0], box[1], box[2])), room, floor_region)
	if code != &"":
		return code
	region.level = floor_region.level
	return _owner.stage_add(_owner_token, region).error


func _replace_matter(check: ColdCheck, site: Vector2i, operation: int, room: Vector2i) -> StringName:
	"""Replace only the exact paid cube, retaining disjoint outside slabs and their complete identities."""
	var handles: PackedInt32Array = PackedInt32Array()
	var code: StringName = _owner.overlapping_regions_into(check.target, handles)
	if code != &"":
		return code
	var region: Owner.Region = Owner.Region.new()
	@warning_ignore("integer_division")
	for index: int in handles.size() / 2:
		var handle: Vector2i = Vector2i(handles[index * 2], handles[index * 2 + 1])
		if _owner.region_into(handle, region) != &"":
			return &"SPACE_REGION_STALE"
		if region.claim_kind != Owner.CLAIM_NONE or region.role not in [Space.DRY_SOLID, Space.UNFINISHED, Space.SUPPORTED_VOID]:
			continue
		code = _retain_outside(check, handle, region)
		if code != &"":
			return code
	return _add_changed_cube(check.target, site, operation, room)


func _retain_outside(check: ColdCheck, handle: Vector2i, region: Owner.Region) -> StringName:
	"""A physical role change cannot remove an adjacent cube, floor datum, fitting or access region."""
	var slabs: Array[PackedInt32Array] = []
	if not _subtract(check, region.box, check.target, slabs):
		return check.error
	var code: StringName = _owner.stage_remove(_owner_token, handle)
	if code != &"":
		return code
	for slab: PackedInt32Array in slabs:
		region.box = slab
		var added: Owner.Result = _owner.stage_add(_owner_token, region)
		if not added.ok():
			return added.error
	return &""


func _add_changed_cube(box: PackedInt32Array, site: Vector2i, operation: int, room: Vector2i) -> StringName:
	"""Completed void retains its real Room/floor identity; actual backfill becomes World-owned matter."""
	var region: Owner.Region = Owner.Region.new()
	region.box = box
	var floor_region: Owner.Region = Owner.Region.new()
	var code: StringName = _room_floor_into(site, room, floor_region)
	if code != &"":
		return code
	region.level = floor_region.level
	if operation == Contract.OP_BACKFILL_CLOSE:
		region.owner = _domain._world
		region.role = Space.DRY_SOLID
	else:
		region.owner = room
		region.role = Space.UNFINISHED if operation == Contract.OP_CUT else Space.SUPPORTED_VOID
		region.section = _bindings.floor_section(site, room)
	return _owner.stage_add(_owner_token, region).error


func _room_floor_into(site: Vector2i, room: Vector2i, floor_region: Owner.Region) -> StringName:
	"""Metadata is bound to the exact actual Room generation; an absent floor never guesses level zero."""
	var section: Vector2i = _bindings.floor_section(site, room)
	if _owner.region_into(section, floor_region) != &"" or floor_region.role != Space.FLOOR_DATUM \
			or floor_region.owner != room or floor_region.claim_kind != Owner.CLAIM_NONE:
		return &"SPACE_SECTION_MISSING"
	return &""


func _final_preflight(check: ColdCheck, site: Vector2i, operation: int, stage: int,
		room: Vector2i) -> StringName:
	"""No source, exact operation, static qualification or companion candidate may drift before payment."""
	if _bindings.qualification_revision() != check.qualification_revision \
			or check.snapshot.revision != _owner.revision() or _next_i64[QUALIFICATION_REVISION] < 1:
		return &"SPACE_GEOMETRY_STALE"
	var code: StringName = _bindings.cold_operation_refusal(_cold_token)
	if code == &"":
		code = _context_refusal(_physical().origin_of(site), operation, room)
	if code == &"":
		code = _phase_refusal(site, operation, stage)
	if code == &"":
		code = _owner.prepared_refusal(_owner_token)
	if code == &"":
		code = _bindings.prepared_refusal(_companion_token)
	return code


func _failed_prepare(code: StringName) -> StringName:
	"""Local failure cleans its own scratch even if the caller never invokes the later discard hook."""
	_discard_prepared(false) # The caller's ColdCheck is still alive until _run_cold_operation returns here.
	return code


func discard_transition(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> void:
	"""Only the exact prepared transition may discard it; paid geometry and lasting claims remain."""
	if _candidate_matches(origin, operation, stage, room):
		_discard_prepared()


func _discard_prepared(release_lease: bool = true) -> void:
	"""Drop transient companions/owner staging and return a reserved unused cache row exactly once."""
	if _companion_token > 0:
		_bindings.discard_companions(_companion_token)
	if _owner_token != 0:
		_owner.abort(_owner_token)
	if _new_cache_row:
		_heap_push(_cache_row)
	_reset_candidate()
	if release_lease:
		_release_cold()


func publish_transition(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> void:
	"""Publish only inside the exact actual Sites callback after its physical owner transaction commits."""
	var sites: Sites = _physical()
	if not _candidate_matches(origin, operation, stage, room) or sites == null \
			or not sites.is_publishing_spatial_transition(origin, operation, stage, room, self):
		return
	if _geometry_changed:
		_owner.publish(_owner_token)
	else:
		_owner.abort(_owner_token)
	_bindings.publish_companions(_companion_token)
	if stage == Contract.STAGE_START:
		_publish_cache_row()
	elif _cache_row != NO_ROW:
		_release_cache_row()
	_reset_candidate()
	_release_cold()


func _candidate_matches(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> bool:
	"""A distinct origin, operation, stage or reused Room cannot publish or discard another candidate."""
	return _stage != -1 and _stage == stage and _next_i32[OPERATION] == operation \
		and _next_i32[ROOM_SLOT] == room.x and _next_i32[ROOM_GENERATION] == room.y \
		and _next_i32[ORIGIN_X] == origin.x and _next_i32[ORIGIN_Y] == origin.y and _next_i32[ORIGIN_Z] == origin.z


func _reset_candidate() -> void:
	"""Candidate controls are not entitlements and never survive a completed operation boundary."""
	_stage = -1
	_owner_token = 0
	_companion_token = 0
	_cache_row = NO_ROW
	_cache_position = NO_ROW
	_new_cache_row = false
	_geometry_changed = false
	_next_i32.fill(0)
	_next_i64.fill(0)


static func _started_phase(operation: int) -> int:
	"""The actual Sites START publication uses these fixed physical phases, independent of WU."""
	match operation:
		Contract.OP_BRACE:
			return Sites.BRACING
		Contract.OP_CUT:
			return Sites.CUTTING
		Contract.OP_FINISH:
			return Sites.FINISHING
	return Sites.CLOSING


func invalidate_proofs() -> StringName:
	"""A completed load or changed qualification pack must explicitly discard all derived old proofs."""
	if _ready_error != &"" or _stage != -1 or _owner.has_prepared() or _cold_token != 0:
		return &"SPACE_TRANSITION_BUSY"
	_clear_cache()
	return &""


func refresh_static_proof(site: Vector2i) -> StringName:
	"""Cold revalidation recovers funded work after revision/load changes; it publishes no physical state."""
	if _cold_token != 0:
		return &"SPACE_TRANSITION_BUSY"
	var code: StringName = _refresh_context_refusal(site)
	if code != &"":
		return code
	var operation: int = _operation_number.value
	var room: Vector2i = _physical().room_of(site)
	var project: Vector2i = _physical().project_of(site)
	code = _begin_cold(site, operation, Contract.STAGE_WORK)
	if code != &"":
		return code
	var check: ColdCheck = ColdCheck.new()
	code = _cold_refusal(check, site, operation, Contract.STAGE_WORK, room)
	if code == &"":
		code = _refresh_proof_from_check(check, site, operation, room, project)
	check = null
	_release_cold()
	return code


func _refresh_proof_from_check(check: ColdCheck, site: Vector2i, operation: int,
		room: Vector2i, project: Vector2i) -> StringName:
	"""Replace the bounded proof only after fresh actual identity and retained lease checks."""
	var code: StringName = _bindings.cold_operation_refusal(_cold_token)
	if code == &"":
		code = _refresh_context_refusal(site)
	if code != &"" or _operation_number.value != operation or _physical().project_of(site) != project \
			or _physical().room_of(site) != room:
		return code if code != &"" else &"SPACE_PHASE_STALE"
	if check.snapshot.revision != _owner.revision() or check.qualification_revision != _bindings.qualification_revision():
		return &"SPACE_GEOMETRY_STALE"
	code = _reserve_candidate(site, operation, Contract.STAGE_START, room)
	if code != &"":
		return code
	_next_i64[GEOMETRY_REVISION] = check.snapshot.revision
	_next_i64[QUALIFICATION_REVISION] = check.qualification_revision
	_publish_cache_row()
	_reset_candidate()
	return &""


func _refresh_context_refusal(site: Vector2i) -> StringName:
	"""Only an actual already funded phase may gain derived static proof without a physical callback."""
	var sites: Sites = _physical()
	if _ready_error != &"" or sites == null or not sites.is_live_site(site) \
			or not sites.operation_into(site, _operation_number):
		return &"SPACE_PHASE_STALE"
	if _stage != -1 or _owner.has_prepared():
		return &"SPACE_TRANSITION_BUSY"
	var operation: int = _operation_number.value
	var code: StringName = _context_refusal(sites.origin_of(site), operation, sites.room_of(site))
	if code != &"":
		return code
	if not sites.phase_into(site, _phase_number) or _phase_number.value != _started_phase(operation) \
			or not _construction.phase_into(sites.project_of(site), _phase_number) \
			or _phase_number.value not in [Construction.PHASE_WORKING, Construction.PHASE_WORK_DONE] \
			or sites.job_of(site) == NULL_REF:
		return &"SPACE_PHASE_NOT_FUNDED"
	return &""


func _clear_cache() -> void:
	"""Rebuild canonical empty derived storage; no geometry, paid history or claim is modified."""
	_present.fill(0)
	_proof_i32.fill(0)
	_proof_i64.fill(0)
	_ordered.fill(NO_ROW)
	for row: int in _capacity:
		_free[row] = row
	_count = 0
	_free_count = _capacity
	_reset_candidate()


func _lower_bound(site_slot: int) -> int:
	"""A bounded binary index finds a site's proof without resident-tick scans or allocation."""
	var low: int = 0
	var high: int = _count
	while low < high:
		@warning_ignore("integer_division") var middle: int = low + (high - low) / 2
		if _proof_i32[_ordered[middle] * I32_FIELDS + SITE_SLOT] < site_slot:
			low = middle + 1
		else:
			high = middle
	return low


func _publish_cache_row() -> void:
	"""Copy the precomputed exact START proof into its already reserved row without fallible work."""
	for column: int in I32_FIELDS:
		_proof_i32[_cache_row * I32_FIELDS + column] = _next_i32[column]
	for column: int in I64_FIELDS:
		_proof_i64[_cache_row * I64_FIELDS + column] = _next_i64[column]
	if _new_cache_row:
		for cursor: int in range(_count, _cache_position, -1):
			_ordered[cursor] = _ordered[cursor - 1]
		_ordered[_cache_position] = _cache_row
		_count += 1
	_present[_cache_row] = 1


func _release_cache_row() -> void:
	"""Terminal publication retires only its exact derived proof; future phases never inherit it."""
	_present[_cache_row] = 0
	for column: int in I32_FIELDS:
		_proof_i32[_cache_row * I32_FIELDS + column] = 0
	for column: int in I64_FIELDS:
		_proof_i64[_cache_row * I64_FIELDS + column] = 0
	for cursor: int in range(_cache_position, _count - 1):
		_ordered[cursor] = _ordered[cursor + 1]
	_count -= 1
	_ordered[_count] = NO_ROW
	_heap_push(_cache_row)


func _heap_pop() -> int:
	"""Reserve the lowest free cache row before any physical mutation."""
	var row: int = _free[0]
	_free_count -= 1
	var value: int = _free[_free_count]
	var at: int = 0
	while at * 2 + 1 < _free_count:
		var child: int = at * 2 + 1
		if child + 1 < _free_count and _free[child + 1] < _free[child]:
			child += 1
		if value <= _free[child]:
			break
		_free[at] = _free[child]
		at = child
	if at < _free_count:
		_free[at] = value
	_free[_free_count] = NO_ROW
	return row


func _heap_push(row: int) -> void:
	"""Return one reserved or retired row without allocating, publishing geometry or changing identity."""
	var at: int = _free_count
	_free_count += 1
	while at > 0:
		@warning_ignore("integer_division") var parent: int = (at - 1) / 2
		if _free[parent] <= row:
			break
		_free[at] = _free[parent]
		at = parent
	_free[at] = row
