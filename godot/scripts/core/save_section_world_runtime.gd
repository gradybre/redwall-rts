extends RefCounted
## ARCH-SAVE-002 section 1 WORLD, the WorldRuntime block: completed tick, world seed, requested
## speed, logical pause mask, host scheduler debt and the six recorded clock counters.
##
## THIS IS A BLOCK OF SECTION 1, NOT THE WHOLE SECTION. Section 1 WORLD also carries
## `spatial_world.gd`'s 262144-cell grid, `world_init.gd`'s published map, `weather.gd`'s row,
## `crop_weather.gd`'s tile agronomy and more -- see `docs/persistence_state_registry.md`, which
## cites "§1 WORLD" on twenty-odd rows across eight modules. Those stores are owned by other
## agents and are deliberately not written here. This module encodes and decodes the leading
## WorldRuntime block at a caller-given offset and reports how many bytes it used, so section 1
## composes from its owners rather than being invented whole by whoever gets there first.
##
## WHAT THIS BLOCK'S BYTES ARE. A FIXED 80 bytes. ARCH-SAVE-007 states in terms that "task 09.2
## still owns its explicit field byte offsets/schema", which is the authority for this layout.
##
##   | Offset | Type | Field                         | ARCH-HASH-001 |
##   |-------:|------|-------------------------------|---------------|
##   |      0 | i64  | completed_tick                | include       |
##   |      8 | i32  | world_seed                    | include       |
##   |     12 | u8   | rng_seeded                    | include       |
##   |     13 | -    | reserved_zero, 3 bytes        | structural    |
##   |     16 | i32  | requested_speed               | include       |
##   |     20 | i32  | pause_mask                    | include       |
##   |     24 | i64  | debt                          | EXCLUDE       |
##   |     32 | i64  | fallback_count                | EXCLUDE       |
##   |     40 | i64  | diagnostic_pause_count        | EXCLUDE       |
##   |     48 | i64  | acknowledged_catchup_resets   | EXCLUDE       |
##   |     56 | i64  | acknowledged_ticks_discarded  | EXCLUDE       |
##   |     64 | i64  | subtick_debt_discards         | EXCLUDE       |
##   |     72 | i64  | day_boundaries_crossed        | EXCLUDE       |
##
## The hashed fields come first ON PURPOSE. The canonical contribution is then a prefix of the
## block, so "what the digest covers" is a structural property you can read off the layout rather
## than a rule kept in a comment somewhere else.
##
## PERSISTENCE OBLIGATION AND DIGEST MEMBERSHIP ARE SEPARATE DIMENSIONS. This is the whole point
## of the 2026-09-11 READY_07 addendum's G3 ruling, and the defect it fixes is a registry where
## category 3 meant both "not hashed" and "not saved". Debt and the six counters are CATEGORY 1 --
## genuinely saved, as host-continuation and evidence metadata -- and are EXCLUDED from
## ARCH-HASH-001 while remaining covered by the section CRC-32 and the body SHA-256. So:
##
##   * `encode_block()` writes all thirteen fields. Change debt and the saved bytes change.
##   * `canonical_bytes_of()` writes only the five hashed ones. Change debt and ARCH-HASH-001
##     does not move. Change requested speed and it does.
##
## `test_save_section_world_runtime.gd` asserts both halves of that, because a codec that quietly
## hashed debt would still round-trip perfectly and still be wrong.
##
## DEBT IS RESTORED EXACTLY. G3: "Do not scale, zero, clamp or subtract debt during restore."
## `2500001` means two owed ticks (TICK_COST is 1000000) plus a remainder of 500001, and it must
## come back as 2500001, not 2000000 and not 2. `decode_into()` validates and REFUSES an
## unrepresentable value; it never saturates, and nothing here rounds a remainder away.
##
## THE DEBT CEILING IS DERIVED, NOT INVENTED. `sim_clock.gd::_is_overloaded()` implements
## ARCH-CLOCK-001's division-free comparison `4*debt > 30*speed*1000000`, so a restored debt whose
## quadruple overflows int64 would make the very first overload test refuse arithmetic on a value
## the save said was fine. The bound is therefore `INT64_MAX / 4` exactly, read off that
## multiplication rather than picked. Likewise `completed_tick + 4500` is GDD §5.1's offset
## calendar, so the tick ceiling is `INT64_MAX - 4500`. Both are "validate representable
## arithmetic bounds before publication"; both reject rather than saturate.
##
## BLOCKER W1 -- THERE IS NO WAY TO PUBLISH THIS BLOCK INTO A LIVE `sim_clock.gd`, AND ADDING ONE
## IS NOT THIS MODULE'S TO DO. `sim_clock.gd` exposes a reader for every field here
## (`completed_tick()`, `debt()`, `requested_speed()`, `pause_mask()` and the six counter
## getters) and a WRITER for only one and a half of them:
##
##   * `set_speed()` restores `_requested_speed`. Fine.
##   * `set_pause()` sets one reason bit at a time -- but `set_pause(PLAYER, true)` ZEROES
##     `_debt` when `0 < _debt < TICK_COST` and increments `_subtick_debt_discards`. Restoring a
##     saved PLAYER pause through it would subtract debt during restore and corrupt a counter,
##     which is precisely what G3 forbids. It is not usable as a restore path.
##   * `_completed_tick`, `_debt` and all six counters have NO writer at all.
##
## So this module stops at a validated `Record` and `agrees_with_clock()`, which verifies a live
## clock against one. Publication needs a `SimClock.restore_runtime(...)` that sets all nine
## fields together with no side effects, and `sim_clock.gd` belongs to another owner. Half-
## publishing through `set_pause()` would be worse than refusing, so this module refuses.
##
## RESTORE ORDER, FOR WHOEVER ADDS THAT ACCESSOR. G3: restore the logical saved pause mask BEFORE
## applying any transient LOAD guard, and adding or removing that guard must not erase PLAYER,
## MENU, CRITICAL or VICTORY holds. `pause_mask_without_load()` and `pause_mask_with_load()` give
## the two masks so the guard is a pure bit operation on the saved value, and
## `test_save_section_world_runtime.gd` proves adding and removing LOAD leaves the other four
## bits untouched. Also reset the host-time sampling origin at that boundary so time spent
## loading is not charged as debt -- a host timestamp is not serialized here at all, which is the
## point.
##
## COLD PATH. ARCH-SAVE-003; see `save_section_rng.gd`'s note. Nothing here runs per tick.
##
## NO FLOAT. ARCH-AUTH-002; `test_save_section_world_runtime.gd` greps this source to enforce it.
##
## OPEN, NOT INVENTED:
##   * `schema_version` stays opaque. Task 09.2's card records the version policy as unresolved
##     and forbids silently repurposing v1 bytes, so no version number is chosen here.
##   * Whether section 1's blocks must be CONTIGUOUS with each other, and in what order, is not
##     settled anywhere. `decode_into()` takes an explicit offset and `BLOCK_BYTES` says how far
##     it reached, which is enough to compose either way without deciding.
##   * `world_seed` is validated only as an i32, which is what `rng.gd::seed_world()` requires.
##     ARCH-NAME-001 calls world seeds a "positive I32" domain, but it says so at the NAMING
##     boundary; no contract restricts the saved seed, so no positivity rule is imposed here.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "1 WORLD, 2 CATALOG_IDS, ...".
const SECTION_ID: int = 1

