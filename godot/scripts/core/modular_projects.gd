extends "res://scripts/core/modular_project_contract.gd"
## Actual shared payment/worker router. Physical purpose owners remain typed and fail closed.
## Four generation-qualified Job columns are authoritative; no receipt arena is duplicated.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Gear := preload("res://scripts/core/gear.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const JOB_CAPACITY: int = Jobs.JOB_CAPACITY
const DELIVERY_CAPACITY: int = Contract.INPUT_CAPACITY
const NO_ROW: int = -1
const REFUSE_JOB: StringName = &"MODULAR_JOB_BINDING_INVALID"
const REFUSE_WORKER: StringName = &"MODULAR_WORKER_BINDING_INVALID"
const REFUSE_CREW: StringName = &"MODULAR_CREW_LIMIT_OR_MEMBERSHIP"
const REFUSE_DELIVERY: StringName = &"MODULAR_DELIVERY_CLAIMS_INVALID"
const REFUSE_OUTPUT: StringName = &"MODULAR_OUTPUT_CONTACT_INVALID"
const REFUSE_BUSY: StringName = &"MODULAR_TRANSITION_IN_PROGRESS"
const REFUSE_SAVE: StringName = &"MODULAR_VERSIONED_CODEC_REQUIRED"

var _job_slot: PackedInt32Array = PackedInt32Array()
var _job_generation: PackedInt32Array = PackedInt32Array()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
## Four line totals are cold delivery scratch, not project quantities or worker objects.
var _delivery_totals: PackedInt64Array = PackedInt64Array()
var _construction: Construction = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: ItemDefinitions = null
var _jobs: Jobs = null
var _work: Work = null
var _sites: Sites = null
var _funding: Funding = null
var _world: Vector2i = NULL_REF
var _furniture_owner: WeakRef = null
var _tip_owner: WeakRef = null
var _connector_owner: WeakRef = null
var _ready_error: StringName = &""
var _quote: Quote = Quote.new()
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _other: IntMath.IntResult = IntMath.IntResult.new()
var _crew_count: int = 0
var _busy: bool = false
var _admitting: WeakRef = null
var _batch_candidates: Directory.CreateBatch = null
var _batch_room: Vector2i = NULL_REF
var _batch_publishing: bool = false
var _permit_project: Vector2i = NULL_REF
var _permit_action: int = -1
var _publishing_project: Vector2i = NULL_REF
var _publishing_action: int = -1
var _publishing_owner: Owner = null


func _init(construction: Construction, inventory: Inventory, pool: Reservations,
		items: ItemDefinitions, jobs: Jobs, work: Work, sites: Sites) -> void:
	"""Preflight both accounting/work bindings and the exact shared arena before any owner changes."""
	_construction = construction
	_inventory = inventory
	_pool = pool
	_items = items
	_jobs = jobs
	_work = work
	_sites = sites
	_ready_error = _initialization_refusal()
	if _ready_error != &"":
		return
	for column: PackedInt32Array in [_job_slot, _job_generation, _project_slot, _project_generation]:
		column.resize(JOB_CAPACITY)
	_job_slot.fill(-1)
	_project_slot.fill(-1)
	_delivery_totals.resize(DELIVERY_CAPACITY)
	var bound: Construction.OpResult = _construction.bind_modular_authority(self)
	assert(bound.ok, "preflighted accounting binding must succeed")
	var work_bound: Work.OpResult = _work.bind_modular_authority(self)
	assert(work_bound.ok, "preflighted Work binding must succeed after accounting binding")


func _initialization_refusal() -> StringName:
	"""A refused initializer never strands an otherwise valid owner on half of a composition."""
	if _construction == null or _inventory == null or _pool == null or _items == null \
			or _jobs == null or _work == null or _sites == null:
		return REFUSE_AUTHORITY
	_funding = _sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work)
	if _funding == null or _construction.directory() != _jobs.directory() or _work.jobs() != _jobs:
		return REFUSE_AUTHORITY
	# The current Directory owns exactly one World; never select among unrelated worlds.
	if Directory.KIND_CAPACITY[Directory.KIND_WORLD] != 1:
		return REFUSE_AUTHORITY
	_world = _jobs.directory().ref_of_slot(_jobs.directory().owner_slot_of_typed_row(Directory.KIND_WORLD, 0))
	if not _jobs.directory().is_valid_of_kind(_world, Directory.KIND_WORLD):
		return REFUSE_AUTHORITY
	if _construction.modular_binding_refusal(self) != &"" or _work.modular_binding_refusal(self) != &"":
		return REFUSE_AUTHORITY
	return &""


func initialization_refusal() -> StringName:
	"""Read explicit construction failure instead of granting an empty permissive router."""
	return _ready_error


func construction_owner() -> RefCounted:
	"""Expose the successfully initialized actual accounting owner; no numeric alias qualifies."""
	return _construction if _ready_error == &"" else null


func world_ref() -> Vector2i:
	"""This derived composition handle names the one real Directory World generation."""
	return _world if _ready_error == &"" else NULL_REF


func item_definitions_owner() -> ItemDefinitions:
	"""A foreign or rewired catalog never supplies item IDs to a physical purpose owner."""
	return _items if _composition_refusal() == &"" else null


func _composition_refusal() -> StringName:
	"""Check actual wiring in O(1), including late Items/Gear/Reservation rewiring."""
	if _ready_error != &"" or _construction == null or _sites == null:
		return REFUSE_AUTHORITY
	if _construction.modular_authority() != self or _work.modular_authority() != self:
		return REFUSE_AUTHORITY
	if not _jobs.directory().is_valid_of_kind(_world, Directory.KIND_WORLD):
		return REFUSE_AUTHORITY
	return &"" if _sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work) == _funding \
		else REFUSE_AUTHORITY


func owner_binding_refusal(owner: Owner) -> StringName:
	"""Resolve all composition/purpose refusals before the physical owner binds its publisher."""
	if _composition_refusal() != &"" or owner == null or _busy:
		return REFUSE_AUTHORITY
	if owner.construction_owner() != _construction or owner.world_ref() != _world:
		return REFUSE_AUTHORITY
	if owner.purpose() == Construction.PURPOSE_SPATIAL_FURNITURE:
		return &"" if _furniture_owner == null else REFUSE_AUTHORITY
	if owner.purpose() == Construction.PURPOSE_SPOIL_TIP:
		return &"" if _tip_owner == null else REFUSE_AUTHORITY
	if owner.purpose() == Construction.PURPOSE_CONNECTOR_INSTALL:
		return &"" if _connector_owner == null else REFUSE_AUTHORITY
	return REFUSE_AUTHORITY


