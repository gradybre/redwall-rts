extends RefCounted
## ARCH-SAVE-002 section 14 NAME_POOL: `residents.gd`'s `_name_key`, 512 rows of variable-length
## UTF-8, wrapped in SAVE-LAYOUT-R01's standard owner block and encoded through `save_codec.gd`'s
## ARCH-SAVE-001 primitives.
##
## THIS IS THE FIRST VARIABLE-LENGTH SECTION IN THE FORMAT, and the framing it establishes is the
## one sections 3, 4, 5, 7, 8 and 13 inherit. Everything the two fixed sections
## (`save_section_rng.gd`, `save_section_world_runtime.gd`) could take for granted stops being
## true here, so the differences are stated rather than left to be rediscovered:
##
##   * THE LENGTH IS NO LONGER THE VALIDATION. Section 10 is exactly 112 bytes, so any other
##     length is a refusal and a truncated read is structurally impossible. Section 14's length
##     is a function of its contents, so a truncated section is a perfectly plausible length for
##     a different, shorter pool. TWO counts are therefore written explicitly -- the wrapper's
##     `payload_byte_length` and the payload's own `row_count` -- and NAME-R02 requires BOTH to
##     be validated, against each other and against the descriptor's section length.
##   * THE CODEC'S READER IS BOUNDED BY THE BUFFER, NOT BY THE SECTION. ARCH-SAVE-002's layout is
##     gapless (SAVE-R09-004), so the bytes after section 14 are section 15's, not absent. A
##     row-length prefix that runs past this section's end would be satisfied by the next
##     section's bytes and decode as a valid name. So every row is bounded against
##     `offset + length` here, not against `bytes.size()`, and `Reader.read_utf8_u32_into()` is
##     deliberately NOT used for a row: it cannot see a section boundary.
##   * TRAILING BYTES ARE A REFUSAL. SAVE-R09-002 requires rejecting trailing payload bytes, and
##     a section that decodes 512 valid rows and still has bytes left is not a short valid pool.
##
## THE BYTES (NAME-R02's §14 wrapper paragraph, 2026-09-12).
##
##   | Offset | Type       | Field                                  | Bytes    |
##   |-------:|------------|----------------------------------------|---------:|
##   |      0 | u32 LE     | store_count = 1                        |        4 |
##   |      4 | u32 LE     | owner_key byte length = 9              |        4 |
##   |      8 | utf8       | owner_key = "residents"                |        9 |
##   |     17 | u32 LE     | owner_schema_version = 1               |        4 |
##   |     21 | u64 LE     | primary_count = 512                    |        8 |
##   |     29 | u64 LE     | payload_byte_length                    |        8 |
##   |     37 | u32 LE     | row_count, always `ROW_COUNT` (512)    |        4 |
##   |     41 | row x512   | one row per resident slot, in order    | variable |
##
##   row = `utf8_byte_count:u32 LE` then exactly that many UTF-8 bytes. No NUL terminator, no
##   alignment, no padding (SAVE-R09-002). An empty name is the four bytes `00000000` and no
##   payload -- it is a PRESENT ROW WITH A ZERO-LENGTH NAME, never an absent row.
##
##   Bytes 4..36 are the 33-byte owner wrapper; `store_count` sits outside it. NAME-R02's own
##   arithmetic: payload length is `4 + sum(4 + utf8_byte_length(name[slot]))`, capped at 67588;
##   "owner-key length 9 makes the wrapper 33 bytes; total section cap 67625 bytes including
##   store_count". 4 + 33 + 67588 = 67625 exactly, and the all-empty floor is 4 + 33 + 2052 =
##   2089.
##
##   SECTION 14'S SCHEMA VERSION IS 2, not 1: NAME-R02 increments it "because the previously
##   exercised unwrapped payload was different". The version travels in `save_header.gd`'s
##   64-byte descriptor, which this module does not write; `SCHEMA_VERSION` below is the value
##   that descriptor must carry, published here so the two cannot drift.
##
## SAVE-R09-002's pinned fixtures are reproduced by this encoder inside the payload: empty
## `00000000`, `Oak` = `030000004f616b`, `Móle` = `050000004dc3b36c65`, and `01000000c0` /
## `02000000c080` both fail UTF-8. `test_save_section_name_pool.gd` asserts all five against this
## module, at their post-wrapper offsets.
##
## COLUMN-MAJOR IS SATISFIED TRIVIALLY, AND THAT IS WORTH SAYING. SAVE-LAYOUT-R01 rules that
## packed stores use column-major bytes: field schema order outer, ascending physical slot inner.
## Section 14 has exactly ONE member (`docs/persistence_state_registry.md`: "§14 NAME_POOL has
## exactly one member, `residents.gd`'s `_name_key`"), so column-major and record-major produce
## identical bytes and no choice is being made here. A later section with two variable-length
## columns MUST NOT read this file as precedent for interleaving them; it owes a full pass of
## column A over all slots before column B begins.
##
## THE EMPTY NAME IS THE COMMON CASE, NOT AN EDGE CASE, AND NAME-R02 SETTLES IT. GDD REQ-SET-040
## makes naming trigger-based and REQ-SET-041 says an anonymous resident "shall retain full
## persistent state and display species plus role and ID rather than a personal name". In the
## starter settlement exactly one of twelve residents is named. So 511 of 512 rows being
## `00000000` is the normal shape of this section, and the encoder writes every one of them:
## dropping empty rows would make the row index stop meaning the slot index.
##
## NAME-R02 REPLACED SAVE-R09-002's "A LIVE RESIDENT CANNOT LOAD AN EMPTY NAME". Read literally
## that sentence refused the starter settlement. The ruled table, which `residents.gd` now owns
## and this module enforces against a live store:
##
##   | Resident row                                | named | name                          |
##   |---------------------------------------------|------:|-------------------------------|
##   | Free                                        |     0 | empty                         |
##   | Present anonymous, INCLUDING a live resident |     0 | empty                         |
##   | Present named                               |     1 | nonempty valid personal name  |
##
## A retained dead or departed row follows its own occupancy rule and keeps its identity; this
## module never erases a name because `is_alive()` is false, and never consults liveness at all.
##
## NAME VALIDATION IS `residents.gd`'s, NOT THIS MODULE'S. NAME-R02: "One resident-owned
## validator is shared by set_name(), naming commands, automatic name assignment, save capture
## and restore." `ResidentsScript.name_refusal()` is that validator and every name rule below
## delegates to it; this module only MAPS its codes onto the `SAVE_NAMES_*` vocabulary a load
## report speaks. A second copy of the 128-byte / 2-32-scalar / control-code rules here is
## exactly the asymmetry blocker N3 recorded, so there is not one.
##
## PERSISTENCE OBLIGATION AND DIGEST MEMBERSHIP ARE SEPARATE AXES (decision 0063, and the
## READY_07 G3 ruling). Section 14 is BOTH: category 1 in the persistence registry, and inside
## ARCH-HASH-001, which includes "all authoritative occupied/generation and typed fields in schema
## order" and excludes selection/camera/UI/derived state by name -- `_name_key` is not among the
## exclusions, and SAVE-R09's canonical stream explicitly carries "Direct binary strings ...
## not intern IDs". BUT THE CANONICAL BYTES ARE NOT THE PAYLOAD BYTES, which is the second thing
## that does not transfer from section 10. REG-R01 fixes the canonical record as
## `(14, "residents", "_name_key", type 5, count 512, values)` and rules that "neither the two
## framing counts nor owner wrapper become extra canonical records", so `canonical_bytes_of()`
## emits the 512 values WITHOUT the wrapper and WITHOUT the `row_count:u32` prefix. It is a
## function, not a convention, and the test asserts the difference is exactly 41 bytes.
##
## ALLOCATE BEFORE CONSUME (decision 0059). `decode_into()` proves the declared extent present,
## checks the wrapper against the descriptor length, bounds every row-length prefix against the
## section end BEFORE reading its bytes, and lands everything in a local Record that is copied
## into `out` only after the whole record validates. `apply()` validates the record, validates
## the whole 512-row name/occupancy agreement, captures the prior names AND the prior flags, and
## only then writes; a refusal at any point leaves every collaborating store byte-identical.
##
## THE ORDERING RULE IS A PRECONDITION, NOT A SEQUENCE (NAME-R02, closing blocker N4). "Name/
## occupancy agreement is validated before any setter can rewrite the incoming `_named` flag;
## 'apply names last' must not conceal corruption." Sequencing section 4 before section 14 is not
## enough on its own: `set_name()` recomputes `_named` from emptiness, so a mismatched pair would
## be repaired into a self-consistent row and never reported. `apply()` therefore runs
## `occupancy_refusal()` over all 512 rows BEFORE its first write, and then writes through
## `residents.gd::restore_name()`, which takes the flag explicitly and derives nothing.
##
## COLD PATH. ARCH-SAVE-003 saves at a completed boundary, so this module allocates freely. It is
## NOT a per-tick path; ARCH-MEM-001's allocation ban applies to `residents.gd`'s columns, which
## this module only reads through the public API.
##
## NO FLOAT (ARCH-AUTH-002). The test greps this source to enforce that.
##
## OPEN, NOT INVENTED (AGENTS.md "do not invent a constant"):
##   * BLOCKERS N1, N2, N3 AND N4 ARE CLOSED by NAME-R02 and REG-R01 and are recorded here as
##     history, not as outstanding work. N1's wrapper is above with the ruling's own byte
##     arithmetic; N2's live-anonymous reading is the ruled table; N3's setter validation is
##     `residents.gd::name_refusal()`; N4's ordering is `occupancy_refusal()` before the first
##     write. See `docs/decisions/0112-*.md`.
##   * WHAT IS STILL MISSING IS SECTION 4. No residents codec exists, so nothing restores
##     `_named`, `_present` or any other §4 column, and `apply()` reads the incoming flags out of
##     whatever the orchestrator has already built. This module cannot supply them: writing
##     `_named` from section 14 would put one future-affecting value in two sections and is the
##     exact concealment NAME-R02 forbids. No release-save completeness is claimed.
##   * `schema_version` in the 64-byte descriptor is carried opaquely by `save_header.gd` and is
##     not set here, exactly as `save_section_rng.gd` does not set it. `SCHEMA_VERSION` below
##     publishes the value it must carry.
##   * The section CRC-32 and body SHA-256 are `save_header.gd`'s; this module produces the
##     payload bytes those protect and computes neither.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 13 CHRONICLE, 14 NAME_POOL, 15 STATE_DIGEST".
const SECTION_ID: int = 14

