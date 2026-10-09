extends "res://test/framework/test_case.gd"
## Decision 1086: actual mixed-kind allocator observations and callback-free publication.

const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _ids: Directory = null
var _batch: Directory.CreateBatch = null


func before_each() -> void:
	"""Use actual complete identity columns and both allocator arenas, never synthetic references."""
	_ids = Directory.new()
	_batch = Directory.CreateBatch.new(16)


func after_each() -> void:
	"""Discard cold observations; weak owner links cannot retain the Directory."""
	_batch = null
	_ids = null


func _mixed() -> PackedInt32Array:
	"""Include repeated kinds whose typed rows deliberately differ from their global slots."""
	return PackedInt32Array([Directory.KIND_FURNITURE, Directory.KIND_CONSTRUCTION,
		Directory.KIND_ROOM, Directory.KIND_FURNITURE, Directory.KIND_CONSTRUCTION,
		Directory.KIND_JOB, Directory.KIND_ROOM])


func _peek(kinds: PackedInt32Array = PackedInt32Array()) -> void:
	"""Create only an observation of the current ordered allocations."""
	if kinds.is_empty():
		kinds = _mixed()
	assert_equal(_ids.peek_create_batch_into(kinds, _batch), &"", "batch available")


func _image() -> PackedByteArray:
	"""Compare every actual array byte, including raw heap tails/order and both diagnostic names."""
	var image: PackedByteArray = PackedByteArray()
	for column: PackedInt32Array in [_ids._persistent_id, _ids._generation, _ids._kind,
			_ids._typed_row, _ids._typed_owner_slot, _ids._free_heap, _ids._heap_index,
			_ids._kind_base, _ids._kind_free_count, _ids._kind_live_count]:
		image.append_array(column.to_byte_array())
	image.append_array(_ids._active)
	image.append_array(_ids._retired)
	image.append_array(PackedInt64Array([_ids._free_count, _ids._live_count,
		_ids._next_persistent_id]).to_byte_array())
	image.append_array(String(_ids.last_refusal()).to_utf8_buffer())
	image.append(0)
	image.append_array(String(_ids.last_column_refusal()).to_utf8_buffer())
	return image


func _unchanged_refusal() -> void:
	"""Both refusal paths preserve all owner bytes; no earlier prefix may have been allocated."""
	var before: PackedByteArray = _image()
	assert_true(_ids.batch_candidate_refusal(_batch) != &"", "validation refuses")
	assert_true(_ids.create_batch(_batch) != &"", "publication refuses")
	assert_true(_image() == before, "columns, raw heaps, counters and diagnostics are unchanged")


func _peek_refused(kinds: PackedInt32Array, expected: StringName) -> void:
	"""Failed observation invalidates its old prefix and never changes the actual owner."""
	var before: PackedByteArray = _image()
	assert_equal(_ids.peek_create_batch_into(kinds, _batch), expected, "specific refusal")
	assert_equal(_batch.count, 0, "no retained valid prefix")
	assert_null(_batch.directory_owner(), "no old owner binding")
	assert_equal(_batch.ref_at(0), NULL_REF, "old tuple is not readable as a receipt")
	assert_true(_image() == before, "failed peek changes no owner byte")


func _assert_published(batch: Directory.CreateBatch) -> void:
	"""Every tuple must be a real full-generation identity with the exact typed row and PID."""
	for index: int in batch.count:
		var ref: Vector2i = batch.ref_at(index)
		assert_true(_ids.is_valid_of_kind(ref, batch.kinds[index]), "actual live kind/ref")
		assert_equal(_ids.get_typed_row(ref), batch.typed_rows[index], "exact typed row")
		assert_equal(_ids.get_persistent_id(ref), batch.persistent_ids[index], "exact PID")


