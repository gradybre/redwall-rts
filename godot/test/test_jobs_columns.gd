extends "res://test/framework/test_case.gd"
## `jobs.gd`'s ARCH-SAVE-002 sections 4 and 5 bulk column API (decision 0132).
##
## This store owns rows in two sections and one `Columns` object carries both, so the suite has
## to prove four things the smaller stores do not:
##   1. The §4 and §5 ORDINAL TABLES are each their own section's, re-read from the registry
##      artifact rather than transcribed a second time here.
##   2. Every category-2 member is REBUILT and not carried -- the persistent-ID caches, the
##      ordered live index, the bucket bounds and the continuation bound. The last is checked
##      BEHAVIOURALLY: a restored continuation must still be invalidated by a later admission,
##      which only happens if the bound came back with it.
##   3. Membership ORDER survives verbatim, because the registry says the chain is written and
##      not re-derived.
##   4. The worker binding holds in BOTH directions.
##
## Sections 3 and the resident store are restored first, through their own published APIs, because
## this store's restore resolves every live job and agent through them.

const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"
const OWNER_KEY: String = "jobs"
## An hour the default schedule template marks WORK, so §5.3 eligibility can resolve.
const WORK_HOUR: int = 8

var _store: JobsScript = null
var _columns: JobsScript.Columns = null
var _coordinator: int = -1
var _first_member: int = -1
var _second_member: int = -1
var _worked_job: int = -1
var _released_job: int = -1
var _reused_job: int = -1


func before_each() -> void:
	"""A fresh store over a fresh resident cohort, and a fresh caller-owned column image."""
	_store = JobsScript.new()
	_store.residents().spawn_initial_settlement()
	_columns = JobsScript.Columns.new()


func _populate() -> void:
	"""A busy store: three urgency runs, a two-member party, a bound worker and a released row.

	The first job is created and destroyed so the LAST job created reuses its low slot with a
	HIGH persistent ID. That makes ascending-slot order and ascending-ID order disagree inside
	one urgency run, which is the only way a test can tell the two apart -- in a store built
	strictly by creation order they are the same sequence and an index sorted by the wrong key
	would pass.
	"""
	var filler: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_HAUL, 1, 0, 10, 1)
	var rescue: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_HEAL, 9, 0, 500, 4)
	_store.set_urgency(rescue.value, JobsScript.URGENCY_RESCUE)
	var haul: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_HAUL, 3, 0, 8000, 5)
	_worked_job = haul.value
	var party: JobsScript.OpResult = _store.create_job(JobsScript.JOB_KIND_BUILD, 4, 0, 12000, 6)
	_coordinator = party.value
	_store.make_coordinator(_coordinator)
	_first_member = _store.create_job(JobsScript.JOB_KIND_BUILD, 4, 0, 0, 7).value
	_second_member = _store.create_job(JobsScript.JOB_KIND_BUILD, 4, 0, 0, 8).value
	_store.set_coordinator(_first_member, _coordinator)
	_store.set_coordinator(_second_member, _coordinator)
	_store.set_urgency(_second_member, JobsScript.URGENCY_COSMETIC)
	_ready_worker(0)
	_ready_worker(1)
	_store.assign_worker(0, _worked_job)
	_store.set_station_gate(_first_member, JobsScript.GATE_UNAVAILABLE)
	_store.refresh_hazard_latch(1)
	_released_job = _store.create_job(JobsScript.JOB_KIND_COOK, 1, 0, 40, 9).value
	_store.destroy_job(_released_job)
	_store.destroy_job(filler.value)
	_reused_job = _store.create_job(JobsScript.JOB_KIND_TEND, 2, 0, 30, 10).value


func _ready_worker(slot: int) -> void:
	"""Give one resident the priorities and schedule rows §5.3 eligibility needs, then an agent.

	Eligibility refuses STEP2_ACTIVITY_UNRESOLVED until the hour is resolved, so a fixture that
	skipped this would bind no worker at all and the binding tests would pass vacuously.
	"""
	_store.priorities().spawn(slot)
	_store.schedule().spawn(slot, _store.schedule().default_template_id().value)
	_store.schedule().resolve(slot, WORK_HOUR, false)
	_store.spawn_agent(slot)


