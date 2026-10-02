extends "res://test/framework/test_case.gd"
## DEMO-CONTAIN-R01 step D6 (decision 0537), composed: the coordinator posts each admitted
## removal's BUILD Job in the planner slot, credits its productive ticks to the project, commits
## the removal through its own door when the Job completes, retries a commit-pending removal and
## an "evacuate, then demolish" order on the hour, and retires the Job on every way out.
##
## Nothing in the running game moves a Job to JOB_STATE_WORK (no settlement movement), so the
## productive-tick tests stand in for arrival exactly as `test_settlement_system.gd`'s do: bind
## the worker and write WORK. Everything after that is the real tick.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const DemolitionWorkScript := preload("res://scripts/core/demolition_work.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const WELL_TILE: int = 50 * 128 + 30
const HALL_TILE: int = 20 * 128 + 20
const INSIDE_TILE: int = 24 * 128 + 25
const DEPOT_TILE: int = 60 * 128 + 90
const START_MASK: int = 1
## A tick that is not an hour crossing, and two that are (ARCH-TICK-002's (k+4500) mod 750).
const PLAIN_TICK: int = 101
const HOUR_TICK: int = 750
const NEXT_HOUR_TICK: int = 1500
## The well's demolition work: a quarter of its 240 WU, in milli-WU.
const WELL_DEMOLITION_MWU: int = 60000
## The well's 50% return: wood 5 U and stone 10 U at 5000 g/U.
const WELL_RETURN_G: int = 75000

var _settlement: SettlementSystemScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _depot_store: Vector2i = InventoryScript.NULL_REF


func before_each() -> void:
	"""The §5.1 cohort, so a work Job can carry a worker, and a depot to take a return."""
	_settlement = SettlementSystemScript.new()
	assert_true(_settlement.create_initial_settlement(), "the cohort spawns")
	var depot: Vector2i = _place_active("covered_store", DEPOT_TILE)
	_depot_store = _store(depot, DEPOT_TILE)


func after_each() -> void:
	"""Free it."""
	if _settlement != null:
		_settlement.free()
		_settlement = null


# --- fixtures --------------------------------------------------------------------------------

func _place_active(key: String, tile: int) -> Vector2i:
	"""Place one ACTIVE building of `key` at `tile`."""
	var placed: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION[key]), tile, 0, START_MASK)
	assert_true(placed.ok, "%s places (%s)" % [key, placed.error])
	assert_true(_settlement.buildings().set_building_state(placed.ref,
		ConstructionScript.STATE_ACTIVE).ok, "%s is ACTIVE" % key)
	return placed.ref


func _store(owner_ref: Vector2i, anchor: int) -> Vector2i:
	"""One accept-all 500000 g container keyed to `owner_ref`, anchored at `anchor`."""
	var made: InventoryScript.OpResult = _settlement.inventory().create_container(owner_ref,
		500000, InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, anchor)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _grain(container: Vector2i) -> Vector2i:
	"""Two units of grain in `container`."""
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var lot: InventoryScript.OpResult = _settlement.inventory().create_lot(container, grain, 2000,
		0, 0, 0, 0, 0)
	assert_true(lot.ok, "grain is stored (%s)" % lot.error)
	return lot.ref


func _admitted_well() -> Vector2i:
	"""An admitted well; return the well."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	assert_true(_settlement.request_demolition(well).ok, "the well is admitted")
	return well


func _job_of(building: Vector2i) -> int:
	"""The building's linked work Job slot, or -1."""
	var job: Vector2i = _settlement.demolition_work().job_of(building)
	if job == EntityDirectoryScript.NULL_REF:
		return -1
	return _settlement.directory().get_typed_row(job)


func _project_of(building: Vector2i) -> Vector2i:
	"""The building's admitted project."""
	return _settlement.demolition_admissions().project_of(building)


func _project_left(project: Vector2i) -> int:
	"""A project's outstanding milli-WU."""
	assert_true(_settlement.construction().remaining_mwu_into(project, _read), "it reads")
	return _read.value


func _phase(project: Vector2i) -> int:
	"""A project's phase."""
	assert_true(_settlement.construction().phase_into(project, _read), "phase reads")
	return _read.value


func _working(job_slot: int, resident_slot: int) -> void:
	"""Stand in for arrival: bind `resident_slot` at a work hour and put the Job in WORK.

	Whoever the selector may already have reserved is released first, so the test names its own
	builder whatever the stagger did on the posting tick.
	"""
	_reserve(job_slot, resident_slot)
	assert_true(_settlement.jobs().set_state(job_slot, JobsScript.JOB_STATE_WORK).ok, "WORK")


