extends "res://test/framework/test_case.gd"
## Section 15 STATE_DIGEST's canonical field walker (SAVE-R09 / REG-R01).
##
## Three layers are exercised, and only the first is a round trip:
##
##   1. THE PINNED FIXTURE. `_fixture_declaration()` builds a seven-field, three-owner declaration
##      designed so that every ordering rule has a witness: two section-1 owners whose ASCII order
##      ("Zed" < "alpha", because 'Z' is 0x5A and 'a' is 0x61) disagrees with both case-insensitive
##      and length order; an owner whose declared ordinals ("_zulu" then "_alpha") disagree with
##      alphabetical order; one declared-but-excluded field; a u32 field whose i32 storage holds
##      0x80000000; and a type 5 value "Móle" that is 4 characters and 5 UTF-8 bytes. The full 426
##      byte stream and its SHA-256 are pinned as hex computed independently in Python, NOT read
##      back out of the module under test. ADR 0127 records the same two strings.
##
##   2. THE GENERATED TABLE vs THE REGISTRY. `test_generated_table_matches_the_registry_json()`
##      re-reads docs/planning/canonical_state_registry.json and compares every owner and every
##      field against the compiled constant table. The table is generated output; this is what
##      makes it impossible for a hand edit or a stale regeneration to survive.
##
##   3. THE REFUSALS. Every way of producing a stable, plausible and wrong digest is asserted to
##      refuse: a missing adapter, a section 15 owner, owners out of ASCII order, a type 5 field
##      with no declared byte cap, a storage form that does not match the declared type, a count
##      that does not match the declared count, a u32 out of range, a negative u64, a malformed
##      engine identity line and a short compatibility digest.
##
## The production walker currently refuses: not one owner adapter exists. That refusal is asserted
## directly, together with the full 50-owner missing list, because a green suite that quietly
## digested a subset would be exactly the failure REG-R01 forbids.