func _restored_copy() -> JobsScript:
	"""A DIFFERENT store over a separately restored directory and resident store."""
	var target_directory: EntityDirectory = EntityDirectory.new()
	_copy_directory_into(target_directory)
	var target_residents: ResidentsScript = ResidentsScript.new(target_directory, null)
	var resident_columns: ResidentsScript.Columns = ResidentsScript.Columns.new()
	_store.residents().copy_columns_into(resident_columns)
	target_residents.restore_columns(resident_columns)
	var target: JobsScript = JobsScript.new(target_residents, null, null)
	_store.copy_columns_into(_columns)
	target.restore_columns(_columns)
	return target


func _copy_directory_into(target: EntityDirectory) -> void:
	"""Move section 3 across through `entity_directory.gd`'s own bulk column API."""
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
	target.restore_columns(active, generation, retired, persistent_id, kind, typed_row)


func _fields_of(section_id: int) -> Array:
	"""The registry artifact's field list for one of this owner's two sections."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	var owners: Array = (JSON.parse_string(text) as Dictionary)["owners"] as Array
	for owner: Variant in owners:
		var group: Dictionary = owner as Dictionary
		if int(group["section_id"]) == section_id and String(group["owner_key"]) == OWNER_KEY:
			return group["fields"] as Array
	return []


func _assert_order(fields: Array, keys: Array[StringName], types: Array[int],
		extents: Array[int], label: String) -> void:
	"""Compare one section's published order against the artifact, ordinal by ordinal."""
	assert_equal(fields.size(), keys.size(), label + " field count")
	for entry: Variant in fields:
		var field: Dictionary = entry as Dictionary
		var ordinal: int = int(field["ordinal"])
		assert_equal(String(field["field_key"]), String(keys[ordinal]),
			"%s ordinal %d key" % [label, ordinal])
		assert_equal(int(field["type_code"]), types[ordinal],
			"%s ordinal %d type code" % [label, ordinal])
		var shape: Dictionary = field["shape"] as Dictionary
		assert_true(String(shape["declared_capacity"]).contains(str(extents[ordinal])),
			"%s ordinal %d declared extent" % [label, ordinal])


# --- the published order is the registry's ------------------------------------------------------

func test_section_four_column_order_matches_the_canonical_registry_artifact() -> void:
	"""Thirty-eight COMPONENT_COLUMNS ordinals, re-read from disk rather than transcribed twice."""
	var fields: Array = _fields_of(4)
	assert_equal(fields.size(), JobsScript.SECTION4_COLUMN_COUNT, "jobs publishes 38 §4 columns")
	_assert_order(fields, JobsScript.SECTION4_COLUMN_KEYS, JobsScript.SECTION4_COLUMN_TYPE_CODES,
		JobsScript.SECTION4_COLUMN_EXTENTS, "section 4")


func test_section_five_column_order_matches_the_canonical_registry_artifact() -> void:
	"""The four CHILD_ARENAS ordinals are their OWN section's, numbered from zero again."""
	var fields: Array = _fields_of(5)
	assert_equal(fields.size(), JobsScript.SECTION5_COLUMN_COUNT, "jobs publishes 4 §5 columns")
	_assert_order(fields, JobsScript.SECTION5_COLUMN_KEYS, JobsScript.SECTION5_COLUMN_TYPE_CODES,
		JobsScript.SECTION5_COLUMN_EXTENTS, "section 5")


func test_the_two_sections_do_not_share_a_column() -> void:
	"""A column in both tables would be written twice and could disagree with itself."""
	for key: StringName in JobsScript.SECTION5_COLUMN_KEYS:
		assert_false(JobsScript.SECTION4_COLUMN_KEYS.has(key), "%s belongs to one section" % key)
	assert_equal(JobsScript.SECTION4_COLUMN_KEYS.size(), JobsScript.SECTION4_COLUMN_COUNT,
		"section 4 key table length")
	assert_equal(JobsScript.SECTION5_COLUMN_KEYS.size(), JobsScript.SECTION5_COLUMN_COUNT,
		"section 5 key table length")


# --- round trip -----------------------------------------------------------------------------------

func test_a_populated_store_round_trips_into_a_different_instance() -> void:
	"""Capture, restore over separately restored collaborators, and compare the whole image."""
	_populate()
	var target: JobsScript = _restored_copy()
	assert_equal(target.last_column_refusal(), JobsScript.REFUSE_NONE, "restore accepted")
	assert_true(target.state_bytes() == _store.state_bytes(), "the two stores agree byte for byte")
	assert_equal(target.job_count(), _store.job_count(), "the live job count was recounted")
	assert_equal(target.agent_count(), _store.agent_count(), "the agent count was recounted")