func test_packet_capacity_refuses_before_allocation_and_accounts_every_packed_byte() -> void:
	"""Explicit small capacity has exactly the accepted 24K+76 payload, without a result copy."""
	assert_equal(_batch.capacity(), 16, "explicit capacity")
	assert_equal(_batch.storage_refusal(), &"", "well-shaped packet")
	var bytes: int = 0
	for column: PackedInt32Array in [_batch.slots, _batch.generations, _batch.kinds,
			_batch.typed_rows, _batch.persistent_ids, _batch._frontier, _batch._kind_counts]:
		bytes += column.size() * 4
	assert_equal(bytes, Directory.CreateBatch.packed_bytes(16), "all seven packed arrays counted")
	assert_equal(bytes, 24 * 16 + 76, "derived exact payload")
	assert_equal(Directory.CreateBatch.packed_bytes(Directory.DIRECTORY_CAPACITY), 8458108, "finite ceiling")
	for capacity: int in [-1, 0, Directory.DIRECTORY_CAPACITY + 1, Directory.MAX_INT32]:
		var invalid: Directory.CreateBatch = Directory.CreateBatch.new(capacity)
		assert_equal(invalid.capacity(), 0, "invalid request allocates no tuple arena")
		assert_equal(invalid.storage_refusal(), Directory.REFUSAL_BATCH_CAPACITY, "explicit refusal")
		assert_equal(Directory.CreateBatch.packed_bytes(capacity), 0, "no accepted payload")
		assert_true(invalid.slots.is_empty() and invalid._frontier.is_empty()
			and invalid._kind_counts.is_empty(), "no invalid allocation")


func test_peek_and_revalidation_preserve_every_owner_byte_and_hide_future_refs() -> void:
	"""Read-only observations cannot publish entities or erase existing diagnostics."""
	_ids.create(-2)
	var before: PackedByteArray = _image()
	_peek()
	assert_true(_batch.directory_owner() == _ids, "exact object owner")
	assert_equal(_batch.count, 7, "only requested prefix is populated")
	assert_equal(_batch.ref_at(0), Vector2i(0, 1), "observed next global identity")
	assert_equal(_batch.typed_rows[3], 1, "second furniture row is not its global slot")
	assert_equal(_batch.persistent_ids[6], 7, "PID order follows mixed request")
	for index: int in _batch.count:
		assert_false(_ids.is_valid(_batch.ref_at(index)), "future identity remains inactive")
	assert_equal(_ids.batch_candidate_refusal(_batch), &"", "all tuples are current")
	assert_true(_image() == before, "read-only owner bytes including diagnostics unchanged")
	assert_equal(_batch.ref_at(-1), NULL_REF, "negative index")
	assert_equal(_batch.ref_at(_batch.count), NULL_REF, "unused tail is not an observation")


func test_mixed_publication_matches_ordinary_allocations_and_cannot_be_replayed() -> void:
	"""Batch allocation has the same identities/state as the original one-at-a-time allocator."""
	var ordinary: Directory = Directory.new()
	_peek()
	for index: int in _batch.count:
		var expected: Vector2i = ordinary.create(_batch.kinds[index])
		assert_equal(_batch.ref_at(index), expected, "same global allocation order")
		assert_equal(_batch.typed_rows[index], ordinary.get_typed_row(expected), "same typed order")
	assert_equal(_ids.create_batch(_batch), &"", "complete publication")
	_assert_published(_batch)
	assert_true(_ids.state_bytes() == ordinary.state_bytes(), "same complete behavioral image")
	assert_equal(_ids.total_live_count(), 7, "all and only requested rows exist")
	_unchanged_refusal()


func _fragment(owner: Directory) -> void:
	"""Produce nontrivial actual free heaps through ordinary allocations and nonmonotonic retirement."""
	var refs: Array[Vector2i] = []
	var kinds: PackedInt32Array = _mixed()
	for index: int in 119:
		refs.append(owner.create(kinds[index % kinds.size()]))
	for index: int in range(118, -1, -3):
		assert_true(owner.destroy(refs[index]), "release scattered actual rows")
	for index: int in range(0, 119, 7):
		owner.destroy(refs[index])


