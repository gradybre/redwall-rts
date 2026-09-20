# godot/scripts/core/fishing.gd immutable source excerpts

## Lines 1435–1568
```gdscript
func reserve_effort_slots(expedition_ref: Vector2i, job_ref: Vector2i, habitat_ref: Vector2i,
		slot_count: int) -> OpResult:
	"""Reserve a cycle's WHOLE effort requirement at once. Returns the slots now taken.

	REQ-SET-050: "While a habitat's effort slots are occupied, the system shall queue further
	fishers rather than multiply yield with unbounded workers." This is the half that makes
	queueing necessary; the queue itself is the Job store's `JobState.QUEUED`.

	Ruling §5: the claim and the occupancy change are published TOGETHER, and a request that does
	not fit refuses without taking a single slot -- two single-slot calls without rollback are not
	a safe two-slot admission API. The claim row is the Expedition's typed row and only its
	coordinator Job may own it.
	"""
	var code: StringName = _refuse_effort_reservation(expedition_ref, job_ref, habitat_ref,
		slot_count)
	if code != REFUSE_NONE:
		return _refuse(code)
	var habitat_slot: int = _pending_habitat_slot
	_write_effort_claim(_pending_claim_row, expedition_ref, job_ref, habitat_ref, slot_count)
	_habitat_effort_used[habitat_slot] += slot_count
	return _succeed(_habitat_effort_used[habitat_slot], habitat_ref)


func _refuse_effort_reservation(expedition_ref: Vector2i, job_ref: Vector2i,
		habitat_ref: Vector2i, slot_count: int) -> StringName:
	"""REFUSE_NONE when this cycle may take `slot_count` slots, with nothing written yet.

	Leaves the claim row and the habitat row in `_pending_*` for the commit that follows.
	"""
	var code: StringName = _refuse_effort_owner(expedition_ref, job_ref)
	if code != REFUSE_NONE:
		return code
	if not habitat_slot_of_into(habitat_ref, _math):
		return StringName(_math.error)
	_pending_habitat_slot = _math.value
	if slot_count <= 0:
		return REFUSE_INVALID_SLOT_COUNT
	var free: int = _habitat_effort_slots[_pending_habitat_slot] \
		- _habitat_effort_used[_pending_habitat_slot]
	if slot_count > free:
		return REFUSE_EFFORT_SLOTS_FULL
	return REFUSE_NONE


func _refuse_effort_owner(expedition_ref: Vector2i, job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Expedition row is free to claim and this Job may own the claim.

	The Expedition reference is validated THROUGH THE DIRECTORY FIRST and only then against the
	generation stored on its row, which is what distinguishes "this expedition already holds a
	claim" from "a previous expedition left one on the row this one reuses".
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] == 1:
		if _effort_claim_expedition_generation[row] == expedition_ref.y:
			return REFUSE_EFFORT_CLAIM_PRESENT
		return REFUSE_EFFORT_CLAIM_STALE
	_pending_claim_row = row
	return _refuse_effort_claim_job(job_ref)


func _refuse_effort_claim_job(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when `job_ref` is a live Job that may own a claim (decision 0017's coordinator).

	A MEMBER Job is refused: its coordinator owns the cycle, which is exactly what stops
	cancelling one party member from releasing the whole cycle's effort slots.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	return REFUSE_NONE


func _write_effort_claim(row: int, expedition_ref: Vector2i, job_ref: Vector2i,
		habitat_ref: Vector2i, slot_count: int) -> void:
	"""Write every column of one claim row and publish `active` last."""
	_effort_claim_expedition_generation[row] = expedition_ref.y
	_effort_claim_habitat_slot[row] = habitat_ref.x
	_effort_claim_habitat_generation[row] = habitat_ref.y
	_effort_claim_job_slot[row] = job_ref.x
	_effort_claim_job_generation[row] = job_ref.y
	_effort_claim_slot_count[row] = slot_count
	_effort_claim_active[row] = 1
	_effort_claim_count += 1


func _clear_effort_claim_row(row: int) -> void:
	"""Return one claim row to the null/zero state unused rows carry."""
	_effort_claim_active[row] = 0
	_effort_claim_expedition_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_habitat_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_habitat_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_slot_count[row] = 0
	_effort_claim_count -= 1


func release_effort_slots(expedition_ref: Vector2i) -> OpResult:
	"""Give back exactly this cycle's slots, exactly once. Returns the slots still taken.

	A second release finds no active claim and refuses, and a reference whose stored generation
	disagrees refuses too, so neither a double nor a stale call can free somebody else's slots.
	"""
	if not effort_claim_row_into(expedition_ref, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	var habitat_ref: Vector2i = effort_claim_habitat_ref_of(row)
	_release_effort_claim_row(row)
	if not habitat_slot_of_into(habitat_ref, _math):
		return _succeed(0, NULL_REF)
	return _succeed(_habitat_effort_used[_math.value], habitat_ref)


func _release_effort_claim_row(row: int) -> void:
	"""Debit the claimed habitat's occupancy and clear the row, in that order.

	The habitat is checked because a cleared store can leave a claim naming a row that is gone;
	destroy_habitat() refuses while any slot is reserved, so no ordinary path reaches that.
	"""
	if habitat_slot_of_into(effort_claim_habitat_ref_of(row), _math_b):
		_habitat_effort_used[_math_b.value] -= _effort_claim_slot_count[row]
	_clear_effort_claim_row(row)


func effort_slots_used_of(slot: int) -> IntMath.IntResult:
	"""How many of a habitat's effort slots are currently reserved."""
```

