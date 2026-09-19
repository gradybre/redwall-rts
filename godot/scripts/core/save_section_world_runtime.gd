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
## THE DEBT CEILING IS `INT64_MAX`, CORRECTED BY RESTORE-R01. This module used to cap debt at
## `INT64_MAX / 4`, reasoning from `sim_clock.gd::_is_overloaded()`'s division-free `4*debt`
## comparison. RESTORE-R01 settles the domain the other way: "debt and each of the six counters in
## 0..INT64_MAX", and "subsequent arithmetic must continue to refuse overflow rather than wrap or
## clamp; restoring a representable value is not permission to overflow it". The old cap made this
## codec REFUSE a debt `sim_clock.restore_runtime()` accepts, which is a codec quietly reducing
## the stored debt's admissible range -- exactly what the ruling forbids. The overload test is
## already checked arithmetic (`IntMath.checked_mul_into(4, _debt, ...)`, treating an overflow as
## overloaded), so the checked side owns that bound and the codec validates representability only.
## `completed_tick + 4500` is GDD §5.1's offset calendar, so the tick ceiling stays
## `INT64_MAX - 4500`. Both reject rather than saturate.
##
## BLOCKER W1 -- THE CLOCK OWNER API EXISTS; JOINT SAVE INSTALL IS SEPARATE
## `SimClock.restore_runtime()` and `GameManager.restore_clock_runtime()` already install the
## ten clock values exactly under the manager's load barrier. Ordinary set_pause(PLAYER, true)
## discards sub-tick debt and must never be used to manufacture a restored clock.
## `save_world_runtime_install.gd` (SAVE-W1-R02) joins this decoded record with section 10's
## stream positions: reseeding alone would zero every draw count. It validates both first,
## installs RNG then clock, and recovers prior RNG on refusal without lowering the barrier.
## Its success is not world publication; all other sections, disk recovery and final publication
## remain the full coordinator's responsibility. This codec's frozen 80-byte format is unchanged.
##
## THE TRANSIENT LOAD GUARD IS NOT A MASK BIT ANY MORE -- RESTORE-R01 SUPERSEDES G3 HERE. The
## load-in-progress guard is an OUT-OF-BAND barrier (`sim_clock.acquire_load_barrier()`, held by
## `game_manager.begin_load()`), and the ruling is explicit that it "is not OR-ed into the
## serialized/canonical logical pause mask". So a saving world does not acquire a LOAD bit by
## being loaded, and a restore does not mutate the mask to raise or lower one. What the ruling
## DOES require is that a genuinely saved LOAD bit survives: "never blindly clear the LOAD bit
## because this particular load operation finished". `pause_mask_without_load()` and
## `pause_mask_with_load()` therefore remain as pure bit helpers for a caller that must reason
## about the two masks -- they are NOT a restore step, and nothing in the restore path calls
## them. Also reset the host-time sampling origin at the release boundary so time spent loading
## is not charged as debt; no host timestamp is serialized here at all, which is the point.
##
## THIS BLOCK'S CANONICAL FIELD RECORDS ARE FOUR, NOT TWELVE AND NOT THIRTEEN. REG-R01's
## correction: "The completed tick appears once in the canonical prefix, not again as a typed
## record. Debt and six clock counters persist in the 80-byte body but contribute no canonical
## field record." `CANONICAL_FIELD_KEYS` below is therefore `_world_seed, _seeded,
## _requested_speed, _pause_mask`. `canonical_bytes_of()` is the OLD 21-byte block-prefix helper
## and it still begins with the completed tick, so it MUST NOT be concatenated into §15's stream
## as an extra header -- doing so would hash the tick twice. Nothing here hashes debt.
##
## SECTION 1 COMPOSITION (REG-R01, SAVE-LAYOUT-R01). See the `--- section 1 composition ---`
## division below: a 44-byte map-provenance prefix, `store_count:u32`, then owner blocks in ASCII
## key order tiling the remainder with no gaps. This module encodes the two blocks it owns --
## `entity_directory` (the 4-byte D2 cursor) and `world_runtime` (this 80-byte body) -- and
## decodes any registered §1 owner's block extent without guessing its schema.
##
## COLD PATH. ARCH-SAVE-003; see `save_section_rng.gd`'s note. Nothing here runs per tick.
##
## NO FLOAT. ARCH-AUTH-002; `test_save_section_world_runtime.gd` greps this source to enforce it.
##
## OPEN, NOT INVENTED:
## BLOCKER W2 IS CLOSED BY R-WORLD-S1-001, AND `save_section_01.gd` IS WHERE. That module encodes,
## decodes, validates and restores all nine §1 owners at the ruled offsets, takes §1 to schema 3
## and `resource_nodes` to owner schema 2, and drops the three deposit scratch arrays from the wire
## entirely. THIS module keeps the two fixed-format payloads it has always owned -- the 4-byte D2
## cursor and the 80-byte WorldRuntime body -- plus `decode_section()`, which remains a bounded
## MEASURING walker over an arbitrary §1 composition and deliberately interprets no foreign block.
## The paragraph below is retained as the record of what the gap was.
##
##   * BLOCKER W2 (CLOSED) -- SEVEN OF SECTION 1'S NINE OWNERS HAD NO ENCODER ANYWHERE. REG-R01 registers
##     `buildings, entity_directory, farming, forage, resource_nodes, spatial_world, weather,
##     world_init, world_runtime` in §1. Two are encoded here; the other seven are owned by other
##     modules and none of them publishes a §1 block yet. `encode_section()` therefore emits
##     `store_count = 2`, which is a DEVELOPMENT section 1 and not a release one. It is not this
##     module's place to invent seven payloads, and `missing_owner_keys()` names the gap in code
##     rather than leaving it to be discovered. `decode_section()` already accepts and measures
##     their blocks, so the composition grows without this file guessing anyone's schema.
##   * The 44-byte prefix's `scenario_version`, `map_generator_schema` and `authored_map_digest`
##     are carried and bounded here; SAVE-R09-003 gives their VALUES to the world/scenario owner,
##     and `world_init.gd` does not produce them yet. No default is manufactured: a caller that
##     does not set them saves zeros, and only the map-hash producer may decide what zeros mean.
##   * `world_seed` is validated only as an i32, which is what `rng.gd::seed_world()` requires.
##     ARCH-NAME-001 calls world seeds a "positive I32" domain, but it says so at the NAMING
##     boundary; no contract restricts the saved seed, so no positivity rule is imposed here.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

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

