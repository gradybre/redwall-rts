extends "res://test/framework/test_case.gd"
## Decision 1951: Routes' unregistered standing snapshot and the three write revisions it is keyed on. Every
## occupancy answer the snapshot gives must equal ADR1219's full scan, written out again here as the oracle, across
## spawns, moves, deaths, despawns, stale needs rows, unbound poses, registered rows and the excepted worker.

const Routes := preload("res://scripts/core/underground_routes.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REACH: int = Routes.UNREGISTERED_REACH_U
const BUDGET: int = 1 << 40

var _residents: Residents = null
var _transforms: Transforms = null
var _routes: Routes = null
var _refs: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func before_each() -> void:
	"""Actual Residents, Needs, Directory and Transforms, and a Routes whose occupancy columns are allocated."""
	_residents = Residents.new()
	_transforms = Transforms.new(_residents.directory())
	_routes = Routes.new(_residents, _transforms)
	_routes._allocate()
	_refs.clear()
	_rng.seed = 1951


func after_each() -> void:
	"""Drop every owner."""
	_routes = null
	_transforms = null
	_residents = null
	_refs.clear()


func _spawn(placed: bool, x: int, z: int) -> Vector2i:
	"""One actual mouse; placed at (x, 0, z) when asked, else left with no pose (UNBOUND)."""
	var ref: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
	if placed: assert_true(_transforms.place(ref, x, 0, z, 0), "actual pose")
	_refs.append(ref)
	return ref


func _row(ref: Vector2i) -> int:
	"""The resident's typed row."""
	return _residents.directory().get_typed_row(ref)


func _oracle(bounds: PackedInt32Array, except_worker: Vector2i) -> StringName:
	"""ADR1219's scan, exactly as it stood before decision 1951: the first unskipped row that refuses or reaches."""
	var low: Vector3i = Vector3i(bounds[0], bounds[1], bounds[2])
	var high: Vector3i = Vector3i(bounds[3], bounds[4], bounds[5])
	for row: int in Routes.RESIDENT_CAPACITY:
		if _routes._resident_ref(row) != NULL_REF or (except_worker.x == _residents._ref_slot[row]
				and except_worker.y == _residents._ref_generation[row] and _residents._present[row] == 1):
			continue
		var code: StringName = _oracle_row(row, low, high)
		if code != &"": return code
	return &""


func _oracle_row(row: int, low: Vector3i, high: Vector3i) -> StringName:
	"""One row of the pre-1951 `unregistered_occupant_refusal`, copied verbatim in meaning."""
	if _residents._present[row] != 1: return &""
	if _residents._needs._present[row] != 1: return &"ROUTE_TURN_ACTOR_STALE"
	if _residents._needs._health[row] <= 0: return &""
	var worker: Vector2i = Vector2i(_residents._ref_slot[row], _residents._ref_generation[row])
	var ids: Directory = _residents.directory()
	if Routes._turn_directory_row(_routes, worker, Directory.KIND_RESIDENT) != row or ids._persistent_id[worker.x] <= 0:
		return &"ROUTE_TURN_ACTOR_STALE"
	var at: int = Transforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + row
	if _transforms._bound_persistent_id[at] != ids._persistent_id[worker.x]: return &"ROUTE_TURN_ACTOR_UNBOUND"
	var root: Vector3i = Vector3i(_transforms._x[at], _transforms._y[at], _transforms._z[at])
	for axis: int in 3:
		if root[axis] - REACH >= high[axis] or root[axis] + REACH <= low[axis]: return &""
	return Routes.REFUSE_UNREGISTERED_NEAR


func _query(bounds: PackedInt32Array, except_worker: Vector2i) -> StringName:
	"""Routes' answer under an unlimited query budget."""
	_routes._occupancy_remaining = BUDGET
	return _routes._unregistered_occupants(bounds, except_worker)


func _box(x: int, z: int, width: int) -> PackedInt32Array:
	"""A query box with its low corner at (x, -256, z)."""
	return PackedInt32Array([x, -256, z, x + width, 512, z + width])


func _assert_matches(label: String, rounds: int) -> void:
	"""Random boxes (some exactly one reach from a root) and every except choice agree with the oracle."""
	for index: int in rounds:
		var x: int = _rng.randi_range(-20000, 20000)
		var z: int = _rng.randi_range(-20000, 20000)
		if index % 4 == 0 and not _refs.is_empty():
			var at: int = Transforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + _row(_refs[index % _refs.size()])
			x = _transforms._x[at] + REACH + (index % 3) - 1
			z = _transforms._z[at] - 64
		var bounds: PackedInt32Array = _box(x, z, _rng.randi_range(1, 4096))
		var except_worker: Vector2i = NULL_REF if index % 3 == 0 or _refs.is_empty() else _refs[index % _refs.size()]
		assert_equal(_query(bounds, except_worker), _oracle(bounds, except_worker), "%s: box %s" % [label, bounds])


func _crowd(count: int) -> void:
	"""`count` placed residents scattered over a 40 m square, and two that were never placed."""
	for index: int in count:
		_spawn(true, _rng.randi_range(-20000, 20000), _rng.randi_range(-20000, 20000))
	_spawn(false, 0, 0)
	_spawn(false, 0, 0)


func test_the_snapshot_answers_exactly_as_the_scan_through_every_change() -> void:
	"""Moves, deaths, despawns, a stale Needs row, a registered row and new spawns each change the answer set."""
	_crowd(40)
	_assert_matches("initial", 300)
	for ref: Vector2i in _refs.slice(0, 10):
		_transforms.place(ref, _rng.randi_range(-3000, 3000), 0, _rng.randi_range(-3000, 3000), 0)
	_assert_matches("moved", 300)
	assert_true(_residents.needs().apply_health_event(_row(_refs[3]), -100).ok, "a resident dies")
	_assert_matches("death", 300)
	assert_true(_residents.despawn(_refs[5]).ok, "a resident leaves")
	_refs.remove_at(5)
	_assert_matches("despawn", 300)
	_routes._set_resident_pair(Routes.R_SLOT, _row(_refs[7]), _refs[7])
	_assert_matches("registered", 300)
	_routes._set_resident_pair(Routes.R_SLOT, _row(_refs[7]), NULL_REF)
	_crowd(8)
	_assert_matches("respawn", 300)
	assert_true(_residents.needs().despawn(_row(_refs[11])).ok, "Needs row cleared under a present Resident")
	_assert_matches("stale needs", 300)


func test_an_earlier_refusal_or_a_later_one_decides_by_row_order() -> void:
	"""A near row before a refusing row answers NEAR; a near row after it answers the refusal."""
	var first: Vector2i = _spawn(true, 0, 0)
	var unplaced: Vector2i = _spawn(false, 0, 0)
	var last: Vector2i = _spawn(true, 100000, 0)
	assert_true(_row(first) < _row(unplaced) and _row(unplaced) < _row(last), "rows in spawn order")
	assert_equal(_query(_box(-100, -100, 200), NULL_REF), Routes.REFUSE_UNREGISTERED_NEAR, "near before the refusal")
	assert_equal(_query(_box(100000, -100, 200), NULL_REF), &"ROUTE_TURN_ACTOR_UNBOUND", "refusal before the near row")
	assert_equal(_query(_box(-100, -100, 200), first), &"ROUTE_TURN_ACTOR_UNBOUND", "the excepted worker is skipped")
	var stale: Vector2i = Vector2i(first.x, first.y + 1)
	assert_equal(_query(_box(-100, -100, 200), stale), Routes.REFUSE_UNREGISTERED_NEAR, "an older generation is not excepted")
	assert_true(_transforms.place(unplaced, 50000, 0, 0, 0), "the unplaced resident is placed")
	assert_equal(_query(_box(100000, -100, 200), NULL_REF), Routes.REFUSE_UNREGISTERED_NEAR, "placing rebuilds")
	assert_equal(_query(_box(30000, -100, 200), NULL_REF), &"", "far from everyone")


func test_the_reach_cube_is_half_open_on_every_axis() -> void:
	"""Exactly one reach away is clear; one unit nearer reaches, on x, y and z."""
	_spawn(true, 0, 0)
	for axis: int in 3:
		var clear: PackedInt32Array = PackedInt32Array([-8, -8, -8, 8, 8, 8])
		clear[axis] = REACH
		clear[axis + 3] = REACH + 10
		assert_equal(_query(clear, NULL_REF), &"", "axis %d: one reach away is clear" % axis)
		clear[axis] = REACH - 1
		assert_equal(_query(clear, NULL_REF), Routes.REFUSE_UNREGISTERED_NEAR, "axis %d: one unit nearer" % axis)
		var below: PackedInt32Array = PackedInt32Array([-8, -8, -8, 8, 8, 8])
		below[axis] = -REACH - 10
		below[axis + 3] = -REACH
		assert_equal(_query(below, NULL_REF), &"", "axis %d: the low face is clear" % axis)
		below[axis + 3] = -REACH + 1
		assert_equal(_query(below, NULL_REF), Routes.REFUSE_UNREGISTERED_NEAR, "axis %d: low face one unit in" % axis)


func test_a_query_reuses_the_snapshot_until_an_input_revision_moves() -> void:
	"""The key holds the eight tokens; an unchanged world keeps it, and each owner's write invalidates it."""
	_crowd(4)
	_query(_box(0, 0, 10), NULL_REF)
	var key: PackedInt64Array = _routes._standing_key.duplicate()
	assert_true(_routes._standing_current(), "read once, current")
	assert_equal(key[4], _residents.identity_revision(), "keyed on the Residents revision")
	assert_equal(key[5], _residents.needs().life_revision(), "keyed on the Needs revision")
	assert_equal(key[6], _residents.directory().mutation_revision(), "keyed on the Directory revision")
	assert_equal(key[7], _transforms.mutation_revision(), "keyed on the Transforms revision")
	_routes._standing_x[Routes.RESIDENT_CAPACITY - 1] = 12345 # A marker a rebuild would overwrite with INT64_MAX.
	_query(_box(5, 5, 10), NULL_REF)
	assert_equal(_routes._standing_x[Routes.RESIDENT_CAPACITY - 1], 12345, "an unchanged world does not rebuild")
	assert_equal(_routes._standing_key, key, "and keeps its key")
	_transforms.place(_refs[0], 1, 0, 1, 0)
	assert_false(_routes._standing_current(), "a pose write invalidates")
	_query(_box(0, 0, 10), NULL_REF)
	_residents.directory().create(Directory.KIND_WORLD)
	assert_false(_routes._standing_current(), "a Directory create invalidates")
	_query(_box(0, 0, 10), NULL_REF)
	var other: Transforms = Transforms.new(_residents.directory())
	other._mutation_revision = _transforms._mutation_revision
	_routes._transforms = other
	assert_false(_routes._standing_current(), "another Transforms at the same revision is not the same input")
	_routes._transforms = _transforms


func test_a_poisoned_revision_falls_back_to_the_scan() -> void:
	"""A saturated (zero) token keeps no snapshot; every answer then comes from the scan, and still matches."""
	_crowd(12)
	_transforms._mutation_revision = IntMath.INT64_MAX
	assert_equal(_transforms.mutation_revision(), 0, "Transforms poisoned")
	_assert_matches("poisoned", 200)
	assert_equal(_routes._standing_key, PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0]), "no snapshot is kept")
	assert_false(_routes._standing_current(), "and none is current")


