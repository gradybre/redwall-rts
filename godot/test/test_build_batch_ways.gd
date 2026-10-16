extends "res://test/framework/test_case.gd"
## The batch's ways per family (decision 2021, slice D1; Brendan's rulings of 2026-10-16): placing each family and
## turn, judging where it stands and where it comes down (its run through solid earth only), ways placed going up,
## a passage under a way below the Surface, the landings a pending removal takes away, removing a confirmed way and a
## Mound's door only when nothing would be cut off (BUILD-REQ-017), and Confirm all handing each way's family, turn
## and removal to the route.

const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 128, 128)
const CAPACITY: int = 4096
const KITCHEN: int = 2
const RAMP: int = Families.RAMP
const HATCH: int = Families.LADDER_HATCH
const STAIR: int = Families.EARTH_TIMBER

var _batch: Batch = null
## The host: ground per (level, cell), confirmed ways per level (quads), dug room types, what a removal cuts off.
var _ground: Dictionary = {}
var _revision: int = 0
var _shapes: Dictionary = {}
var _types: Dictionary = {}
var _cut_words: String = ""
var _cut_asks: Array = []
var _host_edges: Dictionary = {}


func before_each() -> void:
	"""A batch with every host reader bound, nothing confirmed, all ground diggable."""
	_batch = Batch.new()
	assert_equal(_batch.configure(BuildCatalog.new(), BOUNDS, CAPACITY), &"", "configured")
	_ground.clear()
	_shapes.clear()
	_types.clear()
	_cut_words = ""
	_cut_asks.clear()
	_host_edges.clear()
	_batch.bind_ground(func(level: int, cell: Vector2i) -> int: return int(_ground.get(Vector3i(level, cell.x, cell.y),
		Cells.CELL_OK)), func() -> int: return _revision)
	_batch.bind_way_host(_shapes_on, _cut_off, func(level: int, cell: Vector2i) -> int:
		return int(_types.get(Vector3i(level, cell.x, cell.y), -1)))


func after_each() -> void:
	"""Let go of the batch (its readers close over this suite)."""
	_batch = null


func _shapes_on(level: int) -> PackedInt32Array:
	"""The host's confirmed ways standing on `level`."""
	return PackedInt32Array(_shapes.get(level, PackedInt32Array()))


func _cut_off(ways: PackedInt32Array, doors: Array) -> String:
	"""The host's cut-off check: records what it was asked, answers `_cut_words`."""
	_cut_asks.append([ways, doors])
	return _cut_words


func _dig(level: int, cells: PackedInt32Array, room_type: int) -> void:
	"""Mark `cells` (pairs) dug on `level` as `room_type` (the ground FINISHED)."""
	for at: int in range(0, cells.size(), 2):
		_ground[Vector3i(level, cells[at], cells[at + 1])] = Cells.CELL_FINISHED
		_types[Vector3i(level, cells[at], cells[at + 1])] = room_type
	_revision += 1


func _confirm_way(level: int, anchor: Vector2i, family: int, turn: int) -> void:
	"""The host has a confirmed way standing on `level`."""
	var quads: PackedInt32Array = _shapes_on(level)
	quads.append_array(PackedInt32Array([anchor.x, anchor.y, family, turn]))
	_shapes[level] = quads
	_batch.host_changed()


func test_each_offered_family_is_placed_on_the_surface_and_named() -> void:
	"""The Burrow mouth, the Hatch and the Stair-head each stand on the Surface; the step and row name the family."""
	assert_equal(_batch.place_item(0, Vector2i(10, 10), RAMP, 0), Validity.KIND_CAN_BUILD, "a burrow mouth")
	assert_equal(_batch.undo_label(), "Undo Place Burrow mouth", "the step named")
	assert_equal(_batch.place_item(0, Vector2i(30, 10), HATCH, 1), Validity.KIND_CAN_BUILD, "a hatch, turned")
	assert_equal(_batch.place_item(0, Vector2i(50, 10), STAIR, 2), Validity.KIND_NOT_POSSIBLE,
		"a stair-head turned: no qualified stair that way (2041 P-DF-6 (a))")
	assert_equal(_batch.last_dropped(), "X Not possible: No qualified stair for this direction yet", "in words")
	assert_equal(_batch.place_item(0, Vector2i(50, 10), STAIR, 0), Validity.KIND_CAN_BUILD, "a stair-head at turn 0")
	assert_equal(_batch.items().family_of(1), HATCH, "its family kept")
	assert_equal(_batch.items().turn_of(1), 1, "its turn kept")
	assert_equal(_batch.items().name_of_row(2), "Stair-head", "its name")
	assert_equal(_batch.pending_count(), 3, "three ways")


