extends "res://demo/tunnel/tunnel_task.gd"
## One resident putting one fixture in (fixture_crew.gd). Decision 0210 (the underground revamp's P4; install
## animations are P5's). Presentation only.
##
## It walks to the room's middle node through the network, strolls across the floor to stand before the fixture's
## place, facing it, and works there -- the work clip -- for the fixture's install time (room_fixtures.gd INSTALL_WU),
## counted on the fixtures' own row, so work done is kept if it is called away. Done, it strolls back to the middle and
## the task ends: the brain walks it out and it takes up whatever it parked (RESUMING). Called away, the fixture waits
## for whoever comes next, and this resident keeps it on its resume queue. A fixture taken out while it works (or
## put in by another) sends it back to the middle and out, with nothing to come back to.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const STAGE_GOING: int = 0
const STAGE_TO_PLACE: int = 1
const STAGE_WORKING: int = 2
const STAGE_BACK: int = 3
const WORK_CLIP: StringName = &"collect_object"
## The installer stands this far from the place toward the room's middle (m).
const STAND_OFF_M: float = 0.7

var stage: int = STAGE_GOING
var room: int = -1
var place: int = -1

var _graph: RefCounted = null
var _who: int = -1
var _at: Vector2 = Vector2.ZERO
var _middle: Vector2 = Vector2.ZERO


func _init(graph: RefCounted, r: int, f: int, who: int) -> void:
	"""Resident `who` puts in the fixture planned at place `f` of room `r` on `graph` (claimed already)."""
	_graph = graph
	room = r
	place = f
	_who = who
	var rooms: RoomsScript = graph.rooms
	var at := rooms.to_world_u(r, FixturesScript.place_u(rooms.template[r], f))
	_at = Vector2(Rules.to_m(at.x), Rules.to_m(at.y))
	_middle = graph.node_m(rooms.middle[r])


func stand_at() -> Vector2:
	"""Where the installer stands: STAND_OFF_M from the place toward the room's middle."""
	return _at + (_middle - _at).normalized() * STAND_OFF_M


func site_node(_brain: RefCounted) -> int:
	"""The room's middle node."""
	return _graph.rooms.middle[room]


func arrived(brain: RefCounted) -> void:
	"""In the room: across the floor to the place."""
	(brain as BrainScript).task_hold_below()
	stage = STAGE_TO_PLACE


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: walk to the place, work it in, walk back to the middle; false once back."""
	var walker := brain as BrainScript
	if stage == STAGE_TO_PLACE and walker.task_stroll_to(stand_at(), delta):
		stage = STAGE_WORKING
	elif stage == STAGE_WORKING:
		_work(walker, delta)
	elif stage == STAGE_BACK:
		return not walker.task_stroll_to(_middle, delta)
	return true


func _work(walker: BrainScript, delta: float) -> void:
	"""Work the fixture in; once it is in -- or no longer this resident's (taken out, or its row laid again) -- back
	to the middle."""
	var fit: FixturesScript = _graph.fit
	if fit.phase_of(_graph, room, place) != FixturesScript.PLANNED or fit.worker[room * FixturesScript.PLACES + place] != _who:
		stage = STAGE_BACK
		return
	walker.task_face(_at, delta)
	walker.task_play(WORK_CLIP)
	if fit.work(_graph, room, place, _who, int(delta * 1000000.0)):
		stage = STAGE_BACK


func cancel(_brain: RefCounted) -> void:
	"""Called away: the fixture waits for whoever comes next (its work so far kept)."""
	_graph.fit.let_go(room, place, _who)


func unfinished() -> RefCounted:
	"""The fixture to come back to, while it still waits (see the header)."""
	if stage == STAGE_BACK or _graph.fit.phase_of(_graph, room, place) != FixturesScript.PLANNED:
		return null
	return UnfinishedScript.new(take_back, "Put in the %s, %s %d" % [kind_name(), RoomsScript.NAMES[_graph.rooms.template[room]],
		room + 1])


func take_back(brain: RefCounted) -> bool:
	"""Put `brain` back on this fixture, if it is still planned and nobody else is on it."""
	var walker := brain as BrainScript
	if not _graph.fit.claim(_graph, room, place, walker.index):
		return false
	_who = walker.index
	stage = STAGE_GOING
	walker.order_task(self)
	return true


func kind_name() -> String:
	"""The fixture's kind, in words."""
	return RoomsScript.FIXTURE_NAMES[FixturesScript.place_kind(_graph.rooms.template[room], place)]


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine rather than holding (tunnel_task.gd)."""
	return false


func label() -> String:
	"""What the panel says."""
	var where := "%s %d" % [RoomsScript.NAMES[_graph.rooms.template[room]], room + 1]
	if stage == STAGE_WORKING:
		return "Putting in the %s (%s)" % [kind_name(), where]
	return "Fitting out %s: the %s" % [where, kind_name()]
