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

## Scratch buffers for the ARCH-SAVE-002 §3 column API. Sized on first use rather than in
## `before_each()`, so the tests that never touch them pay nothing.
var _c_active: PackedByteArray = PackedByteArray()
var _c_generation: PackedInt32Array = PackedInt32Array()
var _c_retired: PackedByteArray = PackedByteArray()
var _c_persistent_id: PackedInt32Array = PackedInt32Array()
var _c_kind: PackedInt32Array = PackedInt32Array()
var _c_typed_row: PackedInt32Array = PackedInt32Array()


func before_each() -> void:
	"""Build a fresh directory with every column allocated to capacity."""
	_directory = EntityDirectoryScript.new()


func after_each() -> void:
	"""Drop the directory built for the test."""
	_directory = null


func _force_generation(slot: int, value: int) -> void:
	"""Set one slot's stored generation, so exhaustion is reachable without 2^31 creates."""
	_force_generation_on(_directory, slot, value)


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


# --- bulk column capture and restore (ARCH-SAVE-002 §3, decision 0105) ---------------------------

func _force_generation_on(store: EntityDirectoryScript, slot: int, value: int) -> void:
	"""Set one slot's stored generation in any directory, not only the shared fixture."""
	var generations: PackedInt32Array = store.get("_generation")
	generations[slot] = value
	store.set("_generation", generations)


func _size_scratch_columns() -> void:
	"""Give the six scratch columns the capacity length `copy_columns_into()` demands."""
	_c_active.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)
	_c_retired.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)
	_c_generation.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)
	_c_persistent_id.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)
	_c_kind.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)
	_c_typed_row.resize(EntityDirectoryScript.DIRECTORY_CAPACITY)


func _capture_from(store: EntityDirectoryScript) -> bool:
	"""Fill the scratch columns from `store`, returning what `copy_columns_into()` returned."""
	_size_scratch_columns()
	return store.copy_columns_into(_c_active, _c_generation, _c_retired, _c_persistent_id,
		_c_kind, _c_typed_row)


func _restore_into(store: EntityDirectoryScript) -> bool:
	"""Apply the scratch columns to `store`, returning what `restore_columns()` returned."""
	return store.restore_columns(_c_active, _c_generation, _c_retired, _c_persistent_id,
		_c_kind, _c_typed_row)


func _set_scratch_live(slot: int, generation: int, persistent_id: int, kind: int,
		row: int) -> void:
	"""Mark one scratch slot live with a full identity, as `_publish_row()` leaves it."""
	_c_active[slot] = 1
	_c_generation[slot] = generation
	_c_persistent_id[slot] = persistent_id
	_c_kind[slot] = kind
	_c_typed_row[slot] = row


func _build_world(store: EntityDirectoryScript) -> void:
	"""Populate a directory with live, reused, free, retired and never-used slots.

	Slots 0,1,2,4,7 are live residents, slot 3 is a live job on a reused slot at generation 2,
	slot 5 is free at generation 1, slot 6 is retired at the spent generation, and everything
	from slot 8 up has never been used.
	"""
	var refs: Array[Vector2i] = []
	for index: int in range(8):
		refs.append(store.create(EntityDirectoryScript.KIND_RESIDENT))
	assert_true(store.destroy(refs[3]), "slot 3 is released so a later kind can reuse it")
	assert_true(store.destroy(refs[5]), "slot 5 stays free with a spent generation of 1")
	var job: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	assert_equal(job, Vector2i(3, 2), "the job takes the lowest free slot at the next generation")
	_force_generation_on(store, 6, EntityDirectoryScript.MAX_INT32)
	assert_true(store.destroy(Vector2i(6, EntityDirectoryScript.MAX_INT32)),
		"slot 6 spends its last generation and retires")


func _assert_restore_refused(store: EntityDirectoryScript, code: StringName,
		message: String) -> void:
	"""A refused restore names its code and leaves the directory byte-identical (decision 0059)."""
	var before: PackedByteArray = store.state_bytes()
	assert_false(_restore_into(store), message)
	assert_equal(store.last_column_refusal(), code, "%s names its refusal" % message)
	assert_true(store.state_bytes() == before, "%s changed nothing" % message)


