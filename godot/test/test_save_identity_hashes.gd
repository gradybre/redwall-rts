extends "res://test/framework/test_case.gd"
## Suite for `save_identity_hashes.gd`: SAVE-R09-003's header identities, the section-1 provenance
## prefix and the loader's compatibility check (ADR 1222 step 6, DEC-055 Q1/Q9).
##
## Vectors marked "Python" were computed outside Godot with hashlib/struct over the literal bytes.

const Identity := preload("res://scripts/core/save_identity_hashes.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

## Python: sha256(b'RWL-MAP-1\0' + pack('<IiI', 1, 12345, 1) + 32 zero bytes).
const MAP_12345_HEX: String = "bea6d48635b44fbd45ca86761a582208a130d613d8fb22992a4fb55e563ea6c7"
## Python: the same with seed -7 (a negative seed keeps its signed i32 bytes).
const MAP_NEG7_HEX: String = "f025db36c999d28621d791ba742ac7f6133fbd0a9f3fe8ff2786c49f5c89c0e3"
## Python: sha256(b'4.7.2.stable.official.' + b'a' * 40 + b'\n').
const ENGINE_HEX: String = "5a896af18912f2173b13e59c6a6d3e03a60b328c80ef0eabca6df016fc25d0c4"
const ARTIFACT_PATH: String = "user://test_identity_artifact.bin"


func _info() -> Dictionary:
	"""A fully identified version-info dictionary."""
	return {"major": 4, "minor": 7, "patch": 2, "status": "stable", "build": "official",
		"hash": "a".repeat(40)}


func _zero32() -> PackedByteArray:
	"""Thirty-two zero bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(32)
	return bytes


func _local() -> Identity.LocalIdentity:
	"""A local identity of four distinct, recognisable digests."""
	var local: Identity.LocalIdentity = Identity.LocalIdentity.new()
	local.rules = Identity.sha256_of("r".to_utf8_buffer())
	local.catalog = Identity.sha256_of("c".to_utf8_buffer())
	local.lookup = Identity.sha256_of("l".to_utf8_buffer())
	local.engine = Identity.sha256_of("e".to_utf8_buffer())
	return local


func _provenance(world_seed: int) -> Identity.Provenance:
	"""The supported procedural estuary provenance with `world_seed`."""
	var provenance: Identity.Provenance = Identity.Provenance.new()
	provenance.scenario_version = Identity.SCENARIO_ESTUARY_V1
	provenance.effective_seed = world_seed
	provenance.map_generator_schema = Identity.MAP_GENERATOR_SCHEMA_V1
	return provenance


func _matching_header(local: Identity.LocalIdentity, world_seed: int) -> SaveHeader.Header:
	"""A header whose five identities all match `local` and the provenance for `world_seed`."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	header.rules_hash = local.rules
	header.catalog_hash = local.catalog
	header.lookup_hash = local.lookup
	header.engine_hash = local.engine
	header.map_hash = Identity.map_hash(1, world_seed, 1, _zero32()).digest
	return header


func test_map_hash_matches_independent_vectors() -> void:
	"""The ruled byte string, little-endian, signed seed preserved."""
	assert_equal(Identity.map_hash(1, 12345, 1, _zero32()).digest.hex_encode(), MAP_12345_HEX,
		"seed 12345")
	assert_equal(Identity.map_hash(1, -7, 1, _zero32()).digest.hex_encode(), MAP_NEG7_HEX,
		"seed -7")


func test_map_hash_refuses_out_of_range_fields() -> void:
	"""Each provenance field is checked against its ruled wire width."""
	assert_equal(Identity.map_hash(-1, 0, 1, _zero32()).error, Identity.REFUSE_FIELD_RANGE, "u32")
	assert_equal(Identity.map_hash(1, 1 << 31, 1, _zero32()).error, Identity.REFUSE_FIELD_RANGE,
		"i32")
	assert_equal(Identity.map_hash(1, 0, 1, PackedByteArray([1])).error,
		Identity.REFUSE_DIGEST_LENGTH, "digest length")


func test_engine_line_and_hash() -> void:
	"""The exact line and its SHA-256, and refusals for an unidentified build."""
	assert_equal(Identity.engine_identity_line(_info()).text,
		"4.7.2.stable.official.%s\n" % "a".repeat(40), "the ruled line")
	assert_equal(Identity.engine_hash_of(_info()).digest.hex_encode(), ENGINE_HEX, "Python vector")
	var short: Dictionary = _info()
	short["hash"] = "abc1234"
	assert_equal(Identity.engine_hash_of(short).error, Identity.REFUSE_ENGINE_UNIDENTIFIED,
		"an abbreviated hash refuses")
	var upper: Dictionary = _info()
	upper["hash"] = "A".repeat(40)
	assert_equal(Identity.engine_hash_of(upper).error, Identity.REFUSE_ENGINE_UNIDENTIFIED,
		"uppercase hex refuses")
	var dotted: Dictionary = _info()
	dotted["status"] = "rc.1"
	assert_equal(Identity.engine_hash_of(dotted).error, Identity.REFUSE_ENGINE_UNIDENTIFIED,
		"a dotted status refuses")
	var missing: Dictionary = _info()
	missing.erase("major")
	assert_equal(Identity.engine_hash_of(missing).error, Identity.REFUSE_ENGINE_UNIDENTIFIED,
		"a missing number refuses")


func test_development_identities_are_independently_reproduced() -> void:
	"""domain\\0 || u32 length || DECLARATION_ID, through HashingContext directly."""
	for domain: String in [Identity.DEV_RULES_DOMAIN_TEXT, Identity.DEV_LOOKUP_DOMAIN_TEXT]:
		var bytes: PackedByteArray = domain.to_utf8_buffer()
		bytes.append(0)
		var identity: PackedByteArray = Digest.DECLARATION_ID.to_utf8_buffer()
		var length: PackedByteArray = PackedByteArray()
		length.resize(4)
		length.encode_u32(0, identity.size())
		bytes.append_array(length)
		bytes.append_array(identity)
		var context: HashingContext = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		assert_equal(Identity.development_identity_hash(domain).digest, context.finish(), domain)
	assert_false(Identity.development_identity_hash("RWL-RULES-1").ok,
		"a release domain is not a development identity")
	assert_true(Identity.development_identity_hash(Identity.DEV_RULES_DOMAIN_TEXT).digest
		!= Identity.development_identity_hash(Identity.DEV_LOOKUP_DOMAIN_TEXT).digest,
		"rules and lookup development identities differ")


func test_release_artifacts_are_absent_and_refuse() -> void:
	"""No owner registers yet, so the release identities refuse instead of inventing a digest."""
	assert_equal(Identity.rules_hash().error, Identity.REFUSE_ARTIFACT_UNREADABLE, "rules")
	assert_equal(Identity.lookup_hash().error, Identity.REFUSE_ARTIFACT_UNREADABLE, "lookup")
	assert_false(Identity.local_identity().ok, "the release identity is unavailable")


func test_local_development_identity_is_complete() -> void:
	"""The development identity carries all four digests at 32 bytes."""
	var result: Identity.LocalIdentityResult = Identity.local_identity(true)
	assert_true(result.ok, "the development identity is available: %s" % result.detail)
	if not result.ok:
		return
	for digest: PackedByteArray in [result.identity.rules, result.identity.catalog,
			result.identity.lookup, result.identity.engine]:
		assert_equal(digest.size(), 32, "a 32-byte identity")


func test_provenance_prefix_decode_and_support() -> void:
	"""The 44-byte prefix decodes field by field; only the procedural estuary is supported."""
	var prefix: PackedByteArray = PackedByteArray()
	prefix.resize(44)
	prefix.encode_u32(0, 1)
	prefix.encode_s32(4, -9)
	prefix.encode_u32(8, 1)
	var decoded: Identity.ProvenanceResult = Identity.provenance_from_prefix(prefix)
	assert_true(decoded.ok, "decodes")
	assert_equal(decoded.provenance.effective_seed, -9, "signed seed")
	assert_true(Identity.provenance_support_refusal(decoded.provenance).is_ok(), "supported")
	assert_false(Identity.provenance_from_prefix(PackedByteArray([1])).ok, "short prefix")
	var other: Identity.Provenance = _provenance(1)
	other.scenario_version = 2
	assert_equal(Identity.provenance_support_refusal(other).code,
		Identity.REFUSE_UNSUPPORTED_SCENARIO, "scenario")
	other = _provenance(1)
	other.map_generator_schema = 2
	assert_equal(Identity.provenance_support_refusal(other).code,
		Identity.REFUSE_UNSUPPORTED_GENERATOR, "generator")
	other = _provenance(1)
	other.authored_map_digest[3] = 1
	assert_equal(Identity.provenance_support_refusal(other).code, Identity.REFUSE_AUTHORED_DIGEST,
		"authored digest")


func test_compatibility_accepts_a_match_and_names_each_mismatch() -> void:
	"""All five identities must match, checked in header-offset order."""
	var local: Identity.LocalIdentity = _local()
	assert_true(Identity.compatibility_refusal(_matching_header(local, 5), _provenance(5),
		local).is_ok(), "a matching header is compatible")
	var cases: Array = [["rules_hash", Identity.REFUSE_RULES_MISMATCH],
		["catalog_hash", Identity.REFUSE_CATALOG_MISMATCH], ["map_hash", Identity.REFUSE_MAP_MISMATCH],
		["lookup_hash", Identity.REFUSE_LOOKUP_MISMATCH],
		["engine_hash", Identity.REFUSE_ENGINE_MISMATCH]]
	for entry: Array in cases:
		var header: SaveHeader.Header = _matching_header(local, 5)
		var field: PackedByteArray = PackedByteArray(header.get(String(entry[0]))).duplicate()
		field[0] = field[0] ^ 1
		header.set(String(entry[0]), field)
		assert_equal(Identity.compatibility_refusal(header, _provenance(5), local).code, entry[1],
			String(entry[0]))
	assert_equal(Identity.compatibility_refusal(_matching_header(local, 5), _provenance(6),
		local).code, Identity.REFUSE_MAP_MISMATCH, "another seed is another map")
	assert_equal(Identity.compatibility_refusal(null, _provenance(5), local).code,
		Identity.REFUSE_INPUT_MISSING, "a missing header")


func test_artifact_writer_and_verifier_round_trip() -> void:
	"""A written artifact verifies to the SHA-256 of its exact bytes; damage refuses."""
	var file: FileAccess = FileAccess.open(ARTIFACT_PATH, FileAccess.WRITE)
	var writer: Identity.ArtifactWriter = Identity.ArtifactWriter.new()
	assert_true(Identity.writer_begin(writer, file, Identity.KIND_RULES, 2).is_ok(), "begin")
	assert_true(Identity.writer_append_integers(writer, "a.rate", Identity.TYPE_I32,
		PackedInt64Array([1, -2, 3])).is_ok(), "integers")
	assert_true(Identity.writer_append_strings(writer, "b.name",
		PackedStringArray(["mill"])).is_ok(), "strings")
	assert_true(Identity.writer_finish(writer).is_ok(), "finish")
	file.close()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ARTIFACT_PATH)
	var verified: Identity.DigestResult = Identity.verify_artifact_file(ARTIFACT_PATH,
		Identity.KIND_RULES)
	assert_true(verified.ok, "verifies: %s" % verified.detail)
	assert_equal(verified.digest, Identity.sha256_of(bytes), "the digest covers the exact bytes")
	assert_false(Identity.verify_artifact_file(ARTIFACT_PATH, Identity.KIND_LOOKUP).ok,
		"the wrong magic refuses")
	var damaged: FileAccess = FileAccess.open(ARTIFACT_PATH, FileAccess.WRITE)
	damaged.store_buffer(bytes.slice(0, bytes.size() - 1))
	damaged.close()
	assert_equal(Identity.verify_artifact_file(ARTIFACT_PATH, Identity.KIND_RULES).error,
		Identity.REFUSE_ARTIFACT_TRUNCATED, "a truncated artifact refuses")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARTIFACT_PATH))