func _reserve(job_slot: int, resident_slot: int) -> void:
	"""Bind `resident_slot` to the Job (RESERVED), releasing any worker the selector chose."""
	var held: Vector2i = _settlement.jobs().worker_of(job_slot)
	if held != EntityDirectoryScript.NULL_REF:
		assert_true(_settlement.jobs().release_worker(
			_settlement.directory().get_typed_row(held)).ok, "the selector's choice is released")
	_settlement.schedule().resolve(resident_slot, 8, false)
	assert_true(_settlement.jobs().assign_worker(resident_slot, job_slot).ok, "a worker binds")


func _dirty_the_reconcile(other: Vector2i = EntityDirectoryScript.NULL_REF) -> void:
	"""Admit an unrelated building, so the next tick's reconcile walks its rows off the hour.

	Pass one placed earlier when a row is about to be freed: a new building could take it.
	"""
	if other == EntityDirectoryScript.NULL_REF:
		other = _place_active("open_stockpile", 90 * 128 + 10)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(other)
	assert_true(report.ok, "an unrelated admission (%s)" % report.error)


func _retire_around_the_coordinator(well: Vector2i) -> void:
	"""Retire a well's admitted demolition through construction's own doors, then clear its record.

	The shape `release_stranded_reservation()` exists for, finished by hand so no D6 hook runs.
	"""
	var project: Vector2i = _project_of(well)
	var grams: int = _settlement.demolition_admissions().unreleased_reserved_g_of(well)
	var store: Vector2i = _settlement.demolition_admissions().unreleased_output_of(well)
	assert_true(_settlement.construction().begin_refund(project).ok, "refunding around D6")
	assert_true(_settlement.construction().close_demolition_refund(project).ok, "retired")
	assert_true(_settlement.inventory().release_container_mass(store, grams).ok, "claim freed")
	assert_equal(_settlement.demolition_admissions().release(well),
		DemolitionWorkScript.REFUSE_NONE, "record cleared")


func _leave_only(project: Vector2i, job_slot: int, left: int) -> void:
	"""Advance a project to `left` milli-WU outstanding and keep its Job in step."""
	var construction: ConstructionScript = _settlement.construction()
	assert_true(construction.begin_work(project).ok, "work begins")
	assert_true(construction.add_work_mwu(project, _project_left(project) - left).ok, "advanced")
	assert_true(_settlement.jobs().set_remaining_mwu(job_slot, left).ok, "the Job kept in step")


# --- posting -----------------------------------------------------------------------------------

func test_an_admission_writes_no_job_and_the_next_planner_tick_posts_one() -> void:
	"""`request_demolition()` itself touches no Job; the reconcile before selection does."""
	var count: int = _settlement.job_queue_length()
	var well: Vector2i = _admitted_well()
	assert_equal(_settlement.job_queue_length(), count, "admit posts nothing itself")
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	assert_true(job >= 0, "the planner tick posted the work Job")
	assert_equal(_settlement.job_queue_length(), count + 1, "exactly one")
	assert_equal(_settlement.jobs().kind_of(job).value, JobsScript.JOB_KIND_BUILD, "BUILD")
	assert_equal(_settlement.jobs().created_tick_of(job).value, PLAIN_TICK, "on that tick")
	assert_equal(_settlement.jobs().requester_of(job), _project_of(well), "for the project")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.job_queue_length(), count + 1, "and never a second")


func test_a_piece_removal_posts_its_job_at_the_piece() -> void:
	"""A single piece's removal is worked the same way; the Job's destination is the piece."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	assert_true(_settlement.request_furniture_removal(bed.ref).ok, "the bed's removal is admitted")
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(hall)
	assert_true(job >= 0, "posted on the hall's row")
	assert_equal(_settlement.jobs().destination_of(job), bed.ref, "at the bed")


func test_a_quiet_tick_with_nothing_admitted_does_not_walk_the_rows() -> void:
	"""Off the hour and with nothing dirty the reconcile returns at once: nothing is posted."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	assert_true(_settlement.demolition_admissions().record(well,
		_settlement.construction().open_demolition(well).ref, InventoryScript.NULL_REF, 0, 0)
		== DemolitionWorkScript.REFUSE_NONE, "an admission recorded around the request door")
	_settlement.run_tick(PLAIN_TICK)
	assert_equal(_job_of(well), -1, "not dirty, not the hour: nothing posted")
	_settlement.run_tick(HOUR_TICK)
	assert_true(_job_of(well) >= 0, "the hour's reconcile finds it")


