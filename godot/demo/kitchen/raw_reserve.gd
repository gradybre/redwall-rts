extends RefCounted
## THE RAW RESERVE: "eaten raw: N days" beside the HUD's Ready food (decision 1736; Brendan's ruling of 2026-10-07 on
## the balance rerun's P7 (a)). Ready food (kitchen.gd `days_of_meals_milli`) counts only what the kitchen's plain dishes
## would cook -- grain, roots, fish, beans and greens -- so a pantry full of berries, fruit, honey, jam or cheese read
## "0 days" (the rerun: 0.00 in every season, with up to 161 U in store). This figure is shown BESIDE it, never added to
## it: no rule changes, and the two never count the same food.
##
## THE FIGURE. Every raw-edible category (meal_rules.gd RAW_NP_PER_U) that no plain meal dish takes (so not one Ready
## food already counts): its food nobody has set aside (ingredient_takes.gd `free_milli_of_crop`) at its raw NP a unit,
## summed, over a day of the village's portions at a plain portion's NP (PORTION_NP: porridge's and the soup's 1800) --
## in thousandths of a day, floored, as Ready food is. The HUD reads it through `hourly_days_milli`: worked out at most
## once a game hour (the pantry keeps no revision to watch, and a pass over its lots per category is too dear a frame).

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

## A plain portion's NP: the porridge's and Togget's soup's (dish_book.gd), the measure a day of portions is taken in.
const PORTION_NP: int = 1800

var _kitchen: KitchenScript = null
## The raw-edible categories Ready food does not count, and each one's raw NP a unit (built once).
var _categories: PackedInt32Array = PackedInt32Array()
var _np: PackedInt32Array = PackedInt32Array()
## The figure as last worked out, and the game hour it was (-1: never).
var _cached: int = 0
var _cached_hour: int = -1


func _init(kitchen: KitchenScript) -> void:
	"""The reserve of `kitchen`'s pantry (null: always 0)."""
	_kitchen = kitchen
	var cooked: int = cooked_categories()
	for category: Variant in MealRules.RAW_NP_PER_U:
		var c: int = int(category)
		if cooked & (1 << c) == 0:
			_categories.append(c)
			_np.append(int(MealRules.RAW_NP_PER_U[category]))


static func cooked_categories() -> int:
	"""The categories Ready food counts, one bit a category: every input of every plain meal dish (its estimate's
	dishes: kitchen.gd THE READY-FOOD ESTIMATE)."""
	var mask: int = 0
	for dish: int in MealRules.DISH_COUNT:
		if MealRules.PLAIN[dish] == 1 and MealRules.is_meal_dish(dish):
			for k: int in MealRules.INPUT_N[dish]:
				mask |= MealRules.input_categories(dish, k)
	return mask


func np_total() -> int:
	"""The free raw-edible food Ready food does not count, in NP."""
	if _kitchen == null or _kitchen.pantry == null:
		return 0
	var total: int = 0
	for k: int in _categories.size():
		@warning_ignore("integer_division")
		total += _kitchen.takes.free_milli_of_crop(_kitchen.pantry, _categories[k]) * _np[k] / 1000
	return total


func days_milli() -> int:
	"""THE FIGURE: days of the village's portions the raw reserve would feed, in thousandths, floored (0 with nobody)."""
	if _kitchen == null:
		return 0
	var daily: int = _kitchen.daily_portions() * PORTION_NP
	if daily <= 0:
		return 0
	@warning_ignore("integer_division") return np_total() * 1000 / daily


func hourly_days_milli() -> int:
	"""THE FIGURE, worked out at most once a game hour (see THE FIGURE): what the HUD shows and stamps."""
	if _kitchen == null:
		return 0
	var hour: int = _kitchen.hour_index()
	if hour != _cached_hour:
		_cached_hour = hour
		_cached = days_milli()
	return _cached


func categories() -> PackedInt32Array:
	"""The categories counted (checks)."""
	return _categories
