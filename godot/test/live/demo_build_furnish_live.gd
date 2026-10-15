extends "res://test/live/demo_build_dig_live.gd"
## THE FURNISH TAB'S WHOLE LOOP, live (decision 1921; Brendan's rulings of 2026-10-13), on the real village through the
## real input gate: the Entrance placed, a Passage, a Kitchen and a Dormitory painted on level 1 and dug by the mole;
## the Kitchen chosen, the Furnish tab clicked, a hearth and two kitchen benches placed by clicks on the dug floor (one
## turned with R); a bench over the Dormitory and a seat over the hearth refused in words; Confirm all (nothing taken
## from the stores); a resident walks in and fits each piece; "✓ Kitchen ready" over the room and on the tab; then two
## beds in the Dormitory raise the HUD's Beds by two, and every fitted piece stands on whole floor (decision 1914).
## Optional: -- --capture <directory> for its frames.

const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")

## The loop's rooms on level 1 (dry from z 32 m: decision 1912 E8), east and south of the Entrance's landing.
const BIG_KITCHEN_FROM: Vector2i = Vector2i(18, 35)
const BIG_KITCHEN_TO: Vector2i = Vector2i(23, 39)
const DORMITORY_FROM: Vector2i = Vector2i(12, 32)
const DORMITORY_TO: Vector2i = Vector2i(17, 35)
## The landing (4), the Passage (12), the Kitchen (30) and the Dormitory (24).
const ALL_CELLS: int = 70
## Where the cursor stands for each piece (the footprint's middle, rounded north-west: build_furniture.gd).
const HEARTH_AT: Vector2i = Vector2i(19, 35)
const TURNED_BENCH_AT: Vector2i = Vector2i(22, 36)
const BENCH_AT: Vector2i = Vector2i(19, 38)
const WRONG_ROOM_AT: Vector2i = Vector2i(14, 33)
const BEDS_AT: Array[Vector2i] = [Vector2i(12, 32), Vector2i(15, 32)]
## The dig takes 70 cells at 1.5 s each: three times the loop's wait.
const DIG_STEPS: int = 3 * WAIT_STEPS
## The camera a little south of the rooms, so their floors stand clear of the panel; then nearer, for the furniture.
const FURNISH_LOOK: Vector3 = Vector3(17.0, 0.0, 45.0)
const CLOSE_LOOK: Vector3 = Vector3(18.0, 0.0, 43.0)
const CLOSE_PITCH_DEG: float = 52.0
const CLOSE_M: float = 15.0

var _wood_before: int = 0
var _beds_before: int = 0


func _initialize() -> void:
	"""The real village; only the furnish loop's steps."""
	super()
	_steps = [_open_over_the_rooms, _scroll_to.bind("Entrance"), _choose_the_entrance, _place_the_entrance,
		_down_to_level_one, _scroll_to.bind("Passage"), _choose_the_passage, _paint_the_passage,
		_scroll_to.bind("Kitchen"), _choose_the_kitchen, _paint_a_room.bind(BIG_KITCHEN_FROM, BIG_KITCHEN_TO, 3),
		_scroll_to.bind("Dormitory"), _choose_card.bind("Dormitory"), _paint_a_room.bind(DORMITORY_FROM, DORMITORY_TO, 4),
		_confirm_the_rooms, _wait_for_the_digging, _closer_over_the_rooms, _scroll_to.bind("Kitchen"),
		_choose_card.bind("Kitchen"),
		_open_the_furnish_tab.bind("Kitchen bench"), _scroll_to.bind("Hearth"), _choose_card.bind("Hearth"), _hover_the_hearth,
		_place_the_hearth, _scroll_to.bind("Kitchen bench"), _choose_card.bind("Kitchen bench"), _turn_the_bench,
		_place_the_turned_bench, _turn_it_back, _place_the_second_bench, _scroll_to.bind("Kitchen bench"),
		_choose_card.bind("Kitchen bench"), _hover_the_dormitory, _refused_in_the_dormitory, _scroll_to.bind("Seat"),
		_choose_card.bind("Seat"), _refused_over_the_hearth, _put_the_seat_down, _confirm_the_furniture, _wait_for_a_fitter,
		_wait_for_the_fitting, _the_kitchen_is_ready, _tags_apart, _beds_on_the_rooms_tab, _scroll_to.bind("Dormitory"),
		_choose_card.bind("Dormitory"), _open_the_furnish_tab.bind("Bed"), _scroll_to.bind("Bed"), _choose_card.bind("Bed"),
		_place_two_beds, _confirm_the_beds, _wait_for_the_beds, _the_beds_count,
		_after_the_earth.bind(_pieces_on_whole_floor), _close_the_panel]


