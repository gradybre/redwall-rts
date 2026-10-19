extends "res://test/framework/test_case.gd"
## Decision 1991 (slice C3) in the demo's proof of concept (Brendan, P-1990-1 (b) "Keep the mole, build real"): the
## crew the player selects digs the batch (P-1990-4 (a)), named on the footer's ledger; each cell is claimed by one
## mole; the room card (UI-BUILD-015) says how far a room is dug and who digs it; "Stop digging" (UI-BUILD-016,
## P-1990-5 (a)) puts the room's waiting cells back in the plan and keeps what is dug. Off-tree, over a placeholder
## cast, as test_demo_build_panel.gd.

const BuildScript := preload("res://demo/build_panel/demo_build.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Crews := preload("res://demo/build_panel/demo_build_crews.gd")
const BelowTask := preload("res://demo/build_panel/demo_build_below_task.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const RoomCard := preload("res://scripts/ui/build_room_card.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

const KITCHEN: int = 2
## A 6 × 4 Kitchen on level 1 beside an entrance's landing at (4, 4).
const KITCHEN_FROM: Vector2i = Vector2i(6, 4)
const KITCHEN_TO: Vector2i = Vector2i(11, 7)

var _nodes: Array[Node] = []
var _build: BuildScript = null
var _cast: Node = null
var _said: PackedStringArray = PackedStringArray()
var _selected: PackedInt32Array = PackedInt32Array()


func tolerates_outside_tree() -> bool:
	"""The command layer's marks read their transforms off-tree here."""
	return true


func before_each() -> void:
	"""A placeholder cast of four (moles 0, 1 and 2, an otter 3), its command layer, and the build panel over them."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0),
		Vector3(3.0, 1.0, 0.0)] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	for i: int in 3:
		(cast.actor(i) as DemoActorScript).species = "Mole"
	(cast.actor(3) as DemoActorScript).species = "Otter"
	_cast = cast
	var command: CommandScript = CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null)
	var hidden: CanvasLayer = CanvasLayer.new()
	_nodes.append(hidden)
	_said.clear()
	_selected = PackedInt32Array()
	_build = BuildScript.new()
	_nodes.append(_build)
	_build.configure(command.tunnels(), null, camera, func() -> bool: return false,
		func(text: String) -> void: _said.append(text), [hidden] as Array[Node], null)
	_build.bind_cast(cast, func() -> PackedInt32Array: return _selected)


func after_each() -> void:
	"""Free every node (the lambdas hold this suite)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_build = null
	_cast = null


func _confirm_kitchen_with(selected: PackedInt32Array) -> void:
	"""An Entrance on the surface and the Kitchen beside its landing on level 1, Confirm all with `selected`."""
	_build.open_panel()
	assert_equal(_build.batch.place_item(0, Vector2i(4, 4)), Validity.KIND_CAN_BUILD, "the hatch")
	_build.bar.choose(1)
	_build.batch.begin_stroke(KITCHEN, 1, KITCHEN_FROM)
	_build.batch.extend_stroke(KITCHEN_TO)
	_build.batch.finish_stroke()
	_selected = selected
	_build.confirm_all()


func _step_all(frames: int) -> void:
	"""Every dig trip below stepped `frames` frames of 0.1 s (arrived at the Entrance first)."""
	for trip: BelowTask in _build.diggers:
		var row: int = _build._trips.find(trip)
		var brain: Object = (_cast.call(&"actor", _build._trip_actors[row]) as Node).get(&"brain")
		if trip.stage == BelowTask.STAGE_GOING: trip.arrived(brain)
	for frame: int in frames:
		var going: bool = false
		for trip: BelowTask in _build.diggers:
			var row: int = _build._trips.find(trip)
			var brain: Object = (_cast.call(&"actor", _build._trip_actors[row]) as Node).get(&"brain")
			if trip.stage != BelowTask.STAGE_OUT and trip.stage != BelowTask.STAGE_GOING:
				going = trip.step(brain, 0.1) or going
		if not going: return


func test_cells_carry_their_batchs_crew_and_a_crew_digs_only_its_own() -> void:
	"""The works stamp each ordered cell with its Confirm all's crew; a crew's search finds only its cells (any, with
	none given), and a cell another mole holds is passed over."""
	var works: Works = _build.works
	assert_true(works.order_way_down(0, Vector2i(4, 4), 4, 0, 7), "a hatch for crew 7")
	assert_true(works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5]), KITCHEN, 9), "a room for crew 9")
	assert_equal(works.crew_of(1, Vector2i(6, 4)), 9, "stamped")
	assert_equal(works.waiting_for(9), 4, "four cells wait for crew 9")
	assert_equal(works.waiting_for(7), 4, "the landing's four for crew 7")
	var landing: Vector3i = works.landing_of(0)
	assert_false(works.next_dig(landing, PackedByteArray([7])).is_empty(), "crew 7 finds its landing")
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		assert_true(works.open_cell(1, cell), "the landing dug")
	assert_true(works.next_dig(landing, PackedByteArray([7])).is_empty(), "crew 7 has nothing left")
	var found: Dictionary = works.next_dig(landing, PackedByteArray([9]), 101)
	assert_false(found.is_empty(), "crew 9 finds its room")
	assert_true(works.claim(found["target"], 101), "claimed")
	assert_false(works.claim(found["target"], 102), "not twice")
	var second: Dictionary = works.next_dig(landing, PackedByteArray([9]), 102)
	assert_false(second.is_empty() or second["target"] == found["target"], "the second mole takes another cell")
	assert_equal(works.claimed_by(found["target"]), 101, "held")
	works.unclaim(found["target"], 102)
	assert_equal(works.claimed_by(found["target"]), 101, "only its holder lets it go")
	assert_true(works.open_cell(found["target"].x, Vector2i(found["target"].y, found["target"].z)), "dug")
	assert_equal(works.claimed_by(found["target"]), -1, "and let go")
	assert_equal(works.waiting_for(9), 3, "three left")


