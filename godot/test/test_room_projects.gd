extends "res://test/framework/test_case.gd"
## Real-owner pause tests. The stockpile is a Construction fixture, not a fake room cut.

const RoomProjects := preload("res://scripts/core/room_projects.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _residents: Residents = null
var _buildings: Buildings = null
var _construction: Construction = null
var _jobs: Jobs = null
var _reservations: Reservations = null
var _projects: RoomProjects = null
var _inventory: Inventory = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Build actual owners with one directory and an actual inventory reservation pool."""
	_residents = Residents.new()
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_jobs = Jobs.new(_residents)
	_reservations = Reservations.new()
	_projects = RoomProjects.new(_construction, _jobs, _reservations)
	_inventory = Inventory.new(8, 64)
	assert_true(_inventory.register_item(0, 1000, 3).ok, "synthetic material registers")


func after_each() -> void:
	"""Drop borrowed owners without a signal/callable reference cycle."""
	_projects = null
	_reservations = null
	_inventory = null
	_jobs = null
	_construction = null
	_buildings = null
	_residents = null


func _project(tile: int = 60 * 128 + 50, room_type: int = 2) -> Vector2i:
	"""Use a genuine construction bill; fixture type 2 is the protected Kitchen ID."""
	var placed: Buildings.OpResult = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["open_stockpile"]), tile, 0, 1)
	assert_true(placed.ok, "construction subject places: %s" % placed.error)
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(opened.ok, "construction project opens: %s" % opened.error)
	assert_true(_projects.register_project(opened.ref, room_type).ok, "project registers")
	return opened.ref


func _job(project: Vector2i, bind: bool = true) -> Vector2i:
	"""Give a real BUILD job a generation-qualified requester before recording its ownership."""
	var created: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 60000, 0)
	assert_true(created.ok, "job opens")
	assert_true(_jobs.set_requester(created.value, project).ok, "job requester binds")
	if bind:
		assert_true(_projects.bind_job(project, created.ref).ok, "project records job")
	return created.ref


func _worker(job: Vector2i) -> int:
	"""Assign an actual resident so clearing Construction.assigned_count cannot fake release."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "mouse spawns")
	var row: int = spawned.value
	assert_true(_jobs.priorities().spawn(row).ok, "priorities spawn")
	assert_true(_jobs.schedule().spawn(row, _jobs.schedule().default_template_id().value).ok, "schedule spawns")
	assert_true(_jobs.schedule().resolve(row, 8, false).ok, "work hour resolves")
	assert_true(_jobs.spawn_agent(row).ok, "job agent spawns")
	assert_true(_jobs.assign_worker(row, _residents.directory().get_typed_row(job)).ok, "worker assigns")
	return row


func _claim(job: Vector2i) -> void:
	"""Create a physical reserved lot through the real Reservation/Inventory transaction."""
	var store: Inventory.OpResult = _inventory.create_container(job, 10000, Inventory.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(store.ok, "material container creates")
	var lot: Inventory.OpResult = _inventory.create_lot(store.ref, 0, 1000, 0, 0, 0, 0, 0)
	assert_true(lot.ok, "material lot creates")
	var claims: PackedInt64Array = PackedInt64Array([lot.ref.x, lot.ref.y, 0, 500, 300])
	assert_true(_reservations.claim_batch(job, claims, 1, _inventory).ok, "actual ingredients reserve")


func _epoch(project: Vector2i) -> int:
	"""Request a revision and retain the returned edit-session identity."""
	var requested: RoomProjects.OpResult = _projects.request_revision(project)
	assert_true(requested.ok, "revision request accepted")
	return requested.value


func _snapshot() -> PackedByteArray:
	"""Refused commands must preserve adapter, paid work, jobs, claims, and goods."""
	var bytes: PackedByteArray = _projects.state_bytes()
	bytes.append_array(_construction.state_bytes())
	bytes.append_array(_jobs.state_bytes())
	bytes.append_array(_reservations.state_bytes())
	bytes.append_array(_inventory.state_bytes())
	return bytes


func test_registration_pins_type_and_rejects_retyping_or_live_retirement() -> void:
	"""Emptying furniture cannot retype the same project identity or erase its record."""
	var project: Vector2i = _project()
	assert_true(_projects.is_registered(project), "live identity is registered")
	assert_true(_projects.room_type_into(project, _out), "type reads")
	assert_equal(_out.value, 2, "Kitchen remains Kitchen")
	var before: PackedByteArray = _snapshot()
	assert_equal(_projects.register_project(project, 1).error, RoomProjects.REFUSE_ALREADY_REGISTERED, "bedroom is a different lifecycle")
	assert_equal(_projects.retire_record(project).error, RoomProjects.REFUSE_PROJECT_LIVE, "live paid project cannot disappear")
	assert_equal(_snapshot(), before, "refusals are byte-identical")


func test_registration_rejects_unknown_type_and_mismatched_directory() -> void:
	"""A directory coincidence does not prove an owner's identity."""
	var project: Vector2i = _project()
	assert_equal(_projects.register_project(project, 8).error, RoomProjects.REFUSE_ROOM_TYPE, "no invented room ID")
	var foreign: Jobs = Jobs.new()
	var adapter: RoomProjects = RoomProjects.new(_construction, foreign, _reservations)
	assert_equal(adapter.register_project(project, 2).error, RoomProjects.REFUSE_OWNER_MISMATCH, "different directory refuses")
	assert_false(adapter.can_dispatch_work(project), "unbound owner grants no work")


func test_revision_preserves_actual_delivered_inputs_and_partial_work() -> void:
	"""A room editing hold pauses the real paid project without refunding or restarting it."""
	var project: Vector2i = _project()
	assert_true(_construction.deliver_material(project, 0, 4000).ok, "real bill delivered")
	assert_true(_construction.begin_work(project).ok, "real paid work begins")
	assert_true(_construction.add_work_mwu(project, 1234).ok, "partial work committed")
	assert_true(_construction.set_assigned_count(project, 2).ok, "builders assigned")
	var epoch: int = _epoch(project)
	assert_true(_construction.is_paused(project), "Construction is actually paused")
	assert_true(_construction.remaining_mwu_into(project, _out), "remaining work reads")
	assert_equal(_out.value, 58766, "earned WU survive")
	assert_true(_construction.delivered_milli_into(project, 0, _out), "delivered material reads")
	assert_equal(_out.value, 4000, "paid material survives")
	assert_true(_construction.assigned_count_into(project, _out), "assigned builders read")
	assert_equal(_out.value, 0, "Construction releases its builder count")
	assert_equal(_construction.add_work_mwu(project, 1).error, Construction.REFUSE_PAUSED, "real owner blocks more work")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "no jobs or claims remain")
	assert_true(_projects.discard_revision(project, epoch).ok, "explicit discard resumes")
	assert_true(_construction.add_work_mwu(project, 1).ok, "work resumes on same paid project")


func test_request_is_distinct_from_acknowledgement_and_idempotent() -> void:
	"""Selecting the same revision cannot mint repeated holds or falsely acknowledge a stop."""
	var project: Vector2i = _project()
	var epoch: int = _epoch(project)
	assert_equal(_projects.request_revision(project).value, epoch, "retry gets same session")
	assert_true(_projects.revision_state_into(project, _out), "state reads")
	assert_equal(_out.value, RoomProjects.REVISION_REQUESTED, "request is not acknowledgement")
	assert_true(_projects.revision_epoch_into(project, _out), "epoch reads")
	assert_equal(_out.value, epoch, "read epoch matches")
	assert_false(_projects.can_dispatch_work(project), "dispatch stops at request")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "actual stopped owners acknowledge")
	assert_true(_projects.revision_state_into(project, _out), "acknowledged state reads")
	assert_equal(_out.value, RoomProjects.REVISION_ACKNOWLEDGED, "acknowledged distinctly")