## RESTORE-R01: "debt and each of the six counters in 0..INT64_MAX". The GDScript int IS int64,
## so the only rule a value can violate is the lower one -- which is why `_host_metadata_refusal()`
## tests for a NEGATIVE debt and no longer for an upper bound. Kept as a named constant because
## the registry and the clock must be able to cite the same ceiling.
const DEBT_MAX: int = SaveCodec.INT64_MAX

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
## Retired by RESTORE-R01's `0..INT64_MAX` debt domain and no longer reachable; the spelling stays
## so a decoder of an older fixture that recorded it can still name what it meant.
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
	"""Debt and the six counters are nonnegative I64 -- RESTORE-R01's whole domain rule.

	There is deliberately no upper test: `0..INT64_MAX` IS the GDScript int, and the tighter
	`INT64_MAX/4` this once enforced would refuse saves `sim_clock.restore_runtime()` accepts.
	"""
	if record.debt < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_DEBT, "debt %d is negative" % record.debt)
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
	"""The legacy 21-byte hashed prefix of this block. NOT §15's canonical field stream.

	REG-R01 corrects what this is for: "The completed tick appears once in the canonical prefix,
	not again as a typed record", and debt and the six counters "contribute no canonical field
	record". So this helper MUST NOT be concatenated into §15's stream as an extra header -- the
	completed tick is already there and would be hashed twice. `CANONICAL_FIELD_KEYS` is the
	block's actual canonical field set, and it is four keys, not five and not twelve.

	What this still is: a stable digest of the block's hashed prefix, used by
	`test_save_section_world_runtime.gd` to prove that changing debt or a counter does not move it
	while changing the speed or the mask does. That property is the reason it survives.

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


# --- section 1 composition (REG-R01 §1, SAVE-LAYOUT-R01) -------------------------------------------
#
# THE WHOLE SECTION, NOT JUST THIS BLOCK:
#
#   | Offset | Type     | Field                                                | Bytes |
#   |-------:|----------|------------------------------------------------------|------:|
#   |      0 | u32      | scenario_version                                     |     4 |
#   |      4 | i32      | effective_seed                                       |     4 |
#   |      8 | u32      | map_generator_schema                                 |     4 |
#   |     12 | bytes    | authored_map_digest                                  |    32 |
#   |     44 | u32      | store_count                                          |     4 |
#   |     48 | block    | owner blocks, ASCII key order, tiling to section end  |     - |
#
# The first 44 bytes are SAVE-R09-003's map-provenance prefix, retained verbatim. Each block is
# SAVE-LAYOUT-R01's wrapper -- `owner_key:utf8-u32, owner_schema_version:u32, primary_count:u64,
# payload_byte_length:u64, payload` -- and the blocks TILE the remainder: the first starts at 48,
# every next one starts where the previous ended, and the last ends exactly at the section end.
# A gap, an overlap, a repeat, a descending key or a trailing byte is a refusal.
#
# THE TWO BLOCKS THIS MODULE OWNS, in the ASCII order they are emitted:
#
#   "entity_directory", schema 1, primary_count 1, payload 4  -> `_next_persistent_id:u32 LE`
#   "world_runtime",    schema 1, primary_count 1, payload 80 -> the block above, byte for byte
#
# NO DIRECTORY STATE ENTERS THE WORLDRUNTIME PAYLOAD. The 80 bytes and their offsets are exactly
# what they were; the D2 cursor is a separate owner with a separate key, which is what makes it
# possible to version one without versioning the other.


## SAVE-LAYOUT-R01's wrapper, less the owner key's own bytes: length u32, schema u32,
## primary_count u64, payload_byte_length u64.
const WRAPPER_FIXED_BYTES: int = 24

## SAVE-R09-003's map-provenance prefix and its fields.
const PREFIX_BYTES: int = 44
const OFFSET_SCENARIO_VERSION: int = 0
const OFFSET_EFFECTIVE_SEED: int = 4
const OFFSET_MAP_GENERATOR_SCHEMA: int = 8
const OFFSET_AUTHORED_MAP_DIGEST: int = 12
const AUTHORED_MAP_DIGEST_BYTES: int = 32
const OFFSET_STORE_COUNT: int = 44
const STORE_COUNT_BYTES: int = 4

## REG-R01's baseline section-version vector gave §1 version 2. R-WORLD-S1-001 moves it to **3**
## in the same activation that reclassifies `resource_nodes`' three deposit arrays as scratch and
## takes that owner to schema 2; the registry's vector now reads `[3,2,1,2,1,1,2,1,2,1,1,2,1,2,1]`.
## The OWNER schemas inside the section are a different namespace: eight of the nine are still 1.
const SECTION_SCHEMA_VERSION: int = 3

## Every owner REG-R01 registers in §1, in the ASCII order blocks must appear in. `store_count`
## is bounded by this list's length, which is what "the registry bounds store_count" means here.
const SECTION_OWNER_KEYS: Array[String] = ["buildings", "entity_directory", "farming", "forage",
	"resource_nodes", "spatial_world", "weather", "world_init", "world_runtime"]
const SECTION_OWNER_COUNT: int = 9

## The owner keys this module encodes, in the order it emits them. `encode_section()` REFUSES if
## this list is not strictly ASCII-ascending, so the ordering rule is enforced rather than assumed.
const OWNER_KEY_ENTITY_DIRECTORY: String = "entity_directory"
const OWNER_KEY_WORLD_RUNTIME: String = "world_runtime"
const OWNED_OWNER_KEYS: Array[String] = [OWNER_KEY_ENTITY_DIRECTORY, OWNER_KEY_WORLD_RUNTIME]

## Both owned blocks are schema 1 with one primary row (REG-R01).
const OWNER_SCHEMA_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 1

## `_next_persistent_id:u32 LE` and nothing else.
const DIRECTORY_PAYLOAD_BYTES: int = 4

## Owner keys are nonempty ASCII, at most 256 bytes (S2).
const OWNER_KEY_MAX_BYTES: int = 256
const ASCII_MAX: int = 127

## D2's cursor domain, mirrored from `entity_directory.gd` so the codec and the store cite one rule.
const PERSISTENT_ID_MIN: int = EntityDirectoryScript.PERSISTENT_ID_MIN
const PERSISTENT_ID_EXHAUSTED: int = EntityDirectoryScript.PERSISTENT_ID_EXHAUSTED

## Exact width of the two-block development composition this module can emit today (BLOCKER W2).
const OWNED_SECTION_BYTES: int = PREFIX_BYTES + STORE_COUNT_BYTES \
	+ WRAPPER_FIXED_BYTES + 16 + DIRECTORY_PAYLOAD_BYTES \
	+ WRAPPER_FIXED_BYTES + 13 + BLOCK_BYTES

## REG-R01's correction: the completed tick is carried once by §15's canonical prefix and debt and
## the six counters contribute no canonical field record at all. These four are what remain.
const CANONICAL_FIELD_KEYS: Array[StringName] = [&"_world_seed", &"_seeded", &"_requested_speed",
	&"_pause_mask"]
const CANONICAL_FIELD_COUNT: int = 4

const REFUSE_SECTION_TRUNCATED: StringName = &"SAVE_WORLDRT_SECTION_TRUNCATED"
const REFUSE_SECTION_STORE_COUNT: StringName = &"SAVE_WORLDRT_SECTION_STORE_COUNT"
const REFUSE_SECTION_OWNER_KEY: StringName = &"SAVE_WORLDRT_SECTION_OWNER_KEY"
const REFUSE_SECTION_OWNER_ORDER: StringName = &"SAVE_WORLDRT_SECTION_OWNER_ORDER"
const REFUSE_SECTION_OWNER_SCHEMA: StringName = &"SAVE_WORLDRT_SECTION_OWNER_SCHEMA"
const REFUSE_SECTION_PRIMARY_COUNT: StringName = &"SAVE_WORLDRT_SECTION_PRIMARY_COUNT"
const REFUSE_SECTION_PAYLOAD_LENGTH: StringName = &"SAVE_WORLDRT_SECTION_PAYLOAD_LENGTH"
const REFUSE_SECTION_NOT_TILED: StringName = &"SAVE_WORLDRT_SECTION_NOT_TILED"
const REFUSE_SECTION_OWNER_MISSING: StringName = &"SAVE_WORLDRT_SECTION_OWNER_MISSING"
const REFUSE_SECTION_PREFIX_FIELD: StringName = &"SAVE_WORLDRT_SECTION_PREFIX_FIELD"
const REFUSE_CURSOR_RANGE: StringName = &"SAVE_WORLDRT_CURSOR_RANGE"
## R-WORLD-S1-001 retired the two-block composition as a producer; see `encode_section()`.
const REFUSE_SECTION_SUPERSEDED: StringName = &"SAVE_WORLDRT_SECTION_SUPERSEDED"


class SectionRecord:
	"""One decoded section 1: the map-provenance prefix, the D2 cursor, this block, and the
	measured extents of every OTHER registered owner's block that was present.

	The foreign columns are how §1 grows without this module guessing anyone's schema: the key,
	declared schema version, primary count and the payload's absolute offset and length are all
	recorded, so `spatial_world.gd` or `farming.gd` can decode its own block out of the same
	buffer. No foreign payload is interpreted here, and none is re-encoded.
	"""
	var scenario_version: int = 0
	var effective_seed: int = 0
	var map_generator_schema: int = 0
	var authored_map_digest: PackedByteArray = PackedByteArray()
	var next_persistent_id: int = PERSISTENT_ID_MIN
	var runtime: Record = null
	var foreign_keys: PackedStringArray = PackedStringArray()
	var foreign_schema_version: PackedInt32Array = PackedInt32Array()
	var foreign_primary_count: PackedInt64Array = PackedInt64Array()
	var foreign_payload_offset: PackedInt64Array = PackedInt64Array()
	var foreign_payload_length: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate the 32-byte authored-map digest and the owned WorldRuntime record."""
		authored_map_digest.resize(AUTHORED_MAP_DIGEST_BYTES)
		runtime = Record.new()

	func note_foreign(key: String, schema_version: int, primary_count: int,
			payload_offset: int, payload_length: int) -> void:
		"""Record one non-owned registered owner's block extent, in the order it was read."""
		foreign_keys.append(key)
		foreign_schema_version.append(schema_version)
		foreign_primary_count.append(primary_count)
		foreign_payload_offset.append(payload_offset)
		foreign_payload_length.append(payload_length)

	func copy_from(other: SectionRecord) -> void:
		"""Overwrite every field from `other`, including the foreign extent columns."""
		scenario_version = other.scenario_version
		effective_seed = other.effective_seed
		map_generator_schema = other.map_generator_schema
		authored_map_digest = other.authored_map_digest.duplicate()
		next_persistent_id = other.next_persistent_id
		runtime.copy_from(other.runtime)
		foreign_keys = other.foreign_keys.duplicate()
		foreign_schema_version = other.foreign_schema_version.duplicate()
		foreign_primary_count = other.foreign_primary_count.duplicate()
		foreign_payload_offset = other.foreign_payload_offset.duplicate()
		foreign_payload_length = other.foreign_payload_length.duplicate()

	func missing_owner_keys() -> PackedStringArray:
		"""Registered §1 owners with no block in this section. Empty means complete (BLOCKER W2).

		Completeness is REPORTED, not enforced: refusing a development section 1 that legitimately
		predates seven encoders would block the load path this composition exists to unblock. The
		release gate belongs to the load orchestrator, which is the only caller that knows whether
		it is reading a release save.
		"""
		var absent: PackedStringArray = PackedStringArray()
		for key: String in SECTION_OWNER_KEYS:
			if key == OWNER_KEY_ENTITY_DIRECTORY or key == OWNER_KEY_WORLD_RUNTIME:
				continue
			if foreign_keys.has(key):
				continue
			absent.append(key)
		return absent


