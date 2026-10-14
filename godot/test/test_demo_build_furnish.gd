extends "res://test/framework/test_case.gd"
## The Furnish tab's proof of concept in the demo (decision 1921; Brendan's rulings of 2026-10-13): the confirmed
## furniture's store and the fitter's walk (demo_build_fittings.gd, demo_build_works.gd `path_to_any`), the rooms'
## lines in words (demo_build_rooms.gd), a FIT trip (demo_build_below_task.gd), the drawing (demo_build_furnish.gd),
## and the whole loop through the demo's build panel off-tree: a Kitchen and a Dormitory dug, a hearth and two benches
## (one turned with R) placed by keys, refusals in words, Confirm all, a resident fitting them, "✓ Kitchen ready", and
## the fitted beds counted for the HUD's Beds.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Rooms := preload("res://demo/build_panel/demo_build_rooms.gd")
const Furnish := preload("res://demo/build_panel/demo_build_furnish.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const BelowTask := preload("res://demo/build_panel/demo_build_below_task.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const BuildScript := preload("res://demo/build_panel/demo_build.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const HudModel := preload("res://demo/ui/demo_hud_model.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 32, 32)
const FLOORS: PackedInt32Array = [0, -4608, -9728, -14848, -19968]
const BED: int = 0
const HEARTH: int = 2
const DOOR: int = 3
const PARTITION: int = 4
const BENCH: int = 5
const PATIENT_BED: int = 6
const SEAT: int = 7
const SHELF: int = 8
const DORMITORY: int = 0
const BEDROOM: int = 1
const KITCHEN: int = 2
const DINING: int = 3
const INFIRMARY: int = 5
const CORRIDOR: int = 7
## The Kitchen (6 × 5 cells) and, south of it, the Dormitory (6 × 4), beside the Entrance's landing at (4, 4).
const KITCHEN_BOX: Rect2i = Rect2i(6, 4, 6, 5)
const DORMITORY_BOX: Rect2i = Rect2i(6, 9, 6, 4)

var _nodes: Array[Node] = []
var _works: Works = null
var _fittings: Fittings = null
var _rooms: Rooms = null
var _build: BuildScript = null
var _command: CommandScript = null
var _said: PackedStringArray = PackedStringArray()


func tolerates_outside_tree() -> bool:
	"""The command layer's marks read their transforms off-tree here."""
	return true


func before_each() -> void:
	"""An Entrance at (4, 4); a Kitchen and a Dormitory ordered on level 1 beside its landing, all dug."""
	_works = Works.new()
	_works.configure(BOUNDS)
	_works.order_way_down(0, Vector2i(4, 4))
	_order(KITCHEN_BOX, KITCHEN)
	_order(DORMITORY_BOX, DORMITORY)
	_dig_all()
	_fittings = Fittings.new()
	_rooms = Rooms.new()
	_said.clear()


func after_each() -> void:
	"""Free the nodes (the build's lambdas hold this suite)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_build = null
	_command = null


func _order(box: Rect2i, room_type: int) -> void:
	"""Order every cell of `box` on level 1 as `room_type`."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			cells.append_array(PackedInt32Array([x, z]))
	_works.order_room(1, cells, room_type)


func _dig_all() -> void:
	"""Open every ordered cell on level 1 (the mole's work, done at once)."""
	var ordered: PackedInt32Array = PackedInt32Array()
	_works.cells_into(1, Works.ORDERED, ordered)
	for at: int in range(0, ordered.size(), 2):
		_works.open_cell(1, Vector2i(ordered[at], ordered[at + 1]))


func _fitted(level: int, anchor: Vector2i, turn: int, item: int) -> int:
	"""A piece ordered and fitted at once; its row."""
	assert_true(_fittings.order(level, anchor, turn, item), "ordered")
	_fittings.fit(_fittings.count() - 1)
	return _fittings.count() - 1


func _line(room_type: int) -> String:
	"""The level-1 line of the first room of `room_type`, recounted."""
	_rooms.refresh(_works, _fittings, 1)
	for room: int in _rooms.count():
		if _rooms.type_of(room) == room_type:
			return _rooms.line_of(room)
	return ""


# --- the works' walk to the nearest of several goals ---------------------------------------------------------------

func test_the_walk_finds_the_nearest_of_several_goals() -> void:
	"""path_to_any: the nearer goal, its path from the start; an unreachable goal set: {}; the start itself is not a
	goal it walks to."""
	var from: Vector3i = Vector3i(1, 4, 4)
	var found: Dictionary = _works.path_to_any(from, {Vector3i(1, 11, 12): true, Vector3i(1, 7, 4): true})
	assert_equal(found["goal"], Vector3i(1, 7, 4), "the nearer")
	assert_equal(found["path"], PackedVector3Array([Vector3(1, 4, 4), Vector3(1, 5, 4), Vector3(1, 6, 4),
		Vector3(1, 7, 4)]), "walked cell by cell")
	assert_equal(_works.path_to_any(from, {Vector3i(1, 30, 30): true}), {}, "earth: none")
	assert_equal(_works.path_to_any(from, {from: true}), {}, "the start is no walk")
	assert_equal(_works.path_to(from, Vector3i(1, 6, 4)).size(), 3, "path_to still walks to one goal")


# --- the store -----------------------------------------------------------------------------------------------------

func test_the_store_orders_fits_and_reads_its_pieces() -> void:
	"""order (underground levels and real items only), fit (only a waiting piece), the reads, and the revision."""
	var revision: int = _fittings.revision
	assert_false(_fittings.order(0, Vector2i.ZERO, 0, BED), "not on the surface")
	assert_false(_fittings.order(5, Vector2i.ZERO, 0, BED), "not on Overview")
	assert_false(_fittings.order(1, Vector2i.ZERO, 0, 40), "no such item")
	assert_true(_fittings.order(1, Vector2i(6, 4), 5, BENCH), "a bench")
	assert_true(_fittings.revision > revision, "a change moves the revision")
	assert_equal([_fittings.count(), _fittings.waiting(), _fittings.turn_of(0)], [1, 1, 1], "waiting, turn wrapped")
	assert_equal(_fittings.state_of(0), Fittings.ORDERED, "ordered")
	assert_true(_fittings.fit(0), "fitted")
	assert_false(_fittings.fit(0) or _fittings.fit(3) or _fittings.fit(-1), "only a waiting piece fits")
	assert_equal([_fittings.waiting(), _fittings.state_of(0)], [0, Fittings.FITTED], "fitted")
	assert_equal([_fittings.level_of(0), _fittings.anchor_of(0), _fittings.item_of(0)], [1, Vector2i(6, 4), BENCH],
		"read back")
	assert_equal(_fittings.cells_of(0).size(), 16, "a turned bench's 8 cells")
	assert_equal(_fittings.edges_of(0), [] as Array[Vector3i], "no edges")


func test_occupants_answer_the_batchs_overlap_reads() -> void:
	"""occupant: the floor piece on a cell (a turned footprint); edge_occupant: the door on an edge; other levels free."""
	_fittings.order(1, Vector2i(6, 4), 1, BENCH)
	_fittings.order(1, Vector2i(6, 9), 0, DOOR)
	assert_equal(_fittings.occupant(1, Vector2i(7, 7)), BENCH, "inside the turned bench (2 × 4)")
	assert_equal(_fittings.occupant(1, Vector2i(8, 4)), -1, "beside it")
	assert_equal(_fittings.occupant(2, Vector2i(6, 4)), -1, "another level")
	assert_equal(_fittings.occupant(1, Vector2i(6, 9)), -1, "a door takes no floor")
	assert_equal(_fittings.edge_occupant(1, Vector3i(Furniture.EDGE_ACROSS, 7, 9)), DOOR, "the door's edge")
	assert_equal(_fittings.edge_occupant(1, Vector3i(Furniture.EDGE_ACROSS, 8, 9)), -1, "past it")
	assert_equal(_fittings.edge_occupant(2, Vector3i(Furniture.EDGE_ACROSS, 7, 9)), -1, "another level")
	assert_equal(_fittings.fitted_count(BENCH), 0, "none fitted yet")
	_fittings.fit(0)
	assert_equal(_fittings.fitted_count(BENCH), 1, "one fitted")


func test_a_cell_two_waiting_pieces_share_goes_to_the_lower_row() -> void:
	"""A bed and a door beside it share a cell to stand on: the earlier order is fitted first."""
	_fittings.order(1, Vector2i(6, 9), 0, BED)
	_fittings.order(1, Vector2i(6, 9), 0, DOOR)
	assert_equal(_fittings.next_fit(_works, Vector3i(1, 6, 9))["row"], 0, "the bed, ordered first")


func test_the_fitter_walks_to_the_nearest_piece_waiting() -> void:
	"""next_fit: the nearest waiting piece's cell from where the fitter stands; a door's side cells; none: {}."""
	assert_equal(_fittings.next_fit(_works, Vector3i(1, 4, 4)), {}, "nothing waits")
	_fittings.order(1, Vector2i(10, 11), 0, BED)
	_fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	var found: Dictionary = _fittings.next_fit(_works, Vector3i(1, 4, 4))
	assert_equal([found["row"], found["goal"]], [1, Vector3i(1, 6, 4)], "the hearth is nearer")
	_fittings.fit(1)
	found = _fittings.next_fit(_works, Vector3i(1, 4, 4))
	assert_equal(found["row"], 0, "then the bed")
	var standing: Dictionary = _fittings.next_fit(_works, Vector3i(1, 10, 11))
	assert_equal(standing["path"], PackedVector3Array([Vector3(1, 10, 11)]), "standing on it: no walk")
	_fittings.fit(0)
	_fittings.order(1, Vector2i(6, 9), 0, DOOR)
	assert_equal(_fittings.next_fit(_works, Vector3i(1, 4, 4))["goal"], Vector3i(1, 6, 8), "a door's side cell")
	_fittings.order(1, Vector2i(30, 30), 0, BED)
	_fittings.fit(2)
	assert_equal(_fittings.next_fit(_works, Vector3i(1, 4, 4)), {}, "one in earth cannot be reached")


# --- the rooms' lines ----------------------------------------------------------------------------------------------

func test_a_kitchen_reads_being_dug_then_its_needs_then_ready() -> void:
	"""Brendan's example: "Kitchen: needs a hearth" → "✓ Kitchen ready", once each piece is fitted."""
	var waiting: Works = Works.new()
	waiting.configure(BOUNDS)
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	waiting.order_room(1, cells, KITCHEN)
	waiting.open_cell(1, Vector2i(0, 0))
	_rooms.refresh(waiting, _fittings, 1)
	assert_equal(_rooms.line_of(0), "! Kitchen: Being dug (3 cells to go)", "being dug")
	waiting.open_cell(1, Vector2i(1, 0))
	waiting.open_cell(1, Vector2i(0, 1))
	_rooms.refresh(waiting, _fittings, 1)
	assert_equal(_rooms.line_of(0), "! Kitchen: Being dug (1 cell to go)", "one cell to go")
	assert_false(_rooms.is_ready(0), "not ready")
	assert_equal(_line(KITCHEN), "! Kitchen: Needs 1 hearth and 1 kitchen bench", "bare")
	_fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	assert_equal(_line(KITCHEN), "! Kitchen: Needs 1 hearth and 1 kitchen bench", "ordered is not fitted")
	_fittings.fit(0)
	assert_equal(_line(KITCHEN), "! Kitchen: Needs 1 kitchen bench", "a hearth fitted")
	_fitted(1, Vector2i(10, 4), 1, BENCH)
	assert_equal(_line(KITCHEN), "✓ Kitchen ready", "ready")
	assert_true(_rooms.is_ready(0), "ready")


func test_area_maximum_and_counts_are_the_catalogs() -> void:
	"""Dormitory: 12 cells a bed (24 cells hold 2, not 3); a Bedroom takes at most 1 bed; a Dining room 4 seats."""
	assert_equal(_line(DORMITORY), "! Dormitory: Needs 1 bed", "no bed")
	for x: int in [6, 8, 10]:
		_fitted(1, Vector2i(x, 9), 0, BED)
	assert_equal(_line(DORMITORY), "! Dormitory: Too small: Dormitory needs at least 36 cells (has 24)", "3 beds in 24 cells")
	assert_equal(Rooms.beds(_fittings), 3, "three beds fitted")
	_works = Works.new()
	_works.configure(BOUNDS)
	_order(DORMITORY_BOX, DINING)
	_dig_all()
	_fitted(1, Vector2i(6, 9), 0, SEAT)
	assert_equal(_line(DINING), "! Dining room: Needs 4 seats (has 1)", "seats counted")
	assert_equal(Rooms.piece_words(SHELF, 2, 0), "2 shelves (has 0)", "a plural in words")


func test_a_bedroom_needs_walls_or_a_door_where_it_meets_another_room() -> void:
	"""PARTITIONED_ENCLOSURE: a Bedroom against the Kitchen needs partitions or doors along that edge; earth is wall;
	more than one bed is too many."""
	_works = Works.new()
	_works.configure(BOUNDS)
	_works.order_way_down(0, Vector2i(4, 4))
	_order(KITCHEN_BOX, KITCHEN)
	_order(DORMITORY_BOX, BEDROOM)
	_dig_all()
	_fitted(1, Vector2i(6, 11), 0, BED)
	assert_equal(_line(BEDROOM), "! Bedroom: Needs walls, partitions or doors where it meets the Kitchen", "open")
	_fitted(1, Vector2i(6, 9), 0, DOOR)
	_fitted(1, Vector2i(8, 9), 0, PARTITION)
	assert_equal(_line(BEDROOM), "! Bedroom: Needs walls, partitions or doors where it meets the Kitchen", "a gap")
	_fitted(1, Vector2i(10, 9), 0, PARTITION)
	assert_equal(_line(BEDROOM), "✓ Bedroom ready", "walled off: a door and two partitions")
	_fitted(1, Vector2i(9, 11), 0, BED)
	assert_equal(_line(BEDROOM), "! Bedroom: Has 2 beds: a Bedroom takes at most 1", "too many")


func test_a_bedroom_beside_a_landing_names_it() -> void:
	"""A Bedroom whose cells touch a way's landing must close that side too."""
	_works = Works.new()
	_works.configure(BOUNDS)
	_works.order_way_down(0, Vector2i(4, 4))
	_order(Rect2i(6, 4, 6, 4), BEDROOM)
	_dig_all()
	_fitted(1, Vector2i(8, 4), 0, BED)
	assert_equal(_line(BEDROOM), "! Bedroom: Needs walls, partitions or doors where it meets the landing", "landing")
	var batch: Batch = _batch()
	assert_equal(batch.place_piece(1, Vector2i(6, 4), 3, DOOR), Validity.KIND_CAN_BUILD, "a door may stand there")
	assert_equal(batch.confirm_all(Callable(), Callable(), _submit_piece), PackedInt32Array([1, 0]), "ordered")
	_fittings.fit(_fittings.count() - 1)
	assert_equal(_line(BEDROOM), "✓ Bedroom ready", "a door onto the landing")


func _submit_piece(level: int, anchor: Vector2i, turn: int, item: int) -> Dictionary:
	"""The demo's route for a piece: into this suite's store."""
	return {"ok": _fittings.order(level, anchor, turn, item)}


func test_an_infirmary_is_heated_by_a_hearth_joined_to_it() -> void:
	"""HEATED_COMPONENT: no hearth, cold; a hearth in the Kitchen joined to it, warm; a partition along the whole join,
	cold again; a door passes the heat."""
	_works = Works.new()
	_works.configure(BOUNDS)
	_order(KITCHEN_BOX, KITCHEN)
	_order(DORMITORY_BOX, INFIRMARY)
	_dig_all()
	_fitted(1, Vector2i(6, 11), 0, PATIENT_BED)
	_fitted(1, Vector2i(10, 11), 0, SHELF)
	assert_equal(_line(INFIRMARY), "! Infirmary: Needs heat: a hearth in it or in a room joined to it", "cold")
	_fitted(1, Vector2i(6, 4), 0, HEARTH)
	assert_equal(_line(INFIRMARY), "✓ Infirmary ready", "the Kitchen's hearth")
	_fitted(1, Vector2i(6, 9), 0, PARTITION)
	_fitted(1, Vector2i(8, 9), 0, PARTITION)
	_fitted(1, Vector2i(10, 9), 0, DOOR)
	assert_equal(_line(INFIRMARY), "✓ Infirmary ready", "a door keeps the heat")
	_fittings = Fittings.new()
	_fitted(1, Vector2i(6, 11), 0, PATIENT_BED)
	_fitted(1, Vector2i(10, 11), 0, SHELF)
	_fitted(1, Vector2i(6, 4), 0, HEARTH)
	for x: int in [6, 8, 10]:
		_fitted(1, Vector2i(x, 9), 0, PARTITION)
	assert_equal(_line(INFIRMARY), "! Infirmary: Needs heat: a hearth in it or in a room joined to it",
		"partitions along the whole join: cold")


func test_one_hearths_heat_goes_to_rooms_in_order_whole_rooms_only() -> void:
	"""480 cells a hearth, in room order: a joined room too big for what is left is not heated."""
	_works = Works.new()
	_works.configure(Rect2i(0, 0, 64, 64))
	_order(Rect2i(0, 0, 24, 20), KITCHEN)
	_order(Rect2i(0, 20, 6, 4), INFIRMARY)
	_dig_all()
	_fitted(1, Vector2i(0, 0), 0, HEARTH)
	_rooms.refresh(_works, _fittings, 1)
	assert_equal(_rooms.cells_of(0), 480, "the Kitchen takes all 480")
	assert_true(_rooms.heated(0), "the Kitchen is heated")
	assert_false(_rooms.heated(1), "nothing left for the Infirmary")
	_fitted(1, Vector2i(4, 0), 0, HEARTH)
	_rooms.refresh(_works, _fittings, 1)
	assert_true(_rooms.heated(1), "a second hearth heats it")


func test_the_rooms_are_recounted_only_on_a_change() -> void:
	"""refresh: true on a change of works, furniture or level; false on a still frame; the reads."""
	assert_true(_rooms.refresh(_works, _fittings, 1), "first read")
	assert_false(_rooms.refresh(_works, _fittings, 1), "still")
	assert_equal(_rooms.count(), 2, "Kitchen and Dormitory")
	assert_equal(_rooms.read_level(), 1, "level 1")
	assert_equal(_rooms.room_at(Vector2i(7, 10)), 1, "the Dormitory")
	assert_equal(_rooms.room_at(Vector2i(4, 4)), -1, "a landing is no room")
	assert_equal(_rooms.box_of(0), KITCHEN_BOX, "its box")
	assert_equal(_rooms.lines_text(), "! Kitchen: Needs 1 hearth and 1 kitchen bench\n! Dormitory: Needs 1 bed", "words")
	_fittings.order(1, Vector2i(6, 9), 0, BED)
	assert_true(_rooms.refresh(_works, _fittings, 1), "a piece ordered")
	assert_true(_rooms.refresh(_works, _fittings, 0), "the surface")
	assert_equal(_rooms.count(), 0, "no rooms on the surface")


# --- the trip that fits -----------------------------------------------------------------------------------------------

func test_a_fit_trip_fits_each_piece_after_a_short_wait_and_comes_out() -> void:
	"""MODE_FIT: in at the landing, to the nearest waiting piece, FIT_SECONDS on it, the piece fitted; then the next;
	then back and out. It never reads as digging."""
	_fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	_fittings.order(1, Vector2i(6, 9), 0, BED)
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_FIT, Vector3i.ZERO, "Wenna")
	trip.use_fittings(_fittings)
	assert_equal(trip.label(), "Going to the Entrance to fit furniture", "on the way")
	var walker: _Walker = _Walker.new()
	trip.arrived(walker)
	for frame: int in 30:
		trip.step(walker, 0.1)
		if trip.stage == BelowTask.STAGE_DIG:
			break
	assert_equal(trip.fitting_row(), 0, "fitting the hearth")
	assert_equal([trip.digging_cell(), trip.dig_share()], [Vector3i(-1, 0, 0), 0.0], "never digging")
	assert_equal(trip.label(), "Fitting the furniture (2 pieces waiting)", "says so")
	trip.step(walker, BelowTask.FIT_SECONDS / 2.0)
	assert_equal(trip.fitted, 0, "not yet")
	assert_equal(trip.dig_share(), 0.0, "half fitted is no dig")
	trip.step(walker, BelowTask.FIT_SECONDS)
	assert_equal([trip.fitted, _fittings.state_of(0)], [1, Fittings.FITTED], "the hearth appears")
	for frame: int in 400:
		if not trip.step(walker, 0.1):
			break
	assert_equal([trip.fitted, _fittings.waiting()], [2, 0], "the bed too")
	assert_false(walker.indoors or figure.visible, "and out")
	assert_equal(trip.fitting_row(), -1, "fitting nothing")


