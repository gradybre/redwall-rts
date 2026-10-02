extends "res://demo/work/work_source.gd"
## The kitchen's cooking and water drawing as the work board reads them (decision 0411's adapter for decision 0381's
## kitchen; see work_source.gd): a row a resident, live while the kitchen has it on the cook's round or drawing water.
## The kitchen hands both out itself -- the cook, a stand-in, the nearest free resident to the well -- so nothing waits
## to be claimed, and the board's commands refuse with the way to change it: the Pantry's Kitchen tab (Cook, Draw
## water, KEEP WATER DRAWN) or another order for the resident. A diner at the table is a meal, not work: it is not
## listed (the board keeps it out of claims through `set_needs_gate`, `kept_for_meals`).

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

const COOK_ACTION: String = "Cook"
const DRAW_ACTION: String = "Draw water"
const COOK_TARGET: String = "the village's meals"
const DRAW_TARGET: String = "the water butt by the well"
const BY_KITCHEN: String = "the kitchen runs its own round — Pantry (K) ▸ Kitchen, or give the resident another order"

var _kitchen: KitchenScript = null
var _brains: Array[BrainScript] = []


func _init(kitchen: KitchenScript, brains: Array[BrainScript]) -> void:
	"""Read this kitchen's cook and drawers, these residents' brains (by actor index, as the kitchen's)."""
	id = WorkIds.SOURCE_KITCHEN
	_kitchen = kitchen
	_brains = brains


func capacity() -> int:
	"""A row per resident."""
	return _brains.size()


func may_wait() -> bool:
	"""Never: the kitchen hands its parts out itself (see the header), so the board reads none of its rows for claims."""
	return false


func live(row: int) -> bool:
	"""The resident is on the cook's round or drawing water."""
	var role: int = _kitchen.role_of(row)
	return role == KitchenScript.ROLE_COOK or role == KitchenScript.ROLE_DRAW


func key(row: int) -> int:
	"""The resident and its part."""
	return row * 4 + _kitchen.role_of(row)


func worker(row: int) -> int:
	"""The resident itself."""
	return row if live(row) else -1


func activity(_row: int) -> int:
	"""Fetching, carrying the pot and water: HAULING (the crews' nearest activity)."""
	return WorkIds.ACT_HAUL


func point(row: int) -> Vector2:
	"""The cauldron for the cook, the well for a drawer."""
	return _kitchen.places.well if _kitchen.role_of(row) == KitchenScript.ROLE_DRAW else _kitchen.places.cauldron


func fill(task: TaskScript, row: int) -> void:
	"""The row's record: its part, what it is doing in the kitchen's own words, its walk or work."""
	task.reset(id, row)
	var drawing: bool = _kitchen.role_of(row) == KitchenScript.ROLE_DRAW
	task.key = key(row)
	task.action = DRAW_ACTION if drawing else COOK_ACTION
	task.target = DRAW_TARGET if drawing else COOK_TARGET
	task.worker = row
	task.activity = WorkIds.ACT_HAUL
	task.carrying = _kitchen.carried_item(row) != Catalog.NO_ITEM
	task.point = point(row)
	task.pause_refusal = BY_KITCHEN
	task.cancel_refusal = BY_KITCHEN
	task.reassign_refusal = BY_KITCHEN
	var step: int = _kitchen.step_of(row)
	var walking: bool = step > KitchenScript.STEP_DONE and step < KitchenScript.WORK_FIRST
	worker_state_into(task, _brains[row], walking, true)
	if task.reason.is_empty():
		task.reason = Words.doing(_kitchen, row)
