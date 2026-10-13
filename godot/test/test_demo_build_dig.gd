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
const Earth := preload("res://demo/build_panel/demo_build_earth.gd")
const Tags := preload("res://demo/build_panel/demo_build_tags.gd")

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
	assert_true(dug.earth.visible and dug.earth.top_quads >= BOUNDS.size.y, "the level's earth drawn")
	assert_true(dug.tags().has("Waiting for the mole: 8 cells"), "waiting cells said in words")
	assert_true(dug.tags().has("Entrance") and dug.tags().has("Way up to the surface"), ", ".join(dug.tags()))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 1, "a still frame rebuilds nothing")
	_works.open_cell(1, Vector2i(4, 4))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 2, "a dug cell redraws")
	dug.refresh(-1)
	assert_equal(dug.tags(), PackedStringArray(["Entrance"]), "no level shown: only the surface's name")
	dug.refresh(5)
	assert_false(dug.earth.visible, "the bar's Overview is no underground level")
	assert_equal(dug.tags(), PackedStringArray(["Entrance"]), "and shows only the surface's name")


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
	var walker: _Walker = _Walker.new()
	trip.cancel(walker)
	assert_false(figure.visible, "called away: the figure gone")
	assert_false(walker.indoors, "and the resident out")


func test_a_dig_waits_before_the_cell_opens() -> void:
	"""M1: a cell opens only after DIG_SECONDS of digging."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_DIG, Vector3i.ZERO, "Tuppen")
	trip.arrived(_Walker.new())
	trip.step(_Walker.new(), 0.01)
	trip.step(_Walker.new(), 0.01)
	assert_equal(trip.stage, BelowTask.STAGE_DIG, "digging the landing it stands on")
	trip.step(_Walker.new(), BelowTask.DIG_SECONDS / 2.0)
	assert_equal(trip.dug, 0, "not yet")
	trip.step(_Walker.new(), BelowTask.DIG_SECONDS)
	assert_equal(trip.dug, 1, "opened")


func test_a_dug_cell_is_a_pit_in_the_earth() -> void:
	"""Decision 1913: the top is cut away over a dug cell (its row split round it, a floor instead), a wall, a shade and
	a lip on each side that is not dug, the ordered cells pegged out in chalk; the earth reads the World's ground per
	tile (a wet tile is not earth)."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	var top: int = earth.top_quads
	assert_equal(earth.wall_quads, 0, "nothing dug: no wall")
	assert_equal(earth.mark_quads, 8 * 4, "eight ordered cells pegged out, four chalk lines each")
	_works.open_cell(1, Vector2i(6, 4))
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_equal(earth.top_quads, top + 1, "row 4's top split round the pit")
	assert_equal(earth.floor_quads, 1, "the pit's floor")
	assert_equal(earth.wall_quads, 4, "a wall on each side: earth or ordered, none dug")
	assert_equal(earth.mark_quads, 7 * 4 + 4 * 2, "seven cells pegged out; a shade and a lip at each wall")
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(Earth.World.TILE_COUNT)
	kinds.fill(Earth.World.TERRAIN_LAND)
	kinds[Earth.World.MAP_TILES_X * 5 + 5] = Earth.World.TERRAIN_LAKE
	earth.set_kinds(kinds)
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_equal(earth.top_mesh().get_surface_count(), 2, "the earth's top, and the lake's tile in its own mark")


func test_the_cell_being_dug_deepens() -> void:
	"""The digging cell is cut out of the top and drawn as a pit scaled by the dig's progress; its step down to a dug
	neighbour shrinks as it deepens; "Digging" says so, and the waiting count leaves it out."""
	_works.open_cell(1, Vector2i(4, 4))
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1, Vector3i(1, 5, 4))
	assert_equal(dug.earth.digging(), Vector3i(1, 5, 4), "drawn as being dug")
	dug.set_progress(0.25)
	var pit: MeshInstance3D = dug.earth.digging_nodes()[0]
	var step: MeshInstance3D = dug.earth.digging_nodes()[1]
	assert_true(pit.visible and is_equal_approx(pit.scale.y, 0.25), "a quarter dug: a quarter deep")
	assert_true(is_equal_approx(step.scale.y, 0.75), "the step down to the dug landing cell: what is left")
	assert_equal(dug.earth.wall_quads, 3, "no wall between the dug cell and the one being dug")
	assert_equal(dug.earth.mark_quads, 6 * 4 + 3 * 2, "six cells pegged out (not the one being dug); shade and lips")
	assert_equal((step.mesh as ArrayMesh).get_surface_count(), 1, "one dug neighbour, one step face")
	assert_true(dug.tags().has("Digging") and dug.tags().has("Waiting for the mole: 6 cells"), ", ".join(dug.tags()))
	dug.refresh(1)
	assert_false(pit.visible, "not digging: no pit drawn")
	dug.refresh(2, Vector3i(1, 5, 4))
	assert_false(dug.tags().has("Digging"), "a cell dug on another level is not this level's")
	dug.earth.draw(_works, 1, -4.5, Vector3i(2, 5, 4))
	assert_equal(dug.earth.digging(), Earth.NO_CELL, "nor drawn on it")