## NAME-R02: "Section 14's schema version becomes 2, because the previously exercised unwrapped
## payload was different." REG-R01's baseline section vector puts a 2 at index 14 for this reason.
const SCHEMA_VERSION: int = 2

## Taken from `residents.gd` rather than restated, so the two cannot drift to different capacities.
## The registry row is explicit that this is the full 512-row capacity, not the living count.
const ROW_COUNT: int = ResidentsScript.RESIDENT_CAPACITY

# --- SAVE-LAYOUT-R01 owner wrapper, registered by NAME-R02 ----------------------------------------

## NAME-R02: "Register owner `residents`, owner schema 1, primary_count 512."
const STORE_COUNT: int = 1
const OWNER_KEY: String = "residents"
const OWNER_KEY_BYTES: int = 9
## SAVE-LAYOUT-R01: owner keys are nonempty ASCII, at most 256 bytes.
const OWNER_KEY_MAX_BYTES: int = 256
const OWNER_SCHEMA_VERSION: int = 1
const PRIMARY_COUNT: int = ROW_COUNT

const OFFSET_STORE_COUNT: int = 0
const OFFSET_OWNER_KEY_LENGTH: int = 4
const OFFSET_OWNER_KEY: int = 8
const OFFSET_OWNER_SCHEMA_VERSION: int = 17
const OFFSET_PRIMARY_COUNT: int = 21
const OFFSET_PAYLOAD_BYTE_LENGTH: int = 29

