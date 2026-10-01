extends "res://demo/work/work_source.gd"
## The rooms' fit-out as the work board reads it (decision 0411; see work_source.gd): each planned fixture is a task
## (room_fixtures.gd), put in by one resident (install_task.gd). The fit-out keeps its own hand-out (fixture_crew.gd:
## the nearest free resident who can reach the room, a place KEPT for whoever was called away from it), so the board
## lists it and lets the player hand a waiting fixture to someone; pausing and cancelling stay the room panel's own
## ("take it out" gives its cost back).

const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const FixtureCrewScript := preload("res://demo/burrow/fixture_crew.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const ROOM_PANEL: String = "take it out in the room's fit-out (Tunnels panel): its cost comes back"
const KEPT_FOR: String = "kept for %s, who was called away from it"
const UNDER_WAY: String = "someone is putting it in — it can be handed over once it waits"
const CANT_REACH_ROOM: String = "can't reach the room (its body fits no way in)"

var _graph: RefCounted = null
var _crew: FixtureCrewScript = null
var _brains: Array = []
## `name_of(who) -> String`.
var _name_of: Callable = Callable()


func _init(graph: RefCounted, crew: FixtureCrewScript, brains: Array, name_of: Callable) -> void:
	"""Read this network's fit-out and its crew, worked by these residents' brains; `name_of(who)` names a resident."""
	id = WorkIds.SOURCE_FIT_OUT
	_graph = graph
	_crew = crew
	_brains = brains
	_name_of = name_of


func capacity() -> int:
	"""Every room's places."""
	return RoomsScript.MAX_ROOMS * FixturesScript.PLACES


func live(row: int) -> bool:
	"""A planned place."""
	return _fit().phase_of(_graph, row / FixturesScript.PLACES, row % FixturesScript.PLACES) == FixturesScript.PLANNED


func key(row: int) -> int:
	"""The place (a place is planned once until put in or taken out)."""
	return row


func worker(row: int) -> int:
	"""The resident putting it in."""
	return _fit().worker[row]


func activity(_row: int) -> int:
	"""Fit-out is BUILDING."""
	return WorkIds.ACT_BUILD


func point(row: int) -> Vector2:
	"""The room's middle."""
	return _graph.node_m(_graph.rooms.middle[row / FixturesScript.PLACES])


func eligibility(row: int, who: int) -> String:
	"""One who can walk into the room."""
	return "" if _crew.can_reach(who, row / FixturesScript.PLACES) else CANT_REACH_ROOM


func fill(task: TaskScript, row: int) -> void:
	"""The fixture's record."""
	task.reset(id, row)
	var r: int = row / FixturesScript.PLACES
	var kind: int = _fit().kind_at(_graph, r, row % FixturesScript.PLACES)
	task.key = row
	task.action = "Put in a %s" % RoomsScript.FIXTURE_NAMES[kind]
	task.target = "%s %d" % [RoomsScript.NAMES[_graph.rooms.template[r]], r + 1]
	task.worker = _fit().worker[row]
	task.activity = WorkIds.ACT_BUILD
	task.point = point(row)
	var total: int = FixturesScript.install_usec(kind)
	task.remaining_usec = maxi(total - _fit().work_usec[row], 0)
	task.percent = mini(100, int(_fit().work_usec[row] * 100 / maxi(total, 1)))
	task.pause_refusal = ROOM_PANEL
	task.cancel_refusal = ROOM_PANEL
	if task.worker >= 0:
		task.reassign_refusal = UNDER_WAY
		var brain: BrainScript = _brains[task.worker]
		worker_state_into(task, brain, brain.state != BrainScript.State.TASK, true)
		return
	var kept: int = _fit().asked[row]
	waiting_state_into(task, false, "")
	if kept >= 0:
		task.reason = KEPT_FOR % String(_name_of.call(kept))


func reassign(row: int, who: int) -> String:
	"""Hand the waiting fixture to `who` (fixture_crew.gd `give`: taken off whatever it was doing)."""
	if not live(row):
		return WorkIds.NOT_FOUND
	if _fit().worker[row] >= 0:
		return UNDER_WAY
	var why: String = eligibility(row, who)
	if not why.is_empty():
		return why
	return "" if _crew.give(row, who) else "the water's rescue holds them"


func _fit() -> FixturesScript:
	"""The network's fit-out."""
	return _graph.fit
