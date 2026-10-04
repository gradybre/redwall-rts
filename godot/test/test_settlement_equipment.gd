extends "res://test/framework/test_case.gd"
## ADR1148: actual boot owners, no extra stock, and whole-world reset of real equipped records.

const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Economy := preload("res://scripts/systems/economy_system.gd")
const Starter := preload("res://scripts/core/starter_colony.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")

var _host: Settlement = null


func before_each() -> void:
	"""A test-owned host never joins the tree or replaces the running GameManager binding."""
	_host = Settlement.new()


func after_each() -> void:
	"""Release the actual host and all its strongly held services."""
	_host.free()
	_host = null


func _assert_bindings() -> void:
	"""Compare actual collaborating instances, including Inventory's real equipment attestor."""
	assert_true(_host.gear().equipment_binding_matches(_host.inventory(), _host.directory(), _host.residents()), "exact equipment stores")
	assert_equal(_host.work().gear(), _host.gear(), "Work settles this Gear")
	assert_true(_host.haul_carry().binding_matches(_host.inventory(), _host.reservations(), _host.residents(), _host.ground_piles()), "exact Carry stores")
	assert_equal(_host.inventory()._equipment_authority.get_ref(), _host.gear(), "live original equipment authority")


func test_empty_host_wires_services_without_creating_stock_or_population() -> void:
	"""A constructor composes owners without silently creating gameplay state."""
	_assert_bindings()
	assert_equal(_host.population(), 0, "no residents minted")
	assert_equal(_host.gear().active_gear_count(), 0, "no tools minted")
	assert_equal(_host.gear().row_capacity(), 16384, "existing bounded Gear store")
	assert_equal(_host.haul_carry()._reclaim.size(), 5, "one existing fixed reclaim record")


func test_actual_demo_seed_still_creates_exactly_twenty_four_tools() -> void:
	"""Exercise main's actual shared Economy/Settlement seed path, without a second tool producer."""
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual generated settlement")
	var economy: Economy = Economy.new()
	var binding: Starter.StoreBinding = Starter.StoreBinding.new()
	assert_true(economy.bind_inventory(_host.inventory()), "same Inventory as main")
	assert_true(_host.starter_store_binding_into(binding), "actual completed starter stores")
	assert_true(economy.open_and_seed_starter_stores(binding), "actual starter stock")
	assert_equal(economy.stock_milli(&"tool"), 24000, "24 total, never 48")
	assert_equal(_host.gear().active_gear_count(), 0, "record conversion is a separate boot obligation")
	_assert_bindings()
	economy.free()


func test_reset_clears_real_equipped_record_and_preserves_service_identity() -> void:
	"""Teardown retires real lot/owner generations, never leaving Gear rows over removed stock."""
	assert_true(_host.create_initial_settlement(), "real authored residents")
	var owner: Vector2i = _host.residents().ref_of(0)
	var container: Inventory.OpResult = _host.inventory().create_container(owner, 100000, Inventory.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(container.ok, "test-owned store")
	var lot: Inventory.OpResult = _host.inventory().create_lot(container.ref, _host.item_definitions().compiled_id(&"tool"), 1000, 0, 3, 0, 0, 0)
	assert_true(lot.ok, "one existing finite tool lot")
	assert_true(_host.gear().create_gear(_host.inventory(), _host.item_definitions(), lot.ref, Gear.MANUFACTURE_BASIC).ok, "real gear record")
	assert_true(_host.gear().equip(lot.ref, owner).ok, "actual equipped tool")
	var original_gear: Gear = _host.gear()
	var original_carry: Carry = _host.haul_carry()
	_host.reset()
	assert_equal(_host.gear(), original_gear, "Gear allocation retained")
	assert_equal(_host.haul_carry(), original_carry, "Carry allocation retained")
	assert_equal(_host.gear().active_gear_count(), 0, "Gear rows cleared")
	assert_equal(_host.gear().equipped_count(), 0, "no orphan equipped record")
	assert_false(_host.inventory().is_lot_valid(lot.ref), "old lot retired")
	assert_false(_host.directory().is_valid(owner), "old resident retired")
	_assert_bindings()


func test_repeated_generation_keeps_original_services_and_fresh_world_identity() -> void:
	"""Regeneration reuses the composed services, while full World handles change generation."""
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "first World")
	var original: Vector2i = _host.world_ref()
	var original_gear: Gear = _host.gear()
	var original_carry: Carry = _host.haul_carry()
	_host.reset()
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "next World")
	assert_true(_host.world_ref() != original, "stale World cannot survive reset")
	assert_equal(_host.gear(), original_gear, "same Gear")
	assert_equal(_host.haul_carry(), original_carry, "same Carry")
	assert_equal(_host.gear().active_gear_count(), 0, "no implicit tool producer")
	_assert_bindings()
