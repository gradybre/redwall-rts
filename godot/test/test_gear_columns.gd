extends "res://test/framework/test_case.gd"
## Parent-authored SAVE-GEAR-R01 owner and adapter acceptance.
const Gear := preload("res://scripts/core/gear.gd")
const Adapter := preload("res://scripts/core/save_gear_restore.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Inv := preload("res://scripts/core/inventory.gd")
const Defs := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Math := preload("res://scripts/core/int_math.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const FIELDS: Array[String] = ["occupied","lot_slot","lot_generation","item_id","durability","durability_cap","owner_slot","owner_generation","manufacture_recipe","equipped","claim_job_slot","claim_job_generation"]
const CACHES: Array[String] = ["_id_tool","_id_net","_id_trap","_id_ice_kit","_id_outfit_tier2"]
var _store: Gear
var _inv: Inv
var _defs: Defs
var _columns: Gear.GearColumns
var _container: Vector2i
var _clock: Clock
var _residents: Residents

func before_each() -> void:
	_inv = Inv.new(8,256)
	_defs = Defs.new()
	assert_true(_defs.load_default(_inv).ok,"actual catalog loads")
	_store = Gear.new(8)
	_columns = Gear.GearColumns.new(8)
	var made = _inv.create_container(Vector2i(7,1),9000000000,Inv.FILTERS_ACCEPT_ALL,0,true)
	assert_true(made.ok,"container")
	_container = made.ref
	_residents = null
	_clock = Clock.new()
	assert_true(_clock.acquire_load_barrier().is_ok(),"held load barrier")

func after_each() -> void:
	# Fixture lifetime only: assertions above observe the world before disposal.
	if _inv != null and _inv.has_equipment_authority():
		_inv.abort()
		_inv.clear()
		assert_true(_inv.set_equipment_authority(null).ok,"fixture releases Inventory-Gear cycle")

func _collaborator_image() -> PackedByteArray:
	var bytes: PackedByteArray = _inv.state_bytes()
	bytes.append_array(_fields(_defs))
	if _residents != null:
		bytes.append_array(_residents.state_bytes())
		bytes.append_array(_residents.directory().state_bytes())
	return bytes

func _fields(object: Object, exclude: Array[String] = []) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for property: Dictionary in object.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or exclude.has(String(property.name)):
			continue
		var value: Variant = object.get(property.name)
		if not value is Object:
			bytes.append_array(var_to_bytes(value))
	return bytes

func _image(store: Gear = null) -> PackedByteArray:
	if store == null:
		store = _store
	var bytes: PackedByteArray = _fields(store,["_last_column_refusal"])
	bytes.append_array(_fields(store.get("_wear_math")))
	return bytes

func _make(key: StringName, manufacture: int = 0) -> Vector2i:
	var made = _inv.create_lot(_container,_defs.compiled_id(key),1000,0,0,0,0,0)
	assert_true(made.ok,"actual indivisible lot")
	assert_true(_store.create_gear(_inv,_defs,made.ref,manufacture).ok,"actual gear creation")
	return made.ref

func _capture() -> void:
	assert_true(_store.copy_gear_columns_into(_columns,_defs),"capture accepted")

func _reject_restore(code: StringName) -> void:
	var before: PackedByteArray = _image()
	var input: PackedByteArray = _fields(_columns)
	var inv_before: PackedByteArray = _collaborator_image()
	var bindings: Array = [_store.get("_inventory"),_store.get("_directory_binding"),_store.get("_residents")]
	assert_false(_store.restore_gear_columns(_columns,_defs),"restore refuses")
	assert_equal(_store.last_column_refusal(),code,"specific owner refusal")
	assert_equal(_store.canonical_detail(),String(code),"code detail")
	assert_equal(_image(),before,"all owner values and scratch unchanged")
	assert_equal(_fields(_columns),input,"input unchanged")
	assert_equal(_collaborator_image(),inv_before,"all collaborators unchanged")
	assert_equal([_store.get("_inventory"),_store.get("_directory_binding"),_store.get("_residents")],bindings,"same borrowed identities")

func _reject_capture(code: StringName) -> void:
	var before: PackedByteArray = _image()
	var output: PackedByteArray = _fields(_columns)
	var collaborators: PackedByteArray = _collaborator_image()
	var bindings: Array = [_store.get("_inventory"),_store.get("_directory_binding"),_store.get("_residents")]
	assert_false(_store.copy_gear_columns_into(_columns,_defs),"capture refuses")
	assert_equal(_store.last_column_refusal(),code,"specific capture refusal")
	assert_equal(_image(),before,"source unchanged")
	assert_equal(_fields(_columns),output,"output unchanged")
	assert_equal(_collaborator_image(),collaborators,"all collaborators unchanged")
	assert_equal([_store.get("_inventory"),_store.get("_directory_binding"),_store.get("_residents")],bindings,"same borrowed identities")

func _bind() -> void:
	_residents = Residents.new()
	assert_true(_store.bind_equipment(_inv,_residents.directory(),_residents).ok,"real collaborators bound")

func _block(rows: int = 8) -> Codec.OwnerRecord:
	return Codec.OwnerRecord.new(2,rows,PackedInt64Array())

func test_exact_payload_restores_without_compacting_rows() -> void:
	var tool: Vector2i = _make(&"tool",1)
	var net: Vector2i = _make(&"net")
	var trap: Vector2i = _make(&"trap")
	_make(&"ice_kit")
	_make(&"outfit_tier2")
	assert_true(_store.claim_for_job(net,Vector2i(3,1)).ok,"claim net")
	assert_true(_store.complete_cycle(net,Vector2i(3,1)).ok,"wear net")
	assert_true(_store.claim_for_job(tool,Vector2i(4,2)).ok,"claim general tool")
	assert_true(_inv.sink_lot_quantity(trap,1000).ok,"retire one lot")
	assert_true(_store.destroy_gear(_inv,_defs,trap).ok,"hole at row2")
	_capture()
	var restored: Gear = Gear.new(8)
	assert_true(restored.restore_gear_columns(_columns,_defs),"restore")
	for field: String in FIELDS:
		assert_equal(restored.get("_"+field),_store.get("_"+field),"exact "+field)
	assert_equal(restored.get("_occupied")[2],0,"hole preserved")
	assert_equal(restored.get("_free_heap")[0],2,"lowest free row rebuilt")
	assert_true(restored.audit().ok,"owner audit")
	assert_true(restored.is_claimed(tool),"claim retained")
	var out: Math.IntResult = Math.IntResult.new()
	assert_true(restored.durability_into(net,out),"net query")
	assert_equal(out.value,980,"wear retained")

func test_all_record_and_live_array_shapes_are_total() -> void:
	_make(&"tool")
	_capture()
	for field: String in FIELDS:
		var original: Variant = _columns.get(field)
		var short: Variant = original.duplicate()
		short.resize(7)
		_columns.set(field,short)
		_reject_restore(&"COLUMN_GEAR_SHAPE")
		_reject_capture(&"COLUMN_GEAR_SHAPE")
		_columns.set(field,original)
	for field: String in FIELDS + ["free_heap"]:
		var original: Variant = _store.get("_"+field)
		var short: Variant = original.duplicate()
		short.resize(7)
		_store.set("_"+field,short)
		_reject_restore(&"COLUMN_GEAR_SHAPE")
		_reject_capture(&"COLUMN_GEAR_SHAPE")
		_store.set("_"+field,original)
	for invalid: int in [-1,0,40000]:
		var bad: Gear.GearColumns = Gear.GearColumns.new(invalid)
		assert_equal(bad.row_capacity,invalid,"requested metadata preserved")
		assert_equal(bad.occupied.size(),clampi(invalid,1,16384),"bounded allocation")
		assert_false(_store.restore_gear_columns(bad,_defs),"bad metadata refuses")
		assert_equal(_store.last_column_refusal(),&"COLUMN_GEAR_SHAPE","shape first")
	for invalid: int in [-1,0,40000]:
		_store.set("_row_capacity",invalid)
		_reject_restore(&"COLUMN_GEAR_SHAPE")
		_reject_capture(&"COLUMN_GEAR_SHAPE")
	_store.set("_row_capacity",8)

func test_payload_flags_blanks_refs_and_wear_refuse_atomically() -> void:
	_make(&"tool")
	_capture()
	var cases: Array = [
		["occupied",0,2,&"COLUMN_GEAR_OCCUPANCY"],["equipped",0,2,&"COLUMN_GEAR_OCCUPANCY"],
		["item_id",1,0,&"COLUMN_GEAR_BLANK"],["lot_slot",0,-1,&"COLUMN_GEAR_REF"],
		["lot_slot",0,16384,&"COLUMN_GEAR_REF"],["lot_generation",0,0,&"COLUMN_GEAR_REF"],
		["owner_generation",0,7,&"COLUMN_GEAR_REF"],["owner_slot",0,352418,&"COLUMN_GEAR_REF"],
		["claim_job_generation",0,7,&"COLUMN_GEAR_REF"],["claim_job_slot",0,8192,&"COLUMN_GEAR_REF"],
		["item_id",0,-1,&"COLUMN_GEAR_ITEM"],["durability",0,-1,&"COLUMN_GEAR_DURABILITY"],
		["durability",0,1001,&"COLUMN_GEAR_DURABILITY"],["durability_cap",0,-1,&"COLUMN_GEAR_DURABILITY"],
		["manufacture_recipe",0,2,&"COLUMN_GEAR_MANUFACTURE"],["equipped",0,1,&"COLUMN_GEAR_REF"]]
	for item: Array in cases:
		var column: Variant = _columns.get(item[0])
		var saved: int = column[item[1]]
		column[item[1]] = item[2]
		_columns.set(item[0],column)
		_reject_restore(item[3])
		column[item[1]] = saved
		_columns.set(item[0],column)
	for field: String in FIELDS:
		if field == "occupied":
			continue
		var column: Variant = _columns.get(field)
		var saved: int = column[7]
		column[7] = 1 if field == "equipped" else saved+1
		_columns.set(field,column)
		_reject_restore(&"COLUMN_GEAR_BLANK")
		column[7] = saved
		_columns.set(field,column)

func test_duplicate_lot_slot_refuses_even_different_generation() -> void:
	_make(&"tool")
	_make(&"net")
	_capture()
	_columns.lot_slot[1] = _columns.lot_slot[0]
	for generation: int in [1,2]:
		_columns.lot_generation[1] = generation
		_reject_restore(&"COLUMN_GEAR_DUPLICATE_LOT")
	_store.set("_lot_slot",_columns.lot_slot.duplicate())
	_reject_capture(&"COLUMN_GEAR_DUPLICATE_LOT")

func test_structural_bounds_preserve_stale_and_unusual_values() -> void:
	_make(&"tool")
	_capture()
	_columns.lot_slot[0] = 16383
	_columns.lot_generation[0] = 2147483647
	_columns.owner_slot[0] = 352417
	_columns.owner_generation[0] = 2147483647
	_columns.claim_job_slot[0] = 8191
	_columns.claim_job_generation[0] = 2147483647
	_columns.item_id[0] = 2147483647
	_columns.durability[0] = 2147483647
	_columns.durability_cap[0] = 2147483647
	_columns.manufacture_recipe[0] = 1
	assert_true(_store.restore_gear_columns(_columns,_defs),"structural maximums, not world validity")
	_capture()
	assert_equal(_columns.item_id[0],2147483647,"no catalog clamp")
	_columns.durability[0] = 0
	_columns.durability_cap[0] = 0
	assert_true(_store.restore_gear_columns(_columns,_defs),"zero cap allowed structurally")

func test_source_heap_and_native_counts_validate_but_restore_rebuilds() -> void:
	_make(&"tool")
	_capture()
	for field: String in ["_free_count","_active_count","_equipped_count"]:
		var saved: int = _store.get(field)
		for value: int in [-1,9,2]:
			_store.set(field,value)
			_reject_capture(&"COLUMN_GEAR_SOURCE_DERIVED")
		_store.set(field,saved)
	var heap: PackedInt32Array = _store.get("_free_heap")
	for variant: int in 4:
		var bad: PackedInt32Array = heap.duplicate()
		if variant == 0:
			bad[0] = 8
		elif variant == 1:
			bad[0] = 0
		elif variant == 2:
			bad[1] = bad[2]
		else:
			var first: int = bad[0]
			bad[0] = bad[1]
			bad[1] = first
		_store.set("_free_heap",bad)
		_reject_capture(&"COLUMN_GEAR_SOURCE_DERIVED")
	_store.set("_free_heap",PackedInt32Array([1,3,2,7,4,5,6,2147483647]))
	_capture()
	_store.set("_free_count",-99)
	_store.set("_active_count",999)
	_store.set("_equipped_count",999)
	_store.set("_free_heap",PackedInt32Array([99,99,99,99,99,99,99,99]))
	_store.set("_lot_slot",PackedInt32Array([-9,-9,-9,-9,-9,-9,-9,-9]))
	assert_true(_store.restore_gear_columns(_columns,_defs),"restore ignores old contents")
	assert_equal(_store.get("_free_heap"),PackedInt32Array([1,2,3,4,5,6,7,-1]),"canonical heap")
	assert_equal(_store.active_gear_count(),1,"active count")
	assert_equal(_store.equipped_count(),0,"equipped count")

func test_cache_refresh_failure_atomicity_and_scratch_preservation() -> void:
	_make(&"tool")
	_capture()
	var staged_ids: PackedInt32Array = PackedInt32Array()
	for field: String in CACHES:
		staged_ids.append(_store.get(field))
		var saved: int = _store.get(field)
		_store.set(field,10000)
		_reject_capture(&"COLUMN_GEAR_SOURCE_CACHE")
		_store.set(field,saved)
	for field: String in CACHES:
		_store.set(field,-777)
	_store.set("_seed_count",24)
	_store.get("_wear_math").succeed(912)
	var seed_before: PackedByteArray = _fields(_store.get("_wear_math"))
	assert_true(_store.restore_gear_columns(_columns,_defs),"refresh IDs atomically")
	for index: int in 5:
		assert_equal(_store.get(CACHES[index]),staged_ids[index],"exact restored ID")
	assert_equal(_store.get("_seed_count"),24,"residue not busy")
	assert_equal(_fields(_store.get("_wear_math")),seed_before,"wear scratch preserved")
	_capture()
	var empty: Gear = Gear.new(8)
	assert_true(empty.copy_gear_columns_into(Gear.GearColumns.new(8),_defs),"cold empty all-1 cache legal")
	assert_true(empty.capture_item_ids(_defs).ok,"bind cache on empty")
	assert_true(empty.copy_gear_columns_into(Gear.GearColumns.new(8),_defs),"empty exact cache legal")
	empty.set("_id_tool",-777)
	assert_false(empty.copy_gear_columns_into(Gear.GearColumns.new(8),_defs),"mixed stale empty refuses")

func test_restore_window_and_definitions_refuse_without_mutation() -> void:
	_make(&"tool")
	_capture()
	var before: PackedByteArray = _image()
	assert_false(_store.restore_gear_columns(_columns,null),"missing definitions")
	assert_equal(_store.last_column_refusal(),&"COLUMN_GEAR_DEFINITIONS","specific missingdefs")
	assert_false(_store.restore_gear_columns(_columns,Defs.new()),"unloaded definitions")
	assert_false(_store.copy_gear_columns_into(_columns,null),"capture requires catalog")
	assert_equal(_image(),before,"no cache mutation")
	_store.set("_restoring",true)
	_reject_capture(&"COLUMN_GEAR_RESTORING")
	_reject_restore(&"COLUMN_GEAR_RESTORING")

func test_equipped_tool_survives_exact_restore_and_real_unequip() -> void:
	_bind()
	var resident = _residents.spawn(&"mouse")
	assert_true(resident.ok,"actual resident")
	var tool: Vector2i = _make(&"tool")
	assert_true(_store.equip(tool,resident.ref).ok,"actual equip updates all owners")
	_capture()
	var inv_before: PackedByteArray = _inv.state_bytes()
	var residents_before: PackedByteArray = _residents.state_bytes()
	var directory_before: PackedByteArray = _residents.directory().state_bytes()
	var unbound: Gear = Gear.new(8)
	var unbound_before: PackedByteArray = _image(unbound)
	assert_false(unbound.restore_gear_columns(_columns,_defs),"bind-before-load required")
	assert_equal(unbound.last_column_refusal(),&"COLUMN_GEAR_BINDING","missing binding")
	assert_equal(_image(unbound),unbound_before,"missing binding atomic")
	_store.clear()
	assert_true(_store.restore_gear_columns(_columns,_defs),"restore into already bound target")
	assert_equal(_store.equipped_count(),1,"count rebuilt")
	assert_true(_store.is_equipped_record(tool),"live attestation retained")
	assert_true(_store.audit().ok,"gear audit")
	assert_true(_store.audit_equipment_mirror().ok,"actual Equipment mirror")
	assert_true(_inv.audit().ok,"actual Inventory equipped invariant")
	assert_equal(_inv.state_bytes(),inv_before,"restore never rewrites Inventory")
	assert_equal(_residents.state_bytes(),residents_before,"restore never rewrites mirror")
	assert_equal(_residents.directory().state_bytes(),directory_before,"directory unchanged")
	assert_true(_store.get("_inventory") == _inv,"same borrowed Inventory")
	assert_true(_store.get("_directory_binding") == _residents.directory(),"same Directory")
	assert_true(_store.get("_residents") == _residents,"same Residents")
	assert_true(_store.unequip(tool,_container,false).ok,"future unequip")
	assert_true(_store.equip(tool,resident.ref).ok,"future equip")
	assert_true(_inv.audit().ok,"continuation invariant")

func test_stale_equipped_owner_is_preserved_but_world_audit_refuses() -> void:
	_bind()
	var resident = _residents.spawn(&"mouse")
	var tool: Vector2i = _make(&"tool")
	assert_true(_store.equip(tool,resident.ref).ok,"equip")
	assert_true(_residents.despawn(resident.ref).ok,"actual dead owner")
	_capture()
	assert_true(_store.restore_gear_columns(_columns,_defs),"structural stale handle preserved")
	assert_equal(_store.owner_of(tool),resident.ref,"no generation repair")
	assert_false(_store.is_equipped_record(tool),"not a live proof")
	assert_false(_inv.audit().ok,"full-world inconsistency remains explicit")

func test_completed_starter_seed_residue_does_not_block_capture() -> void:
	_store = Gear.new(64)
	_columns = Gear.GearColumns.new(64)
	_bind()
	var owners: Array[Vector2i] = []
	for index: int in 12:
		var spawned = _residents.spawn(&"mouse")
		assert_true(spawned.ok,"starter resident")
		owners.append(spawned.ref)
	assert_true(_store.seed_starter_tools(_defs,_container,owners,0,0).ok,"real completed seed")
	assert_equal(_store.get("_seed_count"),24,"real residue")
	var before: PackedByteArray = _image()
	_capture()
	assert_equal(_image(),before,"capture read only after completed seed")
	assert_true(_store.restore_gear_columns(_columns,_defs),"restore seed rows")
	assert_equal(_store.get("_seed_count"),24,"residue preserved")
	assert_equal(_store.equipped_count(),12,"12 equipped")
	assert_true(_store.audit_equipment_mirror().ok,"mirrors exact")
	assert_true(_inv.audit().ok,"inventory exact")

func _continue(restored: bool) -> PackedByteArray:
	var inventory: Inv = Inv.new(8,256)
	var definitions: Defs = Defs.new()
	assert_true(definitions.load_default(inventory).ok,"catalog")
	var store: Gear = Gear.new(8)
	var container = inventory.create_container(Vector2i(7,1),9000000000,Inv.FILTERS_ACCEPT_ALL,0,true)
	var refs: Array[Vector2i] = []
	for key: StringName in [&"tool",&"net",&"trap"]:
		var lot = inventory.create_lot(container.ref,definitions.compiled_id(key),1000,0,0,0,0,0)
		assert_true(lot.ok,"created lot")
		assert_true(store.create_gear(inventory,definitions,lot.ref,0).ok,"created gear")
		refs.append(lot.ref)
	assert_true(store.claim_for_job(refs[0],Vector2i(3,1)).ok,"general claim")
	var wear: Gear.WearOutcome = Gear.WearOutcome.new()
	assert_true(store.apply_general_wear_into(refs[0],Vector2i(3,1),5000,0,wear),"first half wear")
	var external_remainder: int = wear.remainder_after
	assert_equal(external_remainder,5000,"caller owns remainder")
	assert_true(store.claim_for_job(refs[0],Vector2i(4,1)).ok,"next general claim")
	assert_true(store.claim_for_job(refs[1],Vector2i(5,1)).ok,"fishing claim")
	assert_true(store.claim_for_job(refs[2],Vector2i(6,1)).ok,"cancel claim")
	if restored:
		var columns: Gear.GearColumns = Gear.GearColumns.new(8)
		assert_true(store.copy_gear_columns_into(columns,definitions),"continuation capture")
		store = Gear.new(8)
		assert_true(store.restore_gear_columns(columns,definitions),"continuation restore")
	assert_true(store.apply_general_wear_into(refs[0],Vector2i(4,1),5000,external_remainder,wear),"second half wear")
	assert_equal(wear.durability_after,999,"same wear point")
	assert_equal(wear.remainder_after,0,"same remainder")
	assert_equal(store.complete_cycle(refs[1],Vector2i(5,1)).value,20,"net wear")
	assert_true(store.cancel_claim(refs[2],Vector2i(6,1)).ok,"cancel trap")
	assert_true(store.repair(refs[1],7).ok,"partial repair")
	assert_true(inventory.sink_lot_quantity(refs[0],1000).ok,"retire tool")
	assert_true(store.destroy_gear(inventory,definitions,refs[0]).ok,"free lowest row")
	var new_lot = inventory.create_lot(container.ref,definitions.compiled_id(&"ice_kit"),1000,0,0,0,0,0)
	assert_true(store.create_gear(inventory,definitions,new_lot.ref,0).ok,"allocate lowest free")
	assert_equal(store.get("_lot_slot")[0],new_lot.ref.x,"same row allocation")
	assert_true(store.audit().ok,"continuation owner audit")
	assert_true(inventory.audit().ok,"continuation Inventory audit")
	var result: PackedByteArray = store.state_bytes()
	result.append_array(inventory.state_bytes())
	return result

func test_real_claim_wear_repair_and_allocator_continuation_match() -> void:
	assert_equal(_continue(true),_continue(false),"same future authoritative state")

func test_aliases_do_not_turn_publication_into_shared_mutable_state() -> void:
	_make(&"tool")
	_capture()
	var payload: PackedByteArray = _fields(_columns)
	var expected: PackedByteArray = _store.state_bytes()
	for field: String in FIELDS:
		_columns.set(field,_store.get("_"+field))
	assert_true(_store.restore_gear_columns(_columns,_defs),"input may alias current arrays")
	assert_equal(_store.state_bytes(),expected,"same source values")
	assert_equal(_fields(_columns),payload,"input unchanged")
	_columns.durability[0] = 17
	assert_equal(_store.get("_durability")[0],1000,"caller mutation cannot change owner")
	_capture()
	var durable: PackedInt32Array = _store.get("_durability")
	durable[0] = 19
	_store.set("_durability",durable)
	assert_equal(_columns.durability[0],1000,"owner mutation cannot change output")

func test_adapter_refusal_precedence_busy_and_bound_inventory_identity() -> void:
	var block: Codec.OwnerRecord = _block()
	assert_equal(Adapter.capture_into(null,null).code,&"SAVE_GEAR_NULL_STORE","store first")
	assert_equal(Adapter.capture_into(_store,null).code,&"SAVE_GEAR_BLOCK_SHAPE","then outputshape")
	assert_equal(Adapter.capture_into(_store,block).code,&"SAVE_GEAR_NULL_INVENTORY","Inventory first")
	assert_equal(Adapter.apply(null,null).code,&"SAVE_GEAR_BLOCK_SHAPE","nullblock first")
	assert_equal(Adapter.apply(block,null).code,&"SAVE_GEAR_NULL_STORE","then target")
	assert_equal(Adapter.apply(block,_store).code,&"SAVE_GEAR_NULL_CLOCK","then clock")
	assert_equal(Adapter.apply(block,_store,Clock.new()).code,&"SAVE_GEAR_BARRIER_NOT_HELD","held barrier")
	assert_equal(Adapter.apply(block,_store,_clock).code,&"SAVE_GEAR_NULL_INVENTORY","then Inventory")
	assert_equal(Adapter.capture_into(_store,block,null,_inv).code,&"COLUMN_GEAR_DEFINITIONS","owner definitions gate")
	_bind()
	var foreign: Inv = Inv.new(8,256)
	assert_equal(Adapter.capture_into(_store,block,_defs,foreign).code,&"SAVE_GEAR_INVENTORY_MISMATCH","bound foreign refuses")
	assert_equal(Adapter.apply(block,_store,_clock,_defs,foreign).code,&"SAVE_GEAR_INVENTORY_MISMATCH","apply foreign refuses")
	var inv_before: PackedByteArray = _inv.state_bytes()
	var clock_before: PackedByteArray = _fields(_clock)
	for poisoned: bool in [false,true]:
		if poisoned:
			_inv.set("_tx_poisoned",true)
		else:
			assert_true(_inv.begin().ok,"open transaction")
		var before: PackedByteArray = _image()
		var output: PackedByteArray = _fields(block)
		assert_equal(Adapter.capture_into(_store,block,_defs,_inv).code,&"SAVE_GEAR_BUSY","capture busy")
		assert_equal(Adapter.apply(block,_store,_clock,_defs,_inv).code,&"SAVE_GEAR_BUSY","apply busy")
		assert_equal(_image(),before,"no owner write")
		assert_equal(_fields(block),output,"no block write")
		if poisoned:
			_inv.set("_tx_poisoned",false)
		else:
			_inv.abort()
	assert_equal(_inv.state_bytes(),inv_before,"same Inventory")
	assert_equal(_fields(_clock),clock_before,"same held clock")

func test_adapter_all_group_shapes_refuse_before_indexing() -> void:
	for variant: int in 18:
		var block: Codec.OwnerRecord = _block()
		if variant == 0:
			block.owner = 3
		elif variant == 1:
			block.primary_count = 0
		elif variant == 2:
			block.child_extents = PackedInt64Array([1])
		elif variant == 3:
			block.u8_columns.clear()
		elif variant == 4:
			block.i32_columns.clear()
		elif variant == 5:
			block.i64_columns.append(PackedInt64Array())
		else:
			var ordinal: int = variant-6
			if ordinal == 0 or ordinal == 9:
				var position: int = 0 if ordinal == 0 else 1
				block.u8_columns[position] = PackedByteArray()
			else:
				var position: int = ordinal-1 if ordinal < 9 else ordinal-2
				block.i32_columns[position] = PackedInt32Array()
		var before: PackedByteArray = _image()
		var output: PackedByteArray = _fields(block)
		assert_equal(Adapter.block_shape_refusal(block).code,&"SAVE_GEAR_BLOCK_SHAPE","total shape")
		assert_equal(Adapter.capture_into(_store,block,_defs,_inv).code,&"SAVE_GEAR_BLOCK_SHAPE","capture shape")
		assert_equal(Adapter.apply(block,_store,_clock,_defs,_inv).code,&"SAVE_GEAR_BLOCK_SHAPE","apply shape")
		assert_equal(_image(),before,"owner unchanged")
		assert_equal(_fields(block),output,"block unchanged")

func test_codec_valid_ref_counterexamples_are_refused_without_repair() -> void:
	_make(&"tool")
	var block: Codec.OwnerRecord = _block()
	assert_true(Adapter.capture_into(_store,block,_defs,_inv).is_ok(),"block capture")
	var before: PackedByteArray = _image()
	for variant: int in 3:
		if variant == 0:
			block.set_i32_column(7,PackedInt32Array([7,0,0,0,0,0,0,0]))
		elif variant == 1:
			block.set_i32_column(7,PackedInt32Array([0,0,0,0,0,0,0,0]))
			block.set_i32_column(11,PackedInt32Array([7,0,0,0,0,0,0,0]))
		else:
			block.set_i32_column(10,PackedInt32Array([8192,-1,-1,-1,-1,-1,-1,-1]))
			block.set_i32_column(11,PackedInt32Array([1,0,0,0,0,0,0,0]))
		assert_true(Codec.owner_refusal(block).is_ok(),"explicit weaker codec witness")
		var bytes: PackedByteArray = _fields(block)
		assert_equal(Adapter.apply(block,_store,_clock,_defs,_inv).code,&"COLUMN_GEAR_REF","owner refusal forwarded")
		assert_equal(_image(),before,"no world mutation")
		assert_equal(_fields(block),bytes,"no input repair")

func test_adapter_success_uses_exact_ordinals_and_independent_arrays() -> void:
	_make(&"tool",1)
	_make(&"net")
	var block: Codec.OwnerRecord = _block()
	assert_true(Adapter.capture_into(_store,block,_defs,_inv).is_ok(),"capture")
	var before: PackedByteArray = _fields(block)
	var target: Gear = Gear.new(8)
	assert_true(Adapter.apply(block,target,_clock,_defs,_inv).is_ok(),"apply")
	for ordinal: int in 12:
		var expected: Variant = _store.get("_"+FIELDS[ordinal])
		assert_equal(target.get("_"+FIELDS[ordinal]),expected,"exact semantic field")
		var column: Variant = block.u8_column(ordinal) if ordinal == 0 or ordinal == 9 else block.i32_column(ordinal)
		assert_equal(column,expected,"literal ordinal "+str(ordinal))
	assert_equal(_fields(block),before,"input untouched")
	var recaptured: Codec.OwnerRecord = _block()
	assert_true(Adapter.capture_into(target,recaptured,_defs,_inv).is_ok(),"recapture")
	assert_equal(_fields(recaptured),before,"same block after restore")
	block.set_i32_column(4,PackedInt32Array([17,18,0,0,0,0,0,0]))
	assert_equal(target.get("_durability")[0],1500,"block mutation does not alias target")

func test_default_capacity_and_literal_wire_goldens() -> void:
	const Bytes := preload("res://scripts/core/save_codec.gd")
	var hashes: Array[String] = ["3546ebc737c5a32741292f1782cf59c5685b59e1cbf11d685f962bc6bfd0ddaf","f6d85dd23fe8f03cdf7da9faeed126d0ded46ae165302e0f8932de8001e8369b","3bd99b69091e0e55de02c0bbadeb79bfaf25b041ec23fdc58496e7679a83d530","5e95fc3984d87c115c318666d9b9403df3f33b9f7c5d95645156f4452d5c6d6a"]
	assert_equal(Codec.OWNER_SCHEMA_VERSIONS[2],1,"unchanged owner schema")
	assert_equal(Codec.KEYS_GEAR,[&"_occupied",&"_lot_slot",&"_lot_generation",&"_item_id",&"_durability",&"_durability_cap",&"_owner_slot",&"_owner_generation",&"_manufacture_recipe",&"_equipped",&"_claim_job_slot",&"_claim_job_generation"],"literal ordinals")
	for variant: int in 4:
		var rows: int = 8 if variant < 2 else 16384
		var store: Gear = Gear.new(rows)
		var columns: Gear.GearColumns = Gear.GearColumns.new(rows)
		if variant == 1 or variant == 3:
			for row: int in rows:
				if variant == 1 and row != 2 and row != 5:
					continue
				columns.occupied[row] = 1
				columns.lot_slot[row] = row
				columns.lot_generation[row] = 3
				columns.item_id[row] = 0
				columns.durability[row] = row%1001
				columns.durability_cap[row] = 1000
		assert_true(store.restore_gear_columns(columns,_defs),"bounded literal restore")
		var block: Codec.OwnerRecord = _block(rows)
		assert_true(Adapter.capture_into(store,block,_defs,_inv).is_ok(),"bounded block capture")
		var writer: Bytes.Writer = Bytes.Writer.new(32)
		writer.write_utf8_u32("gear",256)
		writer.write_u32(1)
		writer.write_u64(rows)
		writer.write_u64(Codec.payload_bytes_of(block))
		writer.write_u32(0)
		var raw: PackedByteArray = writer.to_bytes()
		for ordinal: int in 12:
			var prefix: Bytes.Writer = Bytes.Writer.new(8)
			prefix.write_u64(rows)
			raw.append_array(prefix.to_bytes())
			raw.append_array(Codec.column_slice(block,ordinal,0,rows))
		assert_equal(raw.size(),128+42*rows,"literal framed size")
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		assert_equal(hash.finish().hex_encode(),hashes[variant],"independent preimplementation golden")

func test_loaded_catalog_with_unresolved_gear_keys_is_legal() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Defs.DEFAULT_JSON_PATH))
	var filtered: Array = []
	for item: Dictionary in parsed.items:
		if not ["tool","net","trap","ice_kit","outfit_tier2"].has(item.id):
			filtered.append(item)
	parsed.items = filtered
	var path: String = "user://gear_columns_subset_%d.json" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	assert_true(file != null,"fixture file")
	if file == null:
		return
	file.store_string(JSON.stringify(parsed))
	file.close()
	var catalog: Defs = Defs.new()
	var inventory: Inv = Inv.new(4,16)
	var loaded = catalog.load_from_file(path,inventory)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true(loaded.ok,"actual catalog subset loads")
	for key: StringName in [&"tool",&"net",&"trap",&"ice_kit",&"outfit_tier2"]:
		assert_equal(catalog.compiled_id(key),-1,"legal unresolved key")
	var columns: Gear.GearColumns = Gear.GearColumns.new(8)
	columns.occupied[2] = 1
	columns.lot_slot[2] = 0
	columns.lot_generation[2] = 1
	columns.item_id[2] = 0
	var before: PackedByteArray = _fields(catalog)
	assert_true(_store.restore_gear_columns(columns,catalog),"structural restore permits unresolved caches")
	for field: String in CACHES:
		assert_equal(_store.get(field),-1,"all five refreshed to missing")
	assert_true(_store.copy_gear_columns_into(_columns,catalog),"nonempty exact unresolved cache captures")
	assert_equal(_fields(catalog),before,"catalog unchanged")
	assert_false(_store.claim_for_job(Vector2i(0,1),Vector2i(3,1)).ok,"unknown wear model is not playable gear")