func test_copy_columns_into_reads_live_free_retired_and_never_used_slots() -> void:
	"""The capture step answers for all four slot states, which no other reader does."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "the six columns are published")
	assert_equal(_c_active[0], 1, "slot 0 is live")
	assert_equal(_c_kind[0], EntityDirectoryScript.KIND_RESIDENT, "and holds its kind")
	assert_equal(_c_generation[3], 2, "the reused slot carries its second generation")
	assert_equal(_c_kind[3], EntityDirectoryScript.KIND_JOB, "under its new kind")
	assert_equal(_c_active[5], 0, "slot 5 is free")
	assert_equal(_c_persistent_id[5], 0, "a free slot's persistent id is absent, not stale")
	assert_equal(_c_kind[5], EntityDirectoryScript.KIND_ANY, "so is its kind")
	assert_equal(_c_typed_row[5], EntityDirectoryScript.NULL_SLOT, "and its typed row")
	assert_equal(_c_retired[6], 1, "slot 6 is retired")
	assert_equal(_c_generation[6], EntityDirectoryScript.MAX_INT32, "at the spent generation")
	assert_equal(_c_generation[9], 0, "a never-used slot holds generation 0")
	assert_equal(_c_retired[9], 0, "and is not retired")


func test_copy_columns_into_is_the_only_reader_of_an_inactive_slots_generation() -> void:
	"""BLOCKER D1's exact value: the generation of a slot that is free, not live.

	`ref_of_slot()` answers NULL_REF for slot 5 because nothing lives there, so the generation
	the persistence registry requires to survive verbatim is invisible to every other reader.
	Capturing five columns and leaving this one at zero would hand the next `create()` a pair a
	pre-save `EntityRef` still holds.
	"""
	_build_world(_directory)
	assert_equal(_directory.ref_of_slot(5), EntityDirectoryScript.NULL_REF,
		"the live-slot reader sees nothing at slot 5")
	assert_equal(_directory.ref_of_slot(6), EntityDirectoryScript.NULL_REF,
		"nor at the retired slot 6")
	assert_true(_capture_from(_directory), "the columns are published")
	assert_equal(_c_generation[5], 1, "the free slot's generation is captured verbatim")
	assert_equal(_c_generation[6], EntityDirectoryScript.MAX_INT32,
		"and so is the retired slot's")


func test_copy_columns_into_refuses_a_buffer_that_is_not_capacity_sized() -> void:
	"""A wrongly sized buffer is the wrong buffer; resizing it silently would hide that."""
	_build_world(_directory)
	_size_scratch_columns()
	_c_active.fill(0)
	_c_kind.resize(EntityDirectoryScript.KIND_COUNT)
	assert_false(_directory.copy_columns_into(_c_active, _c_generation, _c_retired,
		_c_persistent_id, _c_kind, _c_typed_row), "a short kind column is refused")
	assert_equal(_directory.last_column_refusal(), EntityDirectoryScript.REFUSAL_COLUMN_SHAPE,
		"the refusal names the shape")
	assert_equal(_c_kind.size(), EntityDirectoryScript.KIND_COUNT, "and nothing was written")
	assert_equal(_c_active.count(1), 0, "not even into the correctly sized buffers")


func test_copied_columns_are_snapshots_not_aliases() -> void:
	"""Mutating a captured column must not reach the directory, and later creates must not reach it."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	_c_active[5] = 1
	_c_generation[0] = 99
	assert_false(_directory.is_valid(Vector2i(5, 1)), "the directory did not gain a live slot")
	assert_equal(_directory.ref_of_slot(0), Vector2i(0, 1), "nor a rewritten generation")
	var added: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(added.x, 5, "the directory allocates on")
	assert_equal(_c_kind[5], EntityDirectoryScript.KIND_ANY, "without touching the snapshot")


