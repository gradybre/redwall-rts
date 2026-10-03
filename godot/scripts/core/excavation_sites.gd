extends "res://scripts/core/excavation_contract.gd"
## ECON-001/003/005: permanent physical quantum history, paid phases and actual owner bindings.
## Sparse permanent records share one immutable lattice; no reset/retire erases physical history.
## This owner does not authorize geometry. The bound SpatialAuthority refuses until UG08/09
## provide actual dry/support/contact/occupancy/route/topology proofs.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NO_ROW: int = -1
const SITE_GENERATION: int = 1
## Engineering envelope only: caller chooses a qualified smaller budget; history never evicts.
const MAX_SITE_ARENA_BYTES: int = 8388608
const SITE_RECORD_BYTES: int = 113
const FIXED_PACKED_BYTES: int = Jobs.JOB_CAPACITY * 4 + Work.RESIDENT_CAPACITY * 8 + 16
## floor((8388608 - 36880) / 113), pinned against both this row and the next row in tests.
const MAX_SITE_CAPACITY: int = 73909
const MAX_EARNED_CAPACITY: int = MAX_SITE_CAPACITY * Contract.OP_COUNT
## Separate ASCII-ordered physical phase domain; BuildingState is unchanged.
const BACKFILLED: int = 0
const BRACED: int = 1
const BRACING: int = 2
const CLOSING: int = 3
const CUTTING: int = 4
const FINISHING: int = 5
const OPEN_UNFINISHED: int = 6
const SOLID: int = 7
const SUPPORTED_VOID: int = 8
const REFUSE_SITE: StringName = &"EXCAVATION_SITE_IDENTITY"
const REFUSE_DOMAIN: StringName = &"EXCAVATION_WORLD_DOMAIN"
const REFUSE_SITE_CAPACITY: StringName = &"EXCAVATION_PHYSICAL_HISTORY_CAPACITY"
const REFUSE_OVERLAP: StringName = &"EXCAVATION_SITE_ALREADY_OWNED"
const REFUSE_PHASE: StringName = &"EXCAVATION_PHYSICAL_PHASE"
const REFUSE_JOB: StringName = &"EXCAVATION_JOB_BINDING"
const REFUSE_WORKER: StringName = &"EXCAVATION_WORKER_BINDING"
const REFUSE_CHILD: StringName = &"EXCAVATION_CHILD_FORBIDDEN"
const REFUSE_BUILDER_CAP: StringName = &"EXCAVATION_PROJECT_BUILDER_CAP"
const REFUSE_OUTPUT: StringName = &"SPOIL_OUTPUT_BLOCKED"
const REFUSE_DELIVERY: StringName = &"EXCAVATION_DELIVERY_OWNERSHIP"

var _construction: Construction = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _jobs: Jobs = null
var _work: Work = null
var _funding: Funding = null
var _space: WeakRef = null
var _domain: Domain = Domain.new()
var _ready_error: StringName = REFUSE_DOMAIN
var _capacity: int = 0
var _earned_capacity: int = 0
var _count: int = 0
var _domain_capacity: int = 0
var _site_key: PackedInt64Array = PackedInt64Array()
var _ordered_key: PackedInt64Array = PackedInt64Array()
var _ordered_row: PackedInt32Array = PackedInt32Array()
var _virgin_sourced_milli: int = 0
var _initial_earth_milli: int = 0
var _completed_braces: int = 0
var _funded_braces: int = 0
var _returned_brace_milli: int = 0
var _salvaged_braces: int = 0
var _present: PackedByteArray = PackedByteArray()
var _phase: PackedByteArray = PackedByteArray()
var _installed: PackedByteArray = PackedByteArray()
var _ever_cut: PackedByteArray = PackedByteArray()
var _closure_before: PackedByteArray = PackedByteArray()
var _embedded_milli: PackedInt64Array = PackedInt64Array()
var _earned_mwu: PackedInt64Array = PackedInt64Array()
var _room_slot: PackedInt32Array = PackedInt32Array()
var _room_generation: PackedInt32Array = PackedInt32Array()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _operation: PackedInt32Array = PackedInt32Array()
var _job_slot: PackedInt32Array = PackedInt32Array()
var _job_generation: PackedInt32Array = PackedInt32Array()
var _output_slot: PackedInt32Array = PackedInt32Array()
var _output_generation: PackedInt32Array = PackedInt32Array()
var _promotion_tile: PackedInt32Array = PackedInt32Array()
var _job_site: PackedInt32Array = PackedInt32Array()
var _worker_site: PackedInt32Array = PackedInt32Array()
var _worker_generation: PackedInt32Array = PackedInt32Array()
## A permit exists only on the owner's synchronous call stack, never as a saved clearance flag.
var _permit_project: Vector2i = NULL_REF
var _permit_action: int = -1
var _candidate_row: int = -1
var _candidate_stage: int = -1
## Same-call-stack attestation only; never saved or sufficient before physical commit.
var _publishing_spatial: bool = false
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _other_math: IntMath.IntResult = IntMath.IntResult.new()
var _delivery_totals: PackedInt64Array = PackedInt64Array()


func _init(construction: Construction, inventory: Inventory, pool: Reservations,
		items: Items, jobs: Jobs, work: Work, spatial: SpatialAuthority,
		receipt_capacity: int, physical_site_capacity: int) -> void:
	"""Bind one world and its explicit sparse history budget; this is not a room-count policy."""
	_construction = construction
	_inventory = inventory
	_pool = pool
	_items = items
	_capacity = clampi(physical_site_capacity, 0, MAX_SITE_CAPACITY)
	var earned_request: int = _capacity * OP_COUNT
	_earned_capacity = clampi(earned_request, 0, MAX_EARNED_CAPACITY)
	_jobs = jobs
	_work = work
	_ready_error = _initialization_refusal(spatial, receipt_capacity, physical_site_capacity)
	if _ready_error != &"":
		return
	_space = weakref(spatial)
	_allocate_columns()
	_funding = Funding.new(construction, inventory, pool, items, receipt_capacity)
	_initial_earth_milli = inventory.total_live_milli(items.compiled_id(&"excavated_earth"))
	_publish_owner_bindings()


func _publish_owner_bindings() -> void:
	"""Install preflighted world wiring only after the complete owner set and budgets qualify."""
	var pool_bound: Inventory.OpResult = _pool.bind_inventory(_inventory)
	assert(pool_bound.ok, "preflighted Reservations composition cannot fail synchronously")
	var bound: Construction.OpResult = _construction.bind_excavation_authority(self)
	assert(bound.ok, "preflighted Construction binding cannot fail synchronously")
	var work_bound: Work.OpResult = _work.bind_excavation_authority(self)
	assert(work_bound.ok, "preflighted Work binding cannot fail synchronously")


func _initialization_refusal(spatial: SpatialAuthority, receipts: int, sites: int) -> StringName:
	"""Resolve every budget/domain/binding refusal before allocating or wiring either owner."""
	if spatial == null or _construction == null or _inventory == null or _pool == null \
			or _items == null or _jobs == null or _work == null:
		return REFUSE_AUTHORITY
	if sites <= 0 or sites > MAX_SITE_CAPACITY:
		return REFUSE_SITE_CAPACITY
	if not Funding.valid_receipt_budget(receipts, _pool):
		return Funding.REFUSE_RECEIPTS
	if _composition_refusal() != &"":
		return REFUSE_AUTHORITY
	if _construction.excavation_binding_refusal(self) != &"" or _work.excavation_binding_refusal(self) != &"":
		return REFUSE_AUTHORITY
	return &"" if _read_domain(spatial) and _valid_domain() else REFUSE_DOMAIN


