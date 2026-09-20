extends RefCounted
## ARCH-SAVE-002 section 11 EVENT_SCHEDULE: the byte adapter for the store `event_schedule.gd`
## already owns, implementing SAVE-R09-005's frozen wire form and nothing else.
##
## SAVE-S11-R01 version 2 (`docs/planning/event_schedule_codec_contract.md`) is the contract this
## file transcribes. It closes the missing section 11 codec and NOT event gameplay: no event kind,
## no semantic argument domain, no production rule, no expiry and no consumer is introduced here.
## Real event activation remains PLAN-COMMUNITY-EVENTS scope. The four i32 columns are STORAGE
## DOMAINS ONLY -- every signed int32 value is permitted -- exactly as `event_schedule.gd` says.
##
## ---------------------------------------------------------------------------------------
## THE BYTES, TRANSCRIBED FROM SAVE-R09-005 AND NOT CHOSEN HERE.
##
##   payload = next_sequence:i64, then N records of 32 bytes each, in exact field order
##   kind:i32, source_id:i32, arg0:i32, arg1:i32, due_tick:i64, sequence:i64.
##   Little-endian throughout. Length is `8 + 32*N`: the EMPTY section is 8 bytes, never zero,
##   and the full 64-row section is 2056.
##
## NO OWNER WRAPPER AND NO INLINE COUNT. N is carried by the 64-byte descriptor's `row_count` and
## by the canonical registry, and this distinct wire form does not duplicate it. `_count` stays a
## canonical registry field emitted by the logical-state hash walker; that is the registry's
## business, not this codec's. No generic column framing is applied.
##
## WHAT REMAINS WITH ITS EXISTING OWNER. The outer CRC-32 and the body SHA-256 are
## `save_header.gd`'s. Section placement inside the file is the coordinator's. Canonical
## logical-state hashing is section 15's. Sorting, expiry and repair belong to nobody: rows are
## carried through capture, encode, decode and apply exactly as they are, including OVERDUE rows
## retained for a consumer that has not popped them yet.
##
## ---------------------------------------------------------------------------------------
## VALIDATION IS THE OWNER'S, RUN ON A TEMPORARY OWNER. `record_refusal()` checks null and shape
## itself -- those must precede any allocation -- and then delegates every remaining rule to ONE
## temporary `EventSchedule` through `restore_rows()`, converting its `last_refusal()` into a
## `SaveHeader.Refusal`. That is deliberate: a second transcription of the allocator relation, the
## strict `(due_tick, sequence)` order and the pairwise uniqueness scan is a second place for them
## to drift. Record validation NEVER invokes a method on the real owner, and the temporary store
## carries 2048 bytes of packed columns and no external authority of any kind.
##
## APPLY ALLOCATES NO VALIDATION OWNER. After the null and barrier gates it calls the real owner's
## `restore_rows()` directly, because that owner already validates its ENTIRE input before it
## clears or writes a single column, and installs the exact count and allocator with a zero unused
## tail. Pre-validating into a throwaway store first would only add a second, divergent judge.
##
## THE BARRIER IS CHECKED, NEVER TOUCHED. `apply()` refuses unless `clock.is_load_barrier_held()`,
## and it never acquires or releases that barrier and never alters any other clock state.
## `sim_clock.gd`'s predicate is a pure read (`_load_barrier != null and _load_barrier.is_held()`).
## Clock identity, world association and completed-boundary coordination are CALLER obligations;
## nothing here can check that the clock handed in belongs to the store handed in.
##
## READ DIAGNOSTICS ARE ALLOWED, EXACTLY AS SPECIFIED. `capture_into()` uses the owner's existing
## `read_into()`, which clears `last_refusal()` on a successful read and sets
## EVENT_ROW_OUT_OF_RANGE on a refused one. That existing diagnostic effect is explicitly
## permitted. An EMPTY capture performs no read at all and therefore preserves whatever diagnostic
## the owner already held. No canonical field, allocator, math scratch, row or scheduling
## operation is changed by a capture, and no private owner state is reached by reflection.
##
## COLD PATH, AND THE ACCOUNTING IS TRANSIENT. A live Record's packed payload is `32*N <= 2048`
## bytes; during a load one staging Record, the caller's target Record and one validation owner may
## coexist, plus the 2056-byte encoded buffer and whatever buffers the caller retains. This is a
## transient note, NOT an architecture live-owner ledger row, and it qualifies no RSS figure.
## Saving and loading happen at boundaries (ARCH-SAVE-003), so this module allocates freely and
## must not be read as a per-tick path.
##
## NO FLOAT, no reflection, no callback and no await on any path in this file.

