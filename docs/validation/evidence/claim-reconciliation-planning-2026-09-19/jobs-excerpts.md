# godot/scripts/core/jobs.gd immutable source excerpts

## Lines 914–975
```gdscript
func destroy_job(job_slot: int) -> OpResult:
	"""Release one Job row and its directory slot. Refuses while a worker still holds it.

	Refusing rather than silently unbinding is deliberate: decision 0017 gives worker departure
	and job cancellation separate paths, and a destroy that quietly detached a worker would
	merge them. Call `release_worker()` first.

	A coordinator that still has members is refused for the same reason: releasing it would
	leave every member Job pointing at a dead row, and 0017 requires shared progress and batch
	data to survive a departure, not to be deleted out from under the party. A member is
	unlinked from its coordinator here, which is the only structural change a destroy makes.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if _worker_slot[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_JOB_HAS_WORKER)
	if _member_head[job_slot] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_COORDINATOR_HAS_MEMBERS)
	if _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT:
		_unlink_member(job_slot)
	var ref: Vector2i = ref_of(job_slot)
	_directory.destroy(ref)
	_remove_live_slot(job_slot)
	_job_present[job_slot] = 0
	_clear_job_row(job_slot)
	return _succeed(job_slot, NULL_REF)


func _clear_job_row(job_slot: int) -> void:
	"""Return one released Job row to exactly the state clear() produces.

	Two logically identical worlds must serialize to identical columns, so a destroyed job
	leaves no residue that would change a canonical hash.
	"""
	_kind[job_slot] = JOB_KIND_HAUL
	_priority[job_slot] = 0
	_required_skill[job_slot] = 0
	_state[job_slot] = JOB_STATE_QUEUED
	_remaining_mwu[job_slot] = 0
	_created_tick[job_slot] = 0
	_job_persistent_id[job_slot] = 0
	_urgency[job_slot] = URGENCY_ORDINARY
	_dangerous[job_slot] = 0
	_station_gate[job_slot] = GATE_NOT_REQUIRED
	_tool_gate[job_slot] = GATE_NOT_REQUIRED
	_unlock_gate[job_slot] = GATE_NOT_REQUIRED
	_inputs_gate[job_slot] = GATE_NOT_REQUIRED
	_is_coordinator[job_slot] = 0
	_member_head[job_slot] = EntityDirectory.NULL_SLOT
	_member_next[job_slot] = EntityDirectory.NULL_SLOT
	_set_ref_columns(job_slot, NULL_REF, _coordinator_slot, _coordinator_generation)
	_set_ref_columns(job_slot, NULL_REF, _job_ref_slot, _job_ref_generation)
	_set_ref_columns(job_slot, NULL_REF, _requester_slot, _requester_generation)
	_set_ref_columns(job_slot, NULL_REF, _destination_slot, _destination_generation)
	_set_ref_columns(job_slot, NULL_REF, _source_slot, _source_generation)
	_set_ref_columns(job_slot, NULL_REF, _worker_slot, _worker_generation)


func _insert_live_slot(job_slot: int) -> void:
	"""Insert a job into its declared-urgency run, keeping that run in ascending persistent ID.

```

## Lines 1019–1065
```gdscript
func is_job_present(job_slot: int) -> bool:
	"""True when `job_slot` is in range and holds a live Job row."""
	return _check_job_slot(job_slot) == REFUSE_NONE


func job_count() -> int:
	"""Number of live Job rows."""
	return _live_count


func live_job_at(index: int) -> IntMath.IntResult:
	"""The job slot at `index` of the live index, ordered by declared urgency then persistent ID."""
	if index < 0 or index >= _live_count:
		return _read(REFUSE_INVALID_JOB_SLOT, 0)
	return _read(REFUSE_NONE, _live_slots[index])


func ref_of(job_slot: int) -> Vector2i:
	"""The directory reference owning a Job row, or the null reference when it is empty."""
	if not is_job_present(job_slot):
		return NULL_REF
	return Vector2i(_job_ref_slot[job_slot], _job_ref_generation[job_slot])


func job_id_of(job_slot: int) -> IntMath.IntResult:
	"""The never-reused persistent ID: the last tie-break of the §5.3 sort key, and the ID half of
	decision 0023's continuation key.

	Served from the cached column rather than the directory so the candidate loop, the ordered
	live index and this reader all agree on one number.
	"""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _job_persistent_id[job_slot] if code == REFUSE_NONE else 0)


func kind_of(job_slot: int) -> IntMath.IntResult:
	"""JobKind of a Job row, 0-11 and never the reserved index 3."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _kind[job_slot] if code == REFUSE_NONE else 0)


func priority_of(job_slot: int) -> IntMath.IntResult:
	"""Job.priority: the second term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _priority[job_slot] if code == REFUSE_NONE else 0)


```

## Lines 1111–1137
```gdscript
func remaining_mwu_of(job_slot: int) -> IntMath.IntResult:
	"""Job.remaining_mwu. Stored only: no WU model decrements it in this milestone."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _remaining_mwu[job_slot] if code == REFUSE_NONE else 0)


func created_tick_of(job_slot: int) -> IntMath.IntResult:
	"""Job.created_tick: the fifth term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _created_tick[job_slot] if code == REFUSE_NONE else 0)


func state_of(job_slot: int) -> IntMath.IntResult:
	"""Job.state, one of GDD §4.3's eight JobState values."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _state[job_slot] if code == REFUSE_NONE else 0)


func urgency_of(job_slot: int) -> IntMath.IntResult:
	"""The urgency bucket a job DECLARES, before bucket 2's reserve condition is applied."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _urgency[job_slot] if code == REFUSE_NONE else 0)


func effective_urgency_of(job_slot: int) -> IntMath.IntResult:
	"""The bucket a job actually occupies now: declared, with §5.3's bucket 2 condition applied.

```
