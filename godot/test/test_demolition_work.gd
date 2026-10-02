extends "res://test/framework/test_case.gd"
## DEMO-CONTAIN-R01 step D6 (decision 0537): `demolition_work.gd`, one test or more per public
## function, over the settlement's own composed stores (one directory, one Job store).
##
## The coordinator's composed behaviour -- posting on the planner tick, the productive-tick bridge,
## the commit, the hourly retries -- is `test_settlement_demolition_work.gd`.

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
## The well's §4.1 WU is 240; its demolition is a quarter of it, in milli-WU.
const WELL_DEMOLITION_MWU: int = 60000

var _settlement: SettlementSystemScript = null
var _work: DemolitionWorkScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A settlement with the §5.1 cohort, so a Job can carry a worker."""
	_settlement = SettlementSystemScript.new()
	assert_true(_settlement.create_initial_settlement(), "the cohort spawns")
	_work = _settlement.demolition_work()


func after_each() -> void:
	"""Free it."""
	_work = null
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


func _depot() -> void:
	"""Another ACTIVE building's store, so a return has somewhere to be reserved."""
	var depot: Vector2i = _place_active("covered_store", DEPOT_TILE)
	assert_true(_settlement.inventory().create_container(depot, 500000,
		InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, DEPOT_TILE).ok,
		"the depot store exists")


