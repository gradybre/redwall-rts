extends "res://test/live/demo_input_live.gd"
## MOUND HOMES' WHOLE LOOP, live (decision 2002): on the real village through the real input gate -- B on the Surface in
## the Mound style; a Bedroom, a hall (a 4 × 4 Passage: the GDD has no Hall type) and a Kitchen painted by drags, each
## "! No way in" until a door; the Front door and two Windows placed on their outer edges from the Furnish tab, a
## refusal in words; Confirm all; a resident heaping the hill, digging, framing and topping it; the hill fitting the
## rooms (cover over every room, every wall closed, nothing past the berm); a Pantry added at the back with a hatch on
## its floor, the hill growing round it and the mole going down through the Mound's door to dig the hatch's landing on
## level 1; a hearth fitted in the Kitchen and its chimney on the hill. Optional: -- --capture <directory> for its frames
## (each build stage, the finished home from the front and the side, cut away, the growth and level 1).
##
## THE SITE: south of the clearing, on the open grass between the clearing's trees and the stream -- the only ground in
## the village's plannable quadrant where a hill clears every tree and the water and its hatch lands on dry level-1
## ground (z 32 m and past; decision 2002). The rocks, log and stumps there are scenery the hill covers.

const Mound := preload("res://scripts/ui/build_mound.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")

const BEDROOM: Rect2i = Rect2i(1, 22, 6, 4)
const HALL: Rect2i = Rect2i(7, 22, 4, 4)
const KITCHEN: Rect2i = Rect2i(11, 22, 6, 4)
const PANTRY: Rect2i = Rect2i(1, 26, 2, 8)
## The door on the hall's north wall, two edges from x 8; the windows on the Bedroom's and the Kitchen's north walls.
const DOOR: Vector3i = Vector3i(8, 22, 0)
const WINDOWS: Array[Vector3i] = [Vector3i(2, 22, 0), Vector3i(15, 22, 0)]
const HATCH: Vector2i = Vector2i(1, 32)
const Catalog := preload("res://scripts/core/catalog.gd")
const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]
const LOOK_AT: Vector3 = Vector3(9.0, 0.0, 26.0)
const FIRST_CELLS: int = 64
const WAIT_STEPS: int = 6000
const SETTLE_STEPS: int = 20
const STAGE_NAMES: Array[String] = ["", "heaping", "digging", "framing", "topping"]
## The frames are taken in daylight (hours).
const DAY_FROM: int = 8
const DAY_TO: int = 17

var _seen_stages: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0])
var _before_growth: float = 0.0


func _initialize() -> void:
	"""The real village; only the loop's steps."""
	super()
	_steps = [_open_on_the_surface, _scroll.bind("Bedroom"), _paint.bind("Bedroom", BEDROOM), _scroll.bind("Passage"),
		_paint.bind("Passage", HALL), _scroll.bind("Kitchen"), _paint.bind("Kitchen", KITCHEN), _no_way_in_yet,
		_to_furnish, _scroll.bind("Front door"), _choose_card.bind("Front door"), _place_the_door,
		_scroll.bind("Window"), _choose_card.bind("Window"), _place_window.bind(0), _scroll.bind("Window"),
		_choose_card.bind("Window"), _place_window.bind(1), _scroll.bind("Window"), _choose_card.bind("Window"),
		_refuse_a_window, _planned, _confirm_all, _close_for_the_outside,
		_watch_stage.bind(Mounds.HEAPED, "the resident heaps the hill"), _heaped,
		_open_on_the_surface_again, _cut_away_shown, _watch_stage.bind(Mounds.DUG, "the resident digs the rooms"),
		_watch_stage.bind(Mounds.FRAMED, "the rooms are framed with ribs"),
		_watch_stage.bind(Mounds.TOPPED, "the hill is topped and turfed"), _wait_finished, _hill_fits,
		_until_day, _finished_cutaway, _finished_frames, _grow_open, _scroll.bind("Pantry"), _paint.bind("Pantry", PANTRY), _pantry_ready,
		_scroll.bind("Entrance"), _place_the_hatch, _confirm_the_growth, _wait_grown, _hill_grew,
		_wait_hatch_landing, _down_to_level_one, _up_again, _scroll.bind("Kitchen"), _choose_kitchen, _to_furnish,
		_scroll.bind("Hearth"), _furnish_a_hearth, _confirm_the_hearth, _wait_hearth, _chimney_shown, _close_the_panel]


