extends RefCounted
## SAVE-R09-003's identity producers for the save header's offsets 40, 104, 136 and 168, the
## 44-byte section-1 map-provenance prefix, and the loader's compatibility check over all five.
## ADR 1222 build step 6. Ruling: `docs/rulings/2026-09-11_save_codec_contract.md` SAVE-R09-003.
##
## WHAT IS PRODUCED, EXACTLY AS RULED:
##
##   * MAP (offset 104). SHA-256 of `RWL-MAP-1\0 || scenario_version:u32 || effective_seed:i32 ||
##     map_generator_schema:u32 || authored_map_digest:32`, integers little-endian. The ruling's
##     "New baseline `map_generator_schema=1`" is MAP_GENERATOR_SCHEMA_V1, and "The zero 32-byte
##     authored digest is permitted only for the current wholly procedural estuary".
##   * ENGINE (offset 168). SHA-256 of the UTF-8 line
##     `major.minor.patch.status.build.full_commit_hash\n` from `Engine.get_version_info()`.
##     "Require full commit hash, not its short display abbreviation; refuse an unidentified
##     build." A build with no 40-hex commit hash is refused, never given a substitute.
##   * PROVENANCE. `provenance_of()` reads the published world: `world_init.gd`'s accepted
##     (published) seed -- "Preserve the effective published seed, not an unsuccessful attempt's
##     input" -- cross-checked against the RNG's seed ("Duplicate seed fields elsewhere must
##     agree"). The scenario is SCENARIO_ESTUARY_V1 because `world_init.gd` refuses every other
##     scenario version before generating, so a published world can have no other.
##   * RULES (40) and LOOKUP (136). The artifact formats `RWL-RULES-1\0` / `RWL-LOOKUP-1\0`, a
##     streaming writer for the build, and a streaming verifier whose SHA-256 covers the exact
##     artifact bytes. Verification reads at most CHUNK_BYTES at a time, bounds every count by the
##     remaining bytes before reading, allocates nothing count-sized and requires exact EOF.
##
## WHAT IS NOT PRODUCED, AND WHY (refused, never invented). No `rules_identity.bin` or
## `lookup_identity.bin` is committed. The ruling builds them "from explicit authoritative-owner
## registrations, not prose, comments, filenames, presentation settings or inferred source
## scanning", requires the build to "fail missing coverage", and says "No hand-selected subset may
## be called the release rules identity". No owner registers anything yet, so `rules_hash()` and
## `lookup_hash()` refuse SAVE_IDENTITY_ARTIFACT_UNREADABLE and `local_identity()` refuses with
## them. "Do not insert made-up hex digests into release saves."
##
## THE DEVELOPMENT SAVE (ADR 1222, DEC-055 Q9). `local_identity(true)` uses
## `development_identity_hash()` for rules and lookup instead: SHA-256 over a `-DEV-` domain and the
## canonical registry declaration id, so a development save names exactly the declaration it was
## written under and can never equal a release artifact's identity.
##
## COMPATIBILITY (the loader). Rules and catalog must equal this build's (DEC-055 Q1: until 1.0 a
## save from another content revision is refused). Lookup and engine must equal this build's too:
## "Expected rules/catalog/lookup/engine identities come from the local verified build; map
## identity comes from the validated incoming provenance prefix. All are checked before
## live-world mutation." The map hash is recomputed from the file's own section-1 prefix after
## its scenario/generator/digest are validated against local content -- never compared with the
## open world's seed and never trusted as its own expected value.
##
## COLD PATH. Build time and load time only; nothing here runs per tick. NO FLOAT.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const CatalogIdsScript := preload("res://scripts/core/catalog_ids.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

const DIGEST_BYTES: int = 32
const PROVENANCE_PREFIX_BYTES: int = 44
const RULES_ARTIFACT_PATH: String = "res://data/rules_identity.bin"
const LOOKUP_ARTIFACT_PATH: String = "res://data/lookup_identity.bin"

## Each domain string is followed by one literal zero byte (`_domain_bytes()`).
const RULES_MAGIC_TEXT: String = "RWL-RULES-1"
const LOOKUP_MAGIC_TEXT: String = "RWL-LOOKUP-1"
const MAP_DOMAIN_TEXT: String = "RWL-MAP-1"
## ADR 1222 step 6: the development save's rules and lookup identity domains.
const DEV_RULES_DOMAIN_TEXT: String = "RWL-RULES-DEV-1"
const DEV_LOOKUP_DOMAIN_TEXT: String = "RWL-LOOKUP-DEV-1"

const KIND_RULES: int = 0
const KIND_LOOKUP: int = 1

## "Type 0=u8, 1=u32, 2=i32, 3=u64, 4=i64, 5=UTF-8 string"; lookup tables take 0-4 only.
const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_U64: int = 3
const TYPE_I64: int = 4
const TYPE_STRING: int = 5

const KEY_MAX_BYTES: int = 256
const STRING_VALUE_MAX_BYTES: int = 4096
const LENGTH_PREFIX_BYTES: int = 4
## key length u32 + at least one key byte + type u8 + element count u32.
const MIN_RECORD_BYTES: int = 10
## ARCH-SAVE-003's stream window; no read here is ever longer.
const CHUNK_BYTES: int = 65536
## BAL-CAT-001's printable ASCII key alphabet, shared with `catalog_ids.gd`'s `is_ascii_key()`.
const KEY_BYTE_MIN: int = 0x21
const KEY_BYTE_MAX: int = 0x7e

const ENGINE_COMMIT_HASH_CHARS: int = 40
const ENGINE_NUMBER_KEYS: Array[String] = ["major", "minor", "patch"]
const ENGINE_TEXT_KEYS: Array[String] = ["status", "build"]
const ENGINE_HASH_KEY: String = "hash"

## The only locally supported scenario/generator pair; see the header for both sources.
const SCENARIO_ESTUARY_V1: int = WorldInitScript.SCENARIO_ESTUARY_V1
const MAP_GENERATOR_SCHEMA_V1: int = 1

