extends "res://test/framework/test_case.gd"
## Coverage for the global entity directory: reference validity, the two-level
## slot allocator, explicit refusals, and the packed-storage guarantees.
##
## The prototype's `test_destroyed_ids_are_never_reused` is deliberately absent.
## It asserted the opposite of ARCH-ID-002, which reuses slots and relies on the
## generation counter to detect a stale reference; it is replaced here by
## `test_destroyed_slot_is_reused_lowest_first` and by
## `test_persistent_ids_are_never_reused`, which keeps the half of the prototype's
## intent that the specification does retain.
##
## Component storage, queries and their tests are not ported: components belong
## to the per-kind typed stores, not to the directory, and the prototype keeps
## running against its own suite until those stores are replaced (ARCH-MIG-006).

const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")
## Preloaded for the drift guard below only: these modules duplicate spec numbers this one
## also carries, and nothing but that test keeps the copies agreeing.
const InventoryScript := preload("res://scripts/core/inventory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const PERF_ENTITY_COUNT: int = 1000
const PERF_BUDGET_MSEC: float = 16.0
## Repeats of the timed pass. The budget is checked against the fastest sample, so a machine
## that deschedules one pass does not fail a build the code did not break.
const PERF_SAMPLES: int = 3
const CHURN_CYCLES: int = 2000

var _directory: EntityDirectoryScript = null


func before_each() -> void:
	"""Build a fresh directory with every column allocated to capacity."""
	_directory = EntityDirectoryScript.new()


func after_each() -> void:
	"""Drop the directory built for the test."""
	_directory = null


func _force_generation(slot: int, value: int) -> void:
	"""Set one slot's stored generation, so exhaustion is reachable without 2^31 creates."""
	var generations: PackedInt32Array = _directory.get("_generation")
	generations[slot] = value
	_directory.set("_generation", generations)


func test_create_returns_unique_live_references() -> void:
	"""Successive creates hand out distinct, immediately valid references."""
	var first: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var second: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(first != second, "references are unique")
	assert_true(first != EntityDirectoryScript.NULL_REF, "reference is not the null sentinel")
	assert_true(_directory.is_valid(first), "first reference is valid")
	assert_true(_directory.is_valid(second), "second reference is valid")
	assert_equal(_directory.total_live_count(), 2, "two rows are live")


func test_reference_validates_from_create_until_destroy() -> void:
	"""A reference is valid from create until destroy, and never after."""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_true(_directory.is_valid(ref), "reference is valid after create")
	assert_true(_directory.destroy(ref), "destroy reports success")
	assert_false(_directory.is_valid(ref), "reference is invalid after destroy")
	assert_equal(_directory.total_live_count(), 0, "no rows remain live")


func test_destroy_rejects_unknown_reference() -> void:
	"""Destroying a reference that was never created is a no-op returning false."""
	assert_false(_directory.destroy(Vector2i(42, 1)), "unknown reference cannot be destroyed")
	assert_false(_directory.destroy(EntityDirectoryScript.NULL_REF), "null reference cannot be destroyed")


func test_null_reference_never_validates() -> void:
	"""The GDD null reference (-1,0) and other out-of-contract pairs never validate."""
	assert_false(_directory.is_valid(EntityDirectoryScript.NULL_REF), "null (-1,0) is invalid")
	assert_false(_directory.is_valid(Vector2i(0, 0)), "generation 0 is never issued")
	assert_false(_directory.is_valid(Vector2i(-5, 3)), "negative slot is invalid")
	assert_false(_directory.is_valid(Vector2i(EntityDirectoryScript.DIRECTORY_CAPACITY, 1)), "slot past capacity is invalid")
	_directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_false(_directory.is_valid(EntityDirectoryScript.NULL_REF), "null stays invalid once slot 0 is live")


func test_stale_reference_is_rejected_after_destroy() -> void:
	"""Every accessor rejects a reference to a destroyed row rather than reading it."""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	_directory.destroy(ref)
	assert_false(_directory.is_valid(ref), "stale reference fails validation")
	assert_false(_directory.is_valid_of_kind(ref, EntityDirectoryScript.KIND_JOB), "stale reference fails kind validation")
	assert_equal(_directory.get_kind(ref), EntityDirectoryScript.KIND_ANY, "kind lookup refuses")
	assert_equal(_directory.get_typed_row(ref), EntityDirectoryScript.NULL_SLOT, "typed row lookup refuses")
	assert_equal(_directory.get_persistent_id(ref), 0, "persistent id lookup refuses")


func test_destroyed_slot_is_reused_lowest_first() -> void:
	"""A freed slot returns to the pool and the lowest free slot is allocated first."""
	var first: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var second: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var third: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(first.x, 0, "first create takes slot 0")
	assert_equal(third.x, 2, "third create takes slot 2")
	_directory.destroy(second)
	var reused: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(reused.x, 1, "the freed middle slot is reused, not slot 3")
	_directory.destroy(first)
	_directory.destroy(third)
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT).x, 0, "lowest free slot comes back first")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT).x, 2, "then the next lowest")