func test_selection_offers_the_work_job_and_reserves_a_builder() -> void:
	"""At a work hour the ordinary selector binds a resident: the Job is real demand."""
	var well: Vector2i = _admitted_well()
	var first: int = 2250
	for offset: int in 31:
		_settlement.run_tick(first + offset)
	var job: int = _job_of(well)
	assert_equal(_settlement.jobs().state_of(job).value, JobsScript.JOB_STATE_RESERVED,
		"a builder is reserved")
	assert_true(_settlement.jobs().worker_of(job) != EntityDirectoryScript.NULL_REF, "named")


# --- the productive tick -------------------------------------------------------------------------

func test_each_productive_tick_is_credited_to_the_project_in_step() -> void:
	"""The project begins on the first tick and retires exactly what the Job accepted."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	_settlement.run_tick(PLAIN_TICK + 1)
	var accepted: int = _settlement.accepted_mwu_last_tick()
	assert_true(accepted > 0, "work was accepted")
	assert_equal(_phase(project), ConstructionScript.PHASE_WORKING, "the work has begun")
	assert_equal(_project_left(project), WELL_DEMOLITION_MWU - accepted, "the project retired it")
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, _project_left(project),
		"in step with the Job")
	_settlement.run_tick(PLAIN_TICK + 2)
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, _project_left(project),
		"still in step")


func test_a_tick_work_gd_refuses_after_consuming_still_reaches_the_project() -> void:
	"""Crediting the measured loss: an XP overflow after the consume keeps Job and project in step."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	assert_true(_settlement.residents().set_skill_xp(0, JobsScript.JOB_KIND_BUILD,
		9223372036854775800).ok, "XP one step from overflowing")
	for tick: int in range(PLAIN_TICK + 1, PLAIN_TICK + 30):
		_settlement.run_tick(tick)
	assert_true(_project_left(project) < WELL_DEMOLITION_MWU, "work was consumed and credited")
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, _project_left(project), "in step")


func test_a_final_tick_refused_after_consuming_still_commits() -> void:
	"""The Job spent to 0 by a tick `work.gd` refused is marked COMPLETE and committed anyway.

	Exactly 1000 milli-WU are left and the builder's XP carry starts empty, so the whole WU --
	and the overflowing XP credit -- falls on the final tick, whatever the builder's rate.
	"""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	_working(job, 0)
	_leave_only(_project_of(well), job, 1000)
	assert_true(_settlement.residents().set_skill_xp(0, JobsScript.JOB_KIND_BUILD,
		9223372036854775800).ok, "XP one step from overflowing")
	var tick: int = PLAIN_TICK + 1
	while _settlement.buildings().is_live_building(well) and tick < PLAIN_TICK + 40:
		_settlement.run_tick(tick)
		tick += 1
	assert_false(_settlement.buildings().is_live_building(well), "committed on the spending tick")
	assert_true(tick < HOUR_TICK, "well before any hourly retry")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the builder freed")


func test_a_reserved_job_produces_nothing() -> void:
	"""RESERVED is not WORK: no milli-WU moves on the Job or the project."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	_reserve(job, 0)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "nothing accepted")
	assert_equal(_project_left(_project_of(well)), WELL_DEMOLITION_MWU, "nothing retired")


func test_a_job_out_of_step_takes_no_work_and_is_replaced_on_the_hour() -> void:
	"""Work credited around the Job: the tick consumes nothing; the hour reposts the remainder."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	assert_true(_settlement.construction().begin_work(project).ok, "begun around the Job")
	assert_true(_settlement.construction().add_work_mwu(project, 1000).ok, "and advanced")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "nothing consumed")
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, WELL_DEMOLITION_MWU, "Job intact")
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(job_ref), "the stale Job is retired")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "its worker freed")
	assert_equal(_settlement.jobs().remaining_mwu_of(_job_of(well)).value,
		WELL_DEMOLITION_MWU - 1000, "and the new Job carries the remainder")