func _admitted_well() -> Vector2i:
	"""An admitted well demolition's project."""
	_depot()
	var well: Vector2i = _place_active("well", WELL_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(well)
	assert_true(report.ok, "the well is admitted (%s)" % report.error)
	return report.project_ref


func _row(building: Vector2i) -> int:
	"""A building's typed row."""
	return _settlement.directory().get_typed_row(building)


func _posted(project: Vector2i) -> int:
	"""Post the project's work Job and return its slot."""
	assert_equal(_work.post_job(project, 7), DemolitionWorkScript.REFUSE_NONE, "the Job posts")
	var job: Vector2i = _work.job_of(_work.building_of_project(project))
	assert_true(job != EntityDirectoryScript.NULL_REF, "and is linked")
	return _settlement.directory().get_typed_row(job)


func _working(job_slot: int, resident_slot: int) -> void:
	"""Stand in for arrival: bind a worker and put the Job in WORK, as the work tests do."""
	_settlement.schedule().resolve(resident_slot, 8, false)
	assert_true(_settlement.jobs().assign_worker(resident_slot, job_slot).ok, "a worker binds")
	assert_true(_settlement.jobs().set_state(job_slot, JobsScript.JOB_STATE_WORK).ok, "WORK")


func _project_left(project: Vector2i) -> int:
	"""A project's outstanding milli-WU."""
	assert_true(_settlement.construction().remaining_mwu_into(project, _read), "it reads")
	return _read.value


# --- the intent ------------------------------------------------------------------------------

func test_an_order_is_recorded_once_and_read_back_by_building_and_row() -> void:
	"""`order_intent()`, `has_intent()`, `intent_building_at()`, `intent_count()`."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	assert_false(_work.has_intent(well), "no order yet")
	assert_equal(_work.order_intent(well), DemolitionWorkScript.REFUSE_NONE, "ordered")
	assert_equal(_work.order_intent(well), DemolitionWorkScript.REFUSE_NONE, "again: no change")
	assert_true(_work.has_intent(well), "it reads back")
	assert_equal(_work.intent_building_at(_row(well)), well, "on the building's row")
	assert_equal(_work.intent_count(), 1, "one order")


func test_an_order_refuses_a_stale_building_and_writes_nothing() -> void:
	"""A ref the directory does not hold as a live Building is refused by name."""
	var before: PackedByteArray = _work.state_bytes()
	assert_equal(_work.order_intent(Vector2i(5, 9)), DemolitionWorkScript.REFUSE_STALE_BUILDING,
		"refused")
	assert_true(_work.state_bytes() == before, "byte-identical")
	assert_false(_work.has_intent(Vector2i(5, 9)), "and nothing reads back")


func test_cancelling_an_order_forgets_it_and_refuses_twice() -> void:
	"""`cancel_intent()`: once, then NOT_ORDERED; a stale building refuses STALE."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_work.order_intent(well)
	assert_equal(_work.cancel_intent(well), DemolitionWorkScript.REFUSE_NONE, "withdrawn")
	assert_false(_work.has_intent(well), "gone")
	assert_equal(_work.cancel_intent(well), DemolitionWorkScript.REFUSE_NOT_ORDERED, "twice")
	assert_equal(_work.cancel_intent(Vector2i(5, 9)), DemolitionWorkScript.REFUSE_STALE_BUILDING,
		"a stale building")


func test_an_order_does_not_survive_its_row_being_reused() -> void:
	"""Keyed by the full ref: the next building on the same row carries no order."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_work.order_intent(well)
	var row: int = _row(well)
	assert_true(_settlement.buildings().demolish_building(well).ok, "the well goes around D6")
	var next: Vector2i = _place_active("well", WELL_TILE)
	assert_equal(_row(next), row, "the row is reused")
	assert_false(_work.has_intent(next), "and the new well has no order")
	assert_equal(_work.cancel_intent(next), DemolitionWorkScript.REFUSE_NOT_ORDERED, "none")


func test_drop_intent_and_drop_intent_at_forget_an_order_and_ignore_bad_rows() -> void:
	"""Both drops forget; an out-of-range row or a building without an order is a no-op."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_work.order_intent(well)
	_work.drop_intent(well)
	assert_false(_work.has_intent(well), "dropped by building")
	_work.order_intent(well)
	_work.drop_intent_at(_row(well))
	assert_false(_work.has_intent(well), "dropped by row")
	var before: PackedByteArray = _work.state_bytes()
	_work.drop_intent_at(-1)
	_work.drop_intent_at(BuildingsScript.BUILDING_CAPACITY)
	_work.drop_intent(Vector2i(5, 9))
	assert_true(_work.state_bytes() == before, "the no-ops write nothing")
	assert_equal(_work.intent_building_at(-1), EntityDirectoryScript.NULL_REF, "row -1 names none")
	assert_equal(_work.intent_building_at(BuildingsScript.BUILDING_CAPACITY),
		EntityDirectoryScript.NULL_REF, "nor does the row past the end")


func test_clear_forgets_every_order_and_link() -> void:
	"""`clear()` returns every column to the null ref."""
	var project: Vector2i = _admitted_well()
	var well: Vector2i = _work.building_of_project(project)
	_work.order_intent(well)
	_posted(project)
	_work.clear()
	assert_equal(_work.intent_count(), 0, "no order")
	assert_equal(_work.job_of(well), EntityDirectoryScript.NULL_REF, "no link")


# --- projects --------------------------------------------------------------------------------

func test_a_demolition_and_a_piece_removal_are_removal_projects_and_name_their_building() -> void:
	"""`is_removal_project()` and `building_of_project()` for both removal purposes."""
	var project: Vector2i = _admitted_well()
	var well: Vector2i = _settlement.construction().subject_ref_of(project)
	assert_true(_work.is_removal_project(project), "a demolition is one")
	assert_equal(_work.building_of_project(project), well, "naming the well")
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	var removal: SettlementSystemScript.DemolitionReport = \
		_settlement.request_furniture_removal(bed.ref)
	assert_true(removal.ok, "the bed's removal is admitted (%s)" % removal.error)
	assert_true(_work.is_removal_project(removal.project_ref), "a piece removal is one")
	assert_equal(_work.building_of_project(removal.project_ref), hall, "naming the bed's hall")


func test_a_build_project_and_a_stale_ref_are_not_removals() -> void:
	"""Any other purpose, and a ref that names no project, answer false and the null building."""
	var blueprint: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), WELL_TILE, 0, START_MASK)
	var build: ConstructionScript.OpResult = _settlement.construction().open_build(blueprint.ref)
	assert_true(build.ok, "a BUILD project opens (%s)" % build.error)
	assert_false(_work.is_removal_project(build.ref), "a BUILD is not a removal")
	assert_equal(_work.building_of_project(build.ref), EntityDirectoryScript.NULL_REF, "none")
	assert_false(_work.is_removal_project(Vector2i(3, 7)), "a stale ref is not")
	assert_equal(_work.building_of_project(Vector2i(3, 7)), EntityDirectoryScript.NULL_REF, "none")