func _open_on_the_surface() -> void:
	"""The guide put away; the camera over the site; B opens the panel on the Surface in the Mound style."""
	var hide: Button = _village.get("_guide").get("card").call(&"button", "Hide guide")
	if hide != null and hide.is_visible_in_tree():
		_click(_centre(hide))
	_aim(LOOK_AT, 0.0, 58.0, 26.0)
	_key(KEY_B)
	_check("B opens the build panel on the Surface", bool(_build().call(&"is_open"))
		and int(_build().get("bar").call(&"shown_level")) == 0)
	_check("the style is Mound there", int(_build().get("panel").call(&"style")) == Mound.STYLE_MOUND)


func _aim(at: Vector3, yaw: float, pitch: float, metres: float) -> void:
	"""The camera at a whole view, jumped to."""
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", at, yaw, pitch, metres)
	camera.call(&"snap")


func _scroll(card: String) -> void:
	"""The card row scrolled to `card` (laid out by the next step)."""
	_scroll_to_card(card)


func _paint(card: String, room: Rect2i) -> void:
	"""Choose `card` and drag `room` on the Surface; it joins the batch as a Mound room."""
	_click(_card_centre(card))
	root.gui_release_focus()
	var from: Vector2 = _screen_of(room.position, 0)
	var to: Vector2 = _screen_of(room.end - Vector2i.ONE, 0)
	_check("%s's corners are on open ground" % card, not _over_ui(from) and not _over_ui(to), "%s %s" % [from, to])
	_drag(from, to)
	var batch: Object = _build().get("batch")
	var last: int = int(batch.call(&"operation_count")) - 1
	_check("%s painted in the Mound style" % card, last >= 0 and int(batch.call(&"operation_cell_count", last)) \
		== room.get_area() and int(batch.call(&"operation_style", last)) == Mound.STYLE_MOUND,
		"%s; %s" % [batch.call(&"last_dropped"), batch.call(&"operation_line", last) if last >= 0 else ""])


func _no_way_in_yet() -> void:
	"""BUILD-MOUND-012: no door yet, every room "! No way in: place a door on an outer edge"."""
	var batch: Object = _build().get("batch")
	var all: bool = int(batch.call(&"operation_count")) == 3
	for k: int in int(batch.call(&"operation_count")):
		all = all and String(batch.call(&"operation_reason", k)) == Mound.TEXT_NO_DOOR
	_check("no door: each room has no way in, in words", all, String(_build().get("panel").call(&"confirm_blocked")))
	_capture("mound_painted_no_way_in")


func _to_furnish() -> void:
	"""The Furnish tab."""
	var tabs: Array = _build().get("panel").call(&"controls")[&"tabs"]
	_click(_centre(tabs[1]))
	_check("the Furnish tab", int(_build().get("panel").call(&"shown_tab")) == 1)


func _choose_card(card: String) -> void:
	"""Choose `card` on the row (scrolled to it by the step before)."""
	_click(_card_centre(card))
	root.gui_release_focus()


func _place_the_door() -> void:
	"""The Front door (oak by default) clicked on the hall's north wall: it takes the edge beside it too."""
	_check("the door's colour is oak by default", int(_build().get("panel").call(&"door_colour")) == Mound.COLOUR_OAK)
	_click(_screen_at(Vector3(DOOR.x + 1.0, 0.0, DOOR.y - 0.15)))
	var edges: Object = _build().get("batch").call(&"mound_edges")
	var placed: bool = int(edges.call(&"live_count")) == 1
	_check("the door is placed on two outer edges", placed and edges.call(&"cell_of", 0) == Vector2i(DOOR.x, DOOR.y)
		and int(edges.call(&"side_of", 0)) == DOOR.z, String(_build().get("batch").call(&"last_dropped")))
	var batch: Object = _build().get("batch")
	_check("with a door every room can be built", int(batch.call(&"first_invalid")) < 0,
		String(_build().get("panel").call(&"confirm_blocked")))