const STORE_COUNT_BYTES: int = SaveCodec.U32_BYTES
## 4 key length + 9 key + 4 schema + 8 primary_count + 8 payload_byte_length. NAME-R02 states 33.
const WRAPPER_BYTES: int = 33
## Everything before the payload: `store_count` sits outside the wrapper.
const FRAMING_BYTES: int = STORE_COUNT_BYTES + WRAPPER_BYTES

# --- the payload ------------------------------------------------------------------------------------

## The explicit row-count prefix. RETAINED by NAME-R02 ("retain its existing inner count; validate
## both counts"), because the section length no longer implies the count.
const ROW_COUNT_BYTES: int = SaveCodec.U32_BYTES

## SAVE-R09-002: "utf8_byte_count:u32 LE followed by exactly that many UTF-8 bytes". S1 settles
## that the prefix is a little-endian UTF-8 BYTE length, never a character count.
const LENGTH_PREFIX_BYTES: int = SaveCodec.U32_BYTES

## The name rules are `residents.gd`'s. Mirrored as constants only so the wire arithmetic below
## reads as arithmetic; the VALIDATOR is never duplicated.
const NAME_MAX_UTF8_BYTES: int = ResidentsScript.NAME_MAX_UTF8_BYTES
const NAME_MIN_SCALARS: int = ResidentsScript.NAME_MIN_SCALARS
const NAME_MAX_SCALARS: int = ResidentsScript.NAME_MAX_SCALARS

## SAVE-R09-002: "Independently enforce the 131072-byte name-pool arena limit." It is enforced
## independently even though `ROW_COUNT * NAME_MAX_UTF8_BYTES` = 65536 already bounds it at half
## that: the per-name cap and the arena cap are two separate rules and either may move.
const ARENA_MAX_BYTES: int = 131072