func test_a_fit_trip_with_no_store_comes_out_at_once() -> void:
	"""A FIT trip handed no store finds nothing to fit."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_FIT, Vector3i.ZERO, "Wenna")
	var walker: _Walker = _Walker.new()
	trip.arrived(walker)
	assert_true(trip.step(walker, 0.1), "nothing to fit: heads out")
	assert_false(trip.step(walker, 0.1), "and is out")
	assert_equal(trip.label(), "Fitting the furniture (0 pieces waiting)", "nothing waits")


# --- the drawing ----------------------------------------------------------------------------------------------------

func _view(batch: Batch) -> Furnish:
	"""A furniture view over `batch`, the works and the store."""
	var view: Furnish = Furnish.new()
	_nodes.append(view)
	view.configure(batch, _works, _fittings, FLOORS, Vector2i.ZERO, BOUNDS)
	return view


func _batch() -> Batch:
	"""A batch whose furniture reads this suite's works and store."""
	var batch: Batch = Batch.new()
	batch.configure(BuildCatalog.new(), BOUNDS, 4096)
	batch.bind_furniture_host(_room_at, _fittings.occupant, _fittings.edge_occupant, _fittings.row_at)
	return batch


func _room_at(level: int, cell: Vector2i) -> int:
	"""The demo's room reader, over this suite's works."""
	var state: int = _works.state(level, cell)
	if state != Works.OPEN:
		return Furniture.ROOM_WAITING if state == Works.ORDERED else Furniture.ROOM_EARTH
	var type: int = _works.type_of(level, cell)
	return Furniture.ROOM_BARE if type == Works.TYPE_NONE or _works.on_way(level, cell) else type