func test_live_worker_and_claims_delay_acknowledgement() -> void:
	"""assigned_count=0 is insufficient while the real worker or material claim remains."""
	var project: Vector2i = _project()
	var job: Vector2i = _job(project)
	var worker: int = _worker(job)
	var epoch: int = _epoch(project)
	var before: PackedByteArray = _snapshot()
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_WORKER, "live worker blocks")
	assert_equal(_snapshot(), before, "failed acknowledgement has no side effects")
	assert_true(_jobs.release_worker(worker).ok, "worker owner releases after safe withdrawal")
	_claim(job)
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_CLAIMS, "lease blocks even without worker")
	assert_equal(_projects.release_job_binding(project, job).error, RoomProjects.REFUSE_CLAIMS, "cannot hide owned lease")
	assert_true(_reservations.release_job_claims(job, _inventory).ok, "actual claims release")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "stopped worker plus released claims acknowledge")
	assert_equal(_inventory.total_live_milli(0), 1000, "revision does not destroy goods")


func test_unbound_late_job_and_active_phase_cannot_bypass_hold() -> void:
	"""Revalidate against Jobs each time; the explicit binding list is not an attestation."""
	var project: Vector2i = _project()
	var epoch: int = _epoch(project)
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "initially stopped")
	var job: Vector2i = _job(project, false)
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_JOB_LATE, "unbound owned job blocks")
	assert_true(_projects.revision_state_into(project, _out), "state rechecks")
	assert_equal(_out.value, RoomProjects.REVISION_REQUESTED, "late job invalidates cached acknowledgement")
	assert_true(_projects.bind_job(project, job).ok, "late job binds")
	var row: int = _residents.directory().get_typed_row(job)
	assert_true(_jobs.set_state(row, Jobs.JOB_STATE_HAUL_OUTPUT).ok, "output phase remains active")
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_ACTIVE_JOB, "active transaction blocks without worker")
	assert_true(_jobs.set_state(row, Jobs.JOB_STATE_BLOCKED).ok, "owner stops transaction")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "stopped job acknowledges")


