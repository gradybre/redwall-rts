extends "res://test/framework/test_case.gd"
## The work board's edges (decision 0411): the claim's own rules one at a time -- a claim issues the first walk at once,
## refuses one with another job of that board, honours eligibility and the rescue's hold, breaks ties by distance;
## a paused job is never claimed nor taken back; the farm's blocked words; the crews' old hand-outs stand down; an
## order-list entry names exactly its own task; and a carrier displaced below, in a root cellar, shelves nothing there.
## The work suite's rig (test_demo_work.gd), borrowed. No staged assets.

const WorkTest := preload("res://test/test_demo_work.gd")
const ScreenTest := preload("res://test/test_demo_work_screen.gd")
const IntegrationTest := preload("res://test/test_demo_integration.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const TunnelWork := preload("res://demo/work/tunnel_work.gd")
const WoodsWork := preload("res://demo/work/woods_work.gd")
const BridgeWork := preload("res://demo/work/bridge_work.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const OrdersScript := preload("res://demo/work/work_orders.gd")
const AnswerScript := preload("res://demo/work/queue_answer.gd")
const FarmWork := preload("res://demo/work/farm_work.gd")

const BED_CARROTS: int = 2
const NORTH_OAK: int = 32
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const CARROT: int = 2

var _suite: WorkTest = null


func before_each() -> void:
	"""The work suite's fixtures, borrowed."""
	_suite = WorkTest.new()
	_suite.before_each()


func after_each() -> void:
	"""Free what was built."""
	_suite.after_each()
	_suite = null


func _rig() -> RefCounted:
	"""The work suite's rig."""
	return _suite._rig()


func _brain(rig: RefCounted, who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return _suite._brain(rig, who)


func _rest_all_but(rig: RefCounted, who: int, on: bool) -> void:
	"""Everyone but `who` in bed (`on`), or up again."""
	for i: int in 6:
		if i != who:
			_brain(rig, i).resting = on


# --- the claim --------------------------------------------------------------------------------------

func test_a_claim_sets_the_resident_off_at_once() -> void:
	"""The board's claim issues the job's first walk in the same call (farm, woods, bridge): the resident is under an
	order before anything else could hand it work."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	_rest_all_but(rig, 0, true)
	_suite._crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	board.rebuild_index()
	assert_true(board.consider(0), "claimed")
	assert_equal(_brain(rig, 0).order, BrainScript.ORDER_MOVE, "on its way at once (farm)")
	_rest_all_but(rig, 1, true)
	_brain(rig, 1).resting = false
	(rig.get(&"forestry") as Node).get(&"crew").call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(),
		ForestJobs.ORIGIN_PLAYER)
	board.rebuild_index()
	assert_true(board.consider(1), "claimed")
	assert_equal(_brain(rig, 1).order, BrainScript.ORDER_MOVE, "on its way at once (woods)")
	_rest_all_but(rig, 2, true)
	_brain(rig, 2).resting = false
	_suite._plank_bridge(rig)
	board.rebuild_index()
	assert_true(board.consider(2), "claimed")
	assert_equal(_brain(rig, 2).order, BrainScript.ORDER_MOVE, "on its way at once (bridge)")
	_rest_all_but(rig, -1, false)


func test_a_crew_claim_is_refused_for_one_with_another_job_of_that_board() -> void:
	"""One job a board a resident: the farm's and the woods' `claim` refuse one already on another of theirs."""
	var rig: RefCounted = _rig()
	var farm: FarmCrewScript = rig.get(&"farm")
	_suite._harvest_to(rig, 3)
	var second: Vector2i = _suite._second_farm_task(rig)
	farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, second.x, second.y)
	assert_false(farm.claim(row, 3), "not with a farm job already")
	assert_true(farm.claim(row, 4), "another takes it")
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([1]), ForestJobs.ORIGIN_PLAYER)
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_false(crew.call(&"claim", 1, 1), "not with a woods job already")


func test_an_ineligible_idle_resident_is_not_given_the_task() -> void:
	"""Eligibility is the source's: a badger that fits no bore, idle, is never given a brace in the bore; the mouse is."""
	var screen_suite := ScreenTest.new()
	var site: Array = screen_suite._tunnel_site()
	var brains: Array[BrainScript] = []
	for brain: BrainScript in site[1]:
		brains.append(brain)
	var board := BoardScript.new()
	board.bind(brains, PackedStringArray(["Mouse", "Mole", "Badger"]), [&"mouse_keeper", &"mole_digger", &"badger_quarryman"] as Array[StringName])
	board.add_source(site[3])
	board.rebuild_index()
	assert_false(board.consider(2), "the badger is not given it")
	assert_true(board.consider(0), "the mouse is")


func test_a_resident_held_by_the_rescue_is_never_given_work() -> void:
	"""Held by the water's rescue (and otherwise idle): not once given the waiting harvest, frame after frame."""
	var rig: RefCounted = _rig()
	_rest_all_but(rig, 3, true)
	_brain(rig, 3).water_hold = true
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var farm: FarmCrewScript = rig.get(&"farm")
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var given := [false]
	_suite._run(rig, 2.0, func() -> bool: return false, func() -> void: given[0] = given[0] or farm.jobs.worker[row] == 3)
	assert_false(given[0], "never given it")
	_brain(rig, 3).water_hold = false
	_rest_all_but(rig, 3, false)


func test_between_equals_the_nearer_task_is_taken() -> void:
	"""Same crew priority, same task priority, neither urgent: the nearer of two farm jobs is taken first."""
	var rig: RefCounted = _rig()
	_suite._crews(rig, PackedInt32Array([0, 3, 3, 3, 3, 3]))
	_rest_all_but(rig, 0, true)
	var second: Vector2i = _suite._second_farm_task(rig)
	var farm: FarmCrewScript = rig.get(&"farm")
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var harvest: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var other: int = _suite._farm_row(rig, second.x, second.y)
	var at: Vector2 = _brain(rig, 0).surface_point()
	var near: int = harvest if at.distance_to(Catalog.bed_centre_m(BED_CARROTS)) < at.distance_to(Catalog.bed_centre_m(second.y)) \
		else other
	assert_true(_suite._run(rig, 1.0, func() -> bool: return farm.jobs.worker[near] == 0), "the nearer first")
	_rest_all_but(rig, 0, false)


# --- pausing ------------------------------------------------------------------------------------------

func test_a_paused_farm_job_lets_its_worker_go_and_is_not_claimed() -> void:
	"""Pause on a farm job under way: its worker is let go, the work done kept; nobody claims it while paused."""
	var rig: RefCounted = _rig()
	var farm: FarmCrewScript = rig.get(&"farm")
	var board: BoardScript = rig.get(&"board")
	var row: int = _suite._harvest_to(rig, 3)
	_suite._frame(rig)
	assert_equal(board.pause(WorkIds.SOURCE_FARM, row, true), "", "paused")
	assert_equal([farm.jobs.worker[row], _brain(rig, 3).order], [FarmJobs.NOBODY, BrainScript.ORDER_NONE], "let go")
	assert_false(farm.waiting(row), "not waiting while paused")
	_suite._run(rig, 2.0, func() -> bool: return false)
	assert_equal(farm.jobs.worker[row], FarmJobs.NOBODY, "nobody claimed it")
	var task := TaskScript.new()
	board.fill(WorkIds.SOURCE_FARM, row, task)
	assert_equal(task.state, WorkIds.STATE_PAUSED, "said")


func test_a_farm_job_waiting_for_a_way_says_so() -> void:
	"""A farm job nobody could get to waits BLOCKED, in the farm's words (lifted at its next hour)."""
	var rig: RefCounted = _rig()
	var farm: FarmCrewScript = rig.get(&"farm")
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	farm.jobs.blocked[row] = FarmJobs.BLOCK_WAY
	var task := TaskScript.new()
	(rig.get(&"board") as BoardScript).fill(WorkIds.SOURCE_FARM, row, task)
	assert_equal([task.state, task.reason], [WorkIds.STATE_BLOCKED, "can't reach it — tried again at the farm's next hour"],
		"in words")


func test_a_woods_delivery_is_not_cancelled() -> void:
	"""Cancel on a woods delivery (logs carried on after their haul was cancelled) is refused: it always finishes."""
	var rig: RefCounted = _rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	var jobs: ForestJobs = crew.get(&"jobs")
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array([2]), ForestJobs.ORIGIN_PLAYER)
	assert_true(_suite._run(rig, 120.0, func() -> bool: return jobs.load_milli[0] > 0), "logs in hand")
	var board: BoardScript = rig.get(&"board")
	assert_equal(board.cancel(WorkIds.SOURCE_WOODS, 0), "", "the sawing cancelled")
	assert_true(jobs.is_delivery(0), "carried back")
	assert_equal(board.cancel(WorkIds.SOURCE_WOODS, 0), WorkIds.DELIVERY_GOES_ON, "a delivery goes on")


# --- the old crews, the bridge's builder, the order list ---------------------------------------------------

func test_the_woods_old_crew_stands_down_too() -> void:
	"""With the board claiming, the woods' own routine crew hands nothing out: a woods job its board crews forbid waits
	though the old crew has members."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	for crew: int in CrewsScript.CREW_COUNT:
		board.crews.set_priority(crew, WorkIds.ACT_WOODS, WorkIds.PRIORITY_FORBIDDEN)
	var woods: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	woods.call(&"set_crew", PackedInt32Array([0, 1, 2, 3, 4, 5]))
	woods.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	_suite._run(rig, 2.0, func() -> bool: return false)
	assert_equal((woods.get(&"jobs") as ForestJobs).worker[0], ForestJobs.NOBODY, "no hand-out")


func test_a_mixed_group_on_a_woods_card_previews_each_member() -> void:
	"""UX-001 on the woods' cards: one selected with a woods job already can't, the others can."""
	var rig: RefCounted = _rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array([1]), ForestJobs.ORIGIN_PLAYER)
	var card := CardScript.new()
	crew.call(&"preview_into", card, ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([0, 1]))
	assert_equal(card.members, "Of 2 selected: Placeholder 0 can; Placeholder 1 can't (has another woods job)", card.members)


func test_a_reassigned_bridge_lets_its_old_builder_go() -> void:
	"""Reassigned, a bridge's builder is let go -- back to its routine, its planks put down -- and the new one sent."""
	var rig: RefCounted = _rig()
	_suite._plank_bridge(rig)
	var board: BoardScript = rig.get(&"board")
	var crew: BridgeCrewScript = (rig.get(&"play") as Node).get(&"crew")
	assert_equal(board.reassign(WorkIds.SOURCE_BRIDGES, 0, 1), "", "to resident 1")
	_suite._frame(rig)
	assert_equal(board.reassign(WorkIds.SOURCE_BRIDGES, 0, 3), "", "to resident 3")
	assert_equal([crew.builder[0], _brain(rig, 1).order, _brain(rig, 3).order], [3, BrainScript.ORDER_NONE,
		BrainScript.ORDER_MOVE], "1 let go, 3 sent")


func test_an_entry_names_only_its_own_task() -> void:
	"""An order-list entry names its task by source AND key: a new job in the same row is not promised by it."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var brain := _brain(rig, 0)
	brain.order_move(brain.position + Vector2(1.0, 0.0))
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var jobs: ForestJobs = crew.get(&"jobs")
	var first: int = jobs.serial[0]
	board.queue_task(WorkIds.SOURCE_WOODS, 0, 0)
	board.cancel(WorkIds.SOURCE_WOODS, 0)
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_true(brain.promises(WorkIds.SOURCE_WOODS, first), "its own task")
	assert_false(brain.promises(WorkIds.SOURCE_WOODS, jobs.serial[0]), "not the new one in its row")


# --- a root cellar ----------------------------------------------------------------------------------------

func test_a_carrier_displaced_below_shelves_nothing_from_there() -> void:
	"""The arrival recheck below: a carrier holding in the root cellar moved off its spot mid-drop shelves nothing there,
	and walks back to the cellar's middle first."""
	var it := IntegrationTest.new()
	it.before_each()
	var farm: DemoFarmScript = it._village(true)
	it._dig_cellar(it.get(&"_command").tunnels().network, Vector2(-6.0, 12.8))
	farm.step(24 * HOUR_USEC)
	var cast: DemoCastScript = farm.get(&"_cast")
	var brain: BrainScript = (cast.actor(3) as DemoActorScript).brain
	brain.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.4], [0.0, 0.8]], "mean_speed_m_s": 0.4, "period_s": 2.0})
	farm.crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var dropping := func() -> bool: return farm.crew.jobs.is_live(0) and brain.underground \
		and farm.crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_DROP and farm.crew.jobs.issued[0] == 1
	for frame: int in roundi(240.0 / (1.0 / 60.0)):
		if dropping.call():
			break
		cast.advance(1.0 / 60.0)
		farm.crew.update(cast.clock.frame_usec)
	assert_true(dropping.call(), "shelving it below")
	brain.position += Vector2(3.0, 0.0)
	farm.crew.update(FarmJobs.work_usec_of(FarmJobs.WORK_DROP))
	assert_equal(farm.pantry.total_milli(), 0, "nothing shelved from three metres off")
	assert_equal(farm.crew.jobs.current_step(0), FarmJobs.STEP_CARRY_STORE, "back to its walk")
	it.after_each()