func test_the_cursor_ghost_says_its_validity_in_words() -> void:
	"""The armed piece under the cursor: "✓ Hearth"; over the Dormitory, X in words; a door names its side."""
	var batch: Batch = _batch()
	var view: Furnish = _view(batch)
	view.refresh(1, HEARTH, Vector2i(7, 4), 0, -1)
	assert_equal(view.ghost_words(1)[0], "✓ Hearth", "fits")
	view.refresh(1, BENCH, Vector2i(7, 9), 0, -1)
	assert_equal(view.ghost_words(1)[0], "X Kitchen bench", "the room does not use it: its glyph")
	view.refresh(1, DOOR, Vector2i(6, 9), 0, -1)
	assert_equal(view.ghost_words(1)[0], "✓ Door, north side", "a door's side")
	view.refresh(-1, DOOR, Vector2i(6, 9), 0, -1)
	assert_equal(view.ghost_words(1).size(), 0, "no level shown: nothing")


func test_a_new_pending_piece_redraws_and_a_door_turned_runs_south() -> void:
	"""A piece placed after a frame is drawn on the next; a door on an east side covers its cell and the one south."""
	var batch: Batch = _batch()
	var view: Furnish = _view(batch)
	view.refresh(1, -1, Vector2i.ZERO, 0, -1)
	batch.place_piece(1, Vector2i(6, 9), 0, BED)
	view.refresh(1, -1, Vector2i.ZERO, 0, -1)
	assert_true(view.ghost_words(1).has("✓ Bed"), ", ".join(view.ghost_words(1)))
	assert_equal(Furnish.drawn_cells(_fittings.shapes, DOOR, 1, Vector2i(3, 3)), PackedInt32Array([3, 3, 3, 4]), "east")
	assert_equal(Furnish.drawn_cells(_fittings.shapes, DOOR, 2, Vector2i(3, 3)), PackedInt32Array([3, 3, 4, 3]), "south")