static func owner_order_index(owner_key: String) -> int:
	"""Position of a registered §1 owner key in ASCII order, or -1 when it is not registered.

	Not a failure sentinel dressed as a value: -1 means "no such registered owner", and every
	caller here turns it straight into REFUSE_SECTION_OWNER_KEY rather than indexing with it.
	"""
	return SECTION_OWNER_KEYS.find(owner_key)


static func section_refusal(section: SectionRecord) -> SaveHeader.Refusal:
	"""Every rule section 1 enforces outside the 80-byte block's own `record_refusal()`."""
	if section.authored_map_digest.size() != AUTHORED_MAP_DIGEST_BYTES:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PREFIX_FIELD,
			"the authored map digest is %d bytes, not %d"
				% [section.authored_map_digest.size(), AUTHORED_MAP_DIGEST_BYTES])
	if section.scenario_version < 0 or section.scenario_version > SaveCodec.UINT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PREFIX_FIELD,
			"scenario version %d is not a u32" % section.scenario_version)
	if section.map_generator_schema < 0 or section.map_generator_schema > SaveCodec.UINT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PREFIX_FIELD,
			"map generator schema %d is not a u32" % section.map_generator_schema)
	if section.effective_seed < SaveCodec.INT32_MIN or section.effective_seed > SaveCodec.INT32_MAX:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PREFIX_FIELD,
			"effective seed %d is not an i32" % section.effective_seed)
	var cursor: SaveHeader.Refusal = cursor_refusal(section.next_persistent_id)
	if not cursor.is_ok():
		return cursor
	return record_refusal(section.runtime)


