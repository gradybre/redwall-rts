extends "res://test/framework/test_case.gd"
## FISH-ID-R01: a typed row and generation alone do not identify its Expedition.
const Fish := preload("res://scripts/core/fishing.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Adapter := preload("res://scripts/core/save_resource_claims_restore.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
var _residents: Residents
var _priorities: Priorities
var _schedule: Schedule
var _jobs: Jobs
var _zones: Forage
var _fish: Fish
var _job: Vector2i
var _habitat: Vector2i
var _a: Vector2i
var _row: int

func before_each() -> void:
	_residents = Residents.new()
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents,_priorities,_schedule)
	_zones = Forage.new(null,_jobs)
	_fish = Fish.new(null,_zones,_jobs)
	var job: Jobs.OpResult = _jobs.create_job(2,0,0,100,10)
	var habitat: Fish.OpResult = _fish.create_habitat(2,Directory.NULL_REF,PackedInt32Array([10,11,12]),0,0,0)
	assert_true(job.ok and habitat.ok,"real Job and habitat")
	_job = job.ref
	_habitat = habitat.ref
	_a = _fish.directory().create(Directory.KIND_EXPEDITION)
	_row = _fish.directory().get_typed_row(_a)
	assert_true(_fish.reserve_effort_slots(_a,_job,_habitat,2).ok,"A owns two effort slots")

func after_each() -> void:
	_fish = null
	_zones = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null

func _replacement(separate_slot: bool) -> Vector2i:
	assert_true(_fish.directory().destroy(_a),"A destroyed before normal stale sweep")
	if separate_slot:
		var zone: Forage.OpResult = _zones.create_zone(2,1,1000,false,true)
		assert_true(zone.ok,"another valid owner consumes freed Directory slot")
		assert_equal(zone.ref.x,_a.x,"same slot now belongs to another kind")
	var b: Vector2i = _fish.directory().create(Directory.KIND_EXPEDITION)
	assert_equal(_fish.directory().get_typed_row(b),_row,"Expedition typed row reused")
	assert_equal(b.x != _a.x,separate_slot,"requested slot reuse case")
	assert_equal(b.y == _a.y,separate_slot,"equal generation on different slots is legal")
	return b

func _check_replacement_cannot_inherit(b: Vector2i) -> void:
	assert_equal(_fish.effort_claim_expedition_ref_of(_row),_a,"stale original full pair retained")
	var query = _fish.effort_claim_row_of(b)
	assert_false(query.ok,"B cannot query A's claim")
	assert_equal(StringName(query.error),Fish.REFUSE_EFFORT_CLAIM_STALE,"explicit stale owner")
	var release: Fish.OpResult = _fish.release_effort_slots(b)
	assert_false(release.ok,"B cannot release A's effort")
	assert_equal(release.error,Fish.REFUSE_EFFORT_CLAIM_STALE,"release refuses stale ownership")
	var admission: Fish.OpResult = _fish.reserve_effort_slots(b,_job,_habitat,1)
	assert_false(admission.ok,"B cannot overwrite stale row before cleanup")
	assert_equal(admission.error,Fish.REFUSE_EFFORT_CLAIM_STALE,"occupied row is stale, not B's present claim")
	assert_equal(_fish.effort_claim_count(),1,"refusals preserve A's claim")
	assert_false(_fish.validate_effort_aggregates().ok,"legacy audit now refuses stale original owner")
	assert_false(_fish.rebuild_effort_aggregates().ok,"legacy rebuild cannot reinterpret stale claim as B")
	var released: Fish.OpResult = _fish.purge_stale_effort_claims()
	assert_true(released.ok,"normal sweep")
	assert_equal(released.value,1,"release original stale claim exactly once")
	assert_equal(_fish.purge_stale_effort_claims().value,0,"repeat sweep is idempotent")
	assert_true(_fish.validate_effort_aggregates().ok,"normal cleanup restores auditable live state")
	assert_true(_fish.reserve_effort_slots(b,_job,_habitat,4).ok,"B now claims all four river effort slots")
	assert_equal(_fish.effort_claim_expedition_ref_of(_row),b,"new claim belongs to B exactly")
	assert_true(_fish.release_effort_slots(b).ok,"new owner release succeeds")