func test_a_rooms_east_edge_is_the_furnitures() -> void:
	"""The rooms' cell edges are build_furniture.gd's, side by side."""
	for side: int in 4:
		assert_equal(Rooms.edge_of(Vector2i(3, 3), side), Furniture.edges_of(side, Vector2i(3, 3))[0], "side %d" % side)


func test_a_way_downs_cells_are_no_room_floor() -> void:
	"""A way down dug into the Kitchen: its cells read bare, where it stands and where it lands."""
	_mount()
	_build.works.order_way_down(1, Vector2i(8, 6))
	assert_equal(_build.room_at(1, Vector2i(8, 6)), Furniture.ROOM_BARE, "where it stands")
	assert_equal(_build.room_at(1, Vector2i(10, 6)), KITCHEN, "beside it")
	assert_true(_build.works.on_way(2, Vector2i(9, 7)), "where it lands")
	assert_false(_build.works.on_way(0, Vector2i(4, 4)), "the surface's Entrance is no floor")


func test_pending_waiting_and_fitted_pieces_and_the_room_lines_are_drawn() -> void:
	"""A pending bed's ghost, a waiting hearth outlined with the waiting words, "Fitting" over the one being fitted, a
	fitted bench as a named block, and each room's line; nothing rebuilt on a still frame."""
	var batch: Batch = _batch()
	batch.place_piece(1, Vector2i(6, 9), 0, BED)
	_fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	_fittings.order(1, Vector2i(6, 7), 0, SEAT)
	_fitted(1, Vector2i(10, 4), 1, BENCH)
	var view: Furnish = _view(batch)
	view.refresh(1, -1, Vector2i.ZERO, 0, -1)
	assert_true(view.ghost_words(1).has("✓ Bed"), ", ".join(view.ghost_words(1)))
	var words: PackedStringArray = view.tags()
	assert_true(words.has("Waiting to be fitted: 2 pieces") and words.has("Kitchen bench"), ", ".join(words))
	assert_true(words.has("! Kitchen: Needs 1 hearth") and words.has("! Dormitory: Needs 1 bed"), ", ".join(words))
	assert_equal(view.pieces_shown(), 1, "the fitted bench drawn")
	view.refresh(1, -1, Vector2i.ZERO, 0, -1)
	assert_equal(view.rebuilds, 1, "a still frame rebuilds nothing")
	view.refresh(1, -1, Vector2i.ZERO, 0, 0)
	assert_true(view.tags().has("Fitting") and view.tags().has("Waiting to be fitted: 1 piece"), ", ".join(view.tags()))
	var shown: Array[Label3D] = []
	view.shown_tags(shown)
	assert_equal(shown.size(), view.tags().size(), "every shown tag handed to the spacer")
	view.refresh(-1, -1, Vector2i.ZERO, 0, -1)
	assert_equal([view.pieces_shown(), view.tags().size()], [0, 0], "no level: nothing")


