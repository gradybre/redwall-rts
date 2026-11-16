extends RefCounted
## ADR 1229 increment 3: the claw stair motion tables, the successor of the pick-era motion catalog's stair banks
## (`underground_motion_catalog.gd`, which stays source-only). One immutable bank, loaded once from the create-only
## wire `qualified-claw-stair-motion-v1/stair-motion.ugstair`, holds for each source-proved travel row of content 10
## (step back 51, step forward 52, descent 53, ascent 54, half-turn 55) its integer root track and heading per key,
## the deck that supports each source interval and the fixture decks its approved proofs stood on, all in the frame
## of the row's start root. It grants no movement: WorldRoutes proves the decks live and the air clear, and Routes
## samples the root at the fixed ticks of DEC-050's authored paces.
## Decision 1972: a second, optional bank, the stair-carry tables (`qualified-stair-carry-motion-v1/`, decision 1981:
## content 12's rooted rows 71-84, the same wire format bound to content 12's profile wire), is appended after the
## claw bank by `load_carry_file`. Its programs follow the claw programs, its keys and decks follow theirs, and every
## reader below serves both. The claw tables stay bound to content 10's profile wire: content 12 carries rows 51-55
## byte for byte, and the binding is checked against the published accessor, not the live bank.

const Pins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const Content := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const CarryPins := preload("res://data/underground/mole-worker/qualified-stair-carry-motion-v1/catalog_source.gd")
const CarryContent := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const PROGRAM_FIELDS: int = 12
const KEY_FIELDS: int = 5
const DECK_FIELDS: int = 6
const HEADER_BYTES: int = 64
const P_ROW: int = 0
const P_ROOTED: int = 1
const P_KEYS: int = 2
const P_FIRST_KEY: int = 3
const P_DECKS: int = 4
const P_FIRST_DECK: int = 5
const P_END: int = 6
const P_START_YAW: int = 9
const P_END_YAW: int = 10
const P_CLIP: int = 11
const K_HEADING: int = 3
const K_DECK: int = 4
## The published wire's census (its generated `catalog_source.gd`, checked at load).
const PROGRAMS: int = 5
const KEYS: int = 457
const DECKS: int = 7
const RESERVED_BYTES: int = 4 * (PROGRAM_FIELDS * PROGRAMS + KEY_FIELDS * KEYS + DECK_FIELDS * DECKS) + 32
## Decision 1972: the stair-carry wire's census (its generated `catalog_source.gd`, checked at load).
const CARRY_PROGRAMS: int = 14
const CARRY_KEYS: int = 1634
const CARRY_DECKS: int = 18
## Its retained columns (its profile digest is checked at load and not kept): 33,784 B.
const CARRY_RESERVED_BYTES: int = 4 * PROGRAM_FIELDS * CARRY_PROGRAMS + 4 * KEY_FIELDS * CARRY_KEYS + 4 * DECK_FIELDS * CARRY_DECKS
const REFUSE_SOURCE: StringName = &"STAIR_MOTION_SOURCE"
const REFUSE_FORMAT: StringName = &"STAIR_MOTION_FORMAT"

var _programs: PackedInt32Array = PackedInt32Array()
var _keys: PackedInt32Array = PackedInt32Array()
var _decks: PackedInt32Array = PackedInt32Array()
var _digest: PackedByteArray = PackedByteArray()
var _loaded: bool = false
var _carry_loaded: bool = false
var _program_count: int = 0


func load_file(path: String, expected_sha: String) -> StringName:
	"""Read and validate the whole pinned wire once; a refusal leaves the bank empty."""
	if _loaded or expected_sha != Pins.WIRE_SHA: return REFUSE_SOURCE
	var bytes: PackedByteArray = _read_pinned(path, Pins.WIRE_BYTES, Pins.WIRE_SHA)
	if bytes.is_empty(): return REFUSE_SOURCE
	var code: StringName = _decode(bytes)
	if code == &"": code = _validate()
	if code != &"":
		_clear()
		return code
	_loaded = true
	_program_count = PROGRAMS
	return &""


func load_carry_file(path: String, expected_sha: String) -> StringName:
	"""Decision 1972: append the pinned stair-carry wire after the loaded claw bank; a refusal leaves the claw bank
	exactly as it was."""
	if not _loaded or _carry_loaded or expected_sha != CarryPins.WIRE_SHA: return REFUSE_SOURCE
	var bytes: PackedByteArray = _read_pinned(path, CarryPins.WIRE_BYTES, CarryPins.WIRE_SHA)
	if bytes.is_empty(): return REFUSE_SOURCE
	if bytes.slice(0, 8).get_string_from_ascii() != "UGSTRM01" or bytes.decode_u32(8) != 1 \
			or bytes.decode_s64(12) != CarryPins.CONTENT_REVISION or bytes.decode_u32(20) != CARRY_PROGRAMS \
			or bytes.decode_u32(24) != CARRY_KEYS or bytes.decode_u32(28) != CARRY_DECKS \
			or CarryPins.PROGRAM_COUNT != CARRY_PROGRAMS or CarryPins.KEY_COUNT != CARRY_KEYS \
			or CarryPins.DECK_COUNT != CARRY_DECKS:
		return REFUSE_FORMAT
	if bytes.slice(32, 64).hex_encode() != CarryContent.WIRE_SHA: return REFUSE_SOURCE
	var code: StringName = _append_carry(bytes)
	if code != &"": return code
	_carry_loaded = true
	_program_count = PROGRAMS + CARRY_PROGRAMS
	return &""


