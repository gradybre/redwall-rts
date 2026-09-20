extends "res://test/framework/test_case.gd"
## Independent checker fixtures. Directly authored component images are labeled structural fixtures.
const Check := preload("res://scripts/core/save_resource_claims_reconcile.gd")
const Dir := preload("res://scripts/core/entity_directory.gd")
const DirCodec := preload("res://scripts/core/save_section_directory.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Math := preload("res://scripts/core/int_math.gd")
var _live: Dir
var _directory: DirCodec.Record
var _components: Check.Components
var _fish: Codec.OwnerRecord
var _forage: Codec.OwnerRecord
var _habitat: Vector2i
var _basin: Vector2i
var _designation: Vector2i
var _fish_job: Vector2i
var _forage_job: Vector2i
var _expedition: Vector2i

func before_each() -> void:
	_live = Dir.new()
	_directory = DirCodec.Record.new()
	_components = Check.Components.new()
	_fish = Codec.OwnerRecord.new(0,512,PackedInt64Array())
	_forage = Codec.OwnerRecord.new(1,8192,PackedInt64Array())

func after_each() -> void:
	_live = null
	_directory = null
	_components = null
	_fish = null
	_forage = null

func _sync() -> void:
	assert_true(DirCodec.capture_into(_live,_directory).is_ok(),"real Directory capture")

func _zone() -> Vector2i:
	var ref: Vector2i = _live.create(Dir.KIND_HARVEST_ZONE)
	var row: int = _live.get_typed_row(ref)
	_components.forage.zone_present[row] = 1
	_components.forage.zone_ref_slot[row] = ref.x
	_components.forage.zone_ref_generation[row] = ref.y
	_components.forage.zone_basin_slot[row] = ref.x
	_components.forage.zone_basin_generation[row] = ref.y
	return ref

func _job(tick: int) -> Vector2i:
	var ref: Vector2i = _live.create(Dir.KIND_JOB)
	var row: int = _live.get_typed_row(ref)
	_components.jobs.job_present[row] = 1
	_components.jobs.job_ref_slot[row] = ref.x
	_components.jobs.job_ref_generation[row] = ref.y
	_components.jobs.created_tick[row] = tick
	return ref

func _cell(block: Codec.OwnerRecord, ordinal: int, row: int, value: int) -> void:
	var index: int = Codec.storage_index_of(block.owner,ordinal)
	if Codec.field_type_of(block.owner,ordinal) == 0:
		var bytes: PackedByteArray = block.u8_columns[index]
		bytes[row] = value
		block.u8_columns[index] = bytes
	elif Codec.field_type_of(block.owner,ordinal) == 2:
		var words: PackedInt32Array = block.i32_columns[index]
		words[row] = value
		block.i32_columns[index] = words
	else:
		var longs: PackedInt64Array = block.i64_columns[index]
		longs[row] = value
		block.i64_columns[index] = longs

func _seed() -> void:
	_habitat = _live.create(Dir.KIND_FISH_HABITAT)
	_components.fish.habitat_present[0] = 1
	_components.fish.habitat_ref_slot[0] = _habitat.x
	_components.fish.habitat_ref_generation[0] = _habitat.y
	_components.fish.habitat_effort_slots[0] = 4
	_components.fish.habitat_effort_used[0] = 2
	_basin = _zone()
	_designation = _zone()
	_components.forage.zone_basin_slot[1] = _basin.x
	_components.forage.zone_basin_generation[1] = _basin.y
	_components.forage.zone_quota_reserved_milli[0] = 1000
	_components.forage.zone_quota_reserved_milli[1] = 1000
	_components.forage.patch_present[0] = 1
	_components.forage.patch_zone_slot[0] = _basin.x
	_components.forage.patch_zone_generation[0] = _basin.y
	_fish_job = _job(111)
	_forage_job = _job(222)
	_expedition = _live.create(Dir.KIND_EXPEDITION)
	var f: Array[int] = [1,_expedition.y,_habitat.x,_habitat.y,_fish_job.x,_fish_job.y,2,_expedition.x]
	var v: Array[int] = [1,_forage_job.x,_forage_job.y,_designation.x,_designation.y,_basin.x,_basin.y,0,1000,222,_live.get_persistent_id(_forage_job)]
	for ordinal: int in f.size(): _cell(_fish,ordinal,0,f[ordinal])
	for ordinal: int in v.size(): _cell(_forage,ordinal,1,v[ordinal])
	_sync()

func _fingerprint() -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var objects: Array[Object] = [_directory,_fish,_forage,_components.fish,_components.forage,_components.jobs]
	for object: Object in objects:
		if object == null: continue
		for prop: Dictionary in object.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			var value: Variant = object.get(prop.name)
			if not value is Object: hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()

func _validate() -> Check.Result:
	var before: String = _fingerprint()
	var result: Check.Result = Check.validate(_directory,_live.next_persistent_id(),_fish,_forage,_components)
	assert_equal(_fingerprint(),before,"every supplied column/header remains byte-identical")
	return result

func _refuse(code: StringName, owner: StringName = &"", space: StringName = &"", row: int = -1) -> void:
	var result: Check.Result = _validate()
	assert_false(result.is_ok(),"explicit refusal")
	assert_equal(result.code,code,"exact first refusal")
	assert_true(not result.detail.is_empty(),"nonempty deterministic detail")
	assert_equal(result.owner,owner,"owner namespace")
	assert_equal(result.row_space,space,"row-space namespace")
	assert_equal(result.row,row,"first offending location")
	assert_equal(result.fishing_count+result.forage_count+result.stale_fishing_expeditions+result.stale_fishing_jobs+result.stale_forage_jobs,0,"no partial counts escape refusal")

func _destroy_job(ref: Vector2i) -> void:
	var row: int = _live.get_typed_row(ref)
	assert_true(_live.destroy(ref),"ordinary identity destroy")
	_components.jobs.job_present[row] = 0
	_components.jobs.job_ref_slot[row] = -1
	_components.jobs.job_ref_generation[row] = 0
	_components.jobs.created_tick[row] = 0
	_sync()

func test_empty_and_live_inputs_are_read_only_and_report_exact_counts() -> void:
	_sync()
	var empty: Check.Result = _validate()
	assert_true(empty.is_ok(),"empty valid world")
	assert_equal(empty.fishing_count+empty.forage_count,0,"empty counts")
	_seed()
	var live: Check.Result = _validate()
	assert_true(live.is_ok(),"literal live identities and totals")
	assert_equal(live.fishing_count,1,"one fishing claim")
	assert_equal(live.forage_count,1,"one forage claim")
	assert_equal(live.stale_fishing_expeditions+live.stale_fishing_jobs+live.stale_forage_jobs,0,"no stale owner")
	assert_equal(live.row,-1,"success has no failure location")

func test_all_component_extent_gates_precede_directory_validation() -> void:
	_directory.active.resize(0)
	var groups: Array[Object] = [_components.fish,_components.forage,_components.jobs]
	for group: Object in groups:
		for prop: Dictionary in group.get_property_list():
			if (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			var saved: Variant = group.get(prop.name)
			if not (saved is PackedByteArray or saved is PackedInt32Array or saved is PackedInt64Array): continue
			var malformed: Variant = saved.duplicate()
			malformed.resize(saved.size()-1)
			group.set(prop.name,malformed)
			_refuse(&"CLAIM_CHECK_SHAPE")
			group.set(prop.name,saved)

func test_null_participants_and_subrecords_refuse_without_work() -> void:
	var results: Array[Check.Result] = [Check.validate(null,1,_fish,_forage,_components),Check.validate(_directory,1,null,_forage,_components),Check.validate(_directory,1,_fish,null,_components),Check.validate(_directory,1,_fish,_forage,null)]
	for result: Check.Result in results: assert_equal(result.code,&"CLAIM_CHECK_NULL","null participant")
	var fish = _components.fish
	_components.fish = null
	assert_equal(Check.validate(_directory,1,_fish,_forage,_components).code,&"CLAIM_CHECK_NULL","null fish projection")
	_components.fish = fish
	var forage = _components.forage
	_components.forage = null
	assert_equal(Check.validate(_directory,1,_fish,_forage,_components).code,&"CLAIM_CHECK_NULL","null forage projection")
	_components.forage = forage
	_components.jobs = null
	assert_equal(Check.validate(_directory,1,_fish,_forage,_components).code,&"CLAIM_CHECK_NULL","null job projection")

func test_claim_shape_is_checked_before_directory_and_codec_indexing() -> void:
	_directory.active.resize(0)
	_fish.i32_columns.clear()
	_refuse(&"SAVE_CLAIMS_BLOCK_SHAPE")

func test_unrelated_directory_failure_is_forwarded_unchanged() -> void:
	_directory.active[200] = 2
	var expected = DirCodec.record_refusal(_directory)
	var result: Check.Result = _validate()
	assert_equal(result.code,expected.code,"original Directory refusal")
	assert_equal(result.detail,expected.detail,"original Directory detail")
	assert_equal(result.row,-1,"preflight has no invented parsed location")

func test_cursor_bounds_and_live_id_order_are_checked() -> void:
	_seed()
	for cursor: int in [0,2147483649,_live.next_persistent_id()-1]:
		var before: String = _fingerprint()
		var result: Check.Result = Check.validate(_directory,cursor,_fish,_forage,_components)
		assert_equal(result.code,&"CLAIM_CHECK_CURSOR","invalid or non-advancing cursor")
		assert_equal(_fingerprint(),before,"cursor refusal read-only")
	assert_true(Check.validate(_directory,2147483648,_fish,_forage,_components).is_ok(),"terminal cursor structurally accepted")

func test_reverse_directory_walk_requires_each_component_kind() -> void:
	for kind: int in [Dir.KIND_FISH_HABITAT,Dir.KIND_HARVEST_ZONE,Dir.KIND_JOB]:
		var ref: Vector2i = _live.create(kind)
		_sync()
		var owner: StringName = &"fishing" if kind == Dir.KIND_FISH_HABITAT else (&"forage" if kind == Dir.KIND_HARVEST_ZONE else &"jobs")
		_refuse(&"CLAIM_CHECK_IDENTITY",owner,&"directory_slot",ref.x)
		assert_true(_live.destroy(ref),"clear test identity")

func test_component_self_identity_and_occupancy_refuse_in_their_namespace() -> void:
	_seed()
	_components.fish.habitat_ref_generation[0] += 1
	_refuse(&"CLAIM_CHECK_IDENTITY",&"fishing",&"habitat",0)
	_components.fish.habitat_ref_generation[0] -= 1
	_components.forage.zone_present[1] = 2
	_refuse(&"CLAIM_CHECK_COMPONENT",&"forage",&"zone",1)

func test_dead_expedition_is_preserved_and_never_reconstructed_from_reused_row() -> void:
	_seed()
	assert_true(_live.destroy(_expedition),"destroy Expedition")
	var interloper: Vector2i = _zone()
	assert_equal(interloper.x,_expedition.x,"other kind reuses its Directory slot")
	var replacement: Vector2i = _live.create(Dir.KIND_EXPEDITION)
	assert_equal(replacement.y,_expedition.y,"different slot same generation")
	assert_equal(_live.get_typed_row(replacement),0,"same typed row")
	_sync()
	var result: Check.Result = _validate()
	assert_true(result.is_ok(),"legitimate stale full pair preserved")
	assert_equal(result.stale_fishing_expeditions,1,"old Expedition remains stale")
	assert_equal(result.fishing_count,1,"amount still counted")

func test_same_slot_new_generation_stays_stale_and_both_dead_jobs_are_counted() -> void:
	_seed()
	assert_true(_live.destroy(_expedition),"destroy original")
	var replacement: Vector2i = _live.create(Dir.KIND_EXPEDITION)
	assert_equal(replacement.x,_expedition.x,"same Directory slot")
	assert_true(replacement.y > _expedition.y,"new generation")
	_destroy_job(_fish_job)
	_destroy_job(_forage_job)
	var result: Check.Result = _validate()
	assert_true(result.is_ok(),"three dead owning refs accepted without cleanup")
	assert_equal(result.stale_fishing_expeditions,1,"stale expedition count")
	assert_equal(result.stale_fishing_jobs,1,"stale fishing Job count")
	assert_equal(result.stale_forage_jobs,1,"stale forage Job count")

func test_claim_owner_future_generation_and_live_wrong_kind_are_distinct() -> void:
	_seed()
	_cell(_fish,1,0,_expedition.y+1)
	_refuse(&"CLAIM_CHECK_FUTURE_REF",&"fishing",&"claim",0)
	_cell(_fish,1,0,_expedition.y)
	_cell(_fish,7,0,_fish_job.x)
	_refuse(&"CLAIM_CHECK_IDENTITY",&"fishing",&"claim",0)

func test_fully_live_owner_must_map_to_the_claim_row() -> void:
	_seed()
	var second: Vector2i = _live.create(Dir.KIND_EXPEDITION)
	_cell(_fish,7,0,second.x)
	_cell(_fish,1,0,second.y)
	_sync()
	_refuse(&"CLAIM_CHECK_IDENTITY",&"fishing",&"claim",0)

func test_forage_live_tick_and_pid_provenance_refuse_without_repair() -> void:
	_seed()
	_cell(_forage,9,1,223)
	_refuse(&"CLAIM_CHECK_PROVENANCE",&"forage",&"claim",1)
	_cell(_forage,9,1,222)
	_cell(_forage,10,1,_live.get_persistent_id(_fish_job))
	_refuse(&"CLAIM_CHECK_PROVENANCE",&"forage",&"claim",1)

func test_dead_forage_job_retains_tick_but_requires_historical_pid_domain() -> void:
	_seed()
	_destroy_job(_forage_job)
	_cell(_forage,9,1,9223372036854775807)
	assert_true(_validate().is_ok(),"dead Job tick cannot be guessed from a new occupant")
	for pid: int in [0,2147483648,_live.next_persistent_id()]:
		_cell(_forage,10,1,pid)
		_refuse(&"CLAIM_CHECK_PROVENANCE",&"forage",&"claim",1)

func test_missing_habitat_and_mismatched_designation_basin_refuse() -> void:
	_seed()
	_cell(_fish,2,0,_basin.x)
	_refuse(&"CLAIM_CHECK_ECOLOGY",&"fishing",&"claim",0)
	_cell(_fish,2,0,_habitat.x)
	_components.forage.zone_basin_slot[1] = _designation.x
	_refuse(&"CLAIM_CHECK_ECOLOGY",&"forage",&"claim",1)

func test_only_the_claimed_patch_is_required_and_its_missing_pair_refuses() -> void:
	_seed()
	assert_true(_validate().is_ok(),"one patch among five is sufficient")
	_components.forage.patch_present[0] = 0
	_components.forage.patch_zone_slot[0] = -1
	_components.forage.patch_zone_generation[0] = 0
	_refuse(&"CLAIM_CHECK_ECOLOGY",&"forage",&"claim",1)

func test_shared_designation_and_basin_counts_the_amount_once() -> void:
	_seed()
	_cell(_forage,3,1,_basin.x)
	_cell(_forage,4,1,_basin.y)
	_components.forage.zone_quota_reserved_milli[1] = 0
	assert_true(_validate().is_ok(),"shared row total1000 rather than2000")

func test_every_zone_total_is_checked_even_without_any_claim() -> void:
	_seed()
	var extra: Vector2i = _zone()
	var row: int = _live.get_typed_row(extra)
	_components.forage.zone_quota_reserved_milli[row] = 1
	_sync()
	_refuse(&"CLAIM_CHECK_TOTAL",&"forage",&"zone",row)

func test_missing_saved_totals_and_physical_fishing_capacity_are_not_repaired() -> void:
	_seed()
	_components.fish.habitat_effort_used[0] = 0
	_refuse(&"CLAIM_CHECK_TOTAL",&"fishing",&"habitat",0)
	_components.fish.habitat_effort_used[0] = 2
	_components.forage.zone_quota_reserved_milli[1] = 0
	_refuse(&"CLAIM_CHECK_TOTAL",&"forage",&"zone",1)

func test_codec_quantity_refusal_precedes_stronger_checker_bound() -> void:
	_seed()
	_cell(_fish,6,0,0)
	var codec_error = Codec.owner_refusal(_fish)
	_refuse(codec_error.code)
	_cell(_fish,6,0,7)
	_refuse(&"CLAIM_CHECK_QUANTITY",&"fishing",&"claim",0)
	_cell(_fish,6,0,2)
	_cell(_forage,8,1,1180001)
	_refuse(&"CLAIM_CHECK_QUANTITY",&"forage",&"claim",1)

func test_claim_free_zone_can_retain_a_stale_basin_reference() -> void:
	var basin: Vector2i = _zone()
	var designation: Vector2i = _zone()
	_components.forage.zone_basin_slot[1] = basin.x
	_components.forage.zone_basin_generation[1] = basin.y
	assert_true(_live.destroy(basin),"destroy basin identity in this structural fixture")
	_components.forage.zone_present[0] = 0
	_components.forage.zone_ref_slot[0] = -1
	_components.forage.zone_ref_generation[0] = 0
	_components.forage.zone_basin_slot[0] = -1
	_components.forage.zone_basin_generation[0] = 0
	_sync()
	assert_true(_validate().is_ok(),"surviving designation retains stale basin; no claim uses it")
	assert_equal(_components.forage.zone_ref_slot[1],designation.x,"surviving self identity unchanged")

func test_inactive_habitat_retains_its_old_effort_capacity() -> void:
	_components.fish.habitat_effort_slots[31] = 6
	_sync()
	assert_true(_validate().is_ok(),"ordinary destroyed-row capacity residue is accepted structurally")
	_components.fish.habitat_effort_used[31] = 1
	_refuse(&"CLAIM_CHECK_COMPONENT",&"fishing",&"habitat",31)

func test_synthetic_checked_arithmetic_guard_is_not_a_public_overflow_witness() -> void:
	var out: Math.IntResult = Math.IntResult.new()
	assert_true(Check._checked_total_into(43,71,out),"ordinary sum")
	assert_equal(out.value,114,"exact integer addition")
	assert_false(Check._checked_total_into(9223372036854775807,1,out),"synthetic helper overflow")
	assert_false(out.ok,"checked result refused")

func test_terminal_retired_generation_is_a_legitimate_stale_owner() -> void:
	_seed()
	assert_true(_live.destroy(_expedition),"release ordinary owner first")
	_sync()
	_directory.generation[_expedition.x] = 2147483647
	_directory.retired[_expedition.x] = 1
	_cell(_fish,1,0,2147483647)
	var result: Check.Result = _validate()
	assert_true(result.is_ok(),"synthetic terminal retired slot is historically dead")
	assert_equal(result.stale_fishing_expeditions,1,"same terminal generation is stale on inactive slot")

func test_signed_i32_maximum_persistent_id_is_admitted_at_exhausted_cursor() -> void:
	_seed()
	_directory.persistent_id[_forage_job.x] = 2147483647
	_cell(_forage,10,1,2147483647)
	var before: String = _fingerprint()
	var result: Check.Result = Check.validate(_directory,2147483648,_fish,_forage,_components)
	assert_true(result.is_ok(),"synthetic maximum live PID has one-past exhausted cursor")
	assert_equal(_fingerprint(),before,"maximum-boundary call is read-only")

func test_full_forage_quantity_bound_is_a_structural_sum_exercise() -> void:
	var basin: Vector2i = _zone()
	_components.forage.patch_present[0] = 1
	_components.forage.patch_zone_slot[0] = basin.x
	_components.forage.patch_zone_generation[0] = basin.y
	_components.forage.zone_quota_reserved_milli[0] = 9666560000
	var ids: PackedInt64Array = PackedInt64Array()
	ids.resize(8192)
	for row: int in 8192:
		var job: Vector2i = _job(0)
		ids[row] = _live.get_persistent_id(job)
	var active: PackedByteArray = PackedByteArray()
	active.resize(8192)
	active.fill(1)
	_forage.u8_columns[0] = active
	for ordinal: int in range(1,8):
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(8192)
		if ordinal == 1: words = _components.jobs.job_ref_slot.duplicate()
		elif ordinal == 2 or ordinal == 4 or ordinal == 6: words.fill(1)
		elif ordinal == 3 or ordinal == 5: words.fill(basin.x)
		_forage.i32_columns[Codec.storage_index_of(1,ordinal)] = words
	var amount: PackedInt64Array = PackedInt64Array()
	amount.resize(8192)
	amount.fill(1180000)
	_forage.i64_columns[0] = amount
	_forage.i64_columns[2] = ids
	_sync()
	var result: Check.Result = _validate()
	assert_true(result.is_ok(),"structural maximum sum fits i64; no current quota admission claim")
	assert_equal(result.forage_count,8192,"every row included")
	assert_equal(result.stale_forage_jobs,0,"every generated identity live")

func test_full_fishing_quantity_bound_compares_capacity_after_the_complete_claim_scan() -> void:
	_seed()
	_components.fish.habitat_effort_slots[0] = 6
	_components.fish.habitat_effort_used[0] = 6
	var slots: PackedInt32Array = PackedInt32Array()
	slots.resize(512)
	slots[0] = _expedition.x
	for row: int in range(1,512):
		var ref: Vector2i = _live.create(Dir.KIND_EXPEDITION)
		slots[row] = ref.x
	var active: PackedByteArray = PackedByteArray()
	active.resize(512)
	active.fill(1)
	_fish.u8_columns[0] = active
	for ordinal: int in range(1,8):
		var words: PackedInt32Array = PackedInt32Array()
		words.resize(512)
		if ordinal == 7: words = slots
		elif ordinal == 1 or ordinal == 3 or ordinal == 5: words.fill(1)
		elif ordinal == 2: words.fill(_habitat.x)
		elif ordinal == 4: words.fill(_fish_job.x)
		elif ordinal == 6: words.fill(6)
		_fish.i32_columns[Codec.storage_index_of(0,ordinal)] = words
	_sync()
	_refuse(&"CLAIM_CHECK_TOTAL",&"fishing",&"habitat",0)
	_cell(_fish,1,511,2)
	_refuse(&"CLAIM_CHECK_FUTURE_REF",&"fishing",&"claim",511)

func test_forage_live_job_must_map_to_its_claim_row_before_provenance() -> void:
	_seed()
	_cell(_forage,1,1,_fish_job.x)
	_cell(_forage,2,1,_fish_job.y)
	_refuse(&"CLAIM_CHECK_IDENTITY",&"forage",&"claim",1)

func test_unclaimed_present_patch_requires_its_zone_and_exact_mirror() -> void:
	_components.forage.patch_present[0] = 1
	_components.forage.patch_zone_slot[0] = 0
	_components.forage.patch_zone_generation[0] = 1
	_refuse(&"CLAIM_CHECK_COMPONENT",&"forage",&"patch",0)
	_seed()
	_components.forage.patch_zone_slot[0] = _designation.x
	_refuse(&"CLAIM_CHECK_COMPONENT",&"forage",&"patch",0)

func test_inactive_job_projection_has_exact_blank_tick_and_reference() -> void:
	_components.jobs.created_tick[8191] = 1
	_refuse(&"CLAIM_CHECK_COMPONENT",&"jobs",&"job",8191)
	_components.jobs.created_tick[8191] = 0
	_components.jobs.job_ref_slot[8191] = 0
	_components.jobs.job_ref_generation[8191] = 1
	_refuse(&"CLAIM_CHECK_COMPONENT",&"jobs",&"job",8191)

func test_present_zone_basin_pair_must_have_a_structural_slot_and_generation() -> void:
	_seed()
	for slot: int in [-1,352418]:
		_components.forage.zone_basin_slot[1] = slot
		_refuse(&"CLAIM_CHECK_COMPONENT",&"forage",&"zone",1)
	_components.forage.zone_basin_slot[1] = _basin.x
	_components.forage.zone_basin_generation[1] = 0
	_refuse(&"CLAIM_CHECK_COMPONENT",&"forage",&"zone",1)

func test_codec_preconditions_refuse_every_claim_slot_and_patch_kind_before_indexing() -> void:
	_seed()
	for fishing: bool in [true,false]:
		var block: Codec.OwnerRecord = _fish if fishing else _forage
		var row: int = 0 if fishing else 1
		var ordinals: PackedInt32Array = PackedInt32Array([2,4,7]) if fishing else PackedInt32Array([1,3,5])
		for ordinal: int in ordinals:
			var saved: int = block.i32_column(ordinal)[row]
			for slot: int in [-1,352418]:
				_cell(block,ordinal,row,slot)
				assert_false(Codec.owner_refusal(block).is_ok(),"upstream bound is independently observable")
				_refuse(&"SAVE_INV_SLOT_RANGE")
			_cell(block,ordinal,row,saved)
	for kind: int in [-1,5,640]:
		_cell(_forage,7,1,kind)
		assert_false(Codec.owner_refusal(_forage).is_ok(),"kind outside0..4 rejected before offset arithmetic")
		_refuse(&"SAVE_INV_PATCH_KIND")
	_cell(_forage,7,1,0)
	_cell(_forage,8,1,0)
	assert_true(Codec.owner_refusal(_forage).is_ok(),"zero Forage amount is an intentionally weaker codec domain")
	_refuse(&"CLAIM_CHECK_QUANTITY",&"forage",&"claim",1)
