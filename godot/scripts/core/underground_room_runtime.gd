extends RefCounted
## Decision 1933 (C2.1), P-C2-4 (a): every confirmed underground room's dig is one small packed record, indexed by
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
const REFUSE_CREW_BUSY: StringName = &"ROOM_DIG_CREW_BUSY"
## The bytes of the packed record per room: generation, state, storage and output container references.
const RECORD_BYTES: int = 4 + 1 + 2 * 4 + 2 * 4

var _directory: Directory = null
var _generation: PackedInt32Array = PackedInt32Array()
var _state: PackedByteArray = PackedByteArray()
var _storage: PackedInt32Array = PackedInt32Array()
var _output: PackedInt32Array = PackedInt32Array()
var _foremen: Array[Foreman] = [] # Running ones, and stopped or done ones until their record is released.
var _foreman_rows: PackedInt32Array = PackedInt32Array() # The record row of each foreman, in step with `_foremen`.
var _refusals: Array[StringName] = [] # This tick's new refusals, one per room that stopped.


func _init(directory: Directory) -> void:
	"""Allocate one record per possible room row; a mismatched directory leaves every operation refused."""
	_directory = directory if directory != null and directory.capacity_of_kind(Directory.KIND_ROOM) == ROOM_CAPACITY else null
	_generation.resize(ROOM_CAPACITY)
	_state.resize(ROOM_CAPACITY)
	_storage.resize(2 * ROOM_CAPACITY)
	_output.resize(2 * ROOM_CAPACITY)


static func packed_bytes() -> int:
	"""The runtime's packed record columns, in bytes (decision 1933's memory row)."""
	return ROOM_CAPACITY * RECORD_BYTES


func _row(room: Vector2i) -> int:
	"""The room's directory row, or -1 for a stale or foreign reference."""
	if _directory == null or room == NULL_REF or not _directory.is_valid_of_kind(room, Directory.KIND_ROOM): return -1
	var row: int = _directory.get_typed_row(room)
	return row if row >= 0 and row < ROOM_CAPACITY else -1


func order_room(room: Vector2i, storage: Vector2i, output: Vector2i) -> StringName:
	"""Queue a confirmed room for digging with the containers its inputs come from and its spoil goes to. A record of
	the same room must be released first; one left by a deleted room on a reused row is replaced."""
	var row: int = _row(room)
	if row < 0 or storage == NULL_REF or output == NULL_REF: return REFUSE_ROOM
	if (_generation[row] == room.y and _state[row] != RECORD_NONE) or _digging(row): return REFUSE_STATE
	_drop_foremen(row)
	_generation[row] = room.y
	_state[row] = RECORD_QUEUED
	_storage[2 * row] = storage.x; _storage[2 * row + 1] = storage.y
	_output[2 * row] = output.x; _output[2 * row + 1] = output.y
	return &""


func start_room(room: Vector2i, owners: Builder.Owners, crew: Array[Builder.Crew]) -> StringName:
	"""Give a queued room its foreman and crew; a refused plan leaves it queued. No crew member may already be digging
	another room, and at most MAX_DIGS rooms dig at once."""
	var row: int = _row(room)
	if row < 0: return REFUSE_ROOM
	if _state[row] != RECORD_QUEUED: return REFUSE_STATE
	if _generation[row] != room.y: return REFUSE_ROOM
	if _running() >= MAX_DIGS: return REFUSE_CAPACITY
	if _crew_busy(crew): return REFUSE_CREW_BUSY
	var foreman: Foreman = Foreman.new()
	var code: StringName = foreman.configure(owners, room, Vector2i(_storage[2 * row], _storage[2 * row + 1]),
		Vector2i(_output[2 * row], _output[2 * row + 1]), crew)
	if code != &"": return code
	_foremen.append(foreman)
	_foreman_rows.append(row)
	_state[row] = RECORD_DIGGING
	return &""


func _digging(row: int) -> bool:
	"""A foreman kept for this record row is still running (a deleted room's dig stops itself first)."""
	for index: int in _foremen.size():
		if _foreman_rows[index] == row and _foremen[index].is_running(): return true
	return false


func _running() -> int:
	"""Rooms being dug now."""
	var count: int = 0
	for foreman: Foreman in _foremen:
		count += 1 if foreman.is_running() else 0
	return count


func _crew_busy(crew: Array[Builder.Crew]) -> bool:
	"""Some crew member is a builder of a room still being dug."""
	for foreman: Foreman in _foremen:
		if not foreman.is_running(): continue
		for builder: Builder in foreman.builders():
			for member: Builder.Crew in crew:
				if member != null and member.worker == builder.crew().worker: return true
	return false


func advance(tick: int) -> Array[StringName]:
	"""One fixed tick of every digging room. Returns this tick's new refusals, one per room that stopped, each for
	its own alert (the array is the runtime's, refilled every tick)."""
	_refusals.clear()
	for index: int in _foremen.size():
		var foreman: Foreman = _foremen[index]
		if not foreman.is_running(): continue
		var code: StringName = foreman.advance(tick)
		if code != &"": _refusals.append(code)
		_settle_record(index)
	return _refusals


func _settle_record(index: int) -> void:
	"""A foreman that finished or stopped this tick leaves its record DONE or STOPPED (its row is kept, so a room
	deleted mid-dig still releases its record)."""
	var foreman: Foreman = _foremen[index]
	if foreman.is_running(): return
	var row: int = _foreman_rows[index]
	if _generation[row] != foreman.room().y: return
	_state[row] = RECORD_DONE if foreman.state() == Foreman.STATE_DONE else RECORD_STOPPED


func is_running() -> bool:
	"""True while any room is being dug."""
	return _running() > 0


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
	"""Clear a DONE or STOPPED record and drop its foreman. Re-ordering the room afterwards digs only what is left;
	a phase a stopped dig had paid stays open until C2.3's resume, and the owners refuse to open it again."""
	var row: int = _row(room)
	if row < 0 or _generation[row] != room.y: return REFUSE_ROOM
	if _state[row] != RECORD_DONE and _state[row] != RECORD_STOPPED: return REFUSE_STATE
	_state[row] = RECORD_NONE
	_drop_foremen(row)
	return &""


func _drop_foremen(row: int) -> void:
	"""Forget every foreman kept for one record row."""
	for index: int in range(_foremen.size() - 1, -1, -1):
		if _foreman_rows[index] == row:
			_foremen.remove_at(index)
			_foreman_rows.remove_at(index)
