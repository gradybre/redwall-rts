extends "res://test/live/demo_build_dig_live.gd"
## SLICE C3 IN THE DEMO, live (decision 1991; Brendan's rulings P-1990-1 (b), P-1990-4 (a), P-1990-5 (a)): on the real
## village through the real input gate -- the Entrance placed and a Passage and a Kitchen painted (the dig loop's own
## steps), the crew selected (the staged village's one mole with art; two residents in an art-free village, where no
## mole lives), the footer's ledger naming it, Confirm all clicked, every crew member down digging, a click on the
## Kitchen opening
## its room card (UI-BUILD-015), "Stop digging" (UI-BUILD-016) clicked: the Kitchen's waiting cells back in the plan as
## a pending Kitchen, what was dug kept, and the crew walking out once the Passage is done. Optional:
## -- --capture <directory> for its frames.

const Tags := preload("res://demo/build_panel/demo_build_tags.gd")

## The crew selected: up to two moles -- the village's own (the staged demo village has one) -- or, with no mole in
## the village (art-free placeholders), two residents.
var _crew: PackedInt32Array = PackedInt32Array()
## Kitchen cells dug when the Stop was clicked.
var _dug_at_stop: int = 0


func _initialize() -> void:
	"""The real village; the crew loop's steps."""
	super()
	_steps = [_open_on_the_surface, _scroll_to.bind("Hatch with ladder"), _choose_the_entrance, _place_the_entrance,
		_add_the_entrance, _down_to_level_one, _scroll_to.bind("Passage"), _choose_the_passage, _paint_the_passage,
		_scroll_to.bind("Kitchen"), _choose_the_kitchen, _paint_the_kitchen, _select_the_crew, _tags_apart, _plan_tags_apart, _crew_named,
		_confirm_with_the_crew, _wait_for_both_digging, _tags_apart, _put_the_card_down, _click_the_kitchen,
		_stop_digging, _capture_after.bind("stopped", 12), _stopped_words, _tags_apart, _wait_for_the_crew_out,
		_kitchen_kept, _close_keeping_the_plan, _keep]


func _moles() -> PackedInt32Array:
	"""The village's moles, or (art-free, no mole) its first residents."""
	var cast: Node = _village.get("_cast")
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in int(cast.call(&"actor_count")):
		if String((cast.call(&"actor", i) as Node).get("species")) == "Mole":
			out.append(i)
	if out.is_empty():
		for i: int in mini(2, int(cast.call(&"actor_count"))):
			out.append(i)
	return out


func _select_the_crew() -> void:
	"""The crew selected (the command layer's own selection, as a box or shift-click makes it)."""
	_crew = _moles().slice(0, 2)
	_command().call(&"select", _crew)
	_check("a crew to select", not _crew.is_empty(), str(_crew))


func _crew_named(steps_left: int = 30) -> void:
	"""P-1990-4 (a): the footer's ledger names them before Confirm all (it reads the selection every quarter second)."""
	var line: String = String(_build().get("panel").call(&"crew_line"))
	var names: PackedStringArray = PackedStringArray()
	for i: int in _crew:
		names.append(String((_village.get("_cast").call(&"actor", i) as Node).get("display_name")).get_slice(" ", 0))
	if line != "Crew: " + ", ".join(names) and steps_left > 0:
		_steps.push_front(_crew_named.bind(steps_left - 1))
		return
	_check("the ledger names the crew", line == "Crew: " + ", ".join(names), line)
	var ledger: Button = _build().get("panel").call(&"controls")[&"ledger"]
	_check("on the footer's ledger", ledger.text.contains(line), ledger.text)
	_capture("crew_named")


