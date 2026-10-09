extends "res://test/framework/test_case.gd"
## `save_owner_jobs.gd`: the joint section 4 + section 5 capture/apply bridge (ADR 1222 step 3).
##
## Captures a busy store into a section-4 FramedOwner and a section-5 Block, carries both through
## their real wire codecs, and applies them into a DIFFERENT store over separately restored
## collaborators; every refusal must leave the target byte-identical.

const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_jobs.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")

const WORK_HOUR: int = 8

var _store: JobsScript = null


func before_each() -> void:
	"""A fresh store over a fresh resident cohort, populated with a party, a worker and holes."""
	_store = JobsScript.new()
	_store.residents().spawn_initial_settlement()
	var filler: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_HAUL, 1, 0, 10, 1)
	var haul: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_HAUL, 3, 0, 8000, 5)
	var party: int = _store.create_job(JobsScript.JOB_KIND_BUILD, 4, 0, 12000, 6).value
	_store.make_coordinator(party)
	var member: int = _store.create_job(JobsScript.JOB_KIND_BUILD, 4, 0, 0, 7).value
	_store.set_coordinator(member, party)
	_store.priorities().spawn(0)
	_store.schedule().spawn(0, _store.schedule().default_template_id().value)
	_store.schedule().resolve(0, WORK_HOUR, false)
	_store.spawn_agent(0)
	_store.assign_worker(0, haul.value)
	_store.destroy_job(filler.value)


func _target() -> JobsScript:
	"""A different store over a directory and resident store restored from `_store`'s."""
	var active: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()
	active.resize(EntityDirectory.DIRECTORY_CAPACITY)
	retired.resize(EntityDirectory.DIRECTORY_CAPACITY)
	generation.resize(EntityDirectory.DIRECTORY_CAPACITY)
	persistent_id.resize(EntityDirectory.DIRECTORY_CAPACITY)
	kind.resize(EntityDirectory.DIRECTORY_CAPACITY)
	typed_row.resize(EntityDirectory.DIRECTORY_CAPACITY)
	_store.directory().copy_columns_into(active, generation, retired, persistent_id, kind,
		typed_row)
	var directory: EntityDirectory = EntityDirectory.new()
	assert_true(directory.restore_columns(active, generation, retired, persistent_id, kind,
		typed_row), "section 3 restores")
	var residents: ResidentsScript = ResidentsScript.new(directory, null)
	var resident_columns: ResidentsScript.Columns = ResidentsScript.Columns.new()
	_store.residents().copy_columns_into(resident_columns)
	residents.restore_columns(resident_columns)
	return JobsScript.new(residents, null, null)


func _captured() -> Array:
	"""[FramedOwner, Block] captured from `_store`, through both wire codecs and back."""
	var record: Section.FramedOwner = Section.FramedOwner.new(Bridge.OWNER_INDEX)
	var state: ChildSection.State = ChildSection.State.new()
	var block: ChildSection.Block = state.block(Bridge.CHILD_OWNER_INDEX)
	var refusal: Variant = Bridge.capture_into(_store, record, block)
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	var out: ChildSection.EncodeResult = ChildSection.EncodeResult.new()
	assert_true(ChildSection.encode_section(state, out), "section 5 encodes")
	var decoded: ChildSection.State = ChildSection.State.new()
	assert_true(ChildSection.decode_section(out.bytes, 0, out.bytes.size(), decoded).is_ok(),
		"section 5 decodes")
	return [record, decoded.block(Bridge.CHILD_OWNER_INDEX)]


func test_capture_then_apply_into_a_different_store_is_byte_identical() -> void:
	"""Both halves round-trip and the restored store equals the source's whole image."""
	var pair: Array = _captured()
	var target: JobsScript = _target()
	var refusal: Variant = Bridge.apply(pair[0], pair[1], target)
	assert_true(refusal.is_ok(), "apply: %s %s" % [refusal.code, refusal.detail])
	assert_true(target.state_bytes() == _store.state_bytes(), "the stores agree byte for byte")
	assert_equal(target.job_count(), _store.job_count(), "live jobs recounted")


func test_a_corrupt_child_chain_refuses_and_writes_nothing() -> void:
	"""A member chain naming a free row is refused by the store, with its exact column code."""
	var pair: Array = _captured()
	var block: ChildSection.Block = pair[1]
	var next: PackedInt32Array = block.i32_column(Bridge.CHILD_MEMBER_NEXT)
	next[0] = 4000
	assert_true(block.set_i32_column(Bridge.CHILD_MEMBER_NEXT, next).is_ok(), "corrupt it")
	var target: JobsScript = _target()
	var before: PackedByteArray = target.state_bytes()
	var refusal: Variant = Bridge.apply(pair[0], block, target)
	assert_false(refusal.is_ok(), "the corrupt chain is refused")
	assert_true(String(refusal.code).begins_with("COLUMN_"), "the store's own column code")
	assert_true(target.state_bytes() == before, "nothing was written")


func test_wrong_or_missing_records_refuse_before_the_store() -> void:
	"""Null records, other owners and a null store each refuse with their exact code."""
	var pair: Array = _captured()
	var target: JobsScript = _target()
	var before: PackedByteArray = target.state_bytes()
	assert_equal(Bridge.apply(null, pair[1], target).code, Section.REFUSE_OWNER, "no record")
	assert_equal(Bridge.apply(Section.FramedOwner.new(6), pair[1], target).code,
		Section.REFUSE_OWNER, "another section 4 owner")
	assert_equal(Bridge.apply(pair[0], ChildSection.State.new().block(0), target).code,
		Bridge.REFUSE_CHILD_SHAPE, "another section 5 owner")
	assert_equal(Bridge.apply(pair[0], pair[1], null).code, Bridge.REFUSE_NULL_STORE, "no store")
	assert_equal(Bridge.capture_into(null, pair[0], pair[1]).code, Bridge.REFUSE_NULL_STORE,
		"capture from no store")
	assert_true(target.state_bytes() == before, "no refusal wrote anything")
