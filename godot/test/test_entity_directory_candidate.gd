extends "res://test/framework/test_case.gd"
## Decision 1083: actual allocator observations, not mock identities or generation rollback.

const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _ids: Directory = null
var _candidate: Directory.CreateCandidate = null


func before_each() -> void:
	"""Use actual complete Directory columns and the unchanged two-level min-heaps."""
	_ids = Directory.new()
	_candidate = Directory.CreateCandidate.new()


func after_each() -> void:
	"""Candidates keep only a weak exact owner, so no ownership cycle survives."""
	_candidate = null
	_ids = null


func _peek(kind: int = Directory.KIND_ROOM) -> void:
	"""Read one exact candidate without spending an identity or typed-store row."""
	assert_equal(_ids.peek_create_into(kind, _candidate), &"", "candidate available")


func _unchanged_refusal() -> void:
	"""The complete real Directory image includes both heaps, all columns and the PID cursor."""
	var before: PackedByteArray = _ids.state_bytes()
	assert_true(_ids.candidate_refusal(_candidate) != &"", "read refuses")
	assert_equal(_ids.create_candidate(_candidate), NULL_REF, "publication refuses")
	assert_equal(_ids.state_bytes(), before, "refusal changes no allocator or identity byte")


func test_peek_is_read_only_and_publish_matches_every_observed_identity_field() -> void:
	"""Future identity remains invisible to ordinary readers until actual publication."""
	var before: PackedByteArray = _ids.state_bytes()
	_peek()
	assert_equal(_ids.state_bytes(), before, "peek changes nothing")
	assert_true(_candidate.directory_owner() == _ids, "actual object identity")
	assert_equal(_candidate.ref, Vector2i(0, 1), "next global min root and generation")
	assert_equal(_candidate.typed_row, 0, "next Room typed min root")
	assert_equal(_candidate.persistent_id, 1, "unspent next PID")
	assert_false(_ids.is_valid(_candidate.ref), "future ref is not live")
	assert_equal(_ids.ref_of_slot(0), NULL_REF, "ordinary readers hide the inactive slot")
	assert_equal(_ids.candidate_refusal(_candidate), &"", "exact current observation validates")
	var made: Vector2i = _ids.create_candidate(_candidate)
	assert_equal(made, _candidate.ref, "published exact future ref")
	assert_equal(_ids.get_kind(made), _candidate.kind, "kind matches")
	assert_equal(_ids.get_typed_row(made), _candidate.typed_row, "typed row matches")
	assert_equal(_ids.get_persistent_id(made), _candidate.persistent_id, "PID matches")
	assert_equal(_ids.next_persistent_id(), 2, "only successful publication spends one PID")
	_unchanged_refusal()


func test_numeric_foreign_candidate_cannot_publish_in_an_identical_directory() -> void:
	"""Full ref, kind, row and PID equality cannot substitute for actual owner identity."""
	var foreign: Directory = Directory.new()
	assert_equal(foreign.peek_create_into(Directory.KIND_ROOM, _candidate), &"", "foreign candidate")
	assert_equal(_candidate.ref, Vector2i(0, 1), "same numbers as local allocation")
	_unchanged_refusal()
	assert_equal(foreign.total_live_count(), 0, "foreign owner was also untouched")


func test_expired_owner_and_null_packets_never_qualify() -> void:
	"""Weak expiration cannot turn a candidate into a generic future-identity permit."""
	var foreign: Directory = Directory.new()
	foreign.peek_create_into(Directory.KIND_ROOM, _candidate)
	foreign = null
	assert_null(_candidate.directory_owner(), "weak owner expires")
	_unchanged_refusal()
	var before: PackedByteArray = _ids.state_bytes()
	assert_equal(_ids.peek_create_into(Directory.KIND_ROOM, null), Directory.REFUSAL_CANDIDATE, "null output")
	assert_equal(_ids.candidate_refusal(null), Directory.REFUSAL_CANDIDATE, "null candidate")
	assert_equal(_ids.create_candidate(null), NULL_REF, "null commit")
	assert_equal(_ids.state_bytes(), before, "all null paths unchanged")


func test_intervening_allocation_then_retirement_does_not_resurrect_a_candidate() -> void:
	"""Create-and-delete spends generation and PID even when the same global root returns."""
	_peek()
	var intervening: Vector2i = _ids.create(Directory.KIND_BUILDING)
	assert_true(_ids.destroy(intervening), "retire intervening allocation")
	_unchanged_refusal()
	_peek()
	assert_equal(_candidate.ref, Vector2i(0, 2), "fresh observation sees incremented generation")
	assert_equal(_candidate.persistent_id, 2, "spent PID is never restored")
	assert_equal(_ids.create_candidate(_candidate), _candidate.ref, "fresh candidate commits")


func test_tampered_identity_row_pid_and_invalid_kind_refuse_before_writes() -> void:
	"""A scratch packet cannot override any real allocator choice."""
	_peek()
	_candidate.ref.x += 1
	_unchanged_refusal()
	_peek()
	_candidate.ref.y += 1
	_unchanged_refusal()
	_peek()
	_candidate.typed_row += 1
	_unchanged_refusal()
	_peek()
	_candidate.persistent_id += 1
	_unchanged_refusal()
	_peek()
	_candidate.kind = Directory.KIND_COUNT
	_unchanged_refusal()