func bind_owner(owner: Owner) -> Construction.OpResult:
	"""Bind one exact purpose owner once; an expired binding cannot reset its retained history."""
	var code: StringName = owner_binding_refusal(owner)
	if code != &"":
		return _refuse(code)
	if owner.purpose() == Construction.PURPOSE_SPATIAL_FURNITURE:
		_furniture_owner = weakref(owner)
	elif owner.purpose() == Construction.PURPOSE_SPOIL_TIP:
		_tip_owner = weakref(owner)
	else:
		_connector_owner = weakref(owner)
	return _ok(NULL_REF)


func _owner_for(purpose: int) -> Owner:
	"""Read and requalify a live weak purpose owner without constructing facts or result objects."""
	var binding: WeakRef = _furniture_owner if purpose == Construction.PURPOSE_SPATIAL_FURNITURE \
		else _tip_owner if purpose == Construction.PURPOSE_SPOIL_TIP \
		else _connector_owner if purpose == Construction.PURPOSE_CONNECTOR_INSTALL else null
	var owner: Owner = binding.get_ref() as Owner if binding != null else null
	if owner == null or owner.purpose() != purpose or owner.construction_owner() != _construction \
			or owner.world_ref() != _world:
		return null
	return owner


func is_bound_owner(owner: Owner) -> bool:
	"""Null, expired, foreign or late-rewired owners never acquire publication permission."""
	return owner != null and _composition_refusal() == &"" and _owner_for(owner.purpose()) == owner


func is_publishing(project: Vector2i, action: int, owner: Owner) -> bool:
	"""Attest only this exact synchronous post-commit callback, with full actual identities."""
	if not _busy or _publishing_owner == null or not is_bound_owner(owner):
		return false
	return project != NULL_REF and project == _publishing_project and action == _publishing_action \
		and _publishing_owner == owner and _project_owner(project) == owner


func _project_owner(project: Vector2i) -> Owner:
	"""Hot owner lookup uses actual Construction purpose, never cold quote or Buildings readers."""
	if not _construction.purpose_into(project, _math):
		return null
	return _owner_for(_math.value)


func open_furniture_batch(owner: Owner, room: Vector2i, batch: Directory.CreateBatch,
		entries: PackedInt32Array) -> Construction.OpResult:
	"""Accept exact paired Furniture/projects only after every actual owner preflights the whole batch."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	_busy = true
	if not is_bound_owner(owner) or owner.purpose() != Construction.PURPOSE_SPATIAL_FURNITURE:
		_busy = false
		return _refuse(REFUSE_AUTHORITY)
	_admitting = weakref(owner)
	_batch_candidates = batch
	_batch_room = room
	var code: StringName = _furniture_batch_refusal(owner, room, batch, entries)
	var accepted: Construction.OpResult = null
	if code == &"":
		code = _construction.directory().create_batch(batch)
	if code == &"":
		accepted = _publish_furniture_batch(owner, room, batch, entries)
	else:
		owner.discard_furniture_batch(room, batch)
	_batch_candidates = null
	_batch_room = NULL_REF
	_admitting = null
	_busy = false
	return accepted if code == &"" else _refuse(code)


func _furniture_batch_refusal(owner: Owner, room: Vector2i, batch: Directory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Run the final provider proof after finite actual row/catalog checks and before Directory publication."""
	var code: StringName = _construction.buildings().spatial_furniture_batch_refusal(room, batch, entries)
	if code == &"":
		code = _construction.spatial_furniture_batch_refusal(room, batch, entries)
	if code == &"":
		code = owner.furniture_batch_refusal(room, batch, entries)
	return code


func furniture_batch_preparation_refusal(room: Vector2i, batch: Directory.CreateBatch) -> StringName:
	"""Pure exact in-flight packet comparison; only the actual bound Router opens this context."""
	return &"" if _busy and not _batch_publishing and batch != null \
		and batch == _batch_candidates and room == _batch_room and _admitting != null \
		and _admitting.get_ref() != null else REFUSE_AUTHORITY


func furniture_batch_publication_refusal(room: Vector2i, batch: Directory.CreateBatch) -> StringName:
	"""No post-identity external requalification can make prepared typed-row publication fallible."""
	return &"" if _busy and _batch_publishing and batch != null \
		and batch == _batch_candidates and room == _batch_room and _admitting != null \
		and _admitting.get_ref() != null else REFUSE_AUTHORITY


func is_publishing_furniture_admissions(room: Vector2i, batch: Directory.CreateBatch, owner: Owner) -> bool:
	"""Attest exact purpose-owner identity inside the same synchronous paired publication only."""
	return owner != null and furniture_batch_publication_refusal(room, batch) == &"" \
		and _admitting.get_ref() == owner


func _publish_furniture_batch(owner: Owner, room: Vector2i, batch: Directory.CreateBatch,
		entries: PackedInt32Array) -> Construction.OpResult:
	"""After the actual identity commit only preallocated typed rows and sealed companions publish."""
	@warning_ignore("integer_division") var accepted_count: int = batch.count / 2
	var first_project: Vector2i = batch.ref_at(1)
	_batch_publishing = true
	var placed: StringName = _construction.buildings().publish_spatial_furniture_batch(room, batch, entries)
	assert(placed == &"", "preflighted pending Furniture rows cannot fail after identity publication")
	var projects: StringName = _construction.publish_spatial_furniture_batch(room, batch, entries)
	assert(projects == &"", "preflighted paired project rows cannot fail after identity publication")
	owner.publish_furniture_batch(room, batch, entries)
	_batch_publishing = false
	return Construction.OpResult.new(true, &"", accepted_count, first_project)