func test_success_clears_diagnostics_and_default_constructors_are_exact() -> void:
	var store: Gear = Gear.new()
	var columns: Gear.GearColumns = Gear.GearColumns.new()
	assert_equal(store.row_capacity(),16384,"default owner capacity")
	assert_equal(columns.row_capacity,16384,"default metadata")
	for field: String in FIELDS:
		assert_equal(columns.get(field).size(),16384,"default field extent")
	assert_false(store.copy_gear_columns_into(null,_defs),"first refusal")
	assert_equal(store.last_column_refusal(),&"COLUMN_GEAR_SHAPE","refusal recorded")
	assert_true(store.copy_gear_columns_into(columns,_defs),"successful capture")
	assert_equal(store.last_column_refusal(),&"","capture clears code")
	assert_equal(store.canonical_detail(),"","capture clears detail")
	assert_false(store.restore_gear_columns(null,_defs),"another refusal")
	assert_true(store.restore_gear_columns(columns,_defs),"successful restore")
	assert_equal(store.last_column_refusal(),&"","restore clears code")
	assert_equal(store.canonical_detail(),"","restore clears detail")

func test_whole_flag_pass_and_all_rows_precede_duplicate_lot_check() -> void:
	_make(&"tool")
	_make(&"net")
	_make(&"trap")
	_capture()
	_columns.lot_slot[0] = -1
	_columns.equipped[7] = 2
	_reject_restore(&"COLUMN_GEAR_OCCUPANCY")
	_columns.equipped[7] = 0
	_columns.lot_slot[0] = 0
	_columns.lot_slot[1] = 0
	_columns.item_id[2] = -1
	_reject_restore(&"COLUMN_GEAR_ITEM")
	_columns.item_id[2] = _defs.compiled_id(&"trap")
	_reject_restore(&"COLUMN_GEAR_DUPLICATE_LOT")
	_store.set("_lot_slot",_columns.lot_slot.duplicate())
	var flags: PackedByteArray = _store.get("_equipped")
	flags[7] = 2
	_store.set("_equipped",flags)
	_reject_capture(&"COLUMN_GEAR_OCCUPANCY")

