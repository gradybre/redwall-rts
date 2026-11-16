extends "res://test/framework/test_case.gd"
## Decision 1936, P-1936-4 (a): the room-dig record through the real save path. Section 6's
## `underground_room_progress` block is the canonical empty one while the runtime keeps nothing; a kept record is
## captured, loaded into a fresh settlement (whose re-mount composes an empty runtime and binds its owners), restored
## after the entry's record, and saved again byte-identically. The every-tick parity of a running dig's record is
## test_underground_room_progress.gd's, on the Kitchen: in the game no level has a way in yet (slice D), so no dig
## can run in a mounted settlement.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const SaveUnderground := preload("res://scripts/core/save_underground_adapters.gd")
const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const RoomRuntime := preload("res://scripts/core/underground_room_runtime.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")

var _content: Chain.Content = null
var _nodes: Array[Node] = []


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


func _saved(settlement: Node) -> PackedByteArray:
	"""One complete save, asserting it succeeds."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(settlement, _node(GameManagerScript.new()), bytes)
	assert_true(refusal.is_ok(), "save: %s %s" % [refusal.code, refusal.detail])
	return bytes


func _loaded(bytes: PackedByteArray) -> Node:
	"""A fresh settlement loaded from `bytes`, asserting the load succeeds."""
	var target: Node = _node(Settlement.new())
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(target, _node(GameManagerScript.new()), bytes, _content)
	assert_true(refusal.is_ok(), "load: %s %s" % [refusal.code, refusal.detail])
	return target


func _block(host: Node) -> Section.Block:
	"""The room-dig owner's section 6 block as the adapter captures it from `host`."""
	var world: SaveWorld.World = SaveWorld.World.new()
	world.settlement = host
	SaveWorld.bind_underground(world)
	var block: Section.Block = Section.Block.new(Schema.OWNER_KEYS.find("underground_room_progress"))
	var adapter: SaveUnderground.RoomsAdapter = SaveUnderground.RoomsAdapter.new(world)
	assert_true(adapter.capture(block).is_ok(), "captured")
	assert_true(adapter.validate(block).is_ok(), "valid")
	return block


func test_an_empty_runtime_saves_the_canonical_empty_block_and_loads_empty() -> void:
	"""Composed, nothing ordered: the block is canonical-empty, and the loaded settlement's runtime is composed,
	bound and empty."""
	var host: Node = _composed()
	assert_true(host.underground_rooms().is_empty(), "nothing kept")
	assert_true(_block(host).is_canonical_empty(), "the canonical empty block")
	var target: Node = _loaded(_saved(host))
	assert_not_null(target.underground_rooms(), "the re-mount composed a runtime")
	assert_not_null(target.underground_rooms().bound_owners(), "its owners bound")
	assert_true(target.underground_rooms().is_empty(), "and empty")


func test_a_kept_record_round_trips_through_the_save_and_saves_identically() -> void:
	"""A queued room's record row is captured into the block, restored by the load after the entry's record, and
	the loaded settlement saves byte-identically; its own runtime holds the same record."""
	var host: Node = _composed()
	var room: Vector2i = host.directory().create(Directory.KIND_ROOM)
	var runtime: RoomRuntime = host.underground_rooms()
	assert_equal(runtime.order_room(room, Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)), &"", "queued")
	var block: Section.Block = _block(host)
	var record: PackedByteArray = PackedByteArray()
	assert_equal(runtime.capture(record), &"", "the runtime's record")
	assert_equal(block.scalar(0), record.size(), "its length")
	assert_true(block.u8_column(1) == record, "carried whole")
	var first: PackedByteArray = _saved(host)
	var target: Node = _loaded(first)
	var restored: RoomRuntime = target.underground_rooms()
	assert_true(restored != runtime, "a runtime of its own")
	assert_equal(restored.state_of(room), RoomRuntime.RECORD_QUEUED, "the room is queued again")
	assert_equal(restored.kept(), 1, "one record")
	var again: PackedByteArray = PackedByteArray()
	assert_equal(restored.capture(again), &"", "captured again")
	assert_true(again == record, "the same record")
	assert_true(_saved(target) == first, "the loaded settlement saves byte-identically")


func test_a_record_carrying_a_declared_column_outside_it_is_refused() -> void:
	"""Decision 1936 declared the ten carried columns hash-free; a block with any of them filled, or whose length
	disagrees with its record, is refused by the adapter."""
	var host: Node = _composed()
	var world: SaveWorld.World = SaveWorld.World.new()
	world.settlement = host
	SaveWorld.bind_underground(world)
	var adapter: SaveUnderground.RoomsAdapter = SaveUnderground.RoomsAdapter.new(world)
	var owner: int = Schema.OWNER_KEYS.find("underground_room_progress")
	var block: Section.Block = Section.Block.new(owner)
	assert_true(block.set_scalar(0, 1).is_ok(), "a length with no record")
	assert_equal(adapter.validate(block).code, SaveUnderground.SaveAux.REFUSE_OWNER_STATE, "length mismatch")
	for ordinal: int in range(2, Schema.field_count_of(owner), 2):
		var outside: Section.Block = Section.Block.new(owner)
		assert_true(outside.set_scalar(ordinal, 1).is_ok(), "a declared column's length set")
		assert_equal(adapter.validate(outside).code, SaveUnderground.SaveAux.REFUSE_OWNER_STATE,
			"%s outside the record" % Schema.field_key_of(owner, ordinal + 1))
