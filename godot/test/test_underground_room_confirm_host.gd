extends "res://test/framework/test_case.gd"
## Decision 1991 (slice C3) in the running game: the settlement's painted Confirm route, its Stop, the seam slice D2
## fills, the start of rooms waiting for their crew on the fixed tick, and a named crew through the real settlement
## save and load (ARCH-SAVE-006's path). No level has a way in yet, so the game's own route refuses, named.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const RoomRuntime := preload("res://scripts/core/underground_room_runtime.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Residents := preload("res://scripts/core/residents.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _content: Chain.Content = null
var _nodes: Array[Node] = []


class CountingWayIn extends Confirm.WayIn:
	## A seam that answers like the base class and counts its calls (the host must ask the bound one).
	var calls: int = 0

	func approach_into(_request: Approach.Request, _order: Composer.Order) -> StringName:
		"""Refused, counted."""
		calls += 1
		return Confirm.REFUSE_NO_WAY_IN


func before_each() -> void:
	"""The production actor image."""
	_content = Chain.load_content()
	assert_true(_content != null, "the production actor image loads")


func after_each() -> void:
	"""Free every node this test made; leave the autoload as the other suites expect it."""
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _node(node: Node) -> Node:
	"""Track a node for after_each."""
	_nodes.append(node)
	return node


func _composed() -> Node:
	"""A generated settlement, mounted and composed."""
	var host: Node = _node(Settlement.new())
	assert_equal(Chain.mount_and_compose(host, _content), &"", "mounted and composed")
	return host


