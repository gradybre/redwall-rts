extends "res://test/framework/test_case.gd"
## The Furnish tab's pending pieces (decision 1921; Brendan's "Footprint + rotation"): footprints read from
## room_catalog.gd and turned, edge items on a cell's sides, the judgement in words (dug cells of one room that uses
## the piece, no overlap with a pending or a confirmed piece), the rows, the bill; and the batch's steps for them:
## place, Undo, Redo, Discard all, Confirm all through a host route, and Confirm all held back by a piece that no
## longer fits.

const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

const BED: int = 0
const DECORATION: int = 1
const HEARTH: int = 2
const DOOR: int = 3
const PARTITION: int = 4
const BENCH: int = 5
const SEAT: int = 7
const KITCHEN: int = 2
const DORMITORY: int = 0
const BOUNDS: Rect2i = Rect2i(0, 0, 64, 64)

var _pieces: Furniture = null
var _batch: Batch = null
## The fake host: level-1 cell → room reading; floor cell → confirmed item; edge → confirmed item.
var _rooms: Dictionary = {}
var _taken: Dictionary = {}
var _edges: Dictionary = {}
var _orders: Array = []


func before_each() -> void:
	"""A Kitchen dug at (0..7, 0..5) beside a Dormitory at (8..13, 0..3) on level 1; cells (0..7, 6) ordered, not dug;
	a landing (dug, no room) at (14..15, 0..1)."""
	_rooms.clear()
	_taken.clear()
	_edges.clear()
	_orders.clear()
	_fill(Rect2i(0, 0, 8, 6), KITCHEN)
	_fill(Rect2i(8, 0, 6, 4), DORMITORY)
	_fill(Rect2i(0, 6, 8, 1), Furniture.ROOM_WAITING)
	_fill(Rect2i(14, 0, 2, 2), Furniture.ROOM_BARE)
	_pieces = Furniture.new()
	_pieces.bind_host(_room_at, _occupant, _edge_occupant)
	_batch = Batch.new()
	assert_equal(_batch.configure(BuildCatalog.new(), BOUNDS, 4096), &"", "configured")
	_batch.bind_furniture_host(_room_at, _occupant, _edge_occupant)


func after_each() -> void:
	"""Let go of the subjects (their readers close over this suite)."""
	_pieces = null
	_batch = null


func _fill(box: Rect2i, reading: int) -> void:
	"""Every level-1 cell of `box` reads `reading`."""
	for z: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			_rooms[Vector2i(x, z)] = reading


func _room_at(level: int, cell: Vector2i) -> int:
	"""The fake room reader: level 1 only."""
	return int(_rooms.get(cell, Furniture.ROOM_EARTH)) if level == 1 else Furniture.ROOM_EARTH


func _occupant(_level: int, cell: Vector2i) -> int:
	"""The fake confirmed floor pieces."""
	return int(_taken.get(cell, -1))


func _edge_occupant(_level: int, edge: Vector3i) -> int:
	"""The fake confirmed edge items."""
	return int(_edges.get(edge, -1))


func _submit(level: int, anchor: Vector2i, turn: int, item: int) -> Dictionary:
	"""A host route that takes every piece."""
	_orders.append([level, anchor, turn, item])
	return {"ok": true, "error": ""}


func test_footprints_are_the_catalogs_tiles_in_cells_and_turn() -> void:
	"""SET-BUILD-001 §6: a bed 2 × 2 cells, the bench and hearth 4 × 2 (2 × 4 turned), a door and a partition edges."""
	assert_equal(_pieces.size_of(BED, 0), Vector2i(2, 2), "bed")
	assert_equal(_pieces.size_of(BENCH, 0), Vector2i(4, 2), "bench")
	assert_equal(_pieces.size_of(BENCH, 1), Vector2i(2, 4), "bench turned once")
	assert_equal(_pieces.size_of(HEARTH, 2), Vector2i(4, 2), "hearth turned twice")
	assert_equal(_pieces.size_of(HEARTH, 3), Vector2i(2, 4), "hearth turned three times")
	assert_true(_pieces.is_edge(DOOR) and _pieces.is_edge(PARTITION), "door and partition stand on edges")
	assert_false(_pieces.is_edge(BED), "a bed takes floor")
	assert_equal(_pieces.size_of(DOOR, 0), Vector2i.ZERO, "no floor")
	assert_false(_pieces.is_item(9) or _pieces.is_item(-1), "only the nine items")
	assert_equal(_pieces.size_of(99, 0), Vector2i.ZERO, "an unknown item has no footprint")


