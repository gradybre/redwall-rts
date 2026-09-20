# Additional immutable source for claim reconciliation

Snapshot after integrated FISH-ID-R01 repair; not whole-world acceptance.

## fishing.gd SHA256 08ff3b69c64a14c4b7817813b67af52d981e1b4eeaa457c2222f4ada3ffd9469

### destroy_habitat lines1050–1074
```gdscript
func destroy_habitat(ref: Vector2i) -> OpResult:
	"""Remove one habitat and its three stocks, and free its directory slot.

	Returns the number of stock rows released. Refuses while an effort slot is still reserved --
	destroying the habitat under a live reservation would strand it -- and refuses a stale or
	wrong-kind reference rather than clearing whatever row it points at.
	"""
	if not habitat_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if _habitat_effort_used[slot] > 0:
		return _refuse(REFUSE_EFFORT_SLOTS_RESERVED)
	var released: int = _release_habitat_stocks(slot)
	_habitat_present[slot] = 0
	_habitat_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_habitat_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_habitat_zone_slot[slot] = EntityDirectory.NULL_SLOT
	_habitat_zone_generation[slot] = EntityDirectory.NULL_GENERATION
	_habitat_capacity_milli[slot] = 0
	_habitat_intensive[slot] = 0
	_remove_live_habitat(slot)
	_directory.destroy(ref)
	return _succeed(released, NULL_REF)
```

### habitat_slot_of_into lines1154–1163
```gdscript
func habitat_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating habitat_slot_of(): write the validated row into caller-owned `out`."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_FISH_HABITAT):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	var slot: int = _directory.get_typed_row(ref)
	if not is_habitat_present(slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	return out.succeed(slot)
```

### purge_stale_effort_claims lines1785–1803
```gdscript
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
```

### _refuse_stored_effort_claim lines1767–1784
```gdscript
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
```
Function `_refuse_effort_job` absent.

### Selected domains
```gdscript
const FISH_HABITAT_CAPACITY: int = 32
const FISH_STOCK_CAPACITY: int = FISH_HABITAT_CAPACITY * SPECIES_PER_HABITAT
const FISHING_EFFORT_CLAIM_CAPACITY: int = 512
const EFFORT_SLOTS_BY_TYPE: Array[int] = [
const SPECIES_CAPACITY_U: Array[int] = [600, 900, 600, 900, 700, 600, 1200, 900, 1000]
const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1
```

## forage.gd SHA256 8f1be765de10b5adba1a623ce54033c9830bc8d7bd1eedcc3d82712850b8144a

### destroy_zone lines878–908
```gdscript
func destroy_zone(ref: Vector2i) -> OpResult:
	"""Remove one zone, release every tile link and patch it owns, and free its directory slot.

	Returns the number of tile links released. Refuses a stale or wrong-kind reference rather
	than clearing whatever row it points at, which is what makes a reused slot safe.

	Ruling §4.5: deleting a designation "releases its outstanding claims first" and does not reset
	the basin's usage. Only THIS row's daily totals are cleared; the basin it drew from keeps its
	collected total, its own claims and its annual patch counters.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	_release_claims_of_zone_slot(slot)
	var released: int = _release_zone_links(slot)
	_release_zone_patches(slot)
	_zone_harvested_today_milli[slot] = 0
	_zone_quota_reserved_milli[slot] = 0
	_zone_quota_mode[slot] = QUOTA_MODE_AUTOMATIC
	_zone_present[slot] = 0
	_zone_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_zone_basin_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_basin_generation[slot] = EntityDirectory.NULL_GENERATION
	_remove_live_zone(slot)
	_directory.destroy(ref)
	return _succeed(released, NULL_REF)
```