func test_changed_typed_root_is_rechecked_even_with_matching_global_identity() -> void:
	"""Candidate validation reads the kind's actual min root, not just its free count."""
	var first: Vector2i = _ids.create(Directory.KIND_ROOM)
	_peek()
	assert_equal(_candidate.typed_row, 1, "next typed row while first Room exists")
	assert_true(_ids.destroy(first), "lowest global and typed rows become free")
	var same_global: Directory.CreateCandidate = Directory.CreateCandidate.new()
	_ids.peek_create_into(Directory.KIND_ROOM, same_global)
	_candidate.ref = same_global.ref
	assert_equal(_candidate.persistent_id, same_global.persistent_id, "PID is unchanged by retirement")
	_unchanged_refusal()


func test_unrelated_retirement_does_not_invalidate_unchanged_actual_choices() -> void:
	"""No new global epoch needlessly forbids a safe current candidate."""
	var low: Vector2i = _ids.create(Directory.KIND_BUILDING)
	var high: Vector2i = _ids.create(Directory.KIND_BUILDING)
	assert_true(_ids.destroy(low), "lowest slot available")
	_peek()
	assert_true(_ids.destroy(high), "a higher foreign typed row is freed")
	assert_equal(_ids.candidate_refusal(_candidate), &"", "all observed allocator choices still match")
	assert_equal(_ids.create_candidate(_candidate), _candidate.ref, "current candidate can publish")


func test_capacity_invalid_kind_and_exhausted_pid_peeks_reset_only_the_packet() -> void:
	"""All pre-existing allocator refusals stay strict and never leave an old successful packet."""
	_peek()
	var before: PackedByteArray = _ids.state_bytes()
	assert_equal(_ids.peek_create_into(-2, _candidate), Directory.REFUSAL_UNKNOWN_KIND, "unknown kind")
	assert_equal(_candidate.ref, NULL_REF, "failed peek erases old ref")
	assert_null(_candidate.directory_owner(), "failed peek erases weak binding")
	assert_equal(_ids.state_bytes(), before, "unknown kind unchanged")
	_ids.create(Directory.KIND_WORLD)
	before = _ids.state_bytes()
	assert_equal(_ids.peek_create_into(Directory.KIND_WORLD, _candidate), &"CAPACITY_WORLD", "actual kind full")
	assert_equal(_ids.state_bytes(), before, "capacity refusal unchanged")
	_ids._next_persistent_id = Directory.PERSISTENT_ID_EXHAUSTED
	before = _ids.state_bytes()
	assert_equal(_ids.peek_create_into(Directory.KIND_ROOM, _candidate), Directory.REFUSAL_PERSISTENT_ID, "PID exhausted")
	assert_equal(_ids.state_bytes(), before, "PID refusal unchanged")


func test_candidate_respects_living_cap_after_an_intervening_resident() -> void:
	"""No candidate bypasses the authoritative 256 living cap."""
	for index: int in Directory.RESIDENT_LIVING_CAP - 1:
		assert_true(_ids.create(Directory.KIND_RESIDENT) != NULL_REF, "resident below cap")
	_peek(Directory.KIND_RESIDENT)
	_ids.create(Directory.KIND_RESIDENT)
	assert_equal(_ids.candidate_refusal(_candidate), Directory.REFUSAL_LIVING_CAP, "fresh cap check")
	_unchanged_refusal()


func test_final_generation_and_pid_are_used_once_without_wrapping() -> void:
	"""The observed future identity uses the original exhaustion and retirement semantics."""
	_ids._generation[0] = Directory.MAX_INT32 - 1
	_ids._next_persistent_id = Directory.MAX_INT32
	_peek()
	assert_equal(_candidate.ref.y, Directory.MAX_INT32, "final signed generation")
	assert_equal(_candidate.persistent_id, Directory.MAX_INT32, "final signed PID")
	var made: Vector2i = _ids.create_candidate(_candidate)
	assert_true(_ids.destroy(made), "final generation retires")
	assert_true(_ids.is_slot_retired(0), "retired slot cannot re-enter heap")
	assert_equal(_ids.next_persistent_id(), Directory.PERSISTENT_ID_EXHAUSTED, "cursor remains exhausted")
	_unchanged_refusal()


func test_reset_packet_releases_no_capacity_and_cannot_publish() -> void:
	"""No hidden reservation is created by a candidate object or its lifetime."""
	_peek()
	var before: PackedByteArray = _ids.state_bytes()
	_candidate.reset()
	assert_equal(_candidate.kind, Directory.KIND_ANY, "reset kind")
	assert_equal(_candidate.typed_row, Directory.NULL_SLOT, "reset row")
	assert_equal(_candidate.persistent_id, 0, "reset PID")
	assert_equal(_ids.state_bytes(), before, "reset affects scratch only")
	_unchanged_refusal()
