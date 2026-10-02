extends "res://demo/orders/order_goal.gd"
## KEEP N U OF A CROP HARVESTED (decision 0711): the pantry's stock of one crop item, raised by HARVESTING its ripe
## beds -- the farm's own harvest job (the farm's routine already opens one for every ripe bed, REQ-SET-073; the order
## adopts it, or opens it through farm_crew.gd `order` with nobody selected, as a bed's right-click does). Sowing is the
## farm's (and its sowing policies'), never the order's. A crop an everyday dish takes is food: its jobs are in the work
## board's food bucket while food-days are under two (REQ-SET-113). An occasion's course alone, a drink or a dish still
## waiting for an ingredient does not make a crop food (meal_rules.gd `is_everyday_dish`; decision 0902).

const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

## REQ-SET-113: "While food-days are below 2" (milli-days).
const FOOD_URGENT_BELOW: int = 2000
const NONE_RIPE: String = "no %s bed is ripe yet (%d growing) — the order harvests it when it ripens"
const NONE_GROWING: String = "no %s is growing — sow some from a bed's panel"

var _crew: FarmCrewScript = null
var _sim: SimScript = null
var _pantry: PantryScript = null
## `food_days() -> int`: the kitchen's Ready food in milli-days (kitchen.gd `days_of_meals_milli`).
var _food_days: Callable = Callable()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _nobody: PackedInt32Array = PackedInt32Array()


func _init(crew: FarmCrewScript, sim: SimScript, pantry: PantryScript, food_days: Callable = Callable()) -> void:
	"""Over this farm crew, its beds and its pantry; `food_days()` the kitchen's Ready food (none: never urgent)."""
	kind = Kinds.KIND_CROP
	source = WorkIds.SOURCE_FARM
	_crew = crew
	_sim = sim
	_pantry = pantry
	_food_days = food_days


static func is_meal_crop(item: int) -> bool:
	"""Whether an everyday dish takes `item` (meal_rules.gd `is_input`, `is_everyday_dish`): read from the dishes' own
	data."""
	if not Catalog.is_item(item):
		return false
	for dish: int in MealRules.DISH_COUNT:
		if MealRules.is_everyday_dish(dish) and MealRules.is_input(dish, item):
			return true
	return false


func measure(item: int) -> int:
	"""The crop in store."""
	return _pantry.milli_of(item) if Catalog.is_item(item) else 0


func food_short() -> bool:
	"""REQ-SET-113's condition: food-days under two."""
	return _food_days.is_valid() and int(_food_days.call()) < FOOD_URGENT_BELOW


func urgent(item: int) -> bool:
	"""A food crop's harvests while food-days are under two."""
	return is_meal_crop(item) and food_short()


func key_of(row: int) -> int:
	"""The farm job's serial."""
	return _crew.jobs.serial[row]


func live(row: int, job_key: int) -> bool:
	"""The same job (its serial) is still on the farm's board (a harvest turned delivery keeps it)."""
	return _crew.jobs.is_live(row) and _crew.jobs.serial[row] == job_key


func output_of(row: int, _item: int) -> int:
	"""A cut load in hand, else the ripe bed's expected harvest."""
	if _crew.jobs.load_milli[row] > 0:
		return _crew.jobs.load_milli[row]
	if _crew.jobs.kind[row] == FarmJobs.KIND_HARVEST and _sim.expected_yield_into(_crew.jobs.bed[row], _read):
		return _read.value
	return 0


func wants_bed(bed: int, item: int) -> bool:
	"""Whether a crop in `bed` is one this order harvests."""
	return _sim.item_of(bed) == item


func raise_into(item: int, tracked: Callable, out: IntMath.IntResult) -> String:
	"""The first ripe bed of the crop whose harvest no order holds: its harvest adopted, or opened."""
	for bed: int in Catalog.BED_COUNT:
		if not wants_bed(bed, item) or _sim.stage_of(bed) != SimScript.STAGE_RIPE:
			continue
		if not _crew.jobs.job_on_bed_into(FarmJobs.KIND_HARVEST, bed, _read):
			_crew.order(FarmJobs.KIND_HARVEST, bed, _nobody, FarmJobs.ORIGIN_PLAYER)
			if not _crew.jobs.job_on_bed_into(FarmJobs.KIND_HARVEST, bed, _read):
				continue
		if bool(tracked.call(source, _crew.jobs.serial[_read.value])):
			continue
		out.succeed(_read.value)
		return ""
	return none_words(item)


func growing_count(item: int) -> int:
	"""Beds with the crop sown or growing (not yet ripe)."""
	var count: int = 0
	for bed: int in Catalog.BED_COUNT:
		var stage: int = _sim.stage_of(bed)
		if wants_bed(bed, item) and stage >= SimScript.STAGE_SOWN and stage <= SimScript.STAGE_GROWING:
			count += 1
	return count


func none_words(item: int) -> String:
	"""Why no harvest can be raised: nothing ripe yet, or nothing growing."""
	var growing: int = growing_count(item)
	var crop_name: String = Kinds.good_name(Kinds.KIND_CROP, item)
	return NONE_RIPE % [crop_name, growing] if growing > 0 else NONE_GROWING % crop_name
