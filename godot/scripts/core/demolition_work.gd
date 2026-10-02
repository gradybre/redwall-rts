extends RefCounted
## DEMO-CONTAIN-R01 step D6 (decision 0537): demolition work under BUILD, and the persisted
## "evacuate, then demolish" intent.
##
## `settlement_system.gd` is the coordinator (decision 0145); this store holds the two facts D6
## adds that belong to no other store, one row per Building typed row (BUILDING_CAPACITY = 1024),
## and the job bookkeeping the coordinator calls:
##
##   * THE WORK JOB. Blocker 4: "add demolition work under BUILD". Each admitted removal project
##     -- a building's demolition or one piece's removal, recorded on its building's admission
##     row (decision 0536's R2) -- gets ONE `JOB_KIND_BUILD` Job, linked here by its building's
##     row. Its `requester` is the project and its `destination` the subject; its
##     `remaining_mwu` starts at the project's own, and the bridge keeps the two in step: a tick
##     whose Job and project disagree is refused before anything is consumed
##     (`work_refusal()`), and every milli-WU `work.gd` accepts is credited to the project in the
##     same tick through `construction.add_work_mwu_into()` (`credit_work()`). The PROJECT is
##     the authority; the Job is how a resident is offered the work. Priority is the planner's
##     ruled ORDINARY_JOB_PRIORITY (3), urgency stays the ordinary bucket ("3 ordinary
##     production/construction"), and no minimum skill is invented (decision 0022's 0).
##   * ONE BUILDER PER PROJECT. GDD §5.9's "Maximum 4 builders/project" is a cap, and a solo Job
##     honours it. A party of up to `max_workers` needs decision 0017's coordinator to enter
##     JOB_STATE_WORK, and no document says who writes that; it is a proposal in 0537, not a
##     guess here.
##   * THE INTENT. When a building's demolition is refused because its stores hold goods or carry
##     a claim (stage 3 or 5), the player may order "evacuate, then demolish": the building's
##     directory ref is recorded on its row, and the coordinator retries *admit* once the
##     footprint's containers report empty. Keyed by the full ref, so a reused row never
##     inherits an intent.
##
## WHAT IS NOT HERE, AND WHY. The ruling's evacuation HAUL jobs. Physical hauling is task 06.4
## and it does not exist: no resident has a satchel container (GDD §4.2's "one carried
## container"), no rule says when one is made, nothing moves a Job out of RESERVED (no settlement
## movement; "work arrival requires the real contact"), and INV-GOODS-R01 forbids the gate moving
## goods itself ("no teleports"). Decision 0537 refuses that half by name rather than inventing
## it; the intent and its retry work with whatever empties the stores.
##
## NOTHING HERE TOUCHES INVENTORY, and nothing here completes or cancels a project: that is the
## coordinator's (`complete_demolition()`, `complete_furniture_removal()`, the two cancels).

const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const BUILDING_CAPACITY: int = BuildingsScript.BUILDING_CAPACITY
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

## Blocker 4: "add demolition work under BUILD".
const REMOVAL_JOB_KIND: int = JobsScript.JOB_KIND_BUILD
## The planner's ruled "Ordinary newly generated work has priority 3" (task 03 rulings).
const REMOVAL_JOB_PRIORITY: int = JobPlannerScript.ORDINARY_JOB_PRIORITY
## Decision 0022: 0 is "no minimum experience"; no document states one for demolition.
const REMOVAL_REQUIRED_SKILL: int = 0

const REFUSE_NONE: StringName = &""
const REFUSE_STALE_BUILDING: StringName = &"EVACUATION_STALE_BUILDING"
const REFUSE_NOT_ORDERED: StringName = &"EVACUATION_NOT_ORDERED"
const REFUSE_NOT_REMOVAL: StringName = &"DEMOLITION_WORK_NOT_A_REMOVAL"
const REFUSE_ALREADY_POSTED: StringName = &"DEMOLITION_WORK_ALREADY_POSTED"
const REFUSE_WRONG_PHASE: StringName = &"DEMOLITION_WORK_WRONG_PHASE"
const REFUSE_PAUSED: StringName = &"DEMOLITION_WORK_PROJECT_PAUSED"
const REFUSE_SUBJECT_LOST: StringName = &"DEMOLITION_WORK_SUBJECT_LOST"
const REFUSE_OUT_OF_STEP: StringName = &"DEMOLITION_WORK_OUT_OF_STEP"
const REFUSE_NO_WORK: StringName = &"DEMOLITION_WORK_NOTHING_TO_CREDIT"

