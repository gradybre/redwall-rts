extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 1 WORLD, the WorldRuntime block.
##
## THE TEST THAT MATTERS MOST IS NOT THE ROUND TRIP. It is the pair that pins G3's central
## distinction: changing only the host debt MUST change the saved bytes and MUST NOT change the
## ARCH-HASH-001 contribution. A codec that quietly hashed debt would round-trip perfectly,
## pass every length and bounds check, and still be wrong -- two identical authoritative worlds
## running on different hosts would disagree on their canonical state hash.
##
## Debt `2500001` is the ruling's own acceptance value: two owed ticks at TICK_COST 1000000 plus
## a remainder of 500001. It is checked as a whole, as owed ticks and as its remainder, because
## "restore exactly" fails in three different ways -- truncating to 2000000, collapsing to 2, or
## rounding the remainder away -- and only the last of those changes the field's magnitude much.
##
## INTEGER BOUNDARIES COME FROM ARITHMETIC, NOT LITERALS. `DEBT_MAX` is `INT64_MAX / 4`, derived
## from `sim_clock.gd::_is_overloaded()`'s `4*debt` comparison, and the tests probe `DEBT_MAX` and
## `DEBT_MAX + 1` by computing them rather than by typing 2305843009213693951.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const WorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

const WORLD_SEED: int = 20260911
const ACCEPTANCE_DEBT: int = 2500001

var _record: WorldRuntime.Record = null
var _encoded: WorldRuntime.EncodeResult = null


func before_each() -> void:
	"""Build a valid baseline Record and an EncodeResult for each test."""
	_record = WorldRuntime.Record.new()
	_record.completed_tick = 54321
	_record.world_seed = WORLD_SEED
	_record.rng_seeded = true
	_record.requested_speed = SimClockScript.SPEED_DOUBLE
	_record.pause_mask = SimClockScript.PLAYER
	_record.debt = ACCEPTANCE_DEBT
	for index: int in WorldRuntime.COUNTER_COUNT:
		_record.counters[index] = index + 1
	_encoded = WorldRuntime.EncodeResult.new()


func _bytes_of(record: WorldRuntime.Record) -> PackedByteArray:
	"""Encode a record and assert it succeeded, returning the block bytes."""
	var out: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	assert_true(WorldRuntime.encode_block(record, out), "encode_block succeeds: %s" % out.detail)
	return out.bytes


func _canonical_of(record: WorldRuntime.Record) -> PackedByteArray:
	"""Compute a record's ARCH-HASH-001 contribution and assert it succeeded."""
	var out: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	assert_true(WorldRuntime.canonical_bytes_of(record, out),
		"canonical_bytes_of succeeds: %s" % out.detail)
	return out.bytes


# --- layout --------------------------------------------------------------------------------------

func test_section_identity_and_layout_match_the_documented_table() -> void:
	"""Section 1, 80 bytes, hashed prefix of 24, six counters."""
	assert_equal(WorldRuntime.SECTION_ID, 1, "ARCH-SAVE-002 numbers WORLD as section 1")
	assert_equal(WorldRuntime.BLOCK_BYTES, 80, "the block is a fixed 80 bytes")
	assert_equal(WorldRuntime.HASHED_PREFIX_BYTES, 24, "the hashed fields are the first 24")
	assert_equal(WorldRuntime.OFFSET_DEBT, WorldRuntime.HASHED_PREFIX_BYTES,
		"debt begins exactly where the hashed prefix ends")
	assert_equal(WorldRuntime.COUNTER_COUNT, 6, "G3 names six recorded clock counters")
	assert_equal(WorldRuntime.COUNTER_NAMES.size(), 6, "and all six are named in order")


