extends "res://test/framework/test_case.gd"
## The residents by cell (resident_cells.gd, decision 1004) and the walker's questions that read them (cast_space.gd
## NEIGHBOURS BY CELL): the cells keep everyone as they move, a look gathers everyone near (sorted when asked), and
## `separation`, `constrain`, `standing_blocks` and `surface_occupied` give exactly the answers the old scan over every
## resident gave -- checked against that scan, kept here, over a crowd moved about at random. No scene tree, no assets.

const CellsScript := preload("res://demo/cast/resident_cells.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")

const SEED: int = 1004
const CROWD: int = 80
const ROUNDS: int = 300


# --- the cells -----------------------------------------------------------------------------------------

func test_a_look_gathers_everyone_in_the_cells_it_overlaps_sorted_when_asked() -> void:
	"""Residents kept as they are added; a look over a box gathers each one standing in it, once; sorted, in ascending
	order; a box over more than MAX_CELLS cells gathers everyone in order."""
	var cells := CellsScript.new()
	var at := PackedVector2Array([Vector2(0.5, 0.5), Vector2(9.0, 9.0), Vector2(1.5, 0.2), Vector2(-0.5, 0.5),
		Vector2(0.1, 3.9)])
	for p in at:
		cells.add(p)
	assert_equal(cells.count(), 5, "five kept")
	var out := PackedInt32Array()
	out.resize(5)
	var n := cells.gather(Vector2(-1.0, -1.0), Vector2(1.9, 1.9), out, true)
	assert_equal(out.slice(0, n), PackedInt32Array([0, 2, 3]), "the three in the box's cells, ascending")
	n = cells.gather(Vector2(-100.0, -100.0), Vector2(100.0, 100.0), out, false)
	assert_equal(out.slice(0, n), PackedInt32Array([0, 1, 2, 3, 4]), "a wide box: everyone, in order")


func test_a_resident_is_found_in_its_new_cell_and_not_its_old() -> void:
	"""`move` across a cell's edge takes a resident out of its old bucket and into its new one; a move within its cell
	changes nothing."""
	var cells := CellsScript.new()
	cells.add(Vector2(0.5, 0.5))
	cells.add(Vector2(0.7, 0.5))
	var out := PackedInt32Array()
	out.resize(2)
	cells.move(0, Vector2(1.0, 1.0))
	assert_equal(cells.gather(Vector2(0.1, 0.1), Vector2(0.2, 0.2), out, true), 2, "both still in the first cell")
	cells.move(0, Vector2(6.5, 6.5))
	var n := cells.gather(Vector2(0.1, 0.1), Vector2(0.2, 0.2), out, true)
	assert_equal(out.slice(0, n), PackedInt32Array([1]), "the one moved is gone from it")
	n = cells.gather(Vector2(6.1, 6.1), Vector2(6.2, 6.2), out, true)
	assert_equal(out.slice(0, n), PackedInt32Array([0]), "and found in its new cell")
	cells.clear()
	assert_equal(cells.count(), 0, "cleared")


func test_a_look_never_misses_anyone_near_after_many_moves() -> void:
	"""Eighty residents moved at random for 300 rounds: every look round a point gathers each resident within 3 m of it
	(a superset is allowed), with no one twice, and sorted when asked."""
	var cells := CellsScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var at := PackedVector2Array()
	for i in CROWD:
		at.append(Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0)))
		cells.add(at[i])
	var out := PackedInt32Array()
	out.resize(CROWD)
	var missed := 0
	var unsorted := 0
	for round_index in ROUNDS:
		var i := rng.randi_range(0, CROWD - 1)
		at[i] += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		cells.move(i, at[i])
		var q := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		var n := cells.gather(q - Vector2(3.0, 3.0), q + Vector2(3.0, 3.0), out, true)
		var got := out.slice(0, n)
		for k in range(1, n):
			unsorted += 1 if got[k - 1] >= got[k] else 0
		for j in CROWD:
			if at[j].distance_to(q) <= 3.0 and not got.has(j):
				missed += 1
	assert_equal([missed, unsorted], [0, 0], "nobody near missed; ascending, each once")


# --- the walker's questions, against the scan over everyone ---------------------------------------------

