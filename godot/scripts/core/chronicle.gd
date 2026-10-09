extends RefCounted
## The Chronicle owner (ARCH-SAVE-002 section 13): the record COUNT and the 32-byte ROLLING DIGEST
## of the settlement's append-only history, and nothing else.
##
## WHAT THIS OWNER HOLDS. Exactly the two canonical fields REG-R01 declares for owner `chronicle`
## (`docs/planning/canonical_state_registry.json`, section 13, owner schema 1):
##
##   | Ordinal | Field             | Type | Count |
##   |--------:|-------------------|------|------:|
##   |       0 | `_count`          | u64  |     1 |
##   |       1 | `_rolling_digest` | u8   |    32 |
##
## ARCH-HASH-001: "the Chronicle count plus rolling digest" enter the state hash, "never its whole
## historical stream" (SAVE-R09, section 13).
##
## WHAT THIS OWNER NEVER HOLDS: THE HISTORY. SAVE-R09 section 13 says "Never load all history" and
## ARCH-MEM-004 gives ChronicleRecord no finite cap. The records live on disk -- in the section 13
## body and, once task 08.5 authors events, in ARCH-MEM-004's append-only stream with its two
## 64-record RAM pages. Neither the stream nor the pages are this owner's; `append()` hands the exact
## 24 encoded bytes back to its caller, which is the stream owner's obligation to persist. There is
## no packed member here larger than the 32-byte digest, and there must never be one.
##
## THE RECORD, transcribed from SAVE-R09 section 13 and not chosen here. 24 bytes, little-endian:
##
##   | Offset | Type | Field       |
##   |-------:|------|-------------|
##   |      0 | i32  | resident_id |
##   |      4 | i32  | event       |
##   |      8 | i64  | tick        |
##   |     16 | i32  | other_id    |
##   |     20 | i32  | detail_key  |
##
## THE DIGEST RULE, transcribed exactly: `digest' = SHA256(previous_digest || exact_record_bytes)`,
## starting from 32 zero bytes. `digest_step_into()` is that rule and nothing more; the section 13
## decoder streams the saved records through the same function, so a save and a live append cannot
## disagree about what the digest of a given history is.
##
## THE EVENT DOMAIN IS EMPTY IN THIS RELEASE -- DEC-055 Q8 (ADR 1222): "It ships with an empty
## event list. Saves stay development-only until events are authored." SAVE-R09 section 13 assigns
## the event and `ChronicleDetail` inventories to task 08.5 and the catalog owner and forbids an
## invented list, so `EVENT_KIND_COUNT` and `DETAIL_KEY_COUNT` are both 0 and EVERY `append()`
## refuses with CHRONICLE_EVENT_DOMAIN. The append path is complete -- validate, encode, digest,
## commit -- so authoring the domain is the only change it needs. There is no test hook and no
## runtime override of the domain: a domain is compiled, or it does not exist. SAVE-R09 also says
## "Do not call an empty Chronicle stub release-complete", and nothing here claims that.
##
## RESTORE IS VALIDATE-THEN-WRITE. `restore_state()` checks every rule before it touches either
## field, so a refused restore leaves the owner byte-identical.
##
## NO FLOAT anywhere in this file (ARCH-AUTH-002). Appends are rare, cold events -- never a per-tick
## loop -- so the per-call HashingContext and 24-byte scratch are acceptable allocations.

const SaveCodec := preload("res://scripts/core/save_codec.gd")

# --- identity ------------------------------------------------------------------------------------

## ARCH-SAVE-002: "13 CHRONICLE".
const SECTION_ID: int = 13
const OWNER_KEY: String = "chronicle"
const OWNER_SCHEMA_VERSION: int = 1

## REG-R01's declared order. The canonical walker reads the compiled table, not this list; the
## test suite proves the two agree.
const FIELD_KEYS: Array[String] = ["_count", "_rolling_digest"]
const ORDINAL_COUNT: int = 0
const ORDINAL_ROLLING_DIGEST: int = 1

# --- record layout (SAVE-R09 section 13) ---------------------------------------------------------

const RECORD_BYTES: int = 24
const OFFSET_RESIDENT_ID: int = 0
const OFFSET_EVENT: int = 4
const OFFSET_TICK: int = 8
const OFFSET_OTHER_ID: int = 16
const OFFSET_DETAIL_KEY: int = 20

## SHA-256 output width, and the width of the all-zero starting digest.
const DIGEST_BYTES: int = 32

## The count is a u64 on the wire; a GDScript int holds its non-negative half.
const COUNT_MAX: int = SaveCodec.INT64_MAX

# --- compiled domains (DEC-055 Q8: empty in this release) ---------------------------------------