func test_the_six_counter_names_are_exactly_the_ones_g3_lists() -> void:
	"""Named in the ruling's printed order, so a reordered column is visible here."""
	assert_equal(WorldRuntime.COUNTER_NAMES[0], "_fallback_count", "counter 0")
	assert_equal(WorldRuntime.COUNTER_NAMES[1], "_diagnostic_pause_count", "counter 1")
	assert_equal(WorldRuntime.COUNTER_NAMES[2], "_acknowledged_catchup_resets", "counter 2")
	assert_equal(WorldRuntime.COUNTER_NAMES[3], "_acknowledged_ticks_discarded", "counter 3")
	assert_equal(WorldRuntime.COUNTER_NAMES[4], "_subtick_debt_discards", "counter 4")
	assert_equal(WorldRuntime.COUNTER_NAMES[5], "_day_boundaries_crossed", "counter 5")


func test_every_field_lands_at_its_documented_offset() -> void:
	"""Decode the raw buffer directly, so the docstring table is executable rather than prose."""
	var bytes: PackedByteArray = _bytes_of(_record)
	assert_equal(bytes.decode_s64(WorldRuntime.OFFSET_COMPLETED_TICK), 54321, "tick at 0")
	assert_equal(bytes.decode_s32(WorldRuntime.OFFSET_WORLD_SEED), WORLD_SEED, "seed at 8")
	assert_equal(bytes.decode_u8(WorldRuntime.OFFSET_RNG_SEEDED), 1, "seeded flag at 12")
	assert_equal(bytes.decode_s32(WorldRuntime.OFFSET_REQUESTED_SPEED), 2, "speed at 16")
	assert_equal(bytes.decode_s32(WorldRuntime.OFFSET_PAUSE_MASK), SimClockScript.PLAYER,
		"pause mask at 20")
	assert_equal(bytes.decode_s64(WorldRuntime.OFFSET_DEBT), ACCEPTANCE_DEBT, "debt at 24")
	assert_equal(bytes.decode_s64(WorldRuntime.OFFSET_DAY_BOUNDARIES_CROSSED), 6, "counter 5 at 72")


func test_the_reserved_bytes_are_written_as_zero() -> void:
	"""Three structural padding bytes, zero on write and refused nonzero on read."""
	var bytes: PackedByteArray = _bytes_of(_record)
	for offset: int in WorldRuntime.RESERVED_ZERO_BYTES:
		assert_equal(bytes.decode_u8(WorldRuntime.OFFSET_RESERVED_ZERO + offset), 0,
			"reserved byte %d is zero" % offset)


# --- round trip ------------------------------------------------------------------------------------

func test_every_field_round_trips_exactly() -> void:
	"""All thirteen fields, including the six that ARCH-HASH-001 excludes."""
	var bytes: PackedByteArray = _bytes_of(_record)
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(bytes, 0, back).is_ok(), "decode succeeds")
	assert_equal(back.completed_tick, _record.completed_tick, "tick")
	assert_equal(back.world_seed, _record.world_seed, "seed")
	assert_equal(back.rng_seeded, _record.rng_seeded, "seeded flag")
	assert_equal(back.requested_speed, _record.requested_speed, "requested speed")
	assert_equal(back.pause_mask, _record.pause_mask, "pause mask")
	assert_equal(back.debt, _record.debt, "debt")
	for index: int in WorldRuntime.COUNTER_COUNT:
		assert_equal(back.counters[index], _record.counters[index],
			"%s" % WorldRuntime.COUNTER_NAMES[index])


func test_debt_2500001_restores_exactly_as_two_owed_ticks_plus_a_remainder() -> void:
	"""G3's named acceptance value, checked three ways so no partial restore can pass."""
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "decode succeeds")
	assert_equal(back.debt, ACCEPTANCE_DEBT, "debt restores exactly, not scaled or clamped")
	assert_equal(back.owed_ticks(), 2, "two whole ticks are still owed")
	assert_equal(back.subtick_debt(), 500001, "and the sub-tick remainder is not rounded away")
	assert_equal(SimClockScript.TICK_COST * back.owed_ticks() + back.subtick_debt(),
		ACCEPTANCE_DEBT, "the two parts reconstruct the whole")