func test_a_candidate_taken_in_the_same_pass_is_passed_over_for_the_next() -> void:
	"""Two farm jobs indexed, one urgent (both residents' first choice); resident 0 takes it; resident 1, considered in
	the same period, passes over it (taken) and takes the other at once."""
	var rig: RefCounted = _rig()
	_suite._crews(rig, PackedInt32Array([0, 0, 0, 3, 3, 3]))
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	var second: Vector2i = _suite._second_farm_task(rig)
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var harvest: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var other: int = _suite._farm_row(rig, second.x, second.y)
	board.set_urgent(WorkIds.SOURCE_FARM, harvest, true)
	board.rebuild_index()
	assert_true(board.consider(0), "resident 0 takes the urgent one")
	assert_equal(farm.jobs.worker[harvest], 0, "the urgent one")
	assert_true(board.consider(1), "resident 1 passes over it, taken, to the other, in the same pass")
	assert_equal(farm.jobs.worker[other], 1, "the other")
	farm.cancel_row(harvest)
	farm.cancel_row(other)
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	harvest = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	other = _suite._farm_row(rig, second.x, second.y)
	board.set_urgent(WorkIds.SOURCE_FARM, harvest, true)
	board.rebuild_index()
	assert_equal(board.reassign(WorkIds.SOURCE_FARM, harvest, 3), "", "taken outside the claim, after the index was built")
	assert_true(board.consider(2), "resident 2 passes over it to the other")
	assert_equal(farm.jobs.worker[other], 2, "the other")


