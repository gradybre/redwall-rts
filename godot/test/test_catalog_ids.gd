extends "res://test/framework/test_case.gd"
## Coverage for the `catalog_ids.json` artifact: ruling §10B's acceptance list, item by item.
##
## §10B's acceptance sentence is the spine of this suite: "different definition insertion orders
## give identical artifact bytes/hash; a one-byte/key/ID mutation fails; fixed enums and reserved
## slots survive; JSON duplicate keys are rejected; altered numeric definitions cannot masquerade
## as an unchanged ruleset merely because the ID mapping is unchanged; a load mismatch leaves the
## current world intact."
##
## THE COMMITTED BYTES ARE PINNED BELOW. That is deliberate. The digest is the save header's
## offset-72 catalog hash, so moving it is an intentional ID/schema change that invalidates every
## save written against the old one -- exactly the event the ruling requires to be recorded rather
## than absorbed. A test failing here is the alarm working, not noise: regenerate with
## `./tools/generate_catalog_ids.sh`, update these four constants, and say so.

const CatalogIds := preload("res://scripts/core/catalog_ids.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

## Moved 2026-09-10 by decision 0042, which added ARCH-CMD-003's CommandKind domain: 2588 bytes /
## 21 domains / 182 rows / 73d34d26af1f690261957ef27c0e5a14a5462d5d57b2f55a84b69e5fa900a3bd before
## it. Moved again 2026-09-11 by decision 0056, which added the four starter-colony domains
## BuildingDefinition (30 rows), FurnitureDefinition (9), RoomType (8) and BuildingState (6):
## 3064 bytes / 22 domains / 206 rows /
## 00e3ffd5c98b5f5da050cc13be91895b85744eb3b3f3cfb5e50dde85a598cbf1 before it. Moved a third time
## 2026-09-11 by decision 0080, which published the protected Milestone domain (5 rows) and the
## compiled Station service domain (11): 3869 bytes / 26 domains / 259 rows /
## ead6a8ac6c67bb4b0d9b320a2414cc477f252b5f9cdf8bb3e1e0b8cc593eecf4 before it. All three are an
## INTENTIONAL CATALOG/SCHEMA CHANGE, not a parity result -- every save written
## against the old digest refuses until an explicit migration exists, which is the alarm working.
const COMMITTED_BYTE_LENGTH: int = 4062
const COMMITTED_SHA256: String = \
	"3407b52e4db6fb19874d8ea3a3d636e46575def0048b513558f7a5d3894c3e90"
const COMMITTED_DOMAIN_COUNT: int = 28
const COMMITTED_ROW_COUNT: int = 275

## Every domain the artifact carries, in the ascending ASCII order it is written in.
const COMMITTED_DOMAINS: Array[String] = [
	"Activity", "BuildingDefinition", "BuildingState", "CommandKind", "CropDefinition",
	"CropFamily", "CropState", "EventDefinition", "ForageQuotaMode", "FurnitureDefinition",
	"HabitatType", "ItemCategory", "ItemDefinition", "ItemEffect", "JobKind",
	"JobState", "Milestone", "OrderMode", "Quality", "RoomType", "ScheduleTemplate", "Season",
	"Severity", "Soil", "SpeciesDefinition", "Speed", "Station", "ZoneType",
]

## The exact canonical encoding of a two-domain toy map, written out by hand: sorted at both
## levels, not one byte of whitespace, one final LF.
const TOY_CANONICAL: String = \
	"{\"domains\":{\"Alpha\":{\"Z\":0,\"a\":1},\"beta\":{\"x\":2}}," \
	+ "\"ruleset\":\"settlement_rules_v2\",\"schema_version\":1}\n"

var _artifact_cache: CatalogIds.Artifact = null


# --- helpers -------------------------------------------------------------------------------------

func _artifact() -> CatalogIds.Artifact:
	"""The artifact built from the live registries, built once and reused across this suite."""
	if _artifact_cache == null:
		var built: CatalogIds.BuildResult = CatalogIds.build()
		assert_true(built.ok, "build() must succeed (%s: %s)" % [built.error, built.detail])
		_artifact_cache = built.artifact
	return _artifact_cache


func _canonical_text() -> String:
	"""The artifact's canonical text with its final LF removed, ready for byte surgery."""
	var bytes: PackedByteArray = _artifact().bytes
	return bytes.slice(0, bytes.size() - 1).get_string_from_ascii()


func _document(text: String) -> PackedByteArray:
	"""Canonical-shaped bytes: `text` followed by exactly one LF."""
	return (text + "\n").to_utf8_buffer()


func _edited(needle: String, replacement: String) -> PackedByteArray:
	"""The artifact's bytes with one unique substring replaced, still ending in one LF."""
	var text: String = _canonical_text()
	assert_equal(text.count(needle), 1, "'%s' must occur exactly once in the artifact" % needle)
	return _document(text.replace(needle, replacement))


func _assert_refuses(bytes: PackedByteArray, expected: StringName, label: String) -> void:
	"""Assert verification refuses these bytes with exactly this code and reports no rows."""
	var result: CatalogIds.VerifyResult = CatalogIds.verify_bytes(bytes)
	assert_false(result.ok, "%s must be refused" % label)
	assert_equal(result.error, expected, "%s refusal code (detail: %s)" % [label, result.detail])
	assert_equal(result.row_count, 0, "%s must report no rows" % label)


func _assert_map_equals(actual: Dictionary, expected: Dictionary, label: String) -> void:
	"""Compare two key -> id maps entry by entry, never relying on Dictionary `==` semantics."""
	assert_equal(actual.size(), expected.size(), "%s entry count" % label)
	for key: Variant in expected.keys():
		assert_true(actual.has(String(key)), "%s must carry key '%s'" % [label, key])
		if actual.has(String(key)):
			assert_equal(int(actual[String(key)]), int(expected[key]), "%s['%s']" % [label, key])


func _domain(domain_name: String) -> Dictionary:
	"""One domain's key -> id map out of the built artifact."""
	var domains: Dictionary = _artifact().domains
	assert_true(domains.has(domain_name), "the artifact must carry domain '%s'" % domain_name)
	return domains[domain_name] if domains.has(domain_name) else {}


func _reordered(domains: Dictionary, rotation: int) -> Dictionary:
	"""Rebuild every object in the map with its keys inserted in a rotated, non-sorted order."""
	var out: Dictionary = {}
	for name: String in _rotated(domains.keys(), rotation):
		var entries: Dictionary = domains[name]
		var copy: Dictionary = {}
		for key: String in _rotated(entries.keys(), rotation):
			copy[key] = entries[key]
		out[name] = copy
	return out


func _rotated(keys: Array, rotation: int) -> Array[String]:
	"""The keys as Strings, reversed and then rotated, so insertion order is never sorted order."""
	var names: Array[String] = []
	for key: Variant in keys:
		names.append(String(key))
	names.reverse()
	var size: int = names.size()
	var shift: int = 0 if size == 0 else rotation % size
	return names.slice(shift) + names.slice(0, shift) as Array[String]


# --- the central property: insertion order cannot reach the bytes --------------------------------

func test_shuffled_registry_order_produces_identical_bytes_and_digest() -> void:
	"""§10B acceptance: different definition insertion orders give identical artifact bytes/hash.

	The build registry is handed to build() reversed and in three rotations. A digest that moved
	with registry order would be worthless as a save-header identity.
	"""
	var expected: CatalogIds.Artifact = _artifact()
	for rotation: int in [1, 5, 13, 20]:
		var order: Array[String] = _rotated(CatalogIds.registered_domains(), rotation)
		var built: CatalogIds.BuildResult = CatalogIds.build(order)
		assert_true(built.ok, "rotation %d must build (%s)" % [rotation, built.error])
		if not built.ok:
			continue
		assert_equal(built.artifact.bytes, expected.bytes, "rotation %d bytes" % rotation)
		assert_equal(built.artifact.digest_hex(), expected.digest_hex(),
			"rotation %d digest" % rotation)


func test_shuffled_entry_insertion_order_produces_identical_bytes() -> void:
	"""Insertion order INSIDE each domain is equally powerless: the encoder sorts every object.

	The registry-order test above only permutes domain names. This one rebuilds every entry
	dictionary in a rotated order, which is what a Dictionary iteration leaking into the encoder
	would actually look like.
	"""
	var expected: CatalogIds.Artifact = _artifact()
	for rotation: int in [1, 3, 9]:
		var scrambled: Dictionary = _reordered(expected.domains, rotation)
		var bytes: PackedByteArray = CatalogIds.encode_canonical(scrambled)
		assert_equal(bytes, expected.bytes, "rotation %d re-encoded bytes" % rotation)
		assert_equal(CatalogIds.digest_of(bytes).hex_encode(), expected.digest_hex(),
			"rotation %d digest" % rotation)


func test_encode_canonical_writes_the_exact_canonical_form() -> void:
	"""Sorted at every level, no insignificant whitespace, one final LF, plain decimal integers.

	A two-domain toy map whose insertion order is deliberately wrong at both levels, checked
	against a hand-written expected string rather than against the encoder's own output.
	"""
	var toy: Dictionary = {"beta": {"x": 2}, "Alpha": {"a": 1, "Z": 0}}
	var bytes: PackedByteArray = CatalogIds.encode_canonical(toy)
	assert_equal(bytes.get_string_from_utf8(), TOY_CANONICAL, "canonical encoding of the toy map")
	assert_equal(bytes[bytes.size() - 1], 0x0a, "the last byte is one LF")
	assert_equal(bytes.slice(0, bytes.size() - 1).count(0x0a), 0, "no other LF anywhere")
	assert_equal(bytes.count(0x20), 0, "no space anywhere")
	assert_equal(bytes.count(0x09), 0, "no tab anywhere")


func test_generated_artifact_matches_the_committed_file_byte_for_byte() -> void:
	"""The committed `godot/data/catalog_ids.json` is what these registries generate today."""
	var result: CatalogIds.VerifyResult = CatalogIds.verify_file()
	assert_true(result.ok, "verify_file() (%s: %s)" % [result.error, result.detail])
	assert_equal(result.row_count, COMMITTED_ROW_COUNT, "verified row count")
	var file: FileAccess = FileAccess.open(CatalogIds.ARTIFACT_PATH, FileAccess.READ)
	assert_not_null(file, "the committed artifact must open")
	if file == null:
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	assert_equal(bytes, _artifact().bytes, "the committed file equals the generated bytes")


func test_committed_length_digest_domains_and_row_count_are_pinned() -> void:
	"""The artifact is 4062 bytes, 28 domains, 275 entries, and hashes to the recorded SHA-256."""
	var artifact: CatalogIds.Artifact = _artifact()
	assert_equal(artifact.bytes.size(), COMMITTED_BYTE_LENGTH, "artifact byte length")
	assert_equal(artifact.digest_hex(), COMMITTED_SHA256, "artifact SHA-256")
	assert_equal(artifact.digest.size(), CatalogIds.DIGEST_BYTES, "digest is 32 raw bytes")
	assert_equal(artifact.domains.size(), COMMITTED_DOMAIN_COUNT, "domain count")
	assert_equal(artifact.row_count, COMMITTED_ROW_COUNT, "row_count across all domains")
	var counted: int = 0
	for name: String in COMMITTED_DOMAINS:
		assert_true(artifact.domains.has(name), "the artifact must carry '%s'" % name)
		if artifact.domains.has(name):
			counted += (artifact.domains[name] as Dictionary).size()
	assert_equal(counted, COMMITTED_ROW_COUNT, "the named domains account for every entry")


func test_registered_domains_is_exactly_the_committed_domain_list() -> void:
	"""The build registry and the committed artifact name the same 28 domains, and no others."""
	var registered: Array[String] = CatalogIds.registered_domains()
	assert_equal(registered.size(), COMMITTED_DOMAIN_COUNT, "registered domain count")
	var sorted_names: Array[String] = registered.duplicate()
	sorted_names.sort()
	assert_equal(sorted_names, COMMITTED_DOMAINS, "registered domains in ascending ASCII order")
	for name: String in COMMITTED_DOMAINS:
		assert_true(registered.has(name), "'%s' must be registered" % name)


# --- one-byte, one-key and one-ID mutations ------------------------------------------------------

func test_one_byte_mutation_fails_verification() -> void:
	"""§10B acceptance: a one-byte mutation fails. Every offset probed, none accepted."""
	var pristine: PackedByteArray = _artifact().bytes
	for offset: int in [0, 1, 12, 400, 1300, 2000, pristine.size() - 3, pristine.size() - 1]:
		var mutated: PackedByteArray = pristine.duplicate()
		mutated[offset] = mutated[offset] ^ 0x01
		var result: CatalogIds.VerifyResult = CatalogIds.verify_bytes(mutated)
		assert_false(result.ok, "a byte flipped at offset %d must be refused" % offset)
		assert_false(result.error == CatalogIds.REFUSE_NONE, "offset %d names a code" % offset)


func test_one_key_mutation_fails_verification() -> void:
	"""§10B acceptance: a one-key mutation fails, with a key-level refusal rather than a shrug."""
	_assert_refuses(_edited("\"SLEEP\"", "\"SLUMBER\""), CatalogIds.REFUSE_KEY_MISMATCH,
		"a renamed Activity key")
	_assert_refuses(_edited(",\"WASTE\":10", ""), CatalogIds.REFUSE_KEY_MISMATCH,
		"a deleted ItemCategory key")


func test_one_id_mutation_fails_verification() -> void:
	"""§10B acceptance: a one-ID mutation fails, and the refusal names the id, not just the bytes."""
	_assert_refuses(_edited("\"SLEEP\":0", "\"SLEEP\":7"), CatalogIds.REFUSE_ID_MISMATCH,
		"a renumbered Activity id")
	_assert_refuses(_edited("\"QUADRUPLE\":4", "\"QUADRUPLE\":3"), CatalogIds.REFUSE_ID_MISMATCH,
		"Speed's reserved gap filled in")


func test_verification_compares_bytes_not_a_reparsed_structure() -> void:
	"""The loader compares EXACT canonical bytes. `-0` is the witness that it really does.

	`-0` is valid JSON for the integer 0, so this document parses to a mapping identical to the
	installed one: the assertions below prove that first. A loader that re-parsed and compared
	structures would accept it, and the digest it then vouched for would cover different bytes
	from the ones on disk. Only the byte comparison refuses it.
	"""
	var bytes: PackedByteArray = _edited("\"CEREAL\":0", "\"CEREAL\":-0")
	var parsed: CatalogIds.ParseResult = CatalogIds.parse_canonical(bytes)
	assert_true(parsed.ok, "`-0` parses as valid JSON (%s: %s)" % [parsed.error, parsed.detail])
	if not parsed.ok:
		return
	assert_equal(parsed.row_count, COMMITTED_ROW_COUNT, "it parses to the same row count")
	_assert_map_equals(parsed.domains["CropFamily"], _domain("CropFamily"), "reparsed CropFamily")
	assert_equal(CatalogIds.compare_domains(parsed.domains, _artifact().domains).code,
		CatalogIds.REFUSE_NONE, "a structural comparison finds nothing wrong")
	assert_false(bytes == _artifact().bytes, "yet the bytes differ")
	_assert_refuses(bytes, CatalogIds.REFUSE_BYTES_MISMATCH, "`-0` in place of `0`")


func test_platform_json_printing_of_the_same_mapping_is_refused() -> void:
	"""§10B: "loader verification compares exact canonical bytes, not platform pretty-printing".

	`JSON.stringify` is what a structural round-trip would emit. Indented, it differs in
	whitespace; handed a map whose insertion order is rotated, it differs in key order. Both
	parse to the identical mapping and both must be refused.
	"""
	var pretty: PackedByteArray = _stringified(_artifact().domains, "\t")
	assert_false(pretty == _artifact().bytes, "indented bytes differ from the artifact")
	assert_false(CatalogIds.verify_bytes(pretty).ok, "platform pretty-printing must be refused")
	var rotated: PackedByteArray = _stringified(_reordered(_artifact().domains, 3), "")
	assert_false(rotated == _artifact().bytes, "insertion-ordered bytes differ from the artifact")
	var result: CatalogIds.VerifyResult = CatalogIds.verify_bytes(rotated)
	assert_false(result.ok, "a compact re-serialisation in insertion order must be refused")
	assert_equal(result.error, CatalogIds.REFUSE_UNSORTED_KEY, "and it is refused on key order")


func _stringified(domains: Dictionary, indent: String) -> PackedByteArray:
	"""The artifact's document re-serialised by Godot's own JSON printer, plus one final LF.

	`sort_keys` is passed false explicitly. It defaults to TRUE, which quietly re-sorts every
	object and makes a scrambled map print in canonical order -- the exact accident that would
	turn this into a test of nothing.
	"""
	var document: Dictionary = {
		"domains": domains,
		"ruleset": CatalogIds.RULESET,
		"schema_version": CatalogIds.SCHEMA_VERSION,
	}
	return (JSON.stringify(document, indent, false) + "\n").to_utf8_buffer()


# --- fixed enums, reserved slots and gaps --------------------------------------------------------

func test_speed_preserves_its_gap_at_three() -> void:
	"""PAUSED 0, NORMAL 1, DOUBLE 2, QUADRUPLE 4. There is no 3x, and 3 stays empty."""
	var speed: Dictionary = _domain("Speed")
	assert_equal(speed.size(), 4, "Speed carries four entries")
	assert_equal(int(speed["PAUSED"]), 0, "PAUSED")
	assert_equal(int(speed["NORMAL"]), 1, "NORMAL")
	assert_equal(int(speed["DOUBLE"]), 2, "DOUBLE")
	assert_equal(int(speed["QUADRUPLE"]), 4, "QUADRUPLE")
	for key: String in speed.keys():
		assert_false(int(speed[key]) == 3, "no Speed key may take the reserved 3 ('%s')" % key)
	assert_true(_canonical_text().contains("\"Speed\":{\"DOUBLE\":2,\"NORMAL\":1,\"PAUSED\":0,"
		+ "\"QUADRUPLE\":4}"), "Speed is written with its gap intact")


func test_reserved_entries_survive_unchanged() -> void:
	"""JobKind.RESERVED_3 = 3 and ZoneType.RESERVED_1 = 1 are entries, not holes."""
	var job_kind: Dictionary = _domain("JobKind")
	assert_true(job_kind.has("RESERVED_3"), "JobKind carries RESERVED_3")
	assert_equal(int(job_kind["RESERVED_3"]), 3, "JobKind.RESERVED_3")
	var zone_type: Dictionary = _domain("ZoneType")
	assert_true(zone_type.has("RESERVED_1"), "ZoneType carries RESERVED_1")
	assert_equal(int(zone_type["RESERVED_1"]), 1, "ZoneType.RESERVED_1")
	_assert_refuses(_edited(",\"RESERVED_3\":3", ""), CatalogIds.REFUSE_KEY_MISMATCH,
		"a dropped reserved entry")
	_assert_refuses(_edited("\"RESERVED_1\":1", "\"RESERVED_1\":12"), CatalogIds.REFUSE_ID_MISMATCH,
		"a renumbered reserved entry")


func test_every_protected_enum_is_carried_verbatim() -> void:
	"""All fourteen protected enums appear with catalog.gd's explicit values, gaps included.

	Eleven until decision 0056 added RoomType and BuildingState, which §4.3 numbers individually
	and which are therefore protected rather than compiled from their own keys. Fourteen since
	decision 0080 added Milestone: §4.3 does not print it, but BAL-CAT-002 numbers M0..M4
	individually, which is the same "individually listed" test §4.2's closing paragraph sets."""
	assert_equal(CatalogScript.PROTECTED_ENUM_DOMAINS.size(), 14, "fourteen protected enums")
	for name: String in CatalogScript.PROTECTED_ENUM_DOMAINS:
		_assert_map_equals(_domain(name), CatalogScript.fixed_enum(name), name)


func test_compiled_enums_are_dense_ascending_ascii_ids() -> void:
	"""Every compiled enum carries 0..n-1 in ascending ASCII key order, and nothing else."""
	for name: String in CatalogScript.COMPILED_ENUM_DOMAINS:
		var entries: Dictionary = _domain(name)
		_assert_map_equals(entries, CatalogScript.compiled_enum(name), name)
		var keys: Array[String] = []
		for key: Variant in entries.keys():
			keys.append(String(key))
		keys.sort()
		for index: int in keys.size():
			assert_equal(int(entries[keys[index]]), index, "%s['%s'] is its ASCII rank"
				% [name, keys[index]])


func test_definition_domains_are_dense_ascending_ascii_ids() -> void:
	"""Every non-protected domain numbers 0..n-1 by ascending ASCII key, with no gap and no reuse."""
	for name: String in _artifact().domains.keys():
		if CatalogScript.PROTECTED_ENUM_DOMAINS.has(name):
			continue
		var entries: Dictionary = _domain(name)
		var seen: Array[int] = []
		for key: Variant in entries.keys():
			var id: int = int(entries[key])
			assert_true(id >= 0 and id < entries.size(), "%s['%s'] = %d is within 0..%d"
				% [name, key, id, entries.size() - 1])
			assert_false(seen.has(id), "%s id %d is used twice" % [name, id])
			seen.append(id)


# --- duplicate JSON keys -------------------------------------------------------------------------

func test_duplicate_json_keys_are_rejected() -> void:
	"""§10B acceptance: JSON duplicate keys are rejected, at every level of the document."""
	_assert_refuses(_edited("\"CEREAL\":0,", "\"CEREAL\":0,\"CEREAL\":0,"),
		CatalogIds.REFUSE_DUPLICATE_KEY, "a repeated entry key")
	_assert_refuses(_edited("\"Soil\":{", "\"Soil\":{\"CLAY\":1},\"Soil\":{"),
		CatalogIds.REFUSE_DUPLICATE_KEY, "a repeated domain key")
	_assert_refuses(_edited("\"schema_version\":1", "\"schema_version\":1,\"schema_version\":1"),
		CatalogIds.REFUSE_DUPLICATE_KEY, "a repeated top-level field")


func test_object_keys_must_be_in_ascending_ascii_order() -> void:
	"""Sorted keys are part of the canonical form, so a legal-JSON reordering is still refused."""
	_assert_refuses(_edited("\"CEREAL\":0,\"FIBER\":1", "\"FIBER\":1,\"CEREAL\":0"),
		CatalogIds.REFUSE_UNSORTED_KEY, "swapped entry keys")
	_assert_refuses(_edited("\"ruleset\":\"settlement_rules_v2\",\"schema_version\":1",
		"\"schema_version\":1,\"ruleset\":\"settlement_rules_v2\""),
		CatalogIds.REFUSE_UNSORTED_KEY, "swapped top-level fields")


# --- the offset-40 separation --------------------------------------------------------------------

func test_catalog_digest_cannot_prove_numeric_definitions_unchanged() -> void:
	"""§10B acceptance: an unchanged ID map is NOT an unchanged ruleset.

	CropDefinition records five keys and the ids 0..4. farming.gd's growth hours and yields are
	numeric definitions and appear nowhere in this artifact, so editing one moves no byte and no
	digest here. That is the separate offset-40 rules hash's job.
	"""
	var crops: Dictionary = _domain("CropDefinition")
	_assert_map_equals(crops, {"beans": 0, "cabbage": 1, "flax": 2, "grain": 3, "roots": 4},
		"CropDefinition")
	var ids: Array = crops.values()
	for hours: int in FarmingScript.CROP_GROWTH_HOURS:
		assert_false(ids.has(hours), "growth hours %d are not a CropDefinition id" % hours)
	for yield_milli: int in FarmingScript.CROP_BASE_YIELD_MILLI:
		assert_false(ids.has(yield_milli), "yield %d is not a CropDefinition id" % yield_milli)
	assert_false(_canonical_text().contains(str(FarmingScript.CROP_GROWTH_HOURS[3])),
		"grain's 192 growth hours appear nowhere in the artifact")


func test_the_rules_hash_lives_at_a_separate_non_overlapping_header_offset() -> void:
	"""Offset 40 is the rules hash and offset 72 is this catalog hash; the map proves only itself."""
	assert_equal(CatalogIds.SAVE_HEADER_RULES_HASH_OFFSET, 40, "rules hash offset")
	assert_equal(CatalogIds.SAVE_HEADER_CATALOG_HASH_OFFSET, 72, "catalog hash offset")
	assert_equal(CatalogIds.SAVE_HEADER_RULES_HASH_OFFSET + CatalogIds.DIGEST_BYTES,
		CatalogIds.SAVE_HEADER_CATALOG_HASH_OFFSET, "the two 32-byte digests do not overlap")
	var ok_result: CatalogIds.VerifyResult = CatalogIds.verify_bytes(_artifact().bytes)
	assert_true(ok_result.ok, "the artifact verifies (%s)" % ok_result.error)
	assert_false(ok_result.proves_rules_unchanged,
		"a catalog match must never be presented as a ruleset match")
	var bad_result: CatalogIds.VerifyResult = CatalogIds.verify_bytes(
		_edited("\"SLEEP\":0", "\"SLEEP\":7"))
	assert_false(bad_result.proves_rules_unchanged, "nor on refusal")


func test_the_digest_covers_the_canonical_bytes_and_nothing_else() -> void:
	"""`catalog_hash = SHA256(canonical catalog_ids.json bytes)`, recomputable from the map alone."""
	var artifact: CatalogIds.Artifact = _artifact()
	assert_equal(CatalogIds.digest_of(artifact.bytes), artifact.digest, "digest over the bytes")
	assert_equal(CatalogIds.digest_of(CatalogIds.encode_canonical(artifact.domains)),
		artifact.digest, "the map alone reproduces the digest")
	var shifted: PackedByteArray = artifact.bytes.duplicate()
	shifted[shifted.size() - 2] = 0x20
	assert_false(CatalogIds.digest_of(shifted) == artifact.digest, "one byte moves the digest")


# --- a load mismatch leaves the world intact -----------------------------------------------------

func test_a_load_mismatch_leaves_the_installed_catalog_and_artifact_intact() -> void:
	"""§10B acceptance: a load mismatch leaves the current world intact (GDD §4.2 abort-before-mutate).

	There is no world to mutate here yet, so this pins what a save module will rely on: the
	refusing paths write no file, hand back no mapping, and leave the installed enums and the
	committed artifact exactly as they were.
	"""
	var before: PackedByteArray = _file_bytes(CatalogIds.ARTIFACT_PATH)
	var speed_before: Dictionary = CatalogScript.fixed_enum("Speed").duplicate()
	_assert_refuses(_edited("\"SLEEP\":0", "\"SLEEP\":7"), CatalogIds.REFUSE_ID_MISMATCH,
		"a renumbered id")
	_assert_refuses(_document("{}"), CatalogIds.REFUSE_MISSING_FIELD, "an empty object")
	assert_false(CatalogIds.verify_embedded(PackedByteArray(), _artifact().digest).ok,
		"an empty section refuses")
	assert_equal(_file_bytes(CatalogIds.ARTIFACT_PATH), before, "the artifact file is untouched")
	_assert_map_equals(CatalogScript.fixed_enum("Speed"), speed_before, "Speed after refusals")
	assert_true(CatalogIds.verify_file().ok, "verification still succeeds afterwards")


func test_a_refused_build_produces_no_partial_artifact() -> void:
	"""A refused build hands back a null artifact: there is no half-built object to mistake for one."""
	var short_list: Array[String] = CatalogIds.registered_domains()
	short_list.remove_at(0)
	var missing: CatalogIds.BuildResult = CatalogIds.build(short_list)
	assert_false(missing.ok, "an omitted domain must refuse")
	assert_equal(missing.error, CatalogIds.REFUSE_MISSING_DOMAIN, "omitted-domain code")
	assert_null(missing.artifact, "no partial artifact")
	var parsed: CatalogIds.ParseResult = CatalogIds.parse_canonical(_document("{"))
	assert_false(parsed.ok, "an unterminated document must refuse")
	assert_equal(parsed.domains.size(), 0, "a refused parse yields no domains")
	assert_equal(parsed.row_count, 0, "a refused parse yields no rows")


func test_verify_embedded_validates_the_digest_before_the_mapping() -> void:
	"""The offset-72 digest is checked before the embedded mapping is trusted for anything."""
	var artifact: CatalogIds.Artifact = _artifact()
	var payload: PackedByteArray = CatalogIds.save_section_payload(artifact)
	var good: CatalogIds.VerifyResult = CatalogIds.verify_embedded(payload, artifact.digest)
	assert_true(good.ok, "a matching section and digest verify (%s: %s)" % [good.error, good.detail])
	assert_equal(good.row_count, COMMITTED_ROW_COUNT, "embedded row count")
	var corrupt: PackedByteArray = CatalogIds.save_section_payload(
		_artifact_from(_edited("\"SLEEP\":0", "\"SLEEP\":7")))
	var mismatched: CatalogIds.VerifyResult = CatalogIds.verify_embedded(corrupt, artifact.digest)
	assert_equal(mismatched.error, CatalogIds.REFUSE_DIGEST_MISMATCH,
		"the digest refuses before the mapping is inspected")
	var self_consistent: CatalogIds.VerifyResult = CatalogIds.verify_embedded(
		corrupt, CatalogIds.digest_of(corrupt.slice(CatalogIds.SECTION_LENGTH_BYTES)))
	assert_equal(self_consistent.error, CatalogIds.REFUSE_ID_MISMATCH,
		"a self-consistent digest still cannot smuggle a changed id past the catalog check")


func test_verify_embedded_refuses_a_malformed_header_digest_or_section() -> void:
	"""A wrong-length digest, a truncated section and a lying length prefix each refuse explicitly."""
	var artifact: CatalogIds.Artifact = _artifact()
	var payload: PackedByteArray = CatalogIds.save_section_payload(artifact)
	assert_equal(CatalogIds.verify_embedded(payload, PackedByteArray([1, 2])).error,
		CatalogIds.REFUSE_DIGEST_LENGTH, "a two-byte header digest")
	assert_equal(CatalogIds.verify_embedded(payload.slice(0, 3), artifact.digest).error,
		CatalogIds.REFUSE_SECTION_TRUNCATED, "a section shorter than its length prefix")
	var lying: PackedByteArray = payload.duplicate()
	lying.encode_u32(0, payload.size())
	assert_equal(CatalogIds.verify_embedded(lying, artifact.digest).error,
		CatalogIds.REFUSE_SECTION_LENGTH, "a length prefix that overstates the payload")


func test_save_section_payload_round_trips_through_its_length_prefix() -> void:
	"""ARCH-SAVE-002 section 2: a little-endian u32 byte length followed by the canonical bytes."""
	var artifact: CatalogIds.Artifact = _artifact()
	var payload: PackedByteArray = CatalogIds.save_section_payload(artifact)
	assert_equal(CatalogIds.SAVE_SECTION_ID, 2, "CATALOG_IDS is section 2")
	assert_equal(CatalogIds.SAVE_SECTION_SCHEMA_VERSION, 1, "its descriptor schema_version")
	assert_equal(payload.size(), artifact.bytes.size() + CatalogIds.SECTION_LENGTH_BYTES,
		"payload length")
	assert_equal(payload.decode_u32(0), COMMITTED_BYTE_LENGTH, "the u32 length prefix")
	assert_equal(payload[0], COMMITTED_BYTE_LENGTH & 0xff, "little-endian low byte first")
	var decoded: CatalogIds.SectionResult = CatalogIds.decode_section_payload(payload)
	assert_true(decoded.ok, "the section decodes (%s)" % decoded.error)
	assert_equal(decoded.bytes, artifact.bytes, "the decoded bytes are the canonical bytes")


func _artifact_from(bytes: PackedByteArray) -> CatalogIds.Artifact:
	"""Wrap arbitrary bytes in an Artifact, for exercising the save-section helpers with bad input."""
	return CatalogIds.Artifact.new({}, bytes, CatalogIds.digest_of(bytes), 0)


func _file_bytes(path: String) -> PackedByteArray:
	"""Every byte of a file, or an empty array when it cannot be opened."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


# --- escaping ------------------------------------------------------------------------------------

func test_short_escapes_for_quote_backslash_and_named_controls() -> void:
	"""The standard short escapes, and only those, for the characters JSON names."""
	assert_equal(CatalogIds.encode_string("a\"b"), "\"a\\\"b\"", "quote")
	assert_equal(CatalogIds.encode_string("a\\b"), "\"a\\\\b\"", "backslash")
	assert_equal(CatalogIds.encode_string(String.chr(0x08)), "\"\\b\"", "backspace")
	assert_equal(CatalogIds.encode_string(String.chr(0x0c)), "\"\\f\"", "form feed")
	assert_equal(CatalogIds.encode_string(String.chr(0x0a)), "\"\\n\"", "line feed")
	assert_equal(CatalogIds.encode_string(String.chr(0x0d)), "\"\\r\"", "carriage return")
	assert_equal(CatalogIds.encode_string(String.chr(0x09)), "\"\\t\"", "tab")
	assert_equal(CatalogIds.encode_string("/"), "\"/\"", "the solidus is not escaped")


func test_other_controls_use_lowercase_four_digit_u00xx() -> void:
	"""Every remaining C0 control is `\\u00xx` with LOWERCASE hex, never `\\u00XX` and never short.

	NUL is absent on purpose: `String.chr(0)` yields U+FFFD in Godot 4, so a NUL cannot be put
	into a GDScript String to hand to the encoder at all. The reader's side of `\\u0000` is
	covered by test_the_reader_refuses_every_non_canonical_escape.
	"""
	assert_equal(CatalogIds.encode_string(String.chr(0x01)), "\"\\u0001\"", "0x01")
	assert_equal(CatalogIds.encode_string(String.chr(0x0b)), "\"\\u000b\"", "vertical tab")
	assert_equal(CatalogIds.encode_string(String.chr(0x0e)), "\"\\u000e\"", "0x0e")
	assert_equal(CatalogIds.encode_string(String.chr(0x1b)), "\"\\u001b\"", "escape")
	assert_equal(CatalogIds.encode_string(String.chr(0x1f)), "\"\\u001f\"", "0x1f")
	assert_false(CatalogIds.encode_string(String.chr(0x1b)).contains("B"), "hex stays lowercase")
	assert_equal(CatalogIds.encode_string("Az~!"), "\"Az~!\"", "printable ASCII is literal")


func test_the_reader_refuses_every_non_canonical_escape() -> void:
	"""Uppercase hex, a redundant `\\u` for a short-escaped or printable character, and `\\x`."""
	_assert_refuses(_edited("\"CEREAL\"", "\"CE\\u0041REAL\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "an escaped printable character")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u000A\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "uppercase hex")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u000a\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "a long escape where `\\n` is canonical")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\x41\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "an invented escape")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u00\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "a truncated unicode escape")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u1f00\""),
		CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "a code point above the C0 range")


func test_a_unicode_escape_must_be_four_lowercase_hex_digits() -> void:
	"""Non-hex characters are named as non-hex BEFORE `hex_to_int()` is handed them.

	`hex_to_int()` raises an engine error on non-hex input and quietly returns a number anyway, so
	the four characters are validated first. The refusal detail is asserted, not just the code:
	both spellings refuse, and only the detail says which check caught it.
	"""
	var non_hex: CatalogIds.VerifyResult = CatalogIds.verify_bytes(
		_edited("\"CEREAL\"", "\"CEREAL\\u00zz\""))
	assert_equal(non_hex.error, CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "non-hex digits refuse")
	assert_true(non_hex.detail.contains("lowercase hexadecimal digits"),
		"non-hex digits are caught by the digit check (detail: %s)" % non_hex.detail)
	var uppercase: CatalogIds.VerifyResult = CatalogIds.verify_bytes(
		_edited("\"CEREAL\"", "\"CEREAL\\u001F\""))
	assert_equal(uppercase.error, CatalogIds.REFUSE_NONCANONICAL_ESCAPE, "uppercase hex refuses")
	assert_true(uppercase.detail.contains("lowercase hexadecimal digits"),
		"uppercase hex is caught by the same check (detail: %s)" % uppercase.detail)
	var truncated: CatalogIds.VerifyResult = CatalogIds.verify_bytes(
		_edited("\"CEREAL\"", "\"CEREAL\\u00\""))
	assert_true(truncated.detail.contains("lowercase hexadecimal digits"),
		"a short escape runs into the closing quote, which is not hex (detail: %s)"
			% truncated.detail)


func test_a_control_escape_still_has_to_pass_the_ascii_key_validator() -> void:
	"""`\\u001f` is a canonical escape but not a legal symbolic key, so it is refused as a key."""
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u001f\""),
		CatalogIds.REFUSE_INVALID_ASCII_KEY, "a control character inside a key")
	_assert_refuses(_edited("\"CEREAL\"", "\"CEREAL\\u0000\""),
		CatalogIds.REFUSE_INVALID_ASCII_KEY, "an escaped NUL inside a key")
	assert_false(CatalogIds.is_ascii_key("CEREAL" + String.chr(0x1f)), "is_ascii_key rejects it")
	# DEL is the one asymmetry between the encoder and the reader, and it is deliberate: JSON
	# requires escaping only below 0x20, so the encoder emits 0x7f literally, while the reader
	# refuses that byte outright. Pinned here because it is safe only while is_ascii_key() keeps
	# DEL out of every key and the ruleset string stays plain ASCII.
	assert_equal(CatalogIds.encode_string(String.chr(0x7f)).length(), 3, "DEL is emitted literally")
	assert_false(CatalogIds.is_ascii_key(String.chr(0x7f)), "so no key may contain a DEL")
	assert_false(CatalogIds.RULESET.contains(String.chr(0x7f)), "and the ruleset string has none")


# --- the -1 sentinel -----------------------------------------------------------------------------

func test_the_minus_one_sentinel_is_never_a_catalog_entry() -> void:
	"""GDD §4.2's empty catalog id -1 is absence. It is not generated and it is not accepted."""
	assert_equal(CatalogScript.EMPTY_CATALOG_ID, -1, "the empty catalog id")
	for name: String in _artifact().domains.keys():
		var entries: Dictionary = _artifact().domains[name]
		for key: Variant in entries.keys():
			assert_true(int(entries[key]) >= 0, "%s['%s'] is not negative" % [name, key])
	assert_false(_canonical_text().contains(":-"), "no negative integer is written anywhere")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":-1"),
		CatalogIds.REFUSE_EMPTY_SENTINEL_ID, "the -1 sentinel as an entry")


