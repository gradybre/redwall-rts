extends "res://test/framework/test_case.gd"
## Decision 2054 (slice D2 phase 2): the host's side of the way in, on a generated settlement with its entry begun.
## The way in is a test double of the real `StairWayIn` here (the finished flight's foot is the live suites'): the host
## settles every confirm and every Resume, retires released rooms' fronts on the fixed tick, checks a loaded record's
## contacts against the way in's access, and names a busy session instead of failing on it.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const WayIn := preload("res://scripts/core/underground_way_in.gd")
const Front := preload("res://scripts/core/underground_way_in_front.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _host: Node = null


class Recording extends WayIn.StairWayIn:
	## The real way in's bookkeeping with a scripted approach: what the host asked, and its answers.
	var approach_code: StringName = Confirm.REFUSE_NO_WAY_IN
	var order_code: StringName = &""
	var settled: Array = []

	func approach_into(_request: Approach.Request, _order: Composer.Order) -> StringName:
		"""The scripted answer."""
		return approach_code

	func order_into(room: Vector2i, order: Composer.Order) -> StringName:
		"""The scripted answer; on success an order the composer refuses (no Sites)."""
		order.room = room
		return order_code

	func settle(admitted: bool, room: Vector2i = NULL_REF) -> StringName:
		"""Recorded, then the real bookkeeping."""
		settled.append([admitted, room])
		return super.settle(admitted, room)


func before_each() -> void:
	"""A generated settlement, mounted, composed, its entry begun."""
	_host = Settlement.new()
	assert_equal(Chain.mount_and_compose(_host, Chain.load_content()), &"", "composed")
	assert_equal(Chain.begin_entry(_host), &"", "the entry begun")


func after_each() -> void:
	"""Free the host; hand the autoload back."""
	if _host != null: _host.free()
	_host = null
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _h_endpoint() -> Vector2i:
	"""The entry work area's H, standing in for a foot's access."""
	return _host.underground_entry()._published.endpoints[0]


func _bound() -> Recording:
	"""A recording way in over a fixture foot at H, bound to the host."""
	var way: Recording = Recording.new()
	var foot: WayIn.Foot = WayIn.Foot.new()
	foot.level = 1; foot.access = _h_endpoint(); foot.travel = 49; foot.ground = 42; foot.content = 12
	foot.wall_rows = PackedInt32Array([67]); foot.forward_rows = PackedInt32Array([43])
	foot.backward_rows = PackedInt32Array([47]); foot.store_point = Vector3i(1, 0, 0)
	assert_equal(way.configure(_host.underground_rooms().bound_owners(), foot), &"", "configured")
	assert_true(_host.bind_underground_way_in(way), "bound")
	return way


func _painted() -> Confirm.Painted:
	"""A 2 x 2 Kitchen on level 1."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1; painted.room_type = Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(0, -4608, 0)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = 4096
	return painted


func test_every_confirm_is_settled_with_its_answer() -> void:
	"""2053 review H2: the host settles after each confirm, refused before admission included (nothing admitted)."""
	var way: Recording = _bound()
	var result: Confirm.Result = _host.order_painted_room(_painted())
	assert_equal(result.code, Confirm.REFUSE_NO_WAY_IN, "the way in's refusal")
	assert_equal(way.settled, [[false, NULL_REF]], "settled once, not admitted")
	way.approach_code = Front.REFUSE_NO_FRONT
	assert_equal(_host.order_painted_room(_painted()).code, Front.REFUSE_NO_FRONT, "named")
	assert_equal(way.settled.size(), 2, "settled again")


func test_a_busy_session_is_named_not_crashed_on() -> void:
	"""Decision 2054 (the probe's finding): while an owner holds a scope (here the entry bindings' timber scope, as
	M5's finished flight leaves it) RoomOrders cannot be borrowed; the order is refused with the session's own code."""
	var way: Recording = _bound()
	var bindings: RefCounted = _host.underground_session()._retirement_owners.room_bindings
	bindings._timber_token = 1
	var result: Confirm.Result = _host.order_painted_room(_painted())
	bindings._timber_token = 0
	assert_equal(result.code, &"WORLD_RETIREMENT_BUSY", "named")
	assert_false(result.admitted, "nothing admitted")
	assert_equal(_host.last_refusal(), &"WORLD_RETIREMENT_BUSY", "the host's refusal")
	assert_equal(way.settled, [], "the way in was never asked")


func test_resume_goes_through_the_way_in_and_is_settled() -> void:
	"""P-2052-5 (a): Resume re-orders through the way in; its refusal is named and nothing is settled; an order the
	composer then refuses is settled as not admitted."""
	var way: Recording = _bound()
	way.order_code = WayIn.REFUSE_NO_ROOM
	assert_false(_host.resume_underground_room(Vector2i(3, 1)), "refused by the way in")
	assert_equal(_host.last_refusal(), WayIn.REFUSE_NO_ROOM, "named")
	assert_equal(way.settled, [], "nothing to settle")
	way.order_code = &""
	assert_false(_host.resume_underground_room(Vector2i(3, 1)), "refused by the composer")
	assert_equal(way.settled, [[false, Vector2i(3, 1)]], "settled, not ordered")


func test_a_released_rooms_front_is_retired_on_the_fixed_tick() -> void:
	"""2053 §3: the host offers the kept fronts for retirement after the rooms' tick; a room with no record is
	released, so its front's station leaves Locations."""
	var way: Recording = _bound()
	var owners: RefCounted = _host.underground_rooms().bound_owners()
	var access: Locations.Record = Front.record()
	var m: Vector2i = _host.underground_entry()._published.endpoints[1]
	assert_equal(owners.locations.read_location_into(m, access), &"", "M, with the work area's storage air")
	var made: PackedInt32Array = PackedInt32Array()
	var station: Vector2i = Front.endpoint_at(owners, way.foot, access, access.point + Vector3i(1024, 0, 0),
		Locations.ROLE_TRANSIT, PackedInt32Array([42]), made)
	assert_true(station != NULL_REF, "a stand-in station published")
	way._keep(Vector2i(5, 1), station, _h_endpoint())
	assert_true(_host.run_tick(1), "a tick")
	assert_false(owners.locations._live_ref(owners.locations._live, station), "retired on the tick")
	assert_equal(way.fronts(), PackedInt32Array(), "nothing kept")
	assert_true(owners.locations._live_ref(owners.locations._live, _h_endpoint()), "the access stays")


func test_a_loaded_rooms_contacts_must_be_the_way_ins_access() -> void:
	"""2052 §2.1: after the rooms' record the contacts' access must be the way in's (`ROOM_DIG_OTHER_ACCESS`
	otherwise); with no contacts bound there is nothing to check."""
	var way: Recording = _bound()
	var rooms: RefCounted = _host.underground_rooms()
	assert_equal(_host._recall_way_in(), &"", "no contacts yet")
	rooms.note_contacts(_h_endpoint(), 49)
	assert_equal(_host._recall_way_in(), &"", "the same access")
	rooms.note_contacts(_host.underground_entry()._published.endpoints[1], 49)
	assert_equal(_host._recall_way_in(), Composer.REFUSE_OTHER_ACCESS, "another access")
	rooms.note_contacts(NULL_REF, -1)
	assert_true(way.fronts().is_empty(), "nothing recalled")
