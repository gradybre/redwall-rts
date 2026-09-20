# godot/scripts/core/forage.gd immutable source excerpts

## Lines 2070–2225
```gdscript
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_enabled[slot] != 1:
		return REFUSE_ZONE_DISABLED
	if _zone_protected[slot] == 1:
		return REFUSE_ZONE_PROTECTED
	return REFUSE_NONE


# --- decision 0030 §4.3: ForageClaim lifecycle ----------------------------------------------------

func claim_count() -> int:
	"""Number of active forage claims across the whole 8192-row table."""
	return _claim_count


func is_claim_active(row: int) -> bool:
	"""True when `row` is in range and holds an active claim."""
	return row >= 0 and row < FORAGE_CLAIM_CAPACITY and _claim_active[row] == 1


func claim_row_of(job_ref: Vector2i) -> IntMath.IntResult:
	"""The claim row a Job owns, or an explicit refusal naming why it owns none."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	claim_row_of_into(job_ref, out)
	return out


func claim_row_of_into(job_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating claim_row_of(): validate the Job reference AND its generation into `out`.

	R05-QUOTA-023: a retired or reused Job row must not leave a prior generation's claim usable.
	The claim stores the reference it was created with, so a row whose Job has been destroyed and
	replaced refuses with CLAIM_STALE_JOB instead of acting for the newcomer.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	var row: int = _directory.get_typed_row(job_ref)
	if row < 0 or row >= FORAGE_CLAIM_CAPACITY:
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	if _claim_active[row] != 1:
		return out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
	if _claim_job_slot[row] != job_ref.x or _claim_job_generation[row] != job_ref.y:
		return out.refuse(String(REFUSE_CLAIM_STALE_JOB))
	return out.succeed(row)


func claim_remaining_milli_of(row: int) -> IntMath.IntResult:
	"""The uncollected quantity a claim still promises its owning Job."""
	return _read_claim(row, _claim_remaining_milli)


func claim_created_tick_of(row: int) -> IntMath.IntResult:
	"""The owning Job's `created_tick`, cached at claim time: §4.5's first release-order term."""
	return _read_claim(row, _claim_created_tick)


func claim_persistent_id_of(row: int) -> IntMath.IntResult:
	"""The owning Job's persistent ID, cached at claim time: §4.5's release-order tiebreak."""
	return _read_claim(row, _claim_persistent_id)


func _read_claim(row: int, column: PackedInt64Array) -> IntMath.IntResult:
	"""Read one int64 claim column of an active row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_claim_active(row):
		out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
		return out
	out.succeed(column[row])
	return out


func claim_kind_of(row: int) -> IntMath.IntResult:
	"""Which of §5.5's five forage rows a claim names. One claim names exactly one kind."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_claim_active(row):
		out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
		return out
	out.succeed(_claim_patch_kind[row])
	return out


func claim_job_ref_of(row: int) -> Vector2i:
	"""The owning Job reference of an active claim, or the §4.1 null reference `(-1, 0)`."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_job_slot[row], _claim_job_generation[row])


func claim_designation_ref_of(row: int) -> Vector2i:
	"""The designation an active claim harvests through, or the §4.1 null reference."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_designation_slot[row], _claim_designation_generation[row])


func claim_basin_ref_of(row: int) -> Vector2i:
	"""The basin an active claim draws stock from, or the §4.1 null reference."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_basin_slot[row], _claim_basin_generation[row])


func claim_forage(job_ref: Vector2i, designation_ref: Vector2i, kind: int, amount_milli: int,
		season: int, intensive: bool) -> OpResult:
	"""Reserve the COMPLETE intended collection for one Job. Returns its claim row.

	R05-QUOTA-005: quota and stock are preflighted and committed atomically, or every quantity is
	left unchanged. One pending claim per owning Job, naming one basin, one designation and one
	kind, so a second kind needs a second Job; shared work claims through its COORDINATOR, and a
	member Job is refused rather than reserving the same stock twice. Output capacity, consent and
	destination legality are the caller's preflights and are not checked here (header).
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	var request_code: StringName = _check_claim_request(designation_ref, kind, amount_milli,
		season, intensive)
	if request_code != REFUSE_NONE:
		return _refuse(request_code)
	if not _may_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli,
			_math_c):
		return _refuse(StringName(_math_c.error))
	_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli)
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, amount_milli)
	return _succeed(row, job_ref)


func _check_claim_owner(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Job may own a new forage claim on its own row."""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	if _claim_active[job_slot] != 1:
		return REFUSE_NONE
	if _claim_job_slot[job_slot] == job_ref.x and _claim_job_generation[job_slot] == job_ref.y:
		return REFUSE_CLAIM_PRESENT
	return REFUSE_CLAIM_STALE_JOB


func _check_claim_request(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when the designation, kind, season and amount are claimable.

	Leaves the resolved designation row, basin row and patch row in `_pending_*` for the commit
	that immediately follows. Nothing between the two calls can re-enter this store.
	"""
	var zone_code: StringName = _check_harvest_zone(designation_ref)
	if zone_code != REFUSE_NONE:
		return zone_code
```