func test_reassign_refuses_one_held_by_the_rescue() -> void:
	"""The board's Reassign asks the resident's own state first: one held by the rescue is refused in words."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	_brain(rig, 2).water_hold = true
	assert_equal(board.reassign(WorkIds.SOURCE_FARM, row, 2), BoardScript.HELD, "refused")
	assert_equal((rig.get(&"farm") as FarmCrewScript).jobs.worker[row], FarmJobs.NOBODY, "not given")
	_brain(rig, 2).in_water = true
	_brain(rig, 2).water_hold = false
	assert_equal(board.reassign(WorkIds.SOURCE_FARM, row, 2), BoardScript.IN_WATER, "in the water: refused")
	_brain(rig, 2).in_water = false


func test_has_job_reads_every_board() -> void:
	"""Whether a resident holds a task on some board (the Residents view's status reads it)."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	assert_false(board.has_job(3), "nothing yet")
	_suite._harvest_to(rig, 3)
	assert_true(board.has_job(3), "a farm job")
	(rig.get(&"forestry") as Node).get(&"crew").call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([4]),
		ForestJobs.ORIGIN_PLAYER)
	assert_true(board.has_job(4), "a woods job")
	assert_false(board.has_job(5), "none")


func test_one_woods_job_and_one_bridge_a_resident_in_the_picker() -> void:
	"""The picker's words are the commands' refusals: one with a woods job is not eligible for another; one building a
	bridge is not eligible for a second bridge."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array([1]), ForestJobs.ORIGIN_PLAYER)
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_equal(board.eligibility_words(WorkIds.SOURCE_WOODS, 1, 1), WoodsWork.OTHER_JOB, "the picker's words")
	assert_equal(board.reassign(WorkIds.SOURCE_WOODS, 1, 1), WoodsWork.OTHER_JOB, "the command's")
	_suite._plank_bridge(rig)
	assert_equal(board.reassign(WorkIds.SOURCE_BRIDGES, 0, 2), "", "a builder")
	var play: Node = rig.get(&"play")
	var bridges: RefCounted = play.get(&"bridges")
	var second: int = -1
	var said: String = ""
	for k: int in range(1, int(bridges.call(&"candidate_count"))):
		play.call(&"select_candidate", k)
		said = play.call(&"build", SwimRules.KIND_PLANK, PackedInt32Array())
		if bool(bridges.call(&"is_planned", 1)):
			second = 1
			break
	assert_true(second == 1, "a second bridge planned: %s" % said)
	assert_equal(board.eligibility_words(WorkIds.SOURCE_BRIDGES, second, 2), BridgeWork.OTHER_BRIDGE, "busy on the first")
	assert_equal(board.reassign(WorkIds.SOURCE_BRIDGES, second, 2), BridgeWork.OTHER_BRIDGE, "the command's words")


func test_a_tunnel_worker_called_away_keeps_its_job_promised() -> void:
	"""A tunnel job's worker called away keeps the job on its list naming it (tunnel_job_task.gd `unfinished`): the
	board's claim leaves it to that worker, who takes it back when its order is done."""
	var screen_suite := ScreenTest.new()
	var site: Array = screen_suite._tunnel_site()
	var brains: Array[BrainScript] = []
	for brain: BrainScript in site[1]:
		brains.append(brain)
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	var board := BoardScript.new()
	board.bind(brains, PackedStringArray(["Mouse", "Mole", "Badger"]), [&"mouse_keeper", &"mole_digger", &"badger_quarryman"] as Array[StringName])
	board.add_source(work)
	assert_true(work.claim(bore, 0), "the mouse on it")
	brains[0].order_move(brains[0].position + Vector2(-1.0, 0.0))
	assert_true(brains[0].promises(WorkIds.SOURCE_TUNNELS, work.key(bore)), "kept to come back to, naming its job")
	board.rebuild_index()
	assert_false(board.consider(1), "the mole is not given it")
	brains[0].work_done()
	assert_equal(work.worker(bore), 0, "the mouse takes it back")


