extends RefCounted
## ARCH-SAVE-002 section 10 RNG: the nine xorshift32 stream states and their nine int64 draw
## counts, encoded through `save_codec.gd`'s ARCH-SAVE-001 primitives.
##
## WHAT THIS SECTION'S BYTES ARE. The payload is a FIXED 108 bytes. There is no count field and
## no framing: ARCH-RNG-002 fixes the stream domain at exactly nine keys in ASCII order, so the
## length is the validation. A section of any other length is refused outright, which also makes
## a truncated read impossible to mistake for a short-but-valid one.
##
##   | Offset | Type | Field                                    | Bytes |
##   |-------:|------|------------------------------------------|------:|
##   |      0 | i32 x9 | stored xorshift32 state, stream 0..8    |    36 |
##   |     36 | i64 x9 | draw count, stream 0..8                 |    72 |
##
## Stream order is `rng.gd`'s `STREAM_KEYS`, which ARCH-RNG-002 compiles "in ASCII order":
## ECOLOGY, FISHING, FORAGE, HUNTING, IMMIGRATION, MAP, QUALITY, SOCIAL, WEATHER.
##
## THE STATE IS WRITTEN IN CROWD §6.1's SIGNED FORM, not as a u32. `rng.gd::stored_state_of()`
## returns the signed int32 a state at or above 2147483648 is stored as, and
## `rng.gd::restore_stream()` takes the UNSIGNED u32 back. So the writer emits the signed form
## and the reader converts with `from_stored_int32()` before restoring. The confusion this
## avoids is exact: `0x80000000` is a POSITIVE GDScript int and `-2147483648` as an int32, and
## reading one field with the other signedness turns a live state into a refused one -- or, far
## worse, into a different live one. `save_codec.gd`'s reader never infers signedness from a
## width for the same reason.
##
## WHY THE DRAW COUNT IS NOT OPTIONAL. ARCH-RNG-002: "Store state plus int64 draw count."
## ARCH-HASH-001 hashes "RNG states/draw counts", and ARCH-HASH-002 dumps them on a divergence so
## the report names a stream and a draw index. A stream restored at the right state but the wrong
## count reports the wrong index forever after, and a stream restored at the wrong state produces
## values that are still perfectly plausible -- the divergence is silent. That is the failure
## this section exists to prevent, so both columns are mandatory and neither is derivable.
##
## NOTHING HERE IS EXCLUDED FROM ARCH-HASH-001. `canonical_bytes_of()` returns the same 108
## bytes `encode_record()` writes, and `test_save_section_rng.gd` asserts that identity rather
## than assuming it. Section 1's WorldRuntime block is the one that differs; see
## `save_section_world_runtime.gd`.
##
## SECTION 10 CANNOT BE DECODED ALONE. `restore_stream()` requires an already seeded store,
## because SET-AMEND-001 §3's retired HUNTING slot is canonical only against the world seed and a
## noncanonical tombstone must FAIL validation. The seed lives in section 1 (persistence registry,
## `rng.gd` row "RNG seed and seeded flag"), and ARCH-SAVE-002 already orders WORLD (1) before
## RNG (10). `apply()` therefore takes a seeded store and refuses an unseeded one; it does not
## seed anything itself, because choosing a seed here would be exactly the silent re-derivation
## the registry warns about.
##
## APPLY IS TRANSACTIONAL. Every one of the nine pairs is validated before any is written, and
## the prior nine pairs are captured first, so a refusal leaves the store byte-identical. The
## store is never left half-restored with four new streams and five old ones.
##
## COLD PATH. ARCH-SAVE-003 saves at a completed boundary and loads at a load boundary, so this
## module allocates freely -- a `Record`, a `Writer`, a scratch `Record` for the rollback. It is
## explicitly NOT a per-tick path and must not be optimised as if it were; the per-tick
## allocation ban (ARCH-MEM-001) applies to `rng.gd`'s columns, which this module only reads.
##
## NO FLOAT. There is no float in this file and there must never be one (ARCH-AUTH-002);
## `test_save_section_rng.gd` greps this source to enforce that.
##
## OPEN, NOT INVENTED (AGENTS.md "do not invent a constant"):
##   * `schema_version` in the 64-byte descriptor is carried opaquely by `save_header.gd` and is
##     NOT set here. Task 09.2's card says the version policy is unresolved and that v1 bytes
##     must not be silently repurposed, so this module names no version number at all.
##   * Whether section ranges must be CONTIGUOUS is unresolved. `save_header.gd` validates only
##     that sections do not overlap and stay inside the file, and nothing here assumes a
##     neighbour, so decoding takes an explicit `offset` rather than assuming section 10 begins
##     where section 9 ended.
##   * The section CRC-32 and the body SHA-256 are `save_header.gd`'s; this module produces the
##     payload bytes those protect and computes neither.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "1 WORLD, 2 CATALOG_IDS, ... 10 RNG, ...".
const SECTION_ID: int = 10