func test_frontier_matches_allocator_after_fragmentation_across_repeated_mixed_kinds() -> void:
	"""Traversal reads real sifted heaps, including reused generations and independent kind windows."""
	var ordinary: Directory = Directory.new()
	_fragment(_ids)
	_fragment(ordinary)
	var kinds: PackedInt32Array = PackedInt32Array()
	var pattern: PackedInt32Array = _mixed()
	for index: int in 257:
		kinds.append(pattern[index % 7])
	_batch = Directory.CreateBatch.new(kinds.size())
	var before: PackedByteArray = _image()
	_peek(kinds)
	assert_true(_image() == before, "frontier leaves all source heap bytes intact")
	for index: int in kinds.size():
		var expected: Vector2i = ordinary.create(kinds[index])
		assert_equal(_batch.ref_at(index), expected, "fragmented full identity")
		assert_equal(_batch.typed_rows[index], ordinary.get_typed_row(expected), "fragmented typed identity")
	assert_equal(_ids.create_batch(_batch), &"", "fragmented publication")
	_assert_published(_batch)
	assert_true(_ids.state_bytes() == ordinary.state_bytes(), "identical state after 257 choices")


func test_single_candidate_and_batch_interleaving_revalidate_actual_history() -> void:
	"""Neither observation reserves a slot, and either publication invalidates the older choice."""
	var single: Directory.CreateCandidate = Directory.CreateCandidate.new()
	_ids.peek_create_into(Directory.KIND_ROOM, single)
	_peek()
	assert_equal(single.ref, _batch.ref_at(0), "both read the same next global slot")
	assert_equal(_ids.create_candidate(single), single.ref, "single wins publication")
	_unchanged_refusal()
	_peek()
	_ids.peek_create_into(Directory.KIND_ROOM, single)
	assert_equal(_ids.create_batch(_batch), &"", "fresh batch wins publication")
	assert_equal(_ids.candidate_refusal(single), Directory.REFUSAL_CANDIDATE, "single is now stale")
	assert_equal(_ids.create_candidate(single), NULL_REF, "stale single cannot steal a batch row")
	_assert_published(_batch)


func test_intervening_create_destroy_spends_generation_and_pid_without_rollback() -> void:
	"""Returning the same numeric slot to the heap never resurrects an old full identity."""
	_peek()
	var spent: Vector2i = _ids.create(Directory.KIND_BUILDING)
	assert_true(_ids.destroy(spent), "retire intervening entity")
	_unchanged_refusal()
	_peek()
	assert_equal(_batch.ref_at(0), Vector2i(0, 2), "fresh full generation")
	assert_equal(_batch.persistent_ids[0], 2, "spent PID stays spent")
	assert_equal(_ids.create_batch(_batch), &"", "fresh observation succeeds")
	_assert_published(_batch)


func test_unrelated_retirement_leaves_an_unchanged_prefix_valid_without_an_epoch() -> void:
	"""A safe prefix remains usable when only higher foreign-kind free entries change."""
	var first: Vector2i = _ids.create(Directory.KIND_BUILDING)
	var middle: Vector2i = _ids.create(Directory.KIND_BUILDING)
	var last: Vector2i = _ids.create(Directory.KIND_BUILDING)
	_ids.destroy(first)
	_ids.destroy(middle)
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_FURNITURE]))
	_ids.destroy(last)
	assert_equal(_ids.batch_candidate_refusal(_batch), &"", "actual two choices remain unchanged")
	assert_equal(_ids.create_batch(_batch), &"", "safe current observation publishes")
	_assert_published(_batch)


func test_same_number_foreign_owner_expired_owner_and_null_never_qualify() -> void:
	"""Weak actual object equality is mandatory in addition to every numeric tuple."""
	var foreign: Directory = Directory.new()
	foreign.peek_create_batch_into(_mixed(), _batch)
	assert_equal(_batch.ref_at(0), Vector2i(0, 1), "identical foreign numbers")
	_unchanged_refusal()
	foreign = null
	assert_null(_batch.directory_owner(), "weak owner expires")
	assert_equal(_batch.ref_at(0), NULL_REF, "expired observation is unreadable")
	_unchanged_refusal()
	var before: PackedByteArray = _image()
	assert_equal(_ids.peek_create_batch_into(_mixed(), null), Directory.REFUSAL_BATCH, "null output")
	assert_equal(_ids.batch_candidate_refusal(null), Directory.REFUSAL_BATCH, "null validation")
	assert_equal(_ids.create_batch(null), Directory.REFUSAL_BATCH, "null publication")
	assert_true(_image() == before, "all null paths change nothing")


