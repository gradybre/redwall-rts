extends "res://test/framework/test_case.gd"
## `settlement_save.gd` end to end (ADR 1222 steps 8-9).
##
## A generated starter settlement is saved to bytes, loaded into a DIFFERENT, fresh settlement with
## its own GameManager, and saved again: the second file must be byte-identical to the first. A
## corrupted file refuses before the target is touched; a refusal after the load opened leaves the
## target empty and the manager out of LOAD.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

var _source: Node = null
var _source_manager: Node = null
var _target: Node = null
var _target_manager: Node = null


func before_each() -> void:
	"""A generated source settlement and an empty target, each with its own manager."""
	_source = SettlementSystemScript.new()
	_source_manager = GameManagerScript.new()
	_target = SettlementSystemScript.new()
	_target_manager = GameManagerScript.new()
	assert_true(_source.create_generated_settlement(_source.item_definitions()), "generates")


func after_each() -> void:
	"""Free all four nodes."""
	for node: Node in [_source, _source_manager, _target, _target_manager]:
		node.free()


func _saved(settlement: Node, manager: Node) -> PackedByteArray:
	"""One complete save of `settlement`, asserting it succeeds."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(settlement, manager, bytes)
	assert_true(refusal.is_ok(), "save: %s %s" % [refusal.code, refusal.detail])
	return bytes


func test_a_saved_settlement_loads_into_a_fresh_one_and_saves_byte_identically() -> void:
	"""Save, load into a different settlement, save again: the two files are identical."""
	var first: PackedByteArray = _saved(_source, _source_manager)
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(_target, _target_manager, first)
	assert_true(refusal.is_ok(), "load: %s %s" % [refusal.code, refusal.detail])
	assert_false(_target_manager.is_loading(), "the load is closed")
	assert_equal(_target.residents().population(), _source.residents().population(), "people")
	assert_true(_target.world_ref() != Vector2i(-1, 0), "the World row is restored")
	assert_equal(_target.ground_piles().ground_pile_owner_ref(), _target.world_ref(),
		"ADR 1228: the ground-pile composer owns new piles as the restored World")
	assert_true(_saved(_target, _target_manager) == first, "the restored world saves identically")


func test_a_corrupted_file_refuses_before_the_target_is_touched() -> void:
	"""One flipped body byte refuses on its CRC; the target stays empty and never enters LOAD."""
	var bytes: PackedByteArray = _saved(_source, _source_manager)
	bytes[bytes.size() - 40] ^= 0x01
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(_target, _target_manager, bytes)
	assert_equal(refusal.code, SaveFile.REFUSE_SECTION_CRC, "refused on its CRC")
	assert_equal(_target.residents().population(), 0, "nothing was installed")
	assert_false(_target_manager.is_loading(), "no load was opened")


# --- continuation ---------------------------------------------------------------------------------

## 100 ms host frames: exactly three ticks at 1x, so no sub-tick debt is ever carried.
const FRAME_USEC: int = 100000


func _advance(settlement: Node, ticks: int) -> void:
	"""Drive the autoload GameManager (which `run_tick` reads) until `ticks` more have completed."""
	var target: int = GameManager.clock().completed_tick() + ticks
	assert_true(GameManager.bind_simulation(settlement.run_tick, settlement.run_day_boundary),
		"bind %s" % GameManager.last_refusal())
	var frames: int = 0
	while GameManager.clock().completed_tick() < target and frames < ticks:
		GameManager.advance_host_time(FRAME_USEC)
		frames += 1
	GameManager.unbind_simulation()
	assert_equal(GameManager.clock().completed_tick(), target, "the clock reached its target")


func _cleanup_autoload() -> void:
	"""Leave the autoload as the other suites expect it."""
	GameManager.unbind_simulation()
	GameManager.scheduler_events().clear()
	GameManager.clock().set_pause(SimClockScript.CRITICAL, false)


const SimClockScript := preload("res://scripts/core/sim_clock.gd")


func test_a_loaded_settlement_continues_exactly_like_the_original() -> void:
	"""Save at tick 300, run the source to 1200; load into a new settlement, run it to 1200:
	the two saves at 1200 are byte-identical."""
	assert_true(GameManager.start_game(), "a fresh clock")
	_advance(_source, 300)
	var at_300: PackedByteArray = _saved(_source, GameManager)
	_advance(_source, 900)
	var expected: PackedByteArray = _saved(_source, GameManager)
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(_target, GameManager, at_300)
	assert_true(refusal.is_ok(), "load: %s %s" % [refusal.code, refusal.detail])
	assert_equal(GameManager.clock().completed_tick(), 300, "the clock went back to the save")
	_advance(_target, 900)
	assert_true(_saved(_target, GameManager) == expected, "the continuation is byte-identical")
	_cleanup_autoload()