func test_a_zero_debt_and_a_zero_pause_mask_round_trip_as_real_values() -> void:
	"""Zero is a legitimate state for both, never an absence marker."""
	_record.debt = 0
	_record.pause_mask = 0
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "decode succeeds")
	assert_equal(back.debt, 0, "zero debt survives")
	assert_equal(back.pause_mask, 0, "an unpaused world survives")
	assert_equal(back.owed_ticks(), 0, "and owes nothing")


# --- G3: persistence and digest membership are separate dimensions --------------------------------

func test_changing_only_debt_changes_the_saved_bytes() -> void:
	"""Debt is category 1: genuinely saved, and covered by the section CRC and body SHA-256."""
	var baseline: PackedByteArray = _bytes_of(_record)
	_record.debt = ACCEPTANCE_DEBT + 1
	var altered: PackedByteArray = _bytes_of(_record)
	assert_true(altered != baseline, "a one-unit debt change moves the protected save bytes")
	assert_equal(altered.size(), baseline.size(), "without changing the block length")


func test_changing_only_debt_does_not_change_the_arch_hash_001_contribution() -> void:
	"""The other half of G3, and the reason this module has two encoders instead of one."""
	var baseline: PackedByteArray = _canonical_of(_record)
	_record.debt = ACCEPTANCE_DEBT + 1
	assert_equal(_canonical_of(_record), baseline, "debt+1 leaves the canonical bytes identical")
	_record.debt = 0
	assert_equal(_canonical_of(_record), baseline, "and so does zero debt")
	_record.debt = WorldRuntime.DEBT_MAX
	assert_equal(_canonical_of(_record), baseline, "and so does the largest legal debt")


func test_changing_any_of_the_six_counters_leaves_the_contribution_unchanged() -> void:
	"""All six individually, so a loop that stops one short cannot hide."""
	var baseline: PackedByteArray = _canonical_of(_record)
	for index: int in WorldRuntime.COUNTER_COUNT:
		var original: int = _record.counters[index]
		_record.counters[index] = original + 1000
		assert_equal(_canonical_of(_record), baseline,
			"%s is excluded from ARCH-HASH-001" % WorldRuntime.COUNTER_NAMES[index])
		assert_true(_bytes_of(_record) != _bytes_of_baseline_counters(index, original),
			"%s still changes the saved bytes" % WorldRuntime.COUNTER_NAMES[index])
		_record.counters[index] = original


func _bytes_of_baseline_counters(index: int, original: int) -> PackedByteArray:
	"""Encode the record with counter `index` put back to `original`, for a bytes comparison."""
	var restored: WorldRuntime.Record = WorldRuntime.Record.new()
	restored.copy_from(_record)
	restored.counters[index] = original
	return _bytes_of(restored)


func test_changing_requested_speed_does_change_canonical_state() -> void:
	"""G3: requested speed is included; ARCH-HASH-001's exclusion list does not name it."""
	var baseline: PackedByteArray = _canonical_of(_record)
	for speed: int in SimClockScript.SELECTABLE_SPEEDS:
		_record.requested_speed = speed
		if speed == SimClockScript.SPEED_DOUBLE:
			continue
		assert_true(_canonical_of(_record) != baseline,
			"speed %d gives a different canonical contribution" % speed)


func test_changing_the_pause_mask_the_tick_or_the_seed_changes_canonical_state() -> void:
	"""The other three included fields, each on its own."""
	var baseline: PackedByteArray = _canonical_of(_record)
	_record.pause_mask = SimClockScript.CRITICAL
	assert_true(_canonical_of(_record) != baseline, "a CRITICAL hold is canonical state")
	_record.pause_mask = SimClockScript.PLAYER
	_record.completed_tick += 1
	assert_true(_canonical_of(_record) != baseline, "one more completed tick is canonical state")
	_record.completed_tick -= 1
	_record.world_seed += 1
	assert_true(_canonical_of(_record) != baseline, "a different world seed is canonical state")