func test_final_tuple_tampering_never_publishes_an_earlier_valid_prefix() -> void:
	"""All five tuple columns and count are checked before even the first Directory write."""
	_peek()
	_batch.slots[6] += 1
	_unchanged_refusal()
	_peek()
	_batch.generations[6] += 1
	_unchanged_refusal()
	_peek()
	_batch.typed_rows[6] += 1
	_unchanged_refusal()
	_peek()
	_batch.persistent_ids[6] += 1
	_unchanged_refusal()
	_peek()
	_batch.kinds[6] = Directory.KIND_COUNT
	_unchanged_refusal()
	_peek()
	_batch.count = _batch.capacity() + 1
	_unchanged_refusal()
	_batch.count = -1
	_unchanged_refusal()


func test_shrunken_storage_and_invalidated_packet_refuse_without_indexing() -> void:
	"""Malformed public scratch cannot crash a release template or produce partial owner writes."""
	_peek()
	_batch.generations.resize(1)
	assert_equal(_batch.ref_at(0), NULL_REF, "malformed packet is not a receipt")
	_unchanged_refusal()
	_batch = Directory.CreateBatch.new(16)
	_peek()
	_batch._frontier.resize(0)
	_unchanged_refusal()
	_batch = Directory.CreateBatch.new(16)
	_peek()
	_batch._kind_counts.resize(1)
	_unchanged_refusal()
	_batch = Directory.CreateBatch.new(16)
	_peek()
	var before: PackedByteArray = _image()
	_batch.reset()
	assert_equal(_batch.count, 0, "reset invalidates prefix")
	assert_null(_batch.directory_owner(), "reset clears weak binding")
	assert_true(_image() == before, "reset affects only caller scratch")
	_unchanged_refusal()


func test_invalid_request_and_insufficient_packet_capacity_invalidate_previous_peek() -> void:
	"""No invalid request leaves an old valid prefix available for accidental replay."""
	_peek()
	_peek_refused(PackedInt32Array(), Directory.REFUSAL_BATCH_SHAPE)
	_peek()
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM, -2]), Directory.REFUSAL_UNKNOWN_KIND)
	_peek()
	var too_large: PackedInt32Array = PackedInt32Array()
	too_large.resize(17)
	too_large.fill(Directory.KIND_ROOM)
	_peek_refused(too_large, Directory.REFUSAL_BATCH_SHAPE)
	_batch = Directory.CreateBatch.new(0)
	_peek_refused(_mixed(), Directory.REFUSAL_BATCH_CAPACITY)


func test_typed_exhaustion_checks_the_whole_request_and_never_spends_other_kinds() -> void:
	"""Two World rows and an exhausted FishHabitat window refuse before a valid Room prefix."""
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_WORLD,
		Directory.KIND_WORLD]), &"CAPACITY_WORLD")
	var kinds: PackedInt32Array = PackedInt32Array()
	kinds.resize(32)
	kinds.fill(Directory.KIND_FISH_HABITAT)
	_batch = Directory.CreateBatch.new(33)
	_peek(kinds)
	assert_equal(_ids.create_batch(_batch), &"", "exact actual typed capacity succeeds")
	assert_equal(_ids.free_row_count(Directory.KIND_FISH_HABITAT), 0, "actual typed heap exhausted")
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_FISH_HABITAT]),
		&"CAPACITY_FISH_HABITAT")
	assert_equal(_ids.live_count(Directory.KIND_ROOM), 0, "no earlier Room prefix leaked")


func test_cap_changes_after_peek_are_rechecked_before_publication() -> void:
	"""A still-numerically-similar packet cannot bypass a newly full singleton typed store."""
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_WORLD]))
	_ids.create(Directory.KIND_WORLD)
	assert_equal(_ids.batch_candidate_refusal(_batch), &"CAPACITY_WORLD", "fresh capacity proof")
	_unchanged_refusal()