func _composition_refusal() -> StringName:
	"""Typed handles cannot prove that otherwise identical owners belong to the same world."""
	if _construction.directory() != _jobs.directory() or _work.jobs() != _jobs:
		return REFUSE_AUTHORITY
	if not _items.registered_into(_inventory) or _pool.composition_refusal(_inventory) != &"":
		return REFUSE_AUTHORITY
	if _work.gear() == null or not _work.gear().equipment_binding_matches(
			_inventory, _jobs.directory(), _work.residents()):
		return REFUSE_AUTHORITY
	return &""


func _read_domain(spatial: SpatialAuthority) -> bool:
	"""Copy the descriptor so even an adapter retaining its output object cannot move this datum."""
	var described: Domain = Domain.new()
	if not spatial.domain_into(described):
		return false
	_domain.world_ref = described.world_ref
	_domain.datum_u = described.datum_u
	_domain.minimum_quantum = described.minimum_quantum
	_domain.size_quanta = described.size_quanta
	return true


func _valid_domain() -> bool:
	"""Validate integer dimensions and every extreme world coordinate before allocation."""
	if not _jobs.directory().is_valid_of_kind(_domain.world_ref, Directory.KIND_WORLD):
		return false
	var size: Vector3i = _domain.size_quanta
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return false
	if not IntMath.checked_mul_into(size.x, size.y, _math) \
			or not IntMath.checked_mul_into(_math.value, size.z, _math):
		return false
	_domain_capacity = _math.value
	if _capacity <= 0 or _capacity > _domain_capacity:
		return false
	if not IntMath.checked_mul_into(_capacity, OP_COUNT, _math) or not IntMath.fits_int32(_math.value):
		return false
	for axis: int in 3:
		var minimum: int = int(_domain.datum_u[axis]) + int(_domain.minimum_quantum[axis]) * QUANTUM_SIDE_U
		var maximum: int = minimum + int(size[axis]) * QUANTUM_SIDE_U
		if not IntMath.fits_int32(minimum) or not IntMath.fits_int32(maximum):
			return false
	return true


func _allocate_columns() -> void:
	"""Allocate the finite sparse record budget; untouched world cells consume no record rows."""
	for column: PackedByteArray in [_present, _phase, _installed, _ever_cut, _closure_before]:
		column.resize(_capacity)
	for column: PackedInt32Array in [_room_slot, _room_generation, _project_slot,
			_project_generation, _operation, _job_slot, _job_generation, _output_slot,
			_output_generation, _promotion_tile]:
		column.resize(_capacity)
	for column: PackedInt32Array in [_room_slot, _project_slot, _operation, _job_slot,
			_output_slot, _promotion_tile]:
		column.fill(-1)
	_phase.fill(SOLID)
	_closure_before.fill(SOLID)
	_embedded_milli.resize(_capacity)
	_earned_mwu.resize(_earned_capacity)
	_job_site.resize(Jobs.JOB_CAPACITY)
	_job_site.fill(-1)
	_worker_site.resize(Work.RESIDENT_CAPACITY)
	_worker_site.fill(-1)
	_worker_generation.resize(Work.RESIDENT_CAPACITY)
	_delivery_totals.resize(2)
	_site_key.resize(_capacity)
	_ordered_key.resize(_capacity)
	_ordered_row.resize(_capacity)
	_site_key.fill(-1)
	_ordered_key.fill(-1)
	_ordered_row.fill(-1)


func initialization_refusal() -> StringName:
	"""An invalid world binding has no permissive default and cannot open paid work."""
	return _ready_error


func construction_owner() -> Construction:
	"""Return the exact successfully bound owner, never an equal-numbered foreign world."""
	return _construction if _ready_error == &"" else null


func jobs_owner() -> Jobs:
	"""Borrow the exact initialized Job store; identity alone grants no worker or contact permission."""
	return _jobs if _ready_error == &"" else null


func funding_owner(construction: Construction, inventory: Inventory, pool: Reservations,
		items: Items, jobs: Jobs, work: Work) -> Funding:
	"""Share this one receipt arena only with the exact still-valid composed world owners."""
	if _ready_error != &"" or construction != _construction or inventory != _inventory \
			or pool != _pool or items != _items or jobs != _jobs or work != _work:
		return null
	if _composition_refusal() != &"" or not _world_is_live() \
			or not _funding.composition_matches(construction, inventory, pool, items):
		return null
	return _funding


func bound_spatial_authority() -> Contract.SpatialAuthority:
	"""Expose the live typed weak target for composition checks, without granting clearance."""
	return _spatial() if _ready_error == &"" else null


func is_bound_spatial(candidate: Contract.SpatialAuthority) -> bool:
	"""Prove actual live owner identity; null, refused initialization and expired wiring fail closed."""
	return candidate != null and bound_spatial_authority() == candidate


func is_publishing_spatial_transition(origin_u: Vector3i, operation: int, stage: int,
		room: Vector2i, candidate: Contract.SpatialAuthority) -> bool:
	"""Attest this exact synchronous committed callback; a prepared candidate alone is insufficient."""
	if not _publishing_spatial or not is_bound_spatial(candidate):
		return false
	if _candidate_row < 0 or _candidate_row >= _count or _candidate_stage != stage:
		return false
	return _operation[_candidate_row] == operation and _room(_candidate_row) == room \
		and origin_of(Vector2i(_candidate_row, SITE_GENERATION)) == origin_u


func _spatial() -> SpatialAuthority:
	"""Read the live actual space owner; a released binding is a refusal, never clearance."""
	return _space.get_ref() as SpatialAuthority if _space != null else null


func claim_quantum(origin_u: Vector3i, room: Vector2i) -> Construction.OpResult:
	"""All tools share immutable physical keys; history-capacity refusal precedes any paid work."""
	var spatial: SpatialAuthority = _spatial()
	if _ready_error != &"" or spatial == null or not _world_is_live():
		return _refuse(REFUSE_AUTHORITY)
	var key: int = _key_at(origin_u)
	if key == NO_ROW:
		return _refuse(REFUSE_DOMAIN)
	var code: StringName = spatial.room_refusal(room)
	if code != &"":
		return _refuse(code)
	var index: int = _key_lower_bound(key)
	var row: int = _ordered_row[index] if index < _count and _ordered_key[index] == key else NO_ROW
	if row != NO_ROW and _room(row) != NULL_REF and _room(row) != room:
		return _refuse(REFUSE_OVERLAP)
	if row == NO_ROW:
		if _count == _capacity:
			return _refuse(REFUSE_SITE_CAPACITY)
		row = _claim_key(key, index)
	_room_slot[row] = room.x
	_room_generation[row] = room.y
	return Construction.OpResult.new(true, &"", row, Vector2i(row, SITE_GENERATION))


func _key_at(origin_u: Vector3i) -> int:
	"""Rank an exact absolute world origin on the immutable lattice without rounding or allocation."""
	var local: Vector3i = Vector3i.ZERO
	for axis: int in 3:
		var delta: int = int(origin_u[axis]) - int(_domain.datum_u[axis])
		if delta % QUANTUM_SIDE_U != 0:
			return NO_ROW
		@warning_ignore("integer_division") var cell: int = delta / QUANTUM_SIDE_U - _domain.minimum_quantum[axis]
		if cell < 0 or cell >= _domain.size_quanta[axis]:
			return NO_ROW
		local[axis] = cell
	return (int(local.y) * _domain.size_quanta.z + local.z) * _domain.size_quanta.x + local.x