func test_a_paused_project_takes_no_work_and_loses_its_job_on_the_hour() -> void:
	"""REQ-SET-137: a paused project releases its workers; nothing is offered until it resumes."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	assert_true(_settlement.construction().set_paused(project, true).ok, "paused")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "no work while paused")
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_job_of(well), -1, "no Job is offered while paused")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the worker freed")
	assert_true(_settlement.construction().set_paused(project, false).ok, "resumed")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_true(_job_of(well) >= 0, "the next hour offers it again")


# --- completion ----------------------------------------------------------------------------------

func test_the_last_productive_tick_commits_the_demolition_in_the_same_tick() -> void:
	"""The Job completes, the walk ends, the coordinator's commit removes the well and returns half."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	_leave_only(project, job, 10)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 10, "the last 10 milli-WU")
	assert_false(_settlement.buildings().is_live_building(well), "the well is gone")
	assert_false(_settlement.construction().is_live_project(project), "the project retired")
	assert_false(_settlement.directory().is_valid(job_ref), "the Job row is released")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the builder is free")
	assert_equal(_settlement.inventory().container_used_mass_g(_depot_store), WELL_RETURN_G,
		"its half landed in the reserved store")
	assert_equal(_settlement.inventory().container_reserved_mass_g(_depot_store), 0, "released")


func test_a_finished_piece_removal_commits_through_its_own_door() -> void:
	"""A bed's removal Job completing takes the bed out and returns half of its bill."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	assert_true(_settlement.request_furniture_removal(bed.ref).ok, "admitted")
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(hall)
	var project: Vector2i = _project_of(hall)
	_working(job, 0)
	_leave_only(project, job, 5)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_false(_settlement.buildings().is_live_furniture(bed.ref), "the bed is out")
	assert_true(_settlement.buildings().is_live_building(hall), "the hall stands")
	assert_equal(_project_of(hall), EntityDirectoryScript.NULL_REF, "the admission is released")
	assert_equal(_job_of(hall), -1, "no Job left on the hall's row")
	assert_true(_settlement.inventory().container_used_mass_g(_depot_store) > 0, "a return landed")


func test_a_refused_commit_stays_pending_and_the_hour_retries_it() -> void:
	"""Goods arrive after admission: the commit refuses, the Job is gone, the hour completes it."""
	var well: Vector2i = _admitted_well()
	var own: Vector2i = _store(well, WELL_TILE)
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var project: Vector2i = _project_of(well)
	_working(job, 0)
	_leave_only(project, job, 10)
	var lot: Vector2i = _grain(own)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_true(_settlement.buildings().is_live_building(well), "the commit refused: it stands")
	assert_equal(_phase(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")
	assert_equal(_job_of(well), -1, "and its finished Job retired")
	_settlement.run_tick(HOUR_TICK)
	assert_true(_settlement.buildings().is_live_building(well), "still stranded: still standing")
	assert_equal(_job_of(well), -1, "no Job is posted for finished work")
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	var retries: int = _settlement.removal_commit_retry_count()
	_dirty_the_reconcile()
	_settlement.run_tick(PLAIN_TICK + 2)
	assert_true(_settlement.buildings().is_live_building(well), "not retried off the hour")
	assert_equal(_settlement.removal_commit_retry_count(), retries, "even on a dirty tick")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_false(_settlement.buildings().is_live_building(well), "the hour's retry completes it")


# --- the ways out -------------------------------------------------------------------------------

func test_cancelling_the_demolition_retires_its_job_and_frees_the_builder() -> void:
	"""`cancel_demolition()` releases the claim, retires the project and now the Job too."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job_ref: Vector2i = _settlement.jobs().ref_of(_job_of(well))
	_working(_job_of(well), 0)
	assert_equal(_settlement.cancel_demolition(well), SettlementSystemScript.REFUSE_NONE,
		"cancelled")
	assert_false(_settlement.directory().is_valid(job_ref), "the Job is gone")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the builder is free")
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_job_of(well), -1, "and nothing is reposted")


func test_a_refused_cancellation_keeps_the_job() -> void:
	"""A cancellation that refuses writes nothing, the Job included."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var before: PackedByteArray = _settlement.demolition_work().state_bytes()
	assert_true(_settlement.inventory().begin().ok, "a caller's transaction is open")
	assert_equal(_settlement.cancel_demolition(well),
		SettlementSystemScript.REFUSE_DEMOLITION_TRANSACTION, "refused")
	_settlement.inventory().abort()
	assert_true(_settlement.demolition_work().state_bytes() == before, "the link stands")
	assert_true(_job_of(well) >= 0, "and the Job")


func test_cancelling_a_piece_removal_retires_its_job() -> void:
	"""`cancel_furniture_removal()` retires the hall row's Job."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	assert_true(_settlement.request_furniture_removal(bed.ref).ok, "admitted")
	_settlement.run_tick(PLAIN_TICK)
	assert_true(_job_of(hall) >= 0, "posted")
	assert_equal(_settlement.cancel_furniture_removal(bed.ref), SettlementSystemScript.REFUSE_NONE,
		"cancelled")
	assert_equal(_job_of(hall), -1, "the Job retired")


