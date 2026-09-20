extends "res://test/framework/test_case.gd"
const Reservations := preload("res://scripts/core/reservations.gd")
const Inv := preload("res://scripts/core/inventory.gd")
const Math := preload("res://scripts/core/int_math.gd")
var _pool: Reservations
var _inv: Inv
var _lots: Array[Vector2i]

func before_each() -> void:
	_build(6000000000000000000,6000000000000000000)

func _build(first: int, second: int) -> void:
	_pool = Reservations.new(4,4,4)
	_inv = Inv.new(2,4)
	_lots = []
	assert_true(_inv.register_item(0,1,0).ok,"first mass1 item")
	assert_true(_inv.register_item(1,1,0).ok,"second mass1 item")
	var container = _inv.create_container(Vector2i(1,1),9223372036854775807,Inv.FILTERS_ACCEPT_ALL,0,true)
	assert_true(container.ok,"large capacity")
	for item: int in 2:
		var quantity: int = first if item == 0 else second
		var lot = _inv.create_lot(container.ref,item,quantity,0,0,0,0,0)
		assert_true(lot.ok,"real Inventory lot")
		_lots.append(lot.ref)
		var claimed = _pool.claim_batch(Vector2i(1,1),PackedInt64Array([lot.ref.x,lot.ref.y,item,quantity,100]),1,_inv)
		assert_true(claimed.ok,"real claim remains admitted")
	assert_true(_pool.audit(_inv).ok,"per-lot invariant holds")
	assert_true(_inv.audit().ok,"Inventory invariant holds")