const OFFSET_COMPLETED_TICK: int = 0
const OFFSET_WORLD_SEED: int = 8
const OFFSET_RNG_SEEDED: int = 12
const OFFSET_RESERVED_ZERO: int = 13
const RESERVED_ZERO_BYTES: int = 3
const OFFSET_REQUESTED_SPEED: int = 16
const OFFSET_PAUSE_MASK: int = 20
const OFFSET_DEBT: int = 24
const OFFSET_FALLBACK_COUNT: int = 32
const OFFSET_DIAGNOSTIC_PAUSE_COUNT: int = 40
const OFFSET_ACKNOWLEDGED_CATCHUP_RESETS: int = 48
const OFFSET_ACKNOWLEDGED_TICKS_DISCARDED: int = 56
const OFFSET_SUBTICK_DEBT_DISCARDS: int = 64
const OFFSET_DAY_BOUNDARIES_CROSSED: int = 72

## Total block width, and the width of the ARCH-HASH-001 prefix inside it.
const BLOCK_BYTES: int = 80
const HASHED_PREFIX_BYTES: int = 24

## The canonical contribution drops the three structural reserved bytes: 8+4+1+4+4.
const CANONICAL_BYTES: int = 21

## Number of clock counters G3 names. The six are listed in `COUNTER_NAMES`.
const COUNTER_COUNT: int = 6