func test_the_query_budget_is_charged_and_refused_before_any_read() -> void:
	"""ADR1219's charge is unchanged: 16 per row of capacity, refused when it would go negative."""
	_crowd(2)
	_routes._occupancy_remaining = 16 * Routes.RESIDENT_CAPACITY - 1
	assert_equal(_routes._unregistered_occupants(_box(0, 0, 10), NULL_REF), &"ROUTE_OCCUPANCY_QUERY_BUDGET", "refused")
	_routes._occupancy_remaining = 16 * Routes.RESIDENT_CAPACITY
	_routes._unregistered_occupants(_box(90000, 90000, 10), NULL_REF)
	assert_equal(_routes._occupancy_remaining, 0, "exactly the charge")


func test_residents_identity_revision_moves_on_every_identity_write() -> void:
	"""Spawn, despawn, restore and clear each move it; it is never part of the saved image."""
	var before: int = _residents.identity_revision()
	var ref: Vector2i = _spawn(true, 0, 0)
	assert_true(_residents.identity_revision() > before, "spawn")
	before = _residents.identity_revision()
	var image: PackedByteArray = _residents.state_bytes()
	_residents._mark_identity_changed()
	assert_equal(_residents.state_bytes(), image, "the token is not saved")
	var columns: Residents.Columns = Residents.Columns.new()
	assert_true(_residents.copy_columns_into(columns), "capture")
	before = _residents.identity_revision()
	assert_true(_residents.restore_columns(columns), "restore")
	assert_true(_residents.identity_revision() > before, "restore")
	before = _residents.identity_revision()
	assert_true(_residents.despawn(ref).ok, "despawn")
	assert_true(_residents.identity_revision() > before, "despawn")
	before = _residents.identity_revision()
	_residents.clear()
	assert_true(_residents.identity_revision() > before, "clear")
	_residents._identity_revision = IntMath.INT64_MAX
	assert_equal(_residents.identity_revision(), 0, "saturated is zero")
	_residents._mark_identity_changed()
	assert_equal(_residents._identity_revision, IntMath.INT64_MAX, "and stays saturated")