func test_a_piece_under_construction_names_no_building() -> void:
	"""A FURNITURE build project has a piece as subject, but it is no removal: no building row."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	var build: ConstructionScript.OpResult = _settlement.construction().open_furniture(bed.ref)
	assert_true(build.ok, "the bed's FURNITURE project opens (%s)" % build.error)
	assert_false(_work.is_removal_project(build.ref), "not a removal")
	assert_equal(_work.building_of_project(build.ref), EntityDirectoryScript.NULL_REF,
		"and it names no building row")
	assert_equal(_work.post_refusal(build.ref), DemolitionWorkScript.REFUSE_NOT_REMOVAL, "unpostable")


# --- posting -----------------------------------------------------------------------------------

func test_post_job_publishes_one_build_job_carrying_the_projects_work() -> void:
	"""The Job's kind, priority, skill, work total, tick, requester and destination."""
	var project: Vector2i = _admitted_well()
	var well: Vector2i = _work.building_of_project(project)
	assert_equal(_work.post_refusal(project), DemolitionWorkScript.REFUSE_NONE, "postable")
	var job: int = _posted(project)
	var jobs: JobsScript = _settlement.jobs()
	assert_equal(jobs.kind_of(job).value, JobsScript.JOB_KIND_BUILD, "a BUILD Job")
	assert_equal(jobs.priority_of(job).value, 3, "ordinary priority 3")
	assert_equal(jobs.required_skill_of(job).value, 0, "no minimum skill")
	assert_equal(jobs.remaining_mwu_of(job).value, WELL_DEMOLITION_MWU, "a quarter of 240 WU")
	assert_equal(jobs.created_tick_of(job).value, 7, "created on the tick given")
	assert_equal(jobs.urgency_of(job).value, JobsScript.URGENCY_ORDINARY, "ordinary urgency")
	assert_equal(jobs.requester_of(job), project, "requested by the project")
	assert_equal(jobs.destination_of(job), well, "at the well")
	assert_equal(jobs.state_of(job).value, JobsScript.JOB_STATE_QUEUED, "QUEUED")
	assert_equal(_work.job_at(_row(well)), jobs.ref_of(job), "linked on the well's row")


func test_post_job_refuses_a_second_job_and_every_unworkable_project() -> void:
	"""ALREADY_POSTED, NOT_A_REMOVAL, PAUSED, WRONG_PHASE (work done), each writing nothing."""
	var project: Vector2i = _admitted_well()
	_posted(project)
	var count: int = _settlement.jobs().job_count()
	assert_equal(_work.post_job(project, 8), DemolitionWorkScript.REFUSE_ALREADY_POSTED, "twice")
	assert_equal(_work.post_job(Vector2i(3, 7), 8), DemolitionWorkScript.REFUSE_NOT_REMOVAL,
		"a stale project")
	_work.retire_job_at(_row(_work.building_of_project(project)))
	assert_true(_settlement.construction().set_paused(project, true).ok, "paused")
	assert_equal(_work.post_refusal(project), DemolitionWorkScript.REFUSE_PAUSED, "paused")
	assert_true(_settlement.construction().set_paused(project, false).ok, "resumed")
	assert_true(_settlement.construction().begin_work(project).ok, "work begins")
	assert_true(_settlement.construction().add_work_mwu(project, WELL_DEMOLITION_MWU).ok, "done")
	assert_equal(_work.post_refusal(project), DemolitionWorkScript.REFUSE_WRONG_PHASE, "done")
	assert_equal(_settlement.jobs().job_count(), count - 1, "only the retirement changed jobs")


func test_a_working_project_posts_its_remaining_work_not_its_original_total() -> void:
	"""A reposted Job carries what is left, so Job and project start in step."""
	var project: Vector2i = _admitted_well()
	assert_true(_settlement.construction().begin_work(project).ok, "work begins")
	assert_true(_settlement.construction().add_work_mwu(project, 1234).ok, "some is done")
	var job: int = _posted(project)
	assert_equal(_settlement.jobs().remaining_mwu_of(job).value, WELL_DEMOLITION_MWU - 1234,
		"the remainder")


