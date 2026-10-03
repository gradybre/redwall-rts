extends "res://test/framework/test_case.gd"
## Validation-only equivalence: independent Dictionary flood fill and unchanged public contour tracing.
## Synthetic cells describe no gameplay grid size, room purpose, support, cost or spatial permission.

const Footprint := preload("res://scripts/core/room_footprint.gd")
const LIMIT: int = Footprint.MAX_OPERATION_CELLS


func _pattern_cells(pattern: int, width: int, depth: int) -> PackedInt32Array:
	"""Enumerate exact canonical subsets without passing through any new validation implementation."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in depth:
		for x: int in width:
			if (pattern & (1 << (z * width + x))) != 0:
				cells.append_array(PackedInt32Array([x, z]))
	return cells


func _legacy_refusal(cells: PackedInt32Array, allow_holes: bool) -> StringName:
	"""Keep the original decision order, using a distinct membership flood and the unchanged contour API."""
	if cells.is_empty():
		return Footprint.REFUSE_EMPTY
	if not _oracle_connected(cells):
		return Footprint.REFUSE_DISCONNECTED
	var loops: Array[PackedInt32Array] = Footprint.boundary_loops(cells)
	if loops.is_empty():
		return Footprint.REFUSE_PINCH
	return Footprint.REFUSE_HOLES if not allow_holes and loops.size() > 1 else &""


func _oracle_connected(cells: PackedInt32Array) -> bool:
	"""Test-only membership set and coordinate queue share no packed adjacency, flags or Euler implementation."""
	var remaining: Dictionary = {}
	for pair: int in range(0, cells.size(), 2):
		remaining[Vector2i(cells[pair], cells[pair + 1])] = true
	var queue: Array[Vector2i] = [Vector2i(cells[0], cells[1])]
	remaining.erase(queue[0])
	var at: int = 0
	while at < queue.size():
		var cell: Vector2i = queue[at]
		for neighbor: Vector2i in [cell + Vector2i.LEFT, cell + Vector2i.RIGHT,
				cell + Vector2i.UP, cell + Vector2i.DOWN]:
			if remaining.has(neighbor):
				remaining.erase(neighbor)
				queue.append(neighbor)
		at += 1
	return remaining.is_empty()


func test_every_four_by_four_subset_matches_unchanged_contour_semantics() -> void:
	"""All65,536 shapes exercise components, both diagonal pinches, concavity and every possible small hole."""
	for pattern: int in 1 << 16:
		var cells: PackedInt32Array = _pattern_cells(pattern, 4, 4)
		var before: PackedInt32Array = cells.duplicate()
		var without_holes: StringName = _legacy_refusal(cells, false)
		var with_holes: StringName = &"" if without_holes == Footprint.REFUSE_HOLES else without_holes
		assert_equal(Footprint.validation_error(cells, 16, false), without_holes, "complete4x4 no-hole parity:%d" % pattern)
		assert_equal(Footprint.validation_error(cells, 16, true), with_holes, "complete4x4 hole parity:%d" % pattern)
		assert_equal(cells, before, "validation never sorts, erases or fills caller cells:%d" % pattern)


func test_original_refusal_precedence_is_unchanged() -> void:
	"""A malformed or invalid request cannot enter packed validation and produce a different later refusal."""
	assert_equal(Footprint.validation_error(PackedInt32Array([0]), 0, false), Footprint.REFUSE_FORMAT, "pair shape precedes capacity")
	assert_equal(Footprint.validation_error(PackedInt32Array(), 0, false), Footprint.REFUSE_CAPACITY, "capacity precedes empty")
	assert_equal(Footprint.validation_error(PackedInt32Array([0, 0, 2147483647, 0]), 1, false),
		Footprint.REFUSE_CAPACITY, "oversize precedes coordinate")
	assert_equal(Footprint.validation_error(PackedInt32Array([2147483647, 0, 0, 0]), 2, false),
		Footprint.REFUSE_COORDINATE, "coordinate precedes canonical order")
	assert_equal(Footprint.validation_error(PackedInt32Array([5, 0, 0, 0]), 2, false),
		Footprint.REFUSE_CANONICAL, "canonical order precedes disconnected")
	assert_equal(Footprint.validation_error(PackedInt32Array([0, 0, 0, 0]), 2, false),
		Footprint.REFUSE_CANONICAL, "duplicate cells never become two queue rows")
	assert_equal(Footprint.validation_error(PackedInt32Array(), 1, false), Footprint.REFUSE_EMPTY, "valid empty draft refuses")
	var pinch: PackedInt32Array = _pattern_cells(510 - 16, 3, 3)
	assert_equal(Footprint.validation_error(pinch, LIMIT, false), Footprint.REFUSE_PINCH, "pinch precedes hole policy")
	pinch.append_array(PackedInt32Array([10, 10]))
	assert_equal(Footprint.validation_error(pinch, LIMIT, false), Footprint.REFUSE_DISCONNECTED, "connectivity precedes pinch")


func _translated(cells: PackedInt32Array, x: int, z: int) -> PackedInt32Array:
	"""Translate already canonical tiny fixtures directly with exact integer additions."""
	var out: PackedInt32Array = cells.duplicate()
	for pair: int in range(0, out.size(), 2):
		out[pair] += x
		out[pair + 1] += z
	return out


func test_signed_extremes_and_huge_sparse_spans_keep_exact_neighbors() -> void:
	"""Int64 row-join comparisons never wrap a far corner or allocate the absent bounding rectangle."""
	var ring: PackedInt32Array = _pattern_cells(511 - 16, 3, 3)
	for offset: Vector2i in [Vector2i(-2147483648, -2147483648), Vector2i(2147483644, 2147483644)]:
		var cells: PackedInt32Array = _translated(ring, offset.x, offset.y)
		assert_equal(Footprint.validation_error(cells, LIMIT, true), &"", "exact extreme ring remains connected")
		assert_equal(Footprint.validation_error(cells, LIMIT, false), Footprint.REFUSE_HOLES, "extreme hole stays a hole")
		assert_equal(Footprint.boundary_loops(cells).size(), 2, "existing actual contours remain unchanged")
	var sparse: PackedInt32Array = PackedInt32Array([-2147483648, -2147483648, 2147483646, 2147483646])
	assert_equal(Footprint.validation_error(sparse, LIMIT, true), Footprint.REFUSE_DISCONNECTED, "no wrapped or diagonal bridge")
	assert_equal(Footprint.validation_scratch_bytes(2), 34, "two distant cells still cost only two rows plus scalar")


func test_packed_allocation_is_exact_and_invalid_requests_allocate_nothing() -> void:
	"""The actual four buffers and capacity scalar match the public cold accounting contract."""
	for count: int in [1, 2, 477, 478, LIMIT]:
		var scratch: Footprint.ValidationScratch = Footprint.ValidationScratch.new(count)
		var packed: int = scratch._validation_up.to_byte_array().size() + scratch._validation_down.to_byte_array().size() \
			+ scratch._validation_queue.to_byte_array().size() + scratch._validation_flags.size()
		assert_equal(packed, 13 * count, "three exact I32 arrays and one exact byte array")
		assert_equal(Footprint.validation_scratch_bytes(count), packed + 8, "capacity scalar is included")
	for invalid: int in [-1, 0, LIMIT + 1, 9223372036854775807]:
		var scratch: Footprint.ValidationScratch = Footprint.ValidationScratch.new(invalid)
		assert_true(scratch._validation_up.is_empty() and scratch._validation_down.is_empty()
			and scratch._validation_queue.is_empty() and scratch._validation_flags.is_empty(), "invalid budget allocates no packed row")
		assert_equal(Footprint.validation_scratch_bytes(invalid), 0, "invalid size grants no accounting allowance")


func test_full_existing_capacity_and_long_staircase_do_not_inherit_477_cell_limit() -> void:
	"""The approved pure geometry ceiling and one-cell passages remain unchanged by memory optimization."""
	var square: PackedInt32Array = Footprint.rectangle(-64, -64, 128, 128, LIMIT).cells
	var before: PackedInt32Array = square.duplicate()
	assert_equal(Footprint.validation_error(square, LIMIT, false), &"", "full16384-cell rectangle")
	assert_equal(square, before, "full input remains exact")
	var stairs: PackedInt32Array = PackedInt32Array()
	for row: int in (LIMIT >> 1):
		stairs.append_array(PackedInt32Array([row, row, row + 1, row]))
	assert_equal(stairs.size(), LIMIT * 2, "full sparse staircase")
	assert_equal(Footprint.validation_error(stairs, LIMIT, false), &"", "linear row merges preserve narrow connected stair")
	assert_equal(Footprint.validation_scratch_bytes(LIMIT), 212_992 + 8, "full packed arena stays explicit")
	assert_equal(Footprint.validation_error(square, LIMIT - 1, true), Footprint.REFUSE_CAPACITY, "caller limit never silently expands")


func test_repeated_rotated_and_reflected_queries_never_reuse_visited_state() -> void:
	"""A new cold packet and invariant topology preserve deterministic validation under repeated editing."""
	for pattern: int in [1, 7, 127, 255, 495, 510, 511]:
		var cells: PackedInt32Array = _pattern_cells(pattern, 3, 3)
		for turn: int in 4:
			var transformed: Dictionary = Footprint.transform_cells(cells, turn, -17, 31, LIMIT)
			assert_true(transformed.ok, "actual existing canonical transform")
			for repeat: int in 3:
				assert_equal(Footprint.validation_error(transformed.cells, LIMIT, false),
					_legacy_refusal(transformed.cells, false), "repeated transformed parity")


func test_multiple_holes_and_connected_corridors_match_contour_count() -> void:
	"""Euler counts all enclosed components while leaving narrow bridges and absent cells untouched."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 9:
		for x: int in 13:
			if x % 4 != 2 or z % 4 != 2:
				cells.append_array(PackedInt32Array([x, z]))
	assert_equal(Footprint.boundary_loops(cells).size(), 7, "six existing exact hole loops plus exterior")
	assert_equal(Footprint.validation_error(cells, LIMIT, true), &"", "all six holes remain allowed")
	assert_equal(Footprint.validation_error(cells, LIMIT, false), Footprint.REFUSE_HOLES, "any positive hole count refuses")


func test_full_capacity_cold_timing_is_reported_without_a_budget_claim() -> void:
	"""Diagnostic wall time has no effect on authoritative results or pass/fail performance policy."""
	var cells: PackedInt32Array = Footprint.rectangle(-64, -64, 128, 128, LIMIT).cells
	var began: int = Time.get_ticks_usec()
	for repeat: int in 4:
		assert_equal(Footprint.validation_error(cells, LIMIT, false), &"", "actual full packed validation")
	var elapsed: int = Time.get_ticks_usec() - began
	print("ROOM_FOOTPRINT_PACKED cells=%d packed_bytes=%d capacity_scalar_bytes=8 four_calls_usec=%d" % [LIMIT, 13 * LIMIT, elapsed])