func test_a_fitted_piece_stands_turned_in_its_footprint_on_the_pit_floor() -> void:
	"""placed: a turned bench's middle on the pit floor, turned a quarter; a door on its edges' middle, along z on a
	west side; a staged model laid along the long side and shrunk to fit."""
	var view: Furnish = _view(_batch())
	var bench: int = _fitted(1, Vector2i(10, 4), 1, BENCH)
	var at: Transform3D = view.placed(bench, 1)
	assert_true(at.origin.is_equal_approx(Vector3(11.0, -5.5, 6.0)), str(at.origin))
	assert_true((at.basis * Vector3.RIGHT).is_equal_approx(Vector3(0, 0, 1)), "turned a quarter: %s" % (at.basis * Vector3.RIGHT))
	var door: int = _fitted(1, Vector2i(6, 9), 3, DOOR)
	var door_at: Transform3D = view.placed(door, 1)
	assert_true(door_at.origin.is_equal_approx(Vector3(6.0, -5.5, 10.0)), str(door_at.origin))
	assert_true((door_at.basis * Vector3.RIGHT).is_equal_approx(Vector3(0, 0, -1)), "along z")
	var fit: Basis = Furnish._fitted_basis(AABB(Vector3(-0.5, 0, -2.5), Vector3(1.0, 1.0, 5.0)), Vector2i(4, 2), 0)
	var drawn: AABB = Transform3D(fit, Vector3.ZERO) * AABB(Vector3(-0.5, 0, -2.5), Vector3(1.0, 1.0, 5.0))
	assert_true(drawn.size.x > drawn.size.z, "laid along the footprint's long side: %s" % drawn.size)
	assert_true(drawn.size.x <= 4.0 - 2.0 * Furnish.BLOCK_INSET_M + 0.001, "shrunk inside: %s" % drawn.size)
	assert_true(Furnish.piece_words(PARTITION, 2) == "Partition, south side", "a partition's side")
	assert_false(view.staged(HEARTH), "nothing staged here: a block")
	assert_true(view.mesh_of(DOOR) != null and view.mesh_of(DOOR) == view.mesh_of(DOOR), "made once")