func test_the_cursor_sits_at_the_footprints_middle() -> void:
	"""anchor_for: a 2 × 2 piece's north-west cell is the cursor; a 4 × 2 piece reaches one cell west of it."""
	assert_equal(_pieces.anchor_for(BED, 0, Vector2i(5, 5)), Vector2i(5, 5), "bed")
	assert_equal(_pieces.anchor_for(BENCH, 0, Vector2i(5, 5)), Vector2i(4, 5), "bench")
	assert_equal(_pieces.anchor_for(BENCH, 1, Vector2i(5, 5)), Vector2i(5, 4), "bench turned")
	assert_equal(_pieces.anchor_for(DOOR, 3, Vector2i(5, 5)), Vector2i(5, 5), "a door: the cursor cell")
	assert_equal(_pieces.cells_of(BENCH, 0, Vector2i(1, 2)),
		PackedInt32Array([1, 2, 2, 2, 3, 2, 4, 2, 1, 3, 2, 3, 3, 3, 4, 3]), "row by row")
	assert_equal(_pieces.cells_of(DOOR, 0, Vector2i(1, 2)), PackedInt32Array(), "an edge item takes no floor")


func test_an_edge_item_stands_on_the_side_its_turn_names() -> void:
	"""0 north, 1 east, 2 south, 3 west of the cursor cell, two cells long; edge_sides names both neighbours."""
	var at: Vector2i = Vector2i(3, 3)
	assert_equal(Furniture.edges_of(0, at), [Vector3i(0, 3, 3), Vector3i(0, 4, 3)] as Array[Vector3i], "north")
	assert_equal(Furniture.edges_of(1, at), [Vector3i(1, 4, 3), Vector3i(1, 4, 4)] as Array[Vector3i], "east")
	assert_equal(Furniture.edges_of(2, at), [Vector3i(0, 3, 4), Vector3i(0, 4, 4)] as Array[Vector3i], "south")
	assert_equal(Furniture.edges_of(3, at), [Vector3i(1, 3, 3), Vector3i(1, 3, 4)] as Array[Vector3i], "west")
	assert_equal(Furniture.edges_of(-1, at), Furniture.edges_of(3, at), "turns wrap")
	assert_equal(Furniture.edge_sides(Vector3i(0, 3, 3)), [Vector2i(3, 2), Vector2i(3, 3)] as Array[Vector2i], "across")
	assert_equal(Furniture.edge_sides(Vector3i(1, 3, 3)), [Vector2i(2, 3), Vector2i(3, 3)] as Array[Vector2i], "down")
	assert_equal(Furniture.turn_words(true, 1), "east side", "a door's side in words")
	assert_equal(Furniture.turn_words(false, 1), "turned once", "a bed's turn in words")
	assert_equal(Furniture.turn_words(false, 0), "", "unturned says nothing")


func test_a_piece_on_dug_cells_of_a_room_that_uses_it_can_be_built() -> void:
	"""✓: a hearth in the Kitchen, a bed in the Dormitory, a bench turned in the Kitchen."""
	assert_equal(_pieces.judge(1, Vector2i(0, 0), 0, HEARTH, -1), [Validity.KIND_CAN_BUILD, ""], "hearth")
	assert_equal(_pieces.judge(1, Vector2i(8, 0), 0, BED, -1), [Validity.KIND_CAN_BUILD, ""], "bed")
	assert_equal(_pieces.judge(1, Vector2i(6, 2), 1, BENCH, -1), [Validity.KIND_CAN_BUILD, ""], "bench turned")


