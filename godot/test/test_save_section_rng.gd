extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 10 RNG.
##
## Round-trip is necessary and nowhere near sufficient. The failure this section exists to
## prevent is a stream resumed at the WRONG OFFSET, which produces values that are still
## perfectly plausible and diverges silently on the next roll. So the tests below check the draw
## count as hard as the state, prove that a stream restored one draw early actually produces a
## different number, and prove that the zero state -- the one value xorshift32 forbids, and the
## value an unseeded column is filled with -- is refused rather than accepted.
##
## INTEGER BOUNDARIES COME FROM BIT CONVERSIONS, NOT LITERALS. `0x80000000` is a POSITIVE
## GDScript int and `-2147483648` as an int32. Writing `-2147483648` where `0x80000000` was meant
## is how a boundary test ends up testing the wrong boundary, so every high-state case here is
## built by calling `SaveCodec.u32_bits_to_int32()` / `int32_bits_to_u32()` and asserting the
## pair agrees, rather than by typing the signed literal.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveSectionRng := preload("res://scripts/core/save_section_rng.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const WORLD_SEED: int = 20260911

var _store: RngScript = null
var _record: SaveSectionRng.Record = null
var _encoded: SaveSectionRng.EncodeResult = null


func before_each() -> void:
	"""Build a freshly seeded store, a Record and an EncodeResult for each test."""
	_store = RngScript.new()
	_store.seed_world(WORLD_SEED)
	_record = SaveSectionRng.Record.new()
	_encoded = SaveSectionRng.EncodeResult.new()


func _advance(stream_id: int, draws: int) -> void:
	"""Take `draws` draws from a stream so its state and count both move off the seed."""
	for _index: int in draws:
		_store.draw(stream_id)


func _payload_of(store: RngScript) -> PackedByteArray:
	"""Encode a store's section 10 and assert it succeeded, returning the payload bytes."""
	var out: SaveSectionRng.EncodeResult = SaveSectionRng.EncodeResult.new()
	assert_true(SaveSectionRng.encode_store(store, out), "encode_store succeeds: %s" % out.detail)
	return out.bytes


# --- layout --------------------------------------------------------------------------------------

func test_section_identity_and_layout_match_arch_save_002() -> void:
	"""Section 10, nine streams, 36 state bytes then 72 draw-count bytes, 108 total."""
	assert_equal(SaveSectionRng.SECTION_ID, 10, "ARCH-SAVE-002 numbers RNG as section 10")
	assert_equal(SaveSectionRng.STREAM_COUNT, RngScript.STREAM_COUNT,
		"the codec's stream count is rng.gd's, not a second copy")
	assert_equal(SaveSectionRng.STATE_OFFSET, 0, "states start the payload")
	assert_equal(SaveSectionRng.DRAW_COUNT_OFFSET, 36, "draw counts follow nine i32 states")
	assert_equal(SaveSectionRng.SECTION_BYTES, 108, "9*4 + 9*8")


func test_encoded_payload_is_exactly_the_fixed_length() -> void:
	"""The length is the validation: there is no count field to disagree with the data."""
	var bytes: PackedByteArray = _payload_of(_store)
	assert_equal(bytes.size(), SaveSectionRng.SECTION_BYTES, "payload is 108 bytes")


func test_payload_bytes_are_little_endian_at_the_documented_offsets() -> void:
	"""Read the raw buffer back with decode_* to prove the layout is what the docstring claims."""
	_advance(RngScript.STREAM_QUALITY, 3)
	var bytes: PackedByteArray = _payload_of(_store)
	var quality: int = RngScript.STREAM_QUALITY
	var state_at: int = bytes.decode_s32(SaveSectionRng.STATE_OFFSET + 4 * quality)
	var count_at: int = bytes.decode_s64(SaveSectionRng.DRAW_COUNT_OFFSET + 8 * quality)
	assert_equal(state_at, _store.stored_state_of(quality).value,
		"the i32 at 4*stream_id is that stream's stored state")
	assert_equal(count_at, 3, "the i64 at 36+8*stream_id is that stream's draw count")


