extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1), P-C2-4 (a): the room-dig runtime's packed record per room, and its place on the settlement's
## fixed tick (after the first entry). The digs run on the ADR1161 Kitchen fixture (retired content-6 pick rows,
## tests only).

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 20000

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF
var _runtime: Runtime = null
var _settlement: Node = null


func before_each() -> void:
	"""One confirmed Kitchen and a runtime over its directory."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()
	_runtime = Runtime.new(_h._residents.directory())


func after_each() -> void:
	"""Free the settlement node and every fixture owner."""
	if _settlement != null:
		_settlement.free()
	_settlement = null
	_runtime = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _crew() -> Array[Builder.Crew]:
	"""The fixture's one mole."""
	var crew: Array[Builder.Crew] = [_h.crew_member()]
	return crew


func test_the_record_is_one_small_row_per_room() -> void:
	"""Generation, state and three container references (decision 1934 added staging): 29 bytes per room row."""
	assert_equal(Runtime.RECORD_BYTES, 29, "4 + 1 + 8 + 8 + 8")
	assert_equal(Runtime.packed_bytes(), Runtime.ROOM_CAPACITY * 29, "one row per possible room")
	assert_equal(Runtime.packed_bytes(), 475136, "the ledger figure")
	assert_equal(Runtime.ROOM_CAPACITY, Directory.KIND_CAPACITY[Directory.KIND_ROOM], "the directory's room rows")


func test_ordering_validates_the_room_and_its_containers() -> void:
	"""A live room of kind ROOM with both containers is queued once; anything else is refused."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(NULL_REF, _h.material, _h.material), Runtime.REFUSE_ROOM, "null room")
	assert_equal(_runtime.order_room(Vector2i(_room.x, _room.y + 1), _h.material, _h.material), Runtime.REFUSE_ROOM, "stale room")
	assert_equal(_runtime.order_room(_h._worker, _h.material, _h.material), Runtime.REFUSE_ROOM, "not a room")
	assert_equal(_runtime.order_room(_room, NULL_REF, _h.material), Runtime.REFUSE_ROOM, "no storage")
	assert_equal(_runtime.order_room(_room, _h.material, NULL_REF), Runtime.REFUSE_ROOM, "no spoil container")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "nothing queued yet")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "queued")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), Runtime.REFUSE_STATE, "only once")
	assert_equal(_runtime.state_of(Vector2i(_room.x, _room.y + 1)), Runtime.RECORD_NONE, "stale reads nothing")
	assert_false(_runtime.is_running(), "queued is not digging")


func test_the_record_keeps_the_staging_container_for_the_foreman() -> void:
	"""Decision 1934: the staging container missing inputs are hauled from is kept in the record (null when none
	is named) and handed to the foreman's builders when the dig starts."""
	if _room == NULL_REF: return
	var row: int = _h._residents.directory().get_typed_row(_room)
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued without one")
	assert_equal(Vector2i(_runtime._staging[2 * row], _runtime._staging[2 * row + 1]), NULL_REF, "none named")
	_runtime._state[row] = Runtime.RECORD_STOPPED # Negative-only: re-order the same room.
	assert_equal(_runtime.release_room(_room), &"", "released")
	var pile: Vector2i = _h._inventory.create_spatial_ground_staging(_h.parking).ref
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, pile), &"", "queued with one")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	assert_equal(_runtime.foreman_of(_room)._ctx.staging, pile, "handed to the builders")


func test_starting_needs_a_queued_room_and_a_plan() -> void:
	"""Unqueued and stale rooms are refused; a refused plan leaves the room queued; capacity is bounded."""
	if _room == NULL_REF: return
	var owners: Builder.Owners = _h.owners()
	assert_equal(_runtime.start_room(_room, owners, _crew()), Runtime.REFUSE_STATE, "not queued")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(Vector2i(_room.x, _room.y + 1), owners, _crew()), Runtime.REFUSE_ROOM, "stale")
	var none: Array[Builder.Crew] = []
	assert_equal(_runtime.start_room(_room, owners, none), Foreman.REFUSE_CREW, "a refused plan")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "still queued")
	assert_null(_runtime.foreman_of(_room), "no foreman kept")
	for index: int in Runtime.MAX_DIGS + 1:
		_runtime._foremen.append(Foreman.new()); _runtime._foreman_rows.append(Runtime.ROOM_CAPACITY - 1)
	assert_equal(_runtime.start_room(_room, owners, _crew()), &"", "stopped or unconfigured foremen do not count")
	for index: int in Runtime.MAX_DIGS + 1: _runtime._foremen[index]._state = Foreman.STATE_DIGGING # Negative-only.
	var other: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(_runtime.order_room(other, _h.material, _h.material), &"", "a second room queued")
	assert_equal(_runtime.start_room(other, owners, _crew()), Runtime.REFUSE_CAPACITY, "at most MAX_DIGS running digs")


