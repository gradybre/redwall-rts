extends "res://test/framework/test_case.gd"
## Coming back to unfinished jobs (resident_brain.gd RESUMING, cast/unfinished_job.gd). Decision 0205:
## the playtest's mole, ordered to hang lanterns and then to raise a bed, raised the bed and never went
## back to the lanterns. Pure logic on hand-built spaces; the tunnel job's own take-back is checked in
## test_demo_tunnel_ext_world.gd, the farm's and the spoil crew's in their suites.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const DT: float = 1.0 / 60.0
const BODY_M: float = 0.25
const WALK_M_S: float = 0.8
const SEED: int = 5151


## A task that runs `frames` steps and then ends; called away, it can be come back to.
class CountedTask extends "res://demo/tunnel/tunnel_task.gd":
	var name: String = ""
	var frames: int = 0
	var cancelled: int = 0
	var comeback: bool = true

	func _init(task_name: String, steps: int) -> void:
		"""A task called `task_name` that lasts `steps` steps."""
		name = task_name
		frames = steps

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Count down; over at zero."""
		frames -= 1
		return frames > 0

	func cancel(_brain: RefCounted) -> void:
		"""Called away."""
		cancelled += 1

	func unfinished() -> RefCounted:
		"""Itself, taken back by ordering it again (unless `comeback` is off)."""
		if not comeback:
			return null
		return UnfinishedScript.new(func(brain: RefCounted) -> bool:
			(brain as BrainScript).order_task(self)
			return true, name)

	func label() -> String:
		"""Its name."""
		return name


func _lengths() -> Dictionary:
	"""Every clip the brain knows, with round lengths."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _space() -> CastSpaceScript:
	"""An open space with one POI."""
	var space := CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": &"here", "position": Vector3.ZERO, "face": Vector3(0, 0, 1),
		"activities": [&"collect_object"] as Array[StringName], "capacity": 1}]
	space.setup(points, [] as Array[Vector3])
	return space


func _brain(space: CastSpaceScript) -> BrainScript:
	"""A resident standing at (2, 2)."""
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	brain.start_at(Vector2(2.0, 2.0), 0.0, -1, -1)
	return brain


func _run(brain: BrainScript, frames: int) -> void:
	"""Step the brain."""
	for f: int in frames:
		brain.step(DT)


func _job(job_log: Array[String], job_name: String, still_waits: bool) -> UnfinishedScript:
	"""A remembered job that logs being taken back and answers `still_waits`."""
	return UnfinishedScript.new(func(_resident: RefCounted) -> bool:
		job_log.append(job_name)
		return still_waits, job_name)


func test_the_latest_unfinished_jobs_are_kept_latest_first() -> void:
	"""At most RESUME_MAX are kept (the oldest goes); taken up latest first; a stale one (no longer
	waiting) is dropped on the way to the next."""
	var brain := _brain(_space())
	var job_log: Array[String] = []
	for k: int in 4:
		brain.remember_unfinished(_job(job_log, "job %d" % k, k != 2))
	brain.remember_unfinished(null)
	assert_equal(BrainScript.RESUME_MAX, 3, "three kept")
	assert_equal(brain.unfinished_labels(), PackedStringArray(["job 3", "job 2", "job 1"]), "latest first, oldest gone")
	assert_true(brain.take_up_unfinished(), "job 3 taken up")
	assert_equal(job_log, ["job 3"] as Array[String], "only it")
	assert_true(brain.take_up_unfinished(), "job 2 was stale; job 1 taken up")
	assert_equal(job_log, ["job 3", "job 2", "job 1"] as Array[String], "the stale one asked on the way")
	assert_false(brain.take_up_unfinished(), "nothing left")


func test_a_task_called_away_is_taken_back_when_the_other_ends() -> void:
	"""Hang lanterns (a task) is called away by another task; when that one ends on its own, the brain
	goes back to the first -- the same job, not a new one."""
	var brain := _brain(_space())
	var lanterns := CountedTask.new("lanterns", 100000)
	var raise := CountedTask.new("raise the bed", 3)
	brain.order_task(lanterns)
	brain.order_task(raise)
	assert_equal(lanterns.cancelled, 1, "the lanterns were called away")
	assert_equal(brain.unfinished_labels(), PackedStringArray(["lanterns"]), "and kept")
	_run(brain, 400)
	assert_true(brain.task == lanterns, "back on the lanterns once the bed is raised")
	assert_equal(brain.order, BrainScript.ORDER_TASK, "under the task")
	assert_equal(brain.unfinished_labels().size(), 0, "nothing more to come back to")


func test_a_task_with_nothing_to_come_back_to_is_not_kept() -> void:
	"""An evacuation or a crew place (unfinished() null) is not remembered."""
	var brain := _brain(_space())
	var errand := CountedTask.new("errand", 100000)
	errand.comeback = false
	brain.order_task(errand)
	brain.order_move(Vector2(-2.0, -2.0))
	assert_equal(brain.unfinished_labels().size(), 0, "nothing kept")