# --- refusal rules -------------------------------------------------------------------------------

func test_an_omitted_required_domain_refuses() -> void:
	"""A document missing a registered domain is refused, and so is a build asked to skip one."""
	_assert_refuses(_edited("\"Soil\":{\"CLAY\":1,\"LOAM\":0,\"SAND\":2},", ""),
		CatalogIds.REFUSE_MISSING_DOMAIN, "a document with no Soil domain")
	var short_list: Array[String] = CatalogIds.registered_domains()
	short_list.remove_at(short_list.size() - 1)
	assert_equal(CatalogIds.build(short_list).error, CatalogIds.REFUSE_MISSING_DOMAIN,
		"build() refuses an incomplete registry")


func test_an_unknown_domain_refuses() -> void:
	"""A domain this build does not compile cannot be smuggled in through the artifact."""
	_assert_refuses(_edited("\"ScheduleTemplate\":{", "\"Rumour\":{\"a\":0},\"ScheduleTemplate\":{"),
		CatalogIds.REFUSE_UNKNOWN_DOMAIN, "an unregistered domain in the document")
	var extra: Array[String] = CatalogIds.registered_domains()
	extra.append("Rumour")
	assert_equal(CatalogIds.build(extra).error, CatalogIds.REFUSE_UNKNOWN_DOMAIN,
		"build() refuses an unregistered domain")
	var repeated: Array[String] = CatalogIds.registered_domains()
	repeated.append("Soil")
	assert_equal(CatalogIds.build(repeated).error, CatalogIds.REFUSE_DUPLICATE_KEY,
		"build() refuses the same domain twice")