func _fields(object: Object) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for field: Dictionary in object.get_property_list():
		if (int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = object.get(field.name)
		if not value is Object:
			bytes.append_array(var_to_bytes(value))
	return bytes

func _image() -> PackedByteArray:
	var bytes: PackedByteArray = _fields(_pool)
	bytes.append_array(_fields(_pool.get("_math")))
	return bytes

func _assert_refused(out: Math.IntResult) -> void:
	assert_false(out.ok,"explicit failure")
	assert_equal(out.value,0,"no partial total")
	assert_true(not out.error.is_empty(),"explicit diagnostic")

func test_real_public_api_job_overflow_refuses_without_narrowing_claims() -> void:
	var out: Math.IntResult = Math.IntResult.new(true,77,"old")
	assert_false(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"12e18 exceeds i64")
	_assert_refused(out)
	var cold: Math.IntResult = _pool.job_reserved_total_milli(Vector2i(1,1))
	_assert_refused(cold)
	for lot: Vector2i in _lots:
		assert_true(_pool.lot_reserved_total_milli_into(lot,out),"individual lot fits")
		assert_equal(out.value,6000000000000000000,"exact individual quantity")
	assert_equal(_pool.active_row_count(),2,"claims preserved")
	assert_true(_pool.audit(_inv).ok,"overflowing job query does not invalidate world")
	assert_true(_pool.release_job_claims(Vector2i(1,1),_inv).ok,"row-count release still succeeds")
	assert_true(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"empty query succeeds")
	assert_equal(out.value,0,"empty value")

func test_exact_i64_max_and_ordinary_totals_have_no_false_overflow() -> void:
	_build(4611686018427387903,4611686018427387904)
	var out: Math.IntResult = Math.IntResult.new()
	assert_true(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"exact maximum")
	assert_equal(out.value,9223372036854775807,"maximum exact")
	assert_equal(out.error,"","success clears error")
	var cold: Math.IntResult = _pool.job_reserved_total_milli(Vector2i(1,1))
	assert_true(cold.ok,"cold maximum")
	assert_equal(cold.value,out.value,"same forms")
	_build(100,200)
	assert_true(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"ordinary")
	assert_equal(out.value,300,"ordinary total")
	for index: int in 2:
		cold = _pool.lot_reserved_total_milli(_lots[index])
		assert_true(cold.ok,"cold lot result")
		assert_equal(cold.value,100 if index == 0 else 200,"ordinary lot")

func test_reused_output_recovers_across_success_overflow_and_missing_refs() -> void:
	var out: Math.IntResult = Math.IntResult.new(false,999,"stale")
	assert_true(_pool.lot_reserved_total_milli_into(_lots[0],out),"success first")
	assert_false(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"then overflow")
	_assert_refused(out)
	for ref: Vector2i in [Vector2i(-1,0),Vector2i(4,1),Vector2i(0,1),Vector2i(1,2)]:
		out.refuse("old refusal")
		assert_true(_pool.job_reserved_total_milli_into(ref,out),"missing job is empty")
		assert_equal(out.value,0,"zero")
		assert_equal(out.error,"","cleared")
	for ref: Vector2i in [Vector2i(-1,0),Vector2i(4,1),Vector2i(3,1),Vector2i(_lots[0].x,2)]:
		out.refuse("old refusal")
		assert_true(_pool.lot_reserved_total_milli_into(ref,out),"missing lot is empty")
		assert_equal(out.value,0,"zero")
		assert_equal(out.error,"","cleared")

func test_public_queries_do_not_mutate_owner_math_or_inventory() -> void:
	_pool.get("_math").succeed(771)
	_pool.set("_pending_new_rows",55)
	var before: PackedByteArray = _image()
	var inv_before: PackedByteArray = _inv.state_bytes()
	var out: Math.IntResult = Math.IntResult.new()
	assert_false(_pool.job_reserved_total_milli_into(Vector2i(1,1),out),"hot overflow")
	_assert_refused(_pool.job_reserved_total_milli(Vector2i(1,1)))
	assert_true(_pool.lot_reserved_total_milli_into(_lots[0],out),"hot lot")
	assert_true(_pool.lot_reserved_total_milli(_lots[1]).ok,"cold lot")
	assert_equal(_image(),before,"all owner fields and scratch unchanged")
	assert_equal(_inv.state_bytes(),inv_before,"Inventory unchanged")

func test_null_output_refuses_before_list_access() -> void:
	var jobs: PackedInt32Array = _pool.get("_job_head")
	var lots: PackedInt32Array = _pool.get("_lot_head")
	jobs[1] = 2147483647
	lots[_lots[0].x] = 2147483647
	_pool.set("_job_head",jobs)
	_pool.set("_lot_head",lots)
	var before: PackedByteArray = _image()
	assert_false(_pool.job_reserved_total_milli_into(Vector2i(1,1),null),"null before malformed job index")
	assert_false(_pool.lot_reserved_total_milli_into(_lots[0],null),"null before malformed lot index")
	assert_equal(_image(),before,"null refuses without state write")

func test_cold_results_are_independent_and_outcome_is_not_a_sentinel() -> void:
	var first: Math.IntResult = _pool.lot_reserved_total_milli(_lots[0])
	var second: Math.IntResult = _pool.job_reserved_total_milli(Vector2i(1,1))
	assert_true(first != second,"one fresh result per cold call")
	assert_true(first.ok,"first remains success")
	assert_equal(first.value,6000000000000000000,"first remains exact")
	_assert_refused(second)
	var zero: Math.IntResult = _pool.job_reserved_total_milli(Vector2i(0,1))
	assert_true(zero.ok,"zero is a successful value")
	assert_equal(zero.value,0,"distinct from explicit overflow despite equal value field")

func test_checked_query_survives_exact_owner_snapshot_and_restoration() -> void:
	var columns: Reservations.ReservationColumns = Reservations.ReservationColumns.new(4,4,4)
	assert_true(_pool.copy_reservation_columns_into(columns),"cross-lot set remains capturable")
	var restored: Reservations = Reservations.new(4,4,4)
	assert_true(restored.restore_reservation_columns(columns),"exact restore")
	_assert_refused(restored.job_reserved_total_milli(Vector2i(1,1)))
	for lot: Vector2i in _lots:
		var total: Math.IntResult = restored.lot_reserved_total_milli(lot)
		assert_true(total.ok,"restored per-lot fits")
		assert_equal(total.value,6000000000000000000,"restored quantity exact")
	assert_equal(restored.state_bytes(),_pool.state_bytes(),"canonical claims unchanged")
	assert_true(restored.audit(_inv).ok,"same actual Inventory totals")

func test_audit_refuses_checked_per_lot_overflow_before_comparison() -> void:
	_build(1000,1000)
	assert_true(_pool.release_job_claims(Vector2i(1,1),_inv).ok,"clear fixture claims through API")
	for job: int in [1,2]:
		assert_true(_pool.claim_batch(Vector2i(job,1),PackedInt64Array([_lots[0].x,_lots[0].y,job,100,100]),1,_inv).ok,"two valid rows on one lot")
	var quantities: PackedInt64Array = _pool.get("_r_quantity_milli")
	var saved: PackedInt64Array = quantities.duplicate()
	quantities[0] = 9223372036854775807
	quantities[1] = 1
	_pool.set("_r_quantity_milli",quantities)
	var out: Math.IntResult = Math.IntResult.new()
	assert_false(_pool.lot_reserved_total_milli_into(_lots[0],out),"forged lot sum overflows")
	_assert_refused(out)
	var audit = _pool.audit(_inv)
	assert_false(audit.ok,"audit refuses")
	assert_equal(audit.error,&"OVERFLOW","overflow wins before reserved-total mismatch")
	_pool.set("_r_quantity_milli",saved)
	assert_true(_pool.audit(_inv).ok,"restore fixture integrity")
