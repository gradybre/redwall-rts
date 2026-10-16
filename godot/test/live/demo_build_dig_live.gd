extends "res://test/live/demo_input_live.gd"
## THE PROOF OF CONCEPT'S WHOLE LOOP, live (decision 1912): on the real village through the real input gate -- B, the
## entrance (a Hatch with ladder since decision 2021) placed on the surface by a click and the connector card's Add to
## plan, a Passage and a Kitchen painted by drags on underground level 1,
## Confirm all clicked, a mole walking to the Entrance and digging every cell, the rooms drawn open, and a resident
## sent down by a right click on a dug cell; the look (decision 1913): the rooms are pits with stairs out of the
## landing, no two tags sit on each other, and the Entrance is a burrow mouth on the surface; their rounded walls
## (decision 1914): mid-dig the ordered cells stay square, and every dug cell's floor is whole. THE WAYS PER FAMILY
## (decision 2021): the five way cards in the row, a Burrow mouth and a Stair-head placed through the connector card,
## dug by the mole, drawn on level 1 and on the surface, and removing the hatch refused in words while it is the only
## way in to the Kitchen (BUILD-REQ-017). Optional: -- --capture <directory> for its frames.

const Families := preload("res://scripts/ui/build_connector_families.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Earth := preload("res://demo/build_panel/demo_build_earth.gd")

## Level 1 is under the stream's water up to z 31 m (decision 1912); the loop is laid on dry ground beyond it.
const ENTRANCE: Vector2i = Vector2i(10, 36)
const PASSAGE_FROM: Vector2i = Vector2i(12, 36)
const PASSAGE_TO: Vector2i = Vector2i(17, 37)
const KITCHEN_FROM: Vector2i = Vector2i(18, 35)
const KITCHEN_TO: Vector2i = Vector2i(23, 38)
## Level 1 is 4.6 m down, so the camera looks a little south of the loop to bring its floor up the screen.
const LOOK_AT: Vector3 = Vector3(17.0, 0.0, 41.0)
## Cells ordered: the Entrance's landing (4), the Passage (12) and the Kitchen (24).
const ORDERED_CELLS: int = 40
## Steps (of STEP_FRAMES frames) a wait may take before it fails.
const WAIT_STEPS: int = 3000
const MAX_RESENDS: int = 2
## Steps the surface is left to settle before its frame (a crown over the Entrance fades out over a few frames).
const SETTLE_STEPS: int = 30
## Where the camera looks at the Entrance's mouth from (demo_camera.gd `aim`). The mouth's arch faces the default
## heading (yaw 0, from the south; decision 1913), but at this Entrance an oak's trunk and a fallen log stand south of
## it, and no view the camera allows (7 m and 30 degrees at the least) sees into the arch: from the west, the clearest
## side, the frame shows the mound whole.
const MOUTH_YAW_DEG: float = 270.0
const MOUTH_PITCH_DEG: float = 38.0
const MOUTH_M: float = 7.0
## Decision 2021's two more entrances, on dry ground south-east of the loop (level 1 is dry from z 32 m): the burrow
## mouth turned once (R) to descend east, the stair-head at turn 0 descending north.
## The first spot of each list whose ground is open (the surface's stream and placements refuse a way: decision 2022).
const RAMP_SPOTS: Array[Vector2i] = [Vector2i(24, 40), Vector2i(26, 40), Vector2i(28, 40)]
## The stair-head descends north only (decision 2041 P-DF-6 (a)): its 2 × 27 strip from z 33, its landing at the north.
const STAIR_SPOTS: Array[Vector2i] = [Vector2i(38, 33), Vector2i(40, 33), Vector2i(42, 33), Vector2i(44, 33),
	Vector2i(46, 33), Vector2i(48, 33), Vector2i(50, 33), Vector2i(38, 34), Vector2i(42, 34)]
## Their cells below: the ramp's 2 × 12 and the stair's 2 × 20 (build_connector_families.gd, placeholders; 2043's M5).
const WAYS_CELLS: int = 64
## Where the camera looks at level 1's two new ways from (the hatch is in the loop's own frames), and how far; and at
## the two new entrances' tops on the surface, low from the west as at the hatch (MOUTH_YAW_DEG).
const WAYS_LOOK_AT: Vector3 = Vector3(36.0, 0.0, 44.0)
const WAYS_PITCH_DEG: float = 64.0
const WAYS_M: float = 34.0
const TOPS_LOOK_AT: Vector3 = Vector3(28.0, 0.0, 47.0)
const TOPS_M: float = 20.0
const REFUSED: String = "X Not possible: Would cut off Kitchen (level 1), Passage (level 1): build another way in first"

var _visitor: int = -1
## Times the visit was ordered again after the resident dropped it (a walk to the Entrance that got lost ends the
## trip and the resident goes back to its routine, `resident_brain.gd`'s lost-trip rule; decision 1912 E19).
var _resends: int = 0


func _initialize() -> void:
	"""The real village; only the loop's steps."""
	super()
	_steps = [_open_on_the_surface, _scroll_to.bind("Stone stairs"), _five_way_cards, _scroll_to.bind("Hatch with ladder"),
		_choose_the_entrance, _place_the_entrance, _add_the_entrance,
		_down_to_level_one, _scroll_to.bind("Passage"), _choose_the_passage, _paint_the_passage, _scroll_to.bind("Kitchen"),
		_choose_the_kitchen, _paint_the_kitchen, _confirm_all, _wait_for_the_mole, _after_the_earth.bind(_check_square_plan),
		_tags_apart, _wait_for_the_rooms, _after_the_earth.bind(_rooms_drawn_as_pits), _send_a_visitor,
		_wait_for_the_visitor, _tags_apart, _report_resends, _up_to_the_entrance]
	_steps.append_array([_back_to_the_surface, _scroll_to.bind("Burrow mouth"), _place_way.bind("Burrow mouth", RAMP_SPOTS, 1),
		_add_way.bind("Burrow mouth"), _scroll_to.bind("Stair-head"), _place_way.bind("Stair-head", STAIR_SPOTS, 0),
		_add_way.bind("Stair-head"), _confirm_the_ways, _ways_on_the_surface, _wait_for_the_ways, _ways_below,
		_after_the_earth.bind(_ways_drawn), _up_for_the_removal, _scroll_to.bind("Hatch with ladder"),
		_refuse_the_hatchs_removal, _refusal_beside_the_pointer, _close_the_panel])


func _open_on_the_surface() -> void:
	"""The guide card put away (its Hide guide button), so it covers none of the ground; B opens the panel on the
	surface; the camera over the dry ground the loop is laid on."""
	var hide: Button = _village.get("_guide").get("card").call(&"button", "Hide guide")
	if hide != null and hide.is_visible_in_tree():
		_click(_centre(hide))
	var camera: Node = _village.get("_camera")
	camera.call(&"centre_on", LOOK_AT)
	camera.call(&"snap")
	_key(KEY_B)
	_check("B opens the build panel on the surface", bool(_build().call(&"is_open"))
		and int(_build().get("bar").call(&"shown_level")) == 0)
	var dug_u: int = int(_build().get("orders").call(&"dug_height_of", 1))
	_check("a room is priced at the claw crew's reach on the mounted content (1912 E9)", dug_u == 1024, str(dug_u))


func _scroll_to(card_name: String) -> void:
	"""The card row scrolled to `card_name` (drawn by the next step)."""
	_scroll_to_card(card_name)


func _five_way_cards() -> void:
	"""Decision 2021 (P-D1-1 (a)): the row offers the Burrow mouth, the Hatch with ladder and the Stair-head, with Stone
	and Spiral stairs locked."""
	var names: PackedStringArray = PackedStringArray()
	for card: Object in _build().get("panel").call(&"row_cards"):
		if int(card.get("kind")) == 4:
			names.append("%s%s" % [card.get("name"), "" if bool(card.call(&"usable")) else " (locked)"])
	_check("the five way cards", ", ".join(names) == "Burrow mouth, Hatch with ladder, Stair-head, Stone stairs (locked), "
		+ "Spiral stair (locked)", ", ".join(names))
	_capture("ways_cards")


func _choose_the_entrance() -> void:
	"""The Hatch with ladder card, clicked."""
	_click(_card_centre("Hatch with ladder"))
	_check("the hatch card arms placing it", bool(_build().call(&"way_down_armed")))


func _place_the_entrance() -> void:
	"""A click on the ground pins it and opens the connector card: "✓ Connects to Underground level 1"."""
	root.gui_release_focus()
	_click(_screen_of(ENTRANCE, 0))
	var words: String = String(_build().get("panel").call(&"connector_words"))
	_check("the connector card opens", words.begins_with("✓ Connects to Underground level 1"), words)
	_capture("loop_connector_card")


func _add_the_entrance() -> void:
	"""Add to plan, clicked: the hatch joins the batch, "✓" (its landing on level 1 is dry ground)."""
	var card: Object = _build().get("panel").call(&"connector")
	_click(_centre(card.call(&"add_button")))
	var items: Object = _build().get("batch").call(&"items")
	var placed: bool = int(items.call(&"live_count")) == 1
	_check("the hatch is placed", placed and items.call(&"cell_of", 0) == ENTRANCE,
		str(items.call(&"cell_of", 0)) if placed else String(_build().get("batch").call(&"last_dropped")))
	_check("it can be built", placed and int(_build().get("batch").call(&"item_kind", 0)) == 0,
		String(_build().get("batch").call(&"item_reason", 0)) if placed else "")
	_capture("loop_entrance_placed")


func _down_to_level_one() -> void:
	"""Page Down: level 1, the actual World drawn."""
	_key(KEY_PAGEDOWN)
	_check("level 1", int(_build().get("bar").call(&"shown_level")) == 1)


func _choose_the_passage() -> void:
	"""The Passage card, clicked."""
	_click(_card_centre("Passage"))
	root.gui_release_focus()
	_check("Passage armed", int(_build().call(&"armed_type")) == 7)


func _paint_the_passage() -> void:
	"""A drag paints the Passage from the Entrance's landing east: it has a way in through the pending Entrance."""
	_check("the Passage's corner is on open ground", not _over_ui(_screen_of(PASSAGE_FROM, 1)))
	_drag(_screen_of(PASSAGE_FROM, 1), _screen_of(PASSAGE_TO, 1))
	var batch: Object = _build().get("batch")
	_check("the Passage is painted", int(batch.call(&"operation_count")) == 1
		and int(batch.call(&"operation_cell_count", 0)) == 12, str(batch.call(&"last_dropped")))
	var painted: bool = int(batch.call(&"operation_count")) > 0
	_check("with a way in", painted and int(batch.call(&"operation_kind", 0)) == 0,
		String(batch.call(&"operation_reason", 0)) if painted else "from %s to %s" % [_screen_of(PASSAGE_FROM, 1), _screen_of(PASSAGE_TO, 1)])


func _choose_the_kitchen() -> void:
	"""The Kitchen card, clicked."""
	_click(_card_centre("Kitchen"))
	root.gui_release_focus()


func _paint_the_kitchen() -> void:
	"""A drag paints a 6 × 4 Kitchen beside the Passage: ✓, reached through it."""
	_drag(_screen_of(KITCHEN_FROM, 1), _screen_of(KITCHEN_TO, 1))
	var batch: Object = _build().get("batch")
	_check("the Kitchen is painted, ✓", int(batch.call(&"pending_count")) == 3 and int(batch.call(&"first_invalid")) < 0,
		str(batch.call(&"last_dropped")))
	_capture("loop_painted")


func _confirm_all() -> void:
	"""Confirm all, clicked: nothing is taken from the stores (free for now); a mole is sent."""
	var wood: int = int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood"))
	var controls: Dictionary = _build().get("panel").call(&"controls")
	_click(_centre(controls[&"confirm"]))
	var works: Object = _build().get("works")
	_check("everything ordered", int(works.call(&"waiting")) == ORDERED_CELLS, str(works.call(&"waiting")))
	_check("nothing taken from the stores", int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood")) == wood)
	_check("a mole is sent (with no mole in an art-free village, any resident: P-1912-3)", bool(_build().call(&"digging")))
	_manager().call(&"set_speed", 4)


func _wait_for_the_mole() -> void:
	"""Until the mole is below and has dug six cells."""
	_wait_until("the mole walks in and digs", func() -> bool:
		var digger: Object = _build().get("digger")
		return digger != null and int(digger.get("dug")) >= 6, "loop_mole_digging", WAIT_STEPS)


func _wait_for_the_rooms() -> void:
	"""Until every ordered cell is dug and the mole came out."""
	_wait_until("every cell dug", func() -> bool:
		return int(_build().get("works").call(&"waiting")) == 0 and not bool(_build().call(&"digging")),
		"loop_rooms_open", WAIT_STEPS)


func _tags_apart() -> void:
	"""Decision 1913: the names over the figures and the level's tags never sit on each other."""
	var pairs: int = int(_build().call(&"tag_overlaps"))
	_check("no two tags sit on each other", pairs == 0, "%d pairs: %s" % [pairs, _build().get("dug").call(&"tags")])


func _rooms_drawn_as_pits() -> void:
	"""Decision 1913: the dug cells are pits in the earth (walls drawn), and the Entrance's landing has its stairs up."""
	var dug: Object = _build().get("dug")
	_check("the dug rooms are pits with rounded walls (1914)", int(dug.get("earth").get("patch_count")) > 0)
	_check("the ladder rises out of the hatch's landing", int(dug.call(&"stairs_shown")) == 1)
	_check_whole_floors()


func _check_whole_floors() -> void:
	"""Decision 1914, rule (a): every dug cell on level 1 is drawn at the floor's depth over its whole square."""
	var earth: Object = _build().get("dug").get("earth")
	var cells: PackedInt32Array = PackedInt32Array()
	_build().get("works").call(&"cells_into", 1, Works.OPEN, cells)
	var off: int = int(earth.call(&"cells_off_the_floor", cells))
	_check("every dug cell's floor is whole (rule a)", not cells.is_empty() and off == 0, "%d cells hidden" % off)


func _after_the_earth(step: Callable, steps_left: int = WAIT_STEPS) -> void:
	"""Run `step` once the earth's rebuild on its worker has been shown by the game's own frames (decision 1914: the
	checks read what the player sees, never a build forced through), else wait a step; fail when the budget runs out."""
	if not bool(_build().get("dug").get("earth").call(&"busy")):
		step.call()
	elif steps_left <= 0:
		_check("the earth's rebuild is shown", false, "still in flight")
	else:
		_steps.push_front(_after_the_earth.bind(step, steps_left - 1))


func _check_square_plan() -> void:
	"""Decision 1914, rule (b): mid-dig, no ordered cell is rounded into (the one being dug aside)."""
	var earth: Object = _build().get("dug").get("earth")
	var cells: PackedInt32Array = PackedInt32Array()
	_build().get("works").call(&"cells_into", 1, Works.ORDERED, cells)
	var digging: Vector3i = earth.call(&"digging")
	var square: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, cells.size(), 2):
		if Vector3i(1, cells[at], cells[at + 1]) != digging:
			square.append_array(PackedInt32Array([cells[at], cells[at + 1]]))
	var rounded: int = int(earth.call(&"cells_rounded", square))
	_check("mid-dig, the ordered cells stay square (rule b)", not square.is_empty() and rounded == 0,
		"%d of %d rounded" % [rounded, square.size() >> 1])


func _up_to_the_entrance() -> void:
	"""Page Up: the surface, where the Entrance is a burrow mouth (the camera low over it from the west: see
	MOUTH_YAW_DEG)."""
	_key(KEY_PAGEUP)
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", Vector3(ENTRANCE.x + 1.0, 0.0, ENTRANCE.y + 1.0), MOUTH_YAW_DEG, MOUTH_PITCH_DEG, MOUTH_M)
	camera.call(&"snap")
	_check("the hatch is drawn on the surface", int(_build().get("bar").call(&"shown_level")) == 0
		and int(_build().get("dug").call(&"mouths_shown")) == 1)
	_steps.push_front(_capture_after.bind("loop_entrance_open", SETTLE_STEPS))


func _capture_after(capture_name: String, steps_left: int) -> void:
	"""Capture `capture_name` after `steps_left` more steps (the tree crowns over the camera's line thin out gradually:
	canopy_clear.gd)."""
	if steps_left <= 0:
		_capture(capture_name)
		return
	_steps.push_front(_capture_after.bind(capture_name, steps_left - 1))


func _send_a_visitor() -> void:
	"""A resident who is not a mole, selected, and a right click on a dug Kitchen cell: down they go."""
	_visitor = _first_not_mole()
	_order_the_visit()
	var task: Object = null if _visitor < 0 else (_village.get("_cast").call(&"actor", _visitor) as Node).get("brain").get("task")
	var said: String = String(task.call(&"label")) if task != null and task.has_method(&"label") else str(task)
	# Art-free, with no mole, the digger may be this resident: it came out at the Entrance, so it is in at once.
	_check("a visitor is sent", said.begins_with("Going down") or said.begins_with("In the dug rooms"), said)


func _wait_for_the_visitor() -> void:
	"""Until the visitor stands in the Kitchen below."""
	_wait_until("the visitor walks into the Kitchen", func() -> bool:
		var task: Object = (_village.get("_cast").call(&"actor", _visitor) as Node).get("brain").get("task")
		if (task == null or not task.has_method(&"at")) and _resends < MAX_RESENDS:
			_resends += 1
			_order_the_visit()
			return false
		return task != null and task.has_method(&"at") and task.call(&"at") == Vector3i(1, KITCHEN_FROM.x + 2, KITCHEN_FROM.y + 1),
		"loop_visitor_inside", WAIT_STEPS)


func _report_resends() -> void:
	"""How often the visit had to be ordered again (a player would click again too)."""
	_check("the visit was ordered again at most %d times" % MAX_RESENDS, _resends <= MAX_RESENDS, str(_resends))


func _back_to_the_surface() -> void:
	"""The camera over the dry ground south of the loop, on the surface."""
	_aim_at_the_ways()
	_check("on the surface", int(_build().get("bar").call(&"shown_level")) == 0)


func _aim_at_the_ways() -> void:
	"""The camera over the three ways, far enough to see them all."""
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", WAYS_LOOK_AT, 0.0, WAYS_PITCH_DEG, WAYS_M)
	camera.call(&"snap")


func _open_spot(family: int, spots: Array[Vector2i], turn: int) -> Vector2i:
	"""The first of `spots` where a way of `family` turned `turn` times can be built (the first, to be refused, if
	none)."""
	var why: PackedStringArray = PackedStringArray()
	for spot: Vector2i in spots:
		var judged: Array = _build().get("batch").call(&"judge_item", 0, spot, -1, family, turn)
		if int(judged[0]) == 0:
			return spot
		why.append("%s %s" % [spot, judged[1]])
	_check("an open spot for %s" % Families.name_of(family), false, "; ".join(why))
	return spots[0]


func _place_way(card_name: String, spots: Array[Vector2i], turn: int) -> void:
	"""`card_name`'s card clicked, R turns it `turn` times (the turn is kept from the last way), then the ground at the
	first open spot: the connector card opens saying where it leads."""
	_click(_card_centre(card_name))
	root.gui_release_focus()
	for press: int in 4:
		if int(_build().get("panel").call(&"way_turn")) != turn:
			_key(KEY_R)
	_check("%s turned %d times" % [card_name, turn], int(_build().get("panel").call(&"way_turn")) == turn)
	var at: Vector2i = _open_spot(int(_build().get("panel").call(&"armed_family")), spots, turn)
	_click(_screen_of(at, 0))
	var words: String = String(_build().get("panel").call(&"connector_words"))
	_check("%s: the card says where it leads" % card_name, words.begins_with("✓ Connects to Underground level 1")
		and words.contains("Placeholder: sizes and costs await review"), words)
	_capture("ways_connector_card_%s" % card_name.to_lower().replace(" ", "_"))


func _add_way(card_name: String) -> void:
	"""Add to plan, clicked: the way joins the batch."""
	var card: Object = _build().get("panel").call(&"connector")
	_click(_centre(card.call(&"add_button")))
	var items: Object = _build().get("batch").call(&"items")
	var row: int = int(items.call(&"count")) - 1
	_check("%s added" % card_name, row >= 0 and String(items.call(&"name_of_row", row)) == card_name
		and int(_build().get("batch").call(&"item_kind", row)) == 0, String(_build().get("batch").call(&"last_dropped")))


func _confirm_the_ways() -> void:
	"""Confirm all: both ways' cells below wait for the mole (free for now)."""
	var controls: Dictionary = _build().get("panel").call(&"controls")
	_click(_centre(controls[&"confirm"]))
	var works: Object = _build().get("works")
	_check("both ways ordered", int(works.call(&"waiting")) == WAYS_CELLS, str(works.call(&"waiting")))
	_manager().call(&"set_speed", 4)


func _wait_for_the_ways() -> void:
	"""Until the mole has dug both ways, in through the hatch and over the surface to each foot."""
	_wait_until("the mole digs the burrow mouth and the stair-head", func() -> bool:
		return int(_build().get("works").call(&"waiting")) == 0 and not bool(_build().call(&"digging")),
		"ways_dug", 3 * WAIT_STEPS)


func _ways_below() -> void:
	"""Page Down: level 1, over the two ways' feet."""
	_key(KEY_PAGEDOWN)
	_aim_at_the_ways()
	_check("level 1", int(_build().get("bar").call(&"shown_level")) == 1)


func _ways_drawn() -> void:
	"""Level 1: the ramp rising out of its landing, the stair's flight rising out of its own, the hatch's ladder."""
	var dug: Object = _build().get("dug")
	var tags: PackedStringArray = dug.call(&"tags")
	_check("three ways drawn below", int(dug.call(&"stairs_shown")) == 3, str(dug.call(&"stairs_shown")))
	_check("each named", tags.has("Burrow mouth: way up to the surface") and tags.has("Stair-head: way up to the surface")
		and tags.has("Hatch with ladder: way up to the surface"), ", ".join(tags))
	_capture("ways_dug_below")


func _up_for_the_removal() -> void:
	"""Page Up: the surface, the camera over the hatch."""
	_key(KEY_PAGEUP)
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", Vector3(ENTRANCE.x + 1.0, 0.0, ENTRANCE.y + 3.0), 0.0, WAYS_PITCH_DEG, 18.0)
	camera.call(&"snap")
	_check("back on the surface", int(_build().get("bar").call(&"shown_level")) == 0)


func _refuse_the_hatchs_removal() -> void:
	"""The hatch card chosen and the hatch clicked: refused, naming the Kitchen (BUILD-REQ-017)."""
	_click(_card_centre("Hatch with ladder"))
	root.gui_release_focus()
	_click(_screen_of(ENTRANCE, 0))
	var batch: Object = _build().get("batch")
	_check("removing the only way in is refused in words", String(batch.call(&"last_dropped")) == REFUSED,
		String(batch.call(&"last_dropped")))
	_check("nothing pending", int(batch.call(&"pending_count")) == 0)
	_steps.push_front(_capture_after.bind("ways_removal_refused", 2))


func _refusal_beside_the_pointer() -> void:
	"""The refusal's words stay beside the pointer while the way's card is chosen, and only that judgement shows: the
	ghost over the hatch carries no tag, so no placement refusal shows beside it (decision 2022)."""
	_check("said beside the pointer", String(_build().call(&"label_text")) == REFUSED, String(_build().call(&"label_text")))
	var tags: PackedStringArray = PackedStringArray()
	for ghost: Object in _build().get("paint").call(&"stroke_ghosts", 0):
		if bool(ghost.get(&"visible")) and not String(ghost.call(&"tag_text")).is_empty():
			tags.append(String(ghost.call(&"tag_text")))
	_check("only the removal's judgement shows", tags.is_empty(), ", ".join(tags))


func _ways_on_the_surface() -> void:
	"""The surface: the hatch, the burrow mouth and the stair-head drawn (the two new tops seen low from the west)."""
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", TOPS_LOOK_AT, MOUTH_YAW_DEG, MOUTH_PITCH_DEG, TOPS_M)
	camera.call(&"snap")
	var dug: Object = _build().get("dug")
	_check("three entrances on the surface", int(dug.call(&"mouths_shown")) == 3, str(dug.call(&"mouths_shown")))
	_steps.push_front(_capture_after.bind("ways_surface", SETTLE_STEPS))


func _close_the_panel() -> void:
	"""Normal speed; Escape puts the card down; B closes the panel (nothing pending)."""
	_manager().call(&"set_speed", 1)
	_build().get("panel").call(&"clear_choice")
	_key(KEY_B)
	_check("B closes the panel", not bool(_build().call(&"is_open")))


func _wait_until(check_name: String, done: Callable, capture_name: String, steps_left: int) -> void:
	"""Pass `check_name` once `done()` holds (capturing `capture_name`), else try again next step; fail when the
	budget runs out."""
	if bool(done.call()):
		_check(check_name, true)
		_capture(capture_name)
		return
	if steps_left <= 0:
		_check(check_name, false, "gave up; the visitor: " + _visitor_state())
		return
	_steps.push_front(_wait_until.bind(check_name, done, capture_name, steps_left - 1))


func _order_the_visit() -> void:
	"""Select the visitor and right-click the dug Kitchen cell."""
	_command().call(&"select", PackedInt32Array([_visitor]))
	_right_click(_screen_of(KITCHEN_FROM + Vector2i(2, 1), 1, -Earth.DEPTH_U))


func _visitor_state() -> String:
	"""The visitor's task and where it stands below, for a failed wait's detail."""
	if _visitor < 0:
		return "none"
	var task: Object = (_village.get("_cast").call(&"actor", _visitor) as Node).get("brain").get("task")
	if task == null or not task.has_method(&"label"):
		return str(task)
	return "%s at %s" % [task.call(&"label"), task.call(&"at") if task.has_method(&"at") else "?"]


func _first_not_mole() -> int:
	"""The first resident who is not a mole."""
	var cast: Node = _village.get("_cast")
	for i: int in int(cast.call(&"actor_count")):
		if String((cast.call(&"actor", i) as Node).get("species")) != "Mole":
			return i
	return -1


func _screen_of(cell: Vector2i, level: int, lift_u: int = 0) -> Vector2:
	"""Where `cell`'s middle is on screen on `level`, or `lift_u` above its floor plane (a dug pit's floor is 1 m below
	it: decision 1913), by the painter's own projection."""
	return _build().get("paint").call(&"screen_of", cell, level, lift_u)


func _right_click(at: Vector2) -> void:
	"""A right press and release at `at`."""
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.position = at
		event.pressed = down
		root.push_input(event)