# --- round trip -----------------------------------------------------------------------------------

func test_every_stream_restores_its_exact_state_and_draw_count() -> void:
	"""Nine streams advanced by nine different amounts all come back exactly."""
	for stream_id: int in RngScript.STREAM_COUNT:
		if RngScript.is_retired(stream_id):
			continue
		_advance(stream_id, stream_id + 1)
	var bytes: PackedByteArray = _payload_of(_store)
	var loaded: RngScript = RngScript.new()
	loaded.seed_world(WORLD_SEED)
	assert_true(SaveSectionRng.decode_into(bytes, 0, _record).is_ok(), "decode succeeds")
	assert_true(SaveSectionRng.apply(_record, loaded).is_ok(), "apply succeeds")
	for stream_id: int in RngScript.STREAM_COUNT:
		assert_equal(loaded.state_of(stream_id).value, _store.state_of(stream_id).value,
			"stream %d state restored" % stream_id)
		assert_equal(loaded.draw_count_of(stream_id).value,
			_store.draw_count_of(stream_id).value, "stream %d draw count restored" % stream_id)


func test_a_restored_stream_continues_the_original_sequence() -> void:
	"""The real acceptance: the next 20 draws after a restore equal the next 20 without one."""
	_advance(RngScript.STREAM_WEATHER, 7)
	var bytes: PackedByteArray = _payload_of(_store)
	var loaded: RngScript = RngScript.new()
	loaded.seed_world(WORLD_SEED)
	SaveSectionRng.decode_into(bytes, 0, _record)
	SaveSectionRng.apply(_record, loaded)
	for index: int in 20:
		assert_equal(loaded.draw(RngScript.STREAM_WEATHER).value,
			_store.draw(RngScript.STREAM_WEATHER).value,
			"draw %d after restore matches the uninterrupted run" % index)


func test_a_stream_resumed_one_draw_early_diverges_which_is_why_the_count_is_saved() -> void:
	"""Prove the silent failure is real: re-seeding instead of restoring gives different numbers."""
	_advance(RngScript.STREAM_SOCIAL, 5)
	var reseeded: RngScript = RngScript.new()
	reseeded.seed_world(WORLD_SEED)
	assert_true(reseeded.state_of(RngScript.STREAM_SOCIAL).value
		!= _store.state_of(RngScript.STREAM_SOCIAL).value,
		"a reseeded stream is NOT at the saved state")
	assert_true(reseeded.draw(RngScript.STREAM_SOCIAL).value
		!= _store.draw(RngScript.STREAM_SOCIAL).value,
		"and its very next draw already differs")


func test_the_draw_count_alone_can_differ_and_is_still_caught() -> void:
	"""Two records with identical states but different counts do not encode the same bytes."""
	var bytes: PackedByteArray = _payload_of(_store)
	SaveSectionRng.decode_into(bytes, 0, _record)
	_record.draw_counts[RngScript.STREAM_MAP] = 41
	assert_true(SaveSectionRng.encode_record(_record, _encoded), "the altered record encodes")
	assert_true(_encoded.bytes != bytes, "changing only a draw count changes the payload")
	assert_equal(_encoded.bytes.size(), bytes.size(), "and does not change its length")


# --- the zero state ---------------------------------------------------------------------------------

func test_a_zero_state_is_refused_on_decode() -> void:
	"""0 is the UNSEEDED value and exactly what xorshift32 forbids, so it is never a live state."""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s32(SaveSectionRng.STATE_OFFSET + 4 * RngScript.STREAM_FORAGE, 0)
	var refusal: SaveHeader.Refusal = SaveSectionRng.decode_into(bytes, 0, _record)
	assert_equal(refusal.code, SaveSectionRng.REFUSE_ZERO_STATE, "a zero state is refused")


