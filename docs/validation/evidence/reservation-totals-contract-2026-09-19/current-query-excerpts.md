# Current reservation query and mutation interfaces

Source SHA256 408358c2a64af0295bfd8bd6fd16087780f54a446bfcff66eaddacb850ca6feb

```gdscript
func job_reserved_total_milli(job_ref: Vector2i) -> int:
	"""Total milli-units claimed by one Job across every lot."""
	return _sum_list(_list_head(job_ref, true), true)

func lot_reserved_total_milli(lot_ref: Vector2i) -> int:
	"""Total milli-units claimed against one lot, re-derived from the rows themselves.

	This is the right-hand side of decision 0019's invariant. `audit()` compares it with the
	`reserved_milli` that `inventory.gd` maintains independently.
	"""
	return _sum_list(_list_head(lot_ref, false), false)

func _sum_list(head: int, by_job: bool) -> int:
	"""Sum of the claimed quantities along one intrusive list."""
	var total: int = 0
	var row: int = head
	while row != NULL_ROW:
		total += _r_quantity_milli[row]
		row = _job_next[row] if by_job else _lot_next[row]
	return total


# --- Row iteration ----------------------------------------------------------------------------

func _list_head(owner_ref: Vector2i, by_job: bool) -> int:
	"""Head row of `owner_ref`'s list, or NULL_ROW when the owner is out of range or empty."""
	if by_job:
		if owner_ref.x < 0 or owner_ref.x >= _job_capacity:
			return NULL_ROW
		var job_head: int = _job_head[owner_ref.x]
		return job_head if job_head != NULL_ROW and _r_job_generation[job_head] == owner_ref.y else NULL_ROW
	if owner_ref.x < 0 or owner_ref.x >= _lot_capacity:
		return NULL_ROW
	var lot_head: int = _lot_head[owner_ref.x]
	return lot_head if lot_head != NULL_ROW and _r_lot_generation[lot_head] == owner_ref.y else NULL_ROW

func _audit_lot_totals(inventory: Inventory) -> StringName:
	"""Decision 0019's invariant, per lot the pool holds rows for."""
	for slot: int in range(_lot_capacity):
		var head: int = _lot_head[slot]
		if head == NULL_ROW:
			continue
		var lot_ref: Vector2i = Vector2i(slot, _r_lot_generation[head])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		var total: int = _sum_list(head, false)
		if total != inventory.lot_reserved_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		if total > inventory.lot_quantity_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_EXCEEDS
	return REFUSE_NONE


# --- Serialization ----------------------------------------------------------------------------

func _preflight_quantities(claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Check every lot in the batch can supply the TOTAL this batch asks of it.

	Several records may name the same lot; each is checked once, against the sum of all records
	naming it, so a batch cannot pass by having each piece fit while the whole does not. Keying
	on the lot slot alone is sound because `_preflight_claim_fields()` already proved every
	record's reference valid, and a live lot slot carries exactly one generation.
	"""
	for index: int in range(claim_count):
		var base: int = index * CLAIM_STRIDE
		var lot_slot: int = claims[base + CLAIM_LOT_SLOT]
		if _first_index_of_lot(claims, claim_count, lot_slot) != index:
			continue
		var total: int = 0
		for other: int in range(index, claim_count):
			var other_base: int = other * CLAIM_STRIDE
			if claims[other_base + CLAIM_LOT_SLOT] != lot_slot:
				continue
			if not IntMath.checked_add_into(total, claims[other_base + CLAIM_QUANTITY_MILLI], _math):
				return REFUSE_OVERFLOW
			total = _math.value
		var lot_ref: Vector2i = Vector2i(lot_slot, claims[base + CLAIM_LOT_GENERATION])
		if total > inventory.lot_available_milli(lot_ref):
			return REFUSE_INSUFFICIENT_UNRESERVED
	return REFUSE_NONE

func _upsert_row(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, quantity_milli: int, expiry: int) -> int:
	"""Add a claim onto its existing row, or allocate a fresh one. Returns the row."""
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row != NULL_ROW:
		_r_quantity_milli[row] += quantity_milli
		if expiry > _r_expiry[row]:
			_r_expiry[row] = expiry
		return row
	row = _allocate_row()
	assert(row != NULL_ROW, "the preflight guarantees a free row here")
	_r_job_slot[row] = job_ref.x
	_r_job_generation[row] = job_ref.y
	_r_lot_slot[row] = lot_ref.x
	_r_lot_generation[row] = lot_ref.y
	_r_purpose[row] = purpose
	_r_quantity_milli[row] = quantity_milli
	_r_expiry[row] = expiry
	_link_job(row)
	_link_lot(row)
	return row


# --- Releasing --------------------------------------------------------------------------------

func release_job_claims(job_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim held by one Job, or refuse and release none.

	This is the worker-departure and job-cancellation path. Decision 0017 keeps shared claims on
	the coordinator Job, so calling this for a departing member releases that member's own rows
	and cannot touch the party's shared ingredients. `.value` is the number of rows released.
	"""
	return _release_list(job_ref, true, inventory)

func release_lot_claims(lot_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim standing against one lot, or refuse and release none.

	GDD §5.8's spoilage path: the rows go in the lot list's canonical order, which is ascending
	`(job_slot, job_generation, purpose)` and therefore independent of the order they were
	claimed in. `.value` is the number of rows released.
	"""
	return _release_list(lot_ref, false, inventory)
```