func test_the_settlement_tick_digs_an_adopted_room_to_done() -> void:
	"""SettlementSystem advances the adopted runtime once per fixed tick, after the entry; the record is DONE while its crew walks out, then releases itself."""
	if _room == NULL_REF: return
	_settlement = SettlementSystemScript.new()
	assert_null(_settlement.underground_rooms(), "none until adopted")
	assert_false(_settlement.adopt_underground_rooms(null), "null refused")
	assert_true(_settlement.adopt_underground_rooms(_runtime), "adopted")
	assert_false(_settlement.adopt_underground_rooms(Runtime.new(_h._residents.directory())), "only one")
	assert_equal(_settlement.underground_rooms(), _runtime, "borrowed back")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_DIGGING, "digging")
	assert_true(_runtime.is_running(), "running")
	var foreman: Foreman = _runtime.foreman_of(_room)
	var done_seen: bool = false
	for step: int in TICK_BOUND:
		_h.tick += 1
		_settlement.run_tick(_h.tick)
		done_seen = done_seen or _runtime.state_of(_room) == Runtime.RECORD_DONE
		if not _runtime.is_running(): break
	assert_true(done_seen, "DONE while its crew walked out")
	assert_equal(foreman.done_cubes(), ForemanTests.KITCHEN_SITES, "every cube, by Sites' record")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "released by itself once out (review M-b)")
	assert_null(_runtime.foreman_of(_room), "foreman dropped")
	assert_equal(_runtime.kept(), 0, "nothing kept")
	assert_equal(_runtime.release_room(_room), Runtime.REFUSE_STATE, "nothing left to release")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "orderable again")


func test_a_stopped_room_keeps_its_refusal_and_cannot_be_released_while_digging() -> void:
	"""A full spoil pile stops the dig: the record is STOPPED, the foreman keeps the code, release clears it."""
	if _room == NULL_REF: return
	var pile: Vector2i = _h._inventory.create_spatial_ground_staging(_h.parking).ref
	assert_true(_h._inventory.create_lot(pile, _h._items.compiled_id(&"excavated_earth"),
		_h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0).ok, "a nearly full pile")
	assert_equal(_runtime.order_room(_room, _h.material, pile), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	assert_equal(_runtime.release_room(_room), Runtime.REFUSE_STATE, "not while digging")
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(_runtime.advance(_h.tick))
		if not _runtime.is_running(): break
	assert_equal(seen, [Inventory.REFUSE_CAPACITY_EXCEEDED], "the refusal is returned once for the alert")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_STOPPED, "stopped")
	assert_equal(_runtime.foreman_of(_room).error(), Inventory.REFUSE_CAPACITY_EXCEEDED, "kept")
	assert_equal(_runtime.advance(_h.tick + 1), [] as Array[StringName], "a stopped room is not advanced again")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), Runtime.REFUSE_STATE, "release before re-ordering")
	assert_equal(_runtime.release_room(Vector2i(_room.x, _room.y + 1)), Runtime.REFUSE_ROOM, "stale release")
	assert_equal(_runtime.release_room(_room), &"", "released")
	assert_equal(_runtime.release_room(_room), Runtime.REFUSE_STATE, "nothing left to release")


func test_a_runtime_without_a_matching_directory_refuses_everything() -> void:
	"""A null directory leaves every room unknown."""
	if _room == NULL_REF: return
	var orphan: Runtime = Runtime.new(null)
	assert_equal(orphan.order_room(_room, _h.material, _h.material), Runtime.REFUSE_ROOM, "no directory")
	assert_equal(orphan.state_of(_room), Runtime.RECORD_NONE, "unknown")
	assert_false(orphan.is_running(), "nothing runs")
	assert_equal(orphan.advance(1).size(), 0, "nothing to advance")