func test_player_pause_before_or_during_revision_survives_discard() -> void:
	"""Independent pause reasons cannot be erased by an editing exit."""
	var project: Vector2i = _project()
	assert_true(_projects.set_player_paused(project, true).ok, "player pauses first")
	var epoch: int = _epoch(project)
	assert_true(_projects.discard_revision(project, epoch).ok, "discard accepted")
	assert_true(_construction.is_paused(project), "earlier player hold survives")
	assert_true(_projects.set_player_paused(project, false).ok, "player resumes")
	epoch = _epoch(project)
	assert_true(_projects.set_player_paused(project, true).ok, "player pauses during edit")
	assert_true(_projects.discard_revision(project, epoch).ok, "second discard accepted")
	assert_true(_projects.pause_reasons_into(project, _out), "reasons read")
	assert_equal(_out.value, RoomProjects.PAUSE_PLAYER, "newer player hold also survives")
	assert_true(_projects.set_player_paused(project, false).ok, "explicit player resume")
	assert_true(_projects.can_dispatch_work(project), "no remaining holds")


func test_existing_pause_is_adopted_at_registration() -> void:
	"""Registering an already paused Construction project cannot seize its pause ownership."""
	var placed: Buildings.OpResult = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["open_stockpile"]), 40 * 128 + 40, 0, 1)
	var project: Vector2i = _construction.open_build(placed.ref).ref
	assert_true(_construction.set_paused(project, true).ok, "older pause exists")
	assert_true(_projects.register_project(project, 2).ok, "registers with prior hold")
	var epoch: int = _epoch(project)
	assert_true(_projects.discard_revision(project, epoch).ok, "editing exits")
	assert_true(_construction.is_paused(project), "pre-existing hold remains")


func test_player_resume_during_edit_keeps_editing_hold() -> void:
	"""A user resume clears only the player bit, not an active review session."""
	var project: Vector2i = _project()
	var epoch: int = _epoch(project)
	assert_true(_projects.set_player_paused(project, true).ok, "add player hold")
	assert_true(_projects.set_player_paused(project, false).ok, "remove only player hold")
	assert_true(_construction.is_paused(project), "editing still holds work")
	assert_false(_projects.can_dispatch_work(project), "no dispatch during review")
	assert_true(_projects.discard_revision(project, epoch).ok, "release final hold")
	assert_false(_construction.is_paused(project), "project resumes")


func test_stale_revision_token_cannot_release_newer_session() -> void:
	"""A delayed modal click belongs to its original edit session, even on the same project."""
	var project: Vector2i = _project()
	var first: int = _epoch(project)
	assert_true(_projects.discard_revision(project, first).ok, "first revision exits")
	var second: int = _epoch(project)
	assert_true(second > first, "session epoch advances")
	var before: PackedByteArray = _snapshot()
	assert_equal(_projects.discard_revision(project, first).error, RoomProjects.REFUSE_REVISION_TOKEN, "old discard refuses")
	assert_equal(_projects.acknowledge_revision(project, first).error, RoomProjects.REFUSE_REVISION_TOKEN, "old acknowledgement refuses")
	assert_equal(_snapshot(), before, "second hold is untouched")


func test_observable_direct_pause_writers_fail_closed() -> void:
	"""A legacy call site may not silently resume a project with an edit hold."""
	var project: Vector2i = _project()
	var epoch: int = _epoch(project)
	assert_true(_construction.set_paused(project, false).ok, "simulate bypass writer")
	var before: PackedByteArray = _snapshot()
	assert_equal(_projects.discard_revision(project, epoch).error, RoomProjects.REFUSE_PAUSE_DRIFT, "drift diagnosed")
	assert_false(_projects.can_dispatch_work(project), "drift does not authorize dispatch")
	assert_false(_projects.pause_reasons_into(project, _out), "reader exposes disagreement")
	assert_equal(_snapshot(), before, "adapter does not erase or repair ownership silently")


