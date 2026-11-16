extends "res://test/framework/test_case.gd"
## The demo's Mound store and its builder's next job (decision 2002): stages heap → dig → frame → top, the confirmed
## doors and windows (early or late, fitted), the Mounds as joined rooms, and the job order -- the whole hill heaped
## first, dug breadth first from the door with each open cell framed before the next is dug, topped, then the doors and
## windows fitted, then the furniture on the floor.

const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Jobs := preload("res://demo/build_panel/demo_build_mound_jobs.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 32, 32)
const BED: int = 0

var _mounds: Mounds = null
var _fittings: Fittings = null


func before_each() -> void:
	"""An empty store over a 32 × 32 area."""
	_mounds = Mounds.new()
	_mounds.configure(BOUNDS)
	_fittings = Fittings.new()


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _home() -> void:
	"""A 4 × 2 Mound at (4, 4)-(7, 5) with its door on the north wall at (5, 4)-(6, 4)."""
	assert_true(_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(7, 5))), "ordered")
	assert_true(_mounds.order_edge(Vector2i(5, 4), 0, Mound.KIND_DOOR, 2), "its door")


func _do(job: Dictionary) -> void:
	"""Carry `job` out as the builder would."""
	var kind: int = int(job["kind"])
	if kind == Mounds.JOB_FIT_EDGE:
		assert_true(_mounds.fit_edge(int(job["row"])), "fitted")
	elif kind == Mounds.JOB_FIT_PIECE:
		assert_true(_fittings.fit(int(job["row"])), "piece fitted")
	else:
		assert_true(_mounds.advance(job["cell"], Mounds.JOB_STAGE[kind]), "advanced %s" % job)


func test_ordering_cells_and_taking_them_stage_by_stage() -> void:
	"""Ordered cells wait; each stage only from the one before; the counts and the box follow; off the area nothing
	changes."""
	assert_equal(_mounds.stage_of(Vector2i(4, 4)), Mounds.NONE, "nothing yet")
	assert_false(_mounds.order_cells(PackedInt32Array([4, 4, 40, 4])), "a cell off the area")
	assert_equal(_mounds.count(Mounds.ORDERED), 0, "so none ordered")
	assert_true(_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(7, 5))), "ordered")
	assert_equal([_mounds.count(Mounds.ORDERED), _mounds.box()], [8, Rect2i(4, 4, 4, 2)], "eight, boxed")
	assert_false(_mounds.advance(Vector2i(4, 4), Mounds.DUG), "not dug before it is heaped")
	assert_false(_mounds.advance(Vector2i(4, 4), Mounds.ORDERED), "nor ordered twice")
	assert_false(_mounds.advance(Vector2i(4, 4), Mounds.STAGES), "no stage past topped")
	for stage: int in range(Mounds.HEAPED, Mounds.STAGES):
		assert_true(_mounds.advance(Vector2i(4, 4), stage), "stage %d" % stage)
	assert_equal(_mounds.stage_of(Vector2i(4, 4)), Mounds.TOPPED, "topped")
	assert_true(_mounds.is_open(Vector2i(4, 4)) and not _mounds.is_open(Vector2i(5, 4)), "open once dug")
	assert_equal([_mounds.count(Mounds.ORDERED), _mounds.count(Mounds.TOPPED), _mounds.count(9)], [7, 1, 0], "counts")
	var out: PackedInt32Array = PackedInt32Array([1, 1])
	_mounds.cells_into(Mounds.DUG, out)
	assert_equal(out, PackedInt32Array([4, 4]), "dug or further, cleared first")
	assert_equal(_mounds.all_cells().size(), 16, "every cell")
	assert_true(_mounds.order_cells(PackedInt32Array([4, 4])), "ordered again")
	assert_equal(_mounds.stage_of(Vector2i(4, 4)), Mounds.TOPPED, "a built cell keeps its stage")


