extends "res://test/framework/test_case.gd"
## Suite for scripts/core/rng.gd -- ARCH-RNG-001's xorshift32 and ARCH-RNG-002's nine streams.
##
## Every expected number in this file is a literal computed from the published algorithm, not a
## value read back from the module under test. Two runs of the same code agreeing proves
## nothing; these assertions fail if the algorithm itself drifts. The only fixture quoted from a
## document is GT-004, "With seed state1, first xorshift values are 270369, 67634689,
## 2647435461, 307599695, 2398689233" (crowd §12.2, restated in ARCH-RNG-001).

const Rng := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §5.1: "A fixed-seed tutorial uses seed 20260905." Used as this suite's reference world.
const TUTORIAL_SEED: int = 20260905

## `hash_pair(20260905, stream_id+1)` for stream_id 0..8, in ARCH-RNG-002 ASCII order.
const TUTORIAL_SEEDED_STATES: Array[int] = [
	857490604, 857490605, 857490606, 857490607, 857490600,
	857490601, 857490602, 857490603, 857490596,
]

## The int32 world seed for which `hash_pair(seed, ECOLOGY+1)` is exactly 0, so ARCH-RNG-001's
## "replace a zero initialized state with 1" is a reachable case rather than a hypothetical.
const ZERO_HASH_SEED_FOR_ECOLOGY: int = -1195192679

## First five xorshift32 outputs from state 1 (crowd §12.2 GT-004).
const GT004_SEQUENCE: Array[int] = [270369, 67634689, 2647435461, 307599695, 2398689233]

## First six raw draws of each of these streams under TUTORIAL_SEED.
const ECOLOGY_DRAWS: Array[int] = [
	3401233512, 449360915, 2232456438, 1716386065, 4103668070, 1107348668,
]
const FISHING_DRAWS: Array[int] = [
	3401487433, 515944978, 417086515, 1947754590, 2053117623, 1852807020,
]
const WEATHER_DRAWS: Array[int] = [
	3399202144, 986350619, 594802399, 3903797611, 4291398634, 404830896,
	3516105835, 2194155620, 2136578886, 3391018654, 158253560, 4217668432,
]
## `(draw mod 21) - 10` over the QUALITY stream's first six draws (ARCH-RNG-002 QUALITY row).
const QUALITY_R_VALUES: Array[int] = [-1, -3, 3, 6, -10, -6]


func _seeded(world_seed: int) -> Rng:
	"""Build a store seeded with `world_seed`, failing the test if seeding itself refuses."""
	var rng: Rng = Rng.new()
	var seeded: Rng.OpResult = rng.seed_world(world_seed)
	assert_true(seeded.ok, "seed_world(%d) must succeed (got %s)" % [world_seed, seeded.error])
	return rng


func _value_of(result: IntMath.IntResult, message: String) -> int:
	"""Unwrap a successful IntResult, recording a failure and returning 0 when it refused."""
	assert_true(result.ok, "%s (refused: %s)" % [message, result.error])
	return result.value if result.ok else 0


# --- ARCH-RNG-001: the algorithm itself -----------------------------------------------------------

func test_gt004_fixed_stream_from_state_one() -> void:
	"""GT-004's published five-value fixture reproduces exactly, in order, from state 1."""
	var state: int = 1
	for index: int in range(GT004_SEQUENCE.size()):
		var step: IntMath.IntResult = Rng.next_u32_from(state)
		assert_true(step.ok, "step %d from state 1 must succeed" % index)
		assert_equal(step.value, GT004_SEQUENCE[index],
			"GT-004 value %d" % index)
		state = step.value


func test_next_u32_refuses_zero_and_non_u32_state() -> void:
	"""Zero state is forbidden by crowd §6.1; so is any value outside the u32 domain."""
	var zero: IntMath.IntResult = Rng.next_u32_from(0)
	assert_false(zero.ok, "xorshift32 must refuse a zero state")
	assert_equal(zero.error, String(Rng.REFUSE_ZERO_STATE), "zero-state refusal code")
	assert_equal(zero.value, 0, "a refusal carries no value")
	var negative: IntMath.IntResult = Rng.next_u32_from(-1)
	assert_false(negative.ok, "a negative state is not a u32")
	assert_equal(negative.error, String(Rng.REFUSE_STATE_OUT_OF_RANGE), "negative-state code")
	var too_large: IntMath.IntResult = Rng.next_u32_from(Rng.U32_COUNT)
	assert_false(too_large.ok, "2^32 is outside the u32 domain")
	assert_equal(too_large.error, String(Rng.REFUSE_STATE_OUT_OF_RANGE), "oversized-state code")