func open_order(owner: Owner, subject: Vector2i, operation: int) -> Construction.OpResult:
	"""Admit an owner-prepared order; callers supply neither prices nor a quantity contract."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	if not is_bound_owner(owner):
		return _refuse(REFUSE_AUTHORITY)
	_busy = true
	_quote.reset()
	var code: StringName = owner.prepared_order_into(subject, operation, _quote)
	if code == &"" and (_quote.refusal() != &"" or _quote.subject != subject or _quote.operation != operation):
		code = REFUSE_QUOTE
	if code != &"":
		owner.discard_transition(NULL_REF, ADMIT)
		_busy = false
		return _refuse(code)
	_admitting = weakref(owner)
	var result: Construction.OpResult = _construction.open_modular_phase(owner.purpose(), subject, operation)
	_admitting = null
	if not result.ok:
		owner.discard_transition(NULL_REF, ADMIT)
	_busy = false
	return result


func project_open_into(purpose: int, subject: Vector2i, operation: int, out: Quote) -> StringName:
	"""Only the current prepared admission may copy immutable facts into Construction."""
	var owner: Owner = _admitting.get_ref() as Owner if _admitting != null else null
	if not _busy or out == null or not is_bound_owner(owner) or owner.purpose() != purpose \
			or _quote.subject != subject or _quote.operation != operation:
		return REFUSE_AUTHORITY
	_copy_quote(_quote, out)
	return &""


func _copy_quote(source: Quote, out: Quote) -> void:
	"""Copy bounded cold scratch without sharing mutable arrays with another owner."""
	out.reset()
	out.subject = source.subject
	out.operation = source.operation
	out.quantity_milli = source.quantity_milli
	out.total_mwu = source.total_mwu
	out.remaining_mwu = source.remaining_mwu
	out.job_kind = source.job_kind
	out.max_workers = source.max_workers
	out.input_count = source.input_count
	out.output_count = source.output_count
	for index: int in INPUT_CAPACITY:
		out.input_keys[index] = source.input_keys[index]
		out.input_milli[index] = source.input_milli[index]
	for index: int in OUTPUT_CAPACITY:
		out.output_item[index] = source.output_item[index]
		out.output_milli[index] = source.output_milli[index]
		out.output_quality[index] = source.output_quality[index]
		out.output_provenance[index] = source.output_provenance[index]
		out.output_recipe[index] = source.output_recipe[index]
		out.output_age[index] = source.output_age[index]
		out.output_remainder[index] = source.output_remainder[index]


func attach_project(purpose: int, subject: Vector2i, operation: int, project: Vector2i) -> void:
	"""Publish only the preflighted allocation callback; direct calls cannot attach a subject."""
	var owner: Owner = _admitting.get_ref() as Owner if _admitting != null else null
	if not _busy or not is_bound_owner(owner) or owner.purpose() != purpose \
			or _quote.subject != subject or _quote.operation != operation:
		return
	if not _construction.is_live_project(project) or _construction.subject_ref_of(project) != subject \
			or not _construction.type_id_into(project, _math) or _math.value != operation:
		return
	_publish(project, ADMIT, owner)


func project_facts_into(project: Vector2i, out: Quote) -> StringName:
	"""Cold immutable bill reader; no source owner may substitute another purpose or subject."""
	if _composition_refusal() != &"" or out == null:
		return REFUSE_AUTHORITY
	var owner: Owner = _project_owner(project)
	if owner == null:
		return REFUSE_AUTHORITY
	out.reset()
	var code: StringName = owner.project_facts_into(project, out)
	if code != &"":
		return code
	if out.refusal() != &"" or out.subject != _construction.subject_ref_of(project) \
			or not _construction.type_id_into(project, _math) or out.operation != _math.value:
		return REFUSE_QUOTE
	if not _construction.max_workers_into(project, _math) or out.max_workers != _math.value:
		return REFUSE_QUOTE
	return &""


func mutation_refusal(project: Vector2i, action: int) -> StringName:
	"""Only the router's exact current Accounting/Funding operation may mutate owned state."""
	if not _busy or _composition_refusal() != &"" or project != _permit_project \
			or action != _permit_action or _project_owner(project) == null:
		return REFUSE_AUTHORITY
	return &""


func _allow(project: Vector2i, action: int) -> void:
	"""The caller has already preflighted the exact transaction; permission remains synchronous."""
	_permit_project = project
	_permit_action = action


func _disallow() -> void:
	"""No mutation permit survives an operation or refused retry."""
	_permit_project = NULL_REF
	_permit_action = -1


func _publish(project: Vector2i, action: int, owner: Owner) -> void:
	"""Install only the current prepared physical candidate after its required real commit."""
	_publishing_project = project
	_publishing_action = action
	_publishing_owner = owner
	match action:
		ADMIT: owner.publish_open(project)
		PRODUCTIVE: owner.publish_work(project)
		COMMIT: owner.publish_completion(project)
		CANCEL: owner.publish_cancellation(project)
	_publishing_owner = null
	_publishing_project = NULL_REF
	_publishing_action = -1


func _job_row(job: Vector2i) -> int:
	"""Never index a typed Job row with a Directory slot or accept a recycled generation."""
	if not _jobs.directory().is_valid_of_kind(job, Directory.KIND_JOB):
		return NO_ROW
	var row: int = _jobs.directory().get_typed_row(job)
	return row if _jobs.ref_of(row) == job else NO_ROW


func _bound_job(row: int) -> Vector2i:
	"""Read an accepted full Job identity, including a retained stale reference for diagnostics."""
	return Vector2i(_job_slot[row], _job_generation[row])


func _project(row: int) -> Vector2i:
	"""Read the full generation-qualified project attached to one accepted Job row."""
	return Vector2i(_project_slot[row], _project_generation[row])


func _primary_row(project: Vector2i) -> int:
	"""Cold uniqueness/liveness scan; a detached or stale member cannot become another primary."""
	var primary: int = NO_ROW
	for row: int in JOB_CAPACITY:
		if _project(row) != project:
			continue
		if _job_row(_bound_job(row)) != row:
			return NO_ROW
		if not _jobs.is_member(row):
			if primary != NO_ROW:
				return NO_ROW
			primary = row
	return primary


func bind_job(project: Vector2i, job: Vector2i) -> Construction.OpResult:
	"""Accept one actual primary solo/coordinator Job; requester numbers alone are insufficient."""
	if _busy or _composition_refusal() != &"":
		return _refuse(REFUSE_AUTHORITY)
	var code: StringName = project_facts_into(project, _quote)
	if code != &"":
		return _refuse(code)
	var row: int = _job_row(job)
	if row == NO_ROW or job.x >= _pool.job_capacity() or _job_slot[row] >= 0 \
			or _jobs.requester_of(row) != project or _jobs.is_member(row):
		return _refuse(REFUSE_JOB)
	for existing: int in JOB_CAPACITY:
		if _project(existing) == project:
			return _refuse(REFUSE_JOB)
	if not _jobs.kind_into(row, _math) or _math.value != _quote.job_kind:
		return _refuse(REFUSE_JOB)
	_construction.remaining_mwu_into(project, _math)
	if not _jobs.remaining_mwu_into(row, _other) or _math.value != _other.value:
		return _refuse(REFUSE_JOB)
	if not _jobs.is_coordinator(row) and (not _jobs.tool_gate_into(row, _math) or _math.value == Jobs.GATE_NOT_REQUIRED):
		return _refuse(Work.REFUSE_TOOL_NOT_CLAIMED)
	_write_binding(row, job, project)
	return _ok(project)