func _key_lower_bound(key: int) -> int:
	"""Binary search the derived sorted physical-key index; no per-tick dictionary allocations."""
	var low: int = 0
	var high: int = _count
	while low < high:
		@warning_ignore("integer_division") var middle: int = low + (high - low) / 2
		if _ordered_key[middle] < key:
			low = middle + 1
		else:
			high = middle
	return low


func _claim_key(key: int, index: int) -> int:
	"""Cold admission inserts a new permanent record; no retirement or eviction recycles history."""
	var row: int = _count
	for cursor: int in range(_count, index, -1):
		_ordered_key[cursor] = _ordered_key[cursor - 1]
		_ordered_row[cursor] = _ordered_row[cursor - 1]
	_ordered_key[index] = key
	_ordered_row[index] = row
	_site_key[row] = key
	_present[row] = 1
	_count += 1
	return row


func origin_of(site: Vector2i) -> Vector3i:
	"""Read the original physical key; callers first validate the generation-qualified site."""
	if not is_live_site(site):
		return Vector3i.ZERO
	var x: int = _site_key[site.x] % _domain.size_quanta.x
	@warning_ignore("integer_division") var rest: int = _site_key[site.x] / _domain.size_quanta.x
	var z: int = rest % _domain.size_quanta.z
	@warning_ignore("integer_division") var y: int = rest / _domain.size_quanta.z
	var coordinate: Vector3i = Vector3i(x, y, z)
	for axis: int in 3:
		coordinate[axis] = int(_domain.datum_u[axis]) \
			+ (int(coordinate[axis]) + int(_domain.minimum_quantum[axis])) * QUANTUM_SIDE_U
	return coordinate


func is_live_site(site: Vector2i) -> bool:
	"""Physical history rows never recycle into another quantum or project identity."""
	return site.x >= 0 and site.x < _count and site.y == SITE_GENERATION and _present[site.x] == 1


func site_at(origin_u: Vector3i) -> Vector2i:
	"""Find an existing exact quantum without claiming or rounding new geometry."""
	if _ready_error != &"" or not _world_is_live():
		return NULL_REF
	var key: int = _key_at(origin_u)
	if key == NO_ROW:
		return NULL_REF
	var index: int = _key_lower_bound(key)
	return Vector2i(_ordered_row[index], SITE_GENERATION) \
		if index < _count and _ordered_key[index] == key else NULL_REF


func room_of(site: Vector2i) -> Vector2i:
	"""Read the full current room generation; retired claims or expired authority return null."""
	if not is_live_site(site) or not _world_is_live() or _spatial() == null:
		return NULL_REF
	var room: Vector2i = _room(site.x)
	return room if _spatial().room_refusal(room) == &"" else NULL_REF


func project_of(site: Vector2i) -> Vector2i:
	"""Read only a currently live Construction generation belonging to this physical record."""
	if not is_live_site(site) or not _world_is_live():
		return NULL_REF
	var project: Vector2i = _project(site.x)
	return project if _construction.is_live_project(project) else NULL_REF


func operation_into(site: Vector2i, out: IntMath.IntResult) -> bool:
	"""No active phase is an explicit refusal, never an implicit brace operation."""
	if project_of(site) == NULL_REF or not valid_operation(_operation[site.x]):
		return out.refuse(REFUSE_PHASE)
	return out.succeed(_operation[site.x])


func job_of(site: Vector2i) -> Vector2i:
	"""Read the exact current live Job whose requester still names this site's paid project."""
	if project_of(site) == NULL_REF:
		return NULL_REF
	var job: Vector2i = _job(site.x)
	var row: int = _job_row(job)
	return job if row != NO_ROW and _jobs.requester_of(row) == _project(site.x) else NULL_REF


func open_phase(site: Vector2i, operation: int) -> Construction.OpResult:
	"""Price an actual site operation through Construction, using its retained physical work."""
	if _ready_error != &"":
		return _refuse(REFUSE_AUTHORITY)
	return _construction.open_excavation_phase(site, operation)


func project_open_refusal(site: Vector2i, operation: int) -> StringName:
	"""Check physical history and real geometry before a new phase identity is allocated."""
	if _ready_error != &"" or not is_live_site(site):
		return REFUSE_SITE
	if _project(site.x) != NULL_REF:
		return Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION
	if not valid_operation(operation) or not _operation_allowed(site.x, operation):
		return REFUSE_PHASE
	return _space_refusal(site.x, operation, STAGE_ADMIT)


func _operation_allowed(row: int, operation: int) -> bool:
	"""Only adopted physical transitions exist, including the never-opened support exception."""
	match operation:
		OP_BRACE:
			return _installed[row] == 0 and (_phase[row] == SOLID or _phase[row] == BACKFILLED or _phase[row] == BRACING)
		OP_CUT:
			return _installed[row] == 1 and (_phase[row] == BRACED or _phase[row] == CUTTING)
		OP_FINISH:
			return _installed[row] == 1 and (_phase[row] == OPEN_UNFINISHED or _phase[row] == FINISHING)
		OP_BACKFILL_CLOSE:
			return _installed[row] == 1 and (_phase[row] == OPEN_UNFINISHED or _phase[row] == FINISHING \
				or _phase[row] == SUPPORTED_VOID or (_phase[row] == CLOSING and _closure_before[row] != BRACED \
				and _closure_before[row] != CUTTING))
		OP_UNOPENED_SUPPORT_CLOSE:
			return _installed[row] == 1 and (_phase[row] == BRACED or _phase[row] == CUTTING \
				or (_phase[row] == CLOSING and (_closure_before[row] == BRACED or _closure_before[row] == CUTTING)))
	return false


func remaining_work_into(site: Vector2i, operation: int, out: IntMath.IntResult) -> bool:
	"""Retained work belongs to the physical key and cannot be reset by a new project ID."""
	if not is_live_site(site) or not valid_operation(operation):
		return out.refuse(REFUSE_SITE)
	return out.succeed(work_mwu(operation) - _earned_mwu[site.x * OP_COUNT + operation])


func attach_project(site: Vector2i, operation: int, project: Vector2i) -> void:
	"""Publish Construction's allocated full identity after its own preflight succeeded."""
	_project_slot[site.x] = project.x
	_project_generation[site.x] = project.y
	_operation[site.x] = operation


func mutation_refusal(project: Vector2i, action: int) -> StringName:
	"""Generic Construction/Funding calls cannot impersonate a completed physical transaction."""
	return &"" if project == _permit_project and action == _permit_action else Construction.REFUSE_COORDINATOR_ONLY


func _allow(project: Vector2i, action: int) -> void:
	"""Open a synchronous owner publication window after all failing work has succeeded."""
	_permit_project = project
	_permit_action = action


func _disallow() -> void:
	"""No mutation permission survives the current call stack or a blocked retry."""
	_permit_project = NULL_REF
	_permit_action = -1


