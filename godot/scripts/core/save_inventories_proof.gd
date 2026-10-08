extends RefCounted
## The whole-column proof for section 7's six owner validators (ADR 1235).
##
## `owner_proven(block)` returns true only when native column checks (`column_proofs.gd`) plus
## the owner's own row validator run on each LIVE row (and once on a representative free row,
## where every free row is provably identical in what that validator reads) establish that
## `save_section_inventories.gd`'s row-by-row walk would accept the block. Any other answer is
## false and the caller walks every row itself, so a refusal's code, detail and row are unchanged.
##
## What each owner's proof covers, against its row walk:
##   * fishing, forage, gear, reservations: the occupancy bytes are 0/1; every free row carries
##     the canonical blank of every blank ordinal; every occupied row passes its row validator.
##   * inventory: the three occupancy columns are 0/1; every row generation is >= the canonical
##     minimum (an i32 cannot exceed INT32_MAX); every inactive row carries INV-CANON-R01's unused
##     values; each live row and one inactive row pass the row validator (an inactive row's
##     validator reads only its generation and those unused values); with no retired slot, each
##     free stack's live prefix is exactly the set of non-live slots.
##   * stock_age: the heated bytes are 0/1; the hour tick is in range; every class is declared or
##     UNDECLARED; undeclared rows carry heated 0 and generation 0; declared rows hold a live
##     generation; the dense list's prefix is exactly the set of declared slots.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const S07 := preload("res://scripts/core/save_section_inventories.gd")
const Bulk := preload("res://scripts/core/column_proofs.gd")


static func owner_proven(block: S07.OwnerRecord) -> bool:
	"""True when the block provably passes its owner's row walk; false means "walk it"."""
	if not _columns_sized(block):
		return false
	match block.owner:
		S07.OWNER_FISHING:
			return _blanking_proven(block, [0], S07.BLANK_ORDINALS_FISHING,
				func(row: int) -> bool: return S07._fishing_row_refusal(block, row).is_ok())
		S07.OWNER_FORAGE:
			return _blanking_proven(block, [0], S07.BLANK_ORDINALS_FORAGE,
				func(row: int) -> bool: return S07._forage_row_refusal(block, row).is_ok())
		S07.OWNER_GEAR:
			return _blanking_proven(block, [0, 9], S07.BLANK_ORDINALS_GEAR, func(row: int) -> bool:
				return S07._gear_row_refusal(block, row, block.u8_column(9)[row] == 1).is_ok())
		S07.OWNER_RESERVATIONS:
			return _blanking_proven(block, [0], S07.BLANK_ORDINALS_RESERVATIONS,
				func(row: int) -> bool: return S07._reservation_row_refusal(block, row).is_ok())
		S07.OWNER_INVENTORY:
			return _inventory_proven(block)
		S07.OWNER_STOCK_AGE:
			return _stock_age_proven(block)
	return false


static func _columns_sized(block: S07.OwnerRecord) -> bool:
	"""Every column at its declared backing extent, so no proof reads past a row walk's range."""
	if block.child_extents.size() != S07.child_extent_count_of(block.owner):
		return false
	for ordinal: int in S07.field_count_of(block.owner):
		if not S07._column_length_refusal(block, ordinal).is_ok():
			return false
	return true


static func _others_equal(block: S07.OwnerRecord, ordinal: int, skip: PackedInt32Array,
		value: int) -> bool:
	"""Every cell of one column outside `skip` equals `value`, whatever its storage kind."""
	var type_code: int = S07.field_type_of(block.owner, ordinal)
	if type_code == S07.TYPE_U8:
		return value >= 0 and value <= 255 \
			and Bulk.u8_others_equal(block.u8_column(ordinal), skip, value)
	if type_code == S07.TYPE_I32:
		return Bulk.i32_others_equal(block.i32_column(ordinal), skip, value)
	return Bulk.i64_others_equal(block.i64_column(ordinal), skip, value)


static func _rows_pass(rows: PackedInt32Array, check: Callable) -> bool:
	"""True when `check(row)` holds for every row of `rows`."""
	for row: int in rows:
		if not check.call(row):
			return false
	return true


# --- the four blanking owners ---------------------------------------------------------------------

static func _blanking_proven(block: S07.OwnerRecord, flag_ordinals: Array[int],
		blank_ordinals: Array[int], live_row_ok: Callable) -> bool:
	"""Flags are 0/1, free rows carry every canonical blank, occupied rows pass their check."""
	for ordinal: int in flag_ordinals:
		if not Bulk.bytes_are_flags(block.u8_column(ordinal)):
			return false
	var live: PackedInt32Array = Bulk.rows_holding(block.u8_column(0), 1)
	for ordinal: int in blank_ordinals:
		if not _others_equal(block, ordinal, live, S07.canonical_fill_of(block.owner, ordinal)):
			return false
	return _rows_pass(live, live_row_ok)


