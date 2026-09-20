# Directory source (immutable)
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


func is_valid(ref: Vector2i) -> bool:
	"""ARCH-ID-003 validation in `ANY` mode: true when `ref` still names a live row."""
	return is_valid_of_kind(ref, KIND_ANY)


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


func get_kind(ref: Vector2i) -> int:
	"""The kind of a live reference, or KIND_ANY when the reference is stale."""
	if not is_valid(ref):
		return KIND_ANY
	return _kind[ref.x]


func get_typed_row(ref: Vector2i) -> int:
	"""The typed-store row of a live reference, or NULL_SLOT when it is stale."""
	if not is_valid(ref):
		return NULL_SLOT
	return _typed_row[ref.x]


func owner_slot_of_typed_row(kind: int, row: int) -> int:
	"""The directory slot owning one kind's typed row, or NULL_SLOT when that row is free.

	ARCH-ID-003's reverse map, read forwards. An owner-indexed child store whose row index IS the
	owner's typed row (fishing.gd's FishingEffortClaim is one) needs this to rebuild the owner's
	reference from the row alone, without spending a second slot column per row to store it.
	No new allocation: `_typed_owner_slot` already exists for the validator.
	"""
	if kind < 0 or kind >= KIND_COUNT:
		return NULL_SLOT
	if row < 0 or row >= KIND_CAPACITY[kind]:
		return NULL_SLOT
	return _typed_owner_slot[_kind_base[kind] + row]


func ref_of_slot(slot: int) -> Vector2i:
	"""The live reference naming `slot`, or NULL_REF when that slot holds no live row.

	The reverse of `is_valid()`: a caller that has a SLOT -- an audit walking the directory, a
	loader rebuilding references, `owner_slot_of_typed_row()`'s answer -- rebuilds the full
	`(slot, generation)` pair here instead of storing a second copy of the generation beside it.
	NULL_REF is GDD §4.1's own null reference `(-1, 0)`, not a failure sentinel: an inactive slot
	genuinely names no entity, and the returned reference validates like any other.

	Adds no column and no allocator state; it reads the two that ARCH-ID-002 already keeps.
	"""
	if slot < 0 or slot >= DIRECTORY_CAPACITY:
		return NULL_REF
	if _active[slot] != 1:
		return NULL_REF
	return Vector2i(slot, _generation[slot])


func get_persistent_id(ref: Vector2i) -> int:
	"""The never-reused persistent ID of a live reference, or 0 when it is stale."""
	if not is_valid(ref):
		return 0
	return _persistent_id[ref.x]


func is_slot_retired(slot: int) -> bool:
	"""True when the slot spent its last generation and can never be allocated again."""
	if slot < 0 or slot >= DIRECTORY_CAPACITY:
		return false
	return _retired[slot] == 1


func live_count(kind: int) -> int:
	"""Number of live rows of one kind, or 0 for an unknown kind."""
	if kind < 0 or kind >= KIND_COUNT:
		return 0
	return _kind_live_count[kind]


func total_live_count() -> int:
	"""Number of live directory rows across every kind."""
	return _live_count


func free_slot_count() -> int:
	"""Directory slots still available to allocate."""
	return _free_count


func free_row_count(kind: int) -> int:
	"""Typed rows of one kind still available, or 0 for an unknown kind."""
	if kind < 0 or kind >= KIND_COUNT:
		return 0
	return _kind_free_count[kind]


func capacity_of_kind(kind: int) -> int:
	"""Maximum rows of one kind, or 0 for an unknown kind."""
	if kind < 0 or kind >= KIND_COUNT:
		return 0
	return KIND_CAPACITY[kind]


func last_refusal() -> StringName:
	"""The code from the most recent refused create, or REFUSAL_NONE after a success."""
	return _last_refusal


func last_column_refusal() -> StringName:
	"""The code from the most recent refused bulk column call, or REFUSAL_NONE after a success.

	Deliberately SEPARATE from `last_refusal()`. That one answers for `create()` and callers read
	it straight after a NULL_REF; a save or load clobbering it would make a create refusal report
	a column problem. The two namespaces never share a code value either: every code here is
	prefixed `COLUMN_`.
	"""
	return _last_column_refusal


