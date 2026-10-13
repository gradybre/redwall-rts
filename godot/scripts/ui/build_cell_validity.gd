extends RefCounted
## VALIDITY PER CELL for the build panel's ghosts (decision 1912, slice C1 of DEC-061; SET-BUILD-001 BUILD-REQ-002,
## BUILD-REQ-013, §8 "Ground the crew can dig"; UI-BUILD-010; docs/ui_ux_controls.md "Validity in words"). Every
## drafted cell on one level is judged, before Confirm all, in this order (the first that applies is the cell's):
##
##   X  Cannot dig here: water / protected ground / occupied / protected route   the host's ground reader (ECON-003)
##   X  Too narrow: rooms need at least 2 × 2 cells       the cell lies in no 2 × 2 block of its own room
##   !  No way in: connect to a finished Passage or entrance   no route to finished space (BUILD-REQ-013)
##
## THE WAY IN (Brendan's ruling on decision 1911 P-C4 (a), 2026-10-12): a drafted cell has a way in when a 4-connected
## chain of drafted cells on its level -- of ANY room type, the stroke in progress included -- links it to a cell
## whose side touches finished space (the ground reader's FINISHED), or that is on or beside a connector's landing
## (built, or drafted in the same batch: OPEN-07 (a); the host's `landings` reader). Only cells that can be dug carry
## the chain.
##
## PRESENTATION SCRATCH, never saved or authoritative (ARCH-BUILD-001 "Pending batch"): one level's cells as packed
## columns sized once to the planning area -- a membership column (I32), a breadth-first queue (I32) and a reached
## flag (B8), 9 bytes a cell, 589824 bytes for the 256 × 256-cell area -- reset cell by cell after each judgement,
## never reallocated.
## WITH NO GROUND READER BOUND only the 2 × 2 rule is judged (a host that knows no ground claims nothing about it).

const Validity := preload("res://scripts/ui/build_validity.gd")

const CELL_OK: int = 0
const CELL_TOO_NARROW: int = 1
const CELL_NO_WAY_IN: int = 2
const CELL_WATER: int = 3
const CELL_PROTECTED: int = 4
const CELL_OCCUPIED: int = 5
const CELL_ROUTE: int = 6
## A ground reading only: the space is dug and finished (a way in for its neighbours; occupied for a drafted cell).
const CELL_FINISHED: int = 7
const CELL_CODES: int = 8
## What the canonical "Cannot dig here: " reason names for each ground code (docs/ui_ux_controls.md).
const DIG_WORDS: Dictionary = {CELL_WATER: "water", CELL_PROTECTED: "protected ground", CELL_OCCUPIED: "occupied",
	CELL_ROUTE: "protected route", CELL_FINISHED: "occupied"}
const REFUSE_BOUNDS: StringName = &"BUILD_CELLS_BOUNDS"
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The four 2 × 2 blocks a cell can be a corner of, by their north-west cell's offset.
const BLOCK_CORNERS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
## The membership id `all_in_blocks` marks with (never a set's: sets are numbered from 1).
const CHECK_ID: int = -1

var _bounds: Rect2i = Rect2i()
var _ground: Callable = Callable()
var _ground_revision: Callable = Callable()
var _landings: Callable = Callable()
## Per cell of one level: 0 not drafted, else the drafted set's index + 1 (cleared after each judgement).
var _member: PackedInt32Array = PackedInt32Array()
## The breadth-first queue, and which cells were reached (by index into `_member`).
var _queue: PackedInt32Array = PackedInt32Array()
var _reached: PackedByteArray = PackedByteArray()
## Judgements made (checks: a cursor move with nothing changed judges nothing).
var judgements: int = 0


func configure(bounds: Rect2i) -> StringName:
	"""Size the scratch once to the planning area in cells (refused when empty)."""
	if bounds.size.x < 1 or bounds.size.y < 1 or bounds.size.x * bounds.size.y > 1 << 20:
		return REFUSE_BOUNDS
	_bounds = bounds
	var area: int = bounds.size.x * bounds.size.y
	_member.resize(area)
	_member.fill(0)
	_queue.resize(area)
	_reached.resize(area)
	_reached.fill(0)
	return &""


func bind_ground(ground: Callable, revision: Callable) -> void:
	"""`ground(level: int, cell: Vector2i) -> int` (CELL_OK, a CELL_* dig refusal, or CELL_FINISHED) and
	`revision() -> int`, which changes whenever any reading may have."""
	_ground = ground
	_ground_revision = revision


func bind_landings(landings: Callable) -> void:
	"""`landings(level: int) -> PackedInt32Array`: cells where a built or drafted connector lands on that level."""
	_landings = landings