func test_a_cancel_job_command_cancels_the_job_not_the_demolition() -> void:
	"""CANCEL_JOB's own effect (worker released, CANCELLED); the hour retires it and reposts."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	_working(job, 0)
	assert_true(_settlement.jobs().release_worker(0).ok, "the command releases the worker")
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_CANCELLED).ok, "cancels")
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(job_ref), "the cancelled Job is retired")
	assert_true(_job_of(well) >= 0, "a fresh Job is offered")
	assert_true(_project_of(well) != EntityDirectoryScript.NULL_REF, "the demolition stands")


func test_a_completion_called_directly_retires_the_job_it_leaves_behind() -> void:
	"""`complete_demolition()` called by its other callers still releases the linked Job."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job_ref: Vector2i = _settlement.jobs().ref_of(_job_of(well))
	var project: Vector2i = _project_of(well)
	assert_true(_settlement.construction().begin_work(project).ok, "begins")
	assert_true(_settlement.construction().add_work_mwu(project, WELL_DEMOLITION_MWU).ok, "done")
	assert_true(_settlement.complete_demolition(well).ok, "completed directly")
	assert_false(_settlement.directory().is_valid(job_ref), "its Job is retired")


func test_a_piece_removal_completed_directly_retires_its_job() -> void:
	"""`complete_furniture_removal()` called by any caller releases the hall row's Job."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	assert_true(_settlement.request_furniture_removal(bed.ref).ok, "admitted")
	_settlement.run_tick(PLAIN_TICK)
	var job_ref: Vector2i = _settlement.jobs().ref_of(_job_of(hall))
	var project: Vector2i = _project_of(hall)
	assert_true(_settlement.construction().begin_work(project).ok, "begins")
	assert_true(_settlement.construction().add_work_mwu(project, _project_left(project)).ok, "done")
	assert_true(_settlement.complete_furniture_removal(bed.ref).ok, "completed directly")
	assert_false(_settlement.directory().is_valid(job_ref), "its Job is retired")


func test_work_finished_around_the_job_retires_it_on_the_hour_and_retries_the_commit() -> void:
	"""WORK_DONE with a Job still linked: the hour retires it and tries the commit once."""
	var well: Vector2i = _admitted_well()
	var lot: Vector2i = _grain(_store(well, WELL_TILE))
	_settlement.run_tick(PLAIN_TICK)
	var job_ref: Vector2i = _settlement.jobs().ref_of(_job_of(well))
	var project: Vector2i = _project_of(well)
	assert_true(_settlement.construction().begin_work(project).ok, "begins around the Job")
	assert_true(_settlement.construction().add_work_mwu(project, WELL_DEMOLITION_MWU).ok, "done")
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(job_ref), "the finished project's Job retired")
	assert_equal(_settlement.removal_commit_retry_count(), 1, "the commit was tried")
	assert_true(_settlement.buildings().is_live_building(well), "and refused: goods remain")
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_false(_settlement.buildings().is_live_building(well), "the next hour completes it")


func test_a_stranded_release_retires_the_job_of_an_orphaned_removal() -> void:
	"""A piece removed around the coordinator: the stranded door also retires its Job."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	assert_true(_settlement.request_furniture_removal(bed.ref).ok, "admitted")
	_settlement.run_tick(PLAIN_TICK)
	assert_true(_settlement.buildings().remove_furniture(bed.ref).ok, "removed around it")
	assert_equal(_settlement.release_stranded_reservation(hall), SettlementSystemScript.REFUSE_NONE,
		"the stranded door recovers it")
	assert_equal(_job_of(hall), -1, "and the Job is retired")


func test_a_job_whose_building_is_gone_takes_no_work_and_the_next_reconcile_retires_it() -> void:
	"""The building removed around D6: its Job is never worked again, and the hour frees it."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	var row: int = _settlement.directory().get_typed_row(well)
	var other: Vector2i = _place_active("open_stockpile", 90 * 128 + 10)
	_working(job, 0)
	assert_true(_settlement.buildings().demolish_building(well).ok, "the well goes around D6")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "no work for a project with no subject")
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, WELL_DEMOLITION_MWU, "untouched")
	_dirty_the_reconcile(other)
	_settlement.run_tick(PLAIN_TICK + 2)
	assert_false(_settlement.directory().is_valid(job_ref), "the next reconcile retires the Job")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "and frees its worker")
	assert_equal(_settlement.demolition_work().job_at(row), EntityDirectoryScript.NULL_REF, "unlinked")


func test_a_job_whose_admission_is_gone_takes_no_work_and_the_next_reconcile_retires_it() -> void:
	"""The project retired and the record cleared around the coordinator: same outcome."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	_working(job, 0)
	_retire_around_the_coordinator(well)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "no work for a retired project")
	_dirty_the_reconcile()
	_settlement.run_tick(PLAIN_TICK + 2)
	assert_false(_settlement.directory().is_valid(job_ref), "the next reconcile retires the Job")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "and frees its worker")
	_settlement.run_tick(HOUR_TICK)
	assert_true(_settlement.buildings().is_live_building(well), "the well stands")
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "and nobody ordered it down")
	assert_equal(_settlement.evacuation_retry_count(), 0, "no order, no retry")