## Every row empty: the row-count prefix plus 512 zero-length prefixes. NAME-R02's `4 + sum(4 +
## utf8_byte_length(name[slot]))` at every name empty.
const PAYLOAD_MIN_BYTES: int = ROW_COUNT_BYTES + ROW_COUNT * LENGTH_PREFIX_BYTES

## Every row at the 128-byte cap. NAME-R02 caps the payload at exactly this number.
const PAYLOAD_MAX_BYTES: int = PAYLOAD_MIN_BYTES + ROW_COUNT * NAME_MAX_UTF8_BYTES

## Whole-section bounds, framing included. 37 + 2052 and 37 + 67588; the upper one is NAME-R02's
## stated 67625-byte section cap.
const MIN_SECTION_BYTES: int = FRAMING_BYTES + PAYLOAD_MIN_BYTES
const MAX_SECTION_BYTES: int = FRAMING_BYTES + PAYLOAD_MAX_BYTES

# --- REG-R01's canonical field record ---------------------------------------------------------------

## `(14, "residents", "_name_key", type 5, count 512, values)`. Published as constants so section
## 15's walker reads the identity off the owner instead of reconstructing it from a display label.
const CANONICAL_OWNER_KEY: String = OWNER_KEY
const CANONICAL_FIELD_KEY: String = "_name_key"
## SAVE-R09's type code for `utf8_u32`.
const CANONICAL_TYPE_UTF8_U32: int = 5
const CANONICAL_VALUE_COUNT: int = ROW_COUNT

## The registry's declared unused value for `_name_key`: "Empty string for an unnamed row".
const CANONICAL_UNUSED_NAME: String = ""

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_NAMES_NEGATIVE_OFFSET"
const REFUSE_NEGATIVE_LENGTH: StringName = &"SAVE_NAMES_NEGATIVE_LENGTH"
const REFUSE_SECTION_LENGTH: StringName = &"SAVE_NAMES_SECTION_LENGTH"
const REFUSE_EXTENT: StringName = &"SAVE_NAMES_EXTENT"
const REFUSE_STORE_COUNT: StringName = &"SAVE_NAMES_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_NAMES_OWNER_KEY"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_NAMES_OWNER_SCHEMA_VERSION"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_NAMES_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_NAMES_PAYLOAD_LENGTH"
const REFUSE_ROW_COUNT: StringName = &"SAVE_NAMES_ROW_COUNT"
const REFUSE_TRUNCATED: StringName = &"SAVE_NAMES_TRUNCATED"
const REFUSE_TRAILING_BYTES: StringName = &"SAVE_NAMES_TRAILING_BYTES"
const REFUSE_MALFORMED_UTF8: StringName = &"SAVE_NAMES_MALFORMED_UTF8"
const REFUSE_NAME_BYTES: StringName = &"SAVE_NAMES_NAME_BYTES"
const REFUSE_NAME_SCALARS: StringName = &"SAVE_NAMES_NAME_SCALARS"
const REFUSE_CONTROL_CHARACTER: StringName = &"SAVE_NAMES_CONTROL_CHARACTER"
const REFUSE_ARENA_LIMIT: StringName = &"SAVE_NAMES_ARENA_LIMIT"
const REFUSE_RECORD_SIZE: StringName = &"SAVE_NAMES_RECORD_SIZE"
const REFUSE_NAMED_ROW_EMPTY: StringName = &"SAVE_NAMES_NAMED_ROW_EMPTY"
const REFUSE_ANONYMOUS_ROW_NAMED: StringName = &"SAVE_NAMES_ANONYMOUS_ROW_NAMED"
const REFUSE_ABSENT_ROW_NAMED: StringName = &"SAVE_NAMES_ABSENT_ROW_NAMED"
const REFUSE_STORE_REFUSED: StringName = &"SAVE_NAMES_STORE_REFUSED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_NAMES_ENCODE_FAILED"