func test_next_u32_never_produces_zero_over_a_long_run() -> void:
	"""xorshift32 cannot reach zero from a nonzero state; confirm over 20000 consecutive steps."""
	var state: int = TUTORIAL_SEEDED_STATES[Rng.STREAM_MAP]
	var minimum: int = Rng.U32_MASK
	for _index: int in range(20000):
		var step: IntMath.IntResult = Rng.next_u32_from(state)
		if not step.ok:
			fail("step refused mid-run: %s" % step.error)
			return
		state = step.value
		if state < minimum:
			minimum = state
	assert_true(minimum > 0, "no state in a 20000-step run may be zero (lowest was %d)" % minimum)
	assert_equal(state, 3445594991, "state after 20000 steps is not the published algorithm's")


func test_hash_pair_matches_the_published_constants() -> void:
	"""hash_pair reproduces ARCH-RNG-001's constants for positive, zero and negative inputs."""
	assert_equal(Rng.hash_pair(TUTORIAL_SEED, 1), 857490604, "hash_pair(20260905,1)")
	assert_equal(Rng.hash_pair(TUTORIAL_SEED, 9), 857490596, "hash_pair(20260905,9)")
	assert_equal(Rng.hash_pair(0, 0), 1120965908, "hash_pair(0,0)")
	assert_equal(Rng.hash_pair(-1, 7), 905157895, "hash_pair(-1,7) masks a negative first input")
	assert_equal(Rng.hash_pair(ZERO_HASH_SEED_FOR_ECOLOGY, 1), 0,
		"this seed is chosen precisely because its ECOLOGY hash is zero")


# --- ARCH-RNG-002: the stream table ----------------------------------------------------------------

func test_stream_keys_are_the_nine_names_in_ascii_order() -> void:
	"""The compiled table is exactly ARCH-RNG-002's nine keys, ascending, with matching IDs."""
	assert_equal(Rng.STREAM_KEYS.size(), 9, "ARCH-RNG-002 names nine streams")
	var expected: Array[String] = [
		"ECOLOGY", "FISHING", "FORAGE", "HUNTING", "IMMIGRATION",
		"MAP", "QUALITY", "SOCIAL", "WEATHER",
	]
	for index: int in range(expected.size()):
		assert_equal(Rng.STREAM_KEYS[index], expected[index], "stream key at ID %d" % index)
		if index > 0:
			assert_true(expected[index - 1] < expected[index],
				"keys %d and %d are in ascending ASCII order" % [index - 1, index])
		assert_equal(_value_of(Rng.stream_id_of(expected[index]), "id of %s" % expected[index]),
			index, "stream_id_of(%s)" % expected[index])
		assert_equal(Rng.stream_key_of(index), expected[index], "stream_key_of(%d)" % index)


func test_unknown_stream_names_and_ids_are_refused() -> void:
	"""An unlisted key or an out-of-range ID refuses instead of resolving to a neighbouring slot."""
	var unknown: IntMath.IntResult = Rng.stream_id_of("HUNT")
	assert_false(unknown.ok, "HUNT is not a compiled stream key")
	assert_equal(unknown.error, String(Rng.REFUSE_UNKNOWN_STREAM), "unknown key refusal code")
	assert_equal(Rng.stream_key_of(-1), "", "negative ID names no stream")
	assert_equal(Rng.stream_key_of(Rng.STREAM_COUNT), "", "ID 9 names no stream")
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var read: IntMath.IntResult = rng.state_of(Rng.STREAM_COUNT)
	assert_false(read.ok, "reading an out-of-range stream refuses")
	assert_equal(read.error, String(Rng.REFUSE_UNKNOWN_STREAM), "out-of-range read code")
	var rolled: IntMath.IntResult = rng.draw(-1)
	assert_false(rolled.ok, "drawing from a negative stream ID refuses")
	assert_equal(rolled.error, String(Rng.REFUSE_UNKNOWN_STREAM), "negative-ID draw code")


