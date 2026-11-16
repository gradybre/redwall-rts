extends RefCounted
## Decision 1936, P-1936-4 (a): the canonical wire of the room-dig progress record, section 6 owner
## `underground_room_progress`, after ADR1218/1221's convention. This module holds the framing and the bounds; the
## runtime, each foreman, each builder (with its walk and cube plan) and each hauler write and check their own
## fields, with ADR1218's scalar Writer and Reader (the entry hauler's own codec is reused unchanged). Little-endian,
## no float, no Variant; a decoded record must re-encode to the very same bytes (ROOM_SAVE_NONCANONICAL). What is
## re-derived on load (the footprints, swept again from the saved plans; the row extents; the per-tick block flags)
## is never written.

const EntryProgress := preload("res://scripts/core/underground_entry_progress.gd")
const Claim := preload("res://scripts/core/underground_room_claim.gd")
const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const MAGIC: int = 0x50444D52 # "RMDP"
## Decision 1991: 2 adds each record row's named crew and release-once-out flag. A version-1 record is refused
## (ROOM_SAVE_VERSION), as DEC-055 item 1 refuses a save from another revision before 1.0 (P-1972-3's precedent).
const VERSION: int = 2
const KIND_RUNTIME: int = 1
const HEADER_BYTES: int = 12
const CODE_BYTES: int = EntryProgress.CODE_BYTES
## Wire sizes, checked against the encoder by test_underground_room_progress.gd and charged by
## tools/underground_current_census.py.
## Runtime: the contacts' access (8) and retreat row (4), the record-row and foreman counts (4 each).
const RUNTIME_FIXED_BYTES: int = 20
## One record row in use: its row, generation and state, its three container references, and (decision 1991) its
## named crew (four resident references) and its release-once-out flag.
const ROW_BYTES: int = 36 + 4 * 8 + 1
## One foreman: its record row and room, state, three codes, ledgers and latch, epoch, context (content, two rows,
## three containers) and its order and builder counts.
const FOREMAN_FIXED_BYTES: int = 4 + 8 + 4 + 3 * CODE_BYTES + 4 + 1 + 8 + 8 + 4 + 8 + 4 + 4 + 24 + 4 + 4
## One Site of a running dig's order: its row and its dispatch mark (its key is read again from Sites).
const SITE_BYTES: int = 8
## One builder without its lists and hauler block: the foreman's blocked epoch for it (8), the crew (24), the cursor
## (stage, stall, code, failed stage, index, Site, operation, Job slot and handle, station, work row, standing point,
## plan start and storage: 144), the leg cursor, flags and ledgers (30), the haul endpoints and ledgers (32), two
## flags (2), the walk (17), the standing body (24) and the hauler flag (1).
const BUILDER_FIXED_BYTES: int = 8 + 24 + (4 + 4 + CODE_BYTES + 4 + 4 + 8 + 4 + 4 + 8 + 8 + 4 + 8 + 8 + 8) \
	+ (4 + 4 + 1 + 1 + 4 + 4 + 4 + 8) + (8 + 8 + 4 + 4 + 8) + 2 + (4 + 1 + 12) + 24 + 1
## A count-prefixed leg list: target (slot, generation) and row per leg, at most Claim.MAX_LEGS.
const LEG_LIST_BYTES: int = 4 + Claim.MAX_LEGS * 12
## A count-prefixed trip list: (edge slot, generation, row) per searched edge.
const TRIP_LIST_BYTES: int = 4 + Claim.MAX_TRIP_EDGES * 12
## The stands (four scalars), the carried rows (two) and the queue, each count-prefixed.
const HAUL_PLAN_BYTES: int = (4 + 4 * 4) + (4 + 2 * 4) + (4 + EntryProgress.MAX_QUEUE * 4)
## The entry hauler's own block (ADR1218), at its bounds.
const HAULER_BYTES: int = EntryProgress.HAULER_FIXED_BYTES + EntryProgress.MAX_QUEUE * 4 \
	+ EntryProgress.MAX_LEGS * EntryProgress.LEG_BYTES
## Four leg lists: the current legs and the plan's way back, way there and walk to the storage.
const BUILDER_BYTES: int = BUILDER_FIXED_BYTES + 4 * LEG_LIST_BYTES + TRIP_LIST_BYTES + HAUL_PLAN_BYTES + HAULER_BYTES
## Kept records, the Sites of running digs, and builders (the living population, 256).
const MAX_KEPT: int = 512
const MAX_SITES: int = 73909
const MAX_BUILDERS: int = 256
const MAX_WIRE_BYTES: int = HEADER_BYTES + RUNTIME_FIXED_BYTES + MAX_KEPT * (ROW_BYTES + FOREMAN_FIXED_BYTES) \
	+ MAX_SITES * SITE_BYTES + MAX_BUILDERS * BUILDER_BYTES
const REFUSE_VERSION: StringName = &"ROOM_SAVE_VERSION"
const REFUSE_SHAPE: StringName = &"ROOM_SAVE_SHAPE"
const REFUSE_NONCANONICAL: StringName = &"ROOM_SAVE_NONCANONICAL"
const REFUSE_TARGET: StringName = &"ROOM_SAVE_TARGET"
const REFUSE_OWNERS: StringName = &"ROOM_SAVE_OWNERS"
const REFUSE_CONTACTS: StringName = &"ROOM_SAVE_CONTACTS"
const REFUSE_BUSY: StringName = &"ROOM_SAVE_BUSY"


