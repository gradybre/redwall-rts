extends "res://test/framework/test_case.gd"
## `save_file.gd`: the whole-file container (ADR 1222 steps 8-9).
##
## A synthetic body -- a valid estuary provenance prefix in section 1 and arbitrary bytes in the
## other fourteen -- round-trips through encode/decode and through the atomic disk write; every
## structural corruption (a flipped body byte, a reordered table, a short file, a foreign
## identity) refuses with its exact code and leaves the caller's Body untouched.

const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveIdentity := preload("res://scripts/core/save_identity_hashes.gd")

const TEST_DIR: String = "user://test_save_file"


func _prefix() -> PackedByteArray:
	"""The 44-byte estuary v1 provenance prefix with seed 1234 and a zero authored digest."""
	var prefix: PackedByteArray = PackedByteArray()
	prefix.resize(SaveFile.PROVENANCE_PREFIX_BYTES)
	prefix.encode_u32(0, SaveIdentity.SCENARIO_ESTUARY_V1)
	prefix.encode_s32(4, 1234)
	prefix.encode_u32(8, SaveIdentity.MAP_GENERATOR_SCHEMA_V1)
	return prefix


func _body() -> SaveFile.Body:
	"""Fifteen sections: the prefix plus a tail in section 1, distinct bytes elsewhere, one empty."""
	var body: SaveFile.Body = SaveFile.Body.new()
	var first: PackedByteArray = _prefix()
	first.append_array(PackedByteArray([1, 2, 3]))
	body.set_section(1, first, 4, 1)
	for id: int in range(2, SaveFile.SECTION_COUNT + 1):
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(0 if id == 13 else id * 7)
		bytes.fill(id)
		body.set_section(id, bytes, id % 3 + 1, id)
	body.completed_tick = 3000
	body.economic_next_high = 0
	body.economic_next_low = 17
	return body


func _encoded() -> PackedByteArray:
	"""The body's file bytes, asserting success."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SaveFile.encode_file(_body(), bytes)
	assert_true(refusal.is_ok(), "encode: %s %s" % [refusal.code, refusal.detail])
	return bytes


func _assert_refused(bytes: PackedByteArray, code: StringName, what: String) -> void:
	"""Decode refuses with exactly `code` and leaves the target Body empty."""
	var out: SaveFile.Body = SaveFile.Body.new()
	var refusal: SaveHeader.Refusal = SaveFile.decode_file(bytes, out, null)
	assert_equal(refusal.code, code, "%s: %s" % [what, refusal.detail])
	assert_equal(out.section(1).size(), 0, "%s leaves the Body untouched" % what)


func test_a_body_round_trips_with_its_descriptor_facts_and_header_scalars() -> void:
	"""Every section, schema version, row count and header scalar comes back exactly."""
	var bytes: PackedByteArray = _encoded()
	var source: SaveFile.Body = _body()
	var out: SaveFile.Body = SaveFile.Body.new()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	var refusal: SaveHeader.Refusal = SaveFile.decode_file(bytes, out, header)
	assert_true(refusal.is_ok(), "decode: %s %s" % [refusal.code, refusal.detail])
	for id: int in range(1, SaveFile.SECTION_COUNT + 1):
		assert_equal(out.section(id), source.section(id), "section %d bytes" % id)
	assert_equal(out.schema_versions, source.schema_versions, "schema versions")
	assert_equal(out.row_counts, source.row_counts, "row counts")
	assert_equal(header.completed_tick, 3000, "completed tick")
	assert_equal(header.economic_next_sequence_low, 17, "checkpoint low")
	assert_equal(header.total_file_bytes, bytes.size(), "exact length")


func test_structural_corruptions_refuse_with_their_codes() -> void:
	"""A flipped section byte, a short file, a swapped table slot and a foreign identity refuse."""
	var bytes: PackedByteArray = _encoded()
	var flipped: PackedByteArray = bytes.duplicate()
	flipped[bytes.size() - 1] ^= 0xff
	_assert_refused(flipped, SaveFile.REFUSE_SECTION_CRC, "a flipped last byte")
	_assert_refused(bytes.slice(0, bytes.size() - 1), SaveHeader.REFUSE_FILE_LENGTH, "short")
	var swapped: PackedByteArray = bytes.duplicate()
	var first: int = SaveHeader.SECTION_TABLE_OFFSET
	var slot: PackedByteArray = swapped.slice(first, first + SaveHeader.SECTION_DESCRIPTOR_BYTES)
	for index: int in SaveHeader.SECTION_DESCRIPTOR_BYTES:
		swapped[first + index] = swapped[first + SaveHeader.SECTION_DESCRIPTOR_BYTES + index]
		swapped[first + SaveHeader.SECTION_DESCRIPTOR_BYTES + index] = slot[index]
	_assert_refused(swapped, SaveFile.REFUSE_SECTION_ORDER, "a swapped table")
	var foreign: PackedByteArray = bytes.duplicate()
	foreign[SaveHeader.OFFSET_RULES_HASH] ^= 1
	_assert_refused(foreign, SaveIdentity.REFUSE_RULES_MISMATCH, "a foreign rules identity")


func test_a_body_without_a_provenance_prefix_is_refused_before_any_byte_is_laid_out() -> void:
	"""Section 1 must at least hold its 44-byte prefix."""
	var out: PackedByteArray = PackedByteArray([9])
	var refusal: SaveHeader.Refusal = SaveFile.encode_file(SaveFile.Body.new(), out)
	assert_equal(refusal.code, SaveFile.REFUSE_BODY_SHAPE, "no prefix")
	assert_equal(out, PackedByteArray([9]), "out unchanged")


func test_the_atomic_write_verifies_then_renames_and_reads_back() -> void:
	"""`write_atomic()` leaves exactly the target, which reads back byte-identically."""
	var path: String = TEST_DIR + "/slot.rwlsave"
	var bytes: PackedByteArray = _encoded()
	var written: SaveHeader.Refusal = SaveFile.write_atomic(path, bytes)
	assert_true(written.is_ok(), "write: %s %s" % [written.code, written.detail])
	assert_false(FileAccess.file_exists(path + SaveFile.TEMP_SUFFIX), "no temp file is left")
	var back: PackedByteArray = PackedByteArray()
	assert_true(SaveFile.read_file(path, back).is_ok(), "read back")
	assert_equal(back, bytes, "byte-identical")
	assert_equal(SaveFile.write_atomic(path, flip(bytes)).code, SaveFile.REFUSE_VERIFY,
		"a body that does not decode is never renamed over the target")
	assert_true(SaveFile.read_file(path, back).is_ok() and back == bytes, "target unchanged")
	DirAccess.remove_absolute(path + SaveFile.TEMP_SUFFIX)
	DirAccess.remove_absolute(path)


func flip(bytes: PackedByteArray) -> PackedByteArray:
	"""A copy with its last byte inverted."""
	var copy: PackedByteArray = bytes.duplicate()
	copy[copy.size() - 1] ^= 0xff
	return copy