func test_non_integer_ids_refuse() -> void:
	"""An id must be a JSON integer: not a string, not a float, not a boolean, not an object."""
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":\"0\""),
		CatalogIds.REFUSE_NON_INTEGER_ID, "a quoted id")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":0.0"),
		CatalogIds.REFUSE_NON_INTEGER_ID, "a fractional id")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":1e2"),
		CatalogIds.REFUSE_NON_INTEGER_ID, "an exponent id")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":true"),
		CatalogIds.REFUSE_UNEXPECTED_TOKEN, "a boolean id")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":{\"a\":0}"),
		CatalogIds.REFUSE_NON_INTEGER_ID, "a nested object as an id")


func test_out_of_range_ids_refuse() -> void:
	"""Ids are int32 and non-negative: 2^31 and an eleven-digit number are both refused."""
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":2147483648"),
		CatalogIds.REFUSE_ID_OUT_OF_RANGE, "int32 max plus one")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":99999999999"),
		CatalogIds.REFUSE_ID_OUT_OF_RANGE, "an eleven-digit id")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":-2"),
		CatalogIds.REFUSE_ID_OUT_OF_RANGE, "a negative id")
	assert_equal(CatalogIds.INT32_MAX, 2147483647, "int32 max")


func test_duplicate_ids_within_a_domain_refuse() -> void:
	"""Two keys in one domain may not share an id, however legal the JSON is."""
	_assert_refuses(_edited("\"FIBER\":1", "\"FIBER\":0"),
		CatalogIds.REFUSE_DUPLICATE_ID, "two CropFamily keys on id 0")
	var clash: CatalogIds.Refusal = _validate({"Toy": {"a": 0, "b": 0}})
	assert_equal(clash.code, CatalogIds.REFUSE_DUPLICATE_ID, "validate_domains sees the clash")
	assert_equal(_validate({"Toy": {"a": 0, "b": 1}}).code, CatalogIds.REFUSE_NONE,
		"distinct ids are fine")