static func cursor_refusal(next_persistent_id: int) -> SaveHeader.Refusal:
	"""D2's domain rule: the cursor lies in `1..2147483648`, and 2147483648 means EXHAUSTED.

	The upper bound is a legal saved value, not an error: it is the cursor left after the final
	signed-int32 identity has been issued. It is the LIVE COLUMN that may never carry it, and
	`entity_directory.gd` enforces that. This codec refuses 0 and 2147483649.
	"""
	if next_persistent_id < PERSISTENT_ID_MIN or next_persistent_id > PERSISTENT_ID_EXHAUSTED:
		return SaveHeader.Refusal.new(REFUSE_CURSOR_RANGE,
			"the persistent-id cursor %d is outside %d..%d"
				% [next_persistent_id, PERSISTENT_ID_MIN, PERSISTENT_ID_EXHAUSTED])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func encode_section(section: SectionRecord, out: EncodeResult) -> bool:
	"""REFUSED. R-WORLD-S1-001 makes `save_section_01.gd` the only producer of a section 1.

	The ruling is explicit that the target section has exactly nine owners and that "missing blocks
	are not a permitted target-schema variant". A second producer that emitted two of them would be
	a working way to write a section no target decoder accepts, so the entry point that used to do
	it now names its successor instead of quietly producing one.

	The two-block composition itself is NOT deleted: `encode_development_section()` still builds it,
	and the suite uses it to exercise the wrapper, ordering and tiling rules that both producers
	share. What changed is that nothing can reach it by the old name and by accident.
	"""
	var _unused: SectionRecord = section
	return out.refuse(REFUSE_SECTION_SUPERSEDED,
		"section 1 is composed by save_section_01.gd; this module owns two of its nine blocks")


