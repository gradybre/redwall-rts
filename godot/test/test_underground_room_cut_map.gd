extends "res://test/framework/test_case.gd"
## The oracle intersects actual integer boxes; it shares no interval, heap or cursor implementation.

const CutMap := preload("res://scripts/core/underground_room_cut_map.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")


func _domain(datum: Vector3i = Vector3i(17, -33, 91)) -> Space.Domain:
	"""Small signed fixture domains imply no gameplay location, painting pitch or permission."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(5, 7), datum, Vector3i(-4, -4, -4), Vector3i(8, 8, 8),
		Footprint.MAX_OPERATION_CELLS, 32, Space.MAX_CHECKS), &"", "finite actual Domain")
	return domain


func _cells(pattern: int) -> PackedInt32Array:
	"""Enumerate all canonical subsets directly, including disconnected unions and holes."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 3:
		for x: int in 3:
			if pattern & (1 << (z * 3 + x)):
				cells.append_array(PackedInt32Array([x - 1, z - 1]))
	return cells


func _oracle(cells: PackedInt32Array, origin: Vector3i, pitch: int, height: int,
		domain: Space.Domain) -> Array[Vector3i]:
	"""Brute-force every cube in a small domain and test strict half-open overlap with every painted cell."""
	var out: Array[Vector3i] = []
	var descriptor: Dictionary = domain.descriptor()
	var datum: Vector3i = descriptor.datum_u
	var low: Vector3i = descriptor.min_quantum
	var size: Vector3i = descriptor.size_quanta
	for y: int in range(low.y, low.y + size.y):
		for z: int in range(low.z, low.z + size.z):
			for x: int in range(low.x, low.x + size.x):
				var cube: Vector3i = datum + Vector3i(x, y, z) * 1024
				if _touches(cells, origin, pitch, height, cube):
					out.append(cube)
	return out


func _touches(cells: PackedInt32Array, origin: Vector3i, pitch: int, height: int, cube: Vector3i) -> bool:
	"""Independent box overlap never rounds a cell or infers its shape from another row."""
	if cube.y >= int(origin.y) + height or int(cube.y) + 1024 <= origin.y:
		return false
	for pair: int in range(0, cells.size(), 2):
		var x: int = int(origin.x) + int(cells[pair]) * pitch
		var z: int = int(origin.z) + int(cells[pair + 1]) * pitch
		if cube.x < x + pitch and int(cube.x) + 1024 > x \
				and cube.z < z + pitch and int(cube.z) + 1024 > z:
			return true
	return false


func _read(cuts: CutMap) -> Array[Vector3i]:
	"""Collect only in the test oracle, checking strict actual ledger ordering as every cube arrives."""
	var out: Array[Vector3i] = []
	var previous: int = -1
	while cuts.advance():
		assert_true(cuts.current_key() > previous, "strict Y/Z/X Sites rank, no duplicate physical quantum")
		previous = cuts.current_key()
		out.append(cuts.current_origin())
	return out


func test_completed_private_cursor_replays_without_a_second_bank_or_new_allowance() -> void:
	"""The atomic Sites publisher can replay its already proved immutable input without allocation."""
	var domain: Space.Domain = _domain()
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(_cells(495), Vector3i(17, -33, 91), 769, 1500, domain, 100000, 512), &"", "bounded private cursor")
	var first: Array[Vector3i] = _read(cuts)
	var work: int = 100000 - cuts.remaining_checks()
	var bank_size: int = cuts._intervals.size()
	assert_equal(cuts.rewind_prepaid(work), &"", "replay consumes only an already unused allowance")
	assert_equal(cuts._intervals.size(), bank_size, "same bank capacity retained")
	assert_equal(_read(cuts), first, "same full unique Y/Z/X stream")
	assert_true(cuts.remaining_checks() <= work, "no fresh Domain budget granted")
	assert_equal(cuts._intervals.size(), bank_size, "no second output-key list or interval allocation")


