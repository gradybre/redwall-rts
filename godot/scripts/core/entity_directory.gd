extends RefCounted
## Global referenceable entity directory: identity columns plus the two-level
## slot allocator standing behind every `EntityRef`.
##
## ARCH-ID-001 gives every referenceable runtime entity one row in a single flat
## directory of G=352418 slots. The row's `kind` and `typed_row` locate its data
## in the per-kind typed store. A reference is the GDD §4.1 pair
## `(slot:int32, generation:int32)`, carried here as `Vector2i` so a reference is
## a value with no heap allocation; the null reference is `(-1, 0)`.
##
## ARCH-ID-002 requires preallocated indexed min-heaps of free indices at both
## levels: one global free-directory heap, and one free-row heap per kind.
## ARCH-MEM-008 partitions that allocation into two arenas of G entries each and
## names the second one `heap_index`, which is what `_heap_index` holds: the
## per-kind free-row heaps, each occupying the window `[base(kind), base+cap)`.
##
## ARCH-MEM-001/005: every column is a packed array allocated once to capacity in
## `_init()`. No GDScript `Array` is allocated per row, and nothing here calls
## `resize()` outside construction -- `clear()` refills the existing buffers.
##
## ARCH-SAVE-002 section 3 reads and writes this store in bulk through
## `copy_columns_into()` and `restore_columns()`: the six persisted columns move
## as a set, and every derived member is rebuilt from them rather than carried.
## Those two are the ONLY way to reach the generation of an inactive slot, which
## every other reader hides because it answers for live rows alone. The
## generations here are the DIRECTORY namespace and no other -- `inventory.gd`
## carries its own container and lot generations, and `navigation.gd` its own
## route-descriptor generation, all independently of these.
##
## Promoted from the verified `docs/validation/headless/resident_slots.gd`
## kernel, which stays in place as the isolated experimental control.

const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)

## Validator mode for `is_valid_of_kind`, never a stored kind value (ARCH-ID-003).
const KIND_ANY: int = -1

## Largest int32. Bounds generation, persistent ID, and every packed column.
const MAX_INT32: int = 2147483647

## Kind IDs are the index of each key in ascending ASCII order (ARCH-ID-001).
const KIND_BUILDING: int = 0
const KIND_CONSTRUCTION: int = 1
const KIND_EXPEDITION: int = 2
const KIND_FARM_PLOT: int = 3
const KIND_FEAST: int = 4
const KIND_FISH_HABITAT: int = 5
const KIND_FURNITURE: int = 6
const KIND_HARVEST_ZONE: int = 7
const KIND_HIVE: int = 8
const KIND_INVENTORY_CONTAINER: int = 9
const KIND_INVENTORY_LOT: int = 10
const KIND_JOB: int = 11
const KIND_ORCHARD_PLOT: int = 12
const KIND_PRODUCTION_ORDER: int = 13
const KIND_RESIDENT: int = 14
const KIND_RESOURCE_NODE: int = 15
const KIND_ROOM: int = 16
const KIND_WORLD: int = 17
const KIND_COUNT: int = 18

## Kind keys in the ascending ASCII order that fixes the IDs above.
const KIND_KEYS: Array[StringName] = [
	&"building", &"construction", &"expedition", &"farm_plot", &"feast",
	&"fish_habitat", &"furniture", &"harvest_zone", &"hive",
	&"inventory_container", &"inventory_lot", &"job", &"orchard_plot",
	&"production_order", &"resident", &"resource_node", &"room", &"world",
]

## Maximum rows per kind, systems_architecture.md §2.1. Sums to DIRECTORY_CAPACITY.
const KIND_CAPACITY: Array[int] = [
	1024, 82944, 512, 4096, 1,
	32, 81920, 128, 1024,
	101376, 16384, 8192, 1024,
	32768, 512, 4096, 16384, 1,
]

## Refusal code per kind, ARCH-ID-004 `CAPACITY_<STORE>`. Precomputed so the
## refusal path never concatenates a string.
const KIND_CAPACITY_REFUSAL: Array[StringName] = [
	&"CAPACITY_BUILDING", &"CAPACITY_CONSTRUCTION", &"CAPACITY_EXPEDITION",
	&"CAPACITY_FARM_PLOT", &"CAPACITY_FEAST", &"CAPACITY_FISH_HABITAT",
	&"CAPACITY_FURNITURE", &"CAPACITY_HARVEST_ZONE", &"CAPACITY_HIVE",
	&"CAPACITY_INVENTORY_CONTAINER", &"CAPACITY_INVENTORY_LOT", &"CAPACITY_JOB",
	&"CAPACITY_ORCHARD_PLOT", &"CAPACITY_PRODUCTION_ORDER", &"CAPACITY_RESIDENT",
	&"CAPACITY_RESOURCE_NODE", &"CAPACITY_ROOM", &"CAPACITY_WORLD",
]