const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const Section07 := preload("res://scripts/core/save_section_inventories.gd")
const Section12 := preload("res://scripts/core/save_section_pending_commands.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"

## Independently computed in Python from SAVE-R09's grammar; ADR 0127 repeats it verbatim.
## Split by stream element so a reader can check any one part by hand.
const FIXTURE_STREAM_HEX: String = (
	# RWL-STATE-1, eleven ASCII bytes with no terminator
	"52574c2d53544154452d31"
	# rules, catalog, map and lookup identities, 32 bytes each
	+ "111111111111111111111111111111111111111111111111111111111111111122222222222222"
	+ "222222222222222222222222222222222222222222222222223333333333333333333333333333"
	+ "333333333333333333333333333333333333444444444444444444444444444444444444444444"
	+ "4444444444444444444444"
	# engine identity line: u32 byte length 32, then the line including its LF
	+ "20000000342e372e322e737461626c652e6f6666696369616c2e6564316461663062660a"
	# completed_tick 54000 as i64 LE, then record_count 6 as u32 LE
	+ "f0d200000000000006000000"
	# record 1  (1, "Zed", "_zulu") type 2 i32, 3 values: INT32_MIN, -1, INT32_MAX
	+ "01000000030000005a6564050000005f7a756c7502030000000000000000000080ffffffffffff"
	+ "ff7f"
	# record 2  (1, "Zed", "_alpha") type 0 u8, 2 values: 0, 255
	+ "01000000030000005a6564060000005f616c70686100020000000000000000ff"
	# record 3  (1, "alpha", "_cursor") type 1 u32, 1 value: 0x80000000
	+ "0100000005000000616c706861070000005f637572736f7201010000000000000000000080"
	# record 4  (1, "alpha", "_name") type 5, 2 values: "" and "Móle" (4 chars, 5 bytes)
	+ "0100000005000000616c706861050000005f6e616d650502000000000000000000000005000000"
	+ "4dc3b36c65"
	# record 5  (14, "residents", "_big") type 3 u64, 1 value: INT64_MAX
	+ "0e000000090000007265736964656e7473040000005f626967030100000000000000ffffffffff"
	+ "ffff7f"
	# record 6  (14, "residents", "_debt") type 4 i64, 1 value: -1
	+ "0e000000090000007265736964656e7473050000005f64656274040100000000000000ffffffff"
	+ "ffffffff"
)
const FIXTURE_DIGEST_HEX: String = "7711d6b5dcd94db94f82bb4d61fb976506ffb57aec60eb62d94d4051aad61da0"
const FIXTURE_STREAM_BYTES: int = 426
const FIXTURE_RECORD_COUNT: int = 6
const FIXTURE_IDENTITY: String = "RWL-STATE-FIXTURE-1"
const FIXTURE_ENGINE_LINE: String = "4.7.2.stable.official.ed1daf0bf\n"
const FIXTURE_COMPLETED_TICK: int = 54000
const CAPTURE_CAP: int = 4096

const U32_HIGH_BIT: int = 2147483648
const NAME_CAP_BYTES: int = 128
## REG-R01 REQUIRES this to grow: it is a snapshot of how many packed columns the registry
## currently persists, not a format constant. It read 512 at executor snapshot 197472b, 530
## after the save-registry reconciliation, 536 once event_schedule.gd landed section 11's
## six record columns, and 553 once construction.gd's seventeen category-1 columns were
## registered. A new store SHOULD move it.
##
## `record_count` moves only when the DECLARED field set changes, and the two cases differ:
## section 11's eight fields were already declared before any of them had a module, so that
## landing moved this pin alone and left `record_count` at 582. construction.gd's seventeen
## columns were never declared at all, so registering them is seventeen NEW hash=true
## declarations and `record_count` moves with them, 582 -> 599.
##
## R-WORLD-S1-001 then moved BOTH pins DOWNWARD, 599 -> 596 and 553 -> 550, by reclassifying
## resource_nodes' `_deposit_tiles`, `_deposit_ref_slot` and `_deposit_ref_generation` from
## category-1 persisted state to category-3 placement scratch. Three declarations leave the
## registry, so three hash=true records leave `record_count`; the same three leave
## docs/persistence_state_registry.md's category-1 set, so three persisted packed columns leave
## this pin. A snapshot pin is allowed to move in either direction; what it may never do is stay
## still while the declaration underneath it changes.
##
## INV-CANON-R01 moves NEITHER pin, and that is its stated result rather than an oversight:
## `canonical_record_delta: 0`. Schema 3 changes what an already-declared field may hold on an
## INACTIVE row; it declares no new field, retires none, and reclassifies no packed column. The
## two numbers that moved in that activation are the (7, 'inventory') owner schema and section
## 7's descriptor schema, both 2 -> 3, pinned separately below.
## SAVE-J2-R01 adds three packed lists and three scalar counts: +6 records, +3 packed.
const REGISTRY_PACKED_FIELD_COUNT: int = 553

## Pinned as LITERALS, deliberately not read from the JSON or from `Digest.*`. Every other
## assertion in this suite compares the compiled table against the registry it was generated
## from, so both sides move together and neither can catch a coordinated edit. These four are
## the independent anchor: R-WORLD-S1-001 requires the active rules identity to CHANGE with the
## activation, and an identity that silently stayed at the 2026-09-12 value would satisfy every
## self-referential check in this file while shipping a different field set under an old name.
## INV-CANON-R01 moves the identity 2026-09-14-2 -> 2026-09-15-3 and the version 2 -> 3. The
## declaration under the old name is not the declaration under the new one: an inventory block
## that normalizes its inactive payload accepts a strictly smaller set of states than schema 2
## did, and leaving the name still would let a stricter codec ship under the old identity while
## every self-referential check in this file stayed green.
const REGISTRY_RECORD_COUNT: int = 602
const REGISTRY_FIELD_COUNT: int = 610
const REGISTRY_DECLARATION_ID: String = "RWL-CANONICAL-REGISTRY-2026-09-15-3"
## SAVE-SEQ-R01 v2 advances declaration version to 4 while retaining this exact namespace.
## The version is independent of the opaque identity suffix; commands owner becomes 2.
## SAVE-J2-R01 advances version 5 and planner owner/section schema 2.
const REGISTRY_DECLARATION_VERSION: int = 5

## INV-CANON-R01's two version numbers, pinned as literals and read back from BOTH the registry
## JSON and the compiled table. They live in different namespaces -- one is the owner block's
## `owner_schema_version`, the other the 64-byte descriptor's `schema_version` -- and the whole
## point of the activation is that they move together with the codec.
const INVENTORY_OWNER_SCHEMA_VERSION: int = 3
const SECTION_SEVEN_SCHEMA_VERSION: int = 3

## Section 7 `inventory`'s thirty declared field keys in DECLARED ORDINAL ORDER, pinned outside
## the JSON. REG-R01's order interleaves container and lot columns and is explicitly not
## alphabetical; INV-CANON-R01 changes the payload SEMANTICS and not one key or ordinal.
const INVENTORY_DECLARED_KEYS: String = (
	"_c_free_count, _l_free_count, _c_live, _l_live, _c_generation, _l_generation, "
	+ "_c_owner_slot, _c_owner_generation, _c_policy, _c_lot_count, _c_first_lot, "
	+ "_c_max_mass_g, _c_filters, _c_reserved_mass_g, _c_used_mass_g, _c_reachable, "
	+ "_l_item_id, _l_quality, _l_provenance, _l_recipe_id, _l_container_slot, "
	+ "_l_container_generation, _l_next, _l_prev, _l_quantity_milli, _l_reserved_milli, "
	+ "_l_age_milli_hours, _l_age_remainder, _c_free, _l_free"
)

## construction.gd's section-4 block, pinned independently of the registry JSON so that deleting
## a field from BOTH the JSON and the compiled table still fails. The JSON-comparison tests above
## only prove the two agree; these two constants are what proves they agree about the right thing.
const CONSTRUCTION_SECTION_FOUR_KEYS: String = (
	"_present, _material_container_slot, _material_container_generation, _assigned_count, "
	+ "_max_workers, _refund_policy, _remaining_mwu, _paused, _work_begun, _ref_slot, "
	+ "_ref_generation, _subject_slot, _subject_generation, _purpose, _type_id, _phase"
)
const CONSTRUCTION_SECTION_FOUR_TYPES: String = "0, 2, 2, 2, 2, 2, 4, 0, 0, 2, 2, 2, 2, 2, 2, 2"


class FixtureAdapter:
	"""A test value source. Answers by field key; it never decides what or when to emit."""
	var keys: PackedStringArray = PackedStringArray()
	var storages: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()
	var payloads: Array = []
	var consulted: PackedStringArray = PackedStringArray()
	var refused_key: String = ""

	func add(key: String, storage: int, payload: Variant, count: int) -> void:
		"""Declare the values this adapter will hand back for one field key."""
		keys.append(key)
		storages.append(storage)
		counts.append(count)
		payloads.append(payload)

	func canonical_field_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""The adapter interface the walker calls once per hashed record."""
		var key: String = String(field_key)
		consulted.append(key)
		if key == refused_key:
			return out.refuse(&"FIXTURE_REFUSED", "the fixture adapter refused '%s'" % key)
		var index: int = keys.find(key)
		if index < 0:
			return out.refuse(&"FIXTURE_UNKNOWN_FIELD", "no fixture value for '%s'" % key)
		return _supply(index, out)

	func _supply(index: int, out: Digest.FieldValues) -> bool:
		"""Hand the stored column over in the storage form this fixture declared."""
		var storage: int = storages[index]
		if storage == Digest.STORAGE_BYTE:
			return out.supply_bytes(payloads[index] as PackedByteArray, counts[index])
		if storage == Digest.STORAGE_INT32:
			return out.supply_int32(payloads[index] as PackedInt32Array, counts[index])
		if storage == Digest.STORAGE_INT64:
			return out.supply_int64(payloads[index] as PackedInt64Array, counts[index])
		return out.supply_texts(payloads[index] as PackedStringArray, counts[index])


# --- fixture construction -------------------------------------------------------------------------

func _fixture_inputs() -> Digest.Inputs:
	"""The pinned RWL-STATE-1 prefix: four constant-byte digests, an engine line and a tick."""
	var inputs: Digest.Inputs = Digest.Inputs.new()
	inputs.rules_digest = _repeated_byte(0x11)
	inputs.catalog_digest = _repeated_byte(0x22)
	inputs.map_digest = _repeated_byte(0x33)
	inputs.lookup_digest = _repeated_byte(0x44)
	inputs.engine_identity_line = FIXTURE_ENGINE_LINE
	inputs.completed_tick = FIXTURE_COMPLETED_TICK
	return inputs


func _repeated_byte(value: int) -> PackedByteArray:
	"""A 32-byte digest of one repeated byte, so the pinned stream is readable by eye."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Digest.DIGEST_BYTES)
	for index: int in Digest.DIGEST_BYTES:
		bytes[index] = value
	return bytes


func _fixture_declaration(alphabetical_fields: bool) -> Digest.Declaration:
	"""Build the pinned fixture declaration; `alphabetical_fields` swaps Zed's two ordinals."""
	var builder: Digest.Builder = Digest.Builder.new()
	builder.begin_owner(1, "Zed", 1)
	if alphabetical_fields:
		builder.add_field("_alpha", Digest.TYPE_U8, true, true, 2, 0)
		builder.add_field("_zulu", Digest.TYPE_I32, true, true, 3, 0)
	else:
		builder.add_field("_zulu", Digest.TYPE_I32, true, true, 3, 0)
		builder.add_field("_alpha", Digest.TYPE_U8, true, true, 2, 0)
	builder.begin_owner(1, "alpha", 2)
	builder.add_field("_excluded_tick", Digest.TYPE_I64, false, true, 1, 0)
	builder.add_field("_cursor", Digest.TYPE_U32, true, true, 1, 0)
	builder.add_field("_name", Digest.TYPE_UTF8_U32, true, true, 2, NAME_CAP_BYTES)
	builder.begin_owner(14, "residents", 1)
	builder.add_field("_big", Digest.TYPE_U64, true, true, 1, 0)
	builder.add_field("_debt", Digest.TYPE_I64, true, true, 1, 0)
	return builder.seal(FIXTURE_IDENTITY)


func _adapter_zed(zulu_tail: int) -> FixtureAdapter:
	"""Owner "Zed": an i32 column at both int32 extremes and a u8 column at both extremes."""
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_zulu", Digest.STORAGE_INT32,
		PackedInt32Array([SaveCodec.INT32_MIN, -1, zulu_tail]), 3)
	adapter.add("_alpha", Digest.STORAGE_BYTE, PackedByteArray([0, 255]), 2)
	return adapter