### set_basin lines1239–1266
```gdscript
func set_basin(ref: Vector2i, basin_ref: Vector2i) -> OpResult:
	"""Point a zone at the basin zone whose forage stock it draws from (GDD §5.1).

	This is the anti-multiplication gate. Refuses a zone that already owns patches (its stock
	would be stranded), a basin that is itself bound elsewhere (a chain would give two answers
	for one zone), and a basin of a different ZoneType.

	Ruling §4.5: rebinding "releases its outstanding claims first ... before changing its identity
	or basin", and neither release nor rebind resets basin usage. Both zones' collected totals
	survive; only the claims this zone owned go.
	"""
	if not zone_slot_of_into(ref, _math) or not zone_slot_of_into(basin_ref, _math_b):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _math.value
	var basin_slot: int = _math_b.value
	if _zone_patch_count[slot] > 0:
		return _refuse(REFUSE_BASIN_HAS_OWN_PATCHES)
	if _zone_type[slot] != _zone_type[basin_slot]:
		return _refuse(REFUSE_ZONE_TYPE_MISMATCH)
	if basin_slot != slot and _zone_basin_slot[basin_slot] != basin_ref.x:
		return _refuse(REFUSE_BASIN_CHAIN)
	_release_claims_of_zone_slot(slot)
	_zone_basin_slot[slot] = basin_ref.x
	_zone_basin_generation[slot] = basin_ref.y
	_normalise_quota_mode(slot)
	return _succeed(basin_slot, basin_ref)
```

### zone_slot_of_into lines999–1008
```gdscript
func zone_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating zone_slot_of(): write the validated row into caller-owned `out`."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	return out.succeed(slot)
```

### basin_slot_of_into lines1298–1310
```gdscript
func basin_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating basin_slot_of(): resolve zone -> basin row into caller-owned `out`.

	The basin reference is validated on the way through, so a basin destroyed under a live zone
	refuses here instead of resolving to whatever row later reused its slot.
	"""
	if not zone_slot_of_into(ref, out):
		return false
	var slot: int = out.value
	var basin: Vector2i = Vector2i(_zone_basin_slot[slot], _zone_basin_generation[slot])
	return zone_slot_of_into(basin, out)
```

### patch_row_for_zone_into lines1408–1423
```gdscript
func patch_row_for_zone_into(ref: Vector2i, kind: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating patch_row_for_zone(): write `basin_slot*5 + kind` into caller-owned `out`.

	Two zones sharing a basin resolve to the SAME row here, which is the whole mechanism behind
	§5.1's "all intersecting zones share its quotas and do not multiply capacity".
	"""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not basin_slot_of_into(ref, out):
		return false
	var row: int = out.value * PATCHES_PER_ZONE + kind
	if _patch_present[row] != 1:
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	return out.succeed(row)
```

### _claim_is_over_allowance lines2579–2589
```gdscript
func _claim_is_over_allowance(row: int, season: int) -> bool:
	"""True when this claim must go: its zone is gone, or a zone it names is over its allowance."""
	var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
	var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
	if basin_slot == EntityDirectory.NULL_SLOT or designation_slot == EntityDirectory.NULL_SLOT:
		return true
	if _zone_is_over_allowance(basin_slot, season):
		return true
	return designation_slot != basin_slot and _zone_is_over_allowance(designation_slot, season)
```

### purge_stale_claims lines2483–2500
```gdscript
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
```
Function `_should_release_cancelled_claim` absent.

### _refresh_claim_order_key lines2776–2785
```gdscript
func _refresh_claim_order_key(row: int) -> void:
	"""Re-read §4.5's release-order key from the owning Job, leaving it alone when the Job is gone."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return
	var job_slot: int = _directory.get_typed_row(job_ref)
	_claim_created_tick[row] = _jobs.created_tick_of(job_slot).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)
```

### _write_claim lines2282–2305
```gdscript
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
```

### create_patch_set lines1364–1385
```gdscript
func create_patch_set(ref: Vector2i, item_ids: PackedInt32Array) -> OpResult:
	"""Create all five §5.5 patches of a forage basin at once, in PATCH_KEYS order.

	All or nothing: every kind is validated before the first is written, so a refusal leaves the
	basin with the patches it already had. Returns the number of patches created.
	"""
	if item_ids.size() != PATCHES_PER_ZONE:
		return _refuse(REFUSE_PATCH_SET_SIZE)
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	for kind: int in PATCHES_PER_ZONE:
		var code: StringName = _refuse_create_patch(slot, kind, item_ids[kind])
		if code != REFUSE_NONE:
			return _refuse(code)
	for kind: int in PATCHES_PER_ZONE:
		var created: OpResult = create_patch(ref, kind, item_ids[kind])
		if not created.ok:
			return created
	return _succeed(PATCHES_PER_ZONE, ref)
```

