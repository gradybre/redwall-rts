extends RefCounted
## Each resident's NOURISHMENT: §5.2's hunger need, integer and authoritative for the demo, fed by real portions and
## drawn down by the hour. Decision 0381. Presentation only: the settlement's Needs store is not written.
##
## HUNGER is 0..10000 (meal_rules.gd THE NEED). Every game hour it falls by the rate scripts/core/family_rules.gd
## publishes for the resident's size class and the season (milli-points an hour, adult), with §5.2's remainder rule:
## the milli-points are accumulated and only whole points taken, the rest kept. Eating adds the portion's NP, clamped
## at 10000 "without refunding excess NP" (§5.2). NP eaten is also counted for the day (`today_np`), against the day's
## NEED (family_rules.gd `daily_demand_np_into`): "1800/6000 NP today".
##
## MEALS are remembered: the last HISTORY recipe ids (§5.7's variety), the last meal and whether it was eaten, skipped
## or eaten raw, and §5.7's MONOTONOUS MEMORY when it applies -- its value and the hour it lapses (a readout: the demo
## has no mood). Variety counts §5.7 RECIPES, not dishes (decision 0601): two dishes cooked as one §5.7 row are the same
## recipe -- "Ingredient differences inside the same recipe do not fake variety".
##
## TASTES (decision 0601; dish_favourites.gd): each resident's species' likes and dislikes, per dish, and whether the
## last portion it ate was a FAVOURITE -- noted on its card, counted, and summed for the cook's choice. Data and display
## only: a favourite adds no NP, mood or memory.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Tastes := preload("res://demo/kitchen/dish_favourites.gd")
const FamilyRules := preload("res://scripts/core/family_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const ADULT: int = 0
const NOTHING: int = -1
const OUTCOME_ATE: int = 0
const OUTCOME_SKIPPED: int = 1
const OUTCOME_RAW: int = 2
const MILLI: int = 1000

var hunger: PackedInt32Array = PackedInt32Array()
var size_class: PackedByteArray = PackedByteArray()
var today_np: PackedInt32Array = PackedInt32Array()
## Per resident: the last meal (meal_rules.gd meal_key) it ate or missed, and how (OUTCOME_*); NOTHING before any.
var last_meal: PackedInt32Array = PackedInt32Array()
## The meal before the last one recorded (`had_exact`: the cook may eat supper before breakfast's serving ends).
var prev_meal: PackedInt32Array = PackedInt32Array()
var last_outcome: PackedInt32Array = PackedInt32Array()
var last_dish: PackedInt32Array = PackedInt32Array()
## §5.7's monotonous memory: its value (0: none) and the calendar hour it lapses at.
var monotony: PackedInt32Array = PackedInt32Array()
var monotony_until: PackedInt32Array = PackedInt32Array()
## Meals eaten and missed so far, per resident.
var eaten: PackedInt32Array = PackedInt32Array()
var skipped: PackedInt32Array = PackedInt32Array()
## Per resident: 1 when the last portion it ate was one of its favourites (0 after anything else); favourites eaten.
var last_favourite: PackedByteArray = PackedByteArray()
var favourites_eaten: PackedInt32Array = PackedInt32Array()

var _accumulated: PackedInt64Array = PackedInt64Array()
## HISTORY recipe ids a resident, oldest first; NOTHING where none.
var _history: PackedInt32Array = PackedInt32Array()
## Per resident and dish (who x DISH_COUNT + dish): its species' taste, Tastes.LIKE, DISLIKE or 0.
var _taste: PackedInt32Array = PackedInt32Array()
var _day: int = 0
var _family: FamilyRules = FamilyRules.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(species: PackedStringArray) -> void:
	"""One resident per species name (meal_rules.gd SIZE CLASS), each starting fed."""
	var n: int = species.size()
	for column: PackedInt32Array in [hunger, today_np, last_meal, prev_meal, last_outcome, last_dish, monotony,
			monotony_until, eaten, skipped, favourites_eaten]:
		column.resize(n)
	last_favourite.resize(n)
	_configure_tastes(species)
	hunger.fill(Rules.START_HUNGER)
	last_meal.fill(NOTHING)
	prev_meal.fill(NOTHING)
	last_outcome.fill(NOTHING)
	last_dish.fill(Rules.NO_DISH)
	size_class.resize(n)
	for i: int in n:
		size_class[i] = Rules.size_of_species(species[i])
	_accumulated.resize(n)
	_history.resize(n * Rules.HISTORY)
	_history.fill(NOTHING)


func _configure_tastes(species: PackedStringArray) -> void:
	"""Each resident's taste for each dish, from its species (dish_favourites.gd)."""
	_taste.resize(species.size() * Rules.DISH_COUNT)
	for i: int in species.size():
		var row: int = Tastes.species_row(species[i])
		for dish: int in Rules.DISH_COUNT:
			_taste[i * Rules.DISH_COUNT + dish] = Tastes.taste(row, Rules.DISH_KEYS[dish])


func count() -> int:
	"""How many residents."""
	return hunger.size()


func taste_of(who: int, dish: int) -> int:
	"""Resident `who`'s taste for `dish`: Tastes.LIKE, DISLIKE or 0 (none for no dish)."""
	return _taste[who * Rules.DISH_COUNT + dish] if dish >= 0 and dish < Rules.DISH_COUNT else 0


func village_taste(dish: int) -> int:
	"""Everyone's tastes for `dish` summed: likes less dislikes (the cook's choice weighs it)."""
	var total: int = 0
	for i: int in count():
		total += taste_of(i, dish)
	return total


func likers_of(dish: int) -> int:
	"""How many residents like `dish`."""
	var n: int = 0
	for i: int in count():
		n += 1 if taste_of(i, dish) == Tastes.LIKE else 0
	return n


func hourly_milli(who: int, winter: bool) -> int:
	"""Resident `who`'s hunger fall an hour, milli-points (family_rules.gd's adult row for its size and season)."""
	_family.hunger_rate_milli_into(ADULT, size_class[who], winter, _read)
	return _read.value if _read.ok else 0


func daily_need(who: int, winter: bool) -> int:
	"""Resident `who`'s NP a day (6000 small, 7200 medium, 9600 large; x1.2 in winter)."""
	_family.daily_demand_np_into(ADULT, size_class[who], winter, _read)
	return _read.value if _read.ok else 0


func pass_hour(day: int, winter: bool, hour_index: int) -> void:
	"""One game hour on `day`: everyone's hunger falls (see HUNGER); a new day starts the day's count afresh; a
	monotonous memory past its hour lapses."""
	if day != _day:
		_day = day
		today_np.fill(0)
	for i: int in count():
		_accumulated[i] += hourly_milli(i, winter)
		@warning_ignore("integer_division") var whole: int = int(_accumulated[i] / MILLI)
		_accumulated[i] -= whole * MILLI
		hunger[i] = maxi(0, hunger[i] - whole)
		if hunger[i] == 0:
			_accumulated[i] = 0
		if monotony[i] != 0 and hour_index >= monotony_until[i]:
			monotony[i] = 0


func eat(who: int, np: int) -> int:
	"""`np` eaten by resident `who`: hunger up, clamped at NEED_MAX (no refund). Returns the NP that counted."""
	var counted: int = mini(maxi(np, 0), Rules.NEED_MAX - hunger[who])
	hunger[who] += counted
	today_np[who] += maxi(np, 0)
	if hunger[who] == Rules.NEED_MAX:
		_accumulated[who] = 0
	return counted


func ate_meal(who: int, meal_key: int, dish: int, hour_index: int) -> void:
	"""Resident `who` ate a portion of `dish` at meal `meal_key`: its NP (eat), the variety history and any
	monotonous memory (§5.7, counted over the meals before this one)."""
	var repeats: int = repeats_of(who, dish)
	eat(who, Rules.NP_PER_PORTION[dish])
	var memory: int = Rules.monotony_for(repeats)
	if memory != 0:
		monotony[who] = memory
		monotony_until[who] = hour_index + Rules.MONOTONY_HOURS
	_remember(who, dish)
	_outcome(who, meal_key, OUTCOME_ATE, dish)
	eaten[who] += 1
	if taste_of(who, dish) == Tastes.LIKE:
		last_favourite[who] = 1
		favourites_eaten[who] += 1


func ate_raw(who: int, meal_key: int, np: int) -> void:
	"""Resident `who` ate raw food worth `np` at meal `meal_key` (REQ-SET-013's emergency)."""
	eat(who, np)
	_outcome(who, meal_key, OUTCOME_RAW, Rules.NO_DISH)
	eaten[who] += 1


func missed(who: int, meal_key: int) -> void:
	"""Resident `who` went without meal `meal_key` (no food, or it could not get to the table)."""
	_outcome(who, meal_key, OUTCOME_SKIPPED, Rules.NO_DISH)
	skipped[who] += 1


func _outcome(who: int, meal_key: int, outcome: int, dish: int) -> void:
	"""Record how resident `who`'s meal `meal_key` went."""
	if last_meal[who] != meal_key:
		prev_meal[who] = last_meal[who]
	last_meal[who] = meal_key
	last_outcome[who] = outcome
	last_dish[who] = dish
	last_favourite[who] = 0


func had(who: int, meal_key: int) -> bool:
	"""Whether resident `who` has eaten or missed meal `meal_key` already -- or a later one (it is not called to it)."""
	return last_meal[who] >= meal_key


func had_exact(who: int, meal_key: int) -> bool:
	"""Whether resident `who`'s own record holds meal `meal_key` (eaten, raw or missed): one of its last two."""
	return last_meal[who] == meal_key or prev_meal[who] == meal_key


func _remember(who: int, dish: int) -> void:
	"""Push `dish` onto resident `who`'s last-HISTORY list, dropping the oldest."""
	var base: int = who * Rules.HISTORY
	for k: int in Rules.HISTORY - 1:
		_history[base + k] = _history[base + k + 1]
	_history[base + Rules.HISTORY - 1] = dish


func repeats_of(who: int, dish: int) -> int:
	"""How many of resident `who`'s last HISTORY meals were `dish`'s §5.7 recipe (see MEALS)."""
	var n: int = 0
	var base: int = who * Rules.HISTORY
	for k: int in Rules.HISTORY:
		n += 1 if Rules.same_recipe(_history[base + k], dish) else 0
	return n


func state_of(who: int) -> int:
	"""FED, PECKISH or HUNGRY (meal_rules.gd fed_state)."""
	return Rules.fed_state(hunger[who])


func count_in(state: int) -> int:
	"""How many residents are in `state`."""
	var n: int = 0
	for i: int in count():
		n += 1 if state_of(i) == state else 0
	return n