func test_bound_refusals_preserve_directory_residents_and_all_borrowed_refs() -> void:
	_bind()
	var resident = _residents.spawn(&"mouse")
	var tool: Vector2i = _make(&"tool")
	assert_true(_store.equip(tool,resident.ref).ok,"bound fixture")
	_capture()
	_columns.durability[0] = -1
	_reject_restore(&"COLUMN_GEAR_DURABILITY")
	_columns.durability[0] = 1000
	var original: int = _store.get("_id_tool")
	_store.set("_id_tool",-777)
	_reject_capture(&"COLUMN_GEAR_SOURCE_CACHE")
	_store.set("_id_tool",original)

func test_adapter_refusals_carry_useful_detail_and_owner_echo() -> void:
	var block: Codec.OwnerRecord = _block()
	var results: Array = [Adapter.capture_into(null,null),Adapter.capture_into(_store,null),
		Adapter.capture_into(_store,block),Adapter.apply(block,_store),
		Adapter.apply(block,_store,Clock.new()),Adapter.capture_into(_store,block,null,_inv)]
	for refusal in results:
		assert_false(refusal.is_ok(),"actual refusal")
		assert_true(not refusal.detail.is_empty(),"diagnostic detail supplied")
	assert_equal(results[-1].detail,"COLUMN_GEAR_DEFINITIONS","owner detail forwarded verbatim")