func test_stop_puts_a_rooms_waiting_cells_back_to_earth_and_keeps_what_is_dug() -> void:
	"""`stop_room`: the room's ordered cells go back to earth (unclaimed, uncounted) and are returned; dug ones stay."""
	var works: Works = _build.works
	var cells: PackedInt32Array = PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5])
	assert_true(works.order_room(1, cells, KITCHEN, 3), "ordered")
	assert_true(works.open_cell(1, Vector2i(6, 4)), "one dug")
	assert_true(works.claim(Vector3i(1, 7, 4), 55), "one being dug")
	assert_equal(works.room_cells(1, Vector2i(7, 5)).size(), 8, "the room is its four cells")
	var back: PackedInt32Array = works.stop_room(1, Vector2i(7, 5))
	assert_equal(back.size(), 6, "three cells back")
	assert_equal(works.state(1, Vector2i(6, 4)), Works.OPEN, "the dug one stays")
	assert_equal(works.state(1, Vector2i(7, 4)), Works.EARTH, "the one being dug is earth again")
	assert_equal(works.claimed_by(Vector3i(1, 7, 4)), -1, "and let go")
	assert_equal(works.waiting_for(3), 0, "nothing waits for the crew")
	assert_equal(works.waiting(), 0, "nothing waits at all")
	assert_equal(works.stop_room(1, Vector2i(6, 4)).size(), 0, "a second Stop returns nothing")
	assert_equal(works.room_cells(1, Vector2i(30, 30)).size(), 0, "no room there")


