extends "res://demo/tunnel/tunnel_task.gd"
## A RESIDENT GOES DOWN INTO THE DUG ROOMS (decision 1912's proof of concept; Brendan's ruling of 2026-10-12, "A simple
## mole digs": "A mole walks to each cell, and the cell opens after a short wait. Plain walking."). The resident walks
## on the surface, as any task's resident does, to the Entrance; there it goes in (indoors: its actor is not drawn) and
## a stand-in figure (demo_build_figure.gd) carries on below in the build panel's World view:
##   DIG    the mole digs: breadth first from where it stands (demo_build_works.gd `next_dig`) it walks through dug cells
##          to the nearest ordered one and stands beside it for DIG_SECONDS, then the cell opens; when nothing is left
##          that it can reach it walks back to the Entrance and comes out.
##   VISIT  a resident walks through dug cells to the cell it was sent to and stays there until called away.
##   FIT    a resident fits the confirmed furniture (decision 1921; Brendan's "A resident fits it"): breadth first it
##          walks to the nearest piece waiting (demo_build_fittings.gd `next_fit`), stands on it for FIT_SECONDS and
##          the piece appears; when none is left that it can reach it walks back and comes out, as the mole does.
## Walking is a straight line from cell middle to cell middle at the resident's own walk speed; a step through the
## surface (demo_build_works.gd SURFACE: from one Entrance to another, or into a landing from above) is taken at once,
## up and over. No claw stroke, no Work or Routes phase, no payment: none of the settlement's excavation runs (slice
## C3 built the real route in core behind it, decision 1991; slice D2 switches the demo to it).
## Decision 1991 (P-1990-4 (a)): a DIG trip serves the crews (`crews`, Confirm all numbers) its mole was given, and
## claims each cell before walking to it, so up to four moles dig one batch side by side; a cell the player stops
## (P-1990-5 (a)) while it is walked to or dug is let go and the mole plans again.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")

const MODE_DIG: int = 0
const MODE_VISIT: int = 1
const MODE_FIT: int = 2
const STAGE_GOING: int = 0
const STAGE_PLAN: int = 1
const STAGE_WALK: int = 2
const STAGE_DIG: int = 3
const STAGE_STAY: int = 4
const STAGE_OUT: int = 5
## The short wait before a cell opens (Brendan: "the cell opens after a short wait"; seconds of game time).
const DIG_SECONDS: float = 1.5
## The short wait before a piece appears (Brendan: "the piece appears after a short wait, like the mole digging"; the
## dig's own wait, seconds of game time).
const FIT_SECONDS: float = DIG_SECONDS
const UNITS_PER_M: float = 1024.0
## Decision 1991: after a Stop (or the last cell), on the way back out.
const WALKING_OUT: String = "Walking out: nothing left to dig"

var mode: int = MODE_DIG
var stage: int = STAGE_GOING
## The cells dug, and the pieces fitted, by this trip (checks).
var dug: int = 0
var fitted: int = 0
var _works: Works = null
var _fittings: Fittings = null
var _fit_row: int = -1
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
## Decision 1991: the crew numbers this DIG trip serves (empty: any cell).
var crews: PackedByteArray = PackedByteArray()


func _init(works: Works, figure: Figure, floors: PackedInt32Array, datum: Vector2i, task_mode: int,
		goal: Vector3i, who: String, way: int = -1, site_m: Vector2 = Vector2.INF) -> void:
	"""Down through Entrance row `way` (-1: the first) into `works`' dug rooms, drawn as `figure`, on `floors` (u per
	level) from `datum` (u): to dig (`goal` unused), or to visit `goal` (level, x, z). `site_m` is where it goes in on
	the surface when that is not the Entrance itself (a hatch on a Mound's floor: its door's yard; decision 2002)."""
	_works = works
	_figure = figure
	_floors = floors
	_datum = datum
	mode = task_mode
	_goal = goal
	_who = who
	var row: int = way if way >= 0 else works.entrance()
	var cell: Vector2i = works.way_cell(row) if row >= 0 else Vector2i.ZERO
	_entrance = Vector2(_datum.x / UNITS_PER_M + cell.x + 1.0, _datum.y / UNITS_PER_M + cell.y + 1.0)
	if site_m.is_finite():
		_entrance = site_m
	_start = works.landing_of(row) if row >= 0 else Vector3i.ZERO


func use_fittings(fittings: Fittings) -> void:
	"""The confirmed furniture a FIT trip fits (set before the trip is ordered)."""
	_fittings = fittings


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
	"""What next: the nearest cell to dig (DIG), the nearest piece to fit (FIT), the cell visited (VISIT), or the way
	out."""
	if mode == MODE_VISIT:
		_path = _works.path_to(_at, _goal) if _at != _goal else PackedVector3Array()
		_go(STAGE_STAY if _path.is_empty() else STAGE_WALK)
		return
	var found: Dictionary = _next_job()
	if found.is_empty():
		_head_out()
		return
	_target = found["target"]
	_fit_row = int(found.get("row", -1))
	_path = found["path"]
	_go(STAGE_WALK)


func _next_job() -> Dictionary:
	"""{target, path} (and the piece's `row` for FIT) of the nearest cell to dig or piece to fit, or {}."""
	if mode == MODE_DIG:
		var cell: Dictionary = _works.next_dig(_at, crews, key())
		if not cell.is_empty() and not _works.claim(cell["target"], key()):
			return {}
		return cell
	var found: Dictionary = _fittings.next_fit(_works, _at) if _fittings != null else {}
	if found.is_empty():
		return {}
	return {"target": found["goal"], "path": found["path"], "row": found["row"]}


