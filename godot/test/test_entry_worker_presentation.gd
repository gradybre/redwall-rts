extends "res://test/framework/test_case.gd"
## ADR1211 step 2: the entry worker's Actors are driven from the simulation's own selected row. A real tool-free adult
## mole hauls one staged stone unit through Delivery on the real content-6 bank (the ADR1206 fixture), and every stage
## is drawn by present_row: WALK (31), the wood and stone lifts (34, 39), CARRY in travel and on arrival (37) and the
## set-down (41). Actors are recording subclasses over the real shared Palettes (no renderer headless).

const Presentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const HaulProgram := preload("res://data/underground/mole-worker/mole_haul_program.gd")
const ContentSet := preload("res://demo/cast/underground_content_set.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const PresentationSuite := preload("res://test/test_mole_presentation.gd")
const HaulGrip := preload("res://test/test_underground_haul_grip.gd")
const WorkAreaSource := preload("res://scripts/core/underground_entry_work_area.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _owned: Array[Node] = []
var _fixture: HaulGrip = null
var _frame: Driver.Frame = null


func after_each() -> void:
	"""Free recording Actors and close the real haul fixture."""
	for node: Node in _owned:
		node.free()
	_owned.clear()
	if _fixture != null:
		_fixture.after_each()
		assert_true(_fixture.failures.is_empty(), "actual haul fixture: %s" % _fixture.failures)
	_fixture = null


func _presenter(include_stone: bool) -> Presentation:
	"""All loaded sources, one hidden recording Actor each."""
	var sources: ContentSet = ContentSet.new()
	assert_equal(Presentation.load_sources(sources, true, include_stone), &"", "pinned images")
	var presenter: Presentation = Presentation.new()
	assert_equal(presenter.configure(sources), &"", "bound")
	for source: int in ContentSet.MAX_SOURCES:
		if sources.has_source(source):
			var actor: PresentationSuite.RecordingActor = PresentationSuite.RecordingActor.new()
			_owned.append(actor)
			actor.borrow(sources.content(source)._palette)
			assert_equal(presenter.adopt_actor(source, actor), &"", "source %d adopted hidden" % source)
	return presenter


func _shown(presenter: Presentation) -> Vector3i:
	"""(visible source, its clip, its part mask) of the last shown frame."""
	var source: int = presenter.visible_source()
	if source < 0:
		return Vector3i(-1, -1, -1)
	var actor: PresentationSuite.RecordingActor = presenter.actor(source) as PresentationSuite.RecordingActor
	return Vector3i(source, presenter._sources.clip_of_frame(source, actor.last_frames[0]), actor._visible_parts)


func _hidden_others(presenter: Presentation) -> bool:
	"""Every Actor other than the shown one has mask 0."""
	for source: int in ContentSet.MAX_SOURCES:
		var actor: Presentation.Actor = presenter.actor(source)
		if actor != null and source != presenter.visible_source() and actor._visible_parts != 0:
			return false
	return true


func _draw(presenter: Presentation, tick: int, expected: Vector3i, label: String) -> void:
	"""present_row on the real Routes owner, then the exact source, clip and mask."""
	var world: RefCounted = _fixture._probe._world
	assert_equal(presenter.present_row(world._routes, world._worker, tick, _frame), &"", label)
	assert_equal(_shown(presenter), expected, label)
	assert_true(_hidden_others(presenter), "%s: other sources hidden" % label)


func _start() -> HaulGrip.Jobs.OpResult:
	"""The ADR1206 fixture up to an admitted stone haul with the tool-free mole on R."""
	_fixture = HaulGrip.new()
	_frame = Driver.Frame.new()
	if not _fixture._ready():
		return null
	var lot: Vector2i = _fixture._stage(1000, &"stone")
	var job: HaulGrip.Jobs.OpResult = _fixture._haul_job()
	assert_true(_fixture._delivery.admit(job.ref, lot, 1000, HaulGrip.EXPIRY).ok, "stone admitted")
	assert_true(_fixture._probe._world._jobs.set_state(job.value, HaulGrip.Jobs.JOB_STATE_TRAVEL).ok, "travel")
	return job


func test_stone_haul_rows_draw_their_own_source_clip_and_mask() -> void:
	"""Every stage of the real stone haul selects source by row digest and applies the clip's mask on each draw."""
	var job: HaulGrip.Jobs.OpResult = _start()
	if job == null or not failures.is_empty():
		return
	var presenter: Presentation = _presenter(true)
	_draw(presenter, 0, Vector3i(2, HaulProgram.HAUL_WALK, 1), "tool-free WALK row on R: wood stock hidden")
	assert_true(_fixture._travel(job, WorkAreaSource.STAND_R, Profiles.MODE_WALK), "walk to R's stand")
	assert_true(_fixture._grip(job, 34), "wood lift row selectable")
	_draw(presenter, 10, Vector3i(2, HaulProgram.HAUL_ENTER_HAUL, 3), "wood lift row 34 starts at enter_haul")
	assert_true(_fixture._grip(job, 39), "stone lift row")
	_draw(presenter, 20, Vector3i(3, HaulProgram.STONE_ENTER_HAUL, 3), "stone lift row 39 restarts its program")
	_draw(presenter, 50, Vector3i(3, HaulProgram.APPROACH, 3), "enter_haul_stone (30 ticks) then approach")
	_draw(presenter, 110, Vector3i(3, HaulProgram.LIFT, 3), "approach (60) then lift")
	_draw(presenter, 5000, Vector3i(3, HaulProgram.LIFT, 3), "lift clamps on its last pose")
	assert_equal([_frame.profile_id, _frame.source_digest], [39, Presentation.Session.STONE_ACTOR_SHA], "row 39 frame")
	_lift(job)
	_carry_and_unload(presenter, job)


func _lift(job: HaulGrip.Jobs.OpResult) -> void:
	"""The real guarded load through Delivery."""
	assert_equal(_fixture._delivery.begin_load(job.ref), &"", "stone grip at R")
	assert_true(_fixture._work(job.value), "lift work")
	assert_true(_fixture._delivery.load_payload(job.ref).ok, "guarded load")


func _carry_and_unload(presenter: Presentation, job: HaulGrip.Jobs.OpResult) -> void:
	"""CARRY row 37 in travel then on arrival, then the set-down row 41 to the stone on the ground."""
	var world: RefCounted = _fixture._probe._world
	assert_equal(world._routes.refresh_actor(world._worker, job.ref, Profiles.MODE_CARRY, 0, -1, NULL_REF), &"", "carry")
	assert_equal(world._routes.request_route(world._worker, _fixture._probe._endpoints[WorkAreaSource.STAND_M], 0), &"",
		"route to M's stand")
	var actor: Routes.Actor = Routes.Actor.new()
	var tick: int = _advance_until(world, actor, 0, false)
	_draw(presenter, 6000, Vector3i(3, HaulProgram.HOLD, 3), "CARRY in travel starts at hold")
	_draw(presenter, 6066, Vector3i(3, HaulProgram.CARRY, 3), "hold (1) and enter (64) then the carry loop")
	_draw(presenter, 6066 + 218 * 3, Vector3i(3, HaulProgram.CARRY, 3), "the carry clip loops")
	assert_equal(_frame.phase, Routes.PHASE_TRAVELLING, "drawn while travelling")
	_advance_until(world, actor, tick + 1, true)
	assert_equal(actor.location, _fixture._probe._endpoints[WorkAreaSource.STAND_M], "arrived on M's stand")
	_draw(presenter, 7000, Vector3i(3, HaulProgram.EXIT, 3), "CARRY on arrival leaves the gait by exit")
	assert_equal(_frame.profile_id, 37, "stone CARRY row")
	assert_true(_fixture._grip(job, 41), "stone set-down row")
	_draw(presenter, 7100, Vector3i(3, HaulProgram.HOLD, 3), "unload starts at hold")
	_draw(presenter, 7100 + 1 + 60 + 60 + 29, Vector3i(3, HaulProgram.STONE_LEAVE_HAUL, 3), "place, recovery, leave")
	_draw(presenter, 9000, Vector3i(3, HaulProgram.STONE_LEAVE_HAUL, 3), "leave_haul_stone clamps")


func test_absent_stone_image_refuses_the_stone_rows_without_changing_the_shown_actor() -> void:
	"""Row 39 with the stone image unloaded refuses SOURCE_ABSENT; the wood haul Actor stays shown and posed as it was."""
	var job: HaulGrip.Jobs.OpResult = _start()
	if job == null or not failures.is_empty():
		return
	var presenter: Presentation = _presenter(false)
	_draw(presenter, 0, Vector3i(2, HaulProgram.HAUL_WALK, 1), "WALK row")
	var shown: PresentationSuite.RecordingActor = presenter.actor(2) as PresentationSuite.RecordingActor
	var poses: int = shown.poses
	assert_true(_fixture._travel(job, WorkAreaSource.STAND_R, Profiles.MODE_WALK), "walk to R's stand")
	assert_true(_fixture._grip(job, 39), "stone lift row")
	var world: RefCounted = _fixture._probe._world
	assert_equal(presenter.present_row(world._routes, world._worker, 10, _frame), &"MOLE_PRESENTATION_SOURCE_ABSENT",
		"no stone image")
	assert_equal([shown.poses, presenter.visible_source(), shown._visible_parts], [poses, 2, 1], "nothing changed")
	assert_equal(presenter.present_row(world._routes, Vector2i(world._worker.x, world._worker.y + 1), 10, _frame),
		&"ROUTE_ACTOR_STALE", "stale worker generation refuses through the Routes owner")


func _advance_until(world: RefCounted, actor: Routes.Actor, first: int, arrived: bool) -> int:
	"""Advance the real route clock until the actor travels (or, with `arrived`, is idle or held); returns the tick."""
	for tick: int in range(first, first + 2000):
		world._routes.advance_tick(tick)
		assert_equal(world._routes.read_actor_into(world._worker, actor), &"", "actual actor")
		var done: bool = actor.phase == Routes.PHASE_IDLE or actor.phase == Routes.PHASE_HELD
		if (arrived and done) or (not arrived and actor.phase == Routes.PHASE_TRAVELLING):
			return tick
	assert_true(false, "route phase never reached")
	return first
