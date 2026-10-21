extends "res://test/framework/test_case.gd"
## Decision 1914, rounded hand-dug walls: the field (the plan's distance, the fillet, a one-cell wall's crest, the
## coved section), Brendan's two rules on the drawn earth -- (a) every dug cell's whole floor stays dug and visible,
## (b) what is planned stays square until it is dug -- the wobble's fixed noise, a crack-free mesh, and the rebuild:
## only when the dug set changes, only the patches round a change, on a worker in the live demo.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Earth := preload("res://demo/build_panel/demo_build_earth.gd")
const Dug := preload("res://demo/build_panel/demo_build_dug.gd")
const Field := preload("res://demo/build_panel/demo_build_burrow_field.gd")
const Burrow := preload("res://demo/build_panel/demo_build_burrow.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 40, 40)
const FLOORS: PackedInt32Array = [0, -4608, -9728, -14848, -19968]
const TOP: float = -4.5
const FLOOR: float = -5.5
## Points sampled across a cell's closed square, each way (its edges and corners included).
const SAMPLES_ACROSS: int = 9
const ROOM: int = 2
const PASSAGE: int = 7

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free the nodes."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_the_section_is_coved_from_floor_to_top() -> void:
	"""Floor at or inside 0, top at or past BAND_M, falling all the way, flat where it meets the floor and the top."""
	assert_equal(Field.section(-0.2), 1.0, "inside: the floor")
	assert_equal(Field.section(0.0), 1.0, "at 0: the floor")
	assert_equal(Field.section(-0.03), 1.0, "just inside: still the flat floor")
	assert_equal(Field.section(Field.BAND_M), 0.0, "at the band's end: the top")
	var last: float = 1.0
	for k: int in range(1, 20):
		var at: float = Field.section(Field.BAND_M * k / 20.0)
		assert_true(at < last, "falls at %d" % k)
		last = at
	assert_true(1.0 - Field.section(0.01) < 0.002, "curves into the floor (no step)")
	assert_true(Field.section(Field.BAND_M - 0.01) < 0.002, "rounds over at the lip (no step)")


func test_the_constants_keep_the_rules() -> void:
	"""The wobble never reaches a cell (rule a); the whole wall stays within a cell of the dug cells; a one-cell wall's
	crest reaches the top; a square edge is narrower than the chalk's inset."""
	assert_true(is_equal_approx(Field.RADIUS_M, 1.0 / 3.0), "a third of a cell")
	assert_true(Field.WOBBLE_M < Field.OFFSET_M, "the wobble stays outside the cells")
	assert_true(Field.OFFSET_M + Field.BAND_M + Field.WOBBLE_M < 1.0, "the wall stays within a cell")
	assert_true(0.5 * Field.THIN_SCALE - Field.OFFSET_M - Field.WOBBLE_M >= Field.BAND_M - 0.0001, "a crest's top")
	assert_true(1.0 / Field.SAMPLES < Earth.CHALK_INSET_M, "a square edge stays inside the chalk")


func test_the_plan_is_the_distance_from_the_dug_cells() -> void:
	"""Exact to a dug side and to a dug corner (so a room's convex corner rounds outward); no dug neighbour, none."""
	assert_true(is_equal_approx(Field.base_g(Field.S, 0.3, 0.4), 0.6), "to the south side")
	assert_true(is_equal_approx(Field.base_g(Field.W, 0.3, 0.4), 0.3), "to the west side")
	assert_true(is_equal_approx(Field.base_g(Field.NE, 0.5, 0.5), sqrt(0.5)), "to the north-east corner")
	for point: Vector2 in [Vector2(0.6, 1.0), Vector2(0.0, 0.4), Vector2(0.6, 0.0).rotated(-PI / 4.0) + Vector2(0.0, 1.0)]:
		assert_true(absf(Field.base_g(Field.SW, point.x, point.y) - 0.6) < 0.0001, "0.6 m round the corner at %s" % point)
	assert_equal(Field.base_g(0, 0.5, 0.5), INF, "no dug neighbour: no distance")


func test_an_earth_corner_between_two_dug_sides_is_filleted() -> void:
	"""Where dug cells north and east meet round an earth corner, the field is pulled in near the corner (the mouth
	flares) and is exact again at the cell's far sides (no seam with its neighbours)."""
	var mask: int = Field.N | Field.E
	assert_true(Field.base_g(mask, 0.85, 0.15) < 0.15 - 0.05, "pulled in by the corner")
	assert_true(is_equal_approx(Field.base_g(mask, 0.0, 0.7), 0.7), "exact at the far west side")
	assert_true(is_equal_approx(Field.base_g(mask, 0.3, 1.0), 0.7), "exact at the far south side")


func test_a_one_cell_wall_keeps_its_crest() -> void:
	"""Two rooms one earth cell apart: the wall between them reaches the top along its middle, however it wobbles."""
	var field: Field = Field.new()
	field.setup(Rect2i(0, 0, 9, 9))
	for z: int in range(2, 7):
		for x: int in [3, 5]:
			field.set_kind(Vector2i(x, z), Field.DUG)
	for gz: int in range(2 * Field.SAMPLES, 7 * Field.SAMPLES + 1):
		assert_equal(field.depth_at(4 * Field.SAMPLES + (Field.SAMPLES >> 1), gz), 0.0, "crest at lattice row %d" % gz)


func test_fill_patch_matches_the_field_point_by_point() -> void:
	"""A whole patch at once gives the numbers the field gives point by point (to a float32's precision), round every
	kind of cell, the field's edge cells too (review M-b: their apron lies on negative lattice points)."""
	var field: Field = _scattered(1914)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(Field.SPAN * Field.SPAN)
	var wrong: int = 0
	for cz: int in 16:
		for cx: int in 16:
			field.fill_patch(Vector2i(cx, cz) + field.origin, heights)
			for j: int in Field.SPAN:
				for i: int in Field.SPAN:
					var want: float = field.depth_at(cx * Field.SAMPLES - 1 + i, cz * Field.SAMPLES - 1 + j)
					wrong += 0 if absf(heights[j * Field.SPAN + i] - want) < 0.000001 else 1
	assert_equal(wrong, 0, "every point the same")


func test_every_dug_cell_keeps_its_whole_floor() -> void:
	"""Rule (a), on the drawn mesh: for every layout, every dug cell's closed square -- edges and corners too -- is at
	the floor's depth (the rounding carves into the earth, never into a cell)."""
	for layout: Array in _layouts():
		var works: Works = _works_of(layout)
		var earth: Earth = _earth(works, layout[2] if layout.size() > 2 else Earth.NO_CELL)
		for share: float in [0.0, 1.0]:
			earth.set_progress(share)
			assert_equal(_hidden_points(earth, works), 0, "%s at %f: every dug cell whole" % [layout[0], share])


func test_the_field_never_hides_a_dug_cell() -> void:
	"""Rule (a), on the field: every lattice point on a dug cell's closed square is the floor, among cells of every
	kind."""
	var field: Field = _scattered(7)
	var wrong: int = 0
	for cz: int in field.size.y:
		for cx: int in field.size.x:
			if field.kind_of(field.origin + Vector2i(cx, cz)) != Field.DUG:
				continue
			for j: int in Field.ROW:
				for i: int in Field.ROW:
					wrong += 0 if field.depth_at(cx * Field.SAMPLES + i, cz * Field.SAMPLES + j) == 1.0 else 1
	assert_equal(wrong, 0, "no lattice point of a dug cell above the floor")


func test_the_walls_have_no_cracks() -> void:
	"""Every patch vertex at one place has one height (patches share their edges exactly); a patch edge on a dug cell is
	its floor, on the plain top the top's height -- with the cell being dug at the start and the end of its dig."""
	var works: Works = _works_of(_layouts()[1])
	var earth: Earth = _earth(works, Vector3i(1, 16, 13))
	for share: float in [0.0, 1.0]:
		var walls: Burrow = earth.built()[2]
		var seen: Dictionary = {}
		var cracks: int = 0
		for at: int in walls.vertices.size():
			var point: Vector3 = walls.vertices[at]
			var key: Vector2i = Vector2i(roundi(point.x * Field.SAMPLES), roundi(point.z * Field.SAMPLES))
			var y: float = point.y + share * walls.uv2s[at].x
			if seen.has(key) and absf(float(seen[key]) - y) > 0.00001:
				cracks += 1
			seen[key] = y
		assert_equal(cracks, 0, "at %f" % share)
	for share: float in [0.0, 1.0]:
		assert_equal(_seams(earth, works, share), 0, "patch edges meet the floors and the top at %f" % share)


func test_the_walls_face_into_the_room() -> void:
	"""The rounded walls north and west of a dug room slope down into it: their normals lean south and east, up out of
	the cut."""
	var works: Works = _works_of(_layouts()[0])
	var walls: Burrow = _earth(works, Earth.NO_CELL).built()[2]
	var leaning: int = 0
	var sloped: int = 0
	for at: int in walls.vertices.size():
		var point: Vector3 = walls.vertices[at]
		if point.x > 11.2 and point.x < 14.8 and point.z > 9.2 and point.z < 9.95 and point.y < TOP - 0.1:
			sloped += 1
			leaning += 1 if walls.normals[at].z > 0.0 and walls.normals[at].y > 0.0 else 0
	assert_true(sloped > 10 and leaning == sloped, "%d of %d sloped points lean south" % [leaning, sloped])
	leaning = 0
	sloped = 0
	for at: int in walls.vertices.size():
		var point: Vector3 = walls.vertices[at]
		if point.z > 10.8 and point.z < 13.2 and point.x > 9.2 and point.x < 9.95 and point.y < TOP - 0.1:
			sloped += 1
			leaning += 1 if walls.normals[at].x > 0.0 and walls.normals[at].y > 0.0 else 0
	assert_true(sloped > 10 and leaning == sloped, "%d of %d sloped points on the west lean east" % [leaning, sloped])


func test_the_top_and_the_water_marks_cover_the_rest() -> void:
	"""With a wet tile on the level, the earth's top and the water marks together still cover the planning area, its
	rim and the apron exactly, less the dug cells and the wall patches (no mark drawn twice, none drawn backwards)."""
	var works: Works = _works_of(_layouts()[0])
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(Earth.World.TILE_COUNT)
	kinds.fill(Earth.World.TERRAIN_LAND)
	for tile: int in [Earth.World.MAP_TILES_X * 5 + 4, Earth.World.MAP_TILES_X * 6 + 9, Earth.World.MAP_TILES_X * 2 + 2]:
		kinds[tile] = Earth.World.TERRAIN_LAKE
	earth.set_kinds(kinds)
	earth.draw(works, 1, TOP, Earth.NO_CELL)
	var side: float = BOUNDS.size.x + 2.0 + 2.0 * Earth.APRON_M
	var covered: float = 0.0
	var mesh: ArrayMesh = earth.ground_mesh()
	for surface: int in mesh.get_surface_count():
		if surface != 1 and surface != 2:
			covered += _surface_area(mesh, surface)
	assert_true(is_equal_approx(covered, side * side - 24.0 - earth.patch_count), "covered once: %f" % covered)


func test_the_wobble_is_fixed() -> void:
	"""The same noise from the same seed every time; within WOBBLE_M either way and not flat; two earths drawing the same
	works draw the very same walls."""
	assert_equal(Field._make_noise(), Field._make_noise(), "the same table every run")
	var low: float = INF
	var high: float = -INF
	for z: int in 64:
		for x: int in 64:
			var wobble: float = Field.wobble(x * 3, z * 5)
			low = minf(low, wobble)
			high = maxf(high, wobble)
	assert_true(low >= -Field.WOBBLE_M and high <= Field.WOBBLE_M, "within reach: %f to %f" % [low, high])
	assert_true(low < -0.4 * Field.WOBBLE_M and high > 0.4 * Field.WOBBLE_M, "and it wobbles")
	var works: Works = _works_of(_layouts()[1])
	var first: Burrow = _earth(works, Earth.NO_CELL).built()[2]
	var second: Burrow = _earth(works, Earth.NO_CELL).built()[2]
	assert_true(first.vertices == second.vertices and first.normals == second.normals, "the same walls")


func test_what_is_planned_stays_square() -> void:
	"""Rule (b): ordered cells are never rounded -- an ordered room alone draws no wall at all and its cells are the top;
	beside a dug cell, an ordered cell is the top past one lattice step from its edge, under its chalk."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	works.order_room(1, _rect(Rect2i(10, 10, 4, 3)), ROOM)
	var earth: Earth = _earth(works, Earth.NO_CELL)
	assert_equal(earth.patch_count, 0, "nothing dug: nothing rounded")
	assert_equal(earth.mark_quads, 12 * 4, "every cell pegged out in chalk")
	works.open_cell(1, Vector2i(10, 10))
	earth.draw(works, 1, TOP, Earth.NO_CELL)
	for point: Vector2 in [Vector2(11.0 + 1.0 / Field.SAMPLES, 10.5), Vector2(11.5, 10.5), Vector2(10.5, 11.2)]:
		assert_true(is_equal_approx(earth.height_at(point), TOP), "an ordered cell at the top at %s" % point)
	assert_true(earth.height_at(Vector2(10.5, 9.7)) < TOP - 0.05, "the earth north of the dug cell is rounded into")


func test_the_rounding_grows_as_cells_are_dug() -> void:
	"""As a room is dug cell by cell, more of the earth round it is drawn as rounded wall; the earth just outside a dug
	wall is below the top (the curve carries outward)."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	var cells: PackedInt32Array = _rect(Rect2i(10, 10, 5, 2))
	works.order_room(1, cells, ROOM)
	var earth: Earth = _earth(works, Earth.NO_CELL)
	var last: int = -1
	var earth_patches: int = 0
	for at: int in range(0, cells.size(), 2):
		works.open_cell(1, Vector2i(cells[at], cells[at + 1]))
		earth.draw(works, 1, TOP, Earth.NO_CELL)
		earth_patches = _patches_on(earth, works, Works.EARTH)
		assert_true(earth_patches > last, "more rounded earth after cell %d" % at)
		last = earth_patches
	assert_true(earth.height_at(Vector2(12.5, 9.75)) < TOP - 0.2, "just outside the north wall: carved outward")


func test_a_rebuild_happens_only_when_the_dug_set_changes() -> void:
	"""The dug view draws the earth again only when the works, the level or the cell being dug change; deepening is a
	uniform; a redraw with nothing changed makes no wall patch, and a cell dug in a big room remakes only those round
	it."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	works.order_room(1, _rect(Rect2i(4, 4, 24, 12)), ROOM)
	var order: PackedInt32Array = PackedInt32Array()
	works.cells_into(1, Works.ORDERED, order)
	for at: int in range(0, order.size() - 2, 2):
		works.open_cell(1, Vector2i(order[at], order[at + 1]))
	var dug: Dug = Dug.new()
	_nodes.append(dug)
	dug.configure(works, FLOORS, Vector2i.ZERO, BOUNDS)
	dug.refresh(1)
	var rebuilds: int = dug.earth.rebuilds
	dug.refresh(1)
	dug.set_progress(0.5)
	assert_equal(dug.earth.rebuilds, rebuilds, "a still frame and a deepening rebuild nothing")
	dug.earth.draw(works, 1, FLOORS[1] / Earth.UNITS_PER_M, Earth.NO_CELL)
	assert_equal(dug.earth.patches_made, 0, "nothing changed: every wall patch kept")
	works.open_cell(1, Vector2i(order[order.size() - 2], order[order.size() - 1]))
	dug.refresh(1)
	assert_equal(dug.earth.rebuilds, rebuilds + 2, "a dug cell rebuilds")
	assert_true(dug.earth.patches_made <= 25, "only the patches round it: %d" % dug.earth.patches_made)


func test_kept_patches_match_fresh_ones() -> void:
	"""Patches kept from earlier draws are the very patches a fresh earth makes, as the dig moves from cell to cell and
	cells open: positions, normals, how far each point moves while dug, and its dug normal."""
	var works: Works = _works_of(_layouts()[7])
	var earth: Earth = _earth(works, Earth.NO_CELL)
	var steps: Array[Vector2i] = [Vector2i(14, 10), Vector2i(14, 11), Vector2i(15, 11), Vector2i(16, 12)]
	for k: int in steps.size():
		earth.draw(works, 1, TOP, Vector3i(1, steps[k].x, steps[k].y))
		var fresh: Burrow = _earth(works, Vector3i(1, steps[k].x, steps[k].y)).built()[2]
		var kept: Burrow = earth.built()[2]
		assert_true(kept.vertices == fresh.vertices and kept.normals == fresh.normals and kept.uv2s == fresh.uv2s
			and kept.colors == fresh.colors, "step %d: the same walls" % k)
		if k % 2 == 1:
			works.open_cell(1, steps[k - 1])


func test_kept_patches_match_fresh_ones_as_a_scattered_dig_goes_on() -> void:
	"""Across a dig wandering through scattered ordered and dug cells, every draw's kept walls are a fresh earth's."""
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1914
	var works: Works = Works.new()
	works.configure(BOUNDS)
	var ordered: Array[Vector2i] = []
	for z: int in range(10, 20):
		for x: int in range(10, 20):
			if random.randi_range(0, 2) > 0:
				works.order_room(1, PackedInt32Array([x, z]), ROOM)
				ordered.append(Vector2i(x, z))
	var earth: Earth = _earth(works, Earth.NO_CELL)
	var same: int = 0
	for step: int in 24:
		var cell: Vector2i = ordered[random.randi_range(0, ordered.size() - 1)]
		earth.draw(works, 1, TOP, Vector3i(1, cell.x, cell.y))
		var fresh: Burrow = _earth(works, Vector3i(1, cell.x, cell.y)).built()[2]
		var kept: Burrow = earth.built()[2]
		same += 1 if kept.vertices == fresh.vertices and kept.normals == fresh.normals and kept.uv2s == fresh.uv2s \
			and kept.colors == fresh.colors else 0
		works.open_cell(1, cell)
	assert_equal(same, 24, "every draw the same walls")


func test_a_new_cell_being_dug_starts_at_the_top() -> void:
	"""A rebuild for a new cell being dug shows it at the top again, whatever depth the last one reached."""
	var works: Works = _works_of(_layouts()[7])
	var earth: Earth = _earth(works, Vector3i(1, 14, 11))
	earth.set_progress(0.9)
	works.open_cell(1, Vector2i(14, 11))
	earth.draw(works, 1, TOP, Vector3i(1, 15, 11))
	assert_true(is_equal_approx(earth.height_at(Vector2(15.5, 11.5)), TOP - Earth.dug_depth_m(0.0)), "at the top")


func test_the_threaded_rebuild_shows_the_same_earth() -> void:
	"""On a worker, a build is in flight until `poll` shows it (as the dug view does each frame); a request made
	meanwhile waits and is built after it; what is shown is what a build on the spot draws; and once shown, the dig
	deepens again."""
	var works: Works = _works_of(_layouts()[1])
	var earth: Earth = _earth(works, Vector3i(1, 16, 13))
	earth.threaded = true
	works.open_cell(1, Vector2i(16, 13))
	earth.request(works, 1, TOP, Vector3i(1, 17, 13))
	assert_true(earth.busy(), "in flight")
	works.open_cell(1, Vector2i(17, 13))
	earth.request(works, 1, TOP, Vector3i(1, 16, 14))
	_until_shown(earth)
	assert_false(earth.busy(), "shown, and the waiting request too")
	assert_equal(earth.digging(), Vector3i(1, 16, 14), "the newest cell drawn as being dug")
	var at_once: Earth = _earth(works, Vector3i(1, 16, 14))
	assert_true(earth.built()[2].vertices == at_once.built()[2].vertices
		and earth.built()[2].uv2s == at_once.built()[2].uv2s, "the same walls as a build on the spot")
	earth.set_progress(0.5)
	assert_true(is_equal_approx(earth.height_at(Vector2(16.5, 14.5)), TOP - 0.5), "and the dig deepens again")


func test_a_cell_dug_while_its_build_is_in_flight_stays_down() -> void:
	"""Review M-a: while a build is in flight, the cell shown being dug keeps its depth; when that build is shown with a
	newer request for another cell waiting (the cell it shows being dug is dug by now), it is not lifted back to the
	top."""
	var works: Works = _works_of(_layouts()[1])
	var earth: Earth = _earth(works, Vector3i(1, 16, 13))
	earth.set_progress(1.0)
	earth.threaded = true
	works.open_cell(1, Vector2i(16, 13))
	earth.request(works, 1, TOP, Vector3i(1, 17, 13))
	earth.set_progress(0.1)
	assert_true(is_equal_approx(earth.height_at(Vector2(16.5, 13.5)), TOP - Earth.dug_depth_m(1.0)), "held")
	while not WorkerThreadPool.is_task_completed(int(earth.get("_task"))):
		OS.delay_usec(200)
	works.open_cell(1, Vector2i(17, 13))
	earth.request(works, 1, TOP, Vector3i(1, 16, 14))
	earth.poll()
	assert_true(earth.height_at(Vector2(17.5, 13.5)) < TOP - 0.9, "the next cell, dug meanwhile, stays down")
	_until_shown(earth)
	assert_true(is_equal_approx(earth.height_at(Vector2(17.5, 13.5)), FLOOR), "and is floor once shown")


func test_a_dig_moving_on_behind_a_build_keeps_the_cell_down() -> void:
	"""A build in flight for the same cell being dug (the works changed elsewhere) holds nothing; if that cell is dug and
	the next one waits behind the build, the cell shown keeps its depth until the next build is shown."""
	var works: Works = _works_of(_layouts()[1])
	var earth: Earth = _earth(works, Vector3i(1, 16, 13))
	earth.set_progress(1.0)
	earth.threaded = true
	works.order_room(1, _rect(Rect2i(20, 20, 2, 2)), ROOM)
	earth.request(works, 1, TOP, Vector3i(1, 16, 13))
	works.open_cell(1, Vector2i(16, 13))
	earth.request(works, 1, TOP, Vector3i(1, 17, 13))
	earth.set_progress(0.1)
	assert_true(is_equal_approx(earth.height_at(Vector2(16.5, 13.5)), TOP - Earth.dug_depth_m(1.0)), "kept down")
	_until_shown(earth)
	assert_equal(earth.digging(), Vector3i(1, 17, 13), "the next cell shown being dug")


func test_the_works_hand_the_build_a_copy() -> void:
	"""Review H1: the states a build reads are a copy; the mole digging on does not change them under it."""
	var works: Works = _works_of(_layouts()[7])
	var states: PackedByteArray = works.level_states(1)
	var at: int = (11 - works.area().position.y) * works.area().size.x + 14 - works.area().position.x
	assert_equal(states[at], Works.ORDERED, "ordered when read")
	works.open_cell(1, Vector2i(14, 11))
	assert_equal(states[at], Works.ORDERED, "still, after the cell is dug")
	assert_equal(works.level_states(1)[at], Works.OPEN, "a fresh read sees it dug")


func test_an_earth_freed_or_given_kinds_mid_build_waits_for_it() -> void:
	"""Freed with a build in flight, the earth waits for its worker; handed the World's kinds, it shows the build
	first (the build reads them)."""
	var works: Works = _works_of(_layouts()[0])
	var earth: Earth = _earth(works, Earth.NO_CELL)
	earth.threaded = true
	works.order_room(1, _rect(Rect2i(16, 10, 2, 2)), ROOM)
	earth.request(works, 1, TOP, Earth.NO_CELL)
	earth.set_kinds(PackedByteArray())
	assert_false(earth.busy(), "the build shown before the kinds change")
	earth.request(works, 1, TOP, Vector3i(1, 16, 10))
	assert_true(earth.busy(), "another in flight")
	earth.free()
	assert_false(is_instance_valid(earth), "freed without waiting on anyone")


func test_kept_patches_follow_the_level_and_the_water() -> void:
	"""Patches kept are dropped when the level's top moves, and remade when a cell turns wet -- an earth cell, or an
	ordered one already kept square: the walls are always those a fresh earth draws."""
	var works: Works = _works_of(_layouts()[0])
	works.order_room(1, _rect(Rect2i(16, 10, 2, 2)), ROOM)
	var earth: Earth = _earth(works, Earth.NO_CELL)
	earth.draw(works, 1, TOP - 5.0, Earth.NO_CELL)
	var fresh: Earth = Earth.new()
	_nodes.append(fresh)
	fresh.configure(Vector2i.ZERO, BOUNDS)
	fresh.draw(works, 1, TOP - 5.0, Earth.NO_CELL)
	assert_true(earth.built()[2].vertices == fresh.built()[2].vertices, "another level's top: walls at its height")
	earth.draw(works, 1, TOP, Earth.NO_CELL)
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(Earth.World.TILE_COUNT)
	kinds.fill(Earth.World.TERRAIN_LAND)
	kinds[Earth.World.MAP_TILES_X * 4 + 4] = Earth.World.TERRAIN_LAKE
	kinds[Earth.World.MAP_TILES_X * 5 + 8] = Earth.World.TERRAIN_LAKE
	for each: Earth in [earth, fresh]:
		each.set_kinds(kinds)
		each.draw(works, 1, TOP, Earth.NO_CELL)
	assert_true(earth.built()[2].uvs == fresh.built()[2].uvs and earth.built()[2].vertices == fresh.built()[2].vertices,
		"a cell turned wet: its walls remade")


func test_the_dug_normal_is_the_normal_once_dug() -> void:
	"""Each wall vertex round the cell being dug carries, as its dug normal, the normal the wall has once that cell is
	dug (to the colour's 8-bit precision)."""
	var works: Works = _works_of(_layouts()[7])
	var digging: Earth = _earth(works, Vector3i(1, 14, 11))
	works.open_cell(1, Vector2i(14, 11))
	var dug: Burrow = _earth(works, Earth.NO_CELL).built()[2]
	var normal_at: Dictionary = {}
	for at: int in dug.vertices.size():
		normal_at[Vector2i(roundi(dug.vertices[at].x * 8.0), roundi(dug.vertices[at].z * 8.0))] = dug.normals[at]
	var walls: Burrow = digging.built()[2]
	var compared: int = 0
	var wrong: int = 0
	for at: int in walls.vertices.size():
		var key: Vector2i = Vector2i(roundi(walls.vertices[at].x * 8.0), roundi(walls.vertices[at].z * 8.0))
		if walls.uv2s[at].x == 0.0 or not normal_at.has(key):
			continue
		var colour: Color = walls.colors[at]
		var decoded: Vector3 = Vector3(colour.r, colour.g, colour.b) * 2.0 - Vector3.ONE
		compared += 1
		wrong += 0 if decoded.distance_to(normal_at[key]) < 0.02 else 1
	assert_true(compared > 20 and wrong == 0, "%d of %d moving points with the wrong dug normal" % [wrong, compared])


func test_stairs_rise_into_square_earth() -> void:
	"""The earth a dug landing's stairs rise into is kept square: its top meets the top tread, neither rounded down
	under it nor bulging over it."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	works.order_way_down(0, Vector2i(10, 10))
	for offset: Vector2i in Works.QUAD:
		works.open_cell(1, Vector2i(10, 10) + offset)
	var earth: Earth = _earth(works, Earth.NO_CELL)
	for x: float in [10.2, 10.5, 11.0, 11.5, 11.8]:
		assert_true(is_equal_approx(earth.height_at(Vector2(x, 10.0 - 2.0 / Field.SAMPLES)), TOP), "head at x %f" % x)
	assert_true(earth.height_at(Vector2(9.7, 10.5)) < TOP - 0.05, "the landing's west side is rounded")


func test_the_floor_grid_shows_on_dug_floors_only() -> void:
	"""The grid is a uniform (no rebuild) and only the dug floors carry it (the rounded walls and the top do not)."""
	var works: Works = _works_of(_layouts()[0])
	var earth: Earth = _earth(works, Earth.NO_CELL)
	var rebuilds: int = earth.rebuilds
	earth.set_grid(true)
	assert_true(earth.grid_shown() and float(earth.surface().get_shader_parameter(&"grid_alpha")) > 0.0, "shown")
	assert_equal(earth.rebuilds, rebuilds, "no rebuild")
	for k: int in 3:
		var marked: bool = true
		for uv: Vector2 in earth.built()[k].uvs:
			marked = marked and uv.x == (1.0 if k == 1 else 0.0)
		assert_true(marked, "surface %d: grid only on the floors" % k)
	earth.set_grid(false)
	assert_equal(float(earth.surface().get_shader_parameter(&"grid_alpha")), 0.0, "hidden")


func test_wet_cells_stay_square_and_keep_their_mark() -> void:
	"""A wet tile beside a room is never rounded into: it stays at the top, carrying the water mark."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	var cells: PackedInt32Array = _rect(Rect2i(12, 10, 3, 3))
	works.order_room(1, cells, ROOM)
	for at: int in range(0, cells.size(), 2):
		works.open_cell(1, Vector2i(cells[at], cells[at + 1]))
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(Earth.World.TILE_COUNT)
	kinds.fill(Earth.World.TERRAIN_LAND)
	kinds[Earth.World.MAP_TILES_X * 5 + 5] = Earth.World.TERRAIN_LAKE
	earth.set_kinds(kinds)
	earth.draw(works, 1, TOP, Earth.NO_CELL)
	assert_true(is_equal_approx(earth.height_at(Vector2(11.5, 11.5)), TOP), "the wet cell west of the room: the top")
	var walls: Burrow = earth.built()[2]
	var marked: int = 0
	var below: int = 0
	for at: int in walls.uvs.size():
		marked += 1 if walls.uvs[at].y == 1.0 else 0
		below += 1 if walls.uvs[at].y == 1.0 and not is_equal_approx(walls.vertices[at].y, TOP) else 0
	assert_true(marked > 0 and below == 0, "its patch carries the water mark, on its top only (%d below)" % below)
	assert_equal(_hidden_points(earth, works), 0, "and the room is whole")


# --- helpers ---------------------------------------------------------------------------------------------------

func _layouts() -> Array:
	"""[name, [rect, type, dug?]...(, the cell being dug)]: a room, an L of room and passage, a lozenge, one cell, a
	diagonal pinch, two rooms a cell apart, a room at the planning area's edge, and a dig in progress."""
	return [
		["room", [[Rect2i(10, 10, 6, 4), ROOM, true]]],
		["L", [[Rect2i(10, 10, 4, 4), ROOM, true], [Rect2i(14, 11, 4, 2), PASSAGE, true], [Rect2i(16, 13, 2, 4), PASSAGE,
			false]], Vector3i(1, 16, 13)],
		["lozenge", [[Rect2i(10, 12, 7, 1), ROOM, true], [Rect2i(11, 11, 5, 3), ROOM, true], [Rect2i(13, 10, 1, 5), ROOM,
			true]]],
		["one cell", [[Rect2i(10, 10, 1, 1), ROOM, true]]],
		["pinch", [[Rect2i(10, 10, 2, 2), ROOM, true], [Rect2i(12, 12, 2, 2), ROOM, true]]],
		["wall", [[Rect2i(10, 10, 3, 5), ROOM, true], [Rect2i(14, 10, 3, 5), ROOM, true]]],
		["edge", [[Rect2i(0, 0, 3, 2), ROOM, true], [Rect2i(37, 38, 3, 2), ROOM, true]]],
		["digging", [[Rect2i(10, 10, 4, 3), ROOM, true], [Rect2i(14, 10, 3, 3), ROOM, false]], Vector3i(1, 14, 11)],
	]


func _works_of(layout: Array) -> Works:
	"""The works a layout describes on level 1: each rect ordered, and dug where it says."""
	var works: Works = Works.new()
	works.configure(BOUNDS)
	for part: Array in layout[1]:
		var cells: PackedInt32Array = _rect(part[0])
		works.order_room(1, cells, part[1])
		for at: int in range(0, cells.size(), 2):
			if part[2]:
				works.open_cell(1, Vector2i(cells[at], cells[at + 1]))
	return works


func _earth(works: Works, digging: Vector3i) -> Earth:
	"""An earth drawing level 1 of `works` with `digging` the cell being dug."""
	var earth: Earth = Earth.new()
	_nodes.append(earth)
	earth.configure(Vector2i.ZERO, BOUNDS)
	earth.draw(works, 1, TOP, digging)
	return earth


static func _rect(rect: Rect2i) -> PackedInt32Array:
	"""A rect's cells, canonical pairs."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells.append_array(PackedInt32Array([x, z]))
	return cells


static func _hidden_points(earth: Earth, works: Works) -> int:
	"""Points of dug cells' closed squares drawn anywhere but at the floor's depth."""
	var cells: PackedInt32Array = PackedInt32Array()
	works.cells_into(1, Works.OPEN, cells)
	var hidden: int = 0
	for at: int in range(0, cells.size(), 2):
		for j: int in SAMPLES_ACROSS:
			for i: int in SAMPLES_ACROSS:
				var point: Vector2 = Vector2(cells[at], cells[at + 1]) + Vector2(i, j) / (SAMPLES_ACROSS - 1)
				hidden += 0 if absf(earth.height_at(point) - FLOOR) < 0.00001 else 1
	return hidden


static func _seams(earth: Earth, works: Works, share: float) -> int:
	"""Patch vertices (the cell being dug `share` of the way down) on a dug cell's edge not at the floor, or on a cell
	drawn as plain top not at the top."""
	var walls: Burrow = earth.built()[2]
	var drawn: Dictionary = {}
	for cell: Vector2i in walls.patch_cells:
		drawn[cell] = true
	var seams: int = 0
	for at: int in walls.vertices.size():
		var point: Vector3 = walls.vertices[at]
		var y: float = point.y + share * walls.uv2s[at].x
		for near: Vector2i in _cells_touching(Vector2(point.x, point.z)):
			if works.state(1, near) == Works.OPEN and not is_equal_approx(y, FLOOR):
				seams += 1
			elif works.state(1, near) != Works.OPEN and not drawn.has(near) and not is_equal_approx(y, TOP):
				seams += 1
	return seams


static func _cells_touching(point: Vector2) -> Array[Vector2i]:
	"""The cells whose closed squares hold `point`."""
	var out: Array[Vector2i] = []
	for dz: int in [-1, 0]:
		for dx: int in [-1, 0]:
			var cell: Vector2i = Vector2i(floori(point.x + 0.000001) + dx, floori(point.y + 0.000001) + dz)
			if Rect2(Vector2(cell), Vector2.ONE).grow(0.000001).has_point(point) and not out.has(cell):
				out.append(cell)
	return out


static func _until_shown(earth: Earth) -> void:
	"""Poll `earth` as the dug view does each frame until no build is in flight or waiting."""
	for tries: int in 10000:
		earth.poll()
		if not earth.busy():
			return
		OS.delay_usec(500)


static func _surface_area(mesh: ArrayMesh, surface: int) -> float:
	"""The area (m²) one surface of `mesh` covers, from its triangles."""
	var arrays: Array = mesh.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area: float = 0.0
	for at: int in range(0, indices.size(), 3):
		var a: Vector3 = points[indices[at]]
		area += (points[indices[at + 1]] - a).cross(points[indices[at + 2]] - a).length() / 2.0
	return area


static func _patches_on(earth: Earth, works: Works, state: int) -> int:
	"""Wall patches drawn on cells in `state`."""
	var count: int = 0
	for cell: Vector2i in (earth.built()[2] as Burrow).patch_cells:
		count += 1 if works.state(1, cell) == state else 0
	return count


func _scattered(seed_value: int) -> Field:
	"""A field of 16 × 16 cells from (3, 2) with dug, kept-square and earth cells scattered by a fixed seed."""
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var field: Field = Field.new()
	field.setup(Rect2i(3, 2, 16, 16))
	for z: int in range(2, 18):
		for x: int in range(3, 19):
			var roll: int = random.randi_range(0, 9)
			field.set_kind(Vector2i(x, z), Field.DUG if roll < 5 else Field.HARD if roll < 6 else Field.EARTH)
	return field