func _adapter_alpha() -> FixtureAdapter:
	"""Owner "alpha": the excluded tick, a u32 stored as i32 bits, and two names."""
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_excluded_tick", Digest.STORAGE_INT64, PackedInt64Array([123456789]), 1)
	adapter.add("_cursor", Digest.STORAGE_INT32,
		PackedInt32Array([SaveCodec.u32_bits_to_int32(U32_HIGH_BIT)]), 1)
	adapter.add("_name", Digest.STORAGE_TEXT, PackedStringArray(["", "Móle"]), 2)
	return adapter


func _adapter_residents() -> FixtureAdapter:
	"""Owner "residents": INT64_MAX as a u64 and -1 as an i64."""
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_big", Digest.STORAGE_INT64, PackedInt64Array([SaveCodec.INT64_MAX]), 1)
	adapter.add("_debt", Digest.STORAGE_INT64, PackedInt64Array([-1]), 1)
	return adapter


func _fixture_walker(alphabetical_fields: bool, zulu_tail: int) -> Digest.Walker:
	"""A fully covered walker over the fixture declaration."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(alphabetical_fields))
	walker.register_owner(1, "Zed", _adapter_zed(zulu_tail))
	walker.register_owner(1, "alpha", _adapter_alpha())
	walker.register_owner(14, "residents", _adapter_residents())
	return walker


func _walk_fixture(walker: Digest.Walker, capture: int) -> Digest.DigestResult:
	"""Run one walk over the fixture inputs and return the result object."""
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, capture)
	assert_equal(String(refusal.code), "", "fixture walk must not refuse (%s)" % refusal.detail)
	return result


func _pinned_walk(capture: int) -> Digest.DigestResult:
	"""Walk the pinned fixture exactly as ADR 0127 records it."""
	return _walk_fixture(_fixture_walker(false, SaveCodec.INT32_MAX), capture)


# --- 1. the pinned fixture ------------------------------------------------------------------------

func test_fixture_record_stream_is_exactly_the_pinned_bytes() -> void:
	"""The captured stream equals the independently computed 426-byte RWL-STATE-1 stream."""
	var result: Digest.DigestResult = _pinned_walk(CAPTURE_CAP)
	assert_equal(result.captured_stream.size(), FIXTURE_STREAM_BYTES, "fixture stream length")
	assert_equal(result.captured_stream.hex_encode(), FIXTURE_STREAM_HEX, "fixture stream bytes")
	assert_equal(result.stream_bytes, FIXTURE_STREAM_BYTES, "reported stream byte total")


func test_fixture_digest_is_the_pinned_sha256() -> void:
	"""SHA-256 of that exact stream, pinned as hex from Python, not from this module."""
	var result: Digest.DigestResult = _pinned_walk(0)
	assert_equal(result.digest.size(), Digest.DIGEST_BYTES, "digest is 32 raw bytes")
	assert_equal(result.digest.hex_encode(), FIXTURE_DIGEST_HEX, "pinned fixture digest")
	assert_equal(result.record_count, FIXTURE_RECORD_COUNT, "six hashed records, seven declared")


func test_fixture_digest_matches_sha256_of_the_captured_stream() -> void:
	"""The digest is SHA-256 of the emitted stream and of nothing else."""
	var result: Digest.DigestResult = _pinned_walk(CAPTURE_CAP)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(result.captured_stream)
	assert_equal(context.finish().hex_encode(), FIXTURE_DIGEST_HEX,
		"digest equals SHA-256 over the captured stream")


func test_one_changed_value_changes_the_digest() -> void:
	"""Flipping a single i32 value must move the digest. A digest that does not is not a digest."""
	var baseline: Digest.DigestResult = _pinned_walk(0)
	var altered: Digest.DigestResult = _walk_fixture(_fixture_walker(false, SaveCodec.INT32_MAX - 1), 0)
	assert_equal(baseline.digest.hex_encode(), FIXTURE_DIGEST_HEX, "baseline is the pinned digest")
	assert_false(altered.digest.hex_encode() == baseline.digest.hex_encode(),
		"one changed value must change the digest")


func test_alphabetical_field_order_produces_a_different_digest() -> void:
	"""Ordering Zed's fields alphabetically instead of by declared ordinal is a different stream."""
	var declared: Digest.DigestResult = _pinned_walk(0)
	var alphabetical: Digest.DigestResult = _walk_fixture(_fixture_walker(true, SaveCodec.INT32_MAX), 0)
	assert_equal(declared.digest.hex_encode(), FIXTURE_DIGEST_HEX, "declared ordinal order is pinned")
	assert_false(alphabetical.digest.hex_encode() == FIXTURE_DIGEST_HEX,
		"alphabetical field order must not reproduce the declared-ordinal digest")


func test_utf8_prefix_is_a_byte_count_not_a_character_count() -> void:
	""""Móle" is 4 characters and 5 UTF-8 bytes; the pinned stream carries 05000000 before it."""
	var result: Digest.DigestResult = _pinned_walk(CAPTURE_CAP)
	var hex: String = result.captured_stream.hex_encode()
	assert_equal("Móle".length(), 4, "Móle is four characters")
	assert_equal("Móle".to_utf8_buffer().size(), 5, "Móle is five UTF-8 bytes")
	assert_true(hex.contains("050000004dc3b36c65"), "byte-length prefix 5 precedes the 5 bytes")
	assert_false(hex.contains("040000004dc3b36c65"), "a character-count prefix of 4 must not appear")


func test_empty_string_value_is_a_zero_length_prefix() -> void:
	"""SAVE-R09-002: zero represents an empty string, never a null or signed sentinel."""
	var result: Digest.DigestResult = _pinned_walk(CAPTURE_CAP)
	assert_true(result.captured_stream.hex_encode().contains("00000000050000004dc3b36c65"),
		"the empty name emits 00000000 immediately before the next value")


func test_u32_high_bit_column_emits_its_bit_pattern() -> void:
	"""0x80000000 is a positive GDScript int and INT32_MIN as an i32; the u32 field emits 00000080."""
	assert_true(U32_HIGH_BIT > 0, "0x80000000 is a positive GDScript int")
	assert_equal(SaveCodec.u32_bits_to_int32(U32_HIGH_BIT), SaveCodec.INT32_MIN,
		"its int32 reading is -2147483648")
	var result: Digest.DigestResult = _pinned_walk(CAPTURE_CAP)
	var cursor_record: String = "5f637572736f7201" + "0100000000000000" + "00000080"
	assert_true(result.captured_stream.hex_encode().contains(cursor_record),
		"_cursor emits type 1, count 1 and the 00000080 bit pattern")


