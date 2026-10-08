extends "res://test/framework/test_case.gd"
## `save_aux_adapters.gd`: the section 6 owner adapters (ADR 1222 step 4b).
##
## Two headless SettlementSystems: the source's stores are given non-default section 6 state
## through their own restore entry points, every adapter captures into a section 6 State that is
## carried through the real codec, validated and applied into the target, and each target store
## must then save exactly the source's values. Out-of-domain blocks refuse and write nothing.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveAux := preload("res://scripts/core/save_aux_adapters.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

var _source: Node = null
var _target: Node = null


func before_each() -> void:
	"""Two settlements that are never added to the tree."""
	_source = SettlementSystemScript.new()
	_target = SettlementSystemScript.new()


func after_each() -> void:
	"""Free both nodes."""
	_source.free()
	_target.free()


func _adapters(system: Node) -> Dictionary:
	"""owner key -> adapter over `system`'s live stores."""
	return {
		"crop_weather": SaveAux.CropWeatherAdapter.new(system.crop_weather()),
		"ecology": SaveAux.EcologyAdapter.new(system.ecology()),
		"command_dispatch": SaveAux.CommandDispatchAdapter.new(system.command_dispatch()),
		"demolition_admissions": SaveAux.ColumnsAdapter.new(system.demolition_admissions(),
			"demolition_admissions"),
		"demolition_work": SaveAux.ColumnsAdapter.new(system.demolition_work(), "demolition_work"),
		"store_policy": SaveAux.ColumnsAdapter.new(system._store_policy, "store_policy"),
		"haul_planner": SaveAux.HaulPlannerAdapter.new(system._haul_planner),
	}


func _dirty_source() -> void:
	"""Non-default state in every adapted owner, through each owner's own restore entry point."""
	assert_true(_source.crop_weather().restore_latches(7, 9000), "crop latches")
	assert_true(_source.ecology().restore_last_day(7), "ecology latch")
	var player: PackedInt32Array = PackedInt32Array()
	player.resize(128)
	player.fill(-1)
	player[3] = 2
	var zeros: PackedInt32Array = PackedInt32Array()
	zeros.resize(128)
	var sequence: PackedInt32Array = zeros.duplicate()
	sequence[3] = 41
	assert_true(_source.command_dispatch().restore_intent_columns(player, zeros, sequence, zeros),
		"one recorded intent")
	var admissions: Array = _source.demolition_admissions().save_columns()
	admissions[6][10] = 5
	assert_true(_source.demolition_admissions().restore_columns(admissions), "a revision moved")
	var policy: Array = _source._store_policy.save_columns()
	policy[0][300] = 0
	policy[2][1] = 77
	assert_true(_source._store_policy.restore_columns(policy), "a restricted cell")


func _captured() -> Section.State:
	"""The source's blocks, encoded and decoded through the real section 6 codec."""
	var state: Section.State = Section.State.new()
	var adapters: Dictionary = _adapters(_source)
	for key: String in adapters:
		var block: Section.Block = state.block(Schema.OWNER_KEYS.find(key))
		var refusal: SaveHeader.Refusal = adapters[key].capture(block)
		assert_true(refusal.is_ok(), "%s capture: %s" % [key, refusal.detail])
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(state, out), "section 6 encodes: %s" % out.detail)
	var decoded: Section.State = Section.State.new()
	assert_true(Section.decode_section(out.bytes, 0, out.bytes.size(), decoded).is_ok(), "decodes")
	return decoded


func test_every_adapter_round_trips_its_owner_exactly() -> void:
	"""Validate then apply into the target; each target owner saves the source's values."""
	_dirty_source()
	var state: Section.State = _captured()
	var adapters: Dictionary = _adapters(_target)
	for key: String in adapters:
		var block: Section.Block = state.block(Schema.OWNER_KEYS.find(key))
		assert_true(adapters[key].validate(block).is_ok(), "%s validates" % key)
		var refusal: SaveHeader.Refusal = adapters[key].apply(block)
		assert_true(refusal.is_ok(), "%s applies: %s %s" % [key, refusal.code, refusal.detail])
	assert_equal(_target.crop_weather().save_latches(), PackedInt64Array([7, 9000]), "latches")
	assert_equal(_target.ecology().save_last_day(), 7, "ecology latch")
	assert_equal(_target.demolition_admissions().save_columns(),
		_source.demolition_admissions().save_columns(), "admissions")
	assert_equal(_target._store_policy.save_columns(), _source._store_policy.save_columns(),
		"store policy")
	var reread: Section.State = Section.State.new()
	for key: String in adapters:
		var block: Section.Block = reread.block(Schema.OWNER_KEYS.find(key))
		assert_true(adapters[key].capture(block).is_ok(), "recapture %s" % key)
		assert_true(block.equals(state.block(Schema.OWNER_KEYS.find(key))), "%s identical" % key)


func test_out_of_domain_blocks_refuse_and_write_nothing() -> void:
	"""A negative latch, a half-free intent slot and a 2 in the allow arena each refuse."""
	var state: Section.State = _captured()
	var crop: Section.Block = state.block(Schema.OWNER_KEYS.find("crop_weather"))
	assert_true(crop.set_scalar(1, -5).is_ok(), "corrupt the hour latch")
	var adapters: Dictionary = _adapters(_target)
	assert_false(adapters["crop_weather"].validate(crop).is_ok(), "validate refuses")
	assert_false(adapters["crop_weather"].apply(crop).is_ok(), "apply refuses")
	var intents: Section.Block = state.block(Schema.OWNER_KEYS.find("command_dispatch"))
	var high: PackedInt32Array = intents.i32_column(1)
	high[0] = 4
	assert_true(intents.set_i32_column(1, high).is_ok(), "a sequence on a free slot")
	assert_false(adapters["command_dispatch"].apply(intents).is_ok(), "intents refuse")
	var policy: Section.Block = state.block(Schema.OWNER_KEYS.find("store_policy"))
	var allowed: PackedByteArray = policy.u8_column(0)
	allowed[0] = 2
	assert_true(policy.set_u8_column(0, allowed).is_ok(), "x")
	assert_false(adapters["store_policy"].apply(policy).is_ok(), "the allow arena refuses")
	assert_equal(_target.crop_weather().save_latches(), _source.crop_weather().save_latches(),
		"the target kept its own latches")
	assert_equal(_target._store_policy.save_columns()[0][0], 1, "and its own policy")
