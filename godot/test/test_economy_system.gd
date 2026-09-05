extends "res://test/framework/test_case.gd"
## Coverage for stockpile arithmetic, storage caps and the economy tick budget.

const EconomySystemScript := preload("res://scripts/systems/economy_system.gd")

const TICK_BUDGET_USEC: int = 2000

var _economy: EconomySystemScript = null
var _depleted: Array[StringName] = []
var _changes: int = 0


func before_each() -> void:
	"""Build a fresh economy system and listen for its UI signals."""
	_economy = EconomySystemScript.new()
	_depleted = []
	_changes = 0
	_economy.resource_depleted.connect(_on_resource_depleted)
	_economy.resource_changed.connect(_on_resource_changed)


func after_each() -> void:
	"""Free the economy system built for the test."""
	if _economy != null:
		_economy.free()
		_economy = null


func test_starts_empty() -> void:
	"""Every tracked resource begins at zero with a default cap."""
	for resource_type: StringName in _economy.get_resource_types():
		assert_almost_equal(_economy.get_amount(resource_type), 0.0, "%s starts at zero" % resource_type)
		assert_almost_equal(_economy.get_cap(resource_type), EconomySystemScript.DEFAULT_STORAGE_CAP, "%s has the default cap" % resource_type)


func test_add_resource_accumulates() -> void:
	"""Adding to a stockpile raises it and reports the change once."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 25.0)
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 15.0)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 40.0, "food accumulated")
	assert_equal(_changes, 2, "each change was signalled once")


func test_add_resource_ignores_non_positive() -> void:
	"""Negative or zero additions are rejected rather than silently draining."""
	_economy.add_resource(EconomySystemScript.RESOURCE_WOOD, 10.0)
	_economy.add_resource(EconomySystemScript.RESOURCE_WOOD, -5.0)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_WOOD), 10.0, "wood is unchanged by a negative add")


func test_add_resource_clamps_at_cap() -> void:
	"""A stockpile never exceeds its storage cap."""
	_economy.set_cap(EconomySystemScript.RESOURCE_STONE, 30.0)
	_economy.add_resource(EconomySystemScript.RESOURCE_STONE, 100.0)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_STONE), 30.0, "stone is capped")


func test_set_cap_clamps_existing_stockpile() -> void:
	"""Lowering a cap trims whatever is already stored."""
	_economy.add_resource(EconomySystemScript.RESOURCE_STONE, 100.0)
	_economy.set_cap(EconomySystemScript.RESOURCE_STONE, 40.0)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_STONE), 40.0, "stone trimmed to the new cap")


func test_try_consume_spends_when_affordable() -> void:
	"""A affordable cost is deducted and reported as paid."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 50.0)
	assert_true(_economy.try_consume(EconomySystemScript.RESOURCE_FOOD, 20.0), "purchase succeeds")
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 30.0, "food was deducted")


func test_try_consume_is_all_or_nothing() -> void:
	"""An unaffordable cost leaves the stockpile untouched."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 10.0)
	assert_false(_economy.try_consume(EconomySystemScript.RESOURCE_FOOD, 25.0), "purchase fails")
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 10.0, "nothing was spent")


func test_tick_applies_net_rates() -> void:
	"""One tick moves each stockpile by its per-second rate."""
	_economy.set_rate(EconomySystemScript.RESOURCE_FOOD, 2.5)
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 2.5, "one tick of production")
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 5.0, "two ticks of production")


func test_tick_never_drives_a_stockpile_negative() -> void:
	"""Consumption outruns supply without producing negative stock."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 3.0)
	_economy.set_rate(EconomySystemScript.RESOURCE_FOOD, -5.0)
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 0.0, "food floors at zero")


func test_depletion_signals_once_per_drain() -> void:
	"""Reaching zero raises resource_depleted, and staying at zero does not repeat it."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 1.0)
	_economy.set_rate(EconomySystemScript.RESOURCE_FOOD, -5.0)
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_equal(_depleted.size(), 1, "depletion signalled exactly once")
	assert_equal(_depleted[0], EconomySystemScript.RESOURCE_FOOD, "food is the depleted resource")


func test_unknown_resource_is_inert() -> void:
	"""An unknown key changes nothing and reads back as zero."""
	assert_false(_economy.is_tracked(&"moonlight"), "moonlight is not a resource")
	assert_almost_equal(_economy.get_amount(&"moonlight"), 0.0, "unknown resource reads zero")
	assert_false(_economy.try_consume(&"moonlight", 1.0), "unknown resource cannot be spent")


func test_reset_returns_to_starting_state() -> void:
	"""reset() clears stockpiles and rates together."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 30.0)
	_economy.set_rate(EconomySystemScript.RESOURCE_FOOD, 4.0)
	_economy.reset()
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 0.0, "stockpile cleared")
	assert_almost_equal(_economy.get_rate(EconomySystemScript.RESOURCE_FOOD), 0.0, "rate cleared")


func test_tick_stays_within_budget() -> void:
	"""A full-rate tick costs less than the 2ms economy budget."""
	for resource_type: StringName in _economy.get_resource_types():
		_economy.set_rate(resource_type, 1.37)
	_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_less_than(_economy.get_last_tick_usec(), TICK_BUDGET_USEC, "economy tick is under 2ms")


func test_small_rates_are_not_discarded_at_high_stock() -> void:
	"""A slow rate must keep accumulating even when the stockpile is large."""
	_economy.add_resource(EconomySystemScript.RESOURCE_FOOD, 400.0)
	_economy.set_rate(EconomySystemScript.RESOURCE_FOOD, 0.003)
	for index: int in 100:
		_economy.tick(EconomySystemScript.ECONOMY_TICK_RATE)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_FOOD), 400.3, "slow production still accumulates")


func test_exactly_affordable_cost_is_payable_after_float_accumulation() -> void:
	"""Ten additions of 0.1 must still buy something costing 1.0."""
	for index: int in 10:
		_economy.add_resource(EconomySystemScript.RESOURCE_WOOD, 0.1)
	assert_true(_economy.try_consume(EconomySystemScript.RESOURCE_WOOD, 1.0), "exact cost is affordable")
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_WOOD), 0.0, "the stockpile is spent out")


func test_lowering_a_cap_does_not_report_depletion() -> void:
	"""Trimming to a smaller store is not the same as running out."""
	_economy.add_resource(EconomySystemScript.RESOURCE_STONE, 100.0)
	_economy.set_cap(EconomySystemScript.RESOURCE_STONE, 0.0)
	assert_almost_equal(_economy.get_amount(EconomySystemScript.RESOURCE_STONE), 0.0, "stone was trimmed")
	assert_equal(_depleted.size(), 0, "a storage downgrade is not a depletion")


func _on_resource_depleted(resource_type: StringName) -> void:
	"""Record a depletion signal for assertion."""
	_depleted.append(resource_type)


func _on_resource_changed(_resource_type: StringName, _amount: float) -> void:
	"""Count change signals for assertion."""
	_changes += 1