## Directory length G, systems_architecture.md §2.1.
const DIRECTORY_CAPACITY: int = 352418

## Resident storage is 512 slots but living residents never exceed 256 (GDD §4.1).
const RESIDENT_LIVING_CAP: int = 256

const REFUSAL_NONE: StringName = &""
const REFUSAL_UNKNOWN_KIND: StringName = &"UNKNOWN_KIND"
const REFUSAL_DIRECTORY_FULL: StringName = &"CAPACITY_DIRECTORY"
const REFUSAL_PERSISTENT_ID: StringName = &"PERSISTENT_ID_EXHAUSTED"
const REFUSAL_LIVING_CAP: StringName = &"LIVING_CAP_RESIDENT"

## Bulk column refusals, read through `last_column_refusal()` and never through `last_refusal()`.
## ARCH-ID-004 numbers the `create()` codes above; it publishes no registry for column operations,
## so these spellings are this module's PROPOSAL (decision 0105) and change if one lands.
const REFUSAL_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSAL_COLUMN_ACTIVE_BYTE: StringName = &"COLUMN_ACTIVE_BYTE"
const REFUSAL_COLUMN_RETIRED_BYTE: StringName = &"COLUMN_RETIRED_BYTE"
const REFUSAL_COLUMN_GENERATION_NEGATIVE: StringName = &"COLUMN_GENERATION_NEGATIVE"
const REFUSAL_COLUMN_LIVE_GENERATION: StringName = &"COLUMN_LIVE_GENERATION"
const REFUSAL_COLUMN_LIVE_PERSISTENT_ID: StringName = &"COLUMN_LIVE_PERSISTENT_ID"
const REFUSAL_COLUMN_LIVE_KIND: StringName = &"COLUMN_LIVE_KIND"
const REFUSAL_COLUMN_LIVE_ROW: StringName = &"COLUMN_LIVE_ROW"
const REFUSAL_COLUMN_FREE_IDENTITY: StringName = &"COLUMN_FREE_IDENTITY"
const REFUSAL_COLUMN_RETIREMENT: StringName = &"COLUMN_RETIREMENT"
const REFUSAL_COLUMN_DUPLICATE_TYPED_ROW: StringName = &"COLUMN_DUPLICATE_TYPED_ROW"
const REFUSAL_COLUMN_LIVING_CAP: StringName = &"COLUMN_LIVING_CAP"

# EntityIdentity columns, systems_architecture.md §2.2.
var _persistent_id: PackedInt32Array = PackedInt32Array()
var _generation: PackedInt32Array = PackedInt32Array()
var _kind: PackedInt32Array = PackedInt32Array()
var _active: PackedByteArray = PackedByteArray()

# DirectoryIndex columns, systems_architecture.md §3.
# `_typed_row` locates the row in the kind's typed store and `_typed_owner_slot`
# is the reverse map ARCH-ID-003 validates against. Owner-indexed child stores
# (Reservation, GearInstance, BatchState, LotEffect, NoticeCondition,
# ChildSliceIndex) would hang off the same typed row, but blocker U5 records that
# the architecture ledger budgets no allocator storage for them, so this
# directory allocates for the 18 directory kinds only.
var _typed_row: PackedInt32Array = PackedInt32Array()
var _typed_owner_slot: PackedInt32Array = PackedInt32Array()
var _retired: PackedByteArray = PackedByteArray()
var _free_heap: PackedInt32Array = PackedInt32Array()
var _heap_index: PackedInt32Array = PackedInt32Array()

# Allocator counters. `_kind_base` holds the prefix sums that partition the
# per-kind arenas inside `_heap_index` and `_typed_owner_slot`.
var _kind_base: PackedInt32Array = PackedInt32Array()
var _kind_free_count: PackedInt32Array = PackedInt32Array()
var _kind_live_count: PackedInt32Array = PackedInt32Array()
var _free_count: int = 0
var _live_count: int = 0
var _next_persistent_id: int = 1
var _last_refusal: StringName = REFUSAL_NONE
## The bulk-column namespace's own refusal code. Category 3 like `_last_refusal`: not state, not
## persisted, and excluded from `state_bytes()` so a refusal cannot alter the image proving it
## changed nothing.
var _last_column_refusal: StringName = REFUSAL_NONE