func test_reuse_increments_generation_invalidating_the_old_reference() -> void:
	"""The reused slot carries a new generation, so the old reference cannot alias it."""
	var original: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(original.y, 1, "initial generation is 1")
	_directory.destroy(original)
	var reused: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(reused.x, original.x, "the same slot is handed back")
	assert_equal(reused.y, original.y + 1, "generation incremented on reuse")
	assert_false(_directory.is_valid(original), "the stale reference does not alias the new row")
	assert_true(_directory.is_valid(reused), "the new reference is valid")
	assert_false(_directory.destroy(original), "the stale reference cannot destroy the new row")
	assert_true(_directory.is_valid(reused), "the new row survived the stale destroy")


func test_persistent_ids_are_never_reused() -> void:
	"""Slots recycle but persistent IDs are monotonic and never handed out twice."""
	var first: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var first_id: int = _directory.get_persistent_id(first)
	_directory.destroy(first)
	var second: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(second.x, first.x, "the slot was reused")
	assert_true(_directory.get_persistent_id(second) > first_id, "the persistent id was not reused")


func test_living_cap_refuses_the_two_hundred_fifty_seventh_resident() -> void:
	"""Living residents stop at 256 with an explicit code, leaving the 256 alive intact."""
	var last: Vector2i = EntityDirectoryScript.NULL_REF
	for index: int in range(EntityDirectoryScript.RESIDENT_LIVING_CAP):
		last = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(_directory.live_count(EntityDirectoryScript.KIND_RESIDENT), 256, "256 residents are alive")
	var refused: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(refused, EntityDirectoryScript.NULL_REF, "the 257th resident is refused")
	assert_equal(_directory.last_refusal(), EntityDirectoryScript.REFUSAL_LIVING_CAP, "refusal names the living cap")
	assert_equal(_directory.live_count(EntityDirectoryScript.KIND_RESIDENT), 256, "no resident was silently dropped")
	assert_true(_directory.is_valid(last), "the last admitted resident was not overwritten")
	assert_true(_directory.free_row_count(EntityDirectoryScript.KIND_RESIDENT) > 0, "storage slots remain above the living cap")


func test_living_cap_frees_room_after_a_destroy() -> void:
	"""Once a resident is destroyed the cap admits exactly one more."""
	var refs: Array[Vector2i] = []
	for index: int in range(EntityDirectoryScript.RESIDENT_LIVING_CAP):
		refs.append(_directory.create(EntityDirectoryScript.KIND_RESIDENT))
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT), EntityDirectoryScript.NULL_REF, "cap is reached")
	_directory.destroy(refs[10])
	var admitted: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_directory.is_valid(admitted), "one more resident is admitted")
	assert_equal(_directory.last_refusal(), EntityDirectoryScript.REFUSAL_NONE, "the successful create clears the refusal")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT), EntityDirectoryScript.NULL_REF, "the cap binds again")