func test_unfinished_or_underfunded_replay_refuses_without_changing_cursor() -> void:
	"""A partial/error cursor is never a replay proof, and an excessive allowance cannot be minted."""
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(_cells(1), Vector3i(17, -33, 91), 256, 1, _domain(), 1000, 16), &"", "actual cursor")
	var before: int = cuts.remaining_checks()
	assert_equal(cuts.rewind_prepaid(1), CutMap.REFUSE_CLOSED, "unfinished stream refuses")
	assert_equal(cuts.remaining_checks(), before, "refusal retains allowance")
	_read(cuts)
	before = cuts.remaining_checks()
	assert_equal(cuts.rewind_prepaid(before + 1), CutMap.REFUSE_WORK, "cannot grant extra work")
	assert_equal(cuts.remaining_checks(), before, "invalid replay leaves cursor unchanged")
	cuts.clear()
	assert_equal(cuts.rewind_prepaid(1), CutMap.REFUSE_CLOSED, "dropped input cannot replay")


func test_every_three_by_three_union_matches_independent_cube_intersection() -> void:
	"""All511 nonempty patterns at three pitches cover overlapping rows, true holes and nonaligned boundaries."""
	var domain: Space.Domain = _domain()
	for pitch: int in [256, 769, 1025]:
		for pattern: int in range(1, 512):
			var cells: PackedInt32Array = _cells(pattern)
			var original: PackedInt32Array = cells.duplicate()
			var origin: Vector3i = Vector3i(-157, -533, 139)
			var cuts: CutMap = CutMap.new()
			assert_equal(cuts.configure(cells, origin, pitch, 1537, domain, Space.MAX_CHECKS, 512), &"", "valid derived input")
			assert_equal(_read(cuts), _oracle(cells, origin, pitch, 1537, domain), "complete small-grid cube union")
			assert_equal(cuts.refusal(), &"", "complete stream is not truncated")
			cuts.clear()
			assert_equal(cells, original, "borrowed canonical input remains byte-identical after cleanup")


func test_offset_datum_boundaries_and_negative_coordinates_keep_exact_key_order() -> void:
	"""Negative division, half-open high faces and one-unit crossings all use the immutable datum."""
	var domain: Space.Domain = _domain()
	var descriptor: Dictionary = domain.descriptor()
	var datum: Vector3i = descriptor.datum_u
	for offset: int in [-1025, -1024, -1, 0, 1, 1023, 1024]:
		var origin: Vector3i = datum + Vector3i(offset, offset, offset)
		var cells: PackedInt32Array = PackedInt32Array([0, 0])
		var cuts: CutMap = CutMap.new()
		assert_equal(cuts.configure(cells, origin, 1024, 1024, domain, Space.MAX_CHECKS, 512), &"", "exact offset")
		assert_equal(_read(cuts), _oracle(cells, origin, 1024, 1024, domain), "no truncation toward zero")
		assert_equal(cuts.refusal(), &"", "all requested quantum faces accounted")


func test_fine_duplicates_charge_one_cube_and_preserve_a_whole_cube_hole() -> void:
	"""Many painted cells can share one paid cube; a genuinely untouched cube in a hole stays absent."""
	var domain: Space.Domain = _domain(Vector3i.ZERO)
	var fine: PackedInt32Array = Footprint.rectangle(0, 0, 4, 4, 16).cells
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(fine, Vector3i.ZERO, 256, 1024, domain, Space.MAX_CHECKS, 1), &"", "one-row capacity suffices")
	assert_equal(_read(cuts), [Vector3i.ZERO], "sixteen fine cells produce one physical cube")
	assert_equal(cuts.refusal(), &"", "exact capacity is accepted")
	assert_equal(cuts.emitted_count(), 1, "bill count does not multiply repeated fine-cell intersections")
	var ring: PackedInt32Array = _cells(511 - 16)
	cuts = CutMap.new()
	assert_equal(cuts.configure(ring, Vector3i.ZERO, 1024, 1024, domain, Space.MAX_CHECKS, 8), &"", "physical ring")
	var actual: Array[Vector3i] = _read(cuts)
	assert_equal(actual.size(), 8, "eight distinct full cubes")
	assert_false(actual.has(Vector3i.ZERO), "center whole cube remains untouched")