static func _read_pinned(path: String, size: int, sha: String) -> PackedByteArray:
	"""The whole file when it is exactly the pinned size and digest, else empty."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != size: return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(size)
	file.close()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return bytes if hashing.finish().hex_encode() == sha else PackedByteArray()


func _append_carry(bytes: PackedByteArray) -> StringName:
	"""Decode the carry tables after the claw tables, rebasing each program's first key and deck; a refusal cuts the
	columns back to the claw bank."""
	var programs: PackedInt32Array = PackedInt32Array()
	programs.resize(PROGRAM_FIELDS * CARRY_PROGRAMS)
	var keys: PackedInt32Array = PackedInt32Array()
	keys.resize(KEY_FIELDS * CARRY_KEYS)
	var decks: PackedInt32Array = PackedInt32Array()
	decks.resize(DECK_FIELDS * CARRY_DECKS)
	var at: int = _read(bytes, _read(bytes, _read(bytes, HEADER_BYTES, programs), keys), decks)
	if bytes.slice(at).get_string_from_ascii() != "UGSTEND1": return REFUSE_FORMAT
	for program: int in CARRY_PROGRAMS:
		programs[program * PROGRAM_FIELDS + P_FIRST_KEY] += KEYS
		programs[program * PROGRAM_FIELDS + P_FIRST_DECK] += DECKS
	_programs.append_array(programs)
	_keys.append_array(keys)
	_decks.append_array(decks)
	var code: StringName = _validate_carry()
	if code != &"":
		_programs.resize(PROGRAM_FIELDS * PROGRAMS)
		_keys.resize(KEY_FIELDS * KEYS)
		_decks.resize(DECK_FIELDS * DECKS)
	return code


func _validate_carry() -> StringName:
	"""The carry programs name rows 71-84 in order, are rooted, and keep one supporting deck per key in their span."""
	var key: int = KEYS
	var deck: int = DECKS
	for index: int in CARRY_PROGRAMS:
		var program: int = PROGRAMS + index
		if _p(program, P_ROW) != CarryContent.STAIR_EMPTY_FLOOR_ROWS[0] + index or _p(program, P_ROOTED) != 1 \
				or _p(program, P_FIRST_KEY) != key or _p(program, P_FIRST_DECK) != deck \
				or _p(program, P_KEYS) < 2 or _p(program, P_DECKS) < 1:
			return REFUSE_FORMAT
		for ordinal: int in _p(program, P_KEYS):
			var support: int = _keys[(key + ordinal) * KEY_FIELDS + K_DECK]
			if support < 0 or support >= _p(program, P_DECKS): return REFUSE_FORMAT
		key += _p(program, P_KEYS)
		deck += _p(program, P_DECKS)
	return &"" if key == KEYS + CARRY_KEYS and deck == DECKS + CARRY_DECKS else REFUSE_FORMAT


func _decode(bytes: PackedByteArray) -> StringName:
	"""Fixed header, the content-10 profile wire digest, then three field-major-free row tables and the footer."""
	if bytes.slice(0, 8).get_string_from_ascii() != "UGSTRM01" or bytes.decode_u32(8) != 1 \
			or bytes.decode_s64(12) != Pins.CONTENT_REVISION or bytes.decode_u32(20) != PROGRAMS \
			or bytes.decode_u32(24) != KEYS or bytes.decode_u32(28) != DECKS or Pins.PROGRAM_COUNT != PROGRAMS \
			or Pins.KEY_COUNT != KEYS or Pins.DECK_COUNT != DECKS:
		return REFUSE_FORMAT
	_allocate()
	for index: int in 32:
		_digest[index] = bytes[32 + index]
	if _digest.hex_encode() != Content.WIRE_SHA: return REFUSE_SOURCE
	var at: int = HEADER_BYTES
	at = _read(bytes, at, _programs)
	at = _read(bytes, at, _keys)
	at = _read(bytes, at, _decks)
	return &"" if bytes.slice(at).get_string_from_ascii() == "UGSTEND1" else REFUSE_FORMAT


func _allocate() -> void:
	"""The fixed census of the pinned wire; nothing grows after this."""
	_programs.resize(PROGRAM_FIELDS * PROGRAMS)
	_keys.resize(KEY_FIELDS * KEYS)
	_decks.resize(DECK_FIELDS * DECKS)
	_digest.resize(32)


static func _read(bytes: PackedByteArray, at: int, out: PackedInt32Array) -> int:
	"""Decode one already sized column; returns the next offset."""
	for index: int in out.size():
		out[index] = bytes.decode_s32(at + 4 * index)
	return at + 4 * out.size()


func _validate() -> StringName:
	"""Contiguous spans, the published row ids, and one supporting deck per key inside its program."""
	var key: int = 0
	var deck: int = 0
	var rows: PackedInt32Array = PackedInt32Array([Content.CLAW_STEP_BACK_ROW, Content.CLAW_STEP_FORWARD_ROW,
		Content.CLAW_DESCENT_ROW, Content.CLAW_ASCENT_ROW, Content.CLAW_TURN_ROW])
	for program: int in PROGRAMS:
		if _p(program, P_ROW) != rows[program] or _p(program, P_FIRST_KEY) != key \
				or _p(program, P_FIRST_DECK) != deck or _p(program, P_KEYS) < 2 or _p(program, P_DECKS) < 1:
			return REFUSE_FORMAT
		for ordinal: int in _p(program, P_KEYS):
			var support: int = _keys[(key + ordinal) * KEY_FIELDS + K_DECK]
			if support < 0 or support >= _p(program, P_DECKS): return REFUSE_FORMAT
		key += _p(program, P_KEYS)
		deck += _p(program, P_DECKS)
	return &"" if key == KEYS and deck == DECKS else REFUSE_FORMAT


func _clear() -> void:
	"""A refused load keeps nothing."""
	_program_count = 0
	_programs.clear()
	_keys.clear()
	_decks.clear()
	_digest.clear()


func _p(program: int, field: int) -> int:
	"""One program word; callers bound the program."""
	return _programs[program * PROGRAM_FIELDS + field]


func is_loaded() -> bool:
	"""True once the pinned claw wire is admitted."""
	return _loaded


func is_carry_loaded() -> bool:
	"""Decision 1972: true once the stair-carry wire is appended too."""
	return _carry_loaded


func packed_memory_bytes() -> int:
	"""Every retained packed column."""
	return 4 * (_programs.size() + _keys.size() + _decks.size()) + _digest.size()


func program_of(row: int) -> int:
	"""The program index of a source-proved travel row (content 10's 51-55, and content 12's 71-84 once the carry
	tables are appended), or -1."""
	if not _loaded: return -1
	for program: int in _program_count:
		if _p(program, P_ROW) == row: return program
	return -1


func rooted(program: int) -> bool:
	"""True for the stair gaits and the half-turn, which follow an authored root track; false for the short steps."""
	return _p(program, P_ROOTED) == 1


func key_count(program: int) -> int:
	"""Keys of the program's clip (intervals + 1)."""
	return _p(program, P_KEYS)


