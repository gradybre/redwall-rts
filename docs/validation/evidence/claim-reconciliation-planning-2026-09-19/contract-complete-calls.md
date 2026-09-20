# forage.gd SHA256 8f1be765de10b5adba1a623ce54033c9830bc8d7bd1eedcc3d82712850b8144a

## claim_forage line2172
```gdscript
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
```

## _check_claim_owner line2200
```gdscript
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
```

## _check_claim_request line2216
```gdscript
func _check_claim_request(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when the designation, kind, season and amount are claimable.

	Leaves the resolved designation row, basin row and patch row in `_pending_*` for the commit
	that immediately follows. Nothing between the two calls can re-enter this store.
	"""
	var zone_code: StringName = _check_harvest_zone(designation_ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if not zone_slot_of_into(designation_ref, _math_c):
		return StringName(_math_c.error)
	_pending_designation_slot = _math_c.value
	if not patch_row_for_zone_into(designation_ref, kind, _math_c):
		return StringName(_math_c.error)
	_pending_patch_row = _math_c.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if not availability_per_1000_into(kind, season, _math_c):
		return StringName(_math_c.error)
	if _math_c.value == 0:
		return REFUSE_PATCH_DORMANT
	return _check_claim_limits(designation_ref, kind, amount_milli, season, intensive)
```

## _write_claim line2282
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

## _release_claims_of_zone_slot line2465
```gdscript
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
```

## _release_claim_row line2418
```gdscript
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
```

## destroy_zone line878
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

## set_basin line1239
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

## create_patch line1323
```gdscript
func create_patch(ref: Vector2i, kind: int, item_id: int) -> OpResult:
	"""Create one of a forage basin's five §5.5 patches, full to GDD §5.1's 80% of capacity.

	Returns the patch row. Capacity and kind come from §5.5's table, never from the caller.
	Refuses a non-FORAGE zone, a zone bound to another basin, a kind outside 0..4, a negative
	item id, and a second patch of the same kind.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	var code: StringName = _refuse_create_patch(slot, kind, item_id)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = slot * PATCHES_PER_ZONE + kind
	var capacity: int = PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
	_patch_present[row] = 1
	_patch_item_id[row] = item_id
	_patch_zone_slot[row] = ref.x
	_patch_zone_generation[row] = ref.y
	_patch_capacity_milli[row] = capacity
	_patch_stock_milli[row] = capacity * INITIAL_STOCK_NUMERATOR / INITIAL_STOCK_DENOMINATOR
	_patch_harvested_year_milli[row] = 0
	_zone_patch_count[slot] += 1
	return _succeed(row, ref)
```

## _refuse_create_patch line1349
```gdscript
func _refuse_create_patch(zone_slot: int, kind: int, item_id: int) -> StringName:
	"""The code blocking a patch creation, or REFUSE_NONE when the basin can hold it."""
	if _zone_type[zone_slot] != ZONE_TYPE_FORAGE:
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_basin_slot[zone_slot] != _zone_ref_slot[zone_slot]:
		return REFUSE_ZONE_IS_BOUND
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if item_id < 0 or not IntMath.fits_int32(item_id):
		return REFUSE_INVALID_ITEM_ID
	if _patch_present[zone_slot * PATCHES_PER_ZONE + kind] == 1:
		return REFUSE_PATCH_PRESENT
	return REFUSE_NONE
```

## _release_zone_patches line924
```gdscript
func _release_zone_patches(zone_slot: int) -> void:
	"""Empty the five-row ForagePatch block a destroyed zone owns."""
	var base: int = zone_slot * PATCHES_PER_ZONE
	for kind: int in PATCHES_PER_ZONE:
		var row: int = base + kind
		_patch_present[row] = 0
		_patch_item_id[row] = -1
		_patch_zone_slot[row] = EntityDirectory.NULL_SLOT
		_patch_zone_generation[row] = EntityDirectory.NULL_GENERATION
		_patch_stock_milli[row] = 0
		_patch_capacity_milli[row] = 0
		_patch_harvested_year_milli[row] = 0
	_zone_patch_count[zone_slot] = 0
```

