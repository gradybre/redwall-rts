extends "res://test/framework/test_case.gd"
## Decision 2054 (slice D2 phase 2): the foot of the finished M5 flight. The layout the way in publishes there (hub,
## parking, store, its grip stand, pile) and the end-wall room's front are held clear of the run-out's walls and the
## last sill by the content's own row boxes (the stand's clearance, P-2091-7 (a)); the host's readers and refusals
## before the flight is done. The live foot on the finished flight is proved by test_underground_way_in_level1.gd.

const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const WayFoot := preload("res://scripts/core/underground_way_foot.gd")
const WayIn := preload("res://scripts/core/underground_way_in.gd")
const Prep := preload("res://scripts/core/underground_way_in_foot_prep.gd")
const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
## The chain fixture's entry origin (`underground_entry_chain.gd` NEAR on the cube grid; the probe's origin).
const ORIGIN: Vector3i = Vector3i(122880, 512, 102400)
## The turning spot: where the all-yaw ground row's turn sweep (+-712) clears both side walls, the end wall and the sill.
const TURN_X: Vector2i = Vector2i(-312, 312)
const TURN_Z: Vector2i = Vector2i(712, 824)
## The store's grip stand, and where the loaded span from the hub bends onto its line.
const STAND: Vector2i = Vector2i(-256, 714)
const BEND: Vector2i = Vector2i(0, 714)

var _host: Node = null


func before_each() -> void:
	"""A generated settlement, mounted and composed (content 12's rows)."""
	_host = Settlement.new()
	assert_equal(Chain.mount_and_compose(_host, Chain.load_content()), &"", "composed")


func after_each() -> void:
	"""Free the host; hand the autoload back."""
	if _host != null: _host.free()
	_host = null
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _profiles() -> Profiles:
	"""The mounted Profiles."""
	return _host.underground_session()._retirement_owners.profiles


func _sill() -> PackedInt32Array:
	"""The last sill as [far edge z, top y] in u from the end wall and the floor (the flight's own geometry)."""
	var last: int = Flight.layout_tread_count(WayFoot.LAYOUT) - 1
	var wall: int = Flight.layout_end_wall_z(WayFoot.LAYOUT)
	return PackedInt32Array([Flight.layout_tread_far_z(WayFoot.LAYOUT, last) - wall,
		Flight.layout_tread_top_y(WayFoot.LAYOUT, last) + Flight.LEVEL_DROP])


func _blocked(row: int, at: Vector2i) -> String:
	"""The reason a row's body at (x, z) from the end wall meets the run-out's walls or the last sill, or ""."""
	var p: Profiles = _profiles()
	var box: Profiles.Box = Profiles.Box.new()
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	var sill: PackedInt32Array = _sill()
	if p.descriptor_into(row, WayFoot.CLAW_CONTENT, d) != &"": return "row %d unreadable" % row
	for ordinal: int in d.box_count:
		p.box_into(row, d.profile_revision, WayFoot.CLAW_CONTENT, ordinal, box)
		if box.role != Profiles.BODY_HELD_LOAD and box.role != Profiles.TURN_RECOVERY \
				and box.role != Profiles.WORK_APPROACH: continue
		var low: Vector3i = Vector3i(at.x, 0, at.y) + box.low
		var high: Vector3i = Vector3i(at.x, 0, at.y) + box.high
		if low.x < -Flight.HALF_WIDTH or high.x > Flight.HALF_WIDTH: return "row %d box %d meets a side wall" % [row, ordinal]
		if low.z < 0: return "row %d box %d meets the end wall" % [row, ordinal]
		if high.z > sill[0] and (maxi(low.y, 0) < sill[1] or high.z > sill[0] + Flight.RUN):
			return "row %d box %d meets the sill" % [row, ordinal]
	return ""