func test_the_contribution_is_shorter_than_the_block_and_is_not_its_prefix_bytes() -> void:
	"""21 state bytes, not the 24-byte on-disk prefix: the three reserved bytes are structural."""
	assert_equal(WorldRuntime.CANONICAL_BYTES, 21, "8 + 4 + 1 + 4 + 4")
	var canonical: PackedByteArray = _canonical_of(_record)
	assert_equal(canonical.size(), WorldRuntime.CANONICAL_BYTES, "and that is its length")
	assert_true(canonical != _bytes_of(_record).slice(0, WorldRuntime.HASHED_PREFIX_BYTES),
		"so it is not a byte image of the block's prefix")


# --- validation: reject, never saturate ---------------------------------------------------------

func test_a_negative_completed_tick_is_refused() -> void:
	"""A tick is a count of completed ticks; negative is corruption and never a sentinel."""
	var bytes: PackedByteArray = _bytes_of(_record)
	bytes.encode_s64(WorldRuntime.OFFSET_COMPLETED_TICK, -1)
	assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
		WorldRuntime.REFUSE_NEGATIVE_TICK, "-1 ticks refuses")


func test_tick_zero_is_accepted_because_it_is_a_real_boundary() -> void:
	"""Tick 0 is 06:00 of year 1 spring day 1, so it must not be caught by a `<= 0` slip."""
	_record.completed_tick = 0
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "tick 0 decodes")
	assert_equal(back.completed_tick, 0, "as zero")


func test_the_completed_tick_ceiling_is_the_calendar_offset_boundary() -> void:
	"""`(tick + 4500)` must not overflow, so the ceiling is INT64_MAX - 4500 exactly."""
	assert_equal(WorldRuntime.COMPLETED_TICK_MAX,
		SaveCodec.INT64_MAX - SimClockScript.CALENDAR_OFFSET_TICKS, "the bound is derived")
	_record.completed_tick = WorldRuntime.COMPLETED_TICK_MAX
	assert_true(WorldRuntime.record_refusal(_record).is_ok(), "the ceiling itself is accepted")
	_record.completed_tick = WorldRuntime.COMPLETED_TICK_MAX + 1
	assert_equal(WorldRuntime.record_refusal(_record).code,
		WorldRuntime.REFUSE_TICK_UNREPRESENTABLE, "one past it refuses")


func test_the_debt_ceiling_is_the_overload_comparison_boundary() -> void:
	"""`4*debt` must be representable, so the ceiling is INT64_MAX / 4 exactly. Refuse, not clamp."""
	assert_equal(WorldRuntime.DEBT_MAX,
		SaveCodec.INT64_MAX / SimClockScript.OVERLOAD_NUMERATOR, "the bound is derived")
	_record.debt = WorldRuntime.DEBT_MAX
	assert_true(WorldRuntime.record_refusal(_record).is_ok(), "the ceiling itself is accepted")
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "and round trips")
	assert_equal(back.debt, WorldRuntime.DEBT_MAX, "unclamped")
	_record.debt = WorldRuntime.DEBT_MAX + 1
	assert_equal(WorldRuntime.record_refusal(_record).code,
		WorldRuntime.REFUSE_DEBT_UNREPRESENTABLE, "one past it refuses")


func test_an_unrepresentable_debt_rejects_on_decode_rather_than_saturating() -> void:
	"""G3: an invalid value rejects, never saturates. The record must come back untouched."""
	var bytes: PackedByteArray = _bytes_of(_record)
	bytes.encode_s64(WorldRuntime.OFFSET_DEBT, SaveCodec.INT64_MAX)
	var target: WorldRuntime.Record = WorldRuntime.Record.new()
	target.debt = 77
	assert_equal(WorldRuntime.decode_into(bytes, 0, target).code,
		WorldRuntime.REFUSE_DEBT_UNREPRESENTABLE, "INT64_MAX debt refuses")
	assert_equal(target.debt, 77, "and the caller's record is untouched, not saturated")


func test_a_negative_debt_is_refused() -> void:
	"""Debt is nonnegative I64 by G3's own row; a negative is never a valid host continuation."""
	var bytes: PackedByteArray = _bytes_of(_record)
	bytes.encode_s64(WorldRuntime.OFFSET_DEBT, -1)
	assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
		WorldRuntime.REFUSE_NEGATIVE_DEBT, "-1 debt refuses")