func test_restore_columns_reproduces_the_source_world_in_another_directory() -> void:
	"""A real round trip: capture one directory, restore a second, and prove they agree."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_equal(loaded.total_live_count(), _directory.total_live_count(), "same live count")
	assert_equal(loaded.free_slot_count(), _directory.free_slot_count(), "same free count")
	for kind: int in range(EntityDirectoryScript.KIND_COUNT):
		assert_equal(loaded.live_count(kind), _directory.live_count(kind), "same live rows")
		assert_equal(loaded.free_row_count(kind), _directory.free_row_count(kind), "same free rows")
	assert_true(loaded.is_valid_of_kind(Vector2i(3, 2), EntityDirectoryScript.KIND_JOB),
		"a pre-save reference still validates against the loaded world")
	assert_true(loaded.is_slot_retired(6), "the retired slot stayed retired")
	var source_columns: PackedByteArray = _c_generation.to_byte_array()
	assert_true(_capture_from(loaded), "the loaded directory publishes its own columns")
	assert_true(_c_generation.to_byte_array() == source_columns, "every generation survived")


func test_restore_columns_pins_allocation_order_across_a_round_trip() -> void:
	"""Determinism: the restored world must allocate the same slots in the same order.

	The property no "the same slots are live" assertion can see. A free window filled descending,
	or one that lost a free slot, still restores an identical-looking world and then diverges on
	the very next `create()` -- and every entity created after the load lands in a different slot
	from the one the saving world would have used.
	"""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	var from_source: PackedInt32Array = _allocation_script(_directory)
	var from_loaded: PackedInt32Array = _allocation_script(loaded)
	assert_equal(from_loaded, from_source, "the loaded world allocates exactly as the saved one")
	assert_equal(from_source[0], 5, "starting at the lowest free slot, not the highest")
	assert_equal(from_source[1], 8,
		"then the first never-used slot, skipping the retired 6 and the live 7")
	var source_row: int = _directory.get_typed_row(
		_directory.create(EntityDirectoryScript.KIND_RESIDENT))
	var loaded_row: int = loaded.get_typed_row(
		loaded.create(EntityDirectoryScript.KIND_RESIDENT))
	assert_equal(loaded_row, source_row, "and the per-kind row windows allocate alike")
	assert_equal(loaded_row, 3, "at the lowest free resident row, which ascending fill is for")


func _allocation_script(store: EntityDirectoryScript) -> PackedInt32Array:
	"""Run one fixed create/destroy script and return the slot of every reference it allocated.

	Interleaved on purpose: a free window that is a valid min-heap and one that merely starts
	ascending diverge only once slots are pushed back into it.
	"""
	var slots: PackedInt32Array = PackedInt32Array()
	var held: Array[Vector2i] = []
	for index: int in range(12):
		var ref: Vector2i = store.create(EntityDirectoryScript.KIND_ROOM)
		slots.append(ref.x)
		held.append(ref)
	for index: int in [7, 2, 9, 0, 4]:
		assert_true(store.destroy(held[index]), "the script releases slot %d" % held[index].x)
	for index: int in range(9):
		slots.append(store.create(EntityDirectoryScript.KIND_ROOM).x)
	return slots


func test_restore_columns_excludes_live_slots_from_the_free_heap() -> void:
	"""A live slot left in the free window would be handed straight back out to a second owner."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_equal(loaded.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY - 7,
		"six live slots and one retired slot are out of the pool")
	var next: Vector2i = loaded.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(next.x, 5, "the next create takes the free slot, not a live one")
	assert_true(loaded.is_valid_of_kind(Vector2i(0, 1), EntityDirectoryScript.KIND_RESIDENT),
		"and the live slot 0 still belongs to its original owner")