# --- the review's findings (decision 0411's review) ------------------------------------------------

func test_a_task_queued_after_a_plain_move_is_taken_when_the_move_arrives() -> void:
	"""Shift after a plain right-click move: the move is the order's Now; when it arrives the queued harvest is taken
	up -- the queued task never starves, promised to a resident that would only hold."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	var brain := _brain(rig, 0)
	brain.order_move(brain.position + Vector2(1.5, 0.0))
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	assert_equal(board.queue_task(WorkIds.SOURCE_FARM, row, 0), "", "queued behind the move")
	assert_true(_suite._run(rig, 30.0, func() -> bool: return farm.jobs.worker[row] == 0), "taken once the move arrived")
	assert_equal(brain.queue_size(), 0, "nothing left on its list")


func test_an_idle_resident_takes_its_own_list_before_the_boards_claim() -> void:
	"""An idle resident with an entry on its list takes that up first, before the board's best for it."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var brain := _brain(rig, 0)
	var taken := [false]
	brain.append_queued(UnfinishedScript.new(func(_b: RefCounted) -> bool:
		taken[0] = true
		return true, "mine"))
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	board.rebuild_index()
	assert_true(board.consider(0), "it took something")
	assert_true(taken[0], "its own entry, first")


func test_a_promised_task_claimed_by_its_resident_leaves_no_stale_entry_and_reassign_frees_it() -> void:
	"""A task queued for a resident in the water is claimed for it by the board once it is out; the entry goes with the
	claim, so a later Reassign lets that resident go cleanly -- free, not left holding with no job."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	_suite._crews(rig, PackedInt32Array([0, 3, 3, 3, 3, 3]))
	_rest_all_but(rig, 0, true)
	var brain := _brain(rig, 0)
	brain.in_water = true
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	assert_equal(board.queue_task(WorkIds.SOURCE_FARM, row, 0), "", "queued while in the water")
	brain.in_water = false
	board.rebuild_index()
	assert_true(board.consider(0), "claimed for it")
	assert_equal(farm.jobs.worker[row], 0, "its own")
	assert_false(brain.promises(WorkIds.SOURCE_FARM, farm.jobs.serial[row]), "no stale entry left")
	_brain(rig, 3).resting = false
	assert_equal(board.reassign(WorkIds.SOURCE_FARM, row, 3), "", "reassigned")
	assert_equal([farm.jobs.worker[row], brain.order], [3, BrainScript.ORDER_NONE], "the old worker let go, free")
	_rest_all_but(rig, 0, false)


func test_idle_leaves_out_every_resident_kept_from_work() -> void:
	"""Underground, lying down, indoors, in the water or crossing: never given work by the board."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var brain := _brain(rig, 0)
	assert_true(board.idle(0), "idle to start with")
	for flag: StringName in [&"underground", &"lying", &"indoors", &"in_water"]:
		brain.set(flag, true)
		assert_false(board.idle(0), "%s: not idle" % flag)
		brain.set(flag, false)
	brain.state = BrainScript.State.CROSS
	assert_false(board.idle(0), "crossing: not idle")
	brain.state = BrainScript.State.IDLE
	board.track_walk(0, Vector2(1.0, 1.0))
	assert_false(board.idle(0), "on a queued walk: not idle")