func test_writer_refuses_unsorted_keys_and_wrong_counts() -> void:
	"""Keys must ascend, and finish requires exactly the declared record count."""
	var file: FileAccess = FileAccess.open(ARTIFACT_PATH, FileAccess.WRITE)
	var writer: Identity.ArtifactWriter = Identity.ArtifactWriter.new()
	assert_true(Identity.writer_begin(writer, file, Identity.KIND_LOOKUP, 2).is_ok(), "begin")
	assert_true(Identity.writer_append_integers(writer, "b", Identity.TYPE_U8,
		PackedInt64Array([1])).is_ok(), "first key")
	assert_equal(Identity.writer_append_integers(writer, "a", Identity.TYPE_U8,
		PackedInt64Array([1])).code, Identity.REFUSE_ARTIFACT_UNSORTED_KEY, "descending key")
	file.close()
	var second: FileAccess = FileAccess.open(ARTIFACT_PATH, FileAccess.WRITE)
	var short: Identity.ArtifactWriter = Identity.ArtifactWriter.new()
	assert_true(Identity.writer_begin(short, second, Identity.KIND_LOOKUP, 2).is_ok(), "begin")
	assert_equal(Identity.writer_finish(short).code, Identity.REFUSE_ARTIFACT_RECORD_COUNT,
		"0 of 2 records")
	second.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARTIFACT_PATH))