func _crowd_space(rng: RandomNumberGenerator) -> CastSpaceScript:
	"""Open ground with a few posts and CROWD residents of the cast's radii, some walking, some below."""
	var space := CastSpaceScript.new()
	var posts: Array[Vector3] = [Vector3(-6.0, 1.2, 0.0), Vector3(5.0, 0.8, 4.0), Vector3(0.0, 2.0, -9.0)]
	space.setup([], posts)
	for i in CROWD:
		space.add_resident(Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-15.0, 15.0)), rng.randf_range(0.25, 0.56))
		space.set_walking(i, rng.randf() < 0.3)
		if rng.randf() < 0.1:
			space.set_underground(i, true)
	return space


func _scan_separation(space: CastSpaceScript, index: int, at: Vector2, forward: Vector2) -> Vector2:
	"""cast_space.gd `separation` as it was: a scan over everyone."""
	var push := Vector2.ZERO
	var radius := space.resident_radius[index]
	for j in space.resident_position.size():
		if j == index or space.resident_underground[j] != 0:
			continue
		var offset := at - space.resident_position[j]
		var reach := radius + space.resident_radius[j] + CastSpaceScript.SEPARATION_MARGIN_M
		var d := offset.length()
		if d >= reach or d < 1e-5:
			continue
		var weight := 1.0 - d / reach
		push += offset / d * weight
		if forward.dot(-offset) > 0.0:
			push += Vector2(-forward.y, forward.x) * weight
	return push


func _scan_constrain(space: CastSpaceScript, index: int, from: Vector2, to: Vector2, goal: Vector2) -> Vector2:
	"""cast_space.gd `constrain` as it was: pushed out of everyone in turn, then the obstacles, twice; refused when not
	clear of everyone."""
	var radius := space.resident_radius[index]
	var pad := space.nav.max_radius + radius
	var count := space.nav.circles_near(to.min(from) - Vector2(pad, pad), to.max(from) + Vector2(pad, pad))
	var at := to
	for pass_index in CastSpaceScript.CONSTRAIN_PASSES:
		for j in space.resident_position.size():
			if j != index and space.resident_underground[j] == 0:
				at = CastSpaceScript._keep_out(space.resident_position[j], radius + space.resident_radius[j], from, at)
		for k in count:
			var o := space.obstacles[space.nav.hit(k)]
			at = CastSpaceScript._keep_out(Vector2(o.x, o.z), space._obstacle_reach(o, radius, goal), from, at)
	for j in space.resident_position.size():
		if j == index or space.resident_underground[j] != 0:
			continue
		var limit := minf(radius + space.resident_radius[j], space.resident_position[j].distance_to(from))
		if space.resident_position[j].distance_to(at) < limit - 1e-4:
			return from
	return at if space._clear_of_obstacles(count, radius, from, at, goal) else from


func _scan_blocks(space: CastSpaceScript, index: int, a: Vector2, b: Vector2, body: float, goal: Vector2, margin: float) -> bool:
	"""cast_space.gd `standing_blocks` as it was: a scan over everyone."""
	for j in space.resident_position.size():
		if j != index and space.resident_walking[j] == 0 and space.resident_underground[j] == 0:
			var at := space.resident_position[j]
			var r := CastNavScript.inflated(Vector3(at.x, space.resident_radius[j], at.y), body, margin, a, goal, true)
			if r > 0.0 and CastNavScript.distance_to_segment(at, a, b) < r - 1e-4:
				return true
	return false


func _scan_occupied(space: CastSpaceScript, index: int, at: Vector2, clearance: float) -> bool:
	"""cast_space.gd `surface_occupied` as it was: a scan over everyone."""
	for j in space.resident_position.size():
		if j == index or space.resident_underground[j] != 0:
			continue
		var reach := space.resident_radius[index] + space.resident_radius[j] + clearance
		if space.resident_position[j].distance_squared_to(at) < reach * reach:
			return true
	return false


