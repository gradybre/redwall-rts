extends "res://demo/work/work_source.gd"
## The infirmary building's work as the work board reads it (decision 0623 with 0411; see work_source.gd): its places
## (demo/infirmary/infirmary_builders.gd) -- fetching its materials and building it. Each WAITS and is claimed like the
## farm's: as HAULING while it fetches and BUILDING while it builds. Every command is the builders' own (`claim`,
## `pause`, `reassign`), so a load in hand is set down first and never handed over from afar. A place is cancelled with
## the infirmary (the Tunnels panel's Cancel, REQ-SET-126), not alone. The cellar building's places' adapter (decision
## 0612, stores_work.gd), for one building.

const BuildersScript := preload("res://demo/infirmary/infirmary_builders.gd")
const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const Rules := preload("res://demo/infirmary/infirmary_rules.gd")

const BUILD_ACTIONS: Array[String] = ["", "Fetch materials for", "Build"]
const BY_ITS_BUILDING: String = "the infirmary's work is cancelled with it (the Tunnels panel's Cancel)"

var _builders: BuildersScript = null
var _brains: Array[BrainScript] = []


func _init(builders: BuildersScript, brains: Array[BrainScript]) -> void:
	"""Read these builders' places, worked by these brains."""
	id = WorkIds.SOURCE_CARE
	_builders = builders
	_brains = brains


func capacity() -> int:
	"""The infirmary's places."""
	return BuildersScript.capacity()


func live(row: int) -> bool:
	"""Whether place `row` is on the board."""
	return _builders.is_live(row)


func key(row: int) -> int:
	"""The infirmary's life and the slot, kept through claims, nights and call-aways, so the player's priority and URGENT
	stay with it (the cellar building's rule)."""
	return _projects().generation * BuildersScript.capacity() + row


func worker(row: int) -> int:
	"""The place's resident."""
	return _builders.worker[row]


func activity(row: int) -> int:
	"""A place fetching is HAULING; building, BUILDING."""
	return WorkIds.ACT_BUILD if _projects().state == ProjectsScript.STATE_BUILDING else WorkIds.ACT_HAUL


func point(_row: int) -> Vector2:
	"""Where the infirmary stands."""
	return _projects().at


func waiting(row: int) -> bool:
	"""The builders' own test."""
	return _builders.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""The builders' own: anybeast who can carry, one place each."""
	return _builders.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""The builders' own claim."""
	return _builders.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The task's record: fetching for or building the infirmary, who has it, how far it has got."""
	task.reset(id, row)
	task.key = key(row)
	task.worker = worker(row)
	task.activity = activity(row)
	task.point = point(row)
	task.action = BUILD_ACTIONS[mini(_projects().state, 2)]
	task.target = Rules.LABEL.to_lower()
	task.carrying = _builders.carrying(row)
	task.percent = _projects().percent()
	task.cancel_refusal = BY_ITS_BUILDING
	if task.worker == BuildersScript.NOBODY:
		waiting_state_into(task, _builders.paused[row] == 1, "")
	else:
		var at_step: int = _builders.step[row]
		var walking: bool = at_step == BuildersScript.STEP_TO_STORE or at_step == BuildersScript.STEP_CARRY \
			or at_step == BuildersScript.STEP_TO_WORK
		worker_state_into(task, _brains[task.worker], walking, _builders.issued[row] == 1)
	if task.carrying:
		task.pause_refusal = BuildersScript.IN_HAND
		task.reassign_refusal = BuildersScript.IN_HAND


func pause(row: int, on: bool) -> String:
	"""The builders' own pause."""
	return _builders.pause(row, on)


func cancel(_row: int) -> String:
	"""A place is cancelled with the infirmary."""
	return BY_ITS_BUILDING


func reassign(row: int, who: int) -> String:
	"""The builders' own reassign."""
	return _builders.reassign(row, who)


func _projects() -> ProjectsScript:
	"""The infirmary the places build."""
	return _builders.projects