func test_crew_numbers_are_reused_only_when_nothing_waits_and_four_at_most_are_kept() -> void:
	"""demo_build_crews.gd: a number per Confirm all; four members kept; the footer's words."""
	var waiting: Dictionary = {}
	var count: Callable = func(crew: int) -> int: return int(waiting.get(crew, 0))
	var crews: Crews = Crews.new()
	var first: int = crews.begin(PackedInt32Array([4, 5, 6, 7, 8]), count)
	assert_equal(crews.members_of(first), PackedInt32Array([4, 5, 6, 7]), "four kept")
	assert_true(crews.named(first), "named")
	waiting[first] = 3
	var second: int = crews.begin(PackedInt32Array(), count)
	assert_false(second == first, "a number in use is not reused")
	assert_false(crews.named(second), "the first free mole")
	crews.set_sent(second, 9)
	assert_equal(crews.members_of(second), PackedInt32Array([9]), "the mole sent becomes the crew")
	crews.set_sent(first, 9)
	assert_equal(crews.members_of(first), PackedInt32Array([4, 5, 6, 7]), "a named crew is not replaced")
	waiting[first] = 0
	crews.forget_finished(count)
	assert_equal(crews.ids(), PackedInt32Array(), "both forgotten once nothing waits")
	assert_equal(Crews.words(PackedStringArray(["Bramble", "Teasel"]), 2, true), "Crew: Bramble, Teasel", "named")
	assert_equal(Crews.words(PackedStringArray(["A", "B", "C", "D", "E"]), 5, true),
		"Crew: A, B, C, D (four at most dig a room)", "five selected")
	assert_equal(Crews.words(PackedStringArray(), 0, true), "Crew: the first free mole", "none")
	assert_equal(Crews.words(PackedStringArray(), 0, false), "Crew: the first free resident (no mole lives here)",
		"no mole lives here")


func test_the_selected_moles_crew_the_batch_and_dig_it_side_by_side() -> void:
	"""P-1990-4 (a): two selected moles (the selected otter is not a mole) are the batch's crew; both go down, each
	digs cells of its own claim, and together they dig the batch; the footer named them first."""
	_build.open_panel()
	_selected = PackedInt32Array([1, 3, 2])
	_build._sync_crew_line(1.0)
	var names: String = "Crew: %s, %s" % [Crews.first_name(_build._name_of(1)), Crews.first_name(_build._name_of(2))]
	assert_equal(_build.panel.crew_line(), names, "the footer names the moles selected")
	_confirm_kitchen_with(PackedInt32Array([1, 3, 2]))
	assert_equal(_build.diggers.size(), 2, "both sent")
	assert_equal(_build._trip_actors[_build._trips.find(_build.diggers[0])], 1, "the first selected")
	assert_equal(_build._trip_actors[_build._trips.find(_build.diggers[1])], 2, "the second")
	_step_all(6000)
	assert_equal(_build.works.waiting(), 0, "every cell dug")
	assert_true(_build.diggers[0].dug > 0 and _build.diggers[1].dug > 0, "by both: %d and %d" % [_build.diggers[0].dug,
		_build.diggers[1].dug])
	assert_equal(_build.diggers[0].dug + _build.diggers[1].dug, 28, "each cell once")


func test_with_none_selected_the_first_free_mole_digs() -> void:
	"""Decision 1912's rule kept: no selection, one mole, the first free."""
	_confirm_kitchen_with(PackedInt32Array())
	assert_equal(_build.diggers.size(), 1, "one mole")
	assert_true(_build._is_mole(_build._trip_actors[_build._trips.find(_build.digger)]), "a mole")
	assert_false(_build._send_crews(), "asked again while it digs: nobody more")
	assert_equal(_build.diggers.size(), 1, "still the one mole")
	_build._sync_crew_line(1.0)
	assert_equal(_build.panel.crew_line(), "Crew: the first free mole", "the footer says so")