class Record:
	"""One decoded section 14: 512 names indexed by resident slot, allocated once in `_init`.

	CODEC SCRATCH, NOT A NEW AUTHORITATIVE COLUMN. This mirrors `residents.gd`'s `_name_key` for
	the duration of one save or one load and holds no state the simulation reads; the
	authoritative column stays in `residents.gd`. It is a category 3 transient under decision
	0063's accounting, which is still an allocation that must be declared -- see the ADR.

	Row index IS slot index. An absent slot holds `CANONICAL_UNUSED_NAME`, which is also what an
	anonymous present resident holds; the two are distinguished by `residents.gd`'s `_present`
	column in section 4, never by this section.
	"""
	var names: PackedStringArray = PackedStringArray()

	func _init() -> void:
		"""Allocate the 512-row column and fill it with the declared canonical unused value."""
		names.resize(ROW_COUNT)
		names.fill(CANONICAL_UNUSED_NAME)

	func clear() -> void:
		"""Return every row to the canonical unused empty name without reallocating."""
		names.fill(CANONICAL_UNUSED_NAME)

	func copy_from(other: Record) -> void:
		"""Overwrite every row from `other` without reallocating."""
		for slot: int in ROW_COUNT:
			names[slot] = other.names[slot]

	func arena_bytes() -> int:
		"""Total encoded UTF-8 bytes of every name, excluding all framing. The arena occupancy."""
		var total: int = 0
		for slot: int in ROW_COUNT:
			total += SaveCodec.utf8_byte_length(names[slot])
		return total

	func payload_bytes() -> int:
		"""NAME-R02's `4 + sum(4 + utf8_byte_length(name[slot]))`: the wrapper's declared length."""
		return PAYLOAD_MIN_BYTES + arena_bytes()

	func section_bytes() -> int:
		"""Whole-section length this record encodes to, `store_count` and wrapper included."""
		return FRAMING_BYTES + payload_bytes()