func _init() -> void:
	"""Allocate every column once to capacity, then initialize the free heaps."""
	_allocate_columns()
	clear()


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

	`_next_persistent_id` is NOT restored: the registry assigns it to §1 WORLD as
	`WorldRuntime.next_persistent_id` (BLOCKER D2). Until §1 carries it, a restored directory
	reissues persistent IDs from wherever its own allocator stands.
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
	_last_column_refusal = REFUSAL_NONE
	return true


func state_bytes() -> PackedByteArray:
	"""Diagnostic image of every member the directory's behaviour depends on.

	NOT A PRODUCTION CALL: it allocates about ten megabytes. It exists so a refused
	`restore_columns()` can be proved to have changed nothing, by comparison rather than by eye.

	Included: the six persisted columns, `_typed_owner_slot`, the three per-kind counter arrays,
	`_free_count`, `_live_count`, `_next_persistent_id`, and each free window's live prefix SORTED.
	Excluded: the heap tails beyond `_free_count` / `_kind_free_count[kind]`, which are stale
	garbage two identical worlds can disagree on (decision 0103), and `_last_refusal` /
	`_last_column_refusal`, which are category 3 and would make every refusal change the image it
	is being compared against.

	The prefixes are sorted for the same reason the heaps are rebuilt rather than saved:
	`_pop_min()` returns the window minimum, so allocation order depends on the free SET and never
	on the permutation. A live directory holds that set in whatever order its pops and pushes
	left; a restored one holds it ascending. Comparing the sets is what makes the two comparable,
	and it still catches a live slot left in the pool or a free slot lost from it.
	"""
	var image: PackedByteArray = PackedByteArray()
	image.append_array(_active)
	image.append_array(_retired)
	image.append_array(_generation.to_byte_array())
	image.append_array(_persistent_id.to_byte_array())
	image.append_array(_kind.to_byte_array())
	image.append_array(_typed_row.to_byte_array())
	image.append_array(_typed_owner_slot.to_byte_array())
	image.append_array(_kind_base.to_byte_array())
	image.append_array(_kind_free_count.to_byte_array())
	image.append_array(_kind_live_count.to_byte_array())
	image.append_array(PackedInt64Array(
		[_free_count, _live_count, _next_persistent_id]).to_byte_array())
	image.append_array(_sorted_window_bytes(_free_heap, 0, _free_count))
	for kind: int in range(KIND_COUNT):
		image.append_array(_sorted_window_bytes(_heap_index, _kind_base[kind],
			_kind_free_count[kind]))
	return image


func _sorted_window_bytes(heap: PackedInt32Array, base: int, count: int) -> PackedByteArray:
	"""One free window's live entries, sorted: the free SET rather than its heap permutation."""
	var window: PackedInt32Array = heap.slice(base, base + count)
	window.sort()
	return window.to_byte_array()


func clear() -> void:
	"""Drop every row and refill both heaps without reallocating a column.

	`_generation` and `_retired` are deliberately NOT reset. Zeroing the generation column
	would hand the next create the very `(slot, generation)` pair a reference taken before
	the clear still holds, and that reference would then validate against an unrelated row --
	the aliasing ARCH-ID-002's generation counter exists to make impossible. Generations
	therefore only ever move forward: across reuse, and across a clear as well.
	"""
	_persistent_id.fill(0)
	_kind.fill(KIND_ANY)
	_active.fill(0)
	_typed_row.fill(NULL_SLOT)
	_typed_owner_slot.fill(NULL_SLOT)
	_rebuild_free_heaps()
	_live_count = 0
	_next_persistent_id = 1
	_last_refusal = REFUSAL_NONE
	_last_column_refusal = REFUSAL_NONE


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_persistent_id.resize(DIRECTORY_CAPACITY)
	_generation.resize(DIRECTORY_CAPACITY)
	_kind.resize(DIRECTORY_CAPACITY)
	_active.resize(DIRECTORY_CAPACITY)
	_typed_row.resize(DIRECTORY_CAPACITY)
	_typed_owner_slot.resize(DIRECTORY_CAPACITY)
	_retired.resize(DIRECTORY_CAPACITY)
	_free_heap.resize(DIRECTORY_CAPACITY)
	_heap_index.resize(DIRECTORY_CAPACITY)
	_kind_base.resize(KIND_COUNT)
	_kind_free_count.resize(KIND_COUNT)
	_kind_live_count.resize(KIND_COUNT)
	var base: int = 0
	for kind: int in range(KIND_COUNT):
		_kind_base[kind] = base
		base += KIND_CAPACITY[kind]
	assert(base == DIRECTORY_CAPACITY, "kind capacities must sum to the directory length")