func test_resident_storage_never_allows_more_than_the_living_cap() -> void:
	"""Real publication stops at 256 despite 512 typed resident rows; no 257th entity is created."""
	var kinds: PackedInt32Array = PackedInt32Array()
	kinds.resize(Directory.RESIDENT_LIVING_CAP - 1)
	kinds.fill(Directory.KIND_RESIDENT)
	_batch = Directory.CreateBatch.new(Directory.RESIDENT_LIVING_CAP)
	_peek(kinds)
	assert_equal(_ids.create_batch(_batch), &"", "255 actual residents admitted")
	_peek_refused(PackedInt32Array([Directory.KIND_RESIDENT, Directory.KIND_RESIDENT]),
		Directory.REFUSAL_LIVING_CAP)
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_RESIDENT]))
	assert_equal(_ids.create_batch(_batch), &"", "last living place admits exactly one resident")
	assert_equal(_ids.live_count(Directory.KIND_RESIDENT), 256, "authoritative living cap")
	assert_true(_ids.free_row_count(Directory.KIND_RESIDENT) > 0, "unused storage grants no admission")
	_peek_refused(PackedInt32Array([Directory.KIND_RESIDENT]), Directory.REFUSAL_LIVING_CAP)
	var dead: Vector2i = Vector2i(0, 1)
	assert_true(_ids.destroy(dead), "release one actual living place")
	_peek(PackedInt32Array([Directory.KIND_RESIDENT]))
	assert_equal(_batch.ref_at(0), Vector2i(0, 2), "generation-safe reuse after death")
	assert_equal(_ids.create_batch(_batch), &"", "one freed place reused")
	assert_equal(_ids.live_count(Directory.KIND_RESIDENT), 256, "never exceeded living cap")


func test_pid_range_checks_the_last_requested_identity_before_any_write() -> void:
	"""Explicit synthetic cursor setup reaches signed-int32 exhaustion without billions of creates."""
	_ids._next_persistent_id = Directory.MAX_INT32 - 1
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_ROOM,
		Directory.KIND_ROOM]), Directory.REFUSAL_PERSISTENT_ID)
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_ROOM]))
	assert_equal(_batch.persistent_ids[1], Directory.MAX_INT32, "last signed PID fits exactly")
	assert_equal(_ids.create_batch(_batch), &"", "complete fitting prefix commits")
	assert_equal(_ids.next_persistent_id(), Directory.PERSISTENT_ID_EXHAUSTED, "exact exhausted cursor")
	_assert_published(_batch)
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM]), Directory.REFUSAL_PERSISTENT_ID)


func test_last_generation_retires_and_never_reenters_a_later_batch() -> void:
	"""Synthetic stored-generation setup reaches the existing once-only int32 retirement boundary."""
	_ids._generation[0] = Directory.MAX_INT32 - 1
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_FURNITURE]))
	assert_equal(_batch.ref_at(0), Vector2i(0, Directory.MAX_INT32), "final generation observed")
	assert_equal(_ids.create_batch(_batch), &"", "final generation used once")
	assert_true(_ids.destroy(_batch.ref_at(0)), "final generation destroyed")
	assert_true(_ids.destroy(_batch.ref_at(1)), "ordinary generation destroyed")
	assert_true(_ids.is_slot_retired(0), "max generation cannot re-enter free heap")
	_peek(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_FURNITURE]))
	assert_equal(_batch.ref_at(0), Vector2i(1, 2), "lowest nonretired slot is reused")
	assert_equal(_batch.ref_at(1), Vector2i(2, 1), "untouched next slot follows")
	assert_equal(_ids.create_batch(_batch), &"", "later batch never wraps identity")
	_assert_published(_batch)


func test_global_exhaustion_refuses_when_other_typed_capacity_remains() -> void:
	"""Synthetic retired-column boundary isolates the genuine global-pool refusal from typed limits."""
	_ids._retired.fill(1)
	_ids._generation.fill(Directory.MAX_INT32)
	_ids._retired[0] = 0
	_ids._generation[0] = 0
	_ids._rebuild_allocator()
	_peek_refused(PackedInt32Array([Directory.KIND_ROOM, Directory.KIND_FURNITURE]),
		Directory.REFUSAL_DIRECTORY_FULL)
	_peek(PackedInt32Array([Directory.KIND_ROOM]))
	assert_equal(_ids.create_batch(_batch), &"", "last genuinely free global slot admitted")
	assert_true(_ids.free_row_count(Directory.KIND_FURNITURE) > 0, "typed capacity still available")
	_peek_refused(PackedInt32Array([Directory.KIND_FURNITURE]), Directory.REFUSAL_DIRECTORY_FULL)