func bind_job(site: Vector2i, job: Vector2i) -> Construction.OpResult:
	"""Bind a real BUILD Job whose requester and exact remaining work name this paid phase."""
	var code: StringName = _context_refusal(site)
	if code != &"":
		return _refuse(code)
	var row: int = _job_row(job)
	if row == NO_ROW or job.x >= _pool.job_capacity() or _job_slot[site.x] != -1:
		return _refuse(REFUSE_JOB)
	if _jobs.requester_of(row) != _project(site.x) or _jobs.is_coordinator(row) or _jobs.is_member(row):
		return _refuse(REFUSE_JOB)
	if not _jobs.kind_into(row, _math) or _math.value != Jobs.JOB_KIND_BUILD:
		return _refuse(REFUSE_JOB)
	_construction.remaining_mwu_into(_project(site.x), _math)
	if not _jobs.remaining_mwu_into(row, _other_math) or _math.value != _other_math.value:
		return _refuse(REFUSE_JOB)
	if not _jobs.tool_gate_into(row, _math) or _math.value == Jobs.GATE_NOT_REQUIRED:
		return _refuse(Work.REFUSE_TOOL_NOT_CLAIMED)
	_job_slot[site.x] = job.x
	_job_generation[site.x] = job.y
	_job_site[row] = site.x
	return _ok(site)


func bind_material_container(site: Vector2i, container: Vector2i) -> Construction.OpResult:
	"""Bind actual delivered stock capacity only after the space owner validates its contact."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	if _construction.has_work_begun(_project(site.x)) or not _inventory.container_reachable(container):
		return _refuse(REFUSE_DELIVERY)
	code = _spatial().material_refusal(origin_of(site), _room(site.x), container, _job(site.x))
	if code != &"":
		return _refuse(code)
	_allow(_project(site.x), ACTION_CONTAINER)
	var result: Construction.OpResult = _construction.set_material_container(_project(site.x), container)
	_disallow()
	return result


func bind_output(site: Vector2i, container: Vector2i, promotion_tile: int = -1) -> Construction.OpResult:
	"""Bind finite local output or a real first-cut staging container held by the space owner."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	if _construction.has_work_begun(_project(site.x)) or not _inventory.container_reachable(container):
		return _refuse(REFUSE_OUTPUT)
	code = _funding.output_placement_refusal(container, promotion_tile)
	if code != &"":
		return _refuse(code)
	code = _spatial().output_refusal(origin_of(site), _operation[site.x], _room(site.x),
		container, _job(site.x), promotion_tile)
	if code != &"":
		return _refuse(code)
	_output_slot[site.x] = container.x
	_output_generation[site.x] = container.y
	_promotion_tile[site.x] = promotion_tile
	return _ok(site)


func record_deliveries(site: Vector2i) -> Construction.OpResult:
	"""Derive delivery increments from actual owned local claims, never a requested quantity."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	code = _read_deliveries(site)
	if code != &"":
		return _refuse(code)
	var project: Vector2i = _project(site.x)
	_allow(project, ACTION_DELIVER)
	for line: int in input_count(_operation[site.x]):
		_construction.delivered_milli_into(project, line, _math)
		var delta: int = _delivery_totals[line] - _math.value
		if delta > 0:
			_construction.deliver_material(project, line, delta)
	_disallow()
	return _ok(site)


func _read_deliveries(site: Vector2i) -> StringName:
	"""Preflight every bill line before publishing any increment into Construction."""
	var project: Vector2i = _project(site.x)
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_AWAITING_MATERIALS:
		return Construction.REFUSE_WRONG_PHASE
	var container: Vector2i = _construction.material_container_ref_of(project)
	var code: StringName = _spatial().material_refusal(origin_of(site), _room(site.x), container, _job(site.x))
	if code != &"":
		return code
	_delivery_totals.fill(0)
	code = _sum_delivery_claims(site.x, container)
	if code != &"":
		return code
	for line: int in input_count(_operation[site.x]):
		_construction.delivered_milli_into(project, line, _math)
		if _delivery_totals[line] < _math.value or _delivery_totals[line] > input_milli(_operation[site.x], line):
			return REFUSE_DELIVERY
	return &""


func _sum_delivery_claims(row: int, container: Vector2i) -> StringName:
	"""Only this phase Job's exact input purpose at the actual bound material contact counts."""
	var claim: int = _pool.first_job_row(_job(row))
	while claim != Reservations.NULL_ROW:
		var lot: Vector2i = _pool.row_lot_ref(claim)
		if not _pool.row_purpose_into(claim, _math) or _math.value != Reservations.PURPOSE_EXCAVATION_INPUT:
			return REFUSE_DELIVERY
		if not _inventory.is_lot_valid(lot) or _inventory.lot_container(lot) != container:
			return REFUSE_DELIVERY
		var line: int = _input_line(_operation[row], _inventory.lot_item_id(lot))
		if line == NO_ROW:
			return REFUSE_DELIVERY
		if not IntMath.checked_add_into(_delivery_totals[line], _pool.row_quantity_milli(claim), _math):
			return Inventory.REFUSE_OVERFLOW
		_delivery_totals[line] = _math.value
		claim = _pool.next_job_row(claim)
	return &""


func _input_line(operation: int, item: int) -> int:
	"""Resolve actual compiled item IDs against the authored phase keys."""
	for line: int in input_count(operation):
		if _items.compiled_id(input_key(operation, line)) == item:
			return line
	return NO_ROW