class EncodeResult:
	"""Outcome of encoding one section: the payload bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded payload; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- capture -------------------------------------------------------------------------------------

static func capture_into(store: ResidentsScript, out: Record) -> SaveHeader.Refusal:
	"""Read a live store's 512 name rows into a caller-owned Record. `out` untouched on refusal.

	Reads through `name_key_of()`, which returns the empty name for an absent row, so the
	captured column already carries the registry's declared canonical unused value and no stale
	physical byte can leak into a save.

	Refuses an INCONSISTENT live store through `residents.gd::row_name_refusal()`, which checks
	the PHYSICAL `(_named, _name_key)` pair of every row against NAME-R02's table. A flagged-named
	row with an empty key and a free row with a leftover key are both refusals; a live anonymous
	row with an empty key is the ordinary case and is not.
	"""
	var parsed: Record = Record.new()
	for slot: int in ROW_COUNT:
		var code: StringName = store.row_name_refusal(slot)
		if code != ResidentsScript.REFUSE_NONE:
			return SaveHeader.Refusal.new(_mapped_occupancy_refusal(code),
				"slot %d fails the NAME-R02 occupancy table with %s" % [slot, code])
		parsed.names[slot] = String(store.name_key_of(slot))
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Encode a Record as the whole of section 14. Validates every row before it writes a byte.

	Validation comes first so a refused encode produces no bytes at all, rather than a buffer of
	a plausible length holding an unvalidated name. The wrapper's `payload_byte_length` is the
	record's own computed payload length, and the final size check proves the two agree.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var payload: int = record.payload_bytes()
	var expected: int = FRAMING_BYTES + payload
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(expected)
	_write_framing(writer, payload)
	for slot: int in ROW_COUNT:
		writer.write_utf8_u32(record.names[slot], NAME_MAX_UTF8_BYTES)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != expected:
		return out.refuse(REFUSE_SECTION_LENGTH,
			"encoded %d bytes, not the computed %d" % [bytes.size(), expected])
	return out.succeed(bytes)


static func _write_framing(writer: SaveCodec.Writer, payload_byte_length: int) -> void:
	"""Write `store_count`, the 33-byte owner wrapper and the payload's own `row_count`.

	Both counts are written because NAME-R02 retains the inner one and requires both to be
	validated; the wrapper's length is passed in rather than recomputed here so exactly one
	arithmetic produces it.
	"""
	writer.write_u32(STORE_COUNT)
	writer.write_utf8_u32(OWNER_KEY, OWNER_KEY_MAX_BYTES)
	writer.write_u32(OWNER_SCHEMA_VERSION)
	writer.write_u64(PRIMARY_COUNT)
	writer.write_u64(payload_byte_length)
	writer.write_u32(ROW_COUNT)


static func encode_store(store: ResidentsScript, out: EncodeResult) -> bool:
	"""Capture a live store and encode it in one call, for a caller that keeps no Record."""
	var record: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(store, record)
	if not captured.is_ok():
		return out.refuse(captured.code, captured.detail)
	return encode_record(record, out)


# --- decode ----------------------------------------------------------------------------------------

static func decode_into(bytes: PackedByteArray, offset: int, length: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode section 14 from the descriptor's `offset` and `length`, validating before publishing.

	VALIDATE THEN COMMIT, never commit then validate. Every row lands in a local Record, the whole
	record is revalidated by `record_refusal()` after the last row, and only then is `out` written.
	A section of exactly the declared length whose rows are individually well-formed but whose
	arena overruns, or whose row count is wrong, is refused with `out` byte-identical -- the
	extent gate cannot catch that class, which is why the second validation exists.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset, length)
	if not extent.is_ok():
		return extent
	var parsed: Record = Record.new()
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	var body: SaveHeader.Refusal = _read_body(bytes, reader, parsed, offset, length)
	if not body.is_ok():
		return body
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int, length: int) -> SaveHeader.Refusal:
	"""Prove `length` bytes are readable at `offset`, overflow-safely, and that `length` is legal.

	PUBLIC BECAUSE IT IS THE PRIMARY GATE and must be testable on its own, exactly as
	`save_section_rng.gd::extent_refusal()` is: `save_codec.gd`'s Reader is bounded too, so a
	slack extent check here would still end in some refusal one layer down and hide. A load
	orchestrator can also ask this before committing to a section.

	The addition `offset + length` is never performed; `offset > bytes.size() - length` is the
	same test without the overflow.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if length < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_LENGTH, "length %d is negative" % length)
	if length < MIN_SECTION_BYTES or length > MAX_SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_SECTION_LENGTH,
			"section 14 length %d is outside %d..%d" % [length, MIN_SECTION_BYTES,
				MAX_SECTION_BYTES])
	if bytes.size() < length or offset > bytes.size() - length:
		return SaveHeader.Refusal.new(REFUSE_EXTENT,
			"section 14 needs %d bytes at offset %d, buffer holds %d"
				% [length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_body(bytes: PackedByteArray, reader: SaveCodec.Reader, parsed: Record,
		offset: int, length: int) -> SaveHeader.Refusal:
	"""Read the framing and 512 rows, then demand the section is consumed exactly."""
	var section_end: int = offset + length
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var framing: SaveHeader.Refusal = _read_framing(reader, length)
	if not framing.is_ok():
		return framing
	for slot: int in ROW_COUNT:
		var row: SaveHeader.Refusal = _read_row_into(bytes, reader, parsed, slot, section_end)
		if not row.is_ok():
			return row
	if reader.position() != section_end:
		return SaveHeader.Refusal.new(REFUSE_TRAILING_BYTES,
			"%d bytes remain after 512 rows" % (section_end - reader.position()))
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_framing(reader: SaveCodec.Reader, length: int) -> SaveHeader.Refusal:
	"""Read `store_count`, the owner wrapper and `row_count`, validating BOTH counts (NAME-R02).

	`payload_byte_length` is checked against the descriptor's own section length rather than
	merely against the bounds: a wrapper that claims a different payload from the one the
	descriptor frames is a disagreement between two authorities and there is no repair for it.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 14 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	var owner: SaveHeader.Refusal = _read_owner(reader)
	if not owner.is_ok():
		return owner
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"primary_count %d is not the compiled %d" % [scalar.value, PRIMARY_COUNT])
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != length - FRAMING_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"payload_byte_length %d disagrees with the %d bytes the descriptor frames"
				% [scalar.value, length - FRAMING_BYTES])
	return _read_row_count(reader)


static func _read_owner(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read the owner key and its schema version, refusing any owner but `residents`."""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEY:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"section 14 block is owned by '%s', not '%s'" % [text.value, OWNER_KEY])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner schema %d is not the supported %d" % [scalar.value, OWNER_SCHEMA_VERSION])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_row_count(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read the payload's retained inner `row_count` and check it against the compiled capacity."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != ROW_COUNT:
		return SaveHeader.Refusal.new(REFUSE_ROW_COUNT,
			"section 14 declares %d rows, not the compiled %d" % [scalar.value, ROW_COUNT])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_row_into(bytes: PackedByteArray, reader: SaveCodec.Reader, parsed: Record,
		slot: int, section_end: int) -> SaveHeader.Refusal:
	"""Read one length-prefixed name, bounded against the SECTION end rather than the buffer end.

	The layout is gapless, so bounding against the buffer would let an over-long prefix eat
	section 15's bytes and decode as a valid name. Both bounds are checked as subtractions.
	"""
	if section_end - reader.position() < LENGTH_PREFIX_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"slot %d: no room for a length prefix before the section ends" % slot)
	var declared: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(declared):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if declared.value > NAME_MAX_UTF8_BYTES:
		return SaveHeader.Refusal.new(REFUSE_NAME_BYTES,
			"slot %d declares %d bytes, over the %d-byte cap"
				% [slot, declared.value, NAME_MAX_UTF8_BYTES])
	if section_end - reader.position() < declared.value:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"slot %d declares %d bytes with %d left in the section"
				% [slot, declared.value, section_end - reader.position()])
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not SaveCodec.decode_utf8_into(bytes, reader.position(), declared.value, text):
		return SaveHeader.Refusal.new(REFUSE_MALFORMED_UTF8,
			"slot %d: %s (%s)" % [slot, text.detail, text.refusal])
	parsed.names[slot] = text.value
	reader.seek(reader.position() + declared.value)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule section 14 can check without a live store: shape, each name, and the arena.

	The arena total is checked AFTER the per-name loop because the two caps bound different
	things: 128 bytes per name and 131072 bytes across the pool. SAVE-R09-002 requires both
	independently.
	"""
	if record.names.size() != ROW_COUNT:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SIZE,
			"a section 14 record holds %d rows, not %d" % [record.names.size(), ROW_COUNT])
	for slot: int in ROW_COUNT:
		var invalid: SaveHeader.Refusal = name_refusal(slot, record.names[slot])
		if not invalid.is_ok():
			return invalid
	var arena: int = record.arena_bytes()
	if arena > ARENA_MAX_BYTES:
		return SaveHeader.Refusal.new(REFUSE_ARENA_LIMIT,
			"the pool holds %d name bytes, over the %d-byte arena limit"
				% [arena, ARENA_MAX_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func name_refusal(slot: int, name_value: String) -> SaveHeader.Refusal:
	"""Validate one name THROUGH `residents.gd`'s shared validator. Empty is accepted.

	NAME-R02 gives the store one validator for the setter, the naming command, automatic name
	assignment, capture and restore. This function adds no rule of its own: it calls that
	validator and translates its code into the `SAVE_NAMES_*` vocabulary a load report speaks,
	so the wire cannot enforce a rule the setter does not.
	"""
	var code: StringName = ResidentsScript.name_refusal(StringName(name_value))
	if code == ResidentsScript.REFUSE_NONE:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	return SaveHeader.Refusal.new(_mapped_name_refusal(code), _name_detail(slot, name_value, code))


static func _mapped_name_refusal(code: StringName) -> StringName:
	"""Translate one `residents.gd` name code into this section's refusal vocabulary."""
	if code == ResidentsScript.REFUSE_NAME_BYTES:
		return REFUSE_NAME_BYTES
	if code == ResidentsScript.REFUSE_NAME_SCALARS:
		return REFUSE_NAME_SCALARS
	if code == ResidentsScript.REFUSE_NAME_CONTROL:
		return REFUSE_CONTROL_CHARACTER
	return REFUSE_MALFORMED_UTF8