func test_work_done_takes_up_the_job_and_release_forgets_them() -> void:
	"""A crew's job done (work_done) takes up the latest unfinished job; the player's R (release) forgets
	them all and sends it wandering."""
	var brain := _brain(_space())
	var lanterns := CountedTask.new("lanterns", 100000)
	brain.order_task(lanterns)
	brain.order_move(Vector2(-2.0, -2.0))
	brain.work_done()
	assert_true(brain.task == lanterns, "work done: back on the lanterns")
	brain.order_move(Vector2(-2.0, -2.0))
	assert_equal(brain.unfinished_labels().size(), 1, "called away again: kept")
	brain.release()
	assert_equal(brain.unfinished_labels().size(), 0, "R forgets")
	assert_equal(brain.order, BrainScript.ORDER_NONE, "and it wanders")


func test_work_done_with_nothing_kept_is_a_release() -> void:
	"""With nothing to come back to, work_done lets the resident go as release does."""
	var brain := _brain(_space())
	brain.order_move(Vector2(-2.0, -2.0))
	brain.work_done()
	assert_equal(brain.order, BrainScript.ORDER_NONE, "wandering")


func test_a_dig_called_away_is_resumed() -> void:
	"""A mole called away from a dig with progress leaves the segment paused and keeps it; its next work
	done sends it back to dig the same tunnel. One called away before a tick was dug keeps nothing."""
	var space := _space()
	var mole := _brain(space)
	var ref := PackedInt32Array([-1, 0, -1])
	# A 12 m mouth-to-mouth tunnel (the shortest is 8 m: two 4 m ramps); its first segment, the entrance
	# ramp, is the one dug, left and resumed.
	assert_true(space.tunnels.add_into(PackedInt32Array([0, 4096, 12288, 4096]), 2, mole.index, ref), "a tunnel")
	mole.order_dig(ref[0], ref[1])
	space.tunnels.advance(ref[0], ref[1], 2000000)
	mole.order_move(Vector2(-2.0, -2.0))
	assert_equal(space.tunnels.phase[ref[0]], GraphScript.PHASE_PAUSED, "paused with its progress")
	assert_equal(mole.unfinished_labels(), PackedStringArray(["Dig tunnel %d" % (ref[0] + 1)]), "kept")
	mole.work_done()
	assert_equal(mole.order, BrainScript.ORDER_DIG, "digging again")
	assert_equal(mole.dig_tunnel, ref[0], "the same tunnel")
	assert_equal(space.tunnels.phase[ref[0]], GraphScript.PHASE_DIGGING, "resumed")
	var fresh := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(PackedInt32Array([-16384, -4096, -4096, -4096]), 2, mole.index, fresh), "another")
	mole.order_dig(fresh[0], fresh[1])
	assert_equal(mole.unfinished_labels(), PackedStringArray(["Dig tunnel %d" % (ref[0] + 1)]),
		"leaving the first dig for the second keeps the first")
	mole.order_move(Vector2(-2.0, -2.0))
	assert_equal(mole.unfinished_labels().size(), 1, "the second had nothing dug: not kept (its piece was dropped)")
	assert_equal(space.tunnels.phase[fresh[0]], GraphScript.PHASE_FREE, "the second piece's first segment freed")


func test_no_job_is_taken_up_in_the_water() -> void:
	"""A crew's job done while its worker is in the water: it swims ashore first (as release), keeping
	the job for later."""
	var brain := _brain(_space())
	var job_log: Array[String] = []
	brain.remember_unfinished(_job(job_log, "lanterns", true))
	brain.order_move(Vector2(-2.0, -2.0))
	brain.in_water = true
	brain.work_done()
	assert_equal(job_log.size(), 0, "not taken up in the water")
	assert_equal(brain.unfinished_labels().size(), 1, "kept")


func test_a_kept_dig_does_not_keep_its_brain_alive() -> void:
	"""Review C1: the brain keeps its jobs, so a job must not keep the brain -- a mole with a paused dig
	kept is freed once nothing else holds it."""
	var space := _space()
	var mole := _brain(space)
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 4096, 12288, 4096]), 2, mole.index, ref)
	mole.order_dig(ref[0], ref[1])
	space.tunnels.advance(ref[0], ref[1], 2000000)
	mole.order_move(Vector2(-2.0, -2.0))
	assert_equal(mole.unfinished_labels().size(), 1, "the dig kept")
	var watch: WeakRef = weakref(mole)
	mole = null
	assert_true(watch.get_ref() == null, "the brain was freed")


func test_the_same_job_kept_twice_is_kept_once() -> void:
	"""A job kept again (the same words) moves to the latest place rather than filling a second one."""
	var brain := _brain(_space())
	var job_log: Array[String] = []
	brain.remember_unfinished(_job(job_log, "lanterns", true))
	brain.remember_unfinished(_job(job_log, "raise bed 3", true))
	brain.remember_unfinished(_job(job_log, "lanterns", true))
	assert_equal(brain.unfinished_labels(), PackedStringArray(["lanterns", "raise bed 3"]), "once, latest first")
