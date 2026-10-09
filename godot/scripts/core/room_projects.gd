extends RefCounted
## Project-scoped room editing holds over the real Construction/Jobs/Reservations owners.
##
## This adapter does not excavate, charge materials, complete a room, or erase a physical site.
## Construction currently has no generic excavation-phase API (decision 1053). Its real project
## reference is this record's identity; no second entity allocator or paid ledger is introduced.
## A room type cannot change during that identity's lifetime. Completed-room identity and the
## ECON-001 physical ledger belong to the following integration, not to this editing hold.
##
## Route all pause writes for registered projects through set_player_paused/request_revision/
## discard_revision. The legacy Construction boolean cannot detect another same-value writer.
## Dispatch must use can_dispatch_work before productive work, deliveries, or new job assignment.
## Acknowledgement observes worker release and claims; it does not certify terrain/topology edits.
## The caller must safely withdraw workers through movement before releasing their Job ownership.
## Acknowledgement and revision-state inspection scan the bounded Jobs store. They are cold,
## event-driven command/owner-change checks, not per-frame HUD readers; cache the UI snapshot.

const Construction := preload("res://scripts/core/construction.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const PROJECT_CAPACITY: int = Construction.CONSTRUCTION_CAPACITY
const JOB_CAPACITY: int = Jobs.JOB_CAPACITY
const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const NO_ROW: int = EntityDirectory.NULL_SLOT
const INT32_MAX: int = 2147483647
const PAUSE_PLAYER: int = 1
const PAUSE_REVISION: int = 2
const REVISION_NONE: int = 0
const REVISION_REQUESTED: int = 1
const REVISION_ACKNOWLEDGED: int = 2
const REFUSE_NONE: StringName = &""
const REFUSE_OWNER_MISMATCH: StringName = &"ROOM_PROJECT_OWNER_MISMATCH"
const REFUSE_STALE_PROJECT: StringName = &"ROOM_PROJECT_STALE"
const REFUSE_UNREGISTERED: StringName = &"ROOM_PROJECT_NOT_REGISTERED"
const REFUSE_ALREADY_REGISTERED: StringName = &"ROOM_PROJECT_ALREADY_REGISTERED"
const REFUSE_RETIRE_REQUIRED: StringName = &"ROOM_PROJECT_OLD_RECORD_NOT_RETIRED"
const REFUSE_ROOM_TYPE: StringName = &"ROOM_PROJECT_UNKNOWN_ROOM_TYPE"
const REFUSE_PAUSE_DRIFT: StringName = &"ROOM_PROJECT_UNOWNED_PAUSE_WRITE"
const REFUSE_REVISION_TOKEN: StringName = &"ROOM_PROJECT_REVISION_TOKEN_STALE"
const REFUSE_REVISION_ABSENT: StringName = &"ROOM_PROJECT_NO_REVISION"
const REFUSE_REVISION_OVERFLOW: StringName = &"ROOM_PROJECT_REVISION_EXHAUSTED"
const REFUSE_PROJECT_LIVE: StringName = &"ROOM_PROJECT_STILL_LIVE"
const REFUSE_BOUND_JOBS: StringName = &"ROOM_PROJECT_JOBS_STILL_BOUND"
const REFUSE_JOB_STALE: StringName = &"ROOM_PROJECT_JOB_STALE"
const REFUSE_JOB_OWNER: StringName = &"ROOM_PROJECT_JOB_OWNER_MISMATCH"
const REFUSE_JOB_BOUND: StringName = &"ROOM_PROJECT_JOB_ALREADY_BOUND"
const REFUSE_JOB_UNBOUND: StringName = &"ROOM_PROJECT_JOB_NOT_BOUND"
const REFUSE_JOB_LATE: StringName = &"ROOM_PROJECT_UNBOUND_OWNED_JOB"
const REFUSE_WORKER: StringName = &"ROOM_PROJECT_WORKER_NOT_RELEASED"
const REFUSE_ACTIVE_JOB: StringName = &"ROOM_PROJECT_JOB_NOT_STOPPED"
const REFUSE_CLAIMS: StringName = &"ROOM_PROJECT_CLAIMS_NOT_RELEASED"
const REFUSE_ASSIGNED: StringName = &"ROOM_PROJECT_BUILDERS_NOT_RELEASED"
const REFUSE_RESERVATION_KEY: StringName = &"ROOM_PROJECT_RESERVATION_KEY_UNREPRESENTABLE"

class OpResult extends RefCounted:
	var ok: bool = false
	var error: StringName = &""
	var value: int = 0

	func _init(p_error: StringName = &"", p_value: int = 0) -> void:
		"""Represent a command result without returning an ambiguous sentinel value."""
		ok = p_error == &""
		error = p_error
		value = p_value if ok else 0

var _construction: Construction = null
var _jobs: Jobs = null
var _reservations: Reservations = null
var _directory: EntityDirectory = null
var _owners_match: bool = false
var _present: PackedByteArray = PackedByteArray()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _room_type: PackedInt32Array = PackedInt32Array()
var _pause_reasons: PackedByteArray = PackedByteArray()
var _revision_state: PackedByteArray = PackedByteArray()
var _revision_epoch: PackedInt32Array = PackedInt32Array()
var _job_slot: PackedInt32Array = PackedInt32Array()
var _job_generation: PackedInt32Array = PackedInt32Array()
var _job_project_slot: PackedInt32Array = PackedInt32Array()
var _job_project_generation: PackedInt32Array = PackedInt32Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(construction: Construction, jobs: Jobs, reservations: Reservations) -> void:
	"""Borrow real owners; mismatched directories fail closed on every mutator."""
	_construction = construction
	_jobs = jobs
	_reservations = reservations
	if construction != null and jobs != null and reservations != null:
		_directory = construction.directory()
		_owners_match = jobs.directory() == _directory
	_allocate_columns()


func _allocate_columns() -> void:
	"""Use the existing owner capacities, with no independent room or layout-size cap."""
	_present.resize(PROJECT_CAPACITY)
	_project_slot.resize(PROJECT_CAPACITY)
	_project_generation.resize(PROJECT_CAPACITY)
	_room_type.resize(PROJECT_CAPACITY)
	_pause_reasons.resize(PROJECT_CAPACITY)
	_revision_state.resize(PROJECT_CAPACITY)
	_revision_epoch.resize(PROJECT_CAPACITY)
	_project_slot.fill(NO_ROW)
	_room_type.fill(NO_ROW)
	_job_slot.resize(JOB_CAPACITY)
	_job_generation.resize(JOB_CAPACITY)
	_job_project_slot.resize(JOB_CAPACITY)
	_job_project_generation.resize(JOB_CAPACITY)
	_job_slot.fill(NO_ROW)
	_job_project_slot.fill(NO_ROW)


func register_project(project: Vector2i, room_type: int) -> OpResult:
	"""Pin a type to a live paid-project identity, retaining any pre-existing player pause."""
	if not _owners_match:
		return OpResult.new(REFUSE_OWNER_MISMATCH)
	if not _construction.is_live_project(project):
		return OpResult.new(REFUSE_STALE_PROJECT)
	if room_type < 0 or room_type >= Buildings.ROOM_TYPE_COUNT:
		return OpResult.new(REFUSE_ROOM_TYPE)
	var row: int = _directory.get_typed_row(project)
	if _present[row] != 0:
		var code: StringName = REFUSE_ALREADY_REGISTERED if _record_ref(row) == project else REFUSE_RETIRE_REQUIRED
		return OpResult.new(code)
	_present[row] = 1
	_project_slot[row] = project.x
	_project_generation[row] = project.y
	_room_type[row] = room_type
	_pause_reasons[row] = PAUSE_PLAYER if _construction.is_paused(project) else 0
	return OpResult.new(REFUSE_NONE, row)


func is_registered(project: Vector2i) -> bool:
	"""A stale Construction generation never names its replacement's editing record."""
	return _project_refusal(project) == REFUSE_NONE


func room_type_into(project: Vector2i, out: IntMath.IntResult) -> bool:
	"""Read the immutable project room purpose; this grants no completed-room services."""
	return _read_i32(project, _room_type, out)


func revision_epoch_into(project: Vector2i, out: IntMath.IntResult) -> bool:
	"""Read the edit-session token, which never aliases a later revision session."""
	return _read_i32(project, _revision_epoch, out)


func revision_state_into(project: Vector2i, out: IntMath.IntResult) -> bool:
	"""Read acknowledgement conservatively; newly active workers or claims invalidate it."""
	var code: StringName = _project_refusal(project)
	if code != REFUSE_NONE:
		return _refuse_read(out, code)
	var row: int = _directory.get_typed_row(project)
	var state: int = _revision_state[row]
	if state == REVISION_ACKNOWLEDGED and _safe_stop_refusal(project) != REFUSE_NONE:
		state = REVISION_REQUESTED
	out.succeed(state)
	return true


func pause_reasons_into(project: Vector2i, out: IntMath.IntResult) -> bool:
	"""Expose the independent player/edit bits, refusing an observable legacy-writer drift."""
	var code: StringName = _pause_refusal(project)
	if code != REFUSE_NONE:
		return _refuse_read(out, code)
	out.succeed(_pause_reasons[_directory.get_typed_row(project)])
	return true


func set_player_paused(project: Vector2i, paused: bool) -> OpResult:
	"""Changing a player's hold cannot release an editing hold on the same project."""
	var code: StringName = _pause_refusal(project)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	var row: int = _directory.get_typed_row(project)
	var mask: int = _pause_reasons[row] | PAUSE_PLAYER if paused else _pause_reasons[row] & ~PAUSE_PLAYER
	var changed: Construction.OpResult = _construction.set_paused(project, mask != 0)
	if not changed.ok:
		return OpResult.new(changed.error)
	_pause_reasons[row] = mask
	return OpResult.new(REFUSE_NONE, mask)


func request_revision(project: Vector2i) -> OpResult:
	"""Pause this project's Construction work; return an epoch, never an immediate safe-stop claim."""
	var code: StringName = _pause_refusal(project)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	var row: int = _directory.get_typed_row(project)
	if _revision_state[row] != REVISION_NONE:
		return OpResult.new(REFUSE_NONE, _revision_epoch[row])
	if _revision_epoch[row] == INT32_MAX:
		return OpResult.new(REFUSE_REVISION_OVERFLOW)
	var changed: Construction.OpResult = _construction.set_paused(project, true)
	if not changed.ok:
		return OpResult.new(changed.error)
	_pause_reasons[row] |= PAUSE_REVISION
	_revision_epoch[row] += 1
	_revision_state[row] = REVISION_REQUESTED
	return OpResult.new(REFUSE_NONE, _revision_epoch[row])


func acknowledge_revision(project: Vector2i, epoch: int) -> OpResult:
	"""Acknowledge only after the actual owners report stopped workers and released claims."""
	var code: StringName = _revision_refusal(project, epoch)
	if code == REFUSE_NONE:
		code = _safe_stop_refusal(project)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	_revision_state[_directory.get_typed_row(project)] = REVISION_ACKNOWLEDGED
	return OpResult.new(REFUSE_NONE, epoch)


func discard_revision(project: Vector2i, epoch: int) -> OpResult:
	"""Explicit discard releases only this edit session's hold; it cannot cancel paid work."""
	var code: StringName = _revision_refusal(project, epoch)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	var row: int = _directory.get_typed_row(project)
	var mask: int = _pause_reasons[row] & ~PAUSE_REVISION
	var changed: Construction.OpResult = _construction.set_paused(project, mask != 0)
	if not changed.ok:
		return OpResult.new(changed.error)
	_pause_reasons[row] = mask
	_revision_state[row] = REVISION_NONE
	return OpResult.new(REFUSE_NONE, mask)


func can_dispatch_work(project: Vector2i) -> bool:
	"""Required dispatch gate for productive work, material starts, and new worker assignment."""
	if _pause_refusal(project) != REFUSE_NONE:
		return false
	return _pause_reasons[_directory.get_typed_row(project)] == 0


func bind_job(project: Vector2i, job: Vector2i) -> OpResult:
	"""Bind a real Job through its requester or actual party coordinator, rejecting conflicting owners."""
	var code: StringName = _project_refusal(project)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	var row: int = _live_job_row(job)
	if row == NO_ROW:
		return OpResult.new(REFUSE_JOB_STALE)
	if job.x >= _reservations.job_capacity():
		return OpResult.new(REFUSE_RESERVATION_KEY)
	if not _job_owned_by(row, project):
		return OpResult.new(REFUSE_JOB_OWNER)
	if _job_slot[row] != NO_ROW:
		return OpResult.new(REFUSE_JOB_BOUND)
	_job_slot[row] = job.x
	_job_generation[row] = job.y
	_job_project_slot[row] = project.x
	_job_project_generation[row] = project.y
	return OpResult.new(REFUSE_NONE, row)


func release_job_binding(project: Vector2i, job: Vector2i) -> OpResult:
	"""Forget a stopped, claim-free Job; a dead generation with leaked claims still refuses."""
	var row: int = _bound_job_row(project, job)
	if row == NO_ROW:
		return OpResult.new(REFUSE_JOB_UNBOUND)
	var code: StringName = _job_stop_refusal(row, false)
	if code != REFUSE_NONE:
		return OpResult.new(code)
	_clear_job(row)
	return OpResult.new()


func retire_record(project: Vector2i) -> OpResult:
	"""Retire metadata only after Construction retired the identity and all jobs are resolved."""
	if not _owners_match:
		return OpResult.new(REFUSE_OWNER_MISMATCH)
	if _construction.is_live_project(project):
		return OpResult.new(REFUSE_PROJECT_LIVE)
	var row: int = _stored_project_row(project)
	if row == NO_ROW:
		return OpResult.new(REFUSE_UNREGISTERED)
	for job_row: int in JOB_CAPACITY:
		if _job_project_ref(job_row) == project:
			return OpResult.new(REFUSE_BOUND_JOBS)
	_clear_project(row)
	return OpResult.new()


func _safe_stop_refusal(project: Vector2i) -> StringName:
	"""Inspect the live owners, including late jobs omitted from the explicit binding list."""
	var code: StringName = _pause_refusal(project)
	if code != REFUSE_NONE:
		return code
	if not _construction.assigned_count_into(project, _math) or _math.value != 0:
		return REFUSE_ASSIGNED
	for row: int in JOB_CAPACITY:
		if _job_project_ref(row) == project:
			code = _job_stop_refusal(row, true)
			if code != REFUSE_NONE:
				return code
		elif _jobs.is_job_present(row) and _job_relates_to(row, project):
			return REFUSE_JOB_LATE
	return REFUSE_NONE


func _job_stop_refusal(row: int, require_live: bool) -> StringName:
	"""Never infer safety from a cleared assigned-count or from a replaced Job slot."""
	var job: Vector2i = Vector2i(_job_slot[row], _job_generation[row])
	if _reservations.job_claim_count(job) != 0:
		return REFUSE_CLAIMS
	if _live_job_row(job) != row:
		return REFUSE_JOB_STALE if require_live else REFUSE_NONE
	if not _job_owned_by(row, _job_project_ref(row)):
		return REFUSE_JOB_OWNER
	if _jobs.worker_of(row) != NULL_REF:
		return REFUSE_WORKER
	if not _jobs.state_into(row, _math):
		return REFUSE_JOB_STALE
	var state: int = _math.value
	if state == Jobs.JOB_STATE_RESERVED or state == Jobs.JOB_STATE_TRAVEL or state == Jobs.JOB_STATE_WORK or state == Jobs.JOB_STATE_HAUL_OUTPUT:
		return REFUSE_ACTIVE_JOB
	return REFUSE_NONE


func _job_owned_by(row: int, project: Vector2i) -> bool:
	"""A party member belongs through its actual coordinator; it cannot hide behind a null requester."""
	var requester: Vector2i = _jobs.requester_of(row)
	if not _jobs.is_member(row):
		return requester == project
	var coordinator: int = _live_job_row(_jobs.coordinator_of(row))
	return coordinator != NO_ROW and _jobs.requester_of(coordinator) == project and (requester == NULL_REF or requester == project)


func _job_relates_to(row: int, project: Vector2i) -> bool:
	"""Even conflicting requester/coordinator ownership must invalidate a prior safe-stop claim."""
	if _jobs.requester_of(row) == project:
		return true
	if not _jobs.is_member(row):
		return false
	var coordinator: int = _live_job_row(_jobs.coordinator_of(row))
	return coordinator != NO_ROW and _jobs.requester_of(coordinator) == project


func _revision_refusal(project: Vector2i, epoch: int) -> StringName:
	"""A stale UI session may not release or acknowledge a later session's hold."""
	var code: StringName = _pause_refusal(project)
	if code != REFUSE_NONE:
		return code
	var row: int = _directory.get_typed_row(project)
	if _revision_state[row] == REVISION_NONE:
		return REFUSE_REVISION_ABSENT
	if epoch != _revision_epoch[row]:
		return REFUSE_REVISION_TOKEN
	return REFUSE_NONE


func _pause_refusal(project: Vector2i) -> StringName:
	"""Detect observable writes outside this registered project's pause owner."""
	var code: StringName = _project_refusal(project)
	if code != REFUSE_NONE:
		return code
	var paused: bool = _pause_reasons[_directory.get_typed_row(project)] != 0
	return REFUSE_NONE if _construction.is_paused(project) == paused else REFUSE_PAUSE_DRIFT


func _project_refusal(project: Vector2i) -> StringName:
	"""Resolve both the directory generation and this adapter's record identity."""
	if not _owners_match:
		return REFUSE_OWNER_MISMATCH
	if not _construction.is_live_project(project):
		return REFUSE_STALE_PROJECT
	var row: int = _directory.get_typed_row(project)
	if _present[row] != 1 or _record_ref(row) != project:
		return REFUSE_UNREGISTERED
	return REFUSE_NONE


func _live_job_row(job: Vector2i) -> int:
	"""A live directory row alone does not prove the Jobs store owns that generation."""
	if not _owners_match or not _directory.is_valid_of_kind(job, EntityDirectory.KIND_JOB):
		return NO_ROW
	var row: int = _directory.get_typed_row(job)
	return row if _jobs.is_job_present(row) and _jobs.ref_of(row) == job else NO_ROW


func _bound_job_row(project: Vector2i, job: Vector2i) -> int:
	"""Find a stored binding even after its Job has retired, without trusting a reused slot."""
	if not _owners_match or project == NULL_REF or job == NULL_REF:
		return NO_ROW
	for row: int in JOB_CAPACITY:
		if _job_slot[row] == job.x and _job_generation[row] == job.y and _job_project_ref(row) == project:
			return row
	return NO_ROW


func _stored_project_row(project: Vector2i) -> int:
	"""Retirement scans metadata because a dead directory ref no longer resolves its typed row."""
	if project == NULL_REF:
		return NO_ROW
	for row: int in PROJECT_CAPACITY:
		if _present[row] == 1 and _record_ref(row) == project:
			return row
	return NO_ROW


func _record_ref(row: int) -> Vector2i:
	"""Read the Construction reference whose type and holds are stored in this row."""
	return Vector2i(_project_slot[row], _project_generation[row])


func _job_project_ref(row: int) -> Vector2i:
	"""Read the job's generation-qualified project owner, or the canonical null reference."""
	return Vector2i(_job_project_slot[row], _job_project_generation[row])


func _read_i32(project: Vector2i, column: PackedInt32Array, out: IntMath.IntResult) -> bool:
	"""Read one project column with a refusal rather than a valid-looking zero."""
	var code: StringName = _project_refusal(project)
	if code != REFUSE_NONE:
		return _refuse_read(out, code)
	out.succeed(column[_directory.get_typed_row(project)])
	return true


func _refuse_read(out: IntMath.IntResult, code: StringName) -> bool:
	"""Reuse the caller's result object on hot read paths."""
	out.refuse(String(code))
	return false


func _clear_job(row: int) -> void:
	"""Canonicalize a retired binding so no generation or claim history aliases a new job."""
	_job_slot[row] = NO_ROW
	_job_generation[row] = 0
	_job_project_slot[row] = NO_ROW
	_job_project_generation[row] = 0


func _clear_project(row: int) -> void:
	"""Clear only a fully retired project record, preserving the real owners' accounts."""
	_present[row] = 0
	_project_slot[row] = NO_ROW
	_project_generation[row] = 0
	_room_type[row] = NO_ROW
	_pause_reasons[row] = 0
	_revision_state[row] = REVISION_NONE
	_revision_epoch[row] = 0


func state_bytes() -> PackedByteArray:
	"""Canonical local evidence image; not a save codec or permission to omit these columns."""
	var out: PackedByteArray = _present.duplicate()
	out.append_array(_project_slot.to_byte_array())
	out.append_array(_project_generation.to_byte_array())
	out.append_array(_room_type.to_byte_array())
	out.append_array(_pause_reasons)
	out.append_array(_revision_state)
	out.append_array(_revision_epoch.to_byte_array())
	out.append_array(_job_slot.to_byte_array())
	out.append_array(_job_generation.to_byte_array())
	out.append_array(_job_project_slot.to_byte_array())
	out.append_array(_job_project_generation.to_byte_array())
	return out