func test_the_room_card_says_how_far_and_who_and_stop_puts_the_rest_back_in_the_plan() -> void:
	"""P-1990-5 (a): the card names the room, its progress and its crew, and the proof of concept; Stop digging puts
	the waiting cells back in the plan as one pending Kitchen (Undo takes them out); the dug cells stay; the crew,
	with nothing left, walks out."""
	_confirm_kitchen_with(PackedInt32Array([1]))
	_step_all(120)
	var dug: int = _build.diggers[0].dug
	assert_true(dug > 4 and dug < 28, "partway: %d" % dug)
	assert_true(_build.show_room_card(1, KITCHEN_TO), "the card opens on the Kitchen")
	var card: RoomCard = _build.panel.room_card()
	assert_equal(card.title(), "Kitchen, Underground level 1", "named")
	assert_true(card.words().contains("of 24 cells dug"), card.words())
	assert_true(card.words().contains("Crew: %s" % Crews.first_name(_build._name_of(1))), card.words())
	assert_true(card.words().contains("Proof of concept: free"), card.words())
	assert_false(card.stop_button().disabled, "there is something to stop")
	var pending: int = _build.batch.pending_count()
	_build.stop_shown_room()
	assert_equal(_build.works.waiting(), 0, "nothing waits")
	assert_equal(_build.batch.pending_count(), pending + 1, "one pending Kitchen")
	var k: int = _build.batch.operation_count() - 1
	var back: int = _build.batch.operation_cell_count(k)
	assert_equal(_build.batch.operation_type(k), KITCHEN, "a Kitchen")
	assert_equal(back + _kitchen_open(), 24, "its waiting cells, and the dug ones, make the Kitchen")
	assert_true(_said[-1].begins_with("Stopped digging the Kitchen: "), _said[-1])
	assert_equal(_build.batch.undo_label(), "Undo Return Kitchen", "one step")
	assert_true(card.stop_button().disabled, "nothing left to stop")
	assert_equal(card.stop_button().text, "Stopped", "says so")
	assert_true(card.words().begins_with("Stopped: %d of 24 cells dug; %d back in the plan"
		% [_kitchen_open(), back]), card.words())
	_step_all(400)
	assert_false(_build.diggers[0].below(), "the crew walked out")
	assert_true(_build.diggers[0].label().begins_with("Walking out"), _build.diggers[0].label())
	assert_true(_build.batch.undo(), "Undo")
	assert_equal(_build.batch.pending_count(), pending, "takes them out of the plan")


func test_a_mole_digging_a_stopped_cell_lets_it_go_and_plans_again() -> void:
	"""The cell the mole stands digging is stopped: it lets the cell go at once (no cell opens behind the Stop)."""
	_confirm_kitchen_with(PackedInt32Array([1]))
	var trip: BelowTask = _build.diggers[0]
	var row: int = _build._trips.find(trip)
	var brain: Object = (_cast.call(&"actor", _build._trip_actors[row]) as Node).get(&"brain")
	trip.arrived(brain)
	var frames: int = 0
	while trip.digging_cell().x < 1 or trip.digging_cell() == Vector3i(1, 4, 4) or trip.digging_cell().y < 6:
		trip.step(brain, 0.1)
		frames += 1
		if frames > 3000: break
	var cell: Vector3i = trip.digging_cell()
	assert_true(cell.x == 1 and cell.y >= 6, "digging a Kitchen cell: %s" % cell)
	assert_true(_build.show_room_card(1, Vector2i(cell.y, cell.z)), "its card")
	_build.stop_shown_room()
	trip.step(brain, 0.1)
	assert_equal(_build.works.state(1, Vector2i(cell.y, cell.z)), Works.EARTH, "not opened behind the Stop")
	assert_equal(_build.works.claimed_by(cell), -1, "let go")
	assert_false(trip.digging_cell() == cell, "it stopped digging there at once (no wait out on a stopped cell)")