var _directory: EntityDirectory = null
var _jobs: JobsScript = null
var _construction: ConstructionScript = null
var _buildings: BuildingsScript = null
var _intent_slot: PackedInt32Array = PackedInt32Array()
var _intent_generation: PackedInt32Array = PackedInt32Array()
var _job_slot: PackedInt32Array = PackedInt32Array()
var _job_generation: PackedInt32Array = PackedInt32Array()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(jobs: JobsScript, construction: ConstructionScript) -> void:
	"""Borrow the settlement's Job and Construction stores, which share one directory."""
	_jobs = jobs
	_construction = construction
	_directory = jobs.directory()
	_buildings = construction.buildings()
	assert(_directory == construction.directory(), "jobs and construction share one directory")
	_intent_slot.resize(BUILDING_CAPACITY)
	_intent_generation.resize(BUILDING_CAPACITY)
	_job_slot.resize(BUILDING_CAPACITY)
	_job_generation.resize(BUILDING_CAPACITY)
	clear()


func clear() -> void:
	"""Forget every intent and every job link. The Job rows themselves are the Job store's."""
	_intent_slot.fill(NULL_REF.x)
	_intent_generation.fill(NULL_REF.y)
	_job_slot.fill(NULL_REF.x)
	_job_generation.fill(NULL_REF.y)


func row_of(building_ref: Vector2i) -> int:
	"""The Building typed row a live building ref names, or -1. The coordinator's one reader."""
	return _row_of(building_ref)


func _row_of(building_ref: Vector2i) -> int:
	"""The Building typed row a live building ref names, or -1."""
	if not _directory.is_valid_of_kind(building_ref, EntityDirectory.KIND_BUILDING):
		return -1
	return _directory.get_typed_row(building_ref)


# --- the evacuate-then-demolish intent ------------------------------------------------------------

func order_intent(building_ref: Vector2i) -> StringName:
	"""Record "evacuate, then demolish" for a live building. Ordering it twice changes nothing.

	The coordinator decides WHEN an order may be recorded (a goods-stage refusal); this store
	only refuses a stale building.
	"""
	var row: int = _row_of(building_ref)
	if row < 0:
		return REFUSE_STALE_BUILDING
	_intent_slot[row] = building_ref.x
	_intent_generation[row] = building_ref.y
	return REFUSE_NONE


func cancel_intent(building_ref: Vector2i) -> StringName:
	"""Withdraw a building's order. Refuses a stale building and a building with no order."""
	var row: int = _row_of(building_ref)
	if row < 0:
		return REFUSE_STALE_BUILDING
	if intent_building_at(row) != building_ref:
		return REFUSE_NOT_ORDERED
	drop_intent_at(row)
	return REFUSE_NONE


func has_intent(building_ref: Vector2i) -> bool:
	"""Whether this live building carries an "evacuate, then demolish" order."""
	var row: int = _row_of(building_ref)
	return row >= 0 and intent_building_at(row) == building_ref


func intent_building_at(row: int) -> Vector2i:
	"""The building ref recorded on `row`, live or not, or the null ref when none is recorded."""
	if row < 0 or row >= BUILDING_CAPACITY:
		return NULL_REF
	return Vector2i(_intent_slot[row], _intent_generation[row])


func drop_intent(building_ref: Vector2i) -> void:
	"""Forget a live building's order, if it carries one: its demolition has been admitted."""
	drop_intent_at(_row_of(building_ref))