func test_unknown_schema_versions_refuse() -> void:
	"""schema_version 1 is the only version this build accepts, and it must be an integer."""
	assert_equal(CatalogIds.SCHEMA_VERSION, 1, "the accepted schema version")
	_assert_refuses(_edited("\"schema_version\":1", "\"schema_version\":2"),
		CatalogIds.REFUSE_UNKNOWN_SCHEMA_VERSION, "schema_version 2")
	_assert_refuses(_edited("\"schema_version\":1", "\"schema_version\":0"),
		CatalogIds.REFUSE_UNKNOWN_SCHEMA_VERSION, "schema_version 0")
	_assert_refuses(_edited("\"schema_version\":1", "\"schema_version\":\"1\""),
		CatalogIds.REFUSE_UNKNOWN_SCHEMA_VERSION, "a quoted schema_version")
	_assert_refuses(_edited(",\"schema_version\":1", ""),
		CatalogIds.REFUSE_MISSING_FIELD, "no schema_version at all")


func test_a_foreign_or_missing_ruleset_refuses() -> void:
	"""The artifact belongs to settlement_rules_v2 and says so."""
	assert_equal(CatalogIds.RULESET, "settlement_rules_v2", "the active ruleset")
	_assert_refuses(_edited("settlement_rules_v2", "settlement_rules_v1"),
		CatalogIds.REFUSE_RULESET_MISMATCH, "a previous ruleset")
	_assert_refuses(_edited("\"ruleset\":\"settlement_rules_v2\",", ""),
		CatalogIds.REFUSE_MISSING_FIELD, "no ruleset field")
	_assert_refuses(_edited("\"ruleset\"", "\"extra\":1,\"ruleset\""),
		CatalogIds.REFUSE_UNKNOWN_FIELD, "an extra top-level field")