func _open_over_the_rooms() -> void:
	"""The guide card put away; the camera over the rooms' ground; B opens the panel on the surface."""
	var hide: Button = _village.get("_guide").get("card").call(&"button", "Hide guide")
	if hide != null and hide.is_visible_in_tree():
		_click(_centre(hide))
	var camera: Node = _village.get("_camera")
	camera.call(&"centre_on", FURNISH_LOOK)
	camera.call(&"snap")
	_key(KEY_B)
	_check("B opens the build panel on the surface", bool(_build().call(&"is_open")))


func _choose_card(card_name: String) -> void:
	"""The card called `card_name`, clicked."""
	_click(_card_centre(card_name))
	root.gui_release_focus()
	_check("%s chosen" % card_name, _build().get("panel").call(&"chosen_card") != null
		and String(_build().get("panel").call(&"chosen_card").get("name")) == card_name)


func _paint_a_room(from: Vector2i, to: Vector2i, pending: int) -> void:
	"""A drag paints the chosen room type from `from` to `to`: ✓, with a way in through the Passage."""
	_check("the room's corners are on open ground", not _over_ui(_screen_of(from, 1)) and not _over_ui(_screen_of(to, 1)))
	_drag(_screen_of(from, 1), _screen_of(to, 1))
	var batch: Object = _build().get("batch")
	_check("painted, ✓ (%d pending)" % pending, int(batch.call(&"pending_count")) == pending
		and int(batch.call(&"first_invalid")) < 0, str(batch.call(&"last_dropped")))


func _confirm_the_rooms() -> void:
	"""Confirm all: everything ordered, a mole (or, art-free, anyone) sent, at 4x."""
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("every cell ordered", int(_build().get("works").call(&"waiting")) == ALL_CELLS,
		str(_build().get("works").call(&"waiting")))
	_manager().call(&"set_speed", 4)


func _wait_for_the_digging() -> void:
	"""Until every ordered cell is dug and the mole came out."""
	_wait_until("every room dug", func() -> bool:
		return int(_build().get("works").call(&"waiting")) == 0 and not bool(_build().call(&"digging")),
		"furnish_rooms_dug", DIG_STEPS)


func _closer_over_the_rooms() -> void:
	"""The camera nearer, over the dug rooms (level 1 lies 4.6 m down, so it looks at the ground south of them)."""
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", CLOSE_LOOK, 0.0, CLOSE_PITCH_DEG, CLOSE_M)
	camera.call(&"snap")


func _open_the_furnish_tab(piece: String) -> void:
	"""The Furnish tab, clicked: it lists the chosen room type's own piece, `piece`, and not the other room's."""
	var tabs: Array = _build().get("panel").call(&"controls")[&"tabs"]
	_click(_centre(tabs[1]))
	root.gui_release_focus()
	var names: PackedStringArray = PackedStringArray()
	for card: Object in _build().get("panel").call(&"row_cards"):
		names.append(String(card.get("name")))
	var other: String = "Bed" if piece == "Kitchen bench" else "Kitchen bench"
	_check("the Furnish tab lists the room's pieces", int(_build().get("panel").call(&"shown_tab")) == 1
		and names.has(piece) and not names.has(other), ", ".join(names))


func _floor_point(cell: Vector2i) -> Vector2:
	"""Where `cell`'s middle is on screen on the dug pits' floor (where a piece is picked)."""
	return _screen_of(cell, 1, -Earth.DEPTH_U)


func _hover(cell: Vector2i) -> void:
	"""The pointer moved over `cell` on the pit floor."""
	var motion := InputEventMouseMotion.new()
	motion.position = _floor_point(cell)
	root.push_input(motion)


func _hover_the_hearth() -> void:
	"""The hearth's ghost follows the pointer on the dug Kitchen's floor: "✓ Hearth"."""
	_check("the hearth's spot is on open ground", not _over_ui(_floor_point(HEARTH_AT)), str(_floor_point(HEARTH_AT)))
	_hover(HEARTH_AT)
	_steps.push_front(_hearth_ghost_drawn)


