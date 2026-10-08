extends "res://test/framework/test_case.gd"
## The underground save body end to end (ADR 1228).
##
## A settlement with its underground Session mounted and composed saves, loads into a DIFFERENT,
## fresh settlement (which re-mounts it from the mount record) and saves again byte-identically.
## The goal test: the live entry chain, driven by the GameManager from the surface walk through the
## hauls, the paid phases and the installation, is saved to a FILE at each checkpoint, loaded into a
## fresh settlement and run on to the next checkpoint, where its save is byte-identical to the
## uninterrupted run's.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveUnderground := preload("res://scripts/core/save_underground_adapters.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")

## 100 ms host frames: exactly three ticks at 1x.
const FRAME_USEC: int = 100000
## Save points along the live chain, from the surface walk through the hauls, the paid phases and
## the installation; each is loaded and run to the next. Multiples of 3: one host frame is 3 ticks.
const CHECKPOINTS: Array[int] = [210, 1200, 2004, 2805, 3609, 4410]
## Past the first-entry prefix's finish (ADR 1227: tick 4630 in the host suite's chain).
const END_TICK: int = 4800
const SAVE_PATH: String = "user://test_settlement_save_underground.rwlsave"
const ROLLBACK_PATH: String = "user://test_settlement_save_underground.rwlsave.rollback"

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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _node(node: Node) -> Node:
	"""Track a node for after_each."""
	_nodes.append(node)
	return node


func _composed() -> Node:
	"""A generated settlement, mounted and composed."""
	var host: Node = _node(Settlement.new())
	assert_equal(Chain.mount_and_compose(host, _content), &"", "mounted and composed")
	return host


