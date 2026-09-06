extends RefCounted
## Isolated resident allocator kernel; global directory/child transactions remain separate.

const CAPACITY: int = 512
const LIVING_CAP: int = 256
const MAX_I32: int = 2147483647
var active: PackedByteArray
var generation: PackedInt32Array
var persistent_id: PackedInt32Array
var free_heap: PackedInt32Array
var free_count: int = CAPACITY
var living_count: int = 0
var next_persistent_id: int = 1


func _init() -> void:
	## Allocate all arrays once and initialize the ascending free-slot min-heap.
	active.resize(CAPACITY)
	generation.resize(CAPACITY)
	persistent_id.resize(CAPACITY)
	free_heap.resize(CAPACITY)
	for slot: int in range(CAPACITY):
		free_heap[slot] = slot


func create() -> PackedInt32Array:
	## Refuse capacity/ID exhaustion before mutation; increment generation on reuse.
	if living_count >= LIVING_CAP or free_count == 0 or next_persistent_id > MAX_I32:
		return PackedInt32Array([-1, 0])
	var slot: int = pop_lowest()
	assert(generation[slot] < MAX_I32)
	generation[slot] += 1
	persistent_id[slot] = next_persistent_id
	next_persistent_id += 1
	active[slot] = 1
	living_count += 1
	return PackedInt32Array([slot, generation[slot]])


func valid(slot: int, expected_generation: int) -> bool:
	## Validate both bounds and generation before accessing any resident data.
	return slot >= 0 and slot < CAPACITY and active[slot] == 1 and generation[slot] == expected_generation


func destroy(slot: int, expected_generation: int) -> bool:
	## A maximum-generation row retires permanently; persistent IDs are never recycled.
	if not valid(slot, expected_generation):
		return false
	active[slot] = 0
	persistent_id[slot] = 0
	living_count -= 1
	if generation[slot] < MAX_I32:
		push_free(slot)
	return true


func pop_lowest() -> int:
	## Remove the minimum without shifting or reallocating the backing array.
	var result: int = free_heap[0]
	free_count -= 1
	if free_count == 0:
		return result
	free_heap[0] = free_heap[free_count]
	var index: int = 0
	while index * 2 + 1 < free_count:
		var child: int = index * 2 + 1
		if child + 1 < free_count and free_heap[child + 1] < free_heap[child]:
			child += 1
		if free_heap[index] <= free_heap[child]:
			break
		var temporary: int = free_heap[index]
		free_heap[index] = free_heap[child]
		free_heap[child] = temporary
		index = child
	return result


func push_free(slot: int) -> void:
	## Restore a free row in minimum-index order.
	var index: int = free_count
	free_count += 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if free_heap[parent] <= slot:
			break
		free_heap[index] = free_heap[parent]
		index = parent
	free_heap[index] = slot