func test_a_piece_off_dug_room_floor_is_refused_in_words() -> void:
	"""X: over earth, over cells still waiting for the mole, over a landing, across two rooms, on another level."""
	assert_equal(_pieces.judge(1, Vector2i(30, 30), 0, BED, -1)[1], Validity.not_on_room(), "earth")
	assert_equal(_pieces.judge(1, Vector2i(2, 5), 0, SEAT, -1)[1], Validity.not_dug(), "waiting for the mole")
	assert_equal(_pieces.judge(1, Vector2i(14, 0), 0, SEAT, -1)[1], Validity.not_on_room(), "a landing")
	assert_equal(_pieces.judge(1, Vector2i(7, 0), 0, SEAT, -1)[1], Validity.two_rooms(), "Kitchen and Dormitory")
	assert_equal(_pieces.judge(2, Vector2i(0, 0), 0, SEAT, -1)[0], Validity.KIND_NOT_POSSIBLE, "level 2 is earth")
	assert_equal(_pieces.judge(1, Vector2i(0, 0), 0, 42, -1)[0], Validity.KIND_NOT_POSSIBLE, "no such item")


func test_a_piece_the_room_does_not_use_is_refused_naming_its_rooms() -> void:
	"""X: a kitchen bench in the Dormitory, a bed in the Kitchen (room_catalog.gd's palette)."""
	var bench: Array = _pieces.judge(1, Vector2i(8, 0), 0, BENCH, -1)
	assert_equal(bench, [Validity.KIND_NOT_POSSIBLE, "Wrong room: Kitchen bench belongs in Kitchen"], "bench")
	var bed: Array = _pieces.judge(1, Vector2i(0, 0), 0, BED, -1)
	assert_equal(bed[1], "Wrong room: Bed belongs in Dormitory or Bedroom", "bed")
	assert_equal(_pieces.allowed_words(SEAT), "any room", "a seat: any room")


func test_pieces_cannot_overlap_pending_or_confirmed() -> void:
	"""X: over a pending piece (its own row excepted), over a confirmed one; a piece beside it is fine."""
	var row: int = _pieces.add(1, Vector2i(0, 0), 0, HEARTH)
	assert_equal(_pieces.judge(1, Vector2i(2, 1), 0, SEAT, -1)[1], Validity.piece_overlaps("Hearth"), "pending")
	assert_equal(_pieces.judge(1, Vector2i(0, 0), 0, HEARTH, row)[0], Validity.KIND_CAN_BUILD, "its own row")
	assert_equal(_pieces.judge(1, Vector2i(4, 0), 0, SEAT, -1)[0], Validity.KIND_CAN_BUILD, "beside it")
	_pieces.set_live(row, false)
	assert_equal(_pieces.judge(1, Vector2i(2, 1), 0, SEAT, -1)[0], Validity.KIND_CAN_BUILD, "undone: free")
	_taken[Vector2i(5, 3)] = BENCH
	assert_equal(_pieces.judge(1, Vector2i(4, 2), 0, SEAT, -1)[1], Validity.piece_overlaps("Kitchen bench"), "confirmed")
	_pieces.add(2, Vector2i(0, 0), 0, HEARTH)
	_fill(Rect2i(0, 0, 8, 6), KITCHEN)
	assert_equal(_pieces.judge(1, Vector2i(0, 0), 0, SEAT, -1)[0], Validity.KIND_CAN_BUILD, "another level's piece")


func test_a_door_needs_dug_room_floor_on_both_sides_and_its_own_edges() -> void:
	"""An edge item: ✓ between the Kitchen and the Dormitory; X with earth on one side; X on a pending or confirmed
	edge item's edge; a floor piece does not block it."""
	assert_equal(_pieces.judge(1, Vector2i(8, 0), 3, DOOR, -1)[0], Validity.KIND_CAN_BUILD, "Kitchen | Dormitory")
	assert_equal(_pieces.judge(1, Vector2i(0, 0), 0, DOOR, -1)[1], Validity.not_between_floors("Door"), "earth north")
	assert_equal(_pieces.judge(1, Vector2i(14, 0), 3, DOOR, -1)[1], Validity.not_between_floors("Door"),
		"a landing is no room floor")
	_pieces.add(1, Vector2i(8, 1), 3, PARTITION)
	assert_equal(_pieces.judge(1, Vector2i(8, 0), 3, DOOR, -1)[1], Validity.piece_overlaps("Partition"),
		"shares an edge with a pending partition")
	_edges[Vector3i(Furniture.EDGE_ACROSS, 2, 3)] = DOOR
	assert_equal(_pieces.judge(1, Vector2i(2, 3), 0, PARTITION, -1)[1], Validity.piece_overlaps("Door"), "confirmed")
	_taken[Vector2i(4, 3)] = BED
	assert_equal(_pieces.judge(1, Vector2i(4, 3), 0, PARTITION, -1)[0], Validity.KIND_CAN_BUILD, "floor is no edge")


