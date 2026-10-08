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
	assert_true(_saved(_target, _target_manager) == first, "the restored world saves identically")


func test_a_corrupted_file_refuses_before_the_target_is_touched() -> void:
	"""One flipped body byte refuses on its CRC; the target stays empty and never enters LOAD."""
	var bytes: PackedByteArray = _saved(_source, _source_manager)
	bytes[bytes.size() - 40] ^= 0x01
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(_target, _target_manager, bytes)
	assert_equal(refusal.code, SaveFile.REFUSE_SECTION_CRC, "refused on its CRC")
	assert_equal(_target.residents().population(), 0, "nothing was installed")
	assert_false(_target_manager.is_loading(), "no load was opened")
