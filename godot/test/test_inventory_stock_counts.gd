extends "res://test/framework/test_case.gd"
## INIT-COUNT-R01v2: independent totals, atomic refusal and real equipment behavior.

const Inventory := preload("res://scripts/core/inventory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Definitions := preload("res://scripts/core/item_definitions.gd")
const MAX_I64: int = 9223372036854775807
const FIELDS: Array[StringName] = [
	&"live_milli", &"loose_milli", &"equipped_milli", &"unreserved_loose_milli"]

var _inv: Inventory
var _target: Inventory.StockCounts
var _out: IntMath.IntResult


class UncalledAuthority extends RefCounted:
	"""A counter detects any accidental collaborator call without changing Inventory."""
	var calls: int = 0

	func is_equipped_record(_lot: Vector2i) -> bool:
		"""This predicate must never be reached by a count read."""
		calls += 1
		return false


class ReentrantAuthority extends RefCounted:
	"""Existing attestation deliberately requests a snapshot during its guarded callback."""
	var borrowed: WeakRef
	var refused: bool = false
	var error: String = ""

	func is_equipped_record(_lot: Vector2i) -> bool:
		"""Nested counts must refuse BUSY and leave the outer guard raised."""
		var inv: Inventory = borrowed.get_ref() as Inventory
		var result: IntMath.IntResult = IntMath.IntResult.new()
		refused = not inv.copy_stock_counts_into(Inventory.StockCounts.new(), result)
		error = result.error
		refused = refused and bool(inv.get("_attesting"))
		return false


func before_each() -> void:
	"""Small real stores preserve the exact owner API without allocating a second world."""
	_inv = Inventory.new(8, 16)
	assert_true(_inv.register_item(0, 1, 0).ok, "item zero registered")
	assert_true(_inv.register_item(255, 1, 0).ok, "last item registered")
	_target = Inventory.StockCounts.new()
	_out = IntMath.IntResult.new()


func _container() -> Vector2i:
	"""Create an ordinary reachable store."""
	var made: Inventory.OpResult = _inv.create_container(
		Inventory.NULL_REF, 1000000, Inventory.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(made.ok, "container fixture")
	return made.ref


func _lot(container: Vector2i, item: int, quantity: int) -> Vector2i:
	"""Create stock through real mutation and reservation accounting."""
	var made: Inventory.OpResult = _inv.create_lot(container, item, quantity, 0, 0, 0, 0, 0)
	assert_true(made.ok, "lot fixture")
	return made.ref


func _output_bytes() -> PackedByteArray:
	"""Snapshot every output field, including deliberately wrong lengths."""
	var data: PackedByteArray = PackedByteArray()
	for field: StringName in FIELDS:
		data.append_array(var_to_bytes(_target.get(field)))
	return data


func _private_bytes() -> PackedByteArray:
	"""Include noncanonical scratch, journals and flags that state_bytes omits."""
	var data: PackedByteArray = PackedByteArray()
	for property: Dictionary in _inv.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = _inv.get(property.name)
		if value is Object:
			if property.name in ["_math", "_plan"]:
				for child: Dictionary in value.get_property_list():
					if (int(child.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
						data.append_array(var_to_bytes(value.get(child.name)))
			else:
				data.append_array(var_to_bytes(value.get_instance_id()))
		else:
			data.append_array(var_to_bytes(value))
	return data


func _assert_refusal(error: String) -> void:
	"""All failure paths must preserve source and caller output, including diagnostics."""
	var before: PackedByteArray = _inv.state_bytes()
	var private_before: PackedByteArray = _private_bytes()
	var output_before: PackedByteArray = _output_bytes()
	_out.succeed(888)
	assert_false(_inv.copy_stock_counts_into(_target, _out), "refuses " + error)
	assert_false(_out.ok, "out.ok cleared")
	assert_equal(_out.value, 0, "stale success cleared")
	assert_equal(_out.error, error, "exact refusal")
	assert_equal(_output_bytes(), output_before, "no partial output")
	assert_equal(_inv.state_bytes(), before, "no source mutation")
	assert_equal(_private_bytes(), private_before, "no scratch, guard or journal mutation")


func _assert_totals(item: int, live: int, loose: int, equipped: int, available: int) -> void:
	"""Expected numbers are literal fixture outcomes, not recomputed from source columns."""
	assert_equal(_target.live_milli[item], live, "live")
	assert_equal(_target.loose_milli[item], loose, "loose")
	assert_equal(_target.equipped_milli[item], equipped, "equipped")
	assert_equal(_target.unreserved_loose_milli[item], available, "unreserved loose")
	assert_equal(_target.live_milli[item], _target.loose_milli[item] +
		_target.equipped_milli[item], "no double count")


func test_empty_record_sizes_and_payload() -> void:
	"""Actual array extents measure the cold record's 8192-byte packed payload."""
	assert_true(_inv.copy_stock_counts_into(_target, _out), "empty snapshot succeeds")
	assert_equal(_out.value, 0, "zero live lots")
	var bytes: int = 0
	for field: StringName in FIELDS:
		var array: PackedInt64Array = _target.get(field)
		assert_equal(array.size(), 256, "full compiled item domain")
		bytes += array.to_byte_array().size()
		for quantity: int in array:
			assert_equal(quantity, 0, "zero initialized")
	assert_equal(bytes, 8192, "measured packed payload")


func test_multiple_stores_reservations_and_owner_read_only() -> void:
	"""Whole-store totals include separated containers and leave scratch untouched."""
	var one: Vector2i = _container()
	var two: Vector2i = _container()
	var lot: Vector2i = _lot(one, 0, 5000)
	_lot(two, 0, 7000)
	_lot(two, 255, 1234)
	assert_true(_inv.reserve_lot(lot, 1800).ok, "reserve some stock")
	var authority: UncalledAuthority = UncalledAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "bound hostile witness")
	var before: PackedByteArray = _inv.state_bytes()
	var scratch: PackedByteArray = _private_bytes()
	assert_true(_inv.copy_stock_counts_into(_target, _out), "snapshot")
	assert_equal(_out.value, 3, "three lots across two stores")
	_assert_totals(0, 12000, 12000, 0, 10200)
	_assert_totals(255, 1234, 1234, 0, 1234)
	assert_equal(authority.calls, 0, "no callback")
	assert_equal(_inv.state_bytes(), before, "source equal")
	assert_equal(_private_bytes(), scratch, "all owner diagnostics equal")


func test_shape_and_busy_refusals_have_defined_precedence() -> void:
	"""Malformed output wins before all owner busy states; each busy cause refuses alone."""
	assert_false(_inv.copy_stock_counts_into(null, _out), "null target")
	assert_equal(_out.error, "INV_STOCK_COUNTS_SHAPE", "null diagnostic")
	for field: StringName in FIELDS:
		var prior: PackedInt64Array = _target.get(field)
		_target.set(field, PackedInt64Array([123]))
		_inv.set("_attesting", true)
		_assert_refusal("INV_STOCK_COUNTS_SHAPE")
		_inv.set("_attesting", false)
		_target.set(field, prior)
	for field: StringName in [&"_tx_open", &"_tx_poisoned", &"_attesting", &"_j_count"]:
		var prior: Variant = _inv.get(field)
		_inv.set(field, 1 if field == &"_j_count" else true)
		_assert_refusal("INV_STOCK_COUNTS_BUSY")
		_inv.set(field, prior)


func test_real_open_and_poisoned_transactions_are_untouched() -> void:
	"""Use actual transaction machinery as well as the isolated guard injections."""
	var container: Vector2i = _container()
	assert_true(_inv.begin().ok, "begin")
	_lot(container, 0, 1000)
	_assert_refusal("INV_STOCK_COUNTS_BUSY")
	assert_false(_inv.create_lot(container, 0, -1, 0, 0, 0, 0, 0).ok, "poison")
	assert_true(_inv.is_transaction_poisoned(), "actual poisoned state")
	_assert_refusal("INV_STOCK_COUNTS_BUSY")
	_inv.abort()
	assert_true(_inv.copy_stock_counts_into(_target, _out), "after rollback")
	assert_equal(_out.value, 0, "highwater above empty live count is valid")


func test_malformed_live_rows_refuse_without_partial_output() -> void:
	"""Exercise each unsafe indexing/domain boundary independently of arithmetic."""
	var lot: Vector2i = _lot(_container(), 0, 1000)
	var faults: Array = [
		["_l_live", 2], ["_l_item_id", -1], ["_l_item_id", 256],
		["_l_item_id", 1], ["_l_generation", 0], ["_l_quantity_milli", 0],
		["_l_quantity_milli", -1], ["_l_reserved_milli", -1],
		["_l_reserved_milli", 1001], ["_l_container_slot", -2],
		["_l_container_slot", 8], ["_l_container_generation", 0]]
	for fault: Array in faults:
		var column: Variant = _inv.get(fault[0])
		var prior: int = column[lot.x]
		column[lot.x] = fault[1]
		_inv.set(fault[0], column)
		_assert_refusal("INV_STOCK_COUNTS_STATE")
		column[lot.x] = prior
		_inv.set(fault[0], column)
	for bound: int in [-1, 17]:
		_inv.set("_l_slot_high_water", bound)
		_assert_refusal("INV_STOCK_COUNTS_STATE")
	_inv.set("_l_slot_high_water", 1)


func test_structural_equipment_counts_do_not_claim_cross_owner_validation() -> void:
	"""A locally valid detached row is counted without invoking any authority."""
	var lot: Vector2i = _lot(_container(), 0, 1000)
	for field: StringName in [&"_l_container_slot", &"_l_next", &"_l_prev"]:
		_inv.get(field)[lot.x] = -1
	_inv.get("_l_container_generation")[lot.x] = 0
	assert_true(_inv.copy_stock_counts_into(_target, _out), "local structural count")
	_assert_totals(0, 1000, 0, 1000, 0)
	for field: StringName in [&"_l_container_generation", &"_l_reserved_milli",
			&"_l_next", &"_l_prev"]:
		var prior: int = _inv.get(field)[lot.x]
		_inv.get(field)[lot.x] = 1
		_assert_refusal("INV_STOCK_COUNTS_STATE")
		_inv.get(field)[lot.x] = prior


func test_checked_sum_boundary_overflow_and_row_precedence() -> void:
	"""Inject quantities beyond physical capacity to reach i64 arithmetic independently."""
	var container: Vector2i = _container()
	var first: Vector2i = _lot(container, 0, 1000)
	var second: Vector2i = _lot(container, 0, 1)
	var third: Vector2i = _lot(container, 255, 1)
	_inv.get("_l_quantity_milli")[first.x] = MAX_I64 - 1
	assert_true(_inv.copy_stock_counts_into(_target, _out), "exact maximum representable")
	_assert_totals(0, MAX_I64, MAX_I64, 0, MAX_I64)
	_inv.get("_l_quantity_milli")[second.x] = 2
	_assert_refusal("INV_STOCK_COUNTS_OVERFLOW")
	_inv.get("_l_item_id")[third.x] = -1
	_assert_refusal("INV_STOCK_COUNTS_OVERFLOW")
	_inv.get("_l_quantity_milli")[second.x] = 1
	_assert_refusal("INV_STOCK_COUNTS_STATE")


func test_retired_reused_rows_and_different_allocation_orders() -> void:
	"""Free residue is ignored; reused generation and physical order do not duplicate stock."""
	var container: Vector2i = _container()
	var retired: Vector2i = _lot(container, 0, 777)
	assert_true(_inv.sink_lot_quantity(retired, 777).ok, "retire")
	_inv.get("_l_item_id")[retired.x] = -99
	_inv.get("_l_quantity_milli")[retired.x] = MAX_I64
	assert_true(_inv.copy_stock_counts_into(_target, _out), "free garbage ignored")
	_assert_totals(0, 0, 0, 0, 0)
	var reused: Vector2i = _lot(container, 255, 2000)
	assert_equal(reused.x, retired.x, "same physical slot")
	assert_true(reused.y != retired.y, "different generation")
	_lot(container, 0, 3000)
	assert_true(_inv.copy_stock_counts_into(_target, _out), "first arrangement")
	var expected: PackedByteArray = _output_bytes()
	_inv.clear()
	assert_true(_inv.register_item(0, 1, 0).ok, "re-register")
	assert_true(_inv.register_item(255, 1, 0).ok, "re-register last")
	container = _container()
	_lot(container, 0, 3000)
	_lot(container, 255, 2000)
	assert_true(_inv.copy_stock_counts_into(_target, _out), "reversed arrangement")
	assert_equal(_output_bytes(), expected, "allocation-independent totals")


func test_reused_and_aliased_outputs_publish_independent_new_snapshots() -> void:
	"""Replacing fields preserves held old values and repairs caller field aliasing."""
	var lot: Vector2i = _lot(_container(), 0, 1000)
	assert_true(_inv.reserve_lot(lot, 400).ok, "partial reservation")
	assert_true(_inv.copy_stock_counts_into(_target, _out), "initial result")
	var held: PackedInt64Array = _target.live_milli
	_target.loose_milli = held
	_target.equipped_milli = held
	_target.unreserved_loose_milli = held
	assert_true(_inv.copy_stock_counts_into(_target, _out), "aliased fields supported")
	_assert_totals(0, 1000, 1000, 0, 600)
	_target.equipped_milli[0] = 88
	assert_equal(_target.live_milli[0], 1000, "outputs independent")
	assert_true(_inv.release_reservation(lot, 400).ok, "release")
	assert_true(_inv.sink_lot_quantity(lot, 1000).ok, "empty")
	assert_true(_inv.copy_stock_counts_into(_target, _out), "replace prior populated target")
	_assert_totals(0, 0, 0, 0, 0)
	assert_equal(held[0], 1000, "retained old array remains old snapshot")


func test_actual_attestation_reentry_refuses_without_lowering_guard() -> void:
	"""The primitive does not open a nested callback or disturb the active guard."""
	_lot(_container(), 0, 1000)
	var authority: ReentrantAuthority = ReentrantAuthority.new()
	authority.borrowed = weakref(_inv)
	assert_true(_inv.set_equipment_authority(authority).ok, "bind")
	assert_true(_inv.audit().ok, "outer audit remains valid")
	assert_true(authority.refused, "nested read refuses and guard stays raised")
	assert_equal(authority.error, "INV_STOCK_COUNTS_BUSY", "reentry diagnostic")
	assert_false(bool(_inv.get("_attesting")), "outer authority releases its own guard")


func test_real_gear_equip_destroy_empty_store_and_unequip() -> void:
	"""One actual tool remains counted exactly once as physical ownership changes."""
	_inv = Inventory.new(8, 16)
	var definitions: Definitions = Definitions.new()
	assert_true(definitions.load_default(_inv).ok, "real catalog")
	var gear: Gear = Gear.new(16)
	var residents: Residents = Residents.new()
	assert_true(gear.bind_equipment(_inv, residents.directory(), residents).ok, "real binding")
	var owner: Vector2i = residents.spawn(&"mouse").ref
	var container: Vector2i = _container()
	var item: int = definitions.compiled_id(&"tool")
	var tool: Vector2i = _lot(container, item, 1000)
	assert_true(gear.create_gear(_inv, definitions, tool, Gear.MANUFACTURE_BASIC).ok, "gear row")
	assert_true(_inv.copy_stock_counts_into(_target, _out), "stored tool")
	_assert_totals(item, 1000, 1000, 0, 1000)
	assert_true(gear.equip(tool, owner).ok, "equip same lot")
	assert_true(_inv.destroy_container(container).ok, "destroy empty former container")
	var gear_before: PackedByteArray = gear.state_bytes()
	assert_true(_inv.copy_stock_counts_into(_target, _out), "equipped without old container")
	_assert_totals(item, 1000, 0, 1000, 0)
	assert_equal(_out.value, 1, "one lot")
	assert_equal(gear.state_bytes(), gear_before, "gear untouched by snapshot")
	assert_true(gear.unequip(tool, _container(), false).ok, "return same lot to new store")
	assert_true(_inv.copy_stock_counts_into(_target, _out), "returned tool")
	_assert_totals(item, 1000, 1000, 0, 1000)
	assert_equal(_inv.live_lot_count(), 1, "no duplicate tool")
	assert_true(_inv.set_equipment_authority(null).ok, "release test binding cycle")