## Taken from `rng.gd` rather than restated, so the two cannot drift to different domains.
const STREAM_COUNT: int = RngScript.STREAM_COUNT

const STATE_OFFSET: int = 0
const STATE_STRIDE: int = SaveCodec.I32_BYTES
const DRAW_COUNT_OFFSET: int = STATE_OFFSET + STREAM_COUNT * STATE_STRIDE
const DRAW_COUNT_STRIDE: int = SaveCodec.I64_BYTES
const SECTION_BYTES: int = DRAW_COUNT_OFFSET + STREAM_COUNT * DRAW_COUNT_STRIDE

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_LENGTH: StringName = &"SAVE_RNG_SECTION_LENGTH"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_RNG_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_RNG_TRUNCATED"
const REFUSE_ZERO_STATE: StringName = &"SAVE_RNG_ZERO_STATE"
const REFUSE_NEGATIVE_DRAW_COUNT: StringName = &"SAVE_RNG_NEGATIVE_DRAW_COUNT"
const REFUSE_TOMBSTONE_DRAWN: StringName = &"SAVE_RNG_TOMBSTONE_DRAWN"
const REFUSE_TOMBSTONE_STATE: StringName = &"SAVE_RNG_TOMBSTONE_STATE"
const REFUSE_STORE_UNSEEDED: StringName = &"SAVE_RNG_STORE_UNSEEDED"
const REFUSE_STORE_REFUSED: StringName = &"SAVE_RNG_STORE_REFUSED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_RNG_ENCODE_FAILED"