func test_mounds_are_joined_rooms_with_their_least_stage() -> void:
	"""Two separate Mounds; a cell's Mound; the least stage of each."""
	_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(5, 5)))
	_mounds.order_cells(_rect(Vector2i(10, 4), Vector2i(11, 5)))
	assert_equal(_mounds.groups().size(), 2, "two Mounds")
	assert_equal([_mounds.group_of(Vector2i(5, 5)), _mounds.group_of(Vector2i(10, 4)), _mounds.group_of(Vector2i(8, 4))],
		[0, 1, -1], "whose")
	for cell: Vector2i in [Vector2i(10, 4), Vector2i(11, 4), Vector2i(10, 5), Vector2i(11, 5)]:
		_mounds.advance(cell, Mounds.HEAPED)
	assert_equal([_mounds.least_stage(0), _mounds.least_stage(1), _mounds.least_stage(2)],
		[Mounds.ORDERED, Mounds.HEAPED, Mounds.NONE], "least stages")
	_mounds.order_cells(_rect(Vector2i(6, 4), Vector2i(9, 4)))
	assert_equal(_mounds.groups().size(), 1, "joined by a room between")


func test_doors_and_windows_are_ordered_on_mound_cells_fitted_and_removed() -> void:
	"""A door or window stands on Mound cells only; EARLY with its rooms unheaped; fitted once; read from either side;
	removed by its first edge."""
	_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(7, 5)))
	assert_false(_mounds.order_edge(Vector2i(7, 4), 0, Mound.KIND_DOOR, 0), "its second edge off the Mound")
	assert_true(_mounds.order_edge(Vector2i(5, 4), 4, Mound.KIND_DOOR, 3), "a door, its side wrapped")
	_mounds.advance(Vector2i(4, 5), Mounds.HEAPED)
	assert_true(_mounds.order_edge(Vector2i(4, 5), 3, Mound.KIND_WINDOW, 0), "a window")
	assert_equal([_mounds.edge_count(), _mounds.edge_side(0), _mounds.edge_colour(0)], [2, 0, 3], "rows")
	assert_true(_mounds.edge_early(0) and not _mounds.edge_early(1), "the door came with its rooms; the window later")
	assert_equal(_mounds.edge_at(0, Vector3i(6, 3, 2)), Vector4i(Mound.KIND_DOOR, 5, 4, 0), "named from outside")
	assert_equal(_mounds.edge_at(0, Vector3i(7, 4, 0)).x, -1, "past the door")
	assert_equal(_mounds.doors(), [Vector3i(5, 4, 0)] as Array[Vector3i], "the doors")
	assert_equal(_mounds.listed(Mound.KIND_WINDOW), [Vector3i(4, 5, 3)] as Array[Vector3i], "the windows")
	assert_equal(_mounds.yards(), [Vector3i(5, 4, 0)] as Array[Vector3i], "an early door's yard is cut")
	assert_false(_mounds.edge_fitted(1), "waiting")
	assert_true(_mounds.fit_edge(1), "fitted")
	assert_false(_mounds.fit_edge(1) or _mounds.fit_edge(5), "only once, only a row")
	assert_equal(_mounds.door_of(0), 0, "the Mound's door")
	assert_true(_mounds.remove_edge(Vector3i(5, 4, 0)), "removed")
	assert_false(_mounds.remove_edge(Vector3i(5, 4, 0)), "only once")
	assert_equal([_mounds.door_of(0), _mounds.yards().size()], [-1, 0], "no door now")


func test_a_late_door_has_its_yard_cut_only_when_fitted() -> void:
	"""P-2001-13 item 2: a door added to a heaped hill cuts its yard when it is fitted."""
	_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(7, 5)))
	for at: int in range(0, 16, 2):
		_mounds.advance(Vector2i(_rect(Vector2i(4, 4), Vector2i(7, 5))[at], _rect(Vector2i(4, 4), Vector2i(7, 5))[at + 1]),
			Mounds.HEAPED)
	_mounds.order_edge(Vector2i(5, 5), 2, Mound.KIND_DOOR, 0)
	assert_true(_mounds.yards().is_empty(), "not cut while waiting")
	_mounds.fit_edge(0)
	assert_equal(_mounds.yards().size(), 1, "cut once fitted")