func test_each_of_the_six_counters_refuses_a_negative_value_individually() -> void:
	"""All six offsets, so a loop bound that misses the last counter is caught."""
	var offsets: PackedInt64Array = PackedInt64Array([WorldRuntime.OFFSET_FALLBACK_COUNT,
		WorldRuntime.OFFSET_DIAGNOSTIC_PAUSE_COUNT,
		WorldRuntime.OFFSET_ACKNOWLEDGED_CATCHUP_RESETS,
		WorldRuntime.OFFSET_ACKNOWLEDGED_TICKS_DISCARDED,
		WorldRuntime.OFFSET_SUBTICK_DEBT_DISCARDS, WorldRuntime.OFFSET_DAY_BOUNDARIES_CROSSED])
	var clean: PackedByteArray = _bytes_of(_record)
	for index: int in offsets.size():
		var bytes: PackedByteArray = clean.duplicate()
		bytes.encode_s64(offsets[index], -1)
		assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
			WorldRuntime.REFUSE_NEGATIVE_COUNTER,
			"%s refuses -1" % WorldRuntime.COUNTER_NAMES[index])


func test_speed_three_and_speed_zero_are_both_refused() -> void:
	"""There is no 3x, and SPEED_PAUSED is not requestable -- pause is the reason mask's job."""
	for illegal: int in [0, 3, 5, -1, SaveCodec.INT32_MAX]:
		var bytes: PackedByteArray = _bytes_of(_record)
		bytes.encode_s32(WorldRuntime.OFFSET_REQUESTED_SPEED, illegal)
		assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
			WorldRuntime.REFUSE_SPEED, "requested speed %d refuses" % illegal)


func test_all_three_selectable_speeds_are_accepted() -> void:
	"""1, 2 and 4 must all pass, so a bounds check cannot be tightened into rejecting a real one."""
	for speed: int in SimClockScript.SELECTABLE_SPEEDS:
		_record.requested_speed = speed
		var back: WorldRuntime.Record = WorldRuntime.Record.new()
		assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(),
			"speed %d decodes" % speed)
		assert_equal(back.requested_speed, speed, "as itself")


func test_an_unknown_pause_bit_is_refused_rather_than_masked_away() -> void:
	"""Bit 5 is not a reason sim_clock.gd knows; silently dropping it would lose a real hold."""
	var bytes: PackedByteArray = _bytes_of(_record)
	bytes.encode_s32(WorldRuntime.OFFSET_PAUSE_MASK, WorldRuntime.KNOWN_PAUSE_BITS + 1)
	assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
		WorldRuntime.REFUSE_PAUSE_MASK, "an unknown bit refuses")


func test_the_full_known_pause_mask_is_accepted_and_one_past_it_is_not() -> void:
	"""The exact boundary: 31 is every known reason, 32 is the first unknown bit."""
	assert_equal(WorldRuntime.KNOWN_PAUSE_BITS, 31, "PLAYER|MENU|CRITICAL|VICTORY|LOAD")
	_record.pause_mask = WorldRuntime.KNOWN_PAUSE_BITS
	assert_true(WorldRuntime.record_refusal(_record).is_ok(), "all five reasons at once is valid")
	_record.pause_mask = WorldRuntime.KNOWN_PAUSE_BITS + 1
	assert_equal(WorldRuntime.record_refusal(_record).code,
		WorldRuntime.REFUSE_PAUSE_MASK, "one bit past refuses")


func test_a_negative_pause_mask_is_refused() -> void:
	"""An i32 with its sign bit set is not a giant mask; it is corruption."""
	var bytes: PackedByteArray = _bytes_of(_record)
	bytes.encode_s32(WorldRuntime.OFFSET_PAUSE_MASK, SaveCodec.INT32_MIN)
	assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
		WorldRuntime.REFUSE_PAUSE_MASK, "INT32_MIN refuses")


