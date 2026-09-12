extends RefCounted
## ARCH-SAVE-002 section 14 NAME_POOL: `residents.gd`'s `_name_key`, 512 rows of variable-length
## UTF-8, encoded through `save_codec.gd`'s ARCH-SAVE-001 primitives.
##
## THIS IS THE FIRST VARIABLE-LENGTH SECTION IN THE FORMAT, and the framing it establishes is the
## one sections 3, 4, 5, 7, 8 and 13 inherit. Everything the two fixed sections
## (`save_section_rng.gd`, `save_section_world_runtime.gd`) could take for granted stops being
## true here, so the differences are stated rather than left to be rediscovered:
##
##   * THE LENGTH IS NO LONGER THE VALIDATION. Section 10 is exactly 108 bytes, so any other
##     length is a refusal and a truncated read is structurally impossible. Section 14's length
##     is a function of its contents, so a truncated section is a perfectly plausible length for
##     a different, shorter pool. The row count is therefore written EXPLICITLY and checked
##     against the compiled capacity, and `decode_into()` takes the descriptor's section LENGTH
##     as well as its offset so it can demand exact consumption.
##   * THE CODEC'S READER IS BOUNDED BY THE BUFFER, NOT BY THE SECTION. ARCH-SAVE-002's layout is
##     gapless (SAVE-R09-004), so the bytes after section 14 are section 15's, not absent. A
##     row-length prefix that runs past this section's end would be satisfied by the next
##     section's bytes and decode as a valid name. So every row is bounded against
##     `offset + length` here, not against `bytes.size()`, and `Reader.read_utf8_u32_into()` is
##     deliberately NOT used: it cannot see a section boundary.
##   * TRAILING BYTES ARE A REFUSAL. SAVE-R09-002 requires rejecting trailing payload bytes, and
##     a section that decodes 512 valid rows and still has bytes left is not a short valid pool.
##
## THE BYTES.
##
##   | Offset | Type       | Field                               | Bytes      |
##   |-------:|------------|-------------------------------------|-----------:|
##   |      0 | u32 LE     | row_count, always `ROW_COUNT` (512)  |          4 |
##   |      4 | row x512   | one row per resident slot, in order  |   variable |
##
##   row = `utf8_byte_count:u32 LE` then exactly that many UTF-8 bytes. No NUL terminator, no
##   alignment, no padding (SAVE-R09-002). An empty name is the four bytes `00000000` and no
##   payload -- it is a PRESENT ROW WITH A ZERO-LENGTH NAME, never an absent row.
##
## SAVE-R09-002's pinned fixtures are reproduced by this encoder: empty `00000000`,
## `Oak` = `030000004f616b`, `Móle` = `050000004dc3b36c65`, and `01000000c0` / `02000000c080`
## both fail UTF-8. `test_save_section_name_pool.gd` asserts all five against this module.
##
## COLUMN-MAJOR IS SATISFIED TRIVIALLY, AND THAT IS WORTH SAYING. SAVE-LAYOUT-R01 rules that
## packed stores use column-major bytes: field schema order outer, ascending physical slot inner.
## Section 14 has exactly ONE member (`docs/persistence_state_registry.md`: "§14 NAME_POOL has
## exactly one member, `residents.gd`'s `_name_key`"), so column-major and record-major produce
## identical bytes and no choice is being made here. A later section with two variable-length
## columns MUST NOT read this file as precedent for interleaving them; it owes a full pass of
## column A over all slots before column B begins.
##
## THE EMPTY NAME IS THE COMMON CASE, NOT AN EDGE CASE. GDD REQ-SET-040 makes naming
## trigger-based and REQ-SET-041 says an anonymous resident "shall retain full persistent state
## and display species plus role and ID rather than a personal name". In the starter settlement
## exactly one of twelve residents is named. So 511 of 512 rows being `00000000` is the normal
## shape of this section, and the encoder writes every one of them: dropping empty rows would
## make the row index stop meaning the slot index.
##
## SAVE-R09-002 SAYS "A live resident cannot load an empty name", AND THAT SENTENCE CANNOT BE
## READ LITERALLY AGAINST REQ-SET-041. The reading applied here, stated so it can be corrected:
## the sentence governs a row the owning schema has FLAGGED as named. `residents.gd` carries
## `_named` beside `_name_key`, and `set_name()` derives `_named` from emptiness, so a row with
## `_named == 1` and an empty key is an inconsistent live store and is refused by
## `capture_into()`. A row with `_named == 0` holds `""` legitimately -- that is the registry's
## own declared unused value ("Empty string for an unnamed row"). See BLOCKER N2.
##
## NAME VALIDATION IS REAL, NOT IMPLIED. A nonempty name must pass all three of SAVE-R09-002's
## and ARCH-SAVE-005's rules: at most 128 encoded bytes, then 2-32 Unicode scalar values, then no
## control characters. The three are separate refusal codes because they fail for different
## reasons and a load report that said only "bad name" would be useless.
##
## PERSISTENCE OBLIGATION AND DIGEST MEMBERSHIP ARE SEPARATE AXES (decision 0063, and the
## READY_07 G3 ruling). Section 14 is BOTH: category 1 in the persistence registry, and inside
## ARCH-HASH-001, which includes "all authoritative occupied/generation and typed fields in schema
## order" and excludes selection/camera/UI/derived state by name -- `_name_key` is not among the
## exclusions, and SAVE-R09's canonical stream explicitly carries "Direct binary strings ...
## not intern IDs". BUT THE CANONICAL BYTES ARE NOT THE PAYLOAD BYTES, which is the second thing
## that does not transfer from section 10. SAVE-R09's canonical field record is
## `section_id, owner_key, field_key, type, value_count:u64, values`, so the walker supplies the
## count itself; `canonical_bytes_of()` therefore emits the 512 values WITHOUT this section's
## `row_count:u32` prefix. It is a function, not a convention, and the test asserts the two
## differ by exactly those four bytes.
##
## ALLOCATE BEFORE CONSUME (decision 0059). `decode_into()` proves the declared extent present,
## bounds every row-length prefix against the section end BEFORE reading its bytes, and lands
## everything in a local Record that is copied into `out` only after the whole record validates.
## `apply()` validates the record, validates it against the store, captures the prior names, and
## only then writes; a refusal at any point leaves every collaborating store byte-identical.
##
## COLD PATH. ARCH-SAVE-003 saves at a completed boundary, so this module allocates freely. It is
## NOT a per-tick path; ARCH-MEM-001's allocation ban applies to `residents.gd`'s columns, which
## this module only reads through the public API.
##
## NO FLOAT (ARCH-AUTH-002). The test greps this source to enforce that.
##
## OPEN, NOT INVENTED (AGENTS.md "do not invent a constant"):
##   * BLOCKER N1 -- SECTION 14 HAS NO REGISTERED OWNER-BLOCK FRAMING. SAVE-LAYOUT-R01 defines the
##     `owner_key / owner_schema_version / primary_count / payload_byte_length` store wrapper for
##     sections 3, 4 and 5 ONLY, and says in terms that "sections 6/7/8/9/14 still require
##     registered owner schemas and exact bounded framing". The wrapper is therefore NOT applied
##     here: adopting it would require an owner_key spelling and an owner_schema_version that no
##     ruling has issued, and a wrong guess at either is a silently incompatible fixture. If the
##     registry later extends the wrapper to section 14, this payload gains a prefix and the
##     section version increments. The bytes below are the single-column body, which the wrapper
##     would wrap unchanged.
##   * BLOCKER N2 -- SAVE-R09-002's "a live resident cannot load an empty name" versus GDD
##     REQ-SET-041's anonymous residents. The reading is documented above and implemented as the
##     `_named` consistency rule; it needs confirming.
##   * BLOCKER N3 -- `residents.gd::set_name()` enforces NONE of ARCH-SAVE-005's name rules: it
##     stores any StringName and derives `_named` from emptiness. A live store can therefore hold
##     a name this codec must refuse to write. `encode_store()` refuses rather than truncating,
##     which is correct here, but the validation belongs at the setter as well. `residents.gd` is
##     not this module's file to change.
##   * BLOCKER N4 -- SECTION 14 MUST BE APPLIED AFTER SECTION 4. `set_name()` rewrites `_named`,
##     so applying section 14 last is what makes the two columns agree. Nothing in ARCH-SAVE-002
##     states an intra-load apply order; it states a section ID order. The load orchestrator owns
##     this and does not exist yet.
##   * `schema_version` in the 64-byte descriptor is carried opaquely by `save_header.gd` and is
##     not set here, exactly as `save_section_rng.gd` does not set it.
##   * The section CRC-32 and body SHA-256 are `save_header.gd`'s; this module produces the
##     payload bytes those protect and computes neither.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 13 CHRONICLE, 14 NAME_POOL, 15 STATE_DIGEST".
const SECTION_ID: int = 14