func test_with_no_host_every_piece_is_refused() -> void:
	"""Unbound readers: every cell reads as earth."""
	var bare: Furniture = Furniture.new()
	assert_equal(bare.judge(1, Vector2i(0, 0), 0, BED, -1)[1], Validity.not_on_room(), "no room")
	assert_equal(bare.judge(1, Vector2i(0, 0), 0, DOOR, -1)[1], Validity.not_between_floors("Door"), "no floor")


func test_rows_live_and_clear() -> void:
	"""add, set_live, is_live, the reads, live_count, clear."""
	var row: int = _pieces.add(1, Vector2i(3, 4), 5, BENCH)
	assert_equal(row, 0, "the first row")
	assert_equal([_pieces.level_of(row), _pieces.anchor_of(row), _pieces.turn_of(row), _pieces.item_of(row)],
		[1, Vector2i(3, 4), 1, BENCH], "read back, the turn wrapped")
	assert_true(_pieces.is_live(row) and _pieces.live_count() == 1, "live")
	_pieces.set_live(row, false)
	assert_false(_pieces.is_live(row) or _pieces.is_live(7) or _pieces.is_live(-1), "not live")
	assert_equal([_pieces.count(), _pieces.live_count()], [1, 0], "kept, not live")
	_pieces.clear()
	assert_equal(_pieces.count(), 0, "cleared")


func test_the_bill_sums_every_live_piece_in_its_own_goods() -> void:
	"""Balance §4.3: a bed (wood 2, cloth 1, 20 WU) and a bench (wood 4, stone 4, iron 1, 60 WU)."""
	var goods: PackedStringArray = PackedStringArray()
	var milli: PackedInt64Array = PackedInt64Array()
	_pieces.add(1, Vector2i(8, 0), 0, BED)
	_pieces.add(1, Vector2i(0, 0), 0, BENCH)
	var dropped: int = _pieces.add(1, Vector2i(0, 2), 0, HEARTH)
	_pieces.set_live(dropped, false)
	var work: int = _pieces.bill_into(goods, milli)
	assert_equal(work, 80000, "20 + 60 WU in milli-WU")
	assert_equal(goods, PackedStringArray(["wood", "cloth", "stone", "iron"]), "in order of first appearance")
	assert_equal(milli, PackedInt64Array([6000, 1000, 4000, 1000]), "summed")
	assert_equal(Furniture.name_of(BENCH), "Kitchen bench", "named as its card")
	assert_equal(Furniture.name_of(99), "", "no such item")


# --- the batch ---------------------------------------------------------------------------------------------------

func test_a_placed_piece_is_one_step_undone_and_redone() -> void:
	"""place_piece: ✓ joins the batch as "Place Hearth"; Undo takes it out, Redo puts it back."""
	assert_equal(_batch.place_piece(1, Vector2i(0, 0), 0, HEARTH), Validity.KIND_CAN_BUILD, "placed")
	assert_equal(_batch.pending_count(), 1, "pending")
	assert_equal(_batch.undo_label(), "Undo Place Hearth", "its step")
	assert_true(_batch.undo(), "undone")
	assert_equal([_batch.pending_count(), _batch.furniture().live_count()], [0, 0], "gone")
	assert_equal(_batch.redo_label(), "Redo Place Hearth", "redo names it")
	assert_true(_batch.redo(), "redone")
	assert_equal(_batch.furniture().live_count(), 1, "back")
	assert_equal(_batch.piece_kind(0), Validity.KIND_CAN_BUILD, "✓")
	assert_equal(_batch.piece_reason(0), "", "no reason")