func _rebuild_free_heaps() -> void:
	"""Fill both arenas with ascending indices, which is already a valid min-heap.

	A slot that has spent its last generation is left out and marked retired instead: handing
	it back would need a wrapped generation, and a wrapped generation is exactly the collision
	ARCH-ID-002 forbids. Ascending order survives the gaps, so the window stays a min-heap.
	"""
	var free_slots: int = 0
	for slot: int in range(DIRECTORY_CAPACITY):
		if _generation[slot] >= MAX_INT32:
			_retired[slot] = 1
			continue
		_free_heap[free_slots] = slot
		free_slots += 1
	_free_count = free_slots
	_rebuild_kind_heaps()


func _rebuild_kind_heaps() -> void:
	"""Refill each kind's free-row window with that kind's rows in ascending order."""
	for kind: int in range(KIND_COUNT):
		var base: int = _kind_base[kind]
		var capacity: int = KIND_CAPACITY[kind]
		for row: int in range(capacity):
			_heap_index[base + row] = row
		_kind_free_count[kind] = capacity
		_kind_live_count[kind] = 0


func _columns_are_capacity_sized(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray, persistent_id: PackedInt32Array, kind: PackedInt32Array,
		typed_row: PackedInt32Array) -> bool:
	"""True when all six buffers are exactly DIRECTORY_CAPACITY long, before anything indexes them."""
	return active.size() == DIRECTORY_CAPACITY \
		and generation.size() == DIRECTORY_CAPACITY \
		and retired.size() == DIRECTORY_CAPACITY \
		and persistent_id.size() == DIRECTORY_CAPACITY \
		and kind.size() == DIRECTORY_CAPACITY \
		and typed_row.size() == DIRECTORY_CAPACITY


func _refill(out: PackedByteArray, source: PackedByteArray) -> void:
	"""Refill a caller's byte buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)


func _refill_i32(out: PackedInt32Array, source: PackedInt32Array) -> void:
	"""Refill a caller's int32 buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)


func _restore_refusal(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray, persistent_id: PackedInt32Array, kind: PackedInt32Array,
		typed_row: PackedInt32Array) -> StringName:
	"""Every rule a restored column set must satisfy, checked before a single column is written.

	The duplicate `(kind, typed_row)` rule is NOT here: it is the rebuild's own collision, checked
	by `_fill_owner_map()` so that one piece of code cannot drift from the other.
	"""
	if not _columns_are_capacity_sized(active, generation, retired, persistent_id, kind,
			typed_row):
		return REFUSAL_COLUMN_SHAPE
	var domain: StringName = _column_domain_refusal(active, retired, generation)
	if domain != REFUSAL_NONE:
		return domain
	var live: StringName = _live_column_refusal(active, generation, persistent_id, kind, typed_row)
	if live != REFUSAL_NONE:
		return live
	var retirement: StringName = _retirement_column_refusal(active, generation, retired)
	if retirement != REFUSAL_NONE:
		return retirement
	return _free_identity_refusal(active, persistent_id, kind, typed_row)


func _column_domain_refusal(active: PackedByteArray, retired: PackedByteArray,
		generation: PackedInt32Array) -> StringName:
	"""Both occupancy bytes are 0 or 1, and no generation is negative.

	The generation guard is the int32 sign trap: GDScript ints are 64-bit, so a column carrying
	the bytes `00 00 00 80` holds -2147483648, not the plausible 2147483648 no int32 can store.
	Sorting a copy is one C++ call and only the minimum is read.
	"""
	if active.count(0) + active.count(1) != DIRECTORY_CAPACITY:
		return REFUSAL_COLUMN_ACTIVE_BYTE
	if retired.count(0) + retired.count(1) != DIRECTORY_CAPACITY:
		return REFUSAL_COLUMN_RETIRED_BYTE
	var sorted: PackedInt32Array = generation.duplicate()
	sorted.sort()
	if sorted[0] < 0:
		return REFUSAL_COLUMN_GENERATION_NEGATIVE
	return REFUSAL_NONE