# --- derived validation bounds --------------------------------------------------------------------

## ARCH-CLOCK-001 compares `4*debt` against `30*speed*1000000` without dividing
## (`sim_clock.gd::_is_overloaded`), so a restorable debt is one whose quadruple is representable.
const DEBT_MAX: int = SaveCodec.INT64_MAX / SimClockScript.OVERLOAD_NUMERATOR

## GDD §5.1's calendar is `(tick + 4500) mod 18000`, so a restorable tick is one that addition
## does not overflow.
const COMPLETED_TICK_MAX: int = SaveCodec.INT64_MAX - SimClockScript.CALENDAR_OFFSET_TICKS

## Every pause bit `sim_clock.gd` knows. A mask with any other bit set is refused, not masked.
const KNOWN_PAUSE_BITS: int = SimClockScript.PLAYER | SimClockScript.MENU \
	| SimClockScript.CRITICAL | SimClockScript.VICTORY | SimClockScript.LOAD

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_WORLDRT_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_WORLDRT_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_WORLDRT_LENGTH"
const REFUSE_RESERVED_NONZERO: StringName = &"SAVE_WORLDRT_RESERVED_NONZERO"
const REFUSE_NEGATIVE_TICK: StringName = &"SAVE_WORLDRT_NEGATIVE_TICK"
const REFUSE_TICK_UNREPRESENTABLE: StringName = &"SAVE_WORLDRT_TICK_UNREPRESENTABLE"
const REFUSE_SPEED: StringName = &"SAVE_WORLDRT_SPEED"
const REFUSE_PAUSE_MASK: StringName = &"SAVE_WORLDRT_PAUSE_MASK"
const REFUSE_SEEDED_FLAG: StringName = &"SAVE_WORLDRT_SEEDED_FLAG"
const REFUSE_NEGATIVE_DEBT: StringName = &"SAVE_WORLDRT_NEGATIVE_DEBT"
const REFUSE_DEBT_UNREPRESENTABLE: StringName = &"SAVE_WORLDRT_DEBT_UNREPRESENTABLE"
const REFUSE_NEGATIVE_COUNTER: StringName = &"SAVE_WORLDRT_NEGATIVE_COUNTER"
const REFUSE_HEADER_TICK_MISMATCH: StringName = &"SAVE_WORLDRT_HEADER_TICK_MISMATCH"
const REFUSE_CLOCK_DISAGREES: StringName = &"SAVE_WORLDRT_CLOCK_DISAGREES"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_WORLDRT_ENCODE_FAILED"

## Index order of `Record.counters`, matching G3's printed list exactly.
const COUNTER_FALLBACK: int = 0
const COUNTER_DIAGNOSTIC_PAUSE: int = 1
const COUNTER_ACKNOWLEDGED_CATCHUP_RESETS: int = 2
const COUNTER_ACKNOWLEDGED_TICKS_DISCARDED: int = 3
const COUNTER_SUBTICK_DEBT_DISCARDS: int = 4
const COUNTER_DAY_BOUNDARIES_CROSSED: int = 5

const COUNTER_NAMES: Array[String] = ["_fallback_count", "_diagnostic_pause_count",
	"_acknowledged_catchup_resets", "_acknowledged_ticks_discarded", "_subtick_debt_discards",
	"_day_boundaries_crossed"]