func bind_worker(site: Vector2i) -> Construction.OpResult:
	"""Register an actually assigned/equipped worker, with one face and four room-project workers."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	code = _worker_refusal(site.x, false)
	if code != &"":
		return _refuse(code)
	var worker: Vector2i = _jobs.worker_of(_job_row(_job(site.x)))
	var row: int = _jobs.directory().get_typed_row(worker)
	if _worker_site[row] == site.x and _worker_generation[row] == worker.y:
		return _ok(site)
	if _worker_site[row] != NO_ROW or _registered_worker_row(site.x) != NO_ROW:
		return _refuse(REFUSE_WORKER)
	if _room_worker_count(_room(site.x)) >= MAX_PROJECT_BUILDERS:
		return _refuse(REFUSE_BUILDER_CAP)
	_worker_site[row] = site.x
	_worker_generation[row] = worker.y
	return _ok(site)


func _room_worker_count(room: Vector2i) -> int:
	"""Cold scan of 512 allocated resident rows; the living cap remains 256, never per tick."""
	var count: int = 0
	for resident: int in Work.RESIDENT_CAPACITY:
		var site: int = _worker_site[resident]
		if site != NO_ROW and _room(site) == room:
			count += 1
	return count


func _worker_refusal(row: int, require_registered: bool) -> StringName:
	"""Read the actual Job worker, equipped Gear claim and legal dry work contact."""
	var job_row: int = _job_row(_job(row))
	var worker: Vector2i = _jobs.worker_of(job_row)
	if not _jobs.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return REFUSE_WORKER
	var resident: int = _jobs.directory().get_typed_row(worker)
	if _work.residents().ref_of(resident) != worker or _jobs.job_of(resident) != _job(row):
		return REFUSE_WORKER
	if _work.residents().life_stage_code_of(resident) == Residents.LIFE_STAGE_CHILD:
		return REFUSE_CHILD
	if require_registered and (_worker_site[resident] != row or _worker_generation[resident] != worker.y):
		return REFUSE_WORKER
	if not _jobs.tool_gate_into(job_row, _math) or _math.value != Jobs.GATE_SATISFIED:
		return Work.REFUSE_TOOL_NOT_CLAIMED
	var tool: Vector2i = _work.tool_lot_of(resident)
	if _work.tool_job_of(resident) != _job(row) or _work.gear() == null:
		return Work.REFUSE_TOOL_NOT_CLAIMED
	var gear_code: StringName = _work.gear().equipped_work_claim_refusal(tool, worker, _job(row))
	if gear_code == Gear.REFUSE_GEAR_CLAIM_MISMATCH:
		return Work.REFUSE_TOOL_CLAIM_STALE
	if gear_code != &"":
		return Work.REFUSE_TOOL_BROKEN
	return _spatial().worker_refusal(origin_of(Vector2i(row, SITE_GENERATION)),
		_operation[row], _room(row), _job(row), worker)


func begin_phase_work(site: Vector2i, now_tick: int) -> Construction.OpResult:
	"""Consume all real input claims once and reserve local output before productive work starts."""
	var code: StringName = _start_refusal(site)
	if code != &"":
		_discard_candidate()
		return _refuse(code)
	var project: Vector2i = _project(site.x)
	_allow(project, ACTION_WIP)
	var consumed: Inventory.OpResult = _funding.consume_to_wip(project, _job(site.x), now_tick, _output(site.x))
	_disallow()
	if not consumed.ok:
		_discard_candidate()
		return _refuse(consumed.error)
	if _operation[site.x] == OP_BRACE:
		_funded_braces += 1
	_allow(project, ACTION_BEGIN_WORK)
	var started: Construction.OpResult = _construction.begin_work(project)
	_disallow()
	assert(started.ok, "preflighted physical work start must not fail after WIP commits")
	_publish_start(site.x)
	return _ok(site)


func resume_phase_work(site: Vector2i) -> Construction.OpResult:
	"""Resume funded work after an actual worker/tool rebind; never consume the phase inputs twice."""
	var code: StringName = _productive_refusal(site.x) if is_live_site(site) else REFUSE_SITE
	if code != &"":
		return _refuse(code)
	code = _worker_refusal(site.x, true)
	if code != &"":
		return _refuse(code)
	var changed: Jobs.OpResult = _jobs.set_state(_job_row(_job(site.x)), Jobs.JOB_STATE_WORK)
	if not changed.ok:
		return _refuse(changed.error)
	_construction.set_assigned_count(_project(site.x), 1)
	return _ok(site)


func _start_refusal(site: Vector2i) -> StringName:
	"""Every refusal is resolved before the paid input/output transaction starts."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return code
	var project: Vector2i = _project(site.x)
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_READY:
		return Construction.REFUSE_WRONG_PHASE
	if _operation[site.x] == OP_BRACE and not IntMath.checked_mul_into(_funded_braces + 1, BRACE_WOOD_MILLI, _math):
		return Inventory.REFUSE_OVERFLOW
	code = _worker_refusal(site.x, true)
	if code != &"":
		return code
	if not _jobs.resident_may_work_into(_jobs.directory().get_typed_row(_jobs.worker_of(_job_row(_job(site.x)))), _math):
		return REFUSE_WORKER
	code = _space_refusal(site.x, _operation[site.x], STAGE_START)
	if code != &"":
		return code
	return _output_refusal(site.x)


func _publish_start(row: int) -> void:
	"""Publish support/entry state only after payment; a retained work-ready phase spends no tick."""
	var operation: int = _operation[row]
	if operation == OP_BACKFILL_CLOSE or operation == OP_UNOPENED_SUPPORT_CLOSE:
		if _phase[row] != CLOSING:
			_closure_before[row] = _phase[row]
		_phase[row] = CLOSING
	elif operation == OP_BRACE:
		_phase[row] = BRACING
	elif operation == OP_CUT:
		_phase[row] = CUTTING
	else:
		_phase[row] = FINISHING
	_construction.remaining_mwu_into(_project(row), _math)
	_jobs.set_state(_job_row(_job(row)), Jobs.JOB_STATE_COMPLETE if _math.value == 0 else Jobs.JOB_STATE_WORK)
	_construction.set_assigned_count(_project(row), 1)
	_publish_candidate(row, STAGE_START)


func _output_refusal(row: int) -> StringName:
	"""The actual local capacity/contact is rechecked at start, every work tick, and commit."""
	var mass: int = _funding.output_mass_g(_operation[row])
	if mass == 0:
		return &"" if _output(row) == NULL_REF else REFUSE_OUTPUT
	if mass < 0 or not _inventory.container_reachable(_output(row)):
		return REFUSE_OUTPUT
	var code: StringName = _funding.output_placement_refusal(_output(row), _promotion_tile[row])
	if code != &"":
		return code
	if _promotion_tile[row] >= 0 and not _staging_is_exact(row):
		return REFUSE_OUTPUT
	if _funding.is_funded(_project(row)) and _inventory.container_reserved_mass_g(_output(row)) < mass:
		return REFUSE_OUTPUT
	return _spatial().output_refusal(origin_of(Vector2i(row, SITE_GENERATION)),
		_operation[row], _room(row), _output(row), _job(row), _promotion_tile[row])


func _staging_is_exact(row: int) -> bool:
	"""A first-pile staging row is finite, empty, World-owned and held at the actual contact."""
	var output: Vector2i = _output(row)
	return _inventory.container_anchor_tile_into(output, _math) and _math.value == _promotion_tile[row] \
		and _inventory.container_owner(output) == _domain.world_ref \
		and _inventory.container_policy(output) == Inventory.UNSET_POLICY \
		and _inventory.container_max_mass_g(output) == Inventory.GROUND_PILE_MAX_MASS_G \
		and _inventory.container_filters(output) == Inventory.FILTERS_ACCEPT_ALL \
		and _inventory.container_lot_count(output) == 0


func work_tick_refusal(job: Vector2i) -> StringName:
	"""Even direct Work calls cannot bypass paid-phase pause, tool, ownership or spatial gates."""
	if _ready_error != &"":
		return REFUSE_AUTHORITY
	var job_row: int = _job_row(job)
	if job_row == NO_ROW:
		return &""  # Work's own stale-job gate supplies its established refusal.
	var row: int = _job_site[job_row]
	if row == NO_ROW:
		if _construction.purpose_into(_jobs.requester_of(job_row), _math) and _math.value == Construction.PURPOSE_EXCAVATION:
			return REFUSE_JOB
		return &""
	if _job(row) != job or _jobs.is_coordinator(job_row) or _jobs.is_member(job_row):
		return REFUSE_JOB
	var code: StringName = _productive_refusal(row)
	if code != &"":
		return code
	return _worker_refusal(row, true)


func _productive_refusal(row: int) -> StringName:
	"""Compare actual owner progress before Work touches any resident carry or resource."""
	var code: StringName = _bound_refusal(Vector2i(row, SITE_GENERATION))
	if code != &"":
		return code
	var project: Vector2i = _project(row)
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _funding.is_funded(project) or not _construction.phase_into(project, _math) \
			or _math.value != Construction.PHASE_WORKING:
		return Construction.REFUSE_WRONG_PHASE
	_construction.remaining_mwu_into(project, _math)
	_jobs.remaining_mwu_into(_job_row(_job(row)), _other_math)
	if _math.value != _other_math.value:
		return REFUSE_JOB
	code = _space_refusal(row, _operation[row], STAGE_WORK)
	return _output_refusal(row) if code == &"" else code