func test_the_ordered_live_index_is_rebuilt_in_the_same_order() -> void:
	"""`_live_slots` is category 2: declared-urgency runs, ascending persistent ID inside each."""
	_populate()
	var target: JobsScript = _restored_copy()
	assert_true(_store.job_count() > 3, "the fixture has several live jobs")
	assert_equal(_reused_job, 0, "the last job created reused the lowest free row")
	assert_true(_store.job_id_of(_reused_job).value > _store.job_id_of(_worked_job).value,
		"and carries a higher persistent ID than the jobs already in its run")
	for index: int in _store.job_count():
		assert_equal(target.live_job_at(index).value, _store.live_job_at(index).value,
			"live index position %d" % index)
	assert_true(_descends_somewhere_inside_a_run(target),
		"a run is ordered by persistent ID, and this fixture proves that is not slot order")
	assert_equal(target.job_id_of(_coordinator).value, _store.job_id_of(_coordinator).value,
		"the persistent-ID cache was refilled from section 3")


func test_every_released_job_row_passes_the_stores_own_residue_check() -> void:
	"""The incoming free-row rule and `inactive_job_row_is_clear()` must not drift apart."""
	_populate()
	var target: JobsScript = _restored_copy()
	assert_false(target.is_job_present(_released_job), "the destroyed row is still free")
	assert_true(target.inactive_job_row_is_clear(_released_job),
		"and the store's own residue check passes on it after a restore")
	assert_equal(target.job_id_of(_released_job).ok, false, "no reader answers for a free row")


func test_membership_order_survives_verbatim() -> void:
	"""The registry says the chain is written because its order is observable; prove it is."""
	_populate()
	var target: JobsScript = _restored_copy()
	assert_true(target.is_coordinator(_coordinator), "the coordinator flag survived")
	assert_equal(target.member_count_of(_coordinator).value, 2, "with both members")
	var source_order: PackedInt32Array = _member_order(_store, _coordinator)
	var target_order: PackedInt32Array = _member_order(target, _coordinator)
	assert_equal(target_order.size(), source_order.size(), "the same number of members")
	assert_true(target_order == source_order, "in exactly the same order")


func _descends_somewhere_inside_a_run(store: JobsScript) -> bool:
	"""True when two ADJACENT jobs of the same urgency sit in descending SLOT order.

	An index sorted by slot can never do that, so this is the property that separates the two
	possible sort keys. It is asserted rather than assumed about the fixture.
	"""
	for index: int in range(1, store.job_count()):
		var here: int = store.live_job_at(index).value
		var previous: int = store.live_job_at(index - 1).value
		if here < previous and store.urgency_of(here).value == store.urgency_of(previous).value:
			return true
	return false


func _member_order(store: JobsScript, coordinator: int) -> PackedInt32Array:
	"""Walk one coordinator's party through the published iteration pair."""
	var order: PackedInt32Array = PackedInt32Array()
	var cursor: IntMath.IntResult = IntMath.IntResult.new()
	if not store.first_member_into(coordinator, cursor):
		return order
	order.append(cursor.value)
	while store.next_member_into(order[order.size() - 1], cursor):
		order.append(cursor.value)
	return order


func test_the_worker_binding_survives_in_both_directions() -> void:
	"""A job's worker and an agent's job are two halves of one fact and both must come back."""
	_populate()
	var target: JobsScript = _restored_copy()
	assert_false(target.is_agent_idle(0), "agent 0 still holds a job")
	assert_equal(target.job_of(0), _store.job_of(0), "the same job reference")
	assert_equal(target.worker_of(_worked_job), _store.worker_of(_worked_job), "the same worker")
	assert_true(target.is_agent_idle(1), "agent 1 is still idle")


