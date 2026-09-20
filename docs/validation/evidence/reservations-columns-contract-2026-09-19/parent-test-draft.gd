extends "res://test/framework/test_case.gd"
## Independent owner/adapter acceptance for SAVE-RES-R01.
const Reservations := preload("res://scripts/core/reservations.gd")
const Adapter := preload("res://scripts/core/save_reservations_restore.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Inv := preload("res://scripts/core/inventory.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
var _world: Dictionary
var _pool: Reservations
var _inv: Inv
var _columns: Reservations.ReservationColumns
var _clock: Clock

func before_each() -> void:
	_world = _make_world()
	_pool = _world.pool
	_inv = _world.inv
	_columns = Reservations.ReservationColumns.new(8,8,16)
	_clock = Clock.new()
	assert_true(_clock.acquire_load_barrier().is_ok(),"held barrier")

func _fields(object: Object, excluded: Array[String] = []) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for field: Dictionary in object.get_property_list():
		if (int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or excluded.has(String(field.name)):
			continue
		var value: Variant = object.get(field.name)
		if not value is Object:
			bytes.append_array(var_to_bytes(value))
	return bytes

func _pool_image() -> PackedByteArray:
	var bytes: PackedByteArray = _fields(_pool,["_last_column_refusal"])
	bytes.append_array(_fields(_pool.get("_math")))
	return bytes

func _make_world() -> Dictionary:
	var inv: Inv = Inv.new(4,16)
	assert_true(inv.register_item(0,1,0).ok,"test item")
	var container = inv.create_container(Vector2i(1,1),100000000,Inv.FILTERS_ACCEPT_ALL,0,true)
	assert_true(container.ok,"container")
	var lots: Array[Vector2i] = []
	for index: int in 6:
		var lot = inv.create_lot(container.ref,0,10000,0,0,0,0,0)
		assert_true(lot.ok,"lot")
		lots.append(lot.ref)
	var pool: Reservations = Reservations.new(8,8,16)
	var order: Array[int] = [5,1,4,0,3,2]
	for index: int in 6:
		var job: Vector2i = Vector2i(3 if index % 2 == 0 else 1,1)
		var lot: Vector2i = lots[order[index]]
		assert_true(_claim(pool,inv,job,lot,index-3,100,100+index).ok,"claim")
	assert_true(pool.audit(inv).ok,"fixture invariant")
	return {"pool":pool,"inv":inv,"lots":lots,"container":container.ref}

func _claim(pool: Reservations, inv: Inv, job: Vector2i, lot: Vector2i,
		purpose: int, quantity: int, expiry: int):
	return pool.claim_batch(job,PackedInt64Array([lot.x,lot.y,purpose,quantity,expiry]),1,inv)

func _reject_restore(code: StringName) -> void:
	var before: PackedByteArray = _pool_image()
	var input: PackedByteArray = _fields(_columns)
	var inv_before: PackedByteArray = _inv.state_bytes()
	assert_false(_pool.restore_reservation_columns(_columns),"refused restore")
	assert_equal(_pool.last_column_refusal(),code,"specific refusal")
	assert_equal(_pool.canonical_detail(),String(code),"detail")
	assert_equal(_pool_image(),before,"all owner value/scratch fields untouched")
	assert_equal(_fields(_columns),input,"caller record untouched")
	assert_equal(_inv.state_bytes(),inv_before,"Inventory untouched")

func _reject_capture(code: StringName) -> void:
	var before: PackedByteArray = _pool_image()
	var output: PackedByteArray = _fields(_columns)
	assert_false(_pool.copy_reservation_columns_into(_columns),"refused capture")
	assert_equal(_pool.last_column_refusal(),code,"capture refusal")
	assert_equal(_pool_image(),before,"source unchanged")
	assert_equal(_fields(_columns),output,"output unchanged")

func _job_rows(pool: Reservations, job: Vector2i) -> PackedInt32Array:
	var rows: PackedInt32Array = PackedInt32Array()
	var row: int = pool.first_job_row(job)
	while row != -1 and rows.size() <= pool.row_capacity():
		rows.append(row)
		row = pool.next_job_row(row)
	return rows

func test_exact_rows_rebuild_semantic_chains_without_compaction() -> void:
	assert_true(_pool.release_claim(Vector2i(1,1),_world.lots[1],-2,_inv).ok,"hole at row1")
	assert_true(_pool.copy_reservation_columns_into(_columns),"capture")
	var restored: Reservations = Reservations.new(8,8,16)
	assert_true(restored.restore_reservation_columns(_columns),"restore")
	assert_equal(restored.state_bytes(),_pool.state_bytes(),"same claims")
	assert_equal(_job_rows(restored,Vector2i(3,1)),PackedInt32Array([4,2,0]),"semantic lot order differs from row order")
	assert_false(restored.is_row_active(1),"hole stays at exact row")
	assert_equal(restored.row_lot_ref(0),_world.lots[5],"row0 stays row0")
	assert_true(restored.audit(_inv).ok,"rebuilt indexes and Inventory totals")
	assert_equal(restored.free_row_count(),3,"derived free count")
	assert_true(_claim(restored,_inv,Vector2i(2,1),_world.lots[1],123,10,200).ok,"allocate after restore")
	assert_true(restored.is_row_active(1),"lowest free row reused")
	assert_equal(restored.row_job_ref(1),Vector2i(2,1),"new claim owns exact row")

func test_all_column_shapes_and_extent_metadata_refuse_atomically() -> void:
	assert_false(_pool.copy_reservation_columns_into(null),"null target")
	assert_false(_pool.restore_reservation_columns(null),"null input")
	for field: String in ["row_capacity","job_capacity","lot_capacity"]:
		_columns = Reservations.ReservationColumns.new(8,8,16)
		_columns.set(field,0)
		_reject_capture(&"COLUMN_RESERVATION_SHAPE")
		_reject_restore(&"COLUMN_RESERVATION_SHAPE")
	for field: String in ["occupied","r_job_slot","r_job_generation","r_lot_slot","r_lot_generation","r_purpose","r_quantity_milli","r_expiry"]:
		_columns = Reservations.ReservationColumns.new(8,8,16)
		var array: Variant = _columns.get(field)
		array.resize(0)
		_columns.set(field,array)
		_reject_capture(&"COLUMN_RESERVATION_SHAPE")
		_reject_restore(&"COLUMN_RESERVATION_SHAPE")
	_columns = Reservations.ReservationColumns.new(4294967296,8,16)
	assert_equal(_columns.row_capacity,4294967296,"metadata not narrowed or clamped")
	assert_equal(_columns.occupied.size(),32768,"allocation bounded")
	_reject_restore(&"COLUMN_RESERVATION_SHAPE")

func test_inactive_residue_and_occupancy_refuse_without_repair() -> void:
	_columns.occupied[0] = 2
	_reject_restore(&"COLUMN_RESERVATION_OCCUPANCY")
	_columns.occupied[0] = 0
	for field: String in ["r_job_slot","r_job_generation","r_lot_slot","r_lot_generation","r_purpose","r_quantity_milli","r_expiry"]:
		_columns = Reservations.ReservationColumns.new(8,8,16)
		var array: Variant = _columns.get(field)
		array[0] = 7
		_columns.set(field,array)
		_reject_restore(&"COLUMN_RESERVATION_BLANK")

func test_live_reference_quantity_and_expiry_domains() -> void:
	assert_true(_pool.copy_reservation_columns_into(_columns),"baseline")
	for field: String in ["r_job_slot","r_lot_slot","r_job_generation","r_lot_generation"]:
		var original: Variant = _columns.get(field).duplicate()
		var array: Variant = original.duplicate()
		array[0] = -1 if field.ends_with("slot") else 0
		_columns.set(field,array)
		_reject_restore(&"COLUMN_RESERVATION_REF")
		_columns.set(field,original)
	_columns.r_job_slot[0] = 8
	_reject_restore(&"COLUMN_RESERVATION_REF")
	_columns.r_job_slot[0] = 3
	_columns.r_lot_slot[0] = 16
	_reject_restore(&"COLUMN_RESERVATION_REF")
	_columns.r_lot_slot[0] = 5
	for quantity: int in [0,-1]:
		_columns.r_quantity_milli[0] = quantity
		_reject_restore(&"COLUMN_RESERVATION_QUANTITY")
	_columns.r_quantity_milli[0] = 100
	_columns.r_expiry[0] = -1
	_reject_restore(&"COLUMN_RESERVATION_EXPIRY")
	_columns.r_expiry[0] = 0
	_columns.r_purpose[0] = -2147483648
	_columns.r_purpose[2] = 2147483647
	assert_true(_pool.restore_reservation_columns(_columns),"expired0 and signed purposes preserved")

func test_source_derived_corruption_is_refused_without_traversal_or_repair() -> void:
	for field: String in ["_job_head","_lot_head","_job_prev","_job_next","_lot_prev","_lot_next","_free_heap"]:
		_world = _make_world()
		_pool = _world.pool
		_inv = _world.inv
		var array: PackedInt32Array = _pool.get(field)
		array[0] = 2147483647
		_pool.set(field,array)
		_reject_capture(&"COLUMN_RESERVATION_SOURCE_DERIVED")
	for field: String in ["_active_count","_free_count"]:
		_world = _make_world()
		_pool = _world.pool
		_inv = _world.inv
		_pool.set(field,4294967296)
		_reject_capture(&"COLUMN_RESERVATION_SOURCE_DERIVED")

func _two_rows() -> Reservations.ReservationColumns:
	var columns: Reservations.ReservationColumns = Reservations.ReservationColumns.new(8,8,16)
	for row: int in 2:
		columns.occupied[row] = 1
		columns.r_job_slot[row] = 1
		columns.r_job_generation[row] = 1
		columns.r_lot_slot[row] = 0
		columns.r_lot_generation[row] = 1
		columns.r_purpose[row] = row
		columns.r_quantity_milli[row] = 1
		columns.r_expiry[row] = 0
	return columns

func test_cross_row_conflicts_and_lot_overflow_refuse_but_job_wide_set_survives() -> void:
	_columns = _two_rows()
	_columns.r_purpose[1] = 0
	_reject_restore(&"COLUMN_RESERVATION_DUPLICATE")
	_columns = _two_rows()
	_columns.r_job_generation[1] = 2
	_reject_restore(&"COLUMN_RESERVATION_JOB_GENERATION")
	_columns = _two_rows()
	_columns.r_lot_generation[1] = 2
	_reject_restore(&"COLUMN_RESERVATION_LOT_GENERATION")
	_columns = _two_rows()
	_columns.r_quantity_milli[0] = 9223372036854775807
	_reject_restore(&"COLUMN_RESERVATION_OVERFLOW")
	_columns.r_lot_slot[1] = 1
	_columns.r_quantity_milli[0] = 6000000000000000000
	_columns.r_quantity_milli[1] = 6000000000000000000
	assert_true(_pool.restore_reservation_columns(_columns),"publicly admitted cross-lot set is not narrowed")
	assert_true(_pool.copy_reservation_columns_into(_columns),"such state remains capturable")
	assert_equal(_columns.r_quantity_milli[1],6000000000000000000,"exact i64 quantity")

func test_valid_nonascending_heap_and_stale_tail_are_accepted() -> void:
	_pool = Reservations.new(8,8,16)
	_pool.set("_free_heap",PackedInt32Array([0,2,1,3,4,5,6,7]))
	var before: PackedByteArray = _pool_image()
	assert_true(_pool.copy_reservation_columns_into(_columns),"valid nonascending heap")
	assert_equal(_pool_image(),before,"capture does not normalize source heap")
	assert_true(_pool.restore_reservation_columns(_columns),"restore chooses valid ascending heap")
	assert_equal(_pool.get("_free_heap"),PackedInt32Array([0,1,2,3,4,5,6,7]),"rebuilt free set")
	_pool = _world.pool
	var heap: PackedInt32Array = _pool.get("_free_heap")
	heap[7] = heap[0]
	_pool.set("_free_heap",heap)
	assert_true(_pool.copy_reservation_columns_into(_columns),"unused duplicate tail is residue")
	heap[1] = heap[0]
	_pool.set("_free_heap",heap)
	_reject_capture(&"COLUMN_RESERVATION_SOURCE_DERIVED")

func test_restore_replaces_bad_old_payload_and_preserves_scratch() -> void:
	assert_true(_pool.copy_reservation_columns_into(_columns),"valid source")
	var occupancy: PackedByteArray = _pool.get("_occupied")
	occupancy[0] = 2
	_pool.set("_occupied",occupancy)
	var heads: PackedInt32Array = _pool.get("_job_head")
	heads[0] = 2147483647
	_pool.set("_job_head",heads)
	_pool.set("_pending_new_rows",77)
	_pool.get("_math").value = 123
	var math_before: PackedByteArray = _fields(_pool.get("_math"))
	assert_true(_pool.restore_reservation_columns(_columns),"old payload and indexes need not validate")
	assert_equal(_pool.get("_pending_new_rows"),77,"old call scratch retained")
	assert_equal(_fields(_pool.get("_math")),math_before,"math untouched")
	assert_true(_pool.audit(_inv).ok,"healthy replacement")
	var result = _claim(_pool,_inv,Vector2i(2,1),_world.lots[0],123,10,200)
	assert_true(result.ok,"next real claim succeeds")
	assert_equal(result.value,1,"fresh-row count recomputed, not stale77")

func test_exports_and_restores_separate_caller_buffer_aliases() -> void:
	_columns.r_job_generation = _columns.r_lot_generation
	var old: PackedInt32Array = _columns.r_job_generation
	assert_true(_pool.copy_reservation_columns_into(_columns),"capture overwrites alias safely")
	_columns.r_job_generation[0] = 7
	assert_equal(_columns.r_lot_generation[0],1,"output fields detached")
	assert_equal(_pool.row_job_ref(0).y,1,"owner independent")
	assert_equal(old[0],0,"old output retained unchanged")
	_columns.r_job_generation[0] = 1
	assert_true(_pool.restore_reservation_columns(_columns),"restore")
	_columns.r_quantity_milli[0] = 42
	assert_equal(_pool.row_quantity_milli(0),100,"owner detached from record")

func test_real_coalesce_renew_expire_and_release_continue_after_restore() -> void:
	var other: Dictionary = _make_world()
	assert_true(_pool.copy_reservation_columns_into(_columns),"snapshot")
	other.pool = Reservations.new(8,8,16)
	assert_true(other.pool.restore_reservation_columns(_columns),"new pool receives only reservation state")
	for world: Dictionary in [_world,other]:
		var coalesced = _claim(world.pool,world.inv,Vector2i(3,1),world.lots[5],-3,50,200)
		assert_true(coalesced.ok,"coalesce existing restored row")
		assert_equal(coalesced.value,0,"no new row consumed")
		assert_false(world.pool.renew_claim(Vector2i(3,1),world.lots[5],-3,199).ok,"not later expiry refused")
		assert_true(world.pool.renew_claim(Vector2i(3,1),world.lots[5],-3,201).ok,"renew")
		assert_equal(world.pool.release_expired_for_job(Vector2i(3,1),104,world.inv).value,2,"expire only due rows")
		assert_equal(world.pool.release_lot_claims(world.lots[5],world.inv).value,1,"lot release")
		assert_equal(world.pool.release_job_claims(Vector2i(1,1),world.inv).value,3,"job release")
		assert_true(world.pool.audit(world.inv).ok,"public invariant after continuation")
	assert_equal(other.pool.state_bytes(),_pool.state_bytes(),"same reservation result")
	assert_equal(other.inv.state_bytes(),_inv.state_bytes(),"same Inventory effects")

func _block(rows: int = 8) -> Codec.OwnerRecord:
	return Codec.OwnerRecord.new(4,rows,PackedInt64Array())

func test_adapter_null_shape_barrier_and_busy_precedence() -> void:
	var block: Codec.OwnerRecord = _block()
	assert_equal(Adapter.capture_into(null,null).code,&"SAVE_RES_NULL_STORE","capture store first")
	assert_equal(Adapter.capture_into(_pool,null).code,&"SAVE_RES_BLOCK_SHAPE","then target shape")
	assert_equal(Adapter.capture_into(_pool,block).code,&"SAVE_RES_NULL_INVENTORY","mandatory Inventory")
	assert_equal(Adapter.apply(null,null).code,&"SAVE_RES_BLOCK_SHAPE","apply null block first")
	assert_equal(Adapter.apply(block,null).code,&"SAVE_RES_NULL_STORE","then store")
	block.u8_columns.clear()
	assert_equal(Adapter.apply(block,_pool).code,&"SAVE_RES_NULL_CLOCK","then clock")
	assert_equal(Adapter.apply(block,_pool,Clock.new()).code,&"SAVE_RES_BARRIER_NOT_HELD","then barrier")
	assert_equal(Adapter.apply(block,_pool,_clock).code,&"SAVE_RES_BLOCK_SHAPE","then full block shape")
	block = _block()
	assert_equal(Adapter.apply(block,_pool,_clock).code,&"SAVE_RES_NULL_INVENTORY","then Inventory")
	var inv_before: PackedByteArray = _inv.state_bytes()
	var clock_before: PackedByteArray = _fields(_clock)
	for poisoned: bool in [false,true]:
		if poisoned:
			_inv.set("_tx_poisoned",true)
		else:
			_inv.begin()
		var before: PackedByteArray = _pool_image()
		var output: PackedByteArray = _fields(block)
		assert_equal(Adapter.capture_into(_pool,block,_inv).code,&"SAVE_RES_BUSY","capture busy")
		assert_equal(Adapter.apply(block,_pool,_clock,_inv).code,&"SAVE_RES_BUSY","apply busy")
		assert_equal(_pool_image(),before,"busy leaves owner")
		assert_equal(_fields(block),output,"busy leaves block")
		if poisoned:
			_inv.set("_tx_poisoned",false)
		else:
			_inv.abort()
	assert_equal(_inv.state_bytes(),inv_before,"adapter never mutates Inventory")
	assert_equal(_fields(_clock),clock_before,"adapter never mutates clock")
	assert_true(_inv.has_method("is_transaction_open"),"actual public flag")
	assert_true(_inv.has_method("is_transaction_poisoned"),"actual public flag")

func test_every_adapter_block_shape_refuses_without_indexing() -> void:
	for variant: int in 15:
		var block: Codec.OwnerRecord = _block()
		match variant:
			0: block.owner = 5
			1: block.primary_count = 0
			2: block.primary_count = 32769
			3: block.child_extents.append(16)
			4: block.u8_columns.clear()
			5: block.i32_columns.resize(4)
			6: block.i64_columns.resize(1)
			7: block.u8_columns[0].resize(7)
			8: block.i32_columns[0].resize(0)
			9: block.i32_columns[1].resize(9)
			10: block.i32_columns[2].resize(0)
			11: block.i32_columns[3].resize(9)
			12: block.i32_columns[4].resize(0)
			13: block.i64_columns[0].resize(9)
			14: block.i64_columns[1].resize(0)
		var owner_before: PackedByteArray = _pool_image()
		var block_before: PackedByteArray = _fields(block)
		assert_equal(Adapter.block_shape_refusal(block).code,&"SAVE_RES_BLOCK_SHAPE","total public shape gate")
		assert_equal(Adapter.capture_into(_pool,block,_inv).code,&"SAVE_RES_BLOCK_SHAPE","capture shape")
		assert_equal(Adapter.apply(block,_pool,_clock,_inv).code,&"SAVE_RES_BLOCK_SHAPE","apply shape")
		assert_equal(_pool_image(),owner_before,"bad block leaves owner")
		assert_equal(_fields(block),block_before,"bad block unchanged")

func test_adapter_reduced_context_and_cross_row_asymmetry() -> void:
	var block: Codec.OwnerRecord = _block()
	assert_true(Adapter.capture_into(_pool,block,_inv).is_ok(),"capture")
	assert_equal(block.owner,4,"metadata owner")
	assert_equal(block.primary_count,8,"metadata R")
	assert_true(block.child_extents.is_empty(),"J/L not invented on wire")
	var reduced: Reservations = Reservations.new(8,2,16)
	assert_true(Codec.owner_refusal(block).is_ok(),"compiled bound accepts")
	assert_equal(Adapter.apply(block,reduced,_clock,_inv).code,&"COLUMN_RESERVATION_REF","actual target J refuses job3")
	reduced = Reservations.new(8,8,2)
	assert_equal(Adapter.apply(block,reduced,_clock,_inv).code,&"COLUMN_RESERVATION_REF","actual target L refuses lot5")
	assert_true(Adapter.apply(block,Reservations.new(8,8,16),_clock,_inv).is_ok(),"full context accepts identical block")
	block.i32_columns[1][2] = 2
	assert_true(Codec.owner_refusal(block).is_ok(),"codec does not prove job generation homogeneity")
	var before: PackedByteArray = _pool_image()
	assert_equal(Adapter.apply(block,_pool,_clock,_inv).code,&"COLUMN_RESERVATION_JOB_GENERATION","owner adds cross-row proof")
	assert_equal(_pool_image(),before,"owner refusal leaves state")

func test_generated_owner_admission_implies_codec_admission() -> void:
	for seed: int in 12:
		_columns = Reservations.ReservationColumns.new(8,8,16)
		for row: int in 8:
			if (row+seed) % 3 == 0:
				continue
			_columns.occupied[row] = 1
			_columns.r_job_slot[row] = (row+seed) % 8
			_columns.r_job_generation[row] = 1
			_columns.r_lot_slot[row] = (row*3+seed) % 16
			_columns.r_lot_generation[row] = 2
			_columns.r_purpose[row] = -2147483648+row
			_columns.r_quantity_milli[row] = row+1
			_columns.r_expiry[row] = 9223372036854775807-row
		assert_true(_pool.restore_reservation_columns(_columns),"generated owner accepts")
		var block: Codec.OwnerRecord = _block()
		assert_true(Adapter.capture_into(_pool,block,_inv).is_ok(),"adapter capture passes defensive gate")
		assert_true(Codec.owner_refusal(block).is_ok(),"owner admission subset of codec")

func test_full_capacity_reverse_keys_and_literal_wire_hashes() -> void:
	const Bytes := preload("res://scripts/core/save_codec.gd")
	var hashes: Array[String] = ["a623cbc40a1890197af25b3bf718e679edc4a604c9322c1267732fc45f23d140","347b6d9743756e07e9c0a171033e93022166dd63db395cb886ac452a711bb241","3798c5cf5b34163c1dfb4c9e7c1bd91c8159f72fd27ae23e4bc845a1c9cca898","a6e0867126e6273d4b1faffd5c379eb04740a1a8de8e2510e546569757195254"]
	assert_equal(Codec.OWNER_SCHEMA_VERSIONS[4],1,"literal framing schema")
	assert_equal(Codec.KEYS_RESERVATIONS,[&"_occupied",&"_r_job_slot",&"_r_job_generation",&"_r_lot_slot",&"_r_lot_generation",&"_r_purpose",&"_r_quantity_milli",&"_r_expiry"],"eight registry ordinals")
	assert_equal(Codec.TYPES_RESERVATIONS,[Codec.TYPE_U8,Codec.TYPE_I32,Codec.TYPE_I32,Codec.TYPE_I32,Codec.TYPE_I32,Codec.TYPE_I32,Codec.TYPE_I64,Codec.TYPE_I64],"wire types")
	for variant: int in 4:
		var rows: int = 8 if variant < 2 else 32768
		var pool: Reservations = Reservations.new(rows,8192,16384)
		var columns: Reservations.ReservationColumns = Reservations.ReservationColumns.new(rows,8192,16384)
		if variant == 1 or variant == 3:
			for row: int in rows:
				if variant == 1 and row != 2 and row != 5:
					continue
				columns.occupied[row] = 1
				columns.r_job_slot[row] = 1
				columns.r_job_generation[row] = 2
				columns.r_lot_slot[row] = 0
				columns.r_lot_generation[row] = 3
				columns.r_purpose[row] = -2147483648+rows-row
				columns.r_quantity_milli[row] = row+1
				columns.r_expiry[row] = row
		assert_true(pool.restore_reservation_columns(columns),"bounded reverse-key restore")
		if variant == 3:
			var chain: PackedInt32Array = _job_rows(pool,Vector2i(1,2))
			assert_equal(chain.size(),32768,"all maximum rows indexed")
			assert_equal(chain[0],32767,"semantic order reverses row order")
			assert_equal(chain[-1],0,"last semantic row")
		var block: Codec.OwnerRecord = _block(rows)
		assert_true(Adapter.capture_into(pool,block,_inv).is_ok(),"capture maximum no full section allocation")
		var writer: Bytes.Writer = Bytes.Writer.new(40)
		writer.write_utf8_u32("reservations",256)
		writer.write_u32(1)
		writer.write_u64(rows)
		writer.write_u64(Codec.payload_bytes_of(block))
		writer.write_u32(0)
		var raw: PackedByteArray = writer.to_bytes()
		for ordinal: int in 8:
			var prefix: Bytes.Writer = Bytes.Writer.new(8)
			prefix.write_u64(rows)
			raw.append_array(prefix.to_bytes())
			raw.append_array(Codec.column_slice(block,ordinal,0,rows))
		assert_equal(raw.size(),104+37*rows,"literal size")
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		assert_equal(hash.finish().hex_encode(),hashes[variant],"unchanged preimplementation block hash")

func test_corrupt_live_payload_refuses_before_export() -> void:
	var codes: Array[StringName] = [&"COLUMN_RESERVATION_OCCUPANCY",&"COLUMN_RESERVATION_BLANK",&"COLUMN_RESERVATION_REF",&"COLUMN_RESERVATION_QUANTITY",&"COLUMN_RESERVATION_EXPIRY",&"COLUMN_RESERVATION_JOB_GENERATION",&"COLUMN_RESERVATION_DUPLICATE"]
	for variant: int in codes.size():
		_world = _make_world()
		_pool = _world.pool
		_inv = _world.inv
		assert_true(_pool.copy_reservation_columns_into(_columns),"valid capture before injection")
		match variant:
			0: _columns.occupied[0] = 2
			1: _columns.r_job_slot[7] = 7
			2: _columns.r_job_slot[0] = 8
			3: _columns.r_quantity_milli[0] = 0
			4: _columns.r_expiry[0] = -1
			5: _columns.r_job_generation[2] = 2
			6:
				_columns.r_lot_slot[2] = _columns.r_lot_slot[0]
				_columns.r_purpose[2] = _columns.r_purpose[0]
		for field: String in ["occupied","r_job_slot","r_job_generation","r_lot_slot","r_lot_generation","r_purpose","r_quantity_milli","r_expiry"]:
			_pool.set("_"+field,_columns.get(field))
		_reject_capture(codes[variant])

func test_adapter_overwrites_target_payload_and_preserves_old_buffers() -> void:
	var block: Codec.OwnerRecord = _block()
	block.u8_columns[0].fill(255)
	var held: PackedByteArray = block.u8_columns[0]
	var inv_before: PackedByteArray = _inv.state_bytes()
	assert_true(Adapter.capture_into(_pool,block,_inv).is_ok(),"shaped output may contain semantic garbage")
	assert_equal(held[0],255,"old output buffer untouched")
	assert_equal(block.u8_columns[0][0],1,"current output replaced")
	block.i64_columns[0][0] = 999
	assert_equal(_pool.row_quantity_milli(0),100,"output independent from source")
	assert_true(Adapter.capture_into(_pool,block,_inv).is_ok(),"recapture")
	var restored: Reservations = Reservations.new(8,8,16)
	assert_true(Adapter.apply(block,restored,_clock,_inv).is_ok(),"restore")
	block.i64_columns[0][0] = 888
	assert_equal(restored.row_quantity_milli(0),100,"restored owner independent from input")
	assert_equal(_inv.state_bytes(),inv_before,"capture/apply do not touch reserved totals")
	assert_false(_pool.has_method("copy_canonical_columns_into"),"no Inventory duck type")
	assert_false(_pool.has_method("restore_canonical_columns"),"no Inventory restore duck type")
	var source: String = FileAccess.get_file_as_string("res://scripts/core/reservations.gd")
	assert_false(source.contains("preload(\"res://scripts/core/save_"),"no owner-to-codec edge")
