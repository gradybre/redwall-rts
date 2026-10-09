extends RefCounted
## ADR 1229 increment 3: the claw stair motion tables, the successor of the pick-era motion catalog's stair banks
## (`underground_motion_catalog.gd`, which stays source-only). One immutable bank, loaded once from the create-only
## wire `qualified-claw-stair-motion-v1/stair-motion.ugstair`, holds for each source-proved travel row of content 10
## (step back 51, step forward 52, descent 53, ascent 54, half-turn 55) its integer root track and heading per key,
## the deck that supports each source interval and the fixture decks its approved proofs stood on, all in the frame
## of the row's start root. It grants no movement: WorldRoutes proves the decks live and the air clear, and Routes
## samples the root at the fixed ticks of DEC-050's authored paces.

const Pins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const Content := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
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
const REFUSE_SOURCE: StringName = &"STAIR_MOTION_SOURCE"
const REFUSE_FORMAT: StringName = &"STAIR_MOTION_FORMAT"

var _programs: PackedInt32Array = PackedInt32Array()
var _keys: PackedInt32Array = PackedInt32Array()
var _decks: PackedInt32Array = PackedInt32Array()
var _digest: PackedByteArray = PackedByteArray()
var _loaded: bool = false


func load_file(path: String, expected_sha: String) -> StringName:
	"""Read and validate the whole pinned wire once; a refusal leaves the bank empty."""
	if _loaded or expected_sha != Pins.WIRE_SHA: return REFUSE_SOURCE
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != Pins.WIRE_BYTES: return REFUSE_SOURCE
	var bytes: PackedByteArray = file.get_buffer(Pins.WIRE_BYTES)
	file.close()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != Pins.WIRE_SHA: return REFUSE_SOURCE
	var code: StringName = _decode(bytes)
	if code == &"": code = _validate()
	if code != &"":
		_clear()
		return code
	_loaded = true
	return &""


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
	_programs.clear()
	_keys.clear()
	_decks.clear()
	_digest.clear()


func _p(program: int, field: int) -> int:
	"""One program word; callers bound the program."""
	return _programs[program * PROGRAM_FIELDS + field]


func is_loaded() -> bool:
	"""True once the pinned wire is admitted."""
	return _loaded


func packed_memory_bytes() -> int:
	"""Every retained packed column."""
	return 4 * (_programs.size() + _keys.size() + _decks.size()) + _digest.size()


func program_of(row: int) -> int:
	"""The program index of a content-10 source-proved travel row, or -1."""
	if not _loaded: return -1
	for program: int in PROGRAMS:
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
	"""The claw v2 image clip that presents the motion."""
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