## Lines 2265–2308
```gdscript
	if not IntMath.checked_add_into(_zone_quota_reserved_milli[basin_slot], amount_milli, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if designation_slot == basin_slot:
		return true
	if not IntMath.checked_add_into(_zone_quota_reserved_milli[designation_slot], amount_milli,
			out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return true


func _reserve_quota(designation_slot: int, basin_slot: int, amount_milli: int) -> void:
	"""Add one claim to the outstanding totals: the basin always, the designation if different."""
	_zone_quota_reserved_milli[basin_slot] += amount_milli
	if designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] += amount_milli


func _write_claim(row: int, job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		amount_milli: int) -> void:
	"""Write one claim row and cache §4.5's release-order key from the owning Job.

	`created_tick` and the persistent ID are read from the Job exactly once here. Neither can
	change while that Job row lives, and both are rebuilt on load, so this is a cache of the
	Job's own fields and NOT a separate claim creation timestamp.
	"""
	var basin_ref: Vector2i = Vector2i(_zone_ref_slot[_pending_basin_slot],
		_zone_ref_generation[_pending_basin_slot])
	_claim_active[row] = 1
	_claim_job_slot[row] = job_ref.x
	_claim_job_generation[row] = job_ref.y
	_claim_designation_slot[row] = designation_ref.x
	_claim_designation_generation[row] = designation_ref.y
	_claim_basin_slot[row] = basin_ref.x
	_claim_basin_generation[row] = basin_ref.y
	_claim_patch_kind[row] = kind
	_claim_remaining_milli[row] = amount_milli
	_claim_created_tick[row] = _jobs.created_tick_of(row).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)
	_claim_count += 1


func collect_claim(job_ref: Vector2i, amount_milli: int, season: int, intensive: bool)\
		-> OpResult:
	"""Collect part or all of a Job's claim. Returns the amount collected, for one cargo creation.
```

## Lines 2400–2560
```gdscript


func release_claim(job_ref: Vector2i) -> OpResult:
	"""Release a Job's uncollected claim. Returns the row it occupied.

	R05-QUOTA-007's cancellation half. Releasing produces no WU, no XP, no cargo and no refund; it
	returns the uncollected quantity to both applicable allowances and nothing else. Cargo already
	collected under this claim is untouched.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if not claim_row_of_into(job_ref, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	_release_claim_row(row)
	return _succeed(row, job_ref)


func _release_claim_row(row: int) -> void:
	"""Return one claim's uncollected quantity to both allowances and empty its row.

	A zone that no longer exists is skipped rather than written to: destroy_zone() already zeroed
	its totals, and the basin it drew from keeps its own usage either way.
	"""
	var amount: int = _claim_remaining_milli[row]
	var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
	var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
	if basin_slot != EntityDirectory.NULL_SLOT:
		_zone_quota_reserved_milli[basin_slot] -= amount
	if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] -= amount
	_clear_claim_row(row)
	_claim_count -= 1


func _clear_claim_row(row: int) -> void:
	"""Return one claim row to exactly the state _clear_claim_columns() produces."""
	_claim_active[row] = 0
	_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_designation_slot[row] = EntityDirectory.NULL_SLOT
	_claim_designation_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_basin_slot[row] = EntityDirectory.NULL_SLOT
	_claim_basin_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_patch_kind[row] = -1
	_claim_remaining_milli[row] = 0
	_claim_created_tick[row] = 0
	_claim_persistent_id[row] = 0


func _typed_zone_row_of(ref: Vector2i) -> int:
	"""The live HarvestZone row a reference names, or NULL_SLOT when it names none."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return EntityDirectory.NULL_SLOT
	var slot: int = _directory.get_typed_row(ref)
	return slot if is_zone_present(slot) else EntityDirectory.NULL_SLOT


func release_claims_of_zone(ref: Vector2i) -> OpResult:
	"""Release every claim naming this zone as basin or designation. Returns how many went."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_release_claims_of_zone_slot(_math.value), ref)


func _release_claims_of_zone_slot(slot: int) -> int:
	"""Release every claim naming this zone row, in ascending claim-row order."""
	var zone_ref: Vector2i = Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot])
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		var names_zone: bool = ((_claim_basin_slot[row] == zone_ref.x
				and _claim_basin_generation[row] == zone_ref.y)
			or (_claim_designation_slot[row] == zone_ref.x
				and _claim_designation_generation[row] == zone_ref.y))
		if not names_zone:
			continue
		_release_claim_row(row)
		released += 1
	return released


func purge_stale_claims() -> OpResult:
	"""Release every claim whose owning Job reference no longer validates. Returns how many.

	R05-QUOTA-023's housekeeping half: a Job destroyed without releasing its claim first leaves a
	row that must not survive into the next Job to occupy it. claim_forage() refuses such a row
	explicitly rather than reclaiming it silently, so this is the only path that clears it.
	"""
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		if _directory.is_valid_of_kind(claim_job_ref_of(row), EntityDirectory.KIND_JOB):
			continue
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func release_cancelled_claims() -> OpResult:
	"""R05-QUOTA-007: release the claims of Jobs that are cancelled or gone. Returns how many.

	The LEASE-EXPIRY half of that requirement is unreachable: jobs.gd records that `lease_expiry`
	exists, is always 0 and is never written because ARCH-JOB-004 is unimplemented. Nothing here
	invents an expiry rule to fire on.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		if not _claim_is_cancelled(row):
			continue
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func _claim_is_cancelled(row: int) -> bool:
	"""True when a claim's owning Job is gone, replaced, or in JobState CANCELLED."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return true
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.state_into(job_slot, _math_c):
		return true
	return _math_c.value == JobsScript.JOB_STATE_CANCELLED


# --- decision 0030 §4.5: reconciliation by whole claims, newest first ------------------------------

func reconcile_claims(season: int) -> OpResult:
	"""Release whole claims, newest first, until every applicable limit is satisfied.

	Ruling §4.5: `maximum_outstanding_claims = max(0, Q - H)`, and excess is removed by releasing
	WHOLE claims in `(job.created_tick, job.persistent_id)` DESCENDING order -- a job's promised
	collection is never silently shrunk. One global order serves every zone at once, so a claim
	over on either of its two applicable limits is released exactly once. Returns the count.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	var released: int = 0
	while true:
		var row: int = _newest_over_claim(season)
		if row == NO_CLAIM:
			break
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func _newest_over_claim(season: int) -> int:
	"""The newest active claim whose basin or designation is over its allowance, or NO_CLAIM."""
	var best: int = NO_CLAIM
	var best_tick: int = 0
	var best_id: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or not _claim_is_over_allowance(row, season):
```