func test_needs_life_revision_moves_only_when_life_or_presence_changes() -> void:
	"""Health that stays above zero leaves it; a death, a spawn, a despawn, a restore and a clear move it."""
	var ref: Vector2i = _spawn(true, 0, 0)
	var needs: Needs = _residents.needs()
	var row: int = _row(ref)
	var before: int = needs.life_revision()
	assert_true(needs.apply_health_event(row, -1).ok, "hurt, still alive")
	assert_equal(needs.life_revision(), before, "no crossing, no change")
	needs._health[row] = 1
	assert_true(needs.apply_health_event(row, -1).ok, "the last point")
	assert_true(needs.life_revision() > before, "death from one crosses zero")
	before = needs.life_revision()
	var columns: Needs.Columns = Needs.Columns.new()
	assert_true(needs.copy_columns_into(columns), "capture")
	assert_true(needs.restore_columns(columns), "restore")
	assert_true(needs.life_revision() > before, "restore")
	before = needs.life_revision()
	assert_true(needs.despawn(row).ok, "despawn")
	assert_true(needs.life_revision() > before, "despawn")
	before = needs.life_revision()
	needs.clear()
	assert_true(needs.life_revision() > before, "clear")
	needs._life_revision = IntMath.INT64_MAX
	assert_equal(needs.life_revision(), 0, "saturated is zero")