func test_excluded_field_is_never_consulted_and_never_hashed() -> void:
	"""A declared field with hash=false emits no record and its adapter is not called for it."""
	var adapter: FixtureAdapter = _adapter_alpha()
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(1, "alpha", adapter)
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = _walk_fixture(walker, CAPTURE_CAP)
	assert_false(adapter.consulted.has("_excluded_tick"), "an excluded field is never consulted")
	assert_equal(result.declaration_id, FIXTURE_IDENTITY, "the result names the fixture declaration")
	assert_false(result.captured_stream.hex_encode().contains("5f6578636c756465645f7469636b"),
		"the excluded field key must not appear in the stream")


func test_fixture_result_never_claims_release_coverage() -> void:
	"""A fixture digest is a fixture digest. `covers_release_state` says so in the result object."""
	var result: Digest.DigestResult = _pinned_walk(0)
	assert_false(result.covers_release_state, "a fixture declaration never covers release state")
	assert_false(_fixture_declaration(false).covers_release_state(),
		"the fixture declaration itself does not claim the canonical identity")


# --- 2. the generated table vs the registry JSON ---------------------------------------------------

func _registry() -> Dictionary:
	"""Parse the checked-in canonical registry. Every number arrives as a float; see ADR 0127."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	assert_false(text.is_empty(), "docs/planning/canonical_state_registry.json must be readable")
	return JSON.parse_string(text) as Dictionary


func test_generated_table_matches_the_registry_json() -> void:
	"""Every owner row in the compiled table equals the registry's, in the registry's own order."""
	var data: Dictionary = _registry()
	var owners: Array = data["owners"] as Array
	assert_equal(owners.size(), Digest.CANONICAL_OWNER_COUNT, "owner count")
	var declaration: Digest.Declaration = Digest.production_declaration()
	assert_equal(declaration.owner_count(), owners.size(), "declaration owner count")
	for index: int in owners.size():
		var owner: Dictionary = owners[index] as Dictionary
		assert_equal(declaration.owner_section(index), int(owner["section_id"]), "section %d" % index)
		assert_equal(declaration.owner_key(index), String(owner["owner_key"]), "key %d" % index)
		assert_equal(declaration.owner_schema_version(index), int(owner["owner_schema_version"]),
			"schema version %d" % index)
		assert_equal(declaration.owner_field_count(index), (owner["fields"] as Array).size(),
			"field count %d" % index)


func test_generated_fields_match_the_registry_json() -> void:
	"""Every field's key, type code, hash flag, declared count and byte cap equals the registry's."""
	var owners: Array = _registry()["owners"] as Array
	var declaration: Digest.Declaration = Digest.production_declaration()
	var index: int = 0
	for owner: Dictionary in owners:
		for field: Dictionary in owner["fields"] as Array:
			assert_equal(declaration.field_key(index), String(field["field_key"]), "key %d" % index)
			assert_equal(declaration.field_type(index), int(field["type_code"]), "type %d" % index)
			assert_equal(declaration.field_is_hashed(index), bool(field["hash"]), "hash %d" % index)
			_assert_field_shape(declaration, field, index)
			index += 1
	assert_equal(index, Digest.CANONICAL_FIELD_COUNT, "every declared field was compared")


func _assert_field_shape(declaration: Digest.Declaration, field: Dictionary, index: int) -> void:
	"""Compare one field's sparse declared count and UTF-8 byte cap against the registry."""
	var shape: Dictionary = field["shape"] as Dictionary
	assert_equal(declaration.field_has_declared_count(index), shape.has("count"),
		"declared-count presence %d" % index)
	if shape.has("count"):
		assert_equal(declaration.field_declared_count(index), int(shape["count"]),
			"declared count %d" % index)
	var cap: int = int(field["max_utf8_bytes"]) if field.has("max_utf8_bytes") else 0
	assert_equal(declaration.field_max_utf8_bytes(index), cap, "utf8 cap %d" % index)


func test_registry_counts_are_the_ones_the_ruling_reconciled() -> void:
	"""602 canonical records over 52 owners, 553 persisted packed fields, release_save_ready false."""
	var data: Dictionary = _registry()
	assert_equal(int(data["record_count"]), Digest.CANONICAL_RECORD_COUNT, "registry record_count")
	assert_equal(int(data["packed_source_field_count"]), REGISTRY_PACKED_FIELD_COUNT,
		"registry persisted packed field count")
	assert_equal(String(data["registry_id"]), Digest.DECLARATION_ID, "registry id")
	assert_false(bool(data["release_save_ready"]), "release_save_ready stays false")
	assert_equal(Digest.production_declaration().record_count(), Digest.CANONICAL_RECORD_COUNT,
		"the compiled declaration counts the same 602 records")


func test_the_active_rules_identity_and_counts_match_their_independent_pins() -> void:
	"""R-WORLD-S1-001: the identity and both counts MOVED, against literals held outside the JSON."""
	var data: Dictionary = _registry()
	assert_equal(Digest.DECLARATION_ID, REGISTRY_DECLARATION_ID, "compiled declaration identity")
	assert_equal(Digest.DECLARATION_VERSION, REGISTRY_DECLARATION_VERSION, "declaration version")
	assert_equal(String(data["registry_id"]), REGISTRY_DECLARATION_ID, "registry identity")
	assert_equal(int(data["registry_version"]), REGISTRY_DECLARATION_VERSION, "registry version")
	assert_equal(Digest.CANONICAL_RECORD_COUNT, REGISTRY_RECORD_COUNT, "compiled record count")
	assert_equal(Digest.CANONICAL_FIELD_COUNT, REGISTRY_FIELD_COUNT, "compiled field count")
	assert_equal(int(data["record_count"]), REGISTRY_RECORD_COUNT, "registry record count")
	assert_equal(int(data["packed_source_field_count"]), REGISTRY_PACKED_FIELD_COUNT,
		"registry packed source field count")
	assert_equal(int((data["section_schema_versions"] as Array)[0]), 3,
		"R-WORLD-S1-001 takes section 1 to schema version 3 in the active registry")


