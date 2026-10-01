extends "res://demo/work/work_source.gd"
## The food stores' moves as the work board reads it (decision 0611 with 0411; see work_source.gd): surplus food carried
## from a warmer store into a cool cellar (demo/stores/cellar_haul.gd). A planned move WAITS and is claimed like the
## farm's, as HAULING; every command is the haul's own (`claim`, `pause`, `cancel`, `reassign`), so a load in hand is
## shelved first and never handed over from afar.

const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")

const ACTION: String = "Move to a cooler store"
const TARGET: String = "%s of %s: %s → %s (keeps %s as long)"
const GONE: String = "(gone)"

var _haul: HaulScript = null
var _pantry: PantryScript = null
var _brains: Array[BrainScript] = []


func _init(haul: HaulScript, pantry: PantryScript, brains: Array[BrainScript]) -> void:
	"""Read this haul's moves in this pantry, worked by these residents' brains."""
	id = WorkIds.SOURCE_STORES
	_haul = haul
	_pantry = pantry
	_brains = brains


func capacity() -> int:
	"""The haul's rows."""
	return HaulScript.MAX_ROWS


func live(row: int) -> bool:
	"""Whether `row` holds a move."""
	return _haul.is_live(row)


func key(row: int) -> int:
	"""The move's serial."""
	return _haul.serial[row]


func worker(row: int) -> int:
	"""The move's carrier."""
	return _haul.worker[row]


func activity(_row: int) -> int:
	"""Moving food between stores is HAULING."""
	return WorkIds.ACT_HAUL


func point(row: int) -> Vector2:
	"""Where the food is: its store, or, in hand, the store it goes to."""
	var at: int = _haul.destination_of(row) if _haul.is_carrying(row) else _haul.source_of(row)
	return _pantry.storage.position_of(at) if at != HaulScript.NONE else Vector2.ZERO


func waiting(row: int) -> bool:
	"""The haul's own test (cellar_haul.gd `waiting`)."""
	return _haul.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""cellar_haul.gd `eligibility`: anybeast who can carry, one move each."""
	return _haul.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""cellar_haul.gd `claim`."""
	return _haul.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The move's record: what goes where and why, who carries it, its phase in words."""
	task.reset(id, row)
	task.key = key(row)
	task.action = ACTION
	task.target = target_words(row)
	task.worker = _haul.worker[row]
	task.activity = WorkIds.ACT_HAUL
	task.carrying = _haul.is_carrying(row)
	task.point = point(row)
	task.remaining_usec = HaulScript.SHELVE_USEC + (0 if task.carrying else HaulScript.PICK_USEC)
	if task.worker == HaulScript.NOBODY:
		waiting_state_into(task, _haul.paused[row] == 1, "")
	else:
		var step: int = _haul.step[row]
		var walking: bool = step == HaulScript.STEP_GO or step == HaulScript.STEP_CARRY
		worker_state_into(task, _brains[task.worker], walking, _haul.issued[row] == 1)
	if task.carrying:
		task.pause_refusal = HaulScript.IN_HAND_WORDS
		task.cancel_refusal = HaulScript.IN_HAND_WORDS
		task.reassign_refusal = HaulScript.IN_HAND_WORDS


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
	"""cellar_haul.gd `pause`."""
	return _haul.pause(row, on)


func cancel(row: int) -> String:
	"""cellar_haul.gd `cancel`."""
	return _haul.cancel(row)


func reassign(row: int, who: int) -> String:
	"""cellar_haul.gd `reassign`."""
	return _haul.reassign(row, who)