func test_return_cells_is_one_step_and_refuses_nothing_to_return() -> void:
	"""build_batch.gd `return_cells`: one pending operation, one Undo step; empty input or a stroke in progress
	returns -1."""
	var batch: Batch = _build.batch
	assert_equal(batch.return_cells(KITCHEN, 1, PackedInt32Array()), -1, "nothing")
	var k: int = batch.return_cells(KITCHEN, 1, PackedInt32Array([8, 8, 9, 8, 8, 9, 9, 9]))
	assert_equal(k, batch.operation_count() - 1, "the newest operation")
	assert_equal(batch.operation_cell_count(k), 4, "its cells")
	assert_true(batch.begin_stroke(KITCHEN, 1, Vector2i(20, 20)), "a stroke")
	assert_equal(batch.return_cells(KITCHEN, 1, PackedInt32Array([30, 30])), -1, "not during a stroke")
	batch.cancel_stroke()
	assert_true(batch.undo(), "Undo")
	assert_equal(batch.pending_count(), 0, "gone")
	assert_true(batch.redo(), "Redo")
	assert_equal(batch.pending_count(), 1, "back")


func test_the_room_card_is_ui_build_015_with_its_stop_button_016() -> void:
	"""build_room_card.gd: named UI-BUILD-015 and -016; Stop disabled (with its reason) when nothing is left to dig;
	its presses are only said; laid out in the connector card's rectangle; Escape and a level change put it away."""
	var card: RoomCard = RoomCard.new()
	_nodes.append(card)
	assert_equal(String(card.name), "UI-BUILD-015", "the card")
	assert_equal(String(card.stop_button().name), "UI-BUILD-016", "its button")
	var pressed: Array[String] = []
	card.stop_pressed.connect(func() -> void: pressed.append("stop"))
	card.close_pressed.connect(func() -> void: pressed.append("close"))
	card.show_room("Kitchen, Underground level 1", "3 of 24 cells dug\nCrew: Bramble", RoomCard.STATE_DIGGING)
	assert_true(card.visible, "shown")
	assert_false(card.stop_button().disabled, "something to stop")
	card.stop_button().pressed.emit()
	card.close_button().pressed.emit()
	assert_equal(pressed, ["stop", "close"] as Array[String], "said, not acted on")
	card.show_room("Kitchen, Underground level 1", "Dug: all 24 cells", RoomCard.STATE_DUG)
	assert_true(card.stop_button().disabled, "nothing to stop")
	assert_equal(card.stop_button().text, "Dug", "says so")
	assert_equal(card.stop_button().tooltip_text, RoomCard.NOTHING_TO_STOP, "and why")
	card.show_room("Kitchen, Underground level 1", "Stopped: ...", RoomCard.STATE_STOPPED)
	assert_true(card.stop_button().disabled, "stopped: nothing more to stop")
	assert_equal(card.stop_button().text, "Stopped", "says so")
	assert_equal(card.stop_button().tooltip_text, RoomCard.STOPPED_REASON, "and why")
	card.place_in(Rect2(10.0, 20.0, 280.0, 184.0))
	assert_equal(card.stop_button().size, Vector2(176.0, 32.0), "UI-BUILD-016 at its minimum in the 280-wide card")
	_build.open_panel()
	_build.panel.show_room("Kitchen, Underground level 1", "x", RoomCard.STATE_DIGGING)
	assert_true(_build.panel.escape(), "Escape")
	assert_false(_build.panel.room_shown(), "puts it away")
	_build.panel.show_room("Kitchen, Underground level 1", "x", RoomCard.STATE_DIGGING)
	_build.bar.choose(2)
	_build._on_level_chosen(2)
	assert_false(_build.panel.room_shown(), "a level change puts it away")