const REFUSE_NONE: StringName = &""
const REFUSE_INPUT_MISSING: StringName = &"SAVE_IDENTITY_INPUT_MISSING"
const REFUSE_DIGEST_LENGTH: StringName = &"SAVE_IDENTITY_DIGEST_LENGTH"
const REFUSE_FIELD_RANGE: StringName = &"SAVE_IDENTITY_FIELD_RANGE"
const REFUSE_ARTIFACT_KIND: StringName = &"SAVE_IDENTITY_ARTIFACT_KIND"
const REFUSE_ARTIFACT_UNREADABLE: StringName = &"SAVE_IDENTITY_ARTIFACT_UNREADABLE"
const REFUSE_ARTIFACT_MAGIC: StringName = &"SAVE_IDENTITY_ARTIFACT_MAGIC"
const REFUSE_ARTIFACT_TRUNCATED: StringName = &"SAVE_IDENTITY_ARTIFACT_TRUNCATED"
const REFUSE_ARTIFACT_COUNT_BOUND: StringName = &"SAVE_IDENTITY_ARTIFACT_COUNT_BOUND"
const REFUSE_ARTIFACT_KEY: StringName = &"SAVE_IDENTITY_ARTIFACT_KEY"
const REFUSE_ARTIFACT_DUPLICATE_KEY: StringName = &"SAVE_IDENTITY_ARTIFACT_DUPLICATE_KEY"
const REFUSE_ARTIFACT_UNSORTED_KEY: StringName = &"SAVE_IDENTITY_ARTIFACT_UNSORTED_KEY"
const REFUSE_ARTIFACT_TYPE: StringName = &"SAVE_IDENTITY_ARTIFACT_TYPE"
const REFUSE_ARTIFACT_STRING: StringName = &"SAVE_IDENTITY_ARTIFACT_STRING"
const REFUSE_ARTIFACT_TRAILING_BYTES: StringName = &"SAVE_IDENTITY_ARTIFACT_TRAILING_BYTES"
const REFUSE_ARTIFACT_VALUE_RANGE: StringName = &"SAVE_IDENTITY_ARTIFACT_VALUE_RANGE"
const REFUSE_ARTIFACT_RECORD_COUNT: StringName = &"SAVE_IDENTITY_ARTIFACT_RECORD_COUNT"
const REFUSE_ARTIFACT_WRITE: StringName = &"SAVE_IDENTITY_ARTIFACT_WRITE"
const REFUSE_ENGINE_UNIDENTIFIED: StringName = &"SAVE_IDENTITY_ENGINE_UNIDENTIFIED"
const REFUSE_PROVENANCE_UNAVAILABLE: StringName = &"SAVE_IDENTITY_PROVENANCE_UNAVAILABLE"
const REFUSE_SEED_DISAGREES: StringName = &"SAVE_IDENTITY_SEED_DISAGREES"
const REFUSE_UNSUPPORTED_SCENARIO: StringName = &"SAVE_IDENTITY_UNSUPPORTED_SCENARIO"
const REFUSE_UNSUPPORTED_GENERATOR: StringName = &"SAVE_IDENTITY_UNSUPPORTED_GENERATOR"
const REFUSE_AUTHORED_DIGEST: StringName = &"SAVE_IDENTITY_AUTHORED_DIGEST"
const REFUSE_CATALOG_UNAVAILABLE: StringName = &"SAVE_IDENTITY_CATALOG_UNAVAILABLE"
const REFUSE_RULES_MISMATCH: StringName = &"SAVE_IDENTITY_RULES_MISMATCH"
const REFUSE_CATALOG_MISMATCH: StringName = &"SAVE_IDENTITY_CATALOG_MISMATCH"
const REFUSE_MAP_MISMATCH: StringName = &"SAVE_IDENTITY_MAP_MISMATCH"
const REFUSE_LOOKUP_MISMATCH: StringName = &"SAVE_IDENTITY_LOOKUP_MISMATCH"
const REFUSE_ENGINE_MISMATCH: StringName = &"SAVE_IDENTITY_ENGINE_MISMATCH"


class DigestResult:
	"""One produced identity. `.ok` MUST be inspected first; on refusal `digest` is empty."""
	var ok: bool
	var error: StringName
	var detail: String
	var digest: PackedByteArray

	func _init(p_ok: bool, p_error: StringName, p_detail: String,
			p_digest: PackedByteArray) -> void:
		"""Store the outcome and, only on success, the raw 32-byte SHA-256."""
		ok = p_ok
		error = p_error
		detail = p_detail
		digest = p_digest


class TextResult:
	"""One assembled identity line. On refusal `text` is empty."""
	var ok: bool
	var error: StringName
	var detail: String
	var text: String

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_text: String) -> void:
		"""Store the outcome and, only on success, the exact line."""
		ok = p_ok
		error = p_error
		detail = p_detail
		text = p_text


class Provenance:
	"""SAVE-R09-003's 44-byte section-1 prefix as typed values. The digest is always 32 bytes."""
	var scenario_version: int = 0
	var effective_seed: int = 0
	var map_generator_schema: int = 0
	var authored_map_digest: PackedByteArray = PackedByteArray()

	func _init() -> void:
		"""Allocate the 32-byte authored digest once, zeroed."""
		authored_map_digest.resize(DIGEST_BYTES)
		authored_map_digest.fill(0)


class ProvenanceResult:
	"""Outcome of producing or decoding provenance. On refusal `provenance` is null."""
	var ok: bool
	var error: StringName
	var detail: String
	var provenance: Provenance

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_provenance: Provenance) -> void:
		"""Store the outcome and, only on success, the provenance."""
		ok = p_ok
		error = p_error
		detail = p_detail
		provenance = p_provenance


class LocalIdentity:
	"""The four identities this running build expects of an incoming save."""
	var rules: PackedByteArray = PackedByteArray()
	var catalog: PackedByteArray = PackedByteArray()
	var lookup: PackedByteArray = PackedByteArray()
	var engine: PackedByteArray = PackedByteArray()


