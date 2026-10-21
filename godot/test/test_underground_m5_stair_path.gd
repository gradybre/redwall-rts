extends "res://test/framework/test_case.gd"
## Decision 2044: the M5 stair path's pure parts. Module 0 keeps v10's stops, levels and edge order; module j is
## module 0 moved by (0, -1024j, -5120j) at global levels 8j-1..8j+6; each landing's floor stops F, U and F' are filed by
## landing; P-2044-14 (a) publishes no floor walk-off or back-up and joins a landing to its module on ground rows.

const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
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
		stops.d[index] = Vector2i(next + 4, 1)
		next += 5
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
	assert_equal(StairPath.classify(_stop(1, -1, Tread.DEEP_INSIDE)), Vector2i(StairPath.KIND_D, 1), "D on landing 1")
	assert_equal(StairPath.classify(_stop(StairPath.MODULES, -1, Tread.DEEP_INSIDE)), Vector2i(-1, 0), "no D on the last")
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
	"""The plan opens with module 0's descent, sill and carry; each landing adds its five floor edges (descent, turn,
	ascent, walk-off, back-up) and, but for the last, the five ground joins at F', then module j's P'->A0', treads and
	sill."""
	var plan: PackedInt32Array = StairPath.edge_plan()
	var head: int = StairPath.descent_words() + 2 * StairPath.PLAN_WORDS + StairPath.carry_plan().size()
	var per_module: int = StairPath.PLAN_WORDS * (5 + 7 + 1 + 5 * Tread.TREADS + 2)
	assert_equal(plan.size(), head + (StairPath.MODULES - 1) * per_module + 5 * StairPath.PLAN_WORDS, "plan length")
	assert_equal(plan.slice(StairPath.descent_words() + 2 * StairPath.PLAN_WORDS, head), StairPath.carry_plan(),
		"the stair carry stays module 0's")


func test_landings_cross_on_71_72_and_join_at_f_prime() -> void:
	"""P-2044-16 (a): each landing has the walk-off F -> F' and back-up F' -> F (family 0); the ground joins all start or
	end at F' (F' -> P', F' -> H', F' -> D, H' -> F', P' -> F', D -> F'), but for decision 2045's U0' -> D (the turning
	spot R', P-2045-11 (a)); nothing on the ground touches F or U."""
	var plan: PackedInt32Array = StairPath.edge_plan()
	var floor_edges: Dictionary = {}
	var joins: Dictionary = {}
	var at_f: Array[int] = [StairPath.KIND_F, StairPath.KIND_UF]
	for at: int in range(0, plan.size(), StairPath.PLAN_WORDS):
		var edge: Vector4i = Vector4i(plan[at], plan[at + 1], plan[at + 2], plan[at + 3])
		var at_fp: bool = plan[at] == StairPath.KIND_FP or plan[at + 2] == StairPath.KIND_FP \
			or (plan[at] == StairPath.KIND_U and plan[at + 2] == StairPath.KIND_D)
		assert_false(plan[at + 4] == -1 and (plan[at] in at_f or plan[at + 2] in at_f), "no ground edge at F or U: %s" % edge)
		if plan[at + 4] == 0 and at_fp: floor_edges[edge] = true
		if plan[at + 4] == -1 and at_fp: joins[edge] = true
	for landing: int in range(1, StairPath.MODULES + 1):
		assert_true(floor_edges.has(Vector4i(StairPath.KIND_F, landing, StairPath.KIND_FP, landing)), "walk-off %d" % landing)
		assert_true(floor_edges.has(Vector4i(StairPath.KIND_FP, landing, StairPath.KIND_F, landing)), "back-up %d" % landing)
	for landing: int in range(1, StairPath.MODULES):
		var foot: int = StairPath.global_level(landing, -1)
		for join: Vector4i in [Vector4i(StairPath.KIND_FP, landing, StairPath.KIND_P, foot),
				Vector4i(StairPath.KIND_FP, landing, StairPath.KIND_H, foot),
				Vector4i(StairPath.KIND_H, foot, StairPath.KIND_FP, landing),
				Vector4i(StairPath.KIND_U, foot, StairPath.KIND_D, landing),
				Vector4i(StairPath.KIND_P, foot, StairPath.KIND_FP, landing),
				Vector4i(StairPath.KIND_FP, landing, StairPath.KIND_D, landing),
				Vector4i(StairPath.KIND_D, landing, StairPath.KIND_FP, landing)]:
			assert_true(joins.has(join), "landing %d join %s" % [landing, join])
	assert_equal(joins.size(), 7 * (StairPath.MODULES - 1), "no other ground join")


