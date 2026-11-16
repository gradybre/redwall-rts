extends "res://test/framework/test_case.gd"
## The Mounds drawn in the demo (decision 2002; demo_build_mound_view.gd, demo_build_mound_marks.gd), off-tree: the
## hill whole or cut away, rebuilt only when something moved (also on a worker), each Mound's state in words, a hatch's
## words only cut away, the windows' daylight only cut away by day, a window that never changes the hill's heights, the
## parts drawn by stage, and the door and window marks with their words.

const View := preload("res://demo/build_panel/demo_build_mound_view.gd")
const Marks := preload("res://demo/build_panel/demo_build_mound_marks.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")

const DATUM: Vector2 = Vector2(0.0, 0.0)
const KITCHEN: int = 2
const BEDROOM: int = 1

var _nodes: Array[Node] = []
var _mounds: Mounds = null
var _works: Works = null
var _fittings: Fittings = null


func tolerates_outside_tree() -> bool:
	"""The view's tags and lights are placed off-tree here."""
	return true


func before_each() -> void:
	"""A Kitchen (10, 10)-(15, 13) and a Bedroom joined east (16, 10)-(19, 13) ordered on the Surface."""
	_mounds = Mounds.new()
	_mounds.configure(Rect2i(0, 0, 40, 40))
	_works = Works.new()
	_works.configure(Rect2i(0, 0, 40, 40))
	_fittings = Fittings.new()
	_order(_rect(Vector2i(10, 10), Vector2i(15, 13)), KITCHEN)
	_order(_rect(Vector2i(16, 10), Vector2i(19, 13)), BEDROOM)


func after_each() -> void:
	"""Free every node made."""
	for node: Node in _nodes:
		node.free()
	_nodes.clear()


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _order(cells: PackedInt32Array, room_type: int) -> void:
	"""Confirm all's route for a Mound room."""
	assert_true(_mounds.order_cells(cells) and _works.order_room(Mound.SURFACE, cells, room_type), "ordered")


func _view() -> View:
	"""A view (built on the main thread) over the store."""
	var view: View = View.new()
	_nodes.append(view)
	view.configure(_mounds, _works, _fittings, DATUM)
	return view


func _all_to(stage: int) -> void:
	"""Every Mound cell on to `stage` (a dug one opened in the works)."""
	var cells: PackedInt32Array = _mounds.all_cells()
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		while _mounds.stage_of(cell) < stage:
			_mounds.advance(cell, _mounds.stage_of(cell) + 1)
		if stage >= Mounds.DUG:
			_works.open_cell(Mound.SURFACE, cell)


func test_a_mound_without_a_door_says_so_and_is_only_chalk() -> void:
	"""Ordered and doorless: no hill yet, the cells pegged out in chalk, "! No way in" over it."""
	var view: View = _view()
	view.refresh(false, true)
	assert_null(view.hill_mesh(false), "nothing heaped: no hill")
	assert_equal(view.tags(), PackedStringArray(["! No way in: place a door on an outer edge"]), "its words")
	assert_equal(view.state_words(0), View.NO_WAY_IN, "state")
	assert_equal(view.rebuilds, 1, "built once")
	view.refresh(false, true)
	assert_equal(view.rebuilds, 1, "nothing moved: not again")


