extends "res://test/framework/test_case.gd"
## The proof of concept's drawing and its trips below (decision 1912; its look, decisions 1913 and 1914): the dug rooms
## drawn per level and rebuilt only on a change, the stand-in figure, the ground reader reading ordered and dug cells
## as finished, and a trip's stages for a visitor.

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
	assert_true(dug.tags().has("Proof of concept, free: 8 cells wait for the crew"), "waiting cells said in words")
	assert_true(dug.tags().has("Hatch with ladder") and dug.tags().has("Hatch with ladder: way up to the surface"),
		", ".join(dug.tags()))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 1, "a still frame rebuilds nothing")
	_works.open_cell(1, Vector2i(4, 4))
	dug.refresh(1)
	assert_equal(dug.rebuilds, 2, "a dug cell redraws")
	dug.refresh(-1)
	assert_equal(dug.tags(), PackedStringArray(["Hatch with ladder"]), "no level shown: only the surface's name")
	dug.refresh(5)
	assert_false(dug.earth.visible, "the bar's Overview is no underground level")
	assert_equal(dug.tags(), PackedStringArray(["Hatch with ladder"]), "and shows only the surface's name")


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


func test_a_hatch_on_a_mound_floor_is_gone_down_from_its_doors_yard() -> void:
	"""Decision 2002: a trip down a given way starts where it is told (a Mound's door yard), its landing the way's;
	that way has no burrow mouth or Entrance name on the surface (the Mound's drawing has it)."""
	_works.order_room(0, PackedInt32Array([10, 10, 11, 10, 10, 11, 11, 11]), 2)
	_works.open_cell(0, Vector2i(10, 10))
	assert_true(_works.order_way_down(0, Vector2i(10, 10)), "a hatch on the Mound's floor")
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	assert_false(dug.on_mound(0), "the Entrance is on open ground")
	assert_true(dug.on_mound(1), "the hatch is on a Mound's floor")
	dug.refresh(-1)
	assert_equal(dug.tags(), PackedStringArray(["Hatch with ladder"]), "only the entrance named on the surface")
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_VISIT, Vector3i(1, 10, 10),
		"Wenna", 1, Vector2(11.0, 7.0))
	assert_equal(trip.site(null), Vector2(11.0, 7.0), "the door's yard")
	var first: BelowTask = BelowTask.new(_works, figure, FLOORS, Vector2i.ZERO, BelowTask.MODE_VISIT, Vector3i(1, 6, 4),
		"Wenna")
	assert_equal(first.site(null), Vector2(5.0, 5.0), "no way given: the first Entrance")


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