func bind_member(project: Vector2i, member: Vector2i) -> Construction.OpResult:
	"""Accept a real zero-work party member without creating independent project progress."""
	if _busy or _composition_refusal() != &"":
		return _refuse(REFUSE_AUTHORITY)
	var primary: int = _primary_row(project)
	var row: int = _job_row(member)
	if primary < 0 or row < 0 or _job_slot[row] >= 0 or not _jobs.is_coordinator(primary) \
			or _jobs.coordinator_of(row) != _bound_job(primary) or _jobs.requester_of(row) != project:
		return _refuse(REFUSE_JOB)
	if not _jobs.remaining_mwu_into(row, _math) or _math.value != 0 \
			or not _jobs.tool_gate_into(row, _math) or _math.value == Jobs.GATE_NOT_REQUIRED:
		return _refuse(REFUSE_JOB)
	_jobs.kind_into(primary, _math)
	if not _jobs.kind_into(row, _other) or _other.value != _math.value:
		return _refuse(REFUSE_JOB)
	var count: int = 0
	for existing: int in JOB_CAPACITY:
		if _project(existing) == project and existing != primary:
			count += 1
	_construction.max_workers_into(project, _math)
	if count >= _math.value:
		return _refuse(REFUSE_CREW)
	_write_binding(row, member, project)
	return _ok(project)


func _write_binding(row: int, job: Vector2i, project: Vector2i) -> void:
	"""Publish a fully preflighted accepted Job/Construction pair once."""
	_job_slot[row] = job.x
	_job_generation[row] = job.y
	_project_slot[row] = project.x
	_project_generation[row] = project.y


func _clear_binding(row: int) -> void:
	"""Erase an explicitly retired binding; no physical WIP or historical quantities live here."""
	_job_slot[row] = -1
	_job_generation[row] = 0
	_project_slot[row] = -1
	_project_generation[row] = 0


func job_of(project: Vector2i) -> Vector2i:
	"""Cold actual primary lookup; ambiguity or stale identity refuses as null."""
	if _composition_refusal() != &"" or not _construction.is_live_project(project):
		return NULL_REF
	var row: int = _primary_row(project)
	return _bound_job(row) if row >= 0 else NULL_REF


func _bound_refusal(project: Vector2i, row: int) -> StringName:
	"""Check the actual primary generation/requester; cold facts are unnecessary for work ticks."""
	if _composition_refusal() != &"" or _project_owner(project) == null:
		return REFUSE_AUTHORITY
	if row < 0 or _project(row) != project or _job_row(_bound_job(row)) != row \
			or _jobs.requester_of(row) != project or _jobs.is_member(row):
		return REFUSE_JOB
	return &""


func bind_material_container(project: Vector2i, container: Vector2i) -> Construction.OpResult:
	"""Bind only reachable real stock at the physical owner's current delivery contact."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	var row: int = _primary_row(project) if _ready_error == &"" else NO_ROW
	var code: StringName = _bound_refusal(project, row)
	if code != &"":
		return _refuse(code)
	if _construction.has_work_begun(project) or not _inventory.container_reachable(container):
		return _refuse(REFUSE_DELIVERY)
	_busy = true
	code = _project_owner(project).material_refusal(project, container, _bound_job(row))
	if code != &"":
		return _finish(_refuse(code))
	_allow(project, ACTION_CONTAINER)
	return _finish(_construction.set_material_container(project, container))


func record_deliveries(project: Vector2i) -> Construction.OpResult:
	"""Read actual complete claims; no caller quantity can manufacture a delivered material credit."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	var row: int = _primary_row(project) if _ready_error == &"" else NO_ROW
	var code: StringName = _bound_refusal(project, row)
	if code != &"":
		return _refuse(code)
	_busy = true
	code = _delivery_refusal(project, row)
	if code != &"":
		return _finish(_refuse(code))
	_allow(project, ACTION_DELIVER)
	for line: int in _quote.input_count:
		_construction.delivered_milli_into(project, line, _math)
		var delta: int = _delivery_totals[line] - _math.value
		if delta > 0:
			var applied: Construction.OpResult = _construction.deliver_material(project, line, delta)
			assert(applied.ok, "preflighted delivered quantities cannot fail partway")
	return _finish(_ok(project))


func _delivery_refusal(project: Vector2i, row: int) -> StringName:
	"""Preflight all bill lines and actual contact before changing any Construction credit."""
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_AWAITING_MATERIALS:
		return Construction.REFUSE_WRONG_PHASE
	var code: StringName = project_facts_into(project, _quote)
	if code != &"":
		return code
	var container: Vector2i = _construction.material_container_ref_of(project)
	if not _inventory.container_reachable(container):
		return REFUSE_DELIVERY
	code = _project_owner(project).material_refusal(project, container, _bound_job(row))
	if code == &"":
		code = _sum_claims(row, container)
	if code != &"":
		return code
	for line: int in _quote.input_count:
		_construction.delivered_milli_into(project, line, _math)
		if _delivery_totals[line] < _math.value or _delivery_totals[line] > _quote.input_milli[line]:
			return REFUSE_DELIVERY
	return &""


func _sum_claims(row: int, container: Vector2i) -> StringName:
	"""Only the primary's exact modular input claims in the bound physical container count."""
	_delivery_totals.fill(0)
	var claim: int = _pool.first_job_row(_bound_job(row))
	while claim != Reservations.NULL_ROW:
		var lot: Vector2i = _pool.row_lot_ref(claim)
		if not _pool.row_purpose_into(claim, _math) or _math.value != Reservations.PURPOSE_MODULAR_INPUT \
				or not _inventory.is_lot_valid(lot) or _inventory.lot_container(lot) != container:
			return REFUSE_DELIVERY
		var line: int = _input_line(_inventory.lot_item_id(lot))
		if line < 0:
			return REFUSE_DELIVERY
		if not IntMath.checked_add_into(_delivery_totals[line], _pool.row_quantity_milli(claim), _math):
			return Inventory.REFUSE_OVERFLOW
		_delivery_totals[line] = _math.value
		claim = _pool.next_job_row(claim)
	return &""