class LocalIdentityResult:
	"""Outcome of computing this build's identities. On refusal `identity` is null."""
	var ok: bool
	var error: StringName
	var detail: String
	var identity: LocalIdentity

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_identity: LocalIdentity) -> void:
		"""Store the outcome and, only on success, the four digests."""
		ok = p_ok
		error = p_error
		detail = p_detail
		identity = p_identity


class ArtifactWriter:
	"""Build-time streaming writer state for one rules or lookup artifact. Driven only by the
	static `writer_*` functions; after any refusal it stays failed and writes nothing more."""
	var file: FileAccess = null
	var kind: int = -1
	var declared_count: int = 0
	var written_count: int = 0
	var previous_key: PackedByteArray = PackedByteArray()
	var failed: bool = false
	var finished: bool = false


class _Stream:
	"""Verifier state: the open file, the running SHA-256, bytes left and the previous key."""
	var file: FileAccess
	var context: HashingContext
	var remaining: int
	var previous_key: PackedByteArray = PackedByteArray()

	func _init(p_file: FileAccess) -> void:
		"""Start hashing at the file's first byte with its whole length remaining."""
		file = p_file
		remaining = p_file.get_length()
		context = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)


# --- shared helpers ---------------------------------------------------------------------------

static func _refusal(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record in the save header's shape, so every save module returns one type."""
	return SaveHeader.Refusal.new(code, detail)


static func _accepted() -> SaveHeader.Refusal:
	"""The accepting refusal record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _digest_failure(refusal: SaveHeader.Refusal) -> DigestResult:
	"""A refused DigestResult carrying `refusal`'s code and detail and no digest."""
	return DigestResult.new(false, refusal.code, refusal.detail, PackedByteArray())


static func _domain_bytes(text: String) -> PackedByteArray:
	"""ASCII `text` followed by its literal terminating zero byte."""
	var bytes: PackedByteArray = text.to_ascii_buffer()
	bytes.append(0)
	return bytes


static func sha256_of(bytes: PackedByteArray) -> PackedByteArray:
	"""The raw 32-byte SHA-256 of `bytes`."""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish()


static func zero_digest() -> PackedByteArray:
	"""Thirty-two zero bytes: the procedural estuary's authored-map digest."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(DIGEST_BYTES)
	bytes.fill(0)
	return bytes


static func artifact_magic(kind: int) -> PackedByteArray:
	"""The domain prefix of a rules or lookup artifact, or empty for an unknown kind."""
	if kind == KIND_RULES:
		return _domain_bytes(RULES_MAGIC_TEXT)
	if kind == KIND_LOOKUP:
		return _domain_bytes(LOOKUP_MAGIC_TEXT)
	return PackedByteArray()


static func type_width(type: int) -> int:
	"""Byte width of one integer value of `type`; 0 for the string type and unknown types."""
	match type:
		TYPE_U8:
			return 1
		TYPE_U32, TYPE_I32:
			return 4
		TYPE_U64, TYPE_I64:
			return 8
	return 0


static func is_type_allowed(kind: int, type: int) -> bool:
	"""Types 0-5 in rules; 0-4 in lookup ("no string-valued integer tables")."""
	if kind == KIND_LOOKUP:
		return type >= TYPE_U8 and type <= TYPE_I64
	return kind == KIND_RULES and type >= TYPE_U8 and type <= TYPE_STRING


static func is_ascii_key_bytes(key: PackedByteArray) -> bool:
	"""Nonempty, at most KEY_MAX_BYTES, every byte printable ASCII 0x21..0x7e."""
	if key.is_empty() or key.size() > KEY_MAX_BYTES:
		return false
	for byte: int in key:
		if byte < KEY_BYTE_MIN or byte > KEY_BYTE_MAX:
			return false
	return true


static func compare_bytes(left: PackedByteArray, right: PackedByteArray) -> int:
	"""Unsigned bytewise order: -1, 0 or 1. A proper prefix sorts first."""
	var shared: int = mini(left.size(), right.size())
	for index: int in shared:
		if left[index] != right[index]:
			return -1 if left[index] < right[index] else 1
	if left.size() == right.size():
		return 0
	return -1 if left.size() < right.size() else 1


# --- map identity (offset 104) ----------------------------------------------------------------

static func _map_fields_refusal(scenario_version: int, effective_seed: int,
		map_generator_schema: int, authored_map_digest: PackedByteArray) -> SaveHeader.Refusal:
	"""Range-check the four provenance fields against their ruled wire widths."""
	if not SaveCodec.fits_u32(scenario_version):
		return _refusal(REFUSE_FIELD_RANGE, "scenario version %d is not a u32" % scenario_version)
	if not SaveCodec.fits_i32(effective_seed):
		return _refusal(REFUSE_FIELD_RANGE, "effective seed %d is not an i32" % effective_seed)
	if not SaveCodec.fits_u32(map_generator_schema):
		return _refusal(REFUSE_FIELD_RANGE,
			"map generator schema %d is not a u32" % map_generator_schema)
	if authored_map_digest.size() != DIGEST_BYTES:
		return _refusal(REFUSE_DIGEST_LENGTH, "the authored map digest is %d bytes, not %d"
			% [authored_map_digest.size(), DIGEST_BYTES])
	return _accepted()


static func map_hash(scenario_version: int, effective_seed: int, map_generator_schema: int,
		authored_map_digest: PackedByteArray) -> DigestResult:
	"""SHA-256 of `RWL-MAP-1\\0 || u32 || i32 || u32 || digest32`, integers little-endian.

	Pure over its arguments: this is the hash byte boundary only. Whether the provenance is
	supported locally is `provenance_support_refusal()`'s question, asked by `expected_map_hash()`.
	"""
	var fields: SaveHeader.Refusal = _map_fields_refusal(scenario_version, effective_seed,
		map_generator_schema, authored_map_digest)
	if not fields.is_ok():
		return _digest_failure(fields)
	var bytes: PackedByteArray = _domain_bytes(MAP_DOMAIN_TEXT)
	var at: int = bytes.size()
	bytes.resize(at + 12)
	bytes.encode_u32(at, scenario_version)
	bytes.encode_s32(at + 4, effective_seed)
	bytes.encode_u32(at + 8, map_generator_schema)
	bytes.append_array(authored_map_digest)
	return DigestResult.new(true, REFUSE_NONE, "", sha256_of(bytes))


# --- engine identity (offset 168) -------------------------------------------------------------

static func _engine_numbers_refusal(info: Dictionary) -> SaveHeader.Refusal:
	"""major, minor and patch must be present nonnegative integers."""
	for key: String in ENGINE_NUMBER_KEYS:
		if not info.has(key) or typeof(info[key]) != TYPE_INT or int(info[key]) < 0:
			return _refusal(REFUSE_ENGINE_UNIDENTIFIED,
				"engine version field '%s' is not a nonnegative integer" % key)
	return _accepted()


static func _engine_texts_refusal(info: Dictionary) -> SaveHeader.Refusal:
	"""status and build must be nonempty and hold no period or line feed, so the line is unambiguous."""
	for key: String in ENGINE_TEXT_KEYS:
		if not info.has(key) or not (info[key] is String):
			return _refusal(REFUSE_ENGINE_UNIDENTIFIED, "engine field '%s' is not a string" % key)
		var text: String = info[key]
		if text.is_empty() or text.contains(".") or text.contains("\n"):
			return _refusal(REFUSE_ENGINE_UNIDENTIFIED,
				"engine field '%s' is %s; it must be nonempty with no '.' or LF" % [key, text.c_escape()])
	return _accepted()


static func _engine_commit_refusal(info: Dictionary) -> SaveHeader.Refusal:
	"""The full commit hash: exactly 40 lowercase hex characters. An abbreviation is refused."""
	# `is String`, not `typeof(...) != TYPE_STRING`: this module's own TYPE_STRING (the artifact's
	# type code 5) shadows the engine's Variant.Type constant (4).
	if not info.has(ENGINE_HASH_KEY) or not (info[ENGINE_HASH_KEY] is String):
		return _refusal(REFUSE_ENGINE_UNIDENTIFIED, "this engine build reports no commit hash")
	var commit: String = info[ENGINE_HASH_KEY]
	if commit.length() != ENGINE_COMMIT_HASH_CHARS:
		return _refusal(REFUSE_ENGINE_UNIDENTIFIED, "the commit hash '%s' is %d characters, not %d"
			% [commit.c_escape(), commit.length(), ENGINE_COMMIT_HASH_CHARS])
	for index: int in commit.length():
		var code: int = commit.unicode_at(index)
		if not ((code >= 0x30 and code <= 0x39) or (code >= 0x61 and code <= 0x66)):
			return _refusal(REFUSE_ENGINE_UNIDENTIFIED,
				"the commit hash '%s' is not lowercase hexadecimal" % commit.c_escape())
	return _accepted()


static func engine_identity_line(info: Dictionary) -> TextResult:
	"""`major.minor.patch.status.build.full_commit_hash\\n` from a version-info dictionary.

	The same exact line ARCH-HASH-001 uses. Decimal numbers are formatted with `%d`, which is
	unlocalized. An unidentified build is refused rather than given a substitute line.
	"""
	for check: SaveHeader.Refusal in [_engine_numbers_refusal(info), _engine_texts_refusal(info),
			_engine_commit_refusal(info)]:
		if not check.is_ok():
			return TextResult.new(false, check.code, check.detail, "")
	var line: String = "%d.%d.%d.%s.%s.%s\n" % [int(info["major"]), int(info["minor"]),
		int(info["patch"]), String(info["status"]), String(info["build"]),
		String(info[ENGINE_HASH_KEY])]
	return TextResult.new(true, REFUSE_NONE, "", line)


static func engine_hash_of(info: Dictionary) -> DigestResult:
	"""SHA-256 of `engine_identity_line(info)`'s UTF-8 bytes, or its refusal."""
	var line: TextResult = engine_identity_line(info)
	if not line.ok:
		return DigestResult.new(false, line.error, line.detail, PackedByteArray())
	return DigestResult.new(true, REFUSE_NONE, "", sha256_of(line.text.to_utf8_buffer()))


static func engine_hash() -> DigestResult:
	"""The running engine's identity hash, or SAVE_IDENTITY_ENGINE_UNIDENTIFIED."""
	return engine_hash_of(Engine.get_version_info())


# --- artifact verification (rules offset 40, lookup offset 136) --------------------------------

static func _take(stream: _Stream, count: int) -> PackedByteArray:
	"""Read and hash exactly `count` (1..remaining) bytes; empty when they are not all there."""
	if count <= 0 or count > stream.remaining:
		return PackedByteArray()
	var bytes: PackedByteArray = stream.file.get_buffer(count)
	if bytes.size() != count:
		stream.remaining = 0
		return PackedByteArray()
	stream.context.update(bytes)
	stream.remaining -= count
	return bytes


static func _skip(stream: _Stream, count: int) -> bool:
	"""Hash `count` bytes through windows of at most CHUNK_BYTES; false when they are not all there."""
	var left: int = count
	while left > 0:
		var window: int = mini(left, CHUNK_BYTES)
		if _take(stream, window).size() != window:
			return false
		left -= window
	return true


static func _take_u32(stream: _Stream, what: String, out: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read one little-endian u32 into `out.value`, or refuse as truncated."""
	var bytes: PackedByteArray = _take(stream, LENGTH_PREFIX_BYTES)
	if bytes.size() != LENGTH_PREFIX_BYTES:
		return _refusal(REFUSE_ARTIFACT_TRUNCATED, "the artifact ends inside %s" % what)
	out.succeed(bytes.decode_u32(0))
	return _accepted()


static func verify_artifact_file(path: String, kind: int) -> DigestResult:
	"""Stream-verify one rules or lookup artifact and return SHA-256 of its exact bytes.

	Mutates nothing. Only the 32-byte digest survives; the file is never held whole.
	"""
	if artifact_magic(kind).is_empty():
		return _digest_failure(_refusal(REFUSE_ARTIFACT_KIND, "artifact kind %d is unknown" % kind))
	if not FileAccess.file_exists(path):
		return _digest_failure(_refusal(REFUSE_ARTIFACT_UNREADABLE, "no artifact at %s" % path))
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _digest_failure(_refusal(REFUSE_ARTIFACT_UNREADABLE, "could not open %s" % path))
	var stream: _Stream = _Stream.new(file)
	var refusal: SaveHeader.Refusal = _verify_stream(stream, kind)
	file.close()
	if not refusal.is_ok():
		return _digest_failure(refusal)
	return DigestResult.new(true, REFUSE_NONE, "", stream.context.finish())


static func _verify_stream(stream: _Stream, kind: int) -> SaveHeader.Refusal:
	"""Magic, a count bounded by the bytes left, that many records, then exact EOF."""
	var magic: PackedByteArray = artifact_magic(kind)
	if _take(stream, magic.size()) != magic:
		return _refusal(REFUSE_ARTIFACT_MAGIC, "the artifact does not begin with %s\\0"
			% (RULES_MAGIC_TEXT if kind == KIND_RULES else LOOKUP_MAGIC_TEXT))
	var count: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var read: SaveHeader.Refusal = _take_u32(stream, "the record count", count)
	if not read.is_ok():
		return read
	@warning_ignore("integer_division") var bound: int = stream.remaining / MIN_RECORD_BYTES
	if count.value > bound:
		return _refusal(REFUSE_ARTIFACT_COUNT_BOUND, "%d records cannot fit in %d remaining bytes"
			% [count.value, stream.remaining])
	for index: int in count.value:
		var record: SaveHeader.Refusal = _verify_record(stream, kind, index)
		if not record.is_ok():
			return record
	if stream.remaining != 0:
		return _refusal(REFUSE_ARTIFACT_TRAILING_BYTES,
			"%d bytes follow the declared records" % stream.remaining)
	return _accepted()


static func _verify_key(stream: _Stream, index: int) -> SaveHeader.Refusal:
	"""One key: nonempty ASCII, at most 256 bytes, strictly after the previous record's key."""
	var length: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var read: SaveHeader.Refusal = _take_u32(stream, "record %d's key length" % index, length)
	if not read.is_ok():
		return read
	if length.value == 0 or length.value > KEY_MAX_BYTES:
		return _refusal(REFUSE_ARTIFACT_KEY, "record %d's key is %d bytes; 1..%d are allowed"
			% [index, length.value, KEY_MAX_BYTES])
	var key: PackedByteArray = _take(stream, length.value)
	if key.size() != length.value:
		return _refusal(REFUSE_ARTIFACT_TRUNCATED, "the artifact ends inside record %d's key" % index)
	if not is_ascii_key_bytes(key):
		return _refusal(REFUSE_ARTIFACT_KEY, "record %d's key is not printable ASCII" % index)
	return _order_refusal(stream.previous_key, key, index, stream)


static func _order_refusal(previous: PackedByteArray, key: PackedByteArray, index: int,
		stream: _Stream) -> SaveHeader.Refusal:
	"""Refuse a duplicate or descending key; otherwise remember `key` as the previous one."""
	if index > 0:
		var order: int = compare_bytes(previous, key)
		if order == 0:
			return _refusal(REFUSE_ARTIFACT_DUPLICATE_KEY,
				"record %d repeats key %s" % [index, key.get_string_from_ascii()])
		if order > 0:
			return _refusal(REFUSE_ARTIFACT_UNSORTED_KEY, "record %d's key %s sorts before %s"
				% [index, key.get_string_from_ascii(), previous.get_string_from_ascii()])
	stream.previous_key = key
	return _accepted()


static func _verify_record(stream: _Stream, kind: int, index: int) -> SaveHeader.Refusal:
	"""`key:string, type:u8, element_count:u32, values` with every count bounded before reading."""
	var key: SaveHeader.Refusal = _verify_key(stream, index)
	if not key.is_ok():
		return key
	var type_bytes: PackedByteArray = _take(stream, 1)
	if type_bytes.size() != 1:
		return _refusal(REFUSE_ARTIFACT_TRUNCATED, "the artifact ends before record %d's type" % index)
	var type: int = type_bytes[0]
	if not is_type_allowed(kind, type):
		return _refusal(REFUSE_ARTIFACT_TYPE, "record %d has type %d, not allowed here" % [index, type])
	var count: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var read: SaveHeader.Refusal = _take_u32(stream, "record %d's element count" % index, count)
	if not read.is_ok():
		return read
	if type == TYPE_STRING:
		return _verify_strings(stream, index, count.value)
	@warning_ignore("integer_division") var bound: int = stream.remaining / type_width(type)
	if count.value > bound:
		return _refusal(REFUSE_ARTIFACT_COUNT_BOUND, "record %d declares %d values; %d bytes remain"
			% [index, count.value, stream.remaining])
	if not _skip(stream, count.value * type_width(type)):
		return _refusal(REFUSE_ARTIFACT_TRUNCATED, "the artifact ends inside record %d" % index)
	return _accepted()


static func _verify_strings(stream: _Stream, index: int, count: int) -> SaveHeader.Refusal:
	"""SAVE-R09-002 strings, each at most 4096 bytes of strict UTF-8."""
	@warning_ignore("integer_division") var bound: int = stream.remaining / LENGTH_PREFIX_BYTES
	if count > bound:
		return _refusal(REFUSE_ARTIFACT_COUNT_BOUND, "record %d declares %d strings; %d bytes remain"
			% [index, count, stream.remaining])
	var length: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for element: int in count:
		var read: SaveHeader.Refusal = _take_u32(stream, "record %d's string" % index, length)
		if not read.is_ok():
			return read
		if length.value > STRING_VALUE_MAX_BYTES:
			return _refusal(REFUSE_ARTIFACT_STRING, "record %d string %d is %d bytes; at most %d"
				% [index, element, length.value, STRING_VALUE_MAX_BYTES])
		if length.value == 0:
			continue
		var text: PackedByteArray = _take(stream, length.value)
		if text.size() != length.value:
			return _refusal(REFUSE_ARTIFACT_TRUNCATED, "the artifact ends inside record %d" % index)
		if SaveCodec.utf8_refusal(text, 0, length.value) != SaveCodec.REFUSE_NONE:
			return _refusal(REFUSE_ARTIFACT_STRING,
				"record %d string %d is not well-formed UTF-8" % [index, element])
	return _accepted()


static func rules_hash() -> DigestResult:
	"""Offset 40: SHA-256 of this build's verified `rules_identity.bin`, or its refusal.

	No artifact is committed until owners register (see the header), so today this refuses
	SAVE_IDENTITY_ARTIFACT_UNREADABLE -- never a made-up digest.
	"""
	return verify_artifact_file(RULES_ARTIFACT_PATH, KIND_RULES)


static func lookup_hash() -> DigestResult:
	"""Offset 136: SHA-256 of this build's verified `lookup_identity.bin`, or its refusal."""
	return verify_artifact_file(LOOKUP_ARTIFACT_PATH, KIND_LOOKUP)


# --- artifact writing (build time) ------------------------------------------------------------

static func _writer_fail(writer: ArtifactWriter, code: StringName,
		detail: String) -> SaveHeader.Refusal:
	"""Poison `writer` so nothing more is written, and return the refusal."""
	writer.failed = true
	return _refusal(code, detail)


static func writer_begin(writer: ArtifactWriter, file: FileAccess, kind: int,
		record_count: int) -> SaveHeader.Refusal:
	"""Write the magic and the declared record count. The caller owns the file and its rename."""
	if writer == null or file == null or writer.file != null:
		return _refusal(REFUSE_INPUT_MISSING, "a fresh writer and an open file are required")
	if artifact_magic(kind).is_empty():
		return _writer_fail(writer, REFUSE_ARTIFACT_KIND, "artifact kind %d is unknown" % kind)
	if not SaveCodec.fits_u32(record_count):
		return _writer_fail(writer, REFUSE_ARTIFACT_RECORD_COUNT,
			"%d records is not a u32" % record_count)
	writer.file = file
	writer.kind = kind
	writer.declared_count = record_count
	var head: PackedByteArray = artifact_magic(kind)
	head.append_array(_u32_bytes(record_count))
	return _writer_store(writer, head)


static func _u32_bytes(value: int) -> PackedByteArray:
	"""Four little-endian bytes of a value already proven to fit a u32."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(LENGTH_PREFIX_BYTES)
	bytes.encode_u32(0, value)
	return bytes


static func _writer_store(writer: ArtifactWriter, bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Append `bytes` to the artifact file, refusing on any write error."""
	if not writer.file.store_buffer(bytes) or writer.file.get_error() != OK:
		return _writer_fail(writer, REFUSE_ARTIFACT_WRITE, "the artifact file refused a write")
	return _accepted()


static func _writer_record_refusal(writer: ArtifactWriter, key: String,
		type: int) -> SaveHeader.Refusal:
	"""State, capacity, key and type checks shared by both append functions."""
	if writer == null or writer.file == null or writer.failed or writer.finished:
		return _refusal(REFUSE_ARTIFACT_WRITE, "the writer is not open for another record")
	if writer.written_count >= writer.declared_count:
		return _writer_fail(writer, REFUSE_ARTIFACT_RECORD_COUNT,
			"all %d declared records are already written" % writer.declared_count)
	var key_bytes: PackedByteArray = key.to_utf8_buffer()
	if not is_ascii_key_bytes(key_bytes):
		return _writer_fail(writer, REFUSE_ARTIFACT_KEY, "key '%s' is not 1..%d printable ASCII bytes"
			% [key.c_escape(), KEY_MAX_BYTES])
	if writer.written_count > 0:
		var order: int = compare_bytes(writer.previous_key, key_bytes)
		if order == 0:
			return _writer_fail(writer, REFUSE_ARTIFACT_DUPLICATE_KEY, "key %s repeats" % key)
		if order > 0:
			return _writer_fail(writer, REFUSE_ARTIFACT_UNSORTED_KEY, "key %s is out of order" % key)
	if not is_type_allowed(writer.kind, type):
		return _writer_fail(writer, REFUSE_ARTIFACT_TYPE, "type %d is not allowed here" % type)
	return _accepted()


static func _record_head(key: String, type: int, count: int) -> PackedByteArray:
	"""`key:string, type:u8, element_count:u32` for an already validated record."""
	var key_bytes: PackedByteArray = key.to_utf8_buffer()
	var head: PackedByteArray = _u32_bytes(key_bytes.size())
	head.append_array(key_bytes)
	head.append(type)
	head.append_array(_u32_bytes(count))
	return head


static func _integer_in_range(type: int, value: int) -> bool:
	"""True when `value` is representable in `type`'s declared width and signedness."""
	match type:
		TYPE_U8:
			return value >= 0 and value <= SaveCodec.UINT8_MAX
		TYPE_U32:
			return SaveCodec.fits_u32(value)
		TYPE_I32:
			return SaveCodec.fits_i32(value)
		TYPE_U64:
			return value >= 0
	return type == TYPE_I64


static func _encode_integer(type: int, value: int, out: PackedByteArray, at: int) -> void:
	"""Write one range-checked value little-endian at `at`."""
	match type:
		TYPE_U8:
			out.encode_u8(at, value)
		TYPE_U32:
			out.encode_u32(at, value)
		TYPE_I32:
			out.encode_s32(at, value)
		TYPE_U64:
			out.encode_u64(at, value)
		TYPE_I64:
			out.encode_s64(at, value)


static func writer_append_integers(writer: ArtifactWriter, key: String, type: int,
		values: PackedInt64Array) -> SaveHeader.Refusal:
	"""Append one integer record, values in declared order. Every value is checked first."""
	var state: SaveHeader.Refusal = _writer_record_refusal(writer, key, type)
	if not state.is_ok():
		return state
	if type == TYPE_STRING or not SaveCodec.fits_u32(values.size()):
		return _writer_fail(writer, REFUSE_ARTIFACT_TYPE, "record %s needs an integer type" % key)
	for index: int in values.size():
		if not _integer_in_range(type, values[index]):
			return _writer_fail(writer, REFUSE_ARTIFACT_VALUE_RANGE,
				"record %s value %d (%d) does not fit type %d" % [key, index, values[index], type])
	var stored: SaveHeader.Refusal = _writer_store(writer, _record_head(key, type, values.size()))
	if not stored.is_ok():
		return stored
	stored = _writer_store_integers(writer, type, values)
	if stored.is_ok():
		writer.previous_key = key.to_utf8_buffer()
		writer.written_count += 1
	return stored


static func _writer_store_integers(writer: ArtifactWriter, type: int,
		values: PackedInt64Array) -> SaveHeader.Refusal:
	"""Stream the values through windows of at most CHUNK_BYTES."""
	var width: int = type_width(type)
	@warning_ignore("integer_division") var per_window: int = CHUNK_BYTES / width
	var start: int = 0
	while start < values.size():
		var count: int = mini(per_window, values.size() - start)
		var window: PackedByteArray = PackedByteArray()
		window.resize(count * width)
		for index: int in count:
			_encode_integer(type, values[start + index], window, index * width)
		var stored: SaveHeader.Refusal = _writer_store(writer, window)
		if not stored.is_ok():
			return stored
		start += count
	return _accepted()


static func writer_append_strings(writer: ArtifactWriter, key: String,
		values: PackedStringArray) -> SaveHeader.Refusal:
	"""Append one rules string record (type 5); each value at most 4096 UTF-8 bytes."""
	var state: SaveHeader.Refusal = _writer_record_refusal(writer, key, TYPE_STRING)
	if not state.is_ok():
		return state
	var body: PackedByteArray = _record_head(key, TYPE_STRING, values.size())
	for index: int in values.size():
		var text: PackedByteArray = values[index].to_utf8_buffer()
		if text.size() > STRING_VALUE_MAX_BYTES:
			return _writer_fail(writer, REFUSE_ARTIFACT_STRING, "record %s string %d is %d bytes"
				% [key, index, text.size()])
		body.append_array(_u32_bytes(text.size()))
		body.append_array(text)
	var stored: SaveHeader.Refusal = _writer_store(writer, body)
	if stored.is_ok():
		writer.previous_key = key.to_utf8_buffer()
		writer.written_count += 1
	return stored


static func writer_finish(writer: ArtifactWriter) -> SaveHeader.Refusal:
	"""Require that exactly the declared number of records was written, then flush."""
	if writer == null or writer.file == null or writer.failed or writer.finished:
		return _refusal(REFUSE_ARTIFACT_WRITE, "the writer is not open")
	if writer.written_count != writer.declared_count:
		return _writer_fail(writer, REFUSE_ARTIFACT_RECORD_COUNT, "%d of %d declared records written"
			% [writer.written_count, writer.declared_count])
	writer.file.flush()
	if writer.file.get_error() != OK:
		return _writer_fail(writer, REFUSE_ARTIFACT_WRITE, "the artifact file failed to flush")
	writer.finished = true
	return _accepted()


# --- provenance (section-1 prefix) ------------------------------------------------------------

static func provenance_of(world: WorldInitScript, rng: RngScript) -> ProvenanceResult:
	"""The published world's provenance: estuary v1, the published seed, generator 1, zero digest.

	Refuses while no world is published and when the RNG's seed disagrees with the published one.
	"""
	if world == null or rng == null:
		return ProvenanceResult.new(false, REFUSE_PROVENANCE_UNAVAILABLE,
			"the world generator and the RNG are both required", null)
	var published: IntMath.IntResult = world.published_seed()
	if not published.ok:
		return ProvenanceResult.new(false, REFUSE_PROVENANCE_UNAVAILABLE,
			"no world is published: %s" % published.error, null)
	var seeded: IntMath.IntResult = rng.world_seed_value()
	if not seeded.ok or seeded.value != published.value:
		return ProvenanceResult.new(false, REFUSE_SEED_DISAGREES,
			"the published seed %d is not the RNG's seed (%s)"
				% [published.value, str(seeded.value) if seeded.ok else seeded.error], null)
	var out: Provenance = Provenance.new()
	out.scenario_version = SCENARIO_ESTUARY_V1
	out.effective_seed = published.value
	out.map_generator_schema = MAP_GENERATOR_SCHEMA_V1
	return ProvenanceResult.new(true, REFUSE_NONE, "", out)


static func provenance_from_prefix(prefix: PackedByteArray) -> ProvenanceResult:
	"""Decode exactly the 44-byte prefix read before any world is allocated. Not validated here."""
	if prefix.size() != PROVENANCE_PREFIX_BYTES:
		return ProvenanceResult.new(false, REFUSE_FIELD_RANGE, "the prefix is %d bytes, not %d"
			% [prefix.size(), PROVENANCE_PREFIX_BYTES], null)
	var out: Provenance = Provenance.new()
	out.scenario_version = prefix.decode_u32(0)
	out.effective_seed = prefix.decode_s32(4)
	out.map_generator_schema = prefix.decode_u32(8)
	out.authored_map_digest = prefix.slice(12, PROVENANCE_PREFIX_BYTES)
	return ProvenanceResult.new(true, REFUSE_NONE, "", out)


static func provenance_support_refusal(provenance: Provenance) -> SaveHeader.Refusal:
	"""Ranges, then the locally supported scenario/generator set and its authored content digest."""
	if provenance == null:
		return _refusal(REFUSE_INPUT_MISSING, "no provenance was supplied")
	var fields: SaveHeader.Refusal = _map_fields_refusal(provenance.scenario_version,
		provenance.effective_seed, provenance.map_generator_schema, provenance.authored_map_digest)
	if not fields.is_ok():
		return fields
	if provenance.scenario_version != SCENARIO_ESTUARY_V1:
		return _refusal(REFUSE_UNSUPPORTED_SCENARIO,
			"scenario version %d is not supported by this build" % provenance.scenario_version)
	if provenance.map_generator_schema != MAP_GENERATOR_SCHEMA_V1:
		return _refusal(REFUSE_UNSUPPORTED_GENERATOR,
			"map generator schema %d is not supported by this build" % provenance.map_generator_schema)
	if provenance.authored_map_digest != zero_digest():
		return _refusal(REFUSE_AUTHORED_DIGEST,
			"the procedural estuary has no authored map file; its digest must be zero")
	return _accepted()


static func expected_map_hash(provenance: Provenance) -> DigestResult:
	"""Validate incoming provenance against local content, then recompute its map hash."""
	var support: SaveHeader.Refusal = provenance_support_refusal(provenance)
	if not support.is_ok():
		return _digest_failure(support)
	return map_hash(provenance.scenario_version, provenance.effective_seed,
		provenance.map_generator_schema, provenance.authored_map_digest)


# --- the loader's compatibility check -----------------------------------------------------------

static func development_identity_hash(domain_text: String) -> DigestResult:
	"""SHA-256 of `domain\\0 || u32 length || canonical registry id`, for a DEVELOPMENT save only.

	ADR 1222 step 6 / DEC-055 Q9. Until owners register a release rules or lookup artifact, the
	development save states its rules and lookup identity as the canonical registry declaration
	it was written under. Every registry change moves `Digest.DECLARATION_ID`, so a save written
	under another declaration is refused (DEC-055 Q1). The distinct `-DEV-` domains make these
	digests unequal to any release artifact's, so a development save can never pass as a
	release save -- these are not "made-up hex digests in release saves".
	"""
	if domain_text != DEV_RULES_DOMAIN_TEXT and domain_text != DEV_LOOKUP_DOMAIN_TEXT:
		return DigestResult.new(false, REFUSE_ARTIFACT_KIND,
			"'%s' is not a development identity domain" % domain_text, PackedByteArray())
	var bytes: PackedByteArray = _domain_bytes(domain_text)
	var identity: PackedByteArray = Digest.DECLARATION_ID.to_utf8_buffer()
	bytes.append_array(_u32_bytes(identity.size()))
	bytes.append_array(identity)
	return DigestResult.new(true, REFUSE_NONE, "", sha256_of(bytes))


static func local_identity(development: bool = false) -> LocalIdentityResult:
	"""This build's rules, catalog, lookup and engine identities, refusing at the first gap.

	`development` selects the ADR 1222 development rules and lookup identities in place of the
	release artifacts, which do not exist yet; catalog and engine are the same either way.
	"""
	var out: LocalIdentity = LocalIdentity.new()
	var rules: DigestResult = development_identity_hash(DEV_RULES_DOMAIN_TEXT) if development \
		else rules_hash()
	if not rules.ok:
		return LocalIdentityResult.new(false, rules.error, "rules: " + rules.detail, null)
	var built: CatalogIdsScript.BuildResult = CatalogIdsScript.build()
	if not built.ok:
		return LocalIdentityResult.new(false, REFUSE_CATALOG_UNAVAILABLE, built.detail, null)
	var lookup: DigestResult = development_identity_hash(DEV_LOOKUP_DOMAIN_TEXT) if development \
		else lookup_hash()
	if not lookup.ok:
		return LocalIdentityResult.new(false, lookup.error, "lookup: " + lookup.detail, null)
	var engine: DigestResult = engine_hash()
	if not engine.ok:
		return LocalIdentityResult.new(false, engine.error, engine.detail, null)
	out.rules = rules.digest
	out.catalog = built.artifact.digest
	out.lookup = lookup.digest
	out.engine = engine.digest
	return LocalIdentityResult.new(true, REFUSE_NONE, "", out)


static func _inputs_refusal(header: SaveHeader.Header, incoming: Provenance,
		local: LocalIdentity) -> SaveHeader.Refusal:
	"""All three inputs present and every compared digest exactly 32 bytes."""
	if header == null or incoming == null or local == null:
		return _refusal(REFUSE_INPUT_MISSING, "header, incoming provenance and local identity are required")
	var digests: Array[PackedByteArray] = [header.rules_hash, header.catalog_hash, header.map_hash,
		header.lookup_hash, header.engine_hash, local.rules, local.catalog, local.lookup, local.engine]
	for index: int in digests.size():
		if digests[index].size() != DIGEST_BYTES:
			return _refusal(REFUSE_DIGEST_LENGTH, "identity digest %d of 9 is %d bytes, not %d"
				% [index + 1, digests[index].size(), DIGEST_BYTES])
	return _accepted()


static func _equal_refusal(code: StringName, name: String, saved: PackedByteArray,
		expected: PackedByteArray) -> SaveHeader.Refusal:
	"""Refuse with `code` unless the saved identity equals the expected one byte for byte."""
	if saved != expected:
		return _refusal(code, "the save's %s identity %s is not the expected %s"
			% [name, saved.hex_encode(), expected.hex_encode()])
	return _accepted()


static func compatibility_refusal(header: SaveHeader.Header, incoming: Provenance,
		local: LocalIdentity) -> SaveHeader.Refusal:
	"""Check all five header identities before any world is allocated.

	The incoming prefix is validated against local content first (it defines the expected map
	hash); the five comparisons then run in header-offset order 40, 72, 104, 136, 168.
	`incoming` is the file's OWN section-1 prefix (`provenance_from_prefix()`); `local` is
	`local_identity()`. Pure: reads no disk and touches no store.
	"""
	var inputs: SaveHeader.Refusal = _inputs_refusal(header, incoming, local)
	if not inputs.is_ok():
		return inputs
	var expected_map: DigestResult = expected_map_hash(incoming)
	if not expected_map.ok:
		return _refusal(expected_map.error, expected_map.detail)
	var checks: Array[SaveHeader.Refusal] = [
		_equal_refusal(REFUSE_RULES_MISMATCH, "rules", header.rules_hash, local.rules),
		_equal_refusal(REFUSE_CATALOG_MISMATCH, "catalog", header.catalog_hash, local.catalog),
		_equal_refusal(REFUSE_MAP_MISMATCH, "map", header.map_hash, expected_map.digest),
		_equal_refusal(REFUSE_LOOKUP_MISMATCH, "lookup", header.lookup_hash, local.lookup),
		_equal_refusal(REFUSE_ENGINE_MISMATCH, "engine", header.engine_hash, local.engine)]
	for check: SaveHeader.Refusal in checks:
		if not check.is_ok():
			return check
	return _accepted()
