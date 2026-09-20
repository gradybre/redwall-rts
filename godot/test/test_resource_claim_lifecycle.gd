extends "res://test/framework/test_case.gd"
## Public lifecycle witnesses that constrain future save reconciliation; no forged owner state.
const Forage := preload("res://scripts/core/forage.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
var _residents: Residents
var _priorities: Priorities
var _schedule: Schedule
var _jobs: Jobs
var _forage: Forage
var _basin: Vector2i
var _designation: Vector2i
var _job: Vector2i
var _job_row: int

func before_each() -> void:
	_residents = Residents.new()
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents,_priorities,_schedule)
	_forage = Forage.new(null,_jobs)
	var basin = _forage.create_zone(2,1,20000,false,true)
	assert_true(basin.ok,"real basin takes Directory slot before Job")
	_basin = basin.ref
	assert_true(_forage.set_quota_milli(_basin,20000,1).ok,"manual basin quota")
	assert_true(_forage.create_patch(_basin,0,10).ok,"only claimed patch kind exists")
	var designation = _forage.create_zone(2,1,0,false,true)
	assert_true(designation.ok,"designation")
	_designation = designation.ref
	assert_true(_forage.set_basin(_designation,_basin).ok,"actual basin binding")
	var job = _jobs.create_job(4,0,0,0,1234)
	assert_true(job.ok,"claiming Job with distinctive nonzero creation tick")
	_job = job.ref
	_job_row = _jobs.directory().get_typed_row(_job)
	assert_true(_job.x != _job_row,"Directory slot differs from Job typed row")
	var claim = _forage.claim_forage(_job,_designation,0,1000,1,false)
	assert_true(claim.ok,"ordinary claim admission")
	assert_equal(claim.value,_job_row,"claim row IS owning Job typed row")

func after_each() -> void:
	_forage = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null

func test_claim_order_key_uses_the_owning_job_despite_different_directory_slot() -> void:
	assert_equal(_forage.claim_created_tick_of(_job_row).value,1234,"exact owning Job tick")
	assert_equal(_forage.claim_persistent_id_of(_job_row).value,_jobs.directory().get_persistent_id(_job),"exact Directory PID")
	assert_equal(_forage.patch_count_of(_forage.zone_slot_of(_basin).value).value,1,"all five patches are not required")

func test_destroying_basin_releases_other_designations_claims_first() -> void:
	assert_true(_forage.destroy_zone(_basin).ok,"ordinary basin deletion")
	assert_equal(_forage.claim_count(),0,"claim naming basin is released despite different designation")
	assert_equal(_forage.quota_reserved_milli_of(_forage.zone_slot_of(_designation).value).value,0,"surviving designation debited exactly")
	assert_false(_forage.claim_row_of(_job).ok,"no orphan claim survives")

func test_destroying_designation_releases_its_claim_without_resetting_basin_usage() -> void:
	assert_true(_forage.collect_claim(_job,400,1,false).ok,"partial real collection")
	assert_true(_forage.destroy_zone(_designation).ok,"delete designation")
	assert_equal(_forage.claim_count(),0,"remaining claim released")
	assert_equal(_forage.quota_reserved_milli_of(_forage.zone_slot_of(_basin).value).value,0,"basin reservation fully debited")
	assert_equal(_forage.harvested_today_milli_of(_forage.zone_slot_of(_basin).value).value,400,"collected usage remains")

func test_rebinding_designation_releases_old_claim_and_retains_old_basin() -> void:
	var next_basin = _forage.create_zone(2,1,20000,false,true)
	assert_true(next_basin.ok,"second basin")
	assert_true(_forage.set_basin(_designation,next_basin.ref).ok,"ordinary rebind")
	assert_equal(_forage.claim_count(),0,"old basin claim cleared before rebind")
	assert_equal(_forage.quota_reserved_milli_of(_forage.zone_slot_of(_basin).value).value,0,"old basin debited")

func test_claimed_basin_cannot_be_rebound_away_from_its_patch() -> void:
	var next_basin = _forage.create_zone(2,1,20000,false,true)
	assert_true(next_basin.ok,"second basin")
	var refused = _forage.set_basin(_basin,next_basin.ref)
	assert_false(refused.ok,"claimed basin owns a patch and cannot rebind")
	assert_equal(refused.error,Forage.REFUSE_BASIN_HAS_OWN_PATCHES,"explicit owner gate")
	assert_equal(_forage.claim_count(),1,"existing claim unchanged")
	assert_true(_forage.collect_claim(_job,1000,1,false).ok,"claim still collects from original patch")

func test_cancelled_job_claim_waits_for_normal_release_pipeline() -> void:
	assert_true(_jobs.set_state(_job_row,Jobs.JOB_STATE_CANCELLED).ok,"ordinary cancellation")
	assert_equal(_forage.claim_count(),1,"cancellation itself leaves claim")
	assert_equal(_forage.claim_created_tick_of(_job_row).value,1234,"provenance unchanged")
	assert_equal(_forage.release_cancelled_claims().value,1,"normal release clears once")
	assert_equal(_forage.release_cancelled_claims().value,0,"idempotent later pass")

func test_claim_owner_can_become_member_after_admission() -> void:
	var coordinator = _jobs.create_job(4,0,0,100,1235)
	assert_true(coordinator.ok,"coordinator Job")
	var row: int = _jobs.directory().get_typed_row(coordinator.ref)
	assert_true(_jobs.make_coordinator(row).ok,"promote coordinator")
	assert_true(_jobs.set_coordinator(_job_row,row).ok,"existing zero-work owner may become member")
	assert_true(_jobs.is_member(_job_row),"new membership is real")
	assert_equal(_forage.claim_count(),1,"membership alone does not release saved claim")
	assert_equal(_forage.claim_created_tick_of(_job_row).value,1234,"order key remains its own Job tick")