func _input_line(item: int) -> int:
	"""Resolve an actual registered item only against this cold operation's immutable bill."""
	for line: int in _quote.input_count:
		if _items.compiled_id(_quote.input_keys[line]) == item:
			return line
	return NO_ROW


func start_work(project: Vector2i, now_tick: int, output: Vector2i = NULL_REF,
		promotion_tile: int = -1) -> Construction.OpResult:
	"""Pay once through actual claims and output capacity before any productive worker tick."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	var row: int = _primary_row(project) if _ready_error == &"" else NO_ROW
	var code: StringName = _bound_refusal(project, row)
	if code != &"":
		return _refuse(code)
	_busy = true
	var owner: Owner = _project_owner(project)
	code = _start_refusal(project, row, output, promotion_tile, owner)
	if code != &"":
		return _discard_finish(project, START, owner, code)
	_allow(project, ACTION_WIP)
	var paid: Inventory.OpResult = _funding.consume_to_wip(project, _bound_job(row), now_tick, output)
	_disallow()
	if not paid.ok:
		return _discard_finish(project, START, owner, paid.error)
	_allow(project, ACTION_BEGIN_WORK)
	var begun: Construction.OpResult = _construction.begin_work(project)
	assert(begun.ok, "preflighted paid start cannot fail after Inventory consumption")
	_disallow()
	_start_job_states(project, row)
	owner.discard_transition(project, START)
	return _finish(_ok(project))


func _start_refusal(project: Vector2i, row: int, output: Vector2i, tile: int, owner: Owner) -> StringName:
	"""Every fallible phase/contact/worker check precedes irreversible consumed-input publication."""
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_READY \
			or _funding.is_funded(project):
		return Construction.REFUSE_WRONG_PHASE
	var code: StringName = project_facts_into(project, _quote)
	if code == &"":
		code = _crew_refusal(project, row, false)
	if code == &"":
		code = owner.transition_refusal(project, START)
	if code == &"" and _quote.input_count > 0:
		code = owner.material_refusal(project, _construction.material_container_ref_of(project), _bound_job(row))
	return _cold_output_refusal(project, row, output, tile, owner) if code == &"" else code


func _cold_output_refusal(project: Vector2i, row: int, output: Vector2i, tile: int, owner: Owner) -> StringName:
	"""Retain the actual output location; a spatial endpoint never aliases a surface contact."""
	var mass: int = _funding.project_output_mass_g(project)
	if mass == 0:
		return &"" if output == NULL_REF and tile == -1 else REFUSE_OUTPUT
	if mass < 0 or not _inventory.container_reachable(output):
		return REFUSE_OUTPUT
	var code: StringName = _funding.output_placement_refusal(output, tile)
	if code != &"":
		return code
	if tile >= 0 and not _staging_is_exact(output, tile):
		return REFUSE_OUTPUT
	return owner.output_refusal(project, output, _bound_job(row), tile)


func _staging_is_exact(output: Vector2i, tile: int) -> bool:
	"""Finite first-pile staging keeps the Inventory invariant; spatial admission still belongs elsewhere."""
	return _inventory.container_anchor_tile_into(output, _math) and _math.value == tile \
		and _inventory.container_owner(output) == _world \
		and _inventory.container_policy(output) == Inventory.UNSET_POLICY \
		and _inventory.container_max_mass_g(output) == Inventory.GROUND_PILE_MAX_MASS_G \
		and _inventory.container_filters(output) == Inventory.FILTERS_ACCEPT_ALL \
		and _inventory.container_lot_count(output) == 0


func _start_job_states(project: Vector2i, primary: int) -> void:
	"""Publish worker readiness only after actual funding; retained zero work spends no extra tick."""
	_construction.remaining_mwu_into(project, _math)
	var state: int = Jobs.JOB_STATE_COMPLETE if _math.value == 0 else Jobs.JOB_STATE_WORK
	_jobs.set_state(primary, state)
	if _jobs.is_coordinator(primary) and _jobs.first_member_into(primary, _other):
		var row: int = _other.value
		while row >= 0:
			_jobs.set_state(row, state)
			row = _other.value if _jobs.next_member_into(row, _other) else NO_ROW
	_construction.set_assigned_count(project, _crew_count)


func _crew_refusal(project: Vector2i, primary: int, require_work_state: bool) -> StringName:
	"""Read at most four accepted real contributors without per-worker objects or global scans."""
	_crew_count = 0
	if not _jobs.is_coordinator(primary):
		return _worker_refusal(project, primary, require_work_state)
	if not _jobs.first_member_into(primary, _other):
		return REFUSE_WORKER
	var row: int = _other.value
	var count: int = 0
	while row >= 0:
		count += 1
		if count > MAX_WORKERS or _member_refusal(project, primary, row) != &"":
			return REFUSE_CREW
		var code: StringName = _worker_refusal(project, row, require_work_state)
		if code != &"" and not _safe_skipped_member(row, code):
			return code
		row = _other.value if _jobs.next_member_into(row, _other) else NO_ROW
	if not _construction.max_workers_into(project, _math) or count > _math.value:
		return REFUSE_CREW
	return &"" if _crew_count > 0 else REFUSE_WORKER


func _member_refusal(project: Vector2i, primary: int, row: int) -> StringName:
	"""Even unassigned/late party members need their accepted exact binding and sole progress owner."""
	if _project(row) != project or _job_row(_bound_job(row)) != row \
			or _jobs.coordinator_of(row) != _bound_job(primary) or _jobs.requester_of(row) != project:
		return REFUSE_JOB
	if not _jobs.remaining_mwu_into(row, _math) or _math.value != 0:
		return REFUSE_JOB
	_jobs.kind_into(primary, _math)
	if not _jobs.kind_into(row, _other) or _other.value != _math.value:
		return REFUSE_JOB
	# Work normally permits NOT_REQUIRED; modular paid work may never use that loophole.
	return &"" if _jobs.tool_gate_into(row, _math) and _math.value != Jobs.GATE_NOT_REQUIRED \
		else Work.REFUSE_TOOL_NOT_CLAIMED


func _worker_refusal(project: Vector2i, row: int, require_work_state: bool) -> StringName:
	"""Validate full worker/Job/Gear identity and actual current contact before Work mutates carry."""
	if require_work_state and (not _jobs.state_into(row, _math) or _math.value != Jobs.JOB_STATE_WORK):
		return Work.REFUSE_JOB_NOT_WORKING
	var worker: Vector2i = _jobs.worker_of(row)
	if not _jobs.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return Work.REFUSE_JOB_HAS_NO_WORKER
	var resident: int = _jobs.directory().get_typed_row(worker)
	if _work.residents().ref_of(resident) != worker or _jobs.job_of(resident) != _bound_job(row):
		return REFUSE_WORKER
	if _work.residents().life_stage_code_of(resident) == Residents.LIFE_STAGE_CHILD:
		return REFUSE_WORKER
	if not _jobs.resident_may_work_into(resident, _math):
		return Work.REFUSE_JOB_NOT_WORKING
	var code: StringName = _tool_refusal(row, resident, worker)
	if code == &"":
		code = _project_owner(project).worker_refusal(project, _bound_job(row), worker)
	if code == &"":
		_crew_count += 1
	return code


func _tool_refusal(row: int, resident: int, worker: Vector2i) -> StringName:
	"""Mandatory equipped positive-durability tools use actual owner/job generation proof."""
	if not _jobs.tool_gate_into(row, _math) or _math.value != Jobs.GATE_SATISFIED:
		return Work.REFUSE_TOOL_NOT_CLAIMED if _math.value == Jobs.GATE_NOT_REQUIRED \
			else Work.REFUSE_TOOL_GATE_BLOCKED
	var tool: Vector2i = _work.tool_lot_of(resident)
	if tool == NULL_REF:
		return Work.REFUSE_TOOL_NOT_CLAIMED
	if _work.tool_job_of(resident) != _bound_job(row):
		return Work.REFUSE_TOOL_CLAIM_STALE
	if _work.tool_is_broken(resident):
		return Work.REFUSE_TOOL_BROKEN
	var code: StringName = _work.gear().equipped_work_claim_refusal(tool, worker, _bound_job(row))
	return code


func _safe_skipped_member(row: int, code: StringName) -> bool:
	"""Skip only a contributor that actual Work will also skip; never admit a free-tool mismatch."""
	if code == Work.REFUSE_JOB_NOT_WORKING or code == Work.REFUSE_JOB_HAS_NO_WORKER \
			or code == Work.REFUSE_TOOL_GATE_BLOCKED or code == Work.REFUSE_TOOL_CLAIM_STALE:
		return true
	var resident: int = _jobs.directory().get_typed_row(_jobs.worker_of(row))
	if resident < 0:
		return false
	if code == Work.REFUSE_TOOL_BROKEN:
		return _work.tool_is_broken(resident)
	if code == Work.REFUSE_TOOL_NOT_CLAIMED:
		return _jobs.tool_gate_into(row, _math) and _math.value != Jobs.GATE_NOT_REQUIRED \
			and _work.tool_lot_of(resident) == NULL_REF
	return false


func work_tick_refusal(job: Vector2i) -> StringName:
	"""Direct Work calls require actual paid primary ownership; ordinary unrelated Jobs are unchanged."""
	if _composition_refusal() != &"":
		return REFUSE_AUTHORITY
	var row: int = _job_row(job)
	if row < 0:
		return &""  # Work supplies its established stale-Job refusal.
	if _job_slot[row] < 0:
		if _construction.purpose_into(_jobs.requester_of(row), _math) and Construction.is_modular(_math.value):
			return REFUSE_JOB
		return &""
	if _busy or _bound_job(row) != job:
		return REFUSE_JOB
	var project: Vector2i = _project(row)
	var code: StringName = _bound_refusal(project, row)
	if code == &"":
		code = _crew_refusal(project, row, true)
	if code == &"":
		code = _productive_refusal(project, row)
	if code != &"":
		discard_work_tick(job)
	return code


func _productive_refusal(project: Vector2i, row: int) -> StringName:
	"""Hot proof reads only retained owner state and actual physical readers, with no cold quote."""
	var code: StringName = _bound_refusal(project, row)
	if code != &"":
		return code
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _funding.is_funded(project) or not _construction.phase_into(project, _math) \
			or _math.value != Construction.PHASE_WORKING:
		return Construction.REFUSE_WRONG_PHASE
	_construction.remaining_mwu_into(project, _math)
	if not _jobs.remaining_mwu_into(row, _other) or _other.value != _math.value:
		return REFUSE_JOB
	var mass: int = _funding.reserved_output_mass_g(project)
	var output: Vector2i = _funding.output_container(project)
	if mass < 0 or mass > 0 and (not _inventory.container_reachable(output) \
			or _inventory.container_reserved_mass_g(output) < mass):
		return REFUSE_OUTPUT
	return _project_owner(project).transition_refusal(project, PRODUCTIVE)


func accept_work_tick(job: Vector2i) -> void:
	"""Accept only real Work's synchronous commit; a manually reduced Job counter grants no labor."""
	if _composition_refusal() != &"" or _busy or not _work.is_publishing_modular_tick(job):
		return
	var row: int = _job_row(job)
	if row < 0 or _bound_job(row) != job or _jobs.is_member(row):
		return
	var project: Vector2i = _project(row)
	if _project_owner(project) == null:
		return
	_construction.remaining_mwu_into(project, _math)
	_jobs.remaining_mwu_into(row, _other)
	var accepted: int = _math.value - _other.value
	if accepted <= 0:
		discard_work_tick(job)
		return
	_busy = true
	_allow(project, ACTION_WORK)
	var applied: bool = _construction.add_work_mwu_into(project, accepted, _math)
	assert(applied, "preflighted actual Work publication cannot fail after XP/wear commits")
	_disallow()
	_publish(project, PRODUCTIVE, _project_owner(project))
	_busy = false