func test_capacity_and_work_exhaustion_are_explicit_not_successful_truncation() -> void:
	"""A diagnostic partial stream never becomes an accepted room or partial silently priced plan."""
	var domain: Space.Domain = _domain(Vector3i.ZERO)
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(cells, Vector3i.ZERO, 1024, 1024, domain, Space.MAX_CHECKS, 2), &"", "each individual cell fits")
	assert_equal(_read(cuts).size(), 2, "only the diagnostic bounded prefix is yielded")
	assert_equal(cuts.refusal(), CutMap.REFUSE_CAPACITY, "the missing third cube refuses explicitly")
	assert_equal(cuts.current_key(), -1, "refusal exposes no stale current quantum")
	cuts = CutMap.new()
	assert_equal(cuts.configure(cells, Vector3i.ZERO, 1024, 1024, domain, 3, 10), &"", "preflight consumes exact work")
	assert_false(cuts.advance(), "no uncharged gathering can begin")
	assert_equal(cuts.refusal(), CutMap.REFUSE_WORK, "finite operation work exhausted")
	assert_equal(cuts.remaining_checks(), 0, "work does not underflow")


func test_consumer_queries_share_the_actual_finite_work_budget() -> void:
	"""Source/history queries cannot secretly use a second operation allowance beside the derived cursor."""
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.charge_checks(1), CutMap.REFUSE_CLOSED, "no allowance before configure")
	assert_equal(cuts.configure(PackedInt32Array([0, 0]), Vector3i.ZERO, 1, 1,
		_domain(Vector3i.ZERO), 100, 1), &"", "bounded geometry input")
	assert_equal(cuts.remaining_checks(), 99, "one canonical cell preflight")
	assert_equal(cuts.charge_checks(90), &"", "consumer costs debit the same allowance")
	assert_true(cuts.advance(), "remaining budget covers gather, merge and emission")
	var remaining: int = cuts.remaining_checks()
	assert_equal(cuts.charge_checks(remaining + 1), CutMap.REFUSE_WORK, "later real query cannot overdraw")
	assert_equal(cuts.remaining_checks(), remaining, "refusal never makes the counter negative")
	assert_false(cuts.advance(), "consumer refusal permanently closes this stream")
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(1, 1), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i.ONE, 1, 1, 10), &"", "actual smaller Domain work allowance")
	cuts = CutMap.new()
	assert_equal(cuts.configure(PackedInt32Array([0, 0]), Vector3i.ZERO, 1, 1, domain, 11, 1),
		CutMap.REFUSE_WORK, "consumer cannot enlarge the actual immutable Domain work limit")
	assert_true(cuts._intervals.is_empty(), "work refusal precedes allocation")


func test_invalid_input_and_unrepresentable_rank_refuse_before_interval_allocation() -> void:
	"""Malformed/canonical/overflow/huge domain cases cannot allocate or resize a hidden output list."""
	var domain: Space.Domain = _domain()
	for cells: PackedInt32Array in [PackedInt32Array(), PackedInt32Array([0]),
			PackedInt32Array([0, 0, 0, 0]), PackedInt32Array([1, 0, 0, 0]),
			PackedInt32Array([2147483647, 0])]:
		var cuts: CutMap = CutMap.new()
		assert_true(cuts.configure(cells, Vector3i.ZERO, 1024, 1024, domain, 100, 100) != &"", "invalid request refuses")
		assert_true(cuts._intervals.is_empty(), "no variable scratch before complete shape/range preflight")
		assert_false(cuts.advance(), "refused cursor stays closed")
	var enormous: Space.Domain = Space.Domain.new()
	assert_equal(enormous.configure(Vector2i(2, 1), Vector3i.ZERO, Vector3i(-2097152, -2097152, -2097152),
		Vector3i(4194303, 4194303, 4194303), 16, 16, 100), &"", "int32 endpoints alone do not prove int64 rank")
	var rejected: CutMap = CutMap.new()
	assert_equal(rejected.configure(PackedInt32Array([0, 0]), Vector3i.ZERO, 1, 1, enormous, 100, 1),
		CutMap.REFUSE_DOMAIN, "same key domain overflow as actual physical ledger")
	assert_true(rejected._intervals.is_empty(), "overflow refuses before scratch")