class Record:
	"""One decoded section 10: nine signed stored states and nine draw counts, columns allocated
	once in `_init` so no decode ever resizes them.

	`states` holds crowd §6.1's SIGNED int32 storage form -- the integer that goes on the wire --
	not the u32 `rng.gd::restore_stream()` accepts. `unsigned_state_at()` is the only conversion.
	"""
	var states: PackedInt32Array = PackedInt32Array()
	var draw_counts: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate both columns at the fixed nine-stream width and zero them."""
		states.resize(STREAM_COUNT)
		draw_counts.resize(STREAM_COUNT)

	func clear() -> void:
		"""Zero both columns in place, which is the unseeded (and never valid) shape."""
		states.fill(0)
		draw_counts.fill(0)

	func unsigned_state_at(stream_id: int) -> int:
		"""The u32 state of one stream, recovered from its signed storage form by `& 0xffffffff`."""
		return states[stream_id] & SaveCodec.UINT32_MAX

	func copy_from(other: Record) -> void:
		"""Overwrite both columns from `other` without reallocating either."""
		for stream_id: int in STREAM_COUNT:
			states[stream_id] = other.states[stream_id]
			draw_counts[stream_id] = other.draw_counts[stream_id]


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

static func capture_into(store: RngScript, out: Record) -> SaveHeader.Refusal:
	"""Read a live store's nine stored states and nine draw counts into a caller-owned Record.

	Refuses an unseeded store: every state is 0 there, which is the one value xorshift32 forbids,
	so an unseeded store has no legal section 10 to write. `out` is left untouched on refusal.
	"""
	if not store.is_seeded():
		return SaveHeader.Refusal.new(REFUSE_STORE_UNSEEDED,
			"an unseeded store holds nine zero states, which xorshift32 forbids")
	var parsed: Record = Record.new()
	for stream_id: int in STREAM_COUNT:
		var state: IntMathScript.IntResult = store.stored_state_of(stream_id)
		var count: IntMathScript.IntResult = store.draw_count_of(stream_id)
		if not state.ok or not count.ok:
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"stream %d: %s%s" % [stream_id, state.error, count.error])
		parsed.states[stream_id] = state.value
		parsed.draw_counts[stream_id] = count.value
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Encode a Record as the fixed 108-byte section 10 payload. Validates before it writes.

	The record is validated first so a refused encode produces no bytes at all rather than a
	buffer that is the right length and the wrong content.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(SECTION_BYTES)
	for stream_id: int in STREAM_COUNT:
		writer.write_i32(record.states[stream_id])
	for stream_id: int in STREAM_COUNT:
		writer.write_i64(record.draw_counts[stream_id])
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != SECTION_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"encoded %d bytes, not the fixed %d" % [bytes.size(), SECTION_BYTES])
	return out.succeed(bytes)


static func encode_store(store: RngScript, out: EncodeResult) -> bool:
	"""Capture a live store and encode it in one call, for a caller that keeps no Record."""
	var record: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(store, record)
	if not captured.is_ok():
		return out.refuse(captured.code, captured.detail)
	return encode_record(record, out)


# --- decode ----------------------------------------------------------------------------------------

static func decode_into(bytes: PackedByteArray, offset: int, out: Record) -> SaveHeader.Refusal:
	"""Decode section 10 from `offset`, validating the whole extent before writing anything.

	Allocate before consume (decision 0059): the 108-byte extent is proved present BEFORE any
	value is read, and the decoded values land in a local Record that is copied into `out` only
	once every field has passed validation. A truncated or invalid section therefore leaves the
	caller's Record byte-identical.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var parsed: Record = Record.new()
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if not _read_columns(reader, parsed):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove `SECTION_BYTES` are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own: `save_codec.gd`'s
	Reader is bounded too, so a slack extent check would still end in a refusal and hide.
	A load orchestrator can also ask this before committing to a section.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < SECTION_BYTES or offset > bytes.size() - SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 10 needs %d bytes at offset %d, buffer holds %d"
				% [SECTION_BYTES, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_columns(reader: SaveCodec.Reader, parsed: Record) -> bool:
	"""Read the nine i32 states then the nine i64 draw counts into `parsed`. Sticky on refusal."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for stream_id: int in STREAM_COUNT:
		if not reader.read_i32_into(scalar):
			return false
		parsed.states[stream_id] = scalar.value
	for stream_id: int in STREAM_COUNT:
		if not reader.read_i64_into(scalar):
			return false
		parsed.draw_counts[stream_id] = scalar.value
	return true


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every seed-independent rule section 10 can check without a world seed.

	Zero state is the whole point: `clear()` fills the columns with 0, which is exactly the value
	xorshift32 forbids, so 0 can never be a live state and is never accepted as one. The
	tombstone's seed-DEPENDENT half is checked in `apply()`, where a seed exists.
	"""
	if record.states.size() != STREAM_COUNT or record.draw_counts.size() != STREAM_COUNT:
		return SaveHeader.Refusal.new(REFUSE_LENGTH, "a section 10 record holds %d states and %d counts, not %d each"
			% [record.states.size(), record.draw_counts.size(), STREAM_COUNT])
	for stream_id: int in STREAM_COUNT:
		if record.unsigned_state_at(stream_id) == 0:
			return SaveHeader.Refusal.new(REFUSE_ZERO_STATE,
				"stream %d (%s) holds the forbidden zero state"
					% [stream_id, RngScript.stream_key_of(stream_id)])
		if record.draw_counts[stream_id] < 0:
			return SaveHeader.Refusal.new(REFUSE_NEGATIVE_DRAW_COUNT,
				"stream %d (%s) declares %d draws"
					% [stream_id, RngScript.stream_key_of(stream_id),
						record.draw_counts[stream_id]])
	if record.draw_counts[RngScript.STREAM_HUNTING] != 0:
		return SaveHeader.Refusal.new(REFUSE_TOMBSTONE_DRAWN,
			"SET-AMEND-001 §3 keeps HUNTING at zero draws, not %d"
				% record.draw_counts[RngScript.STREAM_HUNTING])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func tombstone_refusal(record: Record, world_seed: int) -> SaveHeader.Refusal:
	"""The seed-dependent half: HUNTING must still hold the state its original seed rule gives."""
	var canonical: IntMathScript.IntResult = RngScript.seeded_state_for(world_seed,
		RngScript.STREAM_HUNTING)
	if not canonical.ok:
		return SaveHeader.Refusal.new(REFUSE_TOMBSTONE_STATE,
			"no canonical HUNTING state for seed %d: %s" % [world_seed, canonical.error])
	var stored: int = record.unsigned_state_at(RngScript.STREAM_HUNTING)
	if stored != canonical.value:
		return SaveHeader.Refusal.new(REFUSE_TOMBSTONE_STATE,
			"HUNTING holds %d, not the canonical %d for seed %d"
				% [stored, canonical.value, world_seed])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- apply -------------------------------------------------------------------------------------------

static func apply(record: Record, store: RngScript) -> SaveHeader.Refusal:
	"""Publish a decoded section 10 into an already seeded store, all nine streams or none.

	The store must already carry section 1's world seed: `restore_stream()` validates the retired
	HUNTING slot against it, and re-deriving a seed here would restart every stream at draw 0 with
	values that still look plausible.

	THE SEED-DEPENDENT TOMBSTONE RULE IS DELIBERATELY NOT RE-CHECKED HERE. `rng.gd` owns it and
	`restore_stream()` enforces it, so duplicating it in a precondition would put the same rule in
	two files that can drift -- and would make the rollback below unreachable, which is how an
	untested recovery path gets shipped. `tombstone_refusal()` stays public for a caller that
	wants to validate a record BEFORE it owns a store; `apply()` lets the owner decide and rolls
	back instead. Prior state is captured first, so a refusal at any of the nine leaves the store
	byte-identical rather than half-restored.
	"""
	var refused: SaveHeader.Refusal = _apply_precondition_refusal(record, store)
	if not refused.is_ok():
		return refused
	var prior: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(store, prior)
	if not captured.is_ok():
		return captured
	for stream_id: int in STREAM_COUNT:
		var written: RngScript.OpResult = store.restore_stream(stream_id,
			record.unsigned_state_at(stream_id), record.draw_counts[stream_id])
		if written.ok:
			continue
		_roll_back(prior, store)
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"stream %d refused with %s; the store was rolled back" % [stream_id, written.error])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _apply_precondition_refusal(record: Record, store: RngScript) -> SaveHeader.Refusal:
	"""Check only what `rng.gd` cannot: the record's own shape, and that a seed exists at all.

	Stops short of the seed-DEPENDENT tombstone rule on purpose; see `apply()`'s docstring.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	if not store.is_seeded():
		return SaveHeader.Refusal.new(REFUSE_STORE_UNSEEDED,
			"section 10 needs section 1's world seed applied first")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _roll_back(prior: Record, store: RngScript) -> void:
	"""Restore a captured Record after a failed apply. Every pair came out of this store."""
	for stream_id: int in STREAM_COUNT:
		store.restore_stream(stream_id, prior.unsigned_state_at(stream_id),
			prior.draw_counts[stream_id])


# --- ARCH-HASH-001 contribution ------------------------------------------------------------------

static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This section's contribution to ARCH-HASH-001, which is its whole payload.

	ARCH-HASH-001 hashes "RNG states/draw counts" and its exclusion list names nothing in section
	10, so the canonical contribution is byte-for-byte the section payload. This function exists
	so that identity is stated and tested rather than assumed, and so section 10 and section 1's
	WorldRuntime block -- which DOES exclude fields -- present the same interface to whatever
	assembles the digest.

	Section 15 STATE_DIGEST owns the `RWL-STATE-1` domain string, the order the contributions are
	concatenated in and the final SHA-256. None of those is decided here.
	"""
	return encode_record(record, out)