func _within(row: int, air_row: int) -> bool:
	"""Whether every body box of `row` lies inside `air_row`'s body box (BODY_HELD_LOAD 0) at the same root."""
	var p: Profiles = _profiles()
	var box: Profiles.Box = Profiles.Box.new()
	var air: Profiles.Box = Profiles.Box.new()
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	p.descriptor_into(air_row, WayFoot.CLAW_CONTENT, d)
	p.box_into(air_row, d.profile_revision, WayFoot.CLAW_CONTENT, 0, air)
	p.descriptor_into(row, WayFoot.CLAW_CONTENT, d)
	for ordinal: int in d.box_count:
		p.box_into(row, d.profile_revision, WayFoot.CLAW_CONTENT, ordinal, box)
		if box.role != Profiles.BODY_HELD_LOAD and box.role != Profiles.TURN_RECOVERY: continue
		for axis: int in [0, 2]:
			if box.low[axis] < air.low[axis] or box.high[axis] > air.high[axis]: return false
	return true


func _clear(rows: PackedInt32Array, at: Vector2i) -> void:
	"""Every row's body at the point is clear."""
	for row: int in rows:
		assert_equal(_blocked(row, at), "", "row %d at %s" % [row, at])


func test_the_layout_is_measured_from_the_flights_own_end_wall() -> void:
	"""F' is FLOOR_WALK_OFF beyond the last sill's far edge (RUN_OUT from the end wall), on level 1's floor; the stair
	path files that point as the last landing's F'; the stand is the certified offset from the store."""
	var wall: Vector3i = WayFoot.end_wall(ORIGIN)
	assert_equal(wall, ORIGIN + Vector3i(0, -5120, -27648), "the end wall: 27 rows down the flight, one level down")
	assert_equal(_sill()[0], Flight.RUN_OUT, "the last sill's far edge is RUN_OUT from the wall")
	assert_equal(_sill()[1], 128, "the sill stands one rise above the floor")
	assert_equal(WayFoot.at(ORIGIN, WayFoot.STAIR), ORIGIN + Vector3i(0, -5120, -26798), "F'(5), as the probe found it")
	assert_equal(StairPath.classify(WayFoot.at(ORIGIN, WayFoot.STAIR) - ORIGIN),
		Vector2i(StairPath.KIND_FP, StairPath.MODULES), "the stair path's own F'(5)")
	var foot: WayIn.Foot = WayIn.Foot.new()
	foot.store_point = WayFoot.at(ORIGIN, WayFoot.STORE)
	assert_equal(Prep.stand_point(foot) - foot.store_point, -Grip.stock_offset(Grip.QUARTER), "the grip stand")
	assert_equal(Prep.stand_point(foot), WayFoot.at(ORIGIN, STAND), "west of the hub's line")


func test_the_rows_are_content_12s_claw_rows_at_their_headings() -> void:
	"""Wall rows 67/68/70 are WORK at yaw 0/16384/49152 with READY rows at the same yaws; 42 walks at every yaw; the
	retreat row 49 and its forward partner 45 face up the flight (yaw 32768)."""
	var p: Profiles = _profiles()
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	var yaws: Array[int] = [0, 16384, 49152]
	for heading: int in 3:
		for row: int in [WayFoot.WALL_ROWS[heading], WayFoot.FORWARD_ROWS[heading], WayFoot.BACKWARD_ROWS[heading]]:
			assert_equal(p.descriptor_into(row, WayFoot.CLAW_CONTENT, d), &"", "row %d" % row)
			assert_equal([d.yaw_kind, d.yaw], [Profiles.YAW_EXACT, yaws[heading]], "row %d's heading" % row)
		p.descriptor_into(WayFoot.WALL_ROWS[heading], WayFoot.CLAW_CONTENT, d)
		assert_equal(d.mode, Profiles.MODE_WORK, "a wall row")
	p.descriptor_into(WayFoot.GROUND_ROW, WayFoot.CLAW_CONTENT, d)
	assert_equal([d.mode, d.yaw_kind], [Profiles.MODE_WALK, Profiles.YAW_ALL], "the all-yaw ground walk")
	for row: int in [WayFoot.RETREAT_ROW, 45]:
		p.descriptor_into(row, WayFoot.CLAW_CONTENT, d)
		assert_equal([d.mode, d.yaw], [Profiles.MODE_WALK, 32768], "row %d faces up the flight" % row)
	for row: int in [32, 37]:
		p.descriptor_into(row, WayFoot.CLAW_CONTENT, d)
		assert_equal([d.mode, d.yaw_kind], [Profiles.MODE_CARRY, Profiles.YAW_ALL], "carry row %d" % row)