func test_inventory_owner_and_section_seven_schemas_activate_together_at_three() -> void:
	"""INV-CANON-R01: the registry, the compiled table and the §7 codec all read 3, or none do.

	FOUR INDEPENDENT SOURCES, deliberately. The registry JSON and the compiled table are
	generated from each other and would move together under a coordinated edit; the literal
	pins above and the codec's own two constants are what make that edit visible. A tree where
	the registry says 3 and the codec still writes 2 is the broken tree this test exists for.
	"""
	var data: Dictionary = _registry()
	assert_equal(int((data["section_schema_versions"] as Array)[6]), SECTION_SEVEN_SCHEMA_VERSION,
		"registry section_schema_versions[6] is section 7")
	assert_equal(Section07.SECTION_SCHEMA_VERSION, SECTION_SEVEN_SCHEMA_VERSION,
		"the §7 codec publishes the descriptor schema version")
	var owner: Dictionary = _owner_of(data, 7, "inventory")
	assert_equal(int(owner["owner_schema_version"]), INVENTORY_OWNER_SCHEMA_VERSION,
		"registry (7, inventory) owner schema version")
	assert_equal(Section07.OWNER_SCHEMA_VERSIONS[Section07.OWNER_INVENTORY],
		INVENTORY_OWNER_SCHEMA_VERSION, "the §7 codec writes the owner schema version")
	assert_equal(InventoryScript.CANONICAL_OWNER_SCHEMA_VERSION, INVENTORY_OWNER_SCHEMA_VERSION,
		"the store declares the owner schema version the codec reads")
	var index: int = Digest.production_declaration().find_owner(7, "inventory")
	assert_equal(Digest.OWNER_VERSIONS[index], INVENTORY_OWNER_SCHEMA_VERSION,
		"the compiled declaration table carries the same owner schema version")


func test_section_seven_keeps_its_thirty_inventory_fields_and_adds_no_record() -> void:
	"""`canonical_record_delta` is 0: the same 30 keys in the same order, at 596 records."""
	var data: Dictionary = _registry()
	var owner: Dictionary = _owner_of(data, 7, "inventory")
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in owner["fields"] as Array:
		keys.append(String((field as Dictionary)["field_key"]))
	assert_equal(keys.size(), 30, "INV-CANON-R01 keeps all 30 declared inventory fields")
	assert_equal(", ".join(keys), INVENTORY_DECLARED_KEYS,
		"the declared order is unchanged, container and lot columns still interleaved")
	assert_equal(int(data["record_count"]), REGISTRY_RECORD_COUNT,
		"no canonical record is added or removed by the schema 3 activation")


func _owner_of(data: Dictionary, section: int, key: String) -> Dictionary:
	"""One registry owner block, failing the test rather than returning an empty Dictionary."""
	for entry: Variant in data["owners"] as Array:
		var owner: Dictionary = entry as Dictionary
		if int(owner["section_id"]) == section and String(owner["owner_key"]) == key:
			return owner
	fail("registry declares no owner (%d, '%s')" % [section, key])
	return {}


func test_section_one_resource_nodes_declares_only_the_tile_inverse_at_schema_two() -> void:
	"""The three deposit scratch arrays produce NO canonical field record, in either table."""
	var data: Dictionary = _registry()
	var owners: Array = data["owners"] as Array
	var found: bool = false
	for entry: Variant in owners:
		var owner: Dictionary = entry as Dictionary
		if int(owner["section_id"]) != 1 or String(owner["owner_key"]) != "resource_nodes":
			continue
		found = true
		assert_equal(int(owner["owner_schema_version"]), 2, "resource_nodes owner schema version")
		var keys: PackedStringArray = PackedStringArray()
		for field: Variant in owner["fields"] as Array:
			keys.append(String((field as Dictionary)["field_key"]))
		assert_equal(keys, PackedStringArray(["_resource_slot"]), "declared field keys")
	assert_true(found, "section 1 still registers a resource_nodes owner")
	var declaration: Digest.Declaration = Digest.production_declaration()
	var index: int = declaration.find_owner(1, "resource_nodes")
	assert_true(index < declaration.owner_count(), "the compiled table registers it too")
	assert_equal(declaration.owner_schema_version(index), 2, "compiled owner schema version")
	assert_equal(declaration.owner_field_count(index), 1, "compiled field count")
	assert_equal(declaration.field_key(declaration.owner_field_begin(index)), "_resource_slot",
		"compiled field key")


func test_production_declaration_validates_and_excludes_section_fifteen() -> void:
	"""The canonical declaration passes every structural rule and never declares section 15."""
	var declaration: Digest.Declaration = Digest.production_declaration()
	var refusal: Digest.Refusal = declaration.validate()
	assert_equal(String(refusal.code), "", "production declaration validates (%s)" % refusal.detail)
	assert_true(declaration.covers_release_state(), "it is the canonical declaration")
	for index: int in declaration.owner_count():
		assert_true(declaration.owner_section(index) >= Digest.SECTION_ID_MIN
			and declaration.owner_section(index) <= Digest.SECTION_ID_MAX,
			"owner %d is in sections 1..14" % index)


func test_world_runtime_exclusions_are_declared_but_unhashed() -> void:
	"""REG-R01: the completed tick and the seven clock counters persist but emit no record."""
	var declaration: Digest.Declaration = Digest.production_declaration()
	var owner: int = declaration.find_owner(1, "world_runtime")
	assert_true(owner < declaration.owner_count(), "section 1 declares world_runtime")
	var hashed: PackedStringArray = PackedStringArray()
	var begin: int = declaration.owner_field_begin(owner)
	for offset: int in declaration.owner_field_count(owner):
		if declaration.field_is_hashed(begin + offset):
			hashed.append(declaration.field_key(begin + offset))
	assert_equal(declaration.owner_field_count(owner), 12, "twelve declared world_runtime fields")
	assert_equal(", ".join(hashed), "_world_seed, _seeded, _requested_speed, _pause_mask",
		"only the four non-prefix scalars are hashed")


func _owner_keys_and_types(section: int, key: String) -> PackedStringArray:
	"""Return one owner's declared field keys and type codes as two comma-joined strings."""
	var declaration: Digest.Declaration = Digest.production_declaration()
	var owner: int = declaration.find_owner(section, key)
	assert_true(owner < declaration.owner_count(), "section %d declares %s" % [section, key])
	var keys: PackedStringArray = PackedStringArray()
	var types: PackedStringArray = PackedStringArray()
	var begin: int = declaration.owner_field_begin(owner)
	for offset: int in declaration.owner_field_count(owner):
		keys.append(declaration.field_key(begin + offset))
		types.append(str(declaration.field_type(begin + offset)))
		assert_true(declaration.field_is_hashed(begin + offset),
			"%s.%s is a record" % [key, declaration.field_key(begin + offset)])
	return PackedStringArray([", ".join(keys), ", ".join(types)])


func test_construction_section_four_columns_are_declared_in_order() -> void:
	"""The sixteen category-1 project columns, occupied bitset first per ARCH-SAVE-002.

	`construction.gd` declares `_present` AFTER `_material_container_slot`; the canonical order
	hoists it to ordinal 0 exactly as (4, "needs") and (4, "buildings") do. Walking GDScript
	declaration order instead yields a digest that is stable, plausible and wrong.
	"""
	var found: PackedStringArray = _owner_keys_and_types(4, "construction")
	assert_equal(found[0], CONSTRUCTION_SECTION_FOUR_KEYS, "section 4 construction field order")
	assert_equal(found[1], CONSTRUCTION_SECTION_FOUR_TYPES, "section 4 construction type codes")