# --- the loop through the demo's build panel ----------------------------------------------------------------------

func _mount(entrance: bool = true) -> Node:
	"""A placeholder cast with a mole first, its command layer, and the build panel over them; the suite's works dug
	into the panel's own (with its Entrance unless `entrance` is false). Returns the cast."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	_command = CommandScript.new()
	_nodes.append(_command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	_command.configure(cast, camera, null)
	_build = BuildScript.new()
	_nodes.append(_build)
	_build.configure(_command.tunnels(), null, camera, func() -> bool: return false,
		func(text: String) -> void: _said.append(text), [] as Array[Node], null)
	_command.set_build_hooks(_build.takes_before_gui, _build.handle_input)
	_build.bind_cast(cast, func() -> PackedInt32Array: return PackedInt32Array())
	if entrance:
		_build.works.order_way_down(0, Vector2i(4, 4))
	var ordered: PackedInt32Array = PackedInt32Array()
	_works.cells_into(1, Works.OPEN, ordered)
	for at: int in range(0, ordered.size(), 2):
		var cell: Vector2i = Vector2i(ordered[at], ordered[at + 1])
		_build.works.order_room(1, PackedInt32Array([cell.x, cell.y]), _works.type_of(1, cell))
		_build.works.open_cell(1, cell)
	return cast


func _press(code: Key, shift: bool = false) -> bool:
	"""A key through the command layer the way the village routes it."""
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.pressed = true
	return _command.take_before_gui(event) or _command.handle_input(event)


func _choose(card_name: String) -> void:
	"""Choose the row's card called `card_name`."""
	var cards: Array[BuildCatalog.Card] = _build.panel.row_cards()
	for k: int in cards.size():
		if cards[k].name == card_name:
			_build.panel.choose_card(k)
			return
	fail("no card %s" % card_name)