static func encode_development_section(section: SectionRecord, out: EncodeResult) -> bool:
	"""Encode the 44-byte prefix, `store_count = 2` and this module's two owner blocks.

	A DEVELOPMENT composition and nothing more. It is the fixture the wrapper/order/tiling tests
	are built on, and it is not a section any target decoder accepts; `save_section_01.gd` is.
	"""
	var invalid: SaveHeader.Refusal = section_refusal(section)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var order: SaveHeader.Refusal = _owned_key_order_refusal()
	if not order.is_ok():
		return out.refuse(order.code, order.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(OWNED_SECTION_BYTES)
	_write_prefix(section, writer)
	writer.write_u32(OWNED_OWNER_KEYS.size())
	for owner_key: String in OWNED_OWNER_KEYS:
		if not _write_owned_block(section, owner_key, writer):
			return out.refuse(REFUSE_ENCODE_FAILED, "block %s would not encode" % owner_key)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var bytes: PackedByteArray = writer.to_bytes()
	if bytes.size() != OWNED_SECTION_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"section 1 encoded %d bytes, not %d" % [bytes.size(), OWNED_SECTION_BYTES])
	return out.succeed(bytes)


static func _owned_key_order_refusal() -> SaveHeader.Refusal:
	"""Prove `OWNED_OWNER_KEYS` is registered and strictly ASCII-ascending before anything is emitted.

	SAVE-LAYOUT-R01 orders blocks by ASCII owner key. Checking the emitted order HERE, rather than
	trusting the literal's arrangement, is what makes a swapped pair a refusal instead of a file
	that decodes on the machine that wrote it and nowhere else.
	"""
	var previous: int = -1
	for owner_key: String in OWNED_OWNER_KEYS:
		var index: int = owner_order_index(owner_key)
		if index < 0:
			return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_KEY,
				"'%s' is not a registered section 1 owner" % owner_key)
		if index <= previous:
			return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_ORDER,
				"'%s' breaks ASCII owner order" % owner_key)
		previous = index
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _write_prefix(section: SectionRecord, writer: SaveCodec.Writer) -> void:
	"""Write SAVE-R09-003's 44-byte map-provenance prefix, retained verbatim."""
	writer.write_u32(section.scenario_version)
	writer.write_i32(section.effective_seed)
	writer.write_u32(section.map_generator_schema)
	writer.write_bytes(section.authored_map_digest)


