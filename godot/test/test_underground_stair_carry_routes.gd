extends "res://test/test_underground_stair_routes.gd"
## Decision 1972: ADR 1229's hand fixture on content 12 (`qualified-stair-carry-v13`). Every inherited claw stair test
## reruns on content 12 with milli-u/s stair paces; the tests below drive decision 1981's rooted rows (the stair's
## empty floor end and the stair carry) on actual Routes, WorldRoutes and Profiles owners. The loaded crossings (a
## descent, the 90-tick retreat and the floor half-turn) need Routes' CARRY re-selection line and WorldRoutes'
## table-turn line, which land after the cost lane; they join this suite then.

const CarryPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const CarryMotion := preload("res://data/underground/mole-worker/qualified-stair-carry-motion-v1/catalog_source.gd")
const CARRY_WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const CARRY_GROUND: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/ground-pace.ugconn"
## Decision 1972's bundle rule, rate = ceil(length x 30,000 / ticks): 30 ticks a tread, 45 a half-turn, 90 a handoff.
const CARRY_PACES: Array[Vector3i] = [Vector3i(53, 528000, 2), Vector3i(54, 528000, 2), Vector3i(55, 116000, 2),
	Vector3i(71, 114334, 2), Vector3i(72, 114334, 2), Vector3i(73, 114334, 2), Vector3i(74, 528000, 2),
	Vector3i(75, 528000, 2), Vector3i(76, 116000, 2), Vector3i(77, 56334, 2), Vector3i(78, 114334, 2),
	Vector3i(79, 114334, 2), Vector3i(80, 528000, 2), Vector3i(81, 528000, 2), Vector3i(82, 116000, 2),
	Vector3i(83, 56334, 2), Vector3i(84, 114334, 2)]
## The flat fixture: one 128 u World-owned SUPPORT slab under a long floor, as the stair's floor decks were proved on.
var _flat: bool = false


func _select_content() -> void:
	"""Content 12 with every stair and rooted pace."""
	_content = 12
	_counts = Vector3i(85, 637, 8)
	_wire = CARRY_WIRE
	_wire_sha = CarryPins.WIRE_SHA
	_ground_wire = CARRY_GROUND
	_paces = CARRY_PACES
	_flat = false
	_catalog_expected = &""


func _load_motion() -> void:
	"""The claw stair tables, then the stair-carry tables appended."""
	super._load_motion()
	assert_equal(_motion.load_carry_file(CarryMotion.WIRE_PATH, CarryMotion.WIRE_SHA), &"", "stair-carry tables")


func _space(lower_deck: bool, obstacle: bool) -> Space.Domain:
	"""The two-deck fixture, or the flat floor."""
	return _flat_space() if _flat else super._space(lower_deck, obstacle)


func _flat_space() -> Space.Domain:
	"""A floor at UP over z [Z, Z + 12288): its datum, a 128 u World SUPPORT slab and the void above."""
	_routes = Routes.new(_residents, _transforms)
	_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "Domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	var datum: Vector2i = _region(token, _slab(UP, Z, Z + 12288, UP + 1), Space.FLOOR_DATUM)
	_floors = [datum, datum, datum]
	_region(token, _slab(UP - 128, Z, Z + 12288, UP), Space.SUPPORT)
	_region(token, _slab(UP, Z, Z + 12288, 2560), Space.SUPPORTED_VOID)
	assert_equal(_owner.seal(token), &"", "sealed")
	_owner.publish(token)
	return domain


func _admit(start: Vector2i, profile: int, at: Vector3i, yaw: int) -> StringName:
	"""Place the mole and admit it on one explicit row."""
	assert_true(_transforms.place(_worker, at.x, at.y, at.z, yaw), "pose")
	return _routes.admit_travel_actor(_worker, NULL_REF, start, profile, 1, _content, 0, -1, NULL_REF)


func _cross(target: Vector2i, ticks: int) -> Array:
	"""Request the route and run `ticks` real ticks."""
	_tick += 1
	assert_equal(_routes.request_route(_worker, target, _tick), &"", "route")
	return _run(ticks)