func test_a_locked_family_and_levels_off_the_ends_are_not_possible() -> void:
	"""Stone stairs are locked for a later update; a way standing above the Surface (Up from it) or below level 3 has
	no level; one running off the planning area is outside it."""
	assert_equal(_batch.judge_item(0, Vector2i(10, 10), -1, Families.STONE, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.not_yet(Families.LATER)], "stone")
	assert_equal(_batch.judge_item(-1, Vector2i(10, 10), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.no_level_above()], "up from the Surface")
	assert_equal(_batch.judge_item(4, Vector2i(10, 10), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.no_level_below()], "down from level 4")
	assert_equal(_batch.judge_item(0, Vector2i(10, 120), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.outside()], "its run leaves the area")
	assert_equal(_batch.judge_item(0, Vector2i(10, 114), -1, RAMP, 0)[0], Validity.KIND_CAN_BUILD, "14 rows just fit")
	assert_equal(_batch.place_item(0, Vector2i(10, 120), RAMP, 0), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.outside()), "in words")


func test_a_runs_cells_must_be_untouched_earth_and_its_landing_diggable() -> void:
	"""A ramp's run below may not cross a planned or dug room ("occupied"), nor water; its landing may be dug already
	but not water."""
	assert_equal(_batch.place_item(0, Vector2i(10, 10), RAMP, 0), Validity.KIND_CAN_BUILD, "clear earth")
	_ground[Vector3i(1, 10, 15)] = Cells.CELL_WATER
	_revision += 1
	assert_equal(_batch.item_reason(0), Validity.cannot_dig("water"), "water under its run")
	_ground.erase(Vector3i(1, 10, 15))
	_dig(1, PackedInt32Array([11, 16]), KITCHEN)
	assert_equal(_batch.item_reason(0), Validity.cannot_dig("occupied"), "a dug room under its run")
	_ground.erase(Vector3i(1, 11, 16))
	_revision += 1
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(11, 17)), "a room painted")
	_batch.extend_stroke(Vector2i(16, 22))
	_batch.finish_stroke()
	assert_equal(_batch.item_reason(0), Validity.cannot_dig("occupied"), "a planned room under its run")
	assert_equal(_batch.first_invalid_item(), 0, "it holds Confirm all back")
	_dig(1, PackedInt32Array([10, 10, 11, 10]), BuildCatalog.CORRIDOR)
	assert_equal(_batch.judge_item(0, Vector2i(40, 10), -1, RAMP, 0)[0], Validity.KIND_CAN_BUILD, "elsewhere fine")
	_ground[Vector3i(1, 40, 10)] = Cells.CELL_WATER
	_revision += 1
	assert_equal(_batch.judge_item(0, Vector2i(40, 10), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.cannot_dig("water")], "its landing on water")


func test_below_the_surface_a_way_stands_on_a_passage() -> void:
	"""P-D1-5 (a): "! ... needs a passage under it" until a planned or dug Passage is under every standing cell; a dug
	room of another type is not one."""
	assert_equal(_batch.place_item(1, Vector2i(20, 20), HATCH, 0), Validity.KIND_BLOCKED, "nothing under it")
	assert_equal(_batch.item_reason(0), Validity.needs_passage("Hatch with ladder"), "said")
	_dig(1, PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21]), KITCHEN)
	assert_equal(_batch.item_reason(0), Validity.needs_passage("Hatch with ladder"), "a Kitchen is no passage")
	_dig(1, PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21]), BuildCatalog.CORRIDOR)
	assert_equal(_batch.item_kind(0), Validity.KIND_CAN_BUILD, "a dug Passage")
	assert_equal(_batch.place_item(1, Vector2i(40, 40), HATCH, 0), Validity.KIND_BLOCKED, "another, bare")
	assert_true(_batch.begin_stroke(BuildCatalog.CORRIDOR, 1, Vector2i(40, 40)), "a Passage painted")
	_batch.extend_stroke(Vector2i(41, 43))
	_batch.finish_stroke()
	assert_equal(_batch.item_kind(1), Validity.KIND_CAN_BUILD, "a planned Passage serves")