const EventSchedule := preload("res://scripts/core/event_schedule.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

# --- ARCH-SAVE-002 identity and SAVE-R09-005's frozen layout ---------------------------------------

## ARCH-SAVE-002's section order places EVENT_SCHEDULE at 11; `event_schedule.gd` declares the same.
const SECTION_ID: int = EventSchedule.SECTION_ID

## Schema 1 NAMES the already-ruled bytes; it does not choose them. BLOCKER H1's version policy is
## still task 09.2's, so nothing here interprets any other value -- it is simply refused.
const SECTION_SCHEMA_VERSION: int = 1

## Taken from the owner rather than restated, so the two cannot drift to different capacities.
const MAX_ROWS: int = EventSchedule.CAPACITY
const RECORD_BYTES: int = EventSchedule.RECORD_BYTES
const ALLOCATOR_BYTES: int = SaveCodec.I64_BYTES

## `8 + 32*N` at both ends of the range, for callers sizing a buffer or asserting a golden length.
const EMPTY_SECTION_BYTES: int = ALLOCATOR_BYTES
const MAX_SECTION_BYTES: int = ALLOCATOR_BYTES + RECORD_BYTES * MAX_ROWS

# --- refusal codes ----------------------------------------------------------------------------------
#
# These ten are NEW and belong to this codec. Every owner-level judgement instead FORWARDS
# `event_schedule.gd`'s own EVENT_RESTORE_* / EVENT_TICK_NEGATIVE / EVENT_ROW_OUT_OF_RANGE codes
# verbatim, so a diagnostic never loses which rule was broken by being renamed at the wire layer.
#
# SAVE_EVENT_ROW_COUNT is the DESCRIPTOR count refusal and nothing else. A Record or a live store
# carrying more than 64 rows forwards EVENT_RESTORE_COUNT, because that is the owner's rule.

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_RECORD_NULL: StringName = &"SAVE_EVENT_RECORD_NULL"
const REFUSE_NULL_STORE: StringName = &"SAVE_EVENT_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_EVENT_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_EVENT_BARRIER_NOT_HELD"
const REFUSE_SECTION_SCHEMA: StringName = &"SAVE_EVENT_SECTION_SCHEMA"
const REFUSE_ROW_COUNT: StringName = &"SAVE_EVENT_ROW_COUNT"
const REFUSE_LENGTH: StringName = &"SAVE_EVENT_LENGTH"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_EVENT_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_EVENT_TRUNCATED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_EVENT_ENCODE_FAILED"


class Record:
	"""One decoded section 11: the allocator cursor and six equal-length row columns.

	THERE IS NO REDUNDANT COUNT SCALAR. `kind.size()` is the count, so a Record cannot disagree
	with itself about how many rows it holds. All six columns must be the same length, 0..64;
	`record_refusal()` proves that rather than assuming it.

	The columns start EMPTY and carry no pre-required length, because a successful decode replaces
	all six outright. That is the opposite of section 10's fixed nine-stream shape and is correct
	here: section 11's row count is variable.

	INT32 TYPING IS THE STORAGE WIDTH, NOT A RANGE DETECTOR. `PackedInt32Array` narrows on
	assignment, so a caller writing 0x80000000 has ALREADY stored INT32_MIN before any validation
	runs. Signed extrema are therefore valid values to be tested, and no code here can claim to
	detect the original out-of-range assignment.
	"""
	var next_sequence: int = EventSchedule.INITIAL_SEQUENCE
	var kind: PackedInt32Array = PackedInt32Array()
	var source_id: PackedInt32Array = PackedInt32Array()
	var arg0: PackedInt32Array = PackedInt32Array()
	var arg1: PackedInt32Array = PackedInt32Array()
	var due_tick: PackedInt64Array = PackedInt64Array()
	var sequence: PackedInt64Array = PackedInt64Array()

	func row_count() -> int:
		"""Rows this Record declares, which is simply the length of its first column."""
		return kind.size()

	func clear() -> void:
		"""Return to the initial state: no rows, allocator at 1. Not a wire operation."""
		next_sequence = EventSchedule.INITIAL_SEQUENCE
		kind = PackedInt32Array()
		source_id = PackedInt32Array()
		arg0 = PackedInt32Array()
		arg1 = PackedInt32Array()
		due_tick = PackedInt64Array()
		sequence = PackedInt64Array()

	func copy_from(other: Record) -> void:
		"""Overwrite every field from `other`, DUPLICATING each of the six buffers.

		The duplication provides independent buffers. A
		Record that shared a buffer with the staging Record it came from would change under its
		owner the moment that staging Record was reused, and an ALIASED input -- one Record whose
		`arg0` and `arg1` are the same array -- must still publish as independent columns.

		A low-level helper for already-valid input: it validates nothing and is never a public
		path for untrusted data.
		"""
		next_sequence = other.next_sequence
		kind = other.kind.duplicate()
		source_id = other.source_id.duplicate()
		arg0 = other.arg0.duplicate()
		arg1 = other.arg1.duplicate()
		due_tick = other.due_tick.duplicate()
		sequence = other.sequence.duplicate()


class EncodeResult:
	"""Outcome of encoding one section: the payload bytes, or a refusal and no bytes.

	The same shape `save_section_rng.gd` and `save_section_job_indexes.gd` use -- a StringName
	refusal code and a String detail -- so a caller draining several sections reads one convention
	rather than three.
	"""
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
		"""Record a refusal, clearing `ok` and emptying the payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- length -------------------------------------------------------------------------------------

static func section_bytes_for(row_count: int) -> int:
	"""SAVE-R09-005's `8 + 32*N`. Callers pass an ALREADY range-checked count; 64 rows give 2056."""
	return ALLOCATOR_BYTES + RECORD_BYTES * row_count


# --- record validation ----------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Judge one Record against every rule SAVE-R09-005 states, in the ruled order.

	Order: null; count above 64; ragged columns; a negative allocator; then the owner's own row
	scan in index order (nonnegative due tick, positive sequence, the upper allocator relation),
	the strict `(due_tick, sequence)` pair order, and uniqueness across UNEQUAL due ticks.

	The first four are checked here because they must run BEFORE anything is allocated. Everything
	after them is delegated to one temporary `EventSchedule` via `restore_rows()`, whose refusal
	is converted into this vocabulary -- so the allocator relation, the ordering rule and the
	pairwise uniqueness scan have exactly one implementation in the repository. That scan matters
	and is not implied by ordering: two rows sharing a sequence at DIFFERENT due ticks sort
	perfectly well and are still the same event twice.

	No method is ever called on a real owner from here, and nothing outside the temporary store is
	touched on any path.
	"""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no section 11 record was supplied")
	var rows: int = record.kind.size()
	if rows > MAX_ROWS:
		return SaveHeader.Refusal.new(EventSchedule.REFUSE_RESTORE_COUNT,
			"a section 11 record holds %d rows, more than the %d the owner declares"
				% [rows, MAX_ROWS])
	if record.source_id.size() != rows or record.arg0.size() != rows \
			or record.arg1.size() != rows or record.due_tick.size() != rows \
			or record.sequence.size() != rows:
		return SaveHeader.Refusal.new(EventSchedule.REFUSE_RESTORE_RAGGED,
			"columns are ragged: kind %d, source_id %d, arg0 %d, arg1 %d, due_tick %d, sequence %d"
				% [rows, record.source_id.size(), record.arg0.size(), record.arg1.size(),
					record.due_tick.size(), record.sequence.size()])
	if record.next_sequence < EventSchedule.SEQUENCE_EXHAUSTED:
		return SaveHeader.Refusal.new(EventSchedule.REFUSE_RESTORE_ALLOCATOR,
			"allocator %d is negative" % record.next_sequence)
	return _owner_validation_refusal(record)


static func _owner_validation_refusal(record: Record) -> SaveHeader.Refusal:
	"""Run the owner's whole restore gate on a TEMPORARY store and convert its refusal.

	The temporary carries 2048 bytes of packed columns and no clock, no catalog and no external
	authority; it is discarded immediately. `restore_rows()` validates its entire input before it
	writes anything, so this judges the record without half-installing it anywhere.
	"""
	var judge: EventSchedule = EventSchedule.new()
	if judge.restore_rows(record.next_sequence, record.kind, record.source_id, record.arg0,
			record.arg1, record.due_tick, record.sequence):
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	var code: StringName = judge.last_refusal()
	return SaveHeader.Refusal.new(code,
		"the section 11 owner refused this record with %s" % String(code))


static func descriptor_row_count_into(record: Record, out: IntMath.IntResult) -> bool:
	"""The descriptor's `row_count` for this Record: N, and never the 64-row capacity.

	Validated through `record_refusal()` first, so a descriptor can never declare a count for a
	record the codec would refuse to encode. A failure writes the refusal CODE into the result's
	error, because `IntMath.IntResult` carries a String reason rather than a StringName. There is
	no sentinel count: `.ok` must be inspected, exactly as every `int_math.gd` result requires.

	`out` must be a nonnull caller-supplied IntResult; this allocates none.
	"""
	var refusal: SaveHeader.Refusal = record_refusal(record)
	if not refusal.is_ok():
		return out.refuse(String(refusal.code))
	return out.succeed(record.kind.size())


# --- capture -------------------------------------------------------------------------------------

static func capture_into(store: EventSchedule, out: Record) -> SaveHeader.Refusal:
	"""Stage a live schedule into a caller-owned Record, publishing independent buffers.

	Order: null store; null out; count range; stage the allocator and every row through the
	owner's existing `count()`, `next_sequence()` and `read_into()`; validate the staged record;
	only then publish.

	NOTHING AUTHORITATIVE IS TOUCHED. No canonical field, allocator, owner math scratch, row or
	scheduling operation changes. The ONE owner-visible effect is the documented diagnostic one:
	`read_into()` clears `last_refusal()` on each successful read, and a refused getter sets
	EVENT_ROW_OUT_OF_RANGE and leaves it set. An EMPTY capture reads nothing and so preserves the
	owner's existing diagnostic untouched.

	A refused capture publishes NOTHING: the caller's Record is left byte-identical, including a
	partially staged read that failed halfway.
	"""
	if store == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_STORE, "no section 11 store was supplied")
	if out == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no section 11 output record was supplied")
	var rows: int = store.count()
	if rows < 0 or rows > MAX_ROWS:
		return SaveHeader.Refusal.new(EventSchedule.REFUSE_RESTORE_COUNT,
			"the store reports %d rows, outside 0..%d" % [rows, MAX_ROWS])
	var staged: Record = Record.new()
	var refusal: SaveHeader.Refusal = _stage_rows(store, rows, staged)
	if not refusal.is_ok():
		return refusal
	var invalid: SaveHeader.Refusal = record_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _stage_rows(store: EventSchedule, rows: int, staged: Record) -> SaveHeader.Refusal:
	"""Read the allocator and `rows` rows out of the owner into a staging Record.

	The columns are sized once, up front, and then written by index; a refused getter stops the
	staging immediately and nothing is published. The allocator is read BEFORE any row, so a
	refused row cannot leave a record carrying rows from one read and a cursor from another.
	"""
	staged.next_sequence = store.next_sequence()
	staged.kind.resize(rows)
	staged.source_id.resize(rows)
	staged.arg0.resize(rows)
	staged.arg1.resize(rows)
	staged.due_tick.resize(rows)
	staged.sequence.resize(rows)
	var row: EventSchedule.Event = EventSchedule.Event.new()
	for index: int in range(rows):
		if not store.read_into(index, row):
			return SaveHeader.Refusal.new(EventSchedule.REFUSE_ROW_OUT_OF_RANGE,
				"the store refused row %d of the %d it reports" % [index, rows])
		staged.kind[index] = row.kind
		staged.source_id[index] = row.source_id
		staged.arg0[index] = row.arg0
		staged.arg1[index] = row.arg1
		staged.due_tick[index] = row.due_tick
		staged.sequence[index] = row.sequence
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------------------

static func encode_section(record: Record, out: EncodeResult) -> bool:
	"""Encode one Record as SAVE-R09-005's `8 + 32*N` payload, validating before writing a byte.

	The allocator goes first as an i64, then each row's six fields in the frozen order
	`kind, source_id, arg0, arg1, due_tick, sequence`. The encoded length is re-checked against
	`8 + 32*N` afterwards, so a silent framing change fails here rather than at a reader.

	A refused encode clears `ok`, empties `bytes` and supplies a code and detail; it never emits a
	buffer of the right length and the wrong content.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var rows: int = record.kind.size()
	var expected: int = section_bytes_for(rows)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(expected)
	writer.write_i64(record.next_sequence)
	for index: int in range(rows):
		writer.write_i32(record.kind[index])
		writer.write_i32(record.source_id[index])
		writer.write_i32(record.arg0[index])
		writer.write_i32(record.arg1[index])
		writer.write_i64(record.due_tick[index])
		writer.write_i64(record.sequence[index])
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [String(writer.refusal()), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != expected:
		return out.refuse(REFUSE_LENGTH,
			"encoded %d bytes for %d rows, not the required %d" % [bytes.size(), rows, expected])
	return out.succeed(bytes)


# --- decode ----------------------------------------------------------------------------------------

static func decode_section_into(bytes: PackedByteArray, offset: int, length: int, row_count: int,
		schema_version: int, out: Record) -> SaveHeader.Refusal:
	"""Decode a bounded section 11 subsection, publishing only a fully validated Record.

	Section-level order, which runs BEFORE any primitive's own bound check: unsupported schema;
	`row_count` outside 0..64; a length that is not `8 + 32*N`; a negative offset; an offset past
	the buffer or a length past the remainder; a null output; then the parse, the record
	validation and finally the publication. A wrong length therefore WINS over a negative offset
	when both are wrong, because the section's own framing is judged first.

	SUBTRACTION BOUNDS COME BEFORE OFFSET ADDITION: `offset > bytes.size()` is proved first, and
	only then is `length > bytes.size() - offset` evaluated, so no `offset + length` is ever
	formed and no claimed length can overflow into looking small.

	A LENGTH CLAIM CANNOT ALLOCATE ANYTHING UNBOUNDED. `row_count` is bounded to 64 before a
	single column is sized, and the length must agree with it exactly.

	Bytes outside `[offset, offset+length)` are IGNORED, so a nonzero outer offset with a prefix
	and a suffix decodes exactly as the same payload alone does. Nothing truncates, zero-pads,
	sorts or repairs: a short or malformed section is refused, and the caller's Record and the
	input buffer are both left untouched.
	"""
	if schema_version != SECTION_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_SECTION_SCHEMA,
			"section 11 schema %d is not the supported %d" % [schema_version, SECTION_SCHEMA_VERSION])
	if row_count < 0 or row_count > MAX_ROWS:
		return SaveHeader.Refusal.new(REFUSE_ROW_COUNT,
			"descriptor row count %d is outside 0..%d" % [row_count, MAX_ROWS])
	var expected: int = section_bytes_for(row_count)
	if length != expected:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 11 declares %d bytes for %d rows, not the required %d"
				% [length, row_count, expected])
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if offset > bytes.size():
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"offset %d is past the %d-byte buffer" % [offset, bytes.size()])
	if length > bytes.size() - offset:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 11 needs %d bytes at offset %d, only %d remain"
				% [length, offset, bytes.size() - offset])
	if out == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no section 11 output record was supplied")
	var parsed: Record = Record.new()
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if not _read_payload(reader, row_count, parsed):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_payload(reader: SaveCodec.Reader, rows: int, parsed: Record) -> bool:
	"""Read the i64 allocator then `rows` 32-byte records in the frozen field order.

	The reader's refusal is sticky, so one truncated field stops the whole parse and the partially
	filled local Record is discarded by the caller rather than published.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_i64_into(scalar):
		return false
	parsed.next_sequence = scalar.value
	parsed.kind.resize(rows)
	parsed.source_id.resize(rows)
	parsed.arg0.resize(rows)
	parsed.arg1.resize(rows)
	parsed.due_tick.resize(rows)
	parsed.sequence.resize(rows)
	for index: int in range(rows):
		if not reader.read_i32_into(scalar):
			return false
		parsed.kind[index] = scalar.value
		if not reader.read_i32_into(scalar):
			return false
		parsed.source_id[index] = scalar.value
		if not reader.read_i32_into(scalar):
			return false
		parsed.arg0[index] = scalar.value
		if not reader.read_i32_into(scalar):
			return false
		parsed.arg1[index] = scalar.value
		if not reader.read_i64_into(scalar):
			return false
		parsed.due_tick[index] = scalar.value
		if not reader.read_i64_into(scalar):
			return false
		parsed.sequence[index] = scalar.value
	return true


# --- apply -------------------------------------------------------------------------------------------

static func apply(record: Record, store: EventSchedule,
		clock: SimClock = null) -> SaveHeader.Refusal:
	"""Install a decoded section 11 into the real owner under a HELD load barrier.

	Order: null record; null store; null clock; a barrier that is not held; then the owner's
	`restore_rows()` with all six columns and the allocator cursor.

	NO VALIDATION OWNER IS ALLOCATED HERE. `restore_rows()` already validates its ENTIRE input --
	count, raggedness, ticks, sequence range, the allocator relation, the strict pair order and
	uniqueness -- before it clears or writes a single column, and it installs the exact count and
	allocator with a zero unused tail. So a refusal leaves the live store byte-identical and its
	refusal code is forwarded unchanged; a second judge here could only drift from it.

	THE BARRIER IS READ, NEVER MOVED. `is_load_barrier_held()` is a pure predicate; this function
	never acquires or releases the barrier and alters no other clock state. Whether the clock
	belongs to this store's world, and whether the completed boundary has been coordinated, are
	CALLER obligations that nothing here can verify.
	"""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no section 11 record was supplied")
	if store == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_STORE, "no section 11 store was supplied")
	if clock == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_CLOCK,
			"section 11 apply needs the clock whose load barrier is held")
	if not clock.is_load_barrier_held():
		return SaveHeader.Refusal.new(REFUSE_BARRIER_NOT_HELD,
			"the load barrier is not held; section 11 may not write a live schedule")
	if store.restore_rows(record.next_sequence, record.kind, record.source_id, record.arg0,
			record.arg1, record.due_tick, record.sequence):
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	var code: StringName = store.last_refusal()
	return SaveHeader.Refusal.new(code,
		"the section 11 owner refused this restore with %s; the store is unchanged" % String(code))