static func _mapped_occupancy_refusal(code: StringName) -> StringName:
	"""Translate one `residents.gd` occupancy code, falling through to the name codes."""
	if code == ResidentsScript.REFUSE_NAMED_ROW_EMPTY:
		return REFUSE_NAMED_ROW_EMPTY
	if code == ResidentsScript.REFUSE_ANONYMOUS_ROW_NAMED:
		return REFUSE_ANONYMOUS_ROW_NAMED
	if code == ResidentsScript.REFUSE_FREE_ROW_NAMED:
		return REFUSE_ABSENT_ROW_NAMED
	return _mapped_name_refusal(code)


static func _name_detail(slot: int, name_value: String, code: StringName) -> String:
	"""Human-readable detail for one refused name, naming the offending control scalar exactly."""
	if code == ResidentsScript.REFUSE_NAME_CONTROL:
		for index: int in name_value.length():
			if ResidentsScript.is_control_scalar(name_value.unicode_at(index)):
				return "slot %d carries control scalar U+%04X at index %d" \
					% [slot, name_value.unicode_at(index), index]
	return "slot %d holds %d Unicode scalars in %d UTF-8 bytes, refused as %s" % [slot,
		name_value.length(), SaveCodec.utf8_byte_length(name_value), code]


static func is_control_scalar(code_point: int) -> bool:
	"""True for Unicode general category Cc: U+0000-U+001F, U+007F-U+009F.

	Public so the rule is testable directly from this module, and delegating so there is exactly
	one control-code predicate in the codebase -- `residents.gd`'s.
	"""
	return ResidentsScript.is_control_scalar(code_point)


# --- apply -------------------------------------------------------------------------------------------