func test_shift_on_a_task_that_cannot_be_taken_is_not_called_taken() -> void:
	"""The queue's answer says what happened: a paused harvest queued for an idle resident is not taken (it waits for
	Resume), so the answer is a refusal, not "on it now"; a task under way is refused as such; a full list refuses."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	var orders := OrdersScript.new()
	orders.configure(board, null, rig.get(&"forestry"), null)
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	board.pause(WorkIds.SOURCE_FARM, row, true)
	var said: String = orders.queue_task(WorkIds.SOURCE_FARM, row, 0)
	assert_true(said.begins_with("Can't queue:") and said.ends_with("cannot be taken now"), said)
	assert_equal(farm.jobs.worker[row], FarmJobs.NOBODY, "nobody on it")
	board.pause(WorkIds.SOURCE_FARM, row, false)
	board.reassign(WorkIds.SOURCE_FARM, row, 3)
	said = orders.queue_task(WorkIds.SOURCE_FARM, row, 0)
	assert_true(said.ends_with("is on it"), "under way: %s" % said)
	var walks := OrdersScript.new()
	walks.configure(board, null, null, null)
	var answer: AnswerScript = walks.queue_at(Vector2.ZERO, Vector2(1.0, 1.0), PackedInt32Array([1]))
	assert_true(answer.ok and answer.words == OrdersScript.WALK_QUEUED % 1, "a walk queued, ok")
	for k: int in 8:
		_brain(rig, 2).append_queued(UnfinishedScript.new(func(_b: RefCounted) -> bool: return false, "x%d" % k))
	answer = walks.queue_at(Vector2.ZERO, Vector2(2.0, 2.0), PackedInt32Array([2]))
	assert_false(answer.ok, "a full list: refused (%s)" % answer.words)
	assert_true(answer.words.begins_with("Can't queue:"), answer.words)


func test_a_command_or_a_queued_order_re_indexes_at_once() -> void:
	"""The candidate index is rebuilt once a claim period -- and at the next update after a command or a queued order,
	so the claim never works from a list the player just changed."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	board.update(1)
	var rebuilt: int = board.index_rebuilds
	board.update(1)
	assert_equal(board.index_rebuilds, rebuilt, "not rebuilt mid-period")
	assert_equal(board.set_task_priority(WorkIds.SOURCE_FARM, row, WorkIds.PRIORITY_HIGH), true, "a priority set")
	board.pause(WorkIds.SOURCE_FARM, row, true)
	board.update(1)
	assert_equal(board.index_rebuilds, rebuilt + 1, "a command: rebuilt at the next update")
	_brain(rig, 1).order_move(_brain(rig, 1).position + Vector2(1.0, 0.0))
	board.queue_walk(1, Vector2(3.0, 3.0))
	board.update(1)
	assert_equal(board.index_rebuilds, rebuilt + 2, "a queued order: rebuilt at the next update")