func test_cells_put_back_complete_their_blocks_with_the_rooms_dug_cells() -> void:
	"""BUILD-REQ-002, "a 2 × 2 block of its room" (decision 1991): a stopped room's waiting cells, back in the plan,
	are judged with what of the room is dug, so a jagged edge left by the dig is not "Too narrow"; a strip beside
	another room's type still is."""
	var works: Works = _build.works
	assert_true(works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5, 8, 4, 9, 4, 8, 5, 9, 5]), KITCHEN, 0),
		"a 4 × 2 Kitchen")
	for cell: Vector2i in [Vector2i(6, 4), Vector2i(7, 4), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 4)]:
		assert_true(works.open_cell(1, cell), "dug")
	var back: PackedInt32Array = works.stop_room(1, Vector2i(9, 5))
	assert_equal(back.size(), 6, "three cells back: an L, narrower than 2 × 2 on its own")
	var k: int = _build.batch.return_cells(KITCHEN, 1, back)
	assert_true(k >= 0, "back in the plan")
	assert_false(_build.batch.operation_reason(k).contains("Too narrow"), _build.batch.operation_reason(k))
	var other: int = _build.batch.return_cells(3, 1, PackedInt32Array([5, 4, 5, 5])) # Beside the dug Kitchen cells.
	assert_true(_build.batch.operation_reason(other).contains("Too narrow"), "another type's strip: %s"
		% _build.batch.operation_reason(other))


func test_cells_put_back_are_sized_with_the_rooms_dug_cells() -> void:
	"""SET-BUILD-001 §4's minimum is the room's (decision 1991): 22 cells put back beside 2 dug Kitchen cells make the
	Kitchen's 24; the same 22 on their own are "Too small"."""
	var works: Works = _build.works
	var cells: PackedInt32Array = PackedInt32Array()
	for x: int in range(6, 12):
		for z: int in range(4, 8):
			cells.append_array(PackedInt32Array([x, z]))
	assert_true(works.order_room(1, cells, KITCHEN, 0), "a 6 × 4 Kitchen")
	assert_true(works.open_cell(1, Vector2i(6, 4)) and works.open_cell(1, Vector2i(6, 5)), "two cells dug")
	var back: PackedInt32Array = works.stop_room(1, Vector2i(11, 7))
	assert_equal(back.size(), 44, "22 cells back")
	var k: int = _build.batch.return_cells(KITCHEN, 1, back)
	assert_false(_build.batch.operation_reason(k).contains("Too small"), _build.batch.operation_reason(k))
	var alone: int = _build.batch.return_cells(KITCHEN, 2, back)
	assert_true(_build.batch.operation_reason(alone).contains("Too small"), "on another level, alone: %s"
		% _build.batch.operation_reason(alone))


func _kitchen_open() -> int:
	"""The Kitchen's dug cells on level 1."""
	var count: int = 0
	for x: int in range(KITCHEN_FROM.x, KITCHEN_TO.x + 1):
		for z: int in range(KITCHEN_FROM.y, KITCHEN_TO.y + 1):
			count += 1 if _build.works.state(1, Vector2i(x, z)) == Works.OPEN else 0
	return count


func test_a_stopped_cell_keeps_no_room_type_for_what_is_ordered_there_next() -> void:
	"""A cell put back to earth by a Stop forgets its room type: a way down whose landing is later ordered over it is
	a landing, not a piece of the stopped room."""
	var works: Works = _build.works
	assert_true(works.order_room(2, PackedInt32Array([4, 4, 5, 4, 4, 5, 5, 5]), KITCHEN, 0), "a Kitchen on level 2")
	assert_equal(works.stop_room(2, Vector2i(4, 4)).size(), 8, "stopped before a cell was dug")
	assert_equal(works.type_of(2, Vector2i(4, 4)), Works.TYPE_NONE, "no type left")
	assert_true(works.order_way_down(1, Vector2i(4, 4)), "a way down from level 1 landing there")
	assert_equal(works.room_type_at(2, Vector2i(4, 4)), -1, "a landing, not the Kitchen")