func test_needs_integration_moves_the_revision_only_on_the_tick_health_reaches_zero() -> void:
	"""A starving drain that ends at zero moves it; the ticks before do not."""
	var ref: Vector2i = _spawn(true, 0, 0)
	var needs: Needs = _residents.needs()
	var row: int = _row(ref)
	needs._health[row] = 2
	needs._health_remainder[row] = 0
	var before: int = needs.life_revision()
	assert_equal(needs._integrate_health(row, -1 * Needs.HEALTH_DENOMINATOR), Needs.REFUSE_NONE, "one point lost")
	assert_equal(needs.life_revision(), before, "still alive")
	assert_equal(needs._integrate_health(row, -1 * Needs.HEALTH_DENOMINATOR), Needs.REFUSE_NONE, "the last point")
	assert_equal(needs._health[row], 0, "dead")
	assert_true(needs.life_revision() > before, "the crossing tick")


func test_directory_mutation_revision_moves_on_every_identity_write() -> void:
	"""Create, destroy, restore and clear each move it; `state_bytes()` never carries it."""
	var ids: Directory = _residents.directory()
	var before: int = ids.mutation_revision()
	var ref: Vector2i = ids.create(Directory.KIND_WORLD)
	assert_true(ids.mutation_revision() > before, "create")
	var image: PackedByteArray = ids.state_bytes()
	ids._mark_mutated()
	assert_equal(ids.state_bytes(), image, "the token is not saved")
	before = ids.mutation_revision()
	assert_true(ids.destroy(ref), "destroy")
	assert_true(ids.mutation_revision() > before, "destroy")
	var columns: Array = _directory_columns()
	assert_true(ids.copy_columns_into(columns[0], columns[1], columns[2], columns[3], columns[4], columns[5]), "capture")
	before = ids.mutation_revision()
	assert_true(ids.restore_columns(columns[0], columns[1], columns[2], columns[3], columns[4], columns[5]), "restore")
	assert_true(ids.mutation_revision() > before, "restore")
	before = ids.mutation_revision()
	ids.clear()
	assert_true(ids.mutation_revision() > before, "clear")
	ids._mutation_revision = Directory.REVISION_MAX
	assert_equal(ids.mutation_revision(), 0, "saturated is zero")


func _directory_columns() -> Array:
	"""Six capacity-sized buffers for the Directory's bulk column copy."""
	var bytes: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
	var ints: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for index: int in 2:
		bytes[index].resize(Directory.DIRECTORY_CAPACITY)
	for index: int in 4:
		ints[index].resize(Directory.DIRECTORY_CAPACITY)
	return [bytes[0], ints[0], bytes[1], ints[1], ints[2], ints[3]]