func ground_bound() -> bool:
	"""Whether a ground reader is bound (else only the 2 × 2 rule is judged)."""
	return _ground.is_valid()


func ground_revision() -> int:
	"""The ground reader's revision (0 with none bound)."""
	return int(_ground_revision.call()) if _ground_revision.is_valid() else 0


func all_in_blocks(cells: PackedInt32Array) -> bool:
	"""BUILD-REQ-002 for one set, in time linear in its cells (review H3: the batch's binary-search check took 19 ms
	for a 64 × 64 stroke): every cell lies in a 2 × 2 block of the set. A cell off the planning area fails."""
	for at: int in range(0, cells.size(), 2):
		var index: int = _index(Vector2i(cells[at], cells[at + 1]))
		if index < 0:
			_unmark(cells)
			return false
		_member[index] = CHECK_ID
	var ok: bool = true
	for at: int in range(0, cells.size(), 2):
		if not _in_block(Vector2i(cells[at], cells[at + 1]), CHECK_ID):
			ok = false
			break
	_unmark(cells)
	return ok


func ground_of(level: int, cell: Vector2i) -> int:
	"""The ground reader's code for `cell` on `level` (CELL_PROTECTED outside the planning area, CELL_OK unbound)."""
	if _index(cell) < 0:
		return CELL_PROTECTED
	return int(_ground.call(level, cell)) if _ground.is_valid() else CELL_OK


static func kind_of(code: int) -> int:
	"""A cell code's validity kind (build_validity.gd KIND_*): 0 can build, 1 blocked (No way in), 2 not possible."""
	if code == CELL_OK:
		return 0
	return 1 if code == CELL_NO_WAY_IN else 2


static func words_of(code: int) -> String:
	"""A cell code's canonical reason, word for word ("" for CELL_OK)."""
	if code == CELL_TOO_NARROW:
		return Validity.too_narrow()
	if code == CELL_NO_WAY_IN:
		return Validity.no_way_in()
	return Validity.cannot_dig(DIG_WORDS[code]) if DIG_WORDS.has(code) else ""


func judge_level(level: int, sets: Array[PackedInt32Array]) -> Array[PackedByteArray]:
	"""Each drafted set on `level` (canonical cell pairs; one set per room, the stroke as its own) judged per cell:
	the codes, aligned with each set's cells. A set with a cell outside the planning area is judged as it can be
	(that cell CELL_PROTECTED: no ground there)."""
	judgements += 1
	var out: Array[PackedByteArray] = []
	for index: int in sets.size():
		out.append(_mark(sets[index], index + 1))
	for index: int in sets.size():
		_judge_set(level, sets[index], index + 1, out[index])
	if _ground.is_valid():
		_way_in(level, sets, out)
	for cells: PackedInt32Array in sets:
		_unmark(cells)
	return out


func _mark(cells: PackedInt32Array, id: int) -> PackedByteArray:
	"""Mark one set's cells in the membership column; its codes, all CELL_OK so far."""
	var codes: PackedByteArray = PackedByteArray()
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	codes.resize(count)
	for at: int in range(0, cells.size(), 2):
		var index: int = _index(Vector2i(cells[at], cells[at + 1]))
		if index >= 0:
			_member[index] = id
	return codes


func _unmark(cells: PackedInt32Array) -> void:
	"""Reset one set's cells in the scratch columns."""
	for at: int in range(0, cells.size(), 2):
		var index: int = _index(Vector2i(cells[at], cells[at + 1]))
		if index >= 0:
			_member[index] = 0
			_reached[index] = 0


func _judge_set(level: int, cells: PackedInt32Array, id: int, codes: PackedByteArray) -> void:
	"""The ground and the 2 × 2 rule for one set's cells."""
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		var code: int = _dig_code(level, cell)
		if code == CELL_OK and not _in_block(cell, id):
			code = CELL_TOO_NARROW
		@warning_ignore("integer_division") var slot: int = at / 2
		codes[slot] = code


func _dig_code(level: int, cell: Vector2i) -> int:
	"""The ground reader's refusal for a drafted cell (finished space is occupied), or CELL_OK."""
	if _index(cell) < 0:
		return CELL_PROTECTED
	if not _ground.is_valid():
		return CELL_OK
	var code: int = int(_ground.call(level, cell))
	return CELL_OCCUPIED if code == CELL_FINISHED else (code if DIG_WORDS.has(code) else CELL_OK)