func test_a_restored_continuation_is_still_invalidated_by_a_later_admission() -> void:
	"""The continuation BOUND is rebuilt, and this is the only way to observe that it was.

	`_admit_into()` skips the agent walk entirely when the admitted bucket is deeper than the
	bound it holds. A restore that left the bound at "nobody is scanning" would therefore leave a
	restored continuation alive through an admission that must clear it -- silently, and only in
	a world loaded from disk.
	"""
	_populate()
	var target: JobsScript = _restored_copy()
	_columns.continuation_bucket[1] = JobsScript.URGENCY_COSMETIC
	_columns.job_scan_cursor[1] = 5
	assert_true(target.restore_columns(_columns), "the continuation restores")
	assert_true(target.has_continuation(1), "and the agent resumes in the cosmetic bucket")
	assert_equal(target.continuation_bucket_of(1).value, JobsScript.URGENCY_COSMETIC, "bucket")
	var admitted: JobsScript.OpResult = target.create_job(JobsScript.JOB_KIND_HAUL, 2, 0, 10, 20)
	assert_true(admitted.ok, "a new ordinary job is admitted")
	assert_false(target.has_continuation(1),
		"which invalidates the deeper continuation, as it would in the world that saved it")


func test_an_empty_columns_object_matches_a_cleared_store() -> void:
	"""`Columns.clear()` reproduces the store's empty state: null pairs and gate NOT_REQUIRED."""
	_populate()
	_store.clear()
	_store.copy_columns_into(_columns)
	var empty: JobsScript.Columns = JobsScript.Columns.new()
	assert_true(_columns.equals(empty), "a cleared store captures the declared unused values")
	assert_equal(empty.station_gate[0], JobsScript.GATE_NOT_REQUIRED, "the unused gate")
	assert_equal(empty.member_head[0], EntityDirectory.NULL_SLOT, "the unused chain link is -1")


# --- refusals leave the store byte-identical ------------------------------------------------------

func _refuses_without_writing(mutate: Callable, expected: StringName, message: String) -> void:
	"""Apply `mutate` to a valid capture, restore it, and require a refusal that wrote nothing."""
	var target: JobsScript = _restored_copy()
	var before: PackedByteArray = target.state_bytes()
	mutate.call(_columns)
	assert_false(target.restore_columns(_columns), message)
	assert_equal(target.last_column_refusal(), expected, message + " refusal code")
	assert_true(target.state_bytes() == before, message + " left the store byte-identical")


func test_a_short_column_refuses_on_shape() -> void:
	"""A buffer of the wrong length is the wrong buffer and is never silently resized."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.member_next.remove_at(0),
		JobsScript.REFUSE_COLUMN_SHAPE, "a short member chain column")


func test_a_reserved_job_kind_refuses() -> void:
	"""Decision 0022: JobKind.RESERVED_3 is not a productive kind and is refused, not clamped."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.kind[_worked_job] = JobsScript.JOB_KIND_RESERVED_INDEX,
		JobsScript.REFUSE_COLUMN_JOB_DEFINITION, "a job of the reserved kind")


func test_an_out_of_domain_gate_byte_refuses() -> void:
	"""Decision 0023's four gate values are the whole domain."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.tool_gate[_worked_job] = JobsScript.GATE_COUNT,
		JobsScript.REFUSE_COLUMN_GATE, "a gate byte past the enumeration")


func test_an_urgency_outside_the_five_buckets_refuses() -> void:
	"""The index is built from this byte, so an out-of-range bucket would corrupt the runs."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.urgency[_worked_job] = JobsScript.URGENCY_COUNT,
		JobsScript.REFUSE_COLUMN_URGENCY, "a sixth urgency bucket")


func test_a_negative_work_total_refuses_and_the_test_proves_it_is_negative() -> void:
	"""THE INT32 SIGN TRAP, kept out of the test: 0x80000000 is positive to a 64-bit int."""
	_populate()
	var trap: int = -2147483648
	assert_true(trap < 0, "the int32 reading of 0x80000000 is negative")
	assert_equal(trap, -2147483647 - 1, "and it is the int32 minimum")
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.remaining_mwu[_worked_job] = trap,
		JobsScript.REFUSE_COLUMN_NEGATIVE_MWU, "the int32 minimum as milli work units")


func test_a_negative_agent_phase_refuses() -> void:
	"""`_agent_phase` is where in the job the resident is; there is no position before the first."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.agent_phase[0] = -1,
		JobsScript.REFUSE_COLUMN_CONTINUATION, "a negative job phase")


func test_a_negative_creation_tick_refuses() -> void:
	"""`_created_tick` orders §5.3 ties, so a tick before the world began would reorder the queue."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.created_tick[_worked_job] = -1,
		JobsScript.REFUSE_COLUMN_NEGATIVE_TICK, "a job created before tick 0")