static func _write_owned_block(section: SectionRecord, owner_key: String,
		writer: SaveCodec.Writer) -> bool:
	"""Write one owned block: SAVE-LAYOUT-R01's wrapper, then its payload."""
	var payload: PackedByteArray = PackedByteArray()
	if owner_key == OWNER_KEY_ENTITY_DIRECTORY:
		var cursor: SaveCodec.Writer = SaveCodec.Writer.new(DIRECTORY_PAYLOAD_BYTES)
		cursor.write_u32(section.next_persistent_id)
		payload = cursor.to_bytes()
	else:
		var body: EncodeResult = EncodeResult.new()
		if not encode_block(section.runtime, body):
			return false
		payload = body.bytes
	writer.write_utf8_u32(owner_key, OWNER_KEY_MAX_BYTES)
	writer.write_u32(OWNER_SCHEMA_VERSION)
	writer.write_u64(OWNER_PRIMARY_COUNT)
	writer.write_u64(payload.size())
	writer.write_bytes(payload)
	return not writer.failed()


class BlockWalk:
	"""Mutable state of one `decode_section()` walk: ASCII order so far and the owned blocks seen.

	A class rather than three out-parameters because GDScript passes integers and booleans by
	value, and a walk that cannot remember the previous key cannot enforce an order.
	"""
	var previous_index: int = -1
	var seen_directory: bool = false
	var seen_runtime: bool = false

	func missing_owned_key() -> String:
		"""The owned owner key this walk never saw, or the empty String when both were present."""
		if not seen_directory:
			return OWNER_KEY_ENTITY_DIRECTORY
		if not seen_runtime:
			return OWNER_KEY_WORLD_RUNTIME
		return ""