func test_a_mound_without_a_door_waits() -> void:
	"""No way in: no job."""
	_mounds.order_cells(_rect(Vector2i(4, 4), Vector2i(7, 5)))
	assert_true(Jobs.next_job(_mounds, _fittings).is_empty(), "nothing to do")
	assert_equal(Jobs.words({}, _mounds), "", "no words")


func test_the_whole_hill_is_heaped_first_nearest_the_door() -> void:
	"""P-2001-14 (a): heap from the yard, nearest the door first (row order on a tie); no dig before every cell is
	heaped."""
	_home()
	var job: Dictionary = Jobs.next_job(_mounds, _fittings)
	assert_equal([job["kind"], job["cell"], job["door"], job["group"]], [Mounds.JOB_HEAP, Vector2i(5, 4), 0, 0], "heap")
	assert_true((job["path"] as Array).is_empty(), "from the yard")
	assert_equal(Jobs.words(job, _mounds), "Heaping the hill", "in words")
	for k: int in 7:
		_do(Jobs.next_job(_mounds, _fittings))
	job = Jobs.next_job(_mounds, _fittings)
	assert_equal([job["kind"], job["cell"]], [Mounds.JOB_HEAP, Vector2i(7, 5)], "the farthest last")
	_do(job)
	assert_equal(int(Jobs.next_job(_mounds, _fittings)["kind"]), Mounds.JOB_DIG, "then dig")


func test_dig_frames_each_open_cell_before_the_next() -> void:
	"""Dig at the door's cell first; that cell is framed before the next is dug, reached through open cells."""
	_home()
	for k: int in 8:
		_do(Jobs.next_job(_mounds, _fittings))
	var job: Dictionary = Jobs.next_job(_mounds, _fittings)
	assert_equal([job["kind"], job["cell"]], [Mounds.JOB_DIG, Vector2i(5, 4)], "the door's cell")
	assert_equal(job["path"], [Vector2i(5, 4)] as Array[Vector2i], "standing at it")
	_do(job)
	job = Jobs.next_job(_mounds, _fittings)
	assert_equal([job["kind"], job["cell"]], [Mounds.JOB_FRAME, Vector2i(5, 4)], "framed at once")
	_do(job)
	job = Jobs.next_job(_mounds, _fittings, Vector2i(5, 4))
	assert_equal(int(job["kind"]), Mounds.JOB_DIG, "the next dig")
	assert_true(Mound.gap_between(job["cell"], Vector2i(5, 4)) == Vector2i.ZERO, "beside the open cell")
	assert_equal(job["path"], [Vector2i(5, 4)] as Array[Vector2i], "dug from where the builder stands")
	assert_equal(Jobs.words(job, _mounds), "Digging", "in words")


func test_the_whole_build_runs_heap_dig_frame_top_fit_then_furniture() -> void:
	"""Every job in turn until none is left: 8 heaps, 8 digs, 8 frames, 8 tops, a door and a window, a bed."""
	_home()
	_mounds.order_edge(Vector2i(7, 5), 1, Mound.KIND_WINDOW, 0)
	var tally: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var order: Array[int] = []
	var job: Dictionary = Jobs.next_job(_mounds, _fittings)
	for guard: int in 64:
		if job.is_empty():
			break
		tally[int(job["kind"])] += 1
		if order.is_empty() or order[order.size() - 1] != int(job["kind"]):
			order.append(int(job["kind"]))
		if int(job["kind"]) == Mounds.JOB_FIT_EDGE and _mounds.edge_kind(int(job["row"])) == Mound.KIND_DOOR:
			assert_equal(Jobs.words(job, _mounds), "Fitting the front door", "its words")
		_do(job)
		if _mounds.count(Mounds.TOPPED) == 8 and _fittings.count() == 0:
			_fittings.order(Mound.SURFACE, Vector2i(6, 4), 0, BED)
		var path: Array = job["path"]
		job = Jobs.next_job(_mounds, _fittings, path[path.size() - 1] if not path.is_empty() else Jobs.NOWHERE)
	assert_equal(tally, PackedInt32Array([8, 8, 8, 8, 2, 1]), "every job once a cell")
	assert_equal(order[0], Mounds.JOB_HEAP, "heaped first")
	assert_equal(order.slice(order.size() - 3), [Mounds.JOB_TOP, Mounds.JOB_FIT_EDGE, Mounds.JOB_FIT_PIECE], "the end")
	assert_true(order.has(Mounds.JOB_DIG) and order.has(Mounds.JOB_FRAME), "dug and framed between")
	assert_equal(_fittings.waiting(), 0, "the bed fitted")