func test_huge_single_cell_and_zero_capacity_refuse_before_variable_allocation() -> void:
	"""A wide/tall cell cannot hide an enormous implicit physical bill behind one fine-cell count."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(2, 1), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i(1024, 1024, 1024), 16, 16, 100), &"", "finite wide fixture")
	for capacity: int in [0, 1, 100]:
		var cuts: CutMap = CutMap.new()
		assert_equal(cuts.configure(PackedInt32Array([0, 0]), Vector3i.ZERO, 1000000, 1000000,
			domain, 100, capacity), CutMap.REFUSE_CAPACITY, "full exact single-cell bill exceeds supplied engineering rows")
		assert_true(cuts._intervals.is_empty(), "no allocation before inevitable capacity refusal")
		assert_equal(cuts.emitted_count(), 0, "no partial or paid work is emitted")


func test_full_existing_footprint_ceiling_uses_only_one_interval_bank() -> void:
	"""A16,384-cell request is consumed under the same adopted cold work limit without a cube list."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(2, 1), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i(256, 32, 256), Footprint.MAX_OPERATION_CELLS, 16, Space.MAX_CHECKS), &"", "large finite fixture")
	var cells: PackedInt32Array = Footprint.rectangle(0, 0, 128, 128, Footprint.MAX_OPERATION_CELLS).cells
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.configure(cells, Vector3i.ZERO, 256, 4096, domain, 400000, Sites.MAX_SITE_CAPACITY), &"", "full shape configure")
	var count: int = 0
	while cuts.advance():
		count += 1
	assert_equal(count, 4096, "32×32×4 distinct actual quanta")
	assert_equal(cuts.refusal(), &"", "complete finite work remains")
	assert_equal(cuts._intervals.size(), Footprint.MAX_OPERATION_CELLS, "single preallocated I64 interval bank")
	assert_true(cuts.remaining_checks() > 0, "no unbounded coordinate-space scan")


func test_distant_rows_skip_empty_spans_and_closed_cursor_never_reopens() -> void:
	"""Sparse invalid-room geometry remains bounded even if its canonical row coordinates are far apart."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(2, 1), Vector3i.ZERO, Vector3i.ZERO,
		Vector3i(2, 1, 1000000), 2, 2, 100), &"", "long but representable domain")
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 0, 999999])
	var cuts: CutMap = CutMap.new()
	assert_equal(cuts.refusal(), CutMap.REFUSE_CLOSED, "unconfigured cursor is not an empty successful plan")
	assert_equal(cuts.configure(cells, Vector3i.ZERO, 1024, 1024, domain, 100, 2), &"", "sparse canonical input")
	assert_equal(_read(cuts).size(), 2, "million-row gap is skipped")
	assert_equal(cuts.refusal(), &"", "bounded sparse stream finishes")
	cuts.clear()
	assert_true(cuts._intervals.is_empty() and cuts._cells.is_empty(), "all borrowed/owned packed lifetimes dropped")
	assert_equal(cells, PackedInt32Array([0, 0, 0, 999999]), "clear never changes the caller image")
	assert_false(cuts.advance(), "closed cannot expose stale point")
	assert_equal(cuts.configure(cells, Vector3i.ZERO, 1024, 1024, domain, 100, 2), CutMap.REFUSE_CLOSED, "one operation only")