func test_jobs_and_project_generations_do_not_transfer_editing_context() -> void:
	"""Replacement identities must resolve old jobs before reusing a metadata row."""
	var project: Vector2i = _project()
	var job: Vector2i = _job(project)
	var row: int = _residents.directory().get_typed_row(job)
	var epoch: int = _epoch(project)
	assert_true(_jobs.destroy_job(row).ok, "old job retires")
	var replacement: Vector2i = _job(project, false)
	assert_true(replacement != job, "same slot receives a different generation")
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_JOB_STALE, "replacement cannot acknowledge old job")
	assert_true(_projects.release_job_binding(project, job).ok, "claim-free old identity can retire")
	assert_true(_projects.bind_job(project, replacement).ok, "replacement binds explicitly")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "explicit replacement is stopped")


func test_retired_job_with_claims_cannot_be_forgotten() -> void:
	"""A destroyed Jobs row is not proof that its inventory reservations disappeared."""
	var project: Vector2i = _project()
	var job: Vector2i = _job(project)
	_claim(job)
	assert_true(_jobs.destroy_job(_residents.directory().get_typed_row(job)).ok, "simulate early Jobs retirement")
	assert_equal(_projects.release_job_binding(project, job).error, RoomProjects.REFUSE_CLAIMS, "orphan claims still block")
	assert_true(_reservations.release_job_claims(job, _inventory).ok, "claim owner resolves actual reservation")
	assert_true(_projects.release_job_binding(project, job).ok, "retired binding now clears")


func test_retirement_never_retypes_same_identity_or_touches_replacement() -> void:
	"""Metadata retires only after its actual Construction identity; a new one gets no old holds."""
	var project: Vector2i = _project()
	var job: Vector2i = _job(project)
	assert_true(_construction.begin_refund(project).ok, "empty construction can cancel")
	assert_true(_construction.close_refund(project).ok, "actual owner retires project")
	assert_false(_projects.is_registered(project), "old ref is stale")
	assert_equal(_projects.retire_record(project).error, RoomProjects.REFUSE_BOUND_JOBS, "bound child must resolve first")
	assert_true(_jobs.destroy_job(_residents.directory().get_typed_row(job)).ok, "child retires")
	assert_true(_projects.release_job_binding(project, job).ok, "child binding clears")
	assert_true(_projects.retire_record(project).ok, "old metadata retires")
	var next: Vector2i = _project(65 * 128 + 70, 1)
	assert_true(next != project, "new project identity")
	assert_true(_projects.room_type_into(next, _out), "new purpose reads")
	assert_equal(_out.value, 1, "new project can be Bedroom")
	assert_equal(_projects.request_revision(project).error, RoomProjects.REFUSE_STALE_PROJECT, "old ref cannot pause new room")
	assert_true(_projects.can_dispatch_work(next), "replacement inherits no old hold")


func test_pause_is_local_and_wrong_job_owner_refuses_without_mutation() -> void:
	"""Revision cannot pause a neighboring project or adopt its child work."""
	var first: Vector2i = _project()
	var second: Vector2i = _project(65 * 128 + 70)
	var job: Vector2i = _job(second, false)
	var before: PackedByteArray = _snapshot()
	assert_equal(_projects.bind_job(first, job).error, RoomProjects.REFUSE_JOB_OWNER, "wrong actual requester refuses")
	assert_equal(_snapshot(), before, "ownership refusal changes nothing")
	_epoch(first)
	assert_true(_projects.can_dispatch_work(second), "neighbor keeps working")
	assert_false(_construction.is_paused(second), "neighbor Construction unchanged")


func test_packed_state_size_matches_existing_owner_capacities() -> void:
	"""The wrapper's complete byte image is accounted explicitly; no new gameplay cap is added."""
	assert_equal(_projects.state_bytes().size(), 1707008, "82944 * 19 project bytes + 8192 * 16 job bytes")