func test_the_state_words_follow_the_stage() -> void:
	"""Heaping, digging, framing, topping with the cells left; then the doors and windows to fit; then nothing."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_mounds.order_edge(Vector2i(17, 13), 2, Mound.KIND_WINDOW, 0)
	var view: View = _view()
	assert_equal(view.state_words(0), "Heaping the hill: 40 cells to go", "heaping")
	_mounds.advance(Vector2i(10, 10), Mounds.HEAPED)
	assert_equal(view.state_words(0), "Heaping the hill: 39 cells to go", "one fewer")
	_all_to(Mounds.DUG)
	assert_equal(view.state_words(0), "Framing: 40 cells to go", "framing")
	for at: int in range(0, 78, 2):
		var cell: Vector2i = Vector2i(_mounds.all_cells()[at], _mounds.all_cells()[at + 1])
		_mounds.advance(cell, Mounds.FRAMED)
	assert_equal(view.state_words(0), "Framing: 1 cell to go", "one cell")
	_all_to(Mounds.TOPPED)
	assert_equal(view.state_words(0), "Fitting the front door", "the door to fit")
	_mounds.fit_edge(0)
	assert_equal(view.state_words(0), "Fitting the window", "then the window")
	_mounds.fit_edge(1)
	assert_equal(view.state_words(0), "", "finished")
	view.refresh(false, true)
	assert_true(view.tags().is_empty(), "no words over a finished Mound")


func test_the_hill_whole_or_cut_away() -> void:
	"""Outside: the hill whole; the panel on the Surface: cut at the wall's top; the rooms grouped by type."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_all_to(Mounds.DUG)
	var view: View = _view()
	view.refresh(false, true)
	assert_false(view.shown_cutaway(), "whole")
	assert_true(view.hill_mesh(false) != null and view.hill_mesh(true) != null, "both looks made")
	assert_true(view.hill_mesh(false).get_aabb().end.y > Field.ROOM_TOP_M + Field.COVER_M, "the whole hill's crown")
	assert_true(view.hill_mesh(true).get_aabb().end.y <= Field.ROOM_TOP_M + 0.001, "cut at the wall's top")
	view.refresh(true, true)
	assert_true(view.shown_cutaway(), "cut away")
	assert_equal(view.rooms().size(), 2, "the Kitchen and the Bedroom")
	assert_equal(view.material().shader, View.MoundShader, "one shader material")
	view.use_props(null)


func test_a_window_never_changes_the_hills_heights() -> void:
	"""BUILD-MOUND-015: the hill is never cut for a window; it lies on the slope as drawn."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_all_to(Mounds.TOPPED)
	var view: View = _view()
	view.refresh(false, true)
	var before: PackedVector3Array = view.hill_mesh(false).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_mounds.order_edge(Vector2i(17, 13), 2, Mound.KIND_WINDOW, 0)
	_mounds.fit_edge(1)
	view.refresh(false, true)
	assert_equal(view.windows_drawn, 1, "the window drawn")
	var after: PackedVector3Array = view.hill_mesh(false).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_equal(after, before, "the hill unchanged")


func test_daylight_shows_only_cut_away_by_day_from_a_fitted_window() -> void:
	"""BUILD-MOUND-016: a fitted window's sky, beam and spotlight cut away and by day; never outside or at night."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_mounds.order_edge(Vector2i(17, 13), 2, Mound.KIND_WINDOW, 0)
	_all_to(Mounds.TOPPED)
	var view: View = _view()
	view.refresh(true, true)
	assert_false(view.daylight_shown(), "not fitted: no daylight")
	_mounds.fit_edge(1)
	view.refresh(true, true)
	assert_true(view.daylight_shown(), "fitted, cut away, by day")
	assert_equal(view.daylights_shown(), 1, "its spotlight")
	view.refresh(true, false)
	assert_false(view.daylight_shown(), "at night: none")
	assert_equal(view.daylights_shown(), 0, "no spotlight")
	view.refresh(false, true)
	assert_false(view.daylight_shown(), "outside: none")


func test_the_parts_follow_the_build() -> void:
	"""Ribs once framed (cut away), shrubs and a tree once topped, a chimney over a fitted hearth."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_all_to(Mounds.DUG)
	var view: View = _view()
	view.refresh(true, true)
	assert_equal(view.ribs_drawn, 0, "dug, not framed: no ribs")
	_all_to(Mounds.FRAMED)
	view.refresh(true, true)
	assert_true(view.ribs_drawn >= 8, "ribs: %d" % view.ribs_drawn)
	assert_equal(view.shrubs_drawn, 0, "no shrubs before the turf")
	_all_to(Mounds.TOPPED)
	view.refresh(false, true)
	assert_true(view.shrubs_drawn > 0, "shrubs on the turf")


func test_a_hatchs_words_show_only_cut_away() -> void:
	"""BUILD-MOUND-021: a way down on a Mound room's floor is named where it leads, in the cutaway only."""
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_all_to(Mounds.TOPPED)
	_mounds.fit_edge(0)
	assert_true(_works.order_way_down(Mound.SURFACE, Vector2i(11, 11)), "a hatch")
	var view: View = _view()
	view.refresh(false, true)
	assert_false(view.tags().has(View.HATCH_WORDS), "not outside")
	view.refresh(true, true)
	assert_true(view.tags().has(View.HATCH_WORDS), "cut away")
	var shown: Array[Label3D] = []
	view.shown_tags(shown)
	assert_equal(shown.size(), 1, "the one tag")