func test_insignificant_whitespace_refuses() -> void:
	"""No space, tab or newline may appear anywhere except the single final LF."""
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\": 0"),
		CatalogIds.REFUSE_WHITESPACE, "a space after a colon")
	_assert_refuses(_edited(",\"FIBER\"", ", \"FIBER\""),
		CatalogIds.REFUSE_WHITESPACE, "a space after a comma")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\" :0"),
		CatalogIds.REFUSE_WHITESPACE, "a space before a colon")
	_assert_refuses(_document(" " + _canonical_text()),
		CatalogIds.REFUSE_WHITESPACE, "a leading space")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":\t0"),
		CatalogIds.REFUSE_RAW_CONTROL_BYTE, "a tab")


func test_the_final_lf_is_required_and_there_is_exactly_one() -> void:
	"""One final LF terminates the document: none is refused and two are refused."""
	var text: String = _canonical_text()
	assert_equal(CatalogIds.parse_canonical(text.to_utf8_buffer()).error,
		CatalogIds.REFUSE_MISSING_FINAL_LF, "no final LF")
	assert_equal(CatalogIds.parse_canonical((text + "\r\n").to_utf8_buffer()).error,
		CatalogIds.REFUSE_RAW_CONTROL_BYTE, "a CRLF ending")
	assert_equal(CatalogIds.parse_canonical(_document(text + "\n")).error,
		CatalogIds.REFUSE_RAW_CONTROL_BYTE, "two final LFs")
	assert_equal(CatalogIds.parse_canonical(_document(text + "x")).error,
		CatalogIds.REFUSE_TRAILING_BYTES, "trailing content before the LF")
	assert_true(CatalogIds.parse_canonical(_document(text)).ok, "one final LF is accepted")