func _in_block(cell: Vector2i, id: int) -> bool:
	"""BUILD-REQ-002: whether `cell` is a corner of a 2 × 2 block wholly in its own set."""
	for corner: Vector2i in BLOCK_CORNERS:
		var at: Vector2i = cell + corner
		if _is(at, id) and _is(at + Vector2i(1, 0), id) and _is(at + Vector2i(0, 1), id) and _is(at + Vector2i.ONE, id):
			return true
	return false


func _is(cell: Vector2i, id: int) -> bool:
	"""Whether `cell` belongs to set `id`."""
	var index: int = _index(cell)
	return index >= 0 and _member[index] == id


func _way_in(level: int, sets: Array[PackedInt32Array], out: Array[PackedByteArray]) -> void:
	"""Breadth-first from every diggable drafted cell beside finished space or on a landing, through diggable drafted
	cells of any set; every diggable cell not reached is CELL_NO_WAY_IN."""
	var tail: int = _seed(level, sets, out)
	var head: int = 0
	while head < tail:
		var cell: Vector2i = _cell_at(_queue[head])
		head += 1
		for side: Vector2i in SIDES:
			tail = _push(cell + side, sets, out, tail)
	for index: int in sets.size():
		_mark_unreached(sets[index], out[index])


func _seed(level: int, sets: Array[PackedInt32Array], out: Array[PackedByteArray]) -> int:
	"""Queue every diggable drafted cell on or beside a connector's landing, and every one beside finished space."""
	var tail: int = 0
	var landings: PackedInt32Array = PackedInt32Array(_landings.call(level)) if _landings.is_valid() else PackedInt32Array()
	for at: int in range(0, landings.size(), 2):
		var landing: Vector2i = Vector2i(landings[at], landings[at + 1])
		tail = _push(landing, sets, out, tail)
		for side: Vector2i in SIDES:
			tail = _push(landing + side, sets, out, tail)
	for index: int in sets.size():
		var cells: PackedInt32Array = sets[index]
		for at: int in range(0, cells.size(), 2):
			var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
			if _beside_finished(level, cell):
				tail = _push(cell, sets, out, tail)
	return tail


func _beside_finished(level: int, cell: Vector2i) -> bool:
	"""Whether a side of `cell` touches finished space (drafted over or not: it is dug either way)."""
	for side: Vector2i in SIDES:
		var next: Vector2i = cell + side
		if _index(next) >= 0 and int(_ground.call(level, next)) == CELL_FINISHED:
			return true
	return false


func _push(cell: Vector2i, sets: Array[PackedInt32Array], out: Array[PackedByteArray], tail: int) -> int:
	"""Queue `cell` once when it is a drafted cell that can be dug; returns the new queue length."""
	var index: int = _index(cell)
	if index < 0 or _member[index] == 0 or _reached[index] == 1:
		return tail
	var id: int = _member[index]
	var slot: int = _slot_of(sets[id - 1], cell)
	if slot < 0 or (out[id - 1][slot] != CELL_OK and out[id - 1][slot] != CELL_TOO_NARROW):
		return tail
	_reached[index] = 1
	_queue[tail] = index
	return tail + 1


func _mark_unreached(cells: PackedInt32Array, codes: PackedByteArray) -> void:
	"""Every diggable, 2 × 2-sound cell of one set the search did not reach has no way in."""
	for at: int in range(0, cells.size(), 2):
		var index: int = _index(Vector2i(cells[at], cells[at + 1]))
		@warning_ignore("integer_division") var slot: int = at / 2
		if codes[slot] == CELL_OK and (index < 0 or _reached[index] == 0):
			codes[slot] = CELL_NO_WAY_IN


static func _slot_of(cells: PackedInt32Array, cell: Vector2i) -> int:
	"""The pair index of `cell` in canonical (row-major: z, then x) `cells`, by binary search; -1 when absent."""
	var low: int = 0
	@warning_ignore("integer_division") var high: int = cells.size() / 2 - 1
	while low <= high:
		@warning_ignore("integer_division") var mid: int = (low + high) / 2
		var at: Vector2i = Vector2i(cells[mid * 2], cells[mid * 2 + 1])
		if at == cell:
			return mid
		if at.y < cell.y or (at.y == cell.y and at.x < cell.x):
			low = mid + 1
		else:
			high = mid - 1
	return -1


func _index(cell: Vector2i) -> int:
	"""The scratch index of `cell`, or -1 outside the planning area."""
	if not _bounds.has_point(cell):
		return -1
	return (cell.y - _bounds.position.y) * _bounds.size.x + cell.x - _bounds.position.x


func _cell_at(index: int) -> Vector2i:
	"""The cell at scratch index `index`."""
	@warning_ignore("integer_division") var z: int = index / _bounds.size.x
	return Vector2i(index - z * _bounds.size.x + _bounds.position.x, z + _bounds.position.y)