## Lines 1610–1820
```gdscript
	return row >= 0 and row < FISHING_EFFORT_CLAIM_CAPACITY and _effort_claim_active[row] == 1


func effort_claim_row_of(expedition_ref: Vector2i) -> IntMath.IntResult:
	"""The claim row one live Expedition owns, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	effort_claim_row_into(expedition_ref, out)
	return out


func effort_claim_row_into(expedition_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating effort_claim_row_of(): validate through the directory, then the row.

	Ruling §5's two-step ownership test. The directory settles that the Expedition reference is
	live; the stored generation then settles that THIS expedition wrote the claim, and not a
	previous one whose typed row it now occupies.
	"""
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return out.refuse(String(REFUSE_EXPEDITION_NOT_PRESENT))
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] != 1:
		return out.refuse(String(REFUSE_NO_EFFORT_CLAIM))
	if _effort_claim_expedition_generation[row] != expedition_ref.y:
		return out.refuse(String(REFUSE_EFFORT_CLAIM_STALE))
	return out.succeed(row)


func effort_claim_habitat_ref_of(row: int) -> Vector2i:
	"""The habitat a live claim holds slots in, or the §4.1 null reference `(-1, 0)`."""
	if not is_effort_claim_active(row):
		return NULL_REF
	return Vector2i(_effort_claim_habitat_slot[row], _effort_claim_habitat_generation[row])


func effort_claim_job_ref_of(row: int) -> Vector2i:
	"""The coordinator Job owning a live claim, or the §4.1 null reference `(-1, 0)`."""
	if not is_effort_claim_active(row):
		return NULL_REF
	return Vector2i(_effort_claim_job_slot[row], _effort_claim_job_generation[row])


func effort_claim_expedition_ref_of(row: int) -> Vector2i:
	"""The Expedition owning a live claim, rebuilt from the directory's reverse map.

	The claim slice stores only the generation (ruling §5's six I32 columns); the slot comes back
	from EntityDirectory.owner_slot_of_typed_row(), which reads a column that already exists.
	"""
	if not is_effort_claim_active(row):
		return NULL_REF
	var slot: int = _directory.owner_slot_of_typed_row(EntityDirectory.KIND_EXPEDITION, row)
	if slot == EntityDirectory.NULL_SLOT:
		return NULL_REF
	return Vector2i(slot, _effort_claim_expedition_generation[row])


func effort_claim_slot_count_of(row: int) -> IntMath.IntResult:
	"""How many effort slots one live claim holds."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_effort_claim_active(row):
		out.refuse(String(REFUSE_NO_EFFORT_CLAIM))
		return out
	out.succeed(_effort_claim_slot_count[row])
	return out


func restore_effort_claim(expedition_ref: Vector2i, job_ref: Vector2i, habitat_ref: Vector2i,
		slot_count: int) -> OpResult:
	"""Write one saved claim WITHOUT touching the derived occupancy column. Returns its row.

	The load half of ruling §5. A loader restores authoritative claim records and then calls
	rebuild_effort_aggregates() before any cycle resumes, which is why this deliberately leaves
	`effort_used` alone: a stored total cannot prove ownership, so it is recomputed rather than
	trusted. Every reference and the slot count ARE validated, because a save that fails them
	must be refused rather than loaded.
	"""
	var code: StringName = _refuse_effort_owner(expedition_ref, job_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	if not habitat_slot_of_into(habitat_ref, _math):
		return _refuse(StringName(_math.error))
	if slot_count <= 0 or slot_count > _habitat_effort_slots[_math.value]:
		return _refuse(REFUSE_INVALID_SLOT_COUNT)
	_write_effort_claim(_pending_claim_row, expedition_ref, job_ref, habitat_ref, slot_count)
	return _succeed(_pending_claim_row, habitat_ref)


func rebuild_effort_aggregates() -> OpResult:
	"""Recompute every habitat's occupancy from the live claims. Returns the claims counted.

	Ruling §5: "Rebuild/validate the aggregate against live claims on load; a stored total alone
	cannot prove ownership." Every claim is validated and every habitat total is accumulated into
	scratch BEFORE the authoritative column is touched, so a save carrying a mismatched owner
	generation or an over-capacity total is refused with the column unchanged.
	"""
	var code: StringName = _accumulate_effort_totals()
	if code != REFUSE_NONE:
		return _refuse(code)
	for slot: int in FISH_HABITAT_CAPACITY:
		_habitat_effort_used[slot] = _effort_total_scratch[slot]
	return _succeed(_effort_claim_count, NULL_REF)


func validate_effort_aggregates() -> OpResult:
	"""Check the stored occupancy against the live claims, changing nothing. Returns the claims.

	The read-only half of the same contract: a loader that wants to know whether a snapshot is
	self-consistent asks this, and a total that no claim accounts for refuses.
	"""
	var code: StringName = _accumulate_effort_totals()
	if code != REFUSE_NONE:
		return _refuse(code)
	for slot: int in FISH_HABITAT_CAPACITY:
		if _habitat_effort_used[slot] != _effort_total_scratch[slot]:
			return _refuse(REFUSE_AGGREGATE_MISMATCH)
	return _succeed(_effort_claim_count, NULL_REF)


func _accumulate_effort_totals() -> StringName:
	"""Total every live claim into `_effort_total_scratch`, validating each one on the way.

	REFUSE_NONE leaves a complete per-habitat occupancy in the scratch column and the live claim
	count in `_effort_claim_count`; any refusal leaves both meaningless and the caller applies
	neither.
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	_effort_total_scratch.fill(0)
	var counted: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var code: StringName = _refuse_stored_effort_claim(row)
		if code != REFUSE_NONE:
			return code
		counted += 1
		var slot: int = _math_b.value
		_effort_total_scratch[slot] += _effort_claim_slot_count[row]
		if _effort_total_scratch[slot] > _habitat_effort_slots[slot]:
			return REFUSE_AGGREGATE_MISMATCH
	_effort_claim_count = counted
	return REFUSE_NONE


func _refuse_stored_effort_claim(row: int) -> StringName:
	"""REFUSE_NONE when one stored claim's owners are all live and agree. Leaves its habitat row
	in `_math_b` for the accumulation that follows."""
	var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	if _directory.get_typed_row(expedition_ref) != row:
		return REFUSE_EFFORT_CLAIM_STALE
	var code: StringName = _refuse_effort_claim_job(effort_claim_job_ref_of(row))
	if code != REFUSE_NONE:
		return code
	if not habitat_slot_of_into(effort_claim_habitat_ref_of(row), _math_b):
		return StringName(_math_b.error)
	if _effort_claim_slot_count[row] <= 0:
		return REFUSE_INVALID_SLOT_COUNT
	return REFUSE_NONE


func purge_stale_effort_claims() -> OpResult:
	"""Release every claim whose Expedition is gone. Returns how many were released.

	A destroyed expedition cannot call release_effort_slots() for itself, so without this sweep
	its slots would stay taken forever. Nothing else releases a claim on somebody's behalf.
	"""
	var released: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
		if _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION) \
				and _directory.get_typed_row(expedition_ref) == row:
			continue
		_release_effort_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func release_cancelled_effort_claims() -> OpResult:
	"""Release every claim whose owning coordinator Job is gone or CANCELLED. Returns the count.

	Ruling §5: cancellation releases exactly that owner's slots, exactly once. A cancelled MEMBER
	Job is not an owner and never appears here, which is what keeps one member's cancellation from
	ending the coordinator's cycle.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var released: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		if not _effort_claim_is_cancelled(row):
			continue
		_release_effort_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func _effort_claim_is_cancelled(row: int) -> bool:
	"""True when the coordinator Job behind one live claim is gone or in JobState.CANCELLED."""
	var job_ref: Vector2i = effort_claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return true
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return true
	return _jobs.state_of(job_slot).value == JOB_STATE_CANCELLED


```
