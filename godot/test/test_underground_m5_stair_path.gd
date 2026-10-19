extends "res://test/framework/test_case.gd"
## Decision 2044: the M5 stair path's pure parts. Module 0 keeps v10's stops, levels and edge order; module j is
## module 0 moved by (0, -1024j, -5120j) at global levels 8j-1..8j+6; each landing's floor stops F, U and F' are filed by
## landing; P-2044-14 (a) publishes no floor walk-off or back-up and joins a landing to its module on ground rows.

const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const StairPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)


func _stop(module: int, level: int, behind: int) -> Vector3i:
	"""A source-local stop `behind` u behind module `module`'s level `level` far edge."""
	return Vector3i(0, -Tread.MODULE_DROP * module - Tread.RISE * (level + 1), Tread.far_z(level) + behind
		- Tread.MODULE_RUN * module)


func _full_stops() -> StairPath.Stops:
	"""Every stop live, each with its own handle."""
	var stops: StairPath.Stops = StairPath.Stops.new()
	var next: int = 1
	stops.x = Vector2i(next, 1)
	stops.p = Vector2i(next + 1, 1)
	next += 2
	for index: int in StairPath.LEVELS:
		stops.a[index] = Vector2i(next, 1)
		stops.s[index] = Vector2i(next + 1, 1)
		stops.u[index] = Vector2i(next + 2, 1)
		next += 3
	for index: int in StairPath.MODULES + 1:
		stops.hm[index] = Vector2i(next, 1)
		stops.f[index] = Vector2i(next + 1, 1)
		stops.uf[index] = Vector2i(next + 2, 1)
		stops.fp[index] = Vector2i(next + 3, 1)
		next += 4
	stops.h = stops.hm[0]
	return stops


func test_module_zero_stops_classify_as_v10s() -> void:
	"""X, L0's P/A/U and H, and each tread's A/S/U keep v10's kinds at levels -1..6."""
	assert_equal(StairPath.classify(Vector3i(0, 0, StairPath.CROSSING_Z)), Vector2i(StairPath.KIND_X, -1), "X")
	assert_equal(StairPath.classify(_stop(0, -1, Tread.STATION)), Vector2i(StairPath.KIND_P, -1), "P")
	assert_equal(StairPath.classify(_stop(0, -1, Tread.ARRIVAL + StairPath.HANDOFF_U)), Vector2i(StairPath.KIND_H, -1), "H")
	for level: int in range(0, 7):
		assert_equal(StairPath.classify(_stop(0, level, Tread.ARRIVAL)), Vector2i(StairPath.KIND_A, level), "A %d" % level)
		assert_equal(StairPath.classify(_stop(0, level, Tread.STATION)), Vector2i(StairPath.KIND_S, level), "S %d" % level)
		assert_equal(StairPath.classify(_stop(0, level, Tread.ASCENT_START)), Vector2i(StairPath.KIND_U, level), "U %d" % level)
	assert_equal(StairPath.classify(Vector3i(1, 0, StairPath.CROSSING_Z)), Vector2i(-1, 0), "off the axis")


func test_a_later_modules_stops_are_module_zeros_at_shifted_levels() -> void:
	"""Module j's A/S/U at level l are global level 8j + l; its L0 position's P' and H' at 8j - 1."""
	for module: int in range(1, StairPath.MODULES):
		var base: int = StairPath.MODULE_LEVELS * module
		assert_equal(StairPath.classify(_stop(module, -1, Tread.STATION)), Vector2i(StairPath.KIND_P, base - 1), "P' %d" % module)
		assert_equal(StairPath.classify(_stop(module, -1, Tread.ARRIVAL + StairPath.HANDOFF_U)),
			Vector2i(StairPath.KIND_H, base - 1), "H' %d" % module)
		for level: int in range(0, 7):
			assert_equal(StairPath.classify(_stop(module, level, Tread.ARRIVAL)), Vector2i(StairPath.KIND_A, base + level),
				"module %d A %d" % [module, level])
	assert_equal(StairPath.module_of_level(StairPath.MODULE_LEVELS - 1), 1, "module 1's L0 level")
	assert_equal(StairPath.module_of_level(StairPath.MODULE_LEVELS - 2), 0, "module 0's sill")