class Record:
	"""One decoded WorldRuntime block. `counters` is allocated once at COUNTER_COUNT in `_init`.

	`debt` and `counters` are saved and CRC/SHA-protected but are NOT part of ARCH-HASH-001; that
	split is realised by `canonical_bytes_of()`, not by a flag on this object.
	"""
	var completed_tick: int = 0
	var world_seed: int = 0
	var rng_seeded: bool = false
	var requested_speed: int = SimClockScript.SPEED_NORMAL
	var pause_mask: int = 0
	var debt: int = 0
	var counters: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate the six-counter column and zero it."""
		counters.resize(COUNTER_COUNT)

	func copy_from(other: Record) -> void:
		"""Overwrite every field from `other` without reallocating the counter column."""
		completed_tick = other.completed_tick
		world_seed = other.world_seed
		rng_seeded = other.rng_seeded
		requested_speed = other.requested_speed
		pause_mask = other.pause_mask
		debt = other.debt
		for index: int in COUNTER_COUNT:
			counters[index] = other.counters[index]

	func owed_ticks() -> int:
		"""Whole ticks the restored debt still owes, matching `sim_clock.gd::owed_ticks()`."""
		return debt / SimClockScript.TICK_COST

	func subtick_debt() -> int:
		"""The sub-tick remainder of the restored debt, which a restore must not round away."""
		return debt % SimClockScript.TICK_COST


class EncodeResult:
	"""Outcome of encoding this block: the bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded bytes; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with no bytes; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- capture -------------------------------------------------------------------------------------

static func capture_into(clock: SimClockScript, world_seed: int, rng_seeded: bool,
		out: Record) -> SaveHeader.Refusal:
	"""Read a live clock plus section 1's world seed into a caller-owned Record.

	The seed and the seeded flag come from the caller because `rng.gd` owns them (persistence
	registry, row "RNG seed and seeded flag" -> §1 WORLD) and `sim_clock.gd` has never heard of
	them. `out` is left untouched unless every field validates.
	"""
	var parsed: Record = Record.new()
	parsed.completed_tick = clock.completed_tick()
	parsed.world_seed = world_seed
	parsed.rng_seeded = rng_seeded
	parsed.requested_speed = clock.requested_speed()
	parsed.pause_mask = clock.pause_mask()
	parsed.debt = clock.debt()
	_capture_counters(clock, parsed)
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _capture_counters(clock: SimClockScript, parsed: Record) -> void:
	"""Copy G3's six recorded clock counters into the record, in COUNTER_NAMES order."""
	parsed.counters[COUNTER_FALLBACK] = clock.fallback_count()
	parsed.counters[COUNTER_DIAGNOSTIC_PAUSE] = clock.diagnostic_pause_count()
	parsed.counters[COUNTER_ACKNOWLEDGED_CATCHUP_RESETS] = clock.acknowledged_catchup_resets()
	parsed.counters[COUNTER_ACKNOWLEDGED_TICKS_DISCARDED] = clock.acknowledged_ticks_discarded()
	parsed.counters[COUNTER_SUBTICK_DEBT_DISCARDS] = clock.subtick_debt_discards()
	parsed.counters[COUNTER_DAY_BOUNDARIES_CROSSED] = clock.day_boundaries_crossed()


# --- encode ---------------------------------------------------------------------------------------