func test_a_piece_below_the_surface_is_not_the_mound_builders() -> void:
	"""A topped Mound with fitted doors: a piece on level 1 is not its job; one on the floor is, walked to."""
	_home()
	for k: int in 33:
		_do(Jobs.next_job(_mounds, _fittings))
	assert_true(Jobs.next_job(_mounds, _fittings).is_empty(), "all done")
	_fittings.order(1, Vector2i(4, 4), 0, BED)
	assert_true(Jobs.next_job(_mounds, _fittings).is_empty(), "a piece below is not its")
	_fittings.order(Mound.SURFACE, Vector2i(6, 4), 0, BED)
	var job: Dictionary = Jobs.next_job(_mounds, _fittings)
	assert_equal([job["kind"], job["row"]], [Mounds.JOB_FIT_PIECE, 1], "the floor's bed")
	assert_equal(job["path"], [Vector2i(5, 4), Vector2i(6, 4)] as Array[Vector2i], "walked from the door's cell")
	assert_equal(Jobs.words(job, _mounds), "Fitting furniture", "in words")


func test_the_searches() -> void:
	"""`walk_to_stage` and `walk_to_any` through open cells only; `nearest_at`; `has_stage`."""
	_home()
	for k: int in 8:
		_do(Jobs.next_job(_mounds, _fittings))
	assert_equal(Jobs.walk_to_stage(_mounds, Vector2i(5, 4), Mounds.HEAPED), [Vector2i(5, 4), Vector2i(5, 4)] as Array[Vector2i],
		"standing on it")
	_mounds.advance(Vector2i(5, 4), Mounds.DUG)
	var path: Array[Vector2i] = Jobs.walk_to_stage(_mounds, Vector2i(5, 4), Mounds.HEAPED)
	assert_equal(path.size(), 2, "the open cell, then the one beside it")
	assert_true(Jobs.walk_to_stage(_mounds, Vector2i(5, 4), Mounds.TOPPED).is_empty(), "none topped")
	assert_true(Jobs.has_stage(_mounds, 0, Mounds.DUG) and not Jobs.has_stage(_mounds, 0, Mounds.FRAMED), "stages")
	assert_equal(Jobs.nearest_at(_mounds, 0, Mounds.HEAPED, Vector2i(7, 6)), Vector2i(7, 5), "nearest")
	assert_equal(Jobs.walk_to_any(_mounds, Vector2i(5, 4), {Vector2i(5, 4): 0}), [Vector2i(5, 4)] as Array[Vector2i], "here")
	assert_true(Jobs.walk_to_any(_mounds, Vector2i(5, 4), {Vector2i(7, 5): 0}).is_empty(), "not through heaped cells")
	_mounds.advance(Vector2i(6, 4), Mounds.DUG)
	assert_equal(Jobs.walk_to_any(_mounds, Vector2i(5, 4), {Vector2i(6, 4): 0}), [Vector2i(5, 4), Vector2i(6, 4)] as Array[Vector2i],
		"through open cells")