func test_a_job_occupancy_byte_that_is_neither_zero_nor_one_refuses() -> void:
	"""One byte per row and exactly two legal values, as ARCH-SAVE-002's occupied bitset is."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.job_present[500] = 2,
		JobsScript.REFUSE_COLUMN_PRESENT_BYTE, "a job occupancy byte of 2")


func test_residue_on_a_released_job_row_refuses() -> void:
	"""`_clear_job_row()` leaves nothing behind, so anything left is corruption."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.remaining_mwu[_released_job] = 25,
		JobsScript.REFUSE_COLUMN_FREE_JOB_ROW, "work left on a destroyed job")


func test_a_job_reference_the_directory_does_not_honour_refuses() -> void:
	"""The section 3 dependency, enforced rather than assumed."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.job_ref_generation[_worked_job] = columns.job_ref_generation[_worked_job] + 1,
		JobsScript.REFUSE_COLUMN_DIRECTORY_REF, "a generation the directory has not issued")


func test_an_agent_on_an_absent_resident_refuses() -> void:
	"""A JobAgent row exists only for a present resident, which is why residents restore first."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.agent_present[400] = 1,
		JobsScript.REFUSE_COLUMN_AGENT_RESIDENT, "an agent with no resident")


func test_a_non_zero_reserved_agent_column_refuses() -> void:
	"""The registry says section 4 writes these as zeros and must not repurpose the v1 bytes."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.agent_lease_expiry[0] = 30,
		JobsScript.REFUSE_COLUMN_RESERVED_NONZERO, "a lease expiry with no lease owner")


func test_residue_on_a_released_agent_row_refuses() -> void:
	"""`_clear_agent_row()` zeroes every column, hazard latch included."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.agent_hazard_locked[7] = 1,
		JobsScript.REFUSE_COLUMN_FREE_AGENT_ROW, "a hazard latch on a row with no agent")


func test_a_job_whose_worker_does_not_hold_it_refuses() -> void:
	"""One direction of the binding: a job naming a worker that points somewhere else."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		_unbind_the_agent(columns),
		JobsScript.REFUSE_COLUMN_WORKER_BINDING, "a job named by nobody")


func _unbind_the_agent(columns: JobsScript.Columns) -> void:
	"""Release the agent's side of the binding while the job keeps naming it."""
	columns.agent_job_slot[0] = EntityDirectory.NULL_SLOT
	columns.agent_job_generation[0] = EntityDirectory.NULL_GENERATION


func test_an_agent_holding_a_job_that_names_another_worker_refuses() -> void:
	"""The other direction: the agent's half alone is not enough to make the binding true."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		_unbind_the_job(columns),
		JobsScript.REFUSE_COLUMN_WORKER_BINDING, "an agent holding an unclaimed job")


func _unbind_the_job(columns: JobsScript.Columns) -> void:
	"""Clear the job's worker pair while the agent keeps holding the job."""
	columns.worker_slot[_worked_job] = EntityDirectory.NULL_SLOT
	columns.worker_generation[_worked_job] = EntityDirectory.NULL_GENERATION


func test_two_jobs_claiming_one_worker_refuse() -> void:
	"""One resident cannot work two jobs, and the agent row can only name one of them.

	The two jobs carry the SAME directory generation, so nothing but the slot half of the
	comparison can separate them -- which is the point: a generation check alone would accept
	this.
	"""
	_populate()
	_refuses_without_writing(_claim_the_worker_twice,
		JobsScript.REFUSE_COLUMN_WORKER_BINDING, "two jobs claiming one worker")


func _claim_the_worker_twice(columns: JobsScript.Columns) -> void:
	"""Copy the worked job's worker pair onto a second live job that holds no worker."""
	assert_equal(columns.job_ref_generation[_first_member],
		columns.job_ref_generation[_worked_job], "both jobs are on their first generation")
	columns.worker_slot[_first_member] = columns.worker_slot[_worked_job]
	columns.worker_generation[_first_member] = columns.worker_generation[_worked_job]


func test_a_job_naming_a_worker_who_has_no_agent_row_refuses() -> void:
	"""The released-agent case, reached through a CLEAN free agent row so the free-row rule passes.

	A dropped JobAgent row is the shape a partially applied load produces, and the job it left
	behind still names its worker. The binding walk refuses it rather than restoring a job whose
	worker cannot act.
	"""
	_populate()
	_refuses_without_writing(_drop_the_agent_row,
		JobsScript.REFUSE_COLUMN_WORKER_BINDING, "a worker with no agent row")