func test_restore_columns_keeps_a_retired_slot_out_of_the_pool() -> void:
	"""A retired slot handed back needs a wrapped generation: the collision ARCH-ID-002 forbids."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_true(loaded.is_slot_retired(6), "slot 6 is retired in the loaded world")
	var first: Vector2i = loaded.create(EntityDirectoryScript.KIND_ROOM)
	var second: Vector2i = loaded.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(first.x, 5, "the free slot comes back")
	assert_equal(second.x, 8, "and the retired slot 6 is skipped for the first never-used one")


func test_restore_columns_rebuilds_the_reverse_owner_map() -> void:
	"""ARCH-ID-003's reverse map is rebuilt, not restored, and the rebuild is what validates it."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_equal(loaded.owner_slot_of_typed_row(EntityDirectoryScript.KIND_JOB, 0), 3,
		"the job's typed row points back at slot 3")
	assert_equal(loaded.owner_slot_of_typed_row(EntityDirectoryScript.KIND_RESIDENT, 0), 0,
		"and each resident row at its own slot")
	assert_equal(loaded.owner_slot_of_typed_row(EntityDirectoryScript.KIND_RESIDENT, 5),
		EntityDirectoryScript.NULL_SLOT, "a released resident row has no owner")
	assert_equal(loaded.get_typed_row(Vector2i(3, 2)), 0, "and the forward map agrees")


func test_restore_columns_rebuilds_counters_over_a_directory_that_already_held_a_world() -> void:
	"""Every counter is recomputed from the columns; none may survive from the overwritten world."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	for index: int in range(40):
		assert_true(loaded.create(EntityDirectoryScript.KIND_FURNITURE) \
			!= EntityDirectoryScript.NULL_REF, "the target already holds an unrelated world")
	assert_equal(loaded.live_count(EntityDirectoryScript.KIND_FURNITURE), 40, "of 40 rows")
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_equal(loaded.total_live_count(), 6, "the live count is the restored world's")
	assert_equal(loaded.live_count(EntityDirectoryScript.KIND_FURNITURE), 0, "the furniture is gone")
	assert_equal(loaded.free_row_count(EntityDirectoryScript.KIND_FURNITURE), 81920,
		"and its rows returned to the pool")
	assert_equal(loaded.live_count(EntityDirectoryScript.KIND_RESIDENT), 5, "five residents live")
	assert_equal(loaded.free_row_count(EntityDirectoryScript.KIND_RESIDENT), 507, "on 5 of 512 rows")
	assert_equal(loaded.free_slot_count(), EntityDirectoryScript.DIRECTORY_CAPACITY - 7,
		"and the free slot count counts the restored world's occupancy")


func test_two_restores_of_one_column_set_produce_the_same_image() -> void:
	"""The rebuild is a pure function of the six columns: two targets with different histories agree."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var fresh: EntityDirectoryScript = EntityDirectoryScript.new()
	var used: EntityDirectoryScript = EntityDirectoryScript.new()
	for index: int in range(30):
		var ref: Vector2i = used.create(EntityDirectoryScript.KIND_HIVE)
		if index % 2 == 0:
			assert_true(used.destroy(ref), "churn leaves a permuted heap and a stale tail")
	assert_true(_restore_into(fresh), "restored into a fresh directory")
	assert_true(_restore_into(used), "restored over a churned directory")
	assert_true(fresh.state_bytes() != used.state_bytes(),
		"only the §1-owned persistent id allocator still differs (BLOCKER D2)")
	used.set("_next_persistent_id", fresh.get("_next_persistent_id"))
	assert_true(fresh.state_bytes() == used.state_bytes(),
		"both rebuilds produce the same canonical image")


func test_restore_columns_does_not_restore_the_persistent_id_allocator() -> void:
	"""BLOCKER D2, pinned: `_next_persistent_id` belongs to §1 WORLD and must not be written here.

	Writing it in both sections would put one future-affecting value in two places. The cost is
	visible and is meant to be: a restored world reissues persistent IDs from wherever its own
	allocator stands, so the images differ until §1 carries the scalar. This test fails in BOTH
	directions -- if the restore ever starts writing it, the first assertion goes.
	"""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	assert_true(_restore_into(loaded), "restored: %s" % loaded.last_column_refusal())
	assert_equal(loaded.get("_next_persistent_id"), 1, "the loaded allocator is untouched at 1")
	assert_equal(_directory.get("_next_persistent_id"), 10, "while the saved world stands at 10")
	assert_true(loaded.state_bytes() != _directory.state_bytes(),
		"so the two worlds are not yet identical")
	loaded.set("_next_persistent_id", _directory.get("_next_persistent_id"))
	assert_true(loaded.state_bytes() == _directory.state_bytes(),
		"and that one scalar, set by hand, is the whole remaining difference")