## Valid event kinds are `0 .. EVENT_KIND_COUNT - 1`. Zero kinds: no record is admissible.
const EVENT_KIND_COUNT: int = 0
## Valid `ChronicleDetail` IDs are `0 .. DETAIL_KEY_COUNT - 1`. Zero IDs: none is admissible.
const DETAIL_KEY_COUNT: int = 0

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_FIELD_NOT_INT32: StringName = &"CHRONICLE_FIELD_NOT_INT32"
const REFUSE_NEGATIVE_TICK: StringName = &"CHRONICLE_NEGATIVE_TICK"
const REFUSE_EVENT_DOMAIN: StringName = &"CHRONICLE_EVENT_DOMAIN"
const REFUSE_DETAIL_DOMAIN: StringName = &"CHRONICLE_DETAIL_DOMAIN"
const REFUSE_COUNT_EXHAUSTED: StringName = &"CHRONICLE_COUNT_EXHAUSTED"
const REFUSE_DIGEST_INPUT: StringName = &"CHRONICLE_DIGEST_INPUT"
const REFUSE_DIGEST_FAILED: StringName = &"CHRONICLE_DIGEST_FAILED"
const REFUSE_ENCODE_FAILED: StringName = &"CHRONICLE_ENCODE_FAILED"
const REFUSE_RESTORE_COUNT: StringName = &"CHRONICLE_RESTORE_COUNT"
const REFUSE_RESTORE_DIGEST_LENGTH: StringName = &"CHRONICLE_RESTORE_DIGEST_LENGTH"
const REFUSE_RESTORE_EMPTY_DIGEST: StringName = &"CHRONICLE_RESTORE_EMPTY_DIGEST"
const REFUSE_RESTORE_EVENT_DOMAIN: StringName = &"CHRONICLE_RESTORE_EVENT_DOMAIN"
const REFUSE_NULL_STATE: StringName = &"CHRONICLE_NULL_STATE"


class State:
	"""A detached copy of the owner's two canonical fields, for capture and restore.

	`digest` is a value copy (packed arrays are copy-on-write), so editing a State never reaches
	the owner it was copied from.
	"""
	var count: int = 0
	var digest: PackedByteArray = PackedByteArray()


## Number of records appended to this settlement's history, ever. Ordinal 0, u64.
var _count: int = 0
## SHA-256 chain over every record in append order, from 32 zero bytes. Ordinal 1, u8 x 32.
var _rolling_digest: PackedByteArray = PackedByteArray()


func _init() -> void:
	"""Start empty: count 0 and the all-zero digest SAVE-R09 section 13 starts the chain from."""
	_rolling_digest.resize(DIGEST_BYTES)
	_rolling_digest.fill(0)


# --- reads ---------------------------------------------------------------------------------------

func count() -> int:
	"""Records appended so far. Never negative."""
	return _count


func rolling_digest() -> PackedByteArray:
	"""A copy of the 32-byte rolling digest; editing it cannot reach the owner."""
	return _rolling_digest.duplicate()


func is_empty() -> bool:
	"""True when no record has ever been appended."""
	return _count == 0


func copy_state_into(out: State) -> StringName:
	"""Copy both canonical fields into a caller-owned State. Refuses a null State."""
	if out == null:
		return REFUSE_NULL_STATE
	out.count = _count
	out.digest = _rolling_digest.duplicate()
	return REFUSE_NONE


# --- append --------------------------------------------------------------------------------------

func append(resident_id: int, event: int, tick: int, other_id: int, detail_key: int,
		out_record: PackedByteArray) -> StringName:
	"""Append one history record: validate, encode, advance the digest, then commit both fields.

	On success `out_record` holds the exact 24 bytes the digest consumed; persisting them is the
	CALLER's obligation (ARCH-MEM-004). With DEC-055 Q8's empty event domain every call refuses
	with CHRONICLE_EVENT_DOMAIN and changes nothing, `out_record` included.
	"""
	var invalid: StringName = record_refusal(resident_id, event, tick, other_id, detail_key)
	if invalid != REFUSE_NONE:
		return invalid
	if _count >= COUNT_MAX:
		return REFUSE_COUNT_EXHAUSTED
	var encoded: PackedByteArray = PackedByteArray()
	var wrote: StringName = encode_record_into(resident_id, event, tick, other_id, detail_key,
		encoded)
	if wrote != REFUSE_NONE:
		return wrote
	var next_digest: PackedByteArray = PackedByteArray()
	var stepped: StringName = digest_step_into(_rolling_digest, encoded, next_digest)
	if stepped != REFUSE_NONE:
		return stepped
	_rolling_digest = next_digest
	_count += 1
	out_record.clear()
	out_record.append_array(encoded)
	return REFUSE_NONE


# --- restore -------------------------------------------------------------------------------------

func restore_state(p_count: int, p_digest: PackedByteArray) -> StringName:
	"""Install a validated count and digest, both or neither. A refusal changes nothing.

	The owner cannot see records, so it checks only what the pair alone can prove: a count that
	is non-negative, a 32-byte digest, the all-zero digest at count 0 (the chain's start), and no
	record at all while the event domain is empty. The section 13 decoder proves the digest
	matches the saved records before calling this.
	"""
	var invalid: StringName = state_refusal(p_count, p_digest)
	if invalid != REFUSE_NONE:
		return invalid
	_count = p_count
	_rolling_digest = p_digest.duplicate()
	return REFUSE_NONE