func _drop_the_agent_row(columns: JobsScript.Columns) -> void:
	"""Release agent 0 exactly as `despawn_agent()` would, leaving the job still naming it."""
	columns.agent_present[0] = 0
	columns.agent_job_slot[0] = EntityDirectory.NULL_SLOT
	columns.agent_job_generation[0] = EntityDirectory.NULL_GENERATION
	columns.agent_target_slot[0] = EntityDirectory.NULL_SLOT
	columns.agent_target_generation[0] = EntityDirectory.NULL_GENERATION
	columns.agent_phase[0] = 0
	columns.agent_hazard_locked[0] = 0
	columns.job_scan_cursor[0] = 0
	columns.continuation_bucket[0] = 0


func test_a_cyclic_member_chain_refuses_instead_of_hanging() -> void:
	"""The walk is bounded by JOB_CAPACITY, so a cycle is a refusal and never a stall."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.member_next[_first_member] = _first_member,
		JobsScript.REFUSE_COLUMN_MEMBER_CHAIN, "a member linked to itself")


func test_a_member_missing_from_every_chain_refuses() -> void:
	"""The totals prove no member was left out, which no per-node check can see on its own."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.member_head[_coordinator] = EntityDirectory.NULL_SLOT,
		JobsScript.REFUSE_COLUMN_MEMBER_CHAIN, "a party whose head was dropped")


func test_a_chain_head_on_a_job_that_is_not_a_coordinator_refuses() -> void:
	"""Decision 0017 puts the party list on the coordinator row and nowhere else."""
	_populate()
	_refuses_without_writing(func(columns: JobsScript.Columns) -> void:
		columns.is_coordinator[_coordinator] = 0,
		JobsScript.REFUSE_COLUMN_COORDINATOR, "a member list on a plain job")


# --- the refusal namespace is separate ------------------------------------------------------------

func test_a_column_refusal_does_not_touch_the_operation_channel() -> void:
	"""A load must not answer for an operation whose result the caller has not read yet."""
	_populate()
	var refused: JobsScript.OpResult = _store.destroy_job(_worked_job)
	assert_false(refused.ok, "destroying a job that still has a worker refuses")
	assert_equal(refused.error, JobsScript.REFUSE_JOB_HAS_WORKER, "with its own code")
	_store.copy_columns_into(_columns)
	_columns.urgency[_worked_job] = JobsScript.URGENCY_COUNT
	assert_false(_store.restore_columns(_columns), "and the bad restore refuses")
	assert_equal(refused.error, JobsScript.REFUSE_JOB_HAS_WORKER,
		"the operation's own result is untouched by the load")
	assert_true(String(_store.last_column_refusal()).begins_with("COLUMN_"), "prefixed code")


func test_every_published_column_refusal_code_is_prefixed() -> void:
	"""The namespaces cannot collide, because one of them is entirely prefixed."""
	var codes: Array[StringName] = [JobsScript.REFUSE_COLUMN_SHAPE,
		JobsScript.REFUSE_COLUMN_PRESENT_BYTE, JobsScript.REFUSE_COLUMN_FLAG_BYTE,
		JobsScript.REFUSE_COLUMN_URGENCY, JobsScript.REFUSE_COLUMN_GATE,
		JobsScript.REFUSE_COLUMN_JOB_DEFINITION, JobsScript.REFUSE_COLUMN_JOB_STATE,
		JobsScript.REFUSE_COLUMN_NEGATIVE_MWU, JobsScript.REFUSE_COLUMN_NEGATIVE_TICK,
		JobsScript.REFUSE_COLUMN_REF_SHAPE, JobsScript.REFUSE_COLUMN_DIRECTORY_REF,
		JobsScript.REFUSE_COLUMN_FREE_JOB_ROW, JobsScript.REFUSE_COLUMN_FREE_AGENT_ROW,
		JobsScript.REFUSE_COLUMN_AGENT_RESIDENT, JobsScript.REFUSE_COLUMN_RESERVED_NONZERO,
		JobsScript.REFUSE_COLUMN_CONTINUATION, JobsScript.REFUSE_COLUMN_WORKER_BINDING,
		JobsScript.REFUSE_COLUMN_COORDINATOR, JobsScript.REFUSE_COLUMN_MEMBER_CHAIN]
	for code: StringName in codes:
		assert_true(String(code).begins_with("COLUMN_"), "%s is prefixed" % code)
