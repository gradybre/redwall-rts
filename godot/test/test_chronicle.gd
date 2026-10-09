extends "res://test/framework/test_case.gd"
## Suite for `chronicle.gd`, the section 13 Chronicle owner (ADR 1222 step 5, DEC-055 Q8).
##
## THE DIGEST RULE IS PROVED ON BYTES, NOT THROUGH A TEST HOOK. The compiled event domain is
## empty in this release and there is deliberately no override, so `append()` can never succeed
## here. The rule is therefore pinned two independent ways: against SHA-256 vectors computed
## outside Godot (Python `hashlib` over `struct.pack('<iiqii', ...)`), and against an in-test
## HashingContext chain that never calls `chronicle.gd`.

const Chronicle := preload("res://scripts/core/chronicle.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

## SHA256(32 zero bytes || 24 zero bytes), computed with Python hashlib.
const ZERO_STEP_HEX: String = "d4817aa5497628e7c77e6b606107042bbba3130888c5f47a375e6179be789fbb"
## struct.pack('<iiqii', 7, 3, 13500, -1, 42).
const RECORD_A_HEX: String = "0700000003000000bc34000000000000ffffffff2a000000"
## struct.pack('<iiqii', -2147483648, 2147483647, 9223372036854775807, 0, -7).
const RECORD_B_HEX: String = "00000080ffffff7fffffffffffffff7f00000000f9ffffff"
## SHA256(zero32 || A) and SHA256(that || B).
const DIGEST_A_HEX: String = "e86494a4295d3d90fbbad320f6202858e864eba8ac57c146a8311fac1b981c21"
const DIGEST_AB_HEX: String = "f41c9f04486eaedd49fc7531a465b126246e3e389b2bee3135ace70744bb1b4a"

var _chronicle: Chronicle = null


func before_each() -> void:
	"""A fresh, empty owner for each test."""
	_chronicle = Chronicle.new()


func _snapshot(chronicle: Chronicle) -> PackedByteArray:
	"""The owner's whole observable state as bytes: count (i64 LE) then the 32-byte digest."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, chronicle.count())
	bytes.append_array(chronicle.rolling_digest())
	return bytes


func _independent_step(previous: PackedByteArray, record: PackedByteArray) -> PackedByteArray:
	"""SHA256(previous || record) through HashingContext directly, never through chronicle.gd."""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(previous)
	context.update(record)
	return context.finish()


func _filled(size: int, value: int) -> PackedByteArray:
	"""A buffer of `size` bytes all equal to `value`."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	bytes.fill(value)
	return bytes


# --- identity and declaration -----------------------------------------------------------------

func test_layout_constants_transcribe_save_r09_section_13() -> void:
	"""Section 13, 24-byte record at offsets 0/4/8/16/20, a 32-byte digest."""
	assert_equal(Chronicle.SECTION_ID, 13, "ARCH-SAVE-002 numbers CHRONICLE 13")
	assert_equal(Chronicle.RECORD_BYTES, 24, "SAVE-R09 24-byte record")
	assert_equal([Chronicle.OFFSET_RESIDENT_ID, Chronicle.OFFSET_EVENT, Chronicle.OFFSET_TICK,
		Chronicle.OFFSET_OTHER_ID, Chronicle.OFFSET_DETAIL_KEY], [0, 4, 8, 16, 20],
		"resident_id, event, tick, other_id, detail_key")
	assert_equal(Chronicle.DIGEST_BYTES, 32, "SHA-256 width")


func test_owner_matches_the_compiled_canonical_declaration() -> void:
	"""REG-R01: owner (13, chronicle) schema 1, `_count` u64 then `_rolling_digest` u8."""
	var declaration: Digest.Declaration = Digest.production_declaration()
	var index: int = declaration.find_owner(13, Chronicle.OWNER_KEY)
	assert_true(index < declaration.owner_count(), "chronicle is declared")
	assert_equal(declaration.owner_schema_version(index), Chronicle.OWNER_SCHEMA_VERSION, "schema")
	assert_equal(declaration.owner_field_count(index), Chronicle.FIELD_KEYS.size(), "two fields")
	var begin: int = declaration.owner_field_begin(index)
	for ordinal: int in Chronicle.FIELD_KEYS.size():
		assert_equal(declaration.field_key(begin + ordinal), Chronicle.FIELD_KEYS[ordinal],
			"ordinal %d key" % ordinal)
	assert_equal(declaration.field_type(begin + Chronicle.ORDINAL_COUNT), Digest.TYPE_U64, "u64")
	assert_equal(declaration.field_type(begin + Chronicle.ORDINAL_ROLLING_DIGEST), Digest.TYPE_U8,
		"u8")


func test_the_event_and_detail_domains_are_empty_dec_055_q8() -> void:
	"""DEC-055 Q8: the Chronicle ships with an empty event list; no kind or detail is admissible."""
	assert_equal(Chronicle.EVENT_KIND_COUNT, 0, "no event kinds are compiled")
	assert_equal(Chronicle.DETAIL_KEY_COUNT, 0, "no ChronicleDetail ids are compiled")
	for value: int in [0, 1, -1, SaveCodec.INT32_MAX, SaveCodec.INT32_MIN]:
		assert_false(Chronicle.is_event_in_domain(value), "event %d is not a kind" % value)
		assert_false(Chronicle.is_detail_in_domain(value), "detail %d is not an id" % value)


# --- empty state ------------------------------------------------------------------------------

func test_a_new_chronicle_is_empty_with_the_all_zero_digest() -> void:
	"""The chain starts at count 0 and 32 zero bytes."""
	assert_equal(_chronicle.count(), 0, "count 0")
	assert_true(_chronicle.is_empty(), "is_empty")
	assert_equal(_chronicle.rolling_digest(), _filled(32, 0), "32 zero bytes")
	assert_true(Chronicle.is_zero_digest(Chronicle.zero_digest()), "zero_digest is zero")


func test_rolling_digest_returns_a_copy() -> void:
	"""Editing the returned digest cannot reach the owner."""
	var digest: PackedByteArray = _chronicle.rolling_digest()
	digest[0] = 0xff
	assert_equal(_chronicle.rolling_digest(), _filled(32, 0), "owner unchanged")


func test_copy_state_into_copies_and_refuses_null() -> void:
	"""copy_state_into fills a State with a detached digest, and refuses a null State."""
	var state: Chronicle.State = Chronicle.State.new()
	state.count = 9
	assert_equal(_chronicle.copy_state_into(state), Chronicle.REFUSE_NONE, "copies")
	assert_equal(state.count, 0, "count")
	assert_equal(state.digest, _filled(32, 0), "digest")
	state.digest[3] = 1
	assert_equal(_chronicle.rolling_digest(), _filled(32, 0), "detached")
	assert_equal(_chronicle.copy_state_into(null), Chronicle.REFUSE_NULL_STATE, "null refused")


# --- append -----------------------------------------------------------------------------------

func test_every_append_refuses_with_the_event_domain_code_and_changes_nothing() -> void:
	"""With the empty domain every well-formed append refuses CHRONICLE_EVENT_DOMAIN."""
	var before: PackedByteArray = _snapshot(_chronicle)
	var out: PackedByteArray = _filled(5, 0x5a)
	for event: int in [0, 1, 7, SaveCodec.INT32_MAX, -1]:
		var code: StringName = _chronicle.append(7, event, 13500, -1, 0, out)
		assert_equal(code, Chronicle.REFUSE_EVENT_DOMAIN, "event %d refused" % event)
	assert_equal(_snapshot(_chronicle), before, "count and digest byte-identical")
	assert_equal(out, _filled(5, 0x5a), "the caller's record buffer is untouched")


func test_append_checks_width_then_tick_before_the_domain() -> void:
	"""0x80000000 is positive in GDScript and does not fit i32; a negative tick is refused."""
	var out: PackedByteArray = PackedByteArray()
	var too_wide: int = SaveCodec.INT32_MAX + 1
	assert_equal(_chronicle.append(too_wide, 0, 0, 0, 0, out), Chronicle.REFUSE_FIELD_NOT_INT32,
		"resident_id")
	assert_equal(_chronicle.append(0, 0, 0, 0, SaveCodec.INT32_MIN - 1, out),
		Chronicle.REFUSE_FIELD_NOT_INT32, "detail_key")
	assert_equal(_chronicle.append(0, 0, -1, 0, 0, out), Chronicle.REFUSE_NEGATIVE_TICK, "tick")
	assert_equal(Chronicle.record_refusal(0, 0, 0, 0, 0), Chronicle.REFUSE_EVENT_DOMAIN,
		"a well-formed record still fails the domain")
	assert_equal(_chronicle.count(), 0, "nothing committed")
	assert_true(out.is_empty(), "no bytes handed back")


# --- the exact bytes and the exact digest rule ------------------------------------------------

func test_encode_record_matches_independent_little_endian_vectors() -> void:
	"""The 24 bytes are struct.pack('<iiqii'), including the signed extrema."""
	var out: PackedByteArray = PackedByteArray()
	assert_equal(Chronicle.encode_record_into(7, 3, 13500, -1, 42, out), Chronicle.REFUSE_NONE, "A")
	assert_equal(out.hex_encode(), RECORD_A_HEX, "record A bytes")
	assert_equal(Chronicle.encode_record_into(SaveCodec.INT32_MIN, SaveCodec.INT32_MAX,
		SaveCodec.INT64_MAX, 0, -7, out), Chronicle.REFUSE_NONE, "B")
	assert_equal(out.hex_encode(), RECORD_B_HEX, "record B bytes")
	assert_equal(Chronicle.encode_record_into(0, 0, 0, SaveCodec.INT32_MAX + 1, 0, out),
		Chronicle.REFUSE_FIELD_NOT_INT32, "a field wider than i32 is refused")


func test_digest_step_matches_pinned_external_vectors() -> void:
	"""SHA256(previous || record), chained from 32 zero bytes, against Python hashlib output."""
	var step: PackedByteArray = PackedByteArray()
	assert_equal(Chronicle.digest_step_into(Chronicle.zero_digest(), _filled(24, 0), step),
		Chronicle.REFUSE_NONE, "zero step")
	assert_equal(step.hex_encode(), ZERO_STEP_HEX, "SHA256 of 56 zero bytes")
	var after_a: PackedByteArray = PackedByteArray()
	Chronicle.digest_step_into(Chronicle.zero_digest(), RECORD_A_HEX.hex_decode(), after_a)
	assert_equal(after_a.hex_encode(), DIGEST_A_HEX, "one record")
	var after_b: PackedByteArray = PackedByteArray()
	Chronicle.digest_step_into(after_a, RECORD_B_HEX.hex_decode(), after_b)
	assert_equal(after_b.hex_encode(), DIGEST_AB_HEX, "two records, in order")


func test_digest_step_agrees_with_an_independent_hashing_context_and_is_order_sensitive() -> void:
	"""Same answer as a raw HashingContext; swapping the two records changes the result."""
	var a: PackedByteArray = RECORD_A_HEX.hex_decode()
	var b: PackedByteArray = RECORD_B_HEX.hex_decode()
	var expected: PackedByteArray = _independent_step(_independent_step(_filled(32, 0), a), b)
	var first: PackedByteArray = PackedByteArray()
	var second: PackedByteArray = PackedByteArray()
	Chronicle.digest_step_into(Chronicle.zero_digest(), a, first)
	Chronicle.digest_step_into(first, b, second)
	assert_equal(second, expected, "matches the independent chain")
	var swapped: PackedByteArray = PackedByteArray()
	Chronicle.digest_step_into(Chronicle.zero_digest(), b, first)
	Chronicle.digest_step_into(first, a, swapped)
	assert_false(swapped == expected, "append order is part of the digest")


func test_digest_step_refuses_wrong_width_inputs_and_leaves_out_untouched() -> void:
	"""A 31/33-byte previous digest or a 23/25-byte record can never be chained."""
	var out: PackedByteArray = _filled(4, 9)
	for pair: Array in [[31, 24], [33, 24], [32, 23], [32, 25]]:
		assert_equal(Chronicle.digest_step_into(_filled(pair[0], 0), _filled(pair[1], 0), out),
			Chronicle.REFUSE_DIGEST_INPUT, "%d/%d refused" % [pair[0], pair[1]])
	assert_equal(out, _filled(4, 9), "out untouched")


# --- restore ----------------------------------------------------------------------------------

func test_restore_accepts_the_empty_state() -> void:
	"""count 0 with 32 zero bytes is the one restorable state in this release."""
	assert_equal(_chronicle.restore_state(0, _filled(32, 0)), Chronicle.REFUSE_NONE, "accepted")
	assert_equal(_chronicle.count(), 0, "count")
	assert_equal(_chronicle.rolling_digest(), _filled(32, 0), "digest")


func test_every_restore_refusal_leaves_the_owner_byte_identical() -> void:
	"""Negative count, wrong digest width, nonzero empty digest, and any record in an empty domain."""
	var before: PackedByteArray = _snapshot(_chronicle)
	var nonzero: PackedByteArray = _filled(32, 0)
	nonzero[31] = 1
	var cases: Array = [
		[-1, _filled(32, 0), Chronicle.REFUSE_RESTORE_COUNT],
		[0, _filled(31, 0), Chronicle.REFUSE_RESTORE_DIGEST_LENGTH],
		[0, _filled(33, 0), Chronicle.REFUSE_RESTORE_DIGEST_LENGTH],
		[0, nonzero, Chronicle.REFUSE_RESTORE_EMPTY_DIGEST],
		[1, DIGEST_A_HEX.hex_decode(), Chronicle.REFUSE_RESTORE_EVENT_DOMAIN],
	]
	for entry: Array in cases:
		assert_equal(_chronicle.restore_state(entry[0], entry[1]), entry[2], String(entry[2]))
		assert_equal(_snapshot(_chronicle), before, "byte-identical after %s" % entry[2])


func test_restore_detaches_from_its_input_and_clear_resets() -> void:
	"""Mutating the input digest after restore cannot reach the owner; clear() returns to empty."""
	var digest: PackedByteArray = _filled(32, 0)
	_chronicle.restore_state(0, digest)
	digest[0] = 0xee
	assert_equal(_chronicle.rolling_digest(), _filled(32, 0), "detached")
	_chronicle.clear()
	assert_equal(_snapshot(_chronicle), _snapshot(Chronicle.new()), "clear is the new state")


# --- source discipline ------------------------------------------------------------------------

func test_source_holds_no_float_and_no_history_column() -> void:
	"""No float path; the only packed member is the 32-byte digest (never load all history)."""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/chronicle.gd")
	assert_false(source.contains(": float"), "no float declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")
	var regex: RegEx = RegEx.create_from_string("(?m)^var _[a-z_]+: Packed")
	var members: Array[RegExMatch] = regex.search_all(source)
	assert_equal(members.size(), 1, "exactly one packed member")
	assert_true(source.contains("var _rolling_digest: PackedByteArray"), "and it is the digest")