func test_a_refused_job_creation_links_nothing() -> void:
	"""A full KIND_JOB arena: the Job store's own refusal comes back and no link is written."""
	var project: Vector2i = _admitted_well()
	var jobs: JobsScript = _settlement.jobs()
	while jobs.job_count() < JobsScript.JOB_CAPACITY:
		assert_true(jobs.create_job(JobsScript.JOB_KIND_HAUL, 1, 0, 1, 0).ok, "filler")
	var before: PackedByteArray = _work.state_bytes()
	assert_true(_work.post_job(project, 9) != DemolitionWorkScript.REFUSE_NONE, "refused")
	assert_true(_work.state_bytes() == before, "no link")


# --- retiring ----------------------------------------------------------------------------------

func test_retiring_a_job_releases_its_worker_and_destroys_it() -> void:
	"""`retire_job_at()`: the worker is free, the Job row gone, the link cleared."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	_working(job, 0)
	var row: int = _row(_work.building_of_project(project))
	_work.retire_job_at(row)
	assert_false(_settlement.directory().is_valid(job_ref), "the Job row is released")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the worker is idle")
	assert_equal(_work.job_at(row), EntityDirectoryScript.NULL_REF, "the link is cleared")


func test_retire_job_of_a_live_building_and_the_no_op_cases() -> void:
	"""By building; a stale building, an unlinked row and an out-of-range row write nothing."""
	var project: Vector2i = _admitted_well()
	var well: Vector2i = _work.building_of_project(project)
	_posted(project)
	_work.retire_job_of(well)
	assert_equal(_work.job_of(well), EntityDirectoryScript.NULL_REF, "retired")
	var count: int = _settlement.jobs().job_count()
	var before: PackedByteArray = _work.state_bytes()
	_work.retire_job_of(well)
	_work.retire_job_of(Vector2i(5, 9))
	_work.retire_job_at(-1)
	_work.retire_job_at(BuildingsScript.BUILDING_CAPACITY)
	assert_true(_work.state_bytes() == before, "nothing written")
	assert_equal(_settlement.jobs().job_count(), count, "no Job touched")


func test_a_link_to_a_job_destroyed_elsewhere_reads_as_none_and_clears() -> void:
	"""`job_at()` validates the Job ref; retiring a dead link only clears it."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	var row: int = _row(_work.building_of_project(project))
	assert_true(_settlement.jobs().destroy_job(job).ok, "destroyed around D6")
	assert_equal(_work.job_at(row), EntityDirectoryScript.NULL_REF, "a dead link reads as none")
	_work.retire_job_at(row)
	assert_equal(_work.post_refusal(project), DemolitionWorkScript.REFUSE_NONE, "postable again")


# --- the per-tick bridge -----------------------------------------------------------------------

func test_project_of_job_names_only_the_linked_build_job() -> void:
	"""The linked Job names its project; another BUILD Job naming it, and a HAUL Job, do not."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	assert_equal(_work.project_of_job(job), project, "the linked Job")
	var stray: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, WELL_DEMOLITION_MWU, 0)
	assert_true(_settlement.jobs().set_requester(stray.value, project).ok, "a stray names it")
	assert_equal(_work.project_of_job(stray.value), EntityDirectoryScript.NULL_REF, "not linked")
	var haul: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_HAUL,
		3, 0, 1, 0)
	assert_true(_settlement.jobs().set_requester(haul.value, project).ok, "a HAUL names it")
	assert_equal(_work.project_of_job(haul.value), EntityDirectoryScript.NULL_REF, "not BUILD")
	assert_equal(_work.project_of_job(-1), EntityDirectoryScript.NULL_REF, "nor a bad slot")


func test_project_of_job_refuses_a_build_job_whose_requester_is_no_removal() -> void:
	"""A BUILD Job requested by nobody, or by a BUILD project, is not D6's."""
	var none: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, 1, 0)
	assert_equal(_work.project_of_job(none.value), EntityDirectoryScript.NULL_REF, "no requester")


