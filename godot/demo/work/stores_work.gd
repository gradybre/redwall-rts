extends "res://demo/work/work_source.gd"
## The food stores' work as the work board reads it (decisions 0611, 0612 with 0411; see work_source.gd), one source:
## its first rows are the haul's MOVES -- surplus food carried from a warmer store into a cooler one
## (demo/stores/cellar_haul.gd) -- and the rest the cellar buildings' PLACES -- fetching their materials and building them
## (demo/stores/cellar_builders.gd), when they are given. Both WAIT and are claimed like the farm's: a move as HAULING, a
## place as HAULING while it fetches and BUILDING while it builds. Every command is the owner's own (`claim`, `pause`,
## `cancel`, `reassign`), so a load in hand is set down first and never handed over from afar. A cellar's place is
## cancelled with its cellar (the Pantry's Cancel, REQ-SET-126), not alone.

const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const BuildersScript := preload("res://demo/stores/cellar_builders.gd")
const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const Rules := preload("res://demo/stores/cellar_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")

const ACTION: String = "Move to a cooler store"
const TARGET: String = "%s of %s: %s → %s (keeps %s as long)"
const GONE: String = "(gone)"
const BUILD_ACTIONS: Array[String] = ["", "Fetch materials for", "Build"]
const BY_ITS_CELLAR: String = "a cellar's work is cancelled with the cellar (the Pantry's Cancel)"
## Builder keys are kept apart from the moves' (the board keys a task by source, row and key).
const BUILD_KEY_BASE: int = 1 << 24

var _haul: HaulScript = null
var _builders: BuildersScript = null
var _pantry: PantryScript = null
var _brains: Array[BrainScript] = []


func _init(haul: HaulScript, pantry: PantryScript, brains: Array[BrainScript], builders: BuildersScript = null) -> void:
	"""Read this haul's moves in this pantry -- and `builders`' cellar places, when given -- worked by these brains."""
	id = WorkIds.SOURCE_STORES
	_haul = haul
	_pantry = pantry
	_brains = brains
	_builders = builders


func capacity() -> int:
	"""The haul's rows, then the cellar places."""
	return HaulScript.MAX_ROWS + (BuildersScript.capacity() if _builders != null else 0)


func _place(row: int) -> int:
	"""The cellar place `row` is, or -1 for a move."""
	return row - HaulScript.MAX_ROWS if row >= HaulScript.MAX_ROWS else -1


func live(row: int) -> bool:
	"""Whether `row` holds a move, or a place on the board."""
	var p: int = _place(row)
	return _builders.is_live(p) if p >= 0 else _haul.is_live(row)


func key(row: int) -> int:
	"""The move's serial; a cellar place's key is its cellar's life and its slot, kept through claims, nights and
	call-aways so the player's priority and URGENT stay with it (bridge_work.gd keys a bridge by its generation; the
	review's H3), apart from the moves'."""
	var p: int = _place(row)
	if p < 0:
		return _haul.serial[row]
	var c: int = BuildersScript.cellar_of(p)
	return BUILD_KEY_BASE + _projects().generation[c] * BuildersScript.capacity() + p


func worker(row: int) -> int:
	"""The move's carrier or the place's resident."""
	var p: int = _place(row)
	return _builders.worker[p] if p >= 0 else _haul.worker[row]


func activity(row: int) -> int:
	"""A move, or a place fetching, is HAULING; a place building is BUILDING."""
	var p: int = _place(row)
	if p >= 0 and _projects().state[BuildersScript.cellar_of(p)] == ProjectsScript.STATE_BUILDING:
		return WorkIds.ACT_BUILD
	return WorkIds.ACT_HAUL


func point(row: int) -> Vector2:
	"""Where the food is (its store, or in hand the store it goes to), or the cellar."""
	var p: int = _place(row)
	if p >= 0:
		return _projects().at[BuildersScript.cellar_of(p)]
	var at: int = _haul.destination_of(row) if _haul.is_carrying(row) else _haul.source_of(row)
	return _pantry.storage.position_of(at) if at != HaulScript.NONE else Vector2.ZERO