func test_living_cap_does_not_block_other_kinds() -> void:
	"""The 256 living cap is a resident rule, not a directory-wide one."""
	for index: int in range(EntityDirectoryScript.RESIDENT_LIVING_CAP):
		_directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var room: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_true(_directory.is_valid(room), "another kind still allocates at the resident cap")
	assert_equal(_directory.total_live_count(), 257, "the room is counted alongside the residents")


func test_kind_capacity_refusal_is_explicit() -> void:
	"""A kind with no free rows refuses with its CAPACITY_<STORE> code."""
	var feast: Vector2i = _directory.create(EntityDirectoryScript.KIND_FEAST)
	assert_true(_directory.is_valid(feast), "the single feast row allocates")
	var refused: Vector2i = _directory.create(EntityDirectoryScript.KIND_FEAST)
	assert_equal(refused, EntityDirectoryScript.NULL_REF, "a second feast is refused")
	assert_equal(_directory.last_refusal(), &"CAPACITY_FEAST", "refusal names the exhausted store")
	assert_true(_directory.is_valid(feast), "the live feast was not overwritten")


func test_directory_capacity_refusal_is_explicit() -> void:
	"""An exhausted global directory refuses rather than dropping or overwriting a row."""
	var live: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	_directory.set("_free_count", 0)
	var refused: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(refused, EntityDirectoryScript.NULL_REF, "creation is refused")
	assert_equal(_directory.last_refusal(), EntityDirectoryScript.REFUSAL_DIRECTORY_FULL, "refusal names the directory")
	assert_true(_directory.is_valid(live), "the existing row is untouched")
	assert_equal(_directory.free_row_count(EntityDirectoryScript.KIND_ROOM), 16383, "no typed row was consumed by the refusal")


func test_unknown_kind_is_refused() -> void:
	"""An out-of-range kind is refused explicitly instead of indexing a column."""
	assert_equal(_directory.create(-1), EntityDirectoryScript.NULL_REF, "negative kind is refused")
	assert_equal(_directory.last_refusal(), EntityDirectoryScript.REFUSAL_UNKNOWN_KIND, "refusal names the unknown kind")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_COUNT), EntityDirectoryScript.NULL_REF, "kind past the table is refused")
	assert_equal(_directory.total_live_count(), 0, "nothing was allocated")


func test_generation_exhaustion_retires_the_slot() -> void:
	"""Generation 2147483647 is used once, then the slot retires instead of wrapping."""
	_force_generation(0, EntityDirectoryScript.MAX_INT32 - 1)
	var final_use: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(final_use, Vector2i(0, EntityDirectoryScript.MAX_INT32), "the last generation is used once")
	assert_true(_directory.is_valid(final_use), "the last generation is a live reference")
	assert_true(_directory.destroy(final_use), "the last generation is destroyed normally")
	assert_true(_directory.is_slot_retired(0), "the exhausted slot is retired")
	assert_false(_directory.is_valid(final_use), "the exhausted reference is stale")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT).x, 1, "the retired slot is never reallocated")
	assert_equal(_directory.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY - 2, "the retired slot left the pool")


func test_persistent_id_exhaustion_refuses_creation() -> void:
	"""Persistent IDs stop at 2147483647 and refuse rather than wrapping or resetting."""
	_directory.set("_next_persistent_id", EntityDirectoryScript.MAX_INT32)
	var last: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(_directory.get_persistent_id(last), EntityDirectoryScript.MAX_INT32, "the final id is issued")
	var refused: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(refused, EntityDirectoryScript.NULL_REF, "creation is refused after exhaustion")
	assert_equal(_directory.last_refusal(), EntityDirectoryScript.REFUSAL_PERSISTENT_ID, "refusal names id exhaustion")
	assert_true(_directory.is_valid(last), "the existing world is intact")


