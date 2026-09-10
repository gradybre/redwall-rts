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