func _confirm_with_the_crew() -> void:
	"""Confirm all, clicked: both go down; nothing is taken from the stores (the proof of concept is free)."""
	var wood: int = int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood"))
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("everything ordered", int(_build().get("works").call(&"waiting")) == ORDERED_CELLS,
		str(_build().get("works").call(&"waiting")))
	_check("nothing taken from the stores", int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood")) == wood)
	var sent: Array = _build().get("diggers")
	_check("every crew member sent", sent.size() == _crew.size(), "%d of %d" % [sent.size(), _crew.size()])
	_manager().call(&"set_speed", 4)


func _wait_for_both_digging() -> void:
	"""Until every crew member has dug and the Kitchen is partway: some of it dug, most still waiting."""
	_wait_until("the crew digs into the Kitchen", func() -> bool:
		var sent: Array = _build().get("diggers")
		for trip: Object in sent:
			if int(trip.get("dug")) < 1: return false
		return not sent.is_empty() and _kitchen_cells(Works.OPEN) >= 2,
		"crew_digging", WAIT_STEPS)


func _put_the_card_down() -> void:
	"""The Kitchen card put down (as after a Confirm all a player would), so a click reads a room, not a stroke."""
	_build().get("panel").call(&"clear_choice")
	_check("no card armed", int(_build().call(&"armed_type")) < 0)


func _click_the_kitchen() -> void:
	"""A click on the Kitchen opens its card: how far, who, and that it is a proof of concept."""
	_manager().call(&"set_speed", 0)
	_click(_screen_of(KITCHEN_TO, 1))
	var card: Object = _build().get("panel").call(&"room_card")
	_check("the room card opens", bool(card.get("visible")), "")
	_check("named", String(card.call(&"title")) == "Kitchen, Underground level 1", String(card.call(&"title")))
	var words: String = String(card.call(&"words"))
	_check("how far and who", words.contains("of 24 cells dug") and words.contains("Crew: "), words)
	_check("a proof of concept, said", words.contains("Proof of concept: free"), words)
	_capture("room_card")


func _stop_digging() -> void:
	"""Stop digging, clicked: the Kitchen's waiting cells go back in the plan; what is dug stays."""
	var batch: Object = _build().get("batch")
	var card: Object = _build().get("panel").call(&"room_card")
	var pending: int = int(batch.call(&"pending_count"))
	_click(_centre(card.call(&"stop_button")))
	_check("no Kitchen cell waits", _kitchen_cells(Works.ORDERED) == 0, str(_kitchen_cells(Works.ORDERED)))
	_dug_at_stop = _kitchen_cells(Works.OPEN)
	_check("what was dug stays", _dug_at_stop > 0 and _dug_at_stop < 24, str(_dug_at_stop))
	_check("the rest is a pending Kitchen", int(batch.call(&"pending_count")) == pending + 1,
		"%d -> %d" % [pending, int(batch.call(&"pending_count"))])
	_check("the stop button now has nothing to stop", bool(card.call(&"stop_button").get("disabled")))
	var k: int = int(batch.call(&"operation_count")) - 1
	_check("the Kitchen put back is ready to confirm again (sized and blocked with what is dug)",
		int(batch.call(&"operation_kind", k)) == 0, String(batch.call(&"operation_reason", k)))
	_check("the card gives the real counts", String(card.call(&"words")).begins_with("Stopped: %d of 24 cells dug"
		% _dug_at_stop), String(card.call(&"words")))
	_check("and says Stopped", String(card.call(&"stop_button").get("text")) == "Stopped")


func _wait_for_the_crew_out() -> void:
	"""Until every ordered cell is dug and the crew came out; the Kitchen's dug part unchanged."""
	_wait_until("the crew finishes the Passage and walks out", func() -> bool:
		return int(_build().get("works").call(&"waiting")) == 0 and not bool(_build().call(&"digging")),
		"crew_out", WAIT_STEPS)


func _kitchen_kept() -> void:
	"""The Kitchen's dug part unchanged by the rest of the dig."""
	_check("the Kitchen kept what was dug", _kitchen_cells(Works.OPEN) == _dug_at_stop,
		"%d, %d at the stop" % [_kitchen_cells(Works.OPEN), _dug_at_stop])


func _kitchen_cells(wanted: int) -> int:
	"""The Kitchen rectangle's cells on level 1 in state `wanted`."""
	var works: Object = _build().get("works")
	var count: int = 0
	for x: int in range(KITCHEN_FROM.x, KITCHEN_TO.x + 1):
		for z: int in range(KITCHEN_FROM.y, KITCHEN_TO.y + 1):
			count += 1 if int(works.call(&"state", 1, Vector2i(x, z))) == wanted else 0
	return count


func _close_keeping_the_plan() -> void:
	"""Normal speed; the card put down; B asks to keep the returned Kitchen cells (pending), and Keep keeps them."""
	_manager().call(&"set_speed", 1)
	_build().get("panel").call(&"clear_choice")
	_key(KEY_B)
	var panel: Object = _build().get("panel")
	_check("B asks to keep the pending plan", int(panel.call(&"question")) == 1, str(panel.call(&"question")))
	_capture("close_keep")


func _keep() -> void:
	"""Keep, clicked (the question laid out a step before)."""
	_click(_centre(_build().get("panel").call(&"controls")[&"yes"]))
	_check("Keep closes the panel with the cells still planned", not bool(_build().call(&"is_open"))
		and int(_build().get("batch").call(&"pending_count")) == 1)


func _stopped_words() -> void:
	"""After the Stop the crew's own words no longer say it digs (nothing is left for it but the Passage, or nothing)."""
	for trip: Object in _build().get("diggers"):
		var label: String = String(trip.call(&"label"))
		var waiting: int = int(trip.call(&"waiting"))
		_check("the crew's words follow the Stop", (waiting > 0 and label.contains("(%d cells waiting)" % waiting))
			or (waiting == 0 and not label.begins_with("Digging")), "%s (%d waiting)" % [label, waiting])
	_manager().call(&"set_speed", 4)


func _plan_tags_apart() -> void:
	"""The plan's own tags on the level shown (its ghosts' words, "✓ Passage", "✓ Hatch with ladder comes down here")
	and the level's tags, read here apart from the panel's spacing list: none sits on another."""
	var tags: Array[Label3D] = []
	var level: int = int(_build().get("bar").call(&"shown_level"))
	_build().get("paint").call(&"shown_tags", level, tags)
	_build().get("dug").call(&"shown_tags", tags)
	var camera: Camera3D = _build().get("_camera")
	var pairs: int = int(Tags.overlaps(camera, tags))
	_check("the plan's tags sit on none of each other", pairs == 0, "%d pairs over %d tags" % [pairs, tags.size()])