func test_a_refused_piece_is_dropped_with_its_words() -> void:
	"""X: nothing joins the batch, no step, the words kept in last_dropped; a later ✓ clears them."""
	assert_equal(_batch.place_piece(1, Vector2i(8, 0), 0, BENCH), Validity.KIND_NOT_POSSIBLE, "refused")
	assert_equal(_batch.pending_count(), 0, "nothing pending")
	assert_false(_batch.can_undo(), "no step")
	assert_equal(_batch.last_dropped(), "X Not possible: Wrong room: Kitchen bench belongs in Kitchen", "its words")
	_batch.place_piece(1, Vector2i(0, 0), 0, BENCH)
	assert_equal(_batch.place_piece(1, Vector2i(1, 1), 0, SEAT), Validity.KIND_NOT_POSSIBLE, "on the bench")
	assert_equal(_batch.last_dropped(), "X Not possible: Overlaps a Kitchen bench: place it clear of other furniture",
		"overlap in words")
	assert_equal(_batch.place_piece(1, Vector2i(0, 2), 0, SEAT), Validity.KIND_CAN_BUILD, "clear of it")
	assert_equal(_batch.last_dropped(), "", "cleared")


func test_a_stroke_in_progress_or_no_area_places_nothing() -> void:
	"""-1: a stroke in progress; and a batch with no planning area."""
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(30, 30)), "a stroke")
	assert_equal(_batch.place_piece(1, Vector2i(0, 0), 0, HEARTH), -1, "mid-stroke")
	assert_equal(Batch.new().place_piece(1, Vector2i(0, 0), 0, HEARTH), -1, "unconfigured")


func test_confirm_all_orders_pieces_through_the_route_and_out_of_undos_reach() -> void:
	"""BUILD-REQ-019 for furniture: each pending piece to `submit_piece`; ordered pieces leave the batch and its
	history; a refused one stays."""
	_batch.place_piece(1, Vector2i(0, 0), 0, HEARTH)
	_batch.place_piece(1, Vector2i(0, 2), 1, BENCH)
	var result: PackedInt32Array = _batch.confirm_all(Callable(), Callable(), _submit)
	assert_equal(result, PackedInt32Array([2, 0]), "two ordered")
	assert_equal(_orders, [[1, Vector2i(0, 0), 0, HEARTH], [1, Vector2i(0, 2), 1, BENCH]], "in order, turned")
	assert_equal([_batch.pending_count(), _batch.history_size()], [0, 0], "out of Undo's reach")
	_batch.place_piece(1, Vector2i(8, 0), 0, BED)
	var refused: PackedInt32Array = _batch.confirm_all(Callable(), Callable(),
		func(_l: int, _a: Vector2i, _t: int, _i: int) -> Dictionary: return {"ok": false})
	assert_equal(refused, PackedInt32Array([0, 1]), "refused")
	assert_equal(_batch.pending_count(), 1, "kept")
	assert_equal(_batch.confirm_all(Callable(), Callable(), Callable()), PackedInt32Array([0, 1]), "no route: kept")


func test_a_piece_that_no_longer_fits_holds_confirm_all_back() -> void:
	"""A pending piece whose cells were taken since (a confirmed piece there now) is X and holds Confirm all back."""
	_batch.place_piece(1, Vector2i(8, 0), 0, BED)
	assert_equal(_batch.first_invalid_piece(), -1, "fits")
	_taken[Vector2i(9, 1)] = BED
	assert_equal(_batch.first_invalid_piece(), 0, "taken since")
	assert_equal(_batch.invalid_count(), 1, "counted")
	assert_equal(_batch.confirm_all(Callable(), Callable(), _submit), PackedInt32Array([0, 0]), "nothing ordered")


func test_discard_all_drops_the_pending_pieces() -> void:
	"""Discard all drops every piece and its rows."""
	_batch.place_piece(1, Vector2i(8, 0), 0, BED)
	assert_equal(_batch.discard_all(), 1, "one dropped")
	assert_equal(_batch.furniture().count(), 0, "no rows")