func _head_out() -> void:
	"""Nothing left to do that can be reached: back to the landing, then out."""
	_let_go()
	_path = _works.path_to(_at, _start) if _at != _start else PackedVector3Array()
	_go(STAGE_OUT if _path.is_empty() else STAGE_WALK)
	_target = Vector3i(-1, 0, 0)


func _go(next_stage: int) -> void:
	"""Start walking `_path` from its first cell (or go to `next_stage` with nothing to walk)."""
	_next = 0
	stage = next_stage


func _walk(stride: float) -> void:
	"""Along `_path` at walk speed, cell middle to cell middle (through the surface at once); at its end: dig, stay, or
	come out."""
	while _next < _path.size() and stride > 0.0:
		var cell: Vector3i = Vector3i(_path[_next])
		if cell == Works.SURFACE or _from_surface():
			_over_the_top(cell)
			continue
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


func _from_surface() -> bool:
	"""Whether the step just taken was through the surface."""
	return _next > 0 and Vector3i(_path[_next - 1]) == Works.SURFACE


func _over_the_top(cell: Vector3i) -> void:
	"""A step through the surface: at once to the next cell (or, ending there, over the cell to be dug)."""
	_next += 1
	var landing: Vector3i = cell if cell != Works.SURFACE else _target
	if landing.x >= 1:
		_figure.move_to(world_of(landing))
		_at = landing


func _arrive_below() -> void:
	"""The walk's end: dig the target, stay (VISIT), or the way out reached (DIG with nothing left)."""
	if mode == MODE_VISIT:
		stage = STAGE_STAY
	elif _target.x < 0:
		stage = STAGE_OUT
	else:
		_wait = FIT_SECONDS if mode == MODE_FIT else DIG_SECONDS
		_figure.set_digging(true)
		stage = STAGE_DIG


func _dig(delta: float) -> void:
	"""The short wait, then the cell opens (DIG) or the piece appears (FIT). A cell the player stopped meanwhile, or
	one another mole now holds (stopped and ordered again), is let go at once and the next planned (decision 1991)."""
	if mode == MODE_DIG and (_works.state(_target.x, Vector2i(_target.y, _target.z)) != Works.ORDERED
			or _works.claimed_by(_target) != key()):
		_figure.set_digging(false)
		_let_go()
		stage = STAGE_PLAN
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if mode == MODE_FIT:
		fitted += 1 if _fittings != null and _fittings.fit(_fit_row) else 0
	elif _works.open_cell(_target.x, Vector2i(_target.y, _target.z)):
		dug += 1
	_figure.set_digging(false)
	stage = STAGE_PLAN


func _come_out(walker: BrainScript) -> void:
	"""Out at the Entrance: the figure gone, the resident drawn again, any cell it held let go."""
	_let_go()
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


func key() -> int:
	"""This trip's key in the works' claims (its object id: unique while it lives)."""
	return get_instance_id()


func serve(crew: int) -> void:
	"""Decision 1991: also dig the cells of crew `crew` (a later Confirm all naming this mole again)."""
	if not crews.is_empty() and not crews.has(crew):
		crews.append(crew)


func _let_go() -> void:
	"""The cell this trip was going to dig, released for another mole."""
	if mode == MODE_DIG and _target.x >= 1:
		_works.unclaim(_target, key())


func holds_when_lost() -> bool:
	"""Lost on the way to the Entrance, it goes back to its routine; the build panel sends a mole again."""
	return false


func at() -> Vector3i:
	"""Where the figure stands below: (level, x, z)."""
	return _at


func digging_cell() -> Vector3i:
	"""The cell being dug now (level, x, z), or (-1, 0, 0) when not digging (demo_build_earth.gd draws it deepening)."""
	return _target if stage == STAGE_DIG and mode == MODE_DIG else Vector3i(-1, 0, 0)


func fitting_row() -> int:
	"""The piece being fitted now (demo_build_fittings.gd row), or -1."""
	return _fit_row if stage == STAGE_DIG and mode == MODE_FIT else -1


func dig_share() -> float:
	"""How far the cell being dug has gone, 0-1 (0 when not digging)."""
	return clampf(1.0 - _wait / DIG_SECONDS, 0.0, 1.0) if stage == STAGE_DIG and mode == MODE_DIG else 0.0


func below() -> bool:
	"""Whether the resident is underground now (checks)."""
	return stage != STAGE_GOING and stage != STAGE_OUT


func label() -> String:
	"""What the panel says."""
	if mode == MODE_VISIT:
		return "Going down to the dug rooms" if stage == STAGE_GOING else "In the dug rooms below"
	if mode == MODE_FIT:
		var pieces: int = _fittings.waiting() if _fittings != null else 0
		return "Going to the Entrance to fit furniture" if stage == STAGE_GOING \
			else "Fitting the furniture (%d %s waiting)" % [pieces, "piece" if pieces == 1 else "pieces"]
	if stage == STAGE_GOING:
		return "Going to the Entrance to dig"
	if stage == STAGE_OUT or (stage == STAGE_WALK and _target.x < 0):
		return WALKING_OUT
	return "Digging the planned rooms (%d cells waiting)" % waiting()


func waiting() -> int:
	"""Decision 1991: the cells still waiting for this trip's crews (all of them for a trip serving any crew)."""
	if crews.is_empty():
		return _works.waiting()
	var count: int = 0
	for crew: int in crews:
		count += _works.waiting_for(crew)
	return count