func test_floor_stops_are_filed_by_landing() -> void:
	"""On landing j (module j's L0 position) F, U and F' stand 1193, 1367 and 850 u behind; the last landing has only
	its floor stops, and nothing classifies below it."""
	for landing: int in range(1, StairPath.MODULES + 1):
		assert_equal(StairPath.classify(_stop(landing, -1, StairPath.FLOOR_ARRIVAL_BEHIND)),
			Vector2i(StairPath.KIND_F, landing), "F %d" % landing)
		assert_equal(StairPath.classify(_stop(landing, -1, StairPath.FLOOR_ASCENT_BEHIND)),
			Vector2i(StairPath.KIND_UF, landing), "U %d" % landing)
		assert_equal(StairPath.classify(_stop(landing, -1, StairPath.FLOOR_WALK_OFF_BEHIND)),
			Vector2i(StairPath.KIND_FP, landing), "F' %d" % landing)
	assert_equal(StairPath.classify(_stop(StairPath.MODULES, -1, Tread.STATION)), Vector2i(-1, 0), "no P' on the last")
	assert_equal(StairPath.classify(_stop(StairPath.MODULES, 0, Tread.ARRIVAL)), Vector2i(-1, 0), "no tread below")


func test_record_and_at_round_trip() -> void:
	"""Every classified stop files where `at` reads it back."""
	var stops: StairPath.Stops = StairPath.Stops.new()
	var cases: Array[Vector2i] = [Vector2i(StairPath.KIND_H, StairPath.MODULE_LEVELS - 1), Vector2i(StairPath.KIND_F, 1),
		Vector2i(StairPath.KIND_UF, StairPath.MODULES), Vector2i(StairPath.KIND_FP, 2),
		Vector2i(StairPath.KIND_A, StairPath.LEVELS - 2),
		Vector2i(StairPath.KIND_P, 7), Vector2i(StairPath.KIND_U, -1), Vector2i(StairPath.KIND_X, -1)]
	for index: int in cases.size():
		StairPath.record(stops, cases[index], Vector2i(10 + index, 1))
	for index: int in cases.size():
		assert_equal(stops.at(cases[index].x, cases[index].y), Vector2i(10 + index, 1), "kind/level %s" % cases[index])
	assert_equal(stops.at(StairPath.KIND_F, 0), NULL_REF, "no landing 0")
	assert_equal(stops.at(StairPath.KIND_A, StairPath.LEVELS), NULL_REF, "past the last level")


func test_module_zero_plan_is_v10s_then_the_landings() -> void:
	"""The plan opens with module 0's descent, sill and carry; each landing adds its three floor edges and, but for the
	last, the four ground joins, then module j's P'->A0', treads and sill."""
	var plan: PackedInt32Array = StairPath.edge_plan()
	var head: int = StairPath.descent_words() + 2 * StairPath.PLAN_WORDS + StairPath.carry_plan().size()
	var per_module: int = StairPath.PLAN_WORDS * (3 + 4 + 1 + 5 * Tread.TREADS + 2)
	assert_equal(plan.size(), head + (StairPath.MODULES - 1) * per_module + 3 * StairPath.PLAN_WORDS, "plan length")
	assert_equal(plan.slice(StairPath.descent_words() + 2 * StairPath.PLAN_WORDS, head), StairPath.carry_plan(),
		"the stair carry stays module 0's")