func test_state_bytes_ignores_the_stale_heap_tail_and_the_refusal_code() -> void:
	"""The diagnostic image covers the live free-window prefix only, for the reason §3 gives.

	Beyond `_free_count` the window is garbage left by earlier pops, and two worlds identical in
	every observable way can hold different bytes there. Including it would make the refusal
	comparison assert something that is not state.
	"""
	_build_world(_directory)
	var image: PackedByteArray = _directory.state_bytes()
	var heap: PackedInt32Array = _directory.get("_free_heap")
	var free_count: int = _directory.get("_free_count")
	heap[free_count + 3] = 999999
	_directory.set("_free_heap", heap)
	assert_true(_directory.state_bytes() == image, "the stale tail is outside the image")
	assert_equal(_directory.create(EntityDirectoryScript.KIND_COUNT),
		EntityDirectoryScript.NULL_REF, "a refused create sets a category-3 code")
	assert_true(_directory.state_bytes() == image, "which is outside the image too")
	heap[0] = heap[0] + 1
	_directory.set("_free_heap", heap)
	assert_true(_directory.state_bytes() != image, "but the live prefix is inside it")


func test_restore_columns_refuses_a_duplicate_typed_row_and_changes_nothing() -> void:
	"""Two live slots claiming one typed row is caught by the rebuild itself, not by a second pass."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	_c_typed_row[4] = _c_typed_row[2]
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_DUPLICATE_TYPED_ROW,
		"two residents on one typed row")
	assert_true(loaded.is_valid_of_kind(Vector2i(4, 1), EntityDirectoryScript.KIND_RESIDENT),
		"the target's own reverse map still validates every live row")
	assert_equal(loaded.owner_slot_of_typed_row(EntityDirectoryScript.KIND_RESIDENT, 4), 4,
		"including the entry the abandoned rebuild had already written")


func test_restore_columns_refuses_a_mis_sized_column_set() -> void:
	"""A column set that is not capacity-long is refused before anything indexes into it."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	_c_generation.resize(EntityDirectoryScript.DIRECTORY_CAPACITY - 1)
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_SHAPE,
		"a short generation column")


func test_restore_columns_refuses_an_occupancy_byte_outside_zero_and_one() -> void:
	"""`_active` and `_retired` are one byte per slot, and only two of its 256 values are legal."""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	_c_active[11] = 2
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_ACTIVE_BYTE,
		"an occupancy byte of 2")
	_c_active[11] = 0
	_c_retired[11] = 7
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_RETIRED_BYTE,
		"a retirement byte of 7")


func test_restore_columns_refuses_a_negative_generation_from_the_int32_sign_trap() -> void:
	"""GDScript ints are 64-bit: 0x80000000 is positive, and -2147483648 is its int32 reading.

	Storing 2147483648 in a PackedInt32Array wraps it to -2147483648, which is what a save
	carrying the bytes `00 00 00 80` decodes to. A generation only ever rises from 0, so it is
	refused rather than accepted as a plausible 2147483648 no int32 column could ever hold.
	"""
	_build_world(_directory)
	assert_true(_capture_from(_directory), "captured")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	_c_generation[12] = 0x80000000
	assert_equal(_c_generation[12], -2147483648, "the trap itself: the high bit wraps to negative")
	assert_true(0x80000000 > 0, "while the same literal is positive as a GDScript int")
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_GENERATION_NEGATIVE,
		"a generation of -2147483648")