func test_repeated_create_and_destroy_leaks_no_slots() -> void:
	"""Thousands of allocate/free cycles return every slot and typed row to the pool."""
	var last: Vector2i = EntityDirectoryScript.NULL_REF
	for cycle: int in range(CHURN_CYCLES):
		last = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
		_directory.destroy(last)
	assert_equal(last, Vector2i(0, CHURN_CYCLES), "slot 0 was reused every cycle with a fresh generation")
	assert_equal(_directory.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY, "every directory slot is free")
	assert_equal(_directory.free_row_count(EntityDirectoryScript.KIND_RESIDENT), 512, "every resident row is free")
	assert_equal(_directory.total_live_count(), 0, "nothing is live")
	assert_equal(_directory.live_count(EntityDirectoryScript.KIND_RESIDENT), 0, "no resident is live")


func test_interleaved_free_returns_slots_in_ascending_order() -> void:
	"""A scattered set of freed slots is handed back lowest-first, not in free order."""
	var refs: Array[Vector2i] = []
	for index: int in range(10):
		refs.append(_directory.create(EntityDirectoryScript.KIND_RESIDENT))
	for index: int in [9, 3, 7, 1, 5]:
		_directory.destroy(refs[index])
	var handed_back: PackedInt32Array = PackedInt32Array()
	for index: int in range(5):
		handed_back.append(_directory.create(EntityDirectoryScript.KIND_RESIDENT).x)
	assert_equal(handed_back, PackedInt32Array([1, 3, 5, 7, 9]), "freed slots come back in ascending order")
	assert_equal(_directory.live_count(EntityDirectoryScript.KIND_RESIDENT), 10, "ten residents are live again")


func test_reverse_owner_mismatch_invalidates_the_reference() -> void:
	"""ARCH-ID-003's reverse-owner clause: `_typed_owner_slot` is the sole source that
	`is_valid_of_kind` cross-checks a live-looking row against. Corrupting that entry for an
	otherwise perfectly live row (right slot, right generation, right kind, right typed row
	bounds) must still refuse, or the reverse-owner column is dead weight nothing verifies."""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_directory.is_valid_of_kind(ref, EntityDirectoryScript.KIND_RESIDENT), "sanity: the row is live before corruption")
	var kind: int = _directory.get_kind(ref)
	var row: int = _directory.get_typed_row(ref)
	var kind_base: PackedInt32Array = _directory.get("_kind_base")
	var owner_index: int = kind_base[kind] + row
	var owner_slots: PackedInt32Array = _directory.get("_typed_owner_slot")
	owner_slots[owner_index] = EntityDirectoryScript.NULL_SLOT
	_directory.set("_typed_owner_slot", owner_slots)
	assert_false(_directory.is_valid_of_kind(ref, EntityDirectoryScript.KIND_RESIDENT), "reverse-owner mismatch refuses is_valid_of_kind")
	assert_false(_directory.is_valid(ref), "reverse-owner mismatch also refuses is_valid in ANY mode")


func test_reference_is_rejected_for_the_wrong_kind() -> void:
	"""Kind-checked validation refuses a live reference belonging to another store."""
	var resident: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_directory.is_valid_of_kind(resident, EntityDirectoryScript.KIND_RESIDENT), "the right kind validates")
	assert_false(_directory.is_valid_of_kind(resident, EntityDirectoryScript.KIND_JOB), "the wrong kind is refused")
	assert_true(_directory.is_valid_of_kind(resident, EntityDirectoryScript.KIND_ANY), "ANY mode accepts any live kind")