func test_a_shift_order_to_a_resident_at_a_work_spot_starts_at_once() -> void:
	"""A work-spot order has no end of its own: a queued walk given to a resident working at a spot is taken up at
	once."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var brain := _brain(rig, 0)
	brain.order_work(0, 0)
	assert_equal(brain.order, BrainScript.ORDER_WORK, "working at a spot")
	var goal := Vector2(1.0, 1.0)
	assert_equal(board.queue_walk(0, goal), "", "queued")
	assert_equal([brain.order, brain.goal()], [BrainScript.ORDER_MOVE, goal], "on its way at once")


func test_a_shift_order_never_cuts_a_jobs_walk_short() -> void:
	"""Queued behind a resident walking to its farm job: the job's walk is not taken for a plain move -- on arrival the
	resident works the job; the queued walk waits on its list until the job is done."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	var row: int = _suite._harvest_to(rig, 3)
	_suite._frame(rig)
	assert_equal(board.queue_walk(3, Vector2(1.0, 1.0)), "", "a walk queued behind the job")
	var cutting := func() -> bool: return farm.jobs.current_step(row) == FarmJobs.STEP_WORK + FarmJobs.WORK_HARVEST \
		and farm.jobs.elapsed_usec[row] > 0
	assert_true(_suite._run(rig, 90.0, cutting), "working the harvest")
	assert_equal([farm.jobs.worker[row], _brain(rig, 3).queue_size()], [3, 1], "its job, the walk still waiting")