func test_the_stand_and_its_loaded_span_clear_the_walls_and_the_sill() -> void:
	"""P-2091-7 (a): the grip rows at the stand, and both carry rows at the hub, the bend and the stand (each leg runs
	along one axis, so its sweep is the union of its ends), clear the side and end walls and the last sill; the span's
	last leg runs -X, so it enters the stand on the grip heading (the worker faces -X onto the stock)."""
	_clear(PackedInt32Array([34, 36]), STAND)
	for at: Vector2i in [WayFoot.HUB, BEND, STAND]:
		_clear(PackedInt32Array([32, 37]), at)
	assert_true(BEND.x == WayFoot.HUB.x and BEND.y == STAND.y and STAND.x < BEND.x, "down the flight, then -X")


func test_the_hub_and_parking_clear_the_walls_and_the_sill() -> void:
	"""The hub holds every row that turns or walks there, the parking its retreat family."""
	_clear(WayFoot.HUB_ROWS, WayFoot.HUB)
	_clear(WayFoot.PARKING_ROWS, WayFoot.PARKING)
	assert_equal(_blocked(WayFoot.GROUND_ROW, Vector2i(TURN_X.x, TURN_Z.x)), "", "the turning spot's corner")
	assert_true(_blocked(WayFoot.GROUND_ROW, Vector2i(TURN_X.x - 1, TURN_Z.x)) != "", "one unit west: no turn")
	assert_true(_blocked(WayFoot.GROUND_ROW, Vector2i(TURN_X.x, TURN_Z.x - 1)) != "", "one unit nearer the wall: none")
	assert_true(_blocked(WayFoot.GROUND_ROW, Vector2i(TURN_X.y, TURN_Z.y + 1)) != "", "one unit nearer the sill: none")


func _stroke_span(wall: int, axis: int) -> Vector2i:
	"""The wall row's stroke above the stance plane (its WORK_STROKE boxes reaching above the floor) along
	`axis`, relative to its root: what `underground_work_face.gd` requires inside the struck cube alone."""
	var p: Profiles = _profiles()
	var box: Profiles.Box = Profiles.Box.new()
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	p.descriptor_into(wall, WayFoot.CLAW_CONTENT, d)
	var out: Vector2i = Vector2i(1 << 20, -(1 << 20))
	for ordinal: int in d.box_count:
		p.box_into(wall, d.profile_revision, WayFoot.CLAW_CONTENT, ordinal, box)
		if box.role != Profiles.WORK_STROKE or box.high.y <= 0: continue
		out = Vector2i(mini(out.x, box.low[axis]), maxi(out.y, box.high[axis]))
	return out


func test_no_front_station_at_m5s_foot_both_strikes_one_cube_and_is_turned_into() -> void:
	"""BLOCKER (decision 2054 §2): a front station strikes one cube only when it stands across its heading where the
	stroke lies inside the cell, and is reached on its heading only from a corner on its own line where the all-yaw
	ground row can turn. In the 2-cell, RUN_OUT-long run-out those two ranges never meet, for the end wall (67, across
	x) or either side wall (68 and 70, across z): no painted level-1 room can be admitted at M5's foot today."""
	var cases: Array = [[WayFoot.WALL_ROWS[0], 0, [-Flight.HALF_WIDTH, 0], TURN_X],
		[WayFoot.WALL_ROWS[1], 2, [0, Flight.QUANTUM], TURN_Z], [WayFoot.WALL_ROWS[2], 2, [0, Flight.QUANTUM], TURN_Z]]
	for case: Array in cases:
		var stroke: Vector2i = _stroke_span(case[0], case[1])
		assert_true(stroke.y - stroke.x <= Flight.QUANTUM, "row %d's stroke fits one cube" % case[0])
		for cell: int in case[2]:
			var fits: Vector2i = Vector2i(cell - stroke.x, cell + Flight.QUANTUM - stroke.y)
			var turn: Vector2i = case[3]
			assert_true(fits.x <= fits.y, "row %d: stations in cell %d strike it alone from %s" % [case[0], cell, fits])
			assert_true(fits.y < turn.x or fits.x > turn.y,
				"row %d, cell %d: no station on a turnable line (%s against %s)" % [case[0], cell, fits, turn])