static func apply(record: Record, store: ResidentsScript) -> SaveHeader.Refusal:
	"""Publish a decoded section 14 into a live store, all 512 rows or none.

	ALLOCATE BEFORE CONSUME (decision 0059). The record is validated, the whole 512-row
	name/occupancy agreement is validated, the store's own current names AND flags are captured,
	and only then is the first write issued. A refusal at any stage leaves every name in the
	store exactly as it was; a refusal from the store mid-write rolls the earlier writes back.

	SECTION 4 MUST BE APPLIED FIRST, and sequencing alone is not the rule (NAME-R02). The
	agreement is checked BEFORE any setter runs, and the writes go through `restore_name()`,
	which takes the incoming flag explicitly instead of recomputing it from emptiness.
	"""
	var refused: SaveHeader.Refusal = apply_precondition_refusal(record, store)
	if not refused.is_ok():
		return refused
	var prior: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(store, prior)
	if not captured.is_ok():
		return captured
	var flags: PackedByteArray = _captured_flags(store)
	for slot: int in ROW_COUNT:
		if not store.is_present(slot):
			continue
		var written: ResidentsScript.OpResult = store.restore_name(slot, flags[slot] == 1,
			StringName(record.names[slot]))
		if written.ok:
			continue
		_roll_back(prior, flags, store)
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"slot %d refused with %s; the store was rolled back" % [slot, written.error])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func apply_precondition_refusal(record: Record,
		store: ResidentsScript) -> SaveHeader.Refusal:
	"""Record shape and every name rule, then NAME-R02's whole name/occupancy agreement.

	Ordered so a malformed record is reported as a malformed record rather than as whichever row
	first disagrees with the store.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	return occupancy_refusal(record, store)


static func occupancy_refusal(record: Record, store: ResidentsScript) -> SaveHeader.Refusal:
	"""NAME-R02's table over all 512 rows, evaluated BEFORE any setter can rewrite `_named`.

	THIS IS WHAT STOPS "APPLY NAMES LAST" CONCEALING CORRUPTION. Three disagreements are possible
	and all three are refusals, never repairs: a free slot the pool names, a row section 4 flagged
	named for which section 14 supplies nothing, and a row section 4 left anonymous for which
	section 14 supplies a name. A derived flag would silently produce agreement in the last two
	and the save's disagreement would never be reported.

	PUBLIC so a load orchestrator can ask for the verdict without committing to the write.
	"""
	for slot: int in ROW_COUNT:
		var present: bool = store.is_present(slot)
		var code: StringName = ResidentsScript.name_occupancy_refusal(present,
			store.is_named(slot), StringName(record.names[slot]))
		if code == ResidentsScript.REFUSE_NONE:
			continue
		return SaveHeader.Refusal.new(_mapped_occupancy_refusal(code),
			"slot %d: the store has present=%s named=%s, the pool supplies %d name bytes (%s)"
				% [slot, present, store.is_named(slot),
					SaveCodec.utf8_byte_length(record.names[slot]), code])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _captured_flags(store: ResidentsScript) -> PackedByteArray:
	"""The store's incoming `_named` column, taken once before the first write.

	Read before writing so `apply()` never asks the store for a flag it has already changed, and
	so the rollback can put the exact prior pair back rather than a derived one.
	"""
	var flags: PackedByteArray = PackedByteArray()
	flags.resize(ROW_COUNT)
	for slot: int in ROW_COUNT:
		flags[slot] = 1 if store.is_named(slot) else 0
	return flags


static func _roll_back(prior: Record, flags: PackedByteArray, store: ResidentsScript) -> void:
	"""Restore a captured name/flag pair after a failed apply. Both halves came out of this store."""
	for slot: int in ROW_COUNT:
		if not store.is_present(slot):
			continue
		store.restore_name(slot, flags[slot] == 1, StringName(prior.names[slot]))


# --- ARCH-HASH-001 contribution ------------------------------------------------------------------

static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This section's ARCH-HASH-001 contribution: the 512 values, WITHOUT any framing at all.

	NOT the section payload, and that is the point of keeping this a function. REG-R01 fixes the
	canonical record as `(14, "residents", "_name_key", type 5, count 512, values)` and rules that
	"neither the two framing counts nor owner wrapper become extra canonical records", so this
	emits neither `store_count`, nor the owner wrapper, nor `row_count`. The walker supplies
	`value_count` itself; repeating it would hash 512 twice and make the digest disagree with a
	walker that followed the grammar. Each type-5 value keeps its own u32 UTF-8 byte length,
	which is exactly the row encoding above.

	`section_id`, `owner_key` and `field_key` are NOT emitted here: they are the record PREFIX,
	which section 15 owns along with the `RWL-STATE-1` domain string and the final SHA-256. They
	are published as constants above so section 15 reads them off this owner.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(record.arena_bytes()
		+ ROW_COUNT * LENGTH_PREFIX_BYTES)
	for slot: int in ROW_COUNT:
		writer.write_utf8_u32(record.names[slot], NAME_MAX_UTF8_BYTES)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	return out.succeed(writer.to_bytes())