## Taken from `residents.gd` rather than restated, so the two cannot drift to different capacities.
## The registry row is explicit that this is the full 512-row capacity, not the living count.
const ROW_COUNT: int = ResidentsScript.RESIDENT_CAPACITY

## The explicit row-count prefix. Present because the section length no longer implies the count.
const ROW_COUNT_BYTES: int = SaveCodec.U32_BYTES

## SAVE-R09-002: "utf8_byte_count:u32 LE followed by exactly that many UTF-8 bytes".
const LENGTH_PREFIX_BYTES: int = SaveCodec.U32_BYTES

## SAVE-R09-002: "Names/aliases allow at most 128 encoded bytes".
const NAME_MAX_UTF8_BYTES: int = 128

## ARCH-SAVE-005 / UI: "Player aliases are 2-32 Unicode characters". Counted in scalar values,
## which is what Godot's UTF-32 `String.length()` returns -- not bytes, and not grapheme clusters.
const NAME_MIN_SCALARS: int = 2
const NAME_MAX_SCALARS: int = 32

## SAVE-R09-002: "Independently enforce the 131072-byte name-pool arena limit." It is enforced
## independently even though `ROW_COUNT * NAME_MAX_UTF8_BYTES` = 65536 already bounds it at half
## that: the per-name cap and the arena cap are two separate rules and either may move.
const ARENA_MAX_BYTES: int = 131072