func end_of(program: int) -> Vector3i:
	"""The root displacement from the start to the end of the motion."""
	return Vector3i(_p(program, P_END), _p(program, P_END + 1), _p(program, P_END + 2))


func start_yaw(program: int) -> int:
	"""The heading at the first key."""
	return _p(program, P_START_YAW)


func end_yaw(program: int) -> int:
	"""The heading at the last key."""
	return _p(program, P_END_YAW)


func clip_of(program: int) -> int:
	"""The clip that presents the motion, in its row's own image (the claw v2 image, or a stair carry image)."""
	return _p(program, P_CLIP)


func root_at(program: int, key: int) -> Vector3i:
	"""The integer root of one key relative to the start root; keys clamp to the program."""
	var at: int = (_p(program, P_FIRST_KEY) + clampi(key, 0, _p(program, P_KEYS) - 1)) * KEY_FIELDS
	return Vector3i(_keys[at], _keys[at + 1], _keys[at + 2])


func heading_at(program: int, key: int) -> int:
	"""The integer heading of one key (the half-turn's table; the gaits' constant heading)."""
	var at: int = (_p(program, P_FIRST_KEY) + clampi(key, 0, _p(program, P_KEYS) - 1)) * KEY_FIELDS
	return _keys[at + K_HEADING]


func deck_count(program: int) -> int:
	"""Fixture decks the program's proofs stood on."""
	return _p(program, P_DECKS)


func deck_into(program: int, ordinal: int, origin: Vector3i, out: PackedInt32Array) -> bool:
	"""One fixture deck translated to a start root; false for an absent ordinal or a mis-sized packet."""
	if out.size() != 6 or ordinal < 0 or ordinal >= _p(program, P_DECKS): return false
	var at: int = (_p(program, P_FIRST_DECK) + ordinal) * DECK_FIELDS
	for axis: int in 6:
		out[axis] = _decks[at + axis] + origin[axis % 3]
	return true
