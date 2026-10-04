extends "res://test/framework/test_case.gd"

const Budget := preload("res://scripts/core/underground_budget.gd")


func test_joint_pack_keeps_actual_known_buffers_and_positive_remaining_budget() -> void:
	"""Independent literal products catch an accidentally enlarged component pack."""
	assert_equal(Budget.SPACE_BANK_BYTES, 1104160, "both owner banks and derived scratch")
	assert_equal(Budget.SPACE_WIRE_BYTES, 503952, "one exact current source payload")
	assert_equal(Budget.PROOF_BYTES, 17724, "proof cache and replacement")
	assert_equal(Budget.COLD_BYTES, 1048960, "phase composition peak")
	assert_equal(Budget.LOCATION_CAPACITY, 1024, "finite actual endpoint pack")
	assert_equal(Budget.INVENTORY_ENDPOINT_CAPACITY, 1024, "finite retained container identities")


func test_invalid_and_oversized_requests_leave_the_shared_arena_unchanged() -> void:
	"""Invalid byte requests never mint a lease or poison a later legitimate operation."""
	var arena: Budget = Budget.new()
	for size: int in [-1, 0, Budget.COLD_BYTES + 1, Budget.I64_MAX]:
		assert_equal(arena.admission_refusal(size), Budget.REFUSE_BYTES, "explicit capacity refusal")
		assert_equal(arena.acquire(size), 0, "no permission")
		assert_true(arena.is_quiescent(), "no retained allocation")
	assert_equal(arena.peak_reserved_bytes(), 0, "failed requests consume no reservation")
	assert_equal(arena.acquire(1), 1, "invalid requests consumed no token")


func test_two_consumers_cannot_each_claim_the_full_cold_budget() -> void:
	"""Save and a phase cannot coexist merely because each independently fits."""
	var arena: Budget = Budget.new()
	var phase: int = arena.acquire(Budget.COLD_BYTES)
	assert_true(phase > 0, "first operation admitted")
	assert_equal(arena.admission_refusal(Budget.SPACE_WIRE_BYTES), Budget.REFUSE_BUSY, "second must wait")
	assert_equal(arena.acquire(Budget.SPACE_WIRE_BYTES), 0, "no overlapping owner")
	assert_false(arena.is_quiescent(), "save boundary remains blocked")
	assert_equal(arena.used_bytes(), Budget.COLD_BYTES, "first complete charge retained")
	assert_equal(arena.release(phase), &"", "actual operation releases")
	assert_true(arena.acquire(Budget.SPACE_WIRE_BYTES) > phase, "later save is independent")


func test_nested_companions_charge_their_full_simultaneous_peak() -> void:
	"""The final byte fits; an additional byte refuses without losing the original charge."""
	var arena: Budget = Budget.new()
	var token: int = arena.acquire(Budget.SPACE_WIRE_BYTES)
	assert_equal(arena.extend(token, Budget.COLD_BYTES - Budget.SPACE_WIRE_BYTES), &"", "exact total")
	assert_equal(arena.extend(token, 1), Budget.REFUSE_BYTES, "no hidden companion allocation")
	assert_equal(arena.extend(token, -1), Budget.REFUSE_BYTES, "no negative release")
	assert_equal(arena.extend(token, Budget.I64_MAX), Budget.REFUSE_BYTES, "subtraction check cannot overflow")
	assert_equal(arena.used_bytes(), Budget.COLD_BYTES, "failed growth is unchanged")
	assert_equal(arena.peak_reserved_bytes(), Budget.COLD_BYTES, "logical observed peak")
	assert_true(arena.covers(token, Budget.COLD_BYTES), "full simultaneous charge remains attested")
	assert_false(arena.covers(token, Budget.COLD_BYTES + 1), "unreserved bytes cannot be used")
	assert_false(arena.covers(token, 0), "empty request supplies no allocation proof")


func test_stale_or_unissued_token_cannot_grow_or_release_the_next_operation() -> void:
	"""A finished caller cannot free a later caller's held geometry or save image."""
	var arena: Budget = Budget.new()
	var first: int = arena.acquire(100)
	assert_equal(arena.release(first), &"", "first release")
	var second: int = arena.acquire(200)
	for stale: int in [-1, 0, first, second + 1]:
		assert_equal(arena.extend(stale, 10), Budget.REFUSE_TOKEN, "stale growth")
		assert_equal(arena.release(stale), Budget.REFUSE_TOKEN, "stale release")
		assert_false(arena.covers(stale, 1), "stale token grants no retained allocation")
		assert_equal(arena.used_bytes(), 200, "new owner's reservation retained")
	assert_equal(arena.release(second), &"", "only current owner releases")
	assert_true(arena.is_quiescent(), "clean boundary")
	assert_equal(arena.peak_reserved_bytes(), 200, "history is only a reservation measurement")


func test_exhausted_token_space_refuses_without_wrapping() -> void:
	"""A retained stale integer can never regain cold-operation permission through wraparound."""
	var arena: Budget = Budget.new()
	arena.set("_next_token", Budget.I64_MAX)
	assert_equal(arena.acquire(1), 0, "generation exhaustion refuses")
	assert_true(arena.is_quiescent(), "no live operation after exhaustion")