func _saved(settlement: Node, manager: Node) -> PackedByteArray:
	"""One complete save, asserting it succeeds."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(settlement, manager, bytes)
	assert_true(refusal.is_ok(), "save: %s %s" % [refusal.code, refusal.detail])
	return bytes


func _advance_to(settlement: Node, tick: int) -> void:
	"""Drive the autoload GameManager until `tick` has completed."""
	assert_true(GameManager.bind_simulation(settlement.run_tick, settlement.run_day_boundary),
		"bind %s" % GameManager.last_refusal())
	var frames: int = 0
	while GameManager.clock().completed_tick() < tick and frames < tick:
		GameManager.advance_host_time(FRAME_USEC)
		frames += 1
	GameManager.unbind_simulation()
	assert_equal(GameManager.clock().completed_tick(), tick, "the clock reached %d" % tick)


func test_a_composed_session_loads_into_a_fresh_settlement_and_saves_identically() -> void:
	"""Mounted and composed, nothing begun: the target re-mounts to prefix 17 and saves the same."""
	var host: Node = _composed()
	var manager: Node = _node(GameManagerScript.new())
	var first: PackedByteArray = _saved(host, manager)
	var target: Node = _node(Settlement.new())
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(target, _node(GameManagerScript.new()), first,
		_content)
	assert_true(refusal.is_ok(), "load: %s %s" % [refusal.code, refusal.detail])
	assert_equal(target.underground_session()._operations_prefix, 17, "re-mounted through every composer step")
	assert_true(target.underground_session() != host.underground_session(), "a Session of its own")
	assert_true(_saved(target, manager) == first, "the restored world saves identically")


func test_a_mounted_save_refuses_without_its_content() -> void:
	"""No content to re-mount with: the load refuses and leaves the target empty and out of LOAD."""
	var bytes: PackedByteArray = _saved(_composed(), _node(GameManagerScript.new()))
	var target: Node = _node(Settlement.new())
	var manager: Node = _node(GameManagerScript.new())
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(target, manager, bytes)
	assert_equal(refusal.code, SaveUnderground.REFUSE_MOUNT, "refused at the mount record")
	assert_equal(target.residents().population(), 0, "the target was left empty")
	assert_true(target.underground_session() == null, "nothing stays mounted")
	assert_false(manager.is_loading(), "the load was rolled back")


func _entry_stage(host: Node) -> String:
	"""A one-line description of where the entry chain is."""
	var entry: RefCounted = host.underground_entry()
	if not entry.is_running():
		return "stopped(%s)" % entry.error()
	if entry.walk_ticks_left() > 0:
		return "walking(%d)" % entry.walk_ticks_left()
	var foreman: RefCounted = entry._foreman
	return "task %d, %d trips, %d mWU" % [foreman._index, foreman.haul_trips(), foreman.accepted_mwu()]


func _checkpoint_saves(host: Node) -> Array[PackedByteArray]:
	"""The uninterrupted run: a file-format save at every checkpoint and at END_TICK."""
	var saves: Array[PackedByteArray] = []
	var ticks: Array[int] = CHECKPOINTS.duplicate()
	ticks.append(END_TICK)
	for tick: int in ticks:
		_advance_to(host, tick)
		print("SAVE-UNDERGROUND checkpoint %d: %s" % [tick, _entry_stage(host)])
		saves.append(_saved(host, GameManager))
	return saves


func test_the_live_chain_saved_to_a_file_at_each_checkpoint_continues_byte_identically() -> void:
	"""GOAL (ADR 1228): the uninterrupted live chain is saved at every checkpoint (mid-walk, after
	arrival, hauling, in the paid phases, in the installation) and at END_TICK. Each checkpoint's
	save is written to a FILE, loaded into a FRESH settlement and run to the next checkpoint, where
	its save must be byte-identical to the uninterrupted run's."""
	assert_true(GameManager.start_game(), "a fresh clock")
	var host: Node = _composed()
	assert_equal(Chain.begin_entry(host), &"", "the entry begins")
	var saves: Array[PackedByteArray] = _checkpoint_saves(host)
	var ends: Array[int] = []
	ends.assign(CHECKPOINTS.slice(1))
	ends.append(END_TICK)
	for index: int in CHECKPOINTS.size():
		assert_true(SaveFile.write_atomic(SAVE_PATH, saves[index]).is_ok(), "file %d written" % index)
		var target: Node = _node(Settlement.new())
		var loaded: SaveHeader.Refusal = SettlementSave.load_bytes(target, GameManager,
			FileAccess.get_file_as_bytes(SAVE_PATH), _content)
		assert_true(loaded.is_ok(), "load at %d: %s %s" % [CHECKPOINTS[index], loaded.code, loaded.detail])
		if not loaded.is_ok():
			return
		assert_equal(GameManager.clock().completed_tick(), CHECKPOINTS[index], "the clock went back")
		_advance_to(target, ends[index])
		assert_true(_saved(target, GameManager) == saves[index + 1],
			"loaded at %d and run to %d: byte-identical" % [CHECKPOINTS[index], ends[index]])


func test_a_failed_load_restores_the_target_from_its_disk_checkpoint() -> void:
	"""ARCH-SAVE-004: a populated target is saved to its checkpoint before it is retired; a load that
	fails after that (a mounted save with no content to re-mount) puts the target back exactly,
	closes the load and removes the checkpoint."""
	var bytes: PackedByteArray = _saved(_composed(), _node(GameManagerScript.new()))
	var target: Node = _node(Settlement.new())
	assert_true(target.create_generated_settlement(target.item_definitions()), "a populated target")
	var manager: Node = _node(GameManagerScript.new())
	var before: PackedByteArray = _saved(target, manager)
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(target, manager, bytes, null, ROLLBACK_PATH)
	assert_equal(refusal.code, SaveUnderground.REFUSE_MOUNT, "refused at the mount record, after retirement")
	assert_false(manager.is_loading(), "the load was rolled back")
	assert_true(_saved(target, manager) == before, "the target is exactly its old world again")
	assert_false(FileAccess.file_exists(ROLLBACK_PATH), "the checkpoint is removed once it has restored")