func test_a_dug_cell_is_a_rounded_pit_in_the_earth() -> void:
	"""Decisions 1913 and 1914: nothing dug, nothing is rounded and the ordered cells are pegged out in chalk; one dug
	cell is a floor DEPTH_M down, the eight cells round it drawn as wall patches -- the earth beside it rounded into, the
	ordered ones kept square at the top -- and the earth reads the World's ground per tile (a wet tile is not earth)."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_equal(earth.patch_count, 0, "nothing dug: nothing rounded")
	assert_equal(earth.floor_quads, 0, "and no floor")
	assert_equal(earth.mark_quads, 8 * 4, "eight ordered cells pegged out, four chalk lines each")
	_works.open_cell(1, Vector2i(6, 4))
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_equal(earth.floor_quads, 1, "the pit's floor")
	assert_equal(earth.patch_count, 8, "the eight cells round it, as walls")
	assert_equal(earth.mark_quads, 7 * 4, "seven cells pegged out")
	assert_true(is_equal_approx(earth.height_at(Vector2(6.5, 4.5)), -5.5), "the floor, a room's depth down")
	assert_true(is_equal_approx(earth.height_at(Vector2(7.5, 4.5)), -4.5), "an ordered cell stays square at the top")
	var rounded: float = earth.height_at(Vector2(6.5, 3.5))
	assert_true(rounded > -5.5 and rounded < -4.5, "the earth beside it is rounded into: %f" % rounded)
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(Earth.World.TILE_COUNT)
	kinds.fill(Earth.World.TERRAIN_LAND)
	kinds[Earth.World.MAP_TILES_X * 5 + 5] = Earth.World.TERRAIN_LAKE
	earth.set_kinds(kinds)
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_equal(earth.ground_mesh().get_surface_count(), 4, "the top, the floor, the walls, and the lake's tile mark")


func test_the_cell_being_dug_deepens() -> void:
	"""Decision 1914: the digging cell is drawn by a wall patch that moves from the top to its dug floor as the dig goes
	on -- a uniform a frame, no rebuild -- meeting the dug landing cell's floor at their edge; "Digging" says so, and
	the waiting count leaves it out."""
	_works.open_cell(1, Vector2i(4, 4))
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1, Vector3i(1, 5, 4))
	assert_equal(dug.earth.digging(), Vector3i(1, 5, 4), "drawn as being dug")
	var rebuilds: int = dug.earth.rebuilds
	dug.set_progress(0.25)
	var top: float = FLOORS[1] / Earth.UNITS_PER_M
	assert_true(is_equal_approx(dug.earth.height_at(Vector2(5.5, 4.5)), top - 0.25), "a quarter dug: a quarter deep")
	assert_true(is_equal_approx(dug.earth.height_at(Vector2(5.0, 4.5)), top - Earth.DEPTH_M),
		"its edge with the dug landing cell is that cell's floor")
	dug.set_progress(1.0)
	assert_true(is_equal_approx(dug.earth.height_at(Vector2(5.5, 4.5)), top - Earth.dug_depth_m(1.0)), "nearly through")
	assert_equal(dug.earth.rebuilds, rebuilds, "deepening rebuilds nothing")
	assert_equal(dug.earth.mark_quads, 6 * 4, "six cells pegged out (not the one being dug)")
	assert_true(dug.tags().has("Digging") and dug.tags().has("Proof of concept, free: 6 cells wait for the crew"), ", ".join(dug.tags()))
	dug.refresh(1)
	assert_equal(dug.earth.digging(), Earth.NO_CELL, "not digging: none drawn")
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


func test_a_fixed_size_tags_drawn_size_grows_with_its_depth() -> void:
	"""Decision 2002: a tag drawn at a constant screen size (the Surface's) is measured at its drawn size -- its world
	size grows with its depth, so it stays the same on screen; a plain tag's world size is its own at any depth."""
	var fixed: Label3D = _tag(true)
	var near: Vector2 = Tags.world_size(fixed, 10.0)
	assert_true(near.x > 0.0 and near.y > 0.0, "measured")
	assert_true(Tags.world_size(fixed, 20.0).is_equal_approx(near * 2.0), "twice as far: twice the size")
	var plain: Label3D = _tag(false)
	assert_true(Tags.world_size(plain, 20.0).is_equal_approx(Tags.world_size(plain, 10.0)), "plain: its own size")


func _tag(fixed: bool) -> Label3D:
	"""A tag reading "Way down", fixed size or not."""
	var tag: Label3D = Label3D.new()
	_nodes.append(tag)
	tag.text = "Way down"
	tag.font_size = 36
	tag.pixel_size = 0.0006 if fixed else 0.01
	tag.fixed_size = fixed
	return tag


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
	"""Review M5 (decision 1913), as rounded (decision 1914): the earth's top covers the planning area, the cell round
	it and the apron exactly, less each dug cell and each cell a wall patch draws (a strip lost inside or beside the
	works' box would leave a hole; one drawn twice would fight)."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	var side: float = BOUNDS.size.x + 2.0 + 2.0 * Earth.APRON_M
	var whole: float = side * side
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_true(is_equal_approx(_area(earth.built()[0]), whole), "nothing dug: all covered (%f)" % _area(earth.built()[0]))
	_works.open_cell(1, Vector2i(6, 4))
	_works.open_cell(1, Vector2i(7, 5))
	earth.draw(_works, 1, -4.5, Vector3i(1, 4, 4))
	var cut: float = 2.0 + earth.patch_count
	assert_true(is_equal_approx(_area(earth.built()[0]), whole - cut),
		"two pits and %d wall patches cut out (%f)" % [earth.patch_count, _area(earth.built()[0])])
	assert_true(is_equal_approx(_area(earth.built()[1]), 2.0), "and the two floors drawn")


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
	var floors: float = _area(dug.earth.built()[1])
	assert_true(is_equal_approx(floors, 4.0 + 4.0 - 4.0), "the landing's floors; none under the stairs down (%f)" % floors)


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


func test_staged_art_stands_in_for_the_procedural_pieces() -> void:
	"""Decision 1913: a staged mouth and stair flight replace the procedural ones (the flight stretched over a landing
	and the room's rise); with none (null), nothing changes."""
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.use_props(null)
	dug.set_art(null, Transform3D.IDENTITY, null, Transform3D.IDENTITY)
	assert_equal(dug.art, PackedStringArray(), "nothing staged: the procedural pieces")
	var bare: Dug.Props = Dug.Props.new()
	bare.load_from({})
	dug.use_props(bare)
	assert_equal(dug.art, PackedStringArray(), "an art-free table (CI): still the procedural pieces")
	assert_false(dug.earth.surface().get_shader_parameter(&"floor_textured")
		or dug.earth.surface().get_shader_parameter(&"wall_textured"), "and the procedural earth")
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.9, 0.5, 1.7)
	dug.set_art(box, Transform3D.IDENTITY, box, Transform3D.IDENTITY)
	assert_equal(dug.art, PackedStringArray(["mouth", "stairs"]), "both staged")
	var inset: float = Dug.ART_INSET_M
	var laid: AABB = Dug.stretched(box.get_aabb(), Transform3D.IDENTITY) * box.get_aabb()
	assert_true(laid.position.is_equal_approx(Vector3(inset, 0.0, inset))
		and laid.size.is_equal_approx(Vector3(2.0 - 2.0 * inset, 1.0, 2.0 - 2.0 * inset)),
		"laid over a landing, just inside its sides, a room deep: %s" % laid)
	dug.set_art(null, Transform3D.IDENTITY, BoxMesh.new(), Transform3D(Basis.from_scale(Vector3(1, 0, 1)), Vector3.ZERO))
	assert_equal(dug.art, PackedStringArray(), "a flat flight is not drawn; a second call starts again")


func test_a_staged_flight_rises_north_whichever_way_it_was_made() -> void:
	"""Review M1/M2 on b1bb4779: a wedge high at its north end, or one made the other way round, is laid rising north
	out of a landing; down a way it falls north from the floor."""
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(_works, FLOORS, Vector2i.ZERO, BOUNDS)
	for high_north: bool in [true, false]:
		dug.set_art(null, Transform3D.IDENTITY, _wedge(high_north), Transform3D.IDENTITY)
		var top: Vector3 = _highest(dug.stairs_mesh(true), 0)
		assert_true(top.z < 1.0 and is_equal_approx(top.y, 1.0), "rises north (%s): %s" % [high_north, top])
		var down_top: Vector3 = _highest(dug.stairs_mesh(false), 0)
		assert_true(down_top.z > 1.0 and is_equal_approx(down_top.y, 0.0), "falls north from the floor: %s" % down_top)
	assert_true(dug.stairs_mesh(false).get_surface_count() == 2, "in its cut")


func _wedge(high_north: bool) -> ArrayMesh:
	"""A sloped quad 2 m square, 0.5 m high at its north end (or its south)."""
	var near: float = 0.5 if high_north else 0.0
	var far: float = 0.5 - near
	var quads: Dug.Ways.Quads = Dug.Ways.Quads.new()
	quads.quad(Vector3(0, near, 0), Vector3(2, near, 0), Vector3(2, far, 2), Vector3(0, far, 2), Vector3.UP, Color.WHITE)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, StandardMaterial3D.new())
	return mesh


