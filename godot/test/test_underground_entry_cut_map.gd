extends "res://test/framework/test_case.gd"
## Independent complete-cube intersection is the oracle; no interval/cursor algorithm is reused.

const CutMap := preload("res://scripts/core/underground_entry_cut_map.gd")
const Space := preload("res://scripts/core/room_space.gd")


func _domain(datum: Vector3i = Vector3i(17, -33, 91)) -> Space.Domain:
	"""Small signed fixture; these coordinates grant no production entrance or geometry permission."""
	var result: Space.Domain = Space.Domain.new()
	assert_equal(result.configure(Vector2i(5, 7), datum, Vector3i(-2, -2, -2), Vector3i(4, 4, 4),
		Space.MAX_CELLS, Space.MAX_REGIONS, Space.MAX_CHECKS), &"", "actual finite Domain")
	return result


func _boxes(pattern: int, datum: Vector3i = Vector3i(17, -33, 91)) -> PackedInt32Array:
	"""Seven independent boxes include overlaps, disjoint heights, exact faces and a duplicate."""
	var source: PackedInt32Array = PackedInt32Array([
		-1024, -1024, -1024, 0, 0, 0, -512, -512, -512, 512, 512, 512,
		0, 0, 0, 1024, 1024, 1024, 1024, -1024, 0, 1536, 1, 513,
		-1536, 512, 1, -1024, 1536, 1025, 1, -1536, 1024, 1025, -1024, 1536,
		0, 0, 0, 1024, 1024, 1024])
	var result: PackedInt32Array = PackedInt32Array()
	for row: int in 7:
		if pattern & (1 << row):
			for field: int in 6:
				result.append(source[row * 6 + field] + datum[field % 3])
	return result


func _oracle(boxes: PackedInt32Array, domain: Space.Domain) -> Array[Vector3i]:
	"""Brute-force every cube using strict half-open integer intersections, independently of rounding."""
	var result: Array[Vector3i] = []
	var descriptor: Dictionary = domain.descriptor()
	var datum: Vector3i = descriptor.datum_u
	var low: Vector3i = descriptor.min_quantum
	var size: Vector3i = descriptor.size_quanta
	for y: int in range(low.y, low.y + size.y):
		for z: int in range(low.z, low.z + size.z):
			for x: int in range(low.x, low.x + size.x):
				var cube: Vector3i = datum + Vector3i(x, y, z) * 1024
				if _touches(boxes, cube):
					result.append(cube)
	return result


func _touches(boxes: PackedInt32Array, cube: Vector3i) -> bool:
	"""No normalized lattice coordinate or interval union appears in this independent predicate."""
	for at: int in range(0, boxes.size(), 6):
		if cube.x < boxes[at + 3] and int(cube.x) + 1024 > boxes[at] \
				and cube.y < boxes[at + 4] and int(cube.y) + 1024 > boxes[at + 1] \
				and cube.z < boxes[at + 5] and int(cube.z) + 1024 > boxes[at + 2]:
			return true
	return false


func _read(cuts: CutMap) -> Array[Vector3i]:
	"""Only the test retains output; production emits one key at a time."""
	var result: Array[Vector3i] = []
	var previous: int = -1
	while cuts.advance():
		assert_true(cuts.current_key() > previous, "strict unique Sites key order")
		previous = cuts.current_key()
		result.append(cuts.current_origin())
	assert_equal(cuts.current_key(), -1, "no stale current key at end or refusal")
	return result


func test_all_varying_height_subsets_match_independent_whole_cube_intersection() -> void:
	"""All127 nonempty unions test overlapping courses, nonaligned boundaries and repeated input."""
	var domain: Space.Domain = _domain()
	for pattern: int in range(1, 128):
		var boxes: PackedInt32Array = _boxes(pattern)
		var original: PackedInt32Array = boxes.duplicate()
		var cuts: CutMap = CutMap.new()
		assert_equal(cuts.configure(boxes, domain, Space.MAX_CHECKS, 64), &"", "valid box union")
		assert_equal(_read(cuts), _oracle(boxes, domain), "exact union equals independent intersections")
		assert_equal(cuts.refusal(), &"", "complete successful stream")
		cuts.clear()
		assert_equal(boxes, original, "caller input unchanged")


func test_box_order_and_duplicate_parts_do_not_change_the_paid_cube_stream() -> void:
	"""A canonical physical bill cannot depend on source-part ordering or count overlapping parts twice."""
	var original: PackedInt32Array = _boxes(127)
	var expected: Array[Vector3i] = _oracle(original, _domain())
	for shift: int in 7:
		var shuffled: PackedInt32Array = PackedInt32Array()
		for row: int in 7:
			var source_row: int = (6 - row + shift) % 7
			for field: int in 6:
				shuffled.append(original[source_row * 6 + field])
		shuffled.append_array(original)
		var cuts: CutMap = CutMap.new()
		assert_equal(cuts.configure(shuffled, _domain(), Space.MAX_CHECKS, expected.size()), &"", "duplicate parts fit exact union cap")
		assert_equal(_read(cuts), expected, "reordered repeated source has identical physical ownership")
		assert_equal(cuts.refusal(), &"", "no successful truncation")