func clear() -> void:
	"""Return to the empty Chronicle: count 0 and the all-zero digest."""
	_count = 0
	_rolling_digest.resize(DIGEST_BYTES)
	_rolling_digest.fill(0)


static func state_refusal(p_count: int, p_digest: PackedByteArray) -> StringName:
	"""Every rule a (count, digest) pair must satisfy on its own, without any record."""
	if p_count < 0:
		return REFUSE_RESTORE_COUNT
	if p_digest.size() != DIGEST_BYTES:
		return REFUSE_RESTORE_DIGEST_LENGTH
	if p_count == 0 and not is_zero_digest(p_digest):
		return REFUSE_RESTORE_EMPTY_DIGEST
	if p_count > 0 and EVENT_KIND_COUNT == 0:
		return REFUSE_RESTORE_EVENT_DOMAIN
	return REFUSE_NONE


# --- record rules --------------------------------------------------------------------------------

static func is_event_in_domain(event: int) -> bool:
	"""True when `event` is a compiled event kind. Always false in this release (DEC-055 Q8)."""
	return event >= 0 and event < EVENT_KIND_COUNT


static func is_detail_in_domain(detail_key: int) -> bool:
	"""True when `detail_key` is a compiled ChronicleDetail ID. Always false in this release."""
	return detail_key >= 0 and detail_key < DETAIL_KEY_COUNT


static func record_refusal(resident_id: int, event: int, tick: int, other_id: int,
		detail_key: int) -> StringName:
	"""Every rule one record must satisfy, in a fixed order: storage width, tick, then domains.

	Width comes first because GDScript ints are 64-bit and `0x80000000` is positive here but
	INT32_MIN on the wire. A negative tick is refused as `save_header.gd` refuses one. The two
	domain checks follow; with the empty event domain the detail check is not reachable yet.
	"""
	for value: int in [resident_id, event, other_id, detail_key]:
		if not SaveCodec.fits_i32(value):
			return REFUSE_FIELD_NOT_INT32
	if tick < 0:
		return REFUSE_NEGATIVE_TICK
	if not is_event_in_domain(event):
		return REFUSE_EVENT_DOMAIN
	if not is_detail_in_domain(detail_key):
		return REFUSE_DETAIL_DOMAIN
	return REFUSE_NONE


# --- the exact bytes and the exact digest rule ---------------------------------------------------

static func encode_record_into(resident_id: int, event: int, tick: int, other_id: int,
		detail_key: int, out: PackedByteArray) -> StringName:
	"""Write one record's exact 24 little-endian bytes into `out`, resized to 24.

	Checks storage width only, never the domain: this is the byte rule the digest is defined
	over, and tests pin it independently. Refuses a field that does not fit its wire width.
	"""
	for value: int in [resident_id, event, other_id, detail_key]:
		if not SaveCodec.fits_i32(value):
			return REFUSE_FIELD_NOT_INT32
	out.resize(RECORD_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var ok: bool = SaveCodec.write_i32_into(out, OFFSET_RESIDENT_ID, resident_id, scratch)
	ok = ok and SaveCodec.write_i32_into(out, OFFSET_EVENT, event, scratch)
	ok = ok and SaveCodec.write_i64_into(out, OFFSET_TICK, tick, scratch)
	ok = ok and SaveCodec.write_i32_into(out, OFFSET_OTHER_ID, other_id, scratch)
	ok = ok and SaveCodec.write_i32_into(out, OFFSET_DETAIL_KEY, detail_key, scratch)
	return REFUSE_NONE if ok else REFUSE_ENCODE_FAILED


static func digest_step_into(previous: PackedByteArray, record: PackedByteArray,
		out: PackedByteArray) -> StringName:
	"""SAVE-R09 section 13's rule: `out = SHA256(previous || record)`, exactly 32 bytes.

	Refuses a previous digest that is not 32 bytes or a record that is not 24, so a truncated
	input can never be chained. `out` is untouched on refusal.
	"""
	if previous.size() != DIGEST_BYTES or record.size() != RECORD_BYTES:
		return REFUSE_DIGEST_INPUT
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return REFUSE_DIGEST_FAILED
	if context.update(previous) != OK or context.update(record) != OK:
		return REFUSE_DIGEST_FAILED
	var digest: PackedByteArray = context.finish()
	if digest.size() != DIGEST_BYTES:
		return REFUSE_DIGEST_FAILED
	out.resize(DIGEST_BYTES)
	for index: int in DIGEST_BYTES:
		out[index] = digest[index]
	return REFUSE_NONE


static func zero_digest() -> PackedByteArray:
	"""The 32 zero bytes the chain starts from, freshly allocated."""
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(DIGEST_BYTES)
	digest.fill(0)
	return digest


static func is_zero_digest(digest: PackedByteArray) -> bool:
	"""True only for exactly 32 zero bytes."""
	if digest.size() != DIGEST_BYTES:
		return false
	for value: int in digest:
		if value != 0:
			return false
	return true