func test_a_seeded_flag_other_than_zero_or_one_is_refused() -> void:
	"""A bool byte is 0 or 1, never "nonzero means true"."""
	for illegal: int in [2, 255]:
		var bytes: PackedByteArray = _bytes_of(_record)
		bytes.encode_u8(WorldRuntime.OFFSET_RNG_SEEDED, illegal)
		assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
			WorldRuntime.REFUSE_SEEDED_FLAG, "seeded byte %d refuses" % illegal)


func test_both_legal_seeded_flag_values_survive() -> void:
	"""0 and 1 are both real states; an unseeded world is savable."""
	for seeded: bool in [true, false]:
		_record.rng_seeded = seeded
		var back: WorldRuntime.Record = WorldRuntime.Record.new()
		assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "decodes")
		assert_equal(back.rng_seeded, seeded, "seeded flag %s survives" % seeded)


func test_nonzero_reserved_padding_is_refused() -> void:
	"""ARCH-SAVE-005's reserved-zero rule, reused from save_codec.gd rather than reimplemented."""
	for offset: int in WorldRuntime.RESERVED_ZERO_BYTES:
		var bytes: PackedByteArray = _bytes_of(_record)
		bytes.encode_u8(WorldRuntime.OFFSET_RESERVED_ZERO + offset, 1)
		assert_equal(WorldRuntime.decode_into(bytes, 0, _record).code,
			WorldRuntime.REFUSE_RESERVED_NONZERO, "reserved byte %d refuses nonzero" % offset)


func test_the_world_seed_spans_the_whole_signed_int32_range() -> void:
	"""Built from bit conversions: 0x80000000 is POSITIVE in GDScript, INT32_MIN as an int32."""
	assert_equal(SaveCodec.u32_bits_to_int32(SaveCodec.UINT32_SIGN_BIT), SaveCodec.INT32_MIN,
		"the boundary is constructed, not typed")
	for seed: int in [SaveCodec.INT32_MIN, -1, 0, 1, SaveCodec.INT32_MAX]:
		_record.world_seed = seed
		var back: WorldRuntime.Record = WorldRuntime.Record.new()
		assert_true(WorldRuntime.decode_into(_bytes_of(_record), 0, back).is_ok(), "decodes")
		assert_equal(back.world_seed, seed, "seed %d survives as itself" % seed)


func test_a_world_seed_outside_int32_refuses_at_encode_rather_than_truncating() -> void:
	"""save_codec.gd range-checks before writing, so an oversized seed never loses its high bits."""
	_record.world_seed = SaveCodec.INT32_MAX + 1
	assert_false(WorldRuntime.encode_block(_record, _encoded), "an out-of-range seed refuses")
	assert_equal(_encoded.bytes.size(), 0, "and produces no bytes")


# --- truncation and offsets -------------------------------------------------------------------------

func test_a_truncated_block_refuses_and_leaves_the_record_untouched() -> void:
	"""79 bytes must refuse before it reads or writes anything (decision 0059)."""
	var bytes: PackedByteArray = _bytes_of(_record).slice(0, WorldRuntime.BLOCK_BYTES - 1)
	var target: WorldRuntime.Record = WorldRuntime.Record.new()
	target.completed_tick = 4242
	target.debt = 99
	assert_equal(WorldRuntime.decode_into(bytes, 0, target).code,
		WorldRuntime.REFUSE_TRUNCATED, "79 bytes refuses")
	assert_equal(target.completed_tick, 4242, "the caller's record is byte-identical")
	assert_equal(target.debt, 99, "including the excluded metadata")


func test_the_block_decodes_at_a_nonzero_offset_and_refuses_one_past_the_last_legal_one() -> void:
	"""Section ranges are not required to be contiguous, so the offset is always explicit."""
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(16)
	padded.append_array(_bytes_of(_record))
	assert_true(WorldRuntime.decode_into(padded, 16, _record).is_ok(), "offset 16 decodes")
	assert_equal(WorldRuntime.decode_into(padded, 17, _record).code,
		WorldRuntime.REFUSE_TRUNCATED, "offset 17 runs one byte past the end")