func _place_window(k: int) -> void:
	"""A Window clicked on an outer edge."""
	var edge: Vector3i = WINDOWS[k]
	_click(_screen_at(Vector3(edge.x + 0.5, 0.0, edge.y - 0.15)))
	var edges: Object = _build().get("batch").call(&"mound_edges")
	_check("window %d placed" % (k + 1), int(edges.call(&"live_count")) == k + 2,
		String(_build().get("batch").call(&"last_dropped")))


func _refuse_a_window() -> void:
	"""A window by the keyboard on the wall between the Bedroom and the hall (the cursor on the hall's west cell, its
	side turned west with Shift+R, Enter) is refused in words (BUILD-MOUND-030), and nothing is placed."""
	_build().get("paint").call(&"set_cursor", HALL.position + Vector2i(0, 2), 0, -1)
	_key(KEY_R, true)
	_key(KEY_ENTER)
	var said: String = String(_build().get("batch").call(&"last_dropped"))
	_check("a window off an outer edge is refused in words", said.contains(Mound.TEXT_OFF_OUTER), said)
	_build().get("panel").call(&"clear_choice")


func _planned() -> void:
	"""The plan's frame: rooms, door and windows pending."""
	_capture("mound_planned")


func _confirm_all() -> void:
	"""Confirm all: nothing taken from the stores; the cells wait for their heap; a resident is sent."""
	var wood: int = int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood"))
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	var mounds: Object = _mounds()
	_check("the Mound is ordered", int(mounds.call(&"count", Mounds.ORDERED)) == FIRST_CELLS,
		str(mounds.call(&"count", Mounds.ORDERED)))
	_check("its door and windows are ordered", int(mounds.call(&"edge_count")) == 3)
	_check("nothing taken from the stores (free)",
		int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood")) == wood)
	_check("a resident is sent to build it", bool(_host().call(&"working")))
	_manager().call(&"set_speed", 4)


func _close_for_the_outside() -> void:
	"""B closes the panel: the hill is drawn whole while it is heaped."""
	_key(KEY_B)
	_aim(LOOK_AT, 330.0, 32.0, 30.0)


func _watch_stage(stage: int, check_name: String) -> void:
	"""Until every first cell reached `stage`, capturing a frame part-way (a third of the cells there)."""
	var mounds: Object = _mounds()
	_wait_until(check_name, func() -> bool:
		var reached: int = 0
		for at: int in range(stage, Mounds.STAGES):
			reached += int(mounds.call(&"count", at))
		if reached * 3 >= FIRST_CELLS and _seen_stages[stage] == 0:
			_seen_stages[stage] = 1
			_capture("mound_%s" % STAGE_NAMES[stage - 1])
		return reached >= FIRST_CELLS, "mound_%s_done" % STAGE_NAMES[stage - 1], WAIT_STEPS)


func _heaped() -> void:
	"""The heap's whole hill, from the front and the side."""
	_check("the heap shows over the rooms", _hill().call(&"hill_mesh", false) != null)


func _open_on_the_surface_again() -> void:
	"""B again: the panel on the Surface, the hill cut away so the rooms show as they are dug."""
	_key(KEY_B)
	_aim(LOOK_AT, 0.0, 58.0, 26.0)


func _cut_away_shown() -> void:
	"""The hill drawn cut away while the panel shows the Surface (a frame after it opened)."""
	_check("cut away while the panel shows the Surface", bool(_hill().call(&"shown_cutaway")))


func _wait_finished() -> void:
	"""Until the door and windows are fitted too."""
	_wait_until("the door and windows are fitted", func() -> bool:
		var mounds: Object = _mounds()
		for row: int in int(mounds.call(&"edge_count")):
			if not bool(mounds.call(&"edge_fitted", row)):
				return false
		return not bool(_hill().call(&"busy")), "", WAIT_STEPS)


func _finished_cutaway() -> void:
	"""The finished rooms cut away (by day: the windows' daylight inside, BUILD-MOUND-016)."""
	_check("by day the windows light their rooms", _hour() < DAY_FROM or _hour() >= DAY_TO
		or bool(_hill().call(&"daylight_shown")), str(_hour()))
	_steps.push_front(_capture_after.bind("mound_finished_cutaway", SETTLE_STEPS))


func _hill_fits() -> void:
	"""The hill fits the rooms (BUILD-MOUND-003, -005): a metre's cover over every room cell, the first cell outside
	every outer wall standing to the wall's top (the door's yard aside), and no hill a step past the berm."""
	var field: Field = _field()
	var cells: PackedInt32Array = _mounds().call(&"all_cells")
	var thin: int = 0
	for at: int in range(0, cells.size(), 2):
		var middle: Vector2 = Vector2(cells[at] + 0.5, cells[at + 1] + 0.5)
		thin += 1 if not field.in_eave(middle) and field.height_m(middle) < Field.ROOM_TOP_M + Field.COVER_M else 0
	_check("a metre's cover over every room cell (the door's eave aside)", thin == 0, "%d thin" % thin)
	var open: int = 0
	var past: int = 0
	var outer: Array[Vector3i] = []
	Mound.outer_edges_into(cells, func(c: Vector2i) -> bool: return field.is_room(c), outer)
	for edge: Vector3i in outer:
		var out: Vector2 = Field.edge_middle(edge) + Vector2(Mound.step_of(edge.z))
		var yard: bool = field.is_yard(Mound.outside_of(edge))
		open += 1 if not yard and field.height_m(Field.edge_middle(edge) + Vector2(Mound.step_of(edge.z)) * 0.98) < Field.ROOM_TOP_M else 0
		past += 1 if field.height_m(out + Vector2(Mound.step_of(edge.z)) * (Field.BERM_M - 0.9)) > 0.0 \
			and field.room_distance(out + Vector2(Mound.step_of(edge.z)) * (Field.BERM_M - 0.9)) >= Field.BERM_M else 0
	_check("every wall closed: its first cell out stands to the wall's top", open == 0, "%d open" % open)
	_check("no earth past the berm", past == 0, "%d" % past)


func _until_day(steps_left: int = WAIT_STEPS) -> void:
	"""Capturing, wait for the day's light (DAY_FROM to DAY_TO): the frames are looked at; else go straight on."""
	var hour: int = _hour()
	if _capture_dir.is_empty() or (hour >= DAY_FROM and hour < DAY_TO) or steps_left <= 0:
		return
	_steps.push_front(_until_day.bind(steps_left - 1))


func _hour() -> int:
	"""The village's hour now."""
	return int((_village.get("_services").get("calendar").call(&"now") as Object).get("hour"))


func _finished_frames() -> void:
	"""The finished home: B closes the panel; frames from the front and the side."""
	_key(KEY_B)
	_aim(Vector3(9.0, 0.0, 22.0), 180.0, 26.0, 20.0)
	_steps.push_front(_capture_after.bind("mound_finished_side", SETTLE_STEPS))
	_steps.push_front(_aim_after.bind(Vector3(11.0, 0.0, 27.0), 270.0, 28.0, 24.0))
	_steps.push_front(_capture_after.bind("mound_finished_front", SETTLE_STEPS))


func _aim_after(at: Vector3, yaw: float, pitch: float, metres: float) -> void:
	"""Aim the camera (a step of its own, between two frames)."""
	_aim(at, yaw, pitch, metres)


func _capture_after(capture_name: String, steps_left: int) -> void:
	"""Capture `capture_name` after `steps_left` more steps (tree crowns over the camera's line thin out gradually)."""
	if steps_left <= 0:
		_capture(capture_name)
		return
	_steps.push_front(_capture_after.bind(capture_name, steps_left - 1))


func _grow_open() -> void:
	"""B on the Surface, the camera over the ground behind the hall; the hill's height there now."""
	_key(KEY_B)
	_aim(Vector3(5.0, 0.0, 31.0), 0.0, 64.0, 30.0)
	_before_growth = _field().height_m(Vector2(PANTRY.position.x + 1.0, PANTRY.end.y - 1.5))


func _pantry_ready() -> void:
	"""The Pantry joins the Mound, which has its door: it can be built."""
	var batch: Object = _build().get("batch")
	_check("the Pantry can be built (its Mound has a door)", int(batch.call(&"first_invalid")) < 0,
		String(_build().get("panel").call(&"confirm_blocked")))


func _place_the_hatch() -> void:
	"""The Entrance card clicked on the Pantry's floor: a way down standing in the room, to level 1 (BUILD-MOUND-021)."""
	_click(_card_centre("Entrance"))
	root.gui_release_focus()
	_click(_screen_of(HATCH, 0))
	var items: Object = _build().get("batch").call(&"items")
	_check("the hatch is placed on the Pantry's floor", int(items.call(&"live_count")) == 1
		and int(_build().get("batch").call(&"item_kind", 0)) == 0, String(_build().get("batch").call(&"last_dropped")))


func _confirm_the_growth() -> void:
	"""Confirm all: the Pantry and its hatch."""
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("the Pantry waits for its heap", int(_mounds().call(&"count", Mounds.ORDERED)) == PANTRY.get_area())


func _wait_grown() -> void:
	"""Until the Pantry is heaped, dug, framed and topped."""
	_wait_until("the Pantry is built into the hill", func() -> bool:
		return int(_mounds().call(&"count", Mounds.TOPPED)) == FIRST_CELLS + PANTRY.get_area() \
			and not bool(_hill().call(&"busy")), "mound_grown_cutaway", WAIT_STEPS)


func _hill_grew() -> void:
	"""BUILD-MOUND-004: the hill now rises over the Pantry, where there was none."""
	var after: float = _field().height_m(Vector2(PANTRY.position.x + 1.0, PANTRY.end.y - 1.5))
	_check("the hill grew round the Pantry", _before_growth <= 0.0 and after >= Field.ROOM_TOP_M + Field.COVER_M,
		"%.2f -> %.2f" % [_before_growth, after])


func _wait_hatch_landing() -> void:
	"""Until the mole (or, art-free, any resident) has gone down through the Mound's door and dug the hatch's landing."""
	_wait_until("the hatch's landing on level 1 is dug", func() -> bool:
		return int(_build().get("works").call(&"waiting")) == 0 and not bool(_build().call(&"digging")),
		"mound_hatch_dug", WAIT_STEPS)
	_steps.push_front(_until_day)


func _down_to_level_one() -> void:
	"""Page Down: level 1, the hatch's landing with its way up."""
	_key(KEY_PAGEDOWN)
	_aim(Vector3(HATCH.x + 1.0, 0.0, HATCH.y + 4.0), 0.0, 55.0, 14.0)
	_steps.push_front(_capture_after.bind("mound_level_one", SETTLE_STEPS))
	_steps.push_front(_level_one_shows)


func _level_one_shows() -> void:
	"""Level 1 drawn a frame later: the hatch's landing dug, its way up to the surface."""
	var dug: Object = _build().get("dug")
	_check("level 1: the hatch lands there, its way up drawn", int(_build().get("bar").call(&"shown_level")) == 1
		and int(dug.call(&"stairs_shown")) >= 1 and Array(dug.call(&"tags")).has("Way up to the surface"),
		str(dug.call(&"tags")))


func _up_again() -> void:
	"""Page Up: the Surface."""
	_key(KEY_PAGEUP)
	_aim(LOOK_AT, 0.0, 58.0, 26.0)


func _choose_kitchen() -> void:
	"""The Kitchen card (the Furnish tab then lists its furniture)."""
	_click(_card_centre("Kitchen"))


func _furnish_a_hearth() -> void:
	"""The Kitchen's Hearth placed on its dug floor (furniture still works in a Mound), Confirm all."""
	_choose_card("Hearth")
	_click(_screen_of(KITCHEN.position + Vector2i(2, 1), 0))
	var pieces: Object = _build().get("batch").call(&"furniture")
	_check("a hearth placed on the Kitchen's floor", int(pieces.call(&"live_count")) == 1,
		String(_build().get("batch").call(&"last_dropped")))


func _confirm_the_hearth() -> void:
	"""Confirm all: the hearth waits for the Mound's builder."""
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("the hearth is ordered", int(_build().get("batch").call(&"pending_count")) == 0
		and int(_build().get("fittings").call(&"waiting")) == 1, String(_build().get("panel").call(&"confirm_blocked")))


func _wait_hearth() -> void:
	"""Until the Mound's builder has fitted it."""
	_wait_until("the hearth is fitted by the Mound's builder", func() -> bool:
		return int(_build().get("fittings").call(&"fitted_count", HEARTH)) == 1 and not bool(_hill().call(&"busy")),
		"mound_hearth_cutaway", WAIT_STEPS)


func _chimney_shown() -> void:
	"""BUILD-MOUND-022: a chimney on the hill over the Kitchen's hearth; the finished home once more from the front."""
	_key(KEY_B)
	_aim(Vector3(11.0, 0.0, 24.0), 200.0, 30.0, 24.0)
	_steps.push_front(_capture_after.bind("mound_chimney", SETTLE_STEPS))


func _close_the_panel() -> void:
	"""Normal speed; the panel stays closed (nothing pending)."""
	_manager().call(&"set_speed", 1)
	_check("the panel is closed at the end", not bool(_build().call(&"is_open")),
		"%d pending; %s" % [_build().get("batch").call(&"pending_count"), _build().get("panel").call(&"question_text")])


# --- helpers ---------------------------------------------------------------------------------------------------------

func _host() -> Object:
	"""The build panel's Mound homes."""
	return _build().get("mound")


func _mounds() -> Object:
	"""The Mounds' store."""
	return _host().get("mounds")


func _hill() -> Object:
	"""The Mounds' drawing."""
	return _host().get("view")


func _field() -> Field:
	"""The hill's field as now drawn (after any rebuild in flight)."""
	_hill().call(&"finish")
	return (_hill().get("_snap") as Object).get("field")


func _screen_of(cell: Vector2i, level: int, lift_u: int = 0) -> Vector2:
	"""Where `cell`'s middle is on screen on `level`, by the painter's own projection."""
	return _build().get("paint").call(&"screen_of", cell, level, lift_u)


func _screen_at(point: Vector3) -> Vector2:
	"""Where a world point is on screen."""
	return (_build().get("_camera") as Camera3D).unproject_position(point)


func _wait_until(check_name: String, done: Callable, capture_name: String, steps_left: int) -> void:
	"""Pass `check_name` once `done()` holds (capturing `capture_name`), else try again next step; fail when the
	budget runs out."""
	if bool(done.call()):
		_check(check_name, true)
		if not capture_name.is_empty():
			_capture(capture_name)
		return
	if steps_left <= 0:
		_check(check_name, false, "gave up: stages %s, builder %s" % [_stages(), _builder()])
		return
	_steps.push_front(_wait_until.bind(check_name, done, capture_name, steps_left - 1))


func _stages() -> String:
	"""The count of cells at each stage, for a failed wait's detail."""
	var out: PackedStringArray = PackedStringArray()
	for stage: int in range(Mounds.ORDERED, Mounds.STAGES):
		out.append(str(_mounds().call(&"count", stage)))
	return "/".join(out)


func _builder() -> String:
	"""What the Mound's builder is doing, for a failed wait's detail."""
	var task: Object = _host().get("worker")
	return String(task.call(&"label")) if task != null and bool(_host().call(&"working")) else "none"