func test_every_single_stream_slot_rejects_a_zero_state_individually() -> void:
	"""All nine positions, so a bounds slip that skips one slot cannot hide."""
	var clean: PackedByteArray = _payload_of(_store)
	for stream_id: int in RngScript.STREAM_COUNT:
		var bytes: PackedByteArray = clean.duplicate()
		bytes.encode_s32(SaveSectionRng.STATE_OFFSET + 4 * stream_id, 0)
		assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
			SaveSectionRng.REFUSE_ZERO_STATE, "stream %d zero state refused" % stream_id)


func test_an_all_zero_payload_is_refused_rather_than_read_as_an_unseeded_world() -> void:
	"""108 zero bytes is a well-formed length and a completely invalid section."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveSectionRng.SECTION_BYTES)
	assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
		SaveSectionRng.REFUSE_ZERO_STATE, "an all-zero section 10 is refused")


func test_capture_refuses_an_unseeded_store_instead_of_writing_nine_zeros() -> void:
	"""An unseeded store has no legal section 10; it must refuse, not emit a zero payload."""
	var fresh: RngScript = RngScript.new()
	var refusal: SaveHeader.Refusal = SaveSectionRng.capture_into(fresh, _record)
	assert_equal(refusal.code, SaveSectionRng.REFUSE_STORE_UNSEEDED, "unseeded capture refused")
	assert_false(SaveSectionRng.encode_store(fresh, _encoded), "and encode_store refuses too")
	assert_equal(_encoded.bytes.size(), 0, "a refused encode produces no bytes at all")


# --- signed / unsigned boundaries -------------------------------------------------------------------

func test_the_high_u32_boundary_round_trips_through_the_signed_storage_form() -> void:
	"""0x80000000 is POSITIVE in GDScript and -2147483648 as an int32. Build it, do not type it."""
	var sign_bit: int = SaveCodec.UINT32_SIGN_BIT
	assert_true(sign_bit > 0, "0x80000000 is a positive GDScript int")
	assert_equal(SaveCodec.u32_bits_to_int32(sign_bit), SaveCodec.INT32_MIN,
		"and is INT32_MIN as an int32")
	assert_equal(SaveCodec.int32_bits_to_u32(SaveCodec.INT32_MIN), sign_bit, "inverse holds")
	var stored: IntMathScript.IntResult = RngScript.to_stored_int32(sign_bit)
	assert_true(stored.ok, "rng.gd stores 0x80000000")
	assert_equal(stored.value, SaveCodec.u32_bits_to_int32(sign_bit),
		"rng.gd and save_codec.gd agree on the signed spelling")


func test_states_across_the_sign_boundary_survive_encode_and_decode() -> void:
	"""Four u32 states either side of 0x80000000 all come back as the same unsigned values."""
	var probes: PackedInt64Array = PackedInt64Array([SaveCodec.UINT32_SIGN_BIT - 1,
		SaveCodec.UINT32_SIGN_BIT, SaveCodec.UINT32_SIGN_BIT + 1, SaveCodec.UINT32_MAX])
	for index: int in probes.size():
		_record.states[index] = SaveCodec.u32_bits_to_int32(probes[index])
	for index: int in range(probes.size(), RngScript.STREAM_COUNT):
		_record.states[index] = 1
	assert_true(SaveSectionRng.encode_record(_record, _encoded), "boundary states encode")
	var back: SaveSectionRng.Record = SaveSectionRng.Record.new()
	assert_true(SaveSectionRng.decode_into(_encoded.bytes, 0, back).is_ok(), "and decode")
	for index: int in probes.size():
		assert_equal(back.unsigned_state_at(index), probes[index],
			"u32 state %d survives the signed wire form" % probes[index])


func test_a_high_bit_state_applies_to_a_real_store_and_keeps_drawing() -> void:
	"""restore_stream() takes the UNSIGNED form, so the conversion must actually happen."""
	var high: int = SaveCodec.UINT32_MAX
	_store.restore_stream(RngScript.STREAM_MAP, high, 12)
	var bytes: PackedByteArray = _payload_of(_store)
	var loaded: RngScript = RngScript.new()
	loaded.seed_world(WORLD_SEED)
	SaveSectionRng.decode_into(bytes, 0, _record)
	assert_true(SaveSectionRng.apply(_record, loaded).is_ok(), "a 0xffffffff state applies")
	assert_equal(loaded.state_of(RngScript.STREAM_MAP).value, high, "as the unsigned value")
	assert_equal(loaded.draw(RngScript.STREAM_MAP).value,
		_store.draw(RngScript.STREAM_MAP).value, "and the next draw matches")


# --- truncation and bounds ---------------------------------------------------------------------------

func test_a_truncated_section_refuses_and_leaves_the_record_untouched() -> void:
	"""One byte short must refuse before it allocates or writes anything (decision 0059)."""
	var bytes: PackedByteArray = _payload_of(_store).slice(0, SaveSectionRng.SECTION_BYTES - 1)
	_record.states[0] = 12345
	_record.draw_counts[0] = 99
	var refusal: SaveHeader.Refusal = SaveSectionRng.decode_into(bytes, 0, _record)
	assert_equal(refusal.code, SaveSectionRng.REFUSE_TRUNCATED, "107 bytes is refused")
	assert_equal(_record.states[0], 12345, "the caller's record is byte-identical")
	assert_equal(_record.draw_counts[0], 99, "including its draw counts")


func test_a_full_length_but_invalid_section_also_leaves_the_record_untouched() -> void:
	"""Decoding must not commit to the caller's Record and then validate it.

	The truncation test above is caught by the extent gate before anything is read. This one is
	the OTHER order of the same mistake: 108 well-formed bytes carrying an illegal value. If
	`decode_into()` copied first and checked second, the caller would be left holding a refused
	record that it was told not to use -- and the next thing to read it would see the corruption.
	"""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s32(SaveSectionRng.STATE_OFFSET + 4 * RngScript.STREAM_MAP, 0)
	_record.states[RngScript.STREAM_MAP] = 31337
	_record.draw_counts[RngScript.STREAM_MAP] = 404
	assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
		SaveSectionRng.REFUSE_ZERO_STATE, "the zero state refuses")
	assert_equal(_record.states[RngScript.STREAM_MAP], 31337, "the record still holds its marker")
	assert_equal(_record.draw_counts[RngScript.STREAM_MAP], 404, "and its draw count")


func test_a_refused_negative_draw_count_also_leaves_the_record_untouched() -> void:
	"""The same property through the other validation rule, so one gate cannot cover for both."""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s64(SaveSectionRng.DRAW_COUNT_OFFSET + 8 * RngScript.STREAM_SOCIAL, -9)
	_record.states[RngScript.STREAM_SOCIAL] = 777
	assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
		SaveSectionRng.REFUSE_NEGATIVE_DRAW_COUNT, "the negative count refuses")
	assert_equal(_record.states[RngScript.STREAM_SOCIAL], 777, "the record is untouched")


func test_the_exact_length_boundary_accepts_108_and_refuses_107() -> void:
	"""Off by one in either direction, checked explicitly rather than trusted."""
	var bytes: PackedByteArray = _payload_of(_store)
	assert_true(SaveSectionRng.decode_into(bytes, 0, _record).is_ok(), "108 bytes decodes")
	assert_equal(SaveSectionRng.decode_into(bytes.slice(0, 107), 0, _record).code,
		SaveSectionRng.REFUSE_TRUNCATED, "107 bytes refuses")


func test_a_valid_section_decodes_at_a_nonzero_offset_and_refuses_one_past_it() -> void:
	"""Section 10 does not assume it starts the file; the last legal offset is size-108."""
	var payload: PackedByteArray = _payload_of(_store)
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(7)
	padded.append_array(payload)
	assert_true(SaveSectionRng.decode_into(padded, 7, _record).is_ok(), "offset 7 decodes")
	assert_equal(SaveSectionRng.decode_into(padded, 8, _record).code,
		SaveSectionRng.REFUSE_TRUNCATED, "offset 8 runs one byte past the end")


func test_the_extent_gate_is_exact_at_the_last_legal_offset() -> void:
	"""Checked on its own, because save_codec.gd's Reader is ALSO bounded.

	A slack extent check still ends in a truncation refusal -- the Reader catches it one layer
	down -- so testing only `decode_into()`'s refusal code lets an off-by-one here survive. This
	calls the gate directly at `size-108`, `size-107` and `size`, which no other layer can mask.
	"""
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(7)
	padded.append_array(_payload_of(_store))
	var last_legal: int = padded.size() - SaveSectionRng.SECTION_BYTES
	assert_equal(last_legal, 7, "a 115-byte buffer fits one 108-byte section at offset 7")
	assert_true(SaveSectionRng.extent_refusal(padded, last_legal).is_ok(), "offset 7 fits")
	assert_equal(SaveSectionRng.extent_refusal(padded, last_legal + 1).code,
		SaveSectionRng.REFUSE_TRUNCATED, "offset 8 does not")
	assert_equal(SaveSectionRng.extent_refusal(padded, padded.size()).code,
		SaveSectionRng.REFUSE_TRUNCATED, "and neither does the end of the buffer")
	assert_equal(SaveSectionRng.extent_refusal(PackedByteArray(), 0).code,
		SaveSectionRng.REFUSE_TRUNCATED, "an empty buffer holds no section")


func test_the_extent_gate_refuses_before_the_reader_is_built() -> void:
	"""The refusal detail names the section's own requirement, not the Reader's leftover count."""
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(7)
	padded.append_array(_payload_of(_store))
	var refusal: SaveHeader.Refusal = SaveSectionRng.decode_into(padded, 8, _record)
	assert_true(refusal.detail.contains("section 10 needs %d bytes"
		% SaveSectionRng.SECTION_BYTES), "the extent gate reported it: %s" % refusal.detail)


func test_a_negative_offset_refuses_by_name() -> void:
	"""A negative offset is its own refusal, never a wrapped index."""
	assert_equal(SaveSectionRng.decode_into(_payload_of(_store), -1, _record).code,
		SaveSectionRng.REFUSE_NEGATIVE_OFFSET, "offset -1 refuses")


func test_a_negative_draw_count_is_refused() -> void:
	"""A draw count is a monotone counter; negative is corruption, never a sentinel."""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s64(SaveSectionRng.DRAW_COUNT_OFFSET + 8 * RngScript.STREAM_ECOLOGY, -1)
	assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
		SaveSectionRng.REFUSE_NEGATIVE_DRAW_COUNT, "-1 draws refuses")


func test_the_largest_representable_draw_count_is_accepted() -> void:
	"""ARCH-RNG-002 says int64 draw count; the top of that range is valid, not an overflow."""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s64(SaveSectionRng.DRAW_COUNT_OFFSET + 8 * RngScript.STREAM_FISHING,
		SaveCodec.INT64_MAX)
	assert_true(SaveSectionRng.decode_into(bytes, 0, _record).is_ok(), "INT64_MAX draws decodes")
	assert_equal(_record.draw_counts[RngScript.STREAM_FISHING], SaveCodec.INT64_MAX,
		"and survives exactly")


# --- the HUNTING tombstone -----------------------------------------------------------------------

func test_the_tombstone_round_trips_untouched() -> void:
	"""SET-AMEND-001 §3 keeps HUNTING seeded with a zero count; a save must carry it as it is."""
	var bytes: PackedByteArray = _payload_of(_store)
	var loaded: RngScript = RngScript.new()
	loaded.seed_world(WORLD_SEED)
	SaveSectionRng.decode_into(bytes, 0, _record)
	assert_true(SaveSectionRng.apply(_record, loaded).is_ok(), "apply succeeds")
	assert_true(loaded.tombstone_is_intact(), "HUNTING is still canonical after a load")


func test_a_drawn_tombstone_is_refused_without_needing_the_seed() -> void:
	"""A nonzero HUNTING count is seed-independent corruption and fails at decode time."""
	var bytes: PackedByteArray = _payload_of(_store)
	bytes.encode_s64(SaveSectionRng.DRAW_COUNT_OFFSET + 8 * RngScript.STREAM_HUNTING, 1)
	assert_equal(SaveSectionRng.decode_into(bytes, 0, _record).code,
		SaveSectionRng.REFUSE_TOMBSTONE_DRAWN, "one HUNTING draw refuses")


func test_a_tombstone_from_a_different_world_seed_is_refused_at_apply() -> void:
	"""The seed-dependent half: a HUNTING state that is canonical elsewhere is not canonical here.

	The refusal surfaces `rng.gd`'s OWN code in its detail rather than a second copy of the rule
	kept here, which is why `apply()` does not re-check it.
	"""
	var other: RngScript = RngScript.new()
	other.seed_world(WORLD_SEED + 1)
	var bytes: PackedByteArray = _payload_of(other)
	assert_true(SaveSectionRng.decode_into(bytes, 0, _record).is_ok(), "it decodes -- shape is fine")
	var refusal: SaveHeader.Refusal = SaveSectionRng.apply(_record, _store)
	assert_equal(refusal.code, SaveSectionRng.REFUSE_STORE_REFUSED,
		"apply refuses against this world's seed")
	assert_true(refusal.detail.contains(String(RngScript.REFUSE_NONCANONICAL_TOMBSTONE)),
		"and names rng.gd's refusal: %s" % refusal.detail)
	assert_true(refusal.detail.contains("rolled back"), "and says the store was rolled back")


func test_the_rollback_restores_streams_that_had_already_been_written() -> void:
	"""The refusal lands on stream 3, so streams 0-2 were written and must be put back.

	This is the path that makes `apply()` all-or-nothing, and it is reached by a real input --
	not by a contrivance -- because the tombstone rule is enforced where it lives.
	"""
	var other: RngScript = RngScript.new()
	other.seed_world(WORLD_SEED + 1)
	SaveSectionRng.decode_into(_payload_of(other), 0, _record)
	var before: SaveSectionRng.Record = SaveSectionRng.Record.new()
	SaveSectionRng.capture_into(_store, before)
	for stream_id: int in RngScript.STREAM_HUNTING:
		assert_true(_record.states[stream_id] != before.states[stream_id],
			"stream %d really would have changed" % stream_id)
	assert_false(SaveSectionRng.apply(_record, _store).is_ok(), "the apply refuses")
	for stream_id: int in RngScript.STREAM_HUNTING:
		assert_equal(_store.stored_state_of(stream_id).value, before.states[stream_id],
			"stream %d was rolled back" % stream_id)


func test_tombstone_refusal_accepts_the_matching_seed_and_rejects_its_neighbours() -> void:
	"""Checked directly, so the seed comparison cannot be a no-op that always passes."""
	SaveSectionRng.capture_into(_store, _record)
	assert_true(SaveSectionRng.tombstone_refusal(_record, WORLD_SEED).is_ok(), "seed matches")
	assert_false(SaveSectionRng.tombstone_refusal(_record, WORLD_SEED - 1).is_ok(), "seed-1 does not")
	assert_false(SaveSectionRng.tombstone_refusal(_record, WORLD_SEED + 1).is_ok(), "seed+1 does not")


# --- apply preconditions and transactionality --------------------------------------------------------

func test_apply_refuses_an_unseeded_store_rather_than_seeding_one_itself() -> void:
	"""Choosing a seed here would be the silent re-derivation the registry warns about."""
	var bytes: PackedByteArray = _payload_of(_store)
	SaveSectionRng.decode_into(bytes, 0, _record)
	var fresh: RngScript = RngScript.new()
	assert_equal(SaveSectionRng.apply(_record, fresh).code,
		SaveSectionRng.REFUSE_STORE_UNSEEDED, "an unseeded target refuses")
	assert_false(fresh.is_seeded(), "and is still unseeded afterwards")


func test_a_refused_apply_leaves_every_stream_byte_identical() -> void:
	"""Transactional: the tombstone is checked before any of the nine pairs is written."""
	var other: RngScript = RngScript.new()
	other.seed_world(WORLD_SEED + 1)
	for stream_id: int in RngScript.STREAM_COUNT:
		if not RngScript.is_retired(stream_id):
			for _index: int in 4:
				other.draw(stream_id)
	SaveSectionRng.decode_into(_payload_of(other), 0, _record)
	var before: SaveSectionRng.Record = SaveSectionRng.Record.new()
	SaveSectionRng.capture_into(_store, before)
	assert_false(SaveSectionRng.apply(_record, _store).is_ok(), "the apply refuses")
	for stream_id: int in RngScript.STREAM_COUNT:
		assert_equal(_store.stored_state_of(stream_id).value, before.states[stream_id],
			"stream %d state unchanged" % stream_id)
		assert_equal(_store.draw_count_of(stream_id).value, before.draw_counts[stream_id],
			"stream %d count unchanged" % stream_id)


func test_apply_refuses_an_invalid_record_before_touching_the_store() -> void:
	"""Record validation runs first, so a zero state never reaches restore_stream()."""
	SaveSectionRng.capture_into(_store, _record)
	_record.states[RngScript.STREAM_IMMIGRATION] = 0
	var before: int = _store.stored_state_of(RngScript.STREAM_IMMIGRATION).value
	assert_equal(SaveSectionRng.apply(_record, _store).code,
		SaveSectionRng.REFUSE_ZERO_STATE, "a zero state refuses at apply")
	assert_equal(_store.stored_state_of(RngScript.STREAM_IMMIGRATION).value, before,
		"and the store is untouched")


# --- ARCH-HASH-001 contribution -----------------------------------------------------------------------

func test_the_canonical_contribution_is_the_whole_payload() -> void:
	"""ARCH-HASH-001 excludes nothing in section 10, so contribution and payload are identical."""
	SaveSectionRng.capture_into(_store, _record)
	var payload: SaveSectionRng.EncodeResult = SaveSectionRng.EncodeResult.new()
	assert_true(SaveSectionRng.encode_record(_record, payload), "payload encodes")
	assert_true(SaveSectionRng.canonical_bytes_of(_record, _encoded), "contribution encodes")
	assert_equal(_encoded.bytes, payload.bytes, "and they are byte-for-byte the same")


func test_changing_any_rng_field_changes_the_canonical_contribution() -> void:
	"""Both columns are hashed, so a state change and a count change each move the bytes."""
	SaveSectionRng.capture_into(_store, _record)
	SaveSectionRng.canonical_bytes_of(_record, _encoded)
	var baseline: PackedByteArray = _encoded.bytes
	_record.draw_counts[RngScript.STREAM_QUALITY] += 1
	SaveSectionRng.canonical_bytes_of(_record, _encoded)
	assert_true(_encoded.bytes != baseline, "a draw count change moves the contribution")
	_record.draw_counts[RngScript.STREAM_QUALITY] -= 1
	_record.states[RngScript.STREAM_QUALITY] = 7
	SaveSectionRng.canonical_bytes_of(_record, _encoded)
	assert_true(_encoded.bytes != baseline, "a state change moves it too")


# --- module hygiene -------------------------------------------------------------------------------

func test_the_module_declares_no_float_path() -> void:
	"""ARCH-AUTH-002: authoritative state is integer, and a save codec must not open a float door."""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/save_section_rng.gd")
	assert_true(source.length() > 0, "the module source was read")
	assert_false(source.contains(": float"), "no float-typed declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")