func test_hops_down_cross_each_landing_by_its_floor_and_p_prime() -> void:
	"""Down to module 1's T3: P, A0, module 0's descents, F1, the walk-off to F'1, P'1, A0'1, then module 1's T0..T3."""
	var stops: StairPath.Stops = _full_stops()
	var target: int = StairPath.global_level(1, 3)
	var hops: Array = StairPath.hops_down(stops, target)
	assert_equal(hops.size(), 2 + (7 + 4) + 4, "hop count")
	assert_equal(hops[9], [stops.f[1], StairPins.CLAW_DESCENT_ROW], "onto landing 1")
	assert_equal(hops[10], [stops.fp[1], StairPins.STAIR_EMPTY_FLOOR_ROWS[0]], "the walk-off")
	assert_equal(hops[11], [stops.s[StairPath.global_level(1, -1) + 1], StairPins.CLAW_APPROACH_ROWS[0]], "F' -> P'")
	assert_equal(hops[hops.size() - 1], [stops.a[target + 1], StairPins.CLAW_DESCENT_ROW], "arrives at T3's A")


func test_hops_up_climb_back_through_each_landing() -> void:
	"""Up from module 1's T3: its ascents to U0', on to the turning spot R' on the approach 45 and back to F' on the
	retreat 47 (decision 2045, P-2045-11 (a)), the back-up to F, the half-turn onto U, the floor ascent onto module 0's
	sill, then up to X."""
	var stops: StairPath.Stops = _full_stops()
	var hops: Array = StairPath.hops_up(stops, StairPath.global_level(1, 3))
	assert_equal(hops[4], [stops.d[1], StairPins.CLAW_APPROACH_ROWS[2]], "U0' -> R' on landing 1, facing up")
	assert_equal(hops[5], [stops.fp[1], StairPins.CLAW_RETREAT_ROWS[0]], "R' -> F', turned to face down")
	assert_equal(hops[6], [stops.f[1], StairPins.STAIR_EMPTY_FLOOR_ROWS[1]], "the back-up")
	assert_equal(hops[7], [stops.uf[1], StairPins.CLAW_TURN_ROW], "the half-turn")
	assert_equal(hops[8], [stops.u[StairPath.global_level(0, 6) + 1], StairPins.CLAW_ASCENT_ROW], "onto module 0's sill")
	assert_equal(hops[hops.size() - 1], [stops.x, StairPins.CLAW_APPROACH_ROWS[2]], "ends at X")
	assert_equal(hops.size(), 4 + (2 + 2 + 1 + 7) + 1, "hop count")


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


func test_every_m5_hop_list_fits_the_saved_leg_lists() -> void:
	"""Decision 2045: an installation plan's down, up and chain lists are saved with at most Progress.MAX_STAIR_LEGS legs
	each; every M5 hop list (down to and up from every level, to and from every landing's walk-off) fits."""
	var stops: StairPath.Stops = _full_stops()
	var longest: int = 0
	for module: int in StairPath.MODULES:
		for level: int in range(-1, 7):
			var at: int = StairPath.global_level(module, level)
			longest = maxi(longest, maxi(StairPath.hops_down(stops, at).size(), StairPath.hops_up(stops, at).size()))
	for landing: int in range(1, StairPath.MODULES):
		longest = maxi(longest, StairPath.hops_down_to_walk_off(stops, landing).size())
		longest = maxi(longest, StairPath.hops_up_from_walk_off(stops, landing).size())
		longest = maxi(longest, StairPath.hops_up_from_landing(stops, landing).size())
	assert_equal(longest, 56, "up from module 4's deepest stop to X")
	assert_true(longest <= Progress.MAX_STAIR_LEGS, "every list fits the saved record")
	assert_true(longest + 1 <= Progress.MAX_HAUL_LEGS, "and an installer's haul up its whole list, then to M (the review's H2)")


func _legs_record(count: int) -> Progress.Writer:
	"""A stair leg list of `count` legs as the installer writes it."""
	var rows: PackedInt64Array = PackedInt64Array()
	for leg: int in count: rows.append_array(PackedInt64Array([leg, 1, 7 * leg, 1000 + leg]))
	var w: Progress.Writer = Progress.Writer.new()
	Installer._write_legs(w, rows)
	return w


func test_a_leg_list_the_reader_admits_round_trips_and_a_longer_one_refuses_the_capture() -> void:
	"""Decision 2045: the writer refuses (`overflow`) exactly the lists the reader cannot read back."""
	var fits: Progress.Writer = _legs_record(Progress.MAX_STAIR_LEGS)
	assert_false(fits.overflow, "the longest admitted list writes")
	var r: Progress.Reader = Progress.Reader.new()
	r.bytes = fits.bytes
	var rows: PackedInt64Array = Installer._read_legs(r)
	assert_false(r.bad, "and reads back")
	assert_equal(rows.size(), 4 * Progress.MAX_STAIR_LEGS, "every leg")
	assert_equal(rows[rows.size() - 1], 1000 + Progress.MAX_STAIR_LEGS - 1, "in order")
	assert_true(_legs_record(Progress.MAX_STAIR_LEGS + 1).overflow, "one leg more refuses the capture")