static func encode_block(record: Record, out: EncodeResult) -> bool:
	"""Encode the fixed 80-byte WorldRuntime block, including the excluded host metadata.

	Everything G3 classifies as category 1 is written here -- debt and the six counters included.
	Their exclusion is from the DIGEST, not from the file.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(BLOCK_BYTES)
	_write_hashed_prefix(record, writer)
	writer.write_i64(record.debt)
	for index: int in COUNTER_COUNT:
		writer.write_i64(record.counters[index])
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != BLOCK_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"encoded %d bytes, not the fixed %d" % [bytes.size(), BLOCK_BYTES])
	return out.succeed(bytes)


static func _write_hashed_prefix(record: Record, writer: SaveCodec.Writer) -> void:
	"""Write the 24 hashed bytes: tick, seed, seeded flag, three reserved zeros, speed, mask."""
	writer.write_i64(record.completed_tick)
	writer.write_i32(record.world_seed)
	writer.write_u8(1 if record.rng_seeded else 0)
	writer.write_zero_padding(RESERVED_ZERO_BYTES)
	writer.write_i32(record.requested_speed)
	writer.write_i32(record.pause_mask)


# --- decode ----------------------------------------------------------------------------------------

static func decode_into(bytes: PackedByteArray, offset: int, out: Record) -> SaveHeader.Refusal:
	"""Decode the WorldRuntime block at `offset`, validating the whole extent before writing.

	Allocate before consume (decision 0059): the 80-byte extent is proved present before any
	field is read, and the decoded fields land in a local Record that reaches `out` only after
	every rule passes. A truncated block leaves the caller's Record byte-identical.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var parsed: Record = Record.new()
	var read: SaveHeader.Refusal = _read_fields(reader, parsed)
	if not read.is_ok():
		return read
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove `BLOCK_BYTES` are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own: `save_codec.gd`'s
	Reader is bounded too, so a slack extent check would still end in a refusal and hide.
	A load orchestrator can also ask this before committing to a section.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < BLOCK_BYTES or offset > bytes.size() - BLOCK_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"the WorldRuntime block needs %d bytes at offset %d, buffer holds %d"
				% [BLOCK_BYTES, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_fields(reader: SaveCodec.Reader, parsed: Record) -> SaveHeader.Refusal:
	"""Read all thirteen fields in layout order, refusing nonzero reserved padding."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	reader.read_i64_into(scalar)
	parsed.completed_tick = scalar.value
	reader.read_i32_into(scalar)
	parsed.world_seed = scalar.value
	reader.read_u8_into(scalar)
	var seeded_byte: int = scalar.value
	if not reader.read_zero_padding(RESERVED_ZERO_BYTES):
		return SaveHeader.Refusal.new(REFUSE_RESERVED_NONZERO, reader.detail())
	reader.read_i32_into(scalar)
	parsed.requested_speed = scalar.value
	reader.read_i32_into(scalar)
	parsed.pause_mask = scalar.value
	reader.read_i64_into(scalar)
	parsed.debt = scalar.value
	for index: int in COUNTER_COUNT:
		reader.read_i64_into(scalar)
		parsed.counters[index] = scalar.value
	if reader.failed():
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	return _seeded_flag_refusal(seeded_byte, parsed)


static func _seeded_flag_refusal(seeded_byte: int, parsed: Record) -> SaveHeader.Refusal:
	"""The seeded flag is exactly 0 or 1; any other byte is a refusal, never a truthiness test."""
	if seeded_byte > 1:
		return SaveHeader.Refusal.new(REFUSE_SEEDED_FLAG,
			"the rng_seeded byte is %d, not 0 or 1" % seeded_byte)
	parsed.rng_seeded = seeded_byte == 1
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule this block enforces. Reject, never saturate (ARCH-SAVE-005, G3)."""
	if record.counters.size() != COUNTER_COUNT:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"a WorldRuntime record holds %d counters, not %d"
				% [record.counters.size(), COUNTER_COUNT])
	var tick: SaveHeader.Refusal = _tick_refusal(record.completed_tick)
	if not tick.is_ok():
		return tick
	var control: SaveHeader.Refusal = _control_refusal(record)
	if not control.is_ok():
		return control
	return _host_metadata_refusal(record)