func test_construction_delivered_arena_is_its_own_section_five_owner() -> void:
	"""REQ-SET-124's delivered ledger is a CHILD_ARENA, not a project column, and is i64."""
	var found: PackedStringArray = _owner_keys_and_types(5, "construction")
	assert_equal(found[0], "_delivered_milli", "section 5 construction declares only the arena")
	assert_equal(found[1], "4", "quantity_milli is i64 (type code 4), never i32")


# --- 3. refusals ----------------------------------------------------------------------------------

func test_production_walker_refuses_because_no_owner_has_an_adapter() -> void:
	"""The deliverable refusal: 52 declared owners, 0 adapters, no digest and no subset."""
	var walker: Digest.Walker = Digest.production_walker()
	assert_false(walker.adapter_coverage_complete(), "no adapter exists yet")
	assert_equal(walker.missing_adapter_owners().size(), Digest.CANONICAL_OWNER_COUNT,
		"every declared owner is missing an adapter")
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_NO_ADAPTER), "refuses with NO_ADAPTER")
	assert_equal(result.digest.size(), 0, "a refused walk produces no digest bytes")
	assert_false(result.covers_release_state, "and never claims release coverage")


func test_missing_adapter_list_is_in_walk_order_and_names_section_and_owner() -> void:
	"""The refusal names exactly which owners have no producer, in the order they would be walked."""
	var missing: PackedStringArray = Digest.production_walker().missing_adapter_owners()
	assert_equal(missing[0], "1:buildings", "first missing owner")
	assert_equal(missing[missing.size() - 1], "14:residents", "last missing owner")
	assert_true(missing.has("11:event_schedule"), "the forward EventSchedule owner is listed")
	assert_true(missing.has("13:chronicle"), "the forward Chronicle owner is listed")


func test_one_missing_adapter_refuses_the_whole_walk() -> void:
	"""Two of three owners covered is still a refusal, not a digest over two thirds of the state."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_NO_ADAPTER), "refuses with NO_ADAPTER")
	assert_true(refusal.detail.contains("1:alpha"), "the refusal names the uncovered owner")
	assert_equal(result.digest.size(), 0, "no partial digest is produced")


func test_section_fifteen_owner_refuses_self_inclusion() -> void:
	"""REG-R01: canonical_state_hash owns section 15 and never includes itself."""
	var builder: Digest.Builder = Digest.Builder.new()
	builder.begin_owner(15, "canonical_state_hash", 1)
	builder.add_field("_digest", Digest.TYPE_U8, true, true, 32, 0)
	var refusal: Digest.Refusal = builder.seal("SELF").validate()
	assert_equal(String(refusal.code), String(Digest.REFUSE_SELF_INCLUSION), "self inclusion refuses")
	assert_true(refusal.detail.contains("never its own input"), "the refusal says why")


func test_section_outside_one_to_fourteen_refuses() -> void:
	"""Section 0 and section 16 are both outside the record range."""
	for section: int in [0, 16, 255]:
		var builder: Digest.Builder = Digest.Builder.new()
		builder.begin_owner(section, "owner", 1)
		builder.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
		assert_equal(String(builder.seal("BAD").validate().code),
			String(Digest.REFUSE_SECTION_RANGE), "section %d refuses" % section)


func test_owners_out_of_ascii_order_refuse() -> void:
	""""alpha" before "Zed" is case-insensitive order, not ASCII order, and must refuse."""
	var builder: Digest.Builder = Digest.Builder.new()
	builder.begin_owner(1, "alpha", 1)
	builder.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
	builder.begin_owner(1, "Zed", 1)
	builder.add_field("_g", Digest.TYPE_U8, true, true, 1, 0)
	var refusal: Digest.Refusal = builder.seal("ORDER").validate()
	assert_equal(String(refusal.code), String(Digest.REFUSE_OWNER_ORDER), "ASCII order is enforced")


func test_sections_out_of_order_refuse() -> void:
	"""Records run section 1..14 ascending; a section 14 block before a section 1 block refuses."""
	var builder: Digest.Builder = Digest.Builder.new()
	builder.begin_owner(14, "residents", 1)
	builder.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
	builder.begin_owner(1, "buildings", 1)
	builder.add_field("_g", Digest.TYPE_U8, true, true, 1, 0)
	assert_equal(String(builder.seal("ORDER").validate().code),
		String(Digest.REFUSE_OWNER_ORDER), "descending section order refuses")


func test_duplicate_owner_and_duplicate_field_refuse() -> void:
	"""(section, owner_key) is unique, and so is a field key inside one owner."""
	var owners: Digest.Builder = Digest.Builder.new()
	owners.begin_owner(1, "same", 1)
	owners.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
	owners.begin_owner(1, "same", 1)
	owners.add_field("_g", Digest.TYPE_U8, true, true, 1, 0)
	assert_equal(String(owners.seal("DUP").validate().code),
		String(Digest.REFUSE_OWNER_DUPLICATE), "a repeated owner refuses")
	var fields: Digest.Builder = Digest.Builder.new()
	fields.begin_owner(1, "owner", 1)
	fields.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
	fields.add_field("_f", Digest.TYPE_U8, true, true, 1, 0)
	assert_equal(String(fields.seal("DUP").validate().code),
		String(Digest.REFUSE_FIELD_DUPLICATE), "a repeated field key refuses")


func test_ascii_compare_is_byte_order_not_case_folded() -> void:
	"""'Z' is 0x5A and 'a' is 0x61, so "Zed" sorts before "alpha" and a prefix before its extension."""
	assert_equal(Digest.ascii_compare("Zed", "alpha"), -1, "uppercase Z precedes lowercase a")
	assert_equal(Digest.ascii_compare("alpha", "Zed"), 1, "and the reverse")
	assert_equal(Digest.ascii_compare("jobs", "jobs"), 0, "equal keys compare equal")
	assert_equal(Digest.ascii_compare("job", "jobs"), -1, "a prefix precedes its extension")
	assert_equal(Digest.ascii_compare("work", "weather"), 1, "ordinary ASCII order still holds")


func test_type_five_without_a_declared_cap_refuses() -> void:
	"""S2: "u32 is not an allocation permission"; a string field needs its own byte cap."""
	var builder: Digest.Builder = Digest.Builder.new()
	builder.begin_owner(14, "residents", 1)
	builder.add_field("_name_key", Digest.TYPE_UTF8_U32, true, true, 1, 0)
	var refusal: Digest.Refusal = builder.seal("NOCAP").validate()
	assert_equal(String(refusal.code), String(Digest.REFUSE_STRING_CAP_UNDECLARED),
		"an uncapped string field refuses")


func test_type_five_value_over_its_declared_cap_refuses() -> void:
	"""A name longer than its declared cap refuses instead of being truncated or hashed anyway."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_excluded_tick", Digest.STORAGE_INT64, PackedInt64Array([0]), 1)
	adapter.add("_cursor", Digest.STORAGE_INT32, PackedInt32Array([1]), 1)
	adapter.add("_name", Digest.STORAGE_TEXT, PackedStringArray(["", "A".repeat(129)]), 2)
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(1, "alpha", adapter)
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_VALUE_RANGE), "an over-cap name refuses")
	assert_equal(result.digest.size(), 0, "and produces no digest")