func test_an_hour_that_clears_a_stale_link_retries_no_admission_without_an_order() -> void:
	"""The hour finds a link with no admission behind it: it retires the Job and admits nothing."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job_ref: Vector2i = _settlement.jobs().ref_of(_job_of(well))
	_retire_around_the_coordinator(well)
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(job_ref), "the Job is retired")
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "and the well is not admitted")
	assert_equal(_settlement.evacuation_retry_count(), 0, "nobody ordered it")


func test_a_readmitted_building_does_not_keep_the_old_projects_job() -> void:
	"""A link left by a removal retired around the coordinator is replaced, even when in step."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var old_ref: Vector2i = _settlement.jobs().ref_of(_job_of(well))
	_retire_around_the_coordinator(well)
	assert_true(_settlement.request_demolition(well).ok, "admitted again")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_false(_settlement.directory().is_valid(old_ref), "the old project's Job is retired")
	assert_equal(_settlement.jobs().requester_of(_job_of(well)), _project_of(well),
		"the new Job serves the new project")


func test_an_unlinked_build_job_is_never_worked_and_is_retired_on_the_hour() -> void:
	"""A BUILD Job naming the project but not linked (a stray) earns nothing and is swept."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var stray: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, WELL_DEMOLITION_MWU, PLAIN_TICK)
	assert_true(_settlement.jobs().set_requester(stray.value, _project_of(well)).ok, "a stray")
	var haul: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_HAUL,
		3, 0, 1000, PLAIN_TICK)
	_working(stray.value, 1)
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "the stray earns nothing")
	assert_equal(_project_left(_project_of(well)), WELL_DEMOLITION_MWU, "and credits nothing")
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(stray.ref), "swept on the hour")
	assert_equal(_settlement.jobs().job_of(1), EntityDirectoryScript.NULL_REF, "its worker freed")
	assert_true(_job_of(well) >= 0, "the linked Job stays")
	assert_true(_settlement.directory().is_valid(haul.ref), "and a HAUL Job is never swept")


func test_two_adjacent_orphans_are_both_swept_in_one_hour() -> void:
	"""The sweep walks the live index from the end, so a retirement never skips a neighbour."""
	_admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var a: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, 5, PLAIN_TICK)
	var b: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, 5, PLAIN_TICK)
	_settlement.run_tick(HOUR_TICK)
	assert_false(_settlement.directory().is_valid(a.ref), "the first swept")
	assert_false(_settlement.directory().is_valid(b.ref), "and its neighbour")


func test_a_working_job_without_a_worker_produces_nothing_and_logs_nothing() -> void:
	"""WORK with nobody bound: `work.gd` refuses, nothing is consumed and nothing is credited."""
	var well: Vector2i = _admitted_well()
	_settlement.run_tick(PLAIN_TICK)
	var job: int = _job_of(well)
	var held: Vector2i = _settlement.jobs().worker_of(job)
	if held != EntityDirectoryScript.NULL_REF:
		_settlement.jobs().release_worker(_settlement.directory().get_typed_row(held))
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_WORK).ok, "WORK, unbound")
	_settlement.run_tick(PLAIN_TICK + 1)
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "nothing accepted")
	assert_equal(_project_left(_project_of(well)), WELL_DEMOLITION_MWU, "nothing credited")
	assert_equal(_phase(_project_of(well)), ConstructionScript.PHASE_READY, "work never began")


# --- evacuate, then demolish -------------------------------------------------------------------

func test_an_order_on_a_goods_refusal_records_the_intent_and_keeps_the_notice() -> void:
	"""Stage 3: the refusal and its exact stranded lot stay in the report; nothing is admitted."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var lot: Vector2i = _grain(_store(well, WELL_TILE))
	var report: SettlementSystemScript.DemolitionReport = \
		_settlement.order_evacuate_then_demolish(well)
	assert_false(report.ok, "not admitted")
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS, "goods")
	assert_true(report.evacuation_ordered, "the order is recorded")
	assert_equal(report.stranded_lot_at(0), lot, "naming the lot")
	assert_true(_settlement.has_evacuation_intent(well), "it reads back")
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "no admission")


