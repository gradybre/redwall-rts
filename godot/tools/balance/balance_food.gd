extends RefCounted
## THE BALANCE HARNESS'S FOOD WATCH (decision 0911): what was produced, used, eaten and spoiled, the stock and its
## reserve, the meals and how fed the residents were. Measurement only.
##
## WHERE EACH FIGURE COMES FROM -- ledgers only a committed change moves (decision 0451's record reads the same ones):
##   produced / withdrawn / spoiled, per item  the pantry's ledger (farm_pantry.gd `stored_total_milli`,
##                                             `withdrawn_total_milli`, `spoiled_total_milli`), each day's movement;
##   cooked / raw, portions, batches           the kitchen's counters (`consumed_food_milli`, `raw_eaten_milli`,
##                                             `portions_eaten`, `batches_cooked`), each day's movement;
##   spoiled on the table                      the meal store's `spoiled_portions` and a cancelled batch's food;
##   caught / landed                           the fishery's `caught_milli` and `landed_milli`;
##   stock                                     the pantry per item at the day's close;
##   reserve                                   the HUD's Ready food (`days_of_meals_milli`, thousandths of a day),
##                                             at each farm hour (its minimum) and at the close;
##   meals                                     the kitchen's meal log (ate a portion, ate raw, went without), each meal
##                                             booked to its own day (meal key / 2);
##   fed                                       resident-HOURS in each fed state (nourishment.gd), one reading an hour.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")

const K_COOKED: int = 0
const K_RAW: int = 1
const K_PORTIONS: int = 2
const K_BATCHES: int = 3
const K_TABLE_SPOILED: int = 4
const K_CANCELLED_SPOIL: int = 5
const K_CAUGHT: int = 6
const K_LANDED: int = 7
const K_WOOD: int = 8
const K_COUNT: int = 9
const K_NAMES: Array[String] = ["cooked_milli", "raw_eaten_milli", "portions_eaten", "batches_cooked",
	"table_spoiled_portions", "cancelled_spoil_milli", "caught_milli", "landed_milli", "kitchen_wood_milli"]
const LEDGER_PRODUCED: int = 0
const LEDGER_WITHDRAWN: int = 1
const LEDGER_SPOILED: int = 2
const LEDGER_NAMES: Array[String] = ["produced", "withdrawn", "spoiled"]

var _kitchen: KitchenScript = null
var _pantry: PantryScript = null
var _fishery: FisheryScript = null
## The ledgers and counters as they stood at the last close.
var _ledger: PackedInt64Array = PackedInt64Array()
var _counters: PackedInt64Array = PackedInt64Array()
var _now: PackedInt64Array = PackedInt64Array()
## The last meal key booked from the kitchen's log.
var _last_meal_key: int = -1
## Meals by day: day -> [ate, raw, without] per meal (6 ints).
var _meals: Dictionary = {}
var _fed_hours: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _reserve_min: int = -1


func bind(kitchen: KitchenScript, pantry: PantryScript, fishery: FisheryScript) -> void:
	"""Watch these from their ledgers now (the fishery may be null)."""
	_kitchen = kitchen
	_pantry = pantry
	_fishery = fishery
	_ledger.resize(LEDGER_NAMES.size() * Catalog.PANTRY_ITEM_COUNT)
	_counters.resize(K_COUNT)
	_now.resize(K_COUNT)
	_read_ledger_into(_ledger)
	_read_counters_into(_counters)
	reset_day()


func _read_ledger_into(out: PackedInt64Array) -> void:
	"""The pantry's three cumulative ledgers, item by item."""
	for g: int in LEDGER_NAMES.size():
		for item: int in Catalog.PANTRY_ITEM_COUNT:
			out[g * Catalog.PANTRY_ITEM_COUNT + item] = _ledger_value(g, item)


func _read_counters_into(out: PackedInt64Array) -> void:
	"""The kitchen's and the fishery's cumulative counters, in K_* order."""
	out[K_COOKED] = _kitchen.consumed_food_milli
	out[K_RAW] = _kitchen.raw_eaten_milli
	out[K_PORTIONS] = _kitchen.portions_eaten
	out[K_BATCHES] = _kitchen.batches_cooked
	out[K_TABLE_SPOILED] = _kitchen.store.spoiled_portions
	out[K_CANCELLED_SPOIL] = _kitchen.cancelled_spoil_milli
	out[K_CAUGHT] = _fishery.caught_milli if _fishery != null else 0
	out[K_LANDED] = _fishery.landed_milli if _fishery != null else 0
	out[K_WOOD] = _kitchen.consumed_wood_milli