func _hearth_ghost_drawn() -> void:
	"""The ghost and the label say it fits."""
	var words: PackedStringArray = _build().get("furnish").call(&"ghost_words", 1)
	_check("the hearth's ghost says ✓ in words", not words.is_empty() and words[0] == "✓ Hearth", ", ".join(words))
	_check("the label says so", String(_build().call(&"label_text")).ends_with("✓ Can build"),
		String(_build().call(&"label_text")))
	_capture("furnish_hearth_ghost")


func _place_the_hearth() -> void:
	"""A click on the dug floor places it; the card is put down."""
	_click(_floor_point(HEARTH_AT))
	_check("the hearth is placed", _live() == 1, str(_build().get("batch").call(&"last_dropped")))
	_check("the card is put down", not bool(_build().call(&"piece_armed")))


func _live() -> int:
	"""Pending pieces in the batch."""
	return int(_build().get("batch").call(&"furniture").call(&"live_count"))


func _turn_the_bench() -> void:
	"""R turns the armed bench a quarter."""
	_key(KEY_R)
	_check("R turns it", int(_build().call(&"piece_turn")) == 1)


func _place_the_turned_bench() -> void:
	"""Shift+click places it turned, along the Kitchen's east wall, and keeps the card."""
	_hover(TURNED_BENCH_AT)
	_click(_floor_point(TURNED_BENCH_AT), MOUSE_BUTTON_LEFT, true)
	var pieces: Object = _build().get("batch").call(&"furniture")
	_check("the turned bench is placed", _live() == 2 and int(pieces.call(&"turn_of", 1)) == 1,
		str(_build().get("batch").call(&"last_dropped")))
	_check("Shift keeps the card", bool(_build().call(&"piece_armed")))


func _turn_it_back() -> void:
	"""Shift+R turns it back."""
	_key(KEY_R, true)
	_check("Shift+R turns it back", int(_build().call(&"piece_turn")) == 0)


func _place_the_second_bench() -> void:
	"""The second bench along the south of the Kitchen."""
	_hover(BENCH_AT)
	_click(_floor_point(BENCH_AT))
	_check("the second bench is placed", _live() == 3, str(_build().get("batch").call(&"last_dropped")))
	_capture("furnish_kitchen_placed")


func _hover_the_dormitory() -> void:
	"""The bench's ghost over the Dormitory says why not, in words."""
	_hover(WRONG_ROOM_AT)
	_steps.push_front(_wrong_room_drawn)


func _wrong_room_drawn() -> void:
	"""X on the ghost, and in words beside the pointer: the Dormitory does not use a kitchen bench."""
	var words: PackedStringArray = _build().get("furnish").call(&"ghost_words", 1)
	_check("the ghost says X", not words.is_empty() and words[0] == "X Kitchen bench", ", ".join(words))
	var label: String = String(_build().call(&"label_text"))
	_check("the label refuses in words", label.ends_with("X Not possible: Wrong room: Kitchen bench belongs in Kitchen"),
		label)
	_capture("furnish_refused")


func _refused_in_the_dormitory() -> void:
	"""A click there places nothing and says why."""
	_click(_floor_point(WRONG_ROOM_AT))
	_check("a bench in the Dormitory is refused in words", _live() == 3
		and String(_build().get("batch").call(&"last_dropped")).contains("Wrong room: Kitchen bench belongs in Kitchen"),
		str(_build().get("batch").call(&"last_dropped")))


func _refused_over_the_hearth() -> void:
	"""A seat over the hearth: refused, overlapping."""
	_click(_floor_point(HEARTH_AT))
	_check("a seat over the hearth is refused in words", _live() == 3
		and String(_build().get("batch").call(&"last_dropped")).contains("Overlaps a Hearth"),
		str(_build().get("batch").call(&"last_dropped")))


func _put_the_seat_down() -> void:
	"""A right click puts the armed card down."""
	_click(_floor_point(HEARTH_AT), MOUSE_BUTTON_RIGHT)
	_check("a right click puts the seat down", not bool(_build().call(&"piece_armed")))


func _confirm_the_furniture() -> void:
	"""Confirm all: the three pieces wait for a fitter, nothing is taken from the stores."""
	_wood_before = int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood"))
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	var fittings: Object = _build().get("fittings")
	_check("three pieces wait to be fitted", int(fittings.call(&"waiting")) == 3, str(fittings.call(&"waiting")))
	_check("nothing taken from the stores",
		int(_village.get_node(^"/root/EconomySystem").call(&"stock_milli", &"wood")) == _wood_before)