func copy_columns_into(out_active: PackedByteArray, out_generation: PackedInt32Array,
		out_retired: PackedByteArray, out_persistent_id: PackedInt32Array,
		out_kind: PackedInt32Array, out_typed_row: PackedInt32Array) -> bool:
	"""Copy the six persisted columns into caller-owned buffers. False refuses; see
	`last_column_refusal()`.

	ARCH-SAVE-002 §3's capture step, and the ONLY way to read the generation of an inactive slot:
	every other reader answers for live slots alone, so the free and retired generations the
	persistence registry requires to survive verbatim are unreachable without this. These are
	DIRECTORY generations -- not `inventory.gd`'s container or lot generation, and not
	`navigation.gd`'s route-descriptor generation.

	Packed arrays are passed by reference, so each buffer is refilled in place. Every buffer must
	already be DIRECTORY_CAPACITY long: a caller who hands over a differently sized array has
	handed over the wrong array, and silently resizing it would hide that. The copies are
	snapshots -- mutating them afterwards cannot reach a column.

	Category 2 is deliberately absent. `_typed_owner_slot`, both heaps and every counter are
	rebuilt by `restore_columns()`; the heap tail beyond `_free_count` is stale garbage, so two
	identical worlds can hold different bytes there (decision 0103).
	"""
	if not _columns_are_capacity_sized(out_active, out_generation, out_retired,
			out_persistent_id, out_kind, out_typed_row):
		_last_column_refusal = REFUSAL_COLUMN_SHAPE
		return false
	_refill(out_active, _active)
	_refill_i32(out_generation, _generation)
	_refill(out_retired, _retired)
	_refill_i32(out_persistent_id, _persistent_id)
	_refill_i32(out_kind, _kind)
	_refill_i32(out_typed_row, _typed_row)
	_last_column_refusal = REFUSAL_NONE
	return true


func restore_columns(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray, persistent_id: PackedInt32Array,
		kind: PackedInt32Array, typed_row: PackedInt32Array) -> bool:
	"""Replace the six persisted columns and rebuild every derived member. False refuses.

	ARCH-SAVE-002 §3's apply step. The directory becomes the world these columns describe: the
	previous contents are discarded wholesale, so a reference taken before the call belongs to a
	different world and is not honoured afterwards. Restore into a directory you are loading over.

	`_typed_owner_slot`, `_free_heap`, `_heap_index`, `_kind_free_count`, `_kind_live_count`,
	`_free_count` and `_live_count` are REBUILT, never read from the caller (`_kind_base` is the
	prefix sum of a compile-time constant and never moves). The rebuild IS the validator: a
	duplicate `(kind, typed_row)` is caught because two live slots try to own one arena entry.
	Both free windows are filled ASCENDING, which is what makes the next `create()` return the
	lowest free slot exactly as the saved world's would.

	Allocate before consume (decision 0059): every rule is checked before any column is written,
	and the one member the collision scan touches is rebuilt from the untouched columns on the way
	out, so a refusal leaves the directory byte-identical -- `state_bytes()` proves it.

	`_next_persistent_id` is NOT written here, and that is the contract rather than a gap: REG-R01
	assigns the cursor to §1 WORLD's own `entity_directory` block, so §3's codec must not carry a
	§1 value. `restore_columns_and_cursor()` is the entry point that installs both together, and
	a load restores §3 and the cursor through it under one unpublished barrier. A directory
	restored through THIS call keeps whatever cursor it already had.
	"""
	var refusal: StringName = _restore_refusal(active, generation, retired, persistent_id,
		kind, typed_row)
	if refusal != REFUSAL_NONE:
		_last_column_refusal = refusal
		return false
	var collision: StringName = _fill_owner_map(active, kind, typed_row)
	if collision != REFUSAL_NONE:
		var rolled_back: StringName = _fill_owner_map(_active, _kind, _typed_row)
		assert(rolled_back == REFUSAL_NONE, "the directory's own columns cannot collide")
		_last_column_refusal = collision
		return false
	_install_columns(active, generation, retired, persistent_id, kind, typed_row)
	_rebuild_allocator()
```