func test_storage_form_must_match_the_declared_type() -> void:
	"""An i32 field handed a byte column refuses; the walker never widens or reinterprets silently."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_zulu", Digest.STORAGE_BYTE, PackedByteArray([1, 2, 3]), 3)
	adapter.add("_alpha", Digest.STORAGE_BYTE, PackedByteArray([0, 255]), 2)
	walker.register_owner(1, "Zed", adapter)
	walker.register_owner(1, "alpha", _adapter_alpha())
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_STORAGE_MISMATCH), "storage is checked")


func test_value_count_must_match_a_declared_count() -> void:
	"""A field whose shape declares three values refuses when the adapter supplies two."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_zulu", Digest.STORAGE_INT32, PackedInt32Array([1, 2, 3]), 2)
	adapter.add("_alpha", Digest.STORAGE_BYTE, PackedByteArray([0, 255]), 2)
	walker.register_owner(1, "Zed", adapter)
	walker.register_owner(1, "alpha", _adapter_alpha())
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(_fixture_inputs(), result, 0).code),
		String(Digest.REFUSE_VALUE_COUNT), "a short column refuses")


func test_u32_logical_value_out_of_range_refuses() -> void:
	"""A u32 field carried as i64 is range-checked against 0..4294967295, not masked."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_excluded_tick", Digest.STORAGE_INT64, PackedInt64Array([0]), 1)
	adapter.add("_cursor", Digest.STORAGE_INT64, PackedInt64Array([SaveCodec.UINT32_MAX + 1]), 1)
	adapter.add("_name", Digest.STORAGE_TEXT, PackedStringArray(["", ""]), 2)
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(1, "alpha", adapter)
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(_fixture_inputs(), result, 0).code),
		String(Digest.REFUSE_VALUE_RANGE), "4294967296 is not a u32")


func test_u32_logical_value_at_the_boundary_is_accepted() -> void:
	"""0 and 4294967295 are both in range; only the value beyond the top refuses."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_excluded_tick", Digest.STORAGE_INT64, PackedInt64Array([0]), 1)
	adapter.add("_cursor", Digest.STORAGE_INT64, PackedInt64Array([SaveCodec.UINT32_MAX]), 1)
	adapter.add("_name", Digest.STORAGE_TEXT, PackedStringArray(["", ""]), 2)
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(1, "alpha", adapter)
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(_fixture_inputs(), result, CAPTURE_CAP).code), "",
		"4294967295 is a valid u32")
	var cursor_record: String = "5f637572736f7201" + "0100000000000000" + "ffffffff"
	assert_true(result.captured_stream.hex_encode().contains(cursor_record), "and emits ffffffff")


func test_negative_u64_refuses_rather_than_emitting_a_huge_value() -> void:
	"""GDScript cannot hold the upper half of the u64 range; a negative u64 is a refusal."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var adapter: FixtureAdapter = FixtureAdapter.new()
	adapter.add("_big", Digest.STORAGE_INT64, PackedInt64Array([-1]), 1)
	adapter.add("_debt", Digest.STORAGE_INT64, PackedInt64Array([-1]), 1)
	walker.register_owner(1, "Zed", _adapter_zed(SaveCodec.INT32_MAX))
	walker.register_owner(1, "alpha", _adapter_alpha())
	walker.register_owner(14, "residents", adapter)
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(_fixture_inputs(), result, 0).code),
		String(Digest.REFUSE_VALUE_RANGE), "a negative u64 refuses")


func test_adapter_refusal_propagates_and_names_the_field() -> void:
	"""An owner that cannot supply a declared field fails the whole walk, with its own code shown."""
	var adapter: FixtureAdapter = _adapter_zed(SaveCodec.INT32_MAX)
	adapter.refused_key = "_alpha"
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	walker.register_owner(1, "Zed", adapter)
	walker.register_owner(1, "alpha", _adapter_alpha())
	walker.register_owner(14, "residents", _adapter_residents())
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_ADAPTER_REFUSED), "adapter refusal wins")
	assert_true(refusal.detail.contains("_alpha"), "the refusal names the field")


func test_registering_an_undeclared_owner_refuses() -> void:
	"""An adapter for an owner the declaration does not list is an unregistered field, not a bonus."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	var refusal: Digest.Refusal = walker.register_owner(1, "ghost", _adapter_zed(0))
	assert_equal(String(refusal.code), String(Digest.REFUSE_UNREGISTERED_OWNER), "unknown owner")
	var wrong_section: Digest.Refusal = walker.register_owner(4, "Zed", _adapter_zed(0))
	assert_equal(String(wrong_section.code), String(Digest.REFUSE_UNREGISTERED_OWNER),
		"the same key in another section is a different owner")


func test_duplicate_and_malformed_adapter_registration_refuse() -> void:
	"""One adapter per owner, and it must expose the documented interface."""
	var walker: Digest.Walker = Digest.Walker.new(_fixture_declaration(false))
	assert_equal(String(walker.register_owner(1, "Zed", _adapter_zed(0)).code), "", "first wins")
	assert_equal(String(walker.register_owner(1, "Zed", _adapter_zed(0)).code),
		String(Digest.REFUSE_DUPLICATE_ADAPTER), "a second adapter refuses")
	assert_equal(String(walker.register_owner(1, "alpha", RefCounted.new()).code),
		String(Digest.REFUSE_ADAPTER_INTERFACE), "an object without the method refuses")
	assert_equal(String(walker.register_owner(14, "residents", null).code),
		String(Digest.REFUSE_ADAPTER_INTERFACE), "null refuses")


func test_short_compatibility_digest_refuses() -> void:
	"""Each of the four identities is exactly 32 raw bytes; 31 or 0 refuses before any hashing."""
	var walker: Digest.Walker = _fixture_walker(false, SaveCodec.INT32_MAX)
	var inputs: Digest.Inputs = _fixture_inputs()
	inputs.map_digest = PackedByteArray()
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(inputs, result, 0)
	assert_equal(String(refusal.code), String(Digest.REFUSE_DIGEST_LENGTH), "empty map digest refuses")
	assert_true(refusal.detail.contains("map"), "the refusal names which identity was wrong")


func test_engine_identity_line_rules_are_enforced() -> void:
	"""Nonempty, printable ASCII, one final LF, at most 256 UTF-8 bytes including that LF."""
	for line: String in ["", "4.7.2.stable.official.ed1daf0bf", "4.7.2.stable.official.Mó\n",
			"A".repeat(256) + "\n"]:
		var walker: Digest.Walker = _fixture_walker(false, SaveCodec.INT32_MAX)
		var inputs: Digest.Inputs = _fixture_inputs()
		inputs.engine_identity_line = line
		var result: Digest.DigestResult = Digest.DigestResult.new()
		assert_equal(String(walker.digest_into(inputs, result, 0).code),
			String(Digest.REFUSE_ENGINE_IDENTITY), "engine line %d bytes refuses" % line.length())