func drop_intent_at(row: int) -> void:
	"""Forget `row`'s order: admitted, cancelled, or its building gone. Out of range is a no-op."""
	if row < 0 or row >= BUILDING_CAPACITY:
		return
	_intent_slot[row] = NULL_REF.x
	_intent_generation[row] = NULL_REF.y


func intent_count() -> int:
	"""How many rows carry an order, live or stale. A cold count for tests and notices."""
	var count: int = 0
	for row: int in BUILDING_CAPACITY:
		if _intent_slot[row] != NULL_REF.x:
			count += 1
	return count


# --- the work Job ---------------------------------------------------------------------------------

func is_removal_project(project_ref: Vector2i) -> bool:
	"""A live demolition or piece-removal project. Allocation-free."""
	if not _construction.purpose_into(project_ref, _read):
		return false
	return ConstructionScript.is_removal(_read.value)


func building_of_project(project_ref: Vector2i) -> Vector2i:
	"""The building whose admission row records this removal: the subject, or the piece's building."""
	if not _construction.purpose_into(project_ref, _read):
		return NULL_REF
	var subject: Vector2i = _construction.subject_ref_of(project_ref)
	if _read.value == ConstructionScript.PURPOSE_DEMOLISH:
		return subject
	if _read.value != ConstructionScript.PURPOSE_REMOVE_FURNITURE:
		return NULL_REF
	return _buildings.room_building_ref_of(_buildings.room_ref_of_furniture(subject))


func job_at(row: int) -> Vector2i:
	"""The live Job linked to `row`, or the null ref (no link, or a Job the store has retired)."""
	if row < 0 or row >= BUILDING_CAPACITY:
		return NULL_REF
	var job: Vector2i = Vector2i(_job_slot[row], _job_generation[row])
	if not _directory.is_valid_of_kind(job, EntityDirectory.KIND_JOB):
		return NULL_REF
	return job


func job_of(building_ref: Vector2i) -> Vector2i:
	"""The live work Job of a live building's admitted removal, or the null ref."""
	return job_at(_row_of(building_ref))


func post_refusal(project_ref: Vector2i) -> StringName:
	"""Why `post_job()` would refuse right now, or REFUSE_NONE. Writes nothing.

	A Job is posted only for a live removal project with work outstanding, in READY or WORKING,
	not paused (REQ-SET-137 releases workers, so none is offered), whose subject stands, and
	whose building row has no live Job linked yet.
	"""
	if not is_removal_project(project_ref):
		return REFUSE_NOT_REMOVAL
	var row: int = _row_of(building_of_project(project_ref))
	if row < 0:
		return REFUSE_SUBJECT_LOST
	if job_at(row) != NULL_REF:
		return REFUSE_ALREADY_POSTED
	var code: StringName = _workable_refusal(project_ref)
	if code != REFUSE_NONE:
		return code
	if not _construction.remaining_mwu_into(project_ref, _read) or _read.value <= 0:
		return REFUSE_WRONG_PHASE
	return REFUSE_NONE


func post_job(project_ref: Vector2i, created_tick: int) -> StringName:
	"""Publish the one BUILD Job for an admitted removal and link it to its building's row.

	Its work total is the project's outstanding milli-WU. A refusal by the Job store (its 8192
	rows full, say) is returned as is and links nothing; the coordinator retries later.
	"""
	var code: StringName = post_refusal(project_ref)
	if code != REFUSE_NONE:
		return code
	_construction.remaining_mwu_into(project_ref, _read)
	var created: JobsScript.OpResult = _jobs.create_job(REMOVAL_JOB_KIND, REMOVAL_JOB_PRIORITY,
		REMOVAL_REQUIRED_SKILL, _read.value, created_tick)
	if not created.ok:
		return created.error
	code = _bind_job(created.value, project_ref)
	if code != REFUSE_NONE:
		_jobs.destroy_job(created.value)
		return code
	var row: int = _row_of(building_of_project(project_ref))
	_job_slot[row] = created.ref.x
	_job_generation[row] = created.ref.y
	return REFUSE_NONE


