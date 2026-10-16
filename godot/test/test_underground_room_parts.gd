extends "res://test/framework/test_case.gd"
## Decision 1937: the room dig's small parts on the Kitchen fixture, each checked exactly (the mutation pass found
## them covered only end to end): the timed walk, the cube plan's sweep and bounds, the parking candidate checks, the
## composite's identity, and the runtime's ownership, capacity and save preconditions.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Walk := preload("res://scripts/core/underground_room_walk.gd")
const Claim := preload("res://scripts/core/underground_room_claim.gd")
const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const Parking := preload("res://scripts/core/underground_room_parking.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Dispatch := preload("res://scripts/core/underground_dispatch.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TRAVEL_ROW: int = 5
const BACK_ROW: int = 9
const WORK_ROW: int = 27

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF
var _runtime: Runtime = null


func before_each() -> void:
	"""One confirmed Kitchen and a runtime over its owners."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")


func after_each() -> void:
	"""Free the fixture, propagating its assertions."""
	_runtime = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _point(location: Vector2i) -> Vector3i:
	"""A fixture endpoint's integer point."""
	return Claim.point_of(_h.endpoints, location)


func test_a_walk_takes_exactly_its_ticks() -> void:
	"""ADR1219's rule: ceil_div(D × 30, v) ticks at the resident's ground speed, arriving on the last one; a walk of
	no length takes none."""
	if _room == NULL_REF: return
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	var walk: Walk = Walk.new()
	var from: Vector3i = Vector3i(0, 0, 0)
	var to: Vector3i = Vector3i(3000, 0, 4000)
	assert_equal(walk.begin(_h._residents, row, from, to, true), &"", "begun")
	var speed: IntMath.IntResult = _h._residents.size_movement_u_per_s(_h._residents.size_class_of(row).value)
	var expected: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(HaulPlanner.travel_ticks_into(EntryRuntime.ceil_length(to - from), speed.value, expected), "rule")
	assert_true(expected.value > 1, "more than one tick")
	assert_equal(walk.ticks_left, expected.value, "ticks")
	assert_true(walk.leaving, "out")
	for tick: int in expected.value - 1:
		assert_false(walk.step(), "under way at %d" % tick)
	assert_true(walk.step(), "arrives on the last tick")
	assert_false(walk.walking() or walk.step(), "and is done")
	assert_equal(walk.begin(_h._residents, row, from, from, false), &"", "nowhere to go")
	assert_false(walk.walking() or walk.leaving, "no walk, inward")
	assert_equal(walk.begin(_h._residents, -1, from, to, false), Walk.REFUSE_WALK, "no resident, no speed")


func test_a_cube_plan_sweeps_its_legs_station_stands_and_storage_walk_in_order() -> void:
	"""The footprint is the plan's own sweep: each leg from the previous one's end, the station's work, the way there
	from the storage, each carried item's lift (+2) and set-down (+4) rows at the stands, and the walk to the
	storage; the plan's bounds are the save's."""
	if _room == NULL_REF: return
	var plan: Claim = Claim.new()
	var station: Vector2i = _h._first
	plan.home_legs = PackedInt32Array([_h._last.x, _h._last.y, _h.parking.x, _h.parking.y])
	plan.home_profiles = PackedInt32Array([BACK_ROW, TRAVEL_ROW])
	plan.approach_legs = PackedInt32Array([_h._first.x, _h._first.y]); plan.approach_profiles = PackedInt32Array([TRAVEL_ROW])
	plan.store_legs = PackedInt32Array([_h.parking.x, _h.parking.y]); plan.store_profiles = PackedInt32Array([BACK_ROW])
	plan.start = _h._last; plan.store = _h.parking
	plan.stands = PackedInt32Array([_h._first.x, _h._first.y, _h._last.x, _h._last.y])
	plan.carries = PackedInt32Array([TRAVEL_ROW])
	var actual: Footprint = Footprint.new(); actual.configure(_h._profiles)
	plan.sweep_into(actual, _h.endpoints, _h._routes, station, WORK_ROW)
	var expected: Footprint = Footprint.new(); expected.configure(_h._profiles)
	expected.sweep(_point(station), _point(_h._last), BACK_ROW)
	expected.sweep(_point(_h._last), _point(_h.parking), TRAVEL_ROW)
	expected.sweep(_point(station), _point(station), WORK_ROW)
	expected.sweep(_point(_h.parking), _point(_h._first), TRAVEL_ROW)
	expected.sweep(_point(_h._first), _point(_h._first), TRAVEL_ROW + 2)
	expected.sweep(_point(_h._last), _point(_h._last), TRAVEL_ROW + 4)
	expected.sweep(_point(_h._last), _point(_h.parking), BACK_ROW)
	assert_true(actual.claim() == expected.claim(), "the same boxes, in the same order")
	assert_true(plan.hauls() and plan.bounded(), "a haul within the bounds")
	plan.trips.resize(3 * Claim.MAX_TRIP_EDGES)
	assert_true(plan.bounded(), "the last trip edge the save holds")
	plan.trips.resize(3 * Claim.MAX_TRIP_EDGES + 3)
	assert_false(plan.bounded(), "one more is refused")
	plan.clear()
	assert_false(plan.hauls() or plan.start != NULL_REF, "cleared")


func _request() -> Parking.Request:
	"""The composer's parking request for the Kitchen from the fixture's access."""
	var ctx: Builder.Context = Foreman._context(_runtime.bound_owners(), _h.material, _h.material)
	var ask: Parking.Request = Parking.Request.new()
	ask.access = _h._first; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = Composer._room_box(_h.sites, _room)
	return ask


func test_a_parking_candidate_must_be_in_the_access_air_off_the_room_and_free() -> void:
	"""A body outside the access's air or over the room's cells is not clear; a WORK station's point is neither
	reused nor shared; the existing TRANSIT parking is reused."""
	if _room == NULL_REF: return
	var ask: Parking.Request = _request()
	var access: Locations.Record = Parking._record()
	assert_equal(_h.endpoints.read_location_into(_h._first, access), &"", "the access")
	assert_true(Parking._clear(_h._profiles, ask, access, _point(_h.parking)), "the parking is clear")
	var inside: Vector3i = Vector3i((ask.room_box[0] + ask.room_box[2]) >> 1, _point(_h.parking).y,
		(ask.room_box[1] + ask.room_box[3]) >> 1)
	assert_false(Parking._clear(_h._profiles, ask, access, inside), "not over the room's cells")
	assert_false(Parking._clear(_h._profiles, ask, access, _point(_h.parking) + Vector3i(0, 0, 1 << 20)), "not out of the air")
	var over: Parking.Request = _request()
	var at: Vector3i = _point(_h.parking)
	over.room_box = PackedInt32Array([at.x - 8, at.z - 8, at.x + 8, at.z + 8]) # A room reaching over that air.
	assert_false(Parking._clear(_h._profiles, over, access, at), "not where a room's cells lie, even in the air")
	assert_equal(Parking._existing(_h.endpoints, access, _point(_h.parking)), _h.parking, "TRANSIT reused")
	assert_equal(Parking._existing(_h.endpoints, access, _point(_h._last)), NULL_REF, "a WORK station is not")
	assert_true(Parking._occupied(_h.endpoints, _point(_h._last)), "its point is taken")
	assert_equal(Parking._parking_at(_runtime.bound_owners(), ask, access, _point(_h._last)), NULL_REF,
		"and no endpoint is published over it")


func test_the_composite_is_known_only_by_its_own_script() -> void:
	"""`bound_to` is true for this script's composite only: not for unbound Jobs, nor for a runtime's own answers."""
	if _room == NULL_REF: return
	assert_false(Dispatch.bound_to(_h._jobs), "unbound")
	assert_false(Dispatch.bound_to(null), "no Jobs")
	assert_true(_h._jobs.bind_dispatcher(_runtime.owns_job, _runtime.reserves_resident).ok, "the runtime itself")
	assert_false(Dispatch.bound_to(_h._jobs), "is not the composite")
	_h._jobs.clear_dispatcher()


func test_the_runtime_owns_only_excavation_jobs() -> void:
	"""A dig's phase Job is owned because its Project's purpose is EXCAVATION; the same Job under another purpose is
	not (negative-only: the Project's purpose column is flipped and put back)."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _runtime.bound_owners(), [_h.crew_member()] as Array[Builder.Crew]), &"", "started")
	var builder: Builder = _runtime.foreman_of(_room).builders()[0]
	for tick: int in 4000:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if builder._job >= 0: break
	assert_true(_runtime.owns_job(builder._job), "the phase Job is owned")
	var project: Vector2i = _h._jobs.requester_of(builder._job)
	var row: int = _h._residents.directory().get_typed_row(project)
	_h._construction._purpose[row] = Construction.PURPOSE_BUILD
	assert_false(_runtime.owns_job(builder._job), "not under another purpose")
	_h._construction._purpose[row] = Construction.PURPOSE_EXCAVATION
	assert_false(Runtime.new(_h._residents.directory()).owns_job(builder._job), "a runtime with no owners owns nothing")


func test_kept_records_are_bounded_and_a_kept_runtime_is_not_a_restore_target() -> void:
	"""MAX_KEPT records at most; noted contacts alone make the runtime non-empty; only an empty runtime restores."""
	if _room == NULL_REF: return
	for index: int in Runtime.MAX_KEPT:
		var room: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
		assert_equal(_runtime.order_room(room, _h.material, _h.material), &"", "kept %d" % index)
	assert_equal(_runtime.kept(), Runtime.MAX_KEPT, "full")
	var over: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(_runtime.order_room(over, _h.material, _h.material), Runtime.REFUSE_CAPACITY, "one more refused")
	var record: PackedByteArray = PackedByteArray()
	assert_equal(_runtime.capture(record), &"", "captured")
	assert_equal(_runtime.restore(record), Progress.REFUSE_TARGET, "not into a runtime that keeps records")
	var noted: Runtime = Runtime.new(_h._residents.directory())
	assert_true(noted.bind_owners(_h.owners()), "owners")
	assert_true(noted.is_empty(), "empty")
	noted.note_contacts(_h._first, _h.provider._ordinary_travel)
	assert_false(noted.is_empty(), "noted contacts are state to save")
	assert_equal(noted.restore(record), Progress.REFUSE_TARGET, "and not a restore target")


func test_a_stopped_builder_waiting_to_leave_is_named_once_at_the_stall_bound() -> void:
	"""Review M1: waiting to leave from rest is counted; the stall bound names it once and the wait goes on."""
	var builder: Builder = Builder.new()
	for tick: int in Builder.STAGE_TICK_LIMIT - 1:
		assert_equal(builder._wait_out(), &"", "waiting %d" % tick)
	assert_equal(builder._wait_out(), Builder.REFUSE_STUCK, "named at the bound")
	assert_equal(builder._wait_out(), &"", "once")


func test_a_dig_heals_a_stale_routes_occupancy_while_its_crew_walks_out() -> void:
	"""Review M-a: a foreign pose change (here a resident placed on the surface) leaves Routes' occupancy stale, and
	stale Routes moves nobody. While a kept dig's crew is still walking out (no actor edit refreshes it), the runtime
	refreshes it on its next tick."""
	if _room == NULL_REF: return
	var crew: Array[Builder.Crew] = [_h.crew_member()]
	assert_true(_h._transforms.place(_h._worker, 60000, 512, 60000, 0), "far off on the surface")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _runtime.bound_owners(), crew), &"", "started")
	var builder: Builder = _runtime.foreman_of(_room).builders()[0]
	for tick: int in 4000:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if not builder.walking(): break
	_runtime.foreman_of(_room)._halt(&"TEST_STOP") # Negative-only: the dig stops with its builder parked.
	_h.tick += 1
	_runtime.advance(_h.tick)
	assert_true(builder.walking() and builder._walk.leaving, "walking back out")
	var other: Vector2i = _h._residents.ref_of(_h._residents.spawn(&"mole").value)
	assert_true(_h._transforms.place(other, 90000, 512, 90000, 0), "a foreign pose change")
	assert_false(_h._routes._occupancy_context_refusal() == &"", "stale")
	_h.tick += 1
	_runtime.advance(_h.tick)
	assert_true(builder.walking(), "still walking out")
	assert_equal(_h._routes._occupancy_context_refusal(), &"", "healed by the runtime")


func test_builders_share_one_row_extent_table_and_a_record_is_checked_in_place() -> void:
	"""P-1937-1 B: a bound runtime gives every builder one row-extent table; C: a capture writes into the caller's
	buffer and a restore's re-encode is compared against the record itself, so a single changed byte is caught."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _runtime.bound_owners(), [_h.crew_member()] as Array[Builder.Crew]), &"", "started")
	var builder: Builder = _runtime.foreman_of(_room).builders()[0]
	assert_not_null(_runtime.bound_owners().extents, "the runtime's table")
	assert_true(builder._foot._rows == _runtime.bound_owners().extents, "shared by its builders")
	var own: Footprint = Footprint.new(); own.configure(_h._profiles)
	assert_false(own._rows == _runtime.bound_owners().extents, "a footprint given none keeps its own")
	for tick: int in 50:
		_h.tick += 1
		_runtime.advance(_h.tick)
	var out: PackedByteArray = PackedByteArray([1, 2, 3])
	assert_equal(_runtime.capture(out), &"", "captured")
	assert_equal(out.decode_s32(0), Progress.MAGIC, "into the caller's buffer, from its start")
	var check: Progress.Checker = Progress.check(out)
	_runtime._write_state(check)
	assert_true(check.matches(), "the re-encode matches the record in place")
	var changed: PackedByteArray = out.duplicate()
	changed[changed.size() - 1] = changed[changed.size() - 1] ^ 1
	var differ: Progress.Checker = Progress.check(changed)
	_runtime._write_state(differ)
	assert_false(differ.matches(), "one changed byte is caught")
	var longer: Progress.Checker = Progress.check(out + PackedByteArray([0]))
	_runtime._write_state(longer)
	assert_false(longer.matches(), "a record with bytes left over is caught")


func test_the_record_pool_saves_in_room_row_order_and_refuses_a_row_kept_twice() -> void:
	"""P-1937-1 D: whichever slots the records hold, the record lists them in room row order (canonical); a record
	naming one room row twice is refused, even when both copies are the same."""
	if _room == NULL_REF: return
	var first: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	var second: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	var low: int = _h._residents.directory().get_typed_row(first)
	var high: int = _h._residents.directory().get_typed_row(second)
	assert_true(high > low, "the second room has the higher row")
	assert_equal(_runtime.order_room(second, _h.material, _h.material), &"", "the higher row takes slot 0")
	assert_equal(_runtime.order_room(first, _h.material, _h.material), &"", "the lower row slot 1")
	assert_equal(_runtime._slot(high), 0, "slot 0")
	var record: PackedByteArray = PackedByteArray()
	assert_equal(_runtime.capture(record), &"", "captured")
	var rows_at: int = Progress.HEADER_BYTES + 16
	assert_equal(record.decode_s32(rows_at), low, "the lower row first")
	assert_equal(record.decode_s32(rows_at + Progress.ROW_BYTES), high, "then the higher")
	var twice: PackedByteArray = record.slice(0, rows_at - 4)
	twice.resize(twice.size() + 4); twice.encode_s32(rows_at - 4, 3)
	var block: PackedByteArray = record.slice(rows_at, rows_at + Progress.ROW_BYTES)
	twice += block + record.slice(rows_at)
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(_h.owners()), "owners")
	assert_equal(fresh.restore(twice), Progress.REFUSE_SHAPE, "one row kept twice is refused")
	assert_true(fresh.is_empty(), "and leaves it empty")
	assert_equal(fresh.restore(record), &"", "the canonical record restores")
	assert_equal(fresh.state_of(first), Runtime.RECORD_QUEUED, "both rooms queued again")
	assert_equal(fresh.state_of(second), Runtime.RECORD_QUEUED, "in their own slots")


func test_a_shared_row_extent_table_is_reset_for_other_content() -> void:
	"""P-1937-1 B: the shared table is kept while the Profiles content is the same, and reset (every row unfilled)
	when a footprint is configured for other content, even of the same size."""
	if _room == NULL_REF: return
	var rows: Footprint.RowExtents = Footprint.RowExtents.new()
	rows.fit(_h._profiles)
	assert_equal(rows.revision, _h._profiles.content_revision(), "sized for this content")
	rows.table[0] = 7 # A filled entry.
	rows.fit(_h._profiles)
	assert_equal(rows.table[0], 7, "kept for the same content")
	rows.revision = -5 # Negative-only: the table was filled for other content of the same size.
	var foot: Footprint = Footprint.new()
	foot.configure(_h._profiles, rows)
	assert_true(foot._rows == rows, "the shared table")
	assert_equal(rows.table[0], Footprint.UNFILLED, "reset for this content")
	assert_equal(rows.revision, _h._profiles.content_revision(), "and marked")