func test_ways_are_drawn_as_a_mouth_and_stairs() -> void:
	"""The Entrance is a burrow mouth on the surface; its landing gets stairs up once dug, not before."""
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1)
	assert_equal(dug.mouths_shown(), 1, "the burrow mouth")
	assert_equal(dug.stairs_shown(), 0, "the landing not dug: no stairs yet")
	_works.open_cell(1, Vector2i(4, 4))
	dug.refresh(1)
	assert_equal(dug.stairs_shown(), 0, "a quarter of it dug: still none")
	for offset: Vector2i in Works.QUAD:
		_works.open_cell(1, Vector2i(4, 4) + offset)
	dug.refresh(1)
	assert_equal(dug.stairs_shown(), 1, "stairs up out of the dug landing")
	dug.refresh(2)
	assert_equal(dug.stairs_shown(), 0, "none on a level it does not touch")


func test_the_figure_stands_on_the_pit_floor() -> void:
	"""Its place is the floor plane; its body and name are drawn a pit's depth lower, the name over everything."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	assert_true(figure.tag().position.y < Figure.HEIGHT_M + 0.35 and figure.tag().position.y > 0.0, "sunk, still over")
	assert_true(figure.tag().outline_render_priority < figure.tag().render_priority, "outline under text")


func test_tags_spread_upward_only_as_far_as_they_must() -> void:
	"""The first tag never moves; one that meets it rises just clear (`gap` apart); one clear of all stays; a third
	that meets the lifted one rises past both; a tag with no area (behind the camera) is ignored."""
	var gap: float = 4.0
	var rects: Array[Rect2] = [Rect2(0, 100, 100, 20), Rect2(50, 110, 100, 20), Rect2(300, 100, 50, 20),
		Rect2(40, 95, 30, 20), Rect2()]
	var lifts: PackedFloat32Array = Tags.spread(rects, gap)
	assert_equal(lifts[0], 0.0, "the first stays")
	var slack: float = Tags.LIFT_SLACK_PX
	assert_true(absf(lifts[1] - (110.0 - (100.0 - gap - 20.0) + slack)) < 0.001, "just clear of the first")
	assert_equal(lifts[2], 0.0, "clear of all: stays")
	assert_true(absf(lifts[3] - (95.0 - (76.0 - slack - gap - 20.0) + slack)) < 0.001, "past both, the lifted second too")
	assert_equal(lifts[4], 0.0, "no area: left alone")
	var empty_inside: Array[Rect2] = [Rect2(0, 100, 100, 20), Rect2(Vector2(50, 105), Vector2.ZERO)]
	assert_equal(Tags.spread(empty_inside, gap)[1], 0.0, "an empty rect inside another is not lifted either")
	assert_equal(Tags.first_hit(Rect2(0, 76, 100, 20), [Rect2(0, 100, 100, 20)], gap), -1, "exactly gap apart: clear")
	assert_equal(Tags.first_hit(Rect2(0, 77, 100, 20), [Rect2(0, 100, 100, 20)], gap), 0, "closer: meets")
	assert_equal(Tags.first_hit(Rect2(0, 0, 10, 10), [Rect2()], gap), -1, "an empty rect is never met")


func test_a_trip_says_which_cell_it_digs_and_how_far() -> void:
	"""digging_cell and dig_share: the target while digging, nothing otherwise."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_DIG, Vector3i.ZERO, "Tuppen")
	assert_equal(trip.digging_cell(), Vector3i(-1, 0, 0), "not yet")
	assert_equal(trip.dig_share(), 0.0, "none")
	trip.arrived(_Walker.new())
	trip.step(_Walker.new(), 0.01)
	trip.step(_Walker.new(), 0.01)
	trip.step(_Walker.new(), BelowTask.DIG_SECONDS / 4.0)
	assert_equal(trip.digging_cell(), Vector3i(1, 4, 4), "the landing it stands on")
	assert_true(is_equal_approx(trip.dig_share(), 0.25), str(trip.dig_share()))


