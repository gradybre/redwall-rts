extends "res://demo/work/work_source.gd"
## The hall's projects as the work board reads them (decision 0771; see work_source.gd): each PLACE on a project -- the
## tier-2 upgrade's four builders (§5.9's maximum), one per banner -- is a task, worked by one resident through the
## hall's crew (demo/hall/hall_crew.gd), which keeps every number; the board claims a waiting place for an idle
## eligible resident (anybeast on land, LORE-P12; the Builders crew first). Pause and Reassign are the crew's own; a
## project is cancelled as a whole in the hall's panel, where REQ-SET-126's refund is shown, never one place at a time.

const HallRules := preload("res://demo/hall/hall_rules.gd")
const HallCrew := preload("res://demo/hall/hall_crew.gd")
const HallProjects := preload("res://demo/hall/hall_projects.gd")

const CANCEL_IN_PANEL: String = "cancel the whole project in the hall's panel (click the hall): REQ-SET-126 gives " \
	+ "its materials back"

var _crew: HallCrew = null
var _projects: HallProjects = null
## Where the hall stands (presentation metres): a place's distance decides between equals, and "Go to" eases there.
var _hall_at: Vector2 = Vector2.ZERO


func _init(crew: HallCrew, projects: HallProjects, hall_at: Vector2) -> void:
	"""Read these projects and their crew; the hall stands at `hall_at`."""
	id = WorkIds.SOURCE_HALL
	_crew = crew
	_projects = projects
	_hall_at = hall_at


func capacity() -> int:
	"""Every project's places."""
	return HallRules.ROWS


func live(row: int) -> bool:
	"""A place on a project being delivered or built that is worked, waits for hands, or was paused -- and always the
	project's first place, so a project with nothing to do for now still shows why (its other idle places do not)."""
	var p: int = HallRules.row_project(row)
	if not _projects.is_active(p):
		return false
	return row == HallRules.first_row(p) or _crew.worker[row] >= 0 or _crew.waiting(row) or _crew.is_paused(row)


func key(row: int) -> int:
	"""The place in its project's planning."""
	return _crew.key(row)


func worker(row: int) -> int:
	"""The resident on the place."""
	return _crew.worker[row] if row >= 0 and row < HallRules.ROWS else -1


func activity(_row: int) -> int:
	"""The hall's projects are BUILDING."""
	return WorkIds.ACT_BUILD


func point(_row: int) -> Vector2:
	"""The hall."""
	return _hall_at


func waiting(row: int) -> bool:
	"""hall_crew.gd `waiting`."""
	return row >= 0 and row < HallRules.ROWS and _crew.waiting(row)


func eligibility(_row: int, who: int) -> String:
	"""hall_crew.gd `eligibility`: on land, free of the rescue, on no other place of the hall."""
	return _crew.eligibility(who)


func claim(row: int, who: int) -> bool:
	"""hall_crew.gd `give`."""
	return _crew.give(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The place's record: the project, who works it and its step, the work left."""
	task.reset(id, row)
	var p: int = HallRules.row_project(row)
	task.key = _crew.key(row)
	task.action = HallCrew.project_verb(p)
	task.target = "the hall" if p == HallRules.PROJECT_UPGRADE else "banner %d" % (p - HallRules.PROJECT_BANNER_FIRST + 1)
	task.worker = worker(row)
	task.activity = WorkIds.ACT_BUILD
	task.carrying = _crew.carrying(row)
	task.point = _hall_at
	task.remaining_usec = _projects.work_left_usec(p)
	task.percent = _projects.percent(p)
	task.cancel_refusal = CANCEL_IN_PANEL
	if task.worker < 0:
		waiting_state_into(task, _crew.is_paused(row), _blocked_words(row))
		return
	var brain: BrainScript = _crew.brain_of(task.worker)
	worker_state_into(task, brain, _crew.walking(row), _crew.issued[row] == 1)


func _blocked_words(row: int) -> String:
	"""Why a free place waits with nothing to do ("" when it can be taken): the rest of the materials are on their way,
	or the stores are out of what is still needed."""
	if _crew.wanted(row):
		return ""
	var p: int = HallRules.row_project(row)
	for mat: int in HallRules.MAT_COUNT:
		if _projects.outstanding(p, mat) > 0:
			return "waiting for %s: the stores have none to spare" % HallRules.MAT_NAMES[mat]
	return "the rest of the materials are on their way"


func pause(row: int, on: bool) -> String:
	"""hall_crew.gd `pause`."""
	return _crew.pause(row, on)


func cancel(_row: int) -> String:
	"""Not one place at a time (CANCEL_IN_PANEL)."""
	return CANCEL_IN_PANEL


func reassign(row: int, who: int) -> String:
	"""hall_crew.gd `reassign`."""
	return _crew.reassign(row, who)