func test_typed_rows_are_independent_per_kind() -> void:
	"""Each kind has its own free-row heap, so row 0 exists once per kind."""
	var resident: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_equal(_directory.get_typed_row(resident), 0, "the resident takes row 0 of its store")
	assert_equal(_directory.get_typed_row(job), 0, "the job also takes row 0 of its store")
	assert_true(resident.x != job.x, "they still occupy different directory slots")
	assert_true(_directory.is_valid(resident) and _directory.is_valid(job), "neither reverse-owner entry collides")
	_directory.destroy(resident)
	assert_true(_directory.is_valid(job), "freeing one kind's row leaves the other valid")


func test_kind_capacities_sum_to_the_directory_length() -> void:
	"""The per-kind table reproduces the architecture's directory length G=352418."""
	var total: int = 0
	for kind: int in range(EntityDirectoryScript.KIND_COUNT):
		total += _directory.capacity_of_kind(kind)
	assert_equal(total, EntityDirectoryScript.DIRECTORY_CAPACITY, "kind capacities sum to G")
	assert_equal(EntityDirectoryScript.DIRECTORY_CAPACITY, 352418, "G matches the architecture table")
	assert_equal(_directory.capacity_of_kind(EntityDirectoryScript.KIND_RESIDENT), 512, "resident storage is 512 slots")


func test_spec_capacities_do_not_drift_from_the_inventory_copies() -> void:
	"""DRIFT GUARD. ARCH-MEM-002's 101376 containers and GDD §4.2's 16384 lots are written
	down twice -- once in this directory's per-kind capacity table and once as
	`inventory.gd`'s own CONTAINER_CAPACITY/LOT_CAPACITY -- and int32's bound is written down
	twice again. The two stores must size to the same numbers or a lot can exist in one and
	not the other. Nothing in either module enforces that, so this test does: if a future
	edit changes one copy, this fails loudly instead of the mismatch surfacing as a capacity
	refusal no caller expected. Ownership belongs in one module, which is a cross-module
	refactor this suite deliberately does not perform.
	"""
	assert_equal(_directory.capacity_of_kind(EntityDirectoryScript.KIND_INVENTORY_CONTAINER), InventoryScript.CONTAINER_CAPACITY, "container capacity agrees with inventory.gd")
	assert_equal(_directory.capacity_of_kind(EntityDirectoryScript.KIND_INVENTORY_LOT), InventoryScript.LOT_CAPACITY, "lot capacity agrees with inventory.gd")
	assert_equal(EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_INVENTORY_CONTAINER], 101376, "ARCH-MEM-002 container count")
	assert_equal(EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_INVENTORY_LOT], 16384, "GDD §4.2 live lot count")
	assert_equal(EntityDirectoryScript.MAX_INT32, InventoryScript.MAX_INT32, "int32 bound agrees with inventory.gd")
	assert_equal(EntityDirectoryScript.MAX_INT32, IntMathScript.INT32_MAX, "int32 bound agrees with int_math.gd")


func test_kind_ids_follow_ascending_ascii_keys() -> void:
	"""ARCH-ID-001 fixes kind IDs as the index of each key in ascending ASCII order."""
	var keys: Array[StringName] = EntityDirectoryScript.KIND_KEYS
	assert_equal(keys.size(), EntityDirectoryScript.KIND_COUNT, "every kind has a key")
	for index: int in range(1, keys.size()):
		assert_true(String(keys[index - 1]) < String(keys[index]), "keys ascend at index %d" % index)
	assert_equal(keys[EntityDirectoryScript.KIND_RESIDENT], &"resident", "resident sits at its sorted index")
	assert_equal(keys[EntityDirectoryScript.KIND_WORLD], &"world", "world sits last")


func test_no_per_row_array_is_allocated() -> void:
	"""ARCH-MEM-001: every column is a packed array, never a GDScript Array per row."""
	var packed_columns: int = 0
	for property: Dictionary in _directory.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var type: int = int(property["type"])
		var name: String = String(property["name"])
		assert_true(type != TYPE_ARRAY, "%s is not a GDScript Array" % name)
		assert_true(type != TYPE_DICTIONARY, "%s is not a Dictionary" % name)
		assert_true(type != TYPE_OBJECT, "%s is not a per-row object" % name)
		if type == TYPE_PACKED_INT32_ARRAY or type == TYPE_PACKED_BYTE_ARRAY:
			packed_columns += 1
	assert_true(packed_columns >= 9, "the identity and index columns are packed arrays")