func test_the_empty_walk_off_crosses_343_u_in_ninety_ticks() -> void:
	"""Row 71 (F -> F', the empty walk-off) at 114,334 milli-u/s: exactly 90 ticks, one key a tick on its table's
	root track, ending READY on F'."""
	_flat = true
	_compose()
	var f: Vector3i = Vector3i(X + 1024, UP, Z + 4096)
	var back: Vector3i = f + Vector3i(0, 0, -343)
	var start: Vector2i = _location(f, 0, false, 300)
	var end: Vector2i = _location(back, 0, false, 300)
	var added: Routes.Result = _publish(_edge(start, end, f, back, 0))
	assert_equal(added.error, &"", "the floor edge qualifies on its floor deck")
	assert_true(CarryPins.STAIR_EMPTY_FLOOR_ROWS[0] in _masked(added.ref), "the walk-off fits")
	assert_equal(_admit(start, CarryPins.STAIR_EMPTY_FLOOR_ROWS[0], f, 0), &"", "admitted empty")
	var poses: Array = _cross(end, 90)
	var program: int = _motion.program_of(CarryPins.STAIR_EMPTY_FLOOR_ROWS[0])
	assert_equal(poses[44][0], f + _motion.root_at(program, 45), "key 45 on tick 45")
	assert_equal([poses[89][0], poses[89][2], poses[89][3]], [back, end, Stair.word(Routes.PHASE_IDLE, Stair.READY)],
		"on F' in 90 ticks, READY")


func test_stair_timings_are_reported_in_milli_u_per_s() -> void:
	"""The catalog reports every stair-program row's pace in milli-u/s: the authored milli rows as stored, a u/s
	ground cap of a step row times 1,000; a non-stair row keeps its u/s cap."""
	_compose()
	var pace: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	for row: Vector2i in [Vector2i(53, 528000), Vector2i(77, 56334), Vector2i(76, 116000), Vector2i(71, 114334)]:
		assert_equal(_catalog.pace_into(row.x, 1, 12, 0, 0, 1, pace), &"", "row %d" % row.x)
		assert_equal(pace.value, row.y, "row %d in milli-u/s" % row.x)
	assert_equal(_catalog.pace_into(Pins.CLAW_STEP_BACK_ROW, 1, 12, -1, 0, 1, pace), &"", "step ground cap")
	var step: int = pace.value
	assert_equal(_catalog.pace_into(Pins.CLAW_WALK_ROW, 1, 12, -1, 0, 1, pace), &"", "claw walk ground cap")
	assert_equal(step, pace.value * Catalog.MILLI, "the step's cap times 1,000, the walk's not")


func test_a_milli_pace_on_a_row_the_stair_program_does_not_own_is_refused() -> void:
	"""RATE_AUTHORED_MILLI is a stair timing only: the narrow approach (row 43) may not carry one."""
	_paces = CARRY_PACES.duplicate()
	_paces.insert(0, Vector3i(Pins.CLAW_APPROACH_ROWS[0], 114334, Catalog.RATE_AUTHORED_MILLI))
	_catalog_expected = &"CONNECTOR_PACE_UNAUTHORED"
	_compose()


func test_a_rooted_carry_row_paces_only_its_stair_and_only_while_rooted() -> void:
	"""A loaded rooted row may pace the WALK stair variant from its own source; with its policy byte cleared it is an
	ordinary source-6 row on a source-4 catalog and is refused."""
	_compose()
	var policy: int = _profiles._live.flags[_profiles._profile_capacity + 74]
	assert_equal(policy, Profiles.POLICY_ROOTED_STAIR, "row 74 is rooted")
	var pace: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	assert_equal(_catalog.pace_into(74, 1, 12, 0, 0, 1, pace), &"", "CARRY on the WALK variant, source 6")
	_profiles._live.flags[_profiles._profile_capacity + 74] = Profiles.POLICY_AUTOMATIC
	assert_equal(_catalog.pace_into(74, 1, 12, 0, 0, 1, pace), &"CONNECTOR_PACE_PROFILE", "not rooted: wrong source")
	_profiles._live.flags[_profiles._profile_capacity + 74] = policy
