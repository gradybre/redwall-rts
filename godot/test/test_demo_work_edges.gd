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

const BED_CARROTS: int = 2
const NORTH_OAK: int = 32
const HOUR_USEC: int = 2500000
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
	assert_equal(card.members, "Of 2 selected: Placeholder 0 can; Placeholder 1 can't (has a woods job)", card.members)


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