func test_a_way_up_is_the_same_way_standing_on_the_level_above() -> void:
	"""P-D1-4 (a): placed Up from level 2, it stands on level 1 and lands on level 2: its landing gives level 2's room
	its way in; its cells on level 1 need a passage."""
	assert_equal(_batch.place_item(1, Vector2i(30, 30), HATCH, 0), Validity.KIND_BLOCKED, "standing on level 1")
	assert_equal(_batch.items().landings(2), PackedInt32Array([30, 30, 31, 30, 30, 31, 31, 31]), "lands on level 2")
	assert_true(_batch.begin_stroke(KITCHEN, 2, Vector2i(32, 30)), "a room beside its landing")
	_batch.extend_stroke(Vector2i(37, 33))
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "reached through it")


func test_ways_clash_where_they_stand_and_where_a_run_cuts_but_not_on_a_hatchs_landing() -> void:
	"""Two ways never stand on one cell, and nothing shares a run's cells (solid earth only its way takes); a way may
	stand on a hatch's landing (open floor below it)."""
	_batch.place_item(0, Vector2i(10, 10), RAMP, 0)
	assert_equal(_batch.judge_item(0, Vector2i(11, 20), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down("Burrow mouth")], "on its open cut")
	assert_equal(_batch.judge_item(0, Vector2i(11, 12), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down("Burrow mouth")], "landing on its run below")
	assert_equal(_batch.judge_item(0, Vector2i(12, 12), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD,
		"beside its run")
	assert_equal(_batch.judge_item(0, Vector2i(20, 10), -1, RAMP, 1)[0], Validity.KIND_CAN_BUILD, "beside it")
	assert_equal(_batch.items().clashes(0, Vector2i(11, 0), -1, RAMP, 0), 0, "two runs crossing below")
	_batch.place_item(0, Vector2i(60, 60), HATCH, 0)
	_dig(1, PackedInt32Array([60, 60, 61, 60, 60, 61, 61, 61]), BuildCatalog.CORRIDOR)
	assert_equal(_batch.judge_item(1, Vector2i(60, 60), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD,
		"a shaft of hatches")


func test_a_pending_removal_takes_its_ways_landing_away() -> void:
	"""The host's landing is a way in until a pending removal names its way; Undo gives it back."""
	_confirm_way(0, Vector2i(20, 20), HATCH, 0)
	_batch.bind_landings(func(level: int) -> PackedInt32Array:
		return PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21]) if level == 1 else PackedInt32Array())
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(22, 20)), "a room beside the landing")
	_batch.extend_stroke(Vector2i(27, 23))
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "reached")
	assert_equal(_batch.toggle_way_removal(1, Vector2i(21, 21)), Validity.KIND_CAN_BUILD, "removal asked, from below")
	assert_true(_batch.items().is_removal(0), "a removal row")
	assert_equal(_batch.operation_reason(0), Validity.no_way_in(), "the room has no way in now")
	assert_equal(_batch.undo_label(), "Undo Remove Hatch with ladder", "named")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "reached again")


func test_removing_the_only_way_in_is_refused_with_the_names() -> void:
	"""BUILD-REQ-017: the host says what would be cut off; the click is dropped in its words, nothing added."""
	_confirm_way(0, Vector2i(20, 20), RAMP, 0)
	_cut_words = "Kitchen (level 1), Basil"
	assert_equal(_batch.toggle_way_removal(0, Vector2i(20, 30)), Validity.KIND_NOT_POSSIBLE, "refused")
	assert_equal(_batch.last_dropped(), "X Not possible: Would cut off Kitchen (level 1), Basil: build another way in first",
		"its words")
	assert_equal(_batch.items().count(), 0, "nothing added")
	assert_equal(_cut_asks[0][0], PackedInt32Array([0, 20, 20]), "the host asked about that way")
	assert_equal(_batch.toggle_way_removal(0, Vector2i(5, 5)), -1, "no way there: nothing")