func test_a_threaded_build_finishes_and_a_request_meanwhile_waits() -> void:
	"""On a worker: busy until done; a second request waits and is built after; finish shows the newest."""
	var view: View = _view()
	view.threaded = true
	_mounds.order_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	_all_to(Mounds.HEAPED)
	view.request()
	view.request()
	assert_true(view.busy(), "in flight")
	view.finish()
	assert_false(view.busy(), "done")
	assert_equal(view.rebuilds, 2, "both builds")
	assert_true(view.hill_mesh(false) != null, "shown")
	assert_true(view.last_build_usec > 0, "timed")
	view.poll()


func _marks(batch: Batch) -> Marks:
	"""Marks over `batch` and the store."""
	var marks: Marks = Marks.new()
	_nodes.append(marks)
	marks.configure(batch, _mounds, DATUM)
	return marks


func test_the_marks_show_pending_doors_and_windows_and_the_free_edges() -> void:
	"""Each pending one a bar on its edges with its words; armed: every outer edge too, the hovered one judged."""
	var batch: Batch = Batch.new()
	batch.configure(BuildCatalog.new(), Rect2i(0, 0, 40, 40), 4096)
	batch.bind_mound_host(_mounds.all_cells, _works.ways_on, func(_c: Vector2i) -> String: return "", _mounds.doors,
		_mounds.edge_at, _mounds.listed)
	var marks: Marks = _marks(batch)
	marks.refresh(false, -1, Marks.NO_EDGE, 0, "")
	assert_false(marks.visible, "hidden off the Surface")
	batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 1)
	marks.refresh(true, -1, Marks.NO_EDGE, 0, "")
	assert_equal([marks.bars, marks.free_bars], [2, 0], "the door's two edges")
	assert_equal(marks.tags(), PackedStringArray(["✓ Front door, green"]), "in words")
	marks.refresh(true, Mound.KIND_WINDOW, Vector3i(17, 13, 2), Validity.KIND_CAN_BUILD, "Place Window, south\n✓ Can build")
	assert_equal(marks.free_bars, 28 - 2, "every other outer edge free")
	assert_equal(marks.bars, 2 + 26 + 1, "and the hovered one")
	assert_true(marks.tags().has("Place Window, south\n✓ Can build"), "its judgement")
	var shown: Array[Label3D] = []
	marks.shown_tags(shown)
	assert_equal(shown.size(), 2, "two tags")
	var bars: int = marks.bars
	marks.refresh(true, Mound.KIND_WINDOW, Vector3i(17, 13, 2), Validity.KIND_CAN_BUILD, "Place Window, south\n✓ Can build")
	assert_equal(marks.bars, bars, "nothing moved: not redrawn")


func test_pending_words_name_each_row() -> void:
	"""A door with its colour, a window, a removal."""
	var edges: MoundEdges = MoundEdges.new()
	edges.add(0, Vector2i(1, 1), 0, Mound.KIND_DOOR, 2, false)
	edges.add(0, Vector2i(1, 1), 1, Mound.KIND_WINDOW, 0, false)
	edges.add(0, Vector2i(3, 1), 0, Mound.KIND_DOOR, 0, true)
	assert_equal([Marks.pending_words(edges, 0), Marks.pending_words(edges, 1), Marks.pending_words(edges, 2)],
		["Front door, red", "Window", "Remove Front door"], "named")