func test_party_member_cannot_hide_behind_a_coordinator_without_a_worker() -> void:
	"""An otherwise idle coordinator is insufficient while a late member still owns work."""
	var project: Vector2i = _project()
	var coordinator: Vector2i = _job(project)
	var coordinator_row: int = _residents.directory().get_typed_row(coordinator)
	assert_true(_jobs.make_coordinator(coordinator_row).ok, "shared job becomes a coordinator")
	var member: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 0, 0)
	assert_true(member.ok, "zero-progress member creates")
	assert_true(_jobs.set_coordinator(member.value, coordinator_row).ok, "actual member links")
	var epoch: int = _epoch(project)
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_JOB_LATE, "unbound member is still owned")
	assert_true(_projects.bind_job(project, member.ref).ok, "membership proves project ownership")
	var worker: int = _worker(member.ref)
	assert_equal(_projects.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_WORKER, "member worker prevents acknowledgement")
	assert_true(_jobs.release_worker(worker).ok, "member owner releases its worker")
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "stopped party acknowledges together")


func test_job_outside_reservation_key_space_fails_explicitly() -> void:
	"""An out-of-range Reservation query returns zero, which must not be taken as proof."""
	var small_pool: Reservations = Reservations.new(4, 1, 64)
	var adapter: RoomProjects = RoomProjects.new(_construction, _jobs, small_pool)
	var project: Vector2i = _project()
	assert_true(adapter.register_project(project, 2).ok, "owner-compatible adapter registers")
	var job: Vector2i = _job(project, false)
	assert_true(job.x >= small_pool.job_capacity(), "fixture key exceeds pool range")
	assert_equal(adapter.bind_job(project, job).error, RoomProjects.REFUSE_RESERVATION_KEY, "capacity refusal is explicit")
	var epoch: int = adapter.request_revision(project).value
	assert_equal(adapter.acknowledge_revision(project, epoch).error, RoomProjects.REFUSE_JOB_LATE, "unrepresentable job cannot silently vanish")


func test_conflicting_member_requester_cannot_evade_either_project() -> void:
	"""An inconsistent party record is a blocker, not a way to hide unfinished work."""
	var first: Vector2i = _project()
	var second: Vector2i = _project(65 * 128 + 70)
	var coordinator: Vector2i = _job(first)
	var coordinator_row: int = _residents.directory().get_typed_row(coordinator)
	assert_true(_jobs.make_coordinator(coordinator_row).ok, "coordinator creates")
	var member: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 0, 0)
	assert_true(_jobs.set_requester(member.value, second).ok, "conflicting requester is representable in owner")
	assert_true(_jobs.set_coordinator(member.value, coordinator_row).ok, "member still links to first project")
	assert_equal(_projects.bind_job(first, member.ref).error, RoomProjects.REFUSE_JOB_OWNER, "coordinator does not override other requester")
	assert_equal(_projects.bind_job(second, member.ref).error, RoomProjects.REFUSE_JOB_OWNER, "requester does not override other coordinator")
	assert_equal(_projects.acknowledge_revision(first, _epoch(first)).error, RoomProjects.REFUSE_JOB_LATE, "first project sees conflicting member")
	assert_equal(_projects.acknowledge_revision(second, _epoch(second)).error, RoomProjects.REFUSE_JOB_LATE, "second project also sees conflict")


func test_safe_stop_cost_with_256_residents_and_full_job_pool() -> void:
	"""Measure the cold command at the actual population cap and all 8192 occupied Job rows."""
	var project: Vector2i = _project()
	var spawned: int = 0
	for index: int in 256:
		if _residents.spawn(&"mouse").ok:
			spawned += 1
	assert_equal(spawned, 256, "actual capped population exists")
	for index: int in Construction.MAX_BUILDERS:
		_job(project)
	var created: int = Construction.MAX_BUILDERS
	for index: int in range(Construction.MAX_BUILDERS, Jobs.JOB_CAPACITY):
		if _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1, 0).ok:
			created += 1
	assert_equal(created, 8192, "every permitted Job row is occupied")
	var epoch: int = _epoch(project)
	assert_true(_projects.acknowledge_revision(project, epoch).ok, "full job pool still safely acknowledges")
	var total_usec: int = 0
	var maximum_usec: int = 0
	for sample: int in 16:
		var started: int = Time.get_ticks_usec()
		var acknowledged: RoomProjects.OpResult = _projects.acknowledge_revision(project, epoch)
		var elapsed: int = Time.get_ticks_usec() - started
		total_usec += elapsed
		maximum_usec = maxi(maximum_usec, elapsed)
		assert_true(acknowledged.ok, "measurement preserves acknowledged result")
	@warning_ignore("integer_division") var mean_usec: int = total_usec / 16
	print("ROOM-PROJECT-PAUSE-BENCH residents=256 jobs=8192 samples=16 mean_usec=%d max_usec=%d" % [mean_usec, maximum_usec])