func waiting(row: int) -> bool:
	"""The owner's own test."""
	var p: int = _place(row)
	return _builders.waiting(p) if p >= 0 else _haul.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""The owner's own: anybeast who can carry, one move or place each."""
	var p: int = _place(row)
	return _builders.eligibility(p, who) if p >= 0 else _haul.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""The owner's own claim."""
	var p: int = _place(row)
	return _builders.claim(p, who) if p >= 0 else _haul.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The task's record: what it is, who has it, its phase in words."""
	task.reset(id, row)
	task.key = key(row)
	task.worker = worker(row)
	task.activity = activity(row)
	task.point = point(row)
	if _place(row) >= 0:
		_fill_place(task, _place(row))
	else:
		_fill_move(task, row)


func _fill_move(task: TaskScript, row: int) -> void:
	"""A move's record (see the header)."""
	task.action = ACTION
	task.target = target_words(row)
	task.carrying = _haul.is_carrying(row)
	task.remaining_usec = HaulScript.SHELVE_USEC + (0 if task.carrying else HaulScript.PICK_USEC)
	if task.worker == HaulScript.NOBODY:
		waiting_state_into(task, _haul.paused[row] == 1, "")
	else:
		var at_step: int = _haul.step[row]
		var walking: bool = at_step == HaulScript.STEP_GO or at_step == HaulScript.STEP_CARRY
		worker_state_into(task, _brains[task.worker], walking, _haul.issued[row] == 1)
	if task.carrying:
		task.pause_refusal = HaulScript.IN_HAND_WORDS
		task.cancel_refusal = HaulScript.IN_HAND_WORDS
		task.reassign_refusal = HaulScript.IN_HAND_WORDS


func _fill_place(task: TaskScript, p: int) -> void:
	"""A cellar place's record: fetching or building which cellar, how far it has got."""
	var c: int = BuildersScript.cellar_of(p)
	var projects: ProjectsScript = _projects()
	task.action = BUILD_ACTIONS[mini(projects.state[c], 2)]
	task.target = (Rules.LABEL % (c + 1)).to_lower()
	task.carrying = _builders.carrying(p)
	task.percent = projects.percent(c)
	task.cancel_refusal = BY_ITS_CELLAR
	if task.worker == BuildersScript.NOBODY:
		waiting_state_into(task, _builders.paused[p] == 1, "")
	else:
		var at_step: int = _builders.step[p]
		var walking: bool = at_step == BuildersScript.STEP_TO_STORE or at_step == BuildersScript.STEP_CARRY \
			or at_step == BuildersScript.STEP_TO_WORK
		worker_state_into(task, _brains[task.worker], walking, _builders.issued[p] == 1)
	if task.carrying:
		task.pause_refusal = BuildersScript.IN_HAND
		task.reassign_refusal = BuildersScript.IN_HAND


func target_words(row: int) -> String:
	"""'12.0 U of carrot: Covered store → Root cellar 1 (keeps 2.8× as long)'."""
	var from: int = _haul.source_of(row)
	var to: int = _haul.destination_of(row)
	var storage := _pantry.storage
	var gain: String = Text.keeps_text(storage.permille_of(from), storage.permille_of(to)) \
		if from != HaulScript.NONE and to != HaulScript.NONE else "?"
	return TARGET % [Text.units_text(_haul.milli[row]), Catalog.ITEM_LABELS[_haul.item[row]].to_lower(),
		storage.label_of(from) if from != HaulScript.NONE else GONE, storage.label_of(to) if to != HaulScript.NONE else GONE,
		gain]


func pause(row: int, on: bool) -> String:
	"""The owner's own pause."""
	var p: int = _place(row)
	return _builders.pause(p, on) if p >= 0 else _haul.pause(row, on)


func cancel(row: int) -> String:
	"""A move's own cancel; a cellar place is cancelled with its cellar."""
	return BY_ITS_CELLAR if _place(row) >= 0 else _haul.cancel(row)


func reassign(row: int, who: int) -> String:
	"""The owner's own reassign."""
	var p: int = _place(row)
	return _builders.reassign(p, who) if p >= 0 else _haul.reassign(row, who)


func _projects() -> ProjectsScript:
	"""The cellars the places build."""
	return _builders.projects