func _bind_job(job_slot: int, project_ref: Vector2i) -> StringName:
	"""Point a new Job at its project (requester) and the subject it removes (destination)."""
	var bound: JobsScript.OpResult = _jobs.set_requester(job_slot, project_ref)
	if not bound.ok:
		return bound.error
	bound = _jobs.set_destination(job_slot, _construction.subject_ref_of(project_ref))
	return bound.error


func retire_job_at(row: int) -> void:
	"""Release `row`'s linked Job (`retire_job()`) and clear the link once the row is gone.

	A link to a Job already gone is simply cleared. A Job the store refuses to destroy keeps its
	link, so it is never left live and unlinked; that refusal is a guard `retire_job()` reports.
	"""
	if row < 0 or row >= BUILDING_CAPACITY:
		return
	var job: Vector2i = job_at(row)
	if job != NULL_REF and not retire_job(_directory.get_typed_row(job)):
		return
	_job_slot[row] = NULL_REF.x
	_job_generation[row] = NULL_REF.y


func retire_job(job_slot: int) -> bool:
	"""Free one Job's worker, then destroy its row. True when the row is gone.

	Decision 0017 keeps departure and cancellation apart, so the worker is released first and
	`destroy_job()` then refuses nothing. No CANCELLED state is written first: the row is
	destroyed in the same call, so no reader could ever see it. A refusal (a stale slot, which the
	callers rule out) is logged and reported.
	"""
	if not _jobs.is_job_present(job_slot):
		return false
	var worker: Vector2i = _jobs.worker_of(job_slot)
	if worker != NULL_REF:
		var released: JobsScript.OpResult = _jobs.release_worker(_directory.get_typed_row(worker))
		if not released.ok:
			push_error("DemolitionWork: a removal Job's worker refused release (%s)" % released.error)
	var destroyed: JobsScript.OpResult = _jobs.destroy_job(job_slot)
	if not destroyed.ok:
		push_error("DemolitionWork: a released removal Job refused destruction (%s)" % destroyed.error)
	return destroyed.ok


func is_orphaned_removal_job(job_slot: int) -> bool:
	"""A BUILD Job no coordinator link resolves and no live non-removal project requests.

	D6 is the only producer of BUILD Jobs, and REQ-SET-124's build jobs for new construction do
	not exist yet; so a BUILD Job requested by a removal project, or by nothing live, that is not
	its row's linked Job can never be credited. The coordinator must neither tick it as ordinary
	work (its milli-WU would credit no project) nor leave it holding a worker.
	"""
	if not _jobs.kind_into(job_slot, _read) or _read.value != REMOVAL_JOB_KIND:
		return false
	if project_of_job(job_slot) != NULL_REF:
		return false
	var requester: Vector2i = _jobs.requester_of(job_slot)
	return is_removal_project(requester) or not _construction.is_live_project(requester)


func retire_job_of(building_ref: Vector2i) -> void:
	"""`retire_job_at()` for a live building's row; a stale building has no row to retire."""
	var row: int = _row_of(building_ref)
	if row >= 0:
		retire_job_at(row)


func linked_job_is_stale(row: int, project_ref: Vector2i) -> bool:
	"""Whether `row`'s linked Job must be retired before the project is offered again.

	A Job CANCELLED by a player's CANCEL_JOB (the job, not the demolition: that is the
	coordinator's cancel), a Job serving some other project, and a Job that could not take work
	now (`work_refusal()`: paused, out of step) are all stale. No link is not stale.
	"""
	var job: Vector2i = job_at(row)
	if job == NULL_REF:
		return false
	var job_slot: int = _directory.get_typed_row(job)
	if _jobs.requester_of(job_slot) != project_ref:
		return true
	if not _jobs.state_into(job_slot, _read) or _read.value == JobsScript.JOB_STATE_CANCELLED:
		return true
	return work_refusal(job_slot, project_ref) != REFUSE_NONE


func is_quiet_row(row: int) -> bool:
	"""No order and no Job link on `row`: nothing for the reconcile to do but an admission."""
	return _intent_slot[row] == NULL_REF.x and _job_slot[row] == NULL_REF.x