static func _highest(mesh: ArrayMesh, surface: int) -> Vector3:
	"""The highest vertex of one of `mesh`'s surfaces."""
	var top: Vector3 = Vector3(0, -INF, 0)
	for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
		top = point if point.y > top.y else top
	return top


func test_staged_textures_dress_the_earth() -> void:
	"""Decision 1913, as one surface (decision 1914): a staged floor texture dresses the top (darkened) and the dug
	floors; a missing wall texture leaves the walls procedural."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	earth.set_textures(texture, null)
	var surface: ShaderMaterial = earth.surface()
	assert_true(surface.get_shader_parameter(&"floor_texture") == texture
		and surface.get_shader_parameter(&"floor_textured") == true, "the floors and the top wear it")
	assert_equal(surface.get_shader_parameter(&"top_tint"), Earth.TOP_TINT, "the top darkened")
	assert_equal(surface.get_shader_parameter(&"wall_textured"), false, "no wall texture: the procedural wall")
	earth.draw(_works, 1, -4.5, Earth.NO_CELL)
	assert_true(earth.ground_mesh().surface_get_material(0) == surface, "drawn with it")


static func _area(built: Earth.Burrow) -> float:
	"""The area (m²) a surface's level quads cover, from their triangles."""
	var area: float = 0.0
	for at: int in range(0, built.indices.size(), 3):
		var a: Vector3 = built.vertices[built.indices[at]]
		var b: Vector3 = built.vertices[built.indices[at + 1]]
		area += (b - a).cross(built.vertices[built.indices[at + 2]] - a).length() / 2.0
	return area


class _Walker:
	extends "res://demo/cast/resident_brain.gd"
	## A brain stand-in for a trip: its walk speed is read; going in and out only flips `indoors` (no space here).

	func task_go_indoors(inside: bool, _building: int) -> void:
		"""In or out, with no walking space to tell."""
		indoors = inside