static func _tick_refusal(completed_tick: int) -> SaveHeader.Refusal:
	"""Tick 0 is legal; a negative tick and one whose calendar offset overflows are not."""
	if completed_tick < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_TICK,
			"completed tick %d is negative" % completed_tick)
	if completed_tick > COMPLETED_TICK_MAX:
		return SaveHeader.Refusal.new(REFUSE_TICK_UNREPRESENTABLE,
			"completed tick %d overflows the `tick + %d` calendar"
				% [completed_tick, SimClockScript.CALENDAR_OFFSET_TICKS])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _control_refusal(record: Record) -> SaveHeader.Refusal:
	"""Requested speed is 1, 2 or 4 -- never 0 and never 3 -- and the mask has no unknown bit."""
	if not SimClockScript.SELECTABLE_SPEEDS.has(record.requested_speed):
		return SaveHeader.Refusal.new(REFUSE_SPEED,
			"requested speed %d is not one of 1, 2, 4" % record.requested_speed)
	if record.pause_mask < 0 or (record.pause_mask & ~KNOWN_PAUSE_BITS) != 0:
		return SaveHeader.Refusal.new(REFUSE_PAUSE_MASK,
			"pause mask %d carries a bit outside the known %d"
				% [record.pause_mask, KNOWN_PAUSE_BITS])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _host_metadata_refusal(record: Record) -> SaveHeader.Refusal:
	"""Debt and the six counters are nonnegative I64, and debt's quadruple must be representable."""
	if record.debt < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_DEBT, "debt %d is negative" % record.debt)
	if record.debt > DEBT_MAX:
		return SaveHeader.Refusal.new(REFUSE_DEBT_UNREPRESENTABLE,
			"debt %d overflows ARCH-CLOCK-001's `%d*debt` overload test"
				% [record.debt, SimClockScript.OVERLOAD_NUMERATOR])
	for index: int in COUNTER_COUNT:
		if record.counters[index] < 0:
			return SaveHeader.Refusal.new(REFUSE_NEGATIVE_COUNTER,
				"%s is %d, which is negative" % [COUNTER_NAMES[index], record.counters[index]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func header_tick_refusal(record: Record, header_completed_tick: int) -> SaveHeader.Refusal:
	"""G3: the completed tick is section 1 PLUS a validated header tick. They must agree."""
	if record.completed_tick != header_completed_tick:
		return SaveHeader.Refusal.new(REFUSE_HEADER_TICK_MISMATCH,
			"section 1 says tick %d, the header says %d"
				% [record.completed_tick, header_completed_tick])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- pause-mask helpers for the LOAD guard ---------------------------------------------------------

static func pause_mask_without_load(pause_mask: int) -> int:
	"""The logical saved mask with the transient LOAD guard cleared and every other hold kept."""
	return pause_mask & ~SimClockScript.LOAD


static func pause_mask_with_load(pause_mask: int) -> int:
	"""The mask with the transient LOAD guard added and every other hold kept."""
	return pause_mask | SimClockScript.LOAD


# --- verification against a live clock -------------------------------------------------------------

static func agrees_with_clock(record: Record, clock: SimClockScript,
		world_seed: int, rng_seeded: bool) -> SaveHeader.Refusal:
	"""Compare a decoded record against a live clock field for field. See BLOCKER W1.

	This is the verifier that exists because the publisher cannot: `sim_clock.gd` has no writer
	for the completed tick, the debt or the six counters, so this module can prove a restored
	world matches a save but cannot perform the restore.
	"""
	var live: Record = Record.new()
	var captured: SaveHeader.Refusal = capture_into(clock, world_seed, rng_seeded, live)
	if not captured.is_ok():
		return captured
	var mismatch: String = _first_difference(record, live)
	if mismatch != "":
		return SaveHeader.Refusal.new(REFUSE_CLOCK_DISAGREES, mismatch)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _first_difference(record: Record, live: Record) -> String:
	"""Name the first field on which a record and a live capture differ, or the empty String."""
	if record.completed_tick != live.completed_tick:
		return "completed tick %d vs %d" % [record.completed_tick, live.completed_tick]
	if record.world_seed != live.world_seed or record.rng_seeded != live.rng_seeded:
		return "world seed %d/%s vs %d/%s" % [record.world_seed, record.rng_seeded,
			live.world_seed, live.rng_seeded]
	if record.requested_speed != live.requested_speed:
		return "requested speed %d vs %d" % [record.requested_speed, live.requested_speed]
	if record.pause_mask != live.pause_mask:
		return "pause mask %d vs %d" % [record.pause_mask, live.pause_mask]
	if record.debt != live.debt:
		return "debt %d vs %d" % [record.debt, live.debt]
	for index: int in COUNTER_COUNT:
		if record.counters[index] != live.counters[index]:
			return "%s %d vs %d" % [COUNTER_NAMES[index], record.counters[index],
				live.counters[index]]
	return ""


# --- ARCH-HASH-001 contribution ------------------------------------------------------------------

static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This block's contribution to ARCH-HASH-001: the five hashed fields and nothing else.

	G3's table, row by row: completed tick INCLUDE; requested speed and the logical pause mask
	INCLUDE; host debt EXCLUDE; the six recorded clock counters EXCLUDE. The world seed is an
	authoritative World field that ARCH-HASH-001's exclusion list does not name, so it is
	included. The three reserved bytes are file structure, not state, so they are dropped -- this
	is a field digest, not a byte image of the block.

	Section 15 STATE_DIGEST owns the `RWL-STATE-1` domain string, the concatenation order and the
	final SHA-256. None of those is decided here.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(CANONICAL_BYTES)
	writer.write_i64(record.completed_tick)
	writer.write_i32(record.world_seed)
	writer.write_u8(1 if record.rng_seeded else 0)
	writer.write_i32(record.requested_speed)
	writer.write_i32(record.pause_mask)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	return out.succeed(writer.to_bytes())
