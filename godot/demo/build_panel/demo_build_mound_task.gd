extends "res://demo/tunnel/tunnel_task.gd"
## A RESIDENT BUILDS THE MOUNDS (decision 2002; Brendan's ruling of decision 2001: "a resident does the work, the same
## simple way the proof-of-concept mole digs", decision 1912). The resident walks on the surface to a Mound's door yard
## and works there, the next job each time (demo_build_mound_jobs.gd):
##   FROM THE YARD   it heaps the hill a cell at a time and later tops and turfs it, and fits the doors and windows:
##                   it stands on the yard's path facing the door, at work (the forager's work clip), for a short wait;
##   INSIDE          to dig, frame and fit furniture it goes in at the door (its actor indoors, not drawn) and a
##                   stand-in figure (demo_build_figure.gd, on the village's layer) walks the dug cells to the job,
##                   seen in the build view's cutaway; it comes back out at the door for a job done from the yard.
## Each job is a short wait (JOB_SECONDS, game time): the dig the mole's own 1.5 s. When no Mound has work left it comes
## out and goes back to its routine. No payment and no real earthwork: the hill is drawn (P-2001-11 (a)).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Jobs := preload("res://demo/build_panel/demo_build_mound_jobs.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Layers := preload("res://demo/demo_layers.gd")

const STAGE_GOING: int = 0
const STAGE_PLAN: int = 1
const STAGE_WALK: int = 2
const STAGE_WORK: int = 3
const STAGE_OUT: int = 4
## Each job's wait, by demo_build_mounds.gd JOB_*: heap, dig (the proof of concept's dig), frame, top, fit a door or
## window, fit furniture (the Furnish tab's wait).
const JOB_SECONDS: Array[float] = [0.6, 1.5, 0.5, 0.4, 1.5, 1.5]
const WORK_CLIP: StringName = &"pull_radish"

var stage: int = STAGE_GOING
## The job in hand ({} between jobs), and how many were done (checks).
var job: Dictionary = {}
var done: int = 0
var _mounds: Mounds = null
var _works: Works = null
var _fittings: Fittings = null
var _figure: Figure = null
var _datum_m: Vector2 = Vector2.ZERO
var _who: String = ""
var _station: Vector2 = Vector2.INF
var _door_cell: Vector2i = Vector2i.ZERO
var _inside: bool = false
var _at: Vector2i = Vector2i.ZERO
var _path: Array[Vector2i] = []
var _next: int = 0
var _after_walk: int = STAGE_WORK
var _wait: float = 0.0


func _init(mounds: Mounds, works: Works, fittings: Fittings, figure: Figure, datum_m: Vector2, who: String) -> void:
	"""To work `mounds` (with the works' rooms and the confirmed furniture), drawn inside as `figure`, cells from
	`datum_m` (m); `who` names it. It walks first to the yard of the first Mound with work."""
	_mounds = mounds
	_works = works
	_fittings = fittings
	_figure = figure
	_datum_m = datum_m
	_who = who
	var first: Dictionary = Jobs.next_job(mounds, fittings)
	if not first.is_empty():
		_aim_at(int(first["door"]))


func _aim_at(door_row: int) -> void:
	"""Work from door row `door_row`'s yard."""
	var door: Vector3i = _mounds.edges_of(door_row)[0]
	_station = Front.station_of(door, _datum_m)
	_door_cell = Mound.cell_of(door)


func site(brain: RefCounted) -> Vector2:
	"""The yard of the Mound it works on (where it stands: no work, no walk)."""
	return _station if _station.is_finite() else (brain as BrainScript).position