func test_the_top_covers_everything_but_the_pits() -> void:
	"""Review M5: the earth's top covers the planning area and its apron exactly, less each dug cell and the cell being
	dug (a strip lost inside or beside the works' box would leave a hole)."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	var whole: float = (BOUNDS.size.x + 2.0 * Earth.APRON_M) * (BOUNDS.size.y + 2.0 * Earth.APRON_M)
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_true(is_equal_approx(_top_area(earth), whole), "nothing dug: all covered (%f)" % _top_area(earth))
	_works.open_cell(1, Vector2i(6, 4))
	_works.open_cell(1, Vector2i(7, 5))
	earth.draw(_works, 1, -4.5, Vector3i(1, 4, 4))
	assert_true(is_equal_approx(_top_area(earth), whole - 3.0), "two pits and the digging cell cut out (%f)" % _top_area(earth))


func test_a_way_down_has_stairs_only_once_dug_through() -> void:
	"""Review M1: a Way down standing on a passage still waiting for the mole draws no stairs, even with its landing
	dug; with its own cells dug too it does, and no floor is drawn under them."""
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		_works.open_cell(1, cell)
	_works.order_room(1, PackedInt32Array([10, 10, 11, 10, 10, 11, 11, 11]), 7)
	_works.order_way_down(1, Vector2i(10, 10))
	for offset: Vector2i in Works.QUAD:
		_works.open_cell(2, Vector2i(10, 10) + offset)
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1)
	assert_equal(dug.stairs_shown(), 1, "the Entrance's stairs up only: the way down stands on waiting cells")
	assert_false(Earth.stairs_down_at(_works, 1, Vector2i(10, 10)), "no stairs there yet")
	for offset: Vector2i in Works.QUAD:
		_works.open_cell(1, Vector2i(10, 10) + offset)
	dug.refresh(1)
	assert_equal(dug.stairs_shown(), 2, "dug through: its stairs down too")
	assert_true(Earth.stairs_down_at(_works, 1, Vector2i(11, 11)), "and no floor under them")
	var floors: int = dug.earth.floor_quads
	assert_equal(floors, 4 + 4 - 4, "the landing's floors; none under the stairs down (%d)" % floors)


func test_the_mole_stands_on_the_floor_dug_so_far() -> void:
	"""Review M2: set_sink lowers the body and name; shown again, it stands on a dug floor."""
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var full: float = figure.tag().position.y
	figure.set_sink(0.25)
	assert_true(is_equal_approx(figure.tag().position.y, full + Figure.SINK_M - 0.25), "on the shallow pit's floor")
	figure.show_as("Tuppen", Vector3.ZERO)
	assert_true(is_equal_approx(figure.tag().position.y, full), "back on a dug floor")


func test_spread_clears_with_float_positions() -> void:
	"""Review M3: with fractional rects, a lifted rect never meets the one it was lifted past, and a third clears
	both."""
	var rects: Array[Rect2] = [Rect2(10.3, 100.17, 90.1, 13.71), Rect2(40.9, 104.33, 70.2, 13.71),
		Rect2(30.1, 99.9, 50.7, 13.71)]
	var lifts: PackedFloat32Array = Tags.spread(rects, 4.0)
	var placed: Array[Rect2] = []
	for k: int in rects.size():
		var moved: Rect2 = Rect2(rects[k].position - Vector2(0.0, lifts[k]), rects[k].size)
		assert_equal(Tags.first_hit(moved, placed, 4.0), -1, "rect %d clear of all before it" % k)
		placed.append(moved)


func _top_area(earth: Earth) -> float:
	"""The area (m²) of the earth top's land surface, from its triangles."""
	var arrays: Array = earth.top_mesh().surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area: float = 0.0
	for at: int in range(0, indices.size(), 3):
		var a: Vector3 = points[indices[at]]
		area += (points[indices[at + 1]] - a).cross(points[indices[at + 2]] - a).length() / 2.0
	return area


class _Walker:
	extends "res://demo/cast/resident_brain.gd"
	## A brain stand-in for a trip: its walk speed is read; going in and out only flips `indoors` (no space here).

	func task_go_indoors(inside: bool, _building: int) -> void:
		"""In or out, with no walking space to tell."""
		indoors = inside