func _painted(crew: PackedInt32Array) -> Confirm.Painted:
	"""A 2 × 2 Kitchen painted on level 1 at the space domain's datum."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1; painted.room_type = Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(40960, -4608, 40960)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = 4096
	painted.crew = crew
	return painted


func _a_mole(host: Node) -> PackedInt32Array:
	"""The first living adult mole free of tools, named; empty when the village has none."""
	var residents: Residents = host.underground_session()._retirement_owners.residents
	for slot: int in Residents.RESIDENT_CAPACITY:
		if Composer.could_dig(residents, slot):
			var ref: Vector2i = residents.ref_of(slot)
			return PackedInt32Array([ref.x, ref.y])
	return PackedInt32Array()


func test_the_games_route_refuses_every_painted_room_until_d2_binds_a_way_in() -> void:
	"""Decision 1991: in the game no level has a way in (slice D); a painted room is refused ROOM_DIG_NO_WAY_IN, named
	and alerted, and nothing is admitted or recorded. The host asks whatever seam is bound."""
	var host: Node = _composed()
	var rooms: int = host.underground_session().room_orders().buildings_owner().live_room_count()
	var result: Confirm.Result = host.order_painted_room(_painted(PackedInt32Array()))
	assert_equal(result.code, Confirm.REFUSE_NO_WAY_IN, "refused, the Result naming it")
	assert_false(result.admitted, "not admitted")
	assert_equal(result.room, NULL_REF, "no room")
	assert_equal(host.last_refusal(), Confirm.REFUSE_NO_WAY_IN, "no way in")
	assert_equal(host.underground_session().room_orders().buildings_owner().live_room_count(), rooms, "nothing admitted")
	assert_equal(host.underground_rooms().kept(), 0, "nothing recorded")
	assert_false(host.bind_underground_way_in(null), "a null seam refused")
	var counting: CountingWayIn = CountingWayIn.new()
	assert_true(host.bind_underground_way_in(counting), "D2's seam bound")
	assert_equal(host.order_painted_room(_painted(PackedInt32Array())).code, Confirm.REFUSE_NO_WAY_IN, "its refusal")
	assert_equal(counting.calls, 1, "the bound seam was asked")


func test_a_crew_that_cannot_dig_is_refused_in_the_game_before_the_way_in() -> void:
	"""The crew is checked before the seam is asked."""
	var host: Node = _composed()
	var counting: CountingWayIn = CountingWayIn.new()
	assert_true(host.bind_underground_way_in(counting), "bound")
	assert_equal(host.order_painted_room(_painted(PackedInt32Array([999, 1]))).code, Composer.REFUSE_CREW_MEMBER,
		"refused")
	assert_equal(host.last_refusal(), Composer.REFUSE_CREW_MEMBER, "not a digger")
	assert_equal(counting.calls, 0, "the seam was not asked")


func test_the_way_in_belongs_to_the_mounted_session() -> void:
	"""Review H-3: D2's seam is bound after a mount and dropped by the reset that releases the session, so a remounted
	host refuses every painted room again until it is bound again; with nothing mounted it cannot be bound."""
	var host: Node = _composed()
	var counting: CountingWayIn = CountingWayIn.new()
	assert_true(host.bind_underground_way_in(counting), "bound")
	assert_true(host.reset(), "reset releases the session")
	assert_false(host._underground_way_in is CountingWayIn, "the old session's seam is let go at once")
	assert_false(host.bind_underground_way_in(counting), "nothing mounted: refused")
	assert_equal(Chain.mount_and_compose(host, _content), &"", "mounted again")
	assert_equal(host.order_painted_room(_painted(PackedInt32Array())).code, Confirm.REFUSE_NO_WAY_IN, "no way in")
	assert_equal(counting.calls, 0, "the old session's seam was never asked")


func test_stop_in_the_game_is_named_for_a_room_with_no_record() -> void:
	"""`stop_underground_room` on a room nothing digs is a named refusal; on a waiting one it forgets the record."""
	var host: Node = _composed()
	var room: Vector2i = host.directory().create(Directory.KIND_ROOM)
	assert_false(host.stop_underground_room(room), "nothing to stop")
	assert_equal(host.last_refusal(), RoomRuntime.REFUSE_STATE, "named")
	assert_equal(host.underground_rooms().order_room(room, Vector2i(3, 1), Vector2i(4, 1)), &"", "queued")
	assert_true(host.stop_underground_room(room), "stopped")
	assert_equal(host.underground_rooms().kept(), 0, "forgotten")


func test_a_waiting_room_whose_start_is_refused_is_forgotten_on_the_tick() -> void:
	"""The host starts waiting rooms after the runtime's advance. Here no way in was ever bound (no contacts), so the
	start (its parking off the access) is refused: the record is forgotten, the room stays, and the tick goes on.
	(The refusal's alert goes to UIManager's HUD, which a headless host has none of: not asserted here.)"""
	var host: Node = _composed()
	var crew: PackedInt32Array = _a_mole(host)
	if crew.is_empty(): return # An art-free village with no mole: nothing to name.
	var room: Vector2i = host.directory().create(Directory.KIND_ROOM)
	assert_equal(host.underground_rooms().order_room(room, Vector2i(3, 1), Vector2i(4, 1), NULL_REF, crew), &"",
		"queued with a free crew")
	assert_true(host.run_tick(1), "the tick runs")
	assert_equal(host.underground_rooms().kept(), 0, "the refused start forgot the record")
	assert_true(host.directory().is_valid(room), "the room itself stays")


func test_a_named_crew_round_trips_through_the_settlement_save_and_saves_identically() -> void:
	"""Record version 2 through the real save path: a queued room's named crew is restored by the load, and the loaded
	settlement saves byte-identically."""
	var host: Node = _composed()
	var room: Vector2i = host.directory().create(Directory.KIND_ROOM)
	var crew: PackedInt32Array = PackedInt32Array([7, 3, 9, 2])
	assert_equal(host.underground_rooms().order_room(room, Vector2i(3, 1), Vector2i(4, 1), NULL_REF, crew), &"", "queued")
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(host, _node(GameManagerScript.new()), bytes)
	assert_true(refusal.is_ok(), "save: %s %s" % [refusal.code, refusal.detail])
	var target: Node = _node(Settlement.new())
	refusal = SettlementSave.load_bytes(target, _node(GameManagerScript.new()), bytes, _content)
	assert_true(refusal.is_ok(), "load: %s %s" % [refusal.code, refusal.detail])
	assert_equal(target.underground_rooms().crew_of(room), crew, "the crew restored")
	var again: PackedByteArray = PackedByteArray()
	assert_true(SettlementSave.save_bytes(target, _node(GameManagerScript.new()), again).is_ok(), "saved again")
	assert_true(again == bytes, "byte-identical")