func test_the_extent_gate_is_exact_at_the_last_legal_offset() -> void:
	"""Called directly, because save_codec.gd's Reader is also bounded and would mask a slack gate."""
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(16)
	padded.append_array(_bytes_of(_record))
	var last_legal: int = padded.size() - WorldRuntime.BLOCK_BYTES
	assert_equal(last_legal, 16, "a 96-byte buffer fits one 80-byte block at offset 16")
	assert_true(WorldRuntime.extent_refusal(padded, last_legal).is_ok(), "offset 16 fits")
	assert_equal(WorldRuntime.extent_refusal(padded, last_legal + 1).code,
		WorldRuntime.REFUSE_TRUNCATED, "offset 17 does not")
	assert_equal(WorldRuntime.extent_refusal(padded, padded.size()).code,
		WorldRuntime.REFUSE_TRUNCATED, "and neither does the end of the buffer")
	assert_equal(WorldRuntime.extent_refusal(PackedByteArray(), 0).code,
		WorldRuntime.REFUSE_TRUNCATED, "an empty buffer holds no block")


func test_the_extent_gate_refuses_before_the_reader_is_built() -> void:
	"""The refusal detail names the block's own requirement, not the Reader's leftover count."""
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(16)
	padded.append_array(_bytes_of(_record))
	var refusal: SaveHeader.Refusal = WorldRuntime.decode_into(padded, 17, _record)
	assert_true(refusal.detail.contains("the WorldRuntime block needs %d bytes"
		% WorldRuntime.BLOCK_BYTES), "the extent gate reported it: %s" % refusal.detail)


func test_a_negative_offset_refuses_by_name() -> void:
	"""A negative offset is its own refusal, never a wrapped index."""
	assert_equal(WorldRuntime.decode_into(_bytes_of(_record), -1, _record).code,
		WorldRuntime.REFUSE_NEGATIVE_OFFSET, "offset -1 refuses")


# --- the header tick cross-check ---------------------------------------------------------------

func test_the_block_tick_must_equal_the_validated_header_tick() -> void:
	"""G3: the completed tick is section 1 PLUS the header's, and the two must agree."""
	assert_true(WorldRuntime.header_tick_refusal(_record, 54321).is_ok(), "agreement passes")
	assert_equal(WorldRuntime.header_tick_refusal(_record, 54322).code,
		WorldRuntime.REFUSE_HEADER_TICK_MISMATCH, "one tick apart refuses")
	assert_equal(WorldRuntime.header_tick_refusal(_record, 0).code,
		WorldRuntime.REFUSE_HEADER_TICK_MISMATCH, "a zeroed header tick refuses")