func test_columns_are_allocated_once_and_never_resized() -> void:
	"""ARCH-MEM-005: churn must not resize a column away from its capacity length."""
	for cycle: int in range(300):
		var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_FURNITURE)
		if cycle % 3 == 0:
			_directory.destroy(ref)
	for property: Dictionary in _directory.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var type: int = int(property["type"])
		if type != TYPE_PACKED_INT32_ARRAY and type != TYPE_PACKED_BYTE_ARRAY:
			continue
		var name: String = String(property["name"])
		var length: int = int(_directory.get(name).size())
		var expected: int = EntityDirectoryScript.KIND_COUNT if name.begins_with("_kind_") else EntityDirectoryScript.DIRECTORY_CAPACITY
		assert_equal(length, expected, "%s kept its allocated length" % name)


func test_ref_of_slot_rebuilds_a_live_reference_and_refuses_a_dead_one() -> void:
	"""`ref_of_slot()` is the reverse of `is_valid()`: slot in, the GDD §4.1 pair out.

	R-INIT-ID-001 requires a "complete uniqueness and reference audit" over initialization, and an
	audit has slots rather than references. NULL_REF for an inactive slot is §4.1's own null
	reference, not a failure sentinel -- an empty slot names no entity.
	"""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(_directory.ref_of_slot(ref.x), ref, "the live slot rebuilds its own reference")
	assert_true(_directory.is_valid(_directory.ref_of_slot(ref.x)), "and it validates")
	assert_equal(_directory.get_persistent_id(_directory.ref_of_slot(ref.x)),
		_directory.get_persistent_id(ref), "carrying the same persistent id")
	assert_true(_directory.destroy(ref), "the row is released")
	assert_equal(_directory.ref_of_slot(ref.x), EntityDirectoryScript.NULL_REF,
		"a freed slot names no entity")
	assert_equal(_directory.ref_of_slot(-1), EntityDirectoryScript.NULL_REF, "nor does slot -1")
	assert_equal(_directory.ref_of_slot(EntityDirectoryScript.DIRECTORY_CAPACITY),
		EntityDirectoryScript.NULL_REF, "nor one past the last slot")


func test_ref_of_slot_tracks_the_generation_across_reuse() -> void:
	"""A reused slot must rebuild the NEW generation, or an audit would read the dead row."""
	var first: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_directory.destroy(first), "the first row is released")
	var second: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(second.x, first.x, "the slot is handed back")
	assert_equal(_directory.ref_of_slot(second.x), second, "and rebuilds the live generation")
	assert_false(_directory.ref_of_slot(second.x) == first, "never the destroyed one")


func test_clear_resets_the_directory() -> void:
	"""clear() drops every row, refills both heaps, and restarts the persistent id counter."""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	_directory.create(EntityDirectoryScript.KIND_FEAST)
	_directory.clear()
	assert_equal(_directory.total_live_count(), 0, "no rows remain live")
	assert_false(_directory.is_valid(ref), "the old reference is not valid")
	assert_equal(_directory.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY, "every slot is free again")
	assert_equal(_directory.free_row_count(EntityDirectoryScript.KIND_FEAST), 1, "the feast row returned to its pool")
	var rebuilt: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(rebuilt.x, 0, "allocation restarts at slot 0")
	assert_equal(_directory.get_persistent_id(rebuilt), 1, "the persistent id counter restarted")


