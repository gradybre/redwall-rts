extends RefCounted
## ADR1218 (ADR1197 G10): the canonical wire of the first-entry progress record. Brendan chose to save the entry's
## progress explicitly: the runtime step, the foreman's planned tasks and cursor, the installer's plan and cursor
## and each hauler's queue and cursor are written, and a load restores them exactly. This module holds only the
## framing and the scalar codec; every owner writes and validates its own fields. Little-endian, no float, no
## Variant encoding, and a decoded record must re-encode to the very same bytes (ENTRY_SAVE_NONCANONICAL).

const Routes := preload("res://scripts/core/underground_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MAGIC: int = 0x50544E45 # "ENTP"
## ADR1227: 2 since a successful start clears the runtime's earlier refusal. ADR1229: 3 since the work area publishes
## nineteen endpoints (the descent's eight more cut stations) and the plan runs to T6. An earlier record is refused
## with ENTRY_SAVE_VERSION (no migration before 1.0, DEC-055 item 1).
const VERSION: int = 3
const KIND_RUNTIME: int = 1
const KIND_FOREMAN: int = 2
const CODE_BYTES: int = 64 # A refusal code, ASCII, zero-padded.
const HEADER_BYTES: int = 12
## Wire sizes, one per block, checked against the encoder by test_underground_entry_progress.gd and charged by
## tools/underground_current_census.py at the planned task bound.
const CREW_BYTES: int = 40
const TASK_BYTES: int = 52
const LEG_BYTES: int = 20
const QUOTE_LINE_BYTES: int = 12
const RUNTIME_FIXED_BYTES: int = 130
const FOREMAN_FIXED_BYTES: int = 232
const INSTALLER_FIXED_BYTES: int = 165
const HAULER_FIXED_BYTES: int = 88
## ADR1229: L0's twelve phases, T0's six, the descent's twenty-four and eight installations are fifty steps.
const MAX_TASKS: int = 64
const MAX_ENDPOINTS: int = 19 # ADR1229: the work area's endpoints (WorkArea.ENDPOINTS).
const MAX_QUEUE: int = 8
const MAX_LEGS: int = 3
const MAX_QUOTE_LINES: int = 4
## One haul at most is live: the foreman's (STAGE_HAUL) or its installation's, never both.
const MAX_WIRE_BYTES: int = HEADER_BYTES + RUNTIME_FIXED_BYTES + MAX_ENDPOINTS * 8 + CREW_BYTES + FOREMAN_FIXED_BYTES \
	+ MAX_TASKS * TASK_BYTES + INSTALLER_FIXED_BYTES + MAX_QUOTE_LINES * QUOTE_LINE_BYTES \
	+ HAULER_FIXED_BYTES + MAX_QUEUE * 4 + MAX_LEGS * LEG_BYTES
const REFUSE_VERSION: StringName = &"ENTRY_SAVE_VERSION"
const REFUSE_SHAPE: StringName = &"ENTRY_SAVE_SHAPE"
const REFUSE_NONCANONICAL: StringName = &"ENTRY_SAVE_NONCANONICAL"
const REFUSE_TARGET: StringName = &"ENTRY_SAVE_TARGET"
const REFUSE_OWNERS: StringName = &"ENTRY_SAVE_OWNERS"
const REFUSE_CONTENT: StringName = &"ENTRY_SAVE_CONTENT"
const REFUSE_BUSY: StringName = &"ENTRY_SAVE_BUSY"
const REFUSE_CREW: StringName = &"ENTRY_SAVE_CREW"
const REFUSE_PLACEMENT: StringName = &"ENTRY_SAVE_PLACEMENT"
const REFUSE_SITE: StringName = &"ENTRY_SAVE_SITE"
const REFUSE_LOCATION: StringName = &"ENTRY_SAVE_LOCATION"
const REFUSE_JOB: StringName = &"ENTRY_SAVE_JOB"
const REFUSE_PROJECT: StringName = &"ENTRY_SAVE_PROJECT"
const REFUSE_ACTOR: StringName = &"ENTRY_SAVE_ACTOR"


class Writer extends RefCounted:
	## Appends fixed-width little-endian scalars; `overflow` marks a value the wire cannot carry exactly.
	var bytes: PackedByteArray = PackedByteArray()
	var overflow: bool = false

	func i32(value: int) -> void:
		"""One signed 32-bit scalar; a wider value is an overflow, never a truncation."""
		if value < -2147483648 or value > 2147483647: overflow = true
		var at: int = bytes.size()
		bytes.resize(at + 4)
		bytes.encode_s32(at, value)

	func i64(value: int) -> void:
		"""One signed 64-bit scalar."""
		var at: int = bytes.size()
		bytes.resize(at + 8)
		bytes.encode_s64(at, value)

	func ref(value: Vector2i) -> void:
		"""A (slot, generation) handle."""
		i32(value.x)
		i32(value.y)

	func flag(value: bool) -> void:
		"""One byte, 0 or 1."""
		bytes.append(1 if value else 0)

	func code(value: StringName) -> void:
		"""A refusal code as printable ASCII, zero-padded to CODE_BYTES."""
		var raw: PackedByteArray = String(value).to_ascii_buffer()
		if raw.size() > CODE_BYTES: overflow = true
		raw.resize(CODE_BYTES)
		bytes.append_array(raw)


class Reader extends RefCounted:
	## Reads the same scalars; any short read or out-of-range value sets `bad` and yields a harmless default.
	var bytes: PackedByteArray = PackedByteArray()
	var at: int = 0
	var bad: bool = false

	func _take(width: int) -> bool:
		"""Reserve the next `width` bytes, or mark the record truncated."""
		if bad or at + width > bytes.size():
			bad = true
			return false
		at += width
		return true

	func i32() -> int:
		"""One signed 32-bit scalar."""
		return bytes.decode_s32(at - 4) if _take(4) else 0

	func i64() -> int:
		"""One signed 64-bit scalar."""
		return bytes.decode_s64(at - 8) if _take(8) else 0

	func ranged(low: int, high: int) -> int:
		"""A 32-bit scalar that must lie in [low, high]."""
		var value: int = i32()
		if value < low or value > high: bad = true
		return clampi(value, low, high)

	func ref() -> Vector2i:
		"""A handle; the null handle has exactly one spelling, (-1, 0)."""
		var value: Vector2i = Vector2i(i32(), i32())
		if value.x < -1 or (value.x == -1 and value.y != 0): bad = true
		return value if not bad else NULL_REF

	func flag() -> bool:
		"""One byte that must be 0 or 1."""
		if not _take(1): return false
		if bytes[at - 1] > 1: bad = true
		return bytes[at - 1] == 1

	func code() -> StringName:
		"""Printable ASCII up to the first zero, then only zero padding."""
		if not _take(CODE_BYTES): return &""
		var length: int = CODE_BYTES
		for index: int in CODE_BYTES:
			var byte: int = bytes[at - CODE_BYTES + index]
			if length < CODE_BYTES:
				if byte != 0: bad = true
			elif byte == 0: length = index
			elif byte < 0x21 or byte > 0x7E: bad = true
		return StringName(bytes.slice(at - CODE_BYTES, at - CODE_BYTES + length).get_string_from_ascii())


static func begin(kind: int) -> Writer:
	"""A record header: magic, version and the block kind it carries."""
	var w: Writer = Writer.new()
	w.i32(MAGIC)
	w.i32(VERSION)
	w.i32(kind)
	return w


static func open(bytes: PackedByteArray, kind: int, out: Reader) -> StringName:
	"""Check the header of a record of the expected kind; the reader is left on the first block byte."""
	out.bytes = bytes
	out.at = 0
	out.bad = false
	if bytes.size() < HEADER_BYTES or bytes.size() > MAX_WIRE_BYTES: return REFUSE_SHAPE
	if out.i32() != MAGIC or out.i32() != VERSION or out.i32() != kind: return REFUSE_VERSION
	return &""


static func close(reader: Reader) -> StringName:
	"""The whole record was consumed and every scalar was in range."""
	return &"" if not reader.bad and reader.at == reader.bytes.size() else REFUSE_SHAPE


static func finish(w: Writer) -> PackedByteArray:
	"""The finished record, or empty when a value overflowed its field (the caller refuses the save)."""
	return PackedByteArray() if w.overflow or w.bytes.size() > MAX_WIRE_BYTES else w.bytes


static func job_ref(jobs: RefCounted, slot: int, in_use: bool) -> Vector2i:
	"""The Directory handle of a Job slot the cursor still reads, or null for a slot it will overwrite."""
	return jobs.ref_of(slot) if in_use and slot >= 0 else NULL_REF


static func job_refusal(jobs: RefCounted, slot: int, saved: Vector2i, in_use: bool) -> StringName:
	"""A Job the cursor still reads must be live in the restored Jobs with the same generation."""
	if not in_use: return &"" if saved == NULL_REF else REFUSE_SHAPE
	return &"" if slot >= 0 and saved != NULL_REF and jobs.ref_of(slot) == saved else REFUSE_JOB


static func location_refusal(locations: RefCounted, location: Vector2i, nullable: bool) -> StringName:
	"""A Location the cursor will still read must be live in the restored Locations."""
	if location == NULL_REF: return &"" if nullable else REFUSE_LOCATION
	return &"" if locations.is_live_location(location) else REFUSE_LOCATION


static func busy_refusal(owners: RefCounted) -> StringName:
	"""Like the Placement capture, a save is taken only at quiescence: no synchronous route, Location or graph
	operation of the borrowed owners may be open."""
	if owners.routes._token != 0 or owners.locations._token != 0 or owners.binding._route_token != 0:
		return REFUSE_BUSY
	return &""


static func actor_refusal(owners: RefCounted, worker: Vector2i, job: Vector2i) -> StringName:
	"""The worker the innermost dispatcher is driving must be a committed route actor under that very Job."""
	var actor: Routes.Actor = Routes.Actor.new()
	if owners.routes.read_actor_into(worker, actor) != &"" or actor.job != job: return REFUSE_ACTOR
	return &""