func test_a_bom_and_non_ascii_bytes_refuse() -> void:
	"""UTF-8 with no BOM, and in practice pure printable ASCII plus that one LF."""
	var with_bom: PackedByteArray = PackedByteArray([0xef, 0xbb, 0xbf])
	with_bom.append_array(_artifact().bytes)
	assert_equal(CatalogIds.parse_canonical(with_bom).error, CatalogIds.REFUSE_BOM, "a UTF-8 BOM")
	var high: PackedByteArray = _artifact().bytes.duplicate()
	high[20] = 0xc3
	assert_equal(CatalogIds.parse_canonical(high).error, CatalogIds.REFUSE_NON_ASCII_BYTE,
		"a byte above 0x7e")
	var control: PackedByteArray = _artifact().bytes.duplicate()
	control[20] = 0x00
	assert_equal(CatalogIds.parse_canonical(control).error, CatalogIds.REFUSE_RAW_CONTROL_BYTE,
		"a raw NUL")
	var delete: PackedByteArray = _artifact().bytes.duplicate()
	delete[20] = 0x7f
	assert_equal(CatalogIds.parse_canonical(delete).error, CatalogIds.REFUSE_RAW_CONTROL_BYTE,
		"a raw DEL")
	assert_equal(CatalogIds.parse_canonical(PackedByteArray()).error, CatalogIds.REFUSE_EMPTY_INPUT,
		"an empty file")