static func decode_section(bytes: PackedByteArray, offset: int, section_byte_length: int,
		out: SectionRecord) -> SaveHeader.Refusal:
	"""Decode a whole section 1 at `offset`, validating the extent before reading a field.

	Allocate before consume (decision 0059): every block is walked into a local SectionRecord and
	the caller's is overwritten only after the blocks tile the section exactly, both owned owners
	are present and every field validates. A malformed section leaves `out` untouched.
	"""
	var extent: SaveHeader.Refusal = section_extent_refusal(bytes, offset, section_byte_length)
	if not extent.is_ok():
		return extent
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	var staged: SectionRecord = SectionRecord.new()
	var prefix: SaveHeader.Refusal = _read_prefix(reader, staged)
	if not prefix.is_ok():
		return prefix
	var walked: SaveHeader.Refusal = _read_blocks(bytes, reader, offset + section_byte_length,
		staged)
	if not walked.is_ok():
		return walked
	var invalid: SaveHeader.Refusal = section_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func section_extent_refusal(bytes: PackedByteArray, offset: int,
		section_byte_length: int) -> SaveHeader.Refusal:
	"""Prove `section_byte_length` bytes are readable at `offset` and can hold prefix and count."""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if section_byte_length < PREFIX_BYTES + STORE_COUNT_BYTES:
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED,
			"section 1 is %d bytes, below the %d-byte prefix and store count"
				% [section_byte_length, PREFIX_BYTES + STORE_COUNT_BYTES])
	if bytes.size() < section_byte_length or offset > bytes.size() - section_byte_length:
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED,
			"section 1 needs %d bytes at offset %d, buffer holds %d"
				% [section_byte_length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_prefix(reader: SaveCodec.Reader, staged: SectionRecord) -> SaveHeader.Refusal:
	"""Read SAVE-R09-003's 44-byte map-provenance prefix into the staged record."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	reader.read_u32_into(scalar)
	staged.scenario_version = scalar.value
	reader.read_i32_into(scalar)
	staged.effective_seed = scalar.value
	reader.read_u32_into(scalar)
	staged.map_generator_schema = scalar.value
	if not reader.read_bytes_into(AUTHORED_MAP_DIGEST_BYTES, staged.authored_map_digest):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	if reader.failed():
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_blocks(bytes: PackedByteArray, reader: SaveCodec.Reader, section_end: int,
		staged: SectionRecord) -> SaveHeader.Refusal:
	"""Read `store_count` and then every owner block, proving they tile the section exactly."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	var store_count: int = scalar.value
	if store_count < 1 or store_count > SECTION_OWNER_COUNT:
		return SaveHeader.Refusal.new(REFUSE_SECTION_STORE_COUNT,
			"store_count %d is outside 1..%d" % [store_count, SECTION_OWNER_COUNT])
	var walk: BlockWalk = BlockWalk.new()
	for index: int in store_count:
		var block: SaveHeader.Refusal = _read_one_block(bytes, reader, section_end, staged, walk)
		if not block.is_ok():
			return block
	if reader.position() != section_end:
		return SaveHeader.Refusal.new(REFUSE_SECTION_NOT_TILED,
			"%d blocks ended at %d, not the section end %d"
				% [store_count, reader.position(), section_end])
	var missing: String = walk.missing_owned_key()
	if missing != "":
		return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_MISSING,
			"section 1 carries no '%s' block" % missing)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_one_block(bytes: PackedByteArray, reader: SaveCodec.Reader, section_end: int,
		staged: SectionRecord, walk: BlockWalk) -> SaveHeader.Refusal:
	"""Read one owner block's wrapper, dispatch its payload, and advance past it exactly."""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_KEY, reader.detail())
	var owner_key: String = text.value
	var index: int = owner_order_index(owner_key)
	if index < 0:
		return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_KEY,
			"'%s' is not a registered section 1 owner" % owner_key)
	if index <= walk.previous_index:
		return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_ORDER,
			"'%s' is out of ASCII owner order or repeated" % owner_key)
	walk.previous_index = index
	var header: SaveCodec.Scalar = SaveCodec.Scalar.new()
	reader.read_u32_into(header)
	var schema_version: int = header.value
	reader.read_u64_into(header)
	var primary_count: int = header.value
	reader.read_u64_into(header)
	var payload_length: int = header.value
	if reader.failed():
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	var payload_offset: int = reader.position()
	if payload_length < 0 or payload_length > section_end - payload_offset:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PAYLOAD_LENGTH,
			"'%s' declares %d payload bytes, %d remain in the section"
				% [owner_key, payload_length, section_end - payload_offset])
	return _dispatch_block(bytes, reader, owner_key, schema_version, primary_count,
		payload_offset, payload_length, staged, walk)