func test_a_reassign_to_a_resident_that_had_the_task_queued_clears_its_entry() -> void:
	"""A task queued for resident 1 is reassigned to resident 1 directly: its entry naming the task goes."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	_brain(rig, 1).resting = true
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	board.queue_task(WorkIds.SOURCE_FARM, row, 1)
	_brain(rig, 1).resting = false
	assert_equal(board.reassign(WorkIds.SOURCE_FARM, row, 1), "", "reassigned to it")
	assert_false(_brain(rig, 1).promises(WorkIds.SOURCE_FARM, farm.jobs.serial[row]), "its entry gone")


func test_a_task_taken_up_from_the_list_leaves_no_second_entry_for_it() -> void:
	"""Two entries naming the same task (a queued one and a job kept from an interruption): the first taken up hands the
	task over and the other goes with it."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var farm: FarmCrewScript = rig.get(&"farm")
	var brain := _brain(rig, 1)
	brain.resting = true
	farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _suite._farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	board.queue_task(WorkIds.SOURCE_FARM, row, 1)
	brain.remember_unfinished(farm.unfinished_of(row))
	assert_equal(brain.queue_size(), 2, "two entries for one task")
	brain.resting = false
	assert_true(brain.take_up_unfinished(), "taken up")
	assert_equal(farm.jobs.worker[row], 1, "its")
	assert_false(brain.promises(WorkIds.SOURCE_FARM, farm.jobs.serial[row]), "no entry left naming it")