func test_a_removal_asked_and_withdrawn_and_judged_with_the_others() -> void:
	"""A click asks for a removal, another withdraws it (one step each); a pending removal turns "X" when the removals
	together would cut something off, or when its way is gone."""
	_confirm_way(0, Vector2i(20, 20), HATCH, 0)
	_confirm_way(0, Vector2i(40, 20), HATCH, 0)
	assert_equal(_batch.toggle_way_removal(0, Vector2i(20, 20)), Validity.KIND_CAN_BUILD, "asked")
	assert_equal(_batch.item_kind(0), Validity.KIND_CAN_BUILD, "fine alone")
	_cut_words = "Kitchen (level 1)"
	_batch.host_changed()
	assert_equal(_batch.item_reason(0), Validity.cut_off("Kitchen (level 1)"), "now it would cut off")
	assert_equal(_batch.first_invalid_item(), 0, "holding Confirm all back")
	_cut_words = ""
	_shapes[0] = PackedInt32Array([40, 20, HATCH, 0])
	_batch.host_changed()
	assert_equal(_batch.item_reason(0), Batch.NO_WAY_THERE, "its way gone")
	_shapes[0] = PackedInt32Array([20, 20, HATCH, 0, 40, 20, HATCH, 0])
	assert_equal(_batch.toggle_way_removal(0, Vector2i(21, 21)), Validity.KIND_CAN_BUILD, "withdrawn")
	assert_false(_batch.items().is_live(0), "no longer pending")
	assert_equal(_batch.pending_count(), 0, "nothing pending")


func test_removing_a_mounds_only_door_is_refused_and_a_window_is_not_asked() -> void:
	"""Decision 2002's door removal now asks the cut-off check (F6's gap): refused in words while it is the only way
	in; a window's removal never asks."""
	_batch.bind_mound_host(func() -> PackedInt32Array: return PackedInt32Array([10, 10, 11, 10, 10, 11, 11, 11]),
		func(_level: int) -> PackedInt32Array: return PackedInt32Array(), func(_cell: Vector2i) -> String: return "",
		func() -> Array: return [Vector3i(10, 11, 2)], _edge_at, func(_kind: int) -> Array: return [])
	_host_edges[Vector3i(10, 11, 2)] = Mound.KIND_DOOR
	_host_edges[Vector3i(11, 10, 0)] = Mound.KIND_WINDOW
	_cut_words = "Bedroom (surface)"
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(10, 11), 2, Mound.KIND_DOOR, Mound.COLOUR_OAK),
		Validity.KIND_NOT_POSSIBLE, "the only door")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.cut_off("Bedroom (surface)")),
		"in words")
	assert_equal(_cut_asks[-1][1], [Vector3i(10, 11, 2)], "asked about that door")
	var asks: int = _cut_asks.size()
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(11, 10), 0, Mound.KIND_WINDOW, Mound.COLOUR_OAK),
		Validity.KIND_CAN_BUILD, "a window's removal")
	assert_equal(_cut_asks.size(), asks, "never asked")
	_cut_words = ""
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(10, 11), 2, Mound.KIND_DOOR, Mound.COLOUR_OAK),
		Validity.KIND_CAN_BUILD, "allowed once nothing is cut off")
	_cut_words = "Basil"
	_batch.host_changed()
	assert_equal(_batch.edge_reason(1), Validity.cut_off("Basil"), "a pending door removal is judged again")
	assert_equal(_batch.edge_kind(0), Validity.KIND_CAN_BUILD, "the window's still fine")


func _edge_at(_level: int, edge: Vector3i) -> Vector4i:
	"""The host's door or window on `edge`."""
	for first: Vector3i in _host_edges:
		var kind: int = _host_edges[first]
		for own: Vector3i in Mound.edges_of(kind, Mound.cell_of(first), first.z):
			if Mound.same_edge(own, edge):
				return Vector4i(kind, first.x, first.y, first.z)
	return MoundEdges.NONE