### Selected domains
```gdscript
const HARVEST_ZONE_CAPACITY: int = 128
const ZONE_LINK_CAPACITY: int = 16384
const PATCHES_PER_ZONE: int = 5
const FORAGE_PATCH_CAPACITY: int = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE
const FORAGE_CLAIM_CAPACITY: int = 8192
const PATCH_CAPACITY_U: Array[int] = [300, 240, 180, 160, 300]
const MANUAL_QUOTA_MAX_MILLI: int = 1180000
const REFUSE_ZONE_LINK_CAPACITY: StringName = &"CAPACITY_ZONE_LINK"
const REFUSE_STOCK_ABOVE_CAPACITY: StringName = &"STOCK_ABOVE_CAPACITY"
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1
```

## jobs.gd SHA256 bf74583b409dd22da8b9100318e224b63bede5ed01c66be09f4ed0ab38809f3c

### _check_job_slot lines806–814
```gdscript
func _check_job_slot(job_slot: int) -> StringName:
	"""REFUSE_NONE when `job_slot` is in range and holds a live Job row."""
	if job_slot < 0 or job_slot >= JOB_CAPACITY:
		return REFUSE_INVALID_JOB_SLOT
	if _job_present[job_slot] == 0:
		return REFUSE_JOB_NOT_PRESENT
	return REFUSE_NONE
```

### created_tick_of lines1117–1122
```gdscript
func created_tick_of(job_slot: int) -> IntMath.IntResult:
	"""Job.created_tick: the fifth term of the §5.3 within-bucket sort key, ascending."""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _created_tick[job_slot] if code == REFUSE_NONE else 0)
```

### job_id_of lines1043–1053
```gdscript
func job_id_of(job_slot: int) -> IntMath.IntResult:
	"""The never-reused persistent ID: the last tie-break of the §5.3 sort key, and the ID half of
	decision 0023's continuation key.

	Served from the cached column rather than the directory so the candidate loop, the ordered
	live index and this reader all agree on one number.
	"""
	var code: StringName = _check_job_slot(job_slot)
	return _read(code, _job_persistent_id[job_slot] if code == REFUSE_NONE else 0)
```

### state_into lines1335–1342
```gdscript
func state_into(job_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `state_of()`: write Job.state into `out` and return out.ok."""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return out.succeed(_state[job_slot])
```

### is_member lines1508–1514
```gdscript
func is_member(job_slot: int) -> bool:
	"""True when this live Job row is a member of some coordinator's party."""
	if _check_job_slot(job_slot) != REFUSE_NONE:
		return false
	return _coordinator_slot[job_slot] != EntityDirectory.NULL_SLOT
```

### create_job lines835–860
```gdscript
func create_job(kind: int, priority: int, required_skill: int, remaining_mwu: int,
		created_tick: int) -> OpResult:
	"""Allocate one Job row through the directory's KIND_JOB arena and write its §4.2 defaults.

	`required_skill` is the minimum skill LEVEL 0-10 in the job's own kind (decision 0022).
	Refuses without allocating anything on an unknown or reserved kind, an out-of-int32 priority,
	a level outside 0-10, a negative work total or a negative creation tick, and passes a
	directory refusal through with its own ARCH-ID-004 code. Nothing is clamped: an invalid job
	definition is refused, so no row can exist carrying one.
	"""
	var code: StringName = _check_create_arguments(kind, priority, required_skill,
		remaining_mwu, created_tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_JOB)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var job_slot: int = _directory.get_typed_row(ref)
	_write_new_job_row(job_slot, ref, kind, priority, required_skill)
	_remaining_mwu[job_slot] = remaining_mwu
	_created_tick[job_slot] = created_tick
	_insert_live_slot(job_slot)
	_admit(job_slot)
	return _succeed(job_slot, ref)
```

