extends RefCounted
## Decision 1931 (C2.1), P-C2-4 (a): every confirmed underground room's dig is one small packed record, indexed by
## the room's directory row; each quantum keeps its own short-lived per-phase Construction projects (Sites). Rooms
## being dug have a foreman (bounded by the crews, at most MAX_DIGS at once). SettlementSystem advances this
## runtime once per fixed tick after the first entry. Nothing here pays or claims: the foremen's owner calls do.
## Not composed in production yet: C2.3 builds the runtime from the mounted Session and saves it. Until then the
## game never constructs one, so none of these columns is allocated outside tests.

const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## One record per room row; `_init` refuses a directory whose room capacity differs (as Buildings asserts).
const ROOM_CAPACITY: int = 16384
## A dig needs at least one builder and the living population caps at 256 (AGENTS.md), so at most 256 rooms are
## dug at once; queued rooms keep only their record.
const MAX_DIGS: int = 256
const RECORD_NONE: int = 0
const RECORD_QUEUED: int = 1
const RECORD_DIGGING: int = 2
const RECORD_DONE: int = 3
const RECORD_STOPPED: int = 4
const REFUSE_ROOM: StringName = &"ROOM_DIG_ROOM_STALE"
const REFUSE_STATE: StringName = &"ROOM_DIG_RECORD_STATE"
const REFUSE_CAPACITY: StringName = &"ROOM_DIG_CAPACITY"
## The bytes of the packed record per room: generation, state, storage and output container references.
const RECORD_BYTES: int = 4 + 1 + 2 * 4 + 2 * 4

var _directory: Directory = null
var _generation: PackedInt32Array = PackedInt32Array()
var _state: PackedByteArray = PackedByteArray()
var _storage: PackedInt32Array = PackedInt32Array()
var _output: PackedInt32Array = PackedInt32Array()
var _foremen: Array[Foreman] = []


func _init(directory: Directory) -> void:
	"""Allocate one record per possible room row; a mismatched directory leaves every operation refused."""
	_directory = directory if directory != null and directory.capacity_of_kind(Directory.KIND_ROOM) == ROOM_CAPACITY else null
	_generation.resize(ROOM_CAPACITY)
	_state.resize(ROOM_CAPACITY)
	_storage.resize(2 * ROOM_CAPACITY)
	_output.resize(2 * ROOM_CAPACITY)


static func packed_bytes() -> int:
	"""The runtime's packed record columns, in bytes (decision 1931's memory row)."""
	return ROOM_CAPACITY * RECORD_BYTES


func _row(room: Vector2i) -> int:
	"""The room's directory row, or -1 for a stale or foreign reference."""
	if _directory == null or room == NULL_REF or not _directory.is_valid_of_kind(room, Directory.KIND_ROOM): return -1
	var row: int = _directory.get_typed_row(room)
	return row if row >= 0 and row < ROOM_CAPACITY else -1


func order_room(room: Vector2i, storage: Vector2i, output: Vector2i) -> StringName:
	"""Queue a confirmed room for digging with the containers its inputs come from and its spoil goes to."""
	var row: int = _row(room)
	if row < 0 or storage == NULL_REF or output == NULL_REF: return REFUSE_ROOM
	if _state[row] == RECORD_QUEUED or _state[row] == RECORD_DIGGING: return REFUSE_STATE
	_generation[row] = room.y
	_state[row] = RECORD_QUEUED
	_storage[2 * row] = storage.x; _storage[2 * row + 1] = storage.y
	_output[2 * row] = output.x; _output[2 * row + 1] = output.y
	return &""


func start_room(room: Vector2i, owners: Builder.Owners, crew: Array[Builder.Crew]) -> StringName:
	"""Give a queued room its foreman and crew; a refused plan leaves it queued."""
	var row: int = _row(room)
	if row < 0: return REFUSE_ROOM
	if _state[row] != RECORD_QUEUED: return REFUSE_STATE
	if _generation[row] != room.y: return REFUSE_ROOM
	if _foremen.size() >= MAX_DIGS: return REFUSE_CAPACITY
	var foreman: Foreman = Foreman.new()
	var code: StringName = foreman.configure(owners, room, Vector2i(_storage[2 * row], _storage[2 * row + 1]),
		Vector2i(_output[2 * row], _output[2 * row + 1]), crew)
	if code != &"": return code
	_foremen.append(foreman)
	_state[row] = RECORD_DIGGING
	return &""


func advance(tick: int) -> StringName:
	"""One fixed tick of every digging room; the first new refusal is returned for the alert, the rest stop too."""
	var first: StringName = &""
	for foreman: Foreman in _foremen:
		if not foreman.is_running(): continue
		var code: StringName = foreman.advance(tick)
		if code != &"" and first == &"": first = code
		_settle_record(foreman)
	return first


func _settle_record(foreman: Foreman) -> void:
	"""A foreman that finished or stopped this tick leaves its record DONE or STOPPED."""
	if foreman.is_running(): return
	var row: int = _row(foreman.room())
	if row < 0: return
	_state[row] = RECORD_DONE if foreman.state() == Foreman.STATE_DONE else RECORD_STOPPED


func is_running() -> bool:
	"""True while any room is being dug."""
	for foreman: Foreman in _foremen:
		if foreman.is_running(): return true
	return false


func state_of(room: Vector2i) -> int:
	"""The room's record state, RECORD_NONE for an unknown or stale room."""
	var row: int = _row(room)
	return _state[row] if row >= 0 and _generation[row] == room.y else RECORD_NONE


func foreman_of(room: Vector2i) -> Foreman:
	"""The room's foreman while digging or after it stopped, for status; null otherwise."""
	for foreman: Foreman in _foremen:
		if foreman.room() == room: return foreman
	return null


func release_room(room: Vector2i) -> StringName:
	"""Clear a DONE or STOPPED record and drop its foreman, so the room can be ordered again (C3's re-order)."""
	var row: int = _row(room)
	if row < 0 or _generation[row] != room.y: return REFUSE_ROOM
	if _state[row] != RECORD_DONE and _state[row] != RECORD_STOPPED: return REFUSE_STATE
	_state[row] = RECORD_NONE
	for index: int in range(_foremen.size() - 1, -1, -1):
		if _foremen[index].room() == room: _foremen.remove_at(index)
	return &""
