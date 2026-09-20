extends "res://test/framework/test_case.gd"
## Independent exact-owner and single-block tests for SAVE-AGE-R01v2.
const Age := preload("res://scripts/core/stock_age.gd")
const Adapter := preload("res://scripts/core/save_stock_age_restore.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Inv := preload("res://scripts/core/inventory.gd")
const Defs := preload("res://scripts/core/item_definitions.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
var _inv: Inv
var _defs: Defs
var _age: Age
var _columns: Age.CanonicalColumns
var _clock: Clock

func before_each() -> void:
	_inv = Inv.new(8,16)
	_defs = Defs.new()
	assert_true(_defs.load_default(_inv).ok,"actual catalog")
	_age = Age.new(_inv,_defs)
	_columns = Age.CanonicalColumns.new()
	_clock = Clock.new()
	assert_true(_clock.acquire_load_barrier().is_ok(),"held clock")

func _fields(object: Object, exclude: Array[String] = []) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for field: Dictionary in object.get_property_list():
		if (int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or exclude.has(String(field.name)):
			continue
		var value: Variant = object.get(field.name)
		if not value is Object:
			bytes.append_array(var_to_bytes(value))
	return bytes

func _owner_image() -> PackedByteArray:
	var bytes: PackedByteArray = _fields(_age,["_last_column_refusal"])
	bytes.append_array(_fields(_age.get("_math")))
	bytes.append_array(_fields(_age.get("_calendar")))
	return bytes

func _block() -> Codec.OwnerRecord:
	return Codec.OwnerRecord.new(5,101376,PackedInt64Array())

func _container(kind: int = 3, heated: bool = false) -> Vector2i:
	var made = _inv.create_container(Vector2i(9,1),100000000,Inv.FILTERS_ACCEPT_ALL,0,true)
	assert_true(made.ok,"container")
	assert_true(_age.declare_storage_class(made.ref,kind,heated),"declared")
	return made.ref

func _reject_restore(code: StringName) -> void:
	var bound_inventory = _age.inventory()
	var bound_definitions = _age.item_definitions()
	var before: PackedByteArray = _owner_image()
	var source: PackedByteArray = _fields(_columns)
	var inv_before: PackedByteArray = _inv.state_bytes()
	assert_false(_age.restore_stock_age_columns(_columns),"restore refused")
	assert_equal(_age.last_column_refusal(),code,"owner code")
	assert_equal(_age.canonical_detail(),String(code),"detail matches code")
	assert_equal(_owner_image(),before,"owner and scratch unchanged")
	assert_equal(_fields(_columns),source,"input unchanged")
	assert_equal(_inv.state_bytes(),inv_before,"borrowed inventory unchanged")
	assert_true(_age.inventory() == bound_inventory,"borrowed inventory identity")
	assert_true(_age.item_definitions() == bound_definitions,"borrowed catalog identity")

func _reject_capture(code: StringName) -> void:
	var bound_inventory = _age.inventory()
	var bound_definitions = _age.item_definitions()
	var before: PackedByteArray = _owner_image()
	var target: PackedByteArray = _fields(_columns)
	assert_false(_age.copy_stock_age_columns_into(_columns),"capture refused")
	assert_equal(_age.last_column_refusal(),code,"capture code")
	assert_equal(_owner_image(),before,"source unchanged")
	assert_true(_age.inventory() == bound_inventory,"source inventory identity")
	assert_true(_age.item_definitions() == bound_definitions,"source catalog identity")
	assert_equal(_fields(_columns),target,"output unchanged")

func test_empty_columns_and_all_classes_roundtrip_exactly() -> void:
	assert_true(_age.copy_stock_age_columns_into(_columns),"empty copy")
	assert_equal(_columns.container_capacity,101376,"compiled capacity")
	assert_equal(_columns.declared_count,0,"empty count")
	assert_equal(_columns.last_hour_tick,-1,"never run")
	assert_equal(_columns.declared_slots.count(-1),101376,"canonical tail")
	for kind: int in [1,2,3,4]:
		_container(kind,kind % 2 == 0)
	assert_true(_age.copy_stock_age_columns_into(_columns),"four kinds")
	var saved: PackedByteArray = _fields(_columns)
	var restored: Age = Age.new(_inv,_defs)
	assert_true(restored.restore_stock_age_columns(_columns),"restore")
	var back: Age.CanonicalColumns = Age.CanonicalColumns.new()
	assert_true(restored.copy_stock_age_columns_into(back),"recapture")
	assert_equal(_fields(back),saved,"all fields exact")

func test_shape_binding_and_busy_precedence() -> void:
	assert_false(_age.copy_stock_age_columns_into(null),"null target")
	assert_equal(_age.last_column_refusal(),&"COLUMN_STOCK_AGE_SHAPE","shape code")
	assert_false(_age.restore_stock_age_columns(null),"null source")
	_columns.container_capacity = 8
	_reject_restore(&"COLUMN_STOCK_AGE_SHAPE")
	_columns = Age.CanonicalColumns.new()
	_columns.c_storage_class.resize(1)
	_reject_capture(&"COLUMN_STOCK_AGE_SHAPE")
	_columns = Age.CanonicalColumns.new()
	_age = Age.new()
	_reject_capture(&"COLUMN_STOCK_AGE_BINDING")
	_reject_restore(&"COLUMN_STOCK_AGE_BINDING")
	_age = Age.new(_inv,Defs.new())
	_reject_restore(&"COLUMN_STOCK_AGE_BINDING")
	_age = Age.new(_inv,_defs)
	_inv.begin()
	_reject_capture(&"COLUMN_STOCK_AGE_BUSY")
	_reject_restore(&"COLUMN_STOCK_AGE_BUSY")
	_inv.abort()
	_inv.set("_tx_poisoned",true)
	_reject_capture(&"COLUMN_STOCK_AGE_BUSY")
	_reject_restore(&"COLUMN_STOCK_AGE_BUSY")
	_inv.set("_tx_poisoned",false)

func test_native_scalar_domains_refuse_before_narrowing() -> void:
	for count: int in [-1,101377,4294967296]:
		_columns.declared_count = count
		_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
		_age.set("_declared_count",count)
		_reject_capture(&"COLUMN_STOCK_AGE_RECORD")
		_age.set("_declared_count",0)
	_columns.declared_count = 0
	_columns.last_hour_tick = -2
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	for tick: int in [-1,0,751,9223372036854775807]:
		_columns.last_hour_tick = tick
		assert_true(_age.restore_stock_age_columns(_columns),"existing structural latch domain")
		assert_equal(_age.last_hour_tick(),tick,"no alignment repair")

func test_row_and_list_corruption_refuses_atomically() -> void:
	_columns.c_storage_class[0] = 5
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.c_storage_class[0] = 0
	_columns.c_heated_interior[0] = 2
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.c_heated_interior[0] = 1
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.c_heated_interior[0] = 0
	_columns.c_declared_generation[0] = -1
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.c_declared_generation[0] = 1
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.c_storage_class[0] = 3
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.declared_count = 1
	for slot: int in [-1,101376,1]:
		_columns.declared_slots[0] = slot
		_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.declared_slots[0] = 0
	_columns.declared_count = 2
	_columns.declared_slots[1] = 0
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.declared_count = 1
	_columns.declared_slots[1] = 7
	_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
	_columns.declared_slots[1] = -1
	assert_true(_age.restore_stock_age_columns(_columns),"valid baseline after corruptions")

func test_short_source_array_refuses_without_indexing() -> void:
	_container()
	_age.set("_declared_slots",PackedInt32Array())
	_reject_capture(&"COLUMN_STOCK_AGE_RECORD")

func test_restore_invalidates_exactly_two_caches_and_preserves_scratch() -> void:
	_container()
	assert_true(_age.copy_stock_age_columns_into(_columns),"capture")
	_age.set("_spoiled_food_id",77)
	_age.set("_compost_id",88)
	_age.set("_last_refusal",&"existing operation result")
	_age.set("_store_factor",123)
	_age.set("_temperature_factor",456)
	var excluded: Array[String] = ["_last_column_refusal","_spoiled_food_id","_compost_id"]
	var before: PackedByteArray = _fields(_age,excluded)
	var math: PackedByteArray = _fields(_age.get("_math"))
	var calendar: PackedByteArray = _fields(_age.get("_calendar"))
	assert_true(_age.restore_stock_age_columns(_columns),"restore")
	assert_equal(_age.get("_spoiled_food_id"),-1,"spoil cache invalidated")
	assert_equal(_age.get("_compost_id"),-1,"compost cache invalidated")
	assert_equal(_fields(_age,excluded),before,"all other values intact")
	assert_equal(_fields(_age.get("_math")),math,"math intact")
	assert_equal(_fields(_age.get("_calendar")),calendar,"calendar intact")
	assert_true(_age.inventory() == _inv,"same borrowed inventory")
	assert_true(_age.item_definitions() == _defs,"same borrowed catalog")

func test_full_capacity_and_export_restore_alias_independence() -> void:
	_columns.c_storage_class.fill(1)
	_columns.c_heated_interior = _columns.c_storage_class
	_columns.c_declared_generation.fill(1)
	_columns.declared_count = 101376
	for index: int in 101376:
		_columns.declared_slots[index] = index
	assert_true(_age.restore_stock_age_columns(_columns),"full compiled domain, world legality remains coordinator")
	_columns.c_storage_class[0] = 4
	assert_equal(_age.get("_c_storage_class")[0],1,"owner copied source")
	assert_true(_age.copy_stock_age_columns_into(_columns),"copy full")
	_columns.c_storage_class[0] = 3
	assert_equal(_columns.c_heated_interior[0],1,"aliased caller fields separated")
	assert_equal(_age.get("_c_storage_class")[0],1,"output independent of owner")
	var held: PackedByteArray = _columns.c_storage_class
	assert_true(_age.copy_stock_age_columns_into(_columns),"reuse")
	assert_equal(held[0],3,"old held array unchanged")
	assert_equal(_columns.c_storage_class[0],1,"new current snapshot")

func test_latch_and_stale_generation_continue_through_normal_hourly_path() -> void:
	var container: Vector2i = _container(4)
	var lot = _inv.create_lot(container,_defs.compiled_id(&"grain"),1000,0,0,0,0,0)
	assert_true(lot.ok,"grain")
	assert_true(_age.run_hour(750).ok,"first hour")
	assert_equal(_inv.lot_age_milli_hours(lot.ref),350,"cellar spring rate")
	assert_true(_age.copy_stock_age_columns_into(_columns),"latch capture")
	_age = Age.new(_inv,_defs)
	assert_true(_age.restore_stock_age_columns(_columns),"restore latch")
	assert_false(_age.run_hour(750).ok,"same hour cannot repeat")
	assert_true(_age.run_hour(1500).ok,"next hour")
	assert_equal(_inv.lot_age_milli_hours(lot.ref),700,"aged once more")
	var empty: Vector2i = _container(1)
	assert_true(_inv.destroy_container(empty).ok,"destroy empty declared container")
	var recycled = _inv.create_container(Vector2i(9,1),100000000,Inv.FILTERS_ACCEPT_ALL,0,true)
	assert_true(recycled.ok,"reuse destroyed slot")
	assert_equal(recycled.ref.x,empty.x,"same slot")
	assert_true(recycled.ref.y != empty.y,"new generation")
	assert_true(_age.copy_stock_age_columns_into(_columns),"stale reference captures")
	assert_true(_age.restore_stock_age_columns(_columns),"stale declaration survives")
	assert_equal(_age.declared_container_count(),2,"not repaired on load")
	assert_true(_age.run_hour(2250).ok,"normal sweep")
	assert_equal(_age.declared_container_count(),1,"normal sweep retires stale declaration")

func _order_world() -> Dictionary:
	var inv: Inv = Inv.new(8,16)
	var defs: Defs = Defs.new()
	assert_true(defs.load_default(inv).ok,"order world catalog")
	var age: Age = Age.new(inv,defs)
	var refs: Array[Vector2i] = []
	for i: int in 3:
		var c = inv.create_container(Vector2i(9,1),100000000,Inv.FILTERS_ACCEPT_ALL,0,true)
		assert_true(c.ok,"order container")
		refs.append(c.ref)
		assert_true(age.declare_storage_class(c.ref,1,false),"declared in order")
	assert_true(age.withdraw_storage_class(refs[0]),"swap leaves C,B")
	for i: int in [1,2]:
		assert_true(inv.create_lot(refs[i],defs.compiled_id(&"spoiled_food"),1000,0,0,0,240000,0).ok,"waste at expiry")
	return {"inv":inv,"defs":defs,"age":age,"refs":refs}

func _run_order(world: Dictionary) -> PackedInt32Array:
	assert_true(world.age.run_hour(750).ok,"waste expiry")
	var slots: PackedInt32Array = PackedInt32Array()
	for i: int in [1,2]:
		var lot = world.inv.create_lot(world.refs[i],world.defs.compiled_id(&"wood"),1000,0,0,0,0,0)
		assert_true(lot.ok,"allocate after retirement")
		slots.append(lot.ref.x)
	return slots

func test_saved_declaration_order_preserves_next_lot_slots() -> void:
	var original: Dictionary = _order_world()
	var restored: Dictionary = _order_world()
	var sorted: Dictionary = _order_world()
	var block: Codec.OwnerRecord = _block()
	assert_true(Adapter.capture_into(original.age,block).is_ok(),"actual block capture")
	assert_equal(block.i32_column(5).slice(0,2),PackedInt32Array([2,1]),"exact nonascending order")
	restored.age = Age.new(restored.inv,restored.defs)
	assert_true(Adapter.apply(block,restored.age,_clock).is_ok(),"restore only StockAge")
	var rows: PackedInt32Array = sorted.age.get("_declared_slots")
	rows[0] = 1
	rows[1] = 2
	sorted.age.set("_declared_slots",rows)
	assert_equal(_run_order(original),PackedInt32Array([0,1]),"uninterrupted")
	assert_equal(_run_order(restored),PackedInt32Array([0,1]),"restored")
	assert_equal(_run_order(sorted),PackedInt32Array([1,0]),"wrong sorting demonstrably changes IDs")

func _reject_block(block: Codec.OwnerRecord, code: StringName) -> void:
	var bound_inventory = _age.inventory()
	var bound_definitions = _age.item_definitions()
	var before: PackedByteArray = _owner_image()
	var input: PackedByteArray = _fields(block)
	var clock_before: PackedByteArray = _fields(_clock)
	var inventory_before: PackedByteArray = _inv.state_bytes()
	var refusal = Adapter.apply(block,_age,_clock)
	assert_equal(refusal.code,code,"adapter refusal")
	assert_equal(_owner_image(),before,"owner failure atomic")
	assert_true(_age.inventory() == bound_inventory,"apply inventory identity")
	assert_true(_age.item_definitions() == bound_definitions,"apply catalog identity")
	assert_equal(_fields(block),input,"block input unchanged")
	assert_equal(_fields(_clock),clock_before,"clock untouched")
	assert_equal(_inv.state_bytes(),inventory_before,"inventory untouched")

func test_adapter_null_barrier_and_shape_precedence_is_total() -> void:
	var block: Codec.OwnerRecord = _block()
	assert_equal(Adapter.capture_into(null,null).code,&"SAVE_AGE_NULL_STORE","capture null store first")
	assert_equal(Adapter.capture_into(_age,null).code,&"SAVE_AGE_BLOCK_SHAPE","null target")
	assert_equal(Adapter.apply(null,null).code,&"SAVE_AGE_BLOCK_SHAPE","apply null block first")
	assert_equal(Adapter.apply(block,null).code,&"SAVE_AGE_NULL_STORE","then store")
	block.u8_columns.clear()
	assert_equal(Adapter.apply(block,_age).code,&"SAVE_AGE_NULL_CLOCK","then clock")
	assert_equal(Adapter.apply(block,_age,Clock.new()).code,&"SAVE_AGE_BARRIER_NOT_HELD","then barrier")
	_reject_block(block,&"SAVE_AGE_BLOCK_SHAPE")
	for variant: int in 12:
		block = _block()
		match variant:
			0: block.owner = 4
			1: block.primary_count = 8
			2: block.child_extents.append(1)
			3: block.u8_columns.resize(1)
			4: block.i32_columns.resize(1)
			5: block.i64_columns.resize(1)
			6: block.u8_columns[0].resize(0)
			7: block.u8_columns[1].resize(101375)
			8: block.i32_columns[0].resize(0)
			9: block.i32_columns[1].resize(101377)
			10: block.i64_columns[0].resize(0)
			11: block.i64_columns[1].resize(2)
		_reject_block(block,&"SAVE_AGE_BLOCK_SHAPE")
		var target: PackedByteArray = _fields(block)
		assert_equal(Adapter.capture_into(_age,block).code,&"SAVE_AGE_BLOCK_SHAPE","capture also total")
		assert_equal(_fields(block),target,"bad output shape unchanged")

func test_adapter_semantics_and_owner_tail_failure_are_distinct() -> void:
	var block: Codec.OwnerRecord = _block()
	_age.set("_last_column_refusal",&"old column result")
	block.u8_columns[0][0] = 5
	var expected = Codec.owner_refusal(block)
	assert_false(expected.is_ok(),"codec rejects class")
	_reject_block(block,expected.code)
	assert_equal(_age.last_column_refusal(),&"old column result","codec gate preserves owner diagnostic")
	block.u8_columns[0][0] = 0
	block.i32_columns[1][101375] = 7
	assert_true(Codec.owner_refusal(block).is_ok(),"codec ignores unwritten list tail")
	_reject_block(block,&"COLUMN_STOCK_AGE_RECORD")
	assert_equal(_age.last_column_refusal(),&"COLUMN_STOCK_AGE_RECORD","owner gate checks fixed backing tail")
	block.i32_columns[1][101375] = -1
	_inv.begin()
	_reject_block(block,&"COLUMN_STOCK_AGE_BUSY")
	var target: PackedByteArray = _fields(block)
	assert_equal(Adapter.capture_into(_age,block).code,&"COLUMN_STOCK_AGE_BUSY","capture busy forwarded")
	assert_equal(_fields(block),target,"failed capture leaves target")
	_inv.abort()
	assert_true(Adapter.capture_into(_age,block).is_ok(),"successful capture clears only column result")
	assert_equal(_age.last_column_refusal(),&"","cleared")

func test_adapter_all_ordinals_and_buffers_are_independent() -> void:
	_container(4,true)
	_container(2,false)
	_age.set("_last_hour_tick",751)
	var block: Codec.OwnerRecord = _block()
	block.u8_columns[0].fill(255)
	var held: PackedByteArray = block.u8_columns[0]
	assert_true(Adapter.capture_into(_age,block).is_ok(),"overwrite semantic garbage in shaped target")
	assert_equal(held[0],255,"previous target buffer not written")
	assert_equal(block.owner,5,"owner metadata preserved")
	assert_equal(block.primary_count,101376,"extent metadata preserved")
	assert_true(block.child_extents.is_empty(),"child metadata preserved")
	assert_true(Adapter.block_shape_refusal(block).is_ok(),"public shape gate accepts")
	assert_false(_age.has_method("copy_canonical_columns_into"),"cannot duck-type as Inventory capture")
	assert_false(_age.has_method("restore_canonical_columns"),"cannot duck-type as Inventory restore")
	var owner_source: String = FileAccess.get_file_as_string("res://scripts/core/stock_age.gd")
	assert_false(owner_source.contains("preload(\"res://scripts/core/save_"),"owner has no codec preload")
	assert_equal(Codec.field_count_of(5),6,"six declared fields")
	assert_equal(Codec.OWNER_SCHEMA_VERSIONS[5],1,"golden owner schema")
	assert_equal(Codec.TYPES_STOCK_AGE,[Codec.TYPE_U32,Codec.TYPE_I64,Codec.TYPE_U8,Codec.TYPE_U8,Codec.TYPE_I32,Codec.TYPE_I32],"registry wire types")
	assert_equal(Codec.EXTENTS_STOCK_AGE,[Codec.EXT_SCALAR,Codec.EXT_SCALAR,Codec.EXT_PRIMARY,Codec.EXT_PRIMARY,Codec.EXT_PRIMARY,Codec.EXT_PRIMARY],"registry wire extents")
	assert_equal(Codec.KEYS_STOCK_AGE,[&"_declared_count",&"_last_hour_tick",&"_c_storage_class",&"_c_heated_interior",&"_c_declared_generation",&"_declared_slots"],"all registry ordinals")
	assert_equal(block.scalar(0),2,"count ordinal")
	assert_equal(block.scalar(1),751,"latch ordinal")
	assert_equal(block.u8_column(2).slice(0,2),PackedByteArray([4,2]),"class ordinal")
	assert_equal(block.u8_column(3).slice(0,2),PackedByteArray([1,0]),"heat ordinal")
	assert_equal(block.i32_column(4).slice(0,2),PackedInt32Array([1,1]),"generation ordinal")
	assert_equal(block.i32_column(5).slice(0,2),PackedInt32Array([0,1]),"list ordinal")
	var restored: Age = Age.new(_inv,_defs)
	assert_true(Adapter.apply(block,restored,_clock).is_ok(),"apply exact block")
	block.u8_columns[0][0] = 3
	assert_equal(restored.get("_c_storage_class")[0],4,"restore detached from block")
	assert_equal(_age.get("_c_storage_class")[0],4,"capture detached from source")

func test_adapter_wire_golden_for_empty_sparse_and_full_blocks() -> void:
	const Bytes := preload("res://scripts/core/save_codec.gd")
	var hashes: Array[String] = ["6ec7c25d59a51247a094f2a3a423367b0d863472e751d84ec395cf6a9b07014d","cfef4369913c488e6899245b247fe6da1d1873b8b7ce95d68e7f7ce047b69f65","3368160919921ec83a7c2c0306eb4cb1bcc04c397ad0e01ff8e98225de7217c0","3fc25ff6d2e5c25238a9a2c5f911e007bb9e0f1f857de5126905154c1a13ab6d"]
	var case_index: int = 0
	for count: int in [0,1,2,101376]:
		_columns = Age.CanonicalColumns.new()
		_columns.declared_count = count
		for index: int in count:
			var slot: int = (2-index) if count == 2 else index
			_columns.c_storage_class[slot] = 3
			_columns.c_declared_generation[slot] = 1
			_columns.declared_slots[index] = slot
		assert_true(_age.restore_stock_age_columns(_columns),"golden owner")
		var block: Codec.OwnerRecord = _block()
		assert_true(Adapter.capture_into(_age,block).is_ok(),"golden capture")
		var writer: Bytes.Writer = Bytes.Writer.new(33)
		writer.write_utf8_u32("stock_age",256)
		writer.write_u32(1)
		writer.write_u64(101376)
		writer.write_u64(Codec.payload_bytes_of(block))
		var raw: PackedByteArray = writer.to_bytes()
		var child_count: Bytes.Writer = Bytes.Writer.new(4)
		child_count.write_u32(0)
		raw.append_array(child_count.to_bytes())
		for ordinal: int in 6:
			var n: int = Codec.persisted_count_of(block,ordinal)
			var prefix: Bytes.Writer = Bytes.Writer.new(8)
			prefix.write_u64(n)
			raw.append_array(prefix.to_bytes())
			raw.append_array(Codec.column_slice(block,ordinal,0,n))
		assert_equal(raw.size(),608353+4*count,"literal original owner block size")
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		assert_equal(hash.finish().hex_encode(),hashes[case_index],"literal pre-change block hash")
		case_index += 1

func test_owner_and_codec_adversarial_payload_parity() -> void:
	# Each valid case traverses capture, the existing codec gate and owner restore.
	# Each invalid case is rejected by both field validators; tail is separately tested.
	for variant: int in 13:
		var block: Codec.OwnerRecord = _block()
		_columns = Age.CanonicalColumns.new()
		_columns.c_storage_class[0] = 3
		_columns.c_declared_generation[0] = 1
		_columns.declared_slots[0] = 0
		_columns.declared_count = 1
		match variant:
			0: _columns.c_storage_class[0] = 5
			1: _columns.c_heated_interior[0] = 2
			2: _columns.c_declared_generation[0] = 0
			3: _columns.c_declared_generation[0] = -1
			4: _columns.c_heated_interior[1] = 1
			5: _columns.c_declared_generation[1] = 1
			6: _columns.last_hour_tick = -2
			7: _columns.declared_count = -1
			8: _columns.declared_count = 4294967296
			9: _columns.declared_slots[0] = 101376
			10: _columns.declared_slots[0] = -1
			11: _columns.declared_slots[0] = 1
			12: _columns.declared_count = 0
		block.i64_columns[0][0] = _columns.declared_count
		block.i64_columns[1][0] = _columns.last_hour_tick
		block.u8_columns[0] = _columns.c_storage_class
		block.u8_columns[1] = _columns.c_heated_interior
		block.i32_columns[0] = _columns.c_declared_generation
		block.i32_columns[1] = _columns.declared_slots
		assert_false(Codec.owner_refusal(block).is_ok(),"existing codec rejects variant %d" % variant)
		_reject_restore(&"COLUMN_STOCK_AGE_RECORD")
		_age.set("_c_storage_class",_columns.c_storage_class)
		_age.set("_c_heated_interior",_columns.c_heated_interior)
		_age.set("_c_declared_generation",_columns.c_declared_generation)
		_age.set("_declared_slots",_columns.declared_slots)
		_age.set("_declared_count",_columns.declared_count)
		_age.set("_last_hour_tick",_columns.last_hour_tick)
		_reject_capture(&"COLUMN_STOCK_AGE_RECORD")
		_age = Age.new(_inv,_defs)

func test_each_owner_column_shape_checked_before_indexing() -> void:
	for name: String in ["c_storage_class","c_heated_interior","c_declared_generation","declared_slots"]:
		_columns = Age.CanonicalColumns.new()
		var broken: Variant = _columns.get(name)
		broken.resize(0)
		_columns.set(name,broken)
		_reject_capture(&"COLUMN_STOCK_AGE_SHAPE")
		_reject_restore(&"COLUMN_STOCK_AGE_SHAPE")
		_columns = Age.CanonicalColumns.new()
		_age.set("_"+name,broken)
		_reject_capture(&"COLUMN_STOCK_AGE_RECORD")
		_age = Age.new(_inv,_defs)