func _place_at(cursor: Vector2i, keep: bool = false) -> bool:
	"""Enter with the cursor at `cursor` on level 1."""
	_build.paint.set_cursor(cursor, 1, -1)
	return _press(KEY_ENTER, keep)


func test_the_furnish_loop_places_fits_and_readies_the_kitchen() -> void:
	"""Brendan's rulings: a hearth and two benches (one turned with R) placed by keys in the dug Kitchen, a bench
	refused in the Dormitory and a seat over the hearth, Confirm all (nothing taken), a resident fits them, "✓ Kitchen
	ready"; beds placed in the Dormitory raise the HUD's Beds."""
	var cast: Node = _mount()
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_choose("Kitchen")
	assert_true(_build.panel.select_tab(BuildCatalog.TAB_FURNISH), "Furnish opens")
	_choose("Hearth")
	assert_true(_build.piece_armed(), "the hearth armed")
	assert_true(_place_at(Vector2i(7, 4)), "Enter places it")
	assert_equal(_said[-1], "✓ Hearth placed", _said[-1])
	assert_false(_build.piece_armed(), "the card put down")
	_place_two_benches()
	_choose("Seat")
	_place_at(Vector2i(7, 5))
	assert_true(_said[-1].contains("Overlaps a Hearth"), _said[-1])
	assert_equal(_build.batch.furniture().live_count(), 3, "three placed, two refused")
	_confirm_and_fit(cast)
	assert_true(_build.furnish.rooms.lines_text().contains("✓ Kitchen ready"), _build.furnish.rooms.lines_text())
	assert_true(_build.panel.info_text().contains("✓ Kitchen ready"), "on the Furnish tab: %s" % _build.panel.info_text())
	_beds_raise_the_hud(cast)


func _place_two_benches() -> void:
	"""The Kitchen bench card: R turns it, the label says so and its validity at the cursor, Shift+Enter places it and
	keeps the card, Shift+R turns it back, a second placed; a third over the Dormitory is refused in words."""
	_choose("Kitchen bench")
	assert_true(_press(KEY_R), "R turns it")
	assert_equal(_build.piece_turn(), 1, "a quarter turn")
	_build.paint.set_cursor(Vector2i(10, 5), 1, -1)
	_build._process(0.0)
	assert_true(_build.label_text().begins_with("Place Kitchen bench, turned once"), _build.label_text())
	assert_true(_build.label_text().ends_with("✓ Can build"), "at the cursor: %s" % _build.label_text())
	_place_at(Vector2i(10, 5), true)
	assert_true(_build.piece_armed(), "Shift keeps it")
	_press(KEY_R, true)
	assert_equal(_build.piece_turn(), 0, "Shift+R turns it back")
	_place_at(Vector2i(7, 7), true)
	_place_at(Vector2i(7, 10), true)
	assert_true(_said[-1].ends_with("Wrong room: Kitchen bench belongs in Kitchen"), _said[-1])


func _confirm_and_fit(cast: Node) -> void:
	"""Confirm all, nothing taken from the stores; the resident sent fits every piece."""
	var wood: int = EconomySystem.stock_milli(&"wood")
	_build.confirm_all()
	assert_equal(EconomySystem.stock_milli(&"wood"), wood, "free for now")
	assert_equal(_build.fittings.waiting(), 3, "three wait")
	assert_true(_build.fitting(), "a resident sent: %s" % ", ".join(_said))
	assert_true(_said.has("%s goes to the Entrance to fit the furniture" % _build._name_of(1)), "not the mole")
	var brain: Object = (cast.call(&"actor", 1) as Node).get(&"brain")
	_build.fitter.arrived(brain)
	for frame: int in 4000:
		if not _build.fitter.step(brain, 0.1):
			break
	brain.call(&"release")
	assert_equal(_build.fittings.waiting(), 0, "every piece fitted")
	_build._process(0.0)


func _beds_raise_the_hud(cast: Node) -> void:
	"""Two beds in the Dormitory, confirmed and fitted, count in the HUD model's Beds."""
	var model: HudModel = HudModel.new()
	model.beds = func() -> int: return 3
	model.built_beds = _build.built_beds
	var figures: PackedInt64Array = PackedInt64Array()
	figures.resize(HudModel.CELL_COUNT)
	model.read_into(figures)
	assert_equal(figures[HudModel.CELL_BEDS], 3, "the burrow homes' 3")
	_build.panel.select_tab(BuildCatalog.TAB_ROOMS)
	_choose("Dormitory")
	_build.panel.select_tab(BuildCatalog.TAB_FURNISH)
	_choose("Bed")
	_place_at(Vector2i(6, 9), true)
	_place_at(Vector2i(9, 11), true)
	_confirm_and_fit_more(cast)
	model.read_into(figures)
	assert_equal(figures[HudModel.CELL_BEDS], 5, "and the two fitted beds")
	assert_equal(model.ledger_line(HudModel.CELL_BEDS, 5), "Beds: 5 in the burrow homes · 2 built", "the ledger")