func test_work_refusal_passes_a_job_in_step_and_names_each_refusal() -> void:
	"""In step: none. Paused, out of step, done and subject lost each refuse by name."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_NONE, "in step")
	assert_true(_settlement.construction().set_paused(project, true).ok, "paused")
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_PAUSED, "paused")
	assert_true(_settlement.construction().set_paused(project, false).ok, "resumed")
	assert_true(_settlement.jobs().set_remaining_mwu(job, WELL_DEMOLITION_MWU - 1).ok, "skewed")
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_OUT_OF_STEP,
		"one milli-WU apart")
	assert_true(_settlement.jobs().set_remaining_mwu(job, WELL_DEMOLITION_MWU + 1).ok, "skewed")
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_OUT_OF_STEP,
		"either way")
	assert_true(_settlement.construction().begin_work(project).ok, "begins")
	assert_true(_settlement.construction().add_work_mwu(project, WELL_DEMOLITION_MWU).ok, "done")
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_WRONG_PHASE, "done")


func test_work_refusal_refuses_a_subject_that_is_gone() -> void:
	"""A piece removed around the coordinator leaves a live project with no subject."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_depot()
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	var project: Vector2i = _settlement.request_furniture_removal(bed.ref).project_ref
	var job: int = _posted(project)
	assert_true(_settlement.buildings().remove_furniture(bed.ref).ok, "removed around D6")
	assert_equal(_work.work_refusal(job, project), DemolitionWorkScript.REFUSE_SUBJECT_LOST,
		"the subject is gone")
	assert_equal(_work.work_refusal(job, Vector2i(3, 7)),
		StringName(ConstructionScript.REFUSE_STALE_PROJECT_REF), "a stale project")


func test_credit_work_begins_the_work_once_and_then_only_adds() -> void:
	"""The first credit moves READY to WORKING; later credits only retire milli-WU."""
	var project: Vector2i = _admitted_well()
	assert_equal(_work.credit_work(project, 100), DemolitionWorkScript.REFUSE_NONE, "credited")
	assert_true(_settlement.construction().has_work_begun(project), "work has begun")
	assert_equal(_project_left(project), WELL_DEMOLITION_MWU - 100, "100 retired")
	assert_equal(_work.credit_work(project, 50), DemolitionWorkScript.REFUSE_NONE, "again")
	assert_equal(_project_left(project), WELL_DEMOLITION_MWU - 150, "150 retired")


func test_credit_work_refuses_nothing_to_credit_and_a_paused_project() -> void:
	"""Zero or negative work, a paused project and a stale project each refuse, writing nothing."""
	var project: Vector2i = _admitted_well()
	var before: PackedByteArray = _settlement.construction().state_bytes()
	assert_equal(_work.credit_work(project, 0), DemolitionWorkScript.REFUSE_NO_WORK, "zero")
	assert_equal(_work.credit_work(project, -5), DemolitionWorkScript.REFUSE_NO_WORK, "negative")
	assert_equal(_work.credit_work(Vector2i(3, 7), 5),
		StringName(ConstructionScript.REFUSE_STALE_PROJECT_REF), "stale")
	assert_true(_settlement.construction().state_bytes() == before, "nothing written")
	assert_true(_settlement.construction().set_paused(project, true).ok, "paused")
	assert_equal(_work.credit_work(project, 5), StringName(ConstructionScript.REFUSE_PAUSED),
		"begin_work's own refusal")


func test_credit_work_completes_the_project_on_its_last_milli_wu() -> void:
	"""A credit of exactly the remainder leaves the project PHASE_WORK_DONE."""
	var project: Vector2i = _admitted_well()
	assert_equal(_work.credit_work(project, WELL_DEMOLITION_MWU), DemolitionWorkScript.REFUSE_NONE,
		"all of it")
	assert_true(_settlement.construction().phase_into(project, _read), "phase reads")
	assert_equal(_read.value, ConstructionScript.PHASE_WORK_DONE, "work done")