func discard_work_tick(job: Vector2i) -> void:
	"""A different or stale Job cannot discard the prepared stage owned by an accepted primary."""
	if _ready_error != &"" or _busy:
		return
	var row: int = _job_row(job)
	if row < 0 or _bound_job(row) != job or _jobs.is_member(row):
		return
	var owner: Owner = _project_owner(_project(row))
	if owner != null:
		owner.discard_transition(_project(row), PRODUCTIVE)


func resume_work(project: Vector2i) -> Construction.OpResult:
	"""Revalidate actual replacement workers and contact without paying an already funded bill twice."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	var row: int = _primary_row(project) if _ready_error == &"" else NO_ROW
	var code: StringName = _bound_refusal(project, row)
	if code != &"":
		return _refuse(code)
	if _construction.is_paused(project) or not _funding.is_funded(project):
		return _refuse(Construction.REFUSE_PAUSED if _construction.is_paused(project) else REFUSE_DELIVERY)
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_WORKING:
		return _refuse(Construction.REFUSE_WRONG_PHASE)
	_construction.remaining_mwu_into(project, _math)
	if not _jobs.remaining_mwu_into(row, _other) or _other.value != _math.value:
		return _refuse(REFUSE_JOB)
	_busy = true
	var owner: Owner = _project_owner(project)
	code = _crew_refusal(project, row, false)
	if code == &"":
		code = owner.transition_refusal(project, START)
	if code != &"":
		return _discard_finish(project, START, owner, code)
	_start_job_states(project, row)
	owner.discard_transition(project, START)
	return _finish(_ok(project))


func set_paused(project: Vector2i, paused: bool) -> Construction.OpResult:
	"""Hold actual work immediately and release actual workers/unfinished claims without erasing WIP."""
	if _busy or _composition_refusal() != &"" or _project_owner(project) == null:
		return _refuse(REFUSE_AUTHORITY)
	_busy = true
	var changed: Construction.OpResult = _construction.set_paused(project, paused)
	if not changed.ok or not paused:
		return _finish(changed)
	var primary: int = _primary_row(project)
	var code: StringName = _stop_refusal(project, primary, false)
	if code == &"":
		code = _release_claims(project)
	if code != &"":
		return _finish(_refuse(code))
	_release_workers(project)
	return _finish(_ok(project))


func complete_order(project: Vector2i, promotion_tile: int = -1) -> Construction.OpResult:
	"""Commit real output exactly once, then physical source/install and safe Job/project retirement."""
	if _busy:
		return _refuse(REFUSE_BUSY)
	var primary: int = _primary_row(project) if _ready_error == &"" else NO_ROW
	var code: StringName = _bound_refusal(project, primary)
	if code != &"":
		return _refuse(code)
	_busy = true
	var owner: Owner = _project_owner(project)
	code = _completion_refusal(project, primary, promotion_tile, owner)
	if code != &"":
		return _discard_finish(project, COMMIT, owner, code)
	_allow(project, ACTION_OUTPUT)
	var result: Inventory.OpResult = _funding.commit_modular_outputs(project, promotion_tile)
	_disallow()
	if not result.ok:
		return _discard_finish(project, COMMIT, owner, result.error)
	_release_workers(project)
	_publish(project, COMMIT, owner)
	_retire(project, primary)
	return _finish(_ok(project))


func _completion_refusal(project: Vector2i, primary: int, tile: int, owner: Owner) -> StringName:
	"""All fallible identity, worker-release, source and output decisions precede Inventory commit."""
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_WORK_DONE \
			or not _funding.is_funded(project):
		return Construction.REFUSE_WRONG_PHASE
	if not _jobs.remaining_mwu_into(primary, _math) or _math.value != 0:
		return REFUSE_JOB
	var code: StringName = _stop_refusal(project, primary, true)
	if code == &"":
		code = project_facts_into(project, _quote)
	if code == &"":
		code = owner.transition_refusal(project, COMMIT)
	return _cold_output_refusal(project, primary, _funding.output_container(project), tile, owner) \
		if code == &"" else code


func cancel_order(project: Vector2i, refund_container: Vector2i = NULL_REF,
		promotion_tile: int = -1) -> Construction.OpResult:
	"""Freeze actual work; blocked refund retains WIP, and source locks release only after settlement."""
	if _busy or _composition_refusal() != &"" or _project_owner(project) == null:
		return _refuse(REFUSE_AUTHORITY)
	_busy = true
	var primary: int = _primary_row(project)
	var owner: Owner = _project_owner(project)
	var code: StringName = _cancellation_refusal(project, primary, refund_container, promotion_tile, owner)
	if code != &"":
		return _discard_finish(project, CANCEL, owner, code)
	_construction.phase_into(project, _math)
	if _math.value != Construction.PHASE_REFUNDING:
		_allow(project, ACTION_CANCEL)
		var frozen: Construction.OpResult = _construction.begin_refund(project)
		assert(frozen.ok, "preflighted cancellation must freeze before refund")
		_disallow()
	_release_workers(project)
	code = _settle_cancellation(project, refund_container, promotion_tile)
	if code != &"":
		return _discard_finish(project, CANCEL, owner, code)
	_publish(project, CANCEL, owner)
	_retire(project, primary)
	return _finish(_ok(project))


func _cancellation_refusal(project: Vector2i, primary: int, destination: Vector2i,
		tile: int, owner: Owner) -> StringName:
	"""Prepare cancellation without assuming that every accepted order has already bound workers."""
	var code: StringName = project_facts_into(project, _quote)
	if code == &"":
		code = _stop_refusal(project, primary, _funding.is_funded(project))
	if code == &"":
		code = owner.transition_refusal(project, CANCEL)
	if code == &"" and _funding.is_funded(project):
		code = _refund_contact_refusal(project, primary, destination, owner)
	if code == &"" and tile >= 0:
		if not _funding.is_funded(project):
			return REFUSE_OUTPUT
		code = _cold_output_refusal(project, primary, _funding.output_container(project), tile, owner)
	return code


func _refund_contact_refusal(project: Vector2i, primary: int, destination: Vector2i, owner: Owner) -> StringName:
	"""Only actual positive refund quantities require a destination and supported material contact."""
	var has_goods: bool = false
	for line: int in _quote.input_count:
		if not _construction.cancellation_refund_milli_into(project, line, _math):
			return REFUSE_DELIVERY
		has_goods = has_goods or _math.value > 0
	if not has_goods:
		return &""
	if primary < 0 or not _inventory.container_reachable(destination):
		return REFUSE_DELIVERY
	return owner.material_refusal(project, destination, _bound_job(primary))


func _settle_cancellation(project: Vector2i, destination: Vector2i, tile: int) -> StringName:
	"""Consumed goods refund atomically; unstarted goods merely lose their actual claims in place."""
	if not _funding.is_funded(project):
		return _release_claims(project)
	_allow(project, ACTION_REFUND)
	var refunded: Inventory.OpResult = _funding.refund_wip(project, destination, tile)
	_disallow()
	return &"" if refunded.ok else refunded.error


func _stop_refusal(project: Vector2i, primary: int, require_no_claims: bool) -> StringName:
	"""Cold finite scans catch every accepted or late requester Job and actual tool/worker claim."""
	if _inventory.is_transaction_open():
		return Inventory.REFUSE_TRANSACTION_OPEN
	for row: int in JOB_CAPACITY:
		if _project(row) == project:
			var code: StringName = _bound_stop_refusal(project, primary, row, require_no_claims)
			if code != &"":
				return code
		elif _jobs.is_job_present(row) and (_jobs.requester_of(row) == project \
				or primary >= 0 and _jobs.coordinator_of(row) == _bound_job(primary)):
			return REFUSE_JOB
	return _all_tool_claims_refusal(project)


func _bound_stop_refusal(project: Vector2i, primary: int, row: int, no_claims: bool) -> StringName:
	"""A bound stale or detached row never disappears from lifecycle ownership silently."""
	if primary < 0 or _job_row(_bound_job(row)) != row or _jobs.requester_of(row) != project:
		return REFUSE_JOB
	if row == primary and _jobs.is_member(row):
		return REFUSE_JOB
	if row != primary and _jobs.coordinator_of(row) != _bound_job(primary):
		return REFUSE_JOB
	if no_claims and _pool.job_claim_count(_bound_job(row)) > 0:
		return REFUSE_DELIVERY
	var worker: Vector2i = _jobs.worker_of(row)
	if worker == NULL_REF:
		return &""
	if not _jobs.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return REFUSE_WORKER
	var resident: int = _jobs.directory().get_typed_row(worker)
	if _work.residents().ref_of(resident) != worker or _jobs.job_of(resident) != _bound_job(row):
		return REFUSE_WORKER
	var tool: Vector2i = _work.tool_lot_of(resident)
	if tool != NULL_REF and (_work.tool_job_of(resident) != _bound_job(row) \
			or _work.gear().claim_job_of(tool) != _bound_job(row)):
		return Work.REFUSE_TOOL_CLAIM_STALE
	return &""


func _all_tool_claims_refusal(project: Vector2i) -> StringName:
	"""Cold actual Gear scan detects orphan claims even if another caller detached the Job worker."""
	for resident: int in Work.RESIDENT_CAPACITY:
		var job: Vector2i = _work.tool_job_of(resident)
		var row: int = _job_row(job)
		if row >= 0 and _project(row) == project and _jobs.job_of(resident) != job:
			return Work.REFUSE_TOOL_CLAIM_STALE
	for slot: int in _inventory.canonical_capacities().y:
		var lot: Vector2i = _work.gear().recorded_lot_ref_at_lot_slot(slot)
		if lot == NULL_REF:
			continue
		var job: Vector2i = _work.gear().claim_job_of(lot)
		var row: int = _job_row(job)
		if row < 0 or _project(row) != project:
			continue
		var worker: Vector2i = _work.gear().owner_of(lot)
		var resident: int = _jobs.directory().get_typed_row(worker)
		if resident < 0 or _work.residents().ref_of(resident) != worker \
				or _work.tool_job_of(resident) != job or _work.tool_lot_of(resident) != lot \
				or _jobs.worker_of(row) != worker:
			return Work.REFUSE_TOOL_CLAIM_STALE
	return &""


func _release_claims(project: Vector2i) -> StringName:
	"""Release only this accepted crew's unfinished leases; paid WIP is owned by Funding instead."""
	for row: int in JOB_CAPACITY:
		if _project(row) == project and _pool.job_claim_count(_bound_job(row)) > 0:
			var result: Inventory.OpResult = _pool.release_job_claims(_bound_job(row), _inventory)
			if not result.ok:
				return result.error
	return &""


