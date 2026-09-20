extends "res://test/framework/test_case.gd"
## Parent-authored exact claim slice tests; other sections must remain untouched.
const Fish := preload("res://scripts/core/fishing.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Adapter := preload("res://scripts/core/save_resource_claims_restore.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const FF: Array[String] = ["effort_claim_active","effort_claim_expedition_generation","effort_claim_habitat_slot","effort_claim_habitat_generation","effort_claim_job_slot","effort_claim_job_generation","effort_claim_slot_count"]
const VF: Array[String] = ["claim_active","claim_job_slot","claim_job_generation","claim_designation_slot","claim_designation_generation","claim_basin_slot","claim_basin_generation","claim_patch_kind","claim_remaining_milli","claim_created_tick","claim_persistent_id"]
var _fish: Fish
var _forage: Forage
var _fc: Fish.EffortClaimColumns
var _vc: Forage.ForageClaimColumns
var _clock: Clock

func before_each() -> void:
	_fish = Fish.new()
	_forage = Forage.new()
	_fc = Fish.EffortClaimColumns.new()
	_vc = Forage.ForageClaimColumns.new()
	_clock = Clock.new()
	assert_true(_clock.acquire_load_barrier().is_ok(),"held clock")

func after_each() -> void:
	_fish = null
	_forage = null

func _fields(object: Object, exclude: Array[String] = []) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for prop: Dictionary in object.get_property_list():
		if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or exclude.has(String(prop.name)):
			continue
		var value: Variant = object.get(prop.name)
		if not value is Object:
			bytes.append_array(var_to_bytes(value))
	return bytes

func _whole(object: Object, exclude: Array[String] = []) -> PackedByteArray:
	var skip: Array[String] = exclude.duplicate()
	skip.append("_last_claim_column_refusal")
	var bytes: PackedByteArray = _fields(object,skip)
	for name: String in ["_math","_math_b","_math_c"]:
		bytes.append_array(_fields(object.get(name)))
	return bytes

func _nonclaim(fishing: bool) -> PackedByteArray:
	var fields: Array[String] = FF if fishing else VF
	var exclude: Array[String] = ["_effort_claim_count" if fishing else "_claim_count"]
	for field: String in fields:
		exclude.append("_"+field)
	return _whole(_fish if fishing else _forage,exclude)

func _cell(record: Object, field: String, row: int, value: int) -> void:
	var column: Variant = record.get(field)
	column[row] = value
	record.set(field,column)

func _seed(fishing: bool, full: bool = false) -> void:
	var rows: int = 512 if fishing else 8192
	var fields: Array[String] = FF if fishing else VF
	var record: Object = _fc if fishing else _vc
	for row: int in rows:
		if not full and row != 2 and row != rows-1:
			continue
		var values: Array = [1,2,200+row,3,1000+row,4,1+row%6] if fishing else [1,1000+row,2,20000+row,3,100000+row,4,row%5,1+row%1180000,row*101,row+1]
		for index: int in fields.size():
			_cell(record,fields[index],row,values[index])

func _restore(fishing: bool) -> bool:
	return _fish.restore_effort_claim_columns(_fc) if fishing else _forage.restore_forage_claim_columns(_vc)

func _capture(fishing: bool) -> bool:
	return _fish.copy_effort_claim_columns_into(_fc) if fishing else _forage.copy_forage_claim_columns_into(_vc)

func _reject(fishing: bool, code: StringName, capture: bool = false) -> void:
	var store: Variant = _fish if fishing else _forage
	var record: Object = _fc if fishing else _vc
	var before: PackedByteArray = _whole(store)
	var input: PackedByteArray = _fields(record)
	var dir: Variant = store.directory()
	var directory_before: PackedByteArray = dir.state_bytes()
	assert_false(_capture(fishing) if capture else _restore(fishing),"explicit refusal")
	assert_equal(store.last_claim_column_refusal(),code,"exact diagnostic")
	assert_equal(store.claim_column_detail(),String(code),"code echo")
	assert_equal(_whole(store),before,"owner values and scratch unchanged")
	assert_equal(_fields(record),input,"caller record unchanged")
	assert_true(store.directory() == dir,"borrowed identity unchanged")
	assert_equal(dir.state_bytes(),directory_before,"Directory unchanged")

func test_defaults_sparse_last_row_and_independent_arrays_are_exact() -> void:
	for fishing: bool in [true,false]:
		var fields: Array[String] = FF if fishing else VF
		var rows: int = 512 if fishing else 8192
		var record: Object = _fc if fishing else _vc
		var store: Variant = _fish if fishing else _forage
		for field: String in fields:
			assert_equal(record.get(field).size(),rows,"fixed default extent")
		_seed(fishing)
		var input: PackedByteArray = _fields(record)
		var other: PackedByteArray = _nonclaim(fishing)
		assert_true(_restore(fishing),"exact sparse structural install")
		assert_equal(_nonclaim(fishing),other,"every other section unchanged")
		for field: String in fields:
			assert_equal(store.get("_"+field),record.get(field),"exact positional column")
		assert_equal(store.get("_"+fields[0])[rows-1],1,"last row identity preserved")
		assert_equal(store.get("_effort_claim_count" if fishing else "_claim_count"),2,"count rebuilt")
		assert_true(_capture(fishing),"recapture")
		assert_equal(_fields(record),input,"same bytes")
		_cell(record,fields[1],2,19)
		assert_true(store.get("_"+fields[1])[2] != 19,"caller mutation cannot reach owner")

func test_all_caller_and_live_shapes_refuse_without_indexing() -> void:
	for fishing: bool in [true,false]:
		var fields: Array[String] = FF if fishing else VF
		var record: Object = _fc if fishing else _vc
		var store: Variant = _fish if fishing else _forage
		var code: StringName = &"COLUMN_FISH_CLAIM_SHAPE" if fishing else &"COLUMN_FORAGE_CLAIM_SHAPE"
		for field: String in fields:
			var original: Variant = record.get(field)
			var short: Variant = original.duplicate()
			short.resize(1)
			record.set(field,short)
			_reject(fishing,code)
			_reject(fishing,code,true)
			record.set(field,original)
			original = store.get("_"+field)
			short = original.duplicate()
			short.resize(1)
			store.set("_"+field,short)
			_reject(fishing,code)
			_reject(fishing,code,true)
			store.set("_"+field,original)

func test_other_section_aggregates_scratch_and_order_keys_are_never_rebuilt() -> void:
	_seed(true)
	_seed(false)
	var effort: PackedInt32Array = _fish.get("_habitat_effort_used")
	effort.fill(123)
	_fish.set("_habitat_effort_used",effort)
	var quota: PackedInt64Array = _forage.get("_zone_quota_reserved_milli")
	quota.fill(456)
	_forage.set("_zone_quota_reserved_milli",quota)
	var scratch: PackedInt32Array = _fish.get("_effort_total_scratch")
	scratch.fill(789)
	_fish.set("_effort_total_scratch",scratch)
	_fish.set("_pending_claim_row",99)
	_fish.set("_pending_habitat_slot",88)
	_forage.set("_pending_designation_slot",77)
	_forage.set("_pending_basin_slot",66)
	_forage.set("_pending_patch_row",55)
	_forage.set("_section_1_code",&"RETAINED_SECTION1_DIAGNOSTIC")
	_vc.claim_created_tick[2] = 9223372036854775807
	_vc.claim_persistent_id[2] = 0
	for fishing: bool in [true,false]:
		var store: Variant = _fish if fishing else _forage
		for name: String in ["_math","_math_b","_math_c"]:
			store.get(name).refuse("retained scratch")
		var other: PackedByteArray = _nonclaim(fishing)
		assert_true(_restore(fishing),"structural claim slice only")
		assert_true(_capture(fishing),"pure capture")
		assert_equal(_nonclaim(fishing),other,"all other canonical/scratch sections unchanged")
	assert_equal(_vc.claim_created_tick[2],9223372036854775807,"ordering tick exact")
	assert_equal(_vc.claim_persistent_id[2],0,"zero ordering key not repaired")

func test_payload_domains_and_inactive_blanks_refuse_on_both_paths() -> void:
	for fishing: bool in [true,false]:
		_seed(fishing)
		assert_true(_restore(fishing),"valid structural source")
		var store: Variant = _fish if fishing else _forage
		var record: Object = _fc if fishing else _vc
		var fields: Array[String] = FF if fishing else VF
		var prefix: String = "COLUMN_FISH_CLAIM_" if fishing else "COLUMN_FORAGE_CLAIM_"
		var cases: Array = [[FF[0],2,"OCCUPANCY"],[FF[1],0,"REF"],[FF[2],-1,"REF"],[FF[2],352418,"REF"],[FF[3],0,"REF"],[FF[4],352418,"REF"],[FF[5],0,"REF"],[FF[6],0,"SLOT_COUNT"],[FF[6],7,"SLOT_COUNT"],[FF[6],2147483647,"SLOT_COUNT"]] if fishing else [[VF[0],2,"OCCUPANCY"],[VF[1],-1,"REF"],[VF[1],352418,"REF"],[VF[2],0,"REF"],[VF[3],352418,"REF"],[VF[4],0,"REF"],[VF[5],352418,"REF"],[VF[6],0,"REF"],[VF[7],-1,"KIND"],[VF[7],5,"KIND"],[VF[8],0,"QUANTITY"],[VF[8],1180001,"QUANTITY"],[VF[8],9223372036854775807,"QUANTITY"],[VF[9],-1,"ORDER_KEY"],[VF[10],-1,"ORDER_KEY"]]
		for item: Array in cases:
			var field: String = item[0]
			var original: int = record.get(field)[2]
			_cell(record,field,2,item[1])
			_reject(fishing,StringName(prefix+item[2]))
			_cell(store,"_"+field,2,item[1])
			_reject(fishing,StringName(prefix+item[2]),true)
			_cell(store,"_"+field,2,original)
			_cell(record,field,2,original)
		for index: int in range(1,fields.size()):
			var field: String = fields[index]
			var original: int = record.get(field)[0]
			_cell(record,field,0,original+1)
			_reject(fishing,StringName(prefix+"BLANK"))
			_cell(record,field,0,original)
		assert_true(_restore(fishing),"success clears previous failure")
		assert_equal(store.last_claim_column_refusal(),&"","clear success diagnostic")
		assert_equal(store.claim_column_detail(),"","clear success detail")

func test_source_count_and_old_payload_refusal_rules_are_distinct() -> void:
	for fishing: bool in [true,false]:
		_seed(fishing)
		assert_true(_restore(fishing),"valid source")
		var store: Variant = _fish if fishing else _forage
		var count_name: String = "_effort_claim_count" if fishing else "_claim_count"
		var code: StringName = &"COLUMN_FISH_CLAIM_SOURCE_COUNT" if fishing else &"COLUMN_FORAGE_CLAIM_SOURCE_COUNT"
		for count: int in [-1,0,9000]:
			store.set(count_name,count)
			_reject(fishing,code,true)
		store.set(count_name,-999)
		var field: String = "_effort_claim_active" if fishing else "_claim_active"
		var bad: PackedByteArray = store.get(field)
		bad.fill(2)
		store.set(field,bad)
		assert_true(_restore(fishing),"restore ignores old malformed payload/count")
		assert_equal(store.get(count_name),2,"count derived from incoming occupancy")
		assert_true(_capture(fishing),"repaired owner captures")

func test_table_wide_flags_precede_earlier_row_payload_errors() -> void:
	for fishing: bool in [true,false]:
		_seed(fishing)
		var record: Object = _fc if fishing else _vc
		var fields: Array[String] = FF if fishing else VF
		var rows: int = 512 if fishing else 8192
		_cell(record,fields[1],0,1)
		_cell(record,fields[0],rows-1,2)
		_reject(fishing,&"COLUMN_FISH_CLAIM_OCCUPANCY" if fishing else &"COLUMN_FORAGE_CLAIM_OCCUPANCY")
		_cell(record,fields[0],rows-1,1)
		_reject(fishing,&"COLUMN_FISH_CLAIM_BLANK" if fishing else &"COLUMN_FORAGE_CLAIM_BLANK")

func test_maximum_ref_and_quantity_fields_are_preserved_without_typed_row_clamp() -> void:
	_seed(true)
	_seed(false)
	_fc.effort_claim_habitat_slot[2] = 352417
	_fc.effort_claim_job_slot[2] = 352417
	_fc.effort_claim_expedition_generation[2] = 2147483647
	_fc.effort_claim_habitat_generation[2] = 2147483647
	_fc.effort_claim_job_generation[2] = 2147483647
	_fc.effort_claim_slot_count[2] = 6
	_vc.claim_job_slot[2] = 352417
	_vc.claim_job_generation[2] = 2147483647
	_vc.claim_designation_slot[2] = 352417
	_vc.claim_designation_generation[2] = 2147483647
	_vc.claim_basin_slot[2] = 352417
	_vc.claim_basin_generation[2] = 2147483647
	_vc.claim_patch_kind[2] = 4
	_vc.claim_remaining_milli[2] = 1180000
	_vc.claim_created_tick[2] = 9223372036854775807
	_vc.claim_persistent_id[2] = 9223372036854775807
	for fishing: bool in [true,false]:
		var record: Object = _fc if fishing else _vc
		var before: PackedByteArray = _fields(record)
		assert_true(_restore(fishing),"maximum structural boundary")
		assert_true(_capture(fishing),"recapture exact maximums")
		assert_equal(_fields(record),before,"no namespace clamp or generation repair")

func _block(fishing: bool) -> Codec.OwnerRecord:
	return Codec.OwnerRecord.new(0 if fishing else 1,512 if fishing else 8192,PackedInt64Array())

func _block_capture(fishing: bool, block: Codec.OwnerRecord):
	return Adapter.capture_fishing_into(_fish,block) if fishing else Adapter.capture_forage_into(_forage,block)

func _apply(fishing: bool, block: Codec.OwnerRecord, clock: Clock):
	return Adapter.apply_fishing(block,_fish,clock) if fishing else Adapter.apply_forage(block,_forage,clock)

func _assert_refusal(result, code: StringName) -> void:
	assert_equal(result.code,code,"exact boundary refusal")
	assert_false(result.detail.is_empty(),"failure explains refusal")

func test_null_records_and_successful_capture_clear_diagnostic() -> void:
	assert_false(_fish.restore_effort_claim_columns(null),"null restore")
	assert_false(_fish.copy_effort_claim_columns_into(null),"null capture")
	assert_equal(_fish.last_claim_column_refusal(),&"COLUMN_FISH_CLAIM_SHAPE","null shape")
	assert_true(_fish.copy_effort_claim_columns_into(_fc),"empty capture succeeds")
	assert_equal(_fish.claim_column_detail(),"","capture clears diagnostic")
	assert_false(_forage.restore_forage_claim_columns(null),"null restore")
	assert_false(_forage.copy_forage_claim_columns_into(null),"null capture")
	assert_equal(_forage.last_claim_column_refusal(),&"COLUMN_FORAGE_CLAIM_SHAPE","null shape")
	assert_true(_forage.copy_forage_claim_columns_into(_vc),"empty capture succeeds")
	assert_equal(_forage.claim_column_detail(),"","capture clears diagnostic")

func test_adapter_gate_precedence_preserves_owner_block_and_clock() -> void:
	var open_clock: Clock = Clock.new()
	for fishing: bool in [true,false]:
		var block: Codec.OwnerRecord = _block(fishing)
		var store: Variant = _fish if fishing else _forage
		var before: PackedByteArray = _whole(store)
		var target: PackedByteArray = _fields(block)
		var clock_before: PackedByteArray = _fields(open_clock)
		_assert_refusal(Adapter.capture_fishing_into(null,null) if fishing else Adapter.capture_forage_into(null,null),&"SAVE_CLAIMS_NULL_STORE")
		_assert_refusal(_block_capture(fishing,null),&"SAVE_CLAIMS_BLOCK_SHAPE")
		_assert_refusal(Adapter.apply_fishing(null,null) if fishing else Adapter.apply_forage(null,null),&"SAVE_CLAIMS_BLOCK_SHAPE")
		_assert_refusal(Adapter.apply_fishing(block,null) if fishing else Adapter.apply_forage(block,null),&"SAVE_CLAIMS_NULL_STORE")
		_assert_refusal(_apply(fishing,block,null),&"SAVE_CLAIMS_NULL_CLOCK")
		_assert_refusal(_apply(fishing,block,open_clock),&"SAVE_CLAIMS_BARRIER_NOT_HELD")
		block.owner = 5
		_assert_refusal(_apply(fishing,block,open_clock),&"SAVE_CLAIMS_BARRIER_NOT_HELD")
		_assert_refusal(_apply(fishing,block,_clock),&"SAVE_CLAIMS_BLOCK_SHAPE")
		block.owner = 0 if fishing else 1
		assert_equal(_whole(store),before,"all early refusals preserve owner")
		assert_equal(_fields(block),target,"all early refusals preserve caller")
		assert_equal(_fields(open_clock),clock_before,"adapter never acquires barrier")
		assert_true(_clock.is_load_barrier_held(),"held barrier remains held")

func test_adapter_every_group_extent_and_metadata_shape_is_total() -> void:
	for fishing: bool in [true,false]:
		var store: Variant = _fish if fishing else _forage
		var before: PackedByteArray = _whole(store)
		for mode: int in 6:
			var block: Codec.OwnerRecord = _block(fishing)
			match mode:
				0: block.owner = 5
				1: block.primary_count -= 1
				2: block.child_extents = PackedInt64Array([0])
				3: block.u8_columns.clear()
				4: block.i32_columns.clear()
				5: block.i64_columns.append(PackedInt64Array())
			var target: PackedByteArray = _fields(block)
			_assert_refusal(Adapter.fishing_block_shape_refusal(block) if fishing else Adapter.forage_block_shape_refusal(block),&"SAVE_CLAIMS_BLOCK_SHAPE")
			_assert_refusal(_block_capture(fishing,block),&"SAVE_CLAIMS_BLOCK_SHAPE")
			_assert_refusal(_apply(fishing,block,_clock),&"SAVE_CLAIMS_BLOCK_SHAPE")
			assert_equal(_fields(block),target,"invalid output remains byte exact")
		for group: String in ["u8_columns","i32_columns","i64_columns"]:
			var good: Codec.OwnerRecord = _block(fishing)
			for column: int in good.get(group).size():
				var block: Codec.OwnerRecord = _block(fishing)
				var columns: Array = block.get(group)
				columns[column].resize(1)
				var target: PackedByteArray = _fields(block)
				_assert_refusal(_block_capture(fishing,block),&"SAVE_CLAIMS_BLOCK_SHAPE")
				_assert_refusal(_apply(fishing,block,_clock),&"SAVE_CLAIMS_BLOCK_SHAPE")
				assert_equal(_fields(block),target,"short column untouched")
		assert_equal(_whole(store),before,"all shape refusals preserve owner")

func test_adapter_forwards_codec_and_stronger_owner_refusals_atomically() -> void:
	for fishing: bool in [true,false]:
		_seed(fishing)
		assert_true(_restore(fishing),"valid source")
		var store: Variant = _fish if fishing else _forage
		var block: Codec.OwnerRecord = _block(fishing)
		assert_true(_block_capture(fishing,block).is_ok(),"capture")
		block.u8_columns[0][2] = 2
		var codec_code: StringName = Codec.owner_refusal(block).code
		assert_true(codec_code != &"","codec rejects malformed active byte")
		var before: PackedByteArray = _whole(store)
		_assert_refusal(_apply(fishing,block,_clock),codec_code)
		assert_equal(_whole(store),before,"codec failure is atomic")
		block.u8_columns[0][2] = 1
		if fishing:
			block.i32_columns[5][2] = 7
		else:
			block.i64_columns[0][2] = 1180001
		assert_true(Codec.owner_refusal(block).is_ok(),"codec permits deliberately stronger owner counterexample")
		var target: PackedByteArray = _fields(block)
		_assert_refusal(_apply(fishing,block,_clock),&"COLUMN_FISH_CLAIM_SLOT_COUNT" if fishing else &"COLUMN_FORAGE_CLAIM_QUANTITY")
		assert_equal(_whole(store),before,"owner failure preserves everything but diagnostic")
		assert_equal(_fields(block),target,"owner failure preserves input")
		if not fishing:
			block.i64_columns[0][2] = 0
			assert_true(Codec.owner_refusal(block).is_ok(),"codec admits zero forage remaining")
			_assert_refusal(_apply(fishing,block,_clock),&"COLUMN_FORAGE_CLAIM_QUANTITY")
			assert_equal(_whole(store),before,"zero quantity does not publish")
			block.i64_columns[0][2] = 1180001
		store.set("_effort_claim_count" if fishing else "_claim_count",-1)
		_assert_refusal(_block_capture(fishing,block),&"COLUMN_FISH_CLAIM_SOURCE_COUNT" if fishing else &"COLUMN_FORAGE_CLAIM_SOURCE_COUNT")
		assert_equal(_fields(block),target,"capture failure cannot publish partial columns")

func test_adapter_literal_mapping_recapture_and_independent_containers() -> void:
	for fishing: bool in [true,false]:
		_seed(fishing)
		assert_true(_restore(fishing),"source install")
		var fields: Array[String] = FF if fishing else VF
		var record: Object = _fc if fishing else _vc
		var block: Codec.OwnerRecord = _block(fishing)
		var old_group: Array[PackedInt32Array] = block.i32_columns
		assert_true(_block_capture(fishing,block).is_ok(),"capture exact block")
		for index: int in fields.size():
			var column: Variant = block.u8_columns[0] if index == 0 else (block.i64_columns[index-8] if not fishing and index >= 8 else block.i32_columns[index-1])
			assert_equal(column,record.get(fields[index]),"literal semantic ordinal maps exact column")
		old_group[0].fill(123)
		assert_true(block.i32_columns[0][2] != 123,"published Array group independent of previous output")
		var expected: PackedByteArray = _fields(block)
		var other: PackedByteArray = _nonclaim(fishing)
		assert_true(_apply(fishing,block,_clock).is_ok(),"barrier install")
		assert_equal(_nonclaim(fishing),other,"other sections remain exact")
		var recapture: Codec.OwnerRecord = _block(fishing)
		assert_true(_block_capture(fishing,recapture).is_ok(),"recapture")
		assert_equal(_fields(recapture),expected,"block round trip")
		block.i32_columns[0][2] = 111
		assert_true((_fish.get("_"+FF[1]) if fishing else _forage.get("_"+VF[1]))[2] != 111,"input array mutation cannot change owner")
		assert_equal(_fields(recapture),expected,"independent captured arrays")

func test_six_complete_literal_owner_wire_goldens() -> void:
	# Independent generator/digests: docs/validation/evidence/claim-columns-contract-2026-09-19/literal_wire_goldens.py and .json.
	# Owner framing probe plus codec regression, not a full-file writer.
	const Bytes := preload("res://scripts/core/save_codec.gd")
	var fish_hashes: Array[String] = ["af9ba7a0b9f9f749567be9459cd7b517ab76ec49406df4a0d97c9d26578049e7","61177f0279489529c147dc7d586a05261cf46d48d5d6c31805c352f3b599acd2","8e60834b4be590fc4e3d9dd4316ff92983d7cd4624e8357ca11acd9f10bbe647"]
	var forage_hashes: Array[String] = ["30bd50093ba8e17671186b5ecea6a04395eedbf0347f3d985265de03e2fb65fd","f80144a350e53d48f8ff2e0e1071be3e148091c76d51331127db20d72d5d1cb1","9b3092df5707b9577fe245511fac11f0d345e3712230f04c9a008d74d1111c31"]
	for fishing: bool in [true,false]:
		var rows: int = 512 if fishing else 8192
		assert_equal(Codec.OWNER_SCHEMA_VERSIONS[0 if fishing else 1],1,"owner schema unchanged")
		for variant: int in 3:
			_fc = Fish.EffortClaimColumns.new()
			_vc = Forage.ForageClaimColumns.new()
			if variant > 0:
				_seed(fishing,variant == 2)
			assert_true(_restore(fishing),"literal fixture install")
			var block: Codec.OwnerRecord = _block(fishing)
			assert_true(_block_capture(fishing,block).is_ok(),"fixture capture")
			var writer: Bytes.Writer = Bytes.Writer.new(40)
			writer.write_utf8_u32("fishing" if fishing else "forage",256)
			writer.write_u32(1)
			writer.write_u64(rows)
			writer.write_u64(Codec.payload_bytes_of(block))
			writer.write_u32(0)
			var raw: PackedByteArray = writer.to_bytes()
			for ordinal: int in (7 if fishing else 11):
				var prefix: Bytes.Writer = Bytes.Writer.new(8)
				prefix.write_u64(rows)
				raw.append_array(prefix.to_bytes())
				raw.append_array(Codec.column_slice(block,ordinal,0,rows))
			assert_equal(raw.size(),12891 if fishing else 434298,"fixed complete block size")
			var hash: HashingContext = HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(raw)
			assert_equal(hash.finish().hex_encode(),fish_hashes[variant] if fishing else forage_hashes[variant],"preimplementation independent golden")

func _public_world() -> Dictionary:
	var residents: Residents = Residents.new()
	var priorities: Priorities = Priorities.new()
	var schedule: Schedule = Schedule.new(residents.needs())
	var jobs: Jobs = Jobs.new(residents,priorities,schedule)
	var forage: Forage = Forage.new(null,jobs)
	var fish: Fish = Fish.new(null,forage,jobs)
	var fish_job = jobs.create_job(2,0,0,100,10)
	var forage_job = jobs.create_job(4,0,0,100,11)
	assert_true(fish_job.ok and forage_job.ok,"real jobs")
	var expedition: Vector2i = fish.directory().create(Directory.KIND_EXPEDITION)
	var habitat = fish.create_habitat(2,Directory.NULL_REF,PackedInt32Array([10,11,12]),0,0,0)
	assert_true(habitat.ok,"real habitat")
	assert_true(fish.reserve_effort_slots(expedition,fish_job.ref,habitat.ref,2).ok,"real effort admission")
	var basin = forage.create_zone(2,1,20000,false,true)
	assert_true(basin.ok,"real forage basin")
	assert_true(forage.set_quota_milli(basin.ref,20000,1).ok,"manual seasonal quota")
	assert_true(forage.create_patch_set(basin.ref,PackedInt32Array([10,11,12,13,14])).ok,"real patches")
	var designation = forage.create_zone(2,1,0,false,true)
	assert_true(designation.ok,"real designation")
	assert_true(forage.set_basin(designation.ref,basin.ref).ok,"real basin association")
	assert_true(forage.claim_forage(forage_job.ref,designation.ref,0,1000,1,false).ok,"real forage admission")
	return {"residents":residents,"priorities":priorities,"schedule":schedule,"jobs":jobs,"forage":forage,"fish":fish,"fish_job":fish_job.ref,"forage_job":forage_job.ref,"expedition":expedition,"habitat":habitat.ref,"designation":designation.ref}

func test_public_claims_continue_after_structural_slice_only_restore() -> void:
	var uninterrupted: Dictionary = _public_world()
	var restored: Dictionary = _public_world()
	_fish = restored.fish
	_forage = restored.forage
	var directory_before: PackedByteArray = _fish.directory().state_bytes()
	var jobs_before: PackedByteArray = _fields(restored.jobs)
	var fish_binding: Variant = _fish.get("_jobs")
	var forage_binding: Variant = _forage.get("_jobs")
	for fishing: bool in [true,false]:
		var block: Codec.OwnerRecord = _block(fishing)
		var before: PackedByteArray = _nonclaim(fishing)
		assert_true(_block_capture(fishing,block).is_ok(),"public claim capture")
		assert_true(_apply(fishing,block,_clock).is_ok(),"public claim reinstall")
		assert_equal(_nonclaim(fishing),before,"all other sections and scratch exact")
	assert_true(_fish.get("_jobs") == fish_binding and _forage.get("_jobs") == forage_binding,"borrowed Job bindings retained")
	assert_equal(_fish.directory().state_bytes(),directory_before,"borrowed Directory unchanged")
	assert_equal(_fields(restored.jobs),jobs_before,"borrowed Jobs unchanged")
	for world: Dictionary in [uninterrupted,restored]:
		assert_true(world.forage.collect_claim(world.forage_job,400,1,false).ok,"partial collection after restore")
		assert_true(world.forage.release_claim(world.forage_job).ok,"release remaining quota")
		assert_true(world.forage.claim_forage(world.forage_job,world.designation,0,700,1,false).ok,"same row admits next claim")
		assert_true(world.forage.collect_claim(world.forage_job,700,1,false).ok,"full collection closes claim")
		assert_true(world.fish.release_effort_slots(world.expedition).ok,"release effort")
		assert_true(world.fish.reserve_effort_slots(world.expedition,world.fish_job,world.habitat,4).ok,"next cycle uses all four river slots")
		assert_true(world.fish.release_effort_slots(world.expedition).ok,"close next cycle")
	assert_equal(_whole(restored.fish),_whole(uninterrupted.fish),"fishing continuation exact including aggregates and scratch")
	assert_equal(_whole(restored.forage),_whole(uninterrupted.forage),"forage continuation exact including quota, stocks and order keys")
	assert_equal(restored.fish.directory().state_bytes(),uninterrupted.fish.directory().state_bytes(),"identity continuation exact")

func test_real_stale_claims_survive_slice_restore_until_normal_purge() -> void:
	var uninterrupted: Dictionary = _public_world()
	var restored: Dictionary = _public_world()
	for world: Dictionary in [uninterrupted,restored]:
		assert_true(world.fish.directory().destroy(world.expedition),"destroy Expedition leaves claim for normal purge")
		assert_true(world.jobs.destroy_job(world.jobs.directory().get_typed_row(world.forage_job)).ok,"destroy owning Job identity leaves claim for normal purge")
	_fish = restored.fish
	_forage = restored.forage
	for fishing: bool in [true,false]:
		var before: PackedByteArray = _whole(_fish if fishing else _forage)
		var block: Codec.OwnerRecord = _block(fishing)
		assert_true(_block_capture(fishing,block).is_ok(),"stale identity is structurally capturable")
		assert_true(_apply(fishing,block,_clock).is_ok(),"structural slice preserves stale claim")
		assert_equal(_whole(_fish if fishing else _forage),before,"restore must not purge or repair")
	for world: Dictionary in [uninterrupted,restored]:
		var fish_released = world.fish.purge_stale_effort_claims()
		var forage_released = world.forage.purge_stale_claims()
		assert_true(fish_released.ok and forage_released.ok,"normal public purges succeed")
		assert_equal(fish_released.value,1,"one stale fishing owner released")
		assert_equal(forage_released.value,1,"one stale forage owner released")
	assert_equal(_whole(restored.fish),_whole(uninterrupted.fish),"identical postpurge fishing state")
	assert_equal(_whole(restored.forage),_whole(uninterrupted.forage),"identical postpurge forage state")
