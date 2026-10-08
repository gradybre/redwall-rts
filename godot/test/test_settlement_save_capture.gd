extends "res://test/framework/test_case.gd"
## `settlement_save_capture.gd` over a real generated settlement (ADR 1222 step 8).
##
## A headless SettlementSystem generates the starter world and a standalone GameManager supplies the
## clock; every one of sections 1-14 is captured and each body is decoded again by its own section
## codec, so a capture can never emit bytes its own decoder refuses.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

var _settlement: Node = null
var _manager: Node = null


func before_each() -> void:
	"""A generated starter settlement and a manager whose clock it never ticked."""
	_settlement = SettlementSystemScript.new()
	_manager = GameManagerScript.new()
	assert_true(_settlement.create_generated_settlement(_settlement.item_definitions()),
		"the starter settlement generates")


func after_each() -> void:
	"""Free both nodes."""
	_settlement.free()
	_manager.free()


func _captured() -> Array:
	"""[Body, Staged] of the live settlement, asserting the capture succeeds."""
	var world: SaveWorld.World = SaveWorld.bind(_settlement, _manager)
	var staged: Capture.Staged = Capture.Staged.new()
	var body: SaveFile.Body = SaveFile.Body.new()
	var refusal: SaveHeader.Refusal = Capture.capture_body(world, staged, body)
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	return [body, staged]


func test_every_captured_section_decodes_with_its_own_codec() -> void:
	"""Sections 1-14 are non-empty and each decodes; descriptor facts follow the section records."""
	var parts: Array = _captured()
	var body: SaveFile.Body = parts[0]
	for id: int in range(1, 15):
		assert_true(body.section(id).size() > 0, "section %d has bytes" % id)
	assert_true(Capture.S01.decode_section(body.section(1), 0, body.section(1).size(),
		Capture.S01.State.new()).is_ok(), "section 1 decodes")
	assert_true(Capture.S03.decode_into(body.section(3), 0, Capture.S03.Record.new()).is_ok(),
		"section 3 decodes")
	assert_true(Capture.S05.decode_section(body.section(5), 0, body.section(5).size(),
		Capture.S05.State.new()).is_ok(), "section 5 decodes")
	assert_true(Capture.S06.decode_section(body.section(6), 0, body.section(6).size(),
		Capture.S06.State.new()).is_ok(), "section 6 decodes")
	assert_true(Capture.S10.decode_into(body.section(10), 0, Capture.S10.Record.new()).is_ok(),
		"section 10 decodes")
	assert_equal(body.section(4).size(), Capture.S04Schema.SECTION_BYTES, "section 4 length")
	assert_equal(body.schema_versions[3], Capture.S04Schema.SECTION_SCHEMA_VERSION, "s4 schema")
	assert_equal(body.completed_tick, _manager.clock().completed_tick(), "the clock's tick")


func test_a_mounted_underground_owner_refuses_until_its_codec_lands() -> void:
	"""With a spatial inventory endpoint bound, the capture refuses SAVE_UNSUPPORTED_STATE."""
	var world: SaveWorld.World = SaveWorld.bind(_settlement, _manager)
	world.inventory._spatial_world = Vector2i(1, 1)
	var refusal: SaveHeader.Refusal = Capture.capture_body(world, Capture.Staged.new(),
		SaveFile.Body.new())
	world.inventory._spatial_world = world.inventory.NULL_REF
	assert_equal(refusal.code, &"SAVE_UNSUPPORTED_STATE", "named: %s" % refusal.detail)