func test_an_order_on_a_claim_only_refusal_records_the_intent() -> void:
	"""A capacity claim on the building's store is a goods-stage refusal too."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	assert_true(_settlement.inventory().reserve_container_mass(own, 1000).ok, "claimed")
	var report: SettlementSystemScript.DemolitionReport = \
		_settlement.order_evacuate_then_demolish(well)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_CAPACITY_CLAIM, "claim")
	assert_true(report.evacuation_ordered, "the order is recorded")


func test_an_order_on_an_admissible_building_just_admits() -> void:
	"""Nothing to evacuate: the order is the demolition, and no intent is left behind."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var report: SettlementSystemScript.DemolitionReport = \
		_settlement.order_evacuate_then_demolish(well)
	assert_true(report.ok, "admitted")
	assert_false(report.evacuation_ordered, "no order was needed")
	assert_false(_settlement.has_evacuation_intent(well), "none recorded")


func test_the_report_flag_is_cleared_by_the_next_request() -> void:
	"""`evacuation_ordered` belongs to the request that set it, not to the shared report."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_grain(_store(well, WELL_TILE))
	assert_true(_settlement.order_evacuate_then_demolish(well).evacuation_ordered, "set")
	var other: Vector2i = _place_active("open_stockpile", 90 * 128 + 10)
	assert_false(_settlement.request_demolition(other).evacuation_ordered, "cleared by the next")


func test_an_order_on_any_other_refusal_records_nothing() -> void:
	"""Stage 1 (already demolishing) and a stale ref: returned unchanged, nothing written."""
	var well: Vector2i = _admitted_well()
	var before: PackedByteArray = _settlement.demolition_work().state_bytes()
	var report: SettlementSystemScript.DemolitionReport = \
		_settlement.order_evacuate_then_demolish(well)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_IN_PROGRESS, "stage 1")
	assert_false(report.evacuation_ordered, "no order")
	assert_equal(_settlement.order_evacuate_then_demolish(Vector2i(5, 9)).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STALE_BUILDING, "stale")
	assert_true(_settlement.demolition_work().state_bytes() == before, "byte-identical")


func test_the_evacuable_refusals_are_exactly_the_two_goods_stage_codes() -> void:
	"""`is_evacuable_refusal()`: stored goods and a claim; occupants, footprint, none."""
	assert_true(SettlementSystemScript.is_evacuable_refusal(
		SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS), "goods")
	assert_true(SettlementSystemScript.is_evacuable_refusal(
		SettlementSystemScript.REFUSE_DEMOLITION_CAPACITY_CLAIM), "a claim")
	assert_false(SettlementSystemScript.is_evacuable_refusal(
		ConstructionScript.REFUSE_OCCUPANTS_PRESENT), "not occupants")
	assert_false(SettlementSystemScript.is_evacuable_refusal(
		SettlementSystemScript.REFUSE_DEMOLITION_FOREIGN_CONTAINER), "not a foreign container")
	assert_false(SettlementSystemScript.is_evacuable_refusal(&""), "not a pass")


func test_the_hour_admits_once_the_sources_report_empty() -> void:
	"""Goods still there: no retry admits. Gone: the next hour admits and the order is spent."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var lot: Vector2i = _grain(_store(well, WELL_TILE))
	_settlement.order_evacuate_then_demolish(well)
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "goods remain: not admitted")
	assert_equal(_settlement.evacuation_retry_count(), 0, "and the gate was not even asked")
	assert_true(_settlement.has_evacuation_intent(well), "the order waits")
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	_dirty_the_reconcile()
	_settlement.run_tick(PLAIN_TICK)
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "not retried off the hour")
	assert_equal(_settlement.evacuation_retry_count(), 0, "even on a dirty tick")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_true(_project_of(well) != EntityDirectoryScript.NULL_REF, "the hour admits it")
	assert_false(_settlement.has_evacuation_intent(well), "and the order is spent")
	_settlement.run_tick(NEXT_HOUR_TICK + 1)
	assert_true(_job_of(well) >= 0, "the next tick posts its work Job")