func _live_column_refusal(active: PackedByteArray, generation: PackedInt32Array,
		persistent_id: PackedInt32Array, kind: PackedInt32Array,
		typed_row: PackedInt32Array) -> StringName:
	"""Validate each live slot's identity, exactly as `_publish_row()` would have left it.

	`find(1, ...)` jumps from one live slot to the next in C++, so this costs the number of LIVE
	rows and not the 352418-slot capacity. It also proves no live slot holds a free slot's unused
	values, which is what lets `_free_identity_refusal()` finish the job by counting.
	"""
	var slot: int = active.find(1, 0)
	while slot >= 0:
		if generation[slot] < 1:
			return REFUSAL_COLUMN_LIVE_GENERATION
		if persistent_id[slot] < 1:
			return REFUSAL_COLUMN_LIVE_PERSISTENT_ID
		var row_kind: int = kind[slot]
		if row_kind < 0 or row_kind >= KIND_COUNT:
			return REFUSAL_COLUMN_LIVE_KIND
		var row: int = typed_row[slot]
		if row < 0 or row >= KIND_CAPACITY[row_kind]:
			return REFUSAL_COLUMN_LIVE_ROW
		slot = active.find(1, slot + 1)
	return REFUSAL_NONE


func _retirement_column_refusal(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray) -> StringName:
	"""Cross-check retirement in both directions, per slot and per column.

	Every retired slot must be inactive and hold the spent generation, AND every inactive slot
	holding the spent generation must be retired. Neither check subsumes the other: a balanced
	swap -- slot A retired at generation 10 while slot B sits at 2147483647 un-retired -- cancels
	in the counts and is only caught per slot, while a missing retirement mark is only caught by
	the count. Restoring either would hand `_publish_row()` a slot whose generation cannot rise.
	"""
	var slot: int = retired.find(1, 0)
	var retired_count: int = 0
	while slot >= 0:
		if active[slot] != 0 or generation[slot] != MAX_INT32:
			return REFUSAL_COLUMN_RETIREMENT
		retired_count += 1
		slot = retired.find(1, slot + 1)
	if generation.count(MAX_INT32) - _live_spent_count(active, generation) != retired_count:
		return REFUSAL_COLUMN_RETIREMENT
	return REFUSAL_NONE


func _live_spent_count(active: PackedByteArray, generation: PackedInt32Array) -> int:
	"""How many LIVE slots already sit on the last generation they will ever hold.

	A slot reaches 2147483647 while still live and retires on the NEXT `destroy()`, so this count
	separates "spent and retired" from "spent and still in use".
	"""
	var total: int = 0
	var slot: int = active.find(1, 0)
	while slot >= 0:
		if generation[slot] == MAX_INT32:
			total += 1
		slot = active.find(1, slot + 1)
	return total


func _free_identity_refusal(active: PackedByteArray, persistent_id: PackedInt32Array,
		kind: PackedInt32Array, typed_row: PackedInt32Array) -> StringName:
	"""Exactly the inactive slots carry the values `destroy()` leaves: id 0, kind -1, row -1.

	Counting suffices because `_live_column_refusal()` has already proved every live slot holds an
	id of at least 1, a kind inside [0, 18) and a row of at least 0 -- none of which is an unused
	value. This is what refuses a free slot whose -1 typed row was restored as row 0.
	"""
	var inactive: int = DIRECTORY_CAPACITY - active.count(1)
	if persistent_id.count(0) != inactive:
		return REFUSAL_COLUMN_FREE_IDENTITY
	if kind.count(KIND_ANY) != inactive:
		return REFUSAL_COLUMN_FREE_IDENTITY
	if typed_row.count(NULL_SLOT) != inactive:
		return REFUSAL_COLUMN_FREE_IDENTITY
	return REFUSAL_NONE


func _fill_owner_map(active: PackedByteArray, kind: PackedInt32Array,
		typed_row: PackedInt32Array) -> StringName:
	"""Rebuild `_typed_owner_slot` and `_kind_live_count` from three columns; the rebuild validates.

	A duplicate `(kind, typed_row)` needs no separate pass: two live slots claiming one arena
	entry collide here, which is the same instant ARCH-ID-003's reverse map would have been made
	ambiguous. Callers must have range-checked `kind` and `typed_row` first.
	"""
	_typed_owner_slot.fill(NULL_SLOT)
	_kind_live_count.fill(0)
	var slot: int = active.find(1, 0)
	while slot >= 0:
		var row_kind: int = kind[slot]
		var arena: int = _kind_base[row_kind] + typed_row[slot]
		if _typed_owner_slot[arena] != NULL_SLOT:
			return REFUSAL_COLUMN_DUPLICATE_TYPED_ROW
		_typed_owner_slot[arena] = slot
		_kind_live_count[row_kind] += 1
		slot = active.find(1, slot + 1)
	if _kind_live_count[KIND_RESIDENT] > RESIDENT_LIVING_CAP:
		return REFUSAL_COLUMN_LIVING_CAP
	return REFUSAL_NONE