## Every row empty: the prefix plus 512 zero-length prefixes.
const MIN_SECTION_BYTES: int = ROW_COUNT_BYTES + ROW_COUNT * LENGTH_PREFIX_BYTES

## Every row at the 128-byte cap.
const MAX_SECTION_BYTES: int = MIN_SECTION_BYTES + ROW_COUNT * NAME_MAX_UTF8_BYTES

## Unicode general category Cc, the only defined meaning of "control character": U+0000-U+001F
## and U+007F-U+009F. Stated as bounds rather than a hand-listed set.
const CONTROL_C0_MAX: int = 0x1f
const CONTROL_DEL: int = 0x7f
const CONTROL_C1_MAX: int = 0x9f

## The registry's declared unused value for `_name_key`: "Empty string for an unnamed row".
const CANONICAL_UNUSED_NAME: String = ""

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_NAMES_NEGATIVE_OFFSET"
const REFUSE_NEGATIVE_LENGTH: StringName = &"SAVE_NAMES_NEGATIVE_LENGTH"
const REFUSE_SECTION_LENGTH: StringName = &"SAVE_NAMES_SECTION_LENGTH"
const REFUSE_EXTENT: StringName = &"SAVE_NAMES_EXTENT"
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
		"""Exact section length this record encodes to: prefix, 512 length prefixes, and names."""
		return MIN_SECTION_BYTES + arena_bytes()


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

	Refuses an INCONSISTENT live store: `_named == 1` beside an empty key. That pairing is what
	SAVE-R09-002's "a live resident cannot load an empty name" forbids, and writing it would
	produce a save whose section 4 and section 14 disagree about the same resident.
	"""
	var parsed: Record = Record.new()
	for slot: int in ROW_COUNT:
		var name_value: String = String(store.name_key_of(slot))
		if store.is_named(slot) and name_value == CANONICAL_UNUSED_NAME:
			return SaveHeader.Refusal.new(REFUSE_NAMED_ROW_EMPTY,
				"slot %d is flagged named and carries an empty name key" % slot)
		parsed.names[slot] = name_value
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Encode a Record as the section 14 payload. Validates every row before it writes a byte.

	Validation comes first so a refused encode produces no bytes at all, rather than a buffer of
	a plausible length holding an unvalidated name.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var expected: int = record.payload_bytes()
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(expected)
	writer.write_u32(ROW_COUNT)
	for slot: int in ROW_COUNT:
		writer.write_utf8_u32(record.names[slot], NAME_MAX_UTF8_BYTES)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != expected:
		return out.refuse(REFUSE_SECTION_LENGTH,
			"encoded %d bytes, not the computed %d" % [bytes.size(), expected])
	return out.succeed(bytes)


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
	"""Read the row-count prefix and 512 rows, then demand the section is consumed exactly."""
	var section_end: int = offset + length
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var declared: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(declared):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if declared.value != ROW_COUNT:
		return SaveHeader.Refusal.new(REFUSE_ROW_COUNT,
			"section 14 declares %d rows, not the compiled %d" % [declared.value, ROW_COUNT])
	for slot: int in ROW_COUNT:
		var row: SaveHeader.Refusal = _read_row_into(bytes, reader, parsed, slot, section_end)
		if not row.is_ok():
			return row
	if reader.position() != section_end:
		return SaveHeader.Refusal.new(REFUSE_TRAILING_BYTES,
			"%d bytes remain after 512 rows" % (section_end - reader.position()))
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
	"""Validate one name. The empty name is ACCEPTED: it is the anonymous row (GDD REQ-SET-041).

	Three separate codes for three separate rules, in the order SAVE-R09-002 states them: the
	128-byte encoded cap, then the owning 2-32 Unicode scalar-value rule, then no control
	characters. An anonymous row is not subjected to the 2-32 rule, which would refuse every
	unnamed resident in the settlement.
	"""
	if name_value == CANONICAL_UNUSED_NAME:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	var encoded: int = SaveCodec.utf8_byte_length(name_value)
	if encoded > NAME_MAX_UTF8_BYTES:
		return SaveHeader.Refusal.new(REFUSE_NAME_BYTES,
			"slot %d encodes to %d bytes, over the %d-byte cap"
				% [slot, encoded, NAME_MAX_UTF8_BYTES])
	var scalars: int = name_value.length()
	if scalars < NAME_MIN_SCALARS or scalars > NAME_MAX_SCALARS:
		return SaveHeader.Refusal.new(REFUSE_NAME_SCALARS,
			"slot %d holds %d Unicode scalars, outside %d..%d"
				% [slot, scalars, NAME_MIN_SCALARS, NAME_MAX_SCALARS])
	for index: int in scalars:
		if is_control_scalar(name_value.unicode_at(index)):
			return SaveHeader.Refusal.new(REFUSE_CONTROL_CHARACTER,
				"slot %d carries control scalar U+%04X at index %d"
					% [slot, name_value.unicode_at(index), index])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func is_control_scalar(code_point: int) -> bool:
	"""True for Unicode general category Cc: U+0000-U+001F, U+007F-U+009F.

	Public so the rule is testable directly. Cc is the only defined meaning of "control
	character", so the bounds are a citation rather than a chosen set.
	"""
	if code_point <= CONTROL_C0_MAX:
		return true
	return code_point >= CONTROL_DEL and code_point <= CONTROL_C1_MAX


# --- apply -------------------------------------------------------------------------------------------

static func apply(record: Record, store: ResidentsScript) -> SaveHeader.Refusal:
	"""Publish a decoded section 14 into a live store, all 512 rows or none.

	ALLOCATE BEFORE CONSUME (decision 0059). The record is validated, then checked against the
	store's occupancy, then the store's own current names are captured, and only then is the
	first `set_name()` issued. A refusal at any stage leaves every name in the store exactly as
	it was; a refusal from the store mid-write rolls the earlier writes back.

	SECTION 4 MUST BE APPLIED FIRST (blocker N4). Occupancy is read from the store here, and
	`set_name()` rewrites `_named`, so this must be the later of the two.
	"""
	var refused: SaveHeader.Refusal = apply_precondition_refusal(record, store)
	if not refused.is_ok():
		return refused
	var prior: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(store, prior)
	if not captured.is_ok():
		return captured
	for slot: int in ROW_COUNT:
		if not store.is_present(slot):
			continue
		var written: ResidentsScript.OpResult = store.set_name(slot,
			StringName(record.names[slot]))
		if written.ok:
			continue
		_roll_back(prior, store)
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"slot %d refused with %s; the store was rolled back" % [slot, written.error])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func apply_precondition_refusal(record: Record,
		store: ResidentsScript) -> SaveHeader.Refusal:
	"""Record shape plus the one store-coupled rule: an absent row cannot carry a name.

	THIS IS THE EMPTY-VERSUS-ABSENT DISTINCTION MADE ENFORCEABLE. An empty name on an absent row
	is correct and expected -- it is the canonical unused value. A NONEMPTY name on an absent row
	means section 4 and section 14 disagree about which slots hold residents, and it is refused
	rather than silently dropped, which would lose the name and report success.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	for slot: int in ROW_COUNT:
		if store.is_present(slot):
			continue
		if record.names[slot] != CANONICAL_UNUSED_NAME:
			return SaveHeader.Refusal.new(REFUSE_ABSENT_ROW_NAMED,
				"slot %d is absent in the store but the pool names it" % slot)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _roll_back(prior: Record, store: ResidentsScript) -> void:
	"""Restore a captured Record after a failed apply. Every name came out of this store."""
	for slot: int in ROW_COUNT:
		if not store.is_present(slot):
			continue
		store.set_name(slot, StringName(prior.names[slot]))


# --- ARCH-HASH-001 contribution ------------------------------------------------------------------

static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This section's ARCH-HASH-001 contribution: the 512 values, WITHOUT the row-count prefix.

	NOT the section payload, and that is the point of keeping this a function. SAVE-R09's
	canonical field record is `section_id, owner_key, field_key, type, value_count:u64, values`,
	so the walker emits the count itself; repeating it here would hash 512 twice and make the
	digest disagree with a walker that followed the grammar. Each type-5 value keeps its own u32
	UTF-8 byte length, which is exactly the row encoding above.

	`section_id`, `owner_key` and `field_key` are NOT emitted here: they are registry-owned ASCII
	keys that SAVE-R09 requires be registered by the store owner, and no registration exists. See
	blocker N1. Section 15 owns the `RWL-STATE-1` domain string, the record header and the final
	SHA-256; none of those is decided here.
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