func test_the_walkers_questions_answer_as_the_scan_over_everyone_did() -> void:
	"""Eighty residents, a third walking, a tenth below, moved about for 300 rounds: from each mover, its separation, a
	step's constraint (crowded steps included), a sight line's blocking and a spot's occupancy are exactly the scan's."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var space := _crowd_space(rng)
	var differ := PackedStringArray()
	for round_index in ROUNDS:
		var i := rng.randi_range(0, CROWD - 1)
		var from := space.resident_position[i]
		var forward := Vector2.from_angle(rng.randf() * TAU)
		var to := from + forward * rng.randf_range(0.0, 0.3)
		var goal := from + forward * 6.0
		if space.separation(i, from, forward) != _scan_separation(space, i, from, forward):
			differ.append("separation %d" % round_index)
		if space.constrain(i, from, to, goal) != _scan_constrain(space, i, from, to, goal):
			differ.append("constrain %d" % round_index)
		var far := from + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 30.0)
		var margin := rng.randf_range(-0.1, 0.1)
		if space.standing_blocks(i, from, far, 0.4, far, margin) != _scan_blocks(space, i, from, far, 0.4, far, margin):
			differ.append("blocks %d" % round_index)
		if space.surface_occupied(i, to, 0.05) != _scan_occupied(space, i, to, 0.05):
			differ.append("occupied %d" % round_index)
		space.move_resident(i, space.constrain(i, from, from + forward * rng.randf_range(0.0, 2.5), goal))
	assert_equal(differ, PackedStringArray(), "every answer the scan's")


func test_a_resident_come_in_round_add_resident_is_still_seen() -> void:
	"""A position appended without `add_resident` (as a fixture may) puts the questions back on the scan over everyone,
	so nobody is missed."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	space.add_resident(Vector2.ZERO, 0.3)
	space.resident_position.append(Vector2(0.4, 0.0))
	space.resident_radius.append(0.3)
	space.resident_walking.append(0)
	space.resident_underground.append(0)
	assert_true(space.surface_occupied(0, Vector2.ZERO, 0.0), "the one appended is seen")


func test_a_resident_off_a_short_sight_line_s_box_but_within_reach_still_blocks_it() -> void:
	"""`standing_blocks` gathers by the widest body as well as the walker's: a badger standing just below a short line,
	in a cell the line's own box does not reach, is still in its way."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	space.add_resident(Vector2(0.5, 0.5), 0.25)
	space.add_resident(Vector2(1.0, -0.4), 0.56)
	assert_true(space.standing_blocks(0, Vector2(0.5, 0.5), Vector2(1.5, 0.5), 0.4, Vector2(1.5, 0.5), 0.0),
		"0.9 m off the line, within 0.56 + 0.4")


func test_steps_in_a_dense_crowd_answer_as_the_scan_over_everyone_did() -> void:
	"""Sixty residents packed in a 4 m square, steps of up to a stride among them: every constraint is the scan's
	(a step pushed far is gathered again from everyone)."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	for i in 60:
		space.add_resident(Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)), rng.randf_range(0.25, 0.56))
	var differ := 0
	for round_index in ROUNDS:
		var i := rng.randi_range(0, 59)
		var from := space.resident_position[i]
		var to := from + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.6)
		if space.constrain(i, from, to, to) != _scan_constrain(space, i, from, to, to):
			differ += 1
		space.move_resident(i, space.constrain(i, from, to, to))
	assert_equal(differ, 0, "every step the scan's")


func test_a_step_pushed_past_its_span_is_handed_back_to_be_pushed_by_everyone() -> void:
	"""`_pushed` gives INF once the step strays past the span its gathering covered (and the step is then pushed by
	everyone, `constrain`); within it, the step as pushed."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	space.add_resident(Vector2.ZERO, 0.5)
	space.add_resident(Vector2(0.3, 0.0), 0.5)
	var near := space._gather(Vector2.INF, Vector2.INF, true)
	var count := space.nav.circles_near(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	assert_equal(space._pushed(0, Vector2.ZERO, Vector2(0.05, 0.0), Vector2(5.0, 0.0), count, near, 0.01), Vector2.INF,
		"pushed further than 0.01 m: handed back")
	assert_true(space._pushed(0, Vector2.ZERO, Vector2(0.05, 0.0), Vector2(5.0, 0.0), count, near, -1.0).is_finite(),
		"with no span: the step as pushed")