func test_the_bounds_are_tight_where_the_layout_needs_them() -> void:
	"""Why the hub exists, and the margins: the all-yaw ground row cannot stand on F' (its turn meets the sill); F''s
	surveyed air (M5's, the claw endpoint certificate's: row 43's body, the 2054 probe) holds neither carry row nor a
	walk across the flight, so no loaded or sideways span can leave F' (decision 2054 §2); the stand 64 u nearer
	either wall meets it."""
	assert_true(_blocked(WayFoot.GROUND_ROW, WayFoot.STAIR).contains("sill"), "no turn on F'")
	for row: int in [32, 37, 44, 46]:
		assert_false(_within(row, 43), "row %d's body does not fit F''s surveyed air (row 43's body)" % row)
	assert_true(_within(47, 43), "the retreat down the flight does")
	assert_true(_blocked(32, STAND + Vector2i(0, -64)).contains("end wall"), "the stand 64 u nearer the end wall")
	assert_true(_blocked(32, STAND + Vector2i(-64, 0)).contains("side wall"), "the stand 64 u west")


func test_the_foot_is_refused_before_the_flight_is_done() -> void:
	"""No entry, or an entry still being built: WAY_FOOT_NOT_DONE, and the host binds nothing."""
	var foot: WayIn.Foot = WayIn.Foot.new()
	var o: RefCounted = _host.underground_session()._retirement_owners
	assert_equal(WayFoot.derive_into(null, o.locations, 12, foot), WayFoot.REFUSE_NOT_DONE, "no entry")
	assert_equal(_host._bind_finished_way_in(), Confirm.REFUSE_SCOPE, "the host: nothing to bind")
	assert_equal(Chain.begin_entry(_host), &"", "the entry begun")
	assert_equal(WayFoot.derive_into(_host.underground_entry(), o.locations, 12, foot), WayFoot.REFUSE_NOT_DONE,
		"being built")
	assert_equal(_host._bind_finished_way_in(), WayFoot.REFUSE_NOT_DONE, "the host binds nothing yet")
	assert_false(_host._underground_way_in is WayIn.StairWayIn, "the base seam")
	assert_false(_host.resume_underground_room(Vector2i(0, 1)), "no way in to resume through")
	assert_equal(_host.last_refusal(), Confirm.REFUSE_NO_WAY_IN, "named")


func test_the_hosts_readers_follow_the_confirmed_entry() -> void:
	"""P-D1-7 (a): nothing before the entry is confirmed; once it is (being built), level 1's landing is D1's Stair-head
	landing at the derived anchor, the surface holds its shape, and no other level has either."""
	assert_equal(_host.underground_way_landings(1), PackedInt32Array(), "no entry: no landing")
	assert_equal(_host.underground_way_shapes(0), PackedInt32Array(), "no entry: no shape")
	assert_equal(Chain.begin_entry(_host), &"", "the entry begun")
	var origin: Vector3i = _host.underground_entry().origin()
	var datum: Vector3i = _host.underground_session()._retirement_owners.sites._domain.datum_u
	var anchor: Vector2i = WayFoot.Landings.anchor_of(WayFoot.LAYOUT, origin, datum)
	assert_equal(_host.underground_way_landings(1), Families.landing_cells(Families.EARTH_TIMBER, 0, anchor),
		"D1's landing")
	assert_equal(_host.underground_way_shapes(0), PackedInt32Array([anchor.x, anchor.y, Connectors.EARTH_TIMBER, 0]),
		"the Stair-head on the surface")
	for level: int in [0, 2]:
		assert_equal(_host.underground_way_landings(level), PackedInt32Array(), "no landing on level %d" % level)
	assert_equal(_host.underground_way_shapes(1), PackedInt32Array(), "no shape below the surface")