func test_clear_does_not_let_a_pre_clear_reference_alias_a_rebuilt_row() -> void:
	"""The reference taken before clear() must stay dead once the same slot is handed out again.

	Asserting invalidity only in the gap between clear() and the next create proves nothing:
	no row is live there, so every reference is invalid for the trivial reason. The aliasing
	shows up one create later, when the slot comes back -- with a reset generation column it
	comes back as the identical `(slot, generation)` pair and the stale reference reads and
	destroys a row that has nothing to do with it.
	"""
	var stale: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(stale.y, 1, "the pre-clear reference is issued at generation 1")
	_directory.clear()
	var rebuilt: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(rebuilt.x, stale.x, "the same slot is handed back after the clear")
	assert_true(rebuilt.y > stale.y, "the rebuilt row carries a generation past the cleared one")
	assert_false(_directory.is_valid(stale), "the pre-clear reference does not validate against it")
	assert_equal(_directory.get_persistent_id(stale), 0, "the pre-clear reference reads no identity")
	assert_equal(_directory.get_typed_row(stale), EntityDirectoryScript.NULL_SLOT, "and no typed row")
	assert_false(_directory.destroy(stale), "the pre-clear reference cannot destroy the rebuilt row")
	assert_true(_directory.is_valid(rebuilt), "the rebuilt row survived the stale destroy")


func test_clear_does_not_resurrect_a_generation_exhausted_slot() -> void:
	"""A retired slot stays retired across clear(); reuse would need a wrapped generation."""
	_force_generation(0, EntityDirectoryScript.MAX_INT32 - 1)
	var final_use: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(final_use.y, EntityDirectoryScript.MAX_INT32, "the last generation is issued")
	_directory.clear()
	assert_true(_directory.is_slot_retired(0), "the exhausted slot is still retired after clear")
	assert_equal(_directory.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY - 1, "it stayed out of the pool")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_RESIDENT).x, 1, "the next create skips it")
	assert_false(_directory.is_valid(final_use), "the exhausted reference never validates again")


func _measure_lifecycle_usec() -> int:
	"""Time one create/validate/destroy pass over PERF_ENTITY_COUNT rows, asserting correctness.

	The functional assertions are the point of the pass; the duration it returns is only the
	sample the budget assertion takes its minimum over.
	"""
	var timer: PerfTimerScript = PerfTimerScript.new()
	var refs: Array[Vector2i] = []
	timer.start()
	for index: int in range(PERF_ENTITY_COUNT):
		refs.append(_directory.create(EntityDirectoryScript.KIND_FURNITURE))
	var validated: int = 0
	for ref: Vector2i in refs:
		if _directory.is_valid_of_kind(ref, EntityDirectoryScript.KIND_FURNITURE):
			validated += 1
	for ref: Vector2i in refs:
		_directory.destroy(ref)
	var elapsed_usec: int = timer.stop()
	assert_equal(validated, PERF_ENTITY_COUNT, "every reference validated")
	assert_equal(_directory.total_live_count(), 0, "every row was released")
	return elapsed_usec


func test_thousand_entity_lifecycle_within_frame_budget() -> void:
	"""Create, validate and destroy 1000 directory rows inside a single 16ms frame.

	Wall clock on a shared machine is noisy in one direction only: a descheduled run can be
	arbitrarily slow, but no run can finish faster than the work takes. The budget is
	therefore asserted against the FASTEST of PERF_SAMPLES identical passes, which discards a
	scheduling hiccup without ever hiding a real regression -- if the operation genuinely
	costs more than the budget, every sample exceeds it and the minimum does too. The margin
	is wide by construction: the pass is 3000 O(log n) heap operations against a budget of a
	whole 16 ms frame, and it measures in the low hundreds of microseconds here, so only a
	regression of more than an order of magnitude trips it.
	"""
	var fastest_usec: int = _measure_lifecycle_usec()
	for sample: int in range(PERF_SAMPLES - 1):
		fastest_usec = mini(fastest_usec, _measure_lifecycle_usec())
	assert_less_than(float(fastest_usec) / 1000.0, PERF_BUDGET_MSEC, "1000-row lifecycle stays under the frame budget")