static func _dispatch_block(bytes: PackedByteArray, reader: SaveCodec.Reader, owner_key: String,
		schema_version: int, primary_count: int, payload_offset: int, payload_length: int,
		staged: SectionRecord, walk: BlockWalk) -> SaveHeader.Refusal:
	"""Decode an owned payload or measure a foreign one, then seek past `payload_length` exactly."""
	var decoded: SaveHeader.Refusal = _decode_payload(bytes, owner_key, schema_version,
		primary_count, payload_offset, payload_length, staged, walk)
	if not decoded.is_ok():
		return decoded
	if not reader.seek(payload_offset + payload_length):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _decode_payload(bytes: PackedByteArray, owner_key: String, schema_version: int,
		primary_count: int, payload_offset: int, payload_length: int, staged: SectionRecord,
		walk: BlockWalk) -> SaveHeader.Refusal:
	"""Dispatch one block's payload by owner key. Foreign blocks are measured, never interpreted."""
	if owner_key == OWNER_KEY_ENTITY_DIRECTORY:
		walk.seen_directory = true
		return _decode_directory_payload(bytes, schema_version, primary_count, payload_offset,
			payload_length, staged)
	if owner_key == OWNER_KEY_WORLD_RUNTIME:
		walk.seen_runtime = true
		return _decode_runtime_payload(bytes, schema_version, primary_count, payload_offset,
			payload_length, staged)
	staged.note_foreign(owner_key, schema_version, primary_count, payload_offset, payload_length)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _decode_directory_payload(bytes: PackedByteArray, schema_version: int,
		primary_count: int, payload_offset: int, payload_length: int,
		staged: SectionRecord) -> SaveHeader.Refusal:
	"""Read D2's `_next_persistent_id:u32 LE`. Schema 1, primary_count 1, exactly four bytes."""
	var wrapper: SaveHeader.Refusal = _owned_wrapper_refusal(OWNER_KEY_ENTITY_DIRECTORY,
		schema_version, primary_count, payload_length, DIRECTORY_PAYLOAD_BYTES)
	if not wrapper.is_ok():
		return wrapper
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(payload_offset):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_SECTION_TRUNCATED, reader.detail())
	var cursor: SaveHeader.Refusal = cursor_refusal(scalar.value)
	if not cursor.is_ok():
		return cursor
	staged.next_persistent_id = scalar.value
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _decode_runtime_payload(bytes: PackedByteArray, schema_version: int,
		primary_count: int, payload_offset: int, payload_length: int,
		staged: SectionRecord) -> SaveHeader.Refusal:
	"""Read the 80-byte WorldRuntime body through the same `decode_into()` every caller uses."""
	var wrapper: SaveHeader.Refusal = _owned_wrapper_refusal(OWNER_KEY_WORLD_RUNTIME,
		schema_version, primary_count, payload_length, BLOCK_BYTES)
	if not wrapper.is_ok():
		return wrapper
	return decode_into(bytes, payload_offset, staged.runtime)


static func _owned_wrapper_refusal(owner_key: String, schema_version: int, primary_count: int,
		payload_length: int, expected_payload: int) -> SaveHeader.Refusal:
	"""The three wrapper rules both owned blocks share: schema 1, one primary row, fixed payload."""
	if schema_version != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_SECTION_OWNER_SCHEMA,
			"'%s' declares schema %d, not %d"
				% [owner_key, schema_version, OWNER_SCHEMA_VERSION])
	if primary_count != OWNER_PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PRIMARY_COUNT,
			"'%s' declares primary_count %d, not %d"
				% [owner_key, primary_count, OWNER_PRIMARY_COUNT])
	if payload_length != expected_payload:
		return SaveHeader.Refusal.new(REFUSE_SECTION_PAYLOAD_LENGTH,
			"'%s' declares %d payload bytes, not %d"
				% [owner_key, payload_length, expected_payload])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