## _claim_is_cancelled line2521
```gdscript
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
```

## basin_slot_of_into line1298
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

# fishing.gd SHA256 08ff3b69c64a14c4b7817813b67af52d981e1b4eeaa457c2222f4ada3ffd9469

## destroy_habitat line1050
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

## _refuse_effort_owner line1488
```gdscript
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
		# FISH-ID-R01: only the EXACT stored slot/generation pair is this expedition's own claim.
		if _effort_claim_expedition_slot[row] == expedition_ref.x \
				and _effort_claim_expedition_generation[row] == expedition_ref.y:
			return REFUSE_EFFORT_CLAIM_PRESENT
		return REFUSE_EFFORT_CLAIM_STALE
	_pending_claim_row = row
	return _refuse_effort_claim_job(job_ref)
```

## _refuse_effort_claim_job line1510
```gdscript
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
```

## _effort_claim_is_cancelled line1824
```gdscript
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

# jobs.gd SHA256 bf74583b409dd22da8b9100318e224b63bede5ed01c66be09f4ed0ab38809f3c

## set_state line1266
```gdscript
func set_state(job_slot: int, state: int) -> OpResult:
	"""Write Job.state, accepting only GDD §4.3's eight values.

	No transition graph is enforced: ARCH-JOB-001 fixes the eight numbers and states that passive
	wait is a saved phase within WORK, but neither document enumerates the legal transitions, and
	inventing one here would be inventing a contract.
	"""
	var code: StringName = _check_job_slot(job_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	if state < 0 or state >= JOB_STATE_COUNT:
		return _refuse(REFUSE_INVALID_JOB_STATE)
	var was_queued: bool = _state[job_slot] == JOB_STATE_QUEUED
	_state[job_slot] = state
	if state == JOB_STATE_QUEUED and not was_queued:
		_admit(job_slot)
	return _succeed(state, ref_of(job_slot))
```

## set_coordinator line1520
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

## _clear_job_row line943
```gdscript
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
```

# entity_directory.gd SHA256 0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a

## create line193
```gdscript
func create(kind: int) -> Vector2i:
	"""Allocate a directory slot and typed row for `kind`.

	Returns the new reference, or NULL_REF when refused; `last_refusal()` then
	carries the ARCH-ID-004 code. Every pool is checked before anything is
	mutated, so a refusal leaves no partial reservation to roll back.
	"""
	var refusal: StringName = _refuse_create(kind)
	if refusal != REFUSAL_NONE:
		_last_refusal = refusal
		return NULL_REF
	_last_refusal = REFUSAL_NONE
	var slot: int = _pop_min(_free_heap, 0, _free_count)
	_free_count -= 1
	var row: int = _pop_min(_heap_index, _kind_base[kind], _kind_free_count[kind])
	_kind_free_count[kind] -= 1
	return _publish_row(slot, kind, row)
```

## _publish_row line212
```gdscript
func _publish_row(slot: int, kind: int, row: int) -> Vector2i:
	"""Initialize every column of a reserved slot, then publish `active=1` (ARCH-ID-002)."""
	# Initial generation is 1 and it increments on reuse, never on destroy. A
	# retired slot never re-enters the free heap, so this cannot wrap.
	assert(_generation[slot] < MAX_INT32, "a max-generation slot must be retired, not reused")
	_generation[slot] += 1
	_persistent_id[slot] = _next_persistent_id
	_next_persistent_id += 1
	_kind[slot] = kind
	_typed_row[slot] = row
	_typed_owner_slot[_kind_base[kind] + row] = slot
	_active[slot] = 1
	_live_count += 1
	_kind_live_count[kind] += 1
	return Vector2i(slot, _generation[slot])
```

## destroy line229
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

## is_valid_of_kind line261
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