func accept_work_tick(job: Vector2i) -> void:
	"""Read actual accepted Job progress after Work's WU/XP/wear transaction succeeded."""
	if _ready_error != &"" or not _work.is_publishing_excavation_tick(job):
		return
	var job_row: int = _job_row(job)
	if job_row == NO_ROW or _job_site[job_row] == NO_ROW:
		return
	var row: int = _job_site[job_row]
	var project: Vector2i = _project(row)
	_construction.remaining_mwu_into(project, _math)
	_jobs.remaining_mwu_into(job_row, _other_math)
	var accepted: int = _math.value - _other_math.value
	if accepted <= 0:
		return
	_allow(project, ACTION_WORK)
	var applied: bool = _construction.add_work_mwu_into(project, accepted, _math)
	_disallow()
	assert(applied, "preflighted physical Work publication must not fail after Work commits")
	_earned_mwu[row * OP_COUNT + _operation[row]] = work_mwu(_operation[row]) - _math.value


func release_worker(site: Vector2i) -> Construction.OpResult:
	"""Release actual Gear/Work/Job ownership without touching retained physical work or WIP."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	var job_row: int = _job_row(_job(site.x))
	var worker: Vector2i = _jobs.worker_of(job_row)
	if worker == NULL_REF:
		return _ok(site) if _registered_worker_row(site.x) == NO_ROW else _refuse(REFUSE_WORKER)
	if not _jobs.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return _refuse(REFUSE_WORKER)
	var resident: int = _jobs.directory().get_typed_row(worker)
	if _worker_site[resident] != site.x or _worker_generation[resident] != worker.y:
		return _refuse(REFUSE_WORKER)
	if _work.tool_job_of(resident) != _job(site.x) or _jobs.job_of(resident) != _job(site.x):
		return _refuse(Work.REFUSE_TOOL_CLAIM_STALE)
	var released: Work.OpResult = _work.release_tool_claim(resident)
	if not released.ok:
		return _refuse(released.error)
	var detached: Jobs.OpResult = _jobs.release_worker(resident)
	assert(detached.ok, "preflighted worker departure must succeed after its tool claim releases")
	_worker_site[resident] = NO_ROW
	_worker_generation[resident] = 0
	_construction.set_assigned_count(_project(site.x), 0)
	return _ok(site)


func _registered_worker_row(row: int) -> int:
	"""Cold lifecycle check: an externally detached worker is diagnosed, never silently erased."""
	for resident: int in Work.RESIDENT_CAPACITY:
		if _worker_site[resident] == row:
			return resident
	return NO_ROW


func set_paused(site: Vector2i, paused: bool) -> Construction.OpResult:
	"""A held Construction phase also stops Work immediately and releases its actual worker."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	var changed: Construction.OpResult = _construction.set_paused(_project(site.x), paused)
	if not changed.ok or not paused:
		return changed
	return release_worker(site)


func settle_phase(site: Vector2i) -> Construction.OpResult:
	"""Commit actual output, physical history and staged topology once; retries spend no work."""
	var code: StringName = _settlement_refusal(site)
	if code != &"":
		_discard_candidate()
		return _refuse(code)
	var released: Construction.OpResult = release_worker(site)
	if not released.ok:
		_discard_candidate()
		return released
	var project: Vector2i = _project(site.x)
	var provenance: int = Catalog.PROVENANCE_EXCAVATION if _ever_cut[site.x] == 0 \
		else Catalog.PROVENANCE_BACKFILL_RECLAIM
	_allow(project, ACTION_OUTPUT)
	var settled: Inventory.OpResult = _funding.commit_outputs(project, provenance, _promotion_tile[site.x])
	_disallow()
	if not settled.ok:
		_discard_candidate()
		return _refuse(settled.error)
	_publish_physical_completion(site.x)
	_publish_candidate(site.x, STAGE_COMMIT)
	_retire_phase(site.x)
	return _ok(site)


func _settlement_refusal(site: Vector2i) -> StringName:
	"""No caller boolean can stand in for real funded WIP, completed work or safe topology."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return code
	var project: Vector2i = _project(site.x)
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_WORK_DONE \
			or not _funding.is_funded(project):
		return Construction.REFUSE_WRONG_PHASE
	if not _jobs.remaining_mwu_into(_job_row(_job(site.x)), _math) or _math.value != 0:
		return REFUSE_JOB
	if _pool.job_claim_count(_job(site.x)) != 0:
		return REFUSE_DELIVERY
	code = _retirement_jobs_refusal(site.x)
	if code != &"":
		return code
	if _operation[site.x] == OP_CUT and _embedded_milli[site.x] != (EARTH_MILLI if _ever_cut[site.x] == 1 else 0):
		return REFUSE_PHASE
	code = _space_refusal(site.x, _operation[site.x], STAGE_COMMIT)
	return _output_refusal(site.x) if code == &"" else code


func _publish_physical_completion(row: int) -> void:
	"""Only this post-Inventory-commit path changes installed support or geological earth."""
	match _operation[row]:
		OP_BRACE:
			_installed[row] = 1
			_completed_braces += 1
			_phase[row] = BRACED
		OP_CUT:
			if _ever_cut[row] == 0:
				_virgin_sourced_milli += EARTH_MILLI
				_ever_cut[row] = 1
			else:
				_embedded_milli[row] -= EARTH_MILLI
			_phase[row] = OPEN_UNFINISHED
		OP_FINISH:
			_phase[row] = SUPPORTED_VOID
		OP_BACKFILL_CLOSE, OP_UNOPENED_SUPPORT_CLOSE:
			_publish_closure(row)
	_earned_mwu[row * OP_COUNT + _operation[row]] = 0


func _publish_closure(row: int) -> void:
	"""Salvage exists only with paid backfill or the adopted never-opened solid exception."""
	if _operation[row] == OP_BACKFILL_CLOSE:
		_embedded_milli[row] = EARTH_MILLI
		for operation: int in OP_COUNT:
			_earned_mwu[row * OP_COUNT + operation] = 0
	_installed[row] = 0
	_salvaged_braces += 1
	_phase[row] = BACKFILLED if _embedded_milli[row] == EARTH_MILLI else SOLID
	_closure_before[row] = _phase[row]


func cancel_phase(site: Vector2i, refund_container: Vector2i) -> Construction.OpResult:
	"""Freeze work, release actual worker ownership, then settle the scoped current-phase refund."""
	var code: StringName = _bound_refusal(site)
	if code != &"":
		return _refuse(code)
	code = _cancel_refusal(site.x)
	if code != &"":
		_discard_candidate()
		return _refuse(code)
	var released: Construction.OpResult = release_worker(site)
	if not released.ok:
		_discard_candidate()
		return released
	var project: Vector2i = _project(site.x)
	_construction.phase_into(project, _math)
	if _math.value != Construction.PHASE_REFUNDING:
		_allow(project, ACTION_CANCEL)
		_construction.begin_refund(project)
		_disallow()
	code = _settle_refund(site, refund_container)
	if code != &"":
		_discard_candidate()
		return _refuse(code)
	_publish_candidate(site.x, STAGE_CANCEL)
	_retire_phase(site.x)
	return _ok(site)


func _cancel_refusal(row: int) -> StringName:
	"""Prove no late requester Job will be orphaned before freezing or refunding this phase."""
	var code: StringName = _retirement_jobs_refusal(row)
	return _space_refusal(row, _operation[row], STAGE_CANCEL) if code == &"" else code


func _retirement_jobs_refusal(row: int) -> StringName:
	"""Cold transition scan catches every late-bound Job, including its worker/claim ownership."""
	for job_row: int in Jobs.JOB_CAPACITY:
		if _jobs.is_job_present(job_row) and _jobs.requester_of(job_row) == _project(row) \
				and _jobs.ref_of(job_row) != _job(row):
			return REFUSE_JOB
	return &""


func _settle_refund(site: Vector2i, destination: Vector2i) -> StringName:
	"""The Inventory owner publishes either current WIP's refund or untouched unstarted goods."""
	var project: Vector2i = _project(site.x)
	var code: StringName = _refund_destination_refusal(site, destination)
	if code != &"":
		return code
	if not _funding.is_funded(project):
		return _refund_unstarted(site.x, destination)
	_allow(project, ACTION_REFUND)
	var returned: Inventory.OpResult = _funding.refund_wip(project, destination, _promotion_tile[site.x])
	_disallow()
	if returned.ok and _operation[site.x] == OP_BRACE:
		_construction.cancellation_refund_milli_into(project, 0, _math)
		_returned_brace_milli += _math.value
	return &"" if returned.ok else returned.error


