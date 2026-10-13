extends "res://demo/tunnel/tunnel_task.gd"
## A RESIDENT GOES DOWN INTO THE DUG ROOMS (decision 1912's proof of concept; Brendan's ruling of 2026-10-12, "A simple
## mole digs": "A mole walks to each cell, and the cell opens after a short wait. Plain walking."). The resident walks
## on the surface, as any task's resident does, to the Entrance; there it goes in (indoors: its actor is not drawn) and
## a stand-in figure (demo_build_figure.gd) carries on below in the build panel's World view:
##   DIG    the mole digs: breadth first from where it stands (demo_build_works.gd `next_dig`) it walks through dug cells
##          to the nearest ordered one and stands beside it for DIG_SECONDS, then the cell opens; when nothing is left
##          that it can reach it walks back to the Entrance and comes out.
##   VISIT  a resident walks through dug cells to the cell it was sent to and stays there until called away.
## Walking is a straight line from cell middle to cell middle at the resident's own walk speed. No claw stroke, no
## Work or Routes phase, no payment: none of the settlement's excavation runs (that is slice C3's).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")

const MODE_DIG: int = 0
const MODE_VISIT: int = 1
const STAGE_GOING: int = 0
const STAGE_PLAN: int = 1
const STAGE_WALK: int = 2
const STAGE_DIG: int = 3
const STAGE_STAY: int = 4
const STAGE_OUT: int = 5
## The short wait before a cell opens (Brendan: "the cell opens after a short wait"; seconds of game time).
const DIG_SECONDS: float = 1.5
const UNITS_PER_M: float = 1024.0

var mode: int = MODE_DIG
var stage: int = STAGE_GOING
## The cells dug by this trip (checks).
var dug: int = 0
var _works: Works = null
var _figure: Figure = null
var _floors: PackedInt32Array = PackedInt32Array()
var _datum: Vector2i = Vector2i.ZERO
var _entrance: Vector2 = Vector2.ZERO
var _start: Vector3i = Vector3i.ZERO
var _goal: Vector3i = Vector3i.ZERO
var _at: Vector3i = Vector3i.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _next: int = 0
var _target: Vector3i = Vector3i.ZERO
var _wait: float = 0.0
var _who: String = ""


func _init(works: Works, figure: Figure, floors: PackedInt32Array, datum: Vector2i, task_mode: int,
		goal: Vector3i, who: String) -> void:
	"""Down through the first Entrance into `works`' dug rooms, drawn as `figure`, on `floors` (u per level) from
	`datum` (u): to dig (`goal` unused), or to visit `goal` (level, x, z)."""
	_works = works
	_figure = figure
	_floors = floors
	_datum = datum
	mode = task_mode
	_goal = goal
	_who = who
	var row: int = works.entrance()
	var cell: Vector2i = works.way_cell(row) if row >= 0 else Vector2i.ZERO
	_entrance = Vector2(_datum.x / UNITS_PER_M + cell.x + 1.0, _datum.y / UNITS_PER_M + cell.y + 1.0)
	_start = works.landing_of(row) if row >= 0 else Vector3i.ZERO


func site(_brain: RefCounted) -> Vector2:
	"""The Entrance's middle on the surface."""
	return _entrance


func arrived(brain: RefCounted) -> void:
	"""At the Entrance: in, and the figure appears on its landing below."""
	(brain as BrainScript).task_go_indoors(true, BrainScript.INTERIOR_NONE)
	_at = _start
	_figure.show_as(_who, world_of(_at))
	stage = STAGE_PLAN


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame below; false once the mole came out."""
	match stage:
		STAGE_PLAN:
			_plan()
		STAGE_WALK:
			_walk((brain as BrainScript).walk_speed * delta)
		STAGE_DIG:
			_dig(delta)
		STAGE_OUT:
			_come_out(brain as BrainScript)
			return false
	return true


func _plan() -> void:
	"""What next: the nearest cell to dig (DIG), the cell visited (VISIT), or the way out."""
	var found: Dictionary = _works.next_dig(_at) if mode == MODE_DIG else {}
	if mode == MODE_VISIT:
		_path = _works.path_to(_at, _goal) if _at != _goal else PackedVector3Array()
		_go(STAGE_STAY if _path.is_empty() else STAGE_WALK)
		return
	if found.is_empty():
		_path = _works.path_to(_at, _start) if _at != _start else PackedVector3Array()
		_go(STAGE_OUT if _path.is_empty() else STAGE_WALK)
		_target = Vector3i(-1, 0, 0)
		return
	_target = found["target"]
	_path = found["path"]
	_go(STAGE_WALK)


func _go(next_stage: int) -> void:
	"""Start walking `_path` from its first cell (or go to `next_stage` with nothing to walk)."""
	_next = 0
	stage = next_stage


func _walk(stride: float) -> void:
	"""Along `_path` at walk speed, cell middle to cell middle; at its end: dig, stay, or come out."""
	while _next < _path.size() and stride > 0.0:
		var cell: Vector3i = Vector3i(_path[_next])
		var to: Vector3 = world_of(cell) - _figure.position
		if to.length() <= stride:
			_figure.move_to(world_of(cell))
			_at = cell
			stride -= to.length()
			_next += 1
		else:
			_figure.move_to(_figure.position + to.normalized() * stride)
			stride = 0.0
	if _next >= _path.size():
		_arrive_below()


func _arrive_below() -> void:
	"""The walk's end: dig the target, stay (VISIT), or the way out reached (DIG with nothing left)."""
	if mode == MODE_VISIT:
		stage = STAGE_STAY
	elif _target.x < 0:
		stage = STAGE_OUT
	else:
		_wait = DIG_SECONDS
		_figure.set_digging(true)
		stage = STAGE_DIG


func _dig(delta: float) -> void:
	"""The short wait, then the cell opens."""
	_wait -= delta
	if _wait > 0.0:
		return
	if _works.open_cell(_target.x, Vector2i(_target.y, _target.z)):
		dug += 1
	_figure.set_digging(false)
	stage = STAGE_PLAN


func _come_out(walker: BrainScript) -> void:
	"""Out at the Entrance: the figure gone, the resident drawn again."""
	_figure.visible = false
	walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)


func world_of(cell: Vector3i) -> Vector3:
	"""A cell's middle on its level's floor, metres."""
	var level: int = clampi(cell.x, 0, _floors.size() - 1)
	return Vector3(_datum.x / UNITS_PER_M + cell.y + 0.5, _floors[level] / UNITS_PER_M,
		_datum.y / UNITS_PER_M + cell.z + 0.5)


func finish(brain: RefCounted) -> void:
	"""The trip is over."""
	_come_out(brain as BrainScript)


func cancel(brain: RefCounted) -> void:
	"""Called away: out at once (the dug cells stay dug; the rest waits for the next trip)."""
	_come_out(brain as BrainScript)


func holds_when_lost() -> bool:
	"""Lost on the way to the Entrance, it goes back to its routine; the build panel sends a mole again."""
	return false


func at() -> Vector3i:
	"""Where the figure stands below: (level, x, z)."""
	return _at


func below() -> bool:
	"""Whether the resident is underground now (checks)."""
	return stage != STAGE_GOING and stage != STAGE_OUT


func label() -> String:
	"""What the panel says."""
	if mode == MODE_VISIT:
		return "Going down to the dug rooms" if stage == STAGE_GOING else "In the dug rooms below"
	if stage == STAGE_GOING:
		return "Going to the Entrance to dig"
	return "Digging the planned rooms (%d cells waiting)" % _works.waiting()