func test_confirm_all_hands_family_turn_and_removal_to_the_route() -> void:
	"""BUILD-REQ-019: the ways first -- removals before placements (review H2) -- with family, turn and removal."""
	_confirm_way(0, Vector2i(60, 60), HATCH, 0)
	_batch.place_item(0, Vector2i(10, 10), RAMP, 3)
	_batch.toggle_way_removal(0, Vector2i(60, 60))
	var routed: Array = []
	var result: PackedInt32Array = _batch.confirm_all(func(_d: Object, _l: int, _t: int) -> Dictionary: return {"ok": true},
		func(level: int, cell: Vector2i, family: int, turn: int, removal: bool) -> Dictionary:
			routed.append([level, cell, family, turn, removal])
			return {"ok": true})
	assert_equal(routed, [[0, Vector2i(60, 60), HATCH, 0, true], [0, Vector2i(10, 10), RAMP, 3, false]],
		"removals first (review H2), then ways")
	assert_equal(result, PackedInt32Array([2, 0]), "both ordered")
	assert_equal(_batch.pending_count(), 0, "none pending")


func test_on_the_surface_a_way_partly_on_a_mound_room_does_not_fit() -> void:
	"""BUILD-MOUND-021 with P-D1-12 (a)'s words: a ramp whose open cut is partly on a Mound room's floor."""
	_batch.bind_mound_host(func() -> PackedInt32Array: return PackedInt32Array([10, 20, 11, 20, 10, 21, 11, 21]),
		func(_level: int) -> PackedInt32Array: return PackedInt32Array(), func(_cell: Vector2i) -> String: return "",
		func() -> Array: return [], _edge_at, func(_kind: int) -> Array: return [])
	assert_equal(_batch.judge_item(0, Vector2i(10, 8), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.not_in_room("Burrow mouth", 2, 9)], "does not fit")
	assert_equal(_batch.judge_item(0, Vector2i(10, 20), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD, "a hatch on its floor")


func test_a_new_way_never_stands_on_a_confirmed_one_unless_it_is_being_removed() -> void:
	"""A confirmed way's cells clash as a pending way's do; once a pending removal takes it, its place is free."""
	_confirm_way(0, Vector2i(20, 20), HATCH, 0)
	assert_equal(_batch.judge_item(0, Vector2i(21, 21), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down("Hatch with ladder")], "on it")
	_confirm_way(1, Vector2i(40, 40), RAMP, 0)
	_dig(1, PackedInt32Array([40, 40, 41, 40]), BuildCatalog.CORRIDOR)
	assert_equal(_batch.judge_item(0, Vector2i(40, 45), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD,
		"above a run one level down: not on it")
	assert_equal(_batch.judge_item(1, Vector2i(40, 45), -1, HATCH, 0)[0], Validity.KIND_NOT_POSSIBLE,
		"standing on level 1 over the trench of a way from level 1")
	_batch.toggle_way_removal(0, Vector2i(20, 20))
	assert_equal(_batch.judge_item(0, Vector2i(21, 21), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD, "its removal frees it")


func test_on_the_surface_a_way_over_water_or_a_thing_cannot_be_dug() -> void:
	"""Decision 2022: off a Mound room's floor, the host's surface reader ("water", "a tree") refuses a way's open cells
	in ECON-003's words; open ground and a Mound room's floor do not."""
	var things: Dictionary = {Vector2i(10, 16): "water", Vector2i(30, 30): "a tree"}
	_batch.bind_mound_host(func() -> PackedInt32Array: return PackedInt32Array([50, 50, 51, 50, 50, 51, 51, 51]),
		func(_level: int) -> PackedInt32Array: return PackedInt32Array(),
		func(cell: Vector2i) -> String: return String(things.get(cell, "water" if cell.x >= 50 else "")),
		func() -> Array: return [], _edge_at, func(_kind: int) -> Array: return [])
	assert_equal(_batch.judge_item(0, Vector2i(10, 10), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.cannot_dig("water")], "the ramp's open cut over water")
	assert_equal(_batch.judge_item(0, Vector2i(30, 30), -1, HATCH, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.cannot_dig("a tree")], "a hatch under a tree")
	assert_equal(_batch.judge_item(0, Vector2i(20, 20), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD, "open ground")
	assert_equal(_batch.judge_item(0, Vector2i(50, 50), -1, HATCH, 0)[0], Validity.KIND_CAN_BUILD,
		"a Mound room's floor is not asked")


func test_a_new_runs_cells_may_not_cross_a_pending_hatchs_landing() -> void:
	"""Mutation I2: the new way's own run below meets another's landing there (the other has no run): a clash."""
	_batch.place_item(0, Vector2i(11, 12), HATCH, 0)
	assert_equal(_batch.judge_item(0, Vector2i(10, 10), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down("Hatch with ladder")], "the ramp's run meets its landing")


func test_level_three_is_the_deepest_a_way_stands_on() -> void:
	"""Mutation B1: standing on level 3 it lands on level 4 (it needs its passage); on level 4 there is no level below."""
	assert_equal(_batch.judge_item(3, Vector2i(10, 10), -1, HATCH, 0),
		[Validity.KIND_BLOCKED, Validity.needs_passage("Hatch with ladder")], "level 3: needs its passage only")
	assert_equal(_batch.judge_item(4, Vector2i(10, 10), -1, HATCH, 0)[1], Validity.no_level_below(), "level 4")


func test_confirm_all_checks_the_cut_off_afresh() -> void:
	"""Review H1: a removal judged ✓ is checked again at Confirm all; if the host now says it would cut something off,
	nothing is ordered."""
	_confirm_way(0, Vector2i(20, 20), HATCH, 0)
	_batch.toggle_way_removal(0, Vector2i(20, 20))
	assert_equal(_batch.item_kind(0), Validity.KIND_CAN_BUILD, "fine when asked")
	_cut_words = "Basil"
	var result: PackedInt32Array = _batch.confirm_all(func(_d: Object, _l: int, _t: int) -> Dictionary: return {"ok": true},
		func(_level: int, _cell: Vector2i, _family: int, _turn: int, _removal: bool) -> Dictionary: return {"ok": true})
	assert_equal(result, PackedInt32Array([0, 0]), "held back")
	assert_equal(_batch.item_reason(0), Validity.cut_off("Basil"), "and says why")


func test_a_pending_removal_makes_its_dug_landing_no_way_in() -> void:
	"""Review H3: the removed way's dug landing reads occupied, not finished space, so a room beside it has no way in."""
	_confirm_way(0, Vector2i(20, 20), HATCH, 0)
	_dig(1, PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21]), -1)
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(22, 20)), "a room beside the dug landing")
	_batch.extend_stroke(Vector2i(27, 23))
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "reached through dug space")
	_batch.toggle_way_removal(0, Vector2i(20, 20))
	assert_equal(_batch.operation_reason(0), Validity.no_way_in(), "no way in once the way is going")
	assert_equal(_batch.undo_label(), "Undo Remove Hatch with ladder", "named")
	_batch.toggle_way_removal(0, Vector2i(20, 20))
	assert_equal(_batch.undo_label(), "Undo Keep Hatch with ladder", "withdrawn: kept")
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "reached again")