func test_a_claim_left_on_the_footprint_keeps_the_order_waiting() -> void:
	"""Empty of lots but still claimed is not empty: the order is not retried."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	assert_true(_settlement.inventory().reserve_container_mass(own, 1000).ok, "claimed")
	_settlement.order_evacuate_then_demolish(well)
	_settlement.run_tick(HOUR_TICK)
	assert_true(_settlement.has_evacuation_intent(well), "still waiting")
	assert_equal(_settlement.evacuation_retry_count(), 0, "a claimed store is not empty")
	assert_true(_settlement.inventory().release_container_mass(own, 1000).ok, "released")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_false(_settlement.has_evacuation_intent(well), "now admitted")


func test_goods_in_a_rooms_store_on_the_footprint_are_a_source_too() -> void:
	"""The tile scan sees every container on the footprint, a room's included."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var lot: Vector2i = _grain(_store(room.ref, INSIDE_TILE))
	assert_true(_settlement.order_evacuate_then_demolish(hall).evacuation_ordered, "ordered")
	_settlement.run_tick(HOUR_TICK)
	assert_true(_settlement.has_evacuation_intent(hall), "the room's grain keeps it waiting")
	assert_equal(_settlement.evacuation_retry_count(), 0, "the gate was not asked")
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "gone")
	_settlement.run_tick(NEXT_HOUR_TICK)
	assert_false(_settlement.has_evacuation_intent(hall), "admitted")


func test_a_retry_refused_for_another_reason_keeps_the_order() -> void:
	"""Sources empty, but a resident now uses the bed: the retry refuses and the order waits."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	var lot: Vector2i = _grain(_store(hall, HALL_TILE))
	_settlement.order_evacuate_then_demolish(hall)
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	assert_true(_settlement.buildings().set_furniture_user(bed.ref,
		_settlement.residents().ref_of(0)).ok, "somebody sleeps there")
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_settlement.evacuation_retry_count(), 1, "the sources were empty: it retried")
	assert_equal(_project_of(hall), EntityDirectoryScript.NULL_REF, "the retry refused")
	assert_true(_settlement.has_evacuation_intent(hall), "the order still waits")


func test_cancel_evacuation_withdraws_the_order() -> void:
	"""Withdrawn orders are never retried; withdrawing twice refuses by name."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var lot: Vector2i = _grain(_store(well, WELL_TILE))
	_settlement.order_evacuate_then_demolish(well)
	assert_equal(_settlement.cancel_evacuation(well), DemolitionWorkScript.REFUSE_NONE, "withdrawn")
	assert_equal(_settlement.cancel_evacuation(well), DemolitionWorkScript.REFUSE_NOT_ORDERED,
		"twice")
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_project_of(well), EntityDirectoryScript.NULL_REF, "nothing is retried")


func test_an_admission_by_the_plain_request_spends_the_order() -> void:
	"""Whoever admits the building, the order is satisfied and forgotten."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var lot: Vector2i = _grain(_store(well, WELL_TILE))
	_settlement.order_evacuate_then_demolish(well)
	assert_true(_settlement.inventory().sink_lot_quantity(lot, 2000).ok, "the goods leave")
	assert_true(_settlement.request_demolition(well).ok, "admitted directly")
	assert_false(_settlement.has_evacuation_intent(well), "the order is spent")


func test_an_order_for_a_building_gone_around_the_coordinator_is_forgotten() -> void:
	"""The hour drops an order whose building row no longer holds that building."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	_grain(own)
	_settlement.order_evacuate_then_demolish(well)
	assert_true(_settlement.buildings().demolish_building(well).ok, "the well goes around D6")
	_settlement.run_tick(HOUR_TICK)
	assert_equal(_settlement.demolition_work().intent_count(), 0, "the order is forgotten")


func test_reset_forgets_orders_and_links() -> void:
	"""`reset()` clears D6's store with every other."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_grain(_store(well, WELL_TILE))
	_settlement.order_evacuate_then_demolish(well)
	var other: Vector2i = _place_active("open_stockpile", 90 * 128 + 10)
	assert_true(_settlement.request_demolition(other).ok, "another is admitted")
	_settlement.run_tick(PLAIN_TICK)
	var row: int = _settlement.directory().get_typed_row(other)
	assert_true(_settlement.demolition_work().job_at(row) != EntityDirectoryScript.NULL_REF, "linked")
	_settlement.reset()
	assert_equal(_settlement.demolition_work().intent_count(), 0, "no order")
	assert_equal(_settlement.demolition_work().state_bytes(), DemolitionWorkScript.new(
		_settlement.jobs(), _settlement.construction()).state_bytes(), "every column cleared")
	assert_equal(_settlement.evacuation_retry_count() + _settlement.removal_commit_retry_count(), 0,
		"and the counters")