func test_non_canonical_integer_spellings_refuse() -> void:
	"""Decimal, no leading plus, no leading zeros, no exponent -- checked as JSON, then as bytes."""
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":00"),
		CatalogIds.REFUSE_NONCANONICAL_INT, "a leading zero")
	_assert_refuses(_edited("\"FIBER\":1", "\"FIBER\":+1"),
		CatalogIds.REFUSE_NONCANONICAL_INT, "a leading plus")
	_assert_refuses(_edited("\"CEREAL\":0", "\"CEREAL\":"),
		CatalogIds.REFUSE_UNEXPECTED_TOKEN, "a missing value")
	assert_equal(CatalogIds.encode_int(0), "0", "zero")
	assert_equal(CatalogIds.encode_int(4), "4", "four")
	assert_equal(CatalogIds.encode_int(2147483647), "2147483647", "int32 max")


func test_is_ascii_key_accepts_printable_ascii_and_nothing_else() -> void:
	"""BAL-CAT-001's "case-sensitive ASCII StringName keys", enforced character by character."""
	assert_true(CatalogIds.is_ascii_key("CEREAL"), "an uppercase key")
	assert_true(CatalogIds.is_ascii_key("meal_fish_stew"), "an underscored lowercase key")
	assert_true(CatalogIds.is_ascii_key("!"), "0x21 is the lowest legal code point")
	assert_true(CatalogIds.is_ascii_key("~"), "0x7e is the highest legal code point")
	assert_false(CatalogIds.is_ascii_key(""), "an empty key")
	assert_false(CatalogIds.is_ascii_key("a b"), "an embedded space")
	assert_false(CatalogIds.is_ascii_key(String.chr(0x7f)), "DEL")
	assert_false(CatalogIds.is_ascii_key(String.chr(0x09)), "a tab")
	assert_false(CatalogIds.is_ascii_key("café"), "a non-ASCII code point")


func test_validate_domains_refuses_every_illegal_shape() -> void:
	"""The shared validator refuses an empty domain, a bad key, a bad id and a bad value type."""
	assert_equal(_validate({"Toy": {"a": 0}}).code, CatalogIds.REFUSE_NONE, "a minimal legal map")
	assert_equal(_validate({"Toy": {}}).code, CatalogIds.REFUSE_EMPTY_DOMAIN, "an empty domain")
	assert_equal(_validate({"To y": {"a": 0}}).code, CatalogIds.REFUSE_INVALID_ASCII_KEY,
		"a domain name with a space")
	assert_equal(_validate({"Toy": {"a b": 0}}).code, CatalogIds.REFUSE_INVALID_ASCII_KEY,
		"an entry key with a space")
	assert_equal(_validate({"Toy": {"a": "0"}}).code, CatalogIds.REFUSE_NON_INTEGER_ID,
		"a string id")
	assert_equal(_validate({"Toy": {"a": -1}}).code, CatalogIds.REFUSE_EMPTY_SENTINEL_ID,
		"the -1 sentinel")
	assert_equal(_validate({"Toy": {"a": -2}}).code, CatalogIds.REFUSE_ID_OUT_OF_RANGE,
		"a negative id")
	assert_equal(_validate({"Toy": 7}).code, CatalogIds.REFUSE_UNEXPECTED_TOKEN,
		"a domain that is not an object")


func test_row_count_of_counts_every_entry_across_every_domain() -> void:
	"""row_count is the CATALOG_IDS section descriptor's row count: entries, not domains."""
	assert_equal(CatalogIds.row_count_of({}), 0, "an empty map")
	assert_equal(CatalogIds.row_count_of({"A": {"a": 0}}), 1, "one entry")
	assert_equal(CatalogIds.row_count_of({"A": {"a": 0, "b": 1}, "B": {"c": 0}}), 3,
		"three entries across two domains")
	assert_equal(CatalogIds.row_count_of(_artifact().domains), COMMITTED_ROW_COUNT,
		"the artifact's 275 entries")


func test_verify_file_refuses_a_missing_artifact_without_writing_one() -> void:
	"""Runtime never creates the artifact: a missing file is a refusal, not a regeneration."""
	var absent: String = "res://data/catalog_ids_absent_fixture.json"
	assert_false(FileAccess.file_exists(absent), "the fixture path must not exist")
	var result: CatalogIds.VerifyResult = CatalogIds.verify_file(absent)
	assert_false(result.ok, "a missing artifact refuses")
	assert_equal(result.error, CatalogIds.REFUSE_FILE_UNREADABLE, "unreadable-file code")
	assert_false(FileAccess.file_exists(absent), "and nothing was written in its place")


func _validate(domains: Dictionary) -> CatalogIds.Refusal:
	"""Run the shared domain validator over a hand-built map."""
	return CatalogIds.validate_domains(domains)


# --- decision 0056's four starter-colony domains -------------------------------------------------

## The digest this change moved AWAY from, kept so "it changed" is asserted rather than assumed.
const PREVIOUS_SHA256: String = \
	"00e3ffd5c98b5f5da050cc13be91895b85744eb3b3f3cfb5e50dde85a598cbf1"
const PREVIOUS_BYTE_LENGTH: int = 3064
const PREVIOUS_DOMAIN_COUNT: int = 22
const PREVIOUS_ROW_COUNT: int = 206

## Row counts of the four domains decision 0056 added: the owning catalog's 30 buildings and 9
## furniture rows, and GDD §4.3's 8 room types and 6 building states.
const STARTER_DOMAIN_ROWS: Dictionary = {
	"BuildingDefinition": 30, "FurnitureDefinition": 9, "RoomType": 8, "BuildingState": 6,
}


func test_the_artifact_carries_all_four_starter_domains_complete() -> void:
	"""Partial publication is the failure READY_07 §7.2 step 1 names; the row counts are pinned.

	A BuildingDefinition domain of seven runtime-only ordinals would pass every other test in
	this file -- the bytes would be canonical and the digest self-consistent -- and renumber
	every building the day an eighth landed. This is the assertion that would not pass."""
	var domains: Dictionary = _artifact().domains
	for name: String in STARTER_DOMAIN_ROWS:
		assert_true(domains.has(name), "the artifact must carry '%s'" % name)
		if not domains.has(name):
			continue
		assert_equal((domains[name] as Dictionary).size(), int(STARTER_DOMAIN_ROWS[name]),
			"'%s' row count" % name)
	assert_equal(PREVIOUS_ROW_COUNT + 30 + 9 + 8 + 6, PRE_DOMAIN_ROW_COUNT,
		"the 53 new rows are exactly the difference from the artifact 0056 replaced")
	assert_equal(PREVIOUS_DOMAIN_COUNT + 4, PRE_DOMAIN_DOMAIN_COUNT, "four new domains, no more")


func test_the_starter_domain_ids_in_the_artifact_are_the_owning_catalog_order() -> void:
	"""The committed bytes, not the module: a first, a last and a middle key of each domain."""
	var buildings: Dictionary = _domain("BuildingDefinition")
	assert_equal(int(buildings["apiary"]), 0, "apiary sorts first of thirty")
	assert_equal(int(buildings["hall"]), 12, "hall, the starter refuge, is 12")
	assert_equal(int(buildings["workshop"]), 29, "workshop sorts last of thirty")
	var furniture: Dictionary = _domain("FurnitureDefinition")
	assert_equal(int(furniture["bed"]), 0, "bed sorts first of nine")
	assert_equal(int(furniture["kitchen_bench"]), 5, "kitchen_bench is 5")
	assert_equal(int(furniture["shelf"]), 8, "shelf sorts last of nine")
	assert_equal(int(_domain("RoomType")["DORMITORY"]), 0, "§4.3 numbers DORMITORY 0")
	assert_equal(int(_domain("RoomType")["CORRIDOR"]), 7, "§4.3 numbers CORRIDOR 7")
	assert_equal(int(_domain("BuildingState")["BLUEPRINT"]), 0, "§4.3 numbers BLUEPRINT 0")
	assert_equal(int(_domain("BuildingState")["DEMOLISHING"]), 5, "§4.3 numbers DEMOLISHING 5")


