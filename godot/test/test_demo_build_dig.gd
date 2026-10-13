extends "res://test/framework/test_case.gd"
## The proof of concept's drawing and its trips below (decision 1912): the dug rooms drawn per level and rebuilt only
## on a change, the stand-in figure, the ground reader reading ordered and dug cells as finished, and a trip's stages
## for a visitor.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Dug := preload("res://demo/build_panel/demo_build_dug.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Ground := preload("res://demo/build_panel/demo_build_ground.gd")
const BelowTask := preload("res://demo/build_panel/demo_build_below_task.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 32, 32)
const FLOORS: PackedInt32Array = [0, -4608, -9728, -14848, -19968]

var _nodes: Array[Node] = []
var _works: Works = null


func before_each() -> void:
	"""An Entrance at (4, 4) with a 2 × 2 room beside its landing, ordered."""
	_works = Works.new()
	_works.configure(BOUNDS)
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5]), 2)


func after_each() -> void:
	"""Free the nodes."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_the_dug_rooms_are_drawn_per_level_and_rebuilt_only_on_a_change() -> void:
	"""Level 1 drawn with its way-up name, the Entrance named on the surface; a still frame rebuilds nothing; a dug
	cell rebuilds; no level shown hides the level's mesh."""
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1)
	assert_equal(dug.rebuilds, 1, "drawn once")
	assert_true(dug.tags().has("Entrance") and dug.tags().has("Way up to the surface"), ", ".join(dug.tags()))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 1, "a still frame rebuilds nothing")
	_works.open_cell(1, Vector2i(4, 4))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 2, "a dug cell redraws")
	dug.refresh(-1)
	assert_equal(dug.tags(), PackedStringArray(["Entrance"]), "no level shown: only the surface's name")


func test_the_figure_shows_its_name_and_digging_state() -> void:
	"""Hidden until shown; its words; a digging body."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	assert_equal(figure.words(), "", "hidden")
	figure.show_as("Tuppen", Vector3(1, -4.5, 2))
	assert_equal(figure.words(), "Tuppen", "named")
	assert_equal(figure.position, Vector3(1, -4.5, 2), "where it stands")
	figure.set_digging(true)
	figure.move_to(Vector3(2, -4.5, 2))
	assert_equal(figure.position.x, 2.0, "moved")


func test_the_ground_reads_ordered_and_dug_cells_as_finished() -> void:
	"""With the works bound, an ordered or dug cell reads FINISHED and a change moves the ground's revision."""
	var ground: Ground = Ground.new()
	ground.configure(Vector3i.ZERO, BOUNDS)
	assert_false(ground.readable(), "nothing bound")
	ground.bind_works(_works)
	assert_true(ground.readable() and not ground.bound(), "the works only")
	assert_equal(ground.ground(1, Vector2i(6, 4)), Cells.CELL_FINISHED, "ordered")
	assert_equal(ground.ground(1, Vector2i(20, 20)), Cells.CELL_OK, "earth (no settlement ground in this run)")
	var revision: int = ground.revision()
	_works.open_cell(1, Vector2i(4, 4))
	assert_true(ground.revision() > revision, "moved")


func test_a_visit_walks_through_dug_cells_and_stays() -> void:
	"""A visitor's trip: in at the landing, along the dug cells to its goal, staying there; called away, out."""
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 4)]:
		_works.open_cell(1, cell)
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_VISIT, Vector3i(1, 6, 4),
		"Wenna")
	assert_equal(trip.site(null), Vector2(5.0, 5.0), "the Entrance's middle on the surface")
	assert_equal(trip.label(), "Going down to the dug rooms", "on the way")
	trip._at = Vector3i(1, 4, 4)
	figure.show_as("Wenna", trip.world_of(trip._at))
	trip.stage = BelowTask.STAGE_PLAN
	for frame: int in 100:
		trip.step(_Walker.new(), 0.1)
	assert_equal(trip.at(), Vector3i(1, 6, 4), "there")
	assert_equal(trip.stage, BelowTask.STAGE_STAY, "staying")
	assert_true(trip.below(), "below")
	assert_equal(trip.label(), "In the dug rooms below", "says so")
	assert_false(trip.holds_when_lost(), "lost on the way, back to its routine")
	assert_equal(trip.world_of(Vector3i(1, 6, 4)), Vector3(6.5, -4.5, 4.5), "a cell's middle on level 1's floor")


class _Walker:
	extends "res://demo/cast/resident_brain.gd"
	## A brain stand-in for a trip's walk: only its walk speed is read below.