func _refund_destination_refusal(site: Vector2i, destination: Vector2i) -> StringName:
	"""Require reachable capacity only for actual positive returned materials, never a free phase."""
	var has_goods: bool = false
	for line: int in input_count(_operation[site.x]):
		if not _construction.cancellation_refund_milli_into(_project(site.x), line, _math):
			return REFUSE_DELIVERY
		has_goods = has_goods or _math.value > 0
	if not has_goods:
		return &""
	if not _inventory.container_reachable(destination):
		return Inventory.REFUSE_INVALID_CONTAINER
	return _spatial().material_refusal(origin_of(site), _room(site.x), destination, _job(site.x))


func _refund_unstarted(row: int, destination: Vector2i) -> StringName:
	"""Already delivered unconsumed goods are released where they stand, with no reminting."""
	var project: Vector2i = _project(row)
	if _pool.job_claim_count(_job(row)) > 0:
		if destination != _construction.material_container_ref_of(project):
			return REFUSE_DELIVERY
		_delivery_totals.fill(0)
		var code: StringName = _sum_delivery_claims(row, destination)
		if code != &"":
			return code
	var staging_code: StringName = _unstarted_staging_refusal(row)
	if staging_code != &"":
		return staging_code
	var released: Inventory.OpResult = _pool.release_job_claims(_job(row), _inventory)
	if not released.ok:
		return released.error
	if _unstarted_output_is_staging(row) and _inventory.container_reserved_mass_g(_output(row)) == 0:
		var removed: Inventory.OpResult = _inventory.destroy_container(_output(row))
		if not removed.ok:
			return removed.error
	return &""


func _unstarted_staging_refusal(row: int) -> StringName:
	"""Prove the later independent empty-row retirement before releasing any input claim."""
	if _inventory.is_transaction_open():
		return Inventory.REFUSE_TRANSACTION_OPEN
	var code: StringName = _funding.output_placement_refusal(_output(row), _promotion_tile[row])
	if code != &"":
		return code
	if _promotion_tile[row] >= 0 and not _staging_is_exact(row):
		return REFUSE_OUTPUT
	if _unstarted_output_is_staging(row) and _inventory.container_reserved_mass_g(_output(row)) == 0 \
			and _output_generation[row] >= Inventory.MAX_INT32:
		return Inventory.REFUSE_GENERATION_EXHAUSTED
	return &""


func _unstarted_output_is_staging(row: int) -> bool:
	"""Only actual first-output staging is ours to retire; goods or another claim keep it alive."""
	var output: Vector2i = _output(row)
	if not _inventory.is_container_valid(output) \
			or _inventory.container_policy(output) != Inventory.UNSET_POLICY \
			or _inventory.container_lot_count(output) != 0:
		return false
	if _promotion_tile[row] >= 0:
		return true
	return not _inventory.container_anchor_tile_into(output, _math) \
		and _math.error == String(Inventory.REFUSE_SPATIAL_REQUIRED)


func _retire_phase(row: int) -> void:
	"""Retire only after real refund/output publication; retain all physical progress/history."""
	var project: Vector2i = _project(row)
	var job_row: int = _job_row(_job(row))
	_allow(project, ACTION_RETIRE)
	var retired: Construction.OpResult = _construction.retire_excavation_phase(project, self)
	_disallow()
	assert(retired.ok, "settled physical phase must retire through its owning transaction")
	var job_retired: Jobs.OpResult = _jobs.destroy_job(job_row)
	assert(job_retired.ok, "worker/claim-free phase Job must retire after settlement")
	_job_site[job_row] = NO_ROW
	_project_slot[row] = -1
	_project_generation[row] = 0
	_job_slot[row] = -1
	_job_generation[row] = 0
	_operation[row] = -1
	_output_slot[row] = -1
	_output_generation[row] = 0
	_promotion_tile[row] = -1


func release_room_claim(site: Vector2i) -> Construction.OpResult:
	"""Safe room retirement frees its claim, never the world's immutable cut/source history."""
	if not is_live_site(site) or _spatial() == null or not _world_is_live():
		return _refuse(REFUSE_SITE)
	if _project(site.x) != NULL_REF or _installed[site.x] != 0 \
			or (_phase[site.x] != SOLID and _phase[site.x] != BACKFILLED and _phase[site.x] != BRACING):
		return _refuse(REFUSE_PHASE)
	var code: StringName = _spatial().retirement_refusal(_room(site.x))
	if code != &"":
		return _refuse(code)
	_room_slot[site.x] = -1
	_room_generation[site.x] = 0
	_phase[site.x] = BACKFILLED if _embedded_milli[site.x] == EARTH_MILLI else SOLID
	return _ok(site)


func phase_into(site: Vector2i, out: IntMath.IntResult) -> bool:
	"""Read physical state separately from Construction's paid-project phase."""
	return out.succeed(_phase[site.x]) if is_live_site(site) else out.refuse(REFUSE_SITE)


func installed_support(site: Vector2i) -> bool:
	"""Read paid brace truth through the actual live Site, World and Room; phase names are insufficient."""
	if _ready_error != &"" or not is_live_site(site) or not _world_is_live() or _installed[site.x] != 1:
		return false
	var spatial: SpatialAuthority = _spatial()
	var room: Vector2i = _room(site.x)
	if spatial == null or room == NULL_REF or spatial.room_refusal(room) != &"":
		return false
	return _spatial() == spatial and _world_is_live() and _room(site.x) == room and _installed[site.x] == 1


func embedded_earth_milli(site: Vector2i) -> int:
	"""Actual paid backfill retained under the original physical key."""
	return _embedded_milli[site.x] if is_live_site(site) else 0


func virgin_sourced_milli() -> int:
	"""Geological source only; reclaimed backfill and refunds never increment it."""
	return _virgin_sourced_milli


func earth_conservation_refusal() -> StringName:
	"""Cold whole-owner identity for the currently implemented cut/backfill/refund economy."""
	if _ready_error != &"":
		return REFUSE_AUTHORITY
	var item: int = _items.compiled_id(&"excavated_earth")
	var retained: int = _inventory.total_live_milli(item) + _funding.total_wip_milli(item)
	var loss: int = _funding.cancellation_loss_milli(item)
	if loss < 0:
		return REFUSE_AUTHORITY
	retained += loss
	var modular: ModularContract = _construction.modular_authority()
	if _construction.has_modular_binding() and modular == null:
		return REFUSE_AUTHORITY
	if modular != null:
		var tip_earth: int = modular.embedded_earth_milli()
		if tip_earth < 0:
			return REFUSE_AUTHORITY
		retained += tip_earth
	for quantity: int in _embedded_milli:
		retained += quantity
	return &"" if _initial_earth_milli + _virgin_sourced_milli == retained else &"EXCAVATION_EARTH_CONSERVATION"