func test_no_floor_walk_off_or_back_up_and_ground_joins() -> void:
	"""P-2044-14 (a): no edge touches F'; F -> P', F -> H', H' -> F and U0' -> U are WALK on the ground family."""
	var plan: PackedInt32Array = StairPath.edge_plan()
	var joins: Dictionary = {}
	for at: int in range(0, plan.size(), StairPath.PLAN_WORDS):
		assert_false(plan[at] == StairPath.KIND_FP or plan[at + 2] == StairPath.KIND_FP, "no edge at F' (word %d)" % at)
		if plan[at] == StairPath.KIND_F and plan[at + 4] == -1 or plan[at + 2] == StairPath.KIND_F and plan[at + 4] == -1 \
				or plan[at] == StairPath.KIND_U and plan[at + 2] == StairPath.KIND_UF:
			assert_equal(plan[at + 5], StairPath.Profiles.MODE_WALK, "a WALK join")
			joins[Vector4i(plan[at], plan[at + 1], plan[at + 2], plan[at + 3])] = true
	for landing: int in range(1, StairPath.MODULES):
		var foot: int = StairPath.global_level(landing, -1)
		for join: Vector4i in [Vector4i(StairPath.KIND_F, landing, StairPath.KIND_P, foot),
				Vector4i(StairPath.KIND_F, landing, StairPath.KIND_H, foot), Vector4i(StairPath.KIND_H, foot, StairPath.KIND_F, landing),
				Vector4i(StairPath.KIND_U, foot, StairPath.KIND_UF, landing)]:
			assert_true(joins.has(join), "landing %d join %s" % [landing, join])
	assert_equal(joins.size(), 4 * (StairPath.MODULES - 1), "no other ground join")


func test_hops_down_cross_each_landing_by_its_floor_and_p_prime() -> void:
	"""Down to module 1's T3: P, A0, module 0's descents, F1, P'1, A0'1, then module 1's T0..T3."""
	var stops: StairPath.Stops = _full_stops()
	var target: int = StairPath.global_level(1, 3)
	var hops: Array = StairPath.hops_down(stops, target)
	assert_equal(hops.size(), 2 + (7 + 3) + 4, "hop count")
	assert_equal(hops[9], [stops.f[1], StairPins.CLAW_DESCENT_ROW], "onto landing 1")
	assert_equal(hops[10], [stops.s[StairPath.global_level(1, -1) + 1], StairPins.CLAW_APPROACH_ROWS[0]], "F -> P'")
	assert_equal(hops[hops.size() - 1], [stops.a[target + 1], StairPins.CLAW_DESCENT_ROW], "arrives at T3's A")


func test_hops_up_climb_back_through_each_landing() -> void:
	"""Up from module 1's T3: its ascents to U0', U0' -> U1, the floor ascent onto module 0's sill, then up to X."""
	var stops: StairPath.Stops = _full_stops()
	var hops: Array = StairPath.hops_up(stops, StairPath.global_level(1, 3))
	assert_equal(hops[4], [stops.uf[1], StairPins.CLAW_APPROACH_ROWS[2]], "U0' -> U on landing 1")
	assert_equal(hops[5], [stops.u[StairPath.global_level(0, 6) + 1], StairPins.CLAW_ASCENT_ROW], "onto module 0's sill")
	assert_equal(hops[hops.size() - 1], [stops.x, StairPins.CLAW_APPROACH_ROWS[2]], "ends at X")
	assert_equal(hops.size(), 4 + (1 + 1 + 7) + 1, "hop count")


func test_deep_stations_classify_by_landing_row_and_column() -> void:
	"""A deep station stands 406 u inside its uphill row at x -300/+300 on a landing's floor."""
	var landing: int = 1
	var row: int = Tread.deep_first_row(landing)
	var z: int = -Tread.ROW_U * Tread.ROWS + Tread.ROW_U * (Tread.ROWS - 1 - row) + Tread.DEEP_INSIDE
	assert_equal(StairPath.classify_deep(Vector3i(-300, -1024 * landing, z)), Vector3i(landing, row, 0), "left")
	assert_equal(StairPath.classify_deep(Vector3i(300, -1024 * landing, z)), Vector3i(landing, row, 1), "right")
	assert_equal(StairPath.classify_deep(Vector3i(0, -1024 * landing, z)), Vector3i(-1, 0, 0), "not a column")
	assert_equal(StairPath.classify_deep(Vector3i(-300, -1024 * landing, z + 1)), Vector3i(-1, 0, 0), "off the row")
	assert_equal(StairPath.classify_deep(Vector3i(-300, -1024 * StairPath.MODULES, z)), Vector3i(-1, 0, 0), "no floor below")