func hour() -> void:
	"""One farm hour: the fed states counted, the reserve's minimum, and the meals the kitchen has closed."""
	for state: int in 3:
		_fed_hours[state] += _kitchen.fed.count_in(state)
	var reserve: int = _kitchen.days_of_meals_milli()
	_reserve_min = reserve if _reserve_min < 0 else mini(_reserve_min, reserve)
	_book_meals()


func _book_meals() -> void:
	"""Each meal the kitchen's log closed since the last look, onto its own day."""
	for k: int in _kitchen.meal_keys.size():
		var key: int = _kitchen.meal_keys[k]
		if key <= _last_meal_key:
			continue
		_last_meal_key = key
		var day: int = key >> 1
		var meal: int = key & 1
		if not _meals.has(day):
			_meals[day] = PackedInt32Array([0, 0, 0, 0, 0, 0])
		var row: PackedInt32Array = _meals[day]
		row[meal * 3] = _kitchen.meal_ate[k]
		row[meal * 3 + 1] = _kitchen.meal_raw[k]
		row[meal * 3 + 2] = _kitchen.meal_without[k]
		_meals[day] = row


func close_day(day: int) -> Dictionary:
	"""Calendar day `day`'s food figures (milli-U unless named otherwise), then reset."""
	_book_meals()
	var reserve: int = _kitchen.days_of_meals_milli()
	var out: Dictionary = {"items": _item_moves(), "kitchen": _counter_moves(), "stock": _stock(),
		"reserve_days_milli_end": reserve,
		"reserve_days_milli_min": mini(_reserve_min, reserve) if _reserve_min >= 0 else reserve,
		"meals": _meals_of(day), "fed_resident_hours": {"fed": _fed_hours[0], "peckish": _fed_hours[1],
			"hungry": _fed_hours[2]}}
	reset_day()
	return out


func _item_moves() -> Dictionary:
	"""Each ledger's movement since the last close, by item key (items that did not move left out)."""
	var out: Dictionary = {}
	for g: int in LEDGER_NAMES.size():
		var moves: Dictionary = {}
		for item: int in Catalog.PANTRY_ITEM_COUNT:
			var at: int = g * Catalog.PANTRY_ITEM_COUNT + item
			var now: int = _ledger_value(g, item)
			if now != _ledger[at]:
				moves[String(Catalog.ITEM_KEYS[item])] = now - _ledger[at]
				_ledger[at] = now
		out[LEDGER_NAMES[g]] = moves
	return out


func _ledger_value(group: int, item: int) -> int:
	"""Ledger `group`'s cumulative figure for `item` now."""
	match group:
		LEDGER_PRODUCED:
			return _pantry.stored_total_milli(item)
		LEDGER_WITHDRAWN:
			return _pantry.withdrawn_total_milli(item)
	return _pantry.spoiled_total_milli(item)


func _counter_moves() -> Dictionary:
	"""The kitchen's and fishery's counters' movement since the last close."""
	_read_counters_into(_now)
	var out: Dictionary = {}
	for k: int in K_COUNT:
		out[K_NAMES[k]] = _now[k] - _counters[k]
		_counters[k] = _now[k]
	return out


func _stock() -> Dictionary:
	"""The pantry's stock now: the total and each item held."""
	var items: Dictionary = {}
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var milli: int = _pantry.milli_of(item)
		if milli > 0:
			items[String(Catalog.ITEM_KEYS[item])] = milli
	return {"total_milli": _pantry.total_milli(), "items": items}


func _meals_of(day: int) -> Dictionary:
	"""Day `day`'s two meals: who ate a portion, ate raw, went without (zeros for a meal the log has not closed)."""
	var row: PackedInt32Array = _meals.get(day, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	_meals.erase(day)
	return {"breakfast": {"ate": row[0], "raw": row[1], "without": row[2]},
		"supper": {"ate": row[3], "raw": row[4], "without": row[5]},
		"ate": row[0] + row[3], "raw": row[1] + row[4], "without": row[2] + row[5]}


func reset_day() -> void:
	"""Zero the day's hourly tallies."""
	_fed_hours.fill(0)
	_reserve_min = -1