func test_finished_project_at_names_the_project_only_once_its_job_is_complete() -> void:
	"""QUEUED: none. COMPLETE: the project. No link: none."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	var row: int = _row(_work.building_of_project(project))
	assert_equal(_work.finished_project_at(row), EntityDirectoryScript.NULL_REF, "QUEUED")
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_COMPLETE).ok, "complete")
	assert_equal(_work.finished_project_at(row), project, "COMPLETE names it")
	assert_equal(_work.finished_project_at(-1), EntityDirectoryScript.NULL_REF, "no row")


func test_a_linked_job_is_stale_when_cancelled_paused_out_of_step_or_foreign() -> void:
	"""`linked_job_is_stale()`: each of the four conditions, and none when healthy or unlinked."""
	var project: Vector2i = _admitted_well()
	var row: int = _row(_work.building_of_project(project))
	assert_false(_work.linked_job_is_stale(row, project), "no link is not stale")
	var job: int = _posted(project)
	assert_false(_work.linked_job_is_stale(row, project), "healthy")
	assert_true(_work.linked_job_is_stale(row, Vector2i(3, 7)), "serving another project")
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_CANCELLED).ok, "cancelled")
	assert_true(_work.linked_job_is_stale(row, project), "cancelled")
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_QUEUED).ok, "queued again")
	assert_true(_settlement.construction().set_paused(project, true).ok, "paused")
	assert_true(_work.linked_job_is_stale(row, project), "paused")
	assert_true(_settlement.construction().set_paused(project, false).ok, "resumed")
	assert_true(_settlement.jobs().set_remaining_mwu(job, 1).ok, "skewed")
	assert_true(_work.linked_job_is_stale(row, project), "out of step")


func test_the_per_tick_reads_allocate_no_object() -> void:
	"""`project_of_job()`, `work_refusal()` and an in-WORKING `credit_work()` allocate nothing."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	assert_equal(_work.credit_work(project, 1), DemolitionWorkScript.REFUSE_NONE, "begun")
	assert_true(_settlement.jobs().set_remaining_mwu(job, WELL_DEMOLITION_MWU - 1).ok, "in step")
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _index: int in 200:
		_work.project_of_job(job)
		_work.work_refusal(job, project)
	for _index: int in 100:
		_work.credit_work(project, 1)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_equal(after - before, 0, "no object allocated")
	assert_equal(_project_left(project), WELL_DEMOLITION_MWU - 101, "and the credits landed")


func test_add_work_mwu_into_matches_add_work_mwu_and_refuses_the_same_way() -> void:
	"""Construction's non-allocating door: the remainder, completion, and every refusal."""
	var project: Vector2i = _admitted_well()
	var construction: ConstructionScript = _settlement.construction()
	assert_false(construction.add_work_mwu_into(project, 5, _read), "READY refuses")
	assert_equal(_read.error, String(ConstructionScript.REFUSE_WRONG_PHASE), "WRONG_PHASE")
	assert_true(construction.begin_work(project).ok, "begins")
	assert_false(construction.add_work_mwu_into(project, 0, _read), "zero refuses")
	assert_equal(_read.error, String(ConstructionScript.REFUSE_INVALID_WORK), "INVALID_WORK")
	assert_false(construction.add_work_mwu_into(Vector2i(3, 7), 5, _read), "stale refuses")
	assert_equal(_read.error, String(ConstructionScript.REFUSE_STALE_PROJECT_REF), "STALE")
	assert_true(construction.add_work_mwu_into(project, 1000, _read), "accepted")
	assert_equal(_read.value, WELL_DEMOLITION_MWU - 1000, "the remainder")
	assert_equal(construction.add_work_mwu(project, 500).value, WELL_DEMOLITION_MWU - 1500,
		"the allocating door agrees")
	assert_true(construction.set_paused(project, true).ok, "paused")
	assert_false(construction.add_work_mwu_into(project, 5, _read), "paused refuses")
	assert_equal(_read.error, String(ConstructionScript.REFUSE_PAUSED), "PAUSED")
	assert_true(construction.set_paused(project, false).ok, "resumed")
	assert_true(construction.add_work_mwu_into(project, WELL_DEMOLITION_MWU, _read), "capped")
	assert_equal(_read.value, 0, "nothing left")
	assert_true(construction.phase_into(project, _read), "phase reads")
	assert_equal(_read.value, ConstructionScript.PHASE_WORK_DONE, "work done")


# --- review fixes: rows, retirement, orphans ---------------------------------------------------