func test_input_can_alias_the_packets_own_kind_storage_without_erasing_request() -> void:
	"""Reset invalidates authority without clearing a caller's already populated input tuple array."""
	_batch = Directory.CreateBatch.new(3)
	_batch.kinds[0] = Directory.KIND_ROOM
	_batch.kinds[1] = Directory.KIND_FURNITURE
	_batch.kinds[2] = Directory.KIND_CONSTRUCTION
	_peek(_batch.kinds)
	assert_equal(_batch.count, 3, "aliased input retained")
	assert_equal(_ids.create_batch(_batch), &"", "aliased valid request publishes once")
	_assert_published(_batch)


func test_minimum_frontier_capacity_and_mutated_traversal_scratch_are_safe() -> void:
	"""K=1 needs exactly two frontier entries; retained scratch values never grant authority."""
	_batch = Directory.CreateBatch.new(1)
	_peek(PackedInt32Array([Directory.KIND_ROOM]))
	assert_equal(_batch._frontier.size(), 2, "minimum exact frontier capacity")
	_batch._frontier.fill(Directory.MAX_INT32)
	_batch._kind_counts.fill(Directory.MAX_INT32)
	var before: PackedByteArray = _image()
	assert_equal(_ids.batch_candidate_refusal(_batch), &"", "scratch is rebuilt before indexing")
	assert_true(_image() == before, "scratch rebuild never touches the allocator")
	assert_equal(_ids.create_batch(_batch), &"", "one tuple publishes normally")
	_assert_published(_batch)


func test_all_eighteen_kinds_keep_caller_order_and_their_independent_typed_rows() -> void:
	"""Reverse ASCII order exercises every real kind, including singleton and resident windows."""
	var ordinary: Directory = Directory.new()
	var kinds: PackedInt32Array = PackedInt32Array()
	for kind: int in range(Directory.KIND_COUNT - 1, -1, -1):
		kinds.append(kind)
	_batch = Directory.CreateBatch.new(Directory.KIND_COUNT)
	_peek(kinds)
	for index: int in kinds.size():
		assert_equal(_batch.kinds[index], kinds[index], "request order is not sorted by kind")
		assert_equal(_batch.typed_rows[index], 0, "each kind has its own first typed row")
		assert_equal(_batch.ref_at(index), ordinary.create(kinds[index]), "ordinary global order")
	assert_equal(_ids.create_batch(_batch), &"", "all eighteen kinds published")
	_assert_published(_batch)
	assert_true(_ids.state_bytes() == ordinary.state_bytes(), "all-kind state matches original allocator")


func test_cold_2048_identity_observation_and_commit_report_unqualified_timing() -> void:
	"""A real 1024 furniture/project pair packet measures cold work; no target-hardware budget claim."""
	var kinds: PackedInt32Array = PackedInt32Array()
	kinds.resize(2048)
	for index: int in kinds.size():
		kinds[index] = Directory.KIND_FURNITURE if index % 2 == 0 else Directory.KIND_CONSTRUCTION
	_batch = Directory.CreateBatch.new(kinds.size())
	var started: int = Time.get_ticks_usec()
	var peek_code: StringName = _ids.peek_create_batch_into(kinds, _batch)
	var peek_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var read_code: StringName = _ids.batch_candidate_refusal(_batch)
	var read_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var commit_code: StringName = _ids.create_batch(_batch)
	var commit_usec: int = Time.get_ticks_usec() - started
	assert_equal(peek_code, &"", "2048-identity observation")
	assert_equal(read_code, &"", "2048-identity revalidation")
	assert_equal(commit_code, &"", "2048-identity commit including its final validation")
	assert_equal(_ids.live_count(Directory.KIND_FURNITURE), 1024, "all furniture identities exist")
	assert_equal(_ids.live_count(Directory.KIND_CONSTRUCTION), 1024, "all project identities exist")
	_assert_published(_batch)
	print("UG1086_BATCH_TIMING K=2048 packed=49228 peek_us=%d validate_us=%d commit_us=%d" % [
		peek_usec, read_usec, commit_usec])
