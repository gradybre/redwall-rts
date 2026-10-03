extends "res://test/framework/test_case.gd"
## Actual Room/Site/Job identity readers. Initial Room/Site permission remains explicitly synthetic fixture data.

const Fixture := preload("res://test/test_underground_room_bindings.gd")
const Bindings := preload("res://scripts/core/underground_world_bindings.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _actual: Fixture = null


func before_each() -> void:
	"""Use actual generated World, Terrain, Buildings, sparse state and physical accounting owners."""
	_actual = Fixture.new()
	_actual.before_each()
	assert_true(_actual.failures.is_empty(), "actual fixture initialized")
	_actual._world_bindings.end_cold_operation(_actual._lease)
	_actual._lease = 0


func after_each() -> void:
	"""Release this fixture's references and propagate its actual owner setup/cleanup failures."""
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "nested actual-owner checks passed")
	_actual = null


func _job() -> int:
	"""Create a real unworked funded-phase identity and its exact BUILD Job, without productive permission."""
	var project: Fixture.Construction.OpResult = _actual._sites.open_phase(_actual._site, Contract.OP_BRACE)
	assert_true(project.ok, "actual unstarted phase opens through synthetic fixture permission")
	var work: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_actual._construction.remaining_mwu_into(project.ref, work), "actual paid work quantity")
	var job: int = _actual._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, work.value, 0).value
	assert_true(_actual._jobs.set_requester(job, project.ref).ok, "Job names full actual Project")
	assert_true(_actual._jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "identity fixture advertises eligibility only")
	assert_true(_actual._sites.bind_job(_actual._site, _actual._jobs.ref_of(job)).ok, "actual paid Site binds exact Job")
	return job


func _worker() -> int:
	"""Create a living actual JobAgent with the real schedule, priorities and need gates."""
	var resident: int = _actual._residents.spawn_with_stage(&"mole", Residents.LIFE_STAGE_ADULT).value
	assert_true(_actual._jobs.priorities().spawn(resident).ok, "actual priorities")
	assert_true(_actual._jobs.schedule().spawn(resident, _actual._jobs.schedule().default_template_id().value).ok, "actual schedule")
	assert_true(_actual._jobs.schedule().resolve(resident, 8, false).ok, "actual work hour")
	assert_true(_actual._jobs.spawn_agent(resident).ok, "actual JobAgent")
	for need: int in Needs.NEED_COUNT:
		var value: int = _actual._residents.needs().need_of(resident, need).value
		assert_true(_actual._residents.needs().apply_need_event(resident, need, 5000 - value).ok, "actual need gate")
	return resident


func _read(job: int) -> Vector2i:
	"""Read the original actual Site/Job relationship without supplying any worker nomination."""
	return _actual._world_bindings.assigned_worker(_actual._site, _actual._jobs.ref_of(job))


func test_empty_registered_kitchen_has_identity_without_service_or_physical_permission() -> void:
	"""Room identity is necessary for Sites, but cannot qualify empty air, working contacts or service."""
	var before: PackedByteArray = _actual._owner.state_bytes()
	assert_equal(_actual._world_bindings.room_refusal(_actual._room), &"", "actual permanent registered Kitchen")
	assert_false(_actual._buildings.room_is_valid(_actual._room), "unfurnished fixture has no valid service")
	assert_equal(_actual._world_bindings.qualification_revision(), 0, "no actual movement/contact qualification inferred")
	assert_true(_actual._world_bindings.worker_refusal(Fixture.ORIGIN, Contract.OP_BRACE, _actual._room,
		NULL_REF, NULL_REF, _actual._owner.revision(), 1) != &"", "identity supplies no productive permission")
	assert_equal(_actual._owner.state_bytes(), before, "no state publication")


func test_unregistered_stale_and_changed_purpose_rooms_refuse() -> void:
	"""A live allocation alone or a reused numeric slot cannot substitute for the retained source facts."""
	_actual._rooms.registering = true
	var unregistered: Vector2i = _actual._buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN).ref
	_actual._rooms.registering = false
	assert_equal(_actual._world_bindings.room_refusal(unregistered), &"SPACE_SOURCE_NOT_REGISTERED", "actual source required")
	assert_true(_actual._world_bindings.room_refusal(Vector2i(_actual._room.x, _actual._room.y + 1)) != &"", "full generation")
	var row: int = _actual._jobs.directory().get_typed_row(_actual._room)
	_actual._buildings._r_type[row] = Buildings.ROOM_TYPE_DORMITORY
	assert_equal(_actual._world_bindings.room_refusal(_actual._room), &"SPACE_SOURCE_DRIFT", "purpose changed behind owner")
	_actual._buildings._r_type[row] = Buildings.ROOM_TYPE_KITCHEN
	assert_equal(_actual._world_bindings.room_refusal(_actual._room), &"", "original identity intact")