class Checker extends EntryProgress.Writer:
	## Decision 1937 (P-1937-1 C): the re-encode a restore must match, compared scalar by scalar against the record
	## itself instead of written into a second image.
	var expect: PackedByteArray = PackedByteArray()
	var at: int = 0
	var differs: bool = false

	func i32(value: int) -> void:
		"""One signed 32-bit scalar, compared in place."""
		if value < -2147483648 or value > 2147483647: overflow = true
		differs = differs or at + 4 > expect.size() or expect.decode_s32(at) != value
		at += 4

	func i64(value: int) -> void:
		"""One signed 64-bit scalar, compared in place."""
		differs = differs or at + 8 > expect.size() or expect.decode_s64(at) != value
		at += 8

	func flag(value: bool) -> void:
		"""One byte, 0 or 1, compared in place."""
		differs = differs or at >= expect.size() or expect[at] != (1 if value else 0)
		at += 1

	func code(value: StringName) -> void:
		"""A zero-padded ASCII code, compared byte by byte."""
		var raw: PackedByteArray = String(value).to_ascii_buffer()
		if raw.size() > CODE_BYTES: overflow = true
		for index: int in CODE_BYTES:
			var byte: int = raw[index] if index < raw.size() else 0
			differs = differs or at + index >= expect.size() or expect[at + index] != byte
		at += CODE_BYTES

	func matches() -> bool:
		"""Every scalar equal, and the whole record consumed."""
		return not differs and not overflow and at == expect.size()


static func begin(out: PackedByteArray) -> EntryProgress.Writer:
	"""A record header written straight into the caller's buffer (one image, P-1937-1 C): magic, version, kind."""
	var w: EntryProgress.Writer = EntryProgress.Writer.new()
	out.clear()
	w.bytes = out
	_header(w)
	return w


static func check(bytes: PackedByteArray) -> Checker:
	"""A checker over a decoded record, past its header."""
	var c: Checker = Checker.new()
	c.expect = bytes
	_header(c)
	return c


static func _header(w: EntryProgress.Writer) -> void:
	"""Magic, version and kind."""
	w.i32(MAGIC)
	w.i32(VERSION)
	w.i32(KIND_RUNTIME)


static func open(bytes: PackedByteArray, out: EntryProgress.Reader) -> StringName:
	"""Check the header; the reader is left on the first block byte."""
	out.bytes = bytes
	out.at = 0
	out.bad = false
	if bytes.size() < HEADER_BYTES or bytes.size() > MAX_WIRE_BYTES: return REFUSE_SHAPE
	if out.i32() != MAGIC or out.i32() != VERSION or out.i32() != KIND_RUNTIME: return REFUSE_VERSION
	return &""


static func close(reader: EntryProgress.Reader) -> StringName:
	"""The whole record was consumed and every scalar was in range."""
	return &"" if not reader.bad and reader.at == reader.bytes.size() else REFUSE_SHAPE


static func finish(w: EntryProgress.Writer) -> bool:
	"""The record in the caller's buffer is whole; one that overflowed a field or the bound is emptied."""
	if not w.overflow and w.bytes.size() <= MAX_WIRE_BYTES: return true
	w.bytes.clear()
	return false


static func write_list(w: EntryProgress.Writer, values: PackedInt32Array) -> void:
	"""A count-prefixed list of 32-bit scalars."""
	w.i32(values.size())
	for value: int in values:
		w.i32(value)


static func read_list(r: EntryProgress.Reader, limit: int, out: PackedInt32Array) -> void:
	"""A count-prefixed list of at most `limit` scalars."""
	out.clear()
	for index: int in r.ranged(0, limit):
		out.append(r.i32())


static func write_legs(w: EntryProgress.Writer, legs: PackedInt32Array, profiles: PackedInt32Array) -> void:
	"""A count-prefixed leg list: each leg's target (slot, generation) and row."""
	w.i32(profiles.size())
	for leg: int in profiles.size():
		w.i32(legs[2 * leg])
		w.i32(legs[2 * leg + 1])
		w.i32(profiles[leg])


static func read_legs(r: EntryProgress.Reader, legs: PackedInt32Array, profiles: PackedInt32Array) -> void:
	"""The same leg list."""
	legs.clear()
	profiles.clear()
	for leg: int in r.ranged(0, Claim.MAX_LEGS):
		legs.append(r.i32())
		legs.append(r.i32())
		profiles.append(r.i32())


static func write_box(w: EntryProgress.Writer, box: PackedInt32Array) -> void:
	"""Six scalars of one box."""
	for axis: int in 6:
		w.i32(box[axis] if box.size() == 6 else 0)


static func read_box(r: EntryProgress.Reader, out: PackedInt32Array) -> void:
	"""Six scalars of one box, written in place."""
	out.resize(6)
	for axis: int in 6:
		out[axis] = r.i32()