func test_row_of_names_a_live_buildings_row_and_minus_one_otherwise() -> void:
	"""`row_of()` is the coordinator's one row reader."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	assert_equal(_work.row_of(well), _row(well), "the typed row")
	assert_equal(_work.row_of(Vector2i(5, 9)), -1, "a stale ref has none")


func test_retire_job_frees_the_worker_destroys_the_row_and_refuses_a_dead_slot() -> void:
	"""`retire_job()` by slot: true once the row is gone, false for a slot holding no Job."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	var job_ref: Vector2i = _settlement.jobs().ref_of(job)
	_working(job, 0)
	assert_true(_work.retire_job(job), "retired")
	assert_false(_settlement.directory().is_valid(job_ref), "the row is gone")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the worker idle")
	assert_false(_work.retire_job(job), "a dead slot refuses")


func test_a_completed_job_retires_too() -> void:
	"""A COMPLETE Job still holding its worker is released and destroyed like any other."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	_working(job, 0)
	assert_true(_settlement.jobs().set_state(job, JobsScript.JOB_STATE_COMPLETE).ok, "complete")
	_work.retire_job_at(_row(_work.building_of_project(project)))
	assert_false(_settlement.jobs().is_job_present(job), "destroyed")
	assert_equal(_settlement.jobs().job_of(0), EntityDirectoryScript.NULL_REF, "the worker idle")


func test_an_orphaned_removal_job_is_one_no_link_resolves() -> void:
	"""Unlinked BUILD Jobs naming a removal or nothing are orphans; the linked Job is not."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	assert_false(_work.is_orphaned_removal_job(job), "the linked Job is not")
	var stray: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, 1, 0)
	assert_true(_work.is_orphaned_removal_job(stray.value), "no requester: an orphan")
	assert_true(_settlement.jobs().set_requester(stray.value, project).ok, "names the removal")
	assert_true(_work.is_orphaned_removal_job(stray.value), "unlinked: an orphan")
	var haul: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_HAUL,
		3, 0, 1, 0)
	assert_false(_work.is_orphaned_removal_job(haul.value), "a HAUL Job is never one")


func test_a_build_job_requested_by_a_live_build_project_is_not_an_orphan() -> void:
	"""Left for REQ-SET-124's future owner: a live non-removal project's Job is not swept."""
	var blueprint: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), WELL_TILE, 0, START_MASK)
	var build: ConstructionScript.OpResult = _settlement.construction().open_build(blueprint.ref)
	var job: JobsScript.OpResult = _settlement.jobs().create_job(JobsScript.JOB_KIND_BUILD,
		3, 0, 1, 0)
	assert_true(_settlement.jobs().set_requester(job.value, build.ref).ok, "a BUILD project's")
	assert_false(_work.is_orphaned_removal_job(job.value), "not an orphan")


func test_a_row_is_quiet_without_an_order_or_a_link() -> void:
	"""`is_quiet_row()` and the admission record's `is_recorded_at()`."""
	var project: Vector2i = _admitted_well()
	var well: Vector2i = _work.building_of_project(project)
	var row: int = _row(well)
	assert_true(_work.is_quiet_row(row), "no order, no link")
	assert_true(_settlement.demolition_admissions().is_recorded_at(row), "but an admission")
	_posted(project)
	assert_false(_work.is_quiet_row(row), "a link")
	_work.retire_job_at(row)
	_work.order_intent(well)
	assert_false(_work.is_quiet_row(row), "an order")
	assert_false(_settlement.demolition_admissions().is_recorded_at(row + 1), "an empty row")
	assert_false(_settlement.demolition_admissions().is_recorded_at(-1), "no row -1")
	assert_false(_settlement.demolition_admissions().is_recorded_at(
		BuildingsScript.BUILDING_CAPACITY), "nor past the end")


func test_live_job_at_into_matches_live_job_at_and_refuses_out_of_range() -> void:
	"""Jobs' non-allocating live-index reader, which the hourly sweep walks."""
	var project: Vector2i = _admitted_well()
	var job: int = _posted(project)
	var jobs: JobsScript = _settlement.jobs()
	assert_true(jobs.live_job_at_into(0, _read), "index 0 reads")
	assert_equal(_read.value, jobs.live_job_at(0).value, "the same slot as the allocating form")
	assert_equal(_read.value, job, "the posted Job")
	assert_false(jobs.live_job_at_into(jobs.job_count(), _read), "past the end refuses")
	assert_false(jobs.live_job_at_into(-1, _read), "and -1")