func test_negative_completed_tick_refuses() -> void:
	"""The prefix tick is an i64 but a negative one is not a state a save can be in."""
	var walker: Digest.Walker = _fixture_walker(false, SaveCodec.INT32_MAX)
	var inputs: Digest.Inputs = _fixture_inputs()
	inputs.completed_tick = -1
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(inputs, result, 0).code),
		String(Digest.REFUSE_NEGATIVE_TICK), "a negative completed tick refuses")


func test_completed_tick_enters_the_prefix_and_changes_the_digest() -> void:
	"""The tick is hashed exactly once, in the prefix; a different tick is a different digest."""
	var walker: Digest.Walker = _fixture_walker(false, SaveCodec.INT32_MAX)
	var inputs: Digest.Inputs = _fixture_inputs()
	inputs.completed_tick = FIXTURE_COMPLETED_TICK + 1
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(walker.digest_into(inputs, result, CAPTURE_CAP).code), "", "still a valid walk")
	assert_false(result.digest.hex_encode() == FIXTURE_DIGEST_HEX, "a later tick digests differently")
	assert_equal(result.captured_stream.size(), FIXTURE_STREAM_BYTES, "the stream length is unchanged")


func test_capture_limit_refuses_rather_than_truncating() -> void:
	"""A capture cap below the stream size refuses; a truncated capture beside a digest is a lie."""
	var walker: Digest.Walker = _fixture_walker(false, SaveCodec.INT32_MAX)
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = walker.digest_into(_fixture_inputs(), result, 64)
	assert_equal(String(refusal.code), String(Digest.REFUSE_CAPTURE_LIMIT), "an overflowing capture refuses")
	assert_equal(result.captured_stream.size(), 0, "and returns no partial capture")


func test_verify_accepts_the_pinned_digest_and_refuses_any_other() -> void:
	"""Verification recomputes and compares; a one-byte difference in the stored digest refuses."""
	var expected: PackedByteArray = _repeated_byte(0)
	var pinned: PackedByteArray = FIXTURE_DIGEST_HEX.hex_decode()
	var result: Digest.DigestResult = Digest.DigestResult.new()
	assert_equal(String(_fixture_walker(false, SaveCodec.INT32_MAX).verify(_fixture_inputs(),
		pinned, result).code), "", "verification accepts the pinned digest")
	assert_equal(result.digest.hex_encode(), FIXTURE_DIGEST_HEX, "and returns it")
	var mismatch: Digest.Refusal = _fixture_walker(false, SaveCodec.INT32_MAX).verify(
		_fixture_inputs(), expected, result)
	assert_equal(String(mismatch.code), String(Digest.REFUSE_DIGEST_MISMATCH), "a wrong digest refuses")
	assert_equal(result.digest.size(), 0, "and clears the result")


func test_verify_refuses_a_wrong_length_expected_digest() -> void:
	"""Section 15 is exactly 32 raw bytes; anything else is refused before recomputation."""
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var refusal: Digest.Refusal = _fixture_walker(false, SaveCodec.INT32_MAX).verify(
		_fixture_inputs(), PackedByteArray([1, 2, 3]), result)
	assert_equal(String(refusal.code), String(Digest.REFUSE_DIGEST_LENGTH), "3 bytes is not a digest")


func test_stream_tag_is_eleven_bytes_with_no_terminator() -> void:
	"""SAVE-R09: "Eleven ASCII bytes `RWL-STATE-1`, NO terminating zero byte"."""
	assert_equal(Digest.STREAM_TAG.to_utf8_buffer().size(), Digest.STREAM_TAG_BYTES, "eleven bytes")
	assert_true(FIXTURE_STREAM_HEX.begins_with("52574c2d53544154452d31"),
		"the stream opens with RWL-STATE-1 and no NUL")
	assert_false(FIXTURE_STREAM_HEX.begins_with("52574c2d53544154452d3100"), "no terminating zero")


func test_module_has_no_float_and_no_dictionary() -> void:
	"""Integer-authoritative state: no float and no key-value map in the walker's executable code.

	Comment lines are stripped first, because the module's own header explains WHY there is no
	such type and would otherwise match its own prohibition.
	"""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/canonical_state_hash.gd")
	assert_false(source.is_empty(), "the module source must be readable")
	var code: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	var body: String = "\n".join(code)
	for banned: String in [": float", "-> float", "Dictionary", "PackedFloat32Array",
			"PackedFloat64Array", "float(", "JSON."]:
		assert_false(body.contains(banned), "canonical_state_hash.gd must not contain '%s'" % banned)


func test_economic_high_declaration_and_value_preserve_exhaustion() -> void:
	"""Production ordinal 2 uses u64; a bounded field adapter proves its actual eight-byte emission."""
	var data: Dictionary = _registry()
	assert_equal(int((data["section_schema_versions"] as Array)[11]), 3, "registry section12 schema")
	assert_equal(Section12.SECTION_SCHEMA_VERSION, 3, "codec section12 schema")
	var declaration: Digest.Declaration = Digest.production_declaration()
	var owner: int = declaration.find_owner(12, "commands")
	assert_true(owner >= 0, "commands remains declared")
	assert_equal(declaration.owner_schema_version(owner), 2, "commands owner schema")
	assert_equal(declaration.owner_field_count(owner), 20, "no added or removed fields")
	var index: int = declaration.owner_field_begin(owner) + 2
	assert_equal(declaration.field_key(index), "_next_sequence_high", "ordinal remains two")
	assert_equal(declaration.field_type(index), 3, "type is u64")
	assert_true(declaration.field_is_hashed(index), "allocator remains authoritative")
	assert_true(declaration.field_has_declared_count(index), "fixed scalar count")
	assert_equal(declaration.field_declared_count(index), 1, "one scalar")
	var hashes: Array[PackedByteArray] = []
	for high: int in [4294967295, 4294967296]:
		var builder: Digest.Builder = Digest.Builder.new()
		builder.begin_owner(12, "commands", declaration.owner_schema_version(owner))
		builder.add_field(declaration.field_key(index), declaration.field_type(index), true, true, 1, 0)
		var adapter: FixtureAdapter = FixtureAdapter.new()
		adapter.add("_next_sequence_high", Digest.STORAGE_INT64, PackedInt64Array([high]), 1)
		var walker: Digest.Walker = Digest.Walker.new(builder.seal("SEQ-FIELD-FIXTURE"))
		walker.register_owner(12, "commands", adapter)
		var result: Digest.DigestResult = _walk_fixture(walker, CAPTURE_CAP)
		var expected: String = "ffffffff00000000" if high == 4294967295 else "0000000001000000"
		assert_equal(result.captured_stream.slice(result.captured_stream.size() - 8).hex_encode(),
			expected, "pinned eight-byte value; no u32 truncation")
		hashes.append(result.digest)
	assert_true(hashes[0] != hashes[1], "final available high and exhausted high hash differently")