### destroy_job lines914–942
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
```

### set_coordinator lines1520–1537
```gdscript
func set_coordinator(member_slot: int, coordinator_slot: int) -> OpResult:
	"""Attach a member Job to a coordinator, per decision 0017.

	Refuses a member that carries shared progress (`remaining_mwu != 0`), a member that is
	already in a party, a job coordinating itself, a coordinator that is not one, and a member
	that is itself a coordinator. Every one of those would put shared progress or lifecycle
	ownership in two places at once, which is the state 0017 exists to make unreachable.
	"""
	var code: StringName = _check_coordinator_link(member_slot, coordinator_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	_set_ref_columns(member_slot, ref_of(coordinator_slot), _coordinator_slot,
		_coordinator_generation)
	_member_next[member_slot] = _member_head[coordinator_slot]
	_member_head[coordinator_slot] = member_slot
	return _succeed(coordinator_slot, ref_of(coordinator_slot))
```

### Selected domains
```gdscript
const JOB_CAPACITY: int = 8192
const AGENT_CAPACITY: int = 512
const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
```

## entity_directory.gd SHA256 0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a

### is_valid lines256–260
```gdscript
func is_valid(ref: Vector2i) -> bool:
	"""ARCH-ID-003 validation in `ANY` mode: true when `ref` still names a live row."""
	return is_valid_of_kind(ref, KIND_ANY)
```

### is_valid_of_kind lines261–278
```gdscript
func is_valid_of_kind(ref: Vector2i, expected_kind: int) -> bool:
	"""Full ARCH-ID-003 predicate: bounds, active, generation, kind, row, reverse owner."""
	var slot: int = ref.x
	if slot < 0 or slot >= DIRECTORY_CAPACITY:
		return false
	if _active[slot] != 1 or _generation[slot] != ref.y:
		return false
	var kind: int = _kind[slot]
	if expected_kind != KIND_ANY and kind != expected_kind:
		return false
	if kind < 0 or kind >= KIND_COUNT:
		return false
	var row: int = _typed_row[slot]
	if row < 0 or row >= KIND_CAPACITY[kind]:
		return false
	return _typed_owner_slot[_kind_base[kind] + row] == slot
```

### get_typed_row lines286–292
```gdscript
func get_typed_row(ref: Vector2i) -> int:
	"""The typed-store row of a live reference, or NULL_SLOT when it is stale."""
	if not is_valid(ref):
		return NULL_SLOT
	return _typed_row[ref.x]
```

### get_persistent_id lines326–332
```gdscript
func get_persistent_id(ref: Vector2i) -> int:
	"""The never-reused persistent ID of a live reference, or 0 when it is stale."""
	if not is_valid(ref):
		return 0
	return _persistent_id[ref.x]
```

### destroy lines229–255
```gdscript
func destroy(ref: Vector2i) -> bool:
	"""Release a live reference's slot and typed row. False when `ref` is stale."""
	if not is_valid(ref):
		return false
	var slot: int = ref.x
	var kind: int = _kind[slot]
	var base: int = _kind_base[kind]
	var row: int = _typed_row[slot]
	_typed_owner_slot[base + row] = NULL_SLOT
	_push_free(_heap_index, base, _kind_free_count[kind], row)
	_kind_free_count[kind] += 1
	_active[slot] = 0
	_persistent_id[slot] = 0
	_typed_row[slot] = NULL_SLOT
	_kind[slot] = KIND_ANY
	_live_count -= 1
	_kind_live_count[kind] -= 1
	if _generation[slot] >= MAX_INT32:
		# ARCH-ID-002: generation 2147483647 is used once, then the slot retires
		# permanently rather than wrapping into a colliding value.
		_retired[slot] = 1
		return true
	_push_free(_free_heap, 0, _free_count, slot)
	_free_count += 1
	return true
```

### Selected domains
```gdscript
const PERSISTENT_ID_MIN: int = 1
const PERSISTENT_ID_EXHAUSTED: int = MAX_INT32 + 1
const KIND_EXPEDITION: int = 2
const KIND_JOB: int = 11
const KIND_CAPACITY: Array[int] = [
const KIND_CAPACITY_REFUSAL: Array[StringName] = [
const DIRECTORY_CAPACITY: int = 352418
const REFUSAL_DIRECTORY_FULL: StringName = &"CAPACITY_DIRECTORY"
const REFUSAL_PERSISTENT_ID: StringName = &"PERSISTENT_ID_EXHAUSTED"
const REFUSAL_COLUMN_LIVE_PERSISTENT_ID: StringName = &"COLUMN_LIVE_PERSISTENT_ID"
```
