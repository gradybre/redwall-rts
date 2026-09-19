# Actual planner queue functions

Source SHA256: 577c9e9751a0c2ad9683fdc060b69d95265eb0c7e3ac8568acf8c92621dbe244

```gdscript
func mark_plot_dirty(owner_slot: int) -> OpResult:
	"""Mark one owner's demand for reconciliation. Idempotent: a repeat adds no second entry.

	Accepts an addressable slot whether or not a plot is present, because retiring the record of
	a destroyed owner is itself a reconciliation. Refuses only an out-of-range slot.
	"""
	if not is_owner_slot(owner_slot):
		return _refuse(REFUSE_INVALID_OWNER_SLOT)
	if _is_dirty[owner_slot] == 1:
		return _succeed(_dirty_count, EntityDirectory.NULL_REF)
	_is_dirty[owner_slot] = 1
	_dirty_rows[_dirty_count] = owner_slot
	_dirty_count += 1
	return _succeed(_dirty_count, EntityDirectory.NULL_REF)



func _pop_dirty() -> int:
	"""Remove and return the most recently marked owner, clearing its membership bit."""
	_dirty_count -= 1
	var owner_slot: int = _dirty_rows[_dirty_count]
	_dirty_rows[_dirty_count] = 0
	_is_dirty[owner_slot] = 0
	return owner_slot


# --- reconciliation (R06-JOB-008) --------------------------------------------------------------


func mark_zone_dirty(zone_slot: int) -> OpResult:
	"""Mark one designation's demand for reconciliation. Idempotent: a repeat adds no entry.

	R06-JOB-002's trigger. A caller marks here when stock, quota, reservation capacity or access
	changes, and midnight marks every zone because resetting the day's collected totals IS quota
	becoming available. Accepts an addressable slot whether or not a zone is present, because
	retiring the record of a destroyed designation is itself a reconciliation.
	"""
	if not is_zone_owner_slot(zone_slot):
		return _refuse(REFUSE_INVALID_ZONE_SLOT)
	if _is_zone_dirty[zone_slot] == 1:
		return _succeed(_dirty_zone_count, EntityDirectory.NULL_REF)
	_is_zone_dirty[zone_slot] = 1
	_dirty_zone_rows[_dirty_zone_count] = zone_slot
	_dirty_zone_count += 1
	return _succeed(_dirty_zone_count, EntityDirectory.NULL_REF)



func _pop_dirty_zone() -> int:
	"""Remove and return the most recently marked designation, clearing its membership bit."""
	_dirty_zone_count -= 1
	var zone_slot: int = _dirty_zone_rows[_dirty_zone_count]
	_dirty_zone_rows[_dirty_zone_count] = 0
	_is_zone_dirty[zone_slot] = 0
	return zone_slot


# --- R06-JOB-002: reconciliation and publication ---------------------------------------------------


func mark_hive_dirty(hive_slot: int) -> OpResult:
	"""Mark one hive's service demand for reconciliation. Idempotent: a repeat adds no entry.

	Accepts an addressable slot whether or not a hive is present, because retiring the record of
	a destroyed hive is itself a reconciliation. Refuses only an out-of-range slot.
	"""
	if not is_hive_owner_slot(hive_slot):
		return _refuse(REFUSE_INVALID_HIVE_SLOT)
	if _is_hive_dirty[hive_slot] == 1:
		return _succeed(_dirty_hive_count, EntityDirectory.NULL_REF)
	_is_hive_dirty[hive_slot] = 1
	_dirty_hive_rows[_dirty_hive_count] = hive_slot
	_dirty_hive_count += 1
	return _succeed(_dirty_hive_count, EntityDirectory.NULL_REF)



func _pop_dirty_hive() -> int:
	"""Remove and return the most recently marked hive, clearing its membership bit."""
	_dirty_hive_count -= 1
	var hive_slot: int = _dirty_hive_rows[_dirty_hive_count]
	_dirty_hive_rows[_dirty_hive_count] = 0
	_is_hive_dirty[hive_slot] = 0
	return hive_slot


# --- R06-JOB-006: reconciliation and publication --------------------------------------------------

```