func support_conservation_refusal() -> StringName:
	"""Cold wood/stone account: funded inputs equal WIP, returns, installed support, salvage and loss."""
	if _ready_error != &"":
		return REFUSE_AUTHORITY
	var installed: int = 0
	for flag: int in _installed:
		installed += flag
	if installed != _completed_braces - _salvaged_braces:
		return &"EXCAVATION_SUPPORT_CONSERVATION"
	for key: StringName in [&"wood", &"stone"]:
		var item: int = _items.compiled_id(key)
		var wip: int = _funding.purpose_wip_milli(Construction.PURPOSE_EXCAVATION, item)
		var loss: int = _funding.purpose_cancellation_loss_milli(Construction.PURPOSE_EXCAVATION, item)
		if wip < 0 or loss < 0:
			return &"EXCAVATION_SUPPORT_CONSERVATION"
		var accounted: int = wip + _returned_brace_milli
		accounted += loss + installed * BRACE_WOOD_MILLI
		# Each settled closure returns 125 and declares the other 125 structurally unrecoverable.
		accounted += _salvaged_braces * (SALVAGE_WOOD_MILLI + BRACE_WOOD_MILLI - SALVAGE_WOOD_MILLI)
		if _funded_braces * BRACE_WOOD_MILLI != accounted:
			return &"EXCAVATION_SUPPORT_CONSERVATION"
	return &""


func legacy_save_refusal() -> StringName:
	"""Physical history requires the UG16 versioned codec even when every paid project retired."""
	return &"EXCAVATION_VERSIONED_CODEC_REQUIRED"


func state_bytes() -> PackedByteArray:
	"""Deterministic local test image; explicitly not a production save/restore format."""
	var out: PackedByteArray = PackedInt64Array([_capacity, _count, _domain_capacity, _initial_earth_milli,
		_virgin_sourced_milli, _completed_braces, _salvaged_braces, _funded_braces, _returned_brace_milli,
		_domain.world_ref.x, _domain.world_ref.y, _domain.datum_u.x, _domain.datum_u.y,
		_domain.datum_u.z, _domain.minimum_quantum.x, _domain.minimum_quantum.y,
		_domain.minimum_quantum.z, _domain.size_quanta.x, _domain.size_quanta.y, _domain.size_quanta.z]).to_byte_array()
	for column: PackedByteArray in [_present, _phase, _installed, _ever_cut, _closure_before]:
		out.append_array(column)
	for column: PackedInt32Array in [_room_slot, _room_generation, _project_slot,
			_project_generation, _operation, _job_slot, _job_generation, _output_slot,
			_output_generation, _promotion_tile, _job_site, _worker_site, _worker_generation, _ordered_row]:
		out.append_array(column.to_byte_array())
	out.append_array(_site_key.to_byte_array())
	out.append_array(_ordered_key.to_byte_array())
	out.append_array(_embedded_milli.to_byte_array())
	out.append_array(_earned_mwu.to_byte_array())
	if _funding != null:
		out.append_array(_funding.state_bytes())
	return out


func _context_refusal(site: Vector2i) -> StringName:
	"""Validate world/site/room/project identities before touching a phase collaborator."""
	if _ready_error != &"" or not is_live_site(site) or _spatial() == null or not _world_is_live():
		return REFUSE_SITE
	if _composition_refusal() != &"":
		return REFUSE_AUTHORITY
	if not _construction.is_live_project(_project(site.x)):
		return Construction.REFUSE_STALE_PROJECT_REF
	return _spatial().room_refusal(_room(site.x))


func _bound_refusal(site: Vector2i) -> StringName:
	"""The phase's actual Job must still name this exact Construction requester generation."""
	var code: StringName = _context_refusal(site)
	if code != &"":
		return code
	var job_row: int = _job_row(_job(site.x))
	if job_row == NO_ROW or _jobs.requester_of(job_row) != _project(site.x) \
			or _jobs.is_coordinator(job_row) or _jobs.is_member(job_row):
		return REFUSE_JOB
	if not _jobs.kind_into(job_row, _math) or _math.value != Jobs.JOB_KIND_BUILD:
		return REFUSE_JOB
	return &""


func _world_is_live() -> bool:
	"""A recycled World directory slot cannot inherit a prior world's physical source history."""
	return _jobs.directory().is_valid_of_kind(_domain.world_ref, Directory.KIND_WORLD)


func _space_refusal(row: int, operation: int, stage: int) -> StringName:
	"""Revalidate actual space; only real lifecycle events may prepare a finite publication."""
	var spatial: SpatialAuthority = _spatial()
	if spatial == null:
		return REFUSE_AUTHORITY
	var code: StringName = spatial.room_refusal(_room(row))
	if code != &"":
		return code
	var origin: Vector3i = origin_of(Vector2i(row, SITE_GENERATION))
	code = spatial.operation_refusal(origin, operation, stage, _room(row))
	if stage == STAGE_START or stage == STAGE_COMMIT or stage == STAGE_CANCEL:
		_candidate_row = row
		_candidate_stage = stage
		if code != &"":
			_discard_candidate()
	return code


func _discard_candidate() -> void:
	"""Abandon transient space preparation after refusal without rolling back actual owner state."""
	if _candidate_row == NO_ROW:
		return
	var row: int = _candidate_row
	_spatial().discard_transition(origin_of(Vector2i(row, SITE_GENERATION)),
		_operation[row], _candidate_stage, _room(row))
	_candidate_row = NO_ROW
	_candidate_stage = -1


func _publish_candidate(row: int, stage: int) -> void:
	"""Install only the immediately prepared candidate after physical payment/output commits."""
	assert(_candidate_row == row and _candidate_stage == stage, "publication requires its exact prepared transition")
	_publishing_spatial = true
	_spatial().publish_transition(origin_of(Vector2i(row, SITE_GENERATION)), _operation[row], stage, _room(row))
	_publishing_spatial = false
	_candidate_row = NO_ROW
	_candidate_stage = -1


func _job_row(job: Vector2i) -> int:
	"""Validate Job namespace and full generation, never reinterpret a raw global slot as a row."""
	if not _jobs.directory().is_valid_of_kind(job, Directory.KIND_JOB):
		return NO_ROW
	var row: int = _jobs.directory().get_typed_row(job)
	return row if _jobs.ref_of(row) == job else NO_ROW


func _room(row: int) -> Vector2i:
	"""Read a full room-owner reference from paired columns."""
	return Vector2i(_room_slot[row], _room_generation[row])


func _project(row: int) -> Vector2i:
	"""Read this quantum's current paid Construction identity."""
	return Vector2i(_project_slot[row], _project_generation[row])


func _job(row: int) -> Vector2i:
	"""Read this quantum's actual bound Job generation."""
	return Vector2i(_job_slot[row], _job_generation[row])


func _output(row: int) -> Vector2i:
	"""Read the finite Inventory output destination, never a virtual spoil buffer."""
	return Vector2i(_output_slot[row], _output_generation[row])


func _ok(site: Vector2i) -> Construction.OpResult:
	"""Return an explicit successful physical site reference."""
	return Construction.OpResult.new(true, &"", site.x, site)


func _refuse(code: StringName) -> Construction.OpResult:
	"""A refusal never carries stale output state or a newly allocated reference."""
	return Construction.OpResult.new(false, code, 0, NULL_REF)