func project_of_job(job_slot: int) -> Vector2i:
	"""The removal project a linked work Job serves, or the null ref. Allocation-free, per tick.

	Only a BUILD Job whose requester is a live removal project AND which is the Job linked on
	that project's building row qualifies, so a stray BUILD Job can never be credited twice.
	"""
	if not _jobs.kind_into(job_slot, _read) or _read.value != REMOVAL_JOB_KIND:
		return NULL_REF
	var project: Vector2i = _jobs.requester_of(job_slot)
	if not is_removal_project(project):
		return NULL_REF
	var job: Vector2i = job_at(_row_of(building_of_project(project)))
	if job == NULL_REF or _directory.get_typed_row(job) != job_slot:
		return NULL_REF
	return project


func work_refusal(job_slot: int, project_ref: Vector2i) -> StringName:
	"""Why this tick's work must not be taken, BEFORE `work.gd` consumes any. Writes nothing.

	The project must accept the credit (`_workable_refusal()`), and the Job and the project must
	hold the same outstanding milli-WU, so the work `work.gd` accepts is exactly what the project
	retires and the Job completes on the tick the project's work is done.
	"""
	var code: StringName = _workable_refusal(project_ref)
	if code != REFUSE_NONE:
		return code
	if not _construction.remaining_mwu_into(project_ref, _read):
		return StringName(_read.error)
	var project_left: int = _read.value
	if not _jobs.remaining_mwu_into(job_slot, _read):
		return StringName(_read.error)
	return REFUSE_NONE if _read.value == project_left else REFUSE_OUT_OF_STEP


func _workable_refusal(project_ref: Vector2i) -> StringName:
	"""READY or WORKING, not paused, its subject still standing: what `credit_work()` needs."""
	if not _construction.phase_into(project_ref, _read):
		return StringName(_read.error)
	if _read.value != ConstructionScript.PHASE_READY \
			and _read.value != ConstructionScript.PHASE_WORKING:
		return REFUSE_WRONG_PHASE
	if _construction.is_paused(project_ref):
		return REFUSE_PAUSED
	var subject: Vector2i = _construction.subject_ref_of(project_ref)
	if not _buildings.is_live_building(subject) and not _buildings.is_live_furniture(subject):
		return REFUSE_SUBJECT_LOST
	return REFUSE_NONE


func credit_work(project_ref: Vector2i, accepted_mwu: int) -> StringName:
	"""Credit one tick's accepted milli-WU to the project; begin its work on the first credit.

	REQ-SET-125's `begin_work()` runs on the first tick that produced work, never at admission
	("as progress begins"); a removal has no bill, so it only moves READY to WORKING. That one
	call allocates; every later credit is `add_work_mwu_into()`.
	"""
	if accepted_mwu <= 0:
		return REFUSE_NO_WORK
	if not _construction.phase_into(project_ref, _read):
		return StringName(_read.error)
	if _read.value == ConstructionScript.PHASE_READY:
		var begun: ConstructionScript.OpResult = _construction.begin_work(project_ref)
		if not begun.ok:
			return begun.error
	if not _construction.add_work_mwu_into(project_ref, accepted_mwu, _read):
		return StringName(_read.error)
	return REFUSE_NONE


func finished_project_at(row: int) -> Vector2i:
	"""The project of `row`'s linked Job once that Job is COMPLETE, else the null ref."""
	var job: Vector2i = job_at(row)
	if job == NULL_REF:
		return NULL_REF
	var job_slot: int = _directory.get_typed_row(job)
	if not _jobs.state_into(job_slot, _read) or _read.value != JobsScript.JOB_STATE_COMPLETE:
		return NULL_REF
	return _jobs.requester_of(job_slot)


func state_bytes() -> PackedByteArray:
	"""Every column, for byte-identical refusal checks. Test use; allocates."""
	var out: PackedByteArray = PackedByteArray()
	out.append_array(var_to_bytes(_intent_slot))
	out.append_array(var_to_bytes(_intent_generation))
	out.append_array(var_to_bytes(_job_slot))
	out.append_array(var_to_bytes(_job_generation))
	return out