func arrived(_brain: RefCounted) -> void:
	"""At the yard: what next."""
	stage = STAGE_PLAN


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of the work; false once it has come out with nothing left."""
	var walker: BrainScript = brain as BrainScript
	match stage:
		STAGE_PLAN:
			_plan(walker)
		STAGE_WALK:
			_walk(walker, walker.walk_speed * delta)
		STAGE_WORK:
			_work(walker, delta)
		STAGE_OUT:
			_come_out(walker)
			return false
	return true


func _plan(walker: BrainScript) -> void:
	"""The next job: walked to (another Mound's yard, a cell inside, out to the door), or begun here; none: out."""
	job = Jobs.next_job(_mounds, _fittings, _at if _inside else Jobs.NOWHERE)
	if job.is_empty():
		_leave(STAGE_OUT, walker)
		return
	var door: Vector3i = _mounds.edges_of(int(job["door"]))[0]
	if Front.station_of(door, _datum_m) != _station:
		_leave(STAGE_PLAN, walker)
		if not _inside:
			_aim_at(int(job["door"]))
			stage = STAGE_GOING
			walker.task_walk_to(_station)
		return
	if Mounds.JOB_INSIDE[int(job["kind"])]:
		_go_in(walker)
		_walk_path(job["path"], STAGE_WORK)
	elif _inside:
		_leave(STAGE_PLAN, walker)
	else:
		_begin_work(walker)


func _leave(then: int, walker: BrainScript) -> void:
	"""Out of the hill before `then`: walk the figure back to the door's cell (then come out), or straight on."""
	if not _inside:
		stage = then
		return
	var back: Array[Vector2i] = Jobs.walk_to_any(_mounds, _at, {_door_cell: true})
	if back.size() <= 1:
		_come_out(walker)
		stage = then
		return
	_walk_path(back, then)


func _go_in(walker: BrainScript) -> void:
	"""In at the door: the resident indoors, its figure on the door's cell."""
	if _inside:
		return
	_inside = true
	_at = _door_cell
	walker.task_go_indoors(true, BrainScript.INTERIOR_NONE)
	_figure.set_layer(Layers.SURFACE)
	_figure.show_as(_who, world_of(_at))
	_figure.set_sink(0.0)


func _walk_path(path: Array[Vector2i], then: int) -> void:
	"""Walk `path` (from where the figure stands), then go to `then`."""
	_path = path
	_next = 0
	_after_walk = then
	stage = STAGE_WALK


func _walk(walker: BrainScript, stride: float) -> void:
	"""Along `_path` at walk speed, cell middle to cell middle; at its end, what comes after."""
	while _next < _path.size() and stride > 0.0:
		var to: Vector3 = world_of(_path[_next]) - _figure.position
		if to.length() <= stride:
			_figure.move_to(world_of(_path[_next]))
			_at = _path[_next]
			stride -= to.length()
			_next += 1
		else:
			_figure.move_to(_figure.position + to.normalized() * stride)
			stride = 0.0
	if _next >= _path.size():
		_arrive(walker)


func _arrive(walker: BrainScript) -> void:
	"""The walk's end: work, or (walking out) come out at the door and go on."""
	if _after_walk == STAGE_WORK:
		_wait = JOB_SECONDS[int(job["kind"])]
		_figure.set_digging(true)
		stage = STAGE_WORK
		return
	_come_out(walker)
	stage = _after_walk


func _begin_work(walker: BrainScript) -> void:
	"""A job from the yard: face the door, at work, for its wait."""
	walker.task_play(WORK_CLIP)
	_wait = JOB_SECONDS[int(job["kind"])]
	stage = STAGE_WORK


func _work(walker: BrainScript, delta: float) -> void:
	"""The wait, then the job done; then what next."""
	if not _inside:
		walker.task_face(Vector2(world_of(_door_cell).x, world_of(_door_cell).z), delta)
	_wait -= delta
	if _wait > 0.0:
		return
	if apply(job):
		done += 1
	_figure.set_digging(false)
	job = {}
	stage = STAGE_PLAN


func apply(done_job: Dictionary) -> bool:
	"""What a finished job changes: a cell one stage on (a dug one opened in the works), a door or window fitted, or a
	piece of furniture fitted. False when it changed nothing (the job was gone)."""
	var kind: int = int(done_job["kind"])
	var cell: Vector2i = done_job["cell"]
	if kind == Mounds.JOB_FIT_EDGE:
		return _mounds.fit_edge(_mounds.row_at(done_job["edge"]))
	if kind == Mounds.JOB_FIT_PIECE:
		return _fittings.fit(int(done_job["row"]))
	if kind == Mounds.JOB_DIG:
		_works.open_cell(Mound.SURFACE, cell)
	return _mounds.advance(cell, Mounds.JOB_STAGE[kind])


func _come_out(walker: BrainScript) -> void:
	"""Out at the door: the figure gone, the resident drawn again."""
	_inside = false
	_figure.visible = false
	walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)


func world_of(cell: Vector2i) -> Vector3:
	"""A cell's middle on the Surface, metres."""
	return Vector3(_datum_m.x + cell.x + 0.5, 0.0, _datum_m.y + cell.y + 0.5)


func finish(brain: RefCounted) -> void:
	"""The work is over."""
	_come_out(brain as BrainScript)


func cancel(brain: RefCounted) -> void:
	"""Called away: out at once (what was done stays done; the rest waits for the next trip)."""
	_come_out(brain as BrainScript)


func holds_when_lost() -> bool:
	"""Lost on the way to the yard, it goes back to its routine; the build panel sends one again."""
	return false


func inside() -> bool:
	"""Whether it is inside the hill now (checks)."""
	return _inside


func at() -> Vector2i:
	"""The cell its figure stands on inside (checks)."""
	return _at


func label() -> String:
	"""What the panel says."""
	if stage == STAGE_GOING:
		return "Going to the Mound to build it"
	var words: String = Jobs.words(job, _mounds)
	return "Building the Mound: %s" % words.to_lower() if not words.is_empty() else "Building the Mound"