# --- seed derivation --------------------------------------------------------------------------------

func test_seed_derivation_is_hash_pair_of_seed_and_stream_id_plus_one() -> void:
	"""Every stream's initial state equals hash_pair(world_seed, stream_id+1), literal by literal."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	for stream_id: int in range(Rng.STREAM_COUNT):
		assert_equal(_value_of(rng.state_of(stream_id), "state of stream %d" % stream_id),
			TUTORIAL_SEEDED_STATES[stream_id], "seeded state of stream %d" % stream_id)
		assert_equal(_value_of(rng.draw_count_of(stream_id), "count of %d" % stream_id), 0,
			"a freshly seeded stream has taken no draws")
	assert_equal(_value_of(rng.world_seed_value(), "world seed"), TUTORIAL_SEED,
		"the store reports the seed it was derived from")


func test_zero_hash_seed_is_replaced_with_one() -> void:
	"""ARCH-RNG-001's "replace a zero initialized state with 1" on a seed that really produces 0."""
	var rng: Rng = _seeded(ZERO_HASH_SEED_FOR_ECOLOGY)
	assert_equal(_value_of(rng.state_of(Rng.STREAM_ECOLOGY), "ECOLOGY state"), 1,
		"a zero derived hash becomes state 1, never state 0")
	assert_true(_value_of(rng.state_of(Rng.STREAM_FISHING), "FISHING state") != 0,
		"the substitution does not disturb another stream")
	for index: int in range(GT004_SEQUENCE.size()):
		assert_equal(_value_of(rng.draw(Rng.STREAM_ECOLOGY), "ECOLOGY draw %d" % index),
			GT004_SEQUENCE[index],
			"a stream seeded to 1 must reproduce the GT-004 fixture at draw %d" % index)


func test_extreme_int32_world_seeds_derive_their_published_states() -> void:
	"""Seed 0, -1 and both int32 extremes derive the states the published hash gives."""
	assert_equal(_value_of(_seeded(0).state_of(Rng.STREAM_ECOLOGY), "seed 0"), 1120965909,
		"seed 0 ECOLOGY state")
	assert_equal(_value_of(_seeded(-1).state_of(Rng.STREAM_WEATHER), "seed -1"), 905157893,
		"seed -1 WEATHER state")
	assert_equal(_value_of(_seeded(2147483647).state_of(Rng.STREAM_MAP), "seed int32 max"),
		3052608768, "seed 2147483647 MAP state")
	assert_equal(_value_of(_seeded(-2147483648).state_of(Rng.STREAM_SOCIAL), "seed int32 min"),
		3268416796, "seed -2147483648 SOCIAL state")


func test_seed_world_refuses_a_seed_outside_int32() -> void:
	"""World.seed is int32 (GDD §4.2); a wider value is refused, never masked into a valid world."""
	var rng: Rng = Rng.new()
	var too_large: Rng.OpResult = rng.seed_world(2147483648)
	assert_false(too_large.ok, "2^31 is not an int32 world seed")
	assert_equal(too_large.error, Rng.REFUSE_SEED_NOT_INT32, "oversized-seed refusal code")
	assert_false(rng.is_seeded(), "a refused seeding leaves the store unseeded")
	var too_small: Rng.OpResult = rng.seed_world(-2147483649)
	assert_false(too_small.ok, "-2^31-1 is not an int32 world seed")
	assert_equal(too_small.error, Rng.REFUSE_SEED_NOT_INT32, "undersized-seed refusal code")
	var derived: IntMath.IntResult = Rng.seeded_state_for(2147483648, Rng.STREAM_MAP)
	assert_false(derived.ok, "the static derivation refuses the same seed")
	assert_equal(derived.error, String(Rng.REFUSE_SEED_NOT_INT32), "static derivation code")


# --- determinism and independence ---------------------------------------------------------------------