func test_different_directory_slot_equal_generation_cannot_inherit_claim() -> void:
	_check_replacement_cannot_inherit(_replacement(true))

func test_same_directory_slot_new_generation_cannot_inherit_claim() -> void:
	_check_replacement_cannot_inherit(_replacement(false))

func test_structural_restore_keeps_stale_full_pair_before_normal_cleanup() -> void:
	var b: Vector2i = _replacement(true)
	var block: Codec.OwnerRecord = Codec.OwnerRecord.new(0,512,PackedInt64Array())
	var clock: Clock = Clock.new()
	assert_true(clock.acquire_load_barrier().is_ok(),"adapter barrier")
	assert_true(Adapter.capture_fishing_into(_fish,block).is_ok(),"stale claim capture")
	assert_true(Adapter.apply_fishing(block,_fish,clock).is_ok(),"exact claim restore without repairing identity")
	_check_replacement_cannot_inherit(b)

func test_two_live_equal_generation_expeditions_retain_separate_claims() -> void:
	var b: Vector2i = _fish.directory().create(Directory.KIND_EXPEDITION)
	assert_equal(b.y,_a.y,"fresh slots share generation1")
	assert_true(b.x != _a.x,"different Directory slots")
	assert_true(_fish.reserve_effort_slots(b,_job,_habitat,2).ok,"B owns remaining effort")
	assert_equal(_fish.effort_claim_expedition_ref_of(_row),_a,"A identity")
	assert_equal(_fish.effort_claim_expedition_ref_of(_fish.directory().get_typed_row(b)),b,"B identity")
	assert_true(_fish.release_effort_slots(_a).ok,"A release")
	assert_equal(_fish.effort_claim_count(),1,"B unaffected")
	assert_true(_fish.effort_claim_row_of(b).ok,"B still owns its row")
	assert_true(_fish.release_effort_slots(b).ok,"B release")
	assert_equal(_fish.effort_claim_count(),0,"both properly closed")

func test_appended_owner_slot_validates_after_existing_quantity_field() -> void:
	var columns: Fish.EffortClaimColumns = Fish.EffortClaimColumns.new()
	assert_true(_fish.copy_effort_claim_columns_into(columns),"actual live source")
	columns.effort_claim_expedition_slot[_row] = -1
	columns.effort_claim_slot_count[_row] = 7
	assert_false(_fish.restore_effort_claim_columns(columns),"two defects refuse")
	assert_equal(_fish.last_claim_column_refusal(),&"COLUMN_FISH_CLAIM_SLOT_COUNT","ordinal6 precedes appended ordinal7")
	columns.effort_claim_slot_count[_row] = 2
	assert_false(_fish.restore_effort_claim_columns(columns),"new slot itself refuses")
	assert_equal(_fish.last_claim_column_refusal(),&"COLUMN_FISH_CLAIM_REF","appended Directory slot checked")
	var present: Fish.OpResult = _fish.reserve_effort_slots(_a,_job,_habitat,1)
	assert_equal(present.error,Fish.REFUSE_EFFORT_CLAIM_PRESENT,"exact original full pair remains present")

func test_adapter_keeps_codec_precedence_before_owner_payload_precedence() -> void:
	var block: Codec.OwnerRecord = Codec.OwnerRecord.new(0,512,PackedInt64Array())
	var clock: Clock = Clock.new()
	assert_true(clock.acquire_load_barrier().is_ok(),"held adapter barrier")
	assert_true(Adapter.capture_fishing_into(_fish,block).is_ok(),"capture exact source")
	var slots: PackedInt32Array = block.i32_column(7)
	slots[_row] = -1
	block.i32_columns[Codec.storage_index_of(0,7)] = slots
	var quantities: PackedInt32Array = block.i32_column(6)
	quantities[_row] = 7
	block.i32_columns[Codec.storage_index_of(0,6)] = quantities
	var refusal = Adapter.apply_fishing(block,_fish,clock)
	assert_false(refusal.is_ok(),"two defects refuse before publication")
	assert_equal(refusal.code,&"SAVE_INV_SLOT_RANGE","codec slots gate precedes stronger owner quantity gate")
	assert_equal(_fish.effort_claim_expedition_ref_of(_row),_a,"original owner remains intact")
	assert_equal(_fish.effort_claim_slot_count_of(_row).value,2,"original quantity remains intact")