func test_the_digest_moved_exactly_once_for_this_change() -> void:
	"""The artifact exists so the hash moves when the ID mapping does -- and only then.

	The pre-0056 digest is pinned above. The current one must differ from it (the four domains
	really were added, and decision 0080's two after them) and must equal the single committed
	value that the file on disk, a fresh build and the save-header digest all agree on (it moved
	once per intentional change, not once per reader)."""
	var artifact: CatalogIds.Artifact = _artifact()
	assert_false(artifact.digest_hex() == PREVIOUS_SHA256,
		"adding four ID-carrying domains must move the digest")
	assert_false(artifact.bytes.size() == PREVIOUS_BYTE_LENGTH, "and the byte length with it")
	assert_equal(artifact.digest_hex(), COMMITTED_SHA256, "and it moved to exactly this value")
	var rebuilt: CatalogIds.BuildResult = CatalogIds.build()
	assert_true(rebuilt.ok, "a second build must succeed (%s)" % rebuilt.error)
	if rebuilt.ok:
		assert_equal(rebuilt.artifact.digest_hex(), COMMITTED_SHA256, "the rebuild agrees")
	var on_disk: CatalogIds.VerifyResult = CatalogIds.verify_file()
	assert_true(on_disk.ok, "the committed file agrees (%s: %s)" % [on_disk.error, on_disk.detail])
	assert_false(on_disk.proves_rules_unchanged,
		"a catalog match still proves nothing about the numerical ruleset")


func test_building_it_twice_produces_byte_identical_output() -> void:
	"""The generator is a pure function of the registries: a second run rewrites nothing.

	`tools/generate_catalog_ids.sh` relies on this to report `action=unchanged`. Two independent
	builds are compared byte for byte, then re-encoded from the second build's own domain map."""
	var first: CatalogIds.BuildResult = CatalogIds.build()
	var second: CatalogIds.BuildResult = CatalogIds.build()
	assert_true(first.ok and second.ok, "both builds must succeed")
	if not (first.ok and second.ok):
		return
	assert_equal(second.artifact.bytes, first.artifact.bytes, "byte-identical on the second run")
	assert_equal(second.artifact.digest, first.artifact.digest, "and the same raw digest bytes")
	assert_equal(second.artifact.row_count, first.artifact.row_count, "and the same row count")
	assert_equal(CatalogIds.encode_canonical(second.artifact.domains), first.artifact.bytes,
		"re-encoding the second build's own map reproduces the same bytes")


func test_a_partial_building_domain_fails_verification() -> void:
	"""Mutation of the domain itself, not of a byte: drop 23 of the 30 buildings.

	This is the "seven runtime-only ordinals" shape exactly -- the starter colony's keys only --
	and it must be refused against the committed artifact rather than quietly accepted."""
	var starter_only: Dictionary = {}
	var buildings: Dictionary = _domain("BuildingDefinition")
	for key: String in ["hall", "open_stockpile", "well", "workbench"]:
		starter_only[key] = buildings[key]
	var partial: Dictionary = _artifact().domains.duplicate(true)
	partial["BuildingDefinition"] = starter_only
	var refusal: CatalogIds.Refusal = CatalogIds.compare_domains(partial, _artifact().domains)
	assert_false(refusal.is_ok(), "a four-key BuildingDefinition must not compare equal")
	assert_equal(refusal.code, CatalogIds.REFUSE_KEY_MISMATCH, "it is a missing-key refusal")
	var bytes: PackedByteArray = CatalogIds.encode_canonical(partial)
	_assert_refuses(bytes, CatalogIds.REFUSE_KEY_MISMATCH, "a starter-only building domain")


func test_a_renumbered_building_id_fails_verification() -> void:
	"""One id moved by one -- what inserting a thirty-first building ahead of it would do."""
	var renumbered: Dictionary = _artifact().domains.duplicate(true)
	var buildings: Dictionary = renumbered["BuildingDefinition"]
	buildings["workshop"] = 30
	var bytes: PackedByteArray = CatalogIds.encode_canonical(renumbered)
	_assert_refuses(bytes, CatalogIds.REFUSE_ID_MISMATCH, "workshop renumbered 29 -> 30")
	var refusal: CatalogIds.Refusal = CatalogIds.compare_domains(renumbered, _artifact().domains)
	assert_false(refusal.is_ok(), "compare_domains must see the moved id")
	assert_true(refusal.detail.contains("workshop"), "and name the key that moved")


# --- decision 0080's Milestone and Station domains ------------------------------------------------

## The digest this change moved AWAY from, kept so "it changed" is asserted rather than assumed.
const PRE_DOMAIN_SHA256: String = \
	"ead6a8ac6c67bb4b0d9b320a2414cc477f252b5f9cdf8bb3e1e0b8cc593eecf4"
const PRE_DOMAIN_BYTE_LENGTH: int = 3869
const PRE_DOMAIN_DOMAIN_COUNT: int = 26
const PRE_DOMAIN_ROW_COUNT: int = 259

## R-BUILD-DOM-001/002 row counts: five milestones and eleven service keys.
const MILESTONE_ROWS: int = 5
const STATION_ROWS: int = 11


func test_the_artifact_carries_milestone_and_station_complete() -> void:
	"""R-BUILD-DOM-001/002's two domains are in the committed bytes, whole, with their own ids."""
	var domains: Dictionary = _artifact().domains
	assert_true(domains.has("Milestone"), "the artifact must carry Milestone")
	assert_true(domains.has("Station"), "the artifact must carry Station")
	assert_equal((domains["Milestone"] as Dictionary).size(), MILESTONE_ROWS, "Milestone rows")
	assert_equal((domains["Station"] as Dictionary).size(), STATION_ROWS, "Station rows")
	assert_equal(PRE_DOMAIN_ROW_COUNT + MILESTONE_ROWS + STATION_ROWS, COMMITTED_ROW_COUNT,
		"the sixteen new rows are exactly the difference from the previous artifact")
	assert_equal(PRE_DOMAIN_DOMAIN_COUNT + 2, COMMITTED_DOMAIN_COUNT, "two new domains, no more")
	assert_true(PRE_DOMAIN_BYTE_LENGTH != COMMITTED_BYTE_LENGTH, "the byte length moved")
	assert_true(PRE_DOMAIN_SHA256 != COMMITTED_SHA256, "the digest moved, deliberately")


func test_the_committed_milestone_and_station_ids_are_the_ruled_values() -> void:
	"""BAL-CAT-002's M0..M4 and BAL-CAT-011's eleven service keys, read out of the bytes."""
	var milestone: Dictionary = _domain("Milestone")
	assert_equal(int(milestone["M0"]), 0, "BAL-CAT-002 states M0=0")
	assert_equal(int(milestone["M4"]), 4, "BAL-CAT-002 states M4=4")
	assert_false(milestone.has("Start"), "Start is a source label, never a sixth key")
	var station: Dictionary = _domain("Station")
	assert_equal(int(station["brewery"]), 0, "brewery sorts first of eleven")
	assert_equal(int(station["kitchen"]), 3, "kitchen service is 3")
	assert_equal(int(station["workshop"]), 10, "workshop sorts last of eleven")


func test_station_ids_are_not_building_ids_in_the_committed_bytes() -> void:
	"""BAL-CAT-011: station "indexes a service domain, not the BuildingDefinition index"."""
	var station: Dictionary = _domain("Station")
	var buildings: Dictionary = _domain("BuildingDefinition")
	var shared: int = 0
	for key: String in station.keys():
		assert_true(buildings.has(key), "'%s' is also a building key" % key)
		shared += 1
		assert_true(int(station[key]) != int(buildings[key]),
			"'%s' must carry different ids in the two domains" % key)
	assert_equal(shared, STATION_ROWS, "all eleven station keys are also building keys")
	assert_equal(int(station["brewery"]), 0, "brewery is service 0")
	assert_equal(int(buildings["brewery"]), 2, "and building 2")