func test_offset_datum_negative_boundaries_and_one_unit_crossings_remain_exact() -> void:
	"""The half-open high face never charges an adjacent quantum just because it shares a boundary."""
	var datum: Vector3i = Vector3i(17, -33, 91)
	var domain: Space.Domain = _domain(datum)
	for offset: int in [-1025, -1024, -1, 0, 1, 1023, 1024]:
		var box: PackedInt32Array = PackedInt32Array()
		for side: int in 2:
			for axis: int in 3:
				box.append(datum[axis] + offset + side * 1024)
		var cuts: CutMap = CutMap.new()
		assert_equal(cuts.configure(box, domain, Space.MAX_CHECKS, 64), &"", "signed nonaligned box")
		assert_equal(_read(cuts), _oracle(box, domain), "independent face intersections")
		assert_equal(cuts.refusal(), &"", "full successful stream")


func test_whole_cube_gaps_are_retained_between_different_courses() -> void:
	"""Non-flat clearances cannot be replaced by a filled common-height bounding prism."""
	var boxes: PackedInt32Array = PackedInt32Array([-2048, -2048, -2048, -1024, -1024, -1024,
		1024, 1024, 1024, 2048, 2048, 2048])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(boxes, _domain(Vector3i.ZERO), 100, 2), &"", "separate courses")
	assert_equal(_read(cuts), [Vector3i(-2048, -2048, -2048), Vector3i(1024, 1024, 1024)], "exact two cubes only")
	assert_equal(cuts.refusal(), &"", "empty intermediate levels and bands cost no phantom cuts")


func test_sparse_coordinate_gaps_use_visits_not_distance_as_the_work_budget() -> void:
	"""Two tiny islands separated by a million bands must not scan those empty bands."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(5, 7), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i(1, 1000001, 1000001), 1, 2, 100), &"", "large sparse signed-I64 Domain")
	var boxes: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 1, 1,
		0, 1024000000, 1024000000, 1, 1024000001, 1024000001])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(boxes, domain, 100, 2), &"", "two actual boxes")
	assert_equal(_read(cuts), [Vector3i.ZERO, Vector3i(0, 1024000000, 1024000000)], "both islands found")
	assert_equal(cuts.refusal(), &"", "empty-distance scan cannot exhaust finite visits")
	assert_true(cuts.remaining_checks() > 50, "constant bounded visits for two occupied bands")


func test_exact_capacity_accepts_and_one_missing_cube_refuses_explicitly() -> void:
	"""A smaller physical history can never silently accept a priced prefix of a larger entry."""
	var boxes: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 1, 1, 1024, 0, 0, 1025, 1, 1])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(boxes, _domain(Vector3i.ZERO), 1000, 1), &"", "individual boxes fit")
	assert_equal(_read(cuts), [Vector3i.ZERO], "diagnostic bounded prefix")
	assert_equal(cuts.refusal(), CutMap.REFUSE_CAPACITY, "second distinct cube rejects entire operation")
	assert_equal(cuts.emitted_count(), 1, "no extra emitted cube after capacity refusal")
	assert_equal(cuts.current_origin(), Vector3i.ZERO, "no current cube after refusal")
	cuts = CutMap.new()
	assert_equal(cuts.configure(boxes, _domain(Vector3i.ZERO), 1000, 2), &"", "exact physical capacity")
	assert_equal(_read(cuts).size(), 2, "complete union")
	assert_equal(cuts.refusal(), &"", "exact capacity succeeds")


func test_individual_box_capacity_and_malformed_input_refuse_before_allocation() -> void:
	"""Malformed shape, extent, Domain and bill size cannot hide an allocation behind a small row count."""
	for boxes: PackedInt32Array in [PackedInt32Array(), PackedInt32Array([0]),
			PackedInt32Array([0, 0, 0, 0, 1, 1]), PackedInt32Array([1, 0, 0, 0, 1, 1]),
			PackedInt32Array([-2049, 0, 0, 0, 1, 1]), PackedInt32Array([0, 0, 0, 2147483647, 1, 1])]:
		var cuts: CutMap = CutMap.new()
		assert_true(cuts.configure(boxes, _domain(Vector3i.ZERO), 100, 64) != &"", "invalid box refused")
		assert_true(cuts._intervals.is_empty(), "no variable allocation on invalid input")
		assert_false(cuts.advance(), "refused stream closed")
	var large: CutMap = CutMap.new()
	assert_equal(large.configure(PackedInt32Array([0, 0, 0, 1025, 1025, 1025]),
		_domain(Vector3i.ZERO), 100, 7), CutMap.REFUSE_CAPACITY, "individual eight-cube bill cannot fit seven")
	assert_true(large._intervals.is_empty(), "capacity refusal before interval allocation")


func test_unrepresentable_domain_rank_refuses_before_allocation() -> void:
	"""Int32 world bounds alone do not establish Sites' signed-I64 normalized key rank."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(2, 1), Vector3i.ZERO, Vector3i(-2097152, -2097152, -2097152),
		Vector3i(4194303, 4194303, 4194303), 16, 16, 100), &"", "valid int32 world bounds")
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(PackedInt32Array([0, 0, 0, 1, 1, 1]), domain, 100, 1),
		CutMap.REFUSE_DOMAIN, "rank overflow refused")
	assert_true(cuts._intervals.is_empty(), "no interval allocation")