func _wait_for_a_fitter() -> void:
	"""Until a resident stands on a piece fitting it."""
	_wait_until("a resident walks in and fits a piece", func() -> bool:
		var fitter: Object = _build().get("fitter")
		return bool(_build().call(&"fitting")) and int(fitter.call(&"fitting_row")) >= 0, "furnish_fitting", WAIT_STEPS)


func _wait_for_the_fitting() -> void:
	"""Until every piece is fitted and the resident came out."""
	_wait_until("every piece fitted", func() -> bool:
		return int(_build().get("fittings").call(&"waiting")) == 0 and not bool(_build().call(&"fitting")),
		"furnish_kitchen_ready", WAIT_STEPS)


func _the_kitchen_is_ready() -> void:
	"""The room's line over it and on the Furnish tab: "✓ Kitchen ready"; the three pieces drawn."""
	var furnish: Object = _build().get("furnish")
	var lines: String = String(furnish.get("rooms").call(&"lines_text"))
	_check("✓ Kitchen ready", lines.contains("✓ Kitchen ready"), lines.replace("\n", " | "))
	_check("over the room", (furnish.call(&"tags") as PackedStringArray).has("✓ Kitchen ready"))
	_check("and on the Furnish tab", String(_build().get("panel").call(&"info_text")).contains("✓ Kitchen ready"))
	_check("the three pieces are drawn", int(furnish.call(&"pieces_shown")) == 3, str(furnish.call(&"pieces_shown")))


func _beds_on_the_rooms_tab() -> void:
	"""The HUD's Beds before; the Rooms tab, clicked, to choose the Dormitory."""
	_beds_before = _hud_beds()
	var tabs: Array = _build().get("panel").call(&"controls")[&"tabs"]
	_click(_centre(tabs[0]))
	root.gui_release_focus()
	_check("the Rooms tab", int(_build().get("panel").call(&"shown_tab")) == 0)


func _hud_beds() -> int:
	"""What the HUD's Beds cell reads now (demo_hud_model.gd)."""
	var model: Object = _village.get("_counters").get("model")
	var figures: PackedInt64Array = PackedInt64Array()
	figures.resize(int(model.get("CELL_COUNT")))
	model.call(&"read_into", figures)
	return int(figures[int(model.get("CELL_BEDS"))])


func _place_two_beds() -> void:
	"""Two beds in the Dormitory, Shift keeping the card for the second; the second puts it down."""
	for k: int in BEDS_AT.size():
		_hover(BEDS_AT[k])
		_click(_floor_point(BEDS_AT[k]), MOUSE_BUTTON_LEFT, k == 0)
	_check("two beds placed", _live() == 2, str(_build().get("batch").call(&"last_dropped")))
	_check("the card put down after the second", not bool(_build().call(&"piece_armed")))


func _confirm_the_beds() -> void:
	"""Confirm all: the beds wait for a fitter."""
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("two beds wait", int(_build().get("fittings").call(&"waiting")) == 2)


func _wait_for_the_beds() -> void:
	"""Until both beds are fitted."""
	_wait_until("the beds are fitted", func() -> bool:
		return int(_build().get("fittings").call(&"waiting")) == 0 and not bool(_build().call(&"fitting")),
		"furnish_beds", WAIT_STEPS)


func _pieces_on_whole_floor() -> void:
	"""Decision 1914, rule (a): every fitted piece's footprint is drawn at the floor's depth (the rounded walls never
	reach into a cell), and so is every dug cell."""
	var earth: Object = _build().get("dug").get("earth")
	var fittings: Object = _build().get("fittings")
	var footprints: PackedInt32Array = PackedInt32Array()
	for row: int in int(fittings.call(&"count")):
		if int(fittings.call(&"state_of", row)) == Fittings.FITTED:
			footprints.append_array(fittings.call(&"cells_of", row))
	var off: int = int(earth.call(&"cells_off_the_floor", footprints))
	_check("every fitted piece stands on whole floor (rule a)", footprints.size() >= 2 * 16 and off == 0,
		"%d of %d cells off the floor" % [off, footprints.size() >> 1])
	_check_whole_floors()


func _the_beds_count() -> void:
	"""The HUD's Beds rose by the two beds fitted."""
	var beds: int = _hud_beds()
	_check("the HUD's Beds rose by two", beds == _beds_before + 2, "%d then %d" % [_beds_before, beds])
	_check("the Dormitory's line counts them", String(_build().get("furnish").get("rooms").call(&"lines_text"))
		.contains("✓ Dormitory ready"), String(_build().get("furnish").get("rooms").call(&"lines_text")))
