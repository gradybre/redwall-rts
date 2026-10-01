extends "res://test/framework/test_case.gd"
## The Work screen (decision 0411, review F32; F22, SOC-004, UX-002, UX-007) over the real work board and owners, built
## out of the tree and driven by its own buttons' `pressed` -- what each row shows and what each command does -- and the
## work board's adapters for the tunnels', the fit-out's and the spoil heaps' jobs, and Shift+right-click's queue. The
## real-input checks at 1280x720 and 1920x1080 are the live harness's (test/live/demo_input_live.gd). No staged assets.

const WorkTest := preload("res://test/test_demo_work.gd")
const ScreenScript := preload("res://demo/work/work_screen.gd")
const TaskRowScript := preload("res://demo/work/work_task_row.gd")
const ResidentRowScript := preload("res://demo/work/work_resident_row.gd")
const OrdersScript := preload("res://demo/work/work_orders.gd")
const TunnelWork := preload("res://demo/work/tunnel_work.gd")
const SpoilWork := preload("res://demo/work/spoil_work.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelJobs := preload("res://demo/tunnel/tunnel_jobs.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const SpoilCrewScript := preload("res://demo/spoil/spoil_crew.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const HandoffsTest := preload("res://test/test_demo_handoffs.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const ActionCardsTest := preload("res://test/test_demo_action_cards.gd")
const FitOutWork := preload("res://demo/work/fit_out_work.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const InstallTaskScript := preload("res://demo/burrow/install_task.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")

const BED_CARROTS: int = 2
const NORTH_OAK: int = 32
const WEST_OAK: int = 33
const DT: float = 1.0 / 60.0
const DIG_ROUTE: PackedInt32Array = [0, 0, 12288, 0]

var _suite: WorkTest = null
var _nodes: Array[Object] = []
var _jumps: Array = []


func before_each() -> void:
	"""The work suite's fixtures, borrowed."""
	_suite = WorkTest.new()
	_suite.before_each()
	_jumps.clear()


func after_each() -> void:
	"""Free what was built."""
	for node: Object in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_suite.after_each()
	_suite = null


func _screen(rig: RefCounted, paused: bool = false, selected: PackedInt32Array = PackedInt32Array()) -> ScreenScript:
	"""A Work screen over the rig's board, open, with `selected` selected; "Go to" recorded rather than done."""
	var board: BoardScript = rig.get(&"board")
	var screen := ScreenScript.new()
	_nodes.append(screen)
	screen.configure(board, func(_who: int) -> String: return "wandering", func() -> bool: return paused)
	screen.set_readouts(func(_who: int) -> String: return "wandering", func() -> bool: return paused,
		func() -> PackedInt32Array: return selected)
	board.set_jump(func(kind: int, id: int, _at: Vector2) -> bool:
		_jumps.append([kind, id])
		return true)
	screen.toggle()
	return screen


func _row_titled(screen: ScreenScript, start: String) -> TaskRowScript:
	"""The first task row whose title begins `start` (null: none)."""
	for row: TaskRowScript in screen.task_rows_shown():
		if row.title().begins_with(start):
			return row
	return null


func _press(button: Button) -> void:
	"""Press `button` as a click would (only an enabled one)."""
	if not button.disabled:
		button.pressed.emit()


# --- the Tasks view ----------------------------------------------------------------------------------

func test_an_empty_board_says_so_and_how_to_make_work() -> void:
	"""No work: the header says so, the list says how to order some -- and a paused village is said to be paused, not
	read as blocked work."""
	var rig: RefCounted = _suite._rig()
	var screen := _screen(rig, true)
	assert_equal(screen.summary_text(), "No work waiting" + ScreenScript.PAUSED_NOTE, "nothing, paused")
	assert_equal(screen.task_rows_shown().size(), 0, "no rows")


func test_each_row_says_target_action_worker_state_work_left_and_resume_intent() -> void:
	"""A harvest given to resident 3 and a felling queued with nobody: one row each -- what and where, who, its state
	and the work left; the queued one waits for a free resident; a task resident 0 has queued says so."""
	var rig: RefCounted = _suite._rig()
	var farm: RefCounted = rig.get(&"farm")
	farm.call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var forestry: Node = rig.get(&"forestry")
	forestry.get(&"crew").call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var board: BoardScript = rig.get(&"board")
	board.brain_of(0).order_move(board.brain_of(0).position + Vector2(1.0, 0.0))
	assert_equal(board.queue_task(WorkIds.SOURCE_WOODS, 0, 0), "", "queued for resident 0, who is busy")
	var screen := _screen(rig)
	var harvest := _row_titled(screen, "Harvest")
	assert_not_null(harvest, "the harvest's row")
	assert_equal(harvest.title(), "Harvest — the carrot bed · Placeholder 3", "what, where, who")
	assert_true(harvest.detail().contains("left"), "the work left: %s" % harvest.detail())
	var fell := _row_titled(screen, "Fell")
	assert_true(fell.title().ends_with("nobody yet"), fell.title())
	assert_true(fell.detail().begins_with("Queued: waits for a free resident who can do it"), fell.detail())
	assert_true(fell.detail().ends_with("queued for Placeholder 0 (next)"), "its resume intent: %s" % fell.detail())
	assert_equal(screen.summary_text().left(8), "2 tasks:", "counted")


func test_blocked_tasks_come_first_with_their_reason_in_words() -> void:
	"""A bridge whose builder could not reach it is BLOCKED, with the crew's own words; it is listed before the rest."""
	var rig: RefCounted = _suite._rig()
	var row: int = _suite._harvest_to(rig, 3)
	var farm: RefCounted = rig.get(&"farm")
	var cutting := func() -> bool: return (farm.get(&"jobs") as FarmJobs).current_step(row) == FarmJobs.STEP_WORK \
		+ FarmJobs.WORK_HARVEST and (farm.get(&"jobs") as FarmJobs).elapsed_usec[row] > 0
	assert_true(_suite._run(rig, 90.0, cutting), "the harvest being cut")
	_suite._plank_bridge(rig)
	var crew: BridgeCrewScript = (rig.get(&"play") as Node).get(&"crew")
	crew.unreached_usec[0] = 9000000
	var screen := _screen(rig)
	assert_true(screen.task_rows_shown()[1].detail().begins_with("Working"), "a task at work, second")
	var first: TaskRowScript = screen.task_rows_shown()[0]
	assert_true(first.title().begins_with("Build — the"), "the bridge first: %s" % first.title())
	assert_true(first.detail().begins_with("Blocked: waiting — can't reach it"), first.detail())


func test_pause_and_resume_from_the_row() -> void:
	"""Pause on a queued felling: paused (the row says so, its button now Resume); Resume lets it be claimed again."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var screen := _screen(rig)
	var row := _row_titled(screen, "Fell")
	_press(row.button_of(&"pause"))
	assert_true(crew.call(&"is_paused", 0), "paused")
	row = _row_titled(screen, "Fell")
	assert_true(row.detail().begins_with("Paused: paused by you"), row.detail())
	assert_equal(row.button_of(&"pause").text, "Resume", "its button resumes")
	assert_true(screen.answer().begins_with("Paused: Fell"), screen.answer())
	_press(row.button_of(&"pause"))
	assert_false(crew.call(&"is_paused", 0), "resumed")


func test_a_carried_load_disables_pause_and_reassign_with_the_reason() -> void:
	"""With the harvest in hand the row's Pause and Reassign… are disabled, each saying why (its tooltip)."""
	var rig: RefCounted = _suite._rig()
	var row_index: int = _suite._harvest_to(rig, 3)
	var farm: RefCounted = rig.get(&"farm")
	assert_true(_suite._run(rig, 120.0, func() -> bool: return farm.call(&"holds_load", row_index)), "carrying")
	var screen := _screen(rig)
	var row := _row_titled(screen, "Harvest")
	assert_true(row.button_of(&"pause").disabled and row.button_of(&"pick").disabled, "disabled")
	assert_equal(row.button_of(&"pause").tooltip_text, WorkIds.CARRYING % "Placeholder 3", "saying why")
	assert_false(row.button_of(&"cancel").disabled, "Cancel this task stays: it becomes the delivery")


func test_reassign_through_the_picker_shows_each_residents_eligibility() -> void:
	"""Reassign… opens a picker of every resident: one the rescue holds is disabled with the reason; a press on an
	eligible one gives it the task and says so."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([1]), ForestJobs.ORIGIN_PLAYER)
	var board: BoardScript = rig.get(&"board")
	board.brain_of(2).water_hold = true
	var screen := _screen(rig, false, PackedInt32Array([0, 2]))
	var row := _row_titled(screen, "Fell")
	_press(row.button_of(&"pick"))
	assert_true(row.picker_open(), "the picker")
	var note: String = (row.get(&"_picker_note") as Label).text
	assert_true(note.ends_with("Of 2 selected: Placeholder 0 can; Placeholder 2 can't (%s)" % BoardScript.HELD),
		"the selection previewed member by member: %s" % note)
	assert_true(row.resident_button(2).disabled, "held by the rescue: disabled")
	assert_equal(row.resident_button(2).tooltip_text, BoardScript.HELD, "with why")
	_press(row.resident_button(4))
	assert_equal((crew.get(&"jobs") as ForestJobs).worker[0], 4, "given to resident 4")
	assert_true(screen.answer().begins_with("Given to Placeholder 4"), screen.answer())
	assert_false(row.picker_open(), "the picker closes")
	board.brain_of(2).water_hold = false


func test_an_open_picker_stays_with_its_task_when_the_list_re_sorts() -> void:
	"""Reassign… opened on the queued felling, second under a queued harvest; the harvest is then paused (paused tasks
	list last) so the felling moves up: the row with the open picker still shows the felling, and a pick there gives
	the felling -- not whatever took its old place. A row given a new task never keeps an open picker."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	var board: BoardScript = rig.get(&"board")
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var screen := _screen(rig)
	var fell := _row_titled(screen, "Fell")
	assert_equal(screen.task_rows_shown().find(fell), 1, "the felling second, under the harvest")
	_press(fell.button_of(&"pick"))
	board.pause(WorkIds.SOURCE_FARM, 0, true)
	screen.refresh()
	assert_equal(screen.task_rows_shown().find(fell), 0, "the felling now first")
	assert_true(fell.title().begins_with("Fell"), "the same row still shows the felling: %s" % fell.title())
	assert_true(fell.picker_open(), "its picker still open")
	_press(fell.resident_button(4))
	assert_equal((crew.get(&"jobs") as ForestJobs).worker[0], 4, "the felling given to resident 4")
	assert_equal(((rig.get(&"farm") as RefCounted).get(&"jobs") as FarmJobs).worker[0], FarmJobs.NOBODY, "the harvest untouched")
	_press(_row_titled(screen, "Fell").button_of(&"pick"))
	crew.call(&"cancel_row", 0)
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	screen.refresh()
	for row: TaskRowScript in screen.task_rows_shown():
		assert_false(row.picker_open(), "no open picker on %s" % row.title())


func test_priority_and_urgent_from_the_row() -> void:
	"""▲ raises the task's priority (the title says so), ▼ lowers it, Urgent marks it (and again unmarks it)."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var board: BoardScript = rig.get(&"board")
	var screen := _screen(rig)
	var row := _row_titled(screen, "Fell")
	_press(row.button_of(&"up"))
	assert_equal(board.task_priority(WorkIds.SOURCE_WOODS, 0), WorkIds.PRIORITY_HIGH, "raised")
	row = _row_titled(screen, "Fell")
	assert_true(row.title().ends_with("priority high"), row.title())
	_press(row.button_of(&"down"))
	_press(row.button_of(&"down"))
	assert_equal(board.task_priority(WorkIds.SOURCE_WOODS, 0), WorkIds.PRIORITY_LOW, "lowered twice")
	assert_true(_row_titled(screen, "Fell").button_of(&"down").disabled, "lowest: ▼ disabled")
	_press(_row_titled(screen, "Fell").button_of(&"urgent"))
	assert_true(board.is_urgent(WorkIds.SOURCE_WOODS, 0), "urgent")
	assert_true(_row_titled(screen, "Fell").title().ends_with("URGENT"), "said")
	_press(_row_titled(screen, "Fell").button_of(&"urgent"))
	assert_false(board.is_urgent(WorkIds.SOURCE_WOODS, 0), "not urgent again")


func test_go_to_jumps_to_the_target_and_closes() -> void:
	"""Go to: the village's jump to the task's target -- a bed, a tree -- and the screen asks to close."""
	var rig: RefCounted = _suite._rig()
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var screen := _screen(rig)
	var closed := [false]
	screen.close_requested.connect(func() -> void: closed[0] = true)
	_press(_row_titled(screen, "Harvest").button_of(&"go"))
	assert_equal(_jumps, [[NoticesScript.TARGET_BED, BED_CARROTS]], "to the bed")
	assert_true(closed[0], "and out of the way")
	(rig.get(&"forestry") as Node).get(&"crew").call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(),
		ForestJobs.ORIGIN_PLAYER)
	screen.refresh()
	_press(_row_titled(screen, "Fell").button_of(&"go"))
	assert_equal(_jumps[1], [NoticesScript.TARGET_TREE, NORTH_OAK], "a felling: to its tree")


func test_a_row_whose_task_changed_under_it_does_nothing() -> void:
	"""A command on a row whose task has gone (or been replaced in its row) is refused: "look again"."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var screen := _screen(rig)
	var row := _row_titled(screen, "Fell")
	crew.call(&"cancel_row", 0)
	crew.call(&"order", ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	_press(row.button_of(&"pause"))
	assert_equal(screen.answer(), ScreenScript.CHANGED, "look again")
	assert_false(crew.call(&"is_paused", 0), "the new job untouched")


func test_cancel_all_shows_its_scope_then_cancels_what_it_said() -> void:
	"""Cancel all work…: first only its scope, counted per source, with what goes on; Keep working cancels nothing;
	Cancel them cancels what was counted -- a load in hand still delivered."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	_suite._plank_bridge(rig)
	var screen := _screen(rig)
	_press(screen.cancel_all_button())
	assert_equal(screen.confirm_text(), ScreenScript.CANCEL_SCOPE % [2, "Farm 1, Woods 1"], "the scope, the bridge going on")
	_press(screen.confirm_buttons()[1])
	assert_equal(screen.confirm_text(), "", "Keep working")
	assert_equal(screen.task_rows_shown().size(), 3, "nothing cancelled")
	_press(screen.cancel_all_button())
	_press(screen.confirm_buttons()[0])
	assert_equal(screen.answer(), "Cancelled 2 tasks", "said")
	assert_equal(screen.task_rows_shown().size(), 1, "the bridge left")


func test_the_projects_view_groups_tasks_by_source() -> void:
	"""Projects: each source's name and count over its tasks."""
	var rig: RefCounted = _suite._rig()
	var crew: RefCounted = (rig.get(&"forestry") as Node).get(&"crew")
	crew.call(&"order", ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	rig.get(&"farm").call(&"order", FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var screen := _screen(rig)
	_press(screen.tab_button(ScreenScript.VIEW_PROJECTS))
	var headers := PackedStringArray()
	for child: Node in (screen.get(&"_list") as Control).get_children():
		if child is Label and (child as Label).visible:
			headers.append((child as Label).text)
	assert_equal(headers, PackedStringArray(["Farm — 1", "Woods — 1"]), "grouped")


# --- the Residents view: crews, statuses, order lists, presets ----------------------------------------

func _resident_row(screen: ScreenScript, who: int) -> ResidentRowScript:
	"""The Residents view's row for `who`."""
	for row: ResidentRowScript in screen.resident_rows_shown():
		if row.who == who:
			return row
	return null


func test_the_residents_view_lists_each_crew_and_moves_a_member() -> void:
	"""Each crew's header (its activities, its members), each member's crew and status; Crew ▶ and ◀ move one."""
	var rig: RefCounted = _suite._rig()
	var board: BoardScript = rig.get(&"board")
	_suite._crews(rig, PackedInt32Array([0, 0, 1, 2, 3, 4]))
	board.brain_of(5).resting = true
	var screen := _screen(rig)
	_press(screen.tab_button(ScreenScript.VIEW_RESIDENTS))
	assert_equal(screen.resident_rows_shown().size(), 6, "everybody")
	assert_equal(_resident_row(screen, 0).title(), "Placeholder 0 — Field crew · available", "crew and status")
	assert_equal(_resident_row(screen, 5).title(), "Placeholder 5 — Builders crew · resting", "in bed")
	_press(_resident_row(screen, 0).button_of(&"crew_on"))
	assert_equal(board.crews.crew_of[0], CrewsScript.CREW_WOODS, "moved on")
	assert_equal(_resident_row(screen, 0).title(), "Placeholder 0 — Woods crew · available", "said")
	_press(_resident_row(screen, 0).button_of(&"crew_back"))
	_press(_resident_row(screen, 0).button_of(&"crew_back"))
	assert_equal(board.crews.crew_of[0], CrewsScript.CREW_BUILDERS, "back round")
	board.brain_of(5).resting = false


func test_an_order_list_is_shown_and_edited_from_the_residents_view() -> void:
	"""A resident's list: Now and Next -> ... -> then its routine; Sooner, Later and Remove edit it."""
	var rig: RefCounted = _suite._rig()
	var board: BoardScript = rig.get(&"board")
	var brain := board.brain_of(1)
	brain.order_move(brain.position + Vector2(1.0, 0.0))
	assert_equal(board.queue_walk(1, Vector2(1.0, 1.0)), "", "a walk")
	assert_equal(board.queue_walk(1, Vector2(2.0, 2.0)), "", "another")
	var screen := _screen(rig)
	_press(screen.tab_button(ScreenScript.VIEW_RESIDENTS))
	var row := _resident_row(screen, 1)
	assert_equal(row.list_text(), "Next: Walk to 1.0, 1.0 → Walk to 2.0, 2.0 → then its routine", "the list")
	_press(row.entry_button(1, &"sooner"))
	assert_equal(_resident_row(screen, 1).list_text(), "Next: Walk to 2.0, 2.0 → Walk to 1.0, 1.0 → then its routine", "moved")
	assert_true(_resident_row(screen, 1).entry_button(0, &"sooner").disabled, "the first cannot go sooner")
	_press(_resident_row(screen, 1).entry_button(0, &"remove"))
	assert_equal(_resident_row(screen, 1).list_text(), "Next: Walk to 1.0, 1.0 → then its routine", "removed")
	_press(_resident_row(screen, 1).entry_button(0, &"later"))
	assert_equal(brain.queue_size(), 1, "the last cannot go later")


func test_presets_preview_then_apply_from_the_residents_view() -> void:
	"""Focusing a preset says what it would change, before anything changes; pressing it applies it and says so."""
	var rig: RefCounted = _suite._rig()
	var board: BoardScript = rig.get(&"board")
	var screen := _screen(rig)
	_press(screen.tab_button(ScreenScript.VIEW_RESIDENTS))
	screen.preview_preset(CrewsScript.PRESET_WINTER)
	var note: String = (screen.get(&"_preset_note") as Label).text
	assert_true(note.begins_with("Winter stores — every crew lends a hand in the woods"), note)
	assert_equal(board.crews.preset, CrewsScript.PRESET_NORMAL, "nothing applied yet")
	assert_equal(screen.preset_button(CrewsScript.PRESET_WINTER).tooltip_text, note, "its tooltip says the same")
	_press(screen.preset_button(CrewsScript.PRESET_WINTER))
	assert_equal(board.crews.preset, CrewsScript.PRESET_WINTER, "applied")
	assert_true(screen.answer().begins_with("Work preset: Winter stores"), screen.answer())
	screen.end_preview()
	assert_true((screen.get(&"_preset_note") as Label).text.begins_with("In force: Winter stores"), "the preset in force")


# --- the other adapters ------------------------------------------------------------------------------

func _tunnel_site() -> Array:
	"""A 12 m tunnel dug open in a cast space with three brains (a mouse, a mole, a badger that fits no bore), its jobs
	and stores, and a brace job on its bore with nobody on it. [space, brains, jobs, work, bore]."""
	var handoffs := HandoffsTest.new()
	handoffs.before_each()
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var brains: Array[BrainScript] = []
	for k: int in 3:
		brains.append(handoffs._brain(space, Vector2(-2.0, float(k)), ["Mouse", "Mole", "Badger"][k]))
	var network: GraphScript = space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(DIG_ROUTE, 2, 0, ref), "a tunnel")
	handoffs._dig_all(network, ref[2])
	var bore: int = ref[0]
	var stores := StoresScript.new()
	var jobs := TunnelJobs.new(network, stores)
	jobs.post(bore, TunnelJobs.JOB_BRACE, -1, 0, 4096)
	var work := TunnelWork.new(jobs, network, stores, brains, func(who: int) -> bool: return who == 1)
	return [space, brains, jobs, work, bore]


func test_a_paused_tunnel_job_is_claimed_by_one_who_fits_its_bore() -> void:
	"""The tunnels' adapter: a brace with nobody on it waits; the badger, who fits no bore, is not eligible, the mouse
	is; claimed, the mouse is sent with the job's own task. Its record: action, target, BUILDING, percent."""
	var site := _tunnel_site()
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	assert_true(work.live(bore) and work.waiting(bore), "waiting")
	assert_equal(work.activity(bore), WorkIds.ACT_BUILD, "bracing is building")
	assert_equal(work.eligibility(bore, 2), TunnelWork.NOT_FITTING, "the badger does not fit")
	assert_equal(work.eligibility(bore, 0), "", "the mouse does")
	assert_true(work.claim(bore, 0), "claimed")
	var jobs: TunnelJobs = site[2]
	assert_equal(jobs.worker[bore], 0, "posted for the mouse")
	assert_true((site[1][0] as BrainScript).task is JobTaskScript, "sent with the job's task")
	var task := TaskScript.new()
	work.fill(task, bore)
	assert_equal([task.action, task.target, task.worker, task.activity], ["Brace", "tunnel %d" % (bore + 1), 0,
		WorkIds.ACT_BUILD], "its record")
	assert_true(task.remaining_usec > 0, "work left")


func test_a_tunnel_job_paused_reassigned_and_cancelled() -> void:
	"""Pause lets its worker go (the task ends at its next step) and keeps it from being claimed; Resume lets it wait
	again; Reassign moves it (progress kept); Cancel only before its materials are paid."""
	var site := _tunnel_site()
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	var jobs: TunnelJobs = site[2]
	var mouse: BrainScript = site[1][0]
	work.claim(bore, 0)
	assert_equal(work.pause(bore, true), "", "paused")
	assert_equal(jobs.worker[bore], -1, "its worker let go")
	assert_false(work.waiting(bore), "not claimable while paused")
	assert_equal(work.pause(bore, true), WorkIds.PAUSED_ALREADY, "paused already")
	mouse.step(DT)
	assert_false(mouse.task is JobTaskScript and (mouse.task as JobTaskScript).is_valid() and jobs.worker[bore] == 0, "stopped")
	assert_equal(work.pause(bore, false), "", "resumed")
	assert_true(work.waiting(bore), "waiting again")
	assert_equal(work.reassign(bore, 2), TunnelWork.NOT_FITTING, "not to the badger")
	assert_equal(work.reassign(bore, 0), "", "to the mouse")
	jobs.paid[bore] = 1
	assert_equal(work.cancel(bore), TunnelWork.PAID_CANCEL, "paid: not cancelled")
	jobs.paid[bore] = 0
	assert_equal(work.cancel(bore), "", "unpaid: cancelled")
	assert_false(work.live(bore), "gone")


func test_a_paused_tunnel_job_is_not_taken_back_by_its_old_worker() -> void:
	"""The worker called away keeps the job on its list; the player pauses it; when the worker's order is done it does
	not take the job back (tunnel_jobs.gd THE PLAYER'S HOLD) -- and once released anyone eligible may."""
	var site := _tunnel_site()
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	var jobs: TunnelJobs = site[2]
	var mouse: BrainScript = site[1][0]
	assert_true(work.claim(bore, 0), "the mouse on it")
	mouse.order_move(mouse.position + Vector2(-1.0, 0.0))
	assert_true(mouse.promises(WorkIds.SOURCE_TUNNELS, work.key(bore)), "kept to come back to")
	assert_equal(work.pause(bore, true), "", "paused by the player")
	mouse.work_done()
	assert_equal(jobs.worker[bore], -1, "not taken back while paused")
	assert_equal(work.pause(bore, false), "", "released")
	assert_true(work.waiting(bore), "waiting for anyone")


func test_a_tunnel_job_posted_again_is_a_new_job() -> void:
	"""Paused, cancelled and posted again (the same kind): a new posting, with its own key, not paused."""
	var site := _tunnel_site()
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	var jobs: TunnelJobs = site[2]
	var first: int = work.key(bore)
	work.pause(bore, true)
	assert_equal(work.cancel(bore), "", "cancelled")
	jobs.post(bore, TunnelJobs.JOB_BRACE, -1, 0, 4096)
	assert_true(work.key(bore) != first, "a new key")
	assert_false(work.is_paused(bore), "not paused")
	assert_true(work.waiting(bore), "waiting")
	work.pause(bore, true)
	assert_equal(work.reassign(bore, 0), "", "reassigned")
	assert_false(work.is_paused(bore), "a reassign releases the hold")
	var old_task: JobTaskScript = (site[1][0] as BrainScript).task
	assert_true(old_task.is_valid(), "the mouse's task works this posting")
	jobs.hold(bore, true)
	jobs.clear(bore)
	assert_equal(jobs.held[bore], 0, "a clear lets the hold go")
	jobs.post(bore, TunnelJobs.JOB_BRACE, 1, 0, 4096)
	assert_false(old_task.is_valid(), "the old task does not work the new posting")
	jobs.hold(bore, true)
	jobs.post(bore, TunnelJobs.JOB_LANTERNS, -1, 0, 4096)
	assert_false(jobs.is_held(bore), "another kind posted: a new job, not held")


func test_a_widening_needs_one_who_can_dig() -> void:
	"""Widening is DIGGING: only one who can dig is eligible (the mole here)."""
	var site := _tunnel_site()
	var jobs: TunnelJobs = site[2]
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	jobs.clear(bore)
	jobs.post(bore, TunnelJobs.JOB_WIDEN, -1, 0, 4096)
	assert_equal(work.activity(bore), WorkIds.ACT_DIG, "digging")
	assert_equal(work.eligibility(bore, 0), TunnelWork.NOT_A_DIGGER, "the mouse can't dig here")
	assert_equal(work.eligibility(bore, 1), "", "the mole can")


func test_a_tunnel_job_that_cannot_be_worked_says_why_and_waits() -> void:
	"""A brace with nobody on it on a closed tunnel waits BLOCKED ("closed"); with the stores short of its materials it
	waits BLOCKED ("short"); a resident digging a tunnel is not eligible."""
	var site := _tunnel_site()
	var work: TunnelWork = site[3]
	var bore: int = site[4]
	var network: GraphScript = (site[0] as CastSpaceScript).tunnels
	var stores: StoresScript = work.get(&"_stores")
	var task := TaskScript.new()
	network.close(bore, GraphScript.CLOSED_FLOODED, 0, 4096)
	assert_false(work.waiting(bore), "closed: not claimable")
	work.fill(task, bore)
	assert_equal([task.state, task.reason], [WorkIds.STATE_BLOCKED, TunnelWork.CLOSED], "closed, in words")
	network.reopen(bore)
	stores.wood_milli_u = 0
	work.fill(task, bore)
	assert_equal([task.state, task.reason], [WorkIds.STATE_BLOCKED, TunnelWork.SHORT], "short, in words")
	stores.wood_milli_u = 40000
	assert_true(work.waiting(bore), "paid for: waiting")
	(site[1][0] as BrainScript).order = BrainScript.ORDER_DIG
	assert_equal(work.eligibility(bore, 0), TunnelWork.DIGGING, "digging: not eligible")
	(site[1][0] as BrainScript).order = BrainScript.ORDER_NONE


func test_a_mixed_group_on_a_tunnel_job_previews_each_member() -> void:
	"""UX-001 on the tunnels' cards: a brace with a mouse and a badger selected says who of them can work it -- the
	mouse; the badger, who fits no bore, can't, and why."""
	var handoffs := HandoffsTest.new()
	handoffs.before_each()
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var brains: Array[BrainScript] = [handoffs._brain(space, Vector2(-2.0, 0.0), "Mouse"),
		handoffs._brain(space, Vector2(-2.0, 1.0), "Badger")]
	var network: GraphScript = space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(DIG_ROUTE, 2, 0, ref), "a tunnel")
	handoffs._dig_all(network, ref[2])
	var works: Node = handoffs._works(space, brains, PackedStringArray(["Mouse", "Badger"]))
	var actions: ActionsScript = handoffs._actions(works, space, 2)
	actions.select(ref[0])
	var card := CardScript.new()
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([0, 1]))
	assert_equal(card.members, "Of 2 selected: Resident 0 can; Resident 1 can't (%s)" % WorkIds.NOT_FITTING, card.members)
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([0]))
	assert_equal(card.members, "", "one selected: no preview")
	brains[0].underground = true
	assert_equal(actions.member_refusal(TunnelJobs.JOB_BRACE, 0), WorkIds.BELOW, "one below ground can't take it")
	brains[0].underground = false
	handoffs.after_each()


func test_spoil_rows_are_listed_with_their_phase_and_say_how_to_stop_them() -> void:
	"""The spoil heaps' adapter: a worker clearing a heap is a row (Clear, the heap, HAULING its basket); its commands
	say a heap is cleared by order."""
	var handoffs := HandoffsTest.new()
	handoffs.before_each()
	var cast: DemoCastScript = handoffs._spoil_cast()
	var crew := SpoilCrewScript.new()
	crew.configure(cast, cast.space().tunnels, FarmTunnels.new(), null, func(_m: int) -> void: pass, Vector2.ZERO)
	var heap: int = handoffs._spoil_site(cast)
	crew.order(heap, PackedInt32Array([1]))
	var brains: Array[BrainScript] = []
	for i: int in cast.actor_count():
		brains.append((cast.actor(i) as DemoActorScript).brain)
	var work := SpoilWork.new(crew, cast.space().tunnels, brains)
	var row: int = crew.row_of(1)
	assert_true(work.live(row) and not work.waiting(row), "a row, never waiting to be claimed")
	var task := TaskScript.new()
	work.fill(task, row)
	assert_equal([task.action, task.worker, task.cancel_refusal], ["Clear", 1, SpoilWork.BY_ORDER], "its record")
	assert_true(task.target.begins_with("spoil heap %d" % (heap + 1)), task.target)
	assert_equal(work.cancel(row), SourceScript.UNSUPPORTED, "not cancelled from the board")
	handoffs.after_each()


func test_a_waiting_fixture_is_listed_and_handed_to_a_resident() -> void:
	"""The fit-out's adapter: a planned bed in a dug home is a task (Put in a bed, the home, BUILDING, its work left);
	its Pause and Cancel say they are the room's own; Reassign hands the waiting bed to a resident who can reach the
	room (its install task), and once someone is on it, says so."""
	var cards := ActionCardsTest.new()
	cards.before_each()
	var parts: Array = cards._tool_with_tunnel()
	var ext: Node = (parts[0] as Node).get(&"ext")
	var graph: GraphScript = (parts[0] as Node).get(&"network")
	var r: int = parts[2]
	var stores: StoresScript = (ext.get(&"works") as Node).get(&"stores")
	stores.add_planks(100000)
	assert_true(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores) >= 0, "a bed planned")
	var brains: Array[BrainScript] = []
	var cast: Node = parts[1]
	for i: int in cast.call(&"actor_count"):
		brains.append((cast.call(&"actor", i) as DemoActorScript).brain)
	var work := FitOutWork.new(graph, ext.get(&"fixture_crew"), brains, func(who: int) -> String: return "R%d" % who)
	var row: int = -1
	for k: int in work.capacity():
		if work.live(k):
			row = k
	assert_true(row >= 0, "a planned place")
	var task := TaskScript.new()
	work.fill(task, row)
	assert_equal([task.action, task.target, task.state, task.activity], ["Put in a bed", "%s %d" % [RoomsScript.NAMES[
		RoomsScript.TEMPLATE_HOME], r + 1], WorkIds.STATE_QUEUED, WorkIds.ACT_BUILD], "its record")
	assert_equal([task.pause_refusal, task.cancel_refusal], [FitOutWork.ROOM_PANEL, FitOutWork.ROOM_PANEL], "the room's own")
	assert_true(task.remaining_usec > 0, "work left")
	assert_equal(work.eligibility(row, 0), "", "resident 0 can reach the room")
	assert_equal(work.reassign(row, 0), "", "handed to resident 0")
	assert_equal(work.worker(row), 0, "on it")
	assert_true((brains[0] as BrainScript).task is InstallTaskScript, "with its install task")
	assert_equal(work.reassign(row, 1), FitOutWork.UNDER_WAY, "not while someone is on it")
	cards.after_each()