func _confirm_and_fit_more(cast: Node) -> void:
	"""Confirm all again and let the resident sent fit them."""
	_build.confirm_all()
	var brain: Object = (cast.call(&"actor", 1) as Node).get(&"brain")
	_build.fitter.arrived(brain)
	for frame: int in 4000:
		if not _build.fitter.step(brain, 0.1):
			break
	brain.call(&"release")
	assert_equal(_build.built_beds(), 2, "two beds fitted")


func test_nobody_is_sent_with_nothing_waiting_or_no_entrance() -> void:
	"""The fitter is sent only while pieces wait and an Entrance exists; a piece confirmed with nobody to send waits
	and says so once."""
	_mount()
	assert_false(_build._send_fitter(), "nothing waits")
	_build.fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	var selected: PackedInt32Array = PackedInt32Array([2])
	_build.bind_cast(_nodes[0], func() -> PackedInt32Array: return selected)
	assert_true(_build._send_fitter(), "sent")
	assert_equal(_build.fitter.label(), "Going to the Entrance to fit furniture", "on the way")
	assert_equal(_said[-1], "%s goes to the Entrance to fit the furniture" % _build._name_of(2), "the selected one")
	assert_false(_build._send_fitter(), "one fitter at a time")
	assert_equal(_build.rotate_piece(-1), 3, "turns wrap")
	assert_false(_build.put_down_piece(), "nothing armed to put down")
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_choose("Kitchen")
	_build.panel.select_tab(BuildCatalog.TAB_FURNISH)
	_choose("Hearth")
	assert_true(_build.put_down_piece() and not _build.piece_armed(), "put down")


func test_no_entrance_sends_nobody() -> void:
	"""With no Entrance, pieces wait and nobody is sent."""
	_mount(false)
	_build.fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	assert_false(_build._send_fitter(), "no Entrance")
	assert_false(_build.fitting(), "nobody")


func test_a_cut_off_or_unstaffed_piece_says_why_once_and_the_tick_sends_again() -> void:
	"""A piece no Entrance reaches: said once, nobody sent; with everyone below on a visit: "Nobody can fit", once;
	once someone is free, the tick sends a fitter again within SEND_EVERY_S."""
	var cast: Node = _mount()
	_build.fittings.order(1, Vector2i(30, 30), 0, BED)
	assert_false(_build._send_fitter(), "cut off")
	assert_false(_build._send_fitter(), "again")
	assert_equal(_said.count(BuildScript.FIT_CUT_OFF), 1, "said once")
	_build.fittings.fit(0)
	_build.fittings.order(1, Vector2i(6, 4), 0, HEARTH)
	var everyone: PackedInt32Array = PackedInt32Array(range(int(cast.call(&"actor_count"))))
	_build.bind_cast(cast, func() -> PackedInt32Array: return everyone)
	_build.bar.choose(1)
	assert_true(_build.send_visitors(Vector2i(6, 5)) > 0, "everyone goes down to look")
	assert_false(_build._send_fitter() or _build._send_fitter(), "nobody free")
	assert_equal(_said.count(BuildScript.NO_FITTER), 1, "said once")
	(cast.call(&"actor", 3) as Node).get(&"brain").call(&"release")
	_build._tick_works(BuildScript.SEND_EVERY_S + 0.1)
	assert_true(_build.fitting(), "the tick sends the free one")


func test_the_label_follows_the_dig_and_the_level() -> void:
	"""H1: the pointer's words over cells still waiting read "Not dug yet"; once dug, ✓; on another level, its own."""
	_mount()
	_build.works.order_room(1, PackedInt32Array([14, 4, 15, 4, 14, 5, 15, 5]), KITCHEN)
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_choose("Kitchen")
	_build.panel.select_tab(BuildCatalog.TAB_FURNISH)
	_choose("Seat")
	_build.paint.set_cursor(Vector2i(14, 4), 1, -1)
	_build._process(0.0)
	assert_true(_build.label_text().ends_with(Validity.not_dug()), _build.label_text())
	for cell: Vector2i in [Vector2i(14, 4), Vector2i(15, 4), Vector2i(14, 5), Vector2i(15, 5)]:
		_build.works.open_cell(1, cell)
	_build._process(0.0)
	assert_true(_build.label_text().ends_with("✓ Can build"), "dug: %s" % _build.label_text())
	_press(KEY_PAGEDOWN)
	_build._process(0.0)
	assert_true(_build.piece_armed() and _build.label_text().ends_with(Validity.not_on_room()),
		"level 2: %s" % _build.label_text())


class _Walker:
	extends "res://demo/cast/resident_brain.gd"
	## A brain stand-in for a trip: its walk speed is read; going in and out only flips `indoors` (no space here).

	func task_go_indoors(inside: bool, _building: int) -> void:
		"""In or out, with no walking space to tell."""
		indoors = inside