func test_two_independent_stores_produce_the_same_literal_sequence() -> void:
	"""Two separately constructed stores with one seed emit the published values, in order."""
	var first: Rng = _seeded(TUTORIAL_SEED)
	var second: Rng = _seeded(TUTORIAL_SEED)
	for index: int in range(ECOLOGY_DRAWS.size()):
		var a: int = _value_of(first.draw(Rng.STREAM_ECOLOGY), "store A draw %d" % index)
		var b: int = _value_of(second.draw(Rng.STREAM_ECOLOGY), "store B draw %d" % index)
		assert_equal(a, ECOLOGY_DRAWS[index], "store A ECOLOGY draw %d" % index)
		assert_equal(b, ECOLOGY_DRAWS[index], "store B ECOLOGY draw %d" % index)
	assert_equal(_value_of(first.state_of(Rng.STREAM_ECOLOGY), "A state"),
		_value_of(second.state_of(Rng.STREAM_ECOLOGY), "B state"),
		"both stores end on the same state")


func test_different_seeds_produce_different_sequences() -> void:
	"""A changed world seed changes the stream, so the seed is genuinely reaching the state."""
	var tutorial: Rng = _seeded(TUTORIAL_SEED)
	var other: Rng = _seeded(TUTORIAL_SEED + 1)
	var differences: int = 0
	for index: int in range(6):
		var a: int = _value_of(tutorial.draw(Rng.STREAM_WEATHER), "tutorial draw %d" % index)
		var b: int = _value_of(other.draw(Rng.STREAM_WEATHER), "other draw %d" % index)
		assert_equal(a, WEATHER_DRAWS[index], "tutorial WEATHER draw %d" % index)
		if a != b:
			differences += 1
	assert_equal(differences, 6, "every one of six draws differs under a different seed")


func test_streams_do_not_perturb_one_another() -> void:
	"""Draining FISHING leaves ECOLOGY's sequence and count exactly where they were."""
	var busy: Rng = _seeded(TUTORIAL_SEED)
	for index: int in range(FISHING_DRAWS.size()):
		assert_equal(_value_of(busy.draw(Rng.STREAM_FISHING), "FISHING draw %d" % index),
			FISHING_DRAWS[index], "FISHING draw %d" % index)
	assert_equal(_value_of(busy.draw_count_of(Rng.STREAM_ECOLOGY), "ECOLOGY count"), 0,
		"six FISHING draws advance no other stream's counter")
	assert_equal(_value_of(busy.state_of(Rng.STREAM_ECOLOGY), "ECOLOGY state"),
		TUTORIAL_SEEDED_STATES[Rng.STREAM_ECOLOGY], "ECOLOGY state is untouched")
	for index: int in range(3):
		assert_equal(_value_of(busy.draw(Rng.STREAM_ECOLOGY), "ECOLOGY draw %d" % index),
			ECOLOGY_DRAWS[index], "ECOLOGY draw %d after unrelated FISHING traffic" % index)


func test_every_stream_has_its_own_counter() -> void:
	"""Draw counts are per stream, so a desync localises to one named stream."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var taken: Array[int] = [4, 0, 2, 0, 7, 1, 3, 0, 5]
	for stream_id: int in range(Rng.STREAM_COUNT):
		for _index: int in range(taken[stream_id]):
			assert_true(rng.draw(stream_id).ok, "draw from stream %d" % stream_id)
	for stream_id: int in range(Rng.STREAM_COUNT):
		assert_equal(_value_of(rng.draw_count_of(stream_id), "count of %d" % stream_id),
			taken[stream_id], "stream %d counted exactly its own draws" % stream_id)


# --- draw counting ---------------------------------------------------------------------------------------

func test_draw_count_increments_exactly_once_per_draw_of_every_form() -> void:
	"""draw(), draw_below() and draw_in_range() each consume exactly one draw."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	assert_true(rng.draw(Rng.STREAM_WEATHER).ok, "raw draw")
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_WEATHER), "count"), 1, "after one raw draw")
	assert_true(rng.draw_below(Rng.STREAM_WEATHER, 7).ok, "bounded draw")
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_WEATHER), "count"), 2,
		"draw_below consumes exactly one draw, never a rejection loop")
	assert_true(rng.draw_in_range(Rng.STREAM_WEATHER, -10, 10).ok, "ranged draw")
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_WEATHER), "count"), 3,
		"draw_in_range consumes exactly one draw")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_WEATHER), "state"),
		WEATHER_DRAWS[2], "three draws of three forms land on the third published value")