func test_domain_box_and_work_limits_cannot_be_enlarged_by_the_caller() -> void:
	"""Actual immutable Domain limits precede input borrowing and variable scratch."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(1, 1), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i.ONE, 1, 1, 10), &"", "small actual Domain")
	var one: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 1, 1])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(one, domain, 11, 1), CutMap.REFUSE_WORK, "cannot mint extra work")
	assert_true(cuts._intervals.is_empty(), "work refusal before allocation")
	one.append_array(one.duplicate())
	cuts = CutMap.new()
	assert_equal(cuts.configure(one, domain, 10, 1), CutMap.REFUSE_DOMAIN, "cannot exceed actual box ceiling")
	assert_true(cuts._intervals.is_empty(), "Domain count refusal before allocation")


func test_work_exhaustion_and_consumer_queries_share_one_finite_allowance() -> void:
	"""Consumer history lookups and traversal cannot draw from independent work counters."""
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.charge_checks(1), CutMap.REFUSE_CLOSED, "unconfigured scope refuses")
	assert_equal(cuts.configure(PackedInt32Array([0, 0, 0, 1, 1, 1]),
		_domain(Vector3i.ZERO), 100, 1), &"", "one cube input")
	assert_equal(cuts.remaining_checks(), 99, "one complete preflight visit charged")
	assert_equal(cuts.charge_checks(99), &"", "consumer spends remaining original work")
	assert_false(cuts.advance(), "no uncharged next-band scan")
	assert_equal(cuts.refusal(), CutMap.REFUSE_WORK, "explicit exhaustion")
	assert_equal(cuts.remaining_checks(), 0, "no work underflow")
	assert_equal(cuts.rewind_prepaid(10), CutMap.REFUSE_CLOSED, "failed stream cannot replay")


func test_prepaid_replay_has_identical_output_and_no_second_allocation() -> void:
	"""Actual claim publication reuses a fully proven private stream and only its unused budget."""
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(_boxes(127), _domain(), 10000, 64), &"", "complete finite union")
	var first: Array[Vector3i] = _read(cuts)
	var work: int = 10000 - cuts.remaining_checks()
	var capacity: int = cuts._intervals.size()
	assert_equal(cuts.rewind_prepaid(work), &"", "prepaid replay")
	assert_equal(_read(cuts), first, "identical unique order")
	assert_equal(cuts.refusal(), &"", "replay is complete")
	assert_equal(cuts._intervals.size(), capacity, "one retained bank")
	assert_true(cuts.remaining_checks() <= work, "replay cannot mint original full allowance")


func test_invalid_replay_retains_original_cursor_and_cannot_reopen_a_closed_one() -> void:
	"""Neither partial observations nor extra allowances can become an atomic publication proof."""
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(_boxes(1), _domain(), 100, 64), &"", "actual borrowed input")
	var remaining: int = cuts.remaining_checks()
	assert_equal(cuts.rewind_prepaid(1), CutMap.REFUSE_CLOSED, "unfinished stream")
	assert_equal(cuts.remaining_checks(), remaining, "refusal leaves original work")
	_read(cuts)
	remaining = cuts.remaining_checks()
	assert_equal(cuts.rewind_prepaid(remaining + 1), CutMap.REFUSE_WORK, "excessive replay allowance")
	assert_equal(cuts.remaining_checks(), remaining, "invalid replay cannot change work")
	cuts.clear()
	assert_equal(cuts.refusal(), CutMap.REFUSE_CLOSED, "explicit close")
	assert_equal(cuts.configure(_boxes(1), _domain(), 100, 64), CutMap.REFUSE_CLOSED, "closed input cannot reopen")
	assert_equal(cuts.rewind_prepaid(1), CutMap.REFUSE_CLOSED, "released input cannot replay")
	assert_true(cuts._intervals.is_empty() and cuts._boxes.is_empty(), "borrowed and allocated lifetimes dropped")


func test_scratch_admission_is_bounded_and_excludes_caller_images() -> void:
	"""Source-counted interval/control bytes are not a runtime native-memory claim."""
	assert_equal(CutMap.scratch_bytes(0), 0, "zero boxes invalid")
	assert_equal(CutMap.scratch_bytes(-1), 0, "negative boxes invalid")
	assert_equal(CutMap.scratch_bytes(Space.MAX_REGIONS + 1), 0, "oversized input invalid")
	assert_equal(CutMap.scratch_bytes(7), 7 * 8 + 512, "exact interval bank plus fixed controls")
	assert_equal(CutMap.scratch_bytes(Space.MAX_REGIONS), 8 * Space.MAX_REGIONS + 512, "same existing engineering ceiling")