func _release_workers(project: Vector2i) -> void:
	"""Apply only a preflighted release; durability and integer wear/XP carries are preserved."""
	for row: int in JOB_CAPACITY:
		if _project(row) != project:
			continue
		var worker: Vector2i = _jobs.worker_of(row)
		if worker == NULL_REF:
			continue
		var resident: int = _jobs.directory().get_typed_row(worker)
		if _work.tool_lot_of(resident) != NULL_REF:
			var released: Work.OpResult = _work.release_tool_claim(resident)
			assert(released.ok, "preflighted actual tool claim release cannot fail")
		var detached: Jobs.OpResult = _jobs.release_worker(resident)
		assert(detached.ok, "preflighted actual worker release cannot fail")
	if not _construction.is_paused(project):
		_construction.set_assigned_count(project, 0)


func _retire(project: Vector2i, primary: int) -> void:
	"""After physical publication, perform no bill/facts read that installation or closure invalidated."""
	for row: int in JOB_CAPACITY:
		if row != primary and _project(row) == project:
			var removed: Jobs.OpResult = _jobs.destroy_job(row)
			assert(removed.ok, "preflighted member retirement cannot fail after physical commit")
			_clear_binding(row)
	if primary >= 0:
		var removed: Jobs.OpResult = _jobs.destroy_job(primary)
		assert(removed.ok, "preflighted primary retirement cannot fail after physical commit")
		_clear_binding(primary)
	_allow(project, ACTION_RETIRE)
	var retired: Construction.OpResult = _construction.retire_modular_phase(project, self)
	assert(retired.ok, "preflighted paid accounting retirement cannot fail after physical commit")
	_disallow()