func test_a_refused_draw_consumes_nothing() -> void:
	"""Every refusal path leaves state and count untouched, so replay cannot drift past it."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	assert_true(rng.draw(Rng.STREAM_MAP).ok, "one legitimate draw first")
	var state_before: int = _value_of(rng.state_of(Rng.STREAM_MAP), "state before refusals")
	assert_false(rng.draw_below(Rng.STREAM_MAP, 0).ok, "bound 0 refuses")
	assert_false(rng.draw_below(Rng.STREAM_MAP, -3).ok, "negative bound refuses")
	assert_false(rng.draw_below(Rng.STREAM_MAP, Rng.U32_COUNT + 1).ok, "bound above 2^32 refuses")
	assert_false(rng.draw_in_range(Rng.STREAM_MAP, 5, 4).ok, "inverted range refuses")
	assert_false(rng.draw_in_range(Rng.STREAM_MAP, 0, 2147483648).ok, "non-int32 bound refuses")
	assert_false(rng.draw(Rng.STREAM_HUNTING).ok, "the tombstone refuses")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_MAP), "state after refusals"), state_before,
		"six refusals advanced no state")
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_MAP), "count after refusals"), 1,
		"six refusals counted no draw")


func test_draws_refuse_until_the_world_is_seeded() -> void:
	"""An unseeded store holds state 0 everywhere and refuses every draw and read."""
	var rng: Rng = Rng.new()
	assert_false(rng.is_seeded(), "a new store is unseeded")
	var rolled: IntMath.IntResult = rng.draw(Rng.STREAM_ECOLOGY)
	assert_false(rolled.ok, "drawing before seeding refuses")
	assert_equal(rolled.error, String(Rng.REFUSE_NOT_SEEDED), "unseeded draw refusal code")
	var read: IntMath.IntResult = rng.state_of(Rng.STREAM_ECOLOGY)
	assert_false(read.ok, "reading state before seeding refuses")
	assert_equal(read.error, String(Rng.REFUSE_NOT_SEEDED), "unseeded read refusal code")
	assert_false(rng.world_seed_value().ok, "there is no world seed to report yet")
	assert_false(rng.tombstone_is_intact(), "an unseeded tombstone is not yet the canonical seed")
	assert_false(rng.restore_stream(Rng.STREAM_MAP, 1234, 0).ok,
		"restoring into an unseeded store refuses, because the tombstone rule needs the seed")


func test_clear_returns_the_store_to_unseeded() -> void:
	"""clear() drops the seed and every count, and draws refuse again afterwards."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	assert_true(rng.draw(Rng.STREAM_SOCIAL).ok, "a draw before clearing")
	rng.clear()
	assert_false(rng.is_seeded(), "clear() unseeds the store")
	assert_false(rng.draw(Rng.STREAM_SOCIAL).ok, "drawing after clear() refuses")
	var reseeded: Rng.OpResult = rng.seed_world(TUTORIAL_SEED)
	assert_true(reseeded.ok, "the store can be seeded again")
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_SOCIAL), "count"), 0,
		"reseeding zeroes every draw count")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_SOCIAL), "state"),
		TUTORIAL_SEEDED_STATES[Rng.STREAM_SOCIAL], "reseeding restores the derived state")


# --- SET-AMEND-001 §3: the HUNTING tombstone ---------------------------------------------------------------