## Lines 2712–2790
```gdscript

# --- decision 0030 §4.7: the load path and its derived aggregates ----------------------------------

func restore_claim(job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		remaining_milli: int) -> OpResult:
	"""Write one saved claim record WITHOUT touching the derived reservation totals.

	R05-QUOTA-022's load half. A loader restores authoritative claim records and then calls
	rebuild_reservation_aggregates() before any admission or collection resumes; that is why this
	deliberately leaves `quota_reserved_milli` alone rather than maintaining it. It performs NO
	quota or stock preflight either: the world being restored already committed those. References,
	the patch kind and a positive quantity ARE validated, because a save that fails them must be
	refused rather than loaded.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if remaining_milli <= 0 or remaining_milli > MANUAL_QUOTA_MAX_MILLI:
		return _refuse(REFUSE_INVALID_AMOUNT)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	if not is_patch_kind(kind):
		return _refuse(REFUSE_INVALID_PATCH_KIND)
	if not zone_slot_of_into(designation_ref, _math):
		return _refuse(StringName(_math.error))
	_pending_designation_slot = _math.value
	if not patch_row_for_zone_into(designation_ref, kind, _math):
		return _refuse(StringName(_math.error))
	_pending_patch_row = _math.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, remaining_milli)
	return _succeed(row, job_ref)


func rebuild_reservation_aggregates() -> OpResult:
	"""Rebuild every derived quota total from the claim table. Returns the claims counted.

	Ruling §4.7: "For each zone, reconstruct its outstanding total by summing active claims for
	which it is the basin or designation, COUNTING A CLAIM ONCE when those references are
	identical." Every zone total is zeroed first, so a stale cache cannot survive as an addend,
	and the release-order keys are re-read from the owning Jobs at the same time.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	_zone_quota_reserved_milli.fill(0)
	var counted: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		counted += 1
		_refresh_claim_order_key(row)
		var amount: int = _claim_remaining_milli[row]
		var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
		var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
		if basin_slot != EntityDirectory.NULL_SLOT:
			_zone_quota_reserved_milli[basin_slot] += amount
		if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
			_zone_quota_reserved_milli[designation_slot] += amount
	_claim_count = counted
	return _succeed(counted, NULL_REF)


func _refresh_claim_order_key(row: int) -> void:
	"""Re-read §4.5's release-order key from the owning Job, leaving it alone when the Job is gone."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return
	var job_slot: int = _directory.get_typed_row(job_ref)
	_claim_created_tick[row] = _jobs.created_tick_of(job_slot).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)


func claim_payload_bytes() -> int:
	"""Packed bytes of the ForageClaim columns the ruling specifies, from their actual sizes."""
	return (_claim_active.size() * BYTES_PER_BYTE_COLUMN
		+ (_claim_job_slot.size() + _claim_job_generation.size()
			+ _claim_designation_slot.size() + _claim_designation_generation.size()
			+ _claim_basin_slot.size() + _claim_basin_generation.size()
```