func _finish(result: Construction.OpResult) -> Construction.OpResult:
	"""Close all synchronous mutation state on success and refusal."""
	_disallow()
	_busy = false
	return result


func _discard_finish(project: Vector2i, action: int, owner: Owner, code: StringName) -> Construction.OpResult:
	"""A failed transaction drops only prepared candidate scratch, never persistent ownership or WIP."""
	owner.discard_transition(project, action)
	return _finish(_refuse(code))


func embedded_earth_milli() -> int:
	"""Read actual tip stock once; an expired tip owner never becomes assumed zero."""
	if _composition_refusal() != &"":
		return -1
	if _tip_owner == null:
		return 0
	var owner: Owner = _owner_for(Construction.PURPOSE_SPOIL_TIP)
	return owner.embedded_earth_milli() if owner != null else -1


func legacy_save_refusal() -> StringName:
	"""The composed codec must include accepted Jobs and actual owner rebinding, even after payment."""
	return REFUSE_SAVE


func state_bytes() -> PackedByteArray:
	"""Local refusal/reuse image, not a save codec; includes exactly four authoritative columns."""
	var image: PackedByteArray = _job_slot.to_byte_array()
	image.append_array(_job_generation.to_byte_array())
	image.append_array(_project_slot.to_byte_array())
	image.append_array(_project_generation.to_byte_array())
	return image


func _ok(project: Vector2i) -> Construction.OpResult:
	"""Cold convenience result; productive paths use reusable scalar readers."""
	return Construction.OpResult.new(true, &"", 0, project)


func _refuse(code: StringName) -> Construction.OpResult:
	"""Explicit refusal never lends the previous operation's handle to a caller."""
	return Construction.OpResult.new(false, code, 0, NULL_REF)