func test_hunting_tombstone_is_seeded_but_refuses_every_draw() -> void:
	"""The retired slot keeps the prior seed rule, a zero count, and refuses all three draw forms."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	assert_true(Rng.is_retired(Rng.STREAM_HUNTING), "HUNTING is the retired slot")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_HUNTING), "HUNTING state"),
		TUTORIAL_SEEDED_STATES[Rng.STREAM_HUNTING], "the tombstone is seeded by the prior rule")
	var forms: Array[IntMath.IntResult] = [
		rng.draw(Rng.STREAM_HUNTING),
		rng.draw_below(Rng.STREAM_HUNTING, 6),
		rng.draw_in_range(Rng.STREAM_HUNTING, -10, 10),
	]
	for index: int in range(forms.size()):
		assert_false(forms[index].ok, "draw form %d must refuse on HUNTING" % index)
		assert_equal(forms[index].error, String(Rng.REFUSE_RETIRED_STREAM),
			"draw form %d refusal code" % index)
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_HUNTING), "HUNTING count"), 0,
		"three refused draws leave draw_count at 0")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_HUNTING), "HUNTING state after refusals"),
		TUTORIAL_SEEDED_STATES[Rng.STREAM_HUNTING], "the tombstone's state never advances")
	assert_true(rng.tombstone_is_intact(), "the tombstone is intact after refused draws")


func test_hunting_tombstone_rejects_noncanonical_loaded_values() -> void:
	"""REQ-SET-065: a saved tombstone that is not the untouched seed with a zero count is rejected."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var canonical: int = TUTORIAL_SEEDED_STATES[Rng.STREAM_HUNTING]
	var wrong_state: Rng.OpResult = rng.restore_stream(Rng.STREAM_HUNTING, canonical + 1, 0)
	assert_false(wrong_state.ok, "an advanced tombstone state is noncanonical")
	assert_equal(wrong_state.error, Rng.REFUSE_NONCANONICAL_TOMBSTONE, "wrong-state code")
	var wrong_count: Rng.OpResult = rng.restore_stream(Rng.STREAM_HUNTING, canonical, 1)
	assert_false(wrong_count.ok, "a nonzero tombstone draw count is noncanonical")
	assert_equal(wrong_count.error, Rng.REFUSE_NONCANONICAL_TOMBSTONE, "wrong-count code")
	var accepted: Rng.OpResult = rng.restore_stream(Rng.STREAM_HUNTING, canonical, 0)
	assert_true(accepted.ok, "the canonical pair loads (got %s)" % accepted.error)
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_HUNTING), "count"), 0,
		"the loaded tombstone still reports zero draws")
	assert_true(rng.tombstone_is_intact(), "the tombstone remains intact after a canonical load")


func test_hunting_tombstone_detects_a_seed_mismatch() -> void:
	"""A tombstone canonical under one world seed is refused under another."""
	var other: Rng = _seeded(TUTORIAL_SEED + 1)
	var foreign: Rng.OpResult = other.restore_stream(
		Rng.STREAM_HUNTING, TUTORIAL_SEEDED_STATES[Rng.STREAM_HUNTING], 0)
	assert_false(foreign.ok, "another world's tombstone value is noncanonical here")
	assert_equal(foreign.error, Rng.REFUSE_NONCANONICAL_TOMBSTONE, "foreign-tombstone code")
	assert_true(other.tombstone_is_intact(), "the refused load left this world's tombstone intact")


# --- save and restore -----------------------------------------------------------------------------------------

func test_restore_round_trips_state_and_count_and_reproduces_the_next_values() -> void:
	"""A saved (state, count) pair resumes the identical sequence in a different store."""
	var live: Rng = _seeded(TUTORIAL_SEED)
	for _index: int in range(7):
		assert_true(live.draw(Rng.STREAM_WEATHER).ok, "advance the live store")
	var saved_state: int = _value_of(live.state_of(Rng.STREAM_WEATHER), "saved state")
	var saved_count: int = _value_of(live.draw_count_of(Rng.STREAM_WEATHER), "saved count")
	assert_equal(saved_state, WEATHER_DRAWS[6], "the saved state is the seventh published draw")
	assert_equal(saved_count, 7, "seven draws were counted")
	var loaded: Rng = _seeded(TUTORIAL_SEED + 99)
	var restored: Rng.OpResult = loaded.restore_stream(Rng.STREAM_WEATHER, saved_state, saved_count)
	assert_true(restored.ok, "restore must succeed (got %s)" % restored.error)
	assert_equal(_value_of(loaded.draw_count_of(Rng.STREAM_WEATHER), "count"), 7,
		"the restored count is the saved one, not zero")
	for index: int in range(7, WEATHER_DRAWS.size()):
		assert_equal(_value_of(loaded.draw(Rng.STREAM_WEATHER), "resumed draw %d" % index),
			WEATHER_DRAWS[index], "resumed draw %d matches the uninterrupted run" % index)
	assert_equal(_value_of(loaded.draw_count_of(Rng.STREAM_WEATHER), "count"), 12,
		"counting continues from the restored value")