# --- inventory ------------------------------------------------------------------------------------

static func _inventory_proven(block: S07.OwnerRecord) -> bool:
	"""Occupancy, both tables and both free stacks (see the module comment)."""
	for ordinal: int in [2, 3, 15]:
		if not Bulk.bytes_are_flags(block.u8_column(ordinal)):
			return false
	var lot_capacity: int = int(block.child_extents[0])
	var live_containers: PackedInt32Array = Bulk.rows_holding(block.u8_column(2), 1)
	var live_lots: PackedInt32Array = Bulk.rows_holding(block.u8_column(3), 1)
	var containers: bool = _table_proven(block, 2, 4, live_containers,
		S07.INVENTORY_UNUSED_CONTAINER_ORDINALS, S07.INVENTORY_UNUSED_CONTAINER_VALUES,
		func(slot: int, is_live: bool) -> bool:
			return S07._container_row_refusal(block, slot, is_live, lot_capacity).is_ok())
	if not containers:
		return false
	var lots: bool = _table_proven(block, 3, 5, live_lots, S07.INVENTORY_UNUSED_LOT_ORDINALS,
		S07.INVENTORY_UNUSED_LOT_VALUES, func(slot: int, is_live: bool) -> bool:
			return S07._lot_row_refusal(block, slot, is_live, lot_capacity).is_ok())
	if not lots:
		return false
	return _free_stack_proven(block, 28, 0, 4, live_containers) \
		and _free_stack_proven(block, 29, 1, 5, live_lots)


static func _table_proven(block: S07.OwnerRecord, live_ordinal: int, generation_ordinal: int,
		live: PackedInt32Array, unused_ordinals: Array[int], unused_values: Array[int],
		row_ok: Callable) -> bool:
	"""Generations in range, inactive rows at their unused values, live rows and one free row pass."""
	if Bulk.i32_minimum(block.i32_column(generation_ordinal)) < S07.INVENTORY_GENERATION_MIN:
		return false
	for index: int in unused_ordinals.size():
		if not _others_equal(block, unused_ordinals[index], live, unused_values[index]):
			return false
	var free_row: int = block.u8_column(live_ordinal).find(0)
	if free_row >= 0 and not row_ok.call(free_row, false):
		return false
	return _rows_pass(live, func(slot: int) -> bool: return row_ok.call(slot, true))


static func _free_stack_proven(block: S07.OwnerRecord, stack_ordinal: int, count_ordinal: int,
		generation_ordinal: int, live: PackedInt32Array) -> bool:
	"""With no retired slot, the stack's live prefix is exactly the set of non-live slots."""
	if block.i32_column(generation_ordinal).has(S07.MAX_INT32):
		return false
	var stack: PackedInt32Array = block.i32_column(stack_ordinal)
	var count: int = block.scalar(count_ordinal)
	if count < 0 or count > stack.size():
		return false
	return Bulk.is_permutation_of(stack.slice(0, count),
		Bulk.ascending_except(stack.size(), live))


# --- stock_age ------------------------------------------------------------------------------------

static func _stock_age_proven(block: S07.OwnerRecord) -> bool:
	"""Heated flags, the hour tick, every class row and the dense declared list."""
	if not Bulk.bytes_are_flags(block.u8_column(3)):
		return false
	if block.i64_column(1)[0] < S07.NO_HOUR_RUN:
		return false
	if not _classes_in_domain(block.u8_column(2)):
		return false
	var declared: PackedInt32Array = _declared_rows(block.u8_column(2))
	if not Bulk.u8_others_equal(block.u8_column(3), declared, 0) \
			or not Bulk.i32_others_equal(block.i32_column(4), declared, 0):
		return false
	var generation: PackedInt32Array = block.i32_column(4)
	for slot: int in declared:
		if not S07._generation_refusal(generation[slot], true, block.owner, 4, slot).is_ok():
			return false
	var count: int = block.scalar(0)
	if count < 0 or count > block.primary_count:
		return false
	return Bulk.is_permutation_of(block.i32_column(5).slice(0, count), declared)


static func _classes_in_domain(classes: PackedByteArray) -> bool:
	"""True when every storage class byte is below STORAGE_CLASS_COUNT."""
	var in_domain: int = 0
	for value: int in S07.STORAGE_CLASS_COUNT:
		in_domain += classes.count(value)
	return in_domain == classes.size()


static func _declared_rows(classes: PackedByteArray) -> PackedInt32Array:
	"""Ascending rows whose class is not UNDECLARED."""
	var declared: PackedInt32Array = PackedInt32Array()
	for value: int in S07.STORAGE_CLASS_COUNT:
		if value != S07.STORAGE_UNDECLARED:
			declared.append_array(Bulk.rows_holding(classes, value))
	declared.sort()
	return declared