# --- Shift+right-click's queue -----------------------------------------------------------------------

func test_a_queued_woods_order_goes_to_the_nearest_selected_resident() -> void:
	"""Shift on a mature tree: the felling is put on the board and queued for the nearest of the selection, whose list
	then names it; Shift on a felled trunk queues its haul; a young tree is refused."""
	var rig: RefCounted = _suite._rig()
	var board: BoardScript = rig.get(&"board")
	var forestry: Node = rig.get(&"forestry")
	var orders := OrdersScript.new()
	orders.configure(board, null, forestry, null)
	for who: int in 6:
		board.brain_of(who).order_move(board.brain_of(who).position + Vector2(0.5, 0.0))
	var said: String = orders._queue_woods(PickScript.KIND_TREE, NORTH_OAK, PackedInt32Array([1, 4]))
	var crew: RefCounted = forestry.get(&"crew")
	var row: int = orders.waiting_row(ForestJobs.KIND_FELL, NORTH_OAK)
	assert_true(row >= 0, "on the board")
	var to: Vector2 = crew.call(&"target_point", row)
	var nearest: int = 1 if board.brain_of(1).surface_point().distance_to(to) < board.brain_of(4).surface_point().distance_to(to) \
		else 4
	assert_true(board.brain_of(nearest).promises(WorkIds.SOURCE_WOODS, (crew.get(&"jobs") as ForestJobs).serial[row]),
		"queued for the nearer of the two")
	assert_false(board.brain_of(5 - nearest).promises(WorkIds.SOURCE_WOODS, (crew.get(&"jobs") as ForestJobs).serial[row]),
		"not for the farther")
	assert_true(said.contains("queued for %s" % board.name_of(nearest)), said)
	(forestry.get(&"stand") as RefCounted).call(&"blow_down_into", WEST_OAK, 1, Vector2.UP, IntMath.IntResult.new())
	assert_equal(orders.woods_kind(PickScript.KIND_TRUNK, WEST_OAK), ForestJobs.KIND_HAUL, "a trunk: its haul")
	assert_equal(orders.woods_kind(PickScript.KIND_SAW, 0), ForestJobs.KIND_SAW, "the sawhorse: sawing")
	assert_equal(orders.woods_kind(PickScript.KIND_PILE, 0), ForestJobs.KIND_GATHER, "deadfall: gathering")
	assert_equal(orders.queue_walks(Vector2(1.0, 1.0), PackedInt32Array([2, 3])), OrdersScript.WALK_QUEUED % 2, "walks")