func test_restore_refuses_illegal_state_and_count() -> void:
	"""Zero state, a non-u32 state and a negative count are rejected, not clamped."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var zero: Rng.OpResult = rng.restore_stream(Rng.STREAM_MAP, 0, 5)
	assert_false(zero.ok, "a zero state is forbidden on load as well as at seeding")
	assert_equal(zero.error, Rng.REFUSE_ZERO_STATE, "zero-state load code")
	var oversized: Rng.OpResult = rng.restore_stream(Rng.STREAM_MAP, Rng.U32_COUNT, 5)
	assert_false(oversized.ok, "2^32 is not a u32 state")
	assert_equal(oversized.error, Rng.REFUSE_STATE_OUT_OF_RANGE, "oversized-state load code")
	var negative_state: Rng.OpResult = rng.restore_stream(Rng.STREAM_MAP, -1, 5)
	assert_false(negative_state.ok, "restore takes the unsigned form, never the stored signed one")
	var negative_count: Rng.OpResult = rng.restore_stream(Rng.STREAM_MAP, 1234, -1)
	assert_false(negative_count.ok, "a negative draw count is impossible")
	assert_equal(negative_count.error, Rng.REFUSE_NEGATIVE_DRAW_COUNT, "negative-count code")
	assert_equal(_value_of(rng.state_of(Rng.STREAM_MAP), "MAP state"),
		TUTORIAL_SEEDED_STATES[Rng.STREAM_MAP], "no refused load mutated the column")


func test_signed_storage_form_round_trips_across_the_sign_boundary() -> void:
	"""crowd §6.1's `s if s<2^31 else s-2^32` storage rule and its inverse, at the boundaries."""
	assert_equal(_value_of(Rng.to_stored_int32(2147483647), "below the boundary"), 2147483647,
		"the largest positive u32 that stores unchanged")
	assert_equal(_value_of(Rng.to_stored_int32(2147483648), "at the boundary"), -2147483648,
		"2^31 stores as int32 minimum")
	assert_equal(_value_of(Rng.to_stored_int32(4294967295), "top of the domain"), -1,
		"the largest u32 stores as -1")
	assert_equal(_value_of(Rng.from_stored_int32(-1), "recover -1"), 4294967295, "recovering -1")
	assert_equal(_value_of(Rng.from_stored_int32(-2147483648), "recover int32 min"), 2147483648,
		"recovering int32 minimum")
	assert_false(Rng.to_stored_int32(Rng.U32_COUNT).ok, "2^32 is outside the u32 domain")
	assert_false(Rng.to_stored_int32(-1).ok, "a negative is not a u32 state")
	assert_false(Rng.from_stored_int32(2147483648).ok, "2^31 is outside int32")