func _install_columns(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray, persistent_id: PackedInt32Array, kind: PackedInt32Array,
		typed_row: PackedInt32Array) -> void:
	"""Take a private copy of each validated column. `duplicate()` so the caller cannot alias one."""
	_active = active.duplicate()
	_generation = generation.duplicate()
	_retired = retired.duplicate()
	_persistent_id = persistent_id.duplicate()
	_kind = kind.duplicate()
	_typed_row = typed_row.duplicate()


func _rebuild_allocator() -> void:
	"""Refill both free windows ASCENDING from the installed columns and recount every counter.

	Live slots are excluded, or the allocator would hand out a slot that already owns a row;
	retired slots are excluded, because handing one back needs a wrapped generation. Ascending
	fill is load-bearing rather than cosmetic: `_pop_min()` returns the window minimum, so a
	restored world allocates in the same order as the one that saved it only if the free SET is
	right, and ascending order is the canonical arrangement of that set.
	"""
	var free_slots: int = 0
	for slot: int in range(DIRECTORY_CAPACITY):
		if _active[slot] == 1 or _retired[slot] == 1:
			continue
		_free_heap[free_slots] = slot
		free_slots += 1
	_free_count = free_slots
	_live_count = 0
	for kind: int in range(KIND_COUNT):
		_live_count += _kind_live_count[kind]
		_rebuild_kind_rows(kind)


func _rebuild_kind_rows(kind: int) -> void:
	"""Refill one kind's free-row window with its unowned rows, ascending, and recount it."""
	var base: int = _kind_base[kind]
	var capacity: int = KIND_CAPACITY[kind]
	var free_rows: int = 0
	for row: int in range(capacity):
		if _typed_owner_slot[base + row] != NULL_SLOT:
			continue
		_heap_index[base + free_rows] = row
		free_rows += 1
	_kind_free_count[kind] = free_rows
	assert(capacity - free_rows == _kind_live_count[kind],
		"every owned row of a kind must be one of that kind's live rows")


func _refuse_create(kind: int) -> StringName:
	"""The ARCH-ID-004 code blocking a create, or REFUSAL_NONE when it may proceed."""
	if kind < 0 or kind >= KIND_COUNT:
		return REFUSAL_UNKNOWN_KIND
	if _next_persistent_id > MAX_INT32:
		return REFUSAL_PERSISTENT_ID
	if kind == KIND_RESIDENT and _kind_live_count[kind] >= RESIDENT_LIVING_CAP:
		return REFUSAL_LIVING_CAP
	if _kind_free_count[kind] <= 0:
		return KIND_CAPACITY_REFUSAL[kind]
	if _free_count <= 0:
		return REFUSAL_DIRECTORY_FULL
	return REFUSAL_NONE


func _pop_min(heap: PackedInt32Array, base: int, count: int) -> int:
	"""Remove the smallest of the `count` entries in the arena window at `base`.

	Packed arrays reach this by reference, so both arenas share one implementation.
	"""
	var smallest: int = heap[base]
	var last: int = count - 1
	if last == 0:
		return smallest
	heap[base] = heap[base + last]
	var index: int = 0
	while index * 2 + 1 < last:
		var child: int = index * 2 + 1
		if child + 1 < last and heap[base + child + 1] < heap[base + child]:
			child += 1
		if heap[base + index] <= heap[base + child]:
			break
		var carried: int = heap[base + index]
		heap[base + index] = heap[base + child]
		heap[base + child] = carried
		index = child
	return smallest


func _push_free(heap: PackedInt32Array, base: int, count: int, value: int) -> void:
	"""Insert `value` into the arena window at `base` already holding `count` entries."""
	var index: int = count
	while index > 0:
		var parent: int = (index - 1) / 2
		if heap[base + parent] <= value:
			break
		heap[base + index] = heap[base + parent]
		index = parent
	heap[base + index] = value