func test_a_real_header_carrying_the_same_tick_agrees() -> void:
	"""Wired against save_header.gd's own Header, not a hand-built integer."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	header.completed_tick = _record.completed_tick
	assert_true(WorldRuntime.header_tick_refusal(_record, header.completed_tick).is_ok(),
		"the header's field is the one compared")


# --- the transient LOAD guard --------------------------------------------------------------------

func test_adding_and_removing_the_load_guard_preserves_every_other_hold() -> void:
	"""G3: the guard must not erase PLAYER, MENU, CRITICAL or VICTORY."""
	var logical: int = SimClockScript.PLAYER | SimClockScript.MENU | SimClockScript.CRITICAL \
		| SimClockScript.VICTORY
	var guarded: int = WorldRuntime.pause_mask_with_load(logical)
	assert_equal(guarded, logical | SimClockScript.LOAD, "LOAD is added")
	assert_equal(WorldRuntime.pause_mask_without_load(guarded), logical,
		"and removing it restores exactly the four authored holds")


func test_removing_the_load_guard_from_a_mask_that_never_had_it_is_a_no_op() -> void:
	"""Idempotence, so a double release cannot clear a real reason."""
	var logical: int = SimClockScript.CRITICAL
	assert_equal(WorldRuntime.pause_mask_without_load(logical), logical, "unchanged")
	assert_equal(WorldRuntime.pause_mask_without_load(
		WorldRuntime.pause_mask_without_load(logical)), logical, "twice is still unchanged")


func test_the_saved_logical_mask_never_carries_load_into_the_digest_by_accident() -> void:
	"""A save taken under a LOAD guard and one taken without it differ; that is intended and visible."""
	_record.pause_mask = SimClockScript.PLAYER
	var plain: PackedByteArray = _canonical_of(_record)
	_record.pause_mask = WorldRuntime.pause_mask_with_load(SimClockScript.PLAYER)
	assert_true(_canonical_of(_record) != plain,
		"LOAD is part of the mask, so 09.3 must strip it before saving rather than hope")


# --- capture from a live clock ----------------------------------------------------------------------

func test_capture_reads_a_live_clock_and_agrees_with_it() -> void:
	"""The read half works today; the write half is BLOCKER W1."""
	var clock: SimClockScript = SimClockScript.new()
	clock.set_speed(SimClockScript.SPEED_QUADRUPLE)
	var captured: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.capture_into(clock, WORLD_SEED, true, captured).is_ok(), "captured")
	assert_equal(captured.requested_speed, SimClockScript.SPEED_QUADRUPLE, "speed read back")
	assert_equal(captured.pause_mask, clock.pause_mask(), "mask read back")
	assert_equal(captured.completed_tick, clock.completed_tick(), "tick read back")
	assert_true(WorldRuntime.agrees_with_clock(captured, clock, WORLD_SEED, true).is_ok(),
		"and the verifier agrees")


func test_capture_survives_a_round_trip_through_the_block_bytes() -> void:
	"""A live clock advanced past a day boundary, saved and decoded, still matches itself."""
	var clock: SimClockScript = SimClockScript.new()
	clock.set_pause(SimClockScript.PLAYER, false)
	clock.advance(200000)
	var captured: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.capture_into(clock, WORLD_SEED, true, captured).is_ok(), "captured")
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(_bytes_of(captured), 0, back).is_ok(), "decoded")
	assert_true(WorldRuntime.agrees_with_clock(back, clock, WORLD_SEED, true).is_ok(),
		"the decoded record still describes the live clock exactly")
	assert_equal(back.completed_tick, clock.completed_tick(), "including its completed tick")
	assert_equal(back.debt, clock.debt(), "and its retained sub-tick debt")


func test_the_verifier_names_the_first_field_that_disagrees() -> void:
	"""A divergence must localise, not just say no -- that is ARCH-HASH-002's discipline."""
	var clock: SimClockScript = SimClockScript.new()
	var captured: WorldRuntime.Record = WorldRuntime.Record.new()
	WorldRuntime.capture_into(clock, WORLD_SEED, true, captured)
	captured.debt = ACCEPTANCE_DEBT
	var refusal: SaveHeader.Refusal = WorldRuntime.agrees_with_clock(captured, clock,
		WORLD_SEED, true)
	assert_equal(refusal.code, WorldRuntime.REFUSE_CLOCK_DISAGREES, "the verifier refuses")
	assert_true(refusal.detail.contains("debt"), "and names debt: %s" % refusal.detail)


func test_a_paused_clock_accumulates_no_debt_so_a_paused_load_charges_nothing() -> void:
	"""G3's acceptance: a paused load adds no wall-time debt. Proven against the clock itself."""
	var clock: SimClockScript = SimClockScript.new()
	assert_true(clock.is_paused(), "a fresh clock holds the PLAYER pause")
	clock.advance(5000000)
	var captured: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.capture_into(clock, WORLD_SEED, true, captured).is_ok(), "captured")
	assert_equal(captured.debt, 0, "five real seconds while paused charged no debt")
	assert_equal(captured.completed_tick, 0, "and ran no ticks")


# --- module hygiene -------------------------------------------------------------------------------

func test_the_module_declares_no_float_path() -> void:
	"""ARCH-AUTH-002: a save codec must never introduce a float path."""
	var path: String = "res://scripts/core/save_section_world_runtime.gd"
	var source: String = FileAccess.get_file_as_string(path)
	assert_true(source.length() > 0, "the module source was read")
	assert_false(source.contains(": float"), "no float-typed declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")