func test_stored_state_matches_the_conversion_of_the_live_state() -> void:
	"""What a save writes is exactly to_stored_int32() of what the store reports."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	for _index: int in range(7):
		assert_true(rng.draw(Rng.STREAM_WEATHER).ok, "advance into the negative storage half")
	var live: int = _value_of(rng.state_of(Rng.STREAM_WEATHER), "live state")
	var stored: int = _value_of(rng.stored_state_of(Rng.STREAM_WEATHER), "stored state")
	assert_equal(live, 3516105835, "the seventh WEATHER draw is above 2^31")
	assert_equal(stored, -778861461, "its signed int32 storage form")
	assert_equal(_value_of(Rng.to_stored_int32(live), "converted"), stored,
		"stored_state_of agrees with the published conversion")
	assert_equal(_value_of(Rng.from_stored_int32(stored), "recovered"), live,
		"the conversion inverts exactly")


# --- ARCH-RNG-002 range reduction: modulo, and its disclosed bias ---------------------------------------------------

func test_draw_below_is_exactly_the_modulo_of_the_raw_draw() -> void:
	"""Bounded selection is `raw % bound` on the same draw index, with no hidden extra draw."""
	var raw: Rng = _seeded(TUTORIAL_SEED)
	var bounded: Rng = _seeded(TUTORIAL_SEED)
	var bounds: Array[int] = [3, 21, 100, 1000, 7, 2, 1, 4294967296]
	for index: int in range(bounds.size()):
		var bound: int = bounds[index]
		var expected: int = _value_of(raw.draw(Rng.STREAM_QUALITY), "raw draw %d" % index) % bound
		assert_equal(_value_of(bounded.draw_below(Rng.STREAM_QUALITY, bound),
			"bounded draw %d" % index), expected,
			"draw_below with bound %d is the modulo of the same raw draw" % bound)
	assert_equal(_value_of(raw.draw_count_of(Rng.STREAM_QUALITY), "raw count"),
		_value_of(bounded.draw_count_of(Rng.STREAM_QUALITY), "bounded count"),
		"eight bounded selections cost exactly eight raw draws")


func test_draw_in_range_reproduces_the_quality_rule() -> void:
	"""ARCH-RNG-002's QUALITY row: `R=(draw mod 21)-10`, one roll, literal values."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	for index: int in range(QUALITY_R_VALUES.size()):
		assert_equal(_value_of(rng.draw_in_range(Rng.STREAM_QUALITY, -10, 10),
			"quality roll %d" % index), QUALITY_R_VALUES[index],
			"QUALITY R value %d" % index)
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_QUALITY), "count"),
		QUALITY_R_VALUES.size(), "one roll per batch, six batches")
	var single: Rng = _seeded(TUTORIAL_SEED)
	assert_equal(_value_of(single.draw_in_range(Rng.STREAM_MAP, 42, 42), "degenerate range"), 42,
		"a one-value range yields that value")
	assert_equal(_value_of(single.draw_count_of(Rng.STREAM_MAP), "count"), 1,
		"even a degenerate range consumes its one specified draw")


func test_small_bound_reduction_is_near_uniform_over_sixty_thousand_draws() -> void:
	"""Measured histogram for bound 6: exact deterministic counts, all within 5 sigma of N/6."""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(6)
	counts.fill(0)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for _index: int in range(60000):
		if not rng.draw_below_into(Rng.STREAM_MAP, 6, out):
			fail("draw_below_into refused mid-run: %s" % out.error)
			return
		counts[out.value] += 1
	var expected: Array[int] = [9922, 9983, 10062, 9994, 9942, 10097]
	for bucket: int in range(6):
		assert_equal(counts[bucket], expected[bucket], "bucket %d count" % bucket)
		assert_less_than(absi(counts[bucket] - 10000), 500.0,
			"bucket %d is within 5 sigma of 10000" % bucket)
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_MAP), "count"), 60000,
		"sixty thousand bounded selections cost sixty thousand draws")


func test_modulo_bias_is_present_and_exactly_the_disclosed_size() -> void:
	"""ARCH-RNG-002 mandates modulo, not rejection; measure the bias that choice actually causes.

	With bound 2863311531, residues below 2^32-2863311531=1431655765 are reachable from two u32
	values and the rest from one, so modulo puts ~2/3 of draws below that threshold where an
	unbiased reduction would put ~1/2. Observing ~13333 of 20000 rather than ~10000 both proves
	the specified bias exists and would catch a silent switch to rejection sampling.
	"""
	var rng: Rng = _seeded(TUTORIAL_SEED)
	var bound: int = 2863311531
	var threshold: int = Rng.U32_COUNT - bound
	var below: int = 0
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for _index: int in range(20000):
		if not rng.draw_below_into(Rng.STREAM_MAP, bound, out):
			fail("draw_below_into refused mid-run: %s" % out.error)
			return
		if out.value < threshold:
			below += 1
	assert_equal(threshold, 1431655765, "the doubly covered residue span")
	assert_equal(below, 13391, "the measured count is deterministic")
	assert_less_than(absi(below - 13333), 400.0, "modulo predicts about 13333 of 20000")
	assert_true(below > 12000, "an unbiased reduction would give about 10000, not %d" % below)
	assert_equal(_value_of(rng.draw_count_of(Rng.STREAM_MAP), "count"), 20000,
		"no rejection retry inflated the draw count")