func test_a_crew_member_digs_one_room_at_a_time() -> void:
	"""A mole already building a running dig cannot be put on another room's crew."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "digging")
	var other: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(_runtime.order_room(other, _h.material, _h.material), &"", "a second room queued")
	assert_equal(_runtime.start_room(other, _h.owners(), _crew()), Runtime.REFUSE_CREW_BUSY, "the same mole is busy")
	assert_equal(_runtime.state_of(other), Runtime.RECORD_QUEUED, "still queued")


func test_a_record_left_by_a_deleted_room_does_not_start_the_new_room_on_its_row() -> void:
	"""A room deleted while queued leaves its record; a new room given the same row cannot start on it, and ordering
	the new room replaces the old record."""
	if _room == NULL_REF: return
	var ids: Directory = _h._residents.directory()
	var old: Vector2i = ids.create(Directory.KIND_ROOM)
	assert_equal(_runtime.order_room(old, _h.material, _h.material), &"", "queued")
	var row: int = ids.get_typed_row(old)
	assert_true(ids.destroy(old), "the room is deleted")
	var fresh: Vector2i = ids.create(Directory.KIND_ROOM)
	assert_equal(ids.get_typed_row(fresh), row, "the row is reused")
	assert_equal(_runtime.state_of(fresh), Runtime.RECORD_NONE, "the old record is not the new room's")
	assert_equal(_runtime.start_room(fresh, _h.owners(), _crew()), Runtime.REFUSE_ROOM, "not started on the old record")
	assert_equal(_runtime.order_room(fresh, _h.material, _h.material), &"", "ordering replaces the old record")
	assert_equal(_runtime.state_of(fresh), Runtime.RECORD_QUEUED, "queued")


func test_a_reused_row_waits_for_the_stopped_crew_to_walk_out() -> void:
	"""Decision 1937: a room deleted while its stopped crew is still underground leaves its row's foreman walking the
	crew out; a new room on the same directory row is refused until it has (ROOM_DIG_CREW_OUT), so no builder is
	dropped underground still reserved by nobody."""
	if _room == NULL_REF: return
	var pile: Vector2i = _h._inventory.create_spatial_ground_staging(_h.parking).ref
	assert_true(_h._inventory.create_lot(pile, _h._items.compiled_id(&"excavated_earth"),
		_h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0).ok, "a nearly full pile")
	assert_equal(_runtime.order_room(_room, _h.material, pile), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if _runtime.state_of(_room) == Runtime.RECORD_STOPPED: break
	assert_true(_runtime.foreman_of(_room).crew_out(), "stopped with its builder still underground")
	assert_equal(_runtime.release_room(_room), Runtime.REFUSE_CREW_OUT, "not released while the crew is out")
	assert_true(_h._residents.directory().destroy(_room), "the room deleted")
	var reused: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(reused.x, _room.x, "the same directory row, a new generation")
	assert_equal(_runtime.order_room(reused, _h.material, _h.material), Runtime.REFUSE_CREW_OUT, "refused, named")
	assert_true(_runtime.reserves_resident(_h._residents.directory().get_typed_row(_h._worker)), "still reserved")


func test_a_queued_record_no_foreman_took_can_be_cancelled() -> void:
	"""`cancel_queued` forgets only a QUEUED record of the same room."""
	if _room == NULL_REF: return
	assert_equal(_runtime.cancel_queued(_room), Runtime.REFUSE_ROOM, "never ordered")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.cancel_queued(Vector2i(_room.x, _room.y + 1)), Runtime.REFUSE_ROOM, "stale")
	assert_equal(_runtime.cancel_queued(_room), &"", "cancelled")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "forgotten")
	assert_equal(_runtime.cancel_queued(_room), Runtime.REFUSE_STATE, "nothing queued")
	assert_equal(_runtime.kept(), 0, "nothing kept")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "orderable again")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	assert_equal(_runtime.cancel_queued(_room), Runtime.REFUSE_STATE, "not while digging")


func test_a_builder_still_walking_in_when_the_dig_stops_never_arrives() -> void:
	"""Decision 1937: the walk in is cancelled at the stop (the body never left where it stood), so the builder is
	never registered, is forgotten at once and is reserved no longer."""
	if _room == NULL_REF: return
	var crew: Array[Builder.Crew] = _crew()
	var far: Vector3i = Vector3i(60000, 512, 60000)
	assert_true(_h._transforms.place(_h._worker, far.x, far.y, far.z, 0), "far off on the surface")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), crew), &"", "started")
	_h.tick += 1
	_runtime.advance(_h.tick)
	var builder: Builder = _runtime.foreman_of(_room).builders()[0]
	assert_true(builder.walking(), "walking in")
	_runtime.foreman_of(_room)._halt(&"TEST_STOP") # Negative-only: the dig stops mid-walk.
	for step: int in 3:
		_h.tick += 1
		_runtime.advance(_h.tick)
	assert_true(_runtime.foreman_of(_room).builders().is_empty(), "forgotten")
	assert_equal(_h._routes._lost_actor_row(_h._worker), -1, "never registered")
	assert_false(_runtime.reserves_resident(_h._residents.directory().get_typed_row(_h._worker)), "not reserved")
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(_h._transforms.read_into(_h._worker, pose), "its pose")
	assert_equal(Vector3i(pose.x, pose.y, pose.z), far, "still where it stood")
