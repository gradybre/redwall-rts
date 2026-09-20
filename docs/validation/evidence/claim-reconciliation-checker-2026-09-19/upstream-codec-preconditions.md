# Verified upstream codec preconditions
Current source SHA256 `5b12195a52bf641bd5609f1b529ddff48696755ba4d3c5e840052183458285f0`.
Astra inspected the exact source after independent review. Accessors return the stored packed arrays without duplicate; checker never writes through those references. The slot/generation and patch-kind gates run before checker indexing. Tests now pin their pass-through refusals.

## Lines487–504
```gdscript
	func u8_column(ordinal: int) -> PackedByteArray:
		"""The u8 column at `ordinal`. Empty when that ordinal is not a u8 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_U8:
			return PackedByteArray()
		return u8_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i32_column(ordinal: int) -> PackedInt32Array:
		"""The i32 column at `ordinal`. Empty when that ordinal is not an i32 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I32:
			return PackedInt32Array()
		return i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i64_column(ordinal: int) -> PackedInt64Array:
		"""The u32/i64 column at `ordinal`. Empty when that ordinal is neither."""
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		if type_code != TYPE_I64 and type_code != TYPE_U32:
			return PackedInt64Array()
		return i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]
```

## Lines1714–1737
```gdscript
static func _fishing_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one live claim: the stored owner pair, both references and the slot count.

	Ordinal 7 is FISH-ID-R01's appended owner slot, validated at its wire position with no live
	Directory lookup: 0..DIRECTORY_CAPACITY-1 while active, and the blank -1 while it is not.
	"""
	for ordinal: int in [1, 3, 5]:
		var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(ordinal)[row],
			true, block.owner, ordinal, row)
		if not generation.is_ok():
			return generation
	for ordinal: int in [2, 4, 7]:
		var slot: SaveHeader.Refusal = _slot_refusal(block.i32_column(ordinal)[row], true,
			DIRECTORY_CAPACITY, block.owner, ordinal, row)
		if not slot.is_ok():
			return slot
	if block.i32_column(6)[row] < 1:
		return _refuse(REFUSE_SLOT_COUNT,
			"fishing row %d is an active claim on %d effort slots"
				% [row, block.i32_column(6)[row]])
	return _accepted()


static func _forage_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
```

## Lines1759–1786
```gdscript
static func _forage_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one live forage claim: three directory refs, a patch kind and three int64s."""
	var slots: Array[int] = [1, 3, 5]
	var generations: Array[int] = [2, 4, 6]
	for index: int in slots.size():
		var slot: SaveHeader.Refusal = _slot_refusal(block.i32_column(slots[index])[row], true,
			DIRECTORY_CAPACITY, block.owner, slots[index], row)
		if not slot.is_ok():
			return slot
		var generation: SaveHeader.Refusal = _generation_refusal(
			block.i32_column(generations[index])[row], true, block.owner, generations[index], row)
		if not generation.is_ok():
			return generation
	var kind: int = block.i32_column(7)[row]
	if kind < 0 or kind >= FORAGE_PATCH_KIND_COUNT:
		return _refuse(REFUSE_PATCH_KIND,
			"forage row %d claims patch kind %d, outside 0..%d"
				% [row, kind, FORAGE_PATCH_KIND_COUNT - 1])
	for ordinal: int in [8, 9, 10]:
		if block.i64_column(ordinal)[row] < 0:
			return _refuse(REFUSE_QUANTITY_RANGE,
				"forage row %d field '%s' is negative" % [row, KEYS_FORAGE[ordinal]])
	return _accepted()


static func _gear_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `gear.gd`'s GearInstance rows.

```