func _stale_reassign(rig: RefCounted, source: int, row: int, serial: int) -> void:
	"""Resident 0, on task (source, row), also has it queued (a stale entry); the task is reassigned to 3: 0 must end
	free, not pulled back to the task and left holding."""
	var board: BoardScript = rig.get(&"board")
	board.queue_task(source, row, 0)
	assert_true(_brain(rig, 0).promises(source, serial), "the stale entry")
	assert_equal(board.reassign(source, row, 3), "", "reassigned to 3")
	assert_true(board.source(source).worker(row) == 3, "3 on it")
	assert_equal(_brain(rig, 0).order, BrainScript.ORDER_NONE, "0 let go, free")


func test_a_reassign_never_lets_the_old_worker_take_the_task_back() -> void:
	"""The farm and the woods hand the task to the new worker BEFORE letting the old one go, so even an entry naming it
	on the old worker's list cannot pull it back and leave it holding with no job."""
	var rig: RefCounted = _rig()
	var farm: FarmCrewScript = rig.get(&"farm")
	var row: int = _suite._harvest_to(rig, 0)
	_suite._frame(rig)
	_stale_reassign(rig, WorkIds.SOURCE_FARM, row, farm.jobs.serial[row])
	var other: RefCounted = _rig()
	var crew: RefCounted = (other.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([0]), ForestJobs.ORIGIN_PLAYER)
	_suite._frame(other)
	_stale_reassign(other, WorkIds.SOURCE_WOODS, 0, (crew.get(&"jobs") as ForestJobs).serial[0])


func test_a_queued_woods_order_checks_the_list_before_posting() -> void:
	"""Shift on a tree with the nearest resident's list full: refused, and no felling put on the board for nobody."""
	var rig: RefCounted = _rig()
	var board: BoardScript = rig.get(&"board")
	var orders := OrdersScript.new()
	orders.configure(board, null, rig.get(&"forestry"), null)
	for k: int in 8:
		_brain(rig, 2).append_queued(UnfinishedScript.new(func(_b: RefCounted) -> bool: return false, "x%d" % k))
	var said: String = orders._queue_woods(4, NORTH_OAK, PackedInt32Array([2]))
	assert_true(said.begins_with("Can't queue:"), said)
	var jobs: ForestJobs = ((rig.get(&"forestry") as Node).get(&"crew") as RefCounted).get(&"jobs")
	assert_equal(jobs.live_count(), 0, "nothing put on the board")


func test_a_queued_bed_order_checks_the_list_before_posting() -> void:
	"""Shift on a ripe bed with the resident's list full: refused, and no harvest put on the board for nobody."""
	var it := IntegrationTest.new()
	it.before_each()
	var farm: DemoFarmScript = it._village(false)
	farm.step(24 * HOUR_USEC)
	var cast: DemoCastScript = farm.get(&"_cast")
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in cast.actor_count():
		brains.append((cast.actor(i) as DemoActorScript).brain)
		names.append("R%d" % i)
		keys.append(&"mouse_keeper")
	var board := BoardScript.new()
	board.bind(brains, names, keys)
	board.add_source(FarmWork.new(farm.crew))
	var orders := OrdersScript.new()
	orders.configure(board, farm, null, null)
	for k: int in 8:
		brains[0].append_queued(UnfinishedScript.new(func(_b: RefCounted) -> bool: return false, "x%d" % k))
	farm.crew.cancel_bed(BED_CARROTS)
	var before: int = farm.crew.jobs.live_count()
	var said: String = orders._queue_bed(BED_CARROTS, PackedInt32Array([0]))
	assert_true(said.begins_with("Can't queue:"), said)
	assert_equal(farm.crew.jobs.live_count(), before, "nothing put on the board")
	it.after_each()