func test_two_ways_never_share_a_landing() -> void:
	"""Two ramps meeting foot to foot on one landing row clash (removing one would strip the other's), though neither
	stands on nor runs through the other."""
	_batch.place_item(0, Vector2i(10, 20), RAMP, 0)
	assert_equal(_batch.items().landings(1), PackedInt32Array([10, 20, 11, 20]), "its landing row")
	assert_equal(_batch.judge_item(0, Vector2i(10, 7), -1, RAMP, 2)[0], Validity.KIND_NOT_POSSIBLE, "foot to foot")
	assert_equal(_batch.judge_item(0, Vector2i(10, 6), -1, RAMP, 2)[0], Validity.KIND_CAN_BUILD, "a row short of it")


func test_a_new_runs_cells_may_not_pass_under_a_way_standing_below() -> void:
	"""Mutation I2: a hatch standing on level 1 where a new ramp's run would cut: a clash (my run, its standing cells)."""
	_dig(1, PackedInt32Array([10, 15, 11, 15, 10, 16, 11, 16]), BuildCatalog.CORRIDOR)
	_batch.place_item(1, Vector2i(10, 15), HATCH, 0)
	assert_equal(_batch.judge_item(0, Vector2i(10, 10), -1, RAMP, 0),
		[Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down("Hatch with ladder")], "its run under the hatch")