func test_live_surface_room_cannot_be_borrowed_as_an_underground_room() -> void:
	"""The separate exterior Hall room model keeps its own domain even with a valid full Room reference."""
	var hall: Buildings.OpResult = _actual._buildings.place_building(Catalog.BUILDING_DEFINITION["hall"], 0, 0, 1)
	assert_true(hall.ok, "actual surface Hall")
	var room: Buildings.OpResult = _actual._buildings.designate_room(hall.ref, Buildings.ROOM_TYPE_DORMITORY,
		PackedInt32Array([129, 130, 131]))
	assert_true(room.ok, "actual surface Room")
	assert_equal(_actual._world_bindings.room_refusal(room.ref), &"SPACE_UNDERGROUND_ROOM_REQUIRED", "no implicit surface projection")


func test_actual_job_assignment_is_read_live_and_released_without_retaining_previous_worker() -> void:
	"""The caller cannot nominate a worker; actual assignment, release and reassignment decide this identity."""
	var job: int = _job()
	var first: int = _worker()
	assert_equal(_read(job), NULL_REF, "unassigned Job has no worker")
	assert_true(_actual._jobs.assign_worker(first, job).ok, "actual first worker assigns")
	assert_equal(_read(job), _actual._residents.ref_of(first), "actual full first identity")
	assert_true(_actual._jobs.release_worker(first).ok, "actual assignment releases")
	assert_equal(_read(job), NULL_REF, "no cached worker remains")
	var second: int = _worker()
	assert_true(_actual._jobs.assign_worker(second, job).ok, "actual replacement worker assigns")
	assert_equal(_read(job), _actual._residents.ref_of(second), "replacement full identity")


func test_wrong_site_job_generation_and_requester_cannot_supply_an_assignment() -> void:
	"""Project and Site ownership are checked before reading any otherwise valid live Job worker."""
	var job: int = _job()
	var resident: int = _worker()
	assert_true(_actual._jobs.assign_worker(resident, job).ok, "actual worker assigns")
	var ref: Vector2i = _actual._jobs.ref_of(job)
	assert_equal(_actual._world_bindings.assigned_worker(Vector2i(_actual._site.x, _actual._site.y + 1), ref), NULL_REF, "wrong Site generation")
	assert_equal(_actual._world_bindings.assigned_worker(_actual._site, Vector2i(ref.x, ref.y + 1)), NULL_REF, "wrong Job generation")
	var project: Vector2i = _actual._jobs.requester_of(job)
	assert_true(_actual._jobs.set_requester(job, NULL_REF).ok, "remove real requester")
	assert_equal(_read(job), NULL_REF, "Job no longer belongs to paid Site")
	assert_true(_actual._jobs.set_requester(job, project).ok, "restore actual requester")
	assert_equal(_read(job), _actual._residents.ref_of(resident), "exact ownership restored")


func test_worker_generation_and_reciprocal_agent_mirror_are_mandatory() -> void:
	"""Neither a stale worker ref nor a one-sided assignment can be read as productive identity."""
	var job: int = _job()
	var resident: int = _worker()
	assert_true(_actual._jobs.assign_worker(resident, job).ok, "actual worker assigns")
	_actual._jobs._worker_generation[job] += 1
	assert_equal(_read(job), NULL_REF, "full resident generation")
	_actual._jobs._worker_generation[job] -= 1
	_actual._jobs._agent_job_generation[resident] += 1
	assert_equal(_read(job), NULL_REF, "reciprocal actual JobAgent generation")
	_actual._jobs._agent_job_generation[resident] -= 1
	assert_equal(_read(job), _actual._residents.ref_of(resident), "both actual mirrors agree")


func test_retired_world_and_unbound_composer_never_return_room_or_worker_identity() -> void:
	"""World lifetime is rechecked even if Room and Job numeric references still exist."""
	var job: int = _job()
	var resident: int = _worker()
	assert_true(_actual._jobs.assign_worker(resident, job).ok, "actual worker assigns")
	_actual._world.clear()
	assert_true(_actual._world_bindings.room_refusal(_actual._room) != &"", "actual World retired")
	assert_equal(_read(job), NULL_REF, "no assignment escapes retired World")
	var unbound: Bindings = Bindings.new()
	assert_true(unbound.room_refusal(_actual._room) != &"", "unconfigured Room reader")
	assert_equal(unbound.assigned_worker(_actual._site, _actual._jobs.ref_of(job)), NULL_REF, "unconfigured Job reader")