func test_a_room_is_only_its_own_type_and_a_stop_leaves_its_neighbour_alone() -> void:
	"""Two confirmed rooms side by side, a Kitchen and a Passage: each card's room is its own cells, and stopping the
	Kitchen puts back none of the Passage."""
	var works: Works = _build.works
	assert_true(works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5]), KITCHEN, 0), "a Kitchen")
	assert_true(works.order_room(1, PackedInt32Array([8, 4, 9, 4, 8, 5, 9, 5]), 7, 0), "a Passage beside it")
	assert_equal(works.room_cells(1, Vector2i(6, 4)).size(), 8, "the Kitchen's four cells only")
	assert_equal(works.stop_room(1, Vector2i(6, 4)).size(), 8, "its four back")
	assert_equal(works.state(1, Vector2i(8, 4)), Works.ORDERED, "the Passage still waits")
	assert_equal(works.waiting(), 4, "its four")


func test_a_mole_named_again_takes_on_the_new_batch_too() -> void:
	"""A mole already digging for one Confirm all, named for the next, digs both batches on the one trip."""
	_confirm_kitchen_with(PackedInt32Array([1]))
	var trip: BelowTask = _build.diggers[0]
	_build.batch.begin_stroke(7, 1, Vector2i(12, 4))
	_build.batch.extend_stroke(Vector2i(13, 5))
	_build.batch.finish_stroke()
	_selected = PackedInt32Array([1])
	_build.confirm_all()
	assert_equal(_build.diggers.size(), 1, "no second trip")
	assert_equal(trip.crews.size(), 2, "the trip serves both batches")
	_build._send_crews()
	assert_equal(trip.crews.size(), 2, "each once, however often it is asked")
	_step_all(8000)
	assert_equal(_build.works.waiting(), 0, "both dug by the one mole")
	assert_equal(trip.dug, 32, "every cell")


func test_the_ledgers_second_line_keeps_the_crew_and_the_note_before_the_work() -> void:
	"""Decision 1991, E8: the longest second line that fits -- the work, the crew and the note; else the crew and the
	note; else the work and the crew; else the crew alone."""
	_build.open_panel()
	_build.bar.choose(1)
	_build.batch.begin_stroke(KITCHEN, 1, KITCHEN_FROM)
	_build.batch.extend_stroke(KITCHEN_TO)
	_build.batch.finish_stroke()
	var ledger: Button = _build.panel.controls()[&"ledger"]
	var font: Font = ledger.get_theme_font(&"font")
	var px: int = BuildPanel.TEXT_PX
	var crew: String = "Crew: Tuppen"
	var note: String = "proof of concept"
	_build.panel.set_crew_line(crew)
	var work: String = ledger.text.get_slice("\n", 1).get_slice(" · ", 0) # "work about ..." as the panel words it.
	var crew_note: float = font.get_string_size(crew + " · " + note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var work_crew: float = font.get_string_size(work + " · " + crew, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var all_three: float = font.get_string_size(work + " · " + crew + " · " + note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var wide: float = maxf(crew_note, work_crew) + 1.0 # Room for either pair, not for all three.
	assert_true(wide < all_three, "the pairs are shorter than all three")
	ledger.size = Vector2(wide + 2.0 * 8.0 + 16.0, 44.0)
	_build.panel.set_plan_note(note)
	assert_equal(ledger.text.get_slice("\n", 1).trim_suffix(" ▴").trim_suffix(" ▾"), crew + " · " + note,
		"the crew and the note: %s" % ledger.text)
	ledger.size = Vector2(4000.0, 44.0)
	_build.panel.set_crew_line("Crew: Tuppen ")
	assert_true(ledger.text.get_slice("\n", 1).begins_with("work "), "wide: the work first: %s" % ledger.text)
	ledger.size = Vector2(40.0, 44.0)
	_build.panel.set_crew_line(crew)
	assert_true(ledger.text.get_slice("\n", 1).begins_with(crew), "narrow: the crew alone: %s" % ledger.text)