func test_restore_columns_refuses_each_broken_live_identity() -> void:
	"""A live slot must carry the four values `_publish_row()` leaves, and each is checked."""
	_build_world(_directory)
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	assert_true(_capture_from(_directory), "captured")
	_c_generation[0] = 0
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_LIVE_GENERATION,
		"a live slot at generation 0")
	assert_true(_capture_from(_directory), "recaptured")
	_c_persistent_id[0] = 0
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_LIVE_PERSISTENT_ID,
		"a live slot with no persistent id")
	assert_true(_capture_from(_directory), "recaptured")
	_c_kind[0] = EntityDirectoryScript.KIND_COUNT
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_LIVE_KIND,
		"a live slot with a kind past the table")
	assert_true(_capture_from(_directory), "recaptured")
	_c_typed_row[0] = 512
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_LIVE_ROW,
		"a live resident on row 512 of a 512-row store")


func test_restore_columns_refuses_a_free_slot_carrying_a_stale_identity() -> void:
	"""`destroy()` clears a freed slot's identity, so a restored free slot must carry none."""
	_build_world(_directory)
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	assert_true(_capture_from(_directory), "captured")
	_c_typed_row[5] = 0
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_FREE_IDENTITY,
		"a free slot whose null typed row was restored as row 0")
	assert_true(_capture_from(_directory), "recaptured")
	_c_persistent_id[5] = 3
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_FREE_IDENTITY,
		"a free slot holding a stale persistent id")


func test_restore_columns_refuses_both_halves_of_a_retirement_disagreement() -> void:
	"""Retirement is cross-checked per slot AND per column; neither check subsumes the other.

	The balanced swap is the case that proves it: one slot retired below the spent generation
	while another sits at the spent generation un-retired. The counts cancel, so only the
	per-slot half sees it -- and a loader that trusted the count alone would hand the first slot
	back to the allocator and never reuse the second.
	"""
	_build_world(_directory)
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	assert_true(_capture_from(_directory), "captured")
	_c_retired[6] = 0
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_RETIREMENT,
		"a spent slot restored as reusable")
	assert_true(_capture_from(_directory), "recaptured")
	_c_retired[6] = 0
	_c_generation[6] = 10
	_c_retired[9] = 1
	_c_generation[9] = EntityDirectoryScript.MAX_INT32
	assert_true(_restore_into(loaded), "the swap is internally consistent and restores")
	assert_true(loaded.is_slot_retired(9), "with the retirement moved to slot 9")
	assert_true(_capture_from(_directory), "recaptured")
	_c_retired[6] = 0
	_c_generation[6] = EntityDirectoryScript.MAX_INT32
	_c_retired[9] = 1
	_c_generation[9] = 10
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_RETIREMENT,
		"a balanced swap whose counts cancel")


func test_restore_columns_refuses_a_two_hundred_fifty_seventh_living_resident() -> void:
	"""GDD §4.1 caps living residents at 256; the resident store's 512 rows do not.

	`create()` refuses the 257th and a load must too, or a saved file would be the way past a cap
	the allocator enforces everywhere else.
	"""
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	_build_world(loaded)
	assert_true(_capture_from(EntityDirectoryScript.new()), "capture an empty world")
	for index: int in range(EntityDirectoryScript.RESIDENT_LIVING_CAP):
		_set_scratch_live(index, 1, index + 1, EntityDirectoryScript.KIND_RESIDENT, index)
	assert_true(_restore_into(loaded), "256 living residents restore: %s"
		% loaded.last_column_refusal())
	assert_equal(loaded.live_count(EntityDirectoryScript.KIND_RESIDENT), 256, "all of them")
	_set_scratch_live(EntityDirectoryScript.RESIDENT_LIVING_CAP, 1,
		EntityDirectoryScript.RESIDENT_LIVING_CAP + 1, EntityDirectoryScript.KIND_RESIDENT,
		EntityDirectoryScript.RESIDENT_LIVING_CAP)
	_assert_restore_refused(loaded, EntityDirectoryScript.REFUSAL_COLUMN_LIVING_CAP,
		"a 257th living resident")
