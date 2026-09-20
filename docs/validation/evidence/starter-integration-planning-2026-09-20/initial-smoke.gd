extends "res://test/framework/test_case.gd"
const Starter := preload("res://scripts/core/starter_structures.gd")
func test_exact_candidate_smoke() -> void:
	var producer = Starter.new()
	var plan = Starter.Plan.new()
	assert_true(producer.prepare_into(plan), "authored producer succeeds")
	assert_equal(producer.last_refusal(), &"", "no refusal")
	assert_equal(Starter.plan_refusal(plan), &"", "pure validator agrees")
	var arrays = [plan.buildings,plan.rooms,plan.room_tiles,plan.furniture,plan.footprints,plan.candidate_access_tiles,plan.edges,plan.exit_tiles,plan.bed_furniture_ordinals,plan.header]
	var bytes: int = 0
	for values in arrays: bytes += values.size() * 4
	assert_equal(bytes, 2480, "actual array payload")
	assert_equal(plan.header, PackedInt32Array([1,51,33,47]), "canonical header")
	assert_equal(plan.exit_tiles, PackedInt32Array([75,8768,8896]), "three-step exit")
