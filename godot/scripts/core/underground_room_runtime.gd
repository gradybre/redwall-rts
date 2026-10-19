extends RefCounted
## Decision 1933 (C2.1), P-C2-4 (a): every confirmed underground room's dig is one small packed record, indexed by
## the room's directory row; each quantum keeps its own short-lived per-phase Construction projects (Sites). Rooms
## being dug have a foreman (bounded by the crews, at most MAX_DIGS at once). SettlementSystem advances this
## runtime once per fixed tick after the first entry. Nothing here pays or claims: the foremen's owner calls do.
## Decision 1936 (C2.3): SettlementSystem builds it when the Session's room owners are composed (so its record is
## allocated in every mounted game), binds the owners it borrows, and saves it as `underground_room_progress`. A
## finished dig's record is cleared once its crew has walked out; a stopped one is kept until it is released.

const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Construction := preload("res://scripts/core/construction.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const EntryProgress := preload("res://scripts/core/underground_entry_progress.gd")
const Retirement := preload("res://scripts/core/underground_room_station_retirement.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## One record per room row; `_init` refuses a directory whose room capacity differs (as Buildings asserts).
const ROOM_CAPACITY: int = 16384
## A dig needs at least one builder and the living population caps at 256 (AGENTS.md), so at most 256 rooms are
## dug at once; queued rooms keep only their record.
const MAX_DIGS: int = 256
## Decision 1936: records in use (queued, digging, stopped awaiting release, or done with the crew still out) are
## bounded, so the save's bound is: the running digs plus as many stopped ones.
const MAX_KEPT: int = 2 * MAX_DIGS
const RECORD_NONE: int = 0
const RECORD_QUEUED: int = 1
const RECORD_DIGGING: int = 2
const RECORD_DONE: int = 3
const RECORD_STOPPED: int = 4
const REFUSE_ROOM: StringName = &"ROOM_DIG_ROOM_STALE"
const REFUSE_STATE: StringName = &"ROOM_DIG_RECORD_STATE"
const REFUSE_CAPACITY: StringName = &"ROOM_DIG_CAPACITY"
const REFUSE_CREW_BUSY: StringName = &"ROOM_DIG_CREW_BUSY"
## Decision 1936: a dig's record is kept until its crew has walked back out (P-1936-3 (a)).
const REFUSE_CREW_OUT: StringName = &"ROOM_DIG_CREW_OUT"
## The bytes of the packed record per kept room: generation, state, and the storage, output and staging container
## references (decision 1934 added the staging one).
const RECORD_BYTES: int = 4 + 1 + 3 * 2 * 4
## Decision 1937 (P-1937-1 D): the records are a pool of MAX_KEPT slots, each naming its room's directory row.
const SLOT_BYTES: int = RECORD_BYTES + 4

var _directory: Directory = null
var _room_row: PackedInt32Array = PackedInt32Array() # P-1937-1 D: each slot's room directory row, -1 when free.
var _generation: PackedInt32Array = PackedInt32Array()
var _state: PackedByteArray = PackedByteArray()
var _storage: PackedInt32Array = PackedInt32Array()
var _output: PackedInt32Array = PackedInt32Array()
var _staging: PackedInt32Array = PackedInt32Array()
var _foremen: Array[Foreman] = [] # Running ones, and stopped or done ones until their record is released.
var _foreman_rows: PackedInt32Array = PackedInt32Array() # The record row of each foreman, in step with `_foremen`.
var _refusals: Array[StringName] = [] # This tick's new refusals, one per room that stopped.
var _owners: Builder.Owners = null # Decision 1936: the composed owners every dig borrows (null until composed).
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _face: WorkFace = null # Decision 1936: the work face the room phases' contacts borrow (held here, bound weakly).
var _contact_access: Vector2i = NULL_REF # Decision 1936: the access and retreat row the contacts were bound to.
var _contact_travel: int = -1


func _init(directory: Directory) -> void:
	"""Allocate the MAX_KEPT record slots (P-1937-1 D); a mismatched directory leaves every operation refused."""
	_directory = directory if directory != null and directory.capacity_of_kind(Directory.KIND_ROOM) == ROOM_CAPACITY else null
	_room_row.resize(MAX_KEPT)
	_room_row.fill(-1)
	_generation.resize(MAX_KEPT)
	_state.resize(MAX_KEPT)
	_storage.resize(2 * MAX_KEPT)
	_output.resize(2 * MAX_KEPT)
	_staging.resize(2 * MAX_KEPT)


static func packed_bytes() -> int:
	"""The runtime's packed record columns, in bytes (decision 1937: MAX_KEPT slots)."""
	return MAX_KEPT * SLOT_BYTES


func bind_owners(owners: Builder.Owners) -> bool:
	"""Decision 1936: borrow the composed owners once; the dispatcher's answers read Jobs and Construction through
	them."""
	if _owners != null or owners == null or owners.jobs == null or owners.construction == null: return false
	_owners = owners
	if owners.extents == null: owners.extents = Builder.Footprint.RowExtents.new() # P-1937-1 B: one table.
	return true


func bound_owners() -> Builder.Owners:
	"""The bound owners, or null."""
	return _owners


func work_face() -> WorkFace:
	"""The one work face the room phases' contacts are bound with (P-1936-1 (a)); this runtime keeps it alive."""
	if _face == null: _face = WorkFace.new()
	return _face


func parkings() -> Array[Vector2i]:
	"""The parking endpoints of builders still digging or still underground: a new builder parks elsewhere."""
	var out: Array[Vector2i] = []
	for foreman: Foreman in _foremen:
		for builder: Builder in foreman.builders():
			if foreman.is_running() or builder.underground(): out.append(builder.crew().parking)
	return out


func owns_job(job_slot: int) -> bool:
	"""Decision 1936 (review H4): every Job an excavation phase Project requests, read from saved Jobs and Construction
	alone, so a dig's Jobs stay off the JobSelector between cubes, after a stop (its paid phases wait for a resume)
	and across a load. The entry's own cuts are the entry's too; the composite asks both."""
	if _owners == null: return false
	return _owners.construction.purpose_into(_owners.jobs.requester_of(job_slot), _math) \
		and _math.value == Construction.PURPOSE_EXCAVATION


func reserves_resident(resident_slot: int) -> bool:
	"""Decision 1936: a builder is reserved while its dig runs, between cubes too, and afterwards for as long as it is
	still underground (a registered route actor, or walking in or out)."""
	for foreman: Foreman in _foremen:
		if foreman.reserves_resident(resident_slot): return true
	return false


func _row(room: Vector2i) -> int:
	"""The room's directory row, or -1 for a stale or foreign reference."""
	if _directory == null or room == NULL_REF or not _directory.is_valid_of_kind(room, Directory.KIND_ROOM): return -1
	var row: int = _directory.get_typed_row(room)
	return row if row >= 0 and row < ROOM_CAPACITY else -1


func order_room(room: Vector2i, storage: Vector2i, output: Vector2i, staging: Vector2i = NULL_REF) -> StringName:
	"""Queue a confirmed room for digging with the containers its inputs come from and its spoil goes to, and (or
	null) the same-level staging container missing inputs are hauled from (decision 1934). A record of the same room
	must be released first; one left by a deleted room on a reused row is replaced."""
	var row: int = _row(room)
	if row < 0 or storage == NULL_REF or output == NULL_REF: return REFUSE_ROOM
	var slot: int = _slot(row)
	if (slot >= 0 and _generation[slot] == room.y) or _digging(row): return REFUSE_STATE
	if _crew_out_on(row): return REFUSE_CREW_OUT # A deleted room's crew is still walking out.
	if slot < 0: slot = _room_row.find(-1)
	if slot < 0: return REFUSE_CAPACITY
	_drop_foremen(row)
	_room_row[slot] = row
	_generation[slot] = room.y
	_state[slot] = RECORD_QUEUED
	_storage[2 * slot] = storage.x; _storage[2 * slot + 1] = storage.y
	_output[2 * slot] = output.x; _output[2 * slot + 1] = output.y
	_staging[2 * slot] = staging.x; _staging[2 * slot + 1] = staging.y
	return &""


func _slot(row: int) -> int:
	"""The pool slot keeping a room row's record, or -1 (P-1937-1 D)."""
	return _room_row.find(row) if row >= 0 else -1


func _set_state(row: int, state: int) -> void:
	"""Set a kept record's state; RECORD_NONE frees its slot."""
	var slot: int = _slot(row)
	if slot < 0: return
	_state[slot] = state
	if state == RECORD_NONE: _room_row[slot] = -1


func start_room(room: Vector2i, owners: Builder.Owners, crew: Array[Builder.Crew]) -> StringName:
	"""Give a queued room its foreman and crew; a refused plan leaves it queued. No crew member may already be digging
	another room, and at most MAX_DIGS rooms dig at once."""
	var row: int = _row(room)
	if row < 0: return REFUSE_ROOM
	var slot: int = _slot(row)
	if slot < 0 or _state[slot] != RECORD_QUEUED: return REFUSE_STATE
	if _generation[slot] != room.y: return REFUSE_ROOM
	if _running() >= MAX_DIGS: return REFUSE_CAPACITY
	if _crew_busy(crew): return REFUSE_CREW_BUSY
	var foreman: Foreman = Foreman.new()
	var code: StringName = foreman.configure(owners, room, Vector2i(_storage[2 * slot], _storage[2 * slot + 1]),
		Vector2i(_output[2 * slot], _output[2 * slot + 1]), Vector2i(_staging[2 * slot], _staging[2 * slot + 1]), crew)
	if code != &"": return code
	_foremen.append(foreman)
	_foreman_rows.append(row)
	_state[slot] = RECORD_DIGGING
	return &""


func kept() -> int:
	"""Records in use."""
	return MAX_KEPT - _room_row.count(-1)


func note_contacts(access: Vector2i, travel: int) -> void:
	"""P-1936-1 (a): the access and retreat row the room phases' contacts were bound to, kept so a load binds them
	again."""
	_contact_access = access
	_contact_travel = travel


func contacts_access() -> Vector2i:
	"""The access the room phases' contacts are bound to, or null."""
	return _contact_access


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
	"""Some crew member is a builder of a room still being dug, or still underground after one."""
	for foreman: Foreman in _foremen:
		for builder: Builder in foreman.builders():
			if not foreman.is_running() and not builder.underground(): continue
			for member: Builder.Crew in crew:
				if member != null and member.worker == builder.crew().worker: return true
	return false


func advance(tick: int) -> Array[StringName]:
	"""One fixed tick of every digging room. Returns this tick's new refusals, one per room that stopped, each for
	its own alert (the array is the runtime's, refilled every tick)."""
	_refusals.clear()
	_heal_occupancy()
	for index: int in _foremen.size():
		var foreman: Foreman = _foremen[index]
		var code: StringName = &""
		if foreman.is_running():
			code = foreman.advance(tick)
			_settle_record(index)
		elif foreman.crew_out():
			code = foreman.advance_out(tick) # P-1936-3 (a): the crew walks back out.
		foreman.shed_crew()
		if code != &"": _refusals.append(code)
	Retirement.retire_finished(_foremen, _owners) # Decision 1942: finished columns' chains, past the edge bound.
	_release_done()
	return _refusals


func _heal_occupancy() -> void:
	"""Review M-a: an arrival out whose occupancy refresh was refused left Routes stale, and stale Routes moves
	nobody; while a dig runs, one refresh is retried each tick until it holds."""
	if _owners == null or _foremen.is_empty() or _owners.routes._occupancy_context_refusal() == &"": return
	_owners.routes.refresh_occupancy()


func _release_done() -> void:
	"""Review M-b: a finished dig whose crew is out releases its record by itself (Sites keep the dug room), so kept
	records are only digs under way, stopped ones and finished ones still walking out."""
	for index: int in range(_foremen.size() - 1, -1, -1):
		var foreman: Foreman = _foremen[index]
		if foreman.state() != Foreman.STATE_DONE or foreman.crew_out(): continue
		_set_state(_foreman_rows[index], RECORD_NONE)
		_foremen.remove_at(index)
		_foreman_rows.remove_at(index)


func _settle_record(index: int) -> void:
	"""A foreman that finished or stopped this tick leaves its record DONE or STOPPED (its row is kept, so a room
	deleted mid-dig still settles its record; the row cannot be re-ordered while the dig runs)."""
	var foreman: Foreman = _foremen[index]
	if foreman.is_running(): return
	_set_state(_foreman_rows[index], RECORD_DONE if foreman.state() == Foreman.STATE_DONE else RECORD_STOPPED)


func is_running() -> bool:
	"""True while any room is being dug or a finished dig's crew is still walking out."""
	if _running() > 0: return true
	for foreman: Foreman in _foremen:
		if foreman.crew_out(): return true
	return false


func state_of(room: Vector2i) -> int:
	"""The room's record state, RECORD_NONE for an unknown or stale room."""
	var slot: int = _slot(_row(room))
	return _state[slot] if slot >= 0 and _generation[slot] == room.y else RECORD_NONE


func foreman_of(room: Vector2i) -> Foreman:
	"""The room's foreman while digging or after it stopped, for status; null otherwise."""
	for foreman: Foreman in _foremen:
		if foreman.room() == room: return foreman
	return null


func release_room(room: Vector2i) -> StringName:
	"""Clear a DONE or STOPPED record and drop its foreman. Re-ordering the room afterwards digs only what is left;
	a phase a stopped dig had paid stays open, and the re-ordered dig takes it over (P-1933-2 (a)). Refused while a
	builder is still underground."""
	var row: int = _row(room)
	var slot: int = _slot(row)
	if row < 0 or (slot >= 0 and _generation[slot] != room.y): return REFUSE_ROOM
	if slot < 0: return REFUSE_STATE # Nothing kept for this room.
	if _state[slot] != RECORD_DONE and _state[slot] != RECORD_STOPPED: return REFUSE_STATE
	if _crew_out_on(row): return REFUSE_CREW_OUT
	_set_state(row, RECORD_NONE)
	_drop_foremen(row)
	return &""


func cancel_queued(room: Vector2i) -> StringName:
	"""Forget a QUEUED record no foreman took (decision 1937: an order whose start was refused leaves nothing)."""
	var row: int = _row(room)
	var slot: int = _slot(row)
	if row < 0 or (slot >= 0 and _generation[slot] != room.y): return REFUSE_ROOM
	if slot < 0: return REFUSE_STATE # Nothing kept for this room.
	if _state[slot] != RECORD_QUEUED: return REFUSE_STATE
	_set_state(row, RECORD_NONE)
	return &""


func _crew_out_on(row: int) -> bool:
	"""A foreman kept for the row still has a builder underground."""
	for index: int in _foremen.size():
		if _foreman_rows[index] == row and _foremen[index].crew_out(): return true
	return false


func _drop_foremen(row: int) -> void:
	"""Forget every foreman kept for one record row."""
	for index: int in range(_foremen.size() - 1, -1, -1):
		if _foreman_rows[index] == row:
			_foremen.remove_at(index)
			_foreman_rows.remove_at(index)


# --- Decision 1936, P-1936-4 (a): save and load (section 6 `underground_room_progress`) -----------------------------

func is_empty() -> bool:
	"""Nothing to save: no contacts bound, no record in use and no foreman kept (a save writes an empty block)."""
	return _contact_access == NULL_REF and kept() == 0 and _foremen.is_empty()


func capture(out: PackedByteArray) -> StringName:
	"""The whole room-dig record at a quiescent tick boundary, digs in flight or not."""
	out.clear()
	if _owners != null and EntryProgress.busy_refusal(_owners) != &"": return Progress.REFUSE_BUSY
	var w: EntryProgress.Writer = Progress.begin(out)
	_write_state(w)
	return &"" if Progress.finish(w) else Progress.REFUSE_SHAPE


func _write_state(w: EntryProgress.Writer) -> void:
	"""The contacts, every record row in use, then every kept foreman after its record row."""
	w.ref(_contact_access)
	w.i32(_contact_travel)
	w.i32(kept())
	var rows: PackedInt32Array = _room_row.duplicate()
	rows.sort() # In room row order, so the record is canonical whichever slots the records hold.
	for row: int in rows:
		if row < 0: continue
		var slot: int = _slot(row)
		w.i32(row)
		w.i32(_generation[slot])
		w.i32(_state[slot])
		for column: PackedInt32Array in [_storage, _output, _staging]:
			w.ref(Vector2i(column[2 * slot], column[2 * slot + 1]))
	w.i32(_foremen.size())
	for index: int in _foremen.size():
		w.i32(_foreman_rows[index])
		_foremen[index].write_state(w)


func restore(bytes: PackedByteArray) -> StringName:
	"""Rebuild this fresh runtime exactly from its record under its bound owners; a decoded record must re-encode to
	the same bytes. A refused record leaves the runtime empty. The contacts are bound again by the composer."""
	if not is_empty() or _owners == null: return Progress.REFUSE_TARGET
	var r: EntryProgress.Reader = EntryProgress.Reader.new()
	var code: StringName = Progress.open(bytes, r)
	if code == &"": code = _read_state(r)
	if code == &"": code = Progress.close(r)
	if code == &"":
		var c: Progress.Checker = Progress.check(bytes)
		_write_state(c)
		code = &"" if c.matches() else Progress.REFUSE_NONCANONICAL
	if code != &"": _drop_restored()
	return code


func _read_state(r: EntryProgress.Reader) -> StringName:
	"""Decode the contacts, the rows and the foremen in wire order."""
	_contact_access = r.ref()
	_contact_travel = r.i32()
	for index: int in r.ranged(0, MAX_KEPT):
		var row: int = r.ranged(0, ROOM_CAPACITY - 1)
		var slot: int = _room_row.find(-1)
		if _slot(row) >= 0 or slot < 0: return Progress.REFUSE_SHAPE # A row kept twice.
		_room_row[slot] = row
		_generation[slot] = r.i32()
		_state[slot] = r.ranged(RECORD_QUEUED, RECORD_STOPPED)
		var at: Vector2i = r.ref()
		_storage[2 * slot] = at.x; _storage[2 * slot + 1] = at.y
		at = r.ref()
		_output[2 * slot] = at.x; _output[2 * slot + 1] = at.y
		at = r.ref()
		_staging[2 * slot] = at.x; _staging[2 * slot + 1] = at.y
	for index: int in r.ranged(0, MAX_KEPT):
		var row: int = r.ranged(0, ROOM_CAPACITY - 1)
		var foreman: Foreman = Foreman.new()
		var code: StringName = foreman.read_state(r, _owners)
		if code != &"": return code
		_foremen.append(foreman)
		_foreman_rows.append(row)
	return Progress.REFUSE_SHAPE if r.bad else &""


func _drop_restored() -> void:
	"""Undo a refused restore: no contacts, no record, no foreman."""
	_contact_access = NULL_REF
	_contact_travel = -1
	_room_row.fill(-1)
	_state.fill(RECORD_NONE)
	_foremen.clear()
	_foreman_rows.clear()
